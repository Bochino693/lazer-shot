#!/usr/bin/env python3
"""Artes do Egito (scripts/deserto_vivo.gd).

Parte das imagens originais (pasta passada em --originais, com sol.png e
lua.png de 1024x1536) e gera:

  sprites/deserto_sol.png, deserto_lua.png   fundo com o olho antigo apagado e
                                             o olho novo (1x, para o menu)
  sprites/egito_disco_sol.png, _lua.png      sol/lua em 2x com o olho novo
                                             (nítido em 4K), alfa na borda
  sprites/egito_disco_mascara_sol.png, _lua  R=traços do olho G=pupila
                                             B=disco A=branco do olho
  sprites/egito_pontas.png                   pontas de ouro das 3 pirâmides
                                             em 2x: R=detalhe G=face B=quina
                                             A=cobertura
  sprites/egito_cristal_mascara.png          diamante em 2x: R=corpo
                                             G=arestas B=miolo
  sprites/egito_estrela.png                  brilho em estrela (diamante e
                                             pontas)

Olho de Rá no sol (olho direito: olha para a direita, rabo para a
esquerda) e Olho de Hórus na lua (olho esquerdo: olha para a esquerda,
rabo para a direita), os dois completos no traçado do hieróglifo D10
(U+13080): sobrancelha, pálpebras, pupila, rabo, lágrima e espiral.

    git show 89ed8d3:sprites/deserto_sol.png > /tmp/orig/sol.png
    git show 89ed8d3:sprites/deserto_lua.png > /tmp/orig/lua.png
    python3 tools/gerar_egito.py --originais /tmp/orig
"""
import argparse
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as ndi
from skimage.restoration import inpaint_biharmonic

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")
rng = np.random.default_rng(7)

# disco (centro, raio) em px da imagem 1024x1536
SOL = ((512, 290), 124)
LUA = ((510, 282), 130)
# janela do disco em 2x: quadrado de lado 2*JANELA px da imagem
JANELA = 172
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


def bezier(p, n=60):
    P = np.asarray(p, float)
    pts = []
    for t in np.linspace(0, 1, n):
        q = P.copy()
        while len(q) > 1:
            q = (1 - t) * q[:-1] + t * q[1:]
        pts.append(q[0])
    return np.array(pts)


def corrente(*curvas):
    return np.vstack([curvas[0]] + [c[1:] for c in curvas[1:]])


def tira(linha, perfil):
    L = np.asarray(linha, float)
    seg = np.diff(L, axis=0)
    comp = np.r_[0, np.cumsum(np.hypot(seg[:, 0], seg[:, 1]))]
    t = comp / comp[-1]
    tang = np.gradient(L, axis=0)
    tang /= np.hypot(tang[:, 0], tang[:, 1])[:, None] + 1e-9
    nor = np.stack([-tang[:, 1], tang[:, 0]], 1)
    w = np.asarray(perfil(t), float)
    return np.vstack([L + nor * (w[:, None] / 2), (L - nor * (w[:, None] / 2))[::-1]])


def suave(a, b, t):
    return a + (b - a) * (3 * t * t - 2 * t * t * t)


# ───────────────────────────────────────────── o olho (wedjat, D10)
# Unidades: canto interno em x=-1, rabo em x=+1, y para baixo (olho de Hórus).
CIMA = [(-0.91, 0.15), (-0.50, -0.27), (0.38, -0.34), (0.80, 0.08)]
RABO = [(0.80, 0.08), (0.88, 0.15), (0.95, 0.185), (1.03, 0.19)]
BAIXO = [(-0.91, 0.13), (-0.45, 0.27), (0.35, 0.31), (0.78, 0.085)]
PUPILA = ((-0.045, -0.005), 0.235)
CAIXA_OLHO = (-1.04, -0.52, 1.06, 1.31)


def tracos_olho():
    tr = []
    # sobrancelha: arco por cima, mais grossa e reta atrás
    sob = bezier([(-1.02, 0.05), (-0.62, -0.50), (0.40, -0.62), (1.03, -0.02)], 160)
    tr.append(tira(sob, lambda t: suave(0.05, 0.10, np.clip(t * 1.6, 0, 1))))
    # pálpebra de cima, do bico do canto interno até o rabo
    cima = corrente(bezier([(-1.03, 0.205), (-0.98, 0.18), (-0.95, 0.165), (-0.91, 0.15)], 12),
                    bezier(CIMA, 160), bezier(RABO, 50))
    tr.append(tira(cima, lambda t: np.where(t < 0.08, suave(0.04, 0.08, t / 0.08),
                                            0.08 + 0.02 * np.clip((t - 0.7) / 0.3, 0, 1))))
    # pálpebra de baixo
    tr.append(tira(bezier(BAIXO, 160), lambda t: 0.05 + 0.02 * np.sin(np.pi * t)))
    # lágrima: a vela que desce de baixo da pupila
    esq = corrente(bezier([(-0.105, 0.27), (-0.10, 0.40), (-0.12, 0.50), (-0.30, 0.585)], 40),
                   bezier([(-0.30, 0.585), (-0.22, 0.70), (-0.13, 0.95), (-0.085, 1.27)], 60))
    tr.append(np.vstack([[(-0.015, 0.27)], esq, [(-0.015, 1.27)]]))
    # espiral: reta em diagonal para trás que enrola no fim
    esp = corrente(np.linspace((0.035, 0.27), (0.66, 1.16), 50),
                   bezier([(0.66, 1.16), (0.72, 1.25), (0.86, 1.30), (0.97, 1.18)], 40),
                   bezier([(0.97, 1.18), (1.05, 1.06), (0.95, 0.92), (0.83, 0.95)], 40),
                   bezier([(0.83, 0.95), (0.74, 0.98), (0.72, 1.07), (0.79, 1.08)], 30))
    tr.append(tira(esp, lambda t: np.where(t < 0.85, 0.07, 0.07 - 0.032 * (t - 0.85) / 0.15)))
    return tr


def mascaras_olho(tam, centro, escala, espelhar, ss=4):
    """Máscaras 0..1 (traco, pupila, brilho, branco) do símbolo inteiro
    centrado em `centro` (px), `escala` px por unidade."""
    W, H = tam
    cx = (CAIXA_OLHO[0] + CAIXA_OLHO[2]) / 2
    cy = (CAIXA_OLHO[1] + CAIXA_OLHO[3]) / 2

    def p(x, y):
        x -= cx
        y -= cy
        if espelhar:
            x = -x
        return ((centro[0] + x * escala) * ss, (centro[1] + y * escala) * ss)

    img = {k: Image.new("L", (W * ss, H * ss), 0) for k in ("traco", "pupila", "brilho", "branco")}
    d = ImageDraw.Draw(img["traco"])
    for poli in tracos_olho():
        d.polygon([p(*q) for q in poli], fill=255)
    olho = np.vstack([bezier(CIMA, 160), bezier(BAIXO, 160)[::-1]])
    ImageDraw.Draw(img["branco"]).polygon([p(*q) for q in olho], fill=255)

    def circ(c, r):
        x, y = p(*c)
        rr = r * escala * ss
        return [x - rr, y - rr, x + rr, y + rr]

    ImageDraw.Draw(img["pupila"]).ellipse(circ(*PUPILA), fill=255)
    # reflexo sempre no alto, do lado de onde o olho olha
    lado = 0.075 if espelhar else -0.075
    ImageDraw.Draw(img["brilho"]).ellipse(circ((PUPILA[0][0] + (-lado if espelhar else lado), PUPILA[0][1] - 0.085), 0.06), fill=255)
    out = {k: np.asarray(v.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255 for k, v in img.items()}
    out["pupila"] = np.minimum(out["pupila"], out["branco"])
    out["brilho"] = np.minimum(out["brilho"], out["pupila"])
    return out


def relevo(m, raio, luz=(-0.55, -0.83)):
    h = ndi.gaussian_filter(m, raio)
    gy, gx = np.gradient(h)
    return np.clip(-(gx * luz[0] + gy * luz[1]) * 2.4 / max(raio, 0.5) * 2.5, -1, 1)


ESTILO_RA = dict(halo=(1.0, 0.93, 0.62), halo_forca=0.55, branco=(1.0, 0.97, 0.86), branco_a=0.6,
                 pupila=(0.40, 0.17, 0.02), pupila_luz=(0.60, 0.45, 0.20),
                 cima=(0.86, 0.56, 0.10), baixo=(0.64, 0.33, 0.03),
                 luz=(0.45, 0.42, 0.25), sombra=(0.34, 0.20, 0.03), reflexo=(1.0, 0.98, 0.86))
ESTILO_HORUS = dict(halo=(0.70, 0.86, 1.0), halo_forca=0.45, branco=(0.88, 0.93, 1.0), branco_a=0.5,
                    pupila=(0.05, 0.07, 0.13), pupila_luz=(0.40, 0.52, 0.72),
                    cima=(0.18, 0.23, 0.36), baixo=(0.10, 0.13, 0.22),
                    luz=(0.60, 0.72, 0.92), sombra=(0.06, 0.07, 0.10), reflexo=(0.93, 0.97, 1.0))


def pintar_olho(im, centro, R, espelhar, est, px_por_img):
    """Pinta o olho em `im` (float RGB). px_por_img = 1 (fundo) ou 2 (disco 2x)."""
    H, W = im.shape[:2]
    S = 0.633 * R * px_por_img
    m = mascaras_olho((W, H), centro, S, espelhar)
    tr, pu, br, bi = m["traco"], m["pupila"], m["branco"], m["brilho"]
    todo = np.clip(tr + pu, 0, 1)
    halo = ndi.gaussian_filter(todo, 3.5 * px_por_img)
    im = 1 - (1 - im) * (1 - np.clip(halo * est["halo_forca"], 0, 1)[..., None] * np.array(est["halo"]))
    a = (br * (1 - tr))[..., None] * est["branco_a"]
    im = im * (1 - a) + np.array(est["branco"]) * a
    rel = relevo(pu, 1.2 * px_por_img)
    cor = np.array(est["pupila"]) + np.clip(rel, 0, 1)[..., None] * np.array(est["pupila_luz"])
    a = pu[..., None]
    im = im * (1 - a) + np.clip(cor, 0, 1) * a
    rel = relevo(tr, 0.9 * px_por_img)
    yy = np.mgrid[0:H, 0:W][0].astype(np.float32)
    g = np.clip((yy - (centro[1] - R * px_por_img)) / (2 * R * px_por_img), 0, 1)[..., None]
    base = np.array(est["cima"]) * (1 - g) + np.array(est["baixo"]) * g
    cor = base + np.clip(rel, 0, 1)[..., None] * np.array(est["luz"]) - np.clip(-rel, 0, 1)[..., None] * np.array(est["sombra"])
    a = tr[..., None]
    im = im * (1 - a) + np.clip(cor, 0, 1) * a
    a = bi[..., None] * 0.95
    im = im * (1 - a) + np.array(est["reflexo"]) * a
    return np.clip(im, 0, 1), m


# ───────────────────────────────────────────── apagar o olho antigo
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
def disco_2x(limpo, centro, R, espelhar, est, nome):
    x0, y0 = centro[0] - JANELA, centro[1] - JANELA
    reg = limpo[y0:y0 + 2 * JANELA, x0:x0 + 2 * JANELA]
    img = Image.fromarray((reg * 255 + 0.5).astype(np.uint8)).resize((4 * JANELA, 4 * JANELA), Image.LANCZOS)
    img = img.filter(ImageFilter.UnsharpMask(radius=2.0, percent=60, threshold=2))
    arr = np.asarray(img).astype(np.float32) / 255
    c2 = (2 * JANELA, 2 * JANELA)
    arr, m = pintar_olho(arr, c2, R, espelhar, est, 2)
    yy, xx = np.mgrid[0:4 * JANELA, 0:4 * JANELA]
    d = np.hypot(xx + 0.5 - c2[0], yy + 0.5 - c2[1]) / 2.0     # em px da imagem
    alfa = np.clip((R + 10 - d) / 10.0, 0, 1)                  # disco + borda suave
    gravar(np.dstack([arr, alfa]), "egito_disco_%s.png" % nome, "RGBA")
    disco = np.clip((R - d) / 3.0, 0, 1)
    gravar(np.dstack([m["traco"], m["pupila"], disco, m["branco"] * (1 - m["traco"])]),
           "egito_disco_mascara_%s.png" % nome, "RGBA")


# ───────────────────────────────────────────── pontas de ouro (2x)
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
    sol_limpo = apagar_olho(sol, *SOL, 0.6)
    lua_limpo = apagar_olho(lua, *LUA, 1.0)
    for limpo, (c, R), esp, est, nome in [(sol_limpo, SOL, True, ESTILO_RA, "sol"),
                                          (lua_limpo, LUA, False, ESTILO_HORUS, "lua")]:
        fundo, _ = pintar_olho(limpo, c, R, esp, est, 1)
        gravar(fundo, "deserto_%s.png" % nome)
        disco_2x(limpo, c, R, esp, est, nome)
    pontas_2x()
    cristal_2x(os.path.join(arg.originais, "sol.png"))
    estrela()


if __name__ == "__main__":
    main()
