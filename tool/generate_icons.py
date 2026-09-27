"""Génère l'icône de SoliNova (étoile Nova sur fond émeraude).

    python tool/generate_icons.py

Produit les icônes classiques (mipmap-*) ; l'icône adaptative et l'écran
de lancement utilisent des ressources vectorielles (voir res/drawable).
"""

import math
import os

from PIL import Image, ImageDraw

RES = os.path.join(os.path.dirname(__file__), "..", "android", "app", "src", "main", "res")
SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
BG_CENTER = (18, 99, 79)
BG_EDGE = (7, 42, 34)
STAR = (226, 182, 89)


def star_points(cx, cy, r, waist=0.2):
    pts = []
    for i in range(8):
        a = -math.pi / 2 + i * math.pi / 4
        rr = r if i % 2 == 0 else r * waist
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return pts


def render(size):
    scale = 4  # suréchantillonnage pour l'anticrénelage
    s = size * scale
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    grad = Image.new("RGBA", (s, s))
    px = grad.load()
    for y in range(s):
        for x in range(s):
            d = min(1.0, math.hypot(x - s / 2, y - s * 0.42) / (s * 0.75))
            px[x, y] = tuple(int(BG_CENTER[i] + (BG_EDGE[i] - BG_CENTER[i]) * d) for i in range(3)) + (255,)
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, s - 1, s - 1), radius=s * 0.22, fill=255)
    img.paste(grad, (0, 0), mask)
    ImageDraw.Draw(img).polygon(star_points(s / 2, s / 2, s * 0.34), fill=STAR + (255,))
    return img.resize((size, size), Image.LANCZOS)


def main():
    for folder, size in SIZES.items():
        out = os.path.join(RES, f"mipmap-{folder}", "ic_launcher.png")
        render(size).save(out)
        print("écrit", out)


if __name__ == "__main__":
    main()
