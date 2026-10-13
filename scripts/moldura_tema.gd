class_name MolduraTema
extends Control

## MOLDURA DE CADA CENÁRIO para os modais (missão no menu e COMO JOGAR na
## fase). Fica atrás do conteúdo do painel e decora conforme o lugar:
##
##   deserto  areia escura com raios de sol girando atrás do título, asas
##            douradas, faixas de hieróglifos em cima e embaixo, cantos de
##            ouro e brilhos piscando
##   mar      azul profundo com feixes de luz balançando, bolhas subindo,
##            ondas no topo, algas e corais nos cantos de baixo
##   bar      tábuas de madeira com pregos, fita de corda na borda, estrelas
##            de xerife nos cantos, furos de bala e a luz quente do lampião
##   arena    metal escuro com grade, cantos de mira em neon, LEDs piscando,
##            laser varrendo e faixa de perigo embaixo
##
## Tudo desenhado na hora (sem imagem nova), com poucas formas: leve para a
## TV Box. `titulo_y` é a altura do centro do título (raios e asas). O
## conteúdo deixa MARGEM livre em cima e embaixo para as faixas da moldura.

const MARGEM := 56.0

const Pincel := preload("res://scripts/pincel.gd")

var tema := ""
var titulo_y := 120.0
var _t := 0.0
var _bolhas: Array = []     # [x, fase, velocidade, raio]
var _brilhos: Array = []    # [pos, fase]


static func criar(p_tema: String, p_titulo_y: float) -> MolduraTema:
	var m := MolduraTema.new()
	m.tema = p_tema
	m.titulo_y = p_titulo_y
	return m


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tema)
	for i in 16:
		_bolhas.append([rng.randf(), rng.randf(), rng.randf_range(0.05, 0.12), rng.randf_range(5.0, 13.0)])
	for i in 7:
		_brilhos.append([Vector2(rng.randf(), rng.randf()), rng.randf() * TAU])


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


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


# ───────────────────────────────────────────── ajudas

func _s() -> float:
	return get_viewport_rect().size.x / 1024.0


## Retângulo de cantos redondos (polígono), para pintar dentro do painel.
func _arredondado(r: Rect2, raio: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cantos := [
		[r.position + Vector2(r.size.x - raio, raio), -PI * 0.5],
		[r.position + Vector2(r.size.x - raio, r.size.y - raio), 0.0],
		[r.position + Vector2(raio, r.size.y - raio), PI * 0.5],
		[r.position + Vector2(raio, raio), PI],
	]
	for c in cantos:
		for i in 7:
			var a: float = c[1] + (PI * 0.5) * i / 6.0
			pts.append(c[0] + Vector2(cos(a), sin(a)) * raio)
	return pts


## Pinta o fundo com degradê vertical (cor de cima -> cor de baixo).
func _fundo(cima: Color, baixo: Color, inset: float) -> void:
	var r := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	var pts := _arredondado(r, 30.0 * _s())
	var cores := PackedColorArray()
	for p in pts:
		cores.append(cima.lerp(baixo, clampf((p.y - r.position.y) / r.size.y, 0.0, 1.0)))
	draw_polygon(pts, cores)


func _estrela(c: Vector2, r: float, pontas: int, cor: Color, giro: float = -PI * 0.5) -> void:
	var pts := PackedVector2Array()
	for i in pontas * 2:
		var rr := r if i % 2 == 0 else r * 0.45
		var a := giro + i * PI / pontas
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, cor)


func _brilho_estrela(c: Vector2, r: float, cor: Color) -> void:
	# brilho de 4 pontas (cruz fina)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.18, 0), c + Vector2(0, r), c + Vector2(-r * 0.18, 0)]), cor)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(0, r * 0.18), c + Vector2(r, 0), c + Vector2(0, -r * 0.18)]), cor)


# ───────────────────────────────────────────── EGITO

func _deserto() -> void:
	var s := _s()
	var ouro := Color(1.0, 0.78, 0.30)
	_fundo(Color(0.16, 0.09, 0.03, 0.96), Color(0.05, 0.03, 0.01, 0.96), 4.0 * s)
	# raios de sol girando atrás do título
	var c := Vector2(size.x * 0.5, titulo_y)
	var giro := _t * 0.12
	for i in 18:
		var a := giro + i * TAU / 18.0
		var d1 := Vector2(cos(a - 0.05), sin(a - 0.05))
		var d2 := Vector2(cos(a + 0.05), sin(a + 0.05))
		draw_colored_polygon(PackedVector2Array([c, c + d1 * size.x * 0.75, c + d2 * size.x * 0.75]), Color(1.0, 0.75, 0.25, 0.07))
	Pincel.brilho(self, c, 230.0 * s, Color(1.0, 0.7, 0.2, 0.22 + 0.06 * sin(_t * 2.0)))
	# asas douradas dos dois lados do título
	for lado in [-1.0, 1.0]:
		for k in 5:
			var base := c + Vector2(lado * (250.0 + k * 6.0) * s, (k * 9.0 - 6.0) * s)
			var ponta := base + Vector2(lado * (150.0 - k * 22.0) * s, (-26.0 + k * 13.0) * s)
			draw_line(base, ponta, Color(ouro, 0.85 - k * 0.12), (7.0 - k) * s, true)
	# faixas de hieróglifos em cima e embaixo
	for y in [26.0 * s, size.y - 30.0 * s]:
		draw_line(Vector2(40 * s, y - 16 * s), Vector2(size.x - 40 * s, y - 16 * s), Color(ouro, 0.45), 2.0 * s)
		draw_line(Vector2(40 * s, y + 16 * s), Vector2(size.x - 40 * s, y + 16 * s), Color(ouro, 0.45), 2.0 * s)
		var x := 70.0 * s
		var i := 0
		while x < size.x - 60.0 * s:
			_hieroglifo(Vector2(x, y), i % 4, 12.0 * s, Color(ouro, 0.55))
			x += 58.0 * s
			i += 1
	# cantos de ouro
	for canto in [Vector2(30, 30), Vector2(size.x / s - 30, 30), Vector2(30, size.y / s - 30), Vector2(size.x / s - 30, size.y / s - 30)]:
		var p: Vector2 = canto * s
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -14) * s, p + Vector2(14, 0) * s, p + Vector2(0, 14) * s, p + Vector2(-14, 0) * s]), Color(ouro, 0.9))
		Pincel.circulo(self, p, 4.0 * s, Color(0.2, 0.08, 0.02))
	# brilhos de ouro piscando
	for b in _brilhos:
		var k := maxf(0.0, sin(_t * 1.6 + b[1]))
		if k > 0.05:
			_brilho_estrela(Vector2(b[0].x * size.x, 60 * s + b[0].y * (size.y - 120 * s)), 12.0 * s * k, Color(1.0, 0.9, 0.55, 0.7 * k))


func _hieroglifo(p: Vector2, tipo: int, r: float, cor: Color) -> void:
	match tipo:
		0:   # olho
			draw_arc(p, r, PI * 1.1, PI * 1.9, 8, cor, r * 0.18, true)
			draw_arc(p + Vector2(0, -r * 0.9), r, PI * 0.1, PI * 0.9, 8, cor, r * 0.18, true)
			Pincel.circulo(self, p + Vector2(0, -r * 0.45), r * 0.3, cor)
			draw_line(p + Vector2(-r * 0.2, -r * 0.1), p + Vector2(-r * 0.5, r * 0.9), cor, r * 0.16)
		1:   # ankh
			draw_arc(p + Vector2(0, -r * 0.55), r * 0.38, 0, TAU, 10, cor, r * 0.18, true)
			draw_line(p + Vector2(0, -r * 0.15), p + Vector2(0, r), cor, r * 0.2)
			draw_line(p + Vector2(-r * 0.55, r * 0.1), p + Vector2(r * 0.55, r * 0.1), cor, r * 0.2)
		2:   # pena
			draw_line(p + Vector2(0, r), p + Vector2(0, -r), cor, r * 0.12)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.45, -r * 0.2), p + Vector2(0, r * 0.6)]), cor)
		_:   # sol com raios
			Pincel.circulo(self, p, r * 0.42, cor)
			for k in 6:
				var a := k * TAU / 6.0
				draw_line(p + Vector2(cos(a), sin(a)) * r * 0.6, p + Vector2(cos(a), sin(a)) * r, cor, r * 0.12)


# ───────────────────────────────────────────── MAR

func _mar() -> void:
	var s := _s()
	_fundo(Color(0.03, 0.14, 0.26, 0.96), Color(0.01, 0.03, 0.09, 0.96), 4.0 * s)
	# feixes de luz entrando na água, balançando
	for i in 5:
		var x := size.x * (0.12 + i * 0.2) + sin(_t * 0.5 + i) * 30.0 * s
		var w := 60.0 * s + i * 8.0 * s
		var pts := PackedVector2Array([Vector2(x, 0), Vector2(x + w, 0), Vector2(x + w * 2.6 - 120 * s, size.y), Vector2(x - 120 * s, size.y)])
		draw_polygon(pts, PackedColorArray([Color(0.6, 0.9, 1.0, 0.10), Color(0.6, 0.9, 1.0, 0.10), Color(0.6, 0.9, 1.0, 0.0), Color(0.6, 0.9, 1.0, 0.0)]))
	# ondas no topo
	for k in 2:
		var pts := PackedVector2Array()
		var y0 := (22.0 + k * 14.0) * s
		for i in 41:
			var x := 30.0 * s + (size.x - 60.0 * s) * i / 40.0
			pts.append(Vector2(x, y0 + sin(i * 0.7 + _t * (1.6 + k) + k) * 5.0 * s))
		draw_polyline(pts, Color(0.55, 0.9, 1.0, 0.55 - k * 0.2), 3.0 * s, true)
	# algas balançando e corais nos cantos de baixo
	for lado in [0.0, 1.0]:
		var bx: float = lerpf(44.0 * s, size.x - 44.0 * s, lado)
		for k in 4:
			var pts := PackedVector2Array()
			var x0: float = bx + (k * 18.0 - 27.0) * s * (1.0 if lado == 0.0 else -1.0)
			var alto := (90.0 + k * 26.0) * s
			for i in 9:
				var f := i / 8.0
				pts.append(Vector2(x0 + sin(_t * 1.3 + k + f * 3.0) * 12.0 * s * f, size.y - 8.0 * s - alto * f))
			draw_polyline(pts, Color(0.15, 0.75, 0.45, 0.55), (9.0 - k) * s, true)
		for k in 3:
			Pincel.circulo(self, Vector2(bx + (k * 22.0 - 22.0) * s, size.y - 14.0 * s - k * 6.0 * s), (16.0 - k * 3.0) * s, Color(1.0, 0.45, 0.45, 0.45))
	# cardume de peixes passando ao fundo
	for i in 3:
		var dir := 1.0 if i % 2 == 0 else -1.0
		var f := fposmod(_t * (0.05 + i * 0.015) + i * 0.37, 1.0)
		var x: float = lerpf(-80.0 * s, size.x + 80.0 * s, f if dir > 0.0 else 1.0 - f)
		var y: float = size.y * (0.30 + i * 0.22) + sin(_t * 1.1 + i) * 16.0 * s
		for k in 4:
			_peixe(Vector2(x - dir * k * 46.0 * s, y + sin(k * 2.1 + i) * 22.0 * s), dir, (18.0 - k * 2.0) * s, Color(0.65, 0.90, 1.0, 0.20))
	# bolhas subindo
	for b in _bolhas:
		var f := fposmod(b[1] + _t * b[2], 1.0)
		var p := Vector2(30 * s + b[0] * (size.x - 60 * s) + sin(_t * 2.0 + b[1] * 9.0) * 8.0 * s, size.y * (1.0 - f))
		var a := sin(f * PI) * 0.85
		Pincel.anel(self, p, b[3] * 1.3 * s, 2.0 * s, Color(0.75, 0.95, 1.0, a))
		Pincel.circulo(self, p + Vector2(-b[3] * 0.45, -b[3] * 0.45) * s, b[3] * 0.3 * s, Color(1, 1, 1, a))


func _peixe(c: Vector2, dir: float, r: float, cor: Color) -> void:
	var corpo := PackedVector2Array()
	for i in 12:
		var a := i * TAU / 12.0
		corpo.append(c + Vector2(cos(a) * r * dir, sin(a) * r * 0.45))
	draw_colored_polygon(corpo, cor)
	var cauda := c - Vector2(r * 0.9 * dir, 0)
	draw_colored_polygon(PackedVector2Array([cauda, cauda - Vector2(r * 0.6 * dir, -r * 0.45), cauda - Vector2(r * 0.6 * dir, r * 0.45)]), cor)


# ───────────────────────────────────────────── BAR

func _bar() -> void:
	var s := _s()
	var inset := 4.0 * s
	var r := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	_fundo(Color(0.22, 0.12, 0.05, 0.97), Color(0.12, 0.06, 0.02, 0.97), inset)
	# tábuas: emendas, veios e pregos
	var tabua := 96.0 * s
	var y := r.position.y + tabua
	var linha := 0
	while y < r.end.y - 20.0 * s:
		draw_line(Vector2(r.position.x + 12 * s, y), Vector2(r.end.x - 12 * s, y), Color(0.05, 0.02, 0.0, 0.85), 4.0 * s)
		draw_line(Vector2(r.position.x + 12 * s, y + 3 * s), Vector2(r.end.x - 12 * s, y + 3 * s), Color(0.45, 0.28, 0.12, 0.35), 1.5 * s)
		for px in [r.position.x + 34 * s, r.end.x - 34 * s]:
			Pincel.circulo(self, Vector2(px, y - tabua * 0.5), 5.0 * s, Color(0.55, 0.55, 0.58, 0.9))
			Pincel.circulo(self, Vector2(px - 1.2 * s, y - tabua * 0.5 - 1.2 * s), 2.0 * s, Color(0.9, 0.9, 0.95, 0.8))
		# veio da madeira
		var veio := PackedVector2Array()
		for i in 13:
			var x := r.position.x + 60 * s + (r.size.x - 120 * s) * i / 12.0
			veio.append(Vector2(x, y - tabua * (0.35 + 0.1 * (linha % 3)) + sin(i * 1.3 + linha) * 6.0 * s))
		draw_polyline(veio, Color(0.40, 0.24, 0.10, 0.30), 2.0 * s, true)
		y += tabua
		linha += 1
	# luz quente do lampião (tremula)
	Pincel.brilho(self, Vector2(size.x * 0.5, 30 * s), 420.0 * s, Color(1.0, 0.65, 0.25, 0.20 + 0.04 * sin(_t * 9.0) * sin(_t * 3.1)))
	# corda na borda
	var passo := 22.0 * s
	var borda := Rect2(r.position + Vector2(10, 10) * s, r.size - Vector2(20, 20) * s)
	var lados := [[borda.position, Vector2(borda.end.x, borda.position.y)], [Vector2(borda.end.x, borda.position.y), borda.end],
		[borda.end, Vector2(borda.position.x, borda.end.y)], [Vector2(borda.position.x, borda.end.y), borda.position]]
	for l in lados:
		var a: Vector2 = l[0]
		var b: Vector2 = l[1]
		var n := int(a.distance_to(b) / passo)
		var dir := (b - a).normalized()
		var nor := Vector2(-dir.y, dir.x)
		for i in n:
			var p := a + dir * (i + 0.5) * passo
			draw_line(p - dir * passo * 0.42 - nor * 4.0 * s, p + dir * passo * 0.42 + nor * 4.0 * s, Color(0.85, 0.70, 0.45, 0.8), 4.0 * s)
	# estrelas de xerife nos cantos
	for canto in [borda.position, Vector2(borda.end.x, borda.position.y), Vector2(borda.position.x, borda.end.y), borda.end]:
		_estrela(canto, 24.0 * s, 5, Color(0.95, 0.75, 0.25))
		Pincel.circulo(self, canto, 7.0 * s, Color(0.55, 0.38, 0.10))
	# furos de bala
	for f in [Vector2(0.08, 0.22), Vector2(0.93, 0.46), Vector2(0.11, 0.72)]:
		var p := Vector2(f.x * size.x, f.y * size.y)
		Pincel.circulo(self, p, 9.0 * s, Color(0.08, 0.04, 0.02, 0.9))
		Pincel.anel(self, p, 11.0 * s, 2.0 * s, Color(0.55, 0.35, 0.15, 0.7))
		for k in 4:
			var a: float = k * 1.7 + f.x * 10.0
			draw_line(p + Vector2(cos(a), sin(a)) * 11.0 * s, p + Vector2(cos(a), sin(a)) * 22.0 * s, Color(0.06, 0.03, 0.01, 0.6), 1.5 * s)


# ───────────────────────────────────────────── ARENA

func _arena() -> void:
	var s := _s()
	var neon := Color(1.0, 0.18, 0.15)
	_fundo(Color(0.09, 0.09, 0.10, 0.96), Color(0.03, 0.03, 0.04, 0.96), 4.0 * s)
	# grade fina
	var passo := 64.0 * s
	var x := passo
	while x < size.x:
		draw_line(Vector2(x, 8 * s), Vector2(x, size.y - 8 * s), Color(neon, 0.05), 1.0)
		x += passo
	var y := passo
	while y < size.y:
		draw_line(Vector2(8 * s, y), Vector2(size.x - 8 * s, y), Color(neon, 0.05), 1.0)
		y += passo
	# laser varrendo de cima a baixo
	var ly := fposmod(_t * 0.35, 1.0) * size.y
	draw_rect(Rect2(10 * s, ly - 18 * s, size.x - 20 * s, 36 * s), Color(neon, 0.05))
	draw_line(Vector2(10 * s, ly), Vector2(size.x - 10 * s, ly), Color(neon, 0.35), 2.0 * s)
	# lasers cruzando atrás do título
	var k := 0.5 + 0.5 * sin(_t * 3.0)
	draw_line(Vector2(0, titulo_y - 60 * s), Vector2(size.x, titulo_y + 50 * s), Color(neon, 0.18 + 0.15 * k), 3.0 * s)
	draw_line(Vector2(0, titulo_y + 50 * s), Vector2(size.x, titulo_y - 60 * s), Color(neon, 0.18 + 0.15 * (1.0 - k)), 3.0 * s)
	# cantos de mira em neon com LED
	var m := 22.0 * s
	var l := 70.0 * s
	for canto in [[Vector2(m, m), Vector2(1, 1)], [Vector2(size.x - m, m), Vector2(-1, 1)], [Vector2(m, size.y - m), Vector2(1, -1)], [Vector2(size.x - m, size.y - m), Vector2(-1, -1)]]:
		var p: Vector2 = canto[0]
		var d: Vector2 = canto[1]
		draw_line(p, p + Vector2(l * d.x, 0), neon, 5.0 * s)
		draw_line(p, p + Vector2(0, l * d.y), neon, 5.0 * s)
		var led := 0.5 + 0.5 * sin(_t * 5.0 + p.x * 0.01 + p.y * 0.02)
		Pincel.brilho(self, p + d * 18.0 * s, 16.0 * s, Color(neon, 0.6 * led))
		Pincel.circulo(self, p + d * 18.0 * s, 4.0 * s, Color(1.0, 0.6 + 0.4 * led, 0.5))
	# faixa de perigo embaixo
	var fy := size.y - 30.0 * s
	var listra := 26.0 * s
	var xx := 40.0 * s
	var i := 0
	while xx < size.x - 60.0 * s:
		var cor := Color(1.0, 0.80, 0.10, 0.55) if i % 2 == 0 else Color(0.05, 0.05, 0.05, 0.55)
		draw_colored_polygon(PackedVector2Array([Vector2(xx, fy + 10 * s), Vector2(xx + listra, fy + 10 * s), Vector2(xx + listra + 12 * s, fy - 10 * s), Vector2(xx + 12 * s, fy - 10 * s)]), cor)
		xx += listra
		i += 1
