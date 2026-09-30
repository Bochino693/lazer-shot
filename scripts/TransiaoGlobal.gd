extends CanvasLayer

var fade: ColorRect
var em_transicao: bool = false

func _ready() -> void:
	layer = 9999

	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color.BLACK
	fade.visible = false
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

	process_mode = Node.PROCESS_MODE_ALWAYS


func trocar_cena(caminho: String) -> void:
	if em_transicao:
		return

	if caminho == "" or not ResourceLoader.exists(caminho):
		push_error("Cena não encontrada: " + caminho)
		return

	em_transicao = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	fade.visible = true
	fade.color = Color(0, 0, 0, 0)

	var tw_out := create_tween()
	tw_out.tween_property(fade, "color:a", 1.0, 0.25)
	await tw_out.finished

	get_tree().change_scene_to_file(caminho)

	await get_tree().process_frame
	await get_tree().process_frame

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	var tw_in := create_tween()
	tw_in.tween_property(fade, "color:a", 0.0, 0.35)
	await tw_in.finished

	fade.visible = false
	em_transicao = false
