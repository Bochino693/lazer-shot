extends Node2D
class_name Cacos

## CACOS DA PRÓPRIA IMAGEM: o alvo acertado se parte em pedaços que voam,
## giram, caem e somem (garrafa, brasão, lanterna, cristal, vidraça...).
## A rachadura nasce no ponto do tiro: os pedaços perto dele são pequenos e
## os de longe, grandes. Todos os pedaços saem num desenho só (triângulos
## com a textura do alvo); parado, o nó não desenha nada.

const MAX = 90

var _lista = []
var _rng = RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	set_process(false)


## tex/regiao: a imagem do alvo e o retângulo dela (px da textura) que está
## na tela; xf: a transformação do alvo na tela (posição, giro, escala) com o
## centro da região na origem; tiro: o ponto do tiro (coords deste nó).
## opções: n (pedaços, padrão 14), forca, grav, chao, vida, cor, sobe (empurrão
## para cima), giro.
func estourar(tex: Texture, regiao: Rect2, xf: Transform2D, tiro: Vector2, o: Dictionary = {}) -> void:
	if tex == null:
		return
	var n = int(max(6, round(float(o.get("n", 14)) * Maquina.fator_efeitos())))
	var forca: float = o.get("forca", 1.0)
	var grav: float = o.get("grav", 1500.0)
	var chao: float = o.get("chao", 1.0e9)
	var vida: float = o.get("vida", 1.1)
	var cor: Color = o.get("cor", Color.white)
	var sobe: float = o.get("sobe", 260.0)
	var giro: float = o.get("giro", 9.0)
	var ts = tex.get_size()
	var meia = regiao.size * 0.5
	# o ponto do tiro dentro da imagem (px da região, a partir do centro)
	var tiro_local = xf.affine_inverse().xform(tiro)
	tiro_local.x = clamp(tiro_local.x, -meia.x * 0.8, meia.x * 0.8)
	tiro_local.y = clamp(tiro_local.y, -meia.y * 0.8, meia.y * 0.8)
	# pontos na borda da região, em volta do tiro (leque)
	var borda = []
	var base_ang = _rng.randf() * TAU
	for i in n:
		var a = base_ang + TAU * (float(i) + _rng.randf_range(-0.3, 0.3)) / n
		var d = Vector2(cos(a), sin(a))
		# até onde a reta sai da caixa
		var tx = INF if abs(d.x) < 0.0001 else ((meia.x if d.x > 0.0 else -meia.x) - tiro_local.x) / d.x
		var ty = INF if abs(d.y) < 0.0001 else ((meia.y if d.y > 0.0 else -meia.y) - tiro_local.y) / d.y
		borda.append(tiro_local + d * min(tx, ty))
	for i in n:
		var a: Vector2 = borda[i]
		var b: Vector2 = borda[(i + 1) % n]
		# cada fatia do leque em dois pedaços: um perto do tiro e um longe
		var k = _rng.randf_range(0.30, 0.50)
		var a2 = tiro_local.linear_interpolate(a, k)
		var b2 = tiro_local.linear_interpolate(b, k)
		_pedaco([tiro_local, a2, b2], tex, ts, regiao, xf, tiro, forca * 1.25, grav, chao, vida, cor, sobe, giro)
		_pedaco([a2, a, b, b2], tex, ts, regiao, xf, tiro, forca, grav, chao, vida, cor, sobe, giro)
	while _lista.size() > MAX:
		_lista.pop_front()
	set_process(true)


func _pedaco(pts: Array, tex: Texture, ts: Vector2, regiao: Rect2, xf: Transform2D, tiro: Vector2,
		forca: float, grav: float, chao: float, vida: float, cor: Color, sobe: float, giro: float) -> void:
	var centro = Vector2.ZERO
	for p in pts:
		centro += p
	centro /= pts.size()
	var locais = PoolVector2Array()
	var uvs = PoolVector2Array()
	for p in pts:
		locais.append(xf.basis_xform(p - centro))
		var px: Vector2 = p + regiao.size * 0.5 + regiao.position
		uvs.append(Vector2(px.x / ts.x, px.y / ts.y))
	var mundo = xf.xform(centro)
	var dir = (mundo - tiro)
	if dir.length() < 1.0:
		dir = Vector2(_rng.randf_range(-1, 1), -1)
	dir = dir.normalized()
	var v = dir * _rng.randf_range(160.0, 460.0) * forca + Vector2(_rng.randf_range(-60, 60), -sobe * _rng.randf_range(0.5, 1.2))
	_lista.append({"pts": locais, "uv": uvs, "tex": tex, "pos": mundo, "vel": v, "rot": 0.0,
		"giro": _rng.randf_range(-giro, giro), "t": 0.0, "vida": vida * _rng.randf_range(0.75, 1.25),
		"grav": grav, "chao": chao, "cor": cor})


func vazio() -> bool:
	return _lista.empty()


func _process(delta: float) -> void:
	if _lista.empty():
		set_process(false)
		update()
		return
	var i = 0
	while i < _lista.size():
		var c: Dictionary = _lista[i]
		c["t"] += delta
		if c["t"] >= c["vida"]:
			_lista.remove(i)
			continue
		var v: Vector2 = c["vel"]
		v.y += c["grav"] * delta
		var p: Vector2 = c["pos"] + v * delta
		if p.y > c["chao"]:
			p.y = c["chao"]
			v = Vector2(v.x * 0.5, -abs(v.y) * 0.22)
			c["giro"] *= 0.4
		c["vel"] = v
		c["pos"] = p
		c["rot"] += c["giro"] * delta
		i += 1
	update()


func _draw() -> void:
	for c in _lista:
		var k: float = c["t"] / c["vida"]
		var cor: Color = c["cor"]
		cor.a *= clamp((1.0 - k) * 3.0, 0.0, 1.0)
		var cores = PoolColorArray()
		var pts = PoolVector2Array()
		var rot = Transform2D(c["rot"], c["pos"])
		for p in c["pts"]:
			pts.append(rot.xform(p))
			cores.append(cor)
		draw_polygon(pts, cores, c["uv"], c["tex"])
