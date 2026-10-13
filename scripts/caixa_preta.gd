extends CanvasLayer

## CAIXA-PRETA: o que o jogo estava fazendo quando parou na TV Box.
##
## Grava em user://caixa_preta/ (memória interna do app, sem permissão):
##   sessao.txt    esta sessão: aparelho, placa de vídeo, memória, cada troca
##                 de tela, cada erro do motor ou dos scripts e um pulso a
##                 cada 30 s (fps e memória). Cada linha vai para o disco na
##                 hora, então sobra mesmo se o app fechar de repente.
##   anterior.txt  a sessão de antes.
##   vivo.txt      quanto tempo a sessão está rodando (reescrito a cada 2 s).
##
## Na abertura seguinte, se a sessão de antes parou cedo (menos de 3 min), no
## meio de uma troca de tela ou logo depois de um erro, o relatório dela
## aparece na tela para ser fotografado. START ou um tiro fecha (fecha
## sozinho em 60 s). Se parou nos primeiros segundos, a primeira tela só
## começa depois de fechar o relatório.
##
## Criada pela Tela (o primeiro autoload) no _init, antes de qualquer cena.
## Outros scripts marcam etapas com Tela.marca("texto").

const VERSAO := "1.11.1 (Rodada 11b)"
const PASTA := "user://caixa_preta"
const SESSAO := PASTA + "/sessao.txt"
const ANTERIOR := PASTA + "/anterior.txt"
const VIVO := PASTA + "/vivo.txt"
const MAX_LINHAS := 2500      # depois disso o arquivo recomeça (fica o cabeçalho)
const PAROU_CEDO := 180.0      # s: sessão mais curta que isso parou cedo
const SEGURAR := 25.0          # s: parou tão cedo que a primeira tela espera
const MOSTRAR := 60.0          # s: o relatório fecha sozinho
const LINHAS_NA_TELA := 38
const FONTE := preload("res://fonts/Exo2-Bold.ttf")


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


var _gravador := Gravador.new()
var _registro: Registro
var _anterior: PackedStringArray = []
var _duracao_anterior := -1.0
var _mostrar := false
var _segurar := false
var _cena_segura: Node = null
var _t := 0.0
var _vivo_t := 0.0
var _pulso_t := 0.0
var _cena_id := 0
var _painel: Control = null
var _fechar_t := 0.0


func _init() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(PASTA)
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


func _ready() -> void:
	marca("vídeo: %s | %s | %s | tela %s | janela %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(),
		RenderingServer.get_video_adapter_api_version(), DisplayServer.screen_get_size(), DisplayServer.window_get_size()])
	if _mostrar:
		_montar_relatorio()
		if _segurar:
			# parou nos primeiros segundos: a primeira tela fica parada e
			# escondida até fechar o relatório (ela ainda não desenhou nada)
			_cena_segura = get_tree().current_scene
			if _cena_segura != null:
				_cena_segura.process_mode = Node.PROCESS_MODE_DISABLED
				if _cena_segura is CanvasItem:
					(_cena_segura as CanvasItem).visible = false
				marca("modo seguro: primeira tela segurada até fechar o relatório")


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
	if _painel != null:
		_fechar_t -= delta
		if _fechar_t <= 0.0:
			_fechar_relatorio()


func _input(ev: InputEvent) -> void:
	if _painel == null or _fechar_t > MOSTRAR - 3.0:
		return
	if ev.is_action_pressed("input_start") or ev.is_action_pressed("input_shot") or (ev is InputEventMouseButton and ev.pressed):
		get_viewport().set_input_as_handled()
		_fechar_relatorio()


func _estado() -> String:
	return "%d fps | memória %d MB | texturas %d MB | nós %d" % [Engine.get_frames_per_second(),
		int(OS.get_static_memory_usage()) >> 20,
		int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) >> 20,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]


func _guardar_sessao_anterior() -> void:
	if not FileAccess.file_exists(SESSAO):
		return
	if FileAccess.file_exists(VIVO):
		_duracao_anterior = FileAccess.get_file_as_string(VIVO).to_float()
	DirAccess.remove_absolute(ANTERIOR)
	DirAccess.rename_absolute(SESSAO, ANTERIOR)
	DirAccess.remove_absolute(VIVO)
	_anterior = FileAccess.get_file_as_string(ANTERIOR).strip_edges().split("\n")
	if _anterior.is_empty():
		return
	var ultima := _anterior[_anterior.size() - 1]
	if ultima.contains("fechou normalmente"):
		return
	# erro nos últimos 20 s ou uma troca de tela sem a tela nova aparecer
	var fim := ultima.strip_edges().split(" ", false)[0].to_float() if ultima.strip_edges() != "" else 0.0
	var erro_no_fim := false
	var trocando := false
	for i in range(_anterior.size() - 1, maxi(-1, _anterior.size() - 40), -1):
		var l := _anterior[i]
		var t := l.strip_edges().split(" ", false)[0].to_float() if l.strip_edges() != "" else 0.0
		if fim - t <= 20.0 and l.contains(" ERRO "):
			erro_no_fim = true
		if l.contains("troca para "):
			trocando = true
			break
		if l.contains("TELA "):
			break
	var curta := _duracao_anterior >= 0.0 and _duracao_anterior < PAROU_CEDO
	_mostrar = curta or erro_no_fim or trocando
	_segurar = _duracao_anterior >= 0.0 and _duracao_anterior < SEGURAR


func _montar_relatorio() -> void:
	_painel = Control.new()
	_painel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_painel)
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.02, 0.04, 0.95)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(fundo)

	var titulo := _texto("DIAGNÓSTICO: O JOGO PAROU AQUI DA ÚLTIMA VEZ", 34, Color(1.0, 0.82, 0.25))
	titulo.offset_top = 30
	titulo.offset_bottom = 78
	var sub := _texto("Fotografe esta tela inteira e mande. A sessão anterior durou %s.\nSTART ou um tiro fecha (fecha sozinho em %d s)." % [
		("%.0f s" % _duracao_anterior) if _duracao_anterior >= 0.0 else "?", int(MOSTRAR)], 22, Color(0.85, 0.88, 0.95))
	sub.offset_top = 86
	sub.offset_bottom = 150

	# cabeçalho (aparelho, vídeo, memória) + as últimas linhas
	var linhas: PackedStringArray = []
	for i in mini(5, _anterior.size()):
		linhas.append(_anterior[i])
	var resto := _anterior.slice(maxi(5, _anterior.size() - LINHAS_NA_TELA))
	if _anterior.size() - 5 > resto.size():
		linhas.append("   ...")
	linhas.append_array(resto)
	var texto := RichTextLabel.new()
	texto.bbcode_enabled = true
	texto.scroll_active = false
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texto.add_theme_font_override("normal_font", FONTE)
	texto.add_theme_font_size_override("normal_font_size", 22)
	texto.set_anchors_preset(Control.PRESET_FULL_RECT)
	texto.offset_left = 26
	texto.offset_right = -26
	texto.offset_top = 166
	texto.offset_bottom = -24
	var bb := ""
	for l in linhas:
		var seguro := l.replace("[", "(").replace("]", ")")
		if seguro.length() > 150:
			seguro = seguro.substr(0, 150) + "..."
		var cor := "#d8dce6"
		if l.contains(" ERRO "):
			cor = "#ff6a5a"
		elif l.contains(" AVISO "):
			cor = "#ffc94d"
		elif l.contains("TELA ") or l.contains("troca para "):
			cor = "#7fd7ff"
		bb += "[color=%s]%s[/color]\n" % [cor, seguro]
	texto.text = bb
	_painel.add_child(texto)
	_fechar_t = MOSTRAR
	marca("relatório da sessão anterior mostrado na tela")


## Linha de texto centralizada, da largura da tela.
func _texto(txt: String, tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", FONTE)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.anchor_right = 1.0
	l.offset_left = 20
	l.offset_right = -20
	_painel.add_child(l)
	return l


func _fechar_relatorio() -> void:
	if _painel == null:
		return
	_painel.queue_free()
	_painel = null
	marca("relatório fechado")
	if _cena_segura != null and is_instance_valid(_cena_segura):
		_cena_segura.process_mode = Node.PROCESS_MODE_INHERIT
		if _cena_segura is CanvasItem:
			(_cena_segura as CanvasItem).visible = true
	_cena_segura = null
