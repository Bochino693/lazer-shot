extends CanvasLayer
class_name Trajetoria

## O TIRO VISTO DE QUEM ATIRA (primeira pessoa): a bala vai PARA DENTRO da
## tela na linha da mira. Ela aparece no ponto da mira grande e desfocada
## saindo da arma e fecha até o ponto (anéis fechando, como um zoom), e o
## clarão da boca da arma acende de leve a beirada de baixo da tela. No
## ponto, o impacto de cada cenário:
##
##   laser (Arena)  anéis vermelhos e núcleo branco; clarão e anel de choque
##   sol   (Egito)  anéis de ouro; estrela de luz girando e brilhos subindo
##   lua   (Egito)  anéis de prata azulada; anel frio abrindo e pó de estrela
##   mar   (Mar)    anéis de água; ondas abrindo e bolhas subindo
##   bar   (Bar)    traçante: ponto quente fechando rápido; faísca e fumaça
##
## Um desenho para a luz (somada), um para a fumaça/bolhas; só redesenha
## enquanto há tiro no ar.

const IMPACTO = 0.35
# voo (s), raio de saída (px), cor dos anéis, cor do núcleo, cor do clarão
const ESTILOS = {
	"laser": [0.07, 96.0, Color(1.0, 0.16, 0.10), Color(1.0, 0.75, 0.70), Color(1.0, 0.25, 0.18)],
	"sol": [0.10, 118.0, Color(1.0, 0.70, 0.22), Color(1.0, 0.95, 0.75), Color(1.0, 0.70, 0.30)],
	"lua": [0.10, 112.0, Color(0.55, 0.75, 1.0), Color(0.92, 0.97, 1.0), Color(0.60, 0.78, 1.0)],
	"mar": [0.12, 106.0, Color(0.55, 0.90, 1.0), Color(0.90, 0.99, 1.0), Color(0.40, 0.80, 1.0)],
	"bar": [0.06, 74.0, Color(1.0, 0.55, 0.15), Color(1.0, 0.92, 0.65), Color(1.0, 0.62, 0.25)],
	"menu": [0.07, 90.0, Color(1.0, 0.20, 0.22), Color(1.0, 0.85, 0.80), Color(1.0, 0.30, 0.25)],
}

var _luz: Node2D
var _tiros = []
var _brilhos: Particulas
var _fumaca: Particulas
var _t_anel: Texture
var _t_ponto: Texture
var _t_brilho: Texture
var _t_estrela: Texture


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
	var e: Array = ESTILOS.get(estilo, ESTILOS["laser"])
	_tiros.append({"p": p, "t": 0.0, "e": e, "estilo": estilo, "giro": randf() * TAU, "impacto": false})
	while _tiros.size() > 8:
		_tiros.pop_front()
	set_process(true)


func _impacto(s: Dictionary) -> void:
	var p: Vector2 = s["p"]
	var e: Array = s["e"]
	match s["estilo"]:
		"sol":
			_brilhos.explosao(p, {"n": 10, "vel": [60.0, 220.0], "ang": [200.0, 340.0], "vida": [0.4, 0.8], "tam": [8.0, 16.0],
				"cor": Color(1.0, 0.85, 0.4), "grav": -60.0, "arrasto": 2.0})
		"lua":
			_brilhos.explosao(p, {"n": 12, "vel": [40.0, 170.0], "vida": [0.5, 0.9], "tam": [6.0, 12.0],
				"cor": Color(0.75, 0.88, 1.0), "grav": 40.0, "arrasto": 2.5})
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
				"cor": e[2].linear_interpolate(Color.white, 0.3), "estica": 0.04, "arrasto": 2.0})


func _process(delta: float) -> void:
	var i = 0
	while i < _tiros.size():
		var s: Dictionary = _tiros[i]
		s["t"] += delta
		var voo: float = s["e"][0]
		if not s["impacto"] and s["t"] >= voo:
			s["impacto"] = true
			_impacto(s)
		if s["t"] > voo + IMPACTO:
			_tiros.remove(i)
			continue
		i += 1
	_luz.update()
	if _tiros.empty():
		set_process(false)


func _desenhar() -> void:
	for s in _tiros:
		var e: Array = s["e"]
		var t: float = s["t"]
		var voo: float = e[0]
		var p: Vector2 = s["p"]
		var cor_anel: Color = e[2]
		var cor_nucleo: Color = e[3]
		if t < voo:
			# a bala indo para dentro: anéis fechando até o ponto
			var k = t / voo
			var r: float = lerp(e[1], 10.0, k * k)
			var a = 0.35 + 0.65 * k
			_luz.draw_texture_rect(_t_anel, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(cor_anel.r, cor_anel.g, cor_anel.b, a * 0.8))
			var r2 = r * 0.6
			_luz.draw_texture_rect(_t_anel, Rect2(p - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false, Color(cor_anel.r, cor_anel.g, cor_anel.b, a * 0.5))
			var rn = 10.0 + 18.0 * (1.0 - k)
			_luz.draw_texture_rect(_t_ponto, Rect2(p - Vector2(rn, rn), Vector2(rn, rn) * 2.0), false, cor_nucleo)
			# o clarão da boca da arma na beirada de baixo
			var bx: float = clamp(p.x, 160.0, Tela.TELA.x - 160.0)
			var f = (1.0 - k) * 0.55
			_luz.draw_texture_rect(_t_brilho, Rect2(Vector2(bx - 330.0, Tela.TELA.y - 230.0), Vector2(660.0, 460.0)), false, Color(e[4].r, e[4].g, e[4].b, f))
		else:
			var k = (t - voo) / IMPACTO
			var fade = 1.0 - k
			match s["estilo"]:
				"sol":
					var r = 40.0 + 70.0 * k
					_luz.draw_set_transform(p, s["giro"] + k * 2.0, Vector2.ONE)
					_luz.draw_texture_rect(_t_estrela, Rect2(Vector2(-r, -r), Vector2(r, r) * 2.0), false, Color(1.0, 0.9, 0.55, fade))
					_luz.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
					var rb = 34.0 * fade + 10.0
					_luz.draw_texture_rect(_t_brilho, Rect2(p - Vector2(rb, rb), Vector2(rb, rb) * 2.0), false, Color(1.0, 0.8, 0.35, fade))
				"lua":
					var r = 16.0 + 70.0 * k
					_luz.draw_texture_rect(_t_anel, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(0.7, 0.85, 1.0, fade))
					var rb = 30.0 * fade + 8.0
					_luz.draw_texture_rect(_t_brilho, Rect2(p - Vector2(rb, rb), Vector2(rb, rb) * 2.0), false, Color(0.85, 0.92, 1.0, fade))
				"mar":
					for j in 2:
						var kk: float = clamp(k * 1.2 - j * 0.25, 0.0, 1.0)
						var r = 14.0 + 80.0 * kk
						_luz.draw_texture_rect(_t_anel, Rect2(p - Vector2(r, r * 0.8), Vector2(r, r * 0.8) * 2.0), false, Color(0.6, 0.9, 1.0, (1.0 - kk) * 0.7))
				"bar":
					var rb = 26.0 * fade + 4.0
					_luz.draw_texture_rect(_t_brilho, Rect2(p - Vector2(rb, rb), Vector2(rb, rb) * 2.0), false, Color(1.0, 0.7, 0.3, fade))
				_:
					var r = 12.0 + 64.0 * k
					_luz.draw_texture_rect(_t_anel, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(cor_anel.r, cor_anel.g, cor_anel.b, fade))
					var rb = 30.0 * fade + 6.0
					_luz.draw_texture_rect(_t_brilho, Rect2(p - Vector2(rb, rb), Vector2(rb, rb) * 2.0), false, Color(cor_nucleo.r, cor_nucleo.g, cor_nucleo.b, fade))
