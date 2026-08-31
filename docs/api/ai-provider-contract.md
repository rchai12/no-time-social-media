# API Contract — AI Provider Interface

## Overview

All AI provider integrations live inside the Supabase Edge Function (`generate-post`). The Flutter app never calls AI providers directly. This document defines the TypeScript interface that each provider module must implement.

## TypeScript Interface

```typescript
// supabase/functions/generate-post/providers/types.ts

export interface PhotoInput {
  assetId: string;
  thumbnailBase64: string;   // JPEG, 256x256 px
  compositeScore: number;    // 0.0–1.0 from on-device scoring
  dateTaken: string;         // ISO 8601
}

export interface PhotoResult {
  assetId: string;
  caption: string;           // without hashtags
  hashtags: string[];        // 5 items, without '#' prefix
  bestPlatform: 'instagram' | 'twitter' | 'facebook' | 'tiktok';
  engagementRationale: string;
}

export interface GenerationResponse {
  selectedPhotos: PhotoResult[];
}

export interface AIProvider {
  generate(
    photos: PhotoInput[],
    systemPrompt: string,
    platform: 'instagram' | 'twitter' | 'facebook' | 'tiktok'
  ): Promise<GenerationResponse>;
}
```

## Provider Router

```typescript
// supabase/functions/generate-post/providers/index.ts

import { ClaudeProvider } from './claude.ts';
import { OpenAIProvider } from './openai.ts';
import { GeminiProvider } from './gemini.ts';

export function getProvider(): AIProvider {
  const active = Deno.env.get('ACTIVE_AI_PROVIDER') ?? 'claude';
  switch (active) {
    case 'claude':  return new ClaudeProvider();
    case 'openai':  return new OpenAIProvider();
    case 'gemini':  return new GeminiProvider();
    default: throw new Error(`Unknown AI provider: ${active}`);
  }
}
```

## Claude Provider

```typescript
// supabase/functions/generate-post/providers/claude.ts

import Anthropic from 'npm:@anthropic-ai/sdk';

export class ClaudeProvider implements AIProvider {
  private client = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY') });

  async generate(photos: PhotoInput[], systemPrompt: string): Promise<GenerationResponse> {
    const imageContent = photos.map(p => ({
      type: 'image' as const,
      source: {
        type: 'base64' as const,
        media_type: 'image/jpeg' as const,
        data: p.thumbnailBase64,
      },
    }));

    const response = await this.client.messages.create({
      model: 'claude-opus-4-6',
      max_tokens: 2048,
      system: systemPrompt,
      messages: [{
        role: 'user',
        content: [
          ...imageContent,
          { type: 'text', text: 'Select and generate posts for these photos.' }
        ],
      }],
    });

    return parseResponse((response.content[0] as any).text);
  }
}
```

## OpenAI Provider

```typescript
// supabase/functions/generate-post/providers/openai.ts

import OpenAI from 'npm:openai';

export class OpenAIProvider implements AIProvider {
  private client = new OpenAI({ apiKey: Deno.env.get('OPENAI_API_KEY') });

  async generate(photos: PhotoInput[], systemPrompt: string): Promise<GenerationResponse> {
    const imageContent = photos.map(p => ({
      type: 'image_url' as const,
      image_url: { url: `data:image/jpeg;base64,${p.thumbnailBase64}` },
    }));

    const response = await this.client.chat.completions.create({
      model: 'gpt-4o',
      max_tokens: 2048,
      messages: [
        { role: 'system', content: systemPrompt },
        {
          role: 'user',
          content: [
            ...imageContent,
            { type: 'text', text: 'Select and generate posts for these photos.' },
          ],
        },
      ],
    });

    return parseResponse(response.choices[0].message.content!);
  }
}
```

## Gemini Provider

```typescript
// supabase/functions/generate-post/providers/gemini.ts

import { GoogleGenerativeAI } from 'npm:@google/generative-ai';

export class GeminiProvider implements AIProvider {
  private genAI = new GoogleGenerativeAI(Deno.env.get('GOOGLE_API_KEY')!);

  async generate(photos: PhotoInput[], systemPrompt: string): Promise<GenerationResponse> {
    const model = this.genAI.getGenerativeModel({
      model: 'gemini-1.5-pro',
      systemInstruction: systemPrompt,
    });

    const imageParts = photos.map(p => ({
      inlineData: { mimeType: 'image/jpeg' as const, data: p.thumbnailBase64 },
    }));

    const result = await model.generateContent([
      ...imageParts,
      'Select and generate posts for these photos.',
    ]);

    return parseResponse(result.response.text());
  }
}
```

## Shared JSON Parser

```typescript
// supabase/functions/generate-post/providers/parser.ts

export function parseResponse(raw: string): GenerationResponse {
  try {
    // Strip markdown code fences if present
    const cleaned = raw.replace(/^```json\n?/, '').replace(/\n?```$/, '').trim();
    const parsed = JSON.parse(cleaned);
    if (!parsed.selectedPhotos || !Array.isArray(parsed.selectedPhotos)) {
      throw new Error('Missing selectedPhotos array');
    }
    return parsed as GenerationResponse;
  } catch (e) {
    throw new Error(`Failed to parse AI response: ${e.message}\nRaw: ${raw}`);
  }
}
```

## Retry Logic (Edge Function)

```typescript
async function generateWithRetry(
  provider: AIProvider,
  photos: PhotoInput[],
  systemPrompt: string,
  platform: string,
): Promise<GenerationResponse> {
  try {
    return await provider.generate(photos, systemPrompt, platform as any);
  } catch (e) {
    // Retry once with an explicit JSON correction instruction appended
    const correctionPrompt = systemPrompt + '\n\nIMPORTANT: You MUST respond with valid JSON only. No markdown, no explanation.';
    return await provider.generate(photos, correctionPrompt, platform as any);
  }
}
```

## Supabase Environment Variables

| Variable | Description |
|---|---|
| `ACTIVE_AI_PROVIDER` | `claude` \| `openai` \| `gemini` |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `OPENAI_API_KEY` | OpenAI API key |
| `GOOGLE_API_KEY` | Google AI Studio API key |

Set via: `supabase secrets set ANTHROPIC_API_KEY=...`
