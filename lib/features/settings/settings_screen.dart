import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/routing/page_tab.dart';
import '../../core/widgets/page_column.dart';
import '../../core/widgets/pill_tabs.dart';
import '../pairing/pairing_controller.dart';
import '../passcode/passcode_setup_screen.dart';
import '../profile/pin_gate.dart';
import 'remove_kid_dialog.dart';
import '../../data/local_db/app_settings.dart';
import '../reminders/reminder_coordinator.dart';
import '../reminders/reminder_policy.dart';
import '../reminders/reminder_scheduler.dart';
import 'settings_controller.dart';

/// Réglages, as `docs/design/01-design-system-gallery.html` draws it.
///
/// The design's groups as four pill tabs — Apparence, Son et musique,
/// Expérience, Zone parent — shown one at a time (Hafid, 2026-10-28; app ADR
/// 0051), the last tab remembered per kid. Notifications is a section inside
/// Expérience (Hafid, 2026-10-29), so the row never needs a fifth pill. Zone
/// parent holds the picture codes and sign-out too. Aide and À propos sit
/// under every tab.
///
/// Two things here are honest stubs rather than working controls, because
/// the thing behind them does not exist yet. Both say so on screen instead
/// of doing nothing when tapped:
///
/// - **Zone parent** deep-links to the portal (Q24: account, subscription
///   and privacy never happen inside a kid's app, so it never holds guardian
///   credentials). The portal is Track F and unbuilt.
/// - **Notifications** are local reminders only (ADR 0053): no push, none
///   on web or a class tablet, and the screen says which applies.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({this.onOpenHelp, this.onOpenAbout, super.key});

  /// Supplied by the shell, which owns which page is showing. The screen
  /// does not navigate itself — same reason `VillageNavShell` does not.
  final VoidCallback? onOpenHelp;
  final VoidCallback? onOpenAbout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VillagePalette.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final t = context.s;
    final stored = ref.watch(pageTabProvider(TabbedPage.settings));
    final tab = SettingsTab.from(stored);

    final panel = switch (tab) {
      SettingsTab.appearance => _Group(
        children: [
          _SegmentedRow(
            label: t.settingsTheme,
            sublabel: t.settingsThemeSub,
            options: [t.settingsThemeLight, t.settingsThemeDark],
            selected: settings.darkTheme ? 1 : 0,
            onSelect: (i) => controller.setDarkTheme(i == 1),
          ),
        ],
      ),
      SettingsTab.sound => _Group(
        children: [
          _SliderRow(
            label: t.settingsVolume,
            value: settings.volume,
            onChanged: controller.setVolume,
          ),
          _ToggleRow(
            label: t.settingsMusic,
            value: settings.music,
            onChanged: controller.setMusic,
          ),
          _ToggleRow(
            label: t.settingsSfx,
            value: settings.soundEffects,
            onChanged: controller.setSoundEffects,
          ),
          _ToggleRow(
            label: t.settingsReadAloud,
            sublabel: t.settingsReadAloudSub,
            value: settings.readAloud,
            onChanged: controller.setReadAloud,
          ),
        ],
      ),
      SettingsTab.experience => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Group(
            children: [
              _SegmentedRow(
                label: t.settingsLanguage,
                options: ['Français', 'English'],
                selected: settings.english ? 1 : 0,
                onSelect: (i) => controller.setEnglish(i == 1),
              ),
              _ToggleRow(
                label: t.settingsReduceMotion,
                sublabel: t.settingsReduceMotionSub,
                value: settings.reduceMotion,
                onChanged: controller.setReduceMotion,
              ),
            ],
          ),
          // Was its own tab until 2026-10-29. A link to the old tab lands
          // here, scrolled to this heading.
          _SectionHeading(
            key: const ValueKey('settings-section-notifications'),
            label: t.settingsNotifications,
            icon: Icons.notifications_none,
            reveal: stored == SettingsTab.notificationsSection,
          ),
          _Group(children: _reminderRows(context, ref, settings)),
        ],
      ),
      SettingsTab.parents => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ParentZone(),
          const SizedBox(height: Space.md),
          // Each kid's "c'est moi" pictures, behind the guardian PIN
          // (B-A0.5).
          _LinkRow(
            key: const ValueKey('settings-passcodes'),
            icon: Icons.grid_view_rounded,
            label: t.passcodesTitle,
            onTap: () => openPasscodes(context, ref),
          ),
          const SizedBox(height: Space.lg),
          const _SignOutButton(),
          const SizedBox(height: Space.md),
        ],
      ),
    };

    return PageColumn.builder(
      builder: (context, compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PageTitle(eyebrow: t.settingsEyebrow, title: t.settingsTitle),
            const SizedBox(height: Space.md),
            PillTabs<SettingsTab>(
              keyPrefix: 'settings-tab',
              selected: tab,
              compact: compact,
              onSelect: (next) => ref
                  .read(pageTabProvider(TabbedPage.settings).notifier)
                  .select(next.name),
              tabs: [
                for (final s in SettingsTab.values)
                  PillTab(
                    value: s,
                    label: s.label(t),
                    leading: Icon(
                      s.icon,
                      size: compact ? 18 : 20,
                      color: s == tab ? p.quebecBlueBright : p.inkMuted,
                    ),
                  ),
              ],
            ),
            // The raw name, so a link to the old Notifications tab
            // rebuilds the panel and scrolls even from Expérience.
            PillTabPanel(tabKey: stored ?? tab.name, child: panel),

            // Under every tab: never more than a tap away.
            const SizedBox(height: Space.sm),
            _LinkRow(
              icon: Icons.help_outline,
              label: t.navHelp,
              onTap: onOpenHelp ?? () => _notBuilt(context, t.navHelp),
            ),
            const SizedBox(height: Space.xs),
            _LinkRow(
              icon: Icons.info_outline,
              label: t.settingsAbout,
              onTap: onOpenAbout ?? () => _notBuilt(context, t.settingsAbout),
            ),
            const SizedBox(height: Space.md),
            Text(
              'TutoLys · v$appVersion',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: VillageType.display,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: p.inkMuted,
              ),
            ),
            const SizedBox(height: Space.xl),
          ],
        );
      },
    );
  }

  /// "Rappels quotidiens" with its time, and "Ma flamme" (ADR 0053).
  /// Turning either on, or choosing the time, needs the guardian PIN and
  /// asks the OS while the guardian holds the device; turning them off never
  /// does, because doing less is always safe. Not offered on web or on a
  /// class tablet.
  List<Widget> _reminderRows(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final t = context.s;
    final controller = ref.read(settingsControllerProvider.notifier);
    final classTablet = ref.watch(
      sessionControllerProvider.select((s) => s.isClassroom),
    );
    final support = ref.watch(reminderSupportProvider);
    final unavailable = classTablet || support == ReminderSupport.none;
    final note = classTablet
        ? t.settingsRemindersClassNote
        : switch (support) {
            ReminderSupport.none => t.settingsRemindersWebNote,
            ReminderSupport.whileRunning => t.settingsRemindersWhileRunning,
            ReminderSupport.scheduled => null,
          };

    Future<bool> guardian() => requireGuardianPin(
      context,
      ref,
      confirmLabel: t.pinGateContinue,
      createSubtitle: t.remindersPinCreate,
      enterSubtitle: t.remindersPinEnter,
    );

    Future<void> turnOn(Future<void> Function(bool) set) async {
      if (!await guardian() || !context.mounted) return;
      final sink = await ref.read(reminderSinkProvider.future);
      if (!await sink.requestPermission()) {
        if (context.mounted) {
          VillageToast.show(context, t.settingsRemindersBlocked);
        }
        return;
      }
      await set(true);
    }

    Future<void> chooseTime() async {
      if (!await guardian() || !context.mounted) return;
      final chosen = await showDialog<int>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(t.settingsReminderTime),
          children: [
            for (final m in reminderSlots)
              SimpleDialogOption(
                key: ValueKey('reminder-slot-$m'),
                onPressed: () => Navigator.of(context).pop(m),
                child: Text(
                  t.reminderTimeLabel(m),
                  style: TextStyle(
                    fontWeight: m == settings.reminderMinutes
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      );
      if (chosen != null) await controller.setReminderMinutes(chosen);
    }

    return [
      _ToggleRow(
        key: const ValueKey('settings-reminders'),
        label: t.settingsDailyReminders,
        sublabel: note ?? t.settingsDailyRemindersSub,
        value: settings.dailyReminders && !unavailable,
        onChanged: unavailable
            ? null
            : (on) => on
                  ? turnOn(controller.setDailyReminders)
                  : controller.setDailyReminders(false),
      ),
      if (settings.dailyReminders && !unavailable)
        _ValueRow(
          key: const ValueKey('settings-reminder-time'),
          label: t.settingsReminderTime,
          value: t.reminderTimeLabel(settings.reminderMinutes),
          onTap: chooseTime,
        ),
      _ToggleRow(
        key: const ValueKey('settings-flame'),
        label: t.settingsFlameReminders,
        sublabel: t.settingsFlameRemindersSub,
        value: settings.flameReminders && !unavailable,
        onChanged: unavailable
            ? null
            : (on) => on
                  ? turnOn(controller.setFlameReminders)
                  : controller.setFlameReminders(false),
      ),
    ];
  }

  static void _notBuilt(BuildContext context, String what) {
    VillageToast.show(context, '$what — ${context.s.notBuiltYetSuffix}');
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            fontFamily: VillageType.display,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: p.inkMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            fontFamily: VillageType.display,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: p.ink,
          ),
        ),
      ],
    );
  }
}

/// A white card holding a tab's rows. The tab's pill names it, so the
/// card carries no title of its own.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Material(
      color: p.surface,
      borderRadius: VillageMetrics.mdAll,
      elevation: VillageColors.elevationSmall,
      shadowColor: p.shadowSmall,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, color: p.line),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Réglages' four tabs, in the design's group order. The stored name is
/// [Enum.name]; [notificationsSection] opens Expérience at its
/// Notifications section; anything else (none yet, or a tab since renamed)
/// opens the first.
enum SettingsTab {
  appearance(Icons.light_mode_outlined),
  sound(Icons.volume_up_outlined),
  experience(Icons.language_outlined),
  parents(Icons.family_restroom_outlined);

  const SettingsTab(this.icon);

  final IconData icon;

  /// The old fifth tab's stored name, now a section of [experience]. Still
  /// valid to select: a remembered tab or a link to it lands there.
  static const notificationsSection = 'notifications';

  static SettingsTab from(String? name) => name == notificationsSection
      ? experience
      : values.firstWhere((v) => v.name == name, orElse: () => appearance);

  String label(Strings t) => switch (this) {
    appearance => t.settingsAppearance,
    sound => t.settingsSound,
    experience => t.settingsExperience,
    parents => t.settingsParentZone,
  };
}

/// A section's title between two cards of one tab, as the design heads
/// each `.quest-panel`. With [reveal], it scrolls itself into view once
/// when first shown.
class _SectionHeading extends StatefulWidget {
  const _SectionHeading({
    required this.label,
    required this.icon,
    this.reveal = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool reveal;

  @override
  State<_SectionHeading> createState() => _SectionHeadingState();
}

class _SectionHeadingState extends State<_SectionHeading> {
  @override
  void initState() {
    super.initState();
    if (!widget.reveal) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : Motion.quick,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, Space.lg, 4, Space.sm),
        child: Row(
          children: [
            Icon(widget.icon, size: 20, color: p.quebecBlueBright),
            const SizedBox(width: Space.xs),
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: VillageType.display,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
          ],
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
    final p = VillagePalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: VillageType.display,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: p.ink,
          ),
        ),
        if (sublabel != null)
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Text(
              sublabel!,
              style: TextStyle(
                fontFamily: VillageType.display,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: p.inkMuted,
              ),
            ),
          ),
      ],
    );
  }
}

/// A label and its current value; tapping changes it.
class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: VillageMetrics.mdAll,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(
          children: [
            Expanded(child: _RowLabel(label: label)),
            Text(
              value,
              style: TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: p.quebecBlueBright,
              ),
            ),
            const SizedBox(width: Space.xxs),
            Icon(Icons.chevron_right_rounded, color: p.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.sublabel,
    super.key,
  });

  final String label;
  final String? sublabel;
  final bool value;

  /// Null greys the switch out.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Expanded(
            child: _RowLabel(label: label, sublabel: sublabel),
          ),
          VillageSwitch(
            value: value,
            onChanged: onChanged,
            semanticLabel: label,
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
      padding: EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Expanded(
            child: _RowLabel(label: label, sublabel: sublabel),
          ),
          VillageSegmented(
            options: options,
            selected: selected,
            onSelect: onSelect,
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
    final p = VillagePalette.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _RowLabel(label: label)),
              Text(
                '$value %',
                style: TextStyle(
                  fontFamily: VillageType.display,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: p.inkMuted,
                ),
              ),
            ],
          ),
          // `.vol-slider-row`: speaker icon, then the bar.
          Row(
            children: [
              Icon(Icons.volume_up_outlined, size: 18, color: p.inkMuted),
              Expanded(
                child: VillageSlider(
                  value: value.toDouble(),
                  divisions: 20,
                  onChanged: (v) => onChanged(v.round()),
                  semanticFormatterCallback: (v) => '${v.round()} %',
                ),
              ),
            ],
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
    final p = VillagePalette.of(context);
    final t = context.s;
    return Material(
      color: p.quebecBlue,
      borderRadius: VillageMetrics.mdAll,
      child: Padding(
        padding: EdgeInsets.all(Space.md),
        child: Row(
          children: [
            const Icon(Icons.open_in_new, color: Colors.white, size: 22),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.settingsParentZone,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.settingsParentZoneBody,
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
                foregroundColor: p.quebecBlue,
                minimumSize: Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                // The design's display face, like every other button;
                // Material's default fell back to the platform font.
                textStyle: const TextStyle(
                  fontFamily: VillageType.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              // Account, subscription and privacy live on the website, not
              // in here — the app is for playing (Hafid, 2026-10-24). The
              // site is Track F and unbuilt, so this says where it will go
              // rather than opening nothing.
              onPressed: () => VillageToast.show(
                context,
                t.settingsParentZoneSoon,
                icon: Icons.schedule_rounded,
              ),
              child: Text(t.settingsParentZoneCta),
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
    super.key,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    return Material(
      color: p.surface,
      borderRadius: VillageMetrics.mdAll,
      elevation: VillageColors.elevationSmall,
      shadowColor: p.shadowSmall,
      child: InkWell(
        onTap: onTap,
        borderRadius: VillageMetrics.mdAll,
        child: Padding(
          padding: EdgeInsets.all(Space.md),
          child: Row(
            children: [
              Icon(icon, size: 19, color: p.quebecBlue),
              const SizedBox(width: Space.sm),
              Expanded(child: _RowLabel(label: label)),
              Icon(Icons.chevron_right, size: 20, color: p.inkMuted),
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
        backgroundColor: Color(0xFFFFF1F1),
        minimumSize: Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: VillageMetrics.mdAll),
      ),
      icon: Icon(Icons.logout, size: 19),
      label: Text(
        context.s.settingsSignOut,
        style: TextStyle(
          fontFamily: VillageType.display,
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: () async {
        final allowed = await requireGuardianPin(context, ref);
        if (!allowed || !context.mounted) return;
        final kid = ref.read(sessionControllerProvider).kid;
        final erase = await confirmRemoveKid(
          context,
          kidName: kid?.displayName ?? '',
        );
        if (!erase) return;
        ref.read(sessionControllerProvider.notifier).forget();
      },
    );
  }
}
