const { spawnSync } = require("node:child_process");

// CRE CLI passes extra args to cre-compile; we ignore them and run tsc with project config.
const result = spawnSync("tsc", ["-p", "tsconfig.json"], { stdio: "inherit" });
process.exit(result.status ?? 1);
