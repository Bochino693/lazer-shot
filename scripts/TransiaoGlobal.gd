extends CanvasLayer

## Troca de tela sem tela cinza e sem tranco.
##
## 1. escurece (a tela atual some no preto);
## 2. a próxima cena é carregada numa thread enquanto a tela está preta
##    (o jogo não congela; se demorar aparece um anel girando);
## 3. troca a cena, espera ela montar e desenhar os primeiros quadros
##    escondida no preto (é aí que o Godot prepara shaders e texturas);
## 4. clareia.
## A cor de fundo padrão vira preta, então nem no boot nem entre cenas
## aparece o cinza do Godot.
##
## Uso: TransicaoGlobal.trocar_cena("res://scenes/main.tscn")
##      TransicaoGlobal.trocar_cena(caminho, 0.0)  # se a cena já escureceu

const Pincel := preload("res://scripts/pincel.gd")

const TEMPO_SAIDA := 0.22
const TEMPO_ENTRADA := 0.30
const QUADROS_ESCONDIDOS := 3
const ESPERA_ANTES_DO_ANEL := 0.45

signal cena_trocada(caminho: String)

var fade: ColorRect
var em_transicao: bool = false

var _anel: Control
var _anel_t := 0.0


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
	set_process(false)


func trocar_cena(caminho: String, tempo_saida: float = TEMPO_SAIDA, tempo_entrada: float = TEMPO_ENTRADA) -> void:
	if em_transicao:
		return
	if caminho == "" or not ResourceLoader.exists(caminho):
		push_error("Cena não encontrada: " + caminho)
		return

	em_transicao = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Começa a carregar já, em paralelo com o escurecer.
	var pediu := ResourceLoader.load_threaded_request(caminho, "PackedScene", true) == OK

	fade.visible = true
	if tempo_saida <= 0.0:
		fade.color.a = 1.0
	else:
		var tw_out := create_tween()
		tw_out.tween_property(fade, "color:a", 1.0, tempo_saida * (1.0 - fade.color.a))
		await tw_out.finished

	var cena: PackedScene = null
	if pediu:
		var inicio := Time.get_ticks_msec()
		while true:
			var estado := ResourceLoader.load_threaded_get_status(caminho)
			if estado == ResourceLoader.THREAD_LOAD_LOADED:
				cena = ResourceLoader.load_threaded_get(caminho) as PackedScene
				break
			if estado == ResourceLoader.THREAD_LOAD_FAILED or estado == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				break
			await get_tree().process_frame
			if (Time.get_ticks_msec() - inicio) > ESPERA_ANTES_DO_ANEL * 1000.0 and not _anel.visible:
				_mostrar_anel(true)
	if cena == null:
		cena = load(caminho) as PackedScene

	if cena == null or get_tree().change_scene_to_packed(cena) != OK:
		push_error("Não foi possível abrir a cena: " + caminho)
	else:
		# A cena nova monta e desenha os primeiros quadros escondida.
		for i in range(QUADROS_ESCONDIDOS):
			await get_tree().process_frame
		cena_trocada.emit(caminho)

	_mostrar_anel(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	var tw_in := create_tween()
	tw_in.tween_property(fade, "color:a", 0.0, tempo_entrada).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw_in.finished

	fade.visible = false
	em_transicao = false


## Escurece a tela sem trocar de cena (para quem precisa do preto antes).
func escurecer(tempo: float = TEMPO_SAIDA) -> void:
	fade.visible = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, tempo)
	await tw.finished


func _mostrar_anel(sim: bool) -> void:
	_anel.visible = sim
	_anel_t = 0.0
	set_process(sim)


func _process(delta: float) -> void:
	_anel_t += delta
	_anel.queue_redraw()


func _desenhar_anel() -> void:
	var tela := _anel.get_viewport_rect().size
	var centro := Vector2(tela.x * 0.5, tela.y * 0.5)
	var a := _anel_t * 5.0
	var surgir := clampf(_anel_t / 0.3, 0.0, 1.0)
	Pincel.anel(_anel, centro, 26.0, 4.0, Color(1, 1, 1, 0.12 * surgir))
	Pincel.arco(_anel, centro, 26.0, a, a + 1.6, Color(1.0, 0.25, 0.2, 0.9 * surgir), 4.0)
