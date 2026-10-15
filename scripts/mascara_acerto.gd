class_name MascaraAcerto
extends RefCounted

## Acerto pelo desenho: o tiro só vale onde o alvo tem pixel de verdade (o
## desenho que está na tela agora, no quadro da animação de agora), nunca no
## retângulo da imagem, num círculo em volta ou "perto".
## As máscaras (1 canal: 255 = desenho, 0 = vazio) saem das mesmas folhas de
## sprites, uma vez, por tools/gerar_mascaras_acerto.gd
## (sprites/acerto/<folha>.res, poucos KB). Ficam na memória enquanto o jogo
## roda: no tiro é só ler um pixel. Folha sem máscara pronta: a máscara é
## feita na hora a partir da própria textura (uma vez).

const LIMIAR := 64              # alfa (0..255) a partir do qual é desenho

static var _cache: Dictionary = {}   # caminho da folha -> Image (L8)


## Carrega as máscaras das folhas (ao abrir a fase: o primeiro tiro não
## espera nada).
static func preparar(folhas: Array) -> void:
	for f in folhas:
		mascara(f as Texture2D)


static func mascara(folha: Texture2D) -> Image:
	if folha == null:
		return null
	var chave := folha.resource_path
	if chave == "":
		chave = str(folha.get_rid())
	if _cache.has(chave):
		return _cache[chave]
	var m: Image = null
	var arquivo := "res://sprites/acerto/%s.res" % folha.resource_path.get_file().get_basename()
	if folha.resource_path != "" and ResourceLoader.exists(arquivo):
		m = load(arquivo) as Image
	if m == null:
		m = _da_textura(folha)
	_cache[chave] = m
	return m


static func _da_textura(folha: Texture2D) -> Image:
	var img := folha.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var dados := img.get_data()
	var m := PackedByteArray()
	m.resize(w * h)
	for i in w * h:
		m[i] = 255 if dados[i * 4 + 3] > LIMIAR else 0
	return Image.create_from_data(w, h, false, Image.FORMAT_L8, m)


## O ponto (global) cai num pixel do desenho que o nó (Sprite2D ou
## AnimatedSprite2D) mostra agora?
static func no_desenho(no: Node2D, pos_global: Vector2) -> bool:
	if no == null or not no.is_visible_in_tree():
		return false
	var tex: Texture2D = null
	var centrado := true
	var desloc := Vector2.ZERO
	var espelho := Vector2i(0, 0)
	var regiao := Rect2()
	if no is AnimatedSprite2D:
		var a := no as AnimatedSprite2D
		if a.sprite_frames == null or not a.sprite_frames.has_animation(a.animation):
			return false
		var n := a.sprite_frames.get_frame_count(a.animation)
		if n <= 0:
			return false
		tex = a.sprite_frames.get_frame_texture(a.animation, clampi(a.frame, 0, n - 1))
		centrado = a.centered
		desloc = a.offset
		espelho = Vector2i(int(a.flip_h), int(a.flip_v))
	elif no is Sprite2D:
		var s := no as Sprite2D
		tex = s.texture
		centrado = s.centered
		desloc = s.offset
		espelho = Vector2i(int(s.flip_h), int(s.flip_v))
		if tex != null:
			var r := Rect2(Vector2.ZERO, tex.get_size())
			if s.region_enabled:
				r = s.region_rect
			var quadro := r.size / Vector2(maxi(s.hframes, 1), maxi(s.vframes, 1))
			regiao = Rect2(r.position + quadro * Vector2(s.frame_coords), quadro)
	if tex == null:
		return false
	var tam := regiao.size if regiao.size != Vector2.ZERO else tex.get_size()
	var p := no.to_local(pos_global) - desloc
	if centrado:
		p += tam * 0.5
	if espelho.x == 1:
		p.x = tam.x - p.x
	if espelho.y == 1:
		p.y = tam.y - p.y
	if p.x < 0.0 or p.y < 0.0 or p.x >= tam.x or p.y >= tam.y:
		return false
	var folha := tex
	var origem := regiao.position
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		p -= at.margin.position
		if p.x < 0.0 or p.y < 0.0 or p.x >= at.region.size.x or p.y >= at.region.size.y:
			return false
		folha = at.atlas
		origem = at.region.position
	return no_pixel(folha, origem + p)


## O pixel `p` (px da folha) é desenho?
static func no_pixel(folha: Texture2D, p: Vector2) -> bool:
	var m := mascara(folha)
	if m == null:
		return false
	var x := int(p.x)
	var y := int(p.y)
	if x < 0 or y < 0 or x >= m.get_width() or y >= m.get_height():
		return false
	return m.get_pixel(x, y).r > 0.5
