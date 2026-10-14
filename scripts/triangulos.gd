class_name Triangulos
extends RefCounted

## Junta formas sem textura (retângulos, elipses, polígonos, linhas grossas)
## num arranjo de triângulos com a cor em cada vértice e desenha tudo numa
## chamada só (RenderingServer.canvas_item_add_triangle_array). Na TV Box
## cada draw_circle / draw_colored_polygon / draw_polyline era uma chamada
## de desenho; os efeitos com dezenas deles pesavam.

var pontos := PackedVector2Array()
var cores := PackedColorArray()
var indices := PackedInt32Array()


func retangulo(r: Rect2, cor: Color) -> void:
	var i := pontos.size()
	pontos.append_array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	for k in 4:
		cores.append(cor)
	indices.append_array([i, i + 1, i + 2, i, i + 2, i + 3])


func elipse(c: Vector2, raio: Vector2, cor: Color, lados: int = 12) -> void:
	var i := pontos.size()
	pontos.append(c)
	cores.append(cor)
	for k in lados:
		var a := TAU * k / lados
		pontos.append(c + Vector2(cos(a) * raio.x, sin(a) * raio.y))
		cores.append(cor)
	for k in lados:
		indices.append_array([i, i + 1 + k, i + 1 + (k + 1) % lados])


## Polígono convexo (em leque a partir do primeiro ponto).
func poligono(pts: PackedVector2Array, cor: Color) -> void:
	if pts.size() < 3:
		return
	var i := pontos.size()
	pontos.append_array(pts)
	for k in pts.size():
		cores.append(cor)
	for k in range(1, pts.size() - 1):
		indices.append_array([i, i + k, i + k + 1])


## Linha grossa passando pelos pontos (faixa de quadriláteros).
func linha(pts: PackedVector2Array, cor: Color, largura: float) -> void:
	if pts.size() < 2:
		return
	var i := pontos.size()
	var meia := largura * 0.5
	for k in pts.size():
		var d := (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
		var n := Vector2(-d.y, d.x) * meia
		pontos.append(pts[k] + n)
		pontos.append(pts[k] - n)
		cores.append(cor)
		cores.append(cor)
	for k in pts.size() - 1:
		var a := i + k * 2
		indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])


func desenhar(no: CanvasItem) -> void:
	if indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(no.get_canvas_item(), indices, pontos, cores)
