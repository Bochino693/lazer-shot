class_name DesertoVivo
extends Node2D

## EGITO VIVO: o fundo do Deserto Sagrado em camadas, tudo na placa de vídeo.
##
## Todas as posições aqui são pixels da imagem (1024x1536); o nó inteiro é
## escalado para cobrir a tela (sem zoom), ancorado no alto.
##
##   fundo (sol / lua)   imagem + shaders/deserto_fundo.gdshader: feixes de
##                       energia, cristal, ar quente, onda de luz na batida
##   raios               luz em volta do disco girando (egito_raios)
##   disco               sol com o Olho de Rá / lua com o Olho de Hórus feitos
##                       como joia egípcia: esmalte azul-lápis com borda de
##                       ouro (sol) ou prata (lua) em relevo, olho grande e
##                       realista (íris amarelo-castanha no sol, branco-
##                       azulada na lua) ocupando o astro inteiro; pintados
##                       em 4x (nítidos em 4K), em camadas comuns sem shader:
##                       esclera, íris que passeia, pálpebra-joia que desce ao
##                       piscar e o disco com a joia por cima
##                       (tools/gerar_astros.py)
##   águias              planando ao fundo em térmicas, batendo as asas de vez
##                       em quando, inclinando nas curvas, gritando (eco do
##                       vale); de noite silhuetas, às vezes cruzando a lua
##   pontas de ouro      topo das 3 pirâmides, pintado dentro do próprio
##                       fundo (mesma resolução e luz da pedra): ouro ao sol,
##                       claro ao luar; o combo acende, os erros apagam, cada
##                       acerto passa um reflexo de uma para outra
##   diamante            arco-íris nas arestas de dia, vermelho de noite
##   brilhos             estrelas que piscam no diamante, nas pontas e no
##                       disco; estrelas no céu e estrela cadente de noite
##   planos 3D           a cena é feita de planos tirados da própria imagem
##                       (tools/gerar_camadas.py): o fundo (céu, pirâmides e
##                       chão, com o que estava atrás das coisas reconstruído)
##                       e, separados, colunas, Anúbis, obeliscos e o cristal
##                       com o pedestal. A câmera anda com a mira e cada plano
##                       anda pela sua distância (o chão, pixel a pixel pela
##                       altura); os brasões entram na mesma ordem de desenho
##                       (passam atrás e na frente das coisas de verdade).
##   feixes              os quatro feixes de energia do cristal aos obeliscos
##                       são peças vivas (scripts/egito_feixes.gd): pulsam com
##                       a música, apagam de um lado quando o cristal daquele
##                       obelisco quebra e todos quando o do meio quebra; a
##                       carga dos acertos vira a descarga do cristal.
##   cristais das pontas os dois cristais dos obeliscos levam tiro: trincam e,
##                       quebrados, apagam (voltam sozinhos depois).
##   nuvens              ondulam e correm conforme o humor do astro: agitadas
##                       quando ele está feliz, calmas quando está tenso.
##
## Uso: var vivo := DesertoVivo.new(); pai.add_child(vivo)
## (sem zoom: a imagem só cobre a tela, como as outras fases)
##      vivo.mostrar("sol" ou "lua", suave)

const IMG := Vector2(1024, 1536)

# Imagens e sons com load() da instância, e não preload() em const: o Godot
# 4.6 nunca descarrega um script já carregado, e o que ele pré-carrega fica
# junto na memória até o jogo fechar (~50 MB do Egito presos depois da
# primeira partida). Assim tudo some com a fase. A troca de tela já pede
# estes arquivos numa thread (scripts/precarga.gd): o load() acha pronto.
# fundo sem as coisas em pé (reconstruído atrás delas) e a folha dos planos
var FUNDO_SOL: Texture2D = load("res://sprites/egito_fundo_sol.png")
var FUNDO_LUA: Texture2D = load("res://sprites/egito_fundo_lua.png")
var PLANOS_SOL: Texture2D = load("res://sprites/egito_planos_sol.png")
var PLANOS_LUA: Texture2D = load("res://sprites/egito_planos_lua.png")
var PLANOS_BRILHO: Texture2D = load("res://sprites/egito_planos_brilho.png")
var LUZ_FUNDO: Texture2D = load("res://sprites/egito_fundo_luz.png")
# Sol e lua em 4x (tools/gerar_astros.py), camadas comuns sem shader:
# halo (1x, ampliado), esclera, íris (anda), pálpebra (desce ao piscar) e o disco por cima.
var TEX_SOL: Array = [load("res://sprites/egito_sol_disco.png"), load("res://sprites/egito_sol_esclera.png"),
	load("res://sprites/egito_sol_iris.png"), load("res://sprites/egito_sol_palpebra.png"),
	load("res://sprites/egito_sol_halo.png"), load("res://sprites/egito_sol_palpebra_baixo.png")]
var TEX_LUA: Array = [load("res://sprites/egito_lua_disco.png"), load("res://sprites/egito_lua_esclera.png"),
	load("res://sprites/egito_lua_iris.png"), load("res://sprites/egito_lua_palpebra.png"),
	load("res://sprites/egito_lua_halo.png"), load("res://sprites/egito_lua_palpebra_baixo.png")]
var AGUIA: Texture2D = load("res://sprites/egito_aguia.png")
var SOM_AGUIA: AudioStream = load("res://songs/aguia.wav")
var SOM_AGUIA_NOITE: AudioStream = load("res://songs/aguia_noite.wav")
var PONTAS: Texture2D = load("res://sprites/egito_pontas.png")
var CRISTAL: Texture2D = load("res://sprites/egito_cristal_mascara.png")
var ESTRELA: Texture2D = load("res://sprites/egito_estrela.png")
var PROFUNDIDADE: Texture2D = load("res://sprites/egito_profundidade.png")
const SHADER_FUNDO := preload("res://shaders/deserto_fundo.gdshader")
const SHADER_ALVO := preload("res://shaders/egito_alvo.gdshader")
const SHADER_PLANO := preload("res://shaders/egito_plano.gdshader")
const SHADER_RAIOS := preload("res://shaders/egito_raios.gdshader")
const SHADER_CRISTAL := preload("res://shaders/egito_cristal.gdshader")

# Mesmos números de tools/gerar_egito.py.
const CENTRO_SOL := Vector2(512, 300)
const RAIO_SOL := 138.0
const CENTRO_LUA := Vector2(512, 300)
const RAIO_LUA := 138.0
const PONTAS_CAIXA := Rect2(180, 438, 644, 148)

# Medidas do olho (px da textura 3x, a partir do centro do disco), de
# tools/gerar_astros.py: centro do olho, 1 unidade (meia largura da abertura),
# lugar da íris, topo da pálpebra e quanto ela desce para fechar, centro da
# pálpebra de baixo em repouso e quanto ela sobe no máximo.
# Sol: Olho de Rá (o direito); lua: Olho de Hórus (o esquerdo, espelho).
const ASTRO_SOL := {"olho": Vector2(-47.9, -12.0), "u": 342.2, "ux": 479.1, "iris": Vector2(0.0, -13.7), "palpebra_y": -383.4, "abre": 263.6, "baixo_y": 394.9, "sobe": 239.6}
const ASTRO_LUA := {"olho": Vector2(47.9, -12.0), "u": 342.2, "ux": 479.1, "iris": Vector2(0.0, -13.7), "palpebra_y": -383.4, "abre": 263.6, "baixo_y": 394.9, "sobe": 239.6}

# Humor dos olhos. topo: quanto a pálpebra de cima desce (0 aberta, 1
# fechada); baixo: quanto a de baixo sobe (fração de "sobe"; a beirada curva
# para cima, então subindo ela deixa o olho em meia-lua, sorrindo);
# iris_y: íris um pouco acima/abaixo; alcance: o vaivém da íris; vel: rapidez
# com que a íris chega (baixo = desliza calma, alto = salto); mira: segue a mira
# do jogador; piscar: intervalo entre piscadas (s).
const HUMORES := {
	"calmo": {"topo": 0.30, "baixo": 0.12, "iris_y": 0.0, "alcance": 0.55, "vel": 5.0, "mira": false, "piscar": Vector2(3.0, 6.0)},
	"feliz": {"topo": 0.08, "baixo": 0.52, "iris_y": -0.03, "alcance": 0.35, "vel": 6.0, "mira": false, "piscar": Vector2(2.5, 5.0)},
	"radiante": {"topo": 0.10, "baixo": 0.66, "iris_y": -0.05, "alcance": 0.25, "vel": 7.0, "mira": false, "piscar": Vector2(2.0, 4.0)},
	"atento": {"topo": 0.18, "baixo": 0.24, "iris_y": 0.01, "alcance": 1.0, "vel": 14.0, "mira": true, "piscar": Vector2(4.5, 8.0)},
	"bravo": {"topo": 0.50, "baixo": 0.28, "iris_y": 0.02, "alcance": 0.7, "vel": 10.0, "mira": true, "piscar": Vector2(5.0, 9.0)},
	"surpreso": {"topo": 0.04, "baixo": 0.0, "iris_y": 0.0, "alcance": 0.3, "vel": 18.0, "mira": false, "piscar": Vector2(5.0, 8.0)},
	"sono": {"topo": 0.58, "baixo": 0.14, "iris_y": 0.02, "alcance": 0.3, "vel": 2.0, "mira": false, "piscar": Vector2(2.5, 4.5)},
}
const ASTRO_X := 4.0          # as texturas do astro são 4x a imagem do fundo (o halo é 1x)
const CRISTAL_CAIXA := Rect2(440, 620, 136, 340)

# Tiros no fundo (px da imagem): o cristal trinca e, depois de TIROS_CRISTAL
# tiros, quebra: a energia (feixes, brilho, faíscas) apaga e ele fica escuro
# e rachado (sprites/egito_cristal_morto_*.png, tools/gerar_cristal_morto.py)
# por CRISTAL_VOLTA s, até se refazer. As pontas de ouro tocam (clarão e
# anel no metal, faíscas e lasquinhas de ouro), pedra lasca e areia levanta.
const TIROS_CRISTAL := 9
# cristais das pontas dos obeliscos (px da imagem): trincam e quebram com
# menos tiros que o do meio e voltam sozinhos
const POLI_PONTAS := [
	[Vector2(209, 760), Vector2(195, 790), Vector2(193, 842), Vector2(225, 842), Vector2(223, 790)],
	[Vector2(812, 760), Vector2(799, 790), Vector2(797, 842), Vector2(830, 842), Vector2(826, 790)],
]
const TIROS_PONTA := 4
const PLANOS_COM_LUZ := ["cristal", "obelisco_esq", "obelisco_dir"]
const PONTA_VOLTA := 22.0
const Z_OBELISCO := 1.554
const CRISTAL_VOLTA := 30.0
const CAIXA_MORTO := Rect2(428, 608, 160, 376)
var CRISTAL_MORTO_SOL: Texture2D = load("res://sprites/egito_cristal_morto_sol.png")
var CRISTAL_MORTO_LUA: Texture2D = load("res://sprites/egito_cristal_morto_lua.png")
var SOM_TRINCA: AudioStream = load("res://songs/cristal_trinca.wav")
var SOM_QUEBRA: AudioStream = load("res://songs/cristal_quebra.wav")
var SOM_VOLTA: AudioStream = load("res://songs/cristal_volta.wav")
var SOM_OURO: AudioStream = load("res://songs/ouro_ping.wav")
var SOM_PEDRA: AudioStream = load("res://songs/pedra_lasca.wav")
var SOM_AREIA: AudioStream = load("res://songs/areia_tiro.wav")
const Pincel := preload("res://scripts/pincel.gd")
var POLI_CRISTAL := PackedVector2Array([Vector2(506, 626), Vector2(546, 668), Vector2(560, 720), Vector2(558, 900),
	Vector2(536, 968), Vector2(478, 968), Vector2(454, 900), Vector2(452, 720), Vector2(466, 668)])
# pontas de ouro = a ponta pintada de cada pirâmide (tools/gerar_egito.py)
var OURO: Array[PackedVector2Array] = [PackedVector2Array([Vector2(509, 447), Vector2(449, 524), Vector2(509, 501), Vector2(546, 497)]),
	PackedVector2Array([Vector2(229, 519), Vector2(170, 580), Vector2(229, 558), Vector2(256, 554)]),
	PackedVector2Array([Vector2(774, 519), Vector2(721, 582), Vector2(774, 560), Vector2(806, 556)])]
var PIRAMIDES: Array[PackedVector2Array] = [PackedVector2Array([Vector2(508, 444), Vector2(298, 742), Vector2(718, 742)]),
	PackedVector2Array([Vector2(229, 514), Vector2(88, 706), Vector2(362, 706)]),
	PackedVector2Array([Vector2(776, 514), Vector2(640, 706), Vector2(916, 706)])]

const COR_SOL := Color(1.0, 0.78, 0.36)
const COR_LUA := Color(0.62, 0.80, 1.0)

const BRILHOS_CRISTAL := [Vector2(506, 634), Vector2(466, 721), Vector2(548, 721), Vector2(486, 792),
		Vector2(527, 846), Vector2(505, 893), Vector2(461, 944), Vector2(551, 944)]
const BRILHOS_PONTAS := [Vector2(229, 520), Vector2(509, 448), Vector2(774, 520)]
const TEMPO_TROCA := 1.6
# Câmera 3D: com a mira no canto ela anda CAMERA_PASSO px; uma coisa à
# distância Z anda CAMERA_PASSO * (1 - 1/Z) (Z = 1 é o plano dos brasões).
# O mapa vai de Z = 10 (preto: céu, pirâmides) a Z = 0,7 (branco: chão perto).
const CAMERA_PASSO := 30.0
const CAMERA_SUAVE := 2.6
const Z_LONGE := 10.0
const Z_PERTO := 0.7
const Z_CRISTAL := 1.2
# ponto de fuga (pé das pirâmides) e o chão a Z = 1, em px da imagem
# (os mesmos de tools/gerar_profundidade.py)
const HORIZONTE := 700.0
const CHAO_1 := 1300.0
# Águias (tools/gerar_aguias.py): 11 quadros (0 planando, 1..10 batendo asa);
# voam no céu acima das pirâmides, entre as colunas (px da imagem).
const AGUIA_QUADROS := 11
const CEU := Rect2(150, 196, 724, 236)
const N_AGUIAS := 3
const N_ESTRELAS_CEU := 18

var _fundo_sol: Sprite2D
var _fundo_lua: Sprite2D
var _raios_sol: ColorRect
var _raios_lua: ColorRect
var _disco_sol: Node2D
var _disco_lua: Node2D
# olho vivo de cada disco: {disco, iris, palpebra, baixo, iris_0, palpebra_0,
# baixo_0, u, abre, sobe, olhar, alvo, prox_olhar, piscar, prox_piscar, fase,
# dupla, topo_v, baixo_v}
var _olhos: Array = []
# humor: o jogo conta o que aconteceu (evento) e o astro reage
var _combo := 0
var _erros_recentes := 0.0     # cada erro +1, cai 1 a cada 3,5 s
var _tempo_final := false
var _fim := false
var _reacao := ""              # humor curto por cima do de base
var _reacao_t := 0.0
var _espiar := Vector2.INF     # ponto (tela) que o olho espia por um instante
var _espiar_t := 0.0
# pontas de ouro: humor (combo acende, erro apaga) e o reflexo de cada acerto
var _ouro_brilho := 0.0
var _ouro_pulso := 0.0         # pulso curto (acerto +, astro errado -)
var _ouro_varre := -1.0
var _cristal: Sprite2D
var _faiscas: CPUParticles2D
var _poeira: CPUParticles2D
var _ceu_noite: Node2D
var _cadente: Sprite2D

var _brilhos: Array = []      # {no, cor, espera, t, dur, escala}
var _estrelas: Array = []     # {no, w, f}
var _modo := ""
var _noite := 0.0             # 0 = sol ... 1 = lua
var _tw: Tween = null
var _pisco := 0.0
var _proximo_pisco := 5.0
var _onda := 9.0
var _t := 0.0
var _cadente_t := -1.0
var _cadente_em := 6.0
var _cadente_de := Vector2.ZERO
var _cadente_para := Vector2.ZERO
# {no, pos, dir, vel, escala, modo, centro, raio, sentido, alvo, t, t_modo,
#  vida, bat, fase, inclin, grito, ruido, vento, espera}
var _aguias: Array = []
var _grito_espera := 4.0

# planos 3D (recortes da imagem): {no, canto, z}
var _planos: Array[Dictionary] = []
var _mat_planos: ShaderMaterial
var _plano_cristal: Sprite2D
var _plano_obeliscos: Array = [null, null]
var _feixes: EgitoFeixes
var _camada_obeliscos: Node2D          # trincas dos cristais das pontas (anda como os obeliscos)
# cristais das pontas: {danos, quebrado, volta, refaz, morte, trincas}
var _pontas: Array[Dictionary] = []
# descarga do cristal: a carga sobe com os acertos (deserto.gd)
var carga := 0.0
# nuvens: agito (0 calmas .. 1 agitadas) e a fase que corre com ele
var _nuvens := 0.35
var _fase_nuvens := 0.0
var _poeira_perto: CPUParticles2D
var _pontas_acesas := Vector3.ONE        # pontas de ouro (esq, meio, dir) ligadas aos cristais

# câmera 3D
var mira := Vector2.INF        # posição da mira (o jogo atualiza; INF = parada)
var camera := Vector2.ZERO     # quanto a câmera andou agora (px de tela)
var material_alvo: ShaderMaterial = null
var _olhar := Vector2.ZERO
var _camada_ceu: Node2D
var _camada_perto: Node2D
var _prof: Image = null

var _morto: Node2D
var _fx_n: Node2D
var _fx_s: Node2D
var _fx_sujo := false
var _energia := 1.0
var _cristal_danos := 0
var _cristal_tremor := 0.0
var _cristal_quebrado := false
var _cristal_volta := 0.0
var _cristal_morte := 0.0          # 0 inteiro .. 1 apagado (sprite por cima)
var _cristal_refaz := -1.0         # 0..1 enquanto se refaz
var _onda_quebra := -1.0
var _trincas: Array = []           # PackedVector2Array em px da imagem
var _cacos: Array = []
var _faiscas_ouro: Array = []
var _poeiras: Array = []
var _claroes: Array = []
var _toque_ouro := Vector3(0, 0, -1)


func _init() -> void:
	name = "DesertoVivo"
	# no jogo o fundo não tem mais feixes nem cristais pintados (são peças):
	# a máscara de efeitos dele fica vazia
	var vazia := Image.create(4, 4, false, Image.FORMAT_RGB8)
	var sem_mascara := ImageTexture.create_from_image(vazia)
	_fundo_sol = _criar_fundo(FUNDO_SOL, sem_mascara, Color(1.0, 0.74, 0.34), 0.0)
	_fundo_lua = _criar_fundo(FUNDO_LUA, sem_mascara, Color(1.0, 0.28, 0.30), 3.7)
	_criar_planos()
	_criar_feixes()
	_raios_sol = _criar_raios(CENTRO_SOL, RAIO_SOL, 3.1, false, COR_SOL)
	_raios_lua = _criar_raios(CENTRO_LUA, RAIO_LUA, 2.7, true, COR_LUA)
	_disco_sol = _criar_astro(TEX_SOL, ASTRO_SOL, CENTRO_SOL)
	_disco_lua = _criar_astro(TEX_LUA, ASTRO_LUA, CENTRO_LUA)
	_criar_aguias()

	# pontas de ouro: pintadas dentro do próprio fundo, pixel a pixel na grade
	# da foto (mesma resolução, luz e brilho da pedra); só o ouro reage ao jogo
	var caixa := Vector4(PONTAS_CAIXA.position.x / IMG.x, PONTAS_CAIXA.position.y / IMG.y,
		PONTAS_CAIXA.size.x / IMG.x, PONTAS_CAIXA.size.y / IMG.y)
	for par in [[_fundo_sol, 0.0], [_fundo_lua, 1.0]]:
		var mf := (par[0] as Sprite2D).material as ShaderMaterial
		mf.set_shader_parameter("pontas", PONTAS)
		mf.set_shader_parameter("pontas_caixa", caixa)
		mf.set_shader_parameter("ouro_noite", par[1])
	_cristal = _sprite_2x(CRISTAL, CRISTAL_CAIXA.position, SHADER_CRISTAL)
	_criar_cristal_vivo()

	_criar_particulas()

	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_ceu_noite = Node2D.new()
	_ceu_noite.name = "CeuNoite"
	add_child(_ceu_noite)
	_criar_estrelas_ceu(soma)
	for p in BRILHOS_CRISTAL:
		_criar_brilho(p, soma, randf_range(0.30, 0.55), "cristal")
	for p in BRILHOS_PONTAS:
		_criar_brilho(p, soma, randf_range(0.30, 0.42), "ponta")
	# o "pisco" do disco: estrela grande na borda de cima
	_criar_brilho(CENTRO_SOL + Vector2(-0.62, -0.66) * RAIO_SOL, soma, 0.9, "disco")

	_cadente = Sprite2D.new()
	_cadente.name = "EstrelaCadente"
	_cadente.texture = ESTRELA
	_cadente.material = soma
	_cadente.visible = false
	add_child(_cadente)
	_criar_poeira_perto()
	_montar_camera()
	_definir_noite(0.0)


func _ready() -> void:
	get_viewport().size_changed.connect(ajustar)
	ajustar()


## Troca sol <-> lua. suave = cruzamento com clarão; senão é imediato.
func mostrar(modo: String, suave: bool = true) -> void:
	if modo == _modo:
		return
	_modo = modo
	var alvo := 1.0 if modo == "lua" else 0.0
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if not suave:
		_definir_noite(alvo)
		return
	_pisco = 1.0
	_tw = create_tween()
	_tw.tween_method(_definir_noite, _noite, alvo, TEMPO_TROCA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ───────────────────────────────────────────── montagem
func _criar_fundo(tex: Texture2D, mascara: Texture2D, cor: Color, fase: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_FUNDO
	mat.set_shader_parameter("mascara", mascara)
	mat.set_shader_parameter("usa_mascara", false)
	mat.set_shader_parameter("luz_lancada", LUZ_FUNDO)
	mat.set_shader_parameter("cor_energia", Vector3(cor.r, cor.g, cor.b))
	mat.set_shader_parameter("respiro", 0.0)   # quem respira é o nó inteiro
	mat.set_shader_parameter("ceu", 0.0)       # raios e disco são camadas
	mat.set_shader_parameter("fase", fase)
	s.material = mat
	add_child(s)
	return s


func _criar_raios(c: Vector2, r: float, alcance: float, lua: bool, cor: Color) -> ColorRect:
	var q := ColorRect.new()
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q.size = Vector2.ONE * r * alcance * 2.0
	q.position = c - q.size * 0.5
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_RAIOS
	mat.set_shader_parameter("lua", lua)
	mat.set_shader_parameter("cor", Vector3(cor.r, cor.g, cor.b))
	mat.set_shader_parameter("raio_disco", 1.0 / alcance)
	q.material = mat
	add_child(q)
	return q


func _criar_astro(tex: Array, dados: Dictionary, c: Vector2) -> Node2D:
	var astro := Node2D.new()
	astro.position = c
	astro.scale = Vector2.ONE / ASTRO_X    # texturas em 4x
	astro.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # reduzida sem serrilhar
	add_child(astro)
	var olho: Vector2 = dados["olho"]
	# halo (brilho em volta) por trás de tudo, numa textura pequena ampliada
	var halo := Sprite2D.new()
	halo.texture = tex[4]
	halo.scale = Vector2.ONE * ASTRO_X
	astro.add_child(halo)
	var esclera := Sprite2D.new()
	esclera.texture = tex[1]
	esclera.position = olho
	astro.add_child(esclera)
	var iris := Sprite2D.new()
	iris.texture = tex[2]
	iris.position = olho + dados["iris"]
	astro.add_child(iris)
	var baixo := Sprite2D.new()
	baixo.texture = tex[5]
	baixo.position = olho + Vector2(0.0, dados["baixo_y"])
	astro.add_child(baixo)
	var palpebra := Sprite2D.new()
	palpebra.texture = tex[3]
	palpebra.position = olho + Vector2(0.0, dados["palpebra_y"] + (tex[3] as Texture2D).get_height() * 0.5)
	astro.add_child(palpebra)
	var disco := Sprite2D.new()
	disco.texture = tex[0]
	astro.add_child(disco)
	var h: Dictionary = HUMORES["calmo"]
	_olhos.append({"astro": astro, "disco": disco, "halo": halo, "iris": iris, "palpebra": palpebra, "baixo": baixo,
		"iris_0": iris.position, "palpebra_0": palpebra.position, "baixo_0": baixo.position,
		"u": dados["u"], "ux": dados.get("ux", dados["u"]), "abre": dados["abre"], "sobe": dados["sobe"],
		"olhar": Vector2.ZERO, "alvo": Vector2.ZERO, "prox_olhar": randf_range(0.6, 1.5),
		"piscar": 0.0, "prox_piscar": randf_range(1.5, 3.5), "fase": -1.0, "dupla": false,
		"topo_v": h["topo"], "baixo_v": h["baixo"]})
	return astro


# ───────────────────────────────────────────── águias
## Águias planando ao fundo: sobem em térmicas (círculos que o vento leva),
## planam de uma térmica a outra, batem as asas de vez em quando e inclinam
## nas curvas. Cada uma tem tamanho (distância), rapidez, raio, vento e
## turbulência próprios, sorteados de novo a cada volta: nenhum voo se repete.
## Chegam de longe crescendo e vão embora subindo. Gritam de vez em quando
## (de noite o grito vem de mais longe). Contra o sol ou a lua viram silhueta.
func _criar_aguias() -> void:
	for i in N_AGUIAS:
		var s := Sprite2D.new()
		s.texture = AGUIA
		s.hframes = AGUIA_QUADROS
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		s.visible = false
		add_child(s)
		_aguias.append({"no": s, "espera": 1.5 + i * randf_range(3.0, 6.0)})


func _nova_aguia(a: Dictionary) -> void:
	var e := randf_range(0.15, 0.33)
	a["escala"] = e
	a["vel"] = lerpf(24.0, 46.0, (e - 0.15) / 0.18) * randf_range(0.85, 1.15)
	a["pos"] = Vector2(randf_range(CEU.position.x + 90.0, CEU.end.x - 90.0), randf_range(CEU.position.y + 30.0, CEU.end.y - 40.0))
	a["dir"] = randf() * TAU
	a["t"] = 0.0
	a["vida"] = randf_range(26.0, 50.0)
	a["bat"] = randf_range(0.8, 1.6)
	a["fase"] = randf()
	a["inclin"] = 0.0
	a["grito"] = randf_range(3.0, 12.0)
	a["ruido"] = randf() * 100.0
	a["vento"] = Vector2(randf_range(-9.0, 9.0), randf_range(-3.0, 2.0))
	a["modo"] = "termica" if randf() < 0.6 else "plana"
	_entrar_modo(a)
	(a["no"] as Sprite2D).visible = true


func _entrar_modo(a: Dictionary) -> void:
	if a["modo"] == "termica":
		a["raio"] = randf_range(40.0, 105.0) * (a["escala"] / 0.25)
		a["sentido"] = 1.0 if randf() < 0.5 else -1.0
		var lado := Vector2.RIGHT.rotated(a["dir"] + PI * 0.5 * a["sentido"])
		a["centro"] = a["pos"] + lado * a["raio"]
		a["t_modo"] = randf_range(6.0, 15.0)
	else:
		var alvo := Vector2.ZERO
		for i in 6:
			alvo = Vector2(randf_range(CEU.position.x + 60.0, CEU.end.x - 60.0), randf_range(CEU.position.y + 20.0, CEU.end.y - 30.0))
			if _noite > 0.5 and randf() < 0.35:
				alvo = CENTRO_LUA + Vector2(randf_range(-60.0, 60.0), randf_range(-30.0, 40.0))   # passa na frente da lua
			if alvo.distance_to(a["pos"]) > 220.0:
				break
		a["alvo"] = alvo
		a["t_modo"] = randf_range(5.0, 11.0)
		a["bat"] = maxf(a["bat"], randf_range(0.7, 1.6))


func _animar_aguias(delta: float) -> void:
	_grito_espera -= delta
	for a in _aguias:
		var s: Sprite2D = a["no"]
		if a["espera"] > 0.0:
			a["espera"] -= delta
			if a["espera"] <= 0.0:
				_nova_aguia(a)
			continue
		a["t"] += delta
		a["t_modo"] -= delta
		var t: float = a["t"]
		var v: float = a["vel"]
		var giro := 0.0
		if a["modo"] == "termica":
			a["centro"] += a["vento"] * delta
			var para_centro: Vector2 = a["centro"] - a["pos"]
			var r := maxf(para_centro.length(), 0.01)
			var tang := para_centro.rotated(-PI * 0.5 * a["sentido"]) / r
			var desejo := (tang + para_centro / r * clampf((r - a["raio"]) / a["raio"], -1.0, 1.0) * 0.8).angle()
			giro = angle_difference(a["dir"], desejo) * 1.8
			v *= 0.9
			# a térmica saiu do céu: plana de volta
			if not CEU.has_point(a["centro"]):
				a["t_modo"] = 0.0
		else:
			var desejo2: float = (a["alvo"] - a["pos"]).angle()
			giro = angle_difference(a["dir"], desejo2) * 0.9
			v *= 1.15
			if (a["pos"] as Vector2).distance_to(a["alvo"]) < 50.0:
				a["t_modo"] = 0.0
		if a["t_modo"] <= 0.0:
			a["modo"] = "plana" if a["modo"] == "termica" else "termica"
			_entrar_modo(a)
		# turbulência suave (cada águia com a sua)
		var rr: float = a["ruido"]
		giro += sin(t * 0.73 + rr) * 0.11 + sin(t * 1.91 + rr * 2.3) * 0.05
		giro = clampf(giro, -0.95, 0.95)
		a["dir"] += giro * delta
		a["inclin"] = lerpf(a["inclin"], giro * 0.6, 1.0 - exp(-delta * 2.5))
		a["pos"] += Vector2.RIGHT.rotated(a["dir"]) * v * delta + Vector2(0.0, sin(t * 1.3 + rr) * 3.0 * delta)

		# asas: batidas de vez em quando, senão planando
		if a["bat"] > 0.0:
			a["bat"] -= delta
			a["fase"] += delta * 2.3
			s.frame = 1 + int(a["fase"] * 10.0) % 10
		else:
			s.frame = 0
			if randf() < delta * 0.06:
				a["bat"] = randf_range(0.7, 1.5)

		# chega de longe e vai embora subindo (fica menor)
		var chega := clampf(t / 2.8, 0.0, 1.0)
		var vai := clampf((a["vida"] - t) / 3.0, 0.0, 1.0)
		var perto := chega * chega * (3.0 - 2.0 * chega) * vai
		if t > a["vida"]:
			s.visible = false
			a["espera"] = randf_range(2.0, 9.0)
			continue
		var esc: float = a["escala"] * (0.25 + 0.75 * perto)
		var inc: float = a["inclin"]
		s.position = a["pos"]
		s.rotation = a["dir"] + PI * 0.5
		s.scale = Vector2(esc * (1.0 - 0.35 * absf(inc)), esc)
		s.skew = inc * 0.45

		# luz: contra o sol/a lua vira silhueta; longe some na névoa do céu
		var astro := CENTRO_SOL.lerp(CENTRO_LUA, _noite)
		var raio_astro := lerpf(RAIO_SOL, RAIO_LUA, _noite)
		var contra := clampf(1.0 - ((a["pos"] as Vector2).distance_to(astro) - raio_astro * 0.9) / (raio_astro * 0.6), 0.0, 1.0)
		var dia := Color(1.0, 0.93, 0.84).lerp(Color(0.16, 0.10, 0.06), contra)
		var noite := Color(0.24, 0.28, 0.40).lerp(Color(0.03, 0.04, 0.08), contra)
		var cor := dia.lerp(noite, _noite)
		var nevoa: float = (1.0 - (a["escala"] - 0.15) / 0.18) * 0.35 * (1.0 - contra)
		cor = cor.lerp(Color(1.0, 0.78, 0.48).lerp(Color(0.22, 0.30, 0.48), _noite), nevoa)
		cor.a = perto
		s.modulate = cor

		# grito (um de cada vez, de tempos em tempos)
		a["grito"] -= delta
		if a["grito"] <= 0.0 and perto > 0.95:
			a["grito"] = randf_range(9.0, 22.0)
			if _grito_espera <= 0.0 and is_visible_in_tree():
				_grito_espera = 6.0
				var forca: float = (a["escala"] - 0.15) / 0.18
				var noite_som := _noite > 0.5
				Maquina.efeito(SOM_AGUIA_NOITE if noite_som else SOM_AGUIA,
					lerpf(-17.0, -8.0, forca) - (2.0 if noite_som else 0.0), randf_range(0.92, 1.08))


func _sprite_2x(tex: Texture2D, canto: Vector2, shader: Shader) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = canto
	s.scale = Vector2(0.5, 0.5)
	var mat := ShaderMaterial.new()
	mat.shader = shader
	s.material = mat
	add_child(s)
	return s


func _criar_particulas() -> void:
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	rampa.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var ponto := FundoVivo.brilho_redondo()

	# faíscas de energia subindo do diamante
	var f := CPUParticles2D.new()
	f.name = "FaiscasEnergia"
	f.amount = 34
	f.lifetime = 2.8
	f.preprocess = 2.8
	f.position = Vector2(508, 800)
	f.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	f.emission_sphere_radius = 60.0
	f.direction = Vector2(0, -1)
	f.spread = 40.0
	f.gravity = Vector2(0, -16)
	f.initial_velocity_min = 34.0
	f.initial_velocity_max = 100.0
	f.scale_amount_min = 0.35
	f.scale_amount_max = 0.95
	f.texture = ponto
	f.color_ramp = rampa
	f.material = soma
	add_child(f)
	_faiscas = f

	# poeira de areia atravessando devagar
	var p := CPUParticles2D.new()
	p.name = "Poeira"
	p.amount = 22
	p.lifetime = 11.0
	p.preprocess = 11.0
	p.position = Vector2(-20, 1000)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(20, 420)
	p.direction = Vector2(1, -0.12)
	p.spread = 10.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 16.0
	p.initial_velocity_max = 40.0
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.42
	p.texture = ponto
	p.color_ramp = rampa
	p.material = soma
	add_child(p)
	_poeira = p


func _criar_brilho(pos: Vector2, mat: Material, escala: float, tipo: String) -> void:
	var s := Sprite2D.new()
	s.texture = ESTRELA
	s.material = mat
	s.position = pos
	s.visible = false
	add_child(s)
	_brilhos.append({"no": s, "tipo": tipo, "escala": escala, "espera": randf_range(0.2, 3.0), "t": 0.0, "dur": 0.7})


func _criar_estrelas_ceu(mat: Material) -> void:
	var feitas := 0
	var tentativas := 0
	while feitas < N_ESTRELAS_CEU and tentativas < 400:
		tentativas += 1
		var p := Vector2(randf_range(40.0, 984.0), randf_range(40.0, 420.0))
		if p.distance_to(CENTRO_LUA) < RAIO_LUA + 60.0:
			continue
		var s := Sprite2D.new()
		s.texture = ESTRELA
		s.material = mat
		s.position = p
		s.scale = Vector2.ONE * randf_range(0.10, 0.22)
		s.rotation = randf() * 0.6
		_ceu_noite.add_child(s)
		_estrelas.append({"no": s, "w": randf_range(1.2, 3.4), "f": randf() * TAU})
		feitas += 1


## Cobre a tela inteira com a imagem (corta as sobras), como antes.
func ajustar() -> void:
	_aplicar_camera()


func _aplicar_camera() -> void:
	var tela := get_viewport_rect().size
	var esc := maxf(tela.x / IMG.x, tela.y / IMG.y)
	# sem zoom: só cobre a tela (âncora no alto: o sol não entra no placar)
	scale = Vector2.ONE * esc
	position = Vector2((tela.x - IMG.x * esc) * 0.5, minf(0.0, (tela.y - IMG.y * esc) * 0.5))
	var px := Vector2(1.0 / (IMG.x * esc), 1.0 / (IMG.y * esc))
	for fundo: Sprite2D in [_fundo_sol, _fundo_lua]:
		(fundo.material as ShaderMaterial).set_shader_parameter("px_uv", px)
	if is_inside_tree():
		var g := get_global_transform()
		material_alvo.set_shader_parameter("fundo_origem", g.origin)
		material_alvo.set_shader_parameter("fundo_tam", IMG * g.get_scale())


# ───────────────────────────────────────────── câmera 3D
## As camadas de cima andam com a câmera, cada uma na sua distância: o céu
## (raios, sol/lua, águias, estrelas, brilhos das pontas) como o céu da foto e
## o cristal (diamante, trincas, cacos) como o cristal da foto.
func _montar_camera() -> void:
	_prof = PROFUNDIDADE.get_image() if PROFUNDIDADE != null else null
	if _prof != null and _prof.is_compressed():
		_prof.decompress()
	for fundo: Sprite2D in [_fundo_sol, _fundo_lua]:
		var mf := fundo.material as ShaderMaterial
		mf.set_shader_parameter("inv_z_longe", 1.0 / Z_LONGE)
		mf.set_shader_parameter("inv_z_perto", 1.0 / Z_PERTO)
		mf.set_shader_parameter("horizonte_uv", HORIZONTE / IMG.y)
		mf.set_shader_parameter("chao1_uv", CHAO_1 / IMG.y)
	material_alvo = ShaderMaterial.new()
	material_alvo.shader = SHADER_ALVO
	material_alvo.set_shader_parameter("profundidade", PROFUNDIDADE)
	material_alvo.set_shader_parameter("inv_z_longe", 1.0 / Z_LONGE)
	material_alvo.set_shader_parameter("inv_z_perto", 1.0 / Z_PERTO)

	var ceu: Array[Node] = [_raios_sol, _raios_lua, _disco_sol, _disco_lua]
	for a in _aguias:
		ceu.append(a["no"])
	ceu.append(_ceu_noite)
	var perto: Array[Node] = [_cristal, _morto, _fx_n, _fx_s]
	for b in _brilhos:
		(perto if b["tipo"] == "cristal" else ceu).append(b["no"])
	ceu.append(_cadente)
	_camada_ceu = Node2D.new()
	_camada_ceu.name = "CamadaCeu"
	add_child(_camada_ceu)
	move_child(_camada_ceu, 2)            # logo depois das duas imagens
	_camada_perto = Node2D.new()
	_camada_perto.name = "CamadaCristal"
	add_child(_camada_perto)
	move_child(_camada_perto, 3)
	for no in ceu:
		remove_child(no)
		_camada_ceu.add_child(no)
	for no in perto:
		remove_child(no)
		_camada_perto.add_child(no)
	# o brilho do cristal, as trincas e as faíscas ficam na frente do plano
	# do cristal (e atrás dos brasões que estão mais perto que ele)
	remove_child(_faiscas)
	_camada_perto.add_child(_faiscas)
	_camada_perto.z_as_relative = false
	_camada_perto.z_index = z_desenho(Z_CRISTAL) + 1
	# trincas dos cristais das pontas: andam como os obeliscos
	_camada_obeliscos = Node2D.new()
	_camada_obeliscos.name = "CamadaObeliscos"
	_camada_obeliscos.z_as_relative = false
	_camada_obeliscos.z_index = z_desenho(Z_OBELISCO) + 2
	_camada_obeliscos.draw.connect(_desenhar_pontas)
	add_child(_camada_obeliscos)
	for i in 2:
		_pontas.append({"danos": 0, "quebrado": false, "volta": 0.0, "refaz": -1.0, "morte": 0.0, "tremor": 0.0, "trincas": []})

func _animar_camera(delta: float) -> void:
	var alvo := Vector2.ZERO
	if mira != Vector2.INF:
		var meio := get_viewport_rect().size * 0.5
		alvo = ((mira - meio) / meio).clamp(Vector2(-1, -1), Vector2(1, 1))
	_olhar = _olhar.lerp(alvo, 1.0 - exp(-delta * CAMERA_SUAVE))
	# na vertical anda menos (o céu de cima fica sob o placar)
	camera = _olhar * CAMERA_PASSO * Vector2(1.0, 0.7)
	var esc := scale.x
	_camada_ceu.position = camera * (1.0 - 1.0 / Z_LONGE) / esc
	_camada_perto.position = camera * (1.0 - 1.0 / Z_CRISTAL) / esc
	_camada_obeliscos.position = camera * (1.0 - 1.0 / Z_OBELISCO) / esc
	for pl in _planos:
		var pos: Vector2 = pl["canto"] + camera * (1.0 - 1.0 / float(pl["z"])) / esc
		(pl["no"] as Node2D).position = pos
		if pl["lua"] != null:
			(pl["lua"] as Node2D).position = pos
	_feixes.camera_local = camera / esc
	_poeira_perto.position = Vector2(-60.0, 300.0) + camera * (1.0 - 1.0 / 0.45) / esc
	for fundo: Sprite2D in [_fundo_sol, _fundo_lua]:
		if fundo.visible:
			(fundo.material as ShaderMaterial).set_shader_parameter("olhar", camera)
	material_alvo.set_shader_parameter("olhar", camera)


## Ponto de fuga (pé das pirâmides) na tela.
func ponto_de_fuga() -> Vector2:
	return get_global_transform() * Vector2(IMG.x * 0.5, HORIZONTE)


## y (tela) do chão a Z = 1: um brasão à distância z não desce abaixo de
## fuga.y + (chao_1 - fuga.y) / z (senão estaria enterrado).
func chao_1() -> float:
	return (get_global_transform() * Vector2(0.0, CHAO_1)).y


## Quanto uma coisa à distância z anda na tela agora (px).
func paralaxe(z: float) -> Vector2:
	return camera * (1.0 - 1.0 / maxf(z, 0.05))


## 1/Z do fundo no ponto p da imagem (px da imagem).
func _inv_z_local(p: Vector2) -> float:
	if _prof == null:
		return 1.0 / Z_LONGE
	var w := _prof.get_width()
	var h := _prof.get_height()
	var x := clampi(int(p.x / IMG.x * w), 0, w - 1)
	var y := clampi(int(p.y / IMG.y * h), 0, h - 1)
	return lerpf(1.0 / Z_LONGE, 1.0 / Z_PERTO, _prof.get_pixel(x, y).r)


## O ponto da imagem que aparece agora no ponto p da tela (desfaz a câmera).
func ponto_da_imagem(p_global: Vector2) -> Vector2:
	var p: Vector2 = get_global_transform().affine_inverse() * p_global
	var esc := maxf(scale.x, 0.001)
	var inv := _inv_z_local(p)
	return p - camera * (1.0 - _inv_z_local(p - camera * (1.0 - inv) / esc)) / esc


## 1/Z do que aparece no ponto p da tela (para saber se um brasão está atrás).
func inv_z_na_tela(p_global: Vector2) -> float:
	return _inv_z_local(ponto_da_imagem(p_global))


## Quanto um ponto do chão (px da imagem) anda agora, em px da imagem
## (furos de bala e poeira grudados no chão).
func deslocamento_no_chao(p: Vector2) -> Vector2:
	return camera * (1.0 - _inv_z_local(p)) / maxf(scale.x, 0.001)


# ───────────────────────────────────────────── animação
func _definir_noite(v: float) -> void:
	_noite = clampf(v, 0.0, 1.0)
	var dia := 1.0 - _noite
	_fundo_lua.visible = _noite > 0.001
	_fundo_lua.modulate.a = _noite
	_fundo_sol.visible = _noite < 0.999
	for par in [[_raios_sol, dia], [_raios_lua, _noite], [_disco_sol, dia], [_disco_lua, _noite]]:
		var no: CanvasItem = par[0]
		no.visible = par[1] > 0.001
		no.modulate.a = par[1]
	(_cristal.material as ShaderMaterial).set_shader_parameter("noite", _noite)
	_mat_planos.set_shader_parameter("noite", _noite)
	for pl in _planos:
		if pl["lua"] != null:
			var lua: Sprite2D = pl["lua"]
			lua.visible = _noite > 0.001
			lua.modulate.a = _noite
			(pl["no"] as Sprite2D).visible = _noite < 0.999
	_feixes.noite = _noite
	# névoa da distância nos brasões: areia quente de dia, azul-escuro de noite
	var nevoa := Color(0.96, 0.74, 0.46).lerp(Color(0.16, 0.18, 0.30), _noite)
	material_alvo.set_shader_parameter("cor_nevoa", Vector3(nevoa.r, nevoa.g, nevoa.b))
	_ceu_noite.visible = _noite > 0.01
	_faiscas.color = Color(1.0, 0.80, 0.42).lerp(Color(1.0, 0.42, 0.40), _noite)
	_poeira.color = Color(1.0, 0.86, 0.6, 0.55).lerp(Color(0.75, 0.85, 1.0, 0.45), _noite)


func _process(delta: float) -> void:
	_t += delta
	_animar_camera(delta)
	var som := Maquina.pulso_vivo()
	if som.y > 0.55 and _onda > 0.62:
		_onda = 0.0
	_onda = minf(_onda + delta * 0.85, 9.0)

	# "pisco" do disco de tempos em tempos (e o clarão da troca)
	_proximo_pisco -= delta
	if _proximo_pisco <= 0.0:
		_proximo_pisco = randf_range(5.0, 9.0)
		_pisco = maxf(_pisco, 0.45)
	_pisco = move_toward(_pisco, 0.0, delta * 1.1)

	_animar_nuvens(delta)
	for fundo: Sprite2D in [_fundo_sol, _fundo_lua]:
		if fundo.visible:
			var mf := fundo.material as ShaderMaterial
			mf.set_shader_parameter("grave", som.x)
			mf.set_shader_parameter("batida", som.y)
			mf.set_shader_parameter("onda", _onda)
			mf.set_shader_parameter("nuvens", _nuvens)
			mf.set_shader_parameter("fase_nuvens", _fase_nuvens)
	_mat_planos.set_shader_parameter("grave", som.x)
	_mat_planos.set_shader_parameter("batida", som.y)
	_feixes.grave = som.x
	_feixes.batida = som.y
	_feixes.carga = carga
	for no: CanvasItem in [_raios_sol, _raios_lua]:
		if no.visible:
			var m := no.material as ShaderMaterial
			m.set_shader_parameter("grave", som.x)
			m.set_shader_parameter("batida", som.y)
			m.set_shader_parameter("pisco", _pisco)
	# o astro clareia no "pisco" e com a batida (só a cor, sem shader)
	var luz := 1.0 + 0.30 * _pisco + 0.06 * som.y
	for o in _olhos:
		(o["disco"] as Sprite2D).self_modulate = Color(luz, luz, luz, 1.0)
		(o["halo"] as Sprite2D).self_modulate = Color(luz, luz, luz, 1.0)
	var m2 := _cristal.material as ShaderMaterial
	m2.set_shader_parameter("grave", som.x)
	m2.set_shader_parameter("batida", som.y)
	_faiscas.speed_scale = 1.0 + som.y * 1.3

	_animar_olhos(delta)
	_animar_aguias(delta)
	_animar_brilhos(delta)
	_atualizar_tiros_fundo(delta)
	if _noite > 0.01:
		_animar_ceu(delta)


## O jogo conta ao sol e à lua o que aconteceu, e eles reagem:
##   "acerto" (valor = combo), "erro" (pos = onde errou), "astro_errado"
##   (pos), "combo_quebrou", "tempo_final", "fim", "recarga", "inicio".
## Humor de base: calmo; feliz com combo 3+, radiante com 6+; atento (segue a
## mira) com muitos erros seguidos ou nos últimos 10 s; sonolento no fim.
## Por cima, reações curtas: apertinho feliz no acerto, bravo no astro
## errado, uma espiada onde errou, surpresa quando o cristal quebra.
func evento(nome: String, pos_global: Vector2 = Vector2.INF, valor: int = 0) -> void:
	match nome:
		"acerto":
			_combo = valor
			_erros_recentes = maxf(0.0, _erros_recentes - 0.6)
			if _combo < 3:
				_reagir("feliz", 0.5)
			_ouro_varre = 0.0
			_ouro_pulso = 0.35
		"erro":
			_combo = 0
			_erros_recentes += 1.0
			_espiar_ponto(pos_global, 0.7)
		"astro_errado":
			_combo = 0
			_erros_recentes += 1.0
			_reagir("bravo", 1.4)
			_espiar_ponto(pos_global, 0.9)
			_ouro_pulso = -0.45
		"combo_quebrou":
			_combo = 0
		"tempo_final":
			_tempo_final = true
		"fim":
			_fim = true
			_reacao = ""
		"inicio":
			_fim = false
			_tempo_final = false
			_combo = 0
			_erros_recentes = 0.0
		"recarga":
			# olha para a arma (embaixo) num instante
			_espiar_ponto(get_viewport().get_visible_rect().size * Vector2(0.5, 1.0), 0.5)


## As pontas de ouro acompanham o jogo: combo deixa o ouro quente e vivo,
## erros seguidos o apagam um pouco, cada acerto passa um reflexo pelas três
## pirâmides e acertar o astro errado dá uma apagada rápida.
func _animar_ouro(delta: float) -> void:
	var alvo := 0.0
	if _fim:
		alvo = -0.2
	elif _erros_recentes >= 2.5:
		alvo = -0.35
	elif _combo >= 6:
		alvo = 0.7
	elif _combo >= 3:
		alvo = 0.35
	_ouro_brilho = lerpf(_ouro_brilho, alvo, 1.0 - exp(-delta * 3.0))
	_ouro_pulso = move_toward(_ouro_pulso, 0.0, delta * 0.9)
	if _ouro_varre >= 0.0:
		_ouro_varre += delta / 0.8
		if _ouro_varre > 1.0:
			_ouro_varre = -1.0
	_ouro("ouro_brilho", clampf(_ouro_brilho + _ouro_pulso, -0.6, 1.0))
	_ouro("ouro_varre", _ouro_varre)


## Parâmetro do ouro nos dois fundos (o sol e a lua cruzam pela opacidade).
func _ouro(nome: StringName, valor: Variant) -> void:
	(_fundo_sol.material as ShaderMaterial).set_shader_parameter(nome, valor)
	(_fundo_lua.material as ShaderMaterial).set_shader_parameter(nome, valor)


func _reagir(nome: String, dur: float) -> void:
	_reacao = nome
	_reacao_t = dur


func _espiar_ponto(p: Vector2, dur: float) -> void:
	if p == Vector2.INF:
		return
	_espiar = p
	_espiar_t = dur


func _humor_base() -> String:
	if _fim:
		return "sono"
	if _erros_recentes >= 2.5:
		return "atento"
	if _combo >= 6:
		return "radiante"
	if _combo >= 3:
		return "feliz"
	if _tempo_final:
		return "atento"
	return "calmo"


## Para onde a íris olha (offset em px da textura) para ver um ponto da tela.
func _olhar_para(o: Dictionary, p_tela: Vector2, alcance: float) -> Vector2:
	var centro: Vector2 = (o["astro"] as Node2D).get_global_transform_with_canvas().origin
	var d := p_tela - centro
	var u: float = o["u"]
	var ux: float = o["ux"]   # o olho é comprido: na horizontal a íris anda mais
	return Vector2(clampf(d.x / 320.0, -1.0, 1.0) * 0.36 * alcance * ux, clampf(d.y / 420.0, -1.0, 1.0) * 0.05 * u)


## Olho vivo: a íris passeia (calma desliza, atenta salta e segue a mira), as
## duas pálpebras vão para o humor do momento e a de cima pisca de tempos em
## tempos, às vezes duas vezes.
func _animar_olhos(delta: float) -> void:
	_erros_recentes = maxf(0.0, _erros_recentes - delta / 3.5)
	if _reacao_t > 0.0:
		_reacao_t -= delta
		if _reacao_t <= 0.0:
			_reacao = ""
	if _espiar_t > 0.0:
		_espiar_t -= delta
	var h: Dictionary = HUMORES[_reacao if _reacao != "" else _humor_base()]
	_animar_ouro(delta)
	for i in _olhos.size():
		var o: Dictionary = _olhos[i]
		var visivel: bool = (_disco_sol if i == 0 else _disco_lua).visible
		if not visivel:
			continue
		var u: float = o["u"]
		var alcance: float = h["alcance"]
		if _espiar_t > 0.0:
			o["alvo"] = _olhar_para(o, _espiar, 1.0)
		elif h["mira"]:
			o["alvo"] = _olhar_para(o, MiraGlobal.pos, alcance)
		else:
			o["prox_olhar"] -= delta
			if o["prox_olhar"] <= 0.0:
				o["prox_olhar"] = randf_range(1.2, 3.0)
				if randf() < 0.3:
					# de vez em quando dá uma olhada na mira do jogador
					o["alvo"] = _olhar_para(o, MiraGlobal.pos, alcance)
				else:
					var escolhas := [Vector2(0, 0), Vector2(-0.30, 0.0), Vector2(0.30, 0.0), Vector2(-0.22, -0.04),
						Vector2(0.22, -0.04), Vector2(-0.18, 0.04), Vector2(0.18, 0.04), Vector2(0.0, -0.04)]
					var e: Vector2 = escolhas[randi() % escolhas.size()]
					o["alvo"] = Vector2(e.x * alcance * float(o["ux"]) * 1.2, e.y * u)
		var olhar: Vector2 = o["olhar"]
		olhar = olhar.lerp(o["alvo"] + Vector2(0.0, float(h["iris_y"]) * u), 1.0 - exp(-delta * float(h["vel"])))
		o["olhar"] = olhar

		# pálpebras indo para o humor (sem tranco)
		var k := 1.0 - exp(-delta * 7.0)
		o["topo_v"] = lerpf(o["topo_v"], h["topo"], k)
		o["baixo_v"] = lerpf(o["baixo_v"], h["baixo"], k)

		var p: float = o["piscar"]
		if o["fase"] < 0.0:
			o["prox_piscar"] -= delta
			if o["prox_piscar"] <= 0.0:
				o["fase"] = 0.0
		else:
			o["fase"] += delta
			var f: float = o["fase"]
			# fecha em 0,09 s, fica 0,06 s, abre em 0,16 s (piscada calma)
			if f < 0.09:
				p = f / 0.09
			elif f < 0.15:
				p = 1.0
			elif f < 0.31:
				p = 1.0 - (f - 0.15) / 0.16
			else:
				p = 0.0
				o["fase"] = -1.0
				var faixa: Vector2 = h["piscar"]
				if not o["dupla"] and randf() < 0.25:
					o["dupla"] = true
					o["prox_piscar"] = 0.12
				else:
					o["dupla"] = false
					o["prox_piscar"] = randf_range(faixa.x, faixa.y)
		o["piscar"] = p
		(o["iris"] as Sprite2D).position = o["iris_0"] + olhar
		var fecha: float = p * p * (3.0 - 2.0 * p)
		var topo: float = lerpf(o["topo_v"], 1.0, fecha)
		(o["palpebra"] as Sprite2D).position = o["palpebra_0"] + Vector2(0.0, topo * (o["abre"] + 0.03 * u))
		(o["baixo"] as Sprite2D).position = o["baixo_0"] - Vector2(0.0, float(o["baixo_v"]) * float(o["sobe"]))


func _animar_brilhos(delta: float) -> void:
	for b in _brilhos:
		var s: Sprite2D = b["no"]
		if b["espera"] > 0.0:
			b["espera"] -= delta
			if b["espera"] <= 0.0 and b["tipo"] == "cristal" and _energia < 0.6:
				b["espera"] = randf_range(0.5, 1.5)
			elif b["espera"] <= 0.0 and b["tipo"] == "ponta" and _ponta_apagada(s.position):
				b["espera"] = randf_range(0.5, 1.5)   # ponta de ouro apagada não cintila
			elif b["espera"] <= 0.0:
				b["t"] = 0.0
				b["dur"] = randf_range(0.55, 0.95)
				s.rotation = randf_range(-0.3, 0.3)
				s.visible = true
			continue
		b["t"] += delta
		var k: float = b["t"] / b["dur"]
		if k >= 1.0:
			s.visible = false
			b["espera"] = randf_range(1.0, 4.0) if b["tipo"] != "disco" else randf_range(4.0, 8.0)
			continue
		var env := sin(PI * k)
		env *= env
		var cor: Color
		match b["tipo"]:
			"cristal":
				cor = Color.from_hsv(fmod(_t * 0.13 + s.position.y * 0.004, 1.0), 0.35, 1.0).lerp(Color(1.0, 0.40, 0.52), _noite)
			"ponta":
				cor = Color(1.0, 0.90, 0.62).lerp(Color(0.74, 0.88, 1.0), _noite)
			_:
				cor = Color(1.0, 0.95, 0.75).lerp(Color(0.85, 0.93, 1.0), _noite)
				s.position = (CENTRO_SOL + Vector2(-0.62, -0.66) * RAIO_SOL).lerp(CENTRO_LUA + Vector2(-0.62, -0.66) * RAIO_LUA, _noite)
		cor.a = env
		s.modulate = cor
		s.scale = Vector2.ONE * b["escala"] * (0.35 + 0.65 * env)
		s.rotation += delta * 0.6


## A ponta de ouro mais perto do ponto p (px da imagem) está apagada?
func _ponta_apagada(p: Vector2) -> bool:
	var i := 0 if p.x < 380.0 else (2 if p.x > 640.0 else 1)
	return _pontas_acesas[i] < 0.5


func _animar_ceu(delta: float) -> void:
	for e in _estrelas:
		var s: Sprite2D = e["no"]
		var c := 0.5 + 0.5 * sin(_t * e["w"] + e["f"])
		s.modulate.a = _noite * (0.25 + 0.75 * c * c * c)

	# estrela cadente de vez em quando
	if _cadente_t < 0.0:
		_cadente_em -= delta
		if _cadente_em <= 0.0:
			_cadente_t = 0.0
			_cadente_de = Vector2(randf_range(120.0, 900.0), randf_range(60.0, 200.0))
			var dir := Vector2(-1.0 if _cadente_de.x > 512.0 else 1.0, 0.45).normalized()
			_cadente_para = _cadente_de + dir * randf_range(260.0, 380.0)
			_cadente.rotation = dir.angle()
			_cadente.visible = true
		return
	_cadente_t += delta
	var k := _cadente_t / 0.85
	if k >= 1.0:
		_cadente.visible = false
		_cadente_t = -1.0
		_cadente_em = randf_range(7.0, 14.0)
		return
	_cadente.position = _cadente_de.lerp(_cadente_para, k)
	_cadente.scale = Vector2(1.6 + 1.2 * sin(PI * k), 0.10)
	_cadente.modulate = Color(0.85, 0.93, 1.0, _noite * sin(PI * k))


# ───────────────────────────────────────────── tiros no fundo
## O que há no ponto (px da imagem do fundo): "cristal", "ouro", "pedra",
## "areia" ou "ceu".
func material_em(p: Vector2) -> String:
	if Geometry2D.is_point_in_polygon(p, POLI_CRISTAL):
		return "cristal"
	for i in 2:
		if Geometry2D.is_point_in_polygon(p, PackedVector2Array(POLI_PONTAS[i])):
			return "cristal_esq" if i == 0 else "cristal_dir"
	for tri: PackedVector2Array in OURO:
		if Geometry2D.is_point_in_polygon(p, tri):
			return "ouro"
	for tri2: PackedVector2Array in PIRAMIDES:
		if Geometry2D.is_point_in_polygon(p, tri2):
			return "pedra"
	if em_plano(p):
		return "pedra"      # coluna, Anúbis, obelisco, pedestal: tudo pedra
	if p.y > 700.0:
		if (p - Vector2(510, 1180)).length() < 300.0:
			return "pedra"  # degraus do altar
		return "areia"
	return "ceu"


## O ponto (px da imagem) é de uma coisa em pé (um plano recortado) e não do
## chão? (o mapa de profundidade tem o Z de cada recorte; o chão, o da altura)
func em_plano(p: Vector2) -> bool:
	if p.y <= HORIZONTE or _prof == null:
		return false
	var chao := clampf((p.y - HORIZONTE) / (CHAO_1 - HORIZONTE), 1.0 / Z_LONGE, 1.0 / Z_PERTO)
	return absf(_inv_z_local(p) - chao) > 0.04


## O tiro pegou o chão (deixa furo de bala) e não uma coisa em pé?
func no_chao(pos_global: Vector2) -> bool:
	return not em_plano(ponto_da_imagem(pos_global))


## Tiro que não pegou alvo: cada lugar responde do seu jeito. Devolve o
## material (a fase decide se ainda deixa a marca de tiro).
func impacto(pos_global: Vector2) -> String:
	var p: Vector2 = ponto_da_imagem(pos_global)
	var mat := material_em(p)
	match mat:
		"cristal":
			_ferir_cristal(p)
			carga = 0.0
		"cristal_esq", "cristal_dir":
			_ferir_ponta(0 if mat == "cristal_esq" else 1, p)
			carga = maxf(0.0, carga - 0.5)
		"ouro":
			_tocar_ouro(p)
		"pedra":
			_estilhacar(p, Color(0.78, 0.62, 0.42).lerp(Color(0.42, 0.40, 0.48), _noite), 7, 5)
			Maquina.efeito(SOM_PEDRA, -7.0, randf_range(0.9, 1.15))
		"areia":
			_estilhacar(p, Color(0.92, 0.72, 0.42).lerp(Color(0.50, 0.48, 0.56), _noite), 0, 9)
			Maquina.efeito(SOM_AREIA, -6.0, randf_range(0.9, 1.1))
	return mat


# ───────────────────────────────────────────── planos 3D
func z_desenho(z: float) -> int:
	# a mesma conta dos brasões (scripts/deserto.gd): mais perto, por cima
	return 100 + clampi(int(round(60.0 / maxf(z, 0.3))), 0, 190)


## Um sprite por recorte (folha do dia como textura; a da noite e o brilho no
## material), cada um na ordem de desenho da sua distância.
func _criar_planos() -> void:
	_mat_planos = ShaderMaterial.new()
	_mat_planos.shader = SHADER_PLANO
	_mat_planos.set_shader_parameter("folha_lua", PLANOS_LUA)
	_mat_planos.set_shader_parameter("brilho", PLANOS_BRILHO)
	for d: Dictionary in EgitoPlanos.PLANOS:
		var nome := str(d["nome"])
		# só o cristal e os obeliscos brilham e apagam (shader); colunas e
		# estátuas são imagem pura: a do sol e a da lua por cima, cruzando
		# (mais leve para a placa)
		var com_luz := nome in PLANOS_COM_LUZ
		var s := _sprite_plano(d, PLANOS_SOL)
		s.name = "Plano_" + nome
		s.material = _mat_planos if com_luz else null
		var lua: Sprite2D = null
		if not com_luz:
			lua = _sprite_plano(d, PLANOS_LUA)
			lua.name = "Plano_" + nome + "_lua"
			lua.visible = false
		var lado := 0 if nome.ends_with("_esq") else (1 if nome.ends_with("_dir") else -1)
		_planos.append({"no": s, "lua": lua, "canto": d["canto"], "z": float(d["z"]), "lado": lado})
		match nome:
			"cristal":
				_plano_cristal = s
			"obelisco_esq":
				_plano_obeliscos[0] = s
			"obelisco_dir":
				_plano_obeliscos[1] = s


func _sprite_plano(d: Dictionary, folha: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = folha
	s.centered = false
	s.region_enabled = true
	s.region_rect = d["folha"]
	s.position = d["canto"]
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.z_as_relative = false
	s.z_index = z_desenho(float(d["z"]))
	add_child(s)
	return s


func _criar_feixes() -> void:
	_feixes = EgitoFeixes.new()
	_feixes.z_as_relative = false
	_feixes.z_index = z_desenho(Z_OBELISCO) + 3
	add_child(_feixes)


## Poeira bem perto da câmera (grãos grandes e desfocados que passam na frente
## de tudo e andam muito quando a câmera anda: dá a noção de profundidade).
func _criar_poeira_perto() -> void:
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.25, 0.8, 1.0])
	rampa.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
	var p := CPUParticles2D.new()
	p.name = "PoeiraPerto"
	p.amount = 9
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(30, 560)
	p.direction = Vector2(1, -0.08)
	p.spread = 12.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 140.0
	p.scale_amount_min = 0.9
	p.scale_amount_max = 2.2
	p.texture = FundoVivo.brilho_redondo()
	p.color_ramp = rampa
	p.color = Color(1.0, 0.88, 0.66, 0.5)
	p.z_as_relative = false
	p.z_index = 330
	add_child(p)
	_poeira_perto = p


## Nuvens com o humor do astro: feliz/radiante agitadas, calmo devagar, tenso
## (atento, bravo) e com sono quase paradas.
func _animar_nuvens(delta: float) -> void:
	var humor := _reacao if _reacao != "" else _humor_base()
	var alvo := 0.35
	match humor:
		"radiante":
			alvo = 1.0
		"feliz":
			alvo = 0.8
		"surpreso":
			alvo = 0.6
		"atento":
			alvo = 0.12
		"bravo":
			alvo = 0.08
		"sono":
			alvo = 0.05
	_nuvens = lerpf(_nuvens, alvo, 1.0 - exp(-delta * 0.8))
	_fase_nuvens += delta * (0.25 + 2.4 * _nuvens)
	_poeira_perto.color = Color(1.0, 0.88, 0.66, 0.5).lerp(Color(0.70, 0.78, 1.0, 0.4), _noite)


# ───────────────────────────────────────────── cristais das pontas
func _ferir_ponta(i: int, p: Vector2) -> void:
	var pt: Dictionary = _pontas[i]
	var cor := Color(1.0, 0.55, 0.9).lerp(Color(1.0, 0.25, 0.35), _noite)
	if pt["quebrado"]:
		_soltar_cacos(p, 3, Color(0.35, 0.35, 0.45), 140.0)
		return
	pt["danos"] += 1
	pt["tremor"] = 1.0
	var poli := PackedVector2Array(POLI_PONTAS[i])
	for g in randi_range(2, 3):
		var linha := PackedVector2Array([p])
		var ang := randf() * TAU
		for k in randi_range(3, 5):
			ang += randf_range(-0.7, 0.7)
			var q: Vector2 = linha[linha.size() - 1] + Vector2.RIGHT.rotated(ang) * randf_range(5.0, 11.0)
			if not Geometry2D.is_point_in_polygon(q, poli):
				break
			linha.append(q)
		if linha.size() > 1:
			(pt["trincas"] as Array).append(linha)
	_soltar_cacos(p, 6, cor, 200.0)
	_claroes.append({"pos": p, "t": 0.0, "vida": 0.3, "raio": 50.0, "cor": cor})
	if pt["danos"] >= TIROS_PONTA:
		pt["quebrado"] = true
		pt["volta"] = PONTA_VOLTA
		var centro: Vector2 = PONTAS_OBELISCO[i]
		for k2 in 16:
			_soltar_cacos(centro + Vector2(randf_range(-10, 10), randf_range(-30, 30)), 1, cor if k2 % 2 else Color(0.4, 0.4, 0.5), 380.0)
		_claroes.append({"pos": centro, "t": 0.0, "vida": 0.5, "raio": 160.0, "cor": cor})
		_claroes.append({"pos": centro, "t": 0.0, "vida": 0.6, "raio": 80.0, "cor": Color.WHITE})
		_reagir("surpreso", 0.6)
		Maquina.efeito(SOM_QUEBRA, -6.0, 1.25)
	else:
		Maquina.efeito(SOM_TRINCA, -6.0, randf_range(1.1, 1.3))
	_camada_obeliscos.queue_redraw()


func _atualizar_pontas(delta: float) -> void:
	var sujo := false
	for i in 2:
		var pt: Dictionary = _pontas[i]
		if pt["tremor"] > 0.0:
			pt["tremor"] = maxf(0.0, pt["tremor"] - delta * 2.0)
			sujo = true
		if pt["quebrado"]:
			pt["morte"] = minf(1.0, pt["morte"] + delta * 4.0)
			pt["volta"] -= delta
			if pt["volta"] <= 0.0 and not _cristal_quebrado:
				pt["quebrado"] = false
				pt["danos"] = 0
				pt["refaz"] = 0.0
				Maquina.efeito(SOM_VOLTA, -8.0, 1.2)
			sujo = true
		elif pt["refaz"] >= 0.0:
			pt["refaz"] += delta / 1.6
			pt["morte"] = 1.0 - pt["refaz"]
			if pt["refaz"] >= 1.0:
				pt["refaz"] = -1.0
				pt["morte"] = 0.0
				(pt["trincas"] as Array).clear()
			sujo = true
		elif pt["danos"] > 0:
			# trincado: pisca um pouco (a energia vaza)
			pt["morte"] = (0.10 * float(pt["danos"]) / TIROS_PONTA + 0.5 * pt["tremor"]) * randf()
			sujo = true
		else:
			pt["morte"] = 0.0
	if sujo or _pontas_sujo:
		_camada_obeliscos.queue_redraw()
	_pontas_sujo = sujo

var _pontas_sujo := false
const PONTAS_OBELISCO := [Vector2(209, 800), Vector2(812, 800)]


func _desenhar_pontas() -> void:
	for i in 2:
		var pt: Dictionary = _pontas[i]
		var trincas: Array = pt["trincas"]
		if trincas.is_empty():
			continue
		var a: float = 1.0 if pt["refaz"] < 0.0 else 1.0 - float(pt["refaz"])
		for linha: PackedVector2Array in trincas:
			for k in range(linha.size() - 1):
				Pincel.linha(_camada_obeliscos, linha[k], linha[k + 1], Color(0.06, 0.02, 0.08, 0.9 * a), 1.2)


## Descarga do cristal (deserto.gd): raios das pontas acesas até os alvos.
func disparar_descarga(alvos_global: Array) -> void:
	var inv := get_global_transform().affine_inverse()
	var locais: Array = []
	for g: Vector2 in alvos_global:
		locais.append(inv * g)
	_feixes.descarga(locais)
	var cor := Color(1.0, 0.85, 0.5).lerp(Color(1.0, 0.35, 0.45), _noite)
	_claroes.append({"pos": Vector2(508, 700), "t": 0.0, "vida": 0.5, "raio": 380.0, "cor": cor})
	_onda = 0.0
	carga = 0.0
	_reagir("radiante", 1.4)
	Maquina.efeito(SOM_VOLTA, -2.0, 1.75)
	Maquina.efeito(SOM_QUEBRA, -10.0, 1.9)


## A descarga pode sair? (cristal do meio inteiro)
func cristal_inteiro() -> bool:
	return not _cristal_quebrado and _cristal_refaz < 0.0


func _criar_cristal_vivo() -> void:
	_morto = Node2D.new()
	_morto.name = "CristalQuebrado"
	_morto.position = CAIXA_MORTO.position
	_morto.scale = Vector2.ONE * 0.5          # texturas em 2x
	_morto.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_morto.visible = false
	add_child(_morto)
	for tex: Texture2D in [CRISTAL_MORTO_SOL, CRISTAL_MORTO_LUA]:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		_morto.add_child(s)

	_fx_n = Node2D.new()
	_fx_n.name = "FxTirosFundo"
	_fx_n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_fx_n.draw.connect(_desenhar_fx_n)
	add_child(_fx_n)
	_fx_s = Node2D.new()
	_fx_s.name = "LuzTirosFundo"
	_fx_s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fx_s.material = soma
	_fx_s.draw.connect(_desenhar_fx_s)
	add_child(_fx_s)


func _ferir_cristal(p: Vector2) -> void:
	if _cristal_quebrado:
		# já quebrado: só umas lasquinhas do vidro escuro
		_soltar_cacos(p, 4, Color(0.35, 0.35, 0.45), 160.0)
		return
	_cristal_danos += 1
	_cristal_tremor = 1.0
	# trinca: 2 a 3 galhos saindo do ponto, presos dentro do cristal
	for g in randi_range(2, 3):
		var linha := PackedVector2Array([p])
		var ang := randf() * TAU
		for k in randi_range(4, 7):
			ang += randf_range(-0.6, 0.6)
			var q: Vector2 = linha[linha.size() - 1] + Vector2.RIGHT.rotated(ang) * randf_range(8.0, 18.0)
			if not Geometry2D.is_point_in_polygon(q, POLI_CRISTAL):
				break
			linha.append(q)
		if linha.size() > 1:
			_trincas.append(linha)
	while _trincas.size() > 40:
		_trincas.pop_front()
	var cor := Color(1.0, 0.55, 0.9).lerp(Color(1.0, 0.25, 0.35), _noite)
	_soltar_cacos(p, 9, cor, 260.0)
	_claroes.append({"pos": p, "t": 0.0, "vida": 0.35, "raio": 70.0, "cor": cor})
	if _cristal_danos >= TIROS_CRISTAL:
		_quebrar_cristal()
	else:
		Maquina.efeito(SOM_TRINCA, -4.0, randf_range(0.92, 1.12))


func _quebrar_cristal() -> void:
	_reagir("surpreso", 0.8)
	_cristal_quebrado = true
	_cristal_volta = CRISTAL_VOLTA
	_cristal_morte = 0.0
	var centro := Vector2(508, 790)
	var cor := Color(1.0, 0.6, 0.95).lerp(Color(1.0, 0.3, 0.4), _noite)
	for i in 34:
		var q := centro + Vector2(randf_range(-50, 50), randf_range(-150, 160))
		_soltar_cacos(q, 1, cor if i % 3 else Color(0.4, 0.4, 0.5), 520.0)
	_claroes.append({"pos": centro, "t": 0.0, "vida": 0.6, "raio": 420.0, "cor": cor})
	_claroes.append({"pos": centro, "t": 0.0, "vida": 0.9, "raio": 220.0, "cor": Color.WHITE})
	_onda_quebra = 0.0
	Maquina.efeito(SOM_QUEBRA, -1.0)


func _tocar_ouro(p: Vector2) -> void:
	_toque_ouro = Vector3((p.x - PONTAS_CAIXA.position.x) / PONTAS_CAIXA.size.x, (p.y - PONTAS_CAIXA.position.y) / PONTAS_CAIXA.size.y, 0.0)
	var ouro := Color(1.0, 0.82, 0.35).lerp(Color(0.85, 0.9, 1.0), _noite)
	for i in 16:
		_faiscas_ouro.append({"pos": p, "vel": Vector2.RIGHT.rotated(randf_range(-PI, 0.2)) * randf_range(120.0, 340.0), "t": 0.0, "vida": randf_range(0.35, 0.7)})
	for i in 10:
		_cacos.append({"pos": p + Vector2(randf_range(-6, 6), randf_range(-4, 4)), "vel": Vector2(randf_range(-60, 60), randf_range(-140, -20)), "t": 0.0,
			"vida": randf_range(0.9, 1.6), "tam": randf_range(1.5, 3.0), "rot": randf() * TAU, "giro": randf_range(-14, 14), "cor": ouro, "ouro": true})
	_claroes.append({"pos": p, "t": 0.0, "vida": 0.4, "raio": 60.0, "cor": ouro})
	Maquina.efeito(SOM_OURO, -5.0, randf_range(0.94, 1.08))


## Pedra (lascas + pó) ou areia (só o pó e os grãos).
func _estilhacar(p: Vector2, cor: Color, lascas: int, po: int) -> void:
	_soltar_cacos(p, lascas, cor, 220.0)
	for i in po:
		_poeiras.append({"pos": p + Vector2(randf_range(-4, 4), randf_range(-3, 3)), "vel": Vector2(randf_range(-50, 50), randf_range(-70, -15)),
			"t": 0.0, "vida": randf_range(0.7, 1.2), "tam": randf_range(8.0, 16.0), "cor": cor})
	while _poeiras.size() > 60:
		_poeiras.pop_front()


func _soltar_cacos(p: Vector2, n: int, cor: Color, forca: float) -> void:
	for i in n:
		_cacos.append({"pos": p, "vel": Vector2.RIGHT.rotated(randf_range(-PI * 0.95, -PI * 0.05)) * randf_range(forca * 0.35, forca), "t": 0.0,
			"vida": randf_range(0.6, 1.1), "tam": randf_range(2.0, 5.0), "rot": randf() * TAU, "giro": randf_range(-12, 12), "cor": cor, "ouro": false})
	while _cacos.size() > 90:
		_cacos.pop_front()


func _atualizar_tiros_fundo(delta: float) -> void:
	# energia do cristal: cai com as trincas, treme depois de cada tiro, some
	# quebrado e volta aos poucos quando ele se refaz
	_cristal_tremor = maxf(0.0, _cristal_tremor - delta * 1.8)
	var alvo := 1.0 - 0.45 * float(_cristal_danos) / TIROS_CRISTAL
	if _cristal_quebrado:
		_cristal_volta -= delta
		_cristal_morte = minf(1.0, _cristal_morte + delta * 3.0)
		alvo = 0.0
		if _cristal_volta <= 0.0:
			_cristal_quebrado = false
			_cristal_danos = 0
			_cristal_refaz = 0.0
			Maquina.efeito(SOM_VOLTA, -3.0)
	if _cristal_refaz >= 0.0:
		_cristal_refaz += delta / 2.2
		_cristal_morte = 1.0 - _cristal_refaz
		alvo = _cristal_refaz
		if _cristal_refaz >= 1.0:
			_cristal_refaz = -1.0
			_cristal_morte = 0.0
			_trincas.clear()
	var piscar := 0.0
	if _cristal_danos > 0 and not _cristal_quebrado:
		piscar = (0.25 * float(_cristal_danos) / TIROS_CRISTAL + 0.6 * _cristal_tremor) * randf()
	_energia = clampf(alvo * (1.0 - piscar), 0.0, 1.0)
	_cristal.modulate.a = _energia
	_faiscas.emitting = _energia > 0.35
	_atualizar_pontas(delta)
	_feixes.energia = _energia
	# a luz some de tudo com o cristal do meio; de um lado, com a ponta dele
	var lados := Vector2(1.0 - float(_pontas[0]["morte"]), 1.0 - float(_pontas[1]["morte"]))
	# cada ponta de ouro acende com o seu cristal (o do meio manda nas três)
	_pontas_acesas = Vector3(_energia * lados.x, _energia, _energia * lados.y)
	for fundo: Sprite2D in [_fundo_sol, _fundo_lua]:
		var mf := fundo.material as ShaderMaterial
		mf.set_shader_parameter("energia", _energia)
		mf.set_shader_parameter("luz_lados", lados)
		mf.set_shader_parameter("pontas_acesas", _pontas_acesas)
	for pl in _planos:
		if pl["lua"] != null:
			continue
		var no := pl["no"] as Sprite2D
		var lado: int = pl["lado"]
		var acesa := _energia
		if no == _plano_obeliscos[0] or no == _plano_obeliscos[1]:
			acesa *= lados[lado]
		elif lado >= 0:
			acesa *= lerpf(1.0, lados[lado], 0.7)
		var apagado := clampf(1.0 - acesa, 0.0, 1.0)
		if absf(apagado - float(pl.get("apagado", -1.0))) > 0.004:
			pl["apagado"] = apagado
			no.set_instance_shader_parameter("apagado", apagado)
	for i in 2:
		_feixes.lado_aceso[i] = lados[i]
	_morto.visible = _cristal_morte > 0.001
	if _morto.visible:
		(_morto.get_child(0) as Sprite2D).modulate.a = _cristal_morte * (1.0 - _noite)
		(_morto.get_child(1) as Sprite2D).modulate.a = _cristal_morte * _noite
	if _onda_quebra >= 0.0:
		_onda_quebra += delta
		if _onda_quebra > 0.8:
			_onda_quebra = -1.0

	# toque no ouro (pontas, no shader do fundo)
	if _toque_ouro.z >= 0.0:
		_toque_ouro.z += delta
		if _toque_ouro.z > 0.7:
			_toque_ouro.z = -1.0
		_ouro("ouro_toque", _toque_ouro)

	for c in _cacos:
		c["t"] += delta
		c["vel"] = c["vel"] * pow(0.7, delta) + Vector2(0, 620.0 if not c["ouro"] else 160.0) * delta
		c["pos"] += c["vel"] * delta
		c["rot"] += c["giro"] * delta
	while not _cacos.is_empty() and _cacos[0]["t"] > _cacos[0]["vida"]:
		_cacos.pop_front()
	for f in _faiscas_ouro:
		f["t"] += delta
		f["vel"] = f["vel"] * pow(0.2, delta) + Vector2(0, 260.0) * delta
		f["pos"] += f["vel"] * delta
	while not _faiscas_ouro.is_empty() and _faiscas_ouro[0]["t"] > _faiscas_ouro[0]["vida"]:
		_faiscas_ouro.pop_front()
	for p in _poeiras:
		p["t"] += delta
		p["vel"] = p["vel"] * pow(0.25, delta)
		p["pos"] += p["vel"] * delta
	while not _poeiras.is_empty() and _poeiras[0]["t"] > _poeiras[0]["vida"]:
		_poeiras.pop_front()
	for c2 in _claroes:
		c2["t"] += delta
	while not _claroes.is_empty() and _claroes[0]["t"] > _claroes[0]["vida"]:
		_claroes.pop_front()

	var ativo := not (_cacos.is_empty() and _faiscas_ouro.is_empty() and _poeiras.is_empty() and _claroes.is_empty()) \
		or not _trincas.is_empty() or _onda_quebra >= 0.0
	if ativo or _fx_sujo:
		_fx_n.queue_redraw()
		_fx_s.queue_redraw()
	_fx_sujo = ativo


func _desenhar_fx_n() -> void:
	for p in _poeiras:
		var k: float = p["t"] / p["vida"]
		Pincel.forma(_fx_n, Pincel.FUMACA, p["pos"], p["tam"] * (0.5 + 1.4 * k), Color(p["cor"], 0.5 * (1.0 - k)), k)
	# trincas: risco escuro (some quando o cristal se refaz)
	var a_tr := 1.0 if _cristal_refaz < 0.0 else 1.0 - _cristal_refaz
	if not _trincas.is_empty() and a_tr > 0.0:
		for linha: PackedVector2Array in _trincas:
			for i in range(linha.size() - 1):
				Pincel.linha(_fx_n, linha[i], linha[i + 1], Color(0.06, 0.02, 0.08, 0.85 * a_tr), 1.4)
	for c in _cacos:
		if c["ouro"]:
			continue
		var k2: float = c["t"] / c["vida"]
		Pincel.caco(_fx_n, c["pos"], c["tam"], c["rot"], Color(c["cor"], 1.0 - k2 * k2))


func _desenhar_fx_s() -> void:
	# a energia vaza pelas trincas (some com o cristal apagado)
	var cor_e := Color(1.0, 0.55, 0.9).lerp(Color(1.0, 0.25, 0.35), _noite)
	if not _trincas.is_empty() and _energia > 0.05:
		var brilho := (0.35 + 0.4 * _cristal_tremor) * _energia
		for linha: PackedVector2Array in _trincas:
			for i in range(linha.size() - 1):
				Pincel.laser(_fx_s, linha[i], linha[i + 1], Color(cor_e, brilho), 4.0)
	if _cristal_refaz >= 0.0:
		# faixa de luz subindo pelo cristal enquanto ele se refaz
		var y := lerpf(970.0, 620.0, _cristal_refaz)
		Pincel.laser(_fx_s, Vector2(450, y), Vector2(566, y), Color(cor_e, 0.8 * sin(_cristal_refaz * PI)), 14.0)
		Pincel.brilho(_fx_s, Vector2(508, y), 90.0, Color(cor_e, 0.4 * sin(_cristal_refaz * PI)))
	if _onda_quebra >= 0.0:
		var k0 := _onda_quebra / 0.8
		Pincel.anel(_fx_s, Vector2(508, 790), 40.0 + 420.0 * k0, 10.0 * (1.0 - k0) + 2.0, Color(cor_e, 0.7 * (1.0 - k0)))
	for c2 in _claroes:
		var k: float = c2["t"] / c2["vida"]
		Pincel.brilho(_fx_s, c2["pos"], c2["raio"] * (0.6 + 0.6 * k), Color(c2["cor"], 0.55 * (1.0 - k)))
	for c in _cacos:
		var k3: float = c["t"] / c["vida"]
		if c["ouro"]:
			var pisca := 0.5 + 0.5 * sin(c["t"] * 30.0 + c["rot"] * 5.0)
			Pincel.caco(_fx_s, c["pos"], c["tam"], c["rot"], Color(c["cor"], (1.0 - k3) * (0.4 + 0.6 * pisca)))
		elif randf() < 0.3:
			Pincel.circulo(_fx_s, c["pos"], c["tam"] * 0.6, Color(1, 1, 1, 0.5 * (1.0 - k3)))
	for f in _faiscas_ouro:
		var k4: float = f["t"] / f["vida"]
		var pf: Vector2 = f["pos"]
		Pincel.linha(_fx_s, pf, pf - (f["vel"] as Vector2) * 0.03, Color(1.0, 0.85, 0.45, 1.0 - k4), 1.6)
