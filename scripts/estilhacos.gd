extends Node2D

# Garrafa estourando em cacos da PRÓPRIA imagem dela.
#
# A rachadura nasce no ponto do tiro: raios saem dali e anéis cada vez mais
# largos cortam a garrafa em pedaços (pequenos perto do tiro, grandes longe).
# Cada caco leva o pedaço da textura que tinha na garrafa e voa com
# profundidade: os que vão para o fundo batem na prateleira, quicam, deitam
# e somem; os que vêm para a frente crescem e caem pela beirada.
# Três estilos se revezam: ESTOURO, DESABA e PARTIDA (o gargalo sai inteiro).
#
# Custo: todos os cacos de uma garrafa saem num desenho só (um triângulo
# array com a folha de sprites da garrafa) e as gotas/brilhos em outro.

enum { ESTOURO, DESABA, PARTIDA }

const GRAVIDADE := 1500.0
const PRATELEIRA_FUNDO := -1.0   # z da parede
const PRATELEIRA_BEIRA := 0.55   # z da beirada da prateleira (passou: cai)
const ALTURA_PRATELEIRA := 10.0  # quanto o fundo da prateleira aparece acima da beira

static var _proximo_estilo := 0

var _textura: Texture2D
var _chao := 0.0
var _tempo := 0.0
var _duracao := 1.9

# Cacos (textura da garrafa)
var _c_pos := PackedVector2Array()
var _c_vel := PackedVector2Array()
var _c_ang := PackedFloat32Array()
var _c_giro := PackedFloat32Array()
var _c_tomb := PackedFloat32Array()
var _c_tomb_vel := PackedFloat32Array()
var _c_z := PackedFloat32Array()
var _c_vz := PackedFloat32Array()
var _c_vida := PackedFloat32Array()
var _c_solta := PackedFloat32Array()   # quando o caco começa a se mexer (PARTIDA)
var _c_pousado := PackedFloat32Array() # tempo deitado na prateleira (-1 = no ar)
var _c_inicio := PackedInt32Array()    # primeiro vértice do caco
var _c_qtd := PackedInt32Array()
var _forma := PackedVector2Array()     # vértices relativos ao centro do caco
var _pontos := PackedVector2Array()
var _cores := PackedColorArray()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()

# Gotas e brilhos (sem textura)
var _g_pos := PackedVector2Array()
var _g_vel := PackedVector2Array()
var _g_cor := PackedColorArray()
var _g_tam := PackedFloat32Array()
var _g_vida := PackedFloat32Array()
var _g_z := PackedFloat32Array()
var _g_pontos := PackedVector2Array()
var _g_cores := PackedColorArray()
var _g_indices := PackedInt32Array()

const _HEX := [Vector2(1, 0), Vector2(0.5, 0.866), Vector2(-0.5, 0.866), Vector2(-1, 0), Vector2(-0.5, -0.866), Vector2(0.5, -0.866)]


## Estoura a garrafa desenhada por `sprite` (AnimatedSprite2D) usando o
## quadro `quadro` (AtlasTexture da folha ou textura simples). `imagem` é a
## imagem já lida da folha (para pular pedaços transparentes) ou null.
static func quebrar(pai: Node, sprite: Node2D, quadro: Texture2D, imagem: Image, ponto_tiro: Vector2, cor_liquido: Color, estilo: int = -1) -> Node2D:
	if pai == null or sprite == null or quadro == null:
		return null
	var e = load("res://scripts/estilhacos.gd").new()
	e.name = "Estilhacos"
	e.z_index = 7
	e.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pai.add_child(e)
	if estilo < 0:
		estilo = _proximo_estilo
		_proximo_estilo = (_proximo_estilo + 1 + (randi() % 2)) % 3
	e._montar(sprite, quadro, imagem, ponto_tiro, cor_liquido, estilo)
	return e


func _montar(sprite: Node2D, quadro: Texture2D, imagem: Image, ponto_tiro: Vector2, cor_liquido: Color, estilo: int) -> void:
	var regiao := Rect2(Vector2.ZERO, quadro.get_size())
	_textura = quadro
	if quadro is AtlasTexture and (quadro as AtlasTexture).atlas != null:
		_textura = (quadro as AtlasTexture).atlas
		regiao = (quadro as AtlasTexture).region
	var tam_folha := _textura.get_size()
	var tam := regiao.size

	# Quadro -> tela
	var xf: Transform2D = sprite.get_global_transform()
	var canto := Vector2.ZERO
	if sprite.get("centered") != false:
		canto = -tam * 0.5
	var desloc = sprite.get("offset")
	if desloc is Vector2:
		canto += desloc
	var escala_tela: float = xf.get_scale().x

	# Parte visível da garrafa (para o chão e para pular o transparente)
	var limites := _caixa_opaca(imagem, regiao)
	_chao = (xf * (canto + Vector2(0.0, limites.end.y))).y

	var tiro := xf.affine_inverse() * ponto_tiro - canto
	tiro.x = clampf(tiro.x, limites.position.x + 4.0, limites.end.x - 4.0)
	tiro.y = clampf(tiro.y, limites.position.y + 4.0, limites.end.y - 4.0)

	# Raios e anéis da rachadura
	var raios := randi_range(7, 9)
	var giro0 := randf() * TAU
	var angulos := PackedFloat32Array()
	for i in range(raios):
		angulos.append(giro0 + (float(i) + randf_range(-0.3, 0.3)) * TAU / float(raios))
	var r_max := 0.0
	for c in [limites.position, Vector2(limites.end.x, limites.position.y), limites.end, Vector2(limites.position.x, limites.end.y)]:
		r_max = maxf(r_max, tiro.distance_to(c))
	var aneis := PackedFloat32Array([0.0])
	var r := randf_range(9.0, 14.0)
	while r < r_max:
		aneis.append(r)
		r *= randf_range(1.75, 2.1)
	aneis.append(r_max * 1.02)

	var linha_corte := Vector2.RIGHT.rotated(randf_range(-0.5, 0.5))
	var topo_garrafa := limites.position.y

	for j in range(aneis.size() - 1):
		var r0: float = aneis[j]
		var r1: float = aneis[j + 1]
		for i in range(raios):
			var a0: float = angulos[i]
			var a1: float = angulos[(i + 1) % raios]
			if a1 < a0:
				a1 += TAU
			# Pedaços longe do tiro são divididos para não virar placa.
			var partes := maxi(1, int(round((a1 - a0) * r1 / 46.0)))
			for p in range(partes):
				var b0 := lerpf(a0, a1, float(p) / partes)
				var b1 := lerpf(a0, a1, float(p + 1) / partes)
				var poly := PackedVector2Array()
				if r0 <= 0.0:
					poly.append(tiro)
				else:
					poly.append(tiro + Vector2.RIGHT.rotated(b0) * r0)
					if partes > 1 or r1 > 60.0:
						poly.append(tiro + Vector2.RIGHT.rotated((b0 + b1) * 0.5) * r0 * randf_range(0.97, 1.03))
					poly.append(tiro + Vector2.RIGHT.rotated(b1) * r0)
				poly.append(tiro + Vector2.RIGHT.rotated(b1) * r1 * randf_range(0.92, 1.0))
				poly.append(tiro + Vector2.RIGHT.rotated((b0 + b1) * 0.5) * r1 * randf_range(0.9, 1.06))
				poly.append(tiro + Vector2.RIGHT.rotated(b0) * r1 * randf_range(0.92, 1.0))
				for k in range(poly.size()):
					poly[k] = Vector2(clampf(poly[k].x, 0.0, tam.x), clampf(poly[k].y, 0.0, tam.y))
				var centro := Vector2.ZERO
				for v in poly:
					centro += v
				centro /= poly.size()
				if not _tem_vidro(imagem, regiao, poly, centro):
					continue
				_adicionar_caco(poly, centro, regiao, tam_folha, xf, canto, escala_tela, tiro, estilo, linha_corte, topo_garrafa, limites)

	_indices.clear()
	for c in range(_c_inicio.size()):
		var ini: int = _c_inicio[c]
		for k in range(1, _c_qtd[c] - 1):
			_indices.append(ini)
			_indices.append(ini + k)
			_indices.append(ini + k + 1)
	_pontos.resize(_forma.size())
	_cores.resize(_forma.size())

	_criar_gotas(xf * (canto + tiro), cor_liquido, estilo, escala_tela)
	_atualizar(0.0)


func _adicionar_caco(poly: PackedVector2Array, centro: Vector2, regiao: Rect2, tam_folha: Vector2, xf: Transform2D, canto: Vector2, escala_tela: float, tiro: Vector2, estilo: int, linha_corte: Vector2, topo_garrafa: float, limites: Rect2) -> void:
	_c_inicio.append(_forma.size())
	_c_qtd.append(poly.size())
	for v in poly:
		_forma.append((v - centro) * escala_tela)
		_uvs.append((regiao.position + v) / tam_folha)

	var pos_tela: Vector2 = xf * (canto + centro)
	var dist := centro.distance_to(tiro)
	var dir := (centro - tiro).normalized() if dist > 0.5 else Vector2.UP.rotated(randf_range(-1.0, 1.0))
	var perto := clampf(1.0 - dist / 160.0, 0.0, 1.0)
	var vel := Vector2.ZERO
	var vz := 0.0
	var solta := 0.0
	var giro := randf_range(-9.0, 9.0) * (0.6 + perto)

	match estilo:
		ESTOURO:
			vel = dir * randf_range(240.0, 420.0) * (0.55 + perto)
			vel.y -= randf_range(120.0, 320.0)
			vz = randf_range(-1.8, 2.4)
		DESABA:
			# Desmorona: os pedaços escorregam para baixo e para os lados;
			# o gargalo (parte de cima) pula.
			var altura := inverse_lerp(limites.end.y, topo_garrafa, centro.y)
			vel = dir * randf_range(60.0, 170.0) * (0.5 + perto)
			vel.y += randf_range(-40.0, 60.0)
			if altura > 0.72:
				vel = Vector2(randf_range(-90.0, 90.0), randf_range(-400.0, -300.0))
				giro = randf_range(-7.0, 7.0)
			vz = randf_range(-1.2, 1.4)
			solta = (1.0 - altura) * 0.06
		PARTIDA:
			# Corta numa linha que passa pelo tiro: a parte de cima sai inteira
			# girando e se desfaz no ar; a de baixo estoura logo.
			var lado := (centro - tiro).dot(linha_corte.orthogonal())
			if lado < 0.0:
				vel = Vector2(linha_corte.x * randf_range(150.0, 190.0) * signf(randf() - 0.5), randf_range(-430.0, -380.0))
				giro = randf_range(2.5, 3.5) * signf(vel.x)
				vz = randf_range(0.3, 1.0)
				solta = randf_range(0.16, 0.26)
			else:
				vel = dir * randf_range(180.0, 360.0) * (0.5 + perto)
				vel.y -= randf_range(60.0, 200.0)
				vz = randf_range(-1.6, 1.8)

	_c_pos.append(pos_tela)
	_c_vel.append(vel)
	_c_ang.append(0.0)
	_c_giro.append(giro)
	_c_tomb.append(0.0)
	_c_tomb_vel.append(randf_range(-14.0, 14.0) * (0.4 + perto))
	_c_z.append(0.0)
	_c_vz.append(vz)
	_c_vida.append(randf_range(1.2, 1.8))
	_c_solta.append(solta)
	_c_pousado.append(-1.0)


func _criar_gotas(origem: Vector2, cor_liquido: Color, estilo: int, escala_tela: float) -> void:
	var tem_liquido := cor_liquido.a > 0.01
	var qtd_gotas := 0
	if tem_liquido:
		qtd_gotas = 22 if estilo == ESTOURO else 16
	for i in range(qtd_gotas):
		var vel: Vector2
		match estilo:
			DESABA:
				vel = Vector2(randf_range(-160.0, 160.0), randf_range(-120.0, 80.0))
			_:
				vel = Vector2.RIGHT.rotated(randf_range(-PI, 0.0)) * randf_range(140.0, 460.0)
				vel.y -= randf_range(40.0, 180.0)
		var c := cor_liquido
		c.a = randf_range(0.65, 0.9)
		_nova_gota(origem + Vector2(randf_range(-6, 6), randf_range(-6, 6)), vel, c, randf_range(2.2, 4.8) * escala_tela, randf_range(0.7, 1.2))
	# Pó de vidro brilhando
	for i in range(14):
		var vel := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(80.0, 380.0)
		_nova_gota(origem, vel, Color(1.0, 0.97, 0.88, 0.95), randf_range(1.0, 2.0) * escala_tela, randf_range(0.35, 0.7))


func _nova_gota(pos: Vector2, vel: Vector2, cor: Color, tam: float, vida: float) -> void:
	var ini := _g_pontos.size()
	_g_pos.append(pos)
	_g_vel.append(vel)
	_g_cor.append(cor)
	_g_tam.append(tam)
	_g_vida.append(vida)
	_g_z.append(randf_range(-0.8, 0.9))
	for k in range(6):
		_g_pontos.append(pos)
		_g_cores.append(cor)
	for k in range(1, 5):
		_g_indices.append(ini)
		_g_indices.append(ini + k)
		_g_indices.append(ini + k + 1)


func _process(delta: float) -> void:
	_tempo += delta
	if _tempo >= _duracao:
		queue_free()
		return
	_atualizar(minf(delta, 1.0 / 30.0))
	queue_redraw()


func _atualizar(dt: float) -> void:
	for c in range(_c_pos.size()):
		var solta: float = _c_solta[c]
		var no_ar := _tempo >= solta
		var pos: Vector2 = _c_pos[c]
		var vel: Vector2 = _c_vel[c]
		var z: float = _c_z[c]
		var pousado: float = _c_pousado[c]

		if no_ar and dt > 0.0:
			if pousado < 0.0:
				vel.y += GRAVIDADE * dt
				pos += vel * dt
				z += _c_vz[c] * dt
				if z < PRATELEIRA_FUNDO:
					z = PRATELEIRA_FUNDO
					_c_vz[c] = -_c_vz[c] * 0.3
				_c_ang[c] += _c_giro[c] * dt
				_c_tomb[c] += _c_tomb_vel[c] * dt
				# Prateleira: quem está sobre ela (entre a parede e a beirada) bate.
				# Quanto mais para o fundo, mais alto o tampo aparece na tela.
				var chao_aqui := _chao - (PRATELEIRA_BEIRA - z) / (PRATELEIRA_BEIRA - PRATELEIRA_FUNDO) * ALTURA_PRATELEIRA
				if z <= PRATELEIRA_BEIRA and vel.y > 0.0 and pos.y >= chao_aqui:
					pos.y = chao_aqui
					if vel.y > 220.0:
						vel.y = -vel.y * randf_range(0.22, 0.34)
						vel.x *= 0.6
						_c_giro[c] *= 0.5
						_c_tomb_vel[c] *= 0.5
						_c_vz[c] *= 0.4
					else:
						pousado = 0.0
						vel = Vector2(vel.x * 0.5, 0.0)
			else:
				# Deitado: escorrega um pouco e para.
				pousado += dt
				pos.x += vel.x * dt
				vel.x *= pow(0.02, dt)
				# Deita de face (largura cheia, altura achatada pela perspectiva).
				_c_tomb[c] = lerpf(_c_tomb[c], roundf(_c_tomb[c] / PI) * PI, minf(1.0, dt * 12.0))
		_c_pos[c] = pos
		_c_vel[c] = vel
		_c_z[c] = z
		_c_pousado[c] = pousado

		# Aparência: perto da tela fica maior; o giro "3D" achata o caco e
		# faz ele piscar quando pega a luz.
		var perspectiva := 1.0 + 0.32 * clampf(z, -1.0, 2.5)
		var tomb: float = _c_tomb[c]
		var achata := absf(cos(tomb))
		var largura := maxf(0.12, achata) * perspectiva
		var altura_vis := perspectiva
		if pousado >= 0.0:
			altura_vis *= lerpf(1.0, 0.45, clampf(pousado / 0.12, 0.0, 1.0))
		var brilho := 1.0 + 0.85 * pow(absf(cos(tomb + 0.7)), 18.0)
		var sombra := 1.0 - 0.25 * clampf(-z, 0.0, 1.0)
		var vida: float = _c_vida[c]
		var alfa := 1.0
		if pousado >= 0.0:
			alfa = clampf(1.0 - (pousado - 0.35) / 0.5, 0.0, 1.0)
		alfa = minf(alfa, clampf((vida - _tempo) / 0.35, 0.0, 1.0))
		var cor := Color(brilho * sombra, brilho * sombra, brilho * sombra, alfa)
		var giro := Transform2D(_c_ang[c], pos)
		var ini: int = _c_inicio[c]
		for k in range(_c_qtd[c]):
			var v: Vector2 = _forma[ini + k]
			_pontos[ini + k] = giro * Vector2(v.x * largura, v.y * altura_vis)
			_cores[ini + k] = cor

	for g in range(_g_pos.size()):
		var pos: Vector2 = _g_pos[g]
		var vel: Vector2 = _g_vel[g]
		if dt > 0.0:
			vel.y += GRAVIDADE * 0.8 * dt
			vel *= pow(0.4, dt)
			pos += vel * dt
		_g_pos[g] = pos
		_g_vel[g] = vel
		var cor: Color = _g_cor[g]
		cor.a *= clampf((_g_vida[g] - _tempo) / 0.25, 0.0, 1.0)
		var tam: float = _g_tam[g] * (1.0 + 0.3 * _g_z[g])
		# Gota se estica na direção em que cai.
		var estica := clampf(vel.length() / 600.0, 0.0, 1.0)
		var dir := vel.normalized() if vel.length() > 1.0 else Vector2.DOWN
		var ini := g * 6
		for k in range(6):
			var h: Vector2 = _HEX[k] * tam
			var ao_longo := h.dot(dir)
			_g_pontos[ini + k] = pos + h + dir * ao_longo * estica * 1.4
			_g_cores[ini + k] = cor


func _draw() -> void:
	var ci := get_canvas_item()
	if not _indices.is_empty() and _textura != null:
		RenderingServer.canvas_item_add_triangle_array(ci, _indices, _pontos, _cores, _uvs, PackedInt32Array(), PackedFloat32Array(), _textura.get_rid())
	if not _g_indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci, _g_indices, _g_pontos, _g_cores)


static func _caixa_opaca(imagem: Image, regiao: Rect2) -> Rect2:
	var cheia := Rect2(Vector2.ZERO, regiao.size)
	if imagem == null:
		return cheia
	var x0 := int(regiao.position.x)
	var y0 := int(regiao.position.y)
	var w := int(regiao.size.x)
	var h := int(regiao.size.y)
	if x0 < 0 or y0 < 0 or x0 + w > imagem.get_width() or y0 + h > imagem.get_height():
		return cheia
	var minx := w
	var miny := h
	var maxx := -1
	var maxy := -1
	for y in range(0, h, 3):
		for x in range(0, w, 3):
			if imagem.get_pixel(x0 + x, y0 + y).a > 0.5:
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	if maxx < 0:
		return cheia
	return Rect2(minx, miny, maxx - minx + 3, maxy - miny + 3).intersection(cheia)


static func _tem_vidro(imagem: Image, regiao: Rect2, poly: PackedVector2Array, centro: Vector2) -> bool:
	if imagem == null:
		return true
	var amostras := [centro]
	for v in poly:
		amostras.append(centro.lerp(v, 0.6))
	for a in amostras:
		var x := int(regiao.position.x + a.x)
		var y := int(regiao.position.y + a.y)
		if x >= 0 and y >= 0 and x < imagem.get_width() and y < imagem.get_height():
			if imagem.get_pixel(x, y).a > 0.3:
				return true
	return false
