#!/usr/bin/env python3
"""Arte da rodada FIXA da Arena (troca de arte que avisa a mecânica nova).

  sprites/arena_fixa.png   o mesmo fundo (sprites/arena.png) com o neon
                           vermelho trocado:
      - letreiro LAZER SHOT, estrelas e traço: degradê nas 5 cores da ordem
        dos tiros, da esquerda para a direita (azul, verde, amarelo,
        vermelho, roxo)
      - aros dos 9 furos: neon frio (branco-azulado), furo vazio esperando
      - giroflex do alto e lampiões das laterais: roxo

O resto da parede fica igual (o jogo cruza de uma para a outra).

    python3 tools/gerar_arena_fixa.py
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")

CORES = np.array([
    (0.25, 0.62, 1.00),   # azul
    (0.25, 1.00, 0.35),   # verde
    (1.00, 0.86, 0.15),   # amarelo
    (1.00, 0.14, 0.10),   # vermelho
    (0.78, 0.32, 1.00),   # roxo
], np.float32)
FRIO = np.array([0.70, 0.88, 1.00], np.float32)
ROXO = np.array([0.80, 0.35, 1.00], np.float32)


def degrade(x):
    """x 0..1 -> cor das 5 da ordem, misturando entre vizinhas."""
    p = np.clip(x, 0, 1) * (len(CORES) - 1)
    i = np.clip(np.floor(p).astype(int), 0, len(CORES) - 2)
    f = (p - i)[..., None]
    f = f * f * (3 - 2 * f)
    return CORES[i] * (1 - f) + CORES[i + 1] * f


def main():
    base = np.asarray(Image.open(os.path.join(SP, "arena.png")).convert("RGB")).astype(np.float32) / 255
    h, w = base.shape[:2]
    masc = np.asarray(Image.open(os.path.join(SP, "arena_mascara.png")).convert("RGB").resize((w, h), Image.BILINEAR)).astype(np.float32) / 255
    r, g, b = base[..., 0], base[..., 1], base[..., 2]
    vermelho = np.clip((r - np.maximum(g, b)) / 0.35, 0, 1)                  # quanto é neon vermelho
    claro = np.clip((r + g + b) / 3.0, 0, 1)
    perto = ndi.maximum_filter(np.maximum(masc[..., 0], masc[..., 2]), size=9) > 0.04
    neon = np.clip(vermelho * 1.2, 0, 1) * perto
    # miolo quase branco das letras/aros também troca de tom (fica tingido)
    miolo = np.clip((claro - 0.55) / 0.35, 0, 1) * (ndi.maximum_filter(neon, size=7) > 0.3) * perto
    peso = np.maximum(neon, miolo * 0.6)

    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cor = np.zeros_like(base)
    letreiro = (yy < h * 0.335) & (xx > w * 0.10) & (xx < w * 0.90)
    cor[letreiro] = degrade((xx[letreiro] - w * 0.12) / (w * 0.76))
    furos = (yy >= h * 0.335) & (yy < h * 0.83) & (xx > w * 0.08) & (xx < w * 0.80)
    cor[furos] = FRIO
    lampioes = (yy < h * 0.335) & ~letreiro
    cor[lampioes] = ROXO
    giroflex = (np.abs(xx - w * 0.5) < w * 0.05) & (yy < h * 0.15)
    cor[giroflex] = ROXO
    # extintores, placas e caixas ficam como são
    peso_regiao = (letreiro | furos | lampioes | giroflex).astype(np.float32)

    # mantém o brilho do pixel; neon forte fica saturado, miolo fica claro
    lum = np.maximum(r, np.maximum(g, b))[..., None]
    novo = cor * lum * 1.08 + (lum - cor * lum) * 0.0
    novo = novo + miolo[..., None] * claro[..., None] * 0.35
    peso = peso * peso_regiao
    out = base * (1 - peso[..., None]) + np.clip(novo, 0, 1) * peso[..., None]
    Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(SP, "arena_fixa.png"), optimize=True)
    print("arena_fixa.png %dx%d" % (w, h))


if __name__ == "__main__":
    main()
