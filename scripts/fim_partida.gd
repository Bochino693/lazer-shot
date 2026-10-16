class_name FimPartida
extends CanvasLayer

## FIM DE PARTIDA, igual nas quatro fases.
##
## - Botão grande VOLTAR AOS CENÁRIOS no modal de resultado: a mira passa em
##   cima e um tiro leva para a escolha de cenário.
## - A contagem do resultado, quando acaba, volta para a ABERTURA (a
##   apresentação Lazer & Sport e depois o vídeo da abertura).
## - JOGAR DE NOVO (START) recomeça a fase recarregando a tela inteira
##   (passando antes pela foto da webcam, scripts/pose.gd):
##   nada da partida anterior continua rodando por baixo. Antes a fase se
##   "zerava" por dentro, e apertar START várias vezes deixava partidas e
##   laços duplicados rodando juntos (o jogo travava e podia fechar).
##
## Na fase:
##   FimPartida.instalar(self, cor, func() -> bool: return fim_ativo and not ranking_nome_ativo, 150)
##   FimPartida.voltar_a_abertura()     (contagem esgotada)
##   FimPartida.jogar_de_novo(self)     (START no resultado)

const CENA_CENARIOS := "res://scenes/cenarios.tscn"
const CENA_ABERTURA := "res://scenes/abertura_ls.tscn"
const ESPERA_START := 0.8
const FONTE := preload("res://fonts/Exo2-ExtraBold.ttf")
const FONTE_TXT := preload("res://fonts/Exo2-Bold.ttf")

var _visivel: Callable
var _cor := Color(1, 0.2, 0.2)
var _raiz: Control
var _botao: Panel
var _texto: Label
var _dica: Label
var _estilo: StyleBoxFlat
var _estilo_mira: StyleBoxFlat
var _sob := false
var _t := 0.0
var _conferir := 0


static func instalar(fase: Node, cor: Color, visivel: Callable, camada: int = 150) -> FimPartida:
	var f := FimPartida.new()
	f.name = "FimPartida"
	f.layer = camada
	f._cor = cor
	f._visivel = visivel
	fase.add_child(f)
	return f


## Volta para a escolha de cenário (botão do resultado).
static func voltar_aos_cenarios() -> void:
	var tg: Node = Engine.get_main_loop().root.get_node_or_null("TransicaoGlobal")
	if tg == null or tg.em_transicao:
		return
	tg.trocar_cena(CENA_CENARIOS)


## A contagem do resultado acabou: volta para a abertura.
static func voltar_a_abertura() -> void:
	var tg: Node = Engine.get_main_loop().root.get_node_or_null("TransicaoGlobal")
	if tg == null or tg.em_transicao:
		return
	tg.trocar_cena(CENA_ABERTURA)


## START no resultado: cobra o crédito (se a máquina estiver em modo crédito)
## e recarrega a fase do zero. Apertar várias vezes não faz nada a mais.
static func jogar_de_novo(fase: Node) -> void:
	var tg: Node = Engine.get_main_loop().root.get_node_or_null("TransicaoGlobal")
	if tg == null or tg.em_transicao or fase == null or fase.scene_file_path == "":
		return
	if fase.has_meta("_jogar_de_novo"):
		return
	# o resultado precisa estar na tela há um instante: o START que confirma o
	# nome do recorde (ou um START repetido) não recomeça a partida sem querer
	var fp := fase.get_node_or_null("FimPartida") as FimPartida
	if fp != null and fp._t < ESPERA_START:
		return
	if not Maquina.cobrar():
		return
	fase.set_meta("_jogar_de_novo", true)
	# a partida nova também começa com a foto (scripts/pose.gd)
	Pose.ir(fase.scene_file_path)


func _ready() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	_estilo = StyleBoxFlat.new()
	_estilo.bg_color = Color(0.02, 0.02, 0.03, 0.92)
	_estilo.border_color = Color(1, 1, 1, 0.85)
	_estilo.set_border_width_all(4)
	_estilo.set_corner_radius_all(34)
	_estilo.shadow_color = Color(_cor.r, _cor.g, _cor.b, 0.35)
	_estilo.shadow_size = 18
	_estilo.anti_aliasing = true
	_estilo_mira = _estilo.duplicate() as StyleBoxFlat
	_estilo_mira.bg_color = Color(_cor.r * 0.45, _cor.g * 0.45, _cor.b * 0.45, 0.96)
	_estilo_mira.border_color = Color.WHITE
	_estilo_mira.shadow_color = Color(_cor.r, _cor.g, _cor.b, 0.75)
	_estilo_mira.shadow_size = 30

	_botao = Panel.new()
	_botao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_botao.add_theme_stylebox_override("panel", _estilo)
	_raiz.add_child(_botao)

	_texto = Label.new()
	_texto.text = "VOLTAR AOS CENÁRIOS"
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto.add_theme_font_override("font", FONTE)
	_texto.add_theme_color_override("font_color", Color.WHITE)
	_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_botao.add_child(_texto)

	_dica = Label.new()
	_dica.text = "RANKING: SÓ ACIMA DE 4.000 PONTOS"
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dica.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dica.add_theme_font_override("font", FONTE_TXT)
	_dica.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	_dica.add_theme_color_override("font_outline_color", Color.BLACK)
	_raiz.add_child(_dica)

	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	visible = false


func _ajustar() -> void:
	var tela := get_viewport().get_visible_rect().size
	var s := tela.x / 1024.0
	_raiz.size = tela
	_botao.size = Vector2(700, 124) * s
	_botao.position = Vector2((tela.x - _botao.size.x) * 0.5, tela.y - 250.0 * s)
	_botao.pivot_offset = _botao.size * 0.5
	_texto.position = Vector2.ZERO
	_texto.size = _botao.size
	_texto.add_theme_font_size_override("font_size", int(50 * s))
	_texto.add_theme_constant_override("outline_size", int(10 * s))
	_dica.position = Vector2(0, _botao.position.y + _botao.size.y + 14.0 * s)
	_dica.size = Vector2(tela.x, 44.0 * s)
	_dica.add_theme_font_size_override("font_size", int(30 * s))
	_dica.add_theme_constant_override("outline_size", int(7 * s))


func _process(delta: float) -> void:
	# escondido (durante a partida) só confere a cada 4 quadros se já é hora
	# de aparecer: na TV Box cada quadro de processador conta
	_conferir += 1
	if not visible and _conferir % 4 != 0:
		return
	var tg: Node = get_tree().root.get_node_or_null("TransicaoGlobal")
	var v: bool = _visivel.is_valid() and bool(_visivel.call()) and not (tg != null and tg.em_transicao)
	if visible != v:
		visible = v
		_t = 0.0
	if not v:
		return
	_t += delta
	var sob := _botao.get_global_rect().grow(12.0).has_point(MiraGlobal.pos)
	if sob != _sob:
		_sob = sob
		_botao.add_theme_stylebox_override("panel", _estilo_mira if sob else _estilo)
	_botao.scale = Vector2.ONE * ((1.07 if _sob else 1.0) + 0.015 * sin(_t * 4.0))


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var tiro := event.is_action_pressed("input_shot", false)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		tiro = tiro or (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT)
	if not tiro:
		return
	if _botao.get_global_rect().grow(12.0).has_point(MiraGlobal.pos):
		get_viewport().set_input_as_handled()
		voltar_aos_cenarios()
