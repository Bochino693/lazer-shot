extends CanvasLayer

## PÁGINA DE QUEDA (só na TV Box): o app fechou sozinho na última vez
## (scripts/caixa_preta.gd decide). Antes de qualquer outra coisa, mostra o
## começo (versão, aparelho, placa, memória) e o fim da caixa-preta daquela
## sessão, para uma foto: a última linha diz onde o jogo estava.
##
## Feita do jeito mais simples que a placa conhece: um retângulo de cor e
## textos com a fonte embutida do Godot (letras desenhadas na hora, sem
## MSDF). Nada da apresentação é desenhado enquanto ela está na tela.
##
## Fecha com um tiro, START ou sozinha em TEMPO s; aí o jogo segue (a
## apresentação começa, ou o menu, se ela foi contornada).

signal fechou

const TEMPO := 30.0
const ESPERA_TIRO := 3.0   # s antes de aceitar o tiro: dá para ver a página
const MARGEM := 28.0

var _t := 0.0
var _fonte: Font
var _rodape: Label
var _fechada := false


## `fonte`: a fonte embutida do Godot, pega antes de o jogo trocar a fonte
## padrão pela dele (scripts/Maquina.gd).
func montar(fonte: Font, versao: String, cabecalho: PackedStringArray, fim: PackedStringArray, duracao: float, contornos: PackedStringArray) -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fonte = fonte
	var tela := Tela.tamanho()
	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.03, 0.05, 1.0)
	fundo.position = Vector2.ZERO
	fundo.size = tela
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	var caixa := VBoxContainer.new()
	caixa.position = Vector2(MARGEM, MARGEM)
	caixa.size = Vector2(tela.x - MARGEM * 2.0, tela.y - MARGEM * 2.0)
	caixa.add_theme_constant_override("separation", 10)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caixa)

	var titulo := _texto(caixa, 34, Color(1.0, 0.8, 0.25))
	titulo.text = "O LAZER SHOT FECHOU SOZINHO NA ÚLTIMA VEZ"
	var pedido := _texto(caixa, 24, Color(1, 1, 1))
	pedido.text = "Tire uma foto desta tela inteira e mande para o suporte.\nEla mostra onde o jogo parou."
	var info := _texto(caixa, 19, Color(0.75, 0.85, 1.0))
	var linhas := PackedStringArray()
	linhas.append("Agora: Lazer Shot %s  |  a sessão anterior parou sozinha aos %.0f s" % [versao, duracao])
	if not contornos.is_empty():
		linhas.append("Contornando nesta versão: " + ", ".join(contornos))
	info.text = "\n".join(linhas)
	var comeco := _texto(caixa, 18, Color(0.7, 0.7, 0.7))
	comeco.text = "\n".join(cabecalho)
	var corpo := _texto(caixa, 19, Color(0.92, 0.95, 0.92))
	corpo.text = "...\n" + "\n".join(fim)
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rodape = _texto(caixa, 24, Color(1.0, 0.8, 0.25))
	_rodape.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_atualizar_rodape()
	Tela.marca("página de queda na tela (%d linhas da sessão anterior)" % fim.size())


func _texto(onde: Control, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _fonte)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	onde.add_child(l)
	return l


func _atualizar_rodape() -> void:
	var falta := maxi(0, ceili(TEMPO - _t))
	_rodape.text = "Atire ou aperte START para continuar (fecha sozinha em %d s)" % falta


func _process(delta: float) -> void:
	var antes := ceili(TEMPO - _t)
	_t += delta
	if ceili(TEMPO - _t) != antes:
		_atualizar_rodape()
	if _t >= TEMPO:
		_fechar("tempo")


func _input(event: InputEvent) -> void:
	if _fechada or _t < ESPERA_TIRO:
		return
	var aperto := event.is_action_pressed("input_shot") or event.is_action_pressed("input_start")
	if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
			or (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo) \
			or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed):
		aperto = true
	if aperto:
		get_viewport().set_input_as_handled()
		_fechar("tiro")


func _fechar(por: String) -> void:
	if _fechada:
		return
	_fechada = true
	Tela.marca("página de queda fechada (%s, %.0f s)" % [por, _t])
	queue_free()
	fechou.emit()
