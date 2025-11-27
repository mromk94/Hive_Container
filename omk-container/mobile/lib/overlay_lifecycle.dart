import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_advisor.dart';
import 'connectivity_mode.dart';
import 'mesh_event_bus.dart';
import 'mesh_handshake.dart';
import 'network_telemetry.dart';
import 'node_identity.dart';
import 'overlay_bridge.dart';
import 'signal_telemetry.dart';
import 'state.dart';
import 'twin_environment_bridge.dart';

class OverlayLifecycle extends ConsumerStatefulWidget {
  const OverlayLifecycle({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OverlayLifecycle> createState() => _OverlayLifecycleState();
}

class _OverlayLifecycleState extends ConsumerState<OverlayLifecycle>
    with WidgetsBindingObserver {
  void Function(SignalTelemetry)? _telemetryListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOverlay();
    OverlayBridge.registerOverlayTappedHandler(() {
      if (!mounted) return;
      ref.read(assistantOpenProvider.notifier).state = true;
    });

    Future.microtask(() async {
      final node = await NodeIdentity.load();
      final session = await MeshHandshake.ensureSession(node);
      final hello = MeshHandshake.buildHelloFrame(session);
      final now = DateTime.now().millisecondsSinceEpoch;
      MeshEventBus.instance.emit(
        MeshEvent(
          type: MeshEventType.discoveryNote,
          originNodeId: node.nodeId,
          createdAtMillis: now,
          payload: hello,
        ),
      );
    });

    // Feed ConnectivityMode from live NetworkTelemetry so higher-level
    // planners and UI can react to real connectivity state.
    _telemetryListener = (SignalTelemetry _) {
      final mode = ConnectivityAdvisor.currentMode();
      ref.read(connectivityModeProvider.notifier).state = mode;
    };
    NetworkTelemetry.instance.addListener(_telemetryListener!);
  }

  @override
  void dispose() {
    final listener = _telemetryListener;
    if (listener != null) {
      NetworkTelemetry.instance.removeListener(listener);
      _telemetryListener = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkOverlay();
      // When returning from background (e.g. from the floating
      // bubble), pull any new chat messages written by the native
      // overlay into the in-app chat.
      ref.read(miniChatProvider.notifier).syncFromStore();

      // Opportunistically feed a coarse environment snapshot into
      // the twin orchestration layer so Phase 3 twin logic can run
      // without blocking UX.
      TwinEnvironmentBridge.handleAppResumed();
    }
  }

  Future<void> _checkOverlay() async {
    if (!Platform.isAndroid) return;
    final available = await OverlayBridge.isOverlayAvailable();
    if (!mounted || !available) return;

    // Mark overlay as granted; lifecycle decides when to show the native dot.
    ref.read(overlayPermissionGrantedProvider.notifier).state = true;

    // Once we know permission status, ensure overlay matches desired state.
    await _syncOverlay();
  }

  Future<void> _syncOverlay() async {
    if (!Platform.isAndroid) return;
    final permission = ref.read(overlayPermissionGrantedProvider);
    final powerOn = ref.read(omkPowerOnProvider);
    final floating = ref.read(floatingEnabledProvider);

    final shouldShow = permission && powerOn && floating;
    if (shouldShow) {
      await OverlayBridge.startOverlay();
    } else {
      await OverlayBridge.stopOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep native overlay bubble in sync with OMK power + floating settings.
    ref.listen<bool>(floatingEnabledProvider, (_, __) => _syncOverlay());
    ref.listen<bool>(omkPowerOnProvider, (_, __) => _syncOverlay());
    ref.listen<bool>(overlayPermissionGrantedProvider, (_, __) => _syncOverlay());

    return widget.child;
  }
}
