extends Node2D
class_name FundoVivo

## FUNDO VIVO das telas de fora da partida (inicial, escolha de cenário e
## ranking), sem shader de tela cheia (Mali-450).
##
## "init" é o corredor do estande: o VÍDEO da tela inicial da 4.6
## (videos/back_init.webm, VP8 540x960 sem som: a TV Box decodifica VP8 com
## NEON, leve) tocando em volta, por cima do quadro parado (fundo_menu). O
## vídeo pausa quando não aparece (demonstração por cima, outro cenário na
## frente) e some sozinho se a tela pesar (grupo "efeito_opcional", ver
## MiraGlobal) ou se estiver desligado na CONFIGURAÇÃO; aí fica o quadro
## parado vivo: o título, o alvo e o logo acendem na batida da música e as
## luzes do corredor piscam com o grave (duas camadas de luz somada, de meia
## resolução, tiradas do próprio fundo por tools/preparar_mali.py). Os cenários ("deserto", "mar", "bar",
## "arena") são as artes das fases. Por cima de todos, brasas subindo e uma
## faixa de brilho que cruza a tela de tempos em tempos; o fundo "respira"
## (zoom lento, pouco: o logo da Lazer & Sport encosta na borda).
##
## Uso:
##   var f = FundoVivo.new()
##   add_child(f)
##   f.mostrar("init")         # troca com cruzamento suave
##   f.mostrar("mar")          # pedidos seguidos: vale o último

const FUNDOS = {
	"init": "fundo_menu",
	"deserto": "fundo_egito_sol",
	"mar": "fundo_mar",
	"bar": "fundo_bar",
	"arena": "fundo_arena",
}
## Espera o pedido parar antes de trocar (a mira passando por vários cartões
## não fica trocando de fundo) e a duração do cruzamento.
const ATRASO_TROCA = 0.18
const TEMPO_TROCA = 0.35
const VIDEO_INIT = "res://videos/back_init.webm"

var escurecer = 1.0 setget _set_escurecer

var _t = 0.0
var _vivo: Node2D
var _camadas = {}
var _brilho: Sprite
var _luzes: Sprite
var _faixa: Sprite
var _faixa_t = 4.0
var _brasas: Particulas
var _atual = ""
var _desejado = ""
var _espera = 0.0
var _tw: SceneTreeTween
var _video: VideoPlayer
var _video_pausado = false


func _init() -> void:
	_vivo = Node2D.new()
	_vivo.position = Tela.TELA * 0.5
	add_child(_vivo)
	_faixa = Sprite.new()
	_faixa.texture = Estilo.tex("fx_feixe")
	_faixa.material = Estilo.material_soma()
	_faixa.rotation = deg2rad(-28.0)
	_faixa.scale = Vector2(5.0, 9.5)
	_faixa.modulate = Color(1.0, 0.9, 0.9, 0.0)
	_faixa.visible = false
	_faixa.add_to_group("efeito_opcional")
	add_child(_faixa)
	_brasas = Particulas.new()
	_brasas.somar = true
	_brasas.add_to_group("efeito_opcional")
	add_child(_brasas)


## Mostra o fundo `chave` (cruzando com o atual). imediato: sem a espera.
func mostrar(chave: String, imediato: bool = false) -> void:
	if not FUNDOS.has(chave):
		return
	_desejado = chave
	_espera = 0.0 if imediato or _atual == "" else ATRASO_TROCA
	if _atual == "":
		_trocar(chave, true)


func atual() -> String:
	return _atual


func _set_escurecer(v: float) -> void:
	escurecer = v
	_vivo.modulate = Color(v, v, v)


func _camada(chave: String) -> Sprite:
	if _camadas.has(chave):
		return _camadas[chave]
	var s = Sprite.new()
	s.texture = Estilo.tex(FUNDOS[chave])
	s.scale = Vector2.ONE * (Tela.TELA.x / s.texture.get_width())
	s.modulate.a = 0.0
	_vivo.add_child(s)
	_camadas[chave] = s
	if chave == "init":
		_luzes = _luz("menu_luzes", s)
		_brilho = _luz("menu_brilho", s)
		_video = _criar_video(s)
	return s


## O vídeo do corredor por cima do quadro parado (cobre a imagem inteira).
func _criar_video(fundo: Sprite) -> VideoPlayer:
	if not bool(Maquina.valor("video/video_inicial")):
		return null
	var stream = load(VIDEO_INIT)
	if stream == null:
		return null
	var v = VideoPlayer.new()
	v.stream = stream
	v.expand = true
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tam = fundo.texture.get_size()
	v.rect_position = -tam * 0.5
	v.rect_size = tam
	v.connect("finished", self, "_video_de_novo")
	v.add_to_group("efeito_opcional")
	fundo.add_child(v)
	fundo.move_child(v, 0)
	v.play()
	return v


## Em volta: acabou, começa de novo.
func _video_de_novo() -> void:
	if _video != null and is_instance_valid(_video) and _video.is_visible_in_tree():
		_video.play()


## A tela cobriu o fundo (demonstração por cima): o vídeo pausa.
func pausar_video(sim: bool) -> void:
	_video_pausado = sim


## Camada de luz somada presa ao fundo (meia resolução: escala dobrada).
func _luz(nome: String, fundo: Sprite) -> Sprite:
	var l = Sprite.new()
	l.texture = Estilo.tex(nome)
	l.material = Estilo.material_soma()
	l.scale = Vector2.ONE * (fundo.texture.get_width() / float(l.texture.get_width()))
	l.modulate.a = 0.0
	fundo.add_child(l)
	return l


func _trocar(chave: String, imediato: bool) -> void:
	var novo = _camada(chave)
	var velho = _camadas.get(_atual, null)
	_atual = chave
	_vivo.move_child(novo, _vivo.get_child_count() - 1)
	novo.visible = true
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if imediato:
		novo.modulate.a = 1.0
		_so_o_atual()
		return
	_tw = create_tween()
	_tw.tween_property(novo, "modulate:a", 1.0, TEMPO_TROCA).set_trans(Tween.TRANS_SINE)
	_tw.tween_callback(self, "_so_o_atual")
	if velho != null and velho != novo:
		velho.modulate.a = 1.0


## As camadas cobertas nem são desenhadas (todas opacas).
func _so_o_atual() -> void:
	for k in _camadas:
		var s: Sprite = _camadas[k]
		s.visible = k == _atual
		if k != _atual:
			s.modulate.a = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _desejado != _atual and _desejado != "":
		_espera -= delta
		if _espera <= 0.0:
			_trocar(_desejado, false)
	var som = Maquina.pulso_vivo()
	# o fundo respira (zoom sempre acima de 1: a borda nunca aparece)
	var z = 1.0 + 0.007 + 0.004 * sin(_t * 0.19) + 0.004 * som.y
	_vivo.scale = Vector2(z, z)
	_vivo.position = Tela.TELA * 0.5 + Vector2(2.0 * sin(_t * 0.13), 4.0 * cos(_t * 0.11))
	# o vídeo toca só quando aparece; tocando, as luzes do quadro parado somem
	var com_video = false
	if _video != null and is_instance_valid(_video):
		com_video = _video.is_visible_in_tree() and not _video_pausado
		if _video.paused == com_video:
			_video.paused = not com_video
		if _brilho != null:
			_brilho.visible = not com_video
			_luzes.visible = not com_video
	if _brilho != null and _brilho.is_visible_in_tree():
		# título/alvo/logo na batida; luzes do corredor piscando com o grave
		_brilho.modulate.a = clamp(0.10 + 0.85 * som.y + 0.25 * som.x, 0.0, 1.0)
		var pisca = 0.5 + 0.5 * sin(_t * 9.0) * sin(_t * 5.3)
		_luzes.modulate.a = clamp(0.15 + 0.6 * som.x + 0.3 * pisca + 0.35 * som.y, 0.0, 1.0)
	# faixa de brilho na diagonal (~12 s por passagem)
	_faixa_t += delta
	if _faixa_t > 12.0:
		_faixa_t = 0.0
	var k = _faixa_t / 2.2
	if k <= 1.0:
		_faixa.visible = true
		_faixa.position = Vector2(lerp(-500.0, Tela.TELA.x + 500.0, k), Tela.TELA.y * 0.5)
		_faixa.modulate.a = 0.10 * sin(k * PI) * escurecer
	elif _faixa.visible:
		_faixa.visible = false
	# brasas subindo do chão
	if randf() < delta * 9.0 * Maquina.fator_efeitos():
		var p = Vector2(rand_range(0.0, Tela.TELA.x), Tela.TELA.y + 10.0)
		var v = Vector2(rand_range(-20.0, 20.0), rand_range(-110.0, -45.0))
		_brasas.soltar(p, v, rand_range(4.0, 7.0), rand_range(4.0, 8.0), 1.5, Color(1.0, 0.45, 0.2, 0.9 * escurecer),
			Color(1.0, 0.15, 0.05, 0.0), Estilo.tex("fx_ponto"), -6.0, 0.1)
