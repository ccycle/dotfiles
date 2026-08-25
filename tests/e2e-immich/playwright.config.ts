import { defineConfig, devices } from "@playwright/test";

// baseURL/ports come from the isolated per-worktree stack, resolved by
// tests/e2e-immich/scripts/stack.sh and exported before `playwright test`
// runs. See tests/e2e-immich/design.md for why this stack is per-worktree
// and never touches modules/immich's real instance or data.
export default defineConfig({
  testDir: "./specs",
  fullyParallel: false,
  retries: 0,
  workers: 1,
  reporter: [["list"], ["html", { open: "never", outputFolder: "test-results/html" }]],
  outputDir: "test-results/artifacts",
  use: {
    baseURL: process.env.IMMICH_SERVER_URL,
    // Always on, not 'retain-on-failure' (matches tests/e2e and
    // tests/e2e-forgejo): worth inspecting the upload/thumbnail flow in
    // trace viewer even on a passing run, not just to debug failures.
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
