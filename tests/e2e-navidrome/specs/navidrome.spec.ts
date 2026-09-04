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
const NAVIDROME_MUSIC_DIR = requireEnv("NAVIDROME_TEST_MUSIC_DIR");

const TEST_USER = "e2e";
const TEST_PASS = "e2e-test-pass";

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} must be set (see tests/e2e-navidrome/scripts/stack.sh)`);
  }
  return value;
}

async function subsonicGet(request: any, endpoint: string, params: Record<string, string> = {}) {
  const qs = new URLSearchParams({
    u: TEST_USER,
    p: TEST_PASS,
    f: "json",
    v: "1.16.1",
    c: "e2e-test",
    ...params,
  });
  const res = await request.get(`/rest/${endpoint}?${qs}`);
  return res.json();
}

test("web UI loads and create initial admin user via signup form", async ({ page }) => {
  test.setTimeout(60_000);
  await page.goto("/");

  // Navidrome's first-run shows a signup form (username, password, confirm)
  const usernameInput = page.locator('input[name="username"]');
  await expect(usernameInput).toBeVisible({ timeout: 15_000 });

  await usernameInput.fill(TEST_USER);
  await page.locator('input[name="password"]').fill(TEST_PASS);
  await page.locator('input[name="confirmPassword"]').fill(TEST_PASS);
  await page.locator('button[type="submit"]').click();

  // After signup, Navidrome redirects to the login page or main UI
  await expect(page).toHaveURL(/\/|#/, { timeout: 15_000 });
});

test("Subsonic API ping responds with ok", async ({ request }) => {
  test.setTimeout(15_000);
  const ping = await subsonicGet(request, "ping");
  expect(ping["subsonic-response"]?.status).toBe("ok");
  expect(ping["subsonic-response"]?.serverVersion).toBeTruthy();
});

test("music library scan picks up file via Subsonic API", async ({ request }) => {
  test.setTimeout(90_000);

  // Write a parseable FLAC: valid STREAMINFO (44.1kHz stereo 16-bit,
  // 1s) plus a Vorbis comment with ARTIST, so the scanner indexes it.
  // No audio frames — TagLib reads tags and duration from metadata alone.
  const streamInfo = Buffer.alloc(34);
  streamInfo.writeUInt16BE(4096, 0); // min block size
  streamInfo.writeUInt16BE(4096, 2); // max block size
  streamInfo.writeUIntBE(0, 4, 3); // min frame size (unknown)
  streamInfo.writeUIntBE(0, 7, 3); // max frame size (unknown)
  const sampleRate = 44100;
  const totalSamples = 44100;
  streamInfo[10] = sampleRate >> 12;
  streamInfo[11] = (sampleRate >> 4) & 0xff;
  streamInfo[12] = ((sampleRate & 0xf) << 4) | (1 << 1) | (15 >> 4);
  streamInfo[13] = ((15 & 0xf) << 4) | ((totalSamples >> 32) & 0xf);
  streamInfo.writeUInt32BE(totalSamples >>> 0, 14);
  // MD5 (bytes 18-33) stays zero.
  const vendor = Buffer.from("e2e-test");
  const comment = Buffer.from("ARTIST=E2E Artist");
  const vorbis = Buffer.alloc(4 + vendor.length + 4 + 4 + comment.length);
  let o = 0;
  vorbis.writeUInt32LE(vendor.length, o);
  o += 4;
  vendor.copy(vorbis, o);
  o += vendor.length;
  vorbis.writeUInt32LE(1, o);
  o += 4;
  vorbis.writeUInt32LE(comment.length, o);
  o += 4;
  comment.copy(vorbis, o);
  const flacHeader = Buffer.concat([
    Buffer.from("fLaC"),
    Buffer.from([0x00, 0x00, 0x00, 0x22]), // STREAMINFO, not last
    streamInfo,
    Buffer.from([0x84]), // Vorbis comment, last block
    Buffer.from([(vorbis.length >> 16) & 0xff, (vorbis.length >> 8) & 0xff, vorbis.length & 0xff]),
    vorbis,
  ]);
  const testFile = join(NAVIDROME_MUSIC_DIR, "e2e-test-track.flac");
  writeFileSync(testFile, flacHeader);

  // Trigger a scan
  const scan = await subsonicGet(request, "startScan");
  expect(scan["subsonic-response"]?.status).toBe("ok");

  // Poll getArtists until the scanned content appears
  let found = false;
  for (let attempt = 0; attempt < 30; attempt++) {
    const artists = await subsonicGet(request, "getArtists");
    const index = artists?.["subsonic-response"]?.artists?.index || [];
    if (index.length > 0) {
      found = true;
      break;
    }
    await new Promise((r) => setTimeout(r, 3000));
  }
  expect(found, "scanned artist appears in getArtists within poll window").toBe(true);

  // Verify the file is still on the host filesystem
  expect(existsSync(testFile), `file visible on host at ${testFile}`).toBe(true);
});
