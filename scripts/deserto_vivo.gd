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
##   disco               sol com olho masculino (Rá, íris dourada) / lua com
##                       olho feminino (Hórus, íris branca e cílios), em 2x
##                       (nítidos em 4K), gravados em relevo; o olho é vivo:
##                       pisca e a pupila passeia (egito_disco.gdshader)
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
const DISCO_SOL := preload("res://sprites/egito_disco_sol.png")
const DISCO_LUA := preload("res://sprites/egito_disco_lua.png")
const OLHO_SOL := preload("res://sprites/egito_olho_sol.png")
const OLHO_LUA := preload("res://sprites/egito_olho_lua.png")
const PONTAS := preload("res://sprites/egito_pontas.png")
const CRISTAL := preload("res://sprites/egito_cristal_mascara.png")
const ESTRELA := preload("res://sprites/egito_estrela.png")
const SHADER_FUNDO := preload("res://shaders/deserto_fundo.gdshader")
const SHADER_RAIOS := preload("res://shaders/egito_raios.gdshader")
const SHADER_DISCO := preload("res://shaders/egito_disco.gdshader")
const SHADER_PONTAS := preload("res://shaders/egito_pontas.gdshader")
const SHADER_CRISTAL := preload("res://shaders/egito_cristal.gdshader")

# Mesmos números de tools/gerar_egito.py.
const CENTRO_SOL := Vector2(512, 290)
const RAIO_SOL := 124.0
const CENTRO_LUA := Vector2(510, 282)
const RAIO_LUA := 130.0
const PONTAS_CAIXA := Rect2(180, 438, 644, 148)

# Olho no disco 2x (UV da textura), de tools/gerar_egito.py: centro da pupila,
# raio da íris, tamanho de 1 unidade do olho e raio do disco.
# Sol: olho masculino (olhar intenso); lua: olho feminino (cílios, gatinho).
const OLHO_RA := {"iris": Vector2(0.5268, 0.4244), "raio": 0.0587, "unidade": 0.2667, "disco": 0.3605}
const OLHO_HORUS := {"iris": Vector2(0.4718, 0.4432), "raio": 0.0699, "unidade": 0.2797, "disco": 0.3779}
const CRISTAL_CAIXA := Rect2(440, 620, 136, 340)

const COR_SOL := Color(1.0, 0.78, 0.36)
const COR_LUA := Color(0.62, 0.80, 1.0)

const BRILHOS_CRISTAL := [Vector2(506, 634), Vector2(466, 721), Vector2(548, 721), Vector2(486, 792),
		Vector2(527, 846), Vector2(505, 893), Vector2(461, 944), Vector2(551, 944)]
const BRILHOS_PONTAS := [Vector2(229, 520), Vector2(509, 448), Vector2(774, 520)]
const TEMPO_TROCA := 1.6
const N_ESTRELAS_CEU := 18

var _fundo_sol: Sprite2D
var _fundo_lua: Sprite2D
var _raios_sol: ColorRect
var _raios_lua: ColorRect
var _disco_sol: Sprite2D
var _disco_lua: Sprite2D
# olho vivo de cada disco: {mat, unidade, olhar, alvo, prox_olhar, piscar, prox_piscar, fase_piscar, dupla}
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


func _init() -> void:
	name = "DesertoVivo"
	_fundo_sol = _criar_fundo(FUNDO_SOL, MASCARA_SOL, Color(1.0, 0.74, 0.34), 0.0)
	_fundo_lua = _criar_fundo(FUNDO_LUA, MASCARA_LUA, Color(1.0, 0.28, 0.30), 3.7)
	_raios_sol = _criar_raios(CENTRO_SOL, RAIO_SOL, 3.1, false, COR_SOL)
	_raios_lua = _criar_raios(CENTRO_LUA, RAIO_LUA, 2.7, true, COR_LUA)
	_disco_sol = _criar_disco(DISCO_SOL, OLHO_SOL, OLHO_RA, CENTRO_SOL, false, Color(1.0, 0.92, 0.62))
	_disco_lua = _criar_disco(DISCO_LUA, OLHO_LUA, OLHO_HORUS, CENTRO_LUA, true, Color(0.72, 0.86, 1.0))

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


func _criar_disco(tex: Texture2D, mapa_olho: Texture2D, dados: Dictionary, c: Vector2, lua: bool, cor: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = c
	s.scale = Vector2(0.5, 0.5)    # textura em 2x
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_DISCO
	mat.set_shader_parameter("olho", mapa_olho)
	mat.set_shader_parameter("lua", lua)
	mat.set_shader_parameter("cor_luz", Vector3(cor.r, cor.g, cor.b))
	mat.set_shader_parameter("raio_uv", dados["disco"])
	mat.set_shader_parameter("iris_c", dados["iris"])
	mat.set_shader_parameter("iris_r", dados["raio"])
	if lua:
		# Hórus: traços de prata escura em relevo, íris branca (prata) na lua;
		# a íris dourada fica só no sol (Rá)
		mat.set_shader_parameter("traco_sombra", Vector3(0.04, 0.05, 0.10))
		mat.set_shader_parameter("traco_luz", Vector3(0.40, 0.48, 0.66))
		mat.set_shader_parameter("cor_branco", Vector3(0.80, 0.86, 0.95))
		mat.set_shader_parameter("iris_centro", Vector3(1.0, 1.0, 1.0))
		mat.set_shader_parameter("iris_borda", Vector3(0.66, 0.74, 0.88))
		mat.set_shader_parameter("cor_palpebra", Vector3(0.62, 0.68, 0.80))
	s.material = mat
	add_child(s)
	_olhos.append({"mat": mat, "unidade": dados["unidade"], "olhar": Vector2.ZERO, "alvo": Vector2.ZERO,
		"prox_olhar": randf_range(0.6, 1.5), "piscar": 0.0, "prox_piscar": randf_range(1.5, 3.5), "fase": -1.0, "dupla": false})
	return s


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
	for no: CanvasItem in [_raios_sol, _raios_lua, _disco_sol, _disco_lua]:
		if no.visible:
			var m := no.material as ShaderMaterial
			m.set_shader_parameter("grave", som.x)
			m.set_shader_parameter("batida", som.y)
			m.set_shader_parameter("pisco", _pisco)
	for no: CanvasItem in [_pontas, _cristal]:
		var m2 := no.material as ShaderMaterial
		m2.set_shader_parameter("grave", som.x)
		m2.set_shader_parameter("batida", som.y)
	_faiscas.speed_scale = 1.0 + som.y * 1.3

	_animar_olhos(delta)
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
		var u: float = o["unidade"]
		o["prox_olhar"] -= delta
		if o["prox_olhar"] <= 0.0:
			o["prox_olhar"] = randf_range(0.7, 2.2)
			var escolhas := [Vector2(0, 0), Vector2(-0.30, 0.0), Vector2(0.30, 0.0), Vector2(-0.22, -0.05),
				Vector2(0.22, -0.05), Vector2(-0.18, 0.05), Vector2(0.18, 0.05), Vector2(0.0, -0.05)]
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
		var mat: ShaderMaterial = o["mat"]
		mat.set_shader_parameter("olhar", olhar)
		mat.set_shader_parameter("piscar", p * p * (3.0 - 2.0 * p))


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
