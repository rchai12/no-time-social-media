import { GoogleGenerativeAI } from "npm:@google/generative-ai";
import type { AIProvider, GenerationResponse, PhotoInput } from "./types.ts";
import { parseResponse } from "./parser.ts";

export class GeminiProvider implements AIProvider {
  private genAI = new GoogleGenerativeAI(Deno.env.get("GOOGLE_API_KEY")!);

  async generate(
    photos: PhotoInput[],
    systemPrompt: string,
    _platform: "instagram" | "twitter" | "facebook" | "tiktok",
  ): Promise<GenerationResponse> {
    const model = this.genAI.getGenerativeModel({
      model: "gemini-1.5-pro",
      systemInstruction: systemPrompt,
    });

    const imageParts = photos.map((p) => ({
      inlineData: { mimeType: "image/jpeg" as const, data: p.thumbnailBase64 },
    }));

    const result = await model.generateContent([
      ...imageParts,
      "Select and generate posts for these photos.",
    ]);

    return parseResponse(result.response.text());
  }
}
