#!/usr/bin/env python3
"""Prepara a arte do Lazer Shot para a TV Box Mali-450 (Godot 3.6, OpenGL ES 2).

A versão 4.6 usa folhas enormes (1536x1024 por garrafa, 2214x716 das
lanternas) e fundos em camadas. Aqui cada imagem sai no tamanho em que
aparece na TV (1080x1920 em pé), recortada e sem sobra:

  fundos     JPG 1080x1920 (o fundo cobre a tela como na 4.6: escala 1,25 da
             imagem 1024x1536 e as laterais cortadas). Sem transparência: o
             Godot 3 comprime em ETC1 na placa (1 MB cada na memória).
  alvos      PNG com transparência, uma folha por alvo, quadros do mesmo
             tamanho lado a lado (parado primeiro, depois o acerto). Sem
             compressão (o ETC1 da Mali-450 não tem alfa) e por isso no
             tamanho certo: cada folha tem poucas centenas de KB.
  efeitos    brilho, anel, estrela, faísca, raios, feixe, mira: desenhados
             aqui em PNG pequeno, branco, para o jogo tingir e somar luz.

Também grava scripts/dados_arte.gd (quadros e máscaras de acerto de cada
alvo) e o .import de cada imagem e som com as opções certas para a Mali-450.

Rodar da raiz do projeto:   python3 tools/preparar_mali.py
Os fundos em alta (1536x2304) vêm de LAZER_HD (padrão: ../lazer-shot/tools/hd,
a pasta da versão 4.6); sem eles, sai da imagem 1024x1536 de arte_original.
"""
import json
import math
import os
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = Path(__file__).resolve().parent.parent
ORIG = RAIZ / "arte_original" / "sprites"
SAIDA = RAIZ / "sprites"
HD = Path(os.environ.get("LAZER_HD", str(RAIZ.parent / "lazer-shot" / "tools" / "hd")))

# A tela em pé: 1024 x 1820 no jogo, 1080 x 1920 na TV.
TELA_TV = (1080, 1920)
# Fundo 1024x1536 cobrindo a tela: escala 1,25 (1920/1536), largura 1280,
# 100 px cortados de cada lado.
ESCALA_FUNDO = 1.25
CORTE_X = 100


def tex_para_tv(p):
    """Pixel da imagem 1024x1536 da 4.6 -> pixel do fundo 1080x1920."""
    return (p[0] * ESCALA_FUNDO - CORTE_X, p[1] * ESCALA_FUNDO)


# ------------------------------------------------------------------ fundos
def enquadrar(im, corte_max=None, filtro=Image.LANCZOS):
    """A imagem 2:3 da 4.6 no fundo 1080x1920 em pé. Nas fases ela cobre a
    tela (escala 1,25 e 100 px cortados de cada lado). No menu (corte_max) faz
    como o fundo vivo da 4.6: corta no máximo essa fração de cada lateral e
    aperta o resto um pouco, para os logos das bordas não sumirem."""
    larg = round(1024 * ESCALA_FUNDO)
    im = im.resize((larg, TELA_TV[1]), filtro)
    if corte_max is None:
        return im.crop((CORTE_X, 0, CORTE_X + TELA_TV[0], TELA_TV[1]))
    corte = min(CORTE_X, round(larg * corte_max))
    return im.crop((corte, 0, larg - corte, TELA_TV[1])).resize(TELA_TV, filtro)


def fundo(nome_orig, nome_saida, nitidez=True, corte_max=None):
    hd = HD / (Path(nome_orig).stem + "@hd.png")
    if hd.exists():
        im = Image.open(hd).convert("RGB")
    else:
        im = Image.open(ORIG / nome_orig).convert("RGB")
    im = enquadrar(im, corte_max)
    if nitidez and not hd.exists():
        im = im.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
    im.save(SAIDA / nome_saida, quality=92, subsampling=0, optimize=True)
    print("fundo", nome_saida, "(alta)" if hd.exists() else "(1024)")
    return im


# ------------------------------------------------------------------ folhas
def recorte(arq, r):
    with Image.open(ORIG / arq) as im:
        return im.convert("RGBA").crop((int(r[0]), int(r[1]), int(r[0] + r[2]), int(r[1] + r[3])))


def aparar(im, folga=2):
    """Recorta a transparência em volta (mantém o desenho centrado depois)."""
    a = np.array(im)[:, :, 3]
    ys, xs = np.nonzero(a > 6)
    if len(xs) == 0:
        return im
    x0, x1 = max(0, xs.min() - folga), min(im.width, xs.max() + 1 + folga)
    y0, y1 = max(0, ys.min() - folga), min(im.height, ys.max() + 1 + folga)
    return im.crop((x0, y0, x1, y1))


def mascara(im, n=24):
    """Máscara de acerto n x n (o tiro só vale no desenho, como na 4.6)."""
    a = np.array(im.convert("RGBA").resize((n, n), Image.BILINEAR))[:, :, 3]
    linhas = []
    for y in range(n):
        linhas.append("".join("1" if a[y, x] > 70 else "0" for x in range(n)))
    return linhas


def folha(nome, quadros, escala, centrar=True, aparar_quadros=True, cel=None):
    """Junta os quadros (imagens RGBA) numa folha de uma linha, células do
    mesmo tamanho, cada quadro escalado por `escala` e centrado na célula."""
    prontos = []
    for q in quadros:
        if aparar_quadros:
            q = aparar(q)
        if escala != 1.0:
            q = q.resize((max(1, round(q.width * escala)), max(1, round(q.height * escala))), Image.LANCZOS)
        prontos.append(q)
    if cel is None:
        cw = max(q.width for q in prontos)
        ch = max(q.height for q in prontos)
    else:
        cw, ch = cel
    # lados pares (o centro do quadro cai num pixel inteiro)
    cw += cw % 2
    ch += ch % 2
    sheet = Image.new("RGBA", (cw * len(prontos), ch), (0, 0, 0, 0))
    for i, q in enumerate(prontos):
        x = i * cw + (cw - q.width) // 2
        y = (ch - q.height) // 2 if centrar else ch - q.height
        sheet.alpha_composite(q, (x, y))
    sheet.save(SAIDA / (nome + ".png"), optimize=True)
    print("folha", nome, sheet.size, len(prontos), "quadros")
    return {"arquivo": "res://sprites/%s.png" % nome, "quadros": len(prontos), "celula": [cw, ch],
            "mascara": mascara(sheet.crop((0, 0, cw, ch)))}


def regioes(arq, lista):
    return [recorte(arq, r) for r in lista]


# ------------------------------------------------------------------ efeitos
def salvar_alfa(nome, a, cor=(255, 255, 255)):
    """a: matriz float 0..1 -> PNG branco com essa transparência."""
    a = np.clip(a, 0.0, 1.0)
    h, w = a.shape
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, 0] = cor[0]
    rgba[:, :, 1] = cor[1]
    rgba[:, :, 2] = cor[2]
    rgba[:, :, 3] = (a * 255.0 + 0.5).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(SAIDA / (nome + ".png"), optimize=True)
    print("efeito", nome, (w, h))


def grade(n):
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    c = (n - 1) / 2.0
    return (x - c) / c, (y - c) / c


def efeitos():
    # brilho redondo macio (luz somada: clarões, halos, faíscas)
    x, y = grade(128)
    r = np.sqrt(x * x + y * y)
    salvar_alfa("fx_brilho", np.exp(-(r * 2.2) ** 2) * (r < 1.0))
    # brilho com miolo forte (estrelas de luz, partículas pequenas)
    salvar_alfa("fx_ponto", np.clip(np.exp(-(r * 3.2) ** 2) * 1.2 + np.exp(-(r * 1.4) ** 2) * 0.25, 0, 1) * (r < 1.0))
    # anel macio (ondas de choque, anéis da bala)
    salvar_alfa("fx_anel", np.exp(-((r - 0.80) / 0.075) ** 2) * (r < 1.0))
    # estrela de quatro pontas finas (impacto do sol, cintilar)
    sx = np.exp(-(np.abs(y) * 26.0) ** 1.2) * np.clip(1.0 - np.abs(x), 0, 1) ** 2.2
    sy = np.exp(-(np.abs(x) * 26.0) ** 1.2) * np.clip(1.0 - np.abs(y), 0, 1) ** 2.2
    salvar_alfa("fx_estrela", np.clip(sx + sy + np.exp(-(r * 5.0) ** 2), 0, 1))
    # faísca alongada (64x16: risco com pontas macias)
    yy, xx = np.mgrid[0:16, 0:64].astype(np.float32)
    fx = (xx - 31.5) / 31.5
    fy = (yy - 7.5) / 7.5
    salvar_alfa("fx_faisca", np.clip(1.0 - np.abs(fx), 0, 1) ** 1.5 * np.exp(-(fy * 2.6) ** 2))
    # raios em volta de um astro (gira devagar; 512x512, 18 raios macios)
    x, y = grade(512)
    r = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    raios = (0.5 + 0.5 * np.cos(ang * 18.0)) ** 6 * 0.85 + (0.5 + 0.5 * np.cos(ang * 7.0 + 1.3)) ** 10 * 0.5
    queda = np.clip(1.0 - r, 0, 1) ** 1.6 * np.clip(r * 3.0, 0, 1)
    salvar_alfa("fx_raios", np.clip(raios, 0, 1) * queda)
    # feixe de luz (64x256): bordas macias, some para baixo (sol na janela,
    # fachos de luz debaixo d'água, arandelas da arena)
    yy, xx = np.mgrid[0:256, 0:64].astype(np.float32)
    bx = (xx - 31.5) / 31.5
    by = yy / 255.0
    salvar_alfa("fx_feixe", np.exp(-(bx * 1.9) ** 2) * (1.0 - by) ** 1.1 * np.clip(by * 8.0, 0, 1))
    # fumaça (sopro macio irregular)
    rnd = np.random.default_rng(7)
    x, y = grade(128)
    base = np.exp(-((x * 1.5) ** 2 + (y * 1.5) ** 2))
    ruido = np.array(Image.fromarray((rnd.random((16, 16)) * 255).astype(np.uint8)).resize((128, 128), Image.BICUBIC)) / 255.0
    salvar_alfa("fx_nuvem", np.clip(base * (0.55 + 0.6 * ruido), 0, 1) * (np.sqrt(x * x + y * y) < 1.0))
    # mira (branca, tingida por fase): anel, quatro traços e o ponto
    n = 160
    im = Image.new("L", (n * 4, n * 4), 0)
    d = ImageDraw.Draw(im)
    c = n * 2
    R = int(n * 1.32)
    d.ellipse((c - R, c - R, c + R, c + R), outline=255, width=int(n * 0.16))
    for ang in range(4):
        a = math.radians(ang * 90)
        x0, y0 = c + math.cos(a) * n * 0.70, c + math.sin(a) * n * 0.70
        x1, y1 = c + math.cos(a) * n * 1.88, c + math.sin(a) * n * 1.88
        d.line((x0, y0, x1, y1), fill=255, width=int(n * 0.15))
    r0 = int(n * 0.17)
    d.ellipse((c - r0, c - r0, c + r0, c + r0), fill=255)
    im = im.resize((n, n), Image.LANCZOS)
    a = np.array(im).astype(np.float32) / 255.0
    salvar_alfa("ui_mira", a)
    # contorno escuro da mira (desenhado por baixo: lê em qualquer fundo)
    sombra = Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(2.0))
    salvar_alfa("ui_mira_sombra", np.array(sombra).astype(np.float32) / 255.0)
    # placa de alvo (anéis vermelhos e brancos): abertura, missão, menu
    n = 256
    im = Image.new("RGBA", (n * 4, n * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = n * 2
    cores = [(255, 255, 255), (225, 32, 44), (255, 255, 255), (225, 32, 44), (255, 255, 255), (225, 32, 44)]
    for i, cor in enumerate(cores):
        R = int(n * 1.96 * (1.0 - i / len(cores)))
        d.ellipse((c - R, c - R, c + R, c + R), fill=cor + (255,))
    d.ellipse((c - int(n * 1.96), c - int(n * 1.96), c + int(n * 1.96), c + int(n * 1.96)), outline=(40, 10, 14, 255), width=int(n * 0.07))
    im.resize((n, n), Image.LANCZOS).save(SAIDA / "ui_alvo.png", optimize=True)
    print("efeito ui_alvo", (n, n))
    # estrela de nível dos cartões (cheia, macia)
    n = 64
    im = Image.new("L", (n * 4, n * 4), 0)
    d = ImageDraw.Draw(im)
    c = n * 2
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = n * 1.9 if i % 2 == 0 else n * 0.78
        pts.append((c + math.cos(a) * rr, c + math.sin(a) * rr))
    d.polygon(pts, fill=255)
    salvar_alfa("ui_estrela", np.array(im.resize((n, n), Image.LANCZOS)).astype(np.float32) / 255.0)
    # caco de vidro/cristal (triângulo irregular macio) para estilhaços
    n = 48
    im = Image.new("L", (n * 4, n * 4), 0)
    d = ImageDraw.Draw(im)
    d.polygon([(n * 0.3 * 4, n * 0.15 * 4), (n * 0.92 * 4, n * 0.42 * 4), (n * 0.2 * 4, n * 0.9 * 4)], fill=255)
    a = np.array(im.resize((n, n), Image.LANCZOS)).astype(np.float32) / 255.0
    salvar_alfa("fx_caco", a)
    # trinca (rachadura ramificada) para cristal e vidro
    n = 256
    im = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(im)
    rnd2 = random.Random(11)
    def galho(x, y, ang, comp, larg, nivel):
        if nivel > 3 or comp < 8:
            return
        passos = rnd2.randint(3, 5)
        for _ in range(passos):
            ang += rnd2.uniform(-0.45, 0.45)
            nx, ny = x + math.cos(ang) * comp / passos, y + math.sin(ang) * comp / passos
            d.line((x, y, nx, ny), fill=255, width=max(1, int(larg)))
            if rnd2.random() < 0.35:
                galho(nx, ny, ang + rnd2.choice([-1, 1]) * rnd2.uniform(0.5, 1.1), comp * 0.5, larg * 0.7, nivel + 1)
            x, y = nx, ny
    for k in range(7):
        galho(n / 2, n / 2, k * math.tau / 7 + rnd2.uniform(-0.3, 0.3), n * rnd2.uniform(0.32, 0.48), 3.2, 0)
    a = np.array(im.filter(ImageFilter.GaussianBlur(0.6))).astype(np.float32) / 255.0
    salvar_alfa("fx_trinca", a)


# ------------------------------------------------------------------ cópias
def copiar(nome, novo=None, escala=1.0):
    im = Image.open(ORIG / nome).convert("RGBA")
    if escala != 1.0:
        im = im.resize((round(im.width * escala), round(im.height * escala)), Image.LANCZOS)
    im.save(SAIDA / (novo or nome), optimize=True)
    print("cópia", novo or nome, im.size)


def jpg(nome, novo, tamanho=None, corte=None):
    im = Image.open(ORIG / nome).convert("RGB")
    if corte:
        im = im.crop(corte)
    if tamanho:
        im = im.resize(tamanho, Image.LANCZOS)
    im.save(SAIDA / novo, quality=90, subsampling=0, optimize=True)
    print("jpg", novo, im.size)


# ------------------------------------------------------------------ Mar
def frente_do_navio(fundo_mar):
    """O templo e o poneglifo pequeno redesenhados por cima do navio que
    afunda lá longe (a máscara da 4.6, no fundo novo)."""
    canto = tex_para_tv((195, 530))
    tam = (430 * ESCALA_FUNDO, 381 * ESCALA_FUNDO)
    x0, y0 = round(canto[0]), round(canto[1])
    w, h = round(tam[0]), round(tam[1])
    pedaco = fundo_mar.crop((x0, y0, x0 + w, y0 + h)).convert("RGBA")
    m = Image.open(ORIG / "mar_frente_navio_mascara.png").convert("L").resize((w, h), Image.LANCZOS)
    pedaco.putalpha(m)
    pedaco.save(SAIDA / "mar_frente.png", optimize=True)
    print("mar_frente", (x0, y0), (w, h))
    return [x0, y0]


# ------------------------------------------------------------------ menu e abertura
# o menu corta no máximo 3% de cada lateral (como o fundo vivo da 4.6)
CORTE_MENU = 0.03


def _mascara_tela(nome, corte_max=None):
    """A máscara de fundo vivo da 4.6 (512x768) no enquadramento do fundo
    1080x1920 (mesma escala e corte)."""
    m = Image.open(ORIG / nome).convert("RGB").resize((1024, 1536), Image.BILINEAR)
    m = enquadrar(m, corte_max, Image.BILINEAR)
    return np.asarray(m).astype(np.float32) / 255.0


def brilhos_menu():
    """O menu da 4.6 era um vídeo (e depois o shader do fundo vivo). Aqui: o
    fundo parado e, por cima, duas camadas de luz somada em meia resolução
    tiradas do próprio fundo pela máscara: o título, o alvo e o logo (B, acende
    na batida) e as luzes do corredor (R, piscam com o grave)."""
    m = _mascara_tela("fundo_init_mascara.png", CORTE_MENU)
    base = np.asarray(Image.open(SAIDA / "fundo_menu.jpg").convert("RGB")).astype(np.float32) / 255.0
    for nome, canal, ganho in [("menu_brilho.jpg", 2, 1.3), ("menu_luzes.jpg", 0, 1.6)]:
        peso = np.clip(m[:, :, canal] * ganho, 0.0, 1.0)[:, :, None]
        luz = Image.fromarray((np.clip(base * peso, 0.0, 1.0) * 255.0).astype(np.uint8))
        luz = luz.resize((TELA_TV[0] // 2, TELA_TV[1] // 2), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.0))
        luz.save(SAIDA / nome, quality=88, subsampling=0)
    print("brilhos do menu")


def fundo_abertura():
    """A parede do estande no escuro da abertura (era um shader na 4.6):
    painéis, um foco vermelho no meio, um facho fraco de cima e a vinheta."""
    w, h = 540, 960
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    u = (xs + 0.5) / w
    v = (ys + 0.5) / h
    grao = (np.sin(u * 311.0 + np.sin(v * 173.0) * 2.0) * 0.5 + 0.5) * 0.035 + (np.sin(v * 913.0 + u * 37.0) * 0.5 + 0.5) * 0.012
    painel = (1.0 - np.clip((np.abs(np.mod(v * 8.0, 1.0) - 0.5) - 0.488) / 0.006, 0.0, 1.0)) * 0.06
    dx = (u - 0.5)
    dy = (v - 0.42) * 0.6
    spot = np.exp(-(dx * dx + dy * dy) * 7.5)
    cone = np.clip(1.0 - (np.abs(u - 0.5) - v * 0.14) / 0.30, 0.0, 1.0) * (1.0 - v) * 0.22
    col = np.zeros((h, w, 3), np.float32)
    col += np.array([0.04, 0.04, 0.05], np.float32)
    col += (grao + painel)[:, :, None]
    col += np.array([0.42, 0.06, 0.07], np.float32) * (spot * 0.5)[:, :, None]
    col += np.array([0.85, 0.88, 1.0], np.float32) * (cone * 0.12)[:, :, None]
    cx = (u - 0.5) * 1.3
    cy = (v - 0.5)
    vinheta = np.clip((1.15 - np.sqrt(cx * cx + cy * cy)) / 0.85, 0.0, 1.0)
    vinheta = vinheta * vinheta * (3.0 - 2.0 * vinheta)
    col *= vinheta[:, :, None]
    Image.fromarray((np.clip(col, 0.0, 1.0) * 255.0).astype(np.uint8)).save(SAIDA / "fundo_abertura.jpg", quality=92, subsampling=0)
    print("fundo da abertura")


# os cartões da escolha de cenário (a imagem dentro do cartão: 414x199 no
# jogo, aqui na escala da TV) com os cantos redondos já recortados (na 4.6
# era um shader)
CARTAO = (436, 210)
CARTAO_RAIO = 36


def cartoes():
    for c in ["desert", "mar", "bar", "arena"]:
        im = Image.open(ORIG / ("cene_%s.png" % c)).convert("RGB")
        # cobre o cartão (2:1) cortando as laterais da capa (2,86:1)
        esc = CARTAO[1] / im.height
        larg = round(im.width * esc)
        im = im.resize((larg, CARTAO[1]), Image.LANCZOS)
        x0 = (larg - CARTAO[0]) // 2
        im = im.crop((x0, 0, x0 + CARTAO[0], CARTAO[1])).convert("RGBA")
        # cantos redondos com borda suave (desenha em 4x e reduz)
        g = Image.new("L", (CARTAO[0] * 4, CARTAO[1] * 4), 0)
        ImageDraw.Draw(g).rounded_rectangle((0, 0, CARTAO[0] * 4 - 1, CARTAO[1] * 4 - 1), CARTAO_RAIO * 4, fill=255)
        im.putalpha(g.resize(CARTAO, Image.LANCZOS))
        im.save(SAIDA / ("cartao_%s.png" % c), optimize=True)
    print("cartões")


# ------------------------------------------------------------------ Bar
def raios_bar():
    """O sol pela janela do bar. Na 4.6 era um shader: a textura
    bar_raios_sol.png (R = força do feixe, B = distância da janela) com
    listras finas de poeira deslizando ao longo de cada raio. Aqui as listras
    saem prontas em duas imagens com as listras em pontos diferentes; o jogo
    soma as duas (luz) e troca o peso entre elas devagar: as listras andam."""
    im = Image.open(ORIG / "bar_raios_sol.png").convert("RGB").resize((512, 768), Image.BICUBIC)
    a = np.asarray(im).astype(np.float32) / 255.0
    forca, longe = a[:, :, 0], a[:, :, 2]
    h, w = forca.shape
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    # a janela em px da textura 256x384 (o shader da 4.6), aqui no dobro
    vx = (xs + 0.5) / 2.0 - 30.0
    vy = (ys + 0.5) / 2.0 - 18.0
    inclin = vx / np.maximum(vy, 4.0)
    cor = np.array([1.0, 0.78, 0.48], dtype=np.float32)
    # listras mais largas que as do shader (aqui não há o pixel da tela para
    # suavizar) e quase nenhuma perto da janela, onde os raios se juntam
    perto = np.clip((vy - 10.0) / 90.0, 0.0, 1.0)
    for nome, fase in [("bar_raios_a.jpg", 0.0), ("bar_raios_b.jpg", 2.6)]:
        listras = 0.74 + perto * (0.20 * np.sin(inclin * 60.0 + fase - longe * 3.0) + 0.08 * np.sin(inclin * 150.0 - fase * 1.7 + longe * 7.0))
        luz = np.clip(forca * listras, 0.0, 1.0)[:, :, None] * cor
        img = Image.fromarray((luz * 255.0).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
        img.save(SAIDA / nome, quality=92, subsampling=0)
    print("raios do bar")


# ------------------------------------------------------------------ Arena
# o logo (com o LED do alto) e o furo do meio, em px do fundo 1080x1920
ARENA_LOGO = (52, 148, 1048, 604)
ARENA_FURO = (538, 1098)
ARENA_FURO_MEIO = 92


def brilhos_arena():
    """Na 4.6 a Arena pulsava com a música num shader de tela cheia (logo,
    furos e LED acendendo onde a máscara manda). Na Mali-450 isso vira luz
    somada só onde brilha: a parte acesa do fundo (fundo x máscara) recortada
    no logo, em meia resolução (vira um brilho macio), e um anel de furo, nas
    duas artes (memória e fixa). Fundo preto: sem transparência, vai em ETC1."""
    a = _mascara_tela("arena_mascara.png")
    peso = np.clip(np.maximum(a[:, :, 0], a[:, :, 2]) * 1.4, 0.0, 1.0)[:, :, None]
    fx, fy = ARENA_FURO
    r = ARENA_FURO_MEIO
    for sufixo, arq in [("", "fundo_arena.jpg"), ("_fixa", "fundo_arena_fixa.jpg")]:
        base = np.asarray(Image.open(SAIDA / arq).convert("RGB")).astype(np.float32) / 255.0
        luz = Image.fromarray((np.clip(base * peso, 0.0, 1.0) * 255.0).astype(np.uint8))
        logo = luz.crop(ARENA_LOGO)
        logo = logo.resize((logo.width // 2, logo.height // 2), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.0))
        logo.save(SAIDA / ("arena_brilho_logo%s.jpg" % sufixo), quality=90, subsampling=0)
        luz.crop((fx - r, fy - r, fx + r, fy + r)).save(SAIDA / ("arena_brilho_furo%s.jpg" % sufixo), quality=92, subsampling=0)
    print("brilhos da arena")


# ------------------------------------------------------------------ ícone
def icones_android():
    """O ícone do APK: o normal (192) e o adaptável do Android 8+ (frente com o
    desenho dentro da área segura de 66% e o fundo escuro)."""
    im = Image.open(SAIDA / "icone_app.png").convert("RGBA")
    im.resize((192, 192), Image.LANCZOS).save(SAIDA / "icone_android.png", optimize=True)
    frente = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    lado = round(432 * 0.66)
    d = im.resize((lado, lado), Image.LANCZOS)
    frente.paste(d, ((432 - lado) // 2, (432 - lado) // 2), d)
    frente.save(SAIDA / "icone_android_frente.png", optimize=True)
    Image.new("RGBA", (432, 432), (16, 6, 8, 255)).save(SAIDA / "icone_android_fundo.png", optimize=True)
    print("ícones do Android")


# ------------------------------------------------------------------ main
def main():
    SAIDA.mkdir(exist_ok=True)
    dados = {}

    # fundos (cobrem a tela em pé como na 4.6)
    fundo("fundo_init.png", "fundo_menu.jpg", corte_max=CORTE_MENU)
    brilhos_menu()
    fundo_abertura()
    fundo("egito_fundo_sol.png", "fundo_egito_sol.jpg")
    fundo("egito_fundo_lua.png", "fundo_egito_lua.jpg")
    mar = fundo("atlantis_fundo.png", "fundo_mar.jpg")
    fundo("back_new.png", "fundo_bar.jpg")
    raios_bar()
    fundo("arena.png", "fundo_arena.jpg")
    fundo("arena_fixa.png", "fundo_arena_fixa.jpg")
    brilhos_arena()
    dados["mar_frente"] = frente_do_navio(mar)

    # capas dos cenários (cartões e missão): faixa larga em meia resolução
    for c in ["desert", "mar", "bar", "arena"]:
        jpg("cene_%s.png" % c, "capa_%s.jpg" % c, (1060, 371))
    cartoes()

    # ---- alvos do Egito: brasões (parado + 3 quadros trincando)
    for astro in ["sol", "lua"]:
        q = regioes("egito_brasao_%s.png" % astro, [(0, 0, 384, 384), (384, 0, 384, 384), (0, 384, 384, 384), (384, 384, 384, 384)])
        dados["brasao_" + astro] = folha("alvo_brasao_" + astro, q, 0.56, aparar_quadros=False)
        dados["brasao_" + astro].update({"parado": [0], "acerto": [1, 2, 3]})
    # o astro do céu em camadas (olho vivo): texturas 4x da 4.6 -> 1,25x
    k = ESCALA_FUNDO / 4.0
    for astro in ["sol", "lua"]:
        for parte in ["disco", "esclera", "iris", "palpebra", "palpebra_baixo"]:
            copiar("egito_%s_%s.png" % (astro, parte), "astro_%s_%s.png" % (astro, parte), k)
    copiar("egito_cristal_morto_sol.png", "egito_cristal_morto_sol.png", 0.56)
    copiar("egito_cristal_morto_lua.png", "egito_cristal_morto_lua.png", 0.56)
    # águias: voo (11 quadros 256x160) e pousada (7 poses 160x128) em meia
    aguia = Image.open(ORIG / "egito_aguia.png").convert("RGBA")
    aguia.resize((aguia.width // 2, aguia.height // 2), Image.LANCZOS).save(SAIDA / "egito_aguia.png", optimize=True)
    pousada = Image.open(ORIG / "egito_aguia_pousada.png").convert("RGBA")
    pousada.resize((pousada.width // 2, pousada.height // 2), Image.LANCZOS).save(SAIDA / "egito_aguia_pousada.png", optimize=True)
    print("águias")

    # ---- alvos do Mar
    agua = regioes("aguaaa.png", [(0, 0, 272, 336), (272, 0, 272, 336), (0, 336, 272, 336), (272, 336, 272, 336),
                                  (759, 0, 253, 319), (1012, 0, 253, 319), (1265, 0, 253, 319)])
    dados["aguaviva"] = folha("alvo_aguaviva", agua, 0.62)
    dados["aguaviva"].update({"parado": [0, 1, 2, 3], "acerto": [4, 5, 6]})
    agua_a = regioes("aguaaa.png", [(514, 666, 257, 333), (0, 666, 257, 333), (0, 662, 272, 331),
                                    (759, 638, 253, 319), (1012, 638, 253, 319), (1265, 638, 253, 319)])
    dados["aguaviva_a"] = folha("alvo_aguaviva_a", agua_a, 0.62)
    dados["aguaviva_a"].update({"parado": [0, 1, 2], "acerto": [3, 4, 5]})
    vaso = regioes("sprites_vaso.png", [(0, 341, 307, 341), (307, 341, 307, 341), (614, 321, 307, 321), (921, 321, 307, 321), (1228, 341, 307, 341)])
    dados["vaso"] = folha("alvo_vaso", vaso, 0.62)
    dados["vaso"].update({"parado": [0], "acerto": [1, 2, 3, 4]})
    bau = regioes("hit_bau.png", [(0, 0, 125, 125), (125, 0, 125, 125), (250, 0, 125, 125), (375, 0, 125, 125), (375, 250, 125, 125), (250, 250, 125, 125)])
    dados["bau"] = folha("alvo_bau", bau, 1.0, aparar_quadros=False)
    dados["bau"].update({"parado": [0], "acerto": [1, 2, 3, 4, 5]})
    bomba = regioes("bomba.png", [(0, 0, 166, 166), (166, 0, 166, 166), (332, 0, 166, 166), (0, 166, 166, 166), (166, 166, 166, 166),
                                  (332, 166, 166, 166), (0, 332, 166, 166), (166, 332, 166, 166), (332, 332, 166, 166)])
    dados["bomba"] = folha("alvo_bomba", bomba, 1.0, aparar_quadros=False)
    dados["bomba"].update({"parado": [0], "acerto": [1, 2, 3, 4, 5, 6, 7, 8]})
    copiar("mar_cavalo.png", "mar_cavalo.png", 0.5)
    copiar("mar_navio_cor.png", "mar_navio.png")
    for n in ["mar_peixe_dourado.png", "mar_peixe.png", "mar_baleia_1.png", "mar_baleia_2.png", "mar_bolha.png", "mar_raios.png", "mar_farpa.png"]:
        copiar(n)

    # ---- garrafas do Bar (só a garrafa inteira: o estouro é do jogo)
    garrafas = {
        "gin": ("sprites-gin.png", (0, 0, 150, 392)),
        "rum": ("sprites-rum.png", (0, 0, 154, 400)),
        "vodka": ("sprites-vodka.png", (0, 0, 153, 388)),
        "whisky": ("sprites-whiskey.png", (0, 0, 167, 341)),
    }
    for nome, (arq, r) in garrafas.items():
        dados["garrafa_" + nome] = folha("alvo_garrafa_" + nome, [recorte(arq, r)], 1.0)
        dados["garrafa_" + nome].update({"parado": [0], "acerto": []})
    falsa = [recorte("sprites_garra.png", (272, 408, 136, 204))] + regioes("sprites_garrafa.png", [(0, 0, 136, 204), (136, 0, 136, 204), (272, 0, 136, 204), (0, 204, 136, 204),
                                                                                                    (0, 408, 136, 204), (136, 408, 136, 204), (272, 408, 136, 204)])
    dados["garrafa_falsa"] = folha("alvo_garrafa_falsa", falsa, 1.0, aparar_quadros=False)
    dados["garrafa_falsa"].update({"parado": [0], "acerto": [1, 2, 3, 4, 5, 6, 7]})
    copiar("bar_furo_madeira.png", "bar_furo_madeira.png", 0.5)
    copiar("bar_furo_papel.png", "bar_furo_papel.png", 0.5)

    # ---- lanternas da Arena: 6 cores (apagada + 5) x (parada, acerto)
    lan = Image.open(ORIG / "arena_lanternas.png").convert("RGBA")
    q = []
    for linha in range(2):
        for i in range(6):
            q.append(lan.crop((i * 369, linha * 358, i * 369 + 369, linha * 358 + 358)))
    dados["lanterna"] = folha("alvo_lanterna", q, 0.70, aparar_quadros=False)
    dados["lanterna"].update({"parado": [0, 1, 2, 3, 4, 5], "acerto": [6, 7, 8, 9, 10, 11]})

    # ---- comuns
    copiar("logo_lazer_sport.png")
    copiar("icone_app.png")
    icones_android()
    copiar("foto_vazia.png")
    for n in ["fx_fumaca.png", "fx_onda.png", "fx_furo_areia.png", "fx_furo_pedra.png", "egito_estrela.png"]:
        copiar(n)
    efeitos()

    # máscaras de cenário (o tiro pega a pedra / o navio): grade de 1 e 0
    mascaras = {}
    for nome, arq, canto in [("pedra_esq", "mar_pedra_esq_mascara.png", (0, 466)), ("pedra_dir", "mar_pedra_dir_mascara.png", (523, 523)),
                             ("navio", "mar_navio_cor.png", (0, 0))]:
        im = Image.open(ORIG / arq).convert("RGBA")
        cols = 32
        rows = max(8, round(cols * im.height / im.width))
        a = np.array(im.resize((cols, rows), Image.BILINEAR))[:, :, 3]
        grade = ["".join("1" if a[y, x] > 110 else "0" for x in range(cols)) for y in range(rows)]
        mascaras[nome] = {"canto": list(canto), "tam": [im.width, im.height], "grade": grade}
    dados["_mascaras"] = mascaras

    # dados para o jogo (quadros e máscaras)
    linhas = ["## Gerado por tools/preparar_mali.py: NÃO edite à mão.",
              "## Quadros de cada folha de alvo (células do mesmo tamanho, numa linha)",
              "## e a máscara de acerto (24x24) do quadro parado.",
              "", "const FOLHAS = " + json.dumps({k: v for k, v in dados.items() if isinstance(v, dict) and not k.startswith("_")}, ensure_ascii=False, indent="\t"),
              "", "const MAR_FRENTE = Vector2(%d, %d)" % tuple(dados["mar_frente"]),
              "", "const MASCARAS = " + json.dumps(dados["_mascaras"], ensure_ascii=False, indent="\t"), ""]
    texto = "\n".join(linhas).replace('"arquivo"', '"arquivo"')
    (RAIZ / "scripts" / "dados_arte.gd").write_text(texto, encoding="utf-8")
    print("scripts/dados_arte.gd")
    escrever_imports()



# ------------------------------------------------------------------ importação
IMPORT_TEXTURA = """[remap]

importer="texture"
type="StreamTexture"

[deps]

source_file="res://{caminho}"

[params]

compress/mode={modo}
compress/lossy_quality=0.7
compress/hdr_mode=0
compress/bptc_ldr=0
compress/normal_map=0
flags/repeat=0
flags/filter=true
flags/mipmaps=false
flags/anisotropic=false
flags/srgb=2
process/fix_alpha_border=true
process/premult_alpha=false
process/HDR_as_SRGB=false
process/invert_color=false
process/normal_map_invert_y=false
stream=false
size_limit=0
detect_3d=false
svg/scale=1.0
"""

IMPORT_WAV = """[remap]

importer="wav"
type="AudioStreamSample"

[deps]

source_file="res://{caminho}"

[params]

force/8_bit=false
force/mono=false
force/max_rate=true
force/max_rate_hz=32000
edit/trim=false
edit/normalize=false
edit/loop_mode=0
edit/loop_begin=0
edit/loop_end=-1
compress/mode=1
"""

IMPORT_OGG = """[remap]

importer="ogg_vorbis"
type="AudioStreamOGGVorbis"

[deps]

source_file="res://{caminho}"

[params]

loop={loop}
loop_offset=0
"""

IMPORT_MP3 = """[remap]

importer="mp3"
type="AudioStreamMP3"

[deps]

source_file="res://{caminho}"

[params]

loop={loop}
loop_offset=0
"""

# músicas que tocam em volta (o resto toca uma vez: vozes, fim, ranking)
MUSICAS_EM_LOOP = {"egito.mp3", "pirate.mp3", "song-oldwest.mp3", "arena_song.mp3", "audio_intro.mp3", "theme.ogg"}


def _opcoes(texto):
    """As linhas chave=valor da parte [params] de um .import."""
    if "[params]" not in texto:
        return None
    opcoes = {}
    for linha in texto.split("[params]", 1)[1].splitlines():
        if "=" in linha:
            chave, valor = linha.split("=", 1)
            opcoes[chave.strip()] = valor.strip()
    return opcoes


def _gravar_import(arq, texto):
    """Grava o .import só quando as opções mudaram, e aí apaga o .md5 que o
    Godot guardou: o Godot 3 só reimporta quando o arquivo de origem muda,
    então um .import novo com a mesma imagem ou som ficaria sem o caminho
    do arquivo importado ("Failed loading resource")."""
    destino = Path(str(arq) + ".import")
    if destino.exists():
        antigo = destino.read_text(encoding="utf-8")
        if "\npath" in antigo and _opcoes(antigo) == _opcoes(texto):
            return
    destino.write_text(texto, encoding="utf-8")
    for md5 in (RAIZ / ".import").glob(arq.name + "-*.md5"):
        md5.unlink()


def escrever_imports():
    """As opções de importação da Mali-450 (Godot 3.6) de cada arquivo:
    - JPG (fundos e capas, sem transparência): comprimido na placa (ETC1);
    - PNG (com transparência): sem compressão (o ETC1 não tem alfa e o
      Godot 3 rebaixaria a imagem para 16 tons por canal), SEM mipmaps (no
      OpenGL ES 2 a imagem de lado qualquer com mipmaps é esticada para
      potência de 2 e dobra de memória);
    - WAV: IMA-ADPCM na memória (4x menor) e no máximo 32 kHz;
    - músicas em loop; vozes e vinhetas uma vez."""
    for arq in sorted(SAIDA.glob("*")):
        rel = str(arq.relative_to(RAIZ)).replace("\\", "/")
        if arq.suffix == ".jpg":
            texto = IMPORT_TEXTURA.format(caminho=rel, modo=2)
        elif arq.suffix == ".png":
            texto = IMPORT_TEXTURA.format(caminho=rel, modo=0)
        else:
            continue
        _gravar_import(arq, texto)
    for arq in sorted((RAIZ / "songs").rglob("*")):
        rel = str(arq.relative_to(RAIZ)).replace("\\", "/")
        loop = "true" if arq.name in MUSICAS_EM_LOOP else "false"
        if arq.suffix == ".wav":
            texto = IMPORT_WAV.format(caminho=rel)
        elif arq.suffix == ".ogg":
            texto = IMPORT_OGG.format(caminho=rel, loop=loop)
        elif arq.suffix == ".mp3":
            texto = IMPORT_MP3.format(caminho=rel, loop=loop)
        else:
            continue
        _gravar_import(arq, texto)
    print("importação gravada")


if __name__ == "__main__":
    if os.environ.get("SO_IMPORTS") == "1":
        escrever_imports()
    elif os.environ.get("SO_ARENA") == "1":
        brilhos_arena()
        escrever_imports()
    elif os.environ.get("SO_BAR") == "1":
        raios_bar()
        escrever_imports()
    elif os.environ.get("SO_ICONES") == "1":
        icones_android()
        escrever_imports()
    elif os.environ.get("SO_CARTOES") == "1":
        cartoes()
        escrever_imports()
    elif os.environ.get("SO_MENU") == "1":
        fundo("fundo_init.png", "fundo_menu.jpg", corte_max=CORTE_MENU)
        brilhos_menu()
        fundo_abertura()
        escrever_imports()
    else:
        main()
