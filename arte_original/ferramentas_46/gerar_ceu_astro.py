#!/usr/bin/env python3
"""Céu atrás do sol e da lua do Egito (pôr do sol / nascer da lua).

O disco (com o olho) vem pintado nos fundos egito_fundo_sol/lua.png; quando
o astro desce atrás das pirâmides, no lugar dele tem que aparecer céu. Aqui
se faz esse pedaço de céu sem o disco, para cada fundo:

  sprites/egito_ceu_sol.png / egito_ceu_lua.png   (464x420 em volta de
  CENTRO, borda esfumada, sem a ponta da pirâmide do meio) = a cor do céu
  em volta por inpainting (OpenCV, em escala reduzida: suave) + o detalhe
  das nuvens do céu dos lados.

O jogo põe o pedaço por cima do fundo, atrás do astro, e o mostra conforme
o astro sai do lugar (scripts/deserto_vivo.gd).

    python3 tools/gerar_ceu_astro.py
"""
import os
import cv2
import numpy as np
from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")
CENTRO = (512.0, 300.0)
RX, RY = 182.0, 160.0      # o disco com o olho (as pontas do olho saem do disco)
MEIO_X, MEIO_Y = 232, 210  # metade do pedaço (px)


def pedaco(nome):
    im = np.asarray(Image.open(os.path.join(SP, "egito_fundo_%s.png" % nome)).convert("RGB")).astype(np.float32)
    h, w = im.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dx, dy = xx - CENTRO[0], yy - CENTRO[1]
    e = np.sqrt((dx / RX) ** 2 + (dy / RY) ** 2)          # 1 = borda do buraco
    # a cor vem de um pouco mais longe (fora do brilho forte em volta do disco)
    buraco = (e < 1.3).astype(np.uint8)
    # cor de fundo: inpainting em 1/8 (só a cor, bem suave), de volta ao tamanho
    k = 8
    pq = cv2.resize(im, (w // k, h // k), interpolation=cv2.INTER_AREA).astype(np.uint8)
    mpq = cv2.resize(buraco * 255, (w // k, h // k), interpolation=cv2.INTER_NEAREST)
    mpq = cv2.dilate(mpq, np.ones((3, 3), np.uint8))
    base = cv2.inpaint(pq, mpq, 8, cv2.INPAINT_TELEA)
    base = cv2.resize(base, (w, h), interpolation=cv2.INTER_CUBIC).astype(np.float32)
    base = cv2.GaussianBlur(base, (0, 0), 10)
    # detalhe das nuvens: a textura do céu dos lados (a metade esquerda do
    # buraco pega a de mais à esquerda, a direita a de mais à direita),
    # emendadas no meio sem corte
    hp = im - cv2.GaussianBlur(im, (0, 0), 4)
    desl = 2.0 * RX
    esq = cv2.remap(hp, (xx - desl).astype(np.float32), yy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    dir_ = cv2.remap(hp, (xx + desl).astype(np.float32), yy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    mistura = np.clip((dx + 24.0) / 48.0, 0, 1)[..., None]
    detalhe = esq * (1 - mistura) + dir_ * mistura
    ceu = base + detalhe * 0.85
    # recorte com a borda esfumada (some no fundo de verdade)
    x0, y0 = int(CENTRO[0] - MEIO_X), int(CENTRO[1] - MEIO_Y)
    out = np.clip(ceu[y0:y0 + 2 * MEIO_Y, x0:x0 + 2 * MEIO_X], 0, 255)
    ec = e[y0:y0 + 2 * MEIO_Y, x0:x0 + 2 * MEIO_X]
    alfa = np.clip((1.18 - ec) / 0.18, 0, 1)
    # a ponta da pirâmide do meio fica de fora (é do fundo, com o ouro vivo)
    piramide = np.zeros((h, w), np.uint8)
    cv2.fillPoly(piramide, [np.array([[508, 443], [298, 742], [718, 742]], np.int32)], 255)
    piramide = cv2.GaussianBlur(piramide.astype(np.float32), (0, 0), 0.8) / 255.0
    alfa = alfa * (1.0 - piramide[y0:y0 + 2 * MEIO_Y, x0:x0 + 2 * MEIO_X])
    alfa = alfa * 255
    rgba = np.dstack([out, alfa]).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(os.path.join(SP, "egito_ceu_%s.png" % nome), optimize=True)
    print("egito_ceu_%s.png" % nome, rgba.shape)


if __name__ == "__main__":
    for n in ("sol", "lua"):
        pedaco(n)
