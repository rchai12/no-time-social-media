import { corsHeaders } from "../_shared/cors.ts";
import { supabaseAdmin } from "../_shared/supabaseClient.ts";
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

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

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
    const body = await req.json();
    const photos = body.photos as PhotoInput[] | undefined;
    const targetPlatform = (body.targetPlatform as string | undefined) ??
      "instagram";

    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return jsonResponse({ error: "unauthorized" }, 401);
    }
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabaseAdmin.auth
      .getUser(token);
    if (authError || !user) {
      return jsonResponse({ error: "unauthorized" }, 401);
    }
    const userId = user.id;

    if (!photos || !Array.isArray(photos) || photos.length === 0) {
      return jsonResponse({
        error: "invalid_request",
        detail: "photos must be a non-empty array",
      }, 400);
    }

    if (photos.length > 20) {
      return jsonResponse({
        error: "invalid_request",
        detail: "photos array must contain 1–20 items",
      }, 400);
    }

    const { data: sub } = await supabaseAdmin
      .from("subscriptions")
      .select("tier")
      .eq("user_id", userId)
      .maybeSingle();

    const tier = sub?.tier ?? "free";
    const isPro = tier === "pro";
    const limit = isPro ? 20 : 3;

    let currentUsage = 0;

    if (isPro) {
      const today = new Date().toISOString().substring(0, 10);
      const { data: usage } = await supabaseAdmin
        .from("usage_daily")
        .select("count")
        .eq("user_id", userId)
        .eq("date", today)
        .maybeSingle();
      currentUsage = usage?.count ?? 0;
    } else {
      const firstOfMonth = new Date();
      firstOfMonth.setUTCDate(1);
      const firstOfMonthStr = firstOfMonth.toISOString().substring(0, 10);

      const { data: rows } = await supabaseAdmin
        .from("usage_daily")
        .select("count")
        .eq("user_id", userId)
        .gte("date", firstOfMonthStr);

      currentUsage = (rows ?? []).reduce(
        (sum: number, r: { count?: number }) => sum + (r.count ?? 0),
        0,
      );
    }

    if (currentUsage >= limit) {
      if (isPro) {
        const tomorrow = new Date();
        tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
        tomorrow.setUTCHours(0, 0, 0, 0);
        return jsonResponse({
          error: "daily_limit_reached",
          limit,
          resets_at: tomorrow.toISOString(),
        }, 429);
      }
      return jsonResponse({ error: "subscription_required" }, 402);
    }

    const today = new Date().toISOString().substring(0, 10);
    await supabaseAdmin.rpc("increment_usage", {
      p_user_id: userId,
      p_date: today,
    });

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

    return jsonResponse(result, 200);
  } catch (error) {
    console.error("Error in AI generation function:", error);
    const detail = error instanceof Error ? error.message : String(error);
    return jsonResponse({ error: "ai_error", detail }, 500);
  }
});
