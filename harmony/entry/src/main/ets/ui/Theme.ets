/**
 * VPN Direct visual source of truth for HarmonyOS NEXT.
 *
 * Values intentionally mirror the iOS DirectUI DesignSystem.swift.
 * Do not introduce a Harmony-only palette.
 */
export class DirectTheme {
  static readonly paper: string = '#EDEFE8';
  static readonly ink: string = '#141714';
  static readonly panel: string = '#30362E';
  static readonly muted: string = '#7A8075';
  static readonly line: string = '#24141714';
  static readonly acid: string = '#A8F069';
  static readonly green: string = '#2E8C4F';
  static readonly danger: string = '#D13D33';
  static readonly white: string = '#FFFFFF';

  static readonly pageTop: number = 24;
  static readonly pageHorizontal: number = 20;
  static readonly appBarHeight: number = 58;
  static readonly tabBarHeight: number = 46;
  static readonly controlHeight: number = 47;
  static readonly serverRowHeight: number = 58;
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
  static readonly telemetry: number = 10;
  static readonly telemetryLabel: number = 7;
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
