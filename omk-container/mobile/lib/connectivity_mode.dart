import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityMode { cloud, localMesh, offline }

final connectivityModeProvider =
    StateProvider<ConnectivityMode>((ref) => ConnectivityMode.cloud);
