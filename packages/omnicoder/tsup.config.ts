import { defineConfig } from "tsup"

export default defineConfig({
  entry: ["src/index.ts"],
  format: ["esm"],
  target: "node18",
  dts: true,
  clean: true,
  sourcemap: false,
  splitting: false,
  // opencode provides these at runtime
  external: ["@opencode-ai/plugin", "@opencode-ai/sdk"],
})
