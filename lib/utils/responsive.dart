import 'package:flutter/widgets.dart';

class Responsive {
  Responsive._();

  static double width(BuildContext context, double fraction) {
    final size = MediaQuery.sizeOf(context);
    return size.width * fraction;
  }

  static double height(BuildContext context, double fraction) {
    final size = MediaQuery.sizeOf(context);
    return size.height * fraction;
  }

  static bool isSmallPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 700;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600;
}




