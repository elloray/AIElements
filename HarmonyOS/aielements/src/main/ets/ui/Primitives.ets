import { LengthMetrics } from "@kit.ArkUI";

import { AIColors, AIIcons } from './Theme';

@Builder
export function AIEmpty() {}

export interface AIOption {
  value: string;
  label: string;
}

@Component
export struct AIIcon {
  @Prop icon: Resource = AIIcons.circle;
  @Prop iconSize: number = 16;
  color: ResourceColor = AIColors.mutedForeground;

  build() {
    Image(this.icon)
      .width(this.iconSize)
      .height(this.iconSize)
      .fillColor(this.color)
      .draggable(false)
      .accessibilityLevel('no')
  }
}

@Component
export struct AIText {
  @Prop text: string = '';
  @Prop variant: string = 'body';
  color?: ResourceColor;

  build() {
    Text(this.text)
      .fontSize(this.variant === 'title' ? 16 : this.variant === 'caption' ? 12 : 14)
      .fontFamily(this.variant === 'title' ? 'GeistSemibold' : this.variant === 'label' ? 'GeistMedium' : 'Geist')
      .fontColor(this.color ?? (this.variant === 'muted' || this.variant === 'caption' ?
        AIColors.mutedForeground : AIColors.foreground))
  }
}

@Component
export struct AIButton {
  @Prop label: string = '';
  @Prop variant: string = 'primary';
  @Prop active: boolean = true;
  @Prop pressed: boolean = false;
  icon?: Resource;
  onPress: () => void = () => {};

  private foreground(): ResourceColor {
    if (this.variant === 'primary') return AIColors.onPrimary;
    if (this.variant === 'destructive') return Color.White;
    return AIColors.foreground;
  }

  private surface(): ResourceColor {
    if (this.variant === 'primary') return AIColors.primary;
    if (this.variant === 'destructive') return '#BA1A20';
    if (this.variant === 'secondary' || this.pressed) return AIColors.muted;
    return Color.Transparent;
  }

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 6 }) {
        if (this.icon) {
          AIIcon({ icon: this.icon, color: this.foreground() })
        }
        if (this.label) {
          Text(this.label).fontSize(14).fontFamily('GeistMedium').fontColor(this.foreground())
        }
      }
      .justifyContent(FlexAlign.Center)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    }
    .constraintSize({ minHeight: 44, minWidth: 44 })
    .borderRadius(8)
    .backgroundColor(this.surface())
    .border({ width: this.variant === 'outline' ? 1 : 0, color: AIColors.border })
    .enabled(this.active)
    .opacity(this.active ? 1 : 0.5)
    .onClick(() => this.onPress())
  }
}

@Component
export struct AIIconButton {
  @Prop icon: Resource = AIIcons.circle;
  @Prop label: string = '';
  @Prop active: boolean = true;
  @Prop selected: boolean = false;
  @Prop solid: boolean = false;
  onPress: () => void = () => {};

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      AIIcon({ icon: this.icon, color: this.solid ? AIColors.onPrimary : AIColors.foreground })
    }
    .width(44)
    .height(44)
    .borderRadius(22)
    .backgroundColor(this.solid ? AIColors.primary : this.selected ? AIColors.muted : Color.Transparent)
    .enabled(this.active)
    .opacity(this.active ? 1 : 0.5)
    .accessibilityText(this.label)
    .onClick(() => this.onPress())
  }
}

@Component
export struct AIBadge {
  @Prop text: string = '';
  @Prop variant: string = 'secondary';

  build() {
    Text(this.text)
      .fontSize(12)
      .fontFamily('GeistMedium')
      .fontColor(this.variant === 'primary' ? AIColors.onPrimary :
        this.variant === 'destructive' ? AIColors.destructive : AIColors.foreground)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .borderRadius(20)
      .backgroundColor(this.variant === 'primary' ? AIColors.primary :
        this.variant === 'secondary' ? AIColors.muted : Color.Transparent)
      .border({ width: this.variant === 'outline' ? 1 : 0, color: AIColors.border })
  }
}

@Component
export struct AICard {
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop footer: string = '';
  @Prop footnote: string = '';
  @Prop chartStyle: boolean = false;
  @Prop trending: boolean = false;
  @BuilderParam content: () => void = AIEmpty;

  build() {
    Column({ space: this.chartStyle ? 24 : 16 }) {
      if (this.title || this.description) {
        Row({ space: 8 }) {
          Column({ space: this.chartStyle ? 6 : 4 }) {
            if (this.title) {
              AIText({ text: this.title, variant: 'title' })
            }
            if (this.description) {
              AIText({ text: this.description, variant: 'muted' })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
      }
      this.content()
      if (this.footer || this.footnote) {
        Column({ space: this.chartStyle ? 8 : 4 }) {
          if (this.footer) {
            Row({ space: 6 }) {
              AIText({ text: this.footer, variant: 'label' })
              if (this.trending) {
                AIIcon({ icon: AIIcons.trendingUp, color: AIColors.foreground })
              }
            }
          }
          if (this.footnote) {
            AIText({ text: this.footnote, variant: 'muted' })
          }
        }
        .alignItems(HorizontalAlign.Start)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(this.chartStyle ? 24 : 14)
    .border({ width: 1, color: AIColors.border, radius: 14 })
    .backgroundColor(AIColors.card)
  }
}

@Component
export struct AIInput {
  @Prop value: string = '';
  @Prop label: string = '';
  @Prop placeholder: string = '';
  @Prop active: boolean = true;
  onValueChange: (value: string) => void = () => {};

  build() {
    Column({ space: 6 }) {
      if (this.label) {
        AIText({ text: this.label, variant: 'label' })
      }
      TextInput({ text: this.value, placeholder: this.placeholder })
        .width('100%')
        .constraintSize({ minHeight: 44 })
        .fontSize(14)
        .fontFamily('Geist')
        .fontColor(AIColors.foreground)
        .placeholderColor(AIColors.mutedForeground)
        .backgroundColor(AIColors.input)
        .border({ width: 1, color: AIColors.inputBorder, radius: 8 })
        .padding({ left: 12, right: 12 })
        .accessibilityText(this.label || this.placeholder)
        .enabled(this.active)
        .onChange(value => this.onValueChange(value))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

@Component
export struct AISelect {
  @Prop value: string = '';
  @Prop options: AIOption[] = [];
  @Prop label: string = '';
  @Prop placeholder: string = 'Select an option';
  @Prop active: boolean = true;
  onValueChange: (value: string) => void = () => {};

  private choices(): SelectOption[] {
    return this.options.map((option: AIOption): SelectOption => ({ value: option.label }));
  }

  build() {
    Column({ space: 6 }) {
      if (this.label) {
        AIText({ text: this.label, variant: 'label' })
      }
      Select(this.choices())
        .selected(this.options.findIndex((option: AIOption) => option.value === this.value))
        .value(this.options.find((option: AIOption) => option.value === this.value)?.label ?? this.placeholder)
        .font({ size: 14, family: 'Geist' })
        .fontColor(AIColors.foreground)
        .backgroundColor(AIColors.input)
        .border({ width: 1, color: AIColors.inputBorder, radius: 8 })
        .constraintSize({ minHeight: 44 })
        .width('100%')
        .accessibilityText(this.label || this.placeholder)
        .enabled(this.active && this.options.length > 0)
        .onSelect(index => {
          if (index >= 0 && index < this.options.length) this.onValueChange(this.options[index].value);
        })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

@Component
export struct AISwitch {
  @Prop value: boolean = false;
  @Prop label: string = '';
  @Prop active: boolean = true;
  onValueChange: (value: boolean) => void = () => {};

  build() {
    Row({ space: 8 }) {
      AIText({ text: this.label, variant: 'label' }).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.value })
        .selectedColor(AIColors.primary)
        .width(48)
        .height(44)
        .enabled(this.active)
        .accessibilityText(this.label)
        .onChange(value => this.onValueChange(value))
    }
    .constraintSize({ minHeight: 44 })
    .width('100%')
  }
}

@Component
export struct AIProgress {
  @Prop value: number = 0;
  @Prop total: number = 100;
  @Prop label: string = '';
  @Prop strokeWidth: number = 8;

  build() {
    Column({ space: 8 }) {
      if (this.label) {
        AIText({ text: this.label, variant: 'label' })
      }
      Progress({ value: this.value, total: this.total, type: ProgressType.Linear })
        .width('100%')
        .color(AIColors.primary)
        .backgroundColor(AIColors.muted)
        .style({ strokeWidth: this.strokeWidth })
        .accessibilityText(this.label || 'Progress')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

@Component
export struct AISeparator {
  build() {
    Divider().strokeWidth(1).color(AIColors.border)
  }
}

@Component
export struct AIStack {
  @Prop gap: number = 12;
  @BuilderParam content: () => void = AIEmpty;

  build() {
    Column({ space: this.gap }) {
      this.content()
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}

@Component
export struct AIRow {
  @Prop gap: number = 8;
  @BuilderParam content: () => void = AIEmpty;

  build() {
    Flex({
      wrap: FlexWrap.Wrap,
      alignItems: ItemAlign.Center,
      space: { main: LengthMetrics.vp(this.gap), cross: LengthMetrics.vp(this.gap) }
    }) {
      this.content()
    }.width('100%')
  }
}
