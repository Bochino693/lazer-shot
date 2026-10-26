extends CanvasLayer

## A POSE: antes da partida o jogo pede a foto do jogador. A imagem ao vivo
## da webcam aparece numa foto instantânea grande ("SORRIA PARA A FOTO!"),
## a contagem 3-2-1 corre em cima, o clique dispara com flash e a foto
## pronta aparece um instante ("FICOU ÓTIMO!"). Sai o sinal `terminou` (com
## ou sem foto: a partida segue de qualquer jeito).
##
## A imagem ao vivo e a foto vêm do FotoJogador. Se a imagem não chegar em
## ESPERA_IMAGEM, a pose fecha sem foto (nada técnico na tela). START pula.

signal terminou

const ESPERA_IMAGEM = 4.5
const LADO = 600.0
const PASSO = 0.85           # s de cada número

var _cor = Color.white
var _raiz: Control
var _escuro: ColorRect
var _cartao: Control
var _foto: TextureRect
var _aguarde: Label
var _titulo: Label
var _num: Label
var _flash: ColorRect
var _legenda: Label
var _t = 0.0
var _fase = "esperando"      # esperando, contando, clicou, mostrando, saindo
var _n = 3
var _som_bip: AudioStream
var _som_clique: AudioStream


static func criar(pai: Node, cor: Color) -> CanvasLayer:
	var p = load("res://scripts/pose_foto.gd").new()
	p._cor = cor
	p.layer = 98
	pai.add_child(p)
	return p


func _ready() -> void:
	_som_bip = load("res://songs/foto_contagem.wav")
	_som_clique = load("res://songs/foto_obturador.wav")
	_raiz = Control.new()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.rect_size = Tela.TELA
	add_child(_raiz)
	_escuro = ColorRect.new()
	_escuro.color = Color(0, 0, 0, 0.72)
	_escuro.rect_size = Tela.TELA
	_escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_escuro)
	var c = _cor.linear_interpolate(Color.white, 0.3)
	_titulo = Estilo.rotulo(_raiz, "SORRIA PARA A FOTO!", 66, c, 8)
	Estilo.colocar(_titulo, Vector2(0, 250), Vector2(Tela.TELA.x, 90))
	var sub = Estilo.rotulo(_raiz, "OLHE PARA A CÂMERA", 32, Color(1, 1, 1, 0.85), 4, false)
	Estilo.colocar(sub, Vector2(0, 340), Vector2(Tela.TELA.x, 44))
	# a foto instantânea: papel, a imagem ao vivo e a legenda
	_cartao = Control.new()
	_cartao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao.rect_size = Vector2(LADO + 36, LADO + 110)
	_cartao.rect_pivot_offset = _cartao.rect_size * 0.5
	_cartao.rect_position = Vector2((Tela.TELA.x - _cartao.rect_size.x) * 0.5, 430)
	_cartao.rect_rotation = -2.0
	_raiz.add_child(_cartao)
	var sombra = ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.5)
	sombra.rect_position = Vector2(14, 16)
	sombra.rect_size = _cartao.rect_size
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao.add_child(sombra)
	var papel = ColorRect.new()
	papel.color = Color(0.97, 0.96, 0.92)
	papel.rect_size = _cartao.rect_size
	papel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao.add_child(papel)
	var fundo = ColorRect.new()
	fundo.color = Color(0.08, 0.08, 0.1)
	fundo.rect_position = Vector2(18, 18)
	fundo.rect_size = Vector2(LADO, LADO)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao.add_child(fundo)
	# a imagem ao vivo recortada no quadrado (o giro e o espelho da
	# CONFIGURAÇÃO valem também aqui)
	var janela = Control.new()
	janela.rect_clip_content = true
	janela.rect_position = Vector2(18, 18)
	janela.rect_size = Vector2(LADO, LADO)
	janela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao.add_child(janela)
	_foto = TextureRect.new()
	_foto.expand = true
	_foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_foto.rect_size = Vector2(LADO, LADO)
	_foto.rect_pivot_offset = Vector2(LADO, LADO) * 0.5
	_foto.rect_rotation = float(int(Maquina.valor("camera/girar")) % 360)
	_foto.flip_h = bool(Maquina.valor("camera/espelhar"))
	_foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	janela.add_child(_foto)
	_aguarde = Estilo.rotulo(_cartao, "PREPARANDO A CÂMERA...", 30, Color(1, 1, 1, 0.8), 0, false)
	Estilo.colocar(_aguarde, Vector2(18, 18), Vector2(LADO, LADO))
	_legenda = Estilo.rotulo(_cartao, "LAZER SHOT", 38, Color(0.15, 0.12, 0.12), 0, true)
	Estilo.colocar(_legenda, Vector2(0, LADO + 34), Vector2(_cartao.rect_size.x, 60))
	# o número da contagem, grande, em cima da foto
	_num = Label.new()
	_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_num.align = Label.ALIGN_CENTER
	_num.valign = Label.VALIGN_CENTER
	_num.rect_size = Vector2(Tela.TELA.x, 300)
	_num.rect_position = Vector2(0, 430 + LADO * 0.5 + 18 - 150)
	_num.rect_pivot_offset = _num.rect_size * 0.5
	var f = DynamicFont.new()
	f.font_data = load(Estilo.FONTE_FORTE)
	f.size = 220
	f.use_filter = true
	f.outline_size = 14
	f.outline_color = Color(0.05, 0.02, 0.02)
	_num.add_font_override("font", f)
	_num.add_color_override("font_color", _cor.linear_interpolate(Color.white, 0.35))
	Estilo.aquecer_fonte(f, "321")
	_num.visible = false
	_raiz.add_child(_num)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.rect_size = Tela.TELA
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_flash)
	# a câmera já está ligada desde que a fase abriu; se não, liga agora
	FotoJogador.ligar_previa()
	FotoJogador.connect("previa_nova", self, "_previa")
	FotoJogador.connect("foto_pronta", self, "_pronta")
	if FotoJogador.tem_previa():
		_previa(FotoJogador.previa)
	_raiz.modulate.a = 0.0
	_cartao.rect_scale = Vector2(0.85, 0.85)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_raiz, "modulate:a", 1.0, 0.25)
	tw.tween_property(_cartao, "rect_scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _previa(tex: Texture) -> void:
	if _fase == "mostrando" or _fase == "saindo" or _fase == "clicou":
		return
	_foto.texture = tex
	_aguarde.visible = false
	if _fase == "esperando":
		_fase = "contando"
		_t = 0.0
		_n = 3
		_mostrar_numero()


func _mostrar_numero() -> void:
	_num.visible = true
	_num.text = str(_n)
	_num.rect_scale = Vector2.ONE * 1.6
	_num.modulate.a = 0.0
	Maquina.efeito(_som_bip, -4.0, 1.0 + 0.1 * (3 - _n))
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_num, "modulate:a", 0.95, 0.12)
	tw.tween_property(_num, "rect_scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	match _fase:
		"esperando":
			if _t > ESPERA_IMAGEM:
				_sair()
		"contando":
			if _t >= PASSO:
				_t = 0.0
				_n -= 1
				if _n > 0:
					_mostrar_numero()
				else:
					_clique()
		"clicou":
			# a foto demora um pouco (gravar, recortar): sem ela, segue
			if _t > 3.5:
				_sair()


func _clique() -> void:
	_fase = "clicou"
	_t = 0.0
	_num.visible = false
	Maquina.efeito(_som_clique, -2.0)
	_flash.color.a = 0.95
	var tw = create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.45)
	FotoJogador.fotografar()


func _pronta(tex: Texture) -> void:
	if _fase != "clicou":
		return
	_fase = "mostrando"
	_foto.texture = tex
	# a foto pronta já está girada e espelhada
	_foto.rect_rotation = 0.0
	_foto.flip_h = false
	_legenda.text = "FICOU ÓTIMO!"
	_titulo.text = "FOTO TIRADA!"
	var tw = create_tween()
	tw.tween_property(_cartao, "rect_scale", Vector2.ONE * 1.05, 0.15)
	tw.tween_property(_cartao, "rect_scale", Vector2.ONE, 0.2)
	tw.tween_interval(0.9)
	tw.tween_callback(self, "_sair")


## START pula a foto.
func pular() -> void:
	if _fase == "esperando" or _fase == "contando":
		FotoJogador.cancelar()
		_sair()


func _sair() -> void:
	if _fase == "saindo":
		return
	if _fase != "mostrando":
		FotoJogador.cancelar()
	_fase = "saindo"
	var tw = create_tween()
	tw.tween_property(_raiz, "modulate:a", 0.0, 0.25)
	tw.tween_callback(self, "_terminar")


func _terminar() -> void:
	emit_signal("terminou")
	queue_free()
