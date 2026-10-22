extends CanvasLayer
class_name ComoJogar

## COMO JOGAR: o aviso do começo de cada fase, para ser lido DE LONGE: letras
## grandes, poucas palavras, a figura de cada alvo e os pontos que o jogo dá
## de verdade:
##
##   deserto  acerto do astro do modo atual +20/50/80/100, astro errado
##            -20/50/80/100, dia e noite trocam a cada 30 s, combo a
##            partir de 3 acertos seguidos
##   mar      água-viva 20, pote 80, baú 100, 3 bombas encerram
##   bar      gin 20, rum 50, vodka 80, whisky 100, garrafa verde -500
##   arena    1º a 5º acerto da sequência 20/40/60/80/100, ordem errada
##            -100 e recomeça, sequência fixa completa +50, rápido +10
##
## Montado uma vez (só Controls); some com o tiro que começa a partida.

const VERDE = Color(0.42, 1.0, 0.48)
const VERMELHO = Color(1.0, 0.30, 0.26)
const OURO = Color(1.0, 0.86, 0.36)

const CORES_ARENA = [
	["AZUL", Color(0.25, 0.55, 1.0)],
	["VERDE", Color(0.30, 0.95, 0.40)],
	["AMARELO", Color(1.0, 0.86, 0.20)],
	["VERMELHO", Color(1.0, 0.25, 0.22)],
	["ROXO", Color(0.72, 0.38, 1.0)],
]

## linha: [ícone, nome, detalhe, valor, cor do valor]
const DADOS = {
	"deserto": {
		"nome": "DESERTO SAGRADO", "cor": Color(1.0, 0.74, 0.22),
		"linhas": [
			["sol", "DE DIA", "ACERTE O SOL", "+20 a +100", VERDE],
			["lua", "DE NOITE", "ACERTE A LUA", "+20 a +100", VERDE],
			["erro", "ASTRO ERRADO", "LUA DE DIA OU SOL DE NOITE", "-20 a -100", VERMELHO],
		],
		"regras": ["O DIA E A NOITE TROCAM A CADA 30 s", "3 ACERTOS SEGUIDOS = COMBO EXTRA", "CRISTAIS DÃO PONTOS EXTRAS"],
	},
	"mar": {
		"nome": "FUNDO DO MAR", "cor": Color(0.24, 0.72, 1.0),
		"linhas": [
			["agua", "ÁGUA-VIVA", "", "+20", VERDE],
			["pote", "POTE", "", "+80", VERDE],
			["bau", "BAÚ", "", "+100", VERDE],
			["bomba", "BOMBA", "NÃO ATIRE!", "3 = FIM", VERMELHO],
		],
		"regras": ["ACERTOU 3 BOMBAS, A PARTIDA ACABA", "PEIXES DOURADOS: +40 CADA"],
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
		"regras": ["BARRIL: +40 POR FURO", "JANELA: +50 NOS 5 PRIMEIROS TIROS"],
	},
	"arena": {
		"nome": "ARENA LAZER SHOT", "cor": Color(1.0, 0.24, 0.20),
		"linhas": [],
		"sequencia": true,
		"regras": ["ORDEM ERRADA: -100 E RECOMEÇA", "LANTERNAS FIXAS: COMPLETA +50,\nACERTO RÁPIDO +10", "LED DO ALTO: +50"],
	},
}

var _fase = ""
var _icones = {}
var _raiz: Control
var _painel: Panel
var _rodape: Label
var _alvo: Sprite
var _t = 0.0


static func criar(pai: Node, fase: String, icones: Dictionary) -> ComoJogar:
	var c = load("res://scripts/como_jogar.gd").new()
	c._fase = fase
	c._icones = icones
	c.layer = 100
	pai.add_child(c)
	return c


func _ready() -> void:
	_raiz = Control.new()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.rect_size = Tela.TELA
	add_child(_raiz)
	var escuro = ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.45)
	escuro.rect_size = Tela.TELA
	escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(escuro)
	_montar()


func _montar() -> void:
	var d: Dictionary = DADOS[_fase]
	var cor: Color = d["cor"]
	var larg = 900.0
	var x0 = (Tela.TELA.x - larg) * 0.5
	var linhas: Array = d["linhas"]
	var regras: Array = d["regras"]
	var alto = 250.0 + (210.0 if d.get("sequencia", false) else linhas.size() * 118.0) + regras.size() * 46.0 + 210.0
	var y0 = (Tela.TELA.y - alto) * 0.5 + 40.0
	var fundo = Estilo.caixa(Color(0.035, 0.03, 0.045, 0.94), Color(cor.r, cor.g, cor.b, 0.9), 4, 26, 26, Color(cor.r, cor.g, cor.b, 0.35))
	_painel = Estilo.painel(_raiz, Vector2(x0, y0), Vector2(larg, alto), fundo)
	# a moldura do cenário fica atrás de tudo (scripts/moldura.gd)
	Moldura.criar(_painel, _fase, Vector2(larg, alto), cor, 111.0)
	var y = 26.0
	var t = Estilo.rotulo(_painel, "COMO JOGAR", 32, Color(1, 1, 1, 0.8), 0, false)
	Estilo.colocar(t, Vector2(0, y), Vector2(larg, 40))
	y += 40.0
	var nome = Estilo.rotulo(_painel, d["nome"], 70, cor.linear_interpolate(Color.white, 0.2), 7, true, Label.ALIGN_CENTER, Color(0.08, 0.04, 0.0))
	Estilo.colocar(nome, Vector2(0, y), Vector2(larg, 90))
	y += 100.0
	var linha_div = ColorRect.new()
	linha_div.color = Color(cor.r, cor.g, cor.b, 0.5)
	linha_div.rect_position = Vector2(40, y)
	linha_div.rect_size = Vector2(larg - 80, 3)
	_painel.add_child(linha_div)
	y += 22.0
	if d.get("sequencia", false):
		var tt = Estilo.rotulo(_painel, "ACERTE AS LANTERNAS NA ORDEM", 40, Color.white, 4)
		Estilo.colocar(tt, Vector2(0, y), Vector2(larg, 56))
		y += 66.0
		var passo = (larg - 80.0) / 5.0
		for i in 5:
			var cx = 40.0 + passo * (i + 0.5)
			var bola = Node2D.new()
			bola.position = Vector2(cx, y + 44)
			bola.connect("draw", self, "_desenhar_bola", [bola, CORES_ARENA[i][1], str(i + 1)])
			_painel.add_child(bola)
			var nm = Estilo.rotulo(_painel, CORES_ARENA[i][0], 22, Color(1, 1, 1, 0.85), 2, false)
			Estilo.colocar(nm, Vector2(cx - passo * 0.5, y + 94), Vector2(passo, 30))
			var vl = Estilo.rotulo(_painel, "+%d" % ((i + 1) * 20), 40, VERDE, 4)
			Estilo.colocar(vl, Vector2(cx - passo * 0.5, y + 122), Vector2(passo, 50))
		y += 190.0
	else:
		for l in linhas:
			_linha(Vector2(30, y), larg - 60.0, l)
			y += 118.0
	y += 8.0
	for r in regras:
		var rg = Estilo.rotulo(_painel, r, 32, OURO, 3)
		rg.autowrap = true
		var h = 46.0 * (1 + r.count("\n"))
		Estilo.colocar(rg, Vector2(20, y), Vector2(larg - 40, h))
		y += h
	y += 18.0
	var chips = ["%d:%02d DE PARTIDA" % [int(Maquina.tempo_partida()) / 60, int(Maquina.tempo_partida()) % 60], "30 TIROS", "RECARGA NO BOTÃO"]
	var cw = (larg - 80.0) / 3.0
	for i in 3:
		var chip = Estilo.painel(_painel, Vector2(30 + i * (cw + 10), y), Vector2(cw, 58), Estilo.caixa(Color(0, 0, 0, 0.45), Color(1, 1, 1, 0.16), 2, 14))
		var ct = Estilo.rotulo(chip, chips[i], 26, Color(1, 1, 1, 0.92), 0, false)
		Estilo.colocar(ct, Vector2.ZERO, Vector2(cw, 58))
	y += 82.0
	_alvo = Sprite.new()
	_alvo.texture = Estilo.tex("ui_alvo")
	_alvo.scale = Vector2.ONE * (64.0 / 256.0)
	_alvo.position = Vector2(150, y + 34)
	_painel.add_child(_alvo)
	_rodape = Estilo.rotulo(_painel, "ATIRE PARA COMEÇAR", 46, Color.white, 5)
	Estilo.colocar(_rodape, Vector2(190, y), Vector2(larg - 260, 70))
	_rodape.align = Label.ALIGN_LEFT


func _linha(pos: Vector2, larg: float, l: Array) -> void:
	var caixa = Estilo.painel(_painel, pos, Vector2(larg, 104), Estilo.caixa(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.10), 2, 16))
	var icone: String = l[0]
	if icone == "erro":
		var x = Node2D.new()
		x.position = Vector2(64, 52)
		x.connect("draw", self, "_desenhar_x", [x])
		caixa.add_child(x)
	elif _icones.has(icone):
		var tex: Texture = _icones[icone]
		var tr = TextureRect.new()
		tr.texture = tex
		tr.expand = true
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.rect_position = Vector2(14, 6)
		tr.rect_size = Vector2(100, 92)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caixa.add_child(tr)
	var tem_detalhe: bool = l[2] != ""
	var nm = Estilo.rotulo(caixa, l[1], 44 if not tem_detalhe else 42, Color.white, 4, true, Label.ALIGN_LEFT)
	Estilo.colocar(nm, Vector2(132, 8 if tem_detalhe else 22), Vector2(larg - 380, 56))
	if tem_detalhe:
		var dt = Estilo.rotulo(caixa, l[2], 24, Color(1, 1, 1, 0.75), 0, false, Label.ALIGN_LEFT)
		Estilo.colocar(dt, Vector2(132, 62), Vector2(larg - 380, 32))
	var vl = Estilo.rotulo(caixa, l[3], 48, l[4], 5, true, Label.ALIGN_RIGHT)
	Estilo.colocar(vl, Vector2(larg - 300, 18), Vector2(280, 68))


func _desenhar_x(n: Node2D) -> void:
	n.draw_circle(Vector2.ZERO, 40.0, Color(0.85, 0.12, 0.12))
	n.draw_circle(Vector2.ZERO, 32.0, Color(0.12, 0.02, 0.02))
	n.draw_line(Vector2(-16, -16), Vector2(16, 16), Color.white, 8.0)
	n.draw_line(Vector2(16, -16), Vector2(-16, 16), Color.white, 8.0)


func _desenhar_bola(n: Node2D, c: Color, txt: String) -> void:
	n.draw_circle(Vector2.ZERO, 40.0, c.darkened(0.55))
	n.draw_circle(Vector2.ZERO, 34.0, c)
	n.draw_circle(Vector2(-10, -12), 12.0, Color(1, 1, 1, 0.25))
	var f = Estilo.fonte(42, true, 4)
	var s = f.get_string_size(txt)
	n.draw_string(f, Vector2(-s.x * 0.5, f.get_ascent() * 0.5 - 6.0), txt, Color.white)


func fechar() -> void:
	var tw = create_tween()
	tw.tween_property(_raiz, "modulate:a", 0.0, 0.2)
	tw.tween_callback(self, "queue_free")
	set_process(false)


func _process(delta: float) -> void:
	_t += delta
	_rodape.modulate.a = 0.55 + 0.45 * abs(sin(_t * 3.2))
	_alvo.rotation = sin(_t * 2.0) * 0.15
