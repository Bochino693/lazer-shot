extends Area2D

signal acertada(pontos: int, garrafa: Area2D, pos_global: Vector2)

@export var pontos: int = 20
@export var escala_garrafa: float = 1.0
@export var offset_vertical_prateleira: float = -52.0
@export var ajuste_colisao_largura: float = 0.57
@export var ajuste_colisao_altura: float = 0.86
@export var deslocamento_colisao_y: float = -2.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var colisao: CollisionShape2D = $CollisionShape2D

var destruida: bool = false
var saindo: bool = false
var posicao_final: Vector2 = Vector2.ZERO

var sombra_alpha_base: float = 0.28
var sombra_escala_base: Vector2 = Vector2(0.85, 0.30)
var sombra_offset: Vector2 = Vector2(0.0, 12.0)


func _ready() -> void:
	visible = true
	show()
	input_pickable = true
	monitoring = true
	monitorable = true
	top_level = false
	z_index = 6
	scale = Vector2.ONE * escala_garrafa

	if anim == null:
		push_error("AnimatedSprite2D não encontrado.")
		return

	anim.visible = true
	anim.show()
	anim.centered = true
	anim.position = Vector2.ZERO
	anim.scale = Vector2.ONE
	anim.z_index = 1
	anim.speed_scale = 1.0

	if anim.sprite_frames == null:
		push_error("AnimatedSprite2D sem SpriteFrames.")
		return

	if anim.sprite_frames.has_animation("hit"):
		anim.sprite_frames.set_animation_loop("hit", false)

	if anim.sprite_frames.has_animation("idle"):
		anim.play("idle")

	_configurar_ambiente_por_pontos()
	_configurar_colisao()


func _configurar_ambiente_por_pontos() -> void:
	match pontos:
		100:
			sombra_alpha_base = 0.22
			sombra_escala_base = Vector2(0.58, 0.18)
			sombra_offset = Vector2(0.0, 8.0)
		80:
			sombra_alpha_base = 0.25
			sombra_escala_base = Vector2(0.70, 0.21)
			sombra_offset = Vector2(0.0, 9.0)
		50:
			sombra_alpha_base = 0.29
			sombra_escala_base = Vector2(0.82, 0.25)
			sombra_offset = Vector2(0.0, 11.0)
		20:
			sombra_alpha_base = 0.35
			sombra_escala_base = Vector2(0.98, 0.32)
			sombra_offset = Vector2(0.0, 13.0)
			

func _configurar_colisao() -> void:
	if colisao == null:
		push_error("CollisionShape2D não encontrado.")
		return

	colisao.disabled = false

	var tamanho_sprite := _obter_tamanho_base_sprite()
	if tamanho_sprite.x <= 0.0 or tamanho_sprite.y <= 0.0:
		tamanho_sprite = Vector2(110.0, 230.0)

	# Colisão mais estreita e mais baixa que o sprite inteiro,
	# para exigir que o alvo fique realmente em cima da garrafa.
	var tamanho_final := Vector2(
		tamanho_sprite.x * ajuste_colisao_largura,
		tamanho_sprite.y * ajuste_colisao_altura
	)

	colisao.position = Vector2(0.0, deslocamento_colisao_y)

	if colisao.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = tamanho_final
		colisao.shape = rect
	elif colisao.shape is RectangleShape2D:
		var rect_shape := colisao.shape as RectangleShape2D
		rect_shape.size = tamanho_final


func _obter_tamanho_base_sprite() -> Vector2:
	if anim == null or anim.sprite_frames == null:
		return Vector2.ZERO

	var nomes_teste := ["idle", "hit"]

	for nome in nomes_teste:
		if anim.sprite_frames.has_animation(nome):
			var total_frames: int = anim.sprite_frames.get_frame_count(nome)
			if total_frames > 0:
				var tex: Texture2D = anim.sprite_frames.get_frame_texture(nome, 0)
				if tex != null:
					return tex.get_size()

	return Vector2.ZERO


func configurar_posicao(pos_local_final: Vector2) -> void:
	posicao_final = pos_local_final + Vector2(0.0, offset_vertical_prateleira)

	# pequena entrada na madeira para tirar o efeito de flutuação
	position = posicao_final + Vector2(0.0, 8.0)

	scale = Vector2.ONE * escala_garrafa
	_configurar_ambiente_por_pontos()
	_configurar_colisao()

	modulate.a = 1.0
	rotation_degrees = 0.0
	destruida = false
	saindo = false
	visible = true
	show()

	if colisao != null:
		colisao.disabled = false

	if anim != null and anim.sprite_frames != null and anim.sprite_frames.has_animation("idle"):
		anim.stop()
		anim.play("idle")


func animar_entrada(distancia_subida: float = 90.0) -> void:
	visible = true
	modulate.a = 0.0
	scale = Vector2.ONE * (escala_garrafa * 0.72)

	var destino := position
	position = destino + Vector2(0.0, distancia_subida)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(self, "position", destino + Vector2(0.0, -10.0), 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.tween_property(self, "modulate:a", 1.0, 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_property(self, "scale", Vector2.ONE * (escala_garrafa * 1.06), 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tween.finished

	var tween2 := create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(self, "position", destino, 0.09)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween2.tween_property(self, "scale", Vector2.ONE * escala_garrafa, 0.10)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func animar_saida() -> void:
	if saindo or destruida:
		return

	saindo = true

	if colisao != null:
		colisao.disabled = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 26.0, 0.14)
	tween.tween_property(self, "modulate:a", 0.0, 0.14)
	tween.tween_property(self, "rotation_degrees", 12.0, 0.12)
	await tween.finished

	if is_inside_tree():
		queue_free()


func receber_tiro() -> void:
	if destruida or saindo:
		return

	destruida = true

	if colisao != null:
		colisao.disabled = true

	acertada.emit(pontos, self, global_position)

	if anim != null and anim.sprite_frames != null and anim.sprite_frames.has_animation("hit"):
		anim.stop()
		anim.play("hit")

	var tween_impacto := create_tween()
	tween_impacto.set_parallel(true)
	tween_impacto.tween_property(self, "scale", Vector2.ONE * escala_garrafa * 1.20, 0.05)
	tween_impacto.tween_property(self, "rotation_degrees", randf_range(-10.0, 10.0), 0.05)
	await tween_impacto.finished

	if anim != null and anim.sprite_frames != null and anim.sprite_frames.has_animation("hit"):
		await anim.animation_finished
	else:
		await get_tree().create_timer(0.15).timeout

	var tween_saida := create_tween()
	tween_saida.set_parallel(true)
	tween_saida.tween_property(self, "scale", Vector2.ONE * escala_garrafa * 1.34, 0.10)
	tween_saida.tween_property(self, "modulate:a", 0.0, 0.10)
	tween_saida.tween_property(self, "rotation_degrees", randf_range(-22.0, 22.0), 0.10)
	await tween_saida.finished

	if is_inside_tree():
		queue_free()


func contem_ponto_global(ponto_global: Vector2) -> bool:
	if destruida or saindo:
		return false

	if colisao == null or colisao.shape == null or colisao.disabled:
		return false

	var local_no_shape: Vector2 = colisao.to_local(ponto_global)

	if colisao.shape is RectangleShape2D:
		var rect_shape := colisao.shape as RectangleShape2D
		var metade: Vector2 = rect_shape.size * 0.5

		return (
			local_no_shape.x >= -metade.x and local_no_shape.x <= metade.x and
			local_no_shape.y >= -metade.y and local_no_shape.y <= metade.y
		)

	return false


func _draw() -> void:
	_desenhar_sombra_base()


func _desenhar_sombra_base() -> void:
	var centro := sombra_offset
	var rx: float = 38.0 * sombra_escala_base.x
	var ry: float = 14.0 * sombra_escala_base.y

	var pontos_sombra := PackedVector2Array()
	var passos: int = 28

	for i in range(passos):
		var ang: float = (float(i) / float(passos)) * TAU
		pontos_sombra.append(centro + Vector2(cos(ang) * rx, sin(ang) * ry))

	draw_colored_polygon(pontos_sombra, Color(0.0, 0.0, 0.0, sombra_alpha_base * 1.12))
	draw_polyline(pontos_sombra, Color(0.0, 0.0, 0.0, sombra_alpha_base * 0.26), 1.0, true)

	var pontos_sombra2 := PackedVector2Array()
	for i in range(passos):
		var ang2: float = (float(i) / float(passos)) * TAU
		pontos_sombra2.append(centro + Vector2(cos(ang2) * rx * 0.62, sin(ang2) * ry * 0.58))

	draw_colored_polygon(pontos_sombra2, Color(0.0, 0.0, 0.0, sombra_alpha_base * 0.34))
