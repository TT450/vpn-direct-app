/**
 * VPN Direct visual source of truth for HarmonyOS NEXT.
 *
 * Values intentionally mirror the iOS DirectUI DesignSystem.swift / DialView.
 * Do not introduce a Harmony-only palette.
 */
export class DirectTheme {
  /** iOS DS.paper rgb(0.93, 0.94, 0.91) */
  static readonly paper: string = '#EDF0E8';
  /** iOS DS.ink rgb(0.08, 0.09, 0.08) */
  static readonly ink: string = '#141714';
  /** iOS DS.panel rgb(0.19, 0.21, 0.18) */
  static readonly panel: string = '#30362E';
  /** iOS DS.muted rgb(0.48, 0.50, 0.46) */
  static readonly muted: string = '#7A8075';
  /** iOS DS.line = Color.black.opacity(0.14) — pure black, not ink-tinted */
  static readonly line: string = '#24000000';
  /** iOS DS.acid rgb(0.66, 0.94, 0.41) */
  static readonly acid: string = '#A8F069';
  /** Tab selected fill: acid @ 14% (VPNHomeView bottomNavigation) */
  static readonly acidSelected: string = '#24A8F069';
  static readonly green: string = '#2E8C4F';
  static readonly danger: string = '#D13D33';
  static readonly white: string = '#FFFFFF';
  /** DialView dialBlue rgb(0.28, 0.55, 0.98) */
  static readonly dialBlue: string = '#478CFA';
  /** OFF label / dial glyph white@0.82 */
  static readonly dialOff: string = '#D1FFFFFF';
  /** AuthField / search white@0.45 */
  static readonly fieldFill: string = '#73FFFFFF';
  /** Panel wash ~22% for home controls row */
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
  static readonly radiusSmall: number = 0;
  static readonly radiusMedium: number = 0;
  static readonly radiusLarge: number = 0;
}

export class DirectTypography {
  static readonly display: number = 40;
  /** iOS PageHeading title / VPNHomeView — semibold → Bold */
  static readonly pageTitle: number = 22;
  /** iOS status title 27 semibold → Bold */
  static readonly statusTitle: number = 27;
  static readonly headline: number = 18;
  static readonly body: number = 13;
  static readonly secondary: number = 12;
  static readonly caption: number = 9;
  /** iOS telemetryCell value 10.5 */
  static readonly telemetry: number = 10.5;
  /** iOS telemetryCell label 6.5 */
  static readonly telemetryLabel: number = 6.5;
}

export class DirectSpacing {
  static readonly xs: number = 4;
  static readonly sm: number = 7;
  static readonly md: number = 10;
  static readonly lg: number = 14;
  static readonly xl: number = 20;
  static readonly xxl: number = 24;
  static readonly huge: number = 32;
}
