import 'package:flutter_test/flutter_test.dart';
import 'package:madl_project/services/qr_content_parser.dart';

void main() {
  group('QrContentParser', () {
    test('parses Wi-Fi QR code correctly', () {
      const wifi = 'WIFI:S:MyCampus;T:WPA;P:SuperSecret123;;';
      final result = QrContentParser.parse(wifi);

      expect(result.type, QrContentType.wifi);
      expect(result.wifiData?.ssid, 'MyCampus');
      expect(result.wifiData?.securityType, 'WPA');
      expect(result.wifiData?.password, 'SuperSecret123');
    });

    test('parses UPI payment string correctly', () {
      const upi = 'upi://pay?pa=merchant@okaxis&pn=CampusStore&am=250.00&cu=INR';
      final result = QrContentParser.parse(upi);

      expect(result.type, QrContentType.upi);
      expect(result.upiData?.payeeAddress, 'merchant@okaxis');
      expect(result.upiData?.payeeName, 'CampusStore');
      expect(result.upiData?.amount, '250.00');
    });

    test('parses vCard contact correctly', () {
      const vcard = '''BEGIN:VCARD
VERSION:3.0
FN:Alex Mercer
TEL:+1234567890
EMAIL:alex@example.com
ORG:Tech Corp
END:VCARD''';
      final result = QrContentParser.parse(vcard);

      expect(result.type, QrContentType.vCard);
      expect(result.vCardData?.fullName, 'Alex Mercer');
      expect(result.vCardData?.phone, '+1234567890');
      expect(result.vCardData?.email, 'alex@example.com');
      expect(result.vCardData?.organization, 'Tech Corp');
    });

    test('detects standard HTTP/HTTPS URLs', () {
      final result = QrContentParser.parse('https://flutter.dev');
      expect(result.type, QrContentType.url);
    });

    test('falls back to plain text', () {
      final result = QrContentParser.parse('Just a simple note');
      expect(result.type, QrContentType.text);
    });
  });
}
