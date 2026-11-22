import { AIColors } from './Theme';
import { AIButton, AIText } from './Primitives';
import { chartDomain, naturalDerivatives } from './ChartGeometry';

export interface AITableColumn {
  key: string;
  label: string;
  width?: number;
  trailing?: boolean;
  emphasized?: boolean;
}

export interface AITableRow {
  id: string;
  cells: string[];
}

@Component
export struct AITable {
  @Prop columns: AITableColumn[] = [];
  @Prop rows: AITableRow[] = [];
  @Prop caption: string = '';
  @Prop footer: string[] = [];

  @Builder
  private cells(values: string[], header: boolean, footer: boolean) {
    Row() {
      Repeat(this.columns).each((column: RepeatItem<AITableColumn>) => {
        Text(header ? column.item.label : values[column.index] ?? '—')
          .fontSize(14)
          .fontFamily(header || footer || column.item.emphasized ? 'GeistMedium' : 'Geist')
          .fontColor(header ? AIColors.mutedForeground : AIColors.foreground)
          .textAlign(column.item.trailing ? TextAlign.End : TextAlign.Start)
          .width(column.item.width ?? 108)
          .padding({ left: 8, right: 8, top: 9, bottom: 9 })
      }).key((column: AITableColumn) => column.key)
    }
    .backgroundColor(footer ? AIColors.muted : Color.Transparent)
    .border({ width: { bottom: footer ? 0 : 1 }, color: AIColors.border })
  }

  build() {
    Column({ space: 10 }) {
      Scroll() {
        Column() {
          this.cells([], true, false)
          Repeat(this.rows).each((row: RepeatItem<AITableRow>) => {
            this.cells(row.item.cells, false, false)
          }).key((row: AITableRow) => row.id)
          if (this.footer.length > 0) {
            this.cells(this.footer, false, true)
          }
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .align(Alignment.Start)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Auto)
      if (this.caption) {
        AIText({ text: this.caption, variant: 'muted' })
      }
    }.width('100%')
  }
}

export interface AIChartSeries {
  key: string;
  label: string;
}

export interface AIChartRow {
  label: string;
  values: number[];
}

export enum AIChartKind { Bar, Line, Area }

const seriesColors: string[] = ['#8EC5FF', '#2B7FFF', '#155DFC', '#1447E6', '#1E3A8A'];

@Component
export struct AIChart {
  @Prop @Watch('draw') data: AIChartRow[] = [];
  @Prop @Watch('draw') series: AIChartSeries[] = [];
  @Prop @Watch('draw') kind: AIChartKind = AIChartKind.Bar;
  @Prop label: string = 'Chart';
  @Prop plotHeight: number = 184;
  @Prop legend: boolean = false;
  onSelect: (row: AIChartRow) => void = () => {};
  @State @Watch('draw') selectedLabel: string = '';
  @State showData: boolean = false;
  private canvas: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private ready: boolean = false;

  private draw(): void {
    if (!this.ready) return;
    const width = this.canvas.width;
    const height = this.canvas.height;
    const count = this.data.length;
    const seriesCount = this.series.length;
    this.canvas.clearRect(0, 0, width, height);
    if (width <= 0 || height <= 0 || count === 0 || seriesCount === 0) return;
    const plotHeight = Math.max(1, height - 26);
    const domain = chartDomain(this.data.flatMap((row: AIChartRow) => row.values));
    const max = domain[1];
    const range = max - domain[0];
    const left = this.kind === AIChartKind.Bar ? 5 : 12;
    const plotWidth = Math.max(1, width - left * 2);
    const band = plotWidth / count;
    const barGap = Math.min(4, band * 0.12);
    const barWidth = (band * 0.8 - (seriesCount - 1) * barGap) / seriesCount;
    const zero = 4 + max / range * plotHeight;
    const step = this.kind === AIChartKind.Bar ? band : plotWidth / Math.max(1, count - 1);
    const origin = left + (this.kind === AIChartKind.Bar ? band / 2 : count === 1 ? plotWidth / 2 : 0);
    this.canvas.lineWidth = 1;
    this.canvas.strokeStyle = 'rgba(115,115,115,0.35)';
    for (let line = 0; line <= 4; line++) {
      if (line === 1) continue;
      const y = 4 + plotHeight * line / 4;
      this.canvas.beginPath();
      this.canvas.moveTo(left, y);
      this.canvas.lineTo(width - left, y);
      this.canvas.stroke();
    }
    const selected = this.data.findIndex((row: AIChartRow) => row.label === this.selectedLabel);
    if (selected >= 0) {
      this.canvas.fillStyle = 'rgba(115,115,115,0.13)';
      this.canvas.fillRect(left + band * selected, 4, band, plotHeight);
    }
    for (let seriesIndex = 0; seriesIndex < seriesCount; seriesIndex++) {
      this.canvas.fillStyle = seriesColors[seriesIndex % seriesColors.length];
      this.canvas.strokeStyle = seriesColors[seriesIndex % seriesColors.length];
      const yValues = this.data.map((row: AIChartRow) => {
        const value = row.values[seriesIndex] ?? 0;
        return 4 + (max - (Number.isFinite(value) && Math.abs(value) <= 1e15 ? value : 0)) / range * plotHeight;
      });
      if (this.kind === AIChartKind.Bar) {
        for (let index = 0; index < count; index++) {
          const x = origin + band * index - band * 0.4 + (barWidth + barGap) * seriesIndex;
          const y = yValues[index];
          this.drawBar(x, Math.min(y, zero), barWidth, Math.abs(zero - y));
        }
      } else {
        this.drawSeries(yValues, origin, step, zero);
      }
    }
    this.canvas.fillStyle = '#737373';
    this.canvas.font = '11vp Geist';
    this.canvas.textAlign = 'center';
    const stride = Math.max(1, Math.ceil(34 / band));
    for (let index = 0; index < count; index += stride) {
      this.canvas.fillText(this.data[index].label.slice(0, 3), origin + step * index, height - 3);
    }
  }

  private drawBar(x: number, y: number, width: number, height: number): void {
    const radius = Math.min(8, width * 0.5, height * 0.5);
    const right = x + width;
    const bottom = y + height;
    this.canvas.beginPath();
    this.canvas.moveTo(x + radius, y);
    this.canvas.arcTo(right, y, right, y + radius, radius);
    this.canvas.arcTo(right, bottom, right - radius, bottom, radius);
    this.canvas.arcTo(x, bottom, x, bottom - radius, radius);
    this.canvas.arcTo(x, y, x + radius, y, radius);
    this.canvas.closePath();
    this.canvas.fill();
  }

  private drawSeries(values: number[], firstX: number, step: number, zero: number): void {
    const derivatives = naturalDerivatives(values);
    this.canvas.beginPath();
    this.canvas.moveTo(firstX, values[0]);
    for (let index = 1; index < values.length; index++) {
      const x = firstX + step * index;
      this.canvas.bezierCurveTo(x - step * 2 / 3, values[index - 1] + derivatives[index - 1] / 3,
        x - step / 3, values[index] - derivatives[index] / 3, x, values[index]);
    }
    this.canvas.lineWidth = 2;
    this.canvas.stroke();
    if (this.kind === AIChartKind.Area) {
      this.canvas.lineTo(firstX + step * (values.length - 1), zero);
      this.canvas.lineTo(firstX, zero);
      this.canvas.closePath();
      this.canvas.globalAlpha = 0.2;
      this.canvas.fill();
      this.canvas.globalAlpha = 1;
    }
    if (values.length === 1) {
      this.canvas.beginPath();
      this.canvas.arc(firstX, values[0], 3, 0, Math.PI * 2);
      this.canvas.fill();
    }
  }

  private choose(row: AIChartRow): void {
    this.selectedLabel = row.label;
    this.onSelect(row);
  }

  private summary(row: AIChartRow): string {
    return row.label + ' · ' + this.series.map((series: AIChartSeries, index: number) =>
      series.label + ': ' + String(row.values[index] ?? 0)).join(' · ');
  }

  build() {
    Column({ space: 8 }) {
      if (this.series.length === 0 || this.data.length === 0) {
        Column() {
          AIText({ text: 'No data yet', variant: 'muted' })
        }.width('100%').height(this.plotHeight).justifyContent(FlexAlign.Center)
      } else {
        Canvas(this.canvas)
          .width('100%')
          .height(this.plotHeight)
          .accessibilityText(this.label)
          .onReady(() => {
            this.ready = true;
            this.draw();
          })
          .onSizeChange(() => this.draw())
          .onClick(event => {
            const left = this.kind === AIChartKind.Bar ? 5 : 12;
            const width = this.canvas.width - left * 2;
            if (width > 0 && this.data.length > 0) {
              const ratio = (event.x - left) / width;
              const point = this.kind === AIChartKind.Bar ? Math.floor(ratio * this.data.length) :
                Math.round(ratio * (this.data.length - 1));
              this.choose(this.data[Math.min(this.data.length - 1, Math.max(0, point))]);
            }
          })
        if (this.legend) {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
            ForEach(this.series, (series: AIChartSeries, index: number) => {
              Row({ space: 5 }) {
                Circle().width(8).height(8).fill(seriesColors[index % seriesColors.length])
                AIText({ text: series.label, variant: 'caption' })
              }.padding(4)
            }, (series: AIChartSeries) => series.key)
          }
        }
        ForEach(this.data.filter((row: AIChartRow) => row.label === this.selectedLabel), (row: AIChartRow) => {
          AIText({ text: this.summary(row), variant: 'caption' })
        }, (row: AIChartRow) => row.label)
        AIButton({ label: this.showData ? 'Hide data' : 'View data', variant: 'ghost',
          onPress: () => { this.showData = !this.showData; } })
        if (this.showData) {
          Column() {
            ForEach(this.data, (row: AIChartRow) => {
              AIButton({ label: this.summary(row), variant: 'ghost', pressed: row.label === this.selectedLabel,
                onPress: () => this.choose(row) })
            }, (row: AIChartRow) => row.label)
          }.width('100%').alignItems(HorizontalAlign.Start)
        }
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}

@Component
export struct AIBarChart {
  @Prop data: AIChartRow[] = [];
  @Prop series: AIChartSeries[] = [];
  onSelect: (row: AIChartRow) => void = () => {};

  build() {
    AIChart({ data: this.data, series: this.series, kind: AIChartKind.Bar, onSelect: this.onSelect })
  }
}

@Component
export struct AILineChart {
  @Prop data: AIChartRow[] = [];
  @Prop series: AIChartSeries[] = [];
  onSelect: (row: AIChartRow) => void = () => {};

  build() {
    AIChart({ data: this.data, series: this.series, kind: AIChartKind.Line, onSelect: this.onSelect })
  }
}

@Component
export struct AIAreaChart {
  @Prop data: AIChartRow[] = [];
  @Prop series: AIChartSeries[] = [];
  onSelect: (row: AIChartRow) => void = () => {};

  build() {
    AIChart({ data: this.data, series: this.series, kind: AIChartKind.Area, onSelect: this.onSelect })
  }
}
