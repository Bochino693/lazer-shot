#!/usr/bin/env python3
"""Águias do céu do Egito (scripts/deserto_vivo.gd).

  sprites/egito_aguia.png   11 quadros de 256x160 lado a lado: 0 = planando,
                            1..10 = um ciclo de batida de asa. Águia-real
                            vista de baixo, cabeça para cima: asas largas com
                            as penas da ponta abertas ("dedos"), cauda em
                            leque, barriga escura, faixa clara nas asas, borda
                            clara onde a luz atravessa as penas
  sprites/egito_aguia_pousada.png
                            4 quadros de 128x128: a mesma águia pousada de
                            frente (na ponta de uma pirâmide apagada), na
                            mesma escala da que voa: 0 = parada, asas
                            fechadas; 1 = cabeça virada; 2 = gritando (cabeça
                            para cima, bico aberto, ombros soltos); 3 = asas
                            meio abertas para cima (assentando)
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
WP = 128


def quadro_pousada(pose):
    """pose: 0 parada, 1 cabeça virada, 2 gritando, 3 asas meio abertas."""
    S = SS
    m = Image.new("L", (WP * S, WP * S), 0)
    d = ImageDraw.Draw(m)
    cx = WP / 2
    P = lambda p: ((cx + p[0]) * S, p[1] * S)
    asas = Image.new("L", (WP * S, WP * S), 0)        # asas fechadas (mais escuras)
    da = ImageDraw.Draw(asas)
    penas = Image.new("L", (WP * S, WP * S), 0)
    dp = ImageDraw.Draw(penas)
    peito = Image.new("L", (WP * S, WP * S), 0)
    dpe = ImageDraw.Draw(peito)
    pes = Image.new("L", (WP * S, WP * S), 0)
    dpes = ImageDraw.Draw(pes)
    bico = Image.new("L", (WP * S, WP * S), 0)
    db = ImageDraw.Draw(bico)
    boca = Image.new("L", (WP * S, WP * S), 0)
    dbo = ImageDraw.Draw(boca)
    olho = Image.new("L", (WP * S, WP * S), 0)
    do = ImageDraw.Draw(olho)
    ombro = 4.0 if pose == 2 else 0.0
    cy_cab = 24.0 if pose == 2 else 30.0
    vira = 5.0 if pose == 1 else 0.0
    # cauda (atrás dos pés)
    d.polygon([P((-9, 92)), P((9, 92)), P((13, 122)), P((0, 125)), P((-13, 122))], fill=255)
    for i in range(5):
        xx = -10 + 5 * i
        dp.line([P((xx * 0.6, 96)), P((xx, 122))], fill=255, width=S)
    # corpo
    d.ellipse([P((-18, 40)), P((18, 102))], fill=255)
    dpe.ellipse([P((-11, 50)), P((11, 96))], fill=255)
    # asas fechadas dos lados
    for lado in (-1, 1):
        if pose == 3:
            # meio abertas, para cima e para fora (assentando / pronta para voar)
            # (a ponta com as penas abertas, os "dedos")
            asa = [(lado * 14, 46), (lado * 34, 22), (lado * 50, 4), (lado * 55, 0), (lado * 56, 8), (lado * 61, 6),
                   (lado * 59, 15), (lado * 63, 15), (lado * 57, 23), (lado * 60, 27), (lado * 52, 31),
                   (lado * 48, 40), (lado * 40, 60), (lado * 26, 80), (lado * 16, 84)]
        else:
            o = ombro
            asa = [(lado * 12, 44 - o), (lado * (22 + o), 48 - o * 0.5), (lado * (25 + o * 0.6), 66), (lado * 22, 90),
                   (lado * 15, 112), (lado * 9, 116), (lado * 8, 96), (lado * 10, 60)]
        d.polygon([P(q) for q in asa], fill=255)
        da.polygon([P(q) for q in asa], fill=255)
        for i in range(6):
            yy = 60 + 9 * i
            dp.line([P((lado * 10, yy)), P((lado * 22, yy + 7))], fill=255, width=S)
    # pernas com "calça" de penas e os dedos amarelos agarrando a pedra
    for lado in (-1, 1):
        d.ellipse([P((lado * 9 - 6, 92)), P((lado * 9 + 6, 110))], fill=255)
        for k in (-1, 0, 1):
            dpes.line([P((lado * 9, 108)), P((lado * 9 + k * 5, 117))], fill=255, width=int(2.6 * S))
    # cabeça, olhos e bico
    hx = vira
    d.ellipse([P((hx - 11, cy_cab - 11)), P((hx + 11, cy_cab + 11))], fill=255)
    d.polygon([P((-9, cy_cab + 4)), P((9, cy_cab + 4)), P((14, 46)), P((-14, 46))], fill=255)   # pescoço
    if pose == 1:
        # de lado: bico para a direita
        db.polygon([P((hx + 7, cy_cab - 2)), P((hx + 17, cy_cab)), P((hx + 19, cy_cab + 4)),
                    P((hx + 15, cy_cab + 3)), P((hx + 7, cy_cab + 4))], fill=255)
        do.ellipse([P((hx + 2, cy_cab - 4)), P((hx + 6, cy_cab))], fill=255)
    elif pose == 2:
        # para cima, gritando: bico aberto (as duas metades e a boca escura)
        db.polygon([P((-4, cy_cab + 2)), P((4, cy_cab + 2)), P((1, cy_cab - 12)), P((-1, cy_cab - 12))], fill=255)
        db.polygon([P((-3, cy_cab + 4)), P((3, cy_cab + 4)), P((4, cy_cab + 12)), P((-4, cy_cab + 12))], fill=255)
        dbo.polygon([P((-3, cy_cab + 2)), P((3, cy_cab + 2)), P((3, cy_cab + 9)), P((-3, cy_cab + 9))], fill=255)
        for lado in (-1, 1):
            do.ellipse([P((lado * 6 - 2, cy_cab - 3)), P((lado * 6 + 2, cy_cab + 1))], fill=255)
    else:
        db.polygon([P((-4, cy_cab + 1)), P((4, cy_cab + 1)), P((2, cy_cab + 11)), P((0, cy_cab + 13)), P((-2, cy_cab + 11))], fill=255)
        for lado in (-1, 1):
            do.ellipse([P((lado * 6 - 2, cy_cab - 3)), P((lado * 6 + 2, cy_cab + 1))], fill=255)
    d.bitmap((0, 0), bico, fill=255)

    reduz = lambda im, r=0.0: (np.asarray((im.resize((WP, WP), Image.LANCZOS)).filter(ImageFilter.GaussianBlur(r)) if r else
                                          im.resize((WP, WP), Image.LANCZOS)).astype(np.float32) / 255)
    mask = reduz(m)
    a_asas = reduz(asas)
    pn = reduz(penas)
    pe = reduz(peito, 2.0)
    ps = reduz(pes)
    bc = reduz(bico)
    bo = reduz(boca)
    ol = reduz(olho)
    yy, xx = np.mgrid[0:WP, 0:WP].astype(np.float32)
    cor = np.ones((WP, WP, 3), np.float32) * np.array([0.30, 0.20, 0.13])
    # peito um pouco mais claro, com as riscas
    cor = cor * (1 - 0.3 * pe[..., None]) + np.array([0.46, 0.33, 0.21]) * (0.3 * pe[..., None])
    # asas fechadas mais escuras
    cor = cor * (1 - 0.25 * a_asas[..., None])
    cor = cor * (1 - 0.28 * pn[..., None])
    # nuca dourada
    cab = np.exp(-(((xx - cx - vira) / 12) ** 2 + ((yy - cy_cab) / 13) ** 2))
    cor = cor * (1 - 0.7 * cab[..., None]) + np.array([0.74, 0.54, 0.24]) * (0.7 * cab[..., None])
    # luz de cima (o céu), base mais escura
    cor = cor * (1.08 - 0.30 * np.clip((yy - 30) / 90, 0, 1))[..., None]
    cor = cor * (1 - ps[..., None]) + np.array([0.90, 0.74, 0.26]) * ps[..., None]
    ponta_bico = np.clip((np.abs(yy - cy_cab) - 6) / 6, 0, 1) if pose != 1 else np.clip((xx - cx - vira - 13) / 6, 0, 1)
    cor_bico = np.array([0.90, 0.76, 0.32]) * (1 - ponta_bico[..., None]) + np.array([0.22, 0.20, 0.20]) * ponta_bico[..., None]
    cor = cor * (1 - bc[..., None]) + cor_bico * bc[..., None]
    cor = cor * (1 - bo[..., None]) + np.array([0.35, 0.08, 0.06]) * bo[..., None]
    cor = cor * (1 - ol[..., None]) + np.array([0.10, 0.06, 0.03]) * ol[..., None]
    # brilho no olho
    for lado in ((-1, 1) if pose != 1 else (1,)):
        ex = cx + (lado * 6 - 0.8 if pose != 1 else vira + 3.2)
        brilho = np.exp(-(((xx - ex) / 0.9) ** 2 + ((yy - (cy_cab - 2.6)) / 0.9) ** 2))
        cor = cor + 0.6 * brilho[..., None]
    borda = np.clip(mask - ndi.grey_erosion(mask, size=(3, 3)), 0, 1)
    cor = cor + np.array([0.55, 0.45, 0.30]) * (0.45 * borda[..., None])
    return np.dstack([np.clip(cor, 0, 1), mask])


def pousada():
    arr = np.concatenate([quadro_pousada(p) for p in range(4)], axis=1)
    Image.fromarray((arr * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(SP, "egito_aguia_pousada.png"), optimize=True)
    print("egito_aguia_pousada.png  %dx%d (4 quadros)" % (arr.shape[1], arr.shape[0]))


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
