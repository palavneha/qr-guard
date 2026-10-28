import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app.dart';
import 'result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, this.openGalleryOnStart = false});

  final bool openGalleryOnStart;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late final MobileScannerController _controller;
  bool _isNavigating = false;
  bool _torchEnabled = false;
  bool _isAnalyzingImage = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      autoStart: true,
    );

    if (widget.openGalleryOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickImageFromGallery();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isNavigating) return;

    String? content;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty && !_hasControlCharacters(value)) {
        content = value;
        break;
      }
    }
    if (content == null) return;

    _navigateToResult(content);
  }

  Future<void> _navigateToResult(String content) async {
    _isNavigating = true;
    try {
      await _controller.stop();
    } catch (_) {
      // Continue to the result even if the camera could not be paused.
    }
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ResultScreen(decodedContent: content),
      ),
    );

    if (!mounted) return;
    _isNavigating = false;
    try {
      await _controller.start();
    } catch (_) {
      // The camera error builder presents initialization failures.
    }
  }

  bool _hasControlCharacters(String value) {
    return value.codeUnits.any((unit) => unit < 0x20 && unit != 0x09);
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torchEnabled = !_torchEnabled);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The flashlight is not available.')),
      );
    }
  }

  Future<void> _retryCamera() async {
    try {
      await _controller.start();
    } catch (_) {
      // MobileScanner's errorBuilder remains visible if startup fails.
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (_isAnalyzingImage) return;

    setState(() => _isAnalyzingImage = true);
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        setState(() => _isAnalyzingImage = false);
        return;
      }

      final barcodes = await _controller.analyzeImage(image.path);
      if (barcodes != null && barcodes.barcodes.isNotEmpty) {
        for (final b in barcodes.barcodes) {
          final val = b.rawValue?.trim();
          if (val != null && val.isNotEmpty) {
            setState(() => _isAnalyzingImage = false);
            _navigateToResult(val);
            return;
          }
        }
      }

      if (!mounted) return;
      setState(() => _isAnalyzingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No QR code found in selected image. Please try another image.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not scan image: $e')),
      );
    }
  }

  Future<void> _showManualInputDialog() async {
    final textController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Test / Enter QR Content'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Type or paste any content (URL, Wi-Fi, UPI, or text) to test without a camera:',
                style: TextStyle(fontSize: 13, color: QRGuardTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'e.g. https://example.com or WIFI:S:...',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              const Text('Quick Test Samples:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _sampleChip(
                    'Low Risk',
                    'https://example.com/',
                    textController,
                  ),
                  _sampleChip(
                    'Caution (Shortener)',
                    'https://bit.ly/demo',
                    textController,
                  ),
                  _sampleChip(
                    'Typosquatting',
                    'https://paypa1.com/login',
                    textController,
                  ),
                  _sampleChip(
                    'Suspicious TLD',
                    'https://login-portal.xyz',
                    textController,
                  ),
                  _sampleChip(
                    'Wi-Fi QR',
                    'WIFI:S:Lab_WiFi;T:WPA;P:Secure2026;;',
                    textController,
                  ),
                  _sampleChip(
                    'UPI Pay',
                    'upi://pay?pa=canteen@upi&pn=Cafeteria&am=85.00&cu=INR',
                    textController,
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(dialogContext).pop();
                _navigateToResult(text);
              }
            },
            child: const Text('Analyze'),
          ),
        ],
      ),
    );
  }

  Widget _sampleChip(
      String label, String value, TextEditingController controller) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () => controller.text = value,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: QRGuardTheme.navy,
        leading: IconButton(
          tooltip: 'Go back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Upload QR image from gallery',
            icon: const Icon(Icons.photo_library_rounded),
            onPressed: _isAnalyzingImage ? null : _pickImageFromGallery,
          ),
          IconButton(
            tooltip: 'Enter QR content manually',
            icon: const Icon(Icons.keyboard_alt_rounded),
            onPressed: _showManualInputDialog,
          ),
          IconButton(
            tooltip: _torchEnabled
                ? 'Turn flashlight off'
                : 'Turn flashlight on',
            icon: Icon(
              _torchEnabled
                  ? Icons.flashlight_off_rounded
                  : Icons.flashlight_on_rounded,
            ),
            onPressed: _toggleTorch,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              final errorText = error.toString().toLowerCase();
              final permissionDenied = errorText.contains('permission') ||
                  errorText.contains('denied');
              return _CameraErrorView(
                permissionDenied: permissionDenied,
                onRetry: _retryCamera,
                onManualInput: _showManualInputDialog,
                onPickImage: _pickImageFromGallery,
              );
            },
          ),
          IgnorePointer(
            ignoring: false,
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 264,
                  height: 264,
                  decoration: BoxDecoration(
                    border: Border.all(color: QRGuardTheme.teal, width: 3),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 24),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: QRGuardTheme.navy.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(QRGuardTheme.radiusMd),
                  ),
                  child: Text(
                    'Place a QR code inside the frame to scan it.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: QRGuardTheme.textPrimary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),

                // Upload button right below scanner
                ElevatedButton.icon(
                  onPressed: _isAnalyzingImage ? null : _pickImageFromGallery,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: QRGuardTheme.teal,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  icon: _isAnalyzingImage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.photo_library_rounded, size: 20),
                  label: Text(_isAnalyzingImage
                      ? 'Scanning Image...'
                      : 'Upload QR from Gallery'),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({
    required this.permissionDenied,
    required this.onRetry,
    required this.onManualInput,
    required this.onPickImage,
  });

  final bool permissionDenied;
  final VoidCallback onRetry;
  final VoidCallback onManualInput;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: QRGuardTheme.navy,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                permissionDenied
                    ? Icons.no_photography_rounded
                    : Icons.camera_alt_rounded,
                size: 56,
                color: QRGuardTheme.teal,
              ),
              const SizedBox(height: 20),
              Text(
                permissionDenied
                    ? 'Camera permission needed'
                    : 'Camera unavailable',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                permissionDenied
                    ? 'Allow camera access in your device settings, or upload a QR image from your gallery.'
                    : 'QRGuard could not start the camera. You can upload a QR image or enter content manually below.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: QRGuardTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: onPickImage,
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Upload QR image'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onManualInput,
                    icon: const Icon(Icons.keyboard_alt_rounded),
                    label: const Text('Test with text'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry camera'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
