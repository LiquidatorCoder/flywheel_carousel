import 'package:flutter/material.dart';

/// Opinionated card layout for [FlywheelCarousel]. Stacks a leading widget
/// (typically an avatar or icon), a title, an optional subtitle, and a small
/// indicator pill that flips color when [selected] is true.
///
/// Bring your own colors and text styles via the optional parameters; sensible
/// defaults come from [Theme.of].
class FlywheelItemCard extends StatelessWidget {
  const FlywheelItemCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.selected = false,
    this.activeIndicatorColor,
    this.inactiveIndicatorColor,
    this.titleStyle,
    this.subtitleStyle,
    this.spacing = 10,
    this.indicatorSpacing = 20,
    this.indicatorWidth = 4,
    this.indicatorHeight = 12,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final bool selected;
  final Color? activeIndicatorColor;
  final Color? inactiveIndicatorColor;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final double spacing;
  final double indicatorSpacing;
  final double indicatorWidth;
  final double indicatorHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = activeIndicatorColor ?? theme.colorScheme.primary;
    final inactiveColor = inactiveIndicatorColor ?? theme.colorScheme.outlineVariant;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        leading,
        SizedBox(height: spacing),
        Text(
          title,
          style: titleStyle ?? theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: subtitleStyle ?? theme.textTheme.labelSmall,
          ),
        ],
        SizedBox(height: indicatorSpacing),
        Container(
          width: indicatorWidth,
          height: indicatorHeight,
          decoration: BoxDecoration(
            color: selected ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(indicatorWidth / 2),
          ),
        ),
      ],
    );
  }
}
