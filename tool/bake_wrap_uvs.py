#!/usr/bin/env python3
"""Bakes wrap preview texture coordinates into the vehicle models.

The models in `assets/models/` come from Sketchfab and carry the UV sets their
authors needed for their own textures. Those UVs have nothing to do with Tesla's
wrap template, so painting a wrap texture through them produced a smeared
pattern with holes: the preview was showing the design in places the file never
intended.

This script replaces the UV set of the **painted** primitives with a projection
that covers the wrap sensibly:

* side facing triangles get the design running along the car and up its side,
* top facing triangles (bonnet, roof, boot) get it running along the car,
* front and rear facing triangles get it across the car.

Every other primitive (glass, tyres, lights, trim) keeps its own UVs and
materials, so the preview stays readable.

The projection is not Tesla's panel layout - a model has no information about
which triangle is a door and which is a wing. It is a stable, seamless way to
show the design on the body; the exported PNG keeps Tesla's exact panel mask.

    python3 tool/bake_wrap_uvs.py --source assets/models --target build/models

Requires nothing beyond the standard library.
"""

import argparse
import json
import os
import struct
import sys

MAGIC = 0x46546C67
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942

COMPONENT = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2),
             5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}

# Materials whose geometry takes the wrap. Kept in sync with
# lib/services/glb_texture_patch.dart.
PAINT_NAMES = ("carpaint", "carro_pintura", "bodyl", "body_", "paint",
               "exterior")
TRIM_NAMES = ("glass", "light", "lamp", "rubber", "tire", "tyre", "wheel",
              "rim", "brake", "break", "chrome", "mirror", "plate", "brand",
              "logo", "badge", "interior", "leather", "wood", "seat",
              "screen", "plastic", "emblem")


def read_glb(path):
    data = open(path, "rb").read()
    magic, version, _length = struct.unpack_from("<III", data, 0)
    if magic != MAGIC or version != 2:
        raise SystemExit(f"{path}: not a GLB 2.0 file")

    offset = 12
    document = None
    blob = b""
    while offset + 8 <= len(data):
        length, kind = struct.unpack_from("<II", data, offset)
        chunk = data[offset + 8:offset + 8 + length]
        if kind == JSON_CHUNK and document is None:
            document = json.loads(chunk.decode("utf-8").rstrip("\x00 "))
        elif kind == BIN_CHUNK and not blob:
            blob = chunk
        offset += 8 + length + ((4 - length % 4) % 4)

    if document is None:
        raise SystemExit(f"{path}: no JSON chunk")
    return document, bytearray(blob)


def write_glb(path, document, blob):
    json_bytes = json.dumps(document, separators=(",", ":")).encode("utf-8")
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    blob += b"\x00" * ((4 - len(blob) % 4) % 4)

    total = 12 + 8 + len(json_bytes) + 8 + len(blob)
    out = bytearray()
    out += struct.pack("<III", MAGIC, 2, total)
    out += struct.pack("<II", len(json_bytes), JSON_CHUNK) + json_bytes
    out += struct.pack("<II", len(blob), BIN_CHUNK) + bytes(blob)
    open(path, "wb").write(out)


def read_accessor(document, blob, index):
    """Returns a list of tuples for one accessor."""
    accessor = document["accessors"][index]
    if "bufferView" not in accessor:
        raise SystemExit("accessor without bufferView (compressed model?)")

    view = document["bufferViews"][accessor["bufferView"]]
    fmt, size = COMPONENT[accessor["componentType"]]
    width = WIDTH[accessor["type"]]
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    step = view.get("byteStride") or size * width

    values = []
    for i in range(accessor["count"]):
        offset = start + i * step
        values.append(struct.unpack_from("<" + fmt * width, blob, offset))
    return values


def node_matrix(node):
    """TRS (or an explicit matrix) as a 4x4 row major matrix."""
    if "matrix" in node:
        m = node["matrix"]  # glTF stores column major
        return [[m[0], m[4], m[8], m[12]],
                [m[1], m[5], m[9], m[13]],
                [m[2], m[6], m[10], m[14]],
                [m[3], m[7], m[11], m[15]]]

    x, y, z, w = node.get("rotation", (0.0, 0.0, 0.0, 1.0))
    sx, sy, sz = node.get("scale", (1.0, 1.0, 1.0))
    tx, ty, tz = node.get("translation", (0.0, 0.0, 0.0))

    rotation = [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]

    return [
        [rotation[0][0] * sx, rotation[0][1] * sy, rotation[0][2] * sz, tx],
        [rotation[1][0] * sx, rotation[1][1] * sy, rotation[1][2] * sz, ty],
        [rotation[2][0] * sx, rotation[2][1] * sy, rotation[2][2] * sz, tz],
        [0.0, 0.0, 0.0, 1.0],
    ]


def multiply(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)]
            for i in range(4)]


def apply(matrix, point):
    return (matrix[0][0] * point[0] + matrix[0][1] * point[1] + matrix[0][2] * point[2] + matrix[0][3],
            matrix[1][0] * point[0] + matrix[1][1] * point[1] + matrix[1][2] * point[2] + matrix[1][3],
            matrix[2][0] * point[0] + matrix[2][1] * point[1] + matrix[2][2] * point[2] + matrix[2][3])


def apply_direction(matrix, vector):
    return (matrix[0][0] * vector[0] + matrix[0][1] * vector[1] + matrix[0][2] * vector[2],
            matrix[1][0] * vector[0] + matrix[1][1] * vector[1] + matrix[1][2] * vector[2],
            matrix[2][0] * vector[0] + matrix[2][1] * vector[1] + matrix[2][2] * vector[2])


def material_vertex_counts(document):
    """Position count per material, used to find the body when names are generic."""
    counts = {}
    for mesh in document.get("meshes", []):
        for primitive in mesh["primitives"]:
            material = primitive.get("material")
            position = primitive["attributes"].get("POSITION")
            if material is None or position is None:
                continue
            count = document["accessors"][position]["count"]
            counts[material] = counts.get(material, 0) + count
    return counts


def is_paint(name):
    lower = (name or "").lower()
    if any(trim in lower for trim in TRIM_NAMES):
        return False
    return any(paint in lower for paint in PAINT_NAMES)


def identity():
    return [[1.0 if r == c else 0.0 for c in range(4)] for r in range(4)]


def collect(document, blob):
    """Maps every mesh primitive to its world matrix and material."""
    by_mesh = {}
    scene = document.get("scene", 0)
    roots = document["scenes"][scene].get("nodes", [])
    stack = [(index, identity()) for index in roots]
    nodes = document["nodes"]

    while stack:
        index, parent = stack.pop()
        node = nodes[index]
        world = multiply(parent, node_matrix(node))
        if "mesh" in node:
            by_mesh.setdefault(node["mesh"], []).append(world)
        for child in node.get("children", []):
            stack.append((child, world))

    return by_mesh


def bake(document, blob, scale_hint=None):
    """Rewrites the UVs of the painted primitives. Returns the count."""
    materials = document.get("materials", [])

    # Same choice the runtime makes (GlbMaterialOverride.paintMaterialIndices):
    # materials named as paint, or - when the model names nothing useful - the
    # largest surfaces that are not trim.
    paint = [i for i, m in enumerate(materials) if is_paint(m.get("name"))]
    if not paint:
        counts = material_vertex_counts(document)
        total = sum(counts.values())
        candidates = [i for i, m in enumerate(materials)
                      if not any(t in (m.get("name") or "").lower()
                                 for t in TRIM_NAMES)]
        candidates.sort(key=lambda i: counts.get(i, 0), reverse=True)
        covered = 0
        for index in candidates:
            paint.append(index)
            covered += counts.get(index, 0)
            if len(paint) >= 4 or covered >= total * 0.35:
                break

    paint_set = set(paint)
    owners = collect(document, blob)

    primitives = []
    for mesh_index, mesh in enumerate(document["meshes"]):
        for primitive in mesh["primitives"]:
            if primitive.get("material") not in paint_set:
                continue
            # The shipped models instance every mesh once; if a model ever
            # reuses a mesh, the first placement decides the projection.
            world = owners.get(mesh_index, [identity()])[0]
            primitives.append((primitive, world))

    if not primitives:
        return 0

    # Bounds of everything that carries the wrap, in world space.
    lows = [float("inf")] * 3
    highs = [float("-inf")] * 3
    prepared = []
    for primitive, world in primitives:
        attributes = primitive["attributes"]
        positions = read_accessor(document, blob, attributes["POSITION"])
        normals = (read_accessor(document, blob, attributes["NORMAL"])
                   if "NORMAL" in attributes else None)
        world_positions = [apply(world, p) for p in positions]
        world_normals = [apply_direction(world, n) for n in normals] if normals else None

        for point in world_positions:
            for axis in range(3):
                lows[axis] = min(lows[axis], point[axis])
                highs[axis] = max(highs[axis], point[axis])
        prepared.append((primitive, world_positions, world_normals))

    span = [highs[i] - lows[i] for i in range(3)]
    length_axis = max(range(3), key=lambda i: span[i])
    if length_axis != 2:
        # Almost every car model is built along Z; a model built along X still
        # works because the projection only needs the longest axis.
        pass

    for primitive, world_positions, world_normals in prepared:
        uvs = []
        for index, point in enumerate(world_positions):
            if world_normals:
                normal = world_normals[index]
                axis = max(range(3), key=lambda i: abs(normal[i]))
            else:
                axis = 1

            # U runs along the car, V up its side. glTF puts V=0 at the top row
            # of the image, so "up" has to be flipped or every logo lands
            # upside down.
            u = (point[length_axis] - lows[length_axis]) / (span[length_axis] or 1)
            v = 1.0 - (point[1] - lows[1]) / (span[1] or 1)

            if axis == 1:
                # Bonnet, roof, boot: running along the car, across its width.
                v = 1.0 - (point[0] - lows[0]) / (span[0] or 1)
            elif axis == 2:
                # Nose and tail: across the car, up and down.
                u = 1.0 - (point[0] - lows[0]) / (span[0] or 1)
                v = 1.0 - (point[1] - lows[1]) / (span[1] or 1)
            elif normal[0] < 0:
                # The left flank is seen from the other side, so its texture has
                # to be mirrored for the design to read the same way round.
                u = 1.0 - u

            uvs.append((u, v))

        _write_uvs(document, blob, primitive, uvs)

    return len(prepared)


def _write_uvs(document, blob, primitive, uvs):
    """Appends a TEXCOORD_1 accessor for [primitive]."""
    start = len(blob)
    blob += b"\x00" * ((4 - start % 4) % 4)
    start = len(blob)

    for u, v in uvs:
        blob += struct.pack("<ff", u, v)

    views = document.setdefault("bufferViews", [])
    views.append({
        "buffer": 0,
        "byteOffset": start,
        "byteLength": len(blob) - start,
    })

    accessors = document.setdefault("accessors", [])
    accessors.append({
        "bufferView": len(views) - 1,
        "componentType": 5126,
        "count": len(uvs),
        "type": "VEC2",
        "min": [min(u for u, _ in uvs), min(v for _, v in uvs)],
        "max": [max(u for u, _ in uvs), max(v for _, v in uvs)],
    })
    # The second UV set, so the model's own textures keep working: only the
    # wrap material points at these coordinates.
    primitive["attributes"]["TEXCOORD_1"] = len(accessors) - 1

    # Indices and attributes stay untouched; only the buffer grew.
    document["buffers"][0]["byteLength"] = len(blob)


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default="assets/models")
    parser.add_argument("--target", default="build/models")
    args = parser.parse_args(argv)

    os.makedirs(args.target, exist_ok=True)
    names = sorted(name for name in os.listdir(args.source) if name.endswith(".glb"))
    if not names:
        print(f"no models in {args.source}", file=sys.stderr)
        return 1

    for name in names:
        source = os.path.join(args.source, name)
        target = os.path.join(args.target, name)
        document, blob = read_glb(source)
        count = bake(document, blob)
        if count == 0:
            print(f"{name}: no painted primitives, copied unchanged")
            open(target, "wb").write(open(source, "rb").read())
            continue
        write_glb(target, document, blob)
        print(f"{name}: baked wrap coordinates into {count} primitives")

    return 0


if __name__ == "__main__":
    sys.exit(main())
