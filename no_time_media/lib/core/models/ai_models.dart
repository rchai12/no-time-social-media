class PhotoInfo {
  final String id;
  final String path;
  final DateTime dateTaken;
  final double score;
  final Components components;

  PhotoInfo({
    required this.id,
    required this.path,
    required this.dateTaken,
    required this.score,
    required this.components,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is PhotoInfo &&
        other.id == id &&
        other.path == path &&
        other.dateTaken == dateTaken &&
        other.score == score &&
        other.components == components;
  }

  @override
  int get hashCode {
    return Object.hash(id, path, dateTaken, score, components);
  }
}

class Components {
  final double recency;
  final double aesthetic;
  final double novelty;
  final double faces;

  Components({
    required this.recency,
    required this.aesthetic,
    required this.novelty,
    required this.faces,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is Components &&
        other.recency == recency &&
        other.aesthetic == aesthetic &&
        other.novelty == novelty &&
        other.faces == faces;
  }

  @override
  int get hashCode {
    return Object.hash(recency, aesthetic, novelty, faces);
  }
}

class PlatformContent {
  final String platform;
  final String caption;
  final String postType;

  PlatformContent({
    required this.platform,
    required this.caption,
    required this.postType,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is PlatformContent &&
        other.platform == platform &&
        other.caption == caption &&
        other.postType == postType;
  }

  @override
  int get hashCode {
    return Object.hash(platform, caption, postType);
  }
}

class AIGenerationResponse {
  final List<String> captions;
  final List<String> hashtags;
  final List<PlatformContent> platforms;

  AIGenerationResponse({
    required this.captions,
    required this.hashtags,
    required this.platforms,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is AIGenerationResponse &&
        other.captions == captions &&
        other.hashtags == hashtags &&
        other.platforms == platforms;
  }

  @override
  int get hashCode {
    return Object.hash(captions, hashtags, platforms);
  }
}