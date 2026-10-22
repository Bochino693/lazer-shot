extends CanvasLayer
class_name Avisos

## Os avisos do tiro sem atrapalhar quem joga:
##   mostrar()    o resultado do tiro (ERROU!, PEDRA!, SPLASH...): letra média,
##                nasce um pouco acima do ponto do tiro, sobe e some em 0,8 s
##   pontos()     os pontos de um acerto saltando do alvo ("+80"): nascem
##                grandes, assentam e sobem sumindo
##   instrucao()  recado do jogo numa pílula discreta logo abaixo do placar
## Tudo num desenho só; parado, não redesenha.

const VIDA = 0.8
const VIDA_PONTOS = 1.0
const VIDA_INSTRUCAO = 2.4
const Y_INSTRUCAO = 152.0

var _no: Node2D
var _lista = []
var _pts = []
var _instrucao = {}
var _f_aviso: DynamicFont
var _f_pontos: DynamicFont
var _f_instr: DynamicFont
var _pilula: StyleBoxFlat


static func criar(pai: Node, camada: int = 55) -> Avisos:
	var a = load("res://scripts/avisos.gd").new()
	a.layer = camada
	pai.add_child(a)
	return a


func _ready() -> void:
	_f_aviso = Estilo.fonte(32, true, 4)
	_f_pontos = Estilo.fonte(48, true, 6)
	_f_instr = Estilo.fonte(28, false, 0)
	_pilula = Estilo.caixa(Color(0, 0, 0, 0.62), Color(1, 1, 1, 0.18), 1, 20)
	_no = Node2D.new()
	_no.connect("draw", self, "_desenhar")
	add_child(_no)
	set_process(false)
	# letras prontas antes do primeiro tiro
	Estilo.aquecer_fonte(_f_aviso)
	Estilo.aquecer_fonte(_f_pontos)
	Estilo.aquecer_fonte(_f_instr)


func mostrar(pos: Vector2, texto: String, cor: Color = Color(1.0, 0.82, 0.78)) -> void:
	if texto.strip_edges() == "":
		return
	for i in range(_lista.size() - 1, -1, -1):
		if (_lista[i]["pos"] as Vector2).distance_to(pos) < 160.0:
			_lista.remove(i)
	_lista.append({"pos": pos, "texto": texto, "cor": cor, "t": 0.0})
	while _lista.size() > 4:
		_lista.pop_front()
	set_process(true)


func pontos(pos: Vector2, texto: String, cor: Color, escala: float = 1.0) -> void:
	_pts.append({"pos": pos, "texto": texto, "cor": cor, "esc": clamp(escala, 0.6, 1.6), "t": 0.0})
	while _pts.size() > 8:
		_pts.pop_front()
	set_process(true)


func instrucao(texto: String, cor: Color = Color(1, 1, 1)) -> void:
	_instrucao = {"texto": texto, "cor": cor, "t": 0.0}
	set_process(true)


func _process(delta: float) -> void:
	for a in _lista:
		a["t"] += delta
	while not _lista.empty() and _lista[0]["t"] > VIDA:
		_lista.pop_front()
	for p in _pts:
		p["t"] += delta
	while not _pts.empty() and _pts[0]["t"] > VIDA_PONTOS:
		_pts.pop_front()
	if not _instrucao.empty():
		_instrucao["t"] += delta
		if _instrucao["t"] > VIDA_INSTRUCAO:
			_instrucao = {}
	_no.update()
	if _lista.empty() and _pts.empty() and _instrucao.empty():
		set_process(false)


func _texto_centro(f: Font, centro: Vector2, texto: String, cor: Color) -> void:
	var tam = f.get_string_size(texto)
	_no.draw_string(f, Vector2(centro.x - tam.x * 0.5, centro.y + f.get_ascent() * 0.5 - 4.0), texto, cor)


func _desenhar() -> void:
	for a in _lista:
		var k: float = a["t"] / VIDA
		var cor: Color = a["cor"]
		cor.a = clamp((1.0 - k) * 2.5, 0.0, 1.0) * clamp(a["t"] * 12.0, 0.0, 1.0)
		var p: Vector2 = a["pos"] + Vector2(0, -78.0 - 40.0 * k)
		_texto_centro(_f_aviso, p, a["texto"], cor)
	for p in _pts:
		var t: float = p["t"]
		var k = t / VIDA_PONTOS
		var s: float = p["esc"] * (1.0 + 0.6 * max(0.0, 1.0 - t * 7.0))
		var cor: Color = p["cor"]
		cor.a = clamp((1.0 - k) * 2.2, 0.0, 1.0)
		var c: Vector2 = p["pos"] + Vector2(0, -40.0 - 90.0 * k)
		_no.draw_set_transform(c, 0.0, Vector2(s, s))
		_texto_centro(_f_pontos, Vector2.ZERO, p["texto"], cor)
		_no.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not _instrucao.empty():
		var t: float = _instrucao["t"]
		var a = clamp(t * 6.0, 0.0, 1.0) * clamp((VIDA_INSTRUCAO - t) * 3.0, 0.0, 1.0)
		var tam = _f_instr.get_string_size(_instrucao["texto"])
		var r = Rect2(Vector2((Tela.TELA.x - tam.x) * 0.5 - 26.0, Y_INSTRUCAO - 4.0), Vector2(tam.x + 52.0, tam.y + 14.0))
		_no.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_pilula.bg_color = Color(0, 0, 0, 0.62 * a)
		_pilula.border_color = Color(1, 1, 1, 0.18 * a)
		_no.draw_style_box(_pilula, r)
		var cor: Color = _instrucao["cor"]
		cor.a = a
		_texto_centro(_f_instr, r.position + r.size * 0.5, _instrucao["texto"], cor)
