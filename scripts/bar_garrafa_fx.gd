class_name BarGarrafaFx
extends Node2D

## Como as garrafas do Bar chegam, ficam e saem da prateleira.
##   vestir()  sombras que dão profundidade: a da garrafa na parede de trás
##             (a luz vem da janela, no alto à esquerda) e a de contato na
##             tábua; as duas são filhas do desenho da garrafa (somem com ela)
##   entrar()  a garrafa cai do alto na tábua, o vidro assenta (achata e volta
##             balançando, presa pela base), sobe um pó fino da madeira, um
##             brilho corre no ombro da garrafa e soa o toque do vidro na tábua
##   sair()    a garrafa é tirada da prateleira: sobe um pouco e some
## O nó desta classe é o pó do pouso (um por garrafa, some em ~0,7 s).

const SOM_POUSO := preload("res://songs/garrafa_pousa.wav")
const LODO := preload("res://sprites/mar_lodo.png")
const QUEDA_PX := 120.0
const TEMPO_QUEDA := 0.23
const TEMPO_ASSENTAR := 0.46
const GRUPO_SOM := "bar_som_pouso"

var _puffs: Array[Dictionary] = []
var _t := 0.0
# entrada (nó filho da garrafa)
var _entrando := false
var _pousou_ja := false
var _pai: Node
var _alvo: Area2D
var _escala := 1.0
var _meia := 200.0
var _final_y := 0.0
var _base := Vector2.ZERO


## Metade da altura do desenho da garrafa (px da textura, sem a escala).
static func meia_altura(anim: AnimatedSprite2D) -> float:
	if anim == null or anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim.animation):
		return 200.0
	var q := anim.sprite_frames.get_frame_texture(anim.animation, 0)
	return q.get_size().y * 0.5 if q != null else 200.0


static func vestir(anim: AnimatedSprite2D) -> void:
	if anim == null or anim.sprite_frames == null or anim.get_node_or_null("SombraParede") != null:
		return
	if not anim.sprite_frames.has_animation(anim.animation):
		return
	var quadro := anim.sprite_frames.get_frame_texture(anim.animation, 0)
	if quadro == null:
		return
	var tam := quadro.get_size()
	# a sombra na parede de trás: o contorno da própria garrafa, escuro e
	# transparente, empurrado para a direita e inclinado (luz da janela)
	var parede := Sprite2D.new()
	parede.name = "SombraParede"
	parede.texture = quadro
	parede.show_behind_parent = true
	parede.modulate = Color(0.10, 0.05, 0.02, 0.42)
	parede.position = Vector2(tam.x * 0.30, -tam.y * 0.035)
	parede.skew = 0.2
	anim.add_child(parede)
	# a sombra de contato embaixo, na tábua
	var chao := Sprite2D.new()
	chao.name = "SombraChao"
	chao.texture = FundoVivo.brilho_redondo()
	chao.show_behind_parent = true
	chao.modulate = Color(0.06, 0.03, 0.0, 0.8)
	chao.position = Vector2(tam.x * 0.12, tam.y * 0.5 - 2.0)
	chao.scale = Vector2(tam.x * 1.8, 34.0) / 32.0
	anim.add_child(chao)


## A garrafa chega: cai do alto até a posição final (pos_final: o centro da
## garrafa já na tábua) e assenta pela base. Quem anima é um nó filho da
## garrafa (some com ela se for acertada no caminho).
static func entrar(pai: Node, alvo: Area2D, pos_final: Vector2, escala: float) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return
	var e := BarGarrafaFx.new()
	e.name = "Entrada"
	e._pai = pai
	e._alvo = alvo
	e._escala = escala
	e._meia = meia_altura(_anim(alvo))
	e._final_y = pos_final.y
	e._base = Vector2(pos_final.x, pos_final.y + e._meia * escala)
	e._entrando = true
	alvo.position = pos_final - Vector2(0.0, QUEDA_PX)
	alvo.modulate.a = 0.0
	alvo.add_child(e)


func _passo_entrada(delta: float) -> void:
	var alvo := _alvo
	if not is_instance_valid(alvo) or alvo.get("ja_acertado") == true or alvo.get("saindo_individual") == true:
		queue_free()
		return
	_t += delta
	if _t < TEMPO_QUEDA:
		var u := _t / TEMPO_QUEDA
		alvo.modulate.a = minf(1.0, _t / 0.09)
		alvo.position.y = _final_y - QUEDA_PX * (1.0 - u * u)
		return
	if not _pousou_ja:
		_pousou_ja = true
		alvo.modulate.a = 1.0
		_pousou(_pai, alvo, _base, _escala, _meia)
	# achata ao bater e volta balançando, sempre com a base na tábua
	var v := (_t - TEMPO_QUEDA) / TEMPO_ASSENTAR
	var k := 1.0 if v >= 1.0 else 1.0 - 0.13 * exp(-5.0 * v) * cos(v * 10.0)
	alvo.scale = Vector2(_escala / sqrt(k), _escala * k)
	alvo.position.y = _base.y - _meia * _escala * k
	if v >= 1.0:
		queue_free()


static func _pousou(pai: Node, alvo: Area2D, base: Vector2, escala: float, meia: float) -> void:
	if not is_instance_valid(alvo) or pai == null or not is_instance_valid(pai) or not pai.is_inside_tree():
		return
	var po := BarGarrafaFx.new()
	po.z_index = 7
	pai.add_child(po)
	po._montar(base, 150.0 * escala)
	# brilho correndo no ombro da garrafa (pega a luz ao assentar)
	var anim := _anim(alvo)
	if anim != null:
		var brilho := Sprite2D.new()
		brilho.texture = FundoVivo.brilho_redondo()
		var soma := CanvasItemMaterial.new()
		soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		brilho.material = soma
		brilho.position = Vector2(-meia * 0.12, -meia * 0.45)
		brilho.scale = Vector2.ONE * 3.2
		brilho.modulate = Color(1.0, 0.92, 0.75, 0.0)
		anim.add_child(brilho)
		var tw := brilho.create_tween()
		tw.tween_property(brilho, "modulate:a", 0.75, 0.06)
		tw.parallel().tween_property(brilho, "position:y", meia * 0.25, 0.32).set_trans(Tween.TRANS_SINE)
		tw.tween_property(brilho, "modulate:a", 0.0, 0.14)
		tw.tween_callback(brilho.queue_free)
	# o toque do vidro na tábua (no máximo um a cada 0,1 s: o começo enche
	# as prateleiras de uma vez)
	var arvore := pai.get_tree()
	var agora := Time.get_ticks_msec()
	if agora - int(arvore.get_meta(GRUPO_SOM, -1000)) >= 100:
		arvore.set_meta(GRUPO_SOM, agora)
		Maquina.efeito(SOM_POUSO, -13.0, randf_range(0.9, 1.12))


## A garrafa é tirada da prateleira: sobe um pouco, afina e some.
static func sair(alvo: Area2D, duracao := 0.26) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return
	var tw := alvo.create_tween()
	tw.set_parallel(true)
	tw.tween_property(alvo, "position:y", alvo.position.y - 38.0, duracao).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(alvo, "modulate:a", 0.0, duracao * 0.85)
	tw.tween_property(alvo, "scale", alvo.scale * Vector2(0.94, 1.03), duracao)


static func _anim(alvo: Area2D) -> AnimatedSprite2D:
	for filho in alvo.get_children():
		if filho is AnimatedSprite2D:
			return filho
	return null


# ───────────────────────────────────────────── o pó do pouso
func _montar(base: Vector2, largura: float) -> void:
	for i in 6:
		var lado := -1.0 if i % 2 == 0 else 1.0
		_puffs.append({
			"pos": base + Vector2(lado * randf_range(0.1, 0.4) * largura, randf_range(-3, 2)),
			"vel": Vector2(lado * randf_range(40.0, 110.0), randf_range(-26.0, -6.0)),
			"tam": randf_range(18.0, 30.0), "ang": randf() * TAU, "vida": randf_range(0.45, 0.7),
		})


func _process(delta: float) -> void:
	if _entrando:
		_passo_entrada(delta)
		return
	_t += delta
	if _t > 0.75:
		queue_free()
		return
	for p in _puffs:
		p["vel"] = p["vel"] * pow(0.04, delta)
		p["pos"] += p["vel"] * delta
	queue_redraw()


func _draw() -> void:
	for p in _puffs:
		var k: float = _t / p["vida"]
		if k >= 1.0:
			continue
		var s: float = p["tam"] * (0.6 + 1.0 * k)
		draw_set_transform(p["pos"], p["ang"], Vector2(1.0, 0.55))
		draw_texture_rect(LODO, Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), false,
			Color(0.86, 0.68, 0.46, 0.42 * (1.0 - k) * minf(1.0, k * 10.0)))
	draw_set_transform(Vector2.ZERO)
