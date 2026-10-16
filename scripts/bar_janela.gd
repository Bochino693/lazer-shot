class_name BarJanela
extends Node2D

## A janela do bar (pintada no fundo, back_new.png): cada vidraça leva tiro.
##   - a vidraça estoura: o vidro racha do furo para fora e os cacos (recortados
##     do próprio vidro) saem girando, piscando quando pegam a luz, caem na
##     tábua de baixo (ou no peitoril), quicam, se partem e ficam deitados um
##     pouco; pó de vidro, faíscas de luz e lascas da madeira do caixilho;
##   - fica o buraco com as pontas de vidro presas na moldura (as bordas
##     cortadas brilhando) e a luz de fora entra mais forte: o feixe de sol
##     do bar cresce a cada vidraça quebrada;
##   - as vidraças do lado trincam com o tranco;
##   - tiro numa vidraça já quebrada derruba as pontas que sobraram perto
##     (no buraco, a bala sai lá fora).
## Filho do fundo, em px da textura (o fundo pode tremer e escalar junto).
## Só redesenha enquanto algo cai; parado, o desenho fica guardado.

const SOM := preload("res://songs/janela_quebra.wav")
const LODO := preload("res://sprites/mar_lodo.png")

# Vidraças da janela (px de back_new.png)
const VIDRACAS := [
	Rect2(90, 82, 48, 56), Rect2(144, 82, 46, 56), Rect2(211, 82, 47, 56), Rect2(264, 82, 46, 56),
	Rect2(90, 145, 48, 55), Rect2(144, 145, 46, 55), Rect2(211, 145, 47, 55), Rect2(264, 145, 46, 55),
]
# vizinhas da mesma folha da janela (trincam junto)
const VIZINHAS := [[1, 4], [0, 5], [3, 6], [2, 7], [0, 5], [1, 4], [2, 7], [3, 6]]
const PEITORIL := Vector3(58.0, 338.0, 205.0)   # x de, x até, y do tampo
const TABUA_Y := 279.0                          # tampo da tábua embaixo da janela
const GRAVIDADE := 1250.0
const FEIXE_FORCA := 0.46                       # forca do bar_sol.gdshader

enum { INTEIRA, TRINCADA, QUEBRADA }

var _estado: Array[int] = []
var _trincas: Array = []          # por vidraça: lista de PackedVector2Array
var _pontas: Array = []           # por vidraça: [{poly, livres}] (vidro preso na moldura)
var _cacos: Array[Dictionary] = []
var _miudos: Array[Dictionary] = []
var _po: Array[Dictionary] = []
var _lascas: Array[Dictionary] = []
var _clarao := 0.0                # o tiro acendendo a luz de fora (1 -> 0)
var _clarao_pos := Vector2.ZERO
var _tex: Texture2D
var _folha := Vector2.ONE
var _luz: Node2D                  # brilhos somados (clarão, buracos, faíscas)
var _brilho: Texture2D
var _feixe: ShaderMaterial


func _ready() -> void:
	name = "Janela"
	var fundo := get_parent() as Sprite2D
	if fundo == null or fundo.texture == null:
		set_process(false)
		return
	_tex = fundo.texture
	_folha = _tex.get_size()
	position = -_folha * 0.5 if fundo.centered else Vector2.ZERO
	for i in VIDRACAS.size():
		_estado.append(INTEIRA)
		_trincas.append([])
		_pontas.append([])
	_brilho = FundoVivo.brilho_redondo()
	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_luz = Node2D.new()
	_luz.name = "Luz"
	_luz.material = soma
	_luz.draw.connect(_desenhar_luz)
	add_child(_luz)
	set_process(false)


## Tiro que não pegou garrafa: se caiu numa vidraça, a janela responde e
## devolve true (sem furo de bala nem lascas de madeira por cima).
func tiro(pos_global: Vector2) -> bool:
	if _estado.is_empty():
		return false
	var p := to_local(pos_global)
	for i in VIDRACAS.size():
		var r: Rect2 = VIDRACAS[i]
		if not r.has_point(p):
			continue
		if _estado[i] == QUEBRADA:
			_soltar_pontas(i, p)
		else:
			_estourar(i, p)
		return true
	return false


func quebradas() -> int:
	return _estado.count(QUEBRADA)


# ───────────────────────────────────────────── a vidraça estourando
func _estourar(i: int, p: Vector2) -> void:
	var r: Rect2 = VIDRACAS[i]
	var c := p.clamp(r.position + Vector2(5, 5), r.end - Vector2(5, 5))
	var caixa := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	_estado[i] = QUEBRADA
	_trincas[i] = []
	# rachaduras saindo do furo (raios) e dois anéis: o miolo e o meio caem;
	# o que passa do segundo anel quase sempre fica preso na moldura
	var n := randi_range(7, 9)
	var giro0 := randf() * TAU
	var angs: Array[float] = []
	for k in n:
		angs.append(giro0 + TAU * (k + randf_range(-0.28, 0.28)) / n)
	var anel1: Array[float] = []
	var anel2: Array[float] = []
	for k in n:
		var borda := _ate_a_borda(c, Vector2.from_angle(angs[k]), r)
		anel1.append(borda * randf_range(0.28, 0.46))
		anel2.append(borda * randf_range(0.62, 0.86))
	var pontas: Array = []
	for k in n:
		var k2 := (k + 1) % n
		var a0 := angs[k]
		var a1 := angs[k2] + (TAU if k2 == 0 else 0.0)
		var am := (a0 + a1) * 0.5 + randf_range(-0.12, 0.12)
		var dm := Vector2.from_angle(am)
		var bm := _ate_a_borda(c, dm, r)
		var r1m := bm * randf_range(0.28, 0.46)
		var r2m := bm * randf_range(0.62, 0.86)
		var d0 := Vector2.from_angle(a0)
		var d1 := Vector2.from_angle(a1)
		var miolo := PackedVector2Array([c + d0 * 1.5, c + d0 * anel1[k], c + dm * r1m, c + d1 * anel1[k2], c + d1 * 1.5])
		var meio := PackedVector2Array([c + d0 * anel1[k], c + d0 * anel2[k], c + dm * r2m, c + d1 * anel2[k2], c + d1 * anel1[k2], c + dm * r1m])
		var fora := PackedVector2Array([c + d0 * anel2[k], c + d0 * 200.0, c + dm * 200.0, c + d1 * 200.0, c + d1 * anel2[k2], c + dm * r2m])
		for q in Geometry2D.intersect_polygons(miolo, caixa):
			_novo_caco(q, c, 1.0)
		for q in Geometry2D.intersect_polygons(meio, caixa):
			# o pedaço do meio às vezes parte em dois no caminho
			if randf() < 0.45 and q.size() >= 4:
				for metade in _partir(q):
					_novo_caco(metade, c, 0.8)
			else:
				_novo_caco(q, c, 0.8)
		for q in Geometry2D.intersect_polygons(fora, caixa):
			if randf() < 0.82:
				pontas.append({"poly": q, "livres": _arestas_livres(q, r)})
			else:
				_novo_caco(q, c, 0.55)
	_pontas[i] = pontas
	# pó de vidro, faíscas de luz e lascas do caixilho
	for k in 26:
		_miudos.append({
			"pos": c + Vector2(randf_range(-4, 4), randf_range(-4, 4)),
			"vel": Vector2.from_angle(randf() * TAU) * randf_range(60.0, 260.0) + Vector2(0, -40.0),
			"t": 0.0, "vida": randf_range(0.5, 1.1), "fase": randf() * TAU, "deitado": false,
		})
	for k in 4:
		_po.append({"pos": c + Vector2(randf_range(-6, 6), randf_range(-6, 6)), "vel": Vector2(randf_range(-30, 30), randf_range(-10, 40)),
			"t": 0.0, "vida": randf_range(0.7, 1.2), "tam": randf_range(26.0, 44.0), "ang": randf() * TAU})
	var lado := Vector2(r.position.x if c.x - r.position.x < r.end.x - c.x else r.end.x, c.y)
	for k in 7:
		_lascas.append({"pos": lado + Vector2(0, randf_range(-14, 14)),
			"vel": Vector2(randf_range(-120, 120), randf_range(-160, -30)), "ang": randf() * TAU, "giro": randf_range(-18, 18),
			"tam": Vector2(randf_range(3.0, 6.0), randf_range(1.0, 1.8)), "t": 0.0, "vida": randf_range(0.5, 0.9),
			"cor": Color(0.62, 0.36, 0.16).lerp(Color(0.92, 0.66, 0.38), randf())})
	# as vizinhas trincam com o tranco
	for v: int in VIZINHAS[i]:
		if _estado[v] == INTEIRA:
			_estado[v] = TRINCADA
			_trincas[v] = _trincar(VIDRACAS[v], VIDRACAS[i])
	_clarao = 1.0
	_clarao_pos = c
	Maquina.efeito(SOM, -2.0, randf_range(0.95, 1.06))
	_ligar()


func _soltar_pontas(i: int, p: Vector2) -> void:
	var r: Rect2 = VIDRACAS[i]
	var ficam: Array = []
	var soltou := 0
	for pt: Dictionary in _pontas[i]:
		var poly: PackedVector2Array = pt["poly"]
		var centro := _centro(poly)
		if centro.distance_to(p) < 22.0 + randf() * 8.0:
			_novo_caco(poly, p, 0.5)
			soltou += 1
		else:
			ficam.append(pt)
	_pontas[i] = ficam
	if soltou == 0:
		return     # a bala passou pelo buraco: foi lá para fora
	for k in 10:
		_miudos.append({"pos": p, "vel": Vector2.from_angle(randf() * TAU) * randf_range(50.0, 180.0),
			"t": 0.0, "vida": randf_range(0.4, 0.9), "fase": randf() * TAU, "deitado": false})
	_clarao = maxf(_clarao, 0.5)
	_clarao_pos = p.clamp(r.position, r.end)
	Maquina.efeito(SOM, -9.0, randf_range(1.2, 1.35))
	_ligar()


func _novo_caco(poly: PackedVector2Array, furo: Vector2, forca: float) -> void:
	if poly.size() < 3:
		return
	var centro := _centro(poly)
	var rel := PackedVector2Array()
	var uvs := PackedVector2Array()
	for v in poly:
		rel.append(v - centro)
		uvs.append(v / _folha)
	var tri := Geometry2D.triangulate_polygon(rel)
	if tri.is_empty():
		return
	var area := 0.0
	for k in range(0, tri.size(), 3):
		area += absf((rel[tri[k + 1]] - rel[tri[k]]).cross(rel[tri[k + 2]] - rel[tri[k]])) * 0.5
	var sai := (centro - furo)
	sai = sai.normalized() if sai.length() > 0.5 else Vector2.from_angle(randf() * TAU)
	# o miolo voa mais rápido; os grandes caem mais reto
	var vel := sai * randf_range(50.0, 170.0) * forca + Vector2(randf_range(-25, 25), randf_range(-70, 10))
	var chao := TABUA_Y
	if centro.x > PEITORIL.x and centro.x < PEITORIL.y and centro.y < PEITORIL.z and randf() < 0.35:
		chao = PEITORIL.z
	_cacos.append({
		"pos": centro, "vel": vel, "ang": 0.0, "giro": randf_range(-7.0, 7.0) / maxf(0.6, sqrt(area) / 8.0),
		"rel": rel, "uvs": uvs, "tri": tri, "area": area, "t": 0.0, "chao": chao, "toques": 0,
		"frente": 0.0, "deitado": 0.0, "fase": randf() * TAU,
	})
	while _cacos.size() > 70:
		_cacos.pop_front()


## Parte um polígono em dois por uma reta que passa perto do meio.
func _partir(q: PackedVector2Array) -> Array:
	var centro := _centro(q)
	var d := Vector2.from_angle(randf() * PI)
	var n := Vector2(-d.y, d.x)
	var faca := PackedVector2Array([centro - d * 300.0 - n * 0.0, centro + d * 300.0, centro + d * 300.0 + n * 300.0, centro - d * 300.0 + n * 300.0])
	var a := Geometry2D.clip_polygons(q, faca)
	var b := Geometry2D.intersect_polygons(q, faca)
	var saida: Array = []
	for x in a + b:
		if x.size() >= 3:
			saida.append(x)
	return saida if not saida.is_empty() else [q]


## Distância do ponto até a borda da vidraça andando na direção d.
func _ate_a_borda(c: Vector2, d: Vector2, r: Rect2) -> float:
	var t := 1e6
	if d.x > 1e-4:
		t = minf(t, (r.end.x - c.x) / d.x)
	elif d.x < -1e-4:
		t = minf(t, (r.position.x - c.x) / d.x)
	if d.y > 1e-4:
		t = minf(t, (r.end.y - c.y) / d.y)
	elif d.y < -1e-4:
		t = minf(t, (r.position.y - c.y) / d.y)
	return maxf(t, 2.0)


## Arestas da ponta presa que ficaram soltas (cortadas no vidro): são as que
## brilham. As encostadas na moldura não aparecem.
func _arestas_livres(q: PackedVector2Array, r: Rect2) -> PackedInt32Array:
	var livres := PackedInt32Array()
	for k in q.size():
		var a := q[k]
		var b := q[(k + 1) % q.size()]
		var na_borda := (absf(a.x - r.position.x) < 0.6 and absf(b.x - r.position.x) < 0.6) \
			or (absf(a.x - r.end.x) < 0.6 and absf(b.x - r.end.x) < 0.6) \
			or (absf(a.y - r.position.y) < 0.6 and absf(b.y - r.position.y) < 0.6) \
			or (absf(a.y - r.end.y) < 0.6 and absf(b.y - r.end.y) < 0.6)
		if not na_borda:
			livres.append(k)
	return livres


## Trincas numa vidraça vizinha: saem da beira que encosta na que quebrou.
func _trincar(r: Rect2, de: Rect2) -> Array:
	var ini: Vector2
	if absf(de.get_center().x - r.get_center().x) > absf(de.get_center().y - r.get_center().y):
		var x := r.position.x if de.get_center().x < r.get_center().x else r.end.x
		ini = Vector2(x, randf_range(r.position.y + 10, r.end.y - 10))
	else:
		var y := r.position.y if de.get_center().y < r.get_center().y else r.end.y
		ini = Vector2(randf_range(r.position.x + 10, r.end.x - 10), y)
	var linhas: Array = []
	var rumo := (r.get_center() - ini).normalized()
	for k in randi_range(2, 3):
		var pts := PackedVector2Array([ini])
		var d := rumo.rotated(randf_range(-0.8, 0.8))
		var p := ini
		for s in randi_range(3, 5):
			d = d.rotated(randf_range(-0.28, 0.28))
			p += d * randf_range(5.0, 11.0)
			if not r.grow(-1.0).has_point(p):
				break
			pts.append(p)
		if pts.size() >= 2:
			linhas.append(pts)
	return linhas


func _centro(q: PackedVector2Array) -> Vector2:
	var s := Vector2.ZERO
	for v in q:
		s += v
	return s / maxf(1.0, q.size())


# ───────────────────────────────────────────── movimento
func _ligar() -> void:
	set_process(true)
	queue_redraw()
	_luz.queue_redraw()


func _process(delta: float) -> void:
	_clarao = maxf(0.0, _clarao - delta * 2.6)
	for c in _cacos:
		c["t"] += delta
		if c["deitado"] > 0.0:
			continue
		c["vel"] += Vector2(0, GRAVIDADE) * delta
		c["pos"] += c["vel"] * delta
		c["ang"] += c["giro"] * delta
		c["frente"] = minf(1.0, c["frente"] + delta * 3.0)
		if c["pos"].y >= c["chao"] and c["vel"].y > 0.0:
			c["pos"].y = c["chao"]
			c["toques"] += 1
			_bater(c)
	for i in range(_cacos.size() - 1, -1, -1):
		if _cacos[i]["t"] > 3.6:
			_cacos.remove_at(i)
	for m in _miudos:
		m["t"] += delta
		if m["deitado"]:
			continue
		m["vel"] = m["vel"] * pow(0.35, delta) + Vector2(0, GRAVIDADE * 0.7) * delta
		m["pos"] += m["vel"] * delta
		if m["pos"].y >= TABUA_Y and m["vel"].y > 0.0:
			m["pos"].y = TABUA_Y
			m["deitado"] = true
			m["vida"] = m["t"] + randf_range(1.2, 2.4)
	for i in range(_miudos.size() - 1, -1, -1):
		if _miudos[i]["t"] >= _miudos[i]["vida"]:
			_miudos.remove_at(i)
	for p in _po:
		p["t"] += delta
		p["vel"] = p["vel"] * pow(0.2, delta)
		p["pos"] += p["vel"] * delta
	for i in range(_po.size() - 1, -1, -1):
		if _po[i]["t"] >= _po[i]["vida"]:
			_po.remove_at(i)
	for l in _lascas:
		l["t"] += delta
		l["vel"] += Vector2(0, GRAVIDADE) * delta
		l["pos"] += l["vel"] * delta
		l["ang"] += l["giro"] * delta
	for i in range(_lascas.size() - 1, -1, -1):
		if _lascas[i]["t"] >= _lascas[i]["vida"]:
			_lascas.remove_at(i)
	_ajustar_feixe()
	queue_redraw()
	_luz.queue_redraw()
	if _cacos.is_empty() and _miudos.is_empty() and _po.is_empty() and _lascas.is_empty() and _clarao <= 0.0:
		set_process(false)


## O caco bateu na tábua: quica mais baixo, o grande se parte, e no fim ele
## fica deitado (achatado de frente) brilhando um pouco antes de sumir.
func _bater(c: Dictionary) -> void:
	var v: Vector2 = c["vel"]
	for k in randi_range(2, 4):
		_miudos.append({"pos": c["pos"], "vel": Vector2(randf_range(-110, 110), randf_range(-150, -50)),
			"t": 0.0, "vida": randf_range(0.6, 1.4), "fase": randf() * TAU, "deitado": false})
	if c["toques"] >= 3 or absf(v.y) < 120.0:
		c["vel"] = Vector2.ZERO
		c["giro"] = 0.0
		c["deitado"] = 1.0
		c["t"] = maxf(c["t"], 1.4)
		return
	if c["toques"] == 1 and c["area"] > 70.0:
		# o grande se parte em dois na batida (cada metade sai do lugar onde
		# ela estava no caco, com o mesmo giro)
		var original := _poligono_original(c)
		var centro0 := _centro(original)
		var pedacos := _partir(original)
		if pedacos.size() >= 2:
			c["t"] = 99.0
			var esc := 1.0 + 0.25 * float(c["frente"])
			for q in pedacos:
				var antes := _cacos.size()
				_novo_caco(q, centro0, 0.0)
				if _cacos.size() > antes:
					var n: Dictionary = _cacos[-1]
					n["pos"] = c["pos"] + ((n["pos"] as Vector2) - centro0).rotated(c["ang"]) * esc
					n["ang"] = c["ang"]
					n["vel"] = Vector2(v.x * 0.5 + randf_range(-60, 60), -absf(v.y) * randf_range(0.2, 0.35))
					n["giro"] = randf_range(-6.0, 6.0)
					n["chao"] = c["chao"]
					n["toques"] = 1
					n["frente"] = c["frente"]
			return
	c["vel"] = Vector2(v.x * 0.55, -absf(v.y) * randf_range(0.22, 0.32))
	c["giro"] = c["giro"] * 0.5 + randf_range(-4.0, 4.0)


## O polígono do caco no lugar de origem dele no vidro (o mesmo recorte da
## textura, para partir sem trocar a imagem).
func _poligono_original(c: Dictionary) -> PackedVector2Array:
	var q := PackedVector2Array()
	for uv: Vector2 in c["uvs"]:
		q.append(uv * _folha)
	return q


func _ajustar_feixe() -> void:
	if _feixe == null:
		var f := get_parent().get_node_or_null("Sol/Feixe") as CanvasItem
		if f == null or not (f.material is ShaderMaterial):
			return
		_feixe = f.material
	var luz := 1.0 + 0.55 * float(quebradas()) / VIDRACAS.size() + 0.9 * _clarao * _clarao
	_feixe.set_shader_parameter("forca", FEIXE_FORCA * luz)


# ───────────────────────────────────────────── desenho
## O que não tem textura (degradês, bordas cortadas, trincas) sai em arranjos
## de triângulos (Triangulos), um por camada: cada draw_line/draw_polyline
## com antialias eram vários desenhos novos na placa a cada quadro.
func _draw() -> void:
	# buracos: a luz de fora, bem mais clara que o vidro fosco
	var luz_buracos := Triangulos.new()
	for i in VIDRACAS.size():
		if _estado[i] != QUEBRADA:
			continue
		var r: Rect2 = VIDRACAS[i]
		draw_texture_rect_region(_tex, r, r, Color(1.32, 1.27, 1.18))
		luz_buracos.poligono_cores(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([Color(1, 0.99, 0.95, 0.45), Color(1, 0.99, 0.95, 0.45), Color(1, 0.9, 0.7, 0.2), Color(1, 0.9, 0.7, 0.2)]))
	luz_buracos.desenhar(self)
	# pontas de vidro presas na moldura (o próprio vidro) e as bordas cortadas
	var pontos := PackedVector2Array()
	var cores := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in VIDRACAS.size():
		for pt: Dictionary in _pontas[i]:
			var q: PackedVector2Array = pt["poly"]
			var tri := Geometry2D.triangulate_polygon(q)
			var ini := pontos.size()
			for v in q:
				pontos.append(v)
				uvs.append(v / _folha)
				cores.append(Color(0.97, 0.95, 0.92))
			for k in tri:
				idx.append(ini + k)
	if not idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pontos, cores, uvs,
			PackedInt32Array(), PackedFloat32Array(), _tex.get_rid())
	var riscos := Triangulos.new()
	for i in VIDRACAS.size():
		for pt: Dictionary in _pontas[i]:
			var q: PackedVector2Array = pt["poly"]
			for k: int in pt["livres"]:
				var a := q[k]
				var b := q[(k + 1) % q.size()]
				riscos.reta(a, b, Color(0.42, 0.26, 0.12, 0.5), 1.6)
				riscos.reta(a, b, Color(1.0, 1.0, 0.96, 0.95), 0.9)
	# trincas nas vizinhas
	for i in VIDRACAS.size():
		if _estado[i] != TRINCADA:
			continue
		for linha: PackedVector2Array in _trincas[i]:
			riscos.linha(linha, Color(0.45, 0.3, 0.15, 0.22), 1.1)
			riscos.linha(linha, Color(1.0, 1.0, 0.97, 0.7), 0.6)
	riscos.desenhar(self)
	# pó de vidro no ar
	for p in _po:
		var k: float = p["t"] / p["vida"]
		var s: float = p["tam"] * (0.6 + 0.8 * k)
		draw_set_transform(p["pos"], p["ang"])
		draw_texture_rect(LODO, Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), false, Color(1.0, 0.97, 0.9, 0.4 * (1.0 - k)))
	draw_set_transform(Vector2.ZERO)
	# cacos caindo (um desenho só, recortados do vidro): piscam quando a face
	# pega a luz da janela; deitados na tábua, achatados
	pontos = PackedVector2Array()
	cores = PackedColorArray()
	uvs = PackedVector2Array()
	idx = PackedInt32Array()
	var bordas: Array[PackedVector2Array] = []
	for c in _cacos:
		var t: float = c["t"]
		if t > 3.6:
			continue
		var some := clampf((3.6 - t) / 0.5, 0.0, 1.0)
		var esc := 1.0 + 0.25 * float(c["frente"])
		var achata := 1.0 - 0.65 * float(c["deitado"])
		# vidro: deixa ver a parede por trás; a face que pega a luz acende
		var face := pow(absf(sin(float(c["ang"]) * 1.7 + float(c["fase"]))), 6.0)
		var luz := 0.9 + 0.6 * face
		var opaco := 0.5 + 0.42 * face
		if c["deitado"] > 0.0:
			var pisca := pow(absf(sin(t * 3.0 + float(c["fase"]))), 12.0)
			luz = 1.0 + 0.3 * pisca
			opaco = 0.22 + 0.4 * pisca
		var cor := Color(luz, luz, luz * 0.97, some * opaco)
		var ini := pontos.size()
		var borda := PackedVector2Array()
		var rel: PackedVector2Array = c["rel"]
		var uv: PackedVector2Array = c["uvs"]
		for k in rel.size():
			var v: Vector2 = (rel[k] * esc).rotated(c["ang"])
			v.y *= achata
			var w: Vector2 = c["pos"] + v
			pontos.append(w)
			uvs.append(uv[k])
			cores.append(cor)
			borda.append(w)
		for k in c["tri"]:
			idx.append(ini + k)
		borda.append(borda[0])
		if some > 0.3 and c["deitado"] <= 0.0:
			bordas.append(borda)
	if not idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pontos, cores, uvs,
			PackedInt32Array(), PackedFloat32Array(), _tex.get_rid())
	var contornos := Triangulos.new()
	for b in bordas:
		contornos.linha(b, Color(1.0, 1.0, 0.95, 0.75), 0.9)
	contornos.desenhar(self)
	# lascas de madeira do caixilho
	for l in _lascas:
		var k2: float = l["t"] / l["vida"]
		var tam: Vector2 = l["tam"]
		draw_set_transform(l["pos"], l["ang"])
		draw_rect(Rect2(-tam * 0.5, tam), Color(l["cor"], 1.0 - k2 * k2))
	draw_set_transform(Vector2.ZERO)


func _desenhar_luz() -> void:
	# a luz de fora vazando pelos buracos
	for i in VIDRACAS.size():
		if _estado[i] != QUEBRADA:
			continue
		var r: Rect2 = VIDRACAS[i]
		var s := r.size * 1.9
		_luz.draw_texture_rect(_brilho, Rect2(r.get_center() - s * 0.5, s), false, Color(1.0, 0.86, 0.6, 0.35))
	# o clarão do estouro
	if _clarao > 0.0:
		var s2 := 40.0 + 90.0 * (1.0 - _clarao)
		_luz.draw_texture_rect(_brilho, Rect2(_clarao_pos - Vector2(s2, s2) * 0.5, Vector2(s2, s2)), false, Color(1.0, 0.95, 0.8, _clarao))
	# faíscas de vidro: pontinhos que piscam ao girar
	for m in _miudos:
		var k: float = m["t"] / m["vida"]
		var pisca: float = pow(absf(sin(m["t"] * 14.0 + m["fase"])), 3.0)
		var a := (1.0 - k) * (0.35 + 0.65 * pisca)
		var tam := 1.6 if not m["deitado"] else 1.2
		_luz.draw_rect(Rect2(m["pos"] - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), Color(1.0, 0.97, 0.88, a))
		if pisca > 0.85 and not m["deitado"]:
			_luz.draw_texture_rect(_brilho, Rect2(m["pos"] - Vector2(5, 5), Vector2(10, 10)), false, Color(1.0, 0.95, 0.8, a * 0.7))
