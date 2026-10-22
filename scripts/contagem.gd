extends CanvasLayer
class_name Contagem

## Contagem 3, 2, 1 antes da partida: o número entra grande e assenta, um
## anel de luz abre em volta, a tela ganha a cor da fase e um bip marca cada
## número. No fim sai o sinal `terminou`.

signal terminou

var _cor = Color.white
var _raiz: Control
var _tinta: ColorRect
var _num: Label
var _anel: Sprite
var _som: AudioStream


static func criar(pai: Node, cor: Color, centro_y: float = 910.0) -> Contagem:
	var c = load("res://scripts/contagem.gd").new()
	c._cor = cor
	c.layer = 95
	pai.add_child(c)
	c._num.rect_position.y = centro_y - 150.0
	c._anel.position.y = centro_y
	return c


func _init() -> void:
	_raiz = Control.new()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.rect_size = Tela.TELA
	add_child(_raiz)
	_tinta = ColorRect.new()
	_tinta.rect_size = Tela.TELA
	_tinta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_tinta)
	_anel = Sprite.new()
	_anel.position = Vector2(512, 910)
	add_child(_anel)
	_num = Label.new()
	_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_num.align = Label.ALIGN_CENTER
	_num.valign = Label.VALIGN_CENTER
	_num.rect_position = Vector2(0, 760)
	_num.rect_size = Vector2(1024, 300)
	_num.rect_pivot_offset = Vector2(512, 150)
	_raiz.add_child(_num)
	visible = false


func _ready() -> void:
	_anel.texture = Estilo.tex("fx_anel")
	_anel.material = Estilo.material_soma()
	# o número gigante tem a fonte só dele (fora da lista do Estilo): a folha
	# de letras desse tamanho ocupa 2048x2048 (e outra para o contorno) e é
	# solta logo que a contagem acaba
	var f = DynamicFont.new()
	f.font_data = load(Estilo.FONTE_FORTE)
	f.size = 240
	f.use_filter = true
	f.outline_size = 16
	f.outline_color = Color(0.05, 0.02, 0.02)
	_num.add_font_override("font", f)
	Estilo.aquecer_fonte(f, "321")
	_tinta.color = Color(_cor.r, _cor.g, _cor.b, 0.0)
	_som = load("res://songs/bip.wav")


func rodar() -> void:
	visible = true
	for n in [3, 2, 1]:
		_num.text = str(n)
		_num.add_color_override("font_color", _cor.linear_interpolate(Color.white, 0.35))
		_num.rect_scale = Vector2.ONE * 1.8
		_num.modulate.a = 0.0
		_anel.scale = Vector2.ONE * 1.2
		_anel.modulate = Color(_cor.r, _cor.g, _cor.b, 0.9)
		_tinta.color.a = 0.22
		Maquina.efeito(_som, -4.0, 1.0 + 0.12 * (3 - n))
		var tw = create_tween().set_parallel(true)
		tw.tween_property(_num, "rect_scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_num, "modulate:a", 1.0, 0.12)
		tw.tween_property(_anel, "scale", Vector2.ONE * 5.0, 0.7).set_ease(Tween.EASE_OUT)
		tw.tween_property(_anel, "modulate:a", 0.0, 0.7)
		tw.tween_property(_tinta, "color:a", 0.08, 0.7)
		yield(get_tree().create_timer(0.75), "timeout")
	var fim = create_tween().set_parallel(true)
	fim.tween_property(_num, "modulate:a", 0.0, 0.15)
	fim.tween_property(_tinta, "color:a", 0.0, 0.2)
	yield(fim, "finished")
	visible = false
	_num.text = ""
	_num.add_font_override("font", null)
	emit_signal("terminou")
