extends Node2D
class_name Fase

## BASE DAS QUATRO FASES (Deserto, Mar, Bar, Arena).
##
## Cuida de tudo o que é igual: COMO JOGAR -> tiro -> contagem 3, 2, 1 ->
## partida (tempo, munição, recarga, tiros, acertos, combo, placar, mira,
## trajetória do tiro, anunciador de combos, avisos) -> fim (nome no ranking
## se entrou, resultado, VOLTAR AOS CENÁRIOS, START joga de novo, a tela
## volta sozinha ao início).
##
## Cada fase preenche:
##   _configurar()        nome, cor, estilo do tiro, músicas e sons
##   _montar_cenario()    fundo e vida do cenário (camadas abaixo)
##   _icones()            figuras do COMO JOGAR
##   _comecar()           a partida começou (alvos começam a nascer)
##   _jogo(delta)         a cada quadro da partida
##   _sempre(delta)       a cada quadro, em qualquer estado (vida do fundo)
##   _tiro(p)             um tiro em p (bala já gasta): acerte ou erre
##   _encerrou()          a partida acabou (pare de nascer, limpe os alvos)
##   _extra_placar()      [título, valor, cor] do último campo do placar
##
## Camadas (de baixo para cima): mundo { cenario, alvos, efeitos (normal),
## luz (somada) }, trajetória do tiro (15), anúncio (46), placar (50),
## avisos (55), clarão (60), modais (95-150), mira (200).

enum { INTRO, CONTAGEM, JOGO, FIM }

const OURO = Color(1.0, 0.86, 0.30)
const VERMELHO = Color(1.0, 0.32, 0.28)
## Os fundos de 1080x1920 (tools/preparar_mali.py) cobrem a tela 1024x1820 na
## escala 1024/1080. As posições da versão 4.6 estão em pixels da imagem
## 1024x1536 (escala 1,25 e 100 px cortados de cada lado): tela() converte.
const K_FUNDO = 1.25 * 1024.0 / 1080.0
const DX_FUNDO = -100.0 * 1024.0 / 1080.0

# --- a fase preenche em _configurar()
var id_fase = ""
var cenario_ranking = ""
var cor = Color.white
var estilo_tiro = "laser"
var forca_coice = 1.0
var musica_path = ""
var som_tiro_path = ""
var som_recarga_path = "res://songs/recharge.wav"
var vol_tiro = -3.0
var janela_combo = 2.2
var municao_max = 30
var tempo_recarga = 1.1
var centro_contagem = 910.0

# --- estado da partida
var estado = INTRO
var tempo_total = 120.0
var tempo_restante = 120.0
var tempo_jogo = 0.0
var pontos = 0
var tiros = 0
var acertos = 0
var balas = 30
var recarregando = false
var recarga_falta = 0.0
var combo = 0
var combo_tipo = ""
var melhor_combo = 0
var combo_t = 0.0

# --- camadas
var mundo: Node2D
var cenario: Node2D
var alvos: Node2D
var efeitos: Node2D
var luz: Node2D
var particulas: Particulas
var particulas_luz: Particulas
var cacos: Cacos

var placar: Placar
var avisos: Avisos
var anuncio: AnuncioCombo
var trajetoria: Trajetoria
var mira_desenho: MiraDesenho
var como_jogar: ComoJogar
var contagem: Contagem
var fim: FimPartida
var nome: NomeRanking

var _musica: AudioStreamPlayer
var _som_tiro: AudioStream
var _som_sem_bala: AudioStream
var _som_recarga: AudioStream
var _clarao: ColorRect
var _faixa: Label
var _tremor = 0.0
var _tremor_forca = 0.0
var _precisao = 0
var _saindo = false


func _ready() -> void:
	randomize()
	_configurar()
	tempo_total = Maquina.tempo_partida()
	tempo_restante = tempo_total
	balas = municao_max
	_montar_camadas()
	_montar_cenario()
	placar = Placar.criar(self, funcref(self, "dados_placar"), cor)
	avisos = Avisos.criar(self)
	anuncio = AnuncioCombo.criar(self, id_fase)
	trajetoria = Trajetoria.criar(self)
	_montar_clarao()
	contagem = Contagem.criar(self, cor, centro_contagem)
	contagem.connect("terminou", self, "_contagem_terminou")
	fim = FimPartida.criar(self, cor)
	fim.connect("escolheu", self, "_fim_escolheu")
	nome = NomeRanking.criar(self)
	nome.connect("confirmado", self, "_nome_confirmado")
	como_jogar = ComoJogar.criar(self, id_fase, _icones())
	mira_desenho = MiraDesenho.criar(self, cor)
	_som_tiro = load(som_tiro_path) if som_tiro_path != "" else null
	_som_sem_bala = load("res://songs/bullet_no.wav")
	_som_recarga = load(som_recarga_path)
	if musica_path != "":
		_musica = Maquina.musica(self, load(musica_path), 0.0)
	MiraGlobal.ativa = true
	estado = INTRO
	Tela.marca("fase %s montada (memória %d MB)" % [id_fase, int(Tela.memoria_mb())])


func _montar_camadas() -> void:
	mundo = Node2D.new()
	mundo.name = "Mundo"
	add_child(mundo)
	cenario = Node2D.new()
	cenario.name = "Cenario"
	mundo.add_child(cenario)
	alvos = Node2D.new()
	alvos.name = "Alvos"
	mundo.add_child(alvos)
	efeitos = Node2D.new()
	efeitos.name = "Efeitos"
	mundo.add_child(efeitos)
	cacos = Cacos.new()
	efeitos.add_child(cacos)
	particulas = Particulas.new()
	efeitos.add_child(particulas)
	luz = Node2D.new()
	luz.name = "Luz"
	luz.material = Estilo.material_soma()
	mundo.add_child(luz)
	particulas_luz = Particulas.new()
	particulas_luz.somar = true
	mundo.add_child(particulas_luz)


func _montar_clarao() -> void:
	var camada = CanvasLayer.new()
	camada.layer = 60
	add_child(camada)
	_clarao = ColorRect.new()
	_clarao.rect_size = Tela.TELA
	_clarao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clarao.visible = false
	camada.add_child(_clarao)
	_faixa = Estilo.rotulo(camada, "", 96, Color.white, 10)
	Estilo.colocar(_faixa, Vector2(0, 820), Vector2(1024, 180))
	_faixa.visible = false


# ------------------------------------------------------------ para as fases
func _configurar() -> void:
	pass


func _montar_cenario() -> void:
	pass


func _icones() -> Dictionary:
	return {}


func _comecar() -> void:
	pass


func _jogo(_delta: float) -> void:
	pass


func _sempre(_delta: float) -> void:
	pass


func _tiro(_p: Vector2) -> void:
	pass


func _encerrou() -> void:
	pass


func _extra_placar() -> Array:
	return ["", "", Color.white]


# ------------------------------------------------------------ quadro
func _process(delta: float) -> void:
	if estado == JOGO:
		tempo_jogo += delta
		tempo_restante -= delta
		if recarregando:
			recarga_falta -= delta
			mira_desenho.recarga(clamp(1.0 - recarga_falta / tempo_recarga, 0.0, 1.0))
			if recarga_falta <= 0.0:
				recarregando = false
				balas = municao_max
				mira_desenho.recarga(-1.0)
		if combo_t > 0.0:
			combo_t -= delta
			if combo_t <= 0.0:
				_combo_expirou()
		_jogo(delta)
		if tempo_restante <= 0.0 and estado == JOGO:
			tempo_restante = 0.0
			encerrar("TEMPO ESGOTADO!")
	_sempre(delta)
	if _tremor > 0.0:
		_tremor = max(0.0, _tremor - delta)
		var f = _tremor_forca * (_tremor / 0.25)
		mundo.position = Vector2(rand_range(-f, f), rand_range(-f, f))
	elif mundo.position != Vector2.ZERO:
		mundo.position = Vector2.ZERO


func _input(ev: InputEvent) -> void:
	if _saindo:
		return
	if Maquina.e_tiro(ev):
		get_tree().set_input_as_handled()
		_gatilho()
	elif Maquina.e_recarga(ev):
		get_tree().set_input_as_handled()
		recarregar()
	elif Maquina.e_start(ev):
		get_tree().set_input_as_handled()
		_start()


func _gatilho() -> void:
	var p = MiraGlobal.mira()
	match estado:
		INTRO:
			_comecar_contagem()
		JOGO:
			atirar(p)
		FIM:
			if nome.ativo:
				if nome.tiro(p):
					trajetoria.disparar(p, estilo_tiro)
			elif fim.ativo:
				trajetoria.disparar(p, estilo_tiro)
				fim.tiro(p)


func _start() -> void:
	match estado:
		INTRO:
			_comecar_contagem()
		FIM:
			if nome.ativo:
				return
			# jogar de novo: a fase recomeça do zero (cobra no modo crédito)
			if Maquina.cobrar():
				_sair(filename)


func _comecar_contagem() -> void:
	if estado != INTRO:
		return
	estado = CONTAGEM
	como_jogar.fechar()
	contagem.rodar()


func _contagem_terminou() -> void:
	estado = JOGO
	tempo_jogo = 0.0
	avisos.instrucao("COMEÇOU!", cor.linear_interpolate(Color.white, 0.4))
	_comecar()


# ------------------------------------------------------------ tiro
func atirar(p: Vector2) -> void:
	if recarregando:
		return
	if balas <= 0:
		Maquina.efeito(_som_sem_bala, -2.0)
		avisos.instrucao("RECARREGUE! (BOTÃO DA ARMA)", Color(1.0, 0.45, 0.35))
		return
	balas -= 1
	tiros += 1
	MiraGlobal.coice(forca_coice)
	mira_desenho.pulso()
	Maquina.efeito(_som_tiro, vol_tiro, rand_range(0.96, 1.04))
	trajetoria.disparar(p, estilo_tiro)
	_tiro(p)
	if balas == 0:
		avisos.instrucao("RECARREGUE!", Color(1.0, 0.45, 0.35))


func recarregar() -> void:
	if estado != JOGO or recarregando or balas >= municao_max:
		return
	recarregando = true
	recarga_falta = tempo_recarga
	Maquina.efeito(_som_recarga, -2.0)
	mira_desenho.recarga(0.0)


# ------------------------------------------------------------ pontos
## Acerto que vale pontos e conta no combo.
func ganhar(valor: int, pos: Vector2, cor_pts: Color = OURO, escala: float = 1.0) -> void:
	pontos += valor
	acertos += 1
	avisos.pontos(pos, "+%d" % valor, cor_pts, escala)


## Bônus (barril, cristal, LED, peixe): pontos e acerto, sem mexer no combo.
func bonus(valor: int, pos: Vector2, cor_pts: Color = OURO, escala: float = 1.15) -> void:
	pontos += valor
	acertos += 1
	avisos.pontos(pos, "+%d" % valor, cor_pts, escala)


## Pontos perdidos (alvo errado, garrafa verde, ordem errada...).
func perder(valor: int, pos: Vector2, texto: String = "") -> void:
	pontos -= valor
	avisos.pontos(pos, "-%d" % valor, VERMELHO, 1.1)
	if texto != "":
		avisos.mostrar(pos, texto, VERMELHO)
	quebrar_combo()


## Tiro que não acertou nada que vale.
func errar(pos: Vector2, texto: String = "ERROU!") -> void:
	quebrar_combo()
	avisos.mostrar(pos, texto, Color(1.0, 0.82, 0.78))


## Mais um acerto seguido (tipo: no Egito o combo é do mesmo astro).
func registrar_combo(tipo: String = "") -> void:
	if combo_t > 0.0 and tipo == combo_tipo:
		combo += 1
	else:
		combo = 1
	combo_tipo = tipo
	combo_t = janela_combo
	melhor_combo = int(max(melhor_combo, combo))
	anuncio.combo(combo)


func quebrar_combo() -> void:
	combo = 0
	combo_tipo = ""
	combo_t = 0.0
	anuncio.zerar()


func _combo_expirou() -> void:
	combo = 0
	combo_tipo = ""
	anuncio.zerar()


func dados_placar() -> Dictionary:
	var e = _extra_placar()
	return {
		"tempo": tempo_restante, "pontos": pontos,
		"municao": balas, "municao_max": municao_max,
		"recarregando": recarregando,
		"recarga": clamp(1.0 - recarga_falta / max(tempo_recarga, 0.01), 0.0, 1.0),
		"acertos": acertos, "tiros": tiros,
		"extra_titulo": e[0], "extra": e[1], "extra_cor": e[2],
	}


# ------------------------------------------------------------ efeitos de tela
func clarao(c: Color, duracao: float = 0.18) -> void:
	_clarao.visible = true
	_clarao.color = c
	var tw = create_tween()
	tw.tween_property(_clarao, "color:a", 0.0, duracao)
	tw.tween_callback(_clarao, "hide")


func tremer(forca: float = 8.0, duracao: float = 0.25) -> void:
	_tremor = max(_tremor, duracao)
	_tremor_forca = max(_tremor_forca if _tremor > 0.0 else 0.0, forca)


## Faixa grande no meio da tela (TEMPO ESGOTADO!, 3 BOMBAS!).
func faixa(texto: String, c: Color, duracao: float = 1.3) -> void:
	_faixa.text = texto
	_faixa.add_color_override("font_color", c)
	_faixa.visible = true
	_faixa.rect_scale = Vector2(1.6, 1.6)
	_faixa.modulate.a = 1.0
	var tw = create_tween()
	tw.tween_property(_faixa, "rect_scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(max(0.1, duracao - 0.6))
	tw.tween_property(_faixa, "modulate:a", 0.0, 0.3)
	tw.tween_callback(_faixa, "hide")


## Espera para usar com yield: yield(esperar(0.3), "timeout"). O relógio é
## filho da fase e sai junto com ela, então a função que espera não volta
## numa fase que já saiu da tela.
func esperar(s: float) -> Timer:
	var t = Timer.new()
	t.one_shot = true
	t.wait_time = max(0.01, s)
	add_child(t)
	t.connect("timeout", t, "queue_free")
	t.start()
	return t


# ------------------------------------------------------------ cenário
## Pixel da imagem 1024x1536 da versão 4.6 -> ponto da tela.
static func tela(p: Vector2) -> Vector2:
	return Vector2(p.x * K_FUNDO + DX_FUNDO, p.y * K_FUNDO)


## Ponto da tela -> pixel da imagem 1024x1536 da versão 4.6.
static func imagem(p: Vector2) -> Vector2:
	return Vector2((p.x - DX_FUNDO) / K_FUNDO, p.y / K_FUNDO)


static func poligono(pts: Array) -> PoolVector2Array:
	var r = PoolVector2Array()
	for q in pts:
		r.append(tela(q))
	return r


## O fundo da fase (sprites/fundo_*.jpg) cobrindo a tela.
func fundo_sprite(nome: String, pai: Node = null) -> Sprite:
	var s = Sprite.new()
	s.texture = Estilo.tex(nome)
	s.centered = false
	s.scale = Vector2.ONE * (Tela.TELA.x / s.texture.get_width())
	(pai if pai != null else cenario).add_child(s)
	return s


## Sprite de luz somada (brilho, anel, estrela...) no nó `pai`.
func luz_sprite(nome: String, pai: Node, pos: Vector2, tam: float, c: Color) -> Sprite:
	var s = Sprite.new()
	s.texture = Estilo.tex(nome)
	s.material = Estilo.material_soma()
	s.position = pos
	s.scale = Vector2.ONE * (tam / s.texture.get_width())
	s.modulate = c
	pai.add_child(s)
	return s


## Clarão redondo que cresce e some (luz somada). São poucos, reaproveitados
## em rodízio: tiro atrás de tiro não cria nó novo.
var _luzes_breves = []
var _luz_breve_i = 0

func luz_sprite_breve(pos: Vector2, tam: float, c: Color, dur: float = 0.35) -> void:
	var s: Sprite
	if _luzes_breves.size() < 10:
		s = luz_sprite("fx_brilho", luz, pos, tam * 0.6, c)
		_luzes_breves.append(s)
	else:
		s = _luzes_breves[_luz_breve_i]
		_luz_breve_i = (_luz_breve_i + 1) % _luzes_breves.size()
		var antes = s.get_meta("tw")
		if antes != null and antes.is_valid():
			antes.kill()
		s.position = pos
		s.scale = Vector2.ONE * (tam * 0.6 / s.texture.get_width())
		s.modulate = c
		s.visible = true
	var tw = create_tween().set_parallel(true)
	tw.tween_property(s, "scale", s.scale * 1.7, dur)
	tw.tween_property(s, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(s, "set_visible", [false])
	s.set_meta("tw", tw)


# ------------------------------------------------------------ alvos
## O tiro em `p` pega o desenho deste sprite? Usa a máscara 24x24 do quadro
## parado (folga: quantas casas em volta também valem).
static func acerta_sprite(s: Sprite, mascara: Array, celula: Vector2, p: Vector2, folga: int = 1) -> bool:
	if s == null or not s.is_visible_in_tree():
		return false
	var local = s.get_global_transform().affine_inverse().xform(p)
	var u = local.x / celula.x + 0.5
	var v = local.y / celula.y + 0.5
	if u < -0.05 or u > 1.05 or v < -0.05 or v > 1.05:
		return false
	var n = mascara.size()
	var cx = int(clamp(u * n, 0, n - 1))
	var cy = int(clamp(v * n, 0, n - 1))
	for dy in range(-folga, folga + 1):
		for dx in range(-folga, folga + 1):
			var x = cx + dx
			var y = cy + dy
			if x >= 0 and y >= 0 and x < n and y < n and mascara[y][x] == "1":
				return true
	return false


## Folha de alvo pronta (scripts/dados_arte.gd): textura, quadros, célula e
## máscara.
static func folha(nome: String) -> Dictionary:
	var d: Dictionary = preload("res://scripts/dados_arte.gd").FOLHAS[nome]
	var r = d.duplicate()
	r["tex"] = load(d["arquivo"])
	r["cel"] = Vector2(d["celula"][0], d["celula"][1])
	return r


## Um quadro da folha como textura (para o COMO JOGAR e cartões).
static func quadro(f: Dictionary, i: int) -> AtlasTexture:
	var a = AtlasTexture.new()
	a.atlas = f["tex"]
	a.region = Rect2(Vector2(f["cel"].x * i, 0), f["cel"])
	return a


# ------------------------------------------------------------ fim
func encerrar(texto: String = "TEMPO ESGOTADO!") -> void:
	if estado == FIM:
		return
	estado = FIM
	recarregando = false
	mira_desenho.recarga(-1.0)
	_encerrou()
	_precisao = int(round(float(acertos) / float(tiros) * 100.0)) if tiros > 0 else 0
	faixa(texto, cor.linear_interpolate(Color.white, 0.3), 1.4)
	if _musica != null:
		var tw = create_tween()
		tw.tween_property(_musica, "volume_db", -40.0, 0.6)
		tw.tween_callback(_musica, "stop")
	var fim_som = load("res://songs/end_game.mp3")
	Maquina.musica(self, fim_som, -2.0)
	yield(esperar(1.5), "timeout")
	if RankingManager.deve_entrar_no_ranking(pontos, _precisao):
		nome.abrir(cor, pontos, _precisao)
	else:
		fim.mostrar(_dados_fim(""))


func _dados_fim(recorde: String) -> Dictionary:
	return {"pontos": pontos, "tiros": tiros, "acertos": acertos, "erros": int(max(0, tiros - acertos)),
		"precisao": _precisao, "melhor_combo": melhor_combo, "recorde": recorde}


func _nome_confirmado(n: String) -> void:
	RankingManager.adicionar_resultado(n, pontos, cenario_ranking, _precisao)
	fim.mostrar(_dados_fim(n))


func _fim_escolheu(acao: String) -> void:
	if acao == "cenarios":
		_sair("res://scenes/cenarios.tscn")
	else:
		_sair("res://scenes/menu.tscn")


func _sair(caminho: String) -> void:
	if _saindo:
		return
	_saindo = true
	TransicaoGlobal.trocar_cena(caminho)
