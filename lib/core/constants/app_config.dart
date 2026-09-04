/// Configuration parameters matching the web app
class AppConfig {
  // MQTT Network (Uses native TCP port 1883 or WSS port 8084)
  static const String mqttBrokerHost = 'broker.emqx.io';
  static const int mqttTcpPort = 1883;
  static const int mqttWssPort = 8084;
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
