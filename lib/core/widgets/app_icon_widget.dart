import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Reusable app icon renderer with bounded in-memory base64 decode caching.
class AppIconWidget extends StatelessWidget {
  final String? iconBase64;
  final double size;
  final double borderRadius;
  final Color fallbackColor;
  final IconData fallbackIcon;

  const AppIconWidget({
    super.key,
    required this.iconBase64,
    this.size = 40,
    this.borderRadius = 10,
    this.fallbackColor = const Color(0xFF4F46E5),
    this.fallbackIcon = Icons.apps_rounded,
  });

  static final Map<int, Uint8List?> _cache = {};

  static Uint8List? decodeCached(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    final key = base64Str.hashCode;
    if (_cache.containsKey(key)) return _cache[key];

    Uint8List? decoded;
    try {
      decoded = base64Decode(base64Str);
    } catch (_) {
      decoded = null;
    }

    if (_cache.length > 300) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = decoded;
    return decoded;
  }

  @override
  Widget build(BuildContext context) {
    final bytes = decodeCached(iconBase64);
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        fallbackIcon,
        color: fallbackColor,
        size: size * 0.55,
      ),
    );
  }
}
