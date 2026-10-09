#!/usr/bin/env python3
"""Gera as máscaras dos fundos vivos (scripts/fundo_vivo.gd).

Cada máscara é RGB, 512x768, no mesmo enquadramento da imagem:
  R = luzes que piscam e pulsam com a música
  G = superfícies que ondulam (chão molhado, água)
  B = brilho grande que acende na batida (alvo, títulos, raios de luz)

    python3 tools/gerar_fundos_vivos.py
"""
import os
import numpy as np
from PIL import Image, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")
W, H = 512, 768
yy, xx = np.mgrid[0:H, 0:W]
U = (xx + 0.5) / W
V = (yy + 0.5) / H


def carregar(nome):
    a = Image.open(os.path.join(SP, nome)).convert("RGB").resize((W, H), Image.LANCZOS)
    return np.asarray(a).astype(np.float32) / 255.0


def suave(m, r):
    img = Image.fromarray((np.clip(m, 0, 1) * 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(r))).astype(np.float32) / 255.0


def caixa(u0, v0, u1, v1, pena=0.02):
    fx = np.clip(np.minimum(U - u0, u1 - U) / pena, 0, 1)
    fy = np.clip(np.minimum(V - v0, v1 - V) / pena, 0, 1)
    return fx * fy


def faixa_v(v0, v1, pena=0.05):
    return np.clip((V - v0) / pena, 0, 1) * np.clip((v1 - V) / pena, 0, 1)


def canais(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    sat = a.max(-1) - a.min(-1)
    return r, g, b, lum, sat


def salvar(nome, R, G, B):
    m = np.stack([np.clip(R, 0, 1), np.clip(G, 0, 1), np.clip(B, 0, 1)], -1)
    Image.fromarray((m * 255).astype(np.uint8)).save(os.path.join(SP, nome))
    print("%-28s R=%.3f G=%.3f B=%.3f" % (nome, R.mean(), G.mean(), B.mean()))


def init():
    a = carregar("fundo_init.png")
    r, g, b, lum, sat = canais(a)
    textos = np.clip(caixa(0.22, 0.04, 0.80, 0.30) + caixa(0.02, 0.77, 0.58, 0.99) + caixa(0.74, 0.0, 1.0, 0.13), 0, 1)
    # luzes do teto e neons (claros ou vermelho forte), fora dos textos
    luz = np.clip((lum - 0.62) / 0.25, 0, 1) + np.clip((r - np.maximum(g, b) - 0.35) / 0.3, 0, 1) * np.clip((r - 0.45) / 0.3, 0, 1)
    R = suave(np.clip(luz, 0, 1) * (1 - textos), 1.5)
    # chão molhado: metade de baixo, menos o LAZER SHOT
    G = suave(faixa_v(0.50, 1.02, 0.08) * (1 - caixa(0.02, 0.77, 0.58, 0.99, 0.03)), 3)
    # batida: alvo e o vermelho dos títulos
    alvo = caixa(0.40, 0.31, 0.60, 0.47, 0.03)
    vermelho_txt = np.clip((r - np.maximum(g, b) - 0.30) / 0.3, 0, 1) * textos
    B = suave(np.clip(alvo * np.clip((lum - 0.25) / 0.4, 0, 1) + vermelho_txt, 0, 1), 2)
    salvar("fundo_init_mascara.png", R, G, B)


def bar():
    a = carregar("back_new.png")
    r, g, b, lum, sat = canais(a)
    R = suave(np.clip((lum - 0.70) / 0.2, 0, 1), 2)            # janela e brilhos
    G = np.zeros_like(lum)
    B = suave(np.clip((lum - 0.55) / 0.3, 0, 1) * faixa_v(0.0, 0.55), 6)
    salvar("back_new_mascara.png", R, G, B)


def mar():
    a = carregar("atlantis.png")
    r, g, b, lum, sat = canais(a)
    azul = np.clip((b - r - 0.10) / 0.3, 0, 1)
    R = suave(np.clip((lum - 0.72) / 0.2, 0, 1) * np.clip((b - 0.5) / 0.3, 0, 1), 2)   # brilhos da água / runas
    G = suave(azul * 0.85, 4)                                                          # água ondula
    B = suave(np.clip((lum - 0.5) / 0.3, 0, 1) * faixa_v(0.0, 0.45), 8)                 # luz da superfície
    salvar("atlantis_mascara.png", R, G, B)


def arena():
    a = carregar("arena.png")
    r, g, b, lum, sat = canais(a)
    neon = np.clip((r - np.maximum(g, b) - 0.30) / 0.3, 0, 1) * np.clip((r - 0.45) / 0.3, 0, 1)
    R = suave(np.clip(neon + np.clip((lum - 0.75) / 0.2, 0, 1), 0, 1), 1.5)
    G = suave(faixa_v(0.80, 1.02, 0.05) * 0.6, 3)
    B = suave(neon, 6)
    salvar("arena_mascara.png", R, G, B)


if __name__ == "__main__":
    init()
    bar()
    mar()
    arena()
