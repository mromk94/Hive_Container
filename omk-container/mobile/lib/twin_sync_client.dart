import 'package:dio/dio.dart';

import 'twin_state.dart';
import 'twin_state_store.dart';

/// Client for syncing TwinSnapshot with Hive Bridge.
class TwinSyncClient {
  TwinSyncClient(this._dio);

  final Dio _dio;

  Future<TwinSnapshot> sync() async {
    final local = await TwinStateStore.loadOrInit();
    try {
      final res = await _dio.post(
        'http://10.0.2.2:4317/twin-sync',
        data: <String, Object?>{'snapshot': local.toJson()},
      );
      final data = res.data as Map<String, Object?>?;
      final remoteSnap = data?['snapshot'] as Map<String, Object?>?;
      if (remoteSnap == null) return local;
      final remote = TwinSnapshot.fromJson(remoteSnap);
      final merged = TwinStateManager.merge(local, remote);
      await TwinStateStore.save(merged);
      return merged;
    } catch (_) {
      return local;
    }
  }
}
