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
##   vivo.txt      quanto tempo a sessão está rodando (reescrito a cada 2 s).
## Na abertura seguinte, as últimas linhas da sessão anterior também saem no
## registro do Android (GERAR_APK_PRO_ULTRA.bat -Registro as puxa pelo adb).
##
## MODO DE SEGURANÇA (só na TV Box): se o jogo fechou sozinho com menos de
## 90 s, as próximas aberturas desta versão pulam a abertura Lazer & Sport e
## não tocam vídeo nenhum (os menus ficam com o fundo animado). Assim o jogo
## roda mesmo que o problema esteja num desses dois. Instalar uma versão nova
## volta ao normal.
##
## Criada pela Tela (o primeiro autoload) no _init, antes de qualquer cena.
## Outros scripts marcam etapas com Tela.marca("texto").

const VERSAO := "1.11.2"
const PASTA := "user://caixa_preta"
const SESSAO := PASTA + "/sessao.txt"
const ANTERIOR := PASTA + "/anterior.txt"
const VIVO := PASTA + "/vivo.txt"
const SEGURANCA := PASTA + "/modo_seguranca.txt"   # guarda a versão em que ligou
const CEDO_SEGURANCA := 90.0   # s: fechou antes disso -> modo de segurança
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


## true: sem abertura e sem vídeos nesta sessão (ver o começo do arquivo)
var modo_seguro := false

var _gravador := Gravador.new()
var _registro: Registro
var _duracao_anterior := -1.0
var _t := 0.0
var _vivo_t := 0.0
var _pulso_t := 0.0
var _cena_id := 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(PASTA)
	_guardar_sessao_anterior()
	if FileAccess.file_exists(SEGURANCA):
		modo_seguro = FileAccess.get_file_as_string(SEGURANCA).strip_edges() == VERSAO
		if not modo_seguro:
			DirAccess.remove_absolute(SEGURANCA)   # versão nova: volta ao normal
	_gravador.arq = FileAccess.open(SESSAO, FileAccess.WRITE)
	_registro = Registro.new(_gravador)
	OS.add_logger(_registro)
	marca("LAZER SHOT %s  |  %s" % [VERSAO, Time.get_datetime_string_from_system(false, true)])
	var mem := OS.get_memory_info()
	marca("aparelho: %s | %s %s | CPU %s x%d" % [OS.get_model_name(), OS.get_name(), OS.get_version(), OS.get_processor_name(), OS.get_processor_count()])
	marca("memória: total %d MB, livre %d MB" % [int(mem.get("physical", 0)) >> 20, int(mem.get("available", 0)) >> 20])
	if _duracao_anterior >= 0.0:
		marca("sessão anterior durou %.0f s" % _duracao_anterior)
	if modo_seguro:
		marca("MODO DE SEGURANÇA: sem abertura e sem vídeos (o jogo fechou cedo nesta versão)")


func _ready() -> void:
	marca("vídeo: %s | %s | %s | tela %s | janela %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(),
		RenderingServer.get_video_adapter_api_version(), DisplayServer.screen_get_size(), DisplayServer.window_get_size()])
	var primeira := get_tree().current_scene
	if modo_seguro and primeira != null and primeira.scene_file_path != CENA_MENU:
		# pula a abertura: ela fica parada e escondida (ainda não desenhou
		# nada) e o jogo vai direto para o menu
		primeira.process_mode = Node.PROCESS_MODE_DISABLED
		if primeira is CanvasItem:
			(primeira as CanvasItem).visible = false
		_ir_para_menu.call_deferred()


func _ir_para_menu() -> void:
	marca("modo de segurança: pulando a abertura")
	TransicaoGlobal.trocar_cena(CENA_MENU, 0.0, 0.3)


func _exit_tree() -> void:
	marca("fim da sessão (o jogo fechou normalmente)")
	OS.remove_logger(_registro)


## Uma linha na caixa-preta (qualquer script: Tela.marca("...")).
func marca(txt: String) -> void:
	_gravador.escrever(txt)


func _process(delta: float) -> void:
	_t += delta
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


func _estado() -> String:
	return "%d fps | memória %d MB | texturas %d MB | nós %d" % [Engine.get_frames_per_second(),
		int(OS.get_static_memory_usage()) >> 20,
		int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) >> 20,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]


func _guardar_sessao_anterior() -> void:
	if not FileAccess.file_exists(SESSAO):
		return
	_duracao_anterior = FileAccess.get_file_as_string(VIVO).to_float() if FileAccess.file_exists(VIVO) else 0.0
	DirAccess.remove_absolute(ANTERIOR)
	DirAccess.rename_absolute(SESSAO, ANTERIOR)
	DirAccess.remove_absolute(VIVO)
	var anterior := FileAccess.get_file_as_string(ANTERIOR).strip_edges().split("\n")
	if anterior.is_empty() or anterior[anterior.size() - 1].contains("fechou normalmente"):
		return
	# a sessão anterior parou sozinha: as últimas linhas vão para o registro do
	# Android (adb logcat), antes de a caixa-preta desta sessão começar
	print("CAIXA-PRETA: a sessão anterior parou sozinha aos %.0f s. Últimas linhas:" % _duracao_anterior)
	for l in anterior.slice(maxi(0, anterior.size() - LINHAS_NO_REGISTRO)):
		print("CAIXA-PRETA | ", l)
	if OS.get_name() != "Android" and OS.get_environment("LAZER_CAIXA") != "1":
		return   # no PC o jogo é parado pelo editor a toda hora: não é falha
	if _duracao_anterior < CEDO_SEGURANCA:
		var f := FileAccess.open(SEGURANCA, FileAccess.WRITE)
		if f != null:
			f.store_string(VERSAO)
