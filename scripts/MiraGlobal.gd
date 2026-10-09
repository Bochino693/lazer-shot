extends Node

const TEXTURA_MIRA: String = "res://sprites/mira.png"
const ESCALA_PADRAO: float = 4.0

## Trava o jogo em 120 FPS em qualquer tela/monitor, independente do que
## estiver salvo em Project Settings -- garante isso via código assim que
## o autoload inicializa, então nunca depende de configuração esquecida.
const FPS_ALVO: int = 120

const VELOCIDADE_XBOX_PADRAO: float = 4500.0
const DEADZONE_XBOX_PADRAO: float = 0.18

const TEMPO_ACEL_MAX: float = 0.55
const FATOR_ACEL_MAX: float = 1.85

var canvas: CanvasLayer
var sprite: Sprite2D
var escala_atual: float = ESCALA_PADRAO
var velocidade_xbox: float = VELOCIDADE_XBOX_PADRAO
var deadzone_xbox: float = DEADZONE_XBOX_PADRAO
var posicao: Vector2 = Vector2.ZERO
var modo_xbox: bool = false
var _tempo_stick_empurrado: float = 0.0


func _ready() -> void:
	_forcar_120_fps()

	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	sprite = Sprite2D.new()
	# opcional: cada tela desenha a própria mira (Pincel.mira)
	if ResourceLoader.exists(TEXTURA_MIRA):
		sprite.texture = load(TEXTURA_MIRA)
	sprite.scale = Vector2(escala_atual, escala_atual)
	sprite.z_index = 1000
	sprite.visible = false
	canvas.add_child(sprite)

	posicao = canvas.get_viewport().get_visible_rect().size * 0.5


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


func _process(delta: float) -> void:
	if not sprite.visible:
		return

	var vp := canvas.get_viewport()
	var tela: Vector2 = vp.get_visible_rect().size

	var tem_xbox: bool = Input.get_connected_joypads().size() > 0
	var stick_ativo: bool = false

	if tem_xbox:
		var ex: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		var ey: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
		if abs(ex) < deadzone_xbox: ex = 0.0
		if abs(ey) < deadzone_xbox: ey = 0.0
		var mov := Vector2(ex, ey)
		var magnitude: float = clampf(mov.length(), 0.0, 1.0)

		if magnitude > 0.0:
			stick_ativo = true
			_tempo_stick_empurrado = min(_tempo_stick_empurrado + delta, TEMPO_ACEL_MAX)
			var acel: float = 1.0 + (_tempo_stick_empurrado / TEMPO_ACEL_MAX) * (FATOR_ACEL_MAX - 1.0)
			var dir: Vector2 = mov.normalized()
			posicao += dir * magnitude * velocidade_xbox * acel * delta
		else:
			_tempo_stick_empurrado = 0.0

	if not stick_ativo:
		if modo_xbox:
			pass
		else:
			posicao = Tela.mouse()

	posicao.x = clampf(posicao.x, 0.0, tela.x)
	posicao.y = clampf(posicao.y, 0.0, tela.y)
	sprite.position = posicao


func mostrar() -> void:
	sprite.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func esconder() -> void:
	sprite.visible = false

func set_escala(novo: float) -> void:
	escala_atual = novo
	sprite.scale = Vector2(novo, novo)

func set_velocidade_xbox(v: float) -> void:
	velocidade_xbox = max(200.0, v)

func set_deadzone(v: float) -> void:
	deadzone_xbox = clampf(v, 0.05, 0.5)

func set_modo_xbox(ativo: bool) -> void:
	modo_xbox = ativo
	if ativo:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func get_posicao() -> Vector2:
	return posicao

func set_posicao(pos: Vector2) -> void:
	posicao = pos

func centralizar() -> void:
	var tela: Vector2 = canvas.get_viewport().get_visible_rect().size
	posicao = tela * 0.5

func set_textura(caminho: String) -> void:
	if ResourceLoader.exists(caminho):
		sprite.texture = load(caminho)
