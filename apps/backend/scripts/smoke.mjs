// Boots the built server, hits /health, exits 0/1. Used locally and in CI.
import { spawn } from "node:child_process";

const PORT = 4100;
const child = spawn(process.execPath, ["dist/main.js"], {
  env: { ...process.env, PORT: String(PORT) },
  stdio: "inherit"
});

const deadline = Date.now() + 15_000;
let ok = false;
while (Date.now() < deadline) {
  try {
    const res = await fetch(`http://localhost:${PORT}/health`);
    const body = await res.json();
    if (res.ok && body.status === "ok") {
      console.log("SMOKE OK:", JSON.stringify(body));
      ok = true;
      break;
    }
  } catch {
    await new Promise((r) => setTimeout(r, 300));
  }
}

// No process.exit(): forcing exit with live fetch/child handles trips a
// libuv assertion on Windows. Set the code and let the loop drain.
process.exitCode = ok ? 0 : 1;
child.kill();
