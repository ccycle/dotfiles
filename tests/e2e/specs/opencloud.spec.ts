import { test, expect } from '@playwright/test';
import { existsSync, rmSync, writeFileSync, mkdtempSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import {
  provisionTestUser,
  loginViaPasskey,
  revokeOwnClientAuthorization,
  type PocketIdAdmin,
} from '../lib/pocket-id-auth';

// Env vars are set by tests/e2e/scripts/stack.sh before invoking
// `playwright test`; see tests/e2e/design.md for the isolated per-worktree
// stack this test runs against (never production).
const POCKET_ID_URL = requireEnv('POCKET_ID_URL');
const POCKET_ID_API_KEY = requireEnv('POCKET_ID_API_KEY');
const OPENCLOUD_GROUP_ID = requireEnv('OPENCLOUD_GROUP_ID');
const OPENCLOUD_OIDC_CLIENT_ID = requireEnv('OPENCLOUD_OIDC_CLIENT_ID');
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

// Deliberately NOT pre-creating USER_DIR here. reva's posix driver
// (pkg/storage/fs/posix/lookup/lookup.go GenerateSpaceID) only takes the
// healthy "generate a fresh space id" path when the personal-space
// directory is entirely absent (IsNotExist) or has an explicitly-unset
// attribute (IsAttrUnset). A directory that already exists without a
// space-id xattr — exactly what mkdirSync produced here — falls through
// to `len(spaceID) == 0` and returns a permanent
// "encountered empty space id on disk" error on every future login for
// this user, because XattrsBackend.IdentifyPath
// (metadata/xattrs_backend.go) silently discards xattr.Get's error
// instead of surfacing ENODATA as IsAttrUnset. OpenCloud's own space
// creation is what must create this directory, on first login.

// Ordered deliberately ahead of the other tests: this suite runs with
// workers: 1 / fullyParallel: false (playwright.config.ts), so tests in
// one file execute strictly in declaration order. This test explicitly
// revokes OpenCloud's OIDC client authorization first, so it — and only
// it — exercises pocket-id's first-time consent screen. Every test after
// it inherits an already-granted authorization, matching real-world
// steady state (see "returning user" below).
test('first-time OIDC authorization shows pocket-id consent screen', async ({ page }) => {
  test.setTimeout(60_000);
  const { teardown } = await provisionTestUser(page, admin, {
    username: TEST_USERNAME,
    groupId: OPENCLOUD_GROUP_ID,
  });

  try {
    await revokeOwnClientAuthorization(page, POCKET_ID_URL, OPENCLOUD_OIDC_CLIENT_ID);

    await page.goto('/');
    // Unlike loginToOpenCloud()'s steady-state helper below, this is a
    // hard assertion, not a best-effort click: with authorization freshly
    // revoked, landing on pocket-id is the whole point of this test.
    await page.waitForURL(new RegExp(`^${escapeRegExp(POCKET_ID_URL)}`), { timeout: 15_000 });
    await loginViaPasskey(page);
    await page.waitForURL(/\/files\//, { timeout: 15_000 });

    await expect(page.getByRole('button', { name: 'My Account' })).toBeVisible({
      timeout: 20_000,
    });
  } finally {
    await teardown();
  }
});

test('returning user gets silent SSO on subsequent logins', async ({ page }) => {
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

    // Upload a file via the UI. Unique filename per run, so a stale
    // id-cache entry for a previous run's file can never be hit.
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

    // Best-effort cleanup of just this run's file (never the directory
    // itself — see the module-level comment above on why USER_DIR must
    // only ever be created by OpenCloud's own space provisioning).
    rmSync(hostFilePath, { force: true });
  } finally {
    await teardown();
  }
});

// Shared by the two tests that run after "first-time OIDC authorization"
// above: OpenCloud's OIDC client authorization is guaranteed already
// granted by this point in the file (workers: 1 / fullyParallel: false
// in playwright.config.ts makes this file's test order deterministic),
// so this asserts the silent-SSO path directly. Measurement showed both
// a speculative click on OpenCloud's own landing-page login button and a
// wait for a pocket-id redirect consistently hit their full timeouts
// (5s / 8s, every run) once authorization was already granted — 13s
// wasted per call on a branch that structurally never fires here. The
// "first-time" test above is the only place that flow is real, and it
// asserts it directly instead of guessing.
async function loginToOpenCloud(page: import('@playwright/test').Page): Promise<void> {
  await page.goto('/');
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
