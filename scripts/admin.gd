extends Control

const CONFIG_PATH: String = "user://config_admin.cfg"

@export_file("*.tscn") var cena_voltar: String = "res://scenes/main.tscn"

const PADRAO_TEMPO_PARTIDA: int = 120
const PADRAO_TEMPO_MODAL_FINAL: int = 21
const PADRAO_TEMPO_RANKING_NOME: int = 50
const PADRAO_TEMPO_INTRO_MAIN: int = 40
const PADRAO_TEMPO_TEASER: int = 20
const PADRAO_VOLUME_MUSICA: float = -5.0
const PADRAO_VOLUME_FX: float = 0.0
const PADRAO_DEMO_ATIVA: bool = true
const PADRAO_RANKING_ATIVO: bool = true
const PADRAO_DIFICULDADE: String = "facil"
const PADRAO_IDIOMA: String = "pt_br"

var cfg := ConfigFile.new()

var tempo_partida: int = PADRAO_TEMPO_PARTIDA
var tempo_modal_final: int = PADRAO_TEMPO_MODAL_FINAL
var tempo_ranking_nome: int = PADRAO_TEMPO_RANKING_NOME
var tempo_intro_main: int = PADRAO_TEMPO_INTRO_MAIN
var tempo_teaser: int = PADRAO_TEMPO_TEASER
var volume_musica: float = PADRAO_VOLUME_MUSICA
var volume_fx: float = PADRAO_VOLUME_FX
var demo_ativa: bool = PADRAO_DEMO_ATIVA
var ranking_ativo: bool = PADRAO_RANKING_ATIVO
var dificuldade_padrao: String = PADRAO_DIFICULDADE
var idioma: String = PADRAO_IDIOMA

var root_panel: Panel
var titulo: Label
var grid: GridContainer
var status_label: Label
var toast_label: Label
var toast_tween: Tween = null

var campo_tempo_partida: SpinBox
var campo_tempo_modal_final: SpinBox
var campo_tempo_ranking_nome: SpinBox
var campo_tempo_intro_main: SpinBox
var campo_tempo_teaser: SpinBox
var campo_volume_musica: SpinBox
var campo_volume_fx: SpinBox
var campo_demo_ativa: CheckButton
var campo_ranking_ativo: CheckButton
var campo_dificuldade: OptionButton
var campo_idioma: OptionButton


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_carregar_config()
	_criar_interface()
	_aplicar_config_global()
	_atualizar_status()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_ESCAPE or key.keycode == KEY_F10:
				_voltar_main()


func _carregar_config() -> void:
	var err := cfg.load(CONFIG_PATH)

	if err != OK:
		_salvar_config_padrao()
		return

	tempo_partida = int(cfg.get_value("jogo", "tempo_partida", PADRAO_TEMPO_PARTIDA))
	tempo_modal_final = int(cfg.get_value("jogo", "tempo_modal_final", PADRAO_TEMPO_MODAL_FINAL))
	tempo_ranking_nome = int(cfg.get_value("ranking", "tempo_nome", PADRAO_TEMPO_RANKING_NOME))
	tempo_intro_main = int(cfg.get_value("main", "tempo_intro", PADRAO_TEMPO_INTRO_MAIN))
	tempo_teaser = int(cfg.get_value("main", "tempo_teaser", PADRAO_TEMPO_TEASER))
	volume_musica = float(cfg.get_value("audio", "volume_musica", PADRAO_VOLUME_MUSICA))
	volume_fx = float(cfg.get_value("audio", "volume_fx", PADRAO_VOLUME_FX))
	demo_ativa = bool(cfg.get_value("main", "demo_ativa", PADRAO_DEMO_ATIVA))
	ranking_ativo = bool(cfg.get_value("ranking", "ranking_ativo", PADRAO_RANKING_ATIVO))
	dificuldade_padrao = str(cfg.get_value("jogo", "dificuldade_padrao", PADRAO_DIFICULDADE))
	idioma = str(cfg.get_value("sistema", "idioma", PADRAO_IDIOMA))


func _salvar_config_padrao() -> void:
	cfg.set_value("jogo", "tempo_partida", tempo_partida)
	cfg.set_value("jogo", "tempo_modal_final", tempo_modal_final)
	cfg.set_value("jogo", "dificuldade_padrao", dificuldade_padrao)

	cfg.set_value("ranking", "tempo_nome", tempo_ranking_nome)
	cfg.set_value("ranking", "ranking_ativo", ranking_ativo)

	cfg.set_value("main", "tempo_intro", tempo_intro_main)
	cfg.set_value("main", "tempo_teaser", tempo_teaser)
	cfg.set_value("main", "demo_ativa", demo_ativa)

	cfg.set_value("audio", "volume_musica", volume_musica)
	cfg.set_value("audio", "volume_fx", volume_fx)

	cfg.set_value("sistema", "idioma", idioma)

	cfg.save(CONFIG_PATH)


func _ler_valor_spin(spin: SpinBox, padrao: float) -> float:
	if spin == null:
		return padrao

	var line := spin.get_line_edit()
	if line != null:
		var texto := line.text.strip_edges()
		if texto != "":
			spin.value = clamp(texto.to_float(), spin.min_value, spin.max_value)

	spin.release_focus()
	return spin.value


func _ler_campos_da_tela() -> void:
	tempo_partida = int(_ler_valor_spin(campo_tempo_partida, tempo_partida))
	tempo_modal_final = int(_ler_valor_spin(campo_tempo_modal_final, tempo_modal_final))
	tempo_ranking_nome = int(_ler_valor_spin(campo_tempo_ranking_nome, tempo_ranking_nome))
	tempo_intro_main = int(_ler_valor_spin(campo_tempo_intro_main, tempo_intro_main))
	tempo_teaser = int(_ler_valor_spin(campo_tempo_teaser, tempo_teaser))

	volume_musica = float(_ler_valor_spin(campo_volume_musica, volume_musica))
	volume_fx = float(_ler_valor_spin(campo_volume_fx, volume_fx))

	if campo_demo_ativa != null:
		demo_ativa = campo_demo_ativa.button_pressed

	if campo_ranking_ativo != null:
		ranking_ativo = campo_ranking_ativo.button_pressed

	if campo_dificuldade != null:
		dificuldade_padrao = "dificil" if campo_dificuldade.selected == 1 else "facil"

	if campo_idioma != null:
		match campo_idioma.selected:
			1:
				idioma = "en"
			2:
				idioma = "es"
			_:
				idioma = "pt_br"


func _salvar_config() -> void:
	_ler_campos_da_tela()

	cfg.set_value("jogo", "tempo_partida", tempo_partida)
	cfg.set_value("jogo", "tempo_modal_final", tempo_modal_final)
	cfg.set_value("jogo", "dificuldade_padrao", dificuldade_padrao)

	cfg.set_value("ranking", "tempo_nome", tempo_ranking_nome)
	cfg.set_value("ranking", "ranking_ativo", ranking_ativo)

	cfg.set_value("main", "tempo_intro", tempo_intro_main)
	cfg.set_value("main", "tempo_teaser", tempo_teaser)
	cfg.set_value("main", "demo_ativa", demo_ativa)

	cfg.set_value("audio", "volume_musica", volume_musica)
	cfg.set_value("audio", "volume_fx", volume_fx)

	cfg.set_value("sistema", "idioma", idioma)

	var err := cfg.save(CONFIG_PATH)
	
	print("ADMIN SALVO EM: ", ProjectSettings.globalize_path(CONFIG_PATH))
	print("TEMPO PARTIDA SALVO: ", tempo_partida)
	print("TEMPO MODAL FINAL SALVO: ", tempo_modal_final)

	if err != OK:
		_mostrar_toast("ERRO AO SALVAR CONFIGURAÇÕES!")
		push_error("Erro ao salvar config_admin.cfg: %s" % err)
		return

	_aplicar_config_global()
	_atualizar_status()
	_mostrar_toast("CONFIGURAÇÕES SALVAS COM SUCESSO!")


func _aplicar_config_global() -> void:
	get_tree().set_meta("admin_tempo_partida", tempo_partida)
	get_tree().set_meta("admin_tempo_modal_final", tempo_modal_final)
	get_tree().set_meta("admin_tempo_ranking_nome", tempo_ranking_nome)
	get_tree().set_meta("admin_tempo_intro_main", tempo_intro_main)
	get_tree().set_meta("admin_tempo_teaser", tempo_teaser)
	get_tree().set_meta("admin_volume_musica", volume_musica)
	get_tree().set_meta("admin_volume_fx", volume_fx)
	get_tree().set_meta("admin_demo_ativa", demo_ativa)
	get_tree().set_meta("admin_ranking_ativo", ranking_ativo)
	get_tree().set_meta("modo_dificuldade", dificuldade_padrao)
	get_tree().set_meta("admin_idioma", idioma)


func _criar_interface() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.005, 0.005, 0.008, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	root_panel = Panel.new()
	root_panel.size = Vector2(980, 1260)
	root_panel.position = (get_viewport_rect().size - root_panel.size) * 0.5
	add_child(root_panel)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.02, 0.02, 0.03, 0.98)
	estilo.border_color = Color(1.0, 0.02, 0.02, 1.0)
	estilo.border_width_left = 4
	estilo.border_width_top = 4
	estilo.border_width_right = 4
	estilo.border_width_bottom = 4
	estilo.corner_radius_top_left = 28
	estilo.corner_radius_top_right = 28
	estilo.corner_radius_bottom_left = 28
	estilo.corner_radius_bottom_right = 28
	root_panel.add_theme_stylebox_override("panel", estilo)

	titulo = Label.new()
	titulo.text = "ADMINISTRAÇÃO DO JOGO"
	titulo.position = Vector2(40, 30)
	titulo.size = Vector2(900, 70)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 44)
	titulo.add_theme_color_override("font_color", Color.WHITE)
	titulo.add_theme_color_override("font_outline_color", Color(0.9, 0.0, 0.0))
	titulo.add_theme_constant_override("outline_size", 7)
	root_panel.add_child(titulo)

	grid = GridContainer.new()
	grid.columns = 1
	grid.position = Vector2(60, 130)
	grid.size = Vector2(860, 890)
	grid.add_theme_constant_override("v_separation", 15)
	root_panel.add_child(grid)

	campo_tempo_partida = _add_linha_numero("TEMPO DA PARTIDA", tempo_partida, 30, 300, 10, func(v): tempo_partida = v)
	campo_tempo_modal_final = _add_linha_numero("TEMPO MODAL FINAL", tempo_modal_final, 5, 60, 1, func(v): tempo_modal_final = v)
	campo_tempo_ranking_nome = _add_linha_numero("TEMPO PARA NOME NO RANKING", tempo_ranking_nome, 10, 120, 5, func(v): tempo_ranking_nome = v)
	campo_tempo_intro_main = _add_linha_numero("TEMPO INTRO DA MAIN", tempo_intro_main, 5, 120, 5, func(v): tempo_intro_main = v)
	campo_tempo_teaser = _add_linha_numero("TEMPO DE CADA TEASER", tempo_teaser, 5, 60, 5, func(v): tempo_teaser = v)
	campo_volume_musica = _add_linha_float("VOLUME MÚSICA DB", volume_musica, -40.0, 10.0, 1.0, func(v): volume_musica = v)
	campo_volume_fx = _add_linha_float("VOLUME EFEITOS DB", volume_fx, -40.0, 15.0, 1.0, func(v): volume_fx = v)
	campo_demo_ativa = _add_linha_bool("DEMO AUTOMÁTICA", demo_ativa, func(v): demo_ativa = v)
	campo_ranking_ativo = _add_linha_bool("RANKING ATIVO", ranking_ativo, func(v): ranking_ativo = v)
	campo_dificuldade = _add_linha_dificuldade()
	campo_idioma = _add_linha_idioma()

	var btn_salvar := _criar_botao("SALVAR CONFIGURAÇÕES", Color(0.0, 0.45, 0.16, 1.0))
	btn_salvar.position = Vector2(90, 1040)
	btn_salvar.size = Vector2(360, 70)
	btn_salvar.pressed.connect(_salvar_config)
	root_panel.add_child(btn_salvar)

	var btn_padrao := _criar_botao("RESTAURAR PADRÃO", Color(0.35, 0.22, 0.0, 1.0))
	btn_padrao.position = Vector2(530, 1040)
	btn_padrao.size = Vector2(360, 70)
	btn_padrao.pressed.connect(_restaurar_padrao)
	root_panel.add_child(btn_padrao)

	var btn_voltar := _criar_botao("VOLTAR", Color(0.55, 0.0, 0.0, 1.0))
	btn_voltar.position = Vector2(310, 1130)
	btn_voltar.size = Vector2(360, 70)
	btn_voltar.pressed.connect(_voltar_main)
	root_panel.add_child(btn_voltar)

	status_label = Label.new()
	status_label.position = Vector2(60, 1210)
	status_label.size = Vector2(860, 38)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.45))
	root_panel.add_child(status_label)

	_criar_toast()


func _add_linha_numero(nome: String, valor: int, minimo: int, maximo: int, passo: int, callback: Callable) -> SpinBox:
	var linha := HBoxContainer.new()
	linha.custom_minimum_size = Vector2(860, 60)
	linha.add_theme_constant_override("separation", 18)
	grid.add_child(linha)

	var lbl := _criar_label(nome)
	linha.add_child(lbl)

	var spin := SpinBox.new()
	spin.min_value = minimo
	spin.max_value = maximo
	spin.step = passo
	spin.value = valor
	spin.custom_minimum_size = Vector2(210, 54)
	spin.add_theme_font_size_override("font_size", 24)
	spin.value_changed.connect(func(v): callback.call(int(v)))
	linha.add_child(spin)

	return spin


func _add_linha_float(nome: String, valor: float, minimo: float, maximo: float, passo: float, callback: Callable) -> SpinBox:
	var linha := HBoxContainer.new()
	linha.custom_minimum_size = Vector2(860, 60)
	linha.add_theme_constant_override("separation", 18)
	grid.add_child(linha)

	var lbl := _criar_label(nome)
	linha.add_child(lbl)

	var spin := SpinBox.new()
	spin.min_value = minimo
	spin.max_value = maximo
	spin.step = passo
	spin.value = valor
	spin.custom_minimum_size = Vector2(210, 54)
	spin.add_theme_font_size_override("font_size", 24)
	spin.value_changed.connect(func(v): callback.call(float(v)))
	linha.add_child(spin)

	return spin


func _add_linha_bool(nome: String, valor: bool, callback: Callable) -> CheckButton:
	var linha := HBoxContainer.new()
	linha.custom_minimum_size = Vector2(860, 60)
	linha.add_theme_constant_override("separation", 18)
	grid.add_child(linha)

	var lbl := _criar_label(nome)
	linha.add_child(lbl)

	var check := CheckButton.new()
	check.button_pressed = valor
	check.text = "ATIVO"
	check.custom_minimum_size = Vector2(210, 54)
	check.add_theme_font_size_override("font_size", 24)
	check.toggled.connect(func(v): callback.call(v))
	linha.add_child(check)

	return check


func _add_linha_dificuldade() -> OptionButton:
	var linha := HBoxContainer.new()
	linha.custom_minimum_size = Vector2(860, 60)
	linha.add_theme_constant_override("separation", 18)
	grid.add_child(linha)

	var lbl := _criar_label("DIFICULDADE PADRÃO")
	linha.add_child(lbl)

	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(210, 54)
	opt.add_theme_font_size_override("font_size", 24)
	opt.add_item("FÁCIL")
	opt.add_item("DIFÍCIL")

	opt.select(1 if dificuldade_padrao == "dificil" else 0)

	opt.item_selected.connect(func(idx):
		dificuldade_padrao = "dificil" if idx == 1 else "facil"
	)

	linha.add_child(opt)

	return opt


func _add_linha_idioma() -> OptionButton:
	var linha := HBoxContainer.new()
	linha.custom_minimum_size = Vector2(860, 60)
	linha.add_theme_constant_override("separation", 18)
	grid.add_child(linha)

	var lbl := _criar_label("IDIOMA")
	linha.add_child(lbl)

	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(210, 54)
	opt.add_theme_font_size_override("font_size", 22)

	opt.add_item("PORTUGUÊS BR")
	opt.add_item("ENGLISH")
	opt.add_item("ESPAÑOL")

	if idioma == "en":
		opt.select(1)
	elif idioma == "es":
		opt.select(2)
	else:
		opt.select(0)

	opt.item_selected.connect(func(idx):
		if idx == 1:
			idioma = "en"
		elif idx == 2:
			idioma = "es"
		else:
			idioma = "pt_br"
	)

	linha.add_child(opt)

	return opt


func _criar_label(texto: String) -> Label:
	var lbl := Label.new()
	lbl.text = texto
	lbl.custom_minimum_size = Vector2(610, 54)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 25)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	return lbl


func _criar_botao(texto: String, cor: Color) -> Button:
	var btn := Button.new()
	btn.text = texto
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_theme_constant_override("outline_size", 5)

	var normal := StyleBoxFlat.new()
	normal.bg_color = cor
	normal.border_color = Color.WHITE
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 22
	normal.corner_radius_top_right = 22
	normal.corner_radius_bottom_left = 22
	normal.corner_radius_bottom_right = 22

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 0.02, 0.02, 1.0)
	hover.border_color = Color.WHITE

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	return btn


func _criar_toast() -> void:
	toast_label = Label.new()
	toast_label.visible = false
	toast_label.modulate.a = 0.0
	toast_label.text = ""
	toast_label.position = Vector2(190, 930)
	toast_label.size = Vector2(600, 60)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 26)
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 5)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.42, 0.16, 0.94)
	style.border_color = Color(0.55, 1.0, 0.68, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	toast_label.add_theme_stylebox_override("normal", style)

	root_panel.add_child(toast_label)


func _mostrar_toast(texto: String) -> void:
	if toast_label == null:
		return

	if toast_tween != null:
		toast_tween.kill()

	toast_label.text = texto
	toast_label.visible = true
	toast_label.modulate.a = 0.0
	toast_label.scale = Vector2(0.94, 0.94)

	toast_tween = create_tween()
	toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.18)
	toast_tween.parallel().tween_property(toast_label, "scale", Vector2.ONE, 0.18)
	toast_tween.tween_interval(1.55)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.22)
	toast_tween.tween_callback(func():
		if toast_label != null:
			toast_label.visible = false
	)


func _restaurar_padrao() -> void:
	tempo_partida = PADRAO_TEMPO_PARTIDA
	tempo_modal_final = PADRAO_TEMPO_MODAL_FINAL
	tempo_ranking_nome = PADRAO_TEMPO_RANKING_NOME
	tempo_intro_main = PADRAO_TEMPO_INTRO_MAIN
	tempo_teaser = PADRAO_TEMPO_TEASER
	volume_musica = PADRAO_VOLUME_MUSICA
	volume_fx = PADRAO_VOLUME_FX
	demo_ativa = PADRAO_DEMO_ATIVA
	ranking_ativo = PADRAO_RANKING_ATIVO
	dificuldade_padrao = PADRAO_DIFICULDADE
	idioma = PADRAO_IDIOMA

	if campo_tempo_partida != null:
		campo_tempo_partida.value = tempo_partida
	if campo_tempo_modal_final != null:
		campo_tempo_modal_final.value = tempo_modal_final
	if campo_tempo_ranking_nome != null:
		campo_tempo_ranking_nome.value = tempo_ranking_nome
	if campo_tempo_intro_main != null:
		campo_tempo_intro_main.value = tempo_intro_main
	if campo_tempo_teaser != null:
		campo_tempo_teaser.value = tempo_teaser
	if campo_volume_musica != null:
		campo_volume_musica.value = volume_musica
	if campo_volume_fx != null:
		campo_volume_fx.value = volume_fx
	if campo_demo_ativa != null:
		campo_demo_ativa.button_pressed = demo_ativa
	if campo_ranking_ativo != null:
		campo_ranking_ativo.button_pressed = ranking_ativo
	if campo_dificuldade != null:
		campo_dificuldade.select(0)
	if campo_idioma != null:
		campo_idioma.select(0)

	_salvar_config()
	_mostrar_toast("VALORES PADRÕES RESTAURADOS!")


func _atualizar_status() -> void:
	if status_label != null:
		status_label.text = "CONFIGURAÇÕES SALVAS EM: " + CONFIG_PATH


func _voltar_main() -> void:
	_salvar_config()

	if cena_voltar != "" and ResourceLoader.exists(cena_voltar):
		get_tree().change_scene_to_file(cena_voltar)
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
