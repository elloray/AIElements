import { AIUIEvent, AIUIValue } from '../protocol/Models';
import { AIUIPhase } from '../protocol/Streaming';
import { AIUIStore } from '../protocol/Store';
import { AIBadge, AIButton, AICard, AIInput, AIProgress, AIRow, AISelect, AISeparator, AIStack, AISwitch,
  AIText } from './Primitives';
import { AIChart, AIChartKind, AIChartRow, AITable } from './DataDisplay';
import { AIColors } from './Theme';
import { AIUIDisplayNode, displaySurface } from './Surface';

@Component
struct RenderNode {
  @Prop node: AIUIDisplayNode = new AIUIDisplayNode('');
  @Prop failed: boolean = false;
  @Prop actionEnabled: boolean = false;
  onAction: (id: string, event: string, value: AIUIValue) => void = () => {};

  @Builder
  private children() {
    Repeat(this.node.children).each((child: RepeatItem<AIUIDisplayNode>) => {
      RenderNode({ node: child.item, failed: this.failed, actionEnabled: this.actionEnabled, onAction: this.onAction })
    }).key((child: AIUIDisplayNode) => child.id)
  }

  private editable(): boolean {
    return this.node.bound && !this.node.flag('disabled');
  }

  private select(row: AIChartRow): void {
    this.onAction(this.node.id, 'select', this.node.chartSelection(row));
  }

  @Builder
  private render() {
    if (this.node.type === 'Stack') {
      AIStack({ gap: this.node.number('gap', 12) }) { this.children() }
    } else if (this.node.type === 'Row') {
      AIRow({ gap: this.node.number('gap', 8) }) { this.children() }
    } else if (this.node.type === 'Card') {
      AICard({ title: this.node.text('title'), description: this.node.text('description'),
        footer: this.node.text('footer'), footnote: this.node.text('footnote'),
        chartStyle: this.node.text('style') === 'chart', trending: this.node.text('footerIcon') === 'trending-up' }) {
        AIStack({ gap: this.node.text('style') === 'chart' ? 24 : 16 }) { this.children() }
      }
    } else if (this.node.type === 'Text') {
      AIText({ text: this.node.text('text'), variant: this.node.text('variant', 'body') })
    } else if (this.node.type === 'Button') {
      AIButton({ label: this.node.text('label', 'Continue'), variant: this.node.text('variant', 'primary'),
        active: !this.failed && !this.node.flag('disabled') && this.node.hasPress && this.actionEnabled,
        onPress: () => this.onAction(this.node.id, 'press', null) })
    } else if (this.node.type === 'Badge') {
      AIBadge({ text: this.node.text('text'), variant: this.node.text('variant', 'secondary') })
    } else if (this.node.type === 'Input') {
      AIInput({ value: this.node.text('value'), label: this.node.text('label'), placeholder: this.node.text('placeholder'),
        active: this.editable(), onValueChange: value => this.onAction(this.node.id, 'change', value) })
    } else if (this.node.type === 'Select') {
      AISelect({ value: this.node.text('value'), label: this.node.text('label'),
        placeholder: this.node.text('placeholder', 'Select an option'), options: this.node.options(),
        active: this.editable(), onValueChange: value => this.onAction(this.node.id, 'change', value) })
    } else if (this.node.type === 'Switch') {
      AISwitch({ value: this.node.flag('value'), label: this.node.text('label', 'Switch'),
        active: this.editable(), onValueChange: value => this.onAction(this.node.id, 'change', value) })
    } else if (this.node.type === 'Progress') {
      AIProgress({ value: this.node.number('value', 0), total: this.node.number('max', 100),
        label: this.node.text('label') })
    } else if (this.node.type === 'Separator') {
      AISeparator()
    } else if (this.node.type === 'Table') {
      AITable({ columns: this.node.columns(), rows: this.node.tableRows(), footer: this.node.tableFooter(),
        caption: this.node.text('caption') })
    } else if (this.node.type.endsWith('Chart')) {
      AIChart({ kind: this.node.type === 'BarChart' ? AIChartKind.Bar :
        this.node.type === 'LineChart' ? AIChartKind.Line : AIChartKind.Area,
        data: this.node.chartRows(), series: this.node.series(), label: this.node.text('label', 'Chart'),
        legend: this.node.flag('legend'), plotHeight: this.node.number('height', 184),
        onSelect: row => this.select(row) })
    } else {
      AIText({ text: 'Loading…', variant: 'muted' })
    }
  }

  build() {
    Column() {
      this.render()
    }.alignItems(HorizontalAlign.Start)
  }
}

@Component
export struct AIUIRenderer {
  store: AIUIStore = new AIUIStore();
  onEvent?: (event: AIUIEvent) => void;
  @State rootNodes: AIUIDisplayNode[] = [];
  @State phase: AIUIPhase = 'idle';
  @State error: string = '';
  private unsubscribe?: () => void;

  aboutToAppear(): void {
    this.refresh();
    this.unsubscribe = this.store.subscribe(() => this.refresh());
  }

  aboutToDisappear(): void {
    this.unsubscribe?.();
  }

  private refresh(): void {
    const root = displaySurface(this.store.document);
    this.rootNodes = root ? [root] : [];
    this.phase = this.store.phase;
    this.error = this.store.errorMessage ?? '';
  }

  private action(id: string, event: string, value: AIUIValue): void {
    if (event === 'change' && !this.store.setValue(id, value)) return;
    const output = this.store.event(id, event, value);
    if (output) this.onEvent?.(output);
  }

  build() {
    Column({ space: 12 }) {
      Repeat(this.rootNodes).each((root: RepeatItem<AIUIDisplayNode>) => {
        RenderNode({ node: root.item, failed: this.phase === 'failed', actionEnabled: this.onEvent !== undefined,
          onAction: (id, event, value) => this.action(id, event, value) }).width('100%')
      }).key((root: AIUIDisplayNode) => root.id)
      if (this.phase === 'streaming') AIText({ text: 'Generating…', variant: 'muted' })
      if (this.error) AIText({ text: this.error, color: AIColors.destructive })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
