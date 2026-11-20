const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { writeNotices } = require("./notices.cjs");

const root = path.resolve(__dirname, "..");
const generated = path.join(root, "build");
const out = process.argv[2]
  ? path.resolve(process.argv[2])
  : path.join(generated, "main.jsbundle");
fs.mkdirSync(generated, { recursive: true });
fs.mkdirSync(path.dirname(out), { recursive: true });

const artwork = {};
for (const name of [
  "HomeHouse",
  "HomeWork",
  "HomeSaved",
  "HomeSearch",
  "HomeRecent",
  "HomeStop",
]) {
  const asset = path.join(
    root,
    "../TuJu/Assets.xcassets",
    name + ".imageset",
    name + ".svg",
  );
  // These exports include a block layout hint for browsers. Yoga lays each
  // native SVG out with the width and height supplied by its Icon component.
  artwork[name] = fs.readFileSync(asset, "utf8").replace(' style="display: block;"', "");
}
for (const name of [
  "house-fill",
  "map-fill",
  "car-front-fill",
  "person-circle",
]) {
  artwork[name] = fs.readFileSync(
    require.resolve("bootstrap-icons/icons/" + name + ".svg"),
    "utf8",
  );
}
const iconModule = path.join(generated, "icons.js");
const contents = "export default " + JSON.stringify(artwork) + ";\n";
if (!fs.existsSync(iconModule) || fs.readFileSync(iconModule, "utf8") !== contents) {
  // Simulator and Mac Catalyst builds may run Metro at the same time.
  const temporary = iconModule + "." + process.pid;
  fs.writeFileSync(temporary, contents);
  fs.renameSync(temporary, iconModule);
}

execFileSync(
  process.execPath,
  [
    path.join(
      path.dirname(require.resolve("react-native/package.json")),
      "cli.js",
    ),
    "bundle",
    "--platform",
    "ios",
    "--dev",
    "false",
    "--entry-file",
    "index.js",
    "--bundle-output",
    out,
    "--sourcemap-output",
    out + ".map",
    "--sourcemap-use-absolute-path",
    "--minify",
    "true",
  ],
  { cwd: root, stdio: "inherit" },
);

const sourceMap = JSON.parse(fs.readFileSync(out + ".map", "utf8"));
writeNotices(
  root,
  sourceMap,
  path.join(path.dirname(out), "TuJuComponentNotices.txt"),
);
fs.unlinkSync(out + ".map");
