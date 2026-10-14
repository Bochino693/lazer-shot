#!/usr/bin/env python3
"""Sol e lua do Egito pintados em 4x (nítidos até em 4K), sem shader no olho.

O olho é o Olho de Rá (sol) e o Olho de Hórus (lua) feitos como joia
egípcia, não como ícone:
  - o traço clássico (sobrancelha, pálpebra que segue reta para o lado,
    lágrima e espiral) em metal maciço: ouro no sol, prata na lua (borda
    polida em relevo e o miolo do traço em metal fosco), com brilho,
    contorno escuro e sombra; o astro atrás tem outra cor (sol laranja-
    avermelhado, lua cinza-azulada) para o desenho aparecer;
  - sobrancelha em faixas (borda, miolo fosco, fio polido no meio e riscos);
    fio de metal acima da pálpebra;
  - olho grande e realista: íris âmbar-castanha no sol, branco-azulada na
    lua, com fibras, aro escuro, pupila e reflexos;
  - o olho ocupa o astro inteiro (até ~0,93 do raio), com um filete
    gravado rente à borda.
  Rá e Hórus são espelhos: Rá é o olho direito (o traço vai para a
  direita e a espiral fica embaixo à direita); Hórus é o esquerdo (traço
  e espiral para a esquerda).

Cada astro sai em camadas simples (Sprite2D comuns, desenhadas nesta ordem):
  egito_<a>_esclera.png   o branco do olho
  egito_<a>_iris.png      íris + pupila + reflexos (anda para olhar)
  egito_<a>_palpebra.png  pálpebra de cima (desce para piscar): pele
                          abaulada, fio gravado, faixa de metal com borda
                          polida em relevo e sombra suave sobre o olho
  egito_<a>_palpebra_baixo.png
                          pálpebra de baixo (sobe nas expressões): a
                          beirada curva para cima, então subindo ela deixa
                          o olho em meia-lua, sorrindo
  egito_<a>_halo.png      o brilho em volta do astro, em 1x (só luz suave;
                          o jogo amplia por trás do disco)
  egito_<a>_disco.png     o astro com tudo gravado e um buraco na abertura do
                          olho; por cima de tudo, esconde a íris e a pálpebra
                          fora do olho

  sol  plasma laranja-avermelhado com grânulos e filamentos, borda mais
       escura e coroa
  lua  cinza-azulada com mares e crateras em relevo, halo frio

Imprime as medidas para scripts/deserto_vivo.gd (ASTRO_SOL / ASTRO_LUA).

    python3 tools/gerar_astros.py [--previa pasta]
"""
import argparse
import os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")

X = 4                      # px da textura por px da imagem do fundo
K = X / 3.0                # o desenho foi afinado em 3x: medidas em px escalam por K
R_IMG = 138.0              # raio do disco (px da imagem do fundo)
HALO = 1.42                # o halo vai até HALO * raio
R = R_IMG * X              # raio do disco na textura
S = int(round(2 * R * HALO / 2 / X)) * 2 * X     # múltiplo de 2X (o halo reduz certinho)
C = S / 2
D = int(round((R + 6) / 2)) * 4                  # lado do disco recortado (par)
U = 279.0 * K              # meia largura da abertura do olho (px da textura): o olho ocupa o astro
# o desenho inteiro vai de x=-1.10 a 1.48 e de y=-1.16 a 1.17 (em u, no
# sentido do Rá): o centro do olho fica deslocado para ele ficar no meio
OLHO_DX = -0.19 * U        # (o Hórus é o espelho)
OLHO_DY = -0.035 * U        # sobe um pouco: o desenho fica no meio do disco
CENTRO_IMG = (512, 300)    # centro do disco na imagem do fundo (= deserto_vivo.gd)


# ───────────────────────────────────────────── utilidades
def suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def ruido(forma, escala, rng):
    escala = escala * K
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
    a = alfa[..., None]
    out = base.copy()
    out[..., :3] = cor * a + base[..., :3] * (1 - a)
    out[..., 3] = alfa + base[..., 3] * (1 - alfa)
    return out


def iluminar(h, cor_base, cor_brilho, forca=1.0, brilho_exp=28.0, ambiente=0.30, brilho=0.9):
    """Ilumina um mapa de altura (luz do alto à esquerda). cor_base pode ser
    uma cor (3,) ou uma imagem (h,w,3)."""
    gy, gx = np.gradient(h)
    nx, ny, nz = -gx * forca, -gy * forca, np.ones_like(h)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / n, ny / n, nz / n
    L = np.array([-0.45, -0.65, 0.62])
    L = L / np.linalg.norm(L)
    dif = np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0, 1)
    Hh = L + np.array([0, 0, 1.0])
    Hh = Hh / np.linalg.norm(Hh)
    esp = np.clip(nx * Hh[0] + ny * Hh[1] + nz * Hh[2], 0, 1) ** brilho_exp
    base = cor_base if np.ndim(cor_base) == 3 else np.asarray(cor_base)[None, None, :]
    cor = base * (ambiente + 0.95 * dif[..., None]) + np.asarray(cor_brilho)[None, None, :] * esp[..., None] * brilho
    return np.clip(cor, 0, 1)


# ───────────────────────────────────────────── geometria do olho
class Olho:
    """Abertura do olho em unidades u (meia largura = 1), no sentido do Olho
    de Rá (o direito: traço para a direita); espelhar faz o de Hórus."""

    def __init__(self, espelhar):
        self.esp = -1.0 if espelhar else 1.0
        self.c_in, self.c_out = 0.05, -0.02
        self.h_up, self.p_up, self.k_up = 0.49, 0.72, -0.10
        self.h_lo, self.p_lo, self.k_lo = 0.35, 0.88, 0.05
        self.r_iris = 0.36
        self.iris_c = (0.0, -0.04)

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
        dentro_x = 1 - suave(0.985, 1.0, np.abs(xu))
        d_up = yu - self.cima(xu)
        d_lo = self.baixo(xu) - yu
        return np.clip(np.minimum(d_up, d_lo) / aa + 0.5, 0, 1) * dentro_x * (np.abs(xu) <= 1.0)


def bezier(p0, p1, p2, p3, n=60):
    t = np.linspace(0, 1, n)[:, None]
    p0, p1, p2, p3 = map(np.array, (p0, p1, p2, p3))
    return (1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t * t * p2 + t ** 3 * p3


def espiral(c, r0, r1, a0, voltas, n=200):
    a = a0 - np.linspace(0, voltas * 2 * np.pi, n)
    r = np.linspace(r0, r1, n)
    return np.stack([c[0] + np.cos(a) * r, c[1] + np.sin(a) * r], 1)


def normais(pts):
    d = np.gradient(pts, axis=0)
    d /= np.linalg.norm(d, axis=1, keepdims=True) + 1e-9
    return np.stack([-d[:, 1], d[:, 0]], 1)


def larguras(pts, lista):
    return np.interp(np.linspace(0, 1, len(pts)), np.linspace(0, 1, len(lista)), lista)


class Tela:
    """Desenho em 4x (bordas lisas) no espaço do disco; pontos em u."""

    def __init__(self, olho, centro, ss=4):
        self.ss = ss
        self.olho = olho
        self.centro = centro
        self.im = Image.new("L", (S * ss, S * ss), 0)
        self.d = ImageDraw.Draw(self.im)

    def px(self, p):
        return ((C + self.centro[0] + p[0] * self.olho.esp * U) * self.ss, (C + self.centro[1] + p[1] * U) * self.ss)

    def faixa(self, pts, w, pontas=(False, False)):
        """Traço de largura w (array por ponto) como polígono: pontas retas."""
        nrm = normais(pts)
        a = pts + nrm * (w * 0.5)[:, None]
        b = pts - nrm * (w * 0.5)[:, None]
        self.d.polygon([self.px(p) for p in a] + [self.px(p) for p in b[::-1]], fill=255)
        for i, red in ((0, pontas[0]), (-1, pontas[1])):
            if red and w[i] > 0:
                cx, cy = self.px(pts[i])
                r = w[i] * 0.5 * U * self.ss
                self.d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)

    def linha(self, a, b, w):
        self.d.line([self.px(a), self.px(b)], fill=255, width=max(1, int(w * U * self.ss)))

    def array(self):
        return np.asarray(self.im.resize((S, S), Image.LANCZOS)).astype(np.float32) / 255


def tracos(olho):
    """Os traços do hieróglifo: nome -> (linha central, larguras, pontas redondas)."""
    xs = np.linspace(-1.0, 1.0, 180)
    cima = np.stack([xs, olho.cima(xs) - 0.06], 1)
    rabo = np.stack([np.linspace(1.0, 1.40, 40), np.linspace(olho.cima(1.0) - 0.06, -0.10, 40)], 1)
    palp = np.vstack([cima, rabo[1:]])
    baixo = np.stack([xs, olho.baixo(xs) + 0.05], 1)
    # sobrancelha em arco, acompanhando a borda do astro
    sob = bezier((-0.90, -0.60), (-0.42, -1.14), (0.66, -1.14), (1.24, -0.70), 160)
    # lágrima e espiral nascem dentro da faixa de baixo
    y_lag = float(olho.baixo(-0.20))
    y_esp = float(olho.baixo(0.14))
    lag = bezier((-0.20, y_lag), (-0.22, 0.66), (-0.26, 0.94), (-0.31, 1.22), 80)
    c = (0.78, 0.92)
    desce = bezier((0.14, y_esp), (0.22, 0.78), (0.40, 1.10), (0.64, 1.14), 80)
    r0 = float(np.hypot(0.64 - c[0], 1.14 - c[1]))      # começa onde a linha chega (sem degrau)
    voltas = espiral(c, r0, 0.075, np.arctan2(1.14 - c[1], 0.64 - c[0]), 1.3, 220)
    esp = np.vstack([desce, voltas[1:]])
    return {
        "palpebra": (palp, larguras(palp, [0.10, 0.19, 0.20, 0.20, 0.20, 0.20]), (True, False)),
        "baixo": (baixo, larguras(baixo, [0.08, 0.12, 0.13, 0.12, 0.08]), (True, True)),
        "sobrancelha": (sob, larguras(sob, [0.24, 0.25, 0.245, 0.22, 0.17, 0.06]), (False, False)),
        "lagrima": (lag, larguras(lag, [0.17, 0.15, 0.10, 0.02]), (False, False)),
        "espiral": (esp, larguras(esp, [0.15, 0.145, 0.14, 0.13, 0.12, 0.11, 0.10, 0.09]), (False, True)),
    }


def hieroglifo(olho, centro):
    """Máscaras do hieróglifo: metal (a peça toda), esmalte (o meio azul) e
    fios (filetes e riscos de metal por cima do esmalte)."""
    metal = Tela(olho, centro)
    esmalte = Tela(olho, centro)
    fios = Tela(olho, centro)
    borda = 0.032
    for nome, (pts, w, pontas) in tracos(olho).items():
        metal.faixa(pts, w, pontas)
        if nome == "sobrancelha":
            # faixas: esmalte no meio, fio de metal no centro e riscos
            esmalte.faixa(pts, np.maximum(w * 0.62 - 0.005, 0))
            fios.faixa(pts, w * 0.07)
            nrm = normais(pts)
            comp = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))])
            for alvo in np.arange(0.10, comp[-1] - 0.10, 0.11):
                i = int(np.searchsorted(comp, alvo))
                meia = w[i] * 0.31
                fios.linha(pts[i] - nrm[i] * meia, pts[i] + nrm[i] * meia, 0.016)
        else:
            esmalte.faixa(pts, np.maximum(w - 2 * borda, 0), pontas)
    # fio de metal acima da pálpebra (maquiagem do hieróglifo)
    xs = np.linspace(-0.72, 0.95, 120)
    acima = np.stack([xs, olho.cima(xs) - 0.29], 1)
    metal.faixa(acima, larguras(acima, [0.0, 0.035, 0.04, 0.035, 0.0]))
    return metal.array(), esmalte.array(), fios.array()


def gravura_aro():
    """Filete gravado rente à borda do astro (o olho ocupa o resto)."""
    ss = 3
    im = Image.new("L", (S * ss, S * ss), 0)
    d = ImageDraw.Draw(im)
    r = 0.975 * R
    d.ellipse([((C - r) * ss, (C - r) * ss), ((C + r) * ss, (C + r) * ss)], outline=255, width=int(0.006 * R * ss))
    return np.asarray(im.resize((S, S), Image.LANCZOS)).astype(np.float32) / 255


# ───────────────────────────────────────────── superfícies
def superficie_sol(xx, yy, rng):
    r = np.hypot(xx, yy) / R
    forma = xx.shape
    n1 = fbm(forma, rng)
    wx = fbm(forma, rng, (160, 80, 40), (1, 0.5, 0.25)) * 26 * K
    wy = fbm(forma, rng, (160, 80, 40), (1, 0.5, 0.25)) * 26 * K
    gy, gx = np.mgrid[0:forma[0], 0:forma[1]].astype(np.float32)
    plasma = ndi.map_coordinates(n1, [gy + wy, gx + wx], order=1, mode="reflect")
    fino = fbm(forma, rng, (10, 5, 2.5), (1, 0.6, 0.35))
    # laranja-avermelhado: o desenho de ouro aparece por cima
    centro = np.array([1.0, 0.66, 0.26])
    meio = np.array([0.96, 0.44, 0.11])
    borda = np.array([0.78, 0.20, 0.03])
    k1 = suave(0.0, 0.75, r)[..., None]
    k2 = suave(0.70, 1.0, r)[..., None]
    cor = centro * (1 - k1) + meio * k1
    cor = cor * (1 - k2) + borda * k2
    cor = cor * (1 + 0.11 * plasma[..., None] + 0.04 * fino[..., None])
    fil = np.exp(-(plasma / 0.08) ** 2)
    cor = cor + np.array([1.0, 0.62, 0.30]) * (0.10 * fil)[..., None]
    cor = cor * (1 - 0.20 * r[..., None] ** 5)
    return np.clip(cor, 0, 1)


def halo_sol(xx, yy, rng):
    r = np.hypot(xx, yy) / R
    ang = np.arctan2(yy, xx)
    raios = 0.65 + 0.35 * np.sin(ang * 23 + 2.0 * np.sin(ang * 5)) * np.sin(ang * 9 + 1.3)
    k = np.clip((r - 1.0) / (HALO - 1.0), 0, 1)
    a = (1 - k) ** 2.2 * (0.75 + 0.25 * raios) * (r > 0.98)
    return np.array([1.0, 0.56, 0.18]), np.clip(a, 0, 1)


def superficie_lua(xx, yy, rng):
    r = np.hypot(xx, yy) / R
    forma = xx.shape
    mares = fbm(forma, rng, (170, 85, 42, 21), (1, 0.55, 0.3, 0.15))
    m = suave(0.18, 0.62, mares)
    h = np.zeros(forma, np.float32)
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
    # cinza-azulada (lua de noite): o desenho de prata aparece por cima
    base = np.array([0.50, 0.56, 0.70])
    escuro = np.array([0.30, 0.35, 0.48])
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
    w = int(2.3 * U)
    hgt = int(1.3 * U)
    xx, yy = np.meshgrid(np.arange(w) - w / 2 + 0.5, np.arange(hgt) - hgt / 2 + 0.5)
    xu, yu = xx / U * olho.esp, yy / U
    cor = np.ones((hgt, w, 3), np.float32) * cor_base
    canto = suave(0.45, 1.05, np.abs(xu))
    cor = cor * (1 - 0.40 * canto[..., None]) + cor_canto * (0.40 * canto[..., None])
    car = np.exp(-(((xu + 0.96) / 0.06) ** 2 + ((yu - olho.canto(-1.0)) / 0.07) ** 2))
    cor = cor * (1 - 0.3 * car[..., None]) + np.array([0.94, 0.70, 0.66]) * (0.3 * car[..., None])
    cor = cor * (1 - 0.16 * suave(0.0, 0.34, yu)[..., None])
    return np.dstack([np.clip(cor, 0, 1), np.ones((hgt, w), np.float32)]), (w, hgt)


def iris(olho, cores, rng):
    """Íris realista: fibras, coroa clara, aro escuro, pupila e reflexos."""
    ri = olho.r_iris * U
    n = int(ri * 2 + 8)
    xx, yy = np.meshgrid(np.arange(n) - n / 2 + 0.5, np.arange(n) - n / 2 + 0.5)
    d = np.hypot(xx, yy) / ri
    ang = np.arctan2(yy, xx)
    centro, meio, borda, aro = [np.array(c, np.float32) for c in cores]
    k1 = suave(0.30, 0.68, d)[..., None]
    k2 = suave(0.66, 0.96, d)[..., None]
    cor = centro * (1 - k1) + meio * k1
    cor = cor * (1 - k2) + borda * k2
    fib = np.zeros_like(d)
    for f, p in ((53, 0.5), (97, 0.3), (181, 0.2)):
        fase = rng.uniform(0, 6.28, 3)
        fib += p * np.sin(ang * f + fase[0] + 3.0 * np.sin(ang * 3 + fase[1])) * np.sin(d * 9 + fase[2])
    manchas = ruido(d.shape, 9, rng)
    cor = cor * (1 + (0.18 * fib + 0.06 * manchas)[..., None] * suave(0.38, 0.6, d)[..., None])
    limbo = suave(0.86, 1.0, d)[..., None]
    cor = cor * (1 - limbo) + aro * limbo
    coroa = np.exp(-((d - 0.50) / 0.08) ** 2)[..., None]
    cor = cor + np.array([0.28, 0.22, 0.10]) * coroa * 0.55
    pup = suave(0.40, 0.35, d)[..., None]
    cor = cor * (1 - pup) + np.array([0.02, 0.015, 0.01]) * pup
    ref1 = suave(0.19, 0.09, np.hypot(xx / ri + 0.34, yy / ri + 0.36))[..., None]
    ref2 = suave(0.08, 0.03, np.hypot(xx / ri - 0.32, yy / ri - 0.28))[..., None]
    cor = cor * (1 - 0.92 * ref1) + 0.92 * ref1
    cor = cor * (1 - 0.75 * ref2) + 0.75 * ref2
    a = suave(1.0 + 1.0 / ri, 1.0 - 1.0 / ri, d)
    return np.dstack([np.clip(cor, 0, 1), a]), n


def palpebra(olho, cor_pele, cor_metal, cor_brilho, cor_esmalte, cor_sombra, rng):
    """Pálpebra de cima como a própria joia: pele da cor do astro abaulada
    (luz no meio, sombra na dobra), um fio de metal gravado e, na beirada,
    a faixa de esmalte com borda de metal em relevo. Embaixo da beirada,
    uma sombra suave sobre o olho (desce junto quando pisca)."""
    H = olho.altura_max()
    w = int(2.3 * U)
    topo = H + 0.35
    hgt = int((topo + 0.20) * U)
    xx, yy = np.meshgrid(np.arange(w) - w / 2 + 0.5, np.arange(hgt).astype(np.float32))
    xu = xx / U * olho.esp
    yu = yy / U - topo
    borda = olho.cima(np.clip(xu, -1, 1)) + 0.04
    dist = borda - yu                                   # > 0 dentro da pálpebra
    pele = np.clip(dist * U / 1.2 + 0.5, 0, 1)
    k = X / 3.0
    # pele abaulada: mais clara no meio da curva, escura na dobra de cima
    curva = np.sin(np.pi * np.clip(dist / 1.15, 0, 1)) ** 0.7
    lado = 1 - 0.55 * np.clip(np.abs(xu), 0, 1) ** 2
    tom = 0.70 + 0.34 * curva * lado + 0.06 * fbm(dist.shape, rng, (48, 24, 12), (1, 0.5, 0.3))
    cor = np.ones((hgt, w, 3), np.float32) * cor_pele * tom[..., None]
    reflexo = np.exp(-((dist - 0.48) / 0.11) ** 2) * np.clip(1 - np.abs(xu + 0.15 * olho.esp) / 0.9, 0, 1)
    cor = cor + cor_brilho * (0.22 * reflexo)[..., None]
    # faixa da beirada (metal | esmalte | metal) e fio gravado acima dela
    faixa = suave(0.21, 0.19, dist) * pele
    metal = faixa * (1 - suave(0.032, 0.040, dist) * suave(0.168, 0.160, dist))
    fio = np.exp(-((dist - 0.30) / 0.009) ** 2) * suave(0.95, 0.75, np.abs(xu))
    metal = np.maximum(metal, fio)
    esm = np.clip(faixa - metal, 0, 1)
    altura = ndi.gaussian_filter(faixa, 2.4 * k) - 0.30 * ndi.gaussian_filter(esm, 1.2 * k) + \
        0.35 * ndi.gaussian_filter(fio, 0.8 * k)
    pontinhos = (ruido(dist.shape, 1.6, rng) > 2.3).astype(np.float32)
    esm_cor = cor_esmalte[None, None, :] * (0.85 + 0.25 * fbm(dist.shape, rng, (40, 20, 10), (1, 0.5, 0.3))[..., None])
    esm_cor = esm_cor * (1 - pontinhos[..., None]) + cor_brilho * pontinhos[..., None] * 0.9
    lit_metal = iluminar(altura * 10.0 * K, cor_metal, cor_brilho, brilho_exp=16.0, ambiente=0.35)
    lit_esm = iluminar(altura * 10.0 * K, esm_cor, cor_brilho, brilho_exp=40.0, ambiente=0.45, brilho=0.6)
    peca = np.maximum(metal, esm)
    cor_peca = lit_metal * (1 - (esm / np.maximum(peca, 1e-6))[..., None]) + lit_esm * (esm / np.maximum(peca, 1e-6))[..., None]
    cor = cor * (1 - peca[..., None]) + cor_peca * peca[..., None]
    # sombra da beirada sobre o olho
    a_somb = 0.30 * np.exp(np.minimum(dist, 0) / 0.05) * (dist < 0.01)
    alfa = pele + (1 - pele) * a_somb
    rgb = (cor * pele[..., None] + cor_sombra * (a_somb * (1 - pele))[..., None]) / np.maximum(alfa, 1e-6)[..., None]
    return np.dstack([np.clip(rgb, 0, 1), alfa]), (w, hgt), topo


# pálpebra de baixo: beirada no meio (em repouso, logo abaixo da abertura) e
# quanto ela desce nos cantos (a curva para cima é o que faz o sorriso)
BAIXO_MEIO = 0.07          # folga abaixo do fundo da abertura, em u
BAIXO_CURVA = 0.60
BAIXO_SOBE = 0.70          # o máximo que ela sobe (u)
# olhar calmo (pálpebra de cima / de baixo) = "calmo" em scripts/deserto_vivo.gd
CALMO = (0.30, 0.12)


def palpebra_baixo(olho, cor_pele, cor_metal, cor_brilho, cor_esmalte, rng):
    """Pálpebra de baixo, a mesma joia da de cima: pele da cor do astro
    abaulada e, na beirada (que curva para cima), a faixa de metal com borda
    polida. Em repouso fica toda abaixo da abertura; subindo, deixa o olho
    em meia-lua (sorrindo) ou estreito (atento)."""
    e0 = olho.baixo(0.0) + BAIXO_MEIO
    y0 = e0 - 0.10
    y1 = e0 + BAIXO_CURVA + 1.0
    w = int(2.3 * U)
    hgt = int((y1 - y0) * U)
    xx, yy = np.meshgrid(np.arange(w) - w / 2 + 0.5, np.arange(hgt).astype(np.float32))
    xu = xx / U * olho.esp
    yu = yy / U + y0
    borda = e0 + BAIXO_CURVA * np.clip(xu, -1.2, 1.2) ** 2
    dist = yu - borda                                    # > 0 dentro da pálpebra
    pele = np.clip(dist * U / 1.2 + 0.5, 0, 1)
    k = X / 3.0
    curva = np.sin(np.pi * np.clip(dist / 0.9, 0, 1)) ** 0.7
    lado = 1 - 0.55 * np.clip(np.abs(xu), 0, 1) ** 2
    tom = 0.66 + 0.30 * curva * lado + 0.06 * fbm(dist.shape, rng, (48, 24, 12), (1, 0.5, 0.3))
    cor = np.ones((hgt, w, 3), np.float32) * cor_pele * tom[..., None]
    reflexo = np.exp(-((dist - 0.30) / 0.10) ** 2) * np.clip(1 - np.abs(xu + 0.15 * olho.esp) / 0.9, 0, 1)
    cor = cor + cor_brilho * (0.16 * reflexo)[..., None]
    faixa = suave(0.17, 0.15, dist) * pele
    metal = faixa * (1 - suave(0.028, 0.036, dist) * suave(0.135, 0.127, dist))
    esm = np.clip(faixa - metal, 0, 1)
    altura = ndi.gaussian_filter(faixa, 2.4 * k) - 0.30 * ndi.gaussian_filter(esm, 1.2 * k)
    pontinhos = (ruido(dist.shape, 1.6, rng) > 2.3).astype(np.float32)
    esm_cor = cor_esmalte[None, None, :] * (0.85 + 0.25 * fbm(dist.shape, rng, (40, 20, 10), (1, 0.5, 0.3))[..., None])
    esm_cor = esm_cor * (1 - pontinhos[..., None]) + cor_brilho * pontinhos[..., None] * 0.9
    lit_metal = iluminar(altura * 10.0 * K, cor_metal, cor_brilho, brilho_exp=16.0, ambiente=0.35)
    lit_esm = iluminar(altura * 10.0 * K, esm_cor, cor_brilho, brilho_exp=40.0, ambiente=0.45, brilho=0.6)
    peca = np.maximum(metal, esm)
    cor_peca = lit_metal * (1 - (esm / np.maximum(peca, 1e-6))[..., None]) + lit_esm * (esm / np.maximum(peca, 1e-6))[..., None]
    cor = cor * (1 - peca[..., None]) + cor_peca * peca[..., None]
    # sombra fininha da beirada sobre o olho
    a_somb = 0.22 * np.exp(np.minimum(dist, 0) / 0.025) * (dist < 0.01)
    alfa = pele + (1 - pele) * a_somb
    rgb = (cor * pele[..., None] + np.array([0.05, 0.03, 0.02]) * (a_somb * (1 - pele))[..., None]) / np.maximum(alfa, 1e-6)[..., None]
    return np.dstack([np.clip(rgb, 0, 1), alfa]), (w, hgt), y0


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
        metal_cor = np.array([1.0, 0.82, 0.36])        # ouro polido
        metal_brilho = np.array([1.0, 0.98, 0.86])
        esmalte_cor = np.array([0.86, 0.60, 0.18])     # miolo: ouro fosco
        contorno_cor = np.array([0.20, 0.04, 0.0])
        sombra_cor = np.array([0.36, 0.07, 0.0])
        gravura_cor = np.array([0.55, 0.15, 0.02])
    else:
        sup = superficie_lua(xx, yy, rng)
        cor_halo, a_halo = halo_lua(xx, yy, rng)
        metal_cor = np.array([0.90, 0.93, 0.98])       # prata polida
        metal_brilho = np.array([1.0, 1.0, 1.0])
        esmalte_cor = np.array([0.62, 0.67, 0.78])     # miolo: prata fosca
        contorno_cor = np.array([0.02, 0.04, 0.10])
        sombra_cor = np.array([0.05, 0.07, 0.15])
        gravura_cor = np.array([0.24, 0.28, 0.40])
    disco = suave(1.0, 0.996, r)
    k = X / 3.0

    # filete gravado na borda (baixo-relevo: escuro dentro, luz na borda de baixo)
    g = gravura_aro()
    luz_g = np.clip(ndi.shift(g, (1.5 * k, 1.5 * k), order=1) - g, 0, 1)
    sup = sup * (1 - 0.45 * g[..., None]) + gravura_cor * (0.25 * g[..., None])
    sup = sup + np.array([1.0, 0.95, 0.85]) * (0.25 * luz_g)[..., None]

    centro = (OLHO_DX * olho.esp, OLHO_DY)
    xu, yu = (xx - centro[0]) / U * olho.esp, (yy - centro[1]) / U
    metal, esmalte, fios = hieroglifo(olho, centro)
    esmalte = esmalte * (1 - fios)
    peca = np.maximum(metal, esmalte)
    # sombra da peça no astro e contorno escuro (define a joia)
    somb = ndi.shift(ndi.gaussian_filter(peca, 4.0 * k), (5 * k, 4 * k), order=1)
    sup = sup * (1 - 0.5 * somb[..., None]) + sombra_cor * (0.15 * somb[..., None])
    lado = int(round(2 * K)) * 2 + 1
    contorno = np.clip(ndi.grey_dilation(peca, size=(lado, lado)) - peca, 0, 1)
    sup = sup * (1 - 0.85 * contorno[..., None]) + contorno_cor * (0.85 * contorno[..., None])
    # relevo: a peça é abaulada, o esmalte fica um pouco abaixo da borda e os
    # fios de metal sobem
    altura = ndi.gaussian_filter(peca, 2.4 * k) - 0.30 * ndi.gaussian_filter(esmalte, 1.2 * k) + \
        0.30 * ndi.gaussian_filter(fios, 0.8 * k)
    pontinhos = (ruido(peca.shape, 1.6, rng) > 2.3).astype(np.float32)      # granulado do metal
    esm_cor = esmalte_cor[None, None, :] * (0.85 + 0.25 * fbm(peca.shape, rng, (40, 20, 10), (1, 0.5, 0.3))[..., None])
    esm_cor = esm_cor * (1 - pontinhos[..., None]) + metal_brilho * pontinhos[..., None] * 0.9   # granulado
    lit_metal = iluminar(altura * 10.0 * K, metal_cor, metal_brilho, brilho_exp=16.0, ambiente=0.35)
    lit_esm = iluminar(altura * 10.0 * K, esm_cor, metal_brilho, brilho_exp=40.0, ambiente=0.45, brilho=0.6)
    cor_peca = lit_metal * (1 - esmalte[..., None]) + lit_esm * esmalte[..., None]
    sup = sup * (1 - peca[..., None]) + cor_peca * peca[..., None]

    # abertura do olho: buraco (a joia fica por cima); dentro, sombra leve
    abre = olho.mascara(xu, yu, 1.2 / U) * (1 - peca)
    somb_palp = np.exp(-np.clip(yu - olho.cima(np.clip(xu, -1, 1)), 0, None) / 0.12) * 0.28
    somb_canto = suave(0.65, 1.0, np.abs(xu)) * 0.18
    base = np.zeros((S, S, 4), np.float32)
    base = sobre(base, sup, disco)
    alfa_buraco = np.clip(somb_palp + somb_canto, 0, 0.6)
    out = base.copy()
    out[..., :3] = base[..., :3] * (1 - abre[..., None]) + sombra_cor * abre[..., None]
    out[..., 3] = base[..., 3] * (1 - abre) + alfa_buraco * abre
    # o disco nítido (4x) só no tamanho dele; o halo, que é só brilho suave,
    # vai numa textura pequena (1x) que o jogo amplia por trás
    a0 = int(C - D / 2)
    disco_png = out[a0:a0 + D, a0:a0 + D]
    Image.fromarray((np.clip(disco_png, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(SP, "egito_%s_disco.png" % nome), optimize=True)
    halo = np.dstack([np.ones((S, S, 3), np.float32) * cor_halo, a_halo * (1 - disco * 0.0)])
    halo_im = Image.fromarray((np.clip(halo, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").resize((S // X, S // X), Image.LANCZOS)
    halo_im.save(os.path.join(SP, "egito_%s_halo.png" % nome), optimize=True)

    if sol:
        e, tam_e = esclera(olho, np.array([1.0, 0.97, 0.90]), np.array([0.90, 0.76, 0.60]))
        ir, n_ir = iris(olho, [(1.0, 0.88, 0.40), (0.80, 0.56, 0.18), (0.46, 0.27, 0.10), (0.15, 0.07, 0.03)], rng)
        pele = np.array([0.98, 0.50, 0.15])
        p, tam_p, topo = palpebra(olho, pele, metal_cor, metal_brilho, esmalte_cor, sombra_cor, rng)
        pb, tam_pb, y0_pb = palpebra_baixo(olho, pele, metal_cor, metal_brilho, esmalte_cor, rng)
    else:
        e, tam_e = esclera(olho, np.array([0.96, 0.98, 1.0]), np.array([0.70, 0.76, 0.88]))
        ir, n_ir = iris(olho, [(0.97, 0.98, 1.0), (0.74, 0.85, 0.98), (0.52, 0.68, 0.92), (0.12, 0.22, 0.48)], rng)
        pele = np.array([0.52, 0.58, 0.72])
        p, tam_p, topo = palpebra(olho, pele, metal_cor, metal_brilho, esmalte_cor, sombra_cor, rng)
        pb, tam_pb, y0_pb = palpebra_baixo(olho, pele, metal_cor, metal_brilho, esmalte_cor, rng)

    # esclera e pálpebra não podem aparecer pelo halo (fora do disco)
    def recortar(arr, cx, cy):
        hh, ww = arr.shape[:2]
        gx, gy = np.meshgrid(np.arange(ww) - ww / 2 + 0.5 + cx, np.arange(hh) - hh / 2 + 0.5 + cy)
        arr[..., 3] *= suave(R * 0.99, R * 0.975, np.hypot(gx, gy))
    recortar(e, centro[0], centro[1])
    recortar(p, centro[0], centro[1] - topo * U + p.shape[0] / 2)
    recortar(pb, centro[0], centro[1] + y0_pb * U + pb.shape[0] / 2)
    for arr, n in ((e, "esclera"), (ir, "iris"), (p, "palpebra"), (pb, "palpebra_baixo")):
        Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(
            os.path.join(SP, "egito_%s_%s.png" % (nome, n)), optimize=True)
    med = _medidas(nome)
    _MEDIDAS[nome] = med
    print("%s: disco %dx%d, esclera %dx%d, iris %d, palpebra %dx%d" % (nome, S, S, tam_e[0], tam_e[1], n_ir, tam_p[0], tam_p[1]))
    print('  const ASTRO_%s := {"olho": Vector2(%.1f, %.1f), "u": %.1f, "iris": Vector2(%.1f, %.1f), "palpebra_y": %.1f, "abre": %.1f, "baixo_y": %.1f, "sobe": %.1f}' % (
        nome.upper(), med["olho"][0], med["olho"][1], U, med["iris"][0], med["iris"][1], med["palpebra_y"], med["abre"], med["baixo_y"], med["sobe"]))
    return med


def colar_astro(fundo, nome):
    """Pinta o disco (olho calmo, sem o halo) no fundo 1x (float RGB)."""
    med = _MEDIDAS.get(nome) or _medidas(nome)
    tela = previa(nome, med, (0.04 if nome == "sol" else -0.04, 0.0), CALMO[0], (0, 0, 0, 0), CALMO[1])
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
    # sol = Rá (o direito), lua = Hórus (o esquerdo, espelhado)
    olho = Olho(nome == "lua")
    H = olho.altura_max()
    e0 = olho.baixo(0.0) + BAIXO_MEIO
    y0 = e0 - 0.10
    h_pb = int((e0 + BAIXO_CURVA + 1.0 - y0) * U)
    return {"olho": (OLHO_DX * olho.esp, OLHO_DY), "u": U, "iris": (olho.iris_c[0] * olho.esp * U, olho.iris_c[1] * U),
            "palpebra_y": -(H + 0.35) * U, "abre": H * U, "baixo_y": y0 * U + h_pb / 2, "sobe": BAIXO_SOBE * U}


def previa(nome, med, olhar=(0, 0), piscar=0.0, fundo_cor=None, baixo=0.0):
    d = Image.open(os.path.join(SP, "egito_%s_disco.png" % nome)).convert("RGBA")
    h = Image.open(os.path.join(SP, "egito_%s_halo.png" % nome)).convert("RGBA").resize((S, S), Image.BICUBIC)
    e = Image.open(os.path.join(SP, "egito_%s_esclera.png" % nome)).convert("RGBA")
    ir = Image.open(os.path.join(SP, "egito_%s_iris.png" % nome)).convert("RGBA")
    p = Image.open(os.path.join(SP, "egito_%s_palpebra.png" % nome)).convert("RGBA")
    pb = Image.open(os.path.join(SP, "egito_%s_palpebra_baixo.png" % nome)).convert("RGBA")
    if fundo_cor is None:
        fundo_cor = (40, 30, 30, 255) if nome == "sol" else (12, 18, 34, 255)
    tela = Image.new("RGBA", (S, S), fundo_cor)
    tela.alpha_composite(h)
    oc = (C + med["olho"][0], C + med["olho"][1])

    def colar(im, centro):
        tela.alpha_composite(im, (int(round(centro[0] - im.width / 2)), int(round(centro[1] - im.height / 2))))
    colar(e, oc)
    colar(ir, (oc[0] + med["iris"][0] + olhar[0] * med["u"], oc[1] + med["iris"][1] + olhar[1] * med["u"]))
    colar(pb, (oc[0], oc[1] + med["baixo_y"] - baixo * med["sobe"]))
    colar(p, (oc[0], oc[1] + med["palpebra_y"] + p.height / 2 + piscar * (med["abre"] + 0.03 * med["u"])))
    tela.alpha_composite(d, (int(C - d.width / 2), int(C - d.height / 2)))
    return tela


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--previa", default="")
    a = ap.parse_args()
    m_sol = astro("sol", False, 101)    # Olho de Rá (o direito)
    m_lua = astro("lua", True, 202)     # Olho de Hórus (o esquerdo: espelho do Rá)
    if a.previa:
        os.makedirs(a.previa, exist_ok=True)
        ims = [previa("sol", m_sol), previa("sol", m_sol, (-0.25, 0.02)), previa("sol", m_sol, (0, 0), 0.6),
               previa("lua", m_lua), previa("lua", m_lua, (0.25, 0.0)), previa("lua", m_lua, (0, 0), 0.6)]
        w = ims[0].width // 2
        g = Image.new("RGB", (w * 3, w * 2))
        for i, im in enumerate(ims):
            g.paste(im.convert("RGB").resize((w, w), Image.LANCZOS), ((i % 3) * w, (i // 3) * w))
        g.save(os.path.join(a.previa, "astros.png"))
        ims[0].convert("RGB").save(os.path.join(a.previa, "sol_grande.png"))
        ims[3].convert("RGB").save(os.path.join(a.previa, "lua_grande.png"))


if __name__ == "__main__":
    main()
