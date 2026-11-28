import { i18n } from '@kit.LocalizationKit';
import { AIColors as C, AIIcons } from '../ui/Theme';
import { AIText, AIIcon, AIProgress, AIBadge, AICard, AISeparator, AISwitch } from '../ui/Primitives';
import { AIChart, AIChartKind, AIChartRow, AIChartSeries, AITable, AITableColumn, AITableRow } from '../ui/DataDisplay';
import { AICodeBlock } from '../ui/Chat';
import { AITraceLine } from '../ui/Traces';
import { AIShadcnNode, AIShadcnItem, AIShadcnState } from './Model';
import { ShadcnTableRow, shadcnTableRows } from './TableRows';
import { ShadcnFlow } from './Flow';

const icons: Record<string, Resource> = {
  'frame': AIIcons.frame, 'chart-pie': AIIcons.chartPie, 'map': AIIcons.map, 'ellipsis': AIIcons.ellipsis,
  'file-text': AIIcons.fileText, 'circle-check': AIIcons.circleCheck, 'cloud': AIIcons.cloud,
  'bookmark': AIIcons.bookmark, 'bold': AIIcons.bold, 'italic': AIIcons.italic, 'underline': AIIcons.underline,
  'calendar': AIIcons.calendar, 'settings': AIIcons.settings, 'git-branch': AIIcons.gitBranch,
  'search': AIIcons.search, 'plus': AIIcons.plus, 'globe': AIIcons.globe, 'message-circle-dashed': AIIcons.messageCircleDashed
};

@Component
struct ShadcnSpinner {
  @Prop iconSize: number = 16;
  @Consume('shadcnAnimationsActive') private animationsActive: boolean;
  @State private angle: number = 0;

  build() {
    Image(AIIcons.loaderCircle)
      .width(this.iconSize).height(this.iconSize).fillColor(C.foreground).draggable(false)
      .rotate({ angle: this.animationsActive ? this.angle : 0 })
      .animation(this.animationsActive ? { duration: 1000, curve: Curve.Linear, iterations: -1 } : undefined)
      .onAppear(() => { this.angle = 360; })
      .accessibilityText('Loading')
  }
}

@Component
export struct AIShadcnView {
  @Prop node: AIShadcnNode = { kind: 'column' };
  @Provide('shadcnImages') images: Record<string, Resource> = {};
  @Provide('shadcnAnimationsActive') animationsActive: boolean = true;
  @State state: AIShadcnState = new AIShadcnState();
  onAction: (id: string, value: string) => void = () => {};

  build() {
    ShadcnPart({ node: this.node, store: this.state, path: this.node.id ?? this.node.kind, onAction: this.onAction })
  }
}

@Component
struct ShadcnPart {
  @Prop node: AIShadcnNode = { kind: 'column' };
  @Prop path: string = '';
  @Prop rtl: boolean = i18n.isRTL(i18n.System.getSystemLanguage());
  @Consume('shadcnImages') images: Record<string, Resource>;
  @ObjectLink store: AIShadcnState;
  onAction: (id: string, value: string) => void = () => {};
  @State private open: boolean = false;
  @State private requiredError: boolean = false;
  @State private query: string = '';
  @State private page: number = 0;
  @State private month: Date = new Date();
  @State private panelWidth: number = 0;
  @State private ascending: boolean = true;
  @State private sortColumn: number = -1;
  @State private atEnd: boolean = true;
  private scroller: Scroller = new Scroller();
  private timer: number = -1;
  @State private notices: number[] = [];
  private noticeSerial: number = 0;
  private noticeTimers: Map<number, number> = new Map<number, number>();
  private dragOrigin: number = 0;

  aboutToAppear(): void {
    if ((this.node.kind === 'calendar' || this.node.kind === 'date-picker') && this.val().length === 10) {
      const d = new Date(this.val() + 'T12:00:00');
      if (Number.isFinite(d.getTime()) && this.stamp(d) === this.val()) this.month = d;
    }
  }
  aboutToDisappear(): void {
    clearTimeout(this.timer);
    this.noticeTimers.forEach((timer: number) => clearTimeout(timer));
    this.noticeTimers.clear();
  }
  private removeNotice(id: number): void {
    clearTimeout(this.noticeTimers.get(id));
    this.noticeTimers.delete(id);
    this.notices = this.notices.filter((item: number) => item !== id);
  }
  private addNotice(): void {
    if (this.notices.length >= 3) this.removeNotice(this.notices[0]);
    const id = ++this.noticeSerial;
    this.notices = this.notices.concat([id]);
    this.noticeTimers.set(id, setTimeout(() => this.removeNotice(id), 4000));
  }
  private val(): string { return this.store.values.get(this.path) ?? this.node.value ?? ''; }
  private set(value: string): void { this.store.set(this.path, value); this.onAction(this.path, value); }
  private label(): string { return this.node.label ?? ''; }
  private parts(): AIShadcnNode[] { return this.node.children ?? []; }
  private opts(): AIShadcnItem[] { return this.node.items ?? []; }
  private itemKey(item: AIShadcnItem): string { return item.id ?? item.label; }
  private childID(i: number): string { return this.parts()[i].id ?? this.path + '/' + i; }
  private childValue(i: number): string { return this.store.values.get(this.childID(i)) ?? this.parts()[i].value ?? ''; }
  private is(...kinds: string[]): boolean { return kinds.includes(this.node.kind); }
  private number(fallback: number): number {
    const value = this.val() ? Number(this.val()) : fallback;
    return Number.isFinite(value) ? value : fallback;
  }
  private language(): number { return Math.max(0, this.opts().findIndex((item: AIShadcnItem) => this.itemKey(item) === this.val())); }
  private image(name: string): Resource | undefined {
    if (this.images[name]) return this.images[name];
    if (name === 'shadcn-aspect') return $r('app.media.aie_shadcn_aspect');
    if (name === 'shadcn-avatar') return $r('app.media.aie_shadcn_avatar');
    return undefined;
  }
  private textSize(): number {
    switch (this.node.variant) {
      case 'h1': return 36;
      case 'h2': return 30;
      case 'h3': return 24;
      case 'h4': case 'lead': return 20;
      case 'large': return 18;
      default: return 14;
    }
  }

  @Builder
  private child(i: number) {
    ShadcnPart({ node: this.parts()[i], store: this.store, path: this.childID(i), onAction: this.onAction,
      rtl: this.is('direction') ? (this.opts()[this.language()]?.detail ?? this.val()) === 'rtl' : this.rtl })
  }
  @Builder
  private children() {
    ForEach(this.parts(), (n: AIShadcnNode, i: number) => { this.child(i) },
      (n: AIShadcnNode, i: number) => JSON.stringify([n.id ?? String(i), n.kind]))
  }
  @Builder
  private title(text: string, size: number = 14, medium: boolean = false, muted: boolean = false) {
    Text(text).fontFamily(medium ? 'GeistMedium' : 'Geist').fontSize(size)
      .fontColor(muted ? C.mutedForeground : C.foreground)
  }
  @Builder
  private glyph(name: string, size: number = 16) {
    AIIcon({ icon: icons[name] ?? AIIcons.circle, iconSize: size, color: C.foreground })
  }
  @Builder
  private btn(text: string, variant: string, press: () => void, enabled: boolean = true) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(text).fontFamily('GeistMedium').fontSize(14).fontColor(variant === 'primary' ? C.onPrimary : C.foreground)
    }
    .constraintSize({ minHeight: 32 }).padding({ left: 11, right: 11, top: 4, bottom: 4 })
    .backgroundColor(variant === 'primary' ? C.primary : variant === 'secondary' ? C.muted : Color.Transparent)
    .border({ width: variant === 'outline' ? 1 : 0, color: C.inputBorder, radius: 10 })
    .enabled(enabled).opacity(enabled ? 1 : 0.45).onClick(press)
  }
  @Builder
  private iconButton(icon: Resource, label: string, press: () => void, enabled: boolean = true) {
    Button({ type: ButtonType.Normal }) { AIIcon({ icon: icon, color: C.foreground }) }
      .width(28).height(28).padding(4).borderRadius(14).backgroundColor(Color.Transparent)
      .enabled(enabled).opacity(enabled ? 1 : 0.45).accessibilityText(label).onClick(press)
  }

  @Builder
  private information() {
    Row({ space: this.is('attachment') ? 8 : 12 }) {
      if (this.node.icon) {
        if (this.is('attachment')) {
          Stack() { this.glyph(this.node.icon) }.width(this.node.variant === 'default' ? 36 : 28)
            .height(this.node.variant === 'default' ? 36 : 28).backgroundColor(C.muted).borderRadius(6)
        } else { this.glyph(this.node.icon) }
      }
      Column({ space: this.is('attachment') ? 1 : 4 }) {
        this.title(this.label(), this.node.variant === 'xs' ? 12 : 14, true)
        if (this.node.detail) { this.title(this.node.detail, this.is('attachment') ? 12 : 14, false, true) }
        this.children()
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (this.node.action) { this.btn(this.node.action, 'outline', () => this.onAction(this.path, this.node.action!)) }
      if (this.node.variant === 'link') { this.iconButton(AIIcons.chevronRight, this.label(), () => this.onAction(this.path, this.label())) }
    }.alignItems(this.is('alert') ? VerticalAlign.Top : VerticalAlign.Center)
    .padding(this.is('attachment') ? (this.node.variant === 'default' ? 8 : 5) : 12).width('100%')
    .borderRadius(12).border({ width: 1, color: C.border }).backgroundColor(this.is('alert') ? C.card : C.background)
  }

  @Builder
  private disclosure() {
    if (this.is('accordion')) {
      Column() {
        ForEach(this.opts(), (item: AIShadcnItem, i: number) => {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 8 }) {
              Text(item.label).fontFamily('GeistMedium').fontSize(14).fontColor(C.foreground).layoutWeight(1)
              AIIcon({ icon: AIIcons.chevronDown }).rotate({ angle: this.val() === this.itemKey(item) ? 180 : 0 })
            }.width('100%').padding({ top: 12, bottom: 12 })
          }.padding(0).backgroundColor(Color.Transparent).enabled(!item.disabled)
          .onClick(() => this.set(this.val() === this.itemKey(item) ? '' : this.itemKey(item)))
          if (this.val() === this.itemKey(item)) {
            Text(item.detail ?? '').fontFamily('Geist').fontSize(14).fontColor(C.foreground)
              .lineHeight(20).width('100%').padding({ bottom: 12 })
          }
          if (i < this.opts().length - 1) { AISeparator() }
        }, (item: AIShadcnItem) => this.itemKey(item))
      }.width('100%').alignItems(HorizontalAlign.Start)
    } else {
      Column({ space: 8 }) {
        Row() {
          Text(this.label()).fontFamily('GeistMedium').fontColor(C.foreground).fontSize(14).layoutWeight(1)
          AIIcon({ icon: AIIcons.chevronDown }).rotate({ angle: this.val() === 'true' ? 180 : 0 })
        }.width('100%').padding(8).focusable(true).onClick(() => this.set(String(this.val() !== 'true')))
        if (this.val() === 'true') {
          this.title(this.node.detail ?? '')
          this.children()
          if (this.node.action) { this.btn(this.node.action, 'primary', () => this.onAction(this.path, this.node.action!)) }
        }
      }.alignItems(HorizontalAlign.Start).padding(16).borderRadius(14).border({ width: 1, color: C.border }).width('100%')
    }
  }

  @Builder
  private check(label: string, checked: boolean, radio: boolean, detail: string, press: () => void, enabled: boolean = true) {
    Row({ space: radio ? 12 : 8 }) {
      Stack() {
        if (checked && radio) { Circle().width(6).height(6).fill(C.onPrimary) }
        else if (checked) { AIIcon({ icon: AIIcons.check, iconSize: 14, color: C.onPrimary }) }
      }.width(16).height(16).backgroundColor(checked ? C.primary : C.input).borderRadius(radio ? 8 : 4)
      .border({ width: 1, color: checked ? C.primary : C.inputBorder })
      if (label) {
        Column({ space: 4 }) {
          this.title(label, 14, true)
          if (detail) { this.title(detail, 14, false, true) }
        }.alignItems(HorizontalAlign.Start)
      }
    }.enabled(enabled).opacity(enabled ? 1 : 0.45).focusable(true).accessibilityGroup(true).accessibilityText(label)
    .accessibilityDescription(checked ? 'Selected' : 'Unselected').onClick(press)
  }
  private otpSize(): number { return Math.max(1, Math.min(32, this.node.size ?? 6)); }
  private numbers(count: number): number[] { const result: number[] = []; for (let i = 0; i < count; i++) result.push(i); return result; }
  @Builder
  private input() {
    Column({ space: 6 }) {
      if (this.node.label) {
        Row() {
          Text(this.node.label).fontFamily('GeistMedium').fontSize(14).fontColor(C.foreground).layoutWeight(1)
          if (this.node.action) { Text(this.node.action).fontFamily('Geist').fontSize(14).fontColor(C.foreground)
            .onClick(() => this.onAction(this.path, this.node.action!)) }
        }.width('100%')
      }
      if (this.is('textarea')) {
        TextArea({ text: this.val(), placeholder: this.node.placeholder }).fontFamily('Geist').fontSize(14).fontColor(C.foreground)
          .placeholderColor(C.mutedForeground).constraintSize({ minHeight: 64 }).width('100%').padding(10)
          .backgroundColor(C.input).border({ width: 1, color: C.inputBorder }).borderRadius(10).onChange((v: string) => this.set(v))
      } else {
        Row({ space: 8 }) {
          if (this.is('input-group')) { this.glyph(this.node.icon ?? 'search') }
          TextInput({ text: this.val(), placeholder: this.node.placeholder }).fontFamily('Geist').fontSize(14).fontColor(C.foreground)
            .placeholderColor(C.mutedForeground).padding(0).height(30).layoutWeight(1).backgroundColor(Color.Transparent)
            .type(this.node.variant === 'password' ? InputType.Password : InputType.Normal).showPasswordIcon(false)
            .accessibilityText(this.label() || this.node.placeholder || 'Input').onChange((v: string) => this.set(v))
          this.children()
        }.width('100%').padding({ left: 11, right: 11 }).constraintSize({ minHeight: 32 }).borderRadius(10)
        .backgroundColor(C.input).border({ width: 1, color: C.inputBorder })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  private form() {
    if (this.is('input', 'input-group', 'textarea')) { this.input() }
    else if (this.is('input-otp')) {
      Stack() {
        Row() {
          ForEach(this.numbers(this.otpSize()), (i: number) => {
            if (i > 0) { Divider().vertical(true).height(32).color(C.inputBorder) }
            Text(this.val().charAt(i)).fontFamily('Geist').fontSize(14).fontColor(C.foreground).textAlign(TextAlign.Center).width(31).height(32)
          }, (i: number) => String(i))
        }.borderRadius(10).border({ width: 1, color: C.inputBorder })
        TextInput({ text: this.val() }).width(this.otpSize() * 32).height(32).opacity(0.02).type(InputType.Number)
          .maxLength(this.otpSize()).accessibilityText(this.label()).onChange((v: string) => this.set(v.replace(/[^0-9]/g, '').slice(0, this.otpSize())))
      }
    } else if (this.is('checkbox')) { this.check(this.label(), this.val() === 'true', false, '', () => this.set(String(this.val() !== 'true'))) }
    else if (this.is('label')) {
      if (this.parts()[0]?.kind === 'checkbox') {
        this.check(this.label(), this.childValue(0) === 'true', false, '', () => {
          const id = this.childID(0);
          const next = String(this.childValue(0) !== 'true');
          this.store.set(id, next);
          this.onAction(id, next);
        })
      } else { Row({ space: 8 }) { this.children(); this.title(this.label(), 14, true) } }
    } else if (this.is('field')) {
      Column({ space: 6 }) {
        this.title(this.label(), 14, true)
        if (this.node.variant === 'description-first') { this.title(this.node.detail ?? '', 14, false, true) }
        this.children()
        if (this.node.variant !== 'description-first' && this.node.detail) { this.title(this.node.detail, 14, false, true) }
      }.alignItems(HorizontalAlign.Start).width('100%')
    } else if (this.is('radio-group')) {
      Column({ space: 8 }) {
        if (this.node.label) { this.title(this.label(), 16, true) }
        if (this.node.detail) { this.title(this.node.detail, 14, false, true) }
        ForEach(this.opts(), (item: AIShadcnItem) => {
          this.check(item.label, this.val() === this.itemKey(item), true, item.detail ?? '', () => this.set(this.itemKey(item)), !item.disabled)
        }, (item: AIShadcnItem) => this.itemKey(item))
      }.alignItems(HorizontalAlign.Start)
    } else if (this.is('slider')) {
      Slider({ value: this.number(0), min: 0, max: 100, step: 1, style: SliderStyle.OutSet })
        .trackColor(C.muted).selectedColor(C.primary).blockColor(C.background).blockBorderColor(C.primary).blockBorderWidth(1)
        .blockSize({ width: 16, height: 16 }).trackThickness(4).width('100%').height(32)
        .accessibilityText(this.label()).onChange((v: number) => this.set(String(Math.round(v))))
    } else {
      Row({ space: 6 }) {
        if (this.node.icon) { this.glyph(this.node.icon, 14) }
        this.title(this.label(), 14, true)
      }.padding({ left: 8, right: 8 }).constraintSize({ minHeight: 28 }).borderRadius(8)
      .backgroundColor(this.val() === 'true' ? C.muted : Color.Transparent)
      .border({ width: this.node.variant === 'outline' ? 1 : 0, color: C.inputBorder })
      .focusable(true).onClick(() => this.set(String(this.val() !== 'true')))
    }
  }

  private active(item: AIShadcnItem): boolean {
    if (this.is('toggle-group') && this.node.variant === 'multiple') return this.store.values.get(this.path + '/' + this.itemKey(item)) === 'true';
    return (this.val() || (this.opts().length ? this.itemKey(this.opts()[0]) : '')) === this.itemKey(item);
  }
  private segmentPress(item: AIShadcnItem): void {
    if (this.is('button-group', 'breadcrumb')) { this.onAction(this.path, this.itemKey(item)); return; }
    if (this.is('toggle-group') && this.node.variant === 'multiple') {
      const key = this.path + '/' + this.itemKey(item);
      const next = String(!this.active(item));
      this.store.set(key, next);
      this.onAction(key, next);
    } else this.set(this.itemKey(item));
  }
  private tab(): number { return this.opts().findIndex((item: AIShadcnItem) => this.active(item)); }
  @Builder
  private segments() {
    Column({ space: 8 }) {
      Row() { ShadcnFlow({ rtl: this.rtl, gap: this.is('pagination') ? 4 : this.is('tabs') ? 6 : this.is('toggle-group') && this.node.variant === 'multiple' ? 8 : 0 }) {
        ForEach(this.opts(), (item: AIShadcnItem, i: number) => {
          if (this.is('breadcrumb') && i > 0) { AIIcon({ icon: AIIcons.chevronRight, iconSize: 12 }).margin({ left: 8, right: 8 }) }
          if (this.is('button-group') && i > 0) { Divider().vertical(true).height(28).color(C.border) }
          Stack({ alignContent: Alignment.Bottom }) {
            Row({ space: 4 }) {
              if (item.icon) { this.glyph(item.icon) }
              else { this.title(item.label, 14, !this.is('breadcrumb'), this.is('breadcrumb') && i < this.opts().length - 1 || this.is('tabs') && !this.active(item)) }
            }.constraintSize({ minHeight: this.is('breadcrumb') ? 20 : 32 })
            .padding({ left: this.is('breadcrumb') ? 0 : 8, right: this.is('breadcrumb') ? 0 : 8 })
            if (this.is('tabs') && this.active(item) && this.node.variant === 'line') { Divider().strokeWidth(2).width(28).color(C.foreground) }
          }.borderRadius(8)
          .backgroundColor(this.is('toggle-group') && this.active(item) ? C.muted : Color.Transparent)
          .border({ width: this.is('toggle-group') || this.is('pagination') && this.active(item) ? 1 : 0, color: C.inputBorder })
          .accessibilityText(item.label).focusable(true).enabled(!item.disabled && !(this.is('breadcrumb') && i === this.opts().length - 1))
          .onClick(() => this.segmentPress(item))
        }, (item: AIShadcnItem) => this.itemKey(item))
      } }.backgroundColor(this.is('button-group') && this.node.variant === 'secondary' ? C.muted : Color.Transparent)
      .borderRadius(9).clip(true)
      if (this.is('tabs') && this.tab() >= 0 && this.tab() < this.parts().length) { this.child(this.tab()) }
    }.alignItems(HorizontalAlign.Start)
  }

  private choices(): AIShadcnItem[] { return this.opts().filter((i: AIShadcnItem) => i.label.toLowerCase().includes(this.query.toLowerCase())); }
  private choose(i: AIShadcnItem): void { this.set(this.itemKey(i)); this.open = false; this.query = ''; }
  @Builder
  private menuItems() {
    Menu() {
      ForEach(this.opts(), (item: AIShadcnItem) => {
        MenuItem({ content: item.label }).enabled(!item.disabled).onClick(() => this.choose(item))
      }, (item: AIShadcnItem) => this.itemKey(item))
    }
  }
  @Builder
  private popupList() {
    Column({ space: 2 }) {
      if (this.node.heading) { this.title(this.node.heading, 12, true, true) }
      if (this.is('command')) {
        TextInput({ text: this.query, placeholder: this.node.placeholder }).fontFamily('Geist').fontSize(14).height(34)
          .onChange((v: string) => { this.query = v; })
      }
      if (this.choices().length === 0) { this.title('No results found.') }
      ForEach(this.choices(), (item: AIShadcnItem) => {
        Row() {
          Text(item.label).fontFamily('Geist').fontSize(14).fontColor(C.foreground).layoutWeight(1)
          if (this.val() === this.itemKey(item)) { AIIcon({ icon: AIIcons.check, iconSize: 14 }) }
        }.constraintSize({ minHeight: 28 }).width('100%').padding({ left: 8, right: 8 }).enabled(!item.disabled)
        .opacity(item.disabled ? 0.5 : 1).focusable(true).onClick(() => this.choose(item))
      }, (item: AIShadcnItem) => this.itemKey(item))
    }.padding(6).width(210).alignItems(HorizontalAlign.Start).backgroundColor(C.card).borderRadius(10)
  }
  private selectedLabel(): string { return this.opts().find((row: AIShadcnItem) => this.itemKey(row) === this.val())?.label ?? this.node.placeholder ?? this.label(); }
  @Builder
  private choice() {
    if (this.is('context-menu')) {
      Stack() { this.title('Long press here') }.width('100%').height(this.node.height ?? 180)
      .border({ width: 1, radius: 12, style: BorderStyle.Dashed, color: C.border })
      .bindContextMenu(this.menuItems(), ResponseType.LongPress)
    } else if (this.is('native-select')) {
      Select(this.opts().map((item: AIShadcnItem): SelectOption => ({ value: item.label })))
        .value(this.selectedLabel()).font({ size: 14, family: 'Geist' }).height(32).backgroundColor(C.input)
        .border({ width: 1, radius: 10, color: C.inputBorder }).fontColor(C.foreground)
        .onSelect((index: number) => { if (this.opts()[index] && !this.opts()[index].disabled) this.choose(this.opts()[index]); })
    } else {
      Row({ space: 8 }) {
        if (this.is('combobox')) {
          TextInput({ text: this.open ? this.query : this.val(), placeholder: this.node.placeholder })
            .fontFamily('Geist').fontSize(14).fontColor(C.foreground).height(30).layoutWeight(1).padding(0)
            .backgroundColor(Color.Transparent).onChange((v: string) => { this.query = v; this.open = true; })
        } else {
          this.title(this.is('select') ? this.selectedLabel() : this.label(), 14, !this.is('select'), this.is('select') && !this.val())
        }
        if (this.is('combobox', 'select')) { AIIcon({ icon: AIIcons.chevronDown, iconSize: 14 }) }
      }.justifyContent(this.is('select', 'combobox') ? FlexAlign.SpaceBetween : FlexAlign.Center)
      .width(this.is('combobox', 'select') && this.node.width ? '100%' : 'auto').padding({ left: 10, right: 10 }).constraintSize({ minHeight: 32 })
      .border({ width: 1, radius: 10, color: C.inputBorder }).focusable(true).onClick(() => { this.open = !this.open; })
      .bindPopup(this.open, { builder: this.popupList, placement: Placement.Bottom, enableArrow: false, popupColor: C.card,
        onStateChange: (e) => { this.open = e.isVisible; } })
    }
  }

  private stamp(d: Date): string { return String(d.getFullYear()) + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); }
  private dateAt(i: number): Date {
    const first = new Date(this.month.getFullYear(), this.month.getMonth(), 1);
    return new Date(first.getFullYear(), first.getMonth(), 1 + i - first.getDay());
  }
  private weekCount(): number {
    const year = this.month.getFullYear(), m = this.month.getMonth();
    return Math.ceil((new Date(year, m, 1).getDay() + new Date(year, m + 1, 0).getDate()) / 7);
  }
  private changeMonth(delta: number): void { this.month = new Date(this.month.getFullYear(), this.month.getMonth() + delta, 1); }
  @Builder
  private calendar() {
    Column({ space: 7 }) {
      Row() {
        this.iconButton(AIIcons.chevronLeft, 'Previous month', () => this.changeMonth(-1))
        Text(this.month.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })).fontFamily('GeistMedium')
          .fontSize(14).fontColor(C.foreground).textAlign(TextAlign.Center).layoutWeight(1)
        this.iconButton(AIIcons.chevronRight, 'Next month', () => this.changeMonth(1))
      }.width('100%')
      Row() {
        ForEach(['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'], (day: string) => {
          Text(day).fontSize(12).fontFamily('Geist').fontColor(C.mutedForeground).height(26).textAlign(TextAlign.Center).layoutWeight(1)
        }, (day: string) => day)
      }.width('100%')
      ForEach(this.numbers(this.weekCount()), (week: number) => {
        Row() {
          ForEach(this.numbers(7), (day: number) => {
            Text(String(this.dateAt(week * 7 + day).getDate())).fontSize(14).fontFamily('Geist').height(28).layoutWeight(1).textAlign(TextAlign.Center)
              .borderRadius(8).fontColor(this.val() === this.stamp(this.dateAt(week * 7 + day)) ? C.onPrimary :
                this.dateAt(week * 7 + day).getMonth() !== this.month.getMonth() ? C.mutedForeground : C.foreground)
              .backgroundColor(this.val() === this.stamp(this.dateAt(week * 7 + day)) ? C.primary :
                this.stamp(new Date()) === this.stamp(this.dateAt(week * 7 + day)) ? C.muted : Color.Transparent)
              .focusable(true).accessibilityText(this.stamp(this.dateAt(week * 7 + day))).onClick(() => {
                this.month = this.dateAt(week * 7 + day); this.set(this.stamp(this.month)); this.open = false;
              })
          }, (day: number) => String(day))
        }.width('100%')
      }, (week: number) => String(week))
    }.padding(8).width(214).border({ width: 1, color: C.border, radius: 10 }).backgroundColor(C.background)
  }
  @Builder
  private details() {
    Column({ space: this.is('tooltip') ? 0 : 8 }) {
      if (this.node.heading) { this.title(this.node.heading, this.is('dialog', 'sheet', 'drawer', 'alert-dialog') ? 18 : 14, true) }
      if (this.node.detail) { this.title(this.node.detail, this.is('tooltip') ? 12 : 14, false, !this.is('tooltip')) }
      if (this.is('hover-card') && this.node.value) { this.title(this.node.value, 12, false, true) }
      this.children()
      if (this.is('sheet', 'dialog', 'drawer', 'alert-dialog', 'toast')) {
        Row({ space: 8 }) {
          if (!this.is('toast')) { this.btn('Cancel', 'outline', () => { this.open = false; }) }
          if (this.node.action) { this.btn(this.node.action, 'primary', () => { this.onAction(this.path, this.node.action!); this.open = false; }) }
        }
      }
    }.width(this.is('tooltip') ? 'auto' : '100%').alignItems(HorizontalAlign.Start).padding(this.is('tooltip') ? 8 : 16)
    .backgroundColor(C.card).borderRadius(12)
  }
  private showOverlay(): void {
    if (this.is('date-picker') && !this.open) {
      const date = new Date(this.val() + 'T12:00:00');
      this.month = Number.isFinite(date.getTime()) && this.stamp(date) === this.val() ? date : new Date();
    }
    this.open = this.is('toast') || !this.open;
    if (this.is('toast')) {
      clearTimeout(this.timer);
      this.timer = setTimeout(() => { this.open = false; }, 5000);
    }
  }
  @Builder
  private sonner() {
    Column({ space: 8 }) {
      this.btn(this.label(), 'outline', () => this.addNotice())
      ForEach(this.notices, (id: number) => {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            this.title(this.node.heading ?? this.label(), 14, true)
            if (this.node.detail) { this.title(this.node.detail, 13, false, true) }
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          if (this.node.action) { this.btn(this.node.action, 'primary', () => { this.onAction(this.path, this.node.action!); this.removeNotice(id); }) }
        }.width('100%').constraintSize({ maxWidth: 356 }).padding(12).backgroundColor(C.card).border({ width: 1, color: C.border, radius: 10 })
      }, (id: number) => String(id))
    }.alignItems(HorizontalAlign.End)
  }
  @Builder
  private overlayControl() {
    if (this.is('date-picker')) {
      Column({ space: 6 }) {
        if (this.node.label) { this.title(this.label(), 14, true) }
        Button({ type: ButtonType.Normal }) {
          Text(this.val() || this.node.placeholder || 'Pick a date').fontFamily('Geist').fontSize(14)
            .fontColor(C.foreground).textAlign(TextAlign.Start).width('100%')
        }.width('100%').constraintSize({ minHeight: 32 }).padding({ left: 10, right: 10 })
        .border({ width: 1, color: C.inputBorder, radius: 10 }).backgroundColor(C.input).onClick(() => this.showOverlay())
      }.width('100%').alignItems(HorizontalAlign.Start)
      .bindPopup(this.open, { builder: this.calendar, placement: Placement.Bottom, enableArrow: false, popupColor: C.card,
        onStateChange: (e) => { this.open = e.isVisible; } })
    } else if (this.is('popover', 'tooltip', 'hover-card')) {
      Row() { this.btn(this.label(), this.is('hover-card') ? 'ghost' : 'outline', () => this.showOverlay()) }
        .onHover((hovered: boolean) => { if (!this.is('popover')) this.open = hovered; })
        .bindPopup(this.open, { builder: this.details, placement: Placement.Bottom, width: this.is('tooltip') ? 120 : 256,
          enableArrow: this.is('tooltip'), popupColor: C.card, onStateChange: (e) => { this.open = e.isVisible; } })
    } else if (this.is('toast')) {
      Column({ space: 10 }) {
        this.btn(this.label(), 'outline', () => this.showOverlay())
        if (this.open) { this.details() }
      }
    } else {
      Row() { this.btn(this.label(), this.is('drawer') ? 'secondary' : 'outline', () => this.showOverlay()) }
        .bindSheet(this.open, this.details(), { height: SheetSize.FIT_CONTENT, showClose: false, backgroundColor: C.card,
          preferType: this.is('alert-dialog', 'dialog') ? SheetType.CENTER : SheetType.BOTTOM,
          onDisappear: () => { this.open = false; } })
    }
  }

  @Builder
  private message() {
    if (this.is('marker')) {
      Row({ space: 8 }) {
        if (this.node.variant === 'separator') { Divider().color(C.border).layoutWeight(1) }
        this.title(this.label(), 14, false, true)
        if (this.node.variant === 'separator') { Divider().color(C.border).layoutWeight(1) }
      }.width('100%').constraintSize({ minHeight: 20 }).justifyContent(FlexAlign.Center)
    } else if (this.is('message')) {
      Column({ space: 10 }) {
        if (this.node.label) { Text(this.label()).fontFamily('GeistMedium').fontSize(12).lineHeight(16).fontColor(C.mutedForeground).padding({ left: 12, right: 12 }) }
        this.children()
        if (this.node.detail) { Text(this.node.detail).fontFamily('Geist').fontSize(12).lineHeight(16).fontColor(C.mutedForeground).padding({ left: 12, right: 12 }) }
      }.alignItems(this.node.align === 'end' ? HorizontalAlign.End : HorizontalAlign.Start).width('100%')
    } else {
      Row() {
        Text(this.label()).fontFamily('Geist').fontSize(14).lineHeight(22.75)
          .constraintSize({ maxWidth: this.node.variant === 'ghost' ? '100%' : '80%' })
          .fontColor(this.node.variant === 'ghost' || this.node.variant === 'muted' || this.node.variant === 'secondary' ? C.foreground : Color.White)
          .backgroundColor(this.node.variant === 'muted' || this.node.variant === 'secondary' ? C.muted : this.node.variant === 'ghost' ? Color.Transparent : $r('app.color.aie_shadcn_bubble'))
          .padding(this.node.variant === 'ghost' ? 0 : { left: 13, right: 13, top: 11, bottom: 11 }).borderRadius(24)
      }
      .width('100%').justifyContent(this.node.align === 'end' ? FlexAlign.End : FlexAlign.Start)
    }
  }

  @Builder
  private card() {
    Column({ space: 16 }) {
      Row({ space: 4 }) {
        Column({ space: 4 }) {
          if (this.node.label) { this.title(this.label(), 16, true) }
          if (this.node.detail) { this.title(this.node.detail, 14, false, true) }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (this.node.action) { this.btn(this.node.action, 'ghost', () => this.onAction(this.path, this.node.action!)) }
      }.width('100%').padding({ left: 16, right: 16 })
      Column({ space: 24 }) { this.children() }.padding({ left: 16, right: 16 }).width('100%')
      if (this.opts().length > 0) {
        Column({ space: 8 }) {
          AISeparator()
          ForEach(this.opts(), (item: AIShadcnItem, i: number) => {
            Button(item.label, { type: ButtonType.Normal }).width('90%').height(32).fontFamily('GeistMedium').fontSize(14)
              .fontColor(i === 0 ? C.onPrimary : C.foreground).backgroundColor(i === 0 ? C.primary : C.background)
              .border({ width: i === 0 ? 0 : 1, color: C.inputBorder, radius: 10 }).enabled(!item.disabled).onClick(() => this.onAction(this.path, this.itemKey(item)))
          }, (item: AIShadcnItem) => this.itemKey(item))
        }.width('100%').padding({ bottom: 16 }).backgroundColor(C.muted)
      }
    }.padding({ top: 16, bottom: this.opts().length ? 0 : 16 }).width('100%').clip(true)
    .border({ width: 1, color: C.border, radius: 14 }).borderRadius(14).backgroundColor(C.card)
  }

  private slideCount(): number { return Math.max(this.opts().length, this.parts().length); }
  private slide(): number { return Math.max(0, Math.min(this.slideCount() - 1, this.number(0))); }
  private move(delta: number): void { this.set(String(Math.max(0, Math.min(this.slideCount() - 1, this.slide() + delta)))); }
  private slideWidth(): number { return Math.max(1, Math.min(312, (this.panelWidth || 360) - 48)); }

  @Builder
  private carousel() {
    Stack() {
      Stack() {
        if (this.slide() < this.parts().length) { this.child(this.slide()) }
        else if (this.opts().length) { this.title(this.opts()[this.slide()].label, 36, true) }
      }.width(this.slideWidth()).height(this.node.height ?? this.slideWidth() + 32).border({ width: 1, color: C.border, radius: 14 }).backgroundColor(C.card)
      .gesture(PanGesture({ direction: PanDirection.Horizontal }).onActionEnd((e: GestureEvent) => {
        if (Math.abs(e.offsetX) > 20) this.move(e.offsetX < 0 ? 1 : -1);
      }))
      Row() {
        this.iconButton(AIIcons.arrowLeft, 'Previous slide', () => this.move(-1), this.slide() > 0)
        Blank()
        this.iconButton(AIIcons.arrowRight, 'Next slide', () => this.move(1), this.slide() + 1 < this.slideCount())
      }.width('100%')
    }.width('100%').padding({ top: 4, bottom: 4 }).onAreaChange((_old: Area, next: Area) => { this.panelWidth = Number(next.width); })
  }
  @Builder
  private resizable() {
    Row() {
      Stack() { if (this.parts().length > 0) { this.child(0) } }.width(String(Math.max(10, Math.min(90, this.number(50)))) + '%')
      Stack() {
        Divider().vertical(true).height('100%').color(C.border)
        AIIcon({ icon: AIIcons.gripVertical, iconSize: 12 }).backgroundColor(C.background)
      }.width(12).height('100%').accessibilityText('Resize panels')
      .gesture(PanGesture({ direction: PanDirection.Horizontal }).onActionStart(() => { this.dragOrigin = this.number(50); })
        .onActionUpdate((e: GestureEvent) => this.set(String(Math.round(Math.max(10, Math.min(90, this.dragOrigin + e.offsetX / Math.max(1, this.panelWidth) * 100)))))))
      Stack() { if (this.parts().length > 1) { this.child(1) } }.layoutWeight(1)
    }.width('100%').height(this.node.height ?? 200).onAreaChange((_old: Area, next: Area) => { this.panelWidth = Number(next.width); })
    .border({ width: 1, color: C.border, radius: 9 })
  }
  @Builder
  private questionnaire() {
    Column({ space: 12 }) {
      if (this.page < this.parts().length) {
        Row() {
          this.title('Question ' + String(this.page + 1) + ' of ' + String(this.parts().length), 12, true, true)
          Blank()
          if (this.parts()[this.page].heading) { this.title('Current checkpoint: ' + this.parts()[this.page].heading, 14, false, true) }
        }.width('100%')
        Column({ space: 4 }) {
          this.title(this.parts()[this.page].label ?? '', 16, true)
          if (this.parts()[this.page].detail) { this.title(this.parts()[this.page].detail!, 14, false, true) }
        }.alignItems(HorizontalAlign.Start)
        Column({ space: 8 }) {
          ForEach(this.parts()[this.page].items ?? [], (item: AIShadcnItem) => {
            Row({ space: 10 }) {
              Stack() {
                Circle().width(16).height(16).fill(C.background).stroke(this.childValue(this.page) === this.itemKey(item) ? C.primary : C.inputBorder).strokeWidth(1)
                if (this.childValue(this.page) === this.itemKey(item)) { Circle().width(8).height(8).fill(C.primary) }
              }
              this.title(item.label)
            }.width('100%').constraintSize({ minHeight: 44 }).padding({ left: 12, right: 12 })
            .border({ width: 1, radius: 10, color: C.inputBorder }).backgroundColor(this.childValue(this.page) === this.itemKey(item) ? C.muted : C.input)
            .enabled(!item.disabled).focusable(true).accessibilityGroup(true).accessibilityText(item.label)
            .accessibilityDescription(this.childValue(this.page) === this.itemKey(item) ? 'Selected' : 'Unselected')
            .onClick(() => { const key = this.childID(this.page); this.store.set(key, this.itemKey(item)); this.onAction(key, this.itemKey(item)); this.requiredError = false; })
          }, (item: AIShadcnItem) => this.itemKey(item))
        }
        if (this.requiredError) { this.title('Select an answer to continue.', 12) }
        Row({ space: 8 }) {
          if (this.page > 0) { this.btn('Back', 'outline', () => { this.page--; this.requiredError = false; }) }
          Blank()
          this.btn(this.page + 1 === this.parts().length ? 'Submit' : 'Next', 'primary', () => {
            if (!this.parts()[this.page].items?.some((item: AIShadcnItem) => !item.disabled && this.itemKey(item) === this.childValue(this.page))) {
              this.requiredError = true; return;
            }
            this.page++;
            if (this.page === this.parts().length) this.onAction(this.path, 'submit');
          })
        }.width('100%')
      } else {
        this.title('Answers submitted', 16, true)
        this.btn('Start again', 'outline', () => {
          this.parts().forEach((question: AIShadcnNode, index: number) => {
            const key = this.childID(index), previous = this.store.values.get(key);
            this.store.remove(key);
            if (previous !== undefined && previous !== (question.value ?? '')) this.onAction(key, question.value ?? '');
          });
          this.requiredError = false; this.page = 0;
        })
      }
    }.alignItems(HorizontalAlign.Start).width('100%')
  }

  private visibleColumns(): AITableColumn[] {
    return (this.node.columns ?? []).map((title: string, i: number): AITableColumn =>
      ({ key: String(i), label: title, trailing: title === 'Amount', emphasized: this.is('table') && i === 0 }))
      .filter((column: AITableColumn) => this.store.values.get(this.path + '/hide/' + column.key) !== 'true');
  }
  private orderedRows(): ShadcnTableRow[] {
    return shadcnTableRows(this.node.rows ?? [], this.node.rowIDs, this.query, this.sortColumn, this.ascending, this.node.filterColumn);
  }
  private currentPage(count: number): number {
    return Math.min(this.page, Math.max(0, Math.ceil(count / 5) - 1));
  }
  private tableRows(): ShadcnTableRow[] {
    const rows = this.orderedRows(), start = this.currentPage(rows.length) * 5;
    const slice = this.is('data-table') ? rows.slice(start, start + 5) : rows;
    const columns = this.visibleColumns();
    return slice.map((row: ShadcnTableRow): ShadcnTableRow =>
      ({ id: row.id, index: row.index, cells: columns.map((col: AITableColumn) => row.cells[Number(col.key)] ?? '') }));
  }
  private footer(): string[] {
    if (!this.opts().length) return [];
    return this.visibleColumns().map((col: AITableColumn) =>
      col.key === '0' ? this.opts()[0].label : Number(col.key) === (this.node.columns?.length ?? 0) - 1 ? this.opts()[0].detail ?? '' : '');
  }
  private staticTableColumns(): AITableColumn[] {
    const columns = this.visibleColumns();
    const rows = this.node.rows ?? [], footer = this.footer();
    const ui = this.getUIContext(), measure = ui.getMeasureUtils();
    const textWidth = (text: string, medium: boolean): number =>
      Math.ceil(ui.px2vp(measure.measureText({ textContent: text, fontFamily: medium ? 'GeistMedium' : 'Geist', fontSize: 14 })));
    let total = 0;
    columns.forEach((col: AITableColumn, i: number) => {
      const index = Number(col.key);
      let width = Math.max(textWidth(col.label, true), textWidth(footer[i] ?? '', true));
      rows.forEach((row: string[]) => { width = Math.max(width, textWidth(row[index] ?? '', Boolean(col.emphasized))); });
      col.width = Math.max(i === 0 ? 100 : 0, width + 16);
      total += col.width;
    });
    const extra = Math.max(0, this.panelWidth - total) / Math.max(1, columns.length);
    columns.forEach((col: AITableColumn) => { col.width = (col.width ?? 0) + extra; });
    return columns;
  }
  @Builder
  private columnMenu() {
    Menu() {
      ForEach(this.node.columns ?? [], (title: string, i: number) => {
        MenuItem({ content: title }).onClick(() => {
          const k = this.path + '/hide/' + i;
          this.store.set(k, String(this.store.values.get(k) !== 'true'));
        })
        MenuItem({ content: 'Sort by ' + title }).onClick(() => {
          this.ascending = this.sortColumn === i ? !this.ascending : true; this.sortColumn = i; this.page = 0;
        })
      }, (title: string) => title)
    }
  }
  private rowFlag(id: string): string { return this.path + '/row/' + id; }
  private selectedRow(id: string): boolean { return this.store.values.get(this.rowFlag(id)) === 'true'; }
  private setRow(id: string, flag: boolean): void { this.store.set(this.rowFlag(id), String(flag)); this.onAction(this.rowFlag(id), String(flag)); }
  private allSelected(): boolean { const rows = this.tableRows(); return rows.length > 0 && rows.every((r: AITableRow) => this.selectedRow(r.id)); }
  private selectedCount(): number { return this.orderedRows().filter((r: ShadcnTableRow) => this.selectedRow(r.id)).length; }
  private cellWidth(label: string): number { return label === 'Email' ? 180 : label === 'Status' ? 78 : 88; }
  @Builder
  private gridCheck(selected: boolean, label: string, action: () => void, mixed: boolean = false) {
    Stack() {
      if (selected) { AIIcon({ icon: AIIcons.check, iconSize: 12, color: C.onPrimary }) }
      else if (mixed) { Rect().width(8).height(2).radius(1).fill(C.onPrimary) }
    }.width(16).height(16).backgroundColor(selected || mixed ? C.primary : C.input).border({ width: 1, color: C.inputBorder, radius: 4 })
    .focusable(true).accessibilityText(label).accessibilityDescription(mixed ? 'Mixed' : selected ? 'Selected' : 'Unselected').onClick(action)
  }
  @Builder
  private rowMenu(id: string) {
    Menu() { MenuItem({ content: 'View details' }).onClick(() => this.onAction(this.rowFlag(id), 'details')) }
  }
  @Builder
  private dataGrid() {
    Scroll() {
      Column() {
        Row({ space: 8 }) {
          this.gridCheck(this.allSelected(), 'Select all rows on this page', () => {
            const next = !this.allSelected(); this.tableRows().forEach((r: AITableRow) => this.setRow(r.id, next));
          }, !this.allSelected() && this.tableRows().some((r: ShadcnTableRow) => this.selectedRow(r.id)))
          ForEach(this.visibleColumns(), (col: AITableColumn) => {
            Row({ space: 4 }) {
              this.title(col.label, 14, true)
              if (col.label === 'Email' || this.sortColumn === Number(col.key)) { AIIcon({ icon: AIIcons.chevronsUpDown, iconSize: 12 }) }
            }.width(this.cellWidth(col.label)).justifyContent(col.trailing ? FlexAlign.End : FlexAlign.Start).focusable(true)
            .onClick(() => { const i = Number(col.key); this.ascending = this.sortColumn === i ? !this.ascending : true; this.sortColumn = i; this.page = 0; })
          }, (col: AITableColumn) => col.key)
          Blank().width(28)
        }.constraintSize({ minHeight: 40 }).padding({ left: 8, right: 8 })
        ForEach(this.tableRows(), (row: ShadcnTableRow) => {
          Row({ space: 8 }) {
            this.gridCheck(this.selectedRow(row.id), 'Select row ' + String(row.index + 1), () => this.setRow(row.id, !this.selectedRow(row.id)))
            ForEach(this.visibleColumns(), (col: AITableColumn, i: number) => {
              Text(row.cells[i] ?? '').fontFamily('Geist').fontSize(14).fontColor(C.foreground)
                .width(this.cellWidth(col.label)).textAlign(col.trailing ? TextAlign.End : TextAlign.Start)
            }, (col: AITableColumn) => col.key)
            Button({ type: ButtonType.Normal }) { AIIcon({ icon: AIIcons.ellipsis }) }.width(28).height(28)
              .backgroundColor(Color.Transparent).padding(4).accessibilityText('Row actions').bindMenu(this.rowMenu(row.id))
          }.constraintSize({ minHeight: 41 }).padding({ left: 8, right: 8 })
          .backgroundColor(this.selectedRow(row.id) ? C.muted : Color.Transparent).border({ width: { top: 1 }, color: C.border })
        }, (row: ShadcnTableRow) => JSON.stringify([row.id, String(row.index)].concat(row.cells, this.visibleColumns().map((col: AITableColumn) => col.key))))
        if (!this.tableRows().length) { this.title('No results.') }
      }.alignItems(HorizontalAlign.Start)
    }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).border({ width: 1, radius: 8, color: C.border }).clip(true)
  }
  @Builder
  private table() {
    Column({ space: 0 }) {
      if (this.is('data-table')) {
        Row({ space: 8 }) {
          TextInput({ text: this.query, placeholder: this.node.placeholder }).fontSize(14).fontFamily('Geist').fontColor(C.foreground)
            .height(32).backgroundColor(C.input).border({ width: 1, color: C.inputBorder, radius: 10 }).layoutWeight(1)
            .onChange((v: string) => { this.query = v; this.page = 0; })
          Button('Columns', { type: ButtonType.Normal }).height(32).fontFamily('GeistMedium').fontSize(14).fontColor(C.foreground)
            .backgroundColor(C.background).border({ width: 1, color: C.border, radius: 10 }).bindMenu(this.columnMenu)
        }.width('100%').padding({ top: 16, bottom: 16 })
      }
      if (this.is('data-table')) { this.dataGrid() }
      else if (this.visibleColumns().length) {
        AITable({ columns: this.staticTableColumns(), rows: this.tableRows(), caption: this.node.detail ?? '', footer: this.footer(), compact: true })
      }
      if (this.is('data-table')) {
        Row({ space: 8 }) {
          this.title(String(this.selectedCount()) + ' of ' + String(this.orderedRows().length) + ' row(s) selected.', 12, false, true)
          Blank()
          this.btn('Previous', 'outline', () => { this.page = this.currentPage(this.orderedRows().length) - 1; }, this.currentPage(this.orderedRows().length) > 0)
          this.btn('Next', 'outline', () => { this.page = this.currentPage(this.orderedRows().length) + 1; }, (this.currentPage(this.orderedRows().length) + 1) * 5 < this.orderedRows().length)
        }.padding({ top: 14, bottom: 14 })
      }
    }.alignItems(HorizontalAlign.Start).width('100%')
    .onSizeChange((_old: SizeOptions, size: SizeOptions) => { if (this.is('table')) this.panelWidth = Number(size.width); })
  }

  private series(): AIChartSeries[] { return (this.node.columns ?? []).slice(1).map((label: string, i: number): AIChartSeries => ({ key: String(i), label: label })); }
  private chartData(): AIChartRow[] { return (this.node.rows ?? []).map((row: string[]): AIChartRow =>
    ({ label: row[0] ?? '', values: row.slice(1).map((v: string) => Number(v) || 0) })); }
  @Builder
  private chartBody() {
    AIChart({ series: this.series(), data: this.chartData(), label: this.label(), compactPlot: true, kind: this.node.variant === 'line' ? AIChartKind.Line :
      this.node.variant === 'area' ? AIChartKind.Area : AIChartKind.Bar, onSelect: (row: AIChartRow) => this.set(row.label) })
  }
  @Builder
  private navMenu(menu: AIShadcnNode, i: number) {
    Menu() {
      ForEach(menu.items ?? [], (item: AIShadcnItem) => {
        MenuItem({ content: item.label }).enabled(!item.disabled).onClick(() => {
          this.store.set(this.childID(i), this.itemKey(item)); this.onAction(this.childID(i), this.itemKey(item));
        })
      }, (item: AIShadcnItem) => this.itemKey(item))
    }
  }
  @Builder
  private navigation() {
    if (this.is('sidebar')) {
      Column({ space: 4 }) {
        Row() {
          if (!this.open) { Text(this.label()).fontFamily('GeistMedium').fontColor(C.mutedForeground).fontSize(12).layoutWeight(1) }
          this.iconButton(AIIcons.panelLeft, 'Toggle sidebar', () => { this.open = !this.open; })
        }
        ForEach(this.opts(), (item: AIShadcnItem) => {
          Row({ space: 8 }) {
            this.glyph(item.icon ?? 'circle')
            if (!this.open) { this.title(item.label) }
          }.width('100%').constraintSize({ minHeight: 32 }).padding({ left: 8, right: 8 }).borderRadius(7)
          .backgroundColor(this.val() === this.itemKey(item) ? C.input : Color.Transparent).focusable(true)
          .enabled(!item.disabled).accessibilityText(item.label).onClick(() => this.set(this.itemKey(item)))
        }, (item: AIShadcnItem) => this.itemKey(item))
      }.width(this.open ? 48 : '100%').padding(8).alignItems(HorizontalAlign.Start).backgroundColor(C.muted)
    } else {
      Row() { ShadcnFlow({ rtl: this.rtl, gap: 2 }) {
        ForEach(this.parts(), (menu: AIShadcnNode, i: number) => {
          if (menu.kind === 'button') { this.child(i) } else { Row({ space: 4 }) {
            this.title(menu.label ?? '', 14, true)
            if (this.is('navigation-menu')) { AIIcon({ icon: AIIcons.chevronDown, iconSize: 12 }) }
          }.padding({ left: 6, right: 6 }).constraintSize({ minHeight: 26 }).focusable(true).bindMenu(this.navMenu(menu, i)) }
        }, (menu: AIShadcnNode, i: number) => menu.id ?? String(i))
      } }.padding(3).border({ width: this.is('menubar') ? 1 : 0, color: C.border, radius: 10 })
    }
  }

  @Builder
  private visual() {
    if (this.is('column')) {
      Column({ space: this.node.gap ?? 8 }) { this.children() }
      .alignItems(this.node.align === 'center' ? HorizontalAlign.Center : HorizontalAlign.Start)
    } else if (this.is('row')) {
      ShadcnFlow({ rtl: this.rtl, gap: this.node.gap ?? 8 }) { this.children() }
    } else if (this.is('text', 'typography')) {
      this.title(this.label(), this.textSize(), ['label', 'semibold', 'h1', 'h2', 'h3', 'h4'].includes(this.node.variant ?? ''), this.node.variant === 'muted')
    } else if (this.is('image')) {
      if (this.image(this.val())) {
        Stack() {
          Image(this.image(this.val())).objectFit(ImageFit.Cover).width('100%').height('100%')
          if (this.val() === 'shadcn-aspect') { Rect().width('100%').height('100%').fill($r('app.color.aie_shadcn_photo_scrim')) }
        }.width('100%').height('100%').accessibilityText(this.label())
      }
    } else if (this.is('aspect-ratio')) {
      Stack() { this.children() }.width('100%').aspectRatio(Math.max(0.01, this.number(16 / 9))).borderRadius(10).clip(true)
    } else if (this.is('avatar')) {
      Stack() {
        this.title(this.val(), 14, true)
        if (this.image(this.node.asset ?? '')) { Image(this.image(this.node.asset ?? '')).width('100%').height('100%').objectFit(ImageFit.Cover) }
      }.width(this.node.size ?? 32).height(this.node.size ?? 32).borderRadius((this.node.size ?? 32) / 2)
      .backgroundColor(C.muted).clip(true).accessibilityText(this.label())
    } else if (this.is('accordion', 'collapsible')) { this.disclosure() }
    else if (this.is('alert', 'item', 'attachment')) { this.information() }
    else if (this.is('badge')) { AIBadge({ text: this.label(), variant: this.node.variant ?? 'primary' }) }
    else if (this.is('button')) { this.btn(this.label(), this.node.variant ?? 'primary', () => this.onAction(this.path, this.label())) }
    else if (this.is('button-group', 'toggle-group', 'tabs', 'breadcrumb', 'pagination')) { this.segments() }
    else if (this.is('bubble', 'marker', 'message')) { this.message() }
    else if (this.is('calendar')) { this.calendar() }
    else if (this.is('card')) { this.card() }
    else if (this.is('carousel')) { this.carousel() }
    else if (this.is('chart')) { AICard({ title: this.label(), description: this.node.detail ?? '', footer: this.node.action ?? '',
      footnote: this.node.placeholder ?? '', trending: true, chartStyle: true, content: () => { this.chartBody(); } }) }
    else if (this.is('code-block')) {
      if (this.node.action) { AICodeBlock({ code: this.val() }) }
      else {
        Scroll() {
          Column() {
            ForEach(this.val().split('\n'), (line: string) => {
              Text(line || ' ').fontFamily('GeistMono').fontSize(14).fontColor(C.foreground).constraintSize({ minHeight: 22.75 })
                .maxLines(1).copyOption(CopyOptions.InApp)
            }, (_line: string, i: number) => String(i))
          }.padding(16).alignItems(HorizontalAlign.Start)
        }.width('100%').align(Alignment.Start).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).backgroundColor(C.muted).borderRadius(14)
      }
    }
    else if (this.is('combobox', 'command', 'select', 'native-select', 'dropdown-menu', 'context-menu')) { this.choice() }
    else if (this.is('sonner')) { this.sonner() }
    else if (this.is('date-picker', 'dialog', 'alert-dialog', 'drawer', 'sheet', 'tooltip', 'hover-card', 'popover', 'toast')) { this.overlayControl() }
    else if (this.is('direction')) { Column({ space: 6 }) {
      if (this.node.variant === 'picker' && this.opts().length) {
        Button(this.opts()[this.language()].label, { type: ButtonType.Normal }).height(28).fontFamily('GeistMedium')
          .fontSize(14).fontColor(C.foreground).backgroundColor(Color.Transparent).bindMenu(this.menuItems)
      }
      Column() {
        if (this.opts().length && this.parts().length > this.language()) { this.child(this.language()) }
        else { this.children() }
      }.direction((this.opts()[this.language()]?.detail ?? this.val()) === 'rtl' ? Direction.Rtl : Direction.Ltr)
    }.alignItems(HorizontalAlign.End) }
    else if (this.is('empty')) { Column({ space: 12 }) {
      if (this.node.icon) { Stack() { this.glyph(this.node.icon, 24) }.width(40).height(40).borderRadius(10).backgroundColor(C.muted) }
      this.title(this.label(), 18, true)
      Text(this.node.detail ?? '').fontFamily('Geist').fontSize(14).fontColor(C.mutedForeground).textAlign(TextAlign.Center)
      this.children()
      if (this.node.action) { this.btn(this.node.action, 'outline', () => this.onAction(this.path, this.node.action!)) }
    }.width('100%').padding(24).border({ width: 1, radius: 14, color: C.border, style: BorderStyle.Dashed }) }
    else if (this.is('checkbox', 'label', 'field', 'input', 'input-group', 'input-otp', 'radio-group', 'slider', 'textarea', 'toggle')) { this.form() }
    else if (this.is('kbd')) { Text(this.label()).fontFamily('GeistMedium').fontSize(12).fontColor(C.mutedForeground)
      .constraintSize({ minWidth: 20, minHeight: 20 }).padding({ left: 4, right: 4 }).textAlign(TextAlign.Center).backgroundColor(C.muted).borderRadius(5) }
    else if (this.is('menubar', 'navigation-menu', 'sidebar')) { this.navigation() }
    else if (this.is('message-scroller')) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Scroll(this.scroller) {
          Column({ space: 16 }) { this.children() }.width('100%').padding(20)
        }.height('100%').width('100%').scrollBar(BarState.Auto).onAppear(() => { if (this.node.align !== 'start') this.scroller.scrollEdge(Edge.Bottom); }).onDidScroll((): void => { this.atEnd = this.scroller.isAtEnd(); })
        if (!this.atEnd) { this.iconButton(AIIcons.arrowDown, 'Jump to latest', (): void => { this.scroller.scrollEdge(Edge.Bottom); }) }
      }.width('100%').height(this.node.height ?? 300)
    } else if (this.is('progress')) { AIProgress({ value: this.number(0), label: this.label(), strokeWidth: 4 }) }
    else if (this.is('questionnaire')) { this.questionnaire() }
    else if (this.is('resizable')) { this.resizable() }
    else if (this.is('scroll-area')) {
      Scroll() { Column() {
        if (this.node.label) { Text(this.label()).fontFamily('GeistMedium').fontSize(14).fontColor(C.foreground).margin({ bottom: 16 }) }
        ForEach(this.opts(), (item: AIShadcnItem) => { this.title(item.label); Divider().color(C.border).margin({ top: 8, bottom: 8 }) },
          (item: AIShadcnItem) => this.itemKey(item))
        this.children()
      }.alignItems(HorizontalAlign.Start).width('100%').padding(16) }
      .width('100%').height(this.node.height ?? 288).scrollBar(BarState.Auto).border({ width: 1, color: C.border, radius: 8 })
    } else if (this.is('separator')) { AISeparator() }
    else if (this.is('skeleton')) { Rect().width('100%').height(this.node.height ?? 16).radius(6).fill(C.muted) }
    else if (this.is('spinner')) { ShadcnSpinner({ iconSize: this.node.size ?? 16 }) }
    else if (this.is('switch')) { Row({ space: 8 }) {
      Toggle({ type: ToggleType.Switch, isOn: this.val() === 'true' }).width(32).height(19).selectedColor(C.primary)
        .accessibilityText(this.label()).onChange((v: boolean) => this.set(String(v)))
      this.title(this.label(), 14, true)
    } }
    else if (this.is('table', 'data-table')) { this.table() }
    else if (this.is('trace')) { AITraceLine({ title: this.label(), detail: this.node.detail ?? '', icon: icons[this.node.icon ?? ''] ?? AIIcons.circleCheck }) }
  }

  build() {
    Column() { this.visual() }
      .width(this.node.width ? '100%' : 'auto').constraintSize({ maxWidth: this.node.width }).alignItems(HorizontalAlign.Start)
  }
}
