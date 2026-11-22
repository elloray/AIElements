import { text } from '@kit.ArkGraphics2D';

let registered = false;

export function registerAIElementsFonts(): void {
  if (registered) return;
  const fonts = text.FontCollection.getGlobalInstance();
  fonts.loadFontSync('Geist', $rawfile('Geist-Regular.ttf'));
  fonts.loadFontSync('GeistMedium', $rawfile('Geist-Medium.ttf'));
  fonts.loadFontSync('GeistSemibold', $rawfile('Geist-SemiBold.ttf'));
  fonts.loadFontSync('GeistMono', $rawfile('GeistMono-Regular.ttf'));
  registered = true;
}

export class AIColors {
  static readonly background: Resource = $r('app.color.aie_background');
  static readonly foreground: Resource = $r('app.color.aie_foreground');
  static readonly muted: Resource = $r('app.color.aie_muted');
  static readonly mutedForeground: Resource = $r('app.color.aie_muted_foreground');
  static readonly border: Resource = $r('app.color.aie_border');
  static readonly destructive: Resource = $r('app.color.aie_destructive');
  static readonly card: Resource = $r('app.color.aie_card');
  static readonly primary: Resource = $r('app.color.aie_primary');
  static readonly onPrimary: Resource = $r('app.color.aie_on_primary');
  static readonly input: Resource = $r('app.color.aie_input');
  static readonly inputBorder: Resource = $r('app.color.aie_input_border');
  static readonly prompt: Resource = $r('app.color.aie_prompt');
}

// Lucide 0.468 paths shared with the Swift and Compose ports.
export class AIIcons {
  static readonly arrowUp: Resource = $r('app.media.aie_arrowup');
  static readonly arrowDown: Resource = $r('app.media.aie_arrowdown');
  static readonly arrowUpRight: Resource = $r('app.media.aie_arrowupright');
  static readonly plus: Resource = $r('app.media.aie_plus');
  static readonly x: Resource = $r('app.media.aie_x');
  static readonly copy: Resource = $r('app.media.aie_copy');
  static readonly check: Resource = $r('app.media.aie_check');
  static readonly rotateCcw: Resource = $r('app.media.aie_rotateccw');
  static readonly thumbsUp: Resource = $r('app.media.aie_thumbsup');
  static readonly thumbsDown: Resource = $r('app.media.aie_thumbsdown');
  static readonly globe: Resource = $r('app.media.aie_globe');
  static readonly search: Resource = $r('app.media.aie_search');
  static readonly file: Resource = $r('app.media.aie_file');
  static readonly fileText: Resource = $r('app.media.aie_filetext');
  static readonly folder: Resource = $r('app.media.aie_folder');
  static readonly folderOpen: Resource = $r('app.media.aie_folderopen');
  static readonly route: Resource = $r('app.media.aie_route');
  static readonly listTodo: Resource = $r('app.media.aie_listtodo');
  static readonly listChecks: Resource = $r('app.media.aie_listchecks');
  static readonly loaderCircle: Resource = $r('app.media.aie_loadercircle');
  static readonly bot: Resource = $r('app.media.aie_bot');
  static readonly paperclip: Resource = $r('app.media.aie_paperclip');
  static readonly square: Resource = $r('app.media.aie_square');
  static readonly flaskConical: Resource = $r('app.media.aie_flaskconical');
  static readonly sun: Resource = $r('app.media.aie_sun');
  static readonly moon: Resource = $r('app.media.aie_moon');
  static readonly circle: Resource = $r('app.media.aie_circle');
  static readonly circleCheck: Resource = $r('app.media.aie_circlecheck');
  static readonly circleDot: Resource = $r('app.media.aie_circledot');
  static readonly circleX: Resource = $r('app.media.aie_circlex');
  static readonly circleAlert: Resource = $r('app.media.aie_circlealert');
  static readonly chevronRight: Resource = $r('app.media.aie_chevronright');
  static readonly chevronDown: Resource = $r('app.media.aie_chevrondown');
  static readonly trendingUp: Resource = $r('app.media.aie_trendingup');
  static readonly layers: Resource = $r('app.media.aie_layers');
  static readonly messageCircleDashed: Resource = $r('app.media.aie_messagecircledashed');
  static readonly terminal: Resource = $r('app.media.aie_terminal');
}
