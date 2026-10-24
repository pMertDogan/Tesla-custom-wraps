#!/usr/bin/env bash
# Rebuilds the compressed 3D models that the web build serves.
#
# The originals in assets/models/ are 117 MB of uncompressed glTF. The viewer
# only needs the compressed copies in web/models/, which are 6 MB together:
# Draco for geometry, WebP for textures, a 0.5 simplify ratio and quantised
# attributes. The Draco decoder ships in web/vendor/draco/, so the page does
# not depend on a Google CDN at runtime.
#
# Before compressing, the wrap preview coordinates are baked in with
# tool/bake_wrap_uvs.py: the models carry their author's UV set, which has
# nothing to do with the wrap template, so the preview writes its own second
# UV set. The bake needs only the Python standard library.
#
#   ./tool/compress_models.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

command -v npx >/dev/null || { echo "npx is required (Node.js 18+)" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }

mkdir -p web/models build/models

echo "Baking wrap preview coordinates"
python3 tool/bake_wrap_uvs.py --source assets/models --target build/models

for source in build/models/*.glb; do
  target="web/models/$(basename "$source")"
  echo "Compressing $source"
  # --prune-attributes false is what keeps TEXCOORD_1 alive: the optimiser
  # otherwise deletes any attribute no material references yet.
  npx --yes @gltf-transform/cli@4.1.1 optimize "$source" "$target" \
    --compress draco \
    --texture-compress webp \
    --texture-size 1024 \
    --simplify true \
    --simplify-ratio 0.5 \
    --simplify-error 0.001 \
    --palette false \
    --prune-attributes false
done
