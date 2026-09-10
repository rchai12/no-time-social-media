export interface PhotoInput {
  assetId: string;
  thumbnailBase64: string; // JPEG, 256x256 px
  compositeScore: number; // 0.0–1.0 from on-device scoring
  dateTaken: string; // ISO 8601
}

export interface PhotoResult {
  assetId: string;
  caption: string; // without hashtags
  hashtags: string[]; // 5 items, without '#' prefix
  bestPlatform: "instagram" | "twitter" | "facebook" | "tiktok";
  engagementRationale: string;
}

export interface GenerationResponse {
  selectedPhotos: PhotoResult[];
}

export interface AIProvider {
  generate(
    photos: PhotoInput[],
    systemPrompt: string,
    platform: "instagram" | "twitter" | "facebook" | "tiktok",
  ): Promise<GenerationResponse>;
}
