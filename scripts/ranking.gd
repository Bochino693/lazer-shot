extends Node2D

## RANKING DOS 20 MELHORES: abas TODOS / DESERTO / MAR / BAR / ARENA, as
## linhas com posição (medalhas no pódio), foto, jogador, cenário, pontos e
## acerto, e VOLTAR AOS CENÁRIOS. Tudo pela mira: tiro na aba, nas setas ▲▼
## (rolam a lista) ou no botão.
##
## Na abertura (vindo da tela inicial parada) é a vitrine: sem botões,
## "APERTE START" piscando, START começa; volta sozinho para a tela inicial.
## A foto é a da webcam no começo da partida (scripts/foto_jogador.gd); sem
## foto, a silhueta. As fotos entram na tabela uma por quadro (abrir todas de
## uma vez engasgaria a TV Box).

const CENA_CENARIOS = "res://scenes/cenarios.tscn"
const CENA_MENU = "res://scenes/menu.tscn"
const TEMPO_VITRINE = 20.0
const MAX = 20
const COLUNAS = [["POS", 0.11], ["FOTO", 0.12], ["JOGADOR", 0.31], ["CENÁRIO", 0.15], ["PONTOS", 0.19], ["ACERTO", 0.12]]
const ALTURA_LINHA = 116.0
const ESPACO_LINHA = 10.0
const FILTROS = ["TODOS", "DESERTO", "MAR", "BAR", "ARENA"]
const VERMELHO = Color(1.0, 0.02, 0.02)

var vitrine = false

var _fundo: FundoVivo
var _painel: Panel
var _filtro = "TODOS"
var _botoes_filtro = []
var _lista_caixa: Control       # recorta a lista
var _lista: Control             # as linhas (sobe e desce)
var _rolagem = 0
var _linhas = 0
var _visiveis = 1
var _subir: Panel
var _descer: Panel
var _voltar: Panel
var _sb_voltar: StyleBoxFlat
var _sb_voltar_mira: StyleBoxFlat
var _voltar_mira = false
var _chamada: Label
var _mira: MiraDesenho
var _trajetoria: Trajetoria
var _musica: AudioStreamPlayer
var _som_tiro: AudioStream
var _saindo = false
var _t = 0.0
var _fotos_pendentes = []       # [TextureRect, caminho]


func _ready() -> void:
	var origem = str(get_tree().get_meta("ranking_origem")) if get_tree().has_meta("ranking_origem") else "cenarios"
	if get_tree().has_meta("ranking_origem"):
		get_tree().remove_meta("ranking_origem")
	vitrine = origem == "main_atrativo"
	MiraGlobal.ativa = not vitrine
	_som_tiro = load("res://songs/tiro_menu.wav")
	_fundo = FundoVivo.new()
	_fundo.escurecer = 0.55
	add_child(_fundo)
	_fundo.mostrar("init")
	var camada = CanvasLayer.new()
	camada.layer = 10
	add_child(camada)
	_painel = Estilo.painel(camada, Vector2(16, 16), Tela.TELA - Vector2(32, 32),
		Estilo.caixa(Color(0, 0, 0, 0.80), Color(1.0, 0.02, 0.02, 0.95), 4, 32, 24, Color(1, 0, 0, 0.26)))
	var titulo = Estilo.rotulo(_painel, "🏆 RANKING DOS 20 MELHORES", 58, Color.white, 10)
	Estilo.colocar(titulo, Vector2(0, 18), Vector2(_painel.rect_size.x, 80))
	_montar_filtros()
	_montar_cabecalho()
	_montar_lista()
	_montar_botoes()
	_montar_lista_linhas()
	_musica = Maquina.musica(self, load("res://songs/ranking-song.mp3"), -4.0)
	if vitrine:
		_montar_chamada()
	else:
		_trajetoria = Trajetoria.criar(self)
		_mira = MiraDesenho.criar(self, Color(1.0, 0.2, 0.18))


# ------------------------------------------------------------ montagem
func _montar_filtros() -> void:
	var larg = 176.0
	var sep = 8.0
	var x0 = (_painel.rect_size.x - (larg * FILTROS.size() + sep * (FILTROS.size() - 1))) * 0.5
	for i in FILTROS.size():
		var b = Estilo.painel(_painel, Vector2(x0 + i * (larg + sep), 108), Vector2(larg, 72), StyleBoxFlat.new())
		b.rect_pivot_offset = b.rect_size * 0.5
		var t = Estilo.rotulo(b, FILTROS[i], 30, Color.white, 4)
		Estilo.colocar(t, Vector2.ZERO, b.rect_size)
		_botoes_filtro.append(b)
	_pintar_filtros()


func _pintar_filtros() -> void:
	for i in FILTROS.size():
		var ativo = FILTROS[i] == _filtro
		var sb = Estilo.caixa(VERMELHO if ativo else Color(0, 0, 0, 0.88), Color.white if ativo else Color(1.0, 0.02, 0.02, 0.85), 2, 18)
		_botoes_filtro[i].add_stylebox_override("panel", sb)


func _montar_cabecalho() -> void:
	var util = _painel.rect_size.x - 52.0 - 20.0
	var x = 26.0
	for col in COLUNAS:
		var l = Estilo.rotulo(_painel, col[0], 28, Color(1.0, 0.25, 0.22), 5, false)
		Estilo.colocar(l, Vector2(x, 196), Vector2(util * col[1], 50))
		x += util * col[1]


func _montar_lista() -> void:
	_lista_caixa = Control.new()
	_lista_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lista_caixa.rect_clip_content = true
	_lista_caixa.rect_position = Vector2(26, 254)
	_lista_caixa.rect_size = Vector2(_painel.rect_size.x - 52, _painel.rect_size.y - 254 - 136)
	_painel.add_child(_lista_caixa)
	_lista = Control.new()
	_lista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lista_caixa.add_child(_lista)
	_visiveis = int(floor((_lista_caixa.rect_size.y + ESPACO_LINHA) / (ALTURA_LINHA + ESPACO_LINHA)))


func _montar_botoes() -> void:
	var sb_seta = Estilo.caixa(Color(0.88, 0.08, 0.06, 0.96), Color(0, 0, 0, 0), 0, 20)
	var caixa = _lista_caixa
	_subir = Estilo.painel(_painel, caixa.rect_position + Vector2(caixa.rect_size.x - 96, 10), Vector2(88, 88), sb_seta)
	_descer = Estilo.painel(_painel, caixa.rect_position + Vector2(caixa.rect_size.x - 96, caixa.rect_size.y - 98), Vector2(88, 88), sb_seta)
	for par in [[_subir, "▲"], [_descer, "▼"]]:
		par[0].rect_pivot_offset = Vector2(44, 44)
		var t = Estilo.rotulo(par[0], par[1], 40, Color.white, 0)
		Estilo.colocar(t, Vector2.ZERO, Vector2(88, 88))
	_sb_voltar = Estilo.caixa(Color(0, 0, 0, 0.96), Color(1.0, 0.02, 0.02, 0.95), 3, 28, 12, Color(1, 0, 0, 0.18))
	_sb_voltar_mira = Estilo.caixa(Color(0.18, 0, 0, 1), Color.white, 4, 28, 38, Color(1, 0, 0, 0.72))
	_voltar = Estilo.painel(_painel, Vector2(_painel.rect_size.x * 0.5 - 300, _painel.rect_size.y - 118), Vector2(600, 96), _sb_voltar)
	_voltar.rect_pivot_offset = _voltar.rect_size * 0.5
	var tv = Estilo.rotulo(_voltar, "VOLTAR AOS CENÁRIOS", 40, Color.white, 5)
	Estilo.colocar(tv, Vector2.ZERO, _voltar.rect_size)
	if vitrine:
		_voltar.visible = false
		_subir.visible = false
		_descer.visible = false


func _montar_chamada() -> void:
	var camada = CanvasLayer.new()
	camada.layer = 30
	add_child(camada)
	_chamada = Estilo.rotulo(camada, Maquina.texto_chamada(), 38, Color.white, 6)
	Estilo.colocar(_chamada, Vector2(152, Tela.TELA.y - 137), Vector2(720, 90))
	var tw = create_tween().set_loops()
	tw.tween_property(_chamada, "modulate:a", 0.35, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_chamada, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)


# ------------------------------------------------------------ linhas
func _montar_lista_linhas() -> void:
	for c in _lista.get_children():
		c.queue_free()
	_rolagem = 0
	_lista.rect_position = Vector2.ZERO
	var dados = []
	for e in RankingManager.obter_ranking():
		if _filtro == "TODOS" or RankingManager.normalizar(str(e.get("cenario", ""))) == _filtro:
			dados.append(e)
	_linhas = int(min(MAX, dados.size()))
	if _linhas == 0:
		_lista_vazia()
	for i in _linhas:
		var e: Dictionary = dados[i]
		_linha(i, e)
	_atualizar_setas()


func _linha(i: int, e: Dictionary) -> void:
	var pos = i + 1
	var larg = _lista_caixa.rect_size.x - 20.0
	var cor_pontos = Color(1.0, 0.86, 0.30)
	var fundo = Color(0, 0, 0, 0.72)
	var borda = Color(1.0, 0.02, 0.02, 0.35)
	match pos:
		1:
			fundo = Color(0.40, 0.28, 0.0, 0.62)
			borda = Color(1.0, 0.82, 0.20)
		2:
			fundo = Color(0.20, 0.20, 0.22, 0.75)
			borda = Color(0.90, 0.92, 0.96)
		3:
			fundo = Color(0.30, 0.13, 0.03, 0.62)
			borda = Color(0.95, 0.55, 0.25)
		_:
			cor_pontos = Color(1.0, 0.30, 0.25)
	var l = Estilo.painel(_lista, Vector2(0, i * (ALTURA_LINHA + ESPACO_LINHA)), Vector2(larg, ALTURA_LINHA),
		Estilo.caixa(fundo, borda, 3 if pos <= 3 else 2, 22))
	var medalha = {1: "🥇 ", 2: "🥈 ", 3: "🥉 "}.get(pos, "")
	var nome = str(e.get("nome", "PLAYER")).strip_edges().to_upper().left(10)
	if nome == "":
		nome = "PLAYER"
	var x = 0.0
	x = _campo(l, medalha + str(pos), x, larg * COLUNAS[0][1], 46, Color.white, true)
	# foto: a do jogador (ou a silhueta), com a borda da cor da linha
	var w_foto = larg * COLUNAS[1][1]
	var lado = min(96.0, w_foto - 8.0)
	var foto = TextureRect.new()
	foto.texture = Estilo.tex("foto_vazia")
	foto.expand = true
	foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foto.rect_position = Vector2(x + (w_foto - lado) * 0.5, (ALTURA_LINHA - lado) * 0.5)
	foto.rect_size = Vector2(lado, lado)
	l.add_child(foto)
	var caminho = str(e.get("foto", ""))
	if caminho != "":
		_fotos_pendentes.append([foto, caminho])
	var mold = StyleBoxFlat.new()
	mold.draw_center = false
	mold.border_color = Color(borda.r, borda.g, borda.b, max(borda.a, 0.7))
	mold.set_border_width_all(3)
	mold.set_corner_radius_all(6)
	Estilo.painel(l, foto.rect_position - Vector2(3, 3), foto.rect_size + Vector2(6, 6), mold)
	x += w_foto
	x = _campo(l, nome, x, larg * COLUNAS[2][1], 52, Color.white, true)
	x = _campo(l, RankingManager.normalizar(str(e.get("cenario", ""))).left(8), x, larg * COLUNAS[3][1], 30, Color(0.82, 0.90, 1.0), false)
	x = _campo(l, Estilo.milhar(int(e.get("pontos", 0))), x, larg * COLUNAS[4][1], 56, cor_pontos, true)
	_campo(l, "%d%%" % int(e.get("precisao", 0)), x, larg * COLUNAS[5][1], 36, Color.white, false)


## Um campo da linha; a letra diminui só o necessário para caber na coluna.
func _campo(pai: Control, texto: String, x: float, larg: float, tam: int, cor: Color, forte: bool) -> float:
	while tam > 16 and Estilo.fonte(tam, forte, 7).get_string_size(texto).x > larg - 12.0:
		tam -= 2
	var l = Estilo.rotulo(pai, texto, tam, cor, 7, forte)
	l.clip_text = true
	Estilo.colocar(l, Vector2(x, 0), Vector2(larg, ALTURA_LINHA))
	return x + larg


func _lista_vazia() -> void:
	var p = Estilo.painel(_lista, Vector2(0, 0), Vector2(_lista_caixa.rect_size.x - 24, 300),
		Estilo.caixa(Color(0.08, 0.09, 0.13, 0.82), Color(1.0, 0.78, 0.18, 0.35), 2, 22))
	var t = Estilo.rotulo(p, "🏆 RANKING VAZIO\n\nJOGUE UMA PARTIDA E\nENTRE PARA O RANKING!", 40, Color.white, 7, false)
	Estilo.colocar(t, Vector2(20, 20), Vector2(p.rect_size.x - 40, 260))


func _rolar(passos: int) -> void:
	var max_rol = int(max(0, _linhas - _visiveis))
	_rolagem = int(clamp(_rolagem + passos, 0, max_rol))
	var tw = create_tween()
	tw.tween_property(_lista, "rect_position:y", -_rolagem * (ALTURA_LINHA + ESPACO_LINHA), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_atualizar_setas()


func _atualizar_setas() -> void:
	if vitrine:
		return
	var precisa = _linhas > _visiveis
	_subir.visible = precisa and _rolagem > 0
	_descer.visible = precisa and _rolagem < _linhas - _visiveis


# ------------------------------------------------------------ quadro e tiro
func _process(delta: float) -> void:
	if not _fotos_pendentes.empty():
		var par: Array = _fotos_pendentes.pop_front()
		if is_instance_valid(par[0]):
			var tex = FotoJogador.textura(par[1])
			if tex != null:
				par[0].texture = tex
	_t += delta
	if vitrine:
		if _t >= TEMPO_VITRINE and not _saindo:
			_ir(CENA_MENU)
		return
	var p = MiraGlobal.mira()
	var sob = Rect2(_painel.rect_position + _voltar.rect_position, _voltar.rect_size).grow(10.0).has_point(p)
	if sob != _voltar_mira:
		_voltar_mira = sob
		_voltar.add_stylebox_override("panel", _sb_voltar_mira if sob else _sb_voltar)
		var tw = create_tween()
		tw.tween_property(_voltar, "rect_scale", Vector2.ONE * (1.06 if sob else 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _input(ev: InputEvent) -> void:
	if _saindo:
		return
	if vitrine:
		if Maquina.e_start(ev):
			get_tree().set_input_as_handled()
			if Maquina.cobrar():
				Maquina.efeito(load("res://songs/init.wav"), 0.0)
				_ir(CENA_CENARIOS)
		return
	if Maquina.e_tiro(ev):
		get_tree().set_input_as_handled()
		_tiro(MiraGlobal.mira())


func _sob(c: Control, p: Vector2) -> bool:
	return c.visible and Rect2(_painel.rect_position + c.rect_position, c.rect_size).grow(8.0).has_point(p)


func _tiro(p: Vector2) -> void:
	Maquina.efeito(_som_tiro, -4.0, rand_range(0.96, 1.04))
	MiraGlobal.coice(0.5)
	_mira.pulso()
	_trajetoria.disparar(p, "menu")
	for i in FILTROS.size():
		if _sob(_botoes_filtro[i], p):
			_filtro = FILTROS[i]
			_pintar_filtros()
			_montar_lista_linhas()
			_pulo(_botoes_filtro[i])
			return
	if _sob(_subir, p):
		_pulo(_subir)
		_rolar(-4)
		return
	if _sob(_descer, p):
		_pulo(_descer)
		_rolar(4)
		return
	if _sob(_voltar, p):
		_pulo(_voltar)
		_ir(CENA_CENARIOS)


func _pulo(c: Control) -> void:
	c.rect_scale = Vector2(0.94, 0.94)
	var tw = create_tween()
	tw.tween_property(c, "rect_scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ir(caminho: String) -> void:
	if _saindo:
		return
	_saindo = true
	if _musica != null:
		var tw = create_tween()
		tw.tween_property(_musica, "volume_db", -40.0, 0.3)
	TransicaoGlobal.trocar_cena(caminho)
