#!/bin/zsh
# Downloads EverPaper/embeddinggemma-2-coreai (text + image encoders and the Swift package; the audio encoder is
# skipped) into Vendor/EmbeddingGemma-2-CoreAI and verifies the checksums.
set -euo pipefail
REPO="EverPaper/embeddinggemma-2-coreai"
DEST="${0:A:h:h}/Vendor/EmbeddingGemma-2-CoreAI"
mkdir -p "$DEST" && cd "$DEST"
curl -sf "https://huggingface.co/api/models/$REPO/tree/main?recursive=true" | python3 -c '
import json, sys
for f in json.load(sys.stdin):
    p = f["path"]
    if f["type"] == "file" and (p.startswith("swift/") or not ("audio" in p.lower() or p.startswith(("export/", "python/")))):
        print(f.get("lfs", {}).get("size", f["size"]), p)
' > files.txt
while read -r size p; do
  if [[ -f "$p" && $(stat -f %z "$p") == "$size" ]]; then continue; fi
  mkdir -p "${p:h}"
  echo "↓ $p"
  # -C - resumes a partial download.
  curl -sfL --retry 5 -C - -o "$p" "https://huggingface.co/$REPO/resolve/main/$p"
done < files.txt
grep -E ' (model|swift)/' CHECKSUMS.sha256 | grep -vi audio | shasum -a 256 -c --quiet
echo "Model ready in $DEST/model"
