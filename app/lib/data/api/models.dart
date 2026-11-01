/// Модели ответов API раздела 1.7. Имена JSON-полей — допущение:
/// файла OpenAPI нет, схему DRF пишет Evgeniy в BE-101. Сверить с ним.
library;

/// Состояния TrialLease (раздел 1.6). Пишется CANCELLED, не CANCELED.
enum TrialState { newState, provisioning, active, expired, cancelled }

TrialState parseTrialState(String? raw) => switch (raw) {
      'NEW' => TrialState.newState,
      'PROVISIONING' => TrialState.provisioning,
      'ACTIVE' => TrialState.active,
      'EXPIRED' => TrialState.expired,
      'CANCELLED' => TrialState.cancelled,
      _ => TrialState.cancelled,
    };

/// GET /trials/current. Время — только время сервера в UTC.
class TrialInfo {
  const TrialInfo({
    required this.id,
    required this.state,
    required this.serverTime,
    this.deadline,
  });

  final String id;
  final TrialState state;
  final DateTime serverTime;

  /// Абсолютный срок на сервере. Есть только после ACK узла (ACTIVE).
  final DateTime? deadline;

  /// Сколько осталось по часам сервера на момент ответа.
  Duration? get remainingAtServer {
    final d = deadline;
    if (d == null) return null;
    final left = d.difference(serverTime);
    return left.isNegative ? Duration.zero : left;
  }

  factory TrialInfo.fromJson(Map<String, Object?> j) => TrialInfo(
        id: '${j['id']}',
        state: parseTrialState(j['state'] as String?),
        serverTime: DateTime.parse(j['server_time']! as String).toUtc(),
        deadline: j['deadline'] == null
            ? null
            : DateTime.parse(j['deadline']! as String).toUtc(),
      );
}

/// GET /nodes: только грубый признак живых узлов. Нет внутреннего IP.
class NodeInfo {
  const NodeInfo({required this.id, required this.label, required this.alive});

  final String id;
  final String label;
  final bool alive;

  factory NodeInfo.fromJson(Map<String, Object?> j) => NodeInfo(
        id: '${j['id']}',
        label: '${j['label'] ?? j['id']}',
        alive: j['alive'] == true,
      );
}

/// POST /peers: один туннельный адрес и публичный конфиг сервера.
class PeerInfo {
  const PeerInfo({
    required this.id,
    required this.tunnelAddress,
    required this.serverConfig,
  });

  final String id;
  final String tunnelAddress;
  final Map<String, Object?> serverConfig;

  factory PeerInfo.fromJson(Map<String, Object?> j) => PeerInfo(
        id: '${j['id']}',
        tunnelAddress: '${j['tunnel_address']}',
        serverConfig:
            (j['server_config'] as Map?)?.cast<String, Object?>() ?? const {},
      );
}
