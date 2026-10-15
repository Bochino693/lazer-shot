extends Node

## CAIXA-PRETA: o que o jogo estava fazendo quando parou na TV Box. Não
## mostra nada na tela; só grava.
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
## Na abertura seguinte, as últimas linhas da sessão anterior também saem no
## registro do Android (GERAR_APK_PRO_ULTRA.bat -Registro as puxa pelo adb).
## Na TV Box, uma cópia fica também na pasta do app que o gerenciador de
## arquivos enxerga (Android/data/com.lazersport.lazershot/files/caixa_preta)
## e, com um pendrive espetado, no próprio pendrive (a mesma pasta
## Android/data/... dentro dele): é só levar o pendrive ao PC. A cópia
## começa no passo "pasta" da preparação (scripts/aquecedor.gd).
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
##   "pasta"            sem cópia da caixa-preta fora do app
## (scripts/contorno_desenho.gd aplica). Todo o resto continua igual.
## Instalar uma versão nova zera tudo.
##
## Criada pela Tela (o primeiro autoload) no _init, antes de qualquer cena.
## Outros scripts marcam etapas com Tela.marca("texto").

const VERSAO := "1.26.0"
const PASTA := "user://caixa_preta"
const SESSAO := PASTA + "/sessao.txt"
const ANTERIOR := PASTA + "/anterior.txt"
const VIVO := PASTA + "/vivo.txt"
const SEGURANCA := PASTA + "/contornos.txt"   # "versão|trecho|trecho..."
const QUASE := PASTA + "/quase.txt"           # "versão|trecho" da 1ª queda num trecho
const RISCO := PASTA + "/risco.txt"           # "versão|trecho" enquanto está nele
const QUEDA := PASTA + "/queda.txt"
const QUEDA_ATE := 600.0       # s: parou sozinha antes disso = provável queda
const CENA_MENU := "res://scenes/main.tscn"
const MAX_LINHAS := 2500      # depois disso o arquivo recomeça (fica o cabeçalho)
const LINHAS_NO_REGISTRO := 40


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
		if rationale.begins_with("Nodes with non-equal opposite anchors"):
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

var _gravador := Gravador.new()
var _registro: Registro
var _duracao_anterior := -1.0
var _t := 0.0
var _vivo_t := 0.0
var _pulso_t := 0.0
var _cena_id := 0
var _externas: Array[String] = []   # pastas visíveis fora do app (interna e pendrive)
var _conferir := 0     # quadros que faltam para anotar o "ok" de marca_quadro
var _conferir_txt := ""


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
	marca("vídeo: %s | %s | %s | tela %s | janela %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(),
		RenderingServer.get_video_adapter_api_version(), DisplayServer.screen_get_size(), DisplayServer.window_get_size()])
	var primeira := get_tree().current_scene
	if contorna("abertura") and primeira != null and primeira.scene_file_path != CENA_MENU:
		# a apresentação já derrubou o app nesta versão: ela fica parada e
		# escondida (ainda não desenhou nada) e o jogo vai direto para o menu
		primeira.process_mode = Node.PROCESS_MODE_DISABLED
		if primeira is CanvasItem:
			(primeira as CanvasItem).visible = false
		_ir_para_menu.call_deferred()


func _ir_para_menu() -> void:
	marca("contorno: pulando a apresentação")
	TransicaoGlobal.trocar_cena(CENA_MENU, 0.0, 0.3)


## Este trecho já derrubou o app nesta versão?
func contorna(trecho: String) -> bool:
	return trecho in contornos


func risco_atual() -> String:
	return _risco


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
			_copiar_fora(SESSAO, "sessao.txt")
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
		_copiar_fora(SESSAO, "sessao.txt")


## Passo "pasta" da preparação: acha as pastas do app que ficam visíveis
## fora dele (sem permissão nenhuma) e copia a caixa-preta para elas.
func abrir_pasta_externa() -> void:
	if not _externas.is_empty():
		return
	for p in _pastas_externas():
		var caminho := p.path_join("caixa_preta")
		if DirAccess.make_dir_recursive_absolute(caminho) == OK or DirAccess.dir_exists_absolute(caminho):
			_externas.append(caminho)
			marca("cópia da caixa-preta em " + caminho)
	_copiar_fora(ANTERIOR, "anterior.txt")
	_copiar_fora(QUEDA, "queda.txt")
	_copiar_fora(SESSAO, "sessao.txt")


## Android/data/<app>/files na memória da TV Box e em cada pendrive/cartão.
func _pastas_externas() -> Array[String]:
	var r: Array[String] = []
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return r
	var rt = Engine.get_singleton("AndroidRuntime")
	var ctx = rt.getApplicationContext() if rt != null else null
	if ctx == null:
		return r
	var dir = ctx.getExternalFilesDir(null)
	if dir != null:
		r.append(str(dir.getAbsolutePath()))
	# o Android cria a pasta do app em cada volume (pendrive) ao pedir a lista
	var todas = ctx.getExternalFilesDirs(null)
	if todas is Array:
		for d in todas:
			if d != null:
				var c := str(d.getAbsolutePath())
				if not (c in r):
					r.append(c)
	# e, se a lista não vier, procura os volumes montados em /storage
	var pacote := "com.lazersport.lazershot"
	var vols := DirAccess.open("/storage")
	if vols != null:
		for v in vols.get_directories():
			if v == "emulated" or v == "self":
				continue
			var c := "/storage/%s/Android/data/%s/files" % [v, pacote]
			if DirAccess.dir_exists_absolute(c) and not (c in r):
				r.append(c)
	return r


func _copiar_fora(origem: String, nome: String) -> void:
	if _externas.is_empty() or not FileAccess.file_exists(origem):
		return
	var texto := FileAccess.get_file_as_string(origem)
	for pasta in _externas:
		var f := FileAccess.open(pasta.path_join(nome), FileAccess.WRITE)
		if f != null:
			f.store_string(texto)


func _estado() -> String:
	return "%d fps | memória %d MB | texturas %d MB | nós %d" % [Engine.get_frames_per_second(),
		int(OS.get_static_memory_usage()) >> 20,
		int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) >> 20,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]


func _guardar_sessao_anterior() -> void:
	if not FileAccess.file_exists(SESSAO):
		return
	_duracao_anterior = FileAccess.get_file_as_string(VIVO).to_float() if FileAccess.file_exists(VIVO) else 0.0
	var risco_anterior := FileAccess.get_file_as_string(RISCO).strip_edges() if FileAccess.file_exists(RISCO) else ""
	DirAccess.remove_absolute(RISCO)
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
	# morreu dentro de um trecho arriscado desta mesma versão: contorna só ele
	var r := risco_anterior.split("|")
	if r.size() == 2 and r[0] == VERSAO and r[1] != "" and not (r[1] in contornos):
		# primeira queda neste trecho: só anota; na segunda, contorna (os
		# passos da preparação da placa já na primeira)
		var na_hora := r[1].begins_with("desenho:") or r[1].begins_with("shader:") or r[1] in ["som", "arma", "pasta", "abertura"]
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
