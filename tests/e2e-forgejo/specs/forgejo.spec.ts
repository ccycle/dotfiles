// E2E test for the Forgejo CI-runner / branch-protection / backup
// automation added in modules/forgejo/options.nix. Exercises the real
// Forgejo server binary and forgejo-runner binary the same way the
// launchd bootstrap jobs do, against an isolated per-worktree stack
// (never modules/forgejo's real instance or data - see
// tests/e2e-forgejo/design.md).
//
// Only the Forgejo REST API calls go through Playwright's `request`
// fixture - that's the part `trace: 'on'` (playwright.config.ts) makes
// inspectable in trace viewer's Network tab. Runner registration and
// `forgejo dump` go through `docker compose exec`, which isn't HTTP and
// so isn't traced the same way; their output is attached to the report
// instead (see `attachLog`).
import { test, expect } from "@playwright/test";
import { execFileSync, spawn, type ChildProcess } from "node:child_process";
import {
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
  existsSync,
  statSync,
  readdirSync,
} from "node:fs";
import path from "node:path";
import os from "node:os";

const BASE_URL = requireEnv("FORGEJO_EXTERNAL_URL");
const PROJECT_NAME = requireEnv("FORGEJO_TEST_PROJECT_NAME");
const FORGEJO_COMPOSE_FILE = requireEnv("FORGEJO_COMPOSE_FILE");
const OVERRIDE_COMPOSE_FILE = requireEnv("FORGEJO_OVERRIDE_COMPOSE_FILE");
const ENV_FILE = requireEnv("FORGEJO_ENV_FILE");
const STATE_DIR = requireEnv("FORGEJO_STATE_DIR");
const FORGEJO_DATA_DIR = requireEnv("FORGEJO_DATA_DIR");

const ADMIN_USER = "e2e-admin";
const ADMIN_EMAIL = "e2e-admin@example.invalid";
const TEST_REPO = "e2e-test-repo";
const RUNNER_NAME = "e2e-runner";
const RUNNER_LABELS = "macos-latest:host,native:host";
const BACKUP_RETENTION_COUNT = 7; // must match modules/forgejo/options.nix's backupRetentionCount default

function requireEnv(name: string): string {
  const v = process.env[name];
  if (!v)
    throw new Error(
      `missing required env var ${name} - run via scripts/run.sh, not npx playwright test directly`,
    );
  return v;
}

function compose(...args: string[]): string {
  return execFileSync("docker", [
    "compose",
    "-p",
    PROJECT_NAME,
    "-f",
    FORGEJO_COMPOSE_FILE,
    "-f",
    OVERRIDE_COMPOSE_FILE,
    "--env-file",
    ENV_FILE,
    ...args,
  ]).toString();
}

// Mirrors forgejo-runner-bootstrap/forgejo-backup's `docker-compose exec`
// calls exactly, including `-u git` - see modules/forgejo/design.md on
// why the exec user can't be left at its root default.
function fexec(...args: string[]): string {
  return compose("exec", "-T", ...args).trim();
}

function git(...args: string[]): string {
  return execFileSync("git", args).toString().trim();
}

test("forgejo CI runner + branch protection + backup", async ({ request }, testInfo) => {
  let runnerProc: ChildProcess | undefined;
  let runnerLog = "";

  const attachLog = async (name: string, body: string) => {
    await testInfo.attach(name, { body, contentType: "text/plain" });
  };

  // A single chronological narrative of the whole run, attached as one
  // file at the end - trace viewer's Actions list and per-step Network
  // tab are the precise record, but reading eight steps' worth of API
  // calls and docker-exec output means clicking through each separately.
  // This is the "read it all in execution order in one place" view.
  const transcript: string[] = [];
  const note = (line: string) => {
    transcript.push(`[${new Date().toISOString()}] ${line}`);
  };
  const step = async <T>(name: string, fn: () => Promise<T>): Promise<T> => {
    note(`\n=== ${name} ===`);
    const result = await test.step(name, fn);
    return result;
  };

  try {
    let adminToken = "";
    await step("bootstrap a local admin user + API token (no OIDC/browser needed)", async () => {
      const password = execFileSync("openssl", ["rand", "-base64", "24"]).toString().trim();
      const createOut = fexec(
        "-u",
        "git",
        "forgejo",
        "forgejo",
        "admin",
        "user",
        "create",
        "--username",
        ADMIN_USER,
        "--password",
        password,
        "--email",
        ADMIN_EMAIL,
        "--admin",
        "--must-change-password=false",
      );
      note(`$ forgejo admin user create --username ${ADMIN_USER} --admin\n${createOut}`);
      await attachLog("admin-user-create.log", createOut);

      adminToken = fexec(
        "-u",
        "git",
        "forgejo",
        "forgejo",
        "admin",
        "user",
        "generate-access-token",
        "-u",
        ADMIN_USER,
        "-t",
        "e2e",
        "--scopes",
        "all",
        "--raw",
      );
      expect(adminToken, "admin API token issued").not.toBe("");
      note("admin API token issued");
    });

    const authHeaders = () => ({ Authorization: `token ${adminToken}` });

    await step("create a test repo via the Forgejo API", async () => {
      const res = await request.post("/api/v1/user/repos", {
        headers: authHeaders(),
        data: { name: TEST_REPO, auto_init: true, default_branch: "main" },
      });
      expect(res.ok(), `repo create: ${res.status()} ${await res.text()}`).toBeTruthy();
      note(`POST /api/v1/user/repos {name: "${TEST_REPO}"} -> ${res.status()}`);

      const getRes = await request.get(`/api/v1/repos/${ADMIN_USER}/${TEST_REPO}`, {
        headers: authHeaders(),
      });
      expect(getRes.ok(), "test repo exists after creation").toBeTruthy();
      note(
        `GET /api/v1/repos/${ADMIN_USER}/${TEST_REPO} -> ${getRes.status()} (confirmed it exists)`,
      );
    });

    const repoDir = path.join(STATE_DIR, "checkout");
    await step("push a minimal Forgejo Actions workflow", async () => {
      rmSync(repoDir, { recursive: true, force: true });
      const cloneUrl =
        BASE_URL.replace("http://", `http://${ADMIN_USER}:${adminToken}@`) +
        `/${ADMIN_USER}/${TEST_REPO}.git`;
      git("clone", "-q", cloneUrl, repoDir);
      note(`cloned ${ADMIN_USER}/${TEST_REPO} to ${repoDir}`);
      mkdirSync(path.join(repoDir, ".forgejo/workflows"), { recursive: true });
      writeFileSync(
        path.join(repoDir, ".forgejo/workflows/e2e.yaml"),
        'name: E2E\non: [push]\njobs:\n  verify:\n    runs-on: macos-latest\n    steps:\n      - run: echo "e2e runner check"\n',
      );
      git(
        "-C",
        repoDir,
        "-c",
        `user.email=${ADMIN_EMAIL}`,
        "-c",
        `user.name=${ADMIN_USER}`,
        "add",
        ".forgejo/workflows/e2e.yaml",
      );
      git(
        "-C",
        repoDir,
        "-c",
        `user.email=${ADMIN_EMAIL}`,
        "-c",
        `user.name=${ADMIN_USER}`,
        "commit",
        "-q",
        "-m",
        "add e2e workflow",
      );
      note("wrote and committed .forgejo/workflows/e2e.yaml (not pushed yet)");
    });

    const runnerDir = path.join(STATE_DIR, "runner");
    let secretFile = "";
    let configFile = "";
    await step(
      "register a host-execution runner the way forgejo-runner-bootstrap does",
      async () => {
        mkdirSync(runnerDir, { recursive: true });
        secretFile = path.join(runnerDir, "secret");
        configFile = path.join(runnerDir, "config.yaml");

        const secret = fexec(
          "-u",
          "git",
          "forgejo",
          "forgejo",
          "forgejo-cli",
          "actions",
          "generate-secret",
        );
        writeFileSync(secretFile, secret, { mode: 0o600 });
        note("generated runner registration secret");

        const uuid = fexec(
          "-u",
          "git",
          "forgejo",
          "forgejo",
          "forgejo-cli",
          "actions",
          "register",
          "--secret",
          secret,
          "--name",
          RUNNER_NAME,
          "--labels",
          RUNNER_LABELS,
        );
        expect(uuid, "runner UUID returned").not.toBe("");
        note(`registered runner "${RUNNER_NAME}" (labels: ${RUNNER_LABELS}), uuid=${uuid}`);

        const generatedConfig = execFileSync("nix", [
          "shell",
          "nixpkgs#forgejo-runner",
          "-c",
          "forgejo-runner",
          "generate-config",
        ]).toString();
        writeFileSync(configFile, generatedConfig);
        note(`generated forgejo-runner config.yaml at ${configFile}`);

        execFileSync(
          "nix",
          [
            "shell",
            "nixpkgs#yq-go",
            "-c",
            "yq",
            "-i",
            ".server.connections.forgejo.url = strenv(RUNNER_URL) | " +
              ".server.connections.forgejo.uuid = strenv(RUNNER_UUID) | " +
              ".server.connections.forgejo.token_url = strenv(RUNNER_TOKEN_URL) | " +
              '.runner.labels = ["macos-latest:host", "native:host"]',
            configFile,
          ],
          {
            env: {
              ...process.env,
              RUNNER_URL: `${BASE_URL}/`,
              RUNNER_UUID: uuid,
              RUNNER_TOKEN_URL: `file:${secretFile}`,
            },
          },
        );
        note("patched config.yaml with server URL/uuid/token and labels");

        runnerProc = spawn(
          "nix",
          [
            "shell",
            "nixpkgs#forgejo-runner",
            "-c",
            "forgejo-runner",
            "daemon",
            "--config",
            configFile,
          ],
          {
            stdio: ["ignore", "pipe", "pipe"],
          },
        );
        runnerProc.stdout?.on("data", (d) => (runnerLog += d.toString()));
        runnerProc.stderr?.on("data", (d) => (runnerLog += d.toString()));
        note(`started forgejo-runner daemon (pid ${runnerProc.pid})`);

        await new Promise((r) => setTimeout(r, 3000));
        expect(runnerProc.exitCode, "runner daemon process alive").toBeNull();
        expect(runnerLog, "runner connected to instance").toMatch(/declared successfully/i);
        note(`confirmed runner daemon connected:\n${runnerLog}`);
        await attachLog("runner-daemon.log", runnerLog);
      },
    );

    let statusContext = "";
    await step(
      "push, trigger the workflow on the runner, capture the real status context",
      async () => {
        git("-C", repoDir, "push", "-q", "origin", "main");
        const sha = git("-C", repoDir, "rev-parse", "HEAD");
        note(`pushed workflow commit ${sha} to main`);

        let attempts = 0;
        for (let i = 0; i < 60; i++) {
          attempts = i + 1;
          const res = await request.get(
            `/api/v1/repos/${ADMIN_USER}/${TEST_REPO}/commits/${sha}/statuses`,
            { headers: authHeaders() },
          );
          if (res.ok()) {
            const body = (await res.json()) as Array<{ context?: string }>;
            if (body[0]?.context) {
              statusContext = body[0].context;
              break;
            }
          }
          await new Promise((r) => setTimeout(r, 2000));
        }
        expect(statusContext, "workflow ran and reported a commit status").not.toBe("");
        // The value modules/forgejo's branchProtections.*.statusCheckContexts
        // must match - see modules/forgejo/design.md.
        console.log(`actual status context reported by Forgejo Actions: '${statusContext}'`);
        note(
          `polled commit-status API (${attempts} attempt(s)) -> observed context: '${statusContext}'`,
        );
        await attachLog("observed-status-context.txt", statusContext);
      },
    );

    await step(
      "apply branch protection via the API the way forgejo-branch-protection-bootstrap does",
      async () => {
        const createRes = await request.post(
          `/api/v1/repos/${ADMIN_USER}/${TEST_REPO}/branch_protections`,
          {
            headers: authHeaders(),
            data: {
              branch_name: "main",
              enable_push: true,
              enable_push_whitelist: false,
              enable_status_check: true,
              status_check_contexts: [statusContext],
              require_signed_commits: false,
            },
          },
        );
        expect(
          createRes.ok(),
          `branch protection create: ${createRes.status()} ${await createRes.text()}`,
        ).toBeTruthy();
        note(
          `POST branch_protections {status_check_contexts: ["${statusContext}"]} -> ${createRes.status()}`,
        );

        const getRes = await request.get(
          `/api/v1/repos/${ADMIN_USER}/${TEST_REPO}/branch_protections/main`,
          { headers: authHeaders() },
        );
        expect(getRes.ok()).toBeTruthy();
        const protection = await getRes.json();
        expect(protection.enable_push, "branch protection enable_push=true").toBe(true);
        expect(protection.enable_status_check, "branch protection enable_status_check=true").toBe(
          true,
        );
        expect(
          protection.status_check_contexts,
          "branch protection status_check_contexts matches",
        ).toContain(statusContext);
        note("read back branch_protections/main and confirmed the fields stuck");
      },
    );

    await step(
      'force-push rejection (no separate "block force push" field exists - see design.md)',
      async () => {
        git(
          "-C",
          repoDir,
          "commit",
          "-q",
          "--allow-empty",
          "-m",
          "rewrite for force-push test",
          "--amend",
        );
        let rejected = false;
        try {
          execFileSync("git", ["-C", repoDir, "push", "-q", "--force", "origin", "main"], {
            stdio: "pipe",
          });
        } catch {
          rejected = true;
        }
        expect(rejected, "force-push to protected main is rejected").toBe(true);
        note("git push --force to protected main was rejected, as expected");
      },
    );

    await step("forgejo dump lands on the host side of the bind mount", async () => {
      const dumpDir = path.join(FORGEJO_DATA_DIR, "dumps");
      mkdirSync(dumpDir, { recursive: true });
      const containerDumpFile = `/data/dumps/e2e-dump-${Date.now()}.zip`;
      const dumpOut = fexec(
        "-u",
        "git",
        "forgejo",
        "forgejo",
        "dump",
        "--file",
        containerDumpFile,
        "--type",
        "zip",
      );
      note(`$ forgejo dump --file ${containerDumpFile} --type zip\n${dumpOut}`);
      await attachLog("forgejo-dump.log", dumpOut);

      const hostFile = path.join(dumpDir, path.basename(containerDumpFile));
      expect(
        existsSync(hostFile),
        "forgejo dump produced a file visible on the host bind mount",
      ).toBe(true);
      expect(statSync(hostFile).size).toBeGreaterThan(0);
      note(`confirmed ${hostFile} exists on host (${statSync(hostFile).size} bytes)`);
    });

    await step(
      `retention pruning keeps exactly ${BACKUP_RETENTION_COUNT} generations`,
      async () => {
        const retentionDir = mkdtempSync(path.join(os.tmpdir(), "forgejo-retention-"));
        try {
          for (let i = 1; i <= 9; i++) {
            const f = path.join(retentionDir, `forgejo-dump-gen${i}.zip`);
            writeFileSync(f, "");
            const mtime = new Date(Date.now() - i * 24 * 60 * 60 * 1000);
            execFileSync("touch", ["-t", formatTouchTimestamp(mtime), f]);
          }
          note(`seeded 9 fake dump generations in ${retentionDir}`);
          // The exact one-liner forgejo-backup's launchd script uses.
          execFileSync("bash", [
            "-c",
            `ls -1t "${retentionDir}"/forgejo-dump-*.zip 2>/dev/null | tail -n +$((${BACKUP_RETENTION_COUNT} + 1)) | xargs -r rm -f`,
          ]);
          const remaining = readdirSync(retentionDir).filter((f) => f.startsWith("forgejo-dump-"));
          expect(remaining.length).toBe(BACKUP_RETENTION_COUNT);
          note(
            `ran the retention one-liner -> ${remaining.length} generation(s) remain (expected ${BACKUP_RETENTION_COUNT})`,
          );
        } finally {
          rmSync(retentionDir, { recursive: true, force: true });
        }
      },
    );
  } finally {
    if (runnerProc && runnerProc.exitCode === null) {
      runnerProc.kill();
    }
    await attachLog("execution-transcript.txt", transcript.join("\n"));
  }
});

function formatTouchTimestamp(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}${pad(d.getHours())}${pad(d.getMinutes())}`;
}
