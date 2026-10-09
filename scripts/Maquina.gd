extends Node

## A MÁQUINA: modo de jogo, créditos, botões e configurações.
##
## MODO LIVRE (padrão): o START começa a partida sem cobrar nada.
## MODO CRÉDITO: cada aperto do SELECT da Zero Delay (onde fica ligado o
## noteiro/moedeiro) soma 1 crédito; o START só começa se houver créditos
## suficientes e desconta os créditos da partida.
##
## As configurações ficam em user://config_admin.cfg e são lidas AQUI no
## boot (antes só valiam depois de abrir a tela de configuração).
## A tela de configuração abre com F10 ou segurando o SELECT por 3 s nas
## telas de abertura (inicial, ranking e escolha de cenário).

const CONFIG := "user://config_admin.cfg"
const CENA_CONFIG := "res://scenes/admin.tscn"
const ACAO_SELECT := "input_select"
const ACAO_START := "input_start"
const SEGURAR_SELECT_PARA_CONFIG := 3.0
const MAX_CREDITOS := 99
const SOM_FICHA := "res://songs/ficha.wav"

const CENAS_ABERTURA := [
	"res://scenes/main.tscn",
	"res://scenes/ranking.tscn",
	"res://scenes/cenarios.tscn",
]
## Onde o selo de créditos fica sempre à vista (nas outras telas ele só
## aparece por uns segundos quando entra ficha ou falta crédito).
const CENAS_SELO := ["res://scenes/main.tscn"]

## Valores padrão (e nomes das chaves no arquivo).
const PADRAO := {
	"maquina/modo": "livre",
	"maquina/creditos_por_partida": 1,
	"maquina/creditos": 0,
	"maquina/total_fichas": 0,
	"maquina/total_partidas": 0,
	"botoes/start": JOY_BUTTON_A,
	"botoes/select": JOY_BUTTON_BACK,
	"jogo/tempo_partida": 120,
	"jogo/tempo_modal_final": 21,
	"jogo/dificuldade_padrao": "facil",
	"ranking/tempo_nome": 50,
	"ranking/ranking_ativo": true,
	"main/tempo_intro": 40,
	"main/tempo_teaser": 20,
	"main/demo_ativa": true,
	"audio/volume_musica": -5.0,
	"audio/volume_fx": 0.0,
	"sistema/idioma": "pt_br",
}

signal creditos_mudaram(creditos: int)
signal sem_credito
signal config_mudou

var cfg := ConfigFile.new()

var _select_segurado := -1.0
var _ficha_do_select := false
var _salvar_em := -1.0

var _camada: CanvasLayer
var _caixa: PanelContainer
var _rotulo: Label
var _aviso_t := 0.0
var _som_ficha: AudioStreamPlayer
var _bus_musica := -1
var _bus_efeitos := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cfg.load(CONFIG)
	_criar_barramentos_de_audio()
	_criar_rotulo()
	aplicar()
	get_tree().node_added.connect(_ao_entrar_no)


# ---------------------------------------------------------------- valores
func valor(chave: String) -> Variant:
	var p := chave.split("/")
	return cfg.get_value(p[0], p[1], PADRAO.get(chave))


func definir(chave: String, v: Variant) -> void:
	var p := chave.split("/")
	cfg.set_value(p[0], p[1], v)


func salvar() -> void:
	cfg.save(CONFIG)


func restaurar_padrao() -> void:
	var guardar := {
		"maquina/total_fichas": valor("maquina/total_fichas"),
		"maquina/total_partidas": valor("maquina/total_partidas"),
		"maquina/creditos": valor("maquina/creditos"),
	}
	cfg = ConfigFile.new()
	for k in guardar:
		definir(k, guardar[k])


var modo: String:
	get:
		return str(valor("maquina/modo"))

var creditos: int:
	get:
		return int(valor("maquina/creditos"))

var creditos_por_partida: int:
	get:
		return maxi(1, int(valor("maquina/creditos_por_partida")))


func modo_credito() -> bool:
	return modo == "credito"


## Aplica tudo no jogo: metas lidas pelas cenas, botões e volumes.
func aplicar() -> void:
	var t := get_tree()
	t.set_meta("admin_tempo_partida", int(valor("jogo/tempo_partida")))
	t.set_meta("admin_tempo_modal_final", int(valor("jogo/tempo_modal_final")))
	t.set_meta("admin_tempo_ranking_nome", int(valor("ranking/tempo_nome")))
	t.set_meta("admin_tempo_intro_main", int(valor("main/tempo_intro")))
	t.set_meta("admin_tempo_teaser", int(valor("main/tempo_teaser")))
	t.set_meta("admin_volume_musica", float(valor("audio/volume_musica")))
	t.set_meta("admin_volume_fx", float(valor("audio/volume_fx")))
	t.set_meta("admin_demo_ativa", bool(valor("main/demo_ativa")))
	t.set_meta("admin_ranking_ativo", bool(valor("ranking/ranking_ativo")))
	t.set_meta("modo_dificuldade", str(valor("jogo/dificuldade_padrao")))
	t.set_meta("admin_idioma", str(valor("sistema/idioma")))

	_mapear_botao(ACAO_START, int(valor("botoes/start")))
	_mapear_botao(ACAO_SELECT, int(valor("botoes/select")))

	if _bus_musica >= 0:
		AudioServer.set_bus_volume_db(_bus_musica, float(valor("audio/volume_musica")))
	if _bus_efeitos >= 0:
		AudioServer.set_bus_volume_db(_bus_efeitos, float(valor("audio/volume_fx")))

	_atualizar_rotulo()
	config_mudou.emit()
	creditos_mudaram.emit(creditos)


## Troca o botão do controle de uma ação (mantém teclado e mouse).
func _mapear_botao(acao: String, botao: int) -> void:
	if not InputMap.has_action(acao):
		InputMap.add_action(acao, 0.2)
	for ev in InputMap.action_get_events(acao):
		if ev is InputEventJoypadButton:
			InputMap.action_erase_event(acao, ev)
	var novo := InputEventJoypadButton.new()
	novo.device = -1
	novo.button_index = botao as JoyButton
	novo.pressed = true
	InputMap.action_add_event(acao, novo)


# ---------------------------------------------------------------- créditos
## O START quer começar uma partida: no modo livre sempre pode; no modo
## crédito desconta os créditos da partida ou avisa que falta crédito.
func cobrar() -> bool:
	if not modo_credito():
		_contar_partida()
		return true
	if creditos >= creditos_por_partida:
		definir("maquina/creditos", creditos - creditos_por_partida)
		_contar_partida()
		_atualizar_rotulo()
		creditos_mudaram.emit(creditos)
		return true
	sem_credito.emit()
	_mostrar_aviso("INSIRA CRÉDITO", true)
	return false


func pode_jogar() -> bool:
	return not modo_credito() or creditos >= creditos_por_partida


## Texto da chamada nas telas de abertura.
func texto_chamada() -> String:
	return "APERTE START" if pode_jogar() else "INSIRA CRÉDITO"


func texto_jogar_novamente() -> String:
	return "APERTE START PARA JOGAR NOVAMENTE" if pode_jogar() else "INSIRA CRÉDITO PARA JOGAR NOVAMENTE"


func texto_creditos() -> String:
	if not modo_credito():
		return "JOGO LIVRE"
	var t := "CRÉDITOS %02d" % creditos
	if creditos_por_partida > 1:
		t += "   ·   %d POR PARTIDA" % creditos_por_partida
	return t


func somar_credito(qtd: int = 1, conta_ficha: bool = true) -> void:
	definir("maquina/creditos", clampi(creditos + qtd, 0, MAX_CREDITOS))
	if conta_ficha:
		definir("maquina/total_fichas", maxi(0, int(valor("maquina/total_fichas")) + qtd))
	_salvar_logo()
	_atualizar_rotulo()
	creditos_mudaram.emit(creditos)


func _contar_partida() -> void:
	definir("maquina/total_partidas", int(valor("maquina/total_partidas")) + 1)
	_salvar_logo()


## Junta várias gravações seguidas (fichas em sequência) numa só.
func _salvar_logo() -> void:
	_salvar_em = 0.6


# ---------------------------------------------------------------- SELECT
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_F10:
			abrir_configuracao()
			return
	if not InputMap.has_action(ACAO_SELECT):
		return
	if event.is_action_pressed(ACAO_SELECT, false):
		_select_segurado = 0.0
		_ficha_do_select = false
		if modo_credito() and not _na_configuracao():
			somar_credito(1)
			_ficha_do_select = true
			_tocar_ficha()
			_mostrar_aviso("+1 CRÉDITO", false)
	elif event.is_action_released(ACAO_SELECT):
		_select_segurado = -1.0


func _process(delta: float) -> void:
	if _salvar_em > 0.0:
		_salvar_em -= delta
		if _salvar_em <= 0.0:
			salvar()

	if _select_segurado >= 0.0:
		_select_segurado += delta
		if _select_segurado >= SEGURAR_SELECT_PARA_CONFIG:
			_select_segurado = -1.0
			if _na_abertura():
				# Segurou para abrir a configuração: a ficha não vale.
				if _ficha_do_select:
					somar_credito(-1, false)
					definir("maquina/total_fichas", maxi(0, int(valor("maquina/total_fichas")) - 1))
				abrir_configuracao()

	if _aviso_t > 0.0:
		_aviso_t -= delta
		if _aviso_t <= 0.0:
			_atualizar_rotulo()
	elif _caixa != null:
		var deve := _cena_atual() in CENAS_SELO
		if _caixa.visible != deve:
			_caixa.visible = deve


func abrir_configuracao() -> void:
	if _na_configuracao():
		return
	var tg := get_tree().root.get_node_or_null("TransicaoGlobal")
	if tg != null:
		tg.trocar_cena(CENA_CONFIG)
	else:
		get_tree().change_scene_to_file(CENA_CONFIG)


func _cena_atual() -> String:
	var c := get_tree().current_scene
	return c.scene_file_path if c != null else ""


func _na_abertura() -> bool:
	return _cena_atual() in CENAS_ABERTURA


func _na_configuracao() -> bool:
	return _cena_atual() == CENA_CONFIG


# ---------------------------------------------------------------- rótulo
func _criar_rotulo() -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 9000
	add_child(_camada)

	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada.add_child(raiz)

	_caixa = PanelContainer.new()
	_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caixa.anchor_left = 0.5
	_caixa.anchor_right = 0.5
	_caixa.anchor_top = 1.0
	_caixa.anchor_bottom = 1.0
	_caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caixa.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_caixa.offset_bottom = -14.0
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.0, 0.0, 0.0, 0.62)
	estilo.set_corner_radius_all(18)
	estilo.content_margin_left = 22
	estilo.content_margin_right = 22
	estilo.content_margin_top = 6
	estilo.content_margin_bottom = 6
	_caixa.add_theme_stylebox_override("panel", estilo)
	raiz.add_child(_caixa)

	_rotulo = Label.new()
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo.add_theme_font_size_override("font_size", 26)
	_rotulo.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_caixa.add_child(_rotulo)
	_caixa.visible = false

	_som_ficha = AudioStreamPlayer.new()
	if ResourceLoader.exists(SOM_FICHA):
		_som_ficha.stream = load(SOM_FICHA)
	add_child(_som_ficha)


func _atualizar_rotulo() -> void:
	if _rotulo == null:
		return
	_rotulo.text = texto_creditos()
	_rotulo.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3) if modo_credito() else Color(0.75, 1.0, 0.8))


func _mostrar_aviso(texto: String, alerta: bool) -> void:
	if _rotulo == null:
		return
	_rotulo.text = texto + ("" if alerta else "   ·   " + texto_creditos())
	_rotulo.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if alerta else Color(1.0, 0.9, 0.35))
	_caixa.visible = true
	_caixa.pivot_offset = _caixa.size * 0.5
	_caixa.scale = Vector2(1.15, 1.15)
	var tw := create_tween()
	tw.tween_property(_caixa, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_aviso_t = 2.5


func _tocar_ficha() -> void:
	if _som_ficha != null and _som_ficha.stream != null:
		_som_ficha.play()


# ---------------------------------------------------------------- áudio
## Música e efeitos em barramentos próprios para os volumes da configuração
## valerem no jogo inteiro (antes os volumes eram salvos mas não usados).
func _criar_barramentos_de_audio() -> void:
	_bus_musica = _bus("Musica")
	_bus_efeitos = _bus("Efeitos")


func _bus(nome: String) -> int:
	var i := AudioServer.get_bus_index(nome)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, nome)
		AudioServer.set_bus_send(i, "Master")
	return i


func _ao_entrar_no(no: Node) -> void:
	if no is AudioStreamPlayer or no is AudioStreamPlayer2D:
		_classificar_audio.call_deferred(no)


func _classificar_audio(no: Node) -> void:
	if not is_instance_valid(no) or no == _som_ficha:
		return
	var bus: String = no.get("bus")
	if bus != "Master" and bus != "":
		return
	var s: AudioStream = no.get("stream")
	var musica := false
	if s != null:
		musica = s.get_length() > 20.0
	else:
		var n := String(no.name).to_lower()
		musica = n.contains("music") or n.contains("theme") or n.contains("song")
	no.set("bus", "Musica" if musica else "Efeitos")
