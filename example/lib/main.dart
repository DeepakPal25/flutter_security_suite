import 'package:flutter/material.dart';
import 'package:flutter_security_suite/flutter_security_suite.dart';

void main() => runApp(const SecureBankKitDemo());

class SecureBankKitDemo extends StatelessWidget {
  const SecureBankKitDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_security_suite Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final SecureBankKit _kit;
  SecurityStatus? _lastStatus;
  final List<_LogEntry> _log = [];
  bool _screenshotProtectionEnabled = false;

  @override
  void initState() {
    super.initState();
    _kit = SecureBankKit.initialize(
      enableRootDetection: true,
      enableAppIntegrity: true,
      enableEmulatorDetection: true,
      enableScreenRecordingDetection: true,
      enableTamperDetection: true,
      enableRuntimeProtection: true,
      enableLogging: true,
    );
  }

  void _addLog(String message, {bool isError = false}) {
    setState(() => _log.insert(0, _LogEntry(message, isError: isError)));
  }

  // ── Security Check ─────────────────────────────────────────────────────────

  Future<void> _runSecurityCheck() async {
    _addLog('▶ Running full security check…');
    final status = await _kit.runSecurityCheck();
    setState(() => _lastStatus = status);

    _addLog('  isSecure:              ${_icon(status.isSecure, invert: false)}  ${status.isSecure}');
    _addLog('  isRooted:              ${_icon(!status.isRooted)}  ${status.isRooted}');
    _addLog('  isEmulator:            ${_icon(!status.isEmulator)}  ${status.isEmulator}');
    _addLog('  isScreenBeingRecorded: ${_icon(!status.isScreenBeingRecorded)}  ${status.isScreenBeingRecorded}');
    _addLog('  isTampered:            ${_icon(!status.isTampered)}  ${status.isTampered}');
    _addLog('  isRuntimeHooked:       ${_icon(!status.isRuntimeHooked)}  ${status.isRuntimeHooked}');
    _addLog('  appIntegrityValid:     ${_icon(status.isAppIntegrityValid)}  ${status.isAppIntegrityValid}');
    _addLog('  certPinningValid:      ${_icon(status.isCertificatePinningValid)}  ${status.isCertificatePinningValid}');
    _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  String _icon(bool good, {bool invert = true}) => good ? '✓' : '✗';

  // ── Screenshot Protection ──────────────────────────────────────────────────

  Future<void> _toggleScreenshotProtection() async {
    final enable = !_screenshotProtectionEnabled;
    final result = enable
        ? await _kit.screenshotProtection.enable()
        : await _kit.screenshotProtection.disable();

    result.fold(
      onSuccess: (_) {
        setState(() => _screenshotProtectionEnabled = enable);
        _addLog('Screenshot protection ${enable ? "enabled" : "disabled"}');
      },
      onFailure: (e) =>
          _addLog('Screenshot protection error: ${e.message}', isError: true),
    );
  }

  // ── Tamper: signature hash ─────────────────────────────────────────────────

  Future<void> _getSignatureHash() async {
    _addLog('▶ Retrieving signing certificate hash…');
    final result = await _kit.tamperDetection.getSignatureHash();
    result.fold(
      onSuccess: (hash) => _addLog('  SHA-256: ${hash ?? "(null)"}'),
      onFailure: (e) => _addLog('  Error: ${e.message}', isError: true),
    );
  }

  // ── Secure Storage ─────────────────────────────────────────────────────────

  Future<void> _testSecureStorage() async {
    _addLog('▶ Testing secure storage…');

    final writeResult = await _kit.secureStorage.write(
      key: 'demo_token',
      value: 'jwt_abc123',
    );
    writeResult.fold(
      onSuccess: (_) => _addLog('  Write: OK'),
      onFailure: (e) => _addLog('  Write error: ${e.message}', isError: true),
    );

    final readResult = await _kit.secureStorage.read(key: 'demo_token');
    readResult.fold(
      onSuccess: (v) => _addLog('  Read:  $v'),
      onFailure: (e) => _addLog('  Read error: ${e.message}', isError: true),
    );

    final deleteResult = await _kit.secureStorage.delete(key: 'demo_token');
    deleteResult.fold(
      onSuccess: (_) => _addLog('  Delete: OK'),
      onFailure: (e) =>
          _addLog('  Delete error: ${e.message}', isError: true),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final status = _lastStatus;
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_security_suite'),
        actions: [
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                label: Text(
                  status.isSecure ? 'SECURE' : 'THREAT DETECTED',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                backgroundColor:
                    status.isSecure ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Status cards ──────────────────────────────────────────────────
          if (status != null) _StatusGrid(status: status),

          // ── Action buttons ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _runSecurityCheck,
                  icon: const Icon(Icons.security),
                  label: const Text('Full Security Check'),
                ),
                FilledButton.tonal(
                  onPressed: _toggleScreenshotProtection,
                  child: Text(
                    _screenshotProtectionEnabled
                        ? 'Disable Screenshot Protection'
                        : 'Enable Screenshot Protection',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _getSignatureHash,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Get Signature Hash'),
                ),
                OutlinedButton.icon(
                  onPressed: _testSecureStorage,
                  icon: const Icon(Icons.lock),
                  label: const Text('Test Secure Storage'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Log output ────────────────────────────────────────────────────
          Expanded(
            child: _log.isEmpty
                ? const Center(
                    child: Text(
                      'Tap "Full Security Check" to begin',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _log.length,
                    itemBuilder: (context, index) {
                      final entry = _log[index];
                      return Text(
                        entry.message,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: entry.isError ? Colors.red : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Status grid widget ────────────────────────────────────────────────────────

class _StatusGrid extends StatelessWidget {
  final SecurityStatus status;

  const _StatusGrid({required this.status});

  @override
  Widget build(BuildContext context) {
    final checks = [
      _Check('Rooted',        !status.isRooted,             Icons.phone_android),
      _Check('Emulator',      !status.isEmulator,           Icons.computer),
      _Check('Recording',     !status.isScreenBeingRecorded, Icons.videocam_off),
      _Check('Tampered',      !status.isTampered,           Icons.verified_user),
      _Check('Runtime Hook',  !status.isRuntimeHooked,      Icons.code_off),
      _Check('App Integrity', status.isAppIntegrityValid,   Icons.check_circle),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: checks.map((c) => _CheckChip(check: c)).toList(),
      ),
    );
  }
}

class _Check {
  final String label;
  final bool passed;
  final IconData icon;

  const _Check(this.label, this.passed, this.icon);
}

class _CheckChip extends StatelessWidget {
  final _Check check;

  const _CheckChip({required this.check});

  @override
  Widget build(BuildContext context) {
    final color = check.passed ? Colors.green.shade700 : Colors.red.shade700;
    return Chip(
      avatar: Icon(check.icon, size: 16, color: color),
      label: Text(
        check.label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
      side: BorderSide(color: color),
      backgroundColor: color.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

// ── Log entry model ───────────────────────────────────────────────────────────

class _LogEntry {
  final String message;
  final bool isError;

  const _LogEntry(this.message, {this.isError = false});
}
