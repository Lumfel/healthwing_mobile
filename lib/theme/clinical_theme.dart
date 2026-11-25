import 'package:material_ui/material_ui.dart';

import '../config/api_config.dart';

/// Clean clinical palette and responsive `408 x 900` layout primitives.
class ClinicalPalette {
  const ClinicalPalette._();

  static const double designWidth = 408.0;
  static const double designHeight = 900.0;

  static const Color primaryTeal = Color(0xFF0D5C63);
  static const Color deepSlate = Color(0xFF102A43);
  static const Color secondaryBlue = Color(0xFF1F4E79);
  static const Color background = Color(0xFFF4F7F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color mutedSurface = Color(0xFFEAF1F5);
  static const Color border = Color(0xFFD5E0E7);
  static const Color textPrimary = Color(0xFF102A43);
  static const Color textSecondary = Color(0xFF486581);

  static const Color emergencyRed = Color(0xFFB42318);
  static const Color emergencyBg = Color(0xFFFEF3F2);
  static const Color emergencyBorder = Color(0xFFFECDCA);

  static const Color successGreen = Color(0xFF067647);
  static const Color successBg = Color(0xFFECFDF3);
  static const Color successBorder = Color(0xFFABEFC6);

  static const Color warningAmber = Color(0xFFB54708);
  static const Color warningBg = Color(0xFFFFFAEB);
  static const Color warningBorder = Color(0xFFFEDF89);
}

/// Builds the global Material 3 clinical theme for HealthWing.
ThemeData buildClinicalTheme() {
  const colorScheme = ColorScheme.light(
    primary: ClinicalPalette.primaryTeal,
    onPrimary: Colors.white,
    secondary: ClinicalPalette.secondaryBlue,
    onSecondary: Colors.white,
    error: ClinicalPalette.emergencyRed,
    onError: Colors.white,
    surface: ClinicalPalette.surface,
    onSurface: ClinicalPalette.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: ClinicalPalette.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: ClinicalPalette.surface,
      foregroundColor: ClinicalPalette.deepSlate,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: ClinicalPalette.deepSlate,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: ClinicalPalette.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ClinicalPalette.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ClinicalPalette.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ClinicalPalette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ClinicalPalette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: ClinicalPalette.primaryTeal,
          width: 1.6,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ClinicalPalette.emergencyRed),
      ),
      labelStyle: const TextStyle(
        color: ClinicalPalette.textSecondary,
        fontSize: 13.5,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ClinicalPalette.primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(46),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ClinicalPalette.primaryTeal,
        minimumSize: const Size.fromHeight(44),
        side: const BorderSide(color: ClinicalPalette.primaryTeal),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

/// Responsive container tuned to `408 x 900` mobile clinical proportions.
class ResponsiveClinicalBody extends StatelessWidget {
  const ResponsiveClinicalBody({
    super.key,
    required this.child,
    this.scrollable = true,
    this.padding,
  });

  final Widget child;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : ClinicalPalette.designWidth;
        final scale = (width / ClinicalPalette.designWidth).clamp(0.85, 1.12);
        final horizontalPad = (16.0 * scale).clamp(12.0, 22.0);
        final verticalPad = (16.0 * scale).clamp(12.0, 22.0);

        final resolvedPadding = padding ??
            EdgeInsets.symmetric(
              horizontal: horizontalPad,
              vertical: verticalPad,
            );

        final constrained = Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: resolvedPadding,
              child: child,
            ),
          ),
        );

        if (!scrollable) {
          return SafeArea(child: constrained);
        }

        return SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: constrained,
          ),
        );
      },
    );
  }
}

/// Standard loading indicator enforcing the `Loading...` label rule.
class ClinicalLoadingView extends StatelessWidget {
  const ClinicalLoadingView({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ClinicalPalette.primaryTeal,
            ),
          ),
          SizedBox(width: 10),
          Text(
            ApiConfig.loadingLabel,
            style: TextStyle(
              color: ClinicalPalette.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: ClinicalPalette.primaryTeal,
              ),
            ),
            SizedBox(height: 12),
            Text(
              ApiConfig.loadingLabel,
              style: TextStyle(
                color: ClinicalPalette.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum BannerTone { info, success, warning, danger }

/// Inline clinical status/error banner with crisp border and icon.
class ClinicalBanner extends StatelessWidget {
  const ClinicalBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = BannerTone.info,
    this.onDismiss,
  });

  final String message;
  final String? title;
  final BannerTone tone;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg, icon) = switch (tone) {
      BannerTone.danger => (
        ClinicalPalette.emergencyBg,
        ClinicalPalette.emergencyBorder,
        ClinicalPalette.emergencyRed,
        Icons.error_outline,
      ),
      BannerTone.success => (
        ClinicalPalette.successBg,
        ClinicalPalette.successBorder,
        ClinicalPalette.successGreen,
        Icons.check_circle_outline,
      ),
      BannerTone.warning => (
        ClinicalPalette.warningBg,
        ClinicalPalette.warningBorder,
        ClinicalPalette.warningAmber,
        Icons.warning_amber_rounded,
      ),
      BannerTone.info => (
        ClinicalPalette.mutedSurface,
        ClinicalPalette.border,
        ClinicalPalette.secondaryBlue,
        Icons.info_outline,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title!.trim().isNotEmpty) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: Icon(Icons.close, size: 16, color: fg),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

/// Compact pill badge for role, status, and severity labels.
class ClinicalBadge extends StatelessWidget {
  const ClinicalBadge({
    super.key,
    required this.label,
    this.backgroundColor = ClinicalPalette.mutedSurface,
    this.foregroundColor = ClinicalPalette.secondaryBlue,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Section header with optional trailing action button.
class ClinicalSectionHeader extends StatelessWidget {
  const ClinicalSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: ClinicalPalette.deepSlate,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
