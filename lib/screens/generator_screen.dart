import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../widgets/qr_view.dart';
import 'result_screen.dart';

class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Controllers
  final _urlController = TextEditingController(text: 'https://example.com');
  final _textController =
      TextEditingController(text: 'Hello from QRGuard offline scanner!');

  // Wi-Fi Controllers
  final _wifiSsidController = TextEditingController(text: 'Campus_Guest_WiFi');
  final _wifiPassController = TextEditingController(text: 'SecurePass2026');
  String _wifiSecurity = 'WPA';

  // UPI Controllers
  final _upiVpaController = TextEditingController(text: 'merchant@upi');
  final _upiNameController = TextEditingController(text: 'Student Store');
  final _upiAmountController = TextEditingController(text: '150.00');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _textController.dispose();
    _wifiSsidController.dispose();
    _wifiPassController.dispose();
    _upiVpaController.dispose();
    _upiNameController.dispose();
    _upiAmountController.dispose();
    super.dispose();
  }

  String get _currentPayload {
    switch (_tabController.index) {
      case 0:
        return _urlController.text.trim();
      case 1:
        return _textController.text.trim();
      case 2:
        final ssid = _wifiSsidController.text.trim();
        final pass = _wifiPassController.text.trim();
        return 'WIFI:S:$ssid;T:$_wifiSecurity;P:$pass;;';
      case 3:
        final vpa = _upiVpaController.text.trim();
        final name = Uri.encodeComponent(_upiNameController.text.trim());
        final am = _upiAmountController.text.trim();
        return 'upi://pay?pa=$vpa&pn=$name&am=$am&cu=INR';
      default:
        return '';
    }
  }

  void _copyPayload() {
    final payload = _currentPayload;
    if (payload.isEmpty) return;
    Clipboard.setData(ClipboardData(text: payload));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR data copied to clipboard!')),
    );
  }

  void _testInApp() {
    final payload = _currentPayload;
    if (payload.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          decodedContent: payload,
          returnLabel: 'Back to generator',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = _currentPayload;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate QR Code'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: QRGuardTheme.teal,
          labelColor: QRGuardTheme.teal,
          unselectedLabelColor: QRGuardTheme.textSecondary,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.link_rounded), text: 'URL'),
            Tab(icon: Icon(Icons.text_fields_rounded), text: 'Text'),
            Tab(icon: Icon(Icons.wifi_rounded), text: 'Wi-Fi'),
            Tab(icon: Icon(Icons.payment_rounded), text: 'UPI Pay'),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Live QR Preview
              Center(
                child: QrView(
                  data: payload,
                  size: 210,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Live QR Code Preview',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: QRGuardTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),

              // Inputs based on active tab
              IndexedStack(
                index: _tabController.index,
                children: [
                  _buildUrlTab(),
                  _buildTextTab(),
                  _buildWifiTab(),
                  _buildUpiTab(),
                ],
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: payload.isNotEmpty ? _copyPayload : null,
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy Data'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: payload.isNotEmpty ? _testInApp : null,
                      icon: const Icon(Icons.security_rounded),
                      label: const Text('Analyze Risk'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUrlTab() {
    return TextField(
      controller: _urlController,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        labelText: 'Website Address',
        hintText: 'https://example.com',
        prefixIcon: Icon(Icons.public_rounded),
      ),
    );
  }

  Widget _buildTextTab() {
    return TextField(
      controller: _textController,
      maxLines: 3,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        labelText: 'Message or Notes',
        hintText: 'Type any text to encode...',
        prefixIcon: Icon(Icons.short_text_rounded),
      ),
    );
  }

  Widget _buildWifiTab() {
    return Column(
      children: [
        TextField(
          controller: _wifiSsidController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Network Name (SSID)',
            prefixIcon: Icon(Icons.wifi_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _wifiPassController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Wi-Fi Password',
            prefixIcon: Icon(Icons.lock_outline_rounded),
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _wifiSecurity,
          items: const [
            DropdownMenuItem(value: 'WPA', child: Text('WPA / WPA2 (Standard)')),
            DropdownMenuItem(value: 'WEP', child: Text('WEP (Legacy)')),
            DropdownMenuItem(value: 'nopass', child: Text('Open / No Password')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _wifiSecurity = val);
          },
          decoration: const InputDecoration(
            labelText: 'Security Type',
            prefixIcon: Icon(Icons.security_rounded),
          ),
        ),
      ],
    );
  }

  Widget _buildUpiTab() {
    return Column(
      children: [
        TextField(
          controller: _upiVpaController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Payee UPI ID (VPA)',
            hintText: 'user@bank or merchant@upi',
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _upiNameController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Payee Name',
            hintText: 'Merchant or Business Name',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _upiAmountController,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Amount (INR)',
            hintText: '0.00',
            prefixIcon: Icon(Icons.currency_rupee_rounded),
          ),
        ),
      ],
    );
  }
}
