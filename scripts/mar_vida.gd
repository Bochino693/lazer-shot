extends Node2D

# Vida do fundo do mar: cachoeiras escorrendo e baleias nadando.
# Fica como filho do Sprite2D do fundo, com a origem no canto da textura,
# então todas as posições aqui são pixels de atlantis.png (1024x1536).
#
# Custo: as 8 cachoeiras usam o mesmo material e a mesma textura do fundo,
# então saem num desenho só; cada baleia é mais um desenho.

const TEXTURA_MASCARA := "res://sprites/mar_cascatas_mascara.png"
const SHADER_CASCATA := "res://shaders/mar_cascata.gdshader"
const SHADER_BALEIA := "res://shaders/mar_baleia.gdshader"

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

var _baleias: Array = []


func _ready() -> void:
	_criar_cascatas()
	_criar_baleias()


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


func _criar_baleias() -> void:
	if not ResourceLoader.exists(SHADER_BALEIA):
		return
	var shader: Shader = load(SHADER_BALEIA)

	# A de trás primeiro (fica atrás na ordem de desenho): menor, mais alta,
	# mais lenta e mais apagada pela água; a da frente maior e mais nítida.
	var dados := [
		{"img": "res://sprites/mar_baleia_2.png", "inicio": Vector2(600.0, 318.0), "vel": 9.0, "y_min": 302.0, "y_max": 336.0, "escala": 0.9, "fase": 1.7, "batida": 1.35},
		{"img": "res://sprites/mar_baleia_1.png", "inicio": Vector2(455.0, 378.0), "vel": 13.0, "y_min": 352.0, "y_max": 404.0, "escala": 1.08, "fase": 0.0, "batida": 1.1},
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
		}
		b["escala_base"] = d["escala"]
		# Primeira volta: já começa visível na água e segue para a esquerda.
		_comecar_volta(b, d["inicio"], -1.0, d["escala"], true)
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

		var passou: bool = (b["x"] - b["fim_x"]) * b["sentido"] >= 0.0
		if passou:
			no.visible = false
			b["espera"] = randf_range(5.0, 12.0)
			continue

		_posicionar(b)


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
