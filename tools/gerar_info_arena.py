#!/usr/bin/env python3
"""Atualiza a arte de instruções da Arena (info_scenes/info_arena.png) para
a mecânica das cores (Rodada 11). Só redesenha o que mudou, por cima da
própria arte (pode rodar de novo, o resultado é o mesmo):

  subtítulo        "ACERTE AS LANTERNAS NA ORDEM DAS CORES!" e a ordem
                   1 AZUL > 2 VERDE > 3 AMARELO > 4 VERMELHO > 5 ROXO
  COMO FUNCIONA    as 5 lanternas acesas (sprites/arena_lanternas.png) e as
                   duas rodadas: MEMÓRIA e FIXA
  PONTUAÇÃO        5 acertos (20, 40, 60, 80, 100) com a borda na cor de
                   cada um; bônus da fixa (+50) e do acerto rápido (+10)

    python3 tools/gerar_info_arena.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARQ = os.path.join(RAIZ, "info_scenes", "info_arena.png")
F_EXTRA = os.path.join(RAIZ, "fonts", "Exo2-ExtraBold.ttf")
F_BOLD = os.path.join(RAIZ, "fonts", "Exo2-Bold.ttf")
LANTERNAS = os.path.join(RAIZ, "sprites", "arena_lanternas.png")

CORES = [(64, 158, 255), (64, 255, 90), (255, 220, 40), (255, 40, 28), (200, 82, 255)]
NOMES = ["AZUL", "VERDE", "AMARELO", "VERMELHO", "ROXO"]


def fonte(arq, tam):
    return ImageFont.truetype(arq, tam)


def limpar(im, caixa, x_esq, x_dir):
    """Apaga a caixa com o fundo da própria arte: para cada linha, mistura a
    cor das colunas de referência da esquerda e da direita."""
    a = np.asarray(im).astype(np.float32)
    x0, y0, x1, y1 = caixa
    for y in range(y0, y1):
        e = a[y, x_esq - 3:x_esq + 3].mean(0)
        d = a[y, x_dir - 3:x_dir + 3].mean(0)
        k = np.linspace(0, 1, x1 - x0)[:, None]
        a[y, x0:x1] = e * (1 - k) + d * k
    # um pouco de grão para não ficar liso demais
    g = np.random.default_rng(5).normal(0, 2.0, (y1 - y0, x1 - x0, 1))
    a[y0:y1, x0:x1, :3] += g
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), im.mode)


def texto_brilho(im, xy, txt, f, cor, ancora="mm", brilho=6, contorno=3):
    """Texto com brilho neon (cópia borrada por trás) e contorno escuro."""
    camada = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(camada)
    d.text(xy, txt, font=f, fill=cor + (255,), anchor=ancora)
    halo = camada.filter(ImageFilter.GaussianBlur(brilho))
    im.alpha_composite(halo)
    im.alpha_composite(halo)
    d2 = ImageDraw.Draw(im)
    d2.text(xy, txt, font=f, fill=(255, 255, 255, 255), anchor=ancora, stroke_width=contorno, stroke_fill=(10, 8, 12, 255))
    d2.text(xy, txt, font=f, fill=cor + (255,), anchor=ancora)


def texto(im, xy, txt, f, cor, ancora="mm", contorno=2):
    ImageDraw.Draw(im).text(xy, txt, font=f, fill=cor + (255,), anchor=ancora, stroke_width=contorno, stroke_fill=(5, 5, 8, 255))


def largura(f, txt):
    return f.getbbox(txt)[2] - f.getbbox(txt)[0]


def main():
    im = Image.open(ARQ).convert("RGBA")
    folha = Image.open(LANTERNAS).convert("RGBA")

    # ── subtítulo
    im = limpar(im, (118, 288, 1556, 402), 112, 1562)
    f1 = fonte(F_EXTRA, 50)
    texto(im, (836, 322), "ACERTE AS LANTERNAS NA ORDEM DAS CORES!", f1, (236, 238, 245), contorno=3)
    f2 = fonte(F_EXTRA, 34)
    partes = []
    for i, nome in enumerate(NOMES):
        partes.append(("%d %s" % (i + 1, nome), CORES[i]))
        if i < 4:
            partes.append((" › ", (200, 200, 210)))
    total = sum(largura(f2, p[0]) for p in partes)
    x = 836 - total / 2
    for txt, cor in partes:
        texto_brilho(im, (x, 374), txt, f2, cor, ancora="lm", brilho=5, contorno=2)
        x += largura(f2, txt)

    # ── COMO FUNCIONA
    im = limpar(im, (70, 468, 522, 748), 66, 526)
    tam = 84
    passo = 88
    x0 = 296 - passo * 2
    fn = fonte(F_EXTRA, 26)
    for i in range(5):
        q = folha.crop(((i + 1) * 369, 0, (i + 2) * 369, 358)).resize((tam, int(tam * 358 / 369)), Image.LANCZOS)
        cx = x0 + passo * i
        im.alpha_composite(q, (int(cx - tam / 2), 470))
        texto(im, (cx + 26, 548), str(i + 1), fn, CORES[i], contorno=3)
    fl = fonte(F_BOLD, 27)
    linhas = [
        [("MEMÓRIA: ", (90, 200, 255)), ("ACENDEM E APAGAM;", (235, 238, 245))],
        [("REPITA NA ORDEM DAS CORES.", (235, 238, 245))],
        [("FIXA: ", (255, 214, 60)), ("NASCEM ACESAS, UMA", (235, 238, 245))],
        [("A UMA; ACERTE NA ORDEM.", (235, 238, 245))],
    ]
    y = 600
    for linha in linhas:
        total = sum(largura(fl, t) for t, _ in linha)
        x = 296 - total / 2
        for t, cor in linha:
            texto(im, (x, y), t, fl, cor, ancora="lm")
            x += largura(fl, t)
        y += 38

    # ── PONTUAÇÃO: 5 acertos
    im = limpar(im, (566, 470, 1120, 750), 562, 1124)
    d = ImageDraw.Draw(im)
    w, h, gap = 98, 152, 9
    x = 843 - (5 * w + 4 * gap) / 2
    fp = fonte(F_BOLD, 18)
    fv = fonte(F_EXTRA, 50)
    fv3 = fonte(F_EXTRA, 42)
    for i in range(5):
        cor = CORES[i]
        caixa = [x, 478, x + w, 478 + h]
        brilho = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ImageDraw.Draw(brilho).rounded_rectangle(caixa, 12, outline=cor + (255,), width=5)
        im.alpha_composite(brilho.filter(ImageFilter.GaussianBlur(5)))
        d = ImageDraw.Draw(im)
        d.rounded_rectangle(caixa, 12, fill=(6, 10, 8, 235), outline=cor + (255,), width=2)
        texto(im, (x + w / 2, 500), "%dº ACERTO" % (i + 1), fp, (235, 238, 245), contorno=1)
        texto_brilho(im, (x + w / 2, 556), str(20 * (i + 1)), fv3 if i == 4 else fv, cor, brilho=4, contorno=2)
        texto(im, (x + w / 2, 608), "PONTOS", fp, (235, 238, 245), contorno=1)
        x += w + gap
    fb = fonte(F_BOLD, 30)
    for y, partes in ((672, [("FIXA COMPLETA: ", (235, 238, 245)), ("+50!", (120, 255, 120))]),
                      (714, [("ACERTO RÁPIDO NA FIXA: ", (235, 238, 245)), ("+10!", (120, 255, 120))])):
        total = sum(largura(fb, t) for t, _ in partes)
        x = 843 - total / 2
        for t, cor in partes:
            texto(im, (x, y), t, fb, cor, ancora="lm")
            x += largura(fb, t)

    im.convert("RGB").save(ARQ, optimize=True)
    print("info_arena.png atualizado")


if __name__ == "__main__":
    main()
