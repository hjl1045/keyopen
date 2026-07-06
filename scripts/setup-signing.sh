#!/usr/bin/env bash
# One-time setup: create a local self-signed code-signing certificate so KeyOpen
# keeps a STABLE identity across rebuilds. Without this, the app is ad-hoc signed,
# its code hash changes every build, and macOS resets its Accessibility permission
# each time you repackage. Idempotent — safe to re-run.
set -euo pipefail

CN="KeyOpen Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning 2>/dev/null | grep -q "$CN"; then
    echo "Signing identity '$CN' already exists — nothing to do."
    exit 0
fi

echo "Creating self-signed code-signing certificate '$CN'…"
TMP="$(mktemp -d)"
cat > "$TMP/req.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = $CN
[v3]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/req.cnf" >/dev/null 2>&1
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/id.p12" -name "$CN" -passout pass: >/dev/null 2>&1

# -A lets codesign use the key without a per-build keychain prompt.
security import "$TMP/id.p12" -k "$KEYCHAIN" -P "" -A >/dev/null 2>&1

rm -rf "$TMP"
echo "Done. Now run:  ./scripts/package.sh   (it will sign with '$CN')."
echo "Grant Accessibility one more time (the identity changed); after that it"
echo "sticks across every future rebuild."
