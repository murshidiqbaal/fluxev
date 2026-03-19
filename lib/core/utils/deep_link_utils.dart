class DeepLinkUtils {
  /// Validates if a string is a valid UUID
  static bool isValidUUID(String uuid) {
    final regex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return regex.hasMatch(uuid);
  }

  /// Extracts connector_id from various data formats:
  /// 1. URI: fluxev://start?connector_id=UUID
  /// 2. Split: station_id|connector_id
  /// 3. Pure UUID: 8-4-4-4-12 format
  static String? extractConnectorId(String data) {
    if (data.isEmpty) return null;

    // 1. Try parsing as URI
    try {
      if (data.contains('://')) {
        final uri = Uri.parse(data);
        final id = uri.queryParameters['connector_id'];
        if (id != null && isValidUUID(id)) return id;
      }
    } catch (_) {
      // Not a valid URI, continue to other checks
    }

    // 2. Try parsing split format (station_id|connector_id)
    if (data.contains('|')) {
      final parts = data.split('|');
      for (final part in parts) {
        if (isValidUUID(part)) return part;
      }
    }

    // 3. Check if it's already a valid UUID
    if (isValidUUID(data)) return data;

    return null;
  }
}
