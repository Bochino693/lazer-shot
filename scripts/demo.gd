extends Node2D

@export_file("*.tscn") var cena_main_menu: String = "res://scenes/main.tscn"
@export var tempo_por_cenario: float = 20.0

var instancia_atual: Node = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var ultimo_cenario: String = ""

const CENARIOS_DEMO: Array[String] = [
	"res://scenes/game.tscn",
	"res://scenes/bar.tscn"
]

func _ready() -> void:
	rng.randomize()
	_carregar_cenario_aleatorio()
	call_deferred("_loop_demo")


func _loop_demo() -> void:
	while is_inside_tree():
		await get_tree().create_timer(tempo_por_cenario).timeout
		if not is_inside_tree():
			return
		_carregar_cenario_aleatorio()


func _carregar_cenario_aleatorio() -> void:
	if instancia_atual != null and is_instance_valid(instancia_atual):
		instancia_atual.queue_free()
		instancia_atual = null

	var caminho: String = _sortear_cenario()
	if caminho == "":
		push_error("Nenhum cenário válido para demo.")
		return

	if not ResourceLoader.exists(caminho):
		push_error("Cenário não encontrado: " + caminho)
		return

	var packed: PackedScene = load(caminho)
	if packed == null:
		push_error("Falha ao carregar: " + caminho)
		return

	instancia_atual = packed.instantiate()
	add_child(instancia_atual)

	_configurar_instancia_demo(instancia_atual)


func _sortear_cenario() -> String:
	var validos: Array[String] = []

	for caminho in CENARIOS_DEMO:
		if caminho != "" and ResourceLoader.exists(caminho):
			validos.append(caminho)

	if validos.is_empty():
		return ""

	if validos.size() == 1:
		ultimo_cenario = validos[0]
		return ultimo_cenario

	var candidatos: Array[String] = []
	for c in validos:
		if c != ultimo_cenario:
			candidatos.append(c)

	if candidatos.is_empty():
		candidatos = validos.duplicate()

	var escolhido: String = candidatos[rng.randi_range(0, candidatos.size() - 1)]
	ultimo_cenario = escolhido
	return escolhido


func _configurar_instancia_demo(no: Node) -> void:
	_setar_se_existir(no, "modo_demo", true)
	_setar_se_existir(no, "tempo_demo", tempo_por_cenario)
	_setar_se_existir(no, "cena_main_menu", cena_main_menu)

	for filho in no.get_children():
		_configurar_instancia_demo(filho)


func _setar_se_existir(obj: Object, propriedade: String, valor) -> void:
	for info in obj.get_property_list():
		if String(info.name) == propriedade:
			obj.set(propriedade, valor)
			return
