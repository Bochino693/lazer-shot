class_name BarTiro
extends Node2D

## Tiro que errou a garrafa no Bar: o que sai do lugar atingido.
##   madeira  (estante/parede) lascas recortadas da própria madeira no ponto
##            do tiro, que pulam para a frente (crescem), giram e caem; pó de
##            madeira e cavaquinhos
##   barril   o mesmo, com a madeira do barril
##   papel    (cartaz JOY-BOY no barril) pedaços do próprio cartaz rasgados
##            que caem planando e virando como papel, fiapos brancos e
##            umas lasquinhas da madeira de baixo
## A marca que fica (furo com profundidade) é desenhada pelo bar.gd com
## sprites/bar_furo_madeira.png ou bar_furo_papel.png.
## Um nó por tiro, desenho em poucas chamadas; some sozinho em ~2 s.

const LODO := preload("res://sprites/mar_lodo.png")

# Contornos em px de back_new.png (fundo do bar).
const CARTAZ := [Vector2(797, 1022), Vector2(992, 1027), Vector2(1002, 1360), Vector2(800, 1335)]
const BARRIL := [Vector2(800, 995), Vector2(1024, 995), Vector2(1024, 1435), Vector2(810, 1425),
	Vector2(785, 1300), Vector2(776, 1160), Vector2(785, 1060)]

# no máximo 5 efeitos ao mesmo tempo (rajada não pesa na TV Box)
const MAX_VIVOS := 5
static var _vivos := 0

var _tex: Texture2D
var _tipo := ""
var _t := 0.0
var _dur := 2.3
var _pecas: Array[Dictionary] = []
var _poeira: Array[Dictionary] = []
var _cavacos: Array[Dictionary] = []


## Transformação px da textura do fundo -> global (o fundo pode estar
## centralizado e escalado para cobrir a tela).
static func _px_para_global(fundo: Sprite2D) -> Transform2D:
	var canto := fundo.offset - (fundo.texture.get_size() * 0.5 if fundo.centered else Vector2.ZERO)
	return fundo.get_global_transform() * Transform2D(0.0, canto)


## Qual material há no ponto (global) do fundo: "papel", "barril" ou "madeira".
static func material_em(fundo: Sprite2D, pos_global: Vector2) -> String:
	if fundo == null or fundo.texture == null:
		return "madeira"
	var p := _px_para_global(fundo).affine_inverse() * pos_global
	if Geometry2D.is_point_in_polygon(p, PackedVector2Array(CARTAZ)):
		return "papel"
	if Geometry2D.is_point_in_polygon(p, PackedVector2Array(BARRIL)):
		return "barril"
	return "madeira"


static func criar(pai: Node, fundo: Sprite2D, pos_global: Vector2, tipo: String) -> void:
	if _vivos >= MAX_VIVOS:
		return
	if pai == null or fundo == null or fundo.texture == null:
		return
	var fx := BarTiro.new()
	fx.top_level = true
	fx.z_index = 4
	_vivos += 1
	pai.add_child(fx)
	fx._montar(fundo, pos_global, tipo)


func _montar(fundo: Sprite2D, pos_global: Vector2, tipo: String) -> void:
	_tipo = tipo
	_tex = fundo.texture
	var folha := _tex.get_size()
	var xf := _px_para_global(fundo)
	var ponto := xf.affine_inverse() * pos_global      # px do fundo
	if tipo == "papel":
		# pedaços do cartaz rasgados em volta do furo
		for i in 7:
			var a := TAU * i / 7.0 + randf_range(-0.3, 0.3)
			var c := ponto + Vector2(cos(a), sin(a)) * randf_range(8.0, 18.0)
			var poly := PackedVector2Array()
			var n := randi_range(5, 7)
			var r := randf_range(10.0, 19.0)
			for k in n:
				var b := TAU * k / n + randf_range(-0.25, 0.25)
				poly.append(Vector2(cos(b), sin(b)) * r * randf_range(0.55, 1.15))
			_nova_peca(poly, c, folha, xf, pos_global, randf_range(120.0, 260.0), randf_range(1.7, 2.2), true)
		for i in 22:
			_cavacos.append({
				"pos": pos_global, "vel": Vector2.RIGHT.rotated(randf_range(-PI, 0.3)) * randf_range(80.0, 260.0),
				"tam": Vector2(randf_range(3.0, 7.0), randf_range(1.5, 3.5)), "giro": randf_range(-12.0, 12.0), "ang": randf() * TAU,
				"t": 0.0, "vida": randf_range(0.9, 1.5), "cor": Color(0.97, 0.93, 0.82), "papel": true,
			})
		for i in 3:
			_nova_lasca(ponto, folha, xf, pos_global, 0.6)
		_novo_po(pos_global, 4, Color(0.90, 0.84, 0.72, 0.6))
	else:
		# lascas da madeira (compridas no sentido do veio, que é em pé)
		for i in 4:
			_nova_lasca(ponto, folha, xf, pos_global, 1.6)
		for i in 6:
			_nova_lasca(ponto, folha, xf, pos_global, 0.8)
		var cru := Color(0.95, 0.70, 0.42) if tipo == "madeira" else Color(0.85, 0.60, 0.34)
		for i in 26:
			_cavacos.append({
				"pos": pos_global, "vel": Vector2.RIGHT.rotated(randf_range(-PI, 0.4)) * randf_range(140.0, 460.0),
				"tam": Vector2(randf_range(4.0, 11.0), randf_range(1.5, 3.2)), "giro": randf_range(-20.0, 20.0), "ang": randf() * TAU,
				"t": 0.0, "vida": randf_range(0.5, 0.9), "cor": cru.lerp(Color(0.45, 0.25, 0.10), randf() * 0.6), "papel": false,
			})
		_novo_po(pos_global, 6, Color(0.80, 0.60, 0.38, 0.65))


func _nova_lasca(ponto: Vector2, folha: Vector2, xf: Transform2D, pos_global: Vector2, tam: float) -> void:
	var comp := randf_range(9.0, 16.0) * tam
	var larg := randf_range(2.5, 4.5) * tam
	var giro := randf_range(-0.35, 0.35)
	var poly := PackedVector2Array()
	for v in [Vector2(-larg * 0.5, -comp), Vector2(larg * 0.6, -comp * 0.4), Vector2(larg * 0.5, comp * 0.7),
			Vector2(0, comp), Vector2(-larg * 0.6, comp * 0.3)]:
		poly.append(v.rotated(giro))
	var c := ponto + Vector2(randf_range(-6, 6), randf_range(-8, 8)) * tam
	_nova_peca(poly, c, folha, xf, pos_global, randf_range(170.0, 380.0), randf_range(0.7, 1.1), false)


func _nova_peca(poly: PackedVector2Array, centro_px: Vector2, folha: Vector2, xf: Transform2D, pos_global: Vector2, vel: float, vida: float, papel: bool) -> void:
	var tri := Geometry2D.triangulate_polygon(poly)
	if tri.is_empty():
		return
	var rel := PackedVector2Array()
	var uvs := PackedVector2Array()
	for v in poly:
		rel.append(xf.basis_xform(v))
		uvs.append((centro_px + v) / folha)
	var pos := xf * centro_px
	var dir := (pos - pos_global).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	dir = (dir + Vector2(0, -0.6)).normalized().rotated(randf_range(-0.4, 0.4))
	_pecas.append({
		"pos": pos, "vel": dir * vel, "ang": 0.0, "giro": randf_range(-9.0, 9.0) if not papel else randf_range(-2.5, 2.5),
		"t": 0.0, "vida": vida, "rel": rel, "uvs": uvs, "tri": tri, "papel": papel,
		"vira": randf_range(4.0, 8.0), "fase": randf() * TAU,
	})


func _novo_po(pos: Vector2, n: int, cor: Color) -> void:
	for i in n:
		_poeira.append({
			"pos": pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)),
			"vel": Vector2.RIGHT.rotated(randf_range(-PI, 0.0)) * randf_range(30.0, 90.0),
			"tam": randf_range(30.0, 56.0), "ang": randf() * TAU, "giro": randf_range(-1.0, 1.0),
			"t": 0.0, "vida": randf_range(0.8, 1.3), "cor": cor,
		})


func _process(delta: float) -> void:
	_t += delta
	if _t >= _dur:
		queue_free()
		return
	for p in _pecas:
		p["t"] += delta
		if p["papel"]:
			# papel: o ar segura, cai devagar balançando de um lado para o outro
			p["vel"] = p["vel"] * pow(0.08, delta) + Vector2(sin(p["t"] * 5.0 + p["fase"]) * 260.0, 260.0) * delta
		else:
			p["vel"] = p["vel"] * pow(0.6, delta) + Vector2(0, 1500.0) * delta
		p["pos"] += p["vel"] * delta
		p["ang"] += p["giro"] * delta
	for c in _cavacos:
		c["t"] += delta
		if c["papel"]:
			c["vel"] = c["vel"] * pow(0.05, delta) + Vector2(sin(c["t"] * 7.0 + c["ang"]) * 120.0, 160.0) * delta
		else:
			c["vel"] = c["vel"] * pow(0.5, delta) + Vector2(0, 1400.0) * delta
		c["pos"] += c["vel"] * delta
		c["ang"] += c["giro"] * delta
	for p in _poeira:
		p["t"] += delta
		p["vel"] = p["vel"] * pow(0.15, delta) + Vector2(0, 10.0) * delta
		p["pos"] += p["vel"] * delta
		p["ang"] += p["giro"] * delta
	queue_redraw()


func _draw() -> void:
	for p in _poeira:
		var k: float = p["t"] / p["vida"]
		if k >= 1.0:
			continue
		var s: float = p["tam"] * (0.5 + 1.1 * k)
		draw_set_transform(p["pos"], p["ang"])
		draw_texture_rect(LODO, Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), false,
			Color(p["cor"], p["cor"].a * (1.0 - k) * minf(1.0, k * 8.0)))
	draw_set_transform(Vector2.ZERO)

	# pedaços recortados do fundo (um desenho só); saem para a frente
	var pontos := PackedVector2Array()
	var cores := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for p in _pecas:
		var resta: float = p["vida"] - p["t"]
		if resta <= 0.0:
			continue
		var k: float = p["t"] / p["vida"]
		var frente: float = 1.0 + (0.35 if not p["papel"] else 0.15) * minf(1.0, k * 3.0)
		var vira: float = cos(p["t"] * p["vira"]) if p["papel"] else 1.0
		var luz: float = 0.75 + 0.25 * absf(vira) if p["papel"] else 1.45
		var cor := Color(luz, luz, luz, clampf(resta / 0.35, 0.0, 1.0))
		var ini := pontos.size()
		var rel: PackedVector2Array = p["rel"]
		var uv: PackedVector2Array = p["uvs"]
		for i in rel.size():
			var v: Vector2 = rel[i] * frente
			v.x *= vira
			pontos.append(p["pos"] + v.rotated(p["ang"]))
			cores.append(cor)
			uvs.append(uv[i])
		for i in p["tri"]:
			indices.append(ini + i)
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, pontos, cores, uvs,
			PackedInt32Array(), PackedFloat32Array(), _tex.get_rid())

	for c in _cavacos:
		var k: float = c["t"] / c["vida"]
		if k >= 1.0:
			continue
		var tam: Vector2 = c["tam"]
		draw_set_transform(c["pos"], c["ang"])
		draw_rect(Rect2(-tam * 0.5, tam), Color(c["cor"], 1.0 - k * k))
	draw_set_transform(Vector2.ZERO)


func _exit_tree() -> void:
	_vivos -= 1
