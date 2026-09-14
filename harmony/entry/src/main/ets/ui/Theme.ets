/**
 * VPN Direct visual source of truth for HarmonyOS NEXT.
 * Values mirror the iOS DirectUI DesignSystem.swift / DialView.
 */
export class DirectTheme {
  static readonly paper: string = '#EDF0E8';
  static readonly ink: string = '#141714';
  static readonly panel: string = '#30362E';
  static readonly muted: string = '#7A8075';
  static readonly line: string = '#24000000';
  static readonly acid: string = '#A8F069';
  static readonly acidSelected: string = '#24A8F069';
  static readonly green: string = '#2E8C4F';
  static readonly danger: string = '#D13D33';
  static readonly white: string = '#FFFFFF';
  static readonly dialBlue: string = '#478CFA';
  static readonly dialOff: string = '#D1FFFFFF';
  static readonly fieldFill: string = '#73FFFFFF';
  static readonly panelWash: string = '#3830362E';

  static readonly pageTop: number = 24;
  static readonly pageHorizontal: number = 20;
  static readonly appBarHeight: number = 58;
  static readonly tabBarHeight: number = 46;
  static readonly controlHeight: number = 47;
  static readonly serverRowHeight: number = 58;
  static readonly dialOuter: number = 264;
  static readonly dialInner: number = 180;
  static readonly dialFrameHeight: number = 290;
  static readonly menuRowHeight: number = 68;
  static readonly profileHeroHeight: number = 116;
  static readonly profileAvatar: number = 62;
  static readonly profileStatHeight: number = 76;
  static readonly profileSettingsRow: number = 67;
  static readonly utilityRowMin: number = 64;
  static readonly systemRowMin: number = 62;
  static readonly systemSectionHeight: number = 40;
  static readonly managementCtaHeight: number = 48;
  static readonly managementSectionHeight: number = 38;
  static readonly addSubHeight: number = 46;
  static readonly periodPickerHeight: number = 40;
  static readonly balanceTopUpHeight: number = 50;
  static readonly pickerSearchHeight: number = 44;
  static readonly pickerAutoRow: number = 76;
  static readonly pickerTitleSize: number = 34;
  static readonly authBrandW: number = 52;
  static readonly authBrandH: number = 42;
  static readonly authPrimaryHeight: number = 52;

  // ArkUI exposes Normal/Regular/Medium/Bold enum weights. iOS Semibold is
  // represented by the numeric 600 weight for closer typographic parity.
  static readonly weightRegular: FontWeight = FontWeight.Normal;
  static readonly weightMedium: FontWeight = FontWeight.Medium;
  static readonly weightSemibold: number = 600;
  static readonly weightBold: FontWeight = FontWeight.Bold;

  static readonly radiusSmall: number = 0;
  static readonly radiusMedium: number = 0;
  static readonly radiusLarge: number = 0;
}

export class DirectTypography {
  static readonly display: number = 40;
  static readonly pageTitle: number = 22;
  static readonly statusTitle: number = 27;
  static readonly headline: number = 18;
  static readonly body: number = 13;
  static readonly secondary: number = 12;
  static readonly caption: number = 9;
  static readonly telemetry: number = 10.5;
  static readonly telemetryLabel: number = 6.5;
  static readonly statusSubtitle: number = 10;
  static readonly serverTitle: number = 14;
  static readonly cardTitle: number = 19;
  static readonly search: number = 13;
}

export class DirectSpacing {
  static readonly hairline: number = 1;
  static readonly xs: number = 4;
  static readonly sm: number = 7;
  static readonly md: number = 10;
  static readonly lg: number = 14;
  static readonly xl: number = 20;
  static readonly xxl: number = 24;
  static readonly huge: number = 32;
}
