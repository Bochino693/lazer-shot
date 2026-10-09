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
	# Botões da arma (lado direito): START perto do bico, RECARGA perto do
	# gatilho. Descritor: "mouse:N", "tecla:N", "voltar" (VOLTAR do Android)
	# ou "" (nenhum). Recarga "padrao" = clique direito/meio/laterais/voltar.
	"botoes/start_arma": "",
	"botoes/recarga_arma": "padrao",
	"jogo/tempo_partida": 120,
	"jogo/tempo_modal_final": 17,
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

const FONTE_PADRAO := "res://fonts/Exo2-Bold.ttf"


## Símbolos e emojis usados nos textos (🏆 ⚙ ★ ▶ 🥇...) que a Exo 2 não
## tem. A TV Box não tem fonte de emoji para o Godot usar,
## então eles apareciam quebrados; estas fontes pequenas (recortes da Noto)
## entram como reserva das fontes do jogo.
const FONTES_RESERVA := ["res://fonts/Simbolos.ttf", "res://fonts/SimbolosEmoji.ttf"]
const FONTES_DO_JOGO := [FONTE_PADRAO, "res://fonts/Exo2-ExtraBold.ttf"]


## Fonte padrão de todos os textos + reservas de símbolos. É posta aqui, e
## não em gui/theme/custom_font do projeto, porque o Godot lê essa opção ANTES
## de importar os arquivos: numa pasta nova (geração do APK) dava "Error
## loading custom project font". Precisa ser no _ready: no _init a fonte
## ainda é recarregada depois e as reservas se perdiam.
func _preparar_fontes() -> void:
	var reservas: Array[Font] = []
	for caminho in FONTES_RESERVA:
		if ResourceLoader.exists(caminho):
			reservas.append(load(caminho))
	for caminho in FONTES_DO_JOGO:
		if ResourceLoader.exists(caminho):
			var f := load(caminho) as FontFile
			if f != null:
				f.fallbacks = reservas
				# Sempre as nossas (igual no PC e na TV Box, que não tem
				# fonte de emoji que o Godot consiga usar).
				f.allow_system_fallback = false
				_fontes_guardadas.append(f)
	if ResourceLoader.exists(FONTE_PADRAO):
		var padrao: Font = load(FONTE_PADRAO)
		ThemeDB.get_default_theme().default_font = padrao
		ThemeDB.fallback_font = padrao


var _fontes_guardadas: Array[Font] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_preparar_fontes()
	# O botão lateral da arma é o "voltar" do mouse; no Android isso vira o
	# VOLTAR do sistema e o Godot fechava o jogo. Agora ele recarrega.
	get_tree().quit_on_go_back = false
	cfg.load(CONFIG)
	_migrar_config()
	_criar_barramentos_de_audio()
	_criar_rotulo()
	aplicar()
	get_tree().node_added.connect(_ao_entrar_no)


## Ajustes de versões antigas do arquivo de configuração.
func _migrar_config() -> void:
	# A volta ao menu depois do resultado passou de 21 s para 17 s (padrão de
	# todas as fases). Quem nunca mexeu nisso (21 = padrão antigo) vai para 17.
	if int(cfg.get_value("sistema", "versao_config", 0)) < 2:
		if cfg.has_section_key("jogo", "tempo_modal_final") and int(cfg.get_value("jogo", "tempo_modal_final")) == 21:
			cfg.set_value("jogo", "tempo_modal_final", 17)
		cfg.set_value("sistema", "versao_config", 2)
		cfg.save(CONFIG)


# ---------------------------------------------------------------- valores
func valor(chave: String) -> Variant:
	var p := chave.split("/")
	return cfg.get_value(p[0], p[1], PADRAO.get(chave))


func definir(chave: String, v: Variant) -> void:
	var p := chave.split("/")
	cfg.set_value(p[0], p[1], v)


func salvar() -> void:
	cfg.save(CONFIG)


## Segundos para a tela de resultado voltar sozinha ao início (sem START).
## Mesmo valor em todas as fases.
func tempo_volta_menu() -> float:
	return clampf(float(valor("jogo/tempo_modal_final")), 5.0, 120.0)


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
	_mapear_arma(ACAO_START, str(valor("botoes/start_arma")))
	_mapear_arma("input_recharge", str(valor("botoes/recarga_arma")))

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


# ---------------------------------------------------------------- arma
## Põe o botão aprendido da arma (clique ou tecla) na ação, sem mexer nos
## botões da Zero Delay. "voltar" e "padrao" são tratados à parte.
func _mapear_arma(acao: String, descritor: String) -> void:
	if not InputMap.has_action(acao):
		InputMap.add_action(acao, 0.2)
	for ev in InputMap.action_get_events(acao):
		if (ev is InputEventMouseButton or ev is InputEventKey) and ev.has_meta("da_arma"):
			InputMap.action_erase_event(acao, ev)
	var novo := evento_do_descritor(descritor)
	if novo != null:
		novo.set_meta("da_arma", true)
		InputMap.action_add_event(acao, novo)


static func descrever(ev: InputEvent) -> String:
	if ev is InputEventMouseButton:
		return "mouse:%d" % (ev as InputEventMouseButton).button_index
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return "tecla:%d" % (k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	if ev is InputEventJoypadButton:
		return "joy:%d" % (ev as InputEventJoypadButton).button_index
	return ""


static func evento_do_descritor(d: String) -> InputEvent:
	if d.begins_with("mouse:"):
		var m := InputEventMouseButton.new()
		m.button_index = int(d.substr(6)) as MouseButton
		m.pressed = true
		return m
	if d.begins_with("tecla:"):
		var k := InputEventKey.new()
		k.physical_keycode = int(d.substr(6)) as Key
		k.pressed = true
		return k
	return null


static func nome_do_descritor(d: String) -> String:
	if d == "" :
		return "NENHUM"
	if d == "padrao":
		return "PADRÃO"
	if d == "voltar":
		return "VOLTAR (ANDROID)"
	if d.begins_with("mouse:"):
		var n := int(d.substr(6))
		var nomes := {1: "ESQUERDO", 2: "DIREITO", 3: "MEIO", 8: "LATERAL 1", 9: "LATERAL 2"}
		return "MOUSE %s" % nomes.get(n, str(n))
	if d.begins_with("tecla:"):
		return "TECLA %s" % OS.get_keycode_string(int(d.substr(6))).to_upper()
	if d.begins_with("joy:"):
		return "BOTÃO %s" % d.substr(4)
	return d.to_upper()


## Clique da arma que atira (o gatilho é o clique esquerdo).
func e_tiro_arma(me: InputEventMouseButton) -> bool:
	if me.button_index != MOUSE_BUTTON_LEFT:
		return false
	var d := descrever(me)
	return d != str(valor("botoes/start_arma")) and d != str(valor("botoes/recarga_arma"))


## Clique da arma que recarrega: o aprendido, ou no padrão o direito, o do
## meio e os laterais (menos o que estiver como START da arma).
func e_recarga_arma(me: InputEventMouseButton) -> bool:
	var d := descrever(me)
	if d == str(valor("botoes/start_arma")):
		return false
	var r := str(valor("botoes/recarga_arma"))
	if r == "padrao":
		return me.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]
	return d == r


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


# ---------------------------------------------------------------- VOLTAR
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_voltar_vira_recarga()


var _ultimo_voltar := 0

func _voltar_vira_recarga() -> void:
	var agora := Time.get_ticks_msec()
	if agora - _ultimo_voltar < 120:
		return
	_ultimo_voltar = agora
	var acao := ""
	if str(valor("botoes/start_arma")) == "voltar":
		acao = ACAO_START
	elif str(valor("botoes/recarga_arma")) in ["padrao", "voltar"]:
		acao = "input_recharge"
	if acao == "" or not InputMap.has_action(acao) or _na_configuracao():
		return
	var aperta := InputEventAction.new()
	aperta.action = acao
	aperta.pressed = true
	Input.parse_input_event(aperta)
	var solta := InputEventAction.new()
	solta.action = acao
	solta.pressed = false
	Input.parse_input_event.call_deferred(solta)


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
	# Analisador de espectro na música: os fundos pulsam com o som.
	if AudioServer.get_bus_effect_count(_bus_musica) == 0:
		var analisador := AudioEffectSpectrumAnalyzer.new()
		analisador.buffer_length = 0.1
		analisador.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_512
		AudioServer.add_bus_effect(_bus_musica, analisador)


## Energia da música agora (0..1), já suavizada: `grave` acompanha o bumbo e
## o baixo, `batida` salta no começo de cada pancada e cai rápido. Para os
## fundos pulsarem com o som. Calculado uma vez por quadro.
var _som_quadro := -1
var _som_grave := 0.0
var _som_batida := 0.0
var _som_media := 0.0


func energia_musica() -> Vector2:
	var q := Engine.get_process_frames()
	if q == _som_quadro:
		return Vector2(_som_grave, _som_batida)
	_som_quadro = q
	var dt := get_process_delta_time()
	var bruto := 0.0
	if _bus_musica >= 0 and AudioServer.get_bus_effect_count(_bus_musica) > 0:
		var ef := AudioServer.get_bus_effect_instance(_bus_musica, 0) as AudioEffectSpectrumAnalyzerInstance
		if ef != null:
			var m := ef.get_magnitude_for_frequency_range(30.0, 160.0, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE)
			var db := linear_to_db(maxf(m.length(), 0.00001))
			bruto = clampf((db + 48.0) / 36.0, 0.0, 1.0)
	# sobe rápido, desce devagar
	var k := 1.0 - exp(-dt * (22.0 if bruto > _som_grave else 5.0))
	_som_grave = lerpf(_som_grave, bruto, k)
	# batida: quanto o grave passou da média recente
	_som_media = lerpf(_som_media, bruto, 1.0 - exp(-dt * 1.5))
	var pico := clampf((bruto - _som_media) * 3.0, 0.0, 1.0)
	_som_batida = maxf(pico, _som_batida - dt * 3.5)
	return Vector2(_som_grave, _som_batida)


## energia_musica() que nunca para: sem música (ou com o volume zerado) um
## pulso calmo, ~112 batidas por minuto, mantém os fundos vivos.
func pulso_vivo() -> Vector2:
	var e := energia_musica()
	var fase := fmod(float(Time.get_ticks_msec()) * 0.001 * 112.0 / 60.0, 1.0)
	var sint := maxf(0.0, 1.0 - fase * 3.0)
	sint *= sint
	var peso := 1.0 - clampf(e.x * 6.0, 0.0, 1.0)
	return Vector2(maxf(e.x, (0.16 + 0.12 * sint) * peso), maxf(e.y, sint * 0.5 * peso))


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
