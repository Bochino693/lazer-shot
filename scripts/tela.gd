extends Node

## A TELA DO LAZER SHOT (Godot 3.6, OpenGL ES 2, TV Box Mali-450).
##
## O jogo é em pé: 1024 x 1820 para todos os scripts (a mesma tela da versão
## 4.6 numa TV 16:9 em pé). Na TV Box o HDMI sai DEITADO (1920 x 1080) e o
## monitor da máquina está EM PÉ. O app abre DEITADO (a marca da abertura já
## sai girada) e então decide quem gira a imagem:
##   - O ANDROID, quando a TV Box gira de verdade: o app pede a tela em pé
##     (retrato) e confere. A janela fica em pé do tamanho da tela inteira
##     (1080 x 1920) e a SETA DO MOUSE passa a andar no sentido da arma e a
##     cobrir a tela: a mira é a própria seta (ver `MiraGlobal`), sem pular.
##   - O JOGO, no resto: a TV Box não gira (Amlogic "force_land") ou põe o app
##     em pé numa faixa no meio da tela, sem girar ("middle_port", o padrão de
##     muitas). O app fica deitado e o jogo gira a imagem 90° por dentro, pela
##     transformação global do canvas (fundo, HUD, modais e mira). A TV Box
##     lembra (user://tela.cfg) e não tenta de novo.
## Para os scripts a tela continua 1024 x 1820.
##
## Ajustes em project.godot (só valem no Android; no PC o giro é 0):
##   lazer/tela/giro = 1   topo do jogo na ESQUERDA do HDMI (retrato do Android)
##                    -1   topo do jogo na DIREITA do HDMI (retrato invertido)
##                     0   sem giro (monitor ligado já em pé)
##   lazer/tela/rotacao = "android"  tenta o giro do Android (padrão)
##                        "jogo"     nem tenta: o jogo gira por dentro
##   lazer/tela/mira_direta = true   arma no sentido do monitor em pé (padrão)
##                            false  mouse segue o HDMI deitado
## Para testar no PC: LAZER_GIRO, LAZER_MIRA_DIRETA, LAZER_ROTACAO
## (auto/android/jogo) e LAZER_PROP_ROTACAO (finge a TV Box Amlogic: o teste
## gira a janela como ela giraria).
## Na TV Box o giro e quem gira também se trocam na CONFIGURAÇÃO ("Giro da
## tela" e "Quem gira a tela", chaves tela/giro e tela/rotacao).
##
## CAIXA-PRETA: a cada 15 s grava em user://caixa_preta.cfg a tela, a memória
## e os quadros por segundo; a CONFIGURAÇÃO mostra como a sessão anterior
## terminou (diagnóstico da TV Box sem cabo nem computador).

const VERSAO = "2.6.0"
const TELA = Vector2(1024, 1820)
const CAIXA = "user://caixa_preta.cfg"
const GIRO_ARQUIVO = "user://tela.cfg"
const GIRO_ESPERA_MS = 5000    # o Android tem isto para girar depois do pedido

var giro = 0                   # o giro que o JOGO faz por dentro agora (0 com a janela em pé)
var giro_pedido = 0            # o giro escolhido (project.godot / CONFIGURAÇÃO)
var android_gira = false       # o Android pôs a janela em pé: a seta anda no sentido da arma
var android_nao_gira = ""      # por que o Android não gira esta tela (para a CONFIGURAÇÃO)
var prop_rotacao = ""          # persist.sys.app.rotation da TV Box Amlogic (vazio: outra)
var mira_direta = true
var _rotacao_atual = ""        # trocada na CONFIGURAÇÃO (vazio: a do arquivo)
var _pediu_em_pe = false       # o app pediu ao Android a tela em pé
var _pedido_ms = 0             # quando pediu (0: já conferiu)
var _lado_longo = 0.0          # o lado maior da tela inteira (da janela deitada)

var _janela = Vector2.ZERO     # pixels da janela (HDMI)
var _escala = 1.0              # pixels do HDMI por pixel do jogo
var _desloc = Vector2.ZERO     # sobra (faixas pretas) se a TV não for 16:9

var _sessao_anterior = {}
var _inicio_ms = 0
var _batida = 0.0
var _marcas = []
var _pico_mem = 0
var _quadros = 0
var _quadros_t = 0.0
var _fps = 0.0


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_inicio_ms = OS.get_ticks_msec()
	giro_pedido = _giro_configurado()
	mira_direta = _mira_configurada()
	prop_rotacao = _ler_prop_rotacao()
	_ler_sessao_anterior()
	marca("LAZER SHOT %s (Godot 3.6, GLES2) | %s | giro %d, quem gira: %s%s" % [VERSAO, _data(), giro_pedido,
		_rotacao_escolhida(), (" | TV Box: %s" % prop_rotacao) if prop_rotacao != "" else ""])
	get_tree().connect("screen_resized", self, "_aplicar")
	_aplicar()
	_pedir_orientacao()
	_aplicar()     # (se a janela já estava em pé, confere agora)
	_gravar_batida()


func _giro_configurado() -> int:
	if OS.has_environment("LAZER_GIRO"):
		return int(OS.get_environment("LAZER_GIRO"))
	if OS.get_name() != "Android":
		return 0
	# escolhido na CONFIGURAÇÃO (a Maquina ainda não carregou: lê o arquivo)
	var cfg = ConfigFile.new()
	if cfg.load("user://config_admin.cfg") == OK:
		var g = cfg.get_value("tela", "giro", "auto")
		if str(g) != "auto":
			return int(g)
	return int(ProjectSettings.get_setting("lazer/tela/giro")) if ProjectSettings.has_setting("lazer/tela/giro") else 1


## Troca o giro na hora (CONFIGURAÇÃO). "auto": o do project.godot.
func definir_giro(g) -> void:
	if OS.get_name() != "Android" and not OS.has_environment("LAZER_GIRO"):
		return
	if str(g) == "auto":
		giro_pedido = int(ProjectSettings.get_setting("lazer/tela/giro")) if ProjectSettings.has_setting("lazer/tela/giro") else 1
	else:
		giro_pedido = int(g)
	_pedir_orientacao()
	_aplicar()
	marca("giro da tela: %d" % giro_pedido)


## Quem gira, como escolhido: "auto", "android" ou "jogo" (CONFIGURAÇÃO).
func _rotacao_escolhida() -> String:
	if OS.has_environment("LAZER_ROTACAO"):
		return OS.get_environment("LAZER_ROTACAO")
	if _rotacao_atual != "":
		return _rotacao_atual
	var cfg = ConfigFile.new()
	if cfg.load("user://config_admin.cfg") == OK:
		return str(cfg.get_value("tela", "rotacao", "auto"))
	return "auto"


## Quem gira: "android" (o app pede a tela em pé e confere) ou "jogo" (o app
## fica deitado). AUTO é o do project.godot (o gerador do APK grava).
func _rotacao() -> String:
	var r = _rotacao_escolhida()
	if r == "auto":
		return str(ProjectSettings.get_setting("lazer/tela/rotacao")) if ProjectSettings.has_setting("lazer/tela/rotacao") else "android"
	return r


## Troca quem gira na hora (CONFIGURAÇÃO). `de_novo`: o operador escolheu
## agora, então o Android tem outra chance mesmo que não tenha girado antes.
func definir_rotacao(r, de_novo: bool = false) -> void:
	_rotacao_atual = str(r)
	if de_novo:
		prop_rotacao = _ler_prop_rotacao()   # (a TV Box pode ter mudado)
		var d = Directory.new()
		if d.file_exists(GIRO_ARQUIVO):
			d.remove(GIRO_ARQUIVO)
	_pedir_orientacao()
	_aplicar()
	marca("quem gira a tela: %s" % _rotacao_atual)


## A rotação de app da TV Box Amlogic (persist.sys.app.rotation): "original"
## gira o app em pé, "force_land" deixa tudo deitado e "middle_port" põe o app
## em pé numa faixa no meio da tela, sem girar. Vazio: outra TV Box (a janela
## é que diz).
func _ler_prop_rotacao() -> String:
	if OS.has_environment("LAZER_PROP_ROTACAO"):
		return OS.get_environment("LAZER_PROP_ROTACAO")
	if OS.get_name() != "Android":
		return ""
	var saida = []
	if OS.execute("getprop", ["persist.sys.app.rotation"], true, saida) != 0 or saida.empty():
		return ""
	return str(saida[0]).strip_edges()


## Já se sabe que o Android desta TV Box não gira o app? (o motivo; vazio:
## tenta). Com ANDROID escolhido na CONFIGURAÇÃO tenta sempre (e confere).
func _motivo_sem_android() -> String:
	if _rotacao_escolhida() == "android":
		return ""
	if prop_rotacao == "force_land":
		return "a TV Box deixa todo app deitado (force_land)"
	if prop_rotacao == "middle_port":
		return "a TV Box põe app em pé numa faixa no meio, sem girar (middle_port)"
	var cfg = ConfigFile.new()
	if cfg.load(GIRO_ARQUIVO) == OK and str(cfg.get_value("android", "gira", "")) == "nao" \
			and str(cfg.get_value("android", "prop", "")) == prop_rotacao:
		return "da outra vez o Android %s" % str(cfg.get_value("android", "motivo", "não girou"))
	return ""


## Pede ao Android a tela no sentido do giro (em pé ou em pé invertida) se ele
## gira o app nesta TV Box; senão o app fica deitado e o jogo gira por dentro.
## A janela confere o resultado (`_aplicar` e `_process`).
func _pedir_orientacao() -> void:
	if OS.get_name() != "Android" and not OS.has_environment("LAZER_PROP_ROTACAO"):
		return
	_pediu_em_pe = false
	_pedido_ms = 0
	android_nao_gira = ""
	if giro_pedido != 0 and _rotacao() == "android":
		android_nao_gira = _motivo_sem_android()
		if android_nao_gira == "":
			_pediu_em_pe = true
			_pedido_ms = max(1, OS.get_ticks_msec())
			OS.screen_orientation = OS.SCREEN_ORIENTATION_PORTRAIT if giro_pedido > 0 else OS.SCREEN_ORIENTATION_REVERSE_PORTRAIT
			marca("pedindo ao Android a tela em pé")
			return
		marca("o jogo gira a tela por dentro: %s" % android_nao_gira)
	OS.screen_orientation = OS.SCREEN_ORIENTATION_LANDSCAPE


## O Android pôs a janela em pé do tamanho da tela inteira.
func _android_girou() -> void:
	_pedido_ms = 0
	marca("o Android girou a tela (%dx%d): a seta anda junto com a arma" % [int(_janela.x), int(_janela.y)])
	_gravar_giro("sim", "girou")


## O Android não girou (ou girou errado): o app volta a ficar deitado, o jogo
## gira por dentro e a TV Box lembra para não tentar de novo.
func _android_falhou(motivo: String) -> void:
	_pediu_em_pe = false
	_pedido_ms = 0
	android_nao_gira = "o Android " + motivo
	OS.screen_orientation = OS.SCREEN_ORIENTATION_LANDSCAPE
	marca("o Android %s: o jogo gira a tela por dentro" % motivo)
	_gravar_giro("nao", motivo)


## Quem gira a imagem agora, em poucas palavras (CONFIGURAÇÃO).
func quem_gira() -> String:
	if android_gira:
		return "o Android (a seta anda junto com a arma)"
	if giro == 0:
		return "ninguém (sem giro)"
	if _pedido_ms > 0:
		return "o jogo, esperando o Android girar..."
	if android_nao_gira != "" and (prop_rotacao == "force_land" or prop_rotacao == "middle_port"):
		return "o jogo (a TV Box está em %s)" % prop_rotacao
	if android_nao_gira != "":
		return "o jogo (o Android desta TV Box não gira)"
	return "o jogo"


func _gravar_giro(gira: String, motivo: String) -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("android", "gira", gira)
	cfg.set_value("android", "prop", prop_rotacao)
	cfg.set_value("android", "motivo", motivo)
	cfg.set_value("android", "janela", _janela)
	cfg.save(GIRO_ARQUIVO)


func _mira_configurada() -> bool:
	if OS.has_environment("LAZER_MIRA_DIRETA"):
		return OS.get_environment("LAZER_MIRA_DIRETA") != "0"
	if ProjectSettings.has_setting("lazer/tela/mira_direta"):
		return bool(ProjectSettings.get_setting("lazer/tela/mira_direta"))
	return true


## Monta a tela: sem giro, o "keep" do Godot cuida de tudo; com giro, o
## conteúdo (em pé) é esticado para a janela (deitada) e a transformação
## global desfaz o esticão e gira 90°, em escala uniforme e centrado.
func _aplicar() -> void:
	var arvore = get_tree()
	var vp = get_viewport()
	_janela = OS.window_size
	if _janela.x <= 0.0 or _janela.y <= 0.0:
		return
	# janela em pé: o Android (ou o monitor) já gira; deitada: o jogo gira
	var em_pe = _janela.y > _janela.x
	var lado = max(_janela.x, _janela.y)
	if not em_pe or _lado_longo <= 0.0:
		_lado_longo = lado
	if em_pe and _pediu_em_pe:
		if lado < _lado_longo * 0.9:
			# em pé, mas numa faixa no meio da tela (sem girar): a imagem
			# sairia de lado no monitor em pé
			_android_falhou("pôs o app numa faixa em pé de %dx%d, sem girar" % [int(_janela.x), int(_janela.y)])
			em_pe = false
		elif _pedido_ms > 0:
			_android_girou()
	var giro_antes = giro
	var android_antes = android_gira
	giro = 0 if em_pe else giro_pedido
	android_gira = em_pe and giro_pedido != 0
	if giro != giro_antes or android_gira != android_antes:
		marca("tela %dx%d: %s" % [int(_janela.x), int(_janela.y),
			"o Android gira (seta no sentido da arma)" if android_gira else ("o jogo gira por dentro (%d)" % giro if giro != 0 else "sem giro")])
	if giro == 0:
		# letras desenhadas já no tamanho da tela (1080p: 5% maiores que o
		# jogo), nítidas; com o giro por dentro o Godot não sabe a escala
		arvore.use_font_oversampling = true
		arvore.set_screen_stretch(SceneTree.STRETCH_MODE_2D, SceneTree.STRETCH_ASPECT_KEEP, TELA)
		vp.global_canvas_transform = Transform2D.IDENTITY
		return
	arvore.use_font_oversampling = false
	arvore.set_screen_stretch(SceneTree.STRETCH_MODE_2D, SceneTree.STRETCH_ASPECT_IGNORE, TELA)
	# o monitor em pé tem largura = altura do HDMI e altura = largura do HDMI
	_escala = min(_janela.y / TELA.x, _janela.x / TELA.y)
	_desloc = Vector2((_janela.x - TELA.y * _escala) * 0.5, (_janela.y - TELA.x * _escala) * 0.5)
	var sx = TELA.x / _janela.x    # desfaz o esticão do "ignore"
	var sy = TELA.y / _janela.y
	if giro > 0:
		# jogo (x, y) -> HDMI (y, altura - x): topo do jogo na esquerda
		vp.global_canvas_transform = Transform2D(
			Vector2(0.0, -_escala * sy), Vector2(_escala * sx, 0.0),
			Vector2(_desloc.x * sx, (_janela.y - _desloc.y) * sy))
	else:
		# jogo (x, y) -> HDMI (largura - y, x): topo do jogo na direita
		vp.global_canvas_transform = Transform2D(
			Vector2(0.0, _escala * sy), Vector2(-_escala * sx, 0.0),
			Vector2((_janela.x - _desloc.x) * sx, _desloc.y * sy))


## Tamanho da tela do jogo (em pé): sempre 1024 x 1820.
func tamanho() -> Vector2:
	return TELA


## Pixel do HDMI (posição crua do evento) -> ponto do jogo, para a arma no
## sentido do monitor em pé (mira_direta): a fração da largura da janela é a
## fração da largura do jogo.
func hdmi_para_jogo_direto(p: Vector2) -> Vector2:
	if _janela.x <= 0.0 or _janela.y <= 0.0:
		return p
	return Vector2(p.x / _janela.x * TELA.x, p.y / _janela.y * TELA.y)


## Ponto do jogo -> pixel do HDMI (onde a arma precisa estar para mirar ali).
func jogo_para_hdmi_direto(p: Vector2) -> Vector2:
	return Vector2(p.x / TELA.x * _janela.x, p.y / TELA.y * _janela.y)


## Pixels do HDMI por pixel do jogo.
func escala() -> float:
	return _escala if giro != 0 else 1.0


## Pixels da janela por pixel do jogo, com ou sem giro (o tamanho real de um
## ponto do jogo na tela: a mira da arma de giroscópio anda nessa escala).
func px_por_ponto() -> float:
	if giro != 0:
		return _escala
	if _janela.x <= 0.0 or _janela.y <= 0.0:
		return 1.0
	return min(_janela.x / TELA.x, _janela.y / TELA.y)


## Movimento no HDMI -> movimento no jogo. Mira direta (o padrão): a arma
## para a direita é a mira para a direita, para cima é para cima. Mira
## girada: o movimento gira junto com a imagem.
func movimento_para_jogo(d: Vector2) -> Vector2:
	if giro == 0 or mira_direta:
		return d
	if giro > 0:
		return Vector2(-d.y, d.x)
	return Vector2(d.y, -d.x)


func janela() -> Vector2:
	return _janela


# ------------------------------------------------------------ caixa-preta
func marca(txt: String) -> void:
	var t = (OS.get_ticks_msec() - _inicio_ms) / 1000.0
	var linha = "%7.1f  %s" % [t, txt]
	print(linha)
	_marcas.append(linha)
	while _marcas.size() > 40:
		_marcas.pop_front()


func _data() -> String:
	var d = OS.get_datetime()
	return "%02d/%02d/%04d %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]


func _process(delta: float) -> void:
	if _pedido_ms > 0 and OS.get_ticks_msec() - _pedido_ms > GIRO_ESPERA_MS:
		_android_falhou("não girou o app em %d s" % (GIRO_ESPERA_MS / 1000))
		_aplicar()
	_quadros += 1
	_quadros_t += delta
	if _quadros_t >= 1.0:
		_fps = _quadros / _quadros_t
		_quadros = 0
		_quadros_t = 0.0
	_batida += delta
	if _batida >= 15.0:
		_batida = 0.0
		_gravar_batida()


func fps() -> float:
	return _fps


func memoria_mb() -> float:
	return (OS.get_static_memory_usage() + OS.get_dynamic_memory_usage()) / 1048576.0


func memoria_video_mb() -> float:
	return Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0


func _gravar_batida() -> void:
	var cena = get_tree().current_scene
	var mem = int(memoria_mb())
	_pico_mem = int(max(_pico_mem, mem))
	var cfg = ConfigFile.new()
	cfg.set_value("sessao", "versao", VERSAO)
	cfg.set_value("sessao", "inicio", _data_inicio())
	cfg.set_value("sessao", "duracao", int((OS.get_ticks_msec() - _inicio_ms) / 1000))
	cfg.set_value("sessao", "tela", cena.name if cena != null else "")
	cfg.set_value("sessao", "memoria", mem)
	cfg.set_value("sessao", "memoria_video", int(memoria_video_mb()))
	cfg.set_value("sessao", "pico_memoria", _pico_mem)
	cfg.set_value("sessao", "fps", int(round(_fps)))
	cfg.set_value("sessao", "fechou_bem", false)
	cfg.set_value("sessao", "marcas", PoolStringArray(_marcas))
	_salvar_em_fundo(cfg)


var _gravador: Thread = null
var _gravando = false

## Grava a caixa-preta sem segurar o jogo: a memória da TV Box às vezes
## demora para escrever, e isso não pode virar tranco no meio da partida.
## Se a gravação anterior ainda não acabou, esta fica para a próxima.
func _salvar_em_fundo(cfg: ConfigFile) -> void:
	if _gravando:
		return
	if _gravador != null:
		_gravador.wait_to_finish()
	_gravando = true
	_gravador = Thread.new()
	if _gravador.start(self, "_gravar_arquivo", cfg) != OK:
		_gravador = null
		_gravando = false
		cfg.save(CAIXA)


func _gravar_arquivo(cfg: ConfigFile) -> void:
	cfg.save(CAIXA)
	_gravando = false


func _exit_tree() -> void:
	if _gravador != null:
		_gravador.wait_to_finish()
		_gravador = null


var _inicio_txt = ""

func _data_inicio() -> String:
	if _inicio_txt == "":
		_inicio_txt = _data()
	return _inicio_txt


func _ler_sessao_anterior() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(CAIXA) != OK:
		return
	for k in ["versao", "inicio", "duracao", "tela", "memoria", "memoria_video", "pico_memoria", "fps", "fechou_bem", "marcas"]:
		_sessao_anterior[k] = cfg.get_value("sessao", k, null)


## Resumo da sessão anterior para a CONFIGURAÇÃO (uma linha).
func resumo_sessao_anterior() -> String:
	if _sessao_anterior.empty():
		return "Primeira vez nesta TV Box"
	var dur = int(_sessao_anterior.get("duracao", 0))
	var tempo = "%d min" % (dur / 60) if dur >= 60 else "%d s" % dur
	var fim = "terminou bem" if bool(_sessao_anterior.get("fechou_bem", false)) else "fechou em %s" % str(_sessao_anterior.get("tela", "?"))
	return "Sessão anterior: %s (%s, %d MB, %d quadros/s)" % [fim, tempo,
		int(_sessao_anterior.get("pico_memoria", 0)), int(_sessao_anterior.get("fps", 0))]


func marcas_sessao_anterior() -> PoolStringArray:
	var m = _sessao_anterior.get("marcas", null)
	return m if m is PoolStringArray else PoolStringArray()


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		if _gravador != null:
			_gravador.wait_to_finish()
			_gravador = null
		var cfg = ConfigFile.new()
		if cfg.load(CAIXA) == OK:
			cfg.set_value("sessao", "fechou_bem", true)
			cfg.save(CAIXA)
