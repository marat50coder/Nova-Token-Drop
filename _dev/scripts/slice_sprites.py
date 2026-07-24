import os
import numpy as np
from PIL import Image
from scipy import ndimage

SRC = r"d:\flutter_proj\Nova_Token_Drop\assets"
OUT = r"d:\flutter_proj\Nova_Token_Drop\nova_token_drop\assets\sprites"

# sheet file -> (output category name, expected minimum sprite size fraction)
SHEETS = {
    "sphere_skins_asset.webp": "token",
    "Reactors_asset.webp": "reactor",
    "Magnetic_Devices_aset.webp": "magnet",
    "Reflectors_Mirrors_asset.webp": "reflector",
    "Gravity_Devices_asset.webp": "gravity",
    "Teleporters_asset.webp": "teleporter",
    "Interactive_Utility_Objects_asset.webp": "utility",
    "Energy Gates_Barriers_asset.webp": "gate",
    "boost_platform_asset.webp": "booster",
    "Decorative_Structural_Elements_asset.webp": "decor",
}


def slice_sheet(path, out_dir, alpha_thresh=30, min_area_frac=0.0008):
    im = Image.open(path).convert("RGBA")
    arr = np.array(im)
    alpha = arr[:, :, 3]
    mask = alpha > alpha_thresh

    # Close small gaps so a single object with thin glow stays connected
    mask_closed = ndimage.binary_closing(mask, structure=np.ones((5, 5)), iterations=2)
    labels, n = ndimage.label(mask_closed)
    total = im.width * im.height
    min_area = total * min_area_frac

    boxes = []
    for i in range(1, n + 1):
        ys, xs = np.where(labels == i)
        area = len(xs)
        if area < min_area:
            continue
        x0, x1 = xs.min(), xs.max()
        y0, y1 = ys.min(), ys.max()
        w = x1 - x0 + 1
        h = y1 - y0 + 1
        if w < 20 or h < 20:
            continue
        boxes.append((x0, y0, x1, y1))

    # sort into rows (group by y center), then by x
    boxes.sort(key=lambda b: (b[1], b[0]))
    rows = []
    for b in boxes:
        cy = (b[1] + b[3]) / 2
        placed = False
        for row in rows:
            ref = row[0]
            rcy = (ref[1] + ref[3]) / 2
            if abs(cy - rcy) < (ref[3] - ref[1]) * 0.6:
                row.append(b)
                placed = True
                break
        if not placed:
            rows.append([b])
    rows.sort(key=lambda r: min(bb[1] for bb in r))
    ordered = []
    for row in rows:
        row.sort(key=lambda b: b[0])
        ordered.extend(row)

    os.makedirs(out_dir, exist_ok=True)
    pad = 6
    for idx, (x0, y0, x1, y1) in enumerate(ordered):
        x0 = max(0, x0 - pad)
        y0 = max(0, y0 - pad)
        x1 = min(im.width - 1, x1 + pad)
        y1 = min(im.height - 1, y1 + pad)
        crop = im.crop((x0, y0, x1 + 1, y1 + 1))
        crop.save(os.path.join(out_dir, f"{idx}.png"))
    return len(ordered)


def main():
    for fname, cat in SHEETS.items():
        p = os.path.join(SRC, fname)
        out_dir = os.path.join(OUT, cat)
        count = slice_sheet(p, out_dir)
        print(f"{cat:12s} -> {count} sprites")


if __name__ == "__main__":
    main()
