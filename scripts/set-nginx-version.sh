#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-}"
VERSION="${2:-}"

if [[ -z "${ENVIRONMENT}" || -z "${VERSION}" ]]; then
  echo "Usage: $0 <dev|preprod|prod> <nginx-version>"
  echo "Example: $0 dev 1.28.1"
  exit 1
fi

case "${ENVIRONMENT}" in
  dev|preprod|prod) ;;
  *)
    echo "Invalid environment: ${ENVIRONMENT}"
    exit 1
    ;;
esac

FILE="environments/${ENVIRONMENT}/kustomization.yaml"

python3 - "${FILE}" "${VERSION}" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
version = sys.argv[2]
text = path.read_text()

new_text, count = re.subn(
    r'(newTag:\s*)["\']?[^"\']+\b["\']?',
    rf'\1"{version}"',
    text,
    count=1
)

if count != 1:
    raise SystemExit(f"Could not update newTag in {path}")

path.write_text(new_text)
print(f"Updated {path} to nginx:{version}")
PY
