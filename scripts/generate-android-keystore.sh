#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# generate-android-keystore.sh
#
# Generates a self-signed Android release keystore for CI/CD use when no
# production signing credentials have been supplied.
#
# Usage (local):
#   chmod +x scripts/generate-android-keystore.sh
#   ./scripts/generate-android-keystore.sh \
#       [output_path]   (default: ci-keystore.jks)
#       [key_alias]     (default: ci-key)
#       [store_password](default: ci-store-pass)
#       [key_password]  (default: ci-key-pass)
#
# After running, copy the printed base64 blob to your GitHub secret
# ANDROID_SIGNING_KEY_BASE64.  Set the other three printed values as:
#   ANDROID_KEY_ALIAS
#   ANDROID_KEYSTORE_PASSWORD
#   ANDROID_KEY_PASSWORD
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

KEY_PATH="${1:-ci-keystore.jks}"
KEY_ALIAS="${2:-ci-key}"
STORE_PASS="${3:-ci-store-pass}"
KEY_PASS="${4:-ci-key-pass}"
VALIDITY_DAYS="${5:-10000}"
DNAME="CN=CI Build, OU=CI, O=Organisation, L=Unknown, ST=Unknown, C=US"

# ── Dependency check ──────────────────────────────────────────────────────────
if ! command -v keytool &>/dev/null; then
  echo "❌  keytool not found. Install a JDK (e.g. 'sudo apt-get install default-jdk')." >&2
  exit 1
fi

# ── Generate keystore ─────────────────────────────────────────────────────────
echo ""
echo "🔑  Generating Android keystore …"
echo "    Output path : $KEY_PATH"
echo "    Key alias   : $KEY_ALIAS"
echo "    Validity    : $VALIDITY_DAYS days"
echo ""

keytool -genkeypair -v \
  -keystore  "$KEY_PATH" \
  -alias     "$KEY_ALIAS" \
  -keyalg    RSA \
  -keysize   2048 \
  -validity  "$VALIDITY_DAYS" \
  -storepass "$STORE_PASS" \
  -keypass   "$KEY_PASS" \
  -dname     "$DNAME" \
  -storetype JKS

echo ""
echo "✅  Keystore created: $KEY_PATH"

# ── Base64 encode ─────────────────────────────────────────────────────────────
BASE64_VALUE=$(base64 < "$KEY_PATH" | tr -d '\n')

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  GitHub Secrets — copy these values to your repository / environment"
echo "══════════════════════════════════════════════════════════════════"
echo ""
echo "ANDROID_SIGNING_KEY_BASE64:"
echo "$BASE64_VALUE"
echo ""
echo "ANDROID_KEY_ALIAS:          $KEY_ALIAS"
echo "ANDROID_KEYSTORE_PASSWORD:  $STORE_PASS"
echo "ANDROID_KEY_PASSWORD:       $KEY_PASS"
echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "⚠️   This is a self-signed CI keystore."
echo "    For Play Store releases, use a production keystore issued"
echo "    through your Google Play signing setup."
echo "══════════════════════════════════════════════════════════════════"
