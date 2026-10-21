extends SceneTree
# Robô jogando uma tela (CENA = deserto | mar | bar | arena) para a demo do
# menu: começa a partida pelo START, mira com movimento de mão (mola
# amortecida) no alvo certo mais perto e atira quando chega. Grava com o
# Movie Maker do Godot (--write-movie); DUR = segundos de partida.

const CENAS := {
	"deserto": "res://scenes/deserto.tscn",
	"mar": "res://scenes/mar.tscn",
	"bar": "res://scenes/bar.tscn",
	"arena": "res://scenes/arena.tscn",
}

var cena := OS.get_environment("CENA")
var dur := float(OS.get_environment("DUR")) if OS.get_environment("DUR") != "" else 34.0
var t := 0.0
var t_jogo := -1.0
var fase := 0
var mira := Vector2(512, 1000)
var vel := Vector2.ZERO
var alvo_id := 0
var alvo_pos := Vector2.INF
var espera := 0.0
var tiros := 0
var alvo_ant := 0
var p_ant := Vector2.ZERO
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 18
	seed(18)
	change_scene_to_file(CENAS[cena])


func _ev(acao: String) -> void:
	var e := InputEventAction.new()
	e.action = acao
	e.pressed = true
	Input.parse_input_event(e)
	var s := InputEventAction.new()
	s.action = acao
	s.pressed = false
	Input.parse_input_event(s)


func _comecou(cs: Node) -> bool:
	match cena:
		"arena":
			return bool(cs.get("jogo_ativo"))
		"deserto":
			return bool(cs.partida_iniciada) and not bool(cs.countdown_ativo)
		_:
			return bool(cs.get("partida_iniciada"))


func _process(d: float) -> bool:
	t += d
	var cs := current_scene
	if cs == null:
		return false
	var mg := root.get_node("MiraGlobal")
	if fase == 0:
		if t > 2.2:
			fase = 1
		mg.levar_para(mira)
		return false
	if fase == 1:
		if _comecou(cs):
			fase = 2
			t_jogo = 0.0
			print("robo: comecou no quadro ", Engine.get_process_frames())
			if cena == "mar":
				cs._cardume_espera = 7.0
		elif fmod(t, 1.2) < d:
			if cena == "deserto":
				cs._iniciar_countdown()
			elif cena == "bar":
				_ev("input_shot")      # no bar a partida começa com um tiro
			else:
				_ev("input_start")
		mg.levar_para(mira)
		return false
	t_jogo += d
	if t_jogo > dur:
		print("robo: fim, tiros ", tiros)
		quit()
		return false
	_municao(cs)
	espera -= d
	var p := _escolher(cs)
	if p == Vector2.INF:
		# sem alvo: a mira passeia devagar pelo meio
		p = Vector2(512 + sin(t * 0.7) * 260.0, 900 + sin(t * 0.43) * 380.0)
	# mão: mola amortecida (chega rápido sem tremer)
	# o alvo anda: a mão acompanha a velocidade dele (sem ficar para trás)
	var v_alvo := Vector2.ZERO
	if alvo_id != 0 and alvo_id == alvo_ant and d > 0.0:
		v_alvo = (p - p_ant) / d
	alvo_ant = alvo_id
	p_ant = p
	var k := 120.0
	var passos := maxi(1, ceili(d / (1.0 / 120.0)))
	var h := d / passos
	for i in passos:
		var acc := (p + v_alvo * 0.05 - mira) * k - (vel - v_alvo) * (2.0 * sqrt(k) * 0.9)
		vel += acc * h
		mira += vel * h
	mg.levar_para(mira)
	if alvo_pos != Vector2.INF and espera <= 0.0 and mira.distance_to(p) < 40.0 and _na_mira(cs, mira):
		_atirar(cs, mira)
		tiros += 1
		espera = rng.randf_range(0.16, 0.32)
		alvo_pos = Vector2.INF
		alvo_id = 0
	return false


## Tem um alvo certo exatamente sob a mira agora? (o mesmo teste do jogo)
func _na_mira(cs: Node, p: Vector2) -> bool:
	match cena:
		"deserto":
			var i: int = cs._achar_alvo_no_ponto(p)
			return i >= 0 and cs.alvos_ativos[i].tipo == cs.modo_atual
		"mar":
			var a = cs._detectar_alvo_no_ponto_visual(p)
			if a != null:
				return String(a.get_meta("tipo_alvo", "")) != "bomba"
			var c = cs._cardume
			if c != null and is_instance_valid(c) and c.vivo:
				for f in c._peixes:
					if cs.alvos_root.to_global(c._pos_peixe(f)).distance_to(p) < 30.0:
						return true
			return false
		"bar":
			var g = cs._detectar_garrafa_no_ponto(p)
			return g != null and _tipo_garrafa(g) != "garrafa_falsa"
		"arena":
			var a2 = cs._detectar_alvo_no_ponto_visual(p)
			if a2 == null or cs.sequencia_atual.is_empty() or cs.indice_sequencia >= cs.sequencia_atual.size():
				return false
			var dados: Dictionary = cs.dados_alvos.get(a2.get_instance_id(), {})
			return int(dados.get("slot", -1)) == cs.sequencia_atual[cs.indice_sequencia]
	return true


## Tipo da garrafa: as impostoras guardam o tipo no meta (a garrafa não tem
## a propriedade tipo_alvo).
func _tipo_garrafa(g: Node) -> String:
	var t = g.get("tipo_alvo")
	if t == null:
		t = g.get_meta("tipo_alvo", "")
	return str(t)


func _municao(cs: Node) -> void:
	match cena:
		"arena":
			cs.municao_atual = maxi(int(cs.municao_atual), 10)
		_:
			cs.balas_no_cartucho = 30


func _atirar(cs: Node, p: Vector2) -> void:
	match cena:
		"deserto":
			cs._processar_tiro(p)
		"arena":
			cs._tentar_atirar(p)
		_:
			cs._processar_tiro_global(p)


## O alvo certo mais perto da mira (segue o mesmo até atirar).
func _escolher(cs: Node) -> Vector2:
	var melhor := Vector2.INF
	var melhor_d := INF
	var melhor_id := 0
	for c in _candidatos(cs):
		var id: int = c[0]
		var pos: Vector2 = c[1]
		var dd := pos.distance_to(mira)
		if id == alvo_id:
			dd *= 0.2      # não troca de alvo à toa
		if dd < melhor_d:
			melhor_d = dd
			melhor = pos
			melhor_id = id
	alvo_id = melhor_id
	alvo_pos = melhor
	return melhor


func _candidatos(cs: Node) -> Array:
	var lista := []
	match cena:
		"deserto":
			for a in cs.alvos_ativos:
				if a == null or a.node == null or not is_instance_valid(a.node) or not a.node.visible or a.alfa < 0.5:
					continue
				if a.tipo != cs.modo_atual:
					continue
				var anim = cs._obter_animado(a.node)
				if anim == null:
					continue
				var pos: Vector2 = anim.global_position
				if pos.y < 150.0 or pos.y > 1760.0 or pos.x < 20.0 or pos.x > 1004.0:
					continue
				lista.append([a.node.get_instance_id(), pos])
		"mar":
			var c = cs._cardume
			if c != null and is_instance_valid(c) and c.vivo and c._t > 1.0:
				var pf: Vector2 = cs.alvos_root.to_global(c._pos_peixe(c._peixes[0]))
				if pf.x > 60.0 and pf.x < 964.0:
					return [[c.get_instance_id(), pf]]
			for a in cs.alvos_ativos:
				if a == null or not is_instance_valid(a) or not a.visible:
					continue
				if bool(a.get_meta("atingido", false)):
					continue
				var tipo := String(a.get_meta("tipo_alvo", ""))
				if tipo == "bomba" or tipo == "":
					continue
				var anim = cs._obter_animated_do_alvo(a)
				var pos: Vector2 = anim.global_position if anim != null else a.global_position
				if pos.y < 170.0 or pos.y > 1760.0 or pos.x < 30.0 or pos.x > 994.0:
					continue
				if float(a.get_meta("longe", 0.0)) > 0.75:
					continue
				lista.append([a.get_instance_id(), pos])
		"bar":
			for a in cs.garrafas_ativas:
				if a == null or not is_instance_valid(a) or not a.visible:
					continue
				if a.get("ja_acertado") == true or a.get("saindo_individual") == true:
					continue
				if _tipo_garrafa(a) == "garrafa_falsa":
					continue
				var pos: Vector2 = a.global_position
				for off in [Vector2.ZERO, Vector2(0, -24), Vector2(0, 24), Vector2(0, -48)]:
					if cs._ponto_esta_sobre_garrafa_real(a, pos + off):
						lista.append([a.get_instance_id(), pos + off])
						break
		"arena":
			if cs.mostrando_sequencia or cs.bloqueia_tiro_sequencia or cs.sequencia_atual.is_empty():
				return lista
			if cs.indice_sequencia < 0 or cs.indice_sequencia >= cs.sequencia_atual.size():
				return lista
			var slot: int = cs.sequencia_atual[cs.indice_sequencia]
			for a in cs.alvos_ativos:
				if a == null or not is_instance_valid(a):
					continue
				var dados: Dictionary = cs.dados_alvos.get(a.get_instance_id(), {})
				if int(dados.get("slot", -1)) == slot and not bool(dados.get("quebrando", false)):
					lista.append([a.get_instance_id(), a.global_position])
	return lista
