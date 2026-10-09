extends RefCounted

# Pincel: desenha círculos, anéis, linhas, arcos e efeitos com recortes de UMA
# textura (sprites/pincel.png, gerada por tools/gerar_pincel.py).
#
# Por quê: no renderizador de compatibilidade (o da TV Box) cada draw_circle,
# draw_arc, draw_line com antialias e draw_colored_polygon é um desenho
# separado na placa de vídeo. Retângulos da mesma textura, mesmo girados e
# com cores diferentes, saem juntos num desenho só. Uma mira tinha 7-12
# desenhos; os efeitos do Mar chegavam a ~1800 por quadro.
#
# Quem usa deve ligar o filtro com mipmaps no nó que desenha:
#   no.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
# e não intercalar draw_* comuns no meio (quebra o lote).

const TEXTURA := preload("res://sprites/pincel.png")

const C := 128.0
const R := 48.0   # raio das formas redondas dentro da célula

const DISCO := 0
const BRILHO := 1
const ANEL_0 := 2   # 6 espessuras: 2..7
const TRACO := 8
const LASCA := 9
const MOEDA := 10
const FURO := 11
const BOLHA := 12
const FAISCA := 13
const FUMACA := 14
const LASER := 15

const ANEIS := [0.035, 0.07, 0.12, 0.2, 0.32, 0.5]


static func celula(i: int) -> Rect2:
	return Rect2(float(i % 4) * C, float(i >> 2) * C, C, C)


## Desenha a célula `i` centrada em `centro`, com a forma de raio `raio`
## (para as redondas: o raio do círculo; para as outras: meia largura).
static func forma(ci: CanvasItem, i: int, centro: Vector2, raio: float, cor: Color, rot: float = 0.0, escala: Vector2 = Vector2.ONE) -> void:
	var meio := raio * (C * 0.5) / R
	if rot == 0.0 and escala == Vector2.ONE:
		ci.draw_texture_rect_region(TEXTURA, Rect2(centro - Vector2(meio, meio), Vector2(meio, meio) * 2.0), celula(i), cor)
		return
	ci.draw_set_transform(centro, rot, escala)
	ci.draw_texture_rect_region(TEXTURA, Rect2(-meio, -meio, meio * 2.0, meio * 2.0), celula(i), cor)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func circulo(ci: CanvasItem, centro: Vector2, raio: float, cor: Color) -> void:
	forma(ci, DISCO, centro, raio, cor)


static func brilho(ci: CanvasItem, centro: Vector2, raio: float, cor: Color) -> void:
	# a célula do brilho vai até 1.25 R
	forma(ci, BRILHO, centro, raio / 1.25, cor)


## Mesmo resultado de draw_arc(centro, raio, 0, TAU, ..., cor, largura):
## anel com o meio da espessura em `raio`.
static func anel(ci: CanvasItem, centro: Vector2, raio: float, largura: float, cor: Color) -> void:
	var fora := raio + largura * 0.5
	if fora <= 0.0:
		return
	var t := clampf(largura / fora, 0.0, 1.0)
	var melhor := 0
	var erro := INF
	for k in range(ANEIS.size()):
		var e := absf(log(ANEIS[k] / maxf(t, 0.001)))
		if e < erro:
			erro = e
			melhor = k
	forma(ci, ANEL_0 + melhor, centro, fora, cor)


static func linha(ci: CanvasItem, a: Vector2, b: Vector2, cor: Color, largura: float = 1.0) -> void:
	var d := b - a
	var comp := d.length()
	if comp <= 0.0001:
		return
	# miolo da célula: x 32..96, y 40..88 (32 px cheios no meio de 48)
	var fonte := Rect2(32.0, 2.0 * C + 40.0, 64.0, 48.0)
	var alto := largura * 1.5
	ci.draw_set_transform(a, d.angle(), Vector2.ONE)
	ci.draw_texture_rect_region(TEXTURA, Rect2(0.0, -alto * 0.5, comp, alto), fonte, cor)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Arco de `de` até `ate` (radianos) em pedaços de reta; quantos pedaços
## depende do raio (erro de no máximo ~0.3 px).
static func arco(ci: CanvasItem, centro: Vector2, raio: float, de: float, ate: float, cor: Color, largura: float = 1.0) -> void:
	var abertura := ate - de
	if absf(abertura) < 0.0001 or raio <= 0.0:
		return
	if absf(abertura) >= TAU - 0.0001:
		anel(ci, centro, raio, largura, cor)
		return
	var passo_max := 2.0 * acos(clampf(1.0 - 0.3 / raio, -1.0, 1.0))
	var pedacos := clampi(int(ceil(absf(abertura) / maxf(passo_max, 0.05))), 2, 64)
	var fonte := Rect2(32.0, 2.0 * C + 40.0, 64.0, 48.0)
	var alto := largura * 1.5
	var ant := centro + Vector2(cos(de), sin(de)) * raio
	for k in range(1, pedacos + 1):
		var ang := de + abertura * float(k) / float(pedacos)
		var p := centro + Vector2(cos(ang), sin(ang)) * raio
		var d := p - ant
		var comp := d.length()
		# estica meia largura para os pedaços se encostarem sem fresta
		ci.draw_set_transform(ant - d.normalized() * largura * 0.25, d.angle(), Vector2.ONE)
		ci.draw_texture_rect_region(TEXTURA, Rect2(0.0, -alto * 0.5, comp + largura * 0.5, alto), fonte, cor)
		ant = p
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func laser(ci: CanvasItem, a: Vector2, b: Vector2, cor: Color, largura: float = 4.0) -> void:
	var d := b - a
	var comp := d.length()
	if comp <= 0.0001:
		return
	# miolo de 12 px (±6) na célula de 128 px de altura
	var fonte := Rect2(3.0 * C + 32.0, 3.0 * C, 64.0, C)
	var alto := largura * C / 12.0
	ci.draw_set_transform(a, d.angle(), Vector2.ONE)
	ci.draw_texture_rect_region(TEXTURA, Rect2(0.0, -alto * 0.5, comp, alto), fonte, cor)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func lasca(ci: CanvasItem, centro: Vector2, tam: Vector2, rot: float, cor: Color) -> void:
	# a lasca ocupa ~±44 px da célula; tam = meia largura/altura desejada
	forma(ci, LASCA, centro, R * 0.5 * (tam.x + tam.y) / 44.0, cor, rot, Vector2(tam.x, tam.y) / maxf(0.001, 0.5 * (tam.x + tam.y)))


## Miolo de formas cheias quaisquer (polígono pequeno): aproxima pela lasca.
static func caco(ci: CanvasItem, centro: Vector2, raio: float, rot: float, cor: Color) -> void:
	forma(ci, LASCA, centro, raio * R / 44.0, cor, rot)


## A mira padrão do jogo (anel externo colorido, anel interno, ponto e 4
## traços), igual em todas as fases.
static func mira(ci: CanvasItem, pos: Vector2, r1: float, r2: float, cor_ext: Color, cor_int: Color, cor_linha: Color = Color.WHITE, alfa: float = 1.0) -> void:
	anel(ci, pos, r1, 2.6, cor_ext)
	anel(ci, pos, r2, 1.2, cor_int)
	circulo(ci, pos, 2.8, Color(1.0, 1.0, 1.0, 0.96 * alfa))
	linha(ci, pos + Vector2(-26, 0), pos + Vector2(-8, 0), cor_linha, 2.0)
	linha(ci, pos + Vector2(8, 0), pos + Vector2(26, 0), cor_linha, 2.0)
	linha(ci, pos + Vector2(0, -26), pos + Vector2(0, -8), cor_linha, 2.0)
	linha(ci, pos + Vector2(0, 8), pos + Vector2(0, 26), cor_linha, 2.0)


## Anel de recarga em volta da mira (progresso 0..1, começa em cima).
static func mira_recarga(ci: CanvasItem, pos: Vector2, progresso: float, raio: float = 34.0, espessura: float = 5.0) -> void:
	var de := -PI * 0.5
	var ate := de + TAU * clampf(progresso, 0.0, 1.0)
	anel(ci, pos, raio, espessura, Color(0.10, 0.20, 0.28, 0.42))
	arco(ci, pos, raio, de, ate, Color(0.30, 0.94, 1.0, 1.0), espessura)
	arco(ci, pos, raio + 7.0, de, ate, Color(0.82, 0.98, 1.0, 0.55), 2.0)
