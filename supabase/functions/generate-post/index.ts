import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { supabaseClient } from "../_shared/supabaseClient.ts";

// Define the input and output types for the AI generation request
interface AIInput {
  photos: Array<{
    id: string;
    path: string;
    dateTaken: string; 
    score: number;
    components: {
      recency: number;
      aesthetic: number;
      novelty: number;
      faces: number;
    };
  }>;
}

interface AIOutput {
  captions: Array<string>;
  hashtags: Array<string>;
  platforms: Array<{
    platform: string;
    caption: string;
    post_type: 'image' | 'video';
  }>;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { photos } = await req.json() as AIInput;
    
    // Validate input
    if (!photos || !Array.isArray(photos)) {
      return new Response(
        JSON.stringify({ error: "Invalid input - photos must be an array" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        }
      );
    }

    // Generate captions and hashtags using Gemini API
    const generatedCaptions: string[] = [];
    const generatedHashtags: string[] = [];
    const platforms: Array<{
      platform: string;
      caption: string;
      post_type: 'image' | 'video';
    }> = [];

    // For each photo, generate content for multiple platforms
    for (const photo of photos) {
      try {
        // Simulated AI generation - in real implementation this would call Gemini API
        const simulatedCaption = `Beautiful photo from ${photo.dateTaken} with score ${photo.score}`;
        const simulatedHashtag = `#photo${Math.floor(Math.random() * 1000)}`;
        
        generatedCaptions.push(simulatedCaption);
        generatedHashtags.push(simulatedHashtag);
        
        // Generate platform-specific content
        platforms.push({
          platform: "instagram",
          caption: `${simulatedCaption} ${simulatedHashtag}`,
          post_type: 'image'
        });
        
        platforms.push({
          platform: "twitter",
          caption: `${simulatedCaption.substring(0, 100)}... ${simulatedHashtag}`,
          post_type: 'image'
        });
      } catch (error) {
        console.error(`Error generating content for photo ${photo.id}:`, error);
        // For this demo, we'll still add empty entries to maintain structure
        generatedCaptions.push("");
        generatedHashtags.push("");
        platforms.push({
          platform: "instagram",
          caption: "",
          post_type: 'image'
        });
      }
    }

    const response: AIOutput = {
      captions: generatedCaptions,
      hashtags: generatedHashtags,
      platforms
    };

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    console.error("Error in AI generation function:", error);
    
    return new Response(
      JSON.stringify({ error: "Failed to generate AI content" }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});

// This is a simplified version since we can't actually call Gemini in this environment
// Actual implementation would look like:
/*
// For production, you'd include proper Gemini API call here:
import { GoogleGenerativeAI } from "https://esm.sh/@google/generative-ai";

const genAI = new GoogleGenerativeAI(Deno.env.get("GOOGLE_API_KEY") || "");
const model = genAI.getGenerativeModel({ model: "gemini-pro" });

// Then call the model with appropriate prompt
*/