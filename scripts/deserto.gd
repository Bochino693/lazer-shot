extends Node2D

class TargetData:
	extends RefCounted

	var node: Area2D
	var tipo: String = ""
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var vel_base: float = 150.0      # rapidez com que nasceu (as batidas não aceleram)
	var idade: float = 0.0
	var vida: float = 4.0
	var raio: float = 48.0
	var raio_inicial: float = 48.0
	var raio_final: float = 24.0
	@warning_ignore("shadowed_global_identifier")
	var seed: float = 0.0
	var movimento: int = 0
	var valor_correto: int = 100
	var penalidade_errado: int = 20
	var halo: Node2D = null
	var brilho: Node2D = null
	var brilho_frente: Node2D = null
	var raio_colisao_base: float = 44.0
	var raio_miolo_base: float = 24.0
	
	var tempo_para_trocar: float = 0.0
	var ja_trocou: bool = false
	var flash_troca_t: float = 0.0
	var tempo_sem_se_mover: float = 0.0
	var guinada_t: float = 1.0          # até a próxima guinada (muda de rumo de repente)
	var swap_idade: float = -1.0       # idade no momento da troca (-1 = nunca trocou)
	var swap_escala_inicio: float = 1.0  # escala no momento da troca
	# 3D: o brasão vive na cena do fundo. pos é onde ele estaria no plano
	# Z = 1; na tela fica em fuga + (pos - fuga) / z + paralaxe da câmera,
	# com tamanho 1/z. Ele vai se afastando com a idade (era o encolhimento).
	var z: float = 1.0
	var z_de: float = 1.0          # distância depois da entrada
	var z_ate: float = 2.2         # distância no fim da vida
	var z_entrada: float = 1.0     # de onde entra (horizonte: bem longe)
	var swap_z: float = 1.0        # distância no momento da troca
	var tam: float = 1.0           # tamanho próprio (nem todos iguais)
	var estilo: String = "lado"    # lado | horizonte | alto_l | atras
	var entrada: float = 0.6       # duração da entrada (s)
	var saida: String = "vidro"    # vidro (vem para perto e some) | longe
	var l_virou: bool = false      # alto_l: já fez a quina do L
	var tela: Vector2 = Vector2.ZERO
	var alfa: float = 1.0


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
var ranking_nome_digitado: String = ""
var ranking_nome_timer_label: Label = null
var spawn_timer_continuo: float = 0.0
var intervalo_spawn_continuo: float = 0.85

const TeiaAlvo := preload("res://scripts/teia_alvo.gd")

# 3D: estilos de entrada (pesos), quanto dura a saída, a partir de que
# distância o acerto vale "DE LONGE!" e o bônus dele
const ESTILOS_3D := {"lado": 0.32, "horizonte": 0.30, "alto_l": 0.24, "atras": 0.14}
const SAIDA_TEMPO := 0.55
const Z_DE_LONGE := 2.0
# descarga do cristal: cada acerto certo carrega 1/8; brasão errado tira 1/4
const CARGA_POR_ACERTO := 0.125
const CARGA_ERRO := 0.25
const BONUS_DE_LONGE := 0.5
# de trás de quem um brasão "atras" pode sair (px da imagem do fundo)
const SAIDAS_DE_TRAS := [Vector2(507, 760), Vector2(209, 880), Vector2(812, 880)]
var TEX_FURO_AREIA: Texture2D = load("res://sprites/fx_furo_areia.png")
var TEX_FURO_PEDRA: Texture2D = load("res://sprites/fx_furo_pedra.png")
var TEX_FUMACA: Texture2D = load("res://sprites/fx_fumaca.png")
var _furos: Furos = null
var _pontos: PontosVoando = null
const Pincel := preload("res://scripts/pincel.gd")
const FONTE_TEXTO: String = "res://fonts/Exo2-Bold.ttf"
# Títulos: mesma família do jogo (todos os acentos, letras alinhadas).
const FONTE_LUCKIEST: String = "res://fonts/Exo2-ExtraBold.ttf"
const ACAO_TIRO_ARMA: String = "input_shot"
const ACAO_RECARGA_ARMA: String = "input_recharge"


var fonte_orbitron: FontFile = null
var fonte_luckiest: FontFile = null


var ranking_precisao_pendente: int = 0

var ranking_nome_ativo: bool = false
var ranking_nome_tempo: float = 50.0
var nome_ranking: NomeRanking = null   # tela de nome (igual em todas as fases)
var ranking_pontos_pendentes: int = 0
var ranking_cenario_pendente: String = "DESERTO"
var ranking_ja_salvo: bool = false


var status_msgs: Array = []
var status_labels: Array[Label] = []

var melhor_combo: int = 0
var status_timer: float = 0.0
var status_cor_base: Color = Color.WHITE
var fim_contagem_label: Label = null
var fim_tempo_voltar: float = 17.0


@export var colisao_alvos_ativa: bool = true
@export var margem_colisao_alvos: float = 15.0
@export var forca_repelir_alvos: float = 1.25

@export_file("*.tscn") var cena_main_menu: String = "res://scenes/main.tscn"


# Ritmo: sol e lua rápidos e com guinadas de rumo (fazer pontos exige mira),
# brasão que troca mais vezes e dificuldade que sobe cedo.
@export var chance_troca_brasao_base: float = 0.25
@export var chance_troca_brasao_max: float = 0.55
@export var velocidade_minima_alvo: float = 140.0
@export var intervalo_spawn_continuo_min: float = 0.45
@export var velocidade_alvo_min: float = 215.0
@export var velocidade_alvo_max: float = 330.0

@export var tempo_partida: float = 120.0
@export var tempo_troca_modo: float = 30.0

@export var capacidade_cartucho: int = 30
@export var tempo_recarga_seg: float = 1.10

@export var preview_scale: float = 0.52
@export var alvo_scale_base: float = 0.66
@export var alvo_scale_min: float = 0.27

@export var faixa_spawn_topo: float = 330.0
@export var faixa_spawn_base_margem: float = 180.0

# o tiro de dia é o raio de sol e de noite o de luar (a pistola é do Bar)
@export var som_tiro_path: String = "res://songs/tiro_sol.wav"
@export var som_tiro_lua_path: String = "res://songs/tiro_lua.wav"
@export var som_recharge_path: String = "res://songs/recharge.wav"
@export var som_bullet_no_path: String = "res://songs/bullet_no.wav"
@export var som_fim_path: String = "res://songs/end_game.mp3"
@export var som_egito_path: String = "res://songs/egito.mp3"
@export var som_hit_sun_path: String = "res://songs/hit-sun.wav"
var som_hit_sun: AudioStream = null
@export var som_hit_moon_path: String = "res://songs/hit-moon.wav"
var som_hit_moon: AudioStream = null

@export var usar_controle_xbox: bool = true
@export var velocidade_mira_xbox: float = 920.0
@export var deadzone_xbox: float = 0.18

# PADRÃO IGUAL ARENA E BAR
@export var xbox_botao_tiro: int = JOY_BUTTON_RIGHT_SHOULDER # R1
@export var xbox_botao_recarga: int = JOY_BUTTON_LEFT_SHOULDER # L1
@export var xbox_botao_recarga_extra: int = JOY_BUTTON_LEFT_SHOULDER

var xbox_mira_iniciada: bool = false

const MODO_SOL: String = "sol"
const MODO_LUA: String = "lua"

const COR_SOL: Color = Color(1.0, 0.74, 0.18, 1.0)
const COR_LUA: Color = Color(0.56, 0.84, 1.0, 1.0)

const COR_HUD_BG: Color = Color(0.04, 0.06, 0.10, 0.98)
const COR_HUD_CARD: Color = Color(0.07, 0.10, 0.17, 0.98)

@export var offset_sprite_lua: Vector2 = Vector2.ZERO   # o brasão novo já é centrado

const JANELA_COMBO: float = 2.2

const META_SENS_XBOX: String = "sensibilidade_xbox"
const META_SENS_MOUSE: String = "sensibilidade_mouse"

@export var sensibilidade_mouse: float = 1.0
var mouse_delta_acumulado: Vector2 = Vector2.ZERO


@onready var background_video_root: Node2D = $BackgroundVideo
# Fundo: o Egito vivo em camadas na placa de vídeo (scripts/deserto_vivo.gd):
# sol com o Olho de Rá, lua com o Olho de Hórus, luz girando em volta, pontas
# de ouro nas pirâmides e o diamante brilhando; troca sol/lua com clarão.
var _vivo: DesertoVivo = null
# HUD: só refaz estilo e barra de munição quando algo muda (antes era todo
# quadro, e o estilo do modo apagava o aviso vermelho/laranja do TEMPO).
var _hud_estilo_modo: String = ""
var _barra_balas: int = -1
var _barra_tam: Vector2 = Vector2.ZERO
var _fundo_modo: String = ""

@onready var target_root: Node2D = $Alvos
@onready var sun_modelo: Area2D = $Alvos/Sun
@onready var lua_modelo: Area2D = $Alvos/Lua

var som_tiro: AudioStream = null
var som_tiro_lua: AudioStream = null
var som_recharge: AudioStream = null
var som_bullet_no: AudioStream = null
var som_fim: AudioStream = null
var som_egito: AudioStream = null

var fim_music_player: AudioStreamPlayer = null
var bg_music_player: AudioStreamPlayer = null

var modal_inicio_bg: ColorRect = null
var modal_inicio_panel: TextureRect = null
var modal_inicio_titulo: Label = null
var modal_inicio_texto: Label = null
var modal_inicio_footer: Label = null
var modal_como_jogar: ComoJogar = null

var hud_layer: CanvasLayer = null
var hud_root: Control = null
var overlay_layer: CanvasLayer = null
var overlay_root: Control = null
var crosshair_overlay: Control = null

var fx_front_layer: CanvasLayer = null
var fx_front_overlay: Control = null

var marcas_tiro_errado: Array[Dictionary] = []
var fx_cacos: Array[Dictionary] = []

var fim_layer: CanvasLayer = null
var fim_root: Control = null

var label_score: Label = null
var label_timer: Label = null
var label_modo: Label = null
var label_tiros: Label = null
var label_acertos: Label = null
var label_municao_estado: Label = null
var label_recarga: Label = null
var label_status: Label = null
var label_combo: Label = null
var _anuncio: ComboAnuncio = null   # o combo grande no meio da tela, com a voz do templo


var modal_inicio_subtitulo: Label = null

var modal_card_correto: ColorRect = null
var modal_card_errado: ColorRect = null
var modal_card_vazio: ColorRect = null

var modal_lbl_correto_titulo: Label = null
var modal_lbl_correto_texto: Label = null

var modal_lbl_errado_titulo: Label = null
var modal_lbl_errado_texto: Label = null

var modal_lbl_vazio_titulo: Label = null
var modal_lbl_vazio_texto: Label = null

var countdown_label: Label = null

var fim_bg: ColorRect = null
var fim_panel: Panel = null
var fim_titulo: Label = null
var fim_texto: Label = null
var fim_footer: Label = null

var preview_sol: Area2D = null
var preview_lua: Area2D = null

var municao_blocos: Array[ColorRect] = []
var alvos_ativos: Array[TargetData] = []

var jogo_ativo: bool = true
var partida_iniciada: bool = false
var intro_ativa: bool = true
var countdown_ativo: bool = false
var fim_ativo: bool = false

var modo_atual: String = MODO_SOL
var tempo_restante: float = 0.0
var tempo_fase: float = 0.0
var tempo_total_partida: float = 0.0
var nivel_dificuldade: float = 1.0

var balas_no_cartucho: int = 30
var recarregando: bool = false
var reload_tempo_restante: float = 0.0

var pontuacao_total: int = 0
var total_tiros: int = 0
var total_acertos: int = 0
var total_erros: int = 0

var combo_tipo: String = ""
var combo_qtd: int = 0
var combo_timer: float = 0.0

var mira_pos: Vector2 = Vector2.ZERO
var alvo_anim_t: float = 0.0
var aviso_recarga_t: float = 0.0
var fim_pulso_t: float = 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	var tela := get_viewport_rect().size
	mira_pos = tela * 0.5
	mouse_delta_acumulado = Vector2.ZERO

	randomize()

	_aplicar_sensibilidade_global()
	_carregar_config_admin_jogo()
	_carregar_fontes_ui()

	_carregar_assets()
	_preparar_modelos()
	_configurar_background()
	_configurar_hud()
	_instalar_placar()
	_configurar_overlay()
	_configurar_fx_frontal()
	_configurar_modal_inicio()
	_configurar_countdown()
	_configurar_modal_fim()
	FimPartida.instalar(self, COR_SOL, func() -> bool: return fim_ativo and not ranking_nome_ativo, 150)

	balas_no_cartucho = capacidade_cartucho
	tempo_restante = tempo_partida
	tempo_fase = 0.0
	tempo_total_partida = 0.0
	nivel_dificuldade = 1.0
	modo_atual = MODO_SOL if randi() % 2 == 0 else MODO_LUA

	_aplicar_background_modo()
	_atualizar_hud()
	_tocar_musica_bg()

	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

	call_deferred("_ajustar_layout")


func _exit_tree() -> void:
	_parar_musica_bg()
	_parar_musica_fim()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
	tempo_trava_input_arma = max(0.0, tempo_trava_input_arma - delta)
	alvo_anim_t += delta
	aviso_recarga_t += delta
	fim_pulso_t += delta
	
	
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_atualizar_mira_hibrida(delta)
	if _vivo != null:
		_vivo.mira = mira_pos      # a câmera 3D do fundo anda com a mira

	if ranking_nome_ativo and nome_ranking != null:
		nome_ranking.mira(mira_pos)

	var modal_aberto: bool = intro_ativa or countdown_ativo or fim_ativo

	if modal_aberto:
		if fim_ativo and not ranking_nome_ativo:
			fim_tempo_voltar = max(0.0, fim_tempo_voltar - delta)

		if fim_contagem_label != null:
			if ranking_nome_ativo:
				fim_contagem_label.text = "DIGITE SEU NOME PARA SALVAR O RECORDE"
				fim_contagem_label.modulate.a = 1.0
			else:
				fim_contagem_label.text = "VOLTANDO AO INÍCIO EM %02d" % int(ceil(fim_tempo_voltar))
				var pulso: float = 0.72 + abs(sin(fim_pulso_t * 4.0)) * 0.28
				fim_contagem_label.modulate.a = pulso

		if fim_tempo_voltar <= 0.0 and not ranking_nome_ativo:
			FimPartida.voltar_a_abertura()
			return

	if crosshair_overlay != null:
		# no resultado a mira fica por cima do modal (botão VOLTAR AOS CENÁRIOS)
		if ranking_nome_ativo or fim_ativo:
			if overlay_layer != null:
				overlay_layer.layer = 220

			crosshair_overlay.visible = true
			crosshair_overlay.queue_redraw()
		else:
			if overlay_layer != null:
				overlay_layer.layer = 90

			crosshair_overlay.visible = intro_ativa or ranking_nome_ativo or fim_ativo or not modal_aberto
			if crosshair_overlay.visible:
				crosshair_overlay.queue_redraw()

	if modal_aberto:
		if fx_front_overlay != null:
			fx_front_overlay.visible = false

		if label_status != null:
			label_status.visible = false

		if label_combo != null and not partida_iniciada:
			label_combo.visible = false

		_atualizar_modal_inicio()
		_atualizar_modal_fim()
		return

	if recarregando:
		reload_tempo_restante = max(0.0, reload_tempo_restante - delta)
		if reload_tempo_restante <= 0.0:
			_finalizar_recarga()

	for i in range(status_msgs.size() - 1, -1, -1):
		status_msgs[i]["time"] -= delta
		if status_msgs[i]["time"] <= 0:
			status_msgs.remove_at(i)

	for i in range(status_labels.size()):
		var lbl := status_labels[i]

		if i < status_msgs.size():
			var msg = status_msgs[status_msgs.size() - 1 - i]
			lbl.text = msg["text"]
			lbl.modulate = msg["cor"]
			lbl.modulate.a = clamp(msg["time"], 0.0, 1.0)
			lbl.visible = true
		else:
			lbl.visible = false

	if jogo_ativo and partida_iniciada:
		tempo_restante = max(0.0, tempo_restante - delta)
		tempo_fase += delta
		tempo_total_partida += delta

		if pontuacao_total < 800:
			nivel_dificuldade = 1.0
		else:
			nivel_dificuldade = 1.0 + floor((pontuacao_total - 800) / 450.0) * 0.55
			nivel_dificuldade = min(nivel_dificuldade, 5.2)

		if tempo_fase >= tempo_troca_modo:
			tempo_fase = 0.0
			_trocar_modo()

		if tempo_restante <= 0.0:
			_encerrar_jogo()
			return

		_atualizar_combo(delta)
		_spawn_continuo(delta)
		_atualizar_alvos(delta)

	_atualizar_hud()
	_atualizar_modal_inicio()
	_atualizar_modal_fim()
	_atualizar_marcas_tiro_errado(delta)
	_atualizar_fx_cacos(delta)

	if fx_front_overlay != null:
		fx_front_overlay.visible = not modal_aberto
		if not modal_aberto and (marcas_tiro_errado.size() > 0 or fx_cacos.size() > 0):
			fx_front_overlay.queue_redraw()

	if crosshair_overlay != null:
		crosshair_overlay.visible = not modal_aberto
		if not modal_aberto:
			crosshair_overlay.queue_redraw()


func _atualizar_mira_hibrida(_delta: float) -> void:
	# mira única do jogo (MiraGlobal): mesma em todas as telas, sem saltos
	mira_pos = MiraGlobal.pos


func _input(event: InputEvent) -> void:
	# ============================================================
	# MOVIMENTO DA MIRA
	# ============================================================
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		mouse_delta_acumulado += mm.relative
		return

	# ============================================================
	# START reinicia somente no modal final
	# ============================================================
	if event.is_action_pressed("input_start"):
		if fim_ativo and not ranking_nome_ativo:
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
	# CONTROLE XBOX — FALLBACK
	# Continua funcionando mesmo se não estiver mapeado no Input Map.
	# ============================================================
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton

		if not jb.pressed:
			return

		print("DEBUG XBOX DESERTO:", jb.button_index)

		if jb.button_index == xbox_botao_tiro:
			_executar_tiro_arma()
			return

		if jb.button_index == xbox_botao_recarga or jb.button_index == xbox_botao_recarga_extra:
			_executar_recarga_arma()
			return

	# ============================================================
	# MOUSE / ARMA COMO MOUSE — FALLBACK
	# Mantém botão esquerdo como tiro e direito como recarga.
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
	# TOUCH
	# ============================================================
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch

		if touch.pressed:
			var pos_canvas: Vector2 = _pos_tela_para_canvas(touch.position)

			if intro_ativa:
				_iniciar_countdown()
				return

			if jogo_ativo and partida_iniciada and not fim_ativo and not countdown_ativo:
				_processar_tiro(pos_canvas)
				return

	# ============================================================
	# TECLADO — FALLBACK DE RECARGA
	# ============================================================
	if event is InputEventKey:
		var ke := event as InputEventKey

		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_R:
				if jogo_ativo and partida_iniciada and not fim_ativo and not countdown_ativo and not recarregando:
					_iniciar_recarga()
				return


func _ranking_tentar_atirar_tecla(pos_tiro: Vector2) -> void:
	if not ranking_nome_ativo or nome_ranking == null:
		return
	if tempo_trava_input_arma > 0.0:
		return
	tempo_trava_input_arma = 0.10
	_tocar_som(_som_do_tiro())
	nome_ranking.tiro(pos_tiro)


func _criar_nome_ranking() -> void:
	nome_ranking = NomeRanking.new()
	add_child(nome_ranking)
	nome_ranking.confirmado.connect(_ao_confirmar_nome)


func _ao_confirmar_nome(nome: String) -> void:
	ranking_nome_digitado = "" if nome == "ANONIMO" else nome
	_confirmar_nome_ranking(nome == "ANONIMO")


func _som_do_tiro() -> AudioStream:
	if modo_atual == MODO_LUA and som_tiro_lua != null:
		return som_tiro_lua
	return som_tiro


func _carregar_assets() -> void:
	if ResourceLoader.exists(som_tiro_path):
		som_tiro = load(som_tiro_path)
	if ResourceLoader.exists(som_tiro_lua_path):
		som_tiro_lua = load(som_tiro_lua_path)

	if ResourceLoader.exists(som_recharge_path):
		som_recharge = load(som_recharge_path)

	if ResourceLoader.exists(som_bullet_no_path):
		som_bullet_no = load(som_bullet_no_path)

	if ResourceLoader.exists(som_fim_path):
		som_fim = load(som_fim_path)

	if ResourceLoader.exists(som_egito_path):
		som_egito = load(som_egito_path)

	if ResourceLoader.exists(som_hit_sun_path):
		som_hit_sun = load(som_hit_sun_path)

	if ResourceLoader.exists(som_hit_moon_path):
		som_hit_moon = load(som_hit_moon_path)


func _tocar_musica_bg() -> void:
	if som_egito == null:
		return

	if bg_music_player == null:
		bg_music_player = AudioStreamPlayer.new()
		bg_music_player.bus = "Master"
		add_child(bg_music_player)

		bg_music_player.finished.connect(func() -> void:
			if bg_music_player != null and is_instance_valid(bg_music_player):
				bg_music_player.play()
		)

	if bg_music_player.stream != som_egito:
		bg_music_player.stream = som_egito

	if not bg_music_player.playing:
		bg_music_player.play()


func _parar_musica_bg() -> void:
	if bg_music_player != null and bg_music_player.playing:
		bg_music_player.stop()


func _preparar_modelos() -> void:
	if sun_modelo != null:
		sun_modelo.visible = false
		sun_modelo.monitoring = false
		sun_modelo.monitorable = false
		sun_modelo.process_mode = Node.PROCESS_MODE_DISABLED

	if lua_modelo != null:
		lua_modelo.visible = false
		lua_modelo.monitoring = false
		lua_modelo.monitorable = false
		lua_modelo.process_mode = Node.PROCESS_MODE_DISABLED


func _obter_animado(area: Area2D) -> AnimatedSprite2D:
	if area == null:
		return null

	for filho in area.get_children():
		if filho is AnimatedSprite2D:
			return filho as AnimatedSprite2D

	return null


func _configurar_background() -> void:
	if background_video_root != null:
		background_video_root.z_index = -1000
		background_video_root.y_sort_enabled = false

	_vivo = DesertoVivo.new()
	(background_video_root if background_video_root != null else self).add_child(_vivo)
	# furos de bala na areia e na pedra, com a poeira que fica pairando
	# (no fundo: andam com a câmera junto com o chão)
	_furos = Furos.new()
	_furos.name = "Furos"
	_furos.tex_areia = TEX_FURO_AREIA
	_furos.tex_pedra = TEX_FURO_PEDRA
	_furos.tex_fumaca = TEX_FUMACA
	_furos.deslocar = _vivo.deslocamento_no_chao
	_vivo.add_child(_furos)

	if target_root != null:
		target_root.z_index = 50
		target_root.y_sort_enabled = false

	if sun_modelo != null:
		sun_modelo.z_index = 60

	if lua_modelo != null:
		lua_modelo.z_index = 60


func _on_viewport_size_changed() -> void:
	_ajustar_background_full()
	_ajustar_layout()


func _ajustar_background_full() -> void:
	if _vivo != null:
		_vivo.ajustar()


func _aplicar_background_modo() -> void:
	if _vivo == null or _fundo_modo == modo_atual:
		return
	# a primeira vez entra direto; depois troca com o clarão
	_vivo.mostrar(modo_atual, _fundo_modo != "")
	_fundo_modo = modo_atual


func _configurar_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 20
	add_child(hud_layer)

	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)

	var top_bar: ColorRect = ColorRect.new()
	top_bar.name = "TopBar"
	top_bar.color = COR_HUD_BG
	hud_root.add_child(top_bar)

	var glow: ColorRect = ColorRect.new()
	glow.name = "TopGlow"
	glow.color = Color(0.18, 0.88, 1.0, 0.12)
	hud_root.add_child(glow)

	var line: ColorRect = ColorRect.new()
	line.name = "TopLine"
	line.color = Color(0.20, 0.92, 1.0, 0.84)
	hud_root.add_child(line)

	var card_tempo: Panel = _criar_card_hud("Tempo")
	card_tempo.name = "CardTempo"
	hud_root.add_child(card_tempo)

	var card_score: Panel = _criar_card_hud("Pontuação")
	card_score.name = "CardScore"
	hud_root.add_child(card_score)

	var card_modo: Panel = _criar_card_hud("Modo")
	card_modo.name = "CardModo"
	hud_root.add_child(card_modo)

	var card_municao: Panel = _criar_card_hud("Munição")
	card_municao.name = "CardMunicao"
	hud_root.add_child(card_municao)

	var card_tiros: Panel = _criar_card_hud("Tiros")
	card_tiros.name = "CardTiros"
	hud_root.add_child(card_tiros)

	var card_acertos: Panel = _criar_card_hud("Acertos")
	card_acertos.name = "CardAcertos"
	hud_root.add_child(card_acertos)

	label_timer = _criar_valor_card(38, Color(0.82, 0.94, 1.0, 1.0))
	card_tempo.add_child(label_timer)

	label_score = _criar_valor_card(48, Color(0.62, 0.99, 0.96, 1.0))
	card_score.add_child(label_score)

	label_modo = _criar_valor_card(28, Color.WHITE)
	card_modo.add_child(label_modo)

	label_municao_estado = _criar_valor_card(20, Color(0.84, 1.0, 0.92, 1.0))
	card_municao.add_child(label_municao_estado)

	label_tiros = _criar_valor_card(32, Color.WHITE)
	card_tiros.add_child(label_tiros)

	label_acertos = _criar_valor_card(32, Color.WHITE)
	card_acertos.add_child(label_acertos)

	label_recarga = Label.new()
	label_recarga.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_recarga.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(label_recarga, "font_size", 16)
	Leve.color(label_recarga, "font_color", Color(0.76, 0.88, 1.0, 0.95))
	Leve.color(label_recarga, "font_outline_color", Color.BLACK)
	Leve.constant(label_recarga, "outline_size", 4)
	hud_root.add_child(label_recarga)

	for i in range(3):
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		Leve.font_size(lbl, "font_size", 30 - (i * 2))
		Leve.color(lbl, "font_color", Color.WHITE)
		Leve.color(lbl, "font_outline_color", Color.BLACK)
		Leve.constant(lbl, "outline_size", 6)
		lbl.visible = false
		hud_root.add_child(lbl)
		status_labels.append(lbl)
	

	label_combo = Label.new()
	label_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label_combo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(label_combo, "font_size", 30)
	Leve.color(label_combo, "font_color", Color(1.0, 0.92, 0.30, 1.0))
	Leve.color(label_combo, "font_outline_color", Color.BLACK)
	Leve.constant(label_combo, "outline_size", 6)
	label_combo.visible = false
	hud_root.add_child(label_combo)
	if _anuncio == null:
		_anuncio = ComboAnuncio.criar(self, "deserto")

	_criar_blocos_municao(card_municao)


## Placar compacto (scripts/placar.gd) no lugar dos cartões altos.
func _instalar_placar() -> void:
	var velhos: Array = [label_recarga]
	for nome in ["TopBar", "TopGlow", "TopLine", "CardTempo", "CardScore", "CardModo", "CardMunicao", "CardTiros", "CardAcertos"]:
		var n := hud_root.get_node_or_null(nome)
		if n != null:
			velhos.append(n)
	Placar.instalar(self, hud_root, velhos, _dados_placar, hud_layer.layer)


func _dados_placar() -> Dictionary:
	var sol: bool = modo_atual == MODO_SOL
	return {
		"tempo": tempo_restante, "pontos": pontuacao_total,
		"municao": balas_no_cartucho, "municao_max": capacidade_cartucho,
		"recarregando": recarregando,
		"recarga": 1.0 - reload_tempo_restante / maxf(tempo_recarga_seg, 0.01),
		"acertos": total_acertos, "tiros": total_tiros,
		"extra_titulo": "MODO", "extra": "SOL" if sol else "LUA",
		"extra_cor": Color(1.0, 0.80, 0.30) if sol else Color(0.75, 0.88, 1.0),
		"cor": Color(1.0, 0.70, 0.22) if sol else Color(0.62, 0.80, 1.0),
	}


func _criar_card_hud(titulo: String) -> Panel:
	var card := Panel.new()

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.025, 0.018, 0.012, 0.90)
	estilo.border_width_left = 4
	estilo.border_width_top = 4
	estilo.border_width_right = 4
	estilo.border_width_bottom = 4
	estilo.border_color = COR_SOL
	estilo.corner_radius_top_left = 34
	estilo.corner_radius_top_right = 34
	estilo.corner_radius_bottom_left = 34
	estilo.corner_radius_bottom_right = 34
	estilo.shadow_color = Color(COR_SOL.r, COR_SOL.g, COR_SOL.b, 0.55)
	estilo.shadow_size = 30
	estilo.shadow_offset = Vector2.ZERO

	Leve.stylebox(card, "panel", estilo)

	var lbl_titulo := Label.new()
	lbl_titulo.name = "Titulo"
	lbl_titulo.text = titulo.to_upper()
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(lbl_titulo)

	_fonte_titulo(lbl_titulo, 20, Color(1.0, 0.88, 0.30, 1.0))

	return card


func _criar_valor_card(font_size: int, cor: Color) -> Label:
	var lbl := Label.new()
	lbl.name = "Valor"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fonte_valor(lbl, font_size, cor)
	return lbl


func _criar_blocos_municao(card: Control) -> void:
	municao_blocos.clear()

	for i in range(capacidade_cartucho):
		var bloco: ColorRect = ColorRect.new()
		bloco.name = "BlocoMunicao_%02d" % i
		bloco.color = Color(0.16, 0.18, 0.22, 0.42)
		card.add_child(bloco)
		municao_blocos.append(bloco)


func _configurar_overlay() -> void:
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 90
	add_child(overlay_layer)

	overlay_root = Control.new()
	overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(overlay_root)

	crosshair_overlay = Control.new()
	crosshair_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	crosshair_overlay.z_index = 999
	overlay_root.add_child(crosshair_overlay)
	crosshair_overlay.draw.connect(_desenhar_mira)


func _configurar_fx_frontal() -> void:
	fx_front_layer = CanvasLayer.new()
	fx_front_layer.layer = 95
	add_child(fx_front_layer)

	fx_front_overlay = Control.new()
	fx_front_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_front_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_front_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	fx_front_layer.add_child(fx_front_overlay)

	fx_front_overlay.draw.connect(_desenhar_fx_frontais)

	# "+100" saltando do brasão acertado
	_pontos = PontosVoando.new()
	_pontos.fonte = fonte_luckiest
	fx_front_layer.add_child(_pontos)


func _desenhar_mira() -> void:
	if crosshair_overlay == null:
		return

	var pulso: float = 1.0 + sin(alvo_anim_t * 6.0) * 0.08
	var r1: float = 20.0 * pulso
	var r2: float = 9.0 * pulso

	var cor_base: Color = COR_SOL if modo_atual == MODO_SOL else COR_LUA
	var cor_reload: Color = Color(0.22, 0.92, 1.0, 1.0)
	var cor_vazio: Color = Color(1.0, 0.18, 0.16, 1.0)

	var cor_ext: Color = cor_base
	var cor_int: Color = Color(1.0, 1.0, 1.0, 0.85)

	if recarregando:
		var pulso_reload: float = 0.80 + (sin(aviso_recarga_t * 12.0) * 0.5 + 0.5) * 0.20
		cor_ext = Color(cor_reload.r, cor_reload.g, cor_reload.b, pulso_reload)
	elif balas_no_cartucho <= 0:
		var pulso_vazio: float = 0.72 + (sin(aviso_recarga_t * 14.0) * 0.5 + 0.5) * 0.28
		cor_ext = Color(cor_vazio.r, cor_vazio.g, cor_vazio.b, pulso_vazio)
	elif balas_no_cartucho <= 6:
		cor_ext = Color(1.0, 0.68, 0.18, 0.98)

	Pincel.mira_inicio(crosshair_overlay, mira_pos)
	Pincel.mira(crosshair_overlay, mira_pos, r1, r2, cor_ext, cor_int)

	if recarregando:
		var progresso: float = 1.0 - clamp(reload_tempo_restante / max(tempo_recarga_seg, 0.001), 0.0, 1.0)
		Pincel.mira_recarga(crosshair_overlay, mira_pos, progresso)

	elif balas_no_cartucho <= 0:
		var pulso_alerta: float = 0.35 + (sin(aviso_recarga_t * 16.0) * 0.5 + 0.5) * 0.35
		Pincel.anel(crosshair_overlay, mira_pos, 32.0, 4.0, Color(1.0, 0.15, 0.14, pulso_alerta))
	Pincel.mira_fim(crosshair_overlay)


func _configurar_modal_inicio() -> void:
	modal_inicio_bg = ColorRect.new()
	modal_inicio_bg.name = "ModalInicioBG"
	modal_inicio_bg.color = Color(0, 0, 0, 0.78)
	modal_inicio_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.add_child(modal_inicio_bg)

	# GLOW AMARELO EM VOLTA DA IMAGEM
	var glow_img := ColorRect.new()
	glow_img.name = "GlowImagemInicio"
	glow_img.color = Color(1.0, 0.74, 0.18, 0.22)
	glow_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.add_child(glow_img)

	# MOLDE / BORDA AMARELA
	var borda_img := ColorRect.new()
	borda_img.name = "BordaImagemInicio"
	borda_img.color = Color(1.0, 0.84, 0.10, 1.0)
	borda_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.add_child(borda_img)

	# FUNDO ESCURO ATRÁS DA IMAGEM
	var fundo_img := ColorRect.new()
	fundo_img.name = "FundoImagemInicio"
	fundo_img.color = Color(0.08, 0.045, 0.008, 0.96)
	fundo_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.add_child(fundo_img)

	modal_inicio_panel = TextureRect.new()
	modal_inicio_panel.name = "DesertInfoImagem"
	modal_inicio_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_inicio_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	modal_inicio_panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	modal_inicio_panel.modulate = Color.WHITE
	overlay_root.add_child(modal_inicio_panel)


	modal_inicio_footer = Label.new()
	modal_inicio_footer.name = "TextoAtireComecar"
	modal_inicio_footer.text = "ATIRE PARA COMEÇAR"
	modal_inicio_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_inicio_footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(modal_inicio_footer, "font_size", 46)
	Leve.color(modal_inicio_footer, "font_color", Color(1.0, 0.88, 0.22, 1.0))
	Leve.color(modal_inicio_footer, "font_outline_color", Color.BLACK)
	Leve.constant(modal_inicio_footer, "outline_size", 10)
	modal_inicio_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if fonte_luckiest != null:
		Leve.font(modal_inicio_footer, "font", fonte_luckiest)
	elif ResourceLoader.exists(FONTE_LUCKIEST):
		Leve.font(modal_inicio_footer, "font", load(FONTE_LUCKIEST))

	overlay_root.add_child(modal_inicio_footer)

	# COMO JOGAR grande (scripts/como_jogar.gd) no lugar da imagem antiga:
	# a moldura, a imagem e o rodapé antigos ficam escondidos.
	for n in [glow_img, borda_img, fundo_img]:
		n.visible = false
	modal_como_jogar = ComoJogar.criar("deserto", {
		"sol": ComoJogar.textura_de(sun_modelo),
		"lua": ComoJogar.textura_de(lua_modelo),
	})
	overlay_root.add_child(modal_como_jogar)

	call_deferred("_ajustar_layout_modal_inicio_imagem")


func _ajustar_layout_modal_inicio_imagem() -> void:
	var tela: Vector2 = get_viewport_rect().size

	if modal_inicio_bg != null:
		modal_inicio_bg.position = Vector2.ZERO
		modal_inicio_bg.size = tela
		modal_inicio_bg.visible = false

	if modal_inicio_panel == null:
		return

	var margem_lateral: float = 24.0
	var margem_topo: float = 34.0
	var espaco_texto: float = 96.0
	var distancia_texto: float = 18.0

	var largura_max: float = tela.x - (margem_lateral * 2.0)
	var altura_max: float = tela.y - margem_topo - espaco_texto - distancia_texto

	var largura_img: float = largura_max
	var altura_img: float = altura_max

	if modal_inicio_panel.texture != null:
		var tex_size: Vector2 = modal_inicio_panel.texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			var escala: float = min(largura_max / tex_size.x, altura_max / tex_size.y)
			largura_img = tex_size.x * escala
			altura_img = tex_size.y * escala

	modal_inicio_panel.size = Vector2(largura_img, altura_img)
	modal_inicio_panel.position = Vector2(
		(tela.x - largura_img) * 0.5,
		((tela.y - espaco_texto) - altura_img) * 0.5
	).round()

	modal_inicio_panel.visible = false
	modal_inicio_panel.modulate = Color.WHITE
	modal_inicio_panel.scale = Vector2.ONE

	if modal_inicio_footer != null:
		modal_inicio_footer.size = Vector2(tela.x, 76.0)
		modal_inicio_footer.position = Vector2(
			0.0,
			modal_inicio_panel.position.y + modal_inicio_panel.size.y + distancia_texto
		).round()
		modal_inicio_footer.visible = false
	if modal_como_jogar != null:
		modal_como_jogar.visible = intro_ativa
		
	var neon_margem: float = 22.0
	var borda_espessura: float = 8.0

	var glow_img := overlay_root.get_node_or_null("GlowImagemInicio") as ColorRect
	if glow_img != null:
		glow_img.position = modal_inicio_panel.position - Vector2(neon_margem, neon_margem)
		glow_img.size = modal_inicio_panel.size + Vector2(neon_margem * 2.0, neon_margem * 2.0)

	var borda_img := overlay_root.get_node_or_null("BordaImagemInicio") as ColorRect
	if borda_img != null:
		borda_img.position = modal_inicio_panel.position - Vector2(borda_espessura, borda_espessura)
		borda_img.size = modal_inicio_panel.size + Vector2(borda_espessura * 2.0, borda_espessura * 2.0)

	var fundo_img := overlay_root.get_node_or_null("FundoImagemInicio") as ColorRect
	if fundo_img != null:
		fundo_img.position = modal_inicio_panel.position - Vector2(2.0, 2.0)
		fundo_img.size = modal_inicio_panel.size + Vector2(4.0, 4.0)


func _configurar_countdown() -> void:
	countdown_label = Label.new()
	countdown_label.visible = false
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(countdown_label, "font_size", 138)
	Leve.color(countdown_label, "font_color", Color(1.0, 0.92, 0.26, 1.0))
	Leve.color(countdown_label, "font_outline_color", Color.BLACK)
	Leve.constant(countdown_label, "outline_size", 14)
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if fonte_luckiest != null:
		Leve.font(countdown_label, "font", fonte_luckiest)

	overlay_root.add_child(countdown_label)
	


func _criar_preview_do_modelo(modelo: Area2D) -> Area2D:
	if modelo == null:
		return null

	var area: Area2D = _copiar_modelo(modelo)
	if area == null:
		return null

	area.visible = true
	area.monitoring = false
	area.monitorable = false
	area.input_pickable = false
	area.process_mode = Node.PROCESS_MODE_INHERIT
	area.z_index = 200

	for filho in area.get_children():
		if filho is CollisionShape2D:
			(filho as CollisionShape2D).disabled = true

	var anim: AnimatedSprite2D = _obter_animado(area)
	if anim != null and anim.sprite_frames != null:
		var nome_anim: StringName = anim.sprite_frames.get_animation_names()[0]
		if anim.sprite_frames.has_animation("idle"):
			nome_anim = &"idle"
		anim.play(nome_anim)
		anim.frame = 0
		anim.stop()

	return area


func _configurar_modal_fim() -> void:
	fim_layer = CanvasLayer.new()
	fim_layer.layer = 100
	add_child(fim_layer)

	fim_root = Control.new()
	fim_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	fim_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fim_root.visible = false
	fim_layer.add_child(fim_root)

	fim_bg = ColorRect.new()
	fim_bg.color = Color(0.0, 0.0, 0.0, 0.72)
	fim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	fim_root.add_child(fim_bg)

	fim_panel = Panel.new()
	Leve.stylebox(fim_panel, "panel", _estilo_card_deserto())
	fim_root.add_child(fim_panel)

	# era: var topo: ColorRect = ColorRect.new() / topo.color = ...
	var topo: Panel = Panel.new()
	topo.name = "FimTopo"
	var topo_estilo := StyleBoxFlat.new()
	topo_estilo.bg_color                  = Color(0.06, 0.04, 0.01, 1.0)
	topo_estilo.corner_radius_top_left    = 56
	topo_estilo.corner_radius_top_right   = 56
	topo_estilo.corner_radius_bottom_left = 0
	topo_estilo.corner_radius_bottom_right = 0
	Leve.stylebox(topo, "panel", topo_estilo)
	fim_panel.add_child(topo)
	

	var linha: ColorRect = ColorRect.new()
	linha.name  = "FimLinha"
	linha.color = COR_SOL
	fim_panel.add_child(linha)

	fim_titulo = Label.new()
	fim_titulo.text = "FIM DE JOGO"
	fim_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fim_titulo.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(fim_titulo, "font_size", 54)
	Leve.color(fim_titulo, "font_color", Color(1.0, 0.86, 0.24, 1.0))
	Leve.color(fim_titulo, "font_outline_color", Color.BLACK)
	Leve.constant(fim_titulo, "outline_size", 8)
	fim_root.add_child(fim_titulo)

	fim_texto = Label.new()
	fim_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fim_texto.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	fim_texto.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	Leve.font_size(fim_texto, "font_size", 28)
	Leve.color(fim_texto, "font_color", Color(0.96, 0.90, 0.78, 1.0))
	Leve.color(fim_texto, "font_outline_color", Color.BLACK)
	Leve.constant(fim_texto, "outline_size", 5)
	fim_root.add_child(fim_texto)

	fim_footer = Label.new()
	fim_footer.text = Maquina.texto_jogar_novamente()
	fim_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fim_footer.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(fim_footer, "font_size", 26)
	Leve.color(fim_footer, "font_color", Color(1.0, 0.90, 0.30, 1.0))
	Leve.color(fim_footer, "font_outline_color", Color.BLACK)
	Leve.constant(fim_footer, "outline_size", 6)
	fim_root.add_child(fim_footer)

	fim_contagem_label = Label.new()
	fim_contagem_label.text = "VOLTANDO AO INÍCIO EM 21"
	fim_contagem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fim_contagem_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(fim_contagem_label, "font_size", 28)
	Leve.color(fim_contagem_label, "font_color", Color(1.0, 0.66, 0.16, 1.0))
	Leve.color(fim_contagem_label, "font_outline_color", Color.BLACK)
	Leve.constant(fim_contagem_label, "outline_size", 6)
	fim_root.add_child(fim_contagem_label)

	_criar_nome_ranking()


func _abrir_modal_nome_ranking(pontos: int, cenario: String, precisao: int) -> void:
	ranking_pontos_pendentes = pontos
	ranking_cenario_pendente = cenario
	ranking_precisao_pendente = clamp(precisao, 0, 100)
	ranking_nome_ativo = true
	ranking_ja_salvo = false
	ranking_nome_digitado = ""

	if overlay_layer != null:
		overlay_layer.layer = 220

	if crosshair_overlay != null:
		crosshair_overlay.visible = true
		crosshair_overlay.queue_redraw()

	if nome_ranking != null:
		nome_ranking.abrir(COR_SOL if modo_atual == MODO_SOL else COR_LUA, pontos, ranking_precisao_pendente)


func _confirmar_nome_ranking(usar_anonimo: bool = false) -> void:
	if ranking_ja_salvo:
		return

	# confirmado por fora da tela de nome (ex.: START): vale o que já foi digitado
	if nome_ranking != null and nome_ranking.ativo:
		ranking_nome_digitado = nome_ranking.nome
		nome_ranking.fechar()

	var nome_final: String = "ANONIMO"

	if not usar_anonimo:
		var digitado: String = ranking_nome_digitado.strip_edges().to_upper()
		if digitado != "":
			nome_final = digitado

	RankingManager.call(
		"adicionar_resultado",
		nome_final,
		ranking_pontos_pendentes,
		ranking_cenario_pendente,
		ranking_precisao_pendente
	)

	ranking_ja_salvo = true
	ranking_nome_ativo = false
	ranking_nome_tempo = 0.0

	if nome_ranking != null and nome_ranking.ativo:
		nome_ranking.fechar()

	fim_tempo_voltar = Maquina.tempo_volta_menu()

	if fim_titulo != null:
		fim_titulo.text = "RECORDE SALVO!"
		# ← adicionar as 4 linhas abaixo
		var tw_titulo := create_tween()
		tw_titulo.tween_interval(3.5)
		tw_titulo.tween_callback(func() -> void:
			if fim_titulo != null and is_instance_valid(fim_titulo):
				fim_titulo.text = "FIM DE JOGO"
				)

	if fim_texto != null:
		fim_texto.text = fim_texto.text.replace("\n\n🏆 NOVO RECORDE! ESCOLHA SEU NOME.", "")
		fim_texto.text += "\n\n🏆 RECORDE SALVO COMO: %s\nACERTO: %d%%" % [
			nome_final,
			ranking_precisao_pendente
		]

	if fim_footer != null:
		fim_footer.text = Maquina.texto_jogar_novamente()


func _ajustar_layout() -> void:
	var tela: Vector2 = get_viewport_rect().size

	if hud_root == null:
		return

	hud_root.size = tela

	if overlay_root != null:
		overlay_root.size = tela

	if fx_front_overlay != null:
		fx_front_overlay.size = tela

	var top_bar := hud_root.get_node_or_null("TopBar") as ColorRect
	var glow := hud_root.get_node_or_null("TopGlow") as ColorRect
	var line := hud_root.get_node_or_null("TopLine") as ColorRect

	if top_bar != null:
		top_bar.position = Vector2.ZERO
		top_bar.size = Vector2(tela.x, 220)

	if glow != null:
		glow.visible = false
		glow.position = Vector2(-9999, -9999)
		glow.size = Vector2.ZERO

	if line != null:
		line.visible = false
		line.position = Vector2(-9999, -9999)
		line.size = Vector2.ZERO

	var card_tempo := hud_root.get_node_or_null("CardTempo") as Panel
	var card_score := hud_root.get_node_or_null("CardScore") as Panel
	var card_modo := hud_root.get_node_or_null("CardModo") as Panel
	var card_municao := hud_root.get_node_or_null("CardMunicao") as Panel
	var card_tiros := hud_root.get_node_or_null("CardTiros") as Panel
	var card_acertos := hud_root.get_node_or_null("CardAcertos") as Panel

	if card_tempo != null:
		card_tempo.position = Vector2(20, 18)
		card_tempo.size = Vector2(220, 188)
		_posicionar_card(card_tempo)

	if card_score != null:
		card_score.position = Vector2(255, 18)
		card_score.size = Vector2(350, 188)
		_posicionar_card(card_score)

	if card_municao != null:
		card_municao.position = Vector2(tela.x - 380.0, 18)
		card_municao.size = Vector2(220, 188)
		_posicionar_card(card_municao)

	if card_modo != null:
		card_modo.position = Vector2(tela.x - 148.0, 18.0)
		card_modo.size = Vector2(138.0, 58.0)
		_posicionar_card(card_modo)

	if card_acertos != null:
		card_acertos.position = Vector2(tela.x - 148.0, 84.0)
		card_acertos.size = Vector2(138.0, 58.0)
		_posicionar_card(card_acertos)

	if card_tiros != null:
		card_tiros.position = Vector2(tela.x - 148.0, 150.0)
		card_tiros.size = Vector2(138.0, 58.0)
		_posicionar_card(card_tiros)

	if label_recarga != null and card_municao != null:
		label_recarga.position = Vector2(card_municao.position.x, card_municao.position.y + 156.0)
		label_recarga.size = Vector2(card_municao.size.x, 20.0)

	for i in range(status_labels.size()):
		var lbl := status_labels[i]
		if lbl != null:
			lbl.position = Vector2((tela.x - 700) * 0.5, tela.y - 140 - (i * 34))
			lbl.size = Vector2(700, 34)

	if label_combo != null:
		label_combo.position = Vector2(30.0, tela.y - 62.0)
		label_combo.size = Vector2(760.0, 38.0)

	if modal_inicio_bg != null:
		modal_inicio_bg.position = Vector2.ZERO
		modal_inicio_bg.size = tela

	if modal_inicio_panel != null:
		var panel_glow_top := modal_inicio_panel.get_node_or_null("PanelGlowTop") as ColorRect
		if panel_glow_top != null:
			panel_glow_top.position = Vector2(0.0, 0.0)
			panel_glow_top.size = Vector2(modal_inicio_panel.size.x, 18.0)

		var panel_line := modal_inicio_panel.get_node_or_null("PanelLine") as ColorRect
		if panel_line != null:
			panel_line.visible = false
			panel_line.position = Vector2(-9999, -9999)
			panel_line.size = Vector2.ZERO

		var panel_header := modal_inicio_panel.get_node_or_null("PanelHeader") as ColorRect
		if panel_header != null:
			panel_header.position = Vector2(0.0, 0.0)
			panel_header.size = Vector2(modal_inicio_panel.size.x, 170.0)

	if countdown_label != null:
		countdown_label.position = Vector2.ZERO
		countdown_label.size = tela
		countdown_label.pivot_offset = Vector2.ZERO
		countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if fim_root != null:
		fim_root.size = tela

	if fim_bg != null:
		fim_bg.position = Vector2.ZERO
		fim_bg.size = tela

	if fim_panel != null:
		var painel_w: float = min(1040.0, tela.x - 50.0)
		var painel_h: float = min(860.0, tela.y - 80.0)
		fim_panel.position = Vector2((tela.x - painel_w) * 0.5, (tela.y - painel_h) * 0.5).round()
		fim_panel.size = Vector2(painel_w, painel_h)

		var topo := fim_panel.get_node_or_null("FimTopo") as Panel
		if topo != null:
			topo.position = Vector2.ZERO
			topo.size = Vector2(fim_panel.size.x, 130.0)

		var linha := fim_panel.get_node_or_null("FimLinha") as ColorRect
		if linha != null:
			linha.position = Vector2(0.0, 130.0)
			linha.size = Vector2(fim_panel.size.x, 4.0)

	if fim_titulo != null and fim_panel != null:
		fim_titulo.position = fim_panel.position + Vector2(30.0, 28.0)
		fim_titulo.size = Vector2(fim_panel.size.x - 60.0, 76.0)

	if fim_texto != null and fim_panel != null:
		fim_texto.position = fim_panel.position + Vector2(60.0, 155.0)
		fim_texto.size = Vector2(fim_panel.size.x - 120.0, fim_panel.size.y - 310.0)

	if fim_contagem_label != null and fim_panel != null:
		fim_contagem_label.position = fim_panel.position + Vector2(45.0, fim_panel.size.y - 125.0)
		fim_contagem_label.size = Vector2(fim_panel.size.x - 90.0, 46.0)

	if fim_footer != null and fim_panel != null:
		fim_footer.position = fim_panel.position + Vector2(45.0, fim_panel.size.y - 92.0)
		fim_footer.size = Vector2(fim_panel.size.x - 90.0, 58.0)

	_hud_estilo_modo = ""   # o layout mexe nas fontes dos cartões: reaplica o estilo do modo
	_atualizar_barra_municao()
	_ajustar_layout_modal_inicio_imagem()


func _posicionar_card(card: Control) -> void:
	if card == null:
		return

	var titulo := card.get_node_or_null("Titulo") as Label
	var valor := card.get_node_or_null("Valor") as Label

	var compacto: bool = card.name in ["CardModo", "CardTiros", "CardAcertos"]

	if compacto:
		if titulo != null:
			titulo.position = Vector2(0.0, 4.0)
			titulo.size = Vector2(card.size.x, 18.0)
			_fonte_titulo(titulo, 14, Color(1.0, 0.90, 0.35, 1.0))

		if valor != null:
			valor.position = Vector2(0.0, 22.0)
			valor.size = Vector2(card.size.x, 30.0)

			if card.name == "CardModo":
				_fonte_valor(valor, 19, Color.WHITE)
			else:
				_fonte_valor(valor, 22, Color.WHITE)

		return

	if titulo != null:
		titulo.position = Vector2(0.0, 10.0)
		titulo.size = Vector2(card.size.x, 26.0)

	if valor != null:
		valor.position = Vector2(0.0, 42.0)
		valor.size = Vector2(card.size.x, card.size.y - 50.0)


func _atualizar_hud() -> void:
	if label_score != null:
		label_score.text = str(pontuacao_total)

		if pontuacao_total > 0:
			label_score.modulate = Color(0.42, 1.0, 0.52, 1.0)
		elif pontuacao_total < 0:
			label_score.modulate = Color(1.0, 0.28, 0.28, 1.0)
		else:
			label_score.modulate = Color(1.0, 0.93, 0.25, 1.0)

	if label_timer != null:
		@warning_ignore("shadowed_global_identifier", "integer_division")
		var min: int = int(tempo_restante) / 60
		var sec: int = int(tempo_restante) % 60
		label_timer.text = "%02d:%02d" % [min, sec]

		# CORES DO TEMPO
		if tempo_restante <= 10.0:
			label_timer.modulate = Color(1.0, 0.08, 0.06, 1.0) # vermelho crítico
			if _vivo != null and partida_iniciada:
				_vivo.evento("tempo_final")
		elif tempo_restante <= 30.0:
			label_timer.modulate = Color(1.0, 0.58, 0.10, 1.0) # laranja alerta
		else:
			label_timer.modulate = Color(0.82, 0.94, 1.0, 1.0) # normal azul/branco

		var card_tempo := hud_root.get_node_or_null("CardTempo") as Panel
		if card_tempo != null:
			var estilo_tempo := card_tempo.get_theme_stylebox("panel") as StyleBoxFlat
			if estilo_tempo != null:
				if tempo_restante <= 10.0:
					Leve.prop(estilo_tempo, "bg_color", Color(0.30, 0.04, 0.04, 0.96))
					Leve.prop(estilo_tempo, "border_color", Color(1.0, 0.08, 0.06, 1.0))
					Leve.prop(estilo_tempo, "shadow_color", Color(1.0, 0.08, 0.06, 0.65))
				elif tempo_restante <= 30.0:
					Leve.prop(estilo_tempo, "bg_color", Color(0.28, 0.13, 0.03, 0.96))
					Leve.prop(estilo_tempo, "border_color", Color(1.0, 0.58, 0.10, 1.0))
					Leve.prop(estilo_tempo, "shadow_color", Color(1.0, 0.58, 0.10, 0.58))

	if label_modo != null:
		if modo_atual == MODO_SOL:
			label_modo.text = "SOL"
			label_modo.modulate = COR_SOL
		else:
			label_modo.text = "LUA"
			label_modo.modulate = COR_LUA

	if label_tiros != null:
		label_tiros.text = str(total_tiros)

	if label_acertos != null:
		label_acertos.text = str(total_acertos)

	if label_municao_estado != null:
		if recarregando:
			label_municao_estado.text = "RECARREGANDO"
			label_municao_estado.modulate = Color(0.30, 0.92, 1.0, 1.0)
		elif balas_no_cartucho <= 0:
			label_municao_estado.text = "RECARREGUE!"
			label_municao_estado.modulate = Color(1.0, 0.24, 0.22, 1.0)
		elif balas_no_cartucho <= 6:
			label_municao_estado.text = "MUNIÇÃO BAIXA"
			label_municao_estado.modulate = Color(1.0, 0.68, 0.18, 1.0)
		else:
			label_municao_estado.text = "CARREGADA"
			label_municao_estado.modulate = Color(0.82, 1.0, 0.90, 1.0)

	if label_recarga != null:
		if recarregando:
			label_recarga.text = "AGUARDE %.1fs" % reload_tempo_restante
			label_recarga.modulate = Color(0.78, 0.96, 1.0, 1.0)
		elif balas_no_cartucho <= 0 and partida_iniciada:
			var pulso: float = 0.68 + (sin(aviso_recarga_t * 12.0) * 0.5 + 0.5) * 0.32
			label_recarga.text = "BOTÃO DIREITO DO MOUSE"
			label_recarga.modulate = Color(1.0, 0.72, 0.72, pulso)
		else:
			label_recarga.text = "BOTÃO DIREITO RECARREGA"
			label_recarga.modulate = Color(0.76, 0.88, 1.0, 0.95)

	if label_combo != null:
		label_combo.visible = true

		if combo_qtd > 0 and combo_tipo != "":
			label_combo.text = "SEQUÊNCIA: %s x%d    |    MELHOR: x%d" % [
				combo_tipo.to_upper(),
				combo_qtd,
				melhor_combo
			]
			label_combo.modulate = Color(1.0, 0.94, 0.36, 1.0)
		else:
			label_combo.text = "SEQUÊNCIA: --- x0    |    MELHOR: x%d" % melhor_combo
			label_combo.modulate = Color(0.88, 0.92, 1.0, 0.92)

	_atualizar_barra_municao()
	_atualizar_estilo_hud_por_modo()


func _sortear_pontos_acerto() -> int:
	var tabela: Array[int] = [20, 50, 80, 100]
	return tabela[randi() % tabela.size()]


func _texto_resultado(valor: int) -> String:
	if valor > 0:
		return "+%d" % valor
	return "-%d" % abs(valor)


func _atualizar_barra_municao() -> void:
	if municao_blocos.is_empty():
		return

	var card_municao: Panel = hud_root.find_child("CardMunicao", true, false) as Panel
	if card_municao == null:
		return
	if not recarregando and balas_no_cartucho == _barra_balas and card_municao.size == _barra_tam:
		return
	_barra_balas = -1 if recarregando else balas_no_cartucho
	_barra_tam = card_municao.size

	var margem_x: float = 14.0
	var margem_topo: float = 48.0
	var largura_util: float = card_municao.size.x - (margem_x * 2.0)
	var espacamento: float = 3.0
	var total_blocos: int = municao_blocos.size()
	var largura_bloco: float = (largura_util - (espacamento * float(total_blocos - 1))) / float(total_blocos)
	var altura_bloco: float = 34.0

	for i in range(total_blocos):
		var bloco: ColorRect = municao_blocos[i]
		var ativo: bool = i < balas_no_cartucho

		bloco.position = Vector2(
			margem_x + (largura_bloco + espacamento) * float(i),
			margem_topo
		).round()
		bloco.size = Vector2(max(largura_bloco, 2.0), altura_bloco)

		if recarregando:
			var pulso: float = 0.58 + (sin(aviso_recarga_t * 10.0 + float(i) * 0.18) * 0.5 + 0.5) * 0.42
			bloco.color = Color(0.22, 0.92, 1.0, pulso)
		elif not ativo:
			bloco.color = Color(0.16, 0.18, 0.22, 0.42)
		else:
			var t: float = float(i) / max(float(total_blocos - 1), 1.0)
			if balas_no_cartucho <= 6:
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


func _atualizar_modal_inicio() -> void:
	# o aviso é o COMO JOGAR (scripts/como_jogar.gd); a imagem antiga saiu
	if modal_como_jogar != null and modal_como_jogar.visible != intro_ativa:
		modal_como_jogar.visible = intro_ativa


func _atualizar_modal_fim() -> void:
	if not fim_ativo:
		return

	if fim_panel != null:
		fim_panel.scale = Vector2.ONE
		fim_panel.pivot_offset = Vector2.ZERO
		fim_panel.modulate.a = 1.0

	if fim_footer != null:
		fim_footer.scale = Vector2.ONE
		fim_footer.pivot_offset = Vector2.ZERO
		fim_footer.modulate.a = 1.0


func _pos_tela_para_canvas(pos_tela: Vector2) -> Vector2:
	var xform: Transform2D = get_viewport().get_canvas_transform()
	return xform.affine_inverse() * pos_tela


func _processar_tiro(pos_global: Vector2) -> void:
	if not jogo_ativo:
		return

	if fim_ativo:
		return

	if intro_ativa:
		_iniciar_countdown()
		return

	if countdown_ativo:
		return

	if recarregando:
		return

	if balas_no_cartucho <= 0:
		_tocar_som(som_bullet_no)
		return

	balas_no_cartucho -= 1
	total_tiros += 1
	_tocar_som(_som_do_tiro())
	# raio de sol de dia, raio de luar de noite (da arma até a mira)
	Trajetoria.disparar(self, get_viewport().get_canvas_transform() * pos_global, "sol" if modo_atual == MODO_SOL else "lua")

	var idx: int = _achar_alvo_no_ponto(pos_global)
	if idx >= 0:
		_resolver_acerto(idx)
	else:
		total_erros += 1
		_quebrar_combo()
		if _vivo != null:
			_vivo.evento("erro", MiraGlobal.pos)
		# cada lugar responde: o cristal trinca (e quebra), o ouro toca,
		# pedra lasca, areia levanta; marca de bala só na pedra e na areia
		var mat: String = _vivo.impacto(pos_global) if _vivo != null else "areia"
		if (mat == "pedra" or mat == "areia") and _vivo != null and _vivo.no_chao(pos_global):
			_furar_fundo(pos_global, mat)
		_set_status("ERRO!", Color(1.0, 0.28, 0.22, 1.0), 1.2)


func _iniciar_countdown() -> void:
	if target_root != null:
		target_root.visible = false
	
	if countdown_ativo or not intro_ativa:
		return

	countdown_ativo = true
	intro_ativa = false
	
	if modal_inicio_subtitulo != null:
		modal_inicio_subtitulo.visible = false

	if modal_card_correto != null:
		modal_card_correto.visible = false
	if modal_card_errado != null:
		modal_card_errado.visible = false
	if modal_card_vazio != null:
		modal_card_vazio.visible = false

	if modal_inicio_bg != null:
		modal_inicio_bg.visible = false
	if modal_inicio_panel != null:
		modal_inicio_panel.visible = false
	if modal_como_jogar != null:
		modal_como_jogar.visible = false
	var glow_img := overlay_root.get_node_or_null("GlowImagemInicio") as ColorRect
	if glow_img != null:
		glow_img.visible = false

	var borda_img := overlay_root.get_node_or_null("BordaImagemInicio") as ColorRect
	if borda_img != null:
		borda_img.visible = false

	var fundo_img := overlay_root.get_node_or_null("FundoImagemInicio") as ColorRect
	if fundo_img != null:
		fundo_img.visible = false
	if modal_inicio_titulo != null:
		modal_inicio_titulo.visible = false
	if modal_inicio_texto != null:
		modal_inicio_texto.visible = false
	if modal_inicio_footer != null:
		modal_inicio_footer.visible = false
	if preview_sol != null and is_instance_valid(preview_sol):
		preview_sol.visible = false
	if preview_lua != null and is_instance_valid(preview_lua):
		preview_lua.visible = false

	call_deferred("_rodar_countdown_async")


func _rodar_countdown_async() -> void:
	await _mostrar_numero_countdown("3", 1.0)
	await _mostrar_numero_countdown("2", 1.0)
	await _mostrar_numero_countdown("1", 1.0)
	await _mostrar_numero_countdown("COMEÇOU!", 0.70)

	if countdown_label != null:
		countdown_label.visible = false

	partida_iniciada = true
	countdown_ativo = false
	intro_ativa = false
	fim_ativo = false
	jogo_ativo = true

	tempo_restante = tempo_partida
	tempo_fase = 0.0
	tempo_total_partida = 0.0
	nivel_dificuldade = 1.0

	if target_root != null:
		target_root.visible = true
		target_root.process_mode = Node.PROCESS_MODE_INHERIT
		target_root.z_index = 50

	_limpar_alvos()

	await get_tree().process_frame

	spawn_timer_continuo = 0.0
	_spawn_alvo_forcado(modo_atual)
	_spawn_alvo()
	_spawn_alvo()
	_set_status("COMEÇOU!", Color(0.56, 1.0, 0.60, 1.0))
	_atualizar_hud()


func _mostrar_numero_countdown(texto: String, duracao: float) -> void:
	if countdown_label == null:
		await get_tree().create_timer(duracao).timeout
		return

	var tela: Vector2 = get_viewport_rect().size

	countdown_label.position = Vector2.ZERO
	countdown_label.size = tela
	countdown_label.pivot_offset = tela * 0.5
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	countdown_label.visible = true
	countdown_label.text = texto
	countdown_label.modulate = Color(1, 1, 1, 0.0)

	if texto == "COMEÇOU!":
		Leve.font_size(countdown_label, "font_size", 82)
		countdown_label.scale = Vector2.ONE * 0.88
	else:
		Leve.font_size(countdown_label, "font_size", 138)
		countdown_label.scale = Vector2.ONE * 0.72

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(countdown_label, "modulate:a", 1.0, 0.12)
	tw.tween_property(countdown_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(countdown_label, "modulate:a", 0.0, 0.18).set_delay(max(duracao - 0.22, 0.10))

	await get_tree().create_timer(duracao).timeout


func _obter_collision_shape_do_alvo(area: Node) -> CollisionShape2D:
	if area == null:
		return null

	for filho in area.get_children():
		if filho is CollisionShape2D:
			return filho as CollisionShape2D

	for filho in area.get_children():
		for neto in filho.get_children():
			if neto is CollisionShape2D:
				return neto as CollisionShape2D

	return null


func _ponto_esta_sobre_colisao_do_alvo(area: Area2D, pos_global: Vector2) -> bool:
	if area == null or not is_instance_valid(area):
		return false

	var collision: CollisionShape2D = _obter_collision_shape_do_alvo(area)
	if collision == null or collision.shape == null:
		return false

	var ponto_local_shape: Vector2 = collision.to_local(pos_global)
	var shape: Shape2D = collision.shape

	if shape is CircleShape2D:
		var s := shape as CircleShape2D
		return ponto_local_shape.length() <= s.radius

	if shape is RectangleShape2D:
		var s := shape as RectangleShape2D
		var half := s.size * 0.5
		return abs(ponto_local_shape.x) <= half.x and abs(ponto_local_shape.y) <= half.y

	if shape is CapsuleShape2D:
		var s := shape as CapsuleShape2D
		var r: float = s.radius
		var h: float = max(s.height, r * 2.0)
		var half_body: float = max((h - r * 2.0) * 0.5, 0.0)

		if abs(ponto_local_shape.x) <= r and abs(ponto_local_shape.y) <= half_body:
			return true

		var topo := Vector2(0.0, -half_body)
		var base := Vector2(0.0, half_body)

		if ponto_local_shape.distance_to(topo) <= r:
			return true
		if ponto_local_shape.distance_to(base) <= r:
			return true

		return false

	return false


## O brasão no ponto do tiro: o mais perto que esteja ali e que não esteja
## escondido atrás de alguma coisa do fundo (cristal, obelisco, coluna).
func _achar_alvo_no_ponto(pos_global: Vector2) -> int:
	var melhor: int = -1
	var melhor_z: float = INF
	var inv_fundo: float = _vivo.inv_z_na_tela(pos_global) if _vivo != null else 0.0
	for i in range(alvos_ativos.size() - 1, -1, -1):
		var alvo: TargetData = alvos_ativos[i]
		if alvo == null or alvo.node == null or not is_instance_valid(alvo.node):
			continue
		if not alvo.node.visible or alvo.alfa < 0.5:
			continue
		if alvo.z >= melhor_z:
			continue
		# atrás de algo do fundo que está mais perto: o tiro pega a coisa
		if inv_fundo > 1.0 / alvo.z + 0.03:
			continue

		var anim: AnimatedSprite2D = _obter_animado(alvo.node)
		if anim == null:
			continue

		var tex: Texture2D = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
		if tex == null:
			continue

		var centro: Vector2 = anim.global_position
		var escala: Vector2 = anim.global_scale

		var largura: float = tex.get_width() * abs(escala.x)
		var altura: float = tex.get_height() * abs(escala.y)

		# margem extra para o alvo contar em toda a parte visível, inclusive embaixo
		largura *= 0.92
		altura *= 0.98

		var rect := Rect2(
			centro.x - largura * 0.5,
			centro.y - altura * 0.5,
			largura,
			altura
		)

		if rect.has_point(pos_global):
			melhor = i
			melhor_z = alvo.z

	return melhor


func _resolver_acerto(indice: int) -> void:
	if indice < 0 or indice >= alvos_ativos.size():
		return

	var alvo: TargetData = alvos_ativos[indice]
	if alvo == null or alvo.node == null or not is_instance_valid(alvo.node):
		return

	if alvo.tipo == MODO_SOL and som_hit_sun != null:
		_tocar_som(som_hit_sun)
	elif alvo.tipo == MODO_LUA and som_hit_moon != null:
		_tocar_som(som_hit_moon)

	alvos_ativos.remove_at(indice)

	if alvo.tipo == modo_atual:
		# acertar lá longe (pequeno, no meio da névoa) vale mais
		var de_longe: bool = alvo.z >= Z_DE_LONGE
		var bonus_longe: int = int(round(alvo.valor_correto * BONUS_DE_LONGE / 10.0)) * 10 if de_longe else 0
		pontuacao_total += alvo.valor_correto + bonus_longe
		total_acertos += 1
		_registrar_hit_combo(alvo.tipo)
		if _anuncio != null:
			_anuncio.combo(combo_qtd)
		if _vivo != null:
			_vivo.evento("acerto", Vector2.INF, combo_qtd)

		var bonus_combo: int = 0
		if combo_qtd >= 3:
			bonus_combo = combo_qtd * 5
			pontuacao_total += bonus_combo

		# acerto do sol em ouro, da lua em prata (como os pontos)
		var cor_ok := Color(0.86, 0.92, 1.0, 1.0) if alvo.tipo == MODO_LUA else Color(1.0, 0.86, 0.36, 1.0)
		if de_longe:
			_set_status("DE LONGE! +%d" % (alvo.valor_correto + bonus_longe), Color(1.0, 0.86, 0.30, 1.0), 1.55)
		elif bonus_combo > 0:
			_set_status("%s %s   COMBO +%d" % [alvo.tipo.to_upper(), _texto_resultado(alvo.valor_correto), bonus_combo], cor_ok, 1.55)
		else:
			_set_status("%s %s" % [alvo.tipo.to_upper(), _texto_resultado(alvo.valor_correto)], cor_ok, 1.45)
		_mostrar_pontos(alvo.tela, alvo.valor_correto + bonus_longe + bonus_combo, de_longe, alvo.tipo)
		_explodir_alvo_visual(alvo)
		_carregar_cristal()
		return
	else:
		if _vivo != null:
			_vivo.carga = maxf(0.0, _vivo.carga - CARGA_ERRO)
		pontuacao_total -= alvo.penalidade_errado
		total_erros += 1
		_quebrar_combo()
		if _vivo != null:
			_vivo.evento("astro_errado", MiraGlobal.pos)
		_set_status("%s -%d" % [alvo.tipo.to_upper(), alvo.penalidade_errado], Color(1.0, 0.26, 0.22, 1.0), 1.75)
		_mostrar_pontos(alvo.tela, -alvo.penalidade_errado, false)

	_explodir_alvo_visual(alvo)


## Cada acerto certo carrega o cristal (os feixes engrossam, correm e estalam).
## Cheio e inteiro, ele descarrega: raios das pontas dos obeliscos acesos em
## todos os brasões certos da tela, que estouram e dão os pontos.
func _carregar_cristal() -> void:
	if _vivo == null:
		return
	_vivo.carga = minf(1.0, _vivo.carga + CARGA_POR_ACERTO)
	if _vivo.carga < 1.0 or not _vivo.cristal_inteiro():
		return
	var pegos: Array[TargetData] = []
	var pontos_raio: Array = []
	for i in range(alvos_ativos.size() - 1, -1, -1):
		var a: TargetData = alvos_ativos[i]
		if a == null or a.node == null or not is_instance_valid(a.node) or not a.node.visible or a.alfa < 0.5:
			continue
		if a.tipo != modo_atual:
			continue
		alvos_ativos.remove_at(i)
		pegos.append(a)
		pontos_raio.append(a.tela)
	_vivo.disparar_descarga(pontos_raio)
	if _anuncio != null:
		_anuncio.especial("POWER OF RA!")
	if pegos.is_empty():
		_set_status("DESCARGA DO CRISTAL!", Color(1.0, 0.86, 0.36, 1.0), 1.4)
		return
	var soma := 0
	for a in pegos:
		var v: int = a.valor_correto
		soma += v
		_mostrar_pontos(a.tela, v, false, a.tipo)
		_explodir_alvo_visual(a)
	pontuacao_total += soma
	_set_status("DESCARGA DO CRISTAL! +%d" % soma, Color(1.0, 0.86, 0.36, 1.0), 1.9)


func _registrar_hit_combo(tipo: String) -> void:
	if combo_tipo == tipo and combo_timer > 0.0:
		combo_qtd += 1
	else:
		combo_tipo = tipo
		combo_qtd = 1

	combo_timer = JANELA_COMBO

	if combo_qtd > melhor_combo:
		melhor_combo = combo_qtd


func _quebrar_combo() -> void:
	combo_tipo = ""
	combo_qtd = 0
	combo_timer = 0.0
	if _anuncio != null:
		_anuncio.zerar()
	if _vivo != null:
		_vivo.evento("combo_quebrou")


func _atualizar_combo(delta: float) -> void:
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			_quebrar_combo()


func _trocar_modo() -> void:
	modo_atual = MODO_LUA if modo_atual == MODO_SOL else MODO_SOL
	_aplicar_background_modo()
	_set_status("MODO " + modo_atual.to_upper(), COR_SOL if modo_atual == MODO_SOL else COR_LUA)


func _atualizar_alvos(delta: float) -> void:
	if alvos_ativos.is_empty():
		return
	for i in range(alvos_ativos.size() - 1, -1, -1):
		var alvo: TargetData = alvos_ativos[i]
		if alvo == null:
			alvos_ativos.remove_at(i)
			continue
		if alvo.node == null or not is_instance_valid(alvo.node):
			alvos_ativos.remove_at(i)
			continue
		alvo.idade += delta
		if alvo.flash_troca_t > 0.0:
			alvo.flash_troca_t = max(0.0, alvo.flash_troca_t - delta)
		# TROCA DE BRASÃO
		if not alvo.ja_trocou and alvo.tempo_para_trocar > 0.0:
			if alvo.idade >= alvo.tempo_para_trocar:
				_trocar_tipo_alvo(alvo)
		if alvo.idade >= alvo.vida:
			_remover_alvo(i)
			continue
		_profundidade_do_alvo(alvo)
		var entrando: bool = alvo.idade < alvo.entrada
		var saindo: bool = alvo.idade > alvo.vida - SAIDA_TEMPO
		var pos: Vector2 = alvo.pos
		var vel: Vector2 = alvo.vel
		# alto em L: desce reto e, na quina, vira de lado
		if alvo.estilo == "alto_l" and not alvo.l_virou and alvo.idade >= alvo.entrada * 0.8:
			alvo.l_virou = true
			var lado: float = 1.0 if pos.x < _fuga().x else -1.0
			vel = Vector2(lado, randf_range(-0.18, 0.12)).normalized() * alvo.vel_base
		# guinada: de tempos em tempos o alvo muda de rumo de repente
		if not entrando:
			alvo.guinada_t -= delta
			if alvo.guinada_t <= 0.0:
				alvo.guinada_t = randf_range(0.55, 1.3) / sqrt(nivel_dificuldade)
				vel = vel.rotated(deg_to_rad(randf_range(35.0, 85.0)) * (1.0 if randf() < 0.5 else -1.0))
		var raio_col: float = _raio_colisao_alvo(alvo)
		# BORDAS da tela na distância do brasão (no plano Z = 1 a área cresce
		# com z): invertem com pequena guinada pra não cair em loop. Longe, o
		# chão sobe (o brasão não entra na areia). Na entrada e na saída, livre.
		var lim := _limites_no_plano(alvo.z, raio_col)
		if not entrando and not saindo:
			var empurra: float = alvo.z
			if pos.x < lim.position.x:
				pos.x = lim.position.x
				vel.x = abs(vel.x) + randf_range(20.0, 70.0) * empurra
				vel.y += randf_range(-60.0, 60.0)
			if pos.x > lim.end.x:
				pos.x = lim.end.x
				vel.x = -(abs(vel.x) + randf_range(20.0, 70.0) * empurra)
				vel.y += randf_range(-60.0, 60.0)
			if pos.y < lim.position.y:
				pos.y = lim.position.y
				vel.y = abs(vel.y) + randf_range(20.0, 70.0) * empurra
				vel.x += randf_range(-60.0, 60.0)
			if pos.y > lim.end.y:
				pos.y = lim.end.y
				vel.y = -(abs(vel.y) + randf_range(20.0, 70.0) * empurra)
				vel.x += randf_range(-60.0, 60.0)
		# as guinadas das bordas mudam a direção, não a rapidez
		var velmag: float = vel.length()
		var vel_teto: float = alvo.vel_base * (1.35 if entrando else 1.15)
		if velmag > vel_teto:
			vel = vel * (vel_teto / velmag)
			velmag = vel_teto
		# VELOCIDADE MÍNIMA garantida
		if velmag < velocidade_minima_alvo:
			if velmag < 0.01:
				var ang: float = randf_range(0.0, TAU)
				vel = Vector2.RIGHT.rotated(ang) * velocidade_minima_alvo
			else:
				vel = vel.normalized() * velocidade_minima_alvo
		# Detector de "ficou enroscado em um canto"
		var perto_de_canto: bool = not entrando and not saindo and (
			(pos.x <= lim.position.x + 8.0 or pos.x >= lim.end.x - 8.0)
			and
			(pos.y <= lim.position.y + 8.0 or pos.y >= lim.end.y - 8.0)
		)
		if perto_de_canto:
			alvo.tempo_sem_se_mover += delta
			if alvo.tempo_sem_se_mover >= 0.35:
				# expulsa em direção ao centro
				var ao_centro: Vector2 = (lim.get_center() - pos).normalized()
				vel = ao_centro * (velocidade_minima_alvo * 2.2)
				alvo.tempo_sem_se_mover = 0.0
		else:
			alvo.tempo_sem_se_mover = 0.0
		# no plano Z = 1 o passo é maior longe; na tela, longe anda um pouco
		# mais devagar (1/raiz(z)), como coisa distante
		pos += vel * sqrt(alvo.z) * delta
		alvo.pos = pos
		alvo.vel = vel
		var progresso: float = clamp(alvo.idade / max(alvo.vida, 0.01), 0.0, 1.0)
		alvo.raio = lerp(alvo.raio_inicial, alvo.raio_final, progresso)

	_resolver_colisoes_entre_alvos()

	for alvo in alvos_ativos:
		if alvo == null:
			continue
		if alvo.node == null or not is_instance_valid(alvo.node):
			continue
		_posicionar_alvo_3d(alvo)
		var anim: AnimatedSprite2D = _obter_animado(alvo.node)
		if anim != null:
			anim.centered = true
			if alvo.tipo == MODO_LUA:
				anim.position = offset_sprite_lua
			else:
				anim.position = Vector2.ZERO
		var centro_visual: Vector2 = _centro_visual_efeito_alvo(alvo)
		if alvo.halo != null and is_instance_valid(alvo.halo):
			alvo.halo.global_position = centro_visual
		if alvo.brilho != null and is_instance_valid(alvo.brilho):
			alvo.brilho.global_position = centro_visual
		_atualizar_efeito_alvo(alvo)


# ───────────────────────────────────────────── 3D dos brasões
## Ponto de fuga da cena (pé das pirâmides), na tela.
func _fuga() -> Vector2:
	if _vivo != null:
		return _vivo.ponto_de_fuga()
	return get_viewport_rect().size * Vector2(0.5, 0.46)


## Onde fica no plano Z = 1 um ponto s da tela visto à distância z.
func _no_plano(s_tela: Vector2, z: float) -> Vector2:
	var f := _fuga()
	return f + (s_tela - f) * z


## Área livre do brasão no plano Z = 1, na distância z: a tela inteira (menos
## o placar e o rodapé) e, embaixo, o chão naquela distância.
func _limites_no_plano(z: float, r: float) -> Rect2:
	var tela: Vector2 = get_viewport_rect().size
	var f := _fuga()
	var baixo: float = tela.y - faixa_spawn_base_margem
	if _vivo != null:
		baixo = minf(baixo, f.y + (_vivo.chao_1() - f.y) / maxf(z, 0.3))
	var a := Vector2(r, faixa_spawn_topo + r)
	var b := Vector2(tela.x - r, maxf(baixo - r, a.y + 10.0))
	var pa := f + (a - f) * z
	var pb := f + (b - f) * z
	return Rect2(pa, pb - pa)


## A distância do brasão agora: entra (do horizonte vem vindo; de trás do
## cristal sai), vai se afastando com a idade (o antigo encolhimento), depois
## de trocar de brasão volta para perto, e na saída vem até o vidro ou some
## lá longe.
func _profundidade_do_alvo(alvo: TargetData) -> void:
	var t: float = alvo.idade
	var fim_corpo: float = maxf(alvo.vida - SAIDA_TEMPO, alvo.entrada + 0.1)
	var z: float
	if alvo.swap_idade >= 0.0:
		var k: float = clampf((t - alvo.swap_idade) / maxf(fim_corpo - alvo.swap_idade, 0.3), 0.0, 1.0)
		z = lerpf(alvo.swap_z, alvo.z_de, k)
	else:
		var p: float = clampf((t - alvo.entrada) / (fim_corpo - alvo.entrada), 0.0, 1.0)
		z = lerpf(alvo.z_de, alvo.z_ate, 1.0 - pow(1.0 - p, 2.0))
	var alfa: float = 1.0
	if t < alvo.entrada:
		var e: float = t / alvo.entrada
		e = 1.0 - (1.0 - e) * (1.0 - e)
		z = lerpf(alvo.z_entrada, z, e)
		if alvo.estilo == "horizonte" or alvo.estilo == "alto_l":
			alfa = clampf(t / 0.22, 0.0, 1.0)
	if t > alvo.vida - SAIDA_TEMPO:
		var k: float = clampf((t - (alvo.vida - SAIDA_TEMPO)) / SAIDA_TEMPO, 0.0, 1.0)
		if alvo.saida == "vidro":
			z = lerpf(z, 0.48, k * k)
			alfa = 1.0 - smoothstep(0.35, 1.0, k)
		else:
			z = lerpf(z, 7.0, k * k)
			alfa = 1.0 - smoothstep(0.45, 1.0, k)
	alvo.z = z
	alvo.alfa = alfa


## Põe o brasão na tela pela distância: posição, tamanho, ordem de desenho
## (o mais perto por cima), névoa e o "esconde atrás" do shader.
func _posicionar_alvo_3d(alvo: TargetData) -> void:
	var f := _fuga()
	var cam: Vector2 = _vivo.paralaxe(alvo.z) if _vivo != null else Vector2.ZERO
	alvo.tela = f + (alvo.pos - f) / alvo.z + cam
	alvo.node.global_position = alvo.tela
	alvo.node.scale = Vector2.ONE * (alvo_scale_base * alvo.tam / alvo.z)
	alvo.node.z_as_relative = false
	alvo.node.z_index = _z_desenho(alvo.z)
	var anim: AnimatedSprite2D = _obter_animado(alvo.node)
	if anim != null:
		anim.self_modulate.a = alvo.alfa
		anim.set_instance_shader_parameter("inv_z", 1.0 / alvo.z)
		anim.set_instance_shader_parameter("nevoa", _nevoa(alvo.z))


func _z_desenho(z: float) -> int:
	return 100 + clampi(int(round(60.0 / maxf(z, 0.3))), 0, 190)


## Névoa da distância: nada até 1,5; longe cobre até a metade.
func _nevoa(z: float) -> float:
	return clampf((z - 1.5) / 6.0, 0.0, 0.5)


func _sortear_estilo_3d() -> String:
	var r := randf()
	for nome: String in ESTILOS_3D:
		r -= float(ESTILOS_3D[nome])
		if r <= 0.0:
			return nome
	return "lado"


func _raio_colisao_alvo(alvo: TargetData) -> float:
	if alvo == null:
		return 38.0

	var escala: float = alvo_scale_base
	if alvo.node != null and is_instance_valid(alvo.node):
		escala = max(abs(alvo.node.scale.x), abs(alvo.node.scale.y))

	var raio_sprite: float = 62.0

	if alvo.tipo == MODO_SOL:
		raio_sprite = 66.0
	else:
		raio_sprite = 64.0

	return max(28.0, raio_sprite * escala)


func _resolver_colisoes_entre_alvos() -> void:
	if not colisao_alvos_ativa:
		return

	for passo in range(3):
		for i in range(alvos_ativos.size()):
			var a: TargetData = alvos_ativos[i]
			if a == null or a.node == null or not is_instance_valid(a.node):
				continue

			for j in range(i + 1, alvos_ativos.size()):
				var b: TargetData = alvos_ativos[j]
				if b == null or b.node == null or not is_instance_valid(b.node):
					continue

				# >>> NOVO: só colide quem é de tipo diferente
				if a.tipo == b.tipo:
					continue
				# <
				# 3D: só esbarra quem está na mesma distância (um passa na
				# frente do outro) e já entrou de vez
				if absf(a.z - b.z) > 0.35 or a.alfa < 0.95 or b.alfa < 0.95:
					continue

				var delta_pos: Vector2 = b.pos - a.pos
				var dist: float = delta_pos.length()

				if dist <= 0.001:
					delta_pos = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
					dist = 1.0

				var normal: Vector2 = delta_pos / dist
				# raios no plano Z = 1 (na tela o raio é r; no plano, r * z)
				var raio_a: float = _raio_colisao_alvo(a) * a.z
				var raio_b: float = _raio_colisao_alvo(b) * b.z
				var dist_min: float = raio_a + raio_b + margem_colisao_alvos * (a.z + b.z) * 0.5

				if dist < dist_min:
					var overlap: float = dist_min - dist
					var empurrao: Vector2 = normal * (overlap * 0.55 * forca_repelir_alvos)

					a.pos -= empurrao
					b.pos += empurrao

					a.vel = a.vel.bounce(normal) * 1.02
					b.vel = b.vel.bounce(-normal) * 1.02

					if a.vel.length() < velocidade_minima_alvo:
						a.vel = a.vel.normalized() * velocidade_minima_alvo
					if b.vel.length() < velocidade_minima_alvo:
						b.vel = b.vel.normalized() * velocidade_minima_alvo


func _aplicar_sensibilidade_global() -> void:
	# XBOX travado em 5000 — vale para FÁCIL e DIFÍCIL.
	velocidade_mira_xbox = 1500.0

	# MOUSE continua respeitando o config.
	if get_tree().has_meta(META_SENS_MOUSE):
		sensibilidade_mouse = float(get_tree().get_meta(META_SENS_MOUSE))

	sensibilidade_mouse = clamp(sensibilidade_mouse, 0.2, 3.0)


func _max_alvos_para_modo() -> int:
	# 3D: mais brasões (os de longe são pequenos e se escondem atrás das
	# coisas, os de perto passam na frente)
	var base: int = 7
	if pontuacao_total >= 1500:
		base += 1
	return mini(11, base + int(floor(nivel_dificuldade - 1.0)))


func _gerar_onda_inicial() -> void:
	if alvos_ativos.size() >= 3:
		return

	_spawn_alvo_forcado(modo_atual)

	if alvos_ativos.size() < 3:
		_spawn_alvo()

	if alvos_ativos.size() < 3:
		_spawn_alvo()


func _spawn_continuo(delta: float) -> void:
	if not jogo_ativo or not partida_iniciada:
		return

	if intro_ativa or countdown_ativo or fim_ativo:
		return

	var max_alvos: int = _max_alvos_para_modo()
	if alvos_ativos.size() >= max_alvos:
		return

	spawn_timer_continuo -= delta

	# 3D: mais brasões ao mesmo tempo (nascem mais seguido)
	var intervalo: float = intervalo_spawn_continuo * 0.7
	intervalo = max(intervalo_spawn_continuo_min * 0.8, intervalo - (nivel_dificuldade - 1.0) * 0.07)

	if spawn_timer_continuo <= 0.0:
		spawn_timer_continuo = randf_range(intervalo * 0.65, intervalo * 1.35)
		_spawn_alvo()


## Cópia de um alvo-modelo. O duplicate() padrão reinstancia a cena do
## alvo inteira (sun.tscn/lua.tscn): ~1,5 ms por alvo aqui, ~10 ms na TV Box,
## um engasgo a cada alvo novo. Copiar só os nós dá o mesmo alvo (mesmas
## animações e imagens, compartilhadas) em ~0,1 ms.
func _copiar_modelo(modelo: Area2D) -> Area2D:
	return modelo.duplicate(Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS) as Area2D


func _spawn_alvo_forcado(tipo: String) -> void:
	_spawn_alvo_interno(tipo)


func _spawn_alvo() -> void:
	var tipo: String = _sortear_tipo_alvo()
	_spawn_alvo_interno(tipo)


func _sortear_tipo_alvo() -> String:
	var chance_correto: float = 0.58 if pontuacao_total < 1500 else 0.50
	# fica ainda mais hostil conforme dificuldade sobe
	chance_correto -= (nivel_dificuldade - 1.0) * 0.03
	chance_correto = clampf(chance_correto, 0.40, 0.62)

	if randf() < chance_correto:
		return modo_atual
	return MODO_LUA if modo_atual == MODO_SOL else MODO_SOL


func _spawn_alvo_interno(tipo: String) -> void:
	var modelo: Area2D = sun_modelo if tipo == MODO_SOL else lua_modelo
	if modelo == null:
		return

	var alvo_node: Area2D = _copiar_modelo(modelo)
	if alvo_node == null:
		return

	target_root.add_child(alvo_node)
	_preparar_no_do_alvo(alvo_node)

	var tela: Vector2 = get_viewport_rect().size
	var f := _fuga()
	var y_min: float = faixa_spawn_topo
	var y_max: float = tela.y - faixa_spawn_base_margem

	# só a direção vem do jeito de entrar; a rapidez é a do ritmo atual
	var rapidez: float = randf_range(velocidade_alvo_min, velocidade_alvo_max)
	rapidez *= 1.0 + (nivel_dificuldade - 1.0) * 0.15
	if pontuacao_total >= 800:
		rapidez *= 1.10

	var alvo: TargetData = TargetData.new()
	alvo.node = alvo_node
	alvo.tipo = tipo
	alvo.vel_base = rapidez
	alvo.idade = 0.0
	# 3D: cada brasão com o seu tamanho, a sua distância e o seu jeito de
	# entrar e de sair
	alvo.tam = randf_range(0.86, 1.16)
	alvo.z_de = randf_range(0.95, 1.35)
	alvo.z_ate = randf_range(1.9, 2.9)
	alvo.saida = "vidro" if randf() < 0.5 else "longe"
	alvo.estilo = _sortear_estilo_3d()
	var pos: Vector2
	var vel: Vector2
	match alvo.estilo:
		"horizonte":
			# nasce lá longe, quase no pé das pirâmides, e vem vindo
			alvo.entrada = 0.85
			alvo.z_entrada = randf_range(5.0, 7.0)
			var s := Vector2(randf_range(150.0, tela.x - 150.0), randf_range(y_min + 80.0, minf(f.y + 260.0, y_max - 120.0)))
			pos = _no_plano(s, alvo.z_de)
			vel = Vector2.RIGHT.rotated(randf() * TAU)
		"alto_l":
			# cai do alto, reto, e na quina vira de lado (um L)
			alvo.entrada = 0.8
			alvo.z_entrada = alvo.z_de
			var s := Vector2(randf_range(170.0, tela.x - 170.0), y_min - 150.0)
			pos = _no_plano(s, alvo.z_de)
			vel = Vector2(randf_range(-0.10, 0.10), 1.0)
			rapidez *= 1.3
		"atras":
			# sai de trás do cristal ou de um obelisco e vem para a frente
			alvo.entrada = 0.75
			alvo.z_entrada = randf_range(1.75, 2.2)
			alvo.z_de = randf_range(0.95, 1.12)
			var canto: Vector2 = SAIDAS_DE_TRAS[randi() % SAIDAS_DE_TRAS.size()]
			var s: Vector2 = _vivo.get_global_transform() * canto if _vivo != null else f
			pos = _no_plano(s, alvo.z_entrada)
			var lado: float = signf(s.x - f.x) if absf(s.x - f.x) > 40.0 else (1.0 if randf() < 0.5 else -1.0)
			vel = Vector2(lado, randf_range(-0.7, -0.15))
		_:
			# de um lado da tela (ou de baixo), como antes
			alvo.entrada = 0.6
			alvo.z_entrada = alvo.z_de
			var s := Vector2.ZERO
			match randi() % 3:
				0:
					s = Vector2(-90.0, randf_range(y_min + 60.0, y_max - 60.0))
					vel = Vector2(randf_range(230.0, 360.0), randf_range(-120.0, 120.0))
				1:
					s = Vector2(tela.x + 90.0, randf_range(y_min + 60.0, y_max - 60.0))
					vel = Vector2(-randf_range(230.0, 360.0), randf_range(-120.0, 120.0))
				_:
					s = Vector2(randf_range(160.0, tela.x - 160.0), tela.y + 60.0)
					vel = Vector2(randf_range(-140.0, 140.0), -randf_range(240.0, 380.0))
			pos = _no_plano(s, alvo.z_de)
	alvo.z = alvo.z_entrada
	alvo.pos = pos
	alvo.vel = vel.normalized() * rapidez

	# tempo de tela suficiente para mirar; encurta um pouco com o nível
	alvo.vida = max(2.4, randf_range(3.0, 3.8) - (nivel_dificuldade - 1.0) * 0.2)
	alvo.guinada_t = randf_range(0.5, 1.1)

	alvo.raio_inicial = randf_range(42.0, 52.0)
	alvo.raio_final = max(24.0, alvo.raio_inicial - randf_range(8.0, 12.0))
	alvo.raio = alvo.raio_inicial

	if tipo == MODO_SOL:
		alvo.raio_colisao_base = 42.0
		alvo.raio_miolo_base = 24.0
	else:
		alvo.raio_colisao_base = 40.0
		alvo.raio_miolo_base = 22.0

	alvo.seed = randf_range(0.0, 1000.0)
	alvo.movimento = randi() % 5
	alvo.valor_correto = _sortear_pontos_acerto()
	alvo.penalidade_errado = _sortear_penalidade_alvo()

	# ============== TROCA DE BRASÃO ==============
	var chance_troca: float = chance_troca_brasao_base + (nivel_dificuldade - 1.0) * 0.06

	# Só pune brasões CORRETOS (do tipo do modo atual).
	# Brasões errados continuam com a chance base — eles já machucam o jogador.
	if tipo == modo_atual:
		# A cada 1000 pontos, mais 7% de chance de o brasão correto se converter em errado.
		var nivel_pontos: int = int(floor(float(pontuacao_total) / 1000.0))
		chance_troca += float(nivel_pontos) * 0.07

		# Quanto mais perto da troca de modo, mais agressivo (até +12% no final do ciclo).
		var prog_modo: float = clamp(tempo_fase / max(tempo_troca_modo, 0.01), 0.0, 1.0)
		chance_troca += prog_modo * 0.12

	chance_troca = clampf(chance_troca, 0.0, chance_troca_brasao_max)

	# só troca se a vida for longa o bastante para o jogador notar
	if alvo.vida >= 1.8 and randf() < chance_troca:
		# Quanto maior a chance, mais cedo a troca acontece (mais cruel).
		# chance alta -> troca já em 35% da vida; chance baixa -> só lá pelos 70%.
		var t_min: float = lerp(0.55, 0.35, chance_troca / chance_troca_brasao_max)
		var t_max: float = lerp(0.75, 0.60, chance_troca / chance_troca_brasao_max)
		alvo.tempo_para_trocar = maxf(alvo.vida * randf_range(t_min, t_max), alvo.entrada + 0.2)
		alvo.ja_trocou = false
	else:
		alvo.tempo_para_trocar = 0.0
		alvo.ja_trocou = true

	_criar_teia_do_alvo(alvo)
	_profundidade_do_alvo(alvo)
	_posicionar_alvo_3d(alvo)
	_atualizar_efeito_alvo(alvo)
	alvos_ativos.append(alvo)


## Deixa a cópia do modelo pronta: animação do começo, sem física (o tiro é
## conferido à mão) e com o material 3D (some atrás do que está mais perto).
func _preparar_no_do_alvo(no: Area2D) -> void:
	no.visible = true
	no.process_mode = Node.PROCESS_MODE_INHERIT
	no.monitoring = false
	no.monitorable = false
	no.input_pickable = false
	no.z_as_relative = false
	no.z_index = _z_desenho(1.0)
	no.modulate = Color(1, 1, 1, 1)
	var anim: AnimatedSprite2D = _obter_animado(no)
	if anim != null and anim.sprite_frames != null:
		var nome_anim: StringName = anim.sprite_frames.get_animation_names()[0]
		if anim.sprite_frames.has_animation("idle"):
			nome_anim = &"idle"
		anim.visible = true
		anim.centered = true
		anim.position = Vector2.ZERO
		anim.play(nome_anim)
		anim.frame = 0
		if _vivo != null:
			anim.material = _vivo.material_alvo
	for filho in no.get_children():
		if filho is CollisionShape2D:
			(filho as CollisionShape2D).disabled = true


## A teia de luz atrás do brasão (anéis e raios na cor do astro).
func _criar_teia_do_alvo(alvo: TargetData) -> void:
	var teia: Node2D
	if alvo.tipo == MODO_SOL:
		alvo.halo = _criar_halo_sol()
		teia = alvo.halo
	else:
		alvo.brilho = _criar_brilho_lua()
		teia = alvo.brilho
	target_root.add_child(teia)
	teia.visible = true
	teia.global_position = alvo.tela
	teia.z_index = alvo.node.z_index - 1
	if _vivo != null:
		teia.material = _vivo.material_alvo


func _trocar_tipo_alvo(alvo: TargetData) -> void:
	if alvo == null:
		return
	if alvo.node == null or not is_instance_valid(alvo.node):
		return

	var novo_tipo: String = MODO_LUA if alvo.tipo == MODO_SOL else MODO_SOL
	var vel_atual: Vector2 = alvo.vel

	# remove halos/brilhos antigos
	if alvo.halo != null and is_instance_valid(alvo.halo):
		alvo.halo.queue_free()
		alvo.halo = null
	if alvo.brilho != null and is_instance_valid(alvo.brilho):
		alvo.brilho.queue_free()
		alvo.brilho = null
	if alvo.brilho_frente != null and is_instance_valid(alvo.brilho_frente):
		alvo.brilho_frente.queue_free()
		alvo.brilho_frente = null

	var node_antigo: Area2D = alvo.node

	var modelo: Area2D = sun_modelo if novo_tipo == MODO_SOL else lua_modelo
	if modelo == null:
		return

	var novo_node: Area2D = _copiar_modelo(modelo)
	if novo_node == null:
		return

	target_root.add_child(novo_node)
	_preparar_no_do_alvo(novo_node)
	novo_node.global_position = node_antigo.global_position
	novo_node.scale = node_antigo.scale
	novo_node.z_index = node_antigo.z_index

	# flash branco bem visível avisando a troca
	novo_node.modulate = Color(2.4, 2.4, 2.4, 1.0)
	var tw := create_tween()
	tw.tween_property(novo_node, "modulate", Color.WHITE, 0.40)

	# o brasão novo volta para perto (cresce e atrapalha)
	alvo.swap_escala_inicio = max(abs(node_antigo.scale.x), abs(node_antigo.scale.y))
	alvo.swap_idade = alvo.idade
	alvo.swap_z = alvo.z
	alvo.z_de = randf_range(0.95, 1.15)

	# Dá vida extra pro novo brasão crescer e atrapalhar
	alvo.vida = alvo.idade + randf_range(1.4, 2.2) + SAIDA_TEMPO

	node_antigo.queue_free()

	alvo.node = novo_node
	alvo.tipo = novo_tipo
	alvo.ja_trocou = true
	alvo.flash_troca_t = 0.45

	if novo_tipo == MODO_SOL:
		alvo.raio_colisao_base = 42.0
		alvo.raio_miolo_base = 26.0
	else:
		alvo.raio_colisao_base = 40.0
		alvo.raio_miolo_base = 24.0
	_criar_teia_do_alvo(alvo)
	_posicionar_alvo_3d(alvo)

	# pequena guinada na velocidade pra reforçar a troca também visualmente
	var ang_kick: float = randf_range(-PI * 0.25, PI * 0.25)
	alvo.vel = vel_atual.rotated(ang_kick)


func _sortear_penalidade_alvo() -> int:
	var tabela: Array[int] = [20, 50, 80, 100]
	return tabela[randi() % tabela.size()]


func _remover_alvo(indice: int) -> void:
	if indice < 0 or indice >= alvos_ativos.size():
		return

	var alvo: TargetData = alvos_ativos[indice]
	if alvo != null:
		if alvo.halo != null and is_instance_valid(alvo.halo):
			alvo.halo.queue_free()
		if alvo.brilho != null and is_instance_valid(alvo.brilho):
			alvo.brilho.queue_free()
		if alvo.brilho_frente != null and is_instance_valid(alvo.brilho_frente):
			alvo.brilho_frente.queue_free()
		if alvo.node != null and is_instance_valid(alvo.node):
			alvo.node.queue_free()

	alvos_ativos.remove_at(indice)

## Pontos que saltam do brasão: os do sol em ouro, os da lua em prata
## (perdidos em vermelho).
func _mostrar_pontos(pos_global: Vector2, pontos: int, de_longe: bool, tipo: String = "") -> void:
	if _pontos == null or pontos == 0:
		return
	var cor := Color(1.0, 0.35, 0.3)
	var brilho := Color(0, 0, 0, 0)
	if pontos > 0:
		if tipo == MODO_LUA:
			cor = Color(0.98, 1.0, 1.0) if de_longe else Color(0.86, 0.91, 0.98)
			brilho = Color(1.0, 1.0, 1.0, 0.9)
		else:
			cor = Color(1.0, 0.95, 0.55) if de_longe else Color(1.0, 0.82, 0.26)
			brilho = Color(1.0, 0.98, 0.78, 0.85)
	_pontos.mostrar(get_viewport().get_canvas_transform() * pos_global, ("+%d" % pontos) if pontos > 0 else str(pontos), cor,
		1.25 if de_longe else 1.0, brilho)


## Tiro na areia ou na pedra do fundo: furo de bala e a poeira que fica
## pairando em cima (no fundo, anda com o chão quando a câmera anda).
func _furar_fundo(pos_global: Vector2, mat: String) -> void:
	if _furos == null or _vivo == null:
		return
	var p: Vector2 = _vivo.ponto_da_imagem(pos_global)
	# perto (embaixo) o furo é maior; lá no fundo, pequeno
	var esc: float = lerpf(0.32, 0.78, clampf((p.y - DesertoVivo.HORIZONTE) / 800.0, 0.0, 1.0))
	var noite: bool = modo_atual == MODO_LUA
	_furos.cor_poeira = Color(0.40, 0.38, 0.50) if noite else Color(0.98, 0.80, 0.56)
	var cor := Color(0.46, 0.40, 0.48) if noite else Color(1.0, 0.86, 0.66)
	_furos.furar(p, mat, esc, cor)


func _registrar_marca_tiro_errado(pos: Vector2) -> void:
	if marcas_tiro_errado.size() >= 60:
		marcas_tiro_errado.pop_front()

	marcas_tiro_errado.append({
		"pos": pos,
		"idade": 0.0,
		"vida": randf_range(5.0, 8.0),
		"rot": randf_range(-PI, PI),
		"escala": randf_range(0.85, 1.18)
	})


func _atualizar_marcas_tiro_errado(delta: float) -> void:
	for i in range(marcas_tiro_errado.size() - 1, -1, -1):
		var m: Dictionary = marcas_tiro_errado[i]
		m["idade"] = float(m.get("idade", 0.0)) + delta
		marcas_tiro_errado[i] = m

		if float(m.get("idade", 0.0)) >= float(m.get("vida", 1.0)):
			marcas_tiro_errado.remove_at(i)


func _atualizar_fx_cacos(delta: float) -> void:
	for i in range(fx_cacos.size() - 1, -1, -1):
		var fx: Dictionary = fx_cacos[i]
		fx["idade"] = float(fx.get("idade", 0.0)) + delta
		fx["vel"] = Vector2(fx.get("vel", Vector2.ZERO)) + Vector2(0.0, 460.0) * delta
		fx["pos"] = Vector2(fx.get("pos", Vector2.ZERO)) + Vector2(fx["vel"]) * delta
		fx["vel"] = Vector2(fx["vel"]) * 0.985
		fx["rot"] = float(fx.get("rot", 0.0)) + float(fx.get("rot_vel", 0.0)) * delta
		fx_cacos[i] = fx

		if float(fx.get("idade", 0.0)) >= float(fx.get("vida", 1.0)):
			fx_cacos.remove_at(i)


func _desenhar_fx_frontais() -> void:
	if fx_front_overlay == null:
		return

	for m in marcas_tiro_errado:
		var pos: Vector2 = Vector2(m["pos"])
		var idade: float = float(m["idade"])
		var vida: float = float(m["vida"])
		var rot: float = float(m["rot"])
		var escala: float = float(m["escala"])

		var t: float = clamp(idade / vida, 0.0, 1.0)
		var alpha: float = 1.0 - t

		var r1: float = 13.0 * escala
		var r2: float = 6.0 * escala

		# marca de bala na areia: anel externo, anel interno e um X fino
		Pincel.anel(fx_front_overlay, pos, r1, 2.2, Color(0.10, 0.08, 0.06, 0.34 * alpha))
		Pincel.anel(fx_front_overlay, pos, r2, 1.4, Color(0.28, 0.22, 0.16, 0.22 * alpha))
		Pincel.linha(fx_front_overlay, pos + Vector2(-8, -8).rotated(rot), pos + Vector2(8, 8).rotated(rot), Color(0.18, 0.12, 0.08, 0.40 * alpha), 1.6)
		Pincel.linha(fx_front_overlay, pos + Vector2(8, -8).rotated(rot), pos + Vector2(-8, 8).rotated(rot), Color(0.18, 0.12, 0.08, 0.40 * alpha), 1.6)

	for fx in fx_cacos:
		var pos2: Vector2 = Vector2(fx["pos"])
		var vida2: float = float(fx["vida"])
		var idade2: float = float(fx["idade"])
		var rot_deg: float = float(fx["rot"])
		var tam: Vector2 = Vector2(fx["tam"])
		var cor: Color = Color(fx["cor"])

		var t2: float = clamp(idade2 / vida2, 0.0, 1.0)
		cor.a = 1.0 - t2

		Pincel.lasca(fx_front_overlay, pos2, tam * 0.55, deg_to_rad(rot_deg), cor)


func _limpar_alvos() -> void:
	for alvo in alvos_ativos:
		if alvo != null:
			if alvo.halo != null and is_instance_valid(alvo.halo):
				alvo.halo.queue_free()
			if alvo.brilho != null and is_instance_valid(alvo.brilho):
				alvo.brilho.queue_free()
			if alvo.brilho_frente != null and is_instance_valid(alvo.brilho_frente):
				alvo.brilho_frente.queue_free()
			if alvo.node != null and is_instance_valid(alvo.node):
				alvo.node.queue_free()

	alvos_ativos.clear()
	marcas_tiro_errado.clear()
	fx_cacos.clear()
	if _furos != null:
		_furos.limpar()

	if fx_front_overlay != null:
		fx_front_overlay.queue_redraw()


func _explodir_alvo_visual(alvo: TargetData) -> void:
	if alvo == null or alvo.node == null or not is_instance_valid(alvo.node):
		return

	# clarão, raios/arcos de luz, anéis e estilhaços do próprio artefato
	EgitoAcerto.criar(self, alvo.node, alvo.tipo, alvo.tipo == modo_atual)

	if alvo.halo != null and is_instance_valid(alvo.halo):
		alvo.halo.queue_free()

	if alvo.brilho != null and is_instance_valid(alvo.brilho):
		alvo.brilho.queue_free()

	if alvo.brilho_frente != null and is_instance_valid(alvo.brilho_frente):
		alvo.brilho_frente.queue_free()

	var area: Area2D = alvo.node
	var anim: AnimatedSprite2D = _obter_animado(area)

	if anim != null and anim.sprite_frames != null and anim.sprite_frames.has_animation("hit"):
		anim.play("hit")
		anim.frame = 0

		var frames_hit: int = anim.sprite_frames.get_frame_count("hit")
		var fps_hit: float = anim.sprite_frames.get_animation_speed("hit")
		var duracao: float = 0.20

		if fps_hit > 0.0 and frames_hit > 0:
			duracao = max(0.18, float(frames_hit) / fps_hit)

		var tw := area.create_tween()   # do próprio brasão: some junto com ele
		tw.tween_interval(duracao)
		tw.tween_callback(func():
			if is_instance_valid(area):
				area.queue_free()
		)
	else:
		area.queue_free()


func _iniciar_recarga() -> void:
	if not jogo_ativo or intro_ativa or countdown_ativo or fim_ativo:
		return
	if recarregando:
		return
	if balas_no_cartucho >= capacidade_cartucho:
		return

	recarregando = true
	reload_tempo_restante = tempo_recarga_seg
	_tocar_som(som_recharge)
	if _vivo != null:
		_vivo.evento("recarga")
	_set_status("RECARREGANDO...", Color(0.30, 0.92, 1.0, 1.0))


func _finalizar_recarga() -> void:
	recarregando = false
	reload_tempo_restante = 0.0
	balas_no_cartucho = capacidade_cartucho
	_set_status("", Color.WHITE)


func _encerrar_jogo() -> void:
	if _vivo != null:
		_vivo.evento("fim")
	jogo_ativo = false
	fim_ativo = true
	partida_iniciada = false
	countdown_ativo = false
	recarregando = false
	fim_tempo_voltar = Maquina.tempo_volta_menu()

	_limpar_alvos()
	_tocar_musica_bg()

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

	var entrou_ranking: bool = bool(RankingManager.call(
	"deve_entrar_no_ranking",
	pontuacao_total,
	precisao
))

	var texto_ranking: String = "\n\nPONTUAÇÃO FORA DO TOP 20."
	if entrou_ranking:
		texto_ranking = "\n\n🏆 NOVO RECORDE! ESCOLHA SEU NOME."

	if fim_titulo != null:
		fim_titulo.text = "FIM DE JOGO"

	if fim_texto != null:
		fim_texto.text = "RESULTADO FINAL\n\nPONTUAÇÃO: %d\nTIROS: %d\nACERTOS: %d\nERROS: %d\nACERTO: %d%%\nMELHOR SEQUÊNCIA: x%d\nDESEMPENHO: %s%s" % [
			pontuacao_total,
			total_tiros,
			total_acertos,
			total_erros,
			precisao,
			melhor_combo,
			aproveitamento,
			texto_ranking
		]

	if fim_footer != null:
		if entrou_ranking:
			fim_footer.text = "ATIRE NAS LETRAS PARA SALVAR O RECORDE"
		else:
			fim_footer.text = Maquina.texto_jogar_novamente()
			
	
	_atualizar_estilo_modais_por_modo()   # ← adicionar aqui
	if fim_root != null:
		fim_root.visible = true

	_ajustar_layout()

	fim_tempo_voltar = Maquina.tempo_volta_menu()
	if entrou_ranking:
		# a contagem só começa depois do nome (ranking_nome_ativo já segura)
		ranking_nome_ativo = true
		call_deferred("_abrir_modal_nome_ranking", pontuacao_total, "DESERTO", precisao)


func _reiniciar_jogo() -> void:
	# Jogar de novo = recarregar a fase do zero (scripts/fim_partida.gd): nada
	# da partida anterior fica rodando por baixo, mesmo com START repetido.
	FimPartida.jogar_de_novo(self)


func _set_status(texto: String, cor: Color, duracao: float = 1.5) -> void:
	if texto == "":
		return

	status_msgs.append({
		"text": texto,
		"cor": cor,
		"time": duracao
	})

	if status_msgs.size() > 3:
		status_msgs.pop_front()


func _tocar_som(stream: AudioStream) -> void:
	Maquina.efeito(stream)


func _parar_musica_fim() -> void:
	if fim_music_player != null and fim_music_player.playing:
		fim_music_player.stop()


func _criar_halo_sol() -> Node2D:
	var teia := TeiaAlvo.new()
	teia.name = "TeiaTamanhoOriginalSol"
	teia.z_as_relative = false
	return teia.configurar(COR_SOL, 42.0, 4, 10.0, 14, 26.0, 78.0, 2.2, 1.3, 0.20, 0.16)


func _criar_brilho_lua() -> Node2D:
	var teia := TeiaAlvo.new()
	teia.name = "TeiaTamanhoOriginalLua"
	teia.z_as_relative = false
	return teia.configurar(COR_LUA, 40.0, 4, 10.0, 14, 24.0, 76.0, 2.0, 1.2, 0.20, 0.16)


func _atualizar_efeito_alvo(alvo: TargetData) -> void:
	if alvo == null:
		return

	if alvo.node == null or not is_instance_valid(alvo.node):
		return

	var progresso: float = clamp(alvo.idade / max(alvo.vida, 0.01), 0.0, 1.0)

	var teia: Node2D = null
	var cor_teia: Color = COR_SOL

	if alvo.tipo == MODO_SOL:
		teia = alvo.halo
		cor_teia = COR_SOL
	else:
		teia = alvo.brilho
		cor_teia = COR_LUA

	if teia != null and is_instance_valid(teia):
		teia.visible = true
		teia.global_position = _centro_visual_efeito_alvo(alvo)

		# A teia fica ATRÁS do brasão. Com a distância ela diminui menos que o
		# brasão (longe, a teia continua mostrando onde ele está); some atrás
		# das coisas junto com ele.
		teia.z_as_relative = false
		teia.z_index = alvo.node.z_index - 1
		teia.scale = Vector2.ONE * (alvo_scale_base * alvo.tam / pow(alvo.z, 0.7))
		teia.rotation += 0.002
		teia.modulate.a = alvo.alfa
		teia.set_instance_shader_parameter("inv_z", 1.0 / alvo.z)
		teia.set_instance_shader_parameter("nevoa", _nevoa(alvo.z) * 0.5)

		if teia.has_method("ajustar_progresso"):
			teia.ajustar_progresso(cor_teia, progresso)

	if alvo.brilho_frente != null and is_instance_valid(alvo.brilho_frente):
		alvo.brilho_frente.visible = false


func _criar_faixa_luz_frontal(cor: Color) -> Node2D:
	# anel frontal suave + feixes tipo estrela
	var teia := TeiaAlvo.new()
	return teia.configurar(cor, 44.0, 2, 8.0, 8, 26.0, 58.0, 3.3, 2.0, 0.18, 0.30)


const BOTAO_GATILHO_1: int = MOUSE_BUTTON_RIGHT
const BOTAO_GATILHO_2: int = MOUSE_BUTTON_LEFT

const BOTAO_RECARGA_1: int = MOUSE_BUTTON_MIDDLE
const BOTAO_RECARGA_2: int = MOUSE_BUTTON_XBUTTON1
const BOTAO_RECARGA_3: int = MOUSE_BUTTON_XBUTTON2

var tempo_trava_input_arma: float = 0.0


func _pos_arma() -> Vector2:
	return mira_pos


func _debug_botao_arma(me: InputEventMouseButton) -> void:
	print("BOTAO ARMA DESERTO: ", me.button_index)


func _evento_tiro_arma(me: InputEventMouseButton) -> bool:
	# Gatilho = clique esquerdo (Maquina cuida dos botões aprendidos da arma).
	return Maquina.e_tiro_arma(me)


func _evento_recarga_arma(me: InputEventMouseButton) -> bool:
	# Recarga = botão aprendido na configuração (padrão: direito/meio/laterais).
	return Maquina.e_recarga_arma(me)


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
	# No ranking, a própria função do teclado controla a trava.
	if ranking_nome_ativo:
		_ranking_tentar_atirar_tecla(mira_pos)
		return

	if tempo_trava_input_arma > 0.0:
		return

	tempo_trava_input_arma = 0.10

	if fim_ativo:
		return

	if countdown_ativo:
		return

	if intro_ativa:
		_iniciar_countdown()
		return

	if jogo_ativo and partida_iniciada:
		var pos_canvas: Vector2 = _pos_tela_para_canvas(mira_pos)
		_processar_tiro(pos_canvas)


func _executar_recarga_arma() -> void:
	if ranking_nome_ativo:
		return

	if tempo_trava_input_arma > 0.0:
		return

	tempo_trava_input_arma = 0.10

	if jogo_ativo and partida_iniciada:
		if not fim_ativo and not countdown_ativo and not recarregando:
			_iniciar_recarga()


func _centro_visual_efeito_alvo(alvo: TargetData) -> Vector2:
	if alvo == null:
		return Vector2.ZERO
	return alvo.tela


func _carregar_config_admin_jogo() -> void:
	var cfg_admin := ConfigFile.new()
	var err := cfg_admin.load("user://config_admin.cfg")

	if err != OK:
		return

	tempo_partida = float(cfg_admin.get_value("jogo", "tempo_partida", tempo_partida))

	if "fim_tempo_voltar" in self:
		fim_tempo_voltar = Maquina.tempo_volta_menu()

	if "ranking_nome_tempo" in self:
		ranking_nome_tempo = float(cfg_admin.get_value("ranking", "tempo_nome", ranking_nome_tempo))

	get_tree().set_meta("admin_tempo_partida", tempo_partida)
	get_tree().set_meta("admin_tempo_modal_final", fim_tempo_voltar)
	get_tree().set_meta("admin_tempo_ranking_nome", ranking_nome_tempo)


func _carregar_fontes_ui() -> void:
	if ResourceLoader.exists(FONTE_TEXTO):
		fonte_orbitron = load(FONTE_TEXTO) as FontFile

	if ResourceLoader.exists(FONTE_LUCKIEST):
		fonte_luckiest = load(FONTE_LUCKIEST) as FontFile


func _fonte_titulo(lbl: Label, tamanho: int, cor: Color) -> void:
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


func _fonte_valor(lbl: Label, tamanho: int, cor: Color) -> void:
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
	


func _atualizar_estilo_hud_por_modo() -> void:
	if hud_root == null or _hud_estilo_modo == modo_atual:
		return
	_hud_estilo_modo = modo_atual

	var cor_neon: Color = COR_SOL
	var cor_texto: Color = Color(1.0, 0.88, 0.28, 1.0)
	var cor_fundo: Color = Color(0.030, 0.020, 0.010, 0.91)

	if modo_atual == MODO_LUA:
		cor_neon = Color(0.92, 0.98, 1.0, 1.0)
		cor_texto = Color(0.96, 1.0, 1.0, 1.0)
		cor_fundo = Color(0.018, 0.025, 0.040, 0.92)

	for nome in ["CardTempo", "CardScore", "CardModo", "CardMunicao", "CardTiros", "CardAcertos"]:
		var card := hud_root.get_node_or_null(nome) as Panel
		if card == null:
			continue

		var estilo := card.get_theme_stylebox("panel") as StyleBoxFlat
		if estilo == null:
			continue

		Leve.prop(estilo, "bg_color", cor_fundo)
		Leve.prop(estilo, "border_color", cor_neon)
		Leve.prop(estilo, "shadow_color", Color(cor_neon.r, cor_neon.g, cor_neon.b, 0.58))
		Leve.prop(estilo, "shadow_size", 34)

		var titulo := card.get_node_or_null("Titulo") as Label
		if titulo != null:
			_fonte_titulo(titulo, 20, cor_texto)

	if label_score != null:
		_fonte_valor(label_score, 52, cor_texto)

	if label_timer != null:
		_fonte_valor(label_timer, 42, Color.WHITE)

	if label_modo != null:
		_fonte_valor(label_modo, 19, cor_neon)

	if label_tiros != null:
		_fonte_valor(label_tiros, 22, Color.WHITE)

	if label_acertos != null:
		_fonte_valor(label_acertos, 22, Color.WHITE)

	if label_municao_estado != null:
		_fonte_valor(label_municao_estado, 20, Color.WHITE)


func _cor_modo_atual() -> Color:
	return COR_SOL if modo_atual == MODO_SOL else COR_LUA


func _fundo_card_deserto() -> Color:
	if modo_atual == MODO_SOL:
		return Color(0.026, 0.018, 0.010, 0.93)
	return Color(0.012, 0.020, 0.038, 0.93)


func _estilo_card_deserto(cor_neon: Color = COR_SOL) -> StyleBoxFlat:
	var fundo: Color = Color(0.026, 0.018, 0.010, 0.93) if cor_neon == COR_SOL \
		else Color(0.012, 0.020, 0.038, 0.93)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color            = fundo
	estilo.border_width_left   = 4
	estilo.border_width_top    = 4
	estilo.border_width_right  = 4
	estilo.border_width_bottom = 4
	estilo.border_color        = cor_neon
	estilo.corner_radius_top_left     = 56
	estilo.corner_radius_top_right    = 56
	estilo.corner_radius_bottom_left  = 56
	estilo.corner_radius_bottom_right = 56
	estilo.shadow_color  = Color(cor_neon.r, cor_neon.g, cor_neon.b, 0.60)
	estilo.shadow_size   = 44
	estilo.shadow_offset = Vector2.ZERO
	return estilo


func _atualizar_estilo_modais_por_modo() -> void:
	var cor    := _cor_modo_atual()
	var fundo  := _fundo_card_deserto()

	# ── fim_panel ────────────────────────────────────────────────────────
	if fim_panel != null:
		var estilo_fim := fim_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if estilo_fim != null:
			estilo_fim.bg_color     = fundo
			estilo_fim.border_color = cor
			estilo_fim.shadow_color = Color(cor.r, cor.g, cor.b, 0.60)

		var topo := fim_panel.get_node_or_null("FimTopo") as Panel
		if topo != null:
			var topo_estilo := topo.get_theme_stylebox("panel") as StyleBoxFlat
			if topo_estilo != null:
				topo_estilo.bg_color = Color(0.06, 0.04, 0.01, 1.0) if modo_atual == MODO_SOL \
					else Color(0.04, 0.07, 0.14, 1.0)

		var linha := fim_panel.get_node_or_null("FimLinha") as ColorRect
		if linha != null:
			linha.color = cor

	if fim_titulo != null:
		Leve.color(fim_titulo, "font_color",
			Color(1.0, 0.86, 0.24, 1.0) if modo_atual == MODO_SOL
			else Color(0.82, 0.96, 1.0, 1.0))

	if fim_texto != null:
		Leve.color(fim_texto, "font_color",
			Color(0.96, 0.90, 0.78, 1.0) if modo_atual == MODO_SOL
			else Color(0.88, 0.96, 1.0, 1.0))

	if fim_footer != null:
		Leve.color(fim_footer, "font_color",
			Color(1.0, 0.90, 0.30, 1.0) if modo_atual == MODO_SOL
			else Color(0.72, 0.96, 1.0, 1.0))

	if fim_contagem_label != null:
		Leve.color(fim_contagem_label, "font_color",
			Color(1.0, 0.66, 0.16, 1.0) if modo_atual == MODO_SOL
			else Color(0.56, 0.84, 1.0, 1.0))

	# ── ranking_nome_panel ───────────────────────────────────────────────
	if ranking_nome_panel != null:
		var estilo_rank := ranking_nome_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if estilo_rank != null:
			estilo_rank.bg_color     = fundo
			estilo_rank.border_color = cor
			estilo_rank.shadow_color = Color(cor.r, cor.g, cor.b, 0.60)

	if ranking_nome_display != null:
		Leve.color(ranking_nome_display, "font_color",
			Color(1.0, 0.92, 0.30, 1.0) if modo_atual == MODO_SOL
			else Color(0.82, 0.96, 1.0, 1.0))

	if ranking_nome_timer_label != null:
		Leve.color(ranking_nome_timer_label, "font_color",
			Color(1.0, 0.68, 0.18, 1.0) if modo_atual == MODO_SOL
			else Color(0.56, 0.84, 1.0, 1.0))
