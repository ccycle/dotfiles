import { test, expect } from '@playwright/test';
import {
  provisionTestUser,
  loginViaPasskey,
  revokeOwnClientAuthorization,
  type PocketIdAdmin,
} from '../../e2e/lib/pocket-id-auth';

// Env vars are set by tests/e2e-reports/scripts/stack.sh into .env and
// sourced by scripts/run.sh before `playwright test`; see
// tests/e2e-reports/design.md for the isolated per-worktree stack this
// test runs against (never production).
const REPORTS_URL = requireEnv('REPORTS_URL');
const POCKET_ID_URL = requireEnv('POCKET_ID_URL');
const POCKET_ID_API_KEY = requireEnv('POCKET_ID_API_KEY');
const REPORTS_GROUP_ID = requireEnv('REPORTS_GROUP_ID');
const REPORTS_OIDC_CLIENT_ID = requireEnv('REPORTS_OIDC_CLIENT_ID');

const TEST_USERNAME = 'e2e-test-runner';
// Seeded into the stack's static root by stack.sh's derive_env.
const HELLO_FILE = 'e2e-hello.txt';

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} must be set (see tests/e2e-reports/scripts/stack.sh)`);
  }
  return value;
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

const admin: PocketIdAdmin = { baseUrl: POCKET_ID_URL, apiKey: POCKET_ID_API_KEY };

// The gate's raison d'être: an anonymous browser (no oauth2-proxy cookie,
// no pocket-id session) must not see any report content. The redirect
// chain is reports -> oauth2-proxy /oauth2/sign_in -> pocket-id authorize
// (skip-provider-button skips oauth2-proxy's own picker), landing on
// pocket-id's passkey login page.
test('unauthenticated visit is redirected to pocket-id login', async ({ page }) => {
  test.setTimeout(60_000);
  await page.goto(REPORTS_URL);
  await page.waitForURL(new RegExp(`^${escapeRegExp(POCKET_ID_URL)}`), { timeout: 20_000 });
  await expect(page).toHaveURL(new RegExp(`^${escapeRegExp(POCKET_ID_URL)}`));
});

// Full ceremony: the shared pocket-id-auth helper registers a fresh
// passkey for the (stable) test user, then the browser navigates to
// reports, passes oauth2-proxy's gate, and can browse + read a file.
test('authenticated user can browse and read report files', async ({ page }) => {
  test.setTimeout(90_000);
  const { teardown } = await provisionTestUser(page, admin, {
    username: TEST_USERNAME,
    groupId: REPORTS_GROUP_ID,
  });

  try {
    // Revoke any authorization a prior run left behind (pocket-id's
    // consent state persists across runs — see tests/e2e-reports/design.md
    // and pocket-id-auth.ts's revokeOwnClientAuthorization), so the
    // consent screen loginViaPasskey() expects is always there,
    // deterministically — same pattern as tests/e2e/specs/opencloud.spec.ts.
    await revokeOwnClientAuthorization(page, POCKET_ID_URL, REPORTS_OIDC_CLIENT_ID);

    await page.goto(REPORTS_URL);
    // provisionTestUser left the browser authenticated to pocket-id (via
    // the one-time-access-token login), so oauth2-proxy's redirect lands
    // on pocket-id's consent screen, not its login page.
    await loginViaPasskey(page);
    await page.waitForURL(new RegExp(`^${escapeRegExp(REPORTS_URL)}`), { timeout: 20_000 });

    // file_server browse lists the seeded file.
    await expect(page.getByText(HELLO_FILE)).toBeVisible({ timeout: 20_000 });

    // And the file itself is readable.
    await page.goto(`${REPORTS_URL}/${HELLO_FILE}`);
    await expect(page.getByText('e2e test report payload')).toBeVisible({ timeout: 20_000 });
  } finally {
    await teardown();
  }
});

// Signing out must re-engage the gate: once oauth2-proxy's cookie is gone,
// the same URL that was just served bounces back to pocket-id. clearCookies
// is required because oauth2-proxy's /oauth2/sign_out only drops its own
// cookie — the pocket-id session cookie (which would silently
// re-authenticate the next gate pass) is pocket-id's, not oauth2-proxy's.
test('signing out re-engages the gate', async ({ page }) => {
  test.setTimeout(90_000);
  const { teardown } = await provisionTestUser(page, admin, {
    username: TEST_USERNAME,
    groupId: REPORTS_GROUP_ID,
  });

  try {
    await revokeOwnClientAuthorization(page, POCKET_ID_URL, REPORTS_OIDC_CLIENT_ID);

    await page.goto(REPORTS_URL);
    await loginViaPasskey(page);
    await page.waitForURL(new RegExp(`^${escapeRegExp(REPORTS_URL)}`), { timeout: 20_000 });
    await expect(page.getByText(HELLO_FILE)).toBeVisible({ timeout: 20_000 });

    await page.goto(`${REPORTS_URL}/oauth2/sign_out`);
    await page.context().clearCookies();

    await page.goto(REPORTS_URL);
    await page.waitForURL(new RegExp(`^${escapeRegExp(POCKET_ID_URL)}`), { timeout: 20_000 });
    await expect(page).toHaveURL(new RegExp(`^${escapeRegExp(POCKET_ID_URL)}`));
  } finally {
    await teardown();
  }
});