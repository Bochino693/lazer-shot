extends Node

## A MIRA DO JOGO INTEIRO e o RITMO DE QUADROS.
##
## Há UMA mira, aqui; cada tela lê `MiraGlobal.mira()` e desenha/acerta
## exatamente ali. O tiro sai EXATAMENTE na mira (sem recuo que desvie a
## bala): a arma de verdade aponta onde aponta.
##
## A ARMA é um mouse (a de giroscópio da máquina). Dois jeitos de virar mira,
## escolhidos sozinhos (CONFIGURAÇÃO -> ARMA E MIRA -> Tipo de arma: AUTO):
##   - A MIRA É A SETA (com a janela em pé, ver `Tela`): o Android gira a
##     tela, a seta do mouse anda no sentido da arma e cobre a tela inteira;
##     a mira fica em cima dela, com um filtro leve (1€) que tira o tremor da
##     mão parada sem atrasar o movimento rápido. Nada pula: a borda da seta é
##     a borda da tela.
##   - GIROSCÓPIO (reserva, quando a janela fica deitada e o jogo gira por
##     dentro): a seta anda de lado em relação ao jogo e para na borda curta
##     do HDMI, então a mira soma o MOVIMENTO da seta, na mesma medida nos
##     dois eixos, sem a aceleração do Android, vezes a SENSIBILIDADE. A
##     sensibilidade AUTO faz a seta, de uma borda à outra do HDMI, cobrir a
##     altura inteira do jogo: a mira chega na borda junto com a seta (sem o
##     salto de quando a seta parava antes). Calibrável atirando em 4 alvos.
## Tipo ABSOLUTA força a mira na seta; GIROSCÓPIO força o movimento.
## A SENSIBILIDADE (CONFIGURAÇÃO) vale nos dois: no giroscópio multiplica o
## movimento; na seta, AUTO é a própria seta e um número faz a mira andar
## mais ou menos que ela (ver `_com_ganho`).
##
## A SETA DO SISTEMA: no Android 7.1 o Godot 3.6 não esconde o ponteiro (só
## do Android 8 em diante); ela vira uma imagem transparente (cursor
## próprio, Android 7.0+) em todos os formatos, refeita a cada tela nova e
## quando o jogo volta ao foco. Se a TV Box ainda mostrar a seta, com a tela
## girada pelo Android ela fica em cima da mira, andando junto.
##
## RITMO: a TV é de 60 Hz. Uma tela que não segura 60 quadros alterna 16 e
## 33 ms e isso aparece como tranco; se em 2 s mais de um quarto dos quadros
## passou de 20 ms, os enfeites (grupo "efeito_opcional") somem nela primeiro
## (a mira continua a 60); se ainda assim não segura, a tela fica em 30 por
## segundo cravados (liso). A TV Box lembra (user://ritmo.cfg).

# a aceleração do ponteiro do Android (VelocityControl, igual do 4.1 ao 7.1)
const ACEL_BAIXA = 500.0       # px/s: até aqui o Android não acelera
const ACEL_ALTA = 3000.0       # px/s: daqui para cima acelera o máximo
const ACEL_MAX = 3.0
const BORDA_PX = 0.75          # ponteiro a até isto da borda da janela = parado nela
const BORDA_VOLTA = 10.0       # 1/s: a mira indo para a borda (suave)
const SENS_MIN = 0.2
const SENS_MAX = 4.0
# filtro 1€ da mira na seta (Casiez, Roussel e Vogel): corte baixo parado
# (tira o tremor) e alto em movimento (não atrasa)
const FILTRO_CORTE = 2.4       # Hz com a arma parada
const FILTRO_BETA = 0.012      # quanto o corte sobe por px/s
const FILTRO_D = 1.0           # Hz do corte da velocidade
const FILTRO_SEGUE = 0.35      # s filtrando depois do último movimento

const RITMO_ARQUIVO = "user://ritmo.cfg"
const RITMO_JANELA = 2.0
const RITMO_LENTO_MS = 20.0
const RITMO_FRACAO = 0.25

var pos = Vector2(512, 910)
var ativa = true              # false: a tela não mostra mira (abertura)

## A mira soma o movimento (giroscópio) ou fica na seta (absoluta)? Muda
## sozinha com quem gira a tela (tipo AUTO).
var giroscopio = false
var sensibilidade = 1.0
var compensar = true
## Soma do movimento da arma em pontos do jogo, sem a sensibilidade e sem a
## aceleração do Android (a calibragem mede a arma por aqui).
var movimento = Vector2.ZERO
## O ponteiro encostou numa borda da janela desde `zerar_borda()`?
var bateu_borda = false
## Em que eixo do jogo foi a borda (1 no eixo tocado): preso numa borda, o
## ponteiro só deixa de andar naquele sentido.
var bordas_eixos = Vector2.ZERO
## Último ponto do ponteiro do sistema (pixels da janela).
var ponteiro = Vector2(-1, -1)

var _tipo = "auto"
var _sens_auto = true
var _android = false
var _seta: ImageTexture
var _seta_cena = 0
var _seta_ms = 0               # quando a seta transparente foi reaplicada
var _ultimo = Vector2(INF, INF)
var _quadro_d = Vector2.ZERO   # o quanto o ponteiro andou neste quadro (pixels da janela)
var _na_borda = Vector2.ZERO   # borda do jogo para onde a arma passou (-1, 0, 1 em cada eixo)
var _alvo = Vector2(512, 910)  # a seta no jogo (mira absoluta), antes do filtro
var _segue = 0.0               # s que o filtro ainda anda
var _f_x = Vector2(512, 910)
var _f_v = Vector2.ZERO

var _ritmo_lento = {}
var _telas_leves = {}
var _ritmo_cena = 0
var _ritmo_t = 0.0
var _ritmo_quadros = 0
var _ritmo_lentos = 0
var _ritmo_ultimo = 0


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	process_priority = -100     # atualiza antes das telas lerem
	_android = OS.get_name() == "Android"
	OS.vsync_enabled = true
	Engine.target_fps = 0
	Engine.iterations_per_second = 30
	_ritmo_carregar()
	_esconder_seta(true)
	aplicar_config()
	Maquina.connect("config_mudou", self, "aplicar_config")


## Lê o tipo de arma, a sensibilidade e a correção da aceleração.
func aplicar_config() -> void:
	_tipo = str(Maquina.valor("arma/modo"))
	if OS.has_environment("LAZER_ARMA"):
		_tipo = OS.get_environment("LAZER_ARMA")
	elif not _android:
		_tipo = "absoluta"      # no PC o mouse marca o ponto
	var s = float(Maquina.valor("arma/sensibilidade"))
	_sens_auto = s <= 0.0
	sensibilidade = clamp(s, SENS_MIN, SENS_MAX)
	compensar = bool(Maquina.valor("arma/compensar_aceleracao"))
	_atualizar_modo()


## Giroscópio ou seta, pelo tipo e por quem gira a tela agora.
func _atualizar_modo() -> void:
	var giro_antes = giroscopio
	giroscopio = _tipo == "giroscopio" or (_tipo == "auto" and Tela.giro != 0)
	if _sens_auto:
		sensibilidade = sensibilidade_cobertura()
	if giroscopio != giro_antes:
		_ultimo = Vector2(INF, INF)
		_quadro_d = Vector2.ZERO
		_alvo = pos
		_f_x = pos
		_f_v = Vector2.ZERO


## A sensibilidade em que a seta, de uma borda à outra da janela no sentido
## da altura do jogo, leva a mira do alto ao pé da tela (a sensibilidade AUTO
## do giroscópio).
func sensibilidade_cobertura() -> float:
	var j = Tela.janela()
	if j.x <= 0.0 or j.y <= 0.0:
		return 1.0
	# o eixo da janela que anda junto com a altura do jogo
	var altura = j.y if (Tela.giro == 0 or Tela.mira_direta) else j.x
	return clamp(Tela.TELA.y * Tela.px_por_ponto() / altura, SENS_MIN, SENS_MAX)


## A seta do sistema some: no PC o modo escondido; no Android 7 (onde o Godot
## 3.6 não esconde o ponteiro) uma seta transparente própria. O Godot 3.6
## aplica a imagem no formato ATUAL e depois troca para o pedido: com
## `todos`, duas chamadas por formato deixam todos transparentes.
func _esconder_seta(todos: bool = false) -> void:
	if _seta == null:
		var img = Image.new()
		img.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var caminho = "user://seta_vazia.png"
		img.save_png(caminho)
		_seta = ImageTexture.new()
		_seta.create_from_image(img, 0)
		# o Android lê a imagem pelo caminho do arquivo (PointerIcon)
		_seta.resource_path = caminho
		Tela.marca("seta do sistema transparente")
	if todos:
		for f in range(Input.CURSOR_HELP + 1):
			Input.set_custom_mouse_cursor(_seta, f, Vector2.ZERO)
			Input.set_custom_mouse_cursor(_seta, f, Vector2.ZERO)
	Input.set_custom_mouse_cursor(_seta, Input.CURSOR_ARROW, Vector2.ZERO)
	Input.set_custom_mouse_cursor(_seta, Input.CURSOR_ARROW, Vector2.ZERO)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_seta_ms = OS.get_ticks_msec()


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_FOCUS_IN:
		_esconder_seta(true)
		# voltando ao foco o ponteiro pode ter andado por fora: recomeça a
		# conta do movimento a partir do próximo evento
		_ultimo = Vector2(INF, INF)


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion or event is InputEventMouseButton):
		return
	# o Android de algumas TV Box volta a mostrar a seta normal (troca de
	# janela, foco, giro da tela): com a arma andando, a transparente é
	# reaplicada uma vez por segundo
	if _android and OS.get_ticks_msec() - _seta_ms > 1000:
		_esconder_seta()
	if giroscopio:
		if event is InputEventMouseMotion:
			_mover(event.global_position)
		return
	var tela = Tela.TELA
	var p: Vector2
	if Tela.giro != 0 and Tela.mira_direta:
		# a posição crua do HDMI (global_position não passa pelo giro)
		p = Tela.hdmi_para_jogo_direto(event.global_position)
	else:
		p = event.position
	_alvo = _com_ganho(Vector2(clamp(p.x, 0.0, tela.x), clamp(p.y, 0.0, tela.y)))
	if event is InputEventMouseButton:
		# o clique vale onde a seta está: a mira vai junto na hora
		pos = _alvo
		_f_x = _alvo
		_f_v = Vector2.ZERO
		_segue = 0.0
	else:
		_segue = FILTRO_SEGUE


## A seta com a sensibilidade escolhida (AUTO: a mira é a própria seta). No
## meio da tela a mira anda `sensibilidade` vezes o que a seta anda; perto
## da borda ela acerta o passo para chegar na borda junto com a seta (abaixo
## de 1) ou para na borda antes (acima de 1). É sempre a mesma conta da
## posição da seta: a mira nunca escorrega para longe dela.
func _com_ganho(p: Vector2) -> Vector2:
	if _sens_auto:
		return p
	var meio = Tela.TELA * 0.5
	return Vector2(meio.x * (1.0 + _curva((p.x - meio.x) / meio.x)), meio.y * (1.0 + _curva((p.y - meio.y) / meio.y)))


func _curva(u: float) -> float:
	var a = abs(u)
	var r: float
	if sensibilidade >= 1.0:
		r = min(1.0, a * sensibilidade)
	else:
		var u0 = 0.85
		r = a * sensibilidade if a <= u0 else lerp(u0 * sensibilidade, 1.0, (a - u0) / (1.0 - u0))
	return r * sign(u)


## A mira na seta, pelo filtro 1€ (um passo por quadro).
func _seguir_seta(delta: float) -> void:
	if _segue <= 0.0:
		return
	_segue -= delta
	if delta <= 0.0:
		return
	if _f_x.distance_squared_to(pos) > 0.25:
		# alguém levou a mira para outro lugar (tela nova): recomeça dali
		_f_x = pos
		_f_v = Vector2.ZERO
	var v = (_alvo - _f_x) / delta
	_f_v = _f_v.linear_interpolate(v, _alfa(FILTRO_D, delta))
	var corte = FILTRO_CORTE + FILTRO_BETA * _f_v.length()
	_f_x = _f_x.linear_interpolate(_alvo, _alfa(corte, delta))
	if _segue <= 0.0:
		_f_x = _alvo          # parou: a mira assenta em cima da seta
	pos = _f_x


static func _alfa(corte: float, dt: float) -> float:
	var tau = 1.0 / (TAU * corte)
	return 1.0 / (1.0 + tau / dt)


## Arma de giroscópio: guarda o quanto o ponteiro andou (a mira anda no
## `_process`, com a velocidade do quadro) e vê se ele parou numa borda.
func _mover(p: Vector2) -> void:
	ponteiro = p
	if _ultimo.x != INF:
		_quadro_d += p - _ultimo
	_ultimo = p
	_na_borda = _borda(p)
	if _na_borda != Vector2.ZERO:
		bateu_borda = true
		bordas_eixos = Vector2(max(bordas_eixos.x, abs(_na_borda.x)), max(bordas_eixos.y, abs(_na_borda.y)))


## O movimento do quadro vai para a mira: sem a aceleração do Android (pela
## velocidade do ponteiro no quadro: os eventos chegam juntos, um lote por
## quadro), na escala da tela e vezes a sensibilidade.
func _andar(delta: float) -> void:
	var d = _quadro_d
	_quadro_d = Vector2.ZERO
	if d == Vector2.ZERO:
		return
	if compensar:
		d /= fator_aceleracao(d.length() / max(delta, 0.004))
	var dj = Tela.movimento_para_jogo(d) / Tela.px_por_ponto()
	movimento += dj
	var tela = Tela.TELA
	pos += dj * sensibilidade
	pos = Vector2(clamp(pos.x, 0.0, tela.x), clamp(pos.y, 0.0, tela.y))


## Quanto o Android multiplicou o movimento nesta velocidade do ponteiro
## (px/s): 1 devagar, até 3 rápido. É a conta do Android ao contrário: ele
## acelera pela velocidade de antes da aceleração, e aqui só se vê a de
## depois.
static func fator_aceleracao(veloc: float) -> float:
	if veloc <= ACEL_BAIXA:
		return 1.0
	if veloc >= ACEL_ALTA * ACEL_MAX:
		return ACEL_MAX
	# v * (1 + (v - baixa) * k) = veloc, com k = (max - 1) / (alta - baixa)
	var k = (ACEL_MAX - 1.0) / (ACEL_ALTA - ACEL_BAIXA)
	var b = 1.0 - k * ACEL_BAIXA
	var v = (-b + sqrt(b * b + 4.0 * k * veloc)) / (2.0 * k)
	return veloc / v


## A borda do jogo para onde a arma passou, pelo ponteiro parado numa borda
## da janela (a mesma borda, no sentido do movimento da mira).
func _borda(p: Vector2) -> Vector2:
	var j = Tela.janela()
	if j.x <= 0.0 or j.y <= 0.0:
		return Vector2.ZERO
	var b = Vector2.ZERO
	if p.x <= BORDA_PX:
		b.x = -1.0
	elif p.x >= j.x - 1.0 - BORDA_PX:
		b.x = 1.0
	if p.y <= BORDA_PX:
		b.y = -1.0
	elif p.y >= j.y - 1.0 - BORDA_PX:
		b.y = 1.0
	return Tela.movimento_para_jogo(b)


## A calibragem começa a medir: esquece as bordas tocadas até aqui.
func zerar_borda() -> void:
	bateu_borda = false
	bordas_eixos = Vector2.ZERO


func _process(delta: float) -> void:
	_atualizar_modo()
	if giroscopio:
		_andar(delta)
		if _na_borda != Vector2.ZERO:
			# a arma passou da borda: a mira vai para a mesma borda do jogo
			var k = 1.0 - exp(-BORDA_VOLTA * delta)
			var tela = Tela.TELA
			if _na_borda.x != 0.0:
				pos.x = lerp(pos.x, 0.0 if _na_borda.x < 0.0 else tela.x, k)
			if _na_borda.y != 0.0:
				pos.y = lerp(pos.y, 0.0 if _na_borda.y < 0.0 else tela.y, k)
	else:
		_seguir_seta(delta)
	var cena = get_tree().current_scene
	var id = cena.get_instance_id() if cena != null else 0
	if id != _seta_cena:
		_seta_cena = id
		_esconder_seta()
	_ritmo()


## Onde a arma aponta agora (o tiro sai exatamente aqui).
func mira() -> Vector2:
	return Vector2(clamp(pos.x, 0.0, Tela.TELA.x), clamp(pos.y, 0.0, Tela.TELA.y))


## A tela chama a cada tiro dado. A bala sai exatamente na mira (a arma de
## verdade não sobe sozinha): o tranco fica no pulso da mira e no estampido.
func coice(_forca: float = 1.0) -> void:
	pass


## Leva a mira para um ponto (ex.: centro ao começar algo novo).
func levar_para(p: Vector2) -> void:
	pos = p
	_alvo = p
	_f_x = p
	_f_v = Vector2.ZERO
	_segue = 0.0


func centralizar() -> void:
	levar_para(Tela.TELA * 0.5)


# ------------------------------------------------------------ ritmo
func _ritmo_carregar() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(RITMO_ARQUIVO) != OK:
		return
	if str(cfg.get_value("ritmo", "versao", "")) != Tela.VERSAO:
		return   # outra versão do jogo: mede de novo
	for c in cfg.get_value("ritmo", "telas_30", []):
		_ritmo_lento[c] = true
	for c in cfg.get_value("ritmo", "telas_leves", []):
		_telas_leves[c] = true


func _ritmo_salvar() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("ritmo", "versao", Tela.VERSAO)
	cfg.set_value("ritmo", "telas_30", _ritmo_lento.keys())
	cfg.set_value("ritmo", "telas_leves", _telas_leves.keys())
	cfg.save(RITMO_ARQUIVO)


## A tela atual já ficou leve nesta TV Box? (as fases perguntam ao montar)
func tela_leve(caminho: String) -> bool:
	return _telas_leves.has(caminho) or Maquina.efeitos_leves()


## O ritmo automático já achou esta tela pesada nesta TV Box?
func tela_pesada(caminho: String) -> bool:
	return _telas_leves.has(caminho)


func _ritmo() -> void:
	var agora = OS.get_ticks_usec()
	var cena = get_tree().current_scene
	var id = cena.get_instance_id() if cena != null else 0
	if id != _ritmo_cena:
		_ritmo_cena = id
		var lento = cena != null and _ritmo_lento.has(cena.filename)
		Engine.target_fps = 30 if lento else 0
		_ritmo_t = -1.5
		_ritmo_quadros = 0
		_ritmo_lentos = 0
		_ritmo_ultimo = agora
		if cena != null and _telas_leves.has(cena.filename):
			call_deferred("_deixar_leve", cena)
		return
	var quadro = (agora - _ritmo_ultimo) / 1000.0
	_ritmo_ultimo = agora
	if TransicaoGlobal.em_transicao or cena == null or cena.filename == "" or Engine.target_fps == 30:
		return
	_ritmo_t += quadro / 1000.0
	if _ritmo_t < 0.0:
		return
	_ritmo_quadros += 1
	if quadro > RITMO_LENTO_MS:
		_ritmo_lentos += 1
	if _ritmo_t >= RITMO_JANELA:
		if _ritmo_quadros > 20 and float(_ritmo_lentos) / _ritmo_quadros > RITMO_FRACAO:
			if not _telas_leves.has(cena.filename):
				# primeiro os enfeites somem (a mira continua a 60)
				Tela.marca("leve: %s sem enfeites (%d de %d quadros passavam de %d ms)" % [cena.name, _ritmo_lentos, _ritmo_quadros, int(RITMO_LENTO_MS)])
				_telas_leves[cena.filename] = true
				_deixar_leve(cena)
				_ritmo_t = -1.0
			else:
				# nem assim: 30 quadros cravados (liso)
				Engine.target_fps = 30
				Tela.marca("ritmo: 30 quadros/s em %s (%d de %d quadros passavam de %d ms)" % [cena.name, _ritmo_lentos, _ritmo_quadros, int(RITMO_LENTO_MS)])
				_ritmo_lento[cena.filename] = true
			_ritmo_salvar()
		else:
			_ritmo_t = 0.0
		_ritmo_quadros = 0
		_ritmo_lentos = 0


## Os enfeites que a fase marcou como opcionais param e somem.
func _deixar_leve(cena: Node) -> void:
	if not is_instance_valid(cena):
		return
	for n in get_tree().get_nodes_in_group("efeito_opcional"):
		if cena.is_a_parent_of(n):
			n.visible = false
			n.set_process(false)
			if n is CPUParticles2D:
				n.emitting = false
