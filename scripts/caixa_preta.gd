extends Node

## CAIXA-PRETA: o que o jogo estava fazendo quando parou na TV Box. Grava
## em silêncio; nada aparece na tela do jogo. Para ver: CONFIGURAÇÕES (F10 ou
## SELECT segurado 3 s) > CAIXA-PRETA > VER (scripts/admin.gd).
##
## Grava em user://caixa_preta/ (memória interna do app, sem permissão):
##   sessao.txt    esta sessão: aparelho, placa de vídeo, memória, cada troca
##                 de tela, cada erro do motor ou dos scripts e um pulso a
##                 cada 30 s (fps e memória). Cada linha vai para o disco na
##                 hora, então sobra mesmo se o app fechar de repente.
##   anterior.txt  a sessão de antes.
##   queda.txt     a última sessão que parou sozinha em menos de 10 min (não
##                 é apagada pelas aberturas seguintes).
##   vivo.txt      quanto tempo a sessão está rodando (reescrito a cada 2 s).
## Os primeiros quadros (1, 2, 3, 10, 60 e 300) também são anotados, com a
## memória livre do aparelho: numa tela preta, diz se o jogo chegou a
## desenhar.
## Na abertura seguinte, as últimas linhas da sessão anterior também saem no
## registro do Android (GERAR_APK_PRO_ULTRA.bat -Registro as puxa pelo adb).
##
## CÓPIA FORA DO APP (só na TV Box): na partida do app, e só nela, como na
## 1.24.0, anterior.txt, queda.txt e o começo de sessao.txt são copiados
## para Android/data/com.lazersport.lazershot/files/caixa_preta, a pasta do
## app que o gerenciador de arquivos da TV Box enxerga. Desde a Rodada 30
## nada mais é copiado durante o jogo: a cópia em thread da 1.29.0 (o Godot
## grava nessa pasta pelo Java, e de uma thread do motor isso era novo) é a
## principal suspeita da tela preta que voltou na abertura. A sessão que
## caiu chega inteira lá na abertura seguinte (anterior.txt). O pendrive não
## recebe cópia: no Android 10 o Godot só grava nas pastas do próprio app na
## memória da TV Box.
##
## PROTEÇÃO PONTUAL (só na TV Box): o jogo avisa quando entra num trecho que
## depende do aparelho (Tela.risco("abertura"), Tela.risco("video")) e
## quando sai (Tela.risco("")). Se o app morrer DENTRO de um desses trechos,
## nesta mesma versão, só aquele trecho é contornado nas próximas aberturas.
## O vídeo precisa de DUAS quedas (uma pode ter sido alguém saindo do jogo);
## os outros, de uma:
##   "video"            os vídeos tocam pelo player do Godot em vez do hardware
##   "abertura"         a apresentação Lazer & Sport é pulada
##   "desenho:<jeito>"  aquele jeito de desenhar fica desligado no jogo todo
##   "shader:<nome>"    aquele shader vira um desenho simples
##   "som"              efeitos sonoros desligados
##   "arma"             a mira segue o ponteiro sem capturá-lo
##   "acerto:<alvo>"    no Mar, aquele alvo (bau, vaso, aguaviva, bomba) é
##                      acertado sem o efeito especial e sem o som dele
##   "camera"           sem a foto antes da partida (a webcam não abre mais)
## (scripts/contorno_desenho.gd aplica). Todo o resto continua igual.
## Instalar uma versão nova zera tudo.
##
## A WEBCAM TEM MARCA PRÓPRIA (Rodada 31): ela fica aberta enquanto a tela da
## pose mostra a imagem, e a tela pode ter outro trecho arriscado ao mesmo
## tempo (o vídeo do menu, por exemplo). camera.txt existe enquanto ela está
## aberta; duas quedas com ela aberta, nesta versão, contornam "camera".
##
## Criada pela Tela (o primeiro autoload) no _init, antes de qualquer cena.
## Outros scripts marcam etapas com Tela.marca("texto").

const VERSAO := "1.31.0"
const PASTA := "user://caixa_preta"
const SESSAO := PASTA + "/sessao.txt"
const ANTERIOR := PASTA + "/anterior.txt"
const VIVO := PASTA + "/vivo.txt"
const SEGURANCA := PASTA + "/contornos.txt"   # "versão|trecho|trecho..."
const QUASE := PASTA + "/quase.txt"           # "versão|trecho" da 1ª queda num trecho
const RISCO := PASTA + "/risco.txt"           # "versão|trecho" enquanto está nele
const CAMERA := PASTA + "/camera.txt"         # "versão" enquanto a webcam está aberta
const CAMERA_QUASE := PASTA + "/camera_quase.txt"   # "versão" da 1ª queda com ela aberta
const QUEDA := PASTA + "/queda.txt"
const QUEDA_ATE := 600.0       # s: parou sozinha antes disso = provável queda
const MAX_LINHAS := 2500      # depois disso o arquivo recomeça (fica o cabeçalho)
const LINHAS_NO_REGISTRO := 40
const LINHAS_NA_TELA := 48    # últimas linhas mostradas na configuração (resumo)
const QUADROS_MARCADOS := [1, 2, 3, 10, 60, 300]


## Escreve no arquivo; o motor chama de qualquer thread.
class Gravador extends RefCounted:
	var arq: FileAccess
	var trava := Mutex.new()
	var linhas := 0
	var cabecalho: PackedStringArray = []
	var escrevendo := false
	var ultimo := ""
	var repetiu := 0
	var inicio := Time.get_ticks_msec()

	func escrever(txt: String) -> void:
		txt = txt.replace("\r", "").replace("\n", " / ")
		trava.lock()
		if not escrevendo and arq != null:
			escrevendo = true
			if txt == ultimo:
				repetiu += 1
			else:
				if repetiu > 0:
					_linha("   (repetiu %d vezes)" % repetiu)
				repetiu = 0
				ultimo = txt
				_linha(txt)
			escrevendo = false
		trava.unlock()

	func _linha(txt: String) -> void:
		if linhas >= MAX_LINHAS:
			# sessão longa: recomeça o arquivo com o cabeçalho (o que importa
			# é o fim, quando o jogo para)
			arq = FileAccess.open(SESSAO, FileAccess.WRITE)
			if arq == null:
				return
			linhas = 0
			for c in cabecalho:
				arq.store_line(c)
			arq.store_line("        (sessão longa: linhas antigas apagadas)")
		linhas += 1
		var l := "%7.1f  %s" % [(Time.get_ticks_msec() - inicio) / 1000.0, txt]
		if cabecalho.size() < 5:
			cabecalho.append(l)
		arq.store_line(l)
		arq.flush()


## Recebe tudo o que o motor e os scripts imprimem ou dão de erro.
class Registro extends Logger:
	var gravador: Gravador

	func _init(g: Gravador) -> void:
		gravador = g

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		# aviso de layout que as fases dão ao montar o HUD: não diz nada aqui
		# (vem no código quando não há explicação)
		if rationale.begins_with("Nodes with non-equal opposite anchors") or code.begins_with("Nodes with non-equal opposite anchors"):
			return
		var tipo := "AVISO" if error_type == 1 else "ERRO"
		var onde := "%s:%d %s" % [file.get_file(), line, function]
		for bt in script_backtraces:
			if bt != null and bt.get_frame_count() > 0:
				onde = "%s:%d %s" % [bt.get_frame_file(0).get_file(), bt.get_frame_line(0), bt.get_frame_function(0)]
				break
		gravador.escrever("%s %s | %s" % [tipo, onde, rationale if rationale != "" else code])

	func _log_message(message: String, error: bool) -> void:
		var m := message.strip_edges()
		# os botões da arma imprimem a cada tiro: não interessam aqui
		if not error and (m.begins_with("BOT") or m.begins_with("DEBUG")):
			return
		gravador.escrever(("ERRO " if error else "") + m)


## trechos contornados nesta versão (ver o começo do arquivo)
var contornos: PackedStringArray = []
var _risco := ""
var _camera_aberta := false

var _gravador := Gravador.new()
var _registro: Registro
var _duracao_anterior := -1.0
var _anterior_caiu := false   # a sessão anterior parou sozinha (TV Box)
var _t := 0.0
var _vivo_t := 0.0
var _pulso_t := 0.0
var _cena_id := 0
var _externas: Array[String] = []   # pasta do app que o gerenciador de arquivos enxerga
var _conferir := 0     # quadros que faltam para anotar o "ok" de marca_quadro
var _conferir_txt := ""
var _quadros := 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(PASTA)
	_ler_contornos()
	_guardar_sessao_anterior()
	_gravador.arq = FileAccess.open(SESSAO, FileAccess.WRITE)
	_registro = Registro.new(_gravador)
	OS.add_logger(_registro)
	marca("LAZER SHOT %s  |  %s" % [VERSAO, Time.get_datetime_string_from_system(false, true)])
	var mem := OS.get_memory_info()
	marca("aparelho: %s | %s %s | CPU %s x%d" % [OS.get_model_name(), OS.get_name(), OS.get_version(), OS.get_processor_name(), OS.get_processor_count()])
	marca("memória: total %d MB, livre %d MB" % [int(mem.get("physical", 0)) >> 20, int(mem.get("available", 0)) >> 20])
	if _duracao_anterior >= 0.0:
		marca("sessão anterior durou %.0f s" % _duracao_anterior)
	if not contornos.is_empty():
		marca("contornando nesta versão: " + ", ".join(contornos))


func _ready() -> void:
	# como na 1.24.0: a pasta do app que o gerenciador de arquivos enxerga
	# recebe a caixa-preta na partida (e só nela: ver o começo do arquivo)
	_externas = _pastas_externas()
	for caminho in _externas:
		marca("cópia da caixa-preta em " + caminho)
	_copiar_fora(ANTERIOR, "anterior.txt")
	_copiar_fora(QUEDA, "queda.txt")
	_copiar_fora(SESSAO, "sessao.txt")
	marca("vídeo: %s | %s | %s | tela %s | janela %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(),
		RenderingServer.get_video_adapter_api_version(), DisplayServer.screen_get_size(), DisplayServer.window_get_size()])
	# (o contorno "abertura" é aplicado pela própria apresentação: ela vai
	# direto para o menu, scripts/abertura_ls.gd)


## Este trecho já derrubou o app nesta versão?
func contorna(trecho: String) -> bool:
	return trecho in contornos


func risco_atual() -> String:
	return _risco


## Quantos segundos a sessão anterior durou (-1: não havia).
func duracao_anterior() -> float:
	return _duracao_anterior


## Entrando ("abertura", "video") ou saindo ("") de um trecho arriscado.
func risco(trecho: String) -> void:
	if trecho == _risco:
		return
	_risco = trecho
	if trecho == "":
		DirAccess.remove_absolute(RISCO)
		return
	marca("trecho: " + trecho)
	var f := FileAccess.open(RISCO, FileAccess.WRITE)
	if f != null:
		f.store_string("%s|%s" % [VERSAO, trecho])
		f.close()


## A webcam abriu (true) ou foi solta (false). Ver o começo do arquivo.
func risco_camera(aberta: bool) -> void:
	if aberta == _camera_aberta:
		return
	_camera_aberta = aberta
	if not aberta:
		DirAccess.remove_absolute(CAMERA)
		return
	var f := FileAccess.open(CAMERA, FileAccess.WRITE)
	if f != null:
		f.store_string(VERSAO)
		f.close()


func _ler_contornos() -> void:
	if not FileAccess.file_exists(SEGURANCA):
		return
	var partes := FileAccess.get_file_as_string(SEGURANCA).strip_edges().split("|")
	if partes.size() > 1 and partes[0] == VERSAO:
		contornos = partes.slice(1)
	else:
		DirAccess.remove_absolute(SEGURANCA)   # versão nova: zera


func _exit_tree() -> void:
	marca("fim da sessão (o jogo fechou normalmente)")
	OS.remove_logger(_registro)


## Uma linha na caixa-preta (qualquer script: Tela.marca("...")).
func marca(txt: String) -> void:
	_gravador.escrever(txt)


## Marca agora e anota "ok" quando os dois quadros seguintes já tiverem sido
## desenhados: numa queda, diz se foi no próprio instante (tiro, acerto).
func marca_quadro(txt: String) -> void:
	marca(txt)
	_conferir = 3
	_conferir_txt = txt


func _process(delta: float) -> void:
	_t += delta
	if _quadros < 300:
		_quadros += 1
		if _quadros in QUADROS_MARCADOS:
			marca("quadro %d | %s" % [_quadros, _estado()])
	if _conferir > 0:
		_conferir -= 1
		if _conferir == 0:
			marca("  ok, desenhado depois de: " + _conferir_txt)
	var cena := get_tree().current_scene
	var id := cena.get_instance_id() if cena != null else 0
	if id != _cena_id:
		_cena_id = id
		if cena != null:
			marca("TELA %s (%s) | %s" % [cena.name, cena.scene_file_path.get_file(), _estado()])
	_vivo_t -= delta
	if _vivo_t <= 0.0:
		_vivo_t = 2.0
		var f := FileAccess.open(VIVO, FileAccess.WRITE)
		if f != null:
			f.store_string("%.1f" % _t)
	_pulso_t += delta
	if _pulso_t >= 30.0:
		_pulso_t = 0.0
		marca("pulso | %s" % _estado())


## Android/data/<app>/files/caixa_preta na memória da TV Box (pedida ao
## Android, como na 1.24.0). É a única pasta fora do app em que o Godot
## grava no Android 10 (a do pendrive fica fora do alcance dele).
func _pastas_externas() -> Array[String]:
	var r: Array[String] = []
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return r
	var rt = Engine.get_singleton("AndroidRuntime")
	var ctx = rt.getApplicationContext() if rt != null else null
	var dir = ctx.getExternalFilesDir(null) if ctx != null else null
	if dir == null:
		return r
	var caminho := str(dir.getAbsolutePath()).path_join("caixa_preta")
	if DirAccess.make_dir_recursive_absolute(caminho) == OK or DirAccess.dir_exists_absolute(caminho):
		r.append(caminho)
	return r


## Só na partida do app, na hora (como na 1.24.0).
func _copiar_fora(origem: String, nome: String) -> void:
	if _externas.is_empty() or not FileAccess.file_exists(origem):
		return
	var texto := FileAccess.get_file_as_string(origem)
	for pasta in _externas:
		var f := FileAccess.open(pasta.path_join(nome), FileAccess.WRITE)
		if f != null:
			f.store_string(texto)


## Parou sozinha com a webcam aberta: na segunda vez nesta versão, a foto
## antes da partida é desligada (contorno "camera").
func _caiu_com_a_camera() -> void:
	if "camera" in contornos:
		return
	var quase := FileAccess.get_file_as_string(CAMERA_QUASE).strip_edges() if FileAccess.file_exists(CAMERA_QUASE) else ""
	if quase != VERSAO:
		var q := FileAccess.open(CAMERA_QUASE, FileAccess.WRITE)
		if q != null:
			q.store_string(VERSAO)
		return
	DirAccess.remove_absolute(CAMERA_QUASE)
	contornos.append("camera")
	var f := FileAccess.open(SEGURANCA, FileAccess.WRITE)
	if f != null:
		f.store_string(VERSAO + "|" + "|".join(contornos))


## O que a CONFIGURAÇÃO mostra (scripts/admin.gd, CAIXA-PRETA > VER): como
## a sessão anterior terminou, os contornos desta versão e o começo e o fim
## da última queda guardada (ou da sessão anterior, se não houver queda).
## Para uma foto: a última linha diz onde o jogo estava.
func resumo() -> PackedStringArray:
	var r := PackedStringArray()
	r.append("Lazer Shot %s  |  agora: %s" % [VERSAO, Time.get_datetime_string_from_system(false, true)])
	if _duracao_anterior < 0.0:
		r.append("Sessão anterior: não há registro")
	elif _anterior_caiu:
		r.append("Sessão anterior: PAROU SOZINHA aos %.0f s" % _duracao_anterior)
	else:
		r.append("Sessão anterior: terminou bem (%.0f s)" % _duracao_anterior)
	r.append("Contornando nesta versão: " + (", ".join(contornos) if not contornos.is_empty() else "nada"))
	var arquivo := QUEDA if FileAccess.file_exists(QUEDA) else ANTERIOR
	if not FileAccess.file_exists(arquivo):
		return r
	var linhas := FileAccess.get_file_as_string(arquivo).strip_edges(false, true).split("\n")
	r.append("")
	r.append("%s (%d linhas): começo e fim" % ["ÚLTIMA QUEDA GUARDADA" if arquivo == QUEDA else "SESSÃO ANTERIOR", linhas.size()])
	r.append_array(linhas.slice(0, mini(5, linhas.size())))
	if linhas.size() > 5 + LINHAS_NA_TELA:
		r.append("        ...")
	r.append_array(linhas.slice(maxi(5, linhas.size() - LINHAS_NA_TELA)))
	return r


func _estado() -> String:
	return "%d fps | memória %d MB | texturas %d MB | nós %d | livre no aparelho %d MB" % [Engine.get_frames_per_second(),
		int(OS.get_static_memory_usage()) >> 20,
		int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) >> 20,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(OS.get_memory_info().get("available", 0)) >> 20]


## O app saindo da tela (HOME, outro app) e voltando: se ele for fechado pelo
## Android lá atrás, não foi queda.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		marca("app em segundo plano")
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		marca("app de volta")


## A última notícia da sessão é "app em segundo plano" (sem "app de volta"
## depois)?
static func _em_segundo_plano(linhas: PackedStringArray) -> bool:
	for i in range(linhas.size() - 1, -1, -1):
		if linhas[i].contains("app de volta"):
			return false
		if linhas[i].contains("app em segundo plano"):
			return true
	return false


func _guardar_sessao_anterior() -> void:
	if not FileAccess.file_exists(SESSAO):
		return
	_duracao_anterior = FileAccess.get_file_as_string(VIVO).to_float() if FileAccess.file_exists(VIVO) else 0.0
	var risco_anterior := FileAccess.get_file_as_string(RISCO).strip_edges() if FileAccess.file_exists(RISCO) else ""
	DirAccess.remove_absolute(RISCO)
	var camera_anterior := FileAccess.get_file_as_string(CAMERA).strip_edges() if FileAccess.file_exists(CAMERA) else ""
	DirAccess.remove_absolute(CAMERA)
	DirAccess.remove_absolute(ANTERIOR)
	DirAccess.rename_absolute(SESSAO, ANTERIOR)
	DirAccess.remove_absolute(VIVO)
	var anterior := FileAccess.get_file_as_string(ANTERIOR).strip_edges().split("\n")
	if anterior.is_empty() or anterior[anterior.size() - 1].contains("fechou normalmente"):
		return
	# a sessão anterior parou sozinha: guarda como queda (se foi cedo) e as
	# últimas linhas vão para o registro do Android (adb logcat), antes de a
	# caixa-preta desta sessão começar
	if _duracao_anterior < QUEDA_ATE:
		DirAccess.copy_absolute(ANTERIOR, QUEDA)
	print("CAIXA-PRETA: a sessão anterior parou sozinha aos %.0f s. Últimas linhas:" % _duracao_anterior)
	for l in anterior.slice(maxi(0, anterior.size() - LINHAS_NO_REGISTRO)):
		print("CAIXA-PRETA | ", l)
	if OS.get_name() != "Android" and OS.get_environment("LAZER_CAIXA") != "1":
		return   # no PC o jogo é parado pelo editor a toda hora: não é falha
	if _em_segundo_plano(anterior):
		return   # foi fechado pelo Android lá atrás (HOME, outro app): não é queda
	_anterior_caiu = true
	if camera_anterior == VERSAO:
		_caiu_com_a_camera()
	# morreu dentro de um trecho arriscado desta mesma versão: contorna só ele
	var r := risco_anterior.split("|")
	if r.size() == 2 and r[0] == VERSAO and r[1] != "" and not (r[1] in contornos):
		# primeira queda neste trecho: só anota; na segunda, contorna (os
		# passos da preparação da placa já na primeira)
		var na_hora := r[1].begins_with("desenho:") or r[1].begins_with("shader:") or r[1].begins_with("acerto:") or r[1] in ["som", "arma", "abertura"]
		var quase := FileAccess.get_file_as_string(QUASE).strip_edges() if FileAccess.file_exists(QUASE) else ""
		if quase != risco_anterior and not na_hora:
			var q := FileAccess.open(QUASE, FileAccess.WRITE)
			if q != null:
				q.store_string(risco_anterior)
			return
		if quase == risco_anterior:
			DirAccess.remove_absolute(QUASE)
		contornos.append(r[1])
		var f := FileAccess.open(SEGURANCA, FileAccess.WRITE)
		if f != null:
			f.store_string(VERSAO + "|" + "|".join(contornos))
