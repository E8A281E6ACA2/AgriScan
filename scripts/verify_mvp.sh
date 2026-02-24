#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/backend/.env"

API_BASE_URL="${API_BASE_URL:-http://localhost:8080/api/v1}"
REQUIRE_S3="${REQUIRE_S3:-0}"
SAMPLE_IMAGE="${SAMPLE_IMAGE:-}"

ok() { printf "[OK] %s\n" "$*"; }
warn() { printf "[WARN] %s\n" "$*" >&2; }
fail() { printf "[FAIL] %s\n" "$*" >&2; exit 1; }

check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "command '$1' found"
  else
    warn "command '$1' not found"
  fi
}

check_env_var() {
  local var="$1"
  if [[ -f "$ENV_FILE" ]] && grep -qE "^${var}=" "$ENV_FILE"; then
    ok "env '${var}' present in backend/.env"
  else
    warn "env '${var}' missing in backend/.env"
  fi
}

usage() {
  cat <<EOF
Usage:
  ./scripts/verify_mvp.sh              # preflight checks
  ./scripts/verify_mvp.sh --api        # call API (server must be running)

Env:
  API_BASE_URL=http://localhost:8080/api/v1
  REQUIRE_S3=0|1
  SAMPLE_IMAGE=/abs/path/to/image.jpg
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

echo "== Preflight =="
check_cmd go
check_cmd flutter
check_cmd curl

if [[ ! -f "$ENV_FILE" ]]; then
  warn "backend/.env not found"
else
  ok "backend/.env found"
fi

check_env_var SERVER_PORT
check_env_var DB_HOST
check_env_var DB_PORT
check_env_var DB_USER
check_env_var DB_PASSWORD
check_env_var DB_NAME
check_env_var LLM_PROVIDER
check_env_var LLM_API_KEY
check_env_var LLM_ENDPOINT
check_env_var LLM_MODEL

if [[ -f "$ENV_FILE" ]]; then
  if grep -qE "^S3_ACCESS_KEY_ID=" "$ENV_FILE" \
    && grep -qE "^S3_SECRET_ACCESS_KEY=" "$ENV_FILE" \
    && grep -qE "^S3_BUCKET=" "$ENV_FILE"; then
    ok "S3/R2 credentials present"
  else
    if [[ "$REQUIRE_S3" == "1" ]]; then
      fail "S3/R2 credentials missing but REQUIRE_S3=1"
    fi
    warn "S3/R2 credentials missing; local storage fallback will be used"
  fi
fi

if [[ "${1:-}" != "--api" ]]; then
  echo "== Done (preflight) =="
  exit 0
fi

echo "== API Smoke Test =="
echo "API_BASE_URL=$API_BASE_URL"

if ! command -v curl >/dev/null 2>&1; then
  fail "curl not found"
fi

echo "- GET /providers"
curl -fsS "$API_BASE_URL/providers" >/dev/null && ok "providers OK" || fail "providers failed"

if [[ -n "$SAMPLE_IMAGE" && -f "$SAMPLE_IMAGE" ]]; then
  echo "- POST /upload"
  upload_resp="$(curl -fsS -X POST "$API_BASE_URL/upload" -F "image=@$SAMPLE_IMAGE")"
  ok "upload OK"
  if command -v jq >/dev/null 2>&1; then
    image_id="$(printf "%s" "$upload_resp" | jq -r '.image_id')"
  else
    warn "jq not found; cannot parse image_id automatically"
    image_id=""
  fi

  if [[ -n "$image_id" && "$image_id" != "null" ]]; then
    echo "- POST /recognize"
    recognize_resp="$(curl -fsS -X POST "$API_BASE_URL/recognize" -H "Content-Type: application/json" -d "{\"image_id\": $image_id}")"
    ok "recognize OK"
    if command -v jq >/dev/null 2>&1; then
      result_id="$(printf "%s" "$recognize_resp" | jq -r '.result_id')"
      if [[ -n "$result_id" && "$result_id" != "null" ]]; then
        echo "- GET /result/$result_id"
        curl -fsS "$API_BASE_URL/result/$result_id" >/dev/null && ok "result OK" || fail "result failed"
      fi
    fi
  fi
else
  warn "SAMPLE_IMAGE not provided; skipping upload/recognize/result"
fi

echo "== Done (api) =="
