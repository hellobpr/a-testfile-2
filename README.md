# a-testfile-2 — Node.js Express App with CI/CD

A small Express API used as a DevOps learning sandbox. It exposes two JSON endpoints,
ships as a Docker image, and has three GitHub Actions workflows covering CI, a
containerised deploy, and a tag-based rollback.

Repository: https://github.com/hellobpr/a-testfile-2

---

## Table of Contents

- [What This Project Does](#what-this-project-does)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [How the Application Works](#how-the-application-works)
- [API Reference](#api-reference)
- [How to Run the Project](#how-to-run-the-project)
  - [Option 1 — Run Locally with Node](#option-1--run-locally-with-node)
  - [Option 2 — Run with the devops.sh Script](#option-2--run-with-the-devopssh-script)
  - [Option 3 — Run with Docker](#option-3--run-with-docker)
- [Running the Tests](#running-the-tests)
- [How the Docker Build Works](#how-the-docker-build-works)
- [CI/CD Pipeline](#cicd-pipeline)
  - [main.yml — Node.js CI](#mainyml--nodejs-ci)
  - [deploy.yml — Deploy Node.js Docker App](#deployyml--deploy-nodejs-docker-app)
  - [rollback.yml — Rollback Deployment](#rollbackyml--rollback-deployment)
- [The v1 / v2 Rollback Demo](#the-v1--v2-rollback-demo)
- [Troubleshooting](#troubleshooting)
- [Known Issues and Gotchas](#known-issues-and-gotchas)
- [License](#license)

---

## What This Project Does

The application is a single-file Express server ([index.js](index.js)) listening on
**port 3000**. It provides:

- A `/health` endpoint that reports status, a hardcoded version string, process
  uptime, and a timestamp — used as the smoke-test target by every workflow.
- A `/users` endpoint returning a static array of three mock users.
- Request logging middleware that prints method, URL, status code, and duration
  for every completed response.

The surrounding tooling is the actual point of the project: a Dockerfile, a bash
provisioning script, a Jest test, and a three-workflow GitHub Actions setup that
demonstrates deploying a versioned container and rolling it back to an earlier
git tag.

---

## Project Structure

```text
.
├── .dockerignore              # Excludes tests, docs, Dockerfile, .git from the image
├── .github/
│   └── workflows/
│       ├── main.yml           # CI: install deps, run tests, run the app
│       ├── deploy.yml         # Build Docker image, run it, health-check it
│       └── rollback.yml       # Manual: rebuild and run a chosen git tag
├── .gitignore
├── Dockerfile                 # node:18-alpine, production-only deps, non-root user
├── devops.sh                  # Bash script: preflight checks, install, restart app
├── index.js                   # The Express application (all routes + server start)
├── package.json               # Deps and the `test` script
├── package-lock.json
├── README.md
└── tests/
    └── health.test.js         # Supertest + Jest check that /health returns 200
```

---

## Prerequisites

| Tool | Version | Needed for |
|------|---------|-----------|
| Node.js | **18+** | Running the app and tests. The Dockerfile and CI both pin Node 18. |
| npm | Bundled with Node | Installing dependencies. |
| Docker | Any recent version | The container workflow (optional for local dev). |
| Git | Any recent version | Cloning, and tagging for the rollback demo. |
| Bash | — | Only for [devops.sh](devops.sh); it will not run in PowerShell or cmd. |

Runtime dependency: `express ^5.2.1`.
Dev dependencies: `jest ^30.3.0`, `supertest ^7.2.2`.

> **Note on Node version:** Express 5 requires Node 18 or newer. Older guidance
> suggesting Node 14 does not apply to this project.

---

## How the Application Works

Reading [index.js](index.js) top to bottom:

1. **Express app is created** and `PORT` is set to the literal `3000`. The port is
   not configurable via an environment variable — changing it means editing the file.

2. **Logging middleware** is registered with `app.use()`. It records `Date.now()`
   on the way in, attaches a `finish` listener to the response, and on completion
   logs a line like:

   ```text
   GET /health 200 - 3ms
   ```

3. **`GET /health`** responds with JSON:

   ```json
   {
     "status": "OK",
     "version": "v1",
     "uptime": 12.345,
     "timestamp": "2026-10-05T12:00:00.000Z"
   }
   ```

   The `version` field is a hardcoded string, which is what makes the rollback
   demo observable — see [The v1 / v2 Rollback Demo](#the-v1--v2-rollback-demo).

4. **A commented-out "broken v2" handler** sits directly below the healthy one.
   Uncommenting it makes `/health` throw, simulating a bad release.

5. **`GET /users`** returns a static in-memory array. There is no database.

6. **Conditional server start.** The `app.listen()` call is guarded by
   `if (require.main === module)`, and the app is exported with `module.exports = app`.
   This is deliberate: the server only binds a port when the file is run directly,
   so the Jest test can import the app and drive it through Supertest without
   leaving a listening socket open.

Note there is **no route registered for `/`**. Requesting the root returns Express's
default 404 — this matters for the Docker healthcheck, as described under
[Known Issues](#known-issues-and-gotchas).

---

## API Reference

| Method | Path | Response |
|--------|------|----------|
| `GET` | `/health` | `200` — `{ status, version, uptime, timestamp }` |
| `GET` | `/users` | `200` — array of 3 user objects (`id`, `name`, `email`) |
| `GET` | `/` | `404` — no route defined |

---

## How to Run the Project

Clone first:

```bash
git clone https://github.com/hellobpr/a-testfile-2.git
cd a-testfile-2
```

### Option 1 — Run Locally with Node

```bash
npm install
node index.js
```

Expected output:

```text
Server running on http://localhost:3000
```

> **Important:** use `node index.js`, **not** `npm start`. [package.json](package.json)
> defines only a `test` script — there is no `start` script, so `npm start` will
> fail with "Missing script: start".

Verify it in another terminal:

```bash
curl http://localhost:3000/health
curl http://localhost:3000/users
```

On Windows PowerShell, `curl` is an alias for `Invoke-WebRequest`. Use this instead:

```powershell
Invoke-RestMethod http://localhost:3000/health
```

Stop the server with `Ctrl+C`.

### Option 2 — Run with the devops.sh Script

[devops.sh](devops.sh) wraps the local run with preflight checks. It runs under
`set -Eeuo pipefail` with an `ERR` trap, so it aborts on the first failure and
prints the failing line number.

```bash
chmod +x devops.sh
./devops.sh
```

Steps it performs, in order:

1. Verifies `node` is on `PATH`, else exits with an error.
2. Prints the Node version.
3. Verifies `npm` is on `PATH`, else exits with an error.
4. Prints the npm version.
5. Runs `npm install`.
6. Runs `pkill -f node` to stop any already-running Node processes.
7. Starts the app with `node index.js`.

> **Warning:** step 6 kills **every** process whose command line matches `node`,
> not just this app. Avoid running it on a machine with other Node services you
> care about. The script also needs a real bash environment — on Windows use Git
> Bash or WSL.

Because step 7 runs in the foreground, the final `log "Application exited successfully."`
line only prints after you stop the server.

### Option 3 — Run with Docker

```bash
docker build -t my-node-app .
docker run -d --name my-node-app -p 3000:3000 my-node-app
```

Check it:

```bash
docker ps
docker logs my-node-app
curl http://localhost:3000/health
```

Tear down:

```bash
docker stop my-node-app && docker rm my-node-app
```

---

## Running the Tests

```bash
npm install
npm test
```

This runs Jest, which picks up [tests/health.test.js](tests/health.test.js). The
single test imports the Express app directly and asserts that `GET /health`
returns status `200`. No server needs to be running — Supertest binds an ephemeral
port itself.

> These commands are transcribed from [package.json](package.json) and the test
> file rather than executed, because Node is not installed in the environment
> where this README was generated.

---

## How the Docker Build Works

[Dockerfile](Dockerfile) stages, in order:

1. `FROM node:18-alpine` — small base image.
2. `ENV NODE_ENV=production`.
3. `WORKDIR /app`.
4. `COPY package.json package-lock.json ./` — manifests copied first so the
   dependency layer is cached and only reinstalls when the manifests change.
5. `RUN npm install --omit=dev && npm cache clean --force` — skips `jest` and
   `supertest`, then clears the cache to shrink the layer.
6. `COPY index.js ./` — only the application file is copied in.
7. `HEALTHCHECK` — probes `http://localhost:3000/` every 30s via `wget --spider`.
8. `EXPOSE 3000`.
9. `USER node` — drops from root to the unprivileged `node` user.
10. `CMD ["node", "index.js"]`.

[.dockerignore](.dockerignore) keeps `node_modules`, `tests`, `Dockerfile`,
`devops.sh`, `*.md`, `.git`, `.gitignore`, and `.env` out of the build context.

---

## CI/CD Pipeline

Three workflows live in [.github/workflows/](.github/workflows/).

**Execution order:** `main.yml` and `deploy.yml` both trigger on `push` to `main`,
and GitHub Actions starts them as **two independent, parallel workflow runs**.
Neither waits for the other, so a commit with failing tests will still be built
and deployed. See [Known Issues](#known-issues-and-gotchas) for how to chain them.

### main.yml — Node.js CI

**Trigger:** `push` to `main`.
**Job:** `build-and-run` on `ubuntu-latest`.

| # | Step | Command |
|---|------|---------|
| 1 | Checkout repository | `actions/checkout@v4` |
| 2 | Setup Node.js | `actions/setup-node@v4`, `node-version: 18` |
| 3 | Print Node.js version | `node -v` |
| 4 | Install dependencies | `npm install` |
| 5 | Run tests | `npm test` |
| 6 | Run application | `node index.js` |

> Step 6 starts the server in the foreground. Because nothing stops it, the step
> occupies the runner until the job's timeout — the workflow does not finish
> cleanly after a successful test run.

### deploy.yml — Deploy Node.js Docker App

**Trigger:** `push` to `main`.
**Job:** `build-and-deploy` on `ubuntu-latest`.

| # | Step | Command |
|---|------|---------|
| 1 | Checkout code | `actions/checkout@v4` |
| 2 | Build Docker image | `docker build -t my-node-app .` |
| 3 | Run container (simulation) | `docker run -d -p 3000:3000 my-node-app` |
| 4 | Wait for application startup | `sleep 5` |
| 5 | Verify application is running | `curl --fail http://localhost:3000/health` |
| 6 | Verify container is running | `docker ps` |

> **This does not deploy anywhere.** There is no registry push and no remote
> target. The image is built and run on the ephemeral GitHub runner, which is
> destroyed when the job ends — hence "simulation" in step 3's name. It is a
> build-and-smoke-test, and `curl --fail` makes the job fail if `/health` does
> not return success.

### rollback.yml — Rollback Deployment

**Trigger:** `workflow_dispatch` (manual only), with a `version` input —
described as a git tag, defaulting to `v1`.
**Job:** `rollback` on `ubuntu-latest`.

| # | Step | Command |
|---|------|---------|
| 1 | Checkout selected version | `actions/checkout@v4` with `ref: <version>` |
| 2 | Show rollback version | `echo` the target |
| 3 | Build image from that version | `docker build -t my-node-app:<version> .` |
| 4 | Run rollback container | `docker run -d --name my-node-app -p 3000:3000 my-node-app:<version>` |
| 5 | Wait for startup | `sleep 10` |
| 6 | Show container logs | `docker logs my-node-app` |
| 7 | Verify rollback health | `curl --fail http://localhost:3000/health` |
| 8 | Confirm rollback | `echo` success |

**To run it:** GitHub → **Actions** → **Rollback Deployment** → **Run workflow** →
enter a tag → **Run workflow**.

> The tag must already exist in the repository. This clone currently has **no git
> tags**, so you must create and push them before the rollback workflow can
> resolve a `ref`.

---

## The v1 / v2 Rollback Demo

The commented-out handler in [index.js](index.js) and the hardcoded `version`
field exist to make a rollback visible end to end:

1. **Tag the good release.** With the healthy `/health` handler active:

   ```bash
   git tag v1
   git push origin v1
   ```

2. **Create the broken release.** Comment out the working `/health` handler and
   uncomment the block that throws `Broken deployment v2`. Change `version` to
   `"v2"` if you want the field to match. Then:

   ```bash
   git commit -am "Create broken v2"
   git tag v2
   git push origin main v2
   ```

   `deploy.yml` runs on that push, and step 5's `curl --fail` fails because
   `/health` now throws a 500 — the deploy goes red.

3. **Roll back.** Dispatch **Rollback Deployment** with `version: v1`. It checks
   out the `v1` tag, rebuilds the image as `my-node-app:v1`, runs it, and
   health-checks it. `/health` returns `"version": "v1"`, confirming the rollback.

The repository history already contains a `Create broken v2` commit, so this cycle
has been exercised before.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `npm error Missing script: "start"` | No `start` script exists | Run `node index.js` |
| `Error: listen EADDRINUSE :::3000` | Port 3000 already taken | Stop the other process, or edit `PORT` in [index.js](index.js) |
| `curl: (22) The requested URL returned error: 404` | You hit `/` — no root route | Use `/health` or `/users` |
| Container shows `unhealthy` in `docker ps` | `HEALTHCHECK` probes `/`, which 404s | See [Known Issues](#known-issues-and-gotchas) |
| `docker: Conflict. The container name "/my-node-app" is already in use` | Previous container still present | `docker rm -f my-node-app` |
| `./devops.sh: command not found` / bad syntax | Not running under bash | Use Git Bash or WSL |
| Rollback fails at checkout with `couldn't find remote ref` | The tag does not exist | Create and push the tag first |
| `fatal: detected dubious ownership in repository` | Windows repo owner differs from current user | `git config --global --add safe.directory <repo-path>` |

---

## Known Issues and Gotchas

These are real defects in the current code, documented so the behaviour isn't
mistaken for something you broke. None are fixed by this README.

1. **The Docker `HEALTHCHECK` always fails.** It probes `http://localhost:3000/`,
   but no `/` route is registered, so Express returns 404 and `wget --spider`
   exits non-zero. The container will be marked `unhealthy` even while working
   correctly. Pointing the probe at `/health` fixes it:

   ```dockerfile
   CMD wget --spider -q http://localhost:3000/health || exit 1
   ```

   Note that `deploy.yml` is unaffected — it curls `/health` directly and does
   not consult the container's health status.

2. **CI and deploy race each other.** Both fire on the same push with no ordering,
   so an untested commit can be deployed. To sequence them, either make deploy a
   second job in `main.yml` with `needs: build-and-run`, or switch `deploy.yml` to
   a `workflow_run` trigger:

   ```yaml
   on:
     workflow_run:
       workflows: ["Node.js CI"]
       types: [completed]
       branches: [main]
   ```

   with a job guard of `if: github.event.workflow_run.conclusion == 'success'`.

3. **`main.yml` never terminates cleanly.** Step 6 runs `node index.js` in the
   foreground with nothing to stop it, so the job hangs until timeout.

4. **`devops.sh` runs `pkill -f node`,** which kills unrelated Node processes on
   the machine.

5. **The port is hardcoded.** `PORT = 3000` is a literal, not
   `process.env.PORT || 3000`, so it cannot be overridden at runtime.

6. **License is inconsistent.** [package.json](package.json) declares `ISC`.
   Confirm which licence actually applies before publishing.

7. **`npm install` rather than `npm ci`.** Both CI and the Dockerfile use
   `npm install`, which can drift from `package-lock.json`. `npm ci` would give
   reproducible installs.

---

## License

[package.json](package.json) declares the **ISC** license. No `LICENSE` file is
present in the repository.
