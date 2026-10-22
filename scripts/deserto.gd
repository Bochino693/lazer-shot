extends "res://scripts/fase.gd"

## DESERTO SAGRADO (Egito), em 2D para a Mali-450.
##
## De dia acerte o SOL (Olho de Rá), de noite a LUA (Olho de Hórus): +20 a
## +100; o astro errado tira 20 a 100. O dia e a noite trocam a cada 30 s
## (o sol desce, a lua sobe). Combo do mesmo astro em até 2,2 s; a partir de
## 3 seguidos, cada acerto ganha combo x 5.
## Os brasões voam na frente do cenário (sem passar por trás de nada), com
## guinadas, e alguns trocam de astro no meio do voo (clarão branco).
##
## O CRISTAL do meio carrega com os acertos (os feixes de energia engrossam e
## correm); cheio, descarrega: "POWER OF RA!", raios das pontas dos
## obeliscos em todos os brasões certos da tela. Tiro no cristal o trinca
## (9 tiros quebram: +300) e tiro nos cristais das pontas dos obeliscos
## (4 tiros: +150); quebrados, apagam e voltam sozinhos depois.
## O cenário responde a cada tiro: a areia levanta e fica o furo, a pedra
## lasca, o ouro das pirâmides solta faíscas.

const MODO_SOL = "sol"
const MODO_LUA = "lua"
const COR_SOL = Color(1.0, 0.74, 0.18)
const COR_LUA = Color(0.56, 0.84, 1.0)
const TROCA_MODO = 30.0
const JANELA = 2.2
const BONUS_CRISTAL = 300
const BONUS_PONTA = 150
const CARGA_POR_ACERTO = 0.125
const CARGA_ERRO = 0.25
const TIROS_CRISTAL = 9
const TIROS_PONTA = 4
const CRISTAL_VOLTA = 30.0
const PONTA_VOLTA = 22.0

# px da imagem 1024x1536 (versão 4.6)
const CENTRO_ASTRO = Vector2(512, 300)
const POLI_CRISTAL = [Vector2(506, 626), Vector2(546, 668), Vector2(560, 720), Vector2(558, 900),
	Vector2(536, 968), Vector2(478, 968), Vector2(454, 900), Vector2(452, 720), Vector2(466, 668)]
const POLI_PONTAS = [
	[Vector2(209, 760), Vector2(195, 790), Vector2(193, 842), Vector2(225, 842), Vector2(223, 790)],
	[Vector2(812, 760), Vector2(799, 790), Vector2(797, 842), Vector2(830, 842), Vector2(826, 790)],
]
const PONTAS_OBELISCO = [Vector2(209, 800), Vector2(812, 800)]
const OURO_PIRAMIDES = [
	[Vector2(509, 447), Vector2(449, 524), Vector2(509, 501), Vector2(546, 497)],
	[Vector2(229, 519), Vector2(170, 580), Vector2(229, 558), Vector2(256, 554)],
	[Vector2(774, 519), Vector2(721, 582), Vector2(774, 560), Vector2(806, 556)],
]
const PIRAMIDES = [
	[Vector2(508, 444), Vector2(298, 742), Vector2(718, 742)],
	[Vector2(229, 516), Vector2(120, 700), Vector2(340, 700)],
	[Vector2(775, 516), Vector2(680, 700), Vector2(900, 700)],
]
const FEIXES = [
	[Vector2(488, 664), Vector2(207, 783)],
	[Vector2(528, 666), Vector2(815, 783)],
	[Vector2(482, 856), Vector2(224, 992)],
	[Vector2(536, 862), Vector2(800, 992)],
]
const CAIXA_MORTO = Rect2(428, 608, 160, 376)
const BRILHOS_PONTAS = [Vector2(229, 520), Vector2(509, 448), Vector2(774, 520)]
const BRILHOS_CRISTAL = [Vector2(506, 634), Vector2(466, 721), Vector2(548, 721), Vector2(486, 792),
	Vector2(527, 846), Vector2(505, 893), Vector2(461, 944), Vector2(551, 944)]
const SAIDAS_DE_TRAS = [Vector2(507, 760), Vector2(209, 880), Vector2(812, 880)]
const HORIZONTE = 700.0
# olho do astro (px das texturas 4x da 4.6, a partir do centro do disco)
const ASTRO = {"olho": Vector2(-47.9, -12.0), "u": 342.2, "ux": 479.1, "iris": Vector2(0.0, -13.7),
	"palpebra_y": -383.4, "abre": 263.6, "baixo_y": 394.9, "sobe": 239.6}
const ESCALA_ASTRO = 0.3125      # as texturas do astro saem em 1,25/4 da 4.6
const HUMORES = {
	"calmo": {"topo": 0.30, "baixo": 0.12, "alcance": 0.55, "vel": 5.0, "mira": false, "piscar": Vector2(3.0, 6.0)},
	"feliz": {"topo": 0.08, "baixo": 0.52, "alcance": 0.35, "vel": 6.0, "mira": false, "piscar": Vector2(2.5, 5.0)},
	"radiante": {"topo": 0.10, "baixo": 0.66, "alcance": 0.25, "vel": 7.0, "mira": false, "piscar": Vector2(2.0, 4.0)},
	"atento": {"topo": 0.18, "baixo": 0.24, "alcance": 1.0, "vel": 14.0, "mira": true, "piscar": Vector2(4.5, 8.0)},
	"bravo": {"topo": 0.50, "baixo": 0.28, "alcance": 0.7, "vel": 10.0, "mira": true, "piscar": Vector2(5.0, 9.0)},
	"surpreso": {"topo": 0.04, "baixo": 0.0, "alcance": 0.3, "vel": 18.0, "mira": false, "piscar": Vector2(5.0, 8.0)},
}


class Alvo:
	var no: Node2D
	var spr: Sprite
	var halo: Sprite
	var tipo = "sol"
	var pos = Vector2.ZERO
	var vel = Vector2.ZERO
	var vel_base = 200.0
	var idade = 0.0
	var vida = 3.4
	var entrada = 0.6
	var estilo = "lado"
	var tam = 1.0
	var valor = 50
	var penal = 50
	var troca_em = 0.0
	var trocou = true
	var guinada = 1.0
	var flash = 0.0
	var preso = 0.0
	var l_virou = false
	var saida = "perto"


var modo = MODO_SOL
var tempo_modo = 0.0
var nivel = 1.0
var alvos_lista = []
var spawn_t = 0.0

var _f_sol = {}
var _f_lua = {}
var _fundo_lua: Sprite
var _noite = 0.0
var _astros = {}
var _humor = "calmo"
var _reacao = ""
var _reacao_t = 0.0
var _erros_recentes = 0.0
var _troca_t = -1.0

var carga = 0.0
var _cristal_danos = 0
var _cristal_quebrado = false
var _cristal_volta = 0.0
var _cristal_brilho: Sprite
var _cristal_morto: Sprite
var _trincas = []
var _trincas_no: Node2D
var _feixes_no: Node2D
var _raios_no: Node2D
var _raios = []
var _pontas = [{"danos": 0, "quebrada": false, "volta": 0.0}, {"danos": 0, "quebrada": false, "volta": 0.0}]
var _pontas_brilho = []
var _pontas_mortas = []
var _furos: Node2D
var _poeira: Particulas
var _brilhos = []
var _aguias = []
var _t = 0.0

var _som_tiro_lua: AudioStream
var _som_tiro_sol: AudioStream
var _som_hit_sol: AudioStream
var _som_hit_lua: AudioStream
var _som_trinca: AudioStream
var _som_quebra: AudioStream
var _som_volta: AudioStream
var _som_areia: AudioStream
var _som_pedra: AudioStream
var _som_ouro: AudioStream
var _som_aguia: AudioStream
var _som_aguia_noite: AudioStream


func _configurar() -> void:
	id_fase = "deserto"
	cenario_ranking = "DESERTO"
	cor = Estilo.CORES["deserto"]
	estilo_tiro = "sol"
	forca_coice = 1.0
	musica_path = "res://songs/egito.mp3"
	som_tiro_path = "res://songs/tiro_sol.wav"
	vol_tiro = -4.0
	janela_combo = JANELA
	tempo_recarga = 1.10
	centro_contagem = tela(Vector2(506, 790)).y


func _icones() -> Dictionary:
	return {"sol": quadro(_f_sol, 0), "lua": quadro(_f_lua, 0)}


# ------------------------------------------------------------ cenário
func _montar_cenario() -> void:
	_f_sol = folha("brasao_sol")
	_f_lua = folha("brasao_lua")
	_som_tiro_lua = load("res://songs/tiro_lua.wav")
	_som_tiro_sol = load("res://songs/tiro_sol.wav")
	_som_hit_sol = load("res://songs/hit-sun.wav")
	_som_hit_lua = load("res://songs/hit-moon.wav")
	_som_trinca = load("res://songs/cristal_trinca.wav")
	_som_quebra = load("res://songs/cristal_quebra.wav")
	_som_volta = load("res://songs/cristal_volta.wav")
	_som_areia = load("res://songs/areia_tiro.wav")
	_som_pedra = load("res://songs/pedra_lasca.wav")
	_som_ouro = load("res://songs/ouro_ping.wav")
	_som_aguia = load("res://songs/aguia.wav")
	_som_aguia_noite = load("res://songs/aguia_noite.wav")

	fundo_sprite("fundo_egito_sol")
	_fundo_lua = fundo_sprite("fundo_egito_lua")
	_fundo_lua.modulate.a = 0.0
	_fundo_lua.visible = false

	# o astro: luz em volta, raios girando e o olho vivo
	for a in [MODO_SOL, MODO_LUA]:
		_astros[a] = _criar_astro(a)
	_astros[MODO_LUA]["raiz"].visible = false

	# águias planando no céu
	for i in 2:
		_aguias.append(_criar_aguia(i))

	# furos de bala (areia e pedra)
	_furos = Node2D.new()
	cenario.add_child(_furos)

	# cristal: brilho que respira, feixes de energia, trincas, o quebrado
	_feixes_no = Node2D.new()
	_feixes_no.material = Estilo.material_soma()
	_feixes_no.connect("draw", self, "_desenhar_feixes")
	cenario.add_child(_feixes_no)
	var centro_cristal = tela(Vector2(506, 800))
	_cristal_brilho = luz_sprite("fx_brilho", cenario, centro_cristal, 420.0, Color(1.0, 0.55, 0.9, 0.35))
	_cristal_brilho.scale.y *= 1.8
	_cristal_morto = Sprite.new()
	_cristal_morto.centered = false
	_cristal_morto.texture = Estilo.tex("egito_cristal_morto_sol")
	_cristal_morto.position = tela(CAIXA_MORTO.position)
	_cristal_morto.scale = Vector2.ONE * (CAIXA_MORTO.size.x * K_FUNDO / _cristal_morto.texture.get_width())
	_cristal_morto.visible = false
	cenario.add_child(_cristal_morto)
	_trincas_no = Node2D.new()
	_trincas_no.connect("draw", self, "_desenhar_trincas")
	cenario.add_child(_trincas_no)
	for i in 2:
		var b = luz_sprite("fx_brilho", cenario, tela(PONTAS_OBELISCO[i]), 120.0, Color(1.0, 0.45, 0.8, 0.6))
		_pontas_brilho.append(b)
		var m = Polygon2D.new()
		m.polygon = poligono(POLI_PONTAS[i])
		m.vertex_colors = PoolColorArray([Color(0.30, 0.26, 0.32), Color(0.16, 0.13, 0.17), Color(0.10, 0.08, 0.10),
			Color(0.12, 0.10, 0.12), Color(0.20, 0.17, 0.21)])
		m.modulate.a = 0.0
		cenario.add_child(m)
		_pontas_mortas.append(m)

	# brilhos que piscam nas pontas de ouro e no cristal
	for q in BRILHOS_PONTAS:
		_brilhos.append({"no": luz_sprite("egito_estrela", cenario, tela(q), 70.0, Color(1, 0.95, 0.75, 0.0)), "t": rand_range(0.5, 4.0), "tipo": "ouro"})
	for q in BRILHOS_CRISTAL:
		_brilhos.append({"no": luz_sprite("egito_estrela", cenario, tela(q), 54.0, Color(1, 0.85, 1.0, 0.0)), "t": rand_range(0.5, 3.0), "tipo": "cristal"})

	# raios da descarga do cristal (por cima dos alvos)
	_raios_no = Node2D.new()
	_raios_no.material = Estilo.material_soma()
	_raios_no.connect("draw", self, "_desenhar_raios")
	luz.add_child(_raios_no)

	# poeira dourada no ar (enfeite: some sozinha se a TV Box não segurar)
	_poeira = Particulas.new()
	_poeira.somar = true
	_poeira.add_to_group("efeito_opcional")
	cenario.add_child(_poeira)


func _criar_astro(a: String) -> Dictionary:
	var raiz = Node2D.new()
	raiz.position = tela(CENTRO_ASTRO)
	cenario.add_child(raiz)
	var c = COR_SOL if a == MODO_SOL else COR_LUA
	var halo = luz_sprite("fx_brilho", raiz, Vector2.ZERO, 760.0, Color(c.r, c.g, c.b, 0.55))
	var raios = luz_sprite("fx_raios", raiz, Vector2.ZERO, 720.0, Color(c.r, c.g, c.b, 0.35 if a == MODO_SOL else 0.16))
	raios.add_to_group("efeito_opcional")
	var olho = Node2D.new()
	olho.scale = Vector2.ONE * (Tela.TELA.x / 1080.0)
	raiz.add_child(olho)
	var o: Vector2 = ASTRO["olho"] * ESCALA_ASTRO
	var esclera = _parte(olho, "astro_%s_esclera" % a, o)
	var iris = _parte(olho, "astro_%s_iris" % a, o + ASTRO["iris"] * ESCALA_ASTRO)
	var baixo = _parte(olho, "astro_%s_palpebra_baixo" % a, o + Vector2(0, ASTRO["baixo_y"]) * ESCALA_ASTRO)
	var palp_tex: Texture = Estilo.tex("astro_%s_palpebra" % a)
	var palpebra = _parte(olho, "astro_%s_palpebra" % a, o + Vector2(0, ASTRO["palpebra_y"] * ESCALA_ASTRO + palp_tex.get_height() * 0.5))
	var disco = _parte(olho, "astro_%s_disco" % a, Vector2.ZERO)
	return {"raiz": raiz, "halo": halo, "raios": raios, "iris": iris, "palpebra": palpebra, "baixo": baixo, "disco": disco,
		"iris_0": iris.position, "palpebra_0": palpebra.position, "baixo_0": baixo.position,
		"olhar": Vector2.ZERO, "alvo": Vector2.ZERO, "prox_olhar": 1.0, "piscar_t": rand_range(1.5, 3.5), "fase": -1.0,
		"topo": 0.3, "baixo_v": 0.12, "c": c}


func _parte(pai: Node2D, nome: String, pos: Vector2) -> Sprite:
	var s = Sprite.new()
	s.texture = Estilo.tex(nome)
	s.position = pos
	pai.add_child(s)
	return s


func _criar_aguia(i: int) -> Dictionary:
	var s = Sprite.new()
	s.texture = Estilo.tex("egito_aguia")
	s.hframes = 11
	s.visible = false
	cenario.add_child(s)
	return {"no": s, "espera": 2.0 + i * 5.0, "t": 0.0, "dur": 9.0, "de": Vector2.ZERO, "ate": Vector2.ZERO, "esc": 0.8, "bate": 0.0}


# ------------------------------------------------------------ partida
func _comecar() -> void:
	modo = MODO_SOL
	tempo_modo = 0.0
	spawn_t = 0.0
	_humor = "calmo"
	for i in 3:
		_nascer(modo if i == 0 else _sortear_tipo())


func _extra_placar() -> Array:
	return ["MODO", "SOL" if modo == MODO_SOL else "LUA", COR_SOL if modo == MODO_SOL else COR_LUA]


func _jogo(delta: float) -> void:
	if pontos < 800:
		nivel = 1.0
	else:
		nivel = min(5.2, 1.0 + floor((pontos - 800) / 450.0) * 0.55)
	tempo_modo += delta
	if tempo_modo >= TROCA_MODO:
		tempo_modo = 0.0
		_trocar_modo()
	_spawn(delta)
	_mover_alvos(delta)


func _trocar_modo() -> void:
	var antigo = modo
	modo = MODO_LUA if modo == MODO_SOL else MODO_SOL
	avisos.instrucao("MODO " + modo.to_upper(), (COR_SOL if modo == MODO_SOL else COR_LUA).linear_interpolate(Color.white, 0.3))
	_troca_t = 0.0
	var sai: Node2D = _astros[antigo]["raiz"]
	var entra: Node2D = _astros[modo]["raiz"]
	var base = tela(CENTRO_ASTRO)
	entra.visible = true
	entra.position = base + Vector2(0, 170)
	entra.modulate.a = 0.0
	_fundo_lua.visible = true
	var tw = create_tween().set_parallel(true)
	tw.tween_property(sai, "position", base + Vector2(0, 170), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(sai, "modulate:a", 0.0, 1.4)
	tw.tween_property(entra, "position", base, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(0.5)
	tw.tween_property(entra, "modulate:a", 1.0, 1.4).set_delay(0.5)
	tw.tween_property(_fundo_lua, "modulate:a", 1.0 if modo == MODO_LUA else 0.0, 2.0)
	tw.tween_property(self, "_noite", 1.0 if modo == MODO_LUA else 0.0, 2.0)
	tw.chain().tween_callback(self, "_troca_feita", [sai])
	_cristal_morto.texture = Estilo.tex("egito_cristal_morto_%s" % modo)
	clarao(Color(1.0, 0.85, 0.6, 0.18) if modo == MODO_SOL else Color(0.5, 0.65, 1.0, 0.18), 0.6)


func _troca_feita(sai: Node2D) -> void:
	sai.visible = false
	if modo == MODO_SOL:
		_fundo_lua.visible = false


# ------------------------------------------------------------ brasões
func _max_alvos() -> int:
	var base = 7
	if pontos >= 1500:
		base += 1
	return int(min(11, base + int(floor(nivel - 1.0))))


func _sortear_tipo() -> String:
	var certo = 0.58 if pontos < 1500 else 0.50
	certo = clamp(certo - (nivel - 1.0) * 0.03, 0.40, 0.62)
	if randf() < certo:
		return modo
	return MODO_LUA if modo == MODO_SOL else MODO_SOL


func _spawn(delta: float) -> void:
	if alvos_lista.size() >= _max_alvos():
		return
	spawn_t -= delta
	if spawn_t > 0.0:
		return
	var intervalo = 0.85 * 0.7
	intervalo = max(0.45 * 0.8, intervalo - (nivel - 1.0) * 0.07)
	spawn_t = rand_range(intervalo * 0.65, intervalo * 1.35)
	_nascer(_sortear_tipo())


func _nascer(tipo: String) -> void:
	var a = Alvo.new()
	a.tipo = tipo
	a.no = Node2D.new()
	alvos.add_child(a.no)
	a.halo = luz_sprite("fx_brilho", a.no, Vector2.ZERO, 260.0, Color(1, 1, 1, 0.0))
	a.spr = Sprite.new()
	a.no.add_child(a.spr)
	_aplicar_tipo(a)
	var rapidez = rand_range(215.0, 330.0) * (1.0 + (nivel - 1.0) * 0.15)
	if pontos >= 800:
		rapidez *= 1.10
	a.vel_base = rapidez
	a.tam = rand_range(0.86, 1.16)
	a.saida = "perto" if randf() < 0.5 else "longe"
	var r = randf()
	a.estilo = "lado" if r < 0.45 else ("alto_l" if r < 0.72 else "surge")
	var tela_v = Tela.TELA
	var y_min = 330.0
	var y_max = tela_v.y - 180.0
	match a.estilo:
		"alto_l":
			a.entrada = 0.8
			a.pos = Vector2(rand_range(170.0, tela_v.x - 170.0), y_min - 260.0)
			a.vel = Vector2(rand_range(-0.10, 0.10), 1.0).normalized() * rapidez * 1.3
		"surge":
			# sai de trás do cristal ou de um obelisco crescendo (sem passar por
			# trás de nada: nasce na frente, num clarão)
			a.entrada = 0.55
			var c: Vector2 = tela(SAIDAS_DE_TRAS[randi() % SAIDAS_DE_TRAS.size()])
			a.pos = c
			var lado = sign(c.x - 512.0) if abs(c.x - 512.0) > 40.0 else (1.0 if randf() < 0.5 else -1.0)
			a.vel = Vector2(lado, rand_range(-0.7, -0.15)).normalized() * rapidez
			particulas_luz.explosao(c, {"n": 10, "vel": [60.0, 200.0], "vida": [0.3, 0.6], "tam": [10.0, 22.0],
				"cor": (COR_SOL if tipo == MODO_SOL else COR_LUA).linear_interpolate(Color.white, 0.4), "arrasto": 2.0})
		_:
			a.entrada = 0.6
			match randi() % 3:
				0:
					a.pos = Vector2(-110.0, rand_range(y_min + 60.0, y_max - 60.0))
					a.vel = Vector2(rand_range(230.0, 360.0), rand_range(-120.0, 120.0))
				1:
					a.pos = Vector2(tela_v.x + 110.0, rand_range(y_min + 60.0, y_max - 60.0))
					a.vel = Vector2(-rand_range(230.0, 360.0), rand_range(-120.0, 120.0))
				_:
					a.pos = Vector2(rand_range(160.0, tela_v.x - 160.0), tela_v.y + 110.0)
					a.vel = Vector2(rand_range(-140.0, 140.0), -rand_range(240.0, 380.0))
			a.vel = a.vel.normalized() * rapidez
	a.vida = max(2.4, rand_range(3.0, 3.8) - (nivel - 1.0) * 0.2)
	a.guinada = rand_range(0.5, 1.1)
	a.valor = [20, 50, 80, 100][randi() % 4]
	a.penal = [20, 50, 80, 100][randi() % 4]
	# troca de brasão no meio do voo
	var chance = 0.25 + (nivel - 1.0) * 0.06
	if tipo == modo:
		chance += floor(pontos / 1000.0) * 0.07
		chance += clamp(tempo_modo / TROCA_MODO, 0.0, 1.0) * 0.12
	chance = clamp(chance, 0.0, 0.55)
	if a.vida >= 1.8 and randf() < chance:
		var t_min: float = lerp(0.55, 0.35, chance / 0.55)
		var t_max: float = lerp(0.75, 0.60, chance / 0.55)
		a.troca_em = max(a.vida * rand_range(t_min, t_max), a.entrada + 0.2)
		a.trocou = false
	a.no.position = a.pos
	a.no.scale = Vector2.ZERO
	alvos_lista.append(a)


func _aplicar_tipo(a: Alvo) -> void:
	var f: Dictionary = _f_sol if a.tipo == MODO_SOL else _f_lua
	a.spr.texture = f["tex"]
	a.spr.hframes = f["quadros"]
	a.spr.frame = 0
	var c = COR_SOL if a.tipo == MODO_SOL else COR_LUA
	a.halo.modulate = Color(c.r, c.g, c.b, 0.42)


func _diametro(a: Alvo) -> float:
	var k: float = clamp(a.idade / max(a.vida, 0.01), 0.0, 1.0)
	return lerp(196.0, 128.0, k) * a.tam


func _mover_alvos(delta: float) -> void:
	var tela_v = Tela.TELA
	var i = alvos_lista.size() - 1
	while i >= 0:
		var a: Alvo = alvos_lista[i]
		a.idade += delta
		if a.flash > 0.0:
			a.flash = max(0.0, a.flash - delta)
		if not a.trocou and a.idade >= a.troca_em:
			_trocar_tipo(a)
		if a.idade >= a.vida:
			_remover(i, true)
			i -= 1
			continue
		var entrando = a.idade < a.entrada
		var saindo = a.idade > a.vida - 0.55
		if a.estilo == "alto_l" and not a.l_virou and a.idade >= a.entrada * 0.8:
			a.l_virou = true
			var lado = 1.0 if a.pos.x < 512.0 else -1.0
			a.vel = Vector2(lado, rand_range(-0.18, 0.12)).normalized() * a.vel_base
		if not entrando:
			a.guinada -= delta
			if a.guinada <= 0.0:
				a.guinada = rand_range(0.55, 1.3) / sqrt(nivel)
				a.vel = a.vel.rotated(deg2rad(rand_range(35.0, 85.0)) * (1.0 if randf() < 0.5 else -1.0))
		var raio = _diametro(a) * 0.5
		var lim = Rect2(Vector2(raio, 330.0 + raio * 0.3), Vector2(tela_v.x - raio * 2.0, tela_v.y - 330.0 - raio * 1.3 - 120.0))
		if not entrando and not saindo:
			if a.pos.x < lim.position.x:
				a.pos.x = lim.position.x
				a.vel.x = abs(a.vel.x) + rand_range(20.0, 70.0)
				a.vel.y += rand_range(-60.0, 60.0)
			if a.pos.x > lim.end.x:
				a.pos.x = lim.end.x
				a.vel.x = -(abs(a.vel.x) + rand_range(20.0, 70.0))
				a.vel.y += rand_range(-60.0, 60.0)
			if a.pos.y < lim.position.y:
				a.pos.y = lim.position.y
				a.vel.y = abs(a.vel.y) + rand_range(20.0, 70.0)
				a.vel.x += rand_range(-60.0, 60.0)
			if a.pos.y > lim.end.y:
				a.pos.y = lim.end.y
				a.vel.y = -(abs(a.vel.y) + rand_range(20.0, 70.0))
				a.vel.x += rand_range(-60.0, 60.0)
		var vm = a.vel.length()
		var teto = a.vel_base * (1.35 if entrando else 1.15)
		if vm > teto:
			a.vel *= teto / vm
			vm = teto
		if vm < 140.0:
			a.vel = (Vector2.RIGHT.rotated(rand_range(0.0, TAU)) if vm < 0.01 else a.vel.normalized()) * 140.0
		var canto = not entrando and not saindo and (a.pos.x <= lim.position.x + 8.0 or a.pos.x >= lim.end.x - 8.0) and (a.pos.y <= lim.position.y + 8.0 or a.pos.y >= lim.end.y - 8.0)
		if canto:
			a.preso += delta
			if a.preso >= 0.35:
				a.vel = (lim.position + lim.size * 0.5 - a.pos).normalized() * 308.0
				a.preso = 0.0
		else:
			a.preso = 0.0
		a.pos += a.vel * delta
		# tamanho: entra crescendo (o "surge" vem do nada), sai para perto
		# (cresce e some) ou para longe (encolhe e some)
		var d = _diametro(a)
		var esc = d / f_cel(a)
		var alfa = 1.0
		if entrando:
			var k = a.idade / a.entrada
			esc *= (k if a.estilo == "surge" else lerp(0.7, 1.0, k))
			alfa = clamp(k * 2.0, 0.0, 1.0)
		elif saindo:
			var k = (a.idade - (a.vida - 0.55)) / 0.55
			esc *= (1.0 + 0.35 * k) if a.saida == "perto" else (1.0 - 0.6 * k)
			alfa = 1.0 - k
		a.no.position = a.pos
		a.no.scale = Vector2.ONE * esc
		a.no.modulate = Color(1.0 + a.flash * 3.0, 1.0 + a.flash * 3.0, 1.0 + a.flash * 3.0, alfa)
		a.spr.rotation = sin(a.idade * 2.3 + a.vel_base) * 0.12
		i -= 1
	_separar_alvos()


func f_cel(a: Alvo) -> float:
	return (_f_sol if a.tipo == MODO_SOL else _f_lua)["cel"].x


## Brasões não se sobrepõem: os que se encostam se empurram.
func _separar_alvos() -> void:
	var n = alvos_lista.size()
	for i in n:
		var a: Alvo = alvos_lista[i]
		for j in range(i + 1, n):
			var b: Alvo = alvos_lista[j]
			var d = b.pos - a.pos
			var r = (_diametro(a) + _diametro(b)) * 0.40
			var dist = d.length()
			if dist > 0.01 and dist < r:
				var empurra = d / dist * (r - dist) * 0.5
				a.pos -= empurra
				b.pos += empurra
				var vn = (b.vel - a.vel).dot(d / dist)
				if vn < 0.0:
					a.vel += d / dist * vn * 0.6
					b.vel -= d / dist * vn * 0.6


func _trocar_tipo(a: Alvo) -> void:
	a.trocou = true
	a.tipo = MODO_LUA if a.tipo == MODO_SOL else MODO_SOL
	_aplicar_tipo(a)
	a.flash = 0.45
	a.vida = a.idade + rand_range(1.4, 2.2) + 0.55
	a.vel = a.vel.rotated(rand_range(-PI * 0.25, PI * 0.25))
	particulas_luz.explosao(a.pos, {"n": 8, "vel": [80.0, 220.0], "vida": [0.25, 0.5], "tam": [10.0, 20.0], "cor": Color(1, 1, 1, 0.9), "arrasto": 2.5})


func _remover(i: int, fugiu: bool) -> void:
	var a: Alvo = alvos_lista[i]
	alvos_lista.remove(i)
	a.no.queue_free()


func _alvo_no_ponto(p: Vector2) -> int:
	for i in range(alvos_lista.size() - 1, -1, -1):
		var a: Alvo = alvos_lista[i]
		if a.no.modulate.a < 0.5:
			continue
		var f: Dictionary = _f_sol if a.tipo == MODO_SOL else _f_lua
		if acerta_sprite(a.spr, f["mascara"], f["cel"], p, 1):
			return i
	return -1


# ------------------------------------------------------------ tiro
func _tiro(p: Vector2) -> void:
	_espiar(p)
	var i = _alvo_no_ponto(p)
	if i >= 0:
		_acertou_brasao(i, p)
		return
	var q = imagem(p)
	if Geometry.is_point_in_polygon(q, PoolVector2Array(POLI_CRISTAL)):
		_ferir_cristal(p)
		return
	for k in 2:
		if Geometry.is_point_in_polygon(q, PoolVector2Array(POLI_PONTAS[k])):
			_ferir_ponta(k, p)
			return
	_erros_recentes += 1.0
	errar(p, "ERRO!")
	_reagir("atento", 1.0)
	for o in OURO_PIRAMIDES:
		if Geometry.is_point_in_polygon(q, PoolVector2Array(o)):
			_tocar_ouro(p)
			return
	for pir in PIRAMIDES:
		if Geometry.is_point_in_polygon(q, PoolVector2Array(pir)):
			return   # lá longe: a bala não chega
	if q.y <= HORIZONTE:
		return       # céu
	if q.x < 120.0 or q.x > 904.0 or (q - Vector2(510, 1180)).length() < 300.0:
		_lascar_pedra(p, true)       # colunas da frente e degraus do altar
	elif q.y < 1010.0:
		_lascar_pedra(p, false)      # estátuas e colunas lá atrás: só lasca
	else:
		_furar_areia(p)


func _acertou_brasao(i: int, p: Vector2) -> void:
	var a: Alvo = alvos_lista[i]
	alvos_lista.remove(i)
	var lua = a.tipo == MODO_LUA
	Maquina.efeito(_som_hit_lua if lua else _som_hit_sol, -3.0, rand_range(0.96, 1.05))
	if a.tipo == modo:
		registrar_combo(a.tipo)
		var bonus_combo = combo * 5 if combo >= 3 else 0
		ganhar(a.valor + bonus_combo, a.pos, Color(0.88, 0.94, 1.0) if lua else Color(1.0, 0.84, 0.30), 1.0 + (0.2 if bonus_combo > 0 else 0.0))
		_explodir_brasao(a, p, true)
		_carregar_cristal()
		_reagir("feliz" if combo < 6 else "radiante", 1.2)
	else:
		carga = max(0.0, carga - CARGA_ERRO)
		perder(a.penal, a.pos, "%s -%d" % [a.tipo.to_upper(), a.penal])
		_explodir_brasao(a, p, false)
		clarao(Color(1.0, 0.1, 0.05, 0.16), 0.25)
		_reagir("bravo", 1.6)


## O brasão trinca (os quadros de acerto) e se parte em cacos de ouro ou
## prata; um clarão e faíscas na cor do astro.
func _explodir_brasao(a: Alvo, p: Vector2, certo: bool) -> void:
	var f: Dictionary = _f_sol if a.tipo == MODO_SOL else _f_lua
	var c = COR_SOL if a.tipo == MODO_SOL else COR_LUA
	var cel: Vector2 = f["cel"]
	var xf = a.no.get_transform() * a.spr.get_transform()
	cacos.estourar(f["tex"], Rect2(Vector2(cel.x * 3, 0), cel), xf, p, {"n": 12, "forca": 1.1 if certo else 0.8, "vida": 0.9, "sobe": 200.0})
	particulas_luz.explosao(a.pos, {"n": 18, "vel": [180.0, 520.0], "vida": [0.3, 0.7], "tam": [8.0, 16.0],
		"cor": c.linear_interpolate(Color.white, 0.35) if certo else Color(1.0, 0.3, 0.2), "grav": 300.0, "estica": 0.03, "arrasto": 1.2})
	luz_sprite_breve(a.pos, _diametro(a) * 2.2, Color(c.r, c.g, c.b, 0.8) if certo else Color(1, 0.25, 0.2, 0.7))
	a.no.queue_free()


func _encerrou() -> void:
	for a in alvos_lista:
		var tw = create_tween()
		tw.tween_property(a.no, "modulate:a", 0.0, 0.4)
		tw.tween_callback(a.no, "queue_free")
	alvos_lista.clear()
	_reagir("sono", 99.0)


# ------------------------------------------------------------ cristal
## Cada acerto certo carrega o cristal; cheio e inteiro, ele descarrega.
func _carregar_cristal() -> void:
	carga = min(1.0, carga + CARGA_POR_ACERTO)
	if carga < 1.0 or _cristal_quebrado:
		return
	carga = 0.0
	var pegos = []
	for i in range(alvos_lista.size() - 1, -1, -1):
		var a: Alvo = alvos_lista[i]
		if a.tipo == modo and a.no.modulate.a >= 0.5:
			alvos_lista.remove(i)
			pegos.append(a)
	anuncio.especial("POWER OF RA!")
	clarao(Color(1.0, 0.85, 0.4, 0.28), 0.5)
	tremer(10.0, 0.35)
	var origens = []
	for k in 2:
		if not _pontas[k]["quebrada"]:
			origens.append(tela(PONTAS_OBELISCO[k] - Vector2(0, 30)))
	if origens.empty():
		origens.append(tela(Vector2(506, 640)))
	var soma = 0
	for a in pegos:
		var o: Vector2 = origens[randi() % origens.size()]
		_raios.append({"de": o, "ate": a.pos, "t": 0.0, "pts": _raio_quebrado(o, a.pos)})
		soma += a.valor
		pontos += a.valor
		avisos.pontos(a.pos, "+%d" % a.valor, Color(1.0, 0.9, 0.5), 1.1)
		_explodir_brasao(a, a.pos, true)
	if pegos.empty():
		avisos.instrucao("DESCARGA DO CRISTAL!", Color(1.0, 0.86, 0.36))
	else:
		avisos.instrucao("DESCARGA DO CRISTAL! +%d" % soma, Color(1.0, 0.86, 0.36))
	_raios_no.update()


func _raio_quebrado(de: Vector2, ate: Vector2) -> PoolVector2Array:
	var pts = PoolVector2Array([de])
	var n = 9
	var perp = (ate - de).normalized().rotated(PI * 0.5)
	for i in range(1, n):
		var k = float(i) / n
		pts.append(de.linear_interpolate(ate, k) + perp * rand_range(-36.0, 36.0) * sin(k * PI))
	pts.append(ate)
	return pts


func _desenhar_raios() -> void:
	for r in _raios:
		var a: float = 1.0 - r["t"] / 0.45
		_raios_no.draw_polyline(r["pts"], Color(1.0, 0.75, 0.3, a * 0.6), 14.0)
		_raios_no.draw_polyline(r["pts"], Color(1.0, 0.97, 0.85, a), 4.0)


func _ferir_cristal(p: Vector2) -> void:
	if _cristal_quebrado:
		particulas.explosao(p, {"n": 4, "tex": Estilo.tex("fx_caco"), "vel": [80.0, 180.0], "vida": [0.4, 0.7], "tam": [8.0, 14.0],
			"cor": Color(0.35, 0.35, 0.45), "grav": 900.0, "giro": [-10.0, 10.0]})
		errar(p, "CRISTAL QUEBRADO")
		return
	_cristal_danos += 1
	_reagir("surpreso", 0.8)
	# trinca: 2 a 3 galhos saindo do ponto, presos dentro do cristal
	var poli = poligono(POLI_CRISTAL)
	for g in 2 + randi() % 2:
		var linha = PoolVector2Array([p])
		var ang = randf() * TAU
		for k in 4 + randi() % 4:
			ang += rand_range(-0.6, 0.6)
			var q: Vector2 = linha[linha.size() - 1] + Vector2.RIGHT.rotated(ang) * rand_range(9.0, 21.0)
			if not Geometry.is_point_in_polygon(q, poli):
				break
			linha.append(q)
		if linha.size() > 1:
			_trincas.append(linha)
	while _trincas.size() > 40:
		_trincas.pop_front()
	_trincas_no.update()
	var c = Color(1.0, 0.55, 0.9).linear_interpolate(Color(1.0, 0.25, 0.35), _noite)
	particulas.explosao(p, {"n": 9, "tex": Estilo.tex("fx_caco"), "vel": [140.0, 300.0], "vida": [0.4, 0.8], "tam": [8.0, 16.0],
		"cor": c, "grav": 900.0, "giro": [-12.0, 12.0], "fim": 0.6})
	luz_sprite_breve(p, 150.0, c)
	if _cristal_danos >= TIROS_CRISTAL:
		_quebrar_cristal(p)
	else:
		Maquina.efeito(_som_trinca, -4.0, rand_range(0.92, 1.12))
		avisos.mostrar(p, "CRISTAL %d/%d" % [_cristal_danos, TIROS_CRISTAL], c.linear_interpolate(Color.white, 0.4))


func _quebrar_cristal(p: Vector2) -> void:
	_cristal_quebrado = true
	_cristal_volta = CRISTAL_VOLTA
	carga = 0.0
	_trincas.clear()
	_trincas_no.update()
	# o cristal se parte em cacos da própria pintura do fundo
	# (a região do cristal na imagem 1080x1920 do fundo: 452..560 x 626..968
	# da imagem da 4.6, só o miolo para não levar areia junto)
	var fundo_tex: Texture = Estilo.tex("fundo_egito_lua" if modo == MODO_LUA else "fundo_egito_sol")
	var esc = Tela.TELA.x / 1080.0
	var regiao = Rect2(484.0, 790.0, 96.0, 410.0)
	var centro_px = regiao.position + regiao.size * 0.5
	cacos.estourar(fundo_tex, regiao, Transform2D(Vector2(esc, 0), Vector2(0, esc), centro_px * esc), p,
		{"n": 18, "forca": 1.5, "vida": 1.3, "sobe": 380.0})
	_cristal_morto.visible = true
	_cristal_morto.modulate.a = 1.0
	var c = Color(1.0, 0.6, 0.95).linear_interpolate(Color(1.0, 0.3, 0.4), _noite)
	particulas_luz.explosao(tela(Vector2(506, 790)), {"n": 30, "vel": [200.0, 650.0], "vida": [0.4, 0.9], "tam": [10.0, 22.0],
		"cor": c, "grav": 500.0, "estica": 0.03, "espalha": 60.0})
	luz_sprite_breve(tela(Vector2(506, 790)), 700.0, c, 0.6)
	clarao(Color(1, 1, 1, 0.35), 0.45)
	tremer(12.0, 0.4)
	Maquina.efeito(_som_quebra, -1.0)
	bonus(BONUS_CRISTAL, p, Color(1.0, 0.80, 0.24) if modo == MODO_SOL else Color(0.90, 0.95, 1.0), 1.5)
	avisos.instrucao("CRISTAL QUEBRADO! +%d" % BONUS_CRISTAL, Color(1.0, 0.85, 0.5))


func _ferir_ponta(k: int, p: Vector2) -> void:
	var pt: Dictionary = _pontas[k]
	carga = max(0.0, carga - 0.5)
	if pt["quebrada"]:
		_lascar_pedra(p)
		errar(p, "ERRO!")
		return
	pt["danos"] += 1
	var c = Color(1.0, 0.5, 0.85).linear_interpolate(Color(1.0, 0.3, 0.4), _noite)
	particulas.explosao(p, {"n": 6, "tex": Estilo.tex("fx_caco"), "vel": [120.0, 260.0], "vida": [0.4, 0.7], "tam": [7.0, 12.0],
		"cor": c, "grav": 900.0, "giro": [-12.0, 12.0]})
	luz_sprite_breve(p, 110.0, c)
	if pt["danos"] >= TIROS_PONTA:
		pt["quebrada"] = true
		pt["volta"] = PONTA_VOLTA
		var centro = tela(PONTAS_OBELISCO[k])
		particulas_luz.explosao(centro, {"n": 16, "vel": [150.0, 420.0], "vida": [0.3, 0.7], "tam": [8.0, 16.0], "cor": c, "grav": 600.0, "estica": 0.03})
		particulas.explosao(centro, {"n": 4, "tex": Estilo.tex("fx_fumaca"), "vel": [10.0, 50.0], "ang": [240.0, 300.0], "vida": [1.0, 1.8],
			"tam": [30.0, 50.0], "fim": 2.0, "cor": Color(0.25, 0.2, 0.18, 0.6), "grav": -30.0})
		_pontas_mortas[k].modulate.a = 0.9
		Maquina.efeito(_som_quebra, -6.0, 1.3)
		bonus(BONUS_PONTA, p, Color(1.0, 0.80, 0.24) if modo == MODO_SOL else Color(0.90, 0.95, 1.0), 1.3)
		avisos.instrucao("CRISTAL DO OBELISCO! +%d" % BONUS_PONTA, Color(1.0, 0.85, 0.5))
	else:
		Maquina.efeito(_som_trinca, -6.0, rand_range(1.1, 1.3))


func _desenhar_trincas() -> void:
	for l in _trincas:
		_trincas_no.draw_polyline(l, Color(0.25, 0.05, 0.2, 0.55), 4.0)
		_trincas_no.draw_polyline(l, Color(1.0, 0.92, 1.0, 0.85), 2.0)


## Os quatro feixes do cristal aos obeliscos (luz somada): engrossam e
## correm com a carga; apagam do lado da ponta quebrada e todos com o
## cristal quebrado.
func _desenhar_feixes() -> void:
	if _cristal_quebrado:
		return
	var tex: Texture = Estilo.tex("fx_feixe")
	var e = Maquina.pulso_vivo()
	var c = Color(1.0, 0.62, 0.95).linear_interpolate(Color(1.0, 0.3, 0.45), _noite)
	for i in FEIXES.size():
		if _pontas[i % 2]["quebrada"]:
			continue
		var de = tela(FEIXES[i][0])
		var ate = tela(FEIXES[i][1])
		var v = ate - de
		var larg = 10.0 + 16.0 * carga + 6.0 * e.y
		_feixes_no.draw_set_transform(de, v.angle() - PI * 0.5, Vector2.ONE)
		_feixes_no.draw_texture_rect_region(tex, Rect2(-larg * 0.5, 0.0, larg, v.length()), Rect2(0, 24, 64, 40),
			Color(c.r, c.g, c.b, 0.30 + 0.45 * carga + 0.2 * e.x))
		# o pulso de energia correndo do cristal até a ponta
		var k = fmod(_t * (0.6 + 1.4 * carga) + i * 0.27, 1.0)
		var tam = 26.0 + 30.0 * carga
		_feixes_no.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_feixes_no.draw_texture_rect(Estilo.tex("fx_ponto"), Rect2(de + v * k - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), false, Color(1, 0.9, 1, 0.9))
	_feixes_no.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------ cenário respondendo
func _furar_areia(p: Vector2) -> void:
	_furo(p, "fx_furo_areia", 0.9)
	var c = Color(0.92, 0.72, 0.42).linear_interpolate(Color(0.50, 0.48, 0.56), _noite)
	particulas.explosao(p, {"n": 10, "tex": Estilo.tex("fx_ponto"), "vel": [60.0, 220.0], "ang": [200.0, 340.0], "vida": [0.4, 0.8],
		"tam": [4.0, 8.0], "cor": c, "grav": 700.0, "chao": p.y + 6.0})
	particulas.explosao(p, {"n": 3, "tex": Estilo.tex("fx_nuvem"), "vel": [10.0, 40.0], "ang": [220.0, 320.0], "vida": [0.8, 1.4],
		"tam": [40.0, 60.0], "fim": 2.0, "cor": Color(c.r, c.g, c.b, 0.55), "grav": -20.0})
	Maquina.efeito(_som_areia, -6.0, rand_range(0.9, 1.1))


func _lascar_pedra(p: Vector2, furo: bool = true) -> void:
	if furo:
		_furo(p, "fx_furo_pedra", 0.8)
	var c = Color(0.78, 0.62, 0.42).linear_interpolate(Color(0.42, 0.40, 0.48), _noite)
	particulas.explosao(p, {"n": 8, "tex": Estilo.tex("fx_caco"), "vel": [120.0, 320.0], "vida": [0.4, 0.8], "tam": [6.0, 12.0],
		"cor": c, "grav": 1100.0, "giro": [-14.0, 14.0]})
	particulas.explosao(p, {"n": 2, "tex": Estilo.tex("fx_nuvem"), "vel": [10.0, 30.0], "vida": [0.6, 1.0], "tam": [30.0, 40.0],
		"fim": 1.8, "cor": Color(c.r, c.g, c.b, 0.45)})
	Maquina.efeito(_som_pedra, -7.0, rand_range(0.9, 1.15))


func _tocar_ouro(p: Vector2) -> void:
	var c = Color(1.0, 0.82, 0.35).linear_interpolate(Color(0.85, 0.9, 1.0), _noite)
	particulas_luz.explosao(p, {"n": 16, "vel": [120.0, 340.0], "ang": [180.0, 370.0], "vida": [0.35, 0.7], "tam": [6.0, 12.0],
		"cor": c, "grav": 500.0, "estica": 0.03})
	luz_sprite_breve(p, 120.0, c)
	Maquina.efeito(_som_ouro, -5.0, rand_range(0.94, 1.08))


func _furo(p: Vector2, tex: String, esc: float) -> void:
	var s = Sprite.new()
	s.texture = Estilo.tex(tex)
	s.position = p
	s.scale = Vector2.ONE * esc * rand_range(0.85, 1.15)
	s.rotation = rand_range(-0.4, 0.4)
	_furos.add_child(s)
	if _furos.get_child_count() > 16:
		_furos.get_child(0).queue_free()
	var tw = create_tween()
	tw.tween_interval(8.0)
	tw.tween_property(s, "modulate:a", 0.0, 2.0)
	tw.tween_callback(s, "queue_free")


# ------------------------------------------------------------ vida do cenário
func _sempre(delta: float) -> void:
	_t += delta
	var e = Maquina.pulso_vivo()
	# raios dos descargas
	if not _raios.empty():
		for r in _raios:
			r["t"] += delta
		while not _raios.empty() and _raios[0]["t"] > 0.45:
			_raios.pop_front()
		_raios_no.update()
	# astro: luz respira com a música, raios girando, olho vivo
	for a in [MODO_SOL, MODO_LUA]:
		var d: Dictionary = _astros[a]
		if not d["raiz"].visible:
			continue
		d["raios"].rotation += delta * (0.12 if a == MODO_SOL else 0.05)
		var c: Color = d["c"]
		d["halo"].modulate = Color(c.r, c.g, c.b, 0.42 + 0.22 * e.x + 0.15 * e.y)
		_animar_olho(d, delta)
	# cristal
	if _cristal_quebrado:
		_cristal_volta -= delta
		_cristal_brilho.modulate.a = max(0.0, _cristal_brilho.modulate.a - delta)
		if _cristal_volta <= 0.0:
			_regenerar_cristal()
	else:
		var c = Color(1.0, 0.55, 0.9).linear_interpolate(Color(1.0, 0.25, 0.35), _noite)
		_cristal_brilho.modulate = Color(c.r, c.g, c.b, 0.22 + 0.4 * carga + 0.18 * e.y)
	_feixes_no.update()
	for k in 2:
		var pt: Dictionary = _pontas[k]
		var b: Sprite = _pontas_brilho[k]
		if pt["quebrada"]:
			b.modulate.a = 0.0
			pt["volta"] -= delta
			if pt["volta"] <= 0.0:
				pt["quebrada"] = false
				pt["danos"] = 0
				var tw = create_tween()
				tw.tween_property(_pontas_mortas[k], "modulate:a", 0.0, 0.8)
				particulas_luz.explosao(tela(PONTAS_OBELISCO[k]), {"n": 12, "vel": [40.0, 140.0], "vida": [0.5, 0.9], "tam": [8.0, 14.0],
					"cor": Color(1.0, 0.7, 0.95), "grav": -60.0})
				Maquina.efeito(_som_volta, -8.0, 1.2)
		else:
			b.modulate = Color(1.0, 0.45, 0.8, 0.45 + 0.35 * e.y)
	# brilhos que piscam
	for b in _brilhos:
		b["t"] -= delta
		if b["t"] <= 0.0:
			if b["tipo"] == "cristal" and _cristal_quebrado:
				b["t"] = 1.0
				continue
			b["t"] = rand_range(1.5, 4.5)
			var s: Sprite = b["no"]
			s.rotation = randf() * PI
			var tw2 = create_tween()
			tw2.tween_property(s, "modulate:a", 0.95, 0.15)
			tw2.tween_property(s, "modulate:a", 0.0, 0.45)
	# águias
	for g in _aguias:
		_animar_aguia(g, delta)
	# poeira dourada flutuando
	if randf() < delta * 3.0 * Maquina.fator_efeitos():
		var c2 = Color(1.0, 0.85, 0.55, 0.5).linear_interpolate(Color(0.7, 0.8, 1.0, 0.45), _noite)
		_poeira.soltar(Vector2(rand_range(0, 1024), rand_range(700, 1700)), Vector2(rand_range(-12, 12), rand_range(-20, -5)),
			rand_range(3.0, 5.0), rand_range(4.0, 8.0), 2.0, Color(c2.r, c2.g, c2.b, 0.0), c2, Estilo.tex("fx_ponto"))
	if _reacao_t > 0.0:
		_reacao_t -= delta
		if _reacao_t <= 0.0:
			_reacao = ""
	_erros_recentes = max(0.0, _erros_recentes - delta / 3.5)


func _regenerar_cristal() -> void:
	_cristal_quebrado = false
	_cristal_danos = 0
	var centro = tela(Vector2(506, 797))
	var tw = create_tween()
	tw.tween_property(_cristal_morto, "modulate:a", 0.0, 0.8)
	tw.tween_callback(_cristal_morto, "hide")
	for i in 3:
		particulas_luz.explosao(centro + Vector2(0, -120 + i * 120), {"n": 10, "vel": [30.0, 120.0], "vida": [0.6, 1.0], "tam": [10.0, 20.0],
			"cor": Color(1.0, 0.7, 0.95), "grav": -40.0})
	luz_sprite_breve(centro, 500.0, Color(1.0, 0.7, 0.95, 0.8), 0.8)
	Maquina.efeito(_som_volta, -3.0)
	avisos.instrucao("O CRISTAL VOLTOU!", Color(1.0, 0.8, 0.95))


func _humor_atual() -> String:
	if _reacao != "":
		return _reacao
	if estado == FIM:
		return "calmo"
	if combo >= 6:
		return "radiante"
	if combo >= 3:
		return "feliz"
	if estado == JOGO and (tempo_restante < 15.0 or _erros_recentes > 2.5):
		return "atento"
	return "calmo"


func _reagir(h: String, dur: float) -> void:
	if h == "sono":
		_reacao = "calmo"
		_reacao_t = dur
		return
	_reacao = h
	_reacao_t = dur


var _espiar_p = Vector2.INF
var _espiar_t = 0.0

func _espiar(p: Vector2) -> void:
	_espiar_p = p
	_espiar_t = 0.6


func _olhar_para(d: Dictionary, p: Vector2, alcance: float) -> Vector2:
	var centro: Vector2 = d["raiz"].position
	var dd = p - centro
	return Vector2(clamp(dd.x / 320.0, -1.0, 1.0) * 0.36 * alcance * ASTRO["ux"], clamp(dd.y / 420.0, -1.0, 1.0) * 0.05 * ASTRO["u"]) * ESCALA_ASTRO


func _animar_olho(d: Dictionary, delta: float) -> void:
	var h: Dictionary = HUMORES.get(_humor_atual(), HUMORES["calmo"])
	var u: float = ASTRO["u"] * ESCALA_ASTRO
	_espiar_t = max(0.0, _espiar_t - delta)
	if _espiar_t > 0.0:
		d["alvo"] = _olhar_para(d, _espiar_p, 1.0)
	elif h["mira"]:
		d["alvo"] = _olhar_para(d, MiraGlobal.mira(), h["alcance"])
	else:
		d["prox_olhar"] -= delta
		if d["prox_olhar"] <= 0.0:
			d["prox_olhar"] = rand_range(1.2, 3.0)
			if randf() < 0.3:
				d["alvo"] = _olhar_para(d, MiraGlobal.mira(), h["alcance"])
			else:
				var e: Vector2 = [Vector2(0, 0), Vector2(-0.30, 0.0), Vector2(0.30, 0.0), Vector2(-0.22, -0.04), Vector2(0.22, -0.04), Vector2(0.0, -0.04)][randi() % 6]
				d["alvo"] = Vector2(e.x * h["alcance"] * ASTRO["ux"] * 1.2 * ESCALA_ASTRO, e.y * u)
	d["olhar"] = d["olhar"].linear_interpolate(d["alvo"], 1.0 - exp(-delta * h["vel"]))
	var k = 1.0 - exp(-delta * 7.0)
	d["topo"] = lerp(d["topo"], h["topo"], k)
	d["baixo_v"] = lerp(d["baixo_v"], h["baixo"], k)
	var p = 0.0
	if d["fase"] < 0.0:
		d["piscar_t"] -= delta
		if d["piscar_t"] <= 0.0:
			d["fase"] = 0.0
	else:
		d["fase"] += delta
		var f: float = d["fase"]
		if f < 0.09:
			p = f / 0.09
		elif f < 0.15:
			p = 1.0
		elif f < 0.31:
			p = 1.0 - (f - 0.15) / 0.16
		else:
			d["fase"] = -1.0
			var faixa: Vector2 = h["piscar"]
			d["piscar_t"] = rand_range(faixa.x, faixa.y)
	d["iris"].position = d["iris_0"] + d["olhar"]
	var fecha = p * p * (3.0 - 2.0 * p)
	var topo: float = lerp(d["topo"], 1.0, fecha)
	d["palpebra"].position = d["palpebra_0"] + Vector2(0.0, topo * (ASTRO["abre"] + 0.03 * ASTRO["u"]) * ESCALA_ASTRO)
	d["baixo"].position = d["baixo_0"] - Vector2(0.0, d["baixo_v"] * ASTRO["sobe"] * ESCALA_ASTRO)


## Águia planando no céu entre as colunas, batendo as asas de vez em quando;
## de noite vira silhueta. Grita às vezes.
func _animar_aguia(g: Dictionary, delta: float) -> void:
	var s: Sprite = g["no"]
	if not s.visible:
		g["espera"] -= delta
		if g["espera"] <= 0.0:
			var esq = randf() < 0.5
			var y = rand_range(250.0, 470.0)
			g["de"] = Vector2(-80.0 if esq else 1104.0, y)
			g["ate"] = Vector2(1104.0 if esq else -80.0, y + rand_range(-90.0, 90.0))
			g["dur"] = rand_range(8.0, 12.0)
			g["t"] = 0.0
			g["esc"] = rand_range(0.55, 0.95)
			s.flip_h = not esq
			s.visible = true
			if randf() < 0.6:
				Maquina.efeito(_som_aguia_noite if modo == MODO_LUA else _som_aguia, -14.0, rand_range(0.9, 1.1))
		return
	g["t"] += delta
	var k: float = g["t"] / g["dur"]
	if k >= 1.0:
		s.visible = false
		g["espera"] = rand_range(6.0, 14.0)
		return
	var pos: Vector2 = g["de"].linear_interpolate(g["ate"], k)
	pos.y += sin(k * TAU * 1.5) * 28.0
	s.position = pos
	s.scale = Vector2.ONE * g["esc"]
	g["bate"] = fmod(g["bate"] + delta * 12.0, 40.0)
	var q = int(g["bate"])
	s.frame = (1 + q) if q < 10 else 0
	s.modulate = Color(1, 1, 1, 1).linear_interpolate(Color(0.12, 0.12, 0.2, 0.9), _noite)


func atirar(p: Vector2) -> void:
	# o estampido muda com o astro: raio de sol de dia, de luar de noite
	_som_tiro = _som_tiro_lua if modo == MODO_LUA else _som_tiro_sol
	estilo_tiro = "lua" if modo == MODO_LUA else "sol"
	.atirar(p)


## Teste automático (robô): o brasão certo mais perto da mira.
func robo_alvo():
	var melhor = null
	var md = 1.0e9
	for a in alvos_lista:
		if a.tipo != modo or a.no.modulate.a < 0.6:
			continue
		var d = a.pos.distance_to(MiraGlobal.pos)
		if d < md:
			md = d
			melhor = a.pos
	return melhor
