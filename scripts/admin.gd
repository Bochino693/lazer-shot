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
var _painel: Control = null   # CAIXA-PRETA ou CÂMERA aberta por cima de tudo (ou null)
var _botao_ver: Button = null
var _botao_testar: Button = null
# TESTAR CÂMERA (painel): a imagem ao vivo, a foto de teste e o estado
var _cam_previa: TextureRect = null
var _cam_foto: TextureRect = null
var _cam_estado: Label = null
var _cam_t := 0.0
var _cam_foto_t := 0.0


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
	titulos.add_child(_rotulo("LAZER SHOT %s  ·  aponte a arma e atire nos botões" % Maquina.nome_da_versao(), 20, COR_APAGADO))
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
	_passos(coluna, "Tela de resultado", "volta sozinha depois de", "jogo/tempo_modal_final", 5, 120, 1, func(v): return "%d s" % v)
	_passos(coluna, "Nome no ranking", "tempo para digitar", "ranking/tempo_nome", 10, 120, 5, func(v): return "%d s" % v)

	# ABERTURA
	_secao(coluna, "ABERTURA")
	_passos(coluna, "Tempo da abertura", "", "main/tempo_intro", 10, 300, 5, func(v): return "%d s" % v)
	_passos(coluna, "Tempo do vídeo", "", "main/tempo_teaser", 5, 120, 5, func(v): return "%d s" % v)
	_opcoes(coluna, "Vídeos de demonstração", "", "main/demo_ativa", [[true, "LIGADO"], [false, "DESLIGADO"]])
	_opcoes(coluna, "Ranking na abertura", "", "ranking/ranking_ativo", [[true, "LIGADO"], [false, "DESLIGADO"]])
	_opcoes(coluna, "Vídeo pelo hardware", "decodificador da TV Box (desligado: player interno do jogo)", "video/nativo", [[true, "LIGADO"], [false, "DESLIGADO"]])
	_opcoes(coluna, "Imagem do vídeo", "se o vídeo aparecer de cabeça para baixo", "video/virar", [[false, "NORMAL"], [true, "VIRADA"]])
	# leve: a TV Box mais fraca (Maquina.qualidade_leve)
	_opcoes(coluna, "Qualidade da imagem", "automática: a da versão do APK (leve ou avançada)", "video/qualidade", [["auto", "AUTOMÁTICA"], ["leve", "LEVE"], ["completa", "COMPLETA"]])

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

	# CÂMERA: a foto antes da partida (scripts/webcam.gd, scripts/pose.gd).
	_secao(coluna, "CÂMERA")
	var linha_cam := _opcoes(coluna, "Foto antes da partida", "webcam do gabinete: a foto vai para o ranking", "camera/ativa", [[true, "LIGADA"], [false, "DESLIGADA"]])
	_botao_testar = _botao("TESTAR", _ver_camera, 22, COR_BOTAO, Vector2(150, 50))
	linha_cam.add_child(_botao_testar)

	# CAIXA-PRETA: o que o jogo fazia quando parou (scripts/caixa_preta.gd).
	# Fica só aqui: nada técnico aparece na tela do jogo.
	_secao(coluna, "CAIXA-PRETA")
	var resumo := Tela.resumo_caixa_preta()
	var linha_caixa := _linha(coluna, "Última sessão", resumo[1] if resumo.size() > 1 else "")
	_botao_ver = _botao("VER", _ver_caixa_preta, 24, COR_BOTAO, Vector2(160, 50))
	linha_caixa.add_child(_botao_ver)

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
			if _painel != null:
				_fechar_painel()
			else:
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
			if _painel != null and not _painel.is_ancestor_of(b):
				continue
			if b.is_visible_in_tree() and b.get_global_rect().has_point(p):
				b.pressed.emit()
				break
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _cam_previa != null and is_instance_valid(_cam_previa):
		_atualizar_camera(delta)
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


# ================================================================ caixa-preta
## A caixa-preta por cima da configuração: como a sessão anterior terminou,
## os contornos e o começo e o fim da última queda. É para uma foto quando o
## jogo fechar sozinho na TV Box (antes da Rodada 30 isso aparecia sozinho
## na abertura, num fundo escuro que parecia tela preta).
func _ver_caixa_preta() -> void:
	if _painel != null:
		return
	var tela := get_viewport_rect().size
	_painel = Control.new()
	_painel.name = "CaixaPreta"
	_painel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_painel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_painel)
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(fundo)
	var faixa := ColorRect.new()
	faixa.color = COR_DESTAQUE
	faixa.anchor_right = 1.0
	faixa.offset_bottom = 6.0
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(faixa)
	var titulo := _rotulo("CAIXA-PRETA", 46, COR_TEXTO)
	if ResourceLoader.exists(FONTE_TITULO):
		titulo.add_theme_font_override("font", load(FONTE_TITULO))
	titulo.position = Vector2(36, 22)
	_painel.add_child(titulo)
	var fechar := _botao("FECHAR", _fechar_painel, 26, COR_OK, Vector2(220, 64))
	fechar.position = Vector2(tela.x - 36.0 - 220.0, 24)
	_painel.add_child(fechar)
	var dica := _rotulo("Tire uma foto desta tela e mande para o suporte: a última linha diz onde o jogo estava.", 19, COR_APAGADO)
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dica.position = Vector2(36, 100)
	dica.size = Vector2(tela.x - 72.0, 52)
	_painel.add_child(dica)
	var texto := _rotulo("\n".join(Tela.resumo_caixa_preta()), 16, COR_TEXTO)
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.clip_text = true
	texto.position = Vector2(36, 160)
	texto.size = Vector2(tela.x - 72.0, tela.y - 160.0 - 24.0)
	_painel.add_child(texto)
	fechar.grab_focus()
	_mostrar_fim.call_deferred(texto)


## Se não couber tudo, some o começo: o fim (onde o jogo parou) fica.
func _mostrar_fim(texto: Label) -> void:
	if not is_instance_valid(texto):
		return
	var total := texto.get_line_count()
	var cabe := texto.get_visible_line_count()
	if total > cabe:
		texto.lines_skipped = total - cabe


func _fechar_painel() -> void:
	if _painel == null:
		return
	var era_camera := _painel.name == "Camera"
	for b in _botoes.duplicate():
		if _painel.is_ancestor_of(b):
			_botoes.erase(b)
	_painel.queue_free()
	_painel = null
	_cam_previa = null
	_cam_foto = null
	_cam_estado = null
	if era_camera:
		Maquina.webcam.soltar()
		Maquina.webcam.janelas_liberadas = false
		if is_instance_valid(_botao_testar):
			_botao_testar.grab_focus()
	elif is_instance_valid(_botao_ver):
		_botao_ver.grab_focus()


# ================================================================ câmera
## TESTAR CÂMERA: a imagem da webcam ao vivo, do jeito que sai na pose
## (espelho e giro), uma foto de teste no tamanho do ranking e, embaixo, o
## estado técnico (por onde ela abriu, permissões, o que o Android vê). É
## aqui, e só aqui, que aparece o porquê de não haver imagem.
func _ver_camera() -> void:
	if _painel != null:
		return
	var w: Webcam = Maquina.webcam
	if not bool(Maquina.valor("camera/ativa")):
		_mostrar_aviso("A foto antes da partida está DESLIGADA: ligue para testar", COR_DESTAQUE)
		return
	if Tela.contorna("camera"):
		_mostrar_aviso("A câmera foi desligada pela caixa-preta nesta versão (o app caiu com ela aberta)", COR_DESTAQUE)
	w.janelas_liberadas = true
	w.ligar()
	w.definir_ritmo(100)
	var tela := get_viewport_rect().size
	_painel = Control.new()
	_painel.name = "Camera"
	_painel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_painel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_painel)
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(fundo)
	var faixa := ColorRect.new()
	faixa.color = COR_DESTAQUE
	faixa.anchor_right = 1.0
	faixa.offset_bottom = 6.0
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(faixa)
	var titulo := _rotulo("CÂMERA", 46, COR_TEXTO)
	if ResourceLoader.exists(FONTE_TITULO):
		titulo.add_theme_font_override("font", load(FONTE_TITULO))
	titulo.position = Vector2(36, 22)
	_painel.add_child(titulo)
	var fechar := _botao("FECHAR", _fechar_painel, 26, COR_OK, Vector2(220, 64))
	fechar.position = Vector2(tela.x - 36.0 - 220.0, 24)
	_painel.add_child(fechar)
	var dica := _rotulo("A imagem como aparece na pose. Ajuste o espelho e o giro até a pessoa aparecer de pé; a FOTO TESTE mostra o recorte que vai para o ranking.", 19, COR_APAGADO)
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dica.position = Vector2(36, 100)
	dica.size = Vector2(tela.x - 72.0, 52)
	_painel.add_child(dica)
	# a imagem ao vivo (quadrada, como na pose) e a foto de teste ao lado
	var lado := minf(560.0, tela.x - 72.0 - 280.0)
	var caixa := Control.new()
	caixa.clip_contents = true
	caixa.position = Vector2(36, 170)
	caixa.size = Vector2(lado, lado)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(caixa)
	var preto := ColorRect.new()
	preto.color = Color(0.02, 0.02, 0.03)
	preto.size = caixa.size
	preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(preto)
	_cam_previa = TextureRect.new()
	_cam_previa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cam_previa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_cam_previa.size = caixa.size
	_cam_previa.pivot_offset = caixa.size * 0.5
	_cam_previa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(_cam_previa)
	var x2 := 36.0 + lado + 24.0
	var foto_rotulo := _rotulo("FOTO TESTE", 20, COR_APAGADO)
	foto_rotulo.position = Vector2(x2, 170)
	_painel.add_child(foto_rotulo)
	_cam_foto = TextureRect.new()
	_cam_foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cam_foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_cam_foto.position = Vector2(x2, 200)
	_cam_foto.size = Vector2(220, 220)
	_cam_foto.texture = FotosRanking.vazia()
	_cam_foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(_cam_foto)
	var botoes := VBoxContainer.new()
	botoes.position = Vector2(x2, 440)
	botoes.add_theme_constant_override("separation", 12)
	_painel.add_child(botoes)
	var espelho := _botao("", func():
		Maquina.definir("camera/espelhar", not bool(Maquina.valor("camera/espelhar")))
		Maquina.aplicar()
		_atualizar_tudo(), 22, COR_BOTAO, Vector2(260, 56))
	botoes.add_child(espelho)
	var giro := _botao("", func():
		Maquina.definir("camera/girar", (int(Maquina.valor("camera/girar")) + 90) % 360)
		Maquina.aplicar()
		_atualizar_tudo(), 22, COR_BOTAO, Vector2(260, 56))
	botoes.add_child(giro)
	botoes.add_child(_botao("FOTO TESTE", _foto_teste, 22, COR_BOTAO, Vector2(260, 56)))
	if OS.get_name() == "Android":
		# a janela de permissão da câmera do Android de novo (se ela foi
		# negada sem querer na primeira abertura)
		botoes.add_child(_botao("PERMISSÃO", func():
			OS.request_permission("CAMERA")
			_mostrar_aviso("Toque em PERMITIR na janela do Android", COR_TEXTO), 22, COR_BOTAO, Vector2(260, 56)))
	_atualizadores.append(func():
		if is_instance_valid(espelho):
			espelho.text = "ESPELHO: %s" % ("SIM" if bool(Maquina.valor("camera/espelhar")) else "NÃO")
		if is_instance_valid(giro):
			giro.text = "GIRAR: %d°" % int(Maquina.valor("camera/girar")))
	_cam_estado = _rotulo("", 16, COR_TEXTO)
	_cam_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cam_estado.clip_text = true
	_cam_estado.position = Vector2(36, 170 + lado + 24)
	_cam_estado.size = Vector2(tela.x - 72.0, tela.y - (170 + lado + 24) - 24.0)
	_painel.add_child(_cam_estado)
	_cam_t = 0.0
	_cam_foto_t = 0.0
	_atualizar_tudo()
	fechar.grab_focus()


func _atualizar_camera(delta: float) -> void:
	var w: Webcam = Maquina.webcam
	_cam_previa.texture = w.textura() if w.ao_vivo() else null
	_cam_previa.flip_h = bool(Maquina.valor("camera/espelhar"))
	_cam_previa.rotation_degrees = float(int(Maquina.valor("camera/girar")))
	if _cam_foto_t > 0.0:
		_cam_foto_t -= delta
	_cam_t -= delta
	if _cam_t <= 0.0:
		_cam_t = 0.5
		_cam_estado.text = "\n".join(w.relatorio())


func _foto_teste() -> void:
	var w: Webcam = Maquina.webcam
	if not w.ao_vivo():
		_mostrar_aviso("Sem imagem da câmera agora", COR_DESTAQUE)
		return
	w.abrir_obturador(300)
	await get_tree().create_timer(0.35).timeout
	if _cam_foto == null or not is_instance_valid(_cam_foto):
		return
	var caminho := w.tirar_foto()
	if caminho == "" or w.ultima_foto == null:
		_mostrar_aviso("A foto saiu sem imagem", COR_DESTAQUE)
		return
	var r := Webcam.recortar(w.ultima_foto, w.espelhar, w.girar, Webcam.LADO_FOTO)
	_cam_foto.texture = ImageTexture.create_from_image(r)
	# a foto de teste não fica guardada (não é de ninguém)
	var apagar := func(c: String) -> void:
		if c == caminho:
			DirAccess.remove_absolute(caminho)
	w.foto_gravada.connect(apagar, CONNECT_ONE_SHOT)
