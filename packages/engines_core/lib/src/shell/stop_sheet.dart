import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'activity_shell.dart' show onAccentInk;
import 'shell_strings.dart';

/// « Tu veux arrêter ? »: the sheet the activity's ✕ opens once a série has
/// started. Continuer is the big, focused choice and returns false;
/// « Arrêter » returns true; dismissing it returns null.
///
/// Public so the host can open the same sheet for the phone's or browser's
/// Back (app ADR 0107, AM20) instead of keeping a copy.
Future<bool?> showActivityStopSheet(BuildContext context, ShellStrings s) =>
    showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final p = VillagePalette.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              key: const ValueKey('stop-sheet'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pause_circle_rounded, size: 56, color: p.gold),
                const SizedBox(height: Space.sm),
                Text(
                  s.stopTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: VillageType.display,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  s.stopMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: p.ink),
                ),
                const SizedBox(height: Space.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('stop-continue'),
                    autofocus: true,
                    onPressed: () => Navigator.of(context).pop(false),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.gold,
                      foregroundColor: onAccentInk,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      s.continueLabel.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: VillageType.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.sm),
                TextButton(
                  key: const ValueKey('stop-quit'),
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: p.ink),
                  child: Text(s.stopLabel),
                ),
              ],
            ),
          ),
        );
      },
    );
