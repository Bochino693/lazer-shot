extends Control

## ABERTURA LAZER & SPORT GAMES (a primeira tela do jogo).
##
## Estande de tiro no escuro: três placas-alvo sobem na parede, a mira entra
## e o laser derruba uma a uma (a placa gira e cai, faíscas, furo em brasa
## esfriando na parede), a mira trava no centro,
## carrega e o tiro final acerta o alvo: clarão branco, onda de choque, tela
## tremendo e o logo da Lazer & Sport aparece, com GAMES batendo embaixo
## e "apresenta" logo depois.
## Depois vai para o menu. Qualquer tiro ou START pula.
## Tudo desenhado na hora; a única imagem é o logo.
##
## Antes do primeiro quadro, com a tela preta, a placa de vídeo prepara cada
## jeito de desenhar que a apresentação e os efeitos do jogo usam, os dois
## shaders daqui e os sons, um passo por quadro (scripts/aquecedor.gd). Na
## TV Box a apresentação caía no primeiro tiro, quando a placa montava a luz
## somada e as faíscas no meio da animação.

const Pincel := preload("res://scripts/pincel.gd")
const LOGO := preload("res://sprites/logo_lazer_sport.png")
const SHADER_FUNDO := preload("res://shaders/abertura_fundo.gdshader")
const SHADER_LOGO := preload("res://shaders/abertura_logo.gdshader")
const FONTE := preload("res://fonts/Exo2-ExtraBold.ttf")
const SOM_TIRO := preload("res://songs/tiro_menu.wav")   # laser (a pistola é do Bar)
const SOM_IMPACTO := preload("res://songs/plasma-hit.wav")
const SOM_CARGA := preload("res://songs/lazer-charge.wav")
const SOM_FINAL := preload("res://songs/xploit.wav")
const SOM_ALVO := preload("res://songs/alvo_crash.wav")
const PROXIMA := "res://scenes/main.tscn"

const ALVO_NO_LOGO := Vector2(378, 168)   # centro do alvo dentro do logo (px da imagem)
const VERMELHO := Color(1.0, 0.16, 0.20)
const FIM := 5.9

var _t := 0.0
var _saindo := false
var _tela := Vector2.ZERO
var _fundo: ColorRect
var _logo: TextureRect
var _games: Label
var _apresenta: Label
var _marcas: Node2D       # furos na parede (mistura normal)
var _luz: Node2D          # feixes, clarões, mira e onda (mistura somada)
var _faiscas: Array[CPUParticles2D] = []
var _faisca_vez := 0
var _estouro: CPUParticles2D
var _brasas: CPUParticles2D
var _clarao: ColorRect
var _escuro: ColorRect

var _origem := Vector2.ZERO        # de onde sai o laser (a arma, embaixo)
var _alvo := Vector2.ZERO          # centro do alvo do logo, na tela
var _mira := Vector2.ZERO
var _mira_alvo := Vector2.ZERO
var _mira_vis := 0.0
var _carga := 0.0
var _carregando := false
var _furos: Array = []             # {pos, t, raios}
var _placas: Array = []            # {pos, r, t, caiu, vel, giro, vira}
var _disparos: Array = []          # {de, para, t, vida, forte}
var _impactos: Array = []          # {pos, t, vida, forte}
var _onda_t := -1.0
var _tremor := 0.0
var _logo_t := -1.0
var _games_t := -1.0
var _apresenta_t := -1.0
var _roteiro: Array = []           # [tempo, Callable], em ordem
var _aquecedor: Aquecedor = null   # preparando a placa: a apresentação espera
var _barra: Control                # andamento da preparação (só traços)
static var _marcou := false        # caixa-preta: cada passo, só na 1ª vez


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela = get_viewport_rect().size
	_montar()
	_ajustar()
	get_viewport().size_changed.connect(_ajustar)
	var p1 := Vector2(_tela.x * 0.22, _tela.y * 0.30)
	var p2 := Vector2(_tela.x * 0.79, _tela.y * 0.35)
	var p3 := Vector2(_tela.x * 0.33, _tela.y * 0.56)
	_mira = Vector2(_tela.x * 0.92, _tela.y * 0.88)
	_mira_alvo = _mira
	for i in 3:
		var pp: Vector2 = [p1, p2, p3][i]
		_placas.append({"pos": pp, "r": 54.0, "t": -0.12 - i * 0.16, "caiu": -1.0,
			"vel": Vector2.ZERO, "giro": 0.0, "vira": 0.0})
	_roteiro = [
		[0.35, func() -> void: _mira_alvo = p1],
		[1.10, func() -> void: _disparar(p1, false)],
		[1.30, func() -> void: _mira_alvo = p2],
		[1.62, func() -> void: _disparar(p2, false)],
		[1.82, func() -> void: _mira_alvo = p3],
		[2.12, func() -> void: _disparar(p3, false)],
		[2.36, func() -> void: _comecar_carga()],
		[3.12, func() -> void: _tiro_final()],
		[3.58, func() -> void: _bater_games()],
		[4.25, func() -> void: _apresenta_t = 0.0],
	]
	# Com a tela preta: os jeitos de desenhar (luz somada, linhas, polígonos,
	# faíscas, letras), os dois shaders e os sons daqui, um por quadro. Os
	# shaders de cada fase ficam para a troca de tela, com o cartão de
	# carregamento à vista (scripts/TransiaoGlobal.gd).
	_fundo.visible = false
	_aquecedor = Aquecedor.shaders([SHADER_FUNDO.resource_path, SHADER_LOGO.resource_path], self,
		[SOM_TIRO, SOM_IMPACTO, SOM_CARGA, SOM_FINAL, SOM_ALVO])
	_aquecedor.terminou.connect(_comecar)


## A placa está pronta: a apresentação começa.
func _comecar() -> void:
	_aquecedor = null
	_fundo.visible = true
	if not Tela.contorna("abertura"):
		Tela.risco("abertura")   # se o app morrer aqui, a caixa-preta sabe
	var tw := create_tween()
	tw.tween_property(_escuro, "color:a", 0.0, 0.6)
	tw.parallel().tween_property(_barra, "modulate:a", 0.0, 0.3)
	tw.tween_callback(_barra.queue_free)


## Andamento da preparação, embaixo, na tela preta: um traço por passo.
## Aceso = pronto; vermelho = esse passo derrubou o app antes e agora fica
## desligado. Sem texto: se a TV Box parar aqui, uma foto mostra onde.
func _desenhar_barra() -> void:
	if _aquecedor == null or not is_instance_valid(_aquecedor):
		return
	var lista := _aquecedor.passos()
	var n := lista.size()
	if n == 0:
		return
	var larg := 26.0
	var vao := 10.0
	var total := n * larg + (n - 1) * vao
	var x := (_tela.x - total) * 0.5
	var y := _tela.y * 0.86
	for item in lista:
		var cor := Color(1, 1, 1, 0.12)
		match item[1]:
			"ok":
				cor = Color(1, 1, 1, 0.75)
			"agora":
				cor = Color(1, 1, 1, 0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.012))
			"pulado":
				cor = Color(1.0, 0.18, 0.2, 0.9)
		_barra.draw_rect(Rect2(x, y, larg, 6.0), cor)
		x += larg + vao


func _montar() -> void:
	_fundo = ColorRect.new()
	var mf := ShaderMaterial.new()
	mf.shader = SHADER_FUNDO
	_fundo.material = mf
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fundo)

	_marcas = Node2D.new()
	_marcas.draw.connect(_desenhar_marcas)
	add_child(_marcas)

	_logo = TextureRect.new()
	_logo.texture = LOGO
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ml := ShaderMaterial.new()
	ml.shader = SHADER_LOGO
	_logo.material = ml
	_logo.visible = false
	add_child(_logo)

	_games = Label.new()
	_games.text = "GAMES"
	_games.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_games.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var fv := FontVariation.new()
	fv.base_font = FONTE
	fv.spacing_glyph = 22
	var ls := LabelSettings.new()
	ls.font = fv
	ls.font_size = 132
	ls.font_color = VERMELHO
	ls.outline_size = 16
	ls.outline_color = Color(1, 1, 1)
	ls.shadow_size = 18
	ls.shadow_color = Color(0, 0, 0, 0.75)
	ls.shadow_offset = Vector2(0, 8)
	_games.label_settings = ls
	_games.visible = false
	_games.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_games)

	_apresenta = Label.new()
	_apresenta.text = "apresenta"
	_apresenta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var fa := FontVariation.new()
	fa.base_font = FONTE
	fa.spacing_glyph = 16
	var la := LabelSettings.new()
	la.font = fa
	la.font_size = 46
	la.font_color = Color(1, 0.93, 0.93)
	la.shadow_size = 10
	la.shadow_color = Color(0, 0, 0, 0.7)
	_apresenta.label_settings = la
	_apresenta.modulate.a = 0.0
	_apresenta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_apresenta)

	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_luz = Node2D.new()
	_luz.material = soma
	_luz.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_luz.draw.connect(_desenhar_luz)
	add_child(_luz)

	var ponto := FundoVivo.brilho_redondo()
	var quente := Gradient.new()
	quente.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	quente.colors = PackedColorArray([Color(1.0, 0.95, 0.7, 1), Color(1.0, 0.55, 0.15, 1), Color(1.0, 0.15, 0.05, 0)])
	for i in 2:
		var f := _particulas(26, 0.6, ponto, soma, quente)
		f.initial_velocity_min = 220.0
		f.initial_velocity_max = 640.0
		f.gravity = Vector2(0, 1200)
		f.scale_amount_min = 0.18
		f.scale_amount_max = 0.45
		_faiscas.append(f)
	_estouro = _particulas(70, 1.1, ponto, soma, quente)
	_estouro.initial_velocity_min = 300.0
	_estouro.initial_velocity_max = 1100.0
	_estouro.gravity = Vector2(0, 900)
	_estouro.scale_amount_min = 0.25
	_estouro.scale_amount_max = 0.8
	_brasas = _particulas(30, 3.2, ponto, soma, quente)
	_brasas.one_shot = false
	_brasas.explosiveness = 0.0
	_brasas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_brasas.direction = Vector2(0, -1)
	_brasas.spread = 25.0
	_brasas.gravity = Vector2(0, -35)
	_brasas.initial_velocity_min = 20.0
	_brasas.initial_velocity_max = 70.0
	_brasas.scale_amount_min = 0.08
	_brasas.scale_amount_max = 0.24

	_clarao = ColorRect.new()
	_clarao.color = Color(1, 1, 1, 0)
	_clarao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clarao)
	_escuro = ColorRect.new()
	_escuro.color = Color(0, 0, 0, 1)
	_escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_escuro)
	_barra = Control.new()
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.draw.connect(_desenhar_barra)
	add_child(_barra)


func _particulas(n: int, vida: float, tex: Texture2D, mat: Material, rampa: Gradient) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = n
	p.lifetime = vida
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.spread = 180.0
	p.texture = tex
	p.material = mat
	p.color_ramp = rampa
	add_child(p)
	return p


func _ajustar() -> void:
	_tela = get_viewport_rect().size
	for r: Control in [_fundo, _clarao, _escuro, _barra]:
		r.position = Vector2.ZERO
		r.size = _tela
	var larg := _tela.x * 0.80
	var alt := larg * LOGO.get_height() / LOGO.get_width()
	_logo.size = Vector2(larg, alt)
	_logo.pivot_offset = _logo.size * 0.5
	_logo.position = Vector2((_tela.x - larg) * 0.5, _tela.y * 0.42 - alt * 0.5)
	_alvo = _logo.position + ALVO_NO_LOGO * (larg / LOGO.get_width())
	_games.size = Vector2(_tela.x, 170)
	_games.pivot_offset = _games.size * 0.5
	_games.position = Vector2(0, _logo.position.y + alt + 20)
	_apresenta.size = Vector2(_tela.x, 70)
	_apresenta.position = Vector2(0, _games.position.y + 175)
	_origem = Vector2(_tela.x * 0.84, _tela.y + 70)
	_brasas.position = Vector2(_tela.x * 0.5, _logo.position.y + alt)
	_brasas.emission_rect_extents = Vector2(larg * 0.5, 10)
	(_fundo.material as ShaderMaterial).set_shader_parameter("foco", Vector2(0.5, 0.42))


# ───────────────────────────────────────────── roteiro
func _disparar(p: Vector2, forte: bool) -> void:
	_disparos.append({"de": _origem, "para": p, "t": 0.0, "vida": 0.32 if forte else 0.15, "forte": forte})
	_impactos.append({"pos": p, "t": 0.0, "vida": 0.7 if forte else 0.26, "forte": forte})
	if not forte:
		var raios := PackedVector2Array()
		for i in randi_range(5, 7):
			raios.append(Vector2.RIGHT.rotated(randf() * TAU) * randf_range(16.0, 42.0))
		_furos.append({"pos": p, "t": 0.0, "raios": raios})
		for pl in _placas:
			if pl["caiu"] < 0.0 and (pl["pos"] as Vector2).distance_to(p) < pl["r"]:
				pl["caiu"] = 0.0
				pl["vel"] = Vector2(randf_range(-160.0, 160.0), randf_range(-420.0, -300.0))
				pl["giro"] = randf_range(-7.0, 7.0)
		var f := _faiscas[_faisca_vez]
		_faisca_vez = (_faisca_vez + 1) % _faiscas.size()
		f.position = p
		f.restart()
		f.emitting = true
		_tremor = maxf(_tremor, 7.0)
		Maquina.efeito(SOM_TIRO, -2.0, randf_range(0.95, 1.05))
		Maquina.efeito(SOM_IMPACTO, -6.0, randf_range(0.9, 1.1))


func _comecar_carga() -> void:
	_mira_alvo = _alvo
	_carregando = true
	Maquina.efeito(SOM_CARGA, -3.0)


func _tiro_final() -> void:
	_carregando = false
	_carga = 0.0
	_disparar(_alvo, true)
	_onda_t = 0.0
	_tremor = 22.0
	_clarao.color.a = 0.9
	_estouro.position = _alvo
	_estouro.restart()
	_estouro.emitting = true
	_logo.visible = true
	_logo_t = 0.0
	_brasas.emitting = true
	Maquina.efeito(SOM_FINAL, 0.0)
	Maquina.efeito(SOM_ALVO, -3.0, 0.85)


func _bater_games() -> void:
	_games.visible = true
	_games_t = 0.0
	_tremor = maxf(_tremor, 9.0)
	Maquina.efeito(SOM_IMPACTO, -2.0, 0.7)


func _sair() -> void:
	if _saindo:
		return
	_saindo = true
	Tela.risco("")
	TransicaoGlobal.trocar_cena(PROXIMA, 0.45)


func _input(event: InputEvent) -> void:
	if _t < 0.6 or _saindo:
		return
	var pula := event.is_action_pressed("input_shot") or event.is_action_pressed("input_start")
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		pula = true
	if pula:
		get_viewport().set_input_as_handled()
		_sair()


# ───────────────────────────────────────────── quadro a quadro
func _process(delta: float) -> void:
	if _aquecedor != null:
		_barra.queue_redraw()
		return   # a placa ainda está sendo preparada (tela preta)
	# um quadro pode demorar: o roteiro não pula
	delta = minf(delta, 0.05)
	_t += delta
	while not _roteiro.is_empty() and _t >= _roteiro[0][0]:
		var passo: Array = _roteiro.pop_front()
		if not _marcou:
			Tela.marca_quadro("apresentação %.2f s" % passo[0])
		(passo[1] as Callable).call()
	if _roteiro.is_empty():
		_marcou = true
	if _t >= FIM:
		_sair()

	# mira: segue o alvo com tremidinha de mão; aparece no começo, some no fim
	_mira_vis = clampf(_mira_vis + delta * (2.5 if _t > 0.3 and _t < 3.3 else -3.0), 0.0, 1.0)
	_mira = _mira.lerp(_mira_alvo, 1.0 - exp(-delta * 9.0))
	if _carregando:
		_carga = minf(1.0, _carga + delta / 0.72)

	for d in _disparos:
		d["t"] += delta
	_disparos = _disparos.filter(func(d) -> bool: return d["t"] < d["vida"])
	for i in _impactos:
		i["t"] += delta
	_impactos = _impactos.filter(func(i) -> bool: return i["t"] < i["vida"])
	for f in _furos:
		f["t"] += delta
	for pl in _placas:
		pl["t"] += delta
		if pl["caiu"] >= 0.0:
			pl["caiu"] += delta
			pl["vel"] += Vector2(0, 1900.0) * delta
			pl["pos"] += pl["vel"] * delta
			pl["vira"] += delta * 13.0
	if _onda_t >= 0.0:
		_onda_t += delta
		if _onda_t > 0.8:
			_onda_t = -1.0
	_clarao.color.a = move_toward(_clarao.color.a, 0.0, delta * 2.6)

	# tremor da tela (só a cena, não a transição)
	_tremor = move_toward(_tremor, 0.0, delta * 40.0)
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _tremor

	# logo: entra grande com clarão e assenta; depois a faixa de brilho passa
	if _logo_t >= 0.0:
		_logo_t += delta
		var k := clampf(_logo_t / 0.5, 0.0, 1.0)
		var elastico := 1.0 + 0.32 * exp(-k * 5.0) * cos(k * 9.0)
		_logo.scale = Vector2.ONE * elastico
		var ml := _logo.material as ShaderMaterial
		ml.set_shader_parameter("branco", clampf(1.0 - _logo_t / 0.35, 0.0, 1.0))
		ml.set_shader_parameter("faixa", -0.4 + maxf(0.0, _logo_t - 0.9) * 1.1)
		(_fundo.material as ShaderMaterial).set_shader_parameter("pulso", clampf(1.0 - _logo_t / 0.6, 0.0, 1.0))
	if _games_t >= 0.0:
		_games_t += delta
		var g := clampf(_games_t / 0.22, 0.0, 1.0)
		_games.scale = Vector2.ONE * lerpf(2.2, 1.0, g * g)
		_games.modulate.a = g
	if _apresenta_t >= 0.0:
		_apresenta_t += delta
		var a := clampf(_apresenta_t / 0.5, 0.0, 1.0)
		_apresenta.modulate.a = a
		_apresenta.position.y = _games.position.y + 175 + 18.0 * (1.0 - a) * (1.0 - a)

	_marcas.queue_redraw()
	_luz.queue_redraw()


# ───────────────────────────────────────────── desenho
func _desenhar_marcas() -> void:
	var some := 0.45 if _logo_t >= 0.0 else 1.0
	for f in _furos:
		var p: Vector2 = f["pos"]
		_marcas.draw_circle(p, 26.0, Color(0.08, 0.04, 0.02, 0.28 * some))
		_marcas.draw_circle(p, 15.0, Color(0, 0, 0, 0.45 * some))
		for r: Vector2 in f["raios"]:
			_marcas.draw_line(p + r * 0.3, p + r, Color(0.02, 0.02, 0.02, 0.6 * some), 2.0, true)
		_marcas.draw_circle(p, 9.0, Color(0, 0, 0, 0.92 * some))
	for pl in _placas:
		_desenhar_placa(pl)


# placa de aço com alvo pintado; sobe com mola e, quando leva o tiro, gira e cai
func _desenhar_placa(pl: Dictionary) -> void:
	var t: float = pl["t"]
	if t <= 0.0:
		return
	var cai: float = pl["caiu"]
	if cai > 1.2:
		return
	var sobe := clampf(t / 0.35, 0.0, 1.0)
	var mola := 1.0 + 0.25 * exp(-t * 9.0) * sin(t * 26.0) if sobe >= 1.0 else sobe
	var r: float = pl["r"]
	var p: Vector2 = pl["pos"]
	var a := 1.0 - clampf((cai - 0.6) / 0.6, 0.0, 1.0) if cai >= 0.0 else 1.0
	var vira := cos(pl["vira"]) if cai >= 0.0 else 1.0
	var giro: float = pl["giro"] * maxf(cai, 0.0)
	# haste e sombra na parede (só enquanto está de pé)
	if cai < 0.0:
		_marcas.draw_line(p + Vector2(0, r * 0.8), p + Vector2(0, r * 2.4), Color(0.05, 0.04, 0.04, 0.9 * sobe), 8.0, true)
		_marcas.draw_circle(p + Vector2(7, 9), r * mola, Color(0, 0, 0, 0.45 * sobe))
	_marcas.draw_set_transform(p, giro, Vector2(mola, mola * vira))
	var aneis := [[1.0, Color(0.16, 0.15, 0.16)], [0.92, Color(0.93, 0.92, 0.90)], [0.74, VERMELHO.darkened(0.1)],
		[0.56, Color(0.93, 0.92, 0.90)], [0.38, VERMELHO.darkened(0.1)], [0.18, Color(0.95, 0.94, 0.92)]]
	for anel in aneis:
		_marcas.draw_circle(Vector2.ZERO, r * anel[0], Color(anel[1], a))
	# brilho de metal no canto de cima
	_marcas.draw_arc(Vector2.ZERO, r * 0.96, -2.6, -1.2, 16, Color(1, 1, 1, 0.35 * a), 3.0, true)
	if cai >= 0.0:
		_marcas.draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0, 0.95 * a))
	_marcas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A luz (mistura somada) só com o pincel: retângulos de uma textura só
## (scripts/pincel.gd), o jeito de desenhar que a TV Box já usa no jogo
## inteiro. Linhas e curvas com luz somada coincidiam com as quedas na TV Box.
func _desenhar_luz() -> void:
	# furos em brasa esfriando
	for f in _furos:
		var quente := clampf(1.0 - f["t"] / 1.6, 0.0, 1.0)
		if quente > 0.0:
			Pincel.anel(_luz, f["pos"], 11.0, 4.0, Color(1.0, 0.45, 0.08, quente))
			Pincel.circulo(_luz, f["pos"], 18.0, Color(1.0, 0.25, 0.05, quente * 0.25))
	# feixes do laser
	for d in _disparos:
		var a: float = 1.0 - d["t"] / d["vida"]
		var w := 2.2 if d["forte"] else 1.0
		var de: Vector2 = d["de"]
		var para: Vector2 = d["para"]
		Pincel.linha(_luz, de, para, Color(VERMELHO, 0.18 * a), 30.0 * w)
		Pincel.linha(_luz, de, para, Color(VERMELHO, 0.40 * a), 13.0 * w)
		Pincel.linha(_luz, de, para, Color(1.0, 0.85, 0.85, 0.95 * a), 4.0 * w)
	# clarões dos impactos
	for i in _impactos:
		var k: float = i["t"] / i["vida"]
		var r := (40.0 + 260.0 * k) if i["forte"] else (18.0 + 80.0 * k)
		var a := (1.0 - k)
		for j in 4:
			var rr := r * (1.0 - j * 0.22)
			Pincel.circulo(_luz, i["pos"], rr, Color(1.0, 0.55 + 0.1 * j, 0.35 + 0.15 * j, 0.16 * a))
	# onda de choque do tiro final
	if _onda_t >= 0.0:
		var k := _onda_t / 0.8
		var r := 40.0 + k * _tela.y * 0.75
		Pincel.anel(_luz, _alvo, r, 3.0 + 22.0 * (1.0 - k), Color(1.0, 0.75, 0.75, 0.8 * (1.0 - k)))
		Pincel.anel(_luz, _alvo, r * 0.82, 2.0 + 10.0 * (1.0 - k), Color(VERMELHO, 0.5 * (1.0 - k)))
	# mira
	if _mira_vis > 0.0:
		var c := Vector2(sin(_t * 13.0) * 2.5, cos(_t * 11.0) * 2.0) * (1.0 - _carga) + _mira
		var r := 50.0 - 18.0 * _carga
		var cor := Color(VERMELHO, _mira_vis)
		Pincel.anel(_luz, c, r, 14.0, Color(VERMELHO, 0.22 * _mira_vis))
		Pincel.anel(_luz, c, r, 4.0, cor)
		var giro := _t * 5.0 * _carga
		for k in 4:
			var dir := Vector2.RIGHT.rotated(giro + k * PI * 0.5)
			Pincel.linha(_luz, c + dir * r * 0.55, c + dir * r * 1.4, cor, 4.0)
		Pincel.circulo(_luz, c, 4.0, Color(1, 0.9, 0.9, _mira_vis))
		if _carga > 0.0:
			Pincel.arco(_luz, c, r + 16.0, -PI * 0.5, -PI * 0.5 + TAU * _carga, Color(1.0, 0.6, 0.6, _mira_vis), 5.0)
			Pincel.circulo(_luz, c, r * 0.5 * _carga, Color(VERMELHO, 0.25 * _carga))
