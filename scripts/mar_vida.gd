extends Node2D

# Vida do fundo do mar. Fica como filho do Sprite2D do fundo, com a origem no
# canto da textura: todas as posições aqui são pixels de atlantis_jogo.png
# (1024x1536). Contornos e caixas vêm de tools/gerar_mar.py.
#
#   cachoeiras   escorrendo (mesmo material e textura: um desenho só)
#   cardumes     três cardumes nadando juntos (MultiMesh; o nado é no shader)
#   baleias      nadando devagar; cada volta nova toca o canto delas ao longe
#   navio        aos 9 s de partida afunda de cima (a água segura, ele desce
#                de proa balançando), soltando um rastro de bolhas do casco e
#                das vergas; bate no fundo: nuvem de lodo que sobe e assenta,
#                lodo empurrado rente ao chão, tábuas e farpas soltando, e o
#                cenário volta a ser exatamente a foto
#   pedras       as escritas acendem de cima para baixo; tiro na pedra solta
#                lascas e deixa o buraco com rachaduras no lugar

signal navio_pousou

const TEXTURA_MASCARA := "res://sprites/mar_cascatas_mascara.png"
const SHADER_CASCATA := "res://shaders/mar_cascata.gdshader"
const SHADER_BALEIA := "res://shaders/mar_baleia.gdshader"
const SHADER_CARDUME := preload("res://shaders/mar_cardume.gdshader")
const SHADER_PEDRA := preload("res://shaders/mar_pedra.gdshader")
const SHADER_NAVIO := preload("res://shaders/mar_navio.gdshader")
const PEIXE := preload("res://sprites/mar_peixe.png")
const NAVIO := preload("res://sprites/mar_navio.png")
const NAVIO_POUSO := preload("res://sprites/mar_navio_pouso.png")
const BOLHA := preload("res://sprites/mar_bolha.png")
const LODO := preload("res://sprites/mar_lodo.png")
const FARPA := preload("res://sprites/mar_farpa.png")
const MASCARA_PEDRA_ESQ := preload("res://sprites/mar_pedra_esq_mascara.png")
const MASCARA_PEDRA_DIR := preload("res://sprites/mar_pedra_dir_mascara.png")
const SOM_BALEIA := preload("res://songs/baleia.wav")
const SOM_NAVIO_DESCE := preload("res://songs/navio_desce.wav")
const SOM_NAVIO_IMPACTO := preload("res://songs/navio_impacto.wav")
const SOM_PEDRA := preload("res://songs/pedra_lasca.wav")

# Onde há água caindo (x0, y0, x1, y1), em pixels da textura.
const CASCATAS := [
	Rect2(158, 298, 46, 220),
	Rect2(552, 492, 56, 126),
	Rect2(634, 378, 32, 90),
	Rect2(768, 343, 40, 95),
	Rect2(888, 333, 40, 95),
	Rect2(553, 403, 27, 75),
	Rect2(952, 672, 46, 96),
	Rect2(655, 292, 27, 56),
]

# Água aberta onde as baleias nadam: abaixo do placar (que cobre o topo da
# foto, até y ~265) e acima dos mastros do navio; entre a alga da esquerda
# e a cidade da direita (surgem da névoa da cidade).
const NADO_X_MIN := 255.0
const NADO_X_MAX := 690.0

const COR_NEVOA := Color(0.55, 0.78, 0.95)

# Cardumes: início, fim, segundos para atravessar, peixes, espalhamento,
# fase, cor e distância (0 perto .. 1 longe).
const CARDUMES := [
	{"de": Vector2(790, 262), "para": Vector2(230, 300), "periodo": 34.0, "n": 26, "espalha": Vector2(64, 22), "fase": 0.15, "cor": Color(0.10, 0.22, 0.34, 0.78), "longe": 0.3},
	{"de": Vector2(180, 440), "para": Vector2(620, 330), "periodo": 27.0, "n": 20, "espalha": Vector2(56, 16), "fase": 0.55, "cor": Color(0.09, 0.20, 0.31, 0.75), "longe": 0.4},
	{"de": Vector2(240, 238), "para": Vector2(720, 252), "periodo": 22.0, "n": 14, "espalha": Vector2(40, 12), "fase": 0.80, "cor": Color(0.16, 0.32, 0.46, 0.6), "longe": 0.75},
]

# Navio (tools/gerar_mar.py): canto da caixa e o ponto do casco que vira pivô.
const NAVIO_CANTO := Vector2(176, 429)
const NAVIO_PIVO := Vector2(370, 905)
const NAVIO_QUEDA := 4.2
const NAVIO_ALTURA := 1000.0
# Pontos no alto do casco, mastros e vergas (px do recorte): de onde sai o
# rastro de bolhas enquanto ele afunda (tools/gerar_mar.py).
const NAVIO_RASTRO := [Vector2(20, 110), Vector2(39, 132), Vector2(44, 106), Vector2(46, 106), Vector2(53, 98), Vector2(55, 275), Vector2(60, 95), Vector2(60, 146), Vector2(90, 85), Vector2(99, 402), Vector2(119, 176), Vector2(129, 108), Vector2(150, 277), Vector2(154, 396), Vector2(158, 312), Vector2(164, 55), Vector2(200, 396), Vector2(202, 151), Vector2(202, 315), Vector2(209, 28), Vector2(209, 393), Vector2(217, 138), Vector2(226, 101), Vector2(227, 294), Vector2(232, 338), Vector2(233, 27), Vector2(240, 118), Vector2(241, 88), Vector2(250, 63), Vector2(251, 278), Vector2(256, 62), Vector2(256, 90), Vector2(256, 175), Vector2(257, 157), Vector2(267, 65), Vector2(269, 66), Vector2(278, 341), Vector2(284, 338), Vector2(291, 315), Vector2(292, 327), Vector2(294, 311), Vector2(294, 312), Vector2(295, 319), Vector2(300, 42), Vector2(300, 316), Vector2(307, 27), Vector2(313, 66), Vector2(357, 349)]
# Onde o casco bate no chão (px do recorte): de lá saem as lascas de madeira.
const NAVIO_CASCO := [Vector2(70, 430), Vector2(110, 452), Vector2(150, 468), Vector2(190, 478), Vector2(230, 482), Vector2(270, 476), Vector2(305, 462), Vector2(330, 440)]

# Pedras: canto e tamanho da caixa de cada máscara.
const PEDRAS := [
	{"canto": Vector2(0, 466), "tam": Vector2(238, 471), "mascara": "esq", "fase": 0.0},
	{"canto": Vector2(523, 523), "tam": Vector2(428, 710), "mascara": "dir", "fase": 0.45},
]
const MAX_DANOS := 12

var _baleias: Array = []
var _pedras: Array = []          # {no, mat, img, canto, tam, danos}
var _lascas: Array = []          # {no, vel, giro, t, vida, cresce}
var _poeira_pedra: CPUParticles2D = null
var _bolhas_pedra: CPUParticles2D = null

var _navio: Sprite2D = null
var _navio_pouso: Sprite2D = null
var _navio_estado := ""          # "" fora, "caindo", "pousado", "fim"
var _navio_t := 0.0
var _rastro: CPUParticles2D = null      # bolhas saindo do casco enquanto afunda
var _lodo: CPUParticles2D = null        # nuvem de lodo que sobe e assenta
var _lodo_jatos: CPUParticles2D = null  # lodo empurrado para os lados pela batida
var _farpas: CPUParticles2D = null      # farpas de madeira girando
var _bolhas_pouso: CPUParticles2D = null


func _ready() -> void:
	_criar_cascatas()
	_criar_cardumes()
	_criar_baleias()
	_criar_navio()
	_criar_pedras()
	_criar_efeitos()


func _criar_cascatas() -> void:
	var fundo := get_parent() as Sprite2D
	if fundo == null or fundo.texture == null:
		return
	if not ResourceLoader.exists(SHADER_CASCATA) or not ResourceLoader.exists(TEXTURA_MASCARA):
		return

	var material_agua := ShaderMaterial.new()
	material_agua.shader = load(SHADER_CASCATA)
	material_agua.set_shader_parameter("mascara", load(TEXTURA_MASCARA))

	for r in CASCATAS:
		var queda := Sprite2D.new()
		queda.texture = fundo.texture
		queda.centered = false
		queda.region_enabled = true
		queda.region_rect = r
		queda.position = r.position
		queda.material = material_agua
		add_child(queda)


# ───────────────────────────────────────────── cardumes
func _criar_cardumes() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(PEIXE.get_width(), -PEIXE.get_height())   # y para baixo no 2D
	for c in CARDUMES:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = quad
		mm.instance_count = c["n"]
		var esp: Vector2 = c["espalha"]
		# o desenho é cortado pela caixa do MultiMesh: os peixes ficam em volta
		# do meio do caminho e a caixa cobre o caminho inteiro
		var de: Vector2 = c["de"]
		var para: Vector2 = c["para"]
		var meio := (de + para) * 0.5
		var caixa := Rect2(de, Vector2.ZERO).expand(para).grow(110.0)
		mm.custom_aabb = AABB(Vector3(caixa.position.x, caixa.position.y, -1.0), Vector3(caixa.size.x, caixa.size.y, 2.0))
		for i in c["n"]:
			# lugar no cardume: elipse mais cheia no meio
			var a := randf() * TAU
			var r := sqrt(randf())
			var lugar := Vector2(cos(a) * esp.x, sin(a) * esp.y) * r
			mm.set_instance_transform_2d(i, Transform2D(0.0, meio + lugar))
			mm.set_instance_color(i, Color(randf(), randf(), clampf(c["longe"] + randf_range(-0.15, 0.15), 0.0, 1.0), 1.0))
		var no := MultiMeshInstance2D.new()
		no.name = "Cardume"
		no.multimesh = mm
		no.texture = PEIXE
		var mat := ShaderMaterial.new()
		mat.shader = SHADER_CARDUME
		mat.set_shader_parameter("meio", meio)
		mat.set_shader_parameter("inicio", c["de"])
		mat.set_shader_parameter("fim", c["para"])
		mat.set_shader_parameter("periodo", c["periodo"])
		mat.set_shader_parameter("fase", c["fase"])
		mat.set_shader_parameter("cor", c["cor"])
		no.material = mat
		add_child(no)


# ───────────────────────────────────────────── baleias
func _criar_baleias() -> void:
	if not ResourceLoader.exists(SHADER_BALEIA):
		return
	var shader: Shader = load(SHADER_BALEIA)

	# A de trás primeiro (fica atrás na ordem de desenho): menor, mais alta,
	# mais lenta e mais apagada pela água; a da frente maior e mais nítida.
	var dados := [
		{"img": "res://sprites/mar_baleia_2.png", "inicio": Vector2(600.0, 318.0), "vel": 9.0, "y_min": 302.0, "y_max": 336.0, "escala": 0.9, "fase": 1.7, "batida": 1.35, "voz": 0.82},
		{"img": "res://sprites/mar_baleia_1.png", "inicio": Vector2(455.0, 378.0), "vel": 13.0, "y_min": 352.0, "y_max": 404.0, "escala": 1.08, "fase": 0.0, "batida": 1.1, "voz": 1.0},
	]

	for d in dados:
		if not ResourceLoader.exists(d["img"]):
			continue
		var s := Sprite2D.new()
		s.texture = load(d["img"])
		s.centered = true
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("fase", d["fase"])
		mat.set_shader_parameter("batida", d["batida"])
		s.material = mat
		add_child(s)

		var b := {
			"no": s,
			"vel_base": d["vel"],
			"y_min": d["y_min"],
			"y_max": d["y_max"],
			"batida": d["batida"],
			"fase": d["fase"],
			"voz": d["voz"],
		}
		b["escala_base"] = d["escala"]
		# Primeira volta: já começa visível na água e segue para a esquerda;
		# a da frente canta logo no começo.
		_comecar_volta(b, d["inicio"], -1.0, d["escala"], true)
		b["cantou"] = d["voz"] < 1.0
		_baleias.append(b)
		_posicionar(b)


func _comecar_volta(b: Dictionary, inicio: Vector2, sentido: float, escala: float, visivel_ja: bool) -> void:
	b["sentido"] = sentido
	b["x"] = inicio.x
	b["y0"] = inicio.y
	b["escala0"] = escala
	b["t"] = 0.0
	b["espera"] = 0.0
	b["alfa"] = 1.0 if visivel_ja else 0.0
	b["ja_visivel"] = visivel_ja
	b["cantou"] = visivel_ja
	b["fim_x"] = NADO_X_MIN if sentido < 0.0 else NADO_X_MAX
	b["onda_periodo"] = randf_range(16.0, 24.0)
	b["onda_altura"] = randf_range(5.0, 10.0)
	b["onda_fase"] = 0.0 if visivel_ja else randf() * TAU
	var no: Sprite2D = b["no"]
	no.flip_h = sentido > 0.0
	no.visible = true


func _nova_volta(b: Dictionary) -> void:
	var sentido := -1.0 if randf() < 0.65 else 1.0
	var y := randf_range(b["y_min"], b["y_max"])
	# Mais alta na água = mais longe: um pouco menor.
	var longe := inverse_lerp(b["y_max"], b["y_min"], y)
	var escala: float = b["escala_base"] * lerpf(1.05, 0.92, longe) * randf_range(0.96, 1.04)
	var x := NADO_X_MAX - randf_range(0.0, 40.0) if sentido < 0.0 else NADO_X_MIN + randf_range(0.0, 40.0)
	_comecar_volta(b, Vector2(x, y), sentido, escala, false)


## Canto ao longe quando a baleia aparece na água (a de trás mais grave).
func _cantar(b: Dictionary) -> void:
	b["cantou"] = true
	Maquina.efeito(SOM_BALEIA, -7.0, b["voz"] * randf_range(0.92, 1.08))


func _posicionar(b: Dictionary) -> void:
	var no: Sprite2D = b["no"]
	var t: float = b["t"]
	var w: float = TAU / b["onda_periodo"]
	var ondula: float = sin(t * w + b["onda_fase"])
	var y: float = b["y0"] + ondula * b["onda_altura"]
	# Nariz aponta para onde está indo (subindo/descendo).
	var subida: float = cos(t * w + b["onda_fase"]) * b["onda_altura"] * w
	var direcao := atan2(subida, b["sentido"] * b["vel_base"])
	if b["sentido"] < 0.0:
		direcao -= PI
	no.rotation = wrapf(direcao, -PI, PI) * 0.8

	# Ao sumir ela vai para longe: diminui um pouco e pega a cor da água.
	var alfa: float = b["alfa"]
	var distancia: float = 1.0 - alfa
	var escala: float = b["escala0"] * (1.0 - 0.10 * distancia)
	no.scale = Vector2(escala, escala)
	no.position = Vector2(b["x"], y + 0.6 * sin(t * b["batida"] * TAU + b["fase"]))
	var nevoa: float = clampf(distancia * 0.6 + (1.1 - b["escala0"]) * 0.9, 0.0, 0.7)
	var cor := Color.WHITE.lerp(COR_NEVOA, nevoa)
	cor.a = alfa
	no.modulate = cor


# ───────────────────────────────────────────── navio
func _criar_navio() -> void:
	_navio = Sprite2D.new()
	_navio.name = "Navio"
	_navio.texture = NAVIO
	_navio.centered = false
	_navio.offset = -(NAVIO_PIVO - NAVIO_CANTO)
	_navio.position = NAVIO_PIVO
	_navio.visible = false
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_NAVIO
	_navio.material = mat
	add_child(_navio)

	# rastro: bolhas que escapam do casco e das vergas e ficam para trás
	# (subindo e crescendo) enquanto o navio desce
	_rastro = CPUParticles2D.new()
	_rastro.name = "Rastro"
	_rastro.amount = 90
	_rastro.lifetime = 2.8
	_rastro.emitting = false
	_rastro.local_coords = false
	_rastro.texture = BOLHA
	_rastro.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	var pontos := PackedVector2Array()
	for p in NAVIO_RASTRO:
		pontos.append(p - (NAVIO_PIVO - NAVIO_CANTO))
	_rastro.emission_points = pontos
	_rastro.direction = Vector2(0, -1)
	_rastro.spread = 25.0
	_rastro.gravity = Vector2(0, -120)
	_rastro.initial_velocity_min = 10.0
	_rastro.initial_velocity_max = 45.0
	_rastro.tangential_accel_min = -30.0
	_rastro.tangential_accel_max = 30.0
	_rastro.damping_min = 8.0
	_rastro.damping_max = 20.0
	_rastro.scale_amount_min = 0.10
	_rastro.scale_amount_max = 0.30
	_rastro.scale_amount_curve = _curva(0.6, 1.35)
	_rastro.color_ramp = _rampa(Color(0.85, 0.95, 1.0), 0.85)
	_navio.add_child(_rastro)

	# a foto original na caixa do navio: entra quando ele pousa
	_navio_pouso = Sprite2D.new()
	_navio_pouso.name = "NavioPousado"
	_navio_pouso.texture = NAVIO_POUSO
	_navio_pouso.centered = false
	_navio_pouso.position = NAVIO_CANTO
	_navio_pouso.visible = false
	add_child(_navio_pouso)


## Começa a queda (a cena chama aos 9 s de partida). Só uma vez.
func cair_navio() -> void:
	if _navio_estado != "":
		return
	_navio_estado = "caindo"
	_navio_t = 0.0
	_navio.visible = true
	_navio.modulate = Color(0.78, 0.9, 1.0, 0.0)
	_navio.position = NAVIO_PIVO - Vector2(0, NAVIO_ALTURA)
	(_navio.material as ShaderMaterial).set_shader_parameter("agita", 1.0)
	_rastro.emitting = true
	Maquina.efeito(SOM_NAVIO_DESCE, -5.0)


func _animar_navio(delta: float) -> void:
	_navio_t += delta
	if _navio_estado == "caindo":
		var k := clampf(_navio_t / NAVIO_QUEDA, 0.0, 1.0)
		# debaixo d'água: acelera no começo e logo a água segura (velocidade
		# limite); afunda de proa, balançando e derivando de leve
		var tau := 0.9
		var f := _navio_t - tau * (1.0 - exp(-_navio_t / tau))
		var f_fim := NAVIO_QUEDA - tau * (1.0 - exp(-NAVIO_QUEDA / tau))
		var desce := clampf(f / f_fim, 0.0, 1.0)
		var resta := 1.0 - k
		_navio.position = NAVIO_PIVO - Vector2(24.0 * resta * sin(_navio_t * 0.9 + 0.4), NAVIO_ALTURA * (1.0 - desce))
		_navio.rotation = deg_to_rad(5.5) * resta + deg_to_rad(2.2) * sin(_navio_t * 1.45) * resta
		# vem da névoa lá de cima: azulado no começo, cor certa ao chegar
		_navio.modulate = Color(lerpf(0.72, 1.0, k), lerpf(0.86, 1.0, k), 1.0, clampf(_navio_t / 0.6, 0.0, 1.0))
		if k >= 1.0:
			_pousar()
	elif _navio_estado == "pousado":
		# assenta: afunda um pouco na areia, volta e para; o balanço morre
		var t := _navio_t
		_navio.position = NAVIO_PIVO + Vector2(0, 5.0 * exp(-t * 4.0) * sin(t * 9.0 + 0.6))
		_navio.rotation = deg_to_rad(1.6) * exp(-t * 3.0) * cos(t * 7.0)
		(_navio.material as ShaderMaterial).set_shader_parameter("agita", clampf(1.0 - t * 1.2, 0.0, 1.0))
		if t > 0.35 and not _navio_pouso.visible:
			_navio_pouso.visible = true
			_navio_pouso.modulate.a = 0.0
		if _navio_pouso.visible:
			_navio_pouso.modulate.a = clampf((t - 0.35) / 0.9, 0.0, 1.0)
			if _navio_pouso.modulate.a >= 1.0:
				_navio.visible = false
				_navio_estado = "fim"


func _pousar() -> void:
	_navio_estado = "pousado"
	_navio_t = 0.0
	_rastro.emitting = false
	for p: CPUParticles2D in [_lodo, _lodo_jatos, _farpas, _bolhas_pouso]:
		p.restart()
		p.emitting = true
	# tábuas que se soltam do casco na batida (recortadas do próprio navio)
	for i in 9:
		var ponto: Vector2 = NAVIO_CASCO[randi() % NAVIO_CASCO.size()] + Vector2(randf_range(-14, 14), randf_range(-30, -4))
		_soltar_lasca(NAVIO_CANTO + ponto, randf_range(12.0, 20.0), true, NAVIO, ponto, true)
	Maquina.efeito(SOM_NAVIO_IMPACTO, -2.0)
	navio_pousou.emit()


# ───────────────────────────────────────────── pedras com escritas
func _criar_pedras() -> void:
	var fundo := get_parent() as Sprite2D
	if fundo == null or fundo.texture == null:
		return
	var tex_tam := fundo.texture.get_size()
	for d in PEDRAS:
		var mascara: Texture2D = MASCARA_PEDRA_ESQ if d["mascara"] == "esq" else MASCARA_PEDRA_DIR
		var canto: Vector2 = d["canto"]
		var tam: Vector2 = d["tam"]
		var s := Sprite2D.new()
		s.name = "Pedra_" + d["mascara"]
		s.texture = fundo.texture
		s.centered = false
		s.region_enabled = true
		s.region_rect = Rect2(canto, tam)
		s.position = canto
		var mat := ShaderMaterial.new()
		mat.shader = SHADER_PEDRA
		mat.set_shader_parameter("mascara", mascara)
		mat.set_shader_parameter("regiao", Vector4(canto.x / tex_tam.x, canto.y / tex_tam.y, tam.x / tex_tam.x, tam.y / tex_tam.y))
		mat.set_shader_parameter("aspecto", tam.x / tam.y)
		mat.set_shader_parameter("fase", d["fase"])
		mat.set_shader_parameter("n_danos", 0)
		s.material = mat
		add_child(s)
		_pedras.append({"no": s, "mat": mat, "img": mascara.get_image(), "canto": canto, "tam": tam, "danos": []})


## Tiro em `pos` (px da textura). Se for numa pedra: buraco, lascas, poeira e
## som; devolve true.
func acertar_pedra(pos: Vector2) -> bool:
	for p in _pedras:
		var local: Vector2 = pos - p["canto"]
		var tam: Vector2 = p["tam"]
		if local.x < 0.0 or local.y < 0.0 or local.x >= tam.x or local.y >= tam.y:
			continue
		var img: Image = p["img"]
		if img == null or img.get_pixel(int(local.x), int(local.y)).b < 0.5:
			continue
		_quebrar(p, pos, local)
		return true
	return false


func _quebrar(p: Dictionary, pos: Vector2, local: Vector2) -> void:
	var tam: Vector2 = p["tam"]
	var raio := randf_range(13.0, 18.0)
	var danos: Array = p["danos"]
	danos.append(Vector4(local.x / tam.x, local.y / tam.y, raio / tam.x, randf()))
	while danos.size() > MAX_DANOS:
		danos.pop_front()
	var arr := PackedVector4Array()
	for d in danos:
		arr.append(d)
	for i in range(danos.size(), MAX_DANOS):
		arr.append(Vector4.ZERO)
	var mat: ShaderMaterial = p["mat"]
	mat.set_shader_parameter("danos", arr)
	mat.set_shader_parameter("n_danos", danos.size())

	# a pedra que sai do buraco (recortada do próprio lugar) + lasquinhas
	_soltar_lasca(pos, raio * 1.05, true)
	for i in 4:
		_soltar_lasca(pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)), raio * randf_range(0.28, 0.45), false)
	_poeira_pedra.position = pos
	_poeira_pedra.restart()
	_poeira_pedra.emitting = true
	_bolhas_pedra.position = pos
	_bolhas_pedra.restart()
	_bolhas_pedra.emitting = true
	Maquina.efeito(SOM_PEDRA, -1.0, randf_range(0.9, 1.1))


## Lasca recortada de uma textura: por padrão o próprio fundo no ponto `pos`;
## para o navio, a textura dele e o ponto `uv_em` dentro do recorte. `tabua`
## faz uma tira comprida (madeira) em vez de um caco redondo (pedra).
func _soltar_lasca(pos: Vector2, raio: float, grande: bool, textura: Texture2D = null, uv_em: Vector2 = Vector2.INF, tabua: bool = false) -> void:
	var fundo := get_parent() as Sprite2D
	if textura == null:
		textura = fundo.texture
	if uv_em == Vector2.INF:
		uv_em = pos
	var lasca: Dictionary = {}
	for l in _lascas:
		if not l["no"].visible:
			lasca = l
			break
	if lasca.is_empty():
		if _lascas.size() >= 24:
			lasca = _lascas[0]
		else:
			var novo := Polygon2D.new()
			novo.texture = fundo.texture
			add_child(novo)
			lasca = {"no": novo}
			_lascas.append(lasca)
	var poli := PackedVector2Array()
	if tabua:
		# tira lascada: comprida, fina, pontas irregulares
		var giro := randf() * TAU
		var comp := raio * randf_range(1.4, 2.2)
		var larg := raio * randf_range(0.28, 0.42)
		for v in [Vector2(-comp, -larg * 0.6), Vector2(-comp * 0.3, -larg), Vector2(comp * randf_range(0.8, 1.0), -larg * 0.7),
				Vector2(comp, larg * 0.2), Vector2(comp * 0.4, larg), Vector2(-comp * randf_range(0.8, 1.0), larg * 0.8)]:
			poli.append(v.rotated(giro))
	else:
		var n := 7 if grande else 5
		for i in n:
			var a := TAU * (i + randf_range(-0.3, 0.3)) / n
			poli.append(Vector2(cos(a), sin(a)) * raio * randf_range(0.65, 1.1))
	var uv := PackedVector2Array()
	for v in poli:
		uv.append(uv_em + v)
	var no: Polygon2D = lasca["no"]
	no.texture = textura
	no.polygon = poli
	no.uv = uv
	no.position = pos
	no.rotation = 0.0
	no.scale = Vector2.ONE
	no.color = Color(1.12, 1.12, 1.12) if grande else Color(0.95, 0.95, 0.95)
	no.modulate.a = 1.0
	no.visible = true
	move_child(no, -1)
	var ang := randf_range(-PI, 0.0)
	lasca["vel"] = Vector2(cos(ang), sin(ang)) * (randf_range(30, 70) if grande else randf_range(60, 140))
	lasca["giro"] = randf_range(-5.0, 5.0)
	lasca["t"] = 0.0
	lasca["vida"] = randf_range(1.6, 2.2) if grande else randf_range(0.9, 1.4)
	lasca["cresce"] = 0.45 if grande else 0.15
	if tabua:
		lasca["vel"] = Vector2(randf_range(-1.0, 1.0), -randf_range(0.6, 1.0)).normalized() * randf_range(110.0, 230.0)
		lasca["giro"] = randf_range(-7.0, 7.0)
		lasca["vida"] = randf_range(2.6, 3.6)
		lasca["cresce"] = 0.2
		no.color = Color(0.9, 0.9, 0.92)


func _animar_lascas(delta: float) -> void:
	for l in _lascas:
		var no: Polygon2D = l["no"]
		if not no.visible:
			continue
		l["t"] += delta
		var t: float = l["t"]
		# debaixo d'água: freia rápido e afunda devagar
		var vel: Vector2 = l["vel"]
		vel = vel * pow(0.12, delta) + Vector2(0, 95.0) * delta
		l["vel"] = vel
		no.position += vel * delta
		no.rotation += l["giro"] * delta
		var vem := clampf(t / 0.25, 0.0, 1.0)   # sai da pedra vindo para a frente
		no.scale = Vector2.ONE * (1.0 + l["cresce"] * vem)
		var resta: float = l["vida"] - t
		no.modulate.a = clampf(resta / 0.5, 0.0, 1.0)
		if resta <= 0.0:
			no.visible = false


# ───────────────────────────────────────────── partículas
func _criar_efeitos() -> void:
	var bola := FundoVivo.brilho_redondo()

	_poeira_pedra = _particulas("PoeiraPedra", 16, 1.6, bola, false)
	_poeira_pedra.explosiveness = 0.9
	_poeira_pedra.initial_velocity_min = 15.0
	_poeira_pedra.initial_velocity_max = 55.0
	_poeira_pedra.damping_min = 25.0
	_poeira_pedra.damping_max = 40.0
	_poeira_pedra.gravity = Vector2(0, 6)
	_poeira_pedra.spread = 180.0
	_poeira_pedra.scale_amount_min = 0.5
	_poeira_pedra.scale_amount_max = 1.2
	_poeira_pedra.scale_amount_curve = _curva(0.4, 1.0)
	_poeira_pedra.color_ramp = _rampa(Color(0.62, 0.70, 0.72), 0.55)

	_bolhas_pedra = _particulas("BolhasPedra", 10, 1.6, BOLHA, false)
	_bolhas_pedra.explosiveness = 0.7
	_bolhas_pedra.gravity = Vector2(0, -70)
	_bolhas_pedra.initial_velocity_min = 10.0
	_bolhas_pedra.initial_velocity_max = 40.0
	_bolhas_pedra.spread = 180.0
	_bolhas_pedra.scale_amount_min = 0.10
	_bolhas_pedra.scale_amount_max = 0.24
	_bolhas_pedra.color_ramp = _rampa(Color(0.85, 0.95, 1.0), 0.8)

	# lodo: nuvens grandes que sobem devagar, giram, crescem e assentam
	_lodo = _particulas("Lodo", 30, 4.6, LODO, false)
	_lodo.position = Vector2(355, 912)
	_lodo.explosiveness = 0.85
	_lodo.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_lodo.emission_rect_extents = Vector2(165, 12)
	_lodo.direction = Vector2(0, -1)
	_lodo.spread = 70.0
	_lodo.initial_velocity_min = 40.0
	_lodo.initial_velocity_max = 130.0
	_lodo.damping_min = 25.0
	_lodo.damping_max = 45.0
	_lodo.gravity = Vector2(0, 5)
	_lodo.angular_velocity_min = -25.0
	_lodo.angular_velocity_max = 25.0
	_lodo.angle_min = 0.0
	_lodo.angle_max = 360.0
	_lodo.scale_amount_min = 1.3
	_lodo.scale_amount_max = 2.6
	_lodo.scale_amount_curve = _curva(0.45, 1.6)
	_lodo.color_ramp = _rampa(Color(0.74, 0.82, 0.84), 0.88)

	# lodo empurrado para os lados, rente ao chão
	_lodo_jatos = _particulas("LodoJatos", 18, 2.8, LODO, false)
	_lodo_jatos.position = Vector2(355, 918)
	_lodo_jatos.explosiveness = 1.0
	_lodo_jatos.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_lodo_jatos.emission_rect_extents = Vector2(150, 6)
	_lodo_jatos.direction = Vector2(0, -1)
	_lodo_jatos.spread = 88.0
	_lodo_jatos.initial_velocity_min = 170.0
	_lodo_jatos.initial_velocity_max = 320.0
	_lodo_jatos.damping_min = 120.0
	_lodo_jatos.damping_max = 170.0
	_lodo_jatos.gravity = Vector2(0, 30)
	_lodo_jatos.angle_max = 360.0
	_lodo_jatos.scale_amount_min = 0.6
	_lodo_jatos.scale_amount_max = 1.3
	_lodo_jatos.scale_amount_curve = _curva(0.5, 1.4)
	_lodo_jatos.color_ramp = _rampa(Color(0.70, 0.78, 0.80), 0.7)

	# farpas de madeira girando e afundando devagar
	_farpas = _particulas("Farpas", 22, 3.2, FARPA, false)
	_farpas.position = Vector2(355, 895)
	_farpas.explosiveness = 0.95
	_farpas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_farpas.emission_rect_extents = Vector2(160, 14)
	_farpas.direction = Vector2(0, -1)
	_farpas.spread = 75.0
	_farpas.initial_velocity_min = 140.0
	_farpas.initial_velocity_max = 300.0
	_farpas.damping_min = 80.0
	_farpas.damping_max = 120.0
	_farpas.gravity = Vector2(0, 70)
	_farpas.angle_max = 360.0
	_farpas.angular_velocity_min = -360.0
	_farpas.angular_velocity_max = 360.0
	_farpas.scale_amount_min = 0.3
	_farpas.scale_amount_max = 0.85
	var some := Gradient.new()
	some.offsets = PackedFloat32Array([0.0, 0.08, 0.7, 1.0])
	# madeira molhada vista através da água: tingida pelo azul e sumindo na névoa
	some.colors = PackedColorArray([Color(0.62, 0.76, 0.88, 0), Color(0.62, 0.76, 0.88, 0.85),
		Color(0.58, 0.72, 0.86, 0.6), Color(0.55, 0.70, 0.86, 0)])
	_farpas.color_ramp = some

	# bolhas que escapam do casco depois da batida
	_bolhas_pouso = _particulas("BolhasPouso", 44, 3.0, BOLHA, false)
	_bolhas_pouso.position = Vector2(355, 860)
	_bolhas_pouso.explosiveness = 0.55
	_bolhas_pouso.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_bolhas_pouso.emission_rect_extents = Vector2(170, 50)
	_bolhas_pouso.direction = Vector2(0, -1)
	_bolhas_pouso.spread = 30.0
	_bolhas_pouso.gravity = Vector2(0, -130)
	_bolhas_pouso.initial_velocity_min = 10.0
	_bolhas_pouso.initial_velocity_max = 60.0
	_bolhas_pouso.tangential_accel_min = -30.0
	_bolhas_pouso.tangential_accel_max = 30.0
	_bolhas_pouso.scale_amount_min = 0.10
	_bolhas_pouso.scale_amount_max = 0.34
	_bolhas_pouso.scale_amount_curve = _curva(0.6, 1.35)
	_bolhas_pouso.color_ramp = _rampa(Color(0.85, 0.95, 1.0), 0.85)


func _particulas(nome: String, n: int, vida: float, tex: Texture2D, continuo: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = nome
	p.amount = n
	p.lifetime = vida
	p.one_shot = not continuo
	p.emitting = false
	p.texture = tex
	add_child(p)
	return p


func _rampa(cor: Color, pico: float) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	g.colors = PackedColorArray([Color(cor, 0.0), Color(cor, pico), Color(cor, pico * 0.6), Color(cor, 0.0)])
	return g


func _curva(ini: float, fim: float) -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, ini))
	c.add_point(Vector2(1, fim))
	return c


# ───────────────────────────────────────────── quadro a quadro
func _process(delta: float) -> void:
	for b in _baleias:
		var no: Sprite2D = b["no"]
		if b["espera"] > 0.0:
			b["espera"] -= delta
			if b["espera"] <= 0.0:
				_nova_volta(b)
			continue

		b["t"] += delta
		# Avança em pequenos impulsos, no ritmo da cauda.
		var impulso := 1.0 + 0.22 * sin(b["t"] * b["batida"] * TAU + b["fase"])
		b["x"] += b["sentido"] * b["vel_base"] * impulso * delta

		var falta: float = absf(b["fim_x"] - b["x"])
		var percorrido: float = b["t"] * b["vel_base"]
		# Surge da névoa devagar e some na distância ao chegar no fim.
		var entrada := 1.0 if b["ja_visivel"] else smoothstep(0.0, 70.0, percorrido)
		var saida := smoothstep(0.0, 90.0, falta)
		b["alfa"] = entrada * saida
		if not b["cantou"] and percorrido > 40.0:
			_cantar(b)

		var passou: bool = (b["x"] - b["fim_x"]) * b["sentido"] >= 0.0
		if passou:
			no.visible = false
			b["espera"] = randf_range(5.0, 12.0)
			continue

		_posicionar(b)

	if _navio_estado == "caindo" or _navio_estado == "pousado":
		_animar_navio(delta)
	_animar_lascas(delta)
