import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Soft device chrome for wide Chrome/desktop windows.
/// Real phone feel still needs an Android emulator.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  static const double width = 402;
  static const double height = 874;

  static bool shouldWrap(BuildContext context) {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return false;
    }
    final size = MediaQuery.sizeOf(context);
    return size.width > width + 64;
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldWrap(context)) return child;

    return ColoredBox(
      color: const Color(0xFF0E151A),
      child: Center(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 40,
                offset: Offset(0, 18),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: const Size(width, height),
              padding: const EdgeInsets.only(top: 10, bottom: 14),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
