// E2E test for the monitoring stack (modules/monitoring): Prometheus,
// Grafana, and Loki. Deliberately scrapes the *real* host via
// host-gateway using the real modules/monitoring/prometheus.yml (see
// tests/e2e-monitoring/design.md) rather than faking scrape targets -
// the whole point is verifying the repo's actual scrape config works
// against real endpoints, not a synthetic stand-in.
//
// Runs against an isolated per-worktree stack (never modules/monitoring's
// real instance or data - own ports, own Grafana volume).
import { test, expect, type APIRequestContext } from "@playwright/test";
import { readFileSync } from "node:fs";

const PROMETHEUS_URL = requireEnv("PROMETHEUS_URL");
const GRAFANA_URL = requireEnv("GRAFANA_URL");
const LOKI_URL = requireEnv("LOKI_URL");
const PROMETHEUS_CONFIG = requireEnv("PROMETHEUS_CONFIG");

const GRAFANA_ADMIN_USER = "admin";
const GRAFANA_ADMIN_PASSWORD = requireEnv("GRAFANA_ADMIN_PASSWORD");

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} must be set (see tests/e2e-monitoring/scripts/stack.sh)`);
  }
  return value;
}

// The set of job_names actually configured in the real scrape config -
// read from the same file the stack itself mounts (PROMETHEUS_CONFIG),
// not hand-copied here, so this suite can't silently drift from
// modules/monitoring/prometheus.yml as jobs are added/removed. A plain
// regex, not a YAML parser: prometheus.yml's job_name lines are always
// `  - job_name: "value"` (see the file itself), and adding a full YAML
// dependency for one field isn't worth it in a suite that otherwise
// depends on nothing but @playwright/test.
function configuredJobNames(): string[] {
  const text = readFileSync(PROMETHEUS_CONFIG, "utf-8");
  const matches = [...text.matchAll(/^\s*-\s*job_name:\s*"([^"]+)"/gm)];
  const jobs = matches.map((m) => m[1]);
  expect(jobs.length, `at least one job_name found in ${PROMETHEUS_CONFIG}`).toBeGreaterThan(0);
  return jobs;
}

test("Prometheus loads the real scrape config and discovers every configured job", async ({
  request,
}) => {
  const res = await request.get(`${PROMETHEUS_URL}/api/v1/targets`);
  expect(res.ok(), `targets API: ${res.status()} ${await res.text()}`).toBeTruthy();
  const body = (await res.json()) as {
    data: { activeTargets: Array<{ scrapePool: string; health: string }> };
  };

  const discoveredJobs = new Set(body.data.activeTargets.map((t) => t.scrapePool));
  const expectedJobs = configuredJobNames();
  for (const job of expectedJobs) {
    expect(
      discoveredJobs.has(job),
      `job "${job}" (from prometheus.yml) has a discovered target`,
    ).toBe(true);
  }

  // "実態に合わせた期待値": deliberately not asserting every target is
  // healthy - services like GitLab may legitimately be stopped on this
  // host. Log health per job so a real report still shows the actual
  // state, without failing the suite over expected downtime.
  const healthByJob = new Map<string, string[]>();
  for (const t of body.data.activeTargets) {
    const list = healthByJob.get(t.scrapePool) ?? [];
    list.push(t.health);
    healthByJob.set(t.scrapePool, list);
  }
  console.log("target health by job:", JSON.stringify(Object.fromEntries(healthByJob), null, 2));
});

test("Prometheus itself is queryable and reports up", async ({ request }) => {
  // The one target every run is guaranteed to become healthy, regardless
  // of what else is running on the host: Prometheus scraping itself.
  // Not necessarily immediately, though - measured directly that right
  // after stack.sh's own health check passes (proves the server process
  // is up, nothing about scrape cycles), most targets including this
  // one still report "unknown" until prometheus.yml's scrape_interval
  // (15s) has actually elapsed once. Poll rather than assume instant.
  let value = "";
  for (let attempt = 0; attempt < 15; attempt++) {
    const res = await request.get(`${PROMETHEUS_URL}/api/v1/query`, {
      params: { query: 'up{job="prometheus"}' },
    });
    expect(res.ok(), `query API: ${res.status()} ${await res.text()}`).toBeTruthy();
    const body = (await res.json()) as { data: { result: Array<{ value: [number, string] }> } };
    if (body.data.result.length > 0) {
      value = body.data.result[0].value[1];
      break;
    }
    await new Promise((r) => setTimeout(r, 2000));
  }
  expect(value, 'up{job="prometheus"} returned a result within the poll window').not.toBe("");
  expect(value, "Prometheus reports itself up").toBe("1");
});

async function grafanaApiLogin(request: APIRequestContext): Promise<void> {
  const res = await request.post(`${GRAFANA_URL}/login`, {
    data: { user: GRAFANA_ADMIN_USER, password: GRAFANA_ADMIN_PASSWORD },
  });
  expect(res.ok(), `grafana login: ${res.status()} ${await res.text()}`).toBeTruthy();
}

test("Grafana local admin can log in via the API and fetch the real services-overview dashboard", async ({
  request,
}) => {
  await grafanaApiLogin(request);
  // Session cookie set by the login call above is reused automatically -
  // request fixtures share cookies within a test.
  const res = await request.get(`${GRAFANA_URL}/api/dashboards/uid/services-overview`);
  expect(res.ok(), `dashboard fetch: ${res.status()} ${await res.text()}`).toBeTruthy();
  const body = (await res.json()) as { dashboard: { title: string; panels: unknown[] } };
  expect(body.dashboard.title).toBe("Services Overview");
  expect(body.dashboard.panels.length, "dashboard has panels").toBeGreaterThan(0);
});

test("Grafana dashboard renders in the browser without console errors", async ({ page }) => {
  const consoleErrors: string[] = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") consoleErrors.push(msg.text());
  });
  page.on("pageerror", (err) => consoleErrors.push(err.message));

  await page.goto(`${GRAFANA_URL}/login`);
  await page.getByLabel("Email or username").fill(GRAFANA_ADMIN_USER);
  // getByLabel('Password') is ambiguous: Grafana's PasswordField wraps
  // both the actual input and its own "Show password" visibility-toggle
  // button under the same Field label (LoginForm.tsx / PasswordField.tsx)
  // - the input's own data-testid is unambiguous.
  await page.getByTestId("data-testid Password input field").fill(GRAFANA_ADMIN_PASSWORD);
  await page.getByRole("button", { name: "Log in" }).click();
  await page.waitForURL(/\/(d\/|$|\?)/, { timeout: 15_000 });

  await page.goto(`${GRAFANA_URL}/d/services-overview`);
  // A dashboard-level element that only renders once panels have
  // mounted, not just the page shell - proof the dashboard actually
  // loaded rather than erroring before render.
  await expect(page.getByText("Services Overview")).toBeVisible({ timeout: 20_000 });

  // Grafana's own bundled app-plugin catalog (exploretraces/lokiexplore/
  // pyroscope/metricsdrilldown) intermittently fails to preload with
  // "Unknown Plugin" - measured directly across repeated runs that this
  // is unrelated to anything this suite configures (fires on every app
  // navigation, not specifically ours, and doesn't reproduce every run -
  // a race in Grafana's own plugin-catalog preload, not a dashboard
  // regression). Filtered out so a real rendering error doesn't get lost
  // in this platform noise.
  const relevantErrors = consoleErrors.filter(
    (e) => !e.startsWith("[Plugins] Failed to preload plugin"),
  );
  expect(
    relevantErrors,
    `no console/page errors while rendering the dashboard:\n${relevantErrors.join("\n")}`,
  ).toEqual([]);
});

test("Loki receives real container logs via Alloy", async ({ request }) => {
  // Alloy discovers and tails every container on the host (see
  // alloy-config.alloy's discovery.docker) - this isolated stack's own
  // containers are themselves real, currently-running containers, so
  // real log lines should appear without needing to seed anything.
  let total = 0;
  for (let attempt = 0; attempt < 20; attempt++) {
    const res = await request.get(`${LOKI_URL}/loki/api/v1/query_range`, {
      params: {
        query: '{compose_project=~".+"}',
        start: String((Date.now() - 5 * 60 * 1000) * 1_000_000),
        end: String(Date.now() * 1_000_000),
        limit: "10",
      },
    });
    expect(res.ok(), `loki query_range: ${res.status()} ${await res.text()}`).toBeTruthy();
    const body = (await res.json()) as { data: { result: unknown[] } };
    total = body.data.result.length;
    if (total > 0) break;
    await new Promise((r) => setTimeout(r, 1500));
  }
  expect(total, "Loki returned at least one log stream").toBeGreaterThan(0);
});
