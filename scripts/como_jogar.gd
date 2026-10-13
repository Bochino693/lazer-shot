class_name ComoJogar
extends Control

## COMO JOGAR: o aviso do começo de cada fase, refeito para ser lido DE
## LONGE: letras grandes, poucas palavras, a figura de cada alvo e os pontos
## que o jogo dá de verdade (tirados do código de cada fase):
##
##   deserto.gd  acerto do astro do modo atual +20/50/80/100, astro errado
##               -20/50/80/100, dia e noite trocam a cada 30 s, combo a
##               partir de 3 acertos seguidos
##   mar.gd      água-viva 20, pote 80, baú 100, 3 bombas encerram
##   bar.gd      gin 20, rum 50, vodka 80, whisky 100, garrafa verde -500
##   arena.gd    1º a 5º acerto da sequência 20/40/60/80/100, ordem errada
##               -100 e recomeça, sequência fixa completa +50, rápido +10
##
## A fase cria a tela e a coloca no lugar da imagem antiga:
##   var cj := ComoJogar.criar("mar", {"agua": textura, ...})
##   raiz_do_aviso.add_child(cj)
## Ela some junto com a raiz do aviso (o tiro que começa a partida).

const Pincel := preload("res://scripts/pincel.gd")
const FONTE_FORTE := preload("res://fonts/Exo2-ExtraBold.ttf")
const FONTE := preload("res://fonts/Exo2-Bold.ttf")

const VERDE := Color(0.42, 1.0, 0.48)
const VERMELHO := Color(1.0, 0.30, 0.26)
const OURO := Color(1.0, 0.86, 0.36)

const CORES_ARENA := [
	["AZUL", Color(0.25, 0.55, 1.0)],
	["VERDE", Color(0.30, 0.95, 0.40)],
	["AMARELO", Color(1.0, 0.86, 0.20)],
	["VERMELHO", Color(1.0, 0.25, 0.22)],
	["ROXO", Color(0.72, 0.38, 1.0)],
]

## linha: [ícone, nome, detalhe, valor, cor do valor]
const DADOS := {
	"deserto": {
		"nome": "DESERTO SAGRADO", "cor": Color(1.0, 0.74, 0.22),
		"linhas": [
			["sol", "DE DIA", "ACERTE O SOL", "+20 a +100", VERDE],
			["lua", "DE NOITE", "ACERTE A LUA", "+20 a +100", VERDE],
			["erro", "ASTRO ERRADO", "LUA DE DIA OU SOL DE NOITE", "-20 a -100", VERMELHO],
		],
		"regras": ["O DIA E A NOITE TROCAM A CADA 30 s", "3 ACERTOS SEGUIDOS = COMBO EXTRA"],
	},
	"mar": {
		"nome": "FUNDO DO MAR", "cor": Color(0.24, 0.72, 1.0),
		"linhas": [
			["agua", "ÁGUA-VIVA", "", "+20", VERDE],
			["pote", "POTE", "", "+80", VERDE],
			["bau", "BAÚ", "", "+100", VERDE],
			["bomba", "BOMBA", "NÃO ATIRE!", "3 = FIM", VERMELHO],
		],
		"regras": ["ACERTOU 3 BOMBAS, A PARTIDA ACABA"],
	},
	"bar": {
		"nome": "BAR DO FAROESTE", "cor": Color(0.34, 0.95, 0.42),
		"linhas": [
			["gin", "GIN", "", "+20", VERDE],
			["rum", "RUM", "", "+50", VERDE],
			["vodka", "VODKA", "", "+80", VERDE],
			["whisky", "WHISKY", "", "+100", VERDE],
			["falsa", "GARRAFA VERDE", "COM CAVEIRA", "-500", VERMELHO],
		],
		"regras": [],
	},
	"arena": {
		"nome": "ARENA LAZER SHOT", "cor": Color(1.0, 0.24, 0.20),
		"linhas": [],
		"sequencia": true,
		"regras": ["ORDEM ERRADA: -100 E RECOMEÇA", "LANTERNAS FIXAS: COMPLETA +50,\nACERTO RÁPIDO +10"],
	},
}

var _cor := Color.WHITE
var _t := 0.0
var _rodape: Label
var _alvo: Control
var _desenhos: Array = []    # [Control, tipo, cor, texto]


## Monta a tela da fase `fase` com as figuras `icones` (nome -> Texture2D).
static func criar(fase: String, icones: Dictionary = {}) -> ComoJogar:
	var cj := ComoJogar.new()
	cj.name = "ComoJogar"
	cj._fase = fase
	cj._icones = icones
	return cj


var _fase := ""
var _icones: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_montar()
	get_viewport().size_changed.connect(_remontar)


func _remontar() -> void:
	for c in get_children():
		c.queue_free()
	_desenhos.clear()
	_montar.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _rodape != null:
		_rodape.modulate.a = 0.55 + 0.45 * absf(sin(_t * 3.2))
	if _alvo != null:
		_alvo.queue_redraw()


## A figura de um alvo da fase (Sprite2D, AnimatedSprite2D ou TextureRect,
## no próprio nó ou nos filhos).
static func textura_de(n: Node) -> Texture2D:
	if n == null:
		return null
	if n is AnimatedSprite2D:
		# a animação atual; se estiver vazia, a de repouso ou a primeira com quadros
		var sf := (n as AnimatedSprite2D).sprite_frames
		if sf != null:
			var nomes: Array = [(n as AnimatedSprite2D).animation, &"idle", &"default"]
			nomes.append_array(sf.get_animation_names())
			for anim in nomes:
				if sf.has_animation(anim) and sf.get_frame_count(anim) > 0:
					return sf.get_frame_texture(anim, 0)
	if n is Sprite2D:
		var sp := n as Sprite2D
		if sp.texture != null:
			if sp.region_enabled or sp.hframes > 1 or sp.vframes > 1:
				var at := AtlasTexture.new()
				at.atlas = sp.texture
				if sp.region_enabled:
					at.region = sp.region_rect
				else:
					var tam := sp.texture.get_size() / Vector2(sp.hframes, sp.vframes)
					at.region = Rect2(Vector2(sp.frame % sp.hframes, sp.frame / sp.hframes) * tam, tam)
				return at
			return sp.texture
	if n is TextureRect and (n as TextureRect).texture != null:
		return (n as TextureRect).texture
	for c in n.get_children():
		var t := textura_de(c)
		if t != null:
			return t
	return null


# ───────────────────────────────────────────── montagem

func _montar() -> void:
	var d: Dictionary = DADOS.get(_fase, {})
	if d.is_empty():
		return
	_cor = d["cor"]
	var tela := get_viewport_rect().size
	var s := tela.x / 1024.0

	var fundo := ColorRect.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.color = Color(0.0, 0.0, 0.0, 0.78)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	var painel := Panel.new()
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.05, 0.0)   # o fundo é da moldura
	sb.set_corner_radius_all(int(34 * s))
	sb.border_color = _cor
	sb.set_border_width_all(int(4 * s))
	sb.shadow_color = Color(_cor.r, _cor.g, _cor.b, 0.28)
	sb.shadow_size = int(22 * s)
	sb.anti_aliasing = true
	painel.add_theme_stylebox_override("panel", sb)
	add_child(painel)

	var w := 960.0 * s
	var pad := 36.0 * s
	var y := MolduraTema.MARGEM * s

	# As linhas dos alvos ficam do maior tamanho que couber na tela.
	var regras: Array = d.get("regras", [])
	var fixo := MolduraTema.MARGEM * 2.0 + 170.0 + 140.0 + 120.0
	for r in regras:
		fixo += 62.0 * (str(r).count("\n") + 1)
	if not regras.is_empty():
		fixo += 36.0
	if d.get("sequencia", false):
		fixo += 330.0
	var n_linhas: int = (d.get("linhas", []) as Array).size()
	var alto_linha := 150.0 * s
	if n_linhas > 0:
		alto_linha = clampf((tela.y - 110.0 * s - fixo * s) / n_linhas, 140.0 * s, 210.0 * s)

	# cabeçalho
	var chip := _rotulo(painel, "COMO JOGAR", 38, Color(1, 1, 1, 0.85), FONTE, 6, s)
	chip.position = Vector2(0, y)
	chip.size = Vector2(w, 46 * s)
	y += 46.0 * s
	var titulo := _rotulo(painel, str(d["nome"]), 80, _cor.lerp(Color.WHITE, 0.3), FONTE_FORTE, 12, s)
	titulo.position = Vector2(0, y)
	titulo.size = Vector2(w, 100 * s)
	# a moldura do cenário fica atrás de tudo (scripts/moldura_tema.gd)
	var moldura := MolduraTema.criar(_fase, y + 50.0 * s)
	painel.add_child(moldura)
	painel.move_child(moldura, 0)
	y += 106.0 * s
	_traco(painel, Vector2(pad, y), w - pad * 2.0, s)
	y += 18.0 * s

	# alvos e pontos
	for linha in d.get("linhas", []):
		y = _linha(painel, linha, y, w, pad, s, alto_linha)
	if d.get("sequencia", false):
		y = _sequencia(painel, y, w, pad, s)

	# regras
	if not regras.is_empty():
		y += 10.0 * s
		_traco(painel, Vector2(pad, y), w - pad * 2.0, s)
		y += 16.0 * s
		for r in regras:
			var linhas := str(r).count("\n") + 1
			var l := _rotulo(painel, str(r), 42, OURO, FONTE, 8, s)
			l.position = Vector2(pad, y)
			l.size = Vector2(w - pad * 2.0, 58.0 * s * linhas)
			y += 58.0 * s * linhas + 4.0 * s

	# partida: tempo, munição, recarga
	y += 14.0 * s
	var tempo := 120
	var mq := get_node_or_null("/root/Maquina")
	if mq != null:
		tempo = int(mq.valor("jogo/tempo_partida"))
	var chips := ["%d:%02d DE PARTIDA" % [tempo / 60, tempo % 60], "30 TIROS", "RECARGA NO BOTÃO"]
	var cw := (w - pad * 2.0 - 2.0 * 14.0 * s) / 3.0
	for i in chips.size():
		var c := Panel.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sbc := StyleBoxFlat.new()
		sbc.bg_color = Color(0, 0, 0, 0.45)
		sbc.border_color = Color(1, 1, 1, 0.30)
		sbc.set_border_width_all(int(2 * s))
		sbc.set_corner_radius_all(int(18 * s))
		c.add_theme_stylebox_override("panel", sbc)
		c.position = Vector2(pad + i * (cw + 14.0 * s), y)
		c.size = Vector2(cw, 84 * s)
		painel.add_child(c)
		var lc := _rotulo(c, chips[i], 31, Color.WHITE, FONTE, 6, s)
		lc.position = Vector2.ZERO
		lc.size = c.size
	y += 84.0 * s + 26.0 * s

	# rodapé: o tiro que começa
	_alvo = Control.new()
	_alvo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alvo.size = Vector2(88, 88) * s
	_alvo.position = Vector2(pad + 10.0 * s, y + 4.0 * s)
	_alvo.draw.connect(_desenhar_alvo_rodape)
	painel.add_child(_alvo)
	_rodape = _rotulo(painel, "ATIRE PARA COMEÇAR", 62, Color.WHITE, FONTE_FORTE, 12, s)
	_rodape.position = Vector2(pad + 100.0 * s, y)
	_rodape.size = Vector2(w - pad * 2.0 - 120.0 * s, 96 * s)
	y += 96.0 * s + MolduraTema.MARGEM * s

	painel.size = Vector2(w, y)
	var k := minf(1.0, (tela.y - 60.0 * s) / y)
	painel.scale = Vector2(k, k)
	painel.position = ((tela - painel.size * k) * 0.5).floor()


func _linha(pai: Control, linha: Array, y: float, w: float, pad: float, s: float, alto: float) -> float:
	var k := alto / (140.0 * s)   # letras crescem junto com a linha
	var caixa := Panel.new()
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sbx := StyleBoxFlat.new()
	sbx.bg_color = Color(0, 0, 0, 0.42)
	sbx.border_color = Color(_cor.r, _cor.g, _cor.b, 0.30)
	sbx.set_border_width_all(int(2 * s))
	sbx.set_corner_radius_all(int(22 * s))
	caixa.add_theme_stylebox_override("panel", sbx)
	caixa.position = Vector2(pad, y)
	caixa.size = Vector2(w - pad * 2.0, alto - 12.0 * s)
	pai.add_child(caixa)

	# figura
	var lado := alto - 24.0 * s
	var icone := str(linha[0])
	var tex: Texture2D = _icones.get(icone)
	if tex != null:
		var tr := TextureRect.new()
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = tex
		tr.position = Vector2(14.0 * s, 0.0)
		tr.size = Vector2(lado, lado)
		caixa.add_child(tr)
	else:
		var dz := Control.new()
		dz.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dz.position = Vector2(14.0 * s, 0.0)
		dz.size = Vector2(lado, lado)
		caixa.add_child(dz)
		_desenhos.append([dz, icone, _cor_do_icone(icone), ""])
		dz.draw.connect(_desenhar_icone.bind(_desenhos.size() - 1))

	# nome e detalhe
	var x_txt := 14.0 * s + lado + 20.0 * s
	var larg_valor := 330.0 * s
	var larg_nome := caixa.size.x - x_txt - larg_valor - 16.0 * s
	var nome := _rotulo(caixa, str(linha[1]), int(50 * minf(k, 1.25)), Color.WHITE, FONTE_FORTE, 9, s)
	_caber(nome, larg_nome)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var tem_detalhe := str(linha[2]) != ""
	var meio := caixa.size.y * 0.5
	nome.position = Vector2(x_txt, meio - 62.0 * s * minf(k, 1.25) if tem_detalhe else 0.0)
	nome.size = Vector2(larg_nome, 66.0 * s * minf(k, 1.25) if tem_detalhe else caixa.size.y)
	if tem_detalhe:
		var det := _rotulo(caixa, str(linha[2]), int(30 * minf(k, 1.2)), Color(0.85, 0.87, 0.92), FONTE, 6, s)
		det.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		det.position = Vector2(x_txt, meio + 6.0 * s)
		det.size = Vector2(larg_nome, 46.0 * s * minf(k, 1.2))
		_caber(det, larg_nome)

	# pontos
	var valor := _rotulo(caixa, str(linha[3]), int(60 * minf(k, 1.25)), linha[4], FONTE_FORTE, 10, s)
	_caber(valor, larg_valor)
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	valor.position = Vector2(caixa.size.x - larg_valor - 20.0 * s, 0.0)
	valor.size = Vector2(larg_valor, caixa.size.y)
	return y + alto


## Arena: as 5 cores na ordem, com os pontos de cada acerto.
func _sequencia(pai: Control, y: float, w: float, pad: float, s: float) -> float:
	var l := _rotulo(pai, "ACERTE AS LANTERNAS NA ORDEM", 44, Color.WHITE, FONTE_FORTE, 9, s)
	l.position = Vector2(0, y)
	l.size = Vector2(w, 64 * s)
	y += 70.0 * s
	var passo := (w - pad * 2.0) / 5.0
	var diam := minf(passo - 16.0 * s, 150.0 * s)
	for i in 5:
		var cx := pad + passo * (i + 0.5)
		var dz := Control.new()
		dz.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dz.position = Vector2(cx - diam * 0.5, y)
		dz.size = Vector2(diam, diam)
		pai.add_child(dz)
		_desenhos.append([dz, "lanterna", CORES_ARENA[i][1], str(i + 1)])
		dz.draw.connect(_desenhar_icone.bind(_desenhos.size() - 1))
		var num := _rotulo(pai, str(i + 1), 62, Color.WHITE, FONTE_FORTE, 10, s)
		num.position = dz.position
		num.size = dz.size
		var nome := _rotulo(pai, CORES_ARENA[i][0], 28, (CORES_ARENA[i][1] as Color).lerp(Color.WHITE, 0.3), FONTE, 6, s)
		nome.position = Vector2(cx - passo * 0.5, y + diam + 4.0 * s)
		nome.size = Vector2(passo, 40.0 * s)
		var pts := _rotulo(pai, "+%d" % ((i + 1) * 20), 50, VERDE, FONTE_FORTE, 9, s)
		pts.position = Vector2(cx - passo * 0.5, y + diam + 44.0 * s)
		pts.size = Vector2(passo, 62.0 * s)
	return y + diam + 116.0 * s


func _cor_do_icone(icone: String) -> Color:
	match icone:
		"sol":
			return Color(1.0, 0.78, 0.25)
		"lua":
			return Color(0.75, 0.85, 1.0)
		"erro":
			return VERMELHO
	return _cor


func _desenhar_icone(i: int) -> void:
	var item: Array = _desenhos[i]
	var dz: Control = item[0]
	var tipo: String = item[1]
	var cor: Color = item[2]
	var c := dz.size * 0.5
	var r := dz.size.x * 0.5
	match tipo:
		"erro":
			Pincel.circulo(dz, c, r * 0.80, Color(0.25, 0.02, 0.02, 0.9))
			Pincel.anel(dz, c, r * 0.80, r * 0.10, cor)
			var d := r * 0.38
			Pincel.linha(dz, c + Vector2(-d, -d), c + Vector2(d, d), Color.WHITE, r * 0.16)
			Pincel.linha(dz, c + Vector2(d, -d), c + Vector2(-d, d), Color.WHITE, r * 0.16)
		"lanterna":
			Pincel.brilho(dz, c, r * 1.05, Color(cor.r, cor.g, cor.b, 0.45))
			Pincel.circulo(dz, c, r * 0.78, cor.darkened(0.25))
			Pincel.anel(dz, c, r * 0.78, r * 0.08, cor.lerp(Color.WHITE, 0.35))
		_:
			Pincel.brilho(dz, c, r, Color(cor.r, cor.g, cor.b, 0.4))
			Pincel.circulo(dz, c, r * 0.7, cor)


func _desenhar_alvo_rodape() -> void:
	var c := _alvo.size * 0.5
	var r := _alvo.size.x * 0.5 * (1.0 + 0.06 * sin(_t * 6.0))
	Pincel.anel(_alvo, c, r * 0.85, r * 0.12, Color(1.0, 0.22, 0.18))
	Pincel.anel(_alvo, c, r * 0.48, r * 0.08, Color.WHITE)
	Pincel.circulo(_alvo, c, r * 0.16, Color(1.0, 0.22, 0.18))


## Diminui a letra até o texto caber na largura (nunca transborda por cima
## do vizinho).
func _caber(l: Label, largura: float) -> void:
	var fonte: Font = l.get_theme_font("font")
	var tam := l.get_theme_font_size("font_size")
	while tam > 12 and fonte.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > largura:
		tam -= 2
	l.add_theme_font_size_override("font_size", tam)


func _traco(pai: Control, pos: Vector2, largura: float, s: float) -> void:
	var t := ColorRect.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.color = Color(_cor.r, _cor.g, _cor.b, 0.45)
	t.position = pos
	t.size = Vector2(largura, maxf(2.0, 3.0 * s))
	pai.add_child(t)


func _rotulo(pai: Control, texto: String, tamanho: int, cor: Color, fonte: Font, contorno: int, s: float) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", int(tamanho * s))
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", int(contorno * s))
	pai.add_child(l)
	return l
