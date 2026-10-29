import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// A page's scrolling column, centred in the area the shell leaves the page
/// (to the right of the sidebar or rail, under the header) at every width.
///
/// Every page with a max-width column uses this or [PageColumn.insets], so
/// they can't drift apart (Hafid, 2026-10-29: "WHY PUSH IT TO THE LEFT").
/// Centring is done with symmetric side padding computed from the page's
/// own width, never from the window's, which is what a sidebar would skew.
class PageColumn extends StatelessWidget {
  PageColumn({
    required Widget child,
    this.maxWidth = PageWidth.column,
    this.wideMaxWidth = PageWidth.columnWide,
    this.scrollKey,
    super.key,
  }) : builder = ((_, _) => child);

  /// For a page whose layout depends on [compact].
  const PageColumn.builder({
    required this.builder,
    this.maxWidth = PageWidth.column,
    this.wideMaxWidth = PageWidth.columnWide,
    this.scrollKey,
    super.key,
  });

  final Widget Function(BuildContext context, bool compact) builder;
  final double maxWidth;

  /// From [PageWidth.wideFrom] page width.
  final double wideMaxWidth;

  /// The scroll view's key, for a page that keeps its scroll position.
  final Key? scrollKey;

  /// Below this page width: phone padding and layouts.
  static bool isCompact(double width) => width < Breakpoints.compact;

  /// The padding that centres a column of [maxWidth] in a page [width]
  /// wide: at least the page gutter on each side, equal on both.
  static EdgeInsets insets(
    double width, {
    double maxWidth = PageWidth.column,
    double wideMaxWidth = PageWidth.columnWide,
  }) {
    final pad = isCompact(width) ? Space.md : Space.lg;
    final column = width >= PageWidth.wideFrom ? wideMaxWidth : maxWidth;
    final side = ((width - column) / 2).clamp(pad, double.infinity);
    return EdgeInsets.symmetric(horizontal: side, vertical: pad);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SingleChildScrollView(
          key: scrollKey,
          padding: insets(
            width,
            maxWidth: maxWidth,
            wideMaxWidth: wideMaxWidth,
          ),
          child: builder(context, isCompact(width)),
        );
      },
    );
  }
}
