extends Node2D

@export_file("*.tscn") var cena_do_jogo: String = "res://scenes/cenarios.tscn"
@export_file("*.tscn") var cena_demo: String = "res://scenes/demo.tscn"

@export_file("*.tscn") var cena_ranking: String = "res://scenes/ranking.tscn"
@export_file("*.tscn") var cena_admin: String = "res://scenes/admin.tscn"

var TEMPO_INTRO: float = 40.0
var TEMPO_TEASER: float = 20.0

const TEASERS: Array[String] = [
	"res://background_video/teaser_arena.ogv",
	"res://background_video/teaser_bar.ogv",
	"res://background_video/teaser_mar.ogv",
	"res://background_video/teaser_desert.ogv"
]


@onready var parallax_bg: ParallaxBackground = $ParallaxBackground

const MP4_INTRO: String = "res://background_video/back_init.mp4"
const OGV_INTRO: String = "res://background_video/back_init.ogv"

var video_layer: CanvasLayer = null
# Quadro parado do vídeo inicial (aparece na hora, sem tela preta) e, por
# cima, o vídeo tocado pelo decodificador de hardware da TV Box.
var fundo_vivo: FundoVivo = null
var video_intro: VideoNativo = null
# Prévia do modo demonstração (também pelo hardware); entra por cima.
var video_teaser: VideoNativo = null
@onready var meio_sprite: Sprite2D = $ParallaxBackground/MeioLayer/Sprite2D
@onready var frente_sprite: Sprite2D = $ParallaxBackground/FrenteLayer/Sprite2D

@onready var pressione: Label = $CanvasLayer/Pressione1
@onready var flash_intro: ColorRect = $CanvasLayer/FlashIntro

@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer

const CAMINHO_MUSICA: String      = "res://songs/song.ogg"
const CAMINHO_AUDIO_INTRO: String = "res://songs/audio_intro.mp3"
const CAMINHO_SOM_INIT: String = "res://songs/init.wav"


const VOLUME_INTRO_DB: float      = -3.0
const VOLUME_MUSICA_DB: float     = -5.0
const VOLUME_FADE_OUT_DB: float   = -40.0
const TEMPO_FADE_SAIDA: float     = 0.35

var transicionando: bool = false
var tween_pressione: Tween = null
var tween_fx: Tween = null
var tween_audio_intro: Tween = null
var tween_audio_bg: Tween = null
var audio_intro_player: AudioStreamPlayer = null
var audio_init_player: AudioStreamPlayer = null
var tween_audio_init: Tween = null

var rodada_mostrar_ranking: bool = false
var teasers_disponiveis: Array[String] = []
var teaser_atual: String = ""



func _ready() -> void:
	_ocultar_ponteiro_mouse()
	_configurar_fundos()
	_configurar_canvas()
	_configurar_audio()
	
	if get_tree().has_meta("admin_tempo_intro_main"):
		TEMPO_INTRO = float(get_tree().get_meta("admin_tempo_intro_main"))

	if get_tree().has_meta("admin_tempo_teaser"):
		TEMPO_TEASER = float(get_tree().get_meta("admin_tempo_teaser"))

	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
		
	teasers_disponiveis = TEASERS.duplicate()
	teasers_disponiveis.shuffle()
	rodada_mostrar_ranking = false

	# A abertura entra com a tela pronta: depois da transição (ou do boot),
	# com o vídeo já rodando (no máximo 1,2 s de espera) e os quadros
	# estáveis. Os primeiros quadros de uma tela nova são os mais pesados.
	await _esperar_tela_estavel()
	_tocar_intro()


func _esperar_tela_estavel() -> void:
	var arvore := get_tree()
	await arvore.process_frame
	while TransicaoGlobal.em_transicao:
		await arvore.process_frame
	# vídeo no primeiro quadro e 3 quadros seguidos dentro do ritmo (ou no
	# máximo 1,2 s esperando)
	var bons := 0
	var inicio := Time.get_ticks_msec()
	var antes := Time.get_ticks_usec()
	while Time.get_ticks_msec() - inicio < 1200:
		await arvore.process_frame
		var agora := Time.get_ticks_usec()
		bons = bons + 1 if (agora - antes) < 26000 else 0
		antes = agora
		var video_ok := video_intro == null or video_intro.esta_mostrando() or video_intro.modo == ""
		if bons >= 3 and video_ok:
			break


func _process(_delta: float) -> void:
	_ocultar_ponteiro_mouse()


func _mostrar_tela_inicial() -> void:
	flash_intro.visible = false
	flash_intro.modulate.a = 0.0

	pressione.modulate.a = 1.0
	pressione.scale = Vector2.ONE

	_iniciar_pisca_pressione()
	_iniciar_timer_intro()


func _unhandled_input(event: InputEvent) -> void:
	if transicionando:
		return

	if event is InputEventKey:
		var key := event as InputEventKey

		if key.pressed and not key.echo:
			if key.keycode == KEY_F10:
				_abrir_tela_admin()
				return

	if _evento_start(event):
		# Modo crédito: só começa se houver crédito (desconta aqui).
		if Maquina.cobrar():
			_iniciar_com_confirmacao()


func _abrir_tela_admin() -> void:
	if transicionando:
		return

	if cena_admin == "":
		push_error("Cena admin não configurada.")
		return

	if not ResourceLoader.exists(cena_admin):
		push_error("Cena admin não encontrada: " + cena_admin)
		return

	transicionando = true

	if tween_pressione != null:
		tween_pressione.kill()
	if tween_fx != null:
		tween_fx.kill()
	if tween_audio_intro != null:
		tween_audio_intro.kill()
	if tween_audio_bg != null:
		tween_audio_bg.kill()

	_mostrar_ponteiro_mouse()

	get_tree().set_meta("admin_origem", "main")
	TransicaoGlobal.trocar_cena(cena_admin)


# ─────────────────────────────────────────────
#  FUNDOS
# ─────────────────────────────────────────────
func _configurar_fundos() -> void:
	var tela: Vector2 = get_viewport_rect().size

	_garantir_video_intro()
	_ajustar_video_intro(tela)

	# camadas antigas da cena (sem imagem): nada a desenhar
	if meio_sprite != null:
		meio_sprite.visible = false
	if frente_sprite != null:
		frente_sprite.visible = false


func _garantir_video_intro() -> void:
	var fundo_antigo: Node = get_node_or_null("ParallaxBackground/FundoLayer/Sprite2D")
	if fundo_antigo != null:
		fundo_antigo.visible = false

	var video_antigo: Node = get_node_or_null("ParallaxBackground/FundoLayer/VideoInit")
	if video_antigo != null:
		video_antigo.visible = false

	if video_layer == null:
		video_layer = CanvasLayer.new()
		video_layer.name = "VideoIntroLayer"
		video_layer.layer = -100
		add_child(video_layer)

	if fundo_vivo == null:
		fundo_vivo = FundoVivo.new(["init"])
		video_layer.add_child(fundo_vivo)
		fundo_vivo.mostrar("init")

	if video_intro == null:
		video_intro = VideoNativo.new(MP4_INTRO, OGV_INTRO, Vector2(720, 1088), true, 0.0)
		video_layer.add_child(video_intro)
		# com o vídeo na tela, o quadro parado de baixo deixa de ser desenhado
		video_intro.comecou.connect(func() -> void:
			get_tree().create_timer(0.5).timeout.connect(func() -> void:
				if fundo_vivo != null and video_intro != null and video_intro.esta_mostrando():
					fundo_vivo.visible = false
			)
		)
		video_intro.tocar()


func _ajustar_video_intro(_tela: Vector2) -> void:
	if fundo_vivo != null:
		fundo_vivo.ajustar()
	if video_intro != null:
		video_intro.ajustar()
	if video_teaser != null:
		video_teaser.ajustar()


func _carregar_textura_no_sprite(sprite: Sprite2D, caminho: String) -> void:
	if sprite == null:
		return
	if caminho == "":
		push_warning("Caminho do fundo está vazio.")
		return
	if not ResourceLoader.exists(caminho):
		push_warning("Fundo não encontrado em: " + caminho)
		return

	sprite.texture = load(caminho)



func _ajustar_sprite_para_tela_sem_corte(sprite: Sprite2D, tela: Vector2) -> void:
	if sprite == null or sprite.texture == null:
		return

	var tex_size: Vector2 = sprite.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	# Sem crop: escala independente em X e Y para ocupar a tela inteira
	sprite.centered = true
	sprite.position = tela * 0.5
	sprite.scale = Vector2(tela.x / tex_size.x, tela.y / tex_size.y)



# ─────────────────────────────────────────────
#  CANVAS
# ─────────────────────────────────────────────
func _configurar_canvas() -> void:
	pressione.visible = true
	pressione.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pressione.anchor_left = 0.5
	pressione.anchor_right = 0.5
	pressione.anchor_top = 1.0
	pressione.anchor_bottom = 1.0
	pressione.offset_left = -360.0
	pressione.offset_right = 360.0
	pressione.offset_top = -125.0
	pressione.offset_bottom = -35.0
	pressione.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pressione.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pressione.text = Maquina.texto_chamada()
	if not Maquina.creditos_mudaram.is_connected(_ao_mudar_creditos):
		Maquina.creditos_mudaram.connect(_ao_mudar_creditos)
	pressione.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Leve.font_size(pressione, "font_size", 34)
	Leve.color(pressione, "font_color", Color(1, 1, 1, 1))
	Leve.color(pressione, "font_outline_color", Color(0, 0, 0, 1))
	Leve.constant(pressione, "outline_size", 5)
	pressione.modulate = Color(1, 1, 1, 0)
	pressione.scale = Vector2(0.96, 0.96)

	flash_intro.visible = true
	flash_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_intro.anchor_left = 0.0
	flash_intro.anchor_top = 0.0
	flash_intro.anchor_right = 1.0
	flash_intro.anchor_bottom = 1.0
	flash_intro.offset_left = 0.0
	flash_intro.offset_top = 0.0
	flash_intro.offset_right = 0.0
	flash_intro.offset_bottom = 0.0
	# A abertura nasce do preto (a transição chega no preto) e o preto abre
	# devagar sobre o vídeo. Sem tela branca chapada.
	flash_intro.color = Color(0, 0, 0, 1)
	flash_intro.modulate = Color(1, 1, 1, 1)


# ─────────────────────────────────────────────
#  ÁUDIO
# ─────────────────────────────────────────────
func _configurar_audio() -> void:
	audio_intro_player = AudioStreamPlayer.new()
	audio_intro_player.name = "AudioIntro"
	audio_intro_player.bus = "Master"
	add_child(audio_intro_player)

	if ResourceLoader.exists(CAMINHO_AUDIO_INTRO):
		audio_intro_player.stream = load(CAMINHO_AUDIO_INTRO)
		audio_intro_player.volume_db = VOLUME_INTRO_DB
	else:
		push_warning("Audio intro não encontrado: " + CAMINHO_AUDIO_INTRO)

	audio_init_player = AudioStreamPlayer.new()
	audio_init_player.name = "AudioInit"
	audio_init_player.bus = "Master"
	add_child(audio_init_player)

	if ResourceLoader.exists(CAMINHO_SOM_INIT):
		audio_init_player.stream = load(CAMINHO_SOM_INIT)
		audio_init_player.volume_db = 0.0
	else:
		push_warning("Som init não encontrado: " + CAMINHO_SOM_INIT)

	if audio_player != null:
		if ResourceLoader.exists(CAMINHO_MUSICA):
			audio_player.stream = load(CAMINHO_MUSICA)
			audio_player.autoplay = false
			audio_player.bus = "Master"
			audio_player.volume_db = VOLUME_MUSICA_DB
		# sem song.ogg a abertura fica só com o áudio da intro (é o normal)


func _iniciar_com_confirmacao() -> void:
	if transicionando:
		return

	call_deferred("_iniciar_com_confirmacao_async")



func _iniciar_com_confirmacao_async() -> void:
	transicionando = true

	if tween_pressione != null:
		tween_pressione.kill()
	if tween_fx != null:
		tween_fx.kill()
	if tween_audio_init != null:
		tween_audio_init.kill()

	if audio_init_player != null and audio_init_player.stream != null:
		audio_init_player.stop()
		audio_init_player.play()

	await _efeito_inicio_confirmado()

	_ir_para_jogo()



func _efeito_inicio_confirmado() -> void:
	flash_intro.visible = true
	flash_intro.modulate.a = 0.0
	flash_intro.color = Color(1, 1, 1, 1)

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(pressione, "scale", Vector2(1.18, 1.18), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.tween_property(pressione, "modulate:a", 0.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.tween_property(flash_intro, "modulate:a", 0.95, 0.12) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	await tween.finished

	var tween_saida: Tween = create_tween()
	tween_saida.tween_property(flash_intro, "modulate:a", 0.0, 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween_saida.finished


# ─────────────────────────────────────────────
#  INTRO PRINCIPAL
# ─────────────────────────────────────────────
func _tocar_intro() -> void:
	if audio_intro_player != null and audio_intro_player.stream != null:
		audio_intro_player.volume_db = VOLUME_INTRO_DB
		audio_intro_player.play()

	# Entrada limpa: o preto abre devagar sobre o vídeo e a chamada surge.
	flash_intro.visible = true
	flash_intro.color = Color.BLACK
	flash_intro.modulate.a = 1.0
	pressione.modulate.a = 0.0
	pressione.scale = Vector2(0.94, 0.94)

	var tween: Tween = create_tween()
	tween.tween_property(flash_intro, "modulate:a", 0.0, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(pressione, "modulate:a", 1.0, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(0.3)
	tween.parallel().tween_property(pressione, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.3)

	await tween.finished

	flash_intro.visible = false
	_iniciar_pisca_pressione()
	_iniciar_timer_intro()


# ─────────────────────────────────────────────
#  EFEITO GLITCH DE ENTRADA
# ─────────────────────────────────────────────
# ─────────────────────────────────────────────
#  LOOPS IDLE
# ─────────────────────────────────────────────
func _iniciar_timer_intro() -> void:
	await get_tree().create_timer(TEMPO_INTRO).timeout

	if transicionando:
		return

	# Configuração: vídeos de demonstração desligados pulam direto para o ranking.
	if not bool(get_tree().get_meta("admin_demo_ativa", true)):
		_ir_para_ranking_atrativo()
		return

	_tocar_teaser_atrativo()



func _iniciar_pisca_pressione() -> void:
	if tween_pressione != null:
		tween_pressione.kill()

	tween_pressione = create_tween()
	tween_pressione.set_loops()
	tween_pressione.tween_property(pressione, "modulate:a", 0.35, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_pressione.tween_property(pressione, "modulate:a", 1.0, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)



func _pegar_teaser_sem_repetir() -> String:
	if teasers_disponiveis.is_empty():
		teasers_disponiveis = TEASERS.duplicate()
		teasers_disponiveis.shuffle()

	var escolhido: String = teasers_disponiveis.pop_front()

	if escolhido == teaser_atual and not teasers_disponiveis.is_empty():
		teasers_disponiveis.append(escolhido)
		escolhido = teasers_disponiveis.pop_front()

	teaser_atual = escolhido
	return escolhido



func _tocar_teaser_atrativo() -> void:
	var caminho: String = _pegar_teaser_sem_repetir()

	if not ResourceLoader.exists(caminho):
		push_warning("Teaser não encontrado: " + caminho)
		_ir_para_ranking_atrativo()
		return

	if tween_pressione != null:
		tween_pressione.kill()

	if tween_fx != null:
		tween_fx.kill()

	# INSERT COIN CONTINUA APARECENDO NO TEASER
	pressione.visible = true
	pressione.modulate.a = 1.0
	pressione.scale = Vector2.ONE
	_iniciar_pisca_pressione()

	# A prévia entra por cima do vídeo inicial, que então para (um vídeo por
	# vez no decodificador).
	if video_teaser == null and video_layer != null:
		var volume: float = clampf(db_to_linear(float(Maquina.valor("audio/volume_musica"))), 0.0, 1.0)
		video_teaser = VideoNativo.new(caminho.get_basename() + ".mp4", caminho, Vector2(576, 1024), true, volume)
		video_layer.add_child(video_teaser)
		video_teaser.comecou.connect(func() -> void:
			get_tree().create_timer(0.4).timeout.connect(func() -> void:
				if video_intro != null:
					video_intro.parar()
				if fundo_vivo != null:
					fundo_vivo.visible = false
			)
		)
		video_teaser.tocar()

	_rodar_teaser_e_ir_ranking()



func _rodar_teaser_e_ir_ranking() -> void:
	await get_tree().create_timer(TEMPO_TEASER).timeout

	if transicionando:
		return

	_ir_para_ranking_atrativo()



func _ir_para_ranking_atrativo() -> void:
	# Configuração: ranking desligado na abertura recomeça a abertura.
	if not bool(get_tree().get_meta("admin_ranking_ativo", true)):
		_trocar_cena_com_saida(scene_file_path)
		return

	if cena_ranking == "":
		_mostrar_tela_inicial()
		return

	if not ResourceLoader.exists(cena_ranking):
		push_error("Cena ranking não encontrada: " + cena_ranking)
		_mostrar_tela_inicial()
		return

	get_tree().set_meta("ranking_origem", "main_atrativo")

	_ocultar_ponteiro_mouse()
	_trocar_cena_com_saida(cena_ranking)



# ─────────────────────────────────────────────
#  TRANSIÇÃO DE CENA
# ─────────────────────────────────────────────
func _ir_para_jogo() -> void:
	_trocar_cena_com_saida(cena_do_jogo)



func _ir_para_demo() -> void:
	var destino: String = cena_demo if cena_demo != "" else cena_do_jogo
	_trocar_cena_com_saida(destino)



func _trocar_cena_com_saida(caminho_cena: String) -> void:
	if caminho_cena == "":
		push_error("Caminho da cena vazio.")
		transicionando = false
		return

	if not ResourceLoader.exists(caminho_cena):
		push_error("Cena não encontrada: " + caminho_cena)
		transicionando = false
		return

	transicionando = true
	_ocultar_ponteiro_mouse()

	if tween_pressione != null:
		tween_pressione.kill()
	if tween_fx != null:
		tween_fx.kill()
	if tween_audio_intro != null:
		tween_audio_intro.kill()
	if tween_audio_bg != null:
		tween_audio_bg.kill()

	# FADE PRETO, não branco
	flash_intro.visible = true
	flash_intro.color = Color.BLACK
	flash_intro.modulate.a = 0.0

	var tween_saida: Tween = create_tween()
	tween_saida.set_parallel(true)

	tween_saida.tween_property(flash_intro, "modulate:a", 1.0, 0.28)

	if caminho_cena != cena_ranking:
		tween_saida.tween_property(pressione, "modulate:a", 0.0, 0.18)

	if audio_intro_player != null and audio_intro_player.playing:
		tween_audio_intro = create_tween()
		tween_audio_intro.tween_property(audio_intro_player, "volume_db", VOLUME_FADE_OUT_DB, TEMPO_FADE_SAIDA)

	if audio_player != null and audio_player.playing:
		tween_audio_bg = create_tween()
		tween_audio_bg.tween_property(audio_player, "volume_db", VOLUME_FADE_OUT_DB, TEMPO_FADE_SAIDA)

	await tween_saida.finished

	if audio_intro_player != null and audio_intro_player.playing:
		audio_intro_player.stop()

	if audio_player != null and audio_player.playing:
		audio_player.stop()

	_ocultar_ponteiro_mouse()

	# A tela já está preta (flash_intro): troca sem escurecer de novo.
	TransicaoGlobal.trocar_cena(caminho_cena, 0.0)



func _restaurar_main_apos_erro() -> void:
	flash_intro.visible = false
	pressione.modulate.a = 1.0

	if audio_intro_player != null and audio_intro_player.stream != null:
		audio_intro_player.volume_db = VOLUME_INTRO_DB
		audio_intro_player.play()

	_iniciar_pisca_pressione()


# ─────────────────────────────────────────────
#  RESIZE
# ─────────────────────────────────────────────
func _on_viewport_size_changed() -> void:
	call_deferred("_reajustar_tela")


func _reajustar_tela() -> void:
	_configurar_fundos()
	_reposicionar_canvas()


func _reposicionar_canvas() -> void:
	pressione.anchor_left = 0.5
	pressione.anchor_right = 0.5
	pressione.anchor_top = 1.0
	pressione.anchor_bottom = 1.0
	pressione.offset_left = -360.0
	pressione.offset_right = 360.0
	pressione.offset_top = -125.0
	pressione.offset_bottom = -35.0


# ─────────────────────────────────────────────
#  LIMPEZA
# ─────────────────────────────────────────────
func _exit_tree() -> void:
	if tween_pressione != null:
		tween_pressione.kill()
	if tween_fx != null:
		tween_fx.kill()
	if tween_audio_intro != null:
		tween_audio_intro.kill()
	if tween_audio_bg != null:
		tween_audio_bg.kill()
	if video_teaser != null:
		video_teaser.parar()
	if video_intro != null:
		video_intro.parar()

	if audio_intro_player != null and audio_intro_player.playing:
		audio_intro_player.stop()
	if audio_player != null and audio_player.playing:
		audio_player.stop()


func _evento_start(event: InputEvent) -> bool:
	if InputMap.has_action("input_start") and event.is_action_pressed("input_start"):
		return true

	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			return key.keycode == KEY_1 or key.keycode == KEY_ENTER or key.keycode == KEY_SPACE

	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_ocultar_ponteiro_mouse()



# ─────────────────────────────────────────────
#  MOUSE / MIRA
# ─────────────────────────────────────────────
func _ocultar_ponteiro_mouse() -> void:
	# O ponteiro fica sempre capturado e invisível (MiraGlobal): nada a fazer.
	pass


func _mostrar_ponteiro_mouse() -> void:
	pass


func _ao_mudar_creditos(_creditos: int) -> void:
	if pressione != null and is_instance_valid(pressione):
		pressione.text = Maquina.texto_chamada()
