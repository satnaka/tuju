import { readFileSync, readdirSync, existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

// Keep license texts and copyright notices with the libraries included in the shipped app.
export function bundledNotices(base, metafile) {
  const roots = new Set(["@heroui/styles", "@heroui-pro/react", "tailwindcss"].map(name => join(base, "node_modules", name)));
  for (const output of Object.values(metafile.outputs)) {
    for (const [input, contribution] of Object.entries(output.inputs)) {
      if (!input.includes("node_modules/") || !contribution.bytesInOutput) continue;
      let directory = dirname(resolve(base, input));
      while (directory !== base && directory !== dirname(directory)) {
        const manifest = join(directory, "package.json");
        if (existsSync(manifest) && JSON.parse(readFileSync(manifest, "utf8")).name) {
          roots.add(directory);
          break;
        }
        directory = dirname(directory);
      }
    }
  }

  const groups = new Map();
  for (const root of roots) {
    const manifest = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
    const names = readdirSync(root).filter(name => /^(licen[sc]e|notice)(\.(txt|md))?$/i.test(name)).sort();
    const notice = names.map(name => readFileSync(join(root, name), "utf8").trim()).join("\n\n") || manifest.license;
    const owners = groups.get(notice) ?? new Set();
    owners.add(manifest.name + " " + manifest.version);
    groups.set(notice, owners);
  }
  return [...groups].map(([body, names]) => [...names].sort().join(", ") + "\n\n" + body).sort().join("\n\n");
}
