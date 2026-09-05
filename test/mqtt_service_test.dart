import 'package:flutter_test/flutter_test.dart';
import 'package:live_map_tracker/services/crypto_service.dart';
import 'package:live_map_tracker/services/mqtt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MqttService Tests', () {
    late CryptoService cryptoService;
    late MqttService mqttService;

    setUp(() {
      cryptoService = CryptoService();
      mqttService = MqttService(cryptoService: cryptoService);
    });

    tearDown(() {
      mqttService.dispose();
    });

    test('Initial state is disconnected with no errors', () {
      expect(mqttService.isConnected, isFalse);
      expect(mqttService.lastError, isNull);
      expect(mqttService.activeBroker, isNull);
    });

    test('Connecting to live dedicated HiveMQ Cloud cluster succeeds and sets active connection info', () async {
      await cryptoService.deriveKey(password: 'testpass123', roomId: 'unit-test-room');
      final connected = await mqttService.connect(
        roomId: 'unit-test-room',
        myId: 'unit_test_id_${DateTime.now().millisecondsSinceEpoch % 100000}',
      );

      expect(connected, isTrue);
      expect(mqttService.isConnected, isTrue);
      expect(mqttService.activeBroker, contains('hivemq.cloud'));
      expect(mqttService.activePort, equals(8883));
      expect(mqttService.isSecure, isTrue);

      // Verify broadcasting an encrypted packet over live broker works
      final broadcastSuccess = await mqttService.broadcast({
        'type': 'ping',
        'id': 'unit_test_id',
        'time': DateTime.now().millisecondsSinceEpoch,
      });
      expect(broadcastSuccess, isTrue);

      mqttService.disconnect();
      expect(mqttService.isConnected, isFalse);
    }, timeout: const Timeout(Duration(seconds: 25)));

    test('Connecting to an invalid non-existent broker sets lastError and returns false', () async {
      final connected = await mqttService.connect(
        roomId: 'unit-test-room',
        myId: 'unit_test_id',
        brokerHost: 'nonexistent.invalid.broker.domain',
        port: 1883,
        useTls: false,
      );

      expect(connected, isFalse);
      expect(mqttService.isConnected, isFalse);
      expect(mqttService.lastError, isNotNull);
      expect(mqttService.lastError, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
