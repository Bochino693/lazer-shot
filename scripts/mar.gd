extends "res://scripts/fase.gd"

## FUNDO DO MAR (Atlântida), em 2D para a Mali-450.
##
## Água-viva +20, pote +80, baú +100. BOMBA: não atire! A terceira bomba
## acertada encerra a partida. O que cai de cima (pote, baú, bomba) passa
## reto pela tela e, saindo dela, some na hora (nada processa fora de cena).
## De tempos em tempos um CARDUME DOURADO atravessa: cada peixe +40, o
## cardume inteiro +200 ("POSEIDON'S TREASURE!").
## Aos 9 s de partida o NAVIO afunda de cima, de proa, balançando, e pousa lá
## longe atrás do templo (o templo e o poneglifo pequeno são redesenhados
## por cima dele). Tiro no navio solta lascas; tiro nas pedras lasca a pedra;
## tiro no chão levanta areia. Os alvos nadam e caem na frente de tudo.

const SEGUNDO_NAVIO = 9.0
const NAVIO_QUEDA = 4.2
const NAVIO_LONGE = Vector2(380, 768)
const NAVIO_ESCALA = 0.70
const NAVIO_PIVO_LOCAL = Vector2(194, 476)      # pé do casco na imagem do navio
const BONUS_PEIXE = 40
const BONUS_CARDUME = 200
const CHAO = 1565.0                             # chão do mar na tela
const TEMPLO_PORTA = Vector2(439, 724)
const AGUAVIVA_PERIODO = 1.15
const AGUAVIVA_TRANCO = 0.8
const BOMBAS_MAX = 3

const PONTOS = {"aguaviva": 20, "vaso": 80, "bau": 100, "bomba": 0}
const QUEDA = {"aguaviva": 5.7, "vaso": 6.6, "bau": 4.6, "bomba": 5.0}
const ESCALA = {"aguaviva": [1.0, 1.25], "vaso": [0.78, 0.95], "bau": [1.25, 1.45], "bomba": [1.0, 1.2]}


class Obj:
	var no: Node2D
	var spr: Sprite
	var tipo = ""
	var f: Dictionary
	var ini = Vector2.ZERO
	var fim = Vector2.ZERO
	var dur = 5.0
	var t = 0.0
	var esc = 1.0
	var rot0 = 0.0
	var rot1 = 0.0
	var pulsos = 0
	var de_cima = false
	var atingido = false
	var anim_t = 0.0
	var bolha_t = 0.3
	var visto = false       # já entrou na tela


var objs = []
var spawn_t = 0.3
var bombas = 0
var nivel = 0

var _f = {}
var _navio: Sprite
var _furos_navio = []      # os furos de bala no casco (no máximo 14)
var _navio_estado = "esperando"
var _navio_t = 0.0
var _frente: Sprite
var _cardume: Node2D
var _cardume_peixes = []
var _cardume_espera = 12.0
var _cardume_t = 0.0
var _cardume_dur = 7.0
var _cardume_de = Vector2.ZERO
var _cardume_ate = Vector2.ZERO
var _cardume_pegos = 0
var _cardume_pressa = 1.0
var _raios = []
var _porta: Sprite
var _neve: Particulas
var _bolhas: Particulas
var _peixes_fundo: Node2D
var _cardumes_fundo = []
var _baleia: Sprite
var _baleia_t = -1.0
var _baleia_espera = 8.0
var _furos: Node2D
var _t = 0.0
var _mascaras = {}

var _som_aguaviva: AudioStream
var _som_vaso: AudioStream
var _som_bau: AudioStream
var _som_bomba: AudioStream
var _som_ouro: AudioStream
var _som_pedra: AudioStream
var _som_navio_desce: AudioStream
var _som_navio_impacto: AudioStream
var _som_baleia: AudioStream
var _som_madeira: AudioStream


func _configurar() -> void:
	id_fase = "mar"
	cenario_ranking = "MAR"
	cor = Estilo.CORES["mar"]
	estilo_tiro = "mar"
	forca_coice = 0.85
	musica_path = "res://songs/pirate.mp3"
	som_tiro_path = "res://songs/tiro_mar.wav"
	vol_tiro = -3.0
	janela_combo = 1.15
	tempo_recarga = 1.15
	centro_contagem = 900.0


func _icones() -> Dictionary:
	return {"agua": quadro(_f["aguaviva"], 0), "pote": quadro(_f["vaso"], 0), "bau": quadro(_f["bau"], 0), "bomba": quadro(_f["bomba"], 0)}


# ------------------------------------------------------------ cenário
func _montar_cenario() -> void:
	for n in ["aguaviva", "aguaviva_a", "vaso", "bau", "bomba"]:
		_f[n] = folha(n)
	_mascaras = preload("res://scripts/dados_arte.gd").MASCARAS
	_som_aguaviva = load("res://songs/buble_hit.wav")
	_som_vaso = load("res://songs/vaso_hit.wav")
	_som_bau = load("res://songs/bau_hit_corte.wav")
	_som_bomba = load("res://songs/xploit.wav")
	_som_ouro = load("res://songs/ouro_ping.wav")
	_som_pedra = load("res://songs/pedra_lasca.wav")
	_som_navio_desce = load("res://songs/navio_desce.wav")
	_som_navio_impacto = load("res://songs/navio_impacto.wav")
	_som_baleia = load("res://songs/baleia.wav")
	_som_madeira = load("res://songs/madeira_tiro.wav")

	fundo_sprite("fundo_mar")

	# baleia lá longe (de vez em quando, com o canto)
	_baleia = Sprite.new()
	_baleia.texture = Estilo.tex("mar_baleia_1")
	_baleia.visible = false
	_baleia.modulate = Color(0.55, 0.75, 0.95, 0.55)
	cenario.add_child(_baleia)

	# cardumes do fundo (um desenho só)
	_peixes_fundo = Node2D.new()
	_peixes_fundo.add_to_group("efeito_opcional")
	_peixes_fundo.connect("draw", self, "_desenhar_peixes_fundo")
	cenario.add_child(_peixes_fundo)
	for c in [[Vector2(790, 262), Vector2(230, 300), 34.0, 18, 0.15], [Vector2(180, 440), Vector2(620, 330), 27.0, 14, 0.55]]:
		var peixes = []
		for i in c[3]:
			peixes.append(Vector2(rand_range(-60, 60), rand_range(-18, 18)))
		_cardumes_fundo.append({"de": tela(c[0]), "ate": tela(c[1]), "periodo": c[2], "fase": c[4], "peixes": peixes})

	# o navio (aparece aos 9 s) e a frente do templo por cima dele
	_navio = Sprite.new()
	_navio.texture = Estilo.tex("mar_navio")
	_navio.centered = false
	_navio.offset = -NAVIO_PIVO_LOCAL
	_navio.visible = false
	cenario.add_child(_navio)
	_frente = Sprite.new()
	_frente.texture = Estilo.tex("mar_frente")
	_frente.centered = false
	_frente.position = preload("res://scripts/dados_arte.gd").MAR_FRENTE * (Tela.TELA.x / 1080.0)
	_frente.scale = Vector2.ONE * (Tela.TELA.x / 1080.0)
	cenario.add_child(_frente)

	# luz da porta do templo, respirando com a música
	_porta = luz_sprite("fx_brilho", cenario, tela(TEMPLO_PORTA), 260.0, Color(0.4, 0.95, 1.0, 0.45))

	# furos e marcas no chão
	_furos = Node2D.new()
	cenario.add_child(_furos)

	# fachos de luz do sol de fora, balançando (luz somada)
	for i in 4:
		var s = Sprite.new()
		s.texture = Estilo.tex("fx_feixe")
		s.material = Estilo.material_soma()
		s.centered = false
		s.offset = Vector2(-32, 0)
		s.position = Vector2(120 + i * 260 + rand_range(-40, 40), -40)
		s.scale = Vector2(rand_range(2.2, 3.4), rand_range(4.2, 5.6))
		s.modulate = Color(0.55, 0.9, 1.0, 0.0)
		s.add_to_group("efeito_opcional")
		cenario.add_child(s)
		_raios.append({"no": s, "fase": randf() * TAU, "vel": rand_range(0.25, 0.45), "rot": rand_range(-0.28, -0.08)})

	# neve marinha e bolhas
	_neve = Particulas.new()
	_neve.somar = true
	_neve.add_to_group("efeito_opcional")
	cenario.add_child(_neve)
	_bolhas = Particulas.new()
	cenario.add_child(_bolhas)

	# o cardume dourado (bônus) fica por cima dos alvos
	_cardume = Node2D.new()
	_cardume.visible = false
	alvos.add_child(_cardume)
	for i in 9:
		var s = Sprite.new()
		s.texture = Estilo.tex("mar_peixe_dourado")
		_cardume.add_child(s)
		var fila = int(floor(sqrt(float(i)) + 0.0001))
		_cardume_peixes.append({"no": s, "off": Vector2(-fila * 70.0 + rand_range(-14, 14), (i - fila * fila - fila) * 46.0 + rand_range(-10, 10)),
			"fase": randf() * TAU, "pego": -1.0, "fuga": Vector2.ZERO, "giro": 0.0})


# ------------------------------------------------------------ partida
func _comecar() -> void:
	spawn_t = 0.2
	_cardume_espera = rand_range(10.0, 14.0)
	for i in 2:
		_spawnar("aguaviva")
	_spawnar("bau")


func _extra_placar() -> Array:
	var restantes = int(max(0, BOMBAS_MAX - bombas))
	var c = Color(0.55, 1.0, 0.6) if restantes == 3 else (Color(1.0, 0.8, 0.3) if restantes == 2 else Color(1.0, 0.3, 0.25))
	return ["BOMBAS", "%d/%d" % [restantes, BOMBAS_MAX], c]


func _jogo(delta: float) -> void:
	var n = int(floor(max(pontos, 0) / 3000.0))
	if n != nivel:
		nivel = n
		if nivel > 0:
			avisos.instrucao("NÍVEL %d" % (nivel + 1), Color(0.6, 0.95, 1.0))
	if _navio_estado == "esperando" and tempo_jogo >= SEGUNDO_NAVIO:
		_cair_navio()
	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = rand_range(0.18, 0.42)
		_tentar_spawn()
	_cardume_tick(delta)


func _contar(tipo: String) -> int:
	var n = 0
	for o in objs:
		if o.tipo == tipo and not o.atingido:
			n += 1
	return n


func _tentar_spawn() -> void:
	if _contar("aguaviva") < 6 and randf() <= 0.81 * 0.5:
		_spawnar("aguaviva")
	if _contar("vaso") < 3 and randf() < 0.42 * 0.5:
		_spawnar("vaso")
	if _contar("bau") < 2 and randf() < 0.28:
		_spawnar("bau")
	var chance = 0.39 + (0.10 if pontos < 1500 else 0.0) + nivel * 0.06 + (0.10 if nivel >= 1 else 0.0)
	chance = min(0.9, chance)
	var bombas_vivas = _contar("bomba")
	for i in 1 + nivel:
		if bombas_vivas >= 6 + nivel * 2:
			break
		if randf() < chance:
			_spawnar("bomba")
			bombas_vivas += 1


func _raio(tipo: String, esc: float) -> float:
	var f: Dictionary = _f["aguaviva" if tipo == "aguaviva" else tipo]
	var cel: Vector2 = f["cel"]
	return max(cel.x, cel.y) * esc * 0.42


func _conflita(p: Vector2, r: float) -> bool:
	for o in objs:
		if o.atingido:
			continue
		var r2 = _raio(o.tipo, o.esc)
		if o.no.position.distance_to(p) < r + r2:
			return true
	return false


func _spawnar(tipo: String) -> void:
	var o = Obj.new()
	o.tipo = tipo
	var variante = tipo
	if tipo == "aguaviva" and randf() < 0.5:
		variante = "aguaviva_a"
	o.f = _f[variante]
	var faixa: Array = ESCALA[tipo]
	o.esc = rand_range(faixa[0], faixa[1]) * rand_range(0.88, 1.12)
	if tipo == "bomba":
		o.esc += nivel * 0.07
	# a folha nítida é maior que a de antes: a mesma figura na tela
	o.esc /= float(o.f.get("fator", 1.0))
	var mult = 1.0 + nivel * 0.07
	o.dur = QUEDA[tipo] / mult
	var tela_v = Tela.TELA
	var fora = 150.0
	var r = _raio(tipo, o.esc)
	var achou = false
	for tentativa in 16:
		var ini = Vector2.ZERO
		var fim = Vector2.ZERO
		match tipo:
			"aguaviva":
				match randi() % 3:
					0:
						var x = rand_range(110.0, tela_v.x - 110.0)
						ini = Vector2(x, tela_v.y + fora)
						fim = Vector2(x + rand_range(-120, 120), -fora)
					1:
						var x2 = rand_range(110.0, tela_v.x - 110.0)
						ini = Vector2(x2, tela_v.y + fora)
						fim = Vector2(x2 + rand_range(-60, 60), -fora)
					_:
						var y = rand_range(380.0, tela_v.y - 300.0)
						if randf() < 0.5:
							ini = Vector2(-fora, y)
							fim = Vector2(tela_v.x + fora, y - rand_range(60.0, 260.0))
						else:
							ini = Vector2(tela_v.x + fora, y)
							fim = Vector2(-fora, y - rand_range(60.0, 260.0))
			"bomba":
				match randi() % 4:
					0:
						ini = Vector2(rand_range(70.0, tela_v.x - 70.0), -fora)
						fim = Vector2(rand_range(70.0, tela_v.x - 70.0), tela_v.y + fora)
					1:
						ini = Vector2(rand_range(70.0, tela_v.x - 70.0), tela_v.y + fora)
						fim = Vector2(rand_range(70.0, tela_v.x - 70.0), -fora)
					2:
						ini = Vector2(-fora, rand_range(260.0, tela_v.y - 160.0))
						fim = Vector2(tela_v.x + fora, rand_range(260.0, tela_v.y - 160.0))
					_:
						ini = Vector2(tela_v.x + fora, rand_range(260.0, tela_v.y - 160.0))
						fim = Vector2(-fora, rand_range(260.0, tela_v.y - 160.0))
			_:
				var x3 = rand_range(90.0, tela_v.x - 90.0)
				ini = Vector2(x3, -fora)
				fim = Vector2(x3 + rand_range(-60, 60), tela_v.y + fora)
		var livre = true
		for k in [0.2, 0.35, 0.5, 0.65]:
			if _conflita(ini.linear_interpolate(fim, k), r):
				livre = false
				break
		if livre:
			o.ini = ini
			o.fim = fim
			achou = true
			break
	if not achou:
		return
	# o que cai de cima passa reto pela tela e some lá embaixo (sem bater
	# no chão: nada fica processando fora de cena)
	if tipo != "aguaviva" and o.ini.y < 0.0 and o.fim.y > tela_v.y:
		o.de_cima = true
	if tipo == "aguaviva":
		o.pulsos = int(max(2, round(o.dur / AGUAVIVA_PERIODO)))
		o.rot0 = rand_range(-8.0, 8.0)
		o.rot1 = o.rot0
	elif tipo == "bomba":
		o.rot0 = rand_range(-180.0, 180.0)
		o.rot1 = o.rot0 + rand_range(320.0, 560.0) * (1.0 if randf() < 0.5 else -1.0)
	else:
		o.rot0 = rand_range(-6.0, 6.0)
		o.rot1 = rand_range(-14.0, 14.0)
	o.no = Node2D.new()
	o.no.position = o.ini
	alvos.add_child(o.no)
	if tipo == "bau" or tipo == "vaso":
		luz_sprite("fx_brilho", o.no, Vector2.ZERO, 230.0, Color(1.0, 0.85, 0.4, 0.22))
	elif tipo == "aguaviva":
		luz_sprite("fx_brilho", o.no, Vector2.ZERO, 200.0, Color(0.8, 0.4, 1.0, 0.25) if variante == "aguaviva" else Color(1.0, 0.3, 0.55, 0.25))
	o.spr = Sprite.new()
	o.spr.texture = o.f["tex"]
	o.spr.hframes = o.f["quadros"]
	o.spr.frame = 0
	o.no.add_child(o.spr)
	o.no.scale = Vector2.ONE * o.esc
	o.anim_t = randf() * 4.0
	objs.append(o)


func _mover(delta: float) -> void:
	var i = objs.size() - 1
	while i >= 0:
		var o: Obj = objs[i]
		if o.atingido:
			i -= 1
			continue
		o.t += delta / max(o.dur, 0.1)
		if o.t >= 1.0:
			o.no.queue_free()
			objs.remove(i)
			i -= 1
			continue
		var k = o.t
		if o.tipo == "aguaviva":
			# nada em pulsos: o sino empurra e desliza
			k = o.t + AGUAVIVA_TRANCO * sin(TAU * o.pulsos * o.t) / (TAU * o.pulsos)
			var fase = fmod(o.t * o.pulsos, 1.0)
			o.no.scale = Vector2(o.esc * (1.0 + 0.06 * sin(fase * TAU)), o.esc * (1.0 - 0.06 * sin(fase * TAU)))
		elif o.de_cima:
			k = o.t * o.t * (3.0 - 2.0 * o.t) * 0.35 + o.t * o.t * 0.65
		o.no.position = o.ini.linear_interpolate(o.fim, k)
		# o que já passou pela tela e saiu some na hora (nada processa fora
		# de cena)
		var meio: float = max(o.f["cel"].x, o.f["cel"].y) * o.esc * 0.6
		var p_o: Vector2 = o.no.position
		var dentro = p_o.x > -meio and p_o.x < Tela.TELA.x + meio and p_o.y > -meio and p_o.y < Tela.TELA.y + meio
		if dentro:
			o.visto = true
		elif o.visto:
			o.no.queue_free()
			objs.remove(i)
			i -= 1
			continue
		o.no.rotation_degrees = lerp(o.rot0, o.rot1, o.t)
		o.anim_t += delta
		var parado: Array = o.f["parado"]
		o.spr.frame = parado[int(o.anim_t * 6.0) % parado.size()]
		o.bolha_t -= delta
		if o.bolha_t <= 0.0:
			o.bolha_t = rand_range(0.14, 0.34)
			_bolhas.explosao(o.no.position + Vector2(rand_range(-20, 20), -10), {"n": 1 + randi() % 2, "tex": Estilo.tex("mar_bolha"),
				"vel": [10.0, 40.0], "ang": [240.0, 300.0], "vida": [0.8, 1.4], "tam": [6.0, 14.0], "fim": 1.0,
				"cor": Color(0.85, 0.97, 1.0, 0.7), "grav": -120.0, "arrasto": 1.0})
		i -= 1


# ------------------------------------------------------------ tiro
func _alvo_no_ponto(p: Vector2) -> int:
	for i in range(objs.size() - 1, -1, -1):
		var o: Obj = objs[i]
		if o.atingido:
			continue
		if acerta_sprite(o.spr, o.f["mascara"], o.f["cel"], p, 1):
			return i
	return -1


func _tiro(p: Vector2) -> void:
	var i = _alvo_no_ponto(p)
	if i >= 0:
		_acertar(objs[i], p)
		return
	if _acertar_cardume(p):
		return
	if _navio.visible and _na_mascara("navio", p):
		_lascar_navio(p)
		errar(p, "MADEIRA!")
		return
	if _na_mascara("pedra_dir", p) or _na_mascara("pedra_esq", p):
		_lascar_pedra(p)
		errar(p, "PEDRA!")
		return
	if p.y > CHAO - 120.0:
		_furar_chao(p)
	errar(p, "SPLASH!")


func _na_mascara(nome: String, p: Vector2) -> bool:
	var m: Dictionary = _mascaras[nome]
	var local: Vector2
	var tam = Vector2(m["tam"][0], m["tam"][1])
	if nome == "navio":
		local = _navio.get_global_transform().affine_inverse().xform(p) + NAVIO_PIVO_LOCAL
	else:
		local = imagem(p) - Vector2(m["canto"][0], m["canto"][1])
	if local.x < 0 or local.y < 0 or local.x >= tam.x or local.y >= tam.y:
		return false
	var grade: Array = m["grade"]
	var x = int(local.x / tam.x * grade[0].length())
	var y = int(local.y / tam.y * grade.size())
	return grade[y][x] == "1"


func _acertar(o: Obj, p: Vector2) -> void:
	o.atingido = true
	objs.erase(o)
	if o.tipo == "bomba":
		_explodir_bomba(o, p)
		return
	var pts: int = PONTOS[o.tipo]
	registrar_combo()
	ganhar(pts, o.no.position, OURO, 1.0 + (0.15 if pts >= 80 else 0.0))
	match o.tipo:
		"aguaviva":
			Maquina.efeito(_som_aguaviva, -1.0, rand_range(0.98, 1.05))
			clarao(Color(0.36, 0.88, 1.0, 0.14), 0.2)
			tremer(2.0, 0.12)
			var c = Color(0.85, 0.5, 1.0) if o.f == _f["aguaviva"] else Color(1.0, 0.45, 0.65)
			particulas_luz.explosao(o.no.position, {"n": 26, "vel": [60.0, 260.0], "vida": [0.5, 1.0], "tam": [8.0, 18.0], "cor": c,
				"grav": -80.0, "arrasto": 2.0, "espalha": 30.0})
			_bolhas.explosao(o.no.position, {"n": 8, "tex": Estilo.tex("mar_bolha"), "vel": [40.0, 160.0], "ang": [200.0, 340.0], "vida": [0.6, 1.2],
				"tam": [8.0, 18.0], "fim": 1.0, "cor": Color(0.9, 0.97, 1.0, 0.8), "grav": -260.0, "arrasto": 1.2})
		"vaso":
			Maquina.efeito(_som_vaso, -0.8, rand_range(0.99, 1.02))
			clarao(Color(1.0, 0.95, 0.70, 0.12), 0.2)
			tremer(3.5, 0.12)
			var xf = o.no.get_transform() * o.spr.get_transform()
			cacos.estourar(o.f["tex"], Rect2(Vector2.ZERO, o.f["cel"]), xf, p, {"n": 12, "forca": 1.0, "vida": 1.0})
			_cavalo(o.no.position)
		"bau":
			Maquina.efeito(_som_bau, -0.2, rand_range(1.0, 1.02))
			clarao(Color(1.0, 0.95, 0.70, 0.12), 0.2)
			tremer(3.5, 0.12)
			particulas_luz.explosao(o.no.position, {"n": 24, "vel": [180.0, 460.0], "ang": [200.0, 340.0], "vida": [0.5, 0.9], "tam": [8.0, 14.0],
				"cor": Color(1.0, 0.82, 0.3), "grav": 900.0, "estica": 0.02})
			particulas.explosao(o.no.position, {"n": 14, "tex": Estilo.tex("fx_ponto"), "vel": [120.0, 380.0], "ang": [200.0, 340.0], "vida": [0.8, 1.3],
				"tam": [10.0, 16.0], "fim": 1.0, "cor": Color(1.0, 0.78, 0.2), "grav": 1100.0, "giro": [-10.0, 10.0]})
	# a animação de acerto da folha (estoura, abre, desfaz) e some
	_animar_acerto(o, 9.0)


func _animar_acerto(o: Obj, fps: float) -> void:
	var quadros: Array = o.f["acerto"]
	var tw = create_tween()
	for q in quadros:
		tw.tween_callback(o.spr, "set_frame", [q])
		tw.tween_interval(1.0 / fps)
	tw.tween_property(o.no, "modulate:a", 0.0, 0.2)
	tw.tween_callback(o.no, "queue_free")


## O cavalo-marinho espírito sobe do pote e se desfaz em luz.
func _cavalo(p: Vector2) -> void:
	var s = luz_sprite("fx_brilho", efeitos, p, 10.0, Color(1, 1, 1, 0))
	s.texture = Estilo.tex("mar_cavalo")
	s.scale = Vector2.ONE * 0.8
	s.modulate = Color(0.5, 1.0, 0.95, 0.0)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(s, "position", p + Vector2(0, -170), 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.95, 0.3)
	tw.tween_property(s, "modulate:a", 0.0, 0.6).set_delay(0.7)
	tw.chain().tween_callback(s, "queue_free")


func _explodir_bomba(o: Obj, p: Vector2) -> void:
	bombas += 1
	quebrar_combo()
	acertos += 1
	Maquina.efeito(_som_bomba, -0.1, rand_range(0.97, 1.0))
	clarao(Color(1.0, 0.45, 0.2, 0.22), 0.35)
	tremer(13.0, 0.35)
	var c = o.no.position
	luz_sprite_breve(c, 520.0, Color(1.0, 0.6, 0.25, 0.95), 0.45)
	for k in 2:
		var anel = luz_sprite("fx_anel", luz, c, 80.0, Color(1.0, 0.75, 0.45, 0.9))
		var tw = create_tween().set_parallel(true)
		tw.tween_property(anel, "scale", anel.scale * (7.0 + k * 3.0), 0.5 + k * 0.15).set_ease(Tween.EASE_OUT)
		tw.tween_property(anel, "modulate:a", 0.0, 0.5 + k * 0.15)
		tw.chain().tween_callback(anel, "queue_free")
	particulas_luz.explosao(c, {"n": 30, "vel": [250.0, 700.0], "vida": [0.3, 0.7], "tam": [8.0, 16.0], "cor": Color(1.0, 0.7, 0.3),
		"grav": 300.0, "estica": 0.03, "arrasto": 1.0})
	particulas.explosao(c, {"n": 7, "tex": Estilo.tex("fx_fumaca"), "vel": [30.0, 120.0], "vida": [1.0, 1.8], "tam": [60.0, 100.0],
		"fim": 2.2, "cor": Color(0.15, 0.13, 0.14, 0.7), "grav": -40.0, "arrasto": 1.0})
	particulas.explosao(c, {"n": 12, "tex": Estilo.tex("fx_caco"), "vel": [200.0, 520.0], "vida": [0.6, 1.1], "tam": [8.0, 16.0],
		"cor": Color(0.12, 0.12, 0.14), "grav": 900.0, "giro": [-14.0, 14.0]})
	_bolhas.explosao(c, {"n": 14, "tex": Estilo.tex("mar_bolha"), "vel": [80.0, 260.0], "vida": [0.8, 1.5], "tam": [10.0, 26.0], "fim": 1.0,
		"cor": Color(0.9, 0.97, 1.0, 0.85), "grav": -300.0, "arrasto": 1.0})
	_animar_acerto(o, 16.0)
	var restam = int(max(0, BOMBAS_MAX - bombas))
	if bombas >= BOMBAS_MAX:
		faixa("3 BOMBAS!", Color(1.0, 0.35, 0.25), 1.4)
		encerrar("PARTIDA ENCERRADA")
	else:
		avisos.instrucao("NÃO ACERTE BOMBAS! RESTAM %d CHANCES" % restam, Color(1.0, 0.5, 0.4))


func _lascar_pedra(p: Vector2) -> void:
	particulas.explosao(p, {"n": 8, "tex": Estilo.tex("fx_caco"), "vel": [120.0, 300.0], "vida": [0.5, 0.9], "tam": [6.0, 12.0],
		"cor": Color(0.35, 0.45, 0.52), "grav": 700.0, "giro": [-12.0, 12.0], "arrasto": 1.5})
	particulas.explosao(p, {"n": 2, "tex": Estilo.tex("fx_nuvem"), "vel": [10.0, 30.0], "vida": [0.8, 1.2], "tam": [36.0, 50.0], "fim": 1.8,
		"cor": Color(0.55, 0.7, 0.78, 0.4)})
	particulas_luz.explosao(p, {"n": 5, "vel": [60.0, 160.0], "vida": [0.3, 0.6], "tam": [6.0, 10.0], "cor": Color(0.4, 0.95, 1.0)})
	_furo(p, "fx_furo_pedra", 0.7, Color(0.8, 0.9, 1.0, 0.9))
	Maquina.efeito(_som_pedra, -7.0, rand_range(0.9, 1.15))


func _lascar_navio(p: Vector2) -> void:
	particulas.explosao(p, {"n": 9, "tex": Estilo.tex("mar_farpa"), "vel": [120.0, 320.0], "vida": [0.6, 1.0], "tam": [20.0, 34.0],
		"cor": Color(0.62, 0.48, 0.32), "grav": 500.0, "giro": [-14.0, 14.0], "arrasto": 1.5})
	_bolhas.explosao(p, {"n": 5, "tex": Estilo.tex("mar_bolha"), "vel": [30.0, 90.0], "ang": [230.0, 310.0], "vida": [0.6, 1.0], "tam": [8.0, 14.0],
		"fim": 1.0, "cor": Color(0.9, 0.97, 1.0, 0.8), "grav": -200.0})
	# o furo fica no casco (anda e afunda com o navio); são no máximo 14, o
	# mais velho é reaproveitado: tiro atrás de tiro no navio não acumula nó
	var furo: Sprite
	if _furos_navio.size() >= 14:
		furo = _furos_navio.pop_front()
		_navio.move_child(furo, _navio.get_child_count() - 1)
	else:
		furo = Sprite.new()
		furo.texture = Estilo.tex("bar_furo_madeira")
		furo.scale = Vector2.ONE * 0.5
		_navio.add_child(furo)
	_furos_navio.append(furo)
	furo.position = _navio.get_global_transform().affine_inverse().xform(p)
	furo.rotation = randf() * TAU
	Maquina.efeito(_som_madeira, -6.0, rand_range(0.9, 1.1))


func _furar_chao(p: Vector2) -> void:
	_furo(p, "fx_furo_areia", 0.8, Color(0.75, 0.85, 0.95, 0.9))
	particulas.explosao(p, {"n": 3, "tex": Estilo.tex("fx_nuvem"), "vel": [10.0, 40.0], "ang": [220.0, 320.0], "vida": [0.9, 1.5],
		"tam": [44.0, 64.0], "fim": 2.0, "cor": Color(0.62, 0.78, 0.82, 0.5), "grav": -20.0})


func _furo(p: Vector2, tex: String, esc: float, c: Color) -> void:
	var s = Sprite.new()
	s.texture = Estilo.tex(tex)
	s.position = p
	s.scale = Vector2.ONE * esc * rand_range(0.85, 1.15)
	s.rotation = rand_range(-0.4, 0.4)
	s.modulate = c
	_furos.add_child(s)
	if _furos.get_child_count() > 16:
		_furos.get_child(0).queue_free()
	var tw = create_tween()
	tw.tween_interval(8.0)
	tw.tween_property(s, "modulate:a", 0.0, 2.0)
	tw.tween_callback(s, "queue_free")


func _encerrou() -> void:
	for o in objs:
		var tw = create_tween()
		tw.tween_property(o.no, "modulate:a", 0.0, 0.4)
		tw.tween_callback(o.no, "queue_free")
	objs.clear()
	_cardume.visible = false


# ------------------------------------------------------------ cardume dourado
func _cardume_tick(delta: float) -> void:
	if not _cardume.visible:
		_cardume_espera -= delta
		if _cardume_espera <= 0.0:
			_soltar_cardume()
		return
	_cardume_t += delta * _cardume_pressa
	var k = _cardume_t / _cardume_dur
	if k >= 1.0:
		_cardume.visible = false
		_cardume_espera = rand_range(14.0, 22.0)
		return
	var centro = _cardume_de.linear_interpolate(_cardume_ate, k)
	centro.y += sin(k * TAU * 1.2) * 40.0
	var dir = sign(_cardume_ate.x - _cardume_de.x)
	for p in _cardume_peixes:
		var s: Sprite = p["no"]
		if not s.visible:
			continue
		var off: Vector2 = p["off"] * 1.6
		off.x *= dir
		off += Vector2(sin(_cardume_t * 1.7 + p["fase"]) * 10.0, sin(_cardume_t * 2.3 + p["fase"] * 1.3) * 8.0)
		if p["pego"] >= 0.0:
			p["pego"] += delta
			off += p["fuga"] * p["pego"]
			s.rotation += p["giro"] * delta
			s.modulate.a = max(0.0, 1.0 - p["pego"] * 1.6)
			if s.modulate.a <= 0.0:
				s.visible = false
		s.position = centro + off
		s.flip_h = dir < 0.0
		s.scale = Vector2.ONE * (0.9 + 0.08 * sin(_cardume_t * 9.0 + p["fase"]))
	if randf() < delta * 10.0:
		particulas_luz.explosao(centro, {"n": 1, "vel": [10.0, 30.0], "vida": [0.5, 0.8], "tam": [8.0, 14.0], "cor": Color(1.0, 0.85, 0.4), "espalha": 80.0})


func _soltar_cardume() -> void:
	var direita = randf() < 0.5
	var y = rand_range(0.36, 0.62) * Tela.TELA.y
	_cardume_de = Vector2(-260.0 if direita else Tela.TELA.x + 260.0, y)
	_cardume_ate = Vector2(Tela.TELA.x + 260.0 if direita else -260.0, y + rand_range(-160.0, 160.0))
	_cardume_dur = rand_range(6.0, 7.5)
	_cardume_t = 0.0
	_cardume_pegos = 0
	_cardume_pressa = 1.0
	for p in _cardume_peixes:
		p["pego"] = -1.0
		p["no"].visible = true
		p["no"].modulate = Color.white
		p["no"].rotation = 0.0
	_cardume.visible = true
	Maquina.efeito(_som_ouro, -14.0, 1.6)


func _acertar_cardume(p: Vector2) -> bool:
	if not _cardume.visible:
		return false
	for f in _cardume_peixes:
		var s: Sprite = f["no"]
		if not s.visible or f["pego"] >= 0.0:
			continue
		if s.position.distance_to(p) < 46.0:
			f["pego"] = 0.0
			f["fuga"] = Vector2(rand_range(-120, 120), rand_range(-260, -120))
			f["giro"] = rand_range(-12.0, 12.0)
			_cardume_pegos += 1
			_cardume_pressa = 1.6
			var todos = _cardume_pegos >= _cardume_peixes.size()
			var pts = BONUS_PEIXE + (BONUS_CARDUME if todos else 0)
			registrar_combo()
			bonus(pts, s.position, Color(1.0, 0.86, 0.45), 1.25 if todos else 1.0)
			Maquina.efeito(_som_ouro, -3.0, 1.0 + 0.06 * _cardume_pegos)
			particulas_luz.explosao(s.position, {"n": 14, "vel": [100.0, 300.0], "vida": [0.3, 0.6], "tam": [8.0, 14.0], "cor": Color(1.0, 0.85, 0.35),
				"estica": 0.03, "arrasto": 2.0})
			if _cardume_pegos == 1:
				avisos.instrucao("PEIXES DOURADOS! +%d CADA" % BONUS_PEIXE, Color(1.0, 0.86, 0.45))
			if todos:
				anuncio.especial("POSEIDON'S TREASURE!")
				avisos.instrucao("CARDUME INTEIRO! +%d" % BONUS_CARDUME, Color(1.0, 0.86, 0.45))
				clarao(Color(1.0, 0.85, 0.40, 0.16), 0.3)
				Maquina.efeito(_som_bau, -6.0, 1.25)
			return true
	return false


# ------------------------------------------------------------ navio
func _cair_navio() -> void:
	_navio_estado = "caindo"
	_navio_t = 0.0
	_navio.visible = true
	Maquina.efeito(_som_navio_desce, -4.0)


func _navio_tick(delta: float) -> void:
	if _navio_estado != "caindo":
		return
	_navio_t += delta
	var k: float = clamp(_navio_t / NAVIO_QUEDA, 0.0, 1.0)
	# a água segura: desce rápido no começo e freia perto do fundo
	var desce = 1.0 - pow(1.0 - k, 2.2)
	var destino = tela(NAVIO_LONGE)
	_navio.position = Vector2(destino.x - 60.0 * (1.0 - k), lerp(-260.0, destino.y, desce))
	_navio.scale = Vector2.ONE * lerp(1.15, NAVIO_ESCALA * K_FUNDO, desce)
	_navio.rotation = deg2rad(lerp(-22.0, -3.0, desce) + sin(_navio_t * 2.4) * 7.0 * (1.0 - k))
	var nevoa = Color(1, 1, 1).linear_interpolate(Color(0.62, 0.78, 0.92), desce)
	_navio.modulate = nevoa
	if randf() < delta * 14.0:
		var q = _navio.get_global_transform().xform(Vector2(rand_range(-170, 170), rand_range(-450, -40)))
		_bolhas.explosao(q, {"n": 2, "tex": Estilo.tex("mar_bolha"), "vel": [20.0, 70.0], "ang": [240.0, 300.0], "vida": [0.8, 1.4],
			"tam": [8.0, 18.0], "fim": 1.0, "cor": Color(0.85, 0.95, 1.0, 0.75), "grav": -240.0})
	if k >= 1.0:
		_navio_estado = "pousado"
		_navio.rotation = deg2rad(-3.0)
		var pe = _navio.position
		Maquina.efeito(_som_navio_impacto, -2.0)
		tremer(6.0, 0.4)
		particulas.explosao(pe, {"n": 8, "tex": Estilo.tex("fx_nuvem"), "vel": [40.0, 140.0], "ang": [190.0, 350.0], "vida": [1.4, 2.4],
			"tam": [60.0, 110.0], "fim": 2.2, "cor": Color(0.62, 0.74, 0.80, 0.55), "grav": -30.0, "arrasto": 1.2, "espalha": 90.0})
		particulas.explosao(pe, {"n": 12, "tex": Estilo.tex("mar_farpa"), "vel": [120.0, 300.0], "ang": [200.0, 340.0], "vida": [0.8, 1.4],
			"tam": [18.0, 30.0], "cor": Color(0.55, 0.42, 0.30), "grav": 400.0, "giro": [-10.0, 10.0]})
		_bolhas.explosao(pe, {"n": 16, "tex": Estilo.tex("mar_bolha"), "vel": [60.0, 200.0], "ang": [210.0, 330.0], "vida": [1.0, 1.8],
			"tam": [8.0, 22.0], "fim": 1.0, "cor": Color(0.85, 0.95, 1.0, 0.8), "grav": -260.0, "espalha": 120.0})


# ------------------------------------------------------------ vida do mar
func _sempre(delta: float) -> void:
	_t += delta
	var e = Maquina.pulso_vivo()
	if estado == JOGO:
		_mover(delta)
	_navio_tick(delta)
	_porta.modulate.a = 0.30 + 0.30 * e.x + 0.2 * e.y
	for r in _raios:
		var s: Sprite = r["no"]
		s.rotation = r["rot"] + sin(_t * r["vel"] + r["fase"]) * 0.06
		s.modulate.a = 0.10 + 0.08 * sin(_t * r["vel"] * 1.7 + r["fase"]) + 0.06 * e.x
	if _peixes_fundo.visible:
		_peixes_fundo.update()
	# neve marinha descendo devagar (some com a tela leve)
	if _neve.visible and randf() < delta * 6.0 * Maquina.fator_efeitos():
		_neve.soltar(Vector2(rand_range(0, 1024), rand_range(150, 1500)), Vector2(rand_range(-8, 8), rand_range(6, 18)),
			rand_range(3.0, 5.0), rand_range(3.0, 6.0), 2.0, Color(0.7, 0.9, 1.0, 0.0), Color(0.7, 0.9, 1.0, 0.5), Estilo.tex("fx_ponto"))
	# bolhas subindo do chão
	if randf() < delta * 1.2:
		_bolhas.explosao(Vector2(rand_range(80, 940), CHAO + rand_range(-20, 40)), {"n": 4, "tex": Estilo.tex("mar_bolha"), "vel": [20.0, 50.0],
			"ang": [255.0, 285.0], "vida": [1.6, 2.6], "tam": [6.0, 14.0], "fim": 1.1, "cor": Color(0.85, 0.95, 1.0, 0.6), "grav": -160.0, "espalha": 12.0})
	# baleia lá longe
	if _baleia_t < 0.0:
		_baleia_espera -= delta
		if _baleia_espera <= 0.0:
			_baleia_t = 0.0
			_baleia.visible = true
			_baleia.flip_h = randf() < 0.5
			Maquina.efeito(_som_baleia, -16.0, rand_range(0.9, 1.05))
	else:
		_baleia_t += delta
		var k = _baleia_t / 26.0
		var x: float = lerp(-120.0, 1144.0, k) if not _baleia.flip_h else lerp(1144.0, -120.0, k)
		_baleia.position = Vector2(x, 330.0 + sin(k * TAU) * 30.0)
		_baleia.scale = Vector2.ONE * 0.9
		if k >= 1.0:
			_baleia_t = -1.0
			_baleia.visible = false
			_baleia_espera = rand_range(18.0, 30.0)


func _desenhar_peixes_fundo() -> void:
	var tex: Texture = Estilo.tex("mar_peixe")
	for c in _cardumes_fundo:
		var k = fmod(_t / c["periodo"] + c["fase"], 1.0)
		var centro: Vector2 = c["de"].linear_interpolate(c["ate"], k)
		var dir = sign(c["ate"].x - c["de"].x)
		var a = clamp(min(k, 1.0 - k) * 8.0, 0.0, 1.0) * 0.7
		var i = 0
		for off in c["peixes"]:
			var o: Vector2 = off + Vector2(sin(_t * 2.0 + i) * 6.0, sin(_t * 1.6 + i * 0.7) * 4.0)
			var r = Rect2(centro + o - Vector2(20, 8), Vector2(40 * dir, 16))
			_peixes_fundo.draw_texture_rect(tex, r, false, Color(0.25, 0.42, 0.58, a))
			i += 1


## Teste automático (robô): o alvo bom mais perto da mira (nunca a bomba).
func robo_alvo():
	var melhor = null
	var md = 1.0e9
	for o in objs:
		if o.atingido or o.tipo == "bomba":
			continue
		var p: Vector2 = o.no.position
		if p.x < 40 or p.x > 984 or p.y < 140 or p.y > 1780:
			continue
		var d = p.distance_to(MiraGlobal.pos)
		if d < md:
			md = d
			melhor = p
	return melhor
