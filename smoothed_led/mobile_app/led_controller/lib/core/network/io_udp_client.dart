import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'udp_client.dart';

class IoUdpClient implements UdpClient {
  @override
  Future<String> send({
    required String host,
    required int port,
    required String payload,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    StreamSubscription<RawSocketEvent>? subscription;
    final completer = Completer<String>();

    try {
      final address = await _resolveAddress(host);
      subscription = socket.listen(
        (event) {
          if (event != RawSocketEvent.read) {
            return;
          }

          final datagram = socket.receive();
          if (datagram == null || completer.isCompleted) {
            return;
          }

          completer.complete(utf8.decode(datagram.data));
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
      );

      socket.send(utf8.encode(payload), address, port);
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      throw TimeoutException('UDP request to $host:$port timed out');
    } finally {
      await subscription?.cancel();
      socket.close();
    }
  }

  @override
  Future<String?> sendBroadcast({
    required int port,
    required String payload,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    StreamSubscription<RawSocketEvent>? subscription;
    final completer = Completer<String?>();

    try {
      socket.broadcastEnabled = true;
      subscription = socket.listen(
        (event) {
          if (event != RawSocketEvent.read) {
            return;
          }

          final datagram = socket.receive();
          if (datagram == null || completer.isCompleted) {
            return;
          }

          completer.complete(datagram.address.address);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
      );

      socket.send(
        utf8.encode(payload),
        InternetAddress('255.255.255.255'),
        port,
      );

      return await completer.future.timeout(
        timeout,
        onTimeout: () => null,
      );
    } finally {
      await subscription?.cancel();
      socket.close();
    }
  }

  Future<InternetAddress> _resolveAddress(String host) async {
    final parsed = InternetAddress.tryParse(host);
    if (parsed != null) {
      return parsed;
    }

    return (await InternetAddress.lookup(host)).first;
  }
}
