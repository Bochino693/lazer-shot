extends Node

const SAVE_PATH: String = "user://ranking_lazer_shot.json"
const MAX_RANKING: int = 20
## Só entra no ranking quem fizer MAIS que isto numa partida.
const PONTOS_MINIMOS: int = 4000

var ranking: Array[Dictionary] = []

## A FOTO DESTA PARTIDA (Rodada 31): tirada na tela da pose antes da fase
## (scripts/pose.gd). Vai junto com o recorde, se a partida entrar no
## ranking ("foto" na entrada), e é zerada a cada partida nova.
var foto_da_partida := ""


func _ready() -> void:
	carregar()


func _normalizar_modo(modo: String) -> String:
	var m: String = modo.strip_edges().to_lower()
	if m == "dificil" or m == "difícil":
		return "DIFICIL"
	return "FACIL"


func _peso_modo(modo: String) -> int:
	var m: String = _normalizar_modo(modo)
	if m == "DIFICIL":
		return 2
	return 1


func carregar() -> void:
	ranking.clear()

	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var texto := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(texto) != OK:
		return

	if typeof(json.data) == TYPE_ARRAY:
		for item in json.data:
			if typeof(item) == TYPE_DICTIONARY:
				var entrada: Dictionary = item
				# recordes antigos de 4.000 pontos ou menos não aparecem mais
				if int(entrada.get("pontos", 0)) <= PONTOS_MINIMOS:
					continue

				if not entrada.has("modo"):
					entrada["modo"] = "FACIL"

				entrada["modo"] = _normalizar_modo(str(entrada.get("modo", "FACIL")))
				ranking.append(entrada)

	_ordenar_e_limitar()


func salvar() -> void:
	_ordenar_e_limitar()

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify(ranking, "\t"))
	file.close()


func adicionar_resultado(nome: String, pontos: int, cenario: String, precisao: int = 0, modo: String = "FACIL") -> bool:
	if pontos <= PONTOS_MINIMOS:
		return false

	carregar()

	var entrada := {
		"nome": nome.strip_edges().to_upper(),
		"pontos": pontos,
		"cenario": cenario.to_upper(),
		"precisao": clamp(precisao, 0, 100),
		"modo": _normalizar_modo(modo),
		"data": Time.get_datetime_string_from_system(false, true)
	}
	if foto_da_partida != "":
		entrada["foto"] = foto_da_partida

	ranking.append(entrada)
	_ordenar_e_limitar()
	salvar()
	faxina_fotos()

	return true


## As fotos que não estão em nenhum recorde (nem são da partida de agora)
## são apagadas: só as do Top 20 ficam guardadas na TV Box.
func faxina_fotos() -> void:
	var pasta := "user://ranking_photos"
	var dir := DirAccess.open(pasta)
	if dir == null:
		return
	var usadas := {}
	for e in ranking:
		usadas[str(e.get("foto", "")).get_file()] = true
	usadas[foto_da_partida.get_file()] = true
	for arq in dir.get_files():
		if arq.begins_with("foto_") and arq.ends_with(".jpg") and not usadas.has(arq):
			dir.remove(arq)


func limpar() -> void:
	ranking.clear()
	salvar()


func obter_ranking() -> Array[Dictionary]:
	carregar()
	return ranking.duplicate(true)


func deve_entrar_no_ranking(pontos: int, precisao: int = 0, modo: String = "FACIL") -> bool:
	if pontos <= PONTOS_MINIMOS:
		return false

	carregar()

	if ranking.size() < MAX_RANKING:
		return true

	var ultimo := ranking[ranking.size() - 1]

	var ultimo_pontos: int = int(ultimo.get("pontos", 0))
	var ultimo_precisao: int = int(ultimo.get("precisao", 0))
	var ultimo_modo: String = str(ultimo.get("modo", "FACIL"))

	var peso_novo: int = _peso_modo(modo)
	var peso_ultimo: int = _peso_modo(ultimo_modo)

	if pontos > ultimo_pontos:
		return true

	if pontos < ultimo_pontos:
		return false

	if peso_novo > peso_ultimo:
		return true

	if peso_novo < peso_ultimo:
		return false

	if precisao > ultimo_precisao:
		return true

	return false


func _ordenar_e_limitar() -> void:
	ranking.sort_custom(func(a, b):
		var pontos_a: int = int(a.get("pontos", 0))
		var pontos_b: int = int(b.get("pontos", 0))

		if pontos_a != pontos_b:
			return pontos_a > pontos_b

		var modo_a: int = _peso_modo(str(a.get("modo", "FACIL")))
		var modo_b: int = _peso_modo(str(b.get("modo", "FACIL")))

		if modo_a != modo_b:
			return modo_a > modo_b

		var precisao_a: int = int(a.get("precisao", 0))
		var precisao_b: int = int(b.get("precisao", 0))

		if precisao_a != precisao_b:
			return precisao_a > precisao_b

		return str(a.get("data", "")) > str(b.get("data", ""))
	)

	while ranking.size() > MAX_RANKING:
		ranking.pop_back()
