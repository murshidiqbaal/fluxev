import 'package:flutter_test/flutter_test.dart';
import 'package:flux_ev/core/utils/deep_link_utils.dart';

void main() {
  group('DeepLinkUtils Tests', () {
    const validUuid = '476319b9-8b5b-46b7-8210-d13d34d70816';

    test('extractConnectorId from deep link URI', () {
      const link = 'fluxev://start?connector_id=$validUuid';
      expect(DeepLinkUtils.extractConnectorId(link), validUuid);
    });

    test('extractConnectorId from split format', () {
      const data = 'station_123|$validUuid';
      expect(DeepLinkUtils.extractConnectorId(data), validUuid);
    });

    test('extractConnectorId from pure UUID', () {
      expect(DeepLinkUtils.extractConnectorId(validUuid), validUuid);
    });

    test('extractConnectorId returns null for invalid formats', () {
      expect(DeepLinkUtils.extractConnectorId('invalid_data'), null);
      expect(DeepLinkUtils.extractConnectorId('fluxev://start?other_id=$validUuid'), null);
    });

    test('isValidUUID validates correctly', () {
      expect(DeepLinkUtils.isValidUUID(validUuid), true);
      expect(DeepLinkUtils.isValidUUID('not-a-uuid'), false);
    });
  });
}
