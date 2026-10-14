#!/usr/bin/env python3
"""Fundos em alta (2x) para a TV: impressão de 4K sem estourar a memória.

Cada fundo grande (1024x1536) é refeito em 2048x3072 com uma rede de
super-resolução (EDSR x2, OpenCV dnn_superres), em blocos com sobra (sem
emenda), e ganha uma nitidez leve. O alfa (planos recortados) sobe em
Lanczos. O resultado vai para tools/hd/<nome>@2x.png; depois
tools/gerar_hd.gd converte cada um em sprites/hd/<nome>.res (textura ETC2,
comprimida na placa, com size_override no tamanho antigo: o jogo continua
vendo 1024x1536 e todas as coordenadas em px continuam valendo; a placa
recebe o dobro de detalhe e gasta menos memória que o PNG sem perda).

    MODELO=/caminho/EDSR_x2.pb python3 tools/gerar_hd.py [nomes...]
    godot --headless --path . -s tools/gerar_hd.gd

O modelo (EDSR_x2.pb, 38 MB) vem de github.com/Saafke/EDSR_Tensorflow.
"""
import os
import sys
import cv2
import numpy as np
from PIL import Image, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAIDA = os.path.join(RAIZ, "tools", "hd")
MODELO = os.environ.get("MODELO", "EDSR_x2.pb")

# os fundos que cobrem a tela inteira (e os planos do Egito, que ficam
# por cima do fundo e precisam da mesma nitidez)
FUNDOS = [
    "back_new", "atlantis_fundo", "egito_fundo_sol", "egito_fundo_lua",
    "egito_planos_sol", "egito_planos_lua", "arena_fixa",
]
BLOCO = 192
SOBRA = 12


def super_res(sr, rgb):
    h, w = rgb.shape[:2]
    saida = np.zeros((h * 2, w * 2, 3), np.float32)
    peso = np.zeros((h * 2, w * 2, 1), np.float32)
    for y in range(0, h, BLOCO):
        for x in range(0, w, BLOCO):
            y0, x0 = max(0, y - SOBRA), max(0, x - SOBRA)
            y1, x1 = min(h, y + BLOCO + SOBRA), min(w, x + BLOCO + SOBRA)
            up = sr.upsample(np.ascontiguousarray(rgb[y0:y1, x0:x1])).astype(np.float32)
            # janela que some nas sobras (as emendas se misturam)
            hh, ww = up.shape[:2]
            jy = np.minimum(np.arange(hh) + 1, hh - np.arange(hh)).astype(np.float32)
            jx = np.minimum(np.arange(ww) + 1, ww - np.arange(ww)).astype(np.float32)
            jan = np.minimum(np.minimum.outer(jy, jx) / (SOBRA * 2.0), 1.0)[..., None]
            saida[y0 * 2:y1 * 2, x0 * 2:x1 * 2] += up * jan
            peso[y0 * 2:y1 * 2, x0 * 2:x1 * 2] += jan
        print("   linha %d/%d" % (y // BLOCO + 1, (h + BLOCO - 1) // BLOCO), flush=True)
    return np.clip(saida / np.maximum(peso, 1e-6), 0, 255).astype(np.uint8)


def main():
    nomes = sys.argv[1:] or FUNDOS
    os.makedirs(SAIDA, exist_ok=True)
    sr = cv2.dnn_superres.DnnSuperResImpl_create()
    sr.readModel(MODELO)
    sr.setModel("edsr", 2)
    for nome in nomes:
        destino = os.path.join(SAIDA, nome + "@2x.png")
        if os.path.exists(destino):
            print("já existe:", destino)
            continue
        im = Image.open(os.path.join(RAIZ, "sprites", nome + ".png"))
        print(nome, im.size, im.mode, flush=True)
        alfa = im.getchannel("A") if im.mode == "RGBA" else None
        bgr = cv2.cvtColor(np.array(im.convert("RGB")), cv2.COLOR_RGB2BGR)
        up = Image.fromarray(cv2.cvtColor(super_res(sr, bgr), cv2.COLOR_BGR2RGB))
        # nitidez leve (realça o detalhe novo sem halo)
        up = up.filter(ImageFilter.UnsharpMask(radius=1.4, percent=45, threshold=2))
        if alfa is not None:
            up.putalpha(alfa.resize(up.size, Image.LANCZOS))
        up.save(destino, optimize=True)
        print("  ->", destino, up.size, flush=True)


if __name__ == "__main__":
    main()
