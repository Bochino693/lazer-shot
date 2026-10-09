extends CanvasLayer

## Troca de tela sem tela cinza e sem tranco.
##
## 1. escurece (a tela atual some no preto);
## 2. a próxima cena E os arquivos que ela lê no _ready (scripts/precarga.gd)
##    são carregados em threads enquanto a tela está preta. Nas fases aparece
##    um cartão com a capa, o nome, uma dica e a barra de progresso real; nas
##    outras telas, um anel girando se demorar;
## 3. troca a cena, espera ela montar e desenhar os primeiros quadros
##    escondida (é aí que o Godot prepara shaders e texturas);
## 4. clareia.
## A cor de fundo padrão vira preta, então nem no boot nem entre cenas
## aparece o cinza do Godot.
##
## Uso: TransicaoGlobal.trocar_cena("res://scenes/main.tscn")
##      TransicaoGlobal.trocar_cena(caminho, 0.0)  # se a cena já escureceu

const Pincel := preload("res://scripts/pincel.gd")
const Precarga := preload("res://scripts/precarga.gd")

const TEMPO_SAIDA := 0.22
const TEMPO_ENTRADA := 0.30
const QUADROS_ESCONDIDOS := 3
const ESPERA_ANTES_DO_ANEL := 0.30
const TEMPO_MINIMO_CARTAO := 0.85
const FONTE_TITULO := "res://fonts/Exo2-ExtraBold.ttf"

## Cartão de carregamento de cada fase.
const FASES := {
	"res://scenes/deserto.tscn": {
		"nome": "DESERTO SAGRADO", "capa": "res://sprites/cene_desert.png",
		"cor": Color(1.0, 0.74, 0.22),
		"dica": "ACERTE SÓ O BRASÃO DO MODO ATUAL: SOL OU LUA",
	},
	"res://scenes/mar.tscn": {
		"nome": "FUNDO DO MAR", "capa": "res://sprites/cene_mar.png",
		"cor": Color(0.24, 0.72, 1.0),
		"dica": "CUIDADO: 3 BOMBAS ENCERRAM A PARTIDA",
	},
	"res://scenes/bar.tscn": {
		"nome": "BAR DO FAROESTE", "capa": "res://sprites/cene_bar.png",
		"cor": Color(0.34, 0.95, 0.42),
		"dica": "QUEBRE GARRAFAS EM SEGUIDA PARA FAZER COMBOS",
	},
	"res://scenes/arena.tscn": {
		"nome": "ARENA LAZER SHOT", "capa": "res://sprites/cene_arena.png",
		"cor": Color(1.0, 0.24, 0.20),
		"dica": "OBSERVE A SEQUÊNCIA E REPITA NA MESMA ORDEM",
	},
}

signal cena_trocada(caminho: String)

var fade: ColorRect
var em_transicao: bool = false

var _anel: Control
var _anel_t := 0.0

# cartão da fase
var _cartao: Control
var _halo: Panel
var _moldura: Control
var _borda: Panel
var _capa: TextureRect
var _titulo: Label
var _dica: Label
var _pct: Label
var _barra_fundo: Panel
var _barra: Panel
var _brilho: ColorRect
var _giro: Control
var _cor_fase := Color.WHITE
var _cartao_t := 0.0
var _mostrado := 0.0    # progresso desenhado (corre atrás do real)
var _alvo := 0.0        # progresso real

var _segurar: Array = []   # mantém a pré-carga viva até a cena nova montar


func _ready() -> void:
	layer = 9999
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.set_default_clear_color(Color.BLACK)

	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.visible = false
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

	_anel = Control.new()
	_anel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_anel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_anel.visible = false
	_anel.draw.connect(_desenhar_anel)
	add_child(_anel)

	_criar_cartao()
	set_process(false)


func trocar_cena(caminho: String, tempo_saida: float = TEMPO_SAIDA, tempo_entrada: float = TEMPO_ENTRADA) -> void:
	if em_transicao:
		return
	if caminho == "" or not ResourceLoader.exists(caminho):
		push_error("Cena não encontrada: " + caminho)
		return

	em_transicao = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Começa a carregar já, em paralelo com o escurecer: a cena e o que ela
	# lê no _ready (cada arquivo numa thread do pool).
	var pediu := ResourceLoader.load_threaded_request(caminho, "PackedScene", true) == OK
	var extras: Array[String] = []
	for p in Precarga.LISTA.get(caminho, []):
		if ResourceLoader.has_cached(p) or not ResourceLoader.exists(p):
			continue
		if ResourceLoader.load_threaded_request(p) == OK:
			extras.append(p)

	fade.visible = true
	if tempo_saida <= 0.0:
		fade.color.a = 1.0
	else:
		var tw_out := create_tween()
		tw_out.tween_property(fade, "color:a", 1.0, tempo_saida * (1.0 - fade.color.a))
		await tw_out.finished

	# Tela preta: a tela que sai para de processar e de desenhar (animações,
	# vídeo, efeitos), deixando o processador para as threads que carregam a
	# próxima. Ela some da memória quando a nova monta.
	var velha := get_tree().current_scene
	if velha != null:
		velha.process_mode = Node.PROCESS_MODE_DISABLED
		if velha is CanvasItem:
			(velha as CanvasItem).visible = false

	var fase: Dictionary = FASES.get(caminho, {})
	var com_cartao := not fase.is_empty()
	if com_cartao:
		_mostrar_cartao(fase)

	var cena: PackedScene = null
	var inicio := Time.get_ticks_msec()
	while true:
		_alvo = _progresso(caminho if pediu else "", extras)
		if _alvo >= 1.0:
			break
		await get_tree().process_frame
		if not com_cartao and (Time.get_ticks_msec() - inicio) > ESPERA_ANTES_DO_ANEL * 1000.0 and not _anel.visible:
			_mostrar_anel(true)

	if com_cartao:
		# a barra chega ao fim e o cartão fica um mínimo para ser lido
		while _mostrado < 0.999 or (Time.get_ticks_msec() - inicio) < TEMPO_MINIMO_CARTAO * 1000.0:
			await get_tree().process_frame
		_pct.text = "PRONTO"
		await get_tree().process_frame

	if pediu and ResourceLoader.load_threaded_get_status(caminho) == ResourceLoader.THREAD_LOAD_LOADED:
		cena = ResourceLoader.load_threaded_get(caminho) as PackedScene
	for p in extras:
		if ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_LOADED:
			_segurar.append(ResourceLoader.load_threaded_get(p))
	if cena == null:
		cena = load(caminho) as PackedScene

	if cena == null or get_tree().change_scene_to_packed(cena) != OK:
		push_error("Não foi possível abrir a cena: " + caminho)
		# fica na tela de antes, que volta a rodar
		if is_instance_valid(velha):
			velha.process_mode = Node.PROCESS_MODE_INHERIT
			if velha is CanvasItem:
				(velha as CanvasItem).visible = true
	else:
		# A cena nova monta e desenha os primeiros quadros escondida.
		for i in range(QUADROS_ESCONDIDOS):
			await get_tree().process_frame
		cena_trocada.emit(caminho)
	_segurar.clear()

	_mostrar_anel(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	var tw_in := create_tween().set_parallel(true)
	tw_in.tween_property(fade, "color:a", 0.0, tempo_entrada).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if com_cartao:
		tw_in.tween_property(_cartao, "modulate:a", 0.0, tempo_entrada * 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw_in.finished

	_cartao.visible = false
	fade.visible = false
	set_process(_anel.visible)
	em_transicao = false


## Escurece a tela sem trocar de cena (para quem precisa do preto antes).
func escurecer(tempo: float = TEMPO_SAIDA) -> void:
	fade.visible = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, tempo)
	await tw.finished


## 0..1: a cena pesa metade, os arquivos extras a outra metade.
func _progresso(caminho: String, extras: Array[String]) -> float:
	var info := []
	var cena := 1.0
	if caminho != "":
		var st := ResourceLoader.load_threaded_get_status(caminho, info)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			cena = float(info[0]) if info.size() > 0 else 0.0
	if extras.is_empty():
		return cena
	var soma := 0.0
	for p in extras:
		info.clear()
		var st := ResourceLoader.load_threaded_get_status(p, info)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			soma += float(info[0]) if info.size() > 0 else 0.0
		else:
			soma += 1.0
	return cena * 0.5 + (soma / float(extras.size())) * 0.5


func _mostrar_anel(sim: bool) -> void:
	_anel.visible = sim
	_anel_t = 0.0
	set_process(sim or _cartao.visible)


func _process(delta: float) -> void:
	if _anel.visible:
		_anel_t += delta
		_anel.queue_redraw()
	if _cartao.visible:
		_animar_cartao(delta)


func _desenhar_anel() -> void:
	var tela := _anel.get_viewport_rect().size
	var centro := Vector2(tela.x * 0.5, tela.y * 0.5)
	var a := _anel_t * 5.0
	var surgir := clampf(_anel_t / 0.3, 0.0, 1.0)
	Pincel.anel(_anel, centro, 26.0, 4.0, Color(1, 1, 1, 0.12 * surgir))
	Pincel.arco(_anel, centro, 26.0, a, a + 1.6, Color(1.0, 0.25, 0.2, 0.9 * surgir), 4.0)


# ------------------------------------------------------------------ cartão

func _criar_cartao() -> void:
	_cartao = Control.new()
	_cartao.name = "CartaoFase"
	_cartao.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cartao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao.visible = false
	add_child(_cartao)

	# capa recortada numa moldura (o recorte é por tesoura, sem custo extra)
	# e a borda colorida por cima dela; o halo colorido fica atrás
	_halo = Panel.new()
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao.add_child(_halo)

	_moldura = Control.new()
	_moldura.clip_contents = true
	_moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao.add_child(_moldura)

	_capa = TextureRect.new()
	_capa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_capa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_moldura.add_child(_capa)

	_borda = Panel.new()
	_borda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao.add_child(_borda)

	_titulo = _rotulo(66, Color.WHITE)
	if ResourceLoader.exists(FONTE_TITULO):
		_titulo.add_theme_font_override("font", load(FONTE_TITULO))
	_titulo.add_theme_constant_override("outline_size", 10)
	_titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))

	_barra_fundo = Panel.new()
	_barra_fundo.clip_contents = true
	_barra_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao.add_child(_barra_fundo)

	_barra = Panel.new()
	_barra.clip_contents = true
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra_fundo.add_child(_barra)

	_brilho = ColorRect.new()
	_brilho.color = Color(1, 1, 1, 0.35)
	_brilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.add_child(_brilho)

	_pct = _rotulo(30, Color(1, 1, 1, 0.92))
	_dica = _rotulo(28, Color(0.80, 0.84, 0.90, 0.95))

	_giro = Control.new()
	_giro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_giro.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_giro.draw.connect(_desenhar_giro)
	_cartao.add_child(_giro)


func _rotulo(tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	_cartao.add_child(l)
	return l


func _caixa(cor_fundo: Color, raio: int, cor_borda: Color = Color.TRANSPARENT, borda: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor_fundo
	sb.set_corner_radius_all(raio)
	if borda > 0:
		sb.border_color = cor_borda
		sb.set_border_width_all(borda)
	sb.anti_aliasing = true
	return sb


func _mostrar_cartao(fase: Dictionary) -> void:
	var tela := _cartao.get_viewport_rect().size
	var s := tela.x / 1080.0
	_cor_fase = fase["cor"]

	var capa_l := tela.x * 0.88
	var capa_a := capa_l * 742.0 / 2120.0
	var capa_y := tela.y * 0.30
	_moldura.position = Vector2((tela.x - capa_l) * 0.5, capa_y)
	_moldura.size = Vector2(capa_l, capa_a)
	_borda.position = _moldura.position
	_borda.size = _moldura.size
	var sb_borda := _caixa(Color.TRANSPARENT, int(6 * s), _cor_fase, int(4 * s))
	sb_borda.draw_center = false
	_borda.add_theme_stylebox_override("panel", sb_borda)
	_halo.position = _moldura.position
	_halo.size = _moldura.size
	var sb_halo := _caixa(Color.BLACK, int(6 * s))
	sb_halo.shadow_color = Color(_cor_fase.r, _cor_fase.g, _cor_fase.b, 0.40)
	sb_halo.shadow_size = int(26 * s)
	_halo.add_theme_stylebox_override("panel", sb_halo)
	_capa.texture = load(fase["capa"]) if ResourceLoader.exists(fase["capa"]) else null
	_capa.position = Vector2.ZERO
	_capa.size = _moldura.size
	_capa.pivot_offset = _moldura.size * 0.5
	_capa.scale = Vector2.ONE

	_titulo.text = fase["nome"]
	_titulo.add_theme_font_size_override("font_size", int(66 * s))
	_titulo.add_theme_color_override("font_color", _cor_fase.lerp(Color.WHITE, 0.35))
	_titulo.position = Vector2(0, capa_y + capa_a + 34 * s)
	_titulo.size = Vector2(tela.x, 90 * s)

	var barra_l := tela.x * 0.64
	var barra_a := 16.0 * s
	var barra_y := capa_y + capa_a + 170 * s
	_barra_fundo.position = Vector2((tela.x - barra_l) * 0.5, barra_y)
	_barra_fundo.size = Vector2(barra_l, barra_a)
	_barra_fundo.add_theme_stylebox_override("panel", _caixa(Color(1, 1, 1, 0.10), int(barra_a * 0.5)))
	_barra.position = Vector2.ZERO
	_barra.size = Vector2(0.0, barra_a)
	_barra.add_theme_stylebox_override("panel", _caixa(_cor_fase, int(barra_a * 0.5)))
	_brilho.size = Vector2(60 * s, barra_a)
	_brilho.position = Vector2(-80 * s, 0)

	_pct.add_theme_font_size_override("font_size", int(30 * s))
	_pct.position = Vector2(0, barra_y + barra_a + 18 * s)
	_pct.size = Vector2(tela.x, 44 * s)
	_pct.text = "0%"

	_giro.position = Vector2(tela.x * 0.5 - 22 * s, capa_y - 120 * s)
	_giro.size = Vector2(44 * s, 44 * s)

	_dica.text = "DICA: " + str(fase["dica"])
	_dica.add_theme_font_size_override("font_size", int(28 * s))
	_dica.position = Vector2(tela.x * 0.1, barra_y + 120 * s)
	_dica.size = Vector2(tela.x * 0.8, 44 * s)

	_mostrado = 0.0
	_alvo = 0.0
	_cartao_t = 0.0
	_cartao.modulate.a = 0.0
	_cartao.visible = true
	set_process(true)
	create_tween().tween_property(_cartao, "modulate:a", 1.0, 0.18)


func _animar_cartao(delta: float) -> void:
	_cartao_t += delta
	# a barra corre atrás do progresso real sem pular nem voltar
	_mostrado = move_toward(_mostrado, _alvo, delta * maxf(0.9, (_alvo - _mostrado) * 4.0))
	_barra.size.x = _barra_fundo.size.x * _mostrado
	if _pct.text != "PRONTO":
		_pct.text = "%d%%" % int(round(_mostrado * 100.0))
	var curso := _barra_fundo.size.x + _brilho.size.x * 2.0
	_brilho.position.x = fmod(_cartao_t * 520.0, curso) - _brilho.size.x * 1.5
	var z := 1.0 + minf(_cartao_t, 4.0) * 0.012
	_capa.scale = Vector2(z, z)
	_giro.queue_redraw()


func _desenhar_giro() -> void:
	var c := _giro.size * 0.5
	var r := _giro.size.x * 0.42
	var a := _cartao_t * 5.5
	Pincel.anel(_giro, c, r, 3.5, Color(1, 1, 1, 0.14))
	Pincel.arco(_giro, c, r, a, a + 1.7, _cor_fase, 3.5)
