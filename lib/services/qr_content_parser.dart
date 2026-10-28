enum QrContentType {
  url,
  wifi,
  upi,
  vCard,
  email,
  phone,
  sms,
  text,
}

class WifiData {
  const WifiData({
    required this.ssid,
    required this.securityType,
    required this.password,
    required this.hidden,
  });

  final String ssid;
  final String securityType;
  final String password;
  final bool hidden;
}

class UpiData {
  const UpiData({
    required this.payeeAddress,
    required this.payeeName,
    this.amount,
    this.currency,
    this.transactionNote,
  });

  final String payeeAddress;
  final String payeeName;
  final String? amount;
  final String? currency;
  final String? transactionNote;
}

class VCardData {
  const VCardData({
    required this.fullName,
    this.phone,
    this.email,
    this.organization,
  });

  final String fullName;
  final String? phone;
  final String? email;
  final String? organization;
}

class ParsedQrContent {
  const ParsedQrContent({
    required this.rawContent,
    required this.type,
    this.wifiData,
    this.upiData,
    this.vCardData,
  });

  final String rawContent;
  final QrContentType type;
  final WifiData? wifiData;
  final UpiData? upiData;
  final VCardData? vCardData;

  String get typeLabel => switch (type) {
        QrContentType.url => 'Website URL',
        QrContentType.wifi => 'Wi-Fi Network',
        QrContentType.upi => 'UPI Payment',
        QrContentType.vCard => 'Contact Card (vCard)',
        QrContentType.email => 'Email Address',
        QrContentType.phone => 'Phone Number',
        QrContentType.sms => 'SMS Message',
        QrContentType.text => 'Plain Text',
      };
}

class QrContentParser {
  const QrContentParser._();

  static ParsedQrContent parse(String raw) {
    final trimmed = raw.trim();

    // 1. Wi-Fi: WIFI:S:MyNet;T:WPA;P:MyPass;H:false;;
    if (trimmed.toUpperCase().startsWith('WIFI:')) {
      final wifi = _parseWifi(trimmed);
      if (wifi != null) {
        return ParsedQrContent(
          rawContent: raw,
          type: QrContentType.wifi,
          wifiData: wifi,
        );
      }
    }

    // 2. UPI: upi://pay?pa=...&pn=...
    if (trimmed.toLowerCase().startsWith('upi://pay')) {
      final upi = _parseUpi(trimmed);
      if (upi != null) {
        return ParsedQrContent(
          rawContent: raw,
          type: QrContentType.upi,
          upiData: upi,
        );
      }
    }

    // 3. vCard: BEGIN:VCARD ... END:VCARD
    if (trimmed.toUpperCase().contains('BEGIN:VCARD')) {
      final vcard = _parseVCard(trimmed);
      return ParsedQrContent(
        rawContent: raw,
        type: QrContentType.vCard,
        vCardData: vcard,
      );
    }

    // 4. Email: mailto:user@domain.com
    if (trimmed.toLowerCase().startsWith('mailto:')) {
      return ParsedQrContent(
        rawContent: raw,
        type: QrContentType.email,
      );
    }

    // 5. Phone: tel:+123456789
    if (trimmed.toLowerCase().startsWith('tel:')) {
      return ParsedQrContent(
        rawContent: raw,
        type: QrContentType.phone,
      );
    }

    // 6. SMS: sms:+123456789
    if (trimmed.toLowerCase().startsWith('sms:')) {
      return ParsedQrContent(
        rawContent: raw,
        type: QrContentType.sms,
      );
    }

    // 7. URL
    final uri = Uri.tryParse(trimmed);
    if (uri != null &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https') &&
        uri.host.isNotEmpty) {
      return ParsedQrContent(
        rawContent: raw,
        type: QrContentType.url,
      );
    }

    // 8. Plain text default
    return ParsedQrContent(
      rawContent: raw,
      type: QrContentType.text,
    );
  }

  static WifiData? _parseWifi(String text) {
    // Strips WIFI: prefix
    final body = text.substring(5);
    final parts = body.split(';');

    String ssid = '';
    String security = 'WPA';
    String password = '';
    bool hidden = false;

    for (final part in parts) {
      if (part.startsWith('S:') || part.startsWith('s:')) {
        ssid = part.substring(2);
      } else if (part.startsWith('T:') || part.startsWith('t:')) {
        security = part.substring(2);
      } else if (part.startsWith('P:') || part.startsWith('p:')) {
        password = part.substring(2);
      } else if (part.startsWith('H:') || part.startsWith('h:')) {
        hidden = part.substring(2).toLowerCase() == 'true';
      }
    }

    if (ssid.isEmpty) return null;
    return WifiData(
      ssid: ssid,
      securityType: security.isEmpty ? 'WPA/WPA2' : security,
      password: password,
      hidden: hidden,
    );
  }

  static UpiData? _parseUpi(String text) {
    final uri = Uri.tryParse(text);
    if (uri == null) return null;

    final pa = uri.queryParameters['pa'] ?? '';
    final pn = uri.queryParameters['pn'] ?? 'Unknown Merchant';
    final am = uri.queryParameters['am'];
    final cu = uri.queryParameters['cu'] ?? 'INR';
    final tn = uri.queryParameters['tn'];

    if (pa.isEmpty) return null;

    return UpiData(
      payeeAddress: pa,
      payeeName: pn,
      amount: am,
      currency: cu,
      transactionNote: tn,
    );
  }

  static VCardData _parseVCard(String text) {
    String fullName = 'Contact';
    String? phone;
    String? email;
    String? org;

    final lines = text.split(RegExp(r'\r?\n'));
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.startsWith('FN:')) {
        fullName = line.substring(3).trim();
      } else if (line.startsWith('TEL;') || line.startsWith('TEL:')) {
        final colonIdx = line.indexOf(':');
        if (colonIdx != -1) phone = line.substring(colonIdx + 1).trim();
      } else if (line.startsWith('EMAIL;') || line.startsWith('EMAIL:')) {
        final colonIdx = line.indexOf(':');
        if (colonIdx != -1) email = line.substring(colonIdx + 1).trim();
      } else if (line.startsWith('ORG:')) {
        org = line.substring(4).trim();
      }
    }

    return VCardData(
      fullName: fullName,
      phone: phone,
      email: email,
      organization: org,
    );
  }
}
