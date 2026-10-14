#!/usr/bin/env python3
"""Brasões do Egito (os alvos de sol e de lua de scripts/deserto.gd) em alta
definição, no mesmo estilo joia do sol e da lua do céu (tools/gerar_astros.py):

  lua  medalhão de prata com as fases da lua cravadas no aro; no meio a
       lua (mares e crateras) com o Olho de Hórus em prata e esmalte azul
       de lápis-lazúli, olho de íris azul-clara
  sol  medalhão de ouro com quatro pontas de raio e pedras no aro; no meio
       o sol (plasma laranja) com o Olho de Rá em ouro e esmalte de
       lápis-lazúli, íris âmbar

O olho é o mesmo hieróglifo do astro (gerar_astros.tracos: a cauda sai da
pálpebra, a lágrima e a espiral saem da linha de baixo), só que menor.

Cada brasão sai numa folha 768x768 com 4 quadros de 384 px:
  (0,0) parado   (1,0) (0,1) (1,1) acerto: trincas crescendo e o clarão
O jogo mostra o quadro com escala 2/3 (o mesmo tamanho dos antigos de 256).

    python3 tools/gerar_brasoes.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
import gerar_astros as A

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")
N = 384              # lado do quadro
SS = 2               # desenha em 2x e reduz (bordas lisas)
W = N * SS
R_ARO = 0.455 * W    # borda de fora do aro
R_FACE = 0.355 * W   # borda da face (dentro do aro)


def preparar_escala():
    """O hieróglifo e as superfícies do gerar_astros leem estas medidas do
    módulo: aqui valem para a face do brasão."""
    A.S = W
    A.C = W / 2
    A.R = R_FACE
    A.U = R_FACE * 0.60
    A.UX = A.U * A.ESTICA
    A.K = A.U / (279.0 * 0.92)
    A.X = 3.0 * A.K
    A.OLHO_DX = -0.235 * A.UX


def disco(r, raio, aa=1.2):
    return np.clip((raio - r) / aa + 0.5, 0, 1)


def aro_relevo(r, ang, lua, rng):
    """Altura do aro: bisel arredondado, filetes e gravura fina."""
    t = np.clip((r - R_FACE) / (R_ARO - R_FACE), 0, 1)
    h = np.clip(np.sin(np.pi * t), 0, 1) ** 0.6        # bisel
    h += 0.35 * np.exp(-((t - 0.12) / 0.04) ** 2)       # filete de dentro
    h += 0.35 * np.exp(-((t - 0.90) / 0.04) ** 2)       # filete de fora
    # gravura: ondas (lua) ou raios finos (sol) no meio do aro
    meio = np.exp(-((t - 0.5) / 0.22) ** 2)
    if lua:
        g = 0.5 + 0.5 * np.sin(ang * 48 + 3.0 * np.sin(t * 9.0))
    else:
        g = 0.5 + 0.5 * np.sin(ang * 72)
    h -= 0.16 * meio * g
    h += 0.05 * A.fbm(r.shape, rng, (8, 4, 2), (1, 0.6, 0.3))
    return h * (t > 0) * (t < 1)


def joias(lua, rng):
    """Pedras cravadas no aro: fases da lua (8) ou pedras de lápis (4) +
    pontas de raio (sol). Devolve (altura, cor, alfa) extras."""
    yy, xx = np.mgrid[0:W, 0:W].astype(np.float32) - W / 2 + 0.5
    alt = np.zeros((W, W), np.float32)
    cor = np.zeros((W, W, 3), np.float32)
    alfa = np.zeros((W, W), np.float32)
    rc = (R_FACE + R_ARO) / 2
    n = 8 if lua else 4
    rj = (R_ARO - R_FACE) * (0.42 if lua else 0.36)
    for i in range(n):
        a = -np.pi / 2 + 2 * np.pi * i / n + (0.0 if lua else np.pi / 4)
        cx, cy = np.cos(a) * rc, np.sin(a) * rc
        d = np.hypot(xx - cx, yy - cy) / rj
        dentro = disco(d * rj, rj)
        cupula = np.sqrt(np.clip(1 - d * d, 0, 1))
        if lua:
            # a fase: a sombra vem de um lado conforme a posição no aro
            fase = (i / n) * 2 * np.pi
            sx = np.cos(fase) * 1.25
            claro = np.clip((np.hypot(xx - cx - sx * rj, yy - cy) / rj - 1.0) * 3.0 + 0.5, 0, 1) if i != 0 else np.ones_like(d)
            if i == n // 2:
                claro = np.zeros_like(d) + 0.12
            base = np.array([0.82, 0.90, 1.0]) * (0.25 + 0.75 * claro[..., None])
            base = base * (0.75 + 0.25 * cupula[..., None]) + np.array([0.10, 0.14, 0.30]) * (1 - claro[..., None]) * 0.4
        else:
            base = np.array([0.10, 0.24, 0.62]) * (0.55 + 0.6 * cupula[..., None])   # lápis-lazúli
            pint = (A.ruido(d.shape, 1.2, rng) > 2.0).astype(np.float32)             # pirita dourada
            base = base * (1 - 0.8 * pint[..., None]) + np.array([1.0, 0.85, 0.4]) * 0.8 * pint[..., None]
        brilho = np.exp(-(np.hypot(xx - cx + 0.35 * rj, yy - cy + 0.35 * rj) / (0.22 * rj)) ** 2)
        base = base + brilho[..., None] * 0.8
        # garra de metal em volta da pedra
        garra = np.exp(-((d - 1.08) / 0.10) ** 2)
        alt = np.maximum(alt, garra * 1.2)
        cor = cor * (1 - dentro[..., None]) + np.clip(base, 0, 1) * dentro[..., None]
        alfa = np.maximum(alfa, dentro)
    return alt, cor, alfa


def pontas_sol(xx, yy):
    """Quatro pontas de raio saindo do aro (como o brasão antigo)."""
    m = np.zeros_like(xx)
    ang = np.arctan2(yy, xx)
    r = np.hypot(xx, yy)
    for i in range(4):
        a = i * np.pi / 2
        da = np.angle(np.exp(1j * (ang - a)))
        # largura cai com a distância: ponta fina
        larg = 0.16 * np.clip((0.497 * W - r) / (0.497 * W - R_ARO * 0.9), 0, 1)
        m = np.maximum(m, np.clip((larg - np.abs(da)) / 0.012, 0, 1) * (r > R_ARO * 0.85) * (r < 0.497 * W))
    return m


def olho_na_face(olho, centro, cores_iris, cor_esclera, cor_canto, rng):
    """Branco do olho, íris e pupila pintados na abertura (o olho do brasão
    é fixo: o astro do céu é que pisca e olha)."""
    yy, xx = np.mgrid[0:W, 0:W].astype(np.float32) - W / 2 + 0.5
    xu = (xx - centro[0]) / A.UX * olho.esp
    yu = (yy - centro[1]) / A.U
    abre = olho.mascara(xu, yu, 1.2 / A.U)
    canto = A.suave(0.45, 1.05, np.abs(xu))
    cor = cor_esclera * (1 - 0.45 * canto[..., None]) + cor_canto * (0.45 * canto[..., None])
    cor = cor * (1 - 0.18 * A.suave(0.0, 0.30, yu)[..., None])
    # íris grande (encosta nas pálpebras, como no hieróglifo) olhando para frente
    ri = olho.r_iris * A.U
    ix, iy = centro[0] + olho.iris_c[0] * A.UX * olho.esp, centro[1] + olho.iris_c[1] * A.U
    d = np.hypot(xx - ix, yy - iy) / ri
    ang = np.arctan2(yy - iy, xx - ix)
    c0, c1, c2, c3 = [np.array(c, np.float32) for c in cores_iris]
    k1 = A.suave(0.30, 0.68, d)[..., None]
    k2 = A.suave(0.66, 0.96, d)[..., None]
    ci = c0 * (1 - k1) + c1 * k1
    ci = ci * (1 - k2) + c2 * k2
    fib = np.sin(ang * 41 + 2.5 * np.sin(ang * 3)) * np.sin(d * 8)
    ci = ci * (1 + 0.16 * fib[..., None] * A.suave(0.4, 0.6, d)[..., None])
    ci = ci * (1 - A.suave(0.86, 1.0, d)[..., None]) + c3 * A.suave(0.86, 1.0, d)[..., None]
    pup = A.suave(0.46, 0.41, d)[..., None]
    ci = ci * (1 - pup) + np.array([0.02, 0.02, 0.03]) * pup
    ref = A.suave(0.20, 0.10, np.hypot((xx - ix) / ri + 0.34, (yy - iy) / ri + 0.36))[..., None]
    ci = ci * (1 - 0.9 * ref) + 0.9 * ref
    a_iris = A.suave(1.0 + 1.2 / ri, 1.0 - 1.2 / ri, d)
    cor = cor * (1 - a_iris[..., None]) + ci * a_iris[..., None]
    # sombra da pálpebra de cima sobre o olho
    somb = np.exp(-np.clip(yu - olho.cima(np.clip(xu, -1, 1)), 0, None) / 0.10) * 0.45
    cor = cor * (1 - somb[..., None])
    return np.clip(cor, 0, 1), abre


def brasao(nome, seed):
    rng = np.random.default_rng(seed)
    lua = nome == "lua"
    preparar_escala()
    yy, xx = np.mgrid[0:W, 0:W].astype(np.float32) - W / 2 + 0.5
    r = np.hypot(xx, yy)
    ang = np.arctan2(yy, xx)
    olho = A.Olho(lua)        # lua = Hórus (o esquerdo), sol = Rá
    if lua:
        face = A.superficie_lua(xx, yy, rng)
        face = np.clip(face * np.array([1.12, 1.12, 1.10]) + np.array([0.06, 0.08, 0.12]), 0, 1)   # lua clara
        metal_cor = np.array([0.88, 0.92, 0.98])
        metal_brilho = np.array([1.0, 1.0, 1.0])
        esmalte_cor = np.array([0.14, 0.30, 0.70])          # lápis-lazúli
        contorno_cor = np.array([0.03, 0.05, 0.14])
        aro_cor = np.array([0.66, 0.72, 0.84])
        iris = [(0.96, 0.98, 1.0), (0.66, 0.82, 1.0), (0.30, 0.52, 0.92), (0.06, 0.14, 0.40)]
        esclera, canto = np.array([0.94, 0.96, 1.0]), np.array([0.64, 0.70, 0.86])
    else:
        face = A.superficie_sol(xx, yy, rng)
        metal_cor = np.array([1.0, 0.84, 0.40])
        metal_brilho = np.array([1.0, 0.98, 0.84])
        esmalte_cor = np.array([0.12, 0.26, 0.66])
        contorno_cor = np.array([0.30, 0.14, 0.0])
        aro_cor = np.array([1.0, 0.80, 0.34])
        iris = [(1.0, 0.86, 0.36), (0.84, 0.56, 0.16), (0.48, 0.26, 0.08), (0.16, 0.07, 0.02)]
        esclera, canto = np.array([1.0, 0.94, 0.82]), np.array([0.90, 0.66, 0.42])

    # ── face com o olho
    centro = (A.OLHO_DX * olho.esp, -0.03 * A.U)
    metal, esmalte, fios = A.hieroglifo(olho, centro)
    esmalte = esmalte * (1 - fios)
    peca = np.maximum(metal, esmalte)
    k = A.K
    somb = ndi.shift(ndi.gaussian_filter(peca, 3.0 * k), (4 * k, 3 * k), order=1)
    face = face * (1 - 0.35 * somb[..., None])
    lado = int(round(2 * k)) * 2 + 1
    contorno = ndi.gaussian_filter(np.clip(ndi.grey_dilation(peca, size=(lado, lado)) - peca, 0, 1), 0.7 * k)
    face = face * (1 - 0.6 * contorno[..., None]) + contorno_cor * (0.6 * contorno[..., None])
    olho_cor, abre = olho_na_face(olho, centro, iris, esclera, canto, rng)
    abre = abre * (1 - peca)
    face = face * (1 - abre[..., None]) + olho_cor * abre[..., None]
    # miolo da cauda: o branco do olho seguindo para trás entre as duas linhas
    xu = (xx - centro[0]) / A.UX * olho.esp
    yu = (yy - centro[1]) / A.U
    fx = ndi.gaussian_filter(A.faixa_cauda(olho, xu, yu), 0.8 * A.K) * (1 - peca)
    somb_fx = np.exp(-np.clip(yu - A.linha_cima(olho, np.clip(xu, -1, A.CAUDA_FIM)), 0, None) / 0.08) * 0.30
    face = face * (1 - fx[..., None]) + (esclera * (1 - somb_fx[..., None])) * fx[..., None]
    altura = ndi.gaussian_filter(peca, 2.0 * k) - 0.30 * ndi.gaussian_filter(esmalte, 1.0 * k) + \
        0.30 * ndi.gaussian_filter(fios, 0.7 * k)
    esm = esmalte_cor[None, None, :] * (0.80 + 0.35 * A.fbm(peca.shape, rng, (30, 15, 8), (1, 0.5, 0.3))[..., None])
    lit_metal = A.iluminar(altura * 10.0 * A.K, metal_cor, metal_brilho, brilho_exp=16.0, ambiente=0.35)
    lit_esm = A.iluminar(altura * 10.0 * A.K, esm, metal_brilho, brilho_exp=40.0, ambiente=0.45, brilho=0.7)
    cor_peca = lit_metal * (1 - esmalte[..., None]) + lit_esm * esmalte[..., None]
    face = face * (1 - peca[..., None]) + cor_peca * peca[..., None]
    # a face fica um pouco funda no aro: sombra rente à borda de dentro
    face = face * (1 - 0.35 * A.suave(R_FACE * 0.86, R_FACE, r)[..., None])

    # ── aro de metal
    h = aro_relevo(r, ang, lua, rng)
    j_alt, j_cor, j_alfa = joias(lua, rng)
    h = h + j_alt * 0.6
    aro_lit = A.iluminar(h * 22.0, aro_cor * (0.85 + 0.25 * A.fbm(r.shape, rng, (20, 10, 5), (1, 0.5, 0.3))[..., None]),
                         metal_brilho, forca=1.0, brilho_exp=18.0, ambiente=0.32, brilho=0.8)
    aro_lit = aro_lit * (1 - j_alfa[..., None]) + j_cor * j_alfa[..., None]

    cor = face * (r <= R_FACE)[..., None] + aro_lit * (r > R_FACE)[..., None]
    alfa = disco(r, R_ARO, 1.5)
    if not lua:
        pts = pontas_sol(xx, yy)
        hp = ndi.gaussian_filter(pts, 2.0) * (1 - np.clip((r - R_ARO) / (0.05 * W), 0, 1) * 0.5)
        pts_lit = A.iluminar(hp * 18.0, aro_cor, metal_brilho, brilho_exp=14.0, ambiente=0.4)
        fora = pts * (r > R_ARO - 2)
        cor = cor * (1 - fora[..., None]) + pts_lit * fora[..., None]
        alfa = np.maximum(alfa, fora)
    # contorno escuro fininho por fora (lê sobre qualquer fundo)
    borda = np.clip(ndi.grey_dilation(alfa, size=(5, 5)) - alfa, 0, 1)
    cor = cor * (1 - borda[..., None]) + contorno_cor * borda[..., None]
    alfa = np.maximum(alfa, borda * 0.9)
    return np.dstack([np.clip(cor, 0, 1), alfa]), (face, r, contorno_cor)


def trincas(base, n_galhos, forca, seed, clarao):
    """Quadro de acerto: trincas saindo do meio (escuro com fio claro) e um
    clarão branco-azulado/dourado por cima."""
    rng = np.random.default_rng(seed)
    out = base.copy()
    im = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(im)
    c = np.array([W / 2 + rng.uniform(-20, 20), W / 2 + rng.uniform(-20, 20)])
    for g in range(n_galhos):
        p = c.copy()
        a = 2 * np.pi * g / n_galhos + rng.uniform(-0.3, 0.3)
        comp = R_ARO * forca * rng.uniform(0.7, 1.0)
        pts = [tuple(p)]
        passos = 7
        for s in range(passos):
            a += rng.uniform(-0.35, 0.35)
            p = p + np.array([np.cos(a), np.sin(a)]) * comp / passos
            pts.append(tuple(p))
        d.line(pts, fill=255, width=int(7 - 4 * 0))
    m = np.asarray(im).astype(np.float32) / 255
    m = ndi.gaussian_filter(m, 1.0)
    fio = np.clip(ndi.shift(m, (-2, -2)) - m, 0, 1)
    a = out[..., 3]
    out[..., :3] = out[..., :3] * (1 - 0.85 * m[..., None]) + np.array([0.02, 0.02, 0.04]) * 0.85 * m[..., None]
    out[..., :3] = out[..., :3] + fio[..., None] * 0.9
    if clarao > 0:
        yy, xx = np.mgrid[0:W, 0:W].astype(np.float32)
        g = np.exp(-(np.hypot(xx - c[0], yy - c[1]) / (0.30 * W)) ** 2) * clarao
        out[..., :3] = out[..., :3] + g[..., None]
    out[..., 3] = a
    return np.clip(out, 0, 1)


def reduzir(arr):
    im = Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    # pré-multiplica para reduzir sem franja escura nas bordas
    p = np.asarray(im).astype(np.float32) / 255
    p[..., :3] *= p[..., 3:4]
    pm = Image.fromarray((p * 255 + 0.5).astype(np.uint8), "RGBA").resize((N, N), Image.LANCZOS)
    q = np.asarray(pm).astype(np.float32) / 255
    q[..., :3] /= np.maximum(q[..., 3:4], 1e-4)
    return Image.fromarray((np.clip(q, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def main():
    for nome, arquivo, seed in (("lua", "egito_brasao_lua.png", 31), ("sol", "egito_brasao_sol.png", 47)):
        base, _ = brasao(nome, seed)
        quadros = [base,
                   trincas(base, 4, 0.45, seed + 1, 0.0),
                   trincas(base, 7, 0.80, seed + 2, 0.25),
                   trincas(base, 9, 1.00, seed + 3, 0.65)]
        folha = Image.new("RGBA", (2 * N, 2 * N), (0, 0, 0, 0))
        for i, q in enumerate(quadros):
            folha.paste(reduzir(q), ((i % 2) * N, (i // 2) * N))
        folha.save(os.path.join(SP, arquivo), optimize=True)
        print("  %s  %dx%d (4 quadros de %d)" % (arquivo, folha.width, folha.height, N))


if __name__ == "__main__":
    main()
