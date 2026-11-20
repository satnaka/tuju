import { readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { build, transform } from "esbuild";
import { compile } from "@tailwindcss/node";
import { bundledNotices } from "./notices.mjs";

const base = dirname(fileURLToPath(import.meta.url));
const cssPath = join(base, "controls.css");
const styles = await compile(await readFile(cssPath, "utf8"), {
  base, from: cssPath, onDependency() {},
});
const { code: css } = await transform(styles.build([]), {
  loader: "css", minify: true, target: "safari17", legalComments: "inline",
});
const jsBundle = await build({
  absWorkingDir: base, entryPoints: ["controls.jsx"], bundle: true, write: false, metafile: true,
  minify: true, format: "iife", jsx: "automatic", target: "safari17",
  define: { "process.env.NODE_ENV": '"production"' },
  loader: { ".svg": "dataurl" }, legalComments: "inline", logLevel: "error",
});
const script = jsBundle.outputFiles[0].text.replace(/<\/script/gi, "<\\/script");
const hash = createHash("sha256").update(script).digest("base64");
const csp = `default-src 'none'; script-src 'sha256-${hash}'; style-src 'unsafe-inline'; img-src data:; connect-src 'none'; form-action 'none'; base-uri 'none'`;
const notices = bundledNotices(base, jsBundle.metafile).replaceAll("&", "&amp;").replaceAll("<", "&lt;");
const html = `<!doctype html>
<html lang="en" class="glass-light" data-theme="glass-light">
<head>
<meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="${csp}">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover"><title>TuJu</title>
<style>${css}</style>
</head><body><main id="controls"></main><template id="third-party-notices"><pre>${notices}</pre></template><script>${script}</script></body></html>
`;
await writeFile(join(base, "../TuJu/HeroUIControls.html"), html);
