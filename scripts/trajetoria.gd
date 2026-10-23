extends CanvasLayer
class_name Trajetoria

## O TIRO DE CADA CENÁRIO, saindo da arma (embaixo da tela, puxada para o
## lado da mira) até o ponto:
##
##   laser (Arena)  o LASER DA ABERTURA: feixe vermelho com halo, faixa e
##                  miolo branco e um pulso correndo até o alvo; no ponto o
##                  clarão, o anel de choque e as faíscas em brasa
##   sol   (Egito)  LASER AMARELO do sol, com brilhos soltos subindo pelo
##                  caminho; no ponto a estrela de luz girando
##   lua   (Egito)  LASER BRANCO do luar, com pó de estrela pelo caminho; no
##                  ponto um anel frio abrindo
##   mar   (Mar)    LASER COR DE ÁGUA, com um rastro de bolhas subindo; no
##                  ponto as ondas abrindo e mais bolhas
##   bar   (Bar)    BALA de revólver, sem laser: o clarão da boca da arma e a
##                  bala traçante correndo até o ponto; lá a faísca e a
##                  fumaça
##   menu           (telas de fora das fases) anéis fechando no ponto
##
## O laser acende inteiro na hora e apaga em seguida; a bala voa. Os feixes
## são uma textura macia esticada (luz somada): poucos quadrados, leve para
## a Mali-450. Só redesenha enquanto há tiro no ar.

const IMPACTO = 0.35
# os lasers: voo do pulso (s), vida do feixe (s), cores [halo, faixa, miolo]
# (com o alfa) e larguras [halo, faixa, miolo] (px)
const FEIXES = {
	"laser": [0.07, 0.17, [Color(1.0, 0.16, 0.20, 0.36), Color(1.0, 0.22, 0.24, 0.66), Color(1.0, 0.86, 0.86, 1.0)], [64.0, 24.0, 7.0]],
	"sol": [0.08, 0.26, [Color(1.0, 0.60, 0.10, 0.32), Color(1.0, 0.82, 0.28, 0.66), Color(1.0, 0.98, 0.80, 1.0)], [84.0, 28.0, 8.0]],
	"lua": [0.08, 0.28, [Color(0.80, 0.88, 1.0, 0.28), Color(0.94, 0.97, 1.0, 0.62), Color(1.0, 1.0, 1.0, 1.0)], [76.0, 26.0, 8.0]],
	"mar": [0.09, 0.20, [Color(0.10, 0.72, 0.84, 0.34), Color(0.40, 0.92, 1.0, 0.66), Color(0.86, 1.0, 1.0, 1.0)], [64.0, 22.0, 7.0]],
}
const BALA_VOO = 0.07          # s da arma até o ponto
const BALA_RASTRO = 150.0      # px do risco da bala traçante
# telas de fora (anéis): voo, raio de saída, cor dos anéis, do núcleo e do clarão
const MENU = [0.07, 90.0, Color(1.0, 0.20, 0.22), Color(1.0, 0.85, 0.80), Color(1.0, 0.30, 0.25)]

var _luz: Node2D
var _tiros = []
var _brilhos: Particulas
var _fumaca: Particulas
var _t_anel: Texture
var _t_ponto: Texture
var _t_brilho: Texture
var _t_estrela: Texture
var _t_laser: Texture
var _t_rastro: Texture


static func criar(pai: Node, camada: int = 15) -> Trajetoria:
	var t = load("res://scripts/trajetoria.gd").new()
	t.layer = camada
	pai.add_child(t)
	return t


func _ready() -> void:
	_t_anel = Estilo.tex("fx_anel")
	_t_ponto = Estilo.tex("fx_ponto")
	_t_brilho = Estilo.tex("fx_brilho")
	_t_estrela = Estilo.tex("fx_estrela")
	_t_laser = Estilo.tex("fx_laser")
	_t_rastro = Estilo.tex("fx_rastro")
	_fumaca = Particulas.new()
	add_child(_fumaca)
	_luz = Node2D.new()
	_luz.material = Estilo.material_soma()
	_luz.connect("draw", self, "_desenhar")
	add_child(_luz)
	_brilhos = Particulas.new()
	_brilhos.somar = true
	add_child(_brilhos)
	set_process(false)


## Um tiro em `p` (ponto da tela) no estilo do cenário.
func disparar(p: Vector2, estilo: String) -> void:
	if not FEIXES.has(estilo) and estilo != "bar" and estilo != "menu":
		estilo = "laser"
	var de = Vector2(lerp(Tela.TELA.x * 0.5, p.x, 0.3), Tela.TELA.y + 40.0)
	var s = {"p": p, "de": de, "t": 0.0, "estilo": estilo, "giro": randf() * TAU, "impacto": false}
	_tiros.append(s)
	while _tiros.size() > 8:
		_tiros.pop_front()
	if FEIXES.has(estilo):
		_pelo_caminho(s)
	set_process(true)


func _voo(estilo: String) -> float:
	if FEIXES.has(estilo):
		return FEIXES[estilo][0]
	return BALA_VOO if estilo == "bar" else MENU[0]


func _fim(estilo: String) -> float:
	if FEIXES.has(estilo):
		return max(FEIXES[estilo][1], FEIXES[estilo][0] + IMPACTO)
	return _voo(estilo) + IMPACTO


## O que o laser deixa no caminho, na hora em que acende (cada ponto solto
## direto: tiro atrás de tiro sem montar uma explosão por ponto).
func _pelo_caminho(s: Dictionary) -> void:
	var de: Vector2 = s["de"]
	var p: Vector2 = s["p"]
	var lado = (p - de).normalized().rotated(PI * 0.5)
	var k = Maquina.fator_efeitos()
	match s["estilo"]:
		"sol":
			var c = Color(1.0, 0.85, 0.45)
			var ponto = Estilo.tex("fx_ponto")
			for i in int(round(7 * k)):
				var q = de.linear_interpolate(p, rand_range(0.15, 0.95)) + lado * rand_range(-8.0, 8.0)
				var a = deg2rad(rand_range(230.0, 310.0))
				var t = rand_range(5.0, 10.0)
				_brilhos.soltar(q, Vector2(cos(a), sin(a)) * rand_range(10.0, 50.0), rand_range(0.35, 0.7), t, t * 0.2,
					c, Color(c.r, c.g, c.b, 0.0), ponto, -40.0, 1.0)
		"lua":
			var c = Color(0.92, 0.96, 1.0)
			var ponto = Estilo.tex("fx_ponto")
			for i in int(round(9 * k)):
				var q = de.linear_interpolate(p, rand_range(0.12, 0.95)) + lado * rand_range(-10.0, 10.0)
				var a = randf() * TAU
				var t = rand_range(3.0, 7.0)
				_brilhos.soltar(q, Vector2(cos(a), sin(a)) * rand_range(5.0, 30.0), rand_range(0.4, 0.8), t, t * 0.2,
					c, Color(c.r, c.g, c.b, 0.0), ponto, 10.0, 1.0)
		"mar":
			var n = int(clamp((p - de).length() / 60.0, 8.0, 20.0) * k)
			var bolha = Estilo.tex("mar_bolha")
			var c = Color(0.85, 0.97, 1.0, 0.8)
			var c_fim = Color(0.85, 0.97, 1.0, 0.0)
			for i in n:
				var q = de.linear_interpolate(p, (i + randf()) / n) + lado * rand_range(-10.0, 10.0)
				var a = deg2rad(rand_range(250.0, 290.0))
				var t = rand_range(6.0, 14.0)
				_fumaca.soltar(q, Vector2(cos(a), sin(a)) * rand_range(15.0, 60.0), rand_range(0.6, 1.1), t, t * 0.9,
					c, c_fim, bolha, -160.0, 1.5)


## Quando o tiro chega no ponto.
func _impacto(s: Dictionary) -> void:
	var p: Vector2 = s["p"]
	match s["estilo"]:
		"laser":
			# as faíscas em brasa da abertura (branco-quente esfriando a vermelho)
			_brilhos.explosao(p, {"n": 22, "vel": [220.0, 640.0], "vida": [0.35, 0.6], "tam": [4.0, 8.0],
				"cor": Color(1.0, 0.95, 0.7), "cor_fim": Color(1.0, 0.15, 0.05, 0.0), "grav": 1200.0, "estica": 0.03, "arrasto": 1.0})
		"sol":
			_brilhos.explosao(p, {"n": 10, "vel": [60.0, 220.0], "ang": [200.0, 340.0], "vida": [0.4, 0.8], "tam": [8.0, 16.0],
				"cor": Color(1.0, 0.85, 0.4), "grav": -60.0, "arrasto": 2.0})
		"lua":
			_brilhos.explosao(p, {"n": 12, "vel": [40.0, 170.0], "vida": [0.5, 0.9], "tam": [6.0, 12.0],
				"cor": Color(0.88, 0.94, 1.0), "grav": 40.0, "arrasto": 2.5})
		"mar":
			_fumaca.explosao(p, {"n": 7, "tex": Estilo.tex("mar_bolha"), "vel": [30.0, 110.0], "ang": [220.0, 320.0],
				"vida": [0.6, 1.1], "tam": [10.0, 22.0], "fim": 0.9, "cor": Color(0.85, 0.97, 1.0, 0.85), "grav": -220.0, "arrasto": 1.5, "espalha": 10.0})
		"bar":
			_brilhos.explosao(p, {"n": 8, "vel": [180.0, 420.0], "vida": [0.15, 0.32], "tam": [5.0, 9.0],
				"cor": Color(1.0, 0.75, 0.35), "grav": 600.0, "estica": 0.05, "arrasto": 1.0})
			_fumaca.explosao(p, {"n": 3, "tex": Estilo.tex("fx_fumaca"), "vel": [10.0, 40.0], "ang": [240.0, 300.0],
				"vida": [0.7, 1.2], "tam": [26.0, 40.0], "fim": 2.2, "cor": Color(0.75, 0.72, 0.68, 0.45), "grav": -40.0, "arrasto": 1.0})
		_:
			_brilhos.explosao(p, {"n": 9, "vel": [120.0, 360.0], "vida": [0.18, 0.4], "tam": [5.0, 10.0],
				"cor": MENU[4].linear_interpolate(Color.white, 0.3), "estica": 0.04, "arrasto": 2.0})


func _process(delta: float) -> void:
	var i = 0
	while i < _tiros.size():
		var s: Dictionary = _tiros[i]
		s["t"] += delta
		if not s["impacto"] and s["t"] >= _voo(s["estilo"]):
			s["impacto"] = true
			_impacto(s)
		if s["t"] > _fim(s["estilo"]):
			_tiros.remove(i)
			continue
		i += 1
	_luz.update()
	if _tiros.empty():
		set_process(false)


func _desenhar() -> void:
	for s in _tiros:
		if FEIXES.has(s["estilo"]):
			_desenhar_laser(s)
		elif s["estilo"] == "bar":
			_desenhar_bala(s)
		else:
			_desenhar_aneis(s)


func _brilho(c: Vector2, r: float, cor: Color) -> void:
	_luz.draw_texture_rect(_t_brilho, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, cor)


## Um feixe da arma até `ate`: halo, faixa e miolo (textura macia esticada).
func _raio(de: Vector2, ate: Vector2, cores: Array, larguras: Array, a: float) -> void:
	var v = ate - de
	var comp = v.length()
	if comp < 1.0 or a <= 0.0:
		return
	_luz.draw_set_transform(de, v.angle(), Vector2.ONE)
	for j in 3:
		var c: Color = cores[j]
		var w: float = larguras[j]
		_luz.draw_texture_rect(_t_laser, Rect2(0.0, -w * 0.5, comp, w), false, Color(c.r, c.g, c.b, c.a * a))
	_luz.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Laser (arena, sol, lua, mar): acende inteiro na hora e apaga; um pulso
## corre da arma até o ponto e lá fica o impacto do cenário.
func _desenhar_laser(s: Dictionary) -> void:
	var f: Array = FEIXES[s["estilo"]]
	var voo: float = f[0]
	var vida: float = f[1]
	var cores: Array = f[2]
	var t: float = s["t"]
	var de: Vector2 = s["de"]
	var p: Vector2 = s["p"]
	var halo: Color = cores[0]
	var miolo: Color = cores[2]
	_raio(de, p, cores, f[3], clamp(1.0 - t / vida, 0.0, 1.0))
	if t < voo:
		var k = t / voo
		var cab = de.linear_interpolate(p, k)
		_brilho(cab, 34.0, Color(halo.r, halo.g, halo.b, 0.9))
		_luz.draw_texture_rect(_t_ponto, Rect2(cab - Vector2(10, 10), Vector2(20, 20)), false, miolo)
		# o clarão da arma na beirada de baixo
		_luz.draw_texture_rect(_t_brilho, Rect2(Vector2(de.x - 260.0, Tela.TELA.y - 200.0), Vector2(520.0, 400.0)), false,
			Color(halo.r, halo.g, halo.b, (1.0 - k) * 0.5))
		return
	var k2 = clamp((t - voo) / IMPACTO, 0.0, 1.0)
	var fade = 1.0 - k2
	match s["estilo"]:
		"laser":
			# o clarão do laser abrindo e o anel de choque, como na abertura
			_brilho(p, 22.0 + 96.0 * k2, Color(1.0, 0.6, 0.45, 0.7 * fade))
			var r = 12.0 + 64.0 * k2
			_luz.draw_texture_rect(_t_anel, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.30, 0.25, fade))
			_brilho(p, 14.0 * fade + 4.0, Color(1.0, 0.9, 0.85, fade))
		"sol":
			var r2 = 40.0 + 70.0 * k2
			_luz.draw_set_transform(p, s["giro"] + k2 * 2.0, Vector2.ONE)
			_luz.draw_texture_rect(_t_estrela, Rect2(Vector2(-r2, -r2), Vector2(r2, r2) * 2.0), false, Color(1.0, 0.9, 0.55, fade))
			_luz.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_brilho(p, 34.0 * fade + 10.0, Color(1.0, 0.8, 0.35, fade))
		"lua":
			var r3 = 16.0 + 70.0 * k2
			_luz.draw_texture_rect(_t_anel, Rect2(p - Vector2(r3, r3), Vector2(r3, r3) * 2.0), false, Color(0.85, 0.92, 1.0, fade))
			_brilho(p, 30.0 * fade + 8.0, Color(0.95, 0.97, 1.0, fade))
		"mar":
			for j in 2:
				var kk: float = clamp(k2 * 1.2 - j * 0.25, 0.0, 1.0)
				var r4 = 14.0 + 80.0 * kk
				_luz.draw_texture_rect(_t_anel, Rect2(p - Vector2(r4, r4 * 0.8), Vector2(r4, r4 * 0.8) * 2.0), false, Color(0.5, 0.92, 1.0, (1.0 - kk) * 0.7))
			_brilho(p, 24.0 * fade + 6.0, Color(0.6, 0.95, 1.0, fade))


## Bar: a BALA. O clarão da boca da arma na beirada de baixo e a bala
## traçante (um risco quente, mais forte na ponta) correndo até o ponto.
func _desenhar_bala(s: Dictionary) -> void:
	var t: float = s["t"]
	var de: Vector2 = s["de"]
	var p: Vector2 = s["p"]
	if t < 0.06:
		var f = 1.0 - t / 0.06
		_luz.draw_texture_rect(_t_brilho, Rect2(Vector2(de.x - 300.0, Tela.TELA.y - 240.0), Vector2(600.0, 480.0)), false,
			Color(1.0, 0.70, 0.30, 0.85 * f))
		_luz.draw_texture_rect(_t_brilho, Rect2(Vector2(de.x - 110.0, Tela.TELA.y - 120.0), Vector2(220.0, 240.0)), false,
			Color(1.0, 0.95, 0.80, f))
	if t < BALA_VOO:
		var v = p - de
		var k = t / BALA_VOO
		var cab = de + v * k
		var comp = min(BALA_RASTRO, v.length() * k)
		if comp > 1.0:
			_luz.draw_set_transform(cab, v.angle(), Vector2.ONE)
			_luz.draw_texture_rect(_t_rastro, Rect2(-comp, -11.0, comp, 22.0), false, Color(1.0, 0.62, 0.22, 0.95))
			_luz.draw_texture_rect(_t_rastro, Rect2(-comp * 0.75, -3.5, comp * 0.75, 7.0), false, Color(1.0, 0.97, 0.85))
			_luz.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_brilho(cab, 14.0, Color(1.0, 0.85, 0.55, 0.9))
		return
	var fade = 1.0 - clamp((t - BALA_VOO) / IMPACTO, 0.0, 1.0)
	_brilho(p, 30.0 * fade + 6.0, Color(1.0, 0.72, 0.32, fade))


## Telas de fora das fases: a bala indo para dentro da tela (anéis fechando
## até o ponto) e um clarão com anel no ponto.
func _desenhar_aneis(s: Dictionary) -> void:
	var t: float = s["t"]
	var voo: float = MENU[0]
	var p: Vector2 = s["p"]
	var cor_anel: Color = MENU[2]
	var cor_nucleo: Color = MENU[3]
	if t < voo:
		var k = t / voo
		var r: float = lerp(MENU[1], 10.0, k * k)
		var a = 0.35 + 0.65 * k
		_luz.draw_texture_rect(_t_anel, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(cor_anel.r, cor_anel.g, cor_anel.b, a * 0.8))
		var r2 = r * 0.6
		_luz.draw_texture_rect(_t_anel, Rect2(p - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false, Color(cor_anel.r, cor_anel.g, cor_anel.b, a * 0.5))
		var rn = 10.0 + 18.0 * (1.0 - k)
		_luz.draw_texture_rect(_t_ponto, Rect2(p - Vector2(rn, rn), Vector2(rn, rn) * 2.0), false, cor_nucleo)
		var bx: float = clamp(p.x, 160.0, Tela.TELA.x - 160.0)
		var c: Color = MENU[4]
		_luz.draw_texture_rect(_t_brilho, Rect2(Vector2(bx - 330.0, Tela.TELA.y - 230.0), Vector2(660.0, 460.0)), false, Color(c.r, c.g, c.b, (1.0 - k) * 0.55))
		return
	var k2 = (t - voo) / IMPACTO
	var fade = 1.0 - k2
	var r3 = 12.0 + 64.0 * k2
	_luz.draw_texture_rect(_t_anel, Rect2(p - Vector2(r3, r3), Vector2(r3, r3) * 2.0), false, Color(cor_anel.r, cor_anel.g, cor_anel.b, fade))
	_brilho(p, 30.0 * fade + 6.0, Color(cor_nucleo.r, cor_nucleo.g, cor_nucleo.b, fade))
