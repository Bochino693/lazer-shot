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
##   Aquecedor.shaders(lista, no)   numa troca de tela, ANTES de a tela nova
##                              entrar (com o cartão de carregamento à vista):
##                              os shaders dela, UM POR QUADRO, nos jeitos em
##                              que são desenhados (retângulo, polígono e, nos
##                              cardumes, instâncias). A lista de cada tela vem
##                              de scripts/precarga.gd (tools/gerar_precarga.py)
##   Aquecedor.cena(cena, no)   logo depois que ela entra (ainda no preto):
##                              as imagens, os materiais, as partículas e os
##                              textos da tela nova, inclusive o que ainda está
##                              escondido (instruções, contagem, fim de jogo)
##
## UM POR QUADRO, e nunca na partida do app: na Mali-G31 da TV Box, montar
## todos os shaders do jogo no mesmo quadro segurava a placa por vários
## segundos logo ao abrir; com a arma mexendo, o Android dava o app como
## travado e fechava antes até da apresentação (Rodada 23). A apresentação
## só usa os dois shaders dela, pequenos.
##
## Os itens ficam poucos quadros e somem. Um shader montado fica pronto
## enquanto o recurso dele existir (os pré-carregados pelos scripts ficam a
## sessão inteira); com o cache de shaders do Godot, da segunda vez em diante
## a placa só lê o programa já pronto.

const Pincel := preload("res://scripts/pincel.gd")
const QUADROS := 3
## Shaders desenhados por instâncias (MultiMesh): outro programa na placa.
const INSTANCIADOS := ["res://shaders/mar_cardume.gdshader"]
## Números e sinais que aparecem depois (placar, contagem, pontos).
const SINAIS := " 0123456789:+-%/!?.,x×"

## Fim da fila de shaders.
signal terminou

## Shaders já montados nesta sessão: caminho -> WeakRef do recurso. Se o
## recurso ainda é o mesmo, o programa dele continua na placa.
static var _montados: Dictionary = {}
## Os jeitos de desenhar do material comum e da luz somada (retângulo,
## polígono, linha e partículas), que todos os efeitos de acerto usam: uma vez
## por sessão, na primeira troca de tela (não no primeiro tiro).
static var _base_feita := false
const BASE := "__base__"

var _texturas: Array[Texture2D] = []
var _quadros := QUADROS
# fila de shaders (Aquecedor.shaders)
var _fila: Array[String] = []
var _total := -1          # -1: não é fila
var _feitos := 0
var _acabou := false
static var _branca: Texture2D = null


## Quantos shaders da lista ainda não estão prontos na placa.
static func faltam(caminhos: Array) -> int:
	var n := 0 if _base_feita else 1
	for c in caminhos:
		if not _pronto(c):
			n += 1
	return n


## Numa troca de tela, antes de a tela nova entrar: monta os shaders dela,
## um por quadro. Espere `terminou` (ou consulte acabou()/progresso()).
static func shaders(caminhos: Array, onde: Node) -> Aquecedor:
	var a := Aquecedor.new()
	a.name = "AquecedorShaders"
	if not _base_feita:
		a._fila.append(BASE)
	for c in caminhos:
		if not _pronto(c) and ResourceLoader.exists(c):
			a._fila.append(c)
	a._total = a._fila.size()
	a._pendurar(onde)
	return a


static func _pronto(caminho: String) -> bool:
	var ref: WeakRef = _montados.get(caminho)
	if ref == null or ref.get_ref() == null:
		return false
	# o mesmo recurso que está carregado agora (senão é outro programa)
	return ResourceLoader.has_cached(caminho) and ResourceLoader.get_cached_ref(caminho) == ref.get_ref()


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
	if _total >= 0:
		_proximo_shader()
		return
	_quadros -= 1
	if _quadros <= 0:
		queue_free()


## 0..1 da fila de shaders.
func progresso() -> float:
	if _total <= 0:
		return 1.0
	return clampf(float(_feitos) / float(_total), 0.0, 1.0)


func acabou() -> bool:
	return _acabou


## Um shader por quadro: o do quadro anterior já foi desenhado (montado na
## placa), sai, e entra o próximo.
func _proximo_shader() -> void:
	if _acabou:
		return
	for c in get_children():
		c.queue_free()
	if _fila.is_empty():
		_acabou = true
		terminou.emit()
		queue_free()
		return
	var caminho: String = _fila.pop_front()
	_feitos += 1
	if caminho == BASE:
		_base()
		return
	var sh := load(caminho) as Shader
	if sh == null:
		return
	var m := ShaderMaterial.new()
	m.shader = sh
	_material(m)
	if caminho in INSTANCIADOS:
		_instancias(m)
	_montados[caminho] = weakref(sh)
	Tela.marca("shader: " + caminho.get_file())


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


## Material comum e luz somada em todos os jeitos de desenhar.
func _base() -> void:
	_base_feita = true
	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for m: Material in [null, soma]:
		_material(m)
		_particulas(m, Pincel.TEXTURA)
		var linhas := Node2D.new()
		linhas.material = m
		linhas.draw.connect(func() -> void:
			linhas.draw_line(Vector2.ZERO, Vector2(4, 4), Color(1, 1, 1, 0.02), 1.0)
			linhas.draw_polyline(PackedVector2Array([Vector2.ZERO, Vector2(4, 0), Vector2(4, 4)]), Color(1, 1, 1, 0.02), 2.0)
			linhas.draw_texture_rect_region(Pincel.TEXTURA, Rect2(0, 0, 4, 4), Rect2(0, 0, 8, 8), Color(1, 1, 1, 0.02)))
		add_child(linhas)
	Tela.marca("shader: base (material comum e luz somada)")


## Desenho por instâncias (MultiMesh), como os cardumes do Mar.
func _instancias(m: Material) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(4, 4)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true   # como os cardumes (scripts/mar_vida.gd)
	mm.mesh = quad
	mm.instance_count = 1
	mm.set_instance_transform_2d(0, Transform2D(0.0, Vector2(2, 2)))
	mm.set_instance_color(0, Color(1, 1, 1, 0.02))
	var no := MultiMeshInstance2D.new()
	no.multimesh = mm
	no.texture = _textura_branca()
	no.material = m
	add_child(no)


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
