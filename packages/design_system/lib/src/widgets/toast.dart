import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../tokens.dart';

/// The design's toast (`.proto-toast`): a dark pill centred near the bottom,
/// bold white text, sliding up into view and leaving on its own after a
/// couple of seconds.
///
/// Replaces Material's SnackBar, which spans the whole width as a flat grey
/// bar in the platform font. A toast never takes a tap and never blocks the
/// page; a new one replaces the one showing, so messages never queue up.
/// It sits above the phone's bottom tab bar, and screen readers announce it.
abstract final class VillageToast {
  static OverlayEntry? _entry;
  static Timer? _timer;

  /// How long a toast stays: the design's 2.2s, plus time to read it.
  static const visibleFor = Duration(milliseconds: 2600);

  static void show(BuildContext context, String message, {IconData? icon}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    hide();

    final entry = OverlayEntry(
      builder: (_) => _Toast(message: message, icon: icon),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(visibleFor, hide);

    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  /// Removes the toast now, if one is showing.
  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _Toast extends StatefulWidget {
  const _Toast({required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    // One frame hidden, then slide in: `translateY(140%)` to `0`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final media = MediaQuery.of(context);
    final still = media.disableAnimations;
    // Above the bottom tab bar on phones (78px), the design's 26px
    // elsewhere; plus the device's own inset either way.
    final bottom =
        (media.size.width < Breakpoints.compact ? 78.0 + 14 : 26.0) +
        media.viewPadding.bottom;
    // Ink on light, and on dark the light surface so it still stands out.
    final background = p.isDark ? p.ink : VillageColors.ink;
    final foreground = p.isDark ? p.surface : Colors.white;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: IgnorePointer(
        child: Center(
          child: AnimatedSlide(
            offset: _shown ? Offset.zero : const Offset(0, 1.4),
            duration: still ? Duration.zero : Motion.quick,
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: _shown ? 1 : 0,
              duration: still ? Duration.zero : Motion.quick,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: p.shadow,
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          size: 16,
                          // Gold reads on the dark pill; the light pill (dark
                          // mode) needs the blue to show at all.
                          color: p.isDark ? p.quebecBlue : p.goldLight,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: VillageType.display,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
