extends CanvasLayer

## TROCA DE TELA sem tela cinza nem tranco: escurece, troca, clareia.
##
## Para as fases, um cartão de carregamento com a capa, o nome e uma dica
## aparece no escuro enquanto a fase monta (na TV Box a fase carrega o fundo
## e as folhas dos alvos: ~1 s). As imagens grandes da tela que saiu são
## soltas antes de a nova carregar (a memória da TV Box de 1 GB não junta as
## duas).

const FASES = {
	"res://scenes/deserto.tscn": {
		"nome": "DESERTO SAGRADO", "capa": "capa_desert", "cor": Color(1.0, 0.74, 0.22),
		"dica": "ACERTE SÓ O BRASÃO DO MODO ATUAL: SOL OU LUA",
	},
	"res://scenes/mar.tscn": {
		"nome": "FUNDO DO MAR", "capa": "capa_mar", "cor": Color(0.24, 0.72, 1.0),
		"dica": "CUIDADO: 3 BOMBAS ENCERRAM A PARTIDA",
	},
	"res://scenes/bar.tscn": {
		"nome": "BAR DO FAROESTE", "capa": "capa_bar", "cor": Color(0.34, 0.95, 0.42),
		"dica": "QUEBRE GARRAFAS EM SEGUIDA PARA FAZER COMBOS",
	},
	"res://scenes/arena.tscn": {
		"nome": "ARENA LAZER SHOT", "capa": "capa_arena", "cor": Color(1.0, 0.24, 0.20),
		"dica": "OBSERVE A SEQUÊNCIA E REPITA NA MESMA ORDEM",
	},
}

signal cena_trocada(caminho)

var em_transicao = false

var _preto: ColorRect
var _cartao: Control
var _capa: TextureRect
var _nome: Label
var _dica: Label
var _faixa: ColorRect
var _anel: Node2D
var _anel_t = 0.0
var _anel_cor = Color.white


func _ready() -> void:
	layer = 1000
	pause_mode = Node.PAUSE_MODE_PROCESS
	_preto = ColorRect.new()
	_preto.color = Color(0, 0, 0, 1)
	_preto.rect_size = Tela.TELA
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preto.modulate.a = 0.0
	_preto.visible = false
	add_child(_preto)
	_montar_cartao()
	set_process(false)


func _montar_cartao() -> void:
	_cartao = Control.new()
	_cartao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao.rect_size = Tela.TELA
	_cartao.visible = false
	add_child(_cartao)
	_capa = TextureRect.new()
	_capa.expand = true
	_capa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_capa.rect_position = Vector2(0, 560)
	_capa.rect_size = Vector2(1024, 400)
	_capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao.add_child(_capa)
	_faixa = ColorRect.new()
	_faixa.rect_position = Vector2(0, 956)
	_faixa.rect_size = Vector2(1024, 6)
	_cartao.add_child(_faixa)
	_nome = Estilo.rotulo(_cartao, "", 76, Color.white, 6)
	Estilo.colocar(_nome, Vector2(0, 990), Vector2(1024, 100))
	_dica = Estilo.rotulo(_cartao, "", 32, Color(1, 1, 1, 0.85), 3, false)
	_dica.autowrap = true
	Estilo.colocar(_dica, Vector2(80, 1090), Vector2(864, 110))
	_anel = Node2D.new()
	_anel.position = Vector2(512, 1330)
	_anel.connect("draw", self, "_desenhar_anel")
	_cartao.add_child(_anel)


func _desenhar_anel() -> void:
	var ini = _anel_t * 5.0
	_anel.draw_arc(Vector2.ZERO, 44.0, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 8.0, true)
	_anel.draw_arc(Vector2.ZERO, 44.0, ini, ini + 1.9, 24, _anel_cor, 8.0, true)


func _process(delta: float) -> void:
	_anel_t += delta
	if _cartao.visible:
		_anel.update()


## Escurece, troca para `caminho` e clareia. Nas fases mostra o cartão.
func trocar_cena(caminho: String, escurecer: float = 0.22) -> void:
	if em_transicao:
		return
	em_transicao = true
	set_process(true)
	_preto.visible = true
	if escurecer > 0.0:
		var tw = create_tween()
		tw.tween_property(_preto, "modulate:a", 1.0, escurecer)
		yield(tw, "finished")
	else:
		_preto.modulate.a = 1.0
	var fase: Dictionary = FASES.get(caminho, {})
	if not fase.empty():
		_capa.texture = Estilo.tex(fase["capa"])
		_nome.text = fase["nome"]
		_nome.add_color_override("font_color", fase["cor"].linear_interpolate(Color.white, 0.25))
		_dica.text = fase["dica"]
		_faixa.color = fase["cor"]
		_anel_cor = fase["cor"]
		_cartao.modulate.a = 0.0
		_cartao.visible = true
		var tw2 = create_tween()
		tw2.tween_property(_cartao, "modulate:a", 1.0, 0.18)
		yield(tw2, "finished")
	# dois quadros com o escuro (ou o cartão) na tela antes de carregar
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	Estilo.soltar_texturas_grandes()
	Estilo.soltar_fontes()
	Maquina.soltar_efeitos()
	var inicio = OS.get_ticks_msec()
	var erro = get_tree().change_scene(caminho)
	if erro != OK:
		Tela.marca("ERRO ao abrir %s (%d)" % [caminho, erro])
		get_tree().change_scene("res://scenes/menu.tscn")
	# a tela nova monta no próximo quadro; mais dois para assentar
	for i in 3:
		yield(get_tree(), "idle_frame")
	Tela.marca("tela %s pronta em %d ms (memória %d MB)" % [caminho.get_file(), OS.get_ticks_msec() - inicio, int(Tela.memoria_mb())])
	# o cartão fica pelo menos um instante (dá tempo de ler o nome da fase)
	if _cartao.visible:
		var falta = 0.9 - (OS.get_ticks_msec() - inicio) / 1000.0
		if falta > 0.0:
			yield(get_tree().create_timer(falta), "timeout")
	emit_signal("cena_trocada", caminho)
	var tw3 = create_tween().set_parallel(true)
	tw3.tween_property(_preto, "modulate:a", 0.0, 0.3)
	if _cartao.visible:
		tw3.tween_property(_cartao, "modulate:a", 0.0, 0.25)
	yield(tw3, "finished")
	_preto.visible = false
	_cartao.visible = false
	_capa.texture = null
	em_transicao = false
	set_process(false)
