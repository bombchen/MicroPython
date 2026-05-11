List<String> resolveBroadcastTargets(Iterable<String> localAddresses) {
  final targets = <String>{'255.255.255.255'};

  for (final address in localAddresses) {
    final octets = address.split('.');
    if (octets.length != 4) {
      continue;
    }
    if (octets.first == '127') {
      continue;
    }
    if (octets.any((part) => int.tryParse(part) == null)) {
      continue;
    }
    targets.add('${octets[0]}.${octets[1]}.${octets[2]}.255');
  }

  return targets.toList(growable: false);
}
