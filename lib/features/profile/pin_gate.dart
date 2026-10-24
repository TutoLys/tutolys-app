import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../data/local_db/session_store.dart';
import '../pairing/pairing_controller.dart' show sessionStoreProvider;

final _pinPattern = RegExp(r'^\d{4}$');

/// Gate before "sign out this device": requires a parent-set PIN.
///
/// Deliberately not a security boundary (see `SessionStore.setGuardianPin`)
/// — a determined kid could still ask an adult. It exists to stop a casual
/// tap from signing the device out, which otherwise costs a guardian a
/// full re-pair. The first time this runs on a device, there's no PIN to
/// check yet, so creating one *is* the gate.
///
/// Returns whether the caller may proceed with the sign-out.
Future<bool> requireGuardianPin(BuildContext context, WidgetRef ref) async {
  final store = ref.read(sessionStoreProvider);
  final hasPin = await store.hasGuardianPin();
  if (!context.mounted) return false;

  final result = hasPin
      ? await showDialog<bool>(
          context: context,
          builder: (context) => _EnterPinDialog(store: store),
        )
      : await showDialog<bool>(
          context: context,
          builder: (context) => _CreatePinDialog(store: store),
        );
  return result ?? false;
}

class _CreatePinDialog extends StatefulWidget {
  const _CreatePinDialog({required this.store});

  final SessionStore store;

  @override
  State<_CreatePinDialog> createState() => _CreatePinDialogState();
}

class _CreatePinDialogState extends State<_CreatePinDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = context.s;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_pinController.text != _confirmController.text) {
      setState(() => _error = s.pinGateMismatch);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    await widget.store.setGuardianPin(_pinController.text);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      title: Text(s.pinGateCreateTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.pinGateCreateSubtitle),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _pinController,
              decoration: InputDecoration(labelText: s.pinGatePinLabel),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              autofocus: true,
              validator: (value) =>
                  _pinPattern.hasMatch(value ?? '') ? null : s.pinGateTooShort,
            ),
            TextFormField(
              controller: _confirmController,
              decoration: InputDecoration(labelText: s.pinGateConfirmPinLabel),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              validator: (value) =>
                  _pinPattern.hasMatch(value ?? '') ? null : s.pinGateTooShort,
            ),
            if (_error != null) ...[
              const SizedBox(height: Space.sm),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(s.pinGateCreate),
        ),
      ],
    );
  }
}

class _EnterPinDialog extends StatefulWidget {
  const _EnterPinDialog({required this.store});

  final SessionStore store;

  @override
  State<_EnterPinDialog> createState() => _EnterPinDialogState();
}

class _EnterPinDialogState extends State<_EnterPinDialog> {
  final _pinController = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = context.s;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final correct = await widget.store.verifyGuardianPin(_pinController.text);
    if (!mounted) return;

    if (correct) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _error = s.pinGateWrong;
      _pinController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      title: Text(s.pinGateEnterTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.pinGateEnterSubtitle),
          const SizedBox(height: Space.md),
          TextField(
            controller: _pinController,
            decoration: InputDecoration(labelText: s.pinGatePinLabel),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            autofocus: true,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: Space.sm),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(s.pinGateConfirmSignOut),
        ),
      ],
    );
  }
}
