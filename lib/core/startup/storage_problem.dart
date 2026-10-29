import 'dart:ui' show PlatformDispatcher;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../data/local_db/database.dart' show localDatabaseName;
import '../../data/local_db/storage_repair.dart';
import '../diagnostics/diag_log.dart';
import '../i18n/strings.dart';

/// The local store wouldn't open, even on a fresh worker (K5, ADR 0099).
///
/// Says it's the device's storage, never the Internet: the network is
/// usually fine, and "connecte-toi" sent families chasing the wrong thing.
/// Réessayer opens again (on the web, after a reload on fresh assets).
/// Réparer, on the web, resets the browser's copy after saying what is
/// lost: progress not yet sent from this device. Pairings and everything
/// already sent are kept elsewhere and come back.
///
/// Plain on purpose, like `MisconfiguredApp`: no providers, since the
/// database they would read is the thing that failed. The language is the
/// device's.
class StorageProblemApp extends StatelessWidget {
  const StorageProblemApp({required this.onRetry, super.key});

  /// Opens again and runs the app if it works.
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final english =
        PlatformDispatcher.instance.locale.languageCode == 'en';
    final t = english ? Strings.en : Strings.fr;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: TutolysTheme.village(),
      home: StorageProblemScreen(strings: t, onRetry: onRetry),
    );
  }
}

class StorageProblemScreen extends StatefulWidget {
  const StorageProblemScreen({
    required this.strings,
    required this.onRetry,
    this.canRepair,
    this.repair,
    super.key,
  });

  final Strings strings;
  final Future<void> Function() onRetry;
  /// Null: whatever the platform offers ([canRepairStorage]).
  final bool? canRepair;

  /// Replaces the real reset in tests.
  final Future<void> Function()? repair;

  @override
  State<StorageProblemScreen> createState() => _StorageProblemScreenState();
}

class _StorageProblemScreenState extends State<StorageProblemScreen> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    if (canRepairStorage) {
      // A reload is the surest fresh start on the web: new page, new worker.
      reloadApp();
      return;
    }
    await widget.onRetry();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _repair() async {
    final t = widget.strings;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('storage-repair-confirm'),
        title: Text(t.storageRepairTitle),
        content: Text(t.storageRepairBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton(
            key: const ValueKey('storage-repair-go'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.storageRepair),
          ),
        ],
      ),
    );
    if (sure != true) return;
    setState(() => _busy = true);
    // Counted: what this reset cost can't be read back from a store that
    // won't open, so the reset itself is what's recorded.
    recordCaught('storage_reset', 'local store reset after a failed open');
    if (widget.repair != null) {
      await widget.repair!();
    } else {
      await repairStorage(localDatabaseName);
      reloadApp();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final t = widget.strings;
    return Scaffold(
      key: const ValueKey('storage-problem'),
      backgroundColor: p.skyBottom,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/asset-mascot-welcome.webp',
                    height: 130,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: Space.md),
                  Text(
                    t.storageProblemTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    t.storageProblemBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: p.inkMuted,
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  FilledButton.icon(
                    key: const ValueKey('storage-retry'),
                    onPressed: _busy ? null : _retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(t.retry),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.gold,
                      foregroundColor: const Color(0xFF241A04),
                      shape: const StadiumBorder(),
                    ),
                  ),
                  if (widget.canRepair ?? canRepairStorage) ...[
                    const SizedBox(height: Space.sm),
                    TextButton(
                      key: const ValueKey('storage-repair'),
                      onPressed: _busy ? null : _repair,
                      child: Text(t.storageRepair),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
