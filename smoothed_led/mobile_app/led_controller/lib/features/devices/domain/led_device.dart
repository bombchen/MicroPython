import 'device_status.dart';

class LedDevice {
  const LedDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.lastSeenAt,
    required this.lastKnownStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ipAddress;
  final String name;
  final DateTime lastSeenAt;
  final DeviceStatus lastKnownStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  LedDevice copyWith({
    String? name,
    String? ipAddress,
    DateTime? lastSeenAt,
    DeviceStatus? lastKnownStatus,
    DateTime? updatedAt,
  }) {
    return LedDevice(
      id: id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastKnownStatus: lastKnownStatus ?? this.lastKnownStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LedDevice &&
            other.id == id &&
            other.name == name &&
            other.ipAddress == ipAddress &&
            other.lastSeenAt == lastSeenAt &&
            other.lastKnownStatus == lastKnownStatus &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        ipAddress,
        lastSeenAt,
        lastKnownStatus,
        createdAt,
        updatedAt,
      );
}
