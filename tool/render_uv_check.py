#!/usr/bin/env python3
"""Software preview of a vehicle model's paint, textured with a wrap template.

This is a development aid, not part of the app: it renders the painted body of
a GLB with the template's UV atlas applied, so the baked texture coordinates
can be checked without a browser. Four views are written next to each other:
three-quarter, left side, top and front.

    python3 tool/render_uv_check.py model3 --template model3/template.png \\
        --glb web/models/tesla_m3_model.glb --out /tmp/check.png

Requires numpy (pip install numpy).
"""

import argparse
import json
import math
import struct
import sys

import numpy as np


def read_glb(path):
    """Returns ``(json, bin)`` for a GLB file."""
    data = open(path, "rb").read()
    magic, version, _ = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67 or version != 2:
        raise SystemExit(f"{path} is not a GLB 2.0 file")

    offset = 12
    doc = None
    blob = b""
    while offset + 8 <= len(data):
        length, kind = struct.unpack_from("<II", data, offset)
        chunk = data[offset + 8:offset + 8 + length]
        if kind == 0x4E4F534A:
            doc = json.loads(chunk.decode("utf-8").rstrip("\x00 "))
        elif kind == 0x004E4942:
            blob = chunk
        offset += 8 + length + ((4 - length % 4) % 4)
    return doc, blob


COMPONENTS = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2),
              5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_accessor(doc, blob, index):
    """Reads an accessor into a numpy array, honouring byteStride."""
    accessor = doc["accessors"][index]
    view = doc["bufferViews"][accessor["bufferView"]]
    fmt, size = COMPONENTS[accessor["componentType"]]
    width = WIDTH[accessor["type"]]
    count = accessor["count"]

    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    stride = view.get("byteStride") or size * width
    raw = np.frombuffer(blob, dtype=np.uint8, count=stride * count - (stride - size * width), offset=start)
    raw = raw.reshape(count, stride)[:, :size * width]
    values = raw.copy().view(np.dtype(fmt).newbyteorder("<")).reshape(count, width)
    return values.astype(np.float64) if fmt == "f" else values


def quaternion_matrix(q):
    x, y, z, w = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w), 0],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w), 0],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y), 0],
        [0, 0, 0, 1],
    ], dtype=np.float64)


def node_matrix(node):
    if "matrix" in node:
        return np.array(node["matrix"], dtype=np.float64).reshape(4, 4).T
    matrix = np.eye(4)
    if "scale" in node:
        matrix = np.diag(list(node["scale"]) + [1.0]) @ matrix
    if "rotation" in node:
        matrix = quaternion_matrix(node["rotation"]) @ matrix
    if "translation" in node:
        matrix[:3, 3] = node["translation"]
    return matrix


def scene_triangles(doc, blob, material_names):
    """Returns positions, normals, uvs and material per triangle of the scene."""
    triangles = []
    for mesh in doc["meshes"]:
        for primitive in mesh["primitives"]:
            material = primitive.get("material", -1)
            name = (doc["materials"][material].get("name") or "") if material >= 0 else ""
            if material_names and name not in material_names:
                continue

            attributes = primitive["attributes"]
            positions = read_accessor(doc, blob, attributes["POSITION"])
            normals = (read_accessor(doc, blob, attributes["NORMAL"])
                       if "NORMAL" in attributes else None)
            uvs = (read_accessor(doc, blob, attributes["TEXCOORD_0"])
                   if "TEXCOORD_0" in attributes else None)
            if "indices" in primitive:
                indices = read_accessor(doc, blob, primitive["indices"]).reshape(-1)
            else:
                indices = np.arange(len(positions))

            triangles.append((positions, normals, uvs, indices, name))
    return triangles


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("folder", help="template folder, used for the title only")
    parser.add_argument("--glb", required=True)
    parser.add_argument("--template", required=True)
    parser.add_argument("--out", default="/tmp/uv_check.png")
    parser.add_argument("--materials", nargs="*", default=None,
                        help="material names to draw (default: every primitive)")
    parser.add_argument("--size", type=int, default=420)
    args = parser.parse_args(argv)

    from PIL import Image, ImageDraw

    doc, blob = read_glb(args.glb)
    groups = scene_triangles(doc, blob, args.materials)

    texture = Image.open(args.template).convert("RGBA")

    all_positions = np.vstack([g[0] for g in groups])
    low = all_positions.min(axis=0)
    high = all_positions.max(axis=0)
    center = (low + high) / 2
    extent = high - low
    scale = max(extent)

    views = [
        ("3/4", (0.9, 0.75, 0.9)),
        ("side +Z", (0.0, 0.15, 1.0)),
        ("top", (0.0, 1.0, 0.001)),
        ("front", (1.0, 0.2, 0.0)),
        ("side -Z", (0.0, 0.15, -1.0)),
        ("back", (-1.0, 0.2, 0.0)),
    ]

    columns = 3
    rows = 2
    sheet = Image.new("RGB", (args.size * columns, args.size * rows), (18, 18, 20))

    for index, (label, direction) in enumerate(views):
        eye = center + np.array(direction) * scale * 2.2
        look = center - eye
        look /= np.linalg.norm(look)

        up = np.array([0.0, 1.0, 0.0])
        if abs(np.dot(up, look)) > 0.95:
            up = np.array([0.0, 0.0, 1.0])
        right = np.cross(look, up)
        right /= np.linalg.norm(right)
        true_up = np.cross(right, look)

        image = np.zeros((args.size, args.size, 3), dtype=np.float32)
        depth = np.full((args.size, args.size), -1e9, dtype=np.float64)

        for positions, normals, uvs, indices, _name in groups:
            projected = np.empty((len(positions), 2))
            for axis, vector in enumerate((right, true_up)):
                projected[:, axis] = (positions - center) @ vector
            projected = projected / (scale * 0.62) * (args.size / 2)
            projected[:, 0] += args.size / 2
            projected[:, 1] = args.size / 2 - projected[:, 1]
            view_depth = (positions - center) @ look

            for tri in indices.reshape(-1, 3):
                x = projected[tri, 0]
                y = projected[tri, 1]
                z = view_depth[tri]

                min_x = max(int(math.floor(x.min())), 0)
                max_x = min(int(math.ceil(x.max())) + 1, args.size)
                min_y = max(int(math.floor(y.min())), 0)
                max_y = min(int(math.ceil(y.max())) + 1, args.size)
                if min_x >= max_x or min_y >= max_y:
                    continue

                area = ((x[1] - x[0]) * (y[2] - y[0]) - (x[2] - x[0]) * (y[1] - y[0]))
                if abs(area) < 1e-9:
                    continue

                grid_y, grid_x = np.mgrid[min_y:max_y, min_x:max_x]
                px = grid_x + 0.5
                py = grid_y + 0.5
                w0 = ((x[1] - px) * (y[2] - py) - (x[2] - px) * (y[1] - py)) / area
                w1 = ((x[2] - px) * (y[0] - py) - (x[0] - px) * (y[2] - py)) / area
                w2 = 1 - w0 - w1
                inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
                if not inside.any():
                    continue

                tri_depth = w0 * z[0] + w1 * z[1] + w2 * z[2]
                visible = inside & (tri_depth > depth[min_y:max_y, min_x:max_x])

                if uvs is not None:
                    u = (w0 * uvs[tri[0], 0] + w1 * uvs[tri[1], 0]
                         + w2 * uvs[tri[2], 0])
                    v = (w0 * uvs[tri[0], 1] + w1 * uvs[tri[1], 1]
                         + w2 * uvs[tri[2], 1])
                    tx = np.clip((u * texture.width).astype(int), 0, texture.width - 1)
                    ty = np.clip((v * texture.height).astype(int), 0, texture.height - 1)
                    texels = np.asarray(texture)[ty, tx, :3] / 255.0
                    # The atlas is mostly transparent; a missing panel shows grey.
                    alpha = np.asarray(texture)[ty, tx, 3] / 255.0
                    texels = texels * alpha[..., None] + 0.25 * (1 - alpha[..., None])
                else:
                    texels = np.full((args.size, args.size, 3), 0.35)

                shade = 1.0
                if normals is not None:
                    n = (w0[..., None] * normals[tri[0]]
                         + w1[..., None] * normals[tri[1]]
                         + w2[..., None] * normals[tri[2]])
                    shade = 0.55 + 0.45 * np.clip(n @ np.array([0.3, 0.8, 0.5]), 0, 1)
                texels = texels * shade[..., None]

                depth[min_y:max_y, min_x:max_x] = np.where(
                    visible, tri_depth, depth[min_y:max_y, min_x:max_x])
                image[min_y:max_y, min_x:max_x] = np.where(
                    visible[..., None], texels, image[min_y:max_y, min_x:max_x])

        tile = Image.fromarray((np.clip(image, 0, 1) * 255).astype(np.uint8))
        ImageDraw.Draw(tile).text((10, 10), label, fill=(255, 255, 255))
        sheet.paste(tile, ((index % columns) * args.size, (index // columns) * args.size))

    sheet.save(args.out)
    print(f"{args.folder}: {len(groups)} primitives, wrote {args.out}")


if __name__ == "__main__":
    sys.exit(main())
