#!/usr/bin/env python3
"""Artes dos efeitos da Rodada 17 (Mar e Egito).

Gera (em sprites/):
  (mar_cavalo.png agora é o espírito de tools/gerar_cavalo_espirito.py; o
   cavalo de jade antigo daqui não é mais gravado)
  fx_fumaca.png         nuvem macia (fumaça da bomba, poeira e areia; tingida
                        no jogo)
  fx_onda.png           anel de choque (explosão debaixo d'água)
  fx_furo_areia.png     furo de bala na areia (cratera vista um pouco de cima)
  fx_furo_pedra.png     furo de bala na pedra (buraco com rachaduras)
  mar_caustica.png      luz cáustica (as linhas de luz que a água faz no chão),
                        emenda nos quatro lados
  mar_facho.png         facho de luz que desce da superfície

Uso:
    python3 tools/gerar_fx.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as ndi

AQUI = os.path.dirname(os.path.abspath(__file__))
SPRITES = os.path.join(AQUI, "..", "sprites")
rng = np.random.default_rng(17)


def gravar(arr, nome):
    a = np.clip(arr, 0, 1)
    img = Image.fromarray((a * 255 + 0.5).astype(np.uint8), "RGBA" if a.shape[-1] == 4 else "L")
    img.save(os.path.join(SPRITES, nome), optimize=True)
    print(f"  {nome:24s} {img.width}x{img.height}")


def ruido(forma, escalas, semente):
    g = np.random.default_rng(semente)
    tot = np.zeros(forma, np.float32)
    for s, peso in escalas:
        tot += ndi.gaussian_filter(g.standard_normal(forma), s, mode="wrap") * peso
    tot -= tot.min()
    return tot / max(tot.max(), 1e-6)


# ───────────────────────────────────────────── cavalo-marinho de jade
def _catmull(pts, n=12):
    pts = [pts[0]] + pts + [pts[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = (np.array(pts[j], float) for j in (i - 1, i, i + 1, i + 2))
        for t in np.linspace(0, 1, n, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(np.array(pts[-2], float))
    return np.array(out)


def cavalo():
    W, H, E = 200, 320, 4
    w, h = W * E, H * E
    # espinha: (x, y, raio) da cabeça até a ponta do rabo enrolado
    esp = [(112, 58, 25), (98, 86, 17), (100, 116, 25), (108, 152, 30), (102, 188, 23), (88, 214, 16),
           (76, 238, 11), (72, 260, 8.5), (82, 279, 7), (100, 278, 5.5), (106, 263, 4.5), (97, 252, 3.6), (90, 258, 2.8)]
    linha = _catmull([(x, y, r) for x, y, r in esp], 16)
    corpo = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(corpo)
    for x, y, r in linha:
        d.ellipse([(x - r) * E, (y - r) * E, (x + r) * E, (y + r) * E], fill=255)
    # focinho (tubo) e a boca
    for t in np.linspace(0, 1, 40):
        x, y = 118 + 50 * t, 60 + 13 * t
        r = 7.5 - 1.5 * t
        d.ellipse([(x - r) * E, (y - r) * E, (x + r) * E, (y + r) * E], fill=255)
    d.ellipse([(166 - 7) * E, (73 - 6) * E, (166 + 7) * E, (73 + 6) * E], fill=255)
    # coroa (espinhos no alto da cabeça) e espinhos das costas
    for bx, by, ang in [(100, 36, -0.5), (110, 31, -0.1), (121, 34, 0.35)]:
        ponta = (bx + 14 * np.sin(ang), by - 14 * np.cos(ang))
        d.polygon([((bx - 5) * E, (by + 4) * E), (ponta[0] * E, ponta[1] * E), ((bx + 5) * E, (by + 4) * E)], fill=255)
    for i in range(6, len(linha) - 30, 9):
        x, y, r = linha[i]
        x0, y0, _ = linha[max(i - 2, 0)]
        x1, y1, _ = linha[min(i + 2, len(linha) - 1)]
        tx, ty = x1 - x0, y1 - y0
        n = np.hypot(tx, ty) + 1e-6
        nx, ny = ty / n, -tx / n          # lado de fora (costas, à esquerda)
        if nx > 0:
            nx, ny = -nx, -ny
        b = (x + nx * r, y + ny * r)
        p = (x + nx * (r + 7), y + ny * (r + 7) - 3)
        d.polygon([((b[0] - ty / n * 3.5) * E, (b[1] + tx / n * 3.5) * E), (p[0] * E, p[1] * E),
                   ((b[0] + ty / n * 3.5) * E, (b[1] - tx / n * 3.5) * E)], fill=255)
    m = np.asarray(corpo.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255

    # barbatana das costas: leque translúcido (borda recortada) com raios
    fin = Image.new("L", (w, h), 0)
    df = ImageDraw.Draw(fin)
    cx, cy, rf = 80.0, 142.0, 30.0
    pts = [(cx * E, cy * E)]
    for k in range(41):
        ang = np.radians(118 + 124 * k / 40)
        rr = rf * (0.92 + 0.08 * np.cos(k * 1.9))
        pts.append(((cx + np.cos(ang) * rr) * E, (cy - np.sin(ang) * rr) * E))
    df.polygon(pts, fill=255)
    fin_m = np.asarray(fin.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255
    raios = Image.new("L", (W * E, H * E), 0)
    dr = ImageDraw.Draw(raios)
    for k in range(9):
        ang = np.radians(122 + 116 * k / 8)
        dr.line([(cx * E, cy * E), ((cx + np.cos(ang) * rf * 0.95) * E, (cy - np.sin(ang) * rf * 0.95) * E)], fill=255, width=E)
    raios_m = np.asarray(raios.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255 * fin_m

    # volume: distância até a borda vira altura (luz de cima e da esquerda)
    alt = ndi.distance_transform_edt(m > 0.5)
    alt = np.sqrt(np.clip(alt / 14.0, 0, 1))
    alt = ndi.gaussian_filter(alt, 1.0)
    gy, gx = np.gradient(alt)
    nz = 0.35
    norma = np.sqrt(gx * gx + gy * gy + nz * nz)
    luz = np.clip((-gx * -0.55 + -gy * -0.75 + nz * 0.6) / norma, 0, 1)
    espec = np.clip(luz, 0, 1) ** 18

    # anéis do corpo (sulcos), escuros
    aneis = Image.new("L", (W, H), 0)
    da = ImageDraw.Draw(aneis)
    for i in range(20, len(linha) - 8, 7):
        x, y, r = linha[i]
        x0, y0, _ = linha[i - 2]
        x1, y1, _ = linha[i + 2]
        tx, ty = x1 - x0, y1 - y0
        n = np.hypot(tx, ty) + 1e-6
        nx, ny = ty / n, -tx / n
        da.line([(x - nx * r * 0.95, y - ny * r * 0.95), (x + nx * r * 0.95, y + ny * r * 0.95)], fill=255, width=1)
    aneis_m = np.asarray(aneis.filter(ImageFilter.GaussianBlur(0.5))).astype(np.float32) / 255 * m

    jade_esc = np.array([0.02, 0.32, 0.28])
    jade = np.array([0.16, 0.78, 0.62])
    jade_cla = np.array([0.70, 1.0, 0.88])
    veio = ruido((H, W), ((2.0, 1.0), (6.0, 0.6)), 3)
    xx_c = np.mgrid[0:H, 0:W][1].astype(np.float32)
    # frente (barriga, à direita) mais clara que as costas
    frente = np.clip((xx_c - 70.0) / 50.0, 0, 1)
    cor = jade_esc + (jade - jade_esc) * (0.25 + 0.85 * luz)[..., None] + (jade_cla - jade) * (0.25 * veio * luz)[..., None]
    cor = cor + np.array([0.10, 0.12, 0.08]) * (frente * m)[..., None]
    pintas = (ruido((H, W), ((0.7, 1.0),), 8) > 0.82).astype(np.float32) * m
    cor = cor + np.array([0.25, 0.35, 0.30]) * pintas[..., None] * 0.6
    cor = cor * (1 - 0.45 * aneis_m[..., None]) + espec[..., None] * 0.9
    # olho
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    olho = np.clip(1 - np.hypot(xx - 113, yy - 53) / 6.5, 0, 1) ** 0.5
    cor = cor * (1 - olho[..., None] * 0.95) + np.array([0.02, 0.06, 0.05]) * olho[..., None]
    brilho_olho = np.clip(1 - np.hypot(xx - 111, yy - 51) / 2.2, 0, 1)
    cor = cor + brilho_olho[..., None] * 0.9
    # contorno claro (bioluminescência na borda)
    borda = np.clip(m - ndi.grey_erosion(m, size=3), 0, 1)
    cor = cor + borda[..., None] * np.array([0.35, 0.65, 0.55])
    # barbatana translúcida por trás
    fin_cor = jade_cla * 0.6
    a_fin = fin_m * 0.40 + raios_m * 0.45
    a = np.maximum(m, a_fin * (1 - m))
    cor_final = (cor * m[..., None] + fin_cor * (a_fin * (1 - m))[..., None]) / np.maximum(a[..., None], 1e-4)
    gravar(np.dstack([cor_final, a]), "mar_cavalo.png")


# ───────────────────────────────────────────── nuvem macia
def fumaca():
    N = 128
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32) / N - 0.5
    dens = np.zeros((N, N), np.float32)
    g = np.random.default_rng(5)
    for _ in range(9):
        cx, cy = g.uniform(-0.16, 0.16, 2)
        r = g.uniform(0.13, 0.21)
        dens += np.exp(-((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * r * r))
    dens /= dens.max()
    n = ruido((N, N), ((5.0, 1.0), (12.0, 0.8)), 9)
    radial = np.clip(1 - np.hypot(xx, yy) / 0.5, 0, 1) ** 0.8
    a = np.clip((dens * 1.15 - 0.12) * (0.7 + 0.45 * n) * radial, 0, 1)
    a = ndi.gaussian_filter(a, 1.2)
    luz = np.clip(0.80 + 0.30 * (n - 0.5) - 0.30 * yy, 0.55, 1.0)
    gravar(np.dstack([luz, luz, luz, a]), "fx_fumaca.png")


# ───────────────────────────────────────────── anel de choque
def onda():
    N = 256
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32) / N - 0.5
    r = np.hypot(xx, yy)
    anel = np.exp(-((r - 0.43) / 0.022) ** 2)
    dentro = np.exp(-((r - 0.38) / 0.05) ** 2) * 0.35
    a = np.clip(anel + dentro, 0, 1) * (r < 0.5)
    gravar(np.dstack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a]), "fx_onda.png")


# ───────────────────────────────────────────── furos de bala
def furo_areia():
    W, H = 128, 84
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    cx, cy = W / 2, H / 2
    # visto um pouco de cima: elipse achatada
    d = np.hypot((xx - cx) / 1.0, (yy - cy) / 0.62)
    # cratera: fundo escuro, mais escuro na parede de cima (a luz vem de cima)
    buraco = np.clip(1 - d / 19.0, 0, 1) ** 0.55
    parede = np.clip(0.5 - (yy - cy) / 14.0, 0, 1)
    # borda levantada: topo claro, lado de baixo/direita na sombra
    borda = np.exp(-((d - 23.0) / 5.0) ** 2)
    lado_luz = np.clip(0.62 - (yy - cy) / 26.0 - (xx - cx) / 70.0, 0, 1)
    # areia molhada jogada para fora (mais escura que o chão, lê na espuma clara)
    molhada = np.exp(-((d - 30.0) / 11.0) ** 2) * (0.75 + 0.25 * ruido((H, W), [(2, 1.0), (5, 0.6)], 5))
    respingo = np.zeros((H, W), np.float32)
    g = np.random.default_rng(11)
    for _ in range(60):
        ang = g.uniform(0, 2 * np.pi)
        rr = g.uniform(24, 52)
        px, py = cx + np.cos(ang) * rr, cy + np.sin(ang) * rr * 0.62
        respingo += np.exp(-((xx - px) ** 2 + (yy - py) ** 2) / g.uniform(0.8, 3.0)) * g.uniform(0.4, 0.9)
    respingo = np.clip(respingo, 0, 1)
    escuro = np.array([0.10, 0.08, 0.06]) * (0.75 + 0.5 * parede)[..., None]
    claro = np.array([1.0, 0.95, 0.84])
    areia = np.array([0.36, 0.30, 0.22])
    cor = escuro * buraco[..., None] \
        + claro * (borda * lado_luz)[..., None] + areia * 0.6 * (borda * (1 - lado_luz))[..., None] \
        + areia * (molhada * (1 - borda) * (1 - buraco))[..., None] \
        + (claro * 0.8) * (respingo * (1 - buraco))[..., None]
    a = np.clip(buraco * 0.97 + borda * 0.75 + molhada * 0.42 + respingo * 0.6, 0, 1) * np.clip(1 - d / 62.0, 0, 1) ** 0.7
    cor = cor / np.maximum(a[..., None], 1e-3)
    gravar(np.dstack([np.clip(cor, 0, 1), a]), "fx_furo_areia.png")


def furo_pedra():
    N = 64
    E = 4
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    c = N / 2
    d = np.hypot(xx - c, yy - c)
    buraco = np.clip(1 - d / 7.5, 0, 1) ** 0.6
    lasca = np.exp(-((d - 10.0) / 3.0) ** 2)
    trinca = Image.new("L", (N * E, N * E), 0)
    dt = ImageDraw.Draw(trinca)
    g = np.random.default_rng(23)
    for _ in range(7):
        ang = g.uniform(0, 2 * np.pi)
        x, y = c * E, c * E
        comp = g.uniform(14, 28)
        pts = [(x, y)]
        for k in range(5):
            ang += g.uniform(-0.5, 0.5)
            x += np.cos(ang) * comp * E / 5
            y += np.sin(ang) * comp * E / 5
            pts.append((x, y))
        dt.line(pts, fill=255, width=E)
    trinca_m = np.asarray(trinca.resize((N, N), Image.LANCZOS)).astype(np.float32) / 255
    lado_luz = np.clip(0.6 - (yy - c) / 20.0 - (xx - c) / 30.0, 0, 1)
    cor = np.array([0.08, 0.06, 0.06]) * buraco[..., None] + np.array([1.0, 0.97, 0.92]) * (lasca * lado_luz)[..., None] \
        + np.array([0.10, 0.08, 0.08]) * (trinca_m * (1 - buraco))[..., None]
    a = np.clip(buraco + lasca * 0.5 + trinca_m * 0.7, 0, 1) * np.clip(1 - d / 31.0, 0, 1)
    cor = cor / np.maximum(a[..., None], 1e-3)
    gravar(np.dstack([np.clip(cor, 0, 1), a]), "fx_furo_pedra.png")


# ───────────────────────────────────────────── luz da água
def caustica():
    N = 256
    g = np.random.default_rng(31)
    pts = g.uniform(0, N, (22, 2))
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    # dobra o espaço com ruído que emenda: as linhas ficam onduladas
    xx = xx + (ruido((N, N), ((14.0, 1.0),), 41) - 0.5) * 34.0
    yy = yy + (ruido((N, N), ((14.0, 1.0),), 43) - 0.5) * 34.0
    d1 = np.full((N, N), 1e9, np.float32)
    d2 = np.full((N, N), 1e9, np.float32)
    for px, py in pts:
        for ox in (-N, 0, N):
            for oy in (-N, 0, N):
                dd = np.hypot(xx - px - ox, yy - py - oy)
                menor = dd < d1
                d2 = np.where(menor, d1, np.minimum(d2, dd))
                d1 = np.where(menor, dd, d1)
    aresta = np.clip(1 - (d2 - d1) / 7.0, 0, 1) ** 2.0
    aresta = ndi.gaussian_filter(aresta, 0.8, mode="wrap")
    aresta /= aresta.max()
    gravar(np.dstack([np.ones_like(aresta), np.ones_like(aresta), np.ones_like(aresta), aresta]), "mar_caustica.png")


def facho():
    W, H = 64, 512
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    perfil = np.exp(-((xx - W / 2) / (W * 0.22)) ** 2)
    desce = np.clip(1 - yy / H, 0, 1) ** 1.4 * np.clip(yy / 30.0, 0, 1)
    estrias = 0.75 + 0.25 * ruido((H, W), ((2.0, 1.0),), 4)
    a = perfil * desce * estrias
    gravar(np.dstack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a]), "mar_facho.png")


if __name__ == "__main__":
    fumaca()
    onda()
    furo_areia()
    furo_pedra()
    caustica()
    facho()
