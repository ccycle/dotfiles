import { defineConfig, devices } from "@playwright/test";

// baseURL/ports come from the isolated per-worktree stack, resolved by
// modules/static-reports/tests/e2e/scripts/stack.sh and exported into .env before
// `playwright test` runs (sourced by scripts/run.sh). See
// modules/static-reports/tests/e2e/design.md for why this stack is per-worktree and
// fronted by a dedicated test Caddy (tls internal) that replicates the
// production reports vhost's forward_auth gate.
export default defineConfig({
  testDir: "./specs",
  fullyParallel: false,
  retries: 0,
  workers: 1,
  reporter: [["list"], ["html", { open: "never", outputFolder: "test-results/html" }]],
  outputDir: "test-results/artifacts",
  use: {
    baseURL: process.env.REPORTS_URL ?? "https://localhost:9201",
    // The test Caddy's certs chain to its own per-worktree CA, trusted by
    // nothing. Measured: Chromium (headless shell and full) still completes
    // a WebAuthn ceremony with this alone, so no trust-store import is needed.
    ignoreHTTPSErrors: true,
    // Always on, not 'retain-on-failure': the OIDC/consent/passkey
    // ceremony and the forward_auth redirect chain are worth inspecting
    // in trace viewer even on a passing run.
    trace: "on",
    screenshot: "only-on-failure",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});
