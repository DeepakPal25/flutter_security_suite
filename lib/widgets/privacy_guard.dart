import 'package:flutter/widgets.dart';

/// Draws [cover] over [child] whenever the app leaves the foreground, so
/// sensitive content is hidden in the **iOS app switcher** snapshot (and the
/// Android recents preview).
///
/// iOS takes the app-switcher thumbnail the moment the app becomes
/// *inactive* — before it is fully backgrounded — so neither `FLAG_SECURE`
/// (Android-only) nor the iOS secure-overlay screenshot block covers it. This
/// widget reacts to the lifecycle change and overlays an opaque cover in time
/// for that snapshot, then removes it on resume.
///
/// Wrap it **below** your `MaterialApp` so the cover inherits a
/// [Directionality] / theme, typically via `MaterialApp.builder`:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => PrivacyGuard(child: child!),
///   home: const HomePage(),
/// );
/// ```
///
/// Provide your own [cover] (e.g. a branded splash) for a polished switcher
/// preview; the default is an opaque panel with a lock glyph.
class PrivacyGuard extends StatefulWidget {
  /// The protected UI.
  final Widget child;

  /// What is shown in place of [child] while the app is not in the foreground.
  final Widget cover;

  /// Whether to cover on [AppLifecycleState.inactive] (the state iOS enters
  /// right before taking the switcher snapshot). Keep `true` for iOS switcher
  /// protection; set `false` to cover only once fully backgrounded.
  final bool coverWhenInactive;

  const PrivacyGuard({
    super.key,
    required this.child,
    this.cover = const PrivacyCover(),
    this.coverWhenInactive = true,
  });

  @override
  State<PrivacyGuard> createState() => _PrivacyGuardState();
}

class _PrivacyGuardState extends State<PrivacyGuard>
    with WidgetsBindingObserver {
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final obscure = switch (state) {
      AppLifecycleState.resumed => false,
      AppLifecycleState.inactive => widget.coverWhenInactive,
      AppLifecycleState.hidden => true,
      AppLifecycleState.paused => true,
      AppLifecycleState.detached => true,
    };
    if (obscure != _obscured && mounted) {
      setState(() => _obscured = obscure);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_obscured) Positioned.fill(child: widget.cover),
      ],
    );
  }
}

/// Default [PrivacyGuard.cover]: an opaque panel with a centered lock glyph.
///
/// Deliberately depends on nothing from the Material/Cupertino themes so it
/// renders correctly even when placed above the app's theme.
class PrivacyCover extends StatelessWidget {
  /// Background fill of the cover.
  final Color color;

  /// Tint of the lock glyph.
  final Color glyphColor;

  const PrivacyCover({
    super.key,
    this.color = const Color(0xFF0D1B2A),
    this.glyphColor = const Color(0x99FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Center(
        child: Icon(
          // Material "lock" codepoint, drawn without requiring a Theme.
          const IconData(0xe897, fontFamily: 'MaterialIcons'),
          size: 56,
          color: glyphColor,
          textDirection: TextDirection.ltr,
        ),
      ),
    );
  }
}
