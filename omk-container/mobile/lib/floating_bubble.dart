import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n.dart';
import 'mini_chat.dart';
import 'security_checkpoint.dart';
import 'state.dart';

class FloatingBubbleOverlay extends ConsumerWidget {
  const FloatingBubbleOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(floatingEnabledProvider);
    // The in-app bubble is the primary collapsible UI (mini chat, quick
    // actions). It should always be available while OMK is foregrounded
    // whenever the setting is enabled.
    final showBubble = enabled;
    return Stack(
      children: [
        child,
        if (showBubble) const _DraggableBubble(),
      ],
    );
  }
}

class _DraggableBubble extends ConsumerStatefulWidget {
  const _DraggableBubble();

  @override
  ConsumerState<_DraggableBubble> createState() => _DraggableBubbleState();
}

class _DraggableBubbleState extends ConsumerState<_DraggableBubble>
    with SingleTickerProviderStateMixin {
  late Offset position;
  double _opacity = 1.0;
  Timer? _fadeTimer;

  @override
  void initState() {
    super.initState();
    position = const Offset(20, 120);
    // Schedule initial fade-out so the debug bubble does not permanently
    // obscure content when first shown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _bumpVisibility();
      }
    });
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    super.dispose();
  }

  void _bumpVisibility() {
    setState(() {
      _opacity = 1.0;
    });
    _fadeTimer?.cancel();
    _fadeTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _opacity = 0.3;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final expanded = ref.watch(bubbleExpandedProvider);
    final strings = Strings.of(context);
    final media = MediaQuery.of(context);
    final size = media.size;
    final insets = media.viewInsets;
    const bubbleSize = 56.0;
    const targetExpandedWidth = 320.0;
    const targetExpandedHeight = 260.0;

    // Ensure the expanded panel never exceeds the viewport minus margins.
    // When the keyboard is visible, shrink the available height accordingly
    // so the bubble stays above it.
    final availableHeight = size.height - insets.bottom;
    final maxWidth = size.width - 16.0;
    final maxHeight = availableHeight - 80.0;
    final expandedWidth =
        maxWidth >= targetExpandedWidth ? targetExpandedWidth : maxWidth;
    final expandedHeight =
        maxHeight >= targetExpandedHeight ? targetExpandedHeight : maxHeight;

    final currentWidth = expanded ? expandedWidth : bubbleSize;
    final currentHeight = expanded ? expandedHeight : bubbleSize;

    final maxX = size.width - currentWidth - 8.0;
    final maxY = availableHeight - currentHeight - 40.0;
    final clampedX = position.dx.clamp(8.0, maxX >= 8.0 ? maxX : 8.0);
    final clampedY = position.dy.clamp(40.0, maxY >= 40.0 ? maxY : 40.0);

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            position += details.delta;
          });
          _bumpVisibility();
        },
        // When expanded, let inner widgets (TextField, buttons) handle taps
        // without collapsing the panel.
        onTap: expanded
            ? null
            : () {
                final nextExpanded = !expanded;
                if (nextExpanded) {
                  final centerX = (size.width - expandedWidth) / 2;
                  final centerY = (availableHeight - expandedHeight) / 2;
                  setState(() {
                    position = Offset(centerX, centerY);
                  });
                }
                ref.read(bubbleExpandedProvider.notifier).state = nextExpanded;
                _bumpVisibility();
              },
        child: Semantics(
          label: strings.bubbleLabel,
          button: true,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _opacity,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: expanded ? expandedWidth : bubbleSize,
              height: expanded ? expandedHeight : bubbleSize,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius:
                    BorderRadius.circular(expanded ? 20 : bubbleSize / 2),
                border: Border.all(
                  color: const Color(0xFFD4AF37),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: expanded
                  ? const _ExpandedBubbleContent()
                  : const _CollapsedBubbleContent(),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedBubbleContent extends ConsumerWidget {
  const _CollapsedBubbleContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = Strings.of(context);
    // In a full build, this widget would read the last SecurityCheckpoint
    // result from state. For now, we display a neutral status.
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.shield_moon_rounded,
            color: Color(0xFFD4AF37),
            size: 24,
          ),
          const SizedBox(height: 2),
          Text(
            strings.miniChatTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 9,
                ),
          ),
        ],
      ),
    );
  }
}

class _ExpandedBubbleContent extends ConsumerWidget {
  const _ExpandedBubbleContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                Strings.of(context).miniChatTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Colors.white),
              ),
            ),
            IconButton(
              iconSize: 24,
              onPressed: () {
                ref.read(bubbleExpandedProvider.notifier).state = false;
              },
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ],
        ),
        const Expanded(
          child: Material(
            color: Colors.transparent,
            child: MiniChatPanel(),
          ),
        ),
      ],
    );
  }
}
