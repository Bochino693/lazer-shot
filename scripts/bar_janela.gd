extends Node2D

## A JANELA DO BAR (a da pintura do fundo), com desenho próprio: cada tiro
## destrói o vidro de verdade.
##   - a vidraça estoura: o vidro racha do furo para fora em raios e dois
##     anéis; o miolo e o meio caem em cacos recortados do próprio vidro, que
##     giram piscando na luz, quicam na tábua de baixo (ou no peitoril), os
##     grandes se partem e ficam deitados um pouco; pó de vidro brilhando e
##     lascas do caixilho;
##   - fica o buraco, com a luz de fora entrando, e as pontas de vidro presas
##     na moldura (as bordas cortadas brilham);
##   - as vidraças do lado trincam com o tranco;
##   - tiro numa vidraça quebrada derruba as pontas perto dele (no buraco
##     vazio a bala passa lá para fora);
##   - desabar(): o que sobrou do vidro cai de uma vez, vidraça por vidraça.
## Em pontos do jogo, filho do cenário por baixo do feixe de sol (o sol soma
## por cima dos buracos). Só redesenha enquanto algo cai.

enum { INTEIRA, TRINCADA, QUEBRADA }
# o que o tiro fez na janela
enum { FORA, QUEBROU, PASSOU }

# vizinhas da mesma folha da janela (trincam junto)
const VIZINHAS = [[1, 4], [0, 5], [3, 6], [2, 7], [0, 5], [1, 4], [2, 7], [3, 6]]
const MAX_CACOS = 70
const VIDA_CACO = 3.6
const CEU_ALTO = Color(0.70, 0.84, 1.0, 0.84)
const CEU_BAIXO = Color(1.0, 0.95, 0.86, 0.78)

var _rects = []          # vidraças (pontos do jogo)
var _tex: Texture        # o fundo do bar (o vidro é a pintura dele)
var _uv = Vector2.ONE    # ponto do jogo -> uv da textura
var _k = 1.0             # pontos do jogo por pixel da imagem da 4.6 (medidas)
var _tabua = 0.0         # y da tábua embaixo da janela
var _peitoril = Vector3.ZERO   # x de, x até e y do tampo do peitoril
var _grav = 1250.0
var _estado = []
var _trincas = []        # por vidraça: linhas (PoolVector2Array)
var _pontas = []         # por vidraça: [{poly, livres}] (vidro preso na moldura)
var _cacos = []
var _miudos = []         # pó de vidro brilhando (luz somada)
var _po = []             # nuvem de pó de vidro
var _lascas = []         # lascas da madeira do caixilho
var _fila = []           # desabando: [{i, t}]
var _clarao = 0.0        # o tiro acendendo a luz de fora (1 -> 0)
var _clarao_pos = Vector2.ZERO
var _t = 0.0
var _luz: Node2D
var _buracos = []        # brilho de cada buraco (Sprite somado)
var _t_brilho: Texture
var _t_ponto: Texture
var _t_nuvem: Texture
var _som: AudioStream


## rects: as vidraças na tela; tex: o fundo; px_tex: pontos do jogo por pixel
## da textura; k: pontos do jogo por pixel da imagem da 4.6; tabua: y da tábua
## de baixo; peitoril: (x de, x até, y do tampo).
func configurar(rects: Array, tex: Texture, px_tex: float, k: float, tabua: float, peitoril: Vector3) -> void:
	_rects = rects
	_tex = tex
	_uv = Vector2.ONE / (tex.get_size() * px_tex)
	_k = k
	_grav = 1250.0 * k
	_tabua = tabua
	_peitoril = peitoril
	for i in _rects.size():
		_estado.append(INTEIRA)
		_trincas.append([])
		_pontas.append([])
		_buracos.append(null)
	_t_brilho = Estilo.tex("fx_brilho")
	_t_ponto = Estilo.tex("fx_ponto")
	_t_nuvem = Estilo.tex("fx_nuvem")
	_som = load("res://songs/janela_quebra.wav")
	_luz = Node2D.new()
	_luz.material = Estilo.material_soma()
	_luz.connect("draw", self, "_desenhar_luz")
	add_child(_luz)
	set_process(false)


## Tiro que não pegou garrafa nem barril: FORA (não é na janela), QUEBROU
## (destruiu vidro) ou PASSOU (buraco vazio: a bala foi lá para fora).
func tiro(p: Vector2) -> int:
	for i in _rects.size():
		var r: Rect2 = _rects[i]
		if not r.has_point(p):
			continue
		if _estado[i] == QUEBRADA:
			return QUEBROU if _soltar_pontas(i, p) else PASSOU
		_estourar(i, p)
		return QUEBROU
	return FORA


func quebradas() -> int:
	return _estado.count(QUEBRADA)


## A luz de fora acesa pelo tiro (1 -> 0): o feixe de sol cresce junto.
func clarao() -> float:
	return _clarao


## O que sobrou do vidro cai de uma vez, vidraça por vidraça a partir do
## ponto do tiro.
func desabar(p: Vector2) -> void:
	var ordem = []
	for i in _rects.size():
		var r: Rect2 = _rects[i]
		ordem.append([(r.position + r.size * 0.5).distance_to(p), i])
	ordem.sort_custom(self, "_mais_perto")
	var n = 0
	for par in ordem:
		var i: int = par[1]
		if _estado[i] == QUEBRADA and _pontas[i].empty():
			continue
		_fila.append({"i": i, "t": 0.12 + 0.09 * n})
		n += 1
	if n > 0:
		Maquina.efeito(_som, 0.0, 0.82)
		_ligar()


func _mais_perto(a: Array, b: Array) -> bool:
	return a[0] < b[0]


## O brilho dos buracos respira como o sol lá fora (chamado pela fase).
func respirar(t: float) -> void:
	for i in _buracos.size():
		var s: Sprite = _buracos[i]
		if s != null:
			s.modulate.a = 0.24 + 0.1 * sin(t * 1.3 + i * 0.9)


# ───────────────────────────────────────────── a vidraça estourando
func _estourar(i: int, p: Vector2, som: bool = true) -> void:
	var r: Rect2 = _rects[i]
	var m = 5.0 * _k
	var c = Vector2(clamp(p.x, r.position.x + m, r.end.x - m), clamp(p.y, r.position.y + m, r.end.y - m))
	var caixa = PoolVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	_estado[i] = QUEBRADA
	_trincas[i] = []
	# rachaduras saindo do furo (raios) e dois anéis: o miolo e o meio caem;
	# o que passa do segundo anel quase sempre fica preso na moldura
	var n = 7 + randi() % 3
	var giro0 = randf() * TAU
	var angs = []
	for k in n:
		angs.append(giro0 + TAU * (k + rand_range(-0.28, 0.28)) / n)
	var anel1 = []
	var anel2 = []
	for k in n:
		var borda = _ate_a_borda(c, Vector2(cos(angs[k]), sin(angs[k])), r)
		anel1.append(borda * rand_range(0.28, 0.46))
		anel2.append(borda * rand_range(0.62, 0.86))
	var pontas = []
	var longe = 300.0 * _k
	for k in n:
		var k2 = (k + 1) % n
		var a0: float = angs[k]
		var a1: float = angs[k2] + (TAU if k2 == 0 else 0.0)
		var am = (a0 + a1) * 0.5 + rand_range(-0.12, 0.12)
		var dm = Vector2(cos(am), sin(am))
		var bm = _ate_a_borda(c, dm, r)
		var r1m = bm * rand_range(0.28, 0.46)
		var r2m = bm * rand_range(0.62, 0.86)
		var d0 = Vector2(cos(a0), sin(a0))
		var d1 = Vector2(cos(a1), sin(a1))
		var miolo = PoolVector2Array([c + d0 * 1.5, c + d0 * anel1[k], c + dm * r1m, c + d1 * anel1[k2], c + d1 * 1.5])
		var meio = PoolVector2Array([c + d0 * anel1[k], c + d0 * anel2[k], c + dm * r2m, c + d1 * anel2[k2], c + d1 * anel1[k2], c + dm * r1m])
		var fora = PoolVector2Array([c + d0 * anel2[k], c + d0 * longe, c + dm * longe, c + d1 * longe, c + d1 * anel2[k2], c + dm * r2m])
		for q in Geometry.intersect_polygons_2d(miolo, caixa):
			_novo_caco(q, c, 1.0)
		for q in Geometry.intersect_polygons_2d(meio, caixa):
			# o pedaço do meio às vezes parte em dois no caminho
			if randf() < 0.45 and q.size() >= 4:
				for metade in _partir(q):
					_novo_caco(metade, c, 0.8)
			else:
				_novo_caco(q, c, 0.8)
		for q in Geometry.intersect_polygons_2d(fora, caixa):
			if randf() < 0.82:
				pontas.append({"poly": q, "livres": _arestas_livres(q, r)})
			else:
				_novo_caco(q, c, 0.55)
	_pontas[i] = pontas
	# pó de vidro brilhando, a nuvem de pó e as lascas do caixilho
	for k in 26:
		_miudos.append({"pos": c + Vector2(rand_range(-4, 4), rand_range(-4, 4)) * _k,
			"vel": Vector2(cos(randf() * TAU), sin(randf() * TAU)) * rand_range(60.0, 260.0) * _k + Vector2(0, -40.0 * _k),
			"t": 0.0, "vida": rand_range(0.5, 1.1), "fase": randf() * TAU, "deitado": false})
	for k in 4:
		_po.append({"pos": c + Vector2(rand_range(-6, 6), rand_range(-6, 6)) * _k, "vel": Vector2(rand_range(-30, 30), rand_range(-10, 40)) * _k,
			"t": 0.0, "vida": rand_range(0.7, 1.2), "tam": rand_range(26.0, 44.0) * _k, "ang": randf() * TAU})
	var lado = Vector2(r.position.x if c.x - r.position.x < r.end.x - c.x else r.end.x, c.y)
	for k in 7:
		_lascas.append({"pos": lado + Vector2(0, rand_range(-14, 14) * _k),
			"vel": Vector2(rand_range(-120, 120), rand_range(-160, -30)) * _k, "ang": randf() * TAU, "giro": rand_range(-18, 18),
			"tam": Vector2(rand_range(3.0, 6.0), rand_range(1.0, 1.8)) * _k, "t": 0.0, "vida": rand_range(0.5, 0.9),
			"cor": Color(0.62, 0.36, 0.16).linear_interpolate(Color(0.92, 0.66, 0.38), randf())})
	# as vizinhas trincam com o tranco
	for v in VIZINHAS[i]:
		if _estado[v] == INTEIRA:
			_estado[v] = TRINCADA
			_trincas[v] = _trincar(_rects[v], _rects[i])
	# o buraco: a luz de fora entra
	var b = Sprite.new()
	b.texture = _t_brilho
	b.material = Estilo.material_soma()
	b.position = r.position + r.size * 0.5
	b.scale = r.size * 1.4 / _t_brilho.get_width()
	b.modulate = Color(1.0, 0.9, 0.65, 0.3)
	add_child(b)
	move_child(b, 0)
	_buracos[i] = b
	_clarao = 1.0
	_clarao_pos = c
	if som:
		Maquina.efeito(_som, -2.0, rand_range(0.95, 1.06))
	_ligar()


## Tiro numa vidraça já quebrada: as pontas perto dele caem. Devolve se
## soltou alguma (senão a bala passou pelo buraco).
func _soltar_pontas(i: int, p: Vector2) -> bool:
	var r: Rect2 = _rects[i]
	var ficam = []
	var soltou = 0
	for pt in _pontas[i]:
		var poly: PoolVector2Array = pt["poly"]
		if Geometry.is_point_in_polygon(p, poly) or _centro(poly).distance_to(p) < (22.0 + randf() * 8.0) * _k:
			_novo_caco(poly, p, 0.5)
			soltou += 1
		else:
			ficam.append(pt)
	_pontas[i] = ficam
	if soltou == 0:
		return false
	for k in 10:
		_miudos.append({"pos": p, "vel": Vector2(cos(randf() * TAU), sin(randf() * TAU)) * rand_range(50.0, 180.0) * _k,
			"t": 0.0, "vida": rand_range(0.4, 0.9), "fase": randf() * TAU, "deitado": false})
	_clarao = max(_clarao, 0.5)
	_clarao_pos = Vector2(clamp(p.x, r.position.x, r.end.x), clamp(p.y, r.position.y, r.end.y))
	Maquina.efeito(_som, -9.0, rand_range(1.2, 1.35))
	_ligar()
	return true


## Desabando: a vidraça inteira cai (estoura, se ainda estava lá, e as
## pontas presas soltam todas).
func _cair_tudo(i: int) -> void:
	var r: Rect2 = _rects[i]
	var centro = r.position + r.size * 0.5
	if _estado[i] != QUEBRADA:
		_estourar(i, centro + Vector2(rand_range(-0.3, 0.3) * r.size.x, rand_range(-0.3, 0.3) * r.size.y), false)
	for pt in _pontas[i]:
		_novo_caco(pt["poly"], centro, 0.4)
	_pontas[i] = []
	_clarao = max(_clarao, 0.7)
	_clarao_pos = centro
	Maquina.efeito(_som, -8.0, rand_range(1.0, 1.25))


func _novo_caco(poly: PoolVector2Array, furo: Vector2, forca: float) -> void:
	if poly.size() < 3:
		return
	var centro = _centro(poly)
	var rel = PoolVector2Array()
	var uvs = PoolVector2Array()
	for v in poly:
		rel.append(v - centro)
		uvs.append(v * _uv)
	var area = abs(_area(rel))
	if area < 1.0:
		return
	var sai = centro - furo
	sai = sai.normalized() if sai.length() > 0.5 else Vector2(cos(randf() * TAU), sin(randf() * TAU))
	# o miolo voa mais rápido; os grandes caem mais reto
	var vel = sai * rand_range(50.0, 170.0) * forca * _k + Vector2(rand_range(-25, 25), rand_range(-70, 10)) * _k
	var chao = _tabua
	if centro.x > _peitoril.x and centro.x < _peitoril.y and centro.y < _peitoril.z and randf() < 0.35:
		chao = _peitoril.z
	_cacos.append({"pos": centro, "vel": vel, "ang": 0.0, "giro": rand_range(-7.0, 7.0) / max(0.6, sqrt(area) / (8.0 * _k)),
		"rel": rel, "uvs": uvs, "area": area, "t": 0.0, "chao": chao, "toques": 0, "frente": 0.0, "deitado": 0.0, "fase": randf() * TAU})
	while _cacos.size() > MAX_CACOS:
		_cacos.pop_front()


## Parte um polígono em dois por uma reta que passa perto do meio.
func _partir(q: PoolVector2Array) -> Array:
	var centro = _centro(q)
	var a = randf() * PI
	var d = Vector2(cos(a), sin(a))
	var n = Vector2(-d.y, d.x)
	var l = 300.0 * _k
	var faca = PoolVector2Array([centro - d * l, centro + d * l, centro + d * l + n * l, centro - d * l + n * l])
	var saida = []
	for x in Geometry.clip_polygons_2d(q, faca) + Geometry.intersect_polygons_2d(q, faca):
		if x.size() >= 3:
			saida.append(x)
	return saida if not saida.empty() else [q]


## Distância do ponto até a borda da vidraça andando na direção d.
func _ate_a_borda(c: Vector2, d: Vector2, r: Rect2) -> float:
	var t = 1.0e6
	if d.x > 0.0001:
		t = min(t, (r.end.x - c.x) / d.x)
	elif d.x < -0.0001:
		t = min(t, (r.position.x - c.x) / d.x)
	if d.y > 0.0001:
		t = min(t, (r.end.y - c.y) / d.y)
	elif d.y < -0.0001:
		t = min(t, (r.position.y - c.y) / d.y)
	return max(t, 2.0)


## Arestas da ponta presa que ficaram soltas (cortadas no vidro): são as que
## brilham. As encostadas na moldura não aparecem.
func _arestas_livres(q: PoolVector2Array, r: Rect2) -> PoolIntArray:
	var livres = PoolIntArray()
	var e = 0.7
	for k in q.size():
		var a: Vector2 = q[k]
		var b: Vector2 = q[(k + 1) % q.size()]
		var na_borda = (abs(a.x - r.position.x) < e and abs(b.x - r.position.x) < e) \
			or (abs(a.x - r.end.x) < e and abs(b.x - r.end.x) < e) \
			or (abs(a.y - r.position.y) < e and abs(b.y - r.position.y) < e) \
			or (abs(a.y - r.end.y) < e and abs(b.y - r.end.y) < e)
		if not na_borda:
			livres.append(k)
	return livres


## Trincas numa vidraça vizinha: saem da beira que encosta na que quebrou.
func _trincar(r: Rect2, de: Rect2) -> Array:
	var cr = r.position + r.size * 0.5
	var cd = de.position + de.size * 0.5
	var m = 10.0 * _k
	var ini: Vector2
	if abs(cd.x - cr.x) > abs(cd.y - cr.y):
		ini = Vector2(r.position.x if cd.x < cr.x else r.end.x, rand_range(r.position.y + m, r.end.y - m))
	else:
		ini = Vector2(rand_range(r.position.x + m, r.end.x - m), r.position.y if cd.y < cr.y else r.end.y)
	var linhas = []
	var rumo = (cr - ini).normalized()
	for k in 2 + randi() % 2:
		var pts = PoolVector2Array([ini])
		var d = rumo.rotated(rand_range(-0.8, 0.8))
		var p = ini
		for s in 3 + randi() % 3:
			d = d.rotated(rand_range(-0.28, 0.28))
			p += d * rand_range(5.0, 11.0) * _k
			if not r.grow(-1.0).has_point(p):
				break
			pts.append(p)
		if pts.size() >= 2:
			linhas.append(pts)
	return linhas


func _centro(q: PoolVector2Array) -> Vector2:
	var s = Vector2.ZERO
	for v in q:
		s += v
	return s / max(1.0, q.size())


func _area(q: PoolVector2Array) -> float:
	var a = 0.0
	for k in q.size():
		a += q[k].cross(q[(k + 1) % q.size()])
	return a * 0.5


# ───────────────────────────────────────────── movimento
func _ligar() -> void:
	set_process(true)
	update()
	_luz.update()


func _process(delta: float) -> void:
	_t += delta
	_clarao = max(0.0, _clarao - delta * 2.6)
	# desabando: a próxima vidraça da fila
	var j = 0
	while j < _fila.size():
		_fila[j]["t"] -= delta
		if _fila[j]["t"] <= 0.0:
			_cair_tudo(_fila[j]["i"])
			_fila.remove(j)
			continue
		j += 1
	for c in _cacos:
		c["t"] += delta
		if c["deitado"] > 0.0:
			continue
		c["vel"] += Vector2(0, _grav) * delta
		c["pos"] += c["vel"] * delta
		c["ang"] += c["giro"] * delta
		c["frente"] = min(1.0, c["frente"] + delta * 3.0)
		if c["pos"].y >= c["chao"] and c["vel"].y > 0.0:
			c["pos"].y = c["chao"]
			c["toques"] += 1
			_bater(c)
	for i in range(_cacos.size() - 1, -1, -1):
		if _cacos[i]["t"] > VIDA_CACO:
			_cacos.remove(i)
	for m in _miudos:
		m["t"] += delta
		if m["deitado"]:
			continue
		m["vel"] = m["vel"] * pow(0.35, delta) + Vector2(0, _grav * 0.7) * delta
		m["pos"] += m["vel"] * delta
		if m["pos"].y >= _tabua and m["vel"].y > 0.0:
			m["pos"].y = _tabua
			m["deitado"] = true
			m["vida"] = m["t"] + rand_range(1.2, 2.4)
	for i in range(_miudos.size() - 1, -1, -1):
		if _miudos[i]["t"] >= _miudos[i]["vida"]:
			_miudos.remove(i)
	for p in _po:
		p["t"] += delta
		p["vel"] = p["vel"] * pow(0.2, delta)
		p["pos"] += p["vel"] * delta
	for i in range(_po.size() - 1, -1, -1):
		if _po[i]["t"] >= _po[i]["vida"]:
			_po.remove(i)
	for l in _lascas:
		l["t"] += delta
		l["vel"] += Vector2(0, _grav) * delta
		l["pos"] += l["vel"] * delta
		l["ang"] += l["giro"] * delta
	for i in range(_lascas.size() - 1, -1, -1):
		if _lascas[i]["t"] >= _lascas[i]["vida"]:
			_lascas.remove(i)
	update()
	_luz.update()
	if _cacos.empty() and _miudos.empty() and _po.empty() and _lascas.empty() and _fila.empty() and _clarao <= 0.0:
		set_process(false)


## O caco bateu na tábua: quica mais baixo, o grande se parte e no fim fica
## deitado (achatado de frente) brilhando um pouco antes de sumir.
func _bater(c: Dictionary) -> void:
	var v: Vector2 = c["vel"]
	for k in 2 + randi() % 3:
		_miudos.append({"pos": c["pos"], "vel": Vector2(rand_range(-110, 110), rand_range(-150, -50)) * _k,
			"t": 0.0, "vida": rand_range(0.6, 1.4), "fase": randf() * TAU, "deitado": false})
	if c["toques"] >= 3 or abs(v.y) < 120.0 * _k:
		c["vel"] = Vector2.ZERO
		c["giro"] = 0.0
		c["deitado"] = 1.0
		c["t"] = max(c["t"], 1.4)
		return
	if c["toques"] == 1 and c["area"] > 70.0 * _k * _k:
		# o grande se parte em dois na batida (cada metade sai do lugar dela
		# no caco, com o mesmo giro)
		var original = PoolVector2Array()
		for uv in c["uvs"]:
			original.append(uv / _uv)
		var centro0 = _centro(original)
		var pedacos = _partir(original)
		if pedacos.size() >= 2:
			c["t"] = 99.0
			var esc = 1.0 + 0.25 * c["frente"]
			for q in pedacos:
				var antes = _cacos.size()
				_novo_caco(q, centro0, 0.0)
				if _cacos.size() > antes:
					var n: Dictionary = _cacos[_cacos.size() - 1]
					n["pos"] = c["pos"] + (n["pos"] - centro0).rotated(c["ang"]) * esc
					n["ang"] = c["ang"]
					n["vel"] = Vector2(v.x * 0.5 + rand_range(-60, 60) * _k, -abs(v.y) * rand_range(0.2, 0.35))
					n["giro"] = rand_range(-6.0, 6.0)
					n["chao"] = c["chao"]
					n["toques"] = 1
					n["frente"] = c["frente"]
			return
	c["vel"] = Vector2(v.x * 0.55, -abs(v.y) * rand_range(0.22, 0.32))
	c["giro"] = c["giro"] * 0.5 + rand_range(-4.0, 4.0)


# ───────────────────────────────────────────── desenho
func _draw() -> void:
	# buracos: o céu lá fora (azul claro em cima, branco de sol embaixo), bem
	# diferente do vidro amarelado que sobrou
	for i in _rects.size():
		if _estado[i] != QUEBRADA:
			continue
		var r: Rect2 = _rects[i]
		draw_polygon(PoolVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PoolColorArray([CEU_ALTO, CEU_ALTO, CEU_BAIXO, CEU_BAIXO]))
	# pontas de vidro presas na moldura (o próprio vidro) e as bordas cortadas
	var e = max(1.0, 0.9 * _k)
	for i in _rects.size():
		for pt in _pontas[i]:
			var q: PoolVector2Array = pt["poly"]
			var uvs = PoolVector2Array()
			for v in q:
				uvs.append(v * _uv)
			draw_polygon(q, PoolColorArray([Color(0.97, 0.95, 0.92)]), uvs, _tex)
		for pt in _pontas[i]:
			var q2: PoolVector2Array = pt["poly"]
			for k in pt["livres"]:
				var a: Vector2 = q2[k]
				var b: Vector2 = q2[(k + 1) % q2.size()]
				draw_line(a, b, Color(0.42, 0.26, 0.12, 0.5), e * 1.8)
				draw_line(a, b, Color(1.0, 1.0, 0.96, 0.95), e)
	# trincas nas vizinhas
	for i in _rects.size():
		if _estado[i] != TRINCADA:
			continue
		for linha in _trincas[i]:
			draw_polyline(linha, Color(0.45, 0.3, 0.15, 0.25), e * 1.3)
			draw_polyline(linha, Color(1.0, 1.0, 0.97, 0.75), e * 0.75)
	# nuvem de pó de vidro no ar
	for p in _po:
		var k: float = p["t"] / p["vida"]
		var s: float = p["tam"] * (0.6 + 0.8 * k)
		draw_set_transform(p["pos"], p["ang"], Vector2.ONE)
		draw_texture_rect(_t_nuvem, Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), false, Color(1.0, 0.97, 0.9, 0.35 * (1.0 - k)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# cacos caindo (recortados do vidro): deixam ver a parede por trás e a
	# face que pega a luz acende; deitados na tábua, achatados
	for c in _cacos:
		var t: float = c["t"]
		if t > VIDA_CACO:
			continue
		var some = clamp((VIDA_CACO - t) / 0.5, 0.0, 1.0)
		var esc = 1.0 + 0.25 * c["frente"]
		var achata = 1.0 - 0.65 * c["deitado"]
		var face = pow(abs(sin(c["ang"] * 1.7 + c["fase"])), 6.0)
		var opaco = 0.5 + 0.42 * face
		if c["deitado"] > 0.0:
			opaco = 0.22 + 0.4 * pow(abs(sin(t * 3.0 + c["fase"])), 12.0)
		var pts = PoolVector2Array()
		for v in c["rel"]:
			var w: Vector2 = (v * esc).rotated(c["ang"])
			w.y *= achata
			pts.append(c["pos"] + w)
		draw_polygon(pts, PoolColorArray([Color(1.0, 1.0, 0.98, some * opaco)]), c["uvs"], _tex)
		if some > 0.3 and c["deitado"] <= 0.0:
			pts.append(pts[0])
			draw_polyline(pts, Color(1.0, 1.0, 0.95, 0.35 * some * (0.5 + face)), e)
	# lascas do caixilho
	for l in _lascas:
		var a2 = clamp(1.0 - l["t"] / l["vida"], 0.0, 1.0)
		var cor: Color = l["cor"]
		draw_set_transform(l["pos"], l["ang"], Vector2.ONE)
		draw_rect(Rect2(-l["tam"] * 0.5, l["tam"]), Color(cor.r, cor.g, cor.b, a2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A luz somada: o clarão do tiro, o brilho na face dos cacos e o pó de vidro.
func _desenhar_luz() -> void:
	if _clarao > 0.0:
		var r = (60.0 + 50.0 * (1.0 - _clarao)) * _k
		_luz.draw_texture_rect(_t_brilho, Rect2(_clarao_pos - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.95, 0.8, 0.9 * _clarao))
	for c in _cacos:
		var t: float = c["t"]
		if t > VIDA_CACO:
			continue
		var face = pow(abs(sin(c["ang"] * 1.7 + c["fase"])), 6.0)
		if c["deitado"] > 0.0:
			face = pow(abs(sin(t * 3.0 + c["fase"])), 12.0) * 0.6
		if face < 0.15:
			continue
		var rb = (5.0 + sqrt(c["area"]) * 0.35) * (1.0 + 0.25 * c["frente"])
		_luz.draw_texture_rect(_t_brilho, Rect2(c["pos"] - Vector2(rb, rb), Vector2(rb, rb) * 2.0), false, Color(1.0, 0.97, 0.88, 0.7 * face))
	for m in _miudos:
		var k = m["t"] / m["vida"]
		var pisca = 0.5 + 0.5 * sin(m["t"] * 22.0 + m["fase"])
		var a = (1.0 - k) * (0.4 + 0.6 * pisca)
		var s = 2.2 * _k
		_luz.draw_texture_rect(_t_ponto, Rect2(m["pos"] - Vector2(s, s), Vector2(s, s) * 2.0), false, Color(1.0, 0.98, 0.9, a))
