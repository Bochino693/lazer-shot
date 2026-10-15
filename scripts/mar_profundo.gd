extends Node2D

# Profundidade do Mar (2,5D). A cena tem três planos, como uma câmera de
# verdade olhando para onde a arma aponta:
#
#   fundo   a foto (com toda a vida dela) anda um pouco PARA O LADO da mira e
#           balança de leve, como quem está debaixo d'água
#   alvos   ficam onde estão na tela (a mira continua justa)
#   frente  (este nó) algas escuras e desfocadas nos cantos de baixo, bolhas
#           grandes subindo devagar e, de vez em quando, a sombra de um peixe
#           grande passando bem perto; anda mais e PARA O OUTRO LADO
#
# O que está atrás dos alvos vai com a mira e o que está na frente vai contra:
# é o que o olho espera quando a cabeça se mexe, e dá a sensação de fundo.
# Leve para a TV box: 4 sprites de alga, 1 peixe, 1 sistema de partículas,
# nenhum shader. As artes vêm de tools/gerar_mar_frente.py.

# load() e não preload(): o Godot 4.6 nunca descarrega um script já carregado.
var ALGA: Texture2D = load("res://sprites/mar_frente_alga.png")
var PEIXE: Texture2D = load("res://sprites/mar_frente_peixe.png")
var BOLHA: Texture2D = load("res://sprites/mar_bolha.png")

# Câmera: com a mira no canto, ela anda CAMERA_PASSO px; uma coisa à
# distância Z anda CAMERA_PASSO * (1 - 1/Z) na tela (Z = 1, o plano dos alvos,
# fica parado; longe anda com a mira, perto anda contra). O fundo anda
# inteiro como a parte mais longe (Z_FUNDO), com as pedras e tudo que está
# pintado nele: nada se desloca da pintura (sem recorte nem remendo
# aparecendo); os alvos andam cada um pela distância dele.
const CAMERA_PASSO := 26.0
const Z_FUNDO := 8.0
const Z_FRENTE := 0.32
const SUAVE := 2.6             # quanto mais alto, mais rápido segue a mira
# algas de cada canto: x (fração da largura), escala, inclinação (graus), cor
const ALGAS := [
	[-0.03, 0.74, -7.0, 0.85], [0.08, 0.54, 5.0, 1.0],
	[1.03, 0.78, 8.0, 0.85], [0.92, 0.56, -4.0, 1.0],
]

## O fundo (Sprite2D da foto) e onde ele fica parado (o mar.gd preenche a
## cada ajuste de tela) e o ponto da mira na tela (a cada quadro).
var fundo: Node2D = null
var fundo_base := Vector2.ZERO
var mira := Vector2.ZERO

## Chamado a cada quadro com (câmera em px de tela, 1/Z do fundo): o fundo
## vivo (scripts/mar_vida.gd) move as pedras, cada uma na distância dela.
var ao_mover: Callable

var _tela := Vector2.ZERO
var _c := Vector2.ZERO          # quanto a câmera andou (px de tela)
var _olhar := Vector2.ZERO     # -1..1, suavizado
var _t := 0.0
var _algas: Array = []         # {no, rot, fase, freq, amp}
var _bolhas: CPUParticles2D = null
var _peixe: Sprite2D = null
var _peixe_espera := 9.0
var _peixe_t := -1.0
var _peixe_dur := 4.0
var _peixe_de := Vector2.ZERO
var _peixe_para := Vector2.ZERO


func _ready() -> void:
	name = "Profundidade"
	for d in ALGAS:
		var s := Sprite2D.new()
		s.texture = ALGA
		s.centered = false
		# o pé da alga é o ponto de giro (ela balança presa embaixo)
		s.offset = Vector2(-ALGA.get_width() * 0.5, -ALGA.get_height())
		s.flip_h = float(d[0]) > 0.5
		s.scale = Vector2.ONE * float(d[1])
		var c := float(d[3])
		s.modulate = Color(c, c, c, 0.94)
		add_child(s)
		_algas.append({"no": s, "x": float(d[0]), "rot": deg_to_rad(float(d[2])), "fase": randf() * TAU,
			"freq": randf_range(0.45, 0.7), "amp": deg_to_rad(randf_range(2.0, 3.4))})

	_bolhas = CPUParticles2D.new()
	_bolhas.amount = 9
	_bolhas.lifetime = 11.0
	_bolhas.preprocess = 11.0
	_bolhas.texture = BOLHA
	_bolhas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_bolhas.direction = Vector2(0, -1)
	_bolhas.spread = 8.0
	_bolhas.gravity = Vector2(0, -5)
	_bolhas.initial_velocity_min = 60.0
	_bolhas.initial_velocity_max = 120.0
	_bolhas.tangential_accel_min = -12.0
	_bolhas.tangential_accel_max = 12.0
	_bolhas.scale_amount_min = 0.7
	_bolhas.scale_amount_max = 1.6
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.12, 0.8, 1.0])
	rampa.colors = PackedColorArray([Color(0.8, 0.95, 1.0, 0.0), Color(0.8, 0.95, 1.0, 0.30),
		Color(0.8, 0.95, 1.0, 0.22), Color(0.8, 0.95, 1.0, 0.0)])
	_bolhas.color_ramp = rampa
	add_child(_bolhas)

	_peixe = Sprite2D.new()
	_peixe.texture = PEIXE
	_peixe.visible = false
	add_child(_peixe)


## Põe as algas nos cantos e as bolhas na largura da tela.
func montar(tela: Vector2) -> void:
	_tela = tela
	for a in _algas:
		var no: Sprite2D = a["no"]
		no.position = Vector2(float(a["x"]) * tela.x, tela.y + 30.0)
	_bolhas.position = Vector2(tela.x * 0.5, tela.y + 60.0)
	_bolhas.emission_rect_extents = Vector2(tela.x * 0.55, 10.0)


func _process(delta: float) -> void:
	if _tela == Vector2.ZERO:
		return
	_t += delta
	var meio := _tela * 0.5
	var alvo := ((mira - meio) / meio).clamp(Vector2(-1, -1), Vector2(1, 1))
	_olhar = _olhar.lerp(alvo, 1.0 - exp(-delta * SUAVE))
	_c = _olhar * CAMERA_PASSO
	# a frente anda contra a mira; o fundo, a favor (e balança na água)
	position = paralaxe(Z_FRENTE)
	if fundo != null and is_instance_valid(fundo):
		var balanco := Vector2(4.0 * sin(_t * 0.31), 3.0 * sin(_t * 0.23 + 1.2))
		fundo.position = fundo_base + paralaxe(Z_FUNDO) + balanco
		if ao_mover.is_valid():
			ao_mover.call(_c, 1.0 / Z_FUNDO)

	for a in _algas:
		var no: Sprite2D = a["no"]
		no.rotation = a["rot"] + a["amp"] * sin(_t * a["freq"] + a["fase"]) \
			+ a["amp"] * 0.4 * sin(_t * a["freq"] * 2.3 + a["fase"] * 1.7)

	_animar_peixe(delta)


## Quanto uma coisa à distância z anda na tela agora (px).
func paralaxe(z: float) -> Vector2:
	return _c * (1.0 - 1.0 / maxf(z, 0.05))


## O mesmo, descontado o que o fundo inteiro já andou (para o que é medido em
## cima do fundo, como a porta do templo).
func paralaxe_no_fundo(z: float) -> Vector2:
	return _c * (1.0 / Z_FUNDO - 1.0 / maxf(z, 0.05))


## A sombra de um peixe grande passa bem perto, de um lado ao outro, na metade
## de baixo da tela; meio transparente (não esconde os alvos).
func _animar_peixe(delta: float) -> void:
	if _peixe_t < 0.0:
		_peixe_espera -= delta
		if _peixe_espera > 0.0:
			return
		var para_direita := randf() < 0.5
		var y := randf_range(0.58, 0.84) * _tela.y
		var esc := randf_range(1.25, 1.6)
		var margem := PEIXE.get_width() * esc * 0.6
		_peixe_de = Vector2(-margem if para_direita else _tela.x + margem, y)
		_peixe_para = Vector2(_tela.x + margem if para_direita else -margem, y + randf_range(-90.0, 90.0))
		_peixe_dur = randf_range(3.4, 4.6)
		_peixe.flip_h = not para_direita
		_peixe.scale = Vector2.ONE * esc
		_peixe.visible = true
		_peixe_t = 0.0
		return
	_peixe_t += delta
	var k := _peixe_t / _peixe_dur
	if k >= 1.0:
		_peixe.visible = false
		_peixe_t = -1.0
		_peixe_espera = randf_range(14.0, 24.0)
		return
	# nada em impulsos (a cauda), sobe e desce de leve
	var andar := k + 0.015 * sin(_peixe_t * 7.0)
	_peixe.position = _peixe_de.lerp(_peixe_para, andar) + Vector2(0, 10.0 * sin(_peixe_t * 2.2))
	_peixe.rotation = 0.05 * sin(_peixe_t * 2.2 + 0.8) * (-1.0 if _peixe.flip_h else 1.0)
	_peixe.modulate = Color(1, 1, 1, 0.42 * smoothstep(0.0, 0.12, k) * smoothstep(1.0, 0.85, k))
