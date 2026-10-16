class_name MarExplosao
extends Node2D

## Explosão de bomba debaixo d'água (Mar), do tiro ou da bomba que bateu no
## chão. Camadas, na ordem em que acontecem:
##   clarão e bola de fogo  luz forte que some rápido
##   anéis de choque        a água empurrada em volta (fx_onda.png)
##   bolha de gás           a bolha da explosão incha, encolhe e incha de novo
##                          (como uma explosão de verdade debaixo d'água) e se
##                          desfaz em bolhas
##   água espalhando        jatos riscando para fora e bolhas jogadas longe que
##                          freiam e sobem
##   fumaça                 nuvens escuras que se espalham devagar e sobem
##   estilhaços             pedaços escuros da bomba girando e afundando
##   areia (no chão)        coluna de areia que sobe, abre e assenta
## `k` é a escala pela distância (1 = plano dos alvos; menor = mais longe).
## Um nó por explosão, no máximo 3 ao mesmo tempo; some sozinho.

const Pincel := preload("res://scripts/pincel.gd")
const MAX_VIVAS := 3
const GRUPO := "fx_mar_explosao"
const DURACAO := 3.2

var _fumaca: Texture2D
var _onda: Texture2D
var _brilho: Texture2D
var _bolha: Texture2D

var _pos := Vector2.ZERO
var _k := 1.0
var _chao := false
var _t := 0.0
var _luz: Node2D

var _fogo: Array[Dictionary] = []
var _brasas: Array[Dictionary] = []
var _fumacas: Array[Dictionary] = []
var _bolhas: Array[Dictionary] = []
var _jatos: Array[Dictionary] = []
var _estilhacos: Array[Dictionary] = []
var _areia: Array[Dictionary] = []
var _graos: Array[Dictionary] = []


## `tex`: {"fumaca", "onda", "brilho", "bolha"} (texturas carregadas pela fase).
static func criar(pai: Node, pos: Vector2, k: float, no_chao: bool, tex: Dictionary, z_desenho: int = 166) -> void:
	if pai == null or not pai.is_inside_tree():
		return
	if pai.get_tree().get_node_count_in_group(GRUPO) >= MAX_VIVAS:
		return
	var fx := MarExplosao.new()
	fx._fumaca = tex.get("fumaca")
	fx._onda = tex.get("onda")
	fx._brilho = tex.get("brilho")
	fx._bolha = tex.get("bolha")
	if fx._fumaca == null or fx._onda == null or fx._brilho == null or fx._bolha == null:
		fx.free()
		return
	fx.add_to_group(GRUPO)
	fx.top_level = true
	fx.z_as_relative = false
	fx.z_index = z_desenho
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # pincel
	pai.add_child(fx)
	fx._montar(pos, clampf(k, 0.25, 1.3), no_chao)


func _montar(pos: Vector2, k: float, no_chao: bool) -> void:
	_pos = pos
	_k = k
	_chao = no_chao
	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_luz = Node2D.new()
	_luz.material = soma
	_luz.draw.connect(_desenhar_luz)
	add_child(_luz)

	var cima := Vector2(0, -1)
	for i in 6:
		_fogo.append({"pos": pos + Vector2(randf_range(-18, 18), randf_range(-18, 18)) * k,
			"tam": randf_range(70.0, 110.0) * k, "cresce": randf_range(1.6, 2.4), "ang": randf() * TAU,
			"vida": randf_range(0.32, 0.48), "cor": Color(1.0, randf_range(0.45, 0.75), randf_range(0.1, 0.3))})
	for i in 26:
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		_brasas.append({"pos": pos, "vel": dir * randf_range(260.0, 620.0) * k, "t": 0.0,
			"vida": randf_range(0.45, 0.9), "tam": randf_range(10.0, 20.0) * k,
			"cor": Color(1.0, randf_range(0.5, 0.85), 0.25)})
	for i in 15:
		var dir2 := Vector2.RIGHT.rotated(randf() * TAU)
		if no_chao:
			dir2 = (dir2 + cima * 0.8).normalized()
		_fumacas.append({"pos": pos + dir2 * randf_range(5.0, 34.0) * k, "vel": dir2 * randf_range(80.0, 260.0) * k,
			"t": -randf_range(0.0, 0.2), "vida": randf_range(2.3, 3.0), "tam": randf_range(95.0, 150.0) * k,
			"cresce": randf_range(2.2, 3.0), "ang": randf() * TAU, "giro": randf_range(-0.6, 0.6),
			"cor": Color(0.09, 0.10, 0.12).lerp(Color(0.24, 0.23, 0.22), randf())})
	for i in 24:
		var dir3 := Vector2.RIGHT.rotated(randf() * TAU)
		_bolhas.append({"pos": pos + dir3 * 10.0 * k, "vel": dir3 * randf_range(280.0, 720.0) * k, "t": 0.0,
			"vida": randf_range(1.2, 2.3), "tam": randf_range(7.0, 22.0) * k, "fase": randf() * TAU})
	for i in 16:
		var ang := TAU * i / 16.0 + randf_range(-0.12, 0.12)
		_jatos.append({"ang": ang, "comp": randf_range(140.0, 260.0) * k, "larg": randf_range(3.0, 6.0) * k})
	for i in 12:
		var dir4 := Vector2.RIGHT.rotated(randf() * TAU)
		if no_chao:
			dir4 = (dir4 + cima).normalized()
		var poli := PackedVector2Array()
		var n := randi_range(4, 5)
		var r := randf_range(6.0, 13.0) * k
		for j in n:
			poli.append(Vector2.RIGHT.rotated(TAU * j / n + randf_range(-0.3, 0.3)) * r * randf_range(0.5, 1.1))
		_estilhacos.append({"pos": pos, "vel": dir4 * randf_range(260.0, 540.0) * k, "t": 0.0,
			"vida": randf_range(1.2, 1.7), "ang": randf() * TAU, "giro": randf_range(-12.0, 12.0), "poli": poli})
	if no_chao:
		for i in 10:
			var x := randf_range(-1.0, 1.0)
			_areia.append({"pos": pos + Vector2(x * 50.0, 0) * k, "vel": Vector2(x * 140.0, -randf_range(150.0, 360.0)) * k,
				"t": 0.0, "vida": randf_range(2.0, 2.6), "tam": randf_range(70.0, 120.0) * k, "cresce": randf_range(2.0, 2.8),
				"ang": randf() * TAU, "giro": randf_range(-0.5, 0.5)})
		for i in 30:
			_graos.append({"pos": pos + Vector2(randf_range(-30, 30), 0) * k,
				"vel": Vector2(randf_range(-200.0, 200.0), -randf_range(200.0, 520.0)) * k, "t": 0.0,
				"vida": randf_range(0.9, 1.5), "tam": randf_range(2.5, 5.0) * k, "chao": pos.y + randf_range(-4.0, 10.0) * k})


# ───────────────────────────────────────────── quadro a quadro
func _process(delta: float) -> void:
	_t += delta
	if _t >= DURACAO:
		queue_free()
		return
	var k := _k
	# o que já acabou sai da lista (menos conta por quadro na TV Box)
	for lista: Array[Dictionary] in [_brasas, _bolhas, _estilhacos, _areia, _graos]:
		if not lista.is_empty() and float(lista[0]["t"]) > 0.0:
			for i in range(lista.size() - 1, -1, -1):
				if float(lista[i]["t"]) >= float(lista[i]["vida"]):
					lista.remove_at(i)
	var freio_b := pow(0.04, delta)
	for b in _brasas:
		b["t"] += delta
		b["vel"] = b["vel"] * freio_b
		b["pos"] += b["vel"] * delta
	var freio_f := pow(0.18, delta)
	var sobe_f := Vector2(0, -26.0 * k) * delta
	for f in _fumacas:
		f["t"] += delta
		if f["t"] > 0.0:
			f["vel"] = f["vel"] * freio_f + sobe_f
			f["pos"] += f["vel"] * delta
			f["ang"] += f["giro"] * delta
	var freio_b2 := pow(0.02, delta)
	for b2 in _bolhas:
		b2["t"] += delta
		b2["vel"] = b2["vel"] * freio_b2 + Vector2(sin(b2["t"] * 6.0 + b2["fase"]) * 50.0 * k, -150.0 * k) * delta
		b2["pos"] += b2["vel"] * delta
	var freio_e := pow(0.12, delta)
	var cai_e := Vector2(0, 260.0 * k) * delta
	for e in _estilhacos:
		e["t"] += delta
		e["vel"] = e["vel"] * freio_e + cai_e
		e["pos"] += e["vel"] * delta
		e["ang"] += e["giro"] * delta
	var freio_a := pow(0.25, delta)
	var cai_a := Vector2(0, 70.0 * k) * delta
	for a in _areia:
		a["t"] += delta
		a["vel"] = a["vel"] * freio_a + cai_a
		a["pos"] += a["vel"] * delta
		a["ang"] += a["giro"] * delta
	var freio_g := pow(0.5, delta)
	var cai_g := Vector2(0, 900.0 * k) * delta
	for g in _graos:
		g["t"] += delta
		if g["pos"].y < g["chao"] or g["vel"].y < 0.0:
			g["vel"] = g["vel"] * freio_g + cai_g
			g["pos"] += g["vel"] * delta
		else:
			g["pos"].y = g["chao"]
	queue_redraw()
	_luz.queue_redraw()


## Raio da bolha de gás: incha, encolhe (colapso), incha menos e estoura.
func _raio_bolha() -> float:
	var t := _t
	if t < 0.18:
		return lerpf(10.0, 120.0, sin(t / 0.18 * PI * 0.5)) * _k
	if t < 0.42:
		return lerpf(120.0, 42.0, smoothstep(0.18, 0.42, t)) * _k
	if t < 0.62:
		return lerpf(42.0, 75.0, sin((t - 0.42) / 0.2 * PI * 0.5)) * _k
	return 0.0


func _draw() -> void:
	# areia (no chão) e fumaça: o que tapa
	for a in _areia:
		var ka: float = a["t"] / a["vida"]
		if ka >= 1.0:
			continue
		var s: float = a["tam"] * (1.0 + a["cresce"] * ka)
		draw_set_transform(a["pos"], a["ang"])
		draw_texture_rect(_fumaca, Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), false,
			Color(0.70, 0.74, 0.72, 0.85 * minf(1.0, ka * 8.0) * (1.0 - ka) * (1.0 - ka * 0.3)))
	for f in _fumacas:
		var t: float = f["t"]
		if t < 0.0 or t >= f["vida"]:
			continue
		var kf: float = t / f["vida"]
		var s2: float = f["tam"] * (0.6 + f["cresce"] * (1.0 - (1.0 - kf) * (1.0 - kf)))
		var cor: Color = f["cor"]
		draw_set_transform(f["pos"], f["ang"])
		draw_texture_rect(_fumaca, Rect2(Vector2(-s2, -s2) * 0.5, Vector2(s2, s2)), false,
			Color(cor, 0.95 * minf(1.0, kf * 7.0) * (1.0 - kf * kf)))
	draw_set_transform(Vector2.ZERO)

	# bolha de gás (translúcida, com a borda clara e um reflexo), pelo pincel:
	# círculos e arcos de verdade eram 7 desenhos novos na placa a cada quadro
	var r := _raio_bolha()
	if r > 1.0:
		Pincel.circulo(self, _pos, r, Color(0.70, 0.88, 1.0, 0.16))
		Pincel.anel(self, _pos, r, maxf(1.5, 3.5 * _k), Color(0.92, 0.98, 1.0, 0.55))
		Pincel.arco(self, _pos, r * 0.72, deg_to_rad(200), deg_to_rad(250), Color(1, 1, 1, 0.6), maxf(1.0, 3.0 * _k))

	# água espalhando: bolhas jogadas para fora
	for b in _bolhas:
		var kb: float = b["t"] / b["vida"]
		if kb >= 1.0:
			continue
		var sb: float = b["tam"] * (0.8 + 0.5 * kb)
		draw_texture_rect(_bolha, Rect2(b["pos"] - Vector2(sb, sb) * 0.5, Vector2(sb, sb)), false,
			Color(0.88, 0.96, 1.0, 0.9 * (1.0 - kb * kb)))

	# estilhaços da bomba e grãos de areia: sem textura, num desenho só
	var tri := Triangulos.new()
	for e in _estilhacos:
		var ke: float = e["t"] / e["vida"]
		if ke >= 1.0:
			continue
		var poli: PackedVector2Array = e["poli"]
		var pts := PackedVector2Array()
		for v in poli:
			pts.append(e["pos"] + v.rotated(e["ang"]))
		tri.poligono(pts, Color(0.07, 0.07, 0.08, 1.0 - ke * ke))
	for g in _graos:
		var kg: float = g["t"] / g["vida"]
		if kg < 1.0:
			var sg: float = g["tam"]
			tri.retangulo(Rect2(g["pos"] - Vector2(sg, sg) * 0.5, Vector2(sg, sg)), Color(0.80, 0.80, 0.74, 1.0 - kg))
	tri.desenhar(self)


func _desenhar_luz() -> void:
	var t := _t
	# clarão
	if t < 0.24:
		var kc := t / 0.24
		var s := (380.0 + 260.0 * kc) * _k
		_luz.draw_texture_rect(_brilho, Rect2(_pos - Vector2(s, s) * 0.5, Vector2(s, s)), false,
			Color(1.0, 0.85, 0.6, 1.0 - kc))
	# bola de fogo
	for f in _fogo:
		if t >= f["vida"]:
			continue
		var kf: float = t / f["vida"]
		var s2: float = f["tam"] * (1.0 + f["cresce"] * kf)
		_luz.draw_set_transform(f["pos"], f["ang"])
		_luz.draw_texture_rect(_fumaca, Rect2(Vector2(-s2, -s2) * 0.5, Vector2(s2, s2)), false,
			Color(f["cor"], 0.95 * (1.0 - kf)))
	_luz.draw_set_transform(Vector2.ZERO)
	# anéis de choque (a água empurrada)
	for i in 2:
		var ta := t - 0.08 * i
		if ta < 0.0 or ta > 0.55:
			continue
		var kr := ta / 0.55
		var d := (70.0 + (620.0 - 160.0 * i) * (1.0 - (1.0 - kr) * (1.0 - kr))) * _k
		_luz.draw_texture_rect(_onda, Rect2(_pos - Vector2(d, d) * 0.5, Vector2(d, d)), false,
			Color(0.75, 0.92, 1.0, (0.85 - 0.3 * i) * (1.0 - kr)))
	# jatos de água riscando para fora (riscos com a textura do brilho: saem
	# no mesmo lote das brasas)
	if t < 0.3:
		var kj := t / 0.3
		for j in _jatos:
			var comp: float = j["comp"] * kj * 0.5
			var larg: float = j["larg"] * 2.2
			_luz.draw_set_transform(_pos + Vector2.RIGHT.rotated(j["ang"]) * (30.0 * _k + j["comp"] * kj * 0.5), j["ang"])
			_luz.draw_texture_rect(_brilho, Rect2(Vector2(0.0, -larg * 0.5), Vector2(comp, larg)), false,
				Color(0.85, 0.95, 1.0, 0.7 * (1.0 - kj)))
		_luz.draw_set_transform(Vector2.ZERO)
	# brasas
	for b in _brasas:
		var kb: float = b["t"] / b["vida"]
		if kb >= 1.0:
			continue
		var sb: float = b["tam"] * (1.0 - 0.5 * kb)
		_luz.draw_texture_rect(_brilho, Rect2(b["pos"] - Vector2(sb, sb) * 0.5, Vector2(sb, sb)), false,
			Color(b["cor"], 1.0 - kb))
