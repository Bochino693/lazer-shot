#!/usr/bin/env python3
"""O navio que afunda no Mar com cor de navio (scripts/mar_vida.gd).

sprites/mar_navio.png (tools/gerar_mar.py) é o navio recortado da foto: uma
silhueta azul-escura. Aqui ele ganha as cores de um galeão de verdade
(debaixo d'água, com um véu azul por cima):

  casco      madeira (escura nas frestas, mel nas tábuas, clara onde a luz
             pega) com a faixa pintada de ocre logo abaixo da amurada
  mastros    madeira escura; cordas quase pretas
  velas      pano velho, rasgado, cor de linho
  furo       um rombo no casco, como se tivesse sido atingido: buraco escuro,
             tábuas lascadas em volta (pontas claras) e a madeira chamuscada

e a borda fica limpa (sem o véu de água em volta).

  sprites/mar_navio_cor.png   (mesmo tamanho e canto do mar_navio.png)

    python3 tools/gerar_navio_cor.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")
FURO = (176.0, 404.0)          # o rombo (px do sprite)
FURO_R = 23.0
rng = np.random.default_rng(77)


def suave(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def main():
    im = np.asarray(Image.open(os.path.join(SP, "mar_navio.png")).convert("RGBA")).astype(np.float32) / 255
    rgb, a = im[..., :3], im[..., 3]
    h, w = a.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    lum = rgb @ np.array([0.3, 0.59, 0.11], np.float32)
    dentro = a > 0.3
    lo, hi = np.percentile(lum[dentro], 3), np.percentile(lum[dentro], 97)
    L = np.clip((lum - lo) / max(hi - lo, 1e-3), 0, 1)
    # casco embaixo da linha da amurada (inclinada: a proa desce à esquerda)
    amurada = 248.0 + 0.30 * xx
    casco = suave(yy - amurada, -6, 10)
    faixa = suave(yy - amurada, 4, 10) * (1 - suave(yy - amurada, 22, 30))
    # madeira: escura nas frestas, mel nas tábuas, clara onde a luz pega
    escuro, mel, claro = np.array([0.17, 0.09, 0.05]), np.array([0.50, 0.30, 0.15]), np.array([0.82, 0.60, 0.34])
    t1 = suave(L, 0.0, 0.55)[..., None]
    t2 = suave(L, 0.55, 1.0)[..., None]
    madeira = escuro * (1 - t1) + mel * t1
    madeira = madeira * (1 - t2) + claro * t2
    # veio da madeira (tábuas na horizontal, seguindo a inclinação)
    veio = 0.92 + 0.08 * np.sin((yy - 0.30 * xx) * 0.9 + np.sin(xx * 0.05) * 2.0)
    madeira = madeira * veio[..., None]
    ocre = np.array([0.66, 0.46, 0.16]) * (0.55 + 0.6 * L[..., None])
    madeira = madeira * (1 - 0.55 * faixa[..., None]) + ocre * (0.55 * faixa[..., None])
    # em cima: velas de linho velho nas partes claras, mastros e cordas escuros
    linho = np.array([0.80, 0.74, 0.60]) * (0.55 + 0.5 * L[..., None])
    corda = np.array([0.20, 0.13, 0.08]) * (0.8 + 0.6 * L[..., None])
    vela = suave(L, 0.35, 0.75)[..., None]
    alto = corda * (1 - vela) + linho * vela
    cor = alto * (1 - casco[..., None]) + madeira * casco[..., None]
    # o rombo: buraco escuro, tábuas lascadas em volta e madeira chamuscada
    big = 4
    furo = Image.new("L", (w * big, h * big), 0)
    lasca = Image.new("L", (w * big, h * big), 0)
    df, dl = ImageDraw.Draw(furo), ImageDraw.Draw(lasca)
    pts, pl = [], []
    for k in range(22):
        ang = 2 * np.pi * k / 22
        r = FURO_R * rng.uniform(0.62, 1.0) * (1.0 + 0.15 * np.sin(ang * 3))
        pts.append(((FURO[0] + np.cos(ang) * r * 1.25) * big, (FURO[1] + np.sin(ang) * r * 0.8) * big))
    df.polygon(pts, fill=255)
    # tábuas quebradas: lascas finas, de tamanhos diferentes, entrando no
    # buraco (a bala entrou: as pontas apontam para dentro)
    for k in range(9):
        ang = 2 * np.pi * k / 9 + rng.uniform(-0.3, 0.3)
        c = np.array(FURO)
        dirv = np.array([np.cos(ang) * 1.25, np.sin(ang) * 0.8])
        p0 = c + dirv * FURO_R * rng.uniform(1.05, 1.25)
        p1 = c + dirv * FURO_R * rng.uniform(0.35, 0.7)
        lado = np.array([-np.sin(ang), np.cos(ang)]) * rng.uniform(1.2, 2.4)
        pl.append([tuple((p0 + lado) * big), tuple(p1 * big), tuple((p0 - lado) * big)])
    for tri in pl:
        dl.polygon(tri, fill=255)
    m_furo = np.asarray(furo.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255
    m_lasca = np.asarray(lasca.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255
    d = np.sqrt(((xx - FURO[0]) / 1.25) ** 2 + ((yy - FURO[1]) / 0.8) ** 2)
    queimado = np.clip(1 - (d - FURO_R) / (FURO_R * 1.4), 0, 1) * casco
    cor = cor * (1 - 0.6 * queimado[..., None])
    fundo_furo = np.array([0.02, 0.025, 0.03]) + np.array([0.04, 0.08, 0.11]) * suave(d, 0, FURO_R)[..., None]
    cor = cor * (1 - m_furo[..., None]) + fundo_furo * m_furo[..., None]
    # a madeira lascada (a parte de dentro da tábua, mais clara que a
    # pintura, com a beira escura)
    lasca_cor = np.array([0.60, 0.44, 0.27]) * (0.8 + 0.3 * L[..., None])
    borda = np.clip(m_lasca - ndi.grey_erosion(m_lasca, size=(3, 3)), 0, 1)[..., None]
    cor = cor * (1 - m_lasca[..., None]) + lasca_cor * m_lasca[..., None]
    cor = cor * (1 - 0.5 * borda)
    # véu azul de debaixo d'água (leve: a cor do navio aparece)
    cor = cor * 0.80 + np.array([0.20, 0.36, 0.48]) * 0.20
    # borda limpa: o véu de água em volta some, o miúdo fica; o casco é
    # inteiro (a água não aparece através da madeira)
    a2 = suave(a, 0.18, 0.62)
    cheio = ndi.binary_closing((a > 0.22) & (casco > 0.5), structure=np.ones((3, 3)), iterations=7)
    cheio = ndi.binary_fill_holes(cheio)
    cheio = ndi.gaussian_filter(cheio.astype(np.float32), 1.0) * (casco > 0.2)
    a2 = np.maximum(a2, cheio)
    # a proa: corta o bloco reto da esquerda (pedaço refeito atrás da pedra)
    # numa proa inclinada, como a de um galeão
    linha_proa = 18.0 + np.clip(yy - 250.0, 0, None) * (52.0 / 230.0)
    a2 = a2 * suave(xx - linha_proa, -2.0, 4.0)
    a2 = a2 * (1 - (1 - suave(xx, 24.0, 40.0)) * (yy < 252.0))
    a2 = np.maximum(a2, (m_furo + m_lasca) * (a > 0.05))
    out = np.dstack([np.clip(cor, 0, 1), a2])
    Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(SP, "mar_navio_cor.png"), optimize=True)
    print("mar_navio_cor.png", out.shape, "furo em", FURO)


if __name__ == "__main__":
    main()
