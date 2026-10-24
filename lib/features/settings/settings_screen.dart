import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pairing/pairing_controller.dart';
import '../profile/pin_gate.dart';
import 'settings_controller.dart';

/// Réglages, as `docs/design/01-design-system-gallery.html` draws it.
///
/// Five groups in the design's own order — Apparence, Son et musique,
/// Expérience, Notifications, Zone parent — then the two navigation rows and
/// sign-out.
///
/// Two things here are honest stubs rather than working controls, because
/// the thing behind them does not exist yet. Both say so on screen instead
/// of doing nothing when tapped:
///
/// - **Zone parent** deep-links to the portal (Q24: account, subscription
///   and privacy never happen inside a kid's app, so it never holds guardian
///   credentials). The portal is Track F and unbuilt.
/// - **Notifications** persist as real flags, but no push infrastructure
///   exists on any platform. The old product shipped exactly this and the
///   Flutter spec flagged it as a defect, so it is called out rather than
///   repeated silently.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Space.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _PageTitle(eyebrow: 'Ton espace', title: 'Réglages'),
              const SizedBox(height: Space.lg),

              _Group(
                icon: Icons.light_mode_outlined,
                title: 'Apparence',
                children: [
                  _SegmentedRow(
                    label: 'Thème',
                    sublabel: 'Clair ou sombre',
                    options: const ['Clair', 'Sombre'],
                    selected: settings.darkTheme ? 1 : 0,
                    onSelect: (i) => controller.setDarkTheme(i == 1),
                  ),
                ],
              ),

              _Group(
                icon: Icons.volume_up_outlined,
                title: 'Son et musique',
                children: [
                  _SliderRow(
                    label: 'Volume général',
                    value: settings.volume,
                    onChanged: controller.setVolume,
                  ),
                  _ToggleRow(
                    label: 'Musique de fond',
                    value: settings.music,
                    onChanged: controller.setMusic,
                  ),
                  _ToggleRow(
                    label: 'Effets sonores',
                    value: settings.soundEffects,
                    onChanged: controller.setSoundEffects,
                  ),
                  _ToggleRow(
                    label: 'Lire les questions à voix haute',
                    sublabel: 'Recommandé pour les débuts en lecture',
                    value: settings.readAloud,
                    onChanged: controller.setReadAloud,
                  ),
                ],
              ),

              _Group(
                icon: Icons.language_outlined,
                title: 'Expérience',
                children: [
                  _SegmentedRow(
                    label: 'Langue',
                    options: const ['Français', 'English'],
                    selected: settings.english ? 1 : 0,
                    onSelect: (i) => controller.setEnglish(i == 1),
                  ),
                  _ToggleRow(
                    label: 'Réduire les animations',
                    sublabel: 'Pour un affichage plus calme',
                    value: settings.reduceMotion,
                    onChanged: controller.setReduceMotion,
                  ),
                ],
              ),

              _Group(
                icon: Icons.notifications_none,
                title: 'Notifications',
                children: [
                  _ToggleRow(
                    label: 'Rappels quotidiens',
                    sublabel: "Un petit coucou si tu n'as pas joué",
                    value: settings.dailyReminders,
                    onChanged: controller.setDailyReminders,
                  ),
                  _ToggleRow(
                    label: 'Nouvelles quêtes',
                    value: settings.questNotifications,
                    onChanged: controller.setQuestNotifications,
                  ),
                ],
              ),

              const _ParentZone(),
              const SizedBox(height: Space.md),

              _LinkRow(
                icon: Icons.help_outline,
                label: 'Aide & support',
                onTap: () => _notBuilt(context, 'Aide & support'),
              ),
              const SizedBox(height: Space.xs),
              _LinkRow(
                icon: Icons.info_outline,
                label: 'À propos de TutoLys',
                onTap: () => _notBuilt(context, 'À propos'),
              ),

              const SizedBox(height: Space.lg),
              const _SignOutButton(),
              const SizedBox(height: Space.md),
              const Text(
                'TutoLys · v$appVersion',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: VillageColors.inkMuted,
                ),
              ),
              const SizedBox(height: Space.xl),
            ],
          ),
        ),
      ),
    );
  }

  static void _notBuilt(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what — pas encore construit')),
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            fontFamily: VillageType.display,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: VillageColors.inkMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontFamily: VillageType.display,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: VillageColors.ink,
          ),
        ),
      ],
    );
  }
}

/// A white card with a titled header and a list of rows.
class _Group extends StatelessWidget {
  const _Group({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Material(
        color: VillageColors.surface,
        borderRadius: VillageMetrics.mdAll,
        elevation: VillageColors.elevationSmall,
        shadowColor: VillageColors.shadowSmall,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: VillageColors.quebecBlue),
                    const SizedBox(width: Space.xs),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: VillageType.display,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: VillageColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, color: VillageColors.line),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.label, this.sublabel});

  final String label;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: VillageType.display,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: VillageColors.ink,
          ),
        ),
        if (sublabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              sublabel!,
              style: const TextStyle(
                fontFamily: VillageType.display,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: VillageColors.inkMuted,
              ),
            ),
          ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.sublabel,
  });

  final String label;
  final String? sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Expanded(child: _RowLabel(label: label, sublabel: sublabel)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: VillageColors.quebecBlueBright,
          ),
        ],
      ),
    );
  }
}

class _SegmentedRow extends StatelessWidget {
  const _SegmentedRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.sublabel,
  });

  final String label;
  final String? sublabel;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Expanded(child: _RowLabel(label: label, sublabel: sublabel)),
          DecoratedBox(
            decoration: BoxDecoration(
              color: VillageColors.track,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < options.length; i++)
                  GestureDetector(
                    onTap: () => onSelect(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: i == selected
                            ? VillageColors.surface
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        options[i],
                        style: TextStyle(
                          fontFamily: VillageType.display,
                          fontSize: 13,
                          fontWeight:
                              i == selected ? FontWeight.w800 : FontWeight.w600,
                          color: i == selected
                              ? VillageColors.quebecBlueBright
                              : VillageColors.inkMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _RowLabel(label: label)),
              Text(
                '$value %',
                style: const TextStyle(
                  fontFamily: VillageType.display,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: VillageColors.inkMuted,
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            max: 100,
            divisions: 20,
            activeColor: VillageColors.quebecBlueBright,
            inactiveColor: VillageColors.track,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}

/// The navy card. Everything behind it is portal work (Track F), so the
/// button says what it would do rather than pretending to do it.
class _ParentZone extends StatelessWidget {
  const _ParentZone();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VillageColors.quebecBlue,
      borderRadius: VillageMetrics.mdAll,
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
            const SizedBox(width: Space.sm),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zone parent',
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Certains réglages (compte, abonnement, '
                    "confidentialité) nécessitent l'autorisation d'un parent.",
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC9D8F5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: VillageColors.quebecBlue,
                minimumSize: const Size(0, 40),
              ),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Le portail parent n’existe pas encore — '
                    'rien à déverrouiller pour l’instant.',
                  ),
                ),
              ),
              child: const Text('Déverrouiller'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VillageColors.surface,
      borderRadius: VillageMetrics.mdAll,
      elevation: VillageColors.elevationSmall,
      shadowColor: VillageColors.shadowSmall,
      child: InkWell(
        onTap: onTap,
        borderRadius: VillageMetrics.mdAll,
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(
            children: [
              Icon(icon, size: 19, color: VillageColors.quebecBlue),
              const SizedBox(width: Space.sm),
              Expanded(child: _RowLabel(label: label)),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: VillageColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sign-out, behind the guardian PIN.
///
/// Same gate `ProfileScreen` already uses: not a security boundary, just
/// enough that a casual tap cannot cost a guardian a full re-pair
/// (ADR 0010).
class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: TutolysColors.danger,
        backgroundColor: const Color(0xFFFFF1F1),
        minimumSize: const Size(0, 52),
        shape: const RoundedRectangleBorder(
          borderRadius: VillageMetrics.mdAll,
        ),
      ),
      icon: const Icon(Icons.logout, size: 19),
      label: const Text(
        'Se déconnecter',
        style: TextStyle(
          fontFamily: VillageType.display,
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: () async {
        final allowed = await requireGuardianPin(context, ref);
        if (!allowed || !context.mounted) return;
        ref.read(sessionControllerProvider.notifier).forget();
      },
    );
  }
}
