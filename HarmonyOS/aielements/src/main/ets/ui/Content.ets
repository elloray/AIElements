import { common } from '@kit.AbilityKit';
import { AIColors, AIIcons } from './Theme';
import { AIButton, AIIcon, AIIconButton, AIOption, AIRow, AISelect, AIText } from './Primitives';
import { openAIWebLink } from './Chat';

export interface AIFileNode {
  id: string;
  name: string;
  children?: AIFileNode[];
}

interface AIFileRow {
  node: AIFileNode;
  depth: number;
}

@Component
export struct AIFileTree {
  @Prop nodes: AIFileNode[] = [];
  @Prop selection: string = '';
  @Prop expandedIDs: string[] = [];
  onExpand?: (ids: string[]) => void;
  onSelect?: (node: AIFileNode) => void;
  @State localIDs: string[] = [];

  private expanded(): string[] {
    return this.onExpand ? this.expandedIDs : this.localIDs;
  }

  private flatten(nodes: AIFileNode[], depth: number = 0): AIFileRow[] {
    const rows: AIFileRow[] = [];
    for (const node of nodes) {
      rows.push({ node, depth });
      if (node.children && this.expanded().includes(node.id)) {
        rows.push(...this.flatten(node.children, depth + 1));
      }
    }
    return rows;
  }

  private select(node: AIFileNode): void {
    if (node.children) {
      const ids = this.expanded();
      const next = ids.includes(node.id) ? ids.filter(id => id !== node.id) : ids.concat(node.id);
      if (this.onExpand) this.onExpand(next);
      else this.localIDs = next;
    } else {
      this.onSelect?.(node);
    }
  }

  build() {
    Column() {
      Repeat(this.flatten(this.nodes)).each((item: RepeatItem<AIFileRow>) => {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 8 }) {
            AIIcon({ icon: item.item.node.children ? (this.expanded().includes(item.item.node.id) ?
              AIIcons.chevronDown : AIIcons.chevronRight) : AIIcons.file })
            if (item.item.node.children) {
              AIIcon({ icon: this.expanded().includes(item.item.node.id) ? AIIcons.folderOpen : AIIcons.folder })
            }
            AIText({ text: item.item.node.name })
          }
          .width('100%')
          .padding({ left: 8 + Math.min(item.item.depth, 6) * 14, right: 8 })
        }
        .width('100%')
        .constraintSize({ minHeight: 44 })
        .borderRadius(6)
        .backgroundColor(this.selection === item.item.node.id ? AIColors.muted : Color.Transparent)
        .accessibilityText(item.item.node.name)
        .accessibilityDescription(item.item.node.children ?
          (this.expanded().includes(item.item.node.id) ? 'Expanded folder' : 'Collapsed folder') : 'File')
        .onClick(() => this.select(item.item.node))
      }).key((row: AIFileRow) => row.node.id)
    }.width('100%').padding(8).border({ radius: 12, width: 1, color: AIColors.border })
  }
}

export interface AISource {
  title: string;
  url: string;
  summary?: string;
}

@Component
export struct AISources {
  @Prop sources: AISource[] = [];
  @State open: boolean = false;
  @State error: string = '';

  private async visit(url: string): Promise<void> {
    try {
      await openAIWebLink(this.getUIContext().getHostContext() as common.UIAbilityContext, url);
      this.error = '';
    } catch {
      this.error = 'Unable to open the source.';
    }
  }

  build() {
    Column({ space: 4 }) {
      AIButton({ label: 'Sources · ' + this.sources.length, icon: this.open ? AIIcons.chevronDown : AIIcons.chevronRight,
        variant: 'ghost', active: this.sources.length > 0, onPress: () => { this.open = !this.open; } })
      if (this.open) {
        Repeat(this.sources).each((source: RepeatItem<AISource>) => {
          AIButton({ label: source.item.title, icon: AIIcons.arrowUpRight, variant: 'ghost',
            onPress: () => { void this.visit(source.item.url); } })
        }).key((source: AISource) => source.url)
        if (this.error) AIText({ text: this.error, color: AIColors.destructive })
      }
    }.alignItems(HorizontalAlign.Start)
  }
}

@Component
struct AICitationPreview {
  @Prop sources: AISource[] = [];
  @State index: number = 0;
  @State error: string = '';

  private current(): AISource | undefined {
    return this.sources[this.index];
  }

  private async visit(): Promise<void> {
    const source = this.current();
    if (!source) return;
    try {
      await openAIWebLink(this.getUIContext().getHostContext() as common.UIAbilityContext, source.url);
      this.error = '';
    } catch {
      this.error = 'Unable to open the source.';
    }
  }

  build() {
    Column({ space: 8 }) {
      if (this.current()) {
        AIText({ text: this.current()?.title ?? '', variant: 'title' })
        AIText({ text: this.current()?.url ?? '', variant: 'caption' })
        if (this.current()?.summary) AIText({ text: this.current()?.summary ?? '' })
        if (this.sources.length > 1) {
          Row({ space: 6 }) {
            AIIconButton({ icon: AIIcons.chevronRight, label: 'Previous source', active: this.index > 0,
              onPress: () => { this.index--; this.error = ''; } }).rotate({ angle: 180 })
            AIText({ text: (this.index + 1) + ' / ' + this.sources.length, variant: 'caption' })
            AIIconButton({ icon: AIIcons.chevronRight, label: 'Next source', active: this.index + 1 < this.sources.length,
              onPress: () => { this.index++; this.error = ''; } })
          }
        }
        AIButton({ label: 'Open source', icon: AIIcons.arrowUpRight, variant: 'outline',
          onPress: () => { void this.visit(); } })
        if (this.error) AIText({ text: this.error, color: AIColors.destructive })
      }
    }.alignItems(HorizontalAlign.Start).padding(20).width('100%')
  }
}

@Component
export struct AIInlineCitation {
  @Prop sources: AISource[] = [];
  @Prop title: string = 'Source';
  @State open: boolean = false;

  @Builder
  private preview() {
    AICitationPreview({ sources: this.sources })
  }

  build() {
    Row() {
      AIButton({ label: this.title + (this.sources.length > 1 ? ' +' + (this.sources.length - 1) : ''),
        icon: AIIcons.globe, variant: 'secondary', active: this.sources.length > 0, onPress: () => { this.open = true; } })
    }
    .bindSheet(this.open, this.preview(), {
      title: { title: 'Citation' },
      height: SheetSize.MEDIUM,
      showClose: true,
      onDisappear: () => { this.open = false; }
    })
  }
}

export interface AICitedPart {
  text: string;
  sources?: AISource[];
}

@Component
export struct AICitedText {
  @Prop parts: AICitedPart[] = [];
  @State open: boolean = false;
  @State activeSources: AISource[] = [];

  @Builder
  private preview() {
    AICitationPreview({ sources: this.activeSources })
  }

  private select(part: AICitedPart): void {
    if (!part.sources?.length) return;
    this.activeSources = part.sources;
    this.open = true;
  }

  build() {
    Text() {
      Repeat(this.parts).each((part: RepeatItem<AICitedPart>) => {
        if (part.item.sources?.length) {
          Span(part.item.text)
            .fontFamily('GeistMedium')
            .decoration({ type: TextDecorationType.Underline })
            .onClick(() => this.select(part.item))
        } else {
          Span(part.item.text)
        }
      })
    }
    .fontFamily('Geist')
    .fontSize(14)
    .fontColor(AIColors.foreground)
    .width('100%')
    .bindSheet(this.open, this.preview(), {
      title: { title: 'Citation' },
      height: SheetSize.MEDIUM,
      showClose: true,
      onDisappear: () => { this.open = false; }
    })
  }
}

export interface AIModel {
  id: string;
  name: string;
  provider: string;
}

@Component
export struct AIModelSelector {
  @Prop models: AIModel[] = [];
  @Prop selectedID: string = '';
  @Prop effort: string = '';
  onSelect: (id: string) => void = () => {};
  onEffortChange?: (effort: string) => void;
  private efforts: AIOption[] = [
    { value: 'Low', label: 'Low' }, { value: 'Medium', label: 'Medium' }, { value: 'High', label: 'High' }
  ];

  private choices(): AIOption[] {
    return this.models.map((model: AIModel): AIOption => ({
      value: model.id, label: model.provider ? model.name + ' · ' + model.provider : model.name
    }));
  }

  build() {
    Row({ space: 6 }) {
      AISelect({ options: this.choices(), value: this.selectedID, placeholder: 'Select model',
        onValueChange: this.onSelect }).layoutWeight(2)
      if (this.onEffortChange) {
        AISelect({ options: this.efforts, value: this.effort, placeholder: 'Effort',
          onValueChange: value => this.onEffortChange?.(value) }).layoutWeight(1)
      }
    }.width('100%')
  }
}

@Component
export struct AISuggestion {
  @Prop text: string = '';
  onSelect: (text: string) => void = () => {};

  build() {
    AIButton({ label: this.text, variant: 'outline', onPress: () => this.onSelect(this.text) })
  }
}

@Component
export struct AISuggestions {
  @Prop suggestions: string[] = [];
  onSelect: (text: string) => void = () => {};

  build() {
    AIRow() {
      Repeat(this.suggestions).each((suggestion: RepeatItem<string>) => {
        AISuggestion({ text: suggestion.item, onSelect: this.onSelect })
      })
    }
  }
}
