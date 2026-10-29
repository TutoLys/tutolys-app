import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';

import '../i18n/strings.dart';

/// One pill: what it selects, its words, and its icon (a building image on
/// the Carte, an icon on Réglages).
class PillTab<T> {
  const PillTab({required this.value, required this.label, this.leading});

  final T value;
  final String label;

  /// Given a tight [PillTabs.leadingSize] square.
  final Widget? leading;
}

/// The design's `.subject-tabs`: a horizontally scrolling row of pills.
///
/// Shared by every page that switches between categories, so they all look
/// and behave like the Carte (app ADR 0051):
///
/// - **Keyboard:** Tab reaches the row; ←/→ move to the neighbouring pill
///   and select it, Home/End jump to the ends; Enter and Space select.
/// - **Screen reader:** a tab bar of tabs, each "selected" or not, with its
///   place ("onglet 2 sur 5").
/// - **Never a hard cut:** when the pills don't fit, the row scrolls (by
///   touch, mouse drag, trackpad or keyboard) and the edge with more pills
///   fades out, so a pill half out of view reads as "more this way" rather
///   than as a clipped label (Hafid, 2026-10-29). The selected pill is
///   brought into view when it changes, instantly when motion is reduced.
class PillTabs<T> extends StatefulWidget {
  const PillTabs({
    required this.tabs,
    required this.selected,
    required this.onSelect,
    required this.compact,
    this.keyPrefix = 'pill',
    super.key,
  });

  final List<PillTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onSelect;
  final bool compact;

  /// Each pill is keyed `ValueKey('$keyPrefix-$value')`, an enum by its
  /// name.
  final String keyPrefix;

  static double leadingSize(bool compact) => compact ? 24 : 30;

  @override
  State<PillTabs<T>> createState() => _PillTabsState<T>();
}

class _PillTabsState<T> extends State<PillTabs<T>> {
  final _nodes = <FocusNode>[];
  final _keys = <GlobalKey>[];

  /// Whether pills are hidden past each edge: that edge fades.
  bool _moreBefore = false;
  bool _moreAfter = false;

  /// Width of the fade, about half a short pill.
  static const fadeWidth = 28.0;

  bool _onMetrics(ScrollMetrics m) {
    final before = m.pixels > m.minScrollExtent + 0.5;
    final after = m.pixels < m.maxScrollExtent - 0.5;
    if (before != _moreBefore || after != _moreAfter) {
      setState(() {
        _moreBefore = before;
        _moreAfter = after;
      });
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _sync();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(instant: true));
  }

  @override
  void didUpdateWidget(PillTabs<T> old) {
    super.didUpdateWidget(old);
    _sync();
    if (old.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  void _sync() {
    while (_nodes.length < widget.tabs.length) {
      _nodes.add(FocusNode());
      _keys.add(GlobalKey());
    }
    while (_nodes.length > widget.tabs.length) {
      _nodes.removeLast().dispose();
      _keys.removeLast();
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  static String _name(Object? v) => v is Enum ? v.name : '$v';

  int get _selectedIndex =>
      widget.tabs.indexWhere((t) => t.value == widget.selected);

  void _reveal({bool instant = false}) {
    if (!mounted) return;
    final i = _selectedIndex;
    if (i < 0) return;
    final ctx = _keys[i].currentContext;
    if (ctx == null) return;
    final still = instant || MediaQuery.disableAnimationsOf(context);
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: still ? Duration.zero : Motion.quick,
    );
  }

  KeyEventResult _onKey(int i, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final last = widget.tabs.length - 1;
    final target = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight => i < last ? i + 1 : 0,
      LogicalKeyboardKey.arrowLeft => i > 0 ? i - 1 : last,
      LogicalKeyboardKey.home => 0,
      LogicalKeyboardKey.end => last,
      _ => null,
    };
    if (target == null) return KeyEventResult.ignored;
    _nodes[target].requestFocus();
    widget.onSelect(widget.tabs[target].value);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 14 : 18),
      child: SizedBox(
        height: compact ? 38 : 46,
        // The tab bar sits inside the scroll view: the scrollable's own
        // semantics node may not come between a tab bar and its tabs.
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (n) => _onMetrics(n.metrics),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) => _onMetrics(n.metrics),
            child: ShaderMask(
              key: const ValueKey('pill-tabs-fade'),
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => _fade(bounds.width),
              child: ScrollConfiguration(
                // Desktop: Flutter drags only touch by default, so a mouse
                // could never reach a pill past the edge.
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: PointerDeviceKind.values.toSet(),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Semantics(
                    role: SemanticsRole.tabBar,
                    container: true,
                    explicitChildNodes: true,
                    child: Row(
                      children: [
                        for (var i = 0; i < widget.tabs.length; i++) ...[
                          if (i > 0) SizedBox(width: compact ? 8 : 10),
                          _pill(context, i),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Opaque in the middle, transparent at an edge with pills past it.
  Shader _fade(double width) {
    final f = width <= 0 ? 0.0 : (fadeWidth / width).clamp(0.0, 0.5);
    return LinearGradient(
      colors: [
        _moreBefore ? Colors.transparent : Colors.black,
        Colors.black,
        Colors.black,
        _moreAfter ? Colors.transparent : Colors.black,
      ],
      stops: [0, f, 1 - f, 1],
    ).createShader(Rect.fromLTWH(0, 0, width, 1));
  }

  /// For tests: which edges fade now.
  @visibleForTesting
  ({bool before, bool after}) get fading =>
      (before: _moreBefore, after: _moreAfter);

  Widget _pill(BuildContext context, int i) {
    final p = VillagePalette.of(context);
    final t = context.s;
    final compact = widget.compact;
    final tab = widget.tabs[i];
    final active = tab.value == widget.selected;
    return Semantics(
      key: _keys[i],
      role: SemanticsRole.tab,
      container: true,
      selected: active,
      label: '${tab.label}, ${t.tabPosition(i + 1, widget.tabs.length)}',
      onTap: () => widget.onSelect(tab.value),
      child: ExcludeSemantics(
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (_, e) => _onKey(i, e),
          child: Material(
            // `.subject-tab.is-active { background: #E8F0FF; border: none }`
            color: active ? p.navActiveFill : p.surface,
            shape: StadiumBorder(
              side: active ? BorderSide.none : BorderSide(color: p.line),
            ),
            child: InkWell(
              key: ValueKey('${widget.keyPrefix}-${_name(tab.value)}'),
              focusNode: _nodes[i],
              customBorder: const StadiumBorder(),
              // The active pill stays tappable: on the Carte it re-syncs a
              // stale subject.
              onTap: () => widget.onSelect(tab.value),
              mouseCursor: active
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  tab.leading == null
                      ? (compact ? 13 : 16)
                      : (compact ? 6 : 8),
                  compact ? 6 : 7,
                  compact ? 13 : 16,
                  compact ? 6 : 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tab.leading case final leading?) ...[
                      SizedBox.square(
                        dimension: PillTabs.leadingSize(compact),
                        child: leading,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontFamily: VillageType.display,
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 12 : 13,
                        color: active ? p.quebecBlueBright : p.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The panel under a [PillTabs]: announced as a tab panel, and swapped in
/// with a short fade — or instantly when motion is reduced.
class PillTabPanel extends StatelessWidget {
  const PillTabPanel({required this.tabKey, required this.child, super.key});

  /// Changes with the selected tab, so the swap is recognised.
  final Object tabKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      role: SemanticsRole.tabPanel,
      container: true,
      explicitChildNodes: true,
      child: AnimatedSwitcher(
        duration: still ? Duration.zero : Motion.quick,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        child: KeyedSubtree(key: ValueKey(tabKey), child: child),
      ),
    );
  }
}
