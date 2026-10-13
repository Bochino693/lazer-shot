#!/usr/bin/env python3
"""Cristal do Egito quebrado (scripts/deserto_vivo.gd), em 2x.

  sprites/egito_cristal_morto_sol.png / _lua.png   320x752 (caixa
      428,608,160,376 em 2x, um pouco maior que o cristal para cobrir o
      brilho da borda): o mesmo cristal do fundo, apagado (vidro escuro
      e frio, sem a luz de dentro), cheio de trincas com borda clara e com
      buracos onde caíram pedaços. Fica por cima do cristal inteiro enquanto
      ele está quebrado.

    python3 tools/gerar_cristal_morto.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")
CAIXA = (428, 608, 160, 376)
CAIXA_MASCARA = (440, 620)       # onde começa egito_cristal_mascara.png (1x)
X = 2
rng = np.random.default_rng(83)


def trincas(w, h, corpo):
    """Rachaduras: caminhadas que se dividem, dentro do corpo (4x, reduz)."""
    ss = 4
    im = Image.new("L", (w * ss, h * ss), 0)
    d = ImageDraw.Draw(im)
    ys, xs = np.nonzero(corpo > 0.5)

    def andar(p, ang, comp, larg, nivel):
        pts = [p]
        for _ in range(int(comp)):
            ang += rng.normal(0, 0.35)
            q = (pts[-1][0] + np.cos(ang) * 9 * ss, pts[-1][1] + np.sin(ang) * 9 * ss)
            pts.append(q)
            if nivel < 2 and rng.random() < 0.18:
                andar(q, ang + rng.choice([-1, 1]) * rng.uniform(0.5, 1.1), comp * 0.5, larg * 0.6, nivel + 1)
        d.line(pts, fill=255, width=max(1, int(larg * ss)))

    for _ in range(16):
        i = rng.integers(len(xs))
        andar((xs[i] * ss, ys[i] * ss), rng.uniform(0, 2 * np.pi), rng.integers(6, 16), rng.uniform(1.2, 2.2), 0)
    return np.asarray(im.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255 * corpo


def buracos(w, h, corpo):
    """Lascas que caíram: polígonos irregulares perto das bordas e do alto."""
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    centros = [(w * 0.50, h * 0.10), (w * 0.30, h * 0.30), (w * 0.72, h * 0.42), (w * 0.38, h * 0.62)]
    for cx, cy in centros:
        r = rng.uniform(14, 24)
        pts = []
        for k in range(7):
            a = 2 * np.pi * k / 7 + rng.uniform(-0.3, 0.3)
            pts.append((cx + np.cos(a) * r * rng.uniform(0.6, 1.2), cy + np.sin(a) * r * rng.uniform(0.6, 1.2)))
        d.polygon(pts, fill=255)
    return np.asarray(im).astype(np.float32) / 255 * corpo


def morto(nome):
    fundo = Image.open(os.path.join(SP, "deserto_%s.png" % nome)).convert("RGB")
    x, y, w, h = CAIXA
    reg = fundo.crop((x, y, x + w, y + h)).resize((w * X, h * X), Image.LANCZOS)
    base = np.asarray(reg).astype(np.float32) / 255
    m0 = np.asarray(Image.open(os.path.join(SP, "egito_cristal_mascara.png")).convert("RGB")).astype(np.float32) / 255
    H, W = h * X, w * X
    masc = np.zeros((H, W, 3), np.float32)
    ox, oy = (CAIXA_MASCARA[0] - x) * X, (CAIXA_MASCARA[1] - y) * X
    masc[oy:oy + m0.shape[0], ox:ox + m0.shape[1]] = m0
    # a base do cristal desce mais um pouco que a máscara
    fim = oy + 652
    masc[fim:fim + 40, :, 0] = masc[fim - 1, :, 0][None, :]
    corpo = np.clip(masc[..., 0] * 1.6, 0, 1)
    corpo = ndi.grey_dilation(corpo, size=(13, 13))            # cobre o brilho da borda
    corpo = ndi.gaussian_filter(corpo, 2.0)
    yy = np.arange(H)[:, None]
    corpo = corpo * np.clip((fim + 40 - yy) / 14.0, 0, 1)      # some em cima do pedestal
    lum = base.mean(-1)
    # vidro apagado: escuro, frio, sem a luz de dentro (o desenho das facetas fica)
    frio = np.array([0.30, 0.30, 0.40]) if nome == "sol" else np.array([0.24, 0.24, 0.34])
    cor = lum[..., None] ** 1.3 * frio * 1.1 + 0.02
    arestas = np.clip(masc[..., 1] * 1.2, 0, 1)
    cor = cor + np.array([0.55, 0.55, 0.65]) * arestas[..., None] * 0.18
    # trincas: risco escuro com uma borda clara deslocada (dá fundura)
    tr = trincas(W, H, corpo)
    borda = np.clip(ndi.shift(tr, (0.8, -0.8), order=1) - tr, 0, 1)
    cor = cor * (1 - 0.85 * tr[..., None]) + np.array([0.75, 0.75, 0.85]) * borda[..., None] * 0.45
    # buracos das lascas que caíram: escuro por dentro, aresta clara
    bu = buracos(W, H, corpo)
    aro = np.clip(ndi.grey_dilation(bu, size=(3, 3)) - bu, 0, 1)
    cor = cor * (1 - 0.9 * bu[..., None]) + np.array([0.02, 0.015, 0.03]) * bu[..., None]
    cor = cor + np.array([0.7, 0.7, 0.8]) * aro[..., None] * 0.35
    out = np.dstack([np.clip(cor, 0, 1), corpo])
    Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(SP, "egito_cristal_morto_%s.png" % nome), optimize=True)
    print("egito_cristal_morto_%s.png %dx%d" % (nome, W, H))


if __name__ == "__main__":
    morto("sol")
    morto("lua")
