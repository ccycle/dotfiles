import { defineConfig } from "@playwright/test";

// baseURL/paths come from the isolated per-worktree stack, resolved by
// tests/e2e-forgejo/scripts/stack.sh and exported before `playwright test`
// runs. See tests/e2e-forgejo/design.md.
//
// No `projects`/browser `devices` entry: unlike tests/e2e's OpenCloud
// suite, nothing here drives a browser - every check goes through
// Playwright's `request` fixture (plain HTTP, no page) or shells out to
// the real forgejo/forgejo-runner/git/docker CLIs. Configuring a browser
// project would launch Chromium for no reason.
export default defineConfig({
  testDir: "./specs",
  fullyParallel: false,
  retries: 0,
  workers: 1,
  timeout: 120_000,
  reporter: [["list"], ["html", { open: "never", outputFolder: "test-results/html" }]],
  outputDir: "test-results/artifacts",
  use: {
    baseURL: process.env.FORGEJO_EXTERNAL_URL,
    // Always on, not 'retain-on-failure' (tests/e2e's default): the point
    // of this suite is partly to make the exact Forgejo API calls
    // (request/response bodies - e.g. the observed status-check context
    // string) inspectable in trace viewer even on a passing run, not just
    // to debug failures.
    trace: "on",
  },
});
