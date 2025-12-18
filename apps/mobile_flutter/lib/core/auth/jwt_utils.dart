import 'dart:convert';

class JwtUtils {
  /// JWT の exp（秒）を DateTime に変換して返す
  static DateTime? tryGetExpiry(String jwt) {
    final parts = jwt.split('.');
    if (parts.length < 2) return null;

    try {
      final payload = _decodeBase64UrlJson(parts[1]);
      final exp = payload['exp'];
      final expSeconds = exp is int ? exp : int.tryParse(exp?.toString() ?? '');
      if (expSeconds == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000, isUtc: true).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// 期限が近い（または期限切れ）なら true
  static bool isExpiringSoon(
    String jwt, {
    Duration leeway = const Duration(minutes: 2),
  }) {
    final exp = tryGetExpiry(jwt);
    if (exp == null) return true;
    return DateTime.now().isAfter(exp.subtract(leeway));
  }

  static Map<String, dynamic> _decodeBase64UrlJson(String input) {
    final normalized = base64Url.normalize(input);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final obj = jsonDecode(decoded);
    if (obj is Map<String, dynamic>) return obj;
    return <String, dynamic>{};
  }
}


