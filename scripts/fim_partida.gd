extends CanvasLayer
class_name FimPartida

## RESULTADO DA PARTIDA (igual nas quatro fases): o cartão com o resultado,
## a contagem para voltar sozinho ao início, o botão VOLTAR AOS CENÁRIOS
## (um tiro nele) e o START para jogar de novo (a fase cuida do START).
## Sai o sinal `escolheu` com "cenarios" (botão) ou "menu" (tempo acabou).

signal escolheu(acao)

var ativo = false

var _cor = Color.white
var _raiz: Control
var _painel: Panel
var _titulo: Label
var _corpo: Label
var _contagem: Label
var _chamada: Label
var _botao: Panel
var _botao_txt: Label
var _rodape: Label
var _sb_botao: StyleBoxFlat
var _sb_botao_mira: StyleBoxFlat
var _restante = 17.0
var _t = 0.0
var _sob = false
var _trava = 0.0
var _foto: Control = null


static func criar(pai: Node, cor: Color) -> FimPartida:
	var f = load("res://scripts/fim_partida.gd").new()
	f._cor = cor
	f.layer = 140
	pai.add_child(f)
	return f


func _ready() -> void:
	visible = false
	set_process(false)
	_raiz = Control.new()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.rect_size = Tela.TELA
	add_child(_raiz)
	var escuro = ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.55)
	escuro.rect_size = Tela.TELA
	escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(escuro)
	var c = _cor
	var larg = 960.0
	_painel = Estilo.painel(_raiz, Vector2((Tela.TELA.x - larg) * 0.5, 470.0), Vector2(larg, 860.0),
		Estilo.caixa(Color(0.035, 0.03, 0.03, 0.95), Color(c.r, c.g, c.b, 0.9), 4, 32, 30, Color(c.r, c.g, c.b, 0.45)))
	_painel.rect_pivot_offset = _painel.rect_size * 0.5
	_titulo = Estilo.rotulo(_painel, "FIM DE JOGO", 68, c.linear_interpolate(Color.white, 0.2), 6)
	Estilo.colocar(_titulo, Vector2(0, 28), Vector2(larg, 100))
	var linha = ColorRect.new()
	linha.color = Color(c.r, c.g, c.b, 0.8)
	linha.rect_position = Vector2(0, 140)
	linha.rect_size = Vector2(larg, 3)
	_painel.add_child(linha)
	_corpo = Estilo.rotulo(_painel, "", 36, Color(1, 1, 1, 0.92), 3, false)
	_corpo.autowrap = true
	Estilo.colocar(_corpo, Vector2(40, 170), Vector2(larg - 80, 520))
	_contagem = Estilo.rotulo(_painel, "", 36, c.linear_interpolate(Color.white, 0.25), 3)
	Estilo.colocar(_contagem, Vector2(0, 716), Vector2(larg, 50))
	_chamada = Estilo.rotulo(_painel, "", 30, Color(1.0, 0.88, 0.35), 3)
	Estilo.colocar(_chamada, Vector2(0, 768), Vector2(larg, 46))
	_sb_botao = Estilo.caixa(Color(0.02, 0.02, 0.02, 0.92), Color(1, 1, 1, 0.9), 4, 26, 18, Color(c.r, c.g, c.b, 0.55))
	_sb_botao_mira = Estilo.caixa(Color(c.r * 0.5, c.g * 0.5, c.b * 0.5, 0.95), Color.white, 5, 26, 26, Color(c.r, c.g, c.b, 0.9))
	_botao = Estilo.painel(_raiz, Vector2(222, 1520), Vector2(580, 120), _sb_botao)
	_botao.rect_pivot_offset = _botao.rect_size * 0.5
	_botao_txt = Estilo.rotulo(_botao, "VOLTAR AOS CENÁRIOS", 48, Color.white, 4)
	Estilo.colocar(_botao_txt, Vector2.ZERO, _botao.rect_size)
	_rodape = Estilo.rotulo(_raiz, "RANKING: SÓ ACIMA DE 4.000 PONTOS", 30, Color(1.0, 0.86, 0.36), 3)
	Estilo.colocar(_rodape, Vector2(0, 1652), Vector2(1024, 46))


## dados: pontos, tiros, acertos, erros, precisao, melhor_combo; opcionais:
## titulo, recorde (nome salvo no ranking).
func mostrar(d: Dictionary) -> void:
	var precisao = int(d.get("precisao", 0))
	var desempenho = "TREINE MAIS"
	if precisao >= 80:
		desempenho = "EXCELENTE"
	elif precisao >= 60:
		desempenho = "MUITO BOM"
	elif precisao >= 40:
		desempenho = "BOM"
	var texto = "RESULTADO FINAL\n\nPONTUAÇÃO: %s\nTIROS: %d\nACERTOS: %d\nERROS: %d\nACERTO: %d%%\nMELHOR SEQUÊNCIA: x%d\nDESEMPENHO: %s" % [
		Estilo.milhar(int(d.get("pontos", 0))), int(d.get("tiros", 0)), int(d.get("acertos", 0)), int(d.get("erros", 0)),
		precisao, int(d.get("melhor_combo", 0)), desempenho]
	if str(d.get("recorde", "")) != "":
		texto += "\n\n🏆 RECORDE SALVO COMO: %s" % d["recorde"]
		_titulo.text = "RECORDE SALVO!"
	else:
		_titulo.text = str(d.get("titulo", "FIM DE JOGO"))
	_corpo.text = texto
	_chamada.text = Maquina.texto_jogar_novamente()
	# a foto do jogador (webcam) em cima do cartão
	if _foto != null:
		_foto.queue_free()
		_foto = null
	if FotoJogador.ultima_textura != null:
		_foto = FotoJogador.moldura(_raiz, Vector2(Tela.TELA.x * 0.5, 240.0), 240.0, FotoJogador.ultima_textura, 3.0, "VOCÊ JOGOU!")
	_restante = Maquina.tempo_volta_menu()
	_t = 0.0
	_trava = 0.5
	ativo = true
	visible = true
	_raiz.modulate.a = 0.0
	_painel.rect_scale = Vector2(0.9, 0.9)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_raiz, "modulate:a", 1.0, 0.25)
	tw.tween_property(_painel, "rect_scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	set_process(true)


func _no_botao(p: Vector2) -> bool:
	return Rect2(_botao.rect_position, _botao.rect_size).grow(10.0).has_point(p)


## Tiro na tela de resultado: true se pegou o botão.
func tiro(p: Vector2) -> bool:
	if not ativo or _trava > 0.0 or not _no_botao(p):
		return false
	_botao.rect_scale = Vector2(0.92, 0.92)
	ativo = false
	set_process(false)
	emit_signal("escolheu", "cenarios")
	return true


func _process(delta: float) -> void:
	_t += delta
	_trava = max(0.0, _trava - delta)
	_restante -= delta
	_contagem.text = "VOLTANDO AO INÍCIO EM %02d" % int(ceil(max(0.0, _restante)))
	_contagem.modulate.a = 0.72 + abs(sin(_t * 4.0)) * 0.28
	var sob = _no_botao(MiraGlobal.mira())
	if sob != _sob:
		_sob = sob
		_botao.add_stylebox_override("panel", _sb_botao_mira if sob else _sb_botao)
		_botao.rect_scale = Vector2.ONE * (1.05 if sob else 1.0)
	if _restante <= 0.0:
		ativo = false
		set_process(false)
		emit_signal("escolheu", "menu")
