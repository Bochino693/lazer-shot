extends Node

## A TELA DO LAZER SHOT (Godot 3.6, OpenGL ES 2, TV Box Mali-450).
##
## O jogo é em pé: 1024 x 1820 para todos os scripts (a mesma tela da versão
## 4.6 numa TV 16:9 em pé). Na TV Box o HDMI sai DEITADO (1920 x 1080) e o
## monitor da máquina está EM PÉ: o jogo gira a imagem 90° por dentro, pela
## transformação global do canvas (vale para todas as camadas: fundo, HUD,
## modais e mira). Para os scripts a tela continua 1024 x 1820.
##
## A ARMA manda a posição no sentido do monitor em pé (a fração da largura do
## HDMI é a fração da largura do jogo): ver `MiraGlobal`.
##
## Ajustes em project.godot (só valem no Android; no PC o giro é 0):
##   lazer/tela/giro = 1   topo do jogo na ESQUERDA do HDMI
##                    -1   topo do jogo na DIREITA do HDMI (imagem de cabeça para baixo? use este)
##                     0   sem giro (monitor ligado já em pé)
##   lazer/tela/mira_direta = true   arma no sentido do monitor em pé (padrão)
##                            false  mouse segue o HDMI deitado
## Para testar no PC: variáveis de ambiente LAZER_GIRO e LAZER_MIRA_DIRETA.
## Na TV Box o giro também se troca na CONFIGURAÇÃO ("Giro da tela", chave
## tela/giro de user://config_admin.cfg: "auto" usa o do project.godot).
##
## CAIXA-PRETA: a cada 5 s grava em user://caixa_preta.cfg a tela, a memória
## e os quadros por segundo; a CONFIGURAÇÃO mostra como a sessão anterior
## terminou (diagnóstico da TV Box sem cabo nem computador).

const VERSAO = "2.0.2"
const TELA = Vector2(1024, 1820)
const CAIXA = "user://caixa_preta.cfg"

var giro = 0
var mira_direta = true

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
	giro = _giro_configurado()
	mira_direta = _mira_configurada()
	get_tree().connect("screen_resized", self, "_aplicar")
	_aplicar()
	_inicio_ms = OS.get_ticks_msec()
	_ler_sessao_anterior()
	marca("LAZER SHOT %s (Godot 3.6, GLES2) | %s | giro %d" % [VERSAO, _data(), giro])
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
		giro = int(ProjectSettings.get_setting("lazer/tela/giro")) if ProjectSettings.has_setting("lazer/tela/giro") else 1
	else:
		giro = int(g)
	_aplicar()
	marca("giro da tela: %d" % giro)


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
	if giro == 0:
		arvore.set_screen_stretch(SceneTree.STRETCH_MODE_2D, SceneTree.STRETCH_ASPECT_KEEP, TELA)
		vp.global_canvas_transform = Transform2D.IDENTITY
		_janela = OS.window_size
		return
	_janela = OS.window_size
	if _janela.x <= 0.0 or _janela.y <= 0.0:
		return
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
	_quadros += 1
	_quadros_t += delta
	if _quadros_t >= 1.0:
		_fps = _quadros / _quadros_t
		_quadros = 0
		_quadros_t = 0.0
	_batida += delta
	if _batida >= 5.0:
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
	cfg.save(CAIXA)


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
		var cfg = ConfigFile.new()
		if cfg.load(CAIXA) == OK:
			cfg.set_value("sessao", "fechou_bem", true)
			cfg.save(CAIXA)
