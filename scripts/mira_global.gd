extends Node

## A MIRA DO JOGO INTEIRO e o RITMO DE QUADROS.
##
## Há UMA mira, aqui; cada tela lê `MiraGlobal.mira()` e desenha/acerta
## exatamente ali.
##
## A ARMA DE GIROSCÓPIO (a da máquina, como na versão 4.6): ela é um mouse
## que manda o MOVIMENTO da arma, e a mira soma esse movimento, na mesma
## medida nos dois eixos (arma para a direita = mira para a direita; para
## cima = para cima) e na escala da tela (um pixel do HDMI anda um ponto do
## jogo do mesmo tamanho), vezes a SENSIBILIDADE (CONFIGURAÇÃO -> ARMA E
## MIRA, onde também se calibra atirando em quatro alvos).
## No Android 8 em diante a 4.6 capturava o ponteiro e recebia o movimento
## cru. No Android 7.1 da TV Box não existe captura: o movimento vem do
## ponteiro do sistema, com duas manias que a mira corrige:
##   - ACELERAÇÃO: o Android multiplica o movimento rápido (até 3x acima de
##     3000 px/s). A mira desfaz a conta pela velocidade do ponteiro, e o
##     movimento volta a ser proporcional ao giro da arma.
##   - BORDA: o ponteiro para na borda do HDMI (e a borda curta do HDMI
##     deitado é a altura do jogo em pé). Ponteiro parado numa borda = a arma
##     apontando além dela: a mira vai para a mesma borda do jogo, e arma e
##     mira voltam a casar (o "encostar na borda" de toda arma de giroscópio).
## Tipo ABSOLUTA (CONFIGURAÇÃO): para a arma que marca o ponto da tela; a
## mira é o ponto do ponteiro (a fração do HDMI é a fração do jogo).
##
## A SETA DO SISTEMA: no Android 7.1 o Godot 3.6 não esconde o ponteiro (só
## do Android 8 em diante); ela vira uma imagem transparente (cursor
## próprio, Android 7.0+) em todos os formatos, refeita a cada tela nova e
## quando o jogo volta ao foco. A tela desenha a mira; a seta não aparece.
##
## RECUO (como nos jogos de tiro): o primeiro tiro vai exatamente na mira;
## tiros em sequência levantam a arma (um tranco para cima e um pouco para o
## lado) e a bala do tiro seguinte vai para onde a arma subiu; sem atirar,
## ela volta sozinha (~0,4 s).
##
## RITMO: a TV é de 60 Hz. Uma tela que não segura 60 quadros alterna 16 e
## 33 ms e isso aparece como tranco; se em 2 s mais de um quarto dos quadros
## passou de 20 ms, a tela fica em 30 por segundo cravados (liso). A TV Box
## lembra (user://ritmo.cfg): da próxima vez a tela já abre em 30. Se nem em
## 30 ela segura (quadros de 45 ms), os enfeites (grupo "efeito_opcional")
## somem nela, e isso também fica lembrado.

const RECUO_PASSO = 26.0
const RECUO_LADO = 11.0
const RECUO_SEQUENCIA = 0.45
const RECUO_MAX = 110.0
const RECUO_VOLTA = 4.5

# a aceleração do ponteiro do Android (VelocityControl, igual do 4.1 ao 7.1)
const ACEL_BAIXA = 500.0       # px/s: até aqui o Android não acelera
const ACEL_ALTA = 3000.0       # px/s: daqui para cima acelera o máximo
const ACEL_MAX = 3.0
const BORDA_PX = 0.75          # ponteiro a até isto da borda da janela = parado nela
const BORDA_VOLTA = 16.0       # 1/s: a mira indo para a borda (rápido, sem pulo)
const SENS_MIN = 0.2
const SENS_MAX = 4.0

const RITMO_ARQUIVO = "user://ritmo.cfg"
const RITMO_JANELA = 2.0
const RITMO_LENTO_MS = 20.0
const RITMO_FRACAO = 0.25
const LEVE_JANELA = 3.0
const LEVE_LENTO_MS = 45.0

var pos = Vector2(512, 910)
var recuo = Vector2.ZERO
var ativa = true              # false: a tela não mostra mira (abertura)

## A arma manda movimento (giroscópio) ou o ponto da tela (absoluta)?
var giroscopio = true
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

var _seguidos = 0
var _ultimo_coice_ms = -100000
var _android = false
var _seta: ImageTexture
var _seta_cena = 0
var _ultimo = Vector2(INF, INF)
var _quadro_d = Vector2.ZERO   # o quanto o ponteiro andou neste quadro (pixels da janela)
var _na_borda = Vector2.ZERO   # borda do jogo para onde a arma passou (-1, 0, 1 em cada eixo)

var _ritmo_lento = {}
var _telas_leves = {}
var _ritmo_cena = 0
var _ritmo_t = 0.0
var _ritmo_quadros = 0
var _ritmo_lentos = 0
var _ritmo_ultimo = 0
var _leve_t = 0.0
var _leve_quadros = 0
var _leve_lentos = 0


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
	var tipo = str(Maquina.valor("arma/tipo"))
	if OS.has_environment("LAZER_ARMA"):
		tipo = OS.get_environment("LAZER_ARMA")
	elif not _android:
		tipo = "absoluta"      # no PC o mouse marca o ponto
	giroscopio = tipo != "absoluta"
	sensibilidade = clamp(float(Maquina.valor("arma/sensibilidade")), SENS_MIN, SENS_MAX)
	compensar = bool(Maquina.valor("arma/compensar_aceleracao"))


## A seta do sistema some: no PC o modo escondido; no Android 7 (onde o Godot
## 3.6 não esconde o ponteiro) uma seta transparente própria. O Godot 3.6
## aplica a imagem no formato ATUAL e depois troca para o pedido: com
## `todos`, duas chamadas por formato deixam todos transparentes.
func _esconder_seta(todos: bool = false) -> void:
	if _seta == null:
		var img = Image.new()
		img.create(8, 8, false, Image.FORMAT_RGBA8)
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


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_FOCUS_IN:
		_esconder_seta()
		# voltando ao foco o ponteiro pode ter andado por fora: recomeça a
		# conta do movimento a partir do próximo evento
		_ultimo = Vector2(INF, INF)


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion or event is InputEventMouseButton):
		return
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
	pos = Vector2(clamp(p.x, 0.0, tela.x), clamp(p.y, 0.0, tela.y))


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
	if recuo != Vector2.ZERO:
		recuo *= exp(-RECUO_VOLTA * delta)
		if recuo.length_squared() < 0.04:
			recuo = Vector2.ZERO
	if giroscopio:
		_andar(delta)
	if giroscopio and _na_borda != Vector2.ZERO:
		# a arma passou da borda: a mira vai para a mesma borda do jogo
		var k = 1.0 - exp(-BORDA_VOLTA * delta)
		var tela = Tela.TELA
		if _na_borda.x != 0.0:
			pos.x = lerp(pos.x, 0.0 if _na_borda.x < 0.0 else tela.x, k)
		if _na_borda.y != 0.0:
			pos.y = lerp(pos.y, 0.0 if _na_borda.y < 0.0 else tela.y, k)
	var cena = get_tree().current_scene
	var id = cena.get_instance_id() if cena != null else 0
	if id != _seta_cena:
		_seta_cena = id
		_esconder_seta()
	_ritmo()


## Onde a arma aponta agora: a mira mais o recuo dos tiros em sequência.
func mira() -> Vector2:
	var p = pos + recuo
	return Vector2(clamp(p.x, 0.0, Tela.TELA.x), clamp(p.y, 0.0, Tela.TELA.y))


## A tela chama a cada tiro dado: a arma dá o tranco. `forca` muda com a arma
## (pistola do bar mais forte, laser da arena leve).
func coice(forca: float = 1.0) -> void:
	var agora = OS.get_ticks_msec()
	var dt = (agora - _ultimo_coice_ms) / 1000.0
	_ultimo_coice_ms = agora
	_seguidos = int(min(_seguidos + 1, 5)) if dt < RECUO_SEQUENCIA else 0
	var sobe = RECUO_PASSO * (1.0 + 0.1 * _seguidos)
	var lado = rand_range(-RECUO_LADO, RECUO_LADO) * (1.0 + 0.3 * _seguidos)
	recuo = (recuo + Vector2(lado, -sobe) * forca).limit_length(RECUO_MAX * forca)


## Leva a mira para um ponto (ex.: centro ao começar algo novo).
func levar_para(p: Vector2) -> void:
	pos = p
	recuo = Vector2.ZERO


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
		_leve_t = -2.0
		_leve_quadros = 0
		_leve_lentos = 0
		if cena != null and _telas_leves.has(cena.filename):
			call_deferred("_deixar_leve", cena)
		return
	var quadro = (agora - _ritmo_ultimo) / 1000.0
	_ritmo_ultimo = agora
	if TransicaoGlobal.em_transicao or cena == null or cena.filename == "":
		return
	if Engine.target_fps == 30:
		_medir_leve(quadro, cena)
		return
	_ritmo_t += quadro / 1000.0
	if _ritmo_t < 0.0:
		return
	_ritmo_quadros += 1
	if quadro > RITMO_LENTO_MS:
		_ritmo_lentos += 1
	if _ritmo_t >= RITMO_JANELA:
		if _ritmo_quadros > 20 and float(_ritmo_lentos) / _ritmo_quadros > RITMO_FRACAO:
			Engine.target_fps = 30
			Tela.marca("ritmo: 30 quadros/s em %s (%d de %d quadros passavam de %d ms)" % [cena.name, _ritmo_lentos, _ritmo_quadros, int(RITMO_LENTO_MS)])
			_ritmo_lento[cena.filename] = true
			_ritmo_salvar()
		_ritmo_t = 0.0
		_ritmo_quadros = 0
		_ritmo_lentos = 0


func _medir_leve(quadro: float, cena: Node) -> void:
	if _telas_leves.has(cena.filename):
		return
	_leve_t += quadro / 1000.0
	if _leve_t < 0.0:
		return
	_leve_quadros += 1
	if quadro > LEVE_LENTO_MS:
		_leve_lentos += 1
	if _leve_t >= LEVE_JANELA:
		if _leve_quadros > 20 and float(_leve_lentos) / _leve_quadros > RITMO_FRACAO:
			Tela.marca("calibragem: %s leve (%d de %d quadros passavam de %d ms)" % [cena.name, _leve_lentos, _leve_quadros, int(LEVE_LENTO_MS)])
			_telas_leves[cena.filename] = true
			_ritmo_salvar()
			_deixar_leve(cena)
		_leve_t = 0.0
		_leve_quadros = 0
		_leve_lentos = 0


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
