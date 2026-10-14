class_name BarVinho
extends Node2D

## O barril do Bar é alvo de bônus: cada furo de bala solta o vinho.
##   jato   logo depois do tiro o vinho sai com pressão e cai em arco no chão,
##          na frente do barril (furo do lado esquerdo joga para a esquerda,
##          do meio cai para a frente), espirrando gotas onde bate
##   fio    a pressão cai (o nível baixa) e o jato vira um fio que escorre
##          pela madeira até o pé do barril; depois só pinga e para
##   marca  fica a madeira molhada (mancha escura do furo até o chão) e a
##          poça no chão, que cresce com o vinho que caiu e tem o reflexo da
##          janela
## Posições em px de back_new.png (o nó acompanha o fundo). Um nó só para o
## barril inteiro, um desenho por quadro enquanto escorre; parado não gasta.

const SOM_JORRA := preload("res://songs/vinho_jorra.wav")
const MAX_FUROS := 6
const CENTRO_X := 900.0          # meio do barril
const BASE_Y := 1424.0           # pé do barril (encosta no chão)
const CHAO_Y := 1440.0           # chão logo na frente do barril
const COR := Color(0.40, 0.02, 0.07, 0.95)
const COR_CLARA := Color(0.86, 0.22, 0.30)
const COR_MOLHADO := Color(0.16, 0.02, 0.03, 0.42)
const TEMPO_JATO := 1.5          # a pressão cai à metade a cada ~1 s
const VIDA_FIO := 13.0           # s até parar de escorrer
const VIDA_PINGO := 5.0          # e mais estes só pingando
const PONTOS := 14

var _fundo: Sprite2D
var _furos: Array[Dictionary] = []
var _gotas: Array[Dictionary] = []
var _t := 0.0


static func criar(pai: Node, fundo: Sprite2D) -> BarVinho:
	var v := BarVinho.new()
	v.name = "VinhoBarril"
	v._fundo = fundo
	v.top_level = true
	v.z_index = 2
	pai.add_child(v)
	v._acompanhar()
	v.set_process(false)
	return v


## Novo furo no ponto (global) do tiro. Devolve quantos furos já tem.
func furo(pos_global: Vector2) -> int:
	_acompanhar()
	var p := global_transform.affine_inverse() * pos_global
	if _furos.size() >= MAX_FUROS:
		_furos.pop_front()
	var lado := clampf((p.x - CENTRO_X) / 124.0, -1.0, 1.0)
	_furos.append({"p": p, "t": 0.0, "lado": lado, "volume": 0.0, "semente": randf() * 50.0,
		"pingo": 0.0, "x_poca": p.x + lado * 40.0})
	# o primeiro esguicho: gotas espirrando do furo
	for i in 14:
		if _gotas.size() >= 40:
			break
		_gotas.append({"pos": p, "vel": Vector2(lado * randf_range(60.0, 210.0) + randf_range(-70.0, 70.0), randf_range(-170.0, 30.0)),
			"chao": CHAO_Y + randf_range(0.0, 60.0), "tam": randf_range(1.8, 3.6)})
	Maquina.efeito(SOM_JORRA, -7.0, randf_range(0.92, 1.08))
	set_process(true)
	return _furos.size()


func _acompanhar() -> void:
	if _fundo != null and is_instance_valid(_fundo) and _fundo.texture != null:
		global_transform = BarTiro._px_para_global(_fundo)


## Pressão do vinho no furo (1 = acabou de furar, 0 = parou).
static func _pressao(idade: float) -> float:
	return pow(0.5, idade / TEMPO_JATO * 1.5)


func _process(delta: float) -> void:
	_t += delta
	var vivo := false
	for f in _furos:
		f["t"] += delta
		var idade: float = f["t"]
		if idade < VIDA_FIO:
			vivo = true
			var pr := _pressao(idade)
			f["volume"] = minf(f["volume"] + delta * (0.25 + 0.75 * pr), 6.0)
			# espirros onde o jato bate no chão
			if pr > 0.12 and randf() < delta * 30.0 * pr and _gotas.size() < 40:
				var bate := _ponto_jato(f, 1.0)
				_gotas.append({"pos": bate, "vel": Vector2(randf_range(-70.0, 70.0), randf_range(-150.0, -50.0)) * (0.5 + pr),
					"chao": bate.y + randf_range(2.0, 10.0), "tam": randf_range(1.6, 3.2)})
		elif idade < VIDA_FIO + VIDA_PINGO:
			vivo = true
			f["pingo"] -= delta
			if f["pingo"] <= 0.0:
				f["pingo"] = randf_range(0.35, 0.8)
				_gotas.append({"pos": f["p"] + Vector2(0.0, 4.0), "vel": Vector2(0.0, 20.0), "chao": CHAO_Y + 6.0,
					"tam": 2.4, "escorre": true})
	var i := _gotas.size() - 1
	while i >= 0:
		var g: Dictionary = _gotas[i]
		if g.get("escorre", false) and g["pos"].y < BASE_Y:
			g["vel"] = Vector2(0.0, minf(g["vel"].y + 260.0 * delta, 160.0))   # desce grudada na madeira
		else:
			g["vel"] += Vector2(0.0, 900.0) * delta
		g["pos"] += g["vel"] * delta
		if g["pos"].y > g["chao"]:
			_gotas.remove_at(i)
		i -= 1
	queue_redraw()
	if not vivo and _gotas.is_empty():
		set_process(false)


## Ponto u (0 no furo .. 1 no chão) do vinho saindo do furo f agora: com
## pressão um arco que vai para o lado e para a frente (mais embaixo na
## tela); sem pressão o fio descendo rente à madeira.
func _ponto_jato(f: Dictionary, u: float) -> Vector2:
	var p: Vector2 = f["p"]
	var lado: float = f["lado"]
	var pr := _pressao(f["t"])
	var k := smoothstep(0.04, 0.4, pr)
	var bate := Vector2(p.x + (lado * 150.0 - 12.0) * pr, CHAO_Y + 70.0 * pr)
	var curva := lerpf(0.75, 0.2, k)
	var jato := Vector2(lerpf(p.x, bate.x, sqrt(u) * 0.6 + u * 0.4), p.y + (bate.y - p.y) * (curva * u * u + (1.0 - curva) * u))
	# o fio: desce rente ao barril (um tico para fora embaixo) até o pé e
	# escorre para a frente até o chão
	var y_fio := lerpf(p.y, CHAO_Y + 4.0, u)
	var fio := Vector2(p.x + lado * 4.0 * u + sin(u * 9.0 + f["semente"]) * 0.8, y_fio)
	return fio.lerp(jato, k)


func _draw() -> void:
	# a madeira molhada (do furo até o pé) e as poças no chão
	for f in _furos:
		var p: Vector2 = f["p"]
		var fim := minf(1.0, f["t"] / 1.2)
		var y1 := lerpf(p.y, BASE_Y, fim)
		draw_line(p, Vector2(p.x + f["lado"] * 3.0, y1), COR_MOLHADO, 7.0)
	for f in _furos:
		var vol: float = f["volume"]
		if vol <= 0.01:
			continue
		var r := 10.0 + 26.0 * sqrt(vol)
		var c := Vector2(f["x_poca"], CHAO_Y + 22.0 + r * 0.08)
		draw_set_transform(c, 0.0, Vector2(1.0, 0.26))
		draw_circle(Vector2.ZERO, r, Color(0.20, 0.01, 0.03, 0.82))
		draw_circle(Vector2(-r * 0.2, -r * 0.25), r * 0.62, Color(0.34, 0.03, 0.07, 0.6))
		# reflexo da janela (luz vem do alto à esquerda)
		draw_circle(Vector2(-r * 0.35, -r * 0.42), r * 0.26, Color(0.95, 0.62, 0.52, 0.22))
		draw_set_transform(Vector2.ZERO)
	# os jatos / fios
	for f in _furos:
		var idade: float = f["t"]
		if idade >= VIDA_FIO:
			continue
		var pr := _pressao(idade)
		var largura := lerpf(1.8, 9.0, smoothstep(0.0, 0.6, pr)) * (1.0 - smoothstep(VIDA_FIO - 2.0, VIDA_FIO, idade) * 0.6)
		var tira := PackedVector2Array()
		var meio := PackedVector2Array()
		var ant := _ponto_jato(f, 0.0)
		for k in PONTOS + 1:
			var u := float(k) / PONTOS
			var q := _ponto_jato(f, u)
			var prox := _ponto_jato(f, minf(1.0, u + 1.0 / PONTOS))
			var tang := (prox - ant).normalized()
			if tang == Vector2.ZERO:
				tang = Vector2.DOWN
			var nrm := Vector2(-tang.y, tang.x)
			# afina descendo e treme um pouco (o jato não é liso)
			var w := largura * (1.0 - 0.35 * u) * (1.0 + 0.18 * sin(_t * 23.0 + u * 11.0 + f["semente"]))
			tira.append(q + nrm * w * 0.5)
			tira.append(q - nrm * w * 0.5)
			meio.append(q - nrm * w * 0.18)
			ant = q
		# uma tira de triângulos (não depende de triangular um contorno)
		var idx := PackedInt32Array()
		for k in PONTOS:
			idx.append_array([2 * k, 2 * k + 1, 2 * k + 2, 2 * k + 1, 2 * k + 3, 2 * k + 2])
		var cores := PackedColorArray()
		cores.resize(tira.size())
		cores.fill(COR)
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, tira, cores)
		draw_polyline(meio, Color(COR_CLARA, 0.55), maxf(1.0, largura * 0.22))
		# o vinho correndo: brilhos que descem pelo jato
		for n in 2:
			var u2 := fmod(_t * (1.6 + pr * 1.4) + n * 0.5 + f["semente"], 1.0)
			draw_circle(_ponto_jato(f, u2), maxf(1.0, largura * 0.28), Color(1.0, 0.55, 0.6, 0.45))
		# o furo cheio de vinho
		draw_circle(f["p"], 3.2, COR)
	for g in _gotas:
		draw_circle(g["pos"], g["tam"], COR)
