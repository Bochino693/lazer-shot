class_name ArenaVivo
extends Node2D

## Vida do fundo da Arena (fica entre o fundo e as lanternas).
##
##   fundo vivo     o mesmo shader dos fundos do menu (fundo_vivo.gdshader,
##                  sem zoom para os furos não saírem do lugar): luzes que
##                  piscam com a música, chão com reflexo, brilho na batida
##   troca de arte  rodada FIXA: o fundo cruza para sprites/arena_fixa.png
##                  (letreiro nas 5 cores, furos em neon frio, giroflex roxo),
##                  uma linha de varredura colorida desce a parede e o
##                  letreiro "SEQUÊNCIA FIXA" cruza a tela; na MEMÓRIA volta
##   giroflex       gira na troca de rodada, no erro (vermelho) e na
##                  vitória (nas cores); pisca na cor de cada lanterna
##   fachos         as duas arandelas jogam luz na parede, com poeira no ar
##   vapor/faíscas  baforadas dos canos e faíscas da caixa elétrica, de vez
##                  em quando
##   ordem          faixa de 5 luzes (1 a 5 nas cores) embaixo dos furos;
##                  a próxima pulsa
##   LED do alto    alvo de bônus (arena.gd): o tiro estoura a lâmpada do
##                  giroflex (clarão, faíscas, cacos do vidro vermelho
##                  caindo, zumbido elétrico); fica apagada soltando fumaça
##                  uns segundos e volta piscando até acender
## Tudo com o Pincel (uma textura, poucos desenhos) e quase nada de cálculo.

const SHADER := preload("res://shaders/fundo_vivo.gdshader")
# load() e não preload(): o Godot 4.6 nunca descarrega um script já carregado,
# e o que ele pré-carrega ficava na memória depois da primeira partida.
var MASCARA: Texture2D = load("res://sprites/arena_mascara.png")
var FUNDO_FIXA: Texture2D = Hd.textura("res://sprites/arena_fixa.png")
const Pincel := preload("res://scripts/pincel.gd")
const FONTE := preload("res://fonts/Exo2-ExtraBold.ttf")
const SOM_VAPOR := preload("res://songs/arena_vapor.wav")
const SOM_FAISCA := preload("res://songs/arena_faisca.wav")
const SOM_TROCA := preload("res://songs/arena_troca.wav")
var SOM_LED: AudioStream = load("res://songs/led_estoura.wav")

# pontos em px de sprites/arena.png (1024x1536)
const GIROFLEX := Vector2(510, 190)
const LED_CAIXA := Rect2(484, 177, 54, 25)     # a caixa da luz
const LED_APAGADO := 7.0                       # s apagado depois do tiro
const ARANDELAS := [Vector2(44, 762), Vector2(978, 762)]
const VAPOR := [Vector2(150, 748), Vector2(804, 944), Vector2(842, 1128), Vector2(118, 1180)]
const CAIXA_ELETRICA := Vector2(842, 956)
const Y_ORDEM := 1318.0
# as cores da ordem dos tiros (iguais às da arena)
const CORES := [Color(0.25, 0.62, 1.0), Color(0.25, 1.0, 0.35), Color(1.0, 0.86, 0.15), Color(1.0, 0.14, 0.10), Color(0.78, 0.32, 1.0)]

var arena: Node = null
var fundo: Sprite2D = null

var _fixa: Sprite2D
var _efeitos: Node2D        # vapor (mistura normal)
var _luz: Node2D            # luzes (mistura somada)
var _faixa: CanvasLayer     # letreiro da troca de rodada (por cima das lanternas)
var _letreiro: Node2D
var _mat_base: ShaderMaterial
var _mat_fixa: ShaderMaterial

var _t := 0.0
var _fixo := false
var _tw: Tween = null
var _giro := 0.0            # tempo restante girando o giroflex
var _giro_cor := Color(1, 0.1, 0.05)
var _giro_arco := false     # vitória: gira nas 5 cores
var _pisca := 0.0
var _pisca_cor := Color.WHITE
var _led := 0.0             # s até a luz do alto voltar (0 = acesa)
var _led_clarao := 0.0
var _led_fumaca := 0.0
var _cacos_led: Array[Dictionary] = []
var _varre := -1.0          # 0..1 linha de varredura descendo
var _letreiro_t := -1.0
var _letreiro_txt := ""
var _letreiro_sub := ""
var _erro := 0.0
var _claroes: Array = []    # {pos, cor, t}
var _baforadas: Array = []  # {pos, vel, t, vida, tam}
var _faiscas: Array = []    # {pos, vel, t, vida}
var _poeira: Array = []     # {i, pos, vel, fase}
var _prox_vapor := 3.0
var _prox_faisca := 6.0
var _aquecer := 3


func _ready() -> void:
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mat_base = _material(Color(1.0, 0.18, 0.12), 0.0)
	if fundo != null:
		fundo.material = _mat_base
	_fixa = Sprite2D.new()
	_fixa.texture = FUNDO_FIXA
	_fixa.centered = false
	_fixa.modulate.a = 0.02           # desenhado já no início (sobe para a placa agora)
	_mat_fixa = _material(Color(0.7, 0.35, 1.0), 3.1)
	_fixa.material = _mat_fixa
	add_child(_fixa)

	_efeitos = Node2D.new()
	_efeitos.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_efeitos.draw.connect(_desenhar_efeitos)
	add_child(_efeitos)

	_luz = Node2D.new()
	_luz.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_luz.material = soma
	_luz.draw.connect(_desenhar_luz)
	add_child(_luz)

	_faixa = CanvasLayer.new()
	_faixa.layer = 90
	add_child(_faixa)
	_letreiro = Node2D.new()
	_letreiro.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_letreiro.draw.connect(_desenhar_letreiro)
	_faixa.add_child(_letreiro)

	for i in 2:
		for k in 9:
			_poeira.append({"i": i, "pos": Vector2(randf_range(-0.5, 0.5), randf()), "vel": Vector2(randf_range(-0.02, 0.02), randf_range(-0.03, 0.01)), "fase": randf() * TAU})


func _material(cor: Color, fase: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("mascara", MASCARA)
	m.set_shader_parameter("cor", Vector3(cor.r, cor.g, cor.b))
	m.set_shader_parameter("respiro", 0.0)
	m.set_shader_parameter("forca", 0.8)
	m.set_shader_parameter("fase", fase)
	return m


# ───────────────────────────────────────────── chamadas da arena
## Rodada fixa (true) ou de memória (false): troca a arte.
func modo(fixo: bool) -> void:
	if fixo == _fixo:
		return
	_fixo = fixo
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_fixa, "modulate:a", 1.0 if fixo else 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	_giro = 1.6
	_giro_arco = fixo
	_giro_cor = Color(1.0, 0.12, 0.06)
	_varre = 0.0
	_letreiro_t = 0.0
	_letreiro_txt = "SEQUÊNCIA FIXA" if fixo else "MEMÓRIA"
	_letreiro_sub = "ACERTE NA ORDEM DAS CORES" if fixo else "GRAVE A ORDEM DAS CORES"
	Maquina.efeito(SOM_TROCA, -4.0, 1.0 if fixo else 0.86)


func pulso_cor(c: Color) -> void:
	_pisca = 1.0
	_pisca_cor = c


func acerto(pos: Vector2, c: Color) -> void:
	_claroes.append({"pos": pos, "cor": c, "t": 0.0})
	if _claroes.size() > 6:
		_claroes.pop_front()


func erro() -> void:
	_erro = 1.0
	_giro = 1.3
	_giro_arco = false
	_giro_cor = Color(1.0, 0.08, 0.04)


func vitoria() -> void:
	_giro = 1.4
	_giro_arco = true
	for i in 2:
		_soltar_faiscas(_px(GIROFLEX) + Vector2(randf_range(-40, 40), 10), 10)


## Tiro no LED do alto: estoura (devolve true se pegou nele aceso).
func tiro_no_led(pos: Vector2) -> bool:
	if fundo == null or _led > 0.0:
		return false
	var p := (pos - fundo.position) / fundo.scale
	if not LED_CAIXA.grow(16.0).has_point(p):
		return false
	_led = LED_APAGADO
	_led_clarao = 1.0
	_led_fumaca = 0.0
	var g := _px(GIROFLEX)
	var esc := fundo.scale.x
	_soltar_faiscas(g, 26)
	for i in 14:
		_cacos_led.append({"pos": g + Vector2(randf_range(-22.0, 22.0), randf_range(-6.0, 8.0)) * esc,
			"vel": Vector2(randf_range(-150.0, 150.0), randf_range(-190.0, -20.0)), "rot": randf() * TAU,
			"giro": randf_range(-14.0, 14.0), "tam": randf_range(2.5, 5.5) * esc, "t": 0.0})
	Maquina.efeito(SOM_LED, -4.0, randf_range(0.95, 1.05))
	_efeitos.queue_redraw()
	return true


## Quanto a luz do alto está acesa agora (0 apagada .. 1; pisca ao voltar).
func _led_aceso() -> float:
	if _led <= 0.0:
		return 1.0
	if _led < 1.4:
		# volta piscando (cada vez mais acesa) até firmar
		return 1.0 if fmod(_led * 6.5, 1.0) > 0.35 + 0.4 * (_led / 1.4) else 0.0
	return 0.0


# ───────────────────────────────────────────── quadro a quadro
func _px(p: Vector2) -> Vector2:
	if fundo == null:
		return p
	return fundo.position + p * fundo.scale


func _process(delta: float) -> void:
	_t += delta
	if fundo == null:
		return
	if _aquecer > 0:
		_aquecer -= 1
		if _aquecer == 0 and not _fixo:
			_fixa.modulate.a = 0.0
		_letreiro.queue_redraw()
	_fixa.position = fundo.position
	_fixa.scale = fundo.scale
	_fixa.visible = _fixa.modulate.a > 0.004 or _aquecer > 0

	var som := Maquina.pulso_vivo()
	_mat_base.set_shader_parameter("grave", som.x)
	_mat_base.set_shader_parameter("batida", som.y)
	if _fixa.visible:
		_mat_fixa.set_shader_parameter("grave", som.x)
		_mat_fixa.set_shader_parameter("batida", som.y)

	_giro = maxf(0.0, _giro - delta)
	_pisca = maxf(0.0, _pisca - delta * 2.6)
	if _led > 0.0 or _led_clarao > 0.0 or not _cacos_led.is_empty():
		_animar_led(delta)
	_erro = maxf(0.0, _erro - delta * 1.6)
	if _varre >= 0.0:
		_varre += delta / 0.9
		if _varre > 1.0:
			_varre = -1.0
	if _letreiro_t >= 0.0:
		_letreiro_t += delta
		_letreiro.queue_redraw()
		if _letreiro_t > 1.9:
			_letreiro_t = -1.0
			_letreiro.queue_redraw()
	for c in _claroes:
		c["t"] += delta
	while not _claroes.is_empty() and _claroes[0]["t"] > 0.45:
		_claroes.pop_front()

	# vapor dos canos e faíscas da caixa elétrica
	_prox_vapor -= delta
	if _prox_vapor <= 0.0:
		_prox_vapor = randf_range(4.0, 8.5)
		var v: Vector2 = VAPOR[randi() % VAPOR.size()]
		var dir := Vector2(-1.0 if v.x > 512.0 else 1.0, -0.6).normalized()
		Maquina.efeito(SOM_VAPOR, -17.0, randf_range(0.85, 1.15))
		for i in 9:
			_baforadas.append({"pos": _px(v), "vel": dir.rotated(randf_range(-0.35, 0.35)) * randf_range(40.0, 110.0),
				"t": -i * 0.05, "vida": randf_range(1.2, 2.0), "tam": randf_range(16.0, 30.0)})
	_prox_faisca -= delta
	if _prox_faisca <= 0.0:
		_prox_faisca = randf_range(6.0, 13.0)
		_soltar_faiscas(_px(CAIXA_ELETRICA), randi_range(8, 14))
		Maquina.efeito(SOM_FAISCA, -15.0, randf_range(0.9, 1.1))
	for b in _baforadas:
		b["t"] += delta
		if b["t"] > 0.0:
			b["vel"] = b["vel"] * pow(0.55, delta) + Vector2(0, -16.0) * delta
			b["pos"] += b["vel"] * delta
	while not _baforadas.is_empty() and _baforadas[0]["t"] > _baforadas[0]["vida"]:
		_baforadas.pop_front()
	for f in _faiscas:
		f["t"] += delta
		f["vel"] += Vector2(0, 900.0) * delta
		f["pos"] += f["vel"] * delta
	while not _faiscas.is_empty() and _faiscas[0]["t"] > _faiscas[0]["vida"]:
		_faiscas.pop_front()
	for p in _poeira:
		p["pos"] += p["vel"] * delta
		if p["pos"].y < 0.0 or p["pos"].y > 1.0 or absf(p["pos"].x) > 0.6:
			p["pos"] = Vector2(randf_range(-0.5, 0.5), randf_range(0.6, 1.0))

	if not _baforadas.is_empty():
		_efeitos.queue_redraw()
	elif _efeitos.has_meta("sujo"):
		_efeitos.remove_meta("sujo")
		_efeitos.queue_redraw()
	if not _baforadas.is_empty():
		_efeitos.set_meta("sujo", true)
	_luz.queue_redraw()


func _animar_led(delta: float) -> void:
	var antes := _led
	_led = maxf(0.0, _led - delta)
	_led_clarao = maxf(0.0, _led_clarao - delta * 2.4)
	if _led > 1.4:
		# a lâmpada queimada solta fumaça e de vez em quando estala
		_led_fumaca -= delta
		if _led_fumaca <= 0.0:
			_led_fumaca = randf_range(0.25, 0.5)
			var g := _px(GIROFLEX)
			_baforadas.append({"pos": g + Vector2(randf_range(-10.0, 10.0), -4.0), "vel": Vector2(randf_range(-12.0, 12.0), randf_range(-40.0, -22.0)),
				"t": 0.0, "vida": randf_range(1.0, 1.6), "tam": randf_range(8.0, 14.0)})
			if randf() < 0.18:
				_soltar_faiscas(g, randi_range(3, 6))
	if antes >= 1.4 and _led < 1.4:
		Maquina.efeito(SOM_FAISCA, -14.0, 1.3)        # religando
	for c in _cacos_led:
		c["t"] += delta
		c["vel"] += Vector2(0.0, 900.0) * delta
		c["pos"] += c["vel"] * delta
		c["rot"] += c["giro"] * delta
	while not _cacos_led.is_empty() and _cacos_led[0]["t"] > 1.4:
		_cacos_led.pop_front()
	_efeitos.queue_redraw()


func _soltar_faiscas(de: Vector2, n: int) -> void:
	for i in n:
		_faiscas.append({"pos": de, "vel": Vector2(randf_range(-160.0, 160.0), randf_range(-260.0, -40.0)), "t": 0.0, "vida": randf_range(0.4, 0.9)})
	while _faiscas.size() > 60:
		_faiscas.pop_front()


# ───────────────────────────────────────────── desenho
func _desenhar_efeitos() -> void:
	# a luz do alto queimada: vidro escuro, trincado, e a parede sem o brilho
	if _led_aceso() < 0.5 and fundo != null:
		var esc := fundo.scale.x
		var g := _px(GIROFLEX)
		Pincel.brilho(_efeitos, g + Vector2(0.0, 8.0 * esc), 78.0 * esc, Color(0.0, 0.0, 0.0, 0.62))
		Pincel.brilho(_efeitos, g + Vector2(0.0, 34.0 * esc), 92.0 * esc, Color(0.0, 0.0, 0.0, 0.5))
		var r := Rect2(_px(LED_CAIXA.position + Vector2(3, 3)), (LED_CAIXA.size - Vector2(6, 6)) * esc)
		_efeitos.draw_rect(r, Color(0.10, 0.03, 0.03, 0.96))
		_efeitos.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.35)), Color(0.35, 0.12, 0.12, 0.35))
		var c := r.get_center() + Vector2(-4.0, 1.0) * esc
		for k in 5:
			var ang := k * 1.3 + 0.4
			_efeitos.draw_line(c, c + Vector2(cos(ang), sin(ang) * 0.5) * r.size.x * 0.42, Color(0.75, 0.62, 0.62, 0.55), 1.0)
	for b in _baforadas:
		var t: float = b["t"]
		if t <= 0.0:
			continue
		var k: float = t / b["vida"]
		var a := sin(minf(k, 1.0) * PI) * 0.22
		Pincel.forma(_efeitos, Pincel.FUMACA, b["pos"], b["tam"] * (0.6 + 1.6 * k), Color(0.78, 0.80, 0.84, a), k * 1.5)


func _desenhar_luz() -> void:
	var esc: float = fundo.scale.x if fundo != null else 1.0
	var som := Maquina.pulso_vivo()

	# fachos das arandelas (a luz desce pela parede) e a poeira dentro deles
	for i in 2:
		var a: Vector2 = _px(ARANDELAS[i])
		var dir := 1.0 if i == 0 else -1.0
		var comp := 520.0 * esc
		var cor_facho := Color(1.0, 0.92, 0.78, 0.06 + 0.03 * som.x)
		var pts := PackedVector2Array([a + Vector2(-8 * esc, 4), a + Vector2(8 * esc, 4),
			a + Vector2(dir * 210.0 * esc + 90.0 * esc, comp), a + Vector2(dir * 210.0 * esc - 90.0 * esc, comp)])
		var cores := PackedColorArray([cor_facho, cor_facho, Color(cor_facho, 0.0), Color(cor_facho, 0.0)])
		_luz.draw_polygon(pts, cores)
	for p in _poeira:
		var i: int = p["i"]
		var a2: Vector2 = _px(ARANDELAS[i])
		var dir2 := 1.0 if i == 0 else -1.0
		var y: float = p["pos"].y
		var x: float = p["pos"].x * (16.0 + 180.0 * y)
		var pos := a2 + Vector2((dir2 * 210.0 * y + x) * esc, 520.0 * y * esc)
		var brilho := (0.5 + 0.5 * sin(_t * 1.7 + p["fase"])) * (1.0 - y) * 0.55
		Pincel.circulo(_luz, pos, 1.6 * esc, Color(1.0, 0.92, 0.8, brilho))

	# giroflex
	var g := _px(GIROFLEX)
	var cor_g := Color(0.75, 0.3, 1.0) if _fixo else Color(1.0, 0.12, 0.06)
	if _pisca > 0.0:
		cor_g = cor_g.lerp(_pisca_cor, _pisca)
	var aceso := _led_aceso()
	if aceso > 0.0:
		Pincel.brilho(_luz, g, (34.0 + 26.0 * _pisca + 10.0 * som.y) * esc, Color(cor_g, (0.35 + 0.4 * _pisca) * aceso))
	if _led_clarao > 0.0:
		var kc := 1.0 - _led_clarao
		Pincel.brilho(_luz, g, (60.0 + 260.0 * kc) * esc, Color(1.0, 0.85, 0.75, 0.9 * _led_clarao))
		Pincel.brilho(_luz, g, (30.0 + 60.0 * kc) * esc, Color(1.0, 1.0, 1.0, _led_clarao))
	for c4 in _cacos_led:
		var kk: float = c4["t"] / 1.4
		var dc: Vector2 = Vector2(cos(c4["rot"]), sin(c4["rot"])) * float(c4["tam"])
		Pincel.linha(_luz, c4["pos"] - dc, c4["pos"] + dc, Color(1.0, 0.25, 0.18, 0.9 * (1.0 - kk)), 2.0)
	if _giro > 0.0 and aceso > 0.0:
		var forca := minf(1.0, _giro / 0.4)
		for k in 2:
			var ang := _t * 7.5 + k * PI
			var c := _giro_cor
			if _giro_arco:
				c = Color.from_hsv(fmod(_t * 0.9 + k * 0.5, 1.0), 0.85, 1.0)
			var dir3 := Vector2(cos(ang), sin(ang) * 0.45 + 0.35)
			var ponta := g + dir3 * 900.0 * esc
			var lado := Vector2(-dir3.y, dir3.x) * 170.0 * esc
			var pts2 := PackedVector2Array([g, ponta + lado, ponta - lado])
			var cc := Color(c, 0.20 * forca)
			_luz.draw_polygon(pts2, PackedColorArray([cc, Color(c, 0.0), Color(c, 0.0)]))
		Pincel.brilho(_luz, g, 70.0 * esc, Color(_giro_cor if not _giro_arco else Color.WHITE, 0.4 * forca))

	# luz das lanternas quebrando na parede
	for c2 in _claroes:
		var k2: float = c2["t"] / 0.45
		Pincel.brilho(_luz, c2["pos"], (80.0 + 160.0 * k2) * esc, Color(c2["cor"], 0.45 * (1.0 - k2)))

	# faíscas
	for f in _faiscas:
		var kf: float = f["t"] / f["vida"]
		var pf: Vector2 = f["pos"]
		Pincel.linha(_luz, pf, pf - (f["vel"] as Vector2) * 0.018, Color(1.0, 0.75 - 0.4 * kf, 0.3 - 0.2 * kf, 1.0 - kf), 2.2)
	if not _faiscas.is_empty():
		Pincel.brilho(_luz, _px(CAIXA_ELETRICA), 40.0 * esc, Color(1.0, 0.7, 0.3, 0.25 * randf()))

	# varredura colorida descendo a parede na troca de rodada
	if _varre >= 0.0:
		var tela := get_viewport_rect().size
		var y2 := lerpf(_px(Vector2(0, 470)).y, _px(Vector2(0, 1300)).y, _varre)
		var a3 := sin(_varre * PI)
		var n := 5
		for k3 in n:
			var c3: Color = CORES[k3] if _fixo else Color(1.0, 0.15, 0.1)
			var x0 := tela.x * k3 / n
			Pincel.laser(_luz, Vector2(x0, y2), Vector2(x0 + tela.x / n, y2), Color(c3, 0.9 * a3), 5.0)
			Pincel.laser(_luz, Vector2(x0, y2), Vector2(x0 + tela.x / n, y2), Color(c3, 0.25 * a3), 26.0)

	# erro: a parede fica vermelha um instante
	if _erro > 0.0:
		var tela2 := get_viewport_rect().size
		Pincel.brilho(_luz, tela2 * 0.5, tela2.y * 0.6, Color(1.0, 0.05, 0.02, 0.22 * _erro))

	_desenhar_ordem(esc)


## Faixa da ordem: 5 luzes (1 a 5) embaixo dos furos; a próxima pulsa.
func _desenhar_ordem(esc: float) -> void:
	if arena == null or not bool(arena.get("jogo_ativo")):
		return
	var seq: Array = arena.get("sequencia_atual")
	var total: int = seq.size()
	if total <= 0:
		return
	var proxima: int = int(arena.get("indice_sequencia"))
	var mostrando: bool = bool(arena.get("mostrando_sequencia"))
	var tela := get_viewport_rect().size
	var y := _px(Vector2(0, Y_ORDEM)).y
	var passo := 70.0 * esc
	var x0 := tela.x * 0.5 - passo * (CORES.size() - 1) * 0.5
	for i in CORES.size():
		var c: Color = CORES[i]
		var p := Vector2(x0 + passo * i, y)
		var ativa := i < total
		var r := 15.0 * esc
		if not ativa:
			Pincel.circulo(_luz, p, r * 0.7, Color(c, 0.10))
			continue
		var feita := i < proxima
		var vez := i == proxima and not mostrando
		var a := 0.35
		if feita:
			a = 0.9
		elif vez:
			a = 0.65 + 0.35 * sin(_t * 8.0)
			Pincel.brilho(_luz, p, r * 3.2, Color(c, 0.45))
			Pincel.anel(_luz, p, r * 1.55, 3.0 * esc, Color(c, 0.9))
		Pincel.brilho(_luz, p, r * 1.9, Color(c, a * 0.5))
		Pincel.circulo(_luz, p, r, Color(c, a))
		Pincel.circulo(_luz, p, r * 0.45, Color(1, 1, 1, a * 0.8))


func _desenhar_letreiro() -> void:
	if _aquecer > 0:
		# sobe as letras grandes para a placa já no começo (sem engasgo depois)
		_letreiro.draw_string(FONTE, Vector2(0, 200), "SEQUÊNCIA FIXA MEMÓRIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 92, Color(1, 1, 1, 0.01))
		_letreiro.draw_string(FONTE, Vector2(0, 300), "ACERTE NA ORDEM DAS CORES GRAVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 1, 1, 0.01))
	if _letreiro_t < 0.0:
		return
	var tela := get_viewport_rect().size
	var t := _letreiro_t
	# entra pela direita, para no meio e sai pela esquerda
	var x := 0.0
	if t < 0.35:
		x = tela.x * (1.0 - _suave(t / 0.35))
	elif t > 1.55:
		x = -tela.x * _suave((t - 1.55) / 0.35)
	var a := clampf(minf(t / 0.2, (1.9 - t) / 0.25), 0.0, 1.0)
	var y := tela.y * 0.5
	_letreiro.draw_rect(Rect2(Vector2(0, y - 92), Vector2(tela.x, 184)), Color(0.0, 0.0, 0.02, 0.62 * a))
	for k in 5:
		var c: Color = CORES[k] if _fixo else Color(1.0, 0.15, 0.1)
		_letreiro.draw_rect(Rect2(Vector2(tela.x * k / 5.0, y - 92), Vector2(tela.x / 5.0, 4)), Color(c, a))
		_letreiro.draw_rect(Rect2(Vector2(tela.x * k / 5.0, y + 88), Vector2(tela.x / 5.0, 4)), Color(c, a))
	var cor_txt := Color(1, 1, 1, a)
	_letreiro.draw_string_outline(FONTE, Vector2(x, y + 20), _letreiro_txt, HORIZONTAL_ALIGNMENT_CENTER, tela.x, 92, 14, Color(0, 0, 0, a))
	_letreiro.draw_string(FONTE, Vector2(x, y + 20), _letreiro_txt, HORIZONTAL_ALIGNMENT_CENTER, tela.x, 92, cor_txt)
	_letreiro.draw_string(FONTE, Vector2(x, y + 68), _letreiro_sub, HORIZONTAL_ALIGNMENT_CENTER, tela.x, 34, Color(1.0, 0.9, 0.55, a))


static func _suave(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
