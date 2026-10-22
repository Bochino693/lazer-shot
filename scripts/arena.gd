extends "res://scripts/fase.gd"

## ARENA LAZER SHOT, em 2D para a Mali-450.
##
## As cores dão a ordem dos tiros: AZUL 1º, VERDE 2º, AMARELO 3º, VERMELHO
## 4º, ROXO 5º (vale 20, 40, 60, 80, 100). A partida cicla entre duas rodadas:
##   MEMÓRIA  as 9 lanternas apagadas nos furos; a sequência (1 a 5, cresce a
##            cada nível) acende uma a uma nas cores da ordem e apaga; o
##            jogador repete. Cada acerto fica aceso na sua cor. Parado 20 s,
##            a sequência que falta acende de novo.
##   FIXA     as lanternas descem; 5 lanternas acesas sobem uma depois da
##            outra (a cada 1 a 1,5 s), cada uma já na cor da vez: é acertar
##            na ordem enquanto elas aparecem. Acerto em até 1,1 s: +10;
##            completa: +50.
## Ordem errada: -100 e a rodada recomeça (na memória, volta ao nível 1).
## O LED do alto é bônus: o tiro estoura a lâmpada (+50), que fica queimada,
## soltando fumaça, e volta a acender piscando depois de 7 s.
##
## A parede vive: o logo e os anéis dos furos acendem com a música (luz
## somada, sem shader de tela), vapor dos canos, faíscas da caixa elétrica,
## fachos das arandelas com poeira, giroflex girando na troca de rodada e a
## faixa da ordem embaixo dos furos. O laser que erra deixa a marca queimada
## na parede.

const CORES_SEQ = ["azul", "verde", "amarelo", "vermelho", "roxo"]
const QUADRO_COR = {"apagada": 0, "azul": 1, "verde": 2, "amarelo": 3, "vermelho": 4, "roxo": 5}
const CORES_FX = {
	"apagada": Color(0.75, 0.78, 0.85),
	"azul": Color(0.25, 0.62, 1.0),
	"verde": Color(0.25, 1.0, 0.35),
	"amarelo": Color(1.0, 0.86, 0.15),
	"vermelho": Color(1.0, 0.14, 0.10),
	"roxo": Color(0.78, 0.32, 1.0),
}
const NOMES_COR = {"azul": "AZUL", "verde": "VERDE", "amarelo": "AMARELO", "vermelho": "VERMELHO", "roxo": "ROXO"}
const TONS_BIP = [0.84, 0.94, 1.06, 1.19, 1.34]
# os 9 furos da parede (centro do anel, px do fundo 1080x1920)
const FUROS = [Vector2(226, 782), Vector2(538, 781), Vector2(842, 781),
	Vector2(226, 1098), Vector2(538, 1098), Vector2(842, 1098),
	Vector2(226, 1418), Vector2(538, 1418), Vector2(842, 1417)]
const SUBIDA = 190.0
const PONTOS_BASE = 20
const PENA_ORDEM = 100
const BONUS_FIXA = 50
const BONUS_LED = 50
const RAPIDO_MS = 1100
const TEMPO_MOSTRAR = 0.55
const PAUSA_ENTRE = 0.20
const INATIVO_REPETE = 20.0
# px da imagem 1024x1536 da 4.6 (tela() converte)
const GIROFLEX = Vector2(510, 190)
const LED_CAIXA = Rect2(484, 177, 54, 25)
const LED_APAGADO = 7.0
const ARANDELAS = [Vector2(44, 762), Vector2(978, 762)]
const VAPOR = [Vector2(150, 748), Vector2(804, 944), Vector2(842, 1128), Vector2(118, 1180)]
const CAIXA_ELETRICA = Vector2(842, 956)
const Y_ORDEM = 1318.0
# o recorte do logo (tools/preparar_mali.py: ARENA_LOGO), px do fundo 1080x1920
const LOGO = Rect2(52, 148, 996, 456)
const COR_MEMORIA = Color(1.0, 0.12, 0.06)
const COR_FIXA = Color(0.75, 0.30, 1.0)


class Lanterna:
	var no: Node2D
	var spr: Sprite
	var slot = 0
	var cor = "apagada"
	var quebrando = false


var lanternas = []          # 9 casas: Lanterna ou null
var sequencia = []          # os furos da rodada, na ordem das cores
var indice = 0              # quantos da sequência já foram
var nivel = 1
var mostrando = false
var bloqueado = true
var modo_fixo = false
var _rodada = 0             # muda a cada rodada: corta as esperas da anterior
var _fixa_nasceu = []       # ms em que cada lanterna da rodada fixa subiu
var _sem_jogada = 0.0
var _repetindo = false
var _aviso_espera = 0.0

var _f: Dictionary
var _esc_lanterna = 0.66 / 0.70      # a lanterna da 4.6 (0,66) na folha de 70% (o "fator" da folha nítida desconta)
var _furos_tela = []
var _fundo: Sprite
var _fundo_fixa: Sprite
var _logo: Sprite
var _logo_fixa: Sprite
var _aneis = []
var _aneis_fixa = []
var _tw_arte: SceneTreeTween
var _parede: Node2D          # marcas do laser e o LED queimado (mistura normal)
var _brilhos: Node2D         # fachos, giroflex, faixa da ordem (luz somada)
var _vapor: Particulas
var _marcas = []
var _brasas = false

var _t = 0.0
var _giro = 0.0              # tempo girando o giroflex
var _giro_cor = COR_MEMORIA
var _giro_arco = false
var _pisca = 0.0
var _pisca_cor = Color.white
var _led = 0.0               # s até a luz do alto voltar (0 = acesa)
var _led_clarao = 0.0
var _led_fumaca = 0.0
var _varre = -1.0            # 0..1 linha colorida descendo a parede
var _prox_vapor = 3.0
var _prox_faisca = 6.0
var _poeira = []

var _letreiro: Control
var _letreiro_txt: Label
var _letreiro_sub: Label
var _letreiro_barras = []

var _som_lampada: AudioStream
var _som_bip: AudioStream
var _som_bip_erro: AudioStream
var _som_sobe: AudioStream
var _som_desce: AudioStream
var _som_parede: AudioStream
var _som_led: AudioStream
var _som_vapor: AudioStream
var _som_faisca: AudioStream
var _som_troca: AudioStream


func _configurar() -> void:
	id_fase = "arena"
	cenario_ranking = "ARENA"
	cor = Estilo.CORES["arena"]
	estilo_tiro = "laser"
	forca_coice = 0.6
	musica_path = "res://songs/arena_song.mp3"
	som_tiro_path = "res://songs/plasma-hit.wav"
	som_recarga_path = "res://songs/lazer-charge.wav"
	vol_tiro = -4.0
	janela_combo = 1.0e6       # o combo da arena é de acertos seguidos, sem relógio
	tempo_recarga = 1.10
	centro_contagem = 1100.0


func _icones() -> Dictionary:
	var r = {}
	for c in QUADRO_COR.keys():
		r[c] = quadro(_f, QUADRO_COR[c])
	return r


# ------------------------------------------------------------ cenário
func _montar_cenario() -> void:
	_f = folha("lanterna")
	_esc_lanterna = 0.66 / 0.70 / float(_f.get("fator", 1.0))
	_som_lampada = load("res://songs/hit-lamp.wav")
	_som_bip = load("res://songs/bip.wav")
	_som_bip_erro = load("res://songs/bip-error.wav")
	_som_sobe = load("res://songs/lanterna_sobe.wav")
	_som_desce = load("res://songs/lanterna_desce.wav")
	_som_parede = load("res://songs/laser_parede.wav")
	_som_led = load("res://songs/led_estoura.wav")
	_som_vapor = load("res://songs/arena_vapor.wav")
	_som_faisca = load("res://songs/arena_faisca.wav")
	_som_troca = load("res://songs/arena_troca.wav")
	var esc = Tela.TELA.x / 1080.0
	for p in FUROS:
		_furos_tela.append(p * esc)
	_fundo = fundo_sprite("fundo_arena")
	_fundo_fixa = fundo_sprite("fundo_arena_fixa")
	_fundo_fixa.modulate.a = 0.0
	_fundo_fixa.visible = false
	# o que acende com a música: o logo e os anéis dos furos (luz somada)
	_logo = _brilho_recortado("arena_brilho_logo", LOGO.position * esc + LOGO.size * esc * 0.5, LOGO.size.x * esc)
	_logo_fixa = _brilho_recortado("arena_brilho_logo_fixa", _logo.position, LOGO.size.x * esc)
	_logo_fixa.visible = false
	for p in _furos_tela:
		var a = _brilho_recortado("arena_brilho_furo", p, 184.0 * esc)
		var b = _brilho_recortado("arena_brilho_furo_fixa", p, 184.0 * esc)
		b.visible = false
		_aneis.append(a)
		_aneis_fixa.append(b)
	_parede = Node2D.new()
	_parede.connect("draw", self, "_desenhar_parede")
	cenario.add_child(_parede)
	_vapor = Particulas.new()
	_vapor.add_to_group("efeito_opcional")
	cenario.add_child(_vapor)
	_brilhos = Node2D.new()
	_brilhos.material = Estilo.material_soma()
	_brilhos.connect("draw", self, "_desenhar_brilhos")
	cenario.add_child(_brilhos)
	for i in 2:
		for k in 9:
			_poeira.append({"i": i, "pos": Vector2(rand_range(-0.5, 0.5), randf()), "vel": Vector2(rand_range(-0.02, 0.02), rand_range(-0.03, 0.01)),
				"fase": randf() * TAU})
	for i in 9:
		lanternas.append(null)
	_montar_letreiro()
	# as lanternas apagadas já ficam nos furos durante o COMO JOGAR
	for i in 9:
		_nascer(i, "apagada", false)


func _brilho_recortado(nome: String, centro: Vector2, largura: float) -> Sprite:
	var s = Sprite.new()
	s.texture = Estilo.tex(nome)
	s.material = Estilo.material_soma()
	s.position = centro
	s.scale = Vector2.ONE * (largura / s.texture.get_width())
	s.modulate.a = 0.0
	cenario.add_child(s)
	return s


## Letreiro da troca de rodada (SEQUÊNCIA FIXA / MEMÓRIA): uma faixa que
## entra pela direita, para no meio e sai pela esquerda.
func _montar_letreiro() -> void:
	var camada = CanvasLayer.new()
	camada.layer = 45
	add_child(camada)
	_letreiro = Control.new()
	_letreiro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letreiro.rect_size = Vector2(Tela.TELA.x, 184)
	_letreiro.rect_position = Vector2(0, Tela.TELA.y * 0.5 - 92)
	_letreiro.visible = false
	camada.add_child(_letreiro)
	var fundo = ColorRect.new()
	fundo.color = Color(0.0, 0.0, 0.02, 0.66)
	fundo.rect_size = _letreiro.rect_size
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letreiro.add_child(fundo)
	for k in 5:
		for y in [0.0, 180.0]:
			var b = ColorRect.new()
			b.rect_position = Vector2(Tela.TELA.x * k / 5.0, y)
			b.rect_size = Vector2(Tela.TELA.x / 5.0, 4)
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_letreiro.add_child(b)
			_letreiro_barras.append([b, k])
	_letreiro_txt = Estilo.rotulo(_letreiro, "", 88, Color.white, 10)
	Estilo.colocar(_letreiro_txt, Vector2(0, 14), Vector2(Tela.TELA.x, 110))
	_letreiro_sub = Estilo.rotulo(_letreiro, "", 34, Color(1.0, 0.9, 0.55), 4)
	Estilo.colocar(_letreiro_sub, Vector2(0, 118), Vector2(Tela.TELA.x, 48))
	Estilo.aquecer_fonte(Estilo.fonte(88, true, 10), "SEQUÊNCIA FIXA MEMÓRIA")
	Estilo.aquecer_fonte(Estilo.fonte(34, true, 4), "ACERTE NA ORDEM DAS CORES GRAVE")


func _mostrar_letreiro(fixo: bool) -> void:
	_letreiro_txt.text = "SEQUÊNCIA FIXA" if fixo else "MEMÓRIA"
	_letreiro_sub.text = "ACERTE NA ORDEM DAS CORES" if fixo else "GRAVE A ORDEM DAS CORES"
	for par in _letreiro_barras:
		par[0].color = CORES_FX[CORES_SEQ[par[1]]] if fixo else Color(1.0, 0.15, 0.1)
	_letreiro.visible = true
	_letreiro.modulate.a = 0.0
	var largura = Tela.TELA.x
	_letreiro_txt.rect_position.x = largura
	_letreiro_sub.rect_position.x = largura
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_letreiro, "modulate:a", 1.0, 0.2)
	tw.tween_property(_letreiro_txt, "rect_position:x", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_letreiro_sub, "rect_position:x", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.2)
	tw.chain().tween_property(_letreiro_txt, "rect_position:x", -largura, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_letreiro_sub, "rect_position:x", -largura, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_letreiro, "modulate:a", 0.0, 0.3).set_delay(0.05)
	tw.chain().tween_callback(_letreiro, "hide")


## Troca de arte da rodada: fixa = letreiro nas 5 cores, furos em neon frio,
## giroflex roxo; memória = a arena vermelha de sempre.
func _modo_arte(fixo: bool) -> void:
	_giro = 1.6
	_giro_arco = fixo
	_giro_cor = COR_MEMORIA
	_varre = 0.0
	_mostrar_letreiro(fixo)
	Maquina.efeito(_som_troca, -4.0, 1.0 if fixo else 0.86)
	if _tw_arte != null and _tw_arte.is_valid():
		_tw_arte.kill()
	_fundo_fixa.visible = true
	_fundo.visible = true
	_logo_fixa.visible = true
	_logo.visible = true
	for i in 9:
		_aneis[i].visible = true
		_aneis_fixa[i].visible = true
	_tw_arte = create_tween()
	_tw_arte.tween_property(_fundo_fixa, "modulate:a", 1.0 if fixo else 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	_tw_arte.tween_callback(self, "_arte_assentou")


## Com uma arte cobrindo a outra, a de baixo nem é desenhada (as duas são
## opacas: uma tela inteira a menos por quadro).
func _arte_assentou() -> void:
	var fixo = _fundo_fixa.modulate.a > 0.5
	_fundo.visible = not fixo
	_fundo_fixa.visible = fixo
	_logo.visible = not fixo
	_logo_fixa.visible = fixo
	for i in 9:
		_aneis[i].visible = not fixo
		_aneis_fixa[i].visible = fixo


# ------------------------------------------------------------ partida
func _comecar() -> void:
	nivel = 1
	indice = 0
	sequencia.clear()
	_nova_sequencia()


func _extra_placar() -> Array:
	if modo_fixo:
		return ["FIXA", "%d/%d" % [indice, CORES_SEQ.size()], Color(1.0, 0.85, 0.3)]
	return ["NÍVEL", str(nivel), Color(0.55, 0.9, 1.0)]


func _jogo(delta: float) -> void:
	_aviso_espera = max(0.0, _aviso_espera - delta)
	# parado muito tempo na memória: a sequência que falta acende de novo
	if mostrando or bloqueado or modo_fixo or sequencia.empty() or indice >= sequencia.size():
		_sem_jogada = 0.0
		return
	_sem_jogada += delta
	if _sem_jogada >= INATIVO_REPETE:
		_sem_jogada = 0.0
		_repetir_sequencia()


## Na hora de ver a sequência o gatilho não gasta bala (como na 4.6).
func atirar(p: Vector2) -> void:
	if estado == JOGO and (mostrando or bloqueado or sequencia.empty() or indice >= sequencia.size()):
		if _aviso_espera <= 0.0:
			_aviso_espera = 1.5
			avisos.instrucao("OBSERVE A SEQUÊNCIA!" if mostrando else "AGUARDE...", Color(0.55, 0.9, 1.0))
		return
	.atirar(p)


func _tiro(p: Vector2) -> void:
	_sem_jogada = 0.0
	var l = _lanterna_no_ponto(p)
	if l == null:
		if _tiro_no_led(p):
			bonus(BONUS_LED, p, Color(1.0, 0.45, 0.35))
			avisos.instrucao("LED ESTOURADO! +%d" % BONUS_LED, Color(1.0, 0.72, 0.62))
			return
		_marca_laser(p)
		errar(p)
		return
	if l.quebrando:
		return
	var ordem = sequencia.find(l.slot)
	if ordem == indice and (not modo_fixo or l.cor != "apagada"):
		_acertar(l, ordem, p)
	elif ordem >= 0 or not modo_fixo:
		_erro_ordem(l)
	else:
		_marca_laser(p)
		errar(p)


func _acertar(l: Lanterna, ordem: int, p: Vector2) -> void:
	var minha = _rodada
	var nome_cor = CORES_SEQ[ordem]
	var c: Color = CORES_FX[nome_cor]
	var valor = (indice + 1) * PONTOS_BASE
	var rapido = false
	if modo_fixo and ordem < _fixa_nasceu.size():
		rapido = OS.get_ticks_msec() - int(_fixa_nasceu[ordem]) < RAPIDO_MS
		if rapido:
			valor += 10
	indice += 1
	var completa = indice >= sequencia.size()
	if completa:
		bloqueado = true
	pontos += valor
	acertos += 1
	avisos.pontos(l.no.position + Vector2(0, -120), "+%d" % valor, c.linear_interpolate(Color.white, 0.3), 1.0 + ordem * 0.08)
	if rapido:
		avisos.mostrar(l.no.position + Vector2(0, -190), "RÁPIDO! +10", c.linear_interpolate(Color.white, 0.5))
	# combo de acertos seguidos; a sequência completa ganha o anúncio especial
	combo += 1
	combo_t = janela_combo
	melhor_combo = int(max(melhor_combo, combo))
	if completa:
		anuncio.especial("PERFECT SEQUENCE!")
	else:
		anuncio.combo(combo)
	if modo_fixo:
		l.quebrando = true
	Maquina.efeito(_som_lampada, -3.0, rand_range(0.95, 1.08))
	_quebrar_vidro(l, c, p)
	yield(esperar(0.22), "timeout")
	if estado != JOGO or minha != _rodada:
		return
	if modo_fixo:
		_tirar(l.slot)
	else:
		_trocar_cor(l.slot, nome_cor)
	if not completa:
		return
	if modo_fixo:
		# o bônus da fixa não conta como acerto (não é tiro)
		pontos += BONUS_FIXA
		avisos.pontos(Tela.TELA * 0.5, "+%d" % BONUS_FIXA, OURO, 1.5)
		avisos.instrucao("SEQUÊNCIA FIXA COMPLETA! +%d" % BONUS_FIXA, Color(1.0, 0.85, 0.30))
	else:
		avisos.instrucao("SEQUÊNCIA COMPLETA! NÍVEL %d!" % nivel, Color(0.30, 1.0, 0.50))
		nivel += 1
	_vitoria()
	yield(esperar(0.85), "timeout")
	if estado == JOGO and minha == _rodada:
		# cicla: memória -> fixa -> memória (um nível acima) -> ...
		if modo_fixo:
			_nova_sequencia()
		else:
			_rodada_fixa()


func _erro_ordem(l: Lanterna) -> void:
	perder(PENA_ORDEM, l.no.position + Vector2(0, -120), "ORDEM ERRADA!")
	bloqueado = true
	_rodada += 1
	var minha = _rodada
	Maquina.efeito(_som_lampada, -4.0, 0.9)
	Maquina.efeito(_som_bip_erro, -2.0)
	avisos.instrucao("ORDEM ERRADA! -%d  ·  RECOMEÇANDO..." % PENA_ORDEM, VERMELHO)
	# a lanterna quebra na cor em que estava, com cacos vermelhos, e volta
	_quebrar_vidro(l, Color(1.0, 0.08, 0.05), l.no.position)
	var tw_l = l.no.create_tween()
	tw_l.tween_interval(0.24)
	tw_l.tween_callback(self, "_voltar_quadro", [l])
	clarao(Color(1.0, 0.05, 0.02, 0.24), 0.6)
	tremer(6.0, 0.25)
	_giro = 1.3
	_giro_arco = false
	_giro_cor = Color(1.0, 0.08, 0.04)
	# todas piscam vermelho duas vezes
	for a in lanternas:
		if a == null:
			continue
		var tw = a.no.create_tween()
		tw.tween_property(a.spr, "modulate", Color(1.0, 0.15, 0.15), 0.18)
		tw.tween_property(a.spr, "modulate", Color.white, 0.18)
		tw.tween_property(a.spr, "modulate", Color(1.0, 0.15, 0.15), 0.22)
		tw.tween_property(a.spr, "modulate", Color.white, 0.24)
	yield(esperar(1.45), "timeout")
	if estado != JOGO or minha != _rodada:
		return
	if modo_fixo:
		_rodada_fixa()
	else:
		nivel = 1
		_nova_sequencia()


func _voltar_quadro(l: Lanterna) -> void:
	if l.no != null and is_instance_valid(l.no) and not l.quebrando:
		l.spr.frame = QUADRO_COR[l.cor]


# ------------------------------------------------------------ rodadas
func _nova_sequencia() -> void:
	if estado != JOGO:
		return
	_rodada += 1
	var minha = _rodada
	var vinha_da_fixa = modo_fixo
	modo_fixo = false
	bloqueado = true
	mostrando = true
	indice = 0
	sequencia.clear()
	_sem_jogada = 0.0
	_repetindo = false
	if vinha_da_fixa:
		_modo_arte(false)
	var nasceram = _preencher()
	_apagar_todas()
	yield(esperar(0.55 if nasceram else 0.35), "timeout")
	if minha != _rodada or estado != JOGO:
		return
	_apagar_todas()
	var furos = range(9)
	furos.shuffle()
	for i in min(nivel, CORES_SEQ.size()):
		sequencia.append(furos[i])
	avisos.instrucao("MEMORIZE A ORDEM DAS CORES! (%d)" % sequencia.size(), Color(0.30, 0.85, 1.0))
	yield(_mostrar_sequencia(minha, false), "completed")
	if minha != _rodada or estado != JOGO:
		return
	mostrando = false
	bloqueado = false
	avisos.instrucao("REPITA NA ORDEM DAS CORES!", Color(0.30, 0.85, 1.0))


## Depois do nível 5 a sequência continua com 5, mas acende mais rápido.
func _tempo_mostrar() -> float:
	return max(0.30, TEMPO_MOSTRAR - 0.05 * max(0, nivel - CORES_SEQ.size()))


## Acende a sequência (ou só o que falta) e apaga. Sempre espera ao menos
## uma vez: quem chama espera o "completed".
func _mostrar_sequencia(minha: int, so_faltantes: bool):
	yield(esperar(0.05), "timeout")
	if so_faltantes:
		_restaurar_memoria()
	var inicio = int(clamp(indice, 0, sequencia.size())) if so_faltantes else 0
	for i in range(inicio, sequencia.size()):
		if minha != _rodada or estado != JOGO:
			return
		var slot: int = sequencia[i]
		var nome_cor = CORES_SEQ[i]
		_trocar_cor(slot, nome_cor)
		_brilho_sequencia(slot, CORES_FX[nome_cor])
		_bip(i)
		yield(esperar(_tempo_mostrar()), "timeout")
		if minha != _rodada or estado != JOGO:
			return
		_trocar_cor(slot, "apagada")
		yield(esperar(PAUSA_ENTRE), "timeout")
	if so_faltantes:
		_restaurar_memoria()


func _repetir_sequencia() -> void:
	if _repetindo or estado != JOGO or sequencia.empty():
		return
	_repetindo = true
	bloqueado = true
	mostrando = true
	var minha = _rodada
	avisos.instrucao("RELEMBRANDO A SEQUÊNCIA...", Color(0.30, 0.85, 1.0))
	yield(esperar(0.35), "timeout")
	if minha != _rodada or estado != JOGO or modo_fixo:
		_repetindo = false
		return
	yield(_mostrar_sequencia(minha, true), "completed")
	_repetindo = false
	if minha != _rodada or estado != JOGO:
		return
	mostrando = false
	bloqueado = false
	_sem_jogada = 0.0
	avisos.instrucao("CONTINUE DE ONDE PAROU! %d/%d" % [indice, sequencia.size()], Color(0.30, 1.0, 0.60))


func _restaurar_memoria() -> void:
	_apagar_todas()
	for i in min(indice, sequencia.size()):
		_trocar_cor(sequencia[i], CORES_SEQ[i])


func _apagar_todas() -> void:
	for i in 9:
		_trocar_cor(i, "apagada")


func _rodada_fixa() -> void:
	if estado != JOGO:
		return
	_rodada += 1
	var minha = _rodada
	modo_fixo = true
	bloqueado = true
	mostrando = false
	indice = 0
	sequencia.clear()
	_sem_jogada = 0.0
	_modo_arte(true)
	avisos.instrucao("SEQUÊNCIA FIXA! ACERTE NA ORDEM DAS CORES", Color(1.0, 0.85, 0.30))
	var algum = _recolher()
	yield(esperar(0.75 if algum else 0.45), "timeout")
	if minha != _rodada or estado != JOGO:
		return
	var furos = range(9)
	furos.shuffle()
	for i in CORES_SEQ.size():
		sequencia.append(furos[i])
	_fixa_nasceu.clear()
	bloqueado = false
	for i in CORES_SEQ.size():
		if minha != _rodada or estado != JOGO:
			return
		_nascer(sequencia[i], CORES_SEQ[i])
		_fixa_nasceu.append(OS.get_ticks_msec())
		_bip(i)
		_pisca = 1.0
		_pisca_cor = CORES_FX[CORES_SEQ[i]]
		if i < CORES_SEQ.size() - 1:
			yield(esperar(rand_range(1.0, 1.5)), "timeout")


func _vitoria() -> void:
	_giro = 1.4
	_giro_arco = true
	for i in 2:
		particulas_luz.explosao(tela(GIROFLEX) + Vector2(rand_range(-40, 40), 10), {"n": 10, "tex": Estilo.tex("fx_faisca"),
			"vel": [80.0, 280.0], "ang": [200.0, 340.0], "vida": [0.4, 0.9], "tam": [10.0, 16.0], "cor": Color(1.0, 0.85, 0.5),
			"grav": 900.0, "estica": 0.04})


# ------------------------------------------------------------ lanternas
## Garante as 9 lanternas nos furos (as que faltam sobem). true = alguma subiu.
func _preencher() -> bool:
	var nasceu = false
	for i in 9:
		if lanternas[i] == null:
			_nascer(i, "apagada")
			nasceu = true
	return nasceu


func _nascer(slot: int, nome_cor: String, com_som: bool = true) -> void:
	if lanternas[slot] != null:
		return
	var l = Lanterna.new()
	l.slot = slot
	l.cor = nome_cor
	l.no = Node2D.new()
	l.no.position = _furos_tela[slot]
	alvos.add_child(l.no)
	l.spr = Sprite.new()
	l.spr.texture = _f["tex"]
	l.spr.hframes = _f["quadros"]
	l.spr.frame = QUADRO_COR[nome_cor]
	l.spr.scale = Vector2.ONE * _esc_lanterna
	l.no.add_child(l.spr)
	lanternas[slot] = l
	if not com_som:
		return
	Maquina.efeito(_som_sobe, -13.0 if nome_cor == "apagada" else -8.0, rand_range(0.92, 1.08))
	# sobe do furo (um tranco de leve no fim)
	l.spr.position = Vector2(0, SUBIDA)
	l.spr.modulate.a = 0.0
	var tw = l.no.create_tween().set_parallel(true)
	tw.tween_property(l.spr, "position", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l.spr, "modulate:a", 1.0, 0.16)
	if nome_cor != "apagada":
		luz_sprite_breve(l.no.position, 260.0, Color(CORES_FX[nome_cor].r, CORES_FX[nome_cor].g, CORES_FX[nome_cor].b, 0.7), 0.4)


## cor: "apagada" ou uma das CORES_SEQ.
func _trocar_cor(slot: int, nome_cor: String) -> void:
	var l = lanternas[slot]
	if l == null or l.quebrando:
		return
	l.cor = nome_cor
	l.spr.frame = QUADRO_COR[nome_cor]
	l.spr.modulate = Color.white
	l.spr.scale = Vector2.ONE * _esc_lanterna


## Todas descem para dentro dos furos e somem. true = havia alguma.
func _recolher() -> bool:
	var algum = false
	for i in 9:
		var l = lanternas[i]
		if l == null:
			continue
		algum = true
		_descer(l, 70.0, 0.26)
		lanternas[i] = null
	if algum:
		Maquina.efeito(_som_desce, -6.0)
	return algum


## Uma lanterna sai do furo (acertada na rodada fixa).
func _tirar(slot: int) -> void:
	var l = lanternas[slot]
	if l == null:
		return
	lanternas[slot] = null
	Maquina.efeito(_som_desce, -11.0, rand_range(1.0, 1.15))
	_descer(l, 50.0, 0.22)


func _descer(l: Lanterna, dist: float, dur: float) -> void:
	l.quebrando = true
	var tw = l.no.create_tween().set_parallel(true)
	tw.tween_property(l.spr, "position", Vector2(0, dist), dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(l.spr, "modulate:a", 0.0, dur - 0.02)
	tw.chain().tween_callback(l.no, "queue_free")


func _lanterna_no_ponto(p: Vector2) -> Lanterna:
	for l in lanternas:
		if l == null:
			continue
		if acerta_sprite(l.spr, _f["mascara"], _f["cel"], p, 1):
			return l
	return null


## O acerto: a lanterna estoura na cor dela (quadro quebrado, clarão, cacos
## de vidro colorido voando e caindo, faíscas e a luz batendo na parede).
func _quebrar_vidro(l: Lanterna, c: Color, p: Vector2) -> void:
	l.spr.frame = _f["acerto"][QUADRO_COR[l.cor]]
	l.spr.modulate = Color(1.0 + c.r, 1.0 + c.g, 1.0 + c.b)
	var tw = l.no.create_tween().set_parallel(true)
	tw.tween_property(l.spr, "scale", Vector2.ONE * _esc_lanterna * 1.22, 0.06)
	tw.tween_property(l.spr, "modulate", Color.white, 0.20)
	tw.chain().tween_property(l.spr, "scale", Vector2.ONE * _esc_lanterna, 0.14)
	var centro = l.no.position
	particulas.explosao(centro, {"n": 22, "tex": Estilo.tex("fx_caco"), "vel": [220.0, 620.0], "vida": [0.45, 1.1], "tam": [8.0, 18.0],
		"cor": c.linear_interpolate(Color.white, 0.15), "grav": 1100.0, "arrasto": 0.4, "giro": [-14.0, 14.0], "espalha": 22.0})
	particulas.explosao(centro, {"n": 8, "tex": Estilo.tex("fx_caco"), "vel": [160.0, 420.0], "vida": [0.4, 0.9], "tam": [6.0, 12.0],
		"cor": Color(1.0, 0.94, 0.94), "grav": 1100.0, "giro": [-14.0, 14.0], "espalha": 18.0})
	particulas_luz.explosao(centro, {"n": 16, "vel": [180.0, 520.0], "vida": [0.3, 0.7], "tam": [6.0, 14.0], "cor": c, "grav": 400.0, "estica": 0.03})
	particulas_luz.explosao(p, {"n": 6, "tex": Estilo.tex("fx_estrela"), "vel": [40.0, 160.0], "vida": [0.25, 0.45], "tam": [26.0, 44.0], "fim": 0.1,
		"cor": c.linear_interpolate(Color.white, 0.4)})
	luz_sprite_breve(centro, 360.0, Color(c.r, c.g, c.b, 0.85), 0.45)
	luz_sprite_breve(centro, 150.0, Color(1, 1, 1, 0.8), 0.18)


## A lanterna da vez acende na sequência: pulo, clarão e faíscas na cor.
func _brilho_sequencia(slot: int, c: Color) -> void:
	var l = lanternas[slot]
	if l == null:
		return
	l.spr.modulate = Color(1.7, 1.7, 1.7)
	l.spr.scale = Vector2.ONE * _esc_lanterna
	var tw = l.no.create_tween().set_parallel(true)
	tw.tween_property(l.spr, "scale", Vector2.ONE * _esc_lanterna * 1.18, 0.08)
	tw.tween_property(l.spr, "modulate", Color.white, 0.22)
	tw.chain().tween_property(l.spr, "scale", Vector2.ONE * _esc_lanterna, 0.14)
	particulas_luz.explosao(l.no.position, {"n": 14, "vel": [160.0, 480.0], "vida": [0.4, 0.9], "tam": [6.0, 14.0], "cor": c, "arrasto": 1.2})
	luz_sprite_breve(l.no.position, 320.0, Color(c.r, c.g, c.b, 0.75), 0.5)
	_pisca = 1.0
	_pisca_cor = c


func _bip(ordem: int) -> void:
	Maquina.efeito(_som_bip, 0.0, TONS_BIP[ordem] if ordem >= 0 and ordem < TONS_BIP.size() else 1.0)


# ------------------------------------------------------------ parede
## O laser que erra queima a parede: marca escura com a borda em brasa que
## esfria, fumaça subindo e lascas de metal.
func _marca_laser(p: Vector2) -> void:
	Maquina.efeito(_som_parede, -6.0, rand_range(0.9, 1.1))
	_marcas.append({"pos": p, "raio": rand_range(7.0, 10.0), "t": 0.0, "giro": randf() * TAU})
	while _marcas.size() > 40:
		_marcas.pop_front()
	_brasas = true
	_parede.update()
	particulas.explosao(p, {"n": 5, "tex": Estilo.tex("fx_fumaca"), "vel": [20.0, 70.0], "ang": [230.0, 310.0], "vida": [0.7, 1.3],
		"tam": [26.0, 40.0], "fim": 2.2, "cor": Color(0.08, 0.08, 0.09, 0.5), "grav": -60.0, "giro": [-1.0, 1.0]})
	particulas_luz.explosao(p, {"n": 12, "tex": Estilo.tex("fx_faisca"), "vel": [120.0, 380.0], "vida": [0.25, 0.6], "tam": [8.0, 14.0],
		"cor": Color(1.0, 0.75, 0.45), "grav": 700.0, "estica": 0.035})
	particulas.explosao(p, {"n": 6, "tex": Estilo.tex("fx_caco"), "vel": [90.0, 300.0], "vida": [0.3, 0.7], "tam": [4.0, 8.0],
		"cor": Color(0.62, 0.62, 0.66), "grav": 1000.0, "giro": [-12.0, 12.0]})
	luz_sprite_breve(p, 90.0, Color(1.0, 0.45, 0.35, 0.7), 0.2)


## Tiro no LED do alto: estoura (true se pegou nele aceso).
func _tiro_no_led(p: Vector2) -> bool:
	if _led > 0.0:
		return false
	if not LED_CAIXA.grow(16.0).has_point(imagem(p)):
		return false
	_led = LED_APAGADO
	_led_clarao = 1.0
	_led_fumaca = 0.0
	var g = tela(GIROFLEX)
	particulas_luz.explosao(g, {"n": 26, "tex": Estilo.tex("fx_faisca"), "vel": [120.0, 360.0], "ang": [180.0, 360.0], "vida": [0.4, 0.9],
		"tam": [10.0, 16.0], "cor": Color(1.0, 0.8, 0.45), "grav": 900.0, "estica": 0.04})
	# o vidro vermelho da lâmpada se parte e cai (cacos da própria pintura)
	var esc = Tela.TELA.x / 1080.0
	var caixa = Rect2(tela(LED_CAIXA.position), LED_CAIXA.size * K_FUNDO)
	var px = Rect2(caixa.position / esc, caixa.size / esc)
	var tex = _fundo_fixa.texture if modo_fixo else _fundo.texture
	cacos.estourar(tex, px, Transform2D(Vector2(esc, 0), Vector2(0, esc), caixa.position + caixa.size * 0.5), p,
		{"n": 8, "forca": 0.7, "grav": 1200.0, "vida": 1.3, "sobe": 120.0})
	particulas.explosao(g, {"n": 14, "tex": Estilo.tex("fx_caco"), "vel": [60.0, 200.0], "ang": [200.0, 340.0], "vida": [0.8, 1.4],
		"tam": [5.0, 10.0], "cor": Color(1.0, 0.25, 0.18), "grav": 900.0, "giro": [-14.0, 14.0]})
	Maquina.efeito(_som_led, -4.0, rand_range(0.95, 1.05))
	tremer(4.0, 0.15)
	_parede.update()
	return true


## Quanto a luz do alto está acesa agora (0 apagada .. 1; pisca ao voltar).
func _led_aceso() -> float:
	if _led <= 0.0:
		return 1.0
	if _led < 1.4:
		return 1.0 if fmod(_led * 6.5, 1.0) > 0.35 + 0.4 * (_led / 1.4) else 0.0
	return 0.0


func _encerrou() -> void:
	_rodada += 1
	bloqueado = true
	mostrando = false
	for i in 9:
		var l = lanternas[i]
		if l == null:
			continue
		var tw = l.no.create_tween()
		tw.tween_property(l.no, "modulate:a", 0.0, 0.4)
		tw.tween_callback(l.no, "queue_free")
		lanternas[i] = null


# ------------------------------------------------------------ vida da arena
func _sempre(delta: float) -> void:
	_t += delta
	var som = Maquina.pulso_vivo()
	# o logo e os anéis acendem com a música (a cor do furo pisca na sequência)
	var a_logo = clamp(0.10 + 0.45 * som.x + 0.35 * som.y + 0.08 * sin(_t * 2.3), 0.0, 1.0)
	var a_led = _led_aceso()
	_logo.modulate.a = a_logo * (0.35 + 0.65 * a_led)
	_logo_fixa.modulate.a = _logo.modulate.a
	for i in 9:
		var a = clamp(0.12 + 0.5 * som.x + 0.3 * som.y + 0.15 * sin(_t * 3.1 + i * 1.7), 0.0, 1.0)
		_aneis[i].modulate.a = a
		_aneis_fixa[i].modulate.a = a
	_giro = max(0.0, _giro - delta)
	_pisca = max(0.0, _pisca - delta * 2.6)
	if _led > 0.0 or _led_clarao > 0.0:
		_animar_led(delta)
	if _varre >= 0.0:
		_varre += delta / 0.9
		if _varre > 1.0:
			_varre = -1.0
	# vapor dos canos e faíscas da caixa elétrica, de vez em quando
	_prox_vapor -= delta
	if _prox_vapor <= 0.0:
		_prox_vapor = rand_range(4.0, 8.5)
		var v: Vector2 = VAPOR[randi() % VAPOR.size()]
		var dir = -1.0 if v.x > 512.0 else 1.0
		Maquina.efeito(_som_vapor, -17.0, rand_range(0.85, 1.15))
		_vapor.explosao(tela(v), {"n": 9, "tex": Estilo.tex("fx_nuvem"), "vel": [40.0, 110.0], "ang": [-50.0 if dir > 0 else 192.0, -12.0 if dir > 0 else 230.0],
			"vida": [1.2, 2.0], "tam": [30.0, 50.0], "fim": 3.0, "cor": Color(0.78, 0.80, 0.84, 0.30), "grav": -16.0, "arrasto": 0.6})
	_prox_faisca -= delta
	if _prox_faisca <= 0.0:
		_prox_faisca = rand_range(6.0, 13.0)
		particulas_luz.explosao(tela(CAIXA_ELETRICA), {"n": randi() % 7 + 8, "tex": Estilo.tex("fx_faisca"), "vel": [80.0, 300.0], "ang": [190.0, 350.0],
			"vida": [0.4, 0.9], "tam": [8.0, 14.0], "cor": Color(1.0, 0.75, 0.3), "grav": 900.0, "estica": 0.035})
		luz_sprite_breve(tela(CAIXA_ELETRICA), 120.0, Color(1.0, 0.7, 0.3, 0.6), 0.3)
		Maquina.efeito(_som_faisca, -15.0, rand_range(0.9, 1.1))
	for p in _poeira:
		p["pos"] += p["vel"] * delta
		if p["pos"].y < 0.0 or p["pos"].y > 1.0 or abs(p["pos"].x) > 0.6:
			p["pos"] = Vector2(rand_range(-0.5, 0.5), rand_range(0.6, 1.0))
	if _brasas:
		_brasas = false
		for m in _marcas:
			m["t"] += delta
			if m["t"] < 1.6:
				_brasas = true
		_parede.update()
	_brilhos.update()


func _animar_led(delta: float) -> void:
	var antes = _led
	_led = max(0.0, _led - delta)
	_led_clarao = max(0.0, _led_clarao - delta * 2.4)
	if _led > 1.4:
		# a lâmpada queimada solta fumaça e de vez em quando estala
		_led_fumaca -= delta
		if _led_fumaca <= 0.0:
			_led_fumaca = rand_range(0.25, 0.5)
			var g = tela(GIROFLEX)
			_vapor.soltar(g + Vector2(rand_range(-10.0, 10.0), -4.0), Vector2(rand_range(-12.0, 12.0), rand_range(-40.0, -22.0)), rand_range(1.0, 1.6),
				18.0, 44.0, Color(0.55, 0.55, 0.58, 0.35), Color(0.55, 0.55, 0.58, 0.0), Estilo.tex("fx_nuvem"))
			if randf() < 0.18:
				particulas_luz.explosao(g, {"n": randi() % 4 + 3, "tex": Estilo.tex("fx_faisca"), "vel": [60.0, 200.0], "ang": [190.0, 350.0],
					"vida": [0.3, 0.6], "tam": [8.0, 12.0], "cor": Color(1.0, 0.75, 0.3), "grav": 900.0, "estica": 0.035})
	if antes >= 1.4 and _led < 1.4:
		Maquina.efeito(_som_faisca, -14.0, 1.3)        # religando
	if (antes > 0.0) != (_led > 0.0) or _led < 1.4:
		_parede.update()


func _desenhar_parede() -> void:
	var brilho = Estilo.tex("fx_brilho")
	var ponto = Estilo.tex("fx_ponto")
	# marcas do laser: queimado escuro, miolo preto e a borda em brasa esfriando
	for m in _marcas:
		var p: Vector2 = m["pos"]
		var r: float = m["raio"]
		_parede.draw_texture_rect(brilho, Rect2(p - Vector2(r, r) * 3.2, Vector2(r, r) * 6.4), false, Color(0.0, 0.0, 0.0, 0.55))
		_parede.draw_texture_rect(ponto, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(0.02, 0.02, 0.02, 0.95))
		var k = clamp(1.0 - m["t"] / 1.6, 0.0, 1.0)
		if k > 0.0:
			_parede.draw_texture_rect(brilho, Rect2(p - Vector2(r, r) * 1.6, Vector2(r, r) * 3.2), false, Color(1.0, 0.45 + 0.3 * k, 0.15, 0.85 * k))
	# a luz do alto queimada: vidro escuro, trincado, e a parede sem o brilho
	if _led_aceso() < 0.5:
		var esc = K_FUNDO
		var g = tela(GIROFLEX)
		_parede.draw_texture_rect(brilho, Rect2(g + Vector2(-78, -70) * esc, Vector2(156, 156) * esc), false, Color(0, 0, 0, 0.62))
		_parede.draw_texture_rect(brilho, Rect2(g + Vector2(-92, -58) * esc, Vector2(184, 184) * esc), false, Color(0, 0, 0, 0.5))
		var r = Rect2(tela(LED_CAIXA.position + Vector2(3, 3)), (LED_CAIXA.size - Vector2(6, 6)) * esc)
		_parede.draw_rect(r, Color(0.10, 0.03, 0.03, 0.96))
		_parede.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.35)), Color(0.35, 0.12, 0.12, 0.35))
		var c = r.position + r.size * 0.5 + Vector2(-4.0, 1.0) * esc
		for k in 5:
			var ang = k * 1.3 + 0.4
			_parede.draw_line(c, c + Vector2(cos(ang), sin(ang) * 0.5) * r.size.x * 0.42, Color(0.75, 0.62, 0.62, 0.55), 1.2)


func _desenhar_brilhos() -> void:
	var esc = K_FUNDO
	var som = Maquina.pulso_vivo()
	var brilho = Estilo.tex("fx_brilho")
	# fachos das arandelas descendo a parede (os dois num desenho) e a poeira
	for i in 2:
		var a = tela(ARANDELAS[i])
		var dir = 1.0 if i == 0 else -1.0
		var comp = 520.0 * esc
		var c = Color(1.0, 0.92, 0.78, 0.06 + 0.03 * som.x)
		var c0 = Color(c.r, c.g, c.b, 0.0)
		_brilhos.draw_polygon(PoolVector2Array([a + Vector2(-8 * esc, 4), a + Vector2(8 * esc, 4),
			a + Vector2(dir * 210.0 * esc + 90.0 * esc, comp), a + Vector2(dir * 210.0 * esc - 90.0 * esc, comp)]),
			PoolColorArray([c, c, c0, c0]))
	for p in _poeira:
		var i: int = p["i"]
		var a2 = tela(ARANDELAS[i])
		var dir2 = 1.0 if i == 0 else -1.0
		var y: float = p["pos"].y
		var x: float = p["pos"].x * (16.0 + 180.0 * y)
		var pos = a2 + Vector2((dir2 * 210.0 * y + x) * esc, 520.0 * y * esc)
		var luz_p = (0.5 + 0.5 * sin(_t * 1.7 + p["fase"])) * (1.0 - y) * 0.55
		_brilhos.draw_texture_rect(brilho, Rect2(pos - Vector2(5, 5), Vector2(10, 10)), false, Color(1.0, 0.92, 0.8, luz_p))
	# giroflex
	var g = tela(GIROFLEX)
	var cor_g = COR_FIXA if modo_fixo else COR_MEMORIA
	if _pisca > 0.0:
		cor_g = cor_g.linear_interpolate(_pisca_cor, _pisca)
	var aceso = _led_aceso()
	if aceso > 0.0:
		var r = (34.0 + 26.0 * _pisca + 10.0 * som.y) * esc * 2.0
		_brilhos.draw_texture_rect(brilho, Rect2(g - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(cor_g.r, cor_g.g, cor_g.b, (0.35 + 0.4 * _pisca) * aceso))
	if _led_clarao > 0.0:
		var kc = 1.0 - _led_clarao
		var r1 = (60.0 + 260.0 * kc) * esc * 2.0
		var r2 = (30.0 + 60.0 * kc) * esc * 2.0
		_brilhos.draw_texture_rect(brilho, Rect2(g - Vector2(r1, r1), Vector2(r1, r1) * 2.0), false, Color(1.0, 0.85, 0.75, 0.9 * _led_clarao))
		_brilhos.draw_texture_rect(brilho, Rect2(g - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false, Color(1, 1, 1, _led_clarao))
	if _giro > 0.0 and aceso > 0.0:
		var forca = min(1.0, _giro / 0.4)
		for k in 2:
			var ang = _t * 7.5 + k * PI
			var c3 = _giro_cor
			if _giro_arco:
				c3 = Color.from_hsv(fmod(_t * 0.9 + k * 0.5, 1.0), 0.85, 1.0)
			var d = Vector2(cos(ang), sin(ang) * 0.45 + 0.35)
			var ponta = g + d * 900.0 * esc
			var lado = Vector2(-d.y, d.x) * 170.0 * esc
			_brilhos.draw_polygon(PoolVector2Array([g, ponta + lado, ponta - lado]),
				PoolColorArray([Color(c3.r, c3.g, c3.b, 0.20 * forca), Color(c3.r, c3.g, c3.b, 0.0), Color(c3.r, c3.g, c3.b, 0.0)]))
		var cg = Color.white if _giro_arco else _giro_cor
		var rg = 70.0 * esc * 2.0
		_brilhos.draw_texture_rect(brilho, Rect2(g - Vector2(rg, rg), Vector2(rg, rg) * 2.0), false, Color(cg.r, cg.g, cg.b, 0.4 * forca))
	# varredura colorida descendo a parede na troca de rodada
	if _varre >= 0.0:
		var y2 = lerp(tela(Vector2(0, 470)).y, tela(Vector2(0, 1300)).y, _varre)
		var a3 = sin(_varre * PI)
		for k3 in 5:
			var c4 = CORES_FX[CORES_SEQ[k3]] if modo_fixo else Color(1.0, 0.15, 0.1)
			var x0 = Tela.TELA.x * k3 / 5.0
			_brilhos.draw_texture_rect(brilho, Rect2(Vector2(x0, y2 - 26), Vector2(Tela.TELA.x / 5.0, 52)), false, Color(c4.r, c4.g, c4.b, 0.35 * a3))
			_brilhos.draw_rect(Rect2(Vector2(x0, y2 - 2.5), Vector2(Tela.TELA.x / 5.0, 5)), Color(c4.r, c4.g, c4.b, 0.9 * a3))
	_desenhar_ordem(esc, brilho)


## Faixa da ordem: 5 luzes (1 a 5) embaixo dos furos; a próxima pulsa.
func _desenhar_ordem(esc: float, brilho: Texture) -> void:
	if estado != JOGO:
		return
	var total = sequencia.size()
	if total <= 0:
		return
	var ponto = Estilo.tex("fx_ponto")
	var anel = Estilo.tex("fx_anel")
	var y = tela(Vector2(0, Y_ORDEM)).y
	var passo = 70.0 * esc
	var x0 = Tela.TELA.x * 0.5 - passo * (CORES_SEQ.size() - 1) * 0.5
	for i in CORES_SEQ.size():
		var c: Color = CORES_FX[CORES_SEQ[i]]
		var p = Vector2(x0 + passo * i, y)
		var r = 15.0 * esc
		if i >= total:
			_brilhos.draw_texture_rect(ponto, Rect2(p - Vector2(r, r) * 0.7, Vector2(r, r) * 1.4), false, Color(c.r, c.g, c.b, 0.10))
			continue
		var feita = i < indice
		var vez = i == indice and not mostrando
		var a = 0.35
		if feita:
			a = 0.9
		elif vez:
			a = 0.65 + 0.35 * sin(_t * 8.0)
			_brilhos.draw_texture_rect(brilho, Rect2(p - Vector2(r, r) * 3.2, Vector2(r, r) * 6.4), false, Color(c.r, c.g, c.b, 0.45))
			_brilhos.draw_texture_rect(anel, Rect2(p - Vector2(r, r) * 1.7, Vector2(r, r) * 3.4), false, Color(c.r, c.g, c.b, 0.9))
		_brilhos.draw_texture_rect(brilho, Rect2(p - Vector2(r, r) * 1.9, Vector2(r, r) * 3.8), false, Color(c.r, c.g, c.b, a * 0.5))
		_brilhos.draw_texture_rect(ponto, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(c.r, c.g, c.b, a))
		_brilhos.draw_texture_rect(ponto, Rect2(p - Vector2(r, r) * 0.45, Vector2(r, r) * 0.9), false, Color(1, 1, 1, a * 0.8))


## Teste automático (robô): a próxima lanterna certa (ou o LED de vez em quando).
func robo_alvo():
	if estado != JOGO or mostrando or bloqueado or indice >= sequencia.size():
		return null
	if _led <= 0.0 and int(_t) % 23 == 0:
		return tela(GIROFLEX)
	var l = lanternas[sequencia[indice]]
	if l == null or l.quebrando or (modo_fixo and l.cor == "apagada"):
		return null
	return l.no.position
