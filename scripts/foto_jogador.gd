extends Node

## A FOTO DO JOGADOR (webcam USB da TV Box): tirada no começo de cada
## partida e mostrada na tela do nome, no resultado e no ranking.
##
## No APK do gerador vai a classe org.lazershot.CameraFoto (classes2.dex,
## veja android_camera/ e "OS MODELOS DO LAZER" no gerador): a API clássica
## de câmera do Android, por onde a TV Box mostra a webcam USB. O jogo a
## chama pelo JavaClassWrapper só com números e texto e nunca espera por ela.
##
## A CÂMERA SÓ FICA LIGADA O TEMPO DA FOTO: liga na contagem da partida
## (preparar), fotografa no COMEÇOU! (fotografar) e desliga logo depois.
## Ligada, ela gasta processador que faz falta ao jogo.
##
## O recorte (quadrado do meio), o giro e o espelho saem numa Thread: a
## partida não engasga. Sem câmera (PC, APK sem a classe, câmera ausente ou
## sem permissão) nada acontece e o ranking mostra a silhueta.
##
## Nada técnico aparece no jogo: o estado (status()) só aparece na
## CONFIGURAÇÃO, na página CÂMERA.
##
## Para testar no PC: LAZER_CAMERA_FALSA=/caminho/de/uma/foto.jpg (a foto
## faz o papel da webcam).

signal foto_pronta(textura)

const PASTA = "user://fotos"
const LADO = 256
const QUADROS_ANTES = 8          # a câmera acerta a luz antes da foto
const LIMITE_ABRIR = 7.0         # s esperando a imagem chegar
const LIMITE_GRAVAR = 4.0        # s esperando o JPEG ficar pronto
const GUARDADAS = 6              # fotos sem ranking que ficam (as últimas)

var disponivel = false           # a classe está no APK e o Android vê câmera
var ultima = ""                  # a foto da última partida (png) ou ""
var ultima_textura: Texture = null

var _cls = null
var _cameras = 0
var _fase = ""                   # "", "abrindo", "gravando", "tratando"
var _t = 0.0
var _quer_foto = false
var _jpg = ""
var _thread: Thread = null
var _cache = {}                  # caminho -> textura (o ranking reabre muito)
var _falhas = ""
var _falsa = ""                  # teste no PC: uma foto no lugar da webcam


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	set_process(false)
	_limpar_fotos_velhas()
	if OS.has_environment("LAZER_CAMERA_FALSA"):
		_falsa = OS.get_environment("LAZER_CAMERA_FALSA")
		disponivel = true
		_cameras = 1
		return
	if OS.get_name() != "Android":
		return
	if not (ProjectSettings.has_setting("lazer/camera/nativa") and bool(ProjectSettings.get_setting("lazer/camera/nativa"))):
		return
	var jcw = Engine.get_singleton("JavaClassWrapper")
	if jcw == null:
		return
	_cls = jcw.wrap("org.lazershot.CameraFoto")
	if _cls == null:
		_falhas = "classe da câmera não carregou"
		return
	# a permissão da câmera (o Android pergunta uma vez)
	OS.request_permissions()
	_cameras = int(_cls.call("cameras"))
	disponivel = _cameras > 0
	Tela.marca("câmera: %d" % _cameras)


func ligada() -> bool:
	return disponivel and bool(Maquina.valor("camera/foto"))


func _comecar_tratamento(jpg: String) -> void:
	_fase = "tratando"
	_thread = Thread.new()
	var giro = int(Maquina.valor("camera/girar"))
	var espelho = bool(Maquina.valor("camera/espelhar"))
	if _thread.start(self, "_tratar", [jpg, giro, espelho]) != OK:
		_thread = null
		_desistir()


## O estado em palavras (só para a CONFIGURAÇÃO).
func status() -> String:
	if _falsa != "":
		return "câmera falsa (teste): " + _falsa
	if OS.get_name() != "Android":
		return "no PC não há câmera (só na TV Box)"
	if _cls == null:
		if _falhas != "":
			return _falhas
		return "este APK não tem a câmera (gere de novo com o gerador)"
	var s = "câmeras: %d  ·  %s" % [_cameras, str(_cls.call("status"))]
	if _fase == "abrindo":
		s += "  ·  %d quadros" % int(_cls.call("quadros"))
	return s


func cameras() -> int:
	return _cameras


## Liga a câmera (a contagem da partida começou).
func preparar() -> void:
	if not ligada() or _fase != "":
		return
	ultima = ""
	ultima_textura = null
	_quer_foto = false
	if _falsa != "":
		_fase = "abrindo"
		_t = 0.0
		set_process(true)
		return
	var indice = int(clamp(int(Maquina.valor("camera/indice")), 0, max(0, _cameras - 1)))
	if bool(_cls.call("abrir", indice)):
		_fase = "abrindo"
		_t = 0.0
		set_process(true)


## Tira a foto assim que a imagem estiver boa (ou liga e tira).
func fotografar() -> void:
	if not ligada():
		return
	if _fase == "":
		preparar()
	_quer_foto = true


## Solta a câmera (saiu da partida antes da foto).
func cancelar() -> void:
	if _fase == "abrindo" or _fase == "gravando":
		if _cls != null:
			_cls.call("fechar")
		_fase = ""
		set_process(false)


func _process(delta: float) -> void:
	_t += delta
	match _fase:
		"abrindo":
			if _falsa != "":
				if _quer_foto and _t > 0.4:
					_comecar_tratamento(_falsa)
				return
			var q = int(_cls.call("quadros"))
			if _quer_foto and q >= QUADROS_ANTES:
				_dir()
				_jpg = ProjectSettings.globalize_path("%s/nova.jpg" % PASTA)
				if bool(_cls.call("fotografar", _jpg)):
					_fase = "gravando"
					_t = 0.0
				else:
					_desistir()
			elif _t > LIMITE_ABRIR:
				_desistir()
		"gravando":
			var f = int(_cls.call("foto"))
			if f == 2:
				_cls.call("fechar")
				_comecar_tratamento(_jpg)
			elif f < 0 or _t > LIMITE_GRAVAR:
				_desistir()
		"tratando":
			if _thread != null and not _thread.is_alive():
				var img = _thread.wait_to_finish()
				_thread = null
				_fase = ""
				set_process(false)
				if img is Image:
					_dir()
					var caminho = "%s/foto_%d_%03d.png" % [PASTA, OS.get_unix_time(), randi() % 1000]
					if img.save_png(caminho) == OK:
						var tex = ImageTexture.new()
						tex.create_from_image(img, Texture.FLAG_FILTER)
						ultima = caminho
						ultima_textura = tex
						_cache[caminho] = tex
						emit_signal("foto_pronta", tex)
		_:
			set_process(false)


func _desistir() -> void:
	if _cls != null:
		_cls.call("fechar")
	_fase = ""
	set_process(false)


## Na Thread: abre o JPEG, recorta o quadrado do meio, reduz, gira e espelha.
func _tratar(dados: Array):
	var img = Image.new()
	if img.load(dados[0]) != OK:
		return null
	var w = img.get_width()
	var h = img.get_height()
	var lado = min(w, h)
	img = img.get_rect(Rect2((w - lado) / 2, (h - lado) / 2, lado, lado))
	img.resize(LADO, LADO, Image.INTERPOLATE_BILINEAR)
	img.convert(Image.FORMAT_RGB8)
	var giro = int(dados[1]) % 360
	if giro == 180:
		img.flip_x()
		img.flip_y()
	elif giro == 90 or giro == 270:
		img = _girar_90(img, giro == 90)
	if dados[2]:
		img.flip_x()
	return img


func _girar_90(img: Image, horario: bool) -> Image:
	var n = img.get_width()
	var src = img.get_data()
	var dst = PoolByteArray()
	dst.resize(n * n * 3)
	for y in n:
		for x in n:
			var sx = y if horario else n - 1 - y
			var sy = n - 1 - x if horario else x
			var a = (sy * n + sx) * 3
			var b = (y * n + x) * 3
			dst[b] = src[a]
			dst[b + 1] = src[a + 1]
			dst[b + 2] = src[a + 2]
	var r = Image.new()
	r.create_from_data(n, n, false, Image.FORMAT_RGB8, dst)
	return r


## A foto de um jogador do ranking (ou null): guardada depois da primeira vez.
func textura(caminho: String) -> Texture:
	if caminho == "":
		return null
	if _cache.has(caminho):
		return _cache[caminho]
	var f = File.new()
	if not f.file_exists(caminho):
		return null
	var img = Image.new()
	if img.load(caminho) != OK:
		return null
	var tex = ImageTexture.new()
	tex.create_from_image(img, Texture.FLAG_FILTER)
	_cache[caminho] = tex
	return tex


## Uma foto emoldurada como foto instantânea (borda branca, sombra e um
## leve giro), para a tela do nome e o resultado.
func moldura(pai: Node, centro: Vector2, lado: float, tex: Texture, giro: float = -3.0, legenda: String = "") -> Control:
	var raiz = Control.new()
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.rect_size = Vector2(lado + 24, lado + 70)
	raiz.rect_pivot_offset = raiz.rect_size * 0.5
	raiz.rect_position = centro - raiz.rect_size * 0.5
	raiz.rect_rotation = giro
	pai.add_child(raiz)
	var sombra = ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.45)
	sombra.rect_position = Vector2(10, 12)
	sombra.rect_size = raiz.rect_size
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(sombra)
	var papel = ColorRect.new()
	papel.color = Color(0.97, 0.96, 0.92)
	papel.rect_size = raiz.rect_size
	papel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(papel)
	var foto = TextureRect.new()
	foto.texture = tex
	foto.expand = true
	foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	foto.rect_position = Vector2(12, 12)
	foto.rect_size = Vector2(lado, lado)
	foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(foto)
	if legenda != "":
		var l = Estilo.rotulo(raiz, legenda, int(clamp(lado * 0.13, 16, 34)), Color(0.12, 0.10, 0.10), 0, true)
		Estilo.colocar(l, Vector2(0, lado + 16), Vector2(raiz.rect_size.x, 48))
	return raiz


func _dir() -> void:
	var d = Directory.new()
	if not d.dir_exists(PASTA):
		d.make_dir_recursive(PASTA)


## Apaga as fotos que não estão no ranking (ficam as últimas GUARDADAS).
func _limpar_fotos_velhas() -> void:
	var d = Directory.new()
	if d.open(PASTA) != OK:
		return
	var usadas = {}
	for item in RankingManager.ranking:
		usadas[str(item.get("foto", ""))] = true
	var soltas = []
	d.list_dir_begin(true, true)
	var n = d.get_next()
	while n != "":
		var c = "%s/%s" % [PASTA, n]
		if not d.current_is_dir() and not usadas.has(c):
			soltas.append(n)
		n = d.get_next()
	d.list_dir_end()
	soltas.sort()
	for i in range(0, soltas.size() - GUARDADAS):
		d.remove(soltas[i])


func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
	if _cls != null:
		_cls.call("fechar")
