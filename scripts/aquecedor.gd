class_name Aquecedor
extends Node2D

## PRÉ-AQUECIMENTO: desenha uma vez, escondido, tudo o que a placa de vídeo
## prepara na primeira vez que aparece.
##
## Na TV Box, a primeira vez que um shader é usado a placa compila o
## programa (centenas de milissegundos num shader grande), a primeira vez que
## uma imagem aparece ela sobe para a placa e a primeira vez que uma letra
## aparece num tamanho a fonte é desenhada. Se isso acontece no meio do jogo,
## é uma travada. Aqui acontece antes, debaixo de uma tela opaca:
##
##   Aquecedor.tudo(no)         na partida do app (debaixo do preto da
##                              apresentação): todos os shaders do jogo nos
##                              jeitos em que são desenhados (retângulo,
##                              polígono, partículas) e a mistura somada
##   Aquecedor.cena(cena, no)   em cada troca de tela (debaixo do cartão de
##                              carregamento): as imagens, os materiais, as
##                              partículas e os textos da tela nova, inclusive
##                              o que ainda está escondido (instruções,
##                              contagem, fim de jogo)
##
## Os itens ficam 3 quadros e somem. Com o cache de shaders do Godot, da
## segunda vez em diante a placa só lê o programa já pronto.

const Pincel := preload("res://scripts/pincel.gd")
const QUADROS := 3
## Todos os shaders do jogo (o do vídeo pelo hardware fica de fora: só monta
## com o vídeo de verdade).
const SHADERS := [
	preload("res://shaders/abertura_fundo.gdshader"),
	preload("res://shaders/abertura_logo.gdshader"),
	preload("res://shaders/bar_sol.gdshader"),
	preload("res://shaders/deserto_fundo.gdshader"),
	preload("res://shaders/egito_cristal.gdshader"),
	preload("res://shaders/egito_raios.gdshader"),
	preload("res://shaders/fundo_vivo.gdshader"),
	preload("res://shaders/mar_baleia.gdshader"),
	preload("res://shaders/mar_cardume.gdshader"),
	preload("res://shaders/mar_cascata.gdshader"),
	preload("res://shaders/mar_pedra.gdshader"),
	preload("res://shaders/mar_recorte.gdshader"),
]
## Números e sinais que aparecem depois (placar, contagem, pontos).
const SINAIS := " 0123456789:+-%/!?.,x×"

var _texturas: Array[Texture2D] = []
var _quadros := QUADROS
static var _branca: Texture2D = null


## Na partida do app: todos os shaders e materiais, sem textos.
static func tudo(onde: Node) -> Aquecedor:
	var a := Aquecedor.new()
	a.name = "Aquecedor"
	for sh in SHADERS:
		var m := ShaderMaterial.new()
		m.shader = sh
		a._material(m)
	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	a._material(soma)
	a._material(null)
	a._particulas(soma, Pincel.TEXTURA)
	a._particulas(null, Pincel.TEXTURA)
	a._texturas.append(Pincel.TEXTURA)
	a._pendurar(onde)
	return a


## Numa troca de tela: o que a cena nova usa, inclusive o escondido.
static func cena(raiz: Node, onde: Node) -> Aquecedor:
	var a := Aquecedor.new()
	a.name = "Aquecedor"
	var vistos := {}
	a._varrer(raiz, vistos)
	a._pendurar(onde)
	return a


func _pendurar(onde: Node) -> void:
	position = Vector2.ZERO
	z_index = -4096
	onde.add_child(self)
	onde.move_child(self, 0)   # primeiro filho: desenha embaixo de tudo


func _process(_delta: float) -> void:
	_quadros -= 1
	if _quadros <= 0:
		queue_free()


func _draw() -> void:
	for tex in _texturas:
		if tex != null:
			draw_texture_rect(tex, Rect2(0, 0, 4, 4), false)


func _varrer(n: Node, vistos: Dictionary) -> void:
	if n is CanvasItem:
		var ci := n as CanvasItem
		if ci.material != null and not vistos.has(ci.material):
			vistos[ci.material] = true
			_material(ci.material)
		if n is Sprite2D:
			_textura((n as Sprite2D).texture, vistos)
		elif n is TextureRect:
			_textura((n as TextureRect).texture, vistos)
		elif n is NinePatchRect:
			_textura((n as NinePatchRect).texture, vistos)
		elif n is AnimatedSprite2D:
			var sf := (n as AnimatedSprite2D).sprite_frames
			if sf != null and not vistos.has(sf):
				vistos[sf] = true
				for anim in sf.get_animation_names():
					for i in sf.get_frame_count(anim):
						_textura(sf.get_frame_texture(anim, i), vistos)
		elif n is CPUParticles2D:
			var p := n as CPUParticles2D
			_textura(p.texture, vistos)
			var chave := [p.material, p.texture]
			if not vistos.has(chave):
				vistos[chave] = true
				_particulas(p.material, p.texture)
		elif n is Label or n is RichTextLabel:
			_texto(n as Control, vistos)
	for c in n.get_children():
		_varrer(c, vistos)


func _textura(tex: Texture2D, vistos: Dictionary) -> void:
	if tex == null:
		return
	if tex is AtlasTexture and (tex as AtlasTexture).atlas != null:
		tex = (tex as AtlasTexture).atlas
	if vistos.has(tex):
		return
	vistos[tex] = true
	_texturas.append(tex)


## Um retângulo e um polígono com o material (os dois jeitos de desenhar).
func _material(m: Material) -> void:
	var r := TextureRect.new()
	r.texture = _textura_branca()
	r.size = Vector2(4, 4)
	r.material = m
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(0, 4)])
	p.material = m
	add_child(p)


## Partículas desenham por instâncias: outro programa na placa.
func _particulas(m: Material, tex: Texture2D) -> void:
	var p := CPUParticles2D.new()
	p.amount = 2
	p.lifetime = 0.2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	p.texture = tex
	p.material = m
	p.scale_amount_min = 0.02
	p.scale_amount_max = 0.02
	add_child(p)
	p.emitting = true


## Cópia do texto (mesma fonte, tamanho e contorno) com os números juntos:
## as letras ficam prontas na fonte antes de aparecerem de verdade.
func _texto(c: Control, vistos: Dictionary) -> void:
	var chave := ""
	var copia: Control = c.duplicate(0) as Control
	if copia == null:
		return
	if copia is Label:
		var l := copia as Label
		var ls := l.label_settings
		chave = "L%s|%d|%d|%s" % [ls.font.resource_path if ls != null and ls.font != null else "", ls.font_size if ls != null else l.get_theme_font_size("font_size"), ls.outline_size if ls != null else 0, l.text + SINAIS]
		l.text = l.text + SINAIS
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	else:
		var rt := copia as RichTextLabel
		chave = "R%d|%s" % [rt.get_theme_font_size("normal_font_size"), rt.text]
	if vistos.has(chave):
		copia.free()
		return
	vistos[chave] = true
	copia.visible = true
	copia.modulate = Color(1, 1, 1, 0.02)
	copia.position = Vector2.ZERO
	copia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(copia)


static func _textura_branca() -> Texture2D:
	if _branca == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_branca = ImageTexture.create_from_image(img)
	return _branca
