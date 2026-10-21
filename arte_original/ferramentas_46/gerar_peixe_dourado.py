#!/usr/bin/env python3
"""Peixe dourado do cardume de bônus do Mar (scripts/mar_cardume_dourado.gd).

Peixinho de ouro virado para a direita: corpo com degradê (costas mais
escuras, barriga clara), escamas em meia-lua, nadadeiras translúcidas, rabo
bifurcado, olho com brilho e um reflexo forte de metal no lombo.

Gera sprites/mar_peixe_dourado.png (128x64, RGBA).

    python3 tools/gerar_peixe_dourado.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

AQUI = os.path.dirname(os.path.abspath(__file__))
SPRITES = os.path.join(AQUI, "..", "sprites")
W, H, E = 128, 64, 4


def reduzir(img):
    return np.asarray(img.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255


def main():
    corpo = Image.new("L", (W * E, H * E), 0)
    d = ImageDraw.Draw(corpo)
    # corpo: gota deitada (cabeça à direita)
    pts = []
    for k in range(80):
        a = 2 * np.pi * k / 80
        x = 70 + 34 * np.cos(a)
        larg = 17 * (0.78 + 0.22 * np.cos(a))      # mais alto na cabeça
        y = 32 + larg * np.sin(a)
        pts.append((x * E, y * E))
    d.polygon(pts, fill=255)
    m = reduzir(corpo)

    nad = Image.new("L", (W * E, H * E), 0)
    dn = ImageDraw.Draw(nad)
    # rabo bifurcado
    dn.polygon([(40 * E, 32 * E), (10 * E, 12 * E), (20 * E, 32 * E), (10 * E, 52 * E)], fill=255)
    # dorsal e ventral
    dn.polygon([(54 * E, 24 * E), (64 * E, 5 * E), (86 * E, 21 * E)], fill=255)
    dn.polygon([(58 * E, 41 * E), (66 * E, 57 * E), (80 * E, 42 * E)], fill=255)
    # peitoral
    dn.polygon([(80 * E, 36 * E), (70 * E, 44 * E), (86 * E, 41 * E)], fill=255)
    n = reduzir(nad) * (1 - m)

    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # degradê: costas cobre, barriga ouro claro
    v = np.clip((yy - 15) / 34, 0, 1)
    escuro = np.array([0.62, 0.32, 0.04])
    ouro = np.array([1.00, 0.76, 0.18])
    claro = np.array([1.00, 0.95, 0.62])
    cor = escuro[None, None] * (1 - v[..., None]) + ouro[None, None] * v[..., None]
    cor = cor * (1 - (v ** 3)[..., None] * 0.6) + claro[None, None] * (v ** 3)[..., None] * 0.6
    # escamas em meia-lua
    esc = np.zeros((H, W), np.float32)
    for cx in range(44, 96, 6):
        for cy in range(18, 48, 5):
            r = np.hypot(xx - cx - (3 if (cy // 5) % 2 else 0), yy - cy)
            esc += np.clip(1 - np.abs(r - 3.2) / 0.8, 0, 1) * (xx < cx + 1)
    esc = np.clip(esc, 0, 1) * m * np.clip((xx - 44) / 10, 0, 1) * np.clip((98 - xx) / 10, 0, 1)
    cor = cor * (1 - esc[..., None] * 0.14)
    # reflexo de metal no lombo
    dist = ndi.distance_transform_edt(m > 0.5)
    reflexo = np.exp(-((yy - 22) / 3.5) ** 2) * np.clip((xx - 50) / 30, 0, 1) * np.clip((100 - xx) / 12, 0, 1) * m
    cor = cor + reflexo[..., None] * 0.55
    # contorno levemente escuro
    borda = np.clip(1 - dist / 1.6, 0, 1) * m
    cor = cor * (1 - borda[..., None] * 0.35)
    # olho
    r_o = np.hypot(xx - 92, yy - 28)
    olho = np.clip(1 - (r_o - 3.2) / 0.8, 0, 1)
    cor = cor * (1 - olho[..., None]) + np.array([0.06, 0.04, 0.02])[None, None] * olho[..., None]
    bri = np.clip(1 - np.hypot(xx - 91, yy - 27) / 1.2, 0, 1)
    cor = cor * (1 - bri[..., None]) + bri[..., None]
    # nadadeiras: ouro translúcido com raios
    raios = (0.5 + 0.5 * np.sin(np.arctan2(yy - 32, xx - 40) * 18)) ** 2
    cor_n = ouro * 0.8 + claro * 0.2
    a_n = n * (0.55 + 0.35 * raios)
    cor = cor * (1 - n[..., None]) + cor_n[None, None] * n[..., None]
    alfa = np.clip(m + a_n, 0, 1)
    rgba = np.dstack([np.clip(cor, 0, 1), alfa])
    Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(SPRITES, "mar_peixe_dourado.png"), optimize=True)
    print("  mar_peixe_dourado.png  %dx%d" % (W, H))


if __name__ == "__main__":
    main()
