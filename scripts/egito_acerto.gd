class_name EgitoAcerto
extends Node2D

## Efeito quando um artefato (sol ou lua) do Egito é atingido, junto com a
## animação de acerto dele:
##   sol   clarão quente, leque de raios de luz abrindo, dois anéis dourados,
##         estilhaços do próprio medalhão voando e caindo, brasas douradas
##   lua   clarão frio, anéis prateados, arcos de luar girando para fora,
##         estilhaços prateados e pó de estrelas piscando que sobe devagar
## Acertar o artefato errado (fora da vez) deixa o anel vermelho.
## Um nó só por acerto, desenho em poucas chamadas; some sozinho.

const Pincel := preload("res://scripts/pincel.gd")

var _brilho: Texture2D = null

# no máximo 4 efeitos ao mesmo tempo (rajada não pesa na TV Box); a contagem é
# pelo grupo (static var prenderia o script na memória até o jogo fechar)
const MAX_VIVOS := 4
const GRUPO := "fx_egito_acerto"

var _tex: Texture2D
var _tipo := ""
var _t := 0.0
var _dur := 1.8
var _k := 1.0
var _centro := Vector2.ZERO
var _cor := Color.WHITE
var _certo := true
var _luz: Node2D
var _cacos: Array[Dictionary] = []
var _faiscas: Array[Dictionary] = []
var _aneis: Array[Dictionary] = []
var _raios: Array[Dictionary] = []
var _arcos: Array[Dictionary] = []


static func criar(pai: Node, alvo: Node2D, tipo: String, certo: bool) -> void:
	if pai == null or alvo == null or not pai.is_inside_tree():
		return
	if pai.get_tree().get_node_count_in_group(GRUPO) >= MAX_VIVOS:
		return
	var anim: AnimatedSprite2D = null
	for f in alvo.get_children():
		if f is AnimatedSprite2D:
			anim = f
			break
	var fx := EgitoAcerto.new()
	fx._brilho = FundoVivo.brilho_redondo()
	fx.add_to_group(GRUPO)
	fx.top_level = true
	fx.z_as_relative = false
	fx.z_index = 300
	pai.add_child(fx)
	fx._montar(alvo, anim, tipo, certo)


func _montar(alvo: Node2D, anim: AnimatedSprite2D, tipo: String, certo: bool) -> void:
	_tipo = tipo
	_certo = certo
	_centro = anim.global_position if anim != null else alvo.global_position
	var lua := tipo == "lua"
	_cor = Color(0.80, 0.90, 1.0) if lua else Color(1.0, 0.80, 0.32)
	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_luz = Node2D.new()
	_luz.material = soma
	_luz.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_luz.draw.connect(_desenhar_luz)
	add_child(_luz)

	_k = clampf(absf(alvo.global_transform.get_scale().x) / 0.5, 0.6, 1.6)
	if anim != null and anim.sprite_frames != null and anim.sprite_frames.has_animation(anim.animation):
		var quadro := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
		if quadro != null:
			_cortar(anim, quadro)

	var anel := _cor if certo else Color(1.0, 0.25, 0.2)
	_aneis.append({"raio": 170.0 * _k, "t": 0.0, "vida": 0.5, "cor": Color(anel, 0.9), "larg": 12.0 * _k})
	_aneis.append({"raio": 120.0 * _k, "t": -0.1, "vida": 0.45, "cor": Color(1, 1, 1, 0.6), "larg": 5.0 * _k})
	if lua:
		for i in 4:
			_arcos.append({"ang": TAU * i / 4.0 + randf_range(-0.3, 0.3), "giro": randf_range(3.0, 5.0) * (1.0 if i % 2 == 0 else -1.0),
				"r0": 30.0 * _k, "r1": 150.0 * _k * randf_range(0.8, 1.1), "t": 0.0, "vida": randf_range(0.55, 0.75)})
		for i in 44:
			_nova_faisca(randf_range(60.0, 260.0), randf_range(6.0, 16.0), randf_range(0.8, 1.5),
				Color(0.85, 0.95, 1.0).lerp(Color(0.6, 0.8, 1.0), randf()), -50.0, true)
	else:
		var n := 12
		var a0 := randf() * TAU
		for i in n:
			_raios.append({"ang": a0 + TAU * i / n + randf_range(-0.12, 0.12), "comp": randf_range(150.0, 230.0) * _k,
				"larg": randf_range(0.05, 0.10), "t": 0.0, "vida": randf_range(0.35, 0.5)})
		for i in 40:
			_nova_faisca(randf_range(100.0, 380.0), randf_range(7.0, 18.0), randf_range(0.6, 1.2),
				Color(1.0, 0.85, 0.4).lerp(Color(1.0, 0.55, 0.15), randf()), 260.0, false)


func _cortar(anim: AnimatedSprite2D, quadro: Texture2D) -> void:
	var atlas: Texture2D = quadro
	var regiao := Rect2(Vector2.ZERO, quadro.get_size())
	if quadro is AtlasTexture and (quadro as AtlasTexture).atlas != null:
		atlas = (quadro as AtlasTexture).atlas
		regiao = (quadro as AtlasTexture).region
	_tex = atlas
	var folha := atlas.get_size()
	var xf := anim.get_global_transform()
	var canto := anim.offset - (regiao.size * 0.5 if anim.centered else Vector2.ZERO)
	var c := regiao.size * 0.5
	var r := minf(regiao.size.x, regiao.size.y) * 0.40
	var corpo := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		corpo.append(c + Vector2(cos(a), sin(a)) * r)
	var tiro := c + Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2)) * r
	var n := 8
	var a0 := randf() * TAU
	var raios := [0.0, r * randf_range(0.4, 0.55), r * 3.0]
	for i in n:
		var ai := a0 + TAU * i / n
		var af := a0 + TAU * (i + 1) / n
		for j in 2:
			var setor := PackedVector2Array()
			for s in 5:
				var a := lerpf(ai, af, s / 4.0)
				setor.append(tiro + Vector2(cos(a), sin(a)) * raios[j + 1])
			if j == 0:
				setor.append(tiro)
			else:
				for s in 5:
					var a := lerpf(af, ai, s / 4.0)
					setor.append(tiro + Vector2(cos(a), sin(a)) * raios[j])
			for peca in Geometry2D.intersect_polygons(setor, corpo):
				_novo_caco(peca, regiao, folha, xf, canto, tiro)


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
		dir = Vector2.UP
	_cacos.append({
		"pos": xf * (canto + centro),
		"vel": dir.rotated(randf_range(-0.3, 0.3)) * randf_range(220.0, 460.0) * _k + Vector2(0, -120.0 * _k),
		"ang": 0.0, "giro": randf_range(-9.0, 9.0), "t": 0.0, "vida": randf_range(0.7, 1.1),
		"rel": rel, "uvs": uvs, "tri": tri, "fase": randf() * TAU,
	})


func _nova_faisca(vel: float, tam: float, vida: float, cor: Color, grav: float, estrela: bool) -> void:
	_faiscas.append({
		"pos": _centro + Vector2(randf_range(-10, 10), randf_range(-10, 10)) * _k,
		"vel": Vector2.RIGHT.rotated(randf() * TAU) * vel * _k, "tam": tam * _k, "t": 0.0, "vida": vida,
		"cor": cor, "fase": randf() * TAU, "grav": grav * _k, "estrela": estrela,
	})


func _process(delta: float) -> void:
	_t += delta
	if _t >= _dur:
		queue_free()
		return
	for c in _cacos:
		c["t"] += delta
		c["vel"] = c["vel"] * pow(0.35, delta) + Vector2(0, 1100.0 * _k) * delta
		c["pos"] += c["vel"] * delta
		c["ang"] += c["giro"] * delta
	for f in _faiscas:
		f["t"] += delta
		f["vel"] = f["vel"] * pow(0.06, delta) + Vector2(0, f["grav"]) * delta
		f["pos"] += f["vel"] * delta
	for a in _aneis:
		a["t"] += delta
	for r in _raios:
		r["t"] += delta
	for a in _arcos:
		a["t"] += delta
		a["ang"] += a["giro"] * delta
	queue_redraw()
	_luz.queue_redraw()


func _draw() -> void:
	if _tex == null:
		return
	var pontos := PackedVector2Array()
	var cores := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for c in _cacos:
		var resta: float = c["vida"] - c["t"]
		if resta <= 0.0:
			continue
		# o metal pisca quando gira e pega a luz
		var brilho: float = 1.0 + 0.5 * maxf(0.0, sin(c["t"] * 14.0 + c["fase"]))
		var cor := Color(brilho, brilho, brilho, clampf(resta / 0.3, 0.0, 1.0))
		var ini := pontos.size()
		var rel: PackedVector2Array = c["rel"]
		var uv: PackedVector2Array = c["uvs"]
		for i in rel.size():
			pontos.append(c["pos"] + rel[i].rotated(c["ang"]))
			cores.append(cor)
			uvs.append(uv[i])
		for i in c["tri"]:
			indices.append(ini + i)
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, pontos, cores, uvs,
			PackedInt32Array(), PackedFloat32Array(), _tex.get_rid())


func _desenhar_luz() -> void:
	# clarão
	if _t < 0.3:
		var k := _t / 0.3
		var s := 260.0 * _k * (0.5 + 0.7 * k)
		_luz.draw_texture_rect(_brilho, Rect2(_centro - Vector2(s, s) * 0.5, Vector2(s, s)), false,
			Color(_cor.lerp(Color(1, 1, 1), 0.5), (1.0 - k) * (1.0 - k)))
	# leque de raios do sol
	for r in _raios:
		var k: float = r["t"] / r["vida"]
		if k >= 1.0:
			continue
		var abre := 1.0 - (1.0 - k) * (1.0 - k)
		var comp: float = r["comp"] * (0.3 + 0.7 * abre)
		var a: float = r["ang"]
		var w: float = r["larg"] * (1.0 - 0.5 * k)
		var base := _centro + Vector2(cos(a), sin(a)) * 18.0 * _k
		var ponta := _centro + Vector2(cos(a), sin(a)) * comp
		var lado := Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * comp * w * 0.5
		# feixe: forte na base, some na ponta
		var forte := Color(_cor.lerp(Color(1, 1, 1), 0.4), 0.9 * (1.0 - k))
		var some := Color(_cor, 0.0)
		_luz.draw_polygon(PackedVector2Array([base, ponta + lado, ponta - lado]), PackedColorArray([forte, some, some]))
	# anéis
	for a in _aneis:
		var t: float = a["t"]
		if t < 0.0 or t >= a["vida"]:
			continue
		var k: float = t / a["vida"]
		var ease := 1.0 - (1.0 - k) * (1.0 - k)
		var cor: Color = a["cor"]
		# anéis, arcos e estrelas pelo pincel: na TV Box a luz somada só
		# desenha retângulos de textura (scripts/pincel.gd)
		Pincel.anel(_luz, _centro, 14.0 * _k + a["raio"] * ease, maxf(1.0, a["larg"] * (1.0 - k)), Color(cor, cor.a * (1.0 - k)))
	# arcos de luar
	for a in _arcos:
		var k: float = a["t"] / a["vida"]
		if k >= 1.0:
			continue
		var r: float = lerpf(a["r0"], a["r1"], 1.0 - (1.0 - k) * (1.0 - k))
		Pincel.arco(_luz, _centro, r, a["ang"], a["ang"] + 1.3, Color(0.85, 0.93, 1.0, 0.8 * (1.0 - k)), 5.0 * _k * (1.0 - k) + 1.0)
	# faíscas / estrelas
	for f in _faiscas:
		var k: float = f["t"] / f["vida"]
		if k >= 1.0:
			continue
		var pisca := 0.55 + 0.45 * sin(f["t"] * 24.0 + f["fase"])
		var cor: Color = f["cor"]
		cor.a = (1.0 - k) * pisca
		var s: float = f["tam"] * (1.0 - 0.4 * k)
		_luz.draw_texture_rect(_brilho, Rect2(f["pos"] - Vector2(s, s) * 0.5, Vector2(s, s)), false, cor)
		if f["estrela"]:
			var b := s * 1.2
			Pincel.linha(_luz, f["pos"] - Vector2(b, 0), f["pos"] + Vector2(b, 0), cor, 1.4 * _k)
			Pincel.linha(_luz, f["pos"] - Vector2(0, b), f["pos"] + Vector2(0, b), cor, 1.4 * _k)


