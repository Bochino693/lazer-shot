extends Node2D
class_name Particulas

## PARTÍCULAS LEVES para a Mali-450: faíscas, brilhos, fumaça, bolhas,
## poeira, lascas, moedas... todas desenhadas por UM nó num desenho só (a
## mesma imagem em sequência vira um lote na placa). Nada de nó por
## partícula e nada de partícula na placa de vídeo (o OpenGL ES 2 da TV Box
## não tem).
##
## Cada partícula: posição, velocidade, gravidade, arrasto, vida, tamanho
## (início e fim), cor (início e fim), giro e textura. `estica` > 0 deixa a
## partícula comprida na direção do movimento (faísca riscando).
##
##   var p = Particulas.new()           # luz somada: p.somar = true
##   add_child(p)
##   p.explosao(pos, {"n": 20, "tex": Estilo.tex("fx_ponto"), "vel": [200, 600], ...})

const MAX = 260

var somar = false setget _set_somar

var _lista = []      # cada partícula é um Array (rápido no GDScript 1)
var _texs = []       # texturas usadas (índice na partícula)
var _rng = RandomNumberGenerator.new()

# índices do Array de cada partícula
const P_X = 0
const P_Y = 1
const P_VX = 2
const P_VY = 3
const P_T = 4
const P_VIDA = 5
const P_TAM0 = 6
const P_TAM1 = 7
const P_COR0 = 8
const P_COR1 = 9
const P_GRAV = 10
const P_ARRASTO = 11
const P_ROT = 12
const P_GIRO = 13
const P_TEX = 14
const P_ESTICA = 15
const P_CHAO = 16


func _init() -> void:
	_rng.randomize()
	set_process(false)


func _set_somar(v: bool) -> void:
	somar = v
	material = Estilo.material_soma() if v else null


func vazio() -> bool:
	return _lista.empty()


func limpar() -> void:
	_lista.clear()
	update()


func _tex_indice(t: Texture) -> int:
	var i = _texs.find(t)
	if i < 0:
		_texs.append(t)
		i = _texs.size() - 1
	return i


## Uma partícula. Use explosao() para muitas de uma vez.
func soltar(pos: Vector2, vel: Vector2, vida: float, tam0: float, tam1: float, cor0: Color, cor1: Color,
		tex: Texture, grav: float = 0.0, arrasto: float = 0.0, giro: float = 0.0, estica: float = 0.0, chao: float = 1.0e9) -> void:
	if _lista.size() >= MAX:
		_lista.pop_front()
	_lista.append([pos.x, pos.y, vel.x, vel.y, 0.0, max(0.05, vida), tam0, tam1, cor0, cor1, grav, arrasto,
		_rng.randf() * TAU, giro, _tex_indice(tex), estica, chao])
	set_process(true)


## Explosão de partículas a partir de `pos`. Opções (todas opcionais):
##   n, tex, vel [min, max], ang [graus de, graus até] (padrão: em volta),
##   vida [min, max], tam [min, max] (tamanho inicial em px), fim (fator do
##   tamanho no fim), cor, cor_fim, grav, arrasto, giro [min, max] (rad/s),
##   estica, espalha (raio de nascimento), chao (y onde param), vel_base
func explosao(pos: Vector2, o: Dictionary) -> void:
	var n = int(round(float(o.get("n", 12)) * Maquina.fator_efeitos()))
	var tex: Texture = o.get("tex", null)
	if tex == null:
		tex = Estilo.tex("fx_ponto")
	var vel: Array = o.get("vel", [100.0, 300.0])
	var ang: Array = o.get("ang", [0.0, 360.0])
	var vida: Array = o.get("vida", [0.4, 0.8])
	var tam: Array = o.get("tam", [8.0, 16.0])
	var fim: float = o.get("fim", 0.2)
	var cor: Color = o.get("cor", Color.white)
	var cor_fim: Color = o.get("cor_fim", Color(cor.r, cor.g, cor.b, 0.0))
	var grav: float = o.get("grav", 0.0)
	var arrasto: float = o.get("arrasto", 1.0)
	var giro: Array = o.get("giro", [0.0, 0.0])
	var estica: float = o.get("estica", 0.0)
	var espalha: float = o.get("espalha", 0.0)
	var chao: float = o.get("chao", 1.0e9)
	var vel_base: Vector2 = o.get("vel_base", Vector2.ZERO)
	for i in n:
		var a = deg2rad(_rng.randf_range(ang[0], ang[1]))
		var dir = Vector2(cos(a), sin(a))
		var v = dir * _rng.randf_range(vel[0], vel[1]) + vel_base
		var t0 = _rng.randf_range(tam[0], tam[1])
		var p0 = pos + dir * _rng.randf_range(0.0, espalha)
		soltar(p0, v, _rng.randf_range(vida[0], vida[1]), t0, t0 * fim, cor, cor_fim, tex, grav, arrasto,
			_rng.randf_range(giro[0], giro[1]), estica, chao)


func _process(delta: float) -> void:
	if _lista.empty():
		set_process(false)
		update()
		return
	var i = 0
	while i < _lista.size():
		var p: Array = _lista[i]
		p[P_T] += delta
		if p[P_T] >= p[P_VIDA]:
			_lista.remove(i)
			continue
		if p[P_ARRASTO] > 0.0:
			var k = exp(-p[P_ARRASTO] * delta)
			p[P_VX] *= k
			p[P_VY] *= k
		p[P_VY] += p[P_GRAV] * delta
		p[P_X] += p[P_VX] * delta
		p[P_Y] += p[P_VY] * delta
		if p[P_Y] > p[P_CHAO]:
			# bateu no chão: quica baixo e desliza até parar
			p[P_Y] = p[P_CHAO]
			p[P_VY] = -abs(p[P_VY]) * 0.25
			p[P_VX] *= 0.6
			p[P_GIRO] *= 0.5
		p[P_ROT] += p[P_GIRO] * delta
		i += 1
	update()


func _draw() -> void:
	for p in _lista:
		var k: float = p[P_T] / p[P_VIDA]
		var tam: float = lerp(p[P_TAM0], p[P_TAM1], k)
		if tam <= 0.3:
			continue
		var cor: Color = (p[P_COR0] as Color).linear_interpolate(p[P_COR1], k)
		var tex: Texture = _texs[p[P_TEX]]
		var c = Vector2(p[P_X], p[P_Y])
		if p[P_ESTICA] > 0.0:
			var v = Vector2(p[P_VX], p[P_VY])
			var comp: float = tam + v.length() * p[P_ESTICA]
			draw_set_transform(c, v.angle(), Vector2.ONE)
			draw_texture_rect(tex, Rect2(-comp * 0.5, -tam * 0.25, comp, tam * 0.5), false, cor)
		elif p[P_GIRO] != 0.0:
			draw_set_transform(c, p[P_ROT], Vector2.ONE)
			draw_texture_rect(tex, Rect2(-tam * 0.5, -tam * 0.5, tam, tam), false, cor)
		else:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_texture_rect(tex, Rect2(c.x - tam * 0.5, c.y - tam * 0.5, tam, tam), false, cor)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
