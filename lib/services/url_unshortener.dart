import 'dart:async';
import 'dart:io' show HttpClient, HttpHeaders;
import 'package:flutter/foundation.dart' show kIsWeb;

class UnshortenResult {
  const UnshortenResult({
    required this.originalUrl,
    required this.expandedUrl,
    required this.redirectCount,
    required this.isSuccess,
    this.errorMessage,
  });

  final String originalUrl;
  final String expandedUrl;
  final int redirectCount;
  final bool isSuccess;
  final String? errorMessage;

  bool get hasRedirected => isSuccess && originalUrl != expandedUrl;
}

class UrlUnshortenerService {
  const UrlUnshortenerService();

  Future<UnshortenResult> unshorten(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        (uri.scheme.toLowerCase() != 'http' &&
            uri.scheme.toLowerCase() != 'https')) {
      return UnshortenResult(
        originalUrl: url,
        expandedUrl: url,
        redirectCount: 0,
        isSuccess: false,
        errorMessage: 'Invalid HTTP/HTTPS URL',
      );
    }

    if (kIsWeb) {
      return UnshortenResult(
        originalUrl: url,
        expandedUrl: url,
        redirectCount: 0,
        isSuccess: false,
        errorMessage:
            'Browser CORS restrictions prevent web apps from resolving third-party redirects directly. This runs natively on mobile/desktop devices.',
      );
    }

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 4);

      var currentUri = uri;
      var count = 0;
      const maxHops = 6;

      while (count < maxHops) {
        final request = await client
            .headUrl(currentUri)
            .timeout(const Duration(seconds: 4));
        request.followRedirects = false;

        final response =
            await request.close().timeout(const Duration(seconds: 4));

        if (response.statusCode >= 300 && response.statusCode < 400) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location != null && location.isNotEmpty) {
            final nextUri = currentUri.resolve(location);
            if (nextUri == currentUri) break;
            currentUri = nextUri;
            count++;
            continue;
          }
        }
        break;
      }

      return UnshortenResult(
        originalUrl: url,
        expandedUrl: currentUri.toString(),
        redirectCount: count,
        isSuccess: true,
      );
    } catch (e) {
      return UnshortenResult(
        originalUrl: url,
        expandedUrl: url,
        redirectCount: 0,
        isSuccess: false,
        errorMessage: 'Could not connect to service ($e)',
      );
    } finally {
      client?.close(force: true);
    }
  }
}
