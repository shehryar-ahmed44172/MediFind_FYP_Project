import 'package:flutter/widgets.dart';

class SizeConfig {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double blockSizeHorizontal;
  static late double blockSizeVertical;

  static late double _safeAreaHorizontal;
  static late double _safeAreaVertical;
  static late double safeBlockHorizontal;
  static late double safeBlockVertical;

  static late double textMultiplier;
  static late double imageSizeMultiplier;
  static late double heightMultiplier;
  static late double widthMultiplier;

  void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;

    _safeAreaHorizontal = _mediaQueryData.padding.left +
        _mediaQueryData.padding.right;
    _safeAreaVertical = _mediaQueryData.padding.top +
        _mediaQueryData.padding.bottom;
    safeBlockHorizontal = (screenWidth - _safeAreaHorizontal) / 100;
    safeBlockVertical = (screenHeight - _safeAreaVertical) / 100;

    // Multipliers for scaling
    textMultiplier = safeBlockVertical;
    imageSizeMultiplier = safeBlockHorizontal;
    heightMultiplier = safeBlockVertical;
    widthMultiplier = safeBlockHorizontal;
  }
}

extension ResponsiveExtension on num {
  /// Percentage of screen width
  double get wp => (this * SizeConfig.screenWidth) / 100;

  /// Percentage of screen height
  double get hp => (this * SizeConfig.screenHeight) / 100;

  /// Responsive font size based on height (standard practice)
  double get sp => this * (SizeConfig.screenWidth / 375); // Based on standard 375px width
}
