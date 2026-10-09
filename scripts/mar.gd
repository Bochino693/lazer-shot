extends Node2D

const Pincel := preload("res://scripts/pincel.gd")
const RankingManagerScript := preload("res://scripts/RankingManager.gd")
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
var ranking_cenario_pendente: String = "MAR"
var ranking_precisao_pendente: int = 0
var ranking_ja_salvo: bool = false

var ranking_trava_tecla_tiro: bool = false


var fx_redraw_timer: float = 0.0
@export var fx_redraw_fps: float = 30.0

@export var splash_erro_leve: bool = true
@export var tiro_sem_tremida_no_erro: bool = true


@export var caminho_background: String = "res://sprites/atlantis.png"
@export var tempo_partida: float = 120.0
@export var som_aguaviva_hit_path: String = "res://songs/buble_hit.mp3"
@export var som_bomba_xploit_path: String = "res://songs/xploit.mp3"
@export var som_recharge_path: String = "res://songs/recharge.mp3"
@export var escala_aguaviva_min: float = 0.63
@export var escala_aguaviva_max: float = 0.81
@export var som_bullet_no_path: String = "res://songs/bullet_no.mp3"
var som_bullet_no_stream: AudioStream = null
@export var reducao_spawn_aguaviva: float = 0.5
@export var reducao_spawn_vaso: float = 0.5
@export_file("*.tscn") var cena_main_menu_path: String = "res://scenes/main.tscn"
@export var tempo_auto_retorno_menu_seg: float = 21.0


@export var caminho_info_inicio: String = "res://info_scenes/mar_info.png"

var info_inicio_layer: CanvasLayer = null
var info_inicio_root: Control = null
var info_inicio_bg: ColorRect = null
var info_inicio_image: TextureRect = null
var info_inicio_label: Label = null


const FONTE_TEXTO: String = "res://fonts/Exo2-Bold.ttf"
const FONTE_LUCKIEST: String = "res://fonts/LuckiestGuy-Regular.ttf"

const COR_NEON_MAR: Color = Color(0.18, 0.88, 1.0, 1.0)
const COR_NEON_MAR_CLARO: Color = Color(0.78, 0.96, 1.0, 1.0)
const COR_FUNDO_CARD_MAR: Color = Color(0.015, 0.035, 0.065, 0.94)

var fonte_orbitron: FontFile = null
var fonte_luckiest: FontFile = null

var bombas_restantes_label: Label = null
var bombas_erros_max: int = 3
var bombas_erros_atual: int = 0
var bombas_icones: Array[Area2D] = []


@export var som_fim_path: String = "res://songs/end_game.mp3"
@export var duracao_cutscene_fim_seg: float = 2.2
@export var duracao_loading_resultado_seg: float = 1.6

var som_fim_stream: AudioStream = null
var som_pirate_stream: AudioStream = null

var fim_cutscene_ativa: bool = false
var fim_cutscene_panel: Panel
var fim_cutscene_titulo: Label
var fim_cutscene_loading: Label
var fim_cutscene_barra_bg: ColorRect
var fim_cutscene_barra_fill: ColorRect

@export var pontos_por_nivel_dificuldade: int = 3000
@export var bonus_chance_bomba_por_nivel: float = 0.06
@export var bonus_velocidade_por_nivel: float = 0.12
@export var bonus_escala_bomba_por_nivel: float = 0.07
@export var bonus_margem_spawn_por_nivel: float = 18.0


@export var bonus_bomba_inicio_partida: float = 0.10

@export var bonus_max_bombas_por_nivel: int = 2
@export var bonus_tentativas_spawn_bomba_por_nivel: int = 1
@export var bonus_chance_bomba_extra_apos_3000: float = 0.10

@export var janela_combo_seg: float = 1.15
@export var escala_combo_visual_base: float = 1.0

var fim_retorno_timer: float = 0.0
var fim_countdown_label: Label
var fim_end_music_player: AudioStreamPlayer = null
var pirate_music_player: AudioStreamPlayer = null

var nivel_dificuldade_atual: int = 0
var combo_hits_seguidos: int = 0
var combo_timer_restante: float = 0.0

var combo_layer: CanvasLayer
var combo_label: Label

@export var escala_vaso_min: float = 0.58
@export var escala_vaso_max: float = 0.70

@export var escala_bau_min: float = 1.12
@export var escala_bau_max: float = 1.22

@export var escala_bomba_min: float = 1.18
@export var escala_bomba_max: float = 1.34

@export var margem_seguranca_spawn: float = 110.0
@export var max_tentativas_spawn_sem_sobrepor: int = 24

@export var bolha_objeto_intervalo_min: float = 0.14
@export var bolha_objeto_intervalo_max: float = 0.34
@export var bolha_objeto_qtd_min: int = 1
@export var bolha_objeto_qtd_max: int = 3

const Z_INDEX_OBJETOS_COMUNS: int = 30
const Z_INDEX_BOMBA: int = 80
var som_recharge_stream: AudioStream = null

@export var aguaviva_balanço_x: float = 16.0
@export var aguaviva_balanço_y: float = 10.0
@export var aguaviva_rotacao_idle: float = 8.0
@export var aguaviva_pulso_escala: float = 0.05
@export var aguaviva_freq_x: float = 1.8
@export var aguaviva_freq_y: float = 2.6
@export var aguaviva_freq_rot: float = 1.5
@export var aguaviva_freq_pulso: float = 3.0
@export var aguaviva_bolha_intervalo_min: float = 0.12
@export var aguaviva_bolha_intervalo_max: float = 0.26
@export var aguaviva_bolhas_por_onda_min: int = 1
@export var aguaviva_bolhas_por_onda_max: int = 3

@export var atraso_aguaviva_hit_seg: float = 0.0
@export var inicio_aguaviva_hit_seg: float = 0.0

@export var tremida_bomba_forca_extra: float = 20.0
@export var tremida_bomba_passos_extra: int = 14
@export var duracao_penalidade_bomba: float = 2.6
@export var intensidade_desvio_mira_bomba: float = 12.0
@export var acrescimo_cooldown_tiro_bomba_ms: int = 65

var som_aguaviva_hit_stream: AudioStream = null
var som_bomba_xploit_stream: AudioStream = null

var penalidade_bomba_t: float = 0.0
var mira_desvio_bomba: Vector2 = Vector2.ZERO

@export var pontos_aguaviva: int = 20
@export var pontos_vaso: int = 80
@export var pontos_bau: int = 100

@export var tempo_queda_aguaviva: float = 3.8
@export var tempo_queda_vaso: float = 4.5
@export var tempo_queda_bau: float = 3.0

@export var chance_aguaviva: float = 0.81
@export var chance_vaso: float = 0.42
@export var chance_bau: float = 0.28

@export var intervalo_spawn_min: float = 0.18
@export var intervalo_spawn_max: float = 0.42

@export var max_aguavivas_ativas: int = 6
@export var max_vasos_ativos: int = 3
@export var max_baus_ativos: int = 2

@export var margem_spawn_x: float = 90.0
@export var overscan_background: float = 1.06

@export var som_tiro_path: String = "res://songs/tiro-de-pistola.mp3"
@export var som_vaso_hit_path: String = "res://songs/vaso_hit.mp3"
@export var som_bau_hit_path: String = "res://songs/bau_hit.mp3"
@export var som_pirate_path: String = "res://songs/pirate.mp3"
var ultimo_tiro_ms: int = -1000
var ultimo_hit_ms: int = -1000

@export var cooldown_tiro_ms: int = 70
@export var cooldown_hit_ms: int = 20
@export var atraso_vaso_hit_seg: float = 0.000
@export var atraso_bau_hit_seg: float = 0.000
@export var pontos_bomba_min: int = 40
@export var pontos_bomba_max: int = 120
@export var tempo_queda_bomba: float = 3.4
@export var chance_bomba: float = 0.39
@export var max_bombas_ativas: int = 6

@export var som_bomba_hit_path: String = "res://songs/bomba_hit.mp3"
@export var som_bomba_explode_path: String = "res://songs/bomba_explode.mp3"
@export var intensidade_dano_bomba: float = 0.42
@export var duracao_dano_bomba: float = 0.78
@export var tremida_bomba_forca: float = 12.0
@export var tremida_bomba_passos: int = 9

@export var atraso_bomba_hit_seg: float = 0.000
@export var atraso_bomba_explode_seg: float = 0.000

@export var inicio_bau_hit_seg: float = 2.0
@export var inicio_vaso_hit_seg: float = 0.0
@export var inicio_bomba_hit_seg: float = 0.0
@export var inicio_bomba_explode_seg: float = 0.0

var dano_vinheta_overlay: ColorRect
var dano_nevoa_t: float = 0.0
var dano_nevoa_ativo: bool = false

var fx_explosao_bomba: Array[Dictionary] = []

var som_bomba_hit_stream: AudioStream = null
var som_bomba_explode_stream: AudioStream = null

var aguaviva_modelo: Area2D
var bomba_modelo: Area2D
var combo_bombas_acertadas: int = 0

var som_vaso_hit_stream: AudioStream = null
var som_bau_hit_stream: AudioStream = null

var fx_estilhacos: Array[Dictionary] = []

var recarga_info_label: Label
var tempo_restante: float = 0.0
var total_tiros: int = 0
var total_acertos: int = 0
var pontuacao_total: int = 0

var jogo_ativo: bool = true
var partida_iniciada: bool = false
var tela_inicio_ativa: bool = true
var encerrado: bool = false
var fx_moedas: Array[Dictionary] = []

var spawn_timer: float = 0.0
var alvo_anim_t: float = 0.0
var alvo_pos: Vector2 = Vector2.ZERO
var pulse_modal_t: float = 0.0

@export var recoil_forca_base: float = 2.6
@export var recoil_forca_max: float = 12.0
@export var recoil_decay: float = 18.0
@export var recoil_acumulo_por_tiro: float = 1.05
@export var recoil_ruido_lateral: float = 1.8
@export var recoil_desvio_max_px: float = 9.5
@export var recoil_desvio_vertical_px: float = 12.0
@export var capacidade_cartucho: int = 30
@export var tempo_recarga_seg: float = 1.15
@export var mira_reload_raio: float = 34.0
@export var mira_reload_espessura: float = 5.0
@export var alerta_baixa_municao_limite: int = 6

@export var usar_controle_xbox: bool = true
@export var velocidade_mira_xbox: float = 900.0
@export var deadzone_xbox: float = 0.18

# PADRÃO IGUAL ARENA / BAR / DESERTO
@export var xbox_botao_tiro: int = JOY_BUTTON_RIGHT_SHOULDER # R1 = TIRO
@export var xbox_botao_recarga: int = JOY_BUTTON_LEFT_SHOULDER # L1 = RECARGA
@export var xbox_botao_recarga_extra: int = JOY_BUTTON_LEFT_SHOULDER
const ACAO_TIRO_ARMA: String = "input_shot"
const ACAO_RECARGA_ARMA: String = "input_recharge"


var xbox_mira_iniciada: bool = false


var aviso_layer: CanvasLayer = null
var aviso_root: Control = null
var aviso_panel: ColorRect = null
var aviso_titulo: Label = null
var aviso_subtitulo: Label = null
var aviso_linha_divisoria: ColorRect = null

var aviso_card_aguaviva: ColorRect = null
var aviso_card_vaso_bau: ColorRect = null
var aviso_card_bomba: ColorRect = null

var aviso_preview_aguaviva_container: SubViewportContainer = null
var aviso_preview_aguaviva_viewport: SubViewport = null
var aviso_preview_aguaviva_root: Node2D = null
var aviso_preview_aguaviva_a: Area2D = null
var aviso_preview_aguaviva_b: Area2D = null

var aviso_preview_vaso_bau_container: SubViewportContainer = null
var aviso_preview_vaso_bau_viewport: SubViewport = null
var aviso_preview_vaso_bau_root: Node2D = null
var aviso_preview_vaso: Area2D = null
var aviso_preview_bau: Area2D = null

var aviso_preview_bomba_container: SubViewportContainer = null
var aviso_preview_bomba_viewport: SubViewport = null
var aviso_preview_bomba_root: Node2D = null
var aviso_preview_bomba: Area2D = null

var aviso_bloco_info: ColorRect = null
var aviso_dica_label: Label = null
var aviso_texto_extra_label: Label = null
var aviso_footer_label: Label = null
var aviso_footer_t: float = 0.0

var comeco_layer: CanvasLayer = null
var comeco_root: Control = null
var comeco_flash: ColorRect = null
var comeco_titulo: Label = null
var comeco_subtitulo: Label = null
var intro_comeco_ativa: bool = false
var intro_comeco_t: float = 0.0
var intro_contagem_valor: int = 3

var recoil_intensidade: float = 0.0
var recoil_tempo: float = 0.0
var balas_no_cartucho: int = 30
var recarregando: bool = false
var reload_tempo_restante: float = 0.0
var contagem_inicio_ativa: bool = false
var contagem_inicio_t: float = 0.0
var contagem_inicio_etapa: int = 3

var background: Sprite2D
var alvos_root: Node2D
var vaso_modelo: Area2D
var bau_modelo: Area2D

var alvos_ativos: Array[Area2D] = []

var hud_layer: CanvasLayer
var hud_root: Control
var top_bar: ColorRect
var top_bar_glow: ColorRect
var top_bar_sombra: ColorRect
var top_bar_linha: ColorRect
var timer_panel: Panel
var score_panel: Panel
var tiros_panel: Panel
var acertos_panel: Panel
var status_panel: Panel
var flash_overlay: ColorRect

var timer_title_label: Label
var timer_label: Label
var score_title_label: Label
var score_label: Label
var tiros_title_label: Label
var tiros_label: Label
var acertos_title_label: Label
var acertos_label: Label
var tiros_total_title_label: Label
var tiros_total_label: Label
var status_label: Label

var start_layer: CanvasLayer
var start_root: Control
var start_bg: ColorRect
var start_panel: ColorRect
var start_panel_glow: ColorRect
var start_title: Label
var start_text: Label
var start_hint: Label

var fx_back_layer: CanvasLayer
var fx_back_overlay: Control

var fx_front_layer: CanvasLayer
var fx_front_overlay: Control

var fim_layer: CanvasLayer
var fim_root: Control
var fim_bg: ColorRect
var fim_panel: Panel
var fim_title: Label
var fim_score: Label
var fim_stats: Label
var fim_hint: Label

var alerta_bomba_layer: CanvasLayer = null
var alerta_bomba_root: Control = null
var alerta_bomba_flash: ColorRect = null
var alerta_bomba_panel: Panel = null
var alerta_bomba_titulo: Label = null
var alerta_bomba_subtitulo: Label = null
var alerta_bomba_tw_pulse: Tween = null


var alvo_layer: CanvasLayer
var alvo_overlay: Control
var dano_overlay: ColorRect

var som_tiro_stream: AudioStream = null
var som_acerto_stream: AudioStream = null
var som_erro_stream: AudioStream = null

var marcas_agua: Array[Dictionary] = []
var fx_agua: Array[Dictionary] = []
var municao_blocos: Array[ColorRect] = []

var municao_title_label: Label
var municao_label: Label

var aviso_sem_municao_t: float = 0.0
var cor_mira_base: Color = Color(1.0, 0.24, 0.20, 0.94)
var cor_mira_reload: Color = Color(0.22, 0.92, 1.0, 1.0)
var cor_mira_sem_municao: Color = Color(1.0, 0.18, 0.16, 1.0)


const MAX_MARCAS_AGUA: int = 50

const COR_TIMER_NORMAL: Color = Color(0.70, 0.90, 1.0, 1.0)
const COR_TIMER_ALERTA: Color = Color(1.0, 0.66, 0.15, 1.0)
const COR_TIMER_CRITICO: Color = Color(1.0, 0.15, 0.12, 1.0)

const COR_PANEL_TIMER_NORMAL: Color = Color(0.05, 0.07, 0.11, 0.92)
const COR_PANEL_TIMER_ALERTA: Color = Color(0.26, 0.14, 0.03, 0.95)
const COR_PANEL_TIMER_CRITICO: Color = Color(0.30, 0.04, 0.04, 0.96)
const META_SENS_XBOX: String = "sensibilidade_xbox"
const META_SENS_MOUSE: String = "sensibilidade_mouse"

@export var sensibilidade_mouse: float = 1.0
var mouse_delta_acumulado: Vector2 = Vector2.ZERO


func _ready() -> void:
	randomize()

# Mira controlada localmente por _atualizar_mira_hibrida.
	alvo_pos = get_viewport_rect().size * 0.5
	mouse_delta_acumulado = Vector2.ZERO

	_aplicar_sensibilidade_global()
	_aplicar_config_admin_na_cena()
	_carregar_fontes_ui()

	bombas_erros_atual = 0
	aviso_sem_municao_t = 0.0
	tempo_restante = tempo_partida
	total_tiros = 0
	total_acertos = 0
	pontuacao_total = 0
	combo_bombas_acertadas = 0
	recoil_intensidade = 0.0
	recoil_tempo = 0.0
	balas_no_cartucho = capacidade_cartucho
	recarregando = false
	reload_tempo_restante = 0.0
	contagem_inicio_ativa = false
	contagem_inicio_t = 0.0
	contagem_inicio_etapa = 3

	jogo_ativo = true
	partida_iniciada = false
	tela_inicio_ativa = true
	encerrado = false

	background = get_node_or_null("Sprite2D") as Sprite2D
	alvos_root = get_node_or_null("Alvos") as Node2D
	aguaviva_modelo = get_node_or_null("Alvos/Aguaviva20") as Area2D
	vaso_modelo = get_node_or_null("Alvos/Vaso80") as Area2D
	bau_modelo = get_node_or_null("Alvos/Bau100") as Area2D
	bomba_modelo = get_node_or_null("Alvos/Bomba") as Area2D

	_validar_cena_base()

	if alvos_root != null:
		alvos_root.position = Vector2.ZERO
		alvos_root.scale = Vector2.ONE
		alvos_root.z_index = 5
		alvos_root.visible = true

	_preparar_modelos()
	_carregar_audios()

	_criar_fx_overlay()
	_criar_hud()
	_criar_hud_combo()
	_configurar_intro_comeco()
	_criar_tela_info_inicio()
	_criar_modal_fim()
	_criar_overlay_alerta_bombas()
	_configurar_modal_nome_ranking()
	_criar_mira_overlay()

	_ajustar_layout()
	_atualizar_hud()
	_set_status("")

	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

	_resetar_spawn_timer()
	_iniciar_musica_pirate_em_loop()




func _exit_tree() -> void:
	_parar_musica_pirate()
	_parar_musica_fim()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)



func _modal_ativo() -> bool:
	return encerrado or ranking_nome_ativo



func _aplicar_sensibilidade_global() -> void:
	if get_tree().has_meta(META_SENS_XBOX):
		velocidade_mira_xbox = float(
			get_tree().get_meta(META_SENS_XBOX)
		)
	else:
		velocidade_mira_xbox = 1500.0   # ← fallback = "100%" do menu

	if get_tree().has_meta(META_SENS_MOUSE):
		sensibilidade_mouse = float(
			get_tree().get_meta(META_SENS_MOUSE)
		)

	velocidade_mira_xbox = clampf(
		velocidade_mira_xbox,
		200.0,
		4000.0   # ← antes 2000.0
	)

	sensibilidade_mouse = clampf(
		sensibilidade_mouse,
		0.2,
		3.0
	)


func _process(delta: float) -> void:
	tempo_trava_input_arma = max(0.0, tempo_trava_input_arma - delta)
	_atualizar_combo_hits(delta)
	_ocultar_overlays_apagados()

	if ranking_nome_ativo:
		ranking_nome_tempo = max(0.0, ranking_nome_tempo - delta)

		if ranking_nome_timer_label != null:
			ranking_nome_timer_label.text = "SALVA COMO ANONIMO EM %02d" % int(ceil(ranking_nome_tempo))

		if ranking_nome_tempo <= 0.0:
			_confirmar_nome_ranking(true)

	if ranking_nome_ativo:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_HIDDEN:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
			Tela.warp_mouse(alvo_pos)
	else:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_atualizar_mira_hibrida(delta)

	if ranking_nome_ativo:
		var tela_mouse := get_viewport_rect().size
		alvo_pos = Tela.mouse()
		alvo_pos.x = clampf(alvo_pos.x, 0.0, tela_mouse.x)
		alvo_pos.y = clampf(alvo_pos.y, 0.0, tela_mouse.y)

	alvo_anim_t += delta
	pulse_modal_t += delta
	aviso_sem_municao_t += delta

	var modal_ativo: bool = _modal_ativo()

	_atualizar_fx_agua(delta)
	_atualizar_fx_estilhacos(delta)
	_atualizar_fx_moedas(delta)
	_atualizar_fx_explosao_bomba(delta)
	_atualizar_movimento_aguavivas(delta)
	_atualizar_bolhas_dos_objetos(delta)

	fx_redraw_timer -= delta
	if fx_redraw_timer <= 0.0:
		fx_redraw_timer = 1.0 / max(fx_redraw_fps, 1.0)

		if fx_back_overlay != null and (marcas_agua.size() > 0 or fx_agua.size() > 0):
			fx_back_overlay.queue_redraw()

		if fx_front_overlay != null and (
			fx_estilhacos.size() > 0
			or fx_moedas.size() > 0
			or fx_explosao_bomba.size() > 0
		):
			fx_front_overlay.queue_redraw()

	if alvo_overlay != null:
		if ranking_nome_ativo:
			_forcar_mira_sobre_modal_ranking()
		else:
			if alvo_layer != null:
				alvo_layer.layer = 100

			alvo_overlay.visible = not _modo_dificil_sem_mira()

			if alvo_overlay.visible:
				alvo_overlay.queue_redraw()

	if info_inicio_root != null and info_inicio_root.visible and tela_inicio_ativa:
		aviso_footer_t += delta

		if info_inicio_label != null:
			info_inicio_label.modulate.a = 0.48 + abs(sin(aviso_footer_t * 4.8)) * 0.52

	if dano_nevoa_ativo and not modal_ativo:
		dano_nevoa_t += delta * 4.8

	if encerrado:
		if not ranking_nome_ativo:
			_processar_timer_retorno_fim(delta)

		_atualizar_hud()
		return

	if not jogo_ativo:
		_atualizar_hud()
		return

	if partida_iniciada:
		if recarregando:
			reload_tempo_restante = max(0.0, reload_tempo_restante - delta)

			if reload_tempo_restante <= 0.0:
				_finalizar_recarga()

		tempo_restante = max(0.0, tempo_restante - delta)

		if tempo_restante <= 0.0:
			tempo_restante = 0.0
			_atualizar_hud()
			_encerrar_partida()
			return

		spawn_timer -= delta

		if spawn_timer <= 0.0:
			_tentar_spawn_alvo()
			_resetar_spawn_timer()

	_atualizar_dificuldade_progressiva()
	_atualizar_hud()



func _atualizar_mira_hibrida(delta: float) -> void:
	var tela: Vector2 = get_viewport_rect().size

	# Quando o ranking estiver aberto o cursor está em HIDDEN mode.
	# Lemos a posição real para que hover dos botões e mira fiquem alinhados.
	if ranking_nome_ativo:
		alvo_pos = Tela.mouse()
		alvo_pos.x = clampf(alvo_pos.x, 0.0, tela.x)
		alvo_pos.y = clampf(alvo_pos.y, 0.0, tela.y)
		return

	if not xbox_mira_iniciada:
		alvo_pos = tela * 0.5
		mouse_delta_acumulado = Vector2.ZERO
		xbox_mira_iniciada = true

	var tem_xbox: bool = usar_controle_xbox \
		and Input.get_connected_joypads().size() > 0

	var usou_xbox: bool = false

	if tem_xbox:
		var eixo_x: float = Input.get_joy_axis(
			0,
			JOY_AXIS_LEFT_X
		)

		var eixo_y: float = Input.get_joy_axis(
			0,
			JOY_AXIS_LEFT_Y
		)

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




func _obter_texto_combo(hit_count: int) -> String:
	match hit_count:
		2:
			return "DOUBLE HIT"
		3:
			return "TRIPLE HIT"
		4:
			return "QUADRA HIT"
		5:
			return "MEGA COMBO x5"
		6:
			return "MEGA COMBO x6"
		7:
			return "MEGA COMBO x7"
		8:
			return "MEGA COMBO x8"
		_:
			if hit_count >= 9:
				return "INSANO x%d" % hit_count

	return ""


func _mostrar_combo_hits() -> void:
	if combo_label == null:
		return

	var texto: String = _obter_texto_combo(combo_hits_seguidos)
	if texto == "":
		combo_label.visible = false
		return

	combo_label.text = texto
	combo_label.visible = true
	combo_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	combo_label.scale = Vector2.ONE * escala_combo_visual_base

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(
		combo_label,
		"scale",
		Vector2.ONE * (escala_combo_visual_base * 1.10),
		0.10
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tw.tween_property(
		combo_label,
		"scale",
		Vector2.ONE * escala_combo_visual_base,
		0.22
	).set_delay(0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _obter_nivel_dificuldade() -> int:
	if pontos_por_nivel_dificuldade <= 0:
		return 0

	return max(0, int(floor(float(max(pontuacao_total, 0)) / float(pontos_por_nivel_dificuldade))))

func _atualizar_dificuldade_progressiva() -> void:
	var novo_nivel: int = _obter_nivel_dificuldade()
	if novo_nivel == nivel_dificuldade_atual:
		return

	nivel_dificuldade_atual = novo_nivel

	if nivel_dificuldade_atual > 0:
		_set_status("NÍVEL %d" % (nivel_dificuldade_atual + 1))


func _atualizar_combo_hits(delta: float) -> void:
	if combo_timer_restante > 0.0:
		combo_timer_restante = max(0.0, combo_timer_restante - delta)

		if combo_timer_restante <= 0.0:
			combo_hits_seguidos = 0
			if combo_label != null:
				combo_label.visible = false
				combo_label.text = ""


func _registrar_fx_estilhacos(pos: Vector2, tipo: String) -> void:
	var quantidade: int = 24 if tipo == "vaso" else 28

	for i in range(quantidade):
		var ang: float = randf_range(-PI, PI)
		var vel: Vector2 = Vector2.RIGHT.rotated(ang) * randf_range(110.0, 320.0)
		vel.y -= randf_range(80.0, 230.0)

		var cor_base: Color
		var tam_min_x: float
		var tam_max_x: float
		var tam_min_y: float
		var tam_max_y: float

		if tipo == "vaso":
			cor_base = Color(
				randf_range(0.76, 0.95),
				randf_range(0.82, 0.97),
				randf_range(0.90, 1.00),
				1.0
			)
			tam_min_x = 5.0
			tam_max_x = 14.0
			tam_min_y = 3.0
			tam_max_y = 9.0
		else:
			cor_base = Color(
				randf_range(0.38, 0.58),
				randf_range(0.22, 0.37),
				randf_range(0.08, 0.16),
				1.0
			)
			tam_min_x = 6.0
			tam_max_x = 16.0
			tam_min_y = 2.0
			tam_max_y = 7.0

		fx_estilhacos.append({
			"pos": pos + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0)),
			"vel": vel,
			"idade": 0.0,
			"vida": randf_range(0.55, 1.10),
			"rot": randf_range(-180.0, 180.0),
			"rot_vel": randf_range(-720.0, 720.0),
			"tam": Vector2(randf_range(tam_min_x, tam_max_x), randf_range(tam_min_y, tam_max_y)),
			"cor": cor_base,
			"tipo": tipo
		})


func _atualizar_fx_estilhacos(delta: float) -> void:
	for i in range(fx_estilhacos.size() - 1, -1, -1):
		var fx: Dictionary = fx_estilhacos[i]
		fx["idade"] = float(fx.get("idade", 0.0)) + delta
		fx["vel"] = Vector2(fx.get("vel", Vector2.ZERO)) + Vector2(0.0, 420.0) * delta
		fx["pos"] = Vector2(fx.get("pos", Vector2.ZERO)) + Vector2(fx["vel"]) * delta
		fx["vel"] = Vector2(fx["vel"]) * 0.985
		fx["rot"] = float(fx.get("rot", 0.0)) + float(fx.get("rot_vel", 0.0)) * delta
		fx_estilhacos[i] = fx

		if float(fx.get("idade", 0.0)) >= float(fx.get("vida", 1.0)):
			fx_estilhacos.remove_at(i)


func _desenhar_fx_estilhacos() -> void:
	for fx in fx_estilhacos:
		var pos: Vector2 = Vector2(fx["pos"])
		var vida: float = float(fx["vida"])
		var idade: float = float(fx["idade"])
		var rot_deg: float = float(fx["rot"])
		var tam: Vector2 = Vector2(fx["tam"])
		var cor: Color = Color(fx["cor"])

		var t: float = clamp(idade / vida, 0.0, 1.0)
		cor.a = 1.0 - t

		var local_rect := PackedVector2Array([
			Vector2(-tam.x * 0.5, -tam.y * 0.5),
			Vector2(tam.x * 0.5, -tam.y * 0.5),
			Vector2(tam.x * 0.5, tam.y * 0.5),
			Vector2(-tam.x * 0.5, tam.y * 0.5),
		])

		var pts := PackedVector2Array()
		for p in local_rect:
			pts.append(pos + p.rotated(deg_to_rad(rot_deg)))

		draw_colored_polygon(pts, cor)

func _input(event: InputEvent) -> void:
	# ============================================================
	# MOVIMENTO DA MIRA
	# ============================================================
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		mouse_delta_acumulado += motion.relative
		return

	# ============================================================
	# START / ENTER
	# ============================================================
	if event.is_action_pressed("input_start"):
		if ranking_nome_ativo:
			_confirmar_nome_ranking(false)
			return

		if encerrado and not fim_cutscene_ativa:
			_reiniciar_partida()
			return

		if tela_inicio_ativa and not intro_comeco_ativa:
			_iniciar_intro_comeco()
			return

	# ============================================================
	# INPUT MAP — ARMA FÍSICA / ARDUINO / ZERO DELAY
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
	# XBOX — FALLBACK
	# R1 atira / L1 recarrega
	# ============================================================
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton

		if not jb.pressed:
			return

		print("BOTÃO XBOX MAR:", jb.button_index)

		if jb.button_index == xbox_botao_tiro:
			_executar_tiro_arma()
			return

		if jb.button_index == xbox_botao_recarga or jb.button_index == xbox_botao_recarga_extra:
			_executar_recarga_arma()
			return

	# ============================================================
	# MOUSE / ARMA COMO MOUSE — FALLBACK
	# Esquerdo atira / direito recarrega
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

	# ============================================================
	# TOUCH — TABLET / TESTE
	# ============================================================
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		alvo_pos = touch.position

		if touch.pressed:
			if tela_inicio_ativa:
				_iniciar_intro_comeco()
				return

			if jogo_ativo and partida_iniciada and not encerrado:
				_processar_tiro_global(touch.position)
				return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		alvo_pos = drag.position
		return

	# ============================================================
	# TECLADO — FALLBACK
	# R recarrega / ENTER inicia ou reinicia
	# ============================================================
	if event is InputEventKey:
		var ke := event as InputEventKey

		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_R:
				_executar_recarga_arma()
				return

			if ke.keycode == KEY_ENTER:
				if ranking_nome_ativo:
					_confirmar_nome_ranking(false)
					return

				if encerrado and not fim_cutscene_ativa:
					_reiniciar_partida()
					return

				if tela_inicio_ativa and not intro_comeco_ativa:
					_iniciar_intro_comeco()
					return




func _configurar_aviso_inicio() -> void:
	aviso_layer = CanvasLayer.new()
	aviso_layer.name = "AvisoInicioLayer"
	aviso_layer.layer = 60
	add_child(aviso_layer)

	aviso_root = Control.new()
	aviso_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	aviso_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso_layer.add_child(aviso_root)

	aviso_panel = ColorRect.new()
	aviso_panel.color = Color(0.035, 0.045, 0.078, 0.985)
	aviso_root.add_child(aviso_panel)

	var glow_bg := ColorRect.new()
	glow_bg.name = "GlowBg"
	glow_bg.color = Color(0.16, 0.86, 1.0, 0.085)
	aviso_panel.add_child(glow_bg)

	var borda_topo := ColorRect.new()
	borda_topo.name = "BordaTopo"
	borda_topo.color = Color(0.18, 0.88, 1.0, 1.0)
	aviso_panel.add_child(borda_topo)

	var borda_base := ColorRect.new()
	borda_base.name = "BordaBase"
	borda_base.color = Color(1.0, 0.30, 0.24, 0.82)
	aviso_panel.add_child(borda_base)

	var brilho := ColorRect.new()
	brilho.name = "BrilhoInterno"
	brilho.color = Color(1.0, 1.0, 1.0, 0.035)
	aviso_panel.add_child(brilho)

	var sombra_interna := ColorRect.new()
	sombra_interna.name = "SombraInterna"
	sombra_interna.color = Color(0.0, 0.0, 0.0, 0.12)
	aviso_panel.add_child(sombra_interna)

	aviso_titulo = Label.new()
	aviso_titulo.text = "MAR ATLANTE"
	aviso_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(aviso_titulo, "font_size", 50)
	Leve.color(aviso_titulo, "font_color", Color(0.74, 0.93, 1.0, 1.0))
	Leve.color(aviso_titulo, "font_outline_color", Color.BLACK)
	Leve.constant(aviso_titulo, "outline_size", 8)

	if fonte_luckiest != null:
		Leve.font(aviso_titulo, "font", fonte_luckiest)

	aviso_root.add_child(aviso_titulo)

	aviso_subtitulo = Label.new()
	aviso_subtitulo.text = "ACERTE ALVOS, EVITE BOMBAS E ENTRE NO RITMO"
	aviso_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso_subtitulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(aviso_subtitulo, "font_size", 24)
	Leve.color(aviso_subtitulo, "font_color", Color(0.86, 0.96, 1.0, 1.0))
	Leve.color(aviso_subtitulo, "font_outline_color", Color.BLACK)
	Leve.constant(aviso_subtitulo, "outline_size", 4)

	if fonte_luckiest != null:
		Leve.font(aviso_subtitulo, "font", fonte_luckiest)

	aviso_root.add_child(aviso_subtitulo)

	aviso_linha_divisoria = ColorRect.new()
	aviso_linha_divisoria.color = Color(1.0, 1.0, 1.0, 0.10)
	aviso_root.add_child(aviso_linha_divisoria)

	# ========= CARDS =========

	aviso_card_aguaviva = ColorRect.new()
	aviso_card_aguaviva.color = Color(0.07, 0.10, 0.15, 0.98)
	aviso_root.add_child(aviso_card_aguaviva)

	var faixa_aguaviva := ColorRect.new()
	faixa_aguaviva.name = "FaixaTopo"
	faixa_aguaviva.color = Color(0.22, 0.92, 1.0, 0.98)
	aviso_card_aguaviva.add_child(faixa_aguaviva)

	var titulo_aguaviva := Label.new()
	titulo_aguaviva.name = "TituloCard"
	titulo_aguaviva.text = "ÁGUA-VIVA  +20"
	titulo_aguaviva.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_aguaviva.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(titulo_aguaviva, "font_size", 22)
	Leve.color(titulo_aguaviva, "font_color", Color(0.82, 0.96, 1.0, 1.0))
	Leve.color(titulo_aguaviva, "font_outline_color", Color.BLACK)
	Leve.constant(titulo_aguaviva, "outline_size", 4)

	if fonte_luckiest != null:
		Leve.font(titulo_aguaviva, "font", fonte_luckiest)

	aviso_card_aguaviva.add_child(titulo_aguaviva)

	# ======= RODAPÉ / ATIRE =======

	aviso_footer_label = Label.new()
	aviso_footer_label.text = "ATIRE PARA COMEÇAR"
	aviso_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso_footer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(aviso_footer_label, "font_size", 34)

	# FONTE LUCKIEST
	if fonte_luckiest != null:
		Leve.font(aviso_footer_label, 
			"font",
			fonte_luckiest
		)

	# AZUL OCEÂNICO TEMÁTICO
	Leve.color(aviso_footer_label, 
		"font_color",
		Color(0.30, 0.84, 1.0, 1.0)
	)

	# CONTORNO OCEÂNICO ESCURO
	Leve.color(aviso_footer_label, 
		"font_outline_color",
		Color(0.0, 0.08, 0.16, 1.0)
	)

	Leve.constant(aviso_footer_label, 
		"outline_size",
		8
	)

	# NEON OCEÂNICO
	aviso_footer_label.self_modulate = Color(
		0.88, 0.98, 1.0, 1.0
	)

	aviso_root.add_child(aviso_footer_label)

	# PULSAÇÃO SUAVE
	var tw := create_tween()
	tw.set_loops()

	tw.tween_property(
		aviso_footer_label,
		"scale",
		Vector2(1.04, 1.04),
		0.75
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tw.parallel().tween_property(
		aviso_footer_label,
		"modulate:a",
		1.0,
		0.75
	)

	tw.tween_property(
		aviso_footer_label,
		"scale",
		Vector2.ONE,
		0.75
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tw.parallel().tween_property(
		aviso_footer_label,
		"modulate:a",
		0.72,
		0.75
	)

	_configurar_preview_inicio_mar()
	_atualizar_textos_painel_inicio_mar()

	aviso_root.visible = true


func _configurar_preview_inicio_mar() -> void:
	if aviso_preview_aguaviva_root != null:
		for filho in aviso_preview_aguaviva_root.get_children():
			filho.queue_free()

	if aviso_preview_vaso_bau_root != null:
		for filho in aviso_preview_vaso_bau_root.get_children():
			filho.queue_free()

	if aviso_preview_bomba_root != null:
		for filho in aviso_preview_bomba_root.get_children():
			filho.queue_free()

	aviso_preview_aguaviva_a = null
	aviso_preview_aguaviva_b = null
	aviso_preview_vaso = null
	aviso_preview_bau = null
	aviso_preview_bomba = null

	if aguaviva_modelo != null and aviso_preview_aguaviva_root != null:
		aviso_preview_aguaviva_a = aguaviva_modelo.duplicate(
			Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS
		) as Area2D
		aviso_preview_aguaviva_b = aguaviva_modelo.duplicate(
			Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS
		) as Area2D

		if aviso_preview_aguaviva_a != null:
			aviso_preview_aguaviva_root.add_child(aviso_preview_aguaviva_a)
			aviso_preview_aguaviva_a.position = Vector2(104, 102)
			aviso_preview_aguaviva_a.scale = Vector2.ONE * 0.50
			_preparar_preview_alvo(aviso_preview_aguaviva_a, "idle")

		if aviso_preview_aguaviva_b != null:
			aviso_preview_aguaviva_root.add_child(aviso_preview_aguaviva_b)
			aviso_preview_aguaviva_b.position = Vector2(216, 102)
			aviso_preview_aguaviva_b.scale = Vector2.ONE * 0.50
			_preparar_preview_alvo(aviso_preview_aguaviva_b, "idle_a")

	if vaso_modelo != null and aviso_preview_vaso_bau_root != null:
		aviso_preview_vaso = vaso_modelo.duplicate(
			Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS
		) as Area2D

		if aviso_preview_vaso != null:
			aviso_preview_vaso_bau_root.add_child(aviso_preview_vaso)
			aviso_preview_vaso.position = Vector2(96, 112)
			aviso_preview_vaso.scale = Vector2.ONE * 0.42
			_preparar_preview_alvo(aviso_preview_vaso, "idle")

	if bau_modelo != null and aviso_preview_vaso_bau_root != null:
		aviso_preview_bau = bau_modelo.duplicate(
			Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS
		) as Area2D

		if aviso_preview_bau != null:
			aviso_preview_vaso_bau_root.add_child(aviso_preview_bau)
			aviso_preview_bau.position = Vector2(222, 114)
			aviso_preview_bau.scale = Vector2.ONE * 0.54
			_preparar_preview_alvo(aviso_preview_bau, "idle")

	if bomba_modelo != null and aviso_preview_bomba_root != null:
		aviso_preview_bomba = bomba_modelo.duplicate(
			Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS
		) as Area2D

		if aviso_preview_bomba != null:
			aviso_preview_bomba_root.add_child(aviso_preview_bomba)
			aviso_preview_bomba.position = Vector2(160, 112)
			aviso_preview_bomba.scale = Vector2.ONE * 0.48
			_preparar_preview_alvo(aviso_preview_bomba, "idle")


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
	comeco_flash.color = Color(0.0, 0.02, 0.05, 0.42)
	comeco_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	comeco_root.add_child(comeco_flash)

	comeco_titulo = Label.new()
	comeco_titulo.text = "3"
	comeco_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comeco_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(comeco_titulo, "font_size", 138)
	Leve.color(comeco_titulo, "font_color", COR_NEON_MAR_CLARO)
	Leve.color(comeco_titulo, "font_outline_color", Color.BLACK)
	Leve.constant(comeco_titulo, "outline_size", 14)

	if fonte_luckiest != null:
		Leve.font(comeco_titulo, "font", fonte_luckiest)

	comeco_titulo.visible = false
	comeco_root.add_child(comeco_titulo)

	comeco_subtitulo = Label.new()
	comeco_subtitulo.visible = false
	comeco_root.add_child(comeco_subtitulo)



func _iniciar_intro_comeco() -> void:
	if intro_comeco_ativa:
		return

	intro_comeco_ativa = true
	intro_comeco_t = 0.0
	intro_contagem_valor = 3

	_esconder_aviso_inicio()

	if comeco_root != null:
		comeco_root.visible = true

	if comeco_flash != null:
		comeco_flash.visible = true
		comeco_flash.color = Color(0.0, 0.02, 0.05, 0.42)

	if comeco_titulo != null:
		comeco_titulo.visible = true

	call_deferred("_rodar_intro_comeco_async")



func _rodar_intro_comeco_async() -> void:
	var valores := ["3", "2", "1", "COMEÇOU!"]

	for v in valores:
		if not is_inside_tree():
			return

		if comeco_titulo != null:
			comeco_titulo.text = v
			comeco_titulo.visible = true
			comeco_titulo.modulate = Color(1, 1, 1, 0.0)

			if v == "COMEÇOU!":
				Leve.font_size(comeco_titulo, "font_size", 82)
				Leve.color(comeco_titulo, "font_color", Color(0.58, 0.96, 1.0, 1.0))
				comeco_titulo.scale = Vector2.ONE * 0.88
			else:
				Leve.font_size(comeco_titulo, "font_size", 138)
				Leve.color(comeco_titulo, "font_color", COR_NEON_MAR_CLARO)
				comeco_titulo.scale = Vector2.ONE * 0.72

			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(comeco_titulo, "modulate:a", 1.0, 0.12)
			tw.tween_property(comeco_titulo, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(comeco_titulo, "modulate:a", 0.0, 0.18).set_delay(0.58)

		await get_tree().create_timer(0.82).timeout

	partida_iniciada = true
	tela_inicio_ativa = false
	jogo_ativo = true
	tempo_restante = tempo_partida
	intro_comeco_ativa = false

	if comeco_titulo != null:
		comeco_titulo.visible = false
		comeco_titulo.scale = Vector2.ONE

	if comeco_root != null:
		comeco_root.visible = false

	_set_status("COMEÇOU!")
	_atualizar_hud()



func _esconder_aviso_inicio() -> void:
	if info_inicio_root == null or not info_inicio_root.visible:
		return

	var tw := create_tween()
	tw.set_parallel(true)

	tw.tween_property(info_inicio_root, "modulate:a", 0.0, 0.16)

	tw.finished.connect(func() -> void:
		if info_inicio_root != null:
			info_inicio_root.visible = false
			info_inicio_root.modulate.a = 1.0
	)


func _animar_entrada_cenario() -> void:
	if aviso_footer_label != null:
		aviso_footer_label.modulate = Color(1, 1, 1, 1)

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



func _preparar_preview_alvo(alvo: Area2D, animacao_preferida: String) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	alvo.visible = true
	alvo.show()
	alvo.process_mode = Node.PROCESS_MODE_INHERIT
	alvo.monitoring = false
	alvo.monitorable = false
	alvo.input_pickable = false
	alvo.rotation_degrees = 0.0
	alvo.modulate = Color.WHITE

	var anim: AnimatedSprite2D = _obter_animated_do_alvo(alvo)
	if anim == null:
		return

	anim.visible = true
	anim.show()
	anim.process_mode = Node.PROCESS_MODE_INHERIT
	anim.speed_scale = 1.0
	anim.position = Vector2.ZERO
	anim.rotation_degrees = 0.0
	anim.scale = Vector2.ONE
	anim.modulate = Color.WHITE

	if anim.sprite_frames == null:
		return

	var nomes: PackedStringArray = anim.sprite_frames.get_animation_names()
	if nomes.is_empty():
		return

	var escolhida: String = ""

	if animacao_preferida != "" and anim.sprite_frames.has_animation(animacao_preferida):
		escolhida = animacao_preferida
	elif anim.sprite_frames.has_animation("idle"):
		escolhida = "idle"
	elif anim.sprite_frames.has_animation("default"):
		escolhida = "default"
	else:
		escolhida = String(nomes[0])

	anim.play(escolhida)



func _ajustar_layout_combo() -> void:
	if combo_label == null:
		return

	var tela: Vector2 = get_viewport_rect().size
	combo_label.position = Vector2(36.0, tela.y - 58.0)
	combo_label.size = Vector2(460.0, 34.0)



func _validar_cena_base() -> void:
	if background == null:
		push_error("Sprite2D não encontrado em Mar.")
	if alvos_root == null:
		push_error("Nó Alvos não encontrado em Mar.")
	if aguaviva_modelo == null:
		push_warning("Alvos/Aguaviva20 não encontrado em cena. Vou depender de aguaviva20.tscn.")
	if vaso_modelo == null:
		push_error("Alvos/Vaso80 não encontrado ou não é Area2D.")
	if bau_modelo == null:
		push_error("Alvos/Bau100 não encontrado ou não é Area2D.")
	if bomba_modelo == null:
		push_error("Alvos/Bomba não encontrado ou não é Area2D.")

	if vaso_modelo != null and vaso_modelo.get_node_or_null("CollisionShape2D") == null:
		push_warning("Vaso80 está sem CollisionShape2D.")
	if bau_modelo != null and bau_modelo.get_node_or_null("CollisionShape2D") == null:
		push_warning("Bau100 está sem CollisionShape2D.")
	if bomba_modelo != null and bomba_modelo.get_node_or_null("CollisionShape2D") == null:
		push_warning("Bomba está sem CollisionShape2D.")



func _preparar_modelos() -> void:
	if aguaviva_modelo != null:
		aguaviva_modelo.visible = false
		aguaviva_modelo.process_mode = Node.PROCESS_MODE_DISABLED
		aguaviva_modelo.monitoring = false
		aguaviva_modelo.monitorable = false
		aguaviva_modelo.input_pickable = false
		aguaviva_modelo.set_meta("tipo_alvo", "aguaviva")
		aguaviva_modelo.set_meta("pontos_alvo", pontos_aguaviva)
		_ajustar_collision_shape_por_tipo(aguaviva_modelo)

		var anim_agua: AnimatedSprite2D = _obter_animated_do_alvo(aguaviva_modelo)
		if anim_agua != null:
			anim_agua.visible = false
			anim_agua.hide()
			anim_agua.process_mode = Node.PROCESS_MODE_DISABLED
			anim_agua.stop()

	if vaso_modelo != null:
		vaso_modelo.visible = false
		vaso_modelo.process_mode = Node.PROCESS_MODE_DISABLED
		vaso_modelo.monitoring = false
		vaso_modelo.monitorable = false
		vaso_modelo.input_pickable = false
		vaso_modelo.set_meta("tipo_alvo", "vaso")
		vaso_modelo.set_meta("pontos_alvo", pontos_vaso)
		_ajustar_collision_shape_por_tipo(vaso_modelo)

		var anim_vaso: AnimatedSprite2D = _obter_animated_do_alvo(vaso_modelo)
		if anim_vaso != null:
			anim_vaso.visible = false
			anim_vaso.hide()
			anim_vaso.process_mode = Node.PROCESS_MODE_DISABLED
			anim_vaso.stop()

	if bau_modelo != null:
		bau_modelo.visible = false
		bau_modelo.process_mode = Node.PROCESS_MODE_DISABLED
		bau_modelo.monitoring = false
		bau_modelo.monitorable = false
		bau_modelo.input_pickable = false
		bau_modelo.set_meta("tipo_alvo", "bau")
		bau_modelo.set_meta("pontos_alvo", pontos_bau)
		_ajustar_collision_shape_por_tipo(bau_modelo)

		var anim_bau: AnimatedSprite2D = _obter_animated_do_alvo(bau_modelo)
		if anim_bau != null:
			anim_bau.visible = false
			anim_bau.hide()
			anim_bau.process_mode = Node.PROCESS_MODE_DISABLED
			anim_bau.stop()

	if bomba_modelo != null:
		bomba_modelo.visible = false
		bomba_modelo.process_mode = Node.PROCESS_MODE_DISABLED
		bomba_modelo.monitoring = false
		bomba_modelo.monitorable = false
		bomba_modelo.input_pickable = false
		bomba_modelo.set_meta("tipo_alvo", "bomba")
		bomba_modelo.set_meta("pontos_alvo", -pontos_bomba_min)
		bomba_modelo.z_index = Z_INDEX_BOMBA
		_ajustar_collision_shape_por_tipo(bomba_modelo)

		var anim_bomba: AnimatedSprite2D = _obter_animated_do_alvo(bomba_modelo)
		if anim_bomba != null:
			anim_bomba.visible = false
			anim_bomba.hide()
			anim_bomba.process_mode = Node.PROCESS_MODE_DISABLED
			anim_bomba.stop()


func _obter_nomes_animacoes(anim: AnimatedSprite2D) -> PackedStringArray:
	if anim == null or anim.sprite_frames == null:
		return PackedStringArray()
	return anim.sprite_frames.get_animation_names()


func _obter_variante_aguaviva(alvo: Area2D) -> String:
	if alvo == null or not is_instance_valid(alvo):
		return "normal"

	var variante: String = String(alvo.get_meta("aguaviva_variante", "normal")).to_lower()

	if variante == "a":
		return "a"

	return "normal"

func _achar_animacao_idle_aguaviva(anim: AnimatedSprite2D, variante: String = "normal") -> String:
	var nomes := _obter_nomes_animacoes(anim)

	if variante == "a":
		for nome in nomes:
			var n := String(nome).to_lower()
			if n == "idle_a":
				return String(nome)

		for nome in nomes:
			var n := String(nome).to_lower()
			if n.contains("idle_a"):
				return String(nome)

	for nome in nomes:
		var n := String(nome).to_lower()
		if n == "idle":
			return String(nome)

	for nome in nomes:
		var n := String(nome).to_lower()
		if n.contains("idle") and not n.contains("idle_a"):
			return String(nome)

	for nome in nomes:
		var n := String(nome).to_lower()
		if n == "default":
			return String(nome)

	if nomes.size() > 0:
		return String(nomes[0])

	return ""


func _achar_animacao_hit_aguaviva(anim: AnimatedSprite2D, variante: String = "normal") -> String:
	var nomes := _obter_nomes_animacoes(anim)

	if variante == "a":
		for nome in nomes:
			var n := String(nome).to_lower()
			if n == "hit_a":
				return String(nome)

		for nome in nomes:
			var n := String(nome).to_lower()
			if n.contains("hit_a"):
				return String(nome)

	for nome in nomes:
		var n := String(nome).to_lower()
		if n == "hit":
			return String(nome)

	for nome in nomes:
		var n := String(nome).to_lower()
		if n.contains("hit") and not n.contains("hit_a"):
			return String(nome)

	for nome in nomes:
		var n := String(nome).to_lower()
		if n.contains("explode"):
			return String(nome)

	if nomes.size() > 1:
		return String(nomes[1])

	if nomes.size() > 0:
		return String(nomes[0])

	return ""


func _forcar_aguaviva_visivel(alvo: Area2D) -> AnimatedSprite2D:
	if alvo == null or not is_instance_valid(alvo):
		return null

	var anim: AnimatedSprite2D = _obter_animated_do_alvo(alvo)
	if anim == null:
		push_warning("Aguaviva sem AnimatedSprite2D em: " + str(alvo.name))
		return null

	anim.visible = true
	anim.show()
	anim.modulate = Color.WHITE
	anim.self_modulate = Color.WHITE
	anim.process_mode = Node.PROCESS_MODE_INHERIT
	anim.speed_scale = 1.0
	anim.z_index = 50
	anim.centered = true

	return anim

func _forcar_ativacao_recursiva(no: Node) -> void:
	if no == null:
		return

	no.process_mode = Node.PROCESS_MODE_INHERIT

	if no is CanvasItem:
		var item: CanvasItem = no as CanvasItem
		item.visible = true
		item.show()
		item.modulate = Color.WHITE
		item.self_modulate = Color.WHITE

	if no is AnimatedSprite2D:
		var anim_no: AnimatedSprite2D = no as AnimatedSprite2D
		anim_no.process_mode = Node.PROCESS_MODE_INHERIT
		anim_no.visible = true
		anim_no.show()
		anim_no.speed_scale = 1.0

	for filho in no.get_children():
		_forcar_ativacao_recursiva(filho)


func _carregar_audios() -> void:
	if ResourceLoader.exists(som_tiro_path):
		som_tiro_stream = load(som_tiro_path)
	if ResourceLoader.exists(som_vaso_hit_path):
		som_vaso_hit_stream = load(som_vaso_hit_path)
	if ResourceLoader.exists(som_bau_hit_path):
		som_bau_hit_stream = load(som_bau_hit_path)
	if ResourceLoader.exists(som_bomba_hit_path):
		som_bomba_hit_stream = load(som_bomba_hit_path)
	if ResourceLoader.exists(som_bomba_explode_path):
		som_bomba_explode_stream = load(som_bomba_explode_path)
	if ResourceLoader.exists(som_aguaviva_hit_path):
		som_aguaviva_hit_stream = load(som_aguaviva_hit_path)
	if ResourceLoader.exists(som_bomba_xploit_path):
		som_bomba_xploit_stream = load(som_bomba_xploit_path)
	if ResourceLoader.exists(som_recharge_path):
		som_recharge_stream = load(som_recharge_path)
	if ResourceLoader.exists(som_bullet_no_path):
		som_bullet_no_stream = load(som_bullet_no_path)
	if ResourceLoader.exists(som_fim_path):
		som_fim_stream = load(som_fim_path)
	if ResourceLoader.exists(som_pirate_path):
		som_pirate_stream = load(som_pirate_path)


func _iniciar_musica_fim_em_loop() -> void:
	if som_fim_stream == null:
		return

	_parar_musica_pirate()

	if fim_end_music_player == null:
		fim_end_music_player = AudioStreamPlayer.new()
		fim_end_music_player.bus = "Master"
		add_child(fim_end_music_player)

	fim_end_music_player.stream = som_fim_stream
	fim_end_music_player.volume_db = -1.0

	if fim_end_music_player.playing:
		fim_end_music_player.stop()

	fim_end_music_player.play()



func _iniciar_musica_pirate_em_loop() -> void:
	if som_pirate_stream == null:
		return

	if pirate_music_player == null:
		pirate_music_player = AudioStreamPlayer.new()
		pirate_music_player.bus = "Master"
		add_child(pirate_music_player)
		# toca de novo sempre que a faixa terminar (loop infinito)
		pirate_music_player.finished.connect(_on_pirate_music_finished)

	pirate_music_player.stream = som_pirate_stream
	pirate_music_player.volume_db = -1.0

	if pirate_music_player.playing:
		return

	pirate_music_player.play()


func _on_pirate_music_finished() -> void:
	# Não relança se a música do fim assumiu o controle.
	if fim_end_music_player != null and fim_end_music_player.playing:
		return

	if pirate_music_player != null and is_instance_valid(pirate_music_player):
		pirate_music_player.play()



func _parar_musica_pirate() -> void:
	if pirate_music_player != null and pirate_music_player.playing:
		pirate_music_player.stop()



func _parar_musica_fim() -> void:
	if fim_end_music_player != null and fim_end_music_player.playing:
		fim_end_music_player.stop()


func _voltar_para_main_menu() -> void:
	_parar_musica_pirate()
	_parar_musica_fim()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if cena_main_menu_path != "" and ResourceLoader.exists(cena_main_menu_path):
		TransicaoGlobal.trocar_cena(cena_main_menu_path)
	else:
		push_warning("Cena de menu principal não encontrada: " + cena_main_menu_path)


func _atualizar_texto_countdown_fim() -> void:
	if fim_countdown_label == null:
		return

	if ranking_nome_ativo:
		fim_countdown_label.text = "DIGITE SEU NOME PARA SALVAR O RECORDE"
		return

	var tempo_int: int = int(ceil(clamp(fim_retorno_timer, 0.0, tempo_auto_retorno_menu_seg)))
	fim_countdown_label.text = "VOLTANDO AO MENU EM %02d" % tempo_int



func _iniciar_timer_retorno_fim() -> void:
	fim_retorno_timer = tempo_auto_retorno_menu_seg
	_atualizar_texto_countdown_fim()



## Flash e dano cobrem a tela inteira: apagados (alfa 0) ainda custavam três
## camadas de tela cheia por quadro na placa de vídeo. Os tweens mexem na
## cor; aqui eles só aparecem enquanto têm alguma cor.
func _ocultar_overlays_apagados() -> void:
	for ov: ColorRect in [flash_overlay, dano_overlay, dano_vinheta_overlay]:
		if ov == null:
			continue
		var ligado: bool = ov.color.a * ov.modulate.a > 0.002
		if ov.visible != ligado:
			ov.visible = ligado


func _processar_timer_retorno_fim(delta: float) -> void:
	if not encerrado:
		return
	if fim_cutscene_ativa:
		return
	if ranking_nome_ativo:
		return
	if fim_root == null or not fim_root.visible:
		return

	fim_retorno_timer = max(0.0, fim_retorno_timer - delta)
	_atualizar_texto_countdown_fim()

	if fim_retorno_timer <= 0.0:
		_voltar_para_main_menu()


func _tocar_som(
	stream: AudioStream,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0,
	start_position_seconds: float = 0.0
) -> void:
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.bus = "Master"
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	add_child(player)
	player.play(max(0.0, start_position_seconds))

	player.finished.connect(func() -> void:
		if is_instance_valid(player):
			player.queue_free()
	)

func _tocar_som_com_atraso(
	stream: AudioStream,
	atraso: float,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0,
	start_position_seconds: float = 0.0
) -> void:
	if stream == null:
		return

	if atraso <= 0.0:
		_tocar_som(stream, volume_db, pitch_scale, start_position_seconds)
		return

	var timer := get_tree().create_timer(atraso)
	timer.timeout.connect(func() -> void:
		_tocar_som(stream, volume_db, pitch_scale, start_position_seconds)
	)



func _efeito_erro_aquatico(pos_global: Vector2) -> void:
	_set_status("SPLASH!")

	# efeito bem mais leve para a tela rodar lisa
	if splash_erro_leve:
		_registrar_marca_agua(pos_global)

		for i in range(2):
			_registrar_fx_agua(
				pos_global + Vector2(
					randf_range(-8.0, 8.0),
					randf_range(-6.0, 6.0)
				)
			)

		return

	_flash_tela(Color(0.30, 0.72, 1.0, 0.10))

	if not tiro_sem_tremida_no_erro:
		_tremida_rapida(1.0)

	_registrar_marca_agua(pos_global)

	for i in range(3):
		_registrar_fx_agua(
			pos_global + Vector2(
				randf_range(-10.0, 10.0),
				randf_range(-8.0, 8.0)
			)
		)


func _criar_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	hud_layer.layer = 20
	add_child(hud_layer)

	hud_root = Control.new()
	hud_root.name = "HUDRoot"
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.z_index = 0
	hud_layer.add_child(hud_root)

	top_bar = ColorRect.new()
	top_bar.color = Color(0.04, 0.06, 0.10, 0.98)
	top_bar.z_index = 10
	hud_root.add_child(top_bar)

	top_bar_sombra = ColorRect.new()
	top_bar_sombra.color = Color(0.0, 0.0, 0.0, 0.24)
	top_bar_sombra.z_index = 11
	hud_root.add_child(top_bar_sombra)

	top_bar_glow = ColorRect.new()
	top_bar_glow.color = Color(0.18, 0.88, 1.0, 0.10)
	top_bar_glow.z_index = 12
	hud_root.add_child(top_bar_glow)

	top_bar_linha = ColorRect.new()
	top_bar_linha.color = Color(0.20, 0.92, 1.0, 0.82)
	top_bar_linha.z_index = 13
	hud_root.add_child(top_bar_linha)

	timer_panel = Panel.new()
	Leve.stylebox(timer_panel, "panel", _estilo_card_mar())
	timer_panel.z_index = 20
	hud_root.add_child(timer_panel)

	score_panel = Panel.new()
	Leve.stylebox(score_panel, "panel", _estilo_card_mar())
	score_panel.z_index = 20
	hud_root.add_child(score_panel)

	tiros_panel = Panel.new()
	Leve.stylebox(tiros_panel, "panel", _estilo_card_mar())
	tiros_panel.z_index = 20
	hud_root.add_child(tiros_panel)

	# painel antigo removido visualmente
	acertos_panel = Panel.new()
	acertos_panel.visible = false
	acertos_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	acertos_panel.z_index = -100
	hud_root.add_child(acertos_panel)

	status_panel = Panel.new()
	Leve.stylebox(status_panel, "panel", _estilo_card_mar())
	status_panel.z_index = 20
	hud_root.add_child(status_panel)

	flash_overlay = ColorRect.new()
	flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_overlay.color = Color(1, 1, 1, 0.0)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_overlay.z_index = 90
	hud_root.add_child(flash_overlay)

	dano_overlay = ColorRect.new()
	dano_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	dano_overlay.color = Color(0.85, 0.05, 0.03, 0.0)
	dano_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dano_overlay.z_index = 91
	hud_root.add_child(dano_overlay)

	dano_vinheta_overlay = ColorRect.new()
	dano_vinheta_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	dano_vinheta_overlay.color = Color(0.20, 0.00, 0.00, 0.0)
	dano_vinheta_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dano_vinheta_overlay.z_index = 92
	hud_root.add_child(dano_vinheta_overlay)
	
	bombas_restantes_label = Label.new()
	bombas_restantes_label.text = "BOMBAS"
	bombas_restantes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bombas_restantes_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(bombas_restantes_label, "font_size", 20)
	Leve.color(bombas_restantes_label, "font_color", Color(1.0, 0.82, 0.28, 1.0))
	Leve.color(bombas_restantes_label, "font_outline_color", Color.BLACK)
	Leve.constant(bombas_restantes_label, "outline_size", 4)
	bombas_restantes_label.z_index = 45
	hud_root.add_child(bombas_restantes_label)

	_criar_icones_bombas_hud()

	timer_title_label = _criar_label("TEMPO", 20, Color(0.90, 0.97, 1.0, 1.0), 4)
	timer_title_label.z_index = 40
	hud_root.add_child(timer_title_label)

	timer_label = _criar_label("02:00", 42, COR_TIMER_NORMAL, 7)
	timer_label.z_index = 40
	hud_root.add_child(timer_label)

	score_title_label = _criar_label("PONTUAÇÃO", 22, Color(1.0, 0.93, 0.32, 1.0), 4)
	score_title_label.z_index = 40
	hud_root.add_child(score_title_label)

	score_label = _criar_label("0", 58, Color(1.0, 0.93, 0.25, 1.0), 7)
	score_label.z_index = 40
	hud_root.add_child(score_label)

	tiros_title_label = _criar_label("MUNIÇÃO", 18, Color(0.92, 0.97, 1.0, 1.0), 4)
	tiros_title_label.z_index = 40
	hud_root.add_child(tiros_title_label)

	tiros_label = _criar_label("", 18, Color(1.0, 0.97, 0.84, 1.0), 4)
	tiros_label.z_index = 40
	hud_root.add_child(tiros_label)

	municao_title_label = _criar_label("STATUS", 18, Color(0.72, 0.90, 1.0, 1.0), 4)
	municao_title_label.z_index = 40
	hud_root.add_child(municao_title_label)

	municao_label = _criar_label("PRONTO", 18, Color(0.84, 1.0, 0.92, 1.0), 4)
	municao_label.z_index = 40
	hud_root.add_child(municao_label)

	recarga_info_label = _criar_label("BOTÃO DIREITO RECARREGA", 16, Color(0.76, 0.88, 1.0, 0.95), 4)
	recarga_info_label.z_index = 40
	hud_root.add_child(recarga_info_label)

	acertos_title_label = _criar_label("ACERTOS", 18, Color(0.32, 0.92, 1.0, 1.0), 4)
	acertos_title_label.z_index = 40
	hud_root.add_child(acertos_title_label)

	acertos_label = _criar_label("0", 34, Color.WHITE, 6)
	acertos_label.z_index = 40
	hud_root.add_child(acertos_label)

	tiros_total_title_label = _criar_label("TIROS", 18, Color(1.0, 0.90, 0.32, 1.0), 4)
	tiros_total_title_label.z_index = 40
	hud_root.add_child(tiros_total_title_label)

	tiros_total_label = _criar_label("0", 34, Color.WHITE, 6)
	tiros_total_label.z_index = 40
	hud_root.add_child(tiros_total_label)

	status_label = _criar_label("", 34, Color.WHITE, 5)
	status_label.z_index = 40
	hud_root.add_child(status_label)
	
	_fonte_titulo(timer_title_label, 20, COR_NEON_MAR_CLARO)
	_fonte_valor(timer_label, 42, Color.WHITE)

	_fonte_titulo(score_title_label, 22, COR_NEON_MAR_CLARO)
	_fonte_valor(score_label, 58, Color(0.86, 1.0, 1.0, 1.0))

	_fonte_titulo(tiros_title_label, 18, COR_NEON_MAR_CLARO)
	_fonte_valor(tiros_label, 18, Color.WHITE)

	_fonte_titulo(municao_title_label, 18, COR_NEON_MAR_CLARO)
	_fonte_valor(municao_label, 18, Color.WHITE)

	_fonte_titulo(acertos_title_label, 16, COR_NEON_MAR_CLARO)
	_fonte_valor(acertos_label, 24, Color.WHITE)

	_fonte_titulo(tiros_total_title_label, 16, COR_NEON_MAR_CLARO)
	_fonte_valor(tiros_total_label, 24, Color.WHITE)

	_fonte_valor(recarga_info_label, 15, Color(0.78, 0.94, 1.0, 1.0))
	_fonte_valor(status_label, 34, Color.WHITE)
	_fonte_titulo(bombas_restantes_label, 19, Color(1.0, 0.88, 0.32, 1.0))

	_criar_blocos_municao()

func _criar_icones_bombas_hud() -> void:
	for b in bombas_icones:
		if is_instance_valid(b):
			b.queue_free()

	bombas_icones.clear()

	if hud_root == null or bomba_modelo == null:
		return

	for i in range(bombas_erros_max):
		var inst = bomba_modelo.duplicate(
			Node.DUPLICATE_SIGNALS |
			Node.DUPLICATE_GROUPS |
			Node.DUPLICATE_SCRIPTS
		)

		if not (inst is Area2D):
			if inst != null:
				inst.queue_free()
			continue

		var bomba: Area2D = inst as Area2D
		hud_root.add_child(bomba)

		bomba.visible = true
		bomba.show()
		bomba.z_index = 46
		bomba.scale = Vector2.ONE * 0.39
		bomba.rotation_degrees = 0.0
		bomba.modulate = Color.WHITE
		bomba.process_mode = Node.PROCESS_MODE_INHERIT
		bomba.monitoring = false
		bomba.monitorable = false
		bomba.input_pickable = false

		_preparar_bomba_hud_idle(bomba)

		bombas_icones.append(bomba)

	_atualizar_bombas_hud()



func _preparar_bomba_hud_idle(bomba: Area2D) -> void:
	if bomba == null or not is_instance_valid(bomba):
		return

	for filho in bomba.get_children():
		if filho is CollisionShape2D:
			(filho as CollisionShape2D).disabled = true

	var anim: AnimatedSprite2D = _obter_animated_do_alvo(bomba)
	if anim == null:
		return

	anim.visible = true
	anim.show()
	anim.position = Vector2.ZERO
	anim.rotation_degrees = 0.0
	anim.scale = Vector2.ONE
	anim.modulate = Color.WHITE
	anim.self_modulate = Color.WHITE
	anim.process_mode = Node.PROCESS_MODE_INHERIT
	anim.speed_scale = 1.0

	if anim.sprite_frames != null:
		if anim.sprite_frames.has_animation("idle"):
			anim.play("idle")
		elif anim.sprite_frames.has_animation("default"):
			anim.play("default")



func _criar_blocos_municao() -> void:
	municao_blocos.clear()

	if tiros_panel == null:
		return

	for filho in tiros_panel.get_children():
		if filho is ColorRect and String(filho.name).begins_with("BlocoMunicao_"):
			filho.queue_free()

	for i in range(capacidade_cartucho):
		var bloco := ColorRect.new()
		bloco.name = "BlocoMunicao_%02d" % i
		bloco.color = Color(0.20, 0.24, 0.30, 0.95)
		tiros_panel.add_child(bloco)
		municao_blocos.append(bloco)

func _criar_overlay_alerta_bombas() -> void:
	alerta_bomba_layer = CanvasLayer.new()
	alerta_bomba_layer.name = "AlertaBombaLayer"
	alerta_bomba_layer.layer = 120
	alerta_bomba_layer.visible = false
	add_child(alerta_bomba_layer)

	alerta_bomba_root = Control.new()
	alerta_bomba_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	alerta_bomba_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alerta_bomba_layer.add_child(alerta_bomba_root)

	alerta_bomba_flash = ColorRect.new()
	alerta_bomba_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	alerta_bomba_flash.color = Color(0.65, 0.02, 0.02, 0.0)
	alerta_bomba_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alerta_bomba_root.add_child(alerta_bomba_flash)

	alerta_bomba_panel = Panel.new()
	alerta_bomba_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.10, 0.012, 0.015, 0.985)
	estilo.border_color = Color(1.0, 0.16, 0.12, 1.0)
	estilo.border_width_left = 5
	estilo.border_width_top = 5
	estilo.border_width_right = 5
	estilo.border_width_bottom = 5
	estilo.corner_radius_top_left = 30
	estilo.corner_radius_top_right = 30
	estilo.corner_radius_bottom_left = 30
	estilo.corner_radius_bottom_right = 30
	estilo.shadow_color = Color(1.0, 0.05, 0.03, 0.60)
	estilo.shadow_size = 40
	estilo.shadow_offset = Vector2.ZERO
	Leve.stylebox(alerta_bomba_panel, "panel", estilo)
	alerta_bomba_root.add_child(alerta_bomba_panel)

	var linha_topo := ColorRect.new()
	linha_topo.name = "AlertaLinhaTopo"
	linha_topo.color = Color(1.0, 0.22, 0.16, 1.0)
	alerta_bomba_panel.add_child(linha_topo)

	var linha_base := ColorRect.new()
	linha_base.name = "AlertaLinhaBase"
	linha_base.color = Color(0.22, 0.92, 1.0, 0.85)
	alerta_bomba_panel.add_child(linha_base)

	alerta_bomba_titulo = _criar_label("VOCÊ EXPLODIU!", 76, Color(1.0, 0.88, 0.86, 1.0), 12)
	_fonte_valor(alerta_bomba_titulo, 76, Color(1.0, 0.88, 0.86, 1.0))
	alerta_bomba_panel.add_child(alerta_bomba_titulo)

	alerta_bomba_subtitulo = _criar_label("3 BOMBAS ATINGIDAS — FIM DE JOGO", 30, Color(1.0, 0.66, 0.34, 1.0), 7)
	_fonte_titulo(alerta_bomba_subtitulo, 30, Color(1.0, 0.66, 0.34, 1.0))
	alerta_bomba_panel.add_child(alerta_bomba_subtitulo)

	call_deferred("_posicionar_alerta_bombas")


func _posicionar_alerta_bombas() -> void:
	if alerta_bomba_root == null or alerta_bomba_panel == null:
		return

	var tela: Vector2 = get_viewport_rect().size

	alerta_bomba_root.position = Vector2.ZERO
	alerta_bomba_root.size = tela

	if alerta_bomba_flash != null:
		alerta_bomba_flash.position = Vector2.ZERO
		alerta_bomba_flash.size = tela

	var painel_w: float = min(900.0, tela.x - 80.0)
	var painel_h: float = 300.0

	alerta_bomba_panel.position = Vector2(
		(tela.x - painel_w) * 0.5,
		(tela.y - painel_h) * 0.5
	).round()
	alerta_bomba_panel.size = Vector2(painel_w, painel_h)

	var linha_topo := alerta_bomba_panel.get_node_or_null("AlertaLinhaTopo") as ColorRect
	if linha_topo != null:
		linha_topo.position = Vector2.ZERO
		linha_topo.size = Vector2(painel_w, 6.0)

	var linha_base := alerta_bomba_panel.get_node_or_null("AlertaLinhaBase") as ColorRect
	if linha_base != null:
		linha_base.position = Vector2(0.0, painel_h - 6.0)
		linha_base.size = Vector2(painel_w, 6.0)

	if alerta_bomba_titulo != null:
		alerta_bomba_titulo.position = Vector2(30.0, 70.0)
		alerta_bomba_titulo.size = Vector2(painel_w - 60.0, 110.0)

	if alerta_bomba_subtitulo != null:
		alerta_bomba_subtitulo.position = Vector2(30.0, 196.0)
		alerta_bomba_subtitulo.size = Vector2(painel_w - 60.0, 50.0)


func _mostrar_alerta_3_bombas() -> void:
	if alerta_bomba_layer == null:
		_criar_overlay_alerta_bombas()

	_posicionar_alerta_bombas()
	alerta_bomba_layer.visible = true

	if alerta_bomba_root != null:
		alerta_bomba_root.modulate = Color(1, 1, 1, 1)

	if alerta_bomba_flash != null:
		alerta_bomba_flash.color = Color(0.65, 0.02, 0.02, 0.0)

	if alerta_bomba_panel != null:
		alerta_bomba_panel.pivot_offset = alerta_bomba_panel.size * 0.5
		alerta_bomba_panel.modulate = Color(1, 1, 1, 0.0)
		alerta_bomba_panel.scale = Vector2(0.70, 0.70)

	if alerta_bomba_titulo != null:
		alerta_bomba_titulo.pivot_offset = alerta_bomba_titulo.size * 0.5
		alerta_bomba_titulo.modulate = Color(1, 1, 1, 0.0)
		alerta_bomba_titulo.scale = Vector2.ONE

	if alerta_bomba_subtitulo != null:
		alerta_bomba_subtitulo.modulate = Color(1, 1, 1, 0.0)

	_tremida_rapida(16.0, 9, 0.020)

	var tw := create_tween()
	tw.set_parallel(true)

	if alerta_bomba_flash != null:
		tw.tween_property(alerta_bomba_flash, "color:a", 0.55, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(alerta_bomba_flash, "color:a", 0.0, 0.55).set_delay(0.06)

	if alerta_bomba_panel != null:
		tw.tween_property(alerta_bomba_panel, "modulate:a", 1.0, 0.18)
		tw.tween_property(alerta_bomba_panel, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if alerta_bomba_titulo != null:
		tw.tween_property(alerta_bomba_titulo, "modulate:a", 1.0, 0.22).set_delay(0.08)

	if alerta_bomba_subtitulo != null:
		tw.tween_property(alerta_bomba_subtitulo, "modulate:a", 1.0, 0.26).set_delay(0.16)

	if alerta_bomba_tw_pulse != null and alerta_bomba_tw_pulse.is_valid():
		alerta_bomba_tw_pulse.kill()

	if alerta_bomba_titulo != null:
		alerta_bomba_tw_pulse = create_tween()
		alerta_bomba_tw_pulse.set_loops()
		alerta_bomba_tw_pulse.tween_property(alerta_bomba_titulo, "scale", Vector2(1.05, 1.05), 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		alerta_bomba_tw_pulse.tween_property(alerta_bomba_titulo, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _esconder_alerta_3_bombas() -> void:
	if alerta_bomba_tw_pulse != null and alerta_bomba_tw_pulse.is_valid():
		alerta_bomba_tw_pulse.kill()
	alerta_bomba_tw_pulse = null

	if alerta_bomba_layer == null:
		return

	if alerta_bomba_root == null:
		alerta_bomba_layer.visible = false
		return

	var tw := create_tween()
	tw.tween_property(alerta_bomba_root, "modulate:a", 0.0, 0.22)
	tw.finished.connect(func() -> void:
		if alerta_bomba_layer != null:
			alerta_bomba_layer.visible = false
		if alerta_bomba_root != null:
			alerta_bomba_root.modulate.a = 1.0
	)



func _atualizar_barra_municao() -> void:
	if tiros_panel == null or municao_blocos.is_empty():
		return

	var margem_x: float = 14.0
	var margem_topo: float = 44.0
	var largura_util: float = tiros_panel.size.x - (margem_x * 2.0)
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
			var pulso: float = 0.58 + (sin(aviso_sem_municao_t * 10.0 + float(i) * 0.18) * 0.5 + 0.5) * 0.42
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



func _criar_hud_combo() -> void:
	combo_layer = CanvasLayer.new()
	combo_layer.name = "ComboLayer"
	combo_layer.layer = 45
	add_child(combo_layer)

	combo_label = Label.new()
	combo_label.visible = false
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(combo_label, "font_size", 30)
	Leve.color(combo_label, "font_color", Color(1.0, 0.92, 0.30, 1.0))
	Leve.color(combo_label, "font_outline_color", Color.BLACK)
	Leve.constant(combo_label, "outline_size", 6)
	combo_layer.add_child(combo_label)

	_ajustar_layout_combo()


func _efeito_dano_bomba() -> void:
	if _modal_ativo():
		return

	if dano_overlay == null:
		return

	dano_overlay.color = Color(0.82, 0.04, 0.03, intensidade_dano_bomba)
	dano_overlay.modulate.a = 1.0

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(dano_overlay, "color:a", intensidade_dano_bomba, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(dano_overlay, "color:a", 0.0, duracao_dano_bomba).set_delay(0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)



func _registrar_fx_explosao_bomba(pos: Vector2) -> void:
	for i in range(42):
		var ang := randf_range(-PI, PI)
		var vel := Vector2.RIGHT.rotated(ang) * randf_range(140.0, 520.0)
		vel.y -= randf_range(40.0, 260.0)

		fx_explosao_bomba.append({
			"pos": pos + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0)),
			"vel": vel,
			"idade": 0.0,
			"vida": randf_range(0.35, 0.95),
			"raio": randf_range(6.0, 18.0),
			"rot": randf_range(-180.0, 180.0),
			"rot_vel": randf_range(-980.0, 980.0),
			"cor": Color(
				randf_range(0.95, 1.0),
				randf_range(0.30, 0.72),
				randf_range(0.02, 0.16),
				1.0
			)
		})

	for i in range(24):
		var ang_fumaca := randf_range(-PI, PI)
		var vel_fumaca := Vector2.RIGHT.rotated(ang_fumaca) * randf_range(50.0, 180.0)

		fx_explosao_bomba.append({
			"pos": pos + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0)),
			"vel": vel_fumaca,
			"idade": 0.0,
			"vida": randf_range(0.70, 1.35),
			"raio": randf_range(14.0, 28.0),
			"rot": 0.0,
			"rot_vel": 0.0,
			"cor": Color(
				randf_range(0.14, 0.24),
				randf_range(0.10, 0.16),
				randf_range(0.10, 0.16),
				0.92
			)
		})

func _desenhar_fx_explosao_bomba() -> void:
	for fx in fx_explosao_bomba:
		var pos: Vector2 = Vector2(fx["pos"])
		var idade: float = float(fx["idade"])
		var vida: float = float(fx["vida"])
		var raio: float = float(fx["raio"])
		var rot_deg: float = float(fx["rot"])
		var cor: Color = Color(fx["cor"])

		var t: float = clamp(idade / vida, 0.0, 1.0)
		cor.a *= (1.0 - t)

		if cor.r > 0.7:
			var largura: float = max(raio * 0.40, 2.0)
			var pts := PackedVector2Array([
				Vector2(-largura, -raio),
				Vector2(largura, -raio * 0.30),
				Vector2(largura * 0.65, raio),
				Vector2(-largura * 0.65, raio * 0.45)
			])

			var out := PackedVector2Array()
			for p in pts:
				out.append(pos + p.rotated(deg_to_rad(rot_deg)))

			draw_colored_polygon(out, cor)
		else:
			draw_circle(pos, raio * (0.75 + t * 0.40), cor)


func _efeito_dano_bomba_forte() -> void:
	if _modal_ativo():
		return

	if dano_overlay == null:
		return

	dano_nevoa_ativo = true
	dano_nevoa_t = 0.0

	dano_overlay.color = Color(0.86, 0.02, 0.02, intensidade_dano_bomba)
	dano_vinheta_overlay.color = Color(0.22, 0.00, 0.00, min(0.36, intensidade_dano_bomba * 0.90))

	var tw := create_tween()
	tw.set_parallel(true)

	tw.tween_property(dano_overlay, "color:a", intensidade_dano_bomba, 0.03).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(dano_overlay, "color:a", 0.0, duracao_dano_bomba).set_delay(0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tw.tween_property(dano_vinheta_overlay, "color:a", 0.28, 0.04).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(dano_vinheta_overlay, "color:a", 0.0, duracao_dano_bomba + 0.18).set_delay(0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tw.finished.connect(func() -> void:
		dano_nevoa_ativo = false
	)

func _desenhar_marcas_agua_back() -> void:
	if fx_back_overlay == null:
		return

	for marca in marcas_agua:
		var pos: Vector2 = Vector2(marca.get("pos", Vector2.ZERO))
		var idade: float = float(marca.get("idade", 0.0))
		var vida: float = max(0.001, float(marca.get("vida", 1.0)))

		var t: float = clamp(idade / vida, 0.0, 1.0)
		var fade: float = 1.0 - t

		var r1: float = lerp(16.0, 48.0, t)
		var r2: float = lerp(8.0, 24.0, t)

		Pincel.anel(fx_back_overlay, pos, r1, 1.8, Color(0.74, 0.94, 1.0, 0.20 * fade))
		Pincel.anel(fx_back_overlay, pos, r2, 1.2, Color(0.88, 0.98, 1.0, 0.12 * fade))


func _desenhar_fx_estilhacos_front() -> void:
	if fx_front_overlay == null:
		return

	for fx in fx_estilhacos:
		var pos: Vector2 = Vector2(fx.get("pos", Vector2.ZERO))
		var vida: float = max(0.001, float(fx.get("vida", 1.0)))
		var idade: float = float(fx.get("idade", 0.0))
		var rot_deg: float = float(fx.get("rot", 0.0))
		var tam: Vector2 = Vector2(fx.get("tam", Vector2(8.0, 4.0)))
		var cor: Color = Color(fx.get("cor", Color.WHITE))

		var t: float = clamp(idade / vida, 0.0, 1.0)
		cor.a = 1.0 - t

		Pincel.lasca(fx_front_overlay, pos, tam * 0.6, deg_to_rad(rot_deg), cor)


func _desenhar_fx_moedas_front() -> void:
	if fx_front_overlay == null:
		return

	for fx in fx_moedas:
		var pos: Vector2 = Vector2(fx.get("pos", Vector2.ZERO))
		var idade: float = float(fx.get("idade", 0.0))
		var vida: float = max(0.001, float(fx.get("vida", 1.0)))
		var rot: float = float(fx.get("rot", 0.0))
		var raio: float = float(fx.get("raio", 8.0))

		var t: float = clamp(idade / vida, 0.0, 1.0)
		var fade: float = 1.0 - t

		# Moeda girando no ar: achata na largura conforme vira.
		var giro: float = absf(cos(deg_to_rad(rot) * 1.7))
		Pincel.forma(fx_front_overlay, Pincel.MOEDA, pos, raio, Color(1, 1, 1, 0.96 * fade), 0.0, Vector2(maxf(0.18, giro), 1.0))


func _desenhar_fx_explosao_bomba_front() -> void:
	if fx_front_overlay == null:
		return

	for fx in fx_explosao_bomba:
		var pos: Vector2 = Vector2(fx.get("pos", Vector2.ZERO))
		var idade: float = float(fx.get("idade", 0.0))
		var vida: float = max(0.001, float(fx.get("vida", 1.0)))
		var raio: float = float(fx.get("raio", 10.0))
		var rot_deg: float = float(fx.get("rot", 0.0))
		var cor: Color = Color(fx.get("cor", Color(1, 0.5, 0.2, 1)))

		var t: float = clamp(idade / vida, 0.0, 1.0)
		cor.a *= (1.0 - t)

		if cor.r > 0.7:
			# fagulha quente
			Pincel.lasca(fx_front_overlay, pos, Vector2(max(raio * 0.40, 2.0), raio), deg_to_rad(rot_deg), cor)
		else:
			# fumaça escura que cresce
			Pincel.forma(fx_front_overlay, Pincel.FUMACA, pos, raio * (1.0 + t * 0.6), cor, deg_to_rad(rot_deg))


func _desenhar_fx_agua_back() -> void:
	if fx_back_overlay == null:
		return

	for fx in fx_agua:
		var pos: Vector2 = Vector2(fx.get("pos", Vector2.ZERO))
		var vida: float = max(0.001, float(fx.get("vida", 1.0)))
		var idade: float = float(fx.get("idade", 0.0))
		var tam: float = float(fx.get("tam", 6.0))

		var t: float = clamp(idade / vida, 0.0, 1.0)
		var fade: float = 1.0 - t
		var raio: float = tam * (1.0 + t * 0.18)

		# Bolha com borda e reflexo (uma forma só da textura do Pincel).
		Pincel.forma(fx_back_overlay, Pincel.BOLHA, pos, raio, Color(0.82, 0.96, 1.0, 0.75 * fade))


func _criar_modal_fim() -> void:
	fim_layer = CanvasLayer.new()
	fim_layer.name = "FimLayer"
	fim_layer.layer = 70
	add_child(fim_layer)

	fim_root = Control.new()
	fim_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	fim_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fim_root.visible = false
	fim_layer.add_child(fim_root)

	fim_bg = ColorRect.new()
	fim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	fim_bg.color = Color(0.0, 0.01, 0.025, 0.86)
	fim_root.add_child(fim_bg)

	# =========================
	# CUTSCENE FIM DE JOGO
	# =========================
	fim_cutscene_panel = Panel.new()
	fim_cutscene_panel.name = "FimCutscenePanel"
	fim_cutscene_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Leve.stylebox(fim_cutscene_panel, "panel", _estilo_modal_neon_mar())
	fim_root.add_child(fim_cutscene_panel)

	var cut_glow := ColorRect.new()
	cut_glow.name = "CutGlow"
	cut_glow.color = Color(0.18, 0.88, 1.0, 0.12)
	fim_cutscene_panel.add_child(cut_glow)

	var cut_linha_top := ColorRect.new()
	cut_linha_top.name = "CutLinhaTop"
	cut_linha_top.color = Color(0.22, 0.92, 1.0, 1.0)
	fim_cutscene_panel.add_child(cut_linha_top)

	var cut_linha_base := ColorRect.new()
	cut_linha_base.name = "CutLinhaBase"
	cut_linha_base.color = Color(0.22, 0.92, 1.0, 0.65)
	fim_cutscene_panel.add_child(cut_linha_base)

	fim_cutscene_titulo = _criar_label("FIM DE JOGO", 72, Color(0.82, 0.98, 1.0, 1.0), 10)
	_fonte_valor(fim_cutscene_titulo, 72, Color(0.82, 0.98, 1.0, 1.0))
	fim_root.add_child(fim_cutscene_titulo)

	fim_cutscene_loading = _criar_label("PROCESSANDO RESULTADOS...", 28, Color(0.70, 0.93, 1.0, 1.0), 5)
	_fonte_titulo(fim_cutscene_loading, 28, Color(0.70, 0.93, 1.0, 1.0))
	fim_root.add_child(fim_cutscene_loading)

	fim_cutscene_barra_bg = ColorRect.new()
	fim_cutscene_barra_bg.color = Color(0.04, 0.08, 0.13, 0.98)
	fim_root.add_child(fim_cutscene_barra_bg)

	fim_cutscene_barra_fill = ColorRect.new()
	fim_cutscene_barra_fill.color = Color(0.22, 0.92, 1.0, 1.0)
	fim_root.add_child(fim_cutscene_barra_fill)

	# =========================
	# MODAL RESULTADO FINAL
	# =========================
# =========================
	# MODAL RESULTADO FINAL (neon azul)
	# =========================
	fim_panel = Panel.new()
	fim_panel.name = "FimPanel"
	fim_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Leve.stylebox(fim_panel, "panel", _estilo_modal_neon_mar())
	fim_root.add_child(fim_panel)

	var brilho_fundo := ColorRect.new()
	brilho_fundo.name = "FimGlow"
	brilho_fundo.color = Color(0.10, 0.74, 1.0, 0.07)
	brilho_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fim_panel.add_child(brilho_fundo)

	var topo := Panel.new()
	topo.name = "FimTopo"
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Leve.stylebox(topo, "panel", _estilo_faixa_topo_mar())
	fim_panel.add_child(topo)

	var linha_topo := ColorRect.new()
	linha_topo.name = "FimLinhaTopo"
	linha_topo.color = Color(0.22, 0.92, 1.0, 1.0)
	fim_panel.add_child(linha_topo)

	var linha_base := ColorRect.new()
	linha_base.name = "FimLinhaBase"
	linha_base.color = Color(0.22, 0.92, 1.0, 0.80)
	fim_panel.add_child(linha_base)

	var faixa_score := Panel.new()
	faixa_score.name = "FimFaixaScore"
	faixa_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Leve.stylebox(faixa_score, "panel", _estilo_faixa_interna_mar(Color(0.04, 0.12, 0.19, 0.96)))
	fim_panel.add_child(faixa_score)

	var faixa_stats := Panel.new()
	faixa_stats.name = "FimFaixaStats"
	faixa_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Leve.stylebox(faixa_stats, "panel", _estilo_faixa_interna_mar(Color(0.02, 0.06, 0.11, 0.96)))
	fim_panel.add_child(faixa_stats)

	var linha_stats := ColorRect.new()
	linha_stats.name = "FimLinhaStats"
	linha_stats.color = Color(0.22, 0.92, 1.0, 0.40)
	fim_panel.add_child(linha_stats)

	fim_title = _criar_label("RESULTADO FINAL", 58, Color(0.80, 0.97, 1.0, 1.0), 9)
	_fonte_valor(fim_title, 58, Color(0.80, 0.97, 1.0, 1.0))
	fim_panel.add_child(fim_title)

	fim_score = _criar_label("PONTUAÇÃO\n0", 48, Color(1.0, 0.92, 0.30, 1.0), 8)
	_fonte_valor(fim_score, 48, Color(1.0, 0.92, 0.30, 1.0))
	fim_panel.add_child(fim_score)

	fim_stats = _criar_label("", 27, Color(0.88, 0.98, 1.0, 1.0), 5)
	fim_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fonte_valor(fim_stats, 27, Color(0.88, 0.98, 1.0, 1.0))
	fim_panel.add_child(fim_stats)

	fim_countdown_label = _criar_label("", 25, Color(0.30, 0.94, 1.0, 1.0), 5)
	_fonte_titulo(fim_countdown_label, 25, Color(0.30, 0.94, 1.0, 1.0))
	fim_panel.add_child(fim_countdown_label)

	fim_hint = _criar_label(Maquina.texto_jogar_novamente(), 26, Color(1.0, 0.90, 0.28, 1.0), 6)
	_fonte_titulo(fim_hint, 26, Color(1.0, 0.90, 0.28, 1.0))
	fim_panel.add_child(fim_hint)

	fim_panel.visible = false
	fim_title.visible = false
	fim_score.visible = false
	fim_stats.visible = false
	fim_hint.visible = false
	fim_countdown_label.visible = false

	fim_cutscene_panel.visible = false
	fim_cutscene_titulo.visible = false
	fim_cutscene_loading.visible = false
	fim_cutscene_barra_bg.visible = false
	fim_cutscene_barra_fill.visible = false
	


func _criar_mira_overlay() -> void:
	alvo_layer = CanvasLayer.new()
	alvo_layer.name = "AlvoLayer"
	alvo_layer.layer = 100
	add_child(alvo_layer)

	alvo_overlay = Control.new()
	alvo_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	alvo_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alvo_overlay.visible = not _modo_dificil_sem_mira()
	alvo_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	alvo_layer.add_child(alvo_overlay)

	if not alvo_overlay.draw.is_connected(_on_alvo_overlay_draw):
		alvo_overlay.draw.connect(_on_alvo_overlay_draw)



func _on_alvo_overlay_draw() -> void:
	_desenhar_mira()



func _draw() -> void:
	pass



func _desenhar_mira() -> void:
	if _modo_dificil_sem_mira() and not ranking_nome_ativo and not tela_inicio_ativa:
		return

	if alvo_overlay == null:
		return

	var pulso: float = 1.0 + sin(alvo_anim_t * 6.0) * 0.08
	var r1: float = 20.0 * pulso
	var r2: float = 9.0 * pulso

	var alpha_mira: float = 1.0
	var ghost_offset := Vector2.ZERO

	if dano_overlay != null:
		alpha_mira = clamp(1.0 - dano_overlay.color.a * 1.95, 0.10, 1.0)

	if dano_nevoa_ativo:
		ghost_offset = Vector2(
			sin(dano_nevoa_t * 1.3) * 4.0,
			cos(dano_nevoa_t * 1.9) * 3.0
		)

	var cor_ext := cor_mira_base
	var cor_int := Color(1.0, 1.0, 1.0, 0.85 * alpha_mira)
	var cor_linha := Color(1.0, 1.0, 1.0, alpha_mira)

	if recarregando:
		var pulso_reload: float = 0.80 + (sin(aviso_sem_municao_t * 12.0) * 0.5 + 0.5) * 0.20
		cor_ext = Color(cor_mira_reload.r, cor_mira_reload.g, cor_mira_reload.b, pulso_reload)
	elif balas_no_cartucho <= 0:
		var pulso_vazio: float = 0.72 + (sin(aviso_sem_municao_t * 14.0) * 0.5 + 0.5) * 0.28
		cor_ext = Color(cor_mira_sem_municao.r, cor_mira_sem_municao.g, cor_mira_sem_municao.b, pulso_vazio)
	elif balas_no_cartucho <= alerta_baixa_municao_limite:
		cor_ext = Color(1.0, 0.68, 0.18, 0.98 * alpha_mira)

	var ov: CanvasItem = alvo_overlay
	Pincel.mira_inicio(ov, alvo_pos)
	Pincel.anel(ov, alvo_pos, r1, 2.6, cor_ext)
	Pincel.anel(ov, alvo_pos, r2, 1.2, cor_int)
	Pincel.circulo(ov, alvo_pos, 2.8, Color(1.0, 1.0, 1.0, 0.96 * alpha_mira))

	Pincel.linha(ov, alvo_pos + Vector2(-26, 0), alvo_pos + Vector2(-8, 0), cor_linha, 2.0)
	Pincel.linha(ov, alvo_pos + Vector2(8, 0), alvo_pos + Vector2(26, 0), cor_linha, 2.0)
	Pincel.linha(ov, alvo_pos + Vector2(0, -26), alvo_pos + Vector2(0, -8), cor_linha, 2.0)
	Pincel.linha(ov, alvo_pos + Vector2(0, 8), alvo_pos + Vector2(0, 26), cor_linha, 2.0)

	if recarregando:
		var progresso: float = 1.0 - clamp(reload_tempo_restante / max(tempo_recarga_seg, 0.001), 0.0, 1.0)
		var inicio_ang: float = -PI * 0.5
		var fim_ang: float = inicio_ang + (TAU * progresso)

		Pincel.anel(ov, alvo_pos, mira_reload_raio, mira_reload_espessura, Color(0.10, 0.20, 0.28, 0.42))
		Pincel.arco(ov, alvo_pos, mira_reload_raio, inicio_ang, fim_ang, Color(0.30, 0.94, 1.0, 1.0), mira_reload_espessura)
		Pincel.arco(ov, alvo_pos, mira_reload_raio + 7.0, inicio_ang, fim_ang, Color(0.82, 0.98, 1.0, 0.55), 2.0)

	elif balas_no_cartucho <= 0:
		var pulso_alerta: float = 0.35 + (sin(aviso_sem_municao_t * 16.0) * 0.5 + 0.5) * 0.35
		Pincel.anel(ov, alvo_pos, mira_reload_raio - 2.0, 4.0, Color(1.0, 0.15, 0.14, pulso_alerta))

	if dano_nevoa_ativo:
		var ghost_alpha: float = 0.22 * max(float(dano_overlay.color.a), float(dano_vinheta_overlay.color.a))
		var ghost_color := Color(1.0, 0.72, 0.72, ghost_alpha)

		Pincel.anel(ov, alvo_pos + ghost_offset, r1 + 1.2, 2.0, ghost_color)
		Pincel.anel(ov, alvo_pos - ghost_offset * 0.7, r2 + 0.8, 1.0, ghost_color)
	Pincel.mira_fim(ov)



func _criar_label(texto: String, tamanho: int, cor: Color, outline: int) -> Label:
	var label: Label = Label.new()
	label.text = texto
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(label, "font_size", tamanho)
	Leve.color(label, "font_color", cor)
	Leve.color(label, "font_outline_color", Color.BLACK)
	Leve.constant(label, "outline_size", outline)
	return label



func _on_viewport_size_changed() -> void:
	call_deferred("_ajustar_layout")



func _ajustar_layout() -> void:
	_ajustar_background_fullscreen()

	var tela: Vector2 = get_viewport_rect().size
	var tela_w: int = int(round(tela.x))
	var tela_h: int = int(round(tela.y))

	var margem_topo: int = 16
	var altura_painel_frente: int = 178
	var altura_fundo_topo: int = 232
	var gap_topo: int = 16

	if hud_root != null:
		hud_root.size = Vector2(tela_w, tela_h)
		hud_root.position = Vector2.ZERO
		hud_root.scale = Vector2.ONE
		hud_root.rotation = 0.0

	if top_bar != null:
		top_bar.position = Vector2(0, 0)
		top_bar.size = Vector2(tela_w, altura_fundo_topo)

	if top_bar_sombra != null:
		top_bar_sombra.position = Vector2(0, altura_fundo_topo)
		top_bar_sombra.size = Vector2(tela_w, 18)

	if top_bar_glow != null:
		top_bar_glow.position = Vector2(0, altura_fundo_topo - 10)
		top_bar_glow.size = Vector2(tela_w, 10)

	if top_bar_linha != null:
		top_bar_linha.position = Vector2(0, altura_fundo_topo - 2)
		top_bar_linha.size = Vector2(tela_w, 2)

	if timer_panel != null:
		timer_panel.position = Vector2(20, margem_topo)
		timer_panel.size = Vector2(236, altura_painel_frente)

	if tiros_panel != null:
		tiros_panel.position = Vector2(tela_w - 420, margem_topo)
		tiros_panel.size = Vector2(236, altura_painel_frente)

	if score_panel != null and timer_panel != null and tiros_panel != null:
		var score_x: int = int(timer_panel.position.x + timer_panel.size.x + gap_topo)
		var score_limite_dir: int = int(tiros_panel.position.x - gap_topo)
		var score_w: int = max(300, score_limite_dir - score_x)

		score_panel.position = Vector2(score_x, margem_topo)
		score_panel.size = Vector2(score_w, altura_painel_frente)

	if acertos_panel != null:
		acertos_panel.visible = false
		acertos_panel.modulate.a = 0.0
		acertos_panel.position = Vector2(-5000, -5000)
		acertos_panel.size = Vector2.ZERO

	if timer_title_label != null and timer_panel != null:
		timer_title_label.position = Vector2(int(timer_panel.position.x), int(timer_panel.position.y + 14))
		timer_title_label.size = Vector2(int(timer_panel.size.x), 26)

	if timer_label != null and timer_panel != null:
		timer_label.position = Vector2(int(timer_panel.position.x), int(timer_panel.position.y + 56))
		timer_label.size = Vector2(int(timer_panel.size.x), 60)

	if score_title_label != null and score_panel != null:
		score_title_label.position = Vector2(int(score_panel.position.x), int(score_panel.position.y + 14))
		score_title_label.size = Vector2(int(score_panel.size.x), 26)

	if score_label != null and score_panel != null:
		score_label.position = Vector2(int(score_panel.position.x + 8), int(score_panel.position.y + 42))
		score_label.size = Vector2(int(score_panel.size.x - 16), 74)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		Leve.font_size(score_label, "font_size", 58)

	if tiros_title_label != null and tiros_panel != null:
		tiros_title_label.position = Vector2(int(tiros_panel.position.x), int(tiros_panel.position.y + 10))
		tiros_title_label.size = Vector2(int(tiros_panel.size.x), 20)

	if tiros_label != null and tiros_panel != null:
		tiros_label.position = Vector2(int(tiros_panel.position.x), int(tiros_panel.position.y + 82))
		tiros_label.size = Vector2(int(tiros_panel.size.x), 18)

	if municao_title_label != null and tiros_panel != null:
		municao_title_label.position = Vector2(int(tiros_panel.position.x), int(tiros_panel.position.y + 124))
		municao_title_label.size = Vector2(int(tiros_panel.size.x), 18)

	if municao_label != null and tiros_panel != null:
		municao_label.position = Vector2(int(tiros_panel.position.x), int(tiros_panel.position.y + 144))
		municao_label.size = Vector2(int(tiros_panel.size.x), 18)

	if recarga_info_label != null and tiros_panel != null:
		recarga_info_label.position = Vector2(int(tiros_panel.position.x), int(tiros_panel.position.y + 162))
		recarga_info_label.size = Vector2(int(tiros_panel.size.x), 16)

	if acertos_title_label != null:
		acertos_title_label.position = Vector2(tela_w - 154, margem_topo + 14)
		acertos_title_label.size = Vector2(130, 22)

	if acertos_label != null:
		acertos_label.position = Vector2(tela_w - 154, margem_topo + 48)
		acertos_label.size = Vector2(130, 42)

	if tiros_total_title_label != null:
		tiros_total_title_label.position = Vector2(tela_w - 154, margem_topo + 92)
		tiros_total_title_label.size = Vector2(130, 18)

	if tiros_total_label != null:
		tiros_total_label.position = Vector2(tela_w - 154, margem_topo + 112)
		tiros_total_label.size = Vector2(130, 28)

	if status_panel != null:
		status_panel.position = Vector2(24.0, tela_h - 102.0)
		status_panel.size = Vector2(tela_w - 48.0, 64.0)

	if status_label != null and status_panel != null:
		status_label.position = status_panel.position + Vector2(0.0, 2.0)
		status_label.size = status_panel.size

	if bombas_restantes_label != null and score_panel != null:
		bombas_restantes_label.position = Vector2(
			int(score_panel.position.x + 28),
			int(score_panel.position.y + 128)
		)
		bombas_restantes_label.size = Vector2(120, 30)

	var bomba_inicio_x: float = 0.0
	var bomba_y: float = 0.0

	if score_panel != null and bombas_restantes_label != null:
		bomba_inicio_x = bombas_restantes_label.position.x + bombas_restantes_label.size.x + 28.0
		bomba_y = bombas_restantes_label.position.y + 15.0

	for i in range(bombas_icones.size()):
		var bomba: Area2D = bombas_icones[i]
		if bomba == null or not is_instance_valid(bomba):
			continue

		bomba.position = Vector2(
			bomba_inicio_x + float(i) * 48.0,
			bomba_y
		)

	if info_inicio_root != null:
		info_inicio_root.size = Vector2(tela_w, tela_h)
		info_inicio_root.position = Vector2.ZERO

	if info_inicio_bg != null:
		info_inicio_bg.position = Vector2.ZERO
		info_inicio_bg.size = Vector2(tela_w, tela_h)

	if info_inicio_image != null:
		info_inicio_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		info_inicio_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

		var area_w: float = float(tela_w) * 0.88
		var area_h: float = float(tela_h) * 0.58

		var tex_size: Vector2 = Vector2(1000.0, 600.0)
		if info_inicio_image.texture != null:
			tex_size = info_inicio_image.texture.get_size()

		var escala: float = min(area_w / tex_size.x, area_h / tex_size.y)
		var final_w: float = tex_size.x * escala
		var final_h: float = tex_size.y * escala

		info_inicio_image.size = Vector2(final_w, final_h)

		info_inicio_image.position = Vector2(
			(float(tela_w) - final_w) * 0.5,
			(float(tela_h) * 0.42) - (final_h * 0.5)
		).round()

		var neon_margem: float = 22.0
		var borda_espessura: float = 5.0

		var glow_img := info_inicio_root.get_node_or_null("GlowImagemInicioMar") as ColorRect
		if glow_img != null:
			glow_img.position = info_inicio_image.position - Vector2(neon_margem, neon_margem)
			glow_img.size = info_inicio_image.size + Vector2(neon_margem * 2.0, neon_margem * 2.0)
			glow_img.color = Color(
				0.0,
				0.65,
				1.0,
				0.16 + abs(sin(aviso_footer_t * 3.0)) * 0.08
			)

		var borda_img := info_inicio_root.get_node_or_null("BordaImagemInicioMar") as ColorRect
		if borda_img != null:
			borda_img.position = info_inicio_image.position - Vector2(borda_espessura, borda_espessura)
			borda_img.size = info_inicio_image.size + Vector2(borda_espessura * 2.0, borda_espessura * 2.0)
			borda_img.color = COR_NEON_MAR

		var fundo_img := info_inicio_root.get_node_or_null("FundoImagemInicioMar") as ColorRect
		if fundo_img != null:
			fundo_img.position = info_inicio_image.position - Vector2(3.0, 3.0)
			fundo_img.size = info_inicio_image.size + Vector2(6.0, 6.0)

	if info_inicio_label != null and info_inicio_image != null:
		info_inicio_label.position = Vector2(
			0.0,
			info_inicio_image.position.y + info_inicio_image.size.y + 46.0
		)
		info_inicio_label.size = Vector2(float(tela_w), 62.0)
		info_inicio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_inicio_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if comeco_titulo != null:
		comeco_titulo.position = Vector2.ZERO
		comeco_titulo.size = Vector2(tela_w, tela_h)
		comeco_titulo.pivot_offset = Vector2(tela_w, tela_h) * 0.5
		comeco_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		comeco_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if comeco_subtitulo != null:
		comeco_subtitulo.position = Vector2(int((tela_w - 400) / 2), int((tela_h * 0.5) + 34))
		comeco_subtitulo.size = Vector2(400, 38)
		comeco_subtitulo.visible = false

	if fim_cutscene_panel != null:
		fim_cutscene_panel.position = Vector2(tela.x * 0.5 - 380.0, tela.y * 0.5 - 150.0)
		fim_cutscene_panel.size = Vector2(760.0, 300.0)

	if fim_cutscene_titulo != null and fim_cutscene_panel != null:
		fim_cutscene_titulo.position = Vector2(fim_cutscene_panel.position.x + 30.0, fim_cutscene_panel.position.y + 34.0)
		fim_cutscene_titulo.size = Vector2(fim_cutscene_panel.size.x - 60.0, 70.0)

	if fim_cutscene_loading != null and fim_cutscene_panel != null:
		fim_cutscene_loading.position = Vector2(fim_cutscene_panel.position.x + 30.0, fim_cutscene_panel.position.y + 138.0)
		fim_cutscene_loading.size = Vector2(fim_cutscene_panel.size.x - 60.0, 34.0)

	if fim_cutscene_barra_bg != null and fim_cutscene_panel != null:
		fim_cutscene_barra_bg.position = Vector2(fim_cutscene_panel.position.x + 74.0, fim_cutscene_panel.position.y + 212.0)
		fim_cutscene_barra_bg.size = Vector2(fim_cutscene_panel.size.x - 148.0, 18.0)

	if fim_cutscene_barra_fill != null and fim_cutscene_barra_bg != null:
		fim_cutscene_barra_fill.position = fim_cutscene_barra_bg.position
		fim_cutscene_barra_fill.size = Vector2(0.0, fim_cutscene_barra_bg.size.y)


	_ajustar_layout_combo()
	_atualizar_barra_municao()
	_posicionar_modal_final_mar()
	_posicionar_alerta_bombas()
	_ajustar_modal_nome_ranking()


func _configurar_modal_nome_ranking() -> void:
	ranking_nome_layer = CanvasLayer.new()
	ranking_nome_layer.name = "RankingNomeLayer"
	ranking_nome_layer.layer = 180
	ranking_nome_layer.visible = false
	add_child(ranking_nome_layer)

	ranking_nome_root = Control.new()
	ranking_nome_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ranking_nome_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ranking_nome_layer.add_child(ranking_nome_root)

	ranking_nome_bg = ColorRect.new()
	ranking_nome_bg.color = Color(0.0, 0.01, 0.025, 0.90)
	ranking_nome_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ranking_nome_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ranking_nome_root.add_child(ranking_nome_bg)

	var glow_bg := ColorRect.new()
	glow_bg.name = "RankingGlowBg"
	glow_bg.color = Color(0.12, 0.76, 1.0, 0.10)
	glow_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ranking_nome_root.add_child(glow_bg)

	ranking_nome_panel = Panel.new()
	ranking_nome_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ranking_nome_root.add_child(ranking_nome_panel)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.010, 0.030, 0.060, 0.985)
	estilo.border_color = Color(0.22, 0.92, 1.0, 1.0)
	estilo.border_width_left = 5
	estilo.border_width_top = 5
	estilo.border_width_right = 5
	estilo.border_width_bottom = 5
	estilo.corner_radius_top_left = 34
	estilo.corner_radius_top_right = 34
	estilo.corner_radius_bottom_left = 34
	estilo.corner_radius_bottom_right = 34
	estilo.shadow_color = Color(0.0, 0.80, 1.0, 0.55)
	estilo.shadow_size = 42
	estilo.shadow_offset = Vector2.ZERO
	Leve.stylebox(ranking_nome_panel, "panel", estilo)

	var topo := ColorRect.new()
	topo.name = "RankingTopoNeon"
	topo.color = Color(0.035, 0.080, 0.140, 0.96)
	ranking_nome_panel.add_child(topo)

	var linha_topo := ColorRect.new()
	linha_topo.name = "RankingLinhaTopo"
	linha_topo.color = Color(0.22, 0.92, 1.0, 1.0)
	ranking_nome_panel.add_child(linha_topo)

	var linha_base := ColorRect.new()
	linha_base.name = "RankingLinhaBase"
	linha_base.color = Color(0.22, 0.92, 1.0, 0.80)
	ranking_nome_panel.add_child(linha_base)

	var display_box := ColorRect.new()
	display_box.name = "RankingDisplayBox"
	display_box.color = Color(0.020, 0.065, 0.110, 0.96)
	ranking_nome_panel.add_child(display_box)

	var display_linha := ColorRect.new()
	display_linha.name = "RankingDisplayLinha"
	display_linha.color = Color(0.22, 0.92, 1.0, 0.70)
	ranking_nome_panel.add_child(display_linha)

	ranking_nome_titulo = Label.new()
	ranking_nome_titulo.text = "NOVO RECORDE!"
	ranking_nome_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranking_nome_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(ranking_nome_titulo, "font_size", 52)
	Leve.color(ranking_nome_titulo, "font_color", Color(0.82, 0.98, 1.0, 1.0))
	Leve.color(ranking_nome_titulo, "font_outline_color", Color(0.0, 0.20, 0.32, 1.0))
	Leve.constant(ranking_nome_titulo, "outline_size", 10)
	_fonte_valor(ranking_nome_titulo, 52, Color(0.82, 0.98, 1.0, 1.0))
	ranking_nome_panel.add_child(ranking_nome_titulo)

	ranking_nome_texto = Label.new()
	ranking_nome_texto.text = "ATIRE NAS LETRAS PARA ESCREVER SEU NOME\nMÁXIMO 9 LETRAS"
	ranking_nome_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranking_nome_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(ranking_nome_texto, "font_size", 24)
	Leve.color(ranking_nome_texto, "font_color", Color(0.78, 0.96, 1.0, 1.0))
	Leve.color(ranking_nome_texto, "font_outline_color", Color.BLACK)
	Leve.constant(ranking_nome_texto, "outline_size", 5)
	_fonte_titulo(ranking_nome_texto, 24, Color(0.78, 0.96, 1.0, 1.0))
	ranking_nome_panel.add_child(ranking_nome_texto)

	ranking_nome_display = Label.new()
	ranking_nome_display.text = "---------"
	ranking_nome_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranking_nome_display.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(ranking_nome_display, "font_size", 58)
	Leve.color(ranking_nome_display, "font_color", Color(1.0, 0.92, 0.28, 1.0))
	Leve.color(ranking_nome_display, "font_outline_color", Color(0.0, 0.12, 0.20, 1.0))
	Leve.constant(ranking_nome_display, "outline_size", 10)
	_fonte_valor(ranking_nome_display, 58, Color(1.0, 0.92, 0.28, 1.0))
	ranking_nome_panel.add_child(ranking_nome_display)

	ranking_nome_teclado = GridContainer.new()
	ranking_nome_teclado.columns = 9
	ranking_nome_teclado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Leve.constant(ranking_nome_teclado, "h_separation", 9)
	Leve.constant(ranking_nome_teclado, "v_separation", 9)
	ranking_nome_panel.add_child(ranking_nome_teclado)

	var letras := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	for i in range(letras.length()):
		var letra := letras.substr(i, 1)
		var btn := _criar_botao_tecla_ranking(letra)
		ranking_nome_teclado.add_child(btn)

	ranking_nome_btn_apagar = _criar_botao_tecla_ranking("APAGAR")
	ranking_nome_panel.add_child(ranking_nome_btn_apagar)

	ranking_nome_btn_ok = _criar_botao_tecla_ranking("SALVAR")
	ranking_nome_panel.add_child(ranking_nome_btn_ok)

	ranking_nome_timer_label = Label.new()
	ranking_nome_timer_label.text = "SALVA COMO ANONIMO EM 50"
	ranking_nome_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranking_nome_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(ranking_nome_timer_label, "font_size", 24)
	Leve.color(ranking_nome_timer_label, "font_color", Color(0.30, 0.94, 1.0, 1.0))
	Leve.color(ranking_nome_timer_label, "font_outline_color", Color.BLACK)
	Leve.constant(ranking_nome_timer_label, "outline_size", 6)
	_fonte_titulo(ranking_nome_timer_label, 24, Color(0.30, 0.94, 1.0, 1.0))
	ranking_nome_panel.add_child(ranking_nome_timer_label)

	call_deferred("_ajustar_modal_nome_ranking")



func _criar_botao_tecla_ranking(texto: String) -> Button:
	var btn := Button.new()
	btn.text = texto
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.disabled = false

	Leve.font_size(btn, "font_size", 24)
	Leve.color(btn, "font_color", Color(0.82, 0.98, 1.0, 1.0))
	Leve.color(btn, "font_hover_color", Color.WHITE)
	Leve.color(btn, "font_pressed_color", Color(0.02, 0.05, 0.08, 1.0))
	Leve.color(btn, "font_outline_color", Color.BLACK)
	Leve.constant(btn, "outline_size", 4)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.080, 0.130, 0.98)
	normal.border_color = Color(0.18, 0.82, 1.0, 0.88)
	normal.border_width_left = 3
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 3
	normal.corner_radius_top_left = 15
	normal.corner_radius_top_right = 15
	normal.corner_radius_bottom_left = 15
	normal.corner_radius_bottom_right = 15
	normal.shadow_color = Color(0.0, 0.78, 1.0, 0.38)
	normal.shadow_size = 18
	normal.shadow_offset = Vector2.ZERO

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.88, 1.0, 0.98)
	hover.border_color = Color(0.82, 0.98, 1.0, 1.0)
	hover.border_width_left = 4
	hover.border_width_top = 4
	hover.border_width_right = 4
	hover.border_width_bottom = 4
	hover.corner_radius_top_left = 15
	hover.corner_radius_top_right = 15
	hover.corner_radius_bottom_left = 15
	hover.corner_radius_bottom_right = 15
	hover.shadow_color = Color(0.0, 0.92, 1.0, 0.75)
	hover.shadow_size = 26
	hover.shadow_offset = Vector2.ZERO

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(1.0, 0.88, 0.24, 1.0)
	pressed.border_color = Color(1.0, 0.98, 0.68, 1.0)
	pressed.border_width_left = 4
	pressed.border_width_top = 4
	pressed.border_width_right = 4
	pressed.border_width_bottom = 4
	pressed.corner_radius_top_left = 15
	pressed.corner_radius_top_right = 15
	pressed.corner_radius_bottom_left = 15
	pressed.corner_radius_bottom_right = 15
	pressed.shadow_color = Color(1.0, 0.80, 0.18, 0.70)
	pressed.shadow_size = 24
	pressed.shadow_offset = Vector2.ZERO

	Leve.stylebox(btn, "normal", normal)
	Leve.stylebox(btn, "hover", hover)
	Leve.stylebox(btn, "pressed", pressed)

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


func _abrir_modal_nome_ranking_mar(pontos: int, precisao: int) -> void:
	ranking_pontos_pendentes = pontos
	ranking_cenario_pendente = "MAR"
	ranking_precisao_pendente = clamp(precisao, 0, 100)
	ranking_nome_tempo = 50.0
	ranking_nome_ativo = true
	ranking_ja_salvo = false
	ranking_nome_digitado = ""
	
	mouse_delta_acumulado = Vector2.ZERO
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# Teleporta o cursor OS para alvo_pos para zerar o offset
	# entre hover dos botões e a mira desenhada.
	var pos_inicial := alvo_pos
	if pos_inicial == Vector2.ZERO:
		pos_inicial = get_viewport_rect().size * 0.5
	Tela.warp_mouse(pos_inicial)

	_forcar_mira_sobre_modal_ranking()

	if ranking_nome_layer != null:
		ranking_nome_layer.visible = true

	if ranking_nome_timer_label != null:
		ranking_nome_timer_label.text = "SALVA COMO ANONIMO EM 50"

	_atualizar_display_nome_ranking()
	_ajustar_modal_nome_ranking()
	_atualizar_texto_countdown_fim()



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

	if ranking_nome_layer != null:
		ranking_nome_layer.visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	if alvo_layer != null:
		alvo_layer.layer = 100

	if alvo_overlay != null:
		alvo_overlay.visible = not _modo_dificil_sem_mira()
		alvo_overlay.queue_redraw()

	if fim_title != null:
		fim_title.text = "RECORDE SALVO!"

	if fim_stats != null:
		fim_stats.text = fim_stats.text.replace(
			"\n\n🏆 NOVO RECORDE! ESCOLHA SEU NOME.",
			""
		)

		fim_stats.text += "\n\nRECORDE SALVO COMO: %s\nACERTO: %d%%" % [
			nome_final,
			ranking_precisao_pendente
		]

	if fim_hint != null:
		fim_hint.text = Maquina.texto_jogar_novamente()

	_iniciar_timer_retorno_fim()
	_atualizar_texto_countdown_fim()
	_posicionar_modal_final_mar()



func _ajustar_modal_nome_ranking() -> void:
	if ranking_nome_root == null or ranking_nome_panel == null:
		return

	var tela: Vector2 = get_viewport_rect().size

	ranking_nome_root.size = tela

	if ranking_nome_bg != null:
		ranking_nome_bg.position = Vector2.ZERO
		ranking_nome_bg.size = tela

	var glow_bg := ranking_nome_root.get_node_or_null("RankingGlowBg") as ColorRect
	if glow_bg != null:
		glow_bg.position = Vector2.ZERO
		glow_bg.size = tela

	var painel_w: float = min(1020.0, tela.x - 64.0)
	var painel_h: float = min(780.0, tela.y - 80.0)

	ranking_nome_panel.position = Vector2(
		(tela.x - painel_w) * 0.5,
		(tela.y - painel_h) * 0.5
	).round()

	ranking_nome_panel.size = Vector2(painel_w, painel_h)

	var topo := ranking_nome_panel.get_node_or_null("RankingTopoNeon") as ColorRect
	if topo != null:
		topo.position = Vector2.ZERO
		topo.size = Vector2(painel_w, 116.0)

	var linha_topo := ranking_nome_panel.get_node_or_null("RankingLinhaTopo") as ColorRect
	if linha_topo != null:
		linha_topo.position = Vector2.ZERO
		linha_topo.size = Vector2(painel_w, 5.0)

	var linha_base := ranking_nome_panel.get_node_or_null("RankingLinhaBase") as ColorRect
	if linha_base != null:
		linha_base.position = Vector2(0.0, painel_h - 5.0)
		linha_base.size = Vector2(painel_w, 5.0)

	var display_box := ranking_nome_panel.get_node_or_null("RankingDisplayBox") as ColorRect
	if display_box != null:
		display_box.position = Vector2(86.0, 158.0)
		display_box.size = Vector2(painel_w - 172.0, 86.0)

	var display_linha := ranking_nome_panel.get_node_or_null("RankingDisplayLinha") as ColorRect
	if display_linha != null:
		display_linha.position = Vector2(86.0, 240.0)
		display_linha.size = Vector2(painel_w - 172.0, 4.0)

	if ranking_nome_titulo != null:
		ranking_nome_titulo.position = Vector2(20.0, 18.0)
		ranking_nome_titulo.size = Vector2(painel_w - 40.0, 64.0)

	if ranking_nome_texto != null:
		ranking_nome_texto.position = Vector2(40.0, 90.0)
		ranking_nome_texto.size = Vector2(painel_w - 80.0, 58.0)

	if ranking_nome_display != null:
		ranking_nome_display.position = Vector2(96.0, 160.0)
		ranking_nome_display.size = Vector2(painel_w - 192.0, 80.0)

	if ranking_nome_teclado != null:
		ranking_nome_teclado.position = Vector2(64.0, 272.0)
		ranking_nome_teclado.size = Vector2(painel_w - 128.0, 280.0)

		for child in ranking_nome_teclado.get_children():
			if child is Button:
				(child as Button).custom_minimum_size = Vector2(86.0, 64.0)

	if ranking_nome_btn_apagar != null:
		ranking_nome_btn_apagar.position = Vector2(150.0, painel_h - 150.0)
		ranking_nome_btn_apagar.size = Vector2(280.0, 66.0)

	if ranking_nome_btn_ok != null:
		ranking_nome_btn_ok.position = Vector2(painel_w - 430.0, painel_h - 150.0)
		ranking_nome_btn_ok.size = Vector2(280.0, 66.0)

	if ranking_nome_timer_label != null:
		ranking_nome_timer_label.position = Vector2(40.0, painel_h - 74.0)
		ranking_nome_timer_label.size = Vector2(painel_w - 80.0, 42.0)


func _atualizar_bombas_hud() -> void:
	if bombas_restantes_label != null:
		var restantes: int = max(0, bombas_erros_max - bombas_erros_atual)
		bombas_restantes_label.text = "BOMBAS  %d/%d" % [restantes, bombas_erros_max]

		if restantes <= 1:
			bombas_restantes_label.modulate = Color(1.0, 0.16, 0.12, 1.0)
		elif restantes == 2:
			bombas_restantes_label.modulate = Color(1.0, 0.62, 0.16, 1.0)
		else:
			bombas_restantes_label.modulate = Color(1.0, 0.86, 0.28, 1.0)

	for i in range(bombas_icones.size()):
		var bomba: Area2D = bombas_icones[i]
		if bomba == null or not is_instance_valid(bomba):
			continue

		if i < bombas_erros_atual:
			bomba.modulate = Color(0.38, 0.38, 0.38, 0.72)
		else:
			bomba.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _ajustar_background_fullscreen() -> void:
	if background == null:
		return

	if background.texture == null and ResourceLoader.exists(caminho_background):
		background.texture = load(caminho_background)

	if background.texture == null:
		return

	var tela: Vector2 = get_viewport_rect().size
	var tex_size: Vector2 = background.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	var escala: float = max(float(tela.x) / float(tex_size.x), float(tela.y) / float(tex_size.y)) * overscan_background
	background.centered = true
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background.position = Vector2(floor(tela.x * 0.5), floor(tela.y * 0.5))
	background.scale = Vector2.ONE * escala
	background.z_index = -100

	# Cachoeiras escorrendo e baleias nadando (origem no canto da textura).
	var vida := background.get_node_or_null("Vida") as Node2D
	if vida == null:
		vida = Node2D.new()
		vida.name = "Vida"
		vida.set_script(load("res://scripts/mar_vida.gd"))
		background.add_child(vida)
	vida.position = -tex_size * 0.5



func _encerrar_partida() -> void:
	jogo_ativo = false
	encerrado = true
	partida_iniciada = false
	fim_cutscene_ativa = true

	_finalizar_alvos_sem_congelar()

	var precisao: int = _calcular_precisao()
	var total_erros: int = max(0, total_tiros - total_acertos)

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

	if fim_score != null:
		fim_score.text = "PONTUAÇÃO\n%d" % pontuacao_total

	if fim_stats != null:
		fim_stats.text = "TIROS: %d     ACERTOS: %d     ERROS: %d\nPRECISÃO: %d%%\nBOMBAS: %d/%d\n\nDESEMPENHO: %s%s" % [
			total_tiros,
			total_acertos,
			total_erros,
			precisao,
			bombas_erros_atual,
			bombas_erros_max,
			aproveitamento,
			texto_ranking
		]

	if fim_hint != null:
		if entrou_ranking:
			fim_hint.text = "ATIRE NAS LETRAS PARA SALVAR O RECORDE"
		else:
			fim_hint.text = Maquina.texto_jogar_novamente()

	if fim_countdown_label != null:
		if entrou_ranking:
			fim_countdown_label.text = "DIGITE SEU NOME PARA SALVAR O RECORDE"
		else:
			fim_countdown_label.text = "VOLTANDO AO MENU EM %02d" % int(ceil(tempo_auto_retorno_menu_seg))

	# NÃO PARA E NÃO REINICIA A MÚSICA AQUI.
	# A pirate.mp3 continua tocando do mesmo ponto.

	_set_status("")
	_iniciar_cutscene_fim()



func _finalizar_alvos_sem_congelar() -> void:
	for alvo in alvos_ativos:
		if alvo == null or not is_instance_valid(alvo):
			continue

		alvo.monitoring = false
		alvo.monitorable = false
		alvo.input_pickable = false

		if alvo.has_meta("tween_queda"):
			var tw = alvo.get_meta("tween_queda")
			if tw != null and tw is Tween:
				(tw as Tween).kill()

		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(alvo, "modulate:a", 0.0, 0.45)
		tween.tween_property(alvo, "scale", alvo.scale * 0.92, 0.45)

		tween.finished.connect(func() -> void:
			_remover_alvo(alvo)
		)




func _iniciar_cutscene_fim() -> void:
	if fim_root == null:
		return

	fim_root.visible = true

	if fim_panel != null:
		fim_panel.visible = false
	if fim_title != null:
		fim_title.visible = false
	if fim_score != null:
		fim_score.visible = false
	if fim_stats != null:
		fim_stats.visible = false
	if fim_hint != null:
		fim_hint.visible = false

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

	var precisao: int = _calcular_precisao()
	var entrou_ranking: bool = bool(ranking_manager.call(
		"deve_entrar_no_ranking",
		pontuacao_total,
		precisao
	))

	if fim_panel != null:
		fim_panel.visible = true
		fim_panel.modulate = Color(1, 1, 1, 0.0)
		fim_panel.scale = Vector2(0.92, 0.92)

	if fim_title != null:
		fim_title.visible = true
		fim_title.modulate = Color(1, 1, 1, 0.0)

	if fim_score != null:
		fim_score.visible = true
		fim_score.modulate = Color(1, 1, 1, 0.0)

	if fim_stats != null:
		fim_stats.visible = true
		fim_stats.modulate = Color(1, 1, 1, 0.0)

	if fim_hint != null:
		fim_hint.visible = true
		fim_hint.modulate = Color(1, 1, 1, 0.0)

	if fim_countdown_label != null:
		fim_countdown_label.visible = true
		fim_countdown_label.modulate = Color(1, 1, 1, 0.0)

	_posicionar_modal_final_mar()

	if entrou_ranking:
		fim_retorno_timer = 9999.0
	else:
		_iniciar_timer_retorno_fim()

	var tw := create_tween()
	tw.set_parallel(true)

	if fim_panel != null:
		tw.tween_property(fim_panel, "modulate:a", 1.0, 0.28)
		tw.tween_property(fim_panel, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if fim_title != null:
		tw.tween_property(fim_title, "modulate:a", 1.0, 0.22)

	if fim_score != null:
		tw.tween_property(fim_score, "modulate:a", 1.0, 0.24).set_delay(0.06)

	if fim_stats != null:
		tw.tween_property(fim_stats, "modulate:a", 1.0, 0.26).set_delay(0.10)

	if fim_hint != null:
		tw.tween_property(fim_hint, "modulate:a", 1.0, 0.28).set_delay(0.14)

	if fim_countdown_label != null:
		tw.tween_property(fim_countdown_label, "modulate:a", 1.0, 0.28).set_delay(0.18)

	if entrou_ranking:
		call_deferred("_abrir_modal_nome_ranking_mar", pontuacao_total, precisao)



func _posicionar_modal_final_mar() -> void:
	var tela: Vector2 = get_viewport_rect().size

	var painel_w: float = min(1040.0, tela.x - 60.0)
	var painel_h: float = min(800.0, tela.y - 70.0)

	var x: float = (tela.x - painel_w) * 0.5
	var y: float = (tela.y - painel_h) * 0.5

	if fim_bg != null:
		fim_bg.position = Vector2.ZERO
		fim_bg.size = tela

	# ---------- CUTSCENE ----------
	if fim_cutscene_panel != null:
		var cut_w: float = min(820.0, tela.x - 80.0)
		var cut_h: float = 330.0
		fim_cutscene_panel.position = Vector2((tela.x - cut_w) * 0.5, (tela.y - cut_h) * 0.5).round()
		fim_cutscene_panel.size = Vector2(cut_w, cut_h)

		var cut_glow := fim_cutscene_panel.get_node_or_null("CutGlow") as ColorRect
		if cut_glow != null:
			cut_glow.position = Vector2(30.0, 30.0)
			cut_glow.size = fim_cutscene_panel.size - Vector2(60.0, 60.0)

		var cut_linha_top := fim_cutscene_panel.get_node_or_null("CutLinhaTop") as ColorRect
		if cut_linha_top != null:
			cut_linha_top.position = Vector2(40.0, 16.0)
			cut_linha_top.size = Vector2(cut_w - 80.0, 3.0)

		var cut_linha_base := fim_cutscene_panel.get_node_or_null("CutLinhaBase") as ColorRect
		if cut_linha_base != null:
			cut_linha_base.position = Vector2(40.0, cut_h - 18.0)
			cut_linha_base.size = Vector2(cut_w - 80.0, 3.0)

	if fim_cutscene_titulo != null and fim_cutscene_panel != null:
		fim_cutscene_titulo.position = fim_cutscene_panel.position + Vector2(30.0, 42.0)
		fim_cutscene_titulo.size = Vector2(fim_cutscene_panel.size.x - 60.0, 80.0)

	if fim_cutscene_loading != null and fim_cutscene_panel != null:
		fim_cutscene_loading.position = fim_cutscene_panel.position + Vector2(30.0, 145.0)
		fim_cutscene_loading.size = Vector2(fim_cutscene_panel.size.x - 60.0, 42.0)

	if fim_cutscene_barra_bg != null and fim_cutscene_panel != null:
		fim_cutscene_barra_bg.position = fim_cutscene_panel.position + Vector2(82.0, 230.0)
		fim_cutscene_barra_bg.size = Vector2(fim_cutscene_panel.size.x - 164.0, 20.0)

	if fim_cutscene_barra_fill != null and fim_cutscene_barra_bg != null:
		fim_cutscene_barra_fill.position = fim_cutscene_barra_bg.position
		fim_cutscene_barra_fill.size.y = fim_cutscene_barra_bg.size.y

	# ---------- MODAL FINAL ----------
	if fim_panel == null:
		return

	fim_panel.position = Vector2(x, y).round()
	fim_panel.size = Vector2(painel_w, painel_h)

	var W: float = painel_w
	var H: float = painel_h
	var m: float = 48.0   # margem interna: mantém a borda neon visível

	# Seções verticais (coordenadas LOCAIS ao painel)
	var header_y: float = 30.0
	var header_h: float = 104.0

	var div_top_y: float = header_y + header_h + 12.0

	var score_y: float = div_top_y + 16.0
	var score_h: float = 128.0

	var stats_y: float = score_y + score_h + 18.0

	var hint_h: float = 46.0
	var countdown_h: float = 38.0
	var hint_y: float = H - 30.0 - hint_h
	var countdown_y: float = hint_y - countdown_h - 8.0
	var div_base_y: float = countdown_y - 14.0

	var stats_h: float = max(90.0, div_base_y - 14.0 - stats_y)

	# Glow interno sutil (atrás dos cards, sem tocar a borda)
	var glow := fim_panel.get_node_or_null("FimGlow") as ColorRect
	if glow != null:
		glow.position = Vector2(m - 10.0, score_y - 6.0)
		glow.size = Vector2(W - (m - 10.0) * 2.0, (stats_y + stats_h) - (score_y - 6.0))

	# Card do cabeçalho (título)
	var topo := fim_panel.get_node_or_null("FimTopo") as Control
	if topo != null:
		topo.position = Vector2(m, header_y)
		topo.size = Vector2(W - m * 2.0, header_h)

	# Divisória neon superior
	var linha_topo := fim_panel.get_node_or_null("FimLinhaTopo") as ColorRect
	if linha_topo != null:
		linha_topo.position = Vector2(m, div_top_y)
		linha_topo.size = Vector2(W - m * 2.0, 3.0)

	# Card da pontuação
	var faixa_score := fim_panel.get_node_or_null("FimFaixaScore") as Control
	if faixa_score != null:
		faixa_score.position = Vector2(m, score_y)
		faixa_score.size = Vector2(W - m * 2.0, score_h)

	# Card das estatísticas
	var faixa_stats := fim_panel.get_node_or_null("FimFaixaStats") as Control
	if faixa_stats != null:
		faixa_stats.position = Vector2(m, stats_y)
		faixa_stats.size = Vector2(W - m * 2.0, stats_h)

	# Divisória neon inferior
	var linha_base := fim_panel.get_node_or_null("FimLinhaBase") as ColorRect
	if linha_base != null:
		linha_base.position = Vector2(m, div_base_y)
		linha_base.size = Vector2(W - m * 2.0, 3.0)

	# Linha extra antiga: desativada para não virar retângulo solto
	var linha_stats := fim_panel.get_node_or_null("FimLinhaStats") as ColorRect
	if linha_stats != null:
		linha_stats.visible = false

	# ---- TEXTOS (filhos do painel -> coords LOCAIS) ----
	if fim_title != null:
		fim_title.position = Vector2(m + 12.0, header_y)
		fim_title.size = Vector2(W - (m + 12.0) * 2.0, header_h)
		fim_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if fim_score != null:
		fim_score.position = Vector2(m + 24.0, score_y)
		fim_score.size = Vector2(W - (m + 24.0) * 2.0, score_h)
		fim_score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if fim_stats != null:
		fim_stats.position = Vector2(m + 28.0, stats_y + 16.0)
		fim_stats.size = Vector2(W - (m + 28.0) * 2.0, stats_h - 32.0)
		fim_stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fim_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		var linhas_stats: int = fim_stats.text.count("\n") + 1
		if linhas_stats >= 8:
			_fonte_valor(fim_stats, 23, Color(0.88, 0.98, 1.0, 1.0))
		elif linhas_stats >= 6:
			_fonte_valor(fim_stats, 25, Color(0.88, 0.98, 1.0, 1.0))
		else:
			_fonte_valor(fim_stats, 27, Color(0.88, 0.98, 1.0, 1.0))

	if fim_countdown_label != null:
		fim_countdown_label.position = Vector2(m, countdown_y)
		fim_countdown_label.size = Vector2(W - m * 2.0, countdown_h)
		fim_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fim_countdown_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		fim_countdown_label.clip_text = false

	if fim_hint != null:
		fim_hint.position = Vector2(m, hint_y)
		fim_hint.size = Vector2(W - m * 2.0, hint_h)
		fim_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fim_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART



func _reiniciar_partida() -> void:
	# Modo crédito: só recomeça se houver crédito (desconta aqui).
	if not Maquina.cobrar():
		return
	_aplicar_config_admin_na_cena()
	_parar_musica_fim()
	_iniciar_musica_pirate_em_loop()

	for alvo in alvos_ativos:
		if is_instance_valid(alvo):
			alvo.queue_free()
	alvos_ativos.clear()

	tempo_restante = tempo_partida
	total_tiros = 0
	total_acertos = 0
	pontuacao_total = 0

	bombas_erros_atual = 0
	combo_bombas_acertadas = 0

	recoil_intensidade = 0.0
	recoil_tempo = 0.0
	aviso_sem_municao_t = 0.0

	balas_no_cartucho = capacidade_cartucho
	recarregando = false
	reload_tempo_restante = 0.0

	contagem_inicio_ativa = false
	contagem_inicio_t = 0.0
	contagem_inicio_etapa = 3

	penalidade_bomba_t = 0.0
	mira_desvio_bomba = Vector2.ZERO
	fim_retorno_timer = 0.0

	nivel_dificuldade_atual = 0
	combo_hits_seguidos = 0
	combo_timer_restante = 0.0

	if combo_label != null:
		combo_label.visible = false
		combo_label.text = ""

	marcas_agua.clear()
	fx_agua.clear()
	fx_estilhacos.clear()
	fx_moedas.clear()
	fx_explosao_bomba.clear()
	
	if fx_back_overlay != null:
		fx_back_overlay.queue_redraw()

	if fx_front_overlay != null:
		fx_front_overlay.queue_redraw()

	if flash_overlay != null:
		flash_overlay.color = Color(1, 1, 1, 0.0)
		flash_overlay.modulate.a = 0.0

	if dano_overlay != null:
		dano_overlay.color = Color(0.85, 0.05, 0.03, 0.0)
		dano_overlay.modulate.a = 0.0

	if dano_vinheta_overlay != null:
		dano_vinheta_overlay.color = Color(0.20, 0.0, 0.0, 0.0)
		dano_vinheta_overlay.modulate.a = 0.0

	dano_nevoa_ativo = false
	dano_nevoa_t = 0.0

	jogo_ativo = true
	partida_iniciada = false
	tela_inicio_ativa = true
	encerrado = false
	intro_comeco_ativa = false
	intro_comeco_t = 0.0
	intro_contagem_valor = 3

	if fim_root != null:
		fim_root.visible = false
		
	_esconder_alerta_3_bombas()

	if info_inicio_root != null:
		info_inicio_root.visible = true
		info_inicio_root.modulate.a = 1.0

	if comeco_root != null:
		comeco_root.visible = false

	if comeco_titulo != null:
		comeco_titulo.visible = false
		comeco_titulo.scale = Vector2.ONE
		comeco_titulo.modulate = Color(1, 1, 1, 1)

	if comeco_subtitulo != null:
		comeco_subtitulo.visible = false
		comeco_subtitulo.scale = Vector2.ONE
		comeco_subtitulo.modulate = Color(1, 1, 1, 1)

	if fim_countdown_label != null:
		fim_countdown_label.visible = false
		fim_countdown_label.text = ""

	_resetar_spawn_timer()
	_atualizar_bombas_hud()
	_atualizar_hud()
	_set_status("")
	_ajustar_layout()
	queue_redraw()


func _atualizar_textos_painel_inicio_mar() -> void:
	if aviso_subtitulo != null:
		aviso_subtitulo.text = "SOME PONTOS E NÃO ACERTE AS BOMBAS"

	if aviso_dica_label != null:
		aviso_dica_label.text = "CADA BOMBA TIRA UMA VIDA. COM 3 BOMBAS, A PARTIDA ACABA."

	if aviso_texto_extra_label != null:
		aviso_texto_extra_label.text = "BOMBAS APARECEM NO PAINEL DE PONTOS.\nBOTÃO DIREITO RECARREGA."

	if aviso_card_bomba != null:
		var titulo_bomba: Label = aviso_card_bomba.get_node_or_null("TituloCard") as Label
		if titulo_bomba != null:
			titulo_bomba.text = "BOMBA  3 ACERTOS ENCERRAM"


func _configurar_animacao_inicial_do_alvo(alvo: Area2D) -> void:
	var tipo: String = String(alvo.get_meta("tipo_alvo", ""))
	if tipo == "aguaviva":
		_ativar_animacao_aguaviva(alvo)
	else:
		_configurar_animacao_padrao(alvo)


func _resetar_spawn_timer() -> void:
	spawn_timer = randf_range(intervalo_spawn_min, intervalo_spawn_max)


func _tentar_spawn_alvo() -> void:
	if not partida_iniciada or encerrado:
		return

	var aguavivas_ativas: int = _contar_tipo_ativo("aguaviva")
	var vasos_ativos: int = _contar_tipo_ativo("vaso")
	var baus_ativos: int = _contar_tipo_ativo("bau")
	var bombas_ativas: int = _contar_tipo_ativo("bomba")
	var chance_aguaviva_reduzida := chance_aguaviva * reducao_spawn_aguaviva

	if aguavivas_ativas < max_aguavivas_ativas and randf() <= chance_aguaviva_reduzida:
		_spawnar_alvo("aguaviva")
		aguavivas_ativas += 1


	var chance_vaso_reduzida := chance_vaso * reducao_spawn_vaso

	if vasos_ativos < max_vasos_ativos and randf() < chance_vaso_reduzida:
		_spawnar_alvo("vaso")
		vasos_ativos += 1

	if baus_ativos < max_baus_ativos and randf() < chance_bau:
		_spawnar_alvo("bau")
		baus_ativos += 1

	var max_bombas_agora: int = _obter_max_bombas_ativas_atual()
	var tentativas_bomba: int = _obter_tentativas_spawn_bomba_atual()
	var chance_bomba_atual: float = _obter_chance_bomba_atual()

	for i in range(tentativas_bomba):
		if bombas_ativas >= max_bombas_agora:
			break

		if randf() < chance_bomba_atual:
			_spawnar_alvo("bomba")
			bombas_ativas += 1


func _contar_tipo_ativo(tipo: String) -> int:
	var total: int = 0
	for i in range(alvos_ativos.size() - 1, -1, -1):
		var alvo = alvos_ativos[i]
		if not is_instance_valid(alvo):
			alvos_ativos.remove_at(i)
			continue
		if String(alvo.get_meta("tipo_alvo", "")) == tipo:
			total += 1
	return total


func _spawnar_alvo(tipo: String) -> void:
	var modelo: Area2D = null

	match tipo:
		"aguaviva":
			modelo = aguaviva_modelo
		"vaso":
			modelo = vaso_modelo
		"bau":
			modelo = bau_modelo
		"bomba":
			modelo = bomba_modelo

	if modelo == null or alvos_root == null:
		push_warning("Modelo não encontrado para: " + tipo)
		return

	var novo: Area2D = modelo.duplicate(
		Node.DUPLICATE_SIGNALS |
		Node.DUPLICATE_GROUPS |
		Node.DUPLICATE_SCRIPTS
	) as Area2D

	if novo == null:
		push_warning("Falha ao duplicar alvo: " + tipo)
		return

	var pontos: int = 0
	var duracao: float = 0.0
	var escala_base: float = 1.0

	var mult_vel: float = _obter_multiplicador_velocidade()

	match tipo:
		"aguaviva":
			pontos = pontos_aguaviva
			duracao = tempo_queda_aguaviva / mult_vel
			escala_base = randf_range(escala_aguaviva_min, escala_aguaviva_max)
		"vaso":
			pontos = pontos_vaso
			duracao = tempo_queda_vaso / mult_vel
			escala_base = randf_range(escala_vaso_min, escala_vaso_max)
		"bau":
			pontos = pontos_bau
			duracao = tempo_queda_bau / mult_vel
			escala_base = randf_range(escala_bau_min, escala_bau_max)
		"bomba":
			pontos = -randi_range(pontos_bomba_min, pontos_bomba_max)
			duracao = tempo_queda_bomba / mult_vel
			escala_base = _obter_escala_bomba_ajustada(randf_range(escala_bomba_min, escala_bomba_max))

	novo.visible = true
	novo.show()
	novo.modulate = Color.WHITE
	novo.process_mode = Node.PROCESS_MODE_INHERIT
	novo.monitorable = true
	novo.monitoring = true
	novo.input_pickable = true
	novo.z_index = Z_INDEX_BOMBA if tipo == "bomba" else Z_INDEX_OBJETOS_COMUNS

	novo.set_meta("tipo_alvo", tipo)
	novo.set_meta("pontos_alvo", pontos)
	novo.set_meta("duracao_queda", duracao)
	novo.set_meta("atingido", false)
	novo.set_meta("tween_queda", null)
	novo.set_meta("escala_base", escala_base)
	novo.set_meta("bubble_move_t", randf_range(bolha_objeto_intervalo_min, bolha_objeto_intervalo_max))

	if tipo == "aguaviva":
		var usar_variante_a: bool = randf() < 0.5
		novo.set_meta("aguaviva_variante", "a" if usar_variante_a else "normal")
		novo.set_meta("aguaviva_tempo", randf_range(0.0, 10.0))
		novo.set_meta("aguaviva_seed", randf_range(0.0, TAU))
		novo.set_meta("aguaviva_bubble_t", randf_range(aguaviva_bolha_intervalo_min, aguaviva_bolha_intervalo_max))

	alvos_root.add_child(novo)
	alvos_ativos.append(novo)

	novo.scale = Vector2.ONE * escala_base
	_ajustar_collision_shape_por_tipo(novo)

	var tela: Vector2 = get_viewport_rect().size
	var margem_fora: float = 140.0

	var trajeto: Dictionary = _achar_trajeto_sem_conflito(tipo, tela, margem_fora, escala_base)
	var pos_inicial: Vector2 = trajeto.get("inicial", Vector2.ZERO)
	var pos_final: Vector2 = trajeto.get("final", Vector2.ZERO)

	if not bool(trajeto.get("ok", false)):
		_remover_alvo(novo)
		return

	if tipo == "aguaviva":
		novo.rotation_degrees = randf_range(-8.0, 8.0)
	elif tipo == "vaso":
		novo.rotation_degrees = randf_range(-6.0, 6.0)
	elif tipo == "bau":
		novo.rotation_degrees = randf_range(-4.0, 4.0)
	else:
		novo.rotation_degrees = randf_range(-180.0, 180.0)

	novo.position = pos_inicial

	_configurar_animacao_spawn(novo)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(novo, "position", pos_final, duracao)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_IN_OUT)

	if tipo == "bomba":
		tween.tween_property(novo, "rotation_degrees", novo.rotation_degrees + randf_range(320.0, 560.0), duracao)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
	else:
		tween.tween_property(novo, "rotation_degrees", randf_range(-14.0, 14.0), duracao)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)

	novo.set_meta("tween_queda", tween)

	tween.finished.connect(func() -> void:
		if not is_instance_valid(novo):
			return
		if bool(novo.get_meta("atingido", false)):
			return
		_remover_alvo(novo)
	)


func _atualizar_movimento_aguavivas(delta: float) -> void:
	for i in range(alvos_ativos.size() - 1, -1, -1):
		var alvo: Area2D = alvos_ativos[i]

		if alvo == null or not is_instance_valid(alvo):
			continue

		if String(alvo.get_meta("tipo_alvo", "")) != "aguaviva":
			continue

		_atualizar_idle_aguaviva(alvo, delta)


func _atualizar_idle_aguaviva(alvo: Area2D, delta: float) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	if bool(alvo.get_meta("atingido", false)):
		return

	var anim := _forcar_aguaviva_visivel(alvo)
	if anim == null:
		return
	if anim.sprite_frames == null:
		return

	var variante: String = _obter_variante_aguaviva(alvo)

	var t: float = float(alvo.get_meta("aguaviva_tempo", 0.0)) + delta
	var seed: float = float(alvo.get_meta("aguaviva_seed", 0.0))
	alvo.set_meta("aguaviva_tempo", t)

	var anim_hit: String = _achar_animacao_hit_aguaviva(anim, variante)
	if anim_hit != "" and anim.animation == anim_hit and anim.is_playing():
		return

	var idle_anim: String = _achar_animacao_idle_aguaviva(anim, variante)
	if idle_anim != "" and anim.animation != idle_anim:
		anim.animation = idle_anim
		anim.frame = 0

		if anim.sprite_frames.get_frame_count(idle_anim) > 1:
			anim.play(idle_anim)
		else:
			anim.stop()

	var sway_x: float = sin((t * aguaviva_freq_x) + seed) * aguaviva_balanço_x
	var sway_y: float = cos((t * aguaviva_freq_y) + seed * 0.73) * aguaviva_balanço_y
	var rot: float = sin((t * aguaviva_freq_rot) + seed * 1.17) * aguaviva_rotacao_idle
	var pulso: float = 1.0 + sin((t * aguaviva_freq_pulso) + seed * 0.41) * aguaviva_pulso_escala

	anim.position = Vector2(sway_x, sway_y)
	anim.rotation_degrees = rot
	anim.scale = Vector2.ONE * pulso

	var bubble_t: float = float(alvo.get_meta("aguaviva_bubble_t", 0.18)) - delta
	if bubble_t <= 0.0:
		_emitir_bolhas_idle_aguaviva(alvo, Vector2(sway_x, sway_y))
		bubble_t = randf_range(aguaviva_bolha_intervalo_min, aguaviva_bolha_intervalo_max)

	alvo.set_meta("aguaviva_bubble_t", bubble_t)


func _emitir_bolhas_idle_aguaviva(alvo: Area2D, visual_offset: Vector2 = Vector2.ZERO) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	var qtd: int = randi_range(aguaviva_bolhas_por_onda_min + 1, aguaviva_bolhas_por_onda_max + 2)
	var base: Vector2 = alvo.global_position + visual_offset

	for i in range(qtd):
		var lateral: float = randf_range(-26.0, 26.0)
		var vertical: float = randf_range(-10.0, 28.0)
		var pos_bolha: Vector2 = base + Vector2(lateral, vertical)

		fx_agua.append({
			"pos": pos_bolha,
			"vel": Vector2(
				randf_range(-12.0, 12.0),
				randf_range(-92.0, -34.0)
			),
			"idade": 0.0,
			"vida": randf_range(0.60, 1.25),
			"tam": randf_range(5.0, 11.5)
		})


func _resetar_visual_aguaviva(alvo: Area2D) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	var anim: AnimatedSprite2D = _obter_animated_do_alvo(alvo)
	if anim == null:
		return

	anim.position = Vector2.ZERO
	anim.rotation_degrees = 0.0
	anim.scale = Vector2.ONE



func _parar_movimento_do_alvo(alvo: Area2D) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	if alvo.has_meta("tween_queda"):
		var tw = alvo.get_meta("tween_queda")
		if tw != null and tw is Tween:
			(tw as Tween).kill()

	alvo.set_meta("tween_queda", null)



func _processar_tiro_global(pos_global: Vector2, primeiro_tiro: bool = false) -> void:
	if not jogo_ativo or encerrado:
		return

	if not partida_iniciada:
		return

	if recarregando:
		_set_status("RECARREGANDO.", "neutro")
		_atualizar_hud()
		return

	if balas_no_cartucho <= 0:
		if som_bullet_no_stream != null:
			_tocar_som(som_bullet_no_stream, -2.0, 1.0, 0.0)

		_set_status("CARTUCHO VAZIO", "erro")
		_atualizar_hud()
		return

	balas_no_cartucho -= 1
	total_tiros += 1

	# pulso menor na mira para não dar sensação de pipoco/travada
	alvo_anim_t += 0.08

	var agora_ms := Time.get_ticks_msec()
	if agora_ms - ultimo_tiro_ms >= cooldown_tiro_ms:
		ultimo_tiro_ms = agora_ms
		_tocar_som(som_tiro_stream, -3.0, 1.0, 0.0)

	var alvo_acertado: Area2D = _detectar_alvo_no_ponto_visual(pos_global)

	if alvo_acertado != null:
		_acertar_alvo(alvo_acertado, pos_global)
	else:
		_efeito_erro_aquatico(pos_global)

	if balas_no_cartucho <= 0:
		_set_status("CARTUCHO VAZIO", "erro")

	_atualizar_hud()


func _detectar_alvo_no_ponto_visual(pos_global: Vector2) -> Area2D:
	for i in range(alvos_ativos.size() - 1, -1, -1):
		var alvo: Area2D = alvos_ativos[i]

		if alvo == null or not is_instance_valid(alvo):
			continue
		if not alvo.visible:
			continue
		if bool(alvo.get_meta("atingido", false)):
			continue
		if not alvo.monitoring:
			continue

		if _ponto_esta_sobre_sprite_do_alvo(alvo, pos_global):
			return alvo

	return null


func _obter_collision_shape_do_alvo(alvo: Node) -> CollisionShape2D:
	if alvo == null:
		return null

	for filho in alvo.get_children():
		if filho is CollisionShape2D:
			return filho as CollisionShape2D

	for filho in alvo.get_children():
		for neto in filho.get_children():
			if neto is CollisionShape2D:
				return neto as CollisionShape2D

	return null


func _ajustar_collision_shape_por_tipo(alvo: Area2D) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	var collision: CollisionShape2D = _obter_collision_shape_do_alvo(alvo)
	if collision == null:
		return

	var tipo: String = String(alvo.get_meta("tipo_alvo", ""))
	collision.position = Vector2.ZERO
	collision.rotation_degrees = 0.0
	collision.disabled = false

	match tipo:
		"aguaviva":
			var s := CapsuleShape2D.new()
			s.radius = 20.0
			s.height = 56.0
			collision.shape = s
			collision.position = Vector2(0.0, 4.0)

		"vaso":
			var s := CapsuleShape2D.new()
			s.radius = 28.0
			s.height = 92.0
			collision.shape = s
			collision.position = Vector2(0.0, 8.0)

		"bau":
			var s := RectangleShape2D.new()
			s.size = Vector2(66.0, 48.0)
			collision.shape = s
			collision.position = Vector2(0.0, 10.0)

		"bomba":
			var s := CircleShape2D.new()
			s.radius = 34.0
			collision.shape = s
			collision.position = Vector2.ZERO



func _obter_raio_aproximado_do_alvo(tipo: String, escala: float) -> float:
	match tipo:
		"aguaviva":
			return 40.0 * escala
		"vaso":
			return 44.0 * escala
		"bau":
			return 64.0 * escala
		"bomba":
			return 54.0 * escala
	return 50.0 * escala


func _alvo_pode_sobrepor(tipo: String) -> bool:
	return tipo == "bomba"


func _posicao_conflita_com_outros(tipo: String, pos: Vector2, raio: float) -> bool:
	if _alvo_pode_sobrepor(tipo):
		return false

	var margem_extra_dificuldade: float = float(nivel_dificuldade_atual) * bonus_margem_spawn_por_nivel

	for outro in alvos_ativos:
		if outro == null or not is_instance_valid(outro):
			continue
		if bool(outro.get_meta("atingido", false)):
			continue

		var tipo_outro: String = String(outro.get_meta("tipo_alvo", ""))
		if _alvo_pode_sobrepor(tipo_outro):
			continue

		var escala_outro: float = float(outro.get_meta("escala_base", 1.0))
		var raio_outro: float = _obter_raio_aproximado_do_alvo(tipo_outro, escala_outro)

		if pos.distance_to(outro.position) < (raio + raio_outro + margem_seguranca_spawn + margem_extra_dificuldade):
			return true

	return false


func _achar_trajeto_sem_conflito(tipo: String, tela: Vector2, margem_fora: float, escala: float) -> Dictionary:
	var raio: float = _obter_raio_aproximado_do_alvo(tipo, escala)

	for tentativa in range(max_tentativas_spawn_sem_sobrepor):
		var pos_inicial := Vector2.ZERO
		var pos_final := Vector2.ZERO

		if tipo == "aguaviva":
			var modo: int = randi_range(0, 2)

			if modo == 0:
				var x_subindo: float = randf_range(110.0, tela.x - 110.0)
				pos_inicial = Vector2(x_subindo, tela.y + margem_fora)
				pos_final = Vector2(x_subindo, -margem_fora)
			elif modo == 1:
				var x_descendo: float = randf_range(110.0, tela.x - 110.0)
				pos_inicial = Vector2(x_descendo, -margem_fora)
				pos_final = Vector2(x_descendo, tela.y + margem_fora)
			else:
				var y_lateral: float = randf_range(140.0, tela.y - 140.0)
				if randf() < 0.5:
					pos_inicial = Vector2(-margem_fora, y_lateral)
					pos_final = Vector2(tela.x + margem_fora, y_lateral + randf_range(-90.0, 90.0))
				else:
					pos_inicial = Vector2(tela.x + margem_fora, y_lateral)
					pos_final = Vector2(-margem_fora, y_lateral + randf_range(-90.0, 90.0))

		elif tipo == "bomba":
			var lado: int = randi_range(0, 3)

			match lado:
				0:
					pos_inicial = Vector2(randf_range(70.0, tela.x - 70.0), -margem_fora)
					pos_final = Vector2(randf_range(70.0, tela.x - 70.0), tela.y + margem_fora)
				1:
					pos_inicial = Vector2(randf_range(70.0, tela.x - 70.0), tela.y + margem_fora)
					pos_final = Vector2(randf_range(70.0, tela.x - 70.0), -margem_fora)
				2:
					pos_inicial = Vector2(-margem_fora, randf_range(120.0, tela.y - 90.0))
					pos_final = Vector2(tela.x + margem_fora, randf_range(120.0, tela.y - 90.0))
				3:
					pos_inicial = Vector2(tela.x + margem_fora, randf_range(120.0, tela.y - 90.0))
					pos_final = Vector2(-margem_fora, randf_range(120.0, tela.y - 90.0))
		else:
			var x_topo: float = randf_range(margem_spawn_x, tela.x - margem_spawn_x)
			pos_inicial = Vector2(x_topo, -margem_fora)
			pos_final = Vector2(x_topo, tela.y + margem_fora)

		var amostras := [
			pos_inicial.lerp(pos_final, 0.20),
			pos_inicial.lerp(pos_final, 0.35),
			pos_inicial.lerp(pos_final, 0.50),
			pos_inicial.lerp(pos_final, 0.65)
		]

		var conflitou: bool = false
		for p in amostras:
			if _posicao_conflita_com_outros(tipo, p, raio):
				conflitou = true
				break

		if not conflitou:
			return {
				"ok": true,
				"inicial": pos_inicial,
				"final": pos_final
			}

	return {
		"ok": false,
		"inicial": Vector2.ZERO,
		"final": Vector2.ZERO
	}


func _obter_multiplicador_velocidade() -> float:
	return 1.0 + (float(nivel_dificuldade_atual) * bonus_velocidade_por_nivel)
	
func _obter_max_bombas_ativas_atual() -> int:
	return max_bombas_ativas + (nivel_dificuldade_atual * bonus_max_bombas_por_nivel)


func _obter_tentativas_spawn_bomba_atual() -> int:
	return 1 + (nivel_dificuldade_atual * bonus_tentativas_spawn_bomba_por_nivel)


func _obter_chance_bomba_atual() -> float:
	var chance_atual: float = chance_bomba

	if pontuacao_total < 1500:
		chance_atual += bonus_bomba_inicio_partida

	chance_atual += float(nivel_dificuldade_atual) * bonus_chance_bomba_por_nivel

	if nivel_dificuldade_atual >= 1:
		chance_atual += bonus_chance_bomba_extra_apos_3000

	return min(0.90, chance_atual)

func _obter_escala_bomba_ajustada(base: float) -> float:
	return base + (float(nivel_dificuldade_atual) * bonus_escala_bomba_por_nivel)


func _emitir_bolhas_movimento_objeto(alvo: Area2D, intensidade: float = 1.0) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	var tipo: String = String(alvo.get_meta("tipo_alvo", ""))
	var qtd: int = randi_range(bolha_objeto_qtd_min + 1, bolha_objeto_qtd_max + 2)
	var base: Vector2 = alvo.global_position

	var spread_x: float = 22.0
	var spread_y: float = 22.0
	var vel_y_min: float = -100.0
	var vel_y_max: float = -36.0
	var tam_min: float = 4.8
	var tam_max: float = 10.5

	match tipo:
		"aguaviva":
			spread_x = 28.0
			spread_y = 28.0
			tam_min = 5.0
			tam_max = 11.5
		"vaso":
			spread_x = 22.0
			spread_y = 24.0
			tam_min = 5.6
			tam_max = 12.0
		"bau":
			spread_x = 28.0
			spread_y = 22.0
			tam_min = 6.0
			tam_max = 12.8
		"bomba":
			spread_x = 24.0
			spread_y = 24.0
			tam_min = 5.4
			tam_max = 11.8
			qtd += 2

	for i in range(qtd):
		fx_agua.append({
			"pos": base + Vector2(randf_range(-spread_x, spread_x), randf_range(-spread_y, spread_y)),
			"vel": Vector2(
				randf_range(-16.0, 16.0) * intensidade,
				randf_range(vel_y_min, vel_y_max) * intensidade
			),
			"idade": 0.0,
			"vida": randf_range(0.60, 1.22),
			"tam": randf_range(tam_min, tam_max)
		})


func _atualizar_bolhas_dos_objetos(delta: float) -> void:
	for alvo in alvos_ativos:
		if alvo == null or not is_instance_valid(alvo):
			continue
		if bool(alvo.get_meta("atingido", false)):
			continue

		var bubble_t: float = float(alvo.get_meta("bubble_move_t", randf_range(bolha_objeto_intervalo_min, bolha_objeto_intervalo_max)))
		bubble_t -= delta

		if bubble_t <= 0.0:
			_emitir_bolhas_movimento_objeto(alvo, 1.0)
			bubble_t = randf_range(bolha_objeto_intervalo_min, bolha_objeto_intervalo_max)

		alvo.set_meta("bubble_move_t", bubble_t)


func _ponto_esta_sobre_colisao_do_alvo(alvo: Area2D, pos_global: Vector2) -> bool:
	var collision: CollisionShape2D = _obter_collision_shape_do_alvo(alvo)
	if collision == null or collision.shape == null:
		return false

	var ponto_local_shape: Vector2 = collision.to_local(pos_global)
	var shape: Shape2D = collision.shape

	if shape is CircleShape2D:
		var circle := shape as CircleShape2D
		return ponto_local_shape.length() <= circle.radius

	if shape is RectangleShape2D:
		var rect := shape as RectangleShape2D
		return absf(ponto_local_shape.x) <= rect.size.x and absf(ponto_local_shape.y) <= rect.size.y

	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var half_h: float = capsule.height * 0.5
		var r: float = capsule.radius

		if absf(ponto_local_shape.x) <= r and absf(ponto_local_shape.y) <= half_h:
			return true

		var top_center := Vector2(0.0, -half_h)
		var bottom_center := Vector2(0.0, half_h)

		return ponto_local_shape.distance_to(top_center) <= r or ponto_local_shape.distance_to(bottom_center) <= r

	if shape is ConvexPolygonShape2D:
		var poly := shape as ConvexPolygonShape2D
		return Geometry2D.is_point_in_polygon(ponto_local_shape, poly.points)

	if shape is ConcavePolygonShape2D:
		return false

	return false


func _obter_sprite_do_alvo(alvo: Node) -> Sprite2D:
	if alvo == null:
		return null

	for filho in alvo.get_children():
		if filho is Sprite2D:
			return filho as Sprite2D

	for filho in alvo.get_children():
		for neto in filho.get_children():
			if neto is Sprite2D:
				return neto as Sprite2D

	return null


func _obter_animated_do_alvo(alvo: Node) -> AnimatedSprite2D:
	if alvo == null:
		return null

	for filho in alvo.get_children():
		if filho is AnimatedSprite2D:
			return filho as AnimatedSprite2D

	for filho in alvo.get_children():
		for neto in filho.get_children():
			if neto is AnimatedSprite2D:
				return neto as AnimatedSprite2D

	return null


func _obter_tamanho_visual_do_alvo(alvo: Area2D) -> Dictionary:
	var sprite: Sprite2D = _obter_sprite_do_alvo(alvo)
	if sprite != null and sprite.texture != null:
		return {
			"tipo": "sprite",
			"node": sprite,
			"size": sprite.texture.get_size()
		}

	var anim: AnimatedSprite2D = _obter_animated_do_alvo(alvo)
	if anim != null and anim.sprite_frames != null:
		var anim_nome: String = anim.animation

		if anim_nome == "":
			var nomes: PackedStringArray = anim.sprite_frames.get_animation_names()
			if nomes.size() > 0:
				anim_nome = String(nomes[0])

		if anim_nome != "":
			var frame_index: int = clamp(anim.frame, 0, max(0, anim.sprite_frames.get_frame_count(anim_nome) - 1))
			var frame_tex: Texture2D = anim.sprite_frames.get_frame_texture(anim_nome, frame_index)
			if frame_tex != null:
				return {
					"tipo": "animated",
					"node": anim,
					"size": frame_tex.get_size()
				}

	return {}


func _ponto_esta_sobre_sprite_do_alvo(alvo: Area2D, pos_global: Vector2) -> bool:
	var visual: Dictionary = _obter_tamanho_visual_do_alvo(alvo)
	if visual.is_empty():
		return false

	var tipo_visual: String = String(visual.get("tipo", ""))
	var node_visual: Node = visual.get("node", null)
	var tex_size: Vector2 = visual.get("size", Vector2.ZERO)

	if node_visual == null or tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return false

	var ponto_local: Vector2
	if tipo_visual == "sprite":
		ponto_local = (node_visual as Sprite2D).to_local(pos_global)
	else:
		ponto_local = (node_visual as AnimatedSprite2D).to_local(pos_global)

	var half_size: Vector2 = tex_size * 0.5
	var tipo_alvo: String = String(alvo.get_meta("tipo_alvo", ""))

	var ajuste_x: float = 1.0
	var ajuste_y: float = 1.0
	var offset_y: float = 0.0

	match tipo_alvo:
		"aguaviva":
			ajuste_x = 0.56
			ajuste_y = 0.64
			offset_y = 2.0
		"vaso":
			ajuste_x = 0.72
			ajuste_y = 0.88
			offset_y = 6.0
		"bau":
			ajuste_x = 0.84
			ajuste_y = 0.78
			offset_y = 8.0
		"bomba":
			ajuste_x = 0.86
			ajuste_y = 0.86
			offset_y = 0.0
		_:
			ajuste_x = 0.82
			ajuste_y = 0.82

	var y_local: float = ponto_local.y - offset_y

	if tipo_alvo == "aguaviva":
		# corpo da água-viva = oval justo (reconhece só o desenho, não a região em volta)
		var rx: float = half_size.x * ajuste_x
		var ry: float = half_size.y * ajuste_y
		if rx <= 0.0 or ry <= 0.0:
			return false
		var nx: float = ponto_local.x / rx
		var ny: float = y_local / ry
		return (nx * nx + ny * ny) <= 1.0

	var limite_x: float = half_size.x * ajuste_x
	var limite_y: float = half_size.y * ajuste_y

	if ponto_local.x < -limite_x or ponto_local.x > limite_x:
		return false
	if y_local < -limite_y or y_local > limite_y:
		return false

	return true


func _registrar_fx_moedas(pos: Vector2) -> void:
	var quantidade: int = 18

	for i in range(quantidade):
		var ang: float = randf_range(-PI * 0.96, -PI * 0.04)
		var vel: Vector2 = Vector2.RIGHT.rotated(ang) * randf_range(130.0, 320.0)
		vel.y -= randf_range(80.0, 220.0)

		fx_moedas.append({
			"pos": pos + Vector2(randf_range(-12.0, 12.0), randf_range(-6.0, 6.0)),
			"vel": vel,
			"idade": 0.0,
			"vida": randf_range(0.75, 1.35),
			"rot": randf_range(-180.0, 180.0),
			"rot_vel": randf_range(-900.0, 900.0),
			"raio": randf_range(5.5, 9.5)
		})

func _atualizar_fx_moedas(delta: float) -> void:
	for i in range(fx_moedas.size() - 1, -1, -1):
		var fx: Dictionary = fx_moedas[i]
		fx["idade"] = float(fx["idade"]) + delta
		fx["vel"] = Vector2(fx["vel"]) + Vector2(0.0, 460.0) * delta
		fx["pos"] = Vector2(fx["pos"]) + Vector2(fx["vel"]) * delta
		fx["vel"] = Vector2(fx["vel"]) * 0.992
		fx["rot"] = float(fx["rot"]) + float(fx["rot_vel"]) * delta
		fx_moedas[i] = fx

		if float(fx["idade"]) >= float(fx["vida"]):
			fx_moedas.remove_at(i)


func _desenhar_fx_moedas() -> void:
	for fx in fx_moedas:
		var pos: Vector2 = Vector2(fx["pos"])
		var idade: float = float(fx["idade"])
		var vida: float = float(fx["vida"])
		var raio: float = float(fx["raio"])
		var rot_deg: float = float(fx["rot"])

		var t: float = clamp(idade / vida, 0.0, 1.0)
		var alpha: float = 1.0 - t

		var largura: float = raio * abs(cos(deg_to_rad(rot_deg)))
		largura = max(largura, 1.4)

		var pts := PackedVector2Array([
			pos + Vector2(-largura, -raio * 0.72),
			pos + Vector2(largura, -raio * 0.72),
			pos + Vector2(largura, raio * 0.72),
			pos + Vector2(-largura, raio * 0.72),
		])

		draw_colored_polygon(pts, Color(1.0, 0.84, 0.18, 0.95 * alpha))
		draw_polyline(pts, Color(0.76, 0.52, 0.08, 0.90 * alpha), 1.2, true)



func _aplicar_animacao_hit(alvo: Area2D) -> float:
	var anim: AnimatedSprite2D = _obter_animated_do_alvo(alvo)
	if anim != null and anim.sprite_frames != null:
		anim.visible = true
		anim.show()
		anim.stop()
		anim.process_mode = Node.PROCESS_MODE_INHERIT
		anim.speed_scale = 1.0

		var tipo: String = String(alvo.get_meta("tipo_alvo", ""))

		if tipo == "aguaviva":
			_resetar_visual_aguaviva(alvo)

			var hit_anim: String = _achar_animacao_hit_aguaviva(anim)
			if hit_anim != "":
				anim.animation = hit_anim
				anim.frame = 0

				if anim.sprite_frames.get_frame_count(hit_anim) > 1:
					anim.play(hit_anim)
				else:
					anim.stop()

				var frames_hit_agua: int = anim.sprite_frames.get_frame_count(hit_anim)
				var fps_hit_agua: float = anim.sprite_frames.get_animation_speed(hit_anim)
				if fps_hit_agua > 0.0 and frames_hit_agua > 0:
					return max(0.20, float(frames_hit_agua) / fps_hit_agua)

				return 0.35

			return 0.22

		if anim.sprite_frames.has_animation("hit"):
			anim.animation = "hit"
			anim.frame = 0
			anim.play("hit")

			var frames_hit: int = anim.sprite_frames.get_frame_count("hit")
			var fps_hit: float = anim.sprite_frames.get_animation_speed("hit")
			if fps_hit > 0.0 and frames_hit > 0:
				return max(0.20, float(frames_hit) / fps_hit)

		if anim.sprite_frames.has_animation("explode"):
			anim.animation = "explode"
			anim.frame = 0
			anim.play("explode")

			var frames_explode: int = anim.sprite_frames.get_frame_count("explode")
			var fps_explode: float = anim.sprite_frames.get_animation_speed("explode")
			if fps_explode > 0.0 and frames_explode > 0:
				return max(0.25, float(frames_explode) / fps_explode)

	var sprite: Sprite2D = _obter_sprite_do_alvo(alvo)
	if sprite != null:
		return 0.22

	return 0.22



func _acertar_alvo(alvo: Area2D, pos_impacto: Vector2 = Vector2.ZERO) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	if bool(alvo.get_meta("atingido", false)):
		return

	alvo.set_meta("atingido", true)
	_parar_movimento_do_alvo(alvo)

	var tipo: String = String(alvo.get_meta("tipo_alvo", ""))
	var pontos: int = int(alvo.get_meta("pontos_alvo", 0))
	var escala_base: float = float(alvo.get_meta("escala_base", 1.0))
	var impacto: Vector2 = pos_impacto if pos_impacto != Vector2.ZERO else alvo.global_position

	if tipo == "bomba":
		bombas_erros_atual += 1
		combo_bombas_acertadas += 1
		pontos = 0
		alvo.set_meta("pontos_alvo", 0)

		total_acertos += 1

		combo_hits_seguidos = 0
		combo_timer_restante = 0.0

		if combo_label != null:
			combo_label.visible = false
			combo_label.text = ""

		_atualizar_bombas_hud()

		if som_bomba_xploit_stream != null:
			_tocar_som(som_bomba_xploit_stream, -0.1, randf_range(0.97, 1.0), 0.0)
		elif som_bomba_explode_stream != null:
			_tocar_som(som_bomba_explode_stream, -0.1, randf_range(0.97, 1.0), 0.0)

		_flash_tela(Color(1.0, 0.10, 0.08, 0.24))
		_efeito_dano_bomba_forte()
		_tremida_rapida(12.0, 7, 0.022)

		_aplicar_animacao_hit(alvo)
		_registrar_fx_explosao_bomba(impacto)

		for i in range(3):
			_registrar_fx_estilhacos(
				impacto + Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0)),
				"bau"
			)

		for i in range(10):
			_registrar_fx_agua(
				impacto + Vector2(randf_range(-24.0, 24.0), randf_range(-24.0, 24.0))
			)

		var tw_bomba: Tween = create_tween()
		tw_bomba.set_parallel(true)
		tw_bomba.tween_property(alvo, "scale", Vector2.ONE * (escala_base * 1.35), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_bomba.tween_property(alvo, "rotation_degrees", alvo.rotation_degrees + randf_range(-70.0, 70.0), 0.10)
		tw_bomba.tween_property(alvo, "modulate:a", 0.0, 0.10).set_delay(0.05)

		tw_bomba.finished.connect(func() -> void:
			_remover_alvo(alvo)
		)

		var chances_restantes: int = max(0, bombas_erros_max - bombas_erros_atual)

		if bombas_erros_atual >= bombas_erros_max:
			_set_status("3 BOMBAS! PARTIDA ENCERRADA.", "bomba")
			jogo_ativo = false
			partida_iniciada = false
			_atualizar_hud()

			_mostrar_alerta_3_bombas()

			await get_tree().create_timer(1.6).timeout

			_esconder_alerta_3_bombas()

			if not encerrado:
				_encerrar_partida()

			return

		_set_status("NÃO ACERTE BOMBAS! RESTAM %d CHANCES" % chances_restantes, "bomba")
		_atualizar_hud()
		return

	combo_bombas_acertadas = 0
	pontuacao_total += pontos
	total_acertos += 1

	if pontos > 0:
		combo_hits_seguidos += 1
		combo_timer_restante = janela_combo_seg
		_mostrar_combo_hits()

	_atualizar_dificuldade_progressiva()

	var agora_ms := Time.get_ticks_msec()
	if agora_ms - ultimo_hit_ms >= cooldown_hit_ms:
		ultimo_hit_ms = agora_ms

		match tipo:
			"aguaviva":
				_tocar_som_com_atraso(som_aguaviva_hit_stream, atraso_aguaviva_hit_seg, -1.0, randf_range(0.98, 1.05), inicio_aguaviva_hit_seg)
			"vaso":
				_tocar_som_com_atraso(som_vaso_hit_stream, atraso_vaso_hit_seg, -0.8, randf_range(0.99, 1.02), inicio_vaso_hit_seg)
			"bau":
				_tocar_som_com_atraso(som_bau_hit_stream, 0.0, -0.2, randf_range(1.00, 1.02), inicio_bau_hit_seg)

	_set_status("ACERTO! +%d" % pontos, "acerto")

	if tipo == "aguaviva":
		_flash_tela(Color(0.36, 0.88, 1.0, 0.14))
		_tremida_rapida(1.8, 2, 0.020)
	else:
		_flash_tela(Color(1.0, 0.95, 0.70, 0.12))
		_tremida_rapida(3.5, 2, 0.028)

	var duracao_hit_anim: float = _aplicar_animacao_hit(alvo)

	_registrar_fx_agua(impacto)

	match tipo:
		"aguaviva":
			for i in range(10):
				_registrar_fx_agua(impacto + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0)))

		"vaso":
			_registrar_fx_estilhacos(impacto, "vaso")

		"bau":
			_registrar_fx_estilhacos(impacto, "bau")
			_registrar_fx_moedas(impacto)

	var tw: Tween = create_tween()
	tw.set_parallel(true)

	match tipo:
		"aguaviva":
			tw.tween_property(alvo, "scale", Vector2.ONE * (escala_base * 1.14), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(alvo, "rotation_degrees", alvo.rotation_degrees + randf_range(-10.0, 10.0), 0.10)

		"vaso":
			tw.tween_property(alvo, "scale", Vector2.ONE * (escala_base * 0.88), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(alvo, "rotation_degrees", alvo.rotation_degrees + randf_range(-6.0, 6.0), 0.12)

		"bau":
			tw.tween_property(alvo, "scale", Vector2.ONE * (escala_base * 1.08), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(alvo, "rotation_degrees", alvo.rotation_degrees + randf_range(-8.0, 8.0), 0.12)

	var fade_delay: float = max(0.20, duracao_hit_anim * 0.72)

	tw.tween_property(alvo, "modulate:a", 0.0, 0.20)\
		.set_delay(fade_delay)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)

	tw.finished.connect(func() -> void:
		_remover_alvo(alvo)
	)

	_atualizar_hud()
	
	
	


func _remover_alvo(alvo: Area2D) -> void:
	alvos_ativos.erase(alvo)
	if is_instance_valid(alvo):
		alvo.queue_free()

func _flash_tela(cor: Color) -> void:
	if flash_overlay == null:
		return

	flash_overlay.color = cor
	flash_overlay.modulate.a = 1.0

	var tw: Tween = create_tween()
	tw.tween_property(flash_overlay, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _tremida_rapida(forca: float, passos: int = 2, duracao_passo: float = 0.028) -> void:
	var base_pos: Vector2 = position
	var tw: Tween = create_tween()

	for i in range(passos):
		var offset := Vector2(
			randf_range(-forca, forca),
			randf_range(-forca, forca)
		)
		tw.tween_property(self, "position", base_pos + offset, duracao_passo)

	tw.tween_property(self, "position", base_pos, duracao_passo)

func _registrar_marca_agua(pos: Vector2) -> void:
	marcas_agua.append({
		"pos": pos,
		"raio": randf_range(18.0, 30.0),
		"anel": randf_range(28.0, 44.0),
		"anel2": randf_range(40.0, 58.0),
		"alpha": randf_range(0.34, 0.52)
	})

	while marcas_agua.size() > MAX_MARCAS_AGUA:
		marcas_agua.remove_at(0)

	queue_redraw()

func _registrar_fx_agua(pos: Vector2) -> void:
	for i in range(18):
		var ang: float = randf_range(-PI, PI)
		var vel: Vector2 = Vector2.RIGHT.rotated(ang) * randf_range(45.0, 180.0)
		vel.y -= randf_range(10.0, 110.0)

		fx_agua.append({
			"pos": pos + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)),
			"vel": vel,
			"idade": 0.0,
			"vida": randf_range(0.35, 0.75),
			"tam": randf_range(2.0, 5.5)
		})

func _atualizar_fx_agua(delta: float) -> void:
	for i in range(fx_agua.size() - 1, -1, -1):
		var fx: Dictionary = fx_agua[i]
		fx["idade"] = float(fx["idade"]) + delta
		fx["vel"] = Vector2(fx["vel"]) + Vector2(0.0, 220.0) * delta
		fx["pos"] = Vector2(fx["pos"]) + Vector2(fx["vel"]) * delta
		fx["vel"] = Vector2(fx["vel"]) * 0.96
		fx_agua[i] = fx

		if float(fx["idade"]) >= float(fx["vida"]):
			fx_agua.remove_at(i)



func _desenhar_marcas_agua() -> void:
	for marca in marcas_agua:
		var pos: Vector2 = Vector2(marca.get("pos", Vector2.ZERO))
		var raio: float = float(marca.get("raio", 18.0))
		var anel: float = float(marca.get("anel", 26.0))
		var anel2: float = float(marca.get("anel2", 36.0))
		var alpha: float = float(marca.get("alpha", 0.28))

		draw_arc(pos, raio, 0.0, TAU, 28, Color(0.70, 0.93, 1.0, alpha), 1.8, true)
		draw_arc(pos, anel, 0.0, TAU, 34, Color(0.48, 0.82, 1.0, alpha * 0.82), 1.5, true)
		draw_arc(pos, anel2, 0.0, TAU, 42, Color(0.38, 0.70, 0.96, alpha * 0.55), 1.2, true)
		draw_circle(pos, raio * 0.16, Color(0.88, 0.98, 1.0, alpha * 0.75))




func _calcular_precisao() -> int:
	if total_tiros <= 0:
		return 0
	return int(round((float(total_acertos) / float(total_tiros)) * 100.0))



func _set_status(texto: String, tipo: String = "neutro") -> void:
	if status_label == null or status_panel == null:
		return

	status_label.text = texto
	status_label.visible = texto != ""
	status_panel.visible = texto != ""
	status_panel.scale = Vector2.ONE
	status_panel.modulate = Color(1, 1, 1, 1)

	if texto == "":
		return

	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.color(status_label, "font_outline_color", Color.BLACK)
	Leve.constant(status_label, "outline_size", 7)

	var estilo := status_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if estilo == null:
		estilo = StyleBoxFlat.new()
		estilo.corner_radius_top_left = 18
		estilo.corner_radius_top_right = 18
		estilo.corner_radius_bottom_left = 18
		estilo.corner_radius_bottom_right = 18
		estilo.border_width_left = 3
		estilo.border_width_right = 3
		estilo.border_width_top = 3
		estilo.border_width_bottom = 3
		Leve.stylebox(status_panel, "panel", estilo)

	match tipo:
		"bomba", "erro":
			Leve.color(status_label, "font_color", Color(1.0, 0.88, 0.84, 1.0))
			estilo.bg_color = Color(0.18, 0.015, 0.018, 0.94)
			estilo.border_color = Color(1.0, 0.12, 0.08, 1.0)
			estilo.shadow_color = Color(1.0, 0.04, 0.02, 0.70)
			estilo.shadow_size = 30

		"acerto":
			Leve.color(status_label, "font_color", Color(0.86, 1.0, 1.0, 1.0))
			estilo.bg_color = Color(0.015, 0.075, 0.115, 0.94)
			estilo.border_color = COR_NEON_MAR
			estilo.shadow_color = Color(COR_NEON_MAR.r, COR_NEON_MAR.g, COR_NEON_MAR.b, 0.62)
			estilo.shadow_size = 28

		_:
			Leve.color(status_label, "font_color", Color.WHITE)
			estilo.bg_color = Color(0.015, 0.035, 0.065, 0.94)
			estilo.border_color = COR_NEON_MAR_CLARO
			estilo.shadow_color = Color(0.35, 0.85, 1.0, 0.46)
			estilo.shadow_size = 24

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(status_panel, "scale", Vector2(1.012, 1.08), 0.08)
	tw.tween_property(status_panel, "scale", Vector2.ONE, 0.14).set_delay(0.08)
	tw.tween_property(status_panel, "modulate:a", 0.0, 0.25).set_delay(1.45)

	tw.finished.connect(func() -> void:
		if is_instance_valid(status_panel) and status_label.text == texto:
			status_label.text = ""
			status_label.visible = false
			status_panel.visible = false
			status_panel.modulate.a = 1.0
	)



func _atualizar_hud() -> void:
	if timer_label != null:
		var minutos: int = int(tempo_restante) / 60
		var segundos: int = int(tempo_restante) % 60
		timer_label.text = "%02d:%02d" % [minutos, segundos]

	if score_label != null:
		score_label.text = str(pontuacao_total)

		if pontuacao_total > 0:
			score_label.modulate = Color(0.42, 1.0, 0.52, 1.0)
		elif pontuacao_total < 0:
			score_label.modulate = Color(1.0, 0.28, 0.28, 1.0)
		else:
			score_label.modulate = Color(0.86, 1.0, 1.0, 1.0)

	if tiros_label != null:
		tiros_label.text = "%02d / %02d" % [balas_no_cartucho, capacidade_cartucho]

	if acertos_label != null:
		acertos_label.text = str(total_acertos)

	if tiros_total_label != null:
		tiros_total_label.text = str(total_tiros)

	if tiros_panel != null and tiros_label != null and municao_label != null:
		var estilo_tiros := tiros_panel.get_theme_stylebox("panel") as StyleBoxFlat

		if recarregando:
			var pulso_rec: float = 0.70 + (sin(aviso_sem_municao_t * 10.0) * 0.5 + 0.5) * 0.30

			if estilo_tiros != null:
				Leve.prop(estilo_tiros, "bg_color", Color(0.02, 0.12, 0.18, 0.96))
				Leve.prop(estilo_tiros, "border_color", Color(0.22, 0.92, 1.0, 1.0))
				Leve.prop(estilo_tiros, "shadow_color", Color(0.22, 0.92, 1.0, 0.68))

			tiros_label.modulate = Color(0.88, 0.98, 1.0, 1.0)
			municao_label.text = "RECARREGANDO"
			municao_label.modulate = Color(0.30, 0.92, 1.0, pulso_rec)

			if recarga_info_label != null:
				recarga_info_label.text = "AGUARDE %.1fs" % reload_tempo_restante
				recarga_info_label.modulate = Color(0.78, 0.96, 1.0, pulso_rec)

		elif balas_no_cartucho <= 0:
			var pulso_vazio: float = 0.60 + (sin(aviso_sem_municao_t * 12.0) * 0.5 + 0.5) * 0.40

			if estilo_tiros != null:
				Leve.prop(estilo_tiros, "bg_color", Color(0.22, 0.04, 0.05, 0.98))
				Leve.prop(estilo_tiros, "border_color", Color(1.0, 0.12, 0.10, 1.0))
				Leve.prop(estilo_tiros, "shadow_color", Color(1.0, 0.08, 0.06, 0.68))

			tiros_label.modulate = Color(1.0, 0.82, 0.82, pulso_vazio)
			municao_label.text = "RECARREGUE!"
			municao_label.modulate = Color(1.0, 0.24, 0.22, pulso_vazio)

			if recarga_info_label != null:
				recarga_info_label.text = "BOTÃO DIREITO DO MOUSE"
				recarga_info_label.modulate = Color(1.0, 0.72, 0.72, pulso_vazio)

		elif balas_no_cartucho <= alerta_baixa_municao_limite:
			var pulso_crit: float = 0.72 + (sin(aviso_sem_municao_t * 9.0) * 0.5 + 0.5) * 0.28

			if estilo_tiros != null:
				Leve.prop(estilo_tiros, "bg_color", Color(0.20, 0.11, 0.03, 0.98))
				Leve.prop(estilo_tiros, "border_color", Color(1.0, 0.62, 0.12, 1.0))
				Leve.prop(estilo_tiros, "shadow_color", Color(1.0, 0.62, 0.12, 0.62))

			tiros_label.modulate = Color(1.0, 0.95, 0.62, 1.0)
			municao_label.text = "MUNIÇÃO BAIXA"
			municao_label.modulate = Color(1.0, 0.68, 0.18, pulso_crit)

			if recarga_info_label != null:
				recarga_info_label.text = "PREPARE A RECARGA"
				recarga_info_label.modulate = Color(1.0, 0.84, 0.48, pulso_crit)

		else:
			if estilo_tiros != null:
				Leve.prop(estilo_tiros, "bg_color", COR_FUNDO_CARD_MAR)
				Leve.prop(estilo_tiros, "border_color", COR_NEON_MAR)
				Leve.prop(estilo_tiros, "shadow_color", Color(COR_NEON_MAR.r, COR_NEON_MAR.g, COR_NEON_MAR.b, 0.58))

			tiros_label.modulate = Color(1.0, 0.97, 0.84, 1.0)
			municao_label.text = "PRONTO"
			municao_label.modulate = Color(0.82, 1.0, 0.90, 1.0)

			if recarga_info_label != null:
				recarga_info_label.text = "BOTÃO DIREITO RECARREGA"
				recarga_info_label.modulate = Color(0.76, 0.88, 1.0, 0.95)

	if timer_panel != null and timer_label != null:
		var estilo_timer := timer_panel.get_theme_stylebox("panel") as StyleBoxFlat

		if tempo_restante <= 15.0:
			timer_label.modulate = COR_TIMER_CRITICO

			if estilo_timer != null:
				Leve.prop(estilo_timer, "bg_color", COR_PANEL_TIMER_CRITICO)
				Leve.prop(estilo_timer, "border_color", Color(1.0, 0.08, 0.06, 1.0))
				Leve.prop(estilo_timer, "shadow_color", Color(1.0, 0.08, 0.06, 0.68))

		elif tempo_restante <= 40.0:
			timer_label.modulate = COR_TIMER_ALERTA

			if estilo_timer != null:
				Leve.prop(estilo_timer, "bg_color", COR_PANEL_TIMER_ALERTA)
				Leve.prop(estilo_timer, "border_color", Color(1.0, 0.58, 0.10, 1.0))
				Leve.prop(estilo_timer, "shadow_color", Color(1.0, 0.58, 0.10, 0.62))

		else:
			timer_label.modulate = Color.WHITE

			if estilo_timer != null:
				Leve.prop(estilo_timer, "bg_color", COR_FUNDO_CARD_MAR)
				Leve.prop(estilo_timer, "border_color", COR_NEON_MAR)
				Leve.prop(estilo_timer, "shadow_color", Color(COR_NEON_MAR.r, COR_NEON_MAR.g, COR_NEON_MAR.b, 0.58))

	if recarga_info_label != null:
		recarga_info_label.text = ""
		recarga_info_label.visible = false
		
	_atualizar_bombas_hud()
	_atualizar_barra_municao()


func _forcar_visibilidade_recursiva(no: Node) -> void:
	if no is CanvasItem:
		var item: CanvasItem = no as CanvasItem
		item.visible = true
		item.modulate = Color.WHITE
		item.self_modulate = Color.WHITE

	for filho in no.get_children():
		_forcar_visibilidade_recursiva(filho)


func _ativar_animacao_aguaviva(alvo: Area2D) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	var anim: AnimatedSprite2D = _forcar_aguaviva_visivel(alvo)
	if anim == null:
		return

	var variante: String = _obter_variante_aguaviva(alvo)
	var idle_anim: String = _achar_animacao_idle_aguaviva(anim, variante)

	if idle_anim == "":
		return

	anim.position = Vector2.ZERO
	anim.rotation_degrees = 0.0
	anim.scale = Vector2.ONE
	anim.animation = idle_anim
	anim.frame = 0

	if anim.sprite_frames != null and anim.sprite_frames.get_frame_count(idle_anim) > 1:
		anim.play(idle_anim)
	else:
		anim.stop()


func _tocar_hit_aguaviva(alvo: Area2D) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	var anim: AnimatedSprite2D = _forcar_aguaviva_visivel(alvo)
	if anim == null:
		return

	var variante: String = _obter_variante_aguaviva(alvo)
	var hit_anim: String = _achar_animacao_hit_aguaviva(anim, variante)

	if hit_anim == "":
		return

	anim.position = Vector2.ZERO
	anim.rotation_degrees = 0.0
	anim.scale = Vector2.ONE
	anim.animation = hit_anim
	anim.frame = 0

	if anim.sprite_frames != null and anim.sprite_frames.get_frame_count(hit_anim) > 1:
		anim.play(hit_anim)
	else:
		anim.stop()

func _configurar_animacao_spawn(alvo: Area2D) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	_forcar_ativacao_recursiva(alvo)

	var anim: AnimatedSprite2D = _obter_animated_do_alvo(alvo)
	if anim == null:
		push_warning("Alvo sem AnimatedSprite2D: " + str(alvo.name))
		return
	if anim.sprite_frames == null:
		push_warning("AnimatedSprite2D sem SpriteFrames: " + str(alvo.name))
		return

	anim.visible = true
	anim.show()
	anim.process_mode = Node.PROCESS_MODE_INHERIT
	anim.speed_scale = 1.0
	anim.modulate = Color.WHITE
	anim.self_modulate = Color.WHITE
	anim.stop()

	var tipo: String = String(alvo.get_meta("tipo_alvo", ""))

	if tipo == "aguaviva":
		var idle_anim: String = _achar_animacao_idle_aguaviva(anim)

		if idle_anim != "":
			anim.animation = idle_anim
			anim.frame = 0

			if anim.sprite_frames.get_frame_count(idle_anim) > 1:
				anim.play(idle_anim)
			else:
				anim.stop()

			return

		return

	if anim.sprite_frames.has_animation("idle"):
		anim.animation = "idle"
		anim.frame = 0
		anim.play("idle")
		return

	if anim.sprite_frames.has_animation("default"):
		anim.animation = "default"
		anim.frame = 0
		anim.play("default")
		return

	var nomes: PackedStringArray = anim.sprite_frames.get_animation_names()
	if nomes.size() > 0:
		var primeira: String = String(nomes[0])
		anim.animation = primeira
		anim.frame = 0
		anim.play(primeira)


func _configurar_animacao_padrao(alvo: Area2D) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return

	_forcar_ativacao_recursiva(alvo)

	var anim: AnimatedSprite2D = _obter_animated_do_alvo(alvo)
	if anim == null:
		return
	if anim.sprite_frames == null:
		return

	anim.process_mode = Node.PROCESS_MODE_INHERIT
	anim.visible = true
	anim.show()
	anim.speed_scale = 1.0
	anim.stop()

	if anim.sprite_frames.has_animation("idle"):
		anim.animation = "idle"
		anim.set_frame_and_progress(0, 0.0)
		anim.play("idle")
		return

	if anim.sprite_frames.has_animation("default"):
		anim.animation = "default"
		anim.set_frame_and_progress(0, 0.0)
		anim.play("default")
		return

	var nomes: PackedStringArray = anim.sprite_frames.get_animation_names()
	if nomes.size() > 0:
		var primeira: String = String(nomes[0])
		anim.animation = primeira
		anim.set_frame_and_progress(0, 0.0)
		anim.play(primeira)


func _criar_fx_overlay() -> void:
	fx_back_layer = CanvasLayer.new()
	fx_back_layer.name = "FXBackLayer"
	fx_back_layer.layer = 4
	add_child(fx_back_layer)

	fx_back_overlay = Control.new()
	fx_back_overlay.name = "FXBackOverlay"
	fx_back_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_back_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_back_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	fx_back_layer.add_child(fx_back_overlay)

	if not fx_back_overlay.draw.is_connected(_on_fx_back_overlay_draw):
		fx_back_overlay.draw.connect(_on_fx_back_overlay_draw)

	fx_front_layer = CanvasLayer.new()
	fx_front_layer.name = "FXFrontLayer"
	fx_front_layer.layer = 15
	add_child(fx_front_layer)

	fx_front_overlay = Control.new()
	fx_front_overlay.name = "FXFrontOverlay"
	fx_front_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_front_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_front_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	fx_front_layer.add_child(fx_front_overlay)

	if not fx_front_overlay.draw.is_connected(_on_fx_front_overlay_draw):
		fx_front_overlay.draw.connect(_on_fx_front_overlay_draw)

func _on_fx_back_overlay_draw() -> void:
	_desenhar_marcas_agua_back()
	_desenhar_fx_agua_back()

func _on_fx_front_overlay_draw() -> void:
	_desenhar_fx_estilhacos_front()
	_desenhar_fx_moedas_front()
	_desenhar_fx_explosao_bomba_front()


func _atualizar_fx_explosao_bomba(delta: float) -> void:
	for i in range(fx_explosao_bomba.size() - 1, -1, -1):
		var fx: Dictionary = fx_explosao_bomba[i]
		fx["idade"] = float(fx.get("idade", 0.0)) + delta
		fx["pos"] = Vector2(fx.get("pos", Vector2.ZERO)) + Vector2(fx.get("vel", Vector2.ZERO)) * delta
		fx["vel"] = Vector2(fx.get("vel", Vector2.ZERO)) * 0.985
		fx["rot"] = float(fx.get("rot", 0.0)) + float(fx.get("rot_vel", 0.0)) * delta
		fx_explosao_bomba[i] = fx

		if float(fx.get("idade", 0.0)) >= float(fx.get("vida", 1.0)):
			fx_explosao_bomba.remove_at(i)


func _iniciar_contagem_inicio() -> void:
	if contagem_inicio_ativa or partida_iniciada or intro_comeco_ativa:
		return

	contagem_inicio_ativa = true
	contagem_inicio_t = 0.0
	contagem_inicio_etapa = 3

	if aviso_footer_label != null:
		aviso_footer_label.text = "PREPARE-SE"

	_iniciar_intro_comeco()

	contagem_inicio_ativa = false

func _pode_recarregar() -> bool:
	return jogo_ativo \
		and partida_iniciada \
		and not encerrado \
		and not tela_inicio_ativa \
		and not recarregando \
		and balas_no_cartucho < capacidade_cartucho


func _iniciar_recarga() -> void:
	if not _pode_recarregar():
		return

	recarregando = true
	reload_tempo_restante = tempo_recarga_seg

	if som_recharge_stream != null:
		_tocar_som(som_recharge_stream, 0.0, 1.0, 0.0)

	_flash_tela(Color(0.18, 0.86, 1.0, 0.08))
	_set_status("RECARREGANDO...")
	_atualizar_hud()



func _criar_tela_info_inicio() -> void:
	info_inicio_layer = CanvasLayer.new()
	info_inicio_layer.name = "InfoInicioLayer"
	info_inicio_layer.layer = 60
	add_child(info_inicio_layer)

	info_inicio_root = Control.new()
	info_inicio_root.name = "InfoInicioRoot"
	info_inicio_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	info_inicio_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_inicio_layer.add_child(info_inicio_root)

	info_inicio_bg = ColorRect.new()
	info_inicio_bg.name = "InfoInicioBg"
	info_inicio_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	info_inicio_bg.color = Color(0.0, 0.01, 0.03, 0.78)
	info_inicio_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_inicio_root.add_child(info_inicio_bg)

	var glow_img := ColorRect.new()
	glow_img.name = "GlowImagemInicioMar"
	glow_img.color = Color(0.0, 0.62, 1.0, 0.18)
	glow_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_inicio_root.add_child(glow_img)

	var borda_img := ColorRect.new()
	borda_img.name = "BordaImagemInicioMar"
	borda_img.color = COR_NEON_MAR
	borda_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_inicio_root.add_child(borda_img)

	var fundo_img := ColorRect.new()
	fundo_img.name = "FundoImagemInicioMar"
	fundo_img.color = Color(0.005, 0.035, 0.075, 0.96)
	fundo_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_inicio_root.add_child(fundo_img)

	info_inicio_image = TextureRect.new()
	info_inicio_image.name = "InfoInicioImage"
	info_inicio_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_inicio_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	info_inicio_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	info_inicio_image.modulate = Color(0.92, 0.98, 1.0, 1.0)
	info_inicio_root.add_child(info_inicio_image)

	if ResourceLoader.exists(caminho_info_inicio):
		info_inicio_image.texture = load(caminho_info_inicio)
	else:
		push_error("Imagem de início não encontrada: " + caminho_info_inicio)

	info_inicio_label = Label.new()
	info_inicio_label.name = "InfoInicioLabel"
	info_inicio_label.text = "ATIRE PARA COMEÇAR"
	info_inicio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_inicio_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_inicio_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Leve.font_size(info_inicio_label, "font_size", 48)
	Leve.color(info_inicio_label, "font_color", COR_NEON_MAR_CLARO)
	Leve.color(info_inicio_label, "font_outline_color", Color(0.0, 0.05, 0.12, 1.0))
	Leve.constant(info_inicio_label, "outline_size", 10)
	info_inicio_label.self_modulate = Color(0.88, 0.98, 1.0, 1.0)

	if fonte_luckiest != null:
		Leve.font(info_inicio_label, "font", fonte_luckiest)
	elif ResourceLoader.exists(FONTE_LUCKIEST):
		Leve.font(info_inicio_label, "font", load(FONTE_LUCKIEST))

	info_inicio_root.add_child(info_inicio_label)
	info_inicio_root.visible = true



func _finalizar_recarga() -> void:
	recarregando = false
	reload_tempo_restante = 0.0
	balas_no_cartucho = capacidade_cartucho
	_flash_tela(Color(0.42, 1.0, 0.88, 0.10))
	_set_status("MUNIÇÃO COMPLETA")
	_atualizar_hud()


func _forcar_mira_sobre_modal_ranking() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	if ranking_nome_root != null:
		ranking_nome_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if ranking_nome_bg != null:
		ranking_nome_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if ranking_nome_panel != null:
		ranking_nome_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if ranking_nome_teclado != null:
		ranking_nome_teclado.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if ranking_nome_btn_ok != null:
		ranking_nome_btn_ok.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if ranking_nome_btn_apagar != null:
		ranking_nome_btn_apagar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if alvo_layer != null:
		alvo_layer.layer = 250

	if alvo_overlay != null:
		alvo_overlay.visible = true
		alvo_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		alvo_overlay.queue_redraw()



func _modo_dificil_sem_mira() -> bool:
	var dificuldade: String = get_tree().get_meta("modo_dificuldade", "facil")
	return dificuldade == "dificil" and not ranking_nome_ativo


const BOTAO_GATILHO_1: int = MOUSE_BUTTON_RIGHT
const BOTAO_GATILHO_2: int = MOUSE_BUTTON_LEFT

const BOTAO_RECARGA_1: int = MOUSE_BUTTON_MIDDLE
const BOTAO_RECARGA_2: int = MOUSE_BUTTON_XBUTTON1
const BOTAO_RECARGA_3: int = MOUSE_BUTTON_XBUTTON2

var tempo_trava_input_arma: float = 0.0


func _pos_arma() -> Vector2:
	return Tela.mouse()


func _evento_tiro_arma(me: InputEventMouseButton) -> bool:
	# Gatilho = clique esquerdo (Maquina cuida dos botões aprendidos da arma).
	return Maquina.e_tiro_arma(me)


func _evento_recarga_arma(me: InputEventMouseButton) -> bool:
	# Recarga = botão aprendido na configuração (padrão: direito/meio/laterais).
	return Maquina.e_recarga_arma(me)


func _debug_botao_arma(me: InputEventMouseButton) -> void:
	print("BOTAO ARMA MAR: ", me.button_index)


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
	if ranking_nome_ativo:
		_ranking_tentar_atirar_tecla(alvo_pos)
		return

	if tempo_trava_input_arma > 0.0:
		return

	tempo_trava_input_arma = 0.10

	if encerrado:
		return

	if fim_cutscene_ativa:
		return

	if tela_inicio_ativa:
		_iniciar_intro_comeco()
		return

	if intro_comeco_ativa:
		return

	if jogo_ativo and partida_iniciada:
		_processar_tiro_global(alvo_pos)


func _executar_recarga_arma() -> void:
	if ranking_nome_ativo:
		return

	if tempo_trava_input_arma > 0.0:
		return

	tempo_trava_input_arma = 0.10

	if encerrado:
		return

	if fim_cutscene_ativa:
		return

	if jogo_ativo and partida_iniciada and not recarregando:
		_iniciar_recarga()



func _ranking_tentar_atirar_tecla(pos_tiro: Vector2) -> void:
	if not ranking_nome_ativo:
		return

	if ranking_trava_tecla_tiro:
		return

	ranking_trava_tecla_tiro = true

	_tocar_som(som_tiro_stream, -1.5, randf_range(0.98, 1.03))

	if ranking_nome_teclado != null:
		for child in ranking_nome_teclado.get_children():
			if child is Button:
				var btn := child as Button
				var rect := Rect2(btn.global_position, btn.size)

				if rect.has_point(pos_tiro):
					_ranking_tecla_letra(btn.text)
					_fx_tecla_ranking(btn)
					await get_tree().create_timer(0.18).timeout
					ranking_trava_tecla_tiro = false
					return

	if ranking_nome_btn_apagar != null:
		var rect_apagar := Rect2(
			ranking_nome_btn_apagar.global_position,
			ranking_nome_btn_apagar.size
		)

		if rect_apagar.has_point(pos_tiro):
			_ranking_apagar_letra()
			_fx_tecla_ranking(ranking_nome_btn_apagar)
			await get_tree().create_timer(0.18).timeout
			ranking_trava_tecla_tiro = false
			return

	if ranking_nome_btn_ok != null:
		var rect_ok := Rect2(
			ranking_nome_btn_ok.global_position,
			ranking_nome_btn_ok.size
		)

		if rect_ok.has_point(pos_tiro):
			_fx_tecla_ranking(ranking_nome_btn_ok)
			_confirmar_nome_ranking(false)
			await get_tree().create_timer(0.18).timeout
			ranking_trava_tecla_tiro = false
			return

	await get_tree().create_timer(0.08).timeout
	ranking_trava_tecla_tiro = false



func _fx_tecla_ranking(btn: Button) -> void:
	if btn == null:
		return

	var escala_original: Vector2 = btn.scale

	var tw := create_tween()
	tw.tween_property(btn, "scale", escala_original * 1.12, 0.06)
	tw.tween_property(btn, "scale", escala_original, 0.10)


func _aplicar_config_admin_na_cena() -> void:
	var cfg_admin := ConfigFile.new()
	var err := cfg_admin.load("user://config_admin.cfg")

	if err != OK:
		return

	tempo_partida = float(
		cfg_admin.get_value("jogo", "tempo_partida", tempo_partida)
	)

	tempo_auto_retorno_menu_seg = float(
		cfg_admin.get_value("jogo", "tempo_modal_final", tempo_auto_retorno_menu_seg)
	)

	ranking_nome_tempo = float(
		cfg_admin.get_value("ranking", "tempo_nome", ranking_nome_tempo)
	)

	get_tree().set_meta("admin_tempo_partida", tempo_partida)
	get_tree().set_meta("admin_tempo_modal_final", tempo_auto_retorno_menu_seg)
	get_tree().set_meta("admin_tempo_ranking_nome", ranking_nome_tempo)


func _carregar_fontes_ui() -> void:
	if ResourceLoader.exists(FONTE_TEXTO):
		fonte_orbitron = load(FONTE_TEXTO) as FontFile

	if ResourceLoader.exists(FONTE_LUCKIEST):
		fonte_luckiest = load(FONTE_LUCKIEST) as FontFile


func _fonte_titulo(lbl: Label, tamanho: int, cor: Color = COR_NEON_MAR_CLARO) -> void:
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


func _estilo_card_mar() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_FUNDO_CARD_MAR
	estilo.border_width_left = 4
	estilo.border_width_top = 4
	estilo.border_width_right = 4
	estilo.border_width_bottom = 4
	estilo.border_color = COR_NEON_MAR
	estilo.corner_radius_top_left = 34
	estilo.corner_radius_top_right = 34
	estilo.corner_radius_bottom_left = 34
	estilo.corner_radius_bottom_right = 34
	estilo.shadow_color = Color(COR_NEON_MAR.r, COR_NEON_MAR.g, COR_NEON_MAR.b, 0.58)
	estilo.shadow_size = 34
	estilo.shadow_offset = Vector2.ZERO
	return estilo


func _aplicar_painel_neon_mar(painel: Control) -> void:
	if painel == null:
		return

	if painel is Panel:
		(painel as Panel).add_theme_stylebox_override("panel", _estilo_card_mar())


func _estilo_modal_neon_mar() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.010, 0.030, 0.060, 0.985)
	estilo.border_color = COR_NEON_MAR
	estilo.border_width_left = 5
	estilo.border_width_top = 5
	estilo.border_width_right = 5
	estilo.border_width_bottom = 5
	estilo.corner_radius_top_left = 34
	estilo.corner_radius_top_right = 34
	estilo.corner_radius_bottom_left = 34
	estilo.corner_radius_bottom_right = 34
	estilo.shadow_color = Color(0.0, 0.80, 1.0, 0.55)
	estilo.shadow_size = 42
	estilo.shadow_offset = Vector2.ZERO
	return estilo


func _estilo_faixa_topo_mar() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.035, 0.085, 0.145, 0.97)
	estilo.border_color = Color(0.22, 0.92, 1.0, 0.55)
	estilo.border_width_left = 2
	estilo.border_width_top = 2
	estilo.border_width_right = 2
	estilo.border_width_bottom = 2
	estilo.corner_radius_top_left = 22
	estilo.corner_radius_top_right = 22
	estilo.corner_radius_bottom_left = 22
	estilo.corner_radius_bottom_right = 22
	estilo.shadow_color = Color(0.0, 0.70, 1.0, 0.30)
	estilo.shadow_size = 16
	estilo.shadow_offset = Vector2.ZERO
	return estilo


func _estilo_faixa_interna_mar(cor: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.border_color = Color(0.22, 0.92, 1.0, 0.40)
	estilo.border_width_left = 2
	estilo.border_width_top = 2
	estilo.border_width_right = 2
	estilo.border_width_bottom = 2
	estilo.corner_radius_top_left = 20
	estilo.corner_radius_top_right = 20
	estilo.corner_radius_bottom_left = 20
	estilo.corner_radius_bottom_right = 20
	estilo.shadow_color = Color(0.0, 0.70, 1.0, 0.30)
	estilo.shadow_size = 14
	estilo.shadow_offset = Vector2.ZERO
	return estilo
