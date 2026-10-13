#!/usr/bin/env python3
"""Artes e sons do Mar (scripts/mar_vida.gd).

Parte de sprites/atlantis.png (a foto do menu, que não muda) e gera:

  sprites/atlantis_jogo.png          fundo da partida: sem o navio (ele cai aos
                                     9 s) e sem os peixinhos parados (agora
                                     são cardumes que nadam)
  sprites/mar_navio.png              o navio recortado (só o navio) para cair
  sprites/mar_navio_pouso.png        a foto na caixa do navio: entra quando ele
                                     pousa (o cenário volta a ser a foto)
  sprites/mar_pedra_esq_mascara.png  pedras com escritas, 1x da caixa de cada
  sprites/mar_pedra_dir_mascara.png  uma: R=runas G=altura (0 topo, 1 base)
                                     B=pedra A=halo das runas
  sprites/mar_peixe.png              peixinho dos cardumes (silhueta)
  songs/baleia.wav                   canto de baleia ao longe
  songs/navio_desce.wav              água correndo, madeira rangendo, bolhas
  songs/navio_impacto.wav            batida surda no fundo + areia + bolhas
  songs/pedra_lasca.wav              pedra rachando debaixo d'água

Precisa de opencv-contrib-python-headless (preenchimento por deslocamento,
xphoto.INPAINT_SHIFTMAP) além de numpy, scipy e Pillow.

    python3 tools/gerar_mar.py
"""
import os
import wave
import numpy as np
import cv2
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from scipy.signal import fftconvolve

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")
SONGS = os.path.join(RAIZ, "songs")
rng = np.random.default_rng(11)
W, H = 1024, 1536

# Contornos em px de atlantis.png (mesmos números em scripts/mar_vida.gd).
NAVIO = [(188, 538), (330, 488), (382, 452), (412, 442), (518, 435), (524, 468), (492, 570),
         (487, 632), (480, 698), (542, 762), (538, 802), (502, 872), (462, 912), (410, 934),
         (290, 934), (222, 898), (186, 770), (182, 670)]
PEDRA_ESQ = [(70, 486), (100, 468), (145, 468), (165, 494), (180, 570), (195, 650), (205, 720),
             (215, 790), (225, 860), (236, 925), (0, 935), (0, 740), (14, 640), (30, 565), (55, 512)]
PEDRA_DIR = [(725, 540), (760, 525), (830, 525), (850, 545), (880, 590), (905, 660), (925, 760),
             (940, 850), (948, 930), (900, 942), (856, 952), (850, 1060), (800, 1065), (790, 1130),
             (785, 1230), (525, 1230), (530, 1150), (550, 1050), (580, 950), (610, 850), (630, 760),
             (665, 670), (700, 580)]
# água aberta onde havia peixinhos parados
AGUA = [(196, 150), (700, 150), (700, 236), (650, 300), (566, 334), (476, 420), (414, 462),
        (330, 474), (258, 444), (212, 384), (196, 300)]


def poligono(p, ss=1):
    m = Image.new("L", (W * ss, H * ss), 0)
    ImageDraw.Draw(m).polygon([(x * ss, y * ss) for x, y in p], fill=255)
    if ss > 1:
        m = m.resize((W, H), Image.LANCZOS)
    return np.asarray(m).astype(np.float32) / 255.0


def gravar_img(arr, nome, modo=None):
    img = Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), modo)
    img.save(os.path.join(SP, nome), optimize=True)
    print("%-30s %dx%d" % (nome, img.width, img.height))


# ───────────────────────────────────────────── fundo sem navio e sem peixes
def fundo_sem_navio(orig_bgr):
    nav = poligono(NAVIO) > 0.5
    pe = poligono(PEDRA_ESQ) > 0.5
    buraco = ndi.binary_dilation(nav, iterations=2) & ~pe
    # espelhado: o deslocamento acha ruínas e pedras ao fundo (sem esse giro
    # ele copiava estruturas estranhas do lado esquerdo)
    img = orig_bgr[:, ::-1].copy()
    valido = (~buraco[:, ::-1]).astype(np.uint8) * 255
    dst = np.zeros_like(img)
    cv2.xphoto.inpaint(img, valido, dst, cv2.xphoto.INPAINT_SHIFTMAP)
    return dst[:, ::-1].copy()


def tirar_peixes(bg_bgr):
    rgb = bg_bgr[..., ::-1].astype(np.float32) / 255
    lum = rgb @ np.array([0.3, 0.59, 0.11], np.float32)
    agua = poligono(AGUA) > 0.5
    bh = ndi.grey_closing(lum, size=(15, 15)) - lum
    cand = (bh > 0.075) & agua
    lab, _ = ndi.label(cand)
    ok = np.zeros_like(cand)
    for i, sl in enumerate(ndi.find_objects(lab)):
        if sl is None:
            continue
        reg = lab[sl] == i + 1
        t = reg.sum()
        h = sl[0].stop - sl[0].start
        w = sl[1].stop - sl[1].start
        if 5 <= t <= 260 and w >= h * 0.8 and h <= 22:
            ok[sl] |= reg
    m = ndi.binary_dilation(ok, iterations=2)
    return cv2.inpaint(bg_bgr, m.astype(np.uint8) * 255, 4, cv2.INPAINT_TELEA)


# ───────────────────────────────────────────── navio recortado
def recortar_navio(orig, bg):
    """Dois recortes do navio (orig/bg em float RGB):
    - mar_navio.png: só o navio (cordas, mastros, casco), sem o nevoeiro de
      trás, para cair limpo pela água. Alfa = quanto o pixel é mais escuro que
      o nevoeiro em volta; cor = o navio "descontado" do nevoeiro.
    - mar_navio_pouso.png: a foto original na caixa do navio (alfa = contorno).
      Quando o navio pousa, a areia sobe e este recorte entra no lugar: o
      cenário volta a ser exatamente a foto."""
    P = poligono(NAVIO, 4)
    pe = poligono(PEDRA_ESQ) > 0.5
    nevoa = np.stack([ndi.gaussian_filter(ndi.grey_closing(orig[..., c], size=(41, 41)), 8) for c in range(3)], -1)
    lum = orig @ np.array([0.3, 0.59, 0.11], np.float32)
    lum_n = nevoa @ np.array([0.3, 0.59, 0.11], np.float32)
    a = np.clip((lum_n - lum - 0.03) / 0.20, 0, 1)
    a = ndi.gaussian_filter(a, 0.6)
    # redes e cordas somem aos poucos perto do contorno (sem "placa" de recorte)
    dentro = ndi.gaussian_filter((P > 0.5).astype(np.float32), 6.0)
    a = a * np.clip(dentro * 1.8 - 0.6, 0, 1)
    F = np.clip((orig - (1 - a)[..., None] * nevoa) / np.maximum(a, 0.08)[..., None], 0, 1)
    # parte escondida atrás da pedra: continua o casco (só aparece caindo)
    atras = ndi.binary_dilation((P > 0.5) & pe, iterations=2)
    m8 = atras.astype(np.uint8) * 255
    F = cv2.inpaint((F * 255).astype(np.uint8), m8, 7, cv2.INPAINT_TELEA).astype(np.float32) / 255
    a = cv2.inpaint((a * 255).astype(np.uint8), m8, 7, cv2.INPAINT_TELEA).astype(np.float32) / 255
    a *= P > 0.02
    ys, xs = np.nonzero(P > 0.01)
    x0, y0, x1, y1 = xs.min() - 4, ys.min() - 4, xs.max() + 5, ys.max() + 5
    sl = (slice(y0, y1), slice(x0, x1))
    gravar_img(np.dstack([F[sl], a[sl]]), "mar_navio.png", "RGBA")
    pouso = np.clip(ndi.gaussian_filter(ndi.binary_dilation(P > 0.5, iterations=4).astype(np.float32), 1.5), 0, 1)
    gravar_img(np.dstack([orig[sl], pouso[sl]]), "mar_navio_pouso.png", "RGBA")
    print("   navio: canto (%d, %d)  tamanho %dx%d" % (x0, y0, x1 - x0, y1 - y0))


# ───────────────────────────────────────────── pedras com escritas
def mascara_pedra(orig, contorno, nome):
    memb = poligono(contorno, 4)
    ys, xs = np.nonzero(memb > 0.01)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    r, g, b = orig[..., 0], orig[..., 1], orig[..., 2]
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    ciano = np.minimum(g, b) - r
    runa = np.clip((ciano - 0.16) / 0.28, 0, 1) * np.clip((lum - 0.30) / 0.25, 0, 1)
    runa = ndi.gaussian_filter(runa, 0.7) * memb
    halo = ndi.gaussian_filter(runa, 4.0)
    halo = np.clip(halo / max(halo.max(), 1e-3) * 1.6, 0, 1) * memb
    yy = np.mgrid[0:H, 0:W][0].astype(np.float32)
    altura = np.clip((yy - y0) / (y1 - y0), 0, 1)
    sl = (slice(y0, y1), slice(x0, x1))
    gravar_img(np.dstack([runa[sl], altura[sl], memb[sl], halo[sl]]), nome, "RGBA")
    print("   %s: canto (%d, %d)  tamanho %dx%d" % (nome, x0, y0, x1 - x0, y1 - y0))


def peixe():
    """Silhueta de peixinho visto de lado, cabeça à direita, 4x reduzido."""
    S = 4
    w, h = 40 * S, 16 * S
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    corpo = []
    for i in range(41):
        t = i / 40.0
        x = (0.18 + 0.80 * t) * w
        meia = (0.42 * np.sin(np.pi * (t ** 0.8)) ** 0.9) * h
        corpo.append((x, h / 2 - meia))
    for i in range(40, -1, -1):
        t = i / 40.0
        x = (0.18 + 0.80 * t) * w
        meia = (0.36 * np.sin(np.pi * (t ** 0.8)) ** 0.9) * h
        corpo.append((x, h / 2 + meia))
    d.polygon(corpo, fill=255)
    d.polygon([(0.24 * w, h / 2), (0.0, 0.08 * h), (0.07 * w, h / 2), (0.0, 0.92 * h)], fill=255)
    d.polygon([(0.50 * w, 0.14 * h), (0.62 * w, 0.0), (0.66 * w, 0.18 * h)], fill=200)
    a = np.asarray(im.resize((40, 16), Image.LANCZOS)).astype(np.float32) / 255
    # dorso mais escuro, barriga um pouco mais clara (contra a luz de cima)
    yy = np.linspace(0, 1, 16)[:, None] * np.ones((1, 40))
    cor = np.clip(0.62 + 0.38 * yy, 0, 1)
    gravar_img(np.dstack([cor, cor, cor, a]), "mar_peixe.png", "RGBA")


# ───────────────────────────────────────────── sons (22050 Hz, mono)
TAXA = 22050


def gravar_wav(sinal, nome, pico=0.80):
    s = np.asarray(sinal, np.float64)
    s = s / (np.abs(s).max() + 1e-9) * pico
    dados = (s * 32767).astype(np.int16)
    with wave.open(os.path.join(SONGS, nome), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(TAXA)
        f.writeframes(dados.tobytes())
    print("%-30s %.2f s" % (nome, len(s) / TAXA))


def tempo(seg):
    return np.arange(int(seg * TAXA)) / TAXA


def passa_baixa_rapido(x, fc, ordem=2):
    from scipy.signal import butter, sosfilt
    return sosfilt(butter(ordem, fc, "low", fs=TAXA, output="sos"), x)


def passa_banda(x, f0, f1, ordem=2):
    from scipy.signal import butter, sosfilt
    return sosfilt(butter(ordem, [f0, f1], "band", fs=TAXA, output="sos"), x)


def reverb(x, dur, decai, molhado):
    n = int(dur * TAXA)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (decai * TAXA))
    ir = passa_baixa_rapido(ir, 2500)
    ir /= np.sqrt((ir ** 2).sum())
    y = np.zeros(len(x) + n)
    c = fftconvolve(x, ir)
    y[: len(c)] = c[: len(y)]
    seco = np.concatenate([x, np.zeros(n)])
    return seco * (1 - molhado) + y * molhado * 3.0


def envelope(t, ataque, solta, total):
    e = np.clip(t / ataque, 0, 1) * np.clip((total - t) / solta, 0, 1)
    return e * e * (3 - 2 * e)


def tom(f, t, harm=(1.0, 0.5, 0.25, 0.12)):
    fase = 2 * np.pi * np.cumsum(f) / TAXA
    return sum(a * np.sin((k + 1) * fase) for k, a in enumerate(harm))


def bolhas(dur, n, f0=(320, 700), f1=(800, 1600), pico=0.5):
    out = np.zeros(int(dur * TAXA))
    for _ in range(n):
        ini = rng.integers(0, len(out) - 2000)
        d = rng.uniform(0.018, 0.045)
        tt = tempo(d)
        f = rng.uniform(*f0) * (rng.uniform(*f1) / 600.0) ** (tt / d)
        b = np.sin(2 * np.pi * np.cumsum(f) / TAXA) * np.exp(-tt / (d * 0.35)) * rng.uniform(0.3, 1.0)
        out[ini:ini + len(b)] += b * pico
    return out


def som_baleia():
    total = 5.2
    t = tempo(total)
    s = np.zeros_like(t)
    # gemido longo que sobe e desce
    m1 = (t < 2.4)
    tt = t[m1]
    f = 135 + 95 * np.sin(np.pi * tt / 2.4) ** 1.5 + 3.0 * np.sin(2 * np.pi * 4.6 * tt)
    s[m1] += tom(f, tt) * envelope(tt, 0.45, 0.7, 2.4)
    # "uuoop" que sobe rápido e cai
    m2 = (t >= 2.7) & (t < 4.6)
    tt = t[m2] - 2.7
    f = np.where(tt < 1.2, 250 * (2.1 ** (tt / 1.2)), 525 - 140 * ((tt - 1.2) / 0.7))
    f = f + 4.0 * np.sin(2 * np.pi * 5.2 * tt)
    s[m2] += 0.8 * tom(f, tt, (1.0, 0.35, 0.15)) * envelope(tt, 0.25, 0.45, 1.9)
    # sopro de ar no fundo
    s += 0.05 * passa_baixa_rapido(rng.standard_normal(len(t)), 400) * envelope(t, 0.5, 1.0, total)
    s = passa_baixa_rapido(s, 1600)
    return reverb(s, 2.2, 0.55, 0.5)


def som_navio_desce():
    total = 3.2
    t = tempo(total)
    agua = passa_baixa_rapido(np.cumsum(rng.standard_normal(len(t))) * 0.02, 320)
    agua = agua - passa_baixa_rapido(agua, 25)
    agua *= envelope(t, 0.6, 0.5, total) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.9 * t))
    s = agua * 3.0
    # madeira rangendo (duas vezes)
    for ini, dur, base in [(0.5, 0.55, 95), (1.7, 0.7, 120)]:
        tt = tempo(dur)
        f = base * (1 + 0.25 * np.sin(2 * np.pi * 1.3 * tt)) + rng.normal(0, 6, len(tt))
        serra = 2 * ((np.cumsum(f) / TAXA) % 1.0) - 1
        rangido = passa_banda(serra, 300, 1400) * envelope(tt, 0.08, 0.2, dur) * (0.6 + 0.4 * (rng.random(len(tt)) > 0.6))
        i = int(ini * TAXA)
        s[i:i + len(tt)] += rangido * 0.5
    s += bolhas(total, 70, pico=0.35) * np.clip(t / total * 1.4, 0.2, 1.0)
    s = passa_baixa_rapido(s, 3000)
    return reverb(s, 1.5, 0.4, 0.35)


def som_navio_impacto():
    total = 3.6
    t = tempo(total)
    boom = (np.sin(2 * np.pi * 38 * t) + 0.7 * np.sin(2 * np.pi * 56 * t)) * np.exp(-t / 0.75)
    batida = passa_baixa_rapido(rng.standard_normal(len(t)), 600) * np.exp(-t / 0.22) * 2.0
    madeira = passa_banda(rng.standard_normal(len(t)), 350, 1900) * np.exp(-t / 0.35) * (rng.random(len(t)) > 0.4) * 0.8
    areia = passa_baixa_rapido(rng.standard_normal(len(t)), 900) * np.exp(-t / 1.4) * 0.6 * np.clip(t / 0.15, 0, 1)
    s = boom * 1.2 + batida + madeira + areia
    s += bolhas(total, 90, pico=0.3) * np.exp(-t / 1.6)
    s = passa_baixa_rapido(s, 2800)
    return reverb(s, 2.0, 0.6, 0.4)


def som_pedra():
    total = 0.75
    t = tempo(total)
    estalo = rng.standard_normal(len(t)) * np.exp(-t / 0.004)
    tok = np.sin(2 * np.pi * 1750 * t) * np.exp(-t / 0.014) + 0.8 * np.sin(2 * np.pi * 880 * t) * np.exp(-t / 0.03)
    surdo = np.sin(2 * np.pi * 110 * t) * np.exp(-t / 0.10) * 1.1
    grao = np.zeros_like(t)
    for _ in range(18):
        i = int(rng.uniform(0.01, 0.30) * TAXA)
        d = int(0.004 * TAXA)
        grao[i:i + d] += rng.standard_normal(d) * rng.uniform(0.2, 0.7) * np.exp(-np.arange(d) / (0.0015 * TAXA))
    grao *= np.exp(-t / 0.18)
    s = estalo * 1.2 + tok + surdo + grao
    s += bolhas(total, 10, pico=0.25)
    s = passa_baixa_rapido(s, 3600)
    return reverb(s, 0.6, 0.18, 0.25)


def main():
    orig_bgr = cv2.imread(os.path.join(SP, "atlantis.png"))
    bg_bgr = tirar_peixes(fundo_sem_navio(orig_bgr))
    gravar_img(bg_bgr[..., ::-1].astype(np.float32) / 255, "atlantis_jogo.png")
    orig = orig_bgr[..., ::-1].astype(np.float32) / 255
    bg = bg_bgr[..., ::-1].astype(np.float32) / 255
    recortar_navio(orig, bg)
    mascara_pedra(orig, PEDRA_ESQ, "mar_pedra_esq_mascara.png")
    mascara_pedra(orig, PEDRA_DIR, "mar_pedra_dir_mascara.png")
    peixe()
    gravar_wav(som_baleia(), "baleia.wav", 0.7)
    gravar_wav(som_navio_desce(), "navio_desce.wav", 0.7)
    gravar_wav(som_navio_impacto(), "navio_impacto.wav", 0.85)
    gravar_wav(som_pedra(), "pedra_lasca.wav", 0.8)


if __name__ == "__main__":
    main()
