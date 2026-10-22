# Gera sprites/pincel.png: atlas 512x512 (4x4 células de 128 px) com as
# formas que os efeitos e as miras desenham. Desenhar tudo com recortes da
# MESMA textura deixa o Godot juntar centenas de formas num desenho só
# (círculos/arcos/linhas soltos viram uma chamada de GPU cada).
# Uso: python3 tools/gerar_pincel.py
import numpy as np
from PIL import Image

C = 128          # célula
SS = 4           # superamostragem (bordas lisas)
R = 48.0         # raio útil das formas redondas (sobra margem p/ mipmaps)
ANEIS = [0.035, 0.07, 0.12, 0.2, 0.32, 0.5]

def grade():
    n = C * SS
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    return (x + 0.5) / SS - C / 2, (y + 0.5) / SS - C / 2

def reduz(a):
    n = C
    return a.reshape(n, SS, n, SS, -1).mean(axis=(1, 3))

def branco(alfa):
    a = np.clip(alfa, 0, 1)[..., None]
    return np.concatenate([np.ones_like(a), np.ones_like(a), np.ones_like(a), a], -1)

def disco():
    x, y = grade(); r = np.hypot(x, y)
    return branco((r <= R).astype(np.float32))

def brilho():
    x, y = grade(); r = np.hypot(x, y) / (R * 1.25)
    a = np.exp(-r * r * 3.2) * (r < 1.0) * np.clip((1.0 - r) * 6, 0, 1)
    return branco(a)

def anel(t):
    x, y = grade(); r = np.hypot(x, y)
    return branco(((r <= R) & (r >= R * (1 - t))).astype(np.float32))

def traco():
    # faixa horizontal: miolo de 32 px no meio (y 48..80), ponta a ponta
    x, y = grade()
    return branco((np.abs(y) <= 16).astype(np.float32))

def lasca():
    x, y = grade()
    pts = np.array([[-44, -10], [-12, -34], [40, -18], [30, 20], [-6, 36], [-38, 14]], np.float32)
    dentro = np.ones_like(x, bool)
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        dentro &= ((b[0] - a[0]) * (y - a[1]) - (b[1] - a[1]) * (x - a[0])) >= 0
    return branco(dentro.astype(np.float32))

def moeda():
    x, y = grade(); r = np.hypot(x, y)
    ouro = np.array([1.0, 0.80, 0.20]); escuro = np.array([0.72, 0.46, 0.06]); claro = np.array([1.0, 0.95, 0.62])
    cor = np.zeros(x.shape + (3,), np.float32) + ouro
    borda = (r > R * 0.80) & (r <= R)
    cor[borda] = escuro
    luz = np.clip(1 - np.hypot(x + R * 0.30, y + R * 0.32) / (R * 0.55), 0, 1) ** 1.5
    cor = cor * (1 - luz[..., None] * 0.7) + claro * luz[..., None] * 0.7
    # estrela no meio
    ang = np.arctan2(y, x); raio_estrela = R * (0.22 + 0.16 * np.cos(ang * 5) ** 2)
    estrela = (r < raio_estrela * 0.95) & ~borda
    cor[estrela] = cor[estrela] * 0.78
    a = (r <= R).astype(np.float32)
    return np.concatenate([cor, a[..., None]], -1)

def furo_madeira():
    x, y = grade(); r = np.hypot(x, y)
    rng = np.random.default_rng(3)
    ang = np.arctan2(y, x)
    lascas = 1.0 + 0.35 * np.abs(np.sin(ang * 7 + 0.4)) + 0.2 * np.sin(ang * 13)
    poeira = np.clip(1 - r / (R * 0.98), 0, 1) ** 1.4 * 0.30
    queimado = np.clip(1 - r / (R * 0.55 * lascas), 0, 1) ** 0.8 * 0.55
    buraco = (r < R * 0.24).astype(np.float32)
    borda_clara = ((r > R * 0.24) & (r < R * 0.32)).astype(np.float32) * 0.35
    a = np.clip(poeira + queimado + buraco, 0, 1)
    cor = np.zeros(x.shape + (3,), np.float32)
    cor[..., 0] = 0.10 + 0.30 * borda_clara; cor[..., 1] = 0.06 + 0.17 * borda_clara; cor[..., 2] = 0.03 + 0.07 * borda_clara
    cor[r < R * 0.24] = [0.02, 0.015, 0.012]
    return np.concatenate([cor, a[..., None]], -1)

def bolha():
    x, y = grade(); r = np.hypot(x, y)
    corpo = (r <= R).astype(np.float32)
    borda = np.clip((r - R * 0.78) / (R * 0.22), 0, 1) ** 2 * corpo
    reflexo = np.clip(1 - np.hypot(x + R * 0.38, y + R * 0.38) / (R * 0.26), 0, 1) ** 1.2
    a = np.clip(0.10 * corpo + 0.75 * borda + 0.9 * reflexo, 0, 1)
    return branco(a)

def faisca():
    x, y = grade(); r = np.hypot(x, y) + 1e-3
    ang = np.arctan2(y, x)
    raio = R * (0.18 + 0.82 * np.abs(np.cos(ang * 2)) ** 18)
    a = np.clip(1 - r / raio, 0, 1) ** 0.9 + np.exp(-(r / (R * 0.22)) ** 2) * 0.8
    return branco(np.clip(a, 0, 1))

def fumaca():
    x, y = grade(); r = np.hypot(x, y)
    rng = np.random.default_rng(11)
    ruido = np.zeros_like(x)
    for k, amp in [(3, 0.5), (6, 0.3), (11, 0.2)]:
        fase = rng.random(4) * 6.28
        ruido += amp * (np.sin(x / R * k + fase[0]) * np.cos(y / R * k * 1.3 + fase[1]))
    a = np.clip(1 - r / (R * (1.0 + 0.18 * ruido)), 0, 1) ** 1.6
    return branco(a)

def risco_laser():
    # faixa com brilho: miolo forte e halo suave (para lasers)
    x, y = grade(); d = np.abs(y)
    a = np.clip(np.exp(-(d / 18.0) ** 2) * 0.55 + (d <= 6) * 0.45 + np.clip(1 - (d - 6) / 3, 0, 1) * (d > 6) * 0.45, 0, 1)
    return branco(a)

def mira_cruz():
    # anel com 4 marcas (mira pronta numa célula só)
    x, y = grade(); r = np.hypot(x, y)
    anel_ = (r <= R * 0.62) & (r >= R * 0.62 - 3.2)
    braco = ((np.abs(x) <= 1.8) & (np.abs(y) >= R * 0.30) & (np.abs(y) <= R * 0.98)) | ((np.abs(y) <= 1.8) & (np.abs(x) >= R * 0.30) & (np.abs(x) <= R * 0.98))
    return branco((anel_ | braco).astype(np.float32))

celulas = [disco(), brilho()] + [anel(t) for t in ANEIS] + [traco(), lasca(), moeda(), furo_madeira(), bolha(), faisca(), fumaca(), risco_laser()]
assert len(celulas) == 16, len(celulas)
atlas = np.zeros((C * 4, C * 4, 4), np.float32)
for i, c in enumerate(celulas):
    cx, cy = (i % 4) * C, (i // 4) * C
    atlas[cy:cy + C, cx:cx + C] = reduz(c)
# Cor sob o transparente = cor da forma (sem halo escuro nos mipmaps)
img = (np.clip(atlas, 0, 1) * 255 + 0.5).astype(np.uint8)
Image.fromarray(img, 'RGBA').save('sprites/pincel.png')
print('ok', img.shape)
