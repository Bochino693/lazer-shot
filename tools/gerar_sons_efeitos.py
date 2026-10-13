#!/usr/bin/env python3
"""Sons dos efeitos da Rodada 11 (44,1 kHz, mono), por síntese física
simplificada: ressonâncias (modos) de vidro, metal e madeira, estalos que
correm, cacos que caem e quicam com a gravidade, chiado de vapor, arco
elétrico e bolhas (frequência de Minnaert subindo).

Egito
  cristal_trinca.wav   tiro no cristal: estalo seco, a rachadura correndo
                       (estalinhos acelerando), o cristal soando e uns
                       caquinhos caindo; zumbido de energia vazando
  cristal_quebra.wav   o cristal estoura: pancada, estilhaço, o cristal
                       ressoando, chuva de cacos quicando no pedestal e a
                       energia desligando
  cristal_volta.wav    o cristal se refaz: brilho que cresce e fecha num sino
  ouro_ping.wav        bala no ouro: "tim" metálico e o ricochete
  areia_tiro.wav       bala na areia: baque abafado e areia espirrando
  raio_sol.wav         raio de sol: sopro quente com brilho
  raio_lua.wav         raio de luar: brilho frio e cristalino
Arena
  laser_parede.wav     laser no aço: chiado de queima e o metal soando
  arena_vapor.wav      baforada de vapor do cano
  arena_faisca.wav     faíscas da caixa elétrica (arco estalando)
  arena_troca.wav      troca de rodada: relé, máquina ligando e alarme
  lanterna_sobe.wav    lanterna subindo no furo: motor e trava
  lanterna_desce.wav   lanterna descendo: destrava e motor
Mar
  bolhas_tiro.wav      bala na água: baque abafado e rastro de bolhas
Bar
  madeira_tiro.wav     bala na madeira: estalo, a tábua soando e farpas
  papel_tiro.wav       bala no cartaz: papel rasgando e a madeira atrás

    python3 tools/gerar_sons_efeitos.py
"""
import os
import wave
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SONGS = os.path.join(RAIZ, "songs")
TAXA = 44100
rng = np.random.default_rng(1103)


# ───────────────────────────────────────────── utilidades
def gravar(sinal, nome, pico=0.8):
    s = sinal / (np.abs(sinal).max() + 1e-9) * pico
    s = s * np.minimum(1.0, np.arange(len(s))[::-1] / (0.008 * TAXA))
    with wave.open(os.path.join(SONGS, nome), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(TAXA)
        f.writeframes((s * 32767).astype(np.int16).tobytes())
    print("%-20s %.2f s" % (nome, len(s) / TAXA))


def t_(dur):
    return np.arange(int(dur * TAXA)) / TAXA


def vazio(dur):
    return np.zeros(int(dur * TAXA))


def filtro(x, tipo, fc, ordem=4):
    return sosfilt(butter(ordem, fc, btype=tipo, fs=TAXA, output="sos"), x)


def ruido(dur):
    return rng.standard_normal(int(dur * TAXA))


def som(*partes):
    """Soma sinais de tamanhos diferentes (completa com silêncio)."""
    n = max(len(x) for x in partes)
    out = np.zeros(n)
    for x in partes:
        out[:len(x)] += x
    return out


def colar(dest, src, ini, ganho=1.0):
    i = int(ini * TAXA)
    if i >= len(dest):
        return
    n = min(len(src), len(dest) - i)
    dest[i:i + n] += src[:n] * ganho


def modos(dur, freqs, amps, decais, desafina=0.0):
    """Ressonâncias: senos que somem cada um no seu tempo (com batimento)."""
    t = t_(dur)
    s = np.zeros_like(t)
    for f, a, d in zip(freqs, amps, decais):
        fase = rng.uniform(0, 2 * np.pi)
        s += a * np.sin(2 * np.pi * f * t + fase) * np.exp(-t * d)
        if desafina > 0:
            s += a * 0.5 * np.sin(2 * np.pi * f * (1 + desafina) * t + fase) * np.exp(-t * d * 1.2)
    return s


def estalo(dur=0.004, fc=2500):
    """Clique seco (ruído curtíssimo, só agudo)."""
    return filtro(ruido(dur), "highpass", fc, 2) * np.exp(-t_(dur) * (3.0 / dur))


def baque(dur=0.08, fc=400, d=40):
    """Pancada abafada (ruído grave)."""
    return filtro(ruido(dur), "lowpass", fc, 2) * np.exp(-t_(dur) * d)


def ressonancia_curta(f, q_decai, dur=0.06):
    return np.sin(2 * np.pi * f * t_(dur)) * np.exp(-t_(dur) * q_decai)


def sala(x, cauda=0.5, mistura=0.2, fc=6000):
    """Reverberação curta (ar livre / sala), por convolução com ruído."""
    n = int(cauda * TAXA)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (cauda * 0.25 * TAXA))
    ir = filtro(ir, "lowpass", fc, 2)
    ir /= np.sqrt((ir ** 2).sum())
    r = fftconvolve(x, ir)
    y = np.zeros(len(r))
    y[:len(x)] = x
    return y + r * mistura


def caquinho(f_base, tam=1.0):
    """Um caco de vidro tocando o chão: 3 modos agudos curtos + clique."""
    fs = [f_base, f_base * rng.uniform(2.2, 2.5), f_base * rng.uniform(3.9, 4.6)]
    s = modos(0.12, fs, [1.0, 0.5, 0.3], [60 / tam, 90 / tam, 130 / tam])
    colar(s, estalo(0.002, 4000), 0.0, 0.6)
    return s


def quicar(dest, ini, queda, f, amp, tam=1.0, quiques=3):
    """Caco caindo de uma altura (tempo de queda) e quicando: cada quique
    vem mais cedo e mais fraco (coeficiente de restituição ~0,5)."""
    t = ini + queda
    intervalo = queda * 0.9
    for k in range(quiques):
        if t >= len(dest) / TAXA - 0.05:
            break
        colar(dest, caquinho(f * rng.uniform(0.97, 1.03), tam), t, amp)
        amp *= 0.42
        intervalo *= 0.55
        t += intervalo


def zumbido(dur, f0, f1, d=2.4):
    t = t_(dur)
    f = f1 + (f0 - f1) * np.exp(-t * d)
    fase = 2 * np.pi * np.cumsum(f) / TAXA
    s = np.sin(fase) + 0.45 * np.sin(2 * fase) + 0.25 * np.sin(3 * fase) + 0.12 * np.sin(5 * fase)
    return s * (1 + 0.4 * np.sin(2 * np.pi * 27 * t))


# ───────────────────────────────────────────── Egito
MODOS_CRISTAL = [1180, 1935, 2870, 3990, 5215, 6830, 8420]


def cristal_trinca():
    s = vazio(1.0)
    colar(s, estalo(0.003, 3000), 0.0, 1.6)
    colar(s, baque(0.03, 1200, 90), 0.0, 0.5)
    # a rachadura correndo: estalinhos cada vez mais juntos, cada um num tom
    t = 0.004
    for i in range(16):
        c = som(estalo(0.0015, 3500), ressonancia_curta(rng.uniform(3500, 9000), 400, 0.02) * 0.4)
        colar(s, c, t, 0.7 * (1 - i / 20))
        t += 0.012 * (0.82 ** i) + 0.0015
    # o cristal soa (mais baixo que no estouro)
    colar(s, modos(0.9, [f * rng.uniform(0.99, 1.01) for f in MODOS_CRISTAL],
                   rng.uniform(0.2, 0.6, 7), [5, 6, 8, 10, 13, 16, 20], 0.0015), 0.003, 0.32)
    # uns caquinhos caindo no pedestal
    for i in range(5):
        quicar(s, rng.uniform(0.0, 0.03), rng.uniform(0.18, 0.32), rng.uniform(4200, 8800), rng.uniform(0.15, 0.3), 0.6, 2)
    # energia vazando (zap elétrico curto)
    zap = zumbido(0.25, 260, 160, 6) * np.exp(-t_(0.25) * 12)
    zap = som(zap, filtro(ruido(0.25), "bandpass", [2000, 6000], 2) * np.exp(-t_(0.25) * 20) * 0.6)
    colar(s, zap, 0.01, 0.18)
    return sala(s, 0.45, 0.18)


def cristal_quebra():
    s = vazio(2.6)
    # pancada + estalo seco
    colar(s, estalo(0.004, 2500), 0.0, 2.0)
    colar(s, baque(0.09, 500, 30), 0.0, 1.2)
    # rachadura correndo no corpo inteiro (bem rápido)
    t = 0.002
    for i in range(30):
        colar(s, som(estalo(0.0012, 3000), ressonancia_curta(rng.uniform(3000, 10000), 500, 0.015) * 0.5), t, 0.9 * (1 - i / 40))
        t += 0.006 * (0.88 ** i) + 0.0008
    # o estilhaço: ruído largo agudo + médio, que some rápido
    est = filtro(ruido(0.35), "bandpass", [2000, 12000], 2) * np.exp(-t_(0.35) * 16)
    est += filtro(ruido(0.35), "bandpass", [500, 2000], 2) * np.exp(-t_(0.35) * 28) * 0.7
    # granulado do vidro partindo (o estilhaço "chia" em grãos)
    est *= 0.6 + 0.4 * (rng.random(len(est)) > 0.55)
    colar(s, est, 0.008, 1.1)
    # o cristal inteiro ressoando antes de virar caco
    colar(s, modos(1.6, [f * rng.uniform(0.985, 1.015) for f in MODOS_CRISTAL],
                   rng.uniform(0.4, 1.0, 7), [2.6, 3.2, 4.4, 5.6, 7.0, 9.0, 11.0], 0.002), 0.004, 0.5)
    # chuva de cacos: grandes (mais graves, poucos), médios e miúdos (muitos);
    # os de cima demoram mais para chegar no chão
    for i in range(14):
        quicar(s, rng.uniform(0.0, 0.05), rng.uniform(0.28, 0.55), rng.uniform(1600, 3200), rng.uniform(0.35, 0.6), 1.6, 3)
    for i in range(45):
        quicar(s, rng.uniform(0.0, 0.08), rng.uniform(0.18, 0.62), rng.uniform(3000, 6500), rng.uniform(0.15, 0.4), 1.0, 3)
    for i in range(70):
        quicar(s, rng.uniform(0.0, 0.1), rng.uniform(0.15, 0.8), rng.uniform(6000, 11000), rng.uniform(0.06, 0.2), 0.6, 2)
    # a energia desligando
    z = zumbido(1.5, 560, 45, 2.0) * np.exp(-t_(1.5) * 2.0) * np.clip(t_(1.5) / 0.03, 0, 1)
    colar(s, z, 0.05, 0.3)
    return sala(s, 0.7, 0.22)


def cristal_volta():
    dur = 2.1
    s = vazio(dur)
    t = t_(dur)
    # brilho crescendo: caquinhos "ao contrário" cada vez mais juntos
    n = 60
    for i in range(n):
        k = (i / n) ** 0.6
        ini = 0.05 + k * 1.45 + rng.uniform(-0.03, 0.03)
        colar(s, som(caquinho(rng.uniform(4000, 10000), 0.7)[::-1][-int(0.05 * TAXA):] * 0.6, caquinho(rng.uniform(4000, 10000), 0.5) * 0.3), ini, 0.1 + 0.25 * k)
    # acorde que sobe
    env = np.clip(t / 1.4, 0, 1) ** 2 * np.clip((dur - t) / 0.3, 0, 1)
    for k, base in enumerate((392.0, 494.0, 587.0, 784.0)):
        f = base * (1 + 0.5 * np.clip(t / 1.5, 0, 1))
        fase = 2 * np.pi * np.cumsum(f) / TAXA
        s += np.sin(fase + k) * 0.08 * env * (1 + 0.25 * np.sin(2 * np.pi * (4 + k) * t))
    # fecha num sino de cristal
    colar(s, modos(0.6, [f * 1.2 for f in MODOS_CRISTAL[:5]], [1, 0.7, 0.5, 0.35, 0.2], [5, 7, 9, 12, 15], 0.002), 1.5, 0.4)
    return sala(s, 0.6, 0.25)


def ouro_ping():
    s = vazio(0.9)
    colar(s, estalo(0.002, 3500), 0.0, 1.0)
    colar(s, modos(0.8, [2140, 3310, 5350, 7980], [1.0, 0.6, 0.45, 0.25], [7, 10, 15, 22], 0.003), 0.0, 0.7)
    # ricochete: a bala sai assobiando e caindo de tom, se afastando
    t = t_(0.45)
    f = 3600 * np.exp(-t * 2.4) + 900
    fase = 2 * np.pi * np.cumsum(f) / TAXA
    ric = np.sin(fase) * np.clip(t / 0.02, 0, 1) * np.exp(-t * 6)
    ric += filtro(ruido(0.45), "bandpass", [2000, 6000], 2) * np.exp(-t * 9) * 0.25
    colar(s, ric, 0.03, 0.35)
    return sala(s, 0.5, 0.2)


def areia_tiro():
    s = vazio(0.7)
    colar(s, baque(0.08, 280, 35), 0.0, 1.0)
    jato = filtro(ruido(0.4), "bandpass", [1500, 6500], 2) * np.exp(-t_(0.4) * 9) * np.clip(t_(0.4) / 0.008, 0, 1)
    jato *= 0.55 + 0.45 * (rng.random(len(jato)) > 0.6)
    colar(s, jato, 0.004, 0.55)
    for i in range(18):
        colar(s, estalo(0.001, 5000), rng.uniform(0.08, 0.5), rng.uniform(0.05, 0.15))
    return sala(s, 0.4, 0.12)


def raio_sol():
    s = vazio(0.6)
    t = t_(0.4)
    sopro = ruido(0.4)
    # sopro quente que abre (passa-baixa subindo) e some
    a = filtro(sopro, "lowpass", 1200, 2) * 0.6 + filtro(sopro, "bandpass", [1200, 4500], 2) * np.clip(t / 0.15, 0, 1) * 0.6
    a *= np.clip(t / 0.015, 0, 1) * np.exp(-t * 7)
    colar(s, a, 0.0, 0.8)
    for i in range(4):
        colar(s, modos(0.3, [rng.uniform(3500, 6000)], [1.0], [18]), rng.uniform(0.02, 0.18), 0.12)
    return sala(s, 0.4, 0.15)


def raio_lua():
    s = vazio(0.7)
    t = t_(0.6)
    brilho = sum(np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * a for f, a in ((3520, 1.0), (5270, 0.6), (7040, 0.4)))
    brilho *= np.clip(t / 0.03, 0, 1) * np.exp(-t * 6) * (1 + 0.2 * np.sin(2 * np.pi * 9 * t))
    ar = filtro(ruido(0.6), "highpass", 4000, 2) * np.clip(t / 0.02, 0, 1) * np.exp(-t * 10) * 0.4
    colar(s, brilho * 0.5 + ar, 0.0)
    return sala(s, 0.6, 0.25)


# ───────────────────────────────────────────── Arena
def laser_parede():
    s = vazio(0.7)
    t = t_(0.06)
    f = 1500 * np.exp(-t * 30) + 300
    zap = np.sin(2 * np.pi * np.cumsum(f) / TAXA) * np.exp(-t * 40)
    colar(s, zap, 0.0, 0.6)
    queima = filtro(ruido(0.35), "bandpass", [3000, 11000], 2) * np.exp(-t_(0.35) * 9)
    queima *= 0.5 + 0.5 * (rng.random(len(queima)) > 0.7)
    colar(s, queima, 0.005, 0.5)
    colar(s, modos(0.6, [870, 2390, 4120, 6010], [1.0, 0.6, 0.35, 0.2], [9, 14, 20, 28], 0.004), 0.0, 0.35)
    return sala(s, 0.5, 0.25, 5000)


def arena_vapor():
    dur = 1.5
    t = t_(dur)
    s = filtro(ruido(dur), "bandpass", [1500, 9000], 2)
    env = np.clip(t / 0.05, 0, 1) * np.clip((dur - t) / 0.7, 0, 1)
    pressao = 1 + 0.12 * np.sin(2 * np.pi * 13 * t) + 0.08 * filtro(ruido(dur), "lowpass", 20, 2) * 6
    s *= env * pressao
    colar(s, filtro(ruido(0.08), "highpass", 5000, 2) * np.exp(-t_(0.08) * 30), 0.0, 1.5)   # "psst" da válvula
    return sala(s, 0.6, 0.3, 5000)


def arena_faisca():
    dur = 0.8
    s = vazio(dur)
    t = t_(dur)
    # zumbido do arco (60 Hz e harmônicos, ligando e desligando)
    serra = sum(np.sin(2 * np.pi * 60 * k * t) / k for k in range(1, 12))
    porta = (filtro(rng.random(len(t)), "lowpass", 30, 2) > 0.5).astype(float)
    s += filtro(serra, "highpass", 150, 2) * porta * 0.2 * np.exp(-t * 2)
    # estalos do arco (muitos no começo)
    tt = 0.0
    while tt < dur - 0.02:
        colar(s, som(estalo(0.0015, 2000), ressonancia_curta(rng.uniform(2000, 7000), 300, 0.01) * 0.5), tt, rng.uniform(0.2, 1.0) * np.exp(-tt * 3))
        tt += rng.exponential(0.012 + tt * 0.04)
    return sala(s, 0.4, 0.2)


def arena_troca():
    dur = 1.7
    s = vazio(dur)
    # relé grande batendo
    colar(s, som(baque(0.06, 700, 50), estalo(0.003, 1500) * 0.6), 0.0, 1.0)
    colar(s, modos(0.3, [190, 430, 780], [1.0, 0.6, 0.3], [25, 35, 50]), 0.0, 0.5)
    # máquina ligando: serra filtrada subindo
    t = t_(0.9)
    f = 70 + 260 * (t / 0.9) ** 1.5
    fase = 2 * np.pi * np.cumsum(f) / TAXA
    serra = sum(np.sin(k * fase) / k for k in range(1, 10))
    lig = filtro(serra, "lowpass", 2500, 2) * np.clip(t / 0.1, 0, 1) * np.clip((0.9 - t) / 0.2, 0, 1)
    colar(s, lig, 0.05, 0.35)
    # dois alarmes "uíp"
    for k in range(2):
        tt = t_(0.28)
        ff = 650 + 500 * (tt / 0.28)
        w = np.sin(2 * np.pi * np.cumsum(ff) / TAXA) + 0.3 * np.sin(4 * np.pi * np.cumsum(ff) / TAXA)
        colar(s, w * np.clip(tt / 0.02, 0, 1) * np.clip((0.28 - tt) / 0.05, 0, 1), 0.75 + k * 0.36, 0.3)
    return sala(s, 0.8, 0.3, 5000)


def _motor(dur, f0, f1):
    t = t_(dur)
    f = f0 + (f1 - f0) * (t / dur)
    fase = 2 * np.pi * np.cumsum(f) / TAXA
    m = np.sin(fase) + 0.5 * np.sin(2 * fase) + 0.3 * np.sin(3 * fase)
    m += filtro(ruido(dur), "bandpass", [800, 3000], 2) * 0.4
    return m * np.clip(t / 0.02, 0, 1) * np.clip((dur - t) / 0.03, 0, 1)


def _trava():
    s = vazio(0.25)
    colar(s, som(baque(0.05, 900, 60), estalo(0.002, 2000) * 0.8), 0.0)
    colar(s, modos(0.25, [310, 720, 1350, 2400], [1.0, 0.5, 0.35, 0.2], [30, 40, 55, 70]), 0.0, 0.6)
    return s


def lanterna_sobe():
    s = vazio(0.5)
    colar(s, _motor(0.2, 300, 520), 0.0, 0.25)
    colar(s, _trava(), 0.2, 1.0)
    return sala(s, 0.4, 0.2)


def lanterna_desce():
    s = vazio(0.5)
    colar(s, _trava()[: int(0.12 * TAXA)], 0.0, 0.7)
    colar(s, _motor(0.25, 520, 240), 0.04, 0.25)
    return sala(s, 0.4, 0.2)


# ───────────────────────────────────────────── Mar
def bolha(f0, dur=0.05):
    """Bolha estourando/soltando: seno com a frequência subindo (Minnaert)."""
    t = t_(dur)
    f = f0 * (1 + 2.5 * t / dur)
    return np.sin(2 * np.pi * np.cumsum(f) / TAXA) * np.exp(-t * (60 + f0 * 0.02))


def bolhas_tiro():
    s = vazio(0.9)
    colar(s, baque(0.1, 350, 30), 0.0, 0.8)
    cav = filtro(ruido(0.18), "bandpass", [500, 2200], 2) * np.exp(-t_(0.18) * 18)
    colar(s, cav, 0.0, 0.5)
    for i in range(18):
        colar(s, bolha(rng.uniform(350, 1300)), 0.03 + (i / 18) * 0.45 + rng.uniform(-0.02, 0.02), rng.uniform(0.15, 0.45))
    s = filtro(s, "lowpass", 3200, 2)          # tudo abafado: está debaixo d'água
    return sala(s, 0.7, 0.35, 2500)


# ───────────────────────────────────────────── Bar
def madeira_tiro():
    s = vazio(0.7)
    colar(s, filtro(ruido(0.05), "bandpass", [700, 3200], 2) * np.exp(-t_(0.05) * 70), 0.0, 1.2)
    colar(s, estalo(0.002, 2500), 0.0, 0.8)
    colar(s, modos(0.4, [210, 530, 960, 1650], [1.0, 0.7, 0.45, 0.25], [28, 38, 50, 65]), 0.0, 0.55)
    for i in range(8):
        colar(s, som(estalo(0.0015, 2500), ressonancia_curta(rng.uniform(1500, 4000), 250, 0.012) * 0.4), rng.uniform(0.005, 0.07), rng.uniform(0.2, 0.5))
    for i in range(6):
        colar(s, som(baque(0.02, 2500, 120) * 0.5, estalo(0.001, 3000) * 0.3), rng.uniform(0.25, 0.55), rng.uniform(0.1, 0.25))
    return sala(s, 0.45, 0.2, 5000)


def papel_tiro():
    s = vazio(0.6)
    t = t_(0.16)
    rasga = filtro(ruido(0.16), "bandpass", [900, 5500], 2)
    graos = (filtro(rng.random(len(t)), "lowpass", 300, 2) > 0.52).astype(float)
    rasga *= graos * np.clip(t / 0.01, 0, 1) * np.exp(-t * 12)
    colar(s, rasga, 0.0, 0.9)
    colar(s, filtro(ruido(0.04), "bandpass", [600, 2500], 2) * np.exp(-t_(0.04) * 80), 0.01, 0.6)
    colar(s, modos(0.3, [190, 470, 880], [1.0, 0.6, 0.3], [32, 42, 55]), 0.01, 0.3)
    return sala(s, 0.45, 0.2, 5000)


if __name__ == "__main__":
    gravar(cristal_trinca(), "cristal_trinca.wav", 0.75)
    gravar(cristal_quebra(), "cristal_quebra.wav", 0.9)
    gravar(cristal_volta(), "cristal_volta.wav", 0.6)
    gravar(ouro_ping(), "ouro_ping.wav", 0.65)
    gravar(areia_tiro(), "areia_tiro.wav", 0.6)
    gravar(raio_sol(), "raio_sol.wav", 0.5)
    gravar(raio_lua(), "raio_lua.wav", 0.45)
    gravar(laser_parede(), "laser_parede.wav", 0.65)
    gravar(arena_vapor(), "arena_vapor.wav", 0.5)
    gravar(arena_faisca(), "arena_faisca.wav", 0.55)
    gravar(arena_troca(), "arena_troca.wav", 0.7)
    gravar(lanterna_sobe(), "lanterna_sobe.wav", 0.55)
    gravar(lanterna_desce(), "lanterna_desce.wav", 0.55)
    gravar(bolhas_tiro(), "bolhas_tiro.wav", 0.6)
    gravar(madeira_tiro(), "madeira_tiro.wav", 0.7)
    gravar(papel_tiro(), "papel_tiro.wav", 0.6)
