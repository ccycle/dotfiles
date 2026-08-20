import { defineConfig, devices } from '@playwright/test';

// URLs/ports come from the isolated per-worktree stack, resolved by
// tests/e2e-monitoring/scripts/stack.sh and exported before
// `playwright test` runs. See tests/e2e-monitoring/design.md for why
// this stack is per-worktree yet deliberately still scrapes the real
// host via host-gateway rather than faking scrape targets too.
//
// Unlike tests/e2e-forgejo (API-only, no `projects`), this suite needs a
// browser project for the one lightweight Grafana dashboard-render check
// (see specs/monitoring.spec.ts) alongside its otherwise request-fixture-
// only checks.
export default defineConfig({
  testDir: './specs',
  fullyParallel: false,
  retries: 0,
  workers: 1,
  timeout: 60_000,
  reporter: [['list'], ['html', { open: 'never', outputFolder: 'test-results/html' }]],
  outputDir: 'test-results/artifacts',
  use: {
    trace: 'on',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
