// E2E test for Navidrome (modules/navidrome) — web UI, Subsonic API,
// and music library scanning. Runs against an isolated per-worktree
// stack (never modules/navidrome's real instance or data — see
// tests/e2e-navidrome/design.md).
//
// ND_EXTAUTH is disabled in the test stack (see design.md), so no
// Caddy forward_auth / PocketID chain is exercised here.
import { test, expect } from "@playwright/test";
import { writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const NAVIDROME_URL = requireEnv("NAVIDROME_TEST_URL");
const NAVIDROME_MUSIC_DIR = requireEnv("NAVIDROME_MUSIC_DIR");

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} must be set (see tests/e2e-navidrome/scripts/stack.sh)`);
  }
  return value;
}

test("web UI loads and shows login form", async ({ page }) => {
  test.setTimeout(30_000);
  await page.goto("/");
  // Navidrome's unauthenticated state shows a login form
  await expect(page.locator("input, form, [class*=login], [class*=Login]")).toBeVisible({
    timeout: 15_000,
  });
});

test("Subsonic API ping responds with valid XML", async ({ request }) => {
  test.setTimeout(15_000);
  const res = await request.get("/rest/ping");
  expect(res.ok(), `Subsonic ping: ${res.status()}`).toBeTruthy();
  const body = await res.text();
  expect(body).toContain("subsonic-response");
  expect(body).toContain('status="ok"');
});

test("music library scan picks up uploaded file via Subsonic API", async ({
  request,
}) => {
  test.setTimeout(90_000);

  // Place a minimal valid FLAC file in the music directory.
  // FLAC header: "fLaC" magic, then STREAMINFO metadata block.
  const flacHeader = Buffer.from([
    0x66, 0x4c, 0x41, 0x43, // "fLaC"
    0x00, 0x00, 0x00, 0x22, // STREAMINFO block header (type=0, length=34)
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, // padding
  ]);
  const testFile = join(NAVIDROME_MUSIC_DIR, "e2e-test-track.flac");
  writeFileSync(testFile, flacHeader);

  // Trigger a scan via the Subsonic API
  const scanRes = await request.get("/rest/startScan");
  expect(scanRes.ok(), `startScan: ${scanRes.status()}`).toBeTruthy();

  // Poll getArtists until the scanned content appears (scanner may take
  // a few seconds on first run).
  let found = false;
  for (let attempt = 0; attempt < 30; attempt++) {
    const artistsRes = await request.get("/rest/getArtists");
    const body = await artistsRes.json();
    const artists = body?.subsonicResponse?.artists?.index || [];
    if (artists.length > 0) {
      found = true;
      break;
    }
    await new Promise((r) => setTimeout(r, 3000));
  }
  expect(found, "scanned artist appears in getArtists within poll window").toBe(true);

  // Verify the file is still on the host filesystem
  expect(existsSync(testFile), `uploaded file visible on host at ${testFile}`).toBe(true);
});
