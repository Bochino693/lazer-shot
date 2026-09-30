extends Area2D

signal arco_destruido

@export var tempo_hit: float = 0.35
@export var pontos: int = 100

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var colisao: CollisionShape2D = $CollisionShape2D

var atingido: bool = false

func _ready() -> void:
	input_pickable = true
	resetar()

func resetar() -> void:
	atingido = false
	visible = true

	if colisao != null:
		colisao.disabled = false

	if anim != null and anim.sprite_frames != null:
		if anim.sprite_frames.has_animation("idle"):
			anim.play("idle")

func receber_tiro(pos_mouse_global: Vector2) -> bool:
	if atingido:
		return false

	if not visible:
		return false

	if not _clicou_no_alvo(pos_mouse_global):
		return false

	atingido = true

	if colisao != null:
		colisao.disabled = true

	if anim != null and anim.sprite_frames != null and anim.sprite_frames.has_animation("hit"):
		anim.play("hit")
	else:
		if anim != null:
			anim.stop()

	await get_tree().create_timer(tempo_hit).timeout

	visible = false
	emit_signal("arco_destruido")
	return true

func _clicou_no_alvo(pos_mouse_global: Vector2) -> bool:
	var space_state := get_world_2d().direct_space_state
	var parametros := PhysicsPointQueryParameters2D.new()
	parametros.position = pos_mouse_global
	parametros.collide_with_areas = true
	parametros.collide_with_bodies = false

	var resultado := space_state.intersect_point(parametros, 16)

	for item in resultado:
		if item.collider == self:
			return true

	return false
