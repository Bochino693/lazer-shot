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
