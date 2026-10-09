extends Node2D

var modal_atire_label: Label = null
var chat_rodape_panel: Panel = null
var ranking_nome_bg: ColorRect = null
var ranking_nome_titulo: Label = null
var ranking_nome_texto: Label = null
var ranking_nome_teclado: GridContainer = null
var ranking_nome_btn_ok: Button = null
var ranking_nome_btn_apagar: Button = null
var ranking_nome_timer_label: Label = null

var ranking_precisao_pendente: int = 0
var ranking_pontos_pendentes: int = 0
var ranking_cenario_pendente: String = "ARENA"
var ranking_ja_salvo: bool = false
 
# ─────────────────────────────────────────────
#  CONFIGURAÇÕES EXPORTADAS
# ─────────────────────────────────────────────
 
@export var quantidade_alvos_simultaneos: int = 9
@export var escala_alvo_jogo: float = 0.66
 
@export var cena_lanterna_vermelha: PackedScene = preload("res://entities/LanternaVermelha.tscn")
@export var cena_lanterna_verde: PackedScene   = preload("res://entities/LanternaVerde.tscn")
@export var cena_lanterna_azul: PackedScene    = preload("res://entities/LanternaAzul.tscn")
 
@export var pontos_base_sequencia: int = 20
@export var penalidade_erro_sequencia: int = 100

@export var offset_lanterna_vermelha: Vector2 = Vector2.ZERO
@export var offset_lanterna_azul: Vector2 = Vector2(-6.0, 6.0)
@export var offset_lanterna_verde: Vector2 = Vector2(-3.0, 0.0)
 
@export var tempo_mostrar_azul: float   = 0.55
@export var pausa_entre_azuis: float    = 0.20
@export var tempo_feedback_verde: float = 0.60
@export var tempo_feedback_erro: float  = 0.50
 
@export var capacidade_cartucho: int      = 30
@export var tempo_recarga_seg: float      = 1.10
@export var alerta_baixa_municao_limite: int = 6
 
@export var subida_spawn_distancia: float = 190.0
@export var tempo_respawn_alvo: float     = 0.08
 
@export var distancia_minima_spawn: float = 155.0
@export var distancia_segura_cruzamento: float = 120.0
 
@export var volume_crash_db: float = 8.0
 
@export var escala_preview_modal: float = 0.72
@export var offset_y_alvos: float       = 40.0
 
@export var textura_fundo: Texture2D
 
@export_file("*.mp3;*.wav;*.ogg") var caminho_musica_arena: String  = "res://songs/arena_song.mp3"
@export_file("*.mp3;*.wav;*.ogg") var caminho_som_tiro: String      = "res://songs/plasma-hit.mp3"
@export_file("*.mp3;*.wav;*.ogg") var caminho_som_recarga: String   = "res://songs/lazer-charge.mp3"
@export_file("*.mp3;*.wav;*.ogg") var caminho_som_sem_bala: String  = "res://songs/bullet_no.mp3"
@export_file("*.mp3;*.wav;*.ogg") var caminho_som_alvo_cash: String = "res://songs/alvo_crash.mp3"
@export_file("*.mp3;*.wav;*.ogg") var caminho_som_hit_lamp: String = "res://songs/hit-lamp.mp3" 
@export_file("*.mp3;*.wav;*.ogg") var caminho_som_bip: String = "res://songs/bip.mp3"
@export_file("*.mp3;*.wav;*.ogg") var caminho_som_bip_error: String = "res://songs/bip-error.mp3"


@export var tempo_total: float = 120.0
@export var intervalo_spawn_arco: float = 0.95
 
@export var altura_maxima_spawn_ratio: float = 0.48
@export var margem_topo_spawn: float    = 180.0
@export var margem_lateral_spawn: float = 90.0
@export var margem_spawn_x: float       = 130.0
@export var margem_spawn_topo: float    = 420.0
@export var margem_spawn_baixo: float   = 150.0

@export var tempo_repetir_sequencia_inativo: float = 20.0

@export var usar_controle_xbox: bool = true
@export var velocidade_mira_xbox: float = 900.0
@export var deadzone_xbox: float = 0.18

@export var xbox_botao_tiro: int = JOY_BUTTON_RIGHT_SHOULDER
@export var xbox_botao_recarga: int = JOY_BUTTON_X
@export var xbox_botao_recarga_extra: int = JOY_BUTTON_LEFT_SHOULDER

const Pincel := preload("res://scripts/pincel.gd")
const META_SENS_XBOX: String = "sensibilidade_xbox"
const META_SENS_MOUSE: String = "sensibilidade_mouse"

const COR_NEON_ARENA: Color       = Color(1.0, 0.08, 0.06, 1.0)
const COR_NEON_ARENA_CLARO: Color  = Color(1.0, 0.58, 0.58, 1.0)
const COR_FUNDO_CARD_ARENA: Color  = Color(0.045, 0.008, 0.008, 0.94)



func _estilo_card_arena() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color            = COR_FUNDO_CARD_ARENA
	estilo.border_width_left   = 4
	estilo.border_width_top    = 4
	estilo.border_width_right  = 4
	estilo.border_width_bottom = 4
	estilo.border_color        = COR_NEON_ARENA
	estilo.corner_radius_top_left     = 34
	estilo.corner_radius_top_right    = 34
	estilo.corner_radius_bottom_left  = 34
	estilo.corner_radius_bottom_right = 34
	estilo.shadow_color  = Color(COR_NEON_ARENA.r, COR_NEON_ARENA.g, COR_NEON_ARENA.b, 0.60)
	estilo.shadow_size   = 34
	estilo.shadow_offset = Vector2.ZERO
	return estilo



func _set_estilo_panel_arena(panel: Panel, bg: Color, borda: Color = COR_NEON_ARENA, sombra_alpha: float = 0.60) -> void:
	if panel == null:
		return
	var estilo := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if estilo == null:
		estilo = _estilo_card_arena()
		Leve.stylebox(panel, "panel", estilo)
	estilo.bg_color     = bg
	estilo.border_color = borda
	estilo.shadow_color = Color(borda.r, borda.g, borda.b, sombra_alpha)


@export var sensibilidade_mouse: float = 1.0
var ultimo_mouse_pos: Vector2 = Vector2.ZERO


var mouse_delta_acumulado: Vector2 = Vector2.ZERO

var xbox_mira_iniciada: bool = false

var tempo_sem_jogada: float = 0.0
var repetindo_sequencia_por_inatividade: bool = false
 
 
# ─────────────────────────────────────────────
#  ESTADO DA SEQUÊNCIA (JOGO DE MEMÓRIA)
# ─────────────────────────────────────────────
 
var sequencia_atual: Array[int] = []
var indice_sequencia: int       = 0
var nivel_sequencia: int        = 1
var mostrando_sequencia: bool   = false
var bloqueia_tiro_sequencia: bool = false
 
 
# ─────────────────────────────────────────────
#  ESTADO GERAL DO JOGO
# ─────────────────────────────────────────────
 
var tempo_restante: float = 0.0
var pontuacao: int        = 0
var municao_atual: int    = 0
var tiros: int            = 0
var acertos: int          = 0
 
var jogo_ativo: bool    = false
var jogo_iniciado: bool = false
 
var recarregando: bool         = false
var reload_tempo_restante: float = 0.0
var aviso_recarga_t: float       = 0.0
 
var municao_maxima: int = 12
 
 
# ─────────────────────────────────────────────
#  ALVOS / SLOTS
# ─────────────────────────────────────────────
 
var alvos_ativos: Array[Area2D]  = []
var dados_alvos: Dictionary      = {}
var slots_ocupados: Array[bool]  = []
var posicoes_spawn: Array[Vector2] = []
 
 
# ─────────────────────────────────────────────
#  EFEITOS VISUAIS
# ─────────────────────────────────────────────
 
var fx_colisao: Array[Dictionary] = []
var mira_pos: Vector2             = Vector2.ZERO
var marcas_laser_parede: Array[Dictionary] = []
var fx_layer_jogo: Node2D = null

 
 
# ─────────────────────────────────────────────
#  MENSAGENS DE RODAPÉ
# ─────────────────────────────────────────────
 
var status_msgs: Array              = []
var status_labels: Array[Label]     = []

 
 
# ─────────────────────────────────────────────
#  ÁUDIO
# ─────────────────────────────────────────────
 
var audio_tiro: AudioStreamPlayer        = null
var audio_recarga: AudioStreamPlayer     = null
var audio_sem_bala: AudioStreamPlayer    = null
var audio_musica_arena: AudioStreamPlayer = null
var audio_alvo_cash: AudioStreamPlayer   = null
var audio_hit_lamp: AudioStreamPlayer = null
var audio_bip: AudioStreamPlayer = null
var audio_bip_error: AudioStreamPlayer = null

 
# ─────────────────────────────────────────────
#  HUD (criado por código)
# ─────────────────────────────────────────────
 
var hud_layer_codigo: CanvasLayer = null
var hud_root: Control             = null
 
var top_bar: Panel       = null
var top_bar_sombra: ColorRect = null
var top_bar_linha: ColorRect  = null
 
var timer_panel: Panel  = null
var score_panel: Panel  = null
var municao_panel: Panel = null
 
var stats_arena_panel: Panel = null   # ← novo

var timer_title_label: Label = null
var timer_label: Label       = null
var score_title_label: Label = null
var score_label: Label       = null
var municao_title_label: Label = null
var municao_label: Label     = null
var recarga_label: Label     = null
var acertos_title_label: Label = null
var acertos_label: Label     = null
var tiros_title_label: Label = null
var tiros_label: Label       = null
var nivel_title_label: Label = null
var nivel_label: Label       = null
 
var municao_blocos: Array[ColorRect] = []
 
 
# ─────────────────────────────────────────────
#  MIRA
# ─────────────────────────────────────────────
 
var mira_layer: CanvasLayer = null
var mira_root: Control      = null
 
 
# ─────────────────────────────────────────────
#  MODAL DE INÍCIO
# ─────────────────────────────────────────────
 
var modal_layer: CanvasLayer   = null
var modal_root: Control        = null
var modal_fundo: ColorRect     = null
var modal_painel: Panel        = null
var modal_titulo: Label        = null
var modal_texto: Label         = null
var modal_texto2: Label        = null
var preview_left: AnimatedSprite2D   = null
var preview_center: AnimatedSprite2D = null
var preview_right: AnimatedSprite2D  = null
var preview_label_left: Label   = null
var preview_label_center: Label = null
var preview_label_right: Label  = null
var info_inicio_texture: TextureRect = null
 


# modal fim
 
var fim_layer: CanvasLayer = null
var fim_root: Control = null

var fim_bg: ColorRect = null
var fim_panel: Panel = null

var fim_titulo: Label = null
var fim_score_label: Label = null
var fim_stats_label: Label = null
var fim_footer: Label = null
var fim_contagem_label: Label = null

var fim_ativo: bool = false
var fim_tempo_voltar: float = 21.0

# RANKING
var ranking_nome_layer: CanvasLayer = null
var ranking_nome_root: Control = null
var ranking_nome_panel: Panel = null
var ranking_nome_display: Label = null
var ranking_nome_digitado: String = ""

var ranking_nome_ativo: bool = false
var ranking_nome_tempo: float = 50.0




# ─────────────────────────────────────────────
#  CONTAGEM REGRESSIVA
# ─────────────────────────────────────────────
 
var countdown_layer: CanvasLayer = null
var countdown_root: Control      = null
var countdown_flash: ColorRect   = null
var countdown_label: Label       = null
 
var intro_comeco_ativa: bool  = false
var intro_comeco_t: float     = 0.0
var intro_contagem_valor: int = 3
 
 
# ─────────────────────────────────────────────
#  NÓS DA CENA
# ─────────────────────────────────────────────
 
@onready var background: Node        = $Background
@onready var hud_layer: CanvasLayer  = $Hud
@onready var lbl_tempo: Label        = $Hud/Topo/PainelTempo/ValorTempo
@onready var lbl_pontos: Label       = $Hud/Topo/PainelPontuacao/ValorPontuacao
@onready var lbl_municao: Label      = $Hud/Topo/PainelMunicao/ValorMunicao
@onready var lbl_tiros: Label        = $Hud/Topo/PainelTiros/ValorTiros
@onready var lbl_acertos: Label      = $Hud/Topo/PainelAcertos/ValorAcertos
 
@onready var topo_hud: Control       = $Hud/Topo
@onready var painel_tempo: Control   = $Hud/Topo/PainelTempo
@onready var painel_pontos: Control  = $Hud/Topo/PainelPontuacao
@onready var painel_municao: Control = $Hud/Topo/PainelMunicao
@onready var painel_tiros: Control   = $Hud/Topo/PainelTiros
@onready var painel_acertos: Control = $Hud/Topo/PainelAcertos
 
@onready var timer_jogo: Timer   = $TimerJogo
@onready var timer_spawn: Timer  = $TimerSpawn
@onready var camada_alvos: Node2D = $CamadaAlvos
@onready var alvo_inicial: Area2D = get_node_or_null("CamadaAlvos/Alvo") as Area2D
 
 
# ═══════════════════════════════════════════════════════════
#  _ready
# ═══════════════════════════════════════════════════════════
 
func _ready() -> void:
	randomize()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_aplicar_sensibilidade_global()

	mira_pos = get_viewport_rect().size * 0.5
	ultimo_mouse_pos = mira_pos
	mouse_delta_acumulado = Vector2.ZERO

	_aplicar_config_admin_na_cena()

	tempo_restante = tempo_total
	municao_maxima = capacidade_cartucho
	municao_atual = capacidade_cartucho
	pontuacao = 0
	tiros = 0
	acertos = 0
	jogo_ativo = false
	jogo_iniciado = false
	recarregando = false
	reload_tempo_restante = 0.0
	aviso_recarga_t = 0.0

	timer_jogo.wait_time = 1.0
	timer_jogo.one_shot = false
	if not timer_jogo.timeout.is_connected(_on_timer_jogo_timeout):
		timer_jogo.timeout.connect(_on_timer_jogo_timeout)

	timer_spawn.wait_time = intervalo_spawn_arco
	timer_spawn.one_shot = false
	if not timer_spawn.timeout.is_connected(_on_timer_spawn_timeout):
		timer_spawn.timeout.connect(_on_timer_spawn_timeout)

	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)

	if hud_layer != null:
		hud_layer.visible = false

	_configurar_audio()
	_configurar_background_fullscreen()
	_configurar_fx_layer_jogo()
	_configurar_pontos_spawn()
	_preparar_alvo_inicial()
	_criar_modal_inicio()
	_criar_intro_comeco()
	_configurar_mira()
	_tocar_musica_arena()
	_configurar_hud_bar_padrao()
	_configurar_modal_fim()

	call_deferred("_reposicionar_modal")
	call_deferred("_atualizar_hud")

 

func _aplicar_sensibilidade_global() -> void:
	# XBOX travado em 5000 — vale para FÁCIL e DIFÍCIL.
	velocidade_mira_xbox = 1500.0

	# MOUSE continua respeitando o config.
	if get_tree().has_meta(META_SENS_MOUSE):
		sensibilidade_mouse = float(get_tree().get_meta(META_SENS_MOUSE))

	sensibilidade_mouse = clamp(sensibilidade_mouse, 0.2, 3.0)


 
# ═══════════════════════════════════════════════════════════
#  _process
# ═══════════════════════════════════════════════════════════
 
func _process(delta: float) -> void:
	tempo_trava_input_arma = max(0.0, tempo_trava_input_arma - delta)

	_atualizar_mira_hibrida(delta)		

	aviso_recarga_t += delta
	_atualizar_repeticao_sequencia_por_inatividade(delta)

	# FX SEMPRE ATUALIZA, mesmo se o jogo pausar/finalizar.
	# Isso impede explosão/cacos/fumaça travados na tela.
	if fx_colisao.size() > 0:
		_atualizar_fx_colisao(delta)

	# Marcas de laser também somem automaticamente depois de um limite.
	while marcas_laser_parede.size() > 60:
		marcas_laser_parede.pop_front()

	if fx_layer_jogo != null:
		fx_layer_jogo.queue_redraw()

	if jogo_ativo:
		_atualizar_chat_rodape(delta)


	if recarregando:
		reload_tempo_restante = max(0.0, reload_tempo_restante - delta)
		if reload_tempo_restante <= 0.0:
			_finalizar_recarga()
		_atualizar_hud()

	if audio_musica_arena != null:
		if jogo_ativo or not jogo_iniciado:
			if not audio_musica_arena.playing:
				audio_musica_arena.play()

	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	var dificuldade: String = get_tree().get_meta("modo_dificuldade", "facil")

	if mira_root != null:
		if ranking_nome_ativo:
			if mira_layer != null:
				mira_layer.layer = 200

			mira_root.visible = true
			mira_root.queue_redraw()
		else:
			if mira_layer != null:
				mira_layer.layer = 100

			mira_root.visible = dificuldade != "dificil"

			if mira_root.visible:
				mira_root.queue_redraw()

	if fim_ativo:
		if ranking_nome_ativo:
			ranking_nome_tempo = max(0.0, ranking_nome_tempo - delta)

			if ranking_nome_timer_label != null:
				ranking_nome_timer_label.text = "SALVA COMO ANÔNIMO EM %02d" % int(ceil(ranking_nome_tempo))

			if fim_contagem_label != null:
				fim_contagem_label.text = "DIGITE SEU NOME PARA SALVAR O RECORDE"

			if ranking_nome_tempo <= 0.0:
				_confirmar_nome_ranking(true)

			return

		fim_tempo_voltar -= delta

		if fim_contagem_label != null:
			fim_contagem_label.text = "VOLTANDO AO MENU EM %02d" % int(ceil(fim_tempo_voltar))

		if fim_tempo_voltar <= 0.0:
			TransicaoGlobal.trocar_cena("res://scenes/main.tscn")


func _atualizar_mira_hibrida(delta: float) -> void:
	var tela: Vector2 = get_viewport_rect().size

	if not xbox_mira_iniciada:
		mira_pos = tela * 0.5
		mouse_delta_acumulado = Vector2.ZERO
		xbox_mira_iniciada = true

	var tem_xbox: bool = usar_controle_xbox and Input.get_connected_joypads().size() > 0
	var usou_xbox: bool = false

	if tem_xbox:
		var eixo_x: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		var eixo_y: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)

		if abs(eixo_x) < deadzone_xbox:
			eixo_x = 0.0
		if abs(eixo_y) < deadzone_xbox:
			eixo_y = 0.0

		var movimento := Vector2(eixo_x, eixo_y)

		if movimento.length() > 1.0:
			movimento = movimento.normalized()

		if movimento.length() > 0.0:
			mira_pos += movimento * velocidade_mira_xbox * delta
			usou_xbox = true

	if not usou_xbox:
		if mouse_delta_acumulado.length_squared() > 0.0:
			mira_pos += mouse_delta_acumulado * sensibilidade_mouse
			mouse_delta_acumulado = Vector2.ZERO

	mira_pos.x = clampf(mira_pos.x, 0.0, tela.x)
	mira_pos.y = clampf(mira_pos.y, 0.0, tela.y)



func _atualizar_mira_xbox(delta: float) -> void:
	var tela: Vector2 = get_viewport_rect().size

	if not xbox_mira_iniciada:
		mira_pos = tela * 0.5
		xbox_mira_iniciada = true

	var eixo_x: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var eixo_y: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)

	if abs(eixo_x) < deadzone_xbox:
		eixo_x = 0.0

	if abs(eixo_y) < deadzone_xbox:
		eixo_y = 0.0

	var movimento := Vector2(eixo_x, eixo_y)

	if movimento.length() > 1.0:
		movimento = movimento.normalized()

	mira_pos += movimento * velocidade_mira_xbox * delta

	mira_pos.x = clamp(mira_pos.x, 0.0, tela.x)
	mira_pos.y = clamp(mira_pos.y, 0.0, tela.y)



func _resetar_timer_jogada() -> void:
	tempo_sem_jogada = 0.0 
 

func _atualizar_repeticao_sequencia_por_inatividade(delta: float) -> void:
	if not jogo_ativo:
		return

	if not jogo_iniciado:
		return

	if fim_ativo or ranking_nome_ativo:
		return

	if intro_comeco_ativa:
		return

	if mostrando_sequencia or bloqueia_tiro_sequencia:
		tempo_sem_jogada = 0.0
		return

	if sequencia_atual.is_empty():
		return

	if indice_sequencia >= sequencia_atual.size():
		return

	tempo_sem_jogada += delta

	if tempo_sem_jogada >= tempo_repetir_sequencia_inativo:
		tempo_sem_jogada = 0.0
		_repetir_sequencia_atual_por_inatividade()


func _repetir_sequencia_atual_por_inatividade() -> void:
	if repetindo_sequencia_por_inatividade:
		return

	if not jogo_ativo:
		return

	if sequencia_atual.is_empty():
		return

	repetindo_sequencia_por_inatividade = true
	bloqueia_tiro_sequencia = true
	mostrando_sequencia = true

	_adicionar_chat_rodape("RELEMBRANDO A SEQUÊNCIA ATUAL...", Color(0.30, 0.85, 1.0))

	await get_tree().create_timer(0.35).timeout

	if jogo_ativo:
		await _mostrar_sequencia_azul(true, true)

	mostrando_sequencia = false
	bloqueia_tiro_sequencia = false
	repetindo_sequencia_por_inatividade = false
	tempo_sem_jogada = 0.0

	if jogo_ativo:
		_adicionar_chat_rodape("CONTINUE DE ONDE PAROU! %d/%d" % [
			indice_sequencia,
			sequencia_atual.size()
		], Color(0.30, 1.0, 0.60))



func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
 
 
func _draw() -> void:
	pass
 

func _desenhar_fx_layer_jogo() -> void:
	_desenhar_marcas_laser_parede()
	_desenhar_fx_colisao()

 
# ═══════════════════════════════════════════════════════════
#  INPUT
# ═══════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	# ============================================================
	# MOVIMENTO DA MIRA
	# ============================================================
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		mouse_delta_acumulado += mm.relative
		return

	# ============================================================
	# START / CRÉDITO / RECOMEÇAR
	# ============================================================
	if InputMap.has_action("input_start") and event.is_action_pressed("input_start"):
		if ranking_nome_ativo:
			_confirmar_nome_ranking(false)
			return

		if fim_ativo:
			_reiniciar_partida_modal_final()
			return

		if intro_comeco_ativa:
			return

		if not jogo_iniciado:
			_iniciar_intro_comeco()
			return

	# ============================================================
	# INPUT MAP — ARMA FÍSICA / ZERO DELAY / ARDUINO
	# input_shot = tiro
	# input_recharge = recarga
	# ============================================================
	if _evento_input_shot_arma(event):
		_executar_tiro_arma()
		return

	if _evento_input_recharge_arma(event):
		_executar_recarga_arma()
		return

	# ============================================================
	# CONTROLE XBOX — FALLBACK
	# ============================================================
	if event is InputEventJoypadButton:
		var jb: InputEventJoypadButton = event as InputEventJoypadButton

		if not jb.pressed:
			return

		print("BOTÃO XBOX ARENA:", jb.button_index)

		if jb.button_index == xbox_botao_tiro:
			_executar_tiro_arma()
			return

		if jb.button_index == xbox_botao_recarga or jb.button_index == xbox_botao_recarga_extra:
			_executar_recarga_arma()
			return

	# ============================================================
	# MOUSE / ARMA COMO MOUSE — FALLBACK
	# BOTAO_GATILHO_1 / BOTAO_GATILHO_2 = tiro
	# BOTAO_RECARGA_1 / 2 / 3 = recarga
	# ============================================================
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton

		if not mb.pressed:
			return

		_debug_botao_arma(mb)

		if _evento_tiro_arma(mb):
			_executar_tiro_arma()
			return

		if _evento_recarga_arma(mb):
			_executar_recarga_arma()
			return

	# ============================================================
	# TECLADO — FALLBACK
	# R = recarga
	# ENTER = start
	# ============================================================
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey

		if not key.pressed or key.echo:
			return

		if key.keycode == KEY_R:
			_executar_recarga_arma()
			return

		if key.keycode == KEY_ENTER:
			if ranking_nome_ativo:
				_confirmar_nome_ranking(false)
				return

			if fim_ativo:
				_reiniciar_partida_modal_final()
				return

			if intro_comeco_ativa:
				return

			if not jogo_iniciado:
				_iniciar_intro_comeco()
				return


 
func _reiniciar_partida_modal_final() -> void:
	# Modo crédito: só recomeça se houver crédito (desconta aqui).
	if not Maquina.cobrar():
		return
	_aplicar_config_admin_na_cena()
	fim_ativo = false
	fim_tempo_voltar = float(get_tree().get_meta("admin_tempo_modal_final", fim_tempo_voltar))

	ranking_nome_ativo = false
	ranking_ja_salvo = false
	ranking_nome_digitado = ""

	if fim_root != null:
		fim_root.visible = false
		fim_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if fim_layer != null:
		fim_layer.visible = false

	if ranking_nome_layer != null:
		ranking_nome_layer.visible = false

	if mira_layer != null:
		mira_layer.visible = true
		mira_layer.layer = 100

	if mira_root != null:
		mira_root.visible = true
		mira_root.queue_redraw()

	if hud_layer_codigo != null:
		hud_layer_codigo.visible = true

	if modal_layer != null:
		modal_layer.visible = true

	if info_inicio_texture != null:
		info_inicio_texture.visible = true

	jogo_ativo = false
	jogo_iniciado = false
	intro_comeco_ativa = false
	recarregando = false
	reload_tempo_restante = 0.0
	mostrando_sequencia = false
	bloqueia_tiro_sequencia = false

	tempo_restante = tempo_total
	pontuacao = 0
	tiros = 0
	acertos = 0
	municao_atual = capacidade_cartucho
	nivel_sequencia = 1
	indice_sequencia = 0
	sequencia_atual.clear()

	_limpar_alvos()
	fx_colisao.clear()
	marcas_laser_parede.clear()
	status_msgs.clear()

	timer_jogo.stop()
	timer_spawn.stop()

	_tocar_musica_arena()
	_atualizar_hud()
	_reposicionar_modal()

	if fx_layer_jogo != null:
		fx_layer_jogo.queue_redraw()


func _estilizar_botao_modal_final(btn: Label, texto: String, destaque: bool = false) -> void:
	if btn == null:
		return

	btn.text = texto
	btn.scale = Vector2.ONE
	btn.modulate = Color.WHITE
	btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	Leve.font_size(btn, "font_size", 32)
	Leve.color(btn, "font_color", Color.WHITE)
	Leve.color(btn, "font_outline_color", Color(0.85, 0.0, 0.0))
	Leve.constant(btn, "outline_size", 6)



# ═══════════════════════════════════════════════════════════
#  LÓGICA DE TIRO — JOGO DE MEMÓRIA
# ═══════════════════════════════════════════════════════════
 
func _desenhar_marcas_laser_parede() -> void:
	if fx_layer_jogo == null:
		return

	for marca in marcas_laser_parede:
		var pos: Vector2 = marca.get("pos", Vector2.ZERO)
		var raio: float = float(marca.get("raio", 8.0))

		# Queimado externo vermelho escuro
		Pincel.circulo(fx_layer_jogo, pos, raio + 9.0, Color(0.55, 0.0, 0.0, 0.20))
		Pincel.circulo(fx_layer_jogo, pos, raio + 5.0, Color(1.0, 0.04, 0.02, 0.55))

		# Metal amassado em volta do furo
		Pincel.circulo(fx_layer_jogo, pos + Vector2(-2, 1), raio + 2.5, Color(0.34, 0.34, 0.36, 0.85))
		Pincel.circulo(fx_layer_jogo, pos + Vector2(2, -1), raio + 1.5, Color(0.12, 0.12, 0.13, 0.95))

		# Furo central
		Pincel.circulo(fx_layer_jogo, pos, raio, Color(0.0, 0.0, 0.0, 0.98))
		Pincel.circulo(fx_layer_jogo, pos + Vector2(-2, -2), raio * 0.35, Color(0.35, 0.02, 0.02, 0.65))



func _tentar_atirar(pos_mouse: Vector2) -> void:
	if not jogo_ativo:
		return
	if recarregando:
		return
	if mostrando_sequencia or bloqueia_tiro_sequencia:
		return

	if sequencia_atual.is_empty():
		return
		
	_resetar_timer_jogada()

	# PROTEÇÃO CONTRA DOUBLE HIT FORA DO TAMANHO DA SEQUÊNCIA
	if indice_sequencia < 0 or indice_sequencia >= sequencia_atual.size():
		return

	if municao_atual <= 0:
		if audio_sem_bala:
			audio_sem_bala.stop()
			audio_sem_bala.play()
		_adicionar_chat_rodape("SEM MUNIÇÃO!", Color.RED)
		return

	municao_atual -= 1
	tiros += 1
	_tocar_som_tiro()
	_atualizar_hud()

	var alvo: Area2D = _detectar_alvo_no_ponto_visual(pos_mouse)

	if alvo == null:
		_registrar_marca_laser_parede(pos_mouse)
		_adicionar_chat_rodape("ERROU!", Color.RED)
		return

	var slot_clicado: int = -1
	var id_clicado: int = alvo.get_instance_id()

	if dados_alvos.has(id_clicado):
		slot_clicado = int(dados_alvos[id_clicado].get("slot", -1))

	if slot_clicado < 0:
		_registrar_marca_laser_parede(pos_mouse)
		return

	var slot_esperado: int = sequencia_atual[indice_sequencia]

	if slot_clicado == slot_esperado:
		var pontos_acerto: int = _calcular_pontos_acerto_sequencia()

		acertos += 1
		pontuacao += pontos_acerto
		indice_sequencia += 1

		var sequencia_completa: bool = indice_sequencia >= sequencia_atual.size()

		# Se completou, bloqueia imediatamente para evitar crash no double hit
		if sequencia_completa:
			bloqueia_tiro_sequencia = true

		_tocar_som_hit_lamp()

		await _tocar_hit_lanterna_vermelha_e_virar_verde(alvo, slot_clicado)

		_registrar_fx_colisao(pos_mouse, pontos_acerto, Color(0.20, 1.0, 0.40))
		_adicionar_chat_rodape("+%d  |  ACERTO %d/%d" % [
			pontos_acerto,
			indice_sequencia,
			sequencia_atual.size()
		], Color(0.20, 1.0, 0.40))

		_atualizar_hud()

		if sequencia_completa:
			_adicionar_chat_rodape("SEQUÊNCIA COMPLETA! NÍVEL %d!" % nivel_sequencia, Color(0.30, 1.0, 0.50))

			nivel_sequencia += 1

			await get_tree().create_timer(tempo_feedback_verde).timeout

			if jogo_ativo:
				_iniciar_nova_sequencia()

	else:
		pontuacao -= penalidade_erro_sequencia

		bloqueia_tiro_sequencia = true

		_tocar_som_hit_lamp()
		await _tocar_hit_lanterna_erro_e_voltar_idle(alvo)

		_tocar_bip_error()

		_adicionar_chat_rodape("ERROU! -%d  |  REINICIANDO..." % penalidade_erro_sequencia, Color.RED)
		_atualizar_hud()

		_reiniciar_sequencia_por_erro()



func _configurar_fx_layer_jogo() -> void:
	if fx_layer_jogo != null and is_instance_valid(fx_layer_jogo):
		return

	fx_layer_jogo = Node2D.new()
	fx_layer_jogo.name = "FxLayerJogo"
	fx_layer_jogo.z_index = 999
	fx_layer_jogo.z_as_relative = false
	fx_layer_jogo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(fx_layer_jogo)

	fx_layer_jogo.draw.connect(_desenhar_fx_layer_jogo)



func _registrar_marca_laser_parede(pos: Vector2) -> void:
	marcas_laser_parede.append({
		"pos": pos,
		"raio": randf_range(7.0, 10.0)
	})

	while marcas_laser_parede.size() > 120:
		marcas_laser_parede.pop_front()

	# FUMAÇA MODERNA, ESCURA E SUAVE
	for i in range(34):
		var ang: float = randf_range(-PI * 0.95, -PI * 0.05)
		var vel: Vector2 = Vector2.RIGHT.rotated(ang) * randf_range(18.0, 105.0)
		vel.y -= randf_range(25.0, 120.0)

		fx_colisao.append({
			"fumaca": true,
			"pos": pos + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)),
			"vel": vel,
			"vida": randf_range(0.55, 1.20),
			"idade": 0.0,
			"tam": randf_range(7.0, 22.0),
			"cor": Color(0.06, 0.06, 0.065, randf_range(0.30, 0.58))
		})

	# METAL SAINDO DO IMPACTO
	for i in range(32):
		var ang2: float = randf_range(0.0, TAU)
		var vel2: Vector2 = Vector2.RIGHT.rotated(ang2) * randf_range(90.0, 360.0)

		var cor_metal: Color = Color(0.72, 0.72, 0.76, 1.0)
		if randf() < 0.45:
			cor_metal = Color(0.38, 0.38, 0.42, 1.0)

		fx_colisao.append({
			"metal": true,
			"pos": pos + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)),
			"vel": vel2,
			"vida": randf_range(0.28, 0.72),
			"idade": 0.0,
			"tam": randf_range(3.0, 8.0),
			"cor": cor_metal
		})

	if fx_layer_jogo != null:
		fx_layer_jogo.queue_redraw()



func _tocar_hit_lanterna_erro_e_voltar_idle(alvo: Area2D) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	var anim: AnimatedSprite2D = _obter_animated_do_alvo(alvo)
	if anim == null:
		return

	# Toca o estado quebrado/hit mesmo quando o jogador erra
	anim.modulate = Color.WHITE

	if anim.sprite_frames != null:
		if anim.sprite_frames.has_animation("hit"):
			anim.play("hit")
		elif anim.sprite_frames.has_animation("idle"):
			anim.play("idle")

	_fx_hit_lanterna(alvo, Color(1.0, 0.05, 0.05))
	_registrar_fx_vidro_frontal_lanterna(alvo.global_position, Color(1.0, 0.05, 0.05))

	await get_tree().create_timer(0.24).timeout

	if not jogo_ativo:
		return
	if not is_instance_valid(alvo):
		return

	if anim != null and is_instance_valid(anim) and anim.sprite_frames != null:
		anim.modulate = Color.WHITE
		if anim.sprite_frames.has_animation("idle"):
			anim.play("idle")



func _registrar_fx_vidro_frontal_lanterna(pos: Vector2, cor: Color) -> void:
	for i in range(120):
		var ang: float = randf_range(-PI * 0.92, -PI * 0.08)
		var vel: Vector2 = Vector2.RIGHT.rotated(ang) * randf_range(160.0, 620.0)
		vel.y += randf_range(120.0, 320.0)

		var cor_caco: Color = cor
		if randf() < 0.42:
			cor_caco = Color(1.0, 0.92, 0.92, 1.0)

		fx_colisao.append({
			"pos": pos + Vector2(randf_range(-34.0, 34.0), randf_range(-28.0, 22.0)),
			"vel": vel,
			"vida": randf_range(0.35, 0.90),
			"idade": 0.0,
			"tam": randf_range(4.0, 13.0),
			"cor": cor_caco
		})

	while fx_colisao.size() > 420:
		fx_colisao.pop_front()

	if fx_layer_jogo != null:
		fx_layer_jogo.queue_redraw()
 


func _tocar_hit_lanterna_vermelha_e_virar_verde(alvo: Area2D, slot: int) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	var anim: AnimatedSprite2D = _obter_animated_do_alvo(alvo)
	if anim == null:
		return

	anim.modulate = Color.WHITE

	if anim.sprite_frames != null:
		if anim.sprite_frames.has_animation("hit"):
			anim.play("hit")
		elif anim.sprite_frames.has_animation("idle"):
			anim.play("idle")

	_fx_hit_lanterna(alvo, Color(1.0, 0.05, 0.05))
	_registrar_fx_vidro_quebrado_lanterna(alvo.global_position, Color(1.0, 0.05, 0.05))

	await get_tree().create_timer(0.22).timeout

	if not jogo_ativo:
		return
	if slot < 0 or slot >= alvos_ativos.size():
		return
	if alvos_ativos[slot] == null or not is_instance_valid(alvos_ativos[slot]):
		return

	_trocar_lanterna_slot(slot, "verde")

	var alvo_verde: Area2D = alvos_ativos[slot]
	if alvo_verde != null and is_instance_valid(alvo_verde):
		_registrar_fx_vidro_quebrado_lanterna(alvo_verde.global_position, Color(0.20, 1.0, 0.35))


 
# ═══════════════════════════════════════════════════════════
#  LÓGICA DE SEQUÊNCIA
# ═══════════════════════════════════════════════════════════
 
func _iniciar_nova_sequencia() -> void:
	if not jogo_ativo:
		return
 
	bloqueia_tiro_sequencia = true
	mostrando_sequencia     = true
	indice_sequencia        = 0
	sequencia_atual.clear()
	tempo_sem_jogada = 0.0
	repetindo_sequencia_por_inatividade = false
 
	for i in range(nivel_sequencia):
		sequencia_atual.append(randi_range(0, 8))
 
	_deixar_todas_vermelhas()
 
	await get_tree().create_timer(0.35).timeout
 
	_adicionar_chat_rodape(
		"OBSERVE A SEQUÊNCIA! (%d)" % nivel_sequencia,
		Color(0.30, 0.85, 1.0)
	)
 
	await _mostrar_sequencia_azul()
 
	mostrando_sequencia     = false
	bloqueia_tiro_sequencia = false
 
	_adicionar_chat_rodape("REPITA A SEQUÊNCIA!", Color(0.30, 0.85, 1.0))
 
 

func _mostrar_sequencia_azul(manter_acertos_verdes: bool = false, somente_faltantes: bool = false) -> void:
	if manter_acertos_verdes:
		_restaurar_cores_da_sequencia_atual()

	var inicio: int = 0
	if somente_faltantes:
		inicio = clamp(indice_sequencia, 0, sequencia_atual.size())

	for i in range(inicio, sequencia_atual.size()):
		if not jogo_ativo:
			return

		var slot: int = int(sequencia_atual[i])

		if slot < 0 or slot >= alvos_ativos.size():
			continue

		var alvo: Area2D = alvos_ativos[slot]

		_trocar_lanterna_slot(slot, "azul")
		_fx_sequencia_lanterna(alvo, Color(0.20, 0.75, 1.0))
		_tocar_bip()

		await get_tree().create_timer(tempo_mostrar_azul).timeout

		if manter_acertos_verdes and _slot_ja_foi_acertado_na_sequencia(slot):
			_trocar_lanterna_slot(slot, "verde")
		else:
			_trocar_lanterna_slot(slot, "vermelha")

		await get_tree().create_timer(pausa_entre_azuis).timeout

	if manter_acertos_verdes:
		_restaurar_cores_da_sequencia_atual()
 


func _restaurar_cores_da_sequencia_atual() -> void:
	for i in range(9):
		if _slot_ja_foi_acertado_na_sequencia(i):
			_trocar_lanterna_slot(i, "verde")
		else:
			_trocar_lanterna_slot(i, "vermelha")


func _slot_ja_foi_acertado_na_sequencia(slot: int) -> bool:
	for i in range(indice_sequencia):
		if i >= 0 and i < sequencia_atual.size():
			if int(sequencia_atual[i]) == slot:
				return true
	return false
 

func _deixar_todas_vermelhas() -> void:
	for i in range(9):
		_trocar_lanterna_slot(i, "vermelha")
 
 

func _reiniciar_sequencia_por_erro() -> void:
	if not jogo_ativo:
		return

	bloqueia_tiro_sequencia = true

	# toca erro uma vez, claro e separado do bip da sequência azul
	_tocar_bip_error()

	for alvo in alvos_ativos:
		if alvo == null or not is_instance_valid(alvo):
			continue

		var anim: AnimatedSprite2D = _obter_animated_do_alvo(alvo)
		if anim == null:
			continue

		anim.modulate = Color.WHITE

		var tw := create_tween()
		tw.set_parallel(false)

		tw.tween_property(anim, "modulate", Color(1.0, 0.0, 0.0, 1.0), 0.18)
		tw.tween_property(anim, "modulate", Color.WHITE, 0.18)

		tw.tween_property(anim, "modulate", Color(1.0, 0.0, 0.0, 1.0), 0.22)
		tw.tween_property(anim, "modulate", Color.WHITE, 0.24)

		tw.tween_property(anim, "modulate", Color(1.0, 0.05, 0.05, 1.0), 0.28)
		tw.tween_property(anim, "modulate", Color.WHITE, 0.30)

	await get_tree().create_timer(1.45).timeout

	nivel_sequencia = 1
	indice_sequencia = 0
	sequencia_atual.clear()

	_deixar_todas_vermelhas()

	if jogo_ativo:
		_iniciar_nova_sequencia()
 

 
# ═══════════════════════════════════════════════════════════
#  TROCA DE COR DA LANTERNA NO SLOT
# ═══════════════════════════════════════════════════════════
 
func _trocar_lanterna_slot(slot: int, cor: String) -> void:
	if slot < 0 or slot >= alvos_ativos.size():
		return

	var alvo: Area2D = alvos_ativos[slot]
	if alvo == null or not is_instance_valid(alvo):
		return

	var anim: AnimatedSprite2D = _obter_animated_do_alvo(alvo)
	if anim == null:
		return

	var id: int = alvo.get_instance_id()
	if dados_alvos.has(id):
		dados_alvos[id]["tipo"] = "lanterna_" + cor

	# NÃO MEXE NA POSIÇÃO DO ALVO
	# mantém exatamente em cima do furo do background
	alvo.scale = Vector2.ONE * escala_alvo_jogo
	anim.position = Vector2.ZERO
	anim.scale = Vector2.ONE
	anim.rotation_degrees = 0.0

	if cor == "azul":
		anim.modulate = Color(0.25, 0.65, 1.0, 1.0)
	elif cor == "verde":
		anim.modulate = Color(0.25, 1.0, 0.35, 1.0)
	else:
		anim.modulate = Color.WHITE

	if anim.sprite_frames != null and anim.sprite_frames.has_animation("idle"):
		anim.play("idle")



func _tocar_hit_lanterna(alvo: Area2D, cor: String) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	var anim: AnimatedSprite2D = _obter_animated_do_alvo(alvo)
	if anim == null:
		return

	var cor_fx: Color = Color(1.0, 0.05, 0.05)
	if cor == "azul":
		cor_fx = Color(0.20, 0.75, 1.0)
	elif cor == "verde":
		cor_fx = Color(0.20, 1.0, 0.35)

	if anim.sprite_frames != null:
		if anim.sprite_frames.has_animation("hit"):
			anim.play("hit")
		elif anim.sprite_frames.has_animation("idle"):
			anim.play("idle")

	_fx_hit_lanterna(alvo, cor_fx)
	_registrar_fx_vidro_quebrado_lanterna(alvo.global_position, cor_fx)



func _registrar_fx_vidro_quebrado_lanterna(pos: Vector2, cor: Color) -> void:
	for i in range(95):
		var ang: float = randf_range(0.0, TAU)
		var vel: Vector2 = Vector2.RIGHT.rotated(ang) * randf_range(220.0, 780.0)

		var cor_caco: Color = cor
		if randf() < 0.35:
			cor_caco = Color(1.0, 0.92, 0.92, 1.0)

		fx_colisao.append({
			"pos": pos + Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0)),
			"vel": vel,
			"vida": randf_range(0.45, 1.20),
			"idade": 0.0,
			"tam": randf_range(3.0, 12.0),
			"cor": cor_caco
		})



func _registrar_fx_estilhaco_lanterna(pos: Vector2, cor: Color) -> void:
	for i in range(70):
		var ang: float = randf_range(0.0, TAU)
		var vel: Vector2 = Vector2.RIGHT.rotated(ang) * randf_range(180.0, 650.0)

		fx_colisao.append({
			"pos": pos,
			"vel": vel,
			"vida": randf_range(0.45, 1.05),
			"idade": 0.0,
			"tam": randf_range(5.0, 14.0),
			"cor": cor
		})


 
# ═══════════════════════════════════════════════════════════
#  SPAWN DE LANTERNAS
# ═══════════════════════════════════════════════════════════
 
func _gerar_onda_inicial() -> void:
	_limpar_alvos()
	_configurar_pontos_spawn()
	for i in range(9):
		_spawn_lanterna_no_slot(i)
 
 
func _garantir_3_alvos() -> void:
	_remover_alvos_invalidos()
	_garantir_slots()
	for i in range(9):
		if i >= slots_ocupados.size():
			continue
		if not slots_ocupados[i]:
			_spawn_lanterna_no_slot(i)
 

 
func _spawn_lanterna_no_slot(slot: int) -> void:
	if cena_lanterna_vermelha == null:
		push_error("Cena LanternaVermelha.tscn não configurada.")
		return
	if slot < 0 or slot >= posicoes_spawn.size():
		return
	if slot < slots_ocupados.size() and slots_ocupados[slot]:
		return

	var alvo: Area2D = cena_lanterna_vermelha.instantiate() as Area2D
	if alvo == null:
		push_error("Lanterna precisa ter Area2D como nó raiz.")
		return

	slots_ocupados[slot] = true
	camada_alvos.add_child(alvo)

	var pos_final: Vector2 = posicoes_spawn[slot]
	var pos_spawn: Vector2 = pos_final + Vector2(0.0, subida_spawn_distancia)

	alvo.visible = true
	alvo.show()
	alvo.process_mode = Node.PROCESS_MODE_INHERIT
	alvo.monitoring = true
	alvo.monitorable = true
	alvo.input_pickable = true
	alvo.z_index = 50
	alvo.rotation_degrees = 0.0
	alvo.global_position = pos_spawn

	# AUMENTA AS LANTERNAS VERMELHAS IDLE
	# E GARANTE QUE AZUL/VERDE USEM O MESMO TAMANHO E LUGAR
	alvo.scale = Vector2.ONE * escala_alvo_jogo

	alvo.modulate = Color(1, 1, 1, 0.0)

	_resetar_visual_arco(alvo)

	dados_alvos[alvo.get_instance_id()] = {
		"tipo": "lanterna_vermelha",
		"slot": slot,
		"quebrando": false,
		"nascendo": true,
		"base_pos": pos_final,
		"idade": 0.0
	}

	while alvos_ativos.size() <= slot:
		alvos_ativos.append(null)

	alvos_ativos[slot] = alvo

	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(alvo, "global_position", pos_final, 0.22)
	tw.tween_property(alvo, "scale", Vector2.ONE * escala_alvo_jogo, 0.22)
	tw.tween_property(alvo, "modulate:a", 1.0, 0.16)

	await get_tree().create_timer(0.24).timeout

	if is_instance_valid(alvo):
		var id: int = alvo.get_instance_id()
		if dados_alvos.has(id):
			dados_alvos[id]["nascendo"] = false
			alvo.global_position = pos_final
			alvo.scale = Vector2.ONE * escala_alvo_jogo
			alvo.modulate = Color.WHITE
 
 

# ═══════════════════════════════════════════════════════════
#  GERÊNCIA DE ALVOS / SLOTS
# ═══════════════════════════════════════════════════════════
 
func _limpar_alvos() -> void:
	for alvo in alvos_ativos:
		if is_instance_valid(alvo):
			alvo.queue_free()
	alvos_ativos.clear()
	dados_alvos.clear()
	slots_ocupados.clear()
	_garantir_slots()
 


func _fx_sequencia_lanterna(alvo: Area2D, cor: Color) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	var anim: AnimatedSprite2D = _obter_animated_do_alvo(alvo)
	if anim == null:
		return

	var escala_base: Vector2 = anim.scale

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(anim, "scale", escala_base * 1.18, 0.08)
	tw.tween_property(anim, "modulate", Color(cor.r, cor.g, cor.b, 1.0), 0.08)
	tw.tween_property(anim, "scale", escala_base, 0.14).set_delay(0.08)

	_registrar_fx_estilhaco_lanterna(alvo.global_position, cor)



func _fx_hit_lanterna(alvo: Area2D, cor: Color) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	var anim: AnimatedSprite2D = _obter_animated_do_alvo(alvo)
	if anim == null:
		return

	var escala_base: Vector2 = anim.scale

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(anim, "scale", escala_base * 1.22, 0.06)
	tw.tween_property(anim, "modulate", Color(cor.r, cor.g, cor.b, 1.0), 0.06)
	tw.tween_property(anim, "scale", escala_base, 0.14).set_delay(0.06)

 

func _garantir_slots() -> void:
	slots_ocupados.resize(9)
	for i in range(slots_ocupados.size()):
		if typeof(slots_ocupados[i]) != TYPE_BOOL:
			slots_ocupados[i] = false
 
 

func _remover_alvos_invalidos() -> void:
	_garantir_slots()
	for i in range(alvos_ativos.size() - 1, -1, -1):
		var alvo: Area2D = alvos_ativos[i]
		if not is_instance_valid(alvo):
			alvos_ativos.remove_at(i)
			continue
		if not alvo.visible:
			var id: int = alvo.get_instance_id()
			if dados_alvos.has(id):
				var slot: int = int(dados_alvos[id].get("slot", -1))
				if slot >= 0 and slot < slots_ocupados.size():
					slots_ocupados[slot] = false
				dados_alvos.erase(id)
			if is_instance_valid(alvo):
				alvo.queue_free()
			alvos_ativos.remove_at(i)
 


func _configurar_modal_fim() -> void:
	fim_layer = CanvasLayer.new()
	fim_layer.layer = 120
	add_child(fim_layer)

	fim_root = Control.new()
	fim_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	fim_root.visible = false
	fim_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fim_layer.add_child(fim_root)

	fim_bg = ColorRect.new()
	fim_bg.color = Color(0, 0, 0, 0.86)
	fim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	fim_root.add_child(fim_bg)

	fim_panel = Panel.new()
	Leve.stylebox(fim_panel, "panel", _estilo_card_arena())
	fim_root.add_child(fim_panel)

	var linha_topo := ColorRect.new()
	linha_topo.name  = "LinhaTopo"
	linha_topo.color = COR_NEON_ARENA
	fim_panel.add_child(linha_topo)

	var linha_glow := ColorRect.new()
	linha_glow.name  = "LinhaGlow"
	linha_glow.color = Color(COR_NEON_ARENA.r, COR_NEON_ARENA.g, COR_NEON_ARENA.b, 0.22)
	fim_panel.add_child(linha_glow)

	fim_titulo = Label.new()
	fim_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fim_titulo.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(fim_titulo, "font_size", 58)
	Leve.color(fim_titulo, "font_color", COR_NEON_ARENA_CLARO)
	Leve.color(fim_titulo, "font_outline_color", Color.BLACK)
	Leve.constant(fim_titulo, "outline_size", 9)
	fim_panel.add_child(fim_titulo)

	fim_score_label = Label.new()
	fim_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fim_score_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(fim_score_label, "font_size", 78)
	Leve.color(fim_score_label, "font_color", Color.WHITE)
	Leve.color(fim_score_label, "font_outline_color", Color(0.90, 0.0, 0.0))
	Leve.constant(fim_score_label, "outline_size", 10)
	fim_panel.add_child(fim_score_label)

	fim_stats_label = Label.new()
	fim_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fim_stats_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	fim_stats_label.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	Leve.font_size(fim_stats_label, "font_size", 34)
	Leve.color(fim_stats_label, "font_color", Color(1.0, 0.88, 0.88, 1.0))
	Leve.color(fim_stats_label, "font_outline_color", Color.BLACK)
	Leve.constant(fim_stats_label, "outline_size", 6)
	fim_panel.add_child(fim_stats_label)

	fim_footer = Label.new()
	_estilizar_botao_modal_final(fim_footer, Maquina.texto_jogar_novamente(), true)
	fim_panel.add_child(fim_footer)

	fim_contagem_label = Label.new()
	fim_contagem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fim_contagem_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(fim_contagem_label, "font_size", 28)
	Leve.color(fim_contagem_label, "font_color", COR_NEON_ARENA_CLARO)
	Leve.color(fim_contagem_label, "font_outline_color", Color.BLACK)
	Leve.constant(fim_contagem_label, "outline_size", 5)
	fim_panel.add_child(fim_contagem_label)

	_configurar_modal_nome_ranking()
	_ajustar_layout_modal_final()
 

func _configurar_pontos_spawn() -> void:
	posicoes_spawn.clear()

	var tela: Vector2 = get_viewport_rect().size

	# =====================================================
	# AJUSTE INDIVIDUAL DE CADA FURO
	# X = esquerda/direita
	# Y = cima/baixo
	#
	# diminuir X = vai para esquerda
	# aumentar X = vai para direita
	# diminuir Y = sobe
	# aumentar Y = desce
	# =====================================================

	var p_1x1 := Vector2(0.215, 0.399)
	var p_2x1 := Vector2(0.500, 0.399)
	var p_3x1 := Vector2(0.780, 0.399)

	var p_1x2 := Vector2(0.215, 0.560)
	var p_2x2 := Vector2(0.500, 0.560)
	var p_3x2 := Vector2(0.780, 0.560)

	var p_1x3 := Vector2(0.215, 0.730)
	var p_2x3 := Vector2(0.500, 0.730)
	var p_3x3 := Vector2(0.780, 0.730)


	posicoes_spawn.append(Vector2(tela.x * p_1x1.x, tela.y * p_1x1.y)) # 1x1
	posicoes_spawn.append(Vector2(tela.x * p_2x1.x, tela.y * p_2x1.y)) # 2x1
	posicoes_spawn.append(Vector2(tela.x * p_3x1.x, tela.y * p_3x1.y)) # 3x1

	posicoes_spawn.append(Vector2(tela.x * p_1x2.x, tela.y * p_1x2.y)) # 1x2
	posicoes_spawn.append(Vector2(tela.x * p_2x2.x, tela.y * p_2x2.y)) # 2x2
	posicoes_spawn.append(Vector2(tela.x * p_3x2.x, tela.y * p_3x2.y)) # 3x2

	posicoes_spawn.append(Vector2(tela.x * p_1x3.x, tela.y * p_1x3.y)) # 1x3
	posicoes_spawn.append(Vector2(tela.x * p_2x3.x, tela.y * p_2x3.y)) # 2x3
	posicoes_spawn.append(Vector2(tela.x * p_3x3.x, tela.y * p_3x3.y)) # 3x3

	_garantir_slots()
 


func _mostrar_modal_fim() -> void:
	if fim_root == null or fim_score_label == null or fim_stats_label == null:
		_configurar_modal_fim()

	if fim_root == null:
		push_error("Modal final não foi criado corretamente.")
		return

	fim_ativo = true
	ranking_nome_ativo = false
	ranking_ja_salvo = false
	_aplicar_config_admin_na_cena()
	fim_tempo_voltar = float(get_tree().get_meta("admin_tempo_modal_final", fim_tempo_voltar))

	if ranking_nome_layer != null:
		ranking_nome_layer.visible = false

	if fim_layer != null:
		fim_layer.visible = true

	fim_root.visible = true
	fim_root.mouse_filter = Control.MOUSE_FILTER_STOP

	var erros: int = max(tiros - acertos, 0)

	var precisao: int = 0
	if tiros > 0:
		precisao = int(round((float(acertos) / float(tiros)) * 100.0))

	var desempenho: String = "TREINE MAIS"
	if precisao >= 80:
		desempenho = "EXCELENTE"
	elif precisao >= 60:
		desempenho = "MUITO BOM"
	elif precisao >= 40:
		desempenho = "BOM"

	var modo_atual_ranking: String = _obter_modo_ranking()
	var entrou_ranking: bool = _deve_entrar_no_ranking(pontuacao, precisao)

	if fim_titulo != null:
		if entrou_ranking:
			fim_titulo.text = "🏆 NOVO RECORDE!"
			Leve.color(fim_titulo, "font_color", Color(1.0, 0.86, 0.18))
		else:
			fim_titulo.text = "FIM DE JOGO"
			Leve.color(fim_titulo, "font_color", Color(1.0, 0.06, 0.06))

	if fim_score_label != null:
		fim_score_label.text = "PONTUAÇÃO\n%d" % pontuacao

	if fim_stats_label != null:
		if entrou_ranking:
			fim_stats_label.text = "VOCÊ ENTROU NO RANKING!\n\nTIROS: %d     ACERTOS: %d     ERROS: %d\nMODO: %s     PRECISÃO: %d%%\nNÍVEL ALCANÇADO: %d\nDESEMPENHO: %s" % [
				tiros,
				acertos,
				erros,
				modo_atual_ranking,
				precisao,
				nivel_sequencia,
				desempenho
			]
		else:
			fim_stats_label.text = "RESULTADO DA PARTIDA\n\nTIROS: %d     ACERTOS: %d     ERROS: %d\nMODO: %s     PRECISÃO: %d%%\nNÍVEL ALCANÇADO: %d\nDESEMPENHO: %s" % [
				tiros,
				acertos,
				erros,
				modo_atual_ranking,
				precisao,
				nivel_sequencia,
				desempenho
			]

	if fim_footer != null:
		if entrou_ranking:
			_estilizar_botao_modal_final(fim_footer, "PREPARE-SE PARA DIGITAR SEU NOME", true)
		else:
			_estilizar_botao_modal_final(fim_footer, "▶ " + Maquina.texto_jogar_novamente(), true)

	if fim_contagem_label != null:
		if entrou_ranking:
			fim_contagem_label.text = "ABRINDO REGISTRO DO RECORDE..."
		else:
			fim_contagem_label.text = "VOLTANDO AO MENU EM %02d" % int(ceil(fim_tempo_voltar))

	_ajustar_layout_modal_final()

	if fim_panel != null:
		fim_panel.modulate = Color(1, 1, 1, 0)
		fim_panel.scale = Vector2(0.94, 0.94)

		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(fim_panel, "modulate:a", 1.0, 0.22)
		tw.tween_property(fim_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if entrou_ranking:
		fim_tempo_voltar = 9999.0
		await get_tree().create_timer(1.2).timeout
		if fim_ativo and not ranking_ja_salvo:
			_abrir_modal_nome_ranking(pontuacao, "ARENA", precisao)



func _deve_entrar_no_ranking(pontos: int, precisao: int) -> bool:
	var modo_atual_ranking: String = _obter_modo_ranking()

	if Engine.has_singleton("RankingManager"):
		return bool(RankingManager.call(
			"deve_entrar_no_ranking",
			pontos,
			precisao,
			modo_atual_ranking
		))

	if has_node("/root/RankingManager"):
		var rm: Node = get_node("/root/RankingManager")
		return bool(rm.call(
			"deve_entrar_no_ranking",
			pontos,
			precisao,
			modo_atual_ranking
		))

	return false



func _ajustar_layout_modal_final() -> void:
	var tela: Vector2 = get_viewport_rect().size

	if fim_root != null:
		fim_root.size = tela

	if fim_bg != null:
		fim_bg.position = Vector2.ZERO
		fim_bg.size     = tela

	if fim_panel != null:
		var painel_w: float = min(1120.0, tela.x - 60.0)
		var painel_h: float = min(900.0,  tela.y - 70.0)

		fim_panel.size     = Vector2(painel_w, painel_h)
		fim_panel.position = Vector2(
			(tela.x - painel_w) * 0.5,
			(tela.y - painel_h) * 0.5
		).round()

		var linha_topo := fim_panel.get_node_or_null("LinhaTopo") as ColorRect
		if linha_topo != null:
			linha_topo.color    = COR_NEON_ARENA
			linha_topo.position = Vector2.ZERO
			linha_topo.size     = Vector2(painel_w, 7.0)

		var linha_glow := fim_panel.get_node_or_null("LinhaGlow") as ColorRect
		if linha_glow != null:
			linha_glow.color    = Color(COR_NEON_ARENA.r, COR_NEON_ARENA.g, COR_NEON_ARENA.b, 0.22)
			linha_glow.position = Vector2(0, 7)
			linha_glow.size     = Vector2(painel_w, 28.0)

	if fim_titulo != null and fim_panel != null:
		fim_titulo.position = Vector2(40, 30)
		fim_titulo.size     = Vector2(fim_panel.size.x - 80, 76)

	if fim_score_label != null and fim_panel != null:
		fim_score_label.position = Vector2(70, 122)
		fim_score_label.size     = Vector2(fim_panel.size.x - 140, 170)

	if fim_stats_label != null and fim_panel != null:
		fim_stats_label.position  = Vector2(90, 330)
		fim_stats_label.size      = Vector2(fim_panel.size.x - 180, 285)
		fim_stats_label.clip_text = true

	if fim_footer != null and fim_panel != null:
		fim_footer.position = Vector2(120, fim_panel.size.y - 160)
		fim_footer.size     = Vector2(fim_panel.size.x - 240, 70)

	if fim_contagem_label != null and fim_panel != null:
		fim_contagem_label.position = Vector2(80, fim_panel.size.y - 78)
		fim_contagem_label.size     = Vector2(fim_panel.size.x - 160, 46)



# ═══════════════════════════════════════════════════════════
#  DETECÇÃO DE CLIQUE NOS ALVOS
# ═══════════════════════════════════════════════════════════
 
func _detectar_alvo_no_ponto_visual(pos_global: Vector2) -> Area2D:
	for i in range(alvos_ativos.size() - 1, -1, -1):
		var alvo: Area2D = alvos_ativos[i]
		if alvo == null or not is_instance_valid(alvo):
			continue
		if not alvo.visible:
			continue
		if _ponto_esta_sobre_sprite_do_alvo(alvo, pos_global):
			return alvo
	return null
 

 
func _ponto_esta_sobre_sprite_do_alvo(alvo: Area2D, pos_global: Vector2) -> bool:
	var anim: AnimatedSprite2D = _obter_animated_do_alvo(alvo)
	if anim == null or anim.sprite_frames == null:
		return false

	var tex: Texture2D = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	if tex == null:
		return false

	var escala: Vector2 = anim.global_scale
	var largura: float = tex.get_width() * abs(escala.x)
	var altura: float = tex.get_height() * abs(escala.y)

	# Centro visual ajustado para o corpo redondo da lanterna.
	# Positivo no Y desce o centro.
	var centro: Vector2 = anim.global_position + Vector2(0.0, altura * 0.08)

	# Área redonda maior, sem pegar o sprite inteiro.
	var raio: float = min(largura, altura) * 0.36

	return centro.distance_to(pos_global) <= raio
 

 
func _obter_animated_do_alvo(alvo: Area2D) -> AnimatedSprite2D:
	if alvo == null:
		return null
	for filho in alvo.get_children():
		if filho is AnimatedSprite2D:
			return filho as AnimatedSprite2D
	return null
 

 
func _resetar_visual_arco(alvo: Area2D) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	var anim: AnimatedSprite2D = _obter_animated_do_alvo(alvo)
	if anim == null:
		return

	anim.visible = true
	anim.show()
	anim.process_mode = Node.PROCESS_MODE_INHERIT
	anim.position = Vector2.ZERO
	anim.rotation_degrees = 0.0
	anim.scale = Vector2.ONE
	anim.modulate = Color.WHITE

	if anim.sprite_frames != null:
		if anim.sprite_frames.has_animation("idle"):
			anim.play("idle")
		elif anim.sprite_frames.has_animation("default"):
			anim.play("default")
		elif anim.sprite_frames.get_animation_names().size() > 0:
			anim.play(String(anim.sprite_frames.get_animation_names()[0]))


 
# ═══════════════════════════════════════════════════════════
#  EFEITOS VISUAIS DE COLISÃO
# ═══════════════════════════════════════════════════════════
 
func _registrar_fx_colisao(pos: Vector2, pontos_ganhos: int, cor: Color) -> void:
	var quantidade: int = 18
	if pontos_ganhos >= 100:
		quantidade = 42
	elif pontos_ganhos >= 50:
		quantidade = 28
 
	for i in range(quantidade):
		var ang: float = randf_range(0.0, TAU)
		var vel: Vector2 = Vector2.RIGHT.rotated(ang) * randf_range(80.0, 420.0)
		fx_colisao.append({
			"pos":   pos,
			"vel":   vel,
			"vida":  randf_range(0.28, 0.72),
			"idade": 0.0,
			"tam":   randf_range(3.0, 9.0),
			"cor":   cor
		})
 
	if pontos_ganhos > 0:
		fx_colisao.append({
			"texto": "+%d" % pontos_ganhos,
			"pos":   pos + Vector2(0, -34),
			"vel":   Vector2(0, -75),
			"vida":  0.72,
			"idade": 0.0,
			"tam":   28.0,
			"cor":   cor
		})
	else:
		fx_colisao.append({
			"texto": "ERROU",
			"pos":   pos + Vector2(0, -28),
			"vel":   Vector2(0, -55),
			"vida":  0.58,
			"idade": 0.0,
			"tam":   24.0,
			"cor":   Color.RED
		})
 
 
func _atualizar_fx_colisao(delta: float) -> void:
	for i in range(fx_colisao.size() - 1, -1, -1):
		var fx: Dictionary = fx_colisao[i]
		var idade: float   = float(fx.get("idade", 0.0)) + delta
		var vida: float    = float(fx.get("vida", 0.4))
		if idade >= vida:
			fx_colisao.remove_at(i)
			continue
		var pos: Vector2 = fx.get("pos", Vector2.ZERO)
		var vel: Vector2 = fx.get("vel", Vector2.ZERO)
		vel.y += 380.0 * delta
		pos   += vel * delta
		fx["idade"] = idade
		fx["pos"]   = pos
		fx["vel"]   = vel
		fx_colisao[i] = fx
 
 
func _desenhar_fx_colisao() -> void:
	if fx_layer_jogo == null:
		return

	for fx in fx_colisao:
		var idade: float = float(fx.get("idade", 0.0))
		var vida: float = max(float(fx.get("vida", 0.4)), 0.01)
		var alpha: float = clamp(1.0 - idade / vida, 0.0, 1.0)

		var pos: Vector2 = fx.get("pos", Vector2.ZERO)
		var cor: Color = fx.get("cor", Color.WHITE)
		cor.a *= alpha

		if fx.has("texto"):
			var fonte := ThemeDB.fallback_font
			fx_layer_jogo.draw_string(fonte, pos, str(fx.get("texto", "")), HORIZONTAL_ALIGNMENT_CENTER, 240.0, int(fx.get("tam", 24.0)), cor)

		elif bool(fx.get("fumaca", false)):
			var tam_fumaca: float = float(fx.get("tam", 10.0))
			Pincel.forma(fx_layer_jogo, Pincel.FUMACA, pos, tam_fumaca * alpha, cor)

		elif bool(fx.get("metal", false)):
			var tam: float = float(fx.get("tam", 5.0))
			Pincel.caco(fx_layer_jogo, pos, tam, idade * 9.0, cor)

		else:
			var tam2: float = float(fx.get("tam", 5.0))
			Pincel.circulo(fx_layer_jogo, pos, tam2 * alpha, cor)
			Pincel.circulo(fx_layer_jogo, pos, tam2 * 0.38 * alpha, Color.WHITE)

 
# ═══════════════════════════════════════════════════════════
#  MENSAGENS DE RODAPÉ
# ═══════════════════════════════════════════════════════════
 
func _adicionar_chat_rodape(texto: String, cor: Color) -> void:
	# Mantém SOMENTE a mensagem principal atual
	status_msgs.clear()

	status_msgs.append({
		"text": texto,
		"cor": cor
	})

	_atualizar_status_labels()
 
 
func _atualizar_chat_rodape(delta: float) -> void:
	# Chat fixo: não remove mensagens por tempo.
	# As mensagens só são trocadas quando uma nova jogada acontece.
	_atualizar_status_labels()
 
 
func _atualizar_status_labels() -> void:
	var tem_msg: bool = status_msgs.size() > 0

	if chat_rodape_panel != null:
		chat_rodape_panel.visible = tem_msg

	for i in range(status_labels.size()):
		var lbl: Label = status_labels[i]

		if lbl == null:
			continue

		if i == 0 and tem_msg:
			var msg: Dictionary = status_msgs[0]
			var texto: String = str(msg.get("text", ""))
			var cor: Color = msg.get("cor", Color.WHITE)

			lbl.text = texto
			lbl.visible = true
			lbl.scale = Vector2.ONE
			lbl.modulate = Color(cor.r, cor.g, cor.b, 1.0)

			Leve.font_size(lbl, "font_size", 40)
			Leve.color(lbl, "font_color", Color.WHITE)
			Leve.color(lbl, "font_outline_color", Color.BLACK)
			Leve.constant(lbl, "outline_size", 8)

			if chat_rodape_panel != null:
				var estilo := chat_rodape_panel.get_theme_stylebox("panel") as StyleBoxFlat
				if estilo == null:
					estilo = _estilo_card_arena()
					Leve.stylebox(chat_rodape_panel, "panel", estilo)

				Leve.prop(estilo, "bg_color", Color(0.025, 0.0, 0.0, 0.86))
				Leve.prop(estilo, "border_color", cor)
				Leve.prop(estilo, "shadow_color", Color(cor.r, cor.g, cor.b, 0.72))
				Leve.prop(estilo, "shadow_size", 34)

				chat_rodape_panel.modulate = Color.WHITE

				var tw := create_tween()
				tw.tween_property(chat_rodape_panel, "scale", Vector2(1.015, 1.10), 0.07)
				tw.tween_property(chat_rodape_panel, "scale", Vector2.ONE, 0.14)

		else:
			lbl.visible = false
 
 

# ═══════════════════════════════════════════════════════════
#  MUNIÇÃO E RECARGA
# ═══════════════════════════════════════════════════════════
 
func _iniciar_recarga() -> void:
	if not jogo_ativo or recarregando:
		return
	if municao_atual >= capacidade_cartucho:
		return
		
	_resetar_timer_jogada()
	
	recarregando          = true
	reload_tempo_restante = tempo_recarga_seg
	if audio_recarga != null:
		audio_recarga.stop()
		audio_recarga.play()
	_atualizar_hud()
	if mira_root != null:
		mira_root.queue_redraw()
 
 
func _finalizar_recarga() -> void:
	recarregando          = false
	reload_tempo_restante = 0.0
	municao_atual         = capacidade_cartucho
	_atualizar_hud()
	if mira_root != null:
		mira_root.queue_redraw()
 
 
# ═══════════════════════════════════════════════════════════
#  FLUXO DE PARTIDA
# ═══════════════════════════════════════════════════════════
 
func _iniciar_partida() -> void:
	jogo_iniciado          = true
	jogo_ativo             = true
	intro_comeco_ativa     = false
	tempo_restante         = tempo_total
	pontuacao              = 0
	tiros                  = 0
	acertos                = 0
	municao_atual          = capacidade_cartucho
	recarregando           = false
	reload_tempo_restante  = 0.0
	nivel_sequencia        = 1
	indice_sequencia       = 0
	sequencia_atual.clear()
	mostrando_sequencia    = false
	bloqueia_tiro_sequencia = false
	
	if info_inicio_texture != null:
		info_inicio_texture.visible = false
 
	if modal_layer != null:
		modal_layer.visible = false
	if countdown_root != null:
		countdown_root.visible = false
 
	_limpar_alvos()
	timer_jogo.start()
	timer_spawn.stop()
 
	_gerar_onda_inicial()
	_atualizar_hud()
 
	call_deferred("_iniciar_nova_sequencia")
 
 
func _encerrar_partida() -> void:
	if not jogo_ativo:
		return

	jogo_ativo = false
	jogo_iniciado = true
	intro_comeco_ativa = false
	recarregando = false
	reload_tempo_restante = 0.0
	mostrando_sequencia = false
	bloqueia_tiro_sequencia = true

	timer_jogo.stop()
	timer_spawn.stop()

	# LIMPA O QUE FICAVA FEIO/TRAVADO NO FUNDO
	_limpar_alvos()
	fx_colisao.clear()
	marcas_laser_parede.clear()
	status_msgs.clear()

	if fx_layer_jogo != null:
		fx_layer_jogo.queue_redraw()

	for lbl in status_labels:
		if lbl != null:
			lbl.visible = false

	if hud_layer_codigo != null:
		hud_layer_codigo.visible = false

	if mira_layer != null:
		mira_layer.visible = false

	if countdown_root != null:
		countdown_root.visible = false

	if modal_layer != null:
		modal_layer.visible = false

	_atualizar_hud()
	_parar_musica_arena()
	_mostrar_modal_fim()

	print("Fim de jogo — Pontuação: %d  |  Nível: %d" % [pontuacao, nivel_sequencia])

 
# ═══════════════════════════════════════════════════════════
#  TIMERS
# ═══════════════════════════════════════════════════════════
 
func _on_timer_jogo_timeout() -> void:
	if not jogo_ativo:
		return
	tempo_restante -= 1.0
	if tempo_restante <= 0.0:
		tempo_restante = 0.0
		_atualizar_hud()
		_encerrar_partida()
		return
	_atualizar_hud()
 
 
func _on_timer_spawn_timeout() -> void:
	if not jogo_ativo:
		return
	_garantir_3_alvos()
 
 
func _on_viewport_size_changed() -> void:
	_configurar_background_fullscreen()
	_configurar_pontos_spawn()
	_reposicionar_modal()
	_reposicionar_intro_comeco()
	_ajustar_layout_hud_bar()
	_atualizar_hud()
 
 
# ═══════════════════════════════════════════════════════════
#  MIRA CUSTOMIZADA
# ═══════════════════════════════════════════════════════════
 
func _configurar_mira() -> void:
	mira_layer       = CanvasLayer.new()
	mira_layer.layer = 100
	add_child(mira_layer)
 
	mira_root = Control.new()
	mira_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	mira_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mira_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mira_layer.add_child(mira_root)
 
	mira_root.draw.connect(_desenhar_mira)
 
 
func _desenhar_mira() -> void:
	var dificuldade: String = get_tree().get_meta("modo_dificuldade", "facil")

	# No difícil, a mira só aparece no modal de nome do ranking
	if dificuldade == "dificil" and not ranking_nome_ativo:
		return

	if mira_root == null:
		return

	var cor_principal := Color(1.0, 0.04, 0.04, 0.95)

	if ranking_nome_ativo:
		cor_principal = Color(1.0, 0.04, 0.04, 1.0)
	elif mostrando_sequencia or bloqueia_tiro_sequencia:
		cor_principal = Color(0.60, 0.60, 0.60, 0.70)
	elif recarregando:
		cor_principal = Color(0.20, 0.85, 1.0, 0.95)
	elif municao_atual <= 0:
		cor_principal = Color(1.0, 0.12, 0.08, 0.95)
	elif municao_atual <= alerta_baixa_municao_limite:
		cor_principal = Color(1.0, 0.45, 0.05, 0.95)

	Pincel.anel(mira_root, mira_pos, 20.0, 3.0, cor_principal)
	Pincel.anel(mira_root, mira_pos, 8.0, 1.4, Color.WHITE)
	Pincel.circulo(mira_root, mira_pos, 2.6, Color.WHITE)
	Pincel.linha(mira_root, mira_pos + Vector2(-27, 0), mira_pos + Vector2(-9, 0), Color.WHITE, 2.2)
	Pincel.linha(mira_root, mira_pos + Vector2(9, 0), mira_pos + Vector2(27, 0), Color.WHITE, 2.2)
	Pincel.linha(mira_root, mira_pos + Vector2(0, -27), mira_pos + Vector2(0, -9), Color.WHITE, 2.2)
	Pincel.linha(mira_root, mira_pos + Vector2(0, 9), mira_pos + Vector2(0, 27), Color.WHITE, 2.2)

	if recarregando and not ranking_nome_ativo:
		var pct: float = 1.0 - clamp(reload_tempo_restante / max(tempo_recarga_seg, 0.01), 0.0, 1.0)
		Pincel.arco(mira_root, mira_pos, 34.0, -PI / 2.0, -PI / 2.0 + TAU * pct, Color(0.20, 0.85, 1.0, 1.0), 5.0)

# ═══════════════════════════════════════════════════════════
#  HUD
# ═══════════════════════════════════════════════════════════
 
func _configurar_hud_bar_padrao() -> void:
	if hud_layer != null:
		hud_layer.visible = false
 
	hud_layer_codigo       = CanvasLayer.new()
	hud_layer_codigo.name  = "HudBarPadraoArena"
	hud_layer_codigo.layer = 80
	add_child(hud_layer_codigo)
 
	hud_root = Control.new()
	hud_root.name = "HudRoot"
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer_codigo.add_child(hud_root)
 
	top_bar_sombra         = ColorRect.new()
	top_bar_sombra.color   = Color(0, 0, 0, 0.42)
	top_bar_sombra.visible = false
	hud_root.add_child(top_bar_sombra)

	top_bar = Panel.new()
	Leve.stylebox(top_bar, "panel", _estilo_card_arena())
	hud_root.add_child(top_bar)

	top_bar_linha         = ColorRect.new()
	top_bar_linha.color   = Color(0.90, 0.02, 0.02, 1.0)
	top_bar_linha.visible = false
	hud_root.add_child(top_bar_linha)

	timer_panel   = _criar_painel_bar()
	score_panel   = _criar_painel_bar()
	municao_panel = _criar_painel_bar()

	stats_arena_panel = Panel.new()
	Leve.stylebox(stats_arena_panel, "panel", _estilo_card_arena())
	stats_arena_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(stats_arena_panel)
 
	timer_title_label  = _criar_label_hud("TEMPO",     18, Color(1.0, 0.05, 0.05, 1.0))
	timer_label        = _criar_label_hud("02:00",     44, Color.WHITE)
	score_title_label  = _criar_label_hud("PONTUAÇÃO", 18, Color(1.0, 0.05, 0.05, 1.0))
	score_label        = _criar_label_hud("0",         64, Color.WHITE)
	municao_title_label = _criar_label_hud("MUNIÇÃO",  16, Color(1.0, 0.05, 0.05, 1.0))
	municao_label      = _criar_label_hud("30/30",     15, Color.WHITE)
	recarga_label = _criar_label_hud(
			_texto_hud_recarga_padrao(),
			13,
			Color(0.76, 0.88, 1.0, 0.95)
		)
	acertos_title_label = _criar_label_hud("ACERTOS",  15, Color(1.0, 0.05, 0.05, 1.0))
	acertos_label      = _criar_label_hud("0",         32, Color.WHITE)
	tiros_title_label  = _criar_label_hud("TIROS",     14, Color(1.0, 0.05, 0.05, 1.0))
	tiros_label        = _criar_label_hud("0",         30, Color.WHITE)
	nivel_title_label  = _criar_label_hud("NÍVEL",     15, Color(1.0, 0.05, 0.05, 1.0))
	nivel_label        = _criar_label_hud("1",         32, Color(0.30, 0.85, 1.0, 1.0))
 
	hud_root.add_child(timer_title_label)
	hud_root.add_child(timer_label)
	hud_root.add_child(score_title_label)
	hud_root.add_child(score_label)
	hud_root.add_child(municao_title_label)
	hud_root.add_child(municao_label)
	hud_root.add_child(recarga_label)
	hud_root.add_child(acertos_title_label)
	hud_root.add_child(acertos_label)
	hud_root.add_child(tiros_title_label)
	hud_root.add_child(tiros_label)
	hud_root.add_child(nivel_title_label)
	hud_root.add_child(nivel_label)
	
	chat_rodape_panel = Panel.new()
	chat_rodape_panel.name = "ChatRodapePanel"
	Leve.stylebox(chat_rodape_panel, "panel", _estilo_card_arena())
	chat_rodape_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_rodape_panel.visible = false
	hud_root.add_child(chat_rodape_panel)
 
	for lbl_antigo in status_labels:
		if lbl_antigo != null and is_instance_valid(lbl_antigo):
			lbl_antigo.queue_free()
	status_labels.clear()
 
	for i in range(3):
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		Leve.font_size(lbl, "font_size", 34 - (i * 4))
		Leve.color(lbl, "font_color", Color.WHITE)
		Leve.color(lbl, "font_outline_color", Color.BLACK)
		Leve.constant(lbl, "outline_size", 7)
		lbl.visible = false
		hud_root.add_child(lbl)
		status_labels.append(lbl)
 
	_criar_blocos_municao_bar()
	_ajustar_layout_hud_bar()
	_atualizar_hud()
 
 
func _criar_painel_bar() -> Panel:
	var painel := Panel.new()
	Leve.stylebox(painel, "panel", _estilo_card_arena())
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(painel)
	return painel
 
 
func _criar_label_hud(texto: String, tamanho: int, cor: Color) -> Label:
	var lbl := Label.new()
	lbl.text = texto
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(lbl, "font_size", tamanho)
	Leve.color(lbl, "font_color", cor)
	Leve.color(lbl, "font_outline_color", Color.BLACK)
	Leve.constant(lbl, "outline_size", 4)
	return lbl
 
 

func _ajustar_layout_hud_bar() -> void:
	var tela: Vector2 = get_viewport_rect().size
	var tela_w: int = int(round(tela.x))

	if hud_root != null:
		hud_root.size = tela

	if top_bar != null:
		top_bar.position = Vector2(8, 8)
		top_bar.size = Vector2(tela_w - 16, 230)

	if top_bar_sombra != null:
		top_bar_sombra.visible = false

	if top_bar_linha != null:
		top_bar_linha.visible = false

	var py: int = 22
	var ph: int = 198
	var gap: int = 14

	# TEMPO
	var tp_x: int = 22
	var tp_w: int = 210

	if timer_panel != null:
		timer_panel.position = Vector2(tp_x, py)
		timer_panel.size = Vector2(tp_w, ph)

	if timer_title_label != null:
		timer_title_label.position = Vector2(tp_x, py + 16)
		timer_title_label.size = Vector2(tp_w, 28)

	if timer_label != null:
		timer_label.position = Vector2(tp_x, py + 58)
		timer_label.size = Vector2(tp_w, 66)

	# PONTUAÇÃO
	var sc_x: int = tp_x + tp_w + gap
	var sc_w: int = 360

	if score_panel != null:
		score_panel.position = Vector2(sc_x, py)
		score_panel.size = Vector2(sc_w, ph)

	if score_title_label != null:
		score_title_label.position = Vector2(sc_x, py + 16)
		score_title_label.size = Vector2(sc_w, 28)

	if score_label != null:
		score_label.position = Vector2(sc_x, py + 48)
		score_label.size = Vector2(sc_w, 92)

	# STATS: NÍVEL / ACERTOS / TIROS
	var st_w: int = 190
	var st_x: int = tela_w - st_w - 22

	if stats_arena_panel != null:
		stats_arena_panel.position = Vector2(st_x, py)
		stats_arena_panel.size = Vector2(st_w, ph)

	var st_pad: int = 12

	if nivel_title_label != null:
		nivel_title_label.position = Vector2(st_x + st_pad, py + 10)
		nivel_title_label.size = Vector2(st_w - st_pad * 2, 20)

	if nivel_label != null:
		nivel_label.position = Vector2(st_x + st_pad, py + 30)
		nivel_label.size = Vector2(st_w - st_pad * 2, 34)

	if acertos_title_label != null:
		acertos_title_label.position = Vector2(st_x + st_pad, py + 72)
		acertos_title_label.size = Vector2(st_w - st_pad * 2, 20)

	if acertos_label != null:
		acertos_label.position = Vector2(st_x + st_pad, py + 92)
		acertos_label.size = Vector2(st_w - st_pad * 2, 34)

	if tiros_title_label != null:
		tiros_title_label.position = Vector2(st_x + st_pad, py + 134)
		tiros_title_label.size = Vector2(st_w - st_pad * 2, 20)

	if tiros_label != null:
		tiros_label.position = Vector2(st_x + st_pad, py + 154)
		tiros_label.size = Vector2(st_w - st_pad * 2, 34)

	# MUNIÇÃO
	var mu_x: int = sc_x + sc_w + gap
	var mu_w: int = st_x - mu_x - gap

	if mu_w < 250:
		mu_w = 250
		mu_x = st_x - mu_w - gap

	if municao_panel != null:
		municao_panel.position = Vector2(mu_x, py)
		municao_panel.size = Vector2(mu_w, ph)

	if municao_title_label != null:
		municao_title_label.position = Vector2(mu_x, py + 12)
		municao_title_label.size = Vector2(mu_w, 24)

	if municao_label != null:
		municao_label.position = Vector2(mu_x, py + 104)
		municao_label.size = Vector2(mu_w, 30)

	if recarga_label != null:
		recarga_label.position = Vector2(mu_x, py + 142)
		recarga_label.size = Vector2(mu_w, 32)

	# CHAT / STATUS RODAPÉ COM BARRA NEON
	var chat_w: float = float(tela_w) - 48.0
	var chat_h: float = 68.0
	var chat_x: float = 24.0
	var chat_y: float = tela.y - 104.0

	if chat_rodape_panel != null:
		chat_rodape_panel.position = Vector2(chat_x, chat_y)
		chat_rodape_panel.size = Vector2(chat_w, chat_h)

	for i in range(status_labels.size()):
		var lbl := status_labels[i]
		if lbl == null:
			continue

		if i == 0:
			lbl.position = Vector2(chat_x + 18.0, chat_y + 4.0)
			lbl.size = Vector2(chat_w - 36.0, chat_h - 8.0)
		else:
			lbl.visible = false

	_atualizar_barra_municao_bar()

 
 
func _criar_blocos_municao_bar() -> void:
	municao_blocos.clear()
	if municao_panel == null:
		return
	for filho in municao_panel.get_children():
		if filho is ColorRect and str(filho.name).begins_with("BlocoMunicao_"):
			filho.queue_free()
	for i in range(capacidade_cartucho):
		var bloco := ColorRect.new()
		bloco.name  = "BlocoMunicao_%02d" % i
		bloco.color = Color(0.20, 0.24, 0.30, 0.95)
		municao_panel.add_child(bloco)
		municao_blocos.append(bloco)
 
 
func _atualizar_barra_municao_bar() -> void:
	if municao_panel == null or municao_blocos.is_empty():
		return

	var margem_x: float = 16.0
	var margem_topo_b: float = 48.0
	var largura_util: float = municao_panel.size.x - (margem_x * 2.0)
	var espacamento: float = 3.0
	var total_blocos: int = municao_blocos.size()

	if total_blocos <= 0:
		return

	var largura_bloco: float = (largura_util - (espacamento * float(total_blocos - 1))) / float(total_blocos)
	var altura_bloco: float = 38.0

	for i in range(total_blocos):
		var bloco := municao_blocos[i]
		if bloco == null:
			continue

		bloco.position = Vector2(
			margem_x + (largura_bloco + espacamento) * float(i),
			margem_topo_b
		).round()

		bloco.size = Vector2(max(largura_bloco, 2.0), altura_bloco)

		var ativo: bool = i < municao_atual

		if recarregando:
			var pulso: float = 0.58 + (sin(aviso_recarga_t * 10.0 + float(i) * 0.18) * 0.5 + 0.5) * 0.42
			bloco.color = Color(0.22, 0.92, 1.0, pulso)
		elif not ativo:
			bloco.color = Color(0.16, 0.18, 0.22, 0.42)
		elif municao_atual <= alerta_baixa_municao_limite:
			bloco.color = Color(1.0, 0.30, 0.12, 1.0)
		else:
			bloco.color = Color(0.92, 0.02, 0.02, 1.0)
 
 

func _atualizar_hud() -> void:
	if score_label != null:
		score_label.text = str(pontuacao)
		if pontuacao > 0:
			score_label.modulate = Color(0.42, 1.0, 0.52, 1.0)
		elif pontuacao < 0:
			score_label.modulate = Color(1.0, 0.28, 0.28, 1.0)
		else:
			score_label.modulate = Color(1.0, 0.93, 0.25, 1.0)

	if timer_label != null:
		var minutos: int = int(tempo_restante) / 60
		var segundos: int = int(tempo_restante) % 60
		timer_label.text = "%02d:%02d" % [minutos, segundos]

	if tiros_label != null:
		tiros_label.text = str(tiros)

	if acertos_label != null:
		acertos_label.text = str(acertos)

	if nivel_label != null:
		nivel_label.text = str(nivel_sequencia)

	if municao_panel != null and municao_label != null:
		if recarregando:
			var pulso_rec: float = 0.70 + (sin(aviso_recarga_t * 10.0) * 0.5 + 0.5) * 0.30
			_set_estilo_panel_arena(municao_panel, Color(0.08, 0.22, 0.30, 0.98), Color(0.20, 0.85, 1.0), 0.70)
			municao_label.text = "RECARREGANDO"
			municao_label.modulate = Color(0.30, 0.92, 1.0, pulso_rec)
			if recarga_label != null:
				recarga_label.text = _texto_hud_recarregando()
				recarga_label.modulate = Color(0.78, 0.96, 1.0, pulso_rec)

		elif municao_atual <= 0:
			var pulso_vazio: float = 0.60 + (sin(aviso_recarga_t * 12.0) * 0.5 + 0.5) * 0.40
			_set_estilo_panel_arena(municao_panel, Color(0.22, 0.04, 0.05, 1.0), COR_NEON_ARENA, 0.70)
			municao_label.text = "RECARREGUE!"
			municao_label.modulate = Color(1.0, 0.24, 0.22, pulso_vazio)
			if recarga_label != null:
				recarga_label.text = _texto_hud_sem_municao()
				recarga_label.modulate = Color(1.0, 0.72, 0.72, pulso_vazio)

		elif municao_atual <= alerta_baixa_municao_limite:
			var pulso_crit: float = 0.72 + (sin(aviso_recarga_t * 9.0) * 0.5 + 0.5) * 0.28
			_set_estilo_panel_arena(municao_panel, Color(0.20, 0.11, 0.03, 1.0), Color(1.0, 0.62, 0.12), 0.62)
			municao_label.text = "MUNIÇÃO BAIXA"
			municao_label.modulate = Color(1.0, 0.68, 0.18, pulso_crit)
			if recarga_label != null:
				recarga_label.text = _texto_hud_municao_baixa()
				recarga_label.modulate = Color(1.0, 0.84, 0.48, pulso_crit)

		else:
			_set_estilo_panel_arena(municao_panel, COR_FUNDO_CARD_ARENA, COR_NEON_ARENA, 0.60)
			municao_label.text = "%02d/%02d" % [municao_atual, capacidade_cartucho]
			municao_label.modulate = Color.WHITE
			if recarga_label != null:
				recarga_label.text = _texto_hud_recarga_padrao()
				recarga_label.modulate = Color(0.76, 0.88, 1.0, 0.95)

	_atualizar_barra_municao_bar()
 

# ═══════════════════════════════════════════════════════════
#  CONTAGEM REGRESSIVA (INTRO)
# ═══════════════════════════════════════════════════════════
 
func _criar_intro_comeco() -> void:
	countdown_layer = CanvasLayer.new()
	countdown_layer.name = "CountdownLayer"
	countdown_layer.layer = 110
	add_child(countdown_layer)

	countdown_root = Control.new()
	countdown_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	countdown_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_root.visible = false
	countdown_layer.add_child(countdown_root)

	countdown_flash = ColorRect.new()
	countdown_flash.color = Color(0.16, 0.0, 0.0, 0.48)
	countdown_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	countdown_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_root.add_child(countdown_flash)

	countdown_label = Label.new()
	countdown_label.text = "3"
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(countdown_label, "font_size", 156)
	Leve.color(countdown_label, "font_color", COR_NEON_ARENA_CLARO)
	Leve.color(countdown_label, "font_outline_color", Color(0.18, 0.0, 0.0, 1.0))
	Leve.constant(countdown_label, "outline_size", 16)
	countdown_label.self_modulate = Color(1.0, 0.90, 0.90, 1.0)

	var fonte_luckies := load("res://fonts/LuckiestGuy-Regular.ttf")
	if fonte_luckies:
		Leve.font(countdown_label, "font", fonte_luckies)

	countdown_label.visible = false
	countdown_root.add_child(countdown_label)

	_reposicionar_intro_comeco()
 
 
func _reposicionar_intro_comeco() -> void:
	if countdown_label == null:
		return

	var vp: Vector2 = get_viewport_rect().size
	countdown_label.position = Vector2.ZERO
	countdown_label.size = vp
	countdown_label.pivot_offset = vp * 0.5
 
 

func _iniciar_intro_comeco() -> void:
	if intro_comeco_ativa:
		return

	intro_comeco_ativa = true
	intro_comeco_t = 0.0
	intro_contagem_valor = 3

	if modal_layer != null:
		modal_layer.visible = false

	if info_inicio_texture != null:
		info_inicio_texture.visible = false

	if modal_atire_label != null:
		modal_atire_label.visible = false

	if countdown_root != null:
		countdown_root.visible = true

	if countdown_flash != null:
		countdown_flash.visible = true
		countdown_flash.color = Color(0.0, 0.0, 0.0, 0.42)

	if countdown_label != null:
		countdown_label.visible = true

	_contagem_intro_async()
 


func _contagem_intro_async() -> void:
	var valores := ["3", "2", "1", "COMEÇOU!"]

	for v in valores:
		if not is_inside_tree():
			return

		if countdown_label != null:
			countdown_label.text = v
			countdown_label.visible = true
			countdown_label.modulate = Color(1, 1, 1, 0.0)
			Leve.color(countdown_label, "font_color", COR_NEON_ARENA_CLARO)
			Leve.color(countdown_label, "font_outline_color", Color(0.18, 0.0, 0.0, 1.0))
			Leve.constant(countdown_label, "outline_size", 16)

			if v == "COMEÇOU!":
				Leve.font_size(countdown_label, "font_size", 88)
				countdown_label.scale = Vector2.ONE * 0.82
			else:
				Leve.font_size(countdown_label, "font_size", 156)
				countdown_label.scale = Vector2.ONE * 0.62

		var tw := create_tween()
		tw.set_parallel(true)

		if countdown_flash != null:
			countdown_flash.color = Color(1.0, 0.02, 0.02, 0.0)
			tw.tween_property(countdown_flash, "color:a", 0.20, 0.08)
			tw.tween_property(countdown_flash, "color:a", 0.0, 0.24).set_delay(0.08)

		if countdown_label != null:
			tw.tween_property(countdown_label, "modulate:a", 1.0, 0.12)
			tw.tween_property(countdown_label, "scale", Vector2.ONE * 1.06, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(countdown_label, "scale", Vector2.ONE, 0.18).set_delay(0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(countdown_label, "modulate:a", 0.0, 0.20).set_delay(0.58)

		await get_tree().create_timer(0.84).timeout

	if countdown_root != null:
		countdown_root.visible = false

	intro_comeco_ativa = false
	_iniciar_partida()


 
func _rodar_intro_comeco_async() -> void:
	for numero in [3, 2, 1]:
		if not is_inside_tree():
			return
		intro_contagem_valor = numero
		intro_comeco_t       = 0.0
 
		if countdown_label != null:
			countdown_label.text     = str(numero)
			countdown_label.visible  = true
			countdown_label.modulate = Color(1, 1, 1, 0.0)
			countdown_label.scale    = Vector2.ONE * 0.62
			Leve.font_size(countdown_label, "font_size", 120)
 
		var tw_num := create_tween()
		tw_num.set_parallel(true)
 
		if countdown_flash != null:
			countdown_flash.color = Color(1.0, 1.0, 1.0, 0.0)
			tw_num.tween_property(countdown_flash, "color:a", 0.10, 0.06)
			tw_num.tween_property(countdown_flash, "color:a", 0.0,  0.16).set_delay(0.06)
 
		if countdown_label != null:
			tw_num.tween_property(countdown_label, "modulate:a", 1.0, 0.10)
			tw_num.tween_property(countdown_label, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_num.tween_property(countdown_label, "modulate:a", 0.0, 0.16).set_delay(0.46)
 
		await get_tree().create_timer(0.72).timeout
 
	if not is_inside_tree():
		return
 
	intro_comeco_t = 0.0
 
	if countdown_label != null:
		countdown_label.text     = "COMEÇOU!"
		countdown_label.visible  = true
		countdown_label.modulate = Color(1, 1, 1, 0.0)
		countdown_label.scale    = Vector2.ONE * 0.82
		Leve.font_size(countdown_label, "font_size", 76)
 
	var tw_go := create_tween()
	tw_go.set_parallel(true)
 
	if countdown_flash != null:
		countdown_flash.color = Color(1.0, 1.0, 1.0, 0.0)
		tw_go.tween_property(countdown_flash, "color:a", 0.14, 0.08)
		tw_go.tween_property(countdown_flash, "color:a", 0.0,  0.18).set_delay(0.08)
 
	if countdown_label != null:
		tw_go.tween_property(countdown_label, "modulate:a", 1.0, 0.10)
		tw_go.tween_property(countdown_label, "scale", Vector2.ONE * 0.92, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_go.tween_property(countdown_label, "modulate:a", 0.0, 0.18).set_delay(0.34)
 
	await get_tree().create_timer(0.60).timeout
 
	if countdown_root != null:
		countdown_root.visible = false
 
	_iniciar_partida()
 

func _tocar_bip() -> void:
	if audio_bip == null:
		push_warning("audio_bip não foi criado.")
		return

	if audio_bip.stream == null:
		push_warning("bip.mp3 não foi carregado. Confira: " + caminho_som_bip)
		return

	audio_bip.volume_db = 12.0
	audio_bip.pitch_scale = 1.0
	audio_bip.stop()
	audio_bip.play()

 
# ═══════════════════════════════════════════════════════════
#  MODAL DE INÍCIO
# ═══════════════════════════════════════════════════════════
 
func _criar_modal_inicio() -> void:
	if modal_layer != null and is_instance_valid(modal_layer):
		modal_layer.queue_free()

	modal_layer = CanvasLayer.new()
	modal_layer.name = "ModalInfoArenaLayer"
	modal_layer.layer = 95
	modal_layer.visible = true
	add_child(modal_layer)

	modal_root = Control.new()
	modal_root.name = "ModalInfoArenaRoot"
	modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_layer.add_child(modal_root)

	var bg_escuro := ColorRect.new()
	bg_escuro.name = "ArenaModalBgEscuro"
	bg_escuro.color = Color(0.0, 0.0, 0.0, 0.72)
	bg_escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(bg_escuro)

	var glow_img := ColorRect.new()
	glow_img.name = "GlowImagemInicioArena"
	glow_img.color = Color(1.0, 0.02, 0.02, 0.18)
	glow_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_root.add_child(glow_img)

	var borda_img := ColorRect.new()
	borda_img.name = "BordaImagemInicioArena"
	borda_img.color = COR_NEON_ARENA
	borda_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_root.add_child(borda_img)

	var fundo_img := ColorRect.new()
	fundo_img.name = "FundoImagemInicioArena"
	fundo_img.color = Color(0.060, 0.004, 0.004, 0.96)
	fundo_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_root.add_child(fundo_img)

	info_inicio_texture = TextureRect.new()
	info_inicio_texture.name = "InfoArena"
	info_inicio_texture.texture = load("res://info_scenes/info_arena.png")
	info_inicio_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	info_inicio_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	info_inicio_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_inicio_texture.visible = true
	info_inicio_texture.modulate = Color(1.0, 0.92, 0.92, 1.0)
	modal_root.add_child(info_inicio_texture)

	modal_atire_label = Label.new()
	modal_atire_label.name = "LblAtire"
	modal_atire_label.text = "ATIRE PARA COMEÇAR"
	modal_atire_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_atire_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	modal_atire_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Leve.font_size(modal_atire_label, "font_size", 50)
	Leve.color(modal_atire_label, "font_color", COR_NEON_ARENA_CLARO)
	Leve.color(modal_atire_label, "font_outline_color", Color(0.18, 0.0, 0.0, 1.0))
	Leve.constant(modal_atire_label, "outline_size", 12)
	modal_atire_label.self_modulate = Color(1.0, 0.88, 0.88, 1.0)

	var fonte_luckies := load("res://fonts/LuckiestGuy-Regular.ttf")
	if fonte_luckies:
		Leve.font(modal_atire_label, "font", fonte_luckies)

	modal_atire_label.modulate.a = 0.78
	modal_root.add_child(modal_atire_label)

	var tween_atire := create_tween()
	tween_atire.set_loops()
	tween_atire.tween_property(modal_atire_label, "scale", Vector2(1.07, 1.07), 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_atire.parallel().tween_property(modal_atire_label, "modulate:a", 1.0, 0.65)
	tween_atire.tween_property(modal_atire_label, "scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_atire.parallel().tween_property(modal_atire_label, "modulate:a", 0.72, 0.65)

	_reposicionar_modal()
 
 

func _criar_preview_alvo() -> AnimatedSprite2D:
	if not is_instance_valid(alvo_inicial):
		return null
	var anim_original: AnimatedSprite2D = alvo_inicial.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim_original == null:
		return null
	var preview := AnimatedSprite2D.new()
	preview.sprite_frames = anim_original.sprite_frames
	preview.animation     = "idle"
	preview.play("idle")
	preview.scale = Vector2.ONE * escala_preview_modal
	return preview
 
 
func _criar_label_preview(texto: String) -> Label:
	var lbl := Label.new()
	lbl.text = texto
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(lbl, "font_size", 16)
	Leve.color(lbl, "font_color", Color(1.0, 0.88, 0.25))
	Leve.color(lbl, "font_outline_color", Color(0.0, 0.0, 0.0))
	Leve.constant(lbl, "outline_size", 4)
	return lbl
 

 
func _reposicionar_modal() -> void:
	if info_inicio_texture == null:
		return

	var tela: Vector2 = get_viewport_rect().size

	var area_w: float = tela.x * 0.90
	var area_h: float = tela.y * 0.58

	var tex_size: Vector2 = Vector2(1000.0, 600.0)
	if info_inicio_texture.texture != null:
		tex_size = info_inicio_texture.texture.get_size()

	var escala: float = min(area_w / tex_size.x, area_h / tex_size.y)
	var final_w: float = tex_size.x * escala
	var final_h: float = tex_size.y * escala

	info_inicio_texture.size = Vector2(final_w, final_h)
	info_inicio_texture.position = Vector2(
		(tela.x - final_w) * 0.5,
		(tela.y * 0.42) - (final_h * 0.5)
	).round()

	var neon_margem: float = 24.0
	var borda_espessura: float = 6.0

	if modal_root != null:
		var glow_img := modal_root.get_node_or_null("GlowImagemInicioArena") as ColorRect
		if glow_img != null:
			glow_img.position = info_inicio_texture.position - Vector2(neon_margem, neon_margem)
			glow_img.size = info_inicio_texture.size + Vector2(neon_margem * 2.0, neon_margem * 2.0)
			glow_img.color = Color(1.0, 0.02, 0.02, 0.18)

		var borda_img := modal_root.get_node_or_null("BordaImagemInicioArena") as ColorRect
		if borda_img != null:
			borda_img.position = info_inicio_texture.position - Vector2(borda_espessura, borda_espessura)
			borda_img.size = info_inicio_texture.size + Vector2(borda_espessura * 2.0, borda_espessura * 2.0)
			borda_img.color = COR_NEON_ARENA

		var fundo_img := modal_root.get_node_or_null("FundoImagemInicioArena") as ColorRect
		if fundo_img != null:
			fundo_img.position = info_inicio_texture.position - Vector2(3.0, 3.0)
			fundo_img.size = info_inicio_texture.size + Vector2(6.0, 6.0)

	if modal_atire_label != null:
		modal_atire_label.position = Vector2(
			0.0,
			info_inicio_texture.position.y + info_inicio_texture.size.y + 46.0
		)
		modal_atire_label.size = Vector2(tela.x, 80.0)
		modal_atire_label.pivot_offset = Vector2(tela.x * 0.5, 40.0)

# ═══════════════════════════════════════════════════════════
#  BACKGROUND
# ═══════════════════════════════════════════════════════════
 
func _configurar_background_fullscreen() -> void:
	if background == null:
		return
	if textura_fundo != null:
		if background is Sprite2D:
			(background as Sprite2D).texture = textura_fundo
		elif background is TextureRect:
			(background as TextureRect).texture = textura_fundo
 
	if background is TextureRect:
		var bg := background as TextureRect
		bg.anchor_left   = 0.0
		bg.anchor_top    = 0.0
		bg.anchor_right  = 0.0
		bg.anchor_bottom = 0.0
		bg.offset_left   = 0.0
		bg.offset_top    = 0.0
		bg.offset_right  = 0.0
		bg.offset_bottom = 0.0
		bg.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode  = TextureRect.STRETCH_SCALE
		if bg.texture != null:
			var vp_size: Vector2  = get_viewport_rect().size
			var tex_size: Vector2 = bg.texture.get_size()
			if tex_size.x > 0.0 and tex_size.y > 0.0:
				var escala: float        = max(vp_size.x / tex_size.x, vp_size.y / tex_size.y)
				var novo_tamanho: Vector2 = tex_size * escala
				bg.size     = novo_tamanho
				bg.position = (vp_size - novo_tamanho) * 0.5
	elif background is Sprite2D:
		var bg := background as Sprite2D
		bg.centered = false
		if bg.texture != null:
			var vp_size: Vector2  = get_viewport_rect().size
			var tex_size: Vector2 = bg.texture.get_size()
			if tex_size.x > 0.0 and tex_size.y > 0.0:
				var escala: float        = max(vp_size.x / tex_size.x, vp_size.y / tex_size.y)
				var novo_tamanho: Vector2 = tex_size * escala
				bg.scale    = Vector2(escala, escala)
				bg.position = (vp_size - novo_tamanho) * 0.5
 
 
# ═══════════════════════════════════════════════════════════
#  PREPARAÇÃO DO ALVO INICIAL (HIDDEN)
# ═══════════════════════════════════════════════════════════
 
func _preparar_alvo_inicial() -> void:
	if not is_instance_valid(alvo_inicial):
		return
	alvo_inicial.visible      = false
	alvo_inicial.process_mode = Node.PROCESS_MODE_DISABLED
	alvo_inicial.monitoring   = false
	alvo_inicial.monitorable  = false
	alvo_inicial.input_pickable = false
	alvo_inicial.position     = Vector2(-9999, -9999)
	_resetar_visual_arco(alvo_inicial)
	if alvo_inicial.has_method("resetar"):
		alvo_inicial.resetar()
		alvo_inicial.visible  = false
		alvo_inicial.position = Vector2(-9999, -9999)
 
 
# ═══════════════════════════════════════════════════════════
#  ÁUDIO
# ═══════════════════════════════════════════════════════════
 
func _configurar_audio() -> void:
	audio_tiro = AudioStreamPlayer.new()
	audio_tiro.name = "AudioTiro"
	add_child(audio_tiro)
	if caminho_som_tiro != "":
		var s: AudioStream = load(caminho_som_tiro)
		if s != null: audio_tiro.stream = s
 
	audio_recarga = AudioStreamPlayer.new()
	audio_recarga.name = "AudioRecarga"
	add_child(audio_recarga)
	if caminho_som_recarga != "":
		var s: AudioStream = load(caminho_som_recarga)
		if s != null: audio_recarga.stream = s
 
	audio_sem_bala = AudioStreamPlayer.new()
	audio_sem_bala.name = "AudioSemBala"
	add_child(audio_sem_bala)
	if caminho_som_sem_bala != "":
		var s: AudioStream = load(caminho_som_sem_bala)
		if s != null: audio_sem_bala.stream = s
 
	audio_musica_arena = AudioStreamPlayer.new()
	audio_musica_arena.name = "AudioMusicaArena"
	add_child(audio_musica_arena)
	if caminho_musica_arena != "":
		var s: AudioStream = load(caminho_musica_arena)
		if s != null:
			audio_musica_arena.stream = s
			audio_musica_arena.bus    = "Master"
 
	audio_alvo_cash = AudioStreamPlayer.new()
	audio_alvo_cash.name      = "AudioAlvoCash"
	audio_alvo_cash.volume_db = volume_crash_db
	add_child(audio_alvo_cash)
	if caminho_som_alvo_cash != "":
		var s: AudioStream = load(caminho_som_alvo_cash)
		if s != null:
			audio_alvo_cash.stream = s
			audio_alvo_cash.bus    = "Master"
	
	audio_hit_lamp = AudioStreamPlayer.new()
	audio_hit_lamp.name = "AudioHitLamp"
	audio_hit_lamp.volume_db = volume_crash_db
	add_child(audio_hit_lamp)

	if ResourceLoader.exists(caminho_som_hit_lamp):
		audio_hit_lamp.stream = load(caminho_som_hit_lamp)
		
		# BIP DA SEQUÊNCIA
	audio_bip = AudioStreamPlayer.new()
	audio_bip.name = "AudioBipSequencia"
	audio_bip.bus = "Master"
	audio_bip.volume_db = 12.0
	add_child(audio_bip)

	if ResourceLoader.exists(caminho_som_bip):
		audio_bip.stream = load(caminho_som_bip)
	else:
		push_warning("Som bip não encontrado: " + caminho_som_bip)
		
	# BIP ERROR
	audio_bip_error = AudioStreamPlayer.new()
	audio_bip_error.name = "AudioBipError"
	audio_bip_error.bus = "Master"
	audio_bip_error.volume_db = 12.0
	add_child(audio_bip_error)

	if ResourceLoader.exists(caminho_som_bip_error):
		audio_bip_error.stream = load(caminho_som_bip_error)
	else:
		push_warning("Som bip-error não encontrado: " + caminho_som_bip_error)
 
 
func _tocar_som_tiro() -> void:
	if audio_tiro == null or audio_tiro.stream == null:
		return
	audio_tiro.stop()
	audio_tiro.play()


func _tocar_bip_error() -> void:
	if audio_bip_error == null:
		return
	if audio_bip_error.stream == null:
		return

	audio_bip_error.volume_db = 12.0
	audio_bip_error.stop()
	audio_bip_error.play()

 

func _tocar_som_hit_lamp() -> void:
	if audio_hit_lamp == null:
		return
	if audio_hit_lamp.stream == null:
		return

	audio_hit_lamp.stop()
	audio_hit_lamp.play()

 
func _tocar_musica_arena() -> void:
	if audio_musica_arena == null or audio_musica_arena.stream == null:
		return
	if not audio_musica_arena.playing:
		audio_musica_arena.play()
 
 

func _parar_musica_arena() -> void:
	if audio_musica_arena != null:
		audio_musica_arena.stop()



func _calcular_pontos_acerto_sequencia() -> int:
	return (indice_sequencia + 1) * pontos_base_sequencia



func _configurar_modal_nome_ranking() -> void:
	ranking_nome_layer         = CanvasLayer.new()
	ranking_nome_layer.name    = "RankingNomeLayer"
	ranking_nome_layer.layer   = 150
	ranking_nome_layer.visible = false
	add_child(ranking_nome_layer)

	ranking_nome_root = Control.new()
	ranking_nome_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ranking_nome_root.mouse_filter = Control.MOUSE_FILTER_STOP
	ranking_nome_layer.add_child(ranking_nome_root)

	ranking_nome_bg       = ColorRect.new()
	ranking_nome_bg.color = Color(0.0, 0.0, 0.0, 0.82)
	ranking_nome_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ranking_nome_root.add_child(ranking_nome_bg)

	ranking_nome_panel = Panel.new()
	ranking_nome_root.add_child(ranking_nome_panel)
	Leve.stylebox(ranking_nome_panel, "panel", _estilo_card_arena())

	ranking_nome_titulo = Label.new()
	ranking_nome_titulo.text = "🏆 NOVO RECORDE!"
	ranking_nome_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranking_nome_titulo.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(ranking_nome_titulo, "font_size", 46)
	Leve.color(ranking_nome_titulo, "font_color", Color(1.0, 0.86, 0.20, 1.0))
	Leve.color(ranking_nome_titulo, "font_outline_color", Color.BLACK)
	Leve.constant(ranking_nome_titulo, "outline_size", 8)
	ranking_nome_panel.add_child(ranking_nome_titulo)

	ranking_nome_texto = Label.new()
	ranking_nome_texto.text = "CLIQUE NAS LETRAS PARA ESCREVER SEU NOME\nMÁXIMO 9 LETRAS"
	ranking_nome_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranking_nome_texto.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(ranking_nome_texto, "font_size", 24)
	Leve.color(ranking_nome_texto, "font_color", Color.WHITE)
	Leve.color(ranking_nome_texto, "font_outline_color", Color.BLACK)
	Leve.constant(ranking_nome_texto, "outline_size", 5)
	ranking_nome_panel.add_child(ranking_nome_texto)

	ranking_nome_display = Label.new()
	ranking_nome_display.text = "---------"
	ranking_nome_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranking_nome_display.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(ranking_nome_display, "font_size", 64)
	Leve.color(ranking_nome_display, "font_color", Color.WHITE)
	Leve.color(ranking_nome_display, "font_outline_color", COR_NEON_ARENA)
	Leve.constant(ranking_nome_display, "outline_size", 10)
	ranking_nome_panel.add_child(ranking_nome_display)

	ranking_nome_teclado = GridContainer.new()
	ranking_nome_teclado.columns = 9
	Leve.constant(ranking_nome_teclado, "h_separation", 8)
	Leve.constant(ranking_nome_teclado, "v_separation", 8)
	ranking_nome_panel.add_child(ranking_nome_teclado)

	var letras := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	for i in range(letras.length()):
		var letra := letras.substr(i, 1)
		var btn   := _criar_botao_tecla_ranking(letra)
		ranking_nome_teclado.add_child(btn)

	ranking_nome_btn_apagar = _criar_botao_tecla_ranking("APAGAR")
	ranking_nome_panel.add_child(ranking_nome_btn_apagar)

	ranking_nome_btn_ok = _criar_botao_tecla_ranking("SALVAR")
	ranking_nome_panel.add_child(ranking_nome_btn_ok)

	ranking_nome_timer_label = Label.new()
	ranking_nome_timer_label.text = "SALVA COMO ANONIMO EM 50"
	ranking_nome_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranking_nome_timer_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(ranking_nome_timer_label, "font_size", 24)
	Leve.color(ranking_nome_timer_label, "font_color", COR_NEON_ARENA_CLARO)
	Leve.color(ranking_nome_timer_label, "font_outline_color", Color.BLACK)
	Leve.constant(ranking_nome_timer_label, "outline_size", 6)
	ranking_nome_panel.add_child(ranking_nome_timer_label)

	_ajustar_modal_nome_ranking()



func _ranking_tentar_atirar_tecla(pos_mouse: Vector2) -> void:
	if not ranking_nome_ativo:
		return

	_tocar_som_tiro()

	if ranking_nome_teclado != null:
		for child in ranking_nome_teclado.get_children():
			if child is Button:
				var btn := child as Button
				var rect := Rect2(btn.global_position, btn.size)

				if rect.has_point(pos_mouse):
					_ranking_tecla_letra(btn.text)
					_fx_tecla_ranking(btn)
					return

	if ranking_nome_btn_apagar != null:
		var rect_apagar := Rect2(ranking_nome_btn_apagar.global_position, ranking_nome_btn_apagar.size)
		if rect_apagar.has_point(pos_mouse):
			_ranking_apagar_letra()
			_fx_tecla_ranking(ranking_nome_btn_apagar)
			return

	if ranking_nome_btn_ok != null:
		var rect_ok := Rect2(ranking_nome_btn_ok.global_position, ranking_nome_btn_ok.size)
		if rect_ok.has_point(pos_mouse):
			_fx_tecla_ranking(ranking_nome_btn_ok)
			_confirmar_nome_ranking(false)
			return


func _fx_tecla_ranking(btn: Button) -> void:
	if btn == null:
		return

	var escala_original: Vector2 = btn.scale

	var tw := create_tween()
	tw.tween_property(btn, "scale", escala_original * 1.12, 0.06)
	tw.tween_property(btn, "scale", escala_original, 0.10)



func _criar_botao_tecla_ranking(texto: String) -> Button:
	var btn := Button.new()
	btn.text = texto
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.disabled = true
	Leve.font_size(btn, "font_size", 28)
	Leve.color(btn, "font_color", Color.WHITE)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.02, 0.025, 0.98)
	normal.border_color = Color(0.95, 0.02, 0.02, 1.0)
	normal.border_width_left = 3
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 3
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12

	Leve.stylebox(btn, "normal", normal)
	Leve.stylebox(btn, "disabled", normal)

	return btn



func _abrir_modal_nome_ranking(pontos: int, cenario: String, precisao: int) -> void:
	ranking_pontos_pendentes = pontos
	ranking_cenario_pendente = cenario
	ranking_precisao_pendente = clamp(precisao, 0, 100)
	_aplicar_config_admin_na_cena()
	ranking_nome_tempo = float(get_tree().get_meta("admin_tempo_ranking_nome", ranking_nome_tempo))
	ranking_nome_ativo = true
	ranking_ja_salvo = false
	ranking_nome_digitado = ""

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	if mira_layer != null:
		mira_layer.layer = 200
		mira_layer.visible = true

	if mira_root != null:
		mira_root.visible = true
		mira_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mira_root.queue_redraw()

	if ranking_nome_layer != null:
		ranking_nome_layer.visible = true

	if ranking_nome_timer_label != null:
		ranking_nome_timer_label.text = "SALVA COMO ANONIMO EM %02d" % int(ceil(ranking_nome_tempo))

	_atualizar_display_nome_ranking()
	_ajustar_modal_nome_ranking()


func _ranking_tecla_letra(letra: String) -> void:
	if not ranking_nome_ativo:
		return

	if ranking_nome_digitado.length() >= 9:
		return

	ranking_nome_digitado += letra
	_atualizar_display_nome_ranking()



func _ranking_apagar_letra() -> void:
	if not ranking_nome_ativo:
		return

	if ranking_nome_digitado.length() <= 0:
		return

	ranking_nome_digitado = ranking_nome_digitado.substr(0, ranking_nome_digitado.length() - 1)
	_atualizar_display_nome_ranking()


func _atualizar_display_nome_ranking() -> void:
	if ranking_nome_display == null:
		return

	if ranking_nome_digitado == "":
		ranking_nome_display.text = "---------"
	else:
		ranking_nome_display.text = ranking_nome_digitado


func _confirmar_nome_ranking(usar_anonimo: bool = false) -> void:
	if ranking_ja_salvo:
		return

	var nome_final: String = "ANONIMO"
	var modo_atual_ranking: String = _obter_modo_ranking()

	if not usar_anonimo:
		var digitado: String = ranking_nome_digitado.strip_edges().to_upper()
		if digitado != "":
			nome_final = digitado

	if Engine.has_singleton("RankingManager"):
		RankingManager.call(
			"adicionar_resultado",
			nome_final,
			ranking_pontos_pendentes,
			ranking_cenario_pendente,
			ranking_precisao_pendente,
			modo_atual_ranking
		)
	elif has_node("/root/RankingManager"):
		var rm: Node = get_node("/root/RankingManager")
		rm.call(
			"adicionar_resultado",
			nome_final,
			ranking_pontos_pendentes,
			ranking_cenario_pendente,
			ranking_precisao_pendente,
			modo_atual_ranking
		)

	ranking_ja_salvo = true
	ranking_nome_ativo = false
	ranking_nome_tempo = 0.0

	if ranking_nome_layer != null:
		ranking_nome_layer.visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	if mira_layer != null:
		mira_layer.layer = 100
		mira_layer.visible = false

	_aplicar_config_admin_na_cena()
	fim_tempo_voltar = float(get_tree().get_meta("admin_tempo_modal_final", fim_tempo_voltar))

	if fim_titulo != null:
		fim_titulo.text = "RECORDE SALVO!"

	if fim_score_label != null:
		fim_score_label.text = "PONTUAÇÃO\n%d" % ranking_pontos_pendentes

	if fim_stats_label != null:
		fim_stats_label.text = "RECORDE SALVO COMO:\n%s\n\nPONTUAÇÃO: %d\nMODO: %s\nPRECISÃO: %d%%\nCENÁRIO: %s" % [
			nome_final,
			ranking_pontos_pendentes,
			modo_atual_ranking,
			ranking_precisao_pendente,
			ranking_cenario_pendente
		]
		Leve.font_size(fim_stats_label, "font_size", 38)

	if fim_footer != null:
		_estilizar_botao_modal_final(fim_footer, Maquina.texto_jogar_novamente(), false)

	if fim_contagem_label != null:
		fim_contagem_label.text = "VOLTANDO AO MENU EM %02d" % int(ceil(fim_tempo_voltar))

	_ajustar_layout_modal_final()



func _ajustar_modal_nome_ranking() -> void:
	if ranking_nome_root == null or ranking_nome_panel == null:
		return

	var tela: Vector2 = get_viewport_rect().size

	ranking_nome_root.size = tela

	if ranking_nome_bg != null:
		ranking_nome_bg.position = Vector2.ZERO
		ranking_nome_bg.size = tela

	var painel_w: float = min(980.0, tela.x - 70.0)
	var painel_h: float = min(760.0, tela.y - 90.0)

	ranking_nome_panel.position = Vector2(
		(tela.x - painel_w) * 0.5,
		(tela.y - painel_h) * 0.5
	).round()
	ranking_nome_panel.size = Vector2(painel_w, painel_h)

	if ranking_nome_titulo != null:
		ranking_nome_titulo.position = Vector2(20.0, 20.0)
		ranking_nome_titulo.size = Vector2(painel_w - 40.0, 62.0)

	if ranking_nome_texto != null:
		ranking_nome_texto.position = Vector2(40.0, 88.0)
		ranking_nome_texto.size = Vector2(painel_w - 80.0, 70.0)

	if ranking_nome_display != null:
		ranking_nome_display.position = Vector2(90.0, 162.0)
		ranking_nome_display.size = Vector2(painel_w - 180.0, 78.0)

	if ranking_nome_teclado != null:
		ranking_nome_teclado.position = Vector2(70.0, 260.0)
		ranking_nome_teclado.size = Vector2(painel_w - 140.0, 270.0)

		for child in ranking_nome_teclado.get_children():
			if child is Button:
				(child as Button).custom_minimum_size = Vector2(82.0, 62.0)

	if ranking_nome_btn_apagar != null:
		ranking_nome_btn_apagar.position = Vector2(150.0, painel_h - 150.0)
		ranking_nome_btn_apagar.size = Vector2(260.0, 64.0)

	if ranking_nome_btn_ok != null:
		ranking_nome_btn_ok.position = Vector2(painel_w - 410.0, painel_h - 150.0)
		ranking_nome_btn_ok.size = Vector2(260.0, 64.0)

	if ranking_nome_timer_label != null:
		ranking_nome_timer_label.position = Vector2(40.0, painel_h - 78.0)
		ranking_nome_timer_label.size = Vector2(painel_w - 80.0, 42.0)


func _obter_modo_ranking() -> String:
	var modo: String = str(get_tree().get_meta("modo_dificuldade", "facil")).strip_edges().to_lower()

	if modo == "dificil" or modo == "difícil":
		return "DIFICIL"

	return "FACIL"

func _texto_hud_recarga_padrao() -> String:
	return "BOTÃO AUXILIAR RECARREGA"


func _texto_hud_recarregando() -> String:
	return "AGUARDE %.1fs" % reload_tempo_restante


func _texto_hud_sem_municao() -> String:
	return "BOTÃO AUXILIAR DA ARMA"


func _texto_hud_municao_baixa() -> String:
	return "PREPARE A RECARGA"

# ═══════════════════════════════════════════════════════════
#  CONTROLES DA ARMA EEFORTS / INPUT MAP
# ═══════════════════════════════════════════════════════════

var tempo_trava_input_arma: float = 0.0

const ACAO_TIRO_ARMA: String = "input_shot"
const ACAO_RECARGA_ARMA: String = "input_recharge"

# GATILHO DA ARMA
const BOTAO_GATILHO_1: int = MOUSE_BUTTON_RIGHT
const BOTAO_GATILHO_2: int = MOUSE_BUTTON_LEFT

# AUXILIARES = RECARGA
const BOTAO_RECARGA_1: int = MOUSE_BUTTON_MIDDLE
const BOTAO_RECARGA_2: int = MOUSE_BUTTON_XBUTTON1
const BOTAO_RECARGA_3: int = MOUSE_BUTTON_XBUTTON2



func _pos_arma() -> Vector2:
	return Tela.mouse()


func _evento_tiro_arma(me: InputEventMouseButton) -> bool:
	return (
		me.button_index == BOTAO_GATILHO_1
		or me.button_index == BOTAO_GATILHO_2
	)


func _evento_recarga_arma(me: InputEventMouseButton) -> bool:
	return (
		me.button_index == BOTAO_RECARGA_1
		or me.button_index == BOTAO_RECARGA_2
		or me.button_index == BOTAO_RECARGA_3
	)


func _debug_botao_arma(me: InputEventMouseButton) -> void:
	print("BOTAO ARMA: ", me.button_index)


func _evento_action_arma(event: InputEvent, action_name: String) -> bool:
	if event == null:
		return false

	if not InputMap.has_action(action_name):
		return false

	if event is InputEventMouseMotion:
		return false

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.echo:
			return false

	return event.is_action_pressed(action_name)


func _evento_input_shot_arma(event: InputEvent) -> bool:
	return _evento_action_arma(event, ACAO_TIRO_ARMA)


func _evento_input_recharge_arma(event: InputEvent) -> bool:
	return _evento_action_arma(event, ACAO_RECARGA_ARMA)


func _executar_tiro_arma() -> void:
	if tempo_trava_input_arma > 0.0:
		return

	tempo_trava_input_arma = 0.10

	if ranking_nome_ativo:
		_ranking_tentar_atirar_tecla(mira_pos)
		return

	if fim_ativo:
		return

	if intro_comeco_ativa:
		return

	if not jogo_iniciado:
		_iniciar_intro_comeco()
		return

	if jogo_ativo:
		_tentar_atirar(mira_pos)


func _executar_recarga_arma() -> void:
	if tempo_trava_input_arma > 0.0:
		return

	tempo_trava_input_arma = 0.10

	if ranking_nome_ativo:
		return

	if fim_ativo:
		return

	if intro_comeco_ativa:
		return

	if jogo_ativo and not recarregando:
		_iniciar_recarga()


func _aplicar_config_admin_na_cena() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load("user://config_admin.cfg")

	if err == OK:
		tempo_total = float(cfg.get_value("jogo", "tempo_partida", tempo_total))
		fim_tempo_voltar = float(cfg.get_value("jogo", "tempo_modal_final", fim_tempo_voltar))
		ranking_nome_tempo = float(cfg.get_value("ranking", "tempo_nome", ranking_nome_tempo))

		var dificuldade := str(cfg.get_value("jogo", "dificuldade_padrao", get_tree().get_meta("modo_dificuldade", "facil")))
		get_tree().set_meta("modo_dificuldade", dificuldade)

	get_tree().set_meta("admin_tempo_partida", tempo_total)
	get_tree().set_meta("admin_tempo_modal_final", fim_tempo_voltar)
	get_tree().set_meta("admin_tempo_ranking_nome", ranking_nome_tempo)
