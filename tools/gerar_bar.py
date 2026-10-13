#!/usr/bin/env python3
"""Marcas de tiro do Bar (tiro que erra a garrafa), com profundidade:

  sprites/bar_furo_madeira.png   furo na madeira da estante: cratera de
                                 madeira crua lascada (fibras no sentido do
                                 veio), buraco escuro com fundo, borda de
                                 dentro clara embaixo/escura em cima (luz de
                                 cima) e sombra leve em volta
  sprites/bar_furo_papel.png     furo no cartaz do barril (JOY-BOY): o papel
                                 rasgado com fibras brancas na borda, uma
                                 aba dobrada para fora com sombra, e por
                                 dentro a madeira do barril com o furo

As duas em 160x160, desenhadas em 4x e reduzidas (bordas lisas).

    python3 tools/gerar_bar.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")
T = 160
S = 4
N = T * S
C = N / 2
rng = np.random.default_rng(7)


def camada():
    return Image.new("RGBA", (N, N), (0, 0, 0, 0))


def estrela(raios, alongar=(1.0, 1.0), giro=0.0, centro=(C, C)):
    pts = []
    n = len(raios)
    for i, r in enumerate(raios):
        a = giro + 2 * np.pi * i / n
        pts.append((centro[0] + np.cos(a) * r * alongar[0] * S, centro[1] + np.sin(a) * r * alongar[1] * S))
    return pts


def borrar(im, r):
    return im.filter(ImageFilter.GaussianBlur(r * S))


def gradiente_radial(cor_dentro, cor_fora, r0, r1, centro=(C, C)):
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    d = np.hypot(xx - centro[0], yy - centro[1]) / S
    k = np.clip((d - r0) / max(r1 - r0, 1e-3), 0, 1)[..., None]
    a = np.array(cor_dentro, np.float32) * (1 - k) + np.array(cor_fora, np.float32) * k
    return Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8), "RGBA")


def mascara(pts, borra=0.0):
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return borrar(m, borra) if borra else m


def aplicar(base, cor_img, m):
    c = cor_img.copy()
    a = np.asarray(c.split()[3]).astype(np.float32) * np.asarray(m).astype(np.float32) / 255
    c.putalpha(Image.fromarray(a.astype(np.uint8)))
    base.alpha_composite(c)


def furo_madeira():
    im = camada()
    # sombra/queimado leve em volta
    aplicar(im, gradiente_radial((0.10, 0.05, 0.02, 0.45), (0.10, 0.05, 0.02, 0.0), 18, 56),
            mascara(estrela([48 + rng.uniform(-6, 6) for _ in range(20)]), 4))
    # madeira crua lascada: pontas compridas no sentido do veio (vertical)
    raios = []
    for i in range(18):
        a = 2 * np.pi * i / 18
        veio = abs(np.sin(a)) ** 2          # mais longe para cima/baixo
        r = (20 + 13 * veio) * rng.uniform(0.75, 1.2) if i % 2 == 0 else rng.uniform(15, 20)
        raios.append(r)
    m_lasca = mascara(estrela(raios, giro=rng.uniform(0, 0.3)), 0.7)
    aplicar(im, gradiente_radial((0.55, 0.30, 0.13, 0.92), (0.96, 0.68, 0.38, 0.72), 10, 34), m_lasca)
    # fibras: riscos finos claros e escuros seguindo o veio
    fib = camada()
    d = ImageDraw.Draw(fib)
    for i in range(26):
        x = C + rng.uniform(-30, 30) * S
        y0 = C + rng.uniform(-38, -10) * S
        y1 = C + rng.uniform(10, 38) * S
        claro = rng.random() < 0.5
        cor = (255, 200, 140, 130) if claro else (95, 45, 15, 120)
        d.line([(x, y0), (x + rng.uniform(-3, 3) * S, y1)], fill=cor, width=int(rng.uniform(0.6, 1.4) * S))
    aplicar(im, fib, m_lasca)
    # cratera escura com fundo (anel interno sombreado: luz vem de cima)
    m_crat = mascara(estrela([rng.uniform(13, 17) for _ in range(14)]), 0.6)
    aplicar(im, gradiente_radial((0.06, 0.03, 0.01, 1.0), (0.30, 0.17, 0.07, 1.0), 4, 16), m_crat)
    # borda interna: parte de cima na sombra, de baixo pegando luz
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    ang = np.arctan2(yy - C, xx - C)
    d_c = np.hypot(xx - C, yy - C) / S
    aro = np.clip(1 - np.abs(d_c - 13.5) / 2.2, 0, 1)
    luz = np.clip(np.sin(ang), 0, 1) * aro            # embaixo
    sombra = np.clip(-np.sin(ang), 0, 1) * aro        # em cima
    arr = np.asarray(im).astype(np.float32) / 255
    rgb = arr[..., :3]
    rgb = rgb * (1 - 0.55 * sombra[..., None]) + np.array([1.0, 0.85, 0.6]) * 0.45 * luz[..., None]
    arr[..., :3] = rgb
    # buraco do meio
    furo = np.clip(1 - (d_c - 5.5) / 3.0, 0, 1)
    arr[..., :3] *= (1 - 0.95 * furo[..., None])
    arr[..., 3] = np.maximum(arr[..., 3], furo)
    im = Image.fromarray(np.clip(arr * 255, 0, 255).astype(np.uint8), "RGBA")
    return im.resize((T, T), Image.LANCZOS)


def furo_papel():
    im = camada()
    # sombra do papel levantado sobre a madeira
    aplicar(im, gradiente_radial((0.15, 0.08, 0.03, 0.45), (0.15, 0.08, 0.03, 0.0), 22, 44),
            mascara(estrela([40 + rng.uniform(-5, 5) for _ in range(18)], centro=(C + 3 * S, C + 4 * S)), 4))
    # papel rasgado: borda de fibras claras (o papel por baixo da tinta)
    raios_rasgo = [rng.uniform(19, 30) for _ in range(26)]
    m_fibra = mascara(estrela([r + rng.uniform(3, 6) for r in raios_rasgo]), 0.3)
    aplicar(im, gradiente_radial((0.98, 0.95, 0.86, 0.95), (0.98, 0.95, 0.86, 0.95), 0, 1), m_fibra)
    # dentro: a madeira do barril (escura) com veio e o furo
    m_buraco = mascara(estrela(raios_rasgo), 0.3)
    madeira = gradiente_radial((0.20, 0.11, 0.05, 1.0), (0.42, 0.25, 0.11, 1.0), 4, 26)
    dm = ImageDraw.Draw(madeira)
    for i in range(14):
        y = C + rng.uniform(-30, 30) * S
        dm.line([(0, y), (N, y + rng.uniform(-4, 4) * S)], fill=(60, 30, 12, 110), width=int(rng.uniform(0.8, 1.6) * S))
    aplicar(im, madeira, m_buraco)
    arr = np.asarray(im).astype(np.float32) / 255
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    d_c = np.hypot(xx - C, yy - C) / S
    furo = np.clip(1 - (d_c - 6.0) / 3.0, 0, 1)
    arr[..., :3] *= (1 - 0.95 * furo[..., None])
    # sombra da borda do papel caindo dentro do buraco (em cima)
    ang = np.arctan2(yy - C, xx - C)
    dentro = np.asarray(m_buraco).astype(np.float32) / 255
    borda_sup = np.clip(-np.sin(ang), 0, 1) * np.clip(1 - (np.array(raios_rasgo).mean() - d_c) / 6.0, 0, 1) * dentro
    arr[..., :3] *= (1 - 0.5 * borda_sup[..., None])
    im = Image.fromarray(np.clip(arr * 255, 0, 255).astype(np.uint8), "RGBA")
    # aba de papel dobrada para fora (embaixo à direita), com sombra
    a0 = rng.uniform(0.3, 0.9)
    base1 = (C + np.cos(a0) * 24 * S, C + np.sin(a0) * 24 * S)
    base2 = (C + np.cos(a0 + 0.7) * 24 * S, C + np.sin(a0 + 0.7) * 24 * S)
    ponta = (C + np.cos(a0 + 0.35) * 46 * S, C + np.sin(a0 + 0.35) * 46 * S)
    sombra_aba = camada()
    ImageDraw.Draw(sombra_aba).polygon([base1, base2, (ponta[0] + 5 * S, ponta[1] + 6 * S)], fill=(30, 15, 5, 120))
    im.alpha_composite(borrar(sombra_aba, 2.5))
    aba = camada()
    ImageDraw.Draw(aba).polygon([base1, base2, ponta], fill=(222, 205, 168, 255))
    ImageDraw.Draw(aba).line([base1, base2], fill=(160, 140, 105, 255), width=int(1.2 * S))
    im.alpha_composite(aba)
    return im.resize((T, T), Image.LANCZOS)


def main():
    for nome, f in (("bar_furo_madeira.png", furo_madeira), ("bar_furo_papel.png", furo_papel)):
        img = f()
        img.save(os.path.join(SP, nome), optimize=True)
        print("%-24s %dx%d" % (nome, img.width, img.height))


if __name__ == "__main__":
    main()
