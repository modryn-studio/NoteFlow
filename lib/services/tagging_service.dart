/// Rule-based tagging service for auto-categorizing notes
class TaggingService {
  static TaggingService? _instance;
  static TaggingService get instance => _instance ??= TaggingService._();

  TaggingService._();

  /// Keyword patterns for each category
  static final Map<String, List<String>> _tagPatterns = {
    'work': [
      'meeting',
      'project',
      'deadline',
      'task',
      'client',
      'presentation',
      'report',
      'email',
      'call',
      'office',
      'team',
      'manager',
      'boss',
      'colleague',
      'schedule',
      'agenda',
      'review',
      'feedback',
    ],
    'bills': [
      'payment',
      'due',
      'invoice',
      'bill',
      'subscription',
      'rent',
      'utilities',
      'electric',
      'water',
      'gas',
      'internet',
      'phone',
      'insurance',
      'mortgage',
      'loan',
      'credit',
      'bank',
      'fee',
      '\$',
      'amount',
      'pay',
    ],
    'ideas': [
      'idea',
      'brainstorm',
      'concept',
      'think',
      'maybe',
      'could',
      'what if',
      'imagine',
      'creative',
      'innovation',
      'inspiration',
      'thought',
      'consider',
      'explore',
      'potential',
    ],
    'gifts': [
      'gift',
      'birthday',
      'present',
      'anniversary',
      'christmas',
      'holiday',
      'celebration',
      'surprise',
      'wish list',
      'wishlist',
      'wants',
      'shopping',
      'buy for',
    ],
    'personal': [
      'doctor',
      'appointment',
      'health',
      'gym',
      'exercise',
      'diet',
      'family',
      'friend',
      'vacation',
      'travel',
      'hobby',
      'goal',
      'resolution',
      'habit',
    ],
    'shopping': [
      'buy',
      'purchase',
      'order',
      'amazon',
      'grocery',
      'groceries',
      'store',
      'shop',
      'list',
      'need',
      'get',
      'pick up',
    ],
  };

  /// Auto-tag content based on keyword matching
  List<String> autoTag(String content) {
    final lowerContent = content.toLowerCase();
    final matchedTags = <String>[];

    for (final entry in _tagPatterns.entries) {
      final tagName = entry.key;
      final keywords = entry.value;

      for (final keyword in keywords) {
        if (lowerContent.contains(keyword.toLowerCase())) {
          if (!matchedTags.contains(tagName)) {
            matchedTags.add(tagName);
          }
          break; // Move to next tag category once matched
        }
      }
    }

    // If no tags matched, add 'note' as default
    if (matchedTags.isEmpty) {
      matchedTags.add('note');
    }

    return matchedTags;
  }

  /// Get suggested tags with confidence scores
  Map<String, double> getTagSuggestions(String content) {
    final lowerContent = content.toLowerCase();
    final suggestions = <String, double>{};

    for (final entry in _tagPatterns.entries) {
      final tagName = entry.key;
      final keywords = entry.value;

      int matchCount = 0;
      for (final keyword in keywords) {
        if (lowerContent.contains(keyword.toLowerCase())) {
          matchCount++;
        }
      }

      if (matchCount > 0) {
        // Confidence based on number of keyword matches
        final confidence = (matchCount / keywords.length).clamp(0.1, 1.0);
        suggestions[tagName] = confidence;
      }
    }

    return suggestions;
  }

  /// Add custom keyword to a tag category
  /// Returns true if keyword was added, false if invalid or already exists
  bool addKeywordToTag(String tag, String keyword) {
    // Sanitize input: lowercase, trim, remove special characters
    final sanitizedKeyword = keyword
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    
    // Validate keyword
    if (sanitizedKeyword.isEmpty || sanitizedKeyword.length > 50) {
      return false;
    }
    
    if (_tagPatterns.containsKey(tag)) {
      if (_tagPatterns[tag]!.contains(sanitizedKeyword)) {
        return false; // Already exists
      }
      _tagPatterns[tag]!.add(sanitizedKeyword);
    } else {
      _tagPatterns[tag] = [sanitizedKeyword];
    }
    return true;
  }

  /// Get all available tag categories
  List<String> get availableTags => _tagPatterns.keys.toList();
}
