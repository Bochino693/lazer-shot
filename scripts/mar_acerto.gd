class_name MarAcerto
extends Node2D

## Efeito extra quando um alvo do Mar é atingido, por cima da animação de
## acerto que o alvo já tem:
##   água-viva  o sino se desfaz em pedaços de geleia (da própria imagem) que
##              flutuam e somem, brilhos bioluminescentes piscando, dois anéis
##              na água, tentáculos soltos afundando e bolhas
##   vaso       cacos de cerâmica (da própria imagem) voando e afundando, pó
##              de barro, grãos caindo, brilhos verdes do cristal e bolhas
##   baú        tábuas do baú voando e afundando, estrelas de ouro, anel
##              dourado, pó de madeira e bolhas
## Os pedaços nascem da rachadura no ponto do tiro (pequenos perto dele).
## Um nó só por acerto: os pedaços saem num desenho (triângulos com a folha
## do alvo), o resto em poucas chamadas; some sozinho em ~2 s.

const BOLHA := preload("res://sprites/mar_bolha.png")
const LODO := preload("res://sprites/mar_lodo.png")

# Onde está o corpo do alvo no quadro (fração do quadro): elipse ou caixa.
const FORMAS := {
	"aguaviva": {"centro": Vector2(0.5, 0.36), "raio": Vector2(0.36, 0.27), "caixa": false, "setores": 9, "anel": 0.5},
	"vaso": {"centro": Vector2(0.5, 0.5), "raio": Vector2(0.32, 0.36), "caixa": false, "setores": 7, "anel": 0.45},
	"bau": {"centro": Vector2(0.5, 0.52), "raio": Vector2(0.42, 0.32), "caixa": true, "setores": 6, "anel": 0.5},
}

static var _brilho: Texture2D = null

var _tipo := ""
# no máximo 4 efeitos ao mesmo tempo (rajada não pesa na TV Box)
const MAX_VIVOS := 4
static var _vivos := 0

var _tex: Texture2D
var _t := 0.0
var _dur := 2.2
var _k := 1.0
var _luz: Node2D

var _cacos: Array[Dictionary] = []
var _bolhas: Array[Dictionary] = []
var _faiscas: Array[Dictionary] = []
var _poeira: Array[Dictionary] = []
var _graos: Array[Dictionary] = []
var _aneis: Array[Dictionary] = []
var _clarao := {}
var _fios: Array[Dictionary] = []

# física dos pedaços (debaixo d'água: a água freia e eles afundam ou sobem)
var _freio := 0.1
var _grav := 0.0


## Cria o efeito para `alvo` (Area2D com AnimatedSprite2D) atingido em
## `impacto` (coordenadas globais). Chamar antes de trocar a animação.
static func criar(pai: Node, alvo: Node2D, impacto: Vector2, tipo: String) -> void:
	if _vivos >= MAX_VIVOS:
		return
	if not FORMAS.has(tipo) or pai == null or alvo == null:
		return
	var anim := alvo.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim == null or anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim.animation):
		return
	var quadro := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	if quadro == null:
		return
	if _brilho == null:
		_brilho = FundoVivo.brilho_redondo()
	var fx := MarAcerto.new()
	fx.top_level = true
	fx.z_index = 5
	_vivos += 1
	pai.add_child(fx)
	fx._montar(anim, quadro, impacto, tipo)


func _montar(anim: AnimatedSprite2D, quadro: Texture2D, impacto: Vector2, tipo: String) -> void:
	_tipo = tipo
	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_luz = Node2D.new()
	_luz.material = soma
	_luz.draw.connect(_desenhar_luz)
	add_child(_luz)

	var atlas: Texture2D = quadro
	var regiao := Rect2(Vector2.ZERO, quadro.get_size())
	if quadro is AtlasTexture and (quadro as AtlasTexture).atlas != null:
		atlas = (quadro as AtlasTexture).atlas
		regiao = (quadro as AtlasTexture).region
	_tex = atlas
	var folha := atlas.get_size()
	var xf := anim.get_global_transform()
	var canto := anim.offset - (regiao.size * 0.5 if anim.centered else Vector2.ZERO)
	_k = clampf(regiao.size.x * absf(xf.get_scale().x) / 180.0, 0.6, 1.8)

	var f: Dictionary = FORMAS[tipo]
	var c: Vector2 = f["centro"] * regiao.size
	var r: Vector2 = f["raio"] * regiao.size
	var corpo := PackedVector2Array()
	if f["caixa"]:
		corpo = PackedVector2Array([c - r, Vector2(c.x + r.x, c.y - r.y), c + r, Vector2(c.x - r.x, c.y + r.y)])
	else:
		for i in 28:
			var a := TAU * i / 28.0
			corpo.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	var tiro := xf.affine_inverse() * impacto - canto
	tiro = tiro.clamp(c - r * 0.75, c + r * 0.75)

	# rachadura: setores a partir do tiro, cortados em anel (perto = pequenos)
	var n: int = f["setores"]
	var cortes := PackedFloat32Array()
	var a0 := randf() * TAU
	for i in n + 1:
		cortes.append(a0 + TAU * (i + (randf_range(-0.3, 0.3) if i > 0 and i < n else 0.0)) / n)
	var longe := r.length() * 2.5
	var raios := [0.0, longe] if f["anel"] <= 0.0 else [0.0, maxf(r.x, r.y) * f["anel"] * randf_range(0.8, 1.2), longe]
	for i in n:
		for j in raios.size() - 1:
			var setor := PackedVector2Array()
			var ri: float = raios[j]
			var ro: float = raios[j + 1]
			for s in 6:
				var a := lerpf(cortes[i], cortes[i + 1], s / 5.0)
				setor.append(tiro + Vector2(cos(a), sin(a)) * ro)
			if ri <= 0.0:
				setor.append(tiro)
			else:
				for s in 6:
					var a := lerpf(cortes[i + 1], cortes[i], s / 5.0)
					setor.append(tiro + Vector2(cos(a), sin(a)) * ri)
			for peca in Geometry2D.intersect_polygons(setor, corpo):
				_novo_caco(peca, regiao, folha, xf, canto, tiro)

	# clarão no ponto do tiro
	var cor_clarao := {"aguaviva": Color(1.0, 0.75, 1.0), "vaso": Color(0.85, 1.0, 0.92), "bau": Color(1.0, 0.9, 0.55)}
	_clarao = {"pos": impacto, "tam": 190.0 * _k, "cor": cor_clarao[tipo]}

	match tipo:
		"aguaviva":
			_montar_aguaviva(anim, xf, canto, c, r, impacto)
		"vaso":
			_montar_vaso(impacto)
		"bau":
			_montar_bau(impacto)


func _novo_caco(peca: PackedVector2Array, regiao: Rect2, folha: Vector2, xf: Transform2D, canto: Vector2, tiro: Vector2) -> void:
	if peca.size() < 3:
		return
	var centro := Vector2.ZERO
	for p in peca:
		centro += p
	centro /= peca.size()
	var tri := Geometry2D.triangulate_polygon(peca)
	if tri.is_empty():
		return
	var rel := PackedVector2Array()
	var uvs := PackedVector2Array()
	for p in peca:
		rel.append(xf.basis_xform(p - centro))
		uvs.append((regiao.position + p) / folha)
	var dir := xf.basis_xform(centro - tiro).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP.rotated(randf_range(-1.0, 1.0))
	var veloc := 0.0
	var vida := 1.3
	var giro := 0.0
	match _tipo:
		"aguaviva":
			veloc = randf_range(80.0, 170.0)
			vida = randf_range(0.7, 1.1)
			giro = randf_range(-3.0, 3.0)
		"vaso":
			veloc = randf_range(150.0, 360.0)
			vida = randf_range(1.0, 1.5)
			giro = randf_range(-7.0, 7.0)
		_:
			veloc = randf_range(170.0, 380.0)
			vida = randf_range(1.0, 1.5)
			giro = randf_range(-8.0, 8.0)
	_cacos.append({
		"pos": xf * (canto + centro),
		"vel": (dir.rotated(randf_range(-0.35, 0.35)) * veloc + Vector2(0, -40.0)) * _k,
		"ang": 0.0, "giro": giro, "t": 0.0, "vida": vida,
		"rel": rel, "uvs": uvs, "tri": tri,
	})


func _montar_aguaviva(anim: AnimatedSprite2D, xf: Transform2D, canto: Vector2, c: Vector2, r: Vector2, impacto: Vector2) -> void:
	_freio = 0.35
	_grav = -18.0
	var vermelha := String(anim.animation).ends_with("_a")
	var cor := Color(1.0, 0.42, 0.55) if vermelha else Color(0.80, 0.45, 1.0)
	for i in 34:
		_nova_faisca(impacto, randf_range(80.0, 320.0), randf_range(10.0, 24.0), randf_range(0.8, 1.5),
			cor.lerp(Color(1, 1, 1), randf_range(0.25, 0.7)), -40.0)
	_novo_anel(impacto, 150.0, 0.55, 0.0, Color(cor, 0.55), 7.0)
	_novo_anel(impacto, 110.0, 0.5, 0.12, Color(0.85, 0.95, 1.0, 0.4), 4.0)
	for i in 6:
		var base := c + Vector2(randf_range(-0.7, 0.7) * r.x, r.y * 0.85)
		_fios.append({
			"pos": xf * (canto + base),
			"vel": Vector2(randf_range(-15.0, 15.0), randf_range(25.0, 45.0)) * _k,
			"comp": randf_range(45.0, 80.0) * _k, "fase": randf() * TAU,
			"t": 0.0, "vida": randf_range(1.6, 2.0), "cor": Color(cor.darkened(0.15), 0.75),
		})
	_novas_bolhas(impacto, 12)


func _montar_vaso(impacto: Vector2) -> void:
	_freio = 0.10
	_grav = 320.0
	for i in 8:
		_poeira.append({
			"pos": impacto + Vector2(randf_range(-20, 20), randf_range(-20, 20)) * _k,
			"vel": Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 140.0) * _k,
			"tam": randf_range(50.0, 90.0) * _k, "ang": randf() * TAU, "giro": randf_range(-1.0, 1.0),
			"t": 0.0, "vida": randf_range(1.3, 1.8), "cor": Color(0.86, 0.82, 0.72, 0.6),
		})
	for i in 22:
		_graos.append({
			"pos": impacto, "vel": Vector2.RIGHT.rotated(randf_range(-PI, 0.2)) * randf_range(120.0, 320.0) * _k,
			"tam": randf_range(2.0, 5.0) * _k, "t": 0.0, "vida": randf_range(0.8, 1.2),
			"cor": Color(0.78, 0.73, 0.62).lerp(Color(0.45, 0.42, 0.38), randf()),
		})
	for i in 16:
		_nova_faisca(impacto, randf_range(60.0, 200.0), randf_range(6.0, 14.0), randf_range(0.6, 1.1),
			Color(0.5, 1.0, 0.85), -30.0)
	_novo_anel(impacto, 120.0, 0.45, 0.0, Color(0.95, 0.92, 0.80, 0.45), 6.0)
	_novas_bolhas(impacto, 8)


func _montar_bau(impacto: Vector2) -> void:
	_freio = 0.12
	_grav = 360.0
	for i in 30:
		var f := _nova_faisca(impacto, randf_range(100.0, 320.0), randf_range(8.0, 18.0), randf_range(0.8, 1.5),
			Color(1.0, 0.85, 0.35).lerp(Color(1, 1, 0.9), randf_range(0.0, 0.4)), 120.0)
		f["estrela"] = true
	_novo_anel(impacto, 140.0, 0.5, 0.0, Color(1.0, 0.82, 0.35, 0.6), 7.0)
	for i in 4:
		_poeira.append({
			"pos": impacto + Vector2(randf_range(-14, 14), randf_range(-14, 14)) * _k,
			"vel": Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, 100.0) * _k,
			"tam": randf_range(40.0, 70.0) * _k, "ang": randf() * TAU, "giro": randf_range(-1.0, 1.0),
			"t": 0.0, "vida": randf_range(1.0, 1.4), "cor": Color(0.62, 0.52, 0.40, 0.5),
		})
	_novas_bolhas(impacto, 8)


func _nova_faisca(pos: Vector2, vel: float, tam: float, vida: float, cor: Color, grav: float) -> Dictionary:
	var f := {
		"pos": pos, "vel": Vector2.RIGHT.rotated(randf() * TAU) * vel * _k, "tam": tam * _k,
		"t": 0.0, "vida": vida, "cor": cor, "fase": randf() * TAU, "grav": grav * _k, "estrela": false,
	}
	_faiscas.append(f)
	return f


func _novo_anel(pos: Vector2, raio: float, vida: float, atraso: float, cor: Color, larg: float) -> void:
	_aneis.append({"pos": pos, "raio": raio * _k, "t": -atraso, "vida": vida, "cor": cor, "larg": larg * _k})


func _novas_bolhas(pos: Vector2, n: int) -> void:
	for i in n:
		_bolhas.append({
			"pos": pos + Vector2(randf_range(-22, 22), randf_range(-18, 18)) * _k,
			"vel": Vector2(randf_range(-30.0, 30.0), -randf_range(60.0, 130.0)) * _k,
			"tam": randf_range(8.0, 22.0) * _k, "t": 0.0, "vida": randf_range(1.2, 2.0), "fase": randf() * TAU,
		})


# ───────────────────────────────────────────── quadro a quadro
func _process(delta: float) -> void:
	_t += delta
	if _t >= _dur:
		queue_free()
		return
	var freio := pow(_freio, delta)
	for c in _cacos:
		c["t"] += delta
		c["vel"] = c["vel"] * freio + Vector2(0, _grav * _k) * delta
		c["pos"] += c["vel"] * delta
		c["ang"] += c["giro"] * delta
	for f in _faiscas:
		f["t"] += delta
		f["vel"] = f["vel"] * pow(0.08, delta) + Vector2(0, f["grav"]) * delta
		f["pos"] += f["vel"] * delta
	for p in _poeira:
		p["t"] += delta
		p["vel"] = p["vel"] * pow(0.2, delta)
		p["pos"] += p["vel"] * delta
		p["ang"] += p["giro"] * delta
	for g in _graos:
		g["t"] += delta
		g["vel"] = g["vel"] * pow(0.4, delta) + Vector2(0, 500.0 * _k) * delta
		g["pos"] += g["vel"] * delta
	for b in _bolhas:
		b["t"] += delta
		b["vel"] = b["vel"] * pow(0.6, delta) + Vector2(sin(b["t"] * 6.0 + b["fase"]) * 40.0 * _k, -90.0 * _k) * delta
		b["pos"] += b["vel"] * delta
	for fio in _fios:
		fio["t"] += delta
		fio["pos"] += fio["vel"] * delta
	for a in _aneis:
		a["t"] += delta
	queue_redraw()
	_luz.queue_redraw()


func _draw() -> void:
	# pedaços do próprio alvo (um desenho só)
	var pontos := PackedVector2Array()
	var cores := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var alfa_base := 0.75 if _tipo == "aguaviva" else 1.0
	for c in _cacos:
		var resta: float = c["vida"] - c["t"]
		if resta <= 0.0:
			continue
		var cresce: float = 1.0 + (0.3 * c["t"] / c["vida"] if _tipo == "aguaviva" else 0.0)
		var cor := Color(1, 1, 1, alfa_base * clampf(resta / 0.4, 0.0, 1.0))
		var ini := pontos.size()
		var rel: PackedVector2Array = c["rel"]
		var uv: PackedVector2Array = c["uvs"]
		for i in rel.size():
			pontos.append(c["pos"] + rel[i].rotated(c["ang"]) * cresce)
			cores.append(cor)
			uvs.append(uv[i])
		for i in c["tri"]:
			indices.append(ini + i)
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, pontos, cores, uvs,
			PackedInt32Array(), PackedFloat32Array(), _tex.get_rid())

	for p in _poeira:
		var k: float = p["t"] / p["vida"]
		if k >= 1.0:
			continue
		var s: float = p["tam"] * (0.6 + 1.2 * k)
		draw_set_transform(p["pos"], p["ang"])
		draw_texture_rect(LODO, Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), false, Color(p["cor"], p["cor"].a * (1.0 - k) * minf(1.0, k * 6.0)))
	draw_set_transform(Vector2.ZERO)
	for g in _graos:
		var k: float = g["t"] / g["vida"]
		if k < 1.0:
			var s: float = g["tam"]
			draw_rect(Rect2(g["pos"] - Vector2(s, s) * 0.5, Vector2(s, s)), Color(g["cor"], 1.0 - k))
	for fio in _fios:
		var k: float = fio["t"] / fio["vida"]
		if k >= 1.0:
			continue
		var linha := PackedVector2Array()
		var comp: float = fio["comp"]
		for i in 8:
			var u := i / 7.0
			linha.append(fio["pos"] + Vector2(sin(fio["fase"] + _t * 4.0 + u * 5.0) * 6.0 * _k * u, comp * u))
		draw_polyline(linha, Color(fio["cor"], fio["cor"].a * (1.0 - k)), 4.0 * _k * (1.0 - 0.5 * k), true)
	for b in _bolhas:
		var k: float = b["t"] / b["vida"]
		if k < 1.0:
			var s: float = b["tam"] * (0.8 + 0.4 * k)
			draw_texture_rect(BOLHA, Rect2(b["pos"] - Vector2(s, s) * 0.5, Vector2(s, s)), false,
				Color(0.88, 0.96, 1.0, 0.9 * (1.0 - k * k)))


func _desenhar_luz() -> void:
	if not _clarao.is_empty() and _t < 0.28:
		var k := _t / 0.28
		var s: float = _clarao["tam"] * (0.6 + 0.6 * k)
		_luz.draw_texture_rect(_brilho, Rect2(_clarao["pos"] - Vector2(s, s) * 0.5, Vector2(s, s)), false,
			Color(_clarao["cor"], 0.9 * (1.0 - k) * (1.0 - k)))
	for a in _aneis:
		var t: float = a["t"]
		if t < 0.0 or t >= a["vida"]:
			continue
		var k: float = t / a["vida"]
		var ease := 1.0 - (1.0 - k) * (1.0 - k)
		var cor: Color = a["cor"]
		_luz.draw_arc(a["pos"], 12.0 * _k + a["raio"] * ease, 0.0, TAU, 48, Color(cor, cor.a * (1.0 - k)),
			maxf(1.0, a["larg"] * (1.0 - k)), true)
	for f in _faiscas:
		var k: float = f["t"] / f["vida"]
		if k >= 1.0:
			continue
		var pisca := 0.6 + 0.4 * sin(f["t"] * 22.0 + f["fase"])
		var cor: Color = f["cor"]
		cor.a = (1.0 - k) * pisca
		var s: float = f["tam"] * (1.0 - 0.4 * k)
		_luz.draw_texture_rect(_brilho, Rect2(f["pos"] - Vector2(s, s) * 0.5, Vector2(s, s)), false, cor)
		if f["estrela"]:
			var b := s * 1.3
			_luz.draw_line(f["pos"] - Vector2(b, 0), f["pos"] + Vector2(b, 0), cor, 1.5 * _k, true)
			_luz.draw_line(f["pos"] - Vector2(0, b), f["pos"] + Vector2(0, b), cor, 1.5 * _k, true)


func _exit_tree() -> void:
	_vivos -= 1
