#!/usr/bin/env bash
# Rebuilds the compressed 3D models that the web build serves.
#
# The originals in assets/models/ are 117 MB of uncompressed glTF. The viewer
# only needs the compressed copies in web/models/, which are 6 MB together:
# Draco for geometry, WebP for textures, a 0.5 simplify ratio and quantised
# attributes. The Draco decoder ships in web/vendor/draco/, so the page does
# not depend on a Google CDN at runtime.
#
#   ./tool/compress_models.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

command -v npx >/dev/null || { echo "npx is required (Node.js 18+)" >&2; exit 1; }

mkdir -p web/models

for source in assets/models/*.glb; do
  target="web/models/$(basename "$source")"
  echo "Compressing $source"
  npx --yes @gltf-transform/cli@4.1.1 optimize "$source" "$target" \
    --compress draco \
    --texture-compress webp \
    --texture-size 1024 \
    --simplify true \
    --simplify-ratio 0.5 \
    --palette false
done

echo
du -ch web/models/*.glb | tail -1
