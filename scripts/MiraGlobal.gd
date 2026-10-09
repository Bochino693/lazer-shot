extends Node

## Ritmo de quadros e A MIRA DO JOGO INTEIRO.
##
## A arma funciona como mouse. Antes cada tela tinha a sua mira: umas somavam
## o movimento com o ponteiro capturado, outras liam o cursor do sistema com o
## ponteiro oculto, e cada troca de tela recentralizava a mira e ligava e
## desligava a captura do ponteiro no Android (saltos e perda de movimento).
##
## Agora há UMA mira, aqui:
## - o ponteiro fica sempre capturado (nenhuma tela troca o modo);
## - cada movimento da arma (já corrigido para a tela em pé pelo Tela.gd) soma
##   na posição, com a sensibilidade da configuração;
## - um filtro leve tira o tremor da mão com a arma parada e segue sem atraso
##   quando ela se move rápido (filtro "One Euro");
## - a posição continua a mesma entre as telas.
## Cada tela lê `MiraGlobal.pos` e desenha/acerta exatamente ali.

## No PC o jogo vai a 120 quadros; na TV Box só o vsync manda (ver abaixo).
const FPS_ALVO: int = 120

const META_SENS_MOUSE := "sensibilidade_mouse"

# Filtro anti-tremor (One Euro): corte mínimo (Hz) com a arma parada e quanto
# o corte sobe com a velocidade (px/s). Parado: suaviza; rápido: segue junto.
const FILTRO_CORTE_MIN := 5.0
const FILTRO_BETA := 0.012
const FILTRO_CORTE_VELOCIDADE := 1.5

## Posição da mira (filtrada), em coordenadas da tela do jogo (em pé).
var pos := Vector2.ZERO
## Posição sem filtro (soma direta dos movimentos).
var bruta := Vector2.ZERO

var _iniciada := false
var _vel := Vector2.ZERO
var _sens := 1.0


func _ready() -> void:
	_forcar_120_fps()
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100   # atualiza antes das telas lerem
	# Depois do Tela.gd (autoload anterior), que corrige o giro do evento.
	get_tree().root.window_input.connect(_ao_evento)
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


func _tela() -> Vector2:
	return get_tree().root.get_visible_rect().size


func _garantir_inicio() -> void:
	if _iniciada:
		return
	var tela := _tela()
	if tela.x <= 0.0:
		return
	_iniciada = true
	bruta = tela * 0.5
	pos = bruta


func _ao_evento(ev: InputEvent) -> void:
	if not (ev is InputEventMouseMotion):
		return
	_garantir_inicio()
	var tela := _tela()
	bruta += (ev as InputEventMouseMotion).relative * _sens
	bruta = Vector2(clampf(bruta.x, 0.0, tela.x), clampf(bruta.y, 0.0, tela.y))


func _process(delta: float) -> void:
	_garantir_inicio()
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_sens = clampf(float(get_tree().get_meta(META_SENS_MOUSE, 1.0)), 0.2, 3.0)

	var tela := _tela()
	bruta = Vector2(clampf(bruta.x, 0.0, tela.x), clampf(bruta.y, 0.0, tela.y))

	var te := maxf(delta, 0.001)
	_vel = _vel.lerp((bruta - pos) / te, _alfa(FILTRO_CORTE_VELOCIDADE, te))
	var corte := FILTRO_CORTE_MIN + FILTRO_BETA * _vel.length()
	pos = pos.lerp(bruta, _alfa(corte, te))
	if pos.distance_squared_to(bruta) < 0.01:
		pos = bruta


static func _alfa(corte_hz: float, te: float) -> float:
	var tau := 1.0 / (TAU * corte_hz)
	return 1.0 / (1.0 + tau / te)


## Leva a mira para um ponto (ex.: centro ao começar algo novo).
func levar_para(p: Vector2) -> void:
	_garantir_inicio()
	bruta = p
	pos = p
	_vel = Vector2.ZERO


func centralizar() -> void:
	levar_para(_tela() * 0.5)
