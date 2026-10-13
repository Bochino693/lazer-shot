#!/usr/bin/env python3
"""Ícone oficial do LAZER SHOT (sem nada do Godot).

  sprites/icone_app.png              512x512, ícone do projeto e da janela
  sprites/icone_lazer_shot.png       432x432, frente do ícone adaptativo do
                                     Android (mira + nome dentro da área segura)
  sprites/icone_lazer_shot_fundo.png 432x432, fundo do ícone adaptativo
  sprites/icone_192.png              192x192, ícone comum do Android
  sprites/icone_lazer_shot_mono.png  432x432, ícone monocromático (temas do
                                     Android 13+; sem ele o Android usa o do Godot)
  ico/img_back.ico                   Windows (16 a 256)

    python3 tools/gerar_icone.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")
FONTE = os.path.join(RAIZ, "fonts", "Exo2-ExtraBold.ttf")
N = 1024                     # desenha grande e reduz (bordas lisas)
VERMELHO = (255, 38, 48)
VERMELHO_ESCURO = (120, 6, 12)


def fundo():
    yy, xx = (np.mgrid[0:N, 0:N] + 0.5) / N
    r = np.hypot(xx - 0.5, yy - 0.42)
    base = np.dstack([0.05 + 0.0 * r, 0.05 + 0.0 * r, 0.07 + 0.0 * r])
    brilho = np.exp(-(r / 0.38) ** 2)[..., None] * np.array([0.55, 0.04, 0.06])
    # linhas de "estande de tiro" no fundo, bem sutis
    linhas = (np.abs(((yy * 14) % 1.0) - 0.5) < 0.02)[..., None] * 0.035
    vinheta = np.clip(1.15 - r * 1.1, 0, 1)[..., None]
    img = np.clip((base + brilho + linhas) * vinheta, 0, 1)
    return Image.fromarray((img * 255).astype(np.uint8)).convert("RGBA")


def neon(desenho_fn, raio_brilho=18):
    """Desenha em camada própria e devolve camada + brilho vermelho."""
    camada = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    desenho_fn(ImageDraw.Draw(camada))
    a = camada.split()[3]
    brilho = Image.new("RGBA", (N, N), VERMELHO + (0,))
    brilho.putalpha(a.filter(ImageFilter.GaussianBlur(raio_brilho)).point(lambda v: min(255, int(v * 1.6))))
    return camada, brilho


def frente(escala_area=1.0, com_nome=True):
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    c = N / 2
    cy = N * (0.40 if com_nome else 0.5)
    R = N * 0.25 * escala_area

    def mira(d):
        w = int(N * 0.028 * escala_area)
        d.ellipse([c - R, cy - R, c + R, cy + R], outline=VERMELHO + (255,), width=w)
        r2 = R * 0.55
        d.ellipse([c - r2, cy - r2, c + r2, cy + r2], outline=(255, 255, 255, 235), width=int(w * 0.6))
        g = R * 1.32
        for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
            d.line([(c + dx * R * 0.72, cy + dy * R * 0.72), (c + dx * g, cy + dy * g)], fill=VERMELHO + (255,), width=w)
        pr = R * 0.11
        d.ellipse([c - pr, cy - pr, c + pr, cy + pr], fill=(255, 255, 255, 255))

    camada, brilho = neon(mira, int(22 * escala_area))
    img.alpha_composite(brilho)
    img.alpha_composite(brilho)
    img.alpha_composite(camada)
    # feixe de laser cruzando até o centro
    feixe = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    fd = ImageDraw.Draw(feixe)
    fd.line([(c + R * 2.2, cy + R * 1.9), (c + R * 0.12, cy + R * 0.1)], fill=(255, 90, 90, 255), width=int(N * 0.012 * escala_area))
    img.alpha_composite(Image.composite(Image.new("RGBA", (N, N), VERMELHO + (255,)), Image.new("RGBA", (N, N), (0, 0, 0, 0)),
                                        feixe.split()[3].filter(ImageFilter.GaussianBlur(14))))
    img.alpha_composite(feixe)
    if com_nome:
        f1 = ImageFont.truetype(FONTE, int(N * 0.155 * escala_area))
        f2 = ImageFont.truetype(FONTE, int(N * 0.205 * escala_area))
        d = ImageDraw.Draw(img)
        for texto, fonte, y, cor in [("LAZER", f1, N * 0.66, (240, 240, 245, 255)), ("SHOT", f2, N * 0.66 + N * 0.15 * escala_area, VERMELHO + (255,))]:
            caixa = d.textbbox((0, 0), texto, font=fonte)
            x = c - (caixa[2] - caixa[0]) / 2 - caixa[0]
            yy = y - caixa[1]
            sombra = Image.new("RGBA", (N, N), (0, 0, 0, 0))
            ImageDraw.Draw(sombra).text((x, yy + N * 0.008), texto, font=fonte, fill=(0, 0, 0, 220), stroke_width=int(N * 0.012), stroke_fill=(0, 0, 0, 220))
            img.alpha_composite(sombra.filter(ImageFilter.GaussianBlur(6)))
            d.text((x, yy), texto, font=fonte, fill=cor, stroke_width=int(N * 0.006), stroke_fill=VERMELHO_ESCURO + (255,))
    return img


def monocromo(escala_area=0.66):
    """Só a silhueta branca da mira com o feixe (o sistema pinta a cor)."""
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = cy = N / 2
    R = N * 0.25 * escala_area
    w = int(N * 0.04 * escala_area)
    branco = (255, 255, 255, 255)
    d.ellipse([c - R, cy - R, c + R, cy + R], outline=branco, width=w)
    r2 = R * 0.55
    d.ellipse([c - r2, cy - r2, c + r2, cy + r2], outline=branco, width=int(w * 0.7))
    g = R * 1.32
    for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
        d.line([(c + dx * R * 0.72, cy + dy * R * 0.72), (c + dx * g, cy + dy * g)], fill=branco, width=w)
    pr = R * 0.14
    d.ellipse([c - pr, cy - pr, c + pr, cy + pr], fill=branco)
    d.line([(c + R * 1.75, cy + R * 1.5), (c + R * 0.2, cy + R * 0.17)], fill=branco, width=int(w * 0.5))
    return img


def cantos(img, raio):
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], raio, fill=255)
    out = img.copy()
    out.putalpha(Image.composite(img.split()[3], Image.new("L", img.size, 0), m))
    return out


def main():
    bg = fundo()
    completo = bg.copy()
    completo.alpha_composite(frente())
    app = cantos(completo, int(N * 0.18))
    app.resize((512, 512), Image.LANCZOS).save(os.path.join(SP, "icone_app.png"))
    app.resize((192, 192), Image.LANCZOS).save(os.path.join(SP, "icone_192.png"))
    # adaptativo: a frente cabe na área segura (círculo de 66% do centro)
    frente_ad = frente(escala_area=0.66)
    frente_ad.resize((432, 432), Image.LANCZOS).save(os.path.join(SP, "icone_lazer_shot.png"))
    bg.resize((432, 432), Image.LANCZOS).save(os.path.join(SP, "icone_lazer_shot_fundo.png"))
    monocromo().resize((432, 432), Image.LANCZOS).save(os.path.join(SP, "icone_lazer_shot_mono.png"))
    os.makedirs(os.path.join(RAIZ, "ico"), exist_ok=True)
    app.save(os.path.join(RAIZ, "ico", "img_back.ico"), sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print("ícones gerados")


if __name__ == "__main__":
    main()
