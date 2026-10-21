extends "res://scripts/fase.gd"

## BAR DO FAROESTE, em 2D para a Mali-450.
##
## Garrafas nas quatro prateleiras: GIN +20 (embaixo), RUM +50, VODKA +80,
## WHISKY +100 (em cima). A GARRAFA VERDE COM CAVEIRA tira 500 (+20 a cada
## erro seguido). As garrafas caem do alto na tábua e assentam; ficam um
## tempo e saem, ou viram a verde de caveira (cada vez mais com os pontos).
## Combo de acertos seguidos em até 2,2 s.
##
## O cenário responde a cada tiro: a madeira lasca e fica o furo; o BARRIL é
## bônus (+40 por furo, até 6) e o vinho jorra pelo furo; a JANELA estilhaça
## e o sol entra mais forte. O sol pela janela é um feixe que respira, com
## poeira brilhando dentro.

const JANELA = 2.2
const X_COLUNAS = {
	100: [190.0, 315.0, 440.0, 565.0, 690.0],
	80: [190.0, 355.0, 520.0, 685.0],
	50: [190.0, 355.0, 520.0, 685.0],
	20: [110.0, 220.0, 330.0, 440.0, 550.0, 660.0],
}
const Y_PRATELEIRA = {100: 575.0, 80: 815.0, 50: 1100.0, 20: 1400.0}
const ESCALA_GARRAFA = {100: 0.50, 80: 0.56, 50: 0.62, 20: 0.58}
const ESCALA_FALSA = {100: 0.81, 80: 0.85, 50: 0.96, 20: 1.00}
const PE = 26.0                         # o pé da garrafa abaixo da linha da prateleira
const NOMES = {100: "whisky", 80: "vodka", 50: "rum", 20: "gin"}
const LIQUIDO = {"gin": Color(0.85, 0.95, 1.0, 0.85), "rum": Color(0.78, 0.40, 0.10, 0.9), "vodka": Color(0.9, 0.97, 1.0, 0.85),
	"whisky": Color(0.80, 0.50, 0.12, 0.9), "falsa": Color(0.35, 0.85, 0.25, 0.9)}
const VIDRO = {"gin": Color(0.75, 0.9, 1.0), "rum": Color(0.65, 0.35, 0.12), "vodka": Color(0.85, 0.95, 1.0),
	"whisky": Color(0.75, 0.45, 0.15), "falsa": Color(0.25, 0.6, 0.2)}
const PENA_FALSA = 500
const BONUS_BARRIL = 40
const BARRIL_FUROS = 6
# px de back_new.png (a imagem 1024x1536 da 4.6)
const CARTAZ = [Vector2(797, 1022), Vector2(992, 1027), Vector2(1002, 1360), Vector2(800, 1335)]
const BARRIL = [Vector2(800, 995), Vector2(1024, 995), Vector2(1024, 1435), Vector2(810, 1425),
	Vector2(785, 1300), Vector2(776, 1160), Vector2(785, 1060)]
const VIDRACAS = [Rect2(90, 82, 48, 56), Rect2(144, 82, 46, 56), Rect2(211, 82, 47, 56), Rect2(264, 82, 46, 56),
	Rect2(90, 145, 48, 55), Rect2(144, 145, 46, 55), Rect2(211, 145, 47, 55), Rect2(264, 145, 46, 55)]
const CHAO_BAR = 1590.0
# o feixe de sol: contorno da parte acesa de bar_raios_sol.png (px da textura
# 256x384 da 4.6, que cobre o fundo 1024x1536) e pontos de poeira dentro dele
# (px do fundo 1024x1536)
const CONTORNO_FEIXE = [Vector2(18.3, 30.6), Vector2(31.6, 17.4), Vector2(79.5, 18.0), Vector2(84.6, 28.0), Vector2(135.9, 140.3), Vector2(230.5, 364.6), Vector2(234.5, 384.0), Vector2(163.8, 384.0), Vector2(21.0, 58.8), Vector2(18.1, 49.7)]
const PONTOS_POEIRA = [Vector2(400, 590), Vector2(656, 1139), Vector2(703, 1164), Vector2(438, 748), Vector2(348, 309), Vector2(619, 955), Vector2(134, 198), Vector2(558, 936), Vector2(553, 951), Vector2(513, 1024), Vector2(468, 966), Vector2(340, 603), Vector2(191, 218), Vector2(377, 571), Vector2(438, 701), Vector2(397, 569), Vector2(595, 896), Vector2(352, 406), Vector2(597, 1059), Vector2(640, 1099), Vector2(616, 1177), Vector2(667, 1136), Vector2(350, 474), Vector2(217, 436), Vector2(290, 501), Vector2(467, 566), Vector2(417, 624), Vector2(514, 741), Vector2(650, 1067), Vector2(365, 423), Vector2(110, 138), Vector2(667, 1167), Vector2(367, 699), Vector2(492, 737), Vector2(439, 821), Vector2(460, 590), Vector2(287, 390), Vector2(315, 638), Vector2(248, 419), Vector2(553, 995), Vector2(415, 843), Vector2(396, 347), Vector2(294, 305), Vector2(423, 395), Vector2(610, 920), Vector2(298, 204), Vector2(424, 844), Vector2(264, 275), Vector2(229, 368), Vector2(592, 1009), Vector2(221, 145), Vector2(347, 511), Vector2(502, 947), Vector2(609, 1176), Vector2(597, 1036), Vector2(303, 252), Vector2(449, 936), Vector2(439, 740), Vector2(446, 787), Vector2(198, 363), Vector2(427, 591), Vector2(330, 614), Vector2(402, 675), Vector2(281, 271), Vector2(619, 917), Vector2(209, 286), Vector2(639, 960), Vector2(464, 628), Vector2(341, 636), Vector2(526, 802), Vector2(359, 734), Vector2(297, 295), Vector2(519, 618), Vector2(498, 813), Vector2(338, 472), Vector2(350, 623), Vector2(179, 341), Vector2(317, 126), Vector2(397, 438), Vector2(620, 976)]


class Garrafa:
	var no: Node2D
	var spr: Sprite
	var sombra: Sprite
	var tipo = "gin"           # gin, rum, vodka, whisky, falsa
	var prateleira = 20
	var x = 0.0
	var pontos = 20
	var idade = 0.0
	var vida = 4.0
	var saindo = false
	var f: Dictionary


var garrafas = []
var _slots = {}
var spawn_t = 0.4
var troca_t = 2.5
var erros_seguidos = 0
var nivel = 0
var _f = {}
var _barril_furos = 0
var _vinho: Node2D
var _jatos = []
var _poca = 0.0
var _feixe_a: Polygon2D
var _feixe_b: Polygon2D
var _poeira_sol: Particulas
var _vidracas = []
var _furos: Node2D
var _t = 0.0
var _sol_forca = 1.0

var _som_vidro: AudioStream
var _som_falsa: AudioStream
var _som_pousa: AudioStream
var _som_vinho: AudioStream
var _som_janela: AudioStream
var _som_madeira: AudioStream
var _som_papel: AudioStream


func _configurar() -> void:
	id_fase = "bar"
	cenario_ranking = "BAR"
	cor = Estilo.CORES["bar"]
	estilo_tiro = "bar"
	forca_coice = 1.2
	musica_path = "res://songs/song-oldwest.mp3"
	som_tiro_path = "res://songs/tiro-de-pistola.wav"
	vol_tiro = -2.0
	janela_combo = JANELA
	tempo_recarga = 1.10
	centro_contagem = 1100.0


func _icones() -> Dictionary:
	return {"gin": quadro(_f["gin"], 0), "rum": quadro(_f["rum"], 0), "vodka": quadro(_f["vodka"], 0),
		"whisky": quadro(_f["whisky"], 0), "falsa": quadro(_f["falsa"], 0)}


# ------------------------------------------------------------ cenário
func _montar_cenario() -> void:
	for n in ["gin", "rum", "vodka", "whisky", "falsa"]:
		_f[n] = folha("garrafa_" + n)
	_som_vidro = load("res://songs/smash.wav")
	_som_falsa = load("res://songs/fail.wav")
	_som_pousa = load("res://songs/garrafa_pousa.wav")
	_som_vinho = load("res://songs/vinho_jorra.wav")
	_som_janela = load("res://songs/janela_quebra.wav")
	_som_madeira = load("res://songs/madeira_tiro.wav")
	_som_papel = load("res://songs/papel_tiro.wav")
	fundo_sprite("fundo_bar")
	_furos = Node2D.new()
	cenario.add_child(_furos)
	# vinho do barril (jato, fio escorrendo e a poça)
	_vinho = Node2D.new()
	_vinho.connect("draw", self, "_desenhar_vinho")
	cenario.add_child(_vinho)
	# vidraças da janela (o estado de cada uma)
	for r in VIDRACAS:
		var a = tela(r.position)
		var b = tela(r.end)
		_vidracas.append({"rect": Rect2(a, b - a), "quebrada": false, "luz": null})
	# o sol pela janela: o feixe com listras de poeira (duas imagens somadas,
	# o peso troca devagar e as listras andam) e a poeira brilhando
	_feixe_a = _feixe("bar_raios_a")
	_feixe_b = _feixe("bar_raios_b")
	_poeira_sol = Particulas.new()
	_poeira_sol.somar = true
	_poeira_sol.add_to_group("efeito_opcional")
	cenario.add_child(_poeira_sol)


func _feixe(nome: String) -> Polygon2D:
	var f = Polygon2D.new()
	f.texture = Estilo.tex(nome)
	f.material = Estilo.material_soma()
	var tam_tex: Vector2 = f.texture.get_size()
	var pontos = PoolVector2Array()
	var uv = PoolVector2Array()
	for q in CONTORNO_FEIXE:
		pontos.append(tela(q * 4.0))
		uv.append(q * tam_tex / Vector2(256, 384))
	f.polygon = pontos
	f.uv = uv
	f.modulate.a = 0.0
	cenario.add_child(f)
	return f


# ------------------------------------------------------------ partida
func _comecar() -> void:
	spawn_t = 0.1
	troca_t = 2.5
	for i in 6:
		_spawnar()


func _extra_placar() -> Array:
	var c = Color(0.80, 0.80, 0.80)
	if combo >= 5:
		c = Color(1.0, 0.35, 0.9)
	elif combo >= 3:
		c = Color(1.0, 0.75, 0.2)
	elif combo >= 2:
		c = Color(0.5, 1.0, 0.55)
	return ["COMBO", "x%d" % combo if combo >= 2 else "-", c]


func _jogo(delta: float) -> void:
	nivel = int(floor(max(pontos, 0) / 3000.0))
	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = rand_range(0.35, 0.95)
		for k in 3:
			if _spawnar():
				break
	troca_t -= delta
	if troca_t <= 0.0:
		var de = 2.0
		var ate = 3.2
		if pontos >= 14000:
			de = 0.65
			ate = 1.2
		elif pontos >= 7000:
			de = 0.85
			ate = 1.55
		elif pontos >= 3000:
			de = 1.15
			ate = 2.0
		troca_t = rand_range(de, ate)
		var trocas = 1
		if pontos >= 9000:
			trocas = 3
		elif pontos >= 3000:
			trocas = 2
		for k in trocas:
			_forcar_troca()
	_tick_garrafas(delta)


func _max_garrafas() -> int:
	return int(clamp(13 + nivel, 13, 22))


func _spawnar() -> bool:
	var vivas = 0
	for g in garrafas:
		if not g.saindo:
			vivas += 1
	if vivas >= _max_garrafas():
		return false
	var opcoes = []
	for pts in X_COLUNAS.keys():
		for x in X_COLUNAS[pts]:
			opcoes.append([pts, x])
	opcoes.shuffle()
	for op in opcoes:
		var chave = "%d|%d" % [op[0], int(op[1])]
		if _slots.has(chave):
			continue
		_criar_garrafa(op[0], op[1], NOMES[op[0]])
		return true
	return false


func _criar_garrafa(prat: int, x: float, tipo: String) -> Garrafa:
	var g = Garrafa.new()
	g.tipo = tipo
	g.prateleira = prat
	g.x = x
	g.pontos = prat if tipo != "falsa" else 0
	g.f = _f[tipo]
	g.no = Node2D.new()
	g.no.position = Vector2(x, Y_PRATELEIRA[prat] + PE)
	alvos.add_child(g.no)
	# sombra no fundo da prateleira
	g.sombra = Sprite.new()
	g.sombra.texture = Estilo.tex("fx_brilho")
	g.sombra.modulate = Color(0, 0, 0, 0.45)
	g.sombra.scale = Vector2(0.9, 0.22)
	g.no.add_child(g.sombra)
	g.spr = Sprite.new()
	g.spr.texture = g.f["tex"]
	g.spr.hframes = g.f["quadros"]
	g.spr.frame = 0
	g.spr.centered = false
	var cel: Vector2 = g.f["cel"]
	g.spr.offset = Vector2(-cel.x * 0.5, -cel.y)
	var esc: float = (ESCALA_FALSA if tipo == "falsa" else ESCALA_GARRAFA)[prat]
	g.spr.scale = Vector2.ONE * esc
	g.no.add_child(g.spr)
	g.vida = _vida(g)
	_slots["%d|%d" % [prat, int(x)]] = g
	garrafas.append(g)
	# cai do alto na tábua e assenta (um quique de leve)
	g.spr.position = Vector2(0, -70)
	g.spr.modulate.a = 0.0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(g.spr, "position", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(g.spr, "modulate:a", 1.0, 0.1)
	if randf() < 0.5:
		Maquina.efeito(_som_pousa, -12.0, rand_range(0.9, 1.15))
	return g


func _vida(g: Garrafa) -> float:
	var red: float = min(1.80, nivel * 0.22)
	if g.tipo == "falsa":
		return rand_range(2.8, 3.8)
	match g.prateleira:
		100:
			return rand_range(max(1.65, 2.80 - red), max(2.25, 3.70 - red))
		80:
			return rand_range(max(2.25, 3.70 - red), max(3.00, 4.80 - red))
		50:
			return rand_range(max(3.20, 4.80 - red), max(4.10, 6.10 - red))
		_:
			return rand_range(max(4.40, 6.40 - red), max(5.60, 8.00 - red))


func _chance_falsa(prat: int) -> float:
	var tabela = {100: [0.52, 0.68, 0.88, 0.96], 80: [0.44, 0.58, 0.80, 0.90], 50: [0.34, 0.46, 0.68, 0.78], 20: [0.24, 0.34, 0.52, 0.62]}
	var i = 0
	if pontos >= 7000:
		i = 3
	elif pontos >= 3000:
		i = 2
	elif pontos >= 1500:
		i = 1
	return tabela[prat][i]


func _tick_garrafas(delta: float) -> void:
	for g in garrafas.duplicate():
		if g.saindo:
			continue
		g.idade += delta
		if g.idade >= g.vida:
			if g.tipo == "falsa":
				_retirar(g)
			elif randf() <= _chance_falsa(g.prateleira):
				_virar_falsa(g)
			else:
				_retirar(g)


func _retirar(g: Garrafa) -> void:
	g.saindo = true
	_slots.erase("%d|%d" % [g.prateleira, int(g.x)])
	garrafas.erase(g)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(g.spr, "position", Vector2(0, -26), 0.26)
	tw.tween_property(g.no, "modulate:a", 0.0, 0.26)
	tw.chain().tween_callback(g.no, "queue_free")


## A garrafa vira a verde de caveira no mesmo lugar (um estalo).
func _virar_falsa(g: Garrafa) -> void:
	var prat = g.prateleira
	var x = g.x
	g.saindo = true
	garrafas.erase(g)
	g.no.queue_free()
	_slots.erase("%d|%d" % [prat, int(x)])
	var nova = _criar_garrafa(prat, x, "falsa")
	nova.spr.position = Vector2.ZERO
	nova.spr.modulate.a = 1.0
	nova.spr.scale *= 1.12
	var esc: float = ESCALA_FALSA[prat]
	var tw = create_tween()
	tw.tween_property(nova.spr, "scale", Vector2.ONE * esc, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	particulas.explosao(nova.no.position + Vector2(0, -60), {"n": 4, "tex": Estilo.tex("fx_nuvem"), "vel": [10.0, 40.0], "vida": [0.5, 0.9],
		"tam": [30.0, 50.0], "fim": 1.6, "cor": Color(0.4, 0.85, 0.3, 0.45)})


## De tempos em tempos uma garrafa boa (das mais valiosas) troca: sai ou vira
## a verde, garantindo um mínimo de verdes na estante.
func _forcar_troca() -> void:
	var normais = []
	var falsas = 0
	for g in garrafas:
		if g.saindo:
			continue
		if g.tipo == "falsa":
			falsas += 1
		else:
			normais.append(g)
	var minimo = 1
	if pontos >= 14000:
		minimo = 4
	elif pontos >= 7000:
		minimo = 3
	elif pontos >= 3000:
		minimo = 2
	var precisa = falsas < minimo
	normais.shuffle()
	for g in normais:
		var idade_min: float = {100: 1.20, 80: 1.55, 50: 2.15, 20: 3.20}[g.prateleira]
		if precisa:
			idade_min *= 0.72
		if g.idade < idade_min:
			continue
		if precisa:
			_virar_falsa(g)
			return
		var chance = _chance_falsa(g.prateleira) + (0.10 if g.prateleira >= 80 else 0.0)
		if randf() <= min(chance, 0.98):
			_virar_falsa(g)
		else:
			_retirar(g)
		return


# ------------------------------------------------------------ tiro
func _garrafa_no_ponto(p: Vector2) -> Garrafa:
	for i in range(garrafas.size() - 1, -1, -1):
		var g: Garrafa = garrafas[i]
		if g.saindo:
			continue
		# a máscara é do quadro inteiro; o sprite tem o pé na origem
		var local = g.spr.get_global_transform().affine_inverse().xform(p)
		var cel: Vector2 = g.f["cel"]
		var u = (local.x - g.spr.offset.x) / cel.x
		var v = (local.y - g.spr.offset.y) / cel.y
		if u < -0.08 or u > 1.08 or v < -0.04 or v > 1.04:
			continue
		var m: Array = g.f["mascara"]
		var n = m.size()
		var cx = int(clamp(u * n, 0, n - 1))
		var cy = int(clamp(v * n, 0, n - 1))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var xx = cx + dx
				var yy = cy + dy
				if xx >= 0 and yy >= 0 and xx < n and yy < n and m[yy][xx] == "1":
					return g
	return null


func _tiro(p: Vector2) -> void:
	var g = _garrafa_no_ponto(p)
	if g != null:
		_acertar(g, p)
		return
	var q = imagem(p)
	var em_cartaz = Geometry.is_point_in_polygon(q, PoolVector2Array(CARTAZ))
	var no_barril = em_cartaz or Geometry.is_point_in_polygon(q, PoolVector2Array(BARRIL))
	if no_barril and _barril_furos < BARRIL_FUROS:
		_tiro_no_barril(p, em_cartaz)
		return
	erros_seguidos += 1
	errar(p, "ERROU!")
	for v in _vidracas:
		if v["rect"].has_point(p):
			_quebrar_vidraca(v, p)
			return
	_lascar(p, "papel" if em_cartaz else "madeira")


func _acertar(g: Garrafa, p: Vector2) -> void:
	g.saindo = true
	garrafas.erase(g)
	_slots.erase("%d|%d" % [g.prateleira, int(g.x)])
	if g.tipo == "falsa":
		erros_seguidos += 1
		var perda = PENA_FALSA + 20 * erros_seguidos
		acertos += 0
		perder(perda, g.no.position + Vector2(0, -90), "GARRAFA IMPOSTORA")
		Maquina.efeito(_som_falsa, -1.0)
		clarao(Color(0.9, 0.1, 0.05, 0.22), 0.3)
		tremer(8.0, 0.25)
		particulas.explosao(g.no.position + Vector2(0, -70), {"n": 6, "tex": Estilo.tex("fx_fumaca"), "vel": [30.0, 110.0], "ang": [200.0, 340.0],
			"vida": [0.9, 1.5], "tam": [50.0, 80.0], "fim": 2.0, "cor": Color(0.3, 0.75, 0.25, 0.6), "grav": -40.0})
		var tw = create_tween()
		for q in g.f["acerto"]:
			tw.tween_callback(g.spr, "set_frame", [q])
			tw.tween_interval(1.0 / 16.0)
		tw.tween_property(g.no, "modulate:a", 0.0, 0.2)
		tw.tween_callback(g.no, "queue_free")
		return
	erros_seguidos = 0
	registrar_combo()
	ganhar(g.pontos, g.no.position + Vector2(0, -150 * g.spr.scale.y * 2.0), OURO, 1.0 + (g.pontos - 20) / 400.0)
	Maquina.efeito(_som_vidro, -1.0, rand_range(0.94, 1.08))
	_estourar(g, p)


## A garrafa estoura: cacos da própria imagem caem na prateleira e quicam, a
## bebida espirra no ar na cor dela e pinga na prateleira de baixo.
func _estourar(g: Garrafa, p: Vector2) -> void:
	var cel: Vector2 = g.f["cel"]
	var xf = g.no.get_transform() * g.spr.get_transform() * Transform2D(0.0, g.spr.offset + cel * 0.5)
	var prat_y: float = Y_PRATELEIRA[g.prateleira] + PE - 2.0
	cacos.estourar(g.f["tex"], Rect2(Vector2.ZERO, cel), xf, p, {"n": 14, "forca": 1.0, "grav": 1700.0, "chao": prat_y, "vida": 1.4, "sobe": 240.0})
	var liq: Color = LIQUIDO[g.tipo]
	particulas.explosao(p, {"n": 22, "tex": Estilo.tex("fx_ponto"), "vel": [120.0, 460.0], "vida": [0.5, 1.0], "tam": [8.0, 18.0], "fim": 0.6,
		"cor": liq, "grav": 1300.0, "chao": prat_y, "arrasto": 0.6})
	particulas.explosao(p, {"n": 3, "tex": Estilo.tex("fx_nuvem"), "vel": [20.0, 80.0], "vida": [0.4, 0.7], "tam": [60.0, 90.0], "fim": 1.5,
		"cor": Color(liq.r, liq.g, liq.b, 0.35)})
	particulas_luz.explosao(p, {"n": 12, "vel": [150.0, 420.0], "vida": [0.25, 0.5], "tam": [6.0, 12.0], "cor": Color(1.0, 0.95, 0.85),
		"grav": 500.0, "estica": 0.03})
	luz_sprite_breve(p, 220.0, Color(1.0, 0.92, 0.75, 0.75), 0.25)
	# pingos escorrendo para a prateleira de baixo
	var baixo = prat_y + 260.0
	for prat in [80, 50, 20]:
		if Y_PRATELEIRA[prat] > Y_PRATELEIRA[g.prateleira]:
			baixo = Y_PRATELEIRA[prat] + PE
			break
	particulas.explosao(Vector2(g.x, prat_y + 4.0), {"n": 5, "tex": Estilo.tex("fx_ponto"), "vel": [0.0, 30.0], "ang": [80.0, 100.0],
		"vida": [1.0, 1.6], "tam": [6.0, 9.0], "fim": 0.8, "cor": liq, "grav": 900.0, "chao": baixo, "espalha": 30.0})
	g.no.queue_free()


func _tiro_no_barril(p: Vector2, cartaz: bool) -> void:
	_barril_furos += 1
	_lascar(p, "papel" if cartaz else "madeira")
	bonus(BONUS_BARRIL, p, Color(1.0, 0.45, 0.52), 1.1)
	_jatos.append({"p": p, "t": 0.0, "lado": -1.0 if p.x < tela(Vector2(900, 0)).x else 0.0})
	Maquina.efeito(_som_vinho, -4.0, rand_range(0.95, 1.05))
	if _barril_furos == 1:
		avisos.instrucao("VINHO VAZANDO! +%d POR FURO" % BONUS_BARRIL, Color(1.0, 0.72, 0.76))
	elif _barril_furos == BARRIL_FUROS:
		avisos.instrucao("BARRIL ESGOTADO", Color(1.0, 0.72, 0.76))


func _quebrar_vidraca(v: Dictionary, p: Vector2) -> void:
	Maquina.efeito(_som_janela, -3.0, rand_range(0.95, 1.05))
	var r: Rect2 = v["rect"]
	if v["quebrada"]:
		particulas.explosao(p, {"n": 5, "tex": Estilo.tex("fx_caco"), "vel": [60.0, 160.0], "ang": [60.0, 120.0], "vida": [0.6, 1.0],
			"tam": [6.0, 12.0], "cor": Color(0.85, 0.95, 1.0, 0.8), "grav": 1200.0, "chao": tela(Vector2(0, 279)).y, "giro": [-12.0, 12.0]})
		return
	v["quebrada"] = true
	# o vidro se parte em cacos da própria pintura da janela
	var esc = Tela.TELA.x / 1080.0
	var px = r.position / esc
	var tam = r.size / esc
	cacos.estourar(Estilo.tex("fundo_bar"), Rect2(px, tam), Transform2D(Vector2(esc, 0), Vector2(0, esc), r.position + r.size * 0.5), p,
		{"n": 10, "forca": 0.8, "grav": 1400.0, "chao": tela(Vector2(0, 279)).y, "vida": 1.6, "sobe": 120.0, "cor": Color(1, 1, 1, 0.95)})
	particulas_luz.explosao(p, {"n": 12, "vel": [80.0, 260.0], "vida": [0.3, 0.6], "tam": [6.0, 12.0], "cor": Color(1.0, 0.95, 0.8)})
	# o buraco: a luz de fora entra mais forte
	var luz_buraco = Sprite.new()
	luz_buraco.texture = Estilo.tex("fx_brilho")
	luz_buraco.material = Estilo.material_soma()
	luz_buraco.position = r.position + r.size * 0.5
	luz_buraco.scale = r.size / 70.0
	luz_buraco.modulate = Color(1.0, 0.9, 0.65, 0.85)
	cenario.add_child(luz_buraco)
	v["luz"] = luz_buraco
	_sol_forca = min(2.2, _sol_forca + 0.15)


func _lascar(p: Vector2, material: String) -> void:
	_furo(p, "bar_furo_papel" if material == "papel" else "bar_furo_madeira")
	if material == "papel":
		particulas.explosao(p, {"n": 7, "tex": Estilo.tex("fx_caco"), "vel": [60.0, 180.0], "vida": [0.9, 1.6], "tam": [10.0, 18.0],
			"cor": Color(0.92, 0.85, 0.66), "grav": 260.0, "giro": [-6.0, 6.0], "arrasto": 2.0})
		Maquina.efeito(_som_papel, -5.0, rand_range(0.9, 1.1))
	else:
		particulas.explosao(p, {"n": 9, "tex": Estilo.tex("mar_farpa"), "vel": [140.0, 340.0], "vida": [0.5, 0.9], "tam": [18.0, 30.0],
			"cor": Color(0.62, 0.40, 0.20), "grav": 1200.0, "giro": [-16.0, 16.0]})
		particulas.explosao(p, {"n": 2, "tex": Estilo.tex("fx_nuvem"), "vel": [10.0, 30.0], "vida": [0.5, 0.9], "tam": [28.0, 40.0], "fim": 1.6,
			"cor": Color(0.55, 0.40, 0.25, 0.45)})
		Maquina.efeito(_som_madeira, -5.0, rand_range(0.9, 1.1))


func _furo(p: Vector2, tex: String) -> void:
	var s = Sprite.new()
	s.texture = Estilo.tex(tex)
	s.position = p
	s.scale = Vector2.ONE * rand_range(0.42, 0.55)
	s.rotation = randf() * TAU
	_furos.add_child(s)
	if _furos.get_child_count() > 24:
		_furos.get_child(0).queue_free()


func _encerrou() -> void:
	for g in garrafas:
		var tw = create_tween()
		tw.tween_property(g.no, "modulate:a", 0.0, 0.4)
		tw.tween_callback(g.no, "queue_free")
	garrafas.clear()
	_slots.clear()


# ------------------------------------------------------------ vida do bar
func _sempre(delta: float) -> void:
	_t += delta
	var e = Maquina.pulso_vivo()
	# o sol respira como se nuvens passassem lá fora; as listras andam
	var nuvem = 0.86 + 0.14 * sin(_t * 0.21) * sin(_t * 0.137 + 1.3)
	var forca_sol = 0.5 * nuvem * _sol_forca
	var w = 0.5 + 0.5 * sin(_t * 0.55)
	_feixe_a.modulate.a = forca_sol * w
	_feixe_b.modulate.a = forca_sol * (1.0 - w)
	# poeira brilhando dentro do feixe
	if randf() < delta * 7.0 * Maquina.fator_efeitos():
		var q: Vector2 = PONTOS_POEIRA[randi() % PONTOS_POEIRA.size()]
		var p = tela(q) + Vector2(rand_range(-12, 12), rand_range(-12, 12))
		_poeira_sol.soltar(p, Vector2(rand_range(-4, 8), rand_range(-2, 9)), rand_range(3.0, 5.0), rand_range(4.0, 7.0), 2.0,
			Color(1.0, 0.9, 0.6, 0.6), Color(1.0, 0.9, 0.6, 0.0), Estilo.tex("fx_ponto"))
	for v in _vidracas:
		if v["luz"] != null:
			v["luz"].modulate.a = 0.6 + 0.25 * sin(_t * 1.3)
	if not _jatos.empty():
		for j in _jatos:
			j["t"] += delta
		_poca = min(1.0, _poca + delta * 0.05 * _jatos.size())
		_vinho.update()


## O vinho do barril: jato forte logo depois do tiro, que vira um fio
## escorrendo até o pé do barril; a poça no chão cresce.
func _desenhar_vinho() -> void:
	var cor_v = Color(0.42, 0.02, 0.08, 0.95)
	var pe = tela(Vector2(900, 1424)).y
	if _poca > 0.0:
		var c = Vector2(tela(Vector2(880, 0)).x, pe + 14.0)
		_vinho.draw_set_transform(c, 0.0, Vector2(1.0, 0.22))
		_vinho.draw_circle(Vector2.ZERO, 40.0 + 150.0 * _poca, Color(0.25, 0.01, 0.04, 0.85))
		_vinho.draw_circle(Vector2(-20, -10), 20.0 + 70.0 * _poca, Color(0.55, 0.12, 0.16, 0.35))
		_vinho.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for j in _jatos:
		var p: Vector2 = j["p"]
		var t: float = j["t"]
		var pressao = exp(-t / 1.0)
		if t < 13.0:
			# o fio pela madeira até o pé do barril
			var larg: float = lerp(2.0, 7.0, pressao)
			_vinho.draw_line(p, Vector2(p.x + 4.0, pe), Color(0.30, 0.02, 0.05, 0.85 * clamp((13.0 - t) / 3.0, 0.0, 1.0)), larg)
		if pressao > 0.15:
			# o jato em arco para a frente
			var pts = PoolVector2Array()
			var v0 = Vector2(-260.0 * pressao + j["lado"] * 80.0, -40.0 * pressao)
			for i in 12:
				var s = float(i) / 11.0 * 0.6
				pts.append(p + v0 * s + Vector2(0, 0.5 * 1400.0 * s * s))
			_vinho.draw_polyline(pts, cor_v, 6.0 * pressao + 2.0)


## Teste automático (robô): a garrafa boa mais valiosa perto da mira.
func robo_alvo():
	var melhor = null
	var md = 1.0e9
	for g in garrafas:
		if g.saindo or g.tipo == "falsa":
			continue
		var p: Vector2 = g.no.position + Vector2(0, -90)
		var d = p.distance_to(MiraGlobal.pos) - g.pontos * 3.0
		if d < md:
			md = d
			melhor = p
	return melhor
