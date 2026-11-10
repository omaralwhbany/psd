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
  String get graphMinimumCurrent => isArabic ? 'أدنى تيار' : 'Min I';
  String get operatingMode => isArabic ? 'نمط التشغيل' : 'Operating Mode';
  String get ccm => isArabic ? 'تيار مستمر CCM' : 'Continuous Conduction (CCM)';
  String get dcm => isArabic ? 'تيار متقطع DCM' : 'Discontinuous Conduction (DCM)';

  String get operatingInputVoltage => isArabic ? 'جهد الدخل أثناء التشغيل' : 'Operating input voltage';
  String get loadLevel => isArabic ? 'مستوى الحمل' : 'Load level';
  String get operatingOutputCurrent => isArabic ? 'تيار الحمل الفعلي' : 'Operating load current';
  String get loadControlNote => isArabic
      ? 'وفق سلوك PSD5 الأصلي: موضع 0% يعادل 1% من تيار الخرج المقنن.'
      : 'Matches PSD5: the 0% slider position is 1% of rated output current.';
  String get operatingPoint => isArabic ? 'نقطة التشغيل' : 'Operating point';
  String get switchingPeriod => isArabic ? 'زمن الدورة' : 'Switching period';
  String get onTime => isArabic ? 'زمن التوصيل ON' : 'ON time';
  String get offTime => isArabic ? 'زمن الفصل OFF' : 'OFF time';
  String get zeroCurrentTime => isArabic ? 'زمن انعدام التيار' : 'Zero-current time';
  String get inductor => isArabic ? 'الملف الحثي' : 'Inductor';
  String get averageCurrent => isArabic ? 'متوسط التيار' : 'Average current';
  String get rmsCurrent => isArabic ? 'تيار RMS الفعال' : 'RMS current';
  String get graphAverageCurrent => isArabic ? 'متوسط التيار' : 'Avg I';
  String get graphRmsCurrent => isArabic ? 'تيار RMS' : 'RMS I';
  String get voltageMinMax => isArabic ? 'أقل / أعلى جهد' : 'Voltage min / max';
  String get mosfet => 'MOSFET';
  String get freewheelDiode => isArabic ? 'دايود المسار الحر' : 'Freewheel diode';
  String get peakCurrentGeneric => isArabic ? 'تيار الذروة' : 'Peak current';
  String get voltageAtZeroCurrent => isArabic ? 'الجهد عند انعدام تيار الملف' : 'Voltage at zero current';
  String get capacitors => isArabic ? 'المكثفات' : 'Capacitors';
  String get inputCapacitorRmsCurrent => isArabic ? 'تيار RMS لمكثف الدخل' : 'Input capacitor RMS current';
  String get inputCapacitorVoltage => isArabic ? 'جهد مكثف الدخل' : 'Input capacitor voltage';
  String get outputCapacitorRmsCurrent => isArabic ? 'تيار RMS لمكثف الخرج' : 'Output capacitor RMS current';
  String get outputCapacitorVoltage => isArabic ? 'جهد مكثف الخرج' : 'Output capacitor voltage';
  String get power => isArabic ? 'القدرة' : 'Power';
  String get outputPower => isArabic ? 'قدرة الخرج' : 'Output power';
  String get diodeLoss => isArabic ? 'فقد الدايود' : 'Diode loss';
  String get inputPower => isArabic ? 'قدرة الدخل' : 'Input power';
  String get synchronizedWaveforms => isArabic ? 'الأشكال الموجية المتزامنة' : 'Synchronized waveforms';
  String get deviceWaveforms => isArabic ? 'موجات عناصر دائرة Buck (مطابقة لمصدر TI)' : 'Buck device waveforms (PSD5 source model)';
  String get voltage => isArabic ? 'الجهد' : 'Voltage';
  String get current => isArabic ? 'التيار' : 'Current';
  String get timeScale => isArabic ? 'المقياس الزمني (µs)' : 'Time Scale (µs)';
  String get threeSwitchingPeriods => isArabic ? 'ثلاث دورات تبديل • عينات انتقالية 1 ns وفق PSD5' : 'Three switching periods • 1 ns transition samples per PSD5';
  String get inputCapacitor => isArabic ? 'مكثف الدخل Ci' : 'Input capacitor Ci';
  String get outputCapacitor => isArabic ? 'مكثف الخرج Co' : 'Output capacitor Co';
  String get graphMinimumVoltage => isArabic ? 'أدنى جهد' : 'Min V';
  String get graphMaximumVoltage => isArabic ? 'أعلى جهد' : 'Max V';
  String get graphMaximumCurrent => isArabic ? 'أعلى تيار' : 'Max I';
  String get graphAcCurrent => isArabic ? 'تيار AC' : 'AC I';
  String get buckCcmCurrent => isArabic ? 'تيار ملف Buck في نمط CCM' : 'Buck inductor current (CCM)';
  String get buckDcmCurrent => isArabic ? 'تيار ملف Buck في نمط DCM' : 'Buck inductor current (DCM)';
  String get buckDescription => isArabic ? 'غير معزول • محول DC-DC خافض للجهد' : 'Non-isolated • Step-down DC-DC converter';
  String get designRippleCurrent => isArabic ? 'تموج التيار التصميمي (حسب نموذج TI)' : 'TI design ripple estimate';
  String get actualCurrentExcursion => isArabic ? 'تغير التيار الفعلي من صفر إلى الذروة' : 'Actual current excursion (zero to peak)';
  String get actualRipplePercent => isArabic ? 'نسبة تموج التيار الفعلي' : 'Actual ripple percentage';
  String localizeBuckWarning(String warning) {
    if (!isArabic) return warning;
    const translations = <String, String>{
      'Actual inductor ripple exceeds the requested ripple target.': 'تموج تيار الملف الفعلي يتجاوز حد التموج المطلوب.',
    };
    return translations[warning] ?? warning;
  }

  String localizeBuckError(String error) {
    if (!isArabic) return error;
    const translations = <String, String>{
      'Operating load percentage must be between 0 and 100.': 'يجب أن تكون نسبة الحمل بين 0 و100%.',
      'Input voltage minimum must be a finite value greater than zero.': 'يجب أن يكون أقل جهد دخل رقماً محدوداً وأكبر من صفر.',
      'Input voltage maximum must be a finite value greater than zero.': 'يجب أن يكون أعلى جهد دخل رقماً محدوداً وأكبر من صفر.',
      'Output voltage must be a finite value greater than zero.': 'يجب أن يكون جهد الخرج رقماً محدوداً وأكبر من صفر.',
      'Output current must be a finite value greater than zero.': 'يجب أن يكون تيار الخرج رقماً محدوداً وأكبر من صفر.',
      'Switching frequency must be a finite value greater than zero.': 'يجب أن يكون تردد التبديل رقماً محدوداً وأكبر من صفر.',
      'Ripple fraction must be a finite value greater than zero.': 'يجب أن تكون نسبة تموج التيار رقماً محدوداً وأكبر من صفر.',
      'Input voltage minimum cannot exceed maximum.': 'لا يمكن أن يكون أقل جهد دخل أكبر من أعلى جهد دخل.',
      'Input voltage must not exceed 10000 V.': 'يجب ألا يتجاوز جهد الدخل 10000 فولت.',
      'Output voltage must not exceed 10000 V.': 'يجب ألا يتجاوز جهد الخرج 10000 فولت.',
      'Output current must not exceed 1000 A.': 'يجب ألا يتجاوز تيار الخرج 1000 أمبير.',
      'Switching frequency must not exceed 10 MHz.': 'يجب ألا يتجاوز تردد التبديل 10 ميجاهرتز.',
      'Ripple fraction must not exceed 1 (100%).': 'يجب ألا تتجاوز نسبة التموج 100%.',
      'Buck output voltage must be below minimum input voltage.': 'يجب أن يكون جهد خرج المحول الخافض أقل من أقل جهد دخل.',
      'Diode forward voltage must be between 0 and 5 V.': 'يجب أن يكون هبوط جهد الدايود بين 0 و5 فولت.',
      'Operating input voltage must be within the input voltage range.': 'يجب أن يقع جهد الدخل التشغيلي ضمن مجال جهد الدخل المحدد.',
      'Selected inductance must be greater than zero.': 'يجب أن تكون قيمة المحاثة المختارة أكبر من صفر.',
      'Selected inductance must not exceed 2200 µH.': 'يجب ألا تتجاوز المحاثة المختارة 2200 ميكروهنري.',
      'Buck duty cycle must not exceed 100% at the selected operating point.': 'نسبة تشغيل المحول الخافض لا يمكن أن تتجاوز 100% عند نقطة التشغيل المحددة.',
      'The selected inductance does not produce a valid Buck DCM cycle at this operating point.': 'قيمة المحاثة المختارة لا تنتج دورة تشغيل DCM صالحة عند نقطة التشغيل هذه.',
    };
    return translations[error] ?? error;
  }

  String get oneSwitchingPeriod => isArabic ? 'دورة تبديل واحدة • D = ' : 'One switching period • D = ';
  String get idealizedWaveformNote => isArabic
      ? 'أشكال موجية مثالية؛ لا تشمل التأثيرات الطفيلية أو زمن الفصل الميت أو انتقالات التبديل.'
      : 'Idealized waveforms; parasitic effects, dead time and switching transitions are omitted.';

  String get language => isArabic ? 'English' : 'العربية';
}