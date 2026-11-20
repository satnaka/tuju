const { getDefaultConfig, mergeConfig } = require("@react-native/metro-config");
const { withUniwindConfig } = require("uniwind/metro");

const config = mergeConfig(getDefaultConfig(__dirname), {
  resolver: { useWatchman: false },
  maxWorkers: 4,
});

module.exports = withUniwindConfig(config, {
  cssEntryFile: "./global.css",
  dtsFile: "./build/uniwind-types.d.ts",
});
