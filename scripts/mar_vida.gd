extends Node2D

# Vida do fundo do mar. Fica como filho do Sprite2D do fundo, com a origem no
# canto da textura: todas as posições aqui são pixels de atlantis_fundo.png
# (1024x1536). Contornos e caixas vêm de tools/gerar_mar.py.
#
#   cachoeiras   escorrendo (mesmo material e textura: um desenho só)
#   cardumes     três cardumes nadando juntos (MultiMesh; o nado é no shader)
#   baleias      nadando devagar; cada volta nova toca o canto delas ao longe
#   navio        aos 9 s de partida afunda de cima (a água segura, ele desce
#                de proa balançando), com a cor da foto e sem nada em volta
#                dele; a água cede: redemoinhos sobem pelo casco, bolhas saem
#                das vergas e do fundo, tábuas do fundo se soltam; bate no
#                fundo: colunas de areia e água jogadas para cima, jatos nas
#                pontas do casco, tábuas do fundo voando, farpas e bolhas.
#                Ele afunda longe, ATRÁS do templo e do poneglifo pequeno
#                (menor e um pouco enevoado): esse pedaço do fundo é desenhado
#                de novo por cima dele (máscara de tools/gerar_mar.py)
#   pedras       as escritas acendem de cima para baixo; tiro na pedra solta
#                lascas e deixa o buraco com rachaduras no lugar
#   templo       ruína de Atlântida ao fundo (pintada no fundo pelo
#                tools/gerar_mar.py): a luz de cristal da porta respira com a
#                música e solta pontinhos de luz que sobem
#   água viva    partículas boiando à deriva na correnteza (a luz do sol
#                de fora — raios balançando e a cáustica na cena toda — fica
#                no shader do fundo, shaders/fundo_profundo.gdshader)

signal navio_pousou

const TEMPLO_PORTA := Vector2(439, 724)

const TEXTURA_MASCARA := "res://sprites/mar_cascatas_mascara.png"
const SHADER_CASCATA := "res://shaders/mar_cascata.gdshader"
const SHADER_BALEIA := "res://shaders/mar_baleia.gdshader"
const SHADER_CARDUME := preload("res://shaders/mar_cardume.gdshader")
const SHADER_PEDRA := preload("res://shaders/mar_pedra.gdshader")
const SHADER_RECORTE := preload("res://shaders/mar_recorte.gdshader")
# load() e não preload(): o Godot 4.6 nunca descarrega um script já carregado,
# e o que ele pré-carrega ficava na memória depois da primeira partida.
var PEIXE: Texture2D = load("res://sprites/mar_peixe.png")
# com cor de galeão e o rombo do tiro no casco (tools/gerar_navio_cor.py)
var NAVIO: Texture2D = load("res://sprites/mar_navio_cor.png")
var MASCARA_FRENTE: Texture2D = load("res://sprites/mar_frente_navio_mascara.png")
var BOLHA: Texture2D = load("res://sprites/mar_bolha.png")
var LODO: Texture2D = load("res://sprites/mar_lodo.png")
var FARPA: Texture2D = load("res://sprites/mar_farpa.png")
var CAUSTICA: Texture2D = load("res://sprites/mar_caustica.png")
var MASCARA_PEDRA_ESQ: Texture2D = load("res://sprites/mar_pedra_esq_mascara.png")
var MASCARA_PEDRA_DIR: Texture2D = load("res://sprites/mar_pedra_dir_mascara.png")
# as pedras recortadas (o fundo, atlantis_fundo.png, não tem mais as pedras:
# atrás delas ele foi reconstruído; tools/gerar_camadas.py)
var TEX_PEDRA_ESQ: Texture2D = load("res://sprites/mar_pedra_esq.png")
var TEX_PEDRA_DIR: Texture2D = load("res://sprites/mar_pedra_dir.png")
const SOM_BALEIA := preload("res://songs/baleia.wav")
const SOM_NAVIO_DESCE := preload("res://songs/navio_desce.wav")
const SOM_NAVIO_IMPACTO := preload("res://songs/navio_impacto.wav")
const SOM_PEDRA := preload("res://songs/pedra_lasca.wav")

# Onde há água caindo (x0, y0, x1, y1), em pixels da textura.
# (a de 552,492 saiu: ali a foto agora tem a pedra escura atrás do Poseidon,
# e a água escorrendo virava riscas em cima da pedra)
const CASCATAS := [
	Rect2(158, 298, 46, 220),
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
# Onde ele afunda: longe, atrás do templo (o casco fica escondido atrás do
# templo e do poneglifo pequeno; os mastros aparecem por cima), menor e
# tingido pela água como o templo.
const NAVIO_LONGE := Vector2(380, 768)
const NAVIO_ESCALA := 0.70
const NAVIO_NEVOA := Color(0.90, 0.96, 1.0, 1.0)
# o rombo do tiro no casco (px da caixa do navio, tools/gerar_navio_cor.py):
# solta bolhas e pó de madeira enquanto ele afunda
const NAVIO_FURO := Vector2(176, 404)
# O que fica na frente dele (tools/gerar_mar.py, mar_frente_navio_mascara.png)
const FRENTE_CANTO := Vector2(195, 530)
const FRENTE_TAM := Vector2(430, 381)
# Pontos no alto do casco, mastros e vergas (px do recorte): de onde sai o
# rastro de bolhas enquanto ele afunda (tools/gerar_mar.py).
const NAVIO_RASTRO := [Vector2(20, 110), Vector2(39, 132), Vector2(44, 106), Vector2(46, 106), Vector2(53, 98), Vector2(55, 275), Vector2(60, 95), Vector2(60, 146), Vector2(90, 85), Vector2(99, 402), Vector2(119, 176), Vector2(129, 108), Vector2(150, 277), Vector2(154, 396), Vector2(158, 312), Vector2(164, 55), Vector2(200, 396), Vector2(202, 151), Vector2(202, 315), Vector2(209, 28), Vector2(209, 393), Vector2(217, 138), Vector2(226, 101), Vector2(227, 294), Vector2(232, 338), Vector2(233, 27), Vector2(240, 118), Vector2(241, 88), Vector2(250, 63), Vector2(251, 278), Vector2(256, 62), Vector2(256, 90), Vector2(256, 175), Vector2(257, 157), Vector2(267, 65), Vector2(269, 66), Vector2(278, 341), Vector2(284, 338), Vector2(291, 315), Vector2(292, 327), Vector2(294, 311), Vector2(294, 312), Vector2(295, 319), Vector2(300, 42), Vector2(300, 316), Vector2(307, 27), Vector2(313, 66), Vector2(357, 349)]
# Onde o casco bate no chão (px do recorte): de lá saem as lascas de madeira.
const NAVIO_CASCO := [Vector2(70, 430), Vector2(110, 452), Vector2(150, 468), Vector2(190, 478), Vector2(230, 482), Vector2(270, 476), Vector2(305, 462), Vector2(330, 440)]

# Pedras: canto e tamanho da caixa de cada máscara.
# z: distância de cada pedra (a do pé dela no chão; tools/gerar_profundidade.py)
const PEDRAS := [
	{"canto": Vector2(0, 466), "tam": Vector2(238, 471), "mascara": "esq", "fase": 0.0, "z": 2.68},
	{"canto": Vector2(523, 523), "tam": Vector2(428, 710), "mascara": "dir", "fase": 0.45, "z": 1.12},
]
const CHAO_TELA := 0.86      # o chão no plano Z = 1 (fração da altura da tela; scripts/mar.gd)
const BASE_TEMPLO := 790.0   # daqui para cima, tudo longe


## Ordem de desenho pela distância: perto na frente. Os alvos, as pedras e os
## efeitos usam a mesma conta, então um alvo longe passa atrás da pedra e um
## perto passa na frente.
static func z_desenho(z: float) -> int:
	return 100 + int(round(60.0 / maxf(z, 0.05)))
const MAX_DANOS := 12
const FOLGA_PEDRA := 24.0    # tools/gerar_camadas.py MAR_FOLGA

var _baleias: Array = []
var _pedras: Array = []          # {no, mat, img, canto, tam, danos}
var _lascas: Array = []          # {no, vel, giro, t, vida, cresce}
var _poeira_pedra: CPUParticles2D = null
var _bolhas_pedra: CPUParticles2D = null

var _navio: Sprite2D = null
var _bolhas_furo: CPUParticles2D = null
var _frente: Sprite2D = null           # templo e poneglifo pequeno por cima do navio
var _navio_estado := ""          # "" fora, "caindo", "pousado", "fim"
var _navio_t := 0.0
var _rastro: CPUParticles2D = null      # bolhas saindo das vergas enquanto afunda
var _esteira: CPUParticles2D = null     # água cedendo: redemoinhos subindo pelo casco
var _bolhas_casco: CPUParticles2D = null  # bolhas do fundo do casco enquanto afunda
var _soltas := 0                        # tábuas que já se soltaram na descida
var _lodo: CPUParticles2D = null        # colunas de areia e água jogadas para cima
var _lodo_jatos: CPUParticles2D = null  # jatos nas pontas do casco (água espremida)
var _areia: CPUParticles2D = null       # grãos de areia jogados para cima
var _farpas: CPUParticles2D = null      # farpas de madeira girando
var _bolhas_pouso: CPUParticles2D = null


func _ready() -> void:
	_criar_cascatas()
	_criar_cardumes()
	_criar_baleias()
	_criar_templo()
	_criar_navio()
	_criar_frente_do_navio()
	_criar_pedras()
	_criar_efeitos()
	_criar_agua_viva()


var _templo_luz: Sprite2D = null
var _templo_miolo: Sprite2D = null
var _templo_pontos: CPUParticles2D = null
var _templo_t := 0.0


## Luz de cristal na porta do templo: halo que respira com a música e
## pontinhos de luz subindo devagar (vai para cima do recorte do templo que
## fica na frente do navio).
func _criar_templo() -> void:
	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var ponto := FundoVivo.brilho_redondo()
	_templo_luz = Sprite2D.new()
	_templo_luz.texture = ponto
	_templo_luz.material = soma
	_templo_luz.position = TEMPLO_PORTA
	_templo_luz.scale = Vector2(2.6, 3.4)
	_templo_luz.modulate = Color(0.35, 0.9, 1.0, 0.5)
	add_child(_templo_luz)
	_templo_miolo = Sprite2D.new()
	_templo_miolo.texture = ponto
	_templo_miolo.material = soma
	_templo_miolo.position = TEMPLO_PORTA + Vector2(0, 4)
	_templo_miolo.scale = Vector2(0.7, 1.4)
	_templo_miolo.modulate = Color(0.8, 1.0, 1.0, 0.6)
	add_child(_templo_miolo)
	var p := CPUParticles2D.new()
	p.amount = 8
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.position = TEMPLO_PORTA + Vector2(0, 14)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(9, 16)
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2(0, -4)
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 16.0
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.18
	p.texture = ponto
	p.color = Color(0.6, 1.0, 1.0, 0.8)
	p.color_ramp = _rampa(Color(0.6, 1.0, 1.0), 0.8)
	p.material = soma
	add_child(p)
	_templo_pontos = p


func _animar_templo(delta: float) -> void:
	if _templo_luz == null:
		return
	_templo_t += delta
	var som := Maquina.pulso_vivo()
	var resp := 0.5 + 0.5 * sin(_templo_t * 1.3)
	_templo_luz.modulate.a = 0.30 + 0.22 * resp + 0.25 * som.x
	_templo_miolo.modulate.a = 0.45 + 0.25 * resp + 0.3 * som.y


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
	_navio.position = NAVIO_LONGE
	_navio.scale = Vector2.ONE * NAVIO_ESCALA
	_navio.visible = false
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

	# a água cedendo ao navio: redemoinhos claros nascem no fundo e nos lados
	# do casco e ficam para trás (sobem em relação a ele) enquanto ele desce
	var casco := PackedVector2Array()
	for p in NAVIO_CASCO:
		casco.append(p - (NAVIO_PIVO - NAVIO_CANTO))
	_esteira = CPUParticles2D.new()
	_esteira.name = "Esteira"
	_esteira.amount = 46
	_esteira.lifetime = 1.9
	_esteira.emitting = false
	_esteira.local_coords = false
	_esteira.texture = LODO
	_esteira.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	_esteira.emission_points = casco
	_esteira.direction = Vector2(0, -1)
	_esteira.spread = 50.0
	_esteira.gravity = Vector2(0, -25)
	_esteira.initial_velocity_min = 40.0
	_esteira.initial_velocity_max = 110.0
	_esteira.damping_min = 30.0
	_esteira.damping_max = 60.0
	_esteira.angle_max = 360.0
	_esteira.angular_velocity_min = -40.0
	_esteira.angular_velocity_max = 40.0
	_esteira.scale_amount_min = 0.4
	_esteira.scale_amount_max = 0.9
	_esteira.scale_amount_curve = _curva(0.5, 1.7)
	_esteira.color_ramp = _rampa(Color(0.86, 0.95, 1.0), 0.42)
	_navio.add_child(_esteira)

	_bolhas_casco = CPUParticles2D.new()
	_bolhas_casco.name = "BolhasCasco"
	_bolhas_casco.amount = 50
	_bolhas_casco.lifetime = 2.4
	_bolhas_casco.emitting = false
	_bolhas_casco.local_coords = false
	_bolhas_casco.texture = BOLHA
	_bolhas_casco.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	_bolhas_casco.emission_points = casco
	_bolhas_casco.direction = Vector2(0, -1)
	_bolhas_casco.spread = 40.0
	_bolhas_casco.gravity = Vector2(0, -140)
	_bolhas_casco.initial_velocity_min = 20.0
	_bolhas_casco.initial_velocity_max = 70.0
	_bolhas_casco.tangential_accel_min = -40.0
	_bolhas_casco.tangential_accel_max = 40.0
	_bolhas_casco.scale_amount_min = 0.12
	_bolhas_casco.scale_amount_max = 0.38
	_bolhas_casco.scale_amount_curve = _curva(0.6, 1.3)
	_bolhas_casco.color_ramp = _rampa(Color(0.88, 0.96, 1.0), 0.9)
	_navio.add_child(_bolhas_casco)

	# o ar saindo pelo rombo do tiro: um fio de bolhas grandes e pó de
	# madeira (a água entrando)
	_bolhas_furo = CPUParticles2D.new()
	_bolhas_furo.name = "BolhasFuro"
	_bolhas_furo.amount = 36
	_bolhas_furo.lifetime = 2.0
	_bolhas_furo.emitting = false
	_bolhas_furo.local_coords = false
	_bolhas_furo.texture = BOLHA
	_bolhas_furo.position = NAVIO_FURO - (NAVIO_PIVO - NAVIO_CANTO)
	_bolhas_furo.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_bolhas_furo.emission_sphere_radius = 10.0
	_bolhas_furo.direction = Vector2(-0.4, -1)
	_bolhas_furo.spread = 22.0
	_bolhas_furo.gravity = Vector2(0, -220)
	_bolhas_furo.initial_velocity_min = 40.0
	_bolhas_furo.initial_velocity_max = 110.0
	_bolhas_furo.tangential_accel_min = -30.0
	_bolhas_furo.tangential_accel_max = 30.0
	_bolhas_furo.scale_amount_min = 0.25
	_bolhas_furo.scale_amount_max = 0.6
	_bolhas_furo.scale_amount_curve = _curva(0.7, 1.4)
	_bolhas_furo.color_ramp = _rampa(Color(0.92, 0.98, 1.0), 0.95)
	_navio.add_child(_bolhas_furo)


## O templo, o Poseidon e o poneglifo pequeno (com a ilha de pedras na frente
## dele) desenhados de novo por cima do navio: o mesmo fundo, recortado pela
## máscara. A luz da porta do templo sobe para cima do recorte.
func _criar_frente_do_navio() -> void:
	var fundo := get_parent() as Sprite2D
	if fundo == null or fundo.texture == null:
		return
	var tex_tam := fundo.texture.get_size()
	_frente = Sprite2D.new()
	_frente.name = "FrenteDoNavio"
	_frente.texture = fundo.texture
	_frente.centered = false
	_frente.region_enabled = true
	_frente.region_rect = Rect2(FRENTE_CANTO, FRENTE_TAM)
	_frente.position = FRENTE_CANTO
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_RECORTE
	mat.set_shader_parameter("mascara", MASCARA_FRENTE)
	mat.set_shader_parameter("regiao", Vector4(FRENTE_CANTO.x / tex_tam.x, FRENTE_CANTO.y / tex_tam.y,
		FRENTE_TAM.x / tex_tam.x, FRENTE_TAM.y / tex_tam.y))
	_frente.material = mat
	add_child(_frente)
	for no: Node in [_templo_luz, _templo_miolo, _templo_pontos]:
		if no != null:
			move_child(no, -1)


## Ponto do navio pousado (px da caixa original do navio na foto) levado para
## onde ele afunda agora (longe, menor).
func _no_longe(p: Vector2) -> Vector2:
	return NAVIO_LONGE + (p - NAVIO_PIVO) * NAVIO_ESCALA


## Começa a queda (a cena chama aos 9 s de partida). Só uma vez.
func cair_navio() -> void:
	if _navio_estado != "":
		return
	_navio_estado = "caindo"
	_navio_t = 0.0
	_navio.visible = true
	_navio.modulate = NAVIO_NEVOA
	_navio.position = NAVIO_LONGE - Vector2(0, NAVIO_ALTURA)
	_soltas = 0
	_rastro.emitting = true
	_esteira.emitting = true
	_bolhas_casco.emitting = true
	_bolhas_furo.emitting = true
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
		_navio.position = NAVIO_LONGE - Vector2(24.0 * NAVIO_ESCALA * resta * sin(_navio_t * 0.9 + 0.4), NAVIO_ALTURA * (1.0 - desce))
		# afunda adernando: balança de proa e de lado, o casco range (um
		# tico de torção) e o mastro chicoteia
		_navio.rotation = deg_to_rad(6.5) * resta + deg_to_rad(3.2) * sin(_navio_t * 1.45) * resta \
			+ deg_to_rad(1.2) * sin(_navio_t * 3.1 + 0.7) * resta
		_navio.skew = 0.035 * sin(_navio_t * 2.2) * resta
		# tábuas do fundo do casco se soltando na descida (ficam para trás)
		if _soltas < 4 and _navio_t > 0.9 + _soltas * 0.75:
			_soltas += 1
			var ponto: Vector2 = NAVIO_CASCO[randi() % NAVIO_CASCO.size()] + Vector2(randf_range(-10, 10), randf_range(-16, -4))
			var l := _soltar_lasca(_navio.transform * (ponto - (NAVIO_PIVO - NAVIO_CANTO)), randf_range(9.0, 14.0) * NAVIO_ESCALA, true, NAVIO, ponto, true, true)
			l["vel"] = Vector2(randf_range(-50.0, 50.0), randf_range(20.0, 60.0)) * NAVIO_ESCALA
			l["vida"] = randf_range(2.0, 2.6)
		if k >= 1.0:
			_pousar()
	elif _navio_estado == "pousado":
		# assenta: afunda um pouco na areia, volta e para; o balanço morre
		var t := _navio_t
		_navio.position = NAVIO_LONGE + Vector2(0, 5.0 * NAVIO_ESCALA * exp(-t * 4.0) * sin(t * 9.0 + 0.6))
		_navio.rotation = deg_to_rad(1.6) * exp(-t * 3.0) * cos(t * 7.0)
		_navio.skew = 0.0
		if t > 2.0:
			_navio.position = NAVIO_LONGE
			_navio.rotation = 0.0
			_navio_estado = "fim"


func _pousar() -> void:
	_navio_estado = "pousado"
	_navio_t = 0.0
	_rastro.emitting = false
	_esteira.emitting = false
	_bolhas_casco.emitting = false
	_bolhas_furo.amount = 12          # depois de pousado ainda escapa um pouco de ar
	for p: CPUParticles2D in [_lodo, _lodo_jatos, _areia, _farpas, _bolhas_pouso]:
		p.restart()
		p.emitting = true
	# tábuas do fundo do casco arrancadas na batida (recortadas do próprio
	# navio): voam para cima e para os lados, giram e afundam devagar
	for i in 14:
		var ponto: Vector2 = NAVIO_CASCO[i % NAVIO_CASCO.size()] + Vector2(randf_range(-16, 16), randf_range(-22, -2))
		var l := _soltar_lasca(_no_longe(NAVIO_CANTO + ponto), randf_range(12.0, 21.0) * NAVIO_ESCALA, true, NAVIO, ponto, true, true)
		var lado := (ponto.x - 230.0) / 160.0
		l["vel"] = Vector2(lado * randf_range(120.0, 260.0) + randf_range(-60.0, 60.0), -randf_range(260.0, 460.0)) * NAVIO_ESCALA
		l["vida"] = randf_range(3.2, 4.4)
	Maquina.efeito(SOM_NAVIO_IMPACTO, -2.0)
	navio_pousou.emit()


# ───────────────────────────────────────────── pedras com escritas
func _criar_pedras() -> void:
	for d in PEDRAS:
		var esq: bool = d["mascara"] == "esq"
		var mascara: Texture2D = MASCARA_PEDRA_ESQ if esq else MASCARA_PEDRA_DIR
		var canto: Vector2 = d["canto"]
		var tam: Vector2 = d["tam"]
		var tex: Texture2D = TEX_PEDRA_ESQ if esq else TEX_PEDRA_DIR
		# a textura é a caixa da máscara com FOLGA_PEDRA px em volta (cortada
		# na borda da imagem): o contorno de verdade passa da máscara
		var tex_canto := Vector2(maxf(canto.x - FOLGA_PEDRA, 0.0), maxf(canto.y - FOLGA_PEDRA, 0.0))
		var tex_tam := tex.get_size()
		var desloc := canto - tex_canto
		var s := Sprite2D.new()
		s.name = "Pedra_" + d["mascara"]
		s.texture = tex
		s.centered = false
		s.position = tex_canto
		var mat := ShaderMaterial.new()
		mat.shader = SHADER_PEDRA
		mat.set_shader_parameter("mascara", mascara)
		mat.set_shader_parameter("regiao", Vector4(desloc.x / tex_tam.x, desloc.y / tex_tam.y, tam.x / tex_tam.x, tam.y / tex_tam.y))
		mat.set_shader_parameter("aspecto", tam.x / tam.y)
		mat.set_shader_parameter("fase", d["fase"])
		mat.set_shader_parameter("n_danos", 0)
		mat.set_shader_parameter("caustica", CAUSTICA)
		mat.set_shader_parameter("tam_px", tex_tam)
		s.material = mat
		# cada pedra é uma camada na distância dela (anda pela paralaxe e os
		# alvos passam na frente ou atrás dela)
		s.z_as_relative = false
		s.z_index = z_desenho(d["z"])
		add_child(s)
		var img := tex.get_image()
		if img != null and img.is_compressed():
			img.decompress()
		# canto/tam: a caixa da textura; desloc: onde a caixa da máscara (das
		# runas e dos buracos) começa dentro dela
		_pedras.append({"no": s, "mat": mat, "img": img, "canto": tex_canto, "tam": tex_tam, "desloc": desloc,
			"tam_mascara": tam, "danos": [], "z": d["z"]})


## Tiro em `pos` (px da textura). Se for numa pedra: buraco, lascas, poeira e
## som; devolve true.
func acertar_pedra(pos: Vector2) -> bool:
	for p in _pedras:
		var local: Vector2 = pos - (p["no"] as Node2D).position
		var tam: Vector2 = p["tam"]
		if local.x < 0.0 or local.y < 0.0 or local.x >= tam.x or local.y >= tam.y:
			continue
		var img: Image = p["img"]
		if img == null or img.get_pixel(int(local.x), int(local.y)).a < 0.5:
			continue
		_quebrar(p, pos, local)
		return true
	return false


## Distância da pedra que cobre o ponto `pos` (px da textura), ou INF.
func z_da_pedra_em(pos: Vector2) -> float:
	var z := INF
	for p in _pedras:
		var local: Vector2 = pos - (p["no"] as Node2D).position
		var tam: Vector2 = p["tam"]
		if local.x < 0.0 or local.y < 0.0 or local.x >= tam.x or local.y >= tam.y:
			continue
		var img: Image = p["img"]
		if img != null and img.get_pixel(int(local.x), int(local.y)).a >= 0.5:
			z = minf(z, float(p["z"]))
	return z


var _cam := Vector2.ZERO
var _inv_z_fundo := 0.125


## A câmera andou (scripts/mar_profundo.gd): cada pedra anda o quanto a
## distância dela manda, por cima do fundo (que já andou como a parte longe).
func ajustar_paralaxe(c: Vector2, inv_z_fundo: float) -> void:
	_cam = c
	_inv_z_fundo = inv_z_fundo
	var esc := absf((get_parent() as Node2D).scale.x) if get_parent() is Node2D else 1.0
	for p in _pedras:
		(p["no"] as Node2D).position = p["canto"] + c * (inv_z_fundo - 1.0 / float(p["z"])) / esc


## Distância do chão na linha y (px da textura).
func z_do_chao(y: float) -> float:
	if y <= BASE_TEMPLO:
		return 10.0
	var fuga := to_global(TEMPLO_PORTA).y
	var perto := get_viewport_rect().size.y * CHAO_TELA
	return clampf((perto - fuga) / maxf(to_global(Vector2(0, y)).y - fuga, 0.001), 0.7, 10.0)


## Quanto um ponto do chão (px da textura) anda por cima do fundo agora.
func deslocamento_no_chao(p: Vector2) -> Vector2:
	var esc := absf((get_parent() as Node2D).scale.x) if get_parent() is Node2D else 1.0
	return _cam * (_inv_z_fundo - 1.0 / z_do_chao(p.y)) / esc


func _quebrar(p: Dictionary, pos: Vector2, local: Vector2) -> void:
	# o buraco é marcado na caixa da máscara (o shader desenha lá)
	var tam: Vector2 = p["tam_mascara"]
	var lm: Vector2 = local - p["desloc"]
	var raio := randf_range(13.0, 18.0)
	var danos: Array = p["danos"]
	danos.append(Vector4(lm.x / tam.x, lm.y / tam.y, raio / tam.x, randf()))
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
	var tex_pedra: Texture2D = (p["no"] as Sprite2D).texture
	_soltar_lasca(pos, raio * 1.05, true, tex_pedra, local)
	for i in 4:
		var v := Vector2(randf_range(-6, 6), randf_range(-6, 6))
		_soltar_lasca(pos + v, raio * randf_range(0.28, 0.45), false, tex_pedra, local + v)
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
## atras: a lasca é do navio (lá longe) e fica atrás do templo da frente.
func _soltar_lasca(pos: Vector2, raio: float, grande: bool, textura: Texture2D = null, uv_em: Vector2 = Vector2.INF, tabua: bool = false, atras: bool = false) -> Dictionary:
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
	if atras and _frente != null:
		var k := _frente.get_index()
		move_child(no, k - 1 if no.get_index() < k else k)
	else:
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
		no.color = Color(1, 1, 1)
	return lasca


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

	# o mar cedendo na batida: colunas de areia e água jogadas para cima ao
	# longo do fundo do casco; a água freia, elas abrem, giram e assentam
	_lodo = _particulas("Lodo", 48, 4.0, LODO, false)
	_lodo.position = NAVIO_LONGE
	_lodo.explosiveness = 0.9
	_lodo.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_lodo.emission_rect_extents = Vector2(150, 8)
	_lodo.direction = Vector2(0, -1)
	_lodo.spread = 24.0
	_lodo.initial_velocity_min = 150.0
	_lodo.initial_velocity_max = 380.0
	_lodo.damping_min = 240.0
	_lodo.damping_max = 320.0
	_lodo.gravity = Vector2(0, 14)
	_lodo.angular_velocity_min = -40.0
	_lodo.angular_velocity_max = 40.0
	_lodo.angle_max = 360.0
	_lodo.scale_amount_min = 0.7
	_lodo.scale_amount_max = 1.6
	_lodo.scale_amount_curve = _curva(0.5, 2.0)
	_lodo.color_ramp = _rampa(Color(0.76, 0.86, 0.90), 0.72)

	# água espremida nas pontas do casco: dois jatos para cima e para fora
	_lodo_jatos = _particulas("LodoJatos", 24, 3.0, LODO, false)
	_lodo_jatos.explosiveness = 0.95
	_lodo_jatos.emission_shape = CPUParticles2D.EMISSION_SHAPE_DIRECTED_POINTS
	_lodo_jatos.position = NAVIO_LONGE
	_lodo_jatos.emission_points = PackedVector2Array([Vector2(238, 900) - NAVIO_PIVO, Vector2(250, 906) - NAVIO_PIVO,
		Vector2(500, 884) - NAVIO_PIVO, Vector2(515, 866) - NAVIO_PIVO])
	_lodo_jatos.emission_normals = PackedVector2Array([Vector2(-0.55, -1).normalized(), Vector2(-0.45, -1).normalized(),
		Vector2(0.3, -1).normalized(), Vector2(0.38, -1).normalized()])
	_lodo_jatos.direction = Vector2(0, -1)
	_lodo_jatos.spread = 14.0
	_lodo_jatos.initial_velocity_min = 240.0
	_lodo_jatos.initial_velocity_max = 420.0
	_lodo_jatos.damping_min = 300.0
	_lodo_jatos.damping_max = 380.0
	_lodo_jatos.gravity = Vector2(0, 20)
	_lodo_jatos.angle_max = 360.0
	_lodo_jatos.angular_velocity_min = -60.0
	_lodo_jatos.angular_velocity_max = 60.0
	_lodo_jatos.scale_amount_min = 0.5
	_lodo_jatos.scale_amount_max = 1.2
	_lodo_jatos.scale_amount_curve = _curva(0.4, 1.7)
	_lodo_jatos.color_ramp = _rampa(Color(0.84, 0.92, 0.95), 0.75)

	# grãos de areia jogados para cima: sobem rápido e caem de volta
	_areia = _particulas("Areia", 70, 2.6, bola, false)
	_areia.position = NAVIO_LONGE
	_areia.explosiveness = 0.92
	_areia.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_areia.emission_rect_extents = Vector2(150, 6)
	_areia.direction = Vector2(0, -1)
	_areia.spread = 40.0
	_areia.initial_velocity_min = 220.0
	_areia.initial_velocity_max = 470.0
	_areia.damping_min = 60.0
	_areia.damping_max = 110.0
	_areia.gravity = Vector2(0, 240)
	_areia.scale_amount_min = 0.05
	_areia.scale_amount_max = 0.13
	_areia.color_ramp = _rampa(Color(0.92, 0.93, 0.86), 0.95)

	# farpas de madeira girando e afundando devagar
	_farpas = _particulas("Farpas", 22, 3.2, FARPA, false)
	_farpas.position = _no_longe(Vector2(355, 895))
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
	_bolhas_pouso = _particulas("BolhasPouso", 70, 3.4, BOLHA, false)
	_bolhas_pouso.position = _no_longe(Vector2(370, 870))
	_bolhas_pouso.explosiveness = 0.6
	_bolhas_pouso.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_bolhas_pouso.emission_rect_extents = Vector2(165, 40)
	_bolhas_pouso.direction = Vector2(0, -1)
	_bolhas_pouso.spread = 30.0
	_bolhas_pouso.gravity = Vector2(0, -160)
	_bolhas_pouso.initial_velocity_min = 40.0
	_bolhas_pouso.initial_velocity_max = 130.0
	_bolhas_pouso.tangential_accel_min = -30.0
	_bolhas_pouso.tangential_accel_max = 30.0
	_bolhas_pouso.scale_amount_min = 0.10
	_bolhas_pouso.scale_amount_max = 0.34
	_bolhas_pouso.scale_amount_curve = _curva(0.6, 1.35)
	_bolhas_pouso.color_ramp = _rampa(Color(0.85, 0.95, 1.0), 0.85)

	# o que a batida levanta fica atrás do templo e das pedras da frente (como
	# o navio) e na mesma escala dele (lá longe)
	var depois_do_navio := _navio.get_index() + 1
	for p: CPUParticles2D in [_bolhas_pouso, _farpas, _areia, _lodo_jatos, _lodo]:
		p.scale = Vector2.ONE * NAVIO_ESCALA
		move_child(p, depois_do_navio)
	# a areia e a água sobem acima do telhado do templo (a água freia igual,
	# então lá longe elas precisam sair um pouco mais fortes)
	for p: CPUParticles2D in [_lodo, _lodo_jatos, _areia]:
		p.initial_velocity_min *= 1.35
		p.initial_velocity_max *= 1.35


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


# ───────────────────────────────────────────── a água em movimento
func _criar_agua_viva() -> void:
	# partículas boiando na correnteza
	var p := CPUParticles2D.new()
	p.name = "Deriva"
	p.amount = 40
	p.lifetime = 16.0
	p.preprocess = 16.0
	p.texture = FundoVivo.brilho_redondo()
	p.position = Vector2(512, 760)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(560, 760)
	p.direction = Vector2(0.4, 1.0)
	p.spread = 30.0
	p.gravity = Vector2(2.0, 2.5)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 14.0
	p.tangential_accel_min = -3.0
	p.tangential_accel_max = 3.0
	p.scale_amount_min = 0.07
	p.scale_amount_max = 0.16
	p.color_ramp = _rampa(Color(0.85, 0.95, 1.0), 0.55)
	add_child(p)


# ───────────────────────────────────────────── quadro a quadro
func _process(delta: float) -> void:
	_animar_templo(delta)
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
