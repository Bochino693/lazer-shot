#!/usr/bin/env python3
"""Águias do céu do Egito (scripts/deserto_vivo.gd).

  sprites/egito_aguia.png   11 quadros de 256x160 lado a lado: 0 = planando,
                            1..10 = um ciclo de batida de asa. Águia-real
                            vista de baixo, cabeça para cima: asas largas com
                            as penas da ponta abertas ("dedos"), cauda em
                            leque, barriga escura, faixa clara nas asas, borda
                            clara onde a luz atravessa as penas
  sprites/egito_aguia_pousada.png
                            7 quadros de 160x128: a mesma águia pousada DE
                            FRENTE (na ponta de uma pirâmide apagada), no
                            mesmo traço, cores e escala da que voa: parada,
                            olhando para a esquerda, para a direita,
                            gritando, asas meio abertas (assentando / indo
                            voar), asas abertas (o falcão dos hieróglifos) e
                            olhando para baixo
  songs/aguia.wav           grito da águia ("kiiii-arrr") com eco do vale
  songs/aguia_noite.wav     o mesmo, mais longe: mais grave, abafado e com
                            mais eco (de noite)

    python3 tools/gerar_aguias.py            (tudo)
    python3 tools/gerar_aguias.py pousada    (só a águia pousada)
"""
import sys
import os
import wave
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as ndi
from scipy.signal import butter, sosfilt, fftconvolve

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")
SONGS = os.path.join(RAIZ, "songs")
rng = np.random.default_rng(31)

W, H = 256, 160
SS = 4
N_FLAP = 10


# ───────────────────────────────────────────── desenho
def asa(lado, e):
    """Contorno de uma asa (px do quadro, centro em (0,0), cabeça para cima).
    e = elevação da asa (-1 embaixo .. 0 reta .. 1 em cima)."""
    cima = max(e, 0.0)
    baixo = max(-e, 0.0)
    env = 1.0 - 0.34 * cima - 0.16 * baixo            # a asa encurta vista de baixo
    recua = 26.0 * cima + 6.0 * baixo                 # a mão dobra para trás subindo
    x = lambda v: lado * v * env
    ombro_f = (x(10), -12)
    pulso = (x(66), -18 + recua * 0.25)
    ponta = (x(112), -6 + recua)
    # bordo de fuga: secundárias recortadas e a cauda da asa
    fuga = [(x(98), 18 + recua * 0.6), (x(84), 24 + recua * 0.35), (x(70), 26), (x(56), 27),
            (x(42), 27), (x(28), 25), (x(14), 20)]
    return [ombro_f, pulso, ponta] + fuga, ponta, pulso, recua, env


def dedos(lado, e, ponta, pulso, recua, env):
    """Penas primárias abertas na ponta (5 'dedos')."""
    out = []
    for i in range(5):
        k = i / 4.0
        bx = lado * (96 - 6 * k) * env
        by = -8 + 26 * k + recua * (0.85 - 0.3 * k)
        comp = (24 - 6 * k) * env + 4
        ang = np.deg2rad(-12 + 22 * k) * lado
        dx = np.cos(ang) * lado * comp
        dy = np.sin(ang) * comp + 4 * k
        out.append(((bx, by), (bx + dx, by + dy), 4.2 - 0.6 * k))
    return out


def quadro(e, glide=False):
    big = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    m = Image.new("L", (W * SS, H * SS), 0)
    d = ImageDraw.Draw(m)
    cx, cy = W / 2, H / 2 - 4
    P = lambda p: ((cx + p[0]) * SS, (cy + p[1]) * SS)
    claros = Image.new("L", (W * SS, H * SS), 0)      # faixa clara nas asas
    dc = ImageDraw.Draw(claros)
    penas = Image.new("L", (W * SS, H * SS), 0)       # riscas das penas
    dp = ImageDraw.Draw(penas)
    for lado in (-1, 1):
        contorno, ponta, pulso, recua, env = asa(lado, e)
        d.polygon([P(p) for p in contorno], fill=255)
        # faixa clara (coberteiras) junto do bordo de ataque
        faixa = [(lado * 16 * env, -8), (lado * 64 * env, -12 + recua * 0.25), (lado * 80 * env, -2 + recua * 0.4),
                 (lado * 60 * env, 6), (lado * 18 * env, 6)]
        dc.polygon([P(p) for p in faixa], fill=255)
        for (a, b, w) in dedos(lado, e, ponta, pulso, recua, env):
            d.line([P(a), P(b)], fill=255, width=int(w * SS))
            d.ellipse([P(b)[0] - w * SS / 2, P(b)[1] - w * SS / 2, P(b)[0] + w * SS / 2, P(b)[1] + w * SS / 2], fill=255)
        # riscas das secundárias (da frente para trás)
        for i in range(9):
            xx = lado * (16 + 9.5 * i) * env
            dp.line([P((xx, 0)), P((xx + lado * 2, 25))], fill=255, width=int(1.0 * SS))
    # corpo, cabeça e cauda
    d.ellipse([P((-11, -26)), P((11, 22))], fill=255)
    d.ellipse([P((-7, -38)), P((7, -22))], fill=255)              # cabeça
    d.polygon([P((-3, -38)), P((3, -38)), P((1, -44)), P((-1, -44))], fill=255)   # bico
    d.polygon([P((-9, 16)), P((9, 16)), P((20, 48)), P((12, 53)), P((0, 55)), P((-12, 53)), P((-20, 48))], fill=255)
    for i in range(6):
        xx = -14 + 5.6 * i
        dp.line([P((xx * 0.4, 20)), P((xx, 50))], fill=255, width=int(1.0 * SS))

    mask = np.asarray(m.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255
    clr = np.asarray(claros.resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255
    pn = np.asarray(penas.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # cor: barriga marrom-escura, cabeça com dourado, faixa clara nas asas
    base = np.array([0.30, 0.20, 0.13])
    cor = np.ones((H, W, 3), np.float32) * base
    cor = cor * (1 - 0.35 * clr[..., None]) + np.array([0.62, 0.48, 0.32]) * (0.35 * clr[..., None])
    cabeca = np.exp(-(((xx - cx) / 9) ** 2 + ((yy - (cy - 30)) / 9) ** 2))
    cor = cor * (1 - 0.6 * cabeca[..., None]) + np.array([0.72, 0.52, 0.22]) * (0.6 * cabeca[..., None])
    bico = np.exp(-(((xx - cx) / 2.5) ** 2 + ((yy - (cy - 41)) / 3) ** 2))
    cor = cor * (1 - bico[..., None]) + np.array([0.85, 0.72, 0.30]) * bico[..., None]
    cor = cor * (1 - 0.25 * pn[..., None])
    # pontas das penas mais escuras
    longe = np.clip((np.abs(xx - cx) - 70) / 50, 0, 1)
    cor = cor * (1 - 0.35 * longe[..., None])
    # borda clara: a luz atravessa as penas na beirada
    borda = np.clip(mask - ndi.grey_erosion(mask, size=(3, 3)), 0, 1)
    cor = cor + np.array([0.55, 0.45, 0.30]) * (0.55 * borda[..., None])
    return np.dstack([np.clip(cor, 0, 1), mask])


def folha():
    quadros = [quadro(0.0, True)]
    for i in range(N_FLAP):
        fase = 2 * np.pi * i / N_FLAP
        quadros.append(quadro(np.sin(fase)))
    arr = np.concatenate(quadros, axis=1)
    Image.fromarray((arr * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(SP, "egito_aguia.png"), optimize=True)
    print("egito_aguia.png  %dx%d (%d quadros)" % (arr.shape[1], arr.shape[0], len(quadros)))


# ───────────────────────────────────────────── pousada (de frente)
WP, HP = 160, 128
POSES = ["parada", "olha_esq", "olha_dir", "grita", "asas_meio", "asas_abertas", "olha_baixo"]


def quadro_pousada(pose):
    """Águia-real pousada DE FRENTE para quem joga, no mesmo traço e cores da
    que voa: peito marrom-escuro, asas dobradas dos lados com as coberteiras
    claras no ombro e as pontas cruzando atrás da cauda, "calça" de penas,
    pés amarelos agarrando a ponta, nuca dourada, sobrancelha saliente (o
    olhar bravo) e o bico em gancho. Poses: parada, olha_esq / olha_dir
    (vira só a cabeça), grita (cabeça erguida, bico aberto), asas_meio
    (assentando / indo voar), asas_abertas (abre as asas como o falcão dos
    hieróglifos), olha_baixo."""
    S = SS
    cx = WP / 2.0
    nomes = ("cauda", "pontas", "corpo", "peito", "asa", "claro", "penas", "calca", "pe", "unha",
             "nuca", "cabeca", "bico", "ponta_bico", "boca", "olho", "brilho", "sobr")
    cam = {k: Image.new("L", (WP * S, HP * S), 0) for k in nomes}
    dr = {k: ImageDraw.Draw(v) for k, v in cam.items()}
    P = lambda pts: [((cx + x) * S, y * S) for x, y in pts]
    poly = lambda k, pts: dr[k].polygon(P(pts), fill=255)
    linha = lambda k, pts, w: dr[k].line(P(pts), fill=255, width=max(1, int(w * S)))

    def elipse(k, c, rx, ry):
        dr[k].ellipse([(cx + c[0] - rx) * S, (c[1] - ry) * S, (cx + c[0] + rx) * S, (c[1] + ry) * S], fill=255)

    espelho = lambda pts: [(-x, y) for x, y in pts]
    ombro = 3.0 if pose == "grita" else 0.0

    # cauda e as pontas das asas cruzando atrás dela
    poly("cauda", [(-8, 98), (8, 98), (13, 124), (0, 126), (-13, 124)])
    for i in range(5):
        linha("penas", [(-6 + 3 * i, 102), (-10 + 5 * i, 123)], 0.8)
    if pose not in ("asas_meio", "asas_abertas"):
        for lado in (-1, 1):
            poly("pontas", [(lado * 18, 96), (lado * 12, 100), (lado * 2, 121), (lado * 6, 122)])
    # corpo (ovo, largo nos ombros)
    corpo = [(-10, 34), (-17, 44), (-20, 58), (-18, 76), (-13, 92), (-6, 100), (6, 100), (13, 92), (18, 76),
             (20, 58), (17, 44), (10, 34)]
    poly("corpo", corpo)
    elipse("peito", (0, 64), 11, 22)
    # asas
    for lado in (-1, 1):
        if pose == "asas_meio":
            asa = [(lado * 14, 40), (lado * 26, 26), (lado * 38, 14), (lado * 48, 6), (lado * 52, 2), (lado * 52, 8),
                   (lado * 57, 6), (lado * 55, 13), (lado * 60, 13), (lado * 56, 19), (lado * 60, 22), (lado * 53, 25),
                   (lado * 46, 34), (lado * 36, 50), (lado * 26, 64), (lado * 18, 72), (lado * 14, 58)]
            poly("asa", asa)
            poly("claro", [(lado * 15, 42), (lado * 26, 28), (lado * 38, 16), (lado * 42, 24), (lado * 30, 38), (lado * 18, 52)])
            for i in range(6):
                k = i / 5.0
                linha("penas", [(lado * (22 + 12 * k), 64 - 28 * k), (lado * (40 + 14 * k), 40 - 28 * k)], 0.8)
        elif pose == "asas_abertas":
            # abertas e um pouco caídas (o falcão dos hieróglifos)
            asa = [(lado * 14, 40), (lado * 30, 32), (lado * 48, 28), (lado * 62, 30), (lado * 70, 32), (lado * 76, 36),
                   (lado * 72, 38), (lado * 77, 42), (lado * 72, 44), (lado * 76, 49), (lado * 70, 50), (lado * 73, 56),
                   (lado * 66, 56), (lado * 62, 62), (lado * 52, 66), (lado * 40, 70), (lado * 28, 72), (lado * 18, 70)]
            poly("asa", asa)
            poly("claro", [(lado * 15, 42), (lado * 32, 35), (lado * 50, 31), (lado * 58, 34), (lado * 52, 42),
                           (lado * 34, 46), (lado * 18, 50)])
            for i in range(9):
                xx = lado * (22 + 5.5 * i)
                linha("penas", [(xx, 50), (xx + lado * 1.5, 70 - i * 0.6)], 0.8)
        else:
            asa = [(lado * 12, 36 - ombro), (lado * 21, 40 - ombro), (lado * 26, 54), (lado * 26, 72), (lado * 21, 92),
                   (lado * 16, 104), (lado * 12, 100), (lado * 15, 86), (lado * 16, 62), (lado * 13, 46)]
            poly("asa", asa)
            poly("claro", [(lado * 13, 38 - ombro), (lado * 21, 41 - ombro), (lado * 25, 54), (lado * 21, 60), (lado * 15, 54)])
            for i in range(5):
                yy = 66 + 7 * i
                linha("penas", [(lado * 16, yy), (lado * 24.5 - lado * i * 0.9, yy + 6)], 0.8)
    # "calça" de penas e os pés agarrando a ponta
    for lado in (-1, 1):
        elipse("calca", (lado * 7.5, 95), 7.5, 10)
        linha("pe", [(lado * 6, 103), (lado * 6, 110)], 3.0)
        for dx, dy in ((-4, 7), (0, 8), (4, 7)):
            linha("pe", [(lado * 6, 109), (lado * 6 + dx, 109 + dy)], 2.0)
            elipse("unha", (lado * 6 + dx * 1.12, 109 + dy * 1.1), 0.9, 0.9)
    # pescoço, cabeça, nuca dourada
    cab_y = {"grita": 19.0, "olha_baixo": 26.0}.get(pose, 23.0)
    cab_x = {"olha_esq": -1.5, "olha_dir": 1.5}.get(pose, 0.0)
    poly("corpo", [(-10, 38), (-9, cab_y + 4), (9, cab_y + 4), (10, 38)])
    elipse("cabeca", (cab_x, cab_y), 10.5, 9.5)
    elipse("nuca", (cab_x, cab_y - 3), 11, 9)
    elipse("nuca", (0, cab_y + 10), 12, 6)                   # a gola dourada do pescoço
    if pose in ("olha_esq", "olha_dir"):
        lado = -1 if pose == "olha_esq" else 1
        bico = [(1, cab_y - 1), (7, cab_y - 1.5), (11, cab_y + 0.5), (13.5, cab_y + 3.5), (12.5, cab_y + 6),
                (11, cab_y + 4), (8, cab_y + 4.5), (1, cab_y + 5)]
        bico = [(cab_x + lado * x, y) for x, y in bico]
        poly("bico", bico)
        poly("ponta_bico", [(cab_x + lado * x, y) for x, y in [(10.5, cab_y), (13.5, cab_y + 3.5), (12.5, cab_y + 6), (11, cab_y + 3.5)]])
        ox = cab_x + lado * 1.5
        elipse("olho", (ox, cab_y - 1.5), 1.7, 1.7)
        elipse("brilho", (ox + lado * 0.6, cab_y - 2.1), 0.6, 0.6)
        linha("sobr", [(cab_x - lado * 2.5, cab_y - 4.0), (cab_x + lado * 4.5, cab_y - 3.4)], 1.1)
        # o outro olho escondido do outro lado; a nuca aparece mais
        elipse("nuca", (cab_x - lado * 5, cab_y), 6, 8)
    else:
        baixo = 2.0 if pose == "olha_baixo" else 0.0
        if pose == "grita":
            poly("bico", [(-3.2, cab_y + 2), (3.2, cab_y + 2), (2.2, cab_y - 5), (0, cab_y - 7), (-2.2, cab_y - 5)])
            poly("bico", [(-3.0, cab_y + 5.5), (3.0, cab_y + 5.5), (1.8, cab_y + 11), (-1.8, cab_y + 11)])
            poly("boca", [(-2.6, cab_y + 2), (2.6, cab_y + 2), (2.6, cab_y + 6.5), (-2.6, cab_y + 6.5)])
            poly("ponta_bico", [(-1.4, cab_y - 5.5), (0, cab_y - 7), (1.4, cab_y - 5.5)])
            olho_y = cab_y - 1.0
        else:
            poly("bico", [(-3.6, cab_y + 1 + baixo), (3.6, cab_y + 1 + baixo), (3.0, cab_y + 8 + baixo),
                          (1.6, cab_y + 12 + baixo), (0, cab_y + 13.5 + baixo), (-1.6, cab_y + 12 + baixo), (-3.0, cab_y + 8 + baixo)])
            poly("ponta_bico", [(-2.4, cab_y + 9 + baixo), (2.4, cab_y + 9 + baixo), (1.6, cab_y + 12 + baixo),
                                (0, cab_y + 13.5 + baixo), (-1.6, cab_y + 12 + baixo)])
            olho_y = cab_y + 0.5 + baixo * 0.5
        for lado in (-1, 1):
            elipse("olho", (lado * 5.6, olho_y), 1.7, 1.6)
            elipse("brilho", (lado * 5.6 - 0.5, olho_y - 0.6), 0.55, 0.55)
            # sobrancelha saliente, descendo para o bico (o olhar bravo)
            linha("sobr", [(lado * 9.0, olho_y - 3.2), (lado * 2.6, olho_y - 1.6)], 1.2)

    def m(k, r=0.0):
        im = cam[k].resize((WP, HP), Image.LANCZOS)
        if r:
            im = im.filter(ImageFilter.GaussianBlur(r))
        return np.asarray(im).astype(np.float32)[..., None] / 255
    yy, xx = np.mgrid[0:HP, 0:WP].astype(np.float32)
    base = np.array([0.30, 0.20, 0.13])
    cor = np.zeros((HP, WP, 3), np.float32)
    alfa = np.zeros((HP, WP, 1), np.float32)

    def por(c, a):
        nonlocal cor, alfa
        cor = cor * (1 - a) + np.asarray(c, np.float32) * a
        alfa = alfa + a * (1 - alfa)
    por(base * 0.8, m("cauda"))
    por(base * 0.7, m("pontas"))
    a_corpo = m("corpo")
    por(base, a_corpo)
    pe = m("peito", 3.0) * a_corpo
    cor = cor * (1 - 0.30 * pe) + np.array([0.44, 0.31, 0.20]) * (0.30 * pe)
    por(np.array([0.48, 0.36, 0.24]), m("calca", 0.6))
    a_asa = m("asa")
    por(base * 0.84, a_asa)
    cl = m("claro", 0.9) * a_asa
    cor = cor * (1 - 0.38 * cl) + np.array([0.62, 0.48, 0.32]) * (0.38 * cl)
    por(base * 1.05, m("cabeca"))
    nu = m("nuca", 2.0) * alfa
    cor = cor * (1 - 0.75 * nu) + np.array([0.74, 0.54, 0.24]) * (0.75 * nu)
    cor = cor * (1 - 0.25 * m("penas") * alfa)
    por(np.array([0.88, 0.72, 0.26]), m("pe"))
    por(np.array([0.12, 0.10, 0.09]), m("unha"))
    por(np.array([0.88, 0.74, 0.32]), m("bico"))
    por(np.array([0.24, 0.21, 0.20]), m("ponta_bico"))
    por(np.array([0.38, 0.08, 0.06]), m("boca"))
    sb = m("sobr") * alfa
    cor = cor * (1 - 0.55 * sb)
    por(np.array([0.32, 0.18, 0.04]), m("olho"))
    cor = cor + 0.6 * m("brilho")
    # luz do céu de cima; embaixo mais escuro
    cor = cor * (1.06 - 0.24 * np.clip((yy - 30) / 90, 0, 1))[..., None]
    mask = alfa[..., 0]
    borda = np.clip(mask - ndi.grey_erosion(mask, size=(3, 3)), 0, 1)[..., None]
    cor = cor + np.array([0.55, 0.45, 0.30]) * (0.5 * borda)
    return np.dstack([np.clip(cor, 0, 1), mask])


def pousada():
    arr = np.concatenate([quadro_pousada(p) for p in POSES], axis=1)
    Image.fromarray((arr * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(SP, "egito_aguia_pousada.png"), optimize=True)
    print("egito_aguia_pousada.png  %dx%d (%d quadros)" % (arr.shape[1], arr.shape[0], len(POSES)))


# ───────────────────────────────────────────── som
TAXA = 32000


def gravar_wav(sinal, nome, pico=0.8):
    s = sinal / (np.abs(sinal).max() + 1e-9) * pico
    with wave.open(os.path.join(SONGS, nome), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(TAXA)
        f.writeframes((s * 32767).astype(np.int16).tobytes())
    print("%-18s %.2f s" % (nome, len(s) / TAXA))


def filtro(x, tipo, fc, ordem=4):
    sos = butter(ordem, fc, btype=tipo, fs=TAXA, output="sos")
    return sosfilt(sos, x)


def grito(f0=1.0, dur=1.5):
    n = int(dur * TAXA)
    t = np.arange(n) / TAXA
    # "kii" curto que sobe e o "iiii-arrr" longo que desce
    sobe = np.clip(t / 0.09, 0, 1)
    f = (2500 + 700 * sobe) * np.exp(-np.clip(t - 0.09, 0, None) * 0.42)
    f = f * (1 + 0.012 * np.sin(2 * np.pi * 34 * t) + 0.006 * rng.standard_normal(n).cumsum() / np.sqrt(n) * 30)
    f = f * f0
    fase = 2 * np.pi * np.cumsum(f) / TAXA
    som = np.sin(fase) + 0.55 * np.sin(2 * fase + 0.3) + 0.30 * np.sin(3 * fase + 1.1) + 0.12 * np.sin(4 * fase)
    # aspereza: modulação rápida e ruído preso no tom
    rasp = 1 + 0.45 * filtro(rng.standard_normal(n), "lowpass", 260)
    som = som * rasp
    ruido = filtro(rng.standard_normal(n), "bandpass", [1800 * f0, 4200 * f0], 2) * 0.35
    som = som + ruido * (0.6 + 0.4 * np.sin(fase * 0.5))
    env = np.clip(t / 0.03, 0, 1) * np.clip((dur - t) / 0.35, 0, 1) * (0.75 + 0.25 * np.exp(-t * 2.0))
    # pequena falha no meio (a voz quebra)
    env = env * (1 - 0.35 * np.exp(-((t - 0.55) / 0.04) ** 2))
    return som * env


def eco(x, atrasos, ganhos, cauda, molhado):
    n = int(cauda * TAXA)
    y = np.concatenate([x, np.zeros(n)])
    for a, g in zip(atrasos, ganhos):
        k = int(a * TAXA)
        y[k:k + len(x)] += filtro(x, "lowpass", 3000) * g
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (cauda * 0.35 * TAXA))
    ir = filtro(ir, "lowpass", 2800)
    ir /= np.sqrt((ir ** 2).sum())
    rev = np.zeros(len(y))
    c = fftconvolve(x, ir)[:len(y)]
    rev[:len(c)] = c
    return y + rev * molhado


def sons():
    dia = grito(1.0, 1.45)
    dia = filtro(dia, "lowpass", 7000)
    dia = filtro(dia, "highpass", 500, 2)
    dia = eco(dia, [0.21, 0.47], [0.35, 0.16], 1.6, 0.5)
    gravar_wav(dia, "aguia.wav", 0.75)
    noite = grito(0.9, 1.6)
    noite = filtro(noite, "lowpass", 3600)
    noite = filtro(noite, "highpass", 400, 2)
    noite = eco(noite, [0.26, 0.58, 0.95], [0.45, 0.28, 0.14], 2.4, 0.9)
    gravar_wav(noite, "aguia_noite.wav", 0.7)


if __name__ == "__main__":
    if sys.argv[1:] == ["pousada"]:
        pousada()
    else:
        folha()
        pousada()
        sons()
