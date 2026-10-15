"""Preenche um buraco numa pintura com pedaços dela mesma (Rodada 28).

O jeito do "preenchimento inteligente" dos editores de imagem: para cada
quadradinho 7x7 que toca o buraco, acha o quadradinho mais parecido no resto
da imagem (PatchMatch: chutes ao acaso, o achado do vizinho passado adiante e
buscas cada vez mais perto) e cada pixel do buraco vira a média dos
quadradinhos que o cobrem (votação). Começa com a imagem encolhida 16x (onde
o buraco é pequeno e acha a forma geral) e vai dobrando até o tamanho cheio,
refazendo com os pixels nítidos de cada tamanho: o buraco sai com a textura
de verdade (água, pedra, areia), não com um borrão.

  zonas        cada pixel do buraco só copia da sua zona de fonte (no Mar: o
               que fica acima do chão copia água e penhasco; o chão copia só
               areia e água clara)
  repetição    a fonte já usada em vários lugares fica mais cara (não aparece
               a mesma pedrinha cinco vezes)
  poisson()    no fim a cor do buraco encosta na de fora sem emenda: os
               detalhes do preenchimento com o tom da borda
"""
import numpy as np
import cv2


def _encolher_img(img):
    h, w = img.shape[0] // 2, img.shape[1] // 2
    return cv2.resize(cv2.GaussianBlur(img, (0, 0), 0.85), (w, h), interpolation=cv2.INTER_AREA)


def _encolher_ou(m):
    v = m[:m.shape[0] // 2 * 2, :m.shape[1] // 2 * 2]
    return v[0::2, 0::2] | v[1::2, 0::2] | v[0::2, 1::2] | v[1::2, 1::2]


def _encolher_e(m):
    v = m[:m.shape[0] // 2 * 2, :m.shape[1] // 2 * 2]
    return v[0::2, 0::2] & v[1::2, 0::2] & v[0::2, 1::2] & v[1::2, 1::2]


class _Nivel:
    """Um tamanho da pirâmide: a imagem, os alvos e o mapa alvo -> fonte."""

    def __init__(self, img, buraco, fonte, zona_alvo, zonas_fonte, r):
        self.img = img.astype(np.float32).copy()
        self.H, self.W = buraco.shape
        self.buraco = buraco
        self.r = r
        q = np.ones((2 * r + 1, 2 * r + 1), np.uint8)
        # centro de fonte: o quadradinho inteiro dentro da fonte e da imagem
        ok = cv2.erode(fonte.astype(np.uint8), q, borderType=cv2.BORDER_CONSTANT, borderValue=0).astype(bool)
        ok[:r] = False; ok[-r:] = False; ok[:, :r] = False; ok[:, -r:] = False
        zs = [ok & z for z in zonas_fonte]
        todas = np.logical_or.reduce(zs)
        # zona sem fonte bastante neste tamanho: vale qualquer uma
        self.zonas_ok = np.stack([z if z.sum() >= 60 else todas for z in zs])
        # alvos: centros cujo quadradinho toca o buraco
        alvo = cv2.dilate(buraco.astype(np.uint8), q).astype(bool)
        alvo[:r] = False; alvo[-r:] = False; alvo[:, :r] = False; alvo[:, -r:] = False
        self.ty, self.tx = np.nonzero(alvo)
        self.tz = zona_alvo[self.ty, self.tx].astype(np.int32)
        self.n = self.ty.size
        d = np.arange(-r, r + 1)
        self.dy, self.dx = [a.ravel() for a in np.meshgrid(d, d, indexing="ij")]
        # perto da borda o quadradinho vale mais (lá a cópia é mais certa)
        self.dist = cv2.distanceTransform(buraco.astype(np.uint8), cv2.DIST_L2, 5)
        self.ocup = None
        self.lam = 0.0

    def valido(self, sy, sx):
        dentro = (sy >= 0) & (sy < self.H) & (sx >= 0) & (sx < self.W)
        return dentro & self.zonas_ok[self.tz, np.clip(sy, 0, self.H - 1), np.clip(sx, 0, self.W - 1)]

    def _guardar_alvos(self):
        plano = self.img.reshape(-1, 3)
        self.t_vals = np.empty((self.dy.size, self.n, 3), np.float32)
        for i, (a, b) in enumerate(zip(self.dy, self.dx)):
            self.t_vals[i] = plano[(self.ty + a) * self.W + (self.tx + b)]

    def custo(self, sy, sx):
        plano = self.img.reshape(-1, 3)
        base = sy * self.W + sx
        acc = np.zeros(self.n, np.float32)
        for i, (a, b) in enumerate(zip(self.dy, self.dx)):
            v = plano[base + (a * self.W + b)] - self.t_vals[i]
            acc += np.einsum("ij,ij->i", v, v)
        if self.ocup is not None:
            acc += self.lam * self.ocup.ravel()[base]
        return acc

    def ao_acaso(self, rng):
        sy = np.zeros(self.n, np.int64)
        sx = np.zeros(self.n, np.int64)
        for z in range(self.zonas_ok.shape[0]):
            idx = np.nonzero(self.tz == z)[0]
            if idx.size == 0:
                continue
            vy, vx = np.nonzero(self.zonas_ok[z])
            if vy.size == 0:
                raise RuntimeError("zona %d sem fonte" % z)
            j = rng.integers(0, vy.size, idx.size)
            sy[idx] = vy[j]
            sx[idx] = vx[j]
        return sy, sx

    def _tentar(self, sy, sx, D, cy, cx, v):
        cy = np.where(v, cy, sy)
        cx = np.where(v, cx, sx)
        Dn = self.custo(cy, cx)
        m = v & (Dn < D)
        return np.where(m, cy, sy), np.where(m, cx, sx), np.where(m, Dn, D)

    def patchmatch(self, sy, sx, voltas, rng):
        self._guardar_alvos()
        D = self.custo(sy, sx)
        mapa = -np.ones((self.H, self.W), np.int64)
        mapa[self.ty, self.tx] = np.arange(self.n)
        for _ in range(voltas):
            # o achado do vizinho (a 8, 4, 2 e 1 px) passado adiante
            for passo in (8, 4, 2, 1):
                for ey, ex in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                    ny, nx = self.ty + ey * passo, self.tx + ex * passo
                    ok = (ny >= 0) & (ny < self.H) & (nx >= 0) & (nx < self.W)
                    j = np.where(ok, mapa[np.clip(ny, 0, self.H - 1), np.clip(nx, 0, self.W - 1)], -1)
                    tem = j >= 0
                    cy = sy[np.maximum(j, 0)] - ey * passo
                    cx = sx[np.maximum(j, 0)] - ex * passo
                    sy, sx, D = self._tentar(sy, sx, D, cy, cx, tem & self.valido(cy, cx))
            # busca em volta do achado, cada vez mais perto
            R = max(self.H, self.W)
            while R >= 1:
                cy = sy + np.round(rng.uniform(-1, 1, self.n) * R).astype(np.int64)
                cx = sx + np.round(rng.uniform(-1, 1, self.n) * R).astype(np.int64)
                sy, sx, D = self._tentar(sy, sx, D, cy, cx, self.valido(cy, cx))
                R //= 2
        return sy, sx, D

    def votar(self, sy, sx, D, gama=1.3):
        if self.ocup is not None:
            D = np.maximum(D - self.lam * self.ocup.ravel()[sy * self.W + sx], 0)
        Dn = D / self.dy.size
        s2 = max(float(np.percentile(Dn, 75)), 1e-6)
        w = np.exp(-Dn / (2 * s2)).astype(np.float32)
        acc = np.zeros((self.H * self.W, 3), np.float64)
        pes = np.zeros(self.H * self.W, np.float64)
        plano = self.img.reshape(-1, 3)
        dist = self.dist.ravel()
        for a, b in zip(self.dy, self.dx):
            # com o deslocamento fixo cada alvo cai num pixel diferente
            q = (self.ty + a) * self.W + (self.tx + b)
            wq = w * np.power(gama, -dist[q])
            pes[q] += wq
            acc[q] += plano[(sy + a) * self.W + (sx + b)] * wq[:, None]
        novo = plano.copy()
        tem = self.buraco.ravel() & (pes > 0)
        novo[tem] = (acc[tem] / pes[tem, None]).astype(np.float32)
        self.img = novo.reshape(self.H, self.W, 3)

    def contar_uso(self, sy, sx, D):
        o = np.zeros(self.H * self.W, np.float32)
        np.add.at(o, sy * self.W + sx, 1.0)
        o = cv2.GaussianBlur(o.reshape(self.H, self.W), (0, 0), 1.0)
        # a cópia de um pedaço inteiro usa cada fonte ~1 vez; o mesmo pedaço
        # em vários lugares passa disso e fica mais caro
        self.ocup = np.maximum(o - 1.0, 0.0)
        self.lam = float(np.median(D)) * 0.12


def completar(img, buraco, fonte, zona_alvo, zonas_fonte, niveis=5, r_fino=3, r_grosso=2,
              em=(12, 8, 6, 4, 3), voltas=(4, 3, 3, 2, 2), semente=7, log=print):
    """img: float32 HxWx3 (0..1). buraco: bool, o que refazer. fonte: bool, de
    onde pode copiar. zona_alvo: int HxW, a zona de cada pixel do buraco.
    zonas_fonte: [bool HxW], de onde cada zona copia. Devolve a imagem com o
    buraco preenchido (o resto igual)."""
    rng = np.random.default_rng(semente)
    pir = [(img.astype(np.float32), buraco, fonte, zona_alvo, zonas_fonte)]
    for _ in range(niveis - 1):
        im, b, f, za, zf = pir[-1]
        h, w = im.shape[0] // 2, im.shape[1] // 2
        pir.append((_encolher_img(im), _encolher_ou(b), _encolher_e(f),
                    za[0::2, 0::2][:h, :w], [_encolher_e(z) for z in zf]))
    ant = None
    for L in range(niveis - 1, -1, -1):
        im, b, f, za, zf = pir[L]
        nv = _Nivel(im, b, f & ~b, za, zf, r_fino if L <= 1 else r_grosso)
        i = min(niveis - 1 - L, len(em) - 1)
        if ant is None:
            # o menor: o buraco com a cor da borda escorrida e cópias ao acaso
            u8 = np.clip(im * 255, 0, 255).astype(np.uint8)
            ini = cv2.inpaint(u8, b.astype(np.uint8), 5, cv2.INPAINT_TELEA).astype(np.float32) / 255
            nv.img[b] = ini[b]
            sy, sx = nv.ao_acaso(rng)
        else:
            # o mapa do tamanho de cima, dobrado, e a imagem refeita com os
            # pixels deste tamanho
            asy, asx, aty, atx, aH, aW = ant
            mapa = -np.ones((aH, aW), np.int64)
            mapa[aty, atx] = np.arange(aty.size)
            j = mapa[np.clip(nv.ty // 2, 0, aH - 1), np.clip(nv.tx // 2, 0, aW - 1)]
            sy, sx = nv.ao_acaso(rng)
            cy = asy[np.maximum(j, 0)] * 2 + nv.ty % 2
            cx = asx[np.maximum(j, 0)] * 2 + nv.tx % 2
            v = (j >= 0) & nv.valido(cy, cx)
            sy = np.where(v, cy, sy)
            sx = np.where(v, cx, sx)
            nv.votar(sy, sx, np.zeros(nv.n, np.float32))
        for _ in range(em[i]):
            sy, sx, D = nv.patchmatch(sy, sx, voltas[i], rng)
            nv.votar(sy, sx, D)
            nv.contar_uso(sy, sx, D)
        log("  tamanho 1/%d (%dx%d, %d quadradinhos)" % (2 ** L, nv.W, nv.H, nv.n))
        ant = (sy, sx, nv.ty, nv.tx, nv.H, nv.W)
    return nv.img


def poisson(preenchida, base, buraco):
    """Dentro do buraco ficam as diferenças entre vizinhos de `preenchida` (os
    detalhes); na borda, os valores de `base`. Resolve o resto (Poisson): o
    preenchimento pega o tom de fora sem emenda e sem perder a textura."""
    import scipy.sparse as sp
    import scipy.sparse.linalg as sla
    m = buraco.copy()
    m[0] = m[-1] = False
    m[:, 0] = m[:, -1] = False
    idx = -np.ones(m.shape, np.int64)
    ys, xs = np.nonzero(m)
    n = ys.size
    idx[ys, xs] = np.arange(n)
    linhas, cols, vals = [np.arange(n)], [np.arange(n)], [np.full(n, 4.0)]
    b = np.zeros((n, 3), np.float64)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        ny, nx = ys + dy, xs + dx
        j = idx[ny, nx]
        dentro = j >= 0
        linhas.append(np.nonzero(dentro)[0])
        cols.append(j[dentro])
        vals.append(-np.ones(int(dentro.sum())))
        b += preenchida[ys, xs] - preenchida[ny, nx]
        b[~dentro] += base[ny[~dentro], nx[~dentro]]
    A = sp.csr_matrix((np.concatenate(vals), (np.concatenate(linhas), np.concatenate(cols))), shape=(n, n))
    out = base.astype(np.float32).copy()
    for c in range(3):
        x, _ = sla.cg(A, b[:, c], x0=preenchida[ys, xs, c].astype(np.float64), rtol=1e-6, maxiter=4000)
        out[ys, xs, c] = x
    return out
