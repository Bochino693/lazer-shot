#!/usr/bin/env python3
"""Mapas de profundidade dos fundos (Mar e Egito), tirados da própria imagem.

A tela do jogo mostra o fundo como uma foto de câmera: o chão do mar some
para a porta do templo (o ponto de fuga) e cada coisa em pé tem a distância
do ponto onde ela encosta no chão. Daqui sai, para cada pixel do fundo, a
distância Z (Z = 1 é o plano dos alvos comuns):
  chão          em perspectiva: Z = (chão perto - fuga) / (y na tela - fuga)
  pedras        constante, a do pé de cada uma (as duas pedras grandes)
  templo e céu  longe (Z = 10)
O shader do fundo (shaders/fundo_profundo.gdshader) move cada pixel conforme
essa distância quando a mira anda (paralaxe de verdade, pixel a pixel), e
os alvos passam na frente ou atrás das pedras pela distância deles.

Gera sprites/mar_profundidade.png (L, 1/4 da resolução do fundo), com
t = (1/Z - 1/Z_LONGE) / (1/Z_PERTO - 1/Z_LONGE).

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


def mar():
    yy = np.mgrid[0:TEX[1], 0:TEX[0]][0].astype(np.float64)
    z = np.where(yy > PE_TEMPLO, z_chao(yy), Z_LONGE)
    templo = mascara("mar_frente_navio_mascara.png", (195, 530), 0)
    z = np.where(templo > 0.5, np.minimum(z, float(z_chao(PE_TEMPLO))), z)
    for nome, canto, pe in (("mar_pedra_esq_mascara.png", (0, 466), PE_PEDRA_ESQ),
                            ("mar_pedra_dir_mascara.png", (523, 523), PE_PEDRA_DIR)):
        m = mascara(nome, canto)
        z = np.where(m > 0.5, float(z_chao(pe)), z)
    inv = 1.0 / z
    t = (inv - 1 / Z_LONGE) / (1 / Z_PERTO - 1 / Z_LONGE)
    peq = Image.fromarray((np.clip(t, 0, 1) * 255 + 0.5).astype(np.uint8), "L").resize((TEX[0] // 4, TEX[1] // 4), Image.BILINEAR)
    peq = Image.fromarray(ndi.gaussian_filter(np.asarray(peq).astype(np.float32), 0.7).clip(0, 255).astype(np.uint8), "L")
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


def egito():
    E = 2  # desenha os contornos em 2x e reduz: borda lisa
    yy = np.mgrid[0:TEX[1], 0:TEX[0]][0].astype(np.float64)
    z = z_chao_egito(yy)
    z = np.where(yy <= EG_HORIZONTE, EG_Z_LONGE, z)
    for pol, pe in EG_COISAS:
        m = Image.new("L", (TEX[0] * E, TEX[1] * E), 0)
        ImageDraw.Draw(m).polygon([(x * E, y * E) for x, y in pol], fill=255)
        m = np.asarray(m.resize(TEX, Image.LANCZOS)).astype(np.float32) / 255
        z = np.where(m > 0.5, float(z_chao_egito(pe)), z)
    inv = 1.0 / z
    t = (inv - 1 / EG_Z_LONGE) / (1 / EG_Z_PERTO - 1 / EG_Z_LONGE)
    img = Image.fromarray((np.clip(t, 0, 1) * 255 + 0.5).astype(np.uint8), "L").resize((TEX[0] // 2, TEX[1] // 2), Image.BILINEAR)
    img.save(os.path.join(SP, "egito_profundidade.png"), optimize=True)
    print("  egito_profundidade.png %dx%d  cristal Z=%.2f obeliscos Z=%.2f anubis Z=%.2f colunas Z=%.2f" % (
        img.width, img.height, z_chao_egito(1200), z_chao_egito(1086), z_chao_egito(930), z_chao_egito(1290)))


if __name__ == "__main__":
    mar()
    egito()
