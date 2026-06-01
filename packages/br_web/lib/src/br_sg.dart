// br_sg.dart — Wrappers locaux SG-compatibles (API-compatible avec sg_ui).
//
// **Pourquoi cette couche d'adaptation** :
//
// Le vrai package `sg_ui` (~/Code/sg-packages/packages/sg_ui/) requiert :
// 1. `flutter_riverpod` (refactor de la couche state management — non drop-in)
// 2. `resolution: workspace` (force sg-packages dans le workspace Dart de Broccers)
// 3. `sg_core` (qui dépend de `flutter: sdk: flutter` — pollue br_server pur Dart)
//
// Ces 3 contraintes empêchent une migration directe sans refactor structurel.
//
// Cette couche fournit des widgets API-compatibles (signatures identiques à sg_ui) mais
// implémentés avec Material + le skin BrocBrand. Quand sg_core sera pure-Dart et que
// l'app sera passée à Riverpod, la migration sera un simple `import` swap.
//
// MIGRATE LATER (v0.4) : remplacer `package:br_web/src/br_sg.dart` par
// `package:sg_ui/sg_ui.dart` (signatures identiques garanties).

import 'package:flutter/material.dart';

import '../main.dart' show BrocBrand;

// ============================================================================
// SgApp — App scaffold themed (équivalent SgApp de sg_ui)
// ============================================================================
class SgApp extends StatelessWidget {
  final String title;
  final Widget home;
  final ThemeData? theme;

  const SgApp({
    super.key,
    required this.title,
    required this.home,
    this.theme,
  });

  static ThemeData defaultBrocTheme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: BrocBrand.brocRed,
          brightness: Brightness.dark,
        ).copyWith(
          primary: BrocBrand.brocRed,
          secondary: BrocBrand.brocYellow,
          surface: const Color(0xff1f1818),
          surfaceContainerHighest: const Color(0xff2a1f1f),
        ),
        scaffoldBackgroundColor: BrocBrand.brocBlack,
        appBarTheme: const AppBarTheme(
          backgroundColor: BrocBrand.brocRed,
          foregroundColor: BrocBrand.brocCream,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: BrocBrand.brocYellow,
          foregroundColor: BrocBrand.brocBlack,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xff1f1818),
          indicatorColor: BrocBrand.brocRed.withValues(alpha: 0.4),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(color: BrocBrand.brocCream, fontSize: 11),
          ),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xff1f1818),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: BrocBrand.brocRed, width: 0.5),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: theme ?? defaultBrocTheme(),
      home: home,
    );
  }
}

// ============================================================================
// SgCard — Card avec skin SG (équivalent SgCard)
// ============================================================================
class SgCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final Color? accentColor;
  final VoidCallback? onTap;

  const SgCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    this.padding = const EdgeInsets.all(8),
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: const Color(0xff1f1818),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (accentColor ?? BrocBrand.brocRed).withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: card,
        ),
      );
    }
    return card;
  }
}

// ============================================================================
// SgButton — Primary action button (équivalent SgButton)
// ============================================================================
enum SgButtonStyle { primary, secondary, danger, ghost }

class SgButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final SgButtonStyle style;
  final bool busy;

  const SgButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.style = SgButtonStyle.primary,
    this.busy = false,
  });

  Color _bg() => switch (style) {
        SgButtonStyle.primary => BrocBrand.brocRed,
        SgButtonStyle.secondary => BrocBrand.brocYellow,
        SgButtonStyle.danger => Colors.red.shade700,
        SgButtonStyle.ghost => Colors.transparent,
      };

  Color _fg() => style == SgButtonStyle.secondary
      ? BrocBrand.brocBlack
      : BrocBrand.brocCream;

  @override
  Widget build(BuildContext context) {
    final disabled = busy || onPressed == null;
    return FilledButton.icon(
      onPressed: disabled ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _bg(),
        foregroundColor: _fg(),
        disabledBackgroundColor: _bg().withValues(alpha: 0.4),
        side: style == SgButtonStyle.ghost
            ? BorderSide(color: BrocBrand.brocRed.withValues(alpha: 0.5))
            : null,
      ),
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : (icon != null ? Icon(icon, size: 18) : const SizedBox.shrink()),
      label: Text(label),
    );
  }
}

// ============================================================================
// SgTextField — Champ texte styled (équivalent SgTextField)
// ============================================================================
class SgTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final bool obscureText;
  final bool autofocus;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final TextAlign textAlign;
  final TextStyle? textStyle;

  const SgTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.obscureText = false,
    this.autofocus = false,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
    this.onSubmitted,
    this.textAlign = TextAlign.start,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      autofocus: autofocus,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      textAlign: textAlign,
      style: textStyle,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: BrocBrand.brocRed, width: 1.5),
        ),
        labelStyle: const TextStyle(color: BrocBrand.brocCream),
      ),
    );
  }
}

// ============================================================================
// SgEmptyState — Affichage état vide (équivalent SgEmptyState)
// ============================================================================
class SgEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const SgEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: BrocBrand.brocCream)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SgCallout — Bandeau d'information / alerte (équivalent SgCallout)
// ============================================================================
enum SgCalloutKind { info, success, warning, error }

class SgCallout extends StatelessWidget {
  final SgCalloutKind kind;
  final String message;
  final IconData? icon;
  final Widget? action;

  const SgCallout({
    super.key,
    required this.kind,
    required this.message,
    this.icon,
    this.action,
  });

  factory SgCallout.info(String msg, {Widget? action}) =>
      SgCallout(kind: SgCalloutKind.info, message: msg, action: action);
  factory SgCallout.success(String msg, {Widget? action}) =>
      SgCallout(kind: SgCalloutKind.success, message: msg, action: action);
  factory SgCallout.warning(String msg, {Widget? action}) =>
      SgCallout(kind: SgCalloutKind.warning, message: msg, action: action);
  factory SgCallout.error(String msg, {Widget? action}) =>
      SgCallout(kind: SgCalloutKind.error, message: msg, action: action);

  Color _color() => switch (kind) {
        SgCalloutKind.info => BrocBrand.brocYellow,
        SgCalloutKind.success => Colors.greenAccent,
        SgCalloutKind.warning => Colors.orange,
        SgCalloutKind.error => Colors.redAccent,
      };

  IconData _defaultIcon() => switch (kind) {
        SgCalloutKind.info => Icons.info_outline,
        SgCalloutKind.success => Icons.check_circle,
        SgCalloutKind.warning => Icons.warning_amber,
        SgCalloutKind.error => Icons.error_outline,
      };

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        border: Border.all(color: c),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon ?? _defaultIcon(), color: c, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 13, color: BrocBrand.brocCream)),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

// ============================================================================
// SgChip / SgBadge / SgCountBadge
// ============================================================================
class SgChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  const SgChip({
    super.key,
    required this.label,
    this.color,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? BrocBrand.brocRed;
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? c : c.withValues(alpha: 0.15),
        border: Border.all(color: c),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: selected ? Colors.white : c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : c,
            ),
          ),
        ],
      ),
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: body);
    }
    return body;
  }
}

class SgBadge extends StatelessWidget {
  final String label;
  final Color color;
  const SgBadge({super.key, required this.label, this.color = BrocBrand.brocYellow});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
    );
  }
}

class SgCountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const SgCountBadge({super.key, required this.count, this.color = BrocBrand.brocRed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text('$count',
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// ============================================================================
// SgPanelHeader — Header de section
// ============================================================================
class SgPanelHeader extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? trailing;
  final Color? color;

  const SgPanelHeader({
    super.key,
    required this.label,
    this.icon,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? BrocBrand.brocYellow;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Container(width: 6, height: 16, color: c),
          const SizedBox(width: 8),
          if (icon != null) ...[
            Icon(icon, color: c, size: 16),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  color: c,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  fontSize: 12),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ============================================================================
// SgDialog — Dialog avec skin SG
// ============================================================================
class SgDialog extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final Widget content;
  final List<Widget> actions;
  final double? width;

  const SgDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon,
    this.iconColor,
    this.width,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    IconData? icon,
    Color? iconColor,
    required Widget content,
    required List<Widget> actions,
    double? width,
    bool barrierDismissible = true,
  }) =>
      showDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (_) => SgDialog(
          title: title,
          icon: icon,
          iconColor: iconColor,
          content: content,
          actions: actions,
          width: width,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor ?? BrocBrand.brocYellow),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(title)),
        ],
      ),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(child: content),
      ),
      actions: actions,
    );
  }
}

// ============================================================================
// SgToast — Notification rapide
// ============================================================================
class SgToast {
  static void show(BuildContext context, String message, {SgCalloutKind kind = SgCalloutKind.info, Duration duration = const Duration(seconds: 3)}) {
    final color = switch (kind) {
      SgCalloutKind.info => null,
      SgCalloutKind.success => Colors.green.shade800,
      SgCalloutKind.warning => Colors.orange.shade800,
      SgCalloutKind.error => Colors.red.shade900,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      duration: duration,
    ));
  }

  static void info(BuildContext c, String m) => show(c, m);
  static void success(BuildContext c, String m) => show(c, m, kind: SgCalloutKind.success);
  static void warning(BuildContext c, String m) => show(c, m, kind: SgCalloutKind.warning, duration: const Duration(seconds: 5));
  static void error(BuildContext c, String m) => show(c, m, kind: SgCalloutKind.error, duration: const Duration(seconds: 5));
}

// ============================================================================
// SgListCard — Card type list-tile avec leading/trailing
// ============================================================================
class SgListCard extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? accentColor;

  const SgListCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SgCard(
      accentColor: accentColor,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
      ),
    );
  }
}
