class_name VideoNativo
extends Control

## VÍDEO PELO DECODIFICADOR DE HARDWARE DA TV BOX.
##
## O player de vídeo do Godot (Theora) decodifica tudo no processador, na
## mesma linha do jogo: decodifica, converte cor pixel a pixel e manda a
## imagem inteira para a placa a cada quadro. Na TV Box isso trava até vídeo
## pequeno. A TV Box toca 1080p liso porque tem decodificador de vídeo em
## hardware; aqui o vídeo (H.264, .mp4) vai para ele:
##
##   MediaPlayer do Android -> SurfaceTexture -> ExternalTexture do Godot
##
## e o quadro já decodificado é desenhado direto da placa de vídeo, dentro do
## jogo (gira com a tela, fica atrás dos textos). Custo de processador ~zero.
##
## Plano B: se algo falhar no aparelho (ou no PC), toca o .ogv no player do
## Godot, como antes. A configuração "video/nativo" desliga o hardware.

signal comecou   # primeiro quadro na tela
signal falhou    # sem hardware e sem plano B: a tela fica com o fundo de baixo

const SHADER_OES := "res://shaders/video_oes.gdshader"
const ESPERA_MAX := 3.0          # segundos sem quadro -> plano B
const CORTE_MAX := 0.03          # tela cheia: corta no máximo 3% de cada lado
const PASTA_COPIA := "user://videos/"

var mp4 := ""                    # res://...mp4 (hardware)
var ogv := ""                    # res://...ogv (plano B)
var tamanho := Vector2(720, 1080)
var repetir := true
var volume := 0.0                # 0..1, som do próprio vídeo (se tiver)
## Só pelo hardware: sem ele, não toca nada (a tela fica com o fundo de baixo)
## em vez de cair no player do Godot, que trava a TV Box.
var so_hardware := false

## "nativo", "godot" ou "" (parado).
var modo := ""

var _rect: ColorRect = null
var _ext: ExternalTexture = null
# objetos Java (chamadas dinâmicas, sem tipo estático)
var _st = null                   # android.graphics.SurfaceTexture
var _superficie = null           # android.view.Surface
var _mp = null                   # android.media.MediaPlayer
var _classe_mp = null
var _fio: Thread = null
var _pronto := false             # escrito pela thread
var _erro := ""                  # escrito pela thread
var _espera := 0.0
var _mostrando := false
var _conferir := 0
var _player: VideoStreamPlayer = null


func _init(p_mp4: String = "", p_ogv: String = "", p_tamanho: Vector2 = Vector2(720, 1080), p_repetir: bool = true, p_volume: float = 0.0) -> void:
	mp4 = p_mp4
	ogv = p_ogv
	tamanho = p_tamanho
	repetir = p_repetir
	volume = p_volume
	name = "VideoNativo"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	get_viewport().size_changed.connect(ajustar)
	ajustar()


func tocar() -> void:
	if modo != "":
		return
	if Tela.modo_seguro():
		# o jogo fechou cedo da última vez: nesta sessão, nenhum vídeo (a tela
		# fica com o fundo parado de baixo)
		Tela.marca("vídeo desligado (modo de segurança): " + mp4.get_file())
		falhou.emit.call_deferred()
		return
	if _pode_nativo():
		_iniciar_nativo()
	elif not so_hardware or OS.get_name() != "Android":
		_iniciar_godot()
	else:
		falhou.emit.call_deferred()


func parar() -> void:
	_soltar_nativo()
	if _player != null:
		_player.stop()
		_player.queue_free()
		_player = null
	modo = ""
	_mostrando = false


func esta_mostrando() -> bool:
	return _mostrando


## Já entrou por inteiro (fim do esmaecimento): o que está embaixo pode
## deixar de ser desenhado.
func cobre_tela() -> bool:
	if not _mostrando or modulate.a < 0.999:
		return false
	var no: CanvasItem = _rect if _rect != null else _player
	return no != null and no.modulate.a >= 0.999


## Pausa sem soltar o decodificador (escondido, não gasta nada); continua de
## onde parou.
func pausar() -> void:
	if modo == "nativo" and _mp != null and _pronto:
		_mp.pause()
	elif _player != null:
		_player.paused = true


func continuar() -> void:
	if modo == "nativo" and _mp != null and _pronto:
		_mp.start()
	elif _player != null:
		_player.paused = false


func _exit_tree() -> void:
	parar()


func _pode_nativo() -> bool:
	if OS.get_name() != "Android" or mp4 == "" or not FileAccess.file_exists(mp4):
		return false
	return bool(Maquina.valor("video/nativo"))


# ───────────────────────────────────────────── hardware
func _iniciar_nativo() -> void:
	modo = "nativo"
	_espera = 0.0
	Tela.marca("vídeo hardware: preparando " + mp4.get_file())
	_ext = ExternalTexture.new()
	_ext.size = tamanho
	var id := _ext.get_external_texture_id()
	if id <= 0:
		_falhar("textura externa indisponível")
		return
	_st = JavaClassWrapper.wrap("android.graphics.SurfaceTexture").SurfaceTexture(id)
	if _st == null or _excecao():
		_falhar("SurfaceTexture")
		return
	_superficie = JavaClassWrapper.wrap("android.view.Surface").Surface(_st)
	if _superficie == null or _excecao():
		_falhar("Surface")
		return
	_classe_mp = JavaClassWrapper.wrap("android.media.MediaPlayer")

	_rect = ColorRect.new()
	_rect.name = "Quadro"
	_rect.color = Color.WHITE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_OES)
	mat.set_shader_parameter("video", _ext)
	mat.set_shader_parameter("virar", bool(Maquina.valor("video/virar")))
	_rect.material = mat
	add_child(_rect)
	ajustar()

	# Copiar o arquivo (1ª vez) e preparar o decodificador leva um tempinho:
	# fora da linha do jogo.
	_fio = Thread.new()
	_fio.start(_preparar_player)


## Thread: copia o .mp4 para a memória interna e prepara o MediaPlayer.
func _preparar_player() -> void:
	var caminho := _copia_local(mp4)
	if caminho == "":
		_erro = "cópia do vídeo"
		return
	var mp = _classe_mp.MediaPlayer()
	if mp == null:
		_erro = "MediaPlayer"
		return
	mp.setSurface(_superficie)
	mp.setDataSource(caminho)
	mp.setLooping(repetir)
	mp.setVolume(volume, volume)
	mp.prepare()
	if JavaClassWrapper.get_exception() != null:
		mp.release()
		_erro = "MediaPlayer.prepare"
		return
	mp.start()
	_mp = mp
	_pronto = true


## O MediaPlayer precisa de um arquivo de verdade: copia do pacote do jogo
## para a memória interna na primeira vez (e quando o vídeo mudar de tamanho).
static var _trava_copia := Mutex.new()


static func _copia_local(origem: String) -> String:
	_trava_copia.lock()
	var caminho := _copiar(origem)
	_trava_copia.unlock()
	return caminho


static func _copiar(origem: String) -> String:
	DirAccess.make_dir_recursive_absolute(PASTA_COPIA)
	var destino := PASTA_COPIA + origem.get_file()
	var leitor := FileAccess.open(origem, FileAccess.READ)
	if leitor == null:
		return ""
	var tam := leitor.get_length()
	if FileAccess.file_exists(destino):
		var atual := FileAccess.open(destino, FileAccess.READ)
		if atual != null and atual.get_length() == tam:
			return ProjectSettings.globalize_path(destino)
	# grava num temporário e só renomeia no fim: nunca fica meio arquivo
	var temp := destino + ".tmp"
	var escritor := FileAccess.open(temp, FileAccess.WRITE)
	if escritor == null:
		return ""
	while leitor.get_position() < tam:
		escritor.store_buffer(leitor.get_buffer(mini(1 << 20, tam - leitor.get_position())))
	escritor.close()
	if DirAccess.rename_absolute(temp, destino) != OK:
		return ""
	return ProjectSettings.globalize_path(destino)


func _process(delta: float) -> void:
	if modo != "nativo":
		return
	if _erro != "":
		_falhar(_erro)
		return
	# traz o quadro mais novo do decodificador para a textura (na linha do
	# jogo, que é a dona do contexto OpenGL)
	_st.updateTexImage()
	if _conferir < 30:
		_conferir += 1
		if _excecao():
			_falhar("updateTexImage")
			return
	if not _mostrando:
		_espera += delta
		if _pronto and int(_st.getTimestamp()) != 0:
			Tela.marca("vídeo hardware: tocando " + mp4.get_file())
			_mostrar(_rect)
		elif _espera > ESPERA_MAX:
			_falhar("nenhum quadro em %.0f s" % ESPERA_MAX)


func _excecao() -> bool:
	var e = JavaClassWrapper.get_exception()
	if e != null:
		push_warning("VideoNativo: exceção Java %s" % str(e))
		return true
	return false


func _falhar(motivo: String) -> void:
	Tela.marca("vídeo hardware falhou (%s): %s" % [mp4.get_file(), motivo])
	push_warning("VideoNativo: hardware indisponível (%s)" % motivo)
	_soltar_nativo()
	modo = ""
	if not so_hardware:
		_iniciar_godot()
	if modo == "":
		falhou.emit()


func _soltar_nativo() -> void:
	if _fio != null:
		if _fio.is_started():
			_fio.wait_to_finish()
		_fio = null
	if _mp != null:
		_mp.stop()
		_mp.release()
		_mp = null
	if _superficie != null:
		_superficie.release()
		_superficie = null
	if _st != null:
		_st.release()
		_st = null
	if _rect != null:
		_rect.queue_free()
		_rect = null
	_ext = null
	_pronto = false
	_erro = ""


# ───────────────────────────────────────────── plano B (Godot)
func _iniciar_godot() -> void:
	if ogv == "" or not ResourceLoader.exists(ogv):
		return
	modo = "godot"
	_player = VideoStreamPlayer.new()
	_player.name = "Player"
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player.loop = repetir
	_player.volume = volume
	_player.modulate.a = 0.0
	_player.stream = load(ogv)
	add_child(_player)
	ajustar()
	_player.play()
	_mostrar(_player)


func _mostrar(no: CanvasItem) -> void:
	_mostrando = true
	var tw := create_tween()
	tw.tween_property(no, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	comecou.emit()


# ───────────────────────────────────────────── tela cheia
func ajustar() -> void:
	var tela := get_viewport_rect().size
	position = Vector2.ZERO
	size = tela
	var prop := tamanho.x / maxf(tamanho.y, 1.0)
	if _player != null:
		Leve.cobrir_video(_player, tela, prop, CORTE_MAX)
	if _rect != null:
		var tam := tela
		var largura_cheia := tela.y * prop
		if largura_cheia > tela.x:
			tam.x = minf(largura_cheia, tela.x / (1.0 - 2.0 * CORTE_MAX))
		else:
			tam.y = minf(tela.x / prop, tela.y / (1.0 - 2.0 * CORTE_MAX))
		_rect.position = ((tela - tam) * 0.5).round()
		_rect.size = tam.round()
