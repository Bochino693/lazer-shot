class_name EgitoFeixes
extends Node2D

## Os quatro feixes de energia do Egito, vivos: saem do cristal e chegam nos
## cristais das pontas dos obeliscos (antes eram pintados na foto). Cada ponta
## anda com o plano dela quando a câmera anda (o cristal a Z 1,2, os
## obeliscos a Z 1,55), então o feixe sempre liga as duas coisas certas.
##   - pulsos correndo do cristal para o obelisco, mais fortes com o grave;
##   - um lado apaga quando o cristal da ponta daquele obelisco quebra; tudo
##     apaga quando o cristal do meio quebra;
##   - a carga da descarga deixa os feixes mais grossos, rápidos e estalando;
##   - descarga(): raios saindo das pontas acesas até os alvos.
## Coordenadas: px da imagem do fundo (filho do DesertoVivo).

const SHADER := preload("res://shaders/egito_feixe.gdshader")
const Z_CRISTAL := 1.2
const Z_OBELISCO := 1.554
# [ponta no cristal, ponta no obelisco, lado (0 = esq, 1 = dir)]
const FEIXES := [
	[Vector2(470, 668), Vector2(207, 783), 0],
	[Vector2(550, 670), Vector2(815, 783), 1],
	[Vector2(463, 858), Vector2(224, 992), 0],
	[Vector2(556, 866), Vector2(800, 992), 1],
]
# cristais das pontas dos obeliscos (de onde saem os raios da descarga)
const PONTAS := [Vector2(209, 792), Vector2(813, 792)]
const PONTA_CRISTAL := Vector2(506, 640)

var camera_local := Vector2.ZERO   # câmera em px da imagem (DesertoVivo)
var noite := 0.0
var grave := 0.0
var batida := 0.0
var energia := 1.0                 # cristal do meio (0 = quebrado)
var lado_aceso := [1.0, 1.0]       # cristais das pontas (0 = quebrado)
var carga := 0.0                   # 0..1

var _luz_lado := [1.0, 1.0]
var _mat: ShaderMaterial
var _branco: Texture2D
var _brilho: Texture2D
var _faiscas: Node2D
var _raios: Node2D
var _raios_lista: Array[Dictionary] = []   # {de, ate, t, vida, pontos, prox}
var _t := 0.0


func _init() -> void:
	name = "Feixes"
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_branco = ImageTexture.create_from_image(img)
	_brilho = FundoVivo.brilho_redondo()
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_faiscas = Node2D.new()
	_faiscas.name = "PontasAcesas"
	_faiscas.material = soma
	_faiscas.draw.connect(_desenhar_pontas)
	add_child(_faiscas)
	_raios = Node2D.new()
	_raios.name = "Raios"
	_raios.material = soma
	_raios.z_as_relative = false     # os raios passam na frente de tudo
	_raios.z_index = 320
	_raios.draw.connect(_desenhar_raios)
	add_child(_raios)


func _par(z: float) -> Vector2:
	return camera_local * (1.0 - 1.0 / z)


func _cor() -> Color:
	return Color(1.0, 0.80, 0.40).lerp(Color(1.0, 0.24, 0.30), noite)


func _process(delta: float) -> void:
	_t += delta
	for i in 2:
		var alvo: float = float(lado_aceso[i]) * energia
		# acende devagar, apaga num tranco
		var vel := 1.6 if alvo > _luz_lado[i] else 9.0
		_luz_lado[i] = move_toward(_luz_lado[i], alvo, delta * vel)
	_mat.set_shader_parameter("vel", 0.6 + 1.6 * carga + 0.6 * grave)
	_mat.set_shader_parameter("carga", carga)
	_mat.set_shader_parameter("grave", grave)
	for r in _raios_lista:
		r["t"] += delta
		r["prox"] -= delta
		if r["prox"] <= 0.0:
			r["prox"] = 0.045
			r["pontos"] = _zigue(r["de"], r["ate"])
	for i in range(_raios_lista.size() - 1, -1, -1):
		if _raios_lista[i]["t"] >= _raios_lista[i]["vida"]:
			_raios_lista.remove_at(i)
	queue_redraw()
	_faiscas.queue_redraw()
	if not _raios_lista.is_empty() or _raios_tinha:
		_raios.queue_redraw()
	_raios_tinha = not _raios_lista.is_empty()

var _raios_tinha := false


func _draw() -> void:
	var cor := _cor()
	var larg := 20.0 + 10.0 * carga + 4.0 * batida
	for f in FEIXES:
		var luz: float = _luz_lado[f[2]]
		if luz <= 0.01:
			continue
		var a: Vector2 = f[0] + _par(Z_CRISTAL)
		var b: Vector2 = f[1] + _par(Z_OBELISCO)
		var d := b - a
		draw_set_transform(a, d.angle())
		draw_texture_rect(_branco, Rect2(0.0, -larg * 0.5, d.length(), larg), false,
			Color(cor, luz * (0.85 + 0.25 * batida)))
	draw_set_transform(Vector2.ZERO)


## As pontas acesas: brilho pulsando onde o feixe chega no obelisco e na saída
## do cristal.
func _desenhar_pontas() -> void:
	var cor := _cor()
	for i in 2:
		var luz: float = _luz_lado[i]
		if luz <= 0.01:
			continue
		var p: Vector2 = PONTAS[i] + _par(Z_OBELISCO)
		var s := (46.0 + 14.0 * sin(_t * 5.0 + i * 1.7) + 30.0 * carga + 18.0 * batida) * luz
		_faiscas.draw_texture_rect(_brilho, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(cor, 0.75 * luz))
		_faiscas.draw_texture_rect(_brilho, Rect2(p - Vector2(s, s) * 0.18, Vector2(s, s) * 0.36), false, Color(1, 1, 1, 0.8 * luz))
	for f in FEIXES:
		var luz: float = _luz_lado[f[2]]
		if luz <= 0.01:
			continue
		var b: Vector2 = f[1] + _par(Z_OBELISCO)
		var s2 := (22.0 + 8.0 * sin(_t * 7.0 + b.y)) * luz
		_faiscas.draw_texture_rect(_brilho, Rect2(b - Vector2(s2, s2) * 0.5, Vector2(s2, s2)), false, Color(cor, 0.9 * luz))


## Raios da descarga: das pontas acesas (ou do topo do cristal) até cada alvo
## (px da imagem). Duram meio segundo, redesenhados em zigue-zague.
func descarga(alvos: Array) -> void:
	var origens: Array[Vector2] = []
	for i in 2:
		if _luz_lado[i] > 0.3:
			origens.append(PONTAS[i] + _par(Z_OBELISCO))
	if origens.is_empty():
		origens.append(PONTA_CRISTAL + _par(Z_CRISTAL))
	for alvo: Vector2 in alvos:
		var de: Vector2 = origens[0]
		for o in origens:
			if o.distance_squared_to(alvo) < de.distance_squared_to(alvo):
				de = o
		_raios_lista.append({"de": de, "ate": alvo, "t": 0.0, "vida": randf_range(0.42, 0.55),
			"pontos": _zigue(de, alvo), "prox": 0.045})
	_raios.queue_redraw()


func _zigue(de: Vector2, ate: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var d := ate - de
	var n := Vector2(-d.y, d.x).normalized()
	var passos := clampi(int(d.length() / 28.0), 4, 18)
	for i in passos + 1:
		var u := float(i) / passos
		var desvio := 0.0 if i == 0 or i == passos else randf_range(-1.0, 1.0) * minf(26.0, d.length() * 0.08)
		pts.append(de + d * u + n * desvio)
	return pts


func _desenhar_raios() -> void:
	if _raios_lista.is_empty():
		return
	var cor := _cor()
	var largo := Triangulos.new()
	var fino := Triangulos.new()
	for r in _raios_lista:
		var k: float = 1.0 - r["t"] / r["vida"]
		var pisca := 0.6 + 0.4 * sin(r["t"] * 60.0)
		largo.linha(r["pontos"], Color(cor, 0.55 * k * pisca), 16.0)
		fino.linha(r["pontos"], Color(1.0, 1.0, 1.0, 0.95 * k * pisca), 4.0)
		var s := 120.0 * k
		_raios.draw_texture_rect(_brilho, Rect2(r["ate"] - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(cor, 0.8 * k))
	largo.desenhar(_raios)
	fino.desenhar(_raios)
