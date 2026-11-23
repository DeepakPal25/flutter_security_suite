/// Snapshot of the running build's compile-time hardening.
///
/// This describes how the app *binary* was produced — whether it is a
/// release build and whether the Dart symbols appear to have been obfuscated
/// with `flutter build --obfuscate --split-debug-info=<dir>`. It says nothing
/// about runtime state; use it to refuse sensitive flows in builds that were
/// not hardened (for example a debug build shipped by mistake).
class ObfuscationStatus {
  /// `true` for a `--release` build (`kReleaseMode`).
  final bool isReleaseBuild;

  /// `true` for a `--debug` build (`kDebugMode`).
  final bool isDebugBuild;

  /// `true` for a `--profile` build (`kProfileMode`).
  final bool isProfileBuild;

  /// Best-effort heuristic: `true` when the Dart symbols look obfuscated,
  /// i.e. an internal class name no longer matches its source name, which is
  /// what `flutter build --obfuscate` produces.
  ///
  /// This is a heuristic, not a guarantee — treat it as a strong hint, not
  /// proof. It is only meaningful in a release build.
  final bool symbolsLikelyStripped;

  const ObfuscationStatus({
    required this.isReleaseBuild,
    required this.isDebugBuild,
    required this.isProfileBuild,
    required this.symbolsLikelyStripped,
  });

  /// `true` when the build is a release build with obfuscated symbols — the
  /// configuration you want for a production app.
  bool get isHardened => isReleaseBuild && symbolsLikelyStripped;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObfuscationStatus &&
          other.isReleaseBuild == isReleaseBuild &&
          other.isDebugBuild == isDebugBuild &&
          other.isProfileBuild == isProfileBuild &&
          other.symbolsLikelyStripped == symbolsLikelyStripped;

  @override
  int get hashCode => Object.hash(
    isReleaseBuild,
    isDebugBuild,
    isProfileBuild,
    symbolsLikelyStripped,
  );

  @override
  String toString() =>
      'ObfuscationStatus(isReleaseBuild: $isReleaseBuild, '
      'isDebugBuild: $isDebugBuild, isProfileBuild: $isProfileBuild, '
      'symbolsLikelyStripped: $symbolsLikelyStripped, '
      'isHardened: $isHardened)';
}
