extends Node2D

## CONFIGURAÇÕES DA MÁQUINA (abre com F10 ou segurando o SELECT 3 s nas
## telas de abertura). Feita para a arma: aponte e atire nos botões (ou use
## as setas e ENTER). Tudo é guardado pela Maquina em user://config_admin.cfg
## (as mesmas chaves da versão 4.6). É a ÚNICA tela com informação técnica
## (desempenho e caixa-preta): nada disso aparece no jogo.

const CENA_SAIDA = "res://scenes/menu.tscn"
const COR_FUNDO = Color(0.035, 0.045, 0.075)
const COR_CARTAO = Color(0.075, 0.095, 0.15)
const COR_BOTAO = Color(0.13, 0.16, 0.24)
const COR_DESTAQUE = Color(1.0, 0.27, 0.2)
const COR_OK = Color(0.2, 0.82, 0.45)
const COR_TEXTO = Color(0.93, 0.95, 1.0)
const COR_APAGADO = Color(0.6, 0.66, 0.78)
const X0 = 28.0
const LARG = 968.0
const ALT_LINHA = 56.0
const ALT_BOTAO = 44.0
const Y_BOTAO = 6.0          # (ALT_LINHA - ALT_BOTAO) / 2

var _raiz: Control
var _y = 0.0
var _botoes = []            # {no, rotulo, acao, args, cor, ligado (funcref ou null)}
var _foco = 0
var _atualizadores = []     # [objeto, método, argumentos]
var _rotulos_botao = {}
var _aprendendo = ""
var _aprender_t = 0.0
var _aprender_desde = 0
var _confirmar = {}
var _aviso: Label
var _contadores: Label
var _ultimo: Label
var _desempenho: Label
var _painel_caixa: Control
var _mira: MiraDesenho
var _saindo = false
var _t = 0.0


func _ready() -> void:
	MiraGlobal.ativa = true
	var fundo = ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.rect_size = Tela.TELA
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var camada = CanvasLayer.new()
	camada.layer = 10
	add_child(camada)
	_raiz = Control.new()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.rect_size = Tela.TELA
	camada.add_child(_raiz)
	_montar()
	_mira = MiraDesenho.criar(self, COR_DESTAQUE)
	_atualizar_tudo()
	_pintar_foco()


# ================================================================ montagem
func _montar() -> void:
	var faixa = ColorRect.new()
	faixa.color = COR_DESTAQUE
	faixa.rect_size = Vector2(Tela.TELA.x, 6)
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(faixa)
	var titulo = Estilo.rotulo(_raiz, "CONFIGURAÇÕES", 48, COR_TEXTO, 0, true, Label.ALIGN_LEFT)
	Estilo.colocar(titulo, Vector2(X0, 18), Vector2(560, 60))
	var sub = Estilo.rotulo(_raiz, "LAZER SHOT %s  ·  aponte e atire nos botões" % Tela.VERSAO, 20, COR_APAGADO, 0, false, Label.ALIGN_LEFT)
	Estilo.colocar(sub, Vector2(X0, 76), Vector2(600, 28))
	_contadores = Estilo.rotulo(_raiz, "", 20, COR_APAGADO, 0, false, Label.ALIGN_RIGHT)
	Estilo.colocar(_contadores, Vector2(X0 + LARG - 420, 22), Vector2(420, 28))
	_botao("ZERAR CONTADORES", Vector2(X0 + LARG - 260, 56), Vector2(260, 46), 18, "_confirmado", ["contadores"])
	_y = 108.0

	_secao("MÁQUINA")
	_opcoes("Modo de jogo", "livre: START sem cobrar  ·  crédito: ficha pelo SELECT", "maquina/modo", [["livre", "LIVRE"], ["credito", "CRÉDITO"]])
	_passos("Créditos por partida", "", "maquina/creditos_por_partida", 1, 10, 1, "%d")
	_passos("Créditos na máquina", "", "maquina/creditos", 0, 99, 1, "%02d", 120.0)
	_botao("ZERAR", Vector2(X0 + LARG - 120, _y - ALT_LINHA - 4 + Y_BOTAO), Vector2(108, ALT_BOTAO), 20, "_zerar_creditos", [])

	_secao("PARTIDA")
	_passos("Tempo de partida", "", "jogo/tempo_partida", 30, 600, 10, "tempo")
	_passos("Tela de resultado", "volta sozinha depois de", "jogo/tempo_modal_final", 5, 120, 1, "%d s")
	_passos("Nome no ranking", "tempo para digitar", "ranking/tempo_nome", 10, 120, 5, "%d s")

	_secao("ABERTURA")
	_passos("Tempo da abertura", "parada até a demonstração", "main/tempo_intro", 10, 300, 5, "%d s")
	_passos("Tempo da demonstração", "os 4 cenários passando", "main/tempo_teaser", 5, 120, 5, "%d s")
	_opcoes("Demonstração", "", "main/demo_ativa", [[true, "LIGADA"], [false, "DESLIGADA"]])
	_opcoes("Ranking na abertura", "", "ranking/ranking_ativo", [[true, "LIGADO"], [false, "DESLIGADO"]])

	_secao("VÍDEO")
	_opcoes("Efeitos", "leve: menos partículas, para a TV Box mais fraca", "video/efeitos", [["completo", "COMPLETO"], ["leve", "LEVE"]])
	_opcoes("Giro da tela", "imagem de cabeça para baixo: troque o lado", "tela/giro", [["auto", "AUTO"], [1, "ESQUERDA"], [-1, "DIREITA"], [0, "EM PÉ"]])

	_secao("SOM")
	_volume("Música", "audio/volume_musica")
	_volume("Efeitos", "audio/volume_fx")

	_secao("BOTÕES")
	_aprender("START na arma", "botão do lado direito, perto do bico", "start_arma")
	_aprender("RECARGA na arma", "botão do lado direito, perto do gatilho", "recarga_arma")
	_aprender("START na Zero Delay", "", "start")
	_aprender("SELECT na Zero Delay", "ficha / crédito", "select")
	_ultimo = Estilo.rotulo(_raiz, "Último botão recebido: —", 18, COR_APAGADO, 0, false)
	Estilo.colocar(_ultimo, Vector2(X0, _y), Vector2(LARG, 26))
	_y += 30.0

	_secao("RANKING")
	_linha("Limpar o ranking", "apaga os 20 melhores (atire duas vezes)")
	_botao("LIMPAR", Vector2(X0 + LARG - 190, _y - ALT_LINHA - 4 + Y_BOTAO), Vector2(178, ALT_BOTAO), 22, "_confirmado", ["ranking"])

	_secao("CAIXA-PRETA")
	_linha("Última sessão", Tela.resumo_sessao_anterior())
	_botao("VER", Vector2(X0 + LARG - 170, _y - ALT_LINHA - 4 + Y_BOTAO), Vector2(158, ALT_BOTAO), 24, "_ver_caixa", [])
	_desempenho = Estilo.rotulo(_raiz, "", 18, COR_APAGADO, 0, false)
	Estilo.colocar(_desempenho, Vector2(X0, _y), Vector2(LARG, 26))

	# rodapé
	var yr = Tela.TELA.y - 128.0
	_aviso = Estilo.rotulo(_raiz, "", 22, COR_APAGADO, 0, false)
	Estilo.colocar(_aviso, Vector2(X0, yr - 40), Vector2(LARG, 32))
	_botao("SALVAR E SAIR", Vector2(X0, yr), Vector2(520, 70), 28, "_salvar_e_sair", [], COR_OK)
	_botao("SAIR SEM SALVAR", Vector2(X0 + 534, yr), Vector2(260, 70), 22, "_sair_sem_salvar", [])
	_botao("PADRÃO", Vector2(X0 + 808, yr), Vector2(160, 70), 22, "_confirmado", ["padrao"])
	var dica = Estilo.rotulo(_raiz, "F10 ou segure o SELECT 3 s na abertura para voltar aqui", 17, Color(COR_APAGADO.r, COR_APAGADO.g, COR_APAGADO.b, 0.7), 0, false)
	Estilo.colocar(dica, Vector2(X0, yr + 80), Vector2(LARG, 26))


func _secao(texto: String) -> void:
	_y += 4.0
	var r = Estilo.rotulo(_raiz, texto, 19, COR_DESTAQUE, 0, true, Label.ALIGN_LEFT)
	Estilo.colocar(r, Vector2(X0 + 4, _y), Vector2(LARG, 22))
	_y += 24.0


## Cartão de uma linha: título (e dica) à esquerda; os controles à direita
## são postos por quem chama (o cartão ocupa _y .. _y + ALT_LINHA).
func _linha(titulo: String, dica: String) -> void:
	Estilo.painel(_raiz, Vector2(X0, _y), Vector2(LARG, ALT_LINHA), Estilo.caixa(COR_CARTAO, Color(0, 0, 0, 0), 0, 14))
	var t = Estilo.rotulo(_raiz, titulo, 24, COR_TEXTO, 0, false, Label.ALIGN_LEFT)
	Estilo.colocar(t, Vector2(X0 + 20, _y + (2 if dica != "" else 0)), Vector2(520, 32 if dica != "" else ALT_LINHA))
	if dica != "":
		var d = Estilo.rotulo(_raiz, dica, 15, COR_APAGADO, 0, false, Label.ALIGN_LEFT)
		d.clip_text = true
		Estilo.colocar(d, Vector2(X0 + 20, _y + 32), Vector2(560, 22))
	_y += ALT_LINHA + 4.0


func _passos(titulo: String, dica: String, chave: String, minimo: int, maximo: int, passo: int, formato: String, recuo: float = 0.0) -> void:
	var y = _y
	_linha(titulo, dica)
	var xd = X0 + LARG - 12.0 - recuo
	_botao("+", Vector2(xd - 74, y + Y_BOTAO), Vector2(74, ALT_BOTAO), 34, "_mudar", [chave, passo, minimo, maximo])
	var valor = Estilo.rotulo(_raiz, "", 30, COR_TEXTO, 0, true)
	Estilo.colocar(valor, Vector2(xd - 74 - 130, y), Vector2(130, ALT_LINHA))
	_botao("−", Vector2(xd - 74 - 130 - 74, y + Y_BOTAO), Vector2(74, ALT_BOTAO), 34, "_mudar", [chave, -passo, minimo, maximo])
	_atualizadores.append([self, "_mostrar_passo", [valor, chave, formato]])


func _mostrar_passo(valor: Label, chave: String, formato: String) -> void:
	var v = int(Maquina.valor(chave))
	valor.text = ("%d:%02d" % [v / 60, v % 60]) if formato == "tempo" else (formato % v)


func _mudar(chave: String, d: int, minimo: int, maximo: int) -> void:
	Maquina.definir(chave, int(clamp(int(Maquina.valor(chave)) + d, minimo, maximo)))
	_atualizar_tudo()


func _opcoes(titulo: String, dica: String, chave: String, lista: Array) -> void:
	var y = _y
	_linha(titulo, dica)
	var larg = 170.0 if lista.size() <= 2 else 116.0
	var x = X0 + LARG - 12.0 - lista.size() * (larg + 8.0) + 8.0
	for par in lista:
		var b = _botao(par[1], Vector2(x, y + Y_BOTAO), Vector2(larg, ALT_BOTAO), 22 if larg > 120 else 19, "_escolher", [chave, par[0]])
		b["ligado"] = [chave, par[0]]
		x += larg + 8.0


func _escolher(chave: String, v) -> void:
	Maquina.definir(chave, v)
	if chave == "audio/volume_musica" or chave == "audio/volume_fx" or chave.begins_with("botoes/"):
		Maquina.aplicar()
	if chave == "tela/giro":
		Tela.definir_giro(v)
	_atualizar_tudo()


func _volume(titulo: String, chave: String) -> void:
	var y = _y
	_linha(titulo, "")
	var xd = X0 + LARG - 12.0
	_botao("+", Vector2(xd - 74, y + Y_BOTAO), Vector2(74, ALT_BOTAO), 34, "_mudar_volume", [chave, 10])
	var valor = Estilo.rotulo(_raiz, "", 30, COR_TEXTO, 0, true)
	Estilo.colocar(valor, Vector2(xd - 74 - 130, y), Vector2(130, ALT_LINHA))
	_botao("−", Vector2(xd - 74 - 130 - 74, y + Y_BOTAO), Vector2(74, ALT_BOTAO), 34, "_mudar_volume", [chave, -10])
	_atualizadores.append([self, "_mostrar_volume", [valor, chave]])


func _mostrar_volume(valor: Label, chave: String) -> void:
	valor.text = "%d%%" % _db_para_pct(float(Maquina.valor(chave)))


func _mudar_volume(chave: String, d: int) -> void:
	var p = int(clamp(_db_para_pct(float(Maquina.valor(chave))) + d, 0, 100))
	Maquina.definir(chave, _pct_para_db(p))
	Maquina.aplicar()
	_atualizar_tudo()


func _aprender(titulo: String, dica: String, qual: String) -> void:
	var y = _y
	_linha(titulo, dica)
	_botao("APRENDER", Vector2(X0 + LARG - 12 - 190, y + Y_BOTAO), Vector2(190, ALT_BOTAO), 22, "_comecar_aprender", [qual])
	var valor = Estilo.rotulo(_raiz, "", 24, COR_TEXTO, 0, true)
	Estilo.colocar(valor, Vector2(X0 + LARG - 12 - 190 - 260, y), Vector2(250, ALT_LINHA))
	_rotulos_botao[qual] = valor
	_atualizadores.append([self, "_mostrar_botao", [valor, qual]])


func _mostrar_botao(valor: Label, qual: String) -> void:
	if _aprendendo == qual:
		return
	if qual.ends_with("_arma"):
		valor.text = Maquina.nome_do_descritor(str(Maquina.valor("botoes/" + qual)))
	else:
		valor.text = "BOTÃO %d" % int(Maquina.valor("botoes/" + qual))


func _comecar_aprender(qual: String) -> void:
	_aprendendo = qual
	_aprender_t = 8.0
	_aprender_desde = OS.get_ticks_msec()
	_mostrar_aviso("Aperte agora o botão na %s..." % ("arma" if qual.ends_with("_arma") else "Zero Delay"), COR_DESTAQUE)


## Um botão: painel com rótulo; o tiro em cima chama `acao(args)`.
func _botao(texto: String, pos: Vector2, tam: Vector2, fonte: int, acao: String, args: Array, cor: Color = COR_BOTAO) -> Dictionary:
	var p = Estilo.painel(_raiz, pos, tam, _estilo(cor))
	p.rect_pivot_offset = tam * 0.5
	var r = Estilo.rotulo(p, texto, fonte, COR_TEXTO, 0, true)
	Estilo.colocar(r, Vector2.ZERO, tam)
	var b = {"no": p, "rotulo": r, "acao": acao, "args": args, "cor": cor, "ligado": null}
	_botoes.append(b)
	return b


func _estilo(cor: Color, borda: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	return Estilo.caixa(cor, borda, 3 if borda.a > 0.0 else 0, 12)


func _pintar_botao(i: int) -> void:
	var b: Dictionary = _botoes[i]
	var cor: Color = b["cor"]
	if b["ligado"] != null and _igual(Maquina.valor(b["ligado"][0]), b["ligado"][1]):
		cor = COR_DESTAQUE
	var foco = i == _foco
	b["no"].add_stylebox_override("panel", _estilo(cor.lightened(0.12) if foco else cor, Color(1, 1, 1, 0.85) if foco else Color(0, 0, 0, 0)))


## Igual e do mesmo tipo (no Godot 3 comparar texto com número é erro).
static func _igual(a, b) -> bool:
	if typeof(a) != typeof(b):
		if typeof(a) in [TYPE_INT, TYPE_REAL] and typeof(b) in [TYPE_INT, TYPE_REAL]:
			return int(a) == int(b)
		return false
	return a == b


func _pintar_foco() -> void:
	for i in _botoes.size():
		_pintar_botao(i)


func _apertar(i: int) -> void:
	if i < 0 or i >= _botoes.size():
		return
	var b: Dictionary = _botoes[i]
	var no: Panel = b["no"]
	no.rect_scale = Vector2(0.92, 0.92)
	var tw = create_tween()
	tw.tween_property(no, "rect_scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	callv(b["acao"], b["args"])
	_pintar_foco()


# ================================================================ estado
func _atualizar_tudo() -> void:
	for a in _atualizadores:
		a[0].callv(a[1], a[2])
	_contadores.text = "FICHAS %04d   ·   PARTIDAS %04d" % [int(Maquina.valor("maquina/total_fichas")), int(Maquina.valor("maquina/total_partidas"))]
	_pintar_foco()


func _mostrar_aviso(texto: String, cor: Color) -> void:
	_aviso.text = texto
	_aviso.add_color_override("font_color", cor)


func _zerar_creditos() -> void:
	Maquina.definir("maquina/creditos", 0)
	_atualizar_tudo()


## Ações perigosas pedem um segundo tiro em até 3 s.
func _confirmado(nome: String) -> void:
	var agora = OS.get_ticks_msec()
	if _confirmar.get(nome, 0) <= agora:
		_confirmar[nome] = agora + 3000
		_mostrar_aviso("Atire de novo para confirmar", COR_DESTAQUE)
		return
	_confirmar.erase(nome)
	match nome:
		"contadores":
			Maquina.definir("maquina/total_fichas", 0)
			Maquina.definir("maquina/total_partidas", 0)
			_mostrar_aviso("Contadores zerados (salve para valer)", COR_TEXTO)
		"ranking":
			RankingManager.limpar()
			_mostrar_aviso("Ranking limpo", COR_OK)
		"padrao":
			Maquina.restaurar_padrao()
			Tela.definir_giro(Maquina.valor("tela/giro"))
			_mostrar_aviso("Valores de fábrica (salve para valer)", COR_TEXTO)
	_atualizar_tudo()


func _salvar_e_sair() -> void:
	if _saindo:
		return
	_saindo = true
	Maquina.salvar()
	Maquina.aplicar()
	_mostrar_aviso("Configurações salvas!", COR_OK)
	TransicaoGlobal.trocar_cena(CENA_SAIDA)


func _sair_sem_salvar() -> void:
	if _saindo:
		return
	_saindo = true
	Maquina.cfg = ConfigFile.new()
	Maquina.cfg.load(Maquina.CONFIG)
	Maquina.aplicar()
	Tela.definir_giro(Maquina.valor("tela/giro"))
	TransicaoGlobal.trocar_cena(CENA_SAIDA)


static func _db_para_pct(db: float) -> int:
	if db <= -60.0:
		return 0
	return int(clamp(int(round(db2linear(db) * 10.0)) * 10, 0, 100))


static func _pct_para_db(p: int) -> float:
	if p <= 0:
		return -80.0
	return linear2db(float(p) / 100.0)


# ================================================================ caixa-preta
## A caixa-preta por cima da configuração: como a sessão anterior terminou e
## as últimas marcas (onde o jogo estava). Para uma foto quando o jogo fechar
## sozinho na TV Box.
func _ver_caixa() -> void:
	if _painel_caixa != null:
		return
	var camada = CanvasLayer.new()
	camada.layer = 20
	add_child(camada)
	_painel_caixa = Control.new()
	_painel_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel_caixa.rect_size = Tela.TELA
	camada.add_child(_painel_caixa)
	var fundo = ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.rect_size = Tela.TELA
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel_caixa.add_child(fundo)
	var titulo = Estilo.rotulo(_painel_caixa, "CAIXA-PRETA", 46, COR_TEXTO, 0, true, Label.ALIGN_LEFT)
	Estilo.colocar(titulo, Vector2(X0, 22), Vector2(600, 60))
	var dica = Estilo.rotulo(_painel_caixa, "Tire uma foto desta tela e mande para o suporte: a última linha diz onde o jogo estava.", 19, COR_APAGADO, 0, false, Label.ALIGN_LEFT)
	dica.autowrap = true
	Estilo.colocar(dica, Vector2(X0, 96), Vector2(LARG, 56))
	var linhas = PoolStringArray([Tela.resumo_sessao_anterior(), ""])
	linhas.append_array(Tela.marcas_sessao_anterior())
	var texto = Estilo.rotulo(_painel_caixa, linhas.join("\n"), 17, COR_TEXTO, 0, false, Label.ALIGN_LEFT)
	texto.valign = Label.VALIGN_TOP
	texto.autowrap = true
	texto.clip_text = true
	Estilo.colocar(texto, Vector2(X0, 160), Vector2(LARG, Tela.TELA.y - 160 - 140))
	var b = Estilo.painel(_painel_caixa, Vector2(X0 + LARG - 220, Tela.TELA.y - 110), Vector2(220, 70), _estilo(COR_OK))
	var r = Estilo.rotulo(b, "FECHAR", 26, COR_TEXTO, 0, true)
	Estilo.colocar(r, Vector2.ZERO, b.rect_size)
	_painel_caixa.set_meta("fechar", b)


func _fechar_caixa() -> void:
	if _painel_caixa == null:
		return
	_painel_caixa.get_parent().queue_free()
	_painel_caixa = null


# ================================================================ entrada
func _notification(what: int) -> void:
	# VOLTAR do Android (o botão da arma perto do gatilho costuma ser este)
	if what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
		_mostrar_ultimo("VOLTAR (ANDROID)")
		if _aprendendo.ends_with("_arma"):
			_gravar_arma("voltar")


func _mostrar_ultimo(nome: String) -> void:
	_ultimo.text = "Último botão recebido: " + nome


func _gravar_arma(descritor: String) -> void:
	var qual = _aprendendo
	var outro = "botoes/recarga_arma" if qual == "start_arma" else "botoes/start_arma"
	# o mesmo botão não pode ser START e RECARGA
	if str(Maquina.valor(outro)) == descritor:
		Maquina.definir(outro, "padrao" if outro == "botoes/recarga_arma" else "")
	Maquina.definir("botoes/" + qual, descritor)
	Maquina.aplicar()
	_mostrar_aviso("%s = %s  (salve para valer sempre)" % ["START na arma" if qual == "start_arma" else "RECARGA na arma", Maquina.nome_do_descritor(descritor)], COR_OK)
	_aprendendo = ""
	_atualizar_tudo()


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		_mostrar_ultimo(Maquina.nome_do_descritor(Maquina.descrever(ev)))
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		_mostrar_ultimo(Maquina.nome_do_descritor(Maquina.descrever(ev)))
	elif ev is InputEventJoypadButton and ev.pressed:
		_mostrar_ultimo("ZERO DELAY " + Maquina.nome_do_descritor(Maquina.descrever(ev)))
	if _saindo:
		return
	# aprendendo um botão da arma: clique (menos o gatilho) ou tecla
	if _aprendendo.ends_with("_arma"):
		if OS.get_ticks_msec() - _aprender_desde < 350:
			return
		if ev is InputEventMouseButton and ev.pressed:
			if ev.button_index in [BUTTON_LEFT, BUTTON_WHEEL_UP, BUTTON_WHEEL_DOWN, BUTTON_WHEEL_LEFT, BUTTON_WHEEL_RIGHT]:
				return
			_gravar_arma(Maquina.descrever(ev))
			get_tree().set_input_as_handled()
			return
		if ev is InputEventKey and ev.pressed and not ev.echo:
			if ev.scancode == KEY_ESCAPE:
				_cancelar_aprender()
			elif ev.scancode != KEY_F10:
				_gravar_arma(Maquina.descrever(ev))
			get_tree().set_input_as_handled()
			return
	# aprendendo um botão da Zero Delay: o próximo botão do controle
	if _aprendendo != "" and not _aprendendo.ends_with("_arma"):
		if ev is InputEventJoypadButton and ev.pressed:
			Maquina.definir("botoes/" + _aprendendo, ev.button_index)
			Maquina.aplicar()
			_mostrar_aviso("%s = BOTÃO %d  (salve para valer sempre)" % [_aprendendo.to_upper(), ev.button_index], COR_OK)
			_aprendendo = ""
			_atualizar_tudo()
			get_tree().set_input_as_handled()
			return
		if ev is InputEventKey and ev.pressed and ev.scancode == KEY_ESCAPE:
			_cancelar_aprender()
			get_tree().set_input_as_handled()
			return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.scancode:
			KEY_F10, KEY_ESCAPE:
				if _painel_caixa != null:
					_fechar_caixa()
				else:
					_salvar_e_sair()
				get_tree().set_input_as_handled()
				return
			KEY_DOWN, KEY_RIGHT, KEY_TAB:
				_foco = (_foco + 1) % _botoes.size()
				_pintar_foco()
				return
			KEY_UP, KEY_LEFT:
				_foco = (_foco - 1 + _botoes.size()) % _botoes.size()
				_pintar_foco()
				return
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _painel_caixa != null:
					_fechar_caixa()
				else:
					_apertar(_foco)
				get_tree().set_input_as_handled()
				return
	# gatilho: aperta o botão sob a mira
	if Maquina.e_tiro_arma(ev) or ev.is_action_pressed("input_shot"):
		get_tree().set_input_as_handled()
		var p = MiraGlobal.mira()
		_mira.pulso()
		if _painel_caixa != null:
			var f: Panel = _painel_caixa.get_meta("fechar")
			if Rect2(f.rect_position, f.rect_size).grow(8.0).has_point(p):
				_fechar_caixa()
			return
		for i in _botoes.size():
			var no: Panel = _botoes[i]["no"]
			if Rect2(no.rect_position, no.rect_size).grow(4.0).has_point(p):
				_foco = i
				_apertar(i)
				return


func _cancelar_aprender() -> void:
	_aprendendo = ""
	_mostrar_aviso("", COR_APAGADO)
	_atualizar_tudo()


func _process(delta: float) -> void:
	_t += delta
	if _aprendendo != "":
		_aprender_t -= delta
		var r: Label = _rotulos_botao.get(_aprendendo)
		if r != null:
			r.text = "APERTE..." if fmod(_aprender_t, 0.8) > 0.4 else ""
		if _aprender_t <= 0.0:
			_aprendendo = ""
			_mostrar_aviso("Nenhum botão apertado", COR_APAGADO)
			_atualizar_tudo()
	if int(_t * 2.0) != int((_t - delta) * 2.0):
		_desempenho.text = "Agora: %d quadros/s  ·  memória %d MB  ·  vídeo %d MB  ·  tela %dx%d (giro %d)" % [int(round(Tela.fps())),
			int(Tela.memoria_mb()), int(Tela.memoria_video_mb()), int(Tela.janela().x), int(Tela.janela().y), Tela.giro]
