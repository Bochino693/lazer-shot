extends Node2D

# Sol entrando pela janela do bar: feixe de luz que respira e poeira
# brilhando dentro dele. Fica como filho do fundo (Background), com a
# origem no centro da textura (1024x1536), igual ao fundo centralizado.
#
# Custo: o feixe é um sprite só (textura pequena esticada, shader leve) e a
# poeira é um CPUParticles2D (um desenho para todas as partículas).

const TEXTURA_FEIXE := "res://sprites/bar_raios_sol.png"
const SHADER_FEIXE := "res://shaders/bar_sol.gdshader"

# Pontos dentro do feixe (pixels da textura do fundo), gerados junto com a
# textura do feixe.
const PONTOS_POEIRA := [Vector2(400, 590), Vector2(656, 1139), Vector2(703, 1164), Vector2(438, 748), Vector2(348, 309), Vector2(619, 955), Vector2(134, 198), Vector2(558, 936), Vector2(553, 951), Vector2(513, 1024), Vector2(468, 966), Vector2(340, 603), Vector2(191, 218), Vector2(377, 571), Vector2(438, 701), Vector2(397, 569), Vector2(595, 896), Vector2(352, 406), Vector2(597, 1059), Vector2(640, 1099), Vector2(616, 1177), Vector2(667, 1136), Vector2(350, 474), Vector2(217, 436), Vector2(290, 501), Vector2(467, 566), Vector2(417, 624), Vector2(514, 741), Vector2(650, 1067), Vector2(365, 423), Vector2(110, 138), Vector2(667, 1167), Vector2(367, 699), Vector2(492, 737), Vector2(439, 821), Vector2(460, 590), Vector2(287, 390), Vector2(315, 638), Vector2(248, 419), Vector2(553, 995), Vector2(415, 843), Vector2(396, 347), Vector2(294, 305), Vector2(423, 395), Vector2(610, 920), Vector2(298, 204), Vector2(424, 844), Vector2(264, 275), Vector2(229, 368), Vector2(592, 1009), Vector2(221, 145), Vector2(347, 511), Vector2(502, 947), Vector2(609, 1176), Vector2(597, 1036), Vector2(303, 252), Vector2(449, 936), Vector2(439, 740), Vector2(446, 787), Vector2(198, 363), Vector2(427, 591), Vector2(330, 614), Vector2(402, 675), Vector2(281, 271), Vector2(619, 917), Vector2(209, 286), Vector2(639, 960), Vector2(464, 628), Vector2(341, 636), Vector2(526, 802), Vector2(359, 734), Vector2(297, 295), Vector2(519, 618), Vector2(498, 813), Vector2(338, 472), Vector2(350, 623), Vector2(179, 341), Vector2(317, 126), Vector2(397, 438), Vector2(620, 976)]


func _ready() -> void:
	var fundo := get_parent() as Sprite2D
	if fundo == null or fundo.texture == null:
		return
	var tam_fundo: Vector2 = fundo.texture.get_size()

	if ResourceLoader.exists(TEXTURA_FEIXE) and ResourceLoader.exists(SHADER_FEIXE):
		var feixe := Sprite2D.new()
		feixe.name = "Feixe"
		feixe.texture = load(TEXTURA_FEIXE)
		feixe.centered = true
		var tam_feixe: Vector2 = feixe.texture.get_size()
		feixe.scale = tam_fundo / tam_feixe
		var mat := ShaderMaterial.new()
		mat.shader = load(SHADER_FEIXE)
		feixe.material = mat
		add_child(feixe)

	var poeira := CPUParticles2D.new()
	poeira.name = "Poeira"
	poeira.position = -tam_fundo * 0.5
	# Na frente das garrafas (poeira no ar), mas bem discreta.
	poeira.z_as_relative = false
	poeira.z_index = 8
	poeira.amount = 42
	poeira.lifetime = 7.0
	poeira.preprocess = 7.0
	poeira.local_coords = true
	poeira.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	var pts := PackedVector2Array()
	for p in PONTOS_POEIRA:
		pts.append(p)
	poeira.emission_points = pts
	poeira.direction = Vector2(0.4, 0.9)
	poeira.spread = 180.0
	poeira.gravity = Vector2(0.0, 2.5)
	poeira.initial_velocity_min = 3.0
	poeira.initial_velocity_max = 12.0
	poeira.angular_velocity_min = 0.0
	poeira.angular_velocity_max = 0.0
	poeira.scale_amount_min = 0.3
	poeira.scale_amount_max = 0.8
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.18, 0.4, 0.55, 0.75, 1.0])
	rampa.colors = PackedColorArray([
		Color(1.0, 0.86, 0.6, 0.0),
		Color(1.0, 0.9, 0.66, 0.8),
		Color(1.0, 0.86, 0.6, 0.25),
		Color(1.0, 0.94, 0.75, 0.95),
		Color(1.0, 0.86, 0.6, 0.35),
		Color(1.0, 0.86, 0.6, 0.0),
	])
	poeira.color_ramp = rampa
	var ponto := GradientTexture2D.new()
	ponto.width = 12
	ponto.height = 12
	ponto.fill = GradientTexture2D.FILL_RADIAL
	ponto.fill_from = Vector2(0.5, 0.5)
	ponto.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	ponto.gradient = g
	poeira.texture = ponto
	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	poeira.material = soma
	add_child(poeira)
