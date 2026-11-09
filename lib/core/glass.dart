import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

/// يُفعّل التأثير الزجاجي للعناصر داخله (الشاشات الرئيسية فوق الخلفية الملونة).
class GlassScope extends InheritedWidget {
  const GlassScope({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassScope>() != null;

  @override
  bool updateShouldNotify(GlassScope oldWidget) => false;
}

/// ارتفاع المساحة التي يشغلها شريط التبويب العائم أسفل الشاشات الرئيسية.
double tabBarSpace(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + 20;

/// خلفية ناعمة بألوان خفيفة تظهر من خلف الزجاج (مثل خلفيات iOS).
class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget blob(Color c, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)]),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: Ios.bg(context))),
        PositionedDirectional(
          top: -120,
          start: -140,
          child: blob(
            dark ? const Color(0x553A3AFF) : const Color(0x40007AFF),
            460,
          ),
        ),
        PositionedDirectional(
          top: 260,
          end: -180,
          child: blob(
            dark ? const Color(0x3330B0C7) : const Color(0x33FF9500),
            480,
          ),
        ),
        PositionedDirectional(
          bottom: -160,
          start: -80,
          child: blob(
            dark ? const Color(0x33AF52DE) : const Color(0x2E34C759),
            500,
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// لوحة زجاجية: زوايا دائرية، حد رفيع لامع، ظل خفيف، وتعتيم ضبابي لما خلفها.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final bool? glass; // null = حسب GlassScope
  final double shadow;

  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 22,
    this.padding,
    this.tint,
    this.glass,
    this.shadow = 0,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isGlass = glass ?? GlassScope.of(context);
    final br = BorderRadius.circular(radius);
    final fill =
        tint ??
        (isGlass
            ? (dark
                  ? const Color(0xFF1C1C1E).withValues(alpha: 0.62)
                  : Colors.white.withValues(alpha: 0.72))
            : Ios.cell(context));

    Widget content = Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: br,
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.09)
                : Colors.white.withValues(alpha: 0.85),
            width: 1,
          ),
          gradient: isGlass
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: dark ? 0.06 : 0.35),
                    Colors.white.withValues(alpha: 0),
                  ],
                )
              : null,
        ),
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
    if (isGlass) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: content,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: shadow <= 0
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: (dark ? 0.35 : 0.06) * shadow,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: (dark ? 0.2 : 0.03) * shadow,
                  ),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: ClipRRect(borderRadius: br, child: content),
    );
  }
}

class GlassTabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const GlassTabItem(this.icon, this.activeIcon, this.label);
}

/// شريط تبويب عائم بشكل كبسولة زجاجية، والعنصر المختار داخل كبسولة أصغر.
class GlassTabBar extends StatelessWidget {
  final List<GlassTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  const GlassTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = Ios.tint(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
        child: GlassPanel(
          radius: 34,
          glass: true,
          padding: const EdgeInsets.all(6),
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == currentIndex,
                      label: items[i].label,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            color: i == currentIndex
                                ? (dark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.black.withValues(alpha: 0.06))
                                : Colors.transparent,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                i == currentIndex
                                    ? items[i].activeIcon
                                    : items[i].icon,
                                size: 25,
                                color: i == currentIndex
                                    ? tint
                                    : Ios.label(context),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                items[i].label,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: i == currentIndex
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: i == currentIndex
                                      ? tint
                                      : Ios.label(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// بطاقة إحصائية بزجاج شفاف (أيقونة، نسبة، عنوان، قيمة كبيرة، وشريط تقدم).
class StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String value;
  final String? badge;
  final double? progress;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    this.subtitle,
    this.badge,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GlassPanel(
      radius: 24,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: dark ? 0.24 : 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const Spacer(),
                  if (badge != null)
                    Text(
                      badge!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Ios.label(context),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Ios.secondary(context)),
                ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: Ios.label(context),
                  ),
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  color: color,
                  backgroundColor: dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// شبكة من عمودين للبطاقات.
class CardGrid extends StatelessWidget {
  final List<Widget> children;
  const CardGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: 14),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(children: rows),
    );
  }
}
