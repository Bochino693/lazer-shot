extends Node2D

## TELA INICIAL: "TORNE-SE O MELHOR ATIRADOR" e LAZER SHOT no corredor do
## estande, APERTE START piscando e o selo JOGO LIVRE / CRÉDITOS embaixo.
##
## Sem vídeo (a TV Box Mali-450 engasga decodificando vídeo em pé): o fundo é a
## imagem parada que ganha vida (scripts/fundo_vivo.gd): o título, o alvo e o
## logo acendem na batida da música, as luzes do corredor piscam com o grave,
## brasas sobem do chão e uma faixa de brilho cruza a tela de tempos em tempos.
##
## Parada o tempo da abertura (configuração): a DEMONSTRAÇÃO (os 4 cenários
## passando) e depois o RANKING (se ligados); o ranking volta para cá.
## START: cobra no modo crédito e vai para a escolha de cenário.

const CENA_CENARIOS = "res://scenes/cenarios.tscn"
const CENA_RANKING = "res://scenes/ranking.tscn"
const DEMO = [
	["fundo_egito_sol", "DESERTO SAGRADO", "DE DIA, ACERTE O SOL. DE NOITE, A LUA.", Color(1.0, 0.74, 0.22)],
	["fundo_mar", "FUNDO DO MAR", "ACERTE OS TESOUROS. FUJA DAS BOMBAS.", Color(0.24, 0.72, 1.0)],
	["fundo_bar", "BAR DO FAROESTE", "QUEBRE AS GARRAFAS. NUNCA A VERDE.", Color(0.34, 0.95, 0.42)],
	["fundo_arena", "ARENA LAZER SHOT", "ACERTE AS LANTERNAS NA ORDEM DAS CORES.", Color(1.0, 0.24, 0.20)],
]

var _t = 0.0
var _saindo = false
var _parado = 0.0
var _tempo_intro = 40.0
var _tempo_demo = 20.0
var _demo_t = -1.0
var _demo_i = -1

var _fundo: FundoVivo
var _musica: AudioStreamPlayer

var _demo: Node2D
var _demo_fundos = []
var _demo_painel: Control
var _demo_nome: Label
var _demo_texto: Label
var _demo_linha: ColorRect

var _chamada: Label
var _tw_chamada: SceneTreeTween
var _flash: ColorRect


func _ready() -> void:
	MiraGlobal.ativa = false
	_tempo_intro = clamp(float(Maquina.valor("main/tempo_intro")), 5.0, 600.0)
	_tempo_demo = clamp(float(Maquina.valor("main/tempo_teaser")), 5.0, 120.0)
	_fundo = FundoVivo.new()
	add_child(_fundo)
	_fundo.mostrar("init")
	_montar_demo()
	_montar_tela()
	Maquina.connect("creditos_mudaram", self, "_creditos_mudaram")
	_musica = Maquina.musica(self, load("res://songs/audio_intro.mp3"), -3.0)
	# a chamada surge depois que a tela clareia
	_chamada.modulate.a = 0.0
	_chamada.rect_scale = Vector2(0.94, 0.94)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_chamada, "modulate:a", 1.0, 0.45).set_delay(0.3)
	tw.tween_property(_chamada, "rect_scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.3)
	tw.chain().tween_callback(self, "_piscar_chamada")


func _montar_demo() -> void:
	_demo = Node2D.new()
	_demo.visible = false
	add_child(_demo)
	for i in 2:
		var s = Sprite.new()
		s.centered = true
		s.position = Tela.TELA * 0.5
		s.modulate.a = 0.0
		_demo.add_child(s)
		_demo_fundos.append(s)
	var camada = CanvasLayer.new()
	camada.layer = 20
	add_child(camada)
	_demo_painel = Control.new()
	_demo_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_demo_painel.rect_size = Tela.TELA
	_demo_painel.visible = false
	camada.add_child(_demo_painel)
	var faixa = ColorRect.new()
	faixa.color = Color(0, 0, 0, 0.58)
	faixa.rect_position = Vector2(0, 1250)
	faixa.rect_size = Vector2(Tela.TELA.x, 230)
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_demo_painel.add_child(faixa)
	_demo_linha = ColorRect.new()
	_demo_linha.rect_position = Vector2(0, 1250)
	_demo_linha.rect_size = Vector2(Tela.TELA.x, 6)
	_demo_linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_demo_painel.add_child(_demo_linha)
	_demo_nome = Estilo.rotulo(_demo_painel, "", 92, Color.white, 10)
	Estilo.colocar(_demo_nome, Vector2(0, 1272), Vector2(Tela.TELA.x, 120))
	_demo_texto = Estilo.rotulo(_demo_painel, "", 36, Color(1, 1, 1, 0.92), 5)
	Estilo.colocar(_demo_texto, Vector2(0, 1392), Vector2(Tela.TELA.x, 60))


func _montar_tela() -> void:
	var camada = CanvasLayer.new()
	camada.layer = 30
	add_child(camada)
	_chamada = Estilo.rotulo(camada, Maquina.texto_chamada(), 38, Color.white, 6)
	Estilo.colocar(_chamada, Vector2(152, Tela.TELA.y - 137), Vector2(720, 90))
	_flash = ColorRect.new()
	_flash.rect_size = Tela.TELA
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.visible = false
	camada.add_child(_flash)


func _piscar_chamada() -> void:
	if _tw_chamada != null and _tw_chamada.is_valid():
		_tw_chamada.kill()
	_tw_chamada = create_tween().set_loops()
	_tw_chamada.tween_property(_chamada, "modulate:a", 0.35, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw_chamada.tween_property(_chamada, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _creditos_mudaram(_c) -> void:
	_chamada.text = Maquina.texto_chamada()


# ------------------------------------------------------------ quadro
func _process(delta: float) -> void:
	_t += delta
	if _saindo:
		return
	# parada: demonstração e ranking
	if _demo_t >= 0.0:
		_rodar_demo(delta)
		return
	_parado += delta
	if _parado >= _tempo_intro:
		_parado = 0.0
		if bool(Maquina.valor("main/demo_ativa")):
			_comecar_demo()
		else:
			_ir_ranking()


func _unhandled_input(ev: InputEvent) -> void:
	if _saindo:
		return
	if Maquina.e_start(ev):
		get_tree().set_input_as_handled()
		if Maquina.cobrar():
			_comecar()


func _comecar() -> void:
	_saindo = true
	Maquina.efeito(load("res://songs/init.wav"), 0.0)
	if _tw_chamada != null and _tw_chamada.is_valid():
		_tw_chamada.kill()
	_flash.visible = true
	_flash.color = Color(1, 1, 1, 0)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_chamada, "rect_scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_chamada, "modulate:a", 0.0, 0.18)
	tw.tween_property(_flash, "color:a", 0.95, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_flash, "color:a", 0.0, 0.2)
	tw.chain().tween_callback(self, "_ir", [CENA_CENARIOS])
	if _musica != null:
		var tm = create_tween()
		tm.tween_property(_musica, "volume_db", -40.0, 0.4)


func _ir(caminho: String) -> void:
	TransicaoGlobal.trocar_cena(caminho)


func _ir_ranking() -> void:
	if not bool(Maquina.valor("ranking/ranking_ativo")):
		return
	_saindo = true
	get_tree().set_meta("ranking_origem", "main_atrativo")
	_ir(CENA_RANKING)


# ------------------------------------------------------------ demonstração
## Os quatro cenários passando: cada fundo entra cruzando com o anterior,
## aproximando devagar, com o nome e a missão numa faixa embaixo.
func _comecar_demo() -> void:
	_demo_t = 0.0
	_demo_i = -1
	_demo.visible = true
	_demo_painel.visible = true
	_demo_painel.modulate.a = 1.0
	_proximo_demo()


func _proximo_demo() -> void:
	_demo_i += 1
	var d = DEMO[_demo_i % DEMO.size()]
	var novo: Sprite = _demo_fundos[_demo_i % 2]
	var velho: Sprite = _demo_fundos[(_demo_i + 1) % 2]
	novo.texture = Estilo.tex(d[0])
	novo.scale = Vector2.ONE * (Tela.TELA.x / novo.texture.get_width()) * 1.02
	novo.modulate.a = 0.0
	_demo.move_child(novo, _demo.get_child_count() - 1)
	var dur = _tempo_demo / DEMO.size()
	var tw = create_tween().set_parallel(true)
	tw.tween_property(novo, "modulate:a", 1.0, 0.8)
	tw.tween_property(novo, "scale", novo.scale * 1.08, dur + 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(velho, "modulate:a", 0.0, 0.8).set_delay(0.4)
	var c: Color = d[3]
	_demo_nome.text = d[1]
	_demo_nome.add_color_override("font_color", c.linear_interpolate(Color.white, 0.2))
	_demo_texto.text = d[2]
	_demo_linha.color = c
	_demo_nome.rect_position.x = Tela.TELA.x
	_demo_texto.modulate.a = 0.0
	var tl = create_tween()
	tl.tween_property(_demo_nome, "rect_position:x", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.3)
	tl.tween_property(_demo_texto, "modulate:a", 1.0, 0.3)


func _rodar_demo(delta: float) -> void:
	var antes = _demo_t
	_demo_t += delta
	var dur = _tempo_demo / DEMO.size()
	if int(_demo_t / dur) != int(antes / dur) and _demo_t < _tempo_demo:
		_proximo_demo()
	if _demo_t >= _tempo_demo:
		_demo_t = -1.0
		if bool(Maquina.valor("ranking/ranking_ativo")):
			_ir_ranking()
		else:
			_fim_demo()


func _fim_demo() -> void:
	var tw = create_tween().set_parallel(true)
	for s in _demo_fundos:
		tw.tween_property(s, "modulate:a", 0.0, 0.6)
	tw.tween_property(_demo_painel, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(self, "_demo_escondida")


func _demo_escondida() -> void:
	_demo.visible = false
	_demo_painel.visible = false
	for s in _demo_fundos:
		s.texture = null
	Estilo.soltar_texturas_grandes()
