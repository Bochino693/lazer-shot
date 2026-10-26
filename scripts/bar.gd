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
## bônus (+40 por furo, até 6) e o vinho jorra pelo furo; a JANELA tem
## desenho próprio (scripts/bar_janela.gd): cada tiro estoura o vidro de
## verdade (trincas, cacos caindo, pontas presas na moldura) e o sol entra
## mais forte. Os 5 primeiros tiros na janela valem +50 cada; no 5º o que
## sobrou do vidro desaba e a janela não dá mais pontos. O sol pela janela é
## um feixe que respira, com poeira brilhando dentro.
##
## PROFUNDIDADE (sem 3D, barato para a Mali-450): cada garrafa pisa no tampo
## da tábua dela; nas duas tábuas de cima (na altura do olho, só se vê a
## frente delas) a beirada é desenhada de novo por cima do pé, então a
## garrafa fica atrás dela. A luz vem da janela: sombra macia na parede (para
## a direita e para baixo), sombra de contato no tampo das tábuas de baixo,
## contraluz quente nas garrafas dentro do feixe de sol (que passa na frente
## delas, com a poeira) e reflexos no vidro. Tiro balança as vizinhas.

const JANELA = 2.2
const X_COLUNAS = {
	100: [190.0, 315.0, 440.0, 565.0, 690.0],
	80: [190.0, 355.0, 520.0, 685.0],
	50: [190.0, 355.0, 520.0, 685.0],
	20: [110.0, 220.0, 330.0, 440.0, 550.0, 660.0],
}
# A ESTANTE na tela, medida no fundo_bar: onde o pé da garrafa pisa. Nas duas
# de baixo o tampo aparece (1128-1158 e 1390-1449) e o pé fica no meio dele;
# nas duas de cima só se vê a frente da tábua e o pé fica atrás da beirada.
const PE_PRATELEIRA = {100: 589.0, 80: 853.0, 50: 1146.0, 20: 1424.0}
# a frente das duas tábuas de cima (topo e base na tela), por cima do pé
const BEIRADAS = [Vector2(583.0, 621.0), Vector2(847.0, 890.0)]
# a base da frente de cada tábua (de onde a bebida pinga)
const BASE_TABUA = {100: 621.0, 80: 890.0, 50: 1202.0, 20: 1480.0}
const ESCALA_GARRAFA = {100: 0.50, 80: 0.56, 50: 0.62, 20: 0.58}
const ESCALA_FALSA = {100: 0.81, 80: 0.85, 50: 0.96, 20: 1.00}
# px vazios embaixo do desenho (a garrafa verde parada tem 28; no estouro, 7):
# descontados, toda garrafa pisa na tábua em vez de flutuar acima dela
const VAZIO_EMBAIXO = {"falsa": 28.0}
const VAZIO_ESTOURO_FALSA = 7.0
# a sombra de cada garrafa (tools/preparar_mali.py, sombras_bar): o contorno
# em 1/4 com 6 px de folga, desfocado
const SOMBRA_RED = 4.0
const SOMBRA_FOLGA = 6.0
# a luz da janela joga a sombra na parede para a direita e para baixo (px)
const SOMBRA_PAREDE = Vector2(19.0, 10.0)
const COR_SOMBRA = Color(0.06, 0.02, 0.0, 0.62)
const COR_CONTRALUZ = Color(1.0, 0.72, 0.36)
const NOMES = {100: "whisky", 80: "vodka", 50: "rum", 20: "gin"}
const LIQUIDO = {"gin": Color(0.85, 0.95, 1.0, 0.85), "rum": Color(0.78, 0.40, 0.10, 0.9), "vodka": Color(0.9, 0.97, 1.0, 0.85),
	"whisky": Color(0.80, 0.50, 0.12, 0.9), "falsa": Color(0.35, 0.85, 0.25, 0.9)}
const VIDRO = {"gin": Color(0.75, 0.9, 1.0), "rum": Color(0.65, 0.35, 0.12), "vodka": Color(0.85, 0.95, 1.0),
	"whisky": Color(0.75, 0.45, 0.15), "falsa": Color(0.25, 0.6, 0.2)}
const PENA_FALSA = 500
const BONUS_BARRIL = 40
const BARRIL_FUROS = 6
const BONUS_JANELA = 50
const JANELA_TIROS = 5          # só os 5 primeiros tiros na janela valem pontos
const JanelaBar = preload("res://scripts/bar_janela.gd")
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
	var no: Node2D             # no pé da garrafa (gira em volta dele no balanço)
	var spr: Sprite
	var sombra: Sprite         # de contato, no tampo (só nas tábuas de baixo)
	var parede: Sprite         # na parede, pela luz da janela
	var contraluz: Sprite      # o sol atravessando o vidro (só dentro do feixe)
	var luz = 0.0              # quanto do feixe de sol pega nela (0 a 1)
	var balanco = 0.0          # força do balanço (rad)
	var balanco_t = 0.0
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
var _vago_ate = {}      # o lugar da garrafa estourada fica vazio um pouco
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
var _janela: Node2D             # JanelaBar
var _janela_pagos = 0
var _furos: Node2D              # na parede (atrás das garrafas)
var _frente: Node2D             # por cima das garrafas: beiradas, sol e poeira
var _furos_frente: Node2D       # furos na frente das tábuas de cima
var _manchas: Node2D            # bebida espirrada na parede e no tampo
var _poli_feixe = PoolVector2Array()
var _poli_cartaz = PoolVector2Array()
var _poli_barril = PoolVector2Array()
var _t = 0.0
var _sol_forca = 1.0
var _forca_sol = 0.5
var _n_furo = 0

var _som_vidro: AudioStream
var _som_falsa: AudioStream
var _som_pousa: AudioStream
var _som_vinho: AudioStream
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
	_som_madeira = load("res://songs/madeira_tiro.wav")
	_som_papel = load("res://songs/papel_tiro.wav")
	fundo_sprite("fundo_bar")
	_poli_cartaz = poligono(CARTAZ)
	_poli_barril = poligono(BARRIL)
	_furos = Node2D.new()
	cenario.add_child(_furos)
	_manchas = Node2D.new()
	cenario.add_child(_manchas)
	# vinho do barril (jato, fio escorrendo e a poça)
	_vinho = Node2D.new()
	_vinho.connect("draw", self, "_desenhar_vinho")
	cenario.add_child(_vinho)
	# a janela: as vidraças levam tiro (antes do sol: o feixe soma por cima
	# dos buracos)
	var vidracas = []
	for r in VIDRACAS:
		var a = tela(r.position)
		var b = tela(r.end)
		vidracas.append(Rect2(a, b - a))
	_janela = JanelaBar.new()
	cenario.add_child(_janela)
	_janela.configurar(vidracas, Estilo.tex("fundo_bar"), Tela.TELA.x / 1080.0, K_FUNDO, tela(Vector2(0, 279)).y,
		Vector3(tela(Vector2(58, 0)).x, tela(Vector2(338, 0)).x, tela(Vector2(0, 205)).y))
	_montar_frente()
	# o sol pela janela: o feixe com listras de poeira (duas imagens somadas,
	# o peso troca devagar e as listras andam) e a poeira brilhando. Ficam na
	# frente das garrafas: a luz passa no ar entre elas e quem olha.
	for q in CONTORNO_FEIXE:
		_poli_feixe.append(tela(q * 4.0))
	_feixe_a = _feixe("bar_raios_a")
	_feixe_b = _feixe("bar_raios_b")
	_poeira_sol = Particulas.new()
	_poeira_sol.somar = true
	_poeira_sol.add_to_group("efeito_opcional")
	_frente.add_child(_poeira_sol)


## A frente das duas tábuas de cima de novo, por cima do pé das garrafas (o
## mesmo pedaço do fundo, no mesmo lugar): a garrafa fica EM CIMA da tábua,
## atrás da beirada. Os furos de bala nessa frente ficam por cima também.
func _montar_frente() -> void:
	_frente = Node2D.new()
	_frente.name = "FrenteDasTabuas"
	mundo.add_child_below_node(alvos, _frente)
	var fundo: Texture = Estilo.tex("fundo_bar")
	var k = Tela.TELA.x / fundo.get_width()
	for b in BEIRADAS:
		var y0 = floor(b.x / k)
		var y1 = ceil(b.y / k)
		var s = Sprite.new()
		s.texture = fundo
		s.centered = false
		s.region_enabled = true
		s.region_filter_clip = true
		s.region_rect = Rect2(0, y0, fundo.get_width(), y1 - y0)
		s.position = Vector2(0, y0 * k)
		s.scale = Vector2(k, k)
		_frente.add_child(s)
	_furos_frente = Node2D.new()
	_frente.add_child(_furos_frente)


func _feixe(nome: String) -> Polygon2D:
	var f = Polygon2D.new()
	f.texture = Estilo.tex(nome)
	f.material = Estilo.material_soma()
	var tam_tex: Vector2 = f.texture.get_size()
	var uv = PoolVector2Array()
	for q in CONTORNO_FEIXE:
		uv.append(q * tam_tex / Vector2(256, 384))
	f.polygon = _poli_feixe
	f.uv = uv
	f.modulate.a = 0.0
	_frente.add_child(f)
	return f


## Quanto do feixe de sol pega numa garrafa (0 a 1), pelo meio dela.
func _luz_do_feixe(x: float, y: float) -> float:
	var dentro = 0
	for dx in [-36.0, -18.0, 0.0, 18.0, 36.0]:
		if Geometry.is_point_in_polygon(Vector2(x + dx, y), _poli_feixe):
			dentro += 1
	return dentro / 5.0


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
		if _slots.has(chave) or _vago_ate.get(chave, 0.0) > _t:
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
	g.no.position = Vector2(x, PE_PRATELEIRA[prat])
	alvos.add_child(g.no)
	var cel: Vector2 = g.f["cel"]
	var esc: float = (ESCALA_FALSA if tipo == "falsa" else ESCALA_GARRAFA)[prat]
	if prat <= 50:
		# sombra de contato no tampo (a luz vem da esquerda: um pouco à direita)
		g.sombra = Sprite.new()
		g.sombra.texture = Estilo.tex("fx_brilho")
		g.sombra.modulate = Color(0.05, 0.02, 0.0, 0.0)
		g.sombra.position = Vector2(5.0, 1.0)
		g.sombra.scale = Vector2(cel.x * esc * 1.5 / 128.0, 0.2)
		g.no.add_child(g.sombra)
	g.spr = Sprite.new()
	g.spr.texture = g.f["tex"]
	g.spr.hframes = g.f["quadros"]
	g.spr.frame = 0
	g.spr.centered = false
	g.spr.offset = Vector2(-cel.x * 0.5, -cel.y + VAZIO_EMBAIXO.get(tipo, 0.0))
	g.spr.scale = Vector2.ONE * esc
	g.no.add_child(g.spr)
	# a sombra na parede e o contraluz do sol: o contorno macio da garrafa
	# atrás dela (filhos do desenho: caem e somem junto)
	g.parede = _contorno(g, COR_SOMBRA, false)
	g.parede.position = SOMBRA_PAREDE / esc
	g.luz = _luz_do_feixe(x, PE_PRATELEIRA[prat] - cel.y * esc * 0.45)
	if g.luz > 0.0:
		g.contraluz = _contorno(g, Color(COR_CONTRALUZ.r, COR_CONTRALUZ.g, COR_CONTRALUZ.b, 0.0), true)
	g.vida = _vida(g)
	_slots["%d|%d" % [prat, int(x)]] = g
	garrafas.append(g)
	# cai do alto na tábua e assenta (um quique de leve); a sombra do tampo
	# aparece quando ela chega
	g.spr.position = Vector2(0, -70)
	g.spr.modulate.a = 0.0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(g.spr, "position", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(g.spr, "modulate:a", 1.0, 0.1)
	if g.sombra != null:
		tw.tween_property(g.sombra, "modulate:a", 0.65, 0.22).set_delay(0.08)
	tw.chain().tween_callback(self, "_pousou", [g])
	if randf() < 0.5:
		Maquina.efeito(_som_pousa, -12.0, rand_range(0.9, 1.15))
	return g


## O contorno macio da garrafa (bar_sombra_*), atrás dela, no lugar do quadro
## parado: escuro é a sombra; somado (luz) é o contraluz.
func _contorno(g: Garrafa, c: Color, somar: bool) -> Sprite:
	var s = Sprite.new()
	s.texture = Estilo.tex("bar_sombra_" + g.tipo)
	s.centered = false
	s.show_behind_parent = true
	s.scale = Vector2.ONE * SOMBRA_RED
	s.offset = g.spr.offset / SOMBRA_RED - Vector2.ONE * SOMBRA_FOLGA
	s.modulate = c
	if somar:
		# um pouco maior que a garrafa, em volta do meio dela: a luz vaza
		# pelas bordas do vidro
		s.material = Estilo.material_soma()
		s.scale *= 1.06
		var meio = g.spr.offset + g.f["cel"] * 0.5
		s.position = meio * (1.0 - 1.06)
	g.spr.add_child(s)
	return s


## A garrafa assentou na tábua: balança um pouco.
func _pousou(g: Garrafa) -> void:
	if not g.saindo and abs(g.balanco) < 0.045:
		g.balanco = 0.045
		g.balanco_t = 0.0


## Tiro perto: as garrafas da mesma tábua balançam (mais forte quanto mais
## perto), girando no pé.
func _balancar(prat: int, x: float, forca: float) -> void:
	for g in garrafas:
		if g.saindo or g.prateleira != prat:
			continue
		var f = forca * (1.0 - abs(g.x - x) / 210.0)
		if f > abs(g.balanco):
			g.balanco = f if randf() < 0.5 else -f
			g.balanco_t = 0.0


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
	var em_cartaz = Geometry.is_point_in_polygon(p, _poli_cartaz)
	var no_barril = em_cartaz or Geometry.is_point_in_polygon(p, _poli_barril)
	if no_barril and _barril_furos < BARRIL_FUROS:
		_tiro_no_barril(p, em_cartaz)
		return
	var vidro = _janela.tiro(p)
	if vidro == JanelaBar.QUEBROU:
		_sol_forca = min(2.2, 1.0 + 0.15 * _janela.quebradas())
		if _janela_pagos < JANELA_TIROS:
			_tiro_na_janela(p)
			return
	erros_seguidos += 1
	errar(p, "ERROU!")
	if vidro == JanelaBar.FORA:
		_lascar(p, "papel" if em_cartaz else "madeira")


func _acertar(g: Garrafa, p: Vector2) -> void:
	g.saindo = true
	garrafas.erase(g)
	var chave = "%d|%d" % [g.prateleira, int(g.x)]
	_slots.erase(chave)
	_vago_ate[chave] = _t + 1.3
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
		g.spr.offset.y = -g.f["cel"].y + VAZIO_ESTOURO_FALSA
		g.parede.visible = false
		if g.contraluz != null:
			g.contraluz.visible = false
		if g.sombra != null:
			g.sombra.visible = false
		_balancar(g.prateleira, g.x, 0.07)
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
	var prat_y: float = PE_PRATELEIRA[g.prateleira] - 2.0
	cacos.estourar(g.f["tex"], Rect2(Vector2.ZERO, cel), xf, p, {"n": 10, "forca": 1.0, "grav": 1700.0, "chao": prat_y, "vida": 1.3, "sobe": 240.0})
	var liq: Color = LIQUIDO[g.tipo]
	particulas.explosao(p, {"n": 16, "tex": Estilo.tex("fx_ponto"), "vel": [120.0, 460.0], "vida": [0.5, 1.0], "tam": [8.0, 18.0], "fim": 0.6,
		"cor": liq, "grav": 1300.0, "chao": prat_y, "arrasto": 0.6})
	particulas.explosao(p, {"n": 3, "tex": Estilo.tex("fx_nuvem"), "vel": [20.0, 80.0], "vida": [0.4, 0.7], "tam": [60.0, 90.0], "fim": 1.5,
		"cor": Color(liq.r, liq.g, liq.b, 0.35)})
	particulas_luz.explosao(p, {"n": 9, "vel": [150.0, 420.0], "vida": [0.25, 0.5], "tam": [6.0, 12.0], "cor": Color(1.0, 0.95, 0.85),
		"grav": 500.0, "estica": 0.03})
	luz_sprite_breve(p, 220.0, Color(1.0, 0.92, 0.75, 0.75), 0.25)
	# pingos escorrendo da beirada da tábua para a de baixo (ou o chão)
	var baixo = CHAO_BAR
	for prat in [80, 50, 20]:
		if PE_PRATELEIRA[prat] > PE_PRATELEIRA[g.prateleira]:
			baixo = PE_PRATELEIRA[prat]
			break
	particulas.explosao(Vector2(g.x, BASE_TABUA[g.prateleira] + 2.0), {"n": 5, "tex": Estilo.tex("fx_ponto"), "vel": [0.0, 30.0], "ang": [80.0, 100.0],
		"vida": [1.0, 1.6], "tam": [6.0, 9.0], "fim": 0.8, "cor": liq, "grav": 900.0, "chao": baixo, "espalha": 30.0})
	# a bebida espirrada fica na parede atrás e (nas tábuas de baixo) no tampo
	_manchar(Vector2(g.x + rand_range(-10, 10), PE_PRATELEIRA[g.prateleira] - 70.0 * g.spr.scale.y * 2.0), liq, Vector2(1.1, 1.3))
	if g.prateleira <= 50:
		_manchar(Vector2(g.x + 6.0, PE_PRATELEIRA[g.prateleira] + 2.0), liq, Vector2(1.4, 0.22))
	_balancar(g.prateleira, g.x, 0.09)
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


## Tiro na janela que destruiu vidro: os 5 primeiros valem pontos (bônus,
## sem mexer no combo); no 5º o que sobrou do vidro desaba e acabou.
func _tiro_na_janela(p: Vector2) -> void:
	_janela_pagos += 1
	bonus(BONUS_JANELA, p + Vector2(0, 40), Color(0.78, 0.93, 1.0), 1.1)
	if _janela_pagos == 1:
		avisos.instrucao("JANELA! +%d NOS %d PRIMEIROS TIROS" % [BONUS_JANELA, JANELA_TIROS], Color(0.82, 0.94, 1.0))
	if _janela_pagos >= JANELA_TIROS:
		_janela.desabar(p)
		_sol_forca = 2.2
		tremer(5.0, 0.25)
		avisos.instrucao("JANELA DESTRUÍDA!", Color(0.82, 0.94, 1.0))


func _lascar(p: Vector2, material: String) -> void:
	_furo(p, "bar_furo_papel" if material == "papel" else "bar_furo_madeira")
	# tiro na tábua sacode as garrafas que estão em cima dela
	for prat in PE_PRATELEIRA:
		if p.y > PE_PRATELEIRA[prat] - 10.0 and p.y < BASE_TABUA[prat] + 4.0:
			_balancar(prat, p.x, 0.06)
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


## O furo da bala (madeira ou papel): na frente das tábuas de cima ele fica
## por cima das garrafas. Os furos mais velhos são reaproveitados (nada de nó
## novo a cada tiro).
func _furo(p: Vector2, tex: String) -> void:
	var pai = _furos
	for b in BEIRADAS:
		if p.y >= b.x and p.y <= b.y:
			pai = _furos_frente
	var s: Sprite
	if _furos.get_child_count() + _furos_frente.get_child_count() >= 24:
		# o mais velho dos dois lados
		var a: Sprite = _furos.get_child(0) if _furos.get_child_count() > 0 else null
		var b2: Sprite = _furos_frente.get_child(0) if _furos_frente.get_child_count() > 0 else null
		s = a if b2 == null or (a != null and int(a.get_meta("n")) < int(b2.get_meta("n"))) else b2
		if s.get_parent() != pai:
			s.get_parent().remove_child(s)
			pai.add_child(s)
		else:
			pai.move_child(s, pai.get_child_count() - 1)
	else:
		s = Sprite.new()
		pai.add_child(s)
	_n_furo += 1
	s.set_meta("n", _n_furo)
	s.texture = Estilo.tex(tex)
	s.position = p
	s.scale = Vector2.ONE * rand_range(0.42, 0.55)
	s.rotation = randf() * TAU


## A bebida espirrada: uma mancha que seca devagar (poucas, reaproveitadas).
func _manchar(p: Vector2, c: Color, esc: Vector2) -> void:
	var s: Sprite
	if _manchas.get_child_count() >= 8:
		s = _manchas.get_child(0)
		_manchas.move_child(s, _manchas.get_child_count() - 1)
	else:
		s = Sprite.new()
		s.texture = Estilo.tex("fx_nuvem")
		_manchas.add_child(s)
	s.position = p
	s.rotation = rand_range(-0.3, 0.3)
	s.scale = esc * rand_range(0.85, 1.15) * 0.55
	# madeira molhada escurece (a cor da bebida só tinge)
	s.modulate = Color(0.16 + c.r * 0.14, 0.07 + c.g * 0.08, 0.02 + c.b * 0.05, 0.5)
	s.set_meta("t", 0.0)


func _encerrou() -> void:
	for g in garrafas:
		var tw = create_tween()
		tw.tween_property(g.no, "modulate:a", 0.0, 0.4)
		tw.tween_callback(g.no, "queue_free")
	garrafas.clear()
	_slots.clear()
	_vago_ate.clear()


# ------------------------------------------------------------ vida do bar
func _sempre(delta: float) -> void:
	_t += delta
	var e = Maquina.pulso_vivo()
	# o sol respira como se nuvens passassem lá fora; as listras andam
	var nuvem = 0.86 + 0.14 * sin(_t * 0.21) * sin(_t * 0.137 + 1.3)
	var c = _janela.clarao()
	var forca_sol = 0.5 * nuvem * (_sol_forca + 0.9 * c * c)
	var w = 0.5 + 0.5 * sin(_t * 0.55)
	_feixe_a.modulate.a = forca_sol * w
	_feixe_b.modulate.a = forca_sol * (1.0 - w)
	# poeira brilhando dentro do feixe (some com a tela leve)
	if _poeira_sol.visible and randf() < delta * 7.0 * Maquina.fator_efeitos():
		var q: Vector2 = PONTOS_POEIRA[randi() % PONTOS_POEIRA.size()]
		var p = tela(q) + Vector2(rand_range(-12, 12), rand_range(-12, 12))
		_poeira_sol.soltar(p, Vector2(rand_range(-4, 8), rand_range(-2, 9)), rand_range(3.0, 5.0), rand_range(4.0, 7.0), 2.0,
			Color(1.0, 0.9, 0.6, 0.6), Color(1.0, 0.9, 0.6, 0.0), Estilo.tex("fx_ponto"))
	_janela.respirar(_t)
	if not _jatos.empty():
		for j in _jatos:
			j["t"] += delta
		_poca = min(1.0, _poca + delta * 0.05 * _jatos.size())
		_vinho.update()
	_forca_sol = forca_sol
	_vida_das_garrafas(delta)
	# a bebida espirrada seca devagar
	for m in _manchas.get_children():
		if m.modulate.a > 0.0:
			var tm: float = m.get_meta("t") + delta
			m.set_meta("t", tm)
			if tm > 4.0:
				m.modulate.a = max(0.0, m.modulate.a - delta * 0.12)


## Cada quadro: o balanço (gira no pé, amortecido), o contraluz no ritmo do
## sol e, de vez em quando, um reflexo correndo no vidro.
func _vida_das_garrafas(delta: float) -> void:
	for g in garrafas:
		if g.balanco != 0.0:
			g.balanco_t += delta
			var am = exp(-g.balanco_t * 5.5)
			if am < 0.03:
				g.balanco = 0.0
				g.no.rotation = 0.0
			else:
				g.no.rotation = g.balanco * am * sin(g.balanco_t * 23.0)
		if g.contraluz != null:
			g.contraluz.modulate.a = clamp(g.luz * _forca_sol * 0.75, 0.0, 0.55)
	if not garrafas.empty() and randf() < delta * 0.9 * Maquina.fator_efeitos():
		var g: Garrafa = garrafas[randi() % garrafas.size()]
		if not g.saindo and g.spr.position == Vector2.ZERO:
			var cel: Vector2 = g.f["cel"]
			var esc: float = g.spr.scale.y
			var p = g.no.position + Vector2(-cel.x * esc * rand_range(0.05, 0.2), -cel.y * esc * rand_range(0.45, 0.7))
			particulas_luz.soltar(p, Vector2(0, rand_range(-10, -4)), rand_range(0.35, 0.55), rand_range(16.0, 26.0), 2.0,
				Color(1.0, 0.95, 0.82, 0.85 * (0.6 + 0.6 * g.luz)), Color(1.0, 0.9, 0.7, 0.0), Estilo.tex("fx_estrela"), 0.0, 0.0, 2.5)


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
