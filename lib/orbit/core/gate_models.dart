enum GateRoute {
  game,
  portal,
  undecided;

  String get storageValue => switch (this) {
    GateRoute.game => 'game',
    GateRoute.portal => 'portal',
    GateRoute.undecided => 'undecided',
  };

  static GateRoute parse(String? value) => switch (value) {
    'portal' || 'web' => GateRoute.portal,
    'game' || 'native' => GateRoute.game,
    _ => GateRoute.undecided,
  };
}

class GateReply {
  const GateReply({
    required this.accepted,
    this.url,
    this.expiresAt,
    this.reason,
  });

  factory GateReply.fromJson(Map<String, dynamic> json) {
    final rawExpiry = json['expires'];
    return GateReply(
      accepted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      reason: json['message']?.toString(),
    );
  }

  factory GateReply.rejected(String reason) =>
      GateReply(accepted: false, reason: reason);

  final bool accepted;
  final String? url;
  final int? expiresAt;
  final String? reason;

  bool get hasDestination => accepted && (url?.isNotEmpty ?? false);
}

sealed class GateTarget {
  const GateTarget();
}

final class GameTarget extends GateTarget {
  const GameTarget();
}

final class PortalTarget extends GateTarget {
  const PortalTarget(this.url, {this.coldLaunch = false});

  final String url;
  final bool coldLaunch;
}

final class OfflineTarget extends GateTarget {
  const OfflineTarget({required this.returnToGame});

  final bool returnToGame;
}
