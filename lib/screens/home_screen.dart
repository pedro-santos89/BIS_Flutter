import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers.dart';
import '../theme.dart';
import '../l10n.dart';

/// Public landing page of the BIS app.
///
/// Shows the welcome title, subtitle, description, and two CTA buttons
/// for member registration and daily member registration.
/// The [AppBar] includes theme/locale toggles, text-size menu, and
/// conditional admin/login navigation links.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = context.watch<ThemeProvider>().isDark;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: _buildAppBar(context, isDark),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                child: Text(
                  l.tr('welcomeTitle'),
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontFamily: AppTheme.headlineFont,
                    fontSize: 144,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w100,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.tr('welcomeSubtitle'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 14,
                  fontFamily: 'Oswald',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.tr('welcomeDescription'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: 'Oswald',
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 320,
                child: _CtaButton(
                  label: l.tr('memberRegistration'),
                  isDark: isDark,
                  onPressed: () =>
                      Navigator.pushNamed(context, '/register'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 320,
                child: _CtaButton(
                  label: l.tr('dailyMemberRegistration'),
                  isDark: isDark,
                  onPressed: () =>
                      Navigator.pushNamed(context, '/register-daily'),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the top app bar with the "bIS" logo, theme/locale toggles,
  /// text-size menu, and auth-aware navigation links (admin area / logout).
  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    final themeProvider = context.read<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final primary = Theme.of(context).colorScheme.primary;
    final hover = AppTheme.hoverColor(isDark);
    final l = AppLocalizations.of(context);

    return AppBar(
      title: _HoverText(
        text: 'bIS',
        normalColor: primary,
        hoverColor: hover,
        style: const TextStyle(fontFamily: 'Rowsky', fontSize: 20),
        onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false),
      ),
      actions: [
        _TextSizeMenuButton(primary: primary),
        IconButton(
          icon: Icon(isDark ? Icons.wb_sunny : Icons.nightlight_round),
          tooltip: isDark ? l.tr('switchToLight') : l.tr('switchToDark'),
          onPressed: () => themeProvider.toggleTheme(),
        ),
        IconButton(
          icon: Text(
            themeProvider.locale.languageCode.toUpperCase(),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primary),
          ),
          tooltip: themeProvider.locale.languageCode == 'pt' ? 'English' : 'Português',
          onPressed: () => themeProvider.toggleLocale(),
        ),
        if (authProvider.isAuthenticated) ...[
          _NavLinkButton(
            text: l.tr('adminArea'),
            isDark: isDark,
            onPressed: () => Navigator.pushNamed(context, '/admin'),
          ),
          _NavLinkButton(
            text: l.tr('logout'),
            isDark: isDark,
            onPressed: () {
              authProvider.logout();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                (route) => false,
              );
            },
          ),
        ] else
          _NavLinkButton(
            text: l.tr('adminArea'),
            isDark: isDark,
            onPressed: () => Navigator.pushNamed(context, '/login'),
          ),
      ],
    );
  }
}

/// Nav link that changes color on hover (matching webapp nav-link behavior).
class _NavLinkButton extends StatelessWidget {
  final String text;
  final bool isDark;
  final VoidCallback onPressed;

  const _NavLinkButton({required this.text, required this.isDark, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hover = AppTheme.hoverColor(isDark);

    return TextButton(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed)) {
            return hover;
          }
          return primary;
        }),
        overlayColor: WidgetStateProperty.all(hover.withValues(alpha: 0.1)),
        animationDuration: const Duration(milliseconds: 300),
      ),
      onPressed: onPressed,
      child: Text(text),
    );
  }
}

/// CTA button matching webapp: bg darkens on hover + slight lift.
class _CtaButton extends StatefulWidget {
  final String label;
  final bool isDark;
  final VoidCallback onPressed;

  const _CtaButton({required this.label, required this.isDark, required this.onPressed});

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton> {
  /// Tracks mouse hover to drive animated lift and color change.
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hoverBg = AppTheme.hoverColor(widget.isDark);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, _hovering ? -3 : 0, 0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _hovering ? hoverBg : primary,
            foregroundColor: _hovering ? (widget.isDark ? Colors.black : Colors.white) : (widget.isDark ? Colors.black : AppTheme.lightBgLight),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontFamily: 'Oswald', fontSize: 16, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: _hovering ? 8 : 2,
          ),
          onPressed: widget.onPressed,
          child: Text(widget.label),
        ),
      ),
    );
  }
}

/// Text-size dropdown button using MenuAnchor – stays open after each tap.
class _TextSizeMenuButton extends StatefulWidget {
  final Color primary;
  const _TextSizeMenuButton({required this.primary});

  @override
  State<_TextSizeMenuButton> createState() => _TextSizeMenuButtonState();
}

class _TextSizeMenuButtonState extends State<_TextSizeMenuButton> {
  /// Controller that keeps the dropdown open after each tap via
  /// [addPostFrameCallback] re-open trick.
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final scale = tp.textScale;
    final primary = widget.primary;

    return MenuAnchor(
      controller: _menuController,
      menuChildren: [
        MenuItemButton(
          onPressed: scale < 2.0
              ? () {
                  tp.increaseTextScale();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _menuController.open();
                  });
                }
              : null,
          leadingIcon: const Icon(Icons.text_increase, size: 20),
          child: Text(AppLocalizations.of(context).tr('textSizeIncrease')),
        ),
        MenuItemButton(
          onPressed: () {
            tp.resetTextScale();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _menuController.open();
            });
          },
          leadingIcon: const Icon(Icons.refresh, size: 20),
          child: Text(AppLocalizations.of(context).trArgs('textSizeReset', {'percent': '${tp.textScalePercent}'})),
        ),
        MenuItemButton(
          onPressed: scale > 1.0
              ? () {
                  tp.decreaseTextScale();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _menuController.open();
                  });
                }
              : null,
          leadingIcon: const Icon(Icons.text_decrease, size: 20),
          child: Text(AppLocalizations.of(context).tr('textSizeDecrease')),
        ),
      ],
      child: InkWell(
        onTap: () {
          if (_menuController.isOpen) {
            _menuController.close();
          } else {
            _menuController.open();
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('a', style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.bold)),
              Text('A', style: TextStyle(fontSize: 18, color: primary, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text widget that smoothly transitions color on hover.
class _HoverText extends StatefulWidget {
  final String text;
  final Color normalColor;
  final Color hoverColor;
  final TextStyle? style;
  final VoidCallback? onTap;

  const _HoverText({
    required this.text,
    required this.normalColor,
    required this.hoverColor,
    this.style,
    this.onTap,
  });

  @override
  State<_HoverText> createState() => _HoverTextState();
}

class _HoverTextState extends State<_HoverText> {
  /// Tracks mouse enter/exit to animate text color via [AnimatedDefaultTextStyle].
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: (widget.style ?? const TextStyle()).copyWith(
            color: _hovering ? widget.hoverColor : widget.normalColor,
          ),
          child: Text(widget.text),
        ),
      ),
    );
  }
}
