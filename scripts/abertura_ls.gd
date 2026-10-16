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
##
## Tudo desenhado na hora com o pincel (scripts/pincel.gd: retângulos de uma
## textura só); a única imagem própria é o logo. É o jeito mais simples que
## a placa da TV Box conhece: nada de linhas, polígonos ou sistema de
## partículas (faíscas, estouro e brasas são pontos de luz desenhados aqui)
## e, na TV Box, sem luz somada. Começa no primeiro quadro, como na 1.24.0
## (a última que mostrou a apresentação na TV Box), sempre: desde a Rodada 30
## a página de queda não aparece mais antes dela.

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
var _luz: Node2D          # feixes, clarões, mira, onda e faíscas (pincel)
var _chispas: Array = []  # faíscas, estouro e brasas: {pos, vel, t, vida, r, grav}
var _brasas := false      # brasas subindo do logo depois do tiro final
var _brasas_acc := 0.0
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
static var _marcou := false        # caixa-preta: cada passo, só na 1ª vez

## Cores das faíscas ao longo da vida (quente: amarelo, laranja, some).
const QUENTE := [Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.55, 0.15, 1.0), Color(1.0, 0.15, 0.05, 0.0)]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Tela.contorna("abertura"):
		# já derrubou o app nesta versão: parada e escondida, sem montar
		# nada, direto para o menu
		visible = false
		set_process(false)
		set_process_input(false)
		Tela.marca("contorno: pulando a apresentação")
		TransicaoGlobal.trocar_cena(PROXIMA, 0.0, 0.3)
		return
	_iniciar()


func _iniciar() -> void:
	visible = true
	set_process(true)
	set_process_input(true)
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
	Tela.risco("abertura")   # se o app morrer aqui, a caixa-preta sabe
	var tw := create_tween()
	tw.tween_property(_escuro, "color:a", 0.0, 0.6)


func _montar() -> void:
	_fundo = ColorRect.new()
	var mf := ShaderMaterial.new()
	mf.shader = SHADER_FUNDO
	_fundo.material = mf
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fundo)

	_marcas = Node2D.new()
	_marcas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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

	_luz = Node2D.new()
	if OS.get_name() != "Android":
		var soma := CanvasItemMaterial.new()
		soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_luz.material = soma
	_luz.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_luz.draw.connect(_desenhar_luz)
	add_child(_luz)

	_clarao = ColorRect.new()
	_clarao.color = Color(1, 1, 1, 0)
	_clarao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clarao)
	_escuro = ColorRect.new()
	_escuro.color = Color(0, 0, 0, 1)
	_escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_escuro)


## Faíscas: `n` pontos de luz saindo de `pos` em todas as direções.
func _emitir(pos: Vector2, n: int, vel_min: float, vel_max: float, grav: float, vida: float, r_min: float, r_max: float) -> void:
	for i in n:
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		_chispas.append({"pos": pos, "vel": dir * randf_range(vel_min, vel_max), "t": 0.0,
			"vida": vida * randf_range(0.75, 1.0), "r": randf_range(r_min, r_max), "grav": grav})


## Uma brasa subindo devagar da base do logo.
func _brasa() -> void:
	var larg := _logo.size.x
	var base := Vector2(_tela.x * 0.5 + randf_range(-0.5, 0.5) * larg, _logo.position.y + _logo.size.y)
	var dir := Vector2.UP.rotated(deg_to_rad(randf_range(-25.0, 25.0)))
	_chispas.append({"pos": base, "vel": dir * randf_range(20.0, 70.0), "t": 0.0,
		"vida": 3.2 * randf_range(0.75, 1.0), "r": randf_range(1.5, 4.0), "grav": -35.0})


static func _cor_quente(k: float) -> Color:
	if k < 0.3:
		return (QUENTE[0] as Color).lerp(QUENTE[1], k / 0.3)
	return (QUENTE[1] as Color).lerp(QUENTE[2], (k - 0.3) / 0.7)


func _ajustar() -> void:
	_tela = get_viewport_rect().size
	for r: Control in [_fundo, _clarao, _escuro]:
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
		_emitir(p, 26, 220.0, 640.0, 1200.0, 0.6, 3.0, 7.0)
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
	_emitir(_alvo, 70, 300.0, 1100.0, 900.0, 1.1, 4.0, 13.0)
	_logo.visible = true
	_logo_t = 0.0
	_brasas = true
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

	# faíscas, estouro e brasas (pontos de luz soltos, com gravidade)
	for c in _chispas:
		c["t"] += delta
		c["vel"] += Vector2(0, c["grav"]) * delta
		c["pos"] += c["vel"] * delta
	_chispas = _chispas.filter(func(c) -> bool: return c["t"] < c["vida"])
	if _brasas:
		_brasas_acc += delta * 9.4   # ~30 brasas no ar
		while _brasas_acc >= 1.0:
			_brasas_acc -= 1.0
			_brasa()

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
## Furos e placas também pelo pincel (mistura normal): a apresentação inteira
## é feita de retângulos de uma textura só.
func _desenhar_marcas() -> void:
	var some := 0.45 if _logo_t >= 0.0 else 1.0
	for f in _furos:
		var p: Vector2 = f["pos"]
		Pincel.circulo(_marcas, p, 26.0, Color(0.08, 0.04, 0.02, 0.28 * some))
		Pincel.circulo(_marcas, p, 15.0, Color(0, 0, 0, 0.45 * some))
		for r: Vector2 in f["raios"]:
			Pincel.linha(_marcas, p + r * 0.3, p + r, Color(0.02, 0.02, 0.02, 0.6 * some), 2.0)
		Pincel.circulo(_marcas, p, 9.0, Color(0, 0, 0, 0.92 * some))
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
		Pincel.linha(_marcas, p + Vector2(0, r * 0.8), p + Vector2(0, r * 2.4), Color(0.05, 0.04, 0.04, 0.9 * sobe), 8.0)
		Pincel.circulo(_marcas, p + Vector2(7, 9), r * mola, Color(0, 0, 0, 0.45 * sobe))
	Pincel.base(_marcas, Transform2D(giro, Vector2(mola, mola * vira), 0.0, p))
	var aneis := [[1.0, Color(0.16, 0.15, 0.16)], [0.92, Color(0.93, 0.92, 0.90)], [0.74, VERMELHO.darkened(0.1)],
		[0.56, Color(0.93, 0.92, 0.90)], [0.38, VERMELHO.darkened(0.1)], [0.18, Color(0.95, 0.94, 0.92)]]
	for anel in aneis:
		Pincel.circulo(_marcas, Vector2.ZERO, r * anel[0], Color(anel[1], a))
	# brilho de metal no canto de cima
	Pincel.arco(_marcas, Vector2.ZERO, r * 0.96, -2.6, -1.2, Color(1, 1, 1, 0.35 * a), 3.0)
	if cai >= 0.0:
		Pincel.circulo(_marcas, Vector2.ZERO, 8.0, Color(0, 0, 0, 0.95 * a))
	Pincel.base(_marcas, Transform2D.IDENTITY)


## A luz só com o pincel: retângulos de uma textura só (scripts/pincel.gd),
## o jeito de desenhar que a TV Box já usa no jogo inteiro. No PC ela soma
## (mistura somada); na TV Box, mistura comum.
func _desenhar_luz() -> void:
	# faíscas, estouro e brasas
	for c in _chispas:
		Pincel.brilho(_luz, c["pos"], c["r"] * 1.25, _cor_quente(c["t"] / c["vida"]))
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
