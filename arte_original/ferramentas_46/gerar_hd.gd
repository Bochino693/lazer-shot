extends SceneTree
## tools/hd/<nome>@hd.png (tools/gerar_hd.py: super-resolução em 1,5x com
## nitidez) -> sprites/hd/<nome>.res
##
## Comprime em ETC2 (a Mali-G31 lê direto, sem descompactar: carrega rápido e
## gasta menos memória que o PNG sem perda) e guarda junto o tamanho do
## original: scripts/hd.gd monta a textura com size_override nele, então o
## jogo continua vendo 1024x1536 e todas as coordenadas em px continuam
## valendo.
##
##     godot --headless --path . -s tools/gerar_hd.gd [-- nome ...]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://sprites/hd")
	var pasta := ProjectSettings.globalize_path("res://tools/hd")
	# com nomes depois de "--", só esses (os outros .res ficam como estão)
	var so := OS.get_cmdline_user_args()
	for f in DirAccess.get_files_at(pasta):
		if not f.ends_with("@hd.png"):
			continue
		var nome := f.trim_suffix("@hd.png")
		if not so.is_empty() and not nome in so:
			continue
		var original := Image.load_from_file(ProjectSettings.globalize_path("res://sprites/%s.png" % nome))
		var img := Image.load_from_file(pasta.path_join(f))
		if original == null or img == null:
			push_error("faltou " + nome)
			continue
		var tam := Vector2i(original.get_width(), original.get_height())
		var alvo := Vector2i(img.get_width(), img.get_height())
		if original.detect_alpha() == Image.ALPHA_NONE:
			img.convert(Image.FORMAT_RGB8)
		img.compress(Image.COMPRESS_ETC2, Image.COMPRESS_SOURCE_GENERIC)
		# o tamanho do original vai junto (scripts/hd.gd põe no size_override)
		img.set_meta("tamanho", tam)
		var destino := "res://sprites/hd/%s.res" % nome
		var erro := ResourceSaver.save(img, destino)
		print("%-22s %s -> %s  %s  (%.1f MB)" % [nome, tam, alvo, "ok" if erro == OK else "ERRO %d" % erro,
			FileAccess.get_file_as_bytes(destino).size() / 1048576.0])
	quit()
