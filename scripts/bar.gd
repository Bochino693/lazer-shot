extends Node2D

var erros_seguidos: int = 0

var chat_rodape_panel: Panel = null

const FONTE_ORBITRON: String = "res://fonts/Orbitron-Bold.ttf"
const FONTE_LUCKIEST: String = "res://fonts/LuckiestGuy-Regular.ttf"

const COR_NEON_BAR: Color = Color(0.20, 1.0, 0.32, 1.0)
const COR_NEON_BAR_CLARO: Color = Color(0.74, 1.0, 0.78, 1.0)
const COR_FUNDO_CARD_BAR: Color = Color(0.012, 0.045, 0.018, 0.94)

const ACAO_TIRO_ARMA: String = "input_shot"
const ACAO_RECARGA_ARMA: String = "input_recharge"

var fonte_orbitron: FontFile = null
var fonte_luckiest: FontFile = null

# ===== RANKING INPUT =====
var ranking_hover_idx: int = -1
var ranking_input_trava: float = 0.0
var ranking_input_delay: float = 0.18
var ranking_backspace_trava: float = 0.0

const RankingManagerScript := preload("res://scripts/RankingManager.gd")
const Estilhacos := preload("res://scripts/estilhacos.gd")
const Pincel := preload("res://scripts/pincel.gd")
var ranking_manager := RankingManagerScript.new()

var ranking_nome_layer: CanvasLayer = null
var ranking_nome_root: Control = null
var ranking_nome_bg: ColorRect = null
var ranking_nome_panel: Panel = null
var ranking_nome_titulo: Label = null
var ranking_nome_texto: Label = null
var ranking_nome_display: Label = null
var ranking_nome_teclado: GridContainer = null
var ranking_nome_btn_ok: Button = null
var ranking_nome_btn_apagar: Button = null
var ranking_nome_timer_label: Label = null

var ranking_nome_digitado: String = ""
var ranking_nome_ativo: bool = false
var ranking_nome_tempo: float = 50.0
var ranking_pontos_pendentes: int = 0
var ranking_cenario_pendente: String = "BAR"
var ranking_precisao_pendente: int = 0
var ranking_ja_salvo: bool = false

@export_file("*.tscn") var cena_main_menu: String = "res://scenes/main.tscn"
@export var cena_garrafa_gin: PackedScene = preload("res://entities/GarrafaGin.tscn")
@export var cena_garrafa_rum: PackedScene = preload("res://entities/GarrafaRum.tscn")
@export var cena_garrafa_vodka: PackedScene = preload("res://entities/GarrafaVodka.tscn")
@export var cena_garrafa_whisky: PackedScene = preload("res://entities/GarrafaWhisky.tscn")
@export var tempo_troca_turno: float = 5.0
@export var tempo_partida: float = 120.0
@export var subir_de_baixo_px: float = 90.0
@export var som_recharge_path: String = "res://songs/recharge.mp3"
@export var som_bar_path: String = "res://songs/song-oldwest.mp3"
@export var cena_garrafa_falsa: PackedScene = preload("res://entities/garrafa.tscn")
@export var penalidade_erro: int = 0
@export var penalidade_garrafa_falsa: int = 500
@export var idade_minima_para_virar_impostora: float = 1.45
@export var intervalo_mutacao_min: float = 0.75
@export var intervalo_mutacao_max: float = 1.45
@export var vida_gin_min: float = 4.20
@export var vida_gin_max: float = 5.80
@export var vida_rum_min: float = 3.40
@export var vida_rum_max: float = 4.80
@export var vida_vodka_min: float = 2.70
@export var vida_vodka_max: float = 3.80
@export var vida_whisky_min: float = 1.90
@export var vida_whisky_max: float = 2.80

@export var intervalo_impostora_min: float = 1.35
@export var intervalo_impostora_max: float = 2.40
@export var max_impostoras_ativas: int = 3

@export var intervalo_troca_slot_min: float = 0.55
@export var intervalo_troca_slot_max: float = 1.15
@export var pontos_para_aumentar_impostora: int = 1000

var loop_troca_slots_ativo: bool = false

var loop_impostoras_ativo: bool = false

@export var vida_impostora_min: float = 2.80
@export var vida_impostora_max: float = 4.20

@export var intervalo_spawn_continuo_min: float = 0.35
@export var intervalo_spawn_continuo_max: float = 0.95


@export var usar_controle_xbox: bool = true
@export var velocidade_mira_xbox: float = 920.0
@export var deadzone_xbox: float = 0.18

@export var xbox_botao_tiro: int = JOY_BUTTON_RIGHT_SHOULDER # R1
@export var xbox_botao_recarga: int = JOY_BUTTON_LEFT_SHOULDER # L1
@export var xbox_botao_recarga_extra: int = JOY_BUTTON_LEFT_SHOULDER



var xbox_mira_iniciada: bool = false

var slots_reservados: Dictionary = {}

var spawn_continuo_ativo: bool = false

var status_chat_msgs: Array[Dictionary] = []
var status_chat_labels: Array[Label] = []

@export var som_fim_path: String = "res://songs/end_game.mp3"
@export var duracao_cutscene_fim_seg: float = 2.2
@export var duracao_loading_resultado_seg: float = 1.6
@export var tempo_auto_retorno_menu_seg: float = 21.0

var som_fim_stream: AudioStream = null
var som_bar_stream: AudioStream = null
var fim_end_music_player: AudioStreamPlayer = null
var bar_music_player: AudioStreamPlayer = null
var mutacao_impostora_em_execucao: bool = false

var fim_cutscene_ativa: bool = false
var fim_cutscene_panel: ColorRect = null
var fim_cutscene_titulo: Label = null
var fim_cutscene_loading: Label = null
var fim_cutscene_barra_bg: ColorRect = null
var fim_cutscene_barra_fill: ColorRect = null


var som_recharge_stream: AudioStream = null
var aviso_bloco_info: ColorRect = null
var aviso_linha_divisoria: ColorRect = null
var aviso_texto_extra_label: Label = null
var mascara_topo: ColorRect = null
var fundo_ajustado_uma_vez: bool = false

@export var som_bullet_no_path: String = "res://songs/bullet_no.mp3"
var som_bullet_no_stream: AudioStream = null

@export var modo_demo: bool = false
@export var tempo_demo: float = 20.0
@export var demo_intervalo_min: float = 0.45
@export var demo_intervalo_max: float = 1.10
@export var capacidade_cartucho: int = 30
@export var tempo_recarga_seg: float = 1.10
@export var pontos_por_nivel_dificuldade: int = 3000
@export var bonus_velocidade_por_nivel: float = 0.42
@export var bonus_spawn_por_nivel: int = 1
@export var alerta_baixa_municao_limite: int = 6


var aviso_dica_label: Label = null
var aviso_penalidade_label: Label = null
var aviso_card_garrafa: ColorRect = null
var aviso_card_penalidade: ColorRect = null
var aviso_preview_container: SubViewportContainer = null
var aviso_preview_viewport: SubViewport = null
var aviso_preview_root: Node2D = null
var aviso_preview_garrafa: Area2D = null


var intro_comeco_ativa: bool = false
var intro_comeco_t: float = 0.0
var intro_contagem_valor: int = 3

var comeco_layer: CanvasLayer = null
var comeco_root: Control = null
var comeco_flash: ColorRect = null
var comeco_titulo: Label = null
var comeco_subtitulo: Label = null

var balas_no_cartucho: int = 30
var recarregando: bool = false
var reload_tempo_restante: float = 0.0
var nivel_dificuldade_atual: int = 0
var aviso_recarga_t: float = 0.0

var municao_panel: Panel
var municao_title_label: Label
var municao_label: Label
var recarga_label: Label

var sequencia_acertos: int = 0
var melhor_sequencia: int = 0
var tempo_ultimo_acerto: float = -100.0
const JANELA_COMBO: float = 2.2

var combo_fx_t: float = 0.0
var combo_fx_texto: String = ""
var combo_fx_ativo: bool = false

const DURACAO_COMBO_FX: float = 1.35

var total_double_hits: int = 0
var total_triple_hits: int = 0
var total_quadra_hits: int = 0
var total_penta_hits: int = 0
var total_super_combos: int = 0
var ultimo_alvo_pos: Vector2 = Vector2(-99999.0, -99999.0)
var ultimo_estado_mira: String = ""


var demo_ativo: bool = false

@onready var fundo: Sprite2D = $Background
@onready var spawn_points_root: Node2D = $SpawnPoints
@onready var garrafas_root: Node2D = $Garrafas
@onready var garrafa_modelo: Area2D = get_node_or_null("GarrafaModelo") as Area2D

var fundo_preenchimento: Sprite2D = null
var spawn_points: Array[Marker2D] = []
var garrafas_ativas: Array[Area2D] = []
var fila_spawn_turno: Array[Dictionary] = []
var municao_blocos: Array[ColorRect] = []
var spawn_em_execucao: bool = false

var alvo_pos: Vector2 = Vector2.ZERO
var alvo_anim_t: float = 0.0
var alvo_layer: CanvasLayer = null
var alvo_overlay: Control = null
var combo_hud_label: Label

var partida_iniciada: bool = false
var intro_cenario_em_execucao: bool = false

var aviso_layer: CanvasLayer = null
var aviso_root: Control = null
var aviso_panel: TextureRect = null
var aviso_titulo: Label = null
var aviso_subtitulo: Label = null

var pontuacao_total: int = 0
var jogo_ativo: bool = true
var tempo_restante: float = 120.0
var tempo_turno: float = 0.0
var trocando_turno: bool = false

var total_tiros: int = 0
var total_acertos: int = 0
var total_erros: int = 0

var marcas_erro: Array[Dictionary] = []
## TV Box: prateleiras e marcas de tiro ficam em camadas próprias, atrás do
## nó da fase (mesma ordem de antes: prateleiras, marcas, efeitos). Elas só
## são redesenhadas quando entra/sai uma marca, e não mais em todo quadro
## junto com os efeitos. Guarda as marcas mais recentes (as mais antigas somem).
const MAX_MARCAS_ERRO: int = 80
var _camada_estantes: Node2D = null
var _camada_marcas: Node2D = null
var fx_madeira: Array[Dictionary] = []
var fx_vidro: Array[Dictionary] = []
var fx_impacto: Array[Dictionary] = []

var hud_layer: CanvasLayer
var hud_root: Control
var top_bar: Panel          # era: var top_bar: Control
var stats_hud_panel: Panel  # novo painel para acertos/tiros

var top_bar_glow: ColorRect
var top_bar_linha: ColorRect
var top_bar_sombra: ColorRect

var score_panel: Control
var timer_panel: Panel
var status_panel: Panel
var fim_panel: Panel

var score_title_label: Label
var score_label: Label
var timer_title_label: Label
var timer_label: Label
var tiros_title_label: Label
var tiros_label: Label
var acertos_title_label: Label
var acertos_label: Label
var status_label: Label

var fim_title_label: Label
var fim_score_label: Label
var fim_stats_label: Label
var fim_insert_coin_label: Label
var fim_countdown_label: Label

var som_fail_stream: AudioStream = null
var som_smash_stream: AudioStream = null
var som_tiro_stream: AudioStream = null

var hud_sujo: bool = true
var hud_cache_score: int = -1
var hud_cache_tiros: int = -1
var hud_cache_acertos: int = -1
var hud_cache_balas: int = -1
var hud_cache_recarregando: bool = false
var hud_cache_reload_deci: int = -1
var hud_cache_tempo_seg: int = -1

var hud_animando_entrada: bool = false
var hud_entrada_t: float = 0.0
var hud_top_offset_y: float = -220.0

var aviso_footer_label: Label = null
var aviso_footer_t: float = 0.0


const CAMINHO_SOM_FAIL := "res://songs/fail.mp3"
const CAMINHO_SOM_SMASH := "res://songs/smash.mp3"
const CAMINHO_SOM_TIRO := "res://songs/tiro-de-pistola.mp3"
const HUD_TOPO_Y := 18.0
const HUD_ALTURA_FIXA := 24.0
const CORTE_DESENHO_TOPO_Y := 220.0

var tempo_fim_menu: float = 20.0
var fim_pulso_t: float = 0.0
var status_token: int = 0
var status_tween: Tween = null

const COR_TIMER_NORMAL := Color(0.70, 0.90, 1.0, 1.0)
const COR_TIMER_ALERTA := Color(1.0, 0.66, 0.15, 1.0)
const COR_TIMER_CRITICO := Color(1.0, 0.15, 0.12, 1.0)

const COR_PANEL_TIMER_NORMAL := Color(0.05, 0.07, 0.11, 0.92)
const COR_PANEL_TIMER_ALERTA := Color(0.26, 0.14, 0.03, 0.95)
const COR_PANEL_TIMER_CRITICO := Color(0.30, 0.04, 0.04, 0.96)

const COR_PANEL_SCORE := Color(0.16, 0.10, 0.02, 0.92)
const COR_PANEL_STATUS := Color(0.02, 0.02, 0.03, 0.66)
const COR_PANEL_FIM := Color(0.01, 0.01, 0.02, 0.78)

const X_COLUNAS_100 := [190.0, 315.0, 440.0, 565.0, 690.0]
const X_COLUNAS_80 := [190.0, 355.0, 520.0, 685.0]
const X_COLUNAS_50 := [190.0, 355.0, 520.0, 685.0]
const X_COLUNAS_20 := [110.0, 220.0, 330.0, 440.0, 550.0, 660.0]

const Y_PRATELEIRA_100 := 575.0
const Y_PRATELEIRA_80 := 815.0
const Y_PRATELEIRA_50 := 1100.0
const Y_PRATELEIRA_20 := 1400.0

const AREA_BARRIL_X_INICIO := 700.0
const AREA_BARRIL_X_FIM := 900.0

const META_SENS_XBOX: String = "sensibilidade_xbox"
const META_SENS_MOUSE: String = "sensibilidade_mouse"

@export var sensibilidade_mouse: float = 1.0
var mouse_delta_acumulado: Vector2 = Vector2.ZERO

var tremor_tempo: float = 0.0
var tremor_forca: float = 0.0
var fundo_pos_base: Vector2 = Vector2.ZERO
var garrafas_pos_base: Vector2 = Vector2.ZERO


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	randomize()
	# Efeitos do _draw usam o Pincel (textura com mipmaps).
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_aplicar_sensibilidade_global()
	_criar_camadas_estaticas()
	_preaquecer_alfa_garrafas.call_deferred()
	alvo_pos = get_viewport_rect().size * 0.5
	mouse_delta_acumulado = Vector2.ZERO

	_carregar_config_admin_jogo()
	_carregar_fontes_ui()

	if garrafas_root != null:
		garrafas_root.visible = false
		garrafas_root.position = Vector2.ZERO
		garrafas_root.scale = Vector2.ONE
		garrafas_root.z_index = 5
		garrafas_pos_base = garrafas_root.position

	if garrafa_modelo != null:
		garrafa_modelo.visible = false
		garrafa_modelo.process_mode = Node.PROCESS_MODE_DISABLED

	tempo_restante = tempo_partida
	tempo_turno = 0.0
	partida_iniciada = false
	intro_cenario_em_execucao = true
	sequencia_acertos = 0
	melhor_sequencia = 0
	tempo_ultimo_acerto = -100.0
	combo_fx_t = 0.0
	combo_fx_texto = ""
	combo_fx_ativo = false
	
	balas_no_cartucho = capacidade_cartucho
	recarregando = false
	reload_tempo_restante = 0.0
	nivel_dificuldade_atual = 0
	aviso_recarga_t = 0.0

	total_double_hits = 0
	total_triple_hits = 0
	total_quadra_hits = 0
	total_penta_hits = 0
	total_super_combos = 0
	
	_configurar_audio()
	_criar_fundo_preenchimento()
	_coletar_spawn_points()
	_configurar_hud()
	_configurar_modal_nome_ranking()
	_configurar_alvo_overlay()
	_configurar_aviso_inicio()
	_configurar_intro_comeco()
	_ajustar_fundo_full()
	_criar_mascara_topo()
	_criar_luz_do_sol()

	if fundo != null:
		fundo_pos_base = fundo.position

	_limpar_garrafas_antigas()
	
	hud_animando_entrada = false
	hud_entrada_t = 0.0
	hud_top_offset_y = -220.0
	hud_sujo = true
	_atualizar_hud()
	_set_status_neutro("")

	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

	call_deferred("_ajustar_layout")
	call_deferred("_animar_entrada_cenario")
	_iniciar_musica_bar_em_loop()
	
	if modo_demo:
		_iniciar_modo_demo()


func _iniciar_modo_demo() -> void:
	
	_resetar_combo()
	total_double_hits = 0
	total_triple_hits = 0
	total_quadra_hits = 0
	total_penta_hits = 0
	total_super_combos = 0
	melhor_sequencia = 0
	
	demo_ativo = true
	jogo_ativo = true
	partida_iniciada = true
	intro_cenario_em_execucao = false
	tempo_restante = 9999.0
	tempo_turno = 0.0
	total_tiros = 0
	total_acertos = 0
	total_erros = 0
	pontuacao_total = 0

	if aviso_root != null:
		aviso_root.visible = false

	_set_status_neutro("")
	_atualizar_hud()

	call_deferred("_loop_demo")
	call_deferred("_timer_saida_demo")



func _aplicar_sensibilidade_global() -> void:
	# XBOX travado em 5000 — vale para FÁCIL e DIFÍCIL.
	# Ignora valor antigo salvo no meta que estaria puxando pra baixo.
	velocidade_mira_xbox = 1500.0

	# MOUSE continua respeitando o config.
	if get_tree().has_meta(META_SENS_MOUSE):
		sensibilidade_mouse = float(
			get_tree().get_meta(META_SENS_MOUSE)
		)

	sensibilidade_mouse = clampf(
		sensibilidade_mouse,
		0.2,
		3.0
	)


func _loop_demo() -> void:
	while modo_demo and demo_ativo and is_inside_tree():
		await get_tree().create_timer(randf_range(demo_intervalo_min, demo_intervalo_max)).timeout

		if not modo_demo or not demo_ativo or not is_inside_tree():
			return

		if garrafas_ativas.is_empty():
			continue

		var alvo: Area2D = garrafas_ativas[randi() % garrafas_ativas.size()]
		if alvo == null or not is_instance_valid(alvo):
			continue

		var pos_alvo: Vector2 = alvo.global_position
		_processar_tiro_global(pos_alvo)


func _timer_saida_demo() -> void:
	await get_tree().create_timer(tempo_demo).timeout

	if not modo_demo or not is_inside_tree():
		return

	_sair_demo_para_main()


func _sair_demo_para_main() -> void:
	if cena_main_menu == "":
		return

	demo_ativo = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	TransicaoGlobal.trocar_cena(cena_main_menu)


func _obter_vida_individual_por_pontos(pontos: int) -> float:
	match pontos:
		100:
			return randf_range(vida_whisky_min, vida_whisky_max)
		80:
			return randf_range(vida_vodka_min, vida_vodka_max)
		50:
			return randf_range(vida_rum_min, vida_rum_max)
		20:
			return randf_range(vida_gin_min, vida_gin_max)
		_:
			return randf_range(vida_impostora_min, vida_impostora_max)



func _exit_tree() -> void:
	_parar_musica_bar()
	_parar_musica_fim()

	if Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)



func _process(delta: float) -> void:
	
	if ranking_input_trava > 0.0:
		ranking_input_trava = max(0.0, ranking_input_trava - delta)
	tempo_trava_input_arma = max(0.0, tempo_trava_input_arma - delta)

	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_atualizar_mira_hibrida(delta)

	var mouse_pos: Vector2 = alvo_pos

	if _modo_dificil_sem_mira():
		if alvo_overlay != null:
			alvo_overlay.visible = false
	else:
		if alvo_overlay != null:
			alvo_overlay.visible = true
		_atualizar_mira_se_necessario(mouse_pos)

	alvo_anim_t += delta
	aviso_recarga_t += delta
	
	if ranking_nome_ativo:
		ranking_nome_tempo = max(0.0, ranking_nome_tempo - delta)

		if ranking_nome_timer_label != null:
			ranking_nome_timer_label.text = "SALVA COMO ANONIMO EM %02d" % int(ceil(ranking_nome_tempo))

		if ranking_nome_tempo <= 0.0:
			_confirmar_nome_ranking(true)

	if intro_comeco_ativa:
		intro_comeco_t += delta

		if comeco_titulo != null and comeco_titulo.visible:
			comeco_titulo.self_modulate = Color(
				0.88,
				1.0,
				0.90,
				0.82 + abs(sin(intro_comeco_t * 7.0)) * 0.18
			)

		if comeco_subtitulo != null and comeco_subtitulo.visible:
			comeco_subtitulo.self_modulate = Color(
				0.70,
				1.0,
				0.76,
				0.60 + abs(sin(intro_comeco_t * 5.5)) * 0.35
			)

	# cabeçalho fixo: não anima mais descendo/subindo por frame
	if hud_animando_entrada:
		hud_animando_entrada = false
		hud_entrada_t = 1.0
		hud_top_offset_y = 0.0
		_ajustar_layout()

	if aviso_root != null and aviso_root.visible and not partida_iniciada:
		aviso_footer_t += delta
		if aviso_footer_label != null:
			aviso_footer_label.modulate.a = 0.48 + abs(sin(aviso_footer_t * 4.8)) * 0.52

	if alvo_overlay != null and (recarregando or balas_no_cartucho <= 0):
		alvo_overlay.queue_redraw()

	if not jogo_ativo:
		if not ranking_nome_ativo:
			_animar_fim(delta)
		return

	var tinha_fx_antes := _tem_fx_visuais_ativos()

	_atualizar_fx_madeira(delta)
	_atualizar_fx_vidro(delta)
	_atualizar_fx_impacto(delta)
	_atualizar_tremor(delta)
	_atualizar_marcas_erro(delta)
	_atualizar_combo_hud()

	if recarregando:
		var reload_antigo: int = int(round(reload_tempo_restante * 10.0))
		reload_tempo_restante = max(0.0, reload_tempo_restante - delta)
		var reload_novo: int = int(round(reload_tempo_restante * 10.0))

		if reload_novo != reload_antigo:
			_marcar_hud_sujo()

		if reload_tempo_restante <= 0.0:
			_finalizar_recarga()

	if partida_iniciada:
		var tempo_antigo: int = int(ceil(max(tempo_restante, 0.0)))
		tempo_restante = max(0.0, tempo_restante - delta)
		var tempo_novo: int = int(ceil(max(tempo_restante, 0.0)))

		if tempo_novo != tempo_antigo:
			_marcar_hud_sujo()

		tempo_turno += delta

		if tempo_restante <= 0.0:
			_encerrar_jogo()
			if _tem_fx_visuais_ativos():
				queue_redraw()
			return

	_atualizar_dificuldade_progressiva()
	_atualizar_status_chat(delta)
	_atualizar_hud_se_necessario()
	_atualizar_status_constante()

	var tem_fx_agora := _tem_fx_visuais_ativos()
	
	if tinha_fx_antes or tem_fx_agora:
		queue_redraw()

	if alvo_overlay != null:
		alvo_overlay.queue_redraw()
		




func _atualizar_mira_hibrida(delta: float) -> void:
	var tela: Vector2 = get_viewport_rect().size

	if not xbox_mira_iniciada:
		alvo_pos = tela * 0.5
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
			alvo_pos += movimento * velocidade_mira_xbox * delta
			usou_xbox = true

	if not usou_xbox:
		if mouse_delta_acumulado.length_squared() > 0.0:
			alvo_pos += mouse_delta_acumulado * sensibilidade_mouse
			mouse_delta_acumulado = Vector2.ZERO

	alvo_pos.x = clampf(alvo_pos.x, 0.0, tela.x)
	alvo_pos.y = clampf(alvo_pos.y, 0.0, tela.y)



func _draw() -> void:
	_desenhar_fx_madeira()
	_desenhar_fx_vidro()
	_desenhar_fx_impacto()


func _input(event: InputEvent) -> void:
	# ============================================================
	# MOVIMENTO DA MIRA
	# ============================================================
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		mouse_delta_acumulado += mm.relative
		return

	# ============================================================
	# START — reinicia no fim / salva anônimo se estiver no ranking
	# ============================================================
	if event.is_action_pressed("input_start"):
		if not jogo_ativo:
			if ranking_nome_ativo:
				_confirmar_nome_ranking(true)

			_reiniciar_jogo()
			return

	# ============================================================
	# TIRO PELO INPUT MAP
	# Arduino Leonardo / arma física
	# Action: input_shot
	# ============================================================
	if _evento_input_shot_arma(event):
		_executar_tiro_arma()
		return

	# ============================================================
	# RECARGA PELO INPUT MAP
	# Arduino Leonardo / botão físico
	# Action: input_recharge
	# ============================================================
	if _evento_input_recharge_arma(event):
		_executar_recarga_arma()
		return

	# ============================================================
	# XBOX — FALLBACK
	# Continua funcionando mesmo se não estiver mapeado no Input Map
	# ============================================================
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton

		if not jb.pressed:
			return

		print("DEBUG XBOX BAR:", jb.button_index)

		if jb.button_index == xbox_botao_tiro:
			_executar_tiro_arma()
			return

		if jb.button_index == xbox_botao_recarga or jb.button_index == xbox_botao_recarga_extra:
			_executar_recarga_arma()
			return

	# ============================================================
	# TECLADO — FALLBACK DE RECARGA
	# ============================================================
	if event is InputEventKey:
		var ke := event as InputEventKey

		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_R:
				_executar_recarga_arma()
				return

	# ============================================================
	# MOUSE / ARMA COMO MOUSE — FALLBACK
	# Mouse esquerdo atira / mouse direito recarrega
	# ============================================================
	if event is InputEventMouseButton:
		var me := event as InputEventMouseButton

		if not me.pressed:
			return

		_debug_botao_arma(me)

		if _evento_tiro_arma(me):
			_executar_tiro_arma()
			return

		if _evento_recarga_arma(me):
			_executar_recarga_arma()
			return


func _ranking_tentar_atirar_tecla(pos_tiro: Vector2) -> void:
	if not ranking_nome_ativo:
		return

	if ranking_input_trava > 0.0:
		return

	ranking_input_trava = ranking_input_delay

	if ranking_nome_teclado != null:
		for child in ranking_nome_teclado.get_children():
			if child is Button:
				var btn := child as Button

				if btn.visible and btn.get_global_rect().has_point(pos_tiro):
					var letra: String = btn.text.strip_edges()

					if ranking_nome_digitado.length() < 9:
						ranking_nome_digitado += letra
						_atualizar_display_nome_ranking()

					return

	if ranking_nome_btn_apagar != null:
		if ranking_nome_btn_apagar.visible and ranking_nome_btn_apagar.get_global_rect().has_point(pos_tiro):
			_ranking_apagar_letra()
			return

	if ranking_nome_btn_ok != null:
		if ranking_nome_btn_ok.visible and ranking_nome_btn_ok.get_global_rect().has_point(pos_tiro):
			_confirmar_nome_ranking(false)
			return



func _processar_tiro_global(pos_global: Vector2) -> void:
	if ranking_nome_ativo:
		return

	if not jogo_ativo:
		return

	if intro_comeco_ativa:
		return

	if intro_cenario_em_execucao:
		return

	if recarregando:
		queue_redraw()
		return

	if balas_no_cartucho <= 0:
		if som_bullet_no_stream != null:
			_tocar_som(som_bullet_no_stream, 0.0)
		queue_redraw()
		return

	balas_no_cartucho -= 1
	total_tiros += 1
	alvo_anim_t += 0.35
	_marcar_hud_sujo()

	_tocar_som_tiro()

	var garrafa_acertada: Area2D = _detectar_garrafa_no_ponto(pos_global)

	if garrafa_acertada != null:
		_processar_acerto_alvo(garrafa_acertada, pos_global)
		queue_redraw()
		return

	total_erros += 1
	erros_seguidos += 1
	_resetar_combo()

	_registrar_erro_visual(pos_global)
	_registrar_fx_madeira(pos_global)
	_registrar_fx_impacto(pos_global)

	_set_status_erro("ERROU!")
	_marcar_hud_sujo()

	queue_redraw()




func _processar_acerto_alvo(alvo: Area2D, pos_tiro: Vector2 = Vector2.INF) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return
	if alvo.get("ja_acertado") == true:
		return

	alvo.set("ja_acertado", true)
	alvo.monitoring = false
	alvo.monitorable = false
	alvo.input_pickable = false

	var tipo_alvo: String = _texto(alvo.get("tipo_alvo"), _texto(alvo.get_meta("tipo_alvo", ""), "garrafa"))
	var pontos: int = _num_int(alvo.get("pontos"), _num_int(alvo.get_meta("pontos", 0), 0))
	var pos_global: Vector2 = alvo.global_position

	garrafas_ativas.erase(alvo)

	var id_slot: String = _texto(alvo.get_meta("slot_id", ""), "")
	_liberar_slot_por_id(id_slot)

	# A garrafa vira cacos da própria imagem, rachando a partir do tiro.
	if pos_tiro == Vector2.INF:
		pos_tiro = pos_global
	_estourar_garrafa(alvo, pos_tiro, _obter_cor_liquido_por_alvo(tipo_alvo, pontos))

	if tipo_alvo == "garrafa_falsa":
		erros_seguidos += 1
		var perda_impostora: int = penalidade_garrafa_falsa + (20 * erros_seguidos)

		pontuacao_total -= perda_impostora
		total_erros += 1
		_resetar_combo()

		_tocar_som_erro()
		_registrar_fx_impacto(pos_tiro)
		_set_status_erro("GARRAFA IMPOSTORA  -%d" % perda_impostora)
		_marcar_hud_sujo()

		await get_tree().create_timer(0.34).timeout
		if is_instance_valid(alvo):
			alvo.queue_free()
		return

	erros_seguidos = 0

	pontuacao_total += pontos
	total_acertos += 1
	total_erros = max(0, total_tiros - total_acertos)

	_registrar_combo_acerto()
	_tocar_vidro_apos_tiro()
	_registrar_fx_impacto(pos_tiro)

	_set_status_neutro("%s  +%d" % [_obter_nome_garrafa_por_pontos(pontos), pontos])
	_marcar_hud_sujo()

	await get_tree().create_timer(0.26).timeout
	if is_instance_valid(alvo):
		alvo.queue_free()

	queue_redraw()


func _obter_nome_garrafa_por_pontos(pontos: int) -> String:
	match pontos:
		100:
			return "WHISKY"
		80:
			return "VODKA"
		50:
			return "RUM"
		20:
			return "GIN"
		_:
			return "GARRAFA"


func _estourar_garrafa(alvo: Area2D, pos_tiro: Vector2, cor_liquido: Color) -> void:
	var anim: AnimatedSprite2D = _obter_anim_garrafa(alvo)
	if anim == null or anim.sprite_frames == null:
		return
	var nome: StringName = anim.animation
	if not anim.sprite_frames.has_animation(nome):
		nome = &"idle"
	if not anim.sprite_frames.has_animation(nome) or anim.sprite_frames.get_frame_count(nome) <= 0:
		return
	var quadro: Texture2D = anim.sprite_frames.get_frame_texture(nome, clampi(anim.frame, 0, anim.sprite_frames.get_frame_count(nome) - 1))
	var imagem: Image = null
	if quadro is AtlasTexture and (quadro as AtlasTexture).atlas != null:
		imagem = _imagem_em_cache((quadro as AtlasTexture).atlas)
	elif quadro != null:
		imagem = _imagem_em_cache(quadro)
	Estilhacos.quebrar(self, anim, quadro, imagem, pos_tiro, cor_liquido)
	anim.visible = false


func _animar_alvo_sentindo_tiro(alvo: Area2D) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	var escala_base: Vector2 = alvo.scale
	var pos_base: Vector2 = alvo.position

	var tw := create_tween()
	tw.set_parallel(true)

	tw.tween_property(alvo, "scale", escala_base * 1.08, 0.045)
	tw.tween_property(alvo, "position", pos_base + Vector2(randf_range(-7.0, 7.0), randf_range(-5.0, 3.0)), 0.045)

	tw.tween_property(alvo, "scale", escala_base * 0.96, 0.055).set_delay(0.045)
	tw.tween_property(alvo, "position", pos_base + Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0)), 0.055).set_delay(0.045)

	tw.tween_property(alvo, "scale", escala_base, 0.075).set_delay(0.10)
	tw.tween_property(alvo, "position", pos_base, 0.075).set_delay(0.10)



func _registrar_fx_explosao_bomba(pos: Vector2) -> void:
	for i in range(58):
		var ang: float = randf_range(-PI, PI)
		var vel: Vector2 = Vector2.RIGHT.rotated(ang) * randf_range(170.0, 560.0)

		var cor_estilhaco: Color
		if i % 3 == 0:
			cor_estilhaco = Color(0.02, 0.018, 0.015, 1.0)
		elif i % 3 == 1:
			cor_estilhaco = Color(0.08, 0.075, 0.065, 1.0)
		else:
			cor_estilhaco = Color(0.90, 0.38, 0.06, 1.0)

		fx_vidro.append({
			"tipo": "grande",
			"cor": cor_estilhaco,
			"pos": pos + Vector2(randf_range(-20.0, 20.0), randf_range(-18.0, 18.0)),
			"vel": vel,
			"rot": randf_range(0.0, TAU),
			"rot_vel": randf_range(-20.0, 20.0),
			"idade": 0.0,
			"vida": randf_range(0.55, 1.10),
			"tam": Vector2(randf_range(8.0, 22.0), randf_range(5.0, 15.0))
		})



func _configurar_intro_comeco() -> void:
	comeco_layer = CanvasLayer.new()
	comeco_layer.name = "ComecoLayer"
	comeco_layer.layer = 85
	add_child(comeco_layer)

	comeco_root = Control.new()
	comeco_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	comeco_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	comeco_root.visible = false
	comeco_layer.add_child(comeco_root)

	comeco_flash = ColorRect.new()
	comeco_flash.color = Color(0.20, 1.0, 0.32, 0.0)
	comeco_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	comeco_root.add_child(comeco_flash)

	comeco_titulo = Label.new()
	comeco_titulo.text = "3"
	comeco_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comeco_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(comeco_titulo, "font_size", 210)
	Leve.color(comeco_titulo, "font_color", COR_NEON_BAR_CLARO)
	Leve.color(comeco_titulo, "font_outline_color", Color(0.0, 0.05, 0.0, 1.0))
	Leve.constant(comeco_titulo, "outline_size", 18)
	comeco_titulo.visible = false
	comeco_titulo.pivot_offset = Vector2.ZERO

	if fonte_luckiest != null:
		Leve.font(comeco_titulo, "font", fonte_luckiest)
	elif ResourceLoader.exists(FONTE_LUCKIEST):
		Leve.font(comeco_titulo, "font", load(FONTE_LUCKIEST))

	comeco_root.add_child(comeco_titulo)

	comeco_subtitulo = Label.new()
	comeco_subtitulo.text = "PREPARE-SE"
	comeco_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comeco_subtitulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(comeco_subtitulo, "font_size", 48)
	Leve.color(comeco_subtitulo, "font_color", COR_NEON_BAR)
	Leve.color(comeco_subtitulo, "font_outline_color", Color(0.0, 0.05, 0.0, 1.0))
	Leve.constant(comeco_subtitulo, "outline_size", 9)
	comeco_subtitulo.visible = false

	if fonte_luckiest != null:
		Leve.font(comeco_subtitulo, "font", fonte_luckiest)
	elif ResourceLoader.exists(FONTE_LUCKIEST):
		Leve.font(comeco_subtitulo, "font", load(FONTE_LUCKIEST))

	comeco_root.add_child(comeco_subtitulo)



func _iniciar_intro_comeco() -> void:
	if intro_comeco_ativa:
		return

	intro_comeco_ativa = true
	intro_comeco_t = 0.0
	intro_contagem_valor = 3

	hud_animando_entrada = false
	hud_entrada_t = 0.0
	hud_top_offset_y = -220.0
	_ajustar_layout()

	if garrafas_root != null:
		garrafas_root.visible = false

	_esconder_aviso_inicio()

	if comeco_root != null:
		comeco_root.visible = true

	if comeco_flash != null:
		comeco_flash.color = Color(1.0, 1.0, 1.0, 0.0)

	if comeco_titulo != null:
		comeco_titulo.text = "3"
		comeco_titulo.visible = true
		comeco_titulo.modulate = Color(1, 1, 1, 0.0)
		comeco_titulo.scale = Vector2.ONE * 0.55
		Leve.font_size(comeco_titulo, "font_size", 220)

	if comeco_subtitulo != null:
		comeco_subtitulo.text = ""
		comeco_subtitulo.visible = false
		comeco_subtitulo.modulate = Color(1, 1, 1, 0.0)
		comeco_subtitulo.scale = Vector2.ONE

	call_deferred("_rodar_intro_comeco_async")



func _rodar_intro_comeco_async() -> void:
	for numero in [3, 2, 1]:
		if not is_inside_tree():
			return

		intro_contagem_valor = numero
		intro_comeco_t = 0.0

		if comeco_titulo != null:
			comeco_titulo.text = str(numero)
			comeco_titulo.visible = true
			comeco_titulo.modulate = Color(1, 1, 1, 0.0)
			comeco_titulo.scale = Vector2.ONE * 0.45
			Leve.font_size(comeco_titulo, "font_size", 210)
			Leve.color(comeco_titulo, "font_color", COR_NEON_BAR_CLARO)
			Leve.color(comeco_titulo, "font_outline_color", Color(0.0, 0.05, 0.0, 1.0))
			Leve.constant(comeco_titulo, "outline_size", 18)


		var tw_num := create_tween()
		tw_num.set_parallel(true)

		if comeco_flash != null:
			comeco_flash.color = Color(0.20, 1.0, 0.32, 0.0)
			tw_num.tween_property(comeco_flash, "color:a", 0.16, 0.10)
			tw_num.tween_property(comeco_flash, "color:a", 0.0, 0.28).set_delay(0.10)

		if comeco_titulo != null:
			tw_num.tween_property(comeco_titulo, "modulate:a", 1.0, 0.16)
			tw_num.tween_property(comeco_titulo, "scale", Vector2.ONE * 1.10, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_num.tween_property(comeco_titulo, "scale", Vector2.ONE, 0.22).set_delay(0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw_num.tween_property(comeco_titulo, "modulate:a", 0.0, 0.22).set_delay(0.62)


		await get_tree().create_timer(0.88).timeout

	if not is_inside_tree():
		return

	intro_comeco_t = 0.0

	if comeco_titulo != null:
		comeco_titulo.text = "COMEÇOU!!"
		comeco_titulo.visible = true
		comeco_titulo.modulate = Color(1, 1, 1, 0.0)
		comeco_titulo.scale = Vector2.ONE * 0.70
		Leve.font_size(comeco_titulo, "font_size", 84)
		Leve.color(comeco_titulo, "font_color", COR_NEON_BAR_CLARO)
		Leve.color(comeco_titulo, "font_outline_color", Color(0.0, 0.05, 0.0, 1.0))
		Leve.constant(comeco_titulo, "outline_size", 12)

	if comeco_subtitulo != null:
		comeco_subtitulo.visible = false

	var tw_go := create_tween()
	tw_go.set_parallel(true)

	if comeco_flash != null:
		comeco_flash.color = Color(0.20, 1.0, 0.32, 0.0)
		tw_go.tween_property(comeco_flash, "color:a", 0.22, 0.10)
		tw_go.tween_property(comeco_flash, "color:a", 0.0, 0.26).set_delay(0.10)

	if comeco_titulo != null:
		tw_go.tween_property(comeco_titulo, "modulate:a", 1.0, 0.14)
		tw_go.tween_property(comeco_titulo, "scale", Vector2.ONE * 1.02, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_go.tween_property(comeco_titulo, "modulate:a", 0.0, 0.22).set_delay(0.48)

	await get_tree().create_timer(0.78).timeout

	partida_iniciada = true
	tempo_restante = tempo_partida
	tempo_turno = 0.0
	intro_comeco_ativa = false

	if garrafas_root != null:
		garrafas_root.visible = true

	_iniciar_spawn_continuo()
	_iniciar_loop_troca_slots()

	hud_animando_entrada = false
	hud_entrada_t = 1.0
	hud_top_offset_y = 0.0
	_ajustar_layout()

	_marcar_hud_sujo()

	if comeco_titulo != null:
		comeco_titulo.visible = false
		comeco_titulo.scale = Vector2.ONE

	if comeco_subtitulo != null:
		comeco_subtitulo.visible = false
		comeco_subtitulo.scale = Vector2.ONE

	if comeco_root != null:
		comeco_root.visible = false


func _iniciar_loop_troca_slots() -> void:
	if loop_troca_slots_ativo:
		return

	loop_troca_slots_ativo = true
	call_deferred("_loop_troca_slots")


func _loop_troca_slots() -> void:
	while jogo_ativo and partida_iniciada and is_inside_tree():
		var espera_min: float = 2.00
		var espera_max: float = 3.20

		if pontuacao_total >= 3000:
			espera_min = 1.15
			espera_max = 2.00
		if pontuacao_total >= 7000:
			espera_min = 0.85
			espera_max = 1.55
		if pontuacao_total >= 14000:
			espera_min = 0.65
			espera_max = 1.20

		await get_tree().create_timer(randf_range(espera_min, espera_max)).timeout

		if not jogo_ativo or not partida_iniciada:
			break

		var trocas: int = 1
		if pontuacao_total >= 3000:
			trocas = 2
		if pontuacao_total >= 9000:
			trocas = 3

		for i in range(trocas):
			_forcar_troca_de_slot_ocupado()
			if i < trocas - 1:
				await get_tree().create_timer(0.14).timeout

	loop_troca_slots_ativo = false


func _forcar_troca_de_slot_ocupado() -> void:
	var candidatas_normais: Array[Area2D] = []
	var candidatas_falsas: Array[Area2D] = []

	for garrafa in garrafas_ativas:
		if garrafa == null or not is_instance_valid(garrafa):
			continue
		if garrafa.get("ja_acertado") == true:
			continue
		if garrafa.get("saindo_individual") == true:
			continue

		var tipo: String = _texto(garrafa.get("tipo_alvo"), "garrafa")

		if tipo == "garrafa_falsa":
			candidatas_falsas.append(garrafa)
		else:
			candidatas_normais.append(garrafa)

	candidatas_normais.shuffle()
	candidatas_falsas.shuffle()

	var minimo_impostoras: int = 1
	if pontuacao_total >= 3000:
		minimo_impostoras = 2
	if pontuacao_total >= 7000:
		minimo_impostoras = 3
	if pontuacao_total >= 14000:
		minimo_impostoras = 4

	var qtd_falsas: int = candidatas_falsas.size()
	var precisa_forcar_verde: bool = qtd_falsas < minimo_impostoras

	if candidatas_normais.is_empty():
		if not candidatas_falsas.is_empty() and qtd_falsas > minimo_impostoras:
			_fazer_garrafa_descer_e_sumir(candidatas_falsas[0])
		return

	var alvo: Area2D = null

	candidatas_normais.sort_custom(func(a: Area2D, b: Area2D) -> bool:
		var pa: int = _num_int(a.get("pontos_visual"), _num_int(a.get("pontos"), 20))
		var pb: int = _num_int(b.get("pontos_visual"), _num_int(b.get("pontos"), 20))
		return pa > pb
	)

	for g in candidatas_normais:
		var nasceu_ms: int = _num_int(g.get("nascido_em_ms"), 0)
		var idade: float = float(Time.get_ticks_msec() - nasceu_ms) / 1000.0
		var pontos_g: int = _num_int(g.get("pontos_visual"), _num_int(g.get("pontos"), 20))

		var idade_minima: float = 2.20

		match pontos_g:
			100:
				idade_minima = 1.20
			80:
				idade_minima = 1.55
			50:
				idade_minima = 2.15
			20:
				idade_minima = 3.20

		if precisa_forcar_verde:
			idade_minima *= 0.72

		if idade >= idade_minima:
			alvo = g
			break

	if alvo == null:
		return

	var pontos_visual: int = _num_int(alvo.get("pontos_visual"), _num_int(alvo.get("pontos"), 20))
	var slot_y: float = _num_float(
		alvo.get_meta("slot_y", _obter_y_base_por_pontos_visual(pontos_visual)),
		_obter_y_base_por_pontos_visual(pontos_visual)
	)

	var pontos_prat: int = _pontos_da_prateleira(slot_y)

	if precisa_forcar_verde:
		_substituir_por_impostora(alvo, pontos_prat)
		return

	var chance: float = _chance_impostora_por_pontos(pontos_visual)

	if pontos_visual >= 80:
		chance += 0.10

	if randf() <= min(chance, 0.98):
		_substituir_por_impostora(alvo, pontos_prat)
	else:
		_fazer_garrafa_descer_e_sumir(alvo)



func _adicionar_status_chat(texto: String, cor: Color, duracao: float = 2.2) -> void:
	if texto.strip_edges() == "":
		return

	status_chat_msgs.append({
		"texto": texto,
		"cor": cor,
		"tempo": duracao,
		"vida": duracao
	})

	while status_chat_msgs.size() > 3:
		status_chat_msgs.pop_front()

	_atualizar_status_chat_visual()


func _atualizar_status_chat(delta: float) -> void:
	for i in range(status_chat_msgs.size() - 1, -1, -1):
		var msg: Dictionary = status_chat_msgs[i]
		var tempo: float = _num_float(msg.get("tempo", 0.0), 0.0) - delta
		msg["tempo"] = tempo

		if tempo <= 0.0:
			status_chat_msgs.remove_at(i)
		else:
			status_chat_msgs[i] = msg

	_atualizar_status_chat_visual()


func _atualizar_status_chat_visual() -> void:
	var tela: Vector2 = get_viewport_rect().size

	var chat_w: float = tela.x - 48.0
	var chat_h: float = 68.0
	var chat_x: float = 24.0
	var chat_y: float = tela.y - 106.0

	var tem_msg: bool = status_chat_msgs.size() > 0

	if chat_rodape_panel != null:
		chat_rodape_panel.position = Vector2(chat_x, chat_y).round()
		chat_rodape_panel.size = Vector2(chat_w, chat_h)
		chat_rodape_panel.visible = tem_msg

	for i in range(status_chat_labels.size()):
		var lbl: Label = status_chat_labels[i]

		if lbl == null:
			continue

		if i >= status_chat_msgs.size():
			lbl.visible = false
			lbl.text = ""
			continue

		var idx_msg: int = status_chat_msgs.size() - 1 - i
		var msg: Dictionary = status_chat_msgs[idx_msg]

		var tempo: float = _num_float(msg.get("tempo", 1.0), 1.0)
		var vida: float = max(_num_float(msg.get("vida", 2.2), 2.2), 0.01)
		var cor: Color = msg.get("cor", Color.WHITE)

		var alpha_base: float = clamp(tempo / vida, 0.0, 1.0)

		if i == 0:
			lbl.text = _texto(msg.get("texto", ""), "")
			lbl.position = Vector2(chat_x + 18.0, chat_y + 4.0).round()
			lbl.size = Vector2(chat_w - 36.0, chat_h - 8.0)
			lbl.visible = true
			lbl.modulate = Color(1.0, 1.0, 1.0, clamp(alpha_base * 1.25, 0.25, 1.0))

			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			Leve.font_size(lbl, "font_size", 40)
			Leve.color(lbl, "font_color", Color.WHITE)
			Leve.color(lbl, "font_outline_color", Color.BLACK)
			Leve.constant(lbl, "outline_size", 8)

			if chat_rodape_panel != null:
				var estilo := chat_rodape_panel.get_theme_stylebox("panel") as StyleBoxFlat
				if estilo == null:
					estilo = _estilo_card_bar()
					Leve.stylebox(chat_rodape_panel, "panel", estilo)

				Leve.prop(estilo, "bg_color", Color(0.012, 0.045, 0.018, 0.88))
				Leve.prop(estilo, "border_color", cor)
				Leve.prop(estilo, "shadow_color", Color(cor.r, cor.g, cor.b, 0.74))
				Leve.prop(estilo, "shadow_size", 34)

		else:
			lbl.visible = false



func _texto(valor: Variant, padrao: String = "") -> String:
	if valor == null:
		return padrao

	var tipo := typeof(valor)

	if tipo == TYPE_STRING:
		return valor as String

	if tipo == TYPE_STRING_NAME:
		return str(valor)

	if tipo == TYPE_INT or tipo == TYPE_FLOAT or tipo == TYPE_BOOL:
		return str(valor)

	return padrao


func _iniciar_spawn_continuo() -> void:
	if spawn_continuo_ativo:
		return

	spawn_continuo_ativo = true
	call_deferred("_loop_spawn_continuo")






func _contar_impostoras_ativas() -> int:
	var total: int = 0

	for garrafa in garrafas_ativas:
		if garrafa == null or not is_instance_valid(garrafa):
			continue

		if _texto(garrafa.get("tipo_alvo"), "") == "garrafa_falsa":
			total += 1

	return total



func _loop_spawn_continuo() -> void:
	while jogo_ativo and partida_iniciada and is_inside_tree():
		await get_tree().create_timer(randf_range(intervalo_spawn_continuo_min, intervalo_spawn_continuo_max)).timeout

		if not jogo_ativo or not partida_iniciada:
			break

		_limpar_referencias_garrafas_invalidas()

		var tentativas: int = 0
		while tentativas < 3:
			if _spawnar_garrafa_individual_inteligente():
				break
			tentativas += 1

	spawn_continuo_ativo = false



func _spawnar_garrafa_individual_inteligente() -> bool:
	if garrafas_root == null:
		return false
	if not jogo_ativo or not partida_iniciada:
		return false

	_limpar_referencias_garrafas_invalidas()

	var opcoes: Array[Dictionary] = []

	for x in X_COLUNAS_20:
		opcoes.append({"x": float(x), "y": Y_PRATELEIRA_20})
	for x in X_COLUNAS_50:
		opcoes.append({"x": float(x), "y": Y_PRATELEIRA_50})
	for x in X_COLUNAS_80:
		opcoes.append({"x": float(x), "y": Y_PRATELEIRA_80})
	for x in X_COLUNAS_100:
		opcoes.append({"x": float(x), "y": Y_PRATELEIRA_100})

	opcoes.shuffle()

	for item in opcoes:
		var x_pos: float = _num_float(item.get("x", 0.0), 0.0)
		var y_base: float = _num_float(item.get("y", 0.0), 0.0)

		if not _slot_esta_livre(x_pos, y_base):
			continue

		var pontos: int = _pontos_da_prateleira(y_base)

		# Spawn normal nasce independente de ação do jogador.
		# A verde nasce mais por troca individual, não para lotar a tela.
		_criar_garrafa_em_posicao(pontos, x_pos, y_base, pontos)
		return true

	return false



func _contar_garrafas_por_pontos(pontos_busca: int) -> int:
	var total: int = 0

	for garrafa in garrafas_ativas:
		if garrafa == null or not is_instance_valid(garrafa):
			continue
		if garrafa.get("ja_acertado") == true:
			continue
		if garrafa.get("saindo_individual") == true:
			continue

		var tipo: String = _texto(garrafa.get("tipo_alvo"), "garrafa")
		var pontos: int = _num_int(garrafa.get("pontos_visual"), _num_int(garrafa.get("pontos"), 0))

		if tipo == "garrafa" and pontos == pontos_busca:
			total += 1

	return total


func _existe_garrafa_perto(x: float, y_base: float, distancia_minima: float) -> bool:
	for garrafa in garrafas_ativas:
		if garrafa == null or not is_instance_valid(garrafa):
			continue
		if garrafa.get("ja_acertado") == true:
			continue

		var pontos_visual: int = _num_int(
			garrafa.get("pontos_visual"),
			_num_int(garrafa.get("pontos"), 50)
		)

		var y_garrafa_base: float = _obter_y_base_por_pontos_visual(pontos_visual)

		if abs(y_garrafa_base - y_base) <= 8.0 and abs(garrafa.position.x - x) < distancia_minima:
			return true

	return false


func _num_float(valor: Variant, padrao: float = 0.0) -> float:
	if valor == null:
		return padrao

	var tipo := typeof(valor)

	if tipo == TYPE_FLOAT:
		return valor as float

	if tipo == TYPE_INT:
		var n: int = valor as int
		return n * 1.0

	if tipo == TYPE_STRING:
		var s: String = valor as String
		return s.to_float()

	return padrao


func _num_int(valor: Variant, padrao: int = 0) -> int:
	if valor == null:
		return padrao

	var tipo := typeof(valor)

	if tipo == TYPE_INT:
		return valor as int

	if tipo == TYPE_FLOAT:
		var n: float = valor as float
		return roundi(n)

	if tipo == TYPE_STRING:
		var s: String = valor as String
		return s.to_int()

	return padrao


func _num_vector2(valor: Variant, padrao: Vector2 = Vector2.ZERO) -> Vector2:
	if valor == null:
		return padrao

	if typeof(valor) == TYPE_VECTOR2:
		return valor as Vector2

	return padrao


func _detectar_garrafa_no_ponto(pos_global: Vector2) -> Area2D:
	var candidatas: Array[Area2D] = []

	for alvo in garrafas_ativas:
		if alvo == null or not is_instance_valid(alvo):
			continue
		if not alvo.visible:
			continue
		if alvo.get("ja_acertado") == true:
			continue
		if alvo.get("saindo_individual") == true:
			continue

		if _ponto_esta_sobre_garrafa_real(alvo, pos_global):
			candidatas.append(alvo)

	if candidatas.is_empty():
		return null

	candidatas.sort_custom(func(a: Area2D, b: Area2D) -> bool:
		var tipo_a: String = _texto(a.get("tipo_alvo"), "")
		var tipo_b: String = _texto(b.get("tipo_alvo"), "")

		if tipo_a == "garrafa_falsa" and tipo_b != "garrafa_falsa":
			return true
		if tipo_b == "garrafa_falsa" and tipo_a != "garrafa_falsa":
			return false

		if a.z_index != b.z_index:
			return a.z_index > b.z_index

		return a.get_index() > b.get_index()
	)

	return candidatas[0]


func _ponto_esta_sobre_garrafa_real(garrafa: Area2D, pos_global: Vector2) -> bool:
	if garrafa == null or not is_instance_valid(garrafa):
		return false

	var anim: AnimatedSprite2D = _obter_anim_garrafa(garrafa)

	if anim == null or anim.sprite_frames == null:
		return false

	var anim_nome: String = anim.animation
	if anim_nome == "":
		anim_nome = "idle"

	var frame_id: int = anim.frame

	if not anim.sprite_frames.has_animation(anim_nome):
		if anim.sprite_frames.has_animation("idle"):
			anim_nome = "idle"
		elif anim.sprite_frames.has_animation("default"):
			anim_nome = "default"
		else:
			return false

	var qtd_frames: int = anim.sprite_frames.get_frame_count(anim_nome)
	if qtd_frames <= 0:
		return false

	frame_id = clamp(frame_id, 0, qtd_frames - 1)

	var textura: Texture2D = anim.sprite_frames.get_frame_texture(anim_nome, frame_id)
	if textura == null:
		return false

	var ponto_local: Vector2 = anim.to_local(pos_global)

	var tamanho: Vector2 = textura.get_size()
	if tamanho.x <= 0.0 or tamanho.y <= 0.0:
		return false

	var metade: Vector2 = tamanho * 0.5

	if not anim.centered:
		metade = Vector2.ZERO

	var px: int = int(floor(ponto_local.x + metade.x))
	var py: int = int(floor(ponto_local.y + metade.y))

	if px < 0 or py < 0 or px >= int(tamanho.x) or py >= int(tamanho.y):
		return false

	var alfa: float = _alfa_no_pixel(textura, px, py)
	if alfa < 0.0:
		return true

	return alfa > 0.12


## Transparência de um pixel do quadro da garrafa. Antes, CADA tiro pedia à
## placa de vídeo a folha de sprites inteira (textura.get_image()), o que dava
## um tranco a cada disparo na TV Box. Agora a imagem de cada folha é lida uma
## vez só e fica guardada. Retorna -1 se a imagem não puder ser lida (conta
## como acerto, igual antes).
var _cache_alfa: Dictionary = {}

func _alfa_no_pixel(textura: Texture2D, px: int, py: int) -> float:
	var base: Texture2D = textura
	var origem := Vector2i.ZERO
	var limite := Vector2i(textura.get_size())
	if textura is AtlasTexture:
		var at := textura as AtlasTexture
		if at.atlas == null:
			return -1.0
		base = at.atlas
		origem = Vector2i(at.region.position)
		limite = Vector2i(at.region.size)
	# Fora do recorte do quadro: transparente (como o get_pixel de antes).
	if px >= limite.x or py >= limite.y:
		return 0.0
	var img: Image = _imagem_em_cache(base)
	if img == null:
		return -1.0
	var x: int = origem.x + px
	var y: int = origem.y + py
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return 0.0
	return img.get_pixel(x, y).a


func _imagem_em_cache(tex: Texture2D) -> Image:
	var chave: int = tex.get_instance_id()
	if _cache_alfa.has(chave):
		return _cache_alfa[chave]
	var img: Image = tex.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		if img.is_compressed() or img.is_empty():
			img = null
	else:
		img = null
	_cache_alfa[chave] = img
	return img


## Lê as folhas das garrafas uma por quadro, logo depois de abrir a fase,
## para o primeiro tiro em cada garrafa também não travar.
func _preaquecer_alfa_garrafas() -> void:
	for cena in [cena_garrafa_gin, cena_garrafa_rum, cena_garrafa_vodka, cena_garrafa_whisky, cena_garrafa_falsa]:
		if cena == null:
			continue
		var inst: Node = cena.instantiate()
		for anim in inst.find_children("*", "AnimatedSprite2D", true, false):
			var sf: SpriteFrames = (anim as AnimatedSprite2D).sprite_frames
			if sf == null:
				continue
			for nome in sf.get_animation_names():
				for i in range(sf.get_frame_count(nome)):
					var t: Texture2D = sf.get_frame_texture(nome, i)
					if t is AtlasTexture and (t as AtlasTexture).atlas != null:
						t = (t as AtlasTexture).atlas
					if t != null and not _cache_alfa.has(t.get_instance_id()):
						_imagem_em_cache(t)
						await get_tree().process_frame
						if not is_inside_tree():
							inst.free()
							return
		inst.free()


func _obter_sprite_principal_da_garrafa(garrafa: Area2D) -> Sprite2D:
	for filho in garrafa.get_children():
		if filho is Sprite2D:
			return filho as Sprite2D

	for filho in garrafa.get_children():
		for neto in filho.get_children():
			if neto is Sprite2D:
				return neto as Sprite2D

	return null


func _configurar_audio() -> void:
	if ResourceLoader.exists(CAMINHO_SOM_FAIL):
		som_fail_stream = load(CAMINHO_SOM_FAIL)
	else:
		push_warning("Som não encontrado: " + CAMINHO_SOM_FAIL)

	if ResourceLoader.exists(CAMINHO_SOM_SMASH):
		som_smash_stream = load(CAMINHO_SOM_SMASH)
	else:
		push_warning("Som não encontrado: " + CAMINHO_SOM_SMASH)

	if ResourceLoader.exists(CAMINHO_SOM_TIRO):
		som_tiro_stream = load(CAMINHO_SOM_TIRO)
	else:
		push_warning("Som não encontrado: " + CAMINHO_SOM_TIRO)

	if ResourceLoader.exists(som_recharge_path):
		som_recharge_stream = load(som_recharge_path)
	else:
		push_warning("Som não encontrado: " + som_recharge_path)

	if ResourceLoader.exists(som_bullet_no_path):
		som_bullet_no_stream = load(som_bullet_no_path)
	else:
		push_warning("Som não encontrado: " + som_bullet_no_path)

	if ResourceLoader.exists(som_fim_path):
		som_fim_stream = load(som_fim_path)
	else:
		push_warning("Som não encontrado: " + som_fim_path)

	if ResourceLoader.exists(som_bar_path):
		som_bar_stream = load(som_bar_path)
	else:
		push_warning("Som não encontrado: " + som_bar_path)


func _iniciar_musica_bar_em_loop() -> void:
	if som_bar_stream == null:
		return

	if bar_music_player == null:
		bar_music_player = AudioStreamPlayer.new()
		bar_music_player.bus = "Master"
		bar_music_player.finished.connect(_on_bar_music_finished)
		add_child(bar_music_player)

	bar_music_player.stream = som_bar_stream
	bar_music_player.volume_db = -1.0

	if not bar_music_player.playing:
		bar_music_player.play()

func _on_bar_music_finished() -> void:
	if fim_cutscene_ativa:
		return

	if not jogo_ativo and partida_iniciada:
		return

	if bar_music_player != null:
		bar_music_player.play()



func _parar_musica_bar() -> void:
	if bar_music_player != null and bar_music_player.playing:
		bar_music_player.stop()


func _tocar_som(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.bus = "Master"
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.play()

	player.finished.connect(func() -> void:
		if is_instance_valid(player):
			player.queue_free()
	)


func _tocar_som_erro() -> void:
	_tocar_som(som_fail_stream, 0.0)


func _tocar_som_acerto() -> void:
	_tocar_som(som_smash_stream, 0.0)


func _tocar_som_tiro() -> void:
	_tocar_som(som_tiro_stream, 0.0)


func _tocar_vidro_apos_tiro() -> void:
	_call_tocar_vidro_apos_tiro_async()


func _call_tocar_vidro_apos_tiro_async() -> void:
	await _tocar_vidro_apos_tiro_async()


func _tocar_vidro_apos_tiro_async() -> void:
	await get_tree().create_timer(0.07).timeout
	_tocar_som_acerto()


func _criar_luz_do_sol() -> void:
	if fundo == null or fundo.get_node_or_null("Sol") != null:
		return
	var sol := Node2D.new()
	sol.name = "Sol"
	sol.set_script(load("res://scripts/bar_sol.gd"))
	fundo.add_child(sol)


func _criar_fundo_preenchimento() -> void:
	if fundo == null or fundo.texture == null:
		return

	fundo_preenchimento = Sprite2D.new()
	fundo_preenchimento.texture = fundo.texture
	fundo_preenchimento.name = "FundoPreenchimento"
	fundo_preenchimento.z_index = -200
	fundo_preenchimento.modulate = Color(1, 1, 1, 1)
	fundo_preenchimento.visible = false
	add_child(fundo_preenchimento)
	move_child(fundo_preenchimento, 0)

	fundo.z_index = -100


func _coletar_spawn_points() -> void:
	spawn_points.clear()

	if spawn_points_root == null:
		return

	for filho in spawn_points_root.get_children():
		if filho is Marker2D:
			spawn_points.append(filho as Marker2D)

	spawn_points.sort_custom(func(a: Marker2D, b: Marker2D) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0
	)


func _sortear_colunas(base: Array, quantidade: int) -> Array:
	var copia: Array = base.duplicate()
	copia.shuffle()

	var qtd_final: int = clamp(quantidade, 0, copia.size())
	return copia.slice(0, qtd_final)


func _aplicar_ambiente_garrafa(garrafa: Area2D, pontos: int) -> void:
	match pontos:
		100:
			garrafa.modulate = Color(0.76, 0.82, 0.88, 0.80)
		80:
			garrafa.modulate = Color(0.82, 0.88, 0.93, 0.86)
		50:
			garrafa.modulate = Color(0.90, 0.94, 0.97, 0.92)
		20:
			garrafa.modulate = Color(0.98, 0.99, 1.0, 0.98)


func _obter_cena_garrafa_por_pontos(pontos: int) -> PackedScene:
	match pontos:
		20:
			return cena_garrafa_gin
		50:
			return cena_garrafa_rum
		80:
			return cena_garrafa_vodka
		100:
			return cena_garrafa_whisky
		_:
			return cena_garrafa_gin


func _criar_garrafa_em_posicao(pontos: int, x: float, y: float, pontos_base_visual: int = -1) -> void:
	if garrafas_root == null:
		return

	var pontos_da_prateleira: int = _pontos_da_prateleira(y)

	if pontos > 0:
		pontos = pontos_da_prateleira

	var pontos_visual: int = pontos_da_prateleira
	if pontos_base_visual > 0:
		pontos_visual = pontos_da_prateleira

	if not _slot_esta_livre(x, y):
		return

	var id_slot: String = _slot_id(x, y)
	_reservar_slot(x, y)

	var tipo_alvo: String = "garrafa"
	var cena_escolhida: PackedScene = null

	if pontos <= 0:
		tipo_alvo = "garrafa_falsa"
		cena_escolhida = cena_garrafa_falsa
	else:
		cena_escolhida = _obter_cena_garrafa_por_pontos(pontos)

	if cena_escolhida == null:
		
		return

	var inst = cena_escolhida.instantiate()
	if not (inst is Area2D):
		return

	var alvo_instancia: Area2D = inst as Area2D

	var escala: float = 0.60
	var offset_y: float = -68.0
	var raio_alvo: float = 118.0

	match pontos_visual:
		100:
			escala = 0.50
			offset_y = -66.0
			raio_alvo = 138.0
		80:
			escala = 0.56
			offset_y = -70.0
			raio_alvo = 132.0
		50:
			escala = 0.62
			offset_y = -74.0
			raio_alvo = 126.0
		20:
			escala = 0.58
			offset_y = -62.0
			raio_alvo = 104.0

	if tipo_alvo == "garrafa_falsa":
		# Maior no idle e mais baixa em todas as prateleiras
		match pontos_visual:
			100:
				escala = 0.81
				offset_y = -51.0
				raio_alvo = 195.0
			80:
				escala = 0.85
				offset_y = -27.0
				raio_alvo = 195.0
			50:
				escala = 0.96
				offset_y = -36.0
				raio_alvo = 195.0
			20:
				escala = 1.00
				offset_y = -33.0
				raio_alvo = 195.0

	garrafas_root.add_child(alvo_instancia)

	# identidade oficial do alvo
	alvo_instancia.set("pontos", pontos)
	alvo_instancia.set("pontos_visual", pontos_visual)
	alvo_instancia.set("tipo_alvo", tipo_alvo)
	alvo_instancia.set("nome_alvo", _obter_nome_garrafa_por_pontos(pontos_visual))
	alvo_instancia.set("nascido_em_ms", Time.get_ticks_msec())
	alvo_instancia.set("pode_mutar", tipo_alvo == "garrafa")
	alvo_instancia.set("penalidade", penalidade_garrafa_falsa if tipo_alvo == "garrafa_falsa" else 0)
	alvo_instancia.set("ja_acertado", false)
	alvo_instancia.set_meta("tipo_alvo", tipo_alvo)
	alvo_instancia.set_meta("pontos", pontos)
	alvo_instancia.set_meta("pontos_visual", pontos_visual)
	alvo_instancia.set_meta("slot_id", id_slot)
	alvo_instancia.set_meta("slot_x", x)
	alvo_instancia.set_meta("slot_y", y)

	alvo_instancia.visible = true
	alvo_instancia.show()
	alvo_instancia.z_index = 6
	alvo_instancia.scale = Vector2.ONE * escala
	alvo_instancia.process_mode = Node.PROCESS_MODE_INHERIT
	alvo_instancia.input_pickable = true
	alvo_instancia.monitoring = true
	alvo_instancia.monitorable = true
	alvo_instancia.modulate = Color.WHITE

	_forcar_idle_garrafa(alvo_instancia)
	_ajustar_colisao_alvo(alvo_instancia, tipo_alvo)

	garrafas_ativas.append(alvo_instancia)

	var pos_final: Vector2 = Vector2(x, y + offset_y)
	var pos_inicial: Vector2 = pos_final + Vector2(0.0, subir_de_baixo_px)

	alvo_instancia.position = pos_inicial
	alvo_instancia.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(alvo_instancia, "position", pos_final, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(alvo_instancia, "modulate:a", 1.0, 0.22)
	var vida_individual: float = _obter_vida_individual_por_pontos(pontos_visual)
	alvo_instancia.set("vida_individual", vida_individual)
	alvo_instancia.set("saindo_individual", false)
	
	var ciclo_id: int = randi()
	alvo_instancia.set_meta("ciclo_id", ciclo_id)

	if tipo_alvo == "garrafa_falsa":
		call_deferred("_animar_garrafa_falsa_trocando", alvo_instancia)

	call_deferred("_ciclo_individual_da_garrafa", alvo_instancia, ciclo_id)


func _vida_fixa_impostora(alvo: Area2D) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	await get_tree().create_timer(3.0).timeout

	if alvo == null or not is_instance_valid(alvo):
		return
	if alvo.get("ja_acertado") == true:
		return
	if alvo.get("saindo_individual") == true:
		return
	if not jogo_ativo or not partida_iniciada:
		return

	var tipo: String = _texto(alvo.get("tipo_alvo"), "")
	if tipo != "garrafa_falsa":
		return

	_fazer_garrafa_descer_e_sumir(alvo)



func _obter_config_visual_garrafa(pontos_visual: int, tipo_alvo: String) -> Dictionary:
	var escala: float = 0.60
	var offset_y: float = -68.0

	match pontos_visual:
		100:
			escala = 0.50
			offset_y = -51.0
		80:
			escala = 0.56
			offset_y = -70.0
		50:
			escala = 0.62
			offset_y = -74.0
		20:
			escala = 0.58
			offset_y = -62.0

	if tipo_alvo == "garrafa_falsa":
		match pontos_visual:
			100:
				escala = 0.77
				offset_y = -42.0
			80:
				escala = 0.90
				offset_y = -30.0 # desceu só a verde da prateleira 80
			50:
				escala = 0.98
				offset_y = -21.0 # desceu só a verde da prateleira 50
			20:
				escala = 0.99
				offset_y = -42.0

	return {
		"escala": escala,
		"offset_y": offset_y
	}


func _ciclo_individual_da_garrafa(alvo: Area2D, ciclo_id: int) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	if _num_int(alvo.get_meta("ciclo_id", -1), -1) != ciclo_id:
		return

	var tipo: String = _texto(alvo.get("tipo_alvo"), "garrafa")
	var pontos_visual: int = _num_int(alvo.get("pontos_visual"), _num_int(alvo.get("pontos"), 20))

	var slot_y: float = _num_float(
		alvo.get_meta("slot_y", _obter_y_base_por_pontos_visual(pontos_visual)),
		_obter_y_base_por_pontos_visual(pontos_visual)
	)

	var pontos_prateleira: int = _pontos_da_prateleira(slot_y)
	var vida: float = _vida_do_alvo_por_tipo(tipo, pontos_prateleira)

	await get_tree().create_timer(vida).timeout

	if alvo == null or not is_instance_valid(alvo):
		return
	if _num_int(alvo.get_meta("ciclo_id", -1), -1) != ciclo_id:
		return
	if alvo.get("ja_acertado") == true:
		return
	if alvo.get("saindo_individual") == true:
		return
	if not jogo_ativo or not partida_iniciada:
		return

	tipo = _texto(alvo.get("tipo_alvo"), "garrafa")

	if tipo == "garrafa_falsa":
		_fazer_garrafa_descer_e_sumir(alvo)
		return

	if randf() <= _chance_impostora_por_pontos(pontos_prateleira):
		_substituir_por_impostora(alvo, pontos_prateleira)
	else:
		_fazer_garrafa_descer_e_sumir(alvo)


func _vida_do_alvo_por_tipo(tipo: String, pontos: int) -> float:
	var nivel: int = _nivel_dificuldade_jogo()
	var reducao: float = min(1.80, float(nivel) * 0.22)

	if tipo == "garrafa_falsa":
		return randf_range(2.8, 3.8)

	match pontos:
		100: # WHISKY: mais rara, fica menos tempo
			return randf_range(max(1.65, 2.80 - reducao), max(2.25, 3.70 - reducao))
		80: # VODKA
			return randf_range(max(2.25, 3.70 - reducao), max(3.00, 4.80 - reducao))
		50: # RUM
			return randf_range(max(3.20, 4.80 - reducao), max(4.10, 6.10 - reducao))
		20: # GIN: menor valor, fica mais tempo
			return randf_range(max(4.40, 6.40 - reducao), max(5.60, 8.00 - reducao))
		_:
			return randf_range(4.0, 5.5)



func _substituir_por_impostora(alvo_antigo: Area2D, pontos_da_prateleira: int) -> void:
	if alvo_antigo == null or not is_instance_valid(alvo_antigo):
		return
	if alvo_antigo.get("ja_acertado") == true:
		return
	if alvo_antigo.get("saindo_individual") == true:
		return

	if cena_garrafa_falsa == null:
		_fazer_garrafa_descer_e_sumir(alvo_antigo)
		return

	var slot_x: float = _num_float(alvo_antigo.get_meta("slot_x", alvo_antigo.position.x), alvo_antigo.position.x)
	var slot_y: float = _num_float(
		alvo_antigo.get_meta("slot_y", _obter_y_base_por_pontos_visual(pontos_da_prateleira)),
		_obter_y_base_por_pontos_visual(pontos_da_prateleira)
	)
	var id_slot: String = _texto(alvo_antigo.get_meta("slot_id", _slot_id(slot_x, slot_y)), _slot_id(slot_x, slot_y))

	var inst = cena_garrafa_falsa.instantiate()
	if not (inst is Area2D):
		if inst != null:
			inst.queue_free()
		_fazer_garrafa_descer_e_sumir(alvo_antigo)
		return

	var cfg: Dictionary = _obter_config_visual_garrafa(pontos_da_prateleira, "garrafa_falsa")
	var escala: float = _num_float(cfg.get("escala", 1.0), 1.0)
	var offset_y: float = _num_float(cfg.get("offset_y", -42.0), -42.0)

	var nova: Area2D = inst as Area2D
	garrafas_root.add_child(nova)

	nova.position = Vector2(slot_x, slot_y + offset_y)
	nova.scale = Vector2.ONE * escala
	nova.modulate = Color(1, 1, 1, 1)
	nova.z_index = 50
	nova.visible = true
	nova.show()

	nova.set("pontos", 0)
	nova.set("pontos_visual", pontos_da_prateleira)
	nova.set("tipo_alvo", "garrafa_falsa")
	nova.set("nome_alvo", "IMPOSTORA")
	nova.set("penalidade", penalidade_garrafa_falsa)
	nova.set("ja_acertado", false)
	nova.set("saindo_individual", false)

	nova.set_meta("slot_id", id_slot)
	nova.set_meta("slot_x", slot_x)
	nova.set_meta("slot_y", slot_y)
	nova.set_meta("pontos_visual", pontos_da_prateleira)
	nova.set_meta("tipo_alvo", "garrafa_falsa")
	nova.set_meta("pontos", 0)

	nova.input_pickable = true
	nova.monitoring = true
	nova.monitorable = true
	nova.process_mode = Node.PROCESS_MODE_INHERIT

	_forcar_idle_garrafa(nova)
	_ajustar_colisao_alvo(nova, "garrafa_falsa")

	# A impostora entra IMEDIATAMENTE como alvo válido
	garrafas_ativas.erase(alvo_antigo)
	if not garrafas_ativas.has(nova):
		garrafas_ativas.append(nova)

	# A antiga deixa de contar no tiro NA HORA
	alvo_antigo.set("saindo_individual", true)
	alvo_antigo.set_meta("ciclo_id", -999999)
	alvo_antigo.monitoring = false
	alvo_antigo.monitorable = false
	alvo_antigo.input_pickable = false
	alvo_antigo.z_index = 1

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(alvo_antigo, "modulate:a", 0.0, 0.08)
	tw.tween_property(nova, "scale", nova.scale * 1.08, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(nova, "scale", Vector2.ONE * escala, 0.10).set_delay(0.08)

	await get_tree().create_timer(0.09).timeout

	if is_instance_valid(alvo_antigo):
		alvo_antigo.queue_free()

	if is_instance_valid(nova) and nova.get("saindo_individual") != true:
		var novo_ciclo_id: int = randi()
		nova.set_meta("ciclo_id", novo_ciclo_id)
		call_deferred("_ciclo_individual_da_garrafa", nova, novo_ciclo_id)
	else:
		_liberar_slot_por_id(id_slot)



func _fazer_garrafa_descer_e_sumir(alvo: Area2D) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return
	if alvo.get("ja_acertado") == true:
		return
	if alvo.get("saindo_individual") == true:
		return

	var id_slot: String = _texto(alvo.get_meta("slot_id", ""), "")

	alvo.set("saindo_individual", true)
	alvo.set_meta("ciclo_id", -999999)

	alvo.monitoring = false
	alvo.monitorable = false
	alvo.input_pickable = false

	garrafas_ativas.erase(alvo)
	_liberar_slot_por_id(id_slot)

	var pos_final: Vector2 = alvo.position + Vector2(0.0, subir_de_baixo_px)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(alvo, "position", pos_final, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(alvo, "modulate:a", 0.0, 0.22)

	await get_tree().create_timer(0.32).timeout

	if is_instance_valid(alvo):
		alvo.queue_free()


func _transformar_slot_em_outra_garrafa(alvo: Area2D, novo_pontos: int, pontos_visual: int) -> void:
	_trocar_garrafa_no_mesmo_slot(alvo, novo_pontos, pontos_visual)
 
 
func _trocar_garrafa_no_mesmo_slot(alvo_antigo: Area2D, novo_pontos: int, pontos_visual_base: int) -> void:
	if alvo_antigo == null or not is_instance_valid(alvo_antigo):
		return
	if alvo_antigo.get("ja_acertado") == true:
		return
	if alvo_antigo.get("saindo_individual") == true:
		return
 
	var tipo_atual: String = _texto(alvo_antigo.get("tipo_alvo"), "garrafa")
 
	# Impostora nunca "troca" — ela sempre some
	if tipo_atual == "garrafa_falsa":
		_fazer_garrafa_descer_e_sumir(alvo_antigo)
		return
 
	# Garrafa normal sendo trocada por impostora
	if novo_pontos <= 0:
		var pontos_prat: int = _pontos_da_prateleira(
			_num_float(alvo_antigo.get_meta("slot_y", _obter_y_base_por_pontos_visual(pontos_visual_base)), _obter_y_base_por_pontos_visual(pontos_visual_base))
		)
		_substituir_por_impostora(alvo_antigo, pontos_prat)
		return
 
	# Garrafa normal → outra garrafa normal (renovação via troca visual)
	var slot_x:  float  = _num_float(alvo_antigo.get_meta("slot_x",  alvo_antigo.position.x), alvo_antigo.position.x)
	var slot_y:  float  = _num_float(alvo_antigo.get_meta("slot_y",  _obter_y_base_por_pontos_visual(pontos_visual_base)), _obter_y_base_por_pontos_visual(pontos_visual_base))
	var id_slot: String = _texto(alvo_antigo.get_meta("slot_id", _slot_id(slot_x, slot_y)), _slot_id(slot_x, slot_y))
	var pontos_prateleira: int = _pontos_da_prateleira(slot_y)
 
	var cena_nova: PackedScene = _obter_cena_garrafa_por_pontos(pontos_prateleira)
	if cena_nova == null:
		_fazer_garrafa_descer_e_sumir(alvo_antigo)
		return
 
	var inst = cena_nova.instantiate()
	if not (inst is Area2D):
		if inst != null:
			inst.queue_free()
		_fazer_garrafa_descer_e_sumir(alvo_antigo)
		return
 
	var cfg:      Dictionary = _obter_config_visual_garrafa(pontos_prateleira, "garrafa")
	var escala:   float      = _num_float(cfg.get("escala",   0.60), 0.60)
	var offset_y: float      = _num_float(cfg.get("offset_y", -68.0), -68.0)
 
	var nova: Area2D = inst as Area2D
	garrafas_root.add_child(nova)
 
	nova.position  = Vector2(slot_x, slot_y + offset_y)
	nova.scale     = Vector2.ONE * escala
	nova.modulate  = Color(1, 1, 1, 0.0)
	nova.z_index   = 6
	nova.visible   = true
	nova.show()
 
	nova.set("pontos",            pontos_prateleira)
	nova.set("pontos_visual",     pontos_prateleira)
	nova.set("tipo_alvo",         "garrafa")
	nova.set("nome_alvo",         _obter_nome_garrafa_por_pontos(pontos_prateleira))
	nova.set("penalidade",        0)
	nova.set("ja_acertado",       false)
	nova.set("saindo_individual", false)
 
	nova.set_meta("slot_id",       id_slot)
	nova.set_meta("slot_x",        slot_x)
	nova.set_meta("slot_y",        slot_y)
	nova.set_meta("pontos_visual", pontos_prateleira)
	nova.set_meta("tipo_alvo",     "garrafa")
	nova.set_meta("pontos",        pontos_prateleira)
 
	nova.input_pickable = true
	nova.monitoring     = true
	nova.monitorable    = true
	nova.process_mode   = Node.PROCESS_MODE_INHERIT
 
	_forcar_idle_garrafa(nova)
	_ajustar_colisao_alvo(nova, "garrafa")
 
	alvo_antigo.set("saindo_individual", true)
	alvo_antigo.monitoring     = false
	alvo_antigo.monitorable    = false
	alvo_antigo.input_pickable = false
 
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(alvo_antigo, "modulate:a", 0.0, 0.14)
	tw.tween_property(nova,        "modulate:a", 1.0, 0.18)
 
	await get_tree().create_timer(0.20).timeout
 
	garrafas_ativas.erase(alvo_antigo)
	if is_instance_valid(alvo_antigo):
		alvo_antigo.queue_free()
 
	if is_instance_valid(nova) and nova.get("saindo_individual") != true:
		if not garrafas_ativas.has(nova):
			garrafas_ativas.append(nova)
		call_deferred("_ciclo_individual_da_garrafa", nova)
	else:
		_liberar_slot_por_id(id_slot)
 



# DEPOIS:
func _animar_garrafa_falsa_trocando(alvo: Area2D) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return
 
	var escala_base: Vector2 = alvo.scale
 
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(alvo, "scale", escala_base * 1.14, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(alvo, "scale", escala_base,        0.16).set_delay(0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)



func _slot_ocupado(slots: Array[Dictionary], x: float, y: float, distancia_minima: float = 92.0) -> bool:
	for item in slots:
		var ix: float = _num_float(item.get("x", 0.0), 0.0)
		var iy: float = _num_float(item.get("y", 0.0), 0.0)

		if abs(iy - y) <= 8.0 and abs(ix - x) < distancia_minima:
			return true

	return false


func _adicionar_slot_seguro(slots: Array[Dictionary], novo: Dictionary, distancia_minima: float = 92.0) -> bool:
	var x: float = _num_float(novo.get("x", 0.0), 0.0)
	var y: float = _num_float(novo.get("y", 0.0), 0.0)

	if _slot_ocupado(slots, x, y, distancia_minima):
		return false

	slots.append(novo)
	return true


func _ajustar_colisao_alvo(alvo: Area2D, tipo_alvo: String) -> void:
	if alvo == null:
		return

	var col: CollisionShape2D = null

	for filho in alvo.get_children():
		if filho is CollisionShape2D:
			col = filho as CollisionShape2D
			break

	if col == null:
		col = CollisionShape2D.new()
		col.name = "CollisionShape2D"
		alvo.add_child(col)

	var pontos_visual: int = _num_int(alvo.get("pontos_visual"), _num_int(alvo.get("pontos"), 50))

	var shape := RectangleShape2D.new()

	match pontos_visual:
		100:
			shape.size = Vector2(54.0, 158.0)
		80:
			shape.size = Vector2(56.0, 162.0)
		50:
			shape.size = Vector2(58.0, 166.0)
		20:
			shape.size = Vector2(52.0, 150.0)
		_:
			shape.size = Vector2(56.0, 158.0)

	col.shape = shape
	col.position = Vector2.ZERO
	col.disabled = false


func _forcar_idle_garrafa(garrafa: Area2D) -> void:
	var anim: AnimatedSprite2D = _obter_anim_garrafa(garrafa)
	if anim == null:
		return

	anim.visible = true
	anim.show()
	anim.modulate = Color.WHITE
	anim.self_modulate = Color.WHITE

	if anim.sprite_frames != null:
		if anim.sprite_frames.has_animation("idle"):
			anim.play("idle")
		elif anim.sprite_frames.has_animation("default"):
			anim.play("default")


func _obter_anim_garrafa(garrafa: Area2D) -> AnimatedSprite2D:
	for filho in garrafa.get_children():
		if filho is AnimatedSprite2D:
			return filho as AnimatedSprite2D

	for filho in garrafa.get_children():
		for neto in filho.get_children():
			if neto is AnimatedSprite2D:
				return neto as AnimatedSprite2D

	return null


func _obter_cor_vidro_por_pontos(pontos: int) -> Color:
	match pontos:
		100:
			return Color(0.55, 0.28, 0.08, 1.0) # whisky marrom
		80:
			return Color(0.92, 0.97, 1.0, 1.0) # vodka branca/cinza
		50:
			return Color(0.48, 0.22, 0.07, 1.0) # rum marrom
		20:
			return Color(0.86, 0.90, 0.88, 1.0) # gin cinza/branco
		_:
			return Color(0.80, 1.0, 0.78, 1.0) # impostora verde


func _obter_cor_liquido_por_alvo(tipo_alvo: String, pontos: int) -> Color:
	if tipo_alvo == "garrafa_falsa":
		return Color(0.16, 1.0, 0.25, 1.0)

	match pontos:
		100:
			return Color(0.42, 0.20, 0.05, 1.0) # whisky
		80:
			return Color(0.92, 0.97, 1.0, 1.0) # vodka
		50:
			return Color(0.46, 0.18, 0.04, 1.0) # rum
		20:
			return Color(0.96, 0.98, 1.0, 1.0) # gin
		_:
			return Color(0.90, 0.95, 1.0, 1.0)

func _slot_id(x: float, y_base: float) -> String:
	return "%d_%d" % [roundi(x), roundi(y_base)]


func _slot_esta_livre(x: float, y_base: float) -> bool:
	var id: String = _slot_id(x, y_base)

	if slots_reservados.has(id):
		return false

	for garrafa in garrafas_ativas:
		if garrafa == null or not is_instance_valid(garrafa):
			continue
		if garrafa.get("ja_acertado") == true:
			continue

		var slot_garrafa: String = _texto(garrafa.get_meta("slot_id", ""), "")
		if slot_garrafa == id:
			return false

	return true


func _reservar_slot(x: float, y_base: float) -> void:
	slots_reservados[_slot_id(x, y_base)] = true


func _liberar_slot_por_id(id: String) -> void:
	if id != "" and slots_reservados.has(id):
		slots_reservados.erase(id)


func _obter_y_base_por_pontos_visual(pontos_visual: int) -> float:
	match pontos_visual:
		100:
			return Y_PRATELEIRA_100
		80:
			return Y_PRATELEIRA_80
		50:
			return Y_PRATELEIRA_50
		20:
			return Y_PRATELEIRA_20
		_:
			return Y_PRATELEIRA_50

func _obter_offset_visual_por_pontos(pontos_visual: int) -> float:
	match pontos_visual:
		100:
			return -48.0
		80:
			return -48.0
		50:
			return -48.0
		20:
			return -48.0
		_:
			return -48.0


func _limpar_referencias_garrafas_invalidas() -> void:
	for i in range(garrafas_ativas.size() - 1, -1, -1):
		var g: Area2D = garrafas_ativas[i]
		if g == null or not is_instance_valid(g) or g.get("ja_acertado") == true:
			garrafas_ativas.remove_at(i)


func _limpar_garrafas_antigas() -> void:
	for garrafa in garrafas_ativas:
		if is_instance_valid(garrafa):
			garrafa.queue_free()
 
	garrafas_ativas.clear()
	slots_reservados.clear()



func _on_garrafa_acertada(pontos: int, garrafa: Area2D, pos_global: Vector2) -> void:
	if garrafa == null or not is_instance_valid(garrafa):
		return

	# Não deixa scripts antigos da cena somarem ponto por fora.
	_processar_acerto_alvo(garrafa)


func _registrar_fx_vidro_colorido(pos: Vector2, cor_base: Color, cor_liquido: Color = Color.TRANSPARENT) -> void:
	for i in range(26):
		var ang: float = randf_range(-PI * 0.95, -PI * 0.05)
		var vel: Vector2 = Vector2.RIGHT.rotated(ang) * randf_range(180.0, 440.0)
		vel.x += randf_range(-130.0, 130.0)
		vel.y -= randf_range(50.0, 160.0)

		fx_vidro.append({
			"tipo": "grande",
			"cor": cor_base,
			"pos": pos + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0)),
			"vel": vel,
			"rot": randf_range(0.0, TAU),
			"rot_vel": randf_range(-12.0, 12.0),
			"idade": 0.0,
			"vida": randf_range(0.70, 1.25),
			"tam": Vector2(randf_range(8.0, 18.0), randf_range(4.0, 10.0))
		})

	for i in range(30):
		var ang2: float = randf_range(-PI, PI)
		var vel2: Vector2 = Vector2.RIGHT.rotated(ang2) * randf_range(120.0, 320.0)

		fx_vidro.append({
			"tipo": "pequeno",
			"cor": cor_base,
			"pos": pos + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)),
			"vel": vel2,
			"rot": randf_range(0.0, TAU),
			"rot_vel": randf_range(-16.0, 16.0),
			"idade": 0.0,
			"vida": randf_range(0.45, 0.90),
			"tam": Vector2(randf_range(3.0, 8.0), randf_range(2.0, 5.0))
		})

	if cor_liquido != Color.TRANSPARENT:
		for i in range(22):
			var ang3: float = randf_range(-PI * 0.95, -PI * 0.05)
			var vel3: Vector2 = Vector2.RIGHT.rotated(ang3) * randf_range(90.0, 260.0)
			vel3.x += randf_range(-90.0, 90.0)
			vel3.y -= randf_range(20.0, 110.0)

			fx_vidro.append({
				"tipo": "gota",
				"cor": cor_liquido,
				"pos": pos + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)),
				"vel": vel3,
				"rot": 0.0,
				"rot_vel": 0.0,
				"idade": 0.0,
				"vida": randf_range(0.55, 1.05),
				"tam": Vector2(randf_range(3.0, 7.0), randf_range(3.0, 7.0))
			})



func _registrar_erro_visual(pos: Vector2) -> void:
	while marcas_erro.size() >= MAX_MARCAS_ERRO:
		marcas_erro.remove_at(0)
	marcas_erro.append({
		"pos": pos,
		"idade": 0.0,
		"vida": 9999.0,
		"raio": randf_range(7.0, 10.5),
		"anel": randf_range(12.0, 18.0),
		"poeira": randf_range(16.0, 24.0),
		"desvio_x": randf_range(-1.5, 1.5),
		"desvio_y": randf_range(-1.5, 1.5)
	})
	queue_redraw()
	_redesenhar_marcas()


func _atualizar_marcas_erro(delta: float) -> void:
	for i in range(marcas_erro.size() - 1, -1, -1):
		var marca: Dictionary = marcas_erro[i]

		var idade: float = _num_float(marca.get("idade", 0.0), 0.0) + delta
		var vida: float = _num_float(marca.get("vida", 9999.0), 9999.0)

		marca["idade"] = idade

		if idade >= vida:
			marcas_erro.remove_at(i)
			_redesenhar_marcas()
		else:
			marcas_erro[i] = marca


func _registrar_fx_madeira(pos: Vector2) -> void:
	for i in range(14):
		var ang: float = randf_range(-PI, PI)
		var vel: Vector2 = Vector2.RIGHT.rotated(ang) * randf_range(90.0, 240.0)

		fx_madeira.append({
			"pos": pos + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)),
			"vel": vel,
			"idade": 0.0,
			"vida": randf_range(0.18, 0.36),
			"tam": randf_range(4.0, 11.0)
		})


func _atualizar_fx_madeira(delta: float) -> void:
	for i in range(fx_madeira.size() - 1, -1, -1):
		var fx: Dictionary = fx_madeira[i]

		var idade: float = _num_float(fx.get("idade", 0.0), 0.0) + delta
		var vida: float = _num_float(fx.get("vida", 0.25), 0.25)
		var pos: Vector2 = _num_vector2(fx.get("pos", Vector2.ZERO), Vector2.ZERO)
		var vel: Vector2 = _num_vector2(fx.get("vel", Vector2.ZERO), Vector2.ZERO)

		fx["idade"] = idade
		fx["pos"] = pos + vel * delta
		fx["vel"] = vel * 0.92

		if idade >= vida:
			fx_madeira.remove_at(i)
		else:
			fx_madeira[i] = fx



func _nivel_dificuldade_jogo() -> int:
	# dificuldade só sobe com bastante ponto
	return int(floor(float(max(pontuacao_total, 0)) / 3000.0))



func _max_garrafas_ativas_atual() -> int:
	var nivel: int = _nivel_dificuldade_jogo()
	return clamp(13 + nivel, 13, 22)


func _chance_impostora_por_pontos(pontos: int) -> float:
	if pontuacao_total < 1500:
		match pontos:
			100:
				return 0.52
			80:
				return 0.44
			50:
				return 0.34
			20:
				return 0.24
			_:
				return 0.35

	if pontuacao_total < 3000:
		match pontos:
			100:
				return 0.68
			80:
				return 0.58
			50:
				return 0.46
			20:
				return 0.34
			_:
				return 0.45

	if pontuacao_total < 7000:
		match pontos:
			100:
				return 0.88
			80:
				return 0.80
			50:
				return 0.68
			20:
				return 0.52
			_:
				return 0.55

	match pontos:
		100:
			return 0.96
		80:
			return 0.90
		50:
			return 0.78
		20:
			return 0.62
		_:
			return 0.65


func _vida_normal_atual(pontos: int) -> float:
	var nivel: int = _nivel_dificuldade_jogo()
	var reducao: float = min(2.40, float(nivel) * 0.35)

	match pontos:
		100:
			return randf_range(max(1.10, 2.10 - reducao), max(1.50, 3.00 - reducao))
		80:
			return randf_range(max(1.50, 2.80 - reducao), max(2.00, 4.00 - reducao))
		50:
			return randf_range(max(1.80, 3.40 - reducao), max(2.40, 4.80 - reducao))
		20:
			return randf_range(max(2.10, 4.00 - reducao), max(2.80, 5.60 - reducao))
		_:
			return randf_range(2.0, 3.0)


func _obter_vida_impostora_atual() -> float:
	var nivel: int = _nivel_dificuldade_jogo()
	var reducao: float = min(1.40, float(nivel) * 0.18)

	return randf_range(
		max(1.35, vida_impostora_min - reducao),
		max(2.20, vida_impostora_max - reducao)
	)

func _registrar_fx_vidro(pos: Vector2) -> void:
	for i in range(22):
		var ang: float = randf_range(-PI * 0.95, -PI * 0.05)
		var vel: Vector2 = Vector2.RIGHT.rotated(ang) * randf_range(180.0, 420.0)
		vel.x += randf_range(-120.0, 120.0)
		vel.y -= randf_range(40.0, 140.0)

		fx_vidro.append({
			"tipo": "grande",
			"pos": pos + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0)),
			"vel": vel,
			"rot": randf_range(0.0, TAU),
			"rot_vel": randf_range(-12.0, 12.0),
			"idade": 0.0,
			"vida": randf_range(0.70, 1.25),
			"tam": Vector2(randf_range(8.0, 18.0), randf_range(4.0, 10.0))
		})

	for i in range(26):
		var ang2: float = randf_range(-PI, PI)
		var vel2: Vector2 = Vector2.RIGHT.rotated(ang2) * randf_range(120.0, 300.0)

		fx_vidro.append({
			"tipo": "pequeno",
			"pos": pos + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)),
			"vel": vel2,
			"rot": randf_range(0.0, TAU),
			"rot_vel": randf_range(-16.0, 16.0),
			"idade": 0.0,
			"vida": randf_range(0.45, 0.90),
			"tam": Vector2(randf_range(3.0, 8.0), randf_range(2.0, 5.0))
		})


func _atualizar_fx_vidro(delta: float) -> void:
	for i in range(fx_vidro.size() - 1, -1, -1):
		var fx: Dictionary = fx_vidro[i]
		var tipo: String = _texto(fx.get("tipo", "grande"), "grande")

		var idade: float = _num_float(fx.get("idade", 0.0), 0.0) + delta
		var vida: float = _num_float(fx.get("vida", 1.0), 1.0)
		var pos: Vector2 = _num_vector2(fx.get("pos", Vector2.ZERO), Vector2.ZERO)
		var vel: Vector2 = _num_vector2(fx.get("vel", Vector2.ZERO), Vector2.ZERO)
		var rot: float = _num_float(fx.get("rot", 0.0), 0.0)
		var rot_vel: float = _num_float(fx.get("rot_vel", 0.0), 0.0)

		var gravidade: float = 620.0
		var arrasto: float = 0.965

		if tipo == "pequeno":
			gravidade = 520.0
			arrasto = 0.94

		vel = vel + Vector2(0.0, gravidade) * delta
		pos = pos + vel * delta
		vel = vel * arrasto
		rot = rot + rot_vel * delta

		fx["idade"] = idade
		fx["pos"] = pos
		fx["vel"] = vel
		fx["rot"] = rot

		if idade >= vida:
			fx_vidro.remove_at(i)
		else:
			fx_vidro[i] = fx


func _criar_camadas_estaticas() -> void:
	_camada_estantes = Node2D.new()
	_camada_estantes.name = "CamadaEstantes"
	_camada_estantes.show_behind_parent = true
	add_child(_camada_estantes)
	_camada_estantes.draw.connect(_desenhar_camada_estantes)

	_camada_marcas = Node2D.new()
	_camada_marcas.name = "CamadaMarcasTiro"
	_camada_marcas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_camada_marcas.show_behind_parent = true
	add_child(_camada_marcas)
	_camada_marcas.draw.connect(_desenhar_marcas_erro)

	get_viewport().size_changed.connect(_camada_estantes.queue_redraw)


func _desenhar_camada_estantes() -> void:
	_desenhar_profundidade_estantes()
	_desenhar_sombra_estantes()


func _redesenhar_marcas() -> void:
	if _camada_marcas != null:
		_camada_marcas.queue_redraw()


func _desenhar_profundidade_estantes() -> void:
	var largura_tela: float = get_viewport_rect().size.x
	var altura_tela: float = get_viewport_rect().size.y
	var y_inicio: float = CORTE_DESENHO_TOPO_Y
	var altura_util: float = max(0.0, altura_tela - y_inicio)

	if altura_util <= 0.0:
		return

	_camada_estantes.draw_rect(Rect2(0.0, y_inicio, largura_tela, altura_util), Color(0.0, 0.0, 0.0, 0.015), true)
	_camada_estantes.draw_rect(Rect2(0.0, y_inicio, 54.0, altura_util), Color(0.0, 0.0, 0.0, 0.012), true)
	_camada_estantes.draw_rect(Rect2(largura_tela - 54.0, y_inicio, 54.0, altura_util), Color(0.0, 0.0, 0.0, 0.012), true)

	if Y_PRATELEIRA_100 - 72.0 >= y_inicio:
		_camada_estantes.draw_rect(Rect2(78.0, Y_PRATELEIRA_100 - 72.0, 720.0, 26.0), Color(0.0, 0.0, 0.0, 0.030), true)

	if Y_PRATELEIRA_80 - 62.0 >= y_inicio:
		_camada_estantes.draw_rect(Rect2(60.0, Y_PRATELEIRA_80 - 62.0, 758.0, 24.0), Color(0.0, 0.0, 0.0, 0.026), true)

	if Y_PRATELEIRA_50 - 52.0 >= y_inicio:
		_camada_estantes.draw_rect(Rect2(44.0, Y_PRATELEIRA_50 - 52.0, 790.0, 22.0), Color(0.0, 0.0, 0.0, 0.022), true)

	_camada_estantes.draw_rect(
		Rect2(30.0, Y_PRATELEIRA_20 - 44.0, AREA_BARRIL_X_INICIO - 30.0, 24.0),
		Color(0.0, 0.0, 0.0, 0.0),
		true
	)

	if AREA_BARRIL_X_FIM < largura_tela:
		_camada_estantes.draw_rect(
			Rect2(AREA_BARRIL_X_FIM, Y_PRATELEIRA_20 - 44.0, largura_tela - AREA_BARRIL_X_FIM, 24.0),
			Color(0.0, 0.0, 0.0, 0.0),
			true
		)


func _desenhar_sombra_estantes() -> void:
	var largura_tela: float = get_viewport_rect().size.x
	var y_inicio: float = CORTE_DESENHO_TOPO_Y

	if Y_PRATELEIRA_100 + 34.0 >= y_inicio:
		_camada_estantes.draw_rect(Rect2(80.0, Y_PRATELEIRA_100 + 34.0, 714.0, 8.0), Color(0.0, 0.0, 0.0, 0.045), true)

	if Y_PRATELEIRA_80 + 36.0 >= y_inicio:
		_camada_estantes.draw_rect(Rect2(64.0, Y_PRATELEIRA_80 + 36.0, 748.0, 8.0), Color(0.0, 0.0, 0.0, 0.042), true)

	if Y_PRATELEIRA_50 + 38.0 >= y_inicio:
		_camada_estantes.draw_rect(Rect2(48.0, Y_PRATELEIRA_50 + 38.0, 784.0, 8.0), Color(0.0, 0.0, 0.0, 0.040), true)

	_camada_estantes.draw_rect(
		Rect2(34.0, Y_PRATELEIRA_20 + 40.0, AREA_BARRIL_X_INICIO - 34.0, 8.0),
		Color(0.0, 0.0, 0.0, 0.0),
		true
	)

	if AREA_BARRIL_X_FIM < largura_tela:
		_camada_estantes.draw_rect(
			Rect2(AREA_BARRIL_X_FIM, Y_PRATELEIRA_20 + 40.0, largura_tela - AREA_BARRIL_X_FIM, 8.0),
			Color(0.0, 0.0, 0.0, 0.0),
			true
		)



func _configurar_modal_nome_ranking() -> void:
	ranking_nome_layer         = CanvasLayer.new()
	ranking_nome_layer.name    = "RankingNomeLayer"
	ranking_nome_layer.layer   = 180
	ranking_nome_layer.visible = false
	add_child(ranking_nome_layer)

	ranking_nome_root = Control.new()
	ranking_nome_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ranking_nome_root.mouse_filter = Control.MOUSE_FILTER_STOP
	ranking_nome_layer.add_child(ranking_nome_root)

	ranking_nome_bg       = ColorRect.new()
	ranking_nome_bg.color = Color(0.0, 0.0, 0.0, 0.84)
	ranking_nome_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ranking_nome_root.add_child(ranking_nome_bg)

	ranking_nome_panel = Panel.new()
	ranking_nome_root.add_child(ranking_nome_panel)
	Leve.stylebox(ranking_nome_panel, "panel", _estilo_modal_bar())

	# ── Título ────────────────────────────────────────────────────────────
	ranking_nome_titulo = Label.new()
	ranking_nome_titulo.text = "🏆 NOVO RECORDE!"
	ranking_nome_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranking_nome_titulo.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(ranking_nome_titulo, "font_size", 46)
	Leve.color(ranking_nome_titulo, "font_color", Color(0.82, 1.0, 0.86, 1.0))
	Leve.color(ranking_nome_titulo, "font_outline_color", Color.BLACK)
	Leve.constant(ranking_nome_titulo, "outline_size", 8)
	ranking_nome_panel.add_child(ranking_nome_titulo)

	# ── Instrução ─────────────────────────────────────────────────────────
	ranking_nome_texto = Label.new()
	ranking_nome_texto.text = "ATIRE NAS LETRAS PARA ESCREVER SEU NOME\nMÁXIMO 9 LETRAS"
	ranking_nome_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranking_nome_texto.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(ranking_nome_texto, "font_size", 24)
	Leve.color(ranking_nome_texto, "font_color", COR_NEON_BAR_CLARO)
	Leve.color(ranking_nome_texto, "font_outline_color", Color.BLACK)
	Leve.constant(ranking_nome_texto, "outline_size", 5)
	ranking_nome_panel.add_child(ranking_nome_texto)

	# ── Display do nome digitado ───────────────────────────────────────────
	ranking_nome_display = Label.new()
	ranking_nome_display.text = "---------"
	ranking_nome_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranking_nome_display.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(ranking_nome_display, "font_size", 54)
	Leve.color(ranking_nome_display, "font_color", COR_NEON_BAR)
	Leve.color(ranking_nome_display, "font_outline_color", Color.BLACK)
	Leve.constant(ranking_nome_display, "outline_size", 9)
	if fonte_orbitron != null:
		Leve.font(ranking_nome_display, "font", fonte_orbitron)
	ranking_nome_panel.add_child(ranking_nome_display)

	# ── Teclado de letras ─────────────────────────────────────────────────
	ranking_nome_teclado = GridContainer.new()
	ranking_nome_teclado.columns = 9
	Leve.constant(ranking_nome_teclado, "h_separation", 8)
	Leve.constant(ranking_nome_teclado, "v_separation", 8)
	ranking_nome_panel.add_child(ranking_nome_teclado)

	var letras := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	for i in range(letras.length()):
		var letra := letras.substr(i, 1)
		var btn   := _criar_botao_tecla_ranking(letra)
		btn.pressed.connect(_ranking_tecla_letra.bind(letra))
		ranking_nome_teclado.add_child(btn)

	# ── Botões de ação ────────────────────────────────────────────────────
	ranking_nome_btn_apagar = _criar_botao_tecla_ranking("⌫  APAGAR")
	Leve.color(ranking_nome_btn_apagar, "font_color", Color(0.02, 0.10, 0.04, 1.0))
	ranking_nome_btn_apagar.pressed.connect(_ranking_apagar_letra)
	ranking_nome_panel.add_child(ranking_nome_btn_apagar)

	ranking_nome_btn_ok = _criar_botao_tecla_ranking("✔  SALVAR")
	Leve.color(ranking_nome_btn_ok, "font_color", Color(0.02, 0.10, 0.04, 1.0))
	ranking_nome_btn_ok.pressed.connect(_confirmar_nome_ranking.bind(false))
	ranking_nome_panel.add_child(ranking_nome_btn_ok)

	# ── Timer de salvamento automático ────────────────────────────────────
	ranking_nome_timer_label = Label.new()
	ranking_nome_timer_label.text = "SALVA COMO ANONIMO EM 50"
	ranking_nome_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranking_nome_timer_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(ranking_nome_timer_label, "font_size", 24)
	Leve.color(ranking_nome_timer_label, "font_color", COR_NEON_BAR_CLARO)
	Leve.color(ranking_nome_timer_label, "font_outline_color", Color.BLACK)
	Leve.constant(ranking_nome_timer_label, "outline_size", 6)
	ranking_nome_panel.add_child(ranking_nome_timer_label)

	call_deferred("_ajustar_modal_nome_ranking")



func _criar_botao_tecla_ranking(texto: String) -> Button:
	var btn := Button.new()
	btn.text = texto
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Leve.font_size(btn, "font_size", 24)
	Leve.color(btn, "font_color", Color(0.02, 0.10, 0.04, 1.0))

	if fonte_luckiest != null:
		Leve.font(btn, "font", fonte_luckiest)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.96, 0.28, 0.92)
	normal.border_color = Color(0.12, 0.72, 0.20, 1.0)
	normal.border_width_left   = 2
	normal.border_width_top    = 2
	normal.border_width_right  = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left     = 14
	normal.corner_radius_top_right    = 14
	normal.corner_radius_bottom_left  = 14
	normal.corner_radius_bottom_right = 14
	normal.shadow_color = Color(0.20, 1.0, 0.30, 0.36)
	normal.shadow_size  = 8

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.44, 1.0, 0.52, 1.0)
	hover.border_color = Color(0.18, 0.88, 0.28, 1.0)
	hover.border_width_left   = 2
	hover.border_width_top    = 2
	hover.border_width_right  = 2
	hover.border_width_bottom = 2
	hover.corner_radius_top_left     = 14
	hover.corner_radius_top_right    = 14
	hover.corner_radius_bottom_left  = 14
	hover.corner_radius_bottom_right = 14
	hover.shadow_color = Color(0.20, 1.0, 0.32, 0.62)
	hover.shadow_size  = 14

	Leve.stylebox(btn, "normal",  normal)
	Leve.stylebox(btn, "hover",   hover)
	Leve.stylebox(btn, "pressed", hover)

	return btn


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


func _abrir_modal_nome_ranking_bar(pontos: int, precisao: int) -> void:
	ranking_pontos_pendentes = pontos
	ranking_cenario_pendente = "BAR"
	ranking_precisao_pendente = clamp(precisao, 0, 100)
	ranking_nome_tempo = 50.0
	ranking_nome_ativo = true
	ranking_ja_salvo = false
	ranking_nome_digitado = ""
	ranking_input_trava = 0.0

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if ranking_nome_layer != null:
		ranking_nome_layer.visible = true

	if ranking_nome_timer_label != null:
		ranking_nome_timer_label.text = "SALVA COMO ANONIMO EM 50"

	_atualizar_display_nome_ranking()
	_ajustar_modal_nome_ranking()


func _confirmar_nome_ranking(usar_anonimo: bool = false) -> void:
	if ranking_ja_salvo:
		return

	var nome_final: String = "ANONIMO"

	if not usar_anonimo:
		var digitado: String = ranking_nome_digitado.strip_edges().to_upper()
		if digitado != "":
			nome_final = digitado

	ranking_manager.call(
		"adicionar_resultado",
		nome_final,
		ranking_pontos_pendentes,
		ranking_cenario_pendente,
		ranking_precisao_pendente
	)

	ranking_ja_salvo = true
	ranking_nome_ativo = false
	ranking_nome_tempo = 0.0
	tempo_fim_menu = tempo_auto_retorno_menu_seg

	if ranking_nome_layer != null:
		ranking_nome_layer.visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	if fim_stats_label != null:
		var texto_base := fim_stats_label.text
		texto_base = texto_base.replace("\n\n🏆 NOVO RECORDE! ESCOLHA SEU NOME.", "")
		texto_base = texto_base.replace("\n\nPONTUAÇÃO FORA DO TOP 20.", "")

		fim_stats_label.text = texto_base + "\n\nSALVO COMO: %s\nPRECISÃO FINAL: %d%%" % [
			nome_final,
			ranking_precisao_pendente
		]

	if fim_countdown_label != null:
		fim_countdown_label.text = "VOLTANDO AO MENU EM %02d" % int(ceil(tempo_fim_menu))

	if fim_insert_coin_label != null:
		fim_insert_coin_label.text = "APERTE START PARA JOGAR NOVAMENTE"

	_posicionar_modal_final()
	_animar_texto_record_salvo_temporario(nome_final)


func _animar_texto_record_salvo_temporario(nome_salvo: String) -> void:
	if fim_title_label == null:
		return

	fim_title_label.text = "RECORDE SALVO!"
	Leve.font_size(fim_title_label, "font_size", 50)
	Leve.color(fim_title_label, "font_color", Color(0.82, 1.0, 0.86, 1.0))
	Leve.color(fim_title_label, "font_outline_color", Color.BLACK)
	Leve.constant(fim_title_label, "outline_size", 9)

	fim_title_label.modulate = Color(1, 1, 1, 0.0)
	fim_title_label.scale = Vector2(0.88, 0.88)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(fim_title_label, "modulate:a", 1.0, 0.18)
	tw.tween_property(fim_title_label, "scale", Vector2(1.05, 1.05), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(fim_title_label, "scale", Vector2.ONE, 0.16).set_delay(0.20)

	await get_tree().create_timer(1.35).timeout

	if fim_title_label == null or not is_instance_valid(fim_title_label):
		return

	var tw_out := create_tween()
	tw_out.tween_property(fim_title_label, "modulate:a", 0.0, 0.18)
	await tw_out.finished

	if fim_title_label == null or not is_instance_valid(fim_title_label):
		return

	fim_title_label.text = "RESULTADO FINAL"
	Leve.font_size(fim_title_label, "font_size", 50)
	Leve.color(fim_title_label, "font_color", COR_NEON_BAR_CLARO)
	fim_title_label.modulate = Color(1, 1, 1, 0.0)
	fim_title_label.scale = Vector2(0.96, 0.96)

	var tw_in := create_tween()
	tw_in.set_parallel(true)
	tw_in.tween_property(fim_title_label, "modulate:a", 1.0, 0.20)
	tw_in.tween_property(fim_title_label, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


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



func _desenhar_marcas_erro() -> void:
	# Furo de bala na madeira: uma forma pronta do Pincel por marca (antes
	# eram 8 desenhos por furo, e ficam até 80 furos na tela).
	for marca in marcas_erro:
		var pos: Vector2 = Vector2(marca.get("pos", Vector2.ZERO))
		var poeira: float = float(marca.get("poeira", 20.0))
		var dx: float = float(marca.get("desvio_x", 0.0))
		var dy: float = float(marca.get("desvio_y", 0.0))
		var giro: float = (dx * 1.7 + dy * 2.3) * PI
		Pincel.forma(_camada_marcas, Pincel.FURO, pos + Vector2(dx, dy), poeira, Color.WHITE, giro)


func _desenhar_fx_madeira() -> void:
	for fx in fx_madeira:
		var pos: Vector2 = fx["pos"]
		var vel: Vector2 = fx["vel"]
		var idade: float = fx["idade"]
		var vida: float = fx["vida"]
		var tam: float = fx["tam"]

		var t: float = clamp(idade / vida, 0.0, 1.0)
		var alpha: float = 1.0 - t

		var dir: Vector2 = vel.normalized()
		if dir.length() < 0.01:
			dir = Vector2.RIGHT

		# Farpa de madeira voando
		Pincel.lasca(self, pos - dir * tam * 0.5, Vector2(tam * 0.55, 1.4 + (1.0 - t) * 0.8), dir.angle(), Color(0.74, 0.46, 0.18, 0.90 * alpha))


func _desenhar_fx_vidro() -> void:
	for fx in fx_vidro:
		var tipo: String = _texto(fx.get("tipo", "grande"), "grande")
		var pos: Vector2 = _num_vector2(fx.get("pos", Vector2.ZERO), Vector2.ZERO)
		var rot: float = _num_float(fx.get("rot", 0.0), 0.0)
		var idade: float = _num_float(fx.get("idade", 0.0), 0.0)
		var vida: float = max(_num_float(fx.get("vida", 1.0), 1.0), 0.01)
		var tam: Vector2 = _num_vector2(fx.get("tam", Vector2(8.0, 4.0)), Vector2(8.0, 4.0))

		var t: float = clamp(idade / vida, 0.0, 1.0)
		var alpha: float = 1.0 - t

		var cor_base: Color = Color(0.90, 1.0, 0.95, 1.0)
		if typeof(fx.get("cor", null)) == TYPE_COLOR:
			cor_base = fx.get("cor")

		if tipo == "gota":
			Pincel.circulo(self, pos, max(tam.x, tam.y), Color(cor_base.r, cor_base.g, cor_base.b, 0.72 * alpha))
			continue

		var a: float = 0.55 if tipo == "pequeno" else 0.75
		Pincel.lasca(self, pos, tam, rot, Color(cor_base.r, cor_base.g, cor_base.b, a * alpha))


func _registrar_fx_impacto(pos: Vector2) -> void:
	fx_impacto.append({
		"pos": pos,
		"idade": 0.0,
		"vida": 0.10,
		"raio": 10.0
	})


func _atualizar_fx_impacto(delta: float) -> void:
	for i in range(fx_impacto.size() - 1, -1, -1):
		var fx: Dictionary = fx_impacto[i]

		var idade: float = _num_float(fx.get("idade", 0.0), 0.0) + delta
		var vida: float = _num_float(fx.get("vida", 0.10), 0.10)

		fx["idade"] = idade

		if idade >= vida:
			fx_impacto.remove_at(i)
		else:
			fx_impacto[i] = fx


func _desenhar_fx_impacto() -> void:
	for fx in fx_impacto:
		var pos: Vector2 = fx["pos"]
		var idade: float = fx["idade"]
		var vida: float = fx["vida"]
		var raio_base: float = fx["raio"]

		var t: float = clamp(idade / vida, 0.0, 1.0)
		var alpha: float = 1.0 - t

		var raio_1: float = lerp(raio_base, raio_base + 10.0, t)
		var raio_2: float = lerp(raio_base * 0.45, raio_base + 4.0, t)

		# clarão do tiro + onda
		Pincel.brilho(self, pos, raio_2 * 2.2, Color(1.0, 0.86, 0.55, 0.55 * alpha))
		Pincel.anel(self, pos, raio_1, 1.4, Color(0.30, 0.18, 0.08, 0.16 * alpha))


func _disparar_tremor(forca: float = 10.0, duracao: float = 0.18) -> void:
	pass



func _atualizar_tremor(delta: float) -> void:
	tremor_tempo = 0.0
	tremor_forca = 0.0



func _encerrar_jogo() -> void:
	if not jogo_ativo:
		return

	jogo_ativo = false
	partida_iniciada = false
	intro_comeco_ativa = false
	spawn_continuo_ativo = false
	loop_troca_slots_ativo = false

	tempo_restante = 0.0
	tempo_fim_menu = tempo_auto_retorno_menu_seg

	_limpar_garrafas_antigas()

	if garrafas_root != null:
		garrafas_root.visible = false

	_parar_musica_fim()
	_iniciar_musica_bar_em_loop()

	var precisao: int = 0
	if total_tiros > 0:
		precisao = int(round((float(total_acertos) / float(total_tiros)) * 100.0))

	var aproveitamento: String = "TREINE MAIS"
	if precisao >= 80:
		aproveitamento = "EXCELENTE"
	elif precisao >= 60:
		aproveitamento = "MUITO BOM"
	elif precisao >= 40:
		aproveitamento = "BOM"

	var entrou_ranking: bool = bool(ranking_manager.call(
		"deve_entrar_no_ranking",
		pontuacao_total,
		precisao
	))

	var texto_ranking: String = "\n\nPONTUAÇÃO FORA DO TOP 20."
	if entrou_ranking:
		texto_ranking = "\n\n🏆 NOVO RECORDE! ESCOLHA SEU NOME."

	if fim_title_label != null:
		fim_title_label.text = "FIM DE JOGO"

	if fim_score_label != null:
		fim_score_label.text = "PONTUAÇÃO\n%d" % pontuacao_total

	if fim_stats_label != null:
		fim_stats_label.text = "TIROS: %d     ACERTOS: %d     ERROS: %d\nPRECISÃO: %d%%\nMELHOR SEQUÊNCIA: x%d\n\nDESEMPENHO: %s%s" % [
			total_tiros,
			total_acertos,
			total_erros,
			precisao,
			melhor_sequencia,
			aproveitamento,
			texto_ranking
		]

	if fim_insert_coin_label != null:
		if entrou_ranking:
			fim_insert_coin_label.text = "ATIRE NAS LETRAS PARA SALVAR O RECORDE"
		else:
			fim_insert_coin_label.text = "APERTE START PARA JOGAR NOVAMENTE"

	if fim_countdown_label != null:
		if entrou_ranking:
			fim_countdown_label.text = "DIGITE SEU NOME PARA SALVAR O RECORDE"
		else:
			fim_countdown_label.text = "VOLTANDO AO MENU EM %02d" % int(ceil(tempo_fim_menu))

	_posicionar_modal_final()

	if fim_panel != null:
		fim_panel.visible = true
		fim_panel.modulate = Color(1, 1, 1, 0)
		fim_panel.scale = Vector2(0.94, 0.94)

	if fim_title_label != null:
		fim_title_label.visible = true
		fim_title_label.modulate = Color(1, 1, 1, 0)

	if fim_score_label != null:
		fim_score_label.visible = true
		fim_score_label.modulate = Color(1, 1, 1, 0)

	if fim_stats_label != null:
		fim_stats_label.visible = true
		fim_stats_label.modulate = Color(1, 1, 1, 0)

	if fim_insert_coin_label != null:
		fim_insert_coin_label.visible = true
		fim_insert_coin_label.modulate = Color(1, 1, 1, 0)

	if fim_countdown_label != null:
		fim_countdown_label.visible = true
		fim_countdown_label.modulate = Color(1, 1, 1, 0)

	var tw := create_tween()
	tw.set_parallel(true)

	if fim_panel != null:
		tw.tween_property(fim_panel, "modulate:a", 1.0, 0.28)
		tw.tween_property(fim_panel, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if fim_title_label != null:
		tw.tween_property(fim_title_label, "modulate:a", 1.0, 0.22)

	if fim_score_label != null:
		tw.tween_property(fim_score_label, "modulate:a", 1.0, 0.24).set_delay(0.06)

	if fim_stats_label != null:
		tw.tween_property(fim_stats_label, "modulate:a", 1.0, 0.26).set_delay(0.10)

	if fim_insert_coin_label != null:
		tw.tween_property(fim_insert_coin_label, "modulate:a", 1.0, 0.28).set_delay(0.14)

	if fim_countdown_label != null:
		tw.tween_property(fim_countdown_label, "modulate:a", 1.0, 0.28).set_delay(0.18)

	if entrou_ranking:
		tempo_fim_menu = 9999.0
		call_deferred("_abrir_modal_nome_ranking_bar", pontuacao_total, precisao)

	_marcar_hud_sujo()
	queue_redraw()



func _posicionar_modal_final() -> void:
	var tela: Vector2 = get_viewport_rect().size

	var painel_w: float = min(1080.0, tela.x - 40.0)
	var painel_h: float = min(940.0, tela.y - 40.0)

	var x: float = (tela.x - painel_w) * 0.5
	var y: float = (tela.y - painel_h) * 0.5

	if fim_panel != null:
		fim_panel.position = Vector2(x, y).round()
		fim_panel.size = Vector2(painel_w, painel_h)

		# Atualiza apenas cor — raio 56 já está no StyleBoxFlat de _estilo_modal_bar
		var estilo_fim := fim_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if estilo_fim != null:
			estilo_fim.bg_color     = Color(0.010, 0.038, 0.014, 0.98)
			estilo_fim.border_color = COR_NEON_BAR
			estilo_fim.shadow_color = Color(COR_NEON_BAR.r, COR_NEON_BAR.g, COR_NEON_BAR.b, 0.70)

		var topo := fim_panel.get_node_or_null("FimTopo") as Panel
		if topo != null:
			topo.position = Vector2.ZERO
			topo.size = Vector2(painel_w, 128.0)
			var topo_estilo := topo.get_theme_stylebox("panel") as StyleBoxFlat
			if topo_estilo != null:
				topo_estilo.bg_color = Color(0.01, 0.04, 0.015, 1.0)

		var linha := fim_panel.get_node_or_null("FimLinha") as ColorRect
		if linha != null:
			linha.color    = COR_NEON_BAR
			linha.position = Vector2(0.0, 128.0)
			linha.size     = Vector2(painel_w, 4.0)

	if fim_title_label != null:
		fim_title_label.position = Vector2(x + 30.0, y + 28.0)
		fim_title_label.size = Vector2(painel_w - 60.0, 74.0)
		fim_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fim_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		Leve.font_size(fim_title_label, "font_size", 54)
		Leve.color(fim_title_label, "font_color", COR_NEON_BAR_CLARO)
		Leve.color(fim_title_label, "font_outline_color", Color.BLACK)
		Leve.constant(fim_title_label, "outline_size", 8)

	if fim_score_label != null:
		fim_score_label.position = Vector2(x + 80.0, y + 152.0)
		fim_score_label.size = Vector2(painel_w - 160.0, 150.0)
		fim_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fim_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		Leve.font_size(fim_score_label, "font_size", 42)
		Leve.color(fim_score_label, "font_color", Color(0.82, 1.0, 0.86, 1.0))
		Leve.color(fim_score_label, "font_outline_color", Color.BLACK)
		Leve.constant(fim_score_label, "outline_size", 6)

	if fim_stats_label != null:
		var linhas: int = fim_stats_label.text.count("\n") + 1
		var font_stats: int = 26

		if linhas >= 8:
			font_stats = 22
		elif linhas >= 6:
			font_stats = 24

		fim_stats_label.position = Vector2(x + 80.0, y + 318.0)
		fim_stats_label.size = Vector2(painel_w - 160.0, painel_h - 545.0)
		fim_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fim_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fim_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		Leve.font_size(fim_stats_label, "font_size", font_stats)
		Leve.color(fim_stats_label, "font_color", Color(0.88, 1.0, 0.90, 1.0))
		Leve.color(fim_stats_label, "font_outline_color", Color.BLACK)
		Leve.constant(fim_stats_label, "outline_size", 5)

	if fim_countdown_label != null:
		fim_countdown_label.position = Vector2(x + 60.0, y + painel_h - 150.0)
		fim_countdown_label.size = Vector2(painel_w - 120.0, 44.0)
		fim_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fim_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fim_countdown_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		Leve.font_size(fim_countdown_label, "font_size", 24)
		Leve.color(fim_countdown_label, "font_color", COR_NEON_BAR_CLARO)
		Leve.color(fim_countdown_label, "font_outline_color", Color.BLACK)
		Leve.constant(fim_countdown_label, "outline_size", 5)

	if fim_insert_coin_label != null:
		fim_insert_coin_label.position = Vector2(x + 60.0, y + painel_h - 98.0)
		fim_insert_coin_label.size = Vector2(painel_w - 120.0, 54.0)
		fim_insert_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fim_insert_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fim_insert_coin_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		Leve.font_size(fim_insert_coin_label, "font_size", 24)
		Leve.color(fim_insert_coin_label, "font_color", COR_NEON_BAR)
		Leve.color(fim_insert_coin_label, "font_outline_color", Color.BLACK)
		Leve.constant(fim_insert_coin_label, "outline_size", 5)



func _reiniciar_jogo() -> void:
	_parar_musica_fim()
	_iniciar_musica_bar_em_loop()

	pontuacao_total = 0
	total_tiros = 0
	total_acertos = 0
	total_erros = 0
	tempo_restante = tempo_partida
	tempo_turno = 0.0
	jogo_ativo = true
	trocando_turno = false
	partida_iniciada = false
	intro_cenario_em_execucao = false
	tremor_tempo = 0.0
	tremor_forca = 0.0

	balas_no_cartucho = capacidade_cartucho
	recarregando = false
	reload_tempo_restante = 0.0
	nivel_dificuldade_atual = 0
	aviso_recarga_t = 0.0

	marcas_erro.clear()
	_redesenhar_marcas()
	fx_madeira.clear()
	fx_vidro.clear()
	fx_impacto.clear()

	fim_panel.visible = false
	fim_title_label.visible = false
	fim_score_label.visible = false
	fim_stats_label.visible = false
	fim_insert_coin_label.visible = false
	fim_countdown_label.visible = false

	if fim_cutscene_panel != null:
		fim_cutscene_panel.visible = false
	if fim_cutscene_titulo != null:
		fim_cutscene_titulo.visible = false
	if fim_cutscene_loading != null:
		fim_cutscene_loading.visible = false
	if fim_cutscene_barra_bg != null:
		fim_cutscene_barra_bg.visible = false
	if fim_cutscene_barra_fill != null:
		fim_cutscene_barra_fill.visible = false

	fim_cutscene_ativa = false
	tempo_fim_menu = tempo_auto_retorno_menu_seg
	fim_pulso_t = 0.0

	hud_animando_entrada = false
	hud_entrada_t = 0.0
	hud_top_offset_y = -220.0

	intro_comeco_ativa = false
	intro_comeco_t = 0.0
	intro_contagem_valor = 3

	if comeco_root != null:
		comeco_root.visible = false

	if comeco_titulo != null:
		comeco_titulo.visible = false
		comeco_titulo.modulate = Color(1, 1, 1, 1)
		comeco_titulo.scale = Vector2.ONE

	if comeco_subtitulo != null:
		comeco_subtitulo.visible = false
		comeco_subtitulo.modulate = Color(1, 1, 1, 1)
		comeco_subtitulo.scale = Vector2.ONE

	if fundo != null:
		fundo.position = fundo_pos_base
	if fundo_preenchimento != null:
		fundo_preenchimento.position = fundo_pos_base
	if garrafas_root != null:
		garrafas_root.position = garrafas_pos_base
		garrafas_root.visible = false

	hud_sujo = true
	_set_status_neutro("")
	_limpar_garrafas_antigas()
	_atualizar_hud()

	if aviso_root != null:
		aviso_root.visible = true
		if aviso_panel != null:
			aviso_panel.modulate = Color(1, 1, 1, 1)
			aviso_panel.scale = Vector2.ONE
		if aviso_titulo != null:
			aviso_titulo.modulate = Color(1, 1, 1, 1)
		if aviso_subtitulo != null:
			aviso_subtitulo.modulate = Color(1, 1, 1, 1)

	queue_redraw()

func _pontos_da_prateleira(y_base: float) -> int:
	if abs(y_base - Y_PRATELEIRA_100) <= 12.0:
		return 100
	if abs(y_base - Y_PRATELEIRA_80) <= 12.0:
		return 80
	if abs(y_base - Y_PRATELEIRA_50) <= 12.0:
		return 50
	return 20



func _calcular_nivel_impostora() -> int:
	return int(floor(float(max(pontuacao_total, 0)) / 1500.0))




func _retornar_para_menu() -> void:
	_parar_musica_bar()
	_parar_musica_fim()

	if cena_main_menu == "":
		return

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	TransicaoGlobal.trocar_cena(cena_main_menu)


func _configurar_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUDCanvas"
	hud_layer.layer = 20
	add_child(hud_layer)

	hud_root = Control.new()
	hud_root.name = "HUDRoot"
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.position = Vector2.ZERO
	hud_root.scale = Vector2.ONE
	hud_root.rotation = 0.0
	hud_layer.add_child(hud_root)

	top_bar = Panel.new()
	Leve.stylebox(top_bar, "panel", _estilo_card_bar())
	top_bar.z_index = 40
	hud_root.add_child(top_bar)

	top_bar_sombra = ColorRect.new()
	top_bar_sombra.color = Color(0.0, 0.0, 0.0, 0.24)
	top_bar_sombra.z_index = 41
	hud_root.add_child(top_bar_sombra)

	top_bar_glow = ColorRect.new()
	top_bar_glow.color = Color(0.18, 0.88, 1.0, 0.12)
	top_bar_glow.z_index = 42
	hud_root.add_child(top_bar_glow)

	top_bar_linha = ColorRect.new()
	top_bar_linha.color = Color(0.20, 0.92, 1.0, 0.82)
	top_bar_linha.z_index = 43
	hud_root.add_child(top_bar_linha)

	# Painel de pontuação — sempre Panel arredondado neon verde (igual timer/municao)
	score_panel = Panel.new()
	Leve.stylebox(score_panel, "panel", _estilo_card_bar())
	score_panel.z_index = 55
	score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(score_panel)

	timer_panel = Panel.new()
	Leve.stylebox(timer_panel, "panel", _estilo_card_bar())
	timer_panel.z_index = 60
	hud_root.add_child(timer_panel)

	municao_panel = Panel.new()
	Leve.stylebox(municao_panel, "panel", _estilo_card_bar())
	municao_panel.z_index = 60
	hud_root.add_child(municao_panel)

	status_panel = Panel.new()
	Leve.stylebox(status_panel, "panel", _estilo_card_bar())
	status_panel.visible = false
	status_panel.z_index = 60
	hud_root.add_child(status_panel)
	
	chat_rodape_panel = Panel.new()
	chat_rodape_panel.name = "ChatRodapePanel"
	chat_rodape_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_rodape_panel.visible = false
	Leve.stylebox(chat_rodape_panel, "panel", _estilo_card_bar())
	hud_root.add_child(chat_rodape_panel)
	
	stats_hud_panel = Panel.new()
	Leve.stylebox(stats_hud_panel, "panel", _estilo_card_bar())
	stats_hud_panel.z_index = 55
	stats_hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(stats_hud_panel)

	fim_panel = Panel.new()
	Leve.stylebox(fim_panel, "panel", _estilo_modal_bar())
	fim_panel.visible = false
	fim_panel.z_index = 110
	hud_root.add_child(fim_panel)

	# Cabeçalho com cantos arredondados compatíveis com o painel
	var fim_topo_panel := Panel.new()
	fim_topo_panel.name = "FimTopo"
	var fim_topo_estilo := StyleBoxFlat.new()
	fim_topo_estilo.bg_color = Color(0.01, 0.04, 0.015, 1.0)
	fim_topo_estilo.corner_radius_top_left     = 56
	fim_topo_estilo.corner_radius_top_right    = 56
	fim_topo_estilo.corner_radius_bottom_left  = 0
	fim_topo_estilo.corner_radius_bottom_right = 0
	Leve.stylebox(fim_topo_panel, "panel", fim_topo_estilo)
	fim_panel.add_child(fim_topo_panel)

	# Linha neon separadora
	var fim_linha_neon := ColorRect.new()
	fim_linha_neon.name = "FimLinha"
	fim_linha_neon.color = COR_NEON_BAR
	fim_panel.add_child(fim_linha_neon)

	var fim_glow := ColorRect.new()
	fim_glow.name = "FimGlow"
	fim_glow.color = Color(0.18, 0.88, 1.0, 0.08)
	fim_panel.add_child(fim_glow)

	var fim_borda_topo := ColorRect.new()
	fim_borda_topo.name = "FimBordaTopo"
	fim_borda_topo.color = Color(0.18, 0.88, 1.0, 1.0)
	fim_panel.add_child(fim_borda_topo)

	var fim_borda_base := ColorRect.new()
	fim_borda_base.name = "FimBordaBase"
	fim_borda_base.color = Color(1.0, 0.30, 0.24, 0.84)
	fim_panel.add_child(fim_borda_base)

	var fim_info_box := ColorRect.new()
	fim_info_box.name = "FimInfoBox"
	fim_info_box.color = Color(0.08, 0.10, 0.16, 0.96)
	fim_panel.add_child(fim_info_box)

	var fim_info_faixa := ColorRect.new()
	fim_info_faixa.name = "FimInfoFaixa"
	fim_info_faixa.color = Color(1.0, 0.86, 0.24, 0.96)
	fim_info_box.add_child(fim_info_faixa)

	score_title_label = Label.new()
	score_title_label.text = "PONTUAÇÃO"
	score_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(score_title_label, "font_size", 22)
	Leve.color(score_title_label, "font_color", Color(0.604, 0.997, 0.966, 1.0))
	Leve.color(score_title_label, "font_outline_color", Color.BLACK)
	Leve.constant(score_title_label, "outline_size", 4)
	score_title_label.z_index = 90
	hud_root.add_child(score_title_label)

	score_label = Label.new()
	score_label.text = "0"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(score_label, "font_size", 58)
	Leve.color(score_label, "font_color", Color(0.631, 0.989, 0.968, 1.0))
	Leve.color(score_label, "font_outline_color", Color.BLACK)
	Leve.constant(score_label, "outline_size", 7)
	score_label.z_index = 90
	hud_root.add_child(score_label)

	timer_title_label = Label.new()
	timer_title_label.text = "TEMPO"
	timer_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(timer_title_label, "font_size", 20)
	Leve.color(timer_title_label, "font_color", Color(0.90, 0.97, 1.0, 1.0))
	Leve.color(timer_title_label, "font_outline_color", Color.BLACK)
	Leve.constant(timer_title_label, "outline_size", 4)
	timer_title_label.z_index = 90
	hud_root.add_child(timer_title_label)

	timer_label = Label.new()
	timer_label.text = "02:00"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(timer_label, "font_size", 42)
	Leve.color(timer_label, "font_color", COR_TIMER_NORMAL)
	Leve.color(timer_label, "font_outline_color", Color.BLACK)
	Leve.constant(timer_label, "outline_size", 7)
	timer_label.z_index = 90
	hud_root.add_child(timer_label)

	municao_title_label = Label.new()
	municao_title_label.text = "MUNIÇÃO"
	municao_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	municao_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(municao_title_label, "font_size", 21)
	Leve.color(municao_title_label, "font_color", Color(0.92, 0.97, 1.0, 1.0))
	Leve.color(municao_title_label, "font_outline_color", Color.BLACK)
	Leve.constant(municao_title_label, "outline_size", 4)
	municao_title_label.z_index = 90
	hud_root.add_child(municao_title_label)

	municao_label = Label.new()
	municao_label.text = "CARREGADA"
	municao_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	municao_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(municao_label, "font_size", 18)
	Leve.color(municao_label, "font_color", Color(0.84, 1.0, 0.92, 1.0))
	Leve.color(municao_label, "font_outline_color", Color.BLACK)
	Leve.constant(municao_label, "outline_size", 4)
	municao_label.z_index = 90
	hud_root.add_child(municao_label)

	recarga_label = Label.new()
	recarga_label.text = "ENGATILHE PARA RECARREGAR"
	recarga_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recarga_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(recarga_label, "font_size", 16)
	Leve.color(recarga_label, "font_color", Color(0.76, 0.88, 1.0, 0.95))
	Leve.color(recarga_label, "font_outline_color", Color.BLACK)
	Leve.constant(recarga_label, "outline_size", 4)
	recarga_label.z_index = 90
	hud_root.add_child(recarga_label)

	tiros_title_label = Label.new()
	tiros_title_label.text = "TIROS"
	tiros_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tiros_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(tiros_title_label, "font_size", 18)
	Leve.color(tiros_title_label, "font_color", Color(1.0, 0.90, 0.32, 1.0))
	Leve.color(tiros_title_label, "font_outline_color", Color.BLACK)
	Leve.constant(tiros_title_label, "outline_size", 4)
	tiros_title_label.z_index = 90
	hud_root.add_child(tiros_title_label)

	tiros_label = Label.new()
	tiros_label.text = "0"
	tiros_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tiros_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(tiros_label, "font_size", 34)
	Leve.color(tiros_label, "font_color", Color.WHITE)
	Leve.color(tiros_label, "font_outline_color", Color.BLACK)
	Leve.constant(tiros_label, "outline_size", 6)
	tiros_label.z_index = 90
	hud_root.add_child(tiros_label)

	acertos_title_label = Label.new()
	acertos_title_label.text = "ACERTOS"
	acertos_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	acertos_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(acertos_title_label, "font_size", 18)
	Leve.color(acertos_title_label, "font_color", Color(0.32, 0.92, 1.0, 1.0))
	Leve.color(acertos_title_label, "font_outline_color", Color.BLACK)
	Leve.constant(acertos_title_label, "outline_size", 4)
	acertos_title_label.z_index = 90
	hud_root.add_child(acertos_title_label)

	acertos_label = Label.new()
	acertos_label.text = "0"
	acertos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	acertos_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(acertos_label, "font_size", 34)
	Leve.color(acertos_label, "font_color", Color.WHITE)
	Leve.color(acertos_label, "font_outline_color", Color.BLACK)
	Leve.constant(acertos_label, "outline_size", 6)
	acertos_label.z_index = 90
	hud_root.add_child(acertos_label)

	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.color(status_label, "font_color", Color.WHITE)
	Leve.color(status_label, "font_outline_color", Color.BLACK)
	Leve.font_size(status_label, "font_size", 42)
	Leve.constant(status_label, "outline_size", 6)
	status_label.visible = false
	status_label.z_index = 95
	hud_root.add_child(status_label)

	for i in range(3):
		var lbl: Label = Label.new()
		lbl.name = "StatusChat_%d" % i
		lbl.text = ""
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		Leve.font_size(lbl, "font_size", 34 - (i * 3))
		Leve.color(lbl, "font_color", Color.WHITE)
		Leve.color(lbl, "font_outline_color", Color.BLACK)
		Leve.constant(lbl, "outline_size", 6)
		lbl.visible = false
		lbl.z_index = 95
		hud_root.add_child(lbl)
		status_chat_labels.append(lbl)

	fim_title_label = Label.new()
	fim_title_label.visible = false
	fim_title_label.text = "FIM DE JOGO"
	fim_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fim_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(fim_title_label, "font_size", 64)
	Leve.color(fim_title_label, "font_color", Color(1.0, 0.78, 0.20, 1.0))
	Leve.color(fim_title_label, "font_outline_color", Color.BLACK)
	Leve.constant(fim_title_label, "outline_size", 8)
	fim_title_label.z_index = 120
	hud_root.add_child(fim_title_label)

	fim_score_label = Label.new()
	fim_score_label.visible = false
	fim_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fim_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(fim_score_label, "font_size", 52)
	Leve.color(fim_score_label, "font_color", Color.WHITE)
	Leve.color(fim_score_label, "font_outline_color", Color.BLACK)
	Leve.constant(fim_score_label, "outline_size", 8)
	fim_score_label.z_index = 120
	hud_root.add_child(fim_score_label)

	fim_stats_label = Label.new()
	fim_stats_label.visible = false
	fim_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fim_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	fim_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Leve.font_size(fim_stats_label, "font_size", 32)
	Leve.color(fim_stats_label, "font_color", Color(0.90, 0.96, 1.0, 1.0))
	Leve.color(fim_stats_label, "font_outline_color", Color.BLACK)
	Leve.constant(fim_stats_label, "outline_size", 6)
	fim_stats_label.z_index = 120
	hud_root.add_child(fim_stats_label)

	fim_insert_coin_label = Label.new()
	fim_insert_coin_label.visible = false
	fim_insert_coin_label.text = "INSERT COIN"
	fim_insert_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fim_insert_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(fim_insert_coin_label, "font_size", 33)
	Leve.color(fim_insert_coin_label, "font_color", Color(1.0, 0.92, 0.22, 1.0))
	Leve.color(fim_insert_coin_label, "font_outline_color", Color.BLACK)
	Leve.constant(fim_insert_coin_label, "outline_size", 8)
	fim_insert_coin_label.z_index = 120
	hud_root.add_child(fim_insert_coin_label)

	fim_countdown_label = Label.new()
	fim_countdown_label.visible = false
	fim_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fim_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(fim_countdown_label, "font_size", 22)
	Leve.color(fim_countdown_label, "font_color", Color(0.86, 0.94, 1.0, 1.0))
	Leve.color(fim_countdown_label, "font_outline_color", Color.BLACK)
	Leve.constant(fim_countdown_label, "outline_size", 5)
	fim_countdown_label.z_index = 120
	hud_root.add_child(fim_countdown_label)

	fim_cutscene_panel = ColorRect.new()
	fim_cutscene_panel.color = Color(0.02, 0.04, 0.08, 0.96)
	fim_cutscene_panel.visible = false
	fim_cutscene_panel.z_index = 130
	hud_root.add_child(fim_cutscene_panel)

	fim_cutscene_titulo = Label.new()
	fim_cutscene_titulo.visible = false
	fim_cutscene_titulo.text = "FIM DE JOGO"
	fim_cutscene_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fim_cutscene_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(fim_cutscene_titulo, "font_size", 64)
	Leve.color(fim_cutscene_titulo, "font_color", Color(1.0, 0.82, 0.24, 1.0))
	Leve.color(fim_cutscene_titulo, "font_outline_color", Color.BLACK)
	Leve.constant(fim_cutscene_titulo, "outline_size", 8)
	fim_cutscene_titulo.z_index = 140
	hud_root.add_child(fim_cutscene_titulo)

	fim_cutscene_loading = Label.new()
	fim_cutscene_loading.visible = false
	fim_cutscene_loading.text = "CALCULANDO RESULTADOS..."
	fim_cutscene_loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fim_cutscene_loading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(fim_cutscene_loading, "font_size", 26)
	Leve.color(fim_cutscene_loading, "font_color", Color(0.84, 0.94, 1.0, 1.0))
	Leve.color(fim_cutscene_loading, "font_outline_color", Color.BLACK)
	Leve.constant(fim_cutscene_loading, "outline_size", 5)
	fim_cutscene_loading.z_index = 140
	hud_root.add_child(fim_cutscene_loading)

	fim_cutscene_barra_bg = ColorRect.new()
	fim_cutscene_barra_bg.color = Color(0.10, 0.16, 0.22, 0.95)
	fim_cutscene_barra_bg.visible = false
	fim_cutscene_barra_bg.z_index = 140
	hud_root.add_child(fim_cutscene_barra_bg)

	fim_cutscene_barra_fill = ColorRect.new()
	fim_cutscene_barra_fill.color = Color(0.22, 0.92, 1.0, 1.0)
	fim_cutscene_barra_fill.visible = false
	fim_cutscene_barra_fill.z_index = 141
	hud_root.add_child(fim_cutscene_barra_fill)

	combo_hud_label = Label.new()
	combo_hud_label.visible = false
	combo_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	combo_hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(combo_hud_label, "font_size", 60)
	Leve.color(combo_hud_label, "font_color", Color(1.0, 0.92, 0.30, 1.0))
	Leve.color(combo_hud_label, "font_outline_color", Color.BLACK)
	Leve.constant(combo_hud_label, "outline_size", 6)
	combo_hud_label.z_index = 95
	hud_root.add_child(combo_hud_label)
	
	_fonte_titulo(score_title_label, 22, COR_NEON_BAR_CLARO)
	_fonte_valor(score_label, 58, Color(0.82, 1.0, 0.86, 1.0))

	_fonte_titulo(timer_title_label, 20, COR_NEON_BAR_CLARO)
	_fonte_valor(timer_label, 42, Color.WHITE)

	_fonte_titulo(municao_title_label, 21, COR_NEON_BAR_CLARO)
	_fonte_valor(municao_label, 18, Color.WHITE)
	_fonte_valor(recarga_label, 16, Color(0.78, 1.0, 0.82, 1.0))

	_fonte_titulo(tiros_title_label, 17, COR_NEON_BAR_CLARO)
	_fonte_valor(tiros_label, 26, Color.WHITE)

	_fonte_titulo(acertos_title_label, 17, COR_NEON_BAR_CLARO)
	_fonte_valor(acertos_label, 26, Color.WHITE)

	_fonte_valor(status_label, 42, Color.WHITE)
	_fonte_titulo(combo_hud_label, 60, Color(1.0, 0.95, 0.34, 1.0))

	_fonte_titulo(fim_title_label, 64, COR_NEON_BAR_CLARO)
	_fonte_valor(fim_score_label, 52, Color.WHITE)
	_fonte_valor(fim_stats_label, 32, Color.WHITE)
	_fonte_valor(fim_insert_coin_label, 33, Color(1.0, 0.95, 0.35, 1.0))
	_fonte_valor(fim_countdown_label, 22, Color(0.82, 1.0, 0.86, 1.0))

	_desligar_linhas_hud_tremendo()
	_criar_blocos_municao()
	_ajustar_layout()




func _obter_tipo_alvo_por_pontos(pontos: int) -> String:
	if pontos <= 0:
		return "garrafa_falsa"
	return "garrafa"


func _configurar_alvo_overlay() -> void:
	alvo_layer = CanvasLayer.new()
	alvo_layer.name = "AlvoLayer"
	alvo_layer.layer = 220
	add_child(alvo_layer)

	alvo_overlay = Control.new()
	alvo_overlay.name = "AlvoOverlay"
	alvo_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	alvo_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alvo_overlay.z_index = 999
	alvo_overlay.visible = not _modo_dificil_sem_mira()
	alvo_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	alvo_layer.add_child(alvo_overlay)

	alvo_overlay.draw.connect(_desenhar_alvo_overlay)


func _desenhar_alvo_overlay() -> void:
	if _modo_dificil_sem_mira():
		return

	if alvo_overlay == null:
		return

	var pulso: float = 1.0 + sin(alvo_anim_t * 6.0) * 0.08
	
	
	var r1: float = 20.0 * pulso
	var r2: float = 9.0 * pulso

	var cor_base: Color = Color(1.0, 0.24, 0.20, 0.94)
	var cor_reload: Color = Color(0.22, 0.92, 1.0, 1.0)
	var cor_sem_municao: Color = Color(1.0, 0.18, 0.16, 1.0)

	var cor_ext := cor_base
	var cor_int := Color(1.0, 1.0, 1.0, 0.85)
	var cor_linha := Color(1.0, 1.0, 1.0, 1.0)

	if recarregando:
		var pulso_reload: float = 0.80 + (sin(aviso_recarga_t * 12.0) * 0.5 + 0.5) * 0.20
		cor_ext = Color(cor_reload.r, cor_reload.g, cor_reload.b, pulso_reload)
	elif balas_no_cartucho <= 0:
		var pulso_vazio: float = 0.72 + (sin(aviso_recarga_t * 14.0) * 0.5 + 0.5) * 0.28
		cor_ext = Color(cor_sem_municao.r, cor_sem_municao.g, cor_sem_municao.b, pulso_vazio)
	elif balas_no_cartucho <= alerta_baixa_municao_limite:
		cor_ext = Color(1.0, 0.68, 0.18, 0.98)

	var ov: CanvasItem = alvo_overlay
	Pincel.anel(ov, alvo_pos, r1, 2.6, cor_ext)
	Pincel.anel(ov, alvo_pos, r2, 1.2, cor_int)
	Pincel.circulo(ov, alvo_pos, 2.8, Color(1.0, 1.0, 1.0, 0.96))

	Pincel.linha(ov, alvo_pos + Vector2(-26, 0), alvo_pos + Vector2(-8, 0), cor_linha, 2.0)
	Pincel.linha(ov, alvo_pos + Vector2(8, 0), alvo_pos + Vector2(26, 0), cor_linha, 2.0)
	Pincel.linha(ov, alvo_pos + Vector2(0, -26), alvo_pos + Vector2(0, -8), cor_linha, 2.0)
	Pincel.linha(ov, alvo_pos + Vector2(0, 8), alvo_pos + Vector2(0, 26), cor_linha, 2.0)

	if recarregando:
		var progresso: float = 1.0 - clamp(reload_tempo_restante / max(tempo_recarga_seg, 0.001), 0.0, 1.0)
		var inicio_ang: float = -PI * 0.5
		var fim_ang: float = inicio_ang + (TAU * progresso)
		var mira_reload_raio: float = 34.0
		var mira_reload_espessura: float = 5.0

		Pincel.anel(ov, alvo_pos, mira_reload_raio, mira_reload_espessura, Color(0.10, 0.20, 0.28, 0.42))
		Pincel.arco(ov, alvo_pos, mira_reload_raio, inicio_ang, fim_ang, Color(0.30, 0.94, 1.0, 1.0), mira_reload_espessura)
		Pincel.arco(ov, alvo_pos, mira_reload_raio + 7.0, inicio_ang, fim_ang, Color(0.82, 0.98, 1.0, 0.55), 2.0)

	elif balas_no_cartucho <= 0:
		var pulso_alerta: float = 0.35 + (sin(aviso_recarga_t * 16.0) * 0.5 + 0.5) * 0.35
		Pincel.anel(ov, alvo_pos, 32.0, 4.0, Color(1.0, 0.15, 0.14, pulso_alerta))



func _configurar_aviso_inicio() -> void:
	if aviso_layer != null:
		aviso_layer.queue_free()

	aviso_layer = CanvasLayer.new()
	aviso_layer.layer = 80
	add_child(aviso_layer)

	aviso_root = Control.new()
	aviso_root.name = "AvisoInicio"
	aviso_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	aviso_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso_root.visible = true
	aviso_layer.add_child(aviso_root)

	var sombra := ColorRect.new()
	sombra.name = "SombraInicio"
	sombra.set_anchors_preset(Control.PRESET_FULL_RECT)
	sombra.color = Color(0.0, 0.0, 0.0, 0.82)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso_root.add_child(sombra)

	var glow_img := ColorRect.new()
	glow_img.name = "GlowImagemInicio"
	glow_img.color = Color(0.20, 1.0, 0.32, 0.18)
	glow_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso_root.add_child(glow_img)

	var borda_img := ColorRect.new()
	borda_img.name = "BordaImagemInicio"
	borda_img.color = COR_NEON_BAR
	borda_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso_root.add_child(borda_img)

	var fundo_img := ColorRect.new()
	fundo_img.name = "FundoImagemInicio"
	fundo_img.color = Color(0.012, 0.045, 0.018, 0.96)
	fundo_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso_root.add_child(fundo_img)

	aviso_panel = TextureRect.new()
	aviso_panel.name = "InfoBarImagem"
	aviso_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	aviso_panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	aviso_root.add_child(aviso_panel)

	var caminho_info: String = "res://info_scenes/bar_info.png"
	if ResourceLoader.exists(caminho_info):
		aviso_panel.texture = load(caminho_info)
	else:
		push_warning("Imagem não encontrada: " + caminho_info)

	aviso_footer_label = Label.new()
	aviso_footer_label.text = "ATIRE PARA COMEÇAR"
	aviso_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso_footer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(aviso_footer_label, "font_size", 48)
	Leve.color(aviso_footer_label, "font_color", COR_NEON_BAR_CLARO)
	Leve.color(aviso_footer_label, "font_outline_color", Color(0.0, 0.05, 0.0, 1.0))
	Leve.constant(aviso_footer_label, "outline_size", 10)
	aviso_footer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if fonte_luckiest != null:
		Leve.font(aviso_footer_label, "font", fonte_luckiest)
	elif ResourceLoader.exists(FONTE_LUCKIEST):
		Leve.font(aviso_footer_label, "font", load(FONTE_LUCKIEST))

	aviso_footer_label.self_modulate = Color(0.88, 1.0, 0.90, 1.0)
	aviso_root.add_child(aviso_footer_label)

	call_deferred("_ajustar_layout_aviso_inicio")



func _ajustar_layout_aviso_inicio() -> void:
	if aviso_root == null or aviso_panel == null:
		return

	var tela: Vector2 = get_viewport_rect().size

	aviso_root.position = Vector2.ZERO
	aviso_root.size = tela

	var margem_lateral: float = 34.0
	var margem_topo: float = 42.0
	var espaco_texto: float = 112.0
	var distancia_texto: float = 20.0
	var neon_margem: float = 18.0
	var borda_espessura: float = 6.0

	var largura_max: float = tela.x - (margem_lateral * 2.0)
	var altura_max: float = tela.y - margem_topo - espaco_texto - distancia_texto

	var largura_img: float = largura_max
	var altura_img: float = altura_max

	if aviso_panel.texture != null:
		var tex_size: Vector2 = aviso_panel.texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			var escala: float = min(largura_max / tex_size.x, altura_max / tex_size.y)
			largura_img = tex_size.x * escala
			altura_img = tex_size.y * escala

	aviso_panel.size = Vector2(largura_img, altura_img)
	aviso_panel.position = Vector2(
		(tela.x - largura_img) * 0.5,
		((tela.y - espaco_texto) - altura_img) * 0.5
	).round()

	var glow_img := aviso_root.get_node_or_null("GlowImagemInicio") as ColorRect
	if glow_img != null:
		glow_img.position = aviso_panel.position - Vector2(neon_margem, neon_margem)
		glow_img.size = aviso_panel.size + Vector2(neon_margem * 2.0, neon_margem * 2.0)
		glow_img.color = Color(0.20, 1.0, 0.32, 0.18 + abs(sin(aviso_footer_t * 3.0)) * 0.08)

	var borda_img := aviso_root.get_node_or_null("BordaImagemInicio") as ColorRect
	if borda_img != null:
		borda_img.position = aviso_panel.position - Vector2(borda_espessura, borda_espessura)
		borda_img.size = aviso_panel.size + Vector2(borda_espessura * 2.0, borda_espessura * 2.0)
		borda_img.color = COR_NEON_BAR

	var fundo_img := aviso_root.get_node_or_null("FundoImagemInicio") as ColorRect
	if fundo_img != null:
		fundo_img.position = aviso_panel.position - Vector2(2.0, 2.0)
		fundo_img.size = aviso_panel.size + Vector2(4.0, 4.0)

	if aviso_footer_label != null:
		aviso_footer_label.size = Vector2(tela.x, 82.0)
		aviso_footer_label.position = Vector2(
			0.0,
			aviso_panel.position.y + aviso_panel.size.y + distancia_texto
		).round()



func _configurar_preview_garrafa_aviso() -> void:
	if aviso_preview_root == null:
		return

	for filho in aviso_preview_root.get_children():
		filho.queue_free()

	aviso_preview_garrafa = null

	if cena_garrafa_whisky == null:
		return

	var inst = cena_garrafa_whisky.instantiate()
	
	if not (inst is Area2D):
		return

	aviso_preview_garrafa = inst as Area2D
	aviso_preview_root.add_child(aviso_preview_garrafa)

	aviso_preview_garrafa.position = Vector2(230, 208)
	aviso_preview_garrafa.scale = Vector2.ONE * 0.54
	aviso_preview_garrafa.process_mode = Node.PROCESS_MODE_INHERIT
	aviso_preview_garrafa.visible = true
	aviso_preview_garrafa.show()
	aviso_preview_garrafa.monitoring = false
	aviso_preview_garrafa.monitorable = false
	aviso_preview_garrafa.input_pickable = false
	aviso_preview_garrafa.rotation_degrees = 0.0
	aviso_preview_garrafa.modulate = Color.WHITE
	aviso_preview_garrafa.z_index = 20

	if aviso_preview_garrafa.has_method("configurar_posicao"):
		aviso_preview_garrafa.call("configurar_posicao", Vector2(230, 208))

	var sprite_animado: AnimatedSprite2D = null

	for filho in aviso_preview_garrafa.get_children():
		if filho is AnimatedSprite2D:
			sprite_animado = filho as AnimatedSprite2D
			break

	if sprite_animado == null:
		for filho in aviso_preview_garrafa.get_children():
			for neto in filho.get_children():
				if neto is AnimatedSprite2D:
					sprite_animado = neto as AnimatedSprite2D
					break

	if sprite_animado != null:
		sprite_animado.visible = true
		sprite_animado.show()
		sprite_animado.centered = true
		sprite_animado.position = Vector2.ZERO
		sprite_animado.rotation_degrees = 0.0
		sprite_animado.scale = Vector2.ONE * 0.72
		sprite_animado.modulate = Color.WHITE
		sprite_animado.self_modulate = Color.WHITE
		sprite_animado.z_index = 30

		if sprite_animado.sprite_frames != null:
			if sprite_animado.sprite_frames.has_animation("idle"):
				sprite_animado.play("idle")
			elif sprite_animado.sprite_frames.has_animation("default"):
				sprite_animado.play("default")
			else:
				var nomes := sprite_animado.sprite_frames.get_animation_names()
				if nomes.size() > 0:
					sprite_animado.play(String(nomes[0]))



func _animar_entrada_cenario() -> void:
	if aviso_footer_label != null:
		aviso_footer_label.modulate = Color(1, 1, 1, 1)
	
	intro_cenario_em_execucao = true

	if aviso_panel != null:
		aviso_panel.modulate.a = 0.0
		aviso_panel.scale = Vector2(0.92, 0.92)

	if aviso_titulo != null:
		aviso_titulo.modulate.a = 0.0
		aviso_titulo.position.y += 10.0

	if aviso_subtitulo != null:
		aviso_subtitulo.modulate.a = 0.0
		aviso_subtitulo.position.y += 8.0

	var tw := create_tween()
	tw.set_parallel(true)

	if aviso_panel != null:
		tw.tween_property(aviso_panel, "modulate:a", 1.0, 0.28)
		tw.tween_property(aviso_panel, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if aviso_titulo != null:
		tw.tween_property(aviso_titulo, "modulate:a", 1.0, 0.24)
		tw.tween_property(aviso_titulo, "position:y", aviso_titulo.position.y - 10.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if aviso_subtitulo != null:
		tw.tween_property(aviso_subtitulo, "modulate:a", 1.0, 0.32)
		tw.tween_property(aviso_subtitulo, "position:y", aviso_subtitulo.position.y - 8.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await tw.finished

	if aviso_panel != null:
		aviso_panel.scale = Vector2.ONE
		aviso_panel.modulate = Color(1, 1, 1, 1)

	if aviso_titulo != null:
		aviso_titulo.modulate = Color(1, 1, 1, 1)

	if aviso_subtitulo != null:
		aviso_subtitulo.modulate = Color(1, 1, 1, 1)
		
	if aviso_bloco_info != null:
		aviso_bloco_info.modulate = Color(1, 1, 1, 1)

	if aviso_dica_label != null:
		aviso_dica_label.modulate = Color(1, 1, 1, 1)

	if aviso_texto_extra_label != null:
		aviso_texto_extra_label.modulate = Color(1, 1, 1, 1)

	intro_cenario_em_execucao = false



func _esconder_aviso_inicio() -> void:
	if aviso_root != null:
		aviso_root.visible = false

	var tw := create_tween()
	tw.set_parallel(true)

	if aviso_panel != null:
		tw.tween_property(aviso_panel, "modulate:a", 0.0, 0.16)
		tw.tween_property(aviso_panel, "scale", Vector2(0.96, 0.96), 0.16)

	if aviso_titulo != null:
		tw.tween_property(aviso_titulo, "modulate:a", 0.0, 0.14)

	if aviso_subtitulo != null:
		tw.tween_property(aviso_subtitulo, "modulate:a", 0.0, 0.14)

	tw.finished.connect(func() -> void:
		if aviso_root != null:
			aviso_root.visible = false
	)



func _iniciar_partida_no_primeiro_tiro() -> void:
	if partida_iniciada:
		return

	partida_iniciada = true
	tempo_restante = tempo_partida
	tempo_turno = 0.0

	if aviso_root != null:
		var tw := create_tween()
		tw.set_parallel(true)

		if aviso_panel != null:
			tw.tween_property(aviso_panel, "modulate:a", 0.0, 0.18)
		if aviso_titulo != null:
			tw.tween_property(aviso_titulo, "modulate:a", 0.0, 0.16)
		if aviso_subtitulo != null:
			tw.tween_property(aviso_subtitulo, "modulate:a", 0.0, 0.16)

		tw.finished.connect(func() -> void:
			if aviso_root != null:
				aviso_root.visible = false)

	_set_status_neutro("")



func _ajustar_layout() -> void:
	_ajustar_mascara_topo()

	var tela_tam: Vector2 = get_viewport_rect().size
	var tela_w: int = int(round(tela_tam.x))
	var tela_h: int = int(round(tela_tam.y))

	if hud_root != null:
		hud_root.position = Vector2.ZERO
		hud_root.size = Vector2(tela_w, tela_h)
		hud_root.scale = Vector2.ONE
		hud_root.rotation = 0.0

	# ── FUNDO HUD — Panel neon verde arredondado ────────────────────────────
	if top_bar != null:
		top_bar.position = Vector2(8, 8)
		top_bar.size = Vector2(tela_w - 16, 220)
		top_bar.z_index = 40

	# Decorações antigas — o Panel já tem borda e sombra, essas ficam invisíveis
	if top_bar_sombra != null:
		top_bar_sombra.visible = false
	if top_bar_glow != null:
		top_bar_glow.visible = false
	if top_bar_linha != null:
		top_bar_linha.visible = false

	# ── Geometria base: todos os sub-painéis na mesma faixa vertical ────────
	# top_bar: y=8, height=220 → bottom=228
	# sub-painéis: py=18, ph=192 → bottom=210  (dentro de top_bar) ✓
	var py: int = 18
	var ph: int = 192

	# ── TEMPO — esquerda ────────────────────────────────────────────────────
	var tp_x: int = 20
	var tp_w: int = 202

	if timer_panel != null:
		timer_panel.position = Vector2(tp_x, py)
		timer_panel.size = Vector2(tp_w, ph)
		timer_panel.z_index = 55

	if timer_title_label != null:
		timer_title_label.position = Vector2(tp_x, py + 12)
		timer_title_label.size = Vector2(tp_w, 26)
		timer_title_label.z_index = 90

	if timer_label != null:
		timer_label.position = Vector2(tp_x, py + 52)
		timer_label.size = Vector2(tp_w, 90)
		timer_label.z_index = 90

	# ── PONTUAÇÃO — centro ──────────────────────────────────────────────────
	# ── PONTUAÇÃO — ancorada à direita do timer, avança para a esquerda ─────
	var sc_w: int = 420
	var sc_x: int = tp_x + tp_w + 18

	if score_panel != null:
		score_panel.position = Vector2(sc_x, py)
		score_panel.size = Vector2(sc_w, ph)
		score_panel.z_index = 55

	if score_title_label != null:
		score_title_label.position = Vector2(sc_x, py + 12)
		score_title_label.size = Vector2(sc_w, 28)
		score_title_label.z_index = 90

	if score_label != null:
		score_label.position = Vector2(sc_x, py + 54)
		score_label.size = Vector2(sc_w, 114)
		score_label.z_index = 90

	# ── ACERTOS / TIROS — canto direito (painel próprio) ────────────────────
	var st_w: int = 176
	var st_x: int = tela_w - st_w - 18

	if stats_hud_panel != null:
		stats_hud_panel.position = Vector2(st_x, py)
		stats_hud_panel.size = Vector2(st_w, ph)
		stats_hud_panel.z_index = 55

	if acertos_title_label != null:
		acertos_title_label.position = Vector2(st_x, py + 4)
		acertos_title_label.size = Vector2(st_w, 24)

	if acertos_label != null:
		acertos_label.position = Vector2(st_x, py + 32)
		acertos_label.size = Vector2(st_w, 58)

	if tiros_title_label != null:
		tiros_title_label.position = Vector2(st_x, py + 92)
		tiros_title_label.size = Vector2(st_w, 24)

	if tiros_label != null:
		tiros_label.position = Vector2(st_x, py + 120)
		tiros_label.size = Vector2(st_w, 58)

	# ── MUNIÇÃO — posicionado entre score e stats sem sobrepor ──────────────
	# max() garante que não encosta no score; o clamp máximo evita encosto no stats
	var mu_w: int = 238
	var mu_x: int = clamp(
		st_x - mu_w - 14,
		sc_x + sc_w + 12,
		st_x - mu_w - 14
	)

	if municao_panel != null:
		municao_panel.position = Vector2(mu_x, py)
		municao_panel.size = Vector2(mu_w, ph)
		municao_panel.z_index = 55

	if municao_title_label != null:
		municao_title_label.position = Vector2(mu_x, py + 10)
		municao_title_label.size = Vector2(mu_w, 24)
		municao_title_label.z_index = 90

	# blocos de munição ficam dentro do painel via _atualizar_barra_municao
	# margem_topo=44 → y=py+44=62 até py+44+34=96 (dentro de ph=192) ✓

	if municao_label != null:
		municao_label.position = Vector2(mu_x, py + 118)
		municao_label.size = Vector2(mu_w, 22)
		municao_label.z_index = 90

	if recarga_label != null:
		recarga_label.position = Vector2(mu_x, py + 146)
		recarga_label.size = Vector2(mu_w, 20)
		recarga_label.z_index = 90

	# ── Status (mensagens de jogo) ──────────────────────────────────────────
	# ── Status / Pontuação / Combo Rodapé ─────────────────────
	var status_w: float = float(tela_w) - 48.0
	var status_h: float = 82.0
	var status_x: float = 24.0
	var status_y: float = float(tela_h) - 118.0

	if status_panel != null:
		status_panel.position = Vector2(status_x, status_y).round()
		status_panel.size = Vector2(status_w, status_h)
		status_panel.z_index = 90

	if status_label != null:
		status_label.position = Vector2(status_x + 20.0, status_y + 8.0).round()
		status_label.size = Vector2(status_w - 40.0, 44.0)
		status_label.z_index = 95
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if combo_hud_label != null:
		combo_hud_label.position = Vector2(status_x + 28.0, status_y + 30.0).round()
		combo_hud_label.size = Vector2(status_w - 56.0, 48.0)
		combo_hud_label.z_index = 96
		combo_hud_label.scale = Vector2.ONE
		combo_hud_label.rotation = 0.0
		combo_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		combo_hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_ajustar_layout_aviso_inicio()

	if comeco_titulo != null:
		comeco_titulo.position = Vector2(int((tela_w - 320) / 2), int((tela_h * 0.5) - 78))
		comeco_titulo.size = Vector2(320, 110)

	if comeco_subtitulo != null:
		comeco_subtitulo.position = Vector2(int((tela_w - 400) / 2), int((tela_h * 0.5) + 34))
		comeco_subtitulo.size = Vector2(400, 38)

	_desligar_linhas_hud_tremendo()
	_atualizar_barra_municao()
	_ajustar_modal_nome_ranking()



func _desligar_linhas_hud_tremendo() -> void:
	if top_bar_linha != null:
		top_bar_linha.visible = false
		top_bar_linha.modulate.a = 0.0

	if top_bar_glow != null:
		top_bar_glow.visible = false
		top_bar_glow.modulate.a = 0.0



func _iniciar_musica_fim_em_loop() -> void:
	# Não usa mais end_game.
	# Mantém a música do bar tocando em loop.
	_parar_musica_fim()
	_iniciar_musica_bar_em_loop()


func _parar_musica_fim() -> void:
	if fim_end_music_player != null and fim_end_music_player.playing:
		fim_end_music_player.stop()


func _iniciar_cutscene_fim() -> void:
	fim_cutscene_ativa = true

	if fim_panel != null:
		fim_panel.visible = false
	if fim_title_label != null:
		fim_title_label.visible = false
	if fim_score_label != null:
		fim_score_label.visible = false
	if fim_stats_label != null:
		fim_stats_label.visible = false
	if fim_insert_coin_label != null:
		fim_insert_coin_label.visible = false
	if fim_countdown_label != null:
		fim_countdown_label.visible = false

	if fim_cutscene_panel != null:
		fim_cutscene_panel.visible = true
		fim_cutscene_panel.modulate = Color(1, 1, 1, 0.0)
		fim_cutscene_panel.scale = Vector2(0.92, 0.92)

	if fim_cutscene_titulo != null:
		fim_cutscene_titulo.visible = true
		fim_cutscene_titulo.modulate = Color(1, 1, 1, 0.0)

	if fim_cutscene_loading != null:
		fim_cutscene_loading.visible = true
		fim_cutscene_loading.modulate = Color(1, 1, 1, 0.0)

	if fim_cutscene_barra_bg != null:
		fim_cutscene_barra_bg.visible = true
		fim_cutscene_barra_bg.modulate = Color(1, 1, 1, 0.0)

	if fim_cutscene_barra_fill != null:
		fim_cutscene_barra_fill.visible = true
		fim_cutscene_barra_fill.modulate = Color(1, 1, 1, 1.0)
		fim_cutscene_barra_fill.size.x = 0.0

	var tw_in := create_tween()
	tw_in.set_parallel(true)

	if fim_cutscene_panel != null:
		tw_in.tween_property(fim_cutscene_panel, "modulate:a", 1.0, 0.28)
		tw_in.tween_property(fim_cutscene_panel, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if fim_cutscene_titulo != null:
		tw_in.tween_property(fim_cutscene_titulo, "modulate:a", 1.0, 0.22)

	if fim_cutscene_loading != null:
		tw_in.tween_property(fim_cutscene_loading, "modulate:a", 1.0, 0.24).set_delay(0.08)

	if fim_cutscene_barra_bg != null:
		tw_in.tween_property(fim_cutscene_barra_bg, "modulate:a", 1.0, 0.24).set_delay(0.10)

	await tw_in.finished

	if fim_cutscene_barra_fill != null and fim_cutscene_barra_bg != null:
		var tw_bar := create_tween()
		tw_bar.tween_property(
			fim_cutscene_barra_fill,
			"size:x",
			fim_cutscene_barra_bg.size.x,
			duracao_loading_resultado_seg
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await get_tree().create_timer(duracao_cutscene_fim_seg).timeout
	_mostrar_modal_resultado_final()



func _mostrar_modal_resultado_final() -> void:
	fim_cutscene_ativa = false

	if fim_cutscene_panel != null:
		fim_cutscene_panel.visible = false
	if fim_cutscene_titulo != null:
		fim_cutscene_titulo.visible = false
	if fim_cutscene_loading != null:
		fim_cutscene_loading.visible = false
	if fim_cutscene_barra_bg != null:
		fim_cutscene_barra_bg.visible = false
	if fim_cutscene_barra_fill != null:
		fim_cutscene_barra_fill.visible = false

	if fim_panel != null:
		fim_panel.visible = true
		fim_panel.modulate = Color(1, 1, 1, 0.0)
		fim_panel.scale = Vector2(0.92, 0.92)

	if fim_title_label != null:
		fim_title_label.visible = true
		fim_title_label.modulate = Color(1, 1, 1, 0.0)

	if fim_score_label != null:
		fim_score_label.visible = true
		fim_score_label.modulate = Color(1, 1, 1, 0.0)

	if fim_stats_label != null:
		fim_stats_label.visible = true
		fim_stats_label.modulate = Color(1, 1, 1, 0.0)

	if fim_insert_coin_label != null:
		fim_insert_coin_label.visible = true
		fim_insert_coin_label.text = "APERTE START PARA RECOMEÇAR"
		fim_insert_coin_label.modulate = Color(1, 1, 1, 0.0)

	if fim_countdown_label != null:
		fim_countdown_label.visible = true
		fim_countdown_label.modulate = Color(1, 1, 1, 0.0)

	tempo_fim_menu = tempo_auto_retorno_menu_seg
	fim_pulso_t = 0.0

	var tw := create_tween()
	tw.set_parallel(true)

	if fim_panel != null:
		tw.tween_property(fim_panel, "modulate:a", 1.0, 0.28)
		tw.tween_property(fim_panel, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if fim_title_label != null:
		tw.tween_property(fim_title_label, "modulate:a", 1.0, 0.22)

	if fim_score_label != null:
		tw.tween_property(fim_score_label, "modulate:a", 1.0, 0.24).set_delay(0.06)

	if fim_stats_label != null:
		tw.tween_property(fim_stats_label, "modulate:a", 1.0, 0.26).set_delay(0.10)

	if fim_insert_coin_label != null:
		tw.tween_property(fim_insert_coin_label, "modulate:a", 1.0, 0.28).set_delay(0.14)

	if fim_countdown_label != null:
		tw.tween_property(fim_countdown_label, "modulate:a", 1.0, 0.28).set_delay(0.18)



func _criar_mascara_topo() -> void:
	# removida de propósito
	mascara_topo = null


func _ajustar_mascara_topo() -> void:
	return
	


func _registrar_combo_acerto() -> void:
	var agora: float = Time.get_ticks_msec() / 1000.0

	if agora - tempo_ultimo_acerto <= JANELA_COMBO:
		sequencia_acertos += 1
	else:
		sequencia_acertos = 1

	tempo_ultimo_acerto = agora
	melhor_sequencia = max(melhor_sequencia, sequencia_acertos)

	if sequencia_acertos == 2:
		total_double_hits += 1
		_ativar_combo_fx("DOUBLE HIT")
	elif sequencia_acertos == 3:
		total_triple_hits += 1
		_ativar_combo_fx("TRIPLE HIT")
	elif sequencia_acertos == 4:
		total_quadra_hits += 1
		_ativar_combo_fx("QUADRA HIT")
	elif sequencia_acertos == 5:
		total_penta_hits += 1
		_ativar_combo_fx("PENTA HIT")
	elif sequencia_acertos >= 6:
		total_super_combos += 1
		_ativar_combo_fx("SUPER COMBO")




func _resetar_combo() -> void:
	sequencia_acertos = 0
	tempo_ultimo_acerto = -100.0
	combo_fx_t = 0.0
	combo_fx_texto = ""
	combo_fx_ativo = false

	if combo_hud_label != null:
		combo_hud_label.visible = false
		combo_hud_label.text = ""



func _ativar_combo_fx(texto: String) -> void:
	combo_fx_texto = texto
	combo_fx_t = DURACAO_COMBO_FX
	combo_fx_ativo = true

	if combo_hud_label != null:
		combo_hud_label.text = texto
		combo_hud_label.visible = true


func _set_estilo_panel(
	panel: Panel,
	bg: Color,
	borda: Color = COR_NEON_BAR,
	sombra_alpha: float = 0.60
) -> void:
	if panel == null:
		return

	var estilo := panel.get_theme_stylebox("panel") as StyleBoxFlat

	if estilo == null:
		estilo = _estilo_card_bar()
		Leve.stylebox(panel, "panel", estilo)

	estilo.bg_color = bg
	estilo.border_color = borda
	estilo.shadow_color = Color(borda.r, borda.g, borda.b, sombra_alpha)


func _atualizar_hud() -> void:
	if score_label != null:
		score_label.text = str(pontuacao_total)

		if pontuacao_total > 0:
			score_label.modulate = Color(0.42, 1.0, 0.52, 1.0)
		elif pontuacao_total < 0:
			score_label.modulate = Color(1.0, 0.28, 0.28, 1.0)
		else:
			score_label.modulate = Color(0.82, 1.0, 0.86, 1.0)

	if timer_label != null:
		var minutos: int = int(tempo_restante) / 60
		var segundos: int = int(tempo_restante) % 60
		timer_label.text = "%02d:%02d" % [minutos, segundos]

	if tiros_label != null:
		tiros_label.text = str(total_tiros)

	if acertos_label != null:
		acertos_label.text = str(total_acertos)

	if municao_panel != null and municao_label != null:
		if recarregando:
			var pulso_rec: float = 0.70 + (sin(aviso_recarga_t * 10.0) * 0.5 + 0.5) * 0.30
			_set_estilo_panel(municao_panel, Color(0.02, 0.12, 0.07, 0.96), Color(0.20, 1.0, 0.75, 1.0), 0.70)

			municao_label.text = "RECARREGANDO"
			municao_label.modulate = Color(0.30, 1.0, 0.70, pulso_rec)

			if recarga_label != null:
				recarga_label.text = "AGUARDE %.1fs" % reload_tempo_restante
				recarga_label.modulate = Color(0.78, 1.0, 0.82, pulso_rec)

		elif balas_no_cartucho <= 0:
			var pulso_vazio: float = 0.60 + (sin(aviso_recarga_t * 12.0) * 0.5 + 0.5) * 0.40
			_set_estilo_panel(municao_panel, Color(0.22, 0.04, 0.05, 0.98), Color(1.0, 0.12, 0.10, 1.0), 0.70)

			municao_label.text = "RECARREGUE!"
			municao_label.modulate = Color(1.0, 0.24, 0.22, pulso_vazio)

			if recarga_label != null:
				recarga_label.text = "USE A RECARGA DA ARMA"
				recarga_label.modulate = Color(1.0, 0.72, 0.72, pulso_vazio)

		elif balas_no_cartucho <= alerta_baixa_municao_limite:
			var pulso_crit: float = 0.72 + (sin(aviso_recarga_t * 9.0) * 0.5 + 0.5) * 0.28
			_set_estilo_panel(municao_panel, Color(0.20, 0.11, 0.03, 0.98), Color(1.0, 0.62, 0.12, 1.0), 0.62)

			municao_label.text = "MUNIÇÃO BAIXA"
			municao_label.modulate = Color(1.0, 0.68, 0.18, pulso_crit)

			if recarga_label != null:
				recarga_label.text = "PREPARE A RECARGA"
				recarga_label.modulate = Color(1.0, 0.84, 0.48, pulso_crit)

		else:
			_set_estilo_panel(municao_panel, COR_FUNDO_CARD_BAR, COR_NEON_BAR, 0.60)

			municao_label.text = "CARREGADA"
			municao_label.modulate = Color(0.82, 1.0, 0.90, 1.0)

			if recarga_label != null:
				recarga_label.text = "BOTÃO DE RECARGA NA ARMA"
				recarga_label.modulate = Color(0.76, 1.0, 0.82, 0.95)

	_atualizar_barra_municao()

	if timer_panel != null and timer_label != null:
		if tempo_restante <= 15.0:
			_set_estilo_panel(timer_panel, Color(0.30, 0.04, 0.04, 0.98), Color(1.0, 0.08, 0.06, 1.0), 0.70)
			timer_label.modulate = COR_TIMER_CRITICO
		elif tempo_restante <= 40.0:
			_set_estilo_panel(timer_panel, Color(0.26, 0.14, 0.03, 0.98), Color(1.0, 0.62, 0.12, 1.0), 0.62)
			timer_label.modulate = COR_TIMER_ALERTA
		else:
			_set_estilo_panel(timer_panel, COR_FUNDO_CARD_BAR, COR_NEON_BAR, 0.60)
			timer_label.modulate = Color.WHITE



func _set_status_neutro(texto: String) -> void:
	if texto.strip_edges() == "":
		if status_tween != null:
			status_tween.kill()

		if status_label != null:
			status_label.text = ""
			status_label.visible = false
			status_label.modulate = Color(1, 1, 1, 0)
			status_label.scale = Vector2.ONE
			status_label.rotation = 0.0

		if status_panel != null:
			status_panel.visible = false
			status_panel.modulate.a = 0.0
			status_panel.scale = Vector2.ONE

		return

	status_token += 1
	var token_local: int = status_token

	if status_tween != null:
		status_tween.kill()

	if status_label != null:
		status_label.text = texto
		status_label.visible = true
		status_label.modulate = Color(1, 1, 1, 0)
		status_label.scale = Vector2.ONE
		status_label.rotation = 0.0
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		Leve.font_size(status_label, "font_size", 40)
		Leve.color(status_label, "font_color", Color.WHITE)
		Leve.color(status_label, "font_outline_color", Color.BLACK)
		Leve.constant(status_label, "outline_size", 8)

	if status_panel != null:
		status_panel.visible = true
		status_panel.modulate = Color(1, 1, 1, 0)
		status_panel.scale = Vector2.ONE

		var estilo := status_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if estilo == null:
			estilo = _estilo_card_bar()
			Leve.stylebox(status_panel, "panel", estilo)

		estilo.bg_color = Color(0.025, 0.105, 0.035, 0.92)
		estilo.border_color = COR_NEON_BAR
		estilo.shadow_color = Color(COR_NEON_BAR.r, COR_NEON_BAR.g, COR_NEON_BAR.b, 0.72)
		estilo.shadow_size = 34

	_ajustar_layout()

	status_tween = create_tween()
	status_tween.set_parallel(true)

	if status_label != null:
		status_tween.tween_property(status_label, "modulate:a", 1.0, 0.08)
		status_tween.tween_property(status_label, "modulate:a", 0.0, 0.22).set_delay(1.45)

	if status_panel != null:
		status_tween.tween_property(status_panel, "modulate:a", 1.0, 0.08)
		status_tween.tween_property(status_panel, "scale", Vector2(1.015, 1.10), 0.08)
		status_tween.tween_property(status_panel, "scale", Vector2.ONE, 0.14).set_delay(0.08)
		status_tween.tween_property(status_panel, "modulate:a", 0.0, 0.22).set_delay(1.45)

	_reset_status_depois(1.75, token_local)



func _criar_blocos_municao() -> void:
	municao_blocos.clear()

	if municao_panel == null:
		return

	for filho in municao_panel.get_children():
		if filho is ColorRect and str(filho.name).begins_with("BlocoMunicao_"):
			filho.queue_free()

	for i in range(capacidade_cartucho):
		var bloco := ColorRect.new()
		bloco.name = "BlocoMunicao_%02d" % i
		bloco.color = Color(0.20, 0.24, 0.30, 0.95)
		municao_panel.add_child(bloco)
		municao_blocos.append(bloco)


func _atualizar_barra_municao() -> void:
	if municao_panel == null or municao_blocos.is_empty():
		return

	var margem_x: float = 14.0
	var margem_topo: float = 48.0
	var largura_util: float = municao_panel.size.x - (margem_x * 2.0)
	var espacamento: float = 3.0
	var total_blocos: int = municao_blocos.size()

	if total_blocos <= 0:
		return

	var largura_bloco: float = (largura_util - (espacamento * float(total_blocos - 1))) / float(total_blocos)
	var altura_bloco: float = 34.0

	for i in range(total_blocos):
		var bloco := municao_blocos[i]
		if bloco == null:
			continue

		bloco.position = Vector2(
			margem_x + (largura_bloco + espacamento) * float(i),
			margem_topo
		).round()
		bloco.size = Vector2(max(largura_bloco, 2.0), altura_bloco)

		var ativo: bool = i < balas_no_cartucho

		if recarregando:
			var pulso: float = 0.58 + (sin(aviso_recarga_t * 10.0 + float(i) * 0.18) * 0.5 + 0.5) * 0.42
			bloco.color = Color(0.22, 0.92, 1.0, pulso)
		elif not ativo:
			bloco.color = Color(0.16, 0.18, 0.22, 0.42)
		else:
			var t: float = float(i) / max(float(total_blocos - 1), 1.0)

			if balas_no_cartucho <= alerta_baixa_municao_limite:
				bloco.color = Color(
					lerp(1.0, 1.0, t),
					lerp(0.72, 0.22, t),
					lerp(0.18, 0.12, t),
					1.0
				)
			else:
				bloco.color = Color(
					lerp(1.0, 0.24, t),
					lerp(0.42, 0.92, t),
					lerp(0.18, 1.0, t),
					1.0
				)
	if recarga_label != null:
		recarga_label.text = ""
		recarga_label.visible = false



func _set_status_acerto(texto: String) -> void:
	# topo fixo: não usa mais status de acerto para pontos/hits
	status_token += 1

	if status_tween != null:
		status_tween.kill()

	status_label.text = ""
	status_label.visible = false
	status_label.modulate = Color(1, 1, 1, 0)
	status_label.scale = Vector2.ONE
	status_label.rotation = 0.0

	status_panel.visible = false
	status_panel.modulate.a = 0.0



func _set_status_erro(texto: String) -> void:
	_set_status_neutro(texto)

	if status_label != null:
		Leve.color(status_label, "font_color", Color(1.0, 0.28, 0.18, 1.0))
		Leve.color(status_label, "font_outline_color", Color.BLACK)
		Leve.constant(status_label, "outline_size", 8)

	if status_panel != null:
		var estilo := status_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if estilo == null:
			estilo = _estilo_card_bar()
			Leve.stylebox(status_panel, "panel", estilo)

		# fundo neutro, só a borda/brilho muda para erro
		estilo.bg_color = Color(0.045, 0.060, 0.040, 0.92)
		estilo.border_color = Color(1.0, 0.18, 0.10, 1.0)
		estilo.shadow_color = Color(1.0, 0.08, 0.02, 0.70)
		estilo.shadow_size = 34



func _garrafa_valida(alvo: Area2D) -> bool:
	if alvo == null:
		return false
	if not is_instance_valid(alvo):
		return false
	if alvo.get("ja_acertado") == true:
		return false
	if alvo.get("saindo_individual") == true:
		return false
	if not jogo_ativo:
		return false
	if not partida_iniciada:
		return false
	return true



func _animar_status_acerto_forte() -> void:
	pass



func _animar_status_erro_forte() -> void:
	pass


func _reset_status_depois(segundos: float, token_local: int) -> void:
	call_deferred("_reset_status_depois_async", segundos, token_local)


func _reset_status_depois_async(segundos: float, token_local: int) -> void:
	await get_tree().create_timer(segundos).timeout
	if token_local != status_token:
		return
	if jogo_ativo:
		if recarregando or (balas_no_cartucho <= 0 and partida_iniciada):
			return
		status_label.text = ""
		status_label.visible = false
		status_label.modulate = Color(1, 1, 1, 0)
		status_label.scale = Vector2.ONE
		status_label.rotation = 0.0


func _animar_fim(delta: float) -> void:
	tempo_fim_menu = max(0.0, tempo_fim_menu - delta)
	fim_pulso_t += delta

	_posicionar_modal_final()

	if fim_insert_coin_label != null:
		fim_insert_coin_label.modulate.a = 0.55 + abs(sin(fim_pulso_t * 5.0)) * 0.45

	if fim_countdown_label != null:
		if ranking_nome_ativo:
			fim_countdown_label.text = "DIGITE SEU NOME PARA SALVAR O RECORDE"
		else:
			fim_countdown_label.text = "VOLTANDO AO MENU EM %02d" % int(ceil(tempo_fim_menu))

	if tempo_fim_menu <= 0.0:
		_retornar_para_menu()



func _on_viewport_size_changed() -> void:
	call_deferred("_ajustar_fundo_full")
	call_deferred("_ajustar_layout")
	_ajustar_layout_aviso_inicio()
	_posicionar_modal_final()



func _atualizar_combo_hud() -> void:
	if combo_hud_label == null:
		return

	if sequencia_acertos < 2 or combo_fx_texto == "":
		combo_hud_label.visible = false
		combo_hud_label.text = ""
		return

	var pulso: float = 0.72 + (sin(Time.get_ticks_msec() * 0.010) * 0.5 + 0.5) * 0.28

	combo_hud_label.visible = true
	combo_hud_label.text = combo_fx_texto
	combo_hud_label.scale = Vector2.ONE
	combo_hud_label.rotation = 0.0
	combo_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	combo_hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_hud_label.modulate = Color(1.0, 0.94, 0.34, pulso)
	Leve.font_size(combo_hud_label, "font_size", 26)
	Leve.color(combo_hud_label, "font_color", Color(1.0, 0.94, 0.34, 1.0))
	Leve.color(combo_hud_label, "font_outline_color", Color.BLACK)
	Leve.constant(combo_hud_label, "outline_size", 6)



func _ajustar_fundo_full() -> void:
	if fundo == null or fundo.texture == null:
		return

	var tamanho_tela: Vector2 = get_viewport_rect().size
	var tamanho_textura: Vector2 = fundo.texture.get_size()

	if tamanho_textura.x <= 0.0 or tamanho_textura.y <= 0.0:
		return

	var escala_x: float = tamanho_tela.x / tamanho_textura.x
	var escala_y: float = tamanho_tela.y / tamanho_textura.y
	var escala_final: float = max(escala_x, escala_y)

	fundo.centered = true
	fundo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fundo.position = Vector2(round(tamanho_tela.x * 0.5), round(tamanho_tela.y * 0.5))
	fundo.scale = Vector2.ONE * escala_final
	fundo.z_index = -100
	fundo_pos_base = fundo.position

	if fundo_preenchimento != null:
		fundo_preenchimento.centered = true
		fundo_preenchimento.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		fundo_preenchimento.position = fundo.position
		fundo_preenchimento.scale = Vector2.ONE * escala_final
		fundo_preenchimento.z_index = -200
		fundo_preenchimento.visible = false

	fundo_ajustado_uma_vez = true



func _obter_nivel_dificuldade() -> int:
	if pontos_por_nivel_dificuldade <= 0:
		return 0

	var pontos_validos: int = max(pontuacao_total, 0)
	var divisor: float = pontos_por_nivel_dificuldade * 1.0
	var resultado: float = (pontos_validos * 1.0) / divisor

	return max(0, floori(resultado))


func _atualizar_dificuldade_progressiva() -> int:
	var novo_nivel: int = _obter_nivel_dificuldade()
	if novo_nivel == nivel_dificuldade_atual:
		return 0

	nivel_dificuldade_atual = novo_nivel
	return novo_nivel


func _obter_tempo_turno_atual() -> float:
	var base: float = tempo_troca_turno - ((nivel_dificuldade_atual * 1.0) * bonus_velocidade_por_nivel)
	return max(1.85, base)


func _pode_recarregar() -> bool:
	return jogo_ativo \
		and partida_iniciada \
		and not intro_cenario_em_execucao \
		and not recarregando \
		and balas_no_cartucho < capacidade_cartucho


func _iniciar_recarga() -> void:
	if not _pode_recarregar():
		return

	recarregando = true
	reload_tempo_restante = tempo_recarga_seg

	if som_recharge_stream != null:
		_tocar_som(som_recharge_stream, 0.0)

	_set_status_neutro("RECARREGANDO...")
	_marcar_hud_sujo()
	queue_redraw()



func _finalizar_recarga() -> void:
	recarregando = false
	reload_tempo_restante = 0.0
	balas_no_cartucho = capacidade_cartucho
	_set_status_neutro("")
	_marcar_hud_sujo()
	queue_redraw()


func _marcar_hud_sujo() -> void:
	hud_sujo = true



func _atualizar_hud_se_necessario() -> void:
	var tempo_seg: int = int(ceil(max(tempo_restante, 0.0)))
	var reload_deci: int = int(round(reload_tempo_restante * 10.0))

	var mudou: bool = hud_sujo \
		or pontuacao_total != hud_cache_score \
		or total_tiros != hud_cache_tiros \
		or total_acertos != hud_cache_acertos \
		or balas_no_cartucho != hud_cache_balas \
		or recarregando != hud_cache_recarregando \
		or tempo_seg != hud_cache_tempo_seg \
		or (recarregando and reload_deci != hud_cache_reload_deci)

	if not mudou:
		return

	hud_cache_score = pontuacao_total
	hud_cache_tiros = total_tiros
	hud_cache_acertos = total_acertos
	hud_cache_balas = balas_no_cartucho
	hud_cache_recarregando = recarregando
	hud_cache_reload_deci = reload_deci
	hud_cache_tempo_seg = tempo_seg
	hud_sujo = false

	_atualizar_hud()



func _atualizar_status_constante() -> void:
	if not jogo_ativo:
		return

	if recarregando:
		status_label.visible = true
		status_label.text = "RECARREGANDO..."
		status_label.modulate = Color(0.78, 0.96, 1.0, 1.0)
		return

	if balas_no_cartucho <= 0 and partida_iniciada:
		status_label.visible = true
		status_label.text = "RECARREGUE!"
		status_label.modulate = Color(1.0, 0.24, 0.22, 1.0)
		return

	if status_label.text == "RECARREGUE!" or status_label.text == "RECARREGANDO...":
		status_label.text = ""
		status_label.visible = false
		status_label.modulate = Color(1, 1, 1, 0)


func _tem_fx_visuais_ativos() -> bool:
	return (
		not fx_madeira.is_empty()
		or not fx_vidro.is_empty()
		or not fx_impacto.is_empty()
		or tremor_tempo > 0.0
	)


func _obter_estado_mira() -> String:
	if recarregando:
		return "recarregando"
	if balas_no_cartucho <= 0:
		return "vazio"
	if balas_no_cartucho <= alerta_baixa_municao_limite:
		return "baixo"
	return "normal"


func _atualizar_mira_se_necessario(novo_alvo_pos: Vector2) -> void:
	var pos_arredondada := Vector2(round(novo_alvo_pos.x), round(novo_alvo_pos.y))
	var estado_atual := _obter_estado_mira()

	var mudou_pos := pos_arredondada != ultimo_alvo_pos
	var mudou_estado := estado_atual != ultimo_estado_mira

	alvo_pos = pos_arredondada

	if mudou_pos or mudou_estado:
		ultimo_alvo_pos = pos_arredondada
		ultimo_estado_mira = estado_atual

		if alvo_overlay != null:
			alvo_overlay.queue_redraw()



func _modo_dificil_sem_mira() -> bool:
	var dificuldade: String = get_tree().get_meta("modo_dificuldade", "facil")
	return dificuldade == "dificil"




var tempo_trava_input_arma: float = 0.0
var ultimo_tiro_arma_ms: int = -999999

const JANELA_BLOQUEIO_RECARGA_APOS_TIRO_MS: int = 450

const BOTAO_GATILHO_1: int = MOUSE_BUTTON_RIGHT
const BOTAO_GATILHO_2: int = MOUSE_BUTTON_LEFT

const BOTAO_RECARGA_1: int = MOUSE_BUTTON_MIDDLE
const BOTAO_RECARGA_2: int = MOUSE_BUTTON_XBUTTON1
const BOTAO_RECARGA_3: int = MOUSE_BUTTON_XBUTTON2


func _pos_arma() -> Vector2:
	return Tela.mouse()


func _debug_botao_arma(me: InputEventMouseButton) -> void:
	print("DEBUG ARMA BAR -> BOTÃO: ", me.button_index, " | pressed: ", me.pressed)


func _evento_tiro_arma(me: InputEventMouseButton) -> bool:
	# Igual Arena → botão esquerdo atira
	return me.button_index == MOUSE_BUTTON_LEFT

func _evento_action_arma(event: InputEvent, action_name: String) -> bool:
	if event == null:
		return false

	if not InputMap.has_action(action_name):
		return false

	if event is InputEventMouseMotion:
		return false

	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.echo:
			return false

	return event.is_action_pressed(action_name)


func _evento_input_shot_arma(event: InputEvent) -> bool:
	return _evento_action_arma(event, ACAO_TIRO_ARMA)


func _evento_input_recharge_arma(event: InputEvent) -> bool:
	return _evento_action_arma(event, ACAO_RECARGA_ARMA)


func _executar_tiro_arma() -> void:
	# Ranking usa trava própria: ranking_input_trava
	if ranking_nome_ativo:
		_ranking_tentar_atirar_tecla(alvo_pos)
		return

	if tempo_trava_input_arma > 0.0:
		return

	tempo_trava_input_arma = 0.10

	if not jogo_ativo:
		return

	if not partida_iniciada:
		_iniciar_intro_comeco()
		return

	if intro_comeco_ativa:
		return

	_processar_tiro_global(alvo_pos)


func _executar_recarga_arma() -> void:
	if ranking_nome_ativo:
		return

	if tempo_trava_input_arma > 0.0:
		return

	tempo_trava_input_arma = 0.10

	if jogo_ativo and partida_iniciada and not intro_comeco_ativa and not recarregando:
		_iniciar_recarga()


func _evento_recarga_arma(me: InputEventMouseButton) -> bool:
	# Igual Arena → botão direito recarrega
	# Scroll não faz nada
	return me.button_index == MOUSE_BUTTON_RIGHT


func _carregar_config_admin_jogo() -> void:
	var cfg_admin := ConfigFile.new()
	var err := cfg_admin.load("user://config_admin.cfg")

	if err != OK:
		tempo_restante = tempo_partida
		return

	tempo_partida = float(cfg_admin.get_value("jogo", "tempo_partida", tempo_partida))
	tempo_auto_retorno_menu_seg = float(cfg_admin.get_value("jogo", "tempo_modal_final", tempo_auto_retorno_menu_seg))
	ranking_nome_tempo = float(cfg_admin.get_value("ranking", "tempo_nome", ranking_nome_tempo))

	get_tree().set_meta("modo_dificuldade", str(cfg_admin.get_value("jogo", "dificuldade_padrao", get_tree().get_meta("modo_dificuldade", "facil"))))

	tempo_restante = tempo_partida
	tempo_fim_menu = tempo_auto_retorno_menu_seg



func _carregar_fontes_ui() -> void:
	if ResourceLoader.exists(FONTE_ORBITRON):
		fonte_orbitron = load(FONTE_ORBITRON) as FontFile

	if ResourceLoader.exists(FONTE_LUCKIEST):
		fonte_luckiest = load(FONTE_LUCKIEST) as FontFile


func _fonte_titulo(lbl: Label, tamanho: int, cor: Color = COR_NEON_BAR_CLARO) -> void:
	if lbl == null:
		return

	if fonte_luckiest != null:
		Leve.font(lbl, "font", fonte_luckiest)

	Leve.font_size(lbl, "font_size", tamanho)
	Leve.color(lbl, "font_color", cor)
	Leve.color(lbl, "font_outline_color", Color.BLACK)
	Leve.constant(lbl, "outline_size", 8)
	Leve.color(lbl, "font_shadow_color", cor)
	Leve.constant(lbl, "shadow_offset_x", 0)
	Leve.constant(lbl, "shadow_offset_y", 0)


func _fonte_valor(lbl: Label, tamanho: int, cor: Color = Color.WHITE) -> void:
	if lbl == null:
		return

	if fonte_orbitron != null:
		Leve.font(lbl, "font", fonte_orbitron)

	Leve.font_size(lbl, "font_size", tamanho)
	Leve.color(lbl, "font_color", cor)
	Leve.color(lbl, "font_outline_color", Color.BLACK)
	Leve.constant(lbl, "outline_size", 7)
	Leve.color(lbl, "font_shadow_color", cor)
	Leve.constant(lbl, "shadow_offset_x", 0)
	Leve.constant(lbl, "shadow_offset_y", 0)


func _estilo_card_bar() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_FUNDO_CARD_BAR
	estilo.border_width_left = 4
	estilo.border_width_top = 4
	estilo.border_width_right = 4
	estilo.border_width_bottom = 4
	estilo.border_color = COR_NEON_BAR
	estilo.corner_radius_top_left = 34
	estilo.corner_radius_top_right = 34
	estilo.corner_radius_bottom_left = 34
	estilo.corner_radius_bottom_right = 34
	estilo.shadow_color = Color(COR_NEON_BAR.r, COR_NEON_BAR.g, COR_NEON_BAR.b, 0.60)
	estilo.shadow_size = 34
	estilo.shadow_offset = Vector2.ZERO
	return estilo


func _estilo_modal_bar() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color            = Color(0.010, 0.038, 0.014, 0.96)
	estilo.border_width_left   = 4
	estilo.border_width_top    = 4
	estilo.border_width_right  = 4
	estilo.border_width_bottom = 4
	estilo.border_color        = COR_NEON_BAR
	estilo.corner_radius_top_left     = 56
	estilo.corner_radius_top_right    = 56
	estilo.corner_radius_bottom_left  = 56
	estilo.corner_radius_bottom_right = 56
	estilo.shadow_color  = Color(COR_NEON_BAR.r, COR_NEON_BAR.g, COR_NEON_BAR.b, 0.68)
	estilo.shadow_size   = 46
	estilo.shadow_offset = Vector2.ZERO
	return estilo
