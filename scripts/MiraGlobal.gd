extends Node

## Ritmo de quadros e A MIRA DO JOGO INTEIRO.
##
## A arma é um mouse com giroscópio. Há UMA mira, aqui, e cada tela lê
## `MiraGlobal.pos` e desenha/acerta exatamente ali.
##
## O evento chega no sentido da janela (na TV Box, o HDMI deitado); a mira
## converte movimento e ponto para a tela em pé com a mesma transformação que
## o Godot usa para as telas (sem isso os eixos ficavam trocados: arma para a
## direita subia a mira).
##
## Como a mira anda:
## - Ponteiro CAPTURADO (o normal): o Android manda só o deslocamento da
##   arma; ele soma na mira (com a sensibilidade do botão MIRA do menu), sem
##   filtro nenhum, como um mouse.
## - Ponteiro NÃO capturado: o Android só captura o ponteiro com a janela em
##   foco, e o Godot pede uma vez só (se o pedido chega cedo, ou se o foco sai
##   e volta, a captura some e ele nunca pede de novo). Sem captura, o cursor
##   do sistema bate na borda da tela deitada e somar deslocamentos deixava
##   pedaços da tela sem alcance ("pontos cegos"). Então, sem captura, a mira
##   vai para onde o ponteiro real está (cobre a tela inteira), e a captura é
##   pedida de novo a cada segundo e sempre que o app volta ao foco.
## O cursor do sistema fica invisível em qualquer modo (a tela desenha a mira).
##
## RECUO (como nos jogos de tiro): o primeiro tiro vai exatamente na mira;
## tiros em sequência levantam a arma — cada um dá um tranco para cima e um
## pouco para o lado (mais forte quanto mais rápida a sequência) e a bala do
## tiro seguinte vai para onde a arma subiu. Sem atirar, a arma volta sozinha
## para a mira (~0,4 s). As telas desenham a mira e atiram em `mira()` (a
## mira + o recuo): a bala cai exatamente onde a mira mostra, e o que há lá
## (alvo, madeira, vidro, pedra, água, nada) responde.

## No PC o jogo vai a 120 quadros; na TV Box só o vsync manda (ver abaixo).
const FPS_ALVO: int = 120

const META_SENS_MOUSE := "sensibilidade_mouse"
const INTERVALO_RECAPTURA := 1.0

## Posição da mira, em coordenadas da tela do jogo (em pé).
var pos := Vector2.ZERO
## Mesmo que `pos` (mantido para as telas que já liam este nome).
var bruta := Vector2.ZERO
## Android: o ponteiro está realmente capturado agora?
var capturada := true

## Quanto a arma subiu com os tiros em sequência (px da tela).
var recuo := Vector2.ZERO

const RECUO_PASSO := 26.0       # px para cima por tiro
const RECUO_LADO := 11.0        # px para o lado (sorteado) por tiro
const RECUO_SEQUENCIA := 0.45   # s: tiro antes disto depois do outro é sequência
const RECUO_MAX := 110.0        # px
const RECUO_VOLTA := 4.5        # 1/s: a arma voltando para a mira
var _seguidos := 0
var _ultimo_coice_ms := -100000

var _iniciada := false
var _sens := 1.0
var _android := false
var _arma_ligada := false
var _sem_captura := false
var _ultima_janela := Vector2(INF, INF)
var _recapturar_em := 0.0

# RITMO (TV Box): uma tela que não segura 60 quadros por segundo alterna
# quadros de 16 e de 33 ms, e isso aparece como tranco. Se em 2 s mais de um
# quarto dos quadros passou de 20 ms, a tela fica em 30 por segundo cravados
# (liso). A TV Box LEMBRA dessas telas (user://ritmo.cfg, por versão do
# jogo): da próxima vez a tela já abre em 30, sem os primeiros segundos de
# tranco enquanto media. As outras telas continuam tentando 60.
const RITMO_JANELA := 2.0
const RITMO_LENTO_MS := 20.0
const RITMO_FRACAO := 0.25
const RITMO_ARQUIVO := "user://ritmo.cfg"
const VERSAO_JOGO := preload("res://scripts/caixa_preta.gd").VERSAO
## Calibrado para a TV Box (Mali-G31): estas telas são as mais pesadas para a
## placa (fundo em camadas, luz do sol, planos em 3D) e já abrem em 30
## cravados, sem os 2 s de tranco medindo. As outras tentam 60 e caem para
## 30 sozinhas se não segurarem.
const TELAS_30 := ["res://scenes/deserto.tscn", "res://scenes/mar.tscn"]
var _ritmo_lento: Dictionary = {}   # cena -> true (abre direto em 30)
# CALIBRAGEM (TV Box): se nem em 30 a tela segura (mais de um quarto dos
# quadros de 3 s passando de 45 ms), ela fica LEVE: os enfeites que cada fase
# marcou no grupo "efeito_opcional" (neve do mar, poeira, cardumes do fundo)
# param e somem. Alvos, cenário, luz e efeitos de acerto continuam. A TV Box
# lembra (user://ritmo.cfg, por versão) e a tela já abre leve da próxima vez.
const LEVE_JANELA := 3.0
const LEVE_LENTO_MS := 45.0
var _telas_leves: Dictionary = {}   # cena -> true
# A QUALIDADE COMPLETA QUE NÃO CABE (Rodada 33). A AVANÇADA (TX9) abre na
# qualidade completa. Se uma FASE (deserto, mar, bar, arena), já em 30 e sem
# os enfeites opcionais, ainda não segura (mais de um quarto dos quadros de
# 5 s passando de 45 ms), esta TV Box não aguenta a completa: a partir da
# próxima troca de tela o jogo fica na qualidade leve, a mesma da Pro Ultra
# (Maquina.qualidade_leve). Menu e abertura não contam (um tranco de vídeo
# ali não diz nada da partida).
# A TV Box lembra (user://ritmo.cfg, por versão). Só vale com a qualidade
# AUTOMÁTICA; COMPLETA na CONFIGURAÇÃO fica completa.
const COMPLETA_JANELA := 5.0
var completa_nao_cabe := false
var _leve_t := 0.0
var _leve_quadros := 0
var _leve_lentos := 0
var _ritmo_ativo := false
var _ritmo_cena := 0
var _ritmo_t := 0.0
var _ritmo_quadros := 0
var _ritmo_lentos := 0
var _ritmo_ultimo := 0


func _ready() -> void:
	_forcar_120_fps()
	_android = OS.get_name() == "Android"
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100   # atualiza antes das telas lerem
	# Depois do Tela.gd (autoload anterior), que corrige o giro do evento.
	get_tree().root.window_input.connect(_ao_evento)
	# Captura da arma e cursor transparente logo na partida do app, como até
	# a 1.24.0 (a última que mostrou a apresentação na TV Box).
	iniciar_arma(Tela.contorna("arma"))


## Liga a arma: seta transparente e ponteiro capturado. `seguro`: a TV Box
## já caiu aqui antes (caixa-preta): sem captura nem seta própria, a mira
## segue o ponteiro real escondido.
func iniciar_arma(seguro: bool = false) -> void:
	if _arma_ligada:
		return
	_arma_ligada = true
	_sem_captura = seguro
	if seguro:
		capturada = false
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		Tela.marca("arma sem captura (contorno)")
		return
	_cursor_invisivel()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _forcar_120_fps() -> void:
	# TV Box (Android): a TV é de 60 Hz e o Android sempre sincroniza com ela;
	# pedir 120 só gastaria processador e bateria de CPU sem quadro a mais.
	if OS.get_name() == "Android" or OS.get_environment("LAZER_RITMO") == "1":
		# Só o vsync manda no ritmo (60 Hz, ou 50 Hz em saída PAL). Com o
		# limitador do motor também em 60, os dois brigam e de tempos em
		# tempos um quadro perde a vez: era a "travadinha" constante.
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		_ritmo_ativo = true
		_ritmo_carregar()
		print("MiraGlobal: TV Box -> vsync (sem limitador)")
		return

	# Max FPS: teto interno do motor -- vale pro jogo inteiro, todas as cenas,
	# já que Engine.max_fps é uma propriedade global do motor, não da cena.
	Engine.max_fps = FPS_ALVO

	# VSync: se ficar "Enabled", o Godot trava no refresh rate do monitor
	# (ex: num monitor 60Hz, nunca passa de 60 mesmo com max_fps=120).
	# "Adaptive" deixa passar de 60 em monitores 120Hz, evitando tearing
	# forte quando o FPS cai abaixo do refresh rate.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)

	print("MiraGlobal: FPS alvo definido para ", FPS_ALVO, " | vsync mode = adaptive")


## Mede os quadros da tela atual e, se ela não segura 60, trava em 30.
func _ritmo() -> void:
	var agora := Time.get_ticks_usec()
	var cena := get_tree().current_scene
	var id := cena.get_instance_id() if cena != null else 0
	if id != _ritmo_cena:
		# tela nova: abre em 30 se ela já não segurou 60 antes; senão tenta
		# 60 e espera ela assentar antes de medir. Na qualidade leve (TV Box
		# mais fraca, Maquina.qualidade_leve) toda tela abre em 30 e já sem
		# os enfeites opcionais.
		_ritmo_cena = id
		var leve: bool = Maquina.qualidade_leve()
		_cravar(30 if cena != null and (leve or _ritmo_lento.has(cena.scene_file_path)) else 0)
		_ritmo_t = -1.5
		_ritmo_quadros = 0
		_ritmo_lentos = 0
		_ritmo_ultimo = agora
		_leve_t = -2.0
		_leve_quadros = 0
		_leve_lentos = 0
		if cena != null and (leve or _telas_leves.has(cena.scene_file_path)):
			_deixar_leve.call_deferred(cena)
		return
	var quadro := (agora - _ritmo_ultimo) / 1000.0
	_ritmo_ultimo = agora
	if Engine.max_fps == 30:
		_medir_leve(quadro, cena)
		return
	_ritmo_t += quadro / 1000.0
	if _ritmo_t < 0.0 or TransicaoGlobal.em_transicao:
		return
	_ritmo_quadros += 1
	if quadro > RITMO_LENTO_MS:
		_ritmo_lentos += 1
	if _ritmo_t >= RITMO_JANELA:
		if _ritmo_quadros > 20 and float(_ritmo_lentos) / _ritmo_quadros > RITMO_FRACAO:
			_cravar(30)
			Tela.marca("ritmo: 30 quadros/s cravados em %s (%d de %d quadros passavam de %d ms)" % [cena.name, _ritmo_lentos, _ritmo_quadros, int(RITMO_LENTO_MS)])
			if cena.scene_file_path != "":
				_ritmo_lento[cena.scene_file_path] = true
				_ritmo_salvar()
		_ritmo_t = 0.0
		_ritmo_quadros = 0
		_ritmo_lentos = 0


## 30 ou livre (0 = o vsync manda). Em 30 a física também anda a 30 por
## segundo (nenhuma tela depende dela a cada passo; a 60 eram dois passos
## por quadro), e um quadro atrasado não vira uma fila de passos.
func _cravar(fps: int) -> void:
	Engine.max_fps = fps
	Engine.physics_ticks_per_second = 30 if fps == 30 else 60
	Engine.max_physics_steps_per_frame = 2 if fps == 30 else 4


## Em 30: mede se a tela segura; se não, fica leve (uma vez por tela). Já
## leve e ainda sem segurar, na qualidade completa: a completa não cabe.
func _medir_leve(quadro: float, cena: Node) -> void:
	if cena == null or cena.scene_file_path == "":
		return
	var ja_leve := _telas_leves.has(cena.scene_file_path)
	if ja_leve and not (_pode_largar_a_completa() and TransicaoGlobal.FASES.has(cena.scene_file_path)):
		return
	_leve_t += quadro / 1000.0
	if _leve_t < 0.0 or TransicaoGlobal.em_transicao:
		return
	_leve_quadros += 1
	if quadro > LEVE_LENTO_MS:
		_leve_lentos += 1
	if _leve_t >= (COMPLETA_JANELA if ja_leve else LEVE_JANELA):
		if _leve_quadros > 20 and float(_leve_lentos) / _leve_quadros > RITMO_FRACAO:
			if ja_leve:
				completa_nao_cabe = true
				Tela.marca("calibragem: a qualidade completa não cabe nesta TV Box (%s: %d de %d quadros passavam de %d ms); leve a partir da próxima tela" % [cena.name, _leve_lentos, _leve_quadros, int(LEVE_LENTO_MS)])
				_ritmo_salvar()
			else:
				Tela.marca("calibragem: %s leve (%d de %d quadros passavam de %d ms)" % [cena.name, _leve_lentos, _leve_quadros, int(LEVE_LENTO_MS)])
				_telas_leves[cena.scene_file_path] = true
				_ritmo_salvar()
				_deixar_leve(cena)
		_leve_t = 0.0
		_leve_quadros = 0
		_leve_lentos = 0


## A completa ainda pode virar leve sozinha: está na completa, pela
## qualidade AUTOMÁTICA, e ainda não largou.
func _pode_largar_a_completa() -> bool:
	return not completa_nao_cabe and not Maquina.qualidade_leve() and Maquina.qualidade_automatica()


## Para e esconde os enfeites opcionais da tela.
func _deixar_leve(cena: Node) -> void:
	if not is_instance_valid(cena):
		return
	for n in get_tree().get_nodes_in_group("efeito_opcional"):
		if n is CanvasItem and cena.is_ancestor_of(n):
			(n as CanvasItem).visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED


func _ritmo_carregar() -> void:
	for c in TELAS_30:
		_ritmo_lento[c] = true
	var cfg := ConfigFile.new()
	if cfg.load(RITMO_ARQUIVO) != OK or str(cfg.get_value("ritmo", "versao", "")) != VERSAO_JOGO:
		return   # outra versão do jogo: mede de novo
	for c in cfg.get_value("ritmo", "telas_30", []):
		_ritmo_lento[str(c)] = true
	for c in cfg.get_value("ritmo", "telas_leves", []):
		_telas_leves[str(c)] = true
	completa_nao_cabe = bool(cfg.get_value("ritmo", "completa_nao_cabe", false))


func _ritmo_salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ritmo", "versao", VERSAO_JOGO)
	cfg.set_value("ritmo", "telas_30", _ritmo_lento.keys())
	cfg.set_value("ritmo", "telas_leves", _telas_leves.keys())
	cfg.set_value("ritmo", "completa_nao_cabe", completa_nao_cabe)
	cfg.save(RITMO_ARQUIVO)


## Seta do sistema transparente: refazer a captura não pisca cursor na tela.
func _cursor_invisivel() -> void:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img))


func _tela() -> Vector2:
	return get_tree().root.get_visible_rect().size


func _garantir_inicio() -> void:
	if _iniciada:
		return
	var tela := _tela()
	if tela.x <= 0.0:
		return
	_iniciada = true
	pos = tela * 0.5
	bruta = pos


func _ao_evento(ev: InputEvent) -> void:
	if not (ev is InputEventMouseMotion):
		return
	_garantir_inicio()
	var mm := ev as InputEventMouseMotion
	# O evento ainda está no sentido da janela (o HDMI deitado, na TV Box);
	# a mesma conversão que o Godot faz antes de entregar às telas leva o
	# movimento e o ponto para a tela em pé (arma para cima = mira para cima).
	var para_jogo := get_tree().root.get_final_transform().affine_inverse()
	var tela := _tela()

	if _android:
		# Capturado, o Android manda o ponteiro parado e só o deslocamento;
		# se a posição anda junto, a captura caiu.
		var andou := _ultima_janela.x != INF and mm.position.distance_squared_to(_ultima_janela) > 0.25
		_ultima_janela = mm.position
		capturada = not andou
		if not capturada:
			# sem captura: a mira é o ponteiro real (alcança a tela inteira)
			pos = para_jogo * mm.position
			pos = Vector2(clampf(pos.x, 0.0, tela.x), clampf(pos.y, 0.0, tela.y))
			bruta = pos
			return

	# soma o deslocamento já (a mira responde no mesmo quadro do movimento)
	pos += para_jogo.basis_xform(mm.relative) * _sens
	pos = Vector2(clampf(pos.x, 0.0, tela.x), clampf(pos.y, 0.0, tela.y))
	bruta = pos


func _process(delta: float) -> void:
	_garantir_inicio()
	if _ritmo_ativo:
		_ritmo()
	_sens = clampf(float(get_tree().get_meta(META_SENS_MOUSE, 1.0)), 0.2, 3.0)

	if _android and not capturada and _arma_ligada and not _sem_captura:
		# pede a captura de novo até o Android aceitar
		_recapturar_em -= delta
		if _recapturar_em <= 0.0:
			_recapturar_em = INTERVALO_RECAPTURA
			_recapturar()

	var tela := _tela()
	pos = Vector2(clampf(pos.x, 0.0, tela.x), clampf(pos.y, 0.0, tela.y))
	bruta = pos
	if recuo != Vector2.ZERO:
		recuo *= exp(-RECUO_VOLTA * delta)
		if recuo.length_squared() < 0.04:
			recuo = Vector2.ZERO


## Onde a arma aponta agora: a mira mais o recuo dos tiros em sequência.
## As telas desenham a mira aqui e a bala sai para cá.
func mira() -> Vector2:
	_garantir_inicio()
	var tela := _tela()
	var p := pos + recuo
	return Vector2(clampf(p.x, 0.0, tela.x), clampf(p.y, 0.0, tela.y))


## A tela chama a cada tiro dado (bala gasta): a arma dá o tranco. `forca`
## muda com a arma da tela (pistola do bar mais forte, laser da arena leve).
func coice(forca: float = 1.0) -> void:
	# caixa-preta: o primeiro tiro de cada tela e se os quadros seguintes
	# saíram (scripts/caixa_preta.gd)
	Tela.marca_primeiro("tiro")
	var agora := Time.get_ticks_msec()
	var dt := (agora - _ultimo_coice_ms) / 1000.0
	_ultimo_coice_ms = agora
	_seguidos = mini(_seguidos + 1, 5) if dt < RECUO_SEQUENCIA else 0
	var sobe := RECUO_PASSO * (1.0 + 0.1 * _seguidos)
	var lado := randf_range(-RECUO_LADO, RECUO_LADO) * (1.0 + 0.3 * _seguidos)
	recuo = (recuo + Vector2(lado, -sobe) * forca).limit_length(RECUO_MAX * forca)


func _recapturar() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# ao voltar o foco o Android já soltou a captura: pede de novo
		_recapturar_em = 0.0
		if _android and _arma_ligada and not _sem_captura:
			_recapturar.call_deferred()


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)


## Leva a mira para um ponto (ex.: centro ao começar algo novo).
func levar_para(p: Vector2) -> void:
	_garantir_inicio()
	pos = p
	bruta = p
	recuo = Vector2.ZERO


func centralizar() -> void:
	levar_para(_tela() * 0.5)
