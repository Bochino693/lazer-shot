extends CanvasLayer
class_name AnuncioCombo

## ANUNCIADOR DE COMBOS, igual nas quatro telas e com a cara de cada uma.
## Cada acerto seguido mostra o nível do combo grande no meio da tela: o
## texto entra estourando (vem grande e assenta com um quique), um clarão e
## raios de luz saem de trás dele, faíscas espirram, e ele sobe e some.
## Num nível novo a voz da tela anuncia (Poseidon no Mar, o deus do templo
## no Egito, o locutor do saloon no Bar, a locutora da Arena) e a música
## abaixa um pouco enquanto ela fala. Entre um nível e outro só um pulinho
## no número (x7).

const NIVEIS = [
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
const LENDARIO_A_CADA = 4
# cor do texto, contorno, clarão, faíscas, altura (fração da tela), estilo
const TEMAS = {
	"mar": [Color(0.72, 0.98, 1.0), Color(0.0, 0.14, 0.30), Color(0.2, 0.75, 1.0), Color(0.88, 0.98, 1.0), 0.205, "agua"],
	"deserto": [Color(1.0, 0.86, 0.34), Color(0.32, 0.1, 0.0), Color(1.0, 0.6, 0.18), Color(1.0, 0.96, 0.7), 0.31, "sol"],
	"bar": [Color(1.0, 0.82, 0.38), Color(0.16, 0.07, 0.02), Color(1.0, 0.52, 0.14), Color(1.0, 0.78, 0.36), 0.152, "saloon"],
	"arena": [Color(0.62, 1.0, 0.5), Color(0.04, 0.1, 0.26), Color(0.3, 0.75, 1.0), Color(0.55, 0.95, 1.0), 0.335, "neon"],
}
const DUCK_DB = -7.0

var tela = "mar"

var _raiz: Node2D
var _clarao: Sprite
var _raios: Sprite
var _placa: Panel
var _texto: Label
var _numero: Label
var _luz: Particulas
var _bolhas: Particulas
var _voz: AudioStreamPlayer
var _vozes = {}
var _tema = []
var _tw: SceneTreeTween
var _nivel_atual = -1
var _vivo = 0.0
var _bus_musica = -1
var _musica_db = 0.0
var _abaixada = false


static func criar(pai: Node, nome_tela: String) -> AnuncioCombo:
	var a = load("res://scripts/anuncio_combo.gd").new()
	a.tela = nome_tela
	a.layer = 46
	pai.add_child(a)
	return a


func _ready() -> void:
	_tema = TEMAS.get(tela, TEMAS["mar"])
	_bus_musica = AudioServer.get_bus_index("Musica")
	for n in NIVEIS:
		_carregar_voz(n[2])
	_carregar_voz("especial")
	_raiz = Node2D.new()
	_raiz.position = Vector2(Tela.TELA.x * 0.5, Tela.TELA.y * _tema[4])
	_raiz.visible = false
	add_child(_raiz)
	_clarao = Sprite.new()
	_clarao.texture = Estilo.tex("fx_brilho")
	_clarao.material = Estilo.material_soma()
	_clarao.scale = Vector2(7.5, 2.4)
	_clarao.modulate = _tema[2]
	_raiz.add_child(_clarao)
	_raios = Sprite.new()
	_raios.texture = Estilo.tex("fx_raios")
	_raios.material = Estilo.material_soma()
	_raios.scale = Vector2(1.5, 1.5)
	_raios.modulate = Color(_tema[2].r, _tema[2].g, _tema[2].b, 0.55)
	_raiz.add_child(_raios)
	if _tema[5] == "saloon":
		var madeira = Estilo.caixa(Color(0.30, 0.16, 0.06, 0.96), Color(0.12, 0.05, 0.01, 1.0), 6, 10, 14, Color(0, 0, 0, 0.55))
		_placa = Estilo.painel(_raiz, Vector2(-380, -72), Vector2(760, 144), madeira)
		_placa.rect_pivot_offset = Vector2(380, 72)
		var veios = Node2D.new()
		veios.connect("draw", self, "_desenhar_veios")
		_placa.add_child(veios)
	_texto = Estilo.rotulo(_raiz, "", 104, _tema[0], 10, true, Label.ALIGN_CENTER, _tema[1])
	Estilo.colocar(_texto, Vector2(-512, -80), Vector2(1024, 150))
	_numero = Estilo.rotulo(_raiz, "", 58, Color.white, 7, true, Label.ALIGN_CENTER, _tema[1])
	Estilo.colocar(_numero, Vector2(-200, 46), Vector2(400, 80))
	_luz = Particulas.new()
	_luz.somar = true
	add_child(_luz)
	if _tema[5] == "agua":
		_bolhas = Particulas.new()
		add_child(_bolhas)
	_voz = AudioStreamPlayer.new()
	_voz.bus = "Efeitos"
	_voz.connect("finished", self, "_voz_terminou")
	add_child(_voz)
	Estilo.aquecer_fonte(Estilo.fonte(104, true, 10, _tema[1]), "ABCDEFGHIJKLMNOPQRSTUVWXYZ!' ")
	Estilo.aquecer_fonte(Estilo.fonte(58, true, 7, _tema[1]), "x0123456789")
	set_process(false)


func _carregar_voz(fala: String) -> void:
	var c = "res://songs/voz/%s_%s.ogg" % [tela, fala]
	if ResourceLoader.exists(c):
		_vozes[fala] = load(c)


func _desenhar_veios() -> void:
	# tábua: veios claros e quatro pregos
	var n = _placa.get_child(0) as Node2D
	for i in 5:
		var y = 26.0 + i * 24.0
		n.draw_line(Vector2(22, y), Vector2(738, y + (i % 2) * 3.0), Color(0.48, 0.28, 0.12, 0.35), 2.0)
	for p in [Vector2(26, 24), Vector2(734, 24), Vector2(26, 120), Vector2(734, 120)]:
		n.draw_circle(p, 7.0, Color(0.12, 0.10, 0.08))
		n.draw_circle(p - Vector2(2, 2), 3.0, Color(0.75, 0.68, 0.55))


## Acertos seguidos agora (1 = só um acerto: nada aparece).
func combo(n: int) -> void:
	if n < 2:
		return
	var nivel = -1
	for i in NIVEIS.size():
		if n >= NIVEIS[i][0]:
			nivel = i
	if nivel < 0:
		return
	var novo = nivel != _nivel_atual
	var fala = ""
	if novo:
		fala = NIVEIS[nivel][2]
	elif nivel == NIVEIS.size() - 1 and (n - NIVEIS[nivel][0]) % LENDARIO_A_CADA == 0:
		novo = true
		fala = "lendario"
	_nivel_atual = nivel
	_mostrar(NIVEIS[nivel][1], "x%d" % n if n > 2 else "", novo, 1.0 + 0.06 * nivel)
	if fala != "":
		_falar(fala)


## Anúncio especial (POWER OF RA!, PERFECT SEQUENCE!, POSEIDON'S TREASURE!).
func especial(texto: String) -> void:
	_mostrar(texto, "", true, 1.25)
	_falar("especial")


func zerar() -> void:
	_nivel_atual = -1


func _falar(fala: String) -> void:
	var s: AudioStream = _vozes.get(fala, null)
	if s == null:
		return
	_voz.stream = s
	_voz.play()
	if _bus_musica >= 0 and not _abaixada:
		_musica_db = AudioServer.get_bus_volume_db(_bus_musica)
		AudioServer.set_bus_volume_db(_bus_musica, _musica_db + DUCK_DB)
		_abaixada = true


func _voz_terminou() -> void:
	if _abaixada and _bus_musica >= 0:
		AudioServer.set_bus_volume_db(_bus_musica, _musica_db)
		_abaixada = false


func _mostrar(texto: String, numero: String, forte: bool, forca: float) -> void:
	_texto.text = texto
	# texto comprido (PERFECT SEQUENCE!) diminui até caber na tela
	var largura = _texto.get_font("font").get_string_size(texto).x + 24.0
	forca = min(forca, (Tela.TELA.x - 70.0) / max(largura, 1.0))
	_numero.text = numero
	_raiz.visible = true
	_raiz.modulate = Color.white
	_raiz.position = Vector2(Tela.TELA.x * 0.5, Tela.TELA.y * _tema[4])
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	if forte:
		_raiz.scale = Vector2.ONE * 1.9 * forca
		_clarao.modulate.a = 1.0
		_raios.modulate.a = 0.6
		_tw.tween_property(_raiz, "scale", Vector2.ONE * forca, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.parallel().tween_property(_clarao, "modulate:a", 0.25, 0.5)
		_explodir(forca)
	else:
		_raiz.scale = Vector2.ONE * forca * 1.12
		_tw.tween_property(_raiz, "scale", Vector2.ONE * forca, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_interval(0.55 if forte else 0.4)
	_tw.tween_property(_raiz, "position:y", _raiz.position.y - 70.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tw.parallel().tween_property(_raiz, "modulate:a", 0.0, 0.45)
	_tw.tween_callback(self, "_esconder")
	_vivo = 0.0
	set_process(true)


func _explodir(forca: float) -> void:
	var c = _raiz.position
	var cor: Color = _tema[3]
	match _tema[5]:
		"agua":
			_bolhas.explosao(c, {"n": 16, "tex": Estilo.tex("mar_bolha"), "vel": [60.0, 260.0], "ang": [200.0, 340.0],
				"vida": [0.6, 1.2], "tam": [12.0, 26.0], "fim": 0.9, "cor": Color(0.85, 0.97, 1.0, 0.9), "grav": -300.0, "espalha": 260.0})
		"saloon":
			_luz.explosao(c, {"n": 22, "vel": [250.0, 700.0], "vida": [0.25, 0.55], "tam": [6.0, 12.0],
				"cor": Color(1.0, 0.7, 0.3), "grav": 900.0, "estica": 0.04, "espalha": 200.0})
		_:
			_luz.explosao(c, {"n": int(24 * forca), "vel": [200.0, 620.0], "vida": [0.3, 0.7], "tam": [7.0, 14.0],
				"cor": cor, "grav": 300.0, "estica": 0.03, "arrasto": 1.5, "espalha": 220.0})


func _esconder() -> void:
	_raiz.visible = false
	set_process(false)


func _process(delta: float) -> void:
	_vivo += delta
	_raios.rotation += delta * 0.8
