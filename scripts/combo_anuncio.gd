class_name ComboAnuncio
extends CanvasLayer

## Anunciador de combos, igual nas quatro telas e com a cara de cada uma.
## Cada acerto seguido mostra o nível do combo grande no meio da tela: o
## texto entra estourando (vem grande e assenta com um quique), um clarão e
## raios de luz saem de trás dele, faíscas espirram, e ele sobe e some.
## Quando o combo chega num nível novo, a voz da tela anuncia (Poseidon no
## Mar, o deus do templo no Egito, o locutor do saloon no Bar, a locutora da
## Arena) e a música abaixa um pouco enquanto ela fala. Os acertos entre um
## nível e outro só dão um pulinho no texto com o número (x7).
## As vozes são songs/voz/<tela>_<fala>.ogg (tools/gerar_vozes.py).
## Leve: um rótulo, um sprite de clarão, um desenho de raios e um sistema de
## partículas; parado, nada roda.

# [acertos seguidos, texto, fala]
const Pincel := preload("res://scripts/pincel.gd")
const NIVEIS := [
	[2, "DOUBLE HIT", "double"],
	[3, "TRIPLE HIT", "triple"],
	[4, "QUADRA HIT", "quadra"],
	[5, "PENTA HIT", "penta"],
	[6, "MEGA COMBO", "mega"],
	[8, "SUPER COMBO", "super"],
	[10, "INSANE", "insano"],
	[13, "UNSTOPPABLE", "imparavel"],
	[16, "LEGENDARY", "lendario"],
]
const LENDARIO_A_CADA := 4      # depois de LEGENDARY, a voz volta a cada 4

# cor do texto, contorno, clarão, faíscas, onde fica o meio do anúncio
# (fração da altura da tela) e o efeito de cada tela:
#   mar      água: letra de espuma clara, ondas abrindo na água e bolhas
#            subindo (no alto da água, acima de onde os alvos nadam)
#   deserto  sol: letra de ouro, raios de sol girando e faíscas douradas
#   bar      saloon: placa de madeira com pregos, letra de ouro velho,
#            estouro de pólvora e faíscas; bem no alto, acima das garrafas
#            de 100 (não tampa nenhuma fileira)
#   arena    laser tag: letra neon, duas linhas de laser abrindo e faíscas
#            ciano (logo abaixo do letreiro)
const TEMAS := {
	"mar": [Color(0.72, 0.98, 1.0), Color(0.0, 0.14, 0.30), Color(0.2, 0.75, 1.0), Color(0.88, 0.98, 1.0), 0.205, "agua"],
	"deserto": [Color(1.0, 0.86, 0.34), Color(0.32, 0.1, 0.0), Color(1.0, 0.6, 0.18), Color(1.0, 0.96, 0.7), 0.31, "sol"],
	"bar": [Color(1.0, 0.82, 0.38), Color(0.16, 0.07, 0.02), Color(1.0, 0.52, 0.14), Color(1.0, 0.78, 0.36), 0.152, "saloon"],
	"arena": [Color(0.62, 1.0, 0.5), Color(0.04, 0.1, 0.26), Color(0.3, 0.75, 1.0), Color(0.55, 0.95, 1.0), 0.335, "neon"],
}
const BOLHA := "res://sprites/mar_bolha.png"
const FONTE := "res://fonts/Exo2-ExtraBold.ttf"
const TAMANHO_FONTE := 104
const DUCK_DB := -7.0           # quanto a música abaixa enquanto a voz fala

var tela := "mar"

var _raiz: Node2D
var _clarao: Sprite2D
var _raios: Node2D
var _faiscas: CPUParticles2D
var _texto: Label
var _numero: Label
var _voz: AudioStreamPlayer
var _vozes: Dictionary = {}
var _tw: Tween
var _t := 0.0                   # tempo desde o último anúncio
var _forca := 1.0               # tamanho do último anúncio (cresce com o nível)
var _cores: Array = []
var _ativo := false
var _duck := 0.0                # 0..1, quanto a música está abaixada agora
var _bus_musica := -1
var _fonte: Font
var _altura := 0.31
var _estilo := "sol"
var _placa: Node2D             # a placa de madeira do saloon (só no Bar)
var _placa_larg := 600.0


## Cria o anunciador da tela (filho de `pai`).
static func criar(pai: Node, nome_tela: String) -> ComboAnuncio:
	var a := ComboAnuncio.new()
	a.tela = nome_tela
	pai.add_child(a)
	return a


func _ready() -> void:
	name = "ComboAnuncio"
	layer = 46
	_cores = TEMAS.get(tela, TEMAS["mar"])
	_altura = _cores[4]
	_estilo = _cores[5]
	_bus_musica = AudioServer.get_bus_index("Musica")
	for n in NIVEIS:
		_carregar_voz(n[2])
	_carregar_voz("especial")

	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_raiz = Node2D.new()
	add_child(_raiz)
	if _estilo == "saloon":
		_placa = Node2D.new()
		_placa.draw.connect(_desenhar_placa)
		_raiz.add_child(_placa)

	_clarao = Sprite2D.new()
	_clarao.texture = FundoVivo.brilho_redondo()
	_clarao.material = soma
	_raiz.add_child(_clarao)

	_raios = Node2D.new()
	_raios.material = soma
	_raios.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_raios.draw.connect(_desenhar_raios)
	_raiz.add_child(_raios)

	_faiscas = CPUParticles2D.new()
	_faiscas.material = soma
	_faiscas.texture = FundoVivo.brilho_redondo()
	_faiscas.emitting = false
	_faiscas.one_shot = true
	_faiscas.amount = 34
	_faiscas.lifetime = 0.9
	_faiscas.explosiveness = 1.0
	_faiscas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_faiscas.emission_rect_extents = Vector2(260, 40)
	_faiscas.direction = Vector2(0, -1)
	_faiscas.spread = 180.0
	_faiscas.initial_velocity_min = 260.0
	_faiscas.initial_velocity_max = 620.0
	_faiscas.gravity = Vector2(0, 700)
	_faiscas.damping_min = 60.0
	_faiscas.damping_max = 120.0
	_faiscas.scale_amount_min = 0.10
	_faiscas.scale_amount_max = 0.26
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	rampa.colors = PackedColorArray([Color(1, 1, 1, 1), Color(_cores[3], 0.9), Color(_cores[3], 0.0)])
	_faiscas.color_ramp = rampa
	match _estilo:
		"agua":
			# bolhas saindo das letras e subindo (sem cair)
			if ResourceLoader.exists(BOLHA):
				_faiscas.texture = load(BOLHA)
			_faiscas.material = null
			_faiscas.lifetime = 1.3
			_faiscas.gravity = Vector2(0, -260)
			_faiscas.initial_velocity_min = 60.0
			_faiscas.initial_velocity_max = 220.0
			_faiscas.scale_amount_min = 0.25
			_faiscas.scale_amount_max = 0.7
			rampa.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(_cores[3], 0.75), Color(_cores[3], 0.0)])
			rampa.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
		"saloon":
			# pólvora: faíscas mais baixas e rápidas, para os lados
			_faiscas.emission_rect_extents = Vector2(220, 30)
			_faiscas.spread = 100.0
			_faiscas.direction = Vector2(0, -1)
			_faiscas.initial_velocity_min = 180.0
			_faiscas.initial_velocity_max = 520.0
			_faiscas.lifetime = 0.6
	_raiz.add_child(_faiscas)

	_fonte = load(FONTE) if ResourceLoader.exists(FONTE) else ThemeDB.fallback_font
	_texto = _rotulo(_fonte, TAMANHO_FONTE, 14)
	_numero = _rotulo(_fonte, 62, 10)
	_numero.position.y += 92.0

	_voz = AudioStreamPlayer.new()
	_voz.bus = "Efeitos"
	add_child(_voz)

	_posicionar()
	get_viewport().size_changed.connect(_posicionar)
	# desenha as letras uma vez, quase invisíveis: o primeiro combo não engasga
	# montando as letras grandes na hora
	_texto.text = "DOUBLETRIPLEQUADRAPENTAMEGASUPERINSANEUNSTOPPABLELEGENDARYHIT'S!"
	_numero.text = "x0123456789"
	_raiz.modulate = Color(1, 1, 1, 0.004)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _ativo:
		_esconder()


func _rotulo(fonte: Font, tamanho: int, contorno: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(1400, 150)
	l.position = -l.size * 0.5
	l.pivot_offset = l.size * 0.5
	if fonte != null:
		Leve.font(l, "font", fonte)
	Leve.font_size(l, "font_size", tamanho)
	Leve.color(l, "font_color", _cores[0])
	Leve.color(l, "font_outline_color", _cores[1])
	Leve.constant(l, "outline_size", contorno)
	Leve.color(l, "font_shadow_color", Color(0, 0, 0, 0.55))
	Leve.constant(l, "shadow_offset_x", 0)
	Leve.constant(l, "shadow_offset_y", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(l)
	return l


func _carregar_voz(fala: String) -> void:
	var caminho := "res://songs/voz/%s_%s.ogg" % [tela, fala]
	if ResourceLoader.exists(caminho):
		_vozes[fala] = load(caminho)


func _posicionar() -> void:
	var tam := get_viewport().get_visible_rect().size
	_raiz.position = Vector2(tam.x * 0.5, tam.y * _altura)


## Mais um acerto seguido (n = quantos já foram). falar = false: só o texto
## (quando outra fala mais importante vem junto, como o especial).
func combo(n: int, falar: bool = true) -> void:
	if n < 2:
		return
	var nivel := -1
	for i in NIVEIS.size():
		if n >= int(NIVEIS[i][0]):
			nivel = i
	var limiar := int(NIVEIS[nivel][0])
	var novo := n == limiar
	var lendario_de_novo := nivel == NIVEIS.size() - 1 and n > limiar and (n - limiar) % LENDARIO_A_CADA == 0
	var texto: String = NIVEIS[nivel][1]
	if novo or lendario_de_novo:
		_mostrar(texto, "x%d" % n if n > limiar else "", 1.0 + nivel * 0.07, 14 + nivel * 4)
		if falar:
			_falar(NIVEIS[nivel][2])
	else:
		_pulinho(texto, "x%d" % n)


## Um momento especial da tela (descarga do cristal, cardume dourado,
## sequência perfeita): texto e voz próprios, com tudo no máximo.
func especial(texto: String) -> void:
	_mostrar(texto, "", 1.25, 46)
	_falar("especial")


## O combo quebrou: o anúncio sai rápido.
func zerar() -> void:
	if not _ativo:
		return
	_parar_tween()
	_tw = create_tween()
	_tw.tween_property(_raiz, "modulate:a", 0.0, 0.12)
	_tw.tween_callback(_esconder)


func _mostrar(texto: String, numero: String, forca: float, faiscas: int) -> void:
	_parar_tween()
	_ativo = true
	_t = 0.0
	_forca = forca
	_raiz.visible = true
	_raiz.modulate = Color.WHITE
	_texto.text = texto
	_numero.text = numero
	_numero.visible = numero != ""
	# cabe na tela: textos compridos (POSEIDON'S TREASURE!) encolhem
	var largura := get_viewport().get_visible_rect().size.x
	var w := _fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO_FONTE).x + 28.0
	var e := minf(forca, (largura - (160.0 if _placa != null else 60.0)) / maxf(w, 1.0))
	_texto.scale = Vector2.ONE * e * 2.5
	_texto.rotation = randf_range(-0.16, 0.16)
	_texto.modulate = Color(1.8, 1.8, 1.8, 0.0)
	_numero.scale = Vector2.ONE * e * 0.3
	_numero.modulate = Color(1, 1, 1, 0)
	_raiz.position.y = get_viewport().get_visible_rect().size.y * _altura
	_clarao.modulate = Color(_cores[2], 0.95)
	_clarao.scale = Vector2.ONE * 0.4
	_faiscas.amount = faiscas
	_faiscas.restart()
	_faiscas.emitting = true
	if _placa != null:
		# a placa acompanha o texto: chega balançando presa nas correntes
		_placa_larg = w * e + 90.0
		_placa.queue_redraw()
		_placa.scale = Vector2(1.0, 0.2)
		_placa.rotation = randf_range(-0.12, 0.12)

	_tw = create_tween()
	_tw.set_parallel(true)
	# o texto chega estourando e assenta com um quique
	_tw.tween_property(_texto, "scale", Vector2.ONE * e, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(_texto, "rotation", randf_range(-0.035, 0.035), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(_texto, "modulate", Color(1.8, 1.8, 1.8, 1.0), 0.06)
	_tw.tween_property(_texto, "modulate", Color.WHITE, 0.30).set_delay(0.06)
	_tw.tween_property(_numero, "scale", Vector2.ONE * e, 0.22).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(_numero, "modulate", Color.WHITE, 0.10).set_delay(0.12)
	if _placa != null:
		_tw.tween_property(_placa, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_property(_placa, "rotation", _texto.rotation * 0.4, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# clarão por trás
	_tw.tween_property(_clarao, "scale", Vector2.ONE * 9.0 * forca, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tw.tween_property(_clarao, "modulate:a", 0.0, 0.55).set_delay(0.05)
	# respira um pouco e depois sobe sumindo
	_tw.chain().tween_property(_texto, "scale", Vector2.ONE * e * 1.07, 0.18).set_trans(Tween.TRANS_SINE)
	_tw.chain().tween_property(_texto, "scale", Vector2.ONE * e, 0.22).set_trans(Tween.TRANS_SINE)
	_tw.chain().tween_interval(0.35)
	_tw.chain().tween_property(_raiz, "position:y", _raiz.position.y - 70.0, 0.32).set_ease(Tween.EASE_IN)
	_tw.parallel().tween_property(_raiz, "modulate:a", 0.0, 0.32).set_ease(Tween.EASE_IN)
	_tw.chain().tween_callback(_esconder)
	set_process(true)


## Acerto entre dois níveis: o texto dá um pulinho e o número aparece.
func _pulinho(texto: String, numero: String) -> void:
	if not _ativo:
		_mostrar(texto, numero, _forca, 10)
		return
	_texto.text = texto
	_numero.text = numero
	_numero.visible = true
	_numero.modulate = Color.WHITE
	_faiscas.amount = 10
	_faiscas.restart()
	_faiscas.emitting = true
	_parar_tween()
	_raiz.modulate = Color.WHITE
	_raiz.position.y = get_viewport().get_visible_rect().size.y * _altura
	var e := _texto.scale.x
	if e < 0.3:
		e = _forca
	_texto.scale = Vector2.ONE * e * 1.22
	_numero.scale = Vector2.ONE * e * 1.4
	_tw = create_tween()
	_tw.set_parallel(true)
	_tw.tween_property(_texto, "scale", Vector2.ONE * e, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(_numero, "scale", Vector2.ONE * e, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.chain().tween_interval(0.6)
	_tw.chain().tween_property(_raiz, "position:y", _raiz.position.y - 60.0, 0.3).set_ease(Tween.EASE_IN)
	_tw.parallel().tween_property(_raiz, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	_tw.chain().tween_callback(_esconder)
	_t = 0.0
	set_process(true)


func _falar(fala: String) -> void:
	var s: AudioStream = _vozes.get(fala)
	if s == null:
		return
	_voz.stream = s
	_voz.play()
	set_process(true)


func _parar_tween() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null


func _esconder() -> void:
	_ativo = false
	_raiz.visible = false
	_raiz.modulate = Color.WHITE


func _process(delta: float) -> void:
	_t += delta
	# a música abaixa enquanto a voz fala e volta devagar
	var alvo := 1.0 if _voz.playing else 0.0
	var antes := _duck
	_duck = move_toward(_duck, alvo, delta * (12.0 if alvo > _duck else 2.5))
	if _duck != antes:
		_aplicar_duck()
	if _t < 0.75:
		_raios.queue_redraw()
	if not _ativo and _duck <= 0.0:
		set_process(false)


func _aplicar_duck() -> void:
	if _bus_musica < 0:
		return
	var base := float(Maquina.valor("audio/volume_musica"))
	AudioServer.set_bus_volume_db(_bus_musica, base + DUCK_DB * _duck)


func _exit_tree() -> void:
	# a música nunca fica abaixada se a tela sair no meio da fala
	_duck = 0.0
	_aplicar_duck()


## O efeito de trás do texto, um por tela, forte no começo e sumindo.
func _desenhar_raios() -> void:
	if not _ativo or _t >= 0.7:
		return
	var k := _t / 0.7
	var a := (1.0 - k) * (1.0 - k) * 0.55
	var abre := 1.0 - pow(1.0 - k, 3.0)
	match _estilo:
		"agua":
			# ondas na água abrindo a partir do texto (elipses achatadas)
			for i in 3:
				var ki := clampf(k * 1.25 - i * 0.16, 0.0, 1.0)
				if ki <= 0.0:
					continue
				var r := (120.0 + 520.0 * (1.0 - pow(1.0 - ki, 2.0))) * _forca
				# anel pelo pincel: na TV Box a luz somada só desenha
				# retângulos de textura (scripts/pincel.gd)
				_raios.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
				Pincel.anel(_raios, Vector2.ZERO, r, 7.0 - 4.0 * ki, Color(_cores[2], 0.5 * (1.0 - ki)))
			_raios.draw_set_transform(Vector2.ZERO)
		"saloon":
			# estouro de pólvora: estrela de pontas curtas e grossas
			var r2 := (150.0 + 300.0 * abre) * _forca
			var cores2 := PackedColorArray([Color(1.0, 0.9, 0.6, a * 1.4), Color(_cores[2], 0.0), Color(_cores[2], 0.0)])
			for i in 10:
				var ang := TAU * i / 10.0 + 0.3
				var comp := r2 * (1.0 if i % 2 == 0 else 0.62)
				var p0 := Vector2.from_angle(ang - 0.13) * comp * 0.35
				var p1 := Vector2.from_angle(ang + 0.13) * comp * 0.35
				_raios.draw_polygon(PackedVector2Array([p0, Vector2.from_angle(ang) * comp, p1]), cores2)
		"neon":
			# duas linhas de laser abrindo para os lados, acima e abaixo do texto
			var meia := (200.0 + 520.0 * abre) * _forca
			for y in [-82.0, 82.0]:
				for camada in [[16.0, 0.25], [6.0, 0.6], [2.0, 1.0]]:
					var cor := Color(_cores[2] if camada[1] < 1.0 else Color(0.9, 1.0, 1.0), a * 1.6 * float(camada[1]))
					Pincel.linha(_raios, Vector2(-meia, y), Vector2(meia, y), cor, float(camada[0]))
		_:
			# sol: raios de luz girando
			var r := (160.0 + 520.0 * abre) * _forca
			var cores := PackedColorArray([Color(_cores[2], a), Color(_cores[2], 0.0), Color(_cores[2], 0.0)])
			var n := 14
			var giro := _t * 0.9
			for i in n:
				var ang := giro + TAU * i / n
				var larg := 0.06 if i % 2 == 0 else 0.035
				var comp := r if i % 2 == 0 else r * 0.7
				var p0 := Vector2.from_angle(ang - larg) * comp
				var p1 := Vector2.from_angle(ang + larg) * comp
				_raios.draw_polygon(PackedVector2Array([Vector2.ZERO, p0, p1]), cores)


## A placa do saloon: tábua de madeira com veios, borda escura, dois pregos
## e as correntes subindo (desenhada uma vez por anúncio).
func _desenhar_placa() -> void:
	var w := _placa_larg
	var h := 136.0
	var r := Rect2(-w * 0.5, -h * 0.5, w, h)
	# correntes até o alto
	for x in [-w * 0.34, w * 0.34]:
		for i in 4:
			var y := -h * 0.5 - 14.0 - i * 18.0
			_placa.draw_rect(Rect2(x - 4.0, y - 8.0, 8.0, 14.0), Color(0.22, 0.18, 0.14, 0.9), false, 2.5)
	_placa.draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.35))       # sombra
	_placa.draw_rect(r, Color(0.36, 0.20, 0.09, 0.96))
	# tábuas e veios
	var faixa := h / 3.0
	for i in 3:
		var y0 := -h * 0.5 + i * faixa
		var tom := 0.92 + 0.08 * float(i % 2)
		_placa.draw_rect(Rect2(-w * 0.5, y0, w, faixa - 2.0), Color(0.42 * tom, 0.24 * tom, 0.11 * tom, 0.96))
		for v in 3:
			var yy := y0 + faixa * (0.25 + 0.25 * v)
			_placa.draw_line(Vector2(-w * 0.5 + 10.0, yy), Vector2(w * 0.5 - 10.0, yy + sin(v * 1.7 + i) * 3.0),
				Color(0.22, 0.11, 0.04, 0.35), 1.5)
	_placa.draw_rect(r, Color(0.14, 0.06, 0.02, 1.0), false, 5.0)
	_placa.draw_rect(r.grow(-7.0), Color(0.62, 0.42, 0.22, 0.45), false, 2.0)
	for x in [-w * 0.5 + 18.0, w * 0.5 - 18.0]:
		for y in [-h * 0.5 + 16.0, h * 0.5 - 16.0]:
			_placa.draw_circle(Vector2(x, y), 6.0, Color(0.30, 0.28, 0.26))
			_placa.draw_circle(Vector2(x - 1.5, y - 1.5), 2.5, Color(0.75, 0.70, 0.62))
