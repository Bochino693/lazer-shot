#!/usr/bin/env python3
"""Vozes do anunciador de combos (scripts/combo_anuncio.gd), uma por tela.

Cada fala sai do Piper (voz sintetizada, roda sem internet) e ganha o
timbre da tela no ffmpeg; por baixo entra um efeito curto feito aqui:
  mar      Poseidon: bem grave e encorpado (coro leve), com eco curto de
           caverna; por baixo um "vuum" de água e bolhas
  deserto  deus do Egito: grave, com eco longo de templo; por baixo um gongo
  bar      locutor de saloon: rápido, voz de rádio antigo com estalo; por
           baixo um sino de balcão
  arena    locutora da arena de laser: voz de máquina com eco de estádio;
           por baixo um laser subindo

O efeito bate antes e quase some quando a voz entra, e cada fala sai no
mesmo volume. Os efeitos da voz foram escolhidos para ela continuar clara
(conferido com um reconhecedor de voz: vibrato e eco longo e denso juntos
embolavam a fala grave).

Gera songs/voz/<tela>_<fala>.ogg (mono, 22 kHz, Vorbis).

Precisa do Piper (pip install piper-tts) e dos modelos en_US-ryan-high e
en_US-lessac-medium (.onnx + .onnx.json, releases do rhasspy/piper):
    PIPER=/caminho/piper VOZES=/pasta/dos/modelos python3 tools/gerar_vozes.py
"""
import os
import subprocess
import tempfile
import wave
import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAIDA = os.environ.get("SAIDA", os.path.join(RAIZ, "songs", "voz"))
PIPER = os.environ.get("PIPER", "piper")
VOZES = os.environ.get("VOZES", ".")
SR = 22050

# o que o anunciador fala (a mesma lista do scripts/combo_anuncio.gd)
FALAS = [
    ("double", "Double hit!"),
    ("triple", "Triple hit!"),
    ("quadra", "Quadra hit!"),
    ("penta", "Penta hit!"),
    ("mega", "Mega combo!"),
    ("super", "Super combo!"),
    ("insano", "Insane!"),
    ("imparavel", "Unstoppable!"),
    ("lendario", "Legendary!"),
]
ESPECIAL = {
    "mar": "Poseidon's treasure!",
    "deserto": "Power of Ra!",
    "arena": "Perfect sequence!",
}

# voz, ritmo (length_scale: menor = mais rápido) e o timbre de cada tela
TELAS = {
    "mar": {
        "modelo": "en-us-ryan-high.onnx", "ritmo": 1.0,
        "filtro": "rubberband=pitch=0.7,equalizer=f=120:t=q:w=1:g=5,"
                  "chorus=0.7:0.9:35|50:0.3|0.25:0.3|0.4:1.2|1.7,"
                  "aecho=0.85:0.6:45|90:0.25|0.15",
    },
    "deserto": {
        "modelo": "en-us-ryan-high.onnx", "ritmo": 1.0,
        "filtro": "rubberband=pitch=0.84,equalizer=f=160:t=q:w=1:g=3,"
                  "aecho=0.85:0.7:240|480:0.24|0.12",
    },
    "bar": {
        "modelo": "en-us-ryan-high.onnx", "ritmo": 0.86,
        "filtro": "rubberband=pitch=1.04,highpass=f=320,lowpass=f=3400,"
                  "volume=2.2,alimiter=limit=0.6,equalizer=f=1600:t=q:w=1:g=5,"
                  "aecho=0.7:0.5:32:0.22",
    },
    "arena": {
        "modelo": "en-us-lessac-medium.onnx", "ritmo": 0.9,
        "filtro": "rubberband=pitch=0.94,flanger=delay=2:depth=2:speed=0.6,"
                  "chorus=0.6:0.8:20|28:0.3|0.25:0.3|0.4:2|2.6,highpass=f=120,"
                  "aecho=0.8:0.86:240|480:0.3|0.16",
    },
}


def ler_wav(caminho):
    with wave.open(caminho) as w:
        sr = w.getframerate()
        a = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32768
        if w.getnchannels() == 2:
            a = a.reshape(-1, 2).mean(1)
    if sr != SR:
        x = np.arange(int(len(a) * SR / sr)) * sr / SR
        a = np.interp(x, np.arange(len(a)), a)
    return a


def gravar_wav(caminho, a):
    with wave.open(caminho, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(a, -1, 1) * 32767).astype(np.int16).tobytes())


def falar(texto, modelo, ritmo, pasta):
    bruto = os.path.join(pasta, "bruto.wav")
    subprocess.run([PIPER, "-m", os.path.join(VOZES, modelo), "-f", bruto, "--length-scale", str(ritmo),
                    "--noise-scale", "0.5", "--sentence-silence", "0"],
                   input=texto.encode(), check=True, capture_output=True)
    return bruto


def ffmpeg(entrada, filtro, saida):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", entrada, "-af", filtro + ",aresample=%d" % SR,
                    "-ac", "1", saida], check=True)


def aparar(a, limiar=0.01):
    i = np.nonzero(np.abs(a) > limiar)[0]
    if len(i) == 0:
        return a
    return a[max(0, i[0] - 200):min(len(a), i[-1] + 2000)]


# ───────────────────────────────────────── efeitos por baixo da voz
def _env(n, ataque, queda):
    t = np.arange(n) / SR
    return np.minimum(t / max(ataque, 1e-4), 1.0) * np.exp(-t / queda)


def efeito_mar(g):
    n = int(SR * 1.0)
    t = np.arange(n) / SR
    f = 95 * np.exp(-t * 1.4) + 40
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * _env(n, 0.05, 0.35)
    ruido = g.standard_normal(n)
    agua = np.convolve(ruido, np.ones(60) / 60, "same") * _env(n, 0.12, 0.3) * 2.5
    bolhas = np.zeros(n)
    for _ in range(9):
        i0 = int(g.uniform(0.05, 0.6) * SR)
        m = int(SR * 0.05)
        tt = np.arange(m) / SR
        fb = g.uniform(500, 1100) * (1 + tt * 18)
        bolhas[i0:i0 + m] += np.sin(2 * np.pi * np.cumsum(fb) / SR) * np.exp(-tt * 70) * 0.25
    return sub * 0.8 + agua * 0.5 + bolhas


def efeito_deserto(g):
    n = int(SR * 1.6)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for r, a, q in [(1, 1.0, 0.9), (1.48, 0.6, 0.7), (2.0, 0.5, 0.6), (2.76, 0.35, 0.45), (3.34, 0.25, 0.35), (4.1, 0.2, 0.3)]:
        s += a * np.sin(2 * np.pi * 98 * r * t + g.uniform(0, 6)) * np.exp(-t / q)
    s *= np.minimum(t / 0.004, 1)
    brilho = g.standard_normal(n)
    brilho = (brilho - np.convolve(brilho, np.ones(6) / 6, "same")) * _env(n, 0.01, 0.12) * 0.25
    return s * 0.45 + brilho


def efeito_bar(g):
    n = int(SR * 0.9)
    t = np.arange(n) / SR
    sino = sum(a * np.sin(2 * np.pi * 1320 * r * t) * np.exp(-t / q)
               for r, a, q in [(1, 1.0, 0.35), (2.0, 0.4, 0.2), (2.97, 0.25, 0.12), (4.2, 0.15, 0.08)])
    bumbo = np.sin(2 * np.pi * np.cumsum(140 * np.exp(-t * 18) + 45) / SR) * _env(n, 0.002, 0.09)
    return sino * 0.35 + bumbo * 0.7


def efeito_arena(g):
    n = int(SR * 0.8)
    t = np.arange(n) / SR
    f = 180 + 1400 * np.clip(t / 0.28, 0, 1) ** 1.6
    fase = np.cumsum(f) / SR
    serra = 2 * (fase % 1.0) - 1
    sobe = serra * np.where(t < 0.3, t / 0.3, np.exp(-(t - 0.3) / 0.06)) * 0.25
    bumbo = np.sin(2 * np.pi * np.cumsum(120 * np.exp(-np.maximum(t - 0.28, 0) * 16) + 40) / SR)
    bumbo *= np.where(t >= 0.28, np.exp(-(t - 0.28) / 0.16), 0)
    return np.convolve(sobe, np.ones(3) / 3, "same") + bumbo * 0.8


EFEITOS = {"mar": efeito_mar, "deserto": efeito_deserto, "bar": efeito_bar, "arena": efeito_arena}
# a voz entra quando o efeito já bateu
ATRASO = {"mar": 0.10, "deserto": 0.06, "bar": 0.04, "arena": 0.27}


def montar(tela, chave, texto, pasta, g):
    cfg = TELAS[tela]
    bruto = falar(texto, cfg["modelo"], cfg["ritmo"], pasta)
    feito = os.path.join(pasta, "feito.wav")
    ffmpeg(bruto, cfg["filtro"], feito)
    voz = aparar(ler_wav(feito))
    # todas as falas no mesmo volume (pela média da parte com voz)
    forte = np.abs(voz) > 0.02 * np.abs(voz).max()
    voz *= 0.17 / max(np.sqrt(np.mean(voz[forte] ** 2)), 1e-6)
    fx = EFEITOS[tela](g)
    fx *= 0.30 / max(np.abs(fx).max(), 1e-6)
    atraso = int(ATRASO[tela] * SR)
    n = max(len(fx), atraso + len(voz))
    pista_voz = np.zeros(n)
    pista_voz[atraso:atraso + len(voz)] = voz
    pista_fx = np.zeros(n)
    pista_fx[:len(fx)] = fx
    # o efeito bate antes e quase some quando a voz entra (não cobre as
    # palavras: o grave do efeito embolava a voz grave)
    t = (np.arange(n) - atraso) / SR
    mix = pista_voz + pista_fx * np.where(t < 0, 1.0, 0.12 + 0.88 * np.exp(-np.maximum(t, 0) / 0.06))
    # picos arredondados (sem estourar)
    mix = np.tanh(mix * 1.6) / np.tanh(1.6) * 0.9
    # termina suave
    cauda = int(SR * 0.06)
    mix[-cauda:] *= np.linspace(1, 0, cauda)
    wav = os.path.join(pasta, "mix.wav")
    gravar_wav(wav, mix)
    destino = os.path.join(SAIDA, "%s_%s.ogg" % (tela, chave))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", destino], check=True)
    return destino, n / SR


def main():
    os.makedirs(SAIDA, exist_ok=True)
    g = np.random.default_rng(18)
    with tempfile.TemporaryDirectory() as pasta:
        for tela in TELAS:
            especial = [("especial", ESPECIAL[tela])] if tela in ESPECIAL else []
            for chave, texto in FALAS + especial:
                destino, dur = montar(tela, chave, texto, pasta, g)
                print("  %-28s %.2f s  %5.1f KB" % (os.path.basename(destino), dur, os.path.getsize(destino) / 1024))


if __name__ == "__main__":
    main()
