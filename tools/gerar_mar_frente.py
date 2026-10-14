#!/usr/bin/env python3
"""Camada da frente do Mar (2,5D): o que fica entre o jogador e a cena.

Gera (em sprites/):
  mar_frente_alga.png    uma folha de alga escura, desfocada (bem perto da
                         "câmera"); o jogo põe várias nos cantos de baixo,
                         balançando, e a camada anda ao contrário do fundo
                         quando a mira se mexe (paralaxe)
  mar_frente_peixe.png   silhueta de um peixe grande, desfocada, que às vezes
                         passa na frente de tudo

Uso:
    python3 tools/gerar_mar_frente.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

AQUI = os.path.dirname(os.path.abspath(__file__))
SPRITES = os.path.join(AQUI, "..", "sprites")
rng = np.random.default_rng(16)

# quase preto esverdeado, como a água bem perto e contra a luz
COR = (12, 40, 48)
COR_BORDA = (78, 160, 172)   # um fio de luz azulada de cima, na borda


def gravar(im, nome):
    caminho = os.path.join(SPRITES, nome)
    im.save(caminho, optimize=True)
    print(f"  {nome:30s} {im.size[0]}x{im.size[1]}")


def alga():
    """Touceira de alga: quatro fitas largas e onduladas saindo de um pé só,
    escuras, com um fio de luz azulada na borda (assim ela aparece tanto na
    água clara quanto na frente das pedras escuras) e fora de foco."""
    W, H, E = 300, 820, 3                # desenhado em 3x e reduzido
    w, h = W * E, H * E
    corpo = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(corpo)
    base_x = w * 0.5
    fitas = [(-0.30, 1.00, 0.0, 1.00), (0.24, 0.90, 1.7, 0.90), (-0.06, 0.78, 3.1, 0.95), (0.40, 0.58, 4.4, 0.75),
             (-0.42, 0.55, 5.6, 0.70)]
    for incl, alto, fase, larg_k in fitas:
        n = 90
        meio = []
        for i in range(n + 1):
            t = i / n
            y = h * (1 - t * alto * 0.97)
            x = base_x + incl * w * t ** 0.8 + np.sin(t * 4.6 + fase) * w * 0.09 * t
            meio.append((x, y))
        lado_a, lado_b = [], []
        for i in range(n + 1):
            t = i / n
            x0, y0 = meio[max(i - 1, 0)]
            x1, y1 = meio[min(i + 1, n)]
            dx, dy = x1 - x0, y1 - y0
            norma = max(np.hypot(dx, dy), 1e-6)
            nx, ny = -dy / norma, dx / norma
            # fita larga no meio, fina no pé e pontuda na ponta; borda ondulada
            larg = w * 0.12 * larg_k * (np.sin(np.pi * min(t * 1.15, 1.0)) ** 0.6 + 0.12) * (1 + 0.12 * np.sin(t * 31 + fase))
            x, y = meio[i]
            lado_a.append((x + nx * larg * 0.5, y + ny * larg * 0.5))
            lado_b.append((x - nx * larg * 0.5, y - ny * larg * 0.5))
        d.polygon(lado_a + lado_b[::-1], fill=255)
    corpo = corpo.resize((W, H), Image.LANCZOS)
    # bem perto: fora de foco
    corpo = corpo.filter(ImageFilter.GaussianBlur(2.6))
    m = np.asarray(corpo).astype(np.float32) / 255
    # fio de luz: a borda (onde a cobertura cai), mais forte do lado de cima-esquerda
    dentro = np.asarray(corpo.filter(ImageFilter.GaussianBlur(4))).astype(np.float32) / 255
    borda = np.clip((m - dentro * 0.75) * 3.0, 0, 1) * np.clip(m * 2.0, 0, 1)
    esq = np.clip(m - np.roll(m, 4, axis=1), 0, 1) * 1.2
    luz = np.clip(borda * 0.4 + esq, 0, 1) * m * m * 0.85
    luz = luz[..., None] * np.linspace(1.0, 0.35, H)[:, None, None]
    cor = np.array(COR, np.float32) * (1 - luz) + np.array(COR_BORDA, np.float32) * luz
    # mais escura embaixo (mais perto, mais sombra)
    cor *= np.linspace(1.2, 0.7, H)[:, None, None]
    rgba = np.dstack([np.clip(cor, 0, 255), np.clip(m * 238, 0, 255)[..., None]]).astype(np.uint8)
    gravar(Image.fromarray(rgba, "RGBA"), "mar_frente_alga.png")


def peixe():
    """Silhueta de um peixe grande (garoupa) nadando para a direita."""
    W, H, E = 520, 230, 3
    w, h = W * E, H * E
    a = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(a)
    cy = h * 0.52
    # corpo: fuso com a cabeça à direita
    cima, baixo = [], []
    for j in range(61):
        u = j / 60
        x = w * (0.16 + 0.80 * u)
        meia = h * 0.30 * (np.sin(np.pi * (u ** 0.8)) ** 0.85) + h * 0.02
        cima.append((x, cy - meia * 1.05))
        baixo.append((x, cy + meia * 0.9))
    d.polygon(cima + baixo[::-1], fill=255)
    # cauda em leque
    d.polygon([(w * 0.19, cy - h * 0.05), (w * 0.02, cy - h * 0.33), (w * 0.06, cy),
               (w * 0.02, cy + h * 0.31), (w * 0.19, cy + h * 0.05)], fill=255)
    # nadadeiras: dorsal, anal e peitoral
    d.polygon([(w * 0.34, cy - h * 0.26), (w * 0.47, cy - h * 0.45), (w * 0.66, cy - h * 0.30)], fill=255)
    d.polygon([(w * 0.36, cy + h * 0.22), (w * 0.44, cy + h * 0.38), (w * 0.55, cy + h * 0.24)], fill=255)
    d.polygon([(w * 0.70, cy + h * 0.06), (w * 0.62, cy + h * 0.24), (w * 0.76, cy + h * 0.12)], fill=255)
    a = a.resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(3.5))
    m = np.asarray(a).astype(np.float32) / 255
    cor = np.array(COR, np.float32) * np.ones((H, W, 1), np.float32)
    # o dorso pega um pouco da luz de cima
    cor += np.array([18, 40, 42], np.float32) * np.clip(np.linspace(1.0, -0.2, H), 0, 1)[:, None, None]
    rgba = np.dstack([np.clip(cor, 0, 255), np.clip(m * 230, 0, 255)[..., None]]).astype(np.uint8)
    gravar(Image.fromarray(rgba, "RGBA"), "mar_frente_peixe.png")


if __name__ == "__main__":
    alga()
    peixe()
