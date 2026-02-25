import 'package:flutter/material.dart';
import 'package:flutter_security_suite/flutter_security_suite.dart';

void main() => runApp(const SecureBankKitDemo());

class SecureBankKitDemo extends StatelessWidget {
  const SecureBankKitDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecureBankKit Demo',
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
  final List<String> _log = [];
  bool _screenshotProtectionEnabled = false;

  @override
  void initState() {
    super.initState();
    _kit = SecureBankKit.initialize(
      enableRootDetection: true,
      enableAppIntegrity: true,
      enableLogging: true,
    );
  }

  void _addLog(String message) {
    setState(() => _log.insert(0, message));
  }

  Future<void> _runSecurityCheck() async {
    _addLog('Running security check...');
    final status = await _kit.runSecurityCheck();
    _addLog('Security check result:');
    _addLog('  isSecure: ${status.isSecure}');
    _addLog('  isRooted: ${status.isRooted}');
    _addLog('  appIntegrity: ${status.isAppIntegrityValid}');
    _addLog('  certPinning: ${status.isCertificatePinningValid}');
  }

  Future<void> _toggleScreenshotProtection() async {
    final enable = !_screenshotProtectionEnabled;
    final result = enable
        ? await _kit.screenshotProtection.enable()
        : await _kit.screenshotProtection.disable();

    result.fold(
      onSuccess: (_) {
        setState(() => _screenshotProtectionEnabled = enable);
        _addLog(
            'Screenshot protection ${enable ? "enabled" : "disabled"}');
      },
      onFailure: (e) => _addLog('Screenshot protection error: ${e.message}'),
    );
  }

  Future<void> _testSecureStorage() async {
    _addLog('Writing to secure storage...');
    final writeResult =
        await _kit.secureStorage.write(key: 'demo_token', value: 'jwt_abc123');
    writeResult.fold(
      onSuccess: (_) => _addLog('  Write: OK'),
      onFailure: (e) => _addLog('  Write error: ${e.message}'),
    );

    _addLog('Reading from secure storage...');
    final readResult = await _kit.secureStorage.read(key: 'demo_token');
    readResult.fold(
      onSuccess: (value) => _addLog('  Read: $value'),
      onFailure: (e) => _addLog('  Read error: ${e.message}'),
    );

    _addLog('Deleting from secure storage...');
    final deleteResult = await _kit.secureStorage.delete(key: 'demo_token');
    deleteResult.fold(
      onSuccess: (_) => _addLog('  Delete: OK'),
      onFailure: (e) => _addLog('  Delete error: ${e.message}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SecureBankKit Demo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _runSecurityCheck,
                  child: const Text('Security Check'),
                ),
                FilledButton.tonal(
                  onPressed: _toggleScreenshotProtection,
                  child: Text(_screenshotProtectionEnabled
                      ? 'Disable Screenshot Protection'
                      : 'Enable Screenshot Protection'),
                ),
                OutlinedButton(
                  onPressed: _testSecureStorage,
                  child: const Text('Test Secure Storage'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _log.length,
              itemBuilder: (context, index) => Text(
                _log[index],
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
