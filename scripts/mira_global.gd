extends Node

## A MIRA DO JOGO INTEIRO e o RITMO DE QUADROS.
##
## Há UMA mira, aqui; cada tela lê `MiraGlobal.mira()` e desenha/acerta
## exatamente ali.
##
## A ARMA é um mouse absoluto: a posição do ponteiro do Android vira a mira.
## No HDMI deitado com o monitor em pé (Tela.giro), a arma mede no sentido do
## monitor em pé: a fração da largura do HDMI é a fração da largura do jogo
## (Tela.hdmi_para_jogo_direto). No Android 7.1 o Godot 3.6 não esconde nem
## captura o ponteiro (isso só existe do Android 8 em diante): a seta do
## sistema vira uma imagem transparente (cursor próprio, Android 7.0+), e a
## mira desenhada pela tela é o que aparece.
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

const RITMO_ARQUIVO = "user://ritmo.cfg"
const RITMO_JANELA = 2.0
const RITMO_LENTO_MS = 20.0
const RITMO_FRACAO = 0.25
const LEVE_JANELA = 3.0
const LEVE_LENTO_MS = 45.0

var pos = Vector2(512, 910)
var recuo = Vector2.ZERO
var ativa = true              # false: a tela não mostra mira (abertura)

var _seguidos = 0
var _ultimo_coice_ms = -100000
var _android = false

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
	_esconder_seta()


## A seta do sistema some: no PC o modo escondido; no Android 7 (onde o Godot
## 3.6 não esconde o ponteiro) uma seta transparente própria.
func _esconder_seta() -> void:
	var img = Image.new()
	img.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var caminho = "user://seta_vazia.png"
	img.save_png(caminho)
	var tex = ImageTexture.new()
	tex.create_from_image(img, 0)
	# o Android lê a imagem pelo caminho do arquivo (PointerIcon)
	tex.resource_path = caminho
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2.ZERO)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Tela.marca("seta do sistema transparente")


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_FOCUS_IN:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion or event is InputEventMouseButton):
		return
	var tela = Tela.TELA
	var p: Vector2
	if Tela.giro != 0 and Tela.mira_direta:
		# a posição crua do HDMI (global_position não passa pelo giro)
		p = Tela.hdmi_para_jogo_direto(event.global_position)
	else:
		p = event.position
	pos = Vector2(clamp(p.x, 0.0, tela.x), clamp(p.y, 0.0, tela.y))


func _process(delta: float) -> void:
	if recuo != Vector2.ZERO:
		recuo *= exp(-RECUO_VOLTA * delta)
		if recuo.length_squared() < 0.04:
			recuo = Vector2.ZERO
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
