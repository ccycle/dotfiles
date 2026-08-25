// E2E test for Immich (modules/immich), local-auth only - OIDC/passkey
// coverage is deliberately concentrated in tests/e2e's OpenCloud suite
// instead (see tests/e2e-immich/design.md), so this exercises Immich's
// own POST /api/auth/admin-sign-up + POST /api/auth/login directly.
//
// Runs against an isolated per-worktree stack (never modules/immich's
// real instance or data - see tests/e2e-immich/design.md).
import { test, expect, type APIRequestContext, type Page } from "@playwright/test";
import { existsSync, mkdtempSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

const IMMICH_URL = requireEnv("IMMICH_SERVER_URL");
const IMMICH_UPLOAD_DIR = requireEnv("IMMICH_UPLOAD_DIR");
// Immich's own default UPLOAD_LOCATION inside the container - the prefix
// AssetResponseDto.originalPath always starts with, and the exact bind
// mount source (modules/immich/compose.yaml) is IMMICH_UPLOAD_DIR on the
// host. Substituting one for the other maps a container path to its
// real host path without needing to know Immich's internal subfolder
// layout (upload/library/<userId>/...), which isn't part of its public API.
const CONTAINER_UPLOAD_ROOT = "/usr/src/app/upload";

const ADMIN_EMAIL = "e2e-admin@e2e.invalid";
const ADMIN_PASSWORD = "e2e-test-password-not-secret";
const ADMIN_NAME = "E2E Admin";

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} must be set (see tests/e2e-immich/scripts/stack.sh)`);
  }
  return value;
}

async function signUpAdmin(request: APIRequestContext): Promise<void> {
  const res = await request.post("/api/auth/admin-sign-up", {
    data: { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, name: ADMIN_NAME },
  });
  expect(res.ok(), `admin sign-up: ${res.status()} ${await res.text()}`).toBeTruthy();
}

// A "new version available" nag dialog appears on top of any first page
// load (onboarding, /photos, ...) whenever the pinned image version is
// behind Immich's latest release - unrelated to anything under test, but
// it blocks every other interaction on the page (including file uploads)
// until dismissed. isVisible() alone would race a not-yet-rendered
// dialog (see tests/e2e/lib/pocket-id-auth.ts's own note on this), so
// wait for it properly and only treat a real timeout as "never showed up".
async function dismissVersionNagIfPresent(page: Page): Promise<void> {
  try {
    await page.getByRole("button", { name: "Acknowledge" }).click({ timeout: 5_000 });
  } catch {
    // Dialog never appeared - nothing to dismiss.
  }
}

// Handles the login page directly (never the OAuth button - OIDC isn't
// configured for this stack, see stack.sh) and clears whatever one-time
// redirect a brand-new admin can land on afterward (password-change /
// onboarding), so callers land on the authenticated app reliably.
async function loginAsAdmin(page: Page): Promise<void> {
  await page.goto("/auth/login");
  await page.getByLabel("Email").fill(ADMIN_EMAIL);
  await page.getByLabel("Password").fill(ADMIN_PASSWORD);
  await page.getByRole("button", { name: "Login" }).click();

  await page.waitForURL(/\/auth\/change-password|\/auth\/onboarding|\/photos|\/\?/, {
    timeout: 15_000,
  });

  if (page.url().includes("/auth/change-password")) {
    // admin-sign-up's created user isn't force-flagged to change its
    // password in practice, but handle it if a future Immich version
    // does: keep the same password, just satisfy the form.
    await page.getByLabel("New password", { exact: true }).fill(ADMIN_PASSWORD);
    await page.getByLabel("Confirm password", { exact: true }).fill(ADMIN_PASSWORD);
    await page.getByRole("button", { name: /change password/i }).click();
    await page.waitForURL(/\/auth\/onboarding|\/photos|\/\?/, { timeout: 15_000 });
  }

  if (page.url().includes("/auth/onboarding")) {
    // An 8-step wizard (hello/theme/language/server_privacy/user_privacy/
    // storage_template/backup/mobile_app - +page.svelte's onboardingSteps)
    // whose only "Next" button relabels itself to the *next* step's title
    // every step, only reading "Done" on the last one - not something
    // worth click-matching through 7 times. The step is purely
    // URL-driven (`?step=<name>`, +page.svelte's own `$derived`), so jump
    // straight to the last step instead.
    await page.goto("/auth/onboarding?step=mobile_app");
    await dismissVersionNagIfPresent(page);
    await page.getByRole("button", { name: "Done" }).click();
    await page.waitForURL(/\/photos|\/\?/, { timeout: 15_000 });
  }

  // The nag dialog isn't onboarding-specific - it shows on the first
  // /photos load too (a plain login, no onboarding step at all, still
  // hits it) - so check again unconditionally on whatever page we ended
  // up on, or it silently blocks the very next interaction (e.g. the
  // upload button) for callers that don't know to expect it.
  await dismissVersionNagIfPresent(page);
}

test("local admin sign-up creates the first user and can log in", async ({ page, request }) => {
  test.setTimeout(60_000);
  await signUpAdmin(request);
  await loginAsAdmin(page);
  // Deliberately not asserting which specific view we land on (photos
  // grid vs onboarding-skip destination can vary by version) - only that
  // the app considers us logged in, via the account menu button present
  // on every authenticated view (NavigationBar.svelte).
  await expect(page.getByRole("button", { name: `${ADMIN_NAME} (${ADMIN_EMAIL})` })).toBeVisible({
    timeout: 20_000,
  });
});

test("uploaded photo reflects into host filesystem and generates a thumbnail", async ({
  page,
  request,
}) => {
  test.setTimeout(150_000);
  await loginAsAdmin(page);

  const marker = `e2e-marker-${Date.now()}.jpg`;
  const tmpDir = mkdtempSync(join(tmpdir(), "e2e-immich-upload-"));
  const filePath = join(tmpDir, marker);
  // A real, decodable 4x4 JPEG (generated with Pillow, `Image.new('RGB',
  // (4, 4)).save(..., 'JPEG')`) - not just a renamed .txt, and not a
  // hand-typed/truncated byte sequence either. Immich's upload endpoint
  // itself accepts near-arbitrary bytes with a .jpg name, but the
  // thumbnail-generation job that runs after does real JPEG decoding
  // (libvips/sharp) - measured directly that a malformed-but-plausible
  // fixture let the upload succeed while the thumbnail job failed
  // silently in the background with "VipsJpeg: Failed to decode DCT
  // block", never surfaced anywhere this suite would otherwise see it.
  const validJpeg = Buffer.from(
    "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAAEAAQDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDi6KKK+ZP3E//Z",
    "base64",
  );
  writeFileSync(filePath, validJpeg);

  const fileChooserPromise = page.waitForEvent("filechooser");
  // The empty-timeline call-to-action (main content area, not the navbar
  // "Upload" button - which Immich renders twice, once per breakpoint,
  // an ambiguity this unambiguous button sidesteps entirely) - same
  // underlying openFileUploadDialog() either way.
  await page.getByRole("button", { name: "Click to upload your first photo" }).click();
  const fileChooser = await fileChooserPromise;

  // Wait on the actual upload response rather than any UI-level signal:
  // measured directly that the timeline's empty-state placeholder does
  // not disappear on its own after a successful upload in this
  // environment (no reactive refresh without a reload/websocket update
  // this isolated stack doesn't rely on) - not a bug worth chasing, just
  // not a real completion signal. The API call it makes is.
  const uploadResponsePromise = page.waitForResponse(
    (res) => res.url().endsWith("/api/assets") && res.request().method() === "POST",
  );
  await fileChooser.setFiles(filePath);
  const uploadResponse = await uploadResponsePromise;
  expect(uploadResponse.status(), `asset upload: ${uploadResponse.status()}`).toBe(201);

  // The core assertion: Immich must actually persist the uploaded asset
  // to the host-bound upload directory (design intent - never trust the
  // UI alone), and must have generated a thumbnail for it, both via the
  // real API rather than re-deriving Immich's internal path scheme.
  const loginRes = await request.post("/api/auth/login", {
    data: { email: ADMIN_EMAIL, password: ADMIN_PASSWORD },
  });
  expect(loginRes.ok()).toBeTruthy();
  const { accessToken } = (await loginRes.json()) as { accessToken: string };

  let originalPath = "";
  let thumbGenerated = false;
  // The thumbnail-generation job queue can take a while to pick up its
  // first-ever job in a freshly-started stack (worker warm-up, not the
  // 1x1 image itself, which is trivial to actually process) - measured
  // directly that 20 attempts * 1.5s (30s) wasn't always enough.
  for (let attempt = 0; attempt < 40; attempt++) {
    const res = await request.post("/api/search/metadata", {
      headers: { Authorization: `Bearer ${accessToken}` },
      data: { originalFileName: marker },
    });
    expect(res.ok(), `search/metadata: ${res.status()} ${await res.text()}`).toBeTruthy();
    const body = (await res.json()) as {
      assets: { items: Array<{ originalPath: string; thumbhash: string | null }> };
    };
    const asset = body.assets.items[0];
    if (asset) {
      originalPath = asset.originalPath;
      thumbGenerated = asset.thumbhash !== null;
      if (thumbGenerated) break;
    }
    await new Promise((r) => setTimeout(r, 2000));
  }

  expect(originalPath, "uploaded asset findable via search/metadata").not.toBe("");
  expect(thumbGenerated, "thumbnail generated (thumbhash populated) within the poll window").toBe(
    true,
  );

  expect(
    originalPath.startsWith(CONTAINER_UPLOAD_ROOT),
    `originalPath under ${CONTAINER_UPLOAD_ROOT}`,
  ).toBe(true);
  const hostFilePath = join(IMMICH_UPLOAD_DIR, originalPath.slice(CONTAINER_UPLOAD_ROOT.length));
  expect(existsSync(hostFilePath), `uploaded file visible on host at ${hostFilePath}`).toBe(true);
});
