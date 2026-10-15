extends Node

## CONTORNO DE DESENHO: liga só quando a caixa-preta mandou (a TV Box já caiu
## uma vez preparando um jeito de desenhar ou um shader; scripts/aquecedor.gd,
## scripts/caixa_preta.gd). Em vez de cair de novo no mesmo ponto, o jogo
## segue sem aquele recurso:
##
##   "desenho:soma_*"           luz somada (CanvasItemMaterial BLEND_MODE_ADD)
##                              vira mistura comum: brilhos ficam mais fracos
##   "desenho:comum_instancias" partículas e MultiMesh ficam escondidos
##   "desenho:texto"            letras desenhadas na hora (sem MSDF)
##   "shader:<nome>"            o shader vira um desenho simples (a imagem
##                              sem o efeito; retângulo de cor fica
##                              transparente)
##   "som"                      sem efeitos sonoros (scripts/Maquina.gd)
##
## Retângulo, linha e polígono comuns não têm substituto (todo o jogo é feito
## deles): se um deles cair, a caixa-preta mostra qual foi.
##
## Cada nó que entra na árvore é conferido uma vez (no fim do quadro, depois
## de o script que o criou terminar de configurar o material).

const SIMPLES := "shader_type canvas_item;\n"

var _sem_soma := false
var _sem_instancias := false
var _shaders: Dictionary = {}     # Shader trocado -> true
var _guardados: Array = []        # recursos alterados: ficam na memória (e alterados)
var _trocados := 0


## true se algum contorno de desenho está valendo (aí este nó fica ativo).
static func precisa(contornos: PackedStringArray) -> bool:
	for c in contornos:
		if c.begins_with("desenho:soma_") or c == "desenho:comum_instancias" or c == "desenho:texto" or c.begins_with("shader:"):
			return true
	return false


func configurar(contornos: PackedStringArray) -> void:
	for c in contornos:
		if c.begins_with("desenho:soma_"):
			_sem_soma = true
		elif c == "desenho:comum_instancias":
			_sem_instancias = true
		elif c == "desenho:texto":
			_letras_sem_msdf()
		elif c.begins_with("shader:"):
			_shader_simples(c.trim_prefix("shader:"))
	Tela.marca("contorno de desenho: luz somada %s, partículas %s, shaders simples %d" % [
		"comum" if _sem_soma else "normal", "escondidas" if _sem_instancias else "normais", _shaders.size()])
	get_tree().node_added.connect(_ao_entrar)


func _letras_sem_msdf() -> void:
	for caminho: String in Aquecedor.FONTES:
		if not ResourceLoader.exists(caminho):
			continue
		var f := load(caminho) as FontFile
		if f != null:
			f.multichannel_signed_distance_field = false
			_guardados.append(f)


## O recurso do shader fica com um código simples: todos os materiais que o
## usam (pré-carregados ou não) passam a desenhar só a imagem.
func _shader_simples(nome: String) -> void:
	var caminho := "res://shaders/%s.gdshader" % nome
	if not ResourceLoader.exists(caminho):
		return
	var sh := load(caminho) as Shader
	if sh == null:
		return
	sh.code = SIMPLES
	_shaders[sh] = true
	_guardados.append(sh)


func _ao_entrar(no: Node) -> void:
	if no is CanvasItem:
		_conferir.call_deferred(no)


func _conferir(no: Node) -> void:
	if not is_instance_valid(no):
		return
	var ci := no as CanvasItem
	var m := ci.material
	if _sem_soma and m is CanvasItemMaterial and (m as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
		ci.material = null
		_trocados += 1
	elif m is ShaderMaterial and _shaders.has((m as ShaderMaterial).shader) and ci is ColorRect:
		# retângulo de cor que só existia pelo efeito: sem ele, fica
		# transparente (os scripts podem mostrá-lo e escondê-lo à vontade)
		ci.self_modulate = Color(1, 1, 1, 0)
		_trocados += 1
	if _sem_instancias and (ci is CPUParticles2D or ci is MultiMeshInstance2D):
		ci.visible = false
		ci.process_mode = Node.PROCESS_MODE_DISABLED
		_trocados += 1
