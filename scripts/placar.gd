extends CanvasLayer
class_name Placar

## Placar único das quatro fases: uma faixa no topo (~6% da altura), letras
## grandes (lidas de longe, com a arma na mão), o fundo aparecendo inteiro.
##
##   TEMPO | PONTOS | MUNIÇÃO (as balas) | ACERTOS/TIROS | campo da fase
##
## A munição são os próprios cartuchos (sprites/hud_bala.png), em duas
## fileiras: os gastos ficam escuros, na recarga eles voltam um a um, e no
## fim piscam (laranja com pouca bala, vermelho vazio). Sem escrever nada.
##
## A fase entrega uma função (funcref) que devolve os valores:
##   {"tempo", "pontos", "municao", "municao_max", "recarregando", "recarga",
##    "acertos", "tiros", "extra_titulo", "extra", "extra_cor"}
## Os textos só são reescritos quando o valor muda; as balas só são
## redesenhadas quando a munição muda (ou pisca).

const ALTURA = 111.0
const MARGEM = 10.0
const PARTES = [0.17, 0.25, 0.30, 0.14, 0.14]

var _fonte: FuncRef
var _cor = Color.white
var _raiz: Control
var _painel: Panel
var _estilo: StyleBoxFlat
var _divisorias = []
var _titulos = []
var _valores = []
var _barra: Control
var _t_bala: Texture
var _dados = {}
var _antes = {}
var _t = 0.0
var _pulso_pontos = 0.0
var _pontos_antes = 0
var _vez = 0
var _anima = false


static func criar(pai: Node, fonte: FuncRef, cor: Color, camada: int = 50) -> Placar:
	var p = load("res://scripts/placar.gd").new()
	p.layer = camada
	p._fonte = fonte
	p._cor = cor
	pai.add_child(p)
	return p


func _ready() -> void:
	_raiz = Control.new()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.rect_size = Tela.TELA
	add_child(_raiz)
	_estilo = Estilo.caixa(Color(0.015, 0.018, 0.03, 0.62), Color(_cor.r, _cor.g, _cor.b, 0.85), 2, 18, 10, Color(_cor.r, _cor.g, _cor.b, 0.30))
	_painel = Estilo.painel(_raiz, Vector2(MARGEM, MARGEM), Vector2(Tela.TELA.x - MARGEM * 2.0, ALTURA), _estilo)
	var clara = _cor.linear_interpolate(Color.white, 0.35)
	var larg = Tela.TELA.x - MARGEM * 2.0
	var x = MARGEM
	for i in PARTES.size():
		var w: float = larg * PARTES[i]
		if i > 0:
			var d = ColorRect.new()
			d.mouse_filter = Control.MOUSE_FILTER_IGNORE
			d.color = Color(_cor.r, _cor.g, _cor.b, 0.30)
			d.rect_position = Vector2(round(x) - 1.0, MARGEM + ALTURA * 0.18)
			d.rect_size = Vector2(2.0, ALTURA * 0.64)
			_raiz.add_child(d)
			_divisorias.append(d)
		var t = Estilo.rotulo(_raiz, "", 22, clara, 3, false)
		Estilo.colocar(t, Vector2(x, MARGEM + ALTURA * 0.05), Vector2(w, ALTURA * 0.30))
		_titulos.append(t)
		var tam = 52
		if i == 1:
			tam = 60
		elif i >= 3:
			tam = 44
		var v = Estilo.rotulo(_raiz, "", tam, Color.white, 5)
		Estilo.colocar(v, Vector2(x, MARGEM + ALTURA * 0.31), Vector2(w, ALTURA * 0.64))
		_valores.append(v)
		if i == 2:
			_barra = Control.new()
			_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_barra.rect_position = Vector2(x + w * 0.05, MARGEM + ALTURA * 0.10)
			_barra.rect_size = Vector2(w * 0.90, ALTURA * 0.80)
			_barra.connect("draw", self, "_desenhar_balas")
			_raiz.add_child(_barra)
		x += w
	_titulos[0].text = "TEMPO"
	_titulos[1].text = "PONTOS"
	_titulos[3].text = "ACERTOS"
	_titulos[2].visible = false
	_valores[2].visible = false
	_t_bala = Estilo.tex("hud_bala")
	_ler()
	_aplicar(true)


## Altura ocupada no topo (para pôr coisas logo abaixo).
func altura() -> float:
	return MARGEM + ALTURA


func mostrar(v: bool) -> void:
	_raiz.visible = v


func _process(delta: float) -> void:
	_t += delta
	if not _raiz.visible:
		return
	# lê e aplica a cada 2 quadros; no do meio só se algo estiver animando
	_vez += 1
	if _vez % 2 == 0:
		_ler()
		_aplicar(false)
	elif _anima:
		_aplicar(false)


func _ler() -> void:
	if _fonte != null and _fonte.is_valid():
		_dados = _fonte.call_func()


func _mudou(chave: String, valor) -> bool:
	if _antes.has(chave) and typeof(_antes[chave]) == typeof(valor) and _antes[chave] == valor:
		return false
	_antes[chave] = valor
	return true


func _aplicar(forcar: bool) -> void:
	# tempo (vermelho e pulsando nos últimos 10 s)
	var tempo: float = max(0.0, float(_dados.get("tempo", 0.0)))
	var seg = int(ceil(tempo - 0.001)) if tempo > 0.0 else 0
	if _mudou("tempo", seg):
		_valores[0].text = "%02d:%02d" % [seg / 60, seg % 60]
	if seg <= 10 and tempo > 0.0:
		var k = 0.5 + 0.5 * sin(_t * 9.0)
		_valores[0].modulate = Color(1.0, 0.35 + 0.3 * k, 0.3 + 0.3 * k)
		_valores[0].rect_scale = Vector2.ONE * (1.0 + 0.06 * k)
	elif _valores[0].rect_scale != Vector2.ONE:
		_valores[0].modulate = Color.white
		_valores[0].rect_scale = Vector2.ONE

	# pontos: pulam quando sobem, piscam vermelho quando descem
	var pontos = int(_dados.get("pontos", 0))
	if _mudou("pontos", pontos):
		_valores[1].text = Estilo.milhar(pontos)
		if not forcar:
			_pulso_pontos = 1.0 if pontos >= _pontos_antes else -1.0
		_pontos_antes = pontos
	var base = Color(1.0, 0.86, 0.22) if pontos >= 0 else Color(1.0, 0.3, 0.3)
	if _pulso_pontos != 0.0:
		var k: float = abs(_pulso_pontos)
		var flash = Color(0.55, 1.0, 0.6) if _pulso_pontos > 0.0 else Color(1.0, 0.2, 0.2)
		_valores[1].modulate = base.linear_interpolate(flash, k)
		_valores[1].rect_scale = Vector2.ONE * (1.0 + 0.16 * k)
		_pulso_pontos = sign(_pulso_pontos) * max(0.0, k - get_process_delta_time() * 3.5)
		if abs(_pulso_pontos) < 0.01:
			_pulso_pontos = 0.0
	elif forcar or _mudou("pontos_cor", pontos >= 0):
		_valores[1].modulate = base
		_valores[1].rect_scale = Vector2.ONE

	# munição: as balas (redesenha quando muda ou enquanto pisca)
	var bal = int(_dados.get("municao", 0))
	var maxb = int(max(1, int(_dados.get("municao_max", 30))))
	var rec = bool(_dados.get("recarregando", false))
	var estado = "recarga" if rec else ("vazia" if bal <= 0 else ("baixa" if bal <= max(3, maxb / 5) else "ok"))
	var chave_balas = [bal, maxb, estado, stepify(float(_dados.get("recarga", 0.0)), 0.02)]
	if _mudou("municao", chave_balas) or estado == "baixa" or estado == "vazia":
		_barra.update()

	# acertos / tiros
	var ac = int(_dados.get("acertos", 0))
	var ti = int(_dados.get("tiros", 0))
	if _mudou("acertos", [ac, ti]):
		_valores[3].text = "%d/%d" % [ac, ti]

	# campo da fase (modo, bombas, combo, nível...)
	var et = str(_dados.get("extra_titulo", ""))
	if _mudou("extra_titulo", et):
		_titulos[4].text = et
	var ev = str(_dados.get("extra", ""))
	if _mudou("extra", ev):
		_valores[4].text = ev
	var ec: Color = _dados.get("extra_cor", Color.white)
	if _mudou("extra_cor", ec):
		_valores[4].add_color_override("font_color", ec)
	_anima = _pulso_pontos != 0.0 or (seg <= 10 and tempo > 0.0) or estado != "ok"


## As balas: duas fileiras de cartuchos, os gastos escuros; na recarga eles
## voltam um a um; com pouca bala as que sobram piscam laranja, e vazia os
## estojos piscam vermelho.
func _desenhar_balas() -> void:
	var bal = int(_dados.get("municao", 0))
	var maxb = int(max(1, int(_dados.get("municao_max", 30))))
	var rec = bool(_dados.get("recarregando", false))
	var prog: float = clamp(float(_dados.get("recarga", 0.0)), 0.0, 1.0)
	var tam = _barra.rect_size
	var por_fila = int(min(15, maxb))
	var filas = int(ceil(float(maxb) / por_fila))
	var esp = tam.x / por_fila
	var alt_fila = tam.y / filas
	var bh = min(alt_fila - 4.0, esp * 2.9)
	var bw = bh * 24.0 / 68.0
	var baixa = bal <= max(3, maxb / 5)
	var piscar = 0.55 + 0.45 * abs(sin(_t * 9.0))
	_barra.draw_rect(Rect2(Vector2(-4, -2), tam + Vector2(8, 4)), Color(0, 0, 0, 0.38))
	for i in maxb:
		var fila = i / por_fila
		var r = Rect2(Vector2((i % por_fila) * esp + (esp - bw) * 0.5, fila * alt_fila + (alt_fila - bh) * 0.5), Vector2(bw, bh))
		var c: Color
		if rec:
			# recarregando: os cartuchos voltam um a um
			var k = clamp(prog * maxb - i, 0.0, 1.0)
			c = Color(0.16, 0.16, 0.2, 0.55).linear_interpolate(Color.white, k)
		elif i < bal:
			c = Color(1.0, 0.62, 0.35, piscar) if baixa else Color.white
		elif bal <= 0:
			c = Color(1.0, 0.22, 0.18, 0.35 + 0.4 * piscar)
		else:
			c = Color(0.3, 0.29, 0.32, 0.55)
		_barra.draw_texture_rect(_t_bala, r, false, c)
