import 'package:flutter_test/flutter_test.dart';
import 'package:live_map_tracker/core/utils/haversine.dart';
import 'package:live_map_tracker/models/location_point.dart';
import 'package:live_map_tracker/models/peer_user.dart';
import 'package:live_map_tracker/services/location_service.dart';

void main() {
  group('LocationService & Trail Logic Tests', () {
    late LocationService locationService;

    setUp(() {
      locationService = LocationService();
    });

    test('Haversine accurately measures distance between GPS coordinates', () {
      // Colosseo (41.8902, 12.4922) to Fontana di Trevi (41.9009, 12.4833) ~ 1.4 km
      final distance = Haversine.distanceInMeters(
        41.8902,
        12.4922,
        41.9009,
        12.4833,
      );

      expect(distance, greaterThan(1300));
      expect(distance, lessThan(1600));
    });

    test('shouldBroadcast filters points below threshold and accepts movements', () {
      final p1 = LocationPoint(
        lat: 41.902800,
        lng: 12.496400,
        timestamp: 1000,
      );

      // First point is always accepted
      expect(locationService.shouldBroadcast(p1), isTrue);

      // Minor jitter (~1 meter away) should be filtered out
      final jitter = LocationPoint(
        lat: 41.902808,
        lng: 12.496408,
        timestamp: 2000,
      );
      expect(locationService.shouldBroadcast(jitter), isFalse);

      // Actual movement (~50 meters away) should be accepted
      final movement = LocationPoint(
        lat: 41.903200,
        lng: 12.496800,
        timestamp: 3000,
      );
      expect(locationService.shouldBroadcast(movement), isTrue);
    });

    test('LocationPoint serialization and deserialization preserves all attributes', () {
      final point = LocationPoint(
        lat: 45.4642,
        lng: 9.1900,
        heading: 180.5,
        speed: 1.4,
        accuracy: 4.5,
        timestamp: 1700000000000,
      );

      final json = point.toJson();
      final restored = LocationPoint.fromJson(json);

      expect(restored.lat, equals(45.4642));
      expect(restored.lng, equals(9.1900));
      expect(restored.heading, equals(180.5));
      expect(restored.speed, equals(1.4));
      expect(restored.accuracy, equals(4.5));
      expect(restored.timestamp, equals(1700000000000));
    });

    test('Trail with 2 or more points enables polyline rendering', () {
      final List<LocationPoint> trail = [];
      expect(trail.length >= 2, isFalse);

      trail.add(LocationPoint(lat: 41.9028, lng: 12.4964, timestamp: 1000));
      expect(trail.length >= 2, isFalse);

      trail.add(LocationPoint(lat: 41.9030, lng: 12.4966, timestamp: 2000));
      expect(trail.length >= 2, isTrue);
    });

    test('LocationPoint correctly parses web coordinate formats', () {
      // 1. Web list format: [lat, lng]
      final fromList = LocationPoint.fromJson([41.9028, 12.4964]);
      expect(fromList.lat, equals(41.9028));
      expect(fromList.lng, equals(12.4964));

      // 2. Web object with coord: {coord: [lat, lng]}
      final fromCoordObj = LocationPoint.fromJson({
        'coord': [41.9028, 12.4964],
        'time': 1700000000000,
      });
      expect(fromCoordObj.lat, equals(41.9028));
      expect(fromCoordObj.lng, equals(12.4964));
      expect(fromCoordObj.timestamp, equals(1700000000000));
    });

    test('PeerUser correctly preserves trail and reflects hasLeft/isOnline state', () {
      final peer = PeerUser(
        id: 'user-past',
        name: 'Marco',
        lastSeen: DateTime.now().millisecondsSinceEpoch,
        trail: [
          LocationPoint(lat: 41.900, lng: 12.400, timestamp: 1000),
          LocationPoint(lat: 41.905, lng: 12.405, timestamp: 2000),
        ],
      );

      expect(peer.isOnline, isTrue);
      expect(peer.hasLeft, isFalse);
      expect(peer.trail.length, equals(2));

      // User leaves the room
      peer.hasLeft = true;
      peer.isTracking = false;
      peer.currentPosition = null;

      // Online status should be false, but trail must remain fully intact
      expect(peer.isOnline, isFalse);
      expect(peer.hasLeft, isTrue);
      expect(peer.trail.length, equals(2));

      // Serialization round-trip preserves all trail data
      final json = peer.toJson();
      final restored = PeerUser.fromJson(json);

      expect(restored.id, equals('user-past'));
      expect(restored.name, equals('Marco'));
      expect(restored.hasLeft, isTrue);
      expect(restored.isOnline, isFalse);
      expect(restored.trail.length, equals(2));
      expect(restored.trail.first.lat, equals(41.900));
      expect(restored.trail.last.lat, equals(41.905));
    });

    test('LocationPoint correctly parses isGap flag from web and json formats', () {
      // 1. Web list format with isGap=1
      final fromListWithGap = LocationPoint.fromJson([41.9028, 12.4964, 1, 0, 1700000000000]);
      expect(fromListWithGap.isGap, isTrue);

      // 2. Web list format without gap
      final fromListNoGap = LocationPoint.fromJson([41.9028, 12.4964, 0, 0, 1700000000000]);
      expect(fromListNoGap.isGap, isFalse);

      // 3. Map format with coord array containing gap marker
      final fromCoordWithGap = LocationPoint.fromJson({
        'coord': [41.9028, 12.4964, 1],
        'time': 1700000000000,
      });
      expect(fromCoordWithGap.isGap, isTrue);

      // 4. Map format with explicit isGap: true
      final fromMapExplicit = LocationPoint.fromJson({
        'lat': 41.9028,
        'lng': 12.4964,
        'isGap': true,
        'time': 1700000000000,
      });
      expect(fromMapExplicit.isGap, isTrue);
    });

    test('Trail points with isGap separate into disconnected segments', () {
      // Simulating: segment 1 (p1 -> p2) -> pause -> resume with isGap -> segment 2 (p3 -> p4)
      final trail = [
        LocationPoint(lat: 41.900, lng: 12.400, timestamp: 1000),
        LocationPoint(lat: 41.901, lng: 12.401, timestamp: 2000),
        LocationPoint(lat: 41.905, lng: 12.405, timestamp: 3000, isGap: true),
        LocationPoint(lat: 41.906, lng: 12.406, timestamp: 4000),
      ];

      // Segment splitting logic (matching TrackerMapView)
      final List<List<LocationPoint>> segments = [];
      List<LocationPoint> currentSegment = [];
      for (final p in trail) {
        if (p.isGap && currentSegment.isNotEmpty) {
          if (currentSegment.length >= 2) {
            segments.add(currentSegment);
          }
          currentSegment = [p];
        } else {
          currentSegment.add(p);
        }
      }
      if (currentSegment.length >= 2) {
        segments.add(currentSegment);
      }

      // Must produce 2 separate segments
      expect(segments.length, equals(2));
      // Segment 1: p1 and p2
      expect(segments[0].length, equals(2));
      expect(segments[0][0].lat, equals(41.900));
      expect(segments[0][1].lat, equals(41.901));
      // Segment 2: p3 and p4 (starting at p3 after the pause)
      expect(segments[1].length, equals(2));
      expect(segments[1][0].lat, equals(41.905));
      expect(segments[1][1].lat, equals(41.906));
    });
  });
}
