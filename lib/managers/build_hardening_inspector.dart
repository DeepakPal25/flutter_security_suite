import 'package:flutter/foundation.dart';

import '../domain/entities/obfuscation_status.dart';

/// Internal probe whose source name is known at compile time. Under
/// `flutter build --obfuscate`, Dart renames it, so its runtime name no
/// longer matches — which is how [BuildHardeningInspector] detects
/// obfuscation.
class _ObfuscationProbe {
  const _ObfuscationProbe();
}

/// Reports how the running build was compiled: release/debug/profile and
/// whether Dart symbols look obfuscated. Pure Dart, no platform channel.
class BuildHardeningInspector {
  /// Overrides for the compile-time flags; used by tests. In production the
  /// real `kReleaseMode` / `kDebugMode` / `kProfileMode` values are used.
  final bool? debugIsRelease;
  final bool? debugIsDebug;
  final bool? debugIsProfile;
  final bool? debugSymbolsStripped;

  const BuildHardeningInspector({
    this.debugIsRelease,
    this.debugIsDebug,
    this.debugIsProfile,
    this.debugSymbolsStripped,
  });

  /// `true` when this library's own symbols appear to have been renamed by
  /// `--obfuscate`. Best-effort heuristic.
  bool get symbolsLikelyStripped =>
      debugSymbolsStripped ??
      const _ObfuscationProbe().runtimeType.toString() != '_ObfuscationProbe';

  /// The current [ObfuscationStatus].
  ObfuscationStatus inspect() => ObfuscationStatus(
    isReleaseBuild: debugIsRelease ?? kReleaseMode,
    isDebugBuild: debugIsDebug ?? kDebugMode,
    isProfileBuild: debugIsProfile ?? kProfileMode,
    symbolsLikelyStripped: symbolsLikelyStripped,
  );
}
