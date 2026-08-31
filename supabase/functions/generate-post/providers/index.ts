import { ClaudeProvider } from "./claude.ts";
import { OpenAIProvider } from "./openai.ts";
import { GeminiProvider } from "./gemini.ts";
import type { AIProvider } from "./types.ts";

export function getProvider(): AIProvider {
  const active = Deno.env.get("ACTIVE_AI_PROVIDER") ?? "gemini";
  switch (active) {
    case "claude":
      return new ClaudeProvider();
    case "openai":
      return new OpenAIProvider();
    case "gemini":
      return new GeminiProvider();
    default:
      throw new Error(`Unknown AI provider: ${active}`);
  }
}
