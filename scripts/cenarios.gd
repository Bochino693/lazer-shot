extends Node2D

## ESCOLHA DE CENÁRIO: "ESCOLHA SEU CENÁRIO" com a contagem, os quatro
## cartões (2x2) com a capa, o nome, o nível e as estrelas de dificuldade, e
## os botões ALEATÓRIO (a roleta sorteia o cenário na hora) e RANKING. Tudo
## pela mira da arma: a mira em cima de um cartão o
## destaca e troca o fundo pela arte daquele cenário; o tiro escolhe.
## Contagem no fim: a roleta corre pelos cartões (rápida no começo, freando)
## e escolhe sozinha. Escolhido, abre a MISSÃO (scripts/missao.gd): o alvo
## JOGAR começa a partida; TROCAR CENÁRIO volta para a grade.

const CENAS = ["res://scenes/deserto.tscn", "res://scenes/mar.tscn", "res://scenes/bar.tscn", "res://scenes/arena.tscn"]
const CENA_RANKING = "res://scenes/ranking.tscn"
const FUNDOS = ["deserto", "mar", "bar", "arena"]
const CARTOES = ["cartao_desert", "cartao_mar", "cartao_bar", "cartao_arena"]
const NOMES = ["DESERTO SAGRADO", "FUNDO DO MAR", "BAR DO FAROESTE", "ARENA LAZER SHOT"]
const DIFICULDADES = [3, 1, 2, 4]
const NIVEIS = ["DIFÍCIL", "FÁCIL", "MÉDIO", "EXPERT"]
const CORES = [Color(1.0, 0.72, 0.08), Color(0.0, 0.65, 1.0), Color(0.25, 1.0, 0.35), Color(1.0, 0.02, 0.02)]
const MAX_ESTRELAS = 4
const TEMPO_AUTO = 10.0
const CARTAO = Vector2(430, 215)
const ESPACO = Vector2(32, 30)
const ORDEM_ROLETA = [0, 1, 3, 2]   # sentido horário na grade 2x2

var _fundo: FundoVivo
var _cartoes = []           # Panel de cada cartão
var _molduras = []
var _sob_mira = -1
var _ranking: Panel
var _sb_ranking: StyleBoxFlat
var _sb_ranking_mira: StyleBoxFlat
var _ranking_mira = false
var _aleatorio: Panel
var _sb_aleatorio: StyleBoxFlat
var _sb_aleatorio_mira: StyleBoxFlat
var _aleatorio_mira = false
var _contador: Panel
var _contador_linha: ColorRect
var _contador_num: Label
var _restante = TEMPO_AUTO
var _contando = true
var _roleta = false
var _bloqueado = false
var _missao: Missao
var _mira: MiraDesenho
var _trajetoria: Trajetoria
var _musica: AudioStreamPlayer
var _som_tiro: AudioStream
var _som_choice: AudioStream
var _saindo = false
var _t = 0.0


func _ready() -> void:
	randomize()
	MiraGlobal.ativa = true
	_som_tiro = load("res://songs/tiro_menu.wav")
	_som_choice = load("res://songs/choice.wav")
	_fundo = FundoVivo.new()
	add_child(_fundo)
	_fundo.mostrar("init")
	var camada = CanvasLayer.new()
	camada.layer = 10
	add_child(camada)
	var raiz = Control.new()
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.rect_size = Tela.TELA
	camada.add_child(raiz)
	_montar_contador(raiz)
	_montar_cartoes(raiz)
	_montar_ranking(raiz)
	_montar_aleatorio(raiz)
	_missao = Missao.criar(self)
	_missao.connect("escolheu", self, "_missao_escolheu")
	_trajetoria = Trajetoria.criar(self)
	_mira = MiraDesenho.criar(self, Color(1.0, 0.2, 0.18))
	_entrada(raiz)
	var tw = create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(self, "_tocar_tema")


func _tocar_tema() -> void:
	if not _saindo:
		_musica = Maquina.musica(self, load("res://songs/theme.ogg"), -4.0)


# ------------------------------------------------------------ montagem
func _montar_contador(raiz: Control) -> void:
	# (estreito: não cobre o logo Lazer & Sport do canto do fundo)
	var w = 600.0
	_contador = Estilo.painel(raiz, Vector2((Tela.TELA.x - w) * 0.5 - 60.0, 34), Vector2(w, 218),
		Estilo.caixa(Color(0.012, 0.006, 0.010, 0.94), Color(1.0, 0.0, 0.08), 5, 42, 58, Color(1.0, 0.0, 0.08, 0.70)))
	_contador.rect_pivot_offset = _contador.rect_size * 0.5
	var titulo = Estilo.rotulo(_contador, "ESCOLHA SEU CENÁRIO", 46, Color(1.0, 0.94, 0.78), 10)
	Estilo.colocar(titulo, Vector2(0, 22), Vector2(w, 62))
	_contador_linha = ColorRect.new()
	_contador_linha.color = Color(1.0, 0.0, 0.08)
	_contador_linha.rect_position = Vector2(46, 92)
	_contador_linha.rect_size = Vector2(w - 92, 5)
	_contador_linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contador.add_child(_contador_linha)
	_contador_num = Estilo.rotulo(_contador, str(int(TEMPO_AUTO)), 78, Color.white, 11)
	Estilo.colocar(_contador_num, Vector2(0, 104), Vector2(w, 88))


func _montar_cartoes(raiz: Control) -> void:
	var total = CARTAO * 2.0 + ESPACO
	var x0 = floor((Tela.TELA.x - total.x) * 0.5)
	var y0 = floor((Tela.TELA.y - total.y) * 0.5 + 105.0)
	for i in 4:
		var col = i % 2
		var lin = i / 2
		var pos = Vector2(x0 + col * (CARTAO.x + ESPACO.x), y0 + lin * (CARTAO.y + ESPACO.y))
		var c = Estilo.painel(raiz, pos, CARTAO, Estilo.caixa(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 42, 12, Color(0, 0, 0, 0.34)))
		c.rect_pivot_offset = CARTAO * 0.5
		var cor: Color = CORES[i]
		# a capa (cantos redondos prontos em sprites/cartao_*.png)
		var img = TextureRect.new()
		img.texture = Estilo.tex(CARTOES[i])
		img.expand = true
		img.stretch_mode = TextureRect.STRETCH_SCALE
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.rect_position = Vector2(8, 8)
		img.rect_size = CARTAO - Vector2(16, 16)
		c.add_child(img)
		# moldura neon na cor do cenário
		var moldura = Estilo.painel(c, Vector2.ZERO, CARTAO, _estilo_moldura(cor, false))
		_molduras.append(moldura)
		var nome = Estilo.rotulo(c, NOMES[i], 25, Color.white, 8, true, Label.ALIGN_LEFT)
		nome.add_color_override("font_color_shadow", Color(0, 0, 0, 0.95))
		nome.add_constant_override("shadow_offset_x", 2)
		nome.add_constant_override("shadow_offset_y", 2)
		Estilo.colocar(nome, Vector2(18, CARTAO.y - 66), Vector2(CARTAO.x - 190, 52))
		# estrelas de dificuldade (embaixo, à direita)
		var faixa = Estilo.painel(c, Vector2(CARTAO.x - 168, CARTAO.y - 58), Vector2(150, 42),
			Estilo.caixa(Color(0, 0, 0, 0.78), cor, 2, 24, 10, Color(cor.r, cor.g, cor.b, 0.34)))
		for s in MAX_ESTRELAS:
			var cheia = s < DIFICULDADES[i]
			var e = Estilo.rotulo(faixa, "★", 28, cor if cheia else Color(0.28, 0.28, 0.28, 0.86), 6)
			Estilo.colocar(e, Vector2(10 + s * 33, 0), Vector2(33, 42))
		# selo com o nome do nível (em cima, à direita)
		var selo = Estilo.painel(c, Vector2(CARTAO.x - 168, 16), Vector2(150, 38),
			Estilo.caixa(Color(0, 0, 0, 0.78), cor, 2, 18, 10, Color(cor.r, cor.g, cor.b, 0.34)))
		var nivel = Estilo.rotulo(selo, NIVEIS[i], 24, cor.linear_interpolate(Color.white, 0.25), 6)
		Estilo.colocar(nivel, Vector2.ZERO, selo.rect_size)
		_cartoes.append(c)
	Estilo.aquecer_fonte(Estilo.fonte(28, true, 6), "★")


func _estilo_moldura(cor: Color, forte: bool) -> StyleBoxFlat:
	var s = Estilo.caixa(Color(0, 0, 0, 0), cor if not forte else cor.linear_interpolate(Color.white, 0.35), 7 if forte else 5, 46,
		30 if forte else 22, Color(cor.r, cor.g, cor.b, 0.75 if forte else 0.5))
	s.draw_center = false
	return s


func _montar_ranking(raiz: Control) -> void:
	_sb_ranking = Estilo.caixa(Color(0.02, 0.01, 0.012, 0.96), Color(1.0, 0.02, 0.02), 4, 39, 34, Color(1.0, 0.0, 0.0, 0.58))
	_sb_ranking_mira = Estilo.caixa(Color(0.06, 0.0, 0.0, 0.98), Color(1.0, 0.16, 0.12), 5, 39, 46, Color(1.0, 0.0, 0.0, 0.82))
	_ranking = Estilo.painel(raiz, Vector2((Tela.TELA.x - 480.0) * 0.5, Tela.TELA.y - 122.0), Vector2(480, 92), _sb_ranking)
	_ranking.rect_pivot_offset = _ranking.rect_size * 0.5
	var t = Estilo.rotulo(_ranking, "🏆 RANKING", 42, Color.white, 6)
	Estilo.colocar(t, Vector2.ZERO, _ranking.rect_size)


## O ALEATÓRIO: entre os cartões e o RANKING, em dourado.
func _montar_aleatorio(raiz: Control) -> void:
	var ouro = Color(1.0, 0.78, 0.12)
	_sb_aleatorio = Estilo.caixa(Color(0.03, 0.02, 0.0, 0.94), ouro, 4, 39, 30, Color(ouro.r, ouro.g, ouro.b, 0.5))
	_sb_aleatorio_mira = Estilo.caixa(Color(0.10, 0.07, 0.0, 0.98), ouro.linear_interpolate(Color.white, 0.35), 5, 39, 44, Color(ouro.r, ouro.g, ouro.b, 0.8))
	var ultimo: Panel = _cartoes[3]
	var y = ultimo.rect_position.y + CARTAO.y + 70.0
	_aleatorio = Estilo.painel(raiz, Vector2((Tela.TELA.x - 560.0) * 0.5, y), Vector2(560, 96), _sb_aleatorio)
	_aleatorio.rect_pivot_offset = _aleatorio.rect_size * 0.5
	var t = Estilo.rotulo(_aleatorio, "🎯 ALEATÓRIO", 44, Color(1.0, 0.95, 0.8), 6)
	Estilo.colocar(t, Vector2.ZERO, _aleatorio.rect_size)


func _no_aleatorio(p: Vector2) -> bool:
	return _aleatorio.visible and Rect2(_aleatorio.rect_position, _aleatorio.rect_size).grow(10.0).has_point(p)


func _destacar_aleatorio(sim: bool) -> void:
	if sim == _aleatorio_mira:
		return
	_aleatorio_mira = sim
	_aleatorio.add_stylebox_override("panel", _sb_aleatorio_mira if sim else _sb_aleatorio)
	var tw = create_tween()
	tw.tween_property(_aleatorio, "rect_scale", Vector2.ONE * (1.06 if sim else 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Tudo entra suave: o contador cresce, os cartões aparecem um a um.
func _entrada(raiz: Control) -> void:
	var tw = create_tween().set_parallel(true)
	_contador.modulate.a = 0.0
	_contador.rect_scale = Vector2(0.94, 0.94)
	tw.tween_property(_contador, "modulate:a", 1.0, 0.42).set_delay(0.10)
	tw.tween_property(_contador, "rect_scale", Vector2.ONE, 0.42).set_delay(0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in 4:
		var c: Panel = _cartoes[i]
		var d = 0.30 + i * 0.07
		c.modulate.a = 0.0
		c.rect_scale = Vector2(0.92, 0.92)
		tw.tween_property(c, "modulate:a", 1.0, 0.34).set_delay(d)
		tw.tween_property(c, "rect_scale", Vector2.ONE, 0.34).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_aleatorio.modulate.a = 0.0
	tw.tween_property(_aleatorio, "modulate:a", 1.0, 0.34).set_delay(0.56)
	_ranking.modulate.a = 0.0
	_ranking.rect_scale = Vector2(0.94, 0.94)
	tw.tween_property(_ranking, "modulate:a", 1.0, 0.34).set_delay(0.62)
	tw.tween_property(_ranking, "rect_scale", Vector2.ONE, 0.34).set_delay(0.62).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------ quadro
func _process(delta: float) -> void:
	_t += delta
	var p = MiraGlobal.mira()
	if _missao.ativo:
		_missao.mira(p)
	elif not _roleta and not _bloqueado:
		_destacar(_cartao_em(p))
		_destacar_ranking(_no_ranking(p))
		_destacar_aleatorio(_no_aleatorio(p))
	# o botão RANKING pulsa de leve
	if not _ranking_mira:
		_ranking.rect_scale = Vector2.ONE * (1.0 + 0.02 * sin(_t * 3.2))
	if _contando and not _roleta and not _bloqueado and not _missao.ativo:
		_restante = max(0.0, _restante - delta)
		_atualizar_contador()
		if _restante <= 0.0:
			_contando = false
			_rodar_roleta()


func _atualizar_contador() -> void:
	var seg = int(ceil(_restante))
	_contador_num.text = str(seg)
	var alerta = seg <= 5
	_contador_num.add_color_override("font_color", Color(1.0, 0.05, 0.05) if alerta else Color.white)
	_contador_linha.color = Color(1.0, 0.02, 0.02, 1.0 if alerta else 0.95)


func _cartao_em(p: Vector2) -> int:
	for i in 4:
		var c: Panel = _cartoes[i]
		if Rect2(c.rect_position, c.rect_size).has_point(p):
			return i
	return -1


func _no_ranking(p: Vector2) -> bool:
	return Rect2(_ranking.rect_position, _ranking.rect_size).grow(10.0).has_point(p)


## A mira em cima de um cartão: ele cresce, a moldura acende e o fundo vira
## a arte daquele cenário.
func _destacar(i: int) -> void:
	if i == _sob_mira:
		return
	if _sob_mira >= 0:
		_marcar(_sob_mira, false)
	_sob_mira = i
	if i >= 0:
		_marcar(i, true)
		_fundo.mostrar(FUNDOS[i])
	else:
		_fundo.mostrar("init")


func _marcar(i: int, forte: bool) -> void:
	var c: Panel = _cartoes[i]
	_molduras[i].add_stylebox_override("panel", _estilo_moldura(CORES[i], forte))
	var tw = create_tween()
	tw.tween_property(c, "rect_scale", Vector2.ONE * (1.045 if forte else 1.0), 0.12).set_trans(Tween.TRANS_BACK if forte else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _destacar_ranking(sim: bool) -> void:
	if sim == _ranking_mira:
		return
	_ranking_mira = sim
	_ranking.add_stylebox_override("panel", _sb_ranking_mira if sim else _sb_ranking)
	var tw = create_tween()
	tw.tween_property(_ranking, "rect_scale", Vector2.ONE * (1.06 if sim else 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------ tiro
func _input(ev: InputEvent) -> void:
	if _saindo:
		return
	if Maquina.e_tiro(ev):
		get_tree().set_input_as_handled()
		_tiro(MiraGlobal.mira())
	elif Maquina.e_start(ev):
		get_tree().set_input_as_handled()
		# START: na missão joga; na grade, sorteia agora
		if _missao.ativo:
			_missao.jogar()
		elif not _roleta and not _bloqueado:
			_contando = false
			_rodar_roleta()


func _tiro(p: Vector2) -> void:
	Maquina.efeito(_som_tiro, -4.0, rand_range(0.96, 1.04))
	MiraGlobal.coice(0.5)
	_mira.pulso()
	_trajetoria.disparar(p, "menu")
	if _missao.ativo:
		_missao.tiro(p)
		return
	if _roleta or _bloqueado:
		return
	var i = _cartao_em(p)
	if i >= 0:
		_contando = false
		var c: Panel = _cartoes[i]
		c.rect_scale = Vector2(0.97, 0.97)
		var tw = create_tween()
		tw.tween_property(c, "rect_scale", Vector2(1.03, 1.03), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_abrir_missao(i)
		return
	if _no_aleatorio(p):
		_contando = false
		_destacar_aleatorio(false)
		_rodar_roleta()
		return
	if _no_ranking(p):
		_contando = false
		_bloqueado = true
		get_tree().set_meta("ranking_origem", "cenarios")
		_ir(CENA_RANKING)


# ------------------------------------------------------------ roleta
## Roleta em volta da grade (sentido horário), rápida no começo e freando
## até parar no sorteado: ~1,6 s no total.
func _rodar_roleta() -> void:
	if _roleta:
		return
	_roleta = true
	_destacar(-1)
	var final = randi() % 4
	var p0 = randi() % ORDEM_ROLETA.size()
	var resto = posmod(ORDEM_ROLETA.find(final) - p0 + 1, ORDEM_ROLETA.size())
	var passos = resto + ORDEM_ROLETA.size() * (3 if resto < 2 else 2)
	var tw = create_tween()
	for i in passos:
		tw.tween_callback(self, "_passo_roleta", [ORDEM_ROLETA[(p0 + i) % ORDEM_ROLETA.size()], false])
		tw.tween_interval(0.05 + float(i * i) * 0.0011)
	tw.tween_callback(self, "_passo_roleta", [final, true])
	tw.tween_interval(0.35)
	tw.tween_callback(self, "_fim_roleta", [final])


func _passo_roleta(i: int, final: bool) -> void:
	for k in 4:
		var c: Panel = _cartoes[k]
		var esta = k == i
		_molduras[k].add_stylebox_override("panel", _estilo_moldura(CORES[k], esta))
		c.rect_scale = Vector2.ONE * ((1.08 if final else 1.04) if esta else 1.0)
	_fundo.mostrar(FUNDOS[i], true)
	Maquina.efeito(_som_choice, -3.0)


func _fim_roleta(i: int) -> void:
	_roleta = false
	_abrir_missao(i)


# ------------------------------------------------------------ missão
func _abrir_missao(i: int) -> void:
	if _missao.ativo:
		return
	_bloqueado = true
	_contando = false
	_fundo.mostrar(FUNDOS[i], true)
	_contador.visible = false
	_aleatorio.visible = false
	_missao.abrir(CENAS[i])


func _missao_escolheu(acao: String) -> void:
	if _saindo:
		return
	if acao == "jogar":
		_missao.fechar()
		_ir(_missao.cena)
		return
	# trocar: volta para a grade, com a contagem do sorteio reiniciada
	_missao.fechar()
	_bloqueado = false
	_restante = TEMPO_AUTO
	_contando = true
	_contador.visible = true
	_aleatorio.visible = true
	_atualizar_contador()
	for k in 4:
		_marcar(k, false)
	_sob_mira = -1
	_fundo.mostrar("init")


func _ir(caminho: String) -> void:
	if _saindo:
		return
	_saindo = true
	if _musica != null:
		var tw = create_tween()
		tw.tween_property(_musica, "volume_db", -40.0, 0.3)
	TransicaoGlobal.trocar_cena(caminho)
