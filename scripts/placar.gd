class_name Placar
extends CanvasLayer

## Placar único das quatro fases: uma faixa fina no topo (~5% da altura) que
## usa a largura da tela, para o fundo aparecer inteiro.
##
##   TEMPO | PONTOS | MUNIÇÃO (barra) | ACERTOS/TIROS | campo da fase
##
## A fase não muda o seu código de jogo: entrega uma função que devolve os
## valores ({"tempo", "pontos", "municao", "municao_max", "recarregando",
## "recarga", "acertos", "tiros", "extra_titulo", "extra", "extra_cor", "cor"})
## e a lista dos nós do placar antigo, que vão para um nó escondido (as
## variáveis da fase continuam apontando para eles, só não aparecem mais).
## O placar acompanha a visibilidade do HUD antigo (some no início e no fim
## da partida junto com ele) e só reescreve um texto quando o valor muda.

const FONTE := preload("res://fonts/Exo2-ExtraBold.ttf")
const FONTE_TITULO := preload("res://fonts/Exo2-Bold.ttf")

const ALTURA := 0.082          # da largura da tela
const MARGEM := 10.0
# largura de cada parte (soma 1)
const PARTES := [0.17, 0.25, 0.30, 0.14, 0.14]

var _fonte_dados: Callable
var _hud_antigo: Control = null
var _raiz: Control
var _painel: Panel
var _estilo: StyleBoxFlat
var _divisorias: Array[ColorRect] = []
var _titulos: Array[Label] = []
var _valores: Array[Label] = []
var _barra: Control
var _cor := Color(1, 0.2, 0.2)
var _dados: Dictionary = {}
var _antes: Dictionary = {}
var _t := 0.0
var _pulso_pontos := 0.0
var _pontos_antes := 0
var _vez := 0


## Liga o placar na fase. hud_antigo: o Control do HUD velho (o placar segue a
## visibilidade dele); esconder: nós do placar velho que saem de cena.
static func instalar(fase: Node, hud_antigo: Control, esconder: Array, fonte: Callable, camada: int = 80) -> Placar:
	var p := Placar.new()
	p.layer = camada
	p._fonte_dados = fonte
	p._hud_antigo = hud_antigo
	fase.add_child(p)
	if hud_antigo != null:
		var guarda := Control.new()
		guarda.name = "PlacarAntigo"
		guarda.visible = false
		guarda.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_antigo.add_child(guarda)
		for n in esconder:
			if n is Node and is_instance_valid(n) and (n as Node).get_parent() != null:
				(n as Node).reparent(guarda, false)
	return p


func _ready() -> void:
	_raiz = Control.new()
	_raiz.name = "Placar"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	_painel = Panel.new()
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_estilo = StyleBoxFlat.new()
	_estilo.bg_color = Color(0.015, 0.018, 0.03, 0.62)
	_estilo.set_border_width_all(2)
	_estilo.set_corner_radius_all(18)
	_estilo.shadow_size = 10
	_estilo.anti_aliasing = true
	Leve.stylebox(_painel, "panel", _estilo)
	_raiz.add_child(_painel)

	for i in PARTES.size():
		if i > 0:
			var d := ColorRect.new()
			d.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_raiz.add_child(d)
			_divisorias.append(d)
		var t := Label.new()
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Leve.font(t, "font", FONTE_TITULO)
		Leve.constant(t, "outline_size", 3)
		Leve.color(t, "font_outline_color", Color(0, 0, 0, 0.85))
		_raiz.add_child(t)
		_titulos.append(t)
		var v := Label.new()
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Leve.font(v, "font", FONTE)
		Leve.constant(v, "outline_size", 5)
		Leve.color(v, "font_outline_color", Color(0, 0, 0, 0.9))
		Leve.color(v, "font_color", Color.WHITE)
		_raiz.add_child(v)
		_valores.append(v)
	_titulos[0].text = "TEMPO"
	_titulos[1].text = "PONTOS"
	_titulos[3].text = "ACERTOS"

	_barra = Control.new()
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.draw.connect(_desenhar_barra)
	_raiz.add_child(_barra)

	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	_ler()
	_aplicar(true)


## Altura ocupada no topo (para quem quiser posicionar coisas logo abaixo).
func altura() -> float:
	return MARGEM + _painel.size.y


func _ajustar() -> void:
	var tela := get_viewport().get_visible_rect().size
	var h := roundf(tela.x * ALTURA)
	var larg := tela.x - MARGEM * 2.0
	_raiz.position = Vector2.ZERO
	_raiz.size = tela
	_painel.position = Vector2(MARGEM, MARGEM)
	_painel.size = Vector2(larg, h)
	var x := MARGEM
	var tam_titulo := int(h * 0.19)
	for i in PARTES.size():
		var w: float = larg * PARTES[i]
		if i > 0:
			var d := _divisorias[i - 1]
			d.position = Vector2(roundf(x) - 1.0, MARGEM + h * 0.18)
			d.size = Vector2(2.0, h * 0.64)
		_titulos[i].position = Vector2(x, MARGEM + h * 0.06)
		_titulos[i].size = Vector2(w, h * 0.30)
		Leve.font_size(_titulos[i], "font_size", tam_titulo)
		_valores[i].position = Vector2(x, MARGEM + h * 0.33)
		_valores[i].size = Vector2(w, h * 0.62)
		_valores[i].pivot_offset = _valores[i].size * 0.5
		var tam_valor := int(h * 0.47)
		if i == 1:
			tam_valor = int(h * 0.54)
		elif i >= 3:
			tam_valor = int(h * 0.40)
		Leve.font_size(_valores[i], "font_size", tam_valor)
		if i == 2:
			_barra.position = Vector2(x + w * 0.07, MARGEM + h * 0.46)
			_barra.size = Vector2(w * 0.86, h * 0.34)
		x += w
	_valores[2].visible = false
	_antes.clear()


func _process(delta: float) -> void:
	_t += delta
	var visivel := _hud_antigo == null or _hud_antigo.is_visible_in_tree()
	if _raiz.visible != visivel:
		_raiz.visible = visivel
	if not visivel:
		return
	_vez += 1
	if _vez % 2 == 0:
		_ler()
	_aplicar(false)


func _ler() -> void:
	if _fonte_dados.is_valid():
		_dados = _fonte_dados.call()


func _mudou(chave: String, valor: Variant) -> bool:
	if _antes.get(chave) == valor:
		return false
	_antes[chave] = valor
	return true


func _aplicar(forcar: bool) -> void:
	var cor: Color = _dados.get("cor", _cor)
	if forcar or _mudou("cor", cor):
		_cor = cor
		_estilo.border_color = Color(cor, 0.85)
		_estilo.shadow_color = Color(cor, 0.30)
		for d in _divisorias:
			d.color = Color(cor, 0.30)
		var clara := cor.lerp(Color.WHITE, 0.35)
		for t in _titulos:
			Leve.color(t, "font_color", clara)
		_antes.erase("municao")

	# tempo (vermelho e pulsando nos últimos 10 s)
	var tempo: float = maxf(0.0, float(_dados.get("tempo", 0.0)))
	var seg := int(ceil(tempo - 0.001)) if tempo > 0.0 else 0
	if _mudou("tempo", seg):
		_valores[0].text = "%02d:%02d" % [seg / 60, seg % 60]
	if seg <= 10 and tempo > 0.0:
		var k := 0.5 + 0.5 * sin(_t * 9.0)
		_valores[0].modulate = Color(1.0, 0.35 + 0.3 * k, 0.3 + 0.3 * k)
		_valores[0].scale = Vector2.ONE * (1.0 + 0.06 * k)
	elif _valores[0].scale != Vector2.ONE:
		_valores[0].modulate = Color.WHITE
		_valores[0].scale = Vector2.ONE

	# pontos: pulam quando sobem, piscam vermelho quando descem
	var pontos := int(_dados.get("pontos", 0))
	if _mudou("pontos", pontos):
		_valores[1].text = _milhar(pontos)
		if not forcar:
			_pulso_pontos = 1.0 if pontos >= _pontos_antes else -1.0
		_pontos_antes = pontos
	if _pulso_pontos != 0.0:
		var k := absf(_pulso_pontos)
		var base := Color(1.0, 0.86, 0.22) if pontos >= 0 else Color(1.0, 0.3, 0.3)
		var flash := Color(0.55, 1.0, 0.6) if _pulso_pontos > 0.0 else Color(1.0, 0.2, 0.2)
		_valores[1].modulate = base.lerp(flash, k)
		_valores[1].scale = Vector2.ONE * (1.0 + 0.16 * k)
		_pulso_pontos = signf(_pulso_pontos) * maxf(0.0, k - get_process_delta_time() * 3.5)
		if absf(_pulso_pontos) < 0.01:
			_pulso_pontos = 0.0
	elif forcar or _mudou("pontos_cor", pontos >= 0):
		_valores[1].modulate = Color(1.0, 0.86, 0.22) if pontos >= 0 else Color(1.0, 0.3, 0.3)
		_valores[1].scale = Vector2.ONE

	# munição: título com o número e a barra embaixo
	var bal := int(_dados.get("municao", 0))
	var maxb := maxi(1, int(_dados.get("municao_max", 30)))
	var rec := bool(_dados.get("recarregando", false))
	var estado := "recarga" if rec else ("vazia" if bal <= 0 else ("baixa" if bal <= maxi(3, maxb / 5) else "ok"))
	var texto := "MUNIÇÃO  %d/%d" % [bal, maxb]
	if estado == "recarga":
		texto = "RECARREGANDO"
	elif estado == "vazia":
		texto = "RECARREGUE!"
	if _mudou("municao_txt", texto):
		_titulos[2].text = texto
	if estado == "ok":
		if _mudou("municao_cor", 0):
			Leve.color(_titulos[2], "font_color", _cor.lerp(Color.WHITE, 0.35))
			_titulos[2].modulate = Color.WHITE
	else:
		_antes.erase("municao_cor")
		var piscar := 0.55 + 0.45 * absf(sin(_t * (6.0 if estado == "recarga" else 9.0)))
		var c := Color(0.35, 0.9, 1.0) if estado == "recarga" else (Color(1.0, 0.25, 0.2) if estado == "vazia" else Color(1.0, 0.65, 0.15))
		Leve.color(_titulos[2], "font_color", c)
		_titulos[2].modulate = Color(1, 1, 1, piscar)
	var chave_barra := [bal, maxb, estado, snappedf(float(_dados.get("recarga", 0.0)), 0.02)]
	if _mudou("municao", chave_barra) or estado != "ok":
		_barra.queue_redraw()

	# acertos / tiros
	var ac := int(_dados.get("acertos", 0))
	var ti := int(_dados.get("tiros", 0))
	if _mudou("acertos", Vector2i(ac, ti)):
		_valores[3].text = "%d/%d" % [ac, ti]

	# campo da fase (nível, modo, bombas...)
	var et := str(_dados.get("extra_titulo", ""))
	if _mudou("extra_titulo", et):
		_titulos[4].text = et
	var ev := str(_dados.get("extra", ""))
	if _mudou("extra", ev):
		_valores[4].text = ev
	var ec: Color = _dados.get("extra_cor", Color.WHITE)
	if _mudou("extra_cor", ec):
		Leve.color(_valores[4], "font_color", ec)


func _desenhar_barra() -> void:
	var bal := int(_dados.get("municao", 0))
	var maxb := maxi(1, int(_dados.get("municao_max", 30)))
	var rec := bool(_dados.get("recarregando", false))
	var prog := clampf(float(_dados.get("recarga", 0.0)), 0.0, 1.0)
	var tam := _barra.size
	var gap := 2.0
	var w := (tam.x - gap * (maxb - 1)) / maxb
	var baixa := bal <= maxi(3, maxb / 5)
	var piscar := 0.6 + 0.4 * absf(sin(_t * 9.0))
	_barra.draw_rect(Rect2(Vector2(-3, -3), tam + Vector2(6, 6)), Color(0, 0, 0, 0.45))
	for i in maxb:
		var r := Rect2(Vector2(i * (w + gap), 0.0), Vector2(w, tam.y))
		var cheio := i < bal
		var c: Color
		if rec:
			cheio = float(i) < prog * maxb
			c = Color(0.3, 0.9, 1.0, 0.95) if cheio else Color(0.12, 0.16, 0.2, 0.9)
		elif cheio:
			var k := float(i) / maxb
			c = (Color(1.0, 0.6, 0.12) if baixa else _cor.lerp(Color(1.0, 1.0, 1.0), 0.15 + 0.35 * k))
			if baixa:
				c.a = piscar
		else:
			c = Color(0.13, 0.13, 0.16, 0.9)
		_barra.draw_rect(r, c)
		if cheio:
			_barra.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.32)), Color(1, 1, 1, 0.28))


static func _milhar(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-" if n < 0 else "") + out
