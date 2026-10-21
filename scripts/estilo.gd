extends Node

## ESTILO: letras, imagens de efeito e caixas usadas em todas as telas.
##
## Letras: a Exo 2 (Bold e ExtraBold) em DynamicFont, uma por tamanho e
## contorno, guardadas aqui (cada combinação nova é uma folha de letras na
## placa: poucas combinações, todas reaproveitadas). Os símbolos que a Exo 2
## não tem (🏆 ★ ✔ ⌫ 🥇...) vêm das fontes pequenas de reserva.
## Imagens de efeito (brilho, anel, faísca...): carregadas uma vez e
## compartilhadas por todas as fases.

const FONTE_FORTE = "res://fonts/Exo2-ExtraBold.ttf"
const FONTE = "res://fonts/Exo2-Bold.ttf"
const RESERVAS = ["res://fonts/Simbolos.ttf", "res://fonts/SimbolosEmoji.ttf"]

## Cor de cada fase (placar, mira, modais).
const CORES = {
	"deserto": Color(1.0, 0.74, 0.22),
	"mar": Color(0.24, 0.72, 1.0),
	"bar": Color(0.34, 0.95, 0.42),
	"arena": Color(1.0, 0.24, 0.20),
	"menu": Color(1.0, 0.18, 0.22),
}

## Letras que aparecem no jogo (preparadas na carga: nenhum texto novo
## engasga a TV Box no meio da partida desenhando letra pela primeira vez).
const LETRAS = "ABCDEFGHIJKLMNOPQRSTUVWXYZÁÀÂÃÉÊÍÓÔÕÚÇabcdefghijklmnopqrstuvwxyzáàâãéêíóôõúç0123456789+-x×/:.,!?%'()·• "

var _dados = {}
var _reservas = []
var _fontes = {}
var _texturas = {}


func _ready() -> void:
	for c in RESERVAS:
		var d = load(c)
		if d != null:
			_reservas.append(d)


func _dado(forte: bool) -> DynamicFontData:
	var k = FONTE_FORTE if forte else FONTE
	if not _dados.has(k):
		var d: DynamicFontData = load(k)
		d.antialiased = true
		d.hinting = DynamicFontData.HINTING_LIGHT
		_dados[k] = d
	return _dados[k]


## A fonte no tamanho `tam` (px do jogo). contorno: largura do contorno em px
## (0 = sem); cor_contorno: a cor dele.
func fonte(tam: int, forte: bool = true, contorno: int = 0, cor_contorno: Color = Color(0, 0, 0, 1)) -> DynamicFont:
	var chave = "%d|%d|%d|%s" % [tam, int(forte), contorno, cor_contorno.to_html()]
	if _fontes.has(chave):
		return _fontes[chave]
	var f = DynamicFont.new()
	f.font_data = _dado(forte)
	f.size = tam
	f.use_filter = true
	f.use_mipmaps = false
	if contorno > 0:
		f.outline_size = contorno
		f.outline_color = cor_contorno
	for r in _reservas:
		f.add_fallback(r)
	_fontes[chave] = f
	return f


## Esquece as fontes guardadas (troca de tela). Cada tamanho de letra tem a
## sua folha de letras na memória e na placa (a partir de 65 px, 1024x1024;
## o dobro com contorno): as fontes que só a tela que saiu usava somem com
## ela, e a tela nova faz as dela.
func soltar_fontes() -> void:
	_fontes.clear()


## Prepara as letras de uma fonte (desenha cada letra na folha agora).
func aquecer_fonte(f: Font, texto: String = LETRAS) -> void:
	if f != null:
		f.get_string_size(texto)


func aquecer_todas() -> void:
	for f in _fontes.values():
		aquecer_fonte(f)


## Imagem compartilhada (sprites/<nome>.png ou .jpg).
func tex(nome: String) -> Texture:
	if _texturas.has(nome):
		return _texturas[nome]
	var caminho = "res://sprites/%s.png" % nome
	if not ResourceLoader.exists(caminho):
		caminho = "res://sprites/%s.jpg" % nome
	var t: Texture = load(caminho)
	_texturas[nome] = t
	return t


## Solta as imagens guardadas (troca de tela): só os efeitos pequenos (fx_*)
## e a mira (ui_*) ficam. Fundos, folhas de alvo, capas e cartões são da tela
## e somem com ela.
func soltar_texturas_grandes() -> void:
	for k in _texturas.keys():
		if not (k.begins_with("fx_") or k.begins_with("ui_")):
			_texturas.erase(k)


## Material de luz somada (clarões, brilhos, faíscas, feixes).
var _soma: CanvasItemMaterial = null

func material_soma() -> CanvasItemMaterial:
	if _soma == null:
		_soma = CanvasItemMaterial.new()
		_soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _soma


# ------------------------------------------------------------ caixas e textos
func caixa(fundo: Color, borda: Color = Color(0, 0, 0, 0), largura: int = 0, raio: int = 16,
		sombra: float = 0.0, cor_sombra: Color = Color(0, 0, 0, 0.5)) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = borda
	s.set_border_width_all(largura)
	s.set_corner_radius_all(raio)
	s.corner_detail = 6
	s.anti_aliasing = true
	s.anti_aliasing_size = 1
	if sombra > 0.0:
		s.shadow_size = int(sombra)
		s.shadow_color = cor_sombra
	return s


func painel(pai: Node, pos: Vector2, tam: Vector2, estilo: StyleBox) -> Panel:
	var p = Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.rect_position = pos
	p.rect_size = tam
	p.add_stylebox_override("panel", estilo)
	if pai != null:
		pai.add_child(p)
	return p


## Rótulo pronto: texto, tamanho, cor, contorno (px) e alinhamento.
func rotulo(pai: Node, texto: String, tam: int, cor: Color = Color(1, 1, 1, 1), contorno: int = 0,
		forte: bool = true, alinhar: int = Label.ALIGN_CENTER, cor_contorno: Color = Color(0, 0, 0, 1)) -> Label:
	var l = Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = texto
	l.align = alinhar
	l.valign = Label.VALIGN_CENTER
	l.add_font_override("font", fonte(tam, forte, contorno, cor_contorno))
	l.add_color_override("font_color", cor)
	if pai != null:
		pai.add_child(l)
	return l


## Põe o rótulo numa caixa (posição e tamanho do jogo).
func colocar(c: Control, pos: Vector2, tam: Vector2) -> Control:
	c.rect_position = pos
	c.rect_size = tam
	c.rect_pivot_offset = tam * 0.5
	return c


## Número com ponto de milhar (12.345).
static func milhar(n: int) -> String:
	var s = str(int(abs(n)))
	var out = ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-" if n < 0 else "") + out
