/// Result of the anti-tamper checks (debugger + injected libraries).
class AntiTamperStatus {
  /// `true` when a debugger / tracer is attached to the process.
  final bool isDebuggerAttached;

  /// `true` when suspicious dynamic libraries (Frida, Substrate, …) are
  /// loaded into the process, or a library-injection environment variable
  /// (`DYLD_INSERT_LIBRARIES` / `LD_PRELOAD`) is set.
  final bool hasInjectedLibraries;

  const AntiTamperStatus({
    required this.isDebuggerAttached,
    required this.hasInjectedLibraries,
  });

  /// `true` when any anti-tamper check tripped.
  bool get isCompromised => isDebuggerAttached || hasInjectedLibraries;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AntiTamperStatus &&
          other.isDebuggerAttached == isDebuggerAttached &&
          other.hasInjectedLibraries == hasInjectedLibraries;

  @override
  int get hashCode => Object.hash(isDebuggerAttached, hasInjectedLibraries);

  @override
  String toString() =>
      'AntiTamperStatus(isDebuggerAttached: $isDebuggerAttached, '
      'hasInjectedLibraries: $hasInjectedLibraries)';
}
