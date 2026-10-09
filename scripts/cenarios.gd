extends Control

const Pincel := preload("res://scripts/pincel.gd")
const CENA_CENARIO_1: String = "res://scenes/deserto.tscn"
const CENA_CENARIO_2: String = "res://scenes/mar.tscn"
const CENA_CENARIO_3: String = "res://scenes/bar.tscn"
const CENA_CENARIO_4: String = "res://scenes/arena.tscn"
const CENA_RANKING: String = "res://scenes/ranking.tscn"

const CAMINHO_SOM_TIRO: String = "res://songs/tiro-de-pistola.mp3"
const CAMINHO_THEME: String = "res://songs/theme.ogg"
const CAMINHO_SOM_CHOICE: String = "res://songs/choice.mp3"
const ACAO_TIRO_MENU: String = "input_shot"

const TEMPO_AUTO_ALEATORIO: float = 15.0
const TEMPO_ESCOLHA_DIFICULDADE: float = 20.0

const CAMINHO_IMG_1: String = "res://sprites/cene_desert.png"
const CAMINHO_IMG_2: String = "res://sprites/cene_mar.png"
const CAMINHO_IMG_3: String = "res://sprites/cene_bar.png"
const CAMINHO_IMG_4: String = "res://sprites/cene_arena.png"

const CAMINHO_TEASER_DESERTO: String = "res://background_video/teaser_desert.ogv"
const CAMINHO_TEASER_MAR: String = "res://background_video/teaser_mar.ogv"
const CAMINHO_TEASER_BAR: String = "res://background_video/teaser_bar.ogv"
const CAMINHO_TEASER_ARENA: String = "res://background_video/teaser_arena.ogv"

const DIFICULDADES: Array[int] = [2, 2, 3, 3]

# ── Sensibilidade ─────────────────────────────────────────────────────────────
const SENS_XBOX_MIN: float = 1500.0
const SENS_XBOX_MAX: float = 1500.0      # antes 2000
const SENS_XBOX_PADRAO: float = 5000.0   # antes 2000
const SENS_MOUSE_MIN: float = 0.2
const SENS_MOUSE_MAX: float = 3.0
const SENS_MOUSE_PADRAO: float = 1.0
const META_SENS_XBOX: String = "sensibilidade_xbox"
const META_SENS_MOUSE: String = "sensibilidade_mouse"


const FONTE_GOOGLE: String = "res://fonts/Exo2-Bold.ttf"
var fonte_google: FontFile = null

@export_file("*.ogv") var caminho_video_background: String = "res://background_video/back_init.ogv"

@onready var background: VideoStreamPlayer = $Background
@onready var titulo: Label = $Titulo
@onready var grid: GridContainer = $GridContainer
@onready var botao_ranking: Button = $BotaoRanking

@onready var card_1: Panel = $GridContainer/CardCenario1
@onready var card_2: Panel = $GridContainer/CardCenario2
@onready var card_3: Panel = $GridContainer/CardCenario3
@onready var card_4: Panel = $GridContainer/CardCenario4

@onready var botao_cenario_1: TextureButton = $GridContainer/CardCenario1/Cenario1
@onready var botao_cenario_2: TextureButton = $GridContainer/CardCenario2/Cenario2
@onready var botao_cenario_3: TextureButton = $GridContainer/CardCenario3/Cenario3
@onready var botao_cenario_4: TextureButton = $GridContainer/CardCenario4/Cenario4

@onready var nome_1: Label = $GridContainer/CardCenario1/Nome1
@onready var nome_2: Label = $GridContainer/CardCenario2/Nome2
@onready var nome_3: Label = $GridContainer/CardCenario3/Nome3
@onready var nome_4: Label = $GridContainer/CardCenario4/Nome4

@export var usar_controle_xbox: bool = true
@export var velocidade_mira_xbox: float = 920.0
@export var deadzone_xbox: float = 0.18
@export var xbox_botao_tiro: int = JOY_BUTTON_RIGHT_SHOULDER

@export var sensibilidade_mouse: float = 1.0
var mouse_delta_acumulado: Vector2 = Vector2.ZERO
var ultimo_mouse_pos: Vector2 = Vector2.ZERO

var xbox_mira_iniciada: bool = false
var card_hover_atual: Panel = null
var tween_ranking_pulso: Tween = null
var tween_titulo: Tween = null

var estilo_card_normal: StyleBoxFlat
var estilo_card_hover: StyleBoxFlat
var estilo_card_destaque: StyleBoxFlat
var estilo_ranking_normal: StyleBoxFlat
var estilo_ranking_hover: StyleBoxFlat

var fundo_preto: ColorRect = null
var fade_layer: CanvasLayer = null
var fade_rect: ColorRect = null

var audio_tiro_player: AudioStreamPlayer = null
var audio_theme_player: AudioStreamPlayer = null
var audio_choice_player: AudioStreamPlayer = null

var som_tiro: AudioStream = null
var som_choice: AudioStream = null

var alvo_layer: CanvasLayer = null
var alvo_overlay: Control = null
var alvo_pos: Vector2 = Vector2.ZERO
var alvo_anim_t: float = 0.0

var contador_layer: CanvasLayer = null
var contador_root: Control = null
var contador_panel: Panel = null
var contador_linha: ColorRect = null
var contador_label: Label = null
var contador_titulo: Label = null

var entrada_bloqueada: bool = false
var aleatorio_em_andamento: bool = false
var tempo_restante_auto: float = TEMPO_AUTO_ALEATORIO
var auto_timer_ativo: bool = true

var estrelas_1: HBoxContainer = null
var estrelas_2: HBoxContainer = null
var estrelas_3: HBoxContainer = null
var estrelas_4: HBoxContainer = null

var background_secundario: VideoStreamPlayer = null
var usando_background_a: bool = true

var ranking_hover_ativo: bool = false
var sens_hover_ativo: bool = false
const MARGEM_HOVER_BOTAO: float = 10.0

# ── Modal de dificuldade ──────────────────────────────────────────────────────
var modal_layer: CanvasLayer = null
var modal_root: Control = null
var modal_panel: Panel = null
var modal_titulo_label: Label = null
var modal_subtitulo: Label = null
var modal_contador: Label = null
var modal_botao_facil: Button = null
var modal_botao_dificil: Button = null
var modal_barra_progresso: ColorRect = null
var modal_ativo: bool = false
var modal_tempo_restante: float = TEMPO_ESCOLHA_DIFICULDADE
var modal_cena_destino: String = ""

# ── Modal de sensibilidade ────────────────────────────────────────────────────
var botao_sensibilidade: Button = null
var modal_sens_layer: CanvasLayer = null
var modal_sens_root: Control = null
var modal_sens_panel: Panel = null
var modal_sens_ativo: bool = false
var slider_xbox: HSlider = null
var slider_mouse: HSlider = null
var label_valor_xbox: Label = null
var label_valor_mouse: Label = null
var estilo_botao_sens_normal: StyleBoxFlat = null
var estilo_botao_sens_hover: StyleBoxFlat = null


var background_atual_caminho: String = ""
var background_troca_id: int = 0
var background_tween: Tween = null
@export var delay_troca_background_hover: float = 0.18




# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	randomize()

	_aplicar_sensibilidade_menu()

	var centro := get_viewport_rect().size * 0.5
	alvo_pos = centro
	ultimo_mouse_pos = centro
	mouse_delta_acumulado = Vector2.ZERO

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	_criar_estilos()
	_configurar_audio()
	_configurar_base_fundo()
	_configurar_background()

	call_deferred("_ajustar_background_fullscreen")
	
	_carregar_fonte_google()

	_configurar_layout()
	_configurar_cards()
	_configurar_botoes()
	_configurar_textos()
	_configurar_imagens_e_estrelas()
	_configurar_botao_ranking()

	_inicializar_sensibilidade()

	_configurar_contador()
	_configurar_alvo_overlay()
	_configurar_fade()
	_preparar_abertura_suave()

	_iniciar_pulso_ranking()
	_tocar_theme_com_delay()

	call_deferred("_reaplicar_layout")



func _preparar_abertura_suave() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if fade_rect == null:
		return

	fade_rect.color = Color.BLACK
	fade_rect.visible = true

	if background != null:
		background.modulate.a = 0.0

	if background_secundario != null:
		background_secundario.modulate.a = 0.0

	if contador_panel != null:
		contador_panel.modulate.a = 0.0
		contador_panel.scale = Vector2(0.94, 0.94)

	if contador_titulo != null:
		contador_titulo.modulate.a = 0.0

	if contador_label != null:
		contador_label.modulate.a = 0.0

	if grid != null:
		grid.modulate.a = 0.0
		grid.scale = Vector2(0.96, 0.96)

	var cards: Array[Panel] = [card_1, card_2, card_3, card_4]
	for card in cards:
		if card != null:
			card.modulate.a = 0.0
			card.scale = Vector2(0.92, 0.92)

	if botao_ranking != null:
		botao_ranking.modulate.a = 0.0
		botao_ranking.scale = Vector2(0.94, 0.94)

	if botao_sensibilidade != null:
		botao_sensibilidade.modulate.a = 0.0
		botao_sensibilidade.scale = Vector2(0.94, 0.94)

	call_deferred("_animar_abertura_suave")



func _animar_abertura_suave() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	await get_tree().process_frame
	await get_tree().process_frame

	var tw := create_tween()
	tw.set_parallel(true)

	if background != null:
		tw.tween_property(background, "modulate:a", 1.0, 0.38)

	if fade_rect != null:
		tw.tween_property(fade_rect, "color:a", 0.0, 0.52)

	if contador_panel != null:
		tw.tween_property(contador_panel, "modulate:a", 1.0, 0.42).set_delay(0.10)
		tw.tween_property(contador_panel, "scale", Vector2.ONE, 0.42).set_delay(0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if contador_titulo != null:
		tw.tween_property(contador_titulo, "modulate:a", 1.0, 0.34).set_delay(0.18)

	if contador_label != null:
		tw.tween_property(contador_label, "modulate:a", 1.0, 0.34).set_delay(0.24)

	if grid != null:
		tw.tween_property(grid, "modulate:a", 1.0, 0.42).set_delay(0.24)
		tw.tween_property(grid, "scale", Vector2.ONE, 0.42).set_delay(0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var cards: Array[Panel] = [card_1, card_2, card_3, card_4]
	for i in range(cards.size()):
		var card := cards[i]
		if card != null:
			var d := 0.30 + float(i) * 0.07
			tw.tween_property(card, "modulate:a", 1.0, 0.34).set_delay(d)
			tw.tween_property(card, "scale", Vector2.ONE, 0.34).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if botao_ranking != null:
		tw.tween_property(botao_ranking, "modulate:a", 1.0, 0.34).set_delay(0.62)
		tw.tween_property(botao_ranking, "scale", Vector2.ONE, 0.34).set_delay(0.62).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if botao_sensibilidade != null:
		tw.tween_property(botao_sensibilidade, "modulate:a", 1.0, 0.34).set_delay(0.68)
		tw.tween_property(botao_sensibilidade, "scale", Vector2.ONE, 0.34).set_delay(0.68).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tw.finished

	if fade_rect != null:
		fade_rect.visible = false



func _carregar_fonte_google() -> void:
	if ResourceLoader.exists(FONTE_GOOGLE):
		fonte_google = load(FONTE_GOOGLE) as FontFile
	else:
		push_warning("Fonte Google não encontrada: " + FONTE_GOOGLE)


func _aplicar_fonte_label(
	lbl: Label,
	tamanho: int,
	cor: Color = Color.WHITE,
	outline: int = 8
) -> void:
	if lbl == null:
		return

	if fonte_google != null:
		Leve.font(lbl, "font", fonte_google)

	Leve.font_size(lbl, "font_size", tamanho)
	Leve.color(lbl, "font_color", cor)
	Leve.color(lbl, "font_outline_color", Color.BLACK)
	Leve.constant(lbl, "outline_size", outline)
	Leve.color(lbl, "font_shadow_color", Color(1.0, 0.0, 0.0, 0.65))
	Leve.constant(lbl, "shadow_offset_x", 0)
	Leve.constant(lbl, "shadow_offset_y", 0)


func _aplicar_fonte_botao(
	btn: Button,
	tamanho: int,
	cor: Color = Color.WHITE
) -> void:
	if btn == null:
		return

	if fonte_google != null:
		Leve.font(btn, "font", fonte_google)

	Leve.font_size(btn, "font_size", tamanho)
	Leve.color(btn, "font_color", cor)
	Leve.color(btn, "font_hover_color", Color.WHITE)
	Leve.color(btn, "font_pressed_color", Color.WHITE)
	Leve.color(btn, "font_outline_color", Color.BLACK)
	Leve.constant(btn, "outline_size", 7)


func _aplicar_sensibilidade_menu() -> void:
	if get_tree().has_meta(META_SENS_XBOX):
		velocidade_mira_xbox = float(
			get_tree().get_meta(META_SENS_XBOX)
		)
	else:
		velocidade_mira_xbox = SENS_XBOX_MAX

	if get_tree().has_meta(META_SENS_MOUSE):
		sensibilidade_mouse = float(
			get_tree().get_meta(META_SENS_MOUSE)
		)
	else:
		sensibilidade_mouse = SENS_MOUSE_PADRAO

	velocidade_mira_xbox = clamp(
		velocidade_mira_xbox,
		SENS_XBOX_MIN,
		SENS_XBOX_MAX
	)

	sensibilidade_mouse = clamp(
		sensibilidade_mouse,
		SENS_MOUSE_MIN,
		SENS_MOUSE_MAX
	)



func _exit_tree() -> void:
	if background != null and background.is_playing():
		background.stop()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
	if modal_sens_ativo:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_HIDDEN:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
			# Ao entrar no modal, teleporta o cursor OS para onde a mira já está.
			# Sem isso o cursor reaparece no último ponto do sistema e o hover
			# dos botões fica deslocado em relação à mira desenhada.
			Tela.warp_mouse(alvo_pos)
	else:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
 
	tempo_trava_input_menu = max(0.0, tempo_trava_input_menu - delta)
	_atualizar_mira_menu(delta)
 
	# Com cursor em HIDDEN, sobrescreve alvo_pos com a posição real do mouse.
	# _atualizar_mira_menu usa deltas acumulados (modo capturado), então
	# precisamos corrigir aqui para manter mira e hover perfeitamente alinhados.
	if modal_sens_ativo:
		var tela := get_viewport_rect().size
		alvo_pos = Tela.mouse()
		alvo_pos.x = clampf(alvo_pos.x, 0.0, tela.x)
		alvo_pos.y = clampf(alvo_pos.y, 0.0, tela.y)
 
	alvo_anim_t += delta
 
	if modal_ativo:
		_atualizar_hover_modal_dificuldade()
	else:
		_atualizar_hover_cards_por_alvo()
		_atualizar_hover_botoes()
 
	if alvo_overlay != null:
		alvo_overlay.queue_redraw()
 
	if auto_timer_ativo \
	and not aleatorio_em_andamento \
	and not entrada_bloqueada \
	and not modal_sens_ativo \
	and not modal_ativo:
		tempo_restante_auto = max(0.0, tempo_restante_auto - delta)
		_atualizar_contador()
		if tempo_restante_auto <= 0.0:
			auto_timer_ativo = false
			_iniciar_modo_aleatorio()
 
	if modal_ativo:
		modal_tempo_restante = max(0.0, modal_tempo_restante - delta)
		_atualizar_modal_contador()
		if modal_tempo_restante <= 0.0:
			modal_ativo = false
			get_tree().set_meta("modo_dificuldade", "facil")
			_fechar_modal_e_ir()



func _atualizar_hover_modal_dificuldade() -> void:
	if not modal_ativo:
		return

	if modal_botao_facil != null:
		var r_facil := Rect2(
			modal_botao_facil.global_position,
			modal_botao_facil.size
		)

		if r_facil.has_point(alvo_pos):
			modal_botao_facil.scale = Vector2(1.06, 1.06)
			modal_botao_facil.modulate = Color(1.12, 1.12, 1.12, 1.0)
		else:
			modal_botao_facil.scale = Vector2.ONE
			modal_botao_facil.modulate = Color.WHITE

	if modal_botao_dificil != null:
		var r_dificil := Rect2(
			modal_botao_dificil.global_position,
			modal_botao_dificil.size
		)

		if r_dificil.has_point(alvo_pos):
			modal_botao_dificil.scale = Vector2(1.06, 1.06)
			modal_botao_dificil.modulate = Color(1.12, 1.12, 1.12, 1.0)
		else:
			modal_botao_dificil.scale = Vector2.ONE
			modal_botao_dificil.modulate = Color.WHITE


func _atualizar_mira_menu(delta: float) -> void:
	var tela := get_viewport_rect().size

	# ==========================
	# MOUSE COM DPI
	# ==========================
	if mouse_delta_acumulado.length_squared() > 0.0:

		alvo_pos += (
			mouse_delta_acumulado
			* sensibilidade_mouse
		)

		mouse_delta_acumulado = Vector2.ZERO

	# ==========================
	# XBOX
	# ==========================
	if usar_controle_xbox \
	and Input.get_connected_joypads().size() > 0:

		var eixo_x := Input.get_joy_axis(
			0,
			JOY_AXIS_LEFT_X
		)

		var eixo_y := Input.get_joy_axis(
			0,
			JOY_AXIS_LEFT_Y
		)

		if abs(eixo_x) < deadzone_xbox:
			eixo_x = 0.0

		if abs(eixo_y) < deadzone_xbox:
			eixo_y = 0.0

		alvo_pos.x += (
			eixo_x
			* velocidade_mira_xbox
			* delta
		)

		alvo_pos.y += (
			eixo_y
			* velocidade_mira_xbox
			* delta
		)

	# LIMITES DA TELA
	alvo_pos.x = clampf(
		alvo_pos.x,
		0.0,
		tela.x
	)

	alvo_pos.y = clampf(
		alvo_pos.y,
		0.0,
		tela.y
	)



func _atualizar_hover_botoes() -> void:
	if modal_ativo or modal_sens_ativo:
		_set_hover_ranking(false)
		_set_hover_sensibilidade(false)
		return

	if botao_ranking != null:
		var r_rank := Rect2(
			botao_ranking.position,
			botao_ranking.size
		).grow(MARGEM_HOVER_BOTAO)

		_set_hover_ranking(r_rank.has_point(alvo_pos))

	if botao_sensibilidade != null:
		var r_sens := Rect2(
			botao_sensibilidade.position,
			botao_sensibilidade.size
		).grow(MARGEM_HOVER_BOTAO)

		_set_hover_sensibilidade(r_sens.has_point(alvo_pos))


func _set_hover_ranking(ativo: bool) -> void:
	if ranking_hover_ativo == ativo:
		return

	ranking_hover_ativo = ativo

	if ativo:
		_on_hover_ranking()
	else:
		_on_sair_hover_ranking()


func _set_hover_sensibilidade(ativo: bool) -> void:
	if sens_hover_ativo == ativo:
		return

	sens_hover_ativo = ativo

	if ativo:
		_on_hover_sensibilidade()
	else:
		_on_sair_hover_sensibilidade()


var _ultimo_tamanho_vp: Vector2 = Vector2.ZERO



func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var tamanho_atual := get_viewport_rect().size
		if tamanho_atual != _ultimo_tamanho_vp:
			_ultimo_tamanho_vp = tamanho_atual
			_ajustar_background_fullscreen()


func _reaplicar_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	_configurar_base_fundo()
	_configurar_layout()
	_configurar_cards()
	_configurar_botoes()
	_configurar_textos()
	_configurar_imagens_e_estrelas()
	_configurar_botao_ranking()
	_reposicionar_botao_sensibilidade()  # ← NOVO: reposiciona junto com ranking
	_configurar_contador()
	_atualizar_contador()
	_ajustar_background_fullscreen()


# ─────────────────────────────────────────────────────────────────────────────
# ESTILOS
# ─────────────────────────────────────────────────────────────────────────────
func _criar_estilos() -> void:
	var raio_card: int = 42

	estilo_card_normal = StyleBoxFlat.new()
	estilo_card_normal.bg_color = Color(0.0, 0.0, 0.0, 0.18)
	estilo_card_normal.border_width_left = 3
	estilo_card_normal.border_width_top = 3
	estilo_card_normal.border_width_right = 3
	estilo_card_normal.border_width_bottom = 3
	estilo_card_normal.border_color = Color(0.95, 0.02, 0.02, 0.95)
	estilo_card_normal.corner_radius_top_left = raio_card
	estilo_card_normal.corner_radius_top_right = raio_card
	estilo_card_normal.corner_radius_bottom_right = raio_card
	estilo_card_normal.corner_radius_bottom_left = raio_card
	estilo_card_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	estilo_card_normal.shadow_size = 18
	estilo_card_normal.shadow_offset = Vector2(0, 8)

	estilo_card_hover = StyleBoxFlat.new()
	estilo_card_hover.bg_color = Color(0.02, 0.0, 0.0, 0.24)
	estilo_card_hover.border_width_left = 4
	estilo_card_hover.border_width_top = 4
	estilo_card_hover.border_width_right = 4
	estilo_card_hover.border_width_bottom = 4
	estilo_card_hover.border_color = Color(1.0, 0.02, 0.02, 1.0)
	estilo_card_hover.corner_radius_top_left = raio_card
	estilo_card_hover.corner_radius_top_right = raio_card
	estilo_card_hover.corner_radius_bottom_right = raio_card
	estilo_card_hover.corner_radius_bottom_left = raio_card
	estilo_card_hover.shadow_color = Color(1.0, 0.02, 0.02, 0.34)
	estilo_card_hover.shadow_size = 24
	estilo_card_hover.shadow_offset = Vector2(0, 10)

	estilo_card_destaque = StyleBoxFlat.new()
	estilo_card_destaque.bg_color = Color(0.03, 0.0, 0.0, 0.30)
	estilo_card_destaque.border_width_left = 4
	estilo_card_destaque.border_width_top = 4
	estilo_card_destaque.border_width_right = 4
	estilo_card_destaque.border_width_bottom = 4
	estilo_card_destaque.border_color = Color(1.0, 0.04, 0.04, 1.0)
	estilo_card_destaque.corner_radius_top_left = raio_card
	estilo_card_destaque.corner_radius_top_right = raio_card
	estilo_card_destaque.corner_radius_bottom_right = raio_card
	estilo_card_destaque.corner_radius_bottom_left = raio_card
	estilo_card_destaque.shadow_color = Color(1.0, 0.02, 0.02, 0.42)
	estilo_card_destaque.shadow_size = 28
	estilo_card_destaque.shadow_offset = Vector2(0, 10)

	estilo_ranking_normal = StyleBoxFlat.new()
	estilo_ranking_normal.bg_color = Color(0.02, 0.02, 0.025, 0.96)
	estilo_ranking_normal.corner_radius_top_left = 39
	estilo_ranking_normal.corner_radius_top_right = 39
	estilo_ranking_normal.corner_radius_bottom_right = 39
	estilo_ranking_normal.corner_radius_bottom_left = 39
	estilo_ranking_normal.border_width_left = 2
	estilo_ranking_normal.border_width_top = 2
	estilo_ranking_normal.border_width_right = 2
	estilo_ranking_normal.border_width_bottom = 2
	estilo_ranking_normal.border_color = Color(1.0, 0.02, 0.02, 1.0)
	estilo_ranking_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	estilo_ranking_normal.shadow_size = 21
	estilo_ranking_normal.shadow_offset = Vector2(0, 6)

	estilo_ranking_hover = StyleBoxFlat.new()
	estilo_ranking_hover.bg_color = Color(0.12, 0.0, 0.0, 1.0)
	estilo_ranking_hover.corner_radius_top_left = 30
	estilo_ranking_hover.corner_radius_top_right = 30
	estilo_ranking_hover.corner_radius_bottom_right = 30
	estilo_ranking_hover.corner_radius_bottom_left = 30
	estilo_ranking_hover.border_width_left = 2
	estilo_ranking_hover.border_width_top = 2
	estilo_ranking_hover.border_width_right = 2
	estilo_ranking_hover.border_width_bottom = 2
	estilo_ranking_hover.border_color = Color(1.0, 1.0, 1.0, 1.0)
	estilo_ranking_hover.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	estilo_ranking_hover.shadow_size = 27
	estilo_ranking_hover.shadow_offset = Vector2(0, 7)


# ─────────────────────────────────────────────────────────────────────────────
# ÁUDIO
# ─────────────────────────────────────────────────────────────────────────────
func _configurar_audio() -> void:
	if audio_choice_player == null:
		audio_choice_player = AudioStreamPlayer.new()
		audio_choice_player.name = "AudioChoice"
		audio_choice_player.bus = "Master"
		add_child(audio_choice_player)

	if audio_theme_player == null:
		audio_theme_player = AudioStreamPlayer.new()
		audio_theme_player.name = "AudioTheme"
		audio_theme_player.bus = "Master"
		audio_theme_player.autoplay = false
		audio_theme_player.volume_db = -6.0
		add_child(audio_theme_player)

	if audio_tiro_player == null:
		audio_tiro_player = AudioStreamPlayer.new()
		audio_tiro_player.name = "AudioTiro"
		audio_tiro_player.bus = "Master"
		audio_tiro_player.volume_db = 0.0
		add_child(audio_tiro_player)

	if ResourceLoader.exists(CAMINHO_SOM_CHOICE):
		som_choice = load(CAMINHO_SOM_CHOICE)
	else:
		push_warning("Som não encontrado: " + CAMINHO_SOM_CHOICE)

	if ResourceLoader.exists(CAMINHO_SOM_TIRO):
		som_tiro = load(CAMINHO_SOM_TIRO)
	else:
		push_warning("Som de tiro não encontrado: " + CAMINHO_SOM_TIRO)

	if ResourceLoader.exists(CAMINHO_THEME):
		audio_theme_player.stream = load(CAMINHO_THEME)
	else:
		push_warning("Theme não encontrado: " + CAMINHO_THEME)


func _tocar_theme_com_delay() -> void:
	await get_tree().create_timer(1.0).timeout
	if audio_theme_player != null and audio_theme_player.stream != null:
		audio_theme_player.play(3.0)


func _tocar_tiro() -> void:
	if som_tiro == null or audio_tiro_player == null:
		return
	audio_tiro_player.stop()
	audio_tiro_player.stream = som_tiro
	audio_tiro_player.play()


func _tocar_choice() -> void:
	if som_choice == null or audio_choice_player == null:
		return
	audio_choice_player.stop()
	audio_choice_player.stream = som_choice
	audio_choice_player.play()


# ─────────────────────────────────────────────────────────────────────────────
# FUNDO / BACKGROUND
# ─────────────────────────────────────────────────────────────────────────────
func _configurar_base_fundo() -> void:
	if fundo_preto == null:
		fundo_preto = ColorRect.new()
		fundo_preto.name = "FundoPreto"
		fundo_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fundo_preto)

	fundo_preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo_preto.offset_left = 0.0
	fundo_preto.offset_top = 0.0
	fundo_preto.offset_right = 0.0
	fundo_preto.offset_bottom = 0.0
	fundo_preto.color = Color.BLACK

	move_child(fundo_preto, 0)
	if background != null:
		move_child(background, 1)


func _configurar_background() -> void:
	if background == null:
		return

	if background_secundario == null:
		background_secundario = VideoStreamPlayer.new()
		background_secundario.name = "Background2"
		background_secundario.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background_secundario.set_anchors_preset(Control.PRESET_FULL_RECT)
		background_secundario.expand = true
		background_secundario.loop = true
		background_secundario.modulate.a = 0.0
		add_child(background_secundario)
		move_child(background_secundario, 1)

	background.visible = true
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.offset_left = 0.0
	background.offset_top = 0.0
	background.offset_right = 0.0
	background.offset_bottom = 0.0
	background.position = Vector2.ZERO
	background.size = get_viewport_rect().size
	background.scale = Vector2.ONE
	background.expand = true
	background.loop = true

	if ResourceLoader.exists(caminho_video_background):
		background.stream = load(caminho_video_background)
		background.play()
		background_atual_caminho = caminho_video_background
	else:
		push_error("Vídeo de background não encontrado: " + caminho_video_background)


func _ajustar_background_fullscreen() -> void:
	if background == null:
		return
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.offset_left = 0.0
	background.offset_top = 0.0
	background.offset_right = 0.0
	background.offset_bottom = 0.0
	background.position = Vector2.ZERO
	background.size = get_viewport_rect().size
	background.scale = Vector2.ONE
	background.expand = true


# ─────────────────────────────────────────────────────────────────────────────
# LAYOUT
# ─────────────────────────────────────────────────────────────────────────────
func _configurar_layout() -> void:
	var largura_tela: float = get_viewport_rect().size.x
	var altura_tela: float = get_viewport_rect().size.y

	# O título agora fica dentro do painel neon da contagem
	if titulo != null:
		titulo.visible = false

	var largura_card: float = clamp(largura_tela * 0.42, 390.0, 530.0)
	var altura_card: float = clamp(altura_tela * 0.215, 165.0, 215.0)
	var espacamento_h: float = 32.0
	var espacamento_v: float = 30.0
	var largura_total_grid: float = largura_card * 2.0 + espacamento_h
	var altura_total_grid: float = altura_card * 2.0 + espacamento_v

	grid.columns = 2
	grid.position = Vector2(
		floor((largura_tela - largura_total_grid) * 0.5),
		floor((altura_tela - altura_total_grid) * 0.5 + 105.0)
	)
	grid.size = Vector2(ceil(largura_total_grid), ceil(altura_total_grid))
	Leve.constant(grid, "h_separation", int(espacamento_h))
	Leve.constant(grid, "v_separation", int(espacamento_v))

	botao_ranking.position = Vector2(
		floor(largura_tela * 0.5 - 370.0),
		floor(altura_tela - 122.0)
	)
	botao_ranking.size = Vector2(480.0, 92.0)
	botao_ranking.pivot_offset = botao_ranking.size * 0.5



func _reposicionar_botao_sensibilidade() -> void:
	if botao_sensibilidade == null:
		return
	var largura_tela: float = get_viewport_rect().size.x
	var altura_tela: float = get_viewport_rect().size.y
	# Ranking termina em: largura_tela*0.5 - 370 + 480 = largura_tela*0.5 + 110
	# Botão de mira começa 20px depois
	botao_sensibilidade.position = Vector2(
		floor(largura_tela * 0.5 + 130.0),
		floor(altura_tela - 122.0)
	)
	botao_sensibilidade.size = Vector2(220.0, 92.0)
	botao_sensibilidade.pivot_offset = botao_sensibilidade.size * 0.5


func _configurar_cards() -> void:
	var largura_tela: float = get_viewport_rect().size.x
	var altura_tela: float = get_viewport_rect().size.y
	var largura_card: float = clamp(largura_tela * 0.42, 390.0, 530.0)
	var altura_card: float = clamp(altura_tela * 0.215, 165.0, 215.0)

	var cards: Array[Panel] = [card_1, card_2, card_3, card_4]

	for i in range(cards.size()):
		var card: Panel = cards[i]
		card.custom_minimum_size = Vector2(largura_card, altura_card)
		card.size = Vector2(largura_card, altura_card)
		card.pivot_offset = Vector2(largura_card * 0.5, altura_card * 0.5)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.modulate = Color(1.0, 1.0, 1.0, 0.99)
		card.scale = Vector2.ONE
		card.clip_contents = false

		_aplicar_estilo_card_por_indice(card, i, false)


func _atualizar_hover_cards_por_alvo() -> void:
	if aleatorio_em_andamento or entrada_bloqueada or modal_ativo or modal_sens_ativo:
		_resetar_hover_cards()
		_solicitar_video_background(caminho_video_background, true)
		return

	var cards: Array[Panel] = [card_1, card_2, card_3, card_4]
	var novo_hover: Panel = null

	for card in cards:
		if card != null and card.get_global_rect().has_point(alvo_pos):
			novo_hover = card
			break

	if novo_hover == card_hover_atual:
		return

	if card_hover_atual != null:
		_on_sair_hover_cenario(null, card_hover_atual)

	card_hover_atual = novo_hover

	if card_hover_atual != null:
		_on_hover_cenario(null, card_hover_atual)
	else:
		_solicitar_video_background(caminho_video_background, true)


func _resetar_hover_cards() -> void:
	if card_hover_atual != null:
		_on_sair_hover_cenario(null, card_hover_atual)
	card_hover_atual = null



func _configurar_imagens_e_estrelas() -> void:
	var cards: Array[Panel] = [card_1, card_2, card_3, card_4]
	var botoes: Array[TextureButton] = [botao_cenario_1, botao_cenario_2, botao_cenario_3, botao_cenario_4]
	var nomes: Array[Label] = [nome_1, nome_2, nome_3, nome_4]

	for i in range(cards.size()):
		var card: Panel = cards[i]
		var larg: float = card.size.x
		var alt: float = card.size.y
		var cor_card: Color = _cor_neon_card(i)

		for nome_filho in [
			"MoldeEscuro" + str(i + 1),
			"OverlayEscuro" + str(i + 1),
			"HoverBrilho" + str(i + 1),
			"FaixaEstrelas" + str(i + 1),
			"Estrelas" + str(i + 1)
		]:
			var n := card.find_child(nome_filho, false, false)
			if n:
				n.queue_free()

		var molde_estilo := StyleBoxFlat.new()
		molde_estilo.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		molde_estilo.border_width_left = 5
		molde_estilo.border_width_top = 5
		molde_estilo.border_width_right = 5
		molde_estilo.border_width_bottom = 5
		molde_estilo.border_color = cor_card
		molde_estilo.corner_radius_top_left = 46
		molde_estilo.corner_radius_top_right = 46
		molde_estilo.corner_radius_bottom_left = 46
		molde_estilo.corner_radius_bottom_right = 46
		molde_estilo.shadow_color = Color(cor_card.r, cor_card.g, cor_card.b, 0.50)
		molde_estilo.shadow_size = 22
		molde_estilo.shadow_offset = Vector2.ZERO

		var molde := Panel.new()
		molde.name = "MoldeEscuro" + str(i + 1)
		molde.mouse_filter = Control.MOUSE_FILTER_IGNORE
		molde.position = Vector2.ZERO
		molde.size = Vector2(larg, alt)
		Leve.stylebox(molde, "panel", molde_estilo)
		card.add_child(molde)

		var faixa_estilo := StyleBoxFlat.new()
		faixa_estilo.bg_color = Color(0.0, 0.0, 0.0, 0.78)
		faixa_estilo.border_width_left = 2
		faixa_estilo.border_width_top = 2
		faixa_estilo.border_width_right = 2
		faixa_estilo.border_width_bottom = 2
		faixa_estilo.border_color = cor_card
		faixa_estilo.corner_radius_top_left = 24
		faixa_estilo.corner_radius_top_right = 24
		faixa_estilo.corner_radius_bottom_left = 24
		faixa_estilo.corner_radius_bottom_right = 24
		faixa_estilo.shadow_color = Color(cor_card.r, cor_card.g, cor_card.b, 0.34)
		faixa_estilo.shadow_size = 10
		faixa_estilo.shadow_offset = Vector2.ZERO

		var faixa := Panel.new()
		faixa.name = "FaixaEstrelas" + str(i + 1)
		faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Leve.stylebox(faixa, "panel", faixa_estilo)
		card.add_child(faixa)

		var hbox := HBoxContainer.new()
		hbox.name = "Estrelas" + str(i + 1)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		Leve.constant(hbox, "separation", 3)

		for s in range(3):
			var lbl := Label.new()
			lbl.text = "★"
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			Leve.font_size(lbl, "font_size", 30)
			Leve.color(lbl, "font_outline_color", Color.BLACK)
			Leve.constant(lbl, "outline_size", 6)

			if s < DIFICULDADES[i]:
				Leve.color(lbl, "font_color", cor_card)
				Leve.color(lbl, "font_shadow_color", Color(cor_card.r, cor_card.g, cor_card.b, 0.95))
			else:
				Leve.color(lbl, "font_color", Color(0.28, 0.28, 0.28, 0.86))
				Leve.color(lbl, "font_shadow_color", Color.BLACK)

			Leve.constant(lbl, "shadow_offset_x", 0)
			Leve.constant(lbl, "shadow_offset_y", 0)
			hbox.add_child(lbl)

		card.add_child(hbox)

		var faixa_w: float = 120.0
		var faixa_h: float = 42.0
		faixa.position = Vector2(larg - faixa_w - 18.0, alt - faixa_h - 16.0)
		faixa.size = Vector2(faixa_w, faixa_h)
		hbox.position = faixa.position + Vector2(8.0, 0.0)
		hbox.size = Vector2(faixa_w - 16.0, faixa_h)

		card.move_child(botoes[i], 0)
		card.move_child(molde, 1)
		card.move_child(nomes[i], 2)
		card.move_child(faixa, 3)
		card.move_child(hbox, 4)

		match i:
			0: estrelas_1 = hbox
			1: estrelas_2 = hbox
			2: estrelas_3 = hbox
			3: estrelas_4 = hbox



func _configurar_botoes() -> void:
	var botoes: Array[TextureButton] = [botao_cenario_1, botao_cenario_2, botao_cenario_3, botao_cenario_4]
	var caminhos: Array[String] = [CAMINHO_IMG_1, CAMINHO_IMG_2, CAMINHO_IMG_3, CAMINHO_IMG_4]

	for i in range(botoes.size()):
		var botao: TextureButton = botoes[i]
		var card := botao.get_parent() as Panel
		if card == null:
			continue

		botao.name = "ImagemCenario" + str(i + 1)
		botao.visible = true

		# IMAGEM LIMPA, SEM LENTE
		botao.modulate = Color.WHITE
		botao.self_modulate = Color.WHITE

		botao.mouse_filter = Control.MOUSE_FILTER_STOP
		botao.focus_mode = Control.FOCUS_NONE

		var margem_img: float = 8.0
		var tamanho_img: Vector2 = card.size - Vector2(margem_img * 2.0, margem_img * 2.0)
		botao.position = Vector2(margem_img, margem_img)
		botao.size = tamanho_img
		botao.scale = Vector2.ONE
		botao.pivot_offset = tamanho_img * 0.5
		botao.ignore_texture_size = true
		botao.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		
		botao.material = _criar_material_imagem_arredondada(tamanho_img, 34.0)

		if ResourceLoader.exists(caminhos[i]):
			var tex: Texture2D = ResourceLoader.load(caminhos[i])
			botao.texture_normal = tex
			botao.texture_hover = tex
			botao.texture_pressed = tex
		else:
			push_error("CARD " + str(i + 1) + " IMAGEM NÃO ENCONTRADA: " + caminhos[i])
	
	

func _configurar_textos() -> void:
	nome_1.text = "DESERTO SAGRADO"
	nome_2.text = "FUNDO DO MAR"
	nome_3.text = "BAR DO FAROESTE"
	nome_4.text = "ARENA LAZER SHOT"

	var cards: Array[Panel] = [card_1, card_2, card_3, card_4]
	var nomes: Array[Label] = [nome_1, nome_2, nome_3, nome_4]

	for i in range(nomes.size()):
		var card: Panel = cards[i]
		var nome: Label = nomes[i]
		nome.position = Vector2(14.0, card.size.y - 66.0)
		nome.size = Vector2(card.size.x - 150.0, 52.0)
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		Leve.font_size(nome, "font_size", 25)
		Leve.color(nome, "font_color", Color(1.0, 1.0, 1.0, 1.0))
		Leve.color(nome, "font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		Leve.constant(nome, "outline_size", 8)
		Leve.color(nome, "font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
		Leve.constant(nome, "shadow_offset_x", 2)
		Leve.constant(nome, "shadow_offset_y", 2)


func _configurar_botao_ranking() -> void:
	estilo_ranking_normal = StyleBoxFlat.new()
	estilo_ranking_normal.bg_color = Color(0.02, 0.01, 0.012, 0.96)
	estilo_ranking_normal.corner_radius_top_left = 39
	estilo_ranking_normal.corner_radius_top_right = 39
	estilo_ranking_normal.corner_radius_bottom_right = 39
	estilo_ranking_normal.corner_radius_bottom_left = 39
	estilo_ranking_normal.border_width_left = 4
	estilo_ranking_normal.border_width_top = 4
	estilo_ranking_normal.border_width_right = 4
	estilo_ranking_normal.border_width_bottom = 4
	estilo_ranking_normal.border_color = Color(1.0, 0.02, 0.02, 1.0)
	estilo_ranking_normal.shadow_color = Color(1.0, 0.0, 0.0, 0.58)
	estilo_ranking_normal.shadow_size = 34
	estilo_ranking_normal.shadow_offset = Vector2.ZERO

	estilo_ranking_hover = StyleBoxFlat.new()
	estilo_ranking_hover.bg_color = Color(0.06, 0.0, 0.0, 0.98)
	estilo_ranking_hover.corner_radius_top_left = 39
	estilo_ranking_hover.corner_radius_top_right = 39
	estilo_ranking_hover.corner_radius_bottom_right = 39
	estilo_ranking_hover.corner_radius_bottom_left = 39
	estilo_ranking_hover.border_width_left = 5
	estilo_ranking_hover.border_width_top = 5
	estilo_ranking_hover.border_width_right = 5
	estilo_ranking_hover.border_width_bottom = 5
	estilo_ranking_hover.border_color = Color(1.0, 0.16, 0.12, 1.0)
	estilo_ranking_hover.shadow_color = Color(1.0, 0.0, 0.0, 0.82)
	estilo_ranking_hover.shadow_size = 46
	estilo_ranking_hover.shadow_offset = Vector2.ZERO

	botao_ranking.visible = true
	botao_ranking.focus_mode = Control.FOCUS_NONE
	botao_ranking.mouse_filter = Control.MOUSE_FILTER_STOP
	botao_ranking.text = "🏆 RANKING"
	botao_ranking.modulate = Color.WHITE
	Leve.color(botao_ranking, "font_color", Color.WHITE)
	Leve.color(botao_ranking, "font_hover_color", Color.WHITE)
	Leve.color(botao_ranking, "font_pressed_color", Color.WHITE)
	Leve.color(botao_ranking, "font_outline_color", Color.BLACK)
	Leve.font_size(botao_ranking, "font_size", 42)
	Leve.constant(botao_ranking, "outline_size", 6)
	Leve.stylebox(botao_ranking, "normal", estilo_ranking_normal)
	Leve.stylebox(botao_ranking, "hover", estilo_ranking_hover)
	Leve.stylebox(botao_ranking, "pressed", estilo_ranking_hover)

	if not botao_ranking.mouse_entered.is_connected(_on_hover_ranking):
		botao_ranking.mouse_entered.connect(_on_hover_ranking)
	if not botao_ranking.mouse_exited.is_connected(_on_sair_hover_ranking):
		botao_ranking.mouse_exited.connect(_on_sair_hover_ranking)


# ─────────────────────────────────────────────────────────────────────────────
# SENSIBILIDADE — inicialização e botão
# ─────────────────────────────────────────────────────────────────────────────
func _inicializar_sensibilidade() -> void:
	if get_tree().has_meta(META_SENS_XBOX):
		velocidade_mira_xbox = float(
			get_tree().get_meta(META_SENS_XBOX)
		)
	else:
		# PADRÃO = 100%
		velocidade_mira_xbox = SENS_XBOX_MAX

	if get_tree().has_meta(META_SENS_MOUSE):
		sensibilidade_mouse = float(
			get_tree().get_meta(META_SENS_MOUSE)
		)
	else:
		sensibilidade_mouse = SENS_MOUSE_PADRAO

	_criar_estilos_sensibilidade()
	_criar_botao_sensibilidade()



func _criar_estilos_sensibilidade() -> void:
	estilo_botao_sens_normal = StyleBoxFlat.new()
	estilo_botao_sens_normal.bg_color = Color(0.02, 0.01, 0.012, 0.96)
	estilo_botao_sens_normal.corner_radius_top_left = 39
	estilo_botao_sens_normal.corner_radius_top_right = 39
	estilo_botao_sens_normal.corner_radius_bottom_right = 39
	estilo_botao_sens_normal.corner_radius_bottom_left = 39
	estilo_botao_sens_normal.border_width_left = 4
	estilo_botao_sens_normal.border_width_top = 4
	estilo_botao_sens_normal.border_width_right = 4
	estilo_botao_sens_normal.border_width_bottom = 4
	estilo_botao_sens_normal.border_color = Color(1.0, 0.02, 0.02, 1.0)
	estilo_botao_sens_normal.shadow_color = Color(1.0, 0.0, 0.0, 0.58)
	estilo_botao_sens_normal.shadow_size = 34
	estilo_botao_sens_normal.shadow_offset = Vector2.ZERO

	estilo_botao_sens_hover = StyleBoxFlat.new()
	estilo_botao_sens_hover.bg_color = Color(0.06, 0.0, 0.0, 0.98)
	estilo_botao_sens_hover.corner_radius_top_left = 39
	estilo_botao_sens_hover.corner_radius_top_right = 39
	estilo_botao_sens_hover.corner_radius_bottom_right = 39
	estilo_botao_sens_hover.corner_radius_bottom_left = 39
	estilo_botao_sens_hover.border_width_left = 5
	estilo_botao_sens_hover.border_width_top = 5
	estilo_botao_sens_hover.border_width_right = 5
	estilo_botao_sens_hover.border_width_bottom = 5
	estilo_botao_sens_hover.border_color = Color(1.0, 0.16, 0.12, 1.0)
	estilo_botao_sens_hover.shadow_color = Color(1.0, 0.0, 0.0, 0.82)
	estilo_botao_sens_hover.shadow_size = 46
	estilo_botao_sens_hover.shadow_offset = Vector2.ZERO



func _criar_botao_sensibilidade() -> void:
	if botao_sensibilidade == null:
		botao_sensibilidade = Button.new()
		botao_sensibilidade.name = "BotaoSensibilidade"
		add_child(botao_sensibilidade)

	botao_sensibilidade.visible = true
	botao_sensibilidade.focus_mode = Control.FOCUS_NONE
	botao_sensibilidade.mouse_filter = Control.MOUSE_FILTER_STOP

	botao_sensibilidade.text = "⚙ MIRA"
	Leve.color(botao_sensibilidade, "font_color", Color.WHITE)
	Leve.color(botao_sensibilidade, "font_hover_color", Color.WHITE)
	Leve.color(botao_sensibilidade, "font_pressed_color", Color.WHITE)
	Leve.color(botao_sensibilidade, "font_outline_color", Color.BLACK)
	Leve.font_size(botao_sensibilidade, "font_size", 32)
	Leve.constant(botao_sensibilidade, "outline_size", 6)
	Leve.stylebox(botao_sensibilidade, "normal", estilo_botao_sens_normal)
	Leve.stylebox(botao_sensibilidade, "hover", estilo_botao_sens_hover)
	Leve.stylebox(botao_sensibilidade, "pressed", estilo_botao_sens_hover)

	if not botao_sensibilidade.mouse_entered.is_connected(_on_hover_sensibilidade):
		botao_sensibilidade.mouse_entered.connect(_on_hover_sensibilidade)
	if not botao_sensibilidade.mouse_exited.is_connected(_on_sair_hover_sensibilidade):
		botao_sensibilidade.mouse_exited.connect(_on_sair_hover_sensibilidade)

	_reposicionar_botao_sensibilidade()


func _on_hover_sensibilidade() -> void:
	if modal_ativo or modal_sens_ativo:
		return

	botao_sensibilidade.scale = Vector2(1.08, 1.08)
	botao_sensibilidade.modulate = Color(1.0, 0.96, 0.80, 1.0)


func _on_sair_hover_sensibilidade() -> void:
	botao_sensibilidade.scale = Vector2.ONE
	botao_sensibilidade.modulate = Color.WHITE


# ─────────────────────────────────────────────────────────────────────────────
# CONTADOR
# ─────────────────────────────────────────────────────────────────────────────
func _configurar_contador() -> void:
	var largura_tela: float = get_viewport_rect().size.x

	if contador_layer == null:
		contador_layer = CanvasLayer.new()
		contador_layer.name = "ContadorLayer"
		contador_layer.layer = 40
		add_child(contador_layer)

	if contador_root == null:
		contador_root = Control.new()
		contador_root.name = "ContadorRoot"
		contador_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		contador_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contador_layer.add_child(contador_root)

	if contador_panel == null:
		contador_panel = Panel.new()
		contador_panel.name = "ContadorPanel"
		contador_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contador_root.add_child(contador_panel)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.012, 0.006, 0.010, 0.94)
	estilo.border_width_left = 5
	estilo.border_width_top = 5
	estilo.border_width_right = 5
	estilo.border_width_bottom = 5
	estilo.border_color = Color(1.0, 0.0, 0.08, 1.0)
	estilo.corner_radius_top_left = 42
	estilo.corner_radius_top_right = 42
	estilo.corner_radius_bottom_left = 42
	estilo.corner_radius_bottom_right = 42
	estilo.shadow_color = Color(1.0, 0.0, 0.08, 0.70)
	estilo.shadow_size = 58
	estilo.shadow_offset = Vector2.ZERO
	Leve.stylebox(contador_panel, "panel", estilo)

	if contador_linha == null:
		contador_linha = ColorRect.new()
		contador_linha.name = "LinhaNeon"
		contador_linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contador_panel.add_child(contador_linha)

	contador_linha.color = Color(1.0, 0.0, 0.08, 1.0)

	if contador_titulo == null:
		contador_titulo = Label.new()
		contador_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		contador_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		contador_root.add_child(contador_titulo)

	if contador_label == null:
		contador_label = Label.new()
		contador_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		contador_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		contador_root.add_child(contador_label)

	contador_titulo.text = "ESCOLHA SEU CENÁRIO"
	_aplicar_fonte_label(contador_titulo, 46, Color(1.0, 0.94, 0.78), 10)
	_aplicar_fonte_label(contador_label, 78, Color.WHITE, 11)

	var painel_w: float = 720.0
	var painel_h: float = 218.0

	contador_panel.position = Vector2(
		floor(largura_tela * 0.5 - painel_w * 0.5),
		34.0
	)
	contador_panel.size = Vector2(painel_w, painel_h)

	contador_titulo.position = Vector2(
		contador_panel.position.x,
		contador_panel.position.y + 22.0
	)
	contador_titulo.size = Vector2(painel_w, 62.0)

	contador_linha.position = Vector2(46.0, 92.0)
	contador_linha.size = Vector2(painel_w - 92.0, 5.0)

	contador_label.position = Vector2(
		contador_panel.position.x,
		contador_panel.position.y + 104.0
	)
	contador_label.size = Vector2(painel_w, 88.0)

	_atualizar_contador()



func _atualizar_contador() -> void:
	if contador_label == null:
		return
	var segundos: int = max(0, int(ceil(tempo_restante_auto)))
	contador_label.text = str(segundos)
	if segundos <= 5:
		Leve.color(contador_label, "font_color", Color(1.0, 0.05, 0.05, 1.0))
		if contador_linha != null:
			contador_linha.color = Color(1.0, 0.02, 0.02, 1.0)
	else:
		Leve.color(contador_label, "font_color", Color.WHITE)
		if contador_linha != null:
			contador_linha.color = Color(1.0, 0.02, 0.02, 0.95)


# ─────────────────────────────────────────────────────────────────────────────
# ALVO / CROSSHAIR
# ─────────────────────────────────────────────────────────────────────────────
func _configurar_alvo_overlay() -> void:
	if alvo_layer == null:
		alvo_layer = CanvasLayer.new()
		alvo_layer.name = "AlvoLayer"
		alvo_layer.layer = 100
		add_child(alvo_layer)

	if alvo_overlay == null:
		alvo_overlay = Control.new()
		alvo_overlay.name = "AlvoOverlay"
		alvo_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		alvo_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		alvo_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		alvo_layer.add_child(alvo_overlay)
		alvo_overlay.draw.connect(_desenhar_alvo_overlay)


func _desenhar_alvo_overlay() -> void:
	var t := alvo_anim_t
	var pulso := 1.0 + sin(t * 6.0) * 0.08
	var raio_base := 18.0 * pulso
	var raio_meio := 9.0 * pulso
	var raio_interno := 3.4 * pulso
	var cor_principal := Color(1.0, 0.22, 0.18, 0.98)
	var cor_secundaria := Color(1.0, 1.0, 1.0, 0.94)
	var cor_sombra := Color(0.0, 0.0, 0.0, 0.34)

	Pincel.mira_inicio(alvo_overlay, alvo_pos)
	Pincel.anel(alvo_overlay, alvo_pos + Vector2(1.2, 1.2), raio_base, 3.0, cor_sombra)
	Pincel.anel(alvo_overlay, alvo_pos, raio_base, 2.5, cor_principal)
	Pincel.anel(alvo_overlay, alvo_pos, raio_meio, 1.2, Color(1.0, 0.88, 0.82, 0.78))
	Pincel.circulo(alvo_overlay, alvo_pos, raio_interno, cor_principal)
	Pincel.circulo(alvo_overlay, alvo_pos, 1.4 * pulso, cor_secundaria)

	var tamanho_linha := 13.0 * pulso
	var espaco := 7.0 * pulso
	Pincel.linha(alvo_overlay, alvo_pos + Vector2(-tamanho_linha - espaco, 0.0), alvo_pos + Vector2(-espaco, 0.0), cor_secundaria, 2.2)
	Pincel.linha(alvo_overlay, alvo_pos + Vector2(espaco, 0.0), alvo_pos + Vector2(tamanho_linha + espaco, 0.0), cor_secundaria, 2.2)
	Pincel.linha(alvo_overlay, alvo_pos + Vector2(0.0, -tamanho_linha - espaco), alvo_pos + Vector2(0.0, -espaco), cor_secundaria, 2.2)
	Pincel.linha(alvo_overlay, alvo_pos + Vector2(0.0, espaco), alvo_pos + Vector2(0.0, tamanho_linha + espaco), cor_secundaria, 2.2)
	Pincel.mira_fim(alvo_overlay)
# ─────────────────────────────────────────────────────────────────────────────
# FADE
# ─────────────────────────────────────────────────────────────────────────────
func _configurar_fade() -> void:
	if fade_layer == null:
		fade_layer = CanvasLayer.new()
		fade_layer.name = "FadeLayer"
		fade_layer.layer = 120
		add_child(fade_layer)

	if fade_rect == null:
		fade_rect = ColorRect.new()
		fade_rect.anchor_left = 0.0
		fade_rect.anchor_top = 0.0
		fade_rect.anchor_right = 1.0
		fade_rect.anchor_bottom = 1.0
		fade_rect.offset_left = 0.0
		fade_rect.offset_top = 0.0
		fade_rect.offset_right = 0.0
		fade_rect.offset_bottom = 0.0
		fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade_layer.add_child(fade_rect)


# ─────────────────────────────────────────────────────────────────────────────
# ANIMAÇÕES DE ENTRADA
# ─────────────────────────────────────────────────────────────────────────────
func _animar_entrada_titulo() -> void:
	if titulo != null:
		titulo.visible = false

	if contador_panel == null:
		return

	contador_panel.modulate.a = 0.0
	contador_panel.scale = Vector2(0.94, 0.94)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(contador_panel, "modulate:a", 1.0, 0.35)
	tw.tween_property(contador_panel, "scale", Vector2.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)



func _animar_entrada_cards() -> void:
	var cards: Array[Panel] = [card_1, card_2, card_3, card_4]
	for i in range(cards.size()):
		var card: Panel = cards[i]
		card.modulate.a = 0.0
		card.scale = Vector2(0.92, 0.92)
		var delay := 0.06 * i
		var tween := create_tween()
		tween.tween_property(card, "modulate:a", 1.0, 0.22).set_delay(delay)
		tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)


func _iniciar_pulso_ranking() -> void:
	if tween_ranking_pulso != null:
		tween_ranking_pulso.kill()
	botao_ranking.scale = Vector2.ONE
	tween_ranking_pulso = create_tween()
	tween_ranking_pulso.set_loops()
	tween_ranking_pulso.tween_property(botao_ranking, "scale", Vector2(1.04, 1.04), 0.62)
	tween_ranking_pulso.tween_property(botao_ranking, "scale", Vector2(1.0, 1.0), 0.62)


# ─────────────────────────────────────────────────────────────────────────────
# HOVER
# ─────────────────────────────────────────────────────────────────────────────
func _on_hover_ranking() -> void:
	if modal_ativo or modal_sens_ativo:
		return

	if tween_ranking_pulso != null:
		tween_ranking_pulso.kill()
	botao_ranking.scale = Vector2(1.08, 1.08)
	botao_ranking.modulate = Color(1.0, 0.96, 0.80, 1.0)



func _on_sair_hover_ranking() -> void:
	if botao_ranking == null:
		return

	botao_ranking.scale = Vector2.ONE
	botao_ranking.modulate = Color.WHITE

	if not ranking_hover_ativo:
		_iniciar_pulso_ranking()


func _on_hover_cenario(_botao: TextureButton, card: Panel) -> void:
	if aleatorio_em_andamento:
		return

	var indice: int = 0
	var video_hover: String = caminho_video_background

	if card == card_1:
		indice = 0
		video_hover = CAMINHO_TEASER_DESERTO
	elif card == card_2:
		indice = 1
		video_hover = CAMINHO_TEASER_MAR
	elif card == card_3:
		indice = 2
		video_hover = CAMINHO_TEASER_BAR
	elif card == card_4:
		indice = 3
		video_hover = CAMINHO_TEASER_ARENA

	_solicitar_video_background(video_hover, false)

	_aplicar_estilo_card_por_indice(card, indice, true)

	var tw := create_tween()
	tw.set_parallel(true)

	tw.tween_property(card, "scale", Vector2(1.045, 1.045), 0.12)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	tw.tween_property(card, "modulate", Color.WHITE, 0.12)

	var imagem := card.find_child("ImagemCenario*", true, false) as TextureButton
	if imagem != null:
		imagem.scale = Vector2.ONE
		tw.tween_property(imagem, "modulate", Color.WHITE, 0.10)

	var faixa := card.find_child("FaixaEstrelas*", true, false) as Panel
	if faixa != null:
		tw.tween_property(faixa, "scale", Vector2(1.08, 1.08), 0.12)

	var estrelas := card.find_child("Estrelas*", true, false) as HBoxContainer
	if estrelas != null:
		tw.tween_property(estrelas, "scale", Vector2(1.10, 1.10), 0.12)

	var nome := card.find_child("Nome*", true, false) as Label
	if nome != null:
		tw.tween_property(nome, "scale", Vector2(1.03, 1.03), 0.12)



func _solicitar_video_background(caminho: String, imediato: bool = false) -> void:
	if caminho == "":
		return

	background_troca_id += 1
	var id_local: int = background_troca_id

	if not imediato:
		await get_tree().create_timer(delay_troca_background_hover).timeout
		if id_local != background_troca_id:
			return

	_trocar_video_background(caminho, id_local)


func _trocar_video_background(caminho: String, id_local: int = -1) -> void:
	if caminho == "" or not ResourceLoader.exists(caminho):
		push_warning("Vídeo não encontrado: " + caminho)
		return

	if id_local != -1 and id_local != background_troca_id:
		return

	if background_atual_caminho == caminho:
		return

	var ativo: VideoStreamPlayer = background if usando_background_a else background_secundario
	var inativo: VideoStreamPlayer = background_secundario if usando_background_a else background

	if ativo != null and ativo.stream != null and ativo.stream.resource_path == caminho:
		background_atual_caminho = caminho
		return

	if background_tween != null and background_tween.is_valid():
		background_tween.kill()

	inativo.stop()
	inativo.stream = load(caminho)
	inativo.modulate.a = 0.0
	inativo.visible = true
	inativo.play()

	_ajustar_background_fullscreen()

	background_tween = create_tween()
	background_tween.set_parallel(true)
	background_tween.tween_property(inativo, "modulate:a", 1.0, 0.35)
	background_tween.tween_property(ativo, "modulate:a", 0.0, 0.35)

	await background_tween.finished

	if id_local != -1 and id_local != background_troca_id:
		return

	ativo.stop()
	background_atual_caminho = caminho
	usando_background_a = not usando_background_a



func _on_sair_hover_cenario(_botao: TextureButton, card: Panel) -> void:
	if aleatorio_em_andamento:
		return

	var indice: int = 0
	if card == card_1:
		indice = 0
	elif card == card_2:
		indice = 1
	elif card == card_3:
		indice = 2
	elif card == card_4:
		indice = 3

	_aplicar_estilo_card_por_indice(card, indice, false)

	var tw := create_tween()
	tw.set_parallel(true)

	tw.tween_property(card, "scale", Vector2.ONE, 0.14)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	tw.tween_property(card, "modulate", Color.WHITE, 0.14)

	var imagem := card.find_child("ImagemCenario*", true, false) as TextureButton
	if imagem != null:
		imagem.scale = Vector2.ONE
		tw.tween_property(imagem, "modulate", Color.WHITE, 0.10)

	var faixa := card.find_child("FaixaEstrelas*", true, false) as Panel
	if faixa != null:
		tw.tween_property(faixa, "scale", Vector2.ONE, 0.12)

	var estrelas := card.find_child("Estrelas*", true, false) as HBoxContainer
	if estrelas != null:
		tw.tween_property(estrelas, "scale", Vector2.ONE, 0.12)

	var nome := card.find_child("Nome*", true, false) as Label
	if nome != null:
		tw.tween_property(nome, "scale", Vector2.ONE, 0.12)


# ─────────────────────────────────────────────────────────────────────────────
# INPUT
# ─────────────────────────────────────────────────────────────────────────────
const BOTAO_GATILHO_1: int = MOUSE_BUTTON_RIGHT
const BOTAO_GATILHO_2: int = MOUSE_BUTTON_LEFT
var tempo_trava_input_menu: float = 0.0


func _evento_tiro_menu(me: InputEventMouseButton) -> bool:
	return Maquina.e_tiro_arma(me)


func _input(event: InputEvent) -> void:
	# =========================================================
	# MODAL DE SENSIBILIDADE
	# =========================================================
	if modal_sens_ativo:
		if event is InputEventMouseMotion:
			alvo_pos = event.position
			return

		# Agora a arma também funciona aqui usando input_shot.
		if _evento_input_shot_menu(event):
			if tempo_trava_input_menu > 0.0:
				return

			tempo_trava_input_menu = 0.10

			var btn := modal_sens_panel.find_child(
				"btn_fechar_sens",
				true,
				false
			) as Button

			if btn != null:
				var r := Rect2(btn.global_position, btn.size)
				if r.has_point(alvo_pos):
					_tocar_tiro()
					_fechar_modal_sensibilidade()

			return

		return

	# =========================================================
	# MOVIMENTO DO MOUSE
	# =========================================================
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		mouse_delta_acumulado += mm.relative
		return

	# =========================================================
	# TIRO VIA INPUT MAP
	# Arduino Leonardo / arma / teclado / botão mapeado
	# Action: input_shot
	# =========================================================
	if _evento_input_shot_menu(event):
		_executar_tiro_menu()
		return

	# =========================================================
	# FALLBACK CONTROLE XBOX
	# Mantém funcionando mesmo se o botão não estiver mapeado
	# em input_shot.
	# =========================================================
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton

		if not jb.pressed:
			return

		if jb.button_index != xbox_botao_tiro:
			return

		_executar_tiro_menu()
		return

	# =========================================================
	# FALLBACK MOUSE
	# Mantém clique esquerdo/direito funcionando mesmo sem
	# estar mapeado em input_shot.
	# =========================================================
	if event is InputEventMouseButton:
		var me := event as InputEventMouseButton

		if not me.pressed:
			return

		if not _evento_tiro_menu(me):
			return

		_executar_tiro_menu()



func _tentar_escolher_dificuldade_por_mira() -> void:
	if not modal_ativo:
		return

	if modal_botao_facil != null:
		var r_facil := Rect2(
			modal_botao_facil.global_position,
			modal_botao_facil.size
		)

		if r_facil.has_point(alvo_pos):
			_on_modal_escolheu_facil()
			return

	if modal_botao_dificil != null:
		var r_dificil := Rect2(
			modal_botao_dificil.global_position,
			modal_botao_dificil.size
		)

		if r_dificil.has_point(alvo_pos):
			_on_modal_escolheu_dificil()
			return


# ─────────────────────────────────────────────────────────────────────────────
# SELEÇÃO POR TIRO
# ─────────────────────────────────────────────────────────────────────────────
func _tentar_selecao_por_tiro(pos_global: Vector2) -> void:
	_resetar_hover_cards()
	if aleatorio_em_andamento:
		return

	if _esta_no_card(card_1, pos_global):
		_parar_auto_contador()
		_efeito_tiro_card(card_1)
		_ir_para_cenario_1()
		return
	if _esta_no_card(card_2, pos_global):
		_parar_auto_contador()
		_efeito_tiro_card(card_2)
		_ir_para_cenario_2()
		return
	if _esta_no_card(card_3, pos_global):
		_parar_auto_contador()
		_efeito_tiro_card(card_3)
		_ir_para_cenario_3()
		return
	if _esta_no_card(card_4, pos_global):
		_parar_auto_contador()
		_efeito_tiro_card(card_4)
		_ir_para_cenario_4()
		return

	# ── NOVO: botão de sensibilidade ──────────────────────────────────────────
	if botao_sensibilidade != null and _esta_no_botao(botao_sensibilidade, pos_global):
		_parar_auto_contador()
		_efeito_tiro_botao(botao_sensibilidade)
		_abrir_modal_sensibilidade()
		return

	if _esta_no_botao(botao_ranking, pos_global):
		_parar_auto_contador()
		_efeito_tiro_botao(botao_ranking)
		_ir_para_ranking()


func _parar_auto_contador() -> void:
	auto_timer_ativo = false


func _esta_no_card(card: Panel, pos_global: Vector2) -> bool:
	return card.get_global_rect().has_point(pos_global)


func _esta_no_botao(botao: Control, pos_global: Vector2) -> bool:
	return botao.get_global_rect().has_point(pos_global)


func _efeito_tiro_card(card: Panel) -> void:
	card.scale = Vector2(0.97, 0.97)
	card.modulate = Color(1.08, 1.08, 1.08, 1.0)
	var tween := create_tween()
	tween.tween_property(card, "scale", Vector2(1.03, 1.03), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _efeito_tiro_botao(botao: Button) -> void:
	botao.scale = Vector2(0.96, 0.96)
	botao.modulate = Color(1.0, 0.92, 0.82, 1.0)
	var tween := create_tween()
	tween.tween_property(botao, "scale", Vector2(1.08, 1.08), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ─────────────────────────────────────────────────────────────────────────────
# MODO ALEATÓRIO
# ─────────────────────────────────────────────────────────────────────────────
func _iniciar_modo_aleatorio() -> void:
	if aleatorio_em_andamento:
		return
	_call_modo_aleatorio_async()


func _call_modo_aleatorio_async() -> void:
	await _modo_aleatorio_async()


func _modo_aleatorio_async() -> void:
	if aleatorio_em_andamento:
		return
	aleatorio_em_andamento = true
	entrada_bloqueada = true
	auto_timer_ativo = false

	var cards: Array[Panel] = [card_1, card_2, card_3, card_4]
	var cenas: Array[String] = [CENA_CENARIO_1, CENA_CENARIO_2, CENA_CENARIO_3, CENA_CENARIO_4]
	var indice_final: int = randi() % cards.size()
	var indice_atual: int = randi() % cards.size()
	var voltas: int = randi_range(14, 22)

	for i in range(voltas):
		indice_atual = randi() % cards.size()
		for c in cards:
			Leve.stylebox(c, "panel", estilo_card_normal)
			c.scale = Vector2.ONE
		var card_atual: Panel = cards[indice_atual]
		Leve.stylebox(card_atual, "panel", estilo_card_destaque)
		card_atual.scale = Vector2(1.04, 1.04)
		_tocar_choice()
		var espera: float = 0.055 + float(i) * 0.012
		await get_tree().create_timer(espera).timeout

	for c in cards:
		Leve.stylebox(c, "panel", estilo_card_normal)
		c.scale = Vector2.ONE

	var card_final: Panel = cards[indice_final]
	Leve.stylebox(card_final, "panel", estilo_card_destaque)
	card_final.scale = Vector2(1.08, 1.08)
	_tocar_choice()
	await get_tree().create_timer(0.35).timeout

	aleatorio_em_andamento = false
	entrada_bloqueada = false
	_abrir_modal_dificuldade(cenas[indice_final])


# ─────────────────────────────────────────────────────────────────────────────
# NAVEGAÇÃO DE CENAS
# ─────────────────────────────────────────────────────────────────────────────
func _ir_para_cenario_1() -> void: _abrir_modal_dificuldade(CENA_CENARIO_1)
func _ir_para_cenario_2() -> void: _abrir_modal_dificuldade(CENA_CENARIO_2)
func _ir_para_cenario_3() -> void: _abrir_modal_dificuldade(CENA_CENARIO_3)
func _ir_para_cenario_4() -> void: _abrir_modal_dificuldade(CENA_CENARIO_4)


func _ir_para_ranking() -> void:
	get_tree().set_meta("ranking_origem", "cenarios")
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_abrir_cena_suave_com_tiro(CENA_RANKING)


# ─────────────────────────────────────────────────────────────────────────────
# MODAL DE DIFICULDADE
# ─────────────────────────────────────────────────────────────────────────────
func _abrir_modal_dificuldade(cena_destino: String) -> void:
	if modal_ativo:
		return
	modal_cena_destino = cena_destino
	modal_ativo = true
	modal_tempo_restante = TEMPO_ESCOLHA_DIFICULDADE
	auto_timer_ativo = false
	entrada_bloqueada = true
	_criar_modal()
	_animar_entrada_modal()


func _criar_modal() -> void:
	if modal_layer == null:
		modal_layer = CanvasLayer.new()
		modal_layer.name = "ModalDificuldadeLayer"
		modal_layer.layer = 80
		add_child(modal_layer)

	if modal_root != null:
		modal_root.queue_free()
		modal_root = null
		modal_panel = null
		modal_titulo_label = null
		modal_subtitulo = null
		modal_contador = null
		modal_botao_facil = null
		modal_botao_dificil = null
		modal_barra_progresso = null

	modal_root = Control.new()
	modal_root.name = "ModalRoot"
	modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(modal_root)

	var overlay := ColorRect.new()
	overlay.name = "ModalOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_root.add_child(overlay)

	var vp_size := get_viewport_rect().size
	var painel_w := 560.0
	var painel_h := 340.0

	var estilo_painel := StyleBoxFlat.new()
	estilo_painel.bg_color = Color(0.04, 0.03, 0.03, 0.97)
	estilo_painel.border_width_left = 3
	estilo_painel.border_width_top = 3
	estilo_painel.border_width_right = 3
	estilo_painel.border_width_bottom = 3
	estilo_painel.border_color = Color(0.9, 0.02, 0.02, 1.0)
	estilo_painel.corner_radius_top_left = 32
	estilo_painel.corner_radius_top_right = 32
	estilo_painel.corner_radius_bottom_left = 32
	estilo_painel.corner_radius_bottom_right = 32
	estilo_painel.shadow_color = Color(1.0, 0.0, 0.0, 0.25)
	estilo_painel.shadow_size = 28
	estilo_painel.shadow_offset = Vector2(0, 10)

	modal_panel = Panel.new()
	modal_panel.name = "ModalPanel"
	modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	Leve.stylebox(modal_panel, "panel", estilo_painel)
	modal_panel.position = Vector2(floor((vp_size.x - painel_w) * 0.5), floor((vp_size.y - painel_h) * 0.5))
	modal_panel.size = Vector2(painel_w, painel_h)
	modal_panel.pivot_offset = Vector2(painel_w * 0.5, painel_h * 0.5)
	modal_root.add_child(modal_panel)

	modal_titulo_label = Label.new()
	modal_titulo_label.text = "ESCOLHA A DIFICULDADE"
	modal_titulo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_titulo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	modal_titulo_label.position = Vector2(0.0, 26.0)
	modal_titulo_label.size = Vector2(painel_w, 50.0)
	Leve.font_size(modal_titulo_label, "font_size", 36)
	Leve.color(modal_titulo_label, "font_color", Color(1.0, 0.94, 0.74))
	Leve.color(modal_titulo_label, "font_outline_color", Color.BLACK)
	Leve.constant(modal_titulo_label, "outline_size", 8)
	Leve.color(modal_titulo_label, "font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	Leve.constant(modal_titulo_label, "shadow_offset_x", 3)
	Leve.constant(modal_titulo_label, "shadow_offset_y", 3)
	modal_panel.add_child(modal_titulo_label)

	modal_subtitulo = Label.new()
	modal_subtitulo.text = "No modo DIFÍCIL a mira fica oculta!"
	modal_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_subtitulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	modal_subtitulo.position = Vector2(0.0, 76.0)
	modal_subtitulo.size = Vector2(painel_w, 34.0)
	Leve.font_size(modal_subtitulo, "font_size", 19)
	Leve.color(modal_subtitulo, "font_color", Color(0.78, 0.78, 0.78, 1.0))
	Leve.color(modal_subtitulo, "font_outline_color", Color.BLACK)
	Leve.constant(modal_subtitulo, "outline_size", 5)
	modal_panel.add_child(modal_subtitulo)

	var estilo_facil_normal := StyleBoxFlat.new()
	estilo_facil_normal.bg_color = Color(0.03, 0.22, 0.06, 0.96)
	estilo_facil_normal.border_width_left = 2
	estilo_facil_normal.border_width_top = 2
	estilo_facil_normal.border_width_right = 2
	estilo_facil_normal.border_width_bottom = 2
	estilo_facil_normal.border_color = Color(0.18, 0.9, 0.22, 0.9)
	estilo_facil_normal.corner_radius_top_left = 22
	estilo_facil_normal.corner_radius_top_right = 22
	estilo_facil_normal.corner_radius_bottom_left = 22
	estilo_facil_normal.corner_radius_bottom_right = 22
	estilo_facil_normal.shadow_color = Color(0.0, 0.9, 0.1, 0.22)
	estilo_facil_normal.shadow_size = 14
	estilo_facil_normal.shadow_offset = Vector2(0, 5)
	var estilo_facil_hover := estilo_facil_normal.duplicate() as StyleBoxFlat
	estilo_facil_hover.bg_color = Color(0.04, 0.30, 0.08, 1.0)
	estilo_facil_hover.border_color = Color(0.3, 1.0, 0.35, 1.0)
	estilo_facil_hover.shadow_color = Color(0.0, 1.0, 0.1, 0.36)
	estilo_facil_hover.shadow_size = 22

	modal_botao_facil = Button.new()
	modal_botao_facil.text = "FACIL\n(mira visivel)"
	modal_botao_facil.focus_mode = Control.FOCUS_NONE
	modal_botao_facil.position = Vector2(40.0, 130.0)
	modal_botao_facil.size = Vector2(220.0, 90.0)
	modal_botao_facil.pivot_offset = Vector2(110.0, 45.0)
	Leve.font_size(modal_botao_facil, "font_size", 22)
	Leve.color(modal_botao_facil, "font_color", Color(0.8, 1.0, 0.82))
	Leve.color(modal_botao_facil, "font_hover_color", Color(1.0, 1.0, 1.0))
	Leve.color(modal_botao_facil, "font_pressed_color", Color(1.0, 1.0, 1.0))
	Leve.color(modal_botao_facil, "font_outline_color", Color.BLACK)
	Leve.constant(modal_botao_facil, "outline_size", 4)
	Leve.stylebox(modal_botao_facil, "normal", estilo_facil_normal)
	Leve.stylebox(modal_botao_facil, "hover", estilo_facil_hover)
	Leve.stylebox(modal_botao_facil, "pressed", estilo_facil_hover)
	modal_botao_facil.pressed.connect(_on_modal_escolheu_facil)
	modal_panel.add_child(modal_botao_facil)

	var estilo_dificil_normal := StyleBoxFlat.new()
	estilo_dificil_normal.bg_color = Color(0.22, 0.02, 0.02, 0.96)
	estilo_dificil_normal.border_width_left = 2
	estilo_dificil_normal.border_width_top = 2
	estilo_dificil_normal.border_width_right = 2
	estilo_dificil_normal.border_width_bottom = 2
	estilo_dificil_normal.border_color = Color(1.0, 0.08, 0.08, 0.9)
	estilo_dificil_normal.corner_radius_top_left = 22
	estilo_dificil_normal.corner_radius_top_right = 22
	estilo_dificil_normal.corner_radius_bottom_left = 22
	estilo_dificil_normal.corner_radius_bottom_right = 22
	estilo_dificil_normal.shadow_color = Color(1.0, 0.0, 0.0, 0.22)
	estilo_dificil_normal.shadow_size = 14
	estilo_dificil_normal.shadow_offset = Vector2(0, 5)
	var estilo_dificil_hover := estilo_dificil_normal.duplicate() as StyleBoxFlat
	estilo_dificil_hover.bg_color = Color(0.32, 0.02, 0.02, 1.0)
	estilo_dificil_hover.border_color = Color(1.0, 0.3, 0.3, 1.0)
	estilo_dificil_hover.shadow_color = Color(1.0, 0.0, 0.0, 0.36)
	estilo_dificil_hover.shadow_size = 22

	modal_botao_dificil = Button.new()
	modal_botao_dificil.text = "DIFICIL\n(sem mira)"
	modal_botao_dificil.focus_mode = Control.FOCUS_NONE
	modal_botao_dificil.position = Vector2(300.0, 130.0)
	modal_botao_dificil.size = Vector2(220.0, 90.0)
	modal_botao_dificil.pivot_offset = Vector2(110.0, 45.0)
	Leve.font_size(modal_botao_dificil, "font_size", 22)
	Leve.color(modal_botao_dificil, "font_color", Color(1.0, 0.78, 0.78))
	Leve.color(modal_botao_dificil, "font_hover_color", Color(1.0, 1.0, 1.0))
	Leve.color(modal_botao_dificil, "font_pressed_color", Color(1.0, 1.0, 1.0))
	Leve.color(modal_botao_dificil, "font_outline_color", Color.BLACK)
	Leve.constant(modal_botao_dificil, "outline_size", 4)
	Leve.stylebox(modal_botao_dificil, "normal", estilo_dificil_normal)
	Leve.stylebox(modal_botao_dificil, "hover", estilo_dificil_hover)
	Leve.stylebox(modal_botao_dificil, "pressed", estilo_dificil_hover)
	modal_botao_dificil.pressed.connect(_on_modal_escolheu_dificil)
	modal_panel.add_child(modal_botao_dificil)

	var estilo_fundo_barra := StyleBoxFlat.new()
	estilo_fundo_barra.bg_color = Color(0.12, 0.12, 0.12, 0.8)
	estilo_fundo_barra.corner_radius_top_left = 8
	estilo_fundo_barra.corner_radius_top_right = 8
	estilo_fundo_barra.corner_radius_bottom_left = 8
	estilo_fundo_barra.corner_radius_bottom_right = 8
	var fundo_barra := Panel.new()
	fundo_barra.name = "FundoBarra"
	fundo_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo_barra.position = Vector2(40.0, 248.0)
	fundo_barra.size = Vector2(480.0, 12.0)
	Leve.stylebox(fundo_barra, "panel", estilo_fundo_barra)
	modal_panel.add_child(fundo_barra)

	modal_barra_progresso = ColorRect.new()
	modal_barra_progresso.name = "BarraProgresso"
	modal_barra_progresso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_barra_progresso.color = Color(0.95, 0.06, 0.06, 1.0)
	modal_barra_progresso.position = Vector2(40.0, 248.0)
	modal_barra_progresso.size = Vector2(480.0, 12.0)
	modal_panel.add_child(modal_barra_progresso)

	modal_contador = Label.new()
	modal_contador.name = "ModalContador"
	modal_contador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_contador.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	modal_contador.position = Vector2(0.0, 268.0)
	modal_contador.size = Vector2(painel_w, 44.0)
	Leve.font_size(modal_contador, "font_size", 18)
	Leve.color(modal_contador, "font_color", Color(0.72, 0.72, 0.72, 1.0))
	Leve.color(modal_contador, "font_outline_color", Color.BLACK)
	Leve.constant(modal_contador, "outline_size", 5)
	modal_panel.add_child(modal_contador)

	_atualizar_modal_contador()


func _animar_entrada_modal() -> void:
	if modal_panel == null:
		return
	modal_panel.scale = Vector2(0.88, 0.88)
	modal_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(modal_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(modal_panel, "modulate:a", 1.0, 0.18)


func _atualizar_modal_contador() -> void:
	if modal_contador == null or modal_barra_progresso == null:
		return
	var segundos: int = max(0, int(ceil(modal_tempo_restante)))
	var plural := "s" if segundos != 1 else ""
	modal_contador.text = "Sem escolha, inicia em FÁCIL em %d segundo%s" % [segundos, plural]
	var progresso := modal_tempo_restante / TEMPO_ESCOLHA_DIFICULDADE
	modal_barra_progresso.size.x = 480.0 * clamp(progresso, 0.0, 1.0)
	if segundos <= 5:
		modal_barra_progresso.color = Color(1.0, 0.3, 0.05, 1.0)
		Leve.color(modal_contador, "font_color", Color(1.0, 0.4, 0.4, 1.0))
	else:
		modal_barra_progresso.color = Color(0.95, 0.06, 0.06, 1.0)
		Leve.color(modal_contador, "font_color", Color(0.72, 0.72, 0.72, 1.0))


func _fechar_modal_e_ir() -> void:
	modal_ativo = false
	if modal_panel != null:
		var tw := create_tween()
		tw.tween_property(modal_panel, "modulate:a", 0.0, 0.14)
		await tw.finished

	if modal_root != null:
		modal_root.queue_free()
		modal_root = null
		modal_panel = null
		modal_titulo_label = null
		modal_subtitulo = null
		modal_contador = null
		modal_botao_facil = null
		modal_botao_dificil = null
		modal_barra_progresso = null

	_abrir_cena_suave_com_tiro(modal_cena_destino)


func _on_modal_escolheu_facil() -> void:
	if not modal_ativo:
		return
	_tocar_tiro()
	get_tree().set_meta("modo_dificuldade", "facil")
	modal_ativo = false
	_fechar_modal_e_ir()


func _on_modal_escolheu_dificil() -> void:
	if not modal_ativo:
		return
	_tocar_tiro()
	get_tree().set_meta("modo_dificuldade", "dificil")
	modal_ativo = false
	_fechar_modal_e_ir()


# ─────────────────────────────────────────────────────────────────────────────
# MODAL DE SENSIBILIDADE
# ─────────────────────────────────────────────────────────────────────────────
func _abrir_modal_sensibilidade() -> void:
	if modal_sens_ativo:
		return

	modal_sens_ativo = true
	auto_timer_ativo = false

	mouse_delta_acumulado = Vector2.ZERO

	# mouse livre, mas ponteiro invisível
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	Tela.warp_mouse(get_viewport_rect().size * 0.5)
	alvo_pos = get_viewport_rect().size * 0.5

	_criar_modal_sensibilidade()
	_animar_entrada_modal_sensibilidade()



func _criar_modal_sensibilidade() -> void:
	if modal_sens_layer == null:
		modal_sens_layer = CanvasLayer.new()
		modal_sens_layer.name = "ModalSensLayer"
		modal_sens_layer.layer = 82
		add_child(modal_sens_layer)

	if modal_sens_root != null:
		modal_sens_root.queue_free()
		modal_sens_root = null
		modal_sens_panel = null
		slider_xbox = null
		slider_mouse = null
		label_valor_xbox = null
		label_valor_mouse = null

	modal_sens_root = Control.new()
	modal_sens_root.name = "ModalSensRoot"
	modal_sens_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_sens_root.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_sens_layer.add_child(modal_sens_root)

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.68)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_sens_root.add_child(overlay)

	var vp := get_viewport_rect().size
	var pw := 560.0
	var ph := 370.0

	var estilo_painel := StyleBoxFlat.new()
	estilo_painel.bg_color = Color(0.04, 0.03, 0.03, 0.97)
	estilo_painel.border_width_left = 3
	estilo_painel.border_width_top = 3
	estilo_painel.border_width_right = 3
	estilo_painel.border_width_bottom = 3
	estilo_painel.border_color = Color(0.9, 0.02, 0.02, 1.0)
	estilo_painel.corner_radius_top_left = 32
	estilo_painel.corner_radius_top_right = 32
	estilo_painel.corner_radius_bottom_left = 32
	estilo_painel.corner_radius_bottom_right = 32
	estilo_painel.shadow_color = Color(1.0, 0.0, 0.0, 0.22)
	estilo_painel.shadow_size = 28
	estilo_painel.shadow_offset = Vector2(0, 10)

	modal_sens_panel = Panel.new()
	modal_sens_panel.name = "ModalSensPanel"
	modal_sens_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	Leve.stylebox(modal_sens_panel, "panel", estilo_painel)
	modal_sens_panel.position = Vector2(floor((vp.x - pw) * 0.5), floor((vp.y - ph) * 0.5))
	modal_sens_panel.size = Vector2(pw, ph)
	modal_sens_panel.pivot_offset = Vector2(pw * 0.5, ph * 0.5)
	modal_sens_root.add_child(modal_sens_panel)

	# Título
	var titulo_lbl := Label.new()
	titulo_lbl.text = "⚙  SENSIBILIDADE DA MIRA"
	titulo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo_lbl.position = Vector2(0.0, 22.0)
	titulo_lbl.size = Vector2(pw, 50.0)
	Leve.font_size(titulo_lbl, "font_size", 34)
	Leve.color(titulo_lbl, "font_color", Color(1.0, 0.94, 0.74))
	Leve.color(titulo_lbl, "font_outline_color", Color.BLACK)
	Leve.constant(titulo_lbl, "outline_size", 8)
	Leve.color(titulo_lbl, "font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	Leve.constant(titulo_lbl, "shadow_offset_x", 3)
	Leve.constant(titulo_lbl, "shadow_offset_y", 3)
	modal_sens_panel.add_child(titulo_lbl)

	# Divisor
	var div := ColorRect.new()
	div.color = Color(1.0, 0.02, 0.02, 0.6)
	div.position = Vector2(32.0, 74.0)
	div.size = Vector2(pw - 64.0, 2.0)
	modal_sens_panel.add_child(div)

	# Seção Xbox
	var lbl_xbox := Label.new()
	lbl_xbox.text = "🎮  Controle (Xbox / Joystick)"
	lbl_xbox.position = Vector2(32.0, 88.0)
	lbl_xbox.size = Vector2(pw - 64.0, 30.0)
	Leve.font_size(lbl_xbox, "font_size", 18)
	Leve.color(lbl_xbox, "font_color", Color(0.85, 0.85, 0.85))
	Leve.color(lbl_xbox, "font_outline_color", Color.BLACK)
	Leve.constant(lbl_xbox, "outline_size", 5)
	modal_sens_panel.add_child(lbl_xbox)

	slider_xbox = _criar_slider(modal_sens_panel, Vector2(32.0, 122.0), pw - 180.0,
		SENS_XBOX_MIN, SENS_XBOX_MAX, velocidade_mira_xbox)
	slider_xbox.value_changed.connect(_on_slider_xbox_changed)

	label_valor_xbox = _criar_label_valor(modal_sens_panel, Vector2(pw - 130.0, 118.0))
	label_valor_xbox.text = _formatar_xbox(velocidade_mira_xbox)

	# Divisor secundário
	var div2 := ColorRect.new()
	div2.color = Color(1.0, 0.02, 0.02, 0.25)
	div2.position = Vector2(32.0, 175.0)
	div2.size = Vector2(pw - 64.0, 1.0)
	modal_sens_panel.add_child(div2)

	# Seção Mouse
	var lbl_mouse := Label.new()
	lbl_mouse.text = "🖱  Mouse"
	lbl_mouse.position = Vector2(32.0, 186.0)
	lbl_mouse.size = Vector2(pw - 64.0, 30.0)
	Leve.font_size(lbl_mouse, "font_size", 18)
	Leve.color(lbl_mouse, "font_color", Color(0.85, 0.85, 0.85))
	Leve.color(lbl_mouse, "font_outline_color", Color.BLACK)
	Leve.constant(lbl_mouse, "outline_size", 5)
	modal_sens_panel.add_child(lbl_mouse)

	var sens_mouse_atual: float = SENS_MOUSE_PADRAO
	if get_tree().has_meta(META_SENS_MOUSE):
		sens_mouse_atual = float(get_tree().get_meta(META_SENS_MOUSE))

	slider_mouse = _criar_slider(modal_sens_panel, Vector2(32.0, 220.0), pw - 180.0,
		SENS_MOUSE_MIN, SENS_MOUSE_MAX, sens_mouse_atual)
	slider_mouse.step = 0.05
	slider_mouse.value_changed.connect(_on_slider_mouse_changed)

	label_valor_mouse = _criar_label_valor(modal_sens_panel, Vector2(pw - 130.0, 216.0))
	label_valor_mouse.text = _formatar_mouse(sens_mouse_atual)

	# Nota
	var nota := Label.new()
	nota.text = "As alterações são aplicadas imediatamente em todos os cenários."
	nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nota.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nota.position = Vector2(0.0, 270.0)
	nota.size = Vector2(pw, 28.0)
	Leve.font_size(nota, "font_size", 14)
	Leve.color(nota, "font_color", Color(0.55, 0.55, 0.55, 1.0))
	Leve.color(nota, "font_outline_color", Color.BLACK)
	Leve.constant(nota, "outline_size", 4)
	modal_sens_panel.add_child(nota)

	# Botão Fechar
	var estilo_fechar := StyleBoxFlat.new()
	estilo_fechar.bg_color = Color(0.22, 0.02, 0.02, 0.96)
	estilo_fechar.border_width_left = 2
	estilo_fechar.border_width_top = 2
	estilo_fechar.border_width_right = 2
	estilo_fechar.border_width_bottom = 2
	estilo_fechar.border_color = Color(1.0, 0.08, 0.08, 0.9)
	estilo_fechar.corner_radius_top_left = 22
	estilo_fechar.corner_radius_top_right = 22
	estilo_fechar.corner_radius_bottom_left = 22
	estilo_fechar.corner_radius_bottom_right = 22
	var estilo_fechar_hover := estilo_fechar.duplicate() as StyleBoxFlat
	estilo_fechar_hover.bg_color = Color(0.34, 0.02, 0.02, 1.0)
	estilo_fechar_hover.border_color = Color(1.0, 0.3, 0.3, 1.0)

	var btn_fechar := Button.new()
	btn_fechar.name = "btn_fechar_sens"     # ← nome usado no hit-test do Xbox
	btn_fechar.text = "✔  FECHAR"
	btn_fechar.focus_mode = Control.FOCUS_NONE
	btn_fechar.position = Vector2(floor((pw - 220.0) * 0.5), 308.0)
	btn_fechar.size = Vector2(220.0, 48.0)
	btn_fechar.pivot_offset = Vector2(110.0, 24.0)
	Leve.font_size(btn_fechar, "font_size", 22)
	Leve.color(btn_fechar, "font_color", Color(1.0, 0.78, 0.78))
	Leve.color(btn_fechar, "font_hover_color", Color.WHITE)
	Leve.color(btn_fechar, "font_pressed_color", Color.WHITE)
	Leve.color(btn_fechar, "font_outline_color", Color.BLACK)
	Leve.constant(btn_fechar, "outline_size", 4)
	Leve.stylebox(btn_fechar, "normal", estilo_fechar)
	Leve.stylebox(btn_fechar, "hover", estilo_fechar_hover)
	Leve.stylebox(btn_fechar, "pressed", estilo_fechar_hover)
	btn_fechar.pressed.connect(_fechar_modal_sensibilidade)
	modal_sens_panel.add_child(btn_fechar)


func _criar_slider(
	pai: Control,
	pos: Vector2,
	largura: float,
	minv: float,
	maxv: float,
	valor: float
) -> HSlider:

	var sl := HSlider.new()

	sl.min_value = minv
	sl.max_value = maxv
	sl.value = valor

	sl.step = 0.01
	sl.scrollable = true
	sl.editable = true

	sl.mouse_filter = Control.MOUSE_FILTER_PASS
	sl.focus_mode = Control.FOCUS_ALL

	sl.position = pos
	sl.size = Vector2(largura, 56.0)

	pai.add_child(sl)

	return sl


func _criar_label_valor(pai: Control, pos: Vector2) -> Label:
	var lbl := Label.new()
	lbl.position = pos
	lbl.size = Vector2(134.0, 40.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(lbl, "font_size", 22)
	Leve.color(lbl, "font_color", Color(1.0, 0.92, 0.72))
	Leve.color(lbl, "font_outline_color", Color.BLACK)
	Leve.constant(lbl, "outline_size", 6)
	pai.add_child(lbl)
	return lbl


func _formatar_xbox(v: float) -> String:
	var pct := int(round((v - SENS_XBOX_MIN) / (SENS_XBOX_MAX - SENS_XBOX_MIN) * 100.0))
	return str(pct) + " %"


func _formatar_mouse(v: float) -> String:
	return "%.2f x" % v


func _on_slider_xbox_changed(valor: float) -> void:
	velocidade_mira_xbox = clamp(valor, SENS_XBOX_MIN, SENS_XBOX_MAX)
	get_tree().set_meta(META_SENS_XBOX, velocidade_mira_xbox)

	if label_valor_xbox != null:
		label_valor_xbox.text = _formatar_xbox(velocidade_mira_xbox)



func _on_slider_mouse_changed(valor: float) -> void:
	sensibilidade_mouse = clamp(
		valor,
		SENS_MOUSE_MIN,
		SENS_MOUSE_MAX
	)

	# aplica NA HORA
	get_tree().set_meta(
		META_SENS_MOUSE,
		sensibilidade_mouse
	)

	mouse_delta_acumulado = Vector2.ZERO

	if label_valor_mouse != null:
		label_valor_mouse.text = _formatar_mouse(
			sensibilidade_mouse
		)

	# feedback instantâneo
	var tween := create_tween()
	tween.tween_property(
		botao_sensibilidade,
		"scale",
		Vector2(1.08, 1.08),
		0.08
	)

	tween.tween_property(
		botao_sensibilidade,
		"scale",
		Vector2.ONE,
		0.08
	)



func _animar_entrada_modal_sensibilidade() -> void:
	if modal_sens_panel == null:
		return
	modal_sens_panel.scale = Vector2(0.88, 0.88)
	modal_sens_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(modal_sens_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(modal_sens_panel, "modulate:a", 1.0, 0.18)



func _fechar_modal_sensibilidade() -> void:
	if not modal_sens_ativo:
		return

	modal_sens_ativo = false

	# salva definitivo
	get_tree().set_meta(
		META_SENS_MOUSE,
		sensibilidade_mouse
	)

	get_tree().set_meta(
		META_SENS_XBOX,
		velocidade_mira_xbox
	)

	if modal_sens_root != null:
		modal_sens_root.queue_free()

	modal_sens_root = null
	modal_sens_panel = null

	mouse_delta_acumulado = Vector2.ZERO

	# volta mira customizada
	Input.set_mouse_mode(
		Input.MOUSE_MODE_CAPTURED
	)

	var centro := get_viewport_rect().size * 0.5
	alvo_pos = centro

	if not modal_ativo \
	and not aleatorio_em_andamento:
		auto_timer_ativo = true



# ─────────────────────────────────────────────────────────────────────────────
# TRANSIÇÃO DE CENAS
# ─────────────────────────────────────────────────────────────────────────────
func _abrir_cena_suave_com_tiro(caminho: String) -> void:
	call_deferred("_abrir_cena_suave_com_tiro_async", caminho)


func _abrir_cena_suave_com_tiro_async(caminho: String) -> void:
	if caminho == "" or not ResourceLoader.exists(caminho):
		push_error("Cena não encontrada: " + caminho)
		return

	entrada_bloqueada = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	await get_tree().create_timer(0.10).timeout

	TransicaoGlobal.trocar_cena(caminho)



func _abrir_cena_suave(caminho: String) -> void:
	_call_abrir_cena_suave_async(caminho)



func _call_abrir_cena_suave_async(caminho: String) -> void:
	await _abrir_cena_suave_async(caminho)



func _abrir_cena_suave_async(caminho: String) -> void:
	if caminho == "" or not ResourceLoader.exists(caminho):
		push_error("Cena não encontrada: " + caminho)
		return

	entrada_bloqueada = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	TransicaoGlobal.trocar_cena(caminho)


var _shader_arredondado: Shader = null

func _criar_material_imagem_arredondada(tamanho: Vector2, raio: float) -> ShaderMaterial:
	if _shader_arredondado == null:
		_shader_arredondado = Shader.new()
		_shader_arredondado.code = """
			shader_type canvas_item;
			uniform vec2 rect_size = vec2(400.0, 180.0);
			uniform float radius = 34.0;

			varying vec2 v_local;

			void vertex() {
				// Posição local real do pixel (independente do stretch mode)
				v_local = VERTEX;
			}

			float rounded_box(vec2 p, vec2 b, float r) {
				vec2 q = abs(p) - b + vec2(r);
				return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
			}

			void fragment() {
				vec2 p = v_local - rect_size * 0.5;
				vec2 b = rect_size * 0.5;
				float d = rounded_box(p, b, radius);

				float aa = fwidth(d);
				float alpha = 1.0 - smoothstep(-aa, aa, d);

				vec4 tex = texture(TEXTURE, UV) * COLOR;
				COLOR = vec4(tex.rgb, tex.a * alpha);
			}
		"""

	var mat := ShaderMaterial.new()
	mat.shader = _shader_arredondado
	mat.set_shader_parameter("rect_size", tamanho)
	mat.set_shader_parameter("radius", raio)
	return mat




func _cor_neon_card(indice: int, lado: String = "") -> Color:
	match indice:
		0: # DESERTO: esquerda amarelo / direita branco
			if lado == "right" or lado == "top_right" or lado == "bottom_right":
				return Color(1.0, 1.0, 0.92, 1.0)
			return Color(1.0, 0.72, 0.08, 1.0)

		1: # MAR
			return Color(0.0, 0.65, 1.0, 1.0)

		2: # BAR
			return Color(0.25, 1.0, 0.35, 1.0)

		3: # ARENA
			return Color(1.0, 0.02, 0.02, 1.0)

	return Color(1.0, 0.02, 0.02, 1.0)



func _aplicar_estilo_card_por_indice(card: Panel, indice: int, hover: bool = false) -> void:
	if card == null:
		return

	var estilo := StyleBoxFlat.new()

	# FUNDO 100% TRANSPARENTE: a imagem fica limpa
	estilo.bg_color = Color(0.0, 0.0, 0.0, 0.0)

	# Sem borda no Panel principal, porque a moldura colorida já fica por cima da imagem
	estilo.border_width_left = 0
	estilo.border_width_top = 0
	estilo.border_width_right = 0
	estilo.border_width_bottom = 0

	estilo.corner_radius_top_left = 42
	estilo.corner_radius_top_right = 42
	estilo.corner_radius_bottom_left = 42
	estilo.corner_radius_bottom_right = 42

	# Sombra bem leve, sem colorir o card inteiro
	estilo.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	estilo.shadow_size = 12
	estilo.shadow_offset = Vector2(0, 6)

	Leve.stylebox(card, "panel", estilo)


func _evento_input_shot_menu(event: InputEvent) -> bool:
	if event == null:
		return false

	if event is InputEventMouseMotion:
		return false

	if event is InputEventKey:
		var k := event as InputEventKey
		if k.echo:
			return false

	return event.is_action_pressed(ACAO_TIRO_MENU)


func _executar_tiro_menu() -> void:
	if tempo_trava_input_menu > 0.0:
		return

	tempo_trava_input_menu = 0.10

	if modal_ativo:
		_tentar_escolher_dificuldade_por_mira()
		return

	_tocar_tiro()
	_tentar_selecao_por_tiro(alvo_pos)
