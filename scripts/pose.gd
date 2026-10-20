class_name Pose
extends Control

## A FOTO ANTES DA PARTIDA (Rodada 31), do jeito do Super Boxing: depois do
## START e da escolha do cenário, a tela mostra a webcam AO VIVO num visor,
## conta 3-2-1 e tira a foto, que vai para o recorde e para o ranking
## (RankingManager.foto_da_partida). Depois entra a fase.
##
## A CÂMERA NUNCA SEGURA A MÁQUINA. Sem webcam neste aparelho, desligada na
## CONFIGURAÇÃO ou contornada pela caixa-preta, a pose nem aparece: a fase
## entra direto (Pose.ir). Com webcam, mas sem imagem ainda, a tela espera
## alguns segundos com "PREPARANDO A CÂMERA" e segue sem foto se ela não
## vier. Nada técnico aparece aqui (o porquê fica na CONFIGURAÇÃO > TESTAR).
##
## A FOTO É DA POSE FINAL: o obturador só abre no último meio segundo da
## contagem (scripts/webcam.gd, abrir_obturador). O relógio da contagem para
## junto com a imagem, se ela parar, e volta quando ela volta.
##
## Leve para a TV Box: um visor com a imagem da webcam (uma textura que muda
## ~12 vezes por segundo), a capa do cenário em cima e alguns textos.

const CENA := "res://scenes/pose.tscn"
const META_DESTINO := "pose_destino"
const CENA_CENARIOS := "res://scenes/cenarios.tscn"
const Pincel := preload("res://scripts/pincel.gd")
const FONTE_FORTE := preload("res://fonts/Exo2-ExtraBold.ttf")
const FONTE := preload("res://fonts/Exo2-Bold.ttf")
const SOM_CONTAGEM := preload("res://songs/foto_contagem.wav")
const SOM_OBTURADOR := preload("res://songs/foto_obturador.wav")

const CONTAGEM := 3.0
const JANELA_OBTURADOR := 0.5
## Quanto esperar a imagem da webcam chegar (já vista neste aparelho / nunca).
const ESPERA_CONHECIDA := 6.0
const ESPERA_NOVA := 3.0
## A imagem sumiu no meio da contagem: espera ela voltar até isto.
const ESPERA_NA_CONTAGEM := 3.0
const MOSTRAR_FOTO := 1.5
const MOSTRAR_SEM_FOTO := 0.8
## Leitura dos quadros com a imagem na tela (ms).
const RITMO_PREVIA := 80
const RITMO_PREVIA_LEVE := 100

enum Passo { ESPERANDO, CONTANDO, FOTO, SEM_FOTO, SAINDO }

var _destino := CENA_CENARIOS
var _cor := Color(1.0, 0.24, 0.20)
var _passo := Passo.ESPERANDO
var _t := 0.0
var _espera := 0.0
var _espera_max := ESPERA_NOVA
var _parada := 0.0
var _restante := CONTAGEM
var _ultimo_numero := 0
var _obturador_aberto := false
var _foto := ""
var _webcam: Webcam

var _visor: Control
var _previa: TextureRect
var _previa_fundo: ColorRect
var _sobre: Control       # anel de espera e "REC", desenhados com o pincel
var _aviso_visor: Label
var _clarao: ColorRect
var _numero: Label
var _legenda: Label
var _titulo: Label
var _sub: Label
var _capa: TextureRect
var _sombra_capa: TextureRect
var _cantos: Array[ColorRect] = []
var _bordas: Array[ColorRect] = []
var _rec: Label


## Vai para a fase passando pela foto. Quem chama: a escolha de cenário e o
## JOGAR DE NOVO do resultado (scripts/fim_partida.gd).
static func ir(destino: String) -> void:
	var arvore := Engine.get_main_loop() as SceneTree
	var tg: Node = arvore.root.get_node_or_null("TransicaoGlobal")
	if tg == null or tg.em_transicao:
		return
	# partida nova: a foto da anterior (se não entrou no ranking) vai embora
	RankingManager.foto_da_partida = ""
	RankingManager.carregar()
	RankingManager.faxina_fotos()
	var w: Webcam = Maquina.webcam
	if w == null or not w.quer_foto():
		if w != null:
			w.soltar()
		tg.trocar_cena(destino)
		return
	w.ligar()
	arvore.set_meta(META_DESTINO, destino)
	tg.trocar_cena(CENA)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arvore := get_tree()
	if arvore.has_meta(META_DESTINO):
		_destino = str(arvore.get_meta(META_DESTINO))
		arvore.remove_meta(META_DESTINO)
	var fase: Dictionary = TransicaoGlobal.FASES.get(_destino, {})
	_cor = fase.get("cor", _cor)
	_webcam = Maquina.webcam
	if _webcam != null:
		_webcam.ligar()
		_webcam.definir_ritmo(RITMO_PREVIA_LEVE if Maquina.qualidade_leve() else RITMO_PREVIA)
		_espera_max = ESPERA_CONHECIDA if _webcam.conhecida() else ESPERA_NOVA
	_montar(fase)
	_layout()
	get_viewport().size_changed.connect(_layout)
	Maquina.aquecer([SOM_CONTAGEM, SOM_OBTURADOR])
	var viva := _webcam != null and _webcam.pronta()
	Tela.marca("pose: para %s (webcam %s)" % [_destino.get_file(), "ao vivo" if viva else "abrindo"])
	# a tela entra parada (a troca de tela a monta escondida): com a imagem
	# já viva, ela aparece direto, sem um quadro de "PREPARANDO A CÂMERA"
	if viva:
		_previa.texture = _webcam.textura()
	_mostrar_espera(not viva)


# ================================================================ o passo a passo
func _process(delta: float) -> void:
	_t += delta
	_sobre.queue_redraw()
	var viva := _webcam != null and _webcam.pronta()
	if viva and _passo in [Passo.ESPERANDO, Passo.CONTANDO]:
		var tex := _webcam.textura()
		if _previa.texture != tex:
			_previa.texture = tex
	match _passo:
		Passo.ESPERANDO:
			_espera += delta
			if viva:
				Tela.marca("pose: imagem em %.1f s" % _espera)
				_comecar_contagem()
			elif _espera >= _espera_max:
				Tela.marca("pose: sem imagem em %.1f s, segue sem foto" % _espera)
				_sem_foto()
		Passo.CONTANDO:
			if not viva:
				# a imagem parou: o relógio da pose para junto
				_parada += delta
				_mostrar_espera(true)
				if _parada >= ESPERA_NA_CONTAGEM:
					Tela.marca("pose: a imagem parou na contagem, segue sem foto")
					_sem_foto()
				return
			if _parada > 0.0:
				_parada = 0.0
				_ultimo_numero = 0   # o número volta a aparecer
				_mostrar_espera(false)
			_restante -= delta
			if not _obturador_aberto and _restante <= JANELA_OBTURADOR:
				_obturador_aberto = true
				_webcam.abrir_obturador(int(JANELA_OBTURADOR * 1000.0) + 250)
			var n := maxi(1, int(ceil(_restante)))
			if _restante > 0.0 and n != _ultimo_numero:
				_ultimo_numero = n
				_bater_numero(str(n))
				Maquina.efeito(SOM_CONTAGEM, -3.0)
			if _restante <= 0.0:
				_tirar()
		Passo.FOTO:
			_espera += delta
			if _espera >= MOSTRAR_FOTO:
				_sair()
		Passo.SEM_FOTO:
			_espera += delta
			if _espera >= MOSTRAR_SEM_FOTO:
				_sair()


func _comecar_contagem() -> void:
	_passo = Passo.CONTANDO
	_restante = CONTAGEM
	_ultimo_numero = 0
	_parada = 0.0
	_obturador_aberto = false
	_mostrar_espera(false)
	_legenda.text = "OLHE PARA A CÂMERA!"


func _tirar() -> void:
	_foto = _webcam.tirar_foto() if _webcam != null else ""
	if _foto == "":
		_sem_foto()
		return
	_passo = Passo.FOTO
	_espera = 0.0
	# a imagem para no quadro da foto (o mesmo que foi para o arquivo)
	if _webcam.ultima_foto != null:
		_previa.texture = ImageTexture.create_from_image(_webcam.ultima_foto)
	_clarao.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_clarao, "color:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Maquina.efeito(SOM_OBTURADOR, 0.0)
	_bater_numero("FOTO!")
	_legenda.text = "PREPARE A MIRA!"
	RankingManager.foto_da_partida = _foto
	# a webcam já pode descansar: a fase não precisa dela
	_webcam.soltar()


func _sem_foto() -> void:
	_passo = Passo.SEM_FOTO
	_espera = 0.0
	_mostrar_espera(false)
	_aviso_visor.visible = false
	_numero.text = ""
	_legenda.text = "VAMOS JOGAR!"
	if _webcam != null:
		_webcam.soltar()


func _sair() -> void:
	if _passo == Passo.SAINDO:
		return
	_passo = Passo.SAINDO
	if _webcam != null and _foto == "":
		_webcam.soltar()
	TransicaoGlobal.trocar_cena(_destino)


# ================================================================ visual
func _montar(fase: Dictionary) -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.025, 0.04)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	# a capa do cenário em cima, escurecida, sumindo no fundo
	_capa = TextureRect.new()
	_capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_capa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_capa.modulate = Color(0.55, 0.55, 0.55)
	var capa := str(fase.get("capa", ""))
	if capa != "" and ResourceLoader.exists(capa):
		_capa.texture = load(capa)
	add_child(_capa)
	_sombra_capa = TextureRect.new()
	_sombra_capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sombra_capa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sombra_capa.stretch_mode = TextureRect.STRETCH_SCALE
	var grad := Gradient.new()
	grad.set_color(0, Color(fundo.color, 0.0))
	grad.set_color(1, fundo.color)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 4
	gt.height = 64
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	_sombra_capa.texture = gt
	add_child(_sombra_capa)

	_titulo = _rotulo(86, Color.WHITE, FONTE_FORTE, 14, _cor.darkened(0.55))
	_titulo.text = "FAÇA SUA POSE!"
	add_child(_titulo)
	_sub = _rotulo(34, _cor.lerp(Color.WHITE, 0.35), FONTE, 8, Color(0, 0, 0, 0.9))
	_sub.text = "SUA FOTO VAI PARA O RANKING"
	add_child(_sub)

	# o visor: a imagem da webcam com cantos de máquina fotográfica
	_visor = Control.new()
	_visor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visor.clip_contents = true
	add_child(_visor)
	_previa_fundo = ColorRect.new()
	_previa_fundo.color = Color(0.05, 0.06, 0.085)
	_previa_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visor.add_child(_previa_fundo)
	_previa = TextureRect.new()
	_previa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_previa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_previa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if _webcam != null:
		_previa.flip_h = _webcam.espelhar
		_previa.rotation_degrees = float(_webcam.girar)
	_visor.add_child(_previa)
	_clarao = ColorRect.new()
	_clarao.color = Color(1, 1, 1, 0)
	_clarao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visor.add_child(_clarao)
	_aviso_visor = _rotulo(40, Color(1, 1, 1, 0.9), FONTE, 8, Color(0, 0, 0, 0.9))
	_aviso_visor.text = "PREPARANDO A CÂMERA"
	_visor.add_child(_aviso_visor)
	_sobre = Control.new()
	_sobre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sobre.draw.connect(_desenhar_sobre)
	add_child(_sobre)
	_rec = _rotulo(30, Color(1, 1, 1, 0.95), FONTE_FORTE, 6, Color(0, 0, 0, 0.8))
	_rec.text = "REC"
	_rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_rec.position = Vector2(66, 26)
	_rec.size = Vector2(120, 38)
	_rec.visible = false
	_sobre.add_child(_rec)
	for i in 4:
		var b := ColorRect.new()
		b.color = Color(1, 1, 1, 0.30)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(b)
		_bordas.append(b)
	for i in 8:
		var c := ColorRect.new()
		c.color = _cor
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		_cantos.append(c)

	_numero = _rotulo(200, Color.WHITE, FONTE_FORTE, 18, _cor.darkened(0.45))
	_numero.pivot_offset = Vector2.ZERO
	add_child(_numero)
	_legenda = _rotulo(42, _cor.lerp(Color.WHITE, 0.25), FONTE_FORTE, 10, Color(0, 0, 0, 0.9))
	_legenda.text = "OLHE PARA A CÂMERA!"
	add_child(_legenda)


func _rotulo(tamanho: int, cor: Color, fonte: Font, contorno: int, cor_contorno: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_constant_override("outline_size", contorno)
	l.add_theme_color_override("font_outline_color", cor_contorno)
	return l


func _layout() -> void:
	var tela := get_viewport_rect().size
	var w := tela.x
	var capa_alto := roundf(w / 2.857)
	_capa.position = Vector2.ZERO
	_capa.size = Vector2(w, capa_alto)
	_sombra_capa.position = Vector2(0, capa_alto * 0.45)
	_sombra_capa.size = Vector2(w, capa_alto * 0.55 + 2.0)
	_titulo.position = Vector2(0, capa_alto * 0.5 - 70.0)
	_titulo.size = Vector2(w, 110)
	_sub.position = Vector2(0, capa_alto * 0.5 + 34.0)
	_sub.size = Vector2(w, 50)
	# visor + número + legenda, no meio do que sobra abaixo da capa
	var lado := minf(w - 200.0, 800.0)
	var grupo := lado + 380.0
	var livre := tela.y - capa_alto
	var topo := capa_alto + maxf(30.0, (livre - grupo) * 0.5)
	var x := (w - lado) * 0.5
	_visor.position = Vector2(x, topo)
	_visor.size = Vector2(lado, lado)
	_previa_fundo.size = _visor.size
	_previa.size = _visor.size
	_previa.pivot_offset = _visor.size * 0.5
	_clarao.size = _visor.size
	_aviso_visor.position = Vector2(0, lado * 0.5 + 70.0)
	_aviso_visor.size = Vector2(lado, 60)
	_sobre.position = _visor.position
	_sobre.size = _visor.size
	# borda fina em volta
	var e := 3.0
	_bordas[0].position = Vector2(x - e, topo - e); _bordas[0].size = Vector2(lado + 2 * e, e)
	_bordas[1].position = Vector2(x - e, topo + lado); _bordas[1].size = Vector2(lado + 2 * e, e)
	_bordas[2].position = Vector2(x - e, topo); _bordas[2].size = Vector2(e, lado)
	_bordas[3].position = Vector2(x + lado, topo); _bordas[3].size = Vector2(e, lado)
	# cantos em L (visor de máquina fotográfica)
	var g := 10.0   # grossura
	var c := 96.0   # comprimento
	var f := 14.0   # afastado da imagem
	var pontos := [Vector2(x - f, topo - f), Vector2(x + lado + f, topo - f),
		Vector2(x - f, topo + lado + f), Vector2(x + lado + f, topo + lado + f)]
	for i in 4:
		var p: Vector2 = pontos[i]
		var dx := 1.0 if i % 2 == 0 else -1.0
		var dy := 1.0 if i < 2 else -1.0
		var h := _cantos[i * 2]
		h.size = Vector2(c, g)
		h.position = Vector2(p.x if dx > 0 else p.x - c, p.y if dy > 0 else p.y - g)
		var v := _cantos[i * 2 + 1]
		v.size = Vector2(g, c)
		v.position = Vector2(p.x if dx > 0 else p.x - g, p.y if dy > 0 else p.y - c)
	var base := topo + lado + f + g
	_numero.position = Vector2(0, base + 8.0)
	_numero.size = Vector2(w, 240)
	_numero.pivot_offset = _numero.size * 0.5
	_legenda.position = Vector2(0, base + 268.0)
	_legenda.size = Vector2(w, 70)


func _mostrar_espera(sim: bool) -> void:
	_aviso_visor.visible = sim
	if sim:
		_numero.text = ""


func _bater_numero(texto: String) -> void:
	_numero.text = texto
	_numero.add_theme_font_size_override("font_size", 200 if texto.length() <= 2 else 130)
	_numero.scale = Vector2(1.55, 1.55)
	_numero.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_numero, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_numero, "modulate:a", 1.0, 0.12)


## O anel girando (esperando a imagem) e o "REC" piscando (imagem ao vivo).
func _desenhar_sobre() -> void:
	var tam := _sobre.size
	if _aviso_visor.visible:
		var centro := tam * 0.5
		var a := _t * 5.0
		Pincel.anel(_sobre, centro, 44.0, 7.0, Color(1, 1, 1, 0.14))
		Pincel.arco(_sobre, centro, 44.0, a, a + 1.7, _cor, 7.0)
	# "REC" piscando enquanto a imagem está ao vivo na contagem
	var rec := _passo == Passo.CONTANDO and not _aviso_visor.visible and fmod(_t, 1.0) < 0.6
	if _rec.visible != rec:
		_rec.visible = rec
	if rec:
		Pincel.circulo(_sobre, Vector2(44, 45), 13.0, Color(1.0, 0.15, 0.12))
