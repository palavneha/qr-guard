import 'package:flutter/material.dart';

import '../app.dart';
import '../models/scan_record.dart';
import '../services/history_service.dart';
import '../widgets/scan_record_tile.dart';
import 'result_screen.dart';
import 'scanner_screen.dart';

/// The main entry screen.
///
/// Shows the QRGuard identity (name + tagline), the primary scan action,
/// a shortcut to history, and a "Recent Scans" area.
///
/// The Recent Scans section is intentionally empty here; it will be
/// populated with real data in Stage 6 when [HistoryService] is wired up.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HistoryService _historyService = HistoryService();
  List<ScanRecord> _records = const [];

  @override
  void initState() {
    super.initState();
    _refreshRecords();
  }

  Future<void> _refreshRecords() async {
    try {
      final records = await _historyService.getRecords();
      if (mounted) setState(() => _records = records.take(3).toList());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load recent scans.')),
        );
      }
    }
  }

  Future<void> _openUpload() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ScannerScreen(openGalleryOnStart: true),
      ),
    );
    await _refreshRecords();
  }

  Future<void> _openRoute(String route) async {
    await Navigator.pushNamed(context, route);
    await _refreshRecords();
  }

  Future<void> _openRecord(ScanRecord record) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          decodedContent: record.content,
          analysisOverride: record.toAnalysisResult(),
          historyService: _historyService,
          returnLabel: 'Back to home',
        ),
      ),
    );
    await _refreshRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    const _AppHeader(),
                    const SizedBox(height: 32),
                    _ScanButton(onPressed: () => _openRoute(AppRoutes.scan)),
                    const SizedBox(height: 12),
                    _UploadButton(onPressed: _openUpload),
                    const SizedBox(height: 12),
                    _HistoryButton(onPressed: () => _openRoute(AppRoutes.history)),
                    const SizedBox(height: 12),
                    _GenerateButton(onPressed: () => _openRoute(AppRoutes.generate)),
                    const SizedBox(height: 32),
                    _sectionLabel(context, 'Recent Scans'),
                    const SizedBox(height: 8),
                    const Divider(
                      color: QRGuardTheme.divider,
                      height: 1,
                      thickness: 1,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 180,
                      child: _RecentScans(
                        records: _records,
                        onTap: _openRecord,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets (private to this file)
// ---------------------------------------------------------------------------

/// App logo, name, and tagline.
class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Shield icon in a glowing rounded container.
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: QRGuardTheme.tealSubtle,
            borderRadius: BorderRadius.circular(QRGuardTheme.radiusXl),
            border: Border.all(
              color: QRGuardTheme.tealBorder,
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.security_rounded,
            size: 44,
            color: QRGuardTheme.teal,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'QRGuard',
          style: Theme.of(context).textTheme.headlineLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Scan smart. Check first. Open safely.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontSize: 15),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Primary action — navigates to the QR scanner screen.
class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
      label: const Text('Scan QR Code'),
    );
  }
}

/// Action to pick and analyze an image file from device storage/gallery.
class _UploadButton extends StatelessWidget {
  const _UploadButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.photo_library_rounded, size: 22),
      label: const Text('Upload QR from Gallery'),
    );
  }
}

/// Secondary action — navigates to the scan history screen.
class _HistoryButton extends StatelessWidget {
  const _HistoryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.history_rounded, size: 22),
      label: const Text('Scan History'),
    );
  }
}

/// Action to generate custom QR codes.
class _GenerateButton extends StatelessWidget {
  const _GenerateButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.qr_code_2_rounded, size: 22),
      label: const Text('Generate QR Code'),
    );
  }
}

class _RecentScans extends StatelessWidget {
  const _RecentScans({required this.records, required this.onTap});

  final List<ScanRecord> records;
  final ValueChanged<ScanRecord> onTap;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_rounded,
                size: 48, color: QRGuardTheme.textFaded),
            const SizedBox(height: 12),
            Text(
              'No scans yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: QRGuardTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap "Scan QR Code" to check your first link.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12),
      itemCount: records.length,
      itemBuilder: (context, index) => ScanRecordTile(
        record: records[index],
        onTap: () => onTap(records[index]),
        dense: true,
      ),
    );
  }
}
