#!/usr/bin/env bash
# MANAS — TLS Certificate Pin Hash Generator
#
# Generates SHA-256 public key hashes for the server's certificate chain.
# MANAS uses intermediate CA pinning (ADR-003): we pin the CA that signed
# the server cert, not the leaf cert itself. This survives cert renewals
# as long as the same CA is used (e.g. Let's Encrypt R3, DigiCert).
#
# Usage:
#   ./generate_pin_hash.sh <host> [port]
#
# Examples:
#   ./generate_pin_hash.sh api.maanas.health
#   ./generate_pin_hash.sh api.maanas.health 443
#
# Output: SHA-256 hashes for all certs in the chain (leaf, intermediate, root).
# Copy the INTERMEDIATE hash into ManasDev.plist as MAANAS_PIN_HASH.

set -euo pipefail

HOST="${1:-}"
PORT="${2:-443}"

if [[ -z "$HOST" ]]; then
  echo "Usage: $0 <host> [port]" >&2
  exit 1
fi

echo "Fetching certificate chain from ${HOST}:${PORT} ..."
echo ""

# Fetch full chain (-showcerts includes intermediate + root)
CHAIN=$(echo | openssl s_client \
  -connect "${HOST}:${PORT}" \
  -servername "${HOST}" \
  -showcerts 2>/dev/null)

if [[ -z "$CHAIN" ]]; then
  echo "ERROR: Could not connect to ${HOST}:${PORT}" >&2
  exit 1
fi

# Split chain into individual PEM blocks and hash each one
INDEX=0
LABELS=("LEAF (do not use — rotates with cert)" "INTERMEDIATE ← use this one" "ROOT")
INTERMEDIATE_HASH=""

while IFS= read -r LINE; do
  if [[ "$LINE" == "-----BEGIN CERTIFICATE-----" ]]; then
    CERT_PEM="$LINE"
  elif [[ "$LINE" == "-----END CERTIFICATE-----" ]]; then
    CERT_PEM="${CERT_PEM}"$'\n'"$LINE"

    HASH=$(echo "$CERT_PEM" \
      | openssl x509 -pubkey -noout 2>/dev/null \
      | openssl pkey -pubin -outform DER 2>/dev/null \
      | openssl dgst -sha256 -binary \
      | base64)

    LABEL="${LABELS[$INDEX]:-ADDITIONAL}"
    echo "  Cert $INDEX — ${LABEL}"
    echo "  Hash: ${HASH}"
    echo ""

    if [[ $INDEX -eq 1 ]]; then
      INTERMEDIATE_HASH="$HASH"
    fi

    INDEX=$((INDEX + 1))
    CERT_PEM=""
  elif [[ -n "${CERT_PEM:-}" ]]; then
    CERT_PEM="${CERT_PEM}"$'\n'"$LINE"
  fi
done <<< "$CHAIN"

if [[ -z "$INTERMEDIATE_HASH" ]]; then
  echo "WARNING: Could not extract intermediate cert hash." >&2
  echo "         Server may only be presenting a single (leaf) cert." >&2
  exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Intermediate CA hash for ${HOST}:${PORT}:"
echo ""
echo "  ${INTERMEDIATE_HASH}"
echo ""
echo "Add to ManasDev.plist:"
echo "  <key>MAANAS_PIN_HASH</key>"
echo "  <string>${INTERMEDIATE_HASH}</string>"
echo ""
echo "Or set as Xcode scheme env var: MAANAS_PIN_HASH = ${INTERMEDIATE_HASH}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
