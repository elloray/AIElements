import { AIColors, AIIcons } from './Theme';
import { AIBadge, AIButton, AICard, AIEmpty, AIIcon, AIProgress, AIRow, AIText } from './Primitives';
import { AICodeBlock } from './Chat';

export enum AIStatus { Pending, Running, Completed, Failed, Skipped }

export interface AIStep {
  id: string;
  title: string;
  status: AIStatus;
  detail?: string;
}

export function aiStatusLabel(status: AIStatus): string {
  switch (status) {
    case AIStatus.Running: return 'In progress';
    case AIStatus.Completed: return 'Completed';
    case AIStatus.Failed: return 'Failed';
    case AIStatus.Skipped: return 'Skipped';
    default: return 'Pending';
  }
}

export function aiStatusIcon(status: AIStatus): Resource {
  switch (status) {
    case AIStatus.Running: return AIIcons.circleDot;
    case AIStatus.Completed: return AIIcons.circleCheck;
    case AIStatus.Failed: return AIIcons.circleX;
    default: return AIIcons.circle;
  }
}

@Component
export struct AITraceLine {
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop status: AIStatus = AIStatus.Completed;
  icon?: Resource;

  build() {
    Row({ space: 8 }) {
      AIIcon({ icon: this.icon ?? aiStatusIcon(this.status),
        color: this.status === AIStatus.Failed ? AIColors.destructive : AIColors.mutedForeground })
      Column({ space: 2 }) {
        AIText({ text: this.title, variant: 'label',
          color: this.status === AIStatus.Failed ? AIColors.destructive : AIColors.foreground })
        if (this.detail) AIText({ text: this.detail, variant: 'caption' })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }
    .width('100%')
    .constraintSize({ minHeight: 30 })
    .accessibilityDescription(aiStatusLabel(this.status))
  }
}

@Component
export struct AITrace {
  @BuilderParam content: () => void = AIEmpty;

  build() {
    Column({ space: 3 }) {
      this.content()
    }.alignItems(HorizontalAlign.Start).width('100%')
  }
}

@Component
export struct AITraceDisclosure {
  @Prop title: string = '';
  @Prop status: AIStatus = AIStatus.Completed;
  @Prop initiallyExpanded: boolean = false;
  @Prop streaming: boolean = false;
  icon?: Resource;
  @State expanded: boolean = false;
  @State overridden: boolean = false;
  @BuilderParam content: () => void = AIEmpty;

  private isExpanded(): boolean {
    return this.overridden ? this.expanded : this.streaming || this.initiallyExpanded;
  }

  build() {
    Column() {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row({ space: 5 }) {
          AITraceLine({ title: this.title, status: this.status, icon: this.icon }).layoutWeight(1)
          AIIcon({ icon: this.isExpanded() ? AIIcons.chevronDown : AIIcons.chevronRight })
        }.width('100%')
      }
      .width('100%')
      .constraintSize({ minHeight: 44 })
      .padding({ left: 0, right: 2 })
      .backgroundColor(Color.Transparent)
      .borderRadius(6)
      .accessibilityText(this.title)
      .accessibilityDescription(aiStatusLabel(this.status) + (this.isExpanded() ? ', expanded' : ', collapsed'))
      .onClick(() => {
        this.expanded = !this.isExpanded();
        this.overridden = true;
      })
      Column({ space: 4 }) {
        this.content()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12, bottom: 4, top: 4 })
      .margin({ left: 7 })
      .border({ width: { left: 1 }, color: AIColors.border })
      .visibility(this.isExpanded() ? Visibility.Visible : Visibility.None)
    }.width('100%')
  }
}

@Component
export struct AITool {
  @Prop name: string = '';
  @Prop status: AIStatus = AIStatus.Pending;
  @Prop input: string = '';
  @Prop output: string = '';

  build() {
    AITraceDisclosure({ title: this.name, status: this.status,
      icon: this.status === AIStatus.Failed ? AIIcons.circleX : AIIcons.terminal,
      initiallyExpanded: this.status === AIStatus.Failed }) {
      AIText({ text: aiStatusLabel(this.status), variant: 'caption' })
      if (this.input) AICodeBlock({ code: this.input, language: 'Input' })
      if (this.output) AICodeBlock({ code: this.output, language: 'Output' })
    }
  }
}

@Component
export struct AITerminal {
  @Prop command: string = '';
  @Prop output: string = '';
  @Prop status: AIStatus = AIStatus.Completed;

  build() {
    AITraceDisclosure({ title: this.command, status: this.status, icon: AIIcons.terminal,
      initiallyExpanded: true }) {
      AICodeBlock({ code: this.output || aiStatusLabel(this.status), language: 'Terminal' })
    }
  }
}

@Component
export struct AIReasoning {
  @Prop text: string = '';
  @Prop streaming: boolean = false;
  @Prop durationSeconds: number = 0;

  build() {
    AITraceDisclosure({ title: this.streaming ? 'Thinking…' :
      this.durationSeconds > 0 ? 'Thought for ' + this.durationSeconds + 's' : 'Reasoning',
      status: this.streaming ? AIStatus.Running : AIStatus.Completed, streaming: this.streaming }) {
      AIText({ text: this.text, variant: 'muted' })
    }
  }
}

@Component
struct AISteps {
  @Prop steps: AIStep[] = [];

  build() {
    Column({ space: 4 }) {
      Repeat(this.steps).each((step: RepeatItem<AIStep>) => {
        AITraceLine({ title: step.item.title, status: step.item.status, detail: step.item.detail ?? '' })
      }).key((step: AIStep) => step.id)
    }.width('100%')
  }
}

@Component
export struct AITask {
  @Prop title: string = '';
  @Prop steps: AIStep[] = [];

  build() {
    AITraceDisclosure({ title: this.title, icon: AIIcons.listTodo,
      status: this.steps.every((step: AIStep) => step.status === AIStatus.Completed) ?
        AIStatus.Completed : AIStatus.Running }) {
      AISteps({ steps: this.steps })
    }
  }
}

@Component
export struct AIPlan {
  @Prop title: string = 'Plan';
  @Prop steps: AIStep[] = [];

  build() {
    AICard({ title: this.title, description: this.steps.filter((step: AIStep) => step.status === AIStatus.Completed)
      .length + ' of ' + this.steps.length + ' completed' }) {
      AISteps({ steps: this.steps })
    }
  }
}

@Component
export struct AIChainOfThought {
  @Prop steps: AIStep[] = [];

  build() {
    AITraceDisclosure({ title: 'Chain of thought', initiallyExpanded: true, icon: AIIcons.route }) {
      Repeat(this.steps).each((step: RepeatItem<AIStep>) => {
        if (step.item.detail) {
          AITraceDisclosure({ title: step.item.title, status: step.item.status }) {
            AIText({ text: step.item.detail ?? '', variant: 'muted' })
          }
        } else {
          AITraceLine({ title: step.item.title, status: step.item.status })
        }
      }).key((step: AIStep) => step.id)
    }
  }
}

@Component
export struct AISubagent {
  @Prop title: string = '';
  @Prop status: AIStatus = AIStatus.Running;
  @BuilderParam content: () => void = AIEmpty;

  build() {
    AITraceDisclosure({ title: this.title, status: this.status, icon: AIIcons.bot }) {
      this.content()
    }
  }
}

@Component
export struct AIQueue {
  @Prop items: AIStep[] = [];
  onSelect?: (step: AIStep) => void;

  @Builder
  private group(title: string, completed: boolean) {
    if (this.items.some((item: AIStep) => (item.status === AIStatus.Completed) === completed)) {
      AIText({ text: title, variant: 'caption' })
      Repeat(this.items.filter((item: AIStep) => (item.status === AIStatus.Completed) === completed))
        .each((step: RepeatItem<AIStep>) => {
          if (this.onSelect) {
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              AITraceLine({ title: step.item.title, status: step.item.status, detail: step.item.detail ?? '' })
            }
            .padding(0)
            .width('100%')
            .constraintSize({ minHeight: 44 })
            .backgroundColor(Color.Transparent)
            .onClick(() => this.onSelect?.(step.item))
          } else {
            AITraceLine({ title: step.item.title, status: step.item.status, detail: step.item.detail ?? '' })
          }
        }).key((step: AIStep) => step.id)
    }
  }

  build() {
    AICard({ title: 'Queue' }) {
      Column({ space: 8 }) {
        this.group('To do', false)
        this.group('Completed', true)
      }.alignItems(HorizontalAlign.Start).width('100%')
    }
  }
}

export interface AITestResult {
  id: string;
  name: string;
  status: AIStatus;
  detail?: string;
  suite?: string;
}

@Component
export struct AITestResults {
  @Prop title: string = 'Test results';
  @Prop tests: AITestResult[] = [];

  private groupNames(): string[] {
    return Array.from(new Set(this.tests.map((test: AITestResult) => test.suite ?? '')));
  }

  private count(status: AIStatus): number {
    return this.tests.filter((test: AITestResult) => test.status === status).length;
  }

  build() {
    AICard({ title: this.title, description: this.count(AIStatus.Completed) + ' passed · ' +
      this.count(AIStatus.Failed) + ' failed · ' + this.count(AIStatus.Skipped) + ' skipped' }) {
      Column({ space: 4 }) {
        ForEach(this.groupNames(), (suite: string) => {
          Column({ space: 4 }) {
            if (suite) AIText({ text: suite, variant: 'caption' })
            Repeat(this.tests.filter((test: AITestResult) => (test.suite ?? '') === suite))
              .each((test: RepeatItem<AITestResult>) => {
                if (test.item.detail) {
                  AITraceDisclosure({ title: test.item.name, status: test.item.status,
                    initiallyExpanded: test.item.status === AIStatus.Failed }) {
                    AIText({ text: test.item.detail ?? '', variant: 'muted' })
                  }
                } else {
                  AITraceLine({ title: test.item.name, status: test.item.status })
                }
              }).key((test: AITestResult) => test.id)
          }.alignItems(HorizontalAlign.Start).width('100%')
        })
      }.alignItems(HorizontalAlign.Start).width('100%')
    }
  }
}

export interface AIStackFrame {
  id: string;
  name: string;
  file: string;
  line: number;
  framework?: boolean;
}

@Component
export struct AIStackTrace {
  @Prop error: string = '';
  @Prop frames: AIStackFrame[] = [];
  onOpenSource?: (frame: AIStackFrame) => void;

  @Builder
  private frame(frame: AIStackFrame) {
    if (this.onOpenSource) {
      AIButton({ label: frame.name + ' · ' + frame.file + ':' + frame.line, variant: 'ghost',
        onPress: () => this.onOpenSource?.(frame) })
    } else {
      AITraceLine({ title: frame.name, detail: frame.file + ':' + frame.line, icon: AIIcons.fileText })
    }
  }

  build() {
    AITraceDisclosure({ title: this.error, status: AIStatus.Failed, initiallyExpanded: true }) {
      Repeat(this.frames.filter((frame: AIStackFrame) => !frame.framework)).each((item: RepeatItem<AIStackFrame>) => {
        this.frame(item.item)
      }).key((frame: AIStackFrame) => frame.id)
      if (this.frames.some((frame: AIStackFrame) => frame.framework === true)) {
        AITraceDisclosure({ title: 'Framework frames', icon: AIIcons.layers }) {
          Repeat(this.frames.filter((frame: AIStackFrame) => frame.framework === true))
            .each((item: RepeatItem<AIStackFrame>) => {
              this.frame(item.item)
            }).key((frame: AIStackFrame) => frame.id)
        }
      }
    }
  }
}

@Component
export struct AIContext {
  @Prop input: number = 0;
  @Prop output: number = 0;
  @Prop reasoning: number = 0;
  @Prop limit: number = 0;

  private percent(): number {
    const used = this.input + this.output + this.reasoning;
    return this.limit > 0 ? Math.round(100 * used / this.limit) : 0;
  }

  build() {
    AITraceDisclosure({ title: 'Context · ' + this.percent() + '%', icon: AIIcons.circleDot }) {
      AIProgress({ value: Math.min(100, Math.max(0, this.percent())), label: 'Context window' })
      AIText({ text: 'Input  ' + this.input.toLocaleString() + ' · Output  ' + this.output.toLocaleString(),
        variant: 'muted' })
      AIText({ text: 'Reasoning  ' + this.reasoning.toLocaleString() + ' · Limit  ' + this.limit.toLocaleString(),
        variant: 'muted' })
    }
  }
}

@Component
export struct AICheckpoint {
  @Prop title: string = 'Restore checkpoint';
  @Prop active: boolean = true;
  onRestore: () => void = () => {};

  build() {
    AIButton({ label: this.title, variant: 'outline', icon: AIIcons.rotateCcw,
      active: this.active, onPress: this.onRestore })
  }
}

export enum AIConfirmationDecision { Pending, Approved, Denied }

@Component
export struct AIConfirmation {
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop @Watch('decisionChanged') decision: AIConfirmationDecision = AIConfirmationDecision.Pending;
  @Prop executionStatus: AIStatus = AIStatus.Pending;
  @Prop output: string = '';
  onDecision: (decision: AIConfirmationDecision) => Promise<void> = async () => {};
  @State busy: boolean = false;
  @State error: string = '';

  private decisionChanged(): void {
    this.error = '';
  }

  private async submit(decision: AIConfirmationDecision): Promise<void> {
    if (this.busy || this.decision !== AIConfirmationDecision.Pending) return;
    this.busy = true;
    this.error = '';
    try {
      await this.onDecision(decision);
    } catch {
      this.error = 'The decision could not be saved. Try again.';
    } finally {
      this.busy = false;
    }
  }

  build() {
    AICard({ title: this.title, description: this.description }) {
      if (this.decision === AIConfirmationDecision.Pending) {
        AIRow() {
          AIButton({ label: 'Deny', variant: 'outline', active: !this.busy,
            onPress: () => { void this.submit(AIConfirmationDecision.Denied); } })
          AIButton({ label: this.busy ? 'Saving…' : 'Approve', active: !this.busy,
            onPress: () => { void this.submit(AIConfirmationDecision.Approved); } })
        }
        if (this.error) AIText({ text: this.error, color: AIColors.destructive })
      } else {
        AIBadge({ text: this.decision === AIConfirmationDecision.Approved ? 'Approved' : 'Denied',
          variant: this.decision === AIConfirmationDecision.Denied ? 'destructive' : 'secondary' })
        if (this.decision === AIConfirmationDecision.Approved && this.executionStatus !== AIStatus.Pending) {
          AITraceLine({ title: aiStatusLabel(this.executionStatus), status: this.executionStatus })
          if (this.output) AICodeBlock({ code: this.output, language: 'Output' })
        }
      }
    }
  }
}
