extends Node

## A MÁQUINA: modo de jogo, créditos, botões, sons e configurações.
##
## MODO LIVRE (padrão): o START começa a partida sem cobrar nada.
## MODO CRÉDITO: cada aperto do SELECT da Zero Delay (onde fica ligado o
## noteiro/moedeiro) soma 1 crédito; o START só começa se houver créditos
## suficientes e desconta os créditos da partida.
##
## As configurações ficam em user://config_admin.cfg (o mesmo arquivo e as
## mesmas chaves da versão 4.6). A tela de configuração abre com F10 ou
## segurando o SELECT por 3 s nas telas de abertura (inicial, ranking e
## escolha de cenário).
##
## Botões da Zero Delay no Android (Godot 3.6 e 4.6 numeram igual):
## START = 0, RECARGA = 1, TIRO = 2, SELECT = 4. O gatilho da arma é o
## clique esquerdo do mouse. Sem nada aprendido: a RECARGA é o clique
## direito e o START são os outros botões do lado (o do meio, os laterais e o
## VOLTAR do Android); o da recarga nunca dá START. Na partida qualquer botão
## do lado recarrega. START e RECARGA da arma também se aprendem na
## CONFIGURAÇÃO.

const CONFIG = "user://config_admin.cfg"
const CENA_CONFIG = "res://scenes/config.tscn"
const ACAO_SELECT = "input_select"
const ACAO_START = "input_start"
const SEGURAR_SELECT_PARA_CONFIG = 3.0
const MAX_CREDITOS = 99

const CENAS_ABERTURA = ["res://scenes/menu.tscn", "res://scenes/ranking.tscn", "res://scenes/cenarios.tscn"]
## Onde o selo de créditos fica sempre à vista.
const CENAS_SELO = ["res://scenes/menu.tscn"]

const PADRAO = {
	"maquina/modo": "livre",
	"maquina/creditos_por_partida": 1,
	"maquina/creditos": 0,
	"maquina/total_fichas": 0,
	"maquina/total_partidas": 0,
	"botoes/start": 0,
	"botoes/select": 4,
	# Botões da arma: "mouse:N", "tecla:N", "voltar" (VOLTAR do Android) ou
	# "padrao": RECARGA no clique direito; START nos outros botões do lado
	# direito (o do meio, os laterais e o VOLTAR do Android).
	"botoes/start_arma": "padrao",
	"botoes/recarga_arma": "padrao",
	# ARMA E MIRA: "auto" (a mira é a seta quando o Android gira a tela; soma
	# o movimento quando o jogo gira por dentro), "absoluta" (sempre na seta)
	# ou "giroscopio" (sempre pelo movimento).
	# Sensibilidade do giroscópio: 0 = AUTO (a seta de borda a borda cobre a
	# altura do jogo); outro valor multiplica o movimento (calibrável).
	# Aceleração: desfaz a aceleração que o Android põe no ponteiro.
	"arma/modo": "auto",
	"arma/sensibilidade": 0.0,
	"arma/compensar_aceleracao": true,
	# A calibragem da seta (CONFIGURAÇÃO -> CALIBRAR): [escala x, escala y,
	# deslocamento x, deslocamento y]; vazia = sem calibragem. E o alvo de
	# partida no COMO JOGAR, que recoloca a mira a cada partida.
	"arma/calib": [],
	"arma/alvo_partida": true,
	# A FOTO DO JOGADOR (webcam USB da TV Box): ligada, qual câmera, giro
	# (0, 90, 180, 270) e espelho (scripts/foto_jogador.gd)
	"camera/foto": true,
	"camera/indice": -1,           # -1 = AUTO (a primeira que abrir, da última para a primeira)
	"camera/girar": 0,
	"camera/espelhar": false,
	"jogo/tempo_partida": 120,
	"jogo/tempo_modal_final": 17,
	"ranking/tempo_nome": 50,
	"ranking/ranking_ativo": true,
	"main/tempo_intro": 40,
	"main/tempo_teaser": 20,
	"main/demo_ativa": true,
	# EFEITOS: "completo" (padrão) ou "leve" (menos partículas, sem luz
	# girando): para a TV Box mais fraca de todas.
	"video/efeitos": "completo",
	# o vídeo do corredor na tela inicial e no ranking (some sozinho se pesar)
	"video/video_inicial": true,
	# GIRO DA TELA na TV Box: "auto" (o do project.godot), 1 (topo do jogo na
	# esquerda do HDMI), -1 (na direita) ou 0 (monitor já em pé)
	"tela/giro": "auto",
	# QUEM GIRA: "auto" (o do project.godot), "android" (o app pede a tela em
	# pé e a seta anda com a arma) ou "jogo" (o jogo gira por dentro)
	"tela/rotacao": "auto",
	"audio/volume_musica": -5.0,
	"audio/volume_fx": 0.0,
}

signal creditos_mudaram(creditos)
signal sem_credito
signal config_mudou

var cfg = ConfigFile.new()

var _select_segurado = -1.0
var _ficha_do_select = false
var _salvar_em = -1.0

var _camada: CanvasLayer
var _caixa: Panel
var _rotulo: Label
var _aviso_t = 0.0
var _bus_musica = -1
var _bus_efeitos = -1


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	# O botão lateral da arma é o "voltar" do mouse; no Android isso vira o
	# VOLTAR do sistema: aqui ele recarrega ou dá START (nunca fecha o jogo).
	get_tree().set_quit_on_go_back(false)
	cfg.load(CONFIG)
	# até a 2.0.2 o START da arma vinha vazio ("nenhum"): agora o padrão é o
	# botão do lado direito
	if str(cfg.get_value("botoes", "start_arma", "padrao")) == "":
		cfg.set_value("botoes", "start_arma", "padrao")
	_criar_barramentos_de_audio()
	_criar_rotulo()
	aplicar()


# ---------------------------------------------------------------- valores
func valor(chave: String):
	var p = chave.split("/")
	return cfg.get_value(p[0], p[1], PADRAO.get(chave))


func definir(chave: String, v) -> void:
	var p = chave.split("/")
	cfg.set_value(p[0], p[1], v)


func salvar() -> void:
	cfg.save(CONFIG)


func tempo_partida() -> float:
	return clamp(float(valor("jogo/tempo_partida")), 30.0, 600.0)


## Segundos para a tela de resultado voltar sozinha ao início (sem START).
func tempo_volta_menu() -> float:
	return clamp(float(valor("jogo/tempo_modal_final")), 5.0, 120.0)


func efeitos_leves() -> bool:
	return str(valor("video/efeitos")) == "leve"


## Quantidade de partículas e cacos (1 = completo; a TV Box mais fraca usa
## metade). Na tela que o ritmo automático já achou pesada nesta TV Box
## (MiraGlobal), os estilhaços dos tiros também saem menos: tiro atrás de
## tiro sem tranco.
func fator_efeitos() -> float:
	if efeitos_leves():
		return 0.5
	var cena = get_tree().current_scene
	if cena != null and MiraGlobal.tela_pesada(cena.filename):
		return 0.65
	return 1.0


func restaurar_padrao() -> void:
	var guardar = {
		"maquina/total_fichas": valor("maquina/total_fichas"),
		"maquina/total_partidas": valor("maquina/total_partidas"),
		"maquina/creditos": valor("maquina/creditos"),
	}
	cfg = ConfigFile.new()
	for k in guardar:
		definir(k, guardar[k])


func modo() -> String:
	return str(valor("maquina/modo"))


func creditos() -> int:
	return int(valor("maquina/creditos"))


func creditos_por_partida() -> int:
	return int(max(1, int(valor("maquina/creditos_por_partida"))))


func modo_credito() -> bool:
	return modo() == "credito"


## Aplica a configuração no jogo inteiro (botões, volumes, selo).
func aplicar() -> void:
	_mapear_botao(ACAO_START, int(valor("botoes/start")))
	_mapear_botao(ACAO_SELECT, int(valor("botoes/select")))
	_mapear_arma(ACAO_START, str(valor("botoes/start_arma")))
	_mapear_arma("input_recharge", str(valor("botoes/recarga_arma")))
	if _bus_musica >= 0:
		AudioServer.set_bus_volume_db(_bus_musica, float(valor("audio/volume_musica")))
	if _bus_efeitos >= 0:
		AudioServer.set_bus_volume_db(_bus_efeitos, float(valor("audio/volume_fx")))
	_atualizar_rotulo()
	emit_signal("config_mudou")
	emit_signal("creditos_mudaram", creditos())


## Troca o botão do controle de uma ação (mantém teclado e mouse).
func _mapear_botao(acao: String, botao: int) -> void:
	if not InputMap.has_action(acao):
		InputMap.add_action(acao, 0.2)
	for ev in InputMap.get_action_list(acao):
		if ev is InputEventJoypadButton:
			InputMap.action_erase_event(acao, ev)
	var novo = InputEventJoypadButton.new()
	novo.device = -1
	novo.button_index = botao
	novo.pressed = true
	InputMap.action_add_event(acao, novo)


# ---------------------------------------------------------------- arma
## Põe o botão aprendido da arma (clique ou tecla) na ação, sem mexer nos
## botões da Zero Delay. "voltar" e "padrao" são tratados à parte.
func _mapear_arma(acao: String, descritor: String) -> void:
	if not InputMap.has_action(acao):
		InputMap.add_action(acao, 0.2)
	for ev in InputMap.get_action_list(acao):
		if (ev is InputEventMouseButton or ev is InputEventKey) and ev.has_meta("da_arma"):
			InputMap.action_erase_event(acao, ev)
	var novo = evento_do_descritor(descritor)
	if novo != null:
		novo.set_meta("da_arma", true)
		InputMap.action_add_event(acao, novo)


static func descrever(ev: InputEvent) -> String:
	if ev is InputEventMouseButton:
		return "mouse:%d" % ev.button_index
	if ev is InputEventKey:
		return "tecla:%d" % (ev.physical_scancode if ev.physical_scancode != 0 else ev.scancode)
	if ev is InputEventJoypadButton:
		return "joy:%d" % ev.button_index
	return ""


static func evento_do_descritor(d: String):
	if d.begins_with("mouse:"):
		var m = InputEventMouseButton.new()
		m.button_index = int(d.substr(6))
		m.pressed = true
		return m
	if d.begins_with("tecla:"):
		var k = InputEventKey.new()
		k.physical_scancode = int(d.substr(6))
		k.pressed = true
		return k
	return null


static func nome_do_descritor(d: String) -> String:
	if d == "":
		return "NENHUM"
	if d == "padrao":
		return "PADRÃO"
	if d == "voltar":
		return "VOLTAR (ANDROID)"
	if d.begins_with("mouse:"):
		var n = int(d.substr(6))
		var nomes = {1: "ESQUERDO", 2: "DIREITO", 3: "MEIO", 8: "LATERAL 1", 9: "LATERAL 2"}
		return "MOUSE %s" % nomes.get(n, str(n))
	if d.begins_with("tecla:"):
		return "TECLA %s" % OS.get_scancode_string(int(d.substr(6))).to_upper()
	if d.begins_with("joy:"):
		return "BOTÃO %s" % d.substr(4)
	return d.to_upper()


## Clique da arma que atira (o gatilho é o clique esquerdo).
func e_tiro_arma(ev: InputEvent) -> bool:
	if not (ev is InputEventMouseButton) or not ev.pressed or ev.button_index != BUTTON_LEFT:
		return false
	var d = descrever(ev)
	return d != str(valor("botoes/start_arma")) and d != str(valor("botoes/recarga_arma"))


## Os botões do lado direito da arma (tudo o que não é o gatilho nem a
## rodinha).
static func e_botao_lateral(ev: InputEvent) -> bool:
	return ev is InputEventMouseButton and ev.pressed and \
		ev.button_index in [BUTTON_RIGHT, BUTTON_MIDDLE, BUTTON_XBUTTON1, BUTTON_XBUTTON2]


## A partida está correndo (contagem ou jogo): os botões do lado direito da
## arma recarregam. Fora dela (abertura, menus, como jogar, resultado), dão
## START.
func em_partida() -> bool:
	var cena = get_tree().current_scene
	if cena == null or not cena.has_method("recarregar"):
		return false
	var e = cena.get("estado")
	return e != null and int(e) in [1, 2]     # fase.gd: CONTAGEM, JOGO


## O botão da RECARGA: o aprendido ou, no padrão, o clique direito. Durante
## a partida qualquer botão do lado recarrega (menos o START aprendido):
## ninguém fica sem bala por apertar o botão vizinho.
func e_recarga_arma(ev: InputEvent) -> bool:
	if not (ev is InputEventMouseButton) or not ev.pressed:
		return false
	var d = descrever(ev)
	if d == str(valor("botoes/start_arma")):
		return false
	if e_botao_recarga(ev):
		return true
	return e_botao_lateral(ev) and em_partida()


## É o botão da recarga (o aprendido ou, no padrão, o clique direito)?
func e_botao_recarga(ev: InputEvent) -> bool:
	var r = str(valor("botoes/recarga_arma"))
	if r == "padrao":
		return ev is InputEventMouseButton and ev.button_index == BUTTON_RIGHT
	return descrever(ev) == r


## O botão do START: o aprendido vem pelo mapa de ações; no padrão, os botões
## do lado que NÃO são o da recarga (o do meio e os laterais), fora da
## partida. O da recarga nunca dá START.
func e_start_arma(ev: InputEvent) -> bool:
	if str(valor("botoes/start_arma")) != "padrao" or not e_botao_lateral(ev) or em_partida():
		return false
	return not e_botao_recarga(ev)


## Qualquer jeito de atirar: o gatilho da arma, o TIRO da Zero Delay ou, no
## PC, o espaço não (o espaço é START).
func e_tiro(ev: InputEvent) -> bool:
	if e_tiro_arma(ev):
		return true
	return ev.is_action_pressed("input_shot")


func e_recarga(ev: InputEvent) -> bool:
	if e_recarga_arma(ev):
		return true
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.scancode == KEY_R:
		return true
	return ev.is_action_pressed("input_recharge")


## START da Zero Delay, da arma (lado direito ou o aprendido) ou do teclado
## (1, ENTER, ESPAÇO).
func e_start(ev: InputEvent) -> bool:
	if ev.is_action_pressed(ACAO_START) or e_start_arma(ev):
		return true
	if ev is InputEventKey and ev.pressed and not ev.echo:
		return ev.scancode in [KEY_1, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	return false


# ---------------------------------------------------------------- créditos
## O START quer começar uma partida: no modo livre sempre pode; no modo
## crédito desconta os créditos da partida ou avisa que falta crédito.
func cobrar() -> bool:
	if not modo_credito():
		_contar_partida()
		return true
	if creditos() >= creditos_por_partida():
		definir("maquina/creditos", creditos() - creditos_por_partida())
		_contar_partida()
		_atualizar_rotulo()
		emit_signal("creditos_mudaram", creditos())
		return true
	emit_signal("sem_credito")
	_mostrar_aviso("INSIRA CRÉDITO", true)
	return false


func pode_jogar() -> bool:
	return not modo_credito() or creditos() >= creditos_por_partida()


func texto_chamada() -> String:
	return "APERTE START" if pode_jogar() else "INSIRA CRÉDITO"


func texto_jogar_novamente() -> String:
	return "APERTE START PARA JOGAR NOVAMENTE" if pode_jogar() else "INSIRA CRÉDITO PARA JOGAR NOVAMENTE"


func texto_creditos() -> String:
	if not modo_credito():
		return "JOGO LIVRE"
	var t = "CRÉDITOS %02d" % creditos()
	if creditos_por_partida() > 1:
		t += "   ·   %d POR PARTIDA" % creditos_por_partida()
	return t


func somar_credito(qtd: int = 1, conta_ficha: bool = true) -> void:
	definir("maquina/creditos", int(clamp(creditos() + qtd, 0, MAX_CREDITOS)))
	if conta_ficha:
		definir("maquina/total_fichas", int(max(0, int(valor("maquina/total_fichas")) + qtd)))
	_salvar_em = 0.6
	_atualizar_rotulo()
	emit_signal("creditos_mudaram", creditos())


func _contar_partida() -> void:
	definir("maquina/total_partidas", int(valor("maquina/total_partidas")) + 1)
	_salvar_em = 0.6


# ---------------------------------------------------------------- VOLTAR
func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
		_voltar_vira_recarga()


var _ultimo_voltar = 0
var _ultimo_direito = -100000
var _voltar_pendente = -1.0

## O VOLTAR do Android (um botão lateral da arma vira VOLTAR): espera um
## instante para ver se não é o clique direito chegando também como VOLTAR
## (algumas TV Box fazem isso): aí é a recarga, que já foi tratada.
func _voltar_vira_recarga() -> void:
	var agora = OS.get_ticks_msec()
	if agora - _ultimo_voltar < 120:
		return
	_ultimo_voltar = agora
	_voltar_pendente = 0.15


func _voltar_agora() -> void:
	if OS.get_ticks_msec() - _ultimo_direito < 450:
		return
	var acao = ""
	var s = str(valor("botoes/start_arma"))
	var r = str(valor("botoes/recarga_arma"))
	if s == "voltar":
		acao = ACAO_START
	elif r == "voltar" or em_partida():
		acao = "input_recharge"
	elif s == "padrao":
		acao = ACAO_START
	if acao == "" or not InputMap.has_action(acao) or na_configuracao():
		return
	var aperta = InputEventAction.new()
	aperta.action = acao
	aperta.pressed = true
	Input.parse_input_event(aperta)
	var solta = InputEventAction.new()
	solta.action = acao
	solta.pressed = false
	Input.call_deferred("parse_input_event", solta)


# ---------------------------------------------------------------- SELECT
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_RIGHT:
		_ultimo_direito = OS.get_ticks_msec()
	if event is InputEventKey and event.pressed and not event.echo and event.scancode == KEY_F10:
		abrir_configuracao()
		return
	if not InputMap.has_action(ACAO_SELECT):
		return
	if event.is_action_pressed(ACAO_SELECT):
		_select_segurado = 0.0
		_ficha_do_select = false
		if modo_credito() and not na_configuracao():
			somar_credito(1)
			_ficha_do_select = true
			efeito(_som_ficha())
			_mostrar_aviso("+1 CRÉDITO", false)
	elif event.is_action_released(ACAO_SELECT):
		_select_segurado = -1.0


var _ficha: AudioStream = null

func _som_ficha() -> AudioStream:
	if _ficha == null:
		_ficha = load("res://songs/ficha.wav")
	return _ficha


func _process(delta: float) -> void:
	if _voltar_pendente >= 0.0:
		_voltar_pendente -= delta
		if _voltar_pendente < 0.0:
			_voltar_agora()
	if _salvar_em > 0.0:
		_salvar_em -= delta
		if _salvar_em <= 0.0:
			salvar()
	if _select_segurado >= 0.0:
		_select_segurado += delta
		if _select_segurado >= SEGURAR_SELECT_PARA_CONFIG:
			_select_segurado = -1.0
			if na_abertura():
				# segurou para abrir a configuração: a ficha não vale
				if _ficha_do_select:
					somar_credito(-1, false)
					definir("maquina/total_fichas", int(max(0, int(valor("maquina/total_fichas")) - 1)))
				abrir_configuracao()
	if _aviso_t > 0.0:
		_aviso_t -= delta
		if _aviso_t <= 0.0:
			_atualizar_rotulo()
	elif _caixa != null:
		var deve = cena_atual() in CENAS_SELO
		if _caixa.visible != deve:
			_caixa.visible = deve


func abrir_configuracao() -> void:
	if na_configuracao():
		return
	TransicaoGlobal.trocar_cena(CENA_CONFIG)


func cena_atual() -> String:
	var c = get_tree().current_scene
	return c.filename if c != null else ""


func na_abertura() -> bool:
	return cena_atual() in CENAS_ABERTURA


func na_configuracao() -> bool:
	return cena_atual() == CENA_CONFIG


# ---------------------------------------------------------------- selo
func _criar_rotulo() -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 900
	add_child(_camada)
	_caixa = Panel.new()
	_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caixa.add_stylebox_override("panel", Estilo.caixa(Color(0, 0, 0, 0.62), Color(1, 1, 1, 0.12), 1, 22))
	_camada.add_child(_caixa)
	_rotulo = Estilo.rotulo(_caixa, "", 28, Color(1, 1, 1, 0.92), 0, false)
	_caixa.visible = false


func _posicionar_selo() -> void:
	var tam = Estilo.fonte(28, false).get_string_size(_rotulo.text) + Vector2(56, 18)
	_caixa.rect_size = tam
	# só aparece na tela inicial: à direita, longe do logo LAZER SHOT do fundo
	_caixa.rect_position = Vector2(780.0 - tam.x * 0.5, Tela.TELA.y - tam.y - 16.0)
	_caixa.rect_pivot_offset = tam * 0.5
	_rotulo.rect_position = Vector2.ZERO
	_rotulo.rect_size = tam


func _atualizar_rotulo() -> void:
	if _rotulo == null:
		return
	_rotulo.text = texto_creditos()
	_rotulo.add_color_override("font_color", Color(1.0, 0.86, 0.3) if modo_credito() else Color(0.75, 1.0, 0.8))
	_posicionar_selo()


func _mostrar_aviso(texto: String, alerta: bool) -> void:
	if _rotulo == null:
		return
	_rotulo.text = texto + ("" if alerta else "   ·   " + texto_creditos())
	_rotulo.add_color_override("font_color", Color(1.0, 0.35, 0.3) if alerta else Color(1.0, 0.9, 0.35))
	_posicionar_selo()
	_caixa.visible = true
	_caixa.rect_scale = Vector2(1.15, 1.15)
	var tw = create_tween()
	tw.tween_property(_caixa, "rect_scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_aviso_t = 2.5


# ---------------------------------------------------------------- áudio
## Música e efeitos em barramentos próprios (volumes da configuração).
func _criar_barramentos_de_audio() -> void:
	_bus_musica = _bus("Musica")
	_bus_efeitos = _bus("Efeitos")
	# analisador de espectro na música: as luzes pulsam com o som
	if AudioServer.get_bus_effect_count(_bus_musica) == 0:
		var analisador = AudioEffectSpectrumAnalyzer.new()
		analisador.buffer_length = 0.1
		analisador.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_512
		AudioServer.add_bus_effect(_bus_musica, analisador)
	# os efeitos passam por um limitador antes de somar com a música: muitos
	# tiros e recargas juntos não estouram a saída (o estouro corta o som
	# todo, música inclusive). Ele só pega o pico (limiar alto): não abaixa
	# um som por causa do outro
	if AudioServer.get_bus_effect_count(_bus_efeitos) == 0:
		var lim = AudioEffectLimiter.new()
		lim.ceiling_db = -0.8
		lim.threshold_db = -1.0
		lim.soft_clip_db = 1.5
		AudioServer.add_bus_effect(_bus_efeitos, lim)
	var mestre = AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(mestre) == 0:
		var lim2 = AudioEffectLimiter.new()
		lim2.ceiling_db = -0.3
		lim2.threshold_db = -1.0
		AudioServer.add_bus_effect(mestre, lim2)


func _bus(nome: String) -> int:
	var i = AudioServer.get_bus_index(nome)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, nome)
		AudioServer.set_bus_send(i, "Master")
	return i


var _som_quadro = -1
var _som_grave = 0.0
var _som_batida = 0.0
var _som_media = 0.0

## Energia da música agora (x = grave suavizado 0..1, y = batida).
func energia_musica() -> Vector2:
	var q = Engine.get_idle_frames()
	if q == _som_quadro:
		return Vector2(_som_grave, _som_batida)
	_som_quadro = q
	var dt = get_process_delta_time()
	var bruto = 0.0
	if _bus_musica >= 0 and AudioServer.get_bus_effect_count(_bus_musica) > 0:
		var ef = AudioServer.get_bus_effect_instance(_bus_musica, 0)
		if ef != null:
			var m: Vector2 = ef.get_magnitude_for_frequency_range(30.0, 160.0)
			var db = linear2db(max(m.length(), 0.00001))
			bruto = clamp((db + 48.0) / 36.0, 0.0, 1.0)
	var k = 1.0 - exp(-dt * (22.0 if bruto > _som_grave else 5.0))
	_som_grave = lerp(_som_grave, bruto, k)
	_som_media = lerp(_som_media, bruto, 1.0 - exp(-dt * 1.5))
	var pico = clamp((bruto - _som_media) * 3.0, 0.0, 1.0)
	_som_batida = max(pico, _som_batida - dt * 3.5)
	return Vector2(_som_grave, _som_batida)


## energia_musica() que nunca para: sem música um pulso calmo (~112 bpm).
func pulso_vivo() -> Vector2:
	var e = energia_musica()
	var fase = fmod(OS.get_ticks_msec() * 0.001 * 112.0 / 60.0, 1.0)
	var sint: float = max(0.0, 1.0 - fase * 3.0)
	sint *= sint
	var peso = 1.0 - clamp(e.x * 6.0, 0.0, 1.0)
	return Vector2(max(e.x, (0.16 + 0.12 * sint) * peso), max(e.y, sint * 0.5 * peso))


## EFEITOS SONOROS sem criar nó a cada som: cada efeito tem as suas vozes
## (nascem conforme a precisão, até VOZES_POR_SOM). O som novo vai para uma
## voz livre; só sem voz livre ele toma a que está tocando há mais tempo
## (o fim dela, o mais baixo). No máximo MAX_VOZES tocando juntas; o mesmo
## som repetido em menos de REPETIDO_MS vale uma vez só. Nada abaixa os
## outros sons: o limitador só segura o pico do estouro.
const VOZES_POR_SOM = 6
const MAX_VOZES = 24
const REPETIDO_MS = 30
var _efeitos = {}
var _ultimo_ms = {}
var _tocando = []

func efeito(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0, inicio: float = 0.0) -> void:
	if stream == null:
		return
	var agora = OS.get_ticks_msec()
	if agora - int(_ultimo_ms.get(stream, -1000)) < REPETIDO_MS:
		return
	_ultimo_ms[stream] = agora
	var i_t = _tocando.size() - 1
	while i_t >= 0:
		if not is_instance_valid(_tocando[i_t]) or not _tocando[i_t].playing:
			_tocando.remove(i_t)
		i_t -= 1
	var lista: Array = _efeitos.get(stream, [])
	_efeitos[stream] = lista
	var pl: AudioStreamPlayer = null
	var mais_velha: AudioStreamPlayer = null
	for v in lista:
		if not v.playing:
			pl = v
			break
		if mais_velha == null or v.get_playback_position() > mais_velha.get_playback_position():
			mais_velha = v
	if pl == null and lista.size() < VOZES_POR_SOM:
		pl = AudioStreamPlayer.new()
		pl.bus = "Efeitos"
		pl.stream = stream
		add_child(pl)
		lista.append(pl)
	if pl == null:
		pl = mais_velha
	elif _tocando.size() >= MAX_VOZES:
		# a mistura cheia: cede a voz mais antiga de todas
		var velho = _tocando.pop_front()
		velho.stop()
	pl.volume_db = volume_db
	pl.pitch_scale = max(0.05, pitch)
	pl.play(max(0.0, inicio))
	_tocando.erase(pl)
	_tocando.append(pl)


## Solta os sons de efeito que não são da tela nova (troca de tela).
func soltar_efeitos(manter: Array = []) -> void:
	for s in _efeitos.keys():
		if s in manter:
			continue
		for v in _efeitos[s]:
			(v as Node).queue_free()
		_efeitos.erase(s)
	_tocando.clear()


## Toca uma música no barramento da música (um player por chamada; a tela
## guarda e para). A música nunca acaba enquanto a tela está aberta: se o
## arquivo não tiver laço, ela recomeça sozinha ao terminar.
func musica(pai: Node, stream: AudioStream, volume_db: float = 0.0) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.bus = "Musica"
	p.stream = stream
	p.volume_db = volume_db
	pai.add_child(p)
	p.connect("finished", self, "_musica_acabou", [p])
	if stream != null:
		p.play()
	return p


func _musica_acabou(p: AudioStreamPlayer) -> void:
	if is_instance_valid(p) and p.is_inside_tree() and not p.get_meta("parada", false):
		p.play()
