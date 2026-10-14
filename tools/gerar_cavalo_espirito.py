#!/usr/bin/env python3
"""Cavalo-marinho espírito (sai do vaso quebrado no Mar).

Um cavalo-marinho feito de luz, como os espíritos dos jogos: corpo
translúcido (dá para ver a água atrás), a borda acesa, o miolo brilhando por
dentro, os anéis do corpo em linhas de luz, a barbatana das costas em leque de
raios, o olho vivo e chamas de luz (fitas finas) saindo da coroa, das costas e
da ponta do rabo. No jogo (scripts/mar_acerto.gd) ele ainda ganha um halo,
um segundo desenho somado (o brilho em volta), rastro de luz e, no fim, se
desfaz em faíscas.

Gera sprites/mar_cavalo.png (300x480, RGBA).

    python3 tools/gerar_cavalo_espirito.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as ndi

AQUI = os.path.dirname(os.path.abspath(__file__))
SPRITES = os.path.join(AQUI, "..", "sprites")
W, H, E = 300, 480, 4


def catmull(pts, n):
    """Curva suave pelos pontos (x, y, r)."""
    p = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = (np.array(p[j], np.float64) for j in (i - 1, i, i + 1, i + 2))
        for t in np.linspace(0, 1, n, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(np.array(pts[-1], np.float64))
    return out


def reduzir(img):
    return np.asarray(img.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255


def disco(d, x, y, r, fill=255):
    d.ellipse([(x - r) * E, (y - r) * E, (x + r) * E, (y + r) * E], fill=fill)


def main():
    # espinha: da cabeça ao rabo enrolado (x, y, raio)
    esp = [(166, 96, 33), (150, 134, 21), (150, 178, 33), (160, 228, 40), (154, 280, 33), (136, 322, 24),
           (118, 356, 17), (106, 388, 12.5), (108, 418, 9.5), (126, 436, 7.5), (147, 431, 6.2), (155, 411, 5.2),
           (145, 396, 4.4), (131, 401, 3.6), (131, 414, 2.8)]
    linha = catmull(esp, 18)
    corpo = Image.new("L", (W * E, H * E), 0)
    d = ImageDraw.Draw(corpo)
    for x, y, r in linha:
        disco(d, x, y, r)
    # focinho (tubo) e a boca
    for t in np.linspace(0, 1, 50):
        disco(d, 190 + 70 * t, 92 + 22 * t, 11.0 - 3.0 * t)
    disco(d, 262, 115, 9.0)
    # coroa (espinhos no alto da cabeça)
    for bx, by, ang, comp in [(146, 70, -0.65, 22), (160, 62, -0.2, 26), (176, 64, 0.25, 22), (188, 74, 0.7, 15)]:
        ponta = (bx + comp * np.sin(ang), by - comp * np.cos(ang))
        d.polygon([((bx - 7) * E, (by + 6) * E), (ponta[0] * E, ponta[1] * E), ((bx + 7) * E, (by + 6) * E)], fill=255)
    # espinhos das costas (lado esquerdo), pequenos e curvos
    for i in range(10, len(linha) - 70, 10):
        x, y, r = linha[i]
        x0, y0, _ = linha[i - 3]
        x1, y1, _ = linha[i + 3]
        tx, ty = x1 - x0, y1 - y0
        n = np.hypot(tx, ty) + 1e-6
        nx, ny = ty / n, -tx / n
        if nx > 0:
            nx, ny = -nx, -ny
        b = (x + nx * (r - 1), y + ny * (r - 1))
        p = (x + nx * (r + 10), y + ny * (r + 10) - 5)
        d.polygon([((b[0] - ty / n * 4.5) * E, (b[1] + tx / n * 4.5) * E), (p[0] * E, p[1] * E),
                   ((b[0] + ty / n * 4.5) * E, (b[1] - tx / n * 4.5) * E)], fill=255)
    m = reduzir(corpo)

    # barbatana das costas (leque de raios) e a do peito, pequena
    def leque(cx, cy, raio, a0, a1, nraios, ondula):
        f = Image.new("L", (W * E, H * E), 0)
        df = ImageDraw.Draw(f)
        pts = [(cx * E, cy * E)]
        for k in range(61):
            ang = np.radians(a0 + (a1 - a0) * k / 60)
            rr = raio * (0.9 + ondula * np.cos(k * 1.3))
            pts.append(((cx + np.cos(ang) * rr) * E, (cy - np.sin(ang) * rr) * E))
        df.polygon(pts, fill=255)
        r_img = Image.new("L", (W * E, H * E), 0)
        dr = ImageDraw.Draw(r_img)
        for k in range(nraios):
            ang = np.radians(a0 + 4 + (a1 - a0 - 8) * k / (nraios - 1))
            dr.line([(cx * E, cy * E), ((cx + np.cos(ang) * raio) * E, (cy - np.sin(ang) * raio) * E)], fill=255, width=int(1.4 * E))
        fm = reduzir(f)
        return fm, reduzir(r_img) * fm
    fin, fin_raios = leque(116, 232, 52, 112, 248, 13, 0.10)
    fin2, fin2_raios = leque(172, 150, 20, -70, 40, 6, 0.08)
    fin = np.maximum(fin, fin2)
    fin_raios = np.maximum(fin_raios, fin2_raios)
    fin = fin * (1 - m)
    fin_raios = fin_raios * (1 - m)

    # chamas de luz: fitas finas que saem da coroa, das costas e do rabo
    fitas = Image.new("L", (W * E, H * E), 0)
    df = ImageDraw.Draw(fitas)
    fitas_c = Image.new("L", (W * E, H * E), 0)
    dmiolo = ImageDraw.Draw(fitas_c)
    rng = np.random.default_rng(7)
    # ele sobe nadando: as chamas escorrem para trás e para baixo
    origens = [((160, 44), (-1.0, 0.30), 100), ((148, 54), (-1.0, 0.62), 90), ((176, 48), (-0.85, 0.15), 80),
               ((108, 206), (-1.0, 0.50), 80), ((100, 262), (-1.0, 0.70), 70), ((131, 414), (-1.0, 0.25), 60)]
    for (ox, oy), (dx, dy), comp in origens:
        fase = rng.uniform(0, np.pi * 2)
        pts = []
        for t in np.linspace(0, 1, 60):
            ox2 = ox + dx * comp * t + np.sin(t * 5.0 + fase) * 10 * t
            oy2 = oy + dy * comp * t + np.cos(t * 4.0 + fase) * 7 * t + 14 * t * t
            pts.append((ox2, oy2, t))
        for (x0, y0, t0), (x1, y1, t1) in zip(pts[:-1], pts[1:]):
            larg = max(1.0, (1 - t0) ** 0.7 * 11.0)
            a = int(255 * (1 - t0) ** 0.55)
            df.line([(x0 * E, y0 * E), (x1 * E, y1 * E)], fill=a, width=int(larg * E))
            dmiolo.line([(x0 * E, y0 * E), (x1 * E, y1 * E)], fill=a, width=int(max(1.0, larg * 0.3) * E))
    fitas_m = reduzir(fitas.filter(ImageFilter.GaussianBlur(E * 2.2))) * (1 - m)
    fitas_miolo = reduzir(fitas_c.filter(ImageFilter.GaussianBlur(E * 0.6))) * (1 - m)

    # volume de luz: borda acesa, miolo brilhando e o corpo redondo (luz de
    # cima e da esquerda)
    dist = ndi.distance_transform_edt(m > 0.5)
    borda = np.clip(1.0 - dist / 4.5, 0, 1) ** 1.5 * m
    miolo = np.clip(dist / 18.0, 0, 1) ** 0.9
    miolo = ndi.gaussian_filter(miolo, 2.5) * m
    alt = ndi.gaussian_filter(np.sqrt(np.clip(dist / 16.0, 0, 1)), 1.5)
    gy, gx = np.gradient(alt)
    nz = 0.30
    norma = np.sqrt(gx * gx + gy * gy + nz * nz)
    lambert = np.clip((gx * 0.55 + gy * 0.75 + nz * 0.55) / norma, 0, 1) * m
    reflexo = lambert ** 14 * m

    # anéis do corpo em linhas de luz
    aneis = Image.new("L", (W, H), 0)
    da = ImageDraw.Draw(aneis)
    for i in range(30, len(linha) - 40, 9):
        x, y, r = linha[i]
        x0, y0, _ = linha[i - 3]
        x1, y1, _ = linha[i + 3]
        tx, ty = x1 - x0, y1 - y0
        n = np.hypot(tx, ty) + 1e-6
        nx, ny = ty / n, -tx / n
        # arco levemente curvo (o anel em volta do corpo)
        arco = []
        for s in np.linspace(-0.95, 0.95, 16):
            curva = r * 0.30 * (1 - s * s)
            arco.append((x + nx * r * s + tx / n * curva, y + ny * r * s + ty / n * curva))
        da.line(arco, fill=255, width=1)
    aneis_m = np.asarray(aneis.filter(ImageFilter.GaussianBlur(0.7))).astype(np.float32) / 255 * m

    # veios de luz por dentro (ruído correndo)
    g = np.random.default_rng(11)
    veio = ndi.gaussian_filter(g.standard_normal((H, W)), 5.0)
    veio = np.clip(1.0 - np.abs(veio) / (veio.std() * 0.35), 0, 1) ** 3 * m

    # faíscas por dentro
    faisca = np.zeros((H, W), np.float32)
    ys, xs = np.where(m > 0.9)
    for k in g.choice(len(ys), 26, replace=False):
        faisca[ys[k], xs[k]] = 1.0
    faisca = np.clip(ndi.gaussian_filter(faisca, 1.1) * 18.0, 0, 1)

    fundo = np.array([0.02, 0.22, 0.46])
    agua = np.array([0.16, 0.78, 1.00])
    luz = np.array([0.82, 1.00, 1.00])
    lilas = np.array([0.80, 0.72, 1.00])
    k = np.clip(0.25 + 0.75 * lambert * 0.8 + 0.35 * miolo, 0, 1)
    cor = fundo[None, None] * (1 - k[..., None]) + agua[None, None] * k[..., None]
    cor = cor * (1 - borda[..., None] * 0.85) + luz[None, None] * borda[..., None] * 0.85
    cor += luz[None, None] * (aneis_m * 0.35 + veio * 0.22 + faisca * 0.8 + reflexo * 0.7)[..., None]
    alfa = np.clip(0.36 + 0.34 * k + 0.6 * borda + 0.25 * aneis_m + faisca + reflexo * 0.5, 0, 1) * m

    # barbatanas: véu claro com os raios acesos
    cor_fin = agua * 0.6 + luz * 0.4
    a_fin = np.clip(fin * 0.30 + fin_raios * 0.55, 0, 1)
    cor = cor * (1 - a_fin[..., None]) + cor_fin[None, None] * a_fin[..., None]
    alfa = alfa + a_fin * (1 - alfa)

    # chamas: azul-claro puxando para lilás, com o fio do meio aceso
    a_f = np.clip(fitas_m * 0.85 + fitas_miolo * 0.6, 0, 1)
    cor_f = (luz * 0.55 + lilas * 0.45)[None, None] * (1 - fitas_miolo[..., None]) + fitas_miolo[..., None]
    cor = cor * (1 - a_f[..., None]) + cor_f * a_f[..., None]
    alfa = alfa + a_f * (1 - alfa)
    # halo próprio em volta do corpo (o espírito brilha na água)
    halo = ndi.gaussian_filter(m, 7.0) * (1 - m)
    a_h = np.clip(halo * 0.55, 0, 1) * (1 - alfa)
    cor = (cor * alfa[..., None] + agua[None, None] * a_h[..., None]) / np.maximum(alfa + a_h, 1e-4)[..., None]
    alfa = alfa + a_h

    # olho vivo: íris escura com anel aceso e o brilho
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    ex, ey = 178.0, 90.0
    r_olho = np.hypot(xx - ex, yy - ey)
    anel = np.clip(1 - np.abs(r_olho - 7.0) / 2.0, 0, 1)
    iris = np.clip(1 - (r_olho - 5.5) / 1.2, 0, 1)
    brilho_olho = np.clip(1 - np.hypot(xx - ex + 2.2, yy - ey + 2.4) / 2.2, 0, 1)
    halo_olho = np.clip(1 - r_olho / 15.0, 0, 1) ** 2 * 0.5
    cor = cor * (1 - iris[..., None]) + np.array([0.02, 0.10, 0.20])[None, None] * iris[..., None]
    cor = cor + luz[None, None] * (anel * 0.9 + halo_olho)[..., None]
    cor = cor * (1 - brilho_olho[..., None]) + brilho_olho[..., None]
    alfa = np.maximum(alfa, np.maximum(iris, anel) * m)

    rgba = np.dstack([np.clip(cor, 0, 1), np.clip(alfa, 0, 1)])
    img = Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA")
    img.save(os.path.join(SPRITES, "mar_cavalo.png"), optimize=True)
    print("  mar_cavalo.png  %dx%d" % (W, H))


if __name__ == "__main__":
    main()
