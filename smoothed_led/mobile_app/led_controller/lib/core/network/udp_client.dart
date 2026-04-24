abstract class UdpClient {
  /// Sends a UDP payload to a specific host and returns the response payload
  /// received from that device.
  Future<String> send({
    required String host,
    required int port,
    required String payload,
    Duration timeout = const Duration(seconds: 2),
  });

  /// Sends a UDP broadcast probe and returns the responding device source IP
  /// if one replies within the probe window, or `null` if no response arrives.
  Future<String?> sendBroadcast({
    required int port,
    required String payload,
    Duration timeout = const Duration(seconds: 3),
  });
}
