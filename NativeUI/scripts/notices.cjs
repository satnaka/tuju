const fs = require("node:fs");
const path = require("node:path");

function packageRoot(source, modulesDir) {
  if (!source.startsWith(modulesDir + path.sep)) return null;
  let dir = path.dirname(source);
  while (dir.startsWith(modulesDir + path.sep)) {
    const manifest = path.join(dir, "package.json");
    if (
      fs.existsSync(manifest) &&
      JSON.parse(fs.readFileSync(manifest, "utf8")).name
    )
      return dir;
    dir = path.dirname(dir);
  }
  return null;
}

function writeNotices(root, sourceMap, destination) {
  const modulesDir = path.join(root, "node_modules");
  const packages = new Set([path.join(modulesDir, "bootstrap-icons")]);
  // Metro may produce indexed source maps with a separate section per module.
  const sources = sourceMap.sections ? sourceMap.sections.flatMap(({ map }) => map.sources) : sourceMap.sources;
  for (const source of sources) {
    const directory = packageRoot(path.resolve(root, source), modulesDir);
    if (directory) packages.add(directory);
  }
  const byLicense = new Map();
  for (const directory of packages) {
    const manifest = JSON.parse(
      fs.readFileSync(path.join(directory, "package.json"), "utf8"),
    );
    const files = fs
      .readdirSync(directory)
      .filter((file) => /^(licen[sc]e|notice)(\.(txt|md))?$/i.test(file))
      .sort();
    const text =
      files
        .map((file) =>
          fs.readFileSync(path.join(directory, file), "utf8").trim(),
        )
        .join("\n\n") || manifest.license;
    if (!text) continue;
    if (!byLicense.has(text)) byLicense.set(text, new Set());
    byLicense.get(text).add(manifest.name + " " + manifest.version);
  }
  const groups = [...byLicense].map(
    ([license, names]) => [...names].sort().join(", ") + "\n\n" + license,
  );
  fs.writeFileSync(destination, groups.sort().join("\n\n") + "\n");
}

module.exports = { writeNotices };
