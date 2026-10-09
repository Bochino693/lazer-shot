extends Node2D

# Teia de luz atrás dos alvos do Deserto (anéis + raios). Antes eram 18
# Line2D por alvo (um desenho cada, ~250 por quadro); agora é um nó só
# desenhado com o Pincel (sai junto num desenho).

const Pincel := preload("res://scripts/pincel.gd")

var cor := Color.WHITE
var raio_anel := 42.0
var passo_anel := 10.0
var aneis := 4
var raios := 14
var linha_de := 26.0
var linha_ate := 78.0
var largura_anel := 2.2
var largura_linha := 1.3
var alfa_anel := 0.20
var alfa_linha := 0.16


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func configurar(p_cor: Color, p_raio_anel: float, p_aneis: int, p_passo_anel: float, p_raios: int, p_de: float, p_ate: float, p_larg_anel: float, p_larg_linha: float, p_alfa_anel: float, p_alfa_linha: float) -> Node2D:
	cor = p_cor
	raio_anel = p_raio_anel
	aneis = p_aneis
	passo_anel = p_passo_anel
	raios = p_raios
	linha_de = p_de
	linha_ate = p_ate
	largura_anel = p_larg_anel
	largura_linha = p_larg_linha
	alfa_anel = p_alfa_anel
	alfa_linha = p_alfa_linha
	queue_redraw()
	return self


## Mesma regra de antes: a teia acende e engrossa conforme o alvo envelhece.
func ajustar_progresso(p_cor: Color, progresso: float) -> void:
	var alfa := lerpf(0.12, 0.62, progresso)
	cor = p_cor
	largura_anel = lerpf(1.5, 2.8, progresso)
	largura_linha = lerpf(0.8, 1.8, progresso)
	alfa_anel = alfa
	alfa_linha = alfa * 0.65
	queue_redraw()


func _draw() -> void:
	for i in range(aneis):
		Pincel.anel(self, Vector2.ZERO, raio_anel + float(i) * passo_anel, largura_anel, Color(cor.r, cor.g, cor.b, alfa_anel))
	for i in range(raios):
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / float(raios))
		Pincel.linha(self, dir * linha_de, dir * linha_ate, Color(cor.r, cor.g, cor.b, alfa_linha), largura_linha)
