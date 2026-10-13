class_name Missao
extends Control

## MODAL DA MISSÃO: aparece no menu quando o jogador escolhe um cenário.
##
## Não há mais fácil/difícil: o jogo é sempre com a mira na tela. No lugar
## da escolha de dificuldade, o cartão da missão mostra a capa do cenário, o
## objetivo em letras grandes (lê-se de longe), o RECORDE daquele cenário e
## duas escolhas pela mira:
##   - o ALVO grande "JOGAR" (um tiro nele e a partida começa);
##   - "TROCAR CENÁRIO" (volta para a grade).
## Um anel em volta do alvo conta o tempo; sem tiro, a missão começa sozinha.
##
## Uso (cenarios.gd):
##   var m := Missao.new()
##   camada.add_child(m)
##   m.abrir("res://scenes/mar.tscn")
##   m.escolheu.connect(func(acao): ...)    # "jogar" ou "trocar"
##   todo quadro: m.mira(pos_da_mira)        # destaque do que está sob a mira
##   no tiro:     m.tiro(pos_da_mira)        # true se acertou uma escolha

signal escolheu(acao: String)

const Pincel := preload("res://scripts/pincel.gd")
const FONTE_FORTE := preload("res://fonts/Exo2-ExtraBold.ttf")
const FONTE := preload("res://fonts/Exo2-Bold.ttf")

const TEMPO := 9.0

const DADOS := {
	"res://scenes/deserto.tscn": {
		"nome": "DESERTO SAGRADO", "capa": "res://sprites/cene_desert.png",
		"cor": Color(1.0, 0.74, 0.22), "ranking": "DESERTO",
		"missao": "DE DIA, ACERTE O SOL.\nDE NOITE, ACERTE A LUA.",
	},
	"res://scenes/mar.tscn": {
		"nome": "FUNDO DO MAR", "capa": "res://sprites/cene_mar.png",
		"cor": Color(0.24, 0.72, 1.0), "ranking": "MAR",
		"missao": "ACERTE OS TESOUROS.\n3 BOMBAS E A PARTIDA ACABA.",
	},
	"res://scenes/bar.tscn": {
		"nome": "BAR DO FAROESTE", "capa": "res://sprites/cene_bar.png",
		"cor": Color(0.34, 0.95, 0.42), "ranking": "BAR",
		"missao": "QUEBRE AS GARRAFAS.\nNUNCA A VERDE DE CAVEIRA.",
	},
	"res://scenes/arena.tscn": {
		"nome": "ARENA LAZER SHOT", "capa": "res://sprites/cene_arena.png",
		"cor": Color(1.0, 0.24, 0.20), "ranking": "ARENA",
		"missao": "ACERTE AS LANTERNAS\nNA ORDEM DAS CORES.",
	},
}

var cena := ""
var _cor := Color.WHITE
var _t := 0.0
var _restante := TEMPO
var _ativo := false
var _sob_alvo := false
var _sob_trocar := false
var _destaque_alvo := 0.0      # 0..1, sobe com a mira em cima
var _acertou_t := -1.0         # animação do tiro no alvo

var _painel: Panel
var _capa: TextureRect
var _titulo: Label
var _texto: Label
var _recorde_titulo: Label
var _recorde: Label
var _alvo: Control             # desenho do alvo JOGAR (+ anel do tempo)
var _alvo_texto: Label
var _dica: Label
var _trocar: Panel
var _trocar_texto: Label
var _estilo_trocar: StyleBoxFlat
var _estilo_trocar_mira: StyleBoxFlat


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


func abrir(caminho: String) -> void:
	cena = caminho
	var d: Dictionary = DADOS.get(caminho, {})
	if d.is_empty():
		push_warning("Missão sem dados: " + caminho)
		return
	_cor = d["cor"]
	for c in get_children():
		c.queue_free()
	_montar(d)
	_t = 0.0
	_restante = TEMPO
	_acertou_t = -1.0
	_destaque_alvo = 0.0
	_ativo = true
	visible = true
	set_process(true)
	# entra crescendo de leve
	_painel.pivot_offset = _painel.size * 0.5
	_painel.scale = Vector2(0.9, 0.9)
	_painel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_painel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_painel, "modulate:a", 1.0, 0.18)


## Monta o cartão escondido enquanto o menu carrega: o pré-aquecimento da
## troca de tela (scripts/aquecedor.gd) acha os textos e deixa as letras
## prontas na placa, e a primeira escolha de cenário abre sem engasgo.
func aquecer() -> void:
	if _ativo:
		return
	_cor = Color.WHITE
	_montar(DADOS.values()[0])
	await get_tree().create_timer(1.5).timeout
	if not _ativo and _painel != null:
		for c in get_children():
			c.queue_free()
		_painel = null


func fechar() -> void:
	_ativo = false
	set_process(false)
	if _painel == null:
		visible = false
		return
	var tw := create_tween()
	tw.tween_property(_painel, "modulate:a", 0.0, 0.14)
	await tw.finished
	visible = false
	for c in get_children():
		c.queue_free()
	_painel = null


func ativo() -> bool:
	return _ativo


## Destaque do que está sob a mira (chamar todo quadro).
func mira(pos: Vector2) -> void:
	if not _ativo or _painel == null:
		return
	_sob_alvo = _no_alvo(pos)
	_sob_trocar = _trocar.get_global_rect().grow(10.0).has_point(pos)
	_trocar.add_theme_stylebox_override("panel", _estilo_trocar_mira if _sob_trocar else _estilo_trocar)
	_trocar.scale = Vector2.ONE * (1.05 if _sob_trocar else 1.0)


## Tiro do jogador: true se acertou uma das escolhas.
func tiro(pos: Vector2) -> bool:
	if not _ativo or _painel == null:
		return false
	if _no_alvo(pos):
		_escolher("jogar")
		return true
	if _trocar.get_global_rect().grow(10.0).has_point(pos):
		_escolher("trocar")
		return true
	return false


func _no_alvo(pos: Vector2) -> bool:
	var centro := _alvo.global_position + _alvo.size * 0.5
	return pos.distance_to(centro) <= _alvo.size.x * 0.5


func _escolher(acao: String) -> void:
	if not _ativo:
		return
	_ativo = false
	if acao == "jogar":
		_acertou_t = 0.0
		_alvo_texto.text = "VAMOS!"
		_dica.text = ""
		await get_tree().create_timer(0.32).timeout
	escolheu.emit(acao)


func _process(delta: float) -> void:
	_t += delta
	if _acertou_t >= 0.0:
		_acertou_t += delta
	if _ativo:
		_restante = maxf(0.0, _restante - delta)
		var seg := int(ceil(_restante))
		_dica.text = "COMEÇA SOZINHO EM %d" % seg if seg > 0 else ""
		if _restante <= 0.0:
			_escolher("jogar")
	_destaque_alvo = move_toward(_destaque_alvo, 1.0 if _sob_alvo else 0.0, delta * 6.0)
	var pulso := 1.0 + 0.035 * sin(_t * 5.0) + 0.06 * _destaque_alvo
	_alvo.scale = Vector2.ONE * pulso
	_alvo_texto.scale = _alvo.scale
	_alvo.queue_redraw()


# ───────────────────────────────────────────── montagem

func _montar(d: Dictionary) -> void:
	var tela := get_viewport_rect().size
	var s := tela.x / 1024.0

	var fundo := ColorRect.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.color = Color(0.0, 0.0, 0.0, 0.74)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	var w := 940.0 * s
	var pad := 30.0 * s
	var capa_l := w - pad * 2.0 - 30.0 * s
	var capa_a := capa_l * 742.0 / 2120.0
	var y := MolduraTema.MARGEM * s

	_painel = Panel.new()
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.05, 0.0)   # o fundo é da moldura
	sb.set_corner_radius_all(int(34 * s))
	sb.border_color = _cor
	sb.set_border_width_all(int(4 * s))
	sb.shadow_color = Color(_cor.r, _cor.g, _cor.b, 0.30)
	sb.shadow_size = int(24 * s)
	sb.anti_aliasing = true
	_painel.add_theme_stylebox_override("panel", sb)
	add_child(_painel)

	# capa do cenário numa moldura colorida
	var moldura := Panel.new()
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moldura.clip_contents = true
	moldura.position = Vector2((w - capa_l) * 0.5, y)
	moldura.size = Vector2(capa_l, capa_a)
	var sbm := StyleBoxFlat.new()
	sbm.bg_color = Color.BLACK
	moldura.add_theme_stylebox_override("panel", sbm)
	_painel.add_child(moldura)
	_capa = TextureRect.new()
	_capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_capa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_capa.texture = load(d["capa"]) if ResourceLoader.exists(d["capa"]) else null
	_capa.size = moldura.size
	moldura.add_child(_capa)
	var borda := Panel.new()
	borda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	borda.position = moldura.position
	borda.size = moldura.size
	var sbb := StyleBoxFlat.new()
	sbb.draw_center = false
	sbb.border_color = _cor.lerp(Color.WHITE, 0.25)
	sbb.set_border_width_all(int(4 * s))
	borda.add_theme_stylebox_override("panel", sbb)
	_painel.add_child(borda)
	y += capa_a + 18.0 * s

	_titulo = _rotulo(str(d["nome"]), 76, _cor.lerp(Color.WHITE, 0.30), FONTE_FORTE, 12, s)
	_titulo.position = Vector2(0, y)
	_titulo.size = Vector2(w, 96 * s)
	# a moldura do cenário fica atrás de tudo (scripts/moldura_tema.gd)
	var tema := MolduraTema.criar(str(d["ranking"]).to_lower(), y + 48.0 * s)
	_painel.add_child(tema)
	_painel.move_child(tema, 0)
	y += 96.0 * s

	_texto = _rotulo(str(d["missao"]), 44, Color.WHITE, FONTE, 9, s)
	_texto.position = Vector2(0, y)
	_texto.size = Vector2(w, 128 * s)
	_texto.add_theme_constant_override("line_spacing", int(-4 * s))
	y += 136.0 * s

	# faixa do recorde deste cenário
	var faixa := Panel.new()
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa.position = Vector2((w - capa_l) * 0.5, y)
	faixa.size = Vector2(capa_l, 118 * s)
	var sbf := StyleBoxFlat.new()
	sbf.bg_color = Color(0.0, 0.0, 0.0, 0.50)
	sbf.border_color = Color(1.0, 0.80, 0.25, 0.55)
	sbf.set_border_width_all(int(2 * s))
	sbf.set_corner_radius_all(int(20 * s))
	faixa.add_theme_stylebox_override("panel", sbf)
	_painel.add_child(faixa)
	var rec := _recorde_do_cenario(str(d["ranking"]))
	_recorde_titulo = _rotulo("RECORDE DESTE CENÁRIO" if not rec.is_empty() else "NINGUÉM NO RANKING AINDA", 30, Color(1.0, 0.84, 0.40), FONTE, 6, s)
	_recorde_titulo.position = Vector2(0, y + 8 * s)
	_recorde_titulo.size = Vector2(w, 42 * s)
	var txt_rec := "SEJA O PRIMEIRO!"
	if not rec.is_empty():
		txt_rec = "%s   %s PONTOS" % [str(rec.get("nome", "")).strip_edges().to_upper().left(10), _milhar(int(rec.get("pontos", 0)))]
	_recorde = _rotulo(txt_rec, 46, Color(1.0, 0.92, 0.62), FONTE_FORTE, 9, s)
	_recorde.position = Vector2(0, y + 48 * s)
	_recorde.size = Vector2(w, 62 * s)
	y += 118.0 * s + 26.0 * s

	# o alvo JOGAR
	var diam := 330.0 * s
	_alvo = Control.new()
	_alvo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alvo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_alvo.position = Vector2((w - diam) * 0.5, y)
	_alvo.size = Vector2(diam, diam)
	_alvo.pivot_offset = _alvo.size * 0.5
	_alvo.draw.connect(_desenhar_alvo)
	_painel.add_child(_alvo)
	_alvo_texto = _rotulo("JOGAR", 70, Color.WHITE, FONTE_FORTE, 14, s)
	_alvo_texto.position = _alvo.position
	_alvo_texto.size = _alvo.size
	_alvo_texto.pivot_offset = _alvo.size * 0.5
	y += diam + 8.0 * s

	_dica = _rotulo("", 32, Color(0.85, 0.85, 0.88), FONTE, 6, s)
	_dica.position = Vector2(0, y)
	_dica.size = Vector2(w, 46 * s)
	y += 46.0 * s + 22.0 * s

	# TROCAR CENÁRIO
	var tw_l := 600.0 * s
	var tw_a := 104.0 * s
	_estilo_trocar = StyleBoxFlat.new()
	_estilo_trocar.bg_color = Color(0.0, 0.0, 0.0, 0.85)
	_estilo_trocar.border_color = Color(1.0, 1.0, 1.0, 0.55)
	_estilo_trocar.set_border_width_all(int(3 * s))
	_estilo_trocar.set_corner_radius_all(int(26 * s))
	_estilo_trocar_mira = _estilo_trocar.duplicate() as StyleBoxFlat
	_estilo_trocar_mira.bg_color = Color(0.16, 0.16, 0.18, 0.95)
	_estilo_trocar_mira.border_color = Color.WHITE
	_trocar = Panel.new()
	_trocar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trocar.position = Vector2((w - tw_l) * 0.5, y)
	_trocar.size = Vector2(tw_l, tw_a)
	_trocar.pivot_offset = _trocar.size * 0.5
	_trocar.add_theme_stylebox_override("panel", _estilo_trocar)
	_painel.add_child(_trocar)
	_trocar_texto = _rotulo("TROCAR CENÁRIO", 42, Color.WHITE, FONTE_FORTE, 8, s, _trocar)
	_trocar_texto.position = Vector2.ZERO
	_trocar_texto.size = _trocar.size
	y += tw_a + MolduraTema.MARGEM * s

	_painel.size = Vector2(w, y)
	_painel.position = ((tela - _painel.size) * 0.5).floor()


func _rotulo(texto: String, tamanho: int, cor: Color, fonte: Font, contorno: int, s: float, pai: Control = null) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", int(tamanho * s))
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", int(contorno * s))
	(pai if pai != null else _painel).add_child(l)
	return l


func _desenhar_alvo() -> void:
	var c := _alvo.size * 0.5
	var r := _alvo.size.x * 0.5
	var forte := _destaque_alvo
	var cor := _cor.lerp(Color.WHITE, 0.15 + 0.25 * forte)
	# disco escuro e anéis do alvo
	Pincel.circulo(_alvo, c, r * 0.80, Color(0.02, 0.02, 0.03, 0.92))
	Pincel.brilho(_alvo, c, r * 1.05, Color(_cor.r, _cor.g, _cor.b, 0.22 + 0.25 * forte))
	Pincel.anel(_alvo, c, r * 0.78, r * 0.05, cor)
	Pincel.anel(_alvo, c, r * 0.58, r * 0.03, Color(1, 1, 1, 0.85))
	Pincel.anel(_alvo, c, r * 0.40, r * 0.03, cor)
	# marcas que giram (devagar; mais rápido com a mira em cima)
	var giro := _t * (0.6 + 2.2 * forte)
	for i in 4:
		var a := giro + i * TAU / 4.0
		var dir := Vector2(cos(a), sin(a))
		Pincel.linha(_alvo, c + dir * r * 0.84, c + dir * r * 0.97, Color(1, 1, 1, 0.9), r * 0.035)
	# anel do tempo: começa cheio e esvazia em sentido horário
	var frac := clampf(_restante / TEMPO, 0.0, 1.0)
	Pincel.anel(_alvo, c, r * 0.90, r * 0.03, Color(1, 1, 1, 0.12))
	if frac > 0.0:
		Pincel.arco(_alvo, c, r * 0.90, -PI * 0.5, -PI * 0.5 + TAU * frac, _cor.lerp(Color.WHITE, 0.4), r * 0.035)
	# tiro no alvo: onda e clarão
	if _acertou_t >= 0.0:
		var k := clampf(_acertou_t / 0.32, 0.0, 1.0)
		Pincel.anel(_alvo, c, r * (0.4 + 0.8 * k), r * 0.08 * (1.0 - k), Color(1, 1, 1, 1.0 - k))
		Pincel.brilho(_alvo, c, r * 0.9, Color(1, 1, 1, 0.6 * (1.0 - k)))


func _recorde_do_cenario(chave: String) -> Dictionary:
	var rm := get_node_or_null("/root/RankingManager")
	if rm == null:
		return {}
	var melhor := {}
	for e in rm.obter_ranking():
		if _cenario_do_ranking(str(e.get("cenario", ""))) == chave \
				and (melhor.is_empty() or int(e.get("pontos", 0)) > int(melhor.get("pontos", 0))):
			melhor = e
	return melhor


## Mesmo agrupamento da tela de ranking (scripts/ranking.gd).
static func _cenario_do_ranking(valor: String) -> String:
	var c := valor.strip_edges().to_upper()
	if c.contains("DESERTO") or c.contains("SAGRADO"):
		return "DESERTO"
	if c.contains("MAR") or c.contains("FUNDO"):
		return "MAR"
	if c.contains("BAR") or c.contains("FAROESTE"):
		return "BAR"
	if c.contains("ARENA") or c.contains("LAZER"):
		return "ARENA"
	return c


static func _milhar(n: int) -> String:
	var t := str(absi(n))
	var out := ""
	while t.length() > 3:
		out = "." + t.right(3) + out
		t = t.left(t.length() - 3)
	return ("-" if n < 0 else "") + t + out
