class_name Hd
extends RefCounted

## Fundos em alta para a TV (impressão de 4K).
##
## Para cada fundo grande existe sprites/hd/<nome>.res (tools/gerar_hd.py +
## tools/gerar_hd.gd): a mesma imagem refeita por super-resolução em 1,5x,
## comprimida em ETC2 (a Mali-G31 lê direto: carrega rápido e ocupa menos
## memória que o PNG sem perda), com o tamanho do original guardado nela.
## textura() monta a textura com size_override nesse tamanho: o jogo continua
## vendo 1024x1536 (todas as coordenadas em px, regiões e mapas continuam
## valendo) e a placa desenha com o dobro de detalhe.
## Sem o .res, devolve o PNG de sempre.
##
## A mesma textura é reaproveitada enquanto alguém a usa (cache fraco: some
## sozinha ao trocar de tela).

const PASTA := "res://sprites/hd/"
const CACHE := "hd_cache"


static func textura(png: String) -> Texture2D:
	var nome := png.get_file().get_basename()
	var cache: Dictionary = Engine.get_meta(CACHE) if Engine.has_meta(CACHE) else {}
	var ref: WeakRef = cache.get(nome)
	if ref != null and ref.get_ref() != null:
		return ref.get_ref()
	var caminho := PASTA + nome + ".res"
	if ResourceLoader.exists(caminho):
		var img := load(caminho) as Image
		if img != null and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			var tam: Vector2i = img.get_meta("tamanho", Vector2i.ZERO)
			if tam != Vector2i.ZERO:
				tex.set_size_override(tam)
			cache[nome] = weakref(tex)
			Engine.set_meta(CACHE, cache)
			return tex
	return load(png)
