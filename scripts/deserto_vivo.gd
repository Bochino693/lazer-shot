class_name DesertoVivo
extends Node2D

## EGITO VIVO: o fundo do Deserto Sagrado em camadas, tudo na placa de vídeo.
##
## Todas as posições aqui são pixels da imagem (1024x1536); o nó inteiro é
## escalado para cobrir a tela (sem zoom), ancorado no alto.
##
##   fundo (sol / lua)   imagem + shaders/deserto_fundo.gdshader: feixes de
##                       energia, cristal, ar quente, onda de luz na batida
##   raios               luz em volta do disco girando (egito_raios)
##   disco               sol com o Olho de Rá (pupila cheia) / lua com o Olho
##                       de Hórus (pupila vazada), no traço clássico do
##                       hieróglifo, pintados em 3x (nítidos em 4K), em
##                       camadas comuns sem shader: esclera, pupila que
##                       passeia, pálpebra que desce ao piscar e o disco com o
##                       hieróglifo gravado por cima (tools/gerar_astros.py)
##   águias              planando ao fundo em térmicas, batendo as asas de vez
##                       em quando, inclinando nas curvas, gritando (eco do
##                       vale); de noite silhuetas, às vezes cruzando a lua
##   pontas de ouro      topo das 3 pirâmides: ouro quente ao sol, prateado
##                       ao luar, reflexo correndo de uma para outra
##   diamante            arco-íris nas arestas de dia, vermelho de noite
##   brilhos             estrelas que piscam no diamante, nas pontas e no
##                       disco; estrelas no céu e estrela cadente de noite
##
## Uso: var vivo := DesertoVivo.new(); pai.add_child(vivo)
## (sem zoom: a imagem só cobre a tela, como as outras fases)
##      vivo.mostrar("sol" ou "lua", suave)

const IMG := Vector2(1024, 1536)

const FUNDO_SOL := preload("res://sprites/deserto_sol.png")
const FUNDO_LUA := preload("res://sprites/deserto_lua.png")
const MASCARA_SOL := preload("res://sprites/deserto_sol_mascara.png")
const MASCARA_LUA := preload("res://sprites/deserto_lua_mascara.png")
# Sol e lua em 3x (tools/gerar_astros.py), camadas comuns sem shader:
# esclera, íris (anda), pálpebra (desce ao piscar) e o disco por cima.
const TEX_SOL := [preload("res://sprites/egito_sol_disco.png"), preload("res://sprites/egito_sol_esclera.png"),
	preload("res://sprites/egito_sol_iris.png"), preload("res://sprites/egito_sol_palpebra.png")]
const TEX_LUA := [preload("res://sprites/egito_lua_disco.png"), preload("res://sprites/egito_lua_esclera.png"),
	preload("res://sprites/egito_lua_iris.png"), preload("res://sprites/egito_lua_palpebra.png")]
const AGUIA := preload("res://sprites/egito_aguia.png")
const SOM_AGUIA := preload("res://songs/aguia.wav")
const SOM_AGUIA_NOITE := preload("res://songs/aguia_noite.wav")
const PONTAS := preload("res://sprites/egito_pontas.png")
const CRISTAL := preload("res://sprites/egito_cristal_mascara.png")
const ESTRELA := preload("res://sprites/egito_estrela.png")
const SHADER_FUNDO := preload("res://shaders/deserto_fundo.gdshader")
const SHADER_RAIOS := preload("res://shaders/egito_raios.gdshader")
const SHADER_PONTAS := preload("res://shaders/egito_pontas.gdshader")
const SHADER_CRISTAL := preload("res://shaders/egito_cristal.gdshader")

# Mesmos números de tools/gerar_egito.py.
const CENTRO_SOL := Vector2(512, 300)
const RAIO_SOL := 138.0
const CENTRO_LUA := Vector2(512, 300)
const RAIO_LUA := 138.0
const PONTAS_CAIXA := Rect2(180, 438, 644, 148)

# Medidas do olho (px da textura 3x, a partir do centro do disco), de
# tools/gerar_astros.py: centro do olho, 1 unidade (meia largura da abertura),
# lugar da íris, topo da pálpebra e quanto ela desce para fechar.
# Sol: Olho de Rá (pupila cheia); lua: Olho de Hórus (pupila vazada).
const ASTRO_SOL := {"olho": Vector2(84.2, -18.7), "u": 234.0, "iris": Vector2(0.0, -18.7), "palpebra_y": -255.1, "abre": 173.2}
const ASTRO_LUA := {"olho": Vector2(-84.2, -18.7), "u": 234.0, "iris": Vector2(0.0, -18.7), "palpebra_y": -255.1, "abre": 173.2}
const CRISTAL_CAIXA := Rect2(440, 620, 136, 340)

const COR_SOL := Color(1.0, 0.78, 0.36)
const COR_LUA := Color(0.62, 0.80, 1.0)

const BRILHOS_CRISTAL := [Vector2(506, 634), Vector2(466, 721), Vector2(548, 721), Vector2(486, 792),
		Vector2(527, 846), Vector2(505, 893), Vector2(461, 944), Vector2(551, 944)]
const BRILHOS_PONTAS := [Vector2(229, 520), Vector2(509, 448), Vector2(774, 520)]
const TEMPO_TROCA := 1.6
# Águias (tools/gerar_aguias.py): 11 quadros (0 planando, 1..10 batendo asa);
# voam no céu acima das pirâmides, entre as colunas (px da imagem).
const AGUIA_QUADROS := 11
const CEU := Rect2(150, 196, 724, 236)
const N_AGUIAS := 3
const N_ESTRELAS_CEU := 18

var _fundo_sol: Sprite2D
var _fundo_lua: Sprite2D
var _raios_sol: ColorRect
var _raios_lua: ColorRect
var _disco_sol: Node2D
var _disco_lua: Node2D
# olho vivo de cada disco: {disco, iris, palpebra, iris_0, palpebra_0, u, abre,
# olhar, alvo, prox_olhar, piscar, prox_piscar, fase, dupla}
var _olhos: Array = []
var _pontas: Sprite2D
var _cristal: Sprite2D
var _faiscas: CPUParticles2D
var _poeira: CPUParticles2D
var _ceu_noite: Node2D
var _cadente: Sprite2D

var _brilhos: Array = []      # {no, cor, espera, t, dur, escala}
var _estrelas: Array = []     # {no, w, f}
var _modo := ""
var _noite := 0.0             # 0 = sol ... 1 = lua
var _tw: Tween = null
var _pisco := 0.0
var _proximo_pisco := 5.0
var _onda := 9.0
var _t := 0.0
var _cadente_t := -1.0
var _cadente_em := 6.0
var _cadente_de := Vector2.ZERO
var _cadente_para := Vector2.ZERO
# {no, pos, dir, vel, escala, modo, centro, raio, sentido, alvo, t, t_modo,
#  vida, bat, fase, inclin, grito, ruido, vento, espera}
var _aguias: Array = []
var _grito_espera := 4.0


func _init() -> void:
	name = "DesertoVivo"
	_fundo_sol = _criar_fundo(FUNDO_SOL, MASCARA_SOL, Color(1.0, 0.74, 0.34), 0.0)
	_fundo_lua = _criar_fundo(FUNDO_LUA, MASCARA_LUA, Color(1.0, 0.28, 0.30), 3.7)
	_raios_sol = _criar_raios(CENTRO_SOL, RAIO_SOL, 3.1, false, COR_SOL)
	_raios_lua = _criar_raios(CENTRO_LUA, RAIO_LUA, 2.7, true, COR_LUA)
	_disco_sol = _criar_astro(TEX_SOL, ASTRO_SOL, CENTRO_SOL)
	_disco_lua = _criar_astro(TEX_LUA, ASTRO_LUA, CENTRO_LUA)
	_criar_aguias()

	_pontas = _sprite_2x(PONTAS, PONTAS_CAIXA.position, SHADER_PONTAS)
	_cristal = _sprite_2x(CRISTAL, CRISTAL_CAIXA.position, SHADER_CRISTAL)

	_criar_particulas()

	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_ceu_noite = Node2D.new()
	_ceu_noite.name = "CeuNoite"
	add_child(_ceu_noite)
	_criar_estrelas_ceu(soma)
	for p in BRILHOS_CRISTAL:
		_criar_brilho(p, soma, randf_range(0.30, 0.55), "cristal")
	for p in BRILHOS_PONTAS:
		_criar_brilho(p, soma, randf_range(0.30, 0.42), "ponta")
	# o "pisco" do disco: estrela grande na borda de cima
	_criar_brilho(CENTRO_SOL + Vector2(-0.62, -0.66) * RAIO_SOL, soma, 0.9, "disco")

	_cadente = Sprite2D.new()
	_cadente.name = "EstrelaCadente"
	_cadente.texture = ESTRELA
	_cadente.material = soma
	_cadente.visible = false
	add_child(_cadente)
	_definir_noite(0.0)


func _ready() -> void:
	get_viewport().size_changed.connect(ajustar)
	ajustar()


## Troca sol <-> lua. suave = cruzamento com clarão; senão é imediato.
func mostrar(modo: String, suave: bool = true) -> void:
	if modo == _modo:
		return
	_modo = modo
	var alvo := 1.0 if modo == "lua" else 0.0
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if not suave:
		_definir_noite(alvo)
		return
	_pisco = 1.0
	_tw = create_tween()
	_tw.tween_method(_definir_noite, _noite, alvo, TEMPO_TROCA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ───────────────────────────────────────────── montagem
func _criar_fundo(tex: Texture2D, mascara: Texture2D, cor: Color, fase: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_FUNDO
	mat.set_shader_parameter("mascara", mascara)
	mat.set_shader_parameter("cor_energia", Vector3(cor.r, cor.g, cor.b))
	mat.set_shader_parameter("respiro", 0.0)   # quem respira é o nó inteiro
	mat.set_shader_parameter("ceu", 0.0)       # raios e disco são camadas
	mat.set_shader_parameter("fase", fase)
	s.material = mat
	add_child(s)
	return s


func _criar_raios(c: Vector2, r: float, alcance: float, lua: bool, cor: Color) -> ColorRect:
	var q := ColorRect.new()
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q.size = Vector2.ONE * r * alcance * 2.0
	q.position = c - q.size * 0.5
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_RAIOS
	mat.set_shader_parameter("lua", lua)
	mat.set_shader_parameter("cor", Vector3(cor.r, cor.g, cor.b))
	mat.set_shader_parameter("raio_disco", 1.0 / alcance)
	q.material = mat
	add_child(q)
	return q


func _criar_astro(tex: Array, dados: Dictionary, c: Vector2) -> Node2D:
	var astro := Node2D.new()
	astro.position = c
	astro.scale = Vector2.ONE / 3.0    # texturas em 3x
	astro.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # reduzida sem serrilhar
	add_child(astro)
	var olho: Vector2 = dados["olho"]
	var esclera := Sprite2D.new()
	esclera.texture = tex[1]
	esclera.position = olho
	astro.add_child(esclera)
	var iris := Sprite2D.new()
	iris.texture = tex[2]
	iris.position = olho + dados["iris"]
	astro.add_child(iris)
	var palpebra := Sprite2D.new()
	palpebra.texture = tex[3]
	palpebra.position = olho + Vector2(0.0, dados["palpebra_y"] + (tex[3] as Texture2D).get_height() * 0.5)
	astro.add_child(palpebra)
	var disco := Sprite2D.new()
	disco.texture = tex[0]
	astro.add_child(disco)
	_olhos.append({"disco": disco, "iris": iris, "palpebra": palpebra, "iris_0": iris.position,
		"palpebra_0": palpebra.position, "u": dados["u"], "abre": dados["abre"],
		"olhar": Vector2.ZERO, "alvo": Vector2.ZERO, "prox_olhar": randf_range(0.6, 1.5),
		"piscar": 0.0, "prox_piscar": randf_range(1.5, 3.5), "fase": -1.0, "dupla": false})
	return astro


# ───────────────────────────────────────────── águias
## Águias planando ao fundo: sobem em térmicas (círculos que o vento leva),
## planam de uma térmica a outra, batem as asas de vez em quando e inclinam
## nas curvas. Cada uma tem tamanho (distância), rapidez, raio, vento e
## turbulência próprios, sorteados de novo a cada volta: nenhum voo se repete.
## Chegam de longe crescendo e vão embora subindo. Gritam de vez em quando
## (de noite o grito vem de mais longe). Contra o sol ou a lua viram silhueta.
func _criar_aguias() -> void:
	for i in N_AGUIAS:
		var s := Sprite2D.new()
		s.texture = AGUIA
		s.hframes = AGUIA_QUADROS
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		s.visible = false
		add_child(s)
		_aguias.append({"no": s, "espera": 1.5 + i * randf_range(3.0, 6.0)})


func _nova_aguia(a: Dictionary) -> void:
	var e := randf_range(0.15, 0.33)
	a["escala"] = e
	a["vel"] = lerpf(24.0, 46.0, (e - 0.15) / 0.18) * randf_range(0.85, 1.15)
	a["pos"] = Vector2(randf_range(CEU.position.x + 90.0, CEU.end.x - 90.0), randf_range(CEU.position.y + 30.0, CEU.end.y - 40.0))
	a["dir"] = randf() * TAU
	a["t"] = 0.0
	a["vida"] = randf_range(26.0, 50.0)
	a["bat"] = randf_range(0.8, 1.6)
	a["fase"] = randf()
	a["inclin"] = 0.0
	a["grito"] = randf_range(3.0, 12.0)
	a["ruido"] = randf() * 100.0
	a["vento"] = Vector2(randf_range(-9.0, 9.0), randf_range(-3.0, 2.0))
	a["modo"] = "termica" if randf() < 0.6 else "plana"
	_entrar_modo(a)
	(a["no"] as Sprite2D).visible = true


func _entrar_modo(a: Dictionary) -> void:
	if a["modo"] == "termica":
		a["raio"] = randf_range(40.0, 105.0) * (a["escala"] / 0.25)
		a["sentido"] = 1.0 if randf() < 0.5 else -1.0
		var lado := Vector2.RIGHT.rotated(a["dir"] + PI * 0.5 * a["sentido"])
		a["centro"] = a["pos"] + lado * a["raio"]
		a["t_modo"] = randf_range(6.0, 15.0)
	else:
		var alvo := Vector2.ZERO
		for i in 6:
			alvo = Vector2(randf_range(CEU.position.x + 60.0, CEU.end.x - 60.0), randf_range(CEU.position.y + 20.0, CEU.end.y - 30.0))
			if _noite > 0.5 and randf() < 0.35:
				alvo = CENTRO_LUA + Vector2(randf_range(-60.0, 60.0), randf_range(-30.0, 40.0))   # passa na frente da lua
			if alvo.distance_to(a["pos"]) > 220.0:
				break
		a["alvo"] = alvo
		a["t_modo"] = randf_range(5.0, 11.0)
		a["bat"] = maxf(a["bat"], randf_range(0.7, 1.6))


func _animar_aguias(delta: float) -> void:
	_grito_espera -= delta
	for a in _aguias:
		var s: Sprite2D = a["no"]
		if a["espera"] > 0.0:
			a["espera"] -= delta
			if a["espera"] <= 0.0:
				_nova_aguia(a)
			continue
		a["t"] += delta
		a["t_modo"] -= delta
		var t: float = a["t"]
		var v: float = a["vel"]
		var giro := 0.0
		if a["modo"] == "termica":
			a["centro"] += a["vento"] * delta
			var para_centro: Vector2 = a["centro"] - a["pos"]
			var r := maxf(para_centro.length(), 0.01)
			var tang := para_centro.rotated(-PI * 0.5 * a["sentido"]) / r
			var desejo := (tang + para_centro / r * clampf((r - a["raio"]) / a["raio"], -1.0, 1.0) * 0.8).angle()
			giro = angle_difference(a["dir"], desejo) * 1.8
			v *= 0.9
			# a térmica saiu do céu: plana de volta
			if not CEU.has_point(a["centro"]):
				a["t_modo"] = 0.0
		else:
			var desejo2: float = (a["alvo"] - a["pos"]).angle()
			giro = angle_difference(a["dir"], desejo2) * 0.9
			v *= 1.15
			if (a["pos"] as Vector2).distance_to(a["alvo"]) < 50.0:
				a["t_modo"] = 0.0
		if a["t_modo"] <= 0.0:
			a["modo"] = "plana" if a["modo"] == "termica" else "termica"
			_entrar_modo(a)
		# turbulência suave (cada águia com a sua)
		var rr: float = a["ruido"]
		giro += sin(t * 0.73 + rr) * 0.11 + sin(t * 1.91 + rr * 2.3) * 0.05
		giro = clampf(giro, -0.95, 0.95)
		a["dir"] += giro * delta
		a["inclin"] = lerpf(a["inclin"], giro * 0.6, 1.0 - exp(-delta * 2.5))
		a["pos"] += Vector2.RIGHT.rotated(a["dir"]) * v * delta + Vector2(0.0, sin(t * 1.3 + rr) * 3.0 * delta)

		# asas: batidas de vez em quando, senão planando
		if a["bat"] > 0.0:
			a["bat"] -= delta
			a["fase"] += delta * 2.3
			s.frame = 1 + int(a["fase"] * 10.0) % 10
		else:
			s.frame = 0
			if randf() < delta * 0.06:
				a["bat"] = randf_range(0.7, 1.5)

		# chega de longe e vai embora subindo (fica menor)
		var chega := clampf(t / 2.8, 0.0, 1.0)
		var vai := clampf((a["vida"] - t) / 3.0, 0.0, 1.0)
		var perto := chega * chega * (3.0 - 2.0 * chega) * vai
		if t > a["vida"]:
			s.visible = false
			a["espera"] = randf_range(2.0, 9.0)
			continue
		var esc: float = a["escala"] * (0.25 + 0.75 * perto)
		var inc: float = a["inclin"]
		s.position = a["pos"]
		s.rotation = a["dir"] + PI * 0.5
		s.scale = Vector2(esc * (1.0 - 0.35 * absf(inc)), esc)
		s.skew = inc * 0.45

		# luz: contra o sol/a lua vira silhueta; longe some na névoa do céu
		var astro := CENTRO_SOL.lerp(CENTRO_LUA, _noite)
		var raio_astro := lerpf(RAIO_SOL, RAIO_LUA, _noite)
		var contra := clampf(1.0 - ((a["pos"] as Vector2).distance_to(astro) - raio_astro * 0.9) / (raio_astro * 0.6), 0.0, 1.0)
		var dia := Color(1.0, 0.93, 0.84).lerp(Color(0.16, 0.10, 0.06), contra)
		var noite := Color(0.24, 0.28, 0.40).lerp(Color(0.03, 0.04, 0.08), contra)
		var cor := dia.lerp(noite, _noite)
		var nevoa: float = (1.0 - (a["escala"] - 0.15) / 0.18) * 0.35 * (1.0 - contra)
		cor = cor.lerp(Color(1.0, 0.78, 0.48).lerp(Color(0.22, 0.30, 0.48), _noite), nevoa)
		cor.a = perto
		s.modulate = cor

		# grito (um de cada vez, de tempos em tempos)
		a["grito"] -= delta
		if a["grito"] <= 0.0 and perto > 0.95:
			a["grito"] = randf_range(9.0, 22.0)
			if _grito_espera <= 0.0 and is_visible_in_tree():
				_grito_espera = 6.0
				var forca: float = (a["escala"] - 0.15) / 0.18
				var noite_som := _noite > 0.5
				Maquina.efeito(SOM_AGUIA_NOITE if noite_som else SOM_AGUIA,
					lerpf(-17.0, -8.0, forca) - (2.0 if noite_som else 0.0), randf_range(0.92, 1.08))


func _sprite_2x(tex: Texture2D, canto: Vector2, shader: Shader) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = canto
	s.scale = Vector2(0.5, 0.5)
	var mat := ShaderMaterial.new()
	mat.shader = shader
	s.material = mat
	add_child(s)
	return s


func _criar_particulas() -> void:
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	rampa.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var ponto := FundoVivo.brilho_redondo()

	# faíscas de energia subindo do diamante
	var f := CPUParticles2D.new()
	f.name = "FaiscasEnergia"
	f.amount = 34
	f.lifetime = 2.8
	f.preprocess = 2.8
	f.position = Vector2(508, 800)
	f.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	f.emission_sphere_radius = 60.0
	f.direction = Vector2(0, -1)
	f.spread = 40.0
	f.gravity = Vector2(0, -16)
	f.initial_velocity_min = 34.0
	f.initial_velocity_max = 100.0
	f.scale_amount_min = 0.35
	f.scale_amount_max = 0.95
	f.texture = ponto
	f.color_ramp = rampa
	f.material = soma
	add_child(f)
	_faiscas = f

	# poeira de areia atravessando devagar
	var p := CPUParticles2D.new()
	p.name = "Poeira"
	p.amount = 22
	p.lifetime = 11.0
	p.preprocess = 11.0
	p.position = Vector2(-20, 1000)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(20, 420)
	p.direction = Vector2(1, -0.12)
	p.spread = 10.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 16.0
	p.initial_velocity_max = 40.0
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.42
	p.texture = ponto
	p.color_ramp = rampa
	p.material = soma
	add_child(p)
	_poeira = p


func _criar_brilho(pos: Vector2, mat: Material, escala: float, tipo: String) -> void:
	var s := Sprite2D.new()
	s.texture = ESTRELA
	s.material = mat
	s.position = pos
	s.visible = false
	add_child(s)
	_brilhos.append({"no": s, "tipo": tipo, "escala": escala, "espera": randf_range(0.2, 3.0), "t": 0.0, "dur": 0.7})


func _criar_estrelas_ceu(mat: Material) -> void:
	var feitas := 0
	var tentativas := 0
	while feitas < N_ESTRELAS_CEU and tentativas < 400:
		tentativas += 1
		var p := Vector2(randf_range(40.0, 984.0), randf_range(40.0, 420.0))
		if p.distance_to(CENTRO_LUA) < RAIO_LUA + 60.0:
			continue
		var s := Sprite2D.new()
		s.texture = ESTRELA
		s.material = mat
		s.position = p
		s.scale = Vector2.ONE * randf_range(0.10, 0.22)
		s.rotation = randf() * 0.6
		_ceu_noite.add_child(s)
		_estrelas.append({"no": s, "w": randf_range(1.2, 3.4), "f": randf() * TAU})
		feitas += 1


## Cobre a tela inteira com a imagem (corta as sobras), como antes.
func ajustar() -> void:
	_aplicar_camera()


func _aplicar_camera() -> void:
	var tela := get_viewport_rect().size
	var esc := maxf(tela.x / IMG.x, tela.y / IMG.y)
	# sem zoom: só cobre a tela (âncora no alto: o sol não entra no placar)
	scale = Vector2.ONE * esc
	position = Vector2((tela.x - IMG.x * esc) * 0.5, minf(0.0, (tela.y - IMG.y * esc) * 0.5))


# ───────────────────────────────────────────── animação
func _definir_noite(v: float) -> void:
	_noite = clampf(v, 0.0, 1.0)
	var dia := 1.0 - _noite
	_fundo_lua.visible = _noite > 0.001
	_fundo_lua.modulate.a = _noite
	_fundo_sol.visible = _noite < 0.999
	for par in [[_raios_sol, dia], [_raios_lua, _noite], [_disco_sol, dia], [_disco_lua, _noite]]:
		var no: CanvasItem = par[0]
		no.visible = par[1] > 0.001
		no.modulate.a = par[1]
	(_pontas.material as ShaderMaterial).set_shader_parameter("noite", _noite)
	(_cristal.material as ShaderMaterial).set_shader_parameter("noite", _noite)
	_ceu_noite.visible = _noite > 0.01
	_faiscas.color = Color(1.0, 0.80, 0.42).lerp(Color(1.0, 0.42, 0.40), _noite)
	_poeira.color = Color(1.0, 0.86, 0.6, 0.55).lerp(Color(0.75, 0.85, 1.0, 0.45), _noite)


func _process(delta: float) -> void:
	_t += delta
	var som := Maquina.pulso_vivo()
	if som.y > 0.55 and _onda > 0.62:
		_onda = 0.0
	_onda = minf(_onda + delta * 0.85, 9.0)

	# "pisco" do disco de tempos em tempos (e o clarão da troca)
	_proximo_pisco -= delta
	if _proximo_pisco <= 0.0:
		_proximo_pisco = randf_range(5.0, 9.0)
		_pisco = maxf(_pisco, 0.45)
	_pisco = move_toward(_pisco, 0.0, delta * 1.1)

	for fundo: Sprite2D in [_fundo_sol, _fundo_lua]:
		if fundo.visible:
			var mf := fundo.material as ShaderMaterial
			mf.set_shader_parameter("grave", som.x)
			mf.set_shader_parameter("batida", som.y)
			mf.set_shader_parameter("onda", _onda)
	for no: CanvasItem in [_raios_sol, _raios_lua]:
		if no.visible:
			var m := no.material as ShaderMaterial
			m.set_shader_parameter("grave", som.x)
			m.set_shader_parameter("batida", som.y)
			m.set_shader_parameter("pisco", _pisco)
	# o astro clareia no "pisco" e com a batida (só a cor, sem shader)
	var luz := 1.0 + 0.30 * _pisco + 0.06 * som.y
	for o in _olhos:
		(o["disco"] as Sprite2D).self_modulate = Color(luz, luz, luz, 1.0)
	for no: CanvasItem in [_pontas, _cristal]:
		var m2 := no.material as ShaderMaterial
		m2.set_shader_parameter("grave", som.x)
		m2.set_shader_parameter("batida", som.y)
	_faiscas.speed_scale = 1.0 + som.y * 1.3

	_animar_olhos(delta)
	_animar_aguias(delta)
	_animar_brilhos(delta)
	if _noite > 0.01:
		_animar_ceu(delta)


## Olho vivo: a pupila salta de um ponto a outro (como um olho de verdade,
## rápido e para) e a pálpebra pisca de tempos em tempos, às vezes duas vezes.
func _animar_olhos(delta: float) -> void:
	for i in _olhos.size():
		var o: Dictionary = _olhos[i]
		var visivel: bool = (_disco_sol if i == 0 else _disco_lua).visible
		if not visivel:
			continue
		var u: float = o["u"]
		o["prox_olhar"] -= delta
		if o["prox_olhar"] <= 0.0:
			o["prox_olhar"] = randf_range(0.7, 2.2)
			var escolhas := [Vector2(0, 0), Vector2(-0.30, 0.0), Vector2(0.30, 0.0), Vector2(-0.22, -0.04),
				Vector2(0.22, -0.04), Vector2(-0.18, 0.04), Vector2(0.18, 0.04), Vector2(0.0, -0.04)]
			o["alvo"] = escolhas[randi() % escolhas.size()] * u
		var olhar: Vector2 = o["olhar"]
		olhar = olhar.lerp(o["alvo"], 1.0 - exp(-delta * 18.0))
		o["olhar"] = olhar

		var p: float = o["piscar"]
		if o["fase"] < 0.0:
			o["prox_piscar"] -= delta
			if o["prox_piscar"] <= 0.0:
				o["fase"] = 0.0
		else:
			o["fase"] += delta
			var f: float = o["fase"]
			# fecha em 0,08 s, fica 0,05 s, abre em 0,12 s
			if f < 0.08:
				p = f / 0.08
			elif f < 0.13:
				p = 1.0
			elif f < 0.25:
				p = 1.0 - (f - 0.13) / 0.12
			else:
				p = 0.0
				o["fase"] = -1.0
				if not o["dupla"] and randf() < 0.25:
					o["dupla"] = true
					o["prox_piscar"] = 0.12
				else:
					o["dupla"] = false
					o["prox_piscar"] = randf_range(2.5, 5.5)
		o["piscar"] = p
		(o["iris"] as Sprite2D).position = o["iris_0"] + olhar
		var fecha: float = p * p * (3.0 - 2.0 * p)
		(o["palpebra"] as Sprite2D).position = o["palpebra_0"] + Vector2(0.0, fecha * (o["abre"] + 0.03 * u))


func _animar_brilhos(delta: float) -> void:
	for b in _brilhos:
		var s: Sprite2D = b["no"]
		if b["espera"] > 0.0:
			b["espera"] -= delta
			if b["espera"] <= 0.0:
				b["t"] = 0.0
				b["dur"] = randf_range(0.55, 0.95)
				s.rotation = randf_range(-0.3, 0.3)
				s.visible = true
			continue
		b["t"] += delta
		var k: float = b["t"] / b["dur"]
		if k >= 1.0:
			s.visible = false
			b["espera"] = randf_range(1.0, 4.0) if b["tipo"] != "disco" else randf_range(4.0, 8.0)
			continue
		var env := sin(PI * k)
		env *= env
		var cor: Color
		match b["tipo"]:
			"cristal":
				cor = Color.from_hsv(fmod(_t * 0.13 + s.position.y * 0.004, 1.0), 0.35, 1.0).lerp(Color(1.0, 0.40, 0.52), _noite)
			"ponta":
				cor = Color(1.0, 0.90, 0.62).lerp(Color(0.74, 0.88, 1.0), _noite)
			_:
				cor = Color(1.0, 0.95, 0.75).lerp(Color(0.85, 0.93, 1.0), _noite)
				s.position = (CENTRO_SOL + Vector2(-0.62, -0.66) * RAIO_SOL).lerp(CENTRO_LUA + Vector2(-0.62, -0.66) * RAIO_LUA, _noite)
		cor.a = env
		s.modulate = cor
		s.scale = Vector2.ONE * b["escala"] * (0.35 + 0.65 * env)
		s.rotation += delta * 0.6


func _animar_ceu(delta: float) -> void:
	for e in _estrelas:
		var s: Sprite2D = e["no"]
		var c := 0.5 + 0.5 * sin(_t * e["w"] + e["f"])
		s.modulate.a = _noite * (0.25 + 0.75 * c * c * c)

	# estrela cadente de vez em quando
	if _cadente_t < 0.0:
		_cadente_em -= delta
		if _cadente_em <= 0.0:
			_cadente_t = 0.0
			_cadente_de = Vector2(randf_range(120.0, 900.0), randf_range(60.0, 200.0))
			var dir := Vector2(-1.0 if _cadente_de.x > 512.0 else 1.0, 0.45).normalized()
			_cadente_para = _cadente_de + dir * randf_range(260.0, 380.0)
			_cadente.rotation = dir.angle()
			_cadente.visible = true
		return
	_cadente_t += delta
	var k := _cadente_t / 0.85
	if k >= 1.0:
		_cadente.visible = false
		_cadente_t = -1.0
		_cadente_em = randf_range(7.0, 14.0)
		return
	_cadente.position = _cadente_de.lerp(_cadente_para, k)
	_cadente.scale = Vector2(1.6 + 1.2 * sin(PI * k), 0.10)
	_cadente.modulate = Color(0.85, 0.93, 1.0, _noite * sin(PI * k))
