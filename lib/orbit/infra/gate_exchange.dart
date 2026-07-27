import 'dart:convert';

import '../config/nova_gate_config.dart';
import '../core/gate_models.dart';
import 'drift_attribution.dart';
import 'orbit_vault.dart';
import 'signal_agent.dart';

class GateExchange {
  GateExchange(this._agent, this._vault);

  final SignalAgent _agent;
  final OrbitVault _vault;

  Future<GateReply> request(Map<String, dynamic> payload) async {
    if (!NovaGateConfig.gateCredentialsReady) {
      return GateReply.rejected('credentials_unavailable');
    }
    try {
      novaTrace(() => '[NOVA.EXCHANGE] request ${jsonEncode(payload)}');
      final response = await _agent
          .post(
            Uri.parse(NovaGateConfig.endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      novaTrace(
        () =>
            '[NOVA.EXCHANGE] response ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        return GateReply.rejected('http_${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return GateReply.rejected('invalid_response');
      final reply = GateReply.fromJson(Map<String, dynamic>.from(decoded));
      if (reply.hasDestination) {
        await _vault.cacheUrl(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (error) {
      novaTrace(() => '[NOVA.EXCHANGE] failed: $error');
      return GateReply.rejected('network_failure');
    }
  }
}
