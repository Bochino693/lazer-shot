class_name AvisoTiro
extends Node2D

## Avisos do tiro sem atrapalhar quem joga (no lugar das faixas antigas do
## rodapé):
##   mostrar()    o resultado do tiro (ERROU, PEDRA, SPLASH...): letra média,
##                cor suave e sem faixa, nasce um pouco acima do ponto do tiro
##                (não cobre a mira nem o alvo), sobe um tico e some em 0,8 s
##   instrucao()  recado do jogo (a ordem das cores da Arena...): numa pílula
##                discreta logo abaixo do placar, some sozinha
##   pontos()     os pontos de um acerto saltando do alvo (PontosVoando)
## Uma camada de tela por fase; um desenho só; parado, não redesenha.

const VIDA := 0.8
const VIDA_INSTRUCAO := 2.4
const MAX := 4
const TAMANHO := 30
const TAMANHO_INSTRUCAO := 26
const Y_INSTRUCAO := 152.0        # logo abaixo do placar

var _fonte: Font
var _lista: Array[Dictionary] = []
var _instrucao := {}
var _pontos: PontosVoando


static func _no(fase: Node) -> AvisoTiro:
	if fase == null or not fase.is_inside_tree():
		return null
	var camada := fase.get_node_or_null("AvisoTiro") as CanvasLayer
	if camada == null:
		camada = CanvasLayer.new()
		camada.name = "AvisoTiro"
		camada.layer = 16
		var no := AvisoTiro.new()
		no.name = "Avisos"
		camada.add_child(no)
		fase.add_child(camada)
	return camada.get_child(0) as AvisoTiro


## pos_tela: o ponto do tiro na tela.
static func mostrar(fase: Node, pos_tela: Vector2, texto: String, cor := Color(1.0, 0.82, 0.78)) -> void:
	var no := _no(fase)
	if no == null or texto.strip_edges() == "":
		return
	no._lista.append({"pos": pos_tela, "texto": texto, "cor": cor, "t": 0.0})
	while no._lista.size() > MAX:
		no._lista.pop_front()
	no.set_process(true)
	no.queue_redraw()


static func pontos(fase: Node, pos_tela: Vector2, texto: String, cor: Color, brilho := Color(0, 0, 0, 0)) -> void:
	var no := _no(fase)
	if no == null:
		return
	if no._pontos == null:
		no._pontos = PontosVoando.new()
		no._pontos.fonte = load("res://fonts/Exo2-ExtraBold.ttf") as Font
		no.get_parent().add_child(no._pontos)
	no._pontos.mostrar(pos_tela, texto, cor, 1.0, brilho)


static func instrucao(fase: Node, texto: String, cor := Color(0.85, 0.95, 1.0)) -> void:
	var no := _no(fase)
	if no == null:
		return
	if not no._instrucao.is_empty() and no._instrucao["texto"] == texto:
		# o mesmo recado de novo (ex.: RECARREGUE enquanto falta bala): só
		# continua na tela, sem piscar
		no._instrucao["t"] = minf(no._instrucao["t"], 0.15)
		no.set_process(true)
		return
	no._instrucao = {"texto": texto, "cor": cor, "t": 0.0}
	no.set_process(true)
	no.queue_redraw()


func _ready() -> void:
	_fonte = load("res://fonts/Exo2-Bold.ttf") as Font
	if _fonte == null:
		_fonte = ThemeDB.fallback_font
	set_process(false)


func _process(delta: float) -> void:
	for p in _lista:
		p["t"] += delta
	while not _lista.is_empty() and _lista[0]["t"] > VIDA:
		_lista.pop_front()
	if not _instrucao.is_empty():
		_instrucao["t"] += delta
		if _instrucao["t"] > VIDA_INSTRUCAO:
			_instrucao = {}
	queue_redraw()
	if _lista.is_empty() and _instrucao.is_empty():
		set_process(false)


func _draw() -> void:
	if _fonte == null:
		return
	var tela := get_viewport_rect().size
	for p in _lista:
		var k: float = p["t"] / VIDA
		var a := minf(1.0, p["t"] / 0.08) * (1.0 - smoothstep(0.55, 1.0, k))
		var texto: String = p["texto"]
		var larg := _fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO).x
		var pos: Vector2 = p["pos"] + Vector2(0.0, -70.0 - 26.0 * k)
		pos.x = clampf(pos.x, larg * 0.5 + 16.0, tela.x - larg * 0.5 - 16.0)
		pos.y = clampf(pos.y, 170.0, tela.y - 30.0)
		var base := pos + Vector2(-larg * 0.5, TAMANHO * 0.35)
		draw_string_outline(_fonte, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO, 6, Color(0.02, 0.03, 0.06, 0.55 * a))
		draw_string(_fonte, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO, Color(p["cor"], 0.9 * a))
	if not _instrucao.is_empty():
		var t: float = _instrucao["t"]
		var a2 := minf(1.0, t / 0.15) * (1.0 - smoothstep(VIDA_INSTRUCAO - 0.4, VIDA_INSTRUCAO, t))
		var texto2: String = _instrucao["texto"]
		var larg2 := _fonte.get_string_size(texto2, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO_INSTRUCAO).x
		var caixa := Rect2(Vector2(tela.x * 0.5 - larg2 * 0.5 - 22.0, Y_INSTRUCAO - 22.0), Vector2(larg2 + 44.0, 44.0))
		draw_rect(caixa, Color(0.02, 0.03, 0.06, 0.55 * a2))
		draw_rect(caixa, Color(_instrucao["cor"], 0.35 * a2), false, 2.0)
		draw_string(_fonte, Vector2(caixa.position.x + 22.0, Y_INSTRUCAO + TAMANHO_INSTRUCAO * 0.35), texto2,
			HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO_INSTRUCAO, Color(_instrucao["cor"], 0.92 * a2))
