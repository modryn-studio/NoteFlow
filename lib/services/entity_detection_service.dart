import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:email_validator/email_validator.dart';

/// Types of entities that can be detected in note content
enum EntityType { phone, email, url }

/// Represents a detected entity with its value and type
class DetectedEntity {
  final EntityType type;
  final String value;
  final String displayValue;
  final String actionUri;
  final int startIndex;
  final int endIndex;

  DetectedEntity({
    required this.type,
    required this.value,
    required this.displayValue,
    required this.actionUri,
    required this.startIndex,
    required this.endIndex,
  });

  /// Get icon for this entity type
  String get icon {
    switch (type) {
      case EntityType.phone:
        return '📞';
      case EntityType.email:
        return '📧';
      case EntityType.url:
        return '🔗';
    }
  }

  /// Get action label for this entity
  String get actionLabel {
    switch (type) {
      case EntityType.phone:
        return 'Call';
      case EntityType.email:
        return 'Email';
      case EntityType.url:
        return 'Open';
    }
  }
}

/// Service for detecting actionable entities in text content
class EntityDetectionService {
  static EntityDetectionService? _instance;
  static EntityDetectionService get instance =>
      _instance ??= EntityDetectionService._();

  EntityDetectionService._();

  /// URL regex pattern - matches http, https, and www URLs
  static final RegExp _urlPattern = RegExp(
    r'(?:https?://|www\.)[^\s<>\[\]{}|\\^`"]+',
    caseSensitive: false,
  );

  /// Phone number pattern - broad match for various formats
  /// Matches: +1234567890, (123) 456-7890, 123-456-7890, 123.456.7890, etc.
  static final RegExp _phonePattern = RegExp(
    r'(?:\+?1[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}',
  );

  /// Email pattern - basic pattern, validated with email_validator package
  static final RegExp _emailPattern = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    caseSensitive: false,
  );

  /// Detect all entities in the given content
  List<DetectedEntity> detectEntities(String content) {
    if (content.isEmpty) return [];

    final entities = <DetectedEntity>[];

    // Detect phone numbers with validation
    entities.addAll(_detectPhoneNumbers(content));

    // Detect emails with validation
    entities.addAll(_detectEmails(content));

    // Detect URLs
    entities.addAll(_detectUrls(content));

    // Sort by start index and remove duplicates/overlaps
    entities.sort((a, b) => a.startIndex.compareTo(b.startIndex));
    return _removeOverlaps(entities);
  }

  /// Detect and validate phone numbers
  List<DetectedEntity> _detectPhoneNumbers(String content) {
    final entities = <DetectedEntity>[];
    final matches = _phonePattern.allMatches(content);

    for (final match in matches) {
      final rawPhone = match.group(0)!;

      // Use phone_numbers_parser for validation
      if (_isValidPhoneNumber(rawPhone)) {
        // Clean phone number for URI
        final cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');

        entities.add(
          DetectedEntity(
            type: EntityType.phone,
            value: rawPhone,
            displayValue: _formatPhoneForDisplay(rawPhone),
            actionUri: 'tel:$cleanPhone',
            startIndex: match.start,
            endIndex: match.end,
          ),
        );
      }
    }

    return entities;
  }

  /// Validate phone number using phone_numbers_parser
  bool _isValidPhoneNumber(String phone) {
    try {
      // Clean the phone number
      final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

      // Try to parse as US number (default)
      final phoneNumber = PhoneNumber.parse(cleaned, callerCountry: IsoCode.US);
      return phoneNumber.isValid();
    } catch (e) {
      // If parsing fails, apply stricter validation
      final digits = phone.replaceAll(RegExp(r'\D'), '');

      // Basic length check
      if (digits.length < 10 || digits.length > 15) return false;

      // Reject obviously fake numbers (all same digit or sequential)
      if (RegExp(r'^(\d)\1+$').hasMatch(digits)) {
        return false; // e.g., 1111111111
      }
      if (digits == '1234567890' || digits == '0987654321') return false;

      // Reject numbers starting with 0 or 1 for US area codes (invalid)
      final areaCode = digits.length == 11
          ? digits.substring(1, 4)
          : digits.substring(0, 3);
      if (areaCode.startsWith('0') || areaCode.startsWith('1')) return false;

      return true;
    }
  }

  /// Format phone number for display
  String _formatPhoneForDisplay(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    } else if (digits.length == 11 && digits.startsWith('1')) {
      return '+1 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7)}';
    }
    return phone;
  }

  /// Detect and validate email addresses
  List<DetectedEntity> _detectEmails(String content) {
    final entities = <DetectedEntity>[];
    final matches = _emailPattern.allMatches(content);

    for (final match in matches) {
      final email = match.group(0)!;

      // Validate with email_validator package
      if (EmailValidator.validate(email)) {
        entities.add(
          DetectedEntity(
            type: EntityType.email,
            value: email,
            displayValue: email,
            actionUri: 'mailto:$email',
            startIndex: match.start,
            endIndex: match.end,
          ),
        );
      }
    }

    return entities;
  }

  /// Detect URLs
  List<DetectedEntity> _detectUrls(String content) {
    final entities = <DetectedEntity>[];
    final matches = _urlPattern.allMatches(content);

    for (final match in matches) {
      var url = match.group(0)!;

      // Ensure URL has protocol
      final actionUrl = url.startsWith('http') ? url : 'https://$url';

      // Create display URL (truncate if too long)
      final displayUrl = url.length > 40 ? '${url.substring(0, 40)}...' : url;

      entities.add(
        DetectedEntity(
          type: EntityType.url,
          value: url,
          displayValue: displayUrl,
          actionUri: actionUrl,
          startIndex: match.start,
          endIndex: match.end,
        ),
      );
    }

    return entities;
  }

  /// Remove overlapping entities (keep the first/more specific one)
  List<DetectedEntity> _removeOverlaps(List<DetectedEntity> entities) {
    if (entities.isEmpty) return entities;

    final result = <DetectedEntity>[entities.first];

    for (int i = 1; i < entities.length; i++) {
      final current = entities[i];
      final last = result.last;

      // Skip if current overlaps with last
      if (current.startIndex < last.endIndex) {
        continue;
      }

      result.add(current);
    }

    return result;
  }

  /// Check if content has any detectable entities
  bool hasEntities(String content) {
    return detectEntities(content).isNotEmpty;
  }

  /// Get entities grouped by type
  Map<EntityType, List<DetectedEntity>> getEntitiesGrouped(String content) {
    final entities = detectEntities(content);
    final grouped = <EntityType, List<DetectedEntity>>{};

    for (final entity in entities) {
      grouped.putIfAbsent(entity.type, () => []).add(entity);
    }

    return grouped;
  }
}
