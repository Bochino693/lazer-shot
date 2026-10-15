#!/usr/bin/env python3
"""Mapas de profundidade dos fundos (Mar e Egito), tirados da própria imagem.

A tela do jogo mostra o fundo como uma foto de câmera: o chão do mar some
para a porta do templo (o ponto de fuga) e cada coisa em pé tem a distância
do ponto onde ela encosta no chão. Daqui sai, para cada pixel do fundo, a
distância Z (Z = 1 é o plano dos alvos comuns):
  chão          em perspectiva: Z = (chão perto - fuga) / (y na tela - fuga)
  pedras        fora do mapa: cada uma tem a distância do pé dela
                (scripts/mar_vida.gd), para os alvos passarem na frente ou
                atrás delas
  templo e céu  longe (Z = 10)
Desde a Rodada 21 a cena do Mar anda inteira (sem paralaxe pixel a pixel,
que mostrava o recorte das pedras); R fica só como referência.

Gera sprites/mar_profundidade.png (RGBA, 1/4 da resolução do fundo):
  R  t = (1/Z - 1/Z_LONGE) / (1/Z_PERTO - 1/Z_LONGE)
  G  onde a luz cáustica do sol cai (chão e superfícies com textura, mais
     nas claras; a água aberta não recebe)
  B  coisa em pé no chão (as duas pedras com escritas, pelo contorno de
     sprites/mar_pedra_*.png): leva a cáustica de parede, não a de chão
  A  a força parada dos raios em cada ponto: caem saindo do sol (acima do
     topo, SOL_MAR) e são fortes na água aberta (lisa), fracos no que está
     perto
A luz do sol de fora andando (shaders/mar_luz.gdshaderinc, a mesma no fundo
e nas pedras) usa G, B e A.

Egito (sprites/egito_profundidade.png, L, metade da resolução, a mesma para
o dia e a noite): a imagem é uma câmera olhando o horizonte (ponto de fuga
no pé das pirâmides). Céu e pirâmides longe; chão em perspectiva; cada coisa
em pé (colunas, estátuas de Anúbis, obeliscos, cristal com o pedestal) tem a
distância do pé dela, recortada pelo contorno medido na imagem. O mesmo mapa
move o fundo pixel a pixel com a câmera (shaders/deserto_fundo.gdshader) e
esconde os brasões que passam atrás das coisas (shaders/egito_alvo.gdshader).

    python3 tools/gerar_profundidade.py
"""
import os
import re
import numpy as np
from PIL import Image
from PIL import ImageDraw
from scipy import ndimage as ndi

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")

# câmera do Mar (scripts/mar.gd): tela 1024x1820, fundo 1024x1536 com escala
# max(1024/1024, 1820/1536) * 1,06, centrado; chão perto (Z = 1) a 86% da
# altura da tela; ponto de fuga na porta do templo
TELA = (1024.0, 1820.0)
TEX = (1024, 1536)
ESC = max(TELA[0] / TEX[0], TELA[1] / TEX[1]) * 1.06
PORTA = (439.0, 724.0)
CHAO_TELA = 0.86
Z_LONGE, Z_PERTO = 10.0, 0.7
# pé de cada pedra grande (y na textura) — scripts/mar_vida.gd usa os mesmos
PE_PEDRA_ESQ = 935.0
PE_PEDRA_DIR = 1230.0
PE_TEMPLO = 790.0
# de onde entra a luz do sol (UV do fundo, acima do topo): o mesmo `sol` do
# shaders/fundo_profundo.gdshader
SOL_MAR = (0.52, -0.10)


def y_tela(y_tex):
    return (y_tex - TEX[1] / 2) * ESC + TELA[1] / 2


def z_chao(y_tex):
    fuga = y_tela(PORTA[1])
    perto = TELA[1] * CHAO_TELA
    d = y_tela(np.asarray(y_tex, np.float64)) - fuga
    return np.clip((perto - fuga) / np.maximum(d, 1e-3), Z_PERTO, Z_LONGE)


def mascara(nome, canto, canal=2):
    m = np.asarray(Image.open(os.path.join(SP, nome)).convert("RGBA")).astype(np.float32)[..., canal] / 255
    full = np.zeros((TEX[1], TEX[0]), np.float32)
    full[canto[1]:canto[1] + m.shape[0], canto[0]:canto[0] + m.shape[1]] = m
    return full


def luz_mar(yy):
    """Máscaras da luz do sol no Mar: (onde cai a cáustica, onde os raios
    aparecem). Superfície = onde a imagem tem textura (pedra, coral, templo)
    ou é chão; água aberta = onde a imagem é lisa."""
    img = np.asarray(Image.open(os.path.join(SP, "atlantis_fundo.png")).convert("RGB")).astype(np.float32) / 255
    lum = img @ np.array([0.3, 0.55, 0.15], np.float32)
    m1 = ndi.uniform_filter(lum, 11)
    m2 = ndi.uniform_filter(lum * lum, 11)
    textura = np.clip((np.sqrt(np.maximum(m2 - m1 * m1, 0)) - 0.025) / 0.06, 0, 1)
    textura = ndi.gaussian_filter(textura, 6)
    chao = np.clip((yy - PE_TEMPLO) / 60.0, 0, 1)
    cau = np.maximum(textura * 0.8, chao) * (0.35 + 0.65 * np.clip(lum / 0.55, 0, 1))
    raio = np.clip(1 - textura * 1.2, 0, 1) * (1 - chao * 0.6)
    return cau, raio


def mar():
    yy = np.mgrid[0:TEX[1], 0:TEX[0]][0].astype(np.float64)
    z = np.where(yy > PE_TEMPLO, z_chao(yy), Z_LONGE)
    templo = mascara("mar_frente_navio_mascara.png", (195, 530), 0)
    z = np.where(templo > 0.5, np.minimum(z, float(z_chao(PE_TEMPLO))), z)
    # as duas pedras com escritas não entram: a distância delas é a do pé
    # (scripts/mar_vida.gd)
    inv = 1.0 / z
    t = (inv - 1 / Z_LONGE) / (1 / Z_PERTO - 1 / Z_LONGE)
    cau, raio = luz_mar(yy)
    canais = []
    for i, a in enumerate((t, cau, raio)):
        c = Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), "L").resize((TEX[0] // 4, TEX[1] // 4), Image.BILINEAR)
        canais.append(Image.fromarray(ndi.gaussian_filter(np.asarray(c).astype(np.float32), 0.7 if i == 0 else 1.2).clip(0, 255).astype(np.uint8), "L"))
    # força parada dos raios, na resolução do mapa (UV do centro de cada pixel)
    h, w = TEX[1] // 4, TEX[0] // 4
    vy, vx = np.mgrid[0:h, 0:w].astype(np.float64)
    vx = (vx + 0.5) / w - SOL_MAR[0]
    vy = (vy + 0.5) / h - SOL_MAR[1]
    s = vx / vy
    r = np.asarray(canais[0]).astype(np.float64) / 255
    b = np.asarray(canais[2]).astype(np.float64) / 255
    fixa = np.exp(-vy * 0.9 - s * s * 0.8) * (0.4 + 0.6 * b) * (1 - 0.8 * r)
    canais.append(Image.fromarray((np.clip(fixa, 0, 1) * 255 + 0.5).astype(np.uint8), "L"))
    # B: as pedras em pé (o contorno dos planos, na folga de MAR_FOLGA px)
    em_pe = np.zeros((TEX[1], TEX[0]), np.float32)
    for nome, canto in (("esq", (0, 466)), ("dir", (523, 523))):
        a = np.asarray(Image.open(os.path.join(SP, "mar_pedra_%s.png" % nome)).convert("RGBA"))[..., 3] / 255.0
        x0, y0 = max(canto[0] - 24, 0), max(canto[1] - 24, 0)
        em_pe[y0:y0 + a.shape[0], x0:x0 + a.shape[1]] = np.maximum(em_pe[y0:y0 + a.shape[0], x0:x0 + a.shape[1]], a)
    canais[2] = Image.fromarray((em_pe * 255 + 0.5).astype(np.uint8), "L").resize((w, h), Image.BILINEAR)
    peq = Image.merge("RGBA", canais)
    peq.save(os.path.join(SP, "mar_profundidade.png"), optimize=True)
    print("  mar_profundidade.png   %dx%d  pedras: esq Z=%.2f dir Z=%.2f templo Z=%.2f" % (
        peq.width, peq.height, z_chao(PE_PEDRA_ESQ), z_chao(PE_PEDRA_DIR), z_chao(PE_TEMPLO)))


# ───────────────────────────────────────────── Egito
# horizonte (pé das pirâmides) e o chão a Z = 1 (frente dos degraus do altar),
# em y da imagem; a tela mostra a imagem só escalada (scripts/deserto_vivo.gd)
EG_HORIZONTE = 700.0
EG_CHAO_1 = 1300.0
EG_Z_LONGE, EG_Z_PERTO = 10.0, 0.7

# contornos medidos na imagem (px da imagem 1024x1536) e o y do pé de cada um
EG_COISAS = [
    # colunas do fundo (as mais longe primeiro)
    ([(158, 715), (192, 715), (192, 880), (158, 880)], 880),
    ([(222, 712), (262, 712), (262, 900), (222, 900)], 900),
    ([(334, 722), (374, 722), (374, 880), (334, 880)], 880),
    ([(636, 718), (676, 718), (676, 880), (636, 880)], 880),
    ([(778, 700), (816, 700), (816, 882), (778, 882)], 882),
    ([(828, 742), (860, 742), (860, 886), (828, 886)], 886),
    ([(98, 684), (152, 684), (150, 720), (148, 960), (142, 992), (100, 992)], 990),
    ([(858, 668), (926, 668), (924, 700), (922, 935), (932, 962), (864, 962), (872, 935), (870, 700)], 960),
    # Anúbis
    ([(290, 736), (300, 746), (312, 738), (318, 760), (322, 790), (320, 880), (332, 897), (334, 931),
      (264, 931), (266, 897), (278, 880), (276, 790), (282, 760)], 930),
    ([(712, 734), (724, 745), (733, 736), (742, 760), (748, 790), (746, 880), (762, 895), (762, 927),
      (688, 927), (690, 895), (705, 880), (702, 790), (706, 760)], 926),
    # obeliscos (cristal da ponta, agulha, base em dois degraus)
    ([(209, 764), (198, 790), (196, 836), (192, 840), (176, 1020), (160, 1022), (160, 1050), (132, 1052),
      (132, 1087), (281, 1087), (281, 1052), (258, 1050), (258, 1022), (244, 1020), (226, 840), (222, 836),
      (221, 790)], 1086),
    ([(812, 764), (802, 790), (800, 836), (795, 840), (785, 1020), (767, 1022), (767, 1050), (745, 1052),
      (745, 1087), (893, 1087), (893, 1052), (866, 1050), (866, 1022), (850, 1020), (832, 840), (828, 836),
      (826, 790)], 1086),
    # cristal e pedestal (no meio do altar)
    ([(505, 628), (478, 672), (462, 712), (458, 800), (455, 958), (432, 958), (425, 990), (395, 1060),
      (378, 1112), (642, 1112), (625, 1060), (592, 990), (580, 958), (560, 958), (558, 800), (553, 712),
      (538, 672)], 1200),
    # colunas grandes da frente (capitel, fuste, base)
    ([(0, 98), (150, 108), (168, 170), (160, 262), (130, 320), (102, 336), (100, 1180), (132, 1186),
      (132, 1292), (0, 1292)], 1290),
    ([(1024, 98), (874, 108), (856, 170), (864, 262), (894, 320), (924, 336), (926, 1180), (892, 1186),
      (892, 1300), (1024, 1300)], 1300),
]


def z_chao_egito(y):
    d = np.asarray(y, np.float64) - EG_HORIZONTE
    return np.clip((EG_CHAO_1 - EG_HORIZONTE) / np.maximum(d, 1e-3), EG_Z_PERTO, EG_Z_LONGE)


def planos_egito():
    """Os recortes do Egito (scripts/egito_planos.gd, tools/gerar_camadas.py):
    [(alfa 1024x1536, Z)], do longe para o perto."""
    txt = open(os.path.join(RAIZ, "scripts", "egito_planos.gd"), encoding="utf-8").read()
    folha = np.asarray(Image.open(os.path.join(SP, "egito_planos_sol.png")).convert("RGBA"))[..., 3].astype(np.float32) / 255
    saida = []
    for m in re.finditer(r'"canto": Vector2\((\d+), (\d+)\), "folha": Rect2\((\d+), (\d+), (\d+), (\d+)\), "z": ([\d.]+)', txt):
        cx, cy, fx, fy, fw, fh = (int(v) for v in m.groups()[:6])
        a = np.zeros((TEX[1], TEX[0]), np.float32)
        x0, y0 = max(cx, 0), max(cy, 0)
        x1, y1 = min(cx + fw, TEX[0]), min(cy + fh, TEX[1])
        a[y0:y1, x0:x1] = folha[fy + y0 - cy:fy + y1 - cy, fx + x0 - cx:fx + x1 - cx]
        saida.append((a, float(m.group(7))))
    return saida


def egito():
    # o chão (com as colunas pequenas do fundo, que ficaram pintadas nele) é o
    # mesmo da conta do shader do fundo: Z pelo y; céu e pirâmides longe. Cada
    # plano recortado (colunas, Anúbis, obeliscos, cristal) tem o Z dele, pelo
    # alfa do próprio recorte: o mapa bate com o que a tela mostra.
    yy = np.mgrid[0:TEX[1], 0:TEX[0]][0].astype(np.float64)
    z = z_chao_egito(yy)
    z = np.where(yy <= EG_HORIZONTE, EG_Z_LONGE, z)
    for a, zp in planos_egito():
        z = np.where(a > 0.5, zp, z)
    inv = 1.0 / z
    t = (inv - 1 / EG_Z_LONGE) / (1 / EG_Z_PERTO - 1 / EG_Z_LONGE)
    img = Image.fromarray((np.clip(t, 0, 1) * 255 + 0.5).astype(np.uint8), "L").resize((TEX[0] // 2, TEX[1] // 2), Image.BILINEAR)
    img.save(os.path.join(SP, "egito_profundidade.png"), optimize=True)
    print("  egito_profundidade.png %dx%d  (%d planos recortados)" % (img.width, img.height, len(planos_egito())))


if __name__ == "__main__":
    mar()
    egito()
