import { corsHeaders } from "../_shared/cors.ts";
import { getProvider } from "./providers/index.ts";
import type {
  AIProvider,
  GenerationResponse,
  PhotoInput,
} from "./providers/types.ts";

const SYSTEM_PROMPT = `You are a social media content curator for an Instagram-focused app.

You will receive between 1 and 20 photo thumbnails, each identified by an assetId.

Your tasks:
1. Select the best 1–4 photos based on visual quality, composition, and engagement potential.
2. For each selected photo write a caption (no hashtags) and exactly 5 relevant hashtags (no '#' prefix).
3. Identify the best platform (instagram | twitter | facebook | tiktok) and explain why in one sentence.

Respond ONLY with valid JSON in this exact shape, with no markdown fences:
{
  "selectedPhotos": [
    {
      "assetId": "string",
      "caption": "string",
      "hashtags": ["string","string","string","string","string"],
      "bestPlatform": "instagram",
      "engagementRationale": "string"
    }
  ]
}`;

async function generateWithRetry(
  provider: AIProvider,
  photos: PhotoInput[],
  systemPrompt: string,
  platform: "instagram" | "twitter" | "facebook" | "tiktok",
): Promise<GenerationResponse> {
  try {
    return await provider.generate(photos, systemPrompt, platform);
  } catch (_e) {
    const correctionPrompt =
      systemPrompt +
      "\n\nIMPORTANT: You MUST respond with valid JSON only. No markdown, no explanation.";
    return await provider.generate(photos, correctionPrompt, platform);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // TODO(phase-5): verify JWT and check subscription
    const body = await req.json();
    const photos = body.photos as PhotoInput[] | undefined;
    const targetPlatform = (body.targetPlatform as string | undefined) ??
      "instagram";

    if (!photos || !Array.isArray(photos) || photos.length === 0) {
      return new Response(
        JSON.stringify({
          error: "invalid_request",
          detail: "photos must be a non-empty array",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        },
      );
    }

    if (photos.length > 20) {
      return new Response(
        JSON.stringify({
          error: "invalid_request",
          detail: "photos array must contain 1–20 items",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        },
      );
    }

    const platform = (
      ["instagram", "twitter", "facebook", "tiktok"].includes(targetPlatform)
        ? targetPlatform
        : "instagram"
    ) as "instagram" | "twitter" | "facebook" | "tiktok";

    const provider = getProvider();
    const result = await generateWithRetry(
      provider,
      photos,
      SYSTEM_PROMPT,
      platform,
    );

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    console.error("Error in AI generation function:", error);
    const detail = error instanceof Error ? error.message : String(error);

    return new Response(
      JSON.stringify({ error: "ai_error", detail }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      },
    );
  }
});
