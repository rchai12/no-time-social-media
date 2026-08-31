import type { GenerationResponse } from "./types.ts";

export function parseResponse(raw: string): GenerationResponse {
  try {
    const cleaned = raw.replace(/^```json\n?/, "").replace(/\n?```$/, "").trim();
    const parsed = JSON.parse(cleaned);
    if (!parsed.selectedPhotos || !Array.isArray(parsed.selectedPhotos)) {
      throw new Error("Missing selectedPhotos array");
    }
    return parsed as GenerationResponse;
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    throw new Error(`Failed to parse AI response: ${message}\nRaw: ${raw}`);
  }
}
