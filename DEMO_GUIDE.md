# QRGuard Demo Guide

## Run the app

From the project root:

```powershell
flutter pub get
flutter run
```

Or run directly in Chrome:

```powershell
flutter run -d chrome
```

For a debug APK:

```powershell
flutter build apk --debug
```

The expected APK path is `build/app/outputs/flutter-apk/app-debug.apk`.

---

## What's New in QRGuard (Expanded Edition)

1. **Typosquatting & Lookalike Domain Detection**:
   Uses Levenshtein edit distance and character-replacement analysis (e.g. `0` for `o`, `1` for `l`, `rn` for `m`) to detect spoofed domains like `paypa1.com` or `arnazon.com`.
2. **Suspicious Top-Level Domain (TLD) Alert**:
   Warns when URLs use extensions heavily associated with disposable phishing campaigns (`.xyz`, `.top`, `.buzz`, `.cfd`, `.tk`, etc.).
3. **URL Unshortener / Redirect Resolver**:
   When shortened links (`bit.ly`, `tinyurl.com`, etc.) are detected, users can tap **"Follow Redirects & Reveal URL"** to expand the real destination before opening.
4. **Multi-Format QR Parsing**:
   - **Wi-Fi QRs** (`WIFI:S:...;T:...;P:...;;`): Shows Network Name, Security, and Password with a copy button.
   - **UPI Payment QRs** (`upi://pay?...`): Displays Payee Name, UPI ID (VPA), and Amount with payment safety reminders.
   - **vCard Contacts** (`BEGIN:VCARD ...`): Parses Name, Phone, and Email.
5. **QR Code Generator**:
   Generate clean offline QR codes directly in the app for URLs, Plain Text, Wi-Fi networks, and UPI payment requests.
6. **Search, Filter & Export History**:
   - Live search bar and filter chips (`All`, `High Risk`, `Caution`, `Low Risk`).
   - Export scan history to **CSV** (for Excel/Sheets) or **JSON**.
7. **Manual Test Input**:
   Tap the keyboard icon in the Scanner screen to test any QR payload without needing a physical camera.

---

## Suggested QR Test Scenarios

Encode each exact string into a QR code (or use the built-in QR Generator / Manual Input dialog):

- **Low Risk example**: `https://example.com/`
- **Caution (HTTP)**: `http://example.com/`
- **Caution (URL Shortener with Unshortener)**: `https://bit.ly/demo`
- **Caution (Suspicious TLD)**: `https://portal-service.xyz`
- **Caution (Deceptive Keywords)**: `https://example.com/urgent-action-account-verification`
- **High Risk (Typosquatting)**: `https://paypa1.com/login`
- **High Risk (Brand Masquerading)**: `https://paypal.attacker.test/login`
- **High Risk (User-info `@` trick)**: `https://example.com@attacker.test/login`
- **Wi-Fi QR**: `WIFI:S:Campus_WiFi;T:WPA;P:SecurePass2026;;`
- **UPI Payment QR**: `upi://pay?pa=canteen@upi&pn=Cafeteria&am=120.00&cu=INR`
- **Non-URL text**: `QRGuard classroom demo text`
- **Unsupported scheme**: `javascript:alert(1)`

---

## Demonstrate Features Step-by-Step

### 1. Test QR Scanner & Camera
- Tap **Scan QR Code**.
- Either frame a QR code in the camera, or tap the **Keyboard icon** in the top bar to test with pre-filled sample buttons.

### 2. Test Multi-Format Content
- Scan or enter a **Wi-Fi QR** (`WIFI:S:Campus_WiFi;T:WPA;P:SecurePass2026;;`).
- Observe the dedicated **Wi-Fi Connection Details** card showing network name, masked password with show/hide toggle, and a **Copy Password** button.

### 3. Test QR Generator
- Return to home and tap **Generate QR Code**.
- Switch between URL, Text, Wi-Fi, and UPI tabs.
- Notice the live-generated vector QR code on the canvas.
- Tap **Analyze Risk** to immediately pipe your generated QR into QRGuard's security analyzer.

### 4. Test Search, Filter & Export History
- Open **Scan History**.
- Type in the search bar to filter scans in real-time.
- Tap the **High Risk** or **Caution** chips to isolate specific threat levels.
- Tap the **Export icon** in the top bar and choose **Export as CSV** or **Export as JSON** to copy audit logs to your clipboard.
