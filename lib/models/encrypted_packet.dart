/// Represents an encrypted E2EE container sent over MQTT
class EncryptedPacket {
  final bool e2ee;
  final String iv;
  final String ct;
  final int v;

  EncryptedPacket({
    this.e2ee = true,
    required this.iv,
    required this.ct,
    this.v = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'e2ee': e2ee,
      'iv': iv,
      'ct': ct,
      'v': v,
    };
  }

  factory EncryptedPacket.fromJson(Map<String, dynamic> json) {
    return EncryptedPacket(
      e2ee: json['e2ee'] == true,
      iv: json['iv'] as String? ?? '',
      ct: json['ct'] as String? ?? '',
      v: json['v'] is int ? json['v'] as int : 1,
    );
  }
}
