import { test, expect } from '@playwright/test';
import { existsSync, mkdirSync, rmSync, writeFileSync, mkdtempSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import {
  provisionTestUser,
  loginViaPasskey,
  clickIfPresent,
  type PocketIdAdmin,
} from '../lib/pocket-id-auth';

// Env vars are set by tests/e2e/scripts/stack.sh before invoking
// `playwright test`; see tests/e2e/design.md for the isolated per-worktree
// stack this test runs against (never production).
const POCKET_ID_URL = requireEnv('POCKET_ID_URL');
const POCKET_ID_API_KEY = requireEnv('POCKET_ID_API_KEY');
const OPENCLOUD_GROUP_ID = requireEnv('OPENCLOUD_GROUP_ID');
// Host-side path OpenCloud's posix storage driver mirrors the UI tree
// into (STORAGE_USERS_POSIX_ROOT); see modules/opencloud/design.md.
const USER_FILES_DIR = requireEnv('OPENCLOUD_USER_FILES_DIR');

const TEST_USERNAME = 'e2e-test-runner';
const USER_DIR = join(USER_FILES_DIR, TEST_USERNAME);

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} must be set (see tests/e2e/scripts/stack.sh)`);
  }
  return value;
}

const admin: PocketIdAdmin = { baseUrl: POCKET_ID_URL, apiKey: POCKET_ID_API_KEY };

test.beforeEach(() => {
  // Idempotent, never deleted between runs (mkdirSync recursive is a
  // no-op if it already exists). OpenCloud's posix storage driver in
  // non-collaborative mode does not itself create a personal space
  // directory for a newly auto-provisioned OIDC user on first login —
  // confirmed by inspecting the WebDAV PROPFIND response, whose
  // oc:permissions lacked Create/CreateDir (and resourcetype wasn't even
  // reported as a collection) until the directory existed on disk. Any
  // brand-new user hits this, not just this test suite.
  //
  // Deliberately NOT wiped/recreated every run: non-collaborative mode
  // only learns about filesystem changes via its own assimilation scan,
  // not by watching the filesystem (modules/opencloud/design.md) — an
  // earlier version of this test deleted-then-recreated the directory
  // every run, which left OpenCloud's own id-cache pointing at
  // now-nonexistent paths and made uploads of a fixed filename fail with
  // "stat ...: no such file or directory" (confirmed in its logs). Using
  // a unique filename per run (below) avoids ever needing to reuse a
  // path OpenCloud has stale metadata for.
  mkdirSync(USER_DIR, { recursive: true });
});

test('passkey login through OpenCloud OIDC succeeds', async ({ page }) => {
  test.setTimeout(60_000);
  const { teardown } = await provisionTestUser(page, admin, {
    username: TEST_USERNAME,
    groupId: OPENCLOUD_GROUP_ID,
  });

  try {
    await loginToOpenCloud(page);
    // Deliberately not asserting which specific view we land on
    // (observed varying between the personal space and the general
    // "Spaces" overview) — only that the app considers us logged in,
    // via the account menu that's present on every view once
    // authenticated.
    await expect(page.getByRole('button', { name: 'My Account' })).toBeVisible({
      timeout: 20_000,
    });
  } finally {
    await teardown();
  }
});

test('uploaded file reflects into host filesystem', async ({ page }) => {
  test.setTimeout(90_000);
  const { teardown } = await provisionTestUser(page, admin, {
    username: TEST_USERNAME,
    groupId: OPENCLOUD_GROUP_ID,
  });

  try {
    await loginToOpenCloud(page);
    await navigateToPersonalSpace(page);
    // A freshly auto-provisioned user's personal space isn't necessarily
    // ready the instant the URL changes — the "New" button stays
    // disabled until it is, so wait for the file list itself.
    await page.getByText(/No files found|e2e-marker-/).first().waitFor({ timeout: 20_000 });

    // Upload a file via the UI. Unique filename per run — see
    // beforeEach() above on why a fixed name isn't safe here.
    const marker = `e2e-marker-${Date.now()}.txt`;
    const tmpDir = mkdtempSync(join(tmpdir(), 'e2e-opencloud-upload-'));
    const filePath = join(tmpDir, marker);
    writeFileSync(filePath, `${TEST_USERNAME} upload at ${new Date().toISOString()}\n`);

    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.getByRole('button', { name: /new/i }).click({ timeout: 20_000 });
    await page.getByRole('menuitem', { name: 'Files Upload' }).click();
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles(filePath);

    await expect(page.getByText(marker)).toBeVisible({ timeout: 15_000 });

    // The core assertion: OpenCloud's posix storage driver must mirror
    // the uploaded file into the host filesystem tree under the
    // username-templated personal space directory (design intent
    // documented in modules/opencloud/design.md). Assimilation isn't
    // instantaneous, so poll briefly rather than asserting immediately.
    const hostFilePath = join(USER_DIR, marker);
    await expect
      .poll(() => existsSync(hostFilePath), { timeout: 15_000, intervals: [500] })
      .toBe(true);

    // Best-effort cleanup of just this run's file. Safe to do via raw fs
    // (unlike beforeEach's directory) since its unique name is never
    // reused, so a stale id-cache entry for it can never be hit again.
    rmSync(hostFilePath, { force: true });
  } finally {
    await teardown();
  }
});

// Shared by both tests: OpenCloud's login page redirects to pocket-id as
// the sole OIDC provider (OC_EXCLUDE_RUN_SERVICES=idp disables the
// built-in login), and lands back on OpenCloud authenticated.
async function loginToOpenCloud(page: import('@playwright/test').Page): Promise<void> {
  await page.goto('/');
  await clickIfPresent(page.getByRole('button', { name: /log ?in/i }));

  // The test user's pocket-id session (from provisionTestUser's /lc/
  // login) and its OAuth consent grant for this client both persist
  // across runs now that the user itself is stable (see
  // tests/e2e/design.md). From the second run on this typically means
  // silent SSO: OpenCloud redirects through pocket-id and back so fast
  // there's no observable navigation to pocket-id's origin to wait for.
  // Only drive the passkey/consent UI if we actually land there.
  try {
    await page.waitForURL(new RegExp(`^${escapeRegExp(POCKET_ID_URL)}`), { timeout: 8_000 });
    await loginViaPasskey(page);
  } catch {
    // Silent SSO — already authenticated, nothing to click through.
  }

  await page.waitForURL(/\/files\//, { timeout: 15_000 });
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// The web app's own OIDC token, as it stores it for its own Graph API
// calls (see oc_oAuth.user:<issuer>:<clientId> in localStorage) — reused
// here rather than a separate admin credential, since this only needs to
// see what the logged-in user can already see.
//
// Needed because the post-login redirect doesn't reliably land on the
// personal space's own file listing — observed landing on the general
// "Spaces > Projects" overview instead, inconsistently across
// otherwise-identical runs (see tests/e2e/design.md's "Known Gap"
// section for the fuller history, including that this was chased down
// to a genuine orphaned-Caddy-process bug in scripts/stack.sh, now
// fixed — this Graph-API-based navigation is kept regardless since it's
// more robust than relying on the app's own post-login routing either
// way).
async function navigateToPersonalSpace(page: import('@playwright/test').Page): Promise<void> {
  const webUrl = await page.evaluate(async () => {
    const key = Object.keys(localStorage).find((k) => k.startsWith('oc_oAuth.user'));
    const token = JSON.parse(localStorage.getItem(key!)!).access_token;
    const url =
      '/graph/v1beta1/me/drives?$filter=' + encodeURIComponent('driveType eq personal');
    // The personal drive can take a moment to become listable right
    // after a freshly auto-provisioned user's first login.
    for (let attempt = 0; attempt < 20; attempt++) {
      const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
      const { value } = await res.json();
      if (value?.[0]?.webUrl) return value[0].webUrl as string;
      await new Promise((r) => setTimeout(r, 1500));
    }
    throw new Error('personal drive never appeared in /me/drives');
  });
  await page.goto(new URL(webUrl).pathname);
}
