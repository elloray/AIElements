import { AIEmpty } from '../ui/Primitives';

interface FlowItem { width: number; height: number; x: number; y: number; }

// A wrapping row reports its occupied width so its parent can center or align
// the whole group. ArkUI Flex with wrap otherwise fills the available width.
@Component
export struct ShadcnFlow {
  @Prop gap: number = 0;
  @Prop rtl: boolean = false;
  @BuilderParam content: () => void = AIEmpty;
  private items: FlowItem[] = [];

  onMeasureSize(_info: GeometryInfo, children: Measurable[], bounds: ConstraintSizeOptions): SizeResult {
    const limit = Number(bounds.maxWidth ?? Infinity);
    const gap = Math.max(0, this.gap);
    let x = 0, y = 0, height = 0, width = 0, first = 0;
    this.items = [];
    const finishLine = (): void => {
      for (let i = first; i < this.items.length; i++) {
        this.items[i].y = y + (height - this.items[i].height) / 2;
      }
      width = Math.max(width, x);
      y += height;
      first = this.items.length;
      x = 0; height = 0;
    };
    children.forEach((child: Measurable) => {
      const size = child.measure({ maxWidth: bounds.maxWidth, maxHeight: bounds.maxHeight });
      if (this.items.length > first && x + gap + size.width > limit) {
        finishLine(); y += gap;
      }
      if (this.items.length > first) x += gap;
      this.items.push({ x, y, width: size.width, height: size.height });
      x += size.width; height = Math.max(height, size.height);
    });
    finishLine();
    return { width: Math.min(limit, Math.max(Number(bounds.minWidth ?? 0), width)), height: y };
  }

  onPlaceChildren(info: GeometryInfo, children: Layoutable[], _bounds: ConstraintSizeOptions): void {
    children.forEach((child: Layoutable, index: number) => {
      const item = this.items[index];
      if (item) child.layout({ x: this.rtl ? info.width - item.x - item.width : item.x, y: item.y });
    });
  }

  build() { this.content() }
}
