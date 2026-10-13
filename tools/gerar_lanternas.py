#!/usr/bin/env python3
"""Lanternas da Arena nas cores da sequência, a partir da vermelha original
(sprites/lanternas.png).

  sprites/arena_lanternas.png   folha 6 x 2 de 369x358:
      colunas  0 apagada, 1 azul, 2 verde, 3 amarelo, 4 vermelho, 5 roxo
      linhas   0 acesa (idle), 1 quebrando (hit)

A ordem das cores é a ordem dos tiros: azul = 1º, verde = 2º, amarelo = 3º,
vermelho = 4º, roxo = 5º. A apagada é a lanterna parada, esperando.

O neon (tons vermelhos saturados) troca de matiz e o metal da caixa fica
como está; na apagada o neon vira vidro escuro com um reflexo frio.

    python3 tools/gerar_lanternas.py
"""
import os
import numpy as np
from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")
W, H = 369, 358
QUADROS = {"idle": (369, 0), "hit": (1107, 0)}

# matiz alvo, ganho de saturação, ganho de brilho
CORES = [
    ("azul", 0.575, 1.00, 1.08),
    ("verde", 0.355, 0.95, 1.05),
    ("amarelo", 0.145, 0.95, 1.22),
    ("vermelho", None, 1.0, 1.0),
    ("roxo", 0.790, 0.92, 1.12),
]


def rgb_hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rr = m & (mx == r)
    gg = m & (mx == g) & ~rr
    bb = m & ~rr & ~gg
    h[rr] = ((g - b)[rr] / d[rr]) % 6
    h[gg] = (b - r)[gg] / d[gg] + 2
    h[bb] = (r - g)[bb] / d[bb] + 4
    h = h / 6.0
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0)
    return h, s, mx


def hsv_rgb(h, s, v):
    i = np.floor(h * 6).astype(int) % 6
    f = h * 6 - np.floor(h * 6)
    p = v * (1 - s)
    q = v * (1 - f * s)
    t = v * (1 - (1 - f) * s)
    out = np.zeros(h.shape + (3,), np.float32)
    for k, (a, b, c) in enumerate([(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]):
        sel = i == k
        out[sel, 0] = a[sel]
        out[sel, 1] = b[sel]
        out[sel, 2] = c[sel]
    return out


def neon(h, s, v):
    """Quanto o pixel é neon: tons vermelho/laranja saturados e claros."""
    dh = np.minimum(np.abs(h), np.abs(h - 1.0))
    perto = np.clip(1 - (dh - 0.06) / 0.06, 0, 1)
    return perto * np.clip((s - 0.18) / 0.25, 0, 1) * np.clip((v - 0.10) / 0.15, 0, 1)


def recolorir(arr, cor):
    rgb, a = arr[..., :3], arr[..., 3]
    h, s, v = rgb_hsv(rgb)
    n = neon(h, s, v)
    nome, alvo, ks, kv = cor
    if nome == "vermelho":
        return arr
    dh = np.where(h > 0.5, h - 1.0, h)                  # -0.06..0.06 em volta do vermelho
    h2 = (alvo + dh * 0.8) % 1.0
    s2 = np.clip(s * ks, 0, 1)
    v2 = np.clip(v * kv, 0, 1)
    novo = hsv_rgb(h2, s2, v2)
    # o miolo quase branco ganha um toque da cor
    miolo = np.clip((v - 0.85) / 0.15, 0, 1) * np.clip((0.45 - s) / 0.45, 0, 1)
    tinta = hsv_rgb(np.full_like(h, alvo), np.full_like(h, 0.22), v)
    rgb2 = rgb * (1 - n[..., None]) + novo * n[..., None]
    rgb2 = rgb2 * (1 - miolo[..., None] * 0.7) + tinta * (miolo[..., None] * 0.7)
    return np.dstack([np.clip(rgb2, 0, 1), a])


def apagar(arr):
    """Neon desligado: vidro escuro, o desenho do alvo só sugerido e um
    reflexo frio no alto do vidro."""
    rgb, a = arr[..., :3], arr[..., 3]
    h, s, v = rgb_hsv(rgb)
    n = np.maximum(neon(h, s, v), np.clip((v - 0.85) / 0.15, 0, 1) * np.clip((0.45 - s) / 0.45, 0, 1))
    cinza = np.stack([v, v, v], -1)
    vidro = cinza * 0.20 + np.array([0.035, 0.04, 0.05])
    vidro = vidro + np.array([0.10, 0.06, 0.06]) * (v[..., None] ** 2) * 0.35
    yy, xx = np.mgrid[0:arr.shape[0], 0:arr.shape[1]].astype(np.float32)
    cx, cy = arr.shape[1] / 2, arr.shape[0] * 0.5
    reflexo = np.exp(-(((xx - cx + 30) / 70) ** 2 + ((yy - cy + 52) / 26) ** 2)) * 0.22
    vidro = vidro + np.array([0.75, 0.82, 0.95]) * reflexo[..., None]
    rgb2 = rgb * (1 - n[..., None]) + vidro * n[..., None]
    return np.dstack([np.clip(rgb2, 0, 1), a])


def main():
    folha = Image.open(os.path.join(SP, "lanternas.png")).convert("RGBA")
    quadros = {k: np.asarray(folha.crop((x, y, x + W, y + H))).astype(np.float32) / 255 for k, (x, y) in QUADROS.items()}
    saida = np.zeros((H * 2, W * 6, 4), np.float32)
    for linha, k in enumerate(("idle", "hit")):
        saida[linha * H:(linha + 1) * H, 0:W] = apagar(quadros[k])
        for i, cor in enumerate(CORES):
            saida[linha * H:(linha + 1) * H, (i + 1) * W:(i + 2) * W] = recolorir(quadros[k], cor)
    Image.fromarray((saida * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(SP, "arena_lanternas.png"), optimize=True)
    print("arena_lanternas.png %dx%d" % (saida.shape[1], saida.shape[0]))


if __name__ == "__main__":
    main()
