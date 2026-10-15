class_name MarCardumeDourado
extends Node2D

## Cardume dourado (bônus do Mar). De tempos em tempos um cardume de peixes de
## ouro atravessa a cena no meio da água, nadando junto (cada peixe com o seu
## balanço e o rabo batendo) e deixando um rastro de brilho. Cada peixe
## acertado vale pontos (mar.gd): ele estoura em faíscas de ouro e sai
## girando; o resto do cardume se assusta e nada mais rápido. Pegar todos
## vale o tesouro.
## Fica em alvos_root (mesmas coordenadas dos alvos), na distância Z (anda com
## a câmera como os alvos daquela distância: o mar.gd passa o deslocamento).
## Um nó só: os peixes saem num desenho só (triângulos com a textura).

const PEIXE := preload("res://sprites/mar_peixe_dourado.png")
const N := 9

signal saiu

var z := 1.5
var desloca := Vector2.ZERO    # paralaxe da câmera (mar.gd)
var vivo := true

var _t := 0.0
var _dur := 7.0
var _de := Vector2.ZERO
var _ate := Vector2.ZERO
var _onda := 0.0
var _esc := 0.5
var _peixes: Array[Dictionary] = []   # {off, fase, esc}
var _pegos := 0
var _pressa := 1.0                     # o cardume assustado nada mais rápido
var _dir := 1.0                        # 1 = nada para a direita, -1 = esquerda
var _faiscas: Array[Dictionary] = []
var _luz: Node2D
var _brilho: Texture2D


## tela: tamanho da tela; esc: tamanho do peixe na distância z.
func montar(tela: Vector2, z_dist: float, esc: float) -> void:
	z = z_dist
	_esc = esc
	_brilho = FundoVivo.brilho_redondo()
	var para_direita := randf() < 0.5
	var y := randf_range(0.36, 0.62) * tela.y
	var margem := 260.0
	_de = Vector2(-margem if para_direita else tela.x + margem, y)
	_ate = Vector2(tela.x + margem if para_direita else -margem, y + randf_range(-160.0, 160.0))
	_dur = randf_range(6.0, 7.5)
	_onda = randf() * TAU
	# formação solta (gota): o da frente sozinho, os outros atrás e dos lados
	for i in N:
		var fila := floori(sqrt(float(i)) + 0.0001)
		var off := Vector2(-fila * 70.0 + randf_range(-14.0, 14.0), (i - fila * fila - fila) * 46.0 + randf_range(-10.0, 10.0))
		_peixes.append({"off": off, "fase": randf() * TAU, "esc": randf_range(0.85, 1.12), "fuga": Vector2.ZERO, "giro": 0.0,
			"pego": -1.0})
	_dir = 1.0 if para_direita else -1.0
	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_luz = Node2D.new()
	_luz.material = soma
	_luz.show_behind_parent = true
	_luz.draw.connect(_desenhar_luz)
	add_child(_luz)


func _centro() -> Vector2:
	var k := clampf(_t / _dur, 0.0, 1.0)
	var c := _de.lerp(_ate, k)
	c.y += sin(k * TAU * 1.2 + _onda) * 40.0
	return c + desloca


## Onde está cada peixe agora (coordenadas do pai, alvos_root).
func _pos_peixe(p: Dictionary) -> Vector2:
	var c := _centro()
	var off: Vector2 = p["off"] * _esc * 1.6
	off += Vector2(sin(_t * 1.7 + p["fase"]) * 10.0, sin(_t * 2.3 + p["fase"] * 1.3) * 8.0) * _esc * 1.6
	var pego: float = p["pego"]
	if pego >= 0.0:
		off += p["fuga"] * (1.0 - exp(-pego * 2.4)) / 2.4
	return c + Vector2(off.x * _dir, off.y)


func _process(delta: float) -> void:
	_t += delta * _pressa
	for p in _peixes:
		if p["pego"] >= 0.0:
			p["pego"] += delta
	if (_t >= _dur or _pegos >= N) and _faiscas.is_empty():
		vivo = false
		saiu.emit()
		queue_free()
		return
	if _pegos >= N:
		vivo = false
	# rastro de brilho de vez em quando, de um peixe qualquer
	if vivo and randf() < delta * 14.0:
		var p: Dictionary = _peixes[randi() % _peixes.size()]
		if p["pego"] < 0.0:
			_faiscas.append({"pos": _pos_peixe(p) - Vector2(30.0 * _dir, 0.0) * _esc, "vel": Vector2(0, -18.0),
				"t": 0.0, "vida": randf_range(0.5, 0.9), "tam": randf_range(10.0, 20.0) * _esc / 0.5})
	for f in _faiscas:
		f["t"] += delta
		f["vel"] *= pow(0.3, delta)
		f["pos"] += f["vel"] * delta
	for i in range(_faiscas.size() - 1, -1, -1):
		if _faiscas[i]["t"] >= _faiscas[i]["vida"]:
			_faiscas.remove_at(i)
	queue_redraw()
	_luz.queue_redraw()


## Tiro em `pos` (coordenadas do pai): 0 = errou, 1 = pegou um peixe,
## 2 = pegou o último do cardume (todos).
func acertar(pos: Vector2) -> int:
	if not vivo:
		return 0
	# só vale no desenho do peixe (o pixel dele, na pose de agora)
	var tam := PEIXE.get_size()
	var melhor: Dictionary = {}
	var dist := INF
	for p in _peixes:
		if p["pego"] >= 0.0:
			continue
		var q := _forma_peixe(p).affine_inverse() * pos + tam * 0.5
		if not MascaraAcerto.no_pixel(PEIXE, q):
			continue
		var d := _pos_peixe(p).distance_to(pos)
		if d < dist:
			dist = d
			melhor = p
	if melhor.is_empty():
		return 0
	_pegar(melhor, pos)
	return 2 if _pegos >= N else 1


func pegos() -> int:
	return _pegos


## O peixe acertado estoura em ouro e sai girando; o resto se assusta.
func _pegar(p: Dictionary, pos: Vector2) -> void:
	_pegos += 1
	_pressa = minf(_pressa + 0.12, 1.7)
	var c := _pos_peixe(p)
	p["pego"] = 0.0
	var d: Vector2 = c - pos
	if d.length() < 1.0:
		d = Vector2.RIGHT.rotated(randf() * TAU)
	p["fuga"] = d.normalized().rotated(randf_range(-0.6, 0.6)) * randf_range(420.0, 700.0) * _esc / 0.5
	p["giro"] = randf_range(-10.0, 10.0)
	p["onde"] = c
	var n := 14 if _pegos < N else 34
	for i in n:
		_faiscas.append({"pos": c, "vel": Vector2.RIGHT.rotated(randf() * TAU) * randf_range(100.0, 360.0) * _esc / 0.5,
			"t": 0.0, "vida": randf_range(0.45, 0.9), "tam": randf_range(12.0, 26.0) * _esc / 0.5, "estrela": i % 3 == 0})


func _draw() -> void:
	# os peixes (o nó fica na origem do pai: desenha nas coordenadas dele)
	var tam := PEIXE.get_size()
	var pontos := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cores := PackedColorArray()
	var indices := PackedInt32Array()
	var a := minf(1.0, _t / 0.4) * clampf((_dur - _t) / 0.4, 0.0, 1.0)
	if a > 0.0:
		for p in _peixes:
			var pego: float = p["pego"]
			var af := a if pego < 0.0 else a * clampf(1.0 - (pego - 0.25) / 0.5, 0.0, 1.0)
			if af <= 0.0:
				continue
			var xf := _forma_peixe(p)
			var ini := pontos.size()
			for v in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
				pontos.append(xf * (v * tam))
				uvs.append(v + Vector2(0.5, 0.5))
				cores.append(Color(1, 1, 1, af))
			indices.append_array([ini, ini + 1, ini + 2, ini, ini + 2, ini + 3])
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, pontos, cores, uvs,
			PackedInt32Array(), PackedFloat32Array(), PEIXE.get_rid())


func _desenhar_luz() -> void:
	# brilho dourado em volta do cardume e as faíscas
	var a := minf(1.0, _t / 0.4) * clampf((_dur - _t) / 0.4, 0.0, 1.0)
	for p in _peixes:
		var pego: float = p["pego"]
		if pego < 0.0:
			var c := _pos_peixe(p)
			var s := 120.0 * _esc / 0.5
			_luz.draw_texture_rect(_brilho, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false,
				Color(1.0, 0.78, 0.3, 0.30 * a))
		elif pego < 0.3:
			# o estouro de ouro do peixe pego
			var k := pego / 0.3
			var s2 := 300.0 * _esc / 0.5 * (0.5 + k)
			var c2: Vector2 = p["onde"]
			_luz.draw_texture_rect(_brilho, Rect2(c2 - Vector2(s2, s2) * 0.5, Vector2(s2, s2)), false,
				Color(1.0, 0.85, 0.4, 0.9 * (1.0 - k)))
	for f in _faiscas:
		var k: float = f["t"] / f["vida"]
		var s: float = f["tam"] * (1.0 - 0.5 * k)
		var pos: Vector2 = f["pos"]
		var cor := Color(1.0, 0.86, 0.42, (1.0 - k) * (0.6 + 0.4 * sin(f["t"] * 20.0)))
		_luz.draw_texture_rect(_brilho, Rect2(pos - Vector2(s, s) * 0.5, Vector2(s, s)), false, cor)
		if f.get("estrela", false):
			var b := s * 1.4
			var e := 3.0
			_luz.draw_texture_rect(_brilho, Rect2(pos - Vector2(b, e * 0.5), Vector2(b * 2.0, e)), false, cor)
			_luz.draw_texture_rect(_brilho, Rect2(pos - Vector2(e * 0.5, b), Vector2(e, b * 2.0)), false, cor)


## Onde e como o peixe está agora (posição, tamanho, rabo batendo, giro):
## a mesma conta no desenho e no tiro.
func _forma_peixe(p: Dictionary) -> Transform2D:
	var pego: float = p["pego"]
	var e: float = _esc * float(p["esc"])
	# rabo batendo: o peixe estica e encolhe um pouquinho de lado
	var bate := 1.0 + 0.06 * sin(_t * 14.0 + p["fase"])
	var giro: float = sin(_t * 1.7 + p["fase"]) * 0.10 + (p["giro"] * pego if pego >= 0.0 else 0.0)
	return Transform2D(giro * _dir, Vector2(e * bate * _dir, e), 0.0, _pos_peixe(p))
