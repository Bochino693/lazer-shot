extends Node2D
class_name Moldura

## MOLDURA DE CADA CENÁRIO para os modais (missão na escolha de cenário e
## COMO JOGAR na fase). Fica atrás do conteúdo do painel e decora conforme o
## lugar:
##
##   deserto  raios de sol girando atrás do título, faixas de losangos
##            dourados em cima e embaixo e brilhos piscando
##   mar      feixes de luz balançando, bolhas subindo, ondas no topo e
##            algas nos cantos de baixo
##   bar      tábuas de madeira com pregos, estrelas de xerife nos cantos,
##            furos de bala e a luz quente do lampião
##   arena    grade de metal, cantos de mira em neon, LEDs piscando, laser
##            varrendo e faixa de perigo embaixo
##
## Desenhada na hora com poucas formas (leve para a TV Box) e só anima
## enquanto está na tela. `titulo_y` é a altura do centro do título.

const MARGEM = 56.0

var tema = ""
var tam = Vector2(900, 900)
var cor = Color.white
var titulo_y = 120.0

var _t = 0.0
var _bolhas = []      # [x, fase, velocidade, raio]
var _brilhos = []     # [pos, fase]
var _furos = []       # [pos, giro]


static func criar(pai: Node, p_tema: String, p_tam: Vector2, p_cor: Color, p_titulo_y: float) -> Node2D:
	var m = load("res://scripts/moldura.gd").new()
	m.tema = p_tema
	m.tam = p_tam
	m.cor = p_cor
	m.titulo_y = p_titulo_y
	pai.add_child(m)
	return m


func _ready() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(tema)
	for i in 16:
		_bolhas.append([rng.randf(), rng.randf(), rng.randf_range(0.05, 0.12), rng.randf_range(5.0, 13.0)])
	for i in 7:
		_brilhos.append([Vector2(rng.randf(), rng.randf()), rng.randf() * TAU])
	for i in 3:
		_furos.append([Vector2(rng.randf_range(0.1, 0.9), rng.randf_range(0.15, 0.85)), rng.randf() * TAU])


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	update()


func _draw() -> void:
	match tema:
		"deserto":
			_deserto()
		"mar":
			_mar()
		"bar":
			_bar()
		"arena":
			_arena()


func _brilho(p: Vector2, r: float, c: Color) -> void:
	draw_texture_rect(Estilo.tex("fx_brilho"), Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, c)


func _estrela(c: Vector2, r: float, pontas: int, interno: float, giro: float, cor_e: Color) -> void:
	var pts = PoolVector2Array()
	for i in pontas * 2:
		var a = giro - PI / 2.0 + i * PI / pontas
		var rr = r if i % 2 == 0 else r * interno
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, cor_e)


# ------------------------------------------------------------ deserto
func _deserto() -> void:
	var centro = Vector2(tam.x * 0.5, titulo_y)
	# raios de sol girando atrás do título
	var raios = 14
	for i in raios:
		var a = _t * 0.25 + i * TAU / raios
		var d1 = Vector2(cos(a - 0.07), sin(a - 0.07))
		var d2 = Vector2(cos(a + 0.07), sin(a + 0.07))
		var comp = tam.x * 0.62
		draw_colored_polygon(PoolVector2Array([centro, centro + d1 * comp, centro + d2 * comp]), Color(1.0, 0.78, 0.30, 0.055))
	_brilho(centro, tam.x * 0.30, Color(1.0, 0.75, 0.3, 0.10))
	# faixas de losangos dourados em cima e embaixo
	var c = Color(cor.r, cor.g, cor.b, 0.85)
	var k = 0
	var x = 36.0
	while x < tam.x - 30.0:
		for y in [16.0, tam.y - 16.0]:
			var p = Vector2(x, y)
			var r = 7.0 if k % 3 == 0 else 4.0
			draw_colored_polygon(PoolVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), c)
		x += 30.0
		k += 1
	# brilhos piscando
	for b in _brilhos:
		var a2 = 0.5 + 0.5 * sin(_t * 2.6 + b[1])
		var p2 = Vector2(b[0].x * tam.x, 40.0 + b[0].y * (tam.y - 80.0))
		_estrela(p2, 9.0 * a2 + 2.0, 4, 0.3, 0.0, Color(1.0, 0.92, 0.6, 0.55 * a2))


# ------------------------------------------------------------ mar
func _mar() -> void:
	# feixes de luz balançando
	for i in 3:
		var x = tam.x * (0.22 + 0.28 * i) + sin(_t * 0.6 + i * 1.7) * 40.0
		var larg = 70.0 + 20.0 * i
		draw_colored_polygon(PoolVector2Array([Vector2(x - larg * 0.4, 0), Vector2(x + larg * 0.4, 0),
			Vector2(x + larg * 1.6, tam.y), Vector2(x - larg * 0.2, tam.y)]), Color(0.55, 0.85, 1.0, 0.05))
	# ondas no topo
	var onda = PoolVector2Array()
	for i in 41:
		var x2 = tam.x * i / 40.0
		onda.append(Vector2(x2, 18.0 + 6.0 * sin(x2 * 0.035 + _t * 2.0)))
	draw_polyline(onda, Color(0.7, 0.95, 1.0, 0.55), 3.0)
	# bolhas subindo
	for b in _bolhas:
		var k = fmod(b[1] + _t * b[2], 1.0)
		var p = Vector2(b[0] * tam.x + sin(_t * 1.3 + b[1] * 9.0) * 10.0, tam.y - 30.0 - k * (tam.y - 60.0))
		draw_arc(p, b[3], 0, TAU, 16, Color(0.75, 0.95, 1.0, 0.45 * (1.0 - k)), 2.0)
	# algas nos cantos de baixo
	for lado in [0, 1]:
		for j in 3:
			var base = Vector2(24.0 + j * 18.0 if lado == 0 else tam.x - 24.0 - j * 18.0, tam.y - 6.0)
			var pts = PoolVector2Array()
			for s in 7:
				var h = s * 14.0 + j * 6.0
				pts.append(base + Vector2(sin(_t * 1.4 + s * 0.6 + j) * (3.0 + s * 1.5), -h))
			draw_polyline(pts, Color(0.2, 0.8, 0.5, 0.6), 4.0)


# ------------------------------------------------------------ bar
func _bar() -> void:
	# luz quente do lampião
	_brilho(Vector2(tam.x * 0.5, titulo_y), tam.x * 0.45, Color(1.0, 0.62, 0.25, 0.10 + 0.03 * sin(_t * 3.0)))
	# tábuas e veios
	var y = 60.0
	while y < tam.y - 40.0:
		draw_line(Vector2(14, y), Vector2(tam.x - 14, y + 2.0), Color(0.55, 0.32, 0.14, 0.22), 2.0)
		y += 74.0
	# pregos e estrelas de xerife nos cantos
	var c = Color(cor.r, cor.g, cor.b, 0.85)
	for p in [Vector2(24, 24), Vector2(tam.x - 24, 24), Vector2(24, tam.y - 24), Vector2(tam.x - 24, tam.y - 24)]:
		_estrela(p, 14.0, 5, 0.45, 0.0, c)
		draw_circle(p, 3.0, Color(0.2, 0.12, 0.05, 0.9))
	# furos de bala na madeira
	for f in _furos:
		var p2 = Vector2(f[0].x * tam.x, f[0].y * tam.y)
		draw_circle(p2, 9.0, Color(0.08, 0.04, 0.02, 0.45))
		draw_circle(p2, 5.0, Color(0.02, 0.01, 0.0, 0.8))
		for k in 5:
			var a = f[1] + k * 1.25
			draw_line(p2 + Vector2(cos(a), sin(a)) * 7.0, p2 + Vector2(cos(a), sin(a)) * 16.0, Color(0.1, 0.05, 0.02, 0.4), 1.5)


# ------------------------------------------------------------ arena
func _arena() -> void:
	# grade de metal
	var g = Color(1.0, 1.0, 1.0, 0.035)
	var x = 0.0
	while x < tam.x:
		draw_line(Vector2(x, 0), Vector2(x, tam.y), g, 1.0)
		x += 48.0
	var y = 0.0
	while y < tam.y:
		draw_line(Vector2(0, y), Vector2(tam.x, y), g, 1.0)
		y += 48.0
	# laser varrendo
	var ly = fmod(_t * 160.0, tam.y + 200.0) - 100.0
	if ly > 0.0 and ly < tam.y:
		draw_line(Vector2(20, ly), Vector2(tam.x - 20, ly), Color(1.0, 0.15, 0.1, 0.22), 2.0)
		_brilho(Vector2(tam.x * 0.5, ly), 60.0, Color(1.0, 0.1, 0.05, 0.08))
	# cantos de mira em neon
	var c = Color(cor.r, cor.g, cor.b, 0.95)
	var l = 46.0
	var m = 16.0
	for canto in [[Vector2(m, m), Vector2(1, 1)], [Vector2(tam.x - m, m), Vector2(-1, 1)],
			[Vector2(m, tam.y - m), Vector2(1, -1)], [Vector2(tam.x - m, tam.y - m), Vector2(-1, -1)]]:
		var p: Vector2 = canto[0]
		var d: Vector2 = canto[1]
		draw_line(p, p + Vector2(l * d.x, 0), c, 4.0)
		draw_line(p, p + Vector2(0, l * d.y), c, 4.0)
	# LEDs piscando no topo
	for i in 9:
		var p2 = Vector2(tam.x * (0.1 + 0.1 * i), 10.0)
		var aceso = fmod(_t * 3.0 + i * 0.37, 1.0) > 0.5
		draw_circle(p2, 4.0, Color(1.0, 0.2, 0.15, 0.95 if aceso else 0.25))
	# faixa de perigo embaixo
	var xx = 30.0
	while xx < tam.x - 40.0:
		draw_colored_polygon(PoolVector2Array([Vector2(xx, tam.y - 10), Vector2(xx + 16, tam.y - 10), Vector2(xx + 30, tam.y - 24),
			Vector2(xx + 14, tam.y - 24)]), Color(1.0, 0.8, 0.1, 0.8))
		xx += 34.0
