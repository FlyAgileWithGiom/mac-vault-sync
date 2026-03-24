import esbuild from "esbuild";
import { copyFileSync, existsSync } from "fs";
import { homedir } from "os";
import { join } from "path";

const prod = process.argv[2] === "production";
const PLUGIN_DIR = join(homedir(), "ObsidianNotes/.obsidian/plugins/fly-vault-sync");

function deploy() {
  if (existsSync(PLUGIN_DIR)) {
    for (const f of ["main.js", "manifest.json", "styles.css"]) {
      copyFileSync(f, join(PLUGIN_DIR, f));
    }
    console.log("Deployed to vault plugin dir");
  }
}

const context = await esbuild.context({
  entryPoints: ["src/main.ts"],
  bundle: true,
  external: ["obsidian", "electron", "@codemirror/*", "@lezer/*"],
  format: "cjs",
  target: "es2020",
  outfile: "main.js",
  sourcemap: prod ? false : "inline",
  treeShaking: true,
  minify: prod,
  logLevel: "info",
  plugins: [{
    name: "deploy",
    setup(build) {
      build.onEnd(() => deploy());
    },
  }],
});

if (prod) {
  await context.rebuild();
  process.exit(0);
} else {
  await context.watch();
}
