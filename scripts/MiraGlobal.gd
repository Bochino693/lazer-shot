extends Node

## Ritmo de quadros e A MIRA DO JOGO INTEIRO.
##
## A arma é um mouse com giroscópio. Há UMA mira, aqui, e cada tela lê
## `MiraGlobal.pos` e desenha/acerta exatamente ali.
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

var _iniciada := false
var _sens := 1.0
var _android := false
var _eventos := 0
var _ultimo_ponteiro := Vector2(INF, INF)
var _recapturar_em := 0.0


func _ready() -> void:
	_forcar_120_fps()
	_android = OS.get_name() == "Android"
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100   # atualiza antes das telas lerem
	# Depois do Tela.gd (autoload anterior), que corrige o giro do evento.
	get_tree().root.window_input.connect(_ao_evento)
	_cursor_invisivel()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _forcar_120_fps() -> void:
	# TV Box (Android): a TV é de 60 Hz e o Android sempre sincroniza com ela;
	# pedir 120 só gastaria processador e bateria de CPU sem quadro a mais.
	if OS.get_name() == "Android":
		# Só o vsync manda no ritmo (60 Hz, ou 50 Hz em saída PAL). Com o
		# limitador do motor também em 60, os dois brigam e de tempos em
		# tempos um quadro perde a vez: era a "travadinha" constante.
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
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
	_eventos += 1
	# soma o deslocamento já (a mira responde no mesmo quadro do movimento)
	var tela := _tela()
	pos += (ev as InputEventMouseMotion).relative * _sens
	pos = Vector2(clampf(pos.x, 0.0, tela.x), clampf(pos.y, 0.0, tela.y))
	bruta = pos


func _process(delta: float) -> void:
	_garantir_inicio()
	_sens = clampf(float(get_tree().get_meta(META_SENS_MOUSE, 1.0)), 0.2, 3.0)

	if _android:
		_conferir_captura(delta)

	var tela := _tela()
	pos = Vector2(clampf(pos.x, 0.0, tela.x), clampf(pos.y, 0.0, tela.y))
	bruta = pos
	_eventos = 0


## Capturado, o Android entrega o ponteiro parado e só o deslocamento; se a
## posição do ponteiro anda junto com os movimentos, a captura caiu.
func _conferir_captura(delta: float) -> void:
	var ponteiro: Vector2 = Tela.mouse()
	var andou := _ultimo_ponteiro.x != INF and ponteiro.distance_squared_to(_ultimo_ponteiro) > 0.25
	_ultimo_ponteiro = ponteiro
	if _eventos > 0:
		capturada = not andou
	if not capturada:
		# sem captura: a mira é o ponteiro real (alcança a tela inteira)
		if andou:
			pos = ponteiro
		_recapturar_em -= delta
		if _recapturar_em <= 0.0:
			_recapturar_em = INTERVALO_RECAPTURA
			_recapturar()


## Força o Godot a pedir a captura de novo (ele só pede quando o modo muda).
func _recapturar() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# ao voltar o foco o Android já soltou a captura: pede de novo
		_recapturar_em = 0.0
		if _android:
			_recapturar.call_deferred()


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)


## Leva a mira para um ponto (ex.: centro ao começar algo novo).
func levar_para(p: Vector2) -> void:
	_garantir_inicio()
	pos = p
	bruta = p


func centralizar() -> void:
	levar_para(_tela() * 0.5)
