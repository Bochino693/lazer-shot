extends SceneTree
## Máscaras de acerto dos alvos do Mar (scripts/mascara_acerto.gd): para cada
## folha de sprites, uma imagem de 1 canal do mesmo tamanho, 255 onde o
## desenho aparece (alfa > 25%) e 0 no resto. O jogo lê um pixel dela no
## tiro: só vale o que é desenho. Guardadas comprimidas em
## sprites/acerto/<folha>.res (poucos KB cada).
##
##     godot --headless --path . -s tools/gerar_mascaras_acerto.gd

const FOLHAS := ["aguaaa", "hit_bau", "bomba", "sprites_vaso", "mar_peixe_dourado", "mar_cavalo"]
const LIMIAR := 64

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://sprites/acerto")
	for nome in FOLHAS:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://sprites/%s.png" % nome))
		if img == null:
			push_error("faltou " + nome)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width()
		var h := img.get_height()
		var dados := img.get_data()
		var m := PackedByteArray()
		m.resize(w * h)
		for i in w * h:
			m[i] = 255 if dados[i * 4 + 3] > LIMIAR else 0
		var mascara := Image.create_from_data(w, h, false, Image.FORMAT_L8, m)
		var destino := "res://sprites/acerto/%s.res" % nome
		var erro := ResourceSaver.save(mascara, destino, ResourceSaver.FLAG_COMPRESS)
		print("%-20s %dx%d  %s  (%.1f KB)" % [nome, w, h, "ok" if erro == OK else "ERRO %d" % erro,
			FileAccess.get_file_as_bytes(destino).size() / 1024.0])
	quit()
