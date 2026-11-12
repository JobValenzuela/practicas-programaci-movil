import 'dart:async';

import '../data/local_store.dart';
import 'cloud_service.dart';

enum ServiceStatus { unknown, available, offline, error }

class SyncEngine {
  final LocalStore local;
  final CloudService cloud;
  void Function()? onChanged;
  bool running = false;
  ServiceStatus status = ServiceStatus.unknown;
  String? error;
  DateTime? lastSuccess;
  Future<void>? _flight;
  SyncEngine(this.local, this.cloud);

  // Todos los disparadores comparten el mismo envío serializado.
  Future<void> sync() => _flight ??= _run().whenComplete(() => _flight = null);
  Future<void> _run() async {
    running = true;
    error = null;
    onChanged?.call();
    try {
      final owner = await cloud.authenticate();
      await local.bindOwner(owner);
      // Ciclo acotado: la siguiente activación continúa una cola muy grande.
      for (var i = 0; i < 100; i++) {
        final operation = await local.next();
        if (operation == null) break;
        await cloud.push(operation.task, owner);
        await local.acknowledge(operation, owner);
        onChanged?.call();
      }
      await local.merge(await cloud.fetch());
      lastSuccess = DateTime.now().toUtc();
      await local.setMetadata('last_success', lastSuccess!.toIso8601String());
      status = ServiceStatus.available;
    } catch (e) {
      final text = e.toString();
      status =
          e is TimeoutException ||
              text.contains('SocketException') ||
              text.contains('ClientException')
          ? ServiceStatus.offline
          : ServiceStatus.error;
      error =
          text.contains('anonymous_provider_disabled') ||
              text.contains('Anonymous sign-ins are disabled')
          ? 'Habilita Anonymous Sign-Ins en Supabase → Authentication → Sign In / Providers.'
          : text.contains('PGRST205') || text.contains('42P01')
          ? 'Falta la tabla tasks. Ejecuta la migración SQL en el Dashboard de Supabase.'
          : text;
    } finally {
      running = false;
      onChanged?.call();
    }
  }
}
