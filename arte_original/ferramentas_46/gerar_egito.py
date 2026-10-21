#!/usr/bin/env python3
"""Artes do Egito (scripts/deserto_vivo.gd).

Parte das imagens originais (pasta passada em --originais, com sol.png e
lua.png de 1024x1536) e gera:

  sprites/deserto_sol.png, deserto_lua.png   fundo com o olho antigo apagado e
                                             o sol/a lua novos (1x, para o menu)
  sprites/egito_pontas.png                   pontas de ouro das 3 pirâmides
                                             (a ponta pintada na foto, dourada)
                                             em 1x na grade do fundo: G=face
                                             B=quina A=cobertura
  sprites/egito_cristal_mascara.png          diamante em 2x: R=corpo
                                             G=arestas B=miolo
  sprites/egito_estrela.png                  brilho em estrela (diamante e
                                             pontas)

O sol e a lua (com os olhos) saem de tools/gerar_astros.py: rodar ele antes.

    git show 89ed8d3:sprites/deserto_sol.png > /tmp/orig/sol.png
    git show 89ed8d3:sprites/deserto_lua.png > /tmp/orig/lua.png
    python3 tools/gerar_astros.py
    python3 tools/gerar_egito.py --originais /tmp/orig
    python3 tools/gerar_egito.py --originais /tmp/orig --so-fundo   (só os fundos)
    python3 tools/gerar_egito.py --originais /tmp/orig --so-pontas  (fundos e pontas de ouro)
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


def apagar_borda_antiga(im, antigo, r_antigo, novo, r_novo):
    """A lua da foto é um pouco maior e mais alta que o disco novo: a beirada
    clara dela que sobra para fora do disco novo vira céu (inpaint)."""
    H, W = im.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W]
    d_a = np.hypot(xx - antigo[0], yy - antigo[1])
    d_n = np.hypot(xx - novo[0], yy - novo[1])
    m = (d_a < r_antigo + 6) & (d_n > r_novo - 3)
    r = int(r_antigo + 30)
    x0, y0 = max(antigo[0] - r, 0), max(antigo[1] - r, 0)
    x1, y1 = min(antigo[0] + r, W), min(antigo[1] + r, H)
    crop = im[y0:y1, x0:x1]
    mc = m[y0:y1, x0:x1]
    cheio = inpaint_biharmonic(crop, ndi.binary_dilation(mc, iterations=2), channel_axis=-1)
    pena = ndi.gaussian_filter(ndi.binary_dilation(mc, iterations=1).astype(np.float32), 1.5)[..., None]
    out = im.copy()
    out[y0:y1, x0:x1] = crop * (1 - pena) + np.clip(cheio, 0, 1) * pena
    return out


# ───────────────────────────────────────────── pontas (1x, na grade da foto)
def pontas(sol_orig):
    """Pontas de ouro = a própria ponta pintada na foto, dourada no jogo.

    A foto já tem o topo de cada pirâmide revestido (mais claro, com a borda
    de baixo quebrada) na luz da cena. A máscara segue exatamente isso: as
    arestas medidas na foto (pelo maior contraste perto de cada aresta) e,
    no lado aceso, a borda quebrada (onde o claro vira pedra); no lado da
    sombra, uma reta da quina até a aresta. O próprio shader do fundo
    (deserto_fundo.gdshader) deixa a pedra em ouro ali: a mesma luz, a mesma
    sombra e a mesma névoa da pirâmide, de dia e de noite.
    Saída em 1x, pixel a pixel na grade do fundo (mesma resolução e mesmo
    filtro da foto, para não parecer uma peça mais nítida colada por cima):
    R = livre, G = face (0,25 esquerda / 0,75 direita), B = quinas (aresta
    da frente e beirada), A = cobertura."""
    x0, y0, x1, y1 = PONTAS_CAIXA
    W, H = x1 - x0, y1 - y0
    im = ler(sol_orig)
    lum = im @ np.array([0.3, 0.59, 0.11], np.float32)
    ls = ndi.gaussian_filter(lum, 1.0)
    gx = np.zeros_like(ls)
    gx[:, 1:-1] = ls[:, 2:] - ls[:, :-2]
    gy = np.zeros_like(ls)
    gy[1:-1] = ls[2:] - ls[:-2]
    gy_borda = np.zeros_like(lum)
    lsv = ndi.gaussian_filter(lum, (1.5, 1.0))
    gy_borda[1:-1] = lsv[2:] - lsv[:-2]

    def inclinacao(A, P, alcance=55):
        ax, ay = A
        d = np.array(P, float) - A
        xs, ys = [], []
        for y in range(ay + 6, ay + alcance):
            xc = ax + d[0] * (y - ay) / d[1]
            lo, hi = int(xc - 14), int(xc + 14)
            g = np.abs(gx[y, lo:hi]) + 0.5 * np.abs(gy[y, lo:hi])
            xs.append(lo + int(np.argmax(g)))
            ys.append(y)
        return float(np.median((np.array(xs, float) - ax) / (np.array(ys, float) - ay)))

    # centro de cada pixel da caixa, em px da imagem
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    X = x0 + xx + 0.5
    Y = y0 + yy + 0.5
    cob = np.zeros((H, W), np.float32)
    face = np.zeros((H, W), np.float32)
    quina = np.zeros((H, W), np.float32)
    poligonos = []
    for A, Lp, M, R in PONTAS:
        ax, ay = A
        ml, mr = inclinacao(A, Lp), inclinacao(A, R)
        # borda quebrada no lado aceso (esquerdo): onde o claro vira pedra
        xs = np.arange(int(ax + ml * 75), ax + 1)
        borda = []
        for x in xs:
            ytop = ay + (x - ax) / ml
            ya, yb = int(ytop + 4), int(max(Lp[1], M[1]) + 12)
            if yb <= ya + 3:
                borda.append(np.nan)
                continue
            borda.append(ya + int(np.argmin(gy_borda[ya:yb, x])))
        borda = np.array(borda, float)
        ok = ~np.isnan(borda)
        borda = np.interp(xs, xs[ok], ndi.median_filter(borda[ok], 9))
        y_quina = float(np.median(borda[-6:]))
        # a beirada só desce de leve para o lado (não escorre pela aresta)
        borda = np.minimum(borda, y_quina + (ax - xs) * 0.42)
        # lado da sombra: reta da quina até a aresta direita (um pouco acima)
        x_fim_dir = ax + mr * (y_quina - 4 - ay)
        def limite(xv):
            esq = np.interp(xv, xs, borda, left=np.nan, right=np.nan)
            dirr = y_quina + (xv - ax) / max(x_fim_dir - ax, 1.0) * (-4.0)
            return np.where(xv <= ax, esq, dirr)
        # dentro da silhueta (1 px para dentro, borda suave) e acima do limite
        d_esq = (X - (ax + ml * (Y - ay))) - 1.0           # > 0 à direita da aresta esquerda
        d_dir = ((ax + mr * (Y - ay)) - X) - 1.0           # > 0 à esquerda da aresta direita
        lim = limite(X)
        d_baixo = np.nan_to_num(lim - Y, nan=-99.0)
        # a beirada de baixo é mais macia (1,5 px), como as bordas pintadas
        dentro = np.clip(np.minimum(np.minimum(d_esq, d_dir) * 1.2, d_baixo * 0.7) + 0.5, 0, 1) * (Y >= ay)
        cob = np.maximum(cob, dentro)
        face = np.where(dentro > 0, np.where(X < ax, 0.25, 0.75), face)
        # quinas: aresta da frente e a beirada de baixo (fininhas)
        q = np.exp(-((X - ax) / 0.9) ** 2) * (Y > ay + 1) * np.clip(1 - (Y - ay) / max(y_quina - ay, 1), 0, 1)
        q = np.maximum(q, np.exp(-(d_baixo / 1.1) ** 2) * 0.7 * (X < ax))
        quina = np.maximum(quina, q * dentro)
        fundo_esq = (float(xs[0]), float(borda[0]))
        poligonos.append([(ax, ay), (round(fundo_esq[0]), round(fundo_esq[1])), (ax, round(y_quina)),
                          (round(x_fim_dir), round(y_quina - 4))])
    # sem detalhe próprio: todo o relevo vem da própria pedra pintada
    gravar(np.dstack([np.zeros_like(cob), face * cob, quina * cob, cob]), "egito_pontas.png", "RGBA")
    print("  ouro (scripts/deserto_vivo.gd OURO):", poligonos)


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
    ap.add_argument("--so-fundo", action="store_true", help="só os fundos com o sol/a lua (depois de gerar_astros.py)")
    ap.add_argument("--so-pontas", action="store_true", help="só os fundos e as pontas de ouro")
    arg = ap.parse_args()
    sol = ler(os.path.join(arg.originais, "sol.png"))
    lua = ler(os.path.join(arg.originais, "lua.png"))
    # fundo sem o olho antigo, com o sol/a lua novos pintados por cima (o que
    # o menu mostra; no jogo as camadas de gerar_astros.py ficam por cima)
    lua_limpa = apagar_borda_antiga(apagar_olho(lua, *LUA, 1.0), LUA[0], LUA[1], (512, 300), 138)
    for limpo, nome in ((apagar_olho(sol, *SOL, 0.6), "sol"), (lua_limpa, "lua")):
        gravar(colar_astro(limpo, nome), "deserto_%s.png" % nome)
    if arg.so_fundo:
        return
    pontas(os.path.join(arg.originais, "sol.png"))
    if arg.so_pontas:
        return
    cristal_2x(os.path.join(arg.originais, "sol.png"))
    estrela()


if __name__ == "__main__":
    main()
