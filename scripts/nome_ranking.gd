class_name NomeRanking
extends CanvasLayer

## Tela de nome do recorde, igual em todas as fases.
##
## A fase cria com NomeRanking.new(), põe na árvore, chama abrir() quando o
## jogador entra no ranking, passa a mira a cada quadro (mira()) e os tiros
## (tiro()). Quando o nome fica pronto (SALVAR, 9 letras + SALVAR, ou o tempo
## acabar) sai o sinal `confirmado` com o nome ("ANONIMO" se ficou vazio).
##
## Liso na TV Box: tudo é criado uma vez só; ao mirar só troca o estilo da
## tecla que mudou; letras entram com um "estalo" curto; nada é recriado.

signal confirmado(nome: String)

const MAX_LETRAS := 9
const LETRAS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const COLUNAS := 9
const TRAVA_TIRO := 0.12
const FONTE_TITULO := "res://fonts/Exo2-ExtraBold.ttf"

var ativo := false
var nome := ""

var _cor := Color(1.0, 0.80, 0.22)
var _tempo_total := 50.0
var _restante := 0.0
var _trava := 0.0
var _t := 0.0

var _raiz: Control
var _fundo: ColorRect
var _painel: Panel
var _titulo: Label
var _sub: Label
var _placar: Label
var _casas: Array[Panel] = []
var _casas_letra: Array[Label] = []
var _teclas: Array[Panel] = []         # 26 letras + APAGAR + SALVAR
var _rotulos: Array[Label] = []
var _valores: Array[String] = []        # letra, "<" (apagar) ou "OK"
var _tempo_rotulo: Label
var _tempo_barra_fundo: Panel
var _tempo_barra: Panel

var _sb_tecla: StyleBoxFlat
var _sb_tecla_mira: StyleBoxFlat
var _sb_acao: StyleBoxFlat
var _sb_ok: StyleBoxFlat
var _sb_casa: StyleBoxFlat
var _sb_casa_atual: StyleBoxFlat
var _sob_mira := -1


func _ready() -> void:
	layer = 150
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	set_process(false)


## Abre a tela. `cor` = cor de destaque da fase.
func abrir(cor: Color, pontos: int = -1, precisao: int = -1) -> void:
	_cor = cor
	_tempo_total = float(Maquina.valor("ranking/tempo_nome")) if Maquina != null else 50.0
	_tempo_total = clampf(_tempo_total, 10.0, 180.0)
	_restante = _tempo_total
	nome = ""
	_trava = 0.25   # o tiro que terminou a partida não vira letra
	_t = 0.0
	_sob_mira = -1
	_aplicar_cores()
	_placar.text = ""
	if pontos >= 0:
		_placar.text = "%s PONTOS" % _milhar(pontos)
		if precisao >= 0:
			_placar.text += "   ·   ACERTO %d%%" % precisao
	_layout()
	_atualizar_casas()
	_atualizar_tempo()
	for i in range(_teclas.size()):
		_teclas[i].add_theme_stylebox_override("panel", _estilo_tecla(i, false))
		_teclas[i].scale = Vector2.ONE

	ativo = true
	visible = true
	set_process(true)
	_raiz.modulate.a = 0.0
	_painel.scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_raiz, "modulate:a", 1.0, 0.20)
	tw.tween_property(_painel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func fechar() -> void:
	ativo = false
	set_process(false)
	visible = false


## Posição da mira (coordenadas da tela). Só mexe no estilo se a tecla mudou.
func mira(pos: Vector2) -> void:
	if not ativo:
		return
	var i := _tecla_em(pos)
	if i == _sob_mira:
		return
	if _sob_mira >= 0:
		_teclas[_sob_mira].add_theme_stylebox_override("panel", _estilo_tecla(_sob_mira, false))
		_rotulos[_sob_mira].add_theme_color_override("font_color", _cor_rotulo(_sob_mira, false))
	_sob_mira = i
	if i >= 0:
		_teclas[i].add_theme_stylebox_override("panel", _estilo_tecla(i, true))
		_rotulos[i].add_theme_color_override("font_color", _cor_rotulo(i, true))


## Tiro na posição. Devolve true se acertou uma tecla.
func tiro(pos: Vector2) -> bool:
	if not ativo or _trava > 0.0:
		return false
	var i := _tecla_em(pos)
	if i < 0:
		return false
	_trava = TRAVA_TIRO
	_apertar(i)
	var v := _valores[i]
	if v == "OK":
		_confirmar()
	elif v == "<":
		if nome.length() > 0:
			nome = nome.substr(0, nome.length() - 1)
			_atualizar_casas()
	elif nome.length() < MAX_LETRAS:
		nome += v
		_atualizar_casas()
		_estalar(_casas_letra[nome.length() - 1])
	return true


func _process(delta: float) -> void:
	_t += delta
	_trava = maxf(0.0, _trava - delta)
	_restante = maxf(0.0, _restante - delta)
	_atualizar_tempo()
	# cursor piscando na próxima casa
	if nome.length() < MAX_LETRAS:
		var c := _casas[nome.length()]
		c.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 7.0))
	if _restante <= 0.0:
		_confirmar()


func _confirmar() -> void:
	if not ativo:
		return
	var final := nome.strip_edges()
	if final == "":
		final = "ANONIMO"
	fechar()
	confirmado.emit(final)


# ------------------------------------------------------------------ visual

func _montar() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	_fundo = ColorRect.new()
	_fundo.color = Color(0, 0, 0, 0.80)
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_fundo)

	_painel = Panel.new()
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_painel)

	_titulo = _rotulo(_painel, 56, Color.WHITE, 8)
	_titulo.text = "🏆 NOVO RECORDE!"
	if ResourceLoader.exists(FONTE_TITULO):
		_titulo.add_theme_font_override("font", load(FONTE_TITULO))
	_placar = _rotulo(_painel, 30, Color(1, 1, 1, 0.92), 5)
	_sub = _rotulo(_painel, 26, Color(0.82, 0.86, 0.92), 4)
	_sub.text = "ATIRE NAS LETRAS PARA ESCREVER SEU NOME"

	for k in range(MAX_LETRAS):
		var casa := Panel.new()
		casa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_painel.add_child(casa)
		var l := _rotulo(casa, 54, Color.WHITE, 6)
		if ResourceLoader.exists(FONTE_TITULO):
			l.add_theme_font_override("font", load(FONTE_TITULO))
		_casas.append(casa)
		_casas_letra.append(l)

	for k in range(LETRAS.length()):
		_nova_tecla(LETRAS.substr(k, 1), LETRAS.substr(k, 1))
	_nova_tecla("⌫  APAGAR", "<")
	_nova_tecla("✔  SALVAR", "OK")

	_tempo_rotulo = _rotulo(_painel, 26, Color(1, 1, 1, 0.85), 4)
	_tempo_barra_fundo = Panel.new()
	_tempo_barra_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(_tempo_barra_fundo)
	_tempo_barra = Panel.new()
	_tempo_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tempo_barra_fundo.add_child(_tempo_barra)


func _nova_tecla(texto: String, valor: String) -> void:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(p)
	var l := _rotulo(p, 34 if valor.length() == 1 else 28, Color.WHITE, 0)
	l.text = texto
	_teclas.append(p)
	_rotulos.append(l)
	_valores.append(valor)


func _rotulo(pai: Control, tamanho: int, cor: Color, contorno: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	if contorno > 0:
		l.add_theme_constant_override("outline_size", contorno)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	pai.add_child(l)
	return l


func _caixa(fundo: Color, borda: Color, largura: int, raio: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fundo
	sb.border_color = borda
	sb.set_border_width_all(largura)
	sb.set_corner_radius_all(raio)
	sb.anti_aliasing = true
	return sb


func _aplicar_cores() -> void:
	var escuro := Color(0.03, 0.035, 0.05, 0.97)
	var sb_painel := _caixa(escuro, _cor, 4, 30)
	sb_painel.shadow_color = Color(_cor.r, _cor.g, _cor.b, 0.35)
	sb_painel.shadow_size = 26
	_painel.add_theme_stylebox_override("panel", sb_painel)
	_titulo.add_theme_color_override("font_color", _cor.lerp(Color.WHITE, 0.25))

	_sb_tecla = _caixa(Color(_cor.r * 0.16, _cor.g * 0.16, _cor.b * 0.16, 0.95), Color(_cor.r, _cor.g, _cor.b, 0.75), 2, 14)
	_sb_tecla_mira = _caixa(_cor, _cor.lerp(Color.WHITE, 0.5), 3, 14)
	_sb_tecla_mira.shadow_color = Color(_cor.r, _cor.g, _cor.b, 0.55)
	_sb_tecla_mira.shadow_size = 12
	_sb_acao = _caixa(Color(0.10, 0.10, 0.12, 0.95), Color(1, 1, 1, 0.45), 2, 16)
	_sb_ok = _caixa(Color(_cor.r * 0.30, _cor.g * 0.30, _cor.b * 0.30, 0.95), _cor, 3, 16)
	_sb_casa = _caixa(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.22), 2, 10)
	_sb_casa_atual = _caixa(Color(_cor.r, _cor.g, _cor.b, 0.12), _cor, 3, 10)

	_tempo_barra_fundo.add_theme_stylebox_override("panel", _caixa(Color(1, 1, 1, 0.10), Color.TRANSPARENT, 0, 6))
	_tempo_barra.add_theme_stylebox_override("panel", _caixa(_cor, Color.TRANSPARENT, 0, 6))


func _estilo_tecla(i: int, sob_mira: bool) -> StyleBoxFlat:
	if sob_mira:
		return _sb_tecla_mira
	match _valores[i]:
		"OK":
			return _sb_ok
		"<":
			return _sb_acao
	return _sb_tecla


func _cor_rotulo(_i: int, sob_mira: bool) -> Color:
	return Color(0.05, 0.05, 0.06) if sob_mira else Color.WHITE


func _layout() -> void:
	var tela := _raiz.get_viewport_rect().size
	var pw := minf(980.0, tela.x - 48.0)
	var ph := 860.0
	_painel.size = Vector2(pw, ph)
	_painel.position = ((tela - _painel.size) * 0.5).round()
	_painel.pivot_offset = _painel.size * 0.5

	var y := 26.0
	_titulo.position = Vector2(0, y); _titulo.size = Vector2(pw, 70); y += 72
	_placar.position = Vector2(0, y); _placar.size = Vector2(pw, 40); y += 44
	_sub.position = Vector2(0, y); _sub.size = Vector2(pw, 36); y += 54

	# casas do nome
	var gap := 10.0
	var cw := minf(78.0, (pw - 80.0 - gap * (MAX_LETRAS - 1)) / MAX_LETRAS)
	var ch := cw * 1.18
	var x0 := (pw - (cw * MAX_LETRAS + gap * (MAX_LETRAS - 1))) * 0.5
	for k in range(MAX_LETRAS):
		_casas[k].position = Vector2(x0 + k * (cw + gap), y)
		_casas[k].size = Vector2(cw, ch)
		_casas_letra[k].position = Vector2.ZERO
		_casas_letra[k].size = _casas[k].size
		_casas_letra[k].pivot_offset = _casas[k].size * 0.5
	y += ch + 34

	# teclado: 3 linhas de 9
	var kg := 10.0
	var kw := (pw - 60.0 - kg * (COLUNAS - 1)) / COLUNAS
	var kh := minf(86.0, kw * 0.95)
	var kx := (pw - (kw * COLUNAS + kg * (COLUNAS - 1))) * 0.5
	for k in range(LETRAS.length()):
		var col := k % COLUNAS
		var lin := k / COLUNAS
		_por_tecla(k, Vector2(kx + col * (kw + kg), y + lin * (kh + kg)), Vector2(kw, kh))
	y += 3 * (kh + kg) + 18

	var aw := (pw - 60.0 - 24.0) * 0.5
	_por_tecla(LETRAS.length(), Vector2(30, y), Vector2(aw, 78))
	_por_tecla(LETRAS.length() + 1, Vector2(30 + aw + 24, y), Vector2(aw, 78))
	y += 78 + 26

	_tempo_rotulo.position = Vector2(0, y); _tempo_rotulo.size = Vector2(pw, 34); y += 40
	_tempo_barra_fundo.position = Vector2(60, y); _tempo_barra_fundo.size = Vector2(pw - 120, 10)
	_tempo_barra.position = Vector2.ZERO
	y += 30
	_painel.size.y = y
	_painel.position = ((tela - _painel.size) * 0.5).round()
	_painel.pivot_offset = _painel.size * 0.5


func _por_tecla(i: int, pos: Vector2, tam: Vector2) -> void:
	_teclas[i].position = pos.round()
	_teclas[i].size = tam.round()
	_teclas[i].pivot_offset = tam * 0.5
	_rotulos[i].position = Vector2.ZERO
	_rotulos[i].size = _teclas[i].size
	_rotulos[i].add_theme_color_override("font_color", Color.WHITE)


func _tecla_em(pos: Vector2) -> int:
	for i in range(_teclas.size()):
		if _teclas[i].get_global_rect().grow(4.0).has_point(pos):
			return i
	return -1


func _atualizar_casas() -> void:
	for k in range(MAX_LETRAS):
		_casas_letra[k].text = nome.substr(k, 1) if k < nome.length() else ""
		var atual := k == nome.length()
		_casas[k].add_theme_stylebox_override("panel", _sb_casa_atual if atual else _sb_casa)
		_casas[k].modulate.a = 1.0


func _atualizar_tempo() -> void:
	var s := int(ceil(_restante))
	var texto := "SALVA SOZINHO EM %d s" % s
	if _tempo_rotulo.text != texto:
		_tempo_rotulo.text = texto
	_tempo_barra.size = Vector2(_tempo_barra_fundo.size.x * (_restante / maxf(_tempo_total, 0.01)), _tempo_barra_fundo.size.y)


func _apertar(i: int) -> void:
	var p := _teclas[i]
	p.scale = Vector2(0.90, 0.90)
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _estalar(l: Label) -> void:
	l.scale = Vector2(1.45, 1.45)
	l.modulate = Color(1.6, 1.6, 1.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate", Color.WHITE, 0.22)


static func _milhar(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
