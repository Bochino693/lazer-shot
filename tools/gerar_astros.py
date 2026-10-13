#!/usr/bin/env python3
"""Sol e lua do Egito pintados em 3x (nítidos até em 4K), sem shader no olho.

O olho é o hieróglifo clássico, em traço grosso e limpo:
  sol = OLHO DE RÁ    pupila cheia; traço do olho segue reto para a esquerda,
                      lágrima à direita e espiral embaixo à esquerda
  lua = OLHO DE HÓRUS  o espelho: pupila vazada (anel), traço para a direita,
                      lágrima à esquerda e espiral embaixo à direita
  sobrancelha em barra, pálpebra de cima grossa, de baixo mais fina; o
  traço é esmalte escuro com brilho na borda e sombra, gravado no astro.

Cada astro sai em camadas simples (Sprite2D comuns, desenhadas nesta ordem):
  egito_<a>_esclera.png   o branco do olho
  egito_<a>_iris.png      a pupila (anda para olhar)
  egito_<a>_palpebra.png  pálpebra de cima (desce para piscar)
  egito_<a>_disco.png     o astro com o hieróglifo e um buraco na abertura do
                          olho; por cima de tudo, esconde a pupila e a
                          pálpebra fora do olho

  sol  plasma dourado com grânulos e filamentos, borda mais escura e coroa
  lua  prata com mares e crateras em relevo, halo frio

Imprime as medidas para scripts/deserto_vivo.gd (ASTRO_SOL / ASTRO_LUA).

    python3 tools/gerar_astros.py [--previa pasta]
"""
import argparse
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as ndi

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")

X = 3                      # px da textura por px da imagem do fundo
R_IMG = 138.0              # raio do disco (px da imagem do fundo)
HALO = 1.42                # o halo vai até HALO * raio
R = R_IMG * X              # raio do disco na textura
S = int(round(2 * R * HALO / 2)) * 2
C = S / 2
U = 78.0 * X               # meia largura da abertura do olho (textura)
# o hieróglifo inteiro vai de x=-1.0 (sobrancelha) a 1.72 (traço) e de
# y=-0.88 (sobrancelha) a 1.04 (lágrima/espiral), em u: o centro do olho fica
# deslocado para o desenho todo ficar no meio do disco
OLHO_DX = -0.36 * U        # (no sentido do Hórus; o Rá é o espelho)
OLHO_DY = -0.08 * U


# ───────────────────────────────────────────── utilidades
def suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def ruido(forma, escala, rng):
    gh, gw = int(forma[0] / escala) + 4, int(forma[1] / escala) + 4
    g = rng.standard_normal((gh, gw)).astype(np.float32)
    z = ndi.zoom(g, escala, order=3, mode="wrap")
    return z[:forma[0], :forma[1]]


def fbm(forma, rng, escalas=(96, 48, 24, 12, 6), pesos=(1.0, 0.55, 0.32, 0.18, 0.1)):
    out = np.zeros(forma, np.float32)
    for e, p in zip(escalas, pesos):
        out += p * ruido(forma, e, rng)
    return out / sum(pesos)


def grade(n=S):
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    return xx - n / 2 + 0.5, yy - n / 2 + 0.5


def sobre(base, cor, alfa):
    """base (h,w,4) premultiplicado? não: cor normal; compõe cor/alfa por cima."""
    a = alfa[..., None]
    out = base.copy()
    out[..., :3] = cor * a + base[..., :3] * (1 - a)
    out[..., 3] = alfa + base[..., 3] * (1 - alfa)
    return out


def relevo_luz(h, cor_base, cor_brilho, forca=6.0, brilho_exp=28.0):
    """Ilumina um mapa de altura como metal em relevo (luz do alto à esquerda)."""
    gy, gx = np.gradient(h)
    nx, ny, nz = -gx * forca, -gy * forca, np.ones_like(h)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / n, ny / n, nz / n
    L = np.array([-0.45, -0.65, 0.62])
    L = L / np.linalg.norm(L)
    dif = np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0, 1)
    # especular (Blinn): meio caminho entre luz e olho (0,0,1)
    Hh = L + np.array([0, 0, 1.0])
    Hh = Hh / np.linalg.norm(Hh)
    esp = np.clip(nx * Hh[0] + ny * Hh[1] + nz * Hh[2], 0, 1) ** brilho_exp
    cor = cor_base[None, None, :] * (0.30 + 0.95 * dif[..., None]) + cor_brilho[None, None, :] * esp[..., None] * 0.9
    return np.clip(cor, 0, 1)


# ───────────────────────────────────────────── geometria do olho
class Olho:
    """Abertura do olho em unidades u (meia largura = 1), no sentido do Olho
    de Hórus (traço para a direita); espelhar faz o Olho de Rá."""

    def __init__(self, espelhar):
        self.esp = -1.0 if espelhar else 1.0
        self.c_in, self.c_out = 0.05, -0.02
        self.h_up, self.p_up, self.k_up = 0.44, 0.72, -0.10
        self.h_lo, self.p_lo, self.k_lo = 0.30, 0.88, 0.05
        self.r_iris = 0.30
        self.iris_c = (0.0, -0.08)

    def canto(self, x):
        return self.c_in + (self.c_out - self.c_in) * (x + 1) / 2

    def _forma(self, x, p, k):
        x = np.clip(x, -1, 1)
        return (1 - x * x) ** p * (1 + k * x)

    def cima(self, x):
        return self.canto(x) - self.h_up * self._forma(x, self.p_up, self.k_up)

    def baixo(self, x):
        return self.canto(x) + self.h_lo * self._forma(x, self.p_lo, self.k_lo)

    def altura_max(self):
        xs = np.linspace(-1, 1, 401)
        return float(np.max(self.baixo(xs) - self.cima(xs)))

    def mascara(self, xu, yu, aa):
        """1 dentro da abertura (xu,yu em u, já no sentido do olho)."""
        dentro_x = 1 - suave(0.985, 1.0, np.abs(xu))
        d_up = yu - self.cima(xu)
        d_lo = self.baixo(xu) - yu
        return np.clip(np.minimum(d_up, d_lo) / aa + 0.5, 0, 1) * dentro_x * (np.abs(xu) <= 1.0)


def bezier(p0, p1, p2, p3, n=60):
    t = np.linspace(0, 1, n)[:, None]
    p0, p1, p2, p3 = map(np.array, (p0, p1, p2, p3))
    return (1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t * t * p2 + t ** 3 * p3


class Tela:
    """Desenho em 4x (bordas lisas) no espaço do disco; pontos em u."""

    def __init__(self, n, olho, centro, ss=4):
        self.ss = ss
        self.n = n
        self.olho = olho
        self.centro = centro
        self.im = Image.new("L", (n * ss, n * ss), 0)
        self.d = ImageDraw.Draw(self.im)

    def px(self, p):
        return ((C + self.centro[0] + p[0] * self.olho.esp * U) * self.ss, (C + self.centro[1] + p[1] * U) * self.ss)

    def faixa(self, pts, larguras, ponta_redonda=(False, False)):
        """Traço de largura variável como um polígono (pontas retas e limpas)."""
        pts = np.asarray(pts, np.float64)
        d = np.gradient(pts, axis=0)
        d /= np.linalg.norm(d, axis=1, keepdims=True) + 1e-9
        nrm = np.stack([-d[:, 1], d[:, 0]], 1)
        w = np.interp(np.linspace(0, 1, len(pts)), np.linspace(0, 1, len(larguras)), larguras)[:, None] * 0.5
        a = pts + nrm * w
        b = pts - nrm * w
        poly = [self.px(p) for p in a] + [self.px(p) for p in b[::-1]]
        self.d.polygon(poly, fill=255)
        for i, red in ((0, ponta_redonda[0]), (-1, ponta_redonda[1])):
            if red:
                cx, cy = self.px(pts[i])
                r = w[i, 0] * U * self.ss
                self.d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)

    def array(self):
        return np.asarray(self.im.resize((self.n, self.n), Image.LANCZOS)).astype(np.float32) / 255


def espiral(c, r0, r1, a0, voltas, n=160):
    a = a0 - np.linspace(0, voltas * 2 * np.pi, n)
    r = np.linspace(r0, r1, n)
    return np.stack([c[0] + np.cos(a) * r, c[1] + np.sin(a) * r], 1)


def hieroglifo(olho, centro):
    """Máscara (0..1) do traço do olho no disco inteiro."""
    t = Tela(S, olho, centro)
    xs = np.linspace(-1.0, 1.0, 160)
    # pálpebra de cima: grossa, e segue reta depois do canto (o traço)
    cima = np.stack([xs, olho.cima(xs) - 0.05], 1)
    rabo = np.stack([np.linspace(1.0, 1.72, 40), np.linspace(olho.cima(1.0) - 0.05, -0.08, 40)], 1)
    t.faixa(np.vstack([cima, rabo[1:]]), [0.09, 0.16, 0.17, 0.17, 0.17, 0.17], (True, False))
    # pálpebra de baixo, mais fina
    t.faixa(np.stack([xs, olho.baixo(xs) + 0.045], 1), [0.07, 0.10, 0.11, 0.10, 0.07], (True, True))
    # sobrancelha em barra, arqueada, afinando no fim
    t.faixa(bezier((-0.98, -0.64), (-0.40, -0.98), (0.62, -0.98), (1.42, -0.70), 120),
            [0.19, 0.20, 0.195, 0.18, 0.14, 0.05], (False, False))
    # lágrima: reta, descendo do olho e afinando em ponta
    t.faixa(bezier((-0.20, 0.30), (-0.22, 0.56), (-0.25, 0.82), (-0.29, 1.08), 60), [0.15, 0.13, 0.08, 0.015])
    # espiral: desce do olho, passa embaixo e enrola
    c = (0.86, 0.80)
    desce = bezier((0.16, 0.32), (0.24, 0.66), (0.42, 0.98), (0.70, 1.02), 70)
    r0 = float(np.hypot(0.70 - c[0], 1.02 - c[1]))      # começa onde a linha chega (sem degrau)
    voltas = espiral(c, r0, 0.075, np.arctan2(1.02 - c[1], 0.70 - c[0]), 1.3, 200)
    t.faixa(np.vstack([desce, voltas[1:]]), [0.13, 0.125, 0.12, 0.115, 0.11, 0.10, 0.09, 0.085], (False, True))
    return t.array()


# ───────────────────────────────────────────── superfícies
def superficie_sol(xx, yy, rng):
    r = np.hypot(xx, yy) / R
    forma = xx.shape
    n1 = fbm(forma, rng)
    wx = fbm(forma, rng, (160, 80, 40), (1, 0.5, 0.25)) * 26
    wy = fbm(forma, rng, (160, 80, 40), (1, 0.5, 0.25)) * 26
    gy, gx = np.mgrid[0:forma[0], 0:forma[1]].astype(np.float32)
    plasma = ndi.map_coordinates(n1, [gy + wy, gx + wx], order=1, mode="reflect")
    fino = fbm(forma, rng, (10, 5, 2.5), (1, 0.6, 0.35))
    centro = np.array([1.0, 0.96, 0.78])
    meio = np.array([1.0, 0.80, 0.34])
    borda = np.array([0.98, 0.52, 0.10])
    k1 = suave(0.0, 0.75, r)[..., None]
    k2 = suave(0.70, 1.0, r)[..., None]
    cor = centro * (1 - k1) + meio * k1
    cor = cor * (1 - k2) + borda * k2
    cor = cor * (1 + 0.11 * plasma[..., None] + 0.04 * fino[..., None])
    fil = np.exp(-(plasma / 0.08) ** 2)
    cor = cor + np.array([1.0, 0.9, 0.6]) * (0.10 * fil)[..., None]
    cor = cor * (1 - 0.20 * r[..., None] ** 5)
    return np.clip(cor, 0, 1)


def halo_sol(xx, yy, rng):
    r = np.hypot(xx, yy) / R
    ang = np.arctan2(yy, xx)
    raios = 0.65 + 0.35 * np.sin(ang * 23 + 2.0 * np.sin(ang * 5)) * np.sin(ang * 9 + 1.3)
    k = np.clip((r - 1.0) / (HALO - 1.0), 0, 1)
    a = (1 - k) ** 2.2 * (0.75 + 0.25 * raios) * (r > 0.98)
    cor = np.array([1.0, 0.72, 0.28])
    return cor, np.clip(a, 0, 1)


def superficie_lua(xx, yy, rng):
    r = np.hypot(xx, yy) / R
    forma = xx.shape
    mares = fbm(forma, rng, (170, 85, 42, 21), (1, 0.55, 0.3, 0.15))
    m = suave(0.18, 0.62, mares)
    h = np.zeros(forma, np.float32)
    # crateras (altura): bacia + borda levantada
    for i in range(120):
        rc = R * (0.018 + 0.12 * rng.random() ** 3.0)
        ang = rng.uniform(0, 2 * np.pi)
        dist = R * np.sqrt(rng.random()) * 0.95
        cx, cy = np.cos(ang) * dist, np.sin(ang) * dist
        x0, x1 = int(C + cx - rc * 1.6), int(C + cx + rc * 1.6) + 1
        y0, y1 = int(C + cy - rc * 1.6), int(C + cy + rc * 1.6) + 1
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, S), min(y1, S)
        if x1 <= x0 or y1 <= y0:
            continue
        sx, sy = xx[y0:y1, x0:x1] - cx, yy[y0:y1, x0:x1] - cy
        d = np.hypot(sx, sy) / rc
        prof = -np.clip(1 - d * d, 0, 1) * 0.9 + 0.35 * np.exp(-((d - 1.0) / 0.22) ** 2)
        h[y0:y1, x0:x1] += prof * rc * 0.035
    h += fbm(forma, rng, (8, 4, 2), (1, 0.6, 0.3)) * 0.35
    base = np.array([0.86, 0.88, 0.93])
    escuro = np.array([0.52, 0.56, 0.66])
    cor = base * (1 - m[..., None] * 0.7) + escuro * (m[..., None] * 0.7)
    gy, gx = np.gradient(ndi.gaussian_filter(h, 1.0))
    luz = np.clip(1.0 - (gx * -0.45 + gy * -0.65) * 2.2, 0.55, 1.45)
    cor = cor * luz[..., None]
    cor = cor * (1 + 0.05 * fbm(forma, rng, (6, 3), (1, 0.5))[..., None])
    cor = cor * (1 - 0.22 * r[..., None] ** 4)
    cor = cor + np.array([0.10, 0.16, 0.30]) * (suave(0.80, 1.0, r) * 0.35)[..., None]
    return np.clip(cor, 0, 1)


def halo_lua(xx, yy, rng):
    r = np.hypot(xx, yy) / R
    k = np.clip((r - 1.0) / (HALO - 1.0), 0, 1)
    a = (1 - k) ** 2.6 * 0.8 * (r > 0.98)
    return np.array([0.62, 0.78, 1.0]), np.clip(a, 0, 1)


# ───────────────────────────────────────────── camadas do olho
def esclera(olho, cor_base, cor_canto):
    """O branco do olho: liso como no hieróglifo, só um leve volume."""
    w = int(2.3 * U)
    hgt = int(1.25 * U)
    xx, yy = np.meshgrid(np.arange(w) - w / 2 + 0.5, np.arange(hgt) - hgt / 2 + 0.5)
    xu, yu = xx / U * olho.esp, yy / U
    cor = np.ones((hgt, w, 3), np.float32) * cor_base
    canto = suave(0.55, 1.05, np.abs(xu))
    cor = cor * (1 - 0.30 * canto[..., None]) + cor_canto * (0.30 * canto[..., None])
    cor = cor * (1 - 0.10 * suave(0.0, 0.32, yu)[..., None])
    return np.dstack([np.clip(cor, 0, 1), np.ones((hgt, w), np.float32)]), (w, hgt)


def pupila(olho, cor, anel):
    """Pupila cheia (Rá) ou vazada em anel (Hórus), como no hieróglifo."""
    ri = olho.r_iris * U
    n = int(ri * 2 + 8)
    xx, yy = np.meshgrid(np.arange(n) - n / 2 + 0.5, np.arange(n) - n / 2 + 0.5)
    d = np.hypot(xx, yy) / ri
    a = suave(1.0 + 1.0 / ri, 1.0 - 1.0 / ri, d)
    if anel:
        a = a * suave(0.62 - 1.0 / ri, 0.62 + 1.0 / ri, d)
    c = np.ones((n, n, 3), np.float32) * np.array(cor)
    return np.dstack([np.clip(c, 0, 1), a]), n


def palpebra(olho, cor_pele, cor_traco):
    """Pálpebra de cima: pele da cor do astro com o traço grosso na borda
    (fecha o olho como o próprio hieróglifo)."""
    H = olho.altura_max()
    w = int(2.3 * U)
    topo = H + 0.35
    hgt = int((topo + 0.08) * U)
    xx, yy = np.meshgrid(np.arange(w) - w / 2 + 0.5, np.arange(hgt).astype(np.float32))
    xu = xx / U * olho.esp
    yu = yy / U - topo
    borda = olho.cima(np.clip(xu, -1, 1)) + 0.035
    dist = borda - yu
    pele = np.clip(dist * U / 1.2 + 0.5, 0, 1)
    cor = np.ones((hgt, w, 3), np.float32) * cor_pele
    cor = cor * (0.88 + 0.16 * (1 - np.abs(xu) ** 2)[..., None])
    traco = suave(0.19, 0.16, dist)[..., None]
    cor = cor * (1 - traco) + cor_traco * traco
    return np.dstack([np.clip(cor, 0, 1), pele]), (w, hgt), topo


# ───────────────────────────────────────────── montagem
def astro(nome, espelhar, seed):
    rng = np.random.default_rng(seed)
    olho = Olho(espelhar)
    xx, yy = grade()
    r = np.hypot(xx, yy) / R
    sol = nome == "sol"
    if sol:
        sup = superficie_sol(xx, yy, rng)
        cor_halo, a_halo = halo_sol(xx, yy, rng)
        esmalte = np.array([0.16, 0.06, 0.0])
        esmalte_brilho = np.array([1.0, 0.82, 0.45])
        sombra_cor = np.array([0.50, 0.18, 0.0])
    else:
        sup = superficie_lua(xx, yy, rng)
        cor_halo, a_halo = halo_lua(xx, yy, rng)
        esmalte = np.array([0.05, 0.07, 0.15])
        esmalte_brilho = np.array([0.78, 0.88, 1.0])
        sombra_cor = np.array([0.08, 0.10, 0.20])
    disco = suave(1.0, 0.996, r)
    centro = (OLHO_DX * olho.esp, OLHO_DY)
    xu, yu = (xx - centro[0]) / U * olho.esp, (yy - centro[1]) / U
    # o hieróglifo: esmalte escuro com brilho na borda e sombra projetada
    g = hieroglifo(olho, centro)
    somb = ndi.shift(ndi.gaussian_filter(g, 3.5 * X / 3), (4 * X / 3, 3 * X / 3), order=1)
    sup = sup * (1 - 0.45 * somb[..., None]) + sombra_cor * (0.15 * somb[..., None])
    altura = ndi.gaussian_filter(g, 2.0 * X / 3)
    esm = relevo_luz(altura * 9.0, esmalte, esmalte_brilho, forca=1.0, brilho_exp=36.0)
    sup = sup * (1 - g[..., None]) + esm * g[..., None]
    # abertura do olho: buraco (o traço fica por cima); dentro, sombra leve
    abre = olho.mascara(xu, yu, 1.2 / U) * (1 - g)
    somb_palp = np.exp(-np.clip(yu - olho.cima(np.clip(xu, -1, 1)), 0, None) / 0.12) * 0.35
    somb_canto = suave(0.7, 1.0, np.abs(xu)) * 0.15
    base = np.zeros((S, S, 4), np.float32)
    base = sobre(base, cor_halo, a_halo)
    base = sobre(base, sup, disco)
    alfa_buraco = np.clip(somb_palp + somb_canto, 0, 0.6)
    out = base.copy()
    out[..., :3] = base[..., :3] * (1 - abre[..., None]) + sombra_cor * abre[..., None]
    out[..., 3] = base[..., 3] * (1 - abre) + alfa_buraco * abre
    Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(SP, "egito_%s_disco.png" % nome), optimize=True)

    if sol:
        e, tam_e = esclera(olho, np.array([1.0, 0.97, 0.88]), np.array([0.92, 0.78, 0.58]))
        ir, n_ir = pupila(olho, (0.10, 0.04, 0.0), False)
        p, tam_p, topo = palpebra(olho, np.array([1.0, 0.76, 0.32]), esmalte)
    else:
        e, tam_e = esclera(olho, np.array([0.95, 0.97, 1.0]), np.array([0.70, 0.76, 0.88]))
        ir, n_ir = pupila(olho, (0.05, 0.07, 0.15), True)
        p, tam_p, topo = palpebra(olho, np.array([0.82, 0.85, 0.92]), esmalte)

    # esclera e pálpebra não podem aparecer pelo halo (fora do disco)
    def recortar(arr, cx, cy):
        hh, ww = arr.shape[:2]
        gx, gy = np.meshgrid(np.arange(ww) - ww / 2 + 0.5 + cx, np.arange(hh) - hh / 2 + 0.5 + cy)
        arr[..., 3] *= suave(R * 0.99, R * 0.975, np.hypot(gx, gy))
    recortar(e, centro[0], centro[1])
    recortar(p, centro[0], centro[1] - topo * U + p.shape[0] / 2)
    for arr, n in ((e, "esclera"), (ir, "iris"), (p, "palpebra")):
        Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(
            os.path.join(SP, "egito_%s_%s.png" % (nome, n)), optimize=True)
    med = _medidas(nome)
    _MEDIDAS[nome] = med
    print("%s: disco %dx%d, esclera %dx%d, pupila %d, palpebra %dx%d" % (nome, S, S, tam_e[0], tam_e[1], n_ir, tam_p[0], tam_p[1]))
    print('  const ASTRO_%s := {"olho": Vector2(%.1f, %.1f), "u": %.1f, "iris": Vector2(%.1f, %.1f), "palpebra_y": %.1f, "abre": %.1f}' % (
        nome.upper(), med["olho"][0], med["olho"][1], U, med["iris"][0], med["iris"][1], med["palpebra_y"], med["abre"]))
    return med


CENTRO_IMG = (512, 300)     # centro do disco na imagem do fundo (= deserto_vivo.gd)


def colar_astro(fundo, nome):
    """Pinta o disco (olho aberto, sem o halo) no fundo 1x (float RGB)."""
    med = _MEDIDAS.get(nome)
    if med is None:
        med = _medidas(nome)
    tela = previa(nome, med, "", fundo_cor=(0, 0, 0, 0))
    arr = np.asarray(tela).astype(np.float32) / 255
    xx, yy = grade()
    arr[..., 3] *= suave(1.0, 0.994, np.hypot(xx, yy) / R)
    pequeno = Image.fromarray((arr * 255 + 0.5).astype(np.uint8), "RGBA").resize((S // X, S // X), Image.LANCZOS)
    p = np.asarray(pequeno).astype(np.float32) / 255
    out = fundo.copy()
    x0 = int(round(CENTRO_IMG[0] - p.shape[1] / 2))
    y0 = int(round(CENTRO_IMG[1] - p.shape[0] / 2))
    reg = out[y0:y0 + p.shape[0], x0:x0 + p.shape[1]]
    a = p[..., 3:4]
    reg[...] = p[..., :3] * a + reg * (1 - a)
    return out


_MEDIDAS = {}


def _medidas(nome):
    # sol = Rá (espelhado), lua = Hórus
    olho = Olho(nome == "sol")
    H = olho.altura_max()
    return {"olho": (OLHO_DX * olho.esp, OLHO_DY), "u": U, "iris": (olho.iris_c[0] * olho.esp * U, olho.iris_c[1] * U),
            "palpebra_y": -(H + 0.35) * U, "abre": H * U}


def previa(nome, med, pasta, olhar=(0, 0), piscar=0.0, fundo_cor=None):
    d = Image.open(os.path.join(SP, "egito_%s_disco.png" % nome)).convert("RGBA")
    e = Image.open(os.path.join(SP, "egito_%s_esclera.png" % nome)).convert("RGBA")
    ir = Image.open(os.path.join(SP, "egito_%s_iris.png" % nome)).convert("RGBA")
    p = Image.open(os.path.join(SP, "egito_%s_palpebra.png" % nome)).convert("RGBA")
    if fundo_cor is None:
        fundo_cor = (40, 30, 30, 255) if nome == "sol" else (12, 18, 34, 255)
    tela = Image.new("RGBA", d.size, fundo_cor)
    oc = (C + med["olho"][0], C + med["olho"][1])

    def colar(im, centro):
        tela.alpha_composite(im, (int(round(centro[0] - im.width / 2)), int(round(centro[1] - im.height / 2))))
    colar(e, oc)
    colar(ir, (oc[0] + med["iris"][0] + olhar[0] * med["u"], oc[1] + med["iris"][1] + olhar[1] * med["u"]))
    pc = (oc[0], oc[1] + med["palpebra_y"] + p.height / 2 + piscar * (med["abre"] + 0.03 * med["u"]))
    colar(p, pc)
    tela.alpha_composite(d)
    return tela


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--previa", default="")
    a = ap.parse_args()
    m_sol = astro("sol", True, 101)     # Olho de Rá (espelho do de Hórus)
    m_lua = astro("lua", False, 202)    # Olho de Hórus
    if a.previa:
        os.makedirs(a.previa, exist_ok=True)
        ims = [previa("sol", m_sol, a.previa), previa("sol", m_sol, a.previa, (-0.25, 0.02)), previa("sol", m_sol, a.previa, (0, 0), 0.6),
               previa("lua", m_lua, a.previa), previa("lua", m_lua, a.previa, (0.25, 0.0)), previa("lua", m_lua, a.previa, (0, 0), 0.6)]
        w = ims[0].width // 2
        g = Image.new("RGB", (w * 3, w * 2))
        for i, im in enumerate(ims):
            g.paste(im.convert("RGB").resize((w, w), Image.LANCZOS), ((i % 3) * w, (i // 3) * w))
        g.save(os.path.join(a.previa, "astros.png"))
        ims[0].convert("RGB").save(os.path.join(a.previa, "sol_grande.png"))
        ims[3].convert("RGB").save(os.path.join(a.previa, "lua_grande.png"))


if __name__ == "__main__":
    main()
