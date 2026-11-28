import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { AIColors, AIIcon, AIIconButton, AIIcons, AIInput, AISeparator, AIText,
  AIShadcnView, AIShadcnNode, AIShadcnExample, loadAIShadcnCatalog, registerAIElementsFonts } from '@aielements/arkui';
import { GalleryExample, foundations, patterns, streaming } from './Catalog';
import { ChatDemo, PatternDemo } from './PatternDemo';
import { StreamDemo } from './StreamDemo';

const defaultExample: GalleryExample = { id: 'chat', title: 'Chat' };
const emptySelection: GalleryExample = { id: '', title: '' };

@Entry
@Component
struct Index {
  @State selected: GalleryExample = emptySelection;
  @State query: string = '';
  @State private shadcn: AIShadcnExample[] = [];
  @State private catalogError: string = '';
  @State wide: boolean = false;
  @State short: boolean = false;
  @State appearance: string = 'System';
  @State appearanceError: string = '';

  aboutToAppear(): void {
    try {
      this.shadcn = loadAIShadcnCatalog();
    } catch (error) { this.catalogError = String(error); }
    try {
      registerAIElementsFonts();
    } catch (error) {
      console.warn('AIElements fonts could not be loaded: ' + String(error));
    }
  }

  onBackPress(): boolean {
    if (!this.selected.id) return false;
    this.selected = emptySelection;
    return true;
  }

  private chooseAppearance(value: string): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const mode = value === 'Dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK :
        value === 'Light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT :
          ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
      context.getApplicationContext().setColorMode(mode);
      this.appearance = value;
      this.appearanceError = '';
    } catch {
      this.appearanceError = 'Could not change appearance.';
    }
  }

  private matches(items: GalleryExample[]): GalleryExample[] {
    const query = this.query.trim().toLowerCase();
    return items.filter((item: GalleryExample) => item.title.toLowerCase().includes(query));
  }

  private shadcnEntries(): GalleryExample[] {
    return this.shadcn.map((e: AIShadcnExample): GalleryExample => ({ id: 'shadcn/' + e.id, title: e.title }));
  }

  private previewNode(entry: AIShadcnExample): AIShadcnNode {
    if (entry.id !== 'direction') return entry.root;
    return { kind: 'direction', label: entry.root.label, value: entry.root.value,
      items: entry.root.items, children: entry.root.children, variant: 'picker' };
  }

  private openExample(): GalleryExample[] {
    return [this.selected.id ? this.selected : defaultExample];
  }

  @Builder
  private group(title: string, items: GalleryExample[]) {
    if (this.matches(items).length > 0) {
      if (title) {
        ListItem() {
          Text(title).fontFamily('GeistMedium').fontSize(12).fontColor(AIColors.mutedForeground)
            .padding({ left: 8, top: 12, bottom: 4 })
        }
      }
      ForEach(this.matches(items), (item: GalleryExample) => {
        ListItem() {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Row({ space: 8 }) {
              AIText({ text: item.title }).layoutWeight(1)
              AIIcon({ icon: AIIcons.chevronRight })
            }.width('100%').padding({ left: 10, right: 10, top: 6, bottom: 6 })
          }
          .width('100%')
          .constraintSize({ minHeight: 46 })
          .borderRadius(8)
          .backgroundColor(this.wide && (this.selected.id || defaultExample.id) === item.id ?
            AIColors.muted : Color.Transparent)
          .accessibilityText(item.title)
          .onClick(() => { this.selected = item; })
        }
      }, (item: GalleryExample) => item.id)
    }
  }

  @Builder
  private appearanceMenu() {
    Menu() {
      ForEach(['System', 'Light', 'Dark'], (value: string) => {
        MenuItem({ content: value })
          .selected(this.appearance === value)
          .onChange(() => this.chooseAppearance(value))
      })
    }
  }

  @Builder
  private catalog() {
    Column() {
      AIInput({ value: this.query, placeholder: 'Search components',
        onValueChange: value => { this.query = value; } }).padding({ left: 6, right: 6 })
      List() {
        this.group('', streaming)
        this.group('AI patterns', patterns)
        this.group('Foundation', foundations)
        this.group('shadcn/ui', this.shadcnEntries())
        if (this.catalogError) { ListItem() { AIText({ text: this.catalogError }) } }
        if (this.matches(patterns).length + this.matches(foundations).length + this.matches(streaming).length + this.matches(this.shadcnEntries()).length === 0) {
          ListItem() {
            AIText({ text: 'No components match your search.', variant: 'muted' }).padding(10)
          }
        }
      }.layoutWeight(1).width('100%')
    }.padding({ left: 12, right: 12, top: 12 }).height('100%')
  }

  @Builder
  private detail(item: GalleryExample) {
    Column({ space: 12 }) {
      if (this.wide) {
        Text(item.title).fontFamily('GeistSemibold').fontSize(22).fontColor(AIColors.foreground)
      }
      if (item.id === 'chat') {
        ChatDemo({ showHeader: !this.short }).layoutWeight(1)
      } else {
        Scroll() {
          Column({ space: 16 }) {
            if (item.id.startsWith('shadcn/')) {
              ForEach(this.shadcn.filter((e: AIShadcnExample) => 'shadcn/' + e.id === item.id), (entry: AIShadcnExample) => {
                AIText({ text: entry.summary, variant: 'muted' })
                AIShadcnView({ node: this.previewNode(entry) })
              }, (entry: AIShadcnExample) => entry.id)
            } else if (item.id === 'generative-ui' || foundations.some((example: GalleryExample) => example.id === item.id)) {
              StreamDemo({ example: item.id })
            } else {
              PatternDemo({ name: item.id })
            }
          }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 24 })
        }
        .align(Alignment.TopStart)
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 18, right: 18, top: 16 })
    .width('100%')
    .constraintSize({ maxWidth: 720 })
    .height('100%')
  }

  build() {
    Column() {
      Row({ space: 4 }) {
        if (!this.wide && this.selected.id) {
          AIIconButton({ icon: AIIcons.chevronRight, label: 'Back to components',
            onPress: () => { this.selected = emptySelection; } }).rotate({ angle: 180 })
        }
        Text(this.wide || !this.selected.id ? 'AIElements' : this.selected.title)
          .fontFamily('GeistSemibold')
          .fontSize(19)
          .fontColor(AIColors.foreground)
          .layoutWeight(1)
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          AIIcon({ icon: this.appearance === 'Dark' ? AIIcons.moon : AIIcons.sun, color: AIColors.foreground })
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .accessibilityText('Appearance: ' + this.appearance)
        .bindMenu(this.appearanceMenu())
      }
      .padding({ left: 12, right: 12, top: 4, bottom: 4 })
      .width('100%')
      AISeparator()
      if (this.appearanceError) {
        AIText({ text: this.appearanceError, color: AIColors.destructive }).padding(8)
      }
      Row() {
        if (this.wide || !this.selected.id) {
          Column() { this.catalog() }.width(this.wide ? 280 : '100%').height('100%')
        }
        if (this.wide) Divider().vertical(true).height('100%').color(AIColors.border)
        if (this.wide || this.selected.id) {
          Column() {
            ForEach(this.openExample(), (item: GalleryExample) => {
              this.detail(item)
            }, (item: GalleryExample) => item.id)
          }.height('100%').layoutWeight(1)
        }
      }.layoutWeight(1).width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AIColors.background)
    .onSizeChange((_previous, current) => {
      this.wide = Number(current.width) >= 760 && Number(current.height) >= 480;
      this.short = Number(current.height) < 480;
    })
  }
}
