extends Node

## RANKING DOS 20 MELHORES (o mesmo arquivo e o mesmo formato da 4.6:
## user://ranking_lazer_shot.json). Só entra quem fizer MAIS de 4.000 pontos.

const SAVE_PATH = "user://ranking_lazer_shot.json"
const MAX_RANKING = 20
const PONTOS_MINIMOS = 4000

var ranking = []


func _ready() -> void:
	carregar()


func carregar() -> void:
	ranking.clear()
	var f = File.new()
	if not f.file_exists(SAVE_PATH):
		return
	if f.open(SAVE_PATH, File.READ) != OK:
		return
	var texto = f.get_as_text()
	f.close()
	var res = JSON.parse(texto)
	if res.error != OK or typeof(res.result) != TYPE_ARRAY:
		return
	for item in res.result:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if int(item.get("pontos", 0)) <= PONTOS_MINIMOS:
			continue
		ranking.append(item)
	_ordenar_e_limitar()


func salvar() -> void:
	_ordenar_e_limitar()
	var f = File.new()
	if f.open(SAVE_PATH, File.WRITE) != OK:
		return
	f.store_string(JSON.print(ranking, "\t"))
	f.close()


func adicionar_resultado(nome: String, pontos: int, cenario: String, precisao: int = 0, foto: String = "") -> bool:
	if pontos <= PONTOS_MINIMOS:
		return false
	carregar()
	var d = OS.get_datetime()
	ranking.append({
		"nome": nome.strip_edges().to_upper(),
		"pontos": pontos,
		"cenario": cenario.to_upper(),
		"precisao": int(clamp(precisao, 0, 100)),
		"modo": "FACIL",
		"foto": foto,
		"data": "%04d-%02d-%02d %02d:%02d:%02d" % [d.year, d.month, d.day, d.hour, d.minute, d.second],
	})
	salvar()
	return true


func limpar() -> void:
	ranking.clear()
	salvar()


func obter_ranking() -> Array:
	carregar()
	return ranking.duplicate(true)


## O recorde de um cenário ({} se não houver).
func recorde(cenario: String) -> Dictionary:
	for e in obter_ranking():
		if normalizar(str(e.get("cenario", ""))) == cenario:
			return e
	return {}


## O cenário salvo (as versões antigas gravavam o nome inteiro) numa das
## quatro chaves: DESERTO, MAR, BAR, ARENA.
static func normalizar(valor: String) -> String:
	var c = valor.strip_edges().to_upper()
	if "DESERTO" in c or "SAGRADO" in c:
		return "DESERTO"
	if "ARENA" in c or "LAZER" in c:
		return "ARENA"
	if "FAROESTE" in c or c.begins_with("BAR"):
		return "BAR"
	if "MAR" in c or "FUNDO" in c:
		return "MAR"
	return c


func deve_entrar_no_ranking(pontos: int, precisao: int = 0) -> bool:
	if pontos <= PONTOS_MINIMOS:
		return false
	carregar()
	if ranking.size() < MAX_RANKING:
		return true
	var ultimo: Dictionary = ranking[ranking.size() - 1]
	var up = int(ultimo.get("pontos", 0))
	if pontos != up:
		return pontos > up
	return precisao > int(ultimo.get("precisao", 0))


class _Ordem:
	static func antes(a, b) -> bool:
		var pa = int(a.get("pontos", 0))
		var pb = int(b.get("pontos", 0))
		if pa != pb:
			return pa > pb
		var ca = int(a.get("precisao", 0))
		var cb = int(b.get("precisao", 0))
		if ca != cb:
			return ca > cb
		return str(a.get("data", "")) > str(b.get("data", ""))


func _ordenar_e_limitar() -> void:
	ranking.sort_custom(_Ordem, "antes")
	while ranking.size() > MAX_RANKING:
		ranking.pop_back()
