extends Node

## A TELA DO LAZER SHOT: o jogo é em pé (base 1024 x 1536, e a altura cresce
## para preencher a tela, como no PC com o monitor em pé).
##
## PC / monitor já em pé (giro 0): nada muda, é o jogo de sempre.
##
## TV Box Ultra Pro (Android 10): o HDMI sai DEITADO e o monitor da máquina
## está EM PÉ. O jogo gira a imagem 90° por dentro, pela transformação global
## do canvas da janela (vale para todas as camadas: HUD, modais, mira). Para
## os scripts a tela continua em pé: get_viewport_rect() = 1024 x ~1820,
## então nenhum layout muda.
##
## MIRA: a arma (e qualquer mouse) manda coordenadas no sentido do monitor em
## pé, mas a janela do Android está deitada. Cada evento de mouse é corrigido
## ANTES de chegar às cenas (posição, movimento relativo e cliques), e a
## posição do cursor deve ser lida por `Tela.mouse()`.
##
## Ajustes em project.godot (o GERAR_APK troca pelo parâmetro -Giro):
##   lazer/tela/giro = 1   topo do jogo na ESQUERDA do HDMI
##                    -1   topo do jogo na DIREITA do HDMI (imagem de cabeça para baixo? use este)
##                     0   sem giro
##   lazer/tela/mira_direta = true   arma/mouse no sentido do monitor em pé (padrão)
##                            false  mouse segue o HDMI deitado (girado junto com a imagem)
## Para testar no PC: variáveis de ambiente LAZER_GIRO e LAZER_MIRA_DIRETA.

const BASE := Vector2(1024, 1536)

var giro := 0
var mira_direta := true

var _janela_px := Vector2.ZERO   # tamanho da janela (HDMI), em pixels
var _conteudo := BASE            # a tela em pé que os scripts enxergam
var _escala := 1.0               # pixels do HDMI por pixel do jogo


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	giro = _giro_configurado()
	mira_direta = _mira_configurada()
	var janela := get_tree().root
	_aplicar()
	janela.size_changed.connect(_aplicar)
	janela.window_input.connect(_corrigir_evento)


func _giro_configurado() -> int:
	if OS.has_environment("LAZER_GIRO"):
		return int(OS.get_environment("LAZER_GIRO"))
	if OS.get_name() != "Android":
		return 0
	return int(ProjectSettings.get_setting("lazer/tela/giro", 1))


func _mira_configurada() -> bool:
	if OS.has_environment("LAZER_MIRA_DIRETA"):
		return OS.get_environment("LAZER_MIRA_DIRETA") != "0"
	return bool(ProjectSettings.get_setting("lazer/tela/mira_direta", true))


func _aplicar() -> void:
	var janela := get_tree().root
	janela.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if giro == 0:
		janela.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		janela.content_scale_size = Vector2i(BASE)
		janela.global_canvas_transform = Transform2D.IDENTITY
		return

	_janela_px = Vector2(janela.size)
	if _janela_px.x <= 0.0 or _janela_px.y <= 0.0:
		return
	# O monitor em pé tem largura = altura do HDMI e altura = largura do HDMI.
	# Mesmo cálculo do "expand": a largura 1024 cabe inteira e a altura cresce.
	_escala = min(_janela_px.y / BASE.x, _janela_px.x / BASE.y)
	var tam := Vector2i(roundi(_janela_px.y / _escala), roundi(_janela_px.x / _escala))
	_conteudo = Vector2(tam)

	# Com a proporção "ignore", o conteúdo (em pé) é esticado para a janela
	# (deitada); a transformação abaixo desfaz o esticão e gira 90°, então o
	# resultado final na tela é o jogo em pé, em escala uniforme.
	janela.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	janela.content_scale_size = tam
	var kx := _escala * _conteudo.y / _janela_px.y
	var ky := _escala * _conteudo.x / _janela_px.x
	if giro > 0:
		# jogo (x, y) -> HDMI (y, altura - x): topo do jogo na esquerda
		janela.global_canvas_transform = Transform2D(Vector2(0, -kx), Vector2(ky, 0), Vector2(0, _conteudo.y))
	else:
		# jogo (x, y) -> HDMI (largura - y, x): topo do jogo na direita
		janela.global_canvas_transform = Transform2D(Vector2(0, kx), Vector2(-ky, 0), Vector2(_conteudo.x, 0))


## Tamanho da tela do jogo (em pé), o mesmo que get_viewport_rect().size.
func tamanho() -> Vector2:
	return get_tree().root.get_visible_rect().size


# ------------------------------------------------------------------ mira
## Ponto do jogo -> pixel do HDMI (onde a imagem desse ponto aparece).
func _jogo_para_hdmi(p: Vector2) -> Vector2:
	if giro > 0:
		return Vector2(p.y * _escala, _janela_px.y - p.x * _escala)
	return Vector2(_janela_px.x - p.y * _escala, p.x * _escala)


## Vetor do jogo -> vetor do HDMI (sem deslocamento).
func _vetor_para_hdmi(v: Vector2) -> Vector2:
	if giro > 0:
		return Vector2(v.y * _escala, -v.x * _escala)
	return Vector2(-v.y * _escala, v.x * _escala)


## Onde a arma está apontando, em coordenadas do jogo. A arma mede no sentido
## do monitor em pé: a fração da janela em X é a fração da largura do jogo.
func _hdmi_para_jogo_direto(p: Vector2) -> Vector2:
	return Vector2(p.x / _janela_px.x * _conteudo.x, p.y / _janela_px.y * _conteudo.y)


func _corrigir_evento(ev: InputEvent) -> void:
	if giro == 0 or not mira_direta or not (ev is InputEventMouse):
		return
	if _janela_px.x <= 0.0:
		return
	var m := ev as InputEventMouse
	# O Godot ainda vai desfazer o giro deste evento; entregamos a ele o pixel
	# do HDMI que corresponde ao ponto certo do jogo.
	var alvo := _hdmi_para_jogo_direto(m.position)
	m.position = _jogo_para_hdmi(alvo)
	m.global_position = m.position
	if ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		# Movimento relativo da arma: mesmo sentido do monitor em pé, na
		# escala da tela (pixel do HDMI -> pixel do jogo).
		mm.relative = _vetor_para_hdmi(mm.relative / _escala)
		mm.velocity = _vetor_para_hdmi(mm.velocity / _escala)


## Posição do cursor em coordenadas do jogo. Use no lugar de
## get_viewport().get_mouse_position(), que lê o cursor do sistema sem a
## correção da mira.
func mouse() -> Vector2:
	var vp := get_tree().root
	if giro == 0 or not mira_direta or _janela_px.x <= 0.0:
		return vp.get_mouse_position()
	# get_mouse_position() já desfez o giro; refaz para achar o pixel do HDMI.
	return _hdmi_para_jogo_direto(_jogo_para_hdmi(vp.get_mouse_position()))


## Leva o cursor do sistema até um ponto do jogo (warp_mouse com a correção).
func warp_mouse(p: Vector2) -> void:
	var vp := get_tree().root
	if giro == 0 or not mira_direta or _janela_px.x <= 0.0:
		vp.warp_mouse(p)
		return
	Input.warp_mouse(Vector2(p.x / _conteudo.x * _janela_px.x, p.y / _conteudo.y * _janela_px.y))
