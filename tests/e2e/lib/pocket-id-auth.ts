import type { Page } from '@playwright/test';

// Shared passkey-authentication helper for any pocket-id-fronted service
// under test (currently only OpenCloud; see tests/e2e/design.md for why
// this is split out as a reusable module rather than inlined into
// specs/opencloud.spec.ts).
//
// Ceremony details (usernameless/resident-key login, the "Add Passkey" /
// "Authenticate" button labels, the /lc/{token} magic-link route) are
// verified against pocket-id v2.11.0's own source and its Playwright
// fixtures (tests/utils/passkey.util.ts, tests/utils/auth.util.ts,
// tests/specs/account-settings.spec.ts, tests/specs/one-time-access-token.spec.ts
// in github.com/pocket-id/pocket-id), not guessed.

export interface PocketIdAdmin {
  baseUrl: string;
  apiKey: string;
}

// The test Caddy's cert chains to a copy of production's internal CA
// (see tests/e2e/scripts/stack.sh's ensure_test_ca) that this Node
// process has no reason to have imported into its own trust store — same
// reasoning as playwright.config.ts's ignoreHTTPSErrors, just for the
// plain Node fetch() calls this admin-API helper makes outside the
// browser. Only ever talks to this worktree's own isolated test
// instance, never anything external, so disabling verification
// process-wide is scoped enough to be safe.
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

async function api(
  admin: PocketIdAdmin,
  method: string,
  path: string,
  body?: unknown,
): Promise<Response> {
  const res = await fetch(`${admin.baseUrl}${path}`, {
    method,
    headers: {
      'X-API-KEY': admin.apiKey,
      'Content-Type': 'application/json',
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!res.ok) {
    throw new Error(
      `Pocket ID admin API ${method} ${path} failed: ${res.status} ${await res.text()}`,
    );
  }
  return res;
}

export interface TestUser {
  id: string;
  username: string;
}

async function findUserByUsername(
  admin: PocketIdAdmin,
  username: string,
): Promise<TestUser | undefined> {
  const res = await api(admin, 'GET', `/api/users?search=${encodeURIComponent(username)}`);
  const { data } = (await res.json()) as { data: Array<{ id: string; username: string }> };
  const match = data.find((u) => u.username === username);
  return match ? { id: match.id, username: match.username } : undefined;
}

// Test identity is stable, not disposable-per-run: OpenCloud tracks a
// user by pocket-id's `sub` internally, but templates its on-disk
// personal-space directory from the *username*
// (STORAGE_USERS_POSIX_PERSONAL_SPACE_PATH_TEMPLATE — see
// modules/opencloud/design.md). Deleting and recreating the pocket-id
// user each run gives it a fresh `sub` every time while OpenCloud's own
// data persists across runs (tests/e2e/design.md), which left OpenCloud
// pointing at a stale identity for that directory and broke write
// permissions on the second run — confirmed empirically (first run after
// a clean OpenCloud data dir passed, the very next run failed with the
// space's "New" button permanently disabled). Reusing the same user
// avoids this: only the passkey *credential* is replaced each run (see
// clearPasskeys() in provisionTestUser), never the user/sub itself.
async function findOrCreateUser(
  admin: PocketIdAdmin,
  opts: { username: string; groupId: string },
): Promise<TestUser> {
  const existing = await findUserByUsername(admin, opts.username);
  if (existing) return existing;

  const res = await api(admin, 'POST', '/api/users', {
    username: opts.username,
    email: `${opts.username}@e2e.invalid`,
    firstName: 'E2E',
    lastName: 'Runner',
    isAdmin: false,
  });
  const user = (await res.json()) as { id: string };

  await api(admin, 'PUT', `/api/users/${user.id}/user-groups`, {
    userGroupIds: [opts.groupId],
  });

  return { id: user.id, username: opts.username };
}

async function clearPasskeys(admin: PocketIdAdmin, userId: string): Promise<void> {
  const res = await api(admin, 'GET', `/api/users/${userId}/webauthn-credentials`);
  const credentials = (await res.json()) as Array<{ id: string }>;
  for (const credential of credentials) {
    await api(admin, 'DELETE', `/api/users/${userId}/webauthn-credentials/${credential.id}`);
  }
}

// One-time login-code link (POST /api/users/{id}/one-time-access-token),
// consumed by navigating the browser to /lc/{token}. This is the only
// non-email, non-signup path pocket-id offers to get a freshly
// API-created user into an authenticated browser session so it can
// register its first passkey — email-based one-time access is disabled
// (EMAIL_ONE_TIME_ACCESS_AS_*=false, matching production; see
// modules/pocket-id/design.md) and open signups are disabled too
// (ALLOW_USER_SIGNUPS=disabled).
async function createOneTimeAccessToken(admin: PocketIdAdmin, userId: string): Promise<string> {
  const res = await api(admin, 'POST', `/api/users/${userId}/one-time-access-token`, {});
  const { token } = (await res.json()) as { token: string };
  return token;
}

export interface VirtualAuthenticator {
  authenticatorId: string;
}

// Enables the Chrome DevTools Protocol WebAuthn virtual authenticator on
// the given page's browser context. hasResidentKey/hasUserVerification
// match pocket-id's own usernameless/discoverable-credential login flow
// (confirmed via its passkey.util.ts fixture); isUserVerified: true plus
// the default automaticPresenceSimulation means no human interaction is
// needed to satisfy the ceremony.
export async function setupVirtualAuthenticator(page: Page): Promise<VirtualAuthenticator> {
  const client = await page.context().newCDPSession(page);
  await client.send('WebAuthn.enable');
  const { authenticatorId } = await client.send('WebAuthn.addVirtualAuthenticator', {
    options: {
      protocol: 'ctap2',
      transport: 'internal',
      hasResidentKey: true,
      hasUserVerification: true,
      isUserVerified: true,
    },
  });
  return { authenticatorId };
}

// Drives the actual WebAuthn *registration* ceremony (a fresh credential,
// not a pre-seeded one — unlike pocket-id's own fixtures, our disposable
// user has no existing passkey to inject). The virtual authenticator set
// up by setupVirtualAuthenticator() must already be active on this page's
// context; no credential should be pre-added, so `navigator.credentials
// .create()` generates a brand-new resident credential that the same
// authenticator instance can later assert against for login.
export async function registerPasskey(
  page: Page,
  pocketIdBaseUrl: string,
  oneTimeAccessToken: string,
): Promise<void> {
  await page.goto(`${pocketIdBaseUrl}/lc/${oneTimeAccessToken}`);
  await page.waitForURL('**/settings/account');

  // A brand-new user with zero passkeys also shows an alert banner with
  // its own "Add Passkey" action, so the plain role/name locator is
  // ambiguous (2 matches). Scope to the passkey list section specifically.
  await page.getByRole('list').getByRole('button', { name: 'Add Passkey' }).click();
  await page.getByLabel('Name', { exact: true }).fill('e2e-test-runner');
  await page.getByLabel('Name Passkey').getByRole('button', { name: 'Save' }).click();
}

// Completes whatever pocket-id login screen the browser currently sits on
// (reached via a service's OIDC redirect, or a direct /login visit). The
// resident credential registered by registerPasskey() lives in the same
// virtual authenticator for the lifetime of this browser context, so no
// username entry or fresh credential injection is needed here.
export async function loginViaPasskey(page: Page): Promise<void> {
  await clickIfPresent(page.getByRole('button', { name: 'Authenticate' }));

  // First-time client authorization shows a consent screen ("<Client>
  // wants to access ... Email/Profile/Groups") — pocket-id's OIDC
  // clients require consent by default (no skipConsent set at creation
  // in stack.sh's bootstrap_if_needed). Since registerPasskey() already
  // establishes an authenticated session (the one-time-access-token
  // login), this is usually reached directly without an "Authenticate"
  // step at all.
  await clickIfPresent(page.getByRole('button', { name: 'Sign in' }));
}

// locator.isVisible() checks the *current* DOM snapshot and does not wait
// for an element that hasn't rendered yet, even with a `timeout` passed —
// unlike locator.click()'s built-in actionability wait. Using isVisible()
// here previously raced pocket-id's client-side interaction routing and
// silently skipped screens that hadn't finished rendering yet.
export async function clickIfPresent(locator: ReturnType<Page['getByRole']>, timeout = 5_000): Promise<void> {
  try {
    await locator.click({ timeout });
  } catch {
    // Not present within the timeout — nothing to do.
  }
}

// Full per-test-run lifecycle: find-or-create the (stable, reused) test
// user, replace its passkey with a fresh one for this run's virtual
// authenticator, and return a no-op teardown (kept for interface
// symmetry / a natural place to hang future per-run cleanup — see
// tests/e2e/design.md on why the user itself is stable rather than
// disposable-per-run).
export async function provisionTestUser(
  page: Page,
  admin: PocketIdAdmin,
  opts: { username: string; groupId: string },
): Promise<{ user: TestUser; teardown: () => Promise<void> }> {
  const user = await findOrCreateUser(admin, opts);
  await clearPasskeys(admin, user.id);
  const token = await createOneTimeAccessToken(admin, user.id);
  await setupVirtualAuthenticator(page);
  await registerPasskey(page, admin.baseUrl, token);

  return {
    user,
    teardown: async () => {},
  };
}
