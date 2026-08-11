import { defineConfig, devices } from '@playwright/test';

// baseURL/ports come from the isolated per-worktree stack, resolved by
// tests/e2e/scripts/stack.sh and exported before `playwright test` runs.
// See tests/e2e/design.md for why this stack is per-worktree and always
// fronted by a dedicated test Caddy (tls internal) rather than reached
// directly on a loopback port.
export default defineConfig({
  testDir: './specs',
  fullyParallel: false,
  retries: 0,
  workers: 1,
  reporter: [['list'], ['html', { open: 'never', outputFolder: 'test-results/html' }]],
  outputDir: 'test-results/artifacts',
  use: {
    baseURL: process.env.OPENCLOUD_URL ?? 'https://localhost:9200',
    // The test Caddy's certs chain to a copy of production's internal CA
    // (see stack.sh's ensure_test_ca), which this Node/Playwright process
    // has no reason to have imported into its own trust store.
    ignoreHTTPSErrors: true,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
