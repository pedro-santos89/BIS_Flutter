import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers.dart';
import '../theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = context.watch<ThemeProvider>().isDark;

    return Scaffold(
      appBar: _buildAppBar(context, isDark),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Text(
                'Welcome to bis',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontFamily: AppTheme.headlineFont,
                  fontSize: 144,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w100,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '(BUS Information System)',
                style: GoogleFonts.oswald(
                  textStyle: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Manage members and registrations.',
                style: GoogleFonts.oswald(
                  textStyle: theme.textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 320,
                child: _CtaButton(
                  label: 'Member Registration',
                  isDark: isDark,
                  onPressed: () =>
                      Navigator.pushNamed(context, '/register'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 320,
                child: _CtaButton(
                  label: 'Daily Member Registration',
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

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    final themeProvider = context.read<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final primary = Theme.of(context).colorScheme.primary;
    final hover = AppTheme.hoverColor(isDark);

    return AppBar(
      title: _HoverText(
        text: 'bIS',
        normalColor: primary,
        hoverColor: hover,
        style: const TextStyle(fontFamily: 'Rowsky', fontSize: 20),
        onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false),
      ),
      actions: [
        IconButton(
          icon: Icon(isDark ? Icons.wb_sunny : Icons.nightlight_round),
          tooltip: isDark ? 'Switch to Light' : 'Switch to Dark',
          onPressed: () => themeProvider.toggleTheme(),
        ),
        if (authProvider.isAuthenticated) ...[
          _NavLinkButton(
            text: 'Admin area',
            isDark: isDark,
            onPressed: () => Navigator.pushNamed(context, '/admin'),
          ),
          _NavLinkButton(
            text: 'Logout',
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
            text: 'Admin area',
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
            textStyle: GoogleFonts.oswald(fontSize: 16, fontWeight: FontWeight.w600),
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
