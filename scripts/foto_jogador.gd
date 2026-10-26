extends Node

## A FOTO DO JOGADOR (webcam USB da TV Box): pedida antes de cada partida
## na tela de pose (scripts/pose_foto.gd: a imagem ao vivo, 3-2-1 e o
## clique) e mostrada na tela do nome, no resultado e no ranking.
##
## No APK do gerador vai a classe org.lazershot.CameraFoto (classes2.dex,
## veja android_camera/ e "OS MODELOS DO LAZER" no gerador): a API clássica
## de câmera do Android, por onde a TV Box mostra a webcam USB. Sem câmera
## escolhida (AUTO) ela tenta da última para a primeira: a webcam USB
## costuma ser a última da lista. O jogo a chama pelo JavaClassWrapper só
## com números e texto e nunca espera por ela.
##
## A CÂMERA SÓ FICA LIGADA ENQUANTO A FASE ESPERA O START E NA POSE: liga
## quando a fase abre (ligar_previa: a luz da webcam já está acertada quando
## o jogador aperta START), mostra a imagem ao vivo na pose e desliga logo
## depois da foto. Ligada, ela gasta processador que faz falta ao jogo.
##
## A IMAGEM AO VIVO: a classe grava o quadro mais novo num JPEG pequeno a
## cada PREVIA_MS; aqui ele é aberto numa Thread e vira a textura da pose.
## O recorte da foto (quadrado do meio), o giro e o espelho também saem numa
## Thread: nada engasga. Sem câmera (PC, APK sem a classe, câmera ausente ou
## sem permissão) a pose não aparece e o ranking mostra a silhueta.
##
## Nada técnico aparece no jogo: o estado (status()) só aparece na
## CONFIGURAÇÃO, na página CÂMERA.
##
## Para testar no PC: LAZER_CAMERA_FALSA=/caminho/de/uma/foto.jpg (a foto
## faz o papel da webcam).

signal foto_pronta(textura)
signal previa_nova(textura)

const PASTA = "user://fotos"
const LADO = 256
const PREVIA_MS = 140
const LIMITE_GRAVAR = 4.0        # s esperando o JPEG ficar pronto
const GUARDADAS = 6              # fotos sem ranking que ficam (as últimas)

var disponivel = false           # a classe está no APK e o Android vê câmera
var ultima = ""                  # a foto da última partida (png) ou ""
var ultima_textura: Texture = null
var previa: ImageTexture = null  # a imagem ao vivo (a mesma textura sempre)

var _cls = null
var _cameras = 0
var _fase = ""                   # "", "previa", "gravando", "tratando"
var _t = 0.0
var _jpg = ""
var _jpg_previa = ""
var _previas = 0
var _thread: Thread = null       # a foto
var _thread_previa: Thread = null
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
	_cameras = int(_cls.call("cameras"))
	disponivel = _cameras > 0
	# a permissão da câmera (o Android pergunta uma vez)
	if int(_cls.call("permissao")) != 1:
		OS.request_permissions()
	Tela.marca("câmera: %d (permissão %d)" % [_cameras, int(_cls.call("permissao"))])


func ligada() -> bool:
	if _cls != null and not disponivel:
		# a webcam pode ter sido ligada depois que o jogo abriu
		_cameras = int(_cls.call("cameras"))
		disponivel = _cameras > 0
	return disponivel and bool(Maquina.valor("camera/foto"))


## O estado em palavras (só para a CONFIGURAÇÃO).
func status() -> String:
	if _falsa != "":
		return "câmera falsa (teste): " + _falsa
	if OS.get_name() != "Android":
		return "no PC não há câmera (só na TV Box)"
	if _cls == null:
		if _falhas != "":
			return _falhas
		return "este APK não tem a câmera (gere de novo com o gerador e confira a linha Camera)"
	var perm = int(_cls.call("permissao"))
	var s = "câmeras vistas: %d  ·  %s" % [int(_cls.call("cameras")), str(_cls.call("status"))]
	if perm == 0:
		s = "SEM PERMISSÃO: permita o Lazer Shot usar a câmera (configurações do Android > Apps)  ·  " + s
	if _fase == "previa":
		s += "  ·  %d quadros" % int(_cls.call("quadros"))
	return s


func cameras() -> int:
	return _cameras


## A imagem ao vivo já chegou?
func tem_previa() -> bool:
	return _previas > 0 and previa != null


func ligando() -> bool:
	return _fase == "previa"


## Liga a câmera e a imagem ao vivo (a fase abriu: o jogador ainda vai
## apertar START).
func ligar_previa() -> void:
	if not ligada() or _fase != "":
		return
	ultima = ""
	ultima_textura = null
	_previas = 0
	_t = 0.0
	_dir()
	if _falsa != "":
		_fase = "previa"
		set_process(true)
		return
	_jpg_previa = ProjectSettings.globalize_path("%s/previa.jpg" % PASTA)
	_cls.call("previa", _jpg_previa, PREVIA_MS)
	var indice = int(Maquina.valor("camera/indice"))
	if indice >= _cameras:
		indice = -1
	if bool(_cls.call("abrir", indice)):
		_fase = "previa"
		set_process(true)


## O clique: grava o quadro de agora (a pose chama no fim do 3-2-1).
func fotografar() -> void:
	if _fase != "previa":
		return
	_t = 0.0
	if _falsa != "":
		_comecar_tratamento(_falsa)
		return
	_cls.call("previa", "", 0)
	_jpg = ProjectSettings.globalize_path("%s/nova.jpg" % PASTA)
	if bool(_cls.call("fotografar", _jpg)):
		_fase = "gravando"
	else:
		_desistir()


## Solta a câmera (saiu da fase ou desistiu da foto).
func cancelar() -> void:
	if _fase == "previa" or _fase == "gravando":
		_desistir()


func _comecar_tratamento(jpg: String) -> void:
	_fase = "tratando"
	_thread = Thread.new()
	var giro = int(Maquina.valor("camera/girar"))
	var espelho = bool(Maquina.valor("camera/espelhar"))
	if _thread.start(self, "_tratar", [jpg, giro, espelho]) != OK:
		_thread = null
		_desistir()


func _process(delta: float) -> void:
	_t += delta
	# a imagem ao vivo: a prévia nova é aberta numa Thread
	if _thread_previa != null and not _thread_previa.is_alive():
		var img = _thread_previa.wait_to_finish()
		_thread_previa = null
		if img is Image and _fase == "previa":
			if previa == null or previa.get_width() != img.get_width() or previa.get_height() != img.get_height():
				previa = ImageTexture.new()
				previa.create_from_image(img, Texture.FLAG_FILTER)
			else:
				previa.set_data(img)
			emit_signal("previa_nova", previa)
	match _fase:
		"previa":
			if _thread_previa == null:
				var n = _previas
				if _falsa == "":
					n = int(_cls.call("previas"))
				elif _t > 0.3 * (_previas + 1):
					n = _previas + 1
				if n != _previas:
					_previas = n
					_thread_previa = Thread.new()
					if _thread_previa.start(self, "_abrir_previa", _falsa if _falsa != "" else _jpg_previa) != OK:
						_thread_previa = null
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
			if _thread_previa == null:
				set_process(false)


## Na Thread: a prévia (o JPEG pequeno que a câmera acabou de gravar).
func _abrir_previa(caminho: String):
	var img = Image.new()
	if img.load(caminho) != OK:
		return null
	if img.get_width() > 480:
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	return img


func _desistir() -> void:
	if _cls != null:
		_cls.call("previa", "", 0)
		_cls.call("fechar")
	_fase = ""


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
	if _thread_previa != null:
		_thread_previa.wait_to_finish()
	if _cls != null:
		_cls.call("fechar")
