---
name: smoke-test-caddy-cert
description: Run smoke tests to verify Caddy CA certificate is correctly generated in DER format and served with proper HTTP headers.
---

# Caddy CA Certificate Smoke Test

Verifies that the Caddy internal CA root certificate is correctly converted to DER format and served via HTTP with the correct headers for iOS compatibility.

## Usage

Run from the repository root:

```bash
.agents/skills/smoke-test-caddy-cert/scripts/test.sh
```

## Checks Performed

1. **HTTP Response**: Fetches `http://ca.mac-mini-m4.internal/ca.crt` and verifies:
   - HTTP 200 response
   - `Content-Type` is `application/x-x509-ca-cert`
   - `Content-Disposition` header is **absent** (required for iOS profile installation)
2. **Certificate Format**: Confirms the served file is:
   - Valid DER-encoded X.509 certificate
   - A CA certificate (`CA:TRUE` basic constraint)
3. **HTTPS Verification**: Uses the served CA certificate to verify an HTTPS endpoint, proving the certificate is functional for TLS validation.

## When to Use

- After `darwin-rebuild switch` to verify the CA certificate is correctly deployed.
- When debugging iOS certificate trust issues.
