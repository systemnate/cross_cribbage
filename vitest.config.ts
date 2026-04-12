import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "jsdom",
    globals: true,
    include: ["app/frontend/**/*.{test,spec}.{ts,tsx}"],
    coverage: {
      provider: "v8",
      reporter: ["text", "html"],
      reportsDirectory: "coverage/frontend",
      include: ["app/frontend/**/*.{ts,tsx}"],
      exclude: [
        "app/frontend/**/*.d.ts",
        "app/frontend/entrypoints/**",
        "app/frontend/types/**",
      ],
      thresholds: {
        lines: 75,
        statements: 75,
        branches: 75,
        functions: 75,
      },
    },
  },
});
