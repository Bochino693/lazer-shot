extends CanvasLayer
class_name MiraDesenho

## A MIRA NA TELA (igual em todas as telas): a cruz com anel na cor da tela,
## um contorno escuro por baixo (aparece em qualquer fundo), um pulso a cada
## tiro e o anel da recarga enchendo em volta dela.
## Dois sprites que só mudam de lugar: quase nada por quadro.

const TAM = 96.0

var cor = Color(1.0, 0.25, 0.22) setget definir_cor

var _sombra: Sprite
var _cruz: Sprite
var _anel: Node2D
var _recarga = -1.0
var _pulso = 0.0


static func criar(pai: Node, c: Color, camada: int = 200) -> MiraDesenho:
	var m = load("res://scripts/mira_desenho.gd").new()
	m.layer = camada
	pai.add_child(m)
	m.definir_cor(c)
	return m


func _ready() -> void:
	var tex: Texture = Estilo.tex("ui_mira")
	var esc = TAM / tex.get_width()
	_sombra = Sprite.new()
	_sombra.texture = Estilo.tex("ui_mira_sombra")
	_sombra.modulate = Color(0, 0, 0, 0.55)
	_sombra.scale = Vector2.ONE * esc
	add_child(_sombra)
	_cruz = Sprite.new()
	_cruz.texture = tex
	_cruz.scale = Vector2.ONE * esc
	_cruz.modulate = cor
	add_child(_cruz)
	_anel = Node2D.new()
	_anel.connect("draw", self, "_desenhar_anel")
	add_child(_anel)


func definir_cor(c: Color) -> void:
	cor = c
	if _cruz != null:
		_cruz.modulate = c.linear_interpolate(Color.white, 0.12)


## A cada tiro: a mira dá um pulo.
func pulso() -> void:
	_pulso = 1.0


## Progresso da recarga (0..1); -1 esconde o anel.
func recarga(p: float) -> void:
	if p == _recarga:
		return
	_recarga = p
	_anel.update()


func _process(delta: float) -> void:
	var v: bool = MiraGlobal.ativa
	if _cruz.visible != v:
		_cruz.visible = v
		_sombra.visible = v
		_anel.visible = v
	if not v:
		return
	var p = MiraGlobal.mira()
	_cruz.position = p
	_sombra.position = p
	_anel.position = p
	if _pulso > 0.0:
		_pulso = max(0.0, _pulso - delta * 6.0)
		var s = (TAM / _cruz.texture.get_width()) * (1.0 + 0.22 * _pulso)
		_cruz.scale = Vector2.ONE * s
		_sombra.scale = _cruz.scale


func _desenhar_anel() -> void:
	if _recarga < 0.0:
		return
	var r = TAM * 0.62
	_anel.draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(0, 0, 0, 0.55), 9.0)
	_anel.draw_arc(Vector2.ZERO, r, -PI * 0.5, -PI * 0.5 + TAU * clamp(_recarga, 0.0, 1.0), 40, Color(0.35, 0.92, 1.0), 6.0)
