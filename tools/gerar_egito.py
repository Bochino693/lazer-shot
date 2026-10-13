#!/usr/bin/env python3
"""Artes do Egito (scripts/deserto_vivo.gd).

Parte das imagens originais (pasta passada em --originais, com sol.png e
lua.png de 1024x1536) e gera:

  sprites/deserto_sol.png, deserto_lua.png   fundo com o olho antigo apagado e
                                             o sol/a lua novos (1x, para o menu)
  sprites/egito_pontas.png                   pontas de ouro das 3 pirâmides
                                             em 2x: R=detalhe G=face B=quina
                                             A=cobertura
  sprites/egito_cristal_mascara.png          diamante em 2x: R=corpo
                                             G=arestas B=miolo
  sprites/egito_estrela.png                  brilho em estrela (diamante e
                                             pontas)

O sol e a lua (com os olhos) saem de tools/gerar_astros.py: rodar ele antes.

    git show 89ed8d3:sprites/deserto_sol.png > /tmp/orig/sol.png
    git show 89ed8d3:sprites/deserto_lua.png > /tmp/orig/lua.png
    python3 tools/gerar_astros.py
    python3 tools/gerar_egito.py --originais /tmp/orig
"""
import argparse
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as ndi
from skimage.restoration import inpaint_biharmonic
from gerar_astros import colar_astro

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")
rng = np.random.default_rng(7)

# disco das fotos originais (centro, raio) em px da imagem 1024x1536: é
# onde o olho antigo é apagado (o sol e a lua novos vêm de gerar_astros.py)
SOL = ((512, 290), 124)
LUA = ((510, 282), 130)
# pontas de ouro: ápice, base esquerda, base da quina da frente, base direita
PONTAS = [((229, 519), (189, 569), (230, 575), (269, 566)),
          ((509, 447), (454, 521), (510, 528), (563, 511)),
          ((774, 519), (737, 573), (775, 577), (815, 563))]
PONTAS_CAIXA = (180, 438, 824, 586)          # região da textura das pontas
CRISTAL_CAIXA = (440, 620, 576, 960)         # região da máscara do diamante


# ───────────────────────────────────────────── utilidades
def ler(caminho):
    return np.asarray(Image.open(caminho).convert("RGB")).astype(np.float32) / 255.0


def gravar(arr, nome, modo=None):
    a = np.clip(arr, 0, 1)
    img = Image.fromarray((a * 255 + 0.5).astype(np.uint8), modo)
    img.save(os.path.join(SP, nome), optimize=True)
    print("%-34s %dx%d" % (nome, img.width, img.height))


def textura_aleatoria(alta, livre, forma, passo=10):
    P = passo * 2
    w = np.hanning(P + 2)[1:-1]
    jan = np.outer(w, w)[..., None]
    H, W = forma[:2]
    out = np.zeros((H + 2 * P, W + 2 * P, 3), np.float32)
    peso = np.zeros((H + 2 * P, W + 2 * P, 1), np.float32)
    ok = livre[:H - P, :W - P] & livre[P:, P:] & livre[:H - P, P:] & livre[P:, :W - P]
    ys, xs = np.nonzero(ok)
    for y in range(-passo, H, passo):
        for x in range(-passo, W, passo):
            k = rng.integers(len(ys))
            sy, sx = ys[k], xs[k]
            out[y + passo:y + passo + P, x + passo:x + passo + P] += alta[sy:sy + P, sx:sx + P] * jan
            peso[y + passo:y + passo + P, x + passo:x + passo + P] += jan
    out = out / np.maximum(peso, 1e-4)
    return out[passo:passo + H, passo:passo + W]


def apagar_olho(im, centro, R, forca_alta):
    lum = im @ np.array([0.3, 0.59, 0.11], np.float32)
    H, W = lum.shape
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.hypot(xx - centro[0], yy - centro[1])
    dif = ndi.grey_closing(lum, size=(31, 31)) - lum
    traco = (dif > 0.16) & (d < R - 8)
    traco &= (np.abs(xx - centro[0]) < R * 0.92) & (yy > centro[1] - R * 0.62) & (yy < centro[1] + R * 0.82)
    traco = ndi.binary_opening(traco, iterations=1)
    lab, n = ndi.label(traco)
    tam = ndi.sum(traco, lab, range(1, n + 1))
    traco = np.isin(lab, 1 + np.nonzero(tam > 40)[0])
    m = ndi.binary_dilation(traco, iterations=5)
    m = ndi.binary_fill_holes(ndi.binary_closing(m, iterations=6)) & (d < R - 3)
    x0, y0, x1, y1 = centro[0] - R, centro[1] - R, centro[0] + R, centro[1] + R
    crop = im[y0:y1, x0:x1]
    mc = m[y0:y1, x0:x1]
    dc = d[y0:y1, x0:x1]
    peq = Image.fromarray((crop * 255).astype(np.uint8)).resize((crop.shape[1] // 2, crop.shape[0] // 2), Image.LANCZOS)
    mp = np.asarray(Image.fromarray(mc.astype(np.uint8) * 255).resize(peq.size, Image.NEAREST)) > 0
    mp = ndi.binary_dilation(mp, iterations=2)
    cheio = inpaint_biharmonic(np.asarray(peq).astype(np.float32) / 255, mp, channel_axis=-1)
    grande = np.asarray(Image.fromarray((np.clip(cheio, 0, 1) * 255).astype(np.uint8)).resize(
        (crop.shape[1], crop.shape[0]), Image.BICUBIC)).astype(np.float32) / 255
    alta = crop - ndi.gaussian_filter(crop, (4, 4, 0))
    livre = (~ndi.binary_dilation(mc, iterations=3)) & (dc < R - 14)
    novo = np.clip(grande + textura_aleatoria(alta, livre, crop.shape) * forca_alta, 0, 1)
    pena = ndi.gaussian_filter(mc.astype(np.float32), 2.0)[..., None]
    out = im.copy()
    out[y0:y1, x0:x1] = crop * (1 - pena) + novo * pena
    return out


# ───────────────────────────────────────────── disco em 2x
def pontas_2x():
    x0, y0, x1, y1 = PONTAS_CAIXA
    W, H = (x1 - x0) * 2, (y1 - y0) * 2
    ss = 4
    f = lambda p: ((p[0] - x0) * 2 * ss, (p[1] - y0) * 2 * ss)
    cob = Image.new("L", (W * ss, H * ss), 0)
    face = Image.new("L", (W * ss, H * ss), 0)
    quina = Image.new("L", (W * ss, H * ss), 0)
    faixa = Image.new("L", (W * ss, H * ss), 0)
    dc, df, dq, dfx = ImageDraw.Draw(cob), ImageDraw.Draw(face), ImageDraw.Draw(quina), ImageDraw.Draw(faixa)
    for A, L, M, R in PONTAS:
        dc.polygon([f(A), f(L), f(M), f(R)], fill=255)
        df.polygon([f(A), f(L), f(M)], fill=64)        # face esquerda
        df.polygon([f(A), f(M), f(R)], fill=192)       # face direita
        # faixa da base (friso) — 16% da altura
        k = 0.84
        Lk = (A[0] + (L[0] - A[0]) * k, A[1] + (L[1] - A[1]) * k)
        Mk = (A[0] + (M[0] - A[0]) * k, A[1] + (M[1] - A[1]) * k)
        Rk = (A[0] + (R[0] - A[0]) * k, A[1] + (R[1] - A[1]) * k)
        dfx.polygon([f(Lk), f(L), f(M), f(Mk)], fill=255)
        dfx.polygon([f(Mk), f(M), f(R), f(Rk)], fill=255)
        larg = 2 * ss
        dq.line([f(A), f(M)], fill=255, width=int(larg * 1.2))
        dq.line([f(A), f(L)], fill=200, width=larg)
        dq.line([f(A), f(R)], fill=150, width=larg)
        dq.line([f(Lk), f(Mk), f(Rk)], fill=170, width=larg)
    red = lambda im: np.asarray(im.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255
    cob, face, quina, faixa = red(cob), red(face), red(quina), red(faixa)
    # detalhe do metal: escovado fino + friso com hieróglifos estilizados
    ruido = ndi.gaussian_filter(rng.standard_normal((H, W)), (0.6, 3.0))
    ruido = ruido / (np.abs(ruido).max() + 1e-6)
    det = 0.62 + 0.10 * ruido
    yy, xx = np.mgrid[0:H, 0:W]
    marcas = (np.sin(xx * 0.9) > 0.55) & (np.sin(yy * 1.7 + xx * 0.12) > -0.2)
    det = det - faixa * marcas * 0.22 + faixa * 0.08
    gravar(np.dstack([det * cob, face, quina, cob]), "egito_pontas.png", "RGBA")


# ───────────────────────────────────────────── diamante (2x)
def cristal_2x(sol_m):
    x0, y0, x1, y1 = CRISTAL_CAIXA
    W, H = (x1 - x0) * 2, (y1 - y0) * 2
    orig = Image.open(sol_m).convert("RGB")
    reg = orig.crop((x0, y0, x1, y1)).resize((W, H), Image.LANCZOS)
    a = np.asarray(reg).astype(np.float32) / 255
    lum = a @ np.array([0.3, 0.59, 0.11], np.float32)
    # corpo do cristal: polígono do contorno (px da imagem)
    corpo = Image.new("L", (W * 4, H * 4), 0)
    pts = [(506, 632), (549, 712), (556, 742), (556, 946), (459, 946), (456, 742), (463, 712)]
    ImageDraw.Draw(corpo).polygon([((x - x0) * 8, (y - y0) * 8) for x, y in pts], fill=255)
    corpo = np.asarray(corpo.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255
    # arestas: o que é mais claro que a vizinhança (linhas das facetas)
    arestas = np.clip((lum - ndi.gaussian_filter(lum, 5)) * 6.0, 0, 1) * corpo
    arestas = ndi.gaussian_filter(arestas, 0.8)
    miolo = np.clip(1 - np.hypot((np.mgrid[0:H, 0:W][1] - W * 0.5) / (W * 0.30),
                                 (np.mgrid[0:H, 0:W][0] - H * 0.55) / (H * 0.42)), 0, 1) * corpo
    gravar(np.dstack([corpo, arestas, miolo]), "egito_cristal_mascara.png", "RGB")


def estrela():
    N = 128
    yy, xx = (np.mgrid[0:N, 0:N] + 0.5 - N / 2) / (N / 2)
    r = np.hypot(xx, yy)
    raio4 = np.exp(-np.abs(xx) * 34) * np.clip(1 - np.abs(yy), 0, 1) ** 2 + np.exp(-np.abs(yy) * 34) * np.clip(1 - np.abs(xx), 0, 1) ** 2
    u, v = (xx + yy) * 0.7071, (xx - yy) * 0.7071
    raio_d = (np.exp(-np.abs(u) * 40) * np.clip(1 - np.abs(v) * 1.8, 0, 1) ** 2 + np.exp(-np.abs(v) * 40) * np.clip(1 - np.abs(u) * 1.8, 0, 1) ** 2) * 0.45
    miolo = np.exp(-r * r * 60) + 0.35 * np.exp(-r * r * 9)
    a = np.clip(raio4 + raio_d + miolo, 0, 1) * np.clip(1 - r, 0, 1) ** 0.5
    gravar(np.dstack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a]), "egito_estrela.png", "RGBA")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--originais", required=True)
    arg = ap.parse_args()
    sol = ler(os.path.join(arg.originais, "sol.png"))
    lua = ler(os.path.join(arg.originais, "lua.png"))
    # fundo sem o olho antigo, com o sol/a lua novos pintados por cima (o que
    # o menu mostra; no jogo as camadas de gerar_astros.py ficam por cima)
    for limpo, nome in ((apagar_olho(sol, *SOL, 0.6), "sol"), (apagar_olho(lua, *LUA, 1.0), "lua")):
        gravar(colar_astro(limpo, nome), "deserto_%s.png" % nome)
    pontas_2x()
    cristal_2x(os.path.join(arg.originais, "sol.png"))
    estrela()


if __name__ == "__main__":
    main()
