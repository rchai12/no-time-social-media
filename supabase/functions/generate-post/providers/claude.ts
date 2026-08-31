import type { AIProvider, GenerationResponse, PhotoInput } from "./types.ts";

export class ClaudeProvider implements AIProvider {
  async generate(
    _photos: PhotoInput[],
    _systemPrompt: string,
    _platform: "instagram" | "twitter" | "facebook" | "tiktok",
  ): Promise<GenerationResponse> {
    throw new Error("not configured");
  }
}
