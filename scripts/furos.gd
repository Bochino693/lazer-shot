class_name Furos
extends Node2D

## Furos de bala no chão (areia ou pedra) com a poeira que o tiro levanta e
## que fica pairando em cima do furo. Fica como filho do fundo da fase (anda
## junto com ele) e trabalha em coordenadas do fundo.
##   furar(p, "areia" | "pedra", escala, cor)  furo + poeira
##   poeira(p, escala)                          só a nuvem de areia
## Tudo num desenho só; até 16 furos (o mais velho some) e 24 nuvens; parado,
## não redesenha.

const MAX_FUROS := 16
const MAX_POEIRA := 24
const VIDA_FURO := 10.0

var tex_areia: Texture2D = null
var tex_pedra: Texture2D = null
var tex_fumaca: Texture2D = null
## cor da poeira (o Mar é azulado; o Egito muda de dia para a noite)
var cor_poeira := Color(0.78, 0.80, 0.76)

## Opcional: quanto um ponto do chão anda agora (paralaxe por distância).
var deslocar: Callable

var _furos: Array[Dictionary] = []
var _nuvens: Array[Dictionary] = []
var _sujo := false


func furar(p: Vector2, tipo: String, escala: float = 1.0, cor: Color = Color.WHITE) -> void:
	var tex := tex_pedra if tipo == "pedra" else tex_areia
	if tex != null:
		_furos.append({"pos": p, "tex": tex, "esc": escala * randf_range(0.85, 1.15), "ang": randf_range(-0.25, 0.25) if tipo == "areia" else randf() * TAU,
			"t": 0.0, "cor": cor})
		while _furos.size() > MAX_FUROS:
			_furos.pop_front()
	poeira(p, escala, 0.75 if tipo == "pedra" else 1.0)
	# a poeira que fica: um véu baixo que paira em cima do furo e vai assentando
	if tex_fumaca != null and tipo == "areia":
		for i in 2:
			_nuvens.append({"pos": p + Vector2(randf_range(-10.0, 10.0), randf_range(-14.0, -4.0)) * escala,
				"vel": Vector2(randf_range(-8.0, 8.0), -randf_range(4.0, 10.0)) * escala,
				"tam": randf_range(70.0, 96.0) * escala, "cresce": randf_range(0.6, 0.9), "ang": randf() * TAU,
				"giro": randf_range(-0.15, 0.15), "t": 0.0, "vida": randf_range(5.0, 6.5), "veu": true})
		while _nuvens.size() > MAX_POEIRA:
			_nuvens.pop_front()


func poeira(p: Vector2, escala: float = 1.0, quanto: float = 1.0) -> void:
	if tex_fumaca == null:
		return
	var n := int(round(4.0 * quanto)) + 1
	for i in n:
		var lado := randf_range(-1.0, 1.0)
		_nuvens.append({"pos": p + Vector2(lado * 8.0, randf_range(-6.0, 2.0)) * escala,
			"vel": Vector2(lado * randf_range(20.0, 60.0), -randf_range(18.0, 55.0)) * escala,
			"tam": randf_range(36.0, 60.0) * escala, "cresce": randf_range(1.4, 2.2), "ang": randf() * TAU,
			"giro": randf_range(-0.6, 0.6), "t": 0.0, "vida": randf_range(1.6, 2.6)})
	while _nuvens.size() > MAX_POEIRA:
		_nuvens.pop_front()
	_sujo = true


func limpar() -> void:
	_furos.clear()
	_nuvens.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _furos.is_empty() and _nuvens.is_empty():
		if _sujo:
			_sujo = false
			queue_redraw()
		return
	for f in _furos:
		f["t"] += delta
	while not _furos.is_empty() and _furos[0]["t"] > VIDA_FURO:
		_furos.pop_front()
	for n in _nuvens:
		n["t"] += delta
		n["vel"] = n["vel"] * pow(0.3, delta)
		n["pos"] += n["vel"] * delta
		n["ang"] += n["giro"] * delta
	for i in range(_nuvens.size() - 1, -1, -1):
		if _nuvens[i]["t"] > _nuvens[i]["vida"]:
			_nuvens.remove_at(i)
	_sujo = true
	queue_redraw()


func _draw() -> void:
	for f in _furos:
		var tex: Texture2D = f["tex"]
		var a: float = clampf((VIDA_FURO - f["t"]) / 2.5, 0.0, 1.0) * minf(1.0, f["t"] * 10.0)
		var tam: Vector2 = tex.get_size() * float(f["esc"])
		var pf: Vector2 = f["pos"]
		if deslocar.is_valid():
			pf += deslocar.call(pf)
		draw_set_transform(pf, f["ang"])
		draw_texture_rect(tex, Rect2(-tam * 0.5, tam), false, Color(f["cor"], a))
	draw_set_transform(Vector2.ZERO)
	for n in _nuvens:
		var k: float = n["t"] / n["vida"]
		var s: float = n["tam"] * (0.6 + n["cresce"] * (1.0 - (1.0 - k) * (1.0 - k)))
		var pn: Vector2 = n["pos"]
		if deslocar.is_valid():
			pn += deslocar.call(pn)
		draw_set_transform(pn, n["ang"])
		var forca: float = 0.62 * minf(1.0, k * 8.0) * (1.0 - k)
		if n.has("veu"):
			# véu: achatado, entra devagar e some devagar
			forca = 0.42 * minf(1.0, k * 4.0) * (1.0 - k) * (1.0 - k)
			draw_set_transform(pn, n["ang"] * 0.2, Vector2(1.0, 0.55))
		draw_texture_rect(tex_fumaca, Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), false,
			Color(cor_poeira, forca))
	draw_set_transform(Vector2.ZERO)
