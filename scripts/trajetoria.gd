class_name Trajetoria
extends CanvasLayer

## O tiro visto de quem atira (primeira pessoa): a arma está logo abaixo da
## vista e a bala vai PARA DENTRO da tela, na linha da mira. Por isso ela
## não cruza a tela nem nasce no meio dela: aparece só no ponto da mira,
## grande e desfocada saindo da arma e encolhendo até o ponto enquanto vai
## para longe (anéis fechando, como um zoom), e o clarão da boca da arma
## acende de leve a beirada de baixo da tela. No ponto, o impacto de cada
## cenário (o recuo sai dali também, no MiraGlobal):
##
##   laser  (Arena)  anéis vermelhos fechando e núcleo branco; no ponto o
##                   clarão do laser e um anel de choque
##   sol    (Egito)  anéis de ouro fechando; no ponto a estrela de luz de
##                   quatro pontas finas girando e brilhos soltos subindo
##   lua    (Egito)  anéis de prata azulada; no ponto um anel frio abrindo e
##                   pó de estrela
##   mar    (Mar)    a bala empurra a água: anéis de água fechando, no ponto
##                   ondas abrindo e bolhas subindo
##   bar    (Bar)    traçante: um ponto quente encolhendo rápido; no ponto a
##                   faísca e um fio de fumaça
##
##   Trajetoria.disparar(fase, ponto_na_tela, "laser")
##
## Uma camada por fase (criada no primeiro tiro), um desenho para a luz
## (mistura somada) e um para a fumaça; só redesenha enquanto há tiro no ar.
## Tudo com as formas macias do Pincel (nada de risco com ponta reta).

const Pincel := preload("res://scripts/pincel.gd")
const MAX_TIROS := 8
const IMPACTO := 0.35          # s do impacto no ponto, depois que a bala chega
# por estilo: tempo de voo (s), raio de saída (px), cor dos anéis, cor do
# núcleo, cor do clarão da arma
const ESTILOS := {
	"laser": [0.07, 96.0, Color(1.0, 0.16, 0.10), Color(1.0, 0.75, 0.70), Color(1.0, 0.25, 0.18)],
	"sol": [0.10, 118.0, Color(1.0, 0.70, 0.22), Color(1.0, 0.95, 0.75), Color(1.0, 0.70, 0.30)],
	"lua": [0.10, 112.0, Color(0.55, 0.75, 1.0), Color(0.92, 0.97, 1.0), Color(0.60, 0.78, 1.0)],
	"mar": [0.12, 106.0, Color(0.55, 0.90, 1.0), Color(0.90, 0.99, 1.0), Color(0.40, 0.80, 1.0)],
	"bar": [0.06, 74.0, Color(1.0, 0.55, 0.15), Color(1.0, 0.92, 0.65), Color(1.0, 0.62, 0.25)],
}
# (o som é o estampido de cada fase: raio de sol, de luar, arpão no mar,
# laser na arena, pistola no bar; o tiro não toca nada por cima)

var _tiros: Array = []         # {para, t, voo, estilo}
var _parts: Array = []         # {pos, vel, t, vida, tam, tipo, cor}
var _soma: Node2D
var _normal: Node2D


static func disparar(fase: Node, para: Vector2, estilo: String) -> void:
	if fase == null or not fase.is_inside_tree():
		return
	var tr := fase.get_node_or_null("Trajetoria") as Trajetoria
	if tr == null:
		tr = Trajetoria.new()
		tr.name = "Trajetoria"
		tr.layer = 15
		fase.add_child(tr)
	tr._novo(para, estilo)


func _ready() -> void:
	_normal = Node2D.new()
	_normal.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_normal.draw.connect(_desenhar_normal)
	add_child(_normal)
	_soma = Node2D.new()
	_soma.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_soma.material = m
	_soma.draw.connect(_desenhar_soma)
	add_child(_soma)


func _novo(para: Vector2, estilo: String) -> void:
	if not is_node_ready():
		await ready
	if not ESTILOS.has(estilo):
		estilo = "laser"
	var voo: float = ESTILOS[estilo][0]
	_tiros.append({"para": para, "t": 0.0, "voo": voo, "estilo": estilo})
	while _tiros.size() > MAX_TIROS:
		_tiros.pop_front()
	# o que sai do ponto depois que a bala chega (t negativo = ainda no voo)
	match estilo:
		"sol":
			for i in 6:
				_parts.append({"pos": para + Vector2(randf_range(-6, 6), randf_range(-6, 6)),
					"vel": Vector2.from_angle(randf_range(-PI, 0.0)) * randf_range(60.0, 170.0), "t": -voo,
					"vida": randf_range(0.35, 0.65), "tam": randf_range(7.0, 13.0), "tipo": "estrela", "cor": Color(1.0, 0.85, 0.45)})
		"lua":
			for i in 8:
				_parts.append({"pos": para + Vector2(randf_range(-10, 10), randf_range(-10, 10)),
					"vel": Vector2.from_angle(randf() * TAU) * randf_range(30.0, 110.0), "t": -voo,
					"vida": randf_range(0.4, 0.8), "tam": randf_range(5.0, 9.0), "tipo": "estrela", "cor": Color(0.78, 0.9, 1.0)})
		"mar":
			for i in 9:
				var lado := Vector2.from_angle(randf() * TAU) * randf_range(4.0, 26.0)
				_parts.append({"pos": para + lado, "vel": Vector2(randf_range(-18, 18), randf_range(-110, -45)), "t": -voo - randf() * 0.12,
					"vida": randf_range(0.6, 1.0), "tam": randf_range(4.0, 10.0), "tipo": "bolha", "cor": Color(0.85, 0.97, 1.0)})
		"bar":
			for i in 2:
				_parts.append({"pos": para + Vector2(randf_range(-4, 4), 0.0), "vel": Vector2(randf_range(-10, 10), randf_range(-30, -14)),
					"t": -voo - i * 0.06, "vida": randf_range(0.55, 0.85), "tam": randf_range(12.0, 18.0), "tipo": "fumaca",
					"cor": Color(0.75, 0.72, 0.68)})
	while _parts.size() > 120:
		_parts.pop_front()
	set_process(true)


func _process(delta: float) -> void:
	for t in _tiros:
		t["t"] += delta
	while not _tiros.is_empty() and _tiros[0]["t"] > _tiros[0]["voo"] + IMPACTO:
		_tiros.pop_front()
	for p in _parts:
		p["t"] += delta
		if p["t"] > 0.0:
			p["vel"] = p["vel"] * pow(0.6, delta)
			p["pos"] += p["vel"] * delta
	while not _parts.is_empty() and _parts[0]["t"] > _parts[0]["vida"]:
		_parts.pop_front()
	_soma.queue_redraw()
	_normal.queue_redraw()
	if _tiros.is_empty() and _parts.is_empty():
		set_process(false)


func _desenhar_normal() -> void:
	for p in _parts:
		if p["tipo"] != "fumaca" or p["t"] <= 0.0:
			continue
		var k: float = p["t"] / p["vida"]
		Pincel.forma(_normal, Pincel.FUMACA, p["pos"], p["tam"] * (0.7 + 1.3 * k), Color(p["cor"], 0.28 * (1.0 - k)), k)


## A bala indo para longe na linha da mira: anéis fechando no ponto (o zoom
## de quem vê a bala se afastar), o núcleo encolhendo e o clarão da arma
## embaixo da tela.
func _voo(para: Vector2, idade: float, voo: float, e: Array) -> void:
	var r0: float = e[1]
	var cor_anel: Color = e[2]
	var k := clampf(idade / voo, 0.0, 1.0)
	var vai := 1.0 - (1.0 - k) * (1.0 - k)
	var forcas := [1.0, 0.6, 0.3]
	for j in 3:
		var kj := clampf((idade - j * 0.014) / voo, 0.0, 1.0)
		if kj >= 1.0:
			continue
		var vj := 1.0 - (1.0 - kj) * (1.0 - kj)
		Pincel.anel(_soma, para, lerpf(r0, 5.0, vj), lerpf(14.0, 2.5, vj), Color(cor_anel, forcas[j] * (1.0 - 0.3 * kj)))
	Pincel.brilho(_soma, para, lerpf(r0 * 0.6, 12.0, vai), Color(e[3], 0.85))
	Pincel.circulo(_soma, para, lerpf(8.0, 2.5, vai), Color(1, 1, 1, 0.95))
	var tela := get_viewport().get_visible_rect().size
	var arma := Vector2(tela.x * 0.5 + (para.x - tela.x * 0.5) * 0.35, tela.y + 70.0)
	Pincel.brilho(_soma, arma, 460.0 * (1.0 - 0.4 * k), Color(e[4], 0.20 * (1.0 - k)))


func _desenhar_soma() -> void:
	for t in _tiros:
		var idade: float = t["t"]
		var voo: float = t["voo"]
		var para: Vector2 = t["para"]
		var e: Array = ESTILOS[t["estilo"]]
		if idade < voo:
			_voo(para, idade, voo, e)
			continue
		var di := clampf((idade - voo) / IMPACTO, 0.0, 1.0)
		var fa := 1.0 - di
		match t["estilo"]:
			"laser":
				Pincel.brilho(_soma, para, 22.0 + 70.0 * di, Color(1.0, 0.25, 0.15, 0.55 * fa))
				Pincel.brilho(_soma, para, 10.0 + 18.0 * di, Color(1.0, 0.9, 0.85, 0.8 * fa))
				Pincel.anel(_soma, para, 12.0 + 58.0 * di, 3.0, Color(1.0, 0.4, 0.3, 0.7 * fa))
			"sol":
				Pincel.brilho(_soma, para, 40.0 + 34.0 * di, Color(1.0, 0.75, 0.3, 0.55 * fa))
				var giro := idade * 2.2
				Pincel.forma(_soma, Pincel.FAISCA, para, 64.0 * (1.0 - 0.35 * di), Color(1.0, 0.92, 0.65, 0.95 * fa), giro)
				Pincel.forma(_soma, Pincel.FAISCA, para, 38.0 * (1.0 - 0.35 * di), Color(1.0, 0.8, 0.45, 0.6 * fa), giro + PI * 0.25)
			"lua":
				Pincel.brilho(_soma, para, 36.0, Color(0.6, 0.8, 1.0, 0.5 * fa))
				Pincel.anel(_soma, para, 18.0 + 48.0 * di, 3.0, Color(0.85, 0.93, 1.0, 0.7 * fa))
				Pincel.forma(_soma, Pincel.FAISCA, para, 44.0 * (1.0 - 0.3 * di), Color(0.9, 0.96, 1.0, 0.85 * fa), PI * 0.25)
			"mar":
				Pincel.anel(_soma, para, 10.0 + 60.0 * di, 3.0, Color(0.75, 0.95, 1.0, 0.6 * fa))
				Pincel.anel(_soma, para, 6.0 + 34.0 * di, 2.0, Color(0.75, 0.95, 1.0, 0.5 * fa))
				Pincel.brilho(_soma, para, 24.0, Color(0.5, 0.85, 1.0, 0.35 * fa))
			"bar":
				Pincel.brilho(_soma, para, 26.0, Color(1.0, 0.6, 0.2, 0.5 * fa))
				Pincel.forma(_soma, Pincel.FAISCA, para, 48.0 * fa + 8.0, Color(1.0, 0.85, 0.5, 0.95 * fa), 0.4)
				Pincel.anel(_soma, para, 8.0 + 40.0 * di, 2.5, Color(1.0, 0.75, 0.4, 0.6 * fa))
	for p in _parts:
		if p["t"] <= 0.0:
			continue
		var k4: float = p["t"] / p["vida"]
		match p["tipo"]:
			"estrela":
				var b := sin(k4 * PI)
				Pincel.forma(_soma, Pincel.FAISCA, p["pos"], p["tam"] * 1.6, Color(p["cor"], 0.8 * b), k4 * 3.0)
			"bolha":
				var tam: float = p["tam"] * (0.6 + 0.6 * k4)
				var b2 := minf(1.0, (1.0 - k4) * 3.0)
				Pincel.forma(_soma, Pincel.BOLHA, p["pos"], tam, Color(p["cor"], 0.85 * b2))
