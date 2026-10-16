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
## NUNCA NA PARTIDA DO APP (Rodadas 23 e 27): na Mali-G31 da TV Box, preparar
## coisas antes da apresentação deixou o app em tela preta (1.22.0, 1.25.0 e
## 1.26.0); as versões que abriam começavam a apresentação direto. Ela só usa
## os dois shaders dela, pequenos, e retângulos de imagem.
##
## Cada shader e cada cena são um trecho vigiado (Tela.risco): se o app
## morrer montando um deles, a caixa-preta anota qual foi e, da próxima vez,
## aquele shader fica simples (scripts/contorno_desenho.gd) em vez de
## derrubar o app de novo. Cada passo também vai para a caixa-preta com o
## tempo que levou.
##
## Os itens ficam poucos quadros e somem. Um shader montado fica pronto
## enquanto o recurso dele existir (os pré-carregados pelos scripts ficam a
## sessão inteira).

const QUADROS := 3
## Shaders desenhados por instâncias (MultiMesh): outro programa na placa.
const INSTANCIADOS := ["res://shaders/mar_cardume.gdshader"]
## Números e sinais que aparecem depois (placar, contagem, pontos).
const SINAIS := " 0123456789:+-%/!?.,x×"

## Fim da fila.
signal terminou

## As fontes do jogo (o contorno "desenho:texto" as troca por letras
## desenhadas na hora: scripts/contorno_desenho.gd).
const FONTES := [
	"res://fonts/Exo2-ExtraBold.ttf",
	"res://fonts/Exo2-Bold.ttf",
	"res://fonts/Simbolos.ttf",
	"res://fonts/SimbolosEmoji.ttf",
]

## Shaders já montados nesta sessão: caminho -> WeakRef do recurso. Se o
## recurso ainda é o mesmo, o programa dele continua na placa.
static var _montados: Dictionary = {}

var _texturas: Array[Texture2D] = []
var _quadros := QUADROS
# fila de shaders (Aquecedor.shaders)
var _fila: Array[String] = []
var _total := -1          # -1: não é fila
var _feitos := 0
var _acabou := false
var _risco_antes := ""
var _trecho := ""          # o último trecho vigiado que este aquecedor abriu
var _passo := ""
var _passo_ms := 0
static var _branca: Texture2D = null


## Quantos shaders da lista ainda não estão prontos na placa.
static func faltam(caminhos: Array) -> int:
	var n := 0
	for c in caminhos:
		if not _pronto(c):
			n += 1
	return n


## Numa troca de tela, antes de a tela nova entrar: monta os shaders dela,
## um por quadro. Espere `terminou` (ou consulte acabou()/progresso()).
static func shaders(caminhos: Array, onde: Node) -> Aquecedor:
	var a := Aquecedor.new()
	a.name = "AquecedorShaders"
	for c in caminhos:
		if not _pronto(c) and ResourceLoader.exists(c):
			a._fila.append(c)
	a._total = a._fila.size()
	a._risco_antes = _risco_de_fora()
	a._pendurar(onde)
	return a


## O trecho vigiado de antes, para devolver no fim. O acerto de um alvo do
## Mar (scripts/mar.gd, "acerto:<alvo>") vale só meio segundo: não volta
## depois da troca de tela.
static func _risco_de_fora() -> String:
	var r := Tela.risco_atual()
	return "" if r.begins_with("acerto:") else r


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
	if Tela.contorna("desenho:cena"):
		a._quadros = 0
		a._pendurar(onde)
		return a
	a._risco_antes = _risco_de_fora()
	a._trecho = "desenho:cena"
	Tela.risco(a._trecho)
	a._passo = "desenho:cena " + raiz.name
	a._passo_ms = Time.get_ticks_msec()
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
		_proximo_passo()
		return
	_quadros -= 1
	if _quadros <= 0:
		if _passo != "":
			_fechar_passo()
			_devolver_risco()
		queue_free()


## 0..1 da fila de shaders.
func progresso() -> float:
	if _total <= 0:
		return 1.0
	return clampf(float(_feitos) / float(_total), 0.0, 1.0)


func acabou() -> bool:
	return _acabou


## Um passo por quadro: o do quadro anterior já foi desenhado (montado na
## placa), sai, e entra o próximo.
func _proximo_passo() -> void:
	if _acabou:
		return
	for c in get_children():
		c.queue_free()
	_fechar_passo()
	while not _fila.is_empty():
		var passo: String = _fila.pop_front()
		_feitos += 1
		if _comecar_passo(passo):
			return
	_acabou = true
	_devolver_risco()
	terminou.emit()
	queue_free()


## Monta o shader; false se não há nada para desenhar (pula para o próximo
## no mesmo quadro).
func _comecar_passo(passo: String) -> bool:
	var sh := load(passo) as Shader
	if sh == null:
		return false
	_montados[passo] = weakref(sh)
	var trecho := "shader:" + passo.get_file().get_basename()
	if Tela.contorna(trecho):
		return false   # este shader fica desligado (scripts/contorno_desenho.gd)
	_abrir_passo(trecho)
	var m := ShaderMaterial.new()
	m.shader = sh
	_material(m)
	if passo in INSTANCIADOS:
		_instancias(m)
	return true


## Trecho vigiado: se o app morrer agora, a caixa-preta sabe qual foi.
func _abrir_passo(trecho: String) -> void:
	_passo = trecho
	_passo_ms = Time.get_ticks_msec()
	_trecho = trecho
	Tela.risco(trecho)


## Volta ao trecho de antes (se ninguém abriu outro no meio).
func _devolver_risco() -> void:
	if _trecho != "" and Tela.risco_atual() == _trecho:
		Tela.risco(_risco_antes)


func _fechar_passo() -> void:
	if _passo == "":
		return
	Tela.marca("preparado %s (%d ms)" % [_passo, Time.get_ticks_msec() - _passo_ms])
	_passo = ""


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
