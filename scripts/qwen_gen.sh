#!/usr/bin/env bash
# qwen_gen.sh — call ollama with a prompt file, write response to OUT_FILE.
# Usage: bash scripts/qwen_gen.sh PROMPT_FILE OUT_FILE [model]
#   model defaults to qwen3-coder:30b
# Uses tempfiles for request/response so prompts and responses can be very large.

set -euo pipefail

PROMPT_FILE="${1:?prompt file required}"
OUT_FILE="${2:?output file required}"
MODEL="${3:-qwen3-coder:30b}"
HOST="${OLLAMA_HOST:-http://127.0.0.1:11434}"

if [ ! -f "$PROMPT_FILE" ]; then
  echo "✗ prompt file not found: $PROMPT_FILE" >&2; exit 1
fi

START_T=$(date +%s)
REQ_FILE=$(mktemp /tmp/qwen_req_XXXXXX.json)
RESP_FILE=$(mktemp /tmp/qwen_resp_XXXXXX.json)
trap 'rm -f "$REQ_FILE" "$RESP_FILE"' EXIT

# Build the JSON request via python; nothing big passes through bash variables.
python3 - "$PROMPT_FILE" "$MODEL" "$REQ_FILE" <<'PY'
import json, sys
prompt_path, model, out = sys.argv[1], sys.argv[2], sys.argv[3]
prompt = open(prompt_path).read()
ctx = max(65536, len(prompt) // 3 + 8192)  # rough chars→tokens heuristic
with open(out, "w") as f:
    json.dump({
        "model": model,
        "prompt": prompt,
        "stream": False,
        "options": {
            "num_ctx": ctx,
            "temperature": 0.7,
            "top_p": 0.9,
            "num_predict": 30000,
        },
    }, f)
PY

echo "→ qwen ($MODEL) — prompt $(wc -c < "$PROMPT_FILE") bytes" >&2
HTTP_CODE=$(curl -s --max-time 1800 -X POST "$HOST/api/generate" \
        -H 'Content-Type: application/json' \
        --data-binary "@$REQ_FILE" \
        -o "$RESP_FILE" \
        -w '%{http_code}')

if [ "$HTTP_CODE" != "200" ]; then
  echo "✗ HTTP $HTTP_CODE from ollama" >&2
  head -c 2000 "$RESP_FILE" >&2
  exit 2
fi

# Extract .response field — python reads response file directly, no shell var.
python3 -c "
import json, sys
data = json.load(open('$RESP_FILE'))
sys.stdout.write(data.get('response',''))
" > "$OUT_FILE"

END_T=$(date +%s)
ELAPSED=$((END_T - START_T))
SIZE=$(wc -c < "$OUT_FILE")
LINES=$(wc -l < "$OUT_FILE")
echo "  done in ${ELAPSED}s — wrote $SIZE bytes / $LINES lines to $OUT_FILE" >&2

if [ "$SIZE" -lt 100 ]; then
  echo "✗ suspiciously short response — raw API JSON head:" >&2
  head -c 2000 "$RESP_FILE" >&2
  exit 2
fi
