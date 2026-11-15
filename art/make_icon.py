import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

src, out_dir = sys.argv[1], sys.argv[2]
img = Image.open(src).convert("RGB")
a = np.asarray(img).astype(int)

lo, hi = a.min(axis=2), a.max(axis=2)
# Background is light, near-neutral beige; the bag's light parts (scroll, steel) sit inside a dark outline.
cand = (lo >= 150) & (hi - lo <= 35)

labels, n = ndimage.label(cand)
border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
bg_mean = a[labels == next(iter(border))].mean(axis=0)
bg = np.isin(labels, list(border))
# Gaps enclosed by straps are background too, but aren't reachable from the border.
sizes = ndimage.sum(np.ones_like(labels), labels, range(1, n + 1))
for i, size in enumerate(sizes, start=1):
    if i in border or size < 1500:
        continue
    if np.abs(a[labels == i].mean(axis=0) - bg_mean).max() < 20:
        bg |= labels == i

fg = ~bg
fg = ndimage.binary_opening(fg, iterations=2)
# Keep only the largest blob so stray pattern specks don't survive.
lab, _ = ndimage.label(fg)
counts = np.bincount(lab.ravel()); counts[0] = 0
fg = lab == counts.argmax()
fg = ndimage.binary_fill_holes(fg) & ~bg | (lab == counts.argmax())
# Eat the 1px beige fringe left by anti-aliasing against the old background.
fg = ndimage.binary_erosion(fg, iterations=2)

alpha = Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
rgba = img.copy(); rgba.putalpha(alpha)

ys, xs = np.where(fg)
x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
side = int(max(x1 - x0, y1 - y0) * 1.06)
cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
box = (cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)
square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
square.paste(rgba.crop(box), (0, 0))

square.resize((400, 400), Image.LANCZOS).save(f"{out_dir}/curseforge-avatar.png")
square.resize((256, 256), Image.LANCZOS).save(f"{out_dir}/Icon256.png")
icon = square.resize((64, 64), Image.LANCZOS)
icon.save(f"{out_dir}/Icon.tga")

# Preview on dark/light/checker backgrounds to spot halos.
prev = Image.new("RGBA", (400 * 3 + 64 * 2 + 40, 400), (0, 0, 0, 255))
big = square.resize((400, 400), Image.LANCZOS)
for i, col in enumerate([(20, 20, 24, 255), (245, 240, 230, 255), (90, 60, 120, 255)]):
    tile = Image.new("RGBA", (400, 400), col); tile.alpha_composite(big); prev.paste(tile, (i * 400, 0))
for j, col in enumerate([(20, 20, 24, 255), (245, 240, 230, 255)]):
    t = Image.new("RGBA", (64, 64), col); t.alpha_composite(icon); prev.paste(t, (1200 + 20 + j * 74, 168))
prev.save(f"{out_dir}/preview.png")
print("bbox", box, "side", side)
