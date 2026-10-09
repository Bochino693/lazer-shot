extends Control

const Pincel := preload("res://scripts/pincel.gd")
const CENA_MENU: String = "res://scenes/cenarios.tscn"
const MAX_RANKING: int = 20

const CAMINHO_MUSICA_RANKING: String = "res://songs/ranking-song.mp3"

const CENA_INICIO: String = "res://scenes/main.tscn"
const TEMPO_RANKING_ATRATIVO: float = 20.0

const RankingManagerScript := preload("res://scripts/RankingManager.gd")
var RankingManager := RankingManagerScript.new()

var modo_atrativo: bool = false
# Fundo: vídeo da abertura pelo decodificador de hardware sobre o fundo vivo
# (quadro parado animado), os dois escurecidos atrás da tabela.
var fundo_vivo: FundoVivo = null
var video_fundo: VideoNativo = null

var audio_ranking: AudioStreamPlayer = null

var dados_ranking: Array[Dictionary] = []
var modal_limpar_layer: CanvasLayer = null
var modal_limpar_root: Control = null

var botao_voltar_hover_mira: bool = false

var filtro_atual: String = "TODOS"

var filtros_box: HBoxContainer = null
var botao_todos: Button = null
var botao_deserto: Button = null
var botao_mar: Button = null
var botao_bar: Button = null
var botao_arena: Button = null

var flash_insert_layer: CanvasLayer = null
var flash_insert_rect: ColorRect = null
var transicionando_insert: bool = false

var botao_subir: Button = null
var botao_descer: Button = null

var alvo_layer: CanvasLayer = null
var alvo_overlay: Control = null
var alvo_pos: Vector2 = Vector2.ZERO
var alvo_anim_t: float = 0.0


var insert_coin_layer: CanvasLayer = null
var insert_coin_label: Label = null
var tween_insert_coin: Tween = null


var fundo: ColorRect
var painel: Panel
var scroll: ScrollContainer
var lista: VBoxContainer
var botao_voltar: Button

@export var usar_controle_xbox: bool = true
@export var velocidade_mira_xbox: float = 920.0
@export var deadzone_xbox: float = 0.18
@export var xbox_botao_tiro: int = JOY_BUTTON_RIGHT_SHOULDER

@export var velocidade_mira_mouse: float = 1.0
var mira_iniciada: bool = false

var xbox_mira_iniciada: bool = false


func _ready() -> void:
	var origem: String = "cenarios"
	if get_tree().has_meta("ranking_origem"):
		origem = str(get_tree().get_meta("ranking_origem"))

	modo_atrativo = origem == "main_atrativo"

	_iniciar_musica_ranking()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_criar_fundo()
	_criar_painel()
	_criar_titulo()
	_criar_filtros_cenarios()
	_criar_cabecalho()
	_criar_scroll()
	_criar_ranking()
	_criar_botoes_rolagem()
	_criar_botao_voltar()
	if not modo_atrativo:
		_configurar_alvo_overlay()
	else:
		alvo_layer = null
		alvo_overlay = null

	if modo_atrativo:
		if botao_voltar != null:
			botao_voltar.visible = false
			botao_voltar.disabled = true

		if botao_subir != null:
			botao_subir.visible = false
			botao_subir.disabled = true

		if botao_descer != null:
			botao_descer.visible = false
			botao_descer.disabled = true

		_criar_flash_insert_coin()
		_criar_insert_coin_atrativo()
		_auto_voltar_atrativo()


func _criar_flash_insert_coin() -> void:
	if flash_insert_layer == null:
		flash_insert_layer = CanvasLayer.new()
		flash_insert_layer.name = "FlashInsertLayer"
		flash_insert_layer.layer = 400
		add_child(flash_insert_layer)

	if flash_insert_rect == null:
		flash_insert_rect = ColorRect.new()
		flash_insert_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash_insert_rect.color = Color.WHITE
		flash_insert_rect.modulate.a = 0.0
		flash_insert_rect.visible = false
		flash_insert_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash_insert_layer.add_child(flash_insert_rect)


func _efeito_insert_coin_confirmado() -> void:
	if flash_insert_rect == null:
		_criar_flash_insert_coin()

	transicionando_insert = true

	if tween_insert_coin != null:
		tween_insert_coin.kill()

	flash_insert_rect.visible = true
	flash_insert_rect.modulate.a = 0.0
	flash_insert_rect.color = Color.WHITE

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	if insert_coin_label != null:
		tween.tween_property(insert_coin_label, "scale", Vector2(1.18, 1.18), 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		tween.tween_property(insert_coin_label, "modulate:a", 0.0, 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.tween_property(flash_insert_rect, "modulate:a", 0.95, 0.12) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	await tween.finished

	var tween_saida: Tween = create_tween()
	tween_saida.tween_property(flash_insert_rect, "modulate:a", 0.0, 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween_saida.finished



func _criar_insert_coin_atrativo() -> void:
	if insert_coin_layer == null:
		insert_coin_layer = CanvasLayer.new()
		insert_coin_layer.name = "InsertCoinLayer"
		insert_coin_layer.layer = 300
		add_child(insert_coin_layer)

	if insert_coin_label == null:
		insert_coin_label = Label.new()
		insert_coin_label.text = Maquina.texto_chamada()
		if not Maquina.creditos_mudaram.is_connected(_ao_mudar_creditos):
			Maquina.creditos_mudaram.connect(_ao_mudar_creditos)
		insert_coin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		insert_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		insert_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		Leve.font_size(insert_coin_label, "font_size", 34)
		Leve.color(insert_coin_label, "font_color", Color.WHITE)
		Leve.color(insert_coin_label, "font_outline_color", Color.BLACK)
		Leve.constant(insert_coin_label, "outline_size", 5)
		insert_coin_layer.add_child(insert_coin_label)

	var tela: Vector2 = get_viewport_rect().size
	insert_coin_label.position = Vector2(tela.x * 0.5 - 360.0, tela.y - 125.0)
	insert_coin_label.size = Vector2(720.0, 90.0)
	insert_coin_label.visible = true
	insert_coin_label.modulate.a = 1.0

	if tween_insert_coin != null:
		tween_insert_coin.kill()

	tween_insert_coin = create_tween()
	tween_insert_coin.set_loops()
	tween_insert_coin.tween_property(insert_coin_label, "modulate:a", 0.35, 0.7)
	tween_insert_coin.tween_property(insert_coin_label, "modulate:a", 1.0, 0.7)


func _auto_voltar_atrativo() -> void:
	await get_tree().create_timer(TEMPO_RANKING_ATRATIVO).timeout

	if get_tree().has_meta("ranking_origem"):
		get_tree().remove_meta("ranking_origem")

	TransicaoGlobal.trocar_cena(CENA_INICIO)



func _process(delta: float) -> void:
	if modo_atrativo:
		return

	# mira única do jogo (MiraGlobal)
	alvo_pos = MiraGlobal.pos
	mira_iniciada = true

	alvo_anim_t += delta

	if botao_voltar != null:
		var hover_agora: bool = botao_voltar.get_global_rect().has_point(alvo_pos)

		if hover_agora != botao_voltar_hover_mira:
			botao_voltar_hover_mira = hover_agora
			_animar_hover_voltar(hover_agora)

	if alvo_overlay != null:
		alvo_overlay.queue_redraw()



func _atualizar_mira_xbox(_delta: float) -> void:
	alvo_pos = MiraGlobal.pos


func _criar_fundo() -> void:
	fundo_vivo = FundoVivo.new(["init"])
	fundo_vivo.z_index = -50
	# escurecido (antes: vídeo + véu preto de 45%, duas camadas de tela cheia)
	fundo_vivo.modulate = Color(0.55, 0.55, 0.55)
	add_child(fundo_vivo)
	fundo_vivo.mostrar("init")

	video_fundo = VideoNativo.new("res://background_video/back_init.mp4", "res://background_video/back_init.ogv", Vector2(720, 1088), true, 0.0)
	video_fundo.so_hardware = true
	video_fundo.z_index = -50
	video_fundo.modulate = Color(0.55, 0.55, 0.55)
	add_child(video_fundo)
	video_fundo.comecou.connect(func() -> void:
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if fundo_vivo != null and video_fundo != null and video_fundo.esta_mostrando():
				fundo_vivo.visible = false
		)
	)
	video_fundo.tocar()


func _evento_start(event: InputEvent) -> bool:
	if InputMap.has_action("input_start") and event.is_action_pressed("input_start"):
		return true

	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			return key.keycode == KEY_1 or key.keycode == KEY_ENTER or key.keycode == KEY_SPACE

	return false


func _iniciar_jogo_pelo_insert_coin() -> void:
	if not modo_atrativo:
		return

	if transicionando_insert:
		return

	# Modo crédito: só entra no jogo se houver crédito (desconta aqui).
	if not Maquina.cobrar():
		return

	if get_tree().has_meta("ranking_origem"):
		get_tree().remove_meta("ranking_origem")


	await _efeito_insert_coin_confirmado()

	if ResourceLoader.exists(CENA_MENU):
		TransicaoGlobal.trocar_cena(CENA_MENU)


func _criar_painel() -> void:
	painel = Panel.new()
	painel.position = Vector2(25, 25)
	painel.size = get_viewport_rect().size - Vector2(50, 50)
	add_child(painel)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.0, 0.0, 0.0, 0.78)
	estilo.border_color = Color(1.0, 0.02, 0.02, 0.95)
	estilo.border_width_left = 4
	estilo.border_width_top = 4
	estilo.border_width_right = 4
	estilo.border_width_bottom = 4
	estilo.corner_radius_top_left = 32
	estilo.corner_radius_top_right = 32
	estilo.corner_radius_bottom_left = 32
	estilo.corner_radius_bottom_right = 32
	estilo.shadow_color = Color(1.0, 0.0, 0.0, 0.26)
	estilo.shadow_size = 30
	estilo.shadow_offset = Vector2(0, 10)
	Leve.stylebox(painel, "panel", estilo)


func _criar_titulo() -> void:
	var titulo := Label.new()
	titulo.text = "🏆 RANKING DOS 20 MELHORES"
	titulo.position = Vector2(0, 16)
	titulo.size = Vector2(painel.size.x, 58)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(titulo, "font_size", 38)
	Leve.color(titulo, "font_color", Color.WHITE)
	Leve.color(titulo, "font_outline_color", Color.BLACK)
	Leve.constant(titulo, "outline_size", 8)
	painel.add_child(titulo)


func _criar_cabecalho() -> void:
	var cab := HBoxContainer.new()
	cab.position = Vector2(26, 148)
	cab.size = Vector2(painel.size.x - 52, 42)
	Leve.constant(cab, "separation", 0)
	painel.add_child(cab)

	var textos := ["POS", "PLAYER", "CENÁRIO", "MODO", "PONTOS", "ACERTO"]
	var larguras := [75, 225, 165, 120, 155, 115]

	for i in range(textos.size()):
		var lbl := Label.new()
		lbl.text = textos[i]
		lbl.custom_minimum_size = Vector2(larguras[i], 40)
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.clip_text = true
		Leve.font_size(lbl, "font_size", 19)
		Leve.color(lbl, "font_color", Color(1.0, 0.05, 0.05))
		Leve.color(lbl, "font_outline_color", Color.BLACK)
		Leve.constant(lbl, "outline_size", 4)
		cab.add_child(lbl)



func _criar_scroll() -> void:
	scroll = ScrollContainer.new()
	scroll.position = Vector2(26, 188)

	# menos espaço morto, mas ainda protegendo o botão
	var margem_botao: float = 82.0

	scroll.size = Vector2(
		painel.size.x - 52,
		painel.size.y - scroll.position.y - margem_botao
	)

	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	painel.add_child(scroll)

	lista = VBoxContainer.new()
	lista.custom_minimum_size = Vector2(scroll.size.x - 12, 0)
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Leve.constant(lista, "separation", 8)
	scroll.add_child(lista)



func _normalizar_cenario(valor: String) -> String:
	var c := valor.strip_edges().to_upper()

	if c.contains("DESERTO") or c.contains("SAGRADO"):
		return "DESERTO"

	if c.contains("MAR") or c.contains("FUNDO"):
		return "MAR"

	if c.contains("BAR") or c.contains("FAROESTE"):
		return "BAR"

	if c.contains("ARENA") or c.contains("LAZER"):
		return "ARENA"

	return c



func _criar_ranking() -> void:
	for child in lista.get_children():
		child.queue_free()

	var todos_dados: Array = RankingManager.obter_ranking()
	dados_ranking.clear()

	for item in todos_dados:
		var dados := item as Dictionary
		var cenario_salvo := str(dados.get("cenario", "GERAL"))
		var cenario_normalizado := _normalizar_cenario(cenario_salvo)

		if filtro_atual == "TODOS" or cenario_normalizado == filtro_atual:
			dados_ranking.append(dados)

	if dados_ranking.is_empty():
		_criar_lista_vazia()
		return

	for i in range(min(MAX_RANKING, dados_ranking.size())):
		var dados := dados_ranking[i]
		var cenario_original := str(dados.get("cenario", "GERAL"))

		var linha := _criar_linha_ranking(
			i + 1,
			str(dados.get("nome", "PLAYER")),
			cenario_original,
			str(dados.get("modo", "FACIL")),
			int(dados.get("pontos", 0)),
			int(dados.get("precisao", 0))
		)
		lista.add_child(linha)
		
	await get_tree().process_frame
	_atualizar_botoes_rolagem()



func _criar_filtros_cenarios() -> void:
	filtros_box = HBoxContainer.new()
	filtros_box.position = Vector2(24, 82)
	filtros_box.size = Vector2(painel.size.x - 48, 54)
	filtros_box.alignment = BoxContainer.ALIGNMENT_CENTER
	Leve.constant(filtros_box, "separation", 8)
	painel.add_child(filtros_box)

	botao_todos = _criar_botao_filtro("TODOS")
	botao_deserto = _criar_botao_filtro("DESERTO")
	botao_mar = _criar_botao_filtro("MAR")
	botao_bar = _criar_botao_filtro("BAR")
	botao_arena = _criar_botao_filtro("ARENA")

	filtros_box.add_child(botao_todos)
	filtros_box.add_child(botao_deserto)
	filtros_box.add_child(botao_mar)
	filtros_box.add_child(botao_bar)
	filtros_box.add_child(botao_arena)

	_atualizar_visual_filtros()


func _criar_botao_filtro(texto: String) -> Button:
	var btn := Button.new()
	btn.text = texto
	btn.custom_minimum_size = Vector2(142, 46)
	btn.focus_mode = Control.FOCUS_NONE
	Leve.font_size(btn, "font_size", 18)

	btn.pressed.connect(func():
		filtro_atual = texto
		if scroll != null:
			scroll.scroll_vertical = 0
		_criar_ranking()
		_atualizar_visual_filtros()
	)

	return btn



func _atualizar_visual_filtros() -> void:
	var botoes: Array[Button] = [botao_todos, botao_deserto, botao_mar, botao_bar, botao_arena]

	for btn in botoes:
		if btn == null:
			continue

		var estilo := StyleBoxFlat.new()
		estilo.corner_radius_top_left = 18
		estilo.corner_radius_top_right = 18
		estilo.corner_radius_bottom_left = 18
		estilo.corner_radius_bottom_right = 18
		estilo.border_width_left = 2
		estilo.border_width_top = 2
		estilo.border_width_right = 2
		estilo.border_width_bottom = 2

		if btn.text == filtro_atual:
			estilo.bg_color = Color(1.0, 0.02, 0.02, 1.0)
			estilo.border_color = Color.WHITE
		else:
			estilo.bg_color = Color(0.0, 0.0, 0.0, 0.88)
			estilo.border_color = Color(1.0, 0.02, 0.02, 0.85)

		Leve.color(btn, "font_color", Color.WHITE)
		Leve.color(btn, "font_outline_color", Color.BLACK)
		Leve.constant(btn, "outline_size", 4)
		Leve.stylebox(btn, "normal", estilo)
		Leve.stylebox(btn, "hover", estilo)
		Leve.stylebox(btn, "pressed", estilo)



func _criar_botoes_rolagem() -> void:
	botao_subir = Button.new()
	botao_subir.text = "▲"
	botao_subir.position = Vector2(scroll.position.x + scroll.size.x - 68, scroll.position.y + 10)
	botao_subir.size = Vector2(54, 54)
	botao_subir.focus_mode = Control.FOCUS_NONE
	painel.add_child(botao_subir)

	botao_descer = Button.new()
	botao_descer.text = "▼"
	botao_descer.position = Vector2(scroll.position.x + scroll.size.x - 68, scroll.position.y + scroll.size.y - 64)
	botao_descer.size = Vector2(54, 54)
	botao_descer.focus_mode = Control.FOCUS_NONE
	painel.add_child(botao_descer)

	_estilizar_botao_rolagem(botao_subir)
	_estilizar_botao_rolagem(botao_descer)

	botao_subir.pressed.connect(func():
		scroll.scroll_vertical = max(0, scroll.scroll_vertical - 220)
		_atualizar_botoes_rolagem()
	)

	botao_descer.pressed.connect(func():
		scroll.scroll_vertical += 220
		_atualizar_botoes_rolagem()
	)

	_atualizar_botoes_rolagem()


func _atualizar_botoes_rolagem() -> void:
	if botao_subir == null or botao_descer == null or scroll == null or lista == null:
		return

	var altura_conteudo: float = lista.get_combined_minimum_size().y
	var precisa_rolar: bool = altura_conteudo > scroll.size.y

	botao_subir.visible = precisa_rolar and scroll.scroll_vertical > 0
	botao_descer.visible = precisa_rolar


func _estilizar_botao_rolagem(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.88, 0.08, 0.06, 0.96)
	normal.corner_radius_top_left = 20
	normal.corner_radius_top_right = 20
	normal.corner_radius_bottom_left = 20
	normal.corner_radius_bottom_right = 20

	Leve.stylebox(btn, "normal", normal)
	Leve.stylebox(btn, "hover", normal)
	Leve.stylebox(btn, "pressed", normal)
	Leve.font_size(btn, "font_size", 20)
	Leve.color(btn, "font_color", Color.WHITE)



func _configurar_alvo_overlay() -> void:
	alvo_layer = CanvasLayer.new()
	alvo_layer.name = "AlvoLayer"
	alvo_layer.layer = 100
	add_child(alvo_layer)

	alvo_overlay = Control.new()
	alvo_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	alvo_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alvo_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	alvo_layer.add_child(alvo_overlay)
	alvo_overlay.draw.connect(_desenhar_alvo_overlay)



func _desenhar_alvo_overlay() -> void:
	var pulso := 1.0 + sin(alvo_anim_t * 6.0) * 0.08
	var raio := 18.0 * pulso

	Pincel.mira_inicio(alvo_overlay, alvo_pos)
	Pincel.anel(alvo_overlay, alvo_pos, raio, 2.8, Color(1.0, 0.12, 0.08))
	Pincel.anel(alvo_overlay, alvo_pos, raio * 0.52, 1.4, Color.WHITE)
	Pincel.circulo(alvo_overlay, alvo_pos, 3.4 * pulso, Color(1.0, 0.12, 0.08))

	var l := 13.0 * pulso
	var e := 7.0 * pulso
	Pincel.linha(alvo_overlay, alvo_pos + Vector2(-l - e, 0), alvo_pos + Vector2(-e, 0), Color.WHITE, 2.2)
	Pincel.linha(alvo_overlay, alvo_pos + Vector2(e, 0), alvo_pos + Vector2(l + e, 0), Color.WHITE, 2.2)
	Pincel.linha(alvo_overlay, alvo_pos + Vector2(0, -l - e), alvo_pos + Vector2(0, -e), Color.WHITE, 2.2)
	Pincel.linha(alvo_overlay, alvo_pos + Vector2(0, e), alvo_pos + Vector2(0, l + e), Color.WHITE, 2.2)
	Pincel.mira_fim(alvo_overlay)
func _criar_linha_ranking(posicao: int, nome: String, cenario: String, modo: String, pontos: int, precisao: int) -> Panel:
	var linha := Panel.new()

	# um pouco maior que antes
	linha.custom_minimum_size = Vector2(scroll.size.x - 20, 62)

	var estilo := StyleBoxFlat.new()

	if posicao == 1:
		estilo.bg_color = Color(0.35, 0.0, 0.0, 0.58)
		estilo.border_color = Color(1.0, 0.02, 0.02, 1.0)
	elif posicao == 2:
		estilo.bg_color = Color(0.12, 0.12, 0.12, 0.70)
		estilo.border_color = Color.WHITE
	elif posicao == 3:
		estilo.bg_color = Color(0.22, 0.0, 0.0, 0.50)
		estilo.border_color = Color(1.0, 0.20, 0.18, 0.95)
	else:
		estilo.bg_color = Color(0.0, 0.0, 0.0, 0.72)
		estilo.border_color = Color(1.0, 0.02, 0.02, 0.30)

	estilo.border_width_left = 2
	estilo.border_width_top = 2
	estilo.border_width_right = 2
	estilo.border_width_bottom = 2
	estilo.corner_radius_top_left = 18
	estilo.corner_radius_top_right = 18
	estilo.corner_radius_bottom_left = 18
	estilo.corner_radius_bottom_right = 18

	Leve.stylebox(linha, "panel", estilo)

	var hbox := HBoxContainer.new()
	hbox.position = Vector2(8, 7)
	hbox.size = Vector2(linha.custom_minimum_size.x - 16, 48)
	Leve.constant(hbox, "separation", 0)
	linha.add_child(hbox)

	var medalha := ""

	if posicao == 1:
		medalha = "🥇"
	elif posicao == 2:
		medalha = "🥈"
	elif posicao == 3:
		medalha = "🥉"

	var nome_final: String = nome.strip_edges().to_upper().left(9)
	if nome_final == "":
		nome_final = "PLAYER"

	var cenario_final: String = _normalizar_cenario(cenario).left(8)

	var modo_final: String = modo.strip_edges().to_upper()
	if modo_final == "DIFICIL" or modo_final == "DIFÍCIL":
		modo_final = "DIFICIL"
	else:
		modo_final = "FACIL"

	var cor_modo: Color = Color(0.35, 1.0, 0.45)
	if modo_final == "DIFICIL":
		cor_modo = Color(1.0, 0.20, 0.15)

	_adicionar_campo(hbox, medalha + " " + str(posicao), 75, 18, Color.WHITE)
	_adicionar_campo(hbox, nome_final, 225, 20, Color.WHITE)
	_adicionar_campo(hbox, cenario_final, 165, 18, Color(0.82, 0.90, 1.0))
	_adicionar_campo(hbox, modo_final, 120, 17, cor_modo)
	_adicionar_campo(hbox, str(pontos), 155, 21, Color(1.0, 0.05, 0.05))
	_adicionar_campo(hbox, str(precisao) + "%", 115, 18, Color.WHITE)

	return linha



func _adicionar_campo(pai: HBoxContainer, texto: String, largura: float, fonte: int, cor: Color) -> void:
	var lbl := Label.new()
	lbl.text = texto

	# mais altura visual
	lbl.custom_minimum_size = Vector2(largura, 48)

	lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.clip_text = true
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	Leve.font_size(lbl, "font_size", fonte)
	Leve.color(lbl, "font_color", cor)
	Leve.color(lbl, "font_outline_color", Color.BLACK)
	Leve.constant(lbl, "outline_size", 4)

	pai.add_child(lbl)


func _criar_botao_voltar() -> void:
	botao_voltar = Button.new()
	botao_voltar.text = "VOLTAR AOS CENÁRIOS"

	botao_voltar.position = Vector2(
		painel.size.x * 0.5 - 190,
		painel.size.y - 68
	)

	botao_voltar.size = Vector2(380, 60)
	botao_voltar.focus_mode = Control.FOCUS_NONE
	botao_voltar.pivot_offset = botao_voltar.size * 0.5
	painel.add_child(botao_voltar)

	# =========================
	# ESTILO NORMAL
	# =========================
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.96)
	normal.border_color = Color(1.0, 0.02, 0.02, 0.95)
	normal.border_width_left = 3
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 3
	normal.corner_radius_top_left = 28
	normal.corner_radius_top_right = 28
	normal.corner_radius_bottom_left = 28
	normal.corner_radius_bottom_right = 28
	normal.shadow_color = Color(1.0, 0.0, 0.0, 0.18)
	normal.shadow_size = 12

	# =========================
	# ESTILO HOVER (NEON)
	# =========================
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.0, 0.0, 1.0)
	hover.border_color = Color.WHITE
	hover.border_width_left = 4
	hover.border_width_top = 4
	hover.border_width_right = 4
	hover.border_width_bottom = 4
	hover.corner_radius_top_left = 28
	hover.corner_radius_top_right = 28
	hover.corner_radius_bottom_left = 28
	hover.corner_radius_bottom_right = 28
	hover.shadow_color = Color(1.0, 0.0, 0.0, 0.72)
	hover.shadow_size = 38

	Leve.stylebox(botao_voltar, "normal", normal)
	Leve.stylebox(botao_voltar, "hover", hover)
	Leve.stylebox(botao_voltar, "pressed", hover)

	Leve.font_size(botao_voltar, "font_size", 24)
	Leve.color(botao_voltar, "font_color", Color.WHITE)
	Leve.color(botao_voltar, "font_hover_color", Color.WHITE)
	Leve.color(botao_voltar, "font_pressed_color", Color.WHITE)
	Leve.color(botao_voltar, "font_outline_color", Color.BLACK)
	Leve.constant(botao_voltar, "outline_size", 5)

	# Hover mouse
	botao_voltar.mouse_entered.connect(func():
		_animar_hover_voltar(true)
	)

	botao_voltar.mouse_exited.connect(func():
		_animar_hover_voltar(false)
	)

	botao_voltar.pressed.connect(_voltar_menu)



func _animar_hover_voltar(hover: bool) -> void:
	if botao_voltar == null:
		return

	var estilo := StyleBoxFlat.new()
	estilo.corner_radius_top_left = 28
	estilo.corner_radius_top_right = 28
	estilo.corner_radius_bottom_left = 28
	estilo.corner_radius_bottom_right = 28
	estilo.border_width_left = 4
	estilo.border_width_top = 4
	estilo.border_width_right = 4
	estilo.border_width_bottom = 4

	if hover:
		estilo.bg_color = Color(0.95, 0.02, 0.02, 1.0)
		estilo.border_color = Color.WHITE
		estilo.shadow_color = Color(1.0, 0.0, 0.0, 0.85)
		estilo.shadow_size = 42

		Leve.color(botao_voltar, "font_color", Color.WHITE)
	else:
		estilo.bg_color = Color(0.0, 0.0, 0.0, 0.96)
		estilo.border_color = Color(1.0, 0.02, 0.02, 0.95)
		estilo.shadow_color = Color(1.0, 0.0, 0.0, 0.18)
		estilo.shadow_size = 12

		Leve.color(botao_voltar, "font_color", Color.WHITE)

	Leve.stylebox(botao_voltar, "normal", estilo)
	Leve.stylebox(botao_voltar, "hover", estilo)
	Leve.stylebox(botao_voltar, "pressed", estilo)

	var tween := create_tween()
	tween.set_parallel(true)

	if hover:
		tween.tween_property(botao_voltar, "scale", Vector2(1.08, 1.08), 0.12)
	else:
		tween.tween_property(botao_voltar, "scale", Vector2.ONE, 0.12)



func _input(event: InputEvent) -> void:
	if modo_atrativo:
		if _evento_start(event):
			_iniciar_jogo_pelo_insert_coin()
			return

		if event is InputEventJoypadButton:
			var jb_atrativo := event as InputEventJoypadButton
			if jb_atrativo.pressed and jb_atrativo.button_index == xbox_botao_tiro:
				_iniciar_jogo_pelo_insert_coin()
				return

		return

	if event is InputEventMouseMotion:
		# o movimento já entra na mira única (MiraGlobal)
		return

	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton

		if not jb.pressed:
			return

		print("DEBUG XBOX RANKING:", jb.button_index)

		if jb.button_index == xbox_botao_tiro:
			_tentar_acao_por_tiro(alvo_pos)
			return

	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton

		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_tentar_acao_por_tiro(alvo_pos)
			return

	elif event is InputEventScreenTouch:
		var toque := event as InputEventScreenTouch

		if toque.pressed:
			_tentar_acao_por_tiro(alvo_pos)
			return

	elif event is InputEventKey:
		var key := event as InputEventKey

		if key.pressed and not key.echo and key.keycode == KEY_F9:
			_abrir_modal_limpar_ranking()
			return



func _tentar_acao_por_tiro(pos: Vector2) -> void:
	var botoes: Array[Button] = [
		botao_todos,
		botao_deserto,
		botao_mar,
		botao_bar,
		botao_arena,
		botao_subir,
		botao_descer,
		botao_voltar
	]

	for btn in botoes:
		if btn != null and btn.get_global_rect().has_point(pos):
			btn.emit_signal("pressed")
			return



func _abrir_modal_limpar_ranking() -> void:
	if modal_limpar_layer != null:
		return

	modal_limpar_layer = CanvasLayer.new()
	modal_limpar_layer.layer = 200
	add_child(modal_limpar_layer)

	modal_limpar_root = Control.new()
	modal_limpar_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_limpar_layer.add_child(modal_limpar_root)

	var escuro := ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.72)
	escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_limpar_root.add_child(escuro)

	var modal := Panel.new()
	modal.size = Vector2(620, 310)
	modal.position = get_viewport_rect().size * 0.5 - modal.size * 0.5
	modal_limpar_root.add_child(modal)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.035, 0.04, 0.065, 0.98)
	estilo.border_color = Color(1.0, 0.20, 0.15, 1.0)
	estilo.border_width_left = 3
	estilo.border_width_top = 3
	estilo.border_width_right = 3
	estilo.border_width_bottom = 3
	estilo.corner_radius_top_left = 28
	estilo.corner_radius_top_right = 28
	estilo.corner_radius_bottom_left = 28
	estilo.corner_radius_bottom_right = 28
	Leve.stylebox(modal, "panel", estilo)

	var titulo := Label.new()
	titulo.text = "⚠ LIMPAR RANKING?"
	titulo.position = Vector2(20, 28)
	titulo.size = Vector2(580, 58)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(titulo, "font_size", 36)
	Leve.color(titulo, "font_color", Color(1.0, 0.25, 0.18))
	Leve.color(titulo, "font_outline_color", Color.BLACK)
	Leve.constant(titulo, "outline_size", 7)
	modal.add_child(titulo)

	var msg := Label.new()
	msg.text = "Essa ação apaga todos os 20 melhores jogadores salvos.\nDeseja realmente continuar?"
	msg.position = Vector2(40, 100)
	msg.size = Vector2(540, 80)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(msg, "font_size", 23)
	Leve.color(msg, "font_color", Color.WHITE)
	Leve.color(msg, "font_outline_color", Color.BLACK)
	Leve.constant(msg, "outline_size", 5)
	modal.add_child(msg)

	var btn_sim := Button.new()
	btn_sim.text = "SIM, LIMPAR"
	btn_sim.position = Vector2(70, 215)
	btn_sim.size = Vector2(210, 58)
	Leve.font_size(btn_sim, "font_size", 22)
	modal.add_child(btn_sim)

	var btn_nao := Button.new()
	btn_nao.text = "CANCELAR"
	btn_nao.position = Vector2(340, 215)
	btn_nao.size = Vector2(210, 58)
	Leve.font_size(btn_nao, "font_size", 22)
	modal.add_child(btn_nao)

	btn_sim.pressed.connect(_confirmar_limpar_ranking)
	btn_nao.pressed.connect(_fechar_modal_limpar_ranking)


func _confirmar_limpar_ranking() -> void:
	RankingManager.limpar()
	_fechar_modal_limpar_ranking()
	_criar_ranking()


func _fechar_modal_limpar_ranking() -> void:
	if modal_limpar_layer != null:
		modal_limpar_layer.queue_free()
		modal_limpar_layer = null
		modal_limpar_root = null


func _criar_lista_vazia() -> void:
	var painel_vazio := Panel.new()
	painel_vazio.custom_minimum_size = Vector2(scroll.size.x - 24, 190)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.08, 0.09, 0.13, 0.82)
	estilo.border_color = Color(1.0, 0.78, 0.18, 0.35)
	estilo.border_width_left = 2
	estilo.border_width_top = 2
	estilo.border_width_right = 2
	estilo.border_width_bottom = 2
	estilo.corner_radius_top_left = 22
	estilo.corner_radius_top_right = 22
	estilo.corner_radius_bottom_left = 22
	estilo.corner_radius_bottom_right = 22
	Leve.stylebox(painel_vazio, "panel", estilo)

	var lbl := Label.new()
	lbl.text = "🏆 RANKING VAZIO\n\nJogue uma partida para registrar os melhores jogadores."
	lbl.position = Vector2(20, 20)
	lbl.size = Vector2(painel_vazio.custom_minimum_size.x - 40, 150)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Leve.font_size(lbl, "font_size", 28)
	Leve.color(lbl, "font_color", Color.WHITE)
	Leve.color(lbl, "font_outline_color", Color.BLACK)
	Leve.constant(lbl, "outline_size", 6)
	painel_vazio.add_child(lbl)

	lista.add_child(painel_vazio)
	
	await get_tree().process_frame
	_atualizar_botoes_rolagem()


func _voltar_menu() -> void:
	if ResourceLoader.exists(CENA_MENU):
		TransicaoGlobal.trocar_cena(CENA_MENU)


func _iniciar_musica_ranking() -> void:
	if audio_ranking == null:
		audio_ranking = AudioStreamPlayer.new()
		audio_ranking.name = "AudioRanking"
		add_child(audio_ranking)
		
	audio_ranking.bus = "Master"
	audio_ranking.volume_db = 5.0
	
	if ResourceLoader.exists(CAMINHO_MUSICA_RANKING):
		audio_ranking.stream = load(CAMINHO_MUSICA_RANKING)
		
		if not audio_ranking.finished.is_connected(_reiniciar_musica_ranking):
			audio_ranking.finished.connect(_reiniciar_musica_ranking)
			
		audio_ranking.play()


func _reiniciar_musica_ranking() -> void:
	if audio_ranking != null:
		audio_ranking.play()


func _ao_mudar_creditos(_creditos: int) -> void:
	if insert_coin_label != null and is_instance_valid(insert_coin_label):
		insert_coin_label.text = Maquina.texto_chamada()
