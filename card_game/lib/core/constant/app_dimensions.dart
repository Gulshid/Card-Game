import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Spacing/radius scale, expressed through ScreenUtil so every value
/// scales consistently with the design-size buckets set in `main.dart`.
/// Use `.r` for radii, `.w`/`.h` for spacing so both axes scale
/// independently on unusual aspect ratios.
abstract class AppSpacing {
  static double get xs => 4.w;
  static double get sm => 8.w;
  static double get md => 16.w;
  static double get lg => 24.w;
  static double get xl => 32.w;
  static double get xxl => 48.w;
}

abstract class AppRadius {
  static double get xs => 4.r;
  static double get sm => 8.r;
  static double get md => 12.r;
  static double get lg => 18.r;
  static double get xl => 26.r;
  static double get pill => 999.r;
}
