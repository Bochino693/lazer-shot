class_name EgitoPlanos
extends RefCounted

## Gerado por tools/gerar_camadas.py — não editar à mão.
## Planos do Egito (longe -> perto): onde cada recorte fica na imagem do
## fundo (canto, px da imagem 1024x1536), onde está na folha
## (sprites/egito_planos_sol.png / _lua.png / _brilho.png) e a distância Z.

const PLANOS := [
	{"nome": "anubis_dir", "canto": Vector2(677, 735), "folha": Rect2(0, 1217, 87, 208), "z": 2.655},
	{"nome": "anubis_esq", "canto": Vector2(259, 736), "folha": Rect2(89, 1217, 85, 202), "z": 2.609},
	{"nome": "coluna_fundo_dir", "canto": Vector2(852, 668), "folha": Rect2(890, 0, 76, 298), "z": 2.308},
	{"nome": "coluna_fundo_esq", "canto": Vector2(95, 680), "folha": Rect2(823, 0, 65, 323), "z": 2.069},
	{"nome": "obelisco_esq", "canto": Vector2(130, 770), "folha": Rect2(507, 0, 156, 334), "z": 1.554},
	{"nome": "obelisco_dir", "canto": Vector2(740, 770), "folha": Rect2(665, 0, 156, 333), "z": 1.554},
	{"nome": "cristal", "canto": Vector2(380, 624), "folha": Rect2(242, 0, 263, 505), "z": 1.200},
	{"nome": "coluna_esq", "canto": Vector2(49, 104), "folha": Rect2(119, 0, 121, 1205), "z": 1.017},
	{"nome": "coluna_dir", "canto": Vector2(858, 102), "folha": Rect2(0, 0, 117, 1215), "z": 1.000},
]
