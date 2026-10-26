extends CanvasLayer
class_name NomeRanking

## Tela de nome do recorde, igual em todas as fases: o jogador atira nas
## letras (teclado na tela), APAGAR e SALVAR; com 9 letras ou com o tempo
## acabando, salva sozinho. Sai o sinal `confirmado` com o nome ("ANONIMO" se
## ficou vazio). Tudo é montado uma vez; ao mirar só troca o estilo da tecla
## sob a mira; a letra entra com um estalo curto.

signal confirmado(nome)

const MAX_LETRAS = 9
const LETRAS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const COLUNAS = 9
const TRAVA_TIRO = 0.12

var _foto: Control = null
var ativo = false
var nome = ""

var _cor = Color(1.0, 0.80, 0.22)
var _tempo_total = 50.0
var _restante = 0.0
var _trava = 0.0
var _t = 0.0

var _raiz: Control
var _painel: Panel
var _titulo: Label
var _placar: Label
var _casas = []
var _casas_letra = []
var _teclas = []
var _rotulos = []
var _valores = []
var _tempo_rotulo: Label
var _barra_fundo: Panel
var _barra: Panel
var _sb = {}
var _sob_mira = -1
var _som_tecla: AudioStream


static func criar(pai: Node) -> NomeRanking:
	var n = load("res://scripts/nome_ranking.gd").new()
	n.layer = 150
	pai.add_child(n)
	return n


func _ready() -> void:
	visible = false
	_som_tecla = load("res://songs/choice.wav")
	_montar()
	set_process(false)


func abrir(cor: Color, pontos: int, precisao: int) -> void:
	_cor = cor
	_tempo_total = clamp(float(Maquina.valor("ranking/tempo_nome")), 10.0, 180.0)
	_restante = _tempo_total
	nome = ""
	_trava = 0.3
	_t = 0.0
	_sob_mira = -1
	_aplicar_cores()
	_placar.text = "%s PONTOS  ·  ACERTO %d%%" % [Estilo.milhar(pontos), precisao]
	_atualizar_casas()
	if _foto != null:
		_foto.queue_free()
		_foto = null
	if FotoJogador.ultima_textura != null:
		_foto = FotoJogador.moldura(_raiz, Vector2(Tela.TELA.x * 0.5, 250.0), 250.0, FotoJogador.ultima_textura, -4.0, "SEU RECORDE")
	ativo = true
	visible = true
	_painel.rect_scale = Vector2(0.92, 0.92)
	_raiz.modulate.a = 0.0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_raiz, "modulate:a", 1.0, 0.2)
	tw.tween_property(_painel, "rect_scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	set_process(true)


func fechar() -> void:
	ativo = false
	visible = false
	set_process(false)


func _montar() -> void:
	_raiz = Control.new()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.rect_size = Tela.TELA
	add_child(_raiz)
	var escuro = ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.62)
	escuro.rect_size = Tela.TELA
	escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(escuro)
	var larg = 960.0
	var alto = 820.0
	_painel = Estilo.painel(_raiz, Vector2((Tela.TELA.x - larg) * 0.5, 480.0), Vector2(larg, alto), StyleBoxFlat.new())
	_painel.rect_pivot_offset = Vector2(larg, alto) * 0.5
	_titulo = Estilo.rotulo(_painel, "🏆 NOVO RECORDE!", 62, Color.white, 6)
	Estilo.colocar(_titulo, Vector2(0, 26), Vector2(larg, 80))
	_placar = Estilo.rotulo(_painel, "", 34, Color.white, 3)
	Estilo.colocar(_placar, Vector2(0, 104), Vector2(larg, 46))
	var dica = Estilo.rotulo(_painel, "ATIRE NAS LETRAS PARA ESCREVER SEU NOME", 28, Color(1, 1, 1, 0.8), 0, false)
	Estilo.colocar(dica, Vector2(0, 152), Vector2(larg, 40))
	# as casas do nome
	var cw = 82.0
	var x0 = (larg - (cw * MAX_LETRAS + 10.0 * (MAX_LETRAS - 1))) * 0.5
	for i in MAX_LETRAS:
		var c = Estilo.painel(_painel, Vector2(x0 + i * (cw + 10.0), 206), Vector2(cw, 90), StyleBoxFlat.new())
		var l = Estilo.rotulo(c, "", 56, Color.white, 4)
		Estilo.colocar(l, Vector2.ZERO, Vector2(cw, 90))
		_casas.append(c)
		_casas_letra.append(l)
	# o teclado: 3 linhas de 9 letras (26 + um espaço vazio), APAGAR e SALVAR
	var tw_ = 96.0
	var th = 86.0
	var gx = 10.0
	var kx0 = (larg - (tw_ * COLUNAS + gx * (COLUNAS - 1))) * 0.5
	for i in LETRAS.length():
		var col = i % COLUNAS
		var lin = i / COLUNAS
		_nova_tecla(LETRAS[i], LETRAS[i], Vector2(kx0 + col * (tw_ + gx), 330 + lin * (th + 10.0)), Vector2(tw_, th), 46)
	var y_acoes = 330 + 3 * (th + 10.0) + 14.0
	var lw = (larg - 100.0) * 0.5
	_nova_tecla("⌫ APAGAR", "<", Vector2(40, y_acoes), Vector2(lw, 84), 36)
	_nova_tecla("✔ SALVAR", "OK", Vector2(60 + lw, y_acoes), Vector2(lw, 84), 36)
	_tempo_rotulo = Estilo.rotulo(_painel, "", 28, Color(1, 1, 1, 0.85), 0, false)
	Estilo.colocar(_tempo_rotulo, Vector2(0, y_acoes + 96), Vector2(larg, 36))
	_barra_fundo = Estilo.painel(_painel, Vector2(70, y_acoes + 138), Vector2(larg - 140, 12), Estilo.caixa(Color(1, 1, 1, 0.15), Color(0, 0, 0, 0), 0, 6))
	_barra = Estilo.painel(_painel, Vector2(70, y_acoes + 138), Vector2(larg - 140, 12), Estilo.caixa(Color.white, Color(0, 0, 0, 0), 0, 6))
	for f in [Estilo.fonte(46), Estilo.fonte(56, true, 4), Estilo.fonte(36)]:
		Estilo.aquecer_fonte(f, LETRAS + "⌫✔ APGRSLV")


func _nova_tecla(texto: String, valor: String, pos: Vector2, tam: Vector2, fonte: int) -> void:
	var p = Estilo.painel(_painel, pos, tam, StyleBoxFlat.new())
	var l = Estilo.rotulo(p, texto, fonte, Color.white, 0)
	Estilo.colocar(l, Vector2.ZERO, tam)
	_teclas.append(p)
	_rotulos.append(l)
	_valores.append(valor)


func _aplicar_cores() -> void:
	var c = _cor
	_painel.add_stylebox_override("panel", Estilo.caixa(Color(0.04, 0.035, 0.03, 0.97), c, 4, 24, 28, Color(c.r, c.g, c.b, 0.45)))
	_titulo.add_color_override("font_color", c.linear_interpolate(Color.white, 0.15))
	_sb["tecla"] = Estilo.caixa(Color(0.10, 0.08, 0.05, 1.0), Color(c.r, c.g, c.b, 0.55), 2, 12)
	_sb["mira"] = Estilo.caixa(c, Color.white, 3, 12, 12, Color(c.r, c.g, c.b, 0.6))
	_sb["acao"] = Estilo.caixa(Color(0.14, 0.14, 0.16, 1.0), Color(1, 1, 1, 0.3), 2, 14)
	_sb["ok"] = Estilo.caixa(Color(c.r * 0.35, c.g * 0.35, c.b * 0.35, 1.0), c, 3, 14)
	_sb["casa"] = Estilo.caixa(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.18), 2, 10)
	_sb["casa_atual"] = Estilo.caixa(Color(c.r, c.g, c.b, 0.18), c, 3, 10)
	_barra.add_stylebox_override("panel", Estilo.caixa(c, Color(0, 0, 0, 0), 0, 6))
	for i in _teclas.size():
		_teclas[i].add_stylebox_override("panel", _estilo_tecla(i, false))
		_rotulos[i].add_color_override("font_color", Color.white)


func _estilo_tecla(i: int, mira: bool) -> StyleBox:
	if mira:
		return _sb["mira"]
	if _valores[i] == "OK":
		return _sb["ok"]
	if _valores[i] == "<":
		return _sb["acao"]
	return _sb["tecla"]


func _tecla_em(p: Vector2) -> int:
	var local = p - _painel.rect_position
	for i in _teclas.size():
		var t: Panel = _teclas[i]
		if Rect2(t.rect_position, t.rect_size).grow(4.0).has_point(local):
			return i
	return -1


## A mira passa por cima: destaca a tecla.
func mira(p: Vector2) -> void:
	if not ativo:
		return
	var i = _tecla_em(p)
	if i == _sob_mira:
		return
	if _sob_mira >= 0:
		_teclas[_sob_mira].add_stylebox_override("panel", _estilo_tecla(_sob_mira, false))
	_sob_mira = i
	if i >= 0:
		_teclas[i].add_stylebox_override("panel", _estilo_tecla(i, true))


## Tiro: true se acertou uma tecla.
func tiro(p: Vector2) -> bool:
	if not ativo or _trava > 0.0:
		return false
	var i = _tecla_em(p)
	if i < 0:
		return false
	_trava = TRAVA_TIRO
	_apertar(i)
	return true


func _apertar(i: int) -> void:
	var v: String = _valores[i]
	Maquina.efeito(_som_tecla, -6.0, 1.1 if v == "OK" else 1.0)
	var t: Panel = _teclas[i]
	t.rect_pivot_offset = t.rect_size * 0.5
	t.rect_scale = Vector2(0.88, 0.88)
	var tw = create_tween()
	tw.tween_property(t, "rect_scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if v == "OK":
		_confirmar()
		return
	if v == "<":
		if nome.length() > 0:
			nome = nome.substr(0, nome.length() - 1)
	elif nome.length() < MAX_LETRAS:
		nome += v
		var l: Label = _casas_letra[nome.length() - 1]
		l.rect_scale = Vector2(1.5, 1.5)
		var tw2 = create_tween()
		tw2.tween_property(l, "rect_scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_atualizar_casas()


func _atualizar_casas() -> void:
	for i in MAX_LETRAS:
		_casas_letra[i].text = nome[i] if i < nome.length() else ""
		_casas[i].add_stylebox_override("panel", _sb["casa_atual"] if i == nome.length() else _sb["casa"])


func _confirmar() -> void:
	if not ativo:
		return
	var n = nome.strip_edges()
	if n == "":
		n = "ANONIMO"
	fechar()
	emit_signal("confirmado", n)


func _process(delta: float) -> void:
	_t += delta
	_trava = max(0.0, _trava - delta)
	_restante -= delta
	if _restante <= 0.0:
		_confirmar()
		return
	_tempo_rotulo.text = "SALVA SOZINHO EM %d s" % int(ceil(_restante))
	_barra.rect_size.x = (_barra_fundo.rect_size.x) * clamp(_restante / _tempo_total, 0.0, 1.0)
	mira(MiraGlobal.mira())
