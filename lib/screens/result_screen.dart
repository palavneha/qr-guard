import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../app.dart';
import '../models/analysis_result.dart';
import '../models/scan_record.dart';
import '../services/history_service.dart';
import '../services/qr_content_parser.dart';
import '../services/url_analyzer.dart';
import '../services/url_unshortener.dart';
import '../widgets/finding_tile.dart';
import '../widgets/risk_badge.dart';

typedef LinkLaunchCallback = Future<bool> Function(Uri uri);

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.decodedContent,
    this.launchUrlOverride,
    this.analysisOverride,
    this.historyService,
    this.returnLabel = 'Return to scanning',
  });

  final String decodedContent;

  /// Optional platform-launch seam for deterministic widget tests.
  final LinkLaunchCallback? launchUrlOverride;
  final AnalysisResult? analysisOverride;
  final HistoryService? historyService;
  final String returnLabel;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late AnalysisResult _analysis;
  late final ParsedQrContent _parsedContent;

  // URL unshortening state
  bool _isUnshortening = false;
  String? _unshortenedUrl;
  String? _unshortenError;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _analysis = widget.analysisOverride ?? analyzeUrl(widget.decodedContent);
    _parsedContent = QrContentParser.parse(widget.decodedContent);
    if (widget.analysisOverride == null) _saveScan();
  }

  Future<void> _saveScan() async {
    try {
      await (widget.historyService ?? HistoryService()).addRecord(
        ScanRecord.fromAnalysis(_analysis),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Scan completed, but history could not be saved.')),
      );
    }
  }

  bool get _isShortener =>
      _analysis.findings.any((f) => f.title == 'URL shortener');

  Future<void> _expandUrl() async {
    setState(() {
      _isUnshortening = true;
      _unshortenError = null;
    });

    final result =
        await const UrlUnshortenerService().unshorten(widget.decodedContent);

    if (!mounted) return;

    if (result.isSuccess && result.hasRedirected) {
      setState(() {
        _isUnshortening = false;
        _unshortenedUrl = result.expandedUrl;
        // Re-analyze destination
        _analysis = analyzeUrl(result.expandedUrl);
      });
      // Save updated destination analysis to history
      _saveScan();
    } else {
      setState(() {
        _isUnshortening = false;
        _unshortenError = result.errorMessage ??
            (result.isSuccess
                ? 'No redirects found. Link leads to the same address.'
                : 'Could not expand URL.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysis = _analysis;
    final isUrl = analysis.isValidUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Result')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 8),
                    Icon(
                      _getHeaderIcon(),
                      size: 48,
                      color: QRGuardTheme.teal,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isUrl
                          ? 'URL risk analysis'
                          : 'QR code contains non-URL content',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (!isUrl && _parsedContent.type != QrContentType.text) ...[
                      const SizedBox(height: 4),
                      Text(
                        _parsedContent.typeLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: QRGuardTheme.teal,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Center(child: RiskBadge(riskLevel: analysis.riskLevel)),
                    const SizedBox(height: 12),
                    Text(
                      analysis.summary,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: QRGuardTheme.textSecondary,
                            height: 1.45,
                          ),
                      textAlign: TextAlign.center,
                    ),

                    // Multi-format cards for Wi-Fi / UPI / Contact
                    if (_parsedContent.type == QrContentType.wifi)
                      _buildWifiCard(),
                    if (_parsedContent.type == QrContentType.upi)
                      _buildUpiCard(),
                    if (_parsedContent.type == QrContentType.vCard)
                      _buildVCardCard(),

                    const SizedBox(height: 24),
                    Text(
                      isUrl ? 'Scanned URL' : 'Decoded content',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      decoration: BoxDecoration(
                        color: QRGuardTheme.card,
                        borderRadius:
                            BorderRadius.circular(QRGuardTheme.radiusMd),
                        border: Border.all(color: QRGuardTheme.divider),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SelectableText(
                              _unshortenedUrl ?? widget.decodedContent,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copy content',
                            icon: const Icon(Icons.copy_rounded),
                            onPressed: () => _copyText(
                                context, _unshortenedUrl ?? widget.decodedContent),
                          ),
                        ],
                      ),
                    ),

                    // Unshortener Card
                    if (isUrl && _isShortener) ...[
                      const SizedBox(height: 16),
                      _buildUnshortenerSection(),
                    ],

                    const SizedBox(height: 24),
                    Text('Findings',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ...analysis.findings
                        .map((finding) => FindingTile(finding: finding)),
                    if (!analysis.isValidUrl) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Only valid HTTP or HTTPS URLs can be opened as websites.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: QRGuardTheme.textSecondary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed:
                    isUrl ? () => _openLink(context, _analysis) : null,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open website'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(widget.returnLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getHeaderIcon() {
    return switch (_parsedContent.type) {
      QrContentType.url => Icons.link_rounded,
      QrContentType.wifi => Icons.wifi_rounded,
      QrContentType.upi => Icons.payment_rounded,
      QrContentType.vCard => Icons.contact_page_rounded,
      QrContentType.email => Icons.mail_rounded,
      QrContentType.phone => Icons.phone_rounded,
      QrContentType.sms => Icons.sms_rounded,
      QrContentType.text => Icons.text_snippet_rounded,
    };
  }

  Widget _buildUnshortenerSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QRGuardTheme.navyLight,
        borderRadius: BorderRadius.circular(QRGuardTheme.radiusMd),
        border: Border.all(color: QRGuardTheme.tealBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route_rounded,
                  color: QRGuardTheme.teal, size: 22),
              const SizedBox(width: 8),
              Text(
                'Expand Shortened URL',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: QRGuardTheme.teal,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Check where this link actually leads before you tap Open Website.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: QRGuardTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          if (_unshortenedUrl != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: QRGuardTheme.card,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resolved Destination:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: QRGuardTheme.teal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _unshortenedUrl!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ] else if (_unshortenError != null) ...[
            Text(
              _unshortenError!,
              style: const TextStyle(color: QRGuardTheme.caution, fontSize: 13),
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: _isUnshortening ? null : _expandUrl,
              icon: _isUnshortening
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.unfold_more_rounded, size: 18),
              label: Text(_isUnshortening
                  ? 'Resolving Redirects...'
                  : 'Follow Redirects & Reveal URL'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWifiCard() {
    final wifi = _parsedContent.wifiData;
    if (wifi == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QRGuardTheme.card,
        borderRadius: BorderRadius.circular(QRGuardTheme.radiusMd),
        border: Border.all(color: QRGuardTheme.tealBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_rounded, color: QRGuardTheme.teal),
              const SizedBox(width: 8),
              Text(
                'Wi-Fi Connection Details',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: QRGuardTheme.teal,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const Divider(color: QRGuardTheme.divider, height: 20),
          _detailRow('Network (SSID):', wifi.ssid),
          _detailRow('Security:', wifi.securityType),
          Row(
            children: [
              Expanded(
                child: _detailRow(
                  'Password:',
                  _showPassword
                      ? (wifi.password.isEmpty ? '(None)' : wifi.password)
                      : (wifi.password.isEmpty ? '(None)' : '••••••••'),
                ),
              ),
              if (wifi.password.isNotEmpty) ...[
                IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
                IconButton(
                  tooltip: 'Copy password',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () => _copyText(context, wifi.password),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpiCard() {
    final upi = _parsedContent.upiData;
    if (upi == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QRGuardTheme.card,
        borderRadius: BorderRadius.circular(QRGuardTheme.radiusMd),
        border: Border.all(color: QRGuardTheme.caution),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: QRGuardTheme.caution),
              const SizedBox(width: 8),
              Text(
                'UPI Payment Verification',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: QRGuardTheme.caution,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const Divider(color: QRGuardTheme.divider, height: 20),
          _detailRow('Payee Name:', upi.payeeName),
          _detailRow('UPI ID (VPA):', upi.payeeAddress),
          if (upi.amount != null)
            _detailRow('Amount:', '${upi.currency ?? 'INR'} ${upi.amount}'),
          if (upi.transactionNote != null)
            _detailRow('Note:', upi.transactionNote!),
          const SizedBox(height: 8),
          Text(
            'Always verify the recipient name and UPI ID in your banking app before authorizing with your PIN.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: QRGuardTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildVCardCard() {
    final vcard = _parsedContent.vCardData;
    if (vcard == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QRGuardTheme.card,
        borderRadius: BorderRadius.circular(QRGuardTheme.radiusMd),
        border: Border.all(color: QRGuardTheme.tealBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_rounded, color: QRGuardTheme.teal),
              const SizedBox(width: 8),
              Text(
                'Contact Information',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: QRGuardTheme.teal,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const Divider(color: QRGuardTheme.divider, height: 20),
          _detailRow('Name:', vcard.fullName),
          if (vcard.phone != null) _detailRow('Phone:', vcard.phone!),
          if (vcard.email != null) _detailRow('Email:', vcard.email!),
          if (vcard.organization != null)
            _detailRow('Company:', vcard.organization!),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: QRGuardTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyText(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard.')),
    );
  }

  Future<void> _openLink(
    BuildContext context,
    AnalysisResult analysis,
  ) async {
    final targetUrl = _unshortenedUrl ?? widget.decodedContent.trim();
    final uri = Uri.tryParse(targetUrl);
    final scheme = uri?.scheme.toLowerCase();
    if (!analysis.isValidUrl ||
        uri == null ||
        (scheme != 'http' && scheme != 'https') ||
        uri.host.isEmpty) {
      _showMessage(context, 'Only valid HTTP or HTTPS URLs can be opened.');
      return;
    }

    if (analysis.riskLevel != RiskLevel.low) {
      final confirmed = await _confirmOpen(context, uri, analysis);
      if (confirmed != true || !context.mounted) return;
    }

    try {
      final opened = widget.launchUrlOverride != null
          ? await widget.launchUrlOverride!(uri)
          : await launcher.launchUrl(uri,
              mode: launcher.LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        _showMessage(context, 'Could not open this website. Please try again.');
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'Could not open website.');
      }
    }
  }

  Future<bool?> _confirmOpen(
    BuildContext context,
    Uri uri,
    AnalysisResult analysis,
  ) {
    final isHigh = analysis.riskLevel == RiskLevel.high;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          isHigh ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
          color: isHigh ? QRGuardTheme.highRisk : QRGuardTheme.caution,
          size: 36,
        ),
        title: Text(isHigh ? 'High Risk warning' : 'Review this link'),
        content: Text(
          isHigh
              ? 'This link exhibits high-risk or deceptive indicators. Never provide passwords, banking credentials, or personal data on unverified sites.'
              : 'This link has caution warnings. Are you sure you trust the destination domain (${uri.host})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: isHigh
                ? FilledButton.styleFrom(backgroundColor: QRGuardTheme.highRisk)
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Open anyway'),
          ),
        ],
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
