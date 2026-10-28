import '../models/analysis_result.dart';

const Set<String> knownUrlShorteners = {
	'bit.ly',
	'bitly.com',
	'tinyurl.com',
	't.co',
	'goo.gl',
	'ow.ly',
	'is.gd',
	'buff.ly',
	'shorturl.at',
	'rebrand.ly',
	'cutt.ly',
	'rb.gy',
	'lnkd.in',
};

const Map<String, String> _brandDomains = {
	'amazon': 'amazon.com',
	'apple': 'apple.com',
	'facebook': 'facebook.com',
	'google': 'google.com',
	'instagram': 'instagram.com',
	'microsoft': 'microsoft.com',
	'paypal': 'paypal.com',
	'netflix': 'netflix.com',
	'twitter': 'twitter.com',
	'whatsapp': 'whatsapp.com',
	'binance': 'binance.com',
	'spotify': 'spotify.com',
};

const Set<String> _suspiciousTlds = {
	'xyz', 'top', 'buzz', 'cfd', 'tk', 'ml', 'ga', 'cf', 'gq',
	'work', 'sbs', 'monster', 'fit', 'rest', 'icu', 'click', 'cam',
};

const List<String> _deceptivePhrases = [
	'account verification',
	'verify your account',
	'verify-account',
	'password reset',
	'reset your password',
	'urgent action',
	'act immediately',
	'prize claim',
	'claim your prize',
	'claim your reward',
	'you have won',
	'unusual login',
	'confirm your login',
];

/// Analyzes an HTTP(S) URL using local, explainable heuristics only.
AnalysisResult analyzeUrl(String input) {
	final value = input.trim();
	if (value.isEmpty) return _invalid(value, 'The QR code did not contain a URL.');

	final uri = Uri.tryParse(value);
	if (uri == null ||
			(uri.scheme.toLowerCase() != 'http' && uri.scheme.toLowerCase() != 'https') ||
			uri.host.isEmpty ||
			value.contains(RegExp(r'\s'))) {
		return _invalid(
			value,
			'This content is not a valid HTTP or HTTPS URL, so it was not analyzed as a website.',
		);
	}
	if (!_hasValidAuthority(uri)) {
		return _invalid(
			value,
			'This URL has an invalid hostname or port and was not analyzed as a website.',
		);
	}

	final findings = <Finding>[];
	final warningCategories = <String>{};
	final scheme = uri.scheme.toLowerCase();
	final host = uri.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
	final content = '$host ${uri.path} ${uri.query} ${uri.fragment}'
			.toLowerCase()
			.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');

	findings.add(
		Finding(
			title: scheme == 'https' ? 'HTTPS connection' : 'Unencrypted HTTP',
			description: scheme == 'https'
					? 'HTTPS encrypts the connection, but it does not guarantee that the website itself is trustworthy.'
					: 'HTTP does not encrypt the connection. Avoid entering sensitive information on this page.',
			isWarning: scheme == 'http',
		),
	);
	if (scheme == 'http') warningCategories.add('transport');

	if (_isIpAddress(host)) {
		findings.add(const Finding(
			title: 'IP-based host',
			description: 'This URL uses a numeric network address instead of a recognizable domain name.',
		));
		warningCategories.add('ip-host');
	}

	if (knownUrlShorteners.contains(host)) {
		findings.add(const Finding(
			title: 'URL shortener',
			description: 'The destination is hidden behind a shortening service. Check where it leads before proceeding.',
		));
		warningCategories.add('shortener');
	}

	final tld = host.split('.').last;
	if (_suspiciousTlds.contains(tld)) {
		findings.add(Finding(
			title: 'Suspicious Top-Level Domain (.$tld)',
			description: 'The .$tld domain extension is frequently associated with disposable spam and phishing sites.',
		));
		warningCategories.add('tld');
	}

	final typosquattingWarning = _detectTyposquatting(host);
	if (typosquattingWarning != null) {
		findings.add(Finding(
			title: 'Typosquatting / Lookalike brand',
			description: '$typosquattingWarning (possible typo-trap or phishing attempt).',
		));
		warningCategories.add('typosquatting');
	}

	if (_deceptivePhrases.any((phrase) =>
			content.contains(phrase.replaceAll(RegExp(r'[^a-z0-9]+'), ' ')))) {
		findings.add(const Finding(
			title: 'Potentially deceptive wording',
			description: 'The URL contains wording often used to create urgency or request account actions. This is a warning signal, not proof of malicious intent.',
		));
		warningCategories.add('wording');
	}

	final usesUserInfo = uri.userInfo.isNotEmpty;
	final suspiciousBrand = _hasMisleadingBrandHost(host);
	final manySubdomains = host.split('.').length >= 5;
	final punycode = host.split('.').any((label) => label.startsWith('xn--'));
	if (usesUserInfo || suspiciousBrand || manySubdomains || punycode) {
		final details = <String>[];
		if (usesUserInfo) {
			details.add('it contains an @ sign before the actual host');
		}
		if (suspiciousBrand) {
			details.add('it places a familiar brand name outside that brand\'s domain');
		}
		if (manySubdomains) details.add('it has an unusually deep subdomain structure');
		if (punycode) details.add('it uses an encoded internationalized domain label');
		findings.add(Finding(
			title: 'Deceptive or unusual URL structure',
			description: 'Review the hostname carefully: ${details.join('; ')}.',
		));
		warningCategories.add('structure');
	}

	final warningCount = warningCategories.length;
	final highRisk = usesUserInfo || suspiciousBrand || typosquattingWarning != null || warningCount >= 2;
	final riskLevel = highRisk
			? RiskLevel.high
			: warningCount > 0
					? RiskLevel.medium
					: RiskLevel.low;
	final summary = switch (riskLevel) {
		RiskLevel.low => 'No configured warning rules were triggered. This does not guarantee the website is safe.',
		RiskLevel.medium => 'One or more warning signals need your attention. These checks cannot confirm whether a website is malicious.',
		RiskLevel.high => 'Multiple warning signals or a strong deceptive URL pattern were detected. Do not enter sensitive information unless you independently verify the destination.',
	};

	return AnalysisResult(
		input: value,
		isValidUrl: true,
		riskLevel: riskLevel,
		summary: summary,
		findings: List.unmodifiable(findings),
	);
}

AnalysisResult _invalid(String input, String message) => AnalysisResult(
			input: input,
			isValidUrl: false,
			riskLevel: RiskLevel.medium,
			summary: message,
			findings: [
				Finding(
					title: 'Not analyzed as a website',
					description: message,
				),
			],
		);

bool _isIpAddress(String host) {
	final ipv4Parts = host.split('.');
	if (ipv4Parts.length == 4 &&
			ipv4Parts.every((part) =>
					part.isNotEmpty &&
					int.tryParse(part) != null &&
					int.parse(part) >= 0 &&
					int.parse(part) <= 255)) {
		return true;
	}

	final unwrapped = host.startsWith('[') && host.endsWith(']')
			? host.substring(1, host.length - 1)
			: host;
	return unwrapped.contains(':') &&
			RegExp(r'^[0-9a-f:]+$', caseSensitive: false).hasMatch(unwrapped);
}

bool _hasValidAuthority(Uri uri) {
	try {
		if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) return false;
	} on FormatException {
		return false;
	}

	final host = uri.host;
	if (host.startsWith('[') && host.endsWith(']')) {
		return _isIpAddress(host);
	}
	if (host.startsWith('.') || host.endsWith('.') || host.contains('..')) {
		return false;
	}
	return host.split('.').every((label) =>
			label.isNotEmpty &&
			!label.startsWith('-') &&
			!label.endsWith('-') &&
			RegExp(r'^[a-z0-9-]+$', caseSensitive: false).hasMatch(label));
}

bool _hasMisleadingBrandHost(String host) {
	for (final entry in _brandDomains.entries) {
		final labels = host.split('.');
		if (labels.contains(entry.key) &&
				host != entry.value &&
				!host.endsWith('.${entry.value}')) {
			return true;
		}
	}
	return false;
}

int _levenshtein(String a, String b) {
	if (a == b) return 0;
	if (a.isEmpty) return b.length;
	if (b.isEmpty) return a.length;

	List<int> v0 = List<int>.generate(b.length + 1, (i) => i);
	List<int> v1 = List<int>.filled(b.length + 1, 0);

	for (var i = 0; i < a.length; i++) {
		v1[0] = i + 1;
		for (var j = 0; j < b.length; j++) {
			final cost = (a.codeUnitAt(i) == b.codeUnitAt(j)) ? 0 : 1;
			v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((x, y) => x < y ? x : y);
		}
		for (var j = 0; j <= b.length; j++) {
			v0[j] = v1[j];
		}
	}
	return v1[b.length];
}

String? _detectTyposquatting(String host) {
	final labels = host.split('.');
	if (labels.length < 2) return null;
	final sld = labels[labels.length - 2].toLowerCase();

	for (final entry in _brandDomains.entries) {
		final brand = entry.key;
		final officialDomain = entry.value;

		if (host == officialDomain || host.endsWith('.$officialDomain')) continue;

		final normalized = sld
				.replaceAll('0', 'o')
				.replaceAll('1', 'l')
				.replaceAll('5', 's')
				.replaceAll('8', 'b')
				.replaceAll('rn', 'm')
				.replaceAll('vv', 'w');

		if (normalized == brand && sld != brand) {
			return 'Domain label "$sld" uses lookalike characters to mimic "$brand"';
		}

		if (sld.length >= 4 && brand.length >= 4) {
			final dist = _levenshtein(sld, brand);
			if (dist == 1) {
				return 'Domain label "$sld" is 1 character away from legitimate brand "$brand"';
			}
		}
	}
	return null;
}
