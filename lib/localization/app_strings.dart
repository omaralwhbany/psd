import 'package:flutter/widgets.dart';

class AppStrings {
  AppStrings(this.locale);
  final Locale locale;
  bool get isArabic => locale.languageCode == 'ar';
  String get appTitle => 'PSD';
  String get subtitle => isArabic ? 'مصمم مراحل القدرة' : 'Power Stage Designer';
  String get powerStages => isArabic ? 'طبولوجيات القدرة' : 'Power Stages';
  String get designTools => isArabic ? 'أدوات التصميم' : 'Design Tools';
  String get buckConverter => isArabic ? 'محول خافض Buck' : 'Buck Converter';
  String get boostConverter => isArabic ? 'محول رافع Boost' : 'Boost Converter';
  String get comingSoon => isArabic ? 'قريباً' : 'Coming soon';
  String get inputs => isArabic ? 'مدخلات التصميم' : 'Design Inputs';
  String get results => isArabic ? 'نتائج الحساب' : 'Calculated Results';
  String get schematic => isArabic ? 'مخطط الدائرة' : 'Power Stage Schematic';
  String get inputVoltageMin => isArabic ? 'أقل جهد دخل' : 'Input Voltage Min';
  String get inputVoltageMax => isArabic ? 'أعلى جهد دخل' : 'Input Voltage Max';
  String get outputVoltage => isArabic ? 'جهد الخرج' : 'Output Voltage';
  String get outputCurrent => isArabic ? 'تيار الخرج' : 'Output Current';
  String get switchingFrequency => isArabic ? 'تردد التبديل' : 'Switching Frequency';
  String get ripplePercent => isArabic ? 'تموج تيار الملف' : 'Inductor Ripple';
  String get diodeDrop => isArabic ? 'هبوط جهد الدايود' : 'Diode Forward Voltage';
  String get inductance => isArabic ? 'قيمة الملف' : 'Selected Inductance';
  String get inductanceUsed => isArabic ? 'المحاثة المستخدمة بالحساب' : 'Inductance Used';
  String get customInductor => isArabic ? 'إدخال قيمة ملف مخصصة' : 'Use custom inductor value';
  String get automaticInductor => isArabic ? 'افتراضياً يحسب التطبيق قيمة الملف تلقائياً' : 'By default, the app calculates inductance automatically';
  String get inputCurrent => isArabic ? 'متوسط تيار الدخل' : 'Average Input Current';
  String get dutyCycle => isArabic ? 'نسبة التشغيل' : 'Duty Cycle';
  String get minimumInductance => isArabic ? 'أقل محاثة مطلوبة' : 'Minimum Inductance';
  String get rippleCurrent => isArabic ? 'تموج تيار الملف' : 'Inductor Ripple Current';
  String get peakCurrent => isArabic ? 'أقصى تيار الملف' : 'Inductor Peak Current';
  String get minimumCurrent => isArabic ? 'أقل تيار الملف' : 'Inductor Minimum Current';
  String get operatingMode => isArabic ? 'نمط التشغيل' : 'Operating Mode';
  String get ccm => isArabic ? 'تيار مستمر CCM' : 'Continuous Conduction (CCM)';
  String get dcm => isArabic ? 'تيار متقطع DCM' : 'Discontinuous Conduction (DCM)';
  String get language => isArabic ? 'English' : 'العربية';
}