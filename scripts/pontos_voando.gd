class_name PontosVoando
extends Node2D

## Os pontos de cada acerto saltando do alvo ("+80", "+200"...): nascem
## grandes, encolhem para o tamanho normal e sobem sumindo. Fica numa camada
## de tela (CanvasLayer) e recebe posições de tela. Tudo num desenho só; até
## 8 ao mesmo tempo; parado, não redesenha.

const MAX := 8
const VIDA := 1.0

var fonte: Font = null
var tamanho := 46

var _lista: Array[Dictionary] = []


## brilho: cor da borda clara por dentro do contorno (o ouro e a prata
## parecem metal); transparente = sem.
func mostrar(pos_tela: Vector2, texto: String, cor: Color, escala: float = 1.0, brilho := Color(0, 0, 0, 0)) -> void:
	if fonte == null:
		return
	_lista.append({"pos": pos_tela, "texto": texto, "cor": cor, "esc": clampf(escala, 0.6, 1.6), "t": 0.0, "brilho": brilho})
	while _lista.size() > MAX:
		_lista.pop_front()
	queue_redraw()


func _process(delta: float) -> void:
	if _lista.is_empty():
		return
	for p in _lista:
		p["t"] += delta
	while not _lista.is_empty() and _lista[0]["t"] > VIDA:
		_lista.pop_front()
	queue_redraw()


func _draw() -> void:
	if fonte == null:
		return
	for p in _lista:
		var t: float = p["t"]
		var k := t / VIDA
		var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - t / 0.14)
		var sobe := 90.0 * (1.0 - (1.0 - k) * (1.0 - k))
		var a := 1.0 - smoothstep(0.6, 1.0, k)
		var esc: float = p["esc"] * pop
		var texto: String = p["texto"]
		var largura := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
		draw_set_transform(p["pos"] + Vector2(0, -sobe), 0.0, Vector2(esc, esc))
		var base := Vector2(-largura * 0.5, tamanho * 0.35)
		draw_string_outline(fonte, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, 10, Color(0.02, 0.04, 0.08, 0.85 * a))
		var brilho: Color = p["brilho"]
		if brilho.a > 0.0:
			draw_string_outline(fonte, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, 4, Color(brilho, brilho.a * a))
		draw_string(fonte, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, Color(p["cor"], a))
	draw_set_transform(Vector2.ZERO)
