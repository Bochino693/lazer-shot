class_name Webcam
extends Node

## A WEBCAM DO GABINETE (Rodada 31): a foto de quem vai jogar é tirada antes
## da partida (scenes/pose.tscn) e aparece no recorde e no ranking, como no
## Super Boxing. É o mesmo serviço de câmera de lá (camera_service.gd), com
## o mesmo plugin Android (addons/PunchUsbSerial), sem a parte do Windows:
## aqui o jogo roda na TV Box, e no PC a câmera só serve para teste.
##
## NO ANDROID HÁ DOIS CAMINHOS, E SÓ UM DE CADA VEZ:
##   PONTE     o plugin: a câmera do sistema pela API clássica do Android (é
##             assim que as TV Boxes publicam a webcam USB; a Camera2 do Godot
##             não lista câmeras desse tipo) e, de reserva, a webcam direto
##             pelo USB (UVC).
##   SERVIDOR  o CameraServer do Godot (Camera2), para quando o plugin não vê
##             câmera nenhuma.
## Dois donos para a mesma webcam derrubam os dois.
##
## A WEBCAM SÓ FICA ABERTA QUANDO ALGUÉM PRECISA DELA. Aberta, ela manda 30
## quadros por segundo que o Android decodifica no processador: trabalho que
## o menu e a partida pagariam sem mostrar a imagem (na TV Box mais fraca,
## processador e memória que fazem falta). Ela abre quando a partida é paga
## (Maquina.cobrar), mostra a imagem na tela da pose, e é solta assim que a
## foto sai. No menu ela abre uma vez por sessão, sozinha, só para descobrir
## se existe e por onde abre (a "descoberta"), e fecha logo depois.
##
## Nada técnico aparece na tela do jogo: o estado (`status`) só é mostrado na
## CONFIGURAÇÃO, em TESTAR CÂMERA.
##
## Para testar no PC sem webcam: LAZER_CAMERA_FALSA=1 (imagem de teste que
## mexe; =lenta: a imagem só chega depois de 9 s).

signal foto_gravada(caminho: String)

const PASTA_FOTOS := "user://ranking_photos"
## A foto do ranking: 320x320 (aparece com ~100 px na tabela e ~260 px no
## recorde). Menos disco, e abrir a foto na TV Box pesa pouco.
const LADO_FOTO := 320
## O que a webcam já mostrou neste aparelho (fica entre as aberturas do app).
const LEMBRANCA := "user://webcam.cfg"
## Um quadro desta idade ainda é "ao vivo".
const VIVA_MS := 2500
const INTERVALO_NOVA_BUSCA_MS := 2500
const CONTRASTE_MINIMO := 0.04
## A descoberta no menu dura no máximo isto.
const DESCOBERTA_MS := 20000
## Aberta e sem nenhum sinal de câmera por este tempo: não há webcam aqui.
const SEM_CAMERA_MS := 15000
## O plugin ainda sem quadro: insiste em abrir de tempos em tempos.
const INSISTIR_MS := 3000

enum Uso { NENHUM, DESCOBERTA, FOTO }
enum Caca { NENHUMA, PONTE, SERVIDOR }

var enabled := true
var espelhar := false
## 0, 90, 180 ou 270 graus (webcam montada de lado ou de cabeça para baixo).
var girar := 0
## Ritmo de leitura dos quadros, em ms (rápido só com a imagem na tela).
var intervalo_ms := 400
## Janelas do Android (permissão USB da webcam) podem aparecer agora?
var janelas_liberadas := false
var status := "CÂMERA FECHADA"
## O quadro da última foto, inteiro (a tela da pose mostra ele parado).
var ultima_foto: Image = null
## A última foto já recortada, girada e no tamanho do ranking (e o arquivo).
var ultima_foto_quadrada: Image = null
var ultima_foto_caminho := ""

var _uso := Uso.NENHUM
var _aberta := false
var _aberta_desde_ms := 0
var _abrir_em_ms := -1
var _descoberta_em_ms := -1
var _descoberta_feita := false
var _teve_video := false
var _sem_sinal := false

var _falsa := ""
var _falsa_t := 0.0
var _falsa_img: Image = null

var _android_bridge = null
var _caca := Caca.NENHUMA
var _caca_desde_ms := 0
var _insistir_em_ms := 0
var _proxima_leitura_ms := 0
var _proxima_busca_ms := 0
var _ultima_quantidade_feeds := -1
var _sem_quadro_desde_ms := 0

# Não tipar como CameraFeed: no Android o feed pode ser de outra classe.
var _feed = null
var _texture: CameraTexture = null
var _uvc_texture: ImageTexture = null
var _ultima_imagem: Image = null
var _ultimo_quadro_ms := 0
var _assinatura := 0

var _melhor_imagem: Image = null
var _melhor_nota := -1.0
var _obturador_ate_ms := 0

var _lembranca := ConfigFile.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lembranca.load(LEMBRANCA)
	if OS.has_environment("LAZER_CAMERA_FALSA") and OS.get_environment("LAZER_CAMERA_FALSA") != "0":
		_falsa = OS.get_environment("LAZER_CAMERA_FALSA")


## Valores da CONFIGURAÇÃO (Maquina.aplicar).
func configurar(ativa: bool, espelho: bool, graus: int) -> void:
	espelhar = espelho
	girar = posmod(graus, 360) / 90 * 90
	if ativa == enabled:
		return
	enabled = ativa
	if not enabled:
		_uso = Uso.NENHUM
		_abrir_em_ms = -1
		_descoberta_em_ms = -1
		_fechar("desligada na configuração")
		status = "CÂMERA DESLIGADA NA CONFIGURAÇÃO"


# ================================================================ quem usa
## A descoberta: abre uma vez por sessão (no menu, `atraso_ms` depois) só
## para saber se a webcam existe e por onde abre, e fecha em seguida.
func descobrir(atraso_ms: int) -> void:
	if _descoberta_feita or _descoberta_em_ms >= 0 or not enabled:
		return
	_descoberta_em_ms = Time.get_ticks_msec() + atraso_ms


## A foto vai ser tirada: abre já (ou daqui a `atraso_ms`, para não pesar no
## meio de uma troca de tela) e fica aberta até `soltar`.
func ligar(atraso_ms: int = 0) -> void:
	if not enabled:
		return
	_uso = Uso.FOTO
	_descoberta_em_ms = -1
	if _aberta:
		return
	var em := Time.get_ticks_msec() + maxi(0, atraso_ms)
	_abrir_em_ms = em if _abrir_em_ms < 0 else mini(_abrir_em_ms, em)


## Ninguém precisa mais da imagem: a webcam é solta.
func soltar() -> void:
	_abrir_em_ms = -1
	if _uso == Uso.DESCOBERTA:
		return   # a descoberta termina sozinha
	_uso = Uso.NENHUM
	_fechar("solta")


## A tela da pose vale a pena? (webcam ligada, com permissão, e não se
## concluiu que este aparelho não tem câmera)
func quer_foto() -> bool:
	return enabled and not _sem_sinal and _tem_permissao()


## A webcam já mostrou imagem neste aparelho (agora ou numa sessão anterior).
func conhecida() -> bool:
	return _teve_video or bool(_lembranca.get_value("webcam", "vista", false))


## Imagem chegando agora?
func ao_vivo() -> bool:
	return _aberta and _ultimo_quadro_ms > 0 and Time.get_ticks_msec() - _ultimo_quadro_ms <= VIVA_MS


func pronta() -> bool:
	return enabled and ao_vivo()


func textura() -> Texture2D:
	if _uvc_texture != null:
		return _uvc_texture
	return _texture


func aberta() -> bool:
	return _aberta


## Ritmo de leitura dos quadros (ms): rápido só com a imagem na tela.
func definir_ritmo(ms: int) -> void:
	intervalo_ms = maxi(30, ms)
	_proxima_leitura_ms = mini(_proxima_leitura_ms, Time.get_ticks_msec() + intervalo_ms)


# ================================================================ abrir/fechar
func _abrir() -> void:
	if _aberta or not enabled:
		return
	_aberta = true
	var agora := Time.get_ticks_msec()
	_aberta_desde_ms = agora
	_ultimo_quadro_ms = 0
	_sem_quadro_desde_ms = agora
	_insistir_em_ms = agora + INSISTIR_MS
	_proxima_leitura_ms = 0
	_proxima_busca_ms = 0
	Tela.risco_camera(true)
	_registro("abrindo (%s)" % ("descoberta" if _uso == Uso.DESCOBERTA else "foto"))
	status = "ABRINDO A CÂMERA…"
	if _falsa != "":
		return
	if OS.get_name() == "Android":
		_preparar_ponte()
		# o caminho que já deu certo nesta sessão abre de novo, com a
		# paciência inteira (sem isso, a hora antiga da caçada trocava de
		# caminho logo ao reabrir, antes de o primeiro quadro chegar)
		_caca_desde_ms = agora if _caca != Caca.NENHUMA else 0
		if _caca == Caca.PONTE and _ponte_tem("startUvcCamera"):
			_android_bridge.call("startUvcCamera")
		elif _caca == Caca.SERVIDOR:
			_ligar_servidor()
			_descobrir_cameras()
		return
	_ligar_servidor()
	_descobrir_cameras()


func _fechar(porque: String) -> void:
	if not _aberta:
		return
	_aberta = false
	_registro("fechada (%s)" % porque)
	_parar_feed()
	_parar_uvc_android()
	_ultima_imagem = null
	_ultimo_quadro_ms = 0
	_melhor_imagem = null
	_obturador_ate_ms = 0
	Tela.risco_camera(false)
	status = "CÂMERA FECHADA"


func _process(_delta: float) -> void:
	var agora := Time.get_ticks_msec()
	if _descoberta_em_ms >= 0 and agora >= _descoberta_em_ms:
		_descoberta_em_ms = -1
		if _uso == Uso.NENHUM and enabled:
			_uso = Uso.DESCOBERTA
			_abrir()
	if _abrir_em_ms >= 0 and agora >= _abrir_em_ms:
		_abrir_em_ms = -1
		if _uso == Uso.FOTO:
			_abrir()
	if not _aberta:
		return
	if _uso == Uso.DESCOBERTA and (_teve_video or _sem_sinal or agora - _aberta_desde_ms > DESCOBERTA_MS):
		_descoberta_feita = true
		_uso = Uso.NENHUM
		_fechar("descoberta: %s" % ("com imagem" if _teve_video else "sem imagem"))
		return
	_conferir_sinal(agora)
	if _falsa != "":
		_quadro_falso(agora)
		return
	if not _tem_permissao():
		status = "SEM PERMISSÃO DA CÂMERA (CONFIGURAÇÕES DO ANDROID > APPS > LAZER SHOT)"
		return
	if OS.get_name() == "Android":
		_vigiar_ponte(agora)
		if _amostrar_ponte(agora):
			return
		_cacar_camera_android(agora)
		if _servidor_proibido():
			return
	# CameraServer (PC; no Android só na vez do SERVIDOR)
	if agora >= _proxima_busca_ms:
		_proxima_busca_ms = agora + INTERVALO_NOVA_BUSCA_MS
		var quantidade := CameraServer.feeds().size()
		if _feed == null or quantidade != _ultima_quantidade_feeds:
			_ultima_quantidade_feeds = quantidade
			if _feed == null:
				_descobrir_cameras()
	if _feed == null or agora < _proxima_leitura_ms:
		return
	var obturador := agora <= _obturador_ate_ms
	# ler a imagem da CameraTexture é uma cópia da placa de vídeo: no ritmo
	# pedido (rápido só na pose), e nunca mais que ~15 vezes por segundo
	_proxima_leitura_ms = agora + maxi(66 if obturador else 120, intervalo_ms)
	_amostrar_servidor(agora)


## Aberta há tempo e nenhum sinal de câmera: "não há webcam neste aparelho"
## (a pose é pulada). Qualquer imagem desfaz isso.
func _conferir_sinal(agora: int) -> void:
	if _teve_video or _sem_sinal or agora - _aberta_desde_ms < SEM_CAMERA_MS:
		return
	var alguma := false
	if _falsa != "":
		alguma = true
	elif OS.get_name() == "Android":
		alguma = _ponte_ve_camera() or _servidor_tem_camera()
	else:
		alguma = not CameraServer.feeds().is_empty()
	if not alguma:
		_sem_sinal = true
		_registro("nenhuma câmera neste aparelho")


func _registro(texto: String) -> void:
	Tela.marca("webcam: " + texto)


func _tem_permissao() -> bool:
	return OS.get_name() != "Android" or OS.get_granted_permissions().has("android.permission.CAMERA")


## A permissão da câmera ainda não foi dada (Android): a abertura pede, no
## máximo duas vezes (negada de vez, o Android nem mostra mais a janela, e a
## abertura não deve esperar por ela a cada vez que o jogo abre). Dá para
## liberar depois em Configurações do Android > Apps > Lazer Shot.
func precisa_permissao() -> bool:
	return enabled and OS.get_name() == "Android" and not _tem_permissao() \
		and int(_lembranca.get_value("webcam", "pedidos", 0)) < 2


## A abertura vai pedir a permissão agora (conta os pedidos).
func pedindo_permissao() -> void:
	_lembranca.set_value("webcam", "pedidos", int(_lembranca.get_value("webcam", "pedidos", 0)) + 1)
	_lembranca.save(LEMBRANCA)


# ================================================================ a ponte (plugin)
## NÃO SE PERGUNTA `has_method` AO PLUGIN: o objeto que o Godot entrega para
## um plugin Android só atende a chamada direta, e o `has_method` dele
## responde "não" para toda função do plugin. Esta é a lista das funções do
## PunchUsbSerial deste APK (as mesmas do Super Boxing).
const METODOS_DA_PONTE := [
	"requestUsbCameraAccess", "startUvcCamera", "stopUvcCamera", "pollUvcFrame",
	"getUvcFrameWidth", "getUvcFrameHeight", "getUvcStatus", "getUvcDiagnostics",
	"getUsbCameraStatus", "getSystemCameraCount", "getCameraReport",
]


func _ponte_tem(metodo: String) -> bool:
	return _android_bridge != null and metodo in METODOS_DA_PONTE


func _preparar_ponte() -> void:
	if _android_bridge != null or not Engine.has_singleton("PunchUsbSerial"):
		return
	# SÓ PEGA A PONTE: nada de mexer na janela do Android (o
	# prepareAndroidKiosk do plugin derrubava a imagem do jogo).
	_android_bridge = Engine.get_singleton("PunchUsbSerial")
	_registro("plugin PunchUsbSerial pronto")


func _ponte_ve_camera() -> bool:
	if _android_bridge == null:
		return false
	if _ponte_tem("getSystemCameraCount") and int(_android_bridge.call("getSystemCameraCount")) > 0:
		return true
	if _ponte_tem("getUsbCameraStatus"):
		return not "NENHUMA" in str(_android_bridge.call("getUsbCameraStatus")).to_upper()
	return false


func _servidor_proibido() -> bool:
	return OS.get_name() == "Android" and _caca != Caca.SERVIDOR


func _servidor_tem_camera() -> bool:
	return not _servidor_proibido() and not CameraServer.feeds().is_empty()


## A CAÇADA DA CÂMERA NO ANDROID. Com câmera do sistema, a PONTE; sem ela,
## o SERVIDOR (Camera2); sem imagem por um tempo num caminho, o outro.
const CACA_PONTE_MS := 15000
const CACA_SERVIDOR_MS := 12000

func _cacar_camera_android(agora: int) -> void:
	if _caca == Caca.NENHUMA:
		if _android_bridge == null:
			_mudar_caca(Caca.SERVIDOR, agora, "sem o plugin")
			return
		# a contagem do plugin sai em segundo plano: dá 1,5 s para ela
		if _caca_desde_ms == 0:
			_caca_desde_ms = agora
			if _ponte_tem("getCameraReport"):
				for linha in str(_android_bridge.call("getCameraReport")).split("\n", false):
					_registro("relatório: " + linha)
		var classicas := int(_android_bridge.call("getSystemCameraCount")) if _ponte_tem("getSystemCameraCount") else 0
		if classicas > 0:
			_lembrar("do_sistema", true)
			_mudar_caca(Caca.PONTE, agora, "%d câmera(s) do sistema" % classicas)
		elif agora - _caca_desde_ms >= 1500:
			if _ponte_ve_camera():
				_mudar_caca(Caca.PONTE, agora, "webcam só no USB")
			else:
				_mudar_caca(Caca.SERVIDOR, agora, "nenhuma câmera do sistema")
		return
	if ao_vivo():
		_caca_desde_ms = agora   # com imagem, fica onde está
		return
	var paciencia := CACA_PONTE_MS if _caca == Caca.PONTE else CACA_SERVIDOR_MS
	if agora - _caca_desde_ms < paciencia:
		return
	if _caca == Caca.PONTE:
		_mudar_caca(Caca.SERVIDOR, agora, "plugin sem imagem")
	elif _android_bridge != null:
		_mudar_caca(Caca.PONTE, agora, "Camera2 sem imagem")
	else:
		_caca_desde_ms = agora


func _mudar_caca(nova: Caca, agora: int, porque: String) -> void:
	_caca = nova
	_caca_desde_ms = agora
	if nova == Caca.SERVIDOR:
		_registro("CameraServer (%s)" % porque)
		# solta a webcam do plugin antes: um dono de cada vez
		_parar_uvc_android()
		_ligar_servidor()
		_proxima_busca_ms = 0
		status = "PROCURANDO A WEBCAM (CAMERA2)…"
	else:
		_registro("plugin (%s)" % porque)
		_parar_feed()
		_insistir_em_ms = 0
		status = "PROCURANDO A WEBCAM (PLUGIN)…"


## O plugin sem quadro: insiste em abrir (sem fechar antes: fechar uma câmera
## que nem abriu zerava o plugin e a próxima abertura voltava vazia). A
## janela USB da webcam (só para a webcam que o Android não mostra como
## câmera do sistema) só aparece com as janelas liberadas: no menu e na
## CONFIGURAÇÃO, nunca na pose.
func _vigiar_ponte(agora: int) -> void:
	if _android_bridge == null or _caca != Caca.PONTE or _feed != null:
		return
	if _ultimo_quadro_ms > 0 and agora - _ultimo_quadro_ms < VIVA_MS:
		return
	if agora < _insistir_em_ms:
		return
	_insistir_em_ms = agora + INSISTIR_MS
	var situacao := str(_android_bridge.call("getUvcStatus")) if _ponte_tem("getUvcStatus") else ""
	if situacao != "" and situacao != status:
		_registro("plugin: " + situacao)
	if _ponte_tem("getSystemCameraCount") and int(_android_bridge.call("getSystemCameraCount")) > 0 \
			or bool(_lembranca.get_value("webcam", "do_sistema", false)):
		_android_bridge.call("startUvcCamera")
		return
	if janelas_liberadas and _ponte_tem("getUsbCameraStatus") \
			and "AGUARDANDO" in str(_android_bridge.call("getUsbCameraStatus")).to_upper():
		_registro("pedindo a permissão USB da webcam")
		_android_bridge.call("requestUsbCameraAccess")
		return
	_android_bridge.call("startUvcCamera")


func _amostrar_ponte(agora: int) -> bool:
	if _android_bridge == null or _caca != Caca.PONTE or not _ponte_tem("pollUvcFrame"):
		return false
	if agora < _proxima_leitura_ms:
		return _uvc_texture != null and ao_vivo()
	var obturador := agora <= _obturador_ate_ms
	_proxima_leitura_ms = agora + (mini(intervalo_ms, 66) if obturador else intervalo_ms)
	var dados_variant = _android_bridge.call("pollUvcFrame")
	if not dados_variant is PackedByteArray:
		return _uvc_texture != null and ao_vivo()
	var dados: PackedByteArray = dados_variant
	if dados.is_empty():
		if _ponte_tem("getUvcStatus"):
			status = str(_android_bridge.call("getUvcStatus"))
		return _uvc_texture != null and ao_vivo()
	var largura := int(_android_bridge.call("getUvcFrameWidth"))
	var altura := int(_android_bridge.call("getUvcFrameHeight"))
	if largura <= 0 or altura <= 0 or dados.size() != largura * altura * 4:
		return false
	var imagem := Image.create_from_data(largura, altura, false, Image.FORMAT_RGBA8, dados)
	if imagem == null or imagem.is_empty():
		return false
	_mostrar_quadro(imagem, agora)
	status = "CÂMERA DO PLUGIN AO VIVO %dx%d" % [largura, altura]
	return true


func _mostrar_quadro(imagem: Image, agora: int) -> void:
	if _uvc_texture == null or _uvc_texture.get_width() != imagem.get_width() \
			or _uvc_texture.get_height() != imagem.get_height():
		_uvc_texture = ImageTexture.create_from_image(imagem)
	else:
		_uvc_texture.update(imagem)
	_registrar_quadro(imagem, agora)


func _parar_uvc_android() -> void:
	if _android_bridge != null and _ponte_tem("stopUvcCamera"):
		_android_bridge.call("stopUvcCamera")
	_uvc_texture = null


# ================================================================ o servidor (CameraServer)
func _ligar_servidor() -> void:
	if _servidor_proibido() or not _tem_permissao():
		return
	if CameraServer.has_method("set_monitoring_feeds"):
		CameraServer.call("set_monitoring_feeds", true)


func _descobrir_cameras() -> void:
	if _servidor_proibido() or _feed != null or not _aberta:
		return
	_ligar_servidor()
	var feeds: Array = CameraServer.feeds()
	if feeds.is_empty():
		status = "NENHUMA CÂMERA NO CAMERASERVER"
		return
	# a webcam USB costuma ser a última da lista
	var escolhido = feeds[feeds.size() - 1]
	for f in feeds:
		var nome := str(f.get_name()).to_lower() if f.has_method("get_name") else ""
		if "usb" in nome or "webcam" in nome or "uvc" in nome:
			escolhido = f
	_feed = escolhido
	_registro("CameraServer abrindo '%s' (%d na lista)" % [str(_feed.get_name()) if _feed.has_method("get_name") else "?", feeds.size()])
	_formato_leve()
	_feed.set_active(true)
	_texture = CameraTexture.new()
	_texture.camera_feed_id = _feed.get_id()
	_texture.which_feed = CameraServer.FEED_RGBA_IMAGE
	_proxima_leitura_ms = 0
	status = "ABRINDO A CÂMERA (CAMERA2)…"


## 640x480 (ou o mais perto disso, 20 quadros ou mais): a foto tem 320 px, e
## pedir 720p só aumentaria o USB, a conversão e a leitura da placa de vídeo.
func _formato_leve() -> void:
	if _feed == null or not _feed.has_method("get_formats") or not _feed.has_method("set_format"):
		return
	var formatos: Array = _feed.get_formats()
	if formatos.is_empty():
		return
	var melhor := -1
	var melhor_nota := -1.0e30
	for i in range(formatos.size()):
		var f: Dictionary = formatos[i]
		var w := int(f.get("width", 0))
		var h := int(f.get("height", 0))
		var fps := float(f.get("framerate_numerator", 0)) / maxf(float(f.get("framerate_denominator", 1)), 1.0)
		if w <= 0 or h <= 0 or (fps > 0.0 and fps < 20.0):
			continue
		var nota := -absf(float(w - 640)) - absf(float(h - 480)) * 1.5 + minf(fps, 30.0) * 20.0
		if str(f.get("format", "")) == "MJPG":
			nota += 250.0
		if nota > melhor_nota:
			melhor_nota = nota
			melhor = i
	_feed.set_format(maxi(melhor, 0), {})


func _amostrar_servidor(agora: int) -> void:
	if _texture == null:
		return
	var imagem := _texture.get_image()
	if imagem == null or imagem.is_empty():
		return
	if imagem.get_format() != Image.FORMAT_RGBA8:
		imagem.convert(Image.FORMAT_RGBA8)
	_registrar_quadro(imagem, agora)
	status = "CÂMERA (CAMERA2) AO VIVO %dx%d" % [imagem.get_width(), imagem.get_height()]


func _parar_feed() -> void:
	if _feed != null:
		_feed.set_active(false)
	_feed = null
	_texture = null


# ================================================================ quadros
func _registrar_quadro(imagem: Image, agora: int) -> void:
	var medida := _medir(imagem)
	var assinatura := int(medida.y)
	# imagem de verdade é imagem que muda (um quadro preto parado não conta)
	if assinatura != _assinatura:
		_assinatura = assinatura
		if not _teve_video and medida.x > CONTRASTE_MINIMO:
			_teve_video = true
			_sem_sinal = false
			_lembrar("vista", true)
			_registro("primeira imagem: %dx%d em %d ms" % [imagem.get_width(), imagem.get_height(), agora - _aberta_desde_ms])
	_ultima_imagem = imagem
	_ultimo_quadro_ms = agora
	_oferecer_ao_obturador(imagem, medida.x)


## (contraste, assinatura) de uma grade de 8x6 pontos.
func _medir(imagem: Image) -> Vector2:
	if imagem == null or imagem.is_empty() or imagem.get_width() < 8 or imagem.get_height() < 8:
		return Vector2(-1.0, 0.0)
	var claro := 0.0
	var escuro := 1.0
	var assinatura := 0
	for gx in range(8):
		for gy in range(6):
			var x := int((float(gx) + 0.5) / 8.0 * float(imagem.get_width()))
			var y := int((float(gy) + 0.5) / 6.0 * float(imagem.get_height()))
			var v := imagem.get_pixel(x, y).get_luminance()
			claro = maxf(claro, v)
			escuro = minf(escuro, v)
			assinatura = (assinatura * 31 + int(v * 255.0)) & 0x3FFFFF
	return Vector2(claro - escuro, float(assinatura))


# ================================================================ a foto
## O OBTURADOR ABRE NA RETA FINAL DA CONTAGEM (como no Super Boxing): a foto
## é o quadro de melhor contraste desta janela, e só dela. Aberto na
## contagem inteira, um quadro de quando a pessoa ainda se ajeitava podia
## vencer a pose final.
func abrir_obturador(janela_ms: int) -> void:
	_melhor_imagem = null
	_melhor_nota = -1.0
	_obturador_ate_ms = Time.get_ticks_msec() + janela_ms
	_proxima_leitura_ms = 0


func _oferecer_ao_obturador(imagem: Image, nota: float) -> void:
	if Time.get_ticks_msec() > _obturador_ate_ms:
		return
	if nota > _melhor_nota:
		_melhor_nota = nota
		_melhor_imagem = imagem.duplicate()


## Tira a foto: devolve o caminho do arquivo (gravado em segundo plano) ou
## "" se não havia imagem de verdade.
func tirar_foto() -> String:
	var imagem: Image = null
	if _melhor_imagem != null and _melhor_nota >= CONTRASTE_MINIMO:
		imagem = _melhor_imagem
	elif _ultima_imagem != null and ao_vivo():
		imagem = _ultima_imagem.duplicate()
	_melhor_imagem = null
	_melhor_nota = -1.0
	_obturador_ate_ms = 0
	if imagem == null or imagem.is_empty() or _medir(imagem).x <= 0.0:
		_registro("foto: sem imagem")
		return ""
	ultima_foto = imagem
	ultima_foto_quadrada = null
	ultima_foto_caminho = ""
	DirAccess.make_dir_recursive_absolute(PASTA_FOTOS)
	var caminho := "%s/foto_%d_%03d.jpg" % [PASTA_FOTOS, int(Time.get_unix_time_from_system()), Time.get_ticks_msec() % 1000]
	WorkerThreadPool.add_task(_gravar.bind(imagem.duplicate(), caminho, espelhar, girar))
	_registro("foto: " + caminho.get_file())
	return caminho


## O recorte quadrado do meio, virado como a prévia, no tamanho do ranking.
static func recortar(imagem: Image, espelho: bool, graus: int, lado: int) -> Image:
	var l := mini(imagem.get_width(), imagem.get_height())
	var origem := Vector2i((imagem.get_width() - l) / 2, (imagem.get_height() - l) / 2)
	var r := imagem.get_region(Rect2i(origem, Vector2i(l, l)))
	if l != lado:
		r.resize(lado, lado, Image.INTERPOLATE_BILINEAR if l > lado * 2 else Image.INTERPOLATE_LANCZOS)
	if espelho:
		r.flip_x()
	match graus:
		90:
			r.rotate_90(CLOCKWISE)
		180:
			r.rotate_180()
		270:
			r.rotate_90(COUNTERCLOCKWISE)
	return r


func _gravar(imagem: Image, caminho: String, espelho: bool, graus: int) -> void:
	var r := recortar(imagem, espelho, graus, LADO_FOTO)
	r.save_jpg(caminho, 0.9)
	_gravou.call_deferred(caminho, r)


func _gravou(caminho: String, r: Image) -> void:
	ultima_foto_quadrada = r
	ultima_foto_caminho = caminho
	foto_gravada.emit(caminho)


# ================================================================ lembrança
func _lembrar(chave: String, valor: bool) -> void:
	if bool(_lembranca.get_value("webcam", chave, false)) == valor:
		return
	_lembranca.set_value("webcam", chave, valor)
	_lembranca.save(LEMBRANCA)


# ================================================================ teste no PC
## LAZER_CAMERA_FALSA: uma imagem de teste que mexe (fundo, "rosto" e uma
## faixa andando), no ritmo pedido, depois de um instante abrindo.
func _quadro_falso(agora: int) -> void:
	var espera := 9000 if _falsa == "lenta" else 1200
	if agora - _aberta_desde_ms < espera or agora < _proxima_leitura_ms:
		return
	_proxima_leitura_ms = agora + intervalo_ms
	_falsa_t = float(agora) / 1000.0
	if _falsa_img == null:
		_falsa_img = Image.create(640, 480, false, Image.FORMAT_RGBA8)
	var img := _falsa_img
	var fundo := Color.from_hsv(fmod(_falsa_t * 0.05, 1.0), 0.35, 0.45)
	img.fill(fundo)
	img.fill_rect(Rect2i(0, 330, 640, 150), fundo.darkened(0.4))
	var cx := 320 + int(sin(_falsa_t * 1.3) * 60.0)
	img.fill_rect(Rect2i(cx - 70, 110, 140, 170), Color(0.93, 0.76, 0.62))
	img.fill_rect(Rect2i(cx - 45, 165, 25, 18), Color(0.1, 0.1, 0.12))
	img.fill_rect(Rect2i(cx + 20, 165, 25, 18), Color(0.1, 0.1, 0.12))
	img.fill_rect(Rect2i(cx - 30, 230, 60, 14), Color(0.55, 0.15, 0.15))
	img.fill_rect(Rect2i(cx - 110, 280, 220, 200), Color(0.15, 0.3, 0.75))
	var faixa := int(fmod(_falsa_t * 120.0, 640.0))
	img.fill_rect(Rect2i(faixa, 0, 16, 40), Color.WHITE)
	_mostrar_quadro(img.duplicate(), agora)
	status = "CÂMERA DE TESTE (LAZER_CAMERA_FALSA)"


# ================================================================ diagnóstico
## Linhas para a CONFIGURAÇÃO (TESTAR CÂMERA).
func relatorio() -> PackedStringArray:
	var r := PackedStringArray()
	r.append("Estado: " + status)
	var nomes := ["procurando", "plugin (câmera do sistema / USB)", "Camera2 do Godot"]
	var caminho: String = "teste no PC" if _falsa != "" else ("CameraServer" if OS.get_name() != "Android" else nomes[_caca])
	r.append("Caminho: %s  ·  plugin %s" % [caminho, "presente" if Engine.has_singleton("PunchUsbSerial") else "ausente"])
	r.append("Imagem: %s  ·  já vista neste aparelho: %s" % [
		"ao vivo" if ao_vivo() else "sem imagem", "sim" if conhecida() else "não"])
	if OS.get_name() == "Android":
		r.append("Permissão da câmera: " + ("dada" if _tem_permissao() else "NEGADA"))
		if _android_bridge != null and _ponte_tem("getCameraReport"):
			for linha in str(_android_bridge.call("getCameraReport")).split("\n", false):
				r.append(linha)
	return r


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and _aberta:
		# de volta do segundo plano: a webcam pode ter sido tomada; insiste já
		_insistir_em_ms = mini(_insistir_em_ms, Time.get_ticks_msec() + 1500)
		_proxima_busca_ms = 0


func _exit_tree() -> void:
	_fechar("saída do jogo")
