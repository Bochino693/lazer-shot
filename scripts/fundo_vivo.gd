class_name FundoVivo
extends Control

## FUNDO VIVO: imagem parada que ganha vida na placa de vídeo.
##
## Os fundos em vídeo (back_init e as prévias do menu) eram decodificados
## pelo processador a cada quadro; na TV Box isso era o grosso das travadas
## do menu. Aqui cada fundo é uma imagem + máscara (shaders/fundo_vivo.gdshader):
## luzes piscando e pulsando com a música, chão/água ondulando, brilho na
## batida, zoom lento e uma faixa de brilho de tempos em tempos. Por cima,
## faíscas subindo (poucas, um único desenho). Custo de processador ~zero.
##
## Uso:
##   var fundo := FundoVivo.new()
##   add_child(fundo)
##   fundo.mostrar("init")            # troca com cruzamento suave
##   fundo.mostrar("deserto")         # pedidos seguidos: vale o último

const SHADER := preload("res://shaders/fundo_vivo.gdshader")
const SHADER_DESERTO := preload("res://shaders/deserto_fundo.gdshader")

## img, máscara e cor de destaque de cada fundo.
const FUNDOS := {
	"init": ["res://sprites/fundo_init.png", "res://sprites/fundo_init_mascara.png", Color(1.0, 0.24, 0.16)],
	"deserto": ["res://sprites/deserto_sol.png", "res://sprites/deserto_sol_mascara.png", Color(1.0, 0.74, 0.34)],
	"mar": ["res://sprites/atlantis.png", "res://sprites/atlantis_mascara.png", Color(0.30, 0.80, 1.0)],
	"bar": ["res://sprites/back_new.png", "res://sprites/back_new_mascara.png", Color(1.0, 0.66, 0.28)],
	"arena": ["res://sprites/arena.png", "res://sprites/arena_mascara.png", Color(1.0, 0.18, 0.30)],
}

## Espera o pedido "parar" antes de trocar (a mira passando por cima de
## vários cartões não fica trocando de fundo) e duração do cruzamento.
const ATRASO_TROCA := 0.18
const TEMPO_TROCA := 0.35
## Tela cheia sempre: a imagem (2:3) corta no máximo isto de cada lateral e o
## resto vira escala, como os vídeos faziam (os logos das bordas não somem).
const CORTE_MAX := 0.03

var _camadas: Dictionary = {}   # chave -> TextureRect
var _atual := ""
var _desejado := ""
var _espera := 0.0
var _tw: Tween = null
var _faiscas: CPUParticles2D = null
var _aquecendo := 0
var _onda := 9.0


## chaves: quais fundos esta tela usa (todos já ficam prontos).
func _init(chaves: Array = ["init"]) -> void:
	name = "FundoVivo"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	for chave in chaves:
		if FUNDOS.has(chave):
			_criar_camada(chave)
	_criar_faiscas()


func _ready() -> void:
	ajustar()
	get_viewport().size_changed.connect(ajustar)
	# Desenha todos os fundos (por baixo do atual, quase transparentes) nos
	# primeiros quadros, ainda sob a transição: o shader é montado e as
	# imagens sobem para a placa agora, e não no primeiro passar da mira por
	# um cartão. (Abaixo de ~0,01 de opacidade o Godot nem desenha.)
	_aquecendo = 3
	for c: TextureRect in _camadas.values():
		c.visible = true
		if c.name != "Fundo_" + _atual:
			c.modulate.a = 0.02


func _criar_camada(chave: String) -> void:
	var dados: Array = FUNDOS[chave]
	var camada := TextureRect.new()
	camada.name = "Fundo_" + chave
	camada.texture = load(dados[0])
	camada.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	camada.stretch_mode = TextureRect.STRETCH_SCALE
	camada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	camada.visible = false
	var cor: Color = dados[2]
	var mat := ShaderMaterial.new()
	if chave == "deserto":
		mat.shader = SHADER_DESERTO
		mat.set_shader_parameter("cor_energia", Vector3(cor.r, cor.g, cor.b))
	else:
		mat.shader = SHADER
		mat.set_shader_parameter("cor", Vector3(cor.r, cor.g, cor.b))
	mat.set_shader_parameter("mascara", load(dados[1]))
	mat.set_shader_parameter("fase", float(_camadas.size()) * 7.3)
	if chave == "init":
		mat.set_shader_parameter("respiro", 0.5)   # títulos e logos perto das bordas
	camada.material = mat
	add_child(camada)
	_camadas[chave] = camada


func _criar_faiscas() -> void:
	var p := CPUParticles2D.new()
	p.name = "Faiscas"
	p.amount = 34
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(0, -1)
	p.spread = 14.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 55.0
	p.initial_velocity_max = 150.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.95
	p.texture = brilho_redondo()
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	rampa.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	p.color_ramp = rampa
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	add_child(p)
	_faiscas = p


## Pontinho de luz redondo (32 px) para as faíscas.
static func brilho_redondo() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 32
	t.height = 32
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	return t


func ajustar() -> void:
	var tela := get_viewport_rect().size
	position = Vector2.ZERO
	size = tela
	for c: TextureRect in _camadas.values():
		var img: Vector2 = c.texture.get_size()
		var tam := tela
		var largura_cheia := tela.y * img.x / img.y
		if largura_cheia > tela.x:
			tam.x = minf(largura_cheia, tela.x / (1.0 - 2.0 * CORTE_MAX))
		else:
			tam.y = minf(tela.x * img.y / img.x, tela.y / (1.0 - 2.0 * CORTE_MAX))
		c.position = ((tela - tam) * 0.5).round()
		c.size = tam.round()
	if _faiscas != null:
		_faiscas.position = Vector2(tela.x * 0.5, tela.y + 12.0)
		_faiscas.emission_rect_extents = Vector2(tela.x * 0.5, 16.0)


## Pede um fundo. imediato = troca já (sem esperar o pedido parar).
func mostrar(chave: String, imediato: bool = false) -> void:
	if not _camadas.has(chave):
		return
	if _atual == "":
		_trocar(chave, false)
		return
	if chave != _desejado:
		_desejado = chave
		_espera = 0.0
	if imediato:
		_espera = maxf(_espera, ATRASO_TROCA)


func atual() -> String:
	return _atual


func _process(delta: float) -> void:
	if _aquecendo > 0:
		_aquecendo -= 1
		if _aquecendo == 0:
			for chave: String in _camadas:
				var c: TextureRect = _camadas[chave]
				if chave != _atual:
					c.visible = false
					c.modulate.a = 0.0

	if _desejado != "" and _desejado != _atual:
		_espera += delta
		if _espera >= ATRASO_TROCA and not (_tw != null and _tw.is_valid() and _tw.is_running()):
			_trocar(_desejado, true)
	else:
		_espera = 0.0

	# música -> shader (só nas camadas à mostra: no máximo duas)
	var som := Maquina.pulso_vivo()
	if som.y > 0.55 and _onda > 0.62:
		_onda = 0.0
	_onda = minf(_onda + delta * 0.85, 9.0)
	for c: TextureRect in _camadas.values():
		if c.visible and c.modulate.a > 0.01:
			var mat := c.material as ShaderMaterial
			mat.set_shader_parameter("grave", som.x)
			mat.set_shader_parameter("batida", som.y)
			if c.name == "Fundo_deserto":
				mat.set_shader_parameter("onda", _onda)
	if _faiscas != null:
		_faiscas.speed_scale = 1.0 + som.y * 0.9


func _trocar(chave: String, suave: bool) -> void:
	var novo: TextureRect = _camadas[chave]
	var velho: TextureRect = _camadas.get(_atual)
	_atual = chave
	_desejado = chave
	_espera = 0.0
	var cor: Color = FUNDOS[chave][2]
	if _faiscas != null:
		_faiscas.color = cor.lerp(Color.WHITE, 0.35)

	move_child(novo, _faiscas.get_index() - 1 if _faiscas != null else -1)
	novo.visible = true
	if not suave or velho == null or velho == novo:
		novo.modulate.a = 1.0
		for c: TextureRect in _camadas.values():
			if c != novo and _aquecendo == 0:
				c.visible = false
		return
	novo.modulate.a = 0.0
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(novo, "modulate:a", 1.0, TEMPO_TROCA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_callback(func() -> void:
		for c: TextureRect in _camadas.values():
			if c != novo:
				c.visible = false
				c.modulate.a = 0.0
	)
