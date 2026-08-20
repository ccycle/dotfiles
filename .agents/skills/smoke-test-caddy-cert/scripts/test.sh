#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
HOSTNAME=$(hostname)
CA_URL="http://ca.${HOSTNAME}.internal/ca.crt"
FAILED=0
TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

# --- Helpers ---
pass() { echo "✅ $1"; }
fail() { echo "❌ $1"; FAILED=1; }

# --- 1. HTTP Response ---
echo "=== 🌐 HTTP Response ==="

HEADERS_FILE="$TMPDIR_WORK/headers.txt"
CERT_FILE="$TMPDIR_WORK/served.der"

HTTP_CODE=$(curl -sf --max-time 10 -D "$HEADERS_FILE" -o "$CERT_FILE" -w '%{http_code}' "$CA_URL" 2>/dev/null || true)

if [ "$HTTP_CODE" = "200" ]; then
  pass "HTTP 200 from $CA_URL"
else
  fail "HTTP $HTTP_CODE from $CA_URL (expected 200)"
  echo ""
  echo "❌ Cannot reach CA endpoint — remaining checks cannot proceed."
  exit 1
fi

# Check Content-Type
CT=$(grep -i '^content-type:' "$HEADERS_FILE" | tr -d '\r' | head -1 || true)
if echo "$CT" | grep -qi 'application/x-x509-ca-cert'; then
  pass "Content-Type is application/x-x509-ca-cert"
else
  fail "Content-Type unexpected: ${CT:-<missing>}"
fi

# Check Content-Disposition is absent
CD=$(grep -i '^content-disposition:' "$HEADERS_FILE" | tr -d '\r' || true)
if [ -z "$CD" ]; then
  pass "Content-Disposition header is absent (good for iOS)"
else
  fail "Content-Disposition header is present: $CD"
fi

# --- 2. Certificate Format Validation ---
echo ""
echo "=== 🔐 Certificate Validation ==="

if openssl x509 -in "$CERT_FILE" -inform DER -noout 2>/dev/null; then
  pass "Served certificate is valid DER-encoded X.509"
else
  fail "Served certificate is not valid DER-encoded X.509"
fi

# Verify it is a CA certificate (Basic Constraints: CA:TRUE)
BC=$(openssl x509 -in "$CERT_FILE" -inform DER -text -noout 2>/dev/null | grep -A1 'Basic Constraints' || true)
if echo "$BC" | grep -q 'CA:TRUE'; then
  pass "Certificate has CA:TRUE basic constraint"
else
  fail "Certificate missing CA:TRUE basic constraint"
fi

# Show certificate subject for informational purposes
SUBJECT=$(openssl x509 -in "$CERT_FILE" -inform DER -subject -noout 2>/dev/null || true)
echo "   ℹ️  $SUBJECT"

# --- 3. HTTPS with CA cert ---
echo ""
echo "=== 🔒 HTTPS Verification ==="

# Use the served CA cert to verify an HTTPS endpoint (proves the cert is functional)
if curl -sf --max-time 10 --cacert <(openssl x509 -in "$CERT_FILE" -inform DER -outform PEM 2>/dev/null) \
     "https://ca.${HOSTNAME}.internal" > /dev/null 2>&1; then
  pass "HTTPS verified using served CA certificate"
else
  fail "HTTPS verification failed with served CA certificate"
fi

# --- Result ---
echo ""
if [ "$FAILED" -eq 0 ]; then
  echo "🎉 All CA certificate smoke tests passed!"
else
  echo "❌ Some CA certificate smoke tests failed."
  exit 1
fi
