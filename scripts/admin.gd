extends Control

## CONFIGURAÇÕES DA MÁQUINA (abre com F10 ou segurando o SELECT 3 s na
## abertura). Feita para a arma: aponte e atire nos botões (ou use mouse,
## setas + START/ENTER). Tudo é guardado pela Maquina em
## user://config_admin.cfg.

const Pincel := preload("res://scripts/pincel.gd")
const CENA_SAIDA := "res://scenes/main.tscn"
const FONTE_TITULO := "res://fonts/Exo2-ExtraBold.ttf"

const COR_FUNDO := Color(0.035, 0.045, 0.075)
const COR_CARTAO := Color(0.075, 0.095, 0.15)
const COR_BOTAO := Color(0.13, 0.16, 0.24)
const COR_DESTAQUE := Color(1.0, 0.27, 0.2)
const COR_OK := Color(0.2, 0.82, 0.45)
const COR_TEXTO := Color(0.93, 0.95, 1.0)
const COR_APAGADO := Color(0.6, 0.66, 0.78)

@export_file("*.tscn") var cena_voltar: String = CENA_SAIDA

var _atualizadores: Array[Callable] = []
var _botoes: Array[Button] = []
var _rotulo_contadores: Label
var _aviso: Label
var _mira: Control
var _aprendendo := ""
var _aprender_desde := 0
var _ultimo_botao: Label
var _aprender_t := 0.0
var _rotulos_botao := {}
var _confirmar := {}
var _saindo := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_criar_interface()
	_atualizar_tudo()


# ================================================================ interface
func _criar_interface() -> void:
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	var faixa := ColorRect.new()
	faixa.color = COR_DESTAQUE
	faixa.anchor_right = 1.0
	faixa.offset_bottom = 6.0
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(faixa)

	var margem := MarginContainer.new()
	margem.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right"]:
		margem.add_theme_constant_override("margin_" + lado, 36)
	margem.add_theme_constant_override("margin_top", 24)
	margem.add_theme_constant_override("margin_bottom", 18)
	add_child(margem)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 4)
	margem.add_child(coluna)

	# Cabeçalho
	var topo := HBoxContainer.new()
	coluna.add_child(topo)
	var titulos := VBoxContainer.new()
	titulos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulos.add_theme_constant_override("separation", 0)
	topo.add_child(titulos)
	var titulo := _rotulo("CONFIGURAÇÕES", 48, COR_TEXTO)
	if ResourceLoader.exists(FONTE_TITULO):
		titulo.add_theme_font_override("font", load(FONTE_TITULO))
	titulos.add_child(titulo)
	titulos.add_child(_rotulo("LAZER SHOT  ·  aponte a arma e atire nos botões", 20, COR_APAGADO))
	var direita := VBoxContainer.new()
	direita.alignment = BoxContainer.ALIGNMENT_CENTER
	topo.add_child(direita)
	_rotulo_contadores = _rotulo("", 20, COR_APAGADO)
	_rotulo_contadores.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	direita.add_child(_rotulo_contadores)
	var zerar_cont := _botao("ZERAR CONTADORES", func(): _com_confirmacao("contadores", func():
		Maquina.definir("maquina/total_fichas", 0)
		Maquina.definir("maquina/total_partidas", 0)
		_atualizar_tudo()), 18)
	zerar_cont.size_flags_horizontal = Control.SIZE_SHRINK_END
	direita.add_child(zerar_cont)

	# MÁQUINA
	_secao(coluna, "MÁQUINA")
	_opcoes(coluna, "Modo de jogo", "livre: START sem cobrar  ·  crédito: ficha pelo SELECT", "maquina/modo", [["livre", "LIVRE"], ["credito", "CRÉDITO"]])
	_passos(coluna, "Créditos por partida", "", "maquina/creditos_por_partida", 1, 10, 1, func(v): return "%d" % v)
	var linha_cred := _passos(coluna, "Créditos na máquina", "", "maquina/creditos", 0, 99, 1, func(v): return "%02d" % v)
	linha_cred.add_child(_botao("ZERAR", func():
		Maquina.definir("maquina/creditos", 0)
		_atualizar_tudo(), 20))

	# PARTIDA
	_secao(coluna, "PARTIDA")
	_passos(coluna, "Tempo de partida", "", "jogo/tempo_partida", 30, 600, 10, func(v): return "%d:%02d" % [int(v) / 60, int(v) % 60])
	_opcoes(coluna, "Dificuldade", "difícil: sem mira na tela", "jogo/dificuldade_padrao", [["facil", "FÁCIL"], ["dificil", "DIFÍCIL"]])
	_passos(coluna, "Tela de resultado", "volta sozinha depois de", "jogo/tempo_modal_final", 5, 120, 1, func(v): return "%d s" % v)
	_passos(coluna, "Nome no ranking", "tempo para digitar", "ranking/tempo_nome", 10, 120, 5, func(v): return "%d s" % v)

	# ABERTURA
	_secao(coluna, "ABERTURA")
	_passos(coluna, "Tempo da abertura", "", "main/tempo_intro", 10, 300, 5, func(v): return "%d s" % v)
	_passos(coluna, "Tempo do vídeo", "", "main/tempo_teaser", 5, 120, 5, func(v): return "%d s" % v)
	_opcoes(coluna, "Vídeos de demonstração", "", "main/demo_ativa", [[true, "LIGADO"], [false, "DESLIGADO"]])
	_opcoes(coluna, "Ranking na abertura", "", "ranking/ranking_ativo", [[true, "LIGADO"], [false, "DESLIGADO"]])
	_opcoes(coluna, "Vídeo pelo hardware", "decodificador da TV Box (desligado: player do Godot)", "video/nativo", [[true, "LIGADO"], [false, "DESLIGADO"]])
	_opcoes(coluna, "Imagem do vídeo", "se o vídeo aparecer de cabeça para baixo", "video/virar", [[false, "NORMAL"], [true, "VIRADA"]])

	# SOM
	_secao(coluna, "SOM")
	_volume(coluna, "Música", "audio/volume_musica")
	_volume(coluna, "Efeitos", "audio/volume_fx")

	# CONTROLES
	_secao(coluna, "BOTÕES")
	_aprender(coluna, "START na arma", "botão do lado direito, perto do bico", "start_arma")
	_aprender(coluna, "RECARGA na arma", "botão do lado direito, perto do gatilho", "recarga_arma")
	_aprender(coluna, "START na Zero Delay", "", "start")
	_aprender(coluna, "SELECT na Zero Delay", "ficha / crédito", "select")
	_ultimo_botao = _rotulo("Último botão recebido: —", 18, COR_APAGADO)
	_ultimo_botao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(_ultimo_botao)

	# Rodapé
	var espaco := Control.new()
	espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(espaco)
	_aviso = _rotulo("", 22, COR_APAGADO)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(_aviso)
	var rodape := HBoxContainer.new()
	rodape.add_theme_constant_override("separation", 14)
	coluna.add_child(rodape)
	var salvar := _botao("SALVAR E SAIR", _salvar_e_sair, 28, COR_OK)
	salvar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	salvar.custom_minimum_size.y = 66
	rodape.add_child(salvar)
	var sair := _botao("SAIR SEM SALVAR", _sair_sem_salvar, 22)
	sair.custom_minimum_size = Vector2(250, 66)
	rodape.add_child(sair)
	var padrao := _botao("PADRÃO", func(): _com_confirmacao("padrao", func():
		Maquina.restaurar_padrao()
		_atualizar_tudo()
		_mostrar_aviso("Valores de fábrica (salve para valer)", COR_TEXTO)), 22)
	padrao.custom_minimum_size = Vector2(170, 66)
	rodape.add_child(padrao)
	var dica := _rotulo("F10 ou segure o SELECT 3 s na abertura para voltar aqui", 17, Color(COR_APAGADO, 0.7))
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(dica)

	salvar.grab_focus()

	# Mira da arma por cima de tudo
	var camada := CanvasLayer.new()
	camada.layer = 50
	add_child(camada)
	_mira = Control.new()
	_mira.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mira.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mira.draw.connect(_desenhar_mira)
	camada.add_child(_mira)


func _secao(pai: Control, texto: String) -> void:
	var r := _rotulo(texto, 19, COR_DESTAQUE)
	r.custom_minimum_size.y = 24
	r.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	pai.add_child(r)


## Cartão de uma linha: título (e dica) à esquerda, controles à direita.
func _linha(pai: Control, titulo: String, dica: String) -> HBoxContainer:
	var cartao := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_CARTAO
	estilo.set_corner_radius_all(14)
	estilo.content_margin_left = 20
	estilo.content_margin_right = 12
	estilo.content_margin_top = 4
	estilo.content_margin_bottom = 4
	cartao.add_theme_stylebox_override("panel", estilo)
	pai.add_child(cartao)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	cartao.add_child(linha)
	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.alignment = BoxContainer.ALIGNMENT_CENTER
	textos.add_theme_constant_override("separation", -4)
	linha.add_child(textos)
	textos.add_child(_rotulo(titulo, 26, COR_TEXTO))
	if dica != "":
		textos.add_child(_rotulo(dica, 16, COR_APAGADO))
	return linha


func _passos(pai: Control, titulo: String, dica: String, chave: String, minimo: int, maximo: int, passo: int, formato: Callable) -> HBoxContainer:
	var linha := _linha(pai, titulo, dica)
	var valor := _rotulo("", 30, COR_TEXTO)
	valor.custom_minimum_size.x = 120
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mudar := func(d: int):
		var v := clampi(int(Maquina.valor(chave)) + d, minimo, maximo)
		Maquina.definir(chave, v)
		_atualizar_tudo()
	linha.add_child(_botao("−", func(): mudar.call(-passo), 34, COR_BOTAO, Vector2(74, 50)))
	linha.add_child(valor)
	linha.add_child(_botao("+", func(): mudar.call(passo), 34, COR_BOTAO, Vector2(74, 50)))
	_atualizadores.append(func(): valor.text = formato.call(int(Maquina.valor(chave))))
	return linha


func _opcoes(pai: Control, titulo: String, dica: String, chave: String, lista: Array) -> HBoxContainer:
	var linha := _linha(pai, titulo, dica)
	for par in lista:
		var v = par[0]
		var b := _botao(par[1], func():
			Maquina.definir(chave, v)
			_atualizar_tudo(), 22, COR_BOTAO, Vector2(170, 50))
		b.toggle_mode = true
		linha.add_child(b)
		_atualizadores.append(func(): b.set_pressed_no_signal(Maquina.valor(chave) == v))
	return linha


func _volume(pai: Control, titulo: String, chave: String) -> void:
	var linha := _linha(pai, titulo, "")
	var valor := _rotulo("", 30, COR_TEXTO)
	valor.custom_minimum_size.x = 120
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mudar := func(d: int):
		var p := clampi(_db_para_pct(float(Maquina.valor(chave))) + d, 0, 100)
		Maquina.definir(chave, _pct_para_db(p))
		Maquina.aplicar()
		_atualizar_tudo()
	linha.add_child(_botao("−", func(): mudar.call(-10), 34, COR_BOTAO, Vector2(74, 50)))
	linha.add_child(valor)
	linha.add_child(_botao("+", func(): mudar.call(10), 34, COR_BOTAO, Vector2(74, 50)))
	_atualizadores.append(func(): valor.text = "%d%%" % _db_para_pct(float(Maquina.valor(chave))))


func _aprender(pai: Control, titulo: String, dica: String, qual: String) -> void:
	var linha := _linha(pai, titulo, dica)
	var valor := _rotulo("", 24, COR_TEXTO)
	valor.custom_minimum_size.x = 250
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	linha.add_child(valor)
	_rotulos_botao[qual] = valor
	var da_arma := qual.ends_with("_arma")
	linha.add_child(_botao("APRENDER", func():
		_aprendendo = qual
		_aprender_t = 8.0
		_aprender_desde = Time.get_ticks_msec()
		_mostrar_aviso("Aperte agora o botão na %s..." % ("arma" if da_arma else "Zero Delay"), COR_DESTAQUE), 22, COR_BOTAO, Vector2(190, 50)))
	_atualizadores.append(func():
		if _aprendendo != qual:
			if da_arma:
				valor.text = Maquina.nome_do_descritor(str(Maquina.valor("botoes/" + qual)))
			else:
				valor.text = "BOTÃO %d" % int(Maquina.valor("botoes/" + qual)))


func _rotulo(texto: String, tamanho: int, cor: Color) -> Label:
	var r := Label.new()
	r.text = texto
	r.add_theme_font_size_override("font_size", tamanho)
	r.add_theme_color_override("font_color", cor)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _botao(texto: String, acao: Callable, tamanho: int = 24, cor: Color = COR_BOTAO, minimo: Vector2 = Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = minimo
	# A arma pode mandar o gatilho como clique direito.
	b.button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	b.add_theme_font_size_override("font_size", tamanho)
	b.add_theme_color_override("font_color", COR_TEXTO)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _estilo(cor))
	b.add_theme_stylebox_override("hover", _estilo(cor.lightened(0.18), Color(1, 1, 1, 0.5)))
	b.add_theme_stylebox_override("pressed", _estilo(COR_DESTAQUE if cor == COR_BOTAO else cor.lightened(0.25)))
	b.add_theme_stylebox_override("hover_pressed", _estilo(COR_DESTAQUE.lightened(0.12), Color(1, 1, 1, 0.5)))
	b.add_theme_stylebox_override("focus", _estilo(Color(0, 0, 0, 0), Color(1, 1, 1, 0.85)))
	b.pressed.connect(func():
		_piscar(b)
		acao.call())
	_botoes.append(b)
	return b


func _estilo(cor: Color, borda: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = cor
	e.set_corner_radius_all(12)
	e.content_margin_left = 14
	e.content_margin_right = 14
	e.content_margin_top = 6
	e.content_margin_bottom = 6
	if borda.a > 0.0:
		e.set_border_width_all(3)
		e.border_color = borda
	return e


func _piscar(b: Button) -> void:
	b.pivot_offset = b.size * 0.5
	b.scale = Vector2(0.92, 0.92)
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ================================================================ estado
func _atualizar_tudo() -> void:
	for f in _atualizadores:
		f.call()
	_rotulo_contadores.text = "FICHAS %04d   ·   PARTIDAS %04d" % [int(Maquina.valor("maquina/total_fichas")), int(Maquina.valor("maquina/total_partidas"))]


func _mostrar_aviso(texto: String, cor: Color) -> void:
	_aviso.text = texto
	_aviso.add_theme_color_override("font_color", cor)


## Ações perigosas pedem um segundo tiro em até 3 s.
func _com_confirmacao(nome: String, acao: Callable) -> void:
	var agora := Time.get_ticks_msec()
	if _confirmar.get(nome, 0) > agora:
		_confirmar.erase(nome)
		acao.call()
		return
	_confirmar[nome] = agora + 3000
	_mostrar_aviso("Atire de novo para confirmar", COR_DESTAQUE)


func _salvar_e_sair() -> void:
	if _saindo:
		return
	_saindo = true
	Maquina.salvar()
	Maquina.aplicar()
	_mostrar_aviso("Configurações salvas!", COR_OK)
	TransicaoGlobal.trocar_cena(cena_voltar if ResourceLoader.exists(cena_voltar) else CENA_SAIDA)


func _sair_sem_salvar() -> void:
	if _saindo:
		return
	_saindo = true
	Maquina.cfg = ConfigFile.new()
	Maquina.cfg.load(Maquina.CONFIG)
	Maquina.aplicar()
	TransicaoGlobal.trocar_cena(cena_voltar if ResourceLoader.exists(cena_voltar) else CENA_SAIDA)


static func _db_para_pct(db: float) -> int:
	if db <= -60.0:
		return 0
	return clampi(int(round(db_to_linear(db) * 10.0)) * 10, 0, 100)


static func _pct_para_db(p: int) -> float:
	if p <= 0:
		return -80.0
	return linear_to_db(float(p) / 100.0)


# ================================================================ entrada
func _notification(what: int) -> void:
	# VOLTAR do Android (o botão da arma perto do gatilho costuma ser este).
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_mostrar_ultimo("VOLTAR (ANDROID)")
		if _aprendendo.ends_with("_arma"):
			_gravar_arma("voltar")


func _mostrar_ultimo(nome: String) -> void:
	if _ultimo_botao != null:
		_ultimo_botao.text = "Último botão recebido: " + nome


func _gravar_arma(descritor: String) -> void:
	var qual := _aprendendo
	var outro := "botoes/recarga_arma" if qual == "start_arma" else "botoes/start_arma"
	# O mesmo botão não pode ser START e RECARGA.
	if str(Maquina.valor(outro)) == descritor:
		Maquina.definir(outro, "padrao" if outro == "botoes/recarga_arma" else "")
	Maquina.definir("botoes/" + qual, descritor)
	Maquina.aplicar()
	_mostrar_aviso("%s = %s  (salve para valer sempre)" % ["START na arma" if qual == "start_arma" else "RECARGA na arma", Maquina.nome_do_descritor(descritor)], COR_OK)
	_aprendendo = ""
	_atualizar_tudo()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_mostrar_ultimo(Maquina.nome_do_descritor(Maquina.descrever(event)))
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		_mostrar_ultimo(Maquina.nome_do_descritor(Maquina.descrever(event)))
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		_mostrar_ultimo("ZERO DELAY " + Maquina.nome_do_descritor(Maquina.descrever(event)))

	# Aprendendo um botão da arma: clique (menos o gatilho) ou tecla.
	if _aprendendo.ends_with("_arma"):
		if Time.get_ticks_msec() - _aprender_desde < 350:
			return
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			var mb := event as InputEventMouseButton
			if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
				return
			_gravar_arma(Maquina.descrever(mb))
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
			var kk := event as InputEventKey
			if kk.keycode == KEY_ESCAPE:
				_aprendendo = ""
				_mostrar_aviso("", COR_APAGADO)
				_atualizar_tudo()
				get_viewport().set_input_as_handled()
				return
			if kk.keycode != KEY_F10:
				_gravar_arma(Maquina.descrever(kk))
				get_viewport().set_input_as_handled()
				return

	# Aprendendo um botão: o próximo botão do controle vira o START/SELECT.
	if _aprendendo != "" and not _aprendendo.ends_with("_arma"):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
			var idx := (event as InputEventJoypadButton).button_index
			Maquina.definir("botoes/" + _aprendendo, idx)
			Maquina.aplicar()
			_mostrar_aviso("Botão %s = BOTÃO %d  (salve para valer sempre)" % [_aprendendo.to_upper(), idx], COR_OK)
			_aprendendo = ""
			_atualizar_tudo()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
			_aprendendo = ""
			_mostrar_aviso("", COR_APAGADO)
			_atualizar_tudo()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and (k.keycode == KEY_F10 or k.keycode == KEY_ESCAPE):
			_salvar_e_sair()
			get_viewport().set_input_as_handled()
			return

	# Gatilho (clique esquerdo da arma ou input_shot): aperta o botão sob a
	# mira única. O ponteiro fica capturado, então a interface não recebe o
	# clique por conta própria.
	var gatilho := event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if gatilho or (InputMap.has_action("input_shot") and event.is_action_pressed("input_shot")):
		var p := MiraGlobal.pos
		for b in _botoes:
			if b.is_visible_in_tree() and b.get_global_rect().has_point(p):
				b.pressed.emit()
				break
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _aprendendo != "":
		_aprender_t -= delta
		var r: Label = _rotulos_botao.get(_aprendendo)
		if r != null:
			r.text = "APERTE..." if fmod(_aprender_t, 0.8) > 0.4 else ""
		if _aprender_t <= 0.0:
			_aprendendo = ""
			_mostrar_aviso("Nenhum botão apertado", COR_APAGADO)
			_atualizar_tudo()
	_mira.queue_redraw()


func _desenhar_mira() -> void:
	Pincel.mira(_mira, MiraGlobal.pos, 18.0, 8.0, COR_DESTAQUE, Color(1, 1, 1, 0.85))
