extends Node2D

## ABERTURA LAZER & SPORT GAMES (a primeira tela do jogo).
##
## Estande de tiro no escuro: três placas-alvo sobem na parede, a mira entra
## e o laser derruba uma a uma (a placa gira e cai, faíscas, furo em brasa
## esfriando na parede), a mira trava no centro, carrega e o tiro final
## acerta: clarão branco, onda de choque, tela tremendo e o logo da Lazer &
## Sport aparece, com GAMES batendo embaixo e "apresenta" logo depois.
## Depois vai para a tela inicial. Qualquer tiro ou START pula.
##
## Na Mali-450: a parede é uma imagem pronta (tools/preparar_mali.py), a luz
## é somada num nó só (faíscas, feixes, clarões, mira) e as marcas num outro.

const PROXIMA = "res://scenes/menu.tscn"
const ALVO_NO_LOGO = Vector2(378, 168)    # centro do alvo dentro do logo (px da imagem)
const VERMELHO = Color(1.0, 0.16, 0.20)
const FIM = 5.9
const QUENTE = [Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.55, 0.15, 1.0), Color(1.0, 0.15, 0.05, 0.0)]

var _t = 0.0
var _saindo = false
var _fundo: Sprite
var _pulso: Sprite
var _marcas: Node2D
var _luz: Node2D
var _logo: Sprite
var _games: Label
var _apresenta: Label
var _clarao: ColorRect
var _escuro: ColorRect

var _origem = Vector2.ZERO
var _alvo = Vector2.ZERO
var _mira = Vector2.ZERO
var _mira_alvo = Vector2.ZERO
var _mira_vis = 0.0
var _carga = 0.0
var _carregando = false
var _chispas = []          # faíscas, estouro e brasas: {pos, vel, t, vida, r, grav}
var _brasas = false
var _brasas_acc = 0.0
var _furos = []            # {pos, t, raios}
var _placas = []           # {pos, r, t, caiu, vel, giro, vira}
var _disparos = []         # {de, para, t, vida, forte}
var _impactos = []         # {pos, t, vida, forte}
var _onda_t = -1.0
var _tremor = 0.0
var _logo_t = -1.0
var _logo_escala = 1.0
var _games_t = -1.0
var _apresenta_t = -1.0
var _roteiro = []          # [tempo, método, argumentos], em ordem

var _som_tiro: AudioStream
var _som_impacto: AudioStream
var _som_carga: AudioStream
var _som_final: AudioStream
var _som_alvo: AudioStream


func _ready() -> void:
	MiraGlobal.ativa = false
	_som_tiro = load("res://songs/tiro_menu.wav")
	_som_impacto = load("res://songs/plasma-hit.wav")
	_som_carga = load("res://songs/lazer-charge.wav")
	_som_final = load("res://songs/xploit.wav")
	_som_alvo = load("res://songs/alvo_crash.wav")
	_montar()
	var tela = Tela.TELA
	var p1 = Vector2(tela.x * 0.22, tela.y * 0.30)
	var p2 = Vector2(tela.x * 0.79, tela.y * 0.35)
	var p3 = Vector2(tela.x * 0.33, tela.y * 0.56)
	_mira = Vector2(tela.x * 0.92, tela.y * 0.88)
	_mira_alvo = _mira
	for i in 3:
		_placas.append({"pos": [p1, p2, p3][i], "r": 54.0, "t": -0.12 - i * 0.16, "caiu": -1.0, "vel": Vector2.ZERO, "giro": 0.0, "vira": 0.0})
	_roteiro = [
		[0.35, "_mirar", [p1]], [1.10, "_disparar", [p1, false]],
		[1.30, "_mirar", [p2]], [1.62, "_disparar", [p2, false]],
		[1.82, "_mirar", [p3]], [2.12, "_disparar", [p3, false]],
		[2.36, "_comecar_carga", []], [3.12, "_tiro_final", []],
		[3.58, "_bater_games", []], [4.25, "_mostrar_apresenta", []],
	]
	var tw = create_tween()
	tw.tween_property(_escuro, "color:a", 0.0, 0.6)


func _montar() -> void:
	var tela = Tela.TELA
	_fundo = Sprite.new()
	_fundo.texture = Estilo.tex("fundo_abertura")
	_fundo.centered = false
	_fundo.scale = Vector2.ONE * (tela.x / _fundo.texture.get_width())
	add_child(_fundo)
	# o foco vermelho da parede pisca forte no tiro final
	_pulso = Sprite.new()
	_pulso.texture = Estilo.tex("fx_brilho")
	_pulso.material = Estilo.material_soma()
	_pulso.position = Vector2(tela.x * 0.5, tela.y * 0.42)
	_pulso.scale = Vector2(16.0, 12.0)
	_pulso.modulate = Color(0.85, 0.12, 0.14, 0.0)
	add_child(_pulso)
	_marcas = Node2D.new()
	_marcas.connect("draw", self, "_desenhar_marcas")
	add_child(_marcas)
	_logo = Sprite.new()
	_logo.texture = Estilo.tex("logo_lazer_sport")
	var larg = tela.x * 0.80
	_logo_escala = larg / _logo.texture.get_width()
	var alt = _logo.texture.get_height() * _logo_escala
	_logo.position = Vector2(tela.x * 0.5, tela.y * 0.42)
	_logo.scale = Vector2.ONE * _logo_escala
	_logo.visible = false
	add_child(_logo)
	var canto = _logo.position - Vector2(larg, alt) * 0.5
	_alvo = canto + ALVO_NO_LOGO * _logo_escala
	# GAMES: letras espaçadas, vermelhas com contorno branco e sombra
	var f: DynamicFont = Estilo.fonte(132, true, 16, Color.white).duplicate()
	f.extra_spacing_char = 22
	_games = Label.new()
	_games.text = "GAMES"
	_games.align = Label.ALIGN_CENTER
	_games.valign = Label.VALIGN_CENTER
	_games.add_font_override("font", f)
	_games.add_color_override("font_color", VERMELHO)
	_games.add_color_override("font_color_shadow", Color(0, 0, 0, 0.75))
	_games.add_constant_override("shadow_offset_x", 0)
	_games.add_constant_override("shadow_offset_y", 8)
	_games.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Estilo.colocar(_games, Vector2(0, canto.y + alt + 20), Vector2(tela.x, 170))
	_games.visible = false
	add_child(_games)
	var fa: DynamicFont = Estilo.fonte(46, true, 0).duplicate()
	fa.extra_spacing_char = 16
	_apresenta = Label.new()
	_apresenta.text = "apresenta"
	_apresenta.align = Label.ALIGN_CENTER
	_apresenta.add_font_override("font", fa)
	_apresenta.add_color_override("font_color", Color(1, 0.93, 0.93))
	_apresenta.add_color_override("font_color_shadow", Color(0, 0, 0, 0.7))
	_apresenta.add_constant_override("shadow_offset_y", 4)
	_apresenta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Estilo.colocar(_apresenta, Vector2(0, _games.rect_position.y + 175), Vector2(tela.x, 70))
	_apresenta.modulate.a = 0.0
	add_child(_apresenta)
	_luz = Node2D.new()
	_luz.material = Estilo.material_soma()
	_luz.connect("draw", self, "_desenhar_luz")
	add_child(_luz)
	_origem = Vector2(tela.x * 0.84, tela.y + 70)
	var camada = CanvasLayer.new()
	camada.layer = 50
	add_child(camada)
	_clarao = ColorRect.new()
	_clarao.rect_size = tela
	_clarao.color = Color(1, 1, 1, 0)
	_clarao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(_clarao)
	_escuro = ColorRect.new()
	_escuro.rect_size = tela
	_escuro.color = Color(0, 0, 0, 1)
	_escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(_escuro)


# ------------------------------------------------------------ roteiro
func _mirar(p: Vector2) -> void:
	_mira_alvo = p


func _emitir(pos: Vector2, n: int, vel_min: float, vel_max: float, grav: float, vida: float, r_min: float, r_max: float) -> void:
	n = int(max(4, n * Maquina.fator_efeitos()))
	for i in n:
		var a = randf() * TAU
		_chispas.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * rand_range(vel_min, vel_max), "t": 0.0,
			"vida": vida * rand_range(0.75, 1.0), "r": rand_range(r_min, r_max), "grav": grav})


func _disparar(p: Vector2, forte: bool) -> void:
	_disparos.append({"de": _origem, "para": p, "t": 0.0, "vida": 0.32 if forte else 0.15, "forte": forte})
	_impactos.append({"pos": p, "t": 0.0, "vida": 0.7 if forte else 0.26, "forte": forte})
	if forte:
		return
	var raios = []
	for i in 5 + randi() % 3:
		var a = randf() * TAU
		raios.append(Vector2(cos(a), sin(a)) * rand_range(16.0, 42.0))
	_furos.append({"pos": p, "t": 0.0, "raios": raios})
	for pl in _placas:
		if pl["caiu"] < 0.0 and pl["pos"].distance_to(p) < pl["r"]:
			pl["caiu"] = 0.0
			pl["vel"] = Vector2(rand_range(-160.0, 160.0), rand_range(-420.0, -300.0))
			pl["giro"] = rand_range(-7.0, 7.0)
	_emitir(p, 26, 220.0, 640.0, 1200.0, 0.6, 3.0, 7.0)
	_tremor = max(_tremor, 7.0)
	Maquina.efeito(_som_tiro, -2.0, rand_range(0.95, 1.05))
	Maquina.efeito(_som_impacto, -6.0, rand_range(0.9, 1.1))


func _comecar_carga() -> void:
	_mira_alvo = _alvo
	_carregando = true
	Maquina.efeito(_som_carga, -3.0)


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
	Maquina.efeito(_som_final, 0.0)
	Maquina.efeito(_som_alvo, -3.0, 0.85)


func _bater_games() -> void:
	_games.visible = true
	_games_t = 0.0
	_tremor = max(_tremor, 9.0)
	Maquina.efeito(_som_impacto, -2.0, 0.7)


func _mostrar_apresenta() -> void:
	_apresenta_t = 0.0


func _sair() -> void:
	if _saindo:
		return
	_saindo = true
	TransicaoGlobal.trocar_cena(PROXIMA, 0.45)


func _input(ev: InputEvent) -> void:
	if _t < 0.6 or _saindo:
		return
	if Maquina.e_tiro(ev) or Maquina.e_start(ev) or (ev is InputEventMouseButton and ev.pressed):
		get_tree().set_input_as_handled()
		_sair()


# ------------------------------------------------------------ quadro a quadro
func _process(delta: float) -> void:
	# um quadro pode demorar: o roteiro não pula
	delta = min(delta, 0.05)
	_t += delta
	while not _roteiro.empty() and _t >= _roteiro[0][0]:
		var passo = _roteiro.pop_front()
		callv(passo[1], passo[2])
	if _t >= FIM:
		_sair()
	_mira_vis = clamp(_mira_vis + delta * (2.5 if _t > 0.3 and _t < 3.3 else -3.0), 0.0, 1.0)
	_mira = _mira.linear_interpolate(_mira_alvo, 1.0 - exp(-delta * 9.0))
	if _carregando:
		_carga = min(1.0, _carga + delta / 0.72)
	_disparos = _passar(_disparos, delta)
	_impactos = _passar(_impactos, delta)
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
	var vivas = []
	for c in _chispas:
		c["t"] += delta
		c["vel"] += Vector2(0, c["grav"]) * delta
		c["pos"] += c["vel"] * delta
		if c["t"] < c["vida"]:
			vivas.append(c)
	_chispas = vivas
	if _brasas:
		_brasas_acc += delta * 9.4 * Maquina.fator_efeitos()
		while _brasas_acc >= 1.0:
			_brasas_acc -= 1.0
			_brasa()
	_tremor = move_toward(_tremor, 0.0, delta * 40.0)
	position = Vector2(rand_range(-1, 1), rand_range(-1, 1)) * _tremor
	# logo: entra grande com clarão e assenta
	if _logo_t >= 0.0:
		_logo_t += delta
		var k = clamp(_logo_t / 0.5, 0.0, 1.0)
		var elastico = 1.0 + 0.32 * exp(-k * 5.0) * cos(k * 9.0)
		_logo.scale = Vector2.ONE * _logo_escala * elastico
		var b = clamp(1.0 - _logo_t / 0.35, 0.0, 1.0)
		_logo.modulate = Color(1.0 + 3.0 * b, 1.0 + 3.0 * b, 1.0 + 3.0 * b)
		_pulso.modulate.a = 0.35 * clamp(1.0 - _logo_t / 0.6, 0.0, 1.0) + 0.12
	if _games_t >= 0.0:
		_games_t += delta
		var g = clamp(_games_t / 0.22, 0.0, 1.0)
		_games.rect_scale = Vector2.ONE * lerp(2.2, 1.0, g * g)
		_games.modulate.a = g
	if _apresenta_t >= 0.0:
		_apresenta_t += delta
		var a = clamp(_apresenta_t / 0.5, 0.0, 1.0)
		_apresenta.modulate.a = a
		_apresenta.rect_position.y = _games.rect_position.y + 175 + 18.0 * (1.0 - a) * (1.0 - a)
	_marcas.update()
	_luz.update()


func _passar(lista: Array, delta: float) -> Array:
	var r = []
	for d in lista:
		d["t"] += delta
		if d["t"] < d["vida"]:
			r.append(d)
	return r


func _brasa() -> void:
	var larg = _logo.texture.get_width() * _logo_escala
	var base = Vector2(Tela.TELA.x * 0.5 + rand_range(-0.5, 0.5) * larg, _logo.position.y + _logo.texture.get_height() * _logo_escala * 0.5)
	var a = deg2rad(-90.0 + rand_range(-25.0, 25.0))
	_chispas.append({"pos": base, "vel": Vector2(cos(a), sin(a)) * rand_range(20.0, 70.0), "t": 0.0,
		"vida": 3.2 * rand_range(0.75, 1.0), "r": rand_range(1.5, 4.0), "grav": -35.0})


static func _cor_quente(k: float) -> Color:
	if k < 0.3:
		return QUENTE[0].linear_interpolate(QUENTE[1], k / 0.3)
	return QUENTE[1].linear_interpolate(QUENTE[2], (k - 0.3) / 0.7)


# ------------------------------------------------------------ desenho
func _desenhar_marcas() -> void:
	var some = 0.45 if _logo_t >= 0.0 else 1.0
	for f in _furos:
		var p: Vector2 = f["pos"]
		_marcas.draw_circle(p, 26.0, Color(0.08, 0.04, 0.02, 0.28 * some))
		_marcas.draw_circle(p, 15.0, Color(0, 0, 0, 0.45 * some))
		for r in f["raios"]:
			_marcas.draw_line(p + r * 0.3, p + r, Color(0.02, 0.02, 0.02, 0.6 * some), 2.0)
		_marcas.draw_circle(p, 9.0, Color(0, 0, 0, 0.92 * some))
	for pl in _placas:
		_desenhar_placa(pl)
	_marcas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Placa de aço com o alvo pintado: sobe com mola e, levando o tiro, gira e cai.
func _desenhar_placa(pl: Dictionary) -> void:
	var t: float = pl["t"]
	if t <= 0.0:
		return
	var cai: float = pl["caiu"]
	if cai > 1.2:
		return
	var sobe = clamp(t / 0.35, 0.0, 1.0)
	var mola = (1.0 + 0.25 * exp(-t * 9.0) * sin(t * 26.0)) if sobe >= 1.0 else sobe
	var r: float = pl["r"]
	var p: Vector2 = pl["pos"]
	var a = (1.0 - clamp((cai - 0.6) / 0.6, 0.0, 1.0)) if cai >= 0.0 else 1.0
	var vira = cos(pl["vira"]) if cai >= 0.0 else 1.0
	var giro = pl["giro"] * max(cai, 0.0)
	if cai < 0.0:
		_marcas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_marcas.draw_line(p + Vector2(0, r * 0.8), p + Vector2(0, r * 2.4), Color(0.05, 0.04, 0.04, 0.9 * sobe), 8.0)
		_marcas.draw_circle(p + Vector2(7, 9), r * max(mola, 0.01), Color(0, 0, 0, 0.45 * sobe))
	_marcas.draw_set_transform(p, giro, Vector2(mola, mola * vira))
	var aneis = [[1.0, Color(0.16, 0.15, 0.16)], [0.92, Color(0.93, 0.92, 0.90)], [0.74, VERMELHO.darkened(0.1)],
		[0.56, Color(0.93, 0.92, 0.90)], [0.38, VERMELHO.darkened(0.1)], [0.18, Color(0.95, 0.94, 0.92)]]
	for anel in aneis:
		var c: Color = anel[1]
		_marcas.draw_circle(Vector2.ZERO, r * anel[0], Color(c.r, c.g, c.b, a))
	_marcas.draw_arc(Vector2.ZERO, r * 0.96, -2.6, -1.2, 12, Color(1, 1, 1, 0.35 * a), 3.0)
	if cai >= 0.0:
		_marcas.draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0, 0.95 * a))


func _brilho(pos: Vector2, r: float, c: Color) -> void:
	var tex = Estilo.tex("fx_brilho")
	_luz.draw_texture_rect(tex, Rect2(pos - Vector2(r, r) * 2.0, Vector2(r, r) * 4.0), false, c)


func _anel(pos: Vector2, r: float, largura: float, c: Color) -> void:
	_luz.draw_arc(pos, r, 0.0, TAU, 48, c, largura)


func _desenhar_luz() -> void:
	for c in _chispas:
		_brilho(c["pos"], c["r"] * 1.25, _cor_quente(c["t"] / c["vida"]))
	for f in _furos:
		var quente = clamp(1.0 - f["t"] / 1.6, 0.0, 1.0)
		if quente > 0.0:
			_anel(f["pos"], 11.0, 4.0, Color(1.0, 0.45, 0.08, quente))
			_brilho(f["pos"], 18.0, Color(1.0, 0.25, 0.05, quente * 0.5))
	for d in _disparos:
		var a = 1.0 - d["t"] / d["vida"]
		var w = 2.2 if d["forte"] else 1.0
		_luz.draw_line(d["de"], d["para"], Color(VERMELHO.r, VERMELHO.g, VERMELHO.b, 0.18 * a), 30.0 * w)
		_luz.draw_line(d["de"], d["para"], Color(VERMELHO.r, VERMELHO.g, VERMELHO.b, 0.40 * a), 13.0 * w)
		_luz.draw_line(d["de"], d["para"], Color(1.0, 0.85, 0.85, 0.95 * a), 4.0 * w)
	for i in _impactos:
		var k = i["t"] / i["vida"]
		var r = (40.0 + 260.0 * k) if i["forte"] else (18.0 + 80.0 * k)
		_brilho(i["pos"], r * 0.6, Color(1.0, 0.6, 0.45, 0.7 * (1.0 - k)))
	if _onda_t >= 0.0:
		var k2 = _onda_t / 0.8
		var r2 = 40.0 + k2 * Tela.TELA.y * 0.75
		_anel(_alvo, r2, 3.0 + 22.0 * (1.0 - k2), Color(1.0, 0.75, 0.75, 0.8 * (1.0 - k2)))
		_anel(_alvo, r2 * 0.82, 2.0 + 10.0 * (1.0 - k2), Color(VERMELHO.r, VERMELHO.g, VERMELHO.b, 0.5 * (1.0 - k2)))
	if _mira_vis > 0.0:
		var c = Vector2(sin(_t * 13.0) * 2.5, cos(_t * 11.0) * 2.0) * (1.0 - _carga) + _mira
		var r3 = 50.0 - 18.0 * _carga
		var cor = Color(VERMELHO.r, VERMELHO.g, VERMELHO.b, _mira_vis)
		_anel(c, r3, 14.0, Color(VERMELHO.r, VERMELHO.g, VERMELHO.b, 0.22 * _mira_vis))
		_anel(c, r3, 4.0, cor)
		var giro = _t * 5.0 * _carga
		for k3 in 4:
			var d = Vector2(cos(giro + k3 * PI * 0.5), sin(giro + k3 * PI * 0.5))
			_luz.draw_line(c + d * r3 * 0.55, c + d * r3 * 1.4, cor, 4.0)
		_luz.draw_circle(c, 4.0, Color(1, 0.9, 0.9, _mira_vis))
		if _carga > 0.0:
			_luz.draw_arc(c, r3 + 16.0, -PI * 0.5, -PI * 0.5 + TAU * _carga, 40, Color(1.0, 0.6, 0.6, _mira_vis), 5.0)
			_brilho(c, r3 * 0.5 * _carga, Color(VERMELHO.r, VERMELHO.g, VERMELHO.b, 0.5 * _carga))
