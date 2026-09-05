/// Configuration parameters matching the web app
class AppConfig {
  // MQTT Network (Private HiveMQ Cloud cluster in EU with TLS port 8883 and WSS port 8884)
  static const String mqttBrokerHost =
      '02c32905ccdb4e97b9cd3860b9ae6f14.s1.eu.hivemq.cloud';
  static const String fallbackBrokerHost = 'broker.emqx.io';
  static const int mqttTlsPort = 8883;
  static const int mqttTcpPort = 1883;
  static const int mqttWssPort = 8884;
  static const String mqttWssPath = '/mqtt';

  // HiveMQ Cloud Dedicated Credentials
  static const String defaultMqttUsername = 'tracker_user';
  static const String defaultMqttPassword = r'=$GuL>X#N9G;Yum';

  static const List<String> availableBrokers = [
    '02c32905ccdb4e97b9cd3860b9ae6f14.s1.eu.hivemq.cloud',
    'broker.emqx.io',
    'broker.hivemq.com',
  ];
  static const String topicPrefix = 'geotrack_minimal_v1';

  // Sampling & Battery Optimization
  static const int samplingIntervalMs = 15000; // 15 seconds
  static const double minDistanceMeters = 10.0; // 10 meters noise filter

  // Map Tile Defaults (CARTO Voyager / OpenStreetMap)
  static const String defaultCartoTileUrl =
      'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
  static const String osmFallbackTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // E2EE Security Settings
  static const int pbkdf2Iterations = 100000;
  static const String saltPrefix = 'geotrack_salt_v1_';

  // Notification Channel for Android Foreground Service
  static const String notificationChannelId = 'live_map_tracker_channel';
  static const String notificationChannelName = 'Tracciamento Live GPS';
  static const int notificationId = 888;
}
