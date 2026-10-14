class_name Trajetoria
extends CanvasLayer

## Trajetória do tiro: da arma (embaixo da tela) até onde a mira estava.
##
##   laser  (Arena)  feixe vermelho como o da abertura: halo, faixa e miolo
##                   branco, um pulso correndo até o alvo e o clarão no ponto
##   sol    (Egito)  raio de sol dourado com brilhos soltos e uma estrela de
##                   luz no ponto
##   lua    (Egito)  raio de luar prateado-azulado com pó de estrela e um
##                   anel frio no ponto
##   mar    (Mar)    a bala corta a água: risco claro rápido e um rastro de
##                   bolhas que sobem e estouram, anel na água no ponto
##   bar    (Bar)    traçante quente correndo até o alvo e um fio de fumaça
##                   que fica no ar e se desfaz
##
##   Trajetoria.disparar(fase, ponto_na_tela, "laser")
##
## Uma camada por fase (criada no primeiro tiro), um desenho para a luz
## (mistura somada) e um para a fumaça; só redesenha enquanto há tiro no ar.

const Pincel := preload("res://scripts/pincel.gd")
const MAX_TIROS := 8
# (o som é o estampido de cada fase: raio de sol, de luar, arpão no mar,
# laser na arena, pistola no bar; o rastro não toca nada por cima)

var _tiros: Array = []         # {de, para, t, vida, estilo}
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
	var tela := get_viewport().get_visible_rect().size
	var de := Vector2(lerpf(tela.x * 0.5, para.x, 0.3), tela.y + 40.0)
	var vida := {"laser": 0.17, "sol": 0.30, "lua": 0.32, "mar": 0.20, "bar": 0.10}.get(estilo, 0.2) as float
	_tiros.append({"de": de, "para": para, "t": 0.0, "vida": vida, "estilo": estilo})
	while _tiros.size() > MAX_TIROS:
		_tiros.pop_front()
	var d := para - de
	match estilo:
		"sol":
			for i in 7:
				var k := randf()
				_parts.append({"pos": de + d * k, "vel": Vector2(randf_range(-30, 30), randf_range(-50, -10)), "t": 0.0,
					"vida": randf_range(0.35, 0.7), "tam": randf_range(3.0, 7.0), "tipo": "brilho", "cor": Color(1.0, 0.85, 0.45)})
		"lua":
			for i in 9:
				var k := randf()
				_parts.append({"pos": de + d * k + Vector2(randf_range(-8, 8), 0), "vel": Vector2(randf_range(-20, 20), randf_range(-30, 10)), "t": 0.0,
					"vida": randf_range(0.4, 0.8), "tam": randf_range(2.0, 4.5), "tipo": "brilho", "cor": Color(0.75, 0.88, 1.0)})
		"mar":
			var n := clampi(int(d.length() / 26.0), 12, 40)
			for i in n:
				var k := (i + randf()) / n
				var lado := Vector2(-d.y, d.x).normalized() * randf_range(-10.0, 10.0)
				_parts.append({"pos": de + d * k + lado, "vel": Vector2(randf_range(-14, 14), randf_range(-90, -35)), "t": -k * 0.05,
					"vida": randf_range(0.6, 1.1), "tam": randf_range(4.0, 11.0), "tipo": "bolha", "cor": Color(0.85, 0.97, 1.0)})
		"bar":
			var n2 := clampi(int(d.length() / 70.0), 6, 16)
			for i in n2:
				var k := (i + 0.5) / n2
				_parts.append({"pos": de + d * k, "vel": Vector2(randf_range(-8, 8), randf_range(-26, -10)), "t": -k * 0.08,
					"vida": randf_range(0.5, 0.8), "tam": randf_range(10.0, 16.0), "tipo": "fumaca", "cor": Color(0.75, 0.72, 0.68)})
	while _parts.size() > 160:
		_parts.pop_front()
	set_process(true)


func _process(delta: float) -> void:
	for t in _tiros:
		t["t"] += delta
	while not _tiros.is_empty() and _tiros[0]["t"] > _tiros[0]["vida"] + 0.35:
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


func _desenhar_soma() -> void:
	for t in _tiros:
		var idade: float = t["t"]
		var vida: float = t["vida"]
		var de: Vector2 = t["de"]
		var para: Vector2 = t["para"]
		var a := clampf(1.0 - idade / vida, 0.0, 1.0)
		var depois := clampf((idade - vida) / 0.35, 0.0, 1.0)   # clarão no ponto ainda some depois
		match t["estilo"]:
			"laser":
				if a > 0.0:
					Pincel.laser(_soma, de, para, Color(1.0, 0.1, 0.06, 0.22 * a), 34.0)
					Pincel.laser(_soma, de, para, Color(1.0, 0.18, 0.12, 0.5 * a), 13.0)
					Pincel.laser(_soma, de, para, Color(1.0, 0.88, 0.85, 0.95 * a), 4.0)
					var k := clampf(idade / 0.07, 0.0, 1.0)
					var cabeca := de.lerp(para, k)
					Pincel.brilho(_soma, cabeca, 26.0, Color(1.0, 0.5, 0.45, 0.8 * a))
				var r := 20.0 + 70.0 * clampf(idade / (vida + 0.35), 0.0, 1.0)
				Pincel.brilho(_soma, para, r, Color(1.0, 0.25, 0.15, 0.5 * (1.0 - depois)))
				Pincel.brilho(_soma, para, r * 0.4, Color(1.0, 0.9, 0.85, 0.7 * (1.0 - depois)))
			"sol":
				if a > 0.0:
					Pincel.laser(_soma, de, para, Color(1.0, 0.62, 0.15, 0.20 * a), 50.0)
					Pincel.laser(_soma, de, para, Color(1.0, 0.82, 0.40, 0.45 * a), 17.0)
					Pincel.laser(_soma, de, para, Color(1.0, 0.98, 0.85, 0.95 * a), 5.0)
				var fa := 1.0 - depois
				var raio := 40.0 + 30.0 * (1.0 - a)
				Pincel.brilho(_soma, para, raio, Color(1.0, 0.75, 0.3, 0.55 * fa))
				var giro := idade * 2.0
				for i in 2:
					var dir := Vector2.RIGHT.rotated(giro + i * PI * 0.5) * raio * 1.3
					Pincel.laser(_soma, para - dir, para + dir, Color(1.0, 0.9, 0.6, 0.6 * fa), 4.0)
			"lua":
				if a > 0.0:
					Pincel.laser(_soma, de, para, Color(0.45, 0.65, 1.0, 0.20 * a), 46.0)
					Pincel.laser(_soma, de, para, Color(0.70, 0.85, 1.0, 0.45 * a), 15.0)
					Pincel.laser(_soma, de, para, Color(0.95, 0.98, 1.0, 0.95 * a), 4.0)
				var fa2 := 1.0 - depois
				Pincel.brilho(_soma, para, 36.0, Color(0.6, 0.8, 1.0, 0.5 * fa2))
				Pincel.anel(_soma, para, 18.0 + 46.0 * clampf(idade / (vida + 0.35), 0.0, 1.0), 3.0, Color(0.85, 0.93, 1.0, 0.7 * fa2))
			"mar":
				if a > 0.0:
					Pincel.laser(_soma, de, para, Color(0.4, 0.8, 1.0, 0.28 * a), 26.0)
					Pincel.laser(_soma, de, para, Color(0.8, 0.97, 1.0, 0.95 * a), 4.5)
				var k2 := clampf(idade / (vida + 0.35), 0.0, 1.0)
				Pincel.anel(_soma, para, 10.0 + 60.0 * k2, 3.0, Color(0.75, 0.95, 1.0, 0.6 * (1.0 - k2)))
				Pincel.anel(_soma, para, 6.0 + 34.0 * k2, 2.0, Color(0.75, 0.95, 1.0, 0.5 * (1.0 - k2)))
			"bar":
				# traçante: um risco quente correndo da arma até o ponto
				var k3 := clampf(idade / vida, 0.0, 1.0)
				if k3 < 1.0:
					var cabeca2 := de.lerp(para, k3)
					var cauda := de.lerp(para, maxf(0.0, k3 - 0.35))
					Pincel.laser(_soma, cauda, cabeca2, Color(1.0, 0.55, 0.15, 0.45), 10.0)
					Pincel.laser(_soma, cauda, cabeca2, Color(1.0, 0.92, 0.6, 0.95), 3.0)
				var fb := 1.0 - depois
				Pincel.brilho(_soma, para, 24.0, Color(1.0, 0.6, 0.2, 0.5 * fb * (1.0 if k3 >= 1.0 else 0.0)))
	for p in _parts:
		if p["t"] <= 0.0:
			continue
		var k4: float = p["t"] / p["vida"]
		match p["tipo"]:
			"brilho":
				var b := sin(k4 * PI)
				Pincel.brilho(_soma, p["pos"], p["tam"] * 2.2, Color(p["cor"], 0.5 * b))
				Pincel.circulo(_soma, p["pos"], p["tam"] * 0.4, Color(1, 1, 1, 0.8 * b))
			"bolha":
				var tam: float = p["tam"] * (0.6 + 0.6 * k4)
				var b2 := minf(1.0, (1.0 - k4) * 3.0)
				Pincel.forma(_soma, Pincel.BOLHA, p["pos"], tam, Color(p["cor"], 0.85 * b2))
