import 'dart:io';

import 'broadcast_target_resolver.dart';

class LocalNetworkSnapshot {
  const LocalNetworkSnapshot({
    required this.ipv4Addresses,
    required this.broadcastTargets,
  });

  final List<String> ipv4Addresses;
  final List<String> broadcastTargets;

  String describe() {
    final addresses = ipv4Addresses.isEmpty ? 'none' : ipv4Addresses.join(', ');
    final targets =
        broadcastTargets.isEmpty ? 'none' : broadcastTargets.join(', ');
    return '本机 IPv4: $addresses\n广播目标: $targets';
  }
}

abstract class LocalNetworkDiagnostics {
  Future<LocalNetworkSnapshot> capture();
}

class IoLocalNetworkDiagnostics implements LocalNetworkDiagnostics {
  @override
  Future<LocalNetworkSnapshot> capture() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    final localAddresses = interfaces
        .expand((interface) => interface.addresses)
        .map((address) => address.address)
        .toList(growable: false);

    return LocalNetworkSnapshot(
      ipv4Addresses: localAddresses,
      broadcastTargets: resolveBroadcastTargets(localAddresses),
    );
  }
}
