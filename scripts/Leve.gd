class_name Leve
extends RefCounted

## Ajustes de tema que só mexem no Control quando o valor MUDA.
##
## add_theme_*_override sempre avisa o Control que o tema mudou, mesmo com o
## mesmo valor: o Label refaz o texto inteiro (forma das letras, tamanho,
## contorno) e é redesenhado. Os HUDs das fases chamavam isso em todo quadro
## para dezenas de textos; na TV Box isso sozinho custava vários ms por quadro.
## Com estas funções o resultado na tela é o mesmo, sem o trabalho repetido.


static func color(c: Control, nome: StringName, v: Color) -> void:
	if c.has_theme_color_override(nome) and c.get_theme_color(nome) == v:
		return
	c.add_theme_color_override(nome, v)


static func constant(c: Control, nome: StringName, v: int) -> void:
	if c.has_theme_constant_override(nome) and c.get_theme_constant(nome) == v:
		return
	c.add_theme_constant_override(nome, v)


static func font_size(c: Control, nome: StringName, v: int) -> void:
	if c.has_theme_font_size_override(nome) and c.get_theme_font_size(nome) == v:
		return
	c.add_theme_font_size_override(nome, v)


static func font(c: Control, nome: StringName, v: Font) -> void:
	if c.has_theme_font_override(nome) and c.get_theme_font(nome) == v:
		return
	c.add_theme_font_override(nome, v)


static func stylebox(c: Control, nome: StringName, v: StyleBox) -> void:
	if c.has_theme_stylebox_override(nome) and c.get_theme_stylebox(nome) == v:
		return
	c.add_theme_stylebox_override(nome, v)


## Propriedade de um StyleBox (bg_color, border_color, shadow_size...):
## cada troca redesenha o painel e recalcula a sombra, então só troca se mudou.
static func prop(obj: Object, nome: StringName, v: Variant) -> void:
	if obj.get(nome) == v:
		return
	obj.set(nome, v)




## Enquadra um vídeo de fundo sem esticar e sem cortar o que importa:
## - proporção igual à da tela (as prévias 9:16): ocupa a tela inteira;
## - mais largo que a tela (o fundo 2:3): aparece inteiro na largura e as
##   faixas que sobram em cima e embaixo prolongam a primeira e a última
##   linha do próprio vídeo (dois desenhos pequenos, sem decodificar nada);
## - mais estreito: cobre a tela cortando as sobras de cima e de baixo.
## A proporção vem do quadro decodificado; sem ele, `proporcao_padrao`.
static func cobrir_video(v: VideoStreamPlayer, tela: Vector2, proporcao_padrao: float = 9.0 / 16.0) -> void:
	var proporcao := proporcao_padrao
	var tex := v.get_video_texture()
	if tex != null and tex.get_height() > 0:
		proporcao = float(tex.get_width()) / float(tex.get_height())
	var tam := tela
	var faixas := false
	if absf(proporcao - tela.x / tela.y) > 0.02:
		tam = Vector2(tela.x, tela.x / proporcao)
		faixas = tam.y < tela.y and tex != null
		if tam.y < tela.y and not faixas:
			tam = Vector2(tela.y * proporcao, tela.y)
	v.set_anchors_preset(Control.PRESET_TOP_LEFT)
	v.expand = true
	v.scale = Vector2.ONE
	v.position = ((tela - tam) * 0.5).round()
	v.size = tam.round()

	var alto := v.position.y
	for lado in ["Cima", "Baixo"]:
		var faixa := v.get_node_or_null("Faixa" + lado) as TextureRect
		if faixas and faixa == null:
			faixa = TextureRect.new()
			faixa.name = "Faixa" + lado
			faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
			faixa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			faixa.stretch_mode = TextureRect.STRETCH_SCALE
			faixa.self_modulate = Color(0.55, 0.55, 0.55)
			faixa.texture = AtlasTexture.new()
			v.add_child(faixa)
		if faixa == null:
			continue
		faixa.visible = faixas
		if not faixas:
			continue
		var linhas := 3.0
		var at := faixa.texture as AtlasTexture
		at.atlas = tex
		if lado == "Cima":
			at.region = Rect2(0, 0, tex.get_width(), linhas)
			faixa.position = Vector2(0, -alto)
		else:
			at.region = Rect2(0, tex.get_height() - linhas, tex.get_width(), linhas)
			faixa.position = Vector2(0, v.size.y)
		faixa.size = Vector2(v.size.x, alto + 1.0)
