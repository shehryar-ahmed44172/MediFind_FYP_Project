import 'package:flutter/widgets.dart';

class SizeConfig {
  static MediaQueryData _mediaQueryData = const MediaQueryData();
  static double screenWidth = 375.0; // Default to standard width
  static double screenHeight = 812.0;
  static double blockSizeHorizontal = 3.75;
  static double blockSizeVertical = 8.12;

  static double _safeAreaHorizontal = 0;
  static double _safeAreaVertical = 0;
  static double safeBlockHorizontal = 3.75;
  static double safeBlockVertical = 8.12;

  static double textMultiplier = 1.0;
  static double imageSizeMultiplier = 1.0;
  static double heightMultiplier = 1.0;
  static double widthMultiplier = 1.0;

  void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width > 0 ? _mediaQueryData.size.width : 375.0;
    screenHeight = _mediaQueryData.size.height > 0 ? _mediaQueryData.size.height : 812.0;
    
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;

    _safeAreaHorizontal = _mediaQueryData.padding.left + _mediaQueryData.padding.right;
    _safeAreaVertical = _mediaQueryData.padding.top + _mediaQueryData.padding.bottom;
    
    safeBlockHorizontal = (screenWidth - _safeAreaHorizontal) / 100;
    safeBlockVertical = (screenHeight - _safeAreaVertical) / 100;

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
