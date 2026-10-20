class_name FotosRanking
extends RefCounted

## AS FOTOS DO RANKING NA TELA (Rodada 31), sem engasgar a TV Box.
##
## Cada foto é um JPG de 320x320 (scripts/webcam.gd). Abrir JPG custa alguns
## milissegundos na TV Box, e o ranking mostra até 20: abrindo todos no
## mesmo quadro, a tela travava. Aqui cada foto é aberta e diminuída numa
## thread do pool; a tela pede a textura a cada quadro (textura()) e recebe
## null até ela ficar pronta. As prontas ficam guardadas para as próximas
## vezes que o ranking aparecer (o ranking passa a cada volta da abertura).
##
## Sem foto (recorde antigo, partida sem webcam): FotosRanking.vazia().

const VAZIA := preload("res://sprites/foto_vazia.png")
const MAX_GUARDADAS := 40

static var _guardadas: Dictionary = {}   # "caminho|lado" -> ImageTexture
static var _prontas: Dictionary = {}     # "caminho|lado" -> Image (da thread)
static var _pedidas: Dictionary = {}     # "caminho|lado" -> true
static var _ordem: Array[String] = []
static var _trava := Mutex.new()


static func vazia() -> Texture2D:
	return VAZIA


## A textura da foto em `lado` px (null enquanto abre; vazia() se não há).
static func textura(caminho: String, lado: int) -> Texture2D:
	if caminho == "":
		return VAZIA
	var chave := "%s|%d" % [caminho, lado]
	var t: Texture2D = _guardadas.get(chave)
	if t != null:
		return t
	_trava.lock()
	var img: Image = _prontas.get(chave)
	if img != null:
		_prontas.erase(chave)
	_trava.unlock()
	if img != null:
		_pedidas.erase(chave)
		if img.is_empty():
			_guardar(chave, VAZIA)
			return VAZIA
		var nova := ImageTexture.create_from_image(img)
		_guardar(chave, nova)
		return nova
	if not _pedidas.has(chave):
		if not FileAccess.file_exists(caminho):
			_guardar(chave, VAZIA)
			return VAZIA
		_pedidas[chave] = true
		WorkerThreadPool.add_task(_abrir.bind(caminho, lado, chave))
	return null


## A foto já está na memória (acabou de ser tirada): entra direto.
static func guardar_imagem(caminho: String, img: Image, lado: int) -> void:
	if caminho == "" or img == null or img.is_empty():
		return
	var copia := img.duplicate() as Image
	if copia.get_width() != lado:
		copia.resize(lado, lado, Image.INTERPOLATE_BILINEAR)
	_guardar("%s|%d" % [caminho, lado], ImageTexture.create_from_image(copia))


static func _guardar(chave: String, t: Texture2D) -> void:
	_guardadas[chave] = t
	_ordem.erase(chave)
	_ordem.append(chave)
	while _ordem.size() > MAX_GUARDADAS:
		_guardadas.erase(_ordem.pop_front())


static func _abrir(caminho: String, lado: int, chave: String) -> void:
	var img := Image.load_from_file(caminho)
	if img == null:
		img = Image.new()
	elif not img.is_empty() and img.get_width() != lado:
		img.resize(lado, lado, Image.INTERPOLATE_BILINEAR)
	_trava.lock()
	_prontas[chave] = img
	_trava.unlock()
