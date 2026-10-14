#!/usr/bin/env python3
"""Fundos em alta (2x) para a TV: impressão de 4K sem estourar a memória.

Cada fundo grande (1024x1536) é refeito em 2048x3072 com uma rede de
super-resolução (EDSR x2, OpenCV dnn_superres), em blocos com sobra (sem
emenda): tools/hd/<nome>@2x.png (a parte demorada, guardada). Daí sai o
tamanho que vai para a TV, 1,5x (1536x2304): na TV 1080p cada texel fica
quase do tamanho do pixel (nítido e sem cintilar quando a câmera anda; numa
saída 4K continua bem mais nítido que antes), com uma nitidez fina por cima:
tools/hd/<nome>@hd.png. O alfa (planos recortados) vai em Lanczos.
Depois tools/gerar_hd.gd comprime cada um em ETC2 em sprites/hd/<nome>.res
com o tamanho antigo junto (scripts/hd.gd: o jogo continua vendo 1024x1536 e
todas as coordenadas em px continuam valendo).

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
    "egito_planos_sol", "egito_planos_lua", "arena", "arena_fixa",
]
ESCALA_TV = 1.5
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


def para_tv(nome):
    """@2x -> @hd: 1,5x em Lanczos (múltiplo de 4, para o ETC2) e nitidez fina."""
    original = Image.open(os.path.join(RAIZ, "sprites", nome + ".png"))
    alta = Image.open(os.path.join(SAIDA, nome + "@2x.png"))
    w, h = original.size
    alvo = (int(round(w * ESCALA_TV / 4.0)) * 4, int(round(h * ESCALA_TV / 4.0)) * 4)
    alfa = alta.getchannel("A").resize(alvo, Image.LANCZOS) if alta.mode == "RGBA" else None
    tv = alta.convert("RGB").resize(alvo, Image.LANCZOS)
    tv = tv.filter(ImageFilter.UnsharpMask(radius=0.8, percent=55, threshold=1))
    if alfa is not None:
        tv.putalpha(alfa)
    tv.save(os.path.join(SAIDA, nome + "@hd.png"), optimize=True)
    print("  tv:", nome, alvo, flush=True)


def main():
    nomes = sys.argv[1:] or FUNDOS
    os.makedirs(SAIDA, exist_ok=True)
    sr = None
    for nome in nomes:
        destino = os.path.join(SAIDA, nome + "@2x.png")
        if os.path.exists(destino):
            para_tv(nome)
            continue
        if sr is None:
            sr = cv2.dnn_superres.DnnSuperResImpl_create()
            sr.readModel(MODELO)
            sr.setModel("edsr", 2)
        im = Image.open(os.path.join(RAIZ, "sprites", nome + ".png"))
        print(nome, im.size, im.mode, flush=True)
        alfa = im.getchannel("A") if im.mode == "RGBA" else None
        bgr = cv2.cvtColor(np.array(im.convert("RGB")), cv2.COLOR_RGB2BGR)
        up = Image.fromarray(cv2.cvtColor(super_res(sr, bgr), cv2.COLOR_BGR2RGB))
        if alfa is not None:
            up.putalpha(alfa.resize(up.size, Image.LANCZOS))
        up.save(destino, optimize=True)
        print("  ->", destino, up.size, flush=True)
        para_tv(nome)


if __name__ == "__main__":
    main()
