#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# generate-ios-certs.sh
#
# Two-step helper for iOS code-signing setup.
#
# Step 1 — generate a private key + CSR to submit to Apple:
#   ./scripts/generate-ios-certs.sh csr [name]
#   Outputs: ios-dist-key.pem  ios-dist.csr
#   Upload ios-dist.csr at developer.apple.com → Certificates → (+)
#   Download the resulting ios_distribution.cer
#
# Step 2 — combine Apple's .cer with your key into a .p12 and print secrets:
#   ./scripts/generate-ios-certs.sh p12 ios_distribution.cer [p12_password]
#   Outputs: ios-dist.p12  (and prints base64 + secrets for GitHub)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

COMMAND="${1:-}"
if [[ -z "$COMMAND" ]]; then
  echo "Usage:"
  echo "  $0 csr [common_name]"
  echo "  $0 p12 <path/to/ios_distribution.cer> [p12_password]"
  exit 1
fi

if ! command -v openssl &>/dev/null; then
  echo "❌  openssl not found. Install it (e.g. 'brew install openssl')." >&2
  exit 1
fi

# ── Step 1: generate private key + CSR ───────────────────────────────────────
if [[ "$COMMAND" == "csr" ]]; then
  CN="${2:-iOS Distribution}"
  KEY_FILE="ios-dist-key.pem"
  CSR_FILE="ios-dist.csr"

  echo ""
  echo "🔑  Generating private key → $KEY_FILE"
  openssl genrsa -out "$KEY_FILE" 2048

  echo "📄  Generating CSR → $CSR_FILE"
  openssl req -new \
    -key "$KEY_FILE" \
    -out "$CSR_FILE" \
    -subj "/CN=$CN/O=Personal/C=US"

  echo ""
  echo "✅  Done."
  echo ""
  echo "Next steps:"
  echo "  1. Go to developer.apple.com → Certificates → (+)"
  echo "  2. Choose 'Apple Distribution' (for Ad Hoc / Firebase distribution)"
  echo "  3. Upload $CSR_FILE"
  echo "  4. Download the resulting ios_distribution.cer"
  echo "  5. Run: $0 p12 ios_distribution.cer [password]"
  exit 0
fi

# ── Step 2: build .p12 from Apple cert + private key ─────────────────────────
if [[ "$COMMAND" == "p12" ]]; then
  CER_FILE="${2:-}"
  P12_PASS="${3:-ios-dist-pass}"
  KEY_FILE="ios-dist-key.pem"
  CERT_PEM="ios-dist-cert.pem"
  P12_FILE="ios-dist.p12"

  if [[ -z "$CER_FILE" || ! -f "$CER_FILE" ]]; then
    echo "❌  Certificate file not found: '$CER_FILE'" >&2
    echo "    Usage: $0 p12 <path/to/ios_distribution.cer> [password]" >&2
    exit 1
  fi

  if [[ ! -f "$KEY_FILE" ]]; then
    echo "❌  Private key not found: $KEY_FILE" >&2
    echo "    Run '$0 csr' first." >&2
    exit 1
  fi

  echo ""
  echo "🔄  Converting .cer → PEM"
  openssl x509 -in "$CER_FILE" -inform DER -out "$CERT_PEM"

  echo "📦  Creating .p12 → $P12_FILE"
  openssl pkcs12 -export \
    -out     "$P12_FILE" \
    -inkey   "$KEY_FILE" \
    -in      "$CERT_PEM" \
    -passout "pass:$P12_PASS"

  BASE64_VALUE=$(base64 -i "$P12_FILE" | tr -d '\n')

  echo ""
  echo "══════════════════════════════════════════════════════════════════"
  echo "  GitHub Secrets — copy these values to your environment"
  echo "══════════════════════════════════════════════════════════════════"
  echo ""
  echo "IOS_P12_BASE64:"
  echo "$BASE64_VALUE"
  echo ""
  echo "IOS_P12_PASSWORD:  $P12_PASS"
  echo ""
  echo "── Remaining secrets (find these in Xcode / Apple Developer portal) ──"
  echo "IOS_CODE_SIGN_IDENTITY:    Apple Distribution: <Your Name> (<TEAM_ID>)"
  echo "IOS_PROVISIONING_PROFILE:  <Profile name from Xcode / developer.apple.com>"
  echo ""
  echo "══════════════════════════════════════════════════════════════════"
  echo "  See README.md → iOS Signing Setup for full instructions."
  echo "══════════════════════════════════════════════════════════════════"
  exit 0
fi

echo "❌  Unknown command: $COMMAND  (use 'csr' or 'p12')" >&2
exit 1
