extends CanvasLayer
class_name Missao

## MODAL DA MISSÃO: aparece na escolha de cenário quando o jogador escolhe
## um (ou a roleta escolhe). Mostra a capa do cenário, o objetivo em letras
## grandes (lê-se de longe), o RECORDE daquele cenário e duas escolhas pela
## mira:
##   - o ALVO grande "JOGAR" (um tiro nele e a partida começa);
##   - "TROCAR CENÁRIO" (volta para a grade).
## Um anel em volta do alvo conta o tempo; sem tiro, a missão começa sozinha.
## O sinal `escolheu` sai com "jogar" ou "trocar".

signal escolheu(acao)

const TEMPO = 9.0
const DADOS = {
	"res://scenes/deserto.tscn": {
		"nome": "DESERTO SAGRADO", "capa": "capa_desert", "tema": "deserto",
		"cor": Color(1.0, 0.74, 0.22), "ranking": "DESERTO",
		"missao": "DE DIA, ACERTE O SOL.\nDE NOITE, ACERTE A LUA.",
	},
	"res://scenes/mar.tscn": {
		"nome": "FUNDO DO MAR", "capa": "capa_mar", "tema": "mar",
		"cor": Color(0.24, 0.72, 1.0), "ranking": "MAR",
		"missao": "ACERTE OS TESOUROS.\n3 BOMBAS E A PARTIDA ACABA.",
	},
	"res://scenes/bar.tscn": {
		"nome": "BAR DO FAROESTE", "capa": "capa_bar", "tema": "bar",
		"cor": Color(0.34, 0.95, 0.42), "ranking": "BAR",
		"missao": "QUEBRE AS GARRAFAS.\nNUNCA A VERDE DE CAVEIRA.",
	},
	"res://scenes/arena.tscn": {
		"nome": "ARENA LAZER SHOT", "capa": "capa_arena", "tema": "arena",
		"cor": Color(1.0, 0.24, 0.20), "ranking": "ARENA",
		"missao": "ACERTE AS LANTERNAS\nNA ORDEM DAS CORES.",
	},
}

var cena = ""
var ativo = false

var _cor = Color.white
var _t = 0.0
var _restante = TEMPO
var _sob_alvo = false
var _sob_trocar = false
var _destaque = 0.0
var _acertou_t = -1.0

var _raiz: Control
var _painel: Panel
var _alvo: Node2D
var _alvo_texto: Label
var _dica: Label
var _trocar: Panel
var _sb_trocar: StyleBoxFlat
var _sb_trocar_mira: StyleBoxFlat
var _som_alvo: AudioStream


static func criar(pai: Node) -> Missao:
	var m = load("res://scripts/missao.gd").new()
	m.layer = 80
	pai.add_child(m)
	return m


func _ready() -> void:
	_som_alvo = load("res://songs/alvo_crash.wav")
	visible = false
	set_process(false)


func abrir(caminho: String) -> void:
	if not DADOS.has(caminho):
		return
	cena = caminho
	var d: Dictionary = DADOS[caminho]
	_cor = d["cor"]
	if _raiz != null:
		_raiz.queue_free()
	_montar(d)
	_t = 0.0
	_restante = TEMPO
	_acertou_t = -1.0
	_destaque = 0.0
	ativo = true
	visible = true
	set_process(true)
	# entra crescendo de leve
	_painel.rect_pivot_offset = _painel.rect_size * 0.5
	_painel.rect_scale = Vector2(0.9, 0.9)
	_raiz.modulate.a = 0.0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_painel, "rect_scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_raiz, "modulate:a", 1.0, 0.18)


func fechar() -> void:
	ativo = false
	set_process(false)
	if _raiz == null:
		visible = false
		return
	var tw = create_tween()
	tw.tween_property(_raiz, "modulate:a", 0.0, 0.14)
	tw.tween_callback(self, "_sumiu", [_raiz])


func _sumiu(raiz: Control) -> void:
	if raiz != _raiz:
		return   # reabriu enquanto sumia: o cartão novo fica
	visible = false
	_raiz.queue_free()
	_raiz = null


## Destaque do que está sob a mira (chamar todo quadro).
func mira(p: Vector2) -> void:
	if not ativo or _painel == null:
		return
	_sob_alvo = _no_alvo(p)
	var sob = _no_trocar(p)
	if sob != _sob_trocar:
		_sob_trocar = sob
		_trocar.add_stylebox_override("panel", _sb_trocar_mira if sob else _sb_trocar)
		_trocar.rect_scale = Vector2.ONE * (1.05 if sob else 1.0)


## Tiro do jogador: true se acertou uma das escolhas.
func tiro(p: Vector2) -> bool:
	if not ativo or _painel == null:
		return false
	if _no_alvo(p):
		_escolher("jogar")
		return true
	if _no_trocar(p):
		_escolher("trocar")
		return true
	return false


## START na missão: joga (como o tiro no alvo).
func jogar() -> void:
	if ativo:
		_escolher("jogar")


func _no_alvo(p: Vector2) -> bool:
	return p.distance_to(_painel.rect_position + _alvo.position) <= 165.0


func _no_trocar(p: Vector2) -> bool:
	return Rect2(_painel.rect_position + _trocar.rect_position, _trocar.rect_size).grow(10.0).has_point(p)


func _escolher(acao: String) -> void:
	if not ativo:
		return
	ativo = false
	if acao == "jogar":
		_acertou_t = 0.0
		_alvo_texto.text = "VAMOS!"
		_dica.text = ""
		Maquina.efeito(_som_alvo, -4.0, 1.1)
		var tw = create_tween()
		tw.tween_interval(0.32)
		tw.tween_callback(self, "emit_signal", ["escolheu", acao])
		return
	emit_signal("escolheu", acao)


func _process(delta: float) -> void:
	if _painel == null:
		set_process(false)
		return
	_t += delta
	if _acertou_t >= 0.0:
		_acertou_t += delta
	if ativo:
		_restante = max(0.0, _restante - delta)
		var seg = int(ceil(_restante))
		_dica.text = ("COMEÇA SOZINHO EM %d" % seg) if seg > 0 else ""
		if _restante <= 0.0:
			_escolher("jogar")
	_destaque = move_toward(_destaque, 1.0 if _sob_alvo else 0.0, delta * 6.0)
	var pulso = 1.0 + 0.035 * sin(_t * 5.0) + 0.06 * _destaque
	_alvo.scale = Vector2.ONE * pulso
	_alvo_texto.rect_scale = _alvo.scale
	_alvo.update()


# ------------------------------------------------------------ montagem
func _montar(d: Dictionary) -> void:
	var tela = Tela.TELA
	_raiz = Control.new()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.rect_size = tela
	add_child(_raiz)
	var escuro = ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.74)
	escuro.rect_size = tela
	escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(escuro)
	var w = 940.0
	var capa_l = 850.0
	var capa_a = capa_l * 371.0 / 1060.0
	var y = Moldura.MARGEM
	_painel = Estilo.painel(_raiz, Vector2.ZERO, Vector2(w, 100), Estilo.caixa(Color(0.035, 0.03, 0.045, 0.96), _cor, 4, 34, 24,
		Color(_cor.r, _cor.g, _cor.b, 0.30)))
	var moldura = Moldura.criar(_painel, d["tema"], Vector2(w, 100), _cor, 0.0)
	# capa do cenário numa moldura colorida
	var capa = TextureRect.new()
	capa.texture = Estilo.tex(d["capa"])
	capa.expand = true
	capa.stretch_mode = TextureRect.STRETCH_SCALE
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.rect_position = Vector2((w - capa_l) * 0.5, y)
	capa.rect_size = Vector2(capa_l, capa_a)
	_painel.add_child(capa)
	var borda = StyleBoxFlat.new()
	borda.draw_center = false
	borda.border_color = _cor.linear_interpolate(Color.white, 0.25)
	borda.set_border_width_all(4)
	Estilo.painel(_painel, capa.rect_position, capa.rect_size, borda)
	y += capa_a + 18.0
	var titulo = Estilo.rotulo(_painel, d["nome"], 76, _cor.linear_interpolate(Color.white, 0.3), 12)
	Estilo.colocar(titulo, Vector2(0, y), Vector2(w, 96))
	moldura.titulo_y = y + 48.0
	y += 96.0
	var texto = Estilo.rotulo(_painel, d["missao"], 44, Color.white, 9, false)
	texto.add_constant_override("line_spacing", -4)
	Estilo.colocar(texto, Vector2(0, y), Vector2(w, 128))
	y += 136.0
	# faixa do recorde deste cenário
	Estilo.painel(_painel, Vector2((w - capa_l) * 0.5, y), Vector2(capa_l, 118), Estilo.caixa(Color(0, 0, 0, 0.5), Color(1.0, 0.8, 0.25, 0.55), 2, 20))
	var rec = RankingManager.recorde(d["ranking"])
	var t_rec = Estilo.rotulo(_painel, "RECORDE DESTE CENÁRIO" if not rec.empty() else "NINGUÉM NO RANKING AINDA", 30, Color(1.0, 0.84, 0.40), 6, false)
	Estilo.colocar(t_rec, Vector2(0, y + 8), Vector2(w, 42))
	var txt_rec = "SEJA O PRIMEIRO!"
	if not rec.empty():
		txt_rec = "%s   %s PONTOS" % [str(rec.get("nome", "")).strip_edges().to_upper().left(10), Estilo.milhar(int(rec.get("pontos", 0)))]
	var v_rec = Estilo.rotulo(_painel, txt_rec, 46, Color(1.0, 0.92, 0.62), 9)
	Estilo.colocar(v_rec, Vector2(0, y + 48), Vector2(w, 62))
	y += 118.0 + 26.0
	# o alvo JOGAR
	var diam = 330.0
	_alvo = Node2D.new()
	_alvo.position = Vector2(w * 0.5, y + diam * 0.5)
	_alvo.connect("draw", self, "_desenhar_alvo")
	_painel.add_child(_alvo)
	_alvo_texto = Estilo.rotulo(_painel, "JOGAR", 70, Color.white, 14)
	Estilo.colocar(_alvo_texto, Vector2((w - diam) * 0.5, y), Vector2(diam, diam))
	y += diam + 8.0
	_dica = Estilo.rotulo(_painel, "", 32, Color(0.85, 0.85, 0.88), 6, false)
	Estilo.colocar(_dica, Vector2(0, y), Vector2(w, 46))
	y += 46.0 + 22.0
	# TROCAR CENÁRIO
	_sb_trocar = Estilo.caixa(Color(0, 0, 0, 0.85), Color(1, 1, 1, 0.55), 3, 26)
	_sb_trocar_mira = Estilo.caixa(Color(0.16, 0.16, 0.18, 0.95), Color.white, 3, 26)
	_trocar = Estilo.painel(_painel, Vector2((w - 600.0) * 0.5, y), Vector2(600, 104), _sb_trocar)
	_trocar.rect_pivot_offset = _trocar.rect_size * 0.5
	var tt = Estilo.rotulo(_trocar, "TROCAR CENÁRIO", 42, Color.white, 8)
	Estilo.colocar(tt, Vector2.ZERO, _trocar.rect_size)
	y += 104.0 + Moldura.MARGEM
	_painel.rect_size = Vector2(w, y)
	_painel.rect_position = ((tela - _painel.rect_size) * 0.5).floor()
	moldura.tam = _painel.rect_size
	_sob_trocar = false


func _desenhar_alvo() -> void:
	var r = 165.0
	var forte = _destaque
	var cor = _cor.linear_interpolate(Color.white, 0.15 + 0.25 * forte)
	var brilho = Estilo.tex("fx_brilho")
	_alvo.draw_texture_rect(brilho, Rect2(-Vector2(r, r) * 1.05, Vector2(r, r) * 2.1), false, Color(_cor.r, _cor.g, _cor.b, 0.30 + 0.30 * forte))
	_alvo.draw_circle(Vector2.ZERO, r * 0.80, Color(0.02, 0.02, 0.03, 0.92))
	_alvo.draw_arc(Vector2.ZERO, r * 0.78, 0, TAU, 64, cor, r * 0.05)
	_alvo.draw_arc(Vector2.ZERO, r * 0.58, 0, TAU, 56, Color(1, 1, 1, 0.85), r * 0.03)
	_alvo.draw_arc(Vector2.ZERO, r * 0.40, 0, TAU, 48, cor, r * 0.03)
	# marcas que giram (devagar; mais rápido com a mira em cima)
	var giro = _t * (0.6 + 2.2 * forte)
	for i in 4:
		var a = giro + i * TAU / 4.0
		var d = Vector2(cos(a), sin(a))
		_alvo.draw_line(d * r * 0.84, d * r * 0.97, Color(1, 1, 1, 0.9), r * 0.035)
	# anel do tempo: começa cheio e esvazia
	var frac = clamp(_restante / TEMPO, 0.0, 1.0)
	_alvo.draw_arc(Vector2.ZERO, r * 0.90, 0, TAU, 64, Color(1, 1, 1, 0.12), r * 0.03)
	if frac > 0.0:
		_alvo.draw_arc(Vector2.ZERO, r * 0.90, -PI * 0.5, -PI * 0.5 + TAU * frac, 64, _cor.linear_interpolate(Color.white, 0.4), r * 0.035)
	# tiro no alvo: onda e clarão
	if _acertou_t >= 0.0:
		var k = clamp(_acertou_t / 0.32, 0.0, 1.0)
		_alvo.draw_arc(Vector2.ZERO, r * (0.4 + 0.8 * k), 0, TAU, 64, Color(1, 1, 1, 1.0 - k), max(1.0, r * 0.08 * (1.0 - k)))
		_alvo.draw_texture_rect(brilho, Rect2(-Vector2(r, r) * 0.9, Vector2(r, r) * 1.8), false, Color(1, 1, 1, 0.6 * (1.0 - k)))
