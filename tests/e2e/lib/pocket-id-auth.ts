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

// Completes the pocket-id consent screen the browser lands on after a
// service's OIDC redirect ("<Client> wants to access ...
// Email/Profile/Groups" — pocket-id's OIDC clients require consent by
// default, no skipConsent set at creation in stack.sh's
// bootstrap_if_needed). Only every caller's actual usage: registerPasskey()
// has already established an authenticated pocket-id session (the
// one-time-access-token login) by the time this runs, so there is no
// separate "Authenticate" step to click through — measured directly: a
// speculative click there timed out (5s) on every call before it was
// removed. If a caller ever needs this from a genuinely unauthenticated
// state, that's a different, currently-untested flow this helper doesn't
// cover.
export async function loginViaPasskey(page: Page): Promise<void> {
  await page.getByRole('button', { name: 'Sign in' }).click({ timeout: 15_000 });
}

// Revokes the current browser session's own OIDC client authorization
// (DELETE /api/oidc/users/me/authorized-clients/{clientId} — "me"-scoped,
// so this must run through page.request to reuse the browser context's
// pocket-id session cookie, not the admin API key: pocket-id has no
// admin-scoped equivalent that revokes on another user's behalf). Used to
// force pocket-id's first-time consent screen deterministically, instead
// of relying on whichever state a worktree's prior runs happened to leave
// consent in. A 404 means the client was never authorized in the first
// place (verified against oidc_service.go's RevokeAuthorizedClient,
// which returns apperror.NotFound for exactly this case) — already the
// desired end state, not an error.
export async function revokeOwnClientAuthorization(
  page: Page,
  pocketIdBaseUrl: string,
  clientId: string,
): Promise<void> {
  const res = await page.request.delete(
    `${pocketIdBaseUrl}/api/oidc/users/me/authorized-clients/${clientId}`,
  );
  if (!res.ok() && res.status() !== 404) {
    throw new Error(
      `revoke client authorization failed: ${res.status()} ${await res.text()}`,
    );
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
