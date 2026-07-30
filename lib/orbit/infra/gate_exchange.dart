import 'dart:convert';

import '../config/nova_gate_config.dart';
import '../core/gate_models.dart';
import 'drift_attribution.dart';
import 'orbit_vault.dart';
import 'signal_agent.dart';

/// Talks to the backend config endpoint. Sends the composed attribution
/// payload as JSON, applies a hard 15s timeout, caches the returned URL when
/// present, and always returns a [GateReply] (never throws).
class GateExchange {
  GateExchange(this._agent, this._vault);

  static const Duration _timeout = Duration(seconds: 15);
  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  final SignalAgent _agent;
  final OrbitVault _vault;

  Future<GateReply> request(Map<String, dynamic> payload) async {
    if (!NovaGateConfig.gateCredentialsReady) {
      return GateReply.rejected('credentials_unavailable');
    }
    final encoded = jsonEncode(payload);
    ntdLog(() => '[NTD.EXCHANGE] request $encoded');
    try {
      final response = await _agent
          .post(
            Uri.parse(NovaGateConfig.endpoint),
            headers: _headers,
            body: encoded,
          )
          .timeout(_timeout);
      ntdLog(
        () => '[NTD.EXCHANGE] response ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        return GateReply.rejected('http_${response.statusCode}');
      }
      return await _parseReply(response.body);
    } catch (error) {
      ntdLog(() => '[NTD.EXCHANGE] failed: $error');
      return GateReply.rejected('network_failure');
    }
  }

  Future<GateReply> _parseReply(String body) async {
    final dynamic decoded = jsonDecode(body);
    if (decoded is! Map) return GateReply.rejected('invalid_response');
    final reply = GateReply.fromJson(Map<String, dynamic>.from(decoded));
    if (reply.hasDestination) {
      await _vault.cacheUrl(reply.url!, reply.expiresAt);
    }
    return reply;
  }
}
