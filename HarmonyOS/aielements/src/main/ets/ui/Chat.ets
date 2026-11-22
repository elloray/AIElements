import { LengthMetrics } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileUri, picker } from '@kit.CoreFileKit';
import { AIColors, AIIcons } from './Theme';
import { AIButton, AIEmpty, AIIcon, AIIconButton, AIText } from './Primitives';
import { AIInlineRun, AIMessageBlock, messageBlocks } from './Markdown';

export enum AIMessageRole { User, Assistant, System }

export interface AIAttachment {
  uri: string;
  name: string;
}

export interface AIPromptSubmission {
  text: string;
  attachments: AIAttachment[];
}

export interface AIChatMessage {
  id: string;
  role: AIMessageRole;
  text: string;
  attachments?: AIAttachment[];
}

export async function copyAIText(value: string): Promise<void> {
  await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, value));
}

export async function openAIWebLink(context: common.UIAbilityContext, url: string): Promise<void> {
  if (!/^https?:\/\/[^\s]+$/i.test(url)) throw new Error('This link is not a web URL.');
  await context.openLink(url, { appLinkingOnly: false });
}

@Component
export struct AICodeBlock {
  @Prop code: string = '';
  @Prop language: string = '';
  @Prop showCopy: boolean = true;
  @State copyStatus: string = 'Copy code';

  private async copy(): Promise<void> {
    try {
      await copyAIText(this.code);
      this.copyStatus = 'Copied';
    } catch {
      this.copyStatus = 'Copy failed';
    }
  }

  build() {
    Column() {
      if (this.language || this.showCopy) {
        Row() {
          AIText({ text: this.language || 'Output', variant: 'caption' }).layoutWeight(1)
          if (this.showCopy) {
            AIIconButton({ icon: this.copyStatus === 'Copied' ? AIIcons.check : AIIcons.copy,
              label: this.copyStatus, onPress: () => { void this.copy(); } })
          }
        }.width('100%').padding({ left: 12, right: 4 })
      }
      Scroll() {
        Text(this.code)
          .fontSize(12)
          .fontFamily('GeistMono')
          .lineSpacing(LengthMetrics.vp(4))
          .fontColor(AIColors.foreground)
          .copyOption(CopyOptions.LocalDevice)
          .padding({ left: 12, right: 12, bottom: 12, top: this.language || this.showCopy ? 0 : 12 })
      }
      .width('100%')
      .align(Alignment.Start)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .border({ width: 1, color: AIColors.border, radius: 12 })
    .backgroundColor(AIColors.muted)
  }
}

@Component
export struct AIMessageResponse {
  @Prop text: string = '';
  @State linkError: string = '';

  private async open(url: string): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await openAIWebLink(context, url);
      this.linkError = '';
    } catch {
      this.linkError = 'Unable to open the link.';
    }
  }

  build() {
    Column({ space: 10 }) {
      Repeat(messageBlocks(this.text)).each((item: RepeatItem<AIMessageBlock>) => {
        if (item.item.kind === 'code') {
          AICodeBlock({ code: item.item.code, language: item.item.language })
        } else {
          Text() {
            Repeat(item.item.runs).each((run: RepeatItem<AIInlineRun>) => {
              Span(run.item.text)
                .fontFamily(run.item.style === 'code' ? 'GeistMono' : run.item.style === 'strong' ?
                  'GeistSemibold' : 'Geist')
                .decoration({ type: run.item.style === 'link' ? TextDecorationType.Underline : TextDecorationType.None })
                .onClick(() => {
                  if (run.item.url) void this.open(run.item.url);
                })
            })
          }
          .fontSize(item.item.kind === 'title' ? 16 : 14)
          .lineSpacing(LengthMetrics.vp(4))
          .fontColor(AIColors.foreground)
          .copyOption(CopyOptions.LocalDevice)
        }
      })
      if (this.linkError) AIText({ text: this.linkError, color: AIColors.destructive })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

@Component
export struct AIAttachmentView {
  @Prop attachment: AIAttachment = { uri: '', name: '' };
  onRemove?: () => void;

  build() {
    Row({ space: 6 }) {
      AIIcon({ icon: AIIcons.paperclip })
      Text(this.attachment.name)
        .fontSize(12)
        .fontFamily('GeistMedium')
        .fontColor(AIColors.foreground)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: 160 })
      if (this.onRemove) {
        AIIconButton({ icon: AIIcons.x, label: 'Remove ' + this.attachment.name, onPress: this.onRemove })
      }
    }
    .padding({ left: 8, right: this.onRemove ? 0 : 8, top: this.onRemove ? 0 : 4, bottom: this.onRemove ? 0 : 4 })
    .backgroundColor(AIColors.muted)
    .borderRadius(8)
  }
}

@Component
export struct AIPromptInput {
  @Prop text: string = '';
  @Prop placeholder: string = 'Ask anything…';
  @Prop attachments: AIAttachment[] = [];
  @Prop streaming: boolean = false;
  onTextChange: (value: string) => void = () => {};
  onAttachmentsChange?: (attachments: AIAttachment[]) => void;
  onSubmit: (submission: AIPromptSubmission) => void = () => {};
  onStop?: () => void;
  @BuilderParam toolbar: () => void = AIEmpty;
  @State picking: boolean = false;
  @State pickerError: string = '';

  private async addAttachments(): Promise<void> {
    if (this.picking || !this.onAttachmentsChange) return;
    this.picking = true;
    this.pickerError = '';
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 10;
      const files = await new picker.DocumentViewPicker(context).select(options);
      if (files.length === 0) return;
      const next = this.attachments.slice();
      for (const uri of files) {
        if (!next.some((attachment: AIAttachment) => attachment.uri === uri)) {
          next.push({ uri, name: new fileUri.FileUri(uri).name || 'Attachment' });
        }
      }
      this.onAttachmentsChange(next);
    } catch {
      this.pickerError = 'Unable to select attachments. Try again.';
    } finally {
      this.picking = false;
    }
  }

  private submit(): void {
    if (this.streaming) {
      this.onStop?.();
    } else if (this.text.trim() || this.attachments.length > 0) {
      this.onSubmit({ text: this.text.trim(), attachments: this.attachments.slice() });
    }
  }

  build() {
    Column({ space: 6 }) {
      if (this.attachments.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.attachments, (attachment: AIAttachment) => {
            AIAttachmentView({ attachment, onRemove: this.onAttachmentsChange ? () => {
              this.onAttachmentsChange?.(this.attachments.filter((item: AIAttachment) => item.uri !== attachment.uri));
            } : undefined }).margin({ right: 4, bottom: 4 })
          }, (attachment: AIAttachment) => attachment.uri)
        }
      }
      TextArea({ text: this.text, placeholder: this.placeholder })
        .width('100%')
        .constraintSize({ minHeight: 52, maxHeight: 164 })
        .fontSize(14)
        .fontFamily('Geist')
        .fontColor(AIColors.foreground)
        .placeholderColor(AIColors.mutedForeground)
        .backgroundColor(Color.Transparent)
        .borderRadius(0)
        .padding({ left: 4, top: 6, right: 4, bottom: 6 })
        .accessibilityText('Prompt')
        .onChange(value => this.onTextChange(value))
      Row({ space: 4 }) {
        if (this.onAttachmentsChange) {
          AIIconButton({ icon: AIIcons.plus, label: 'Add attachment', active: !this.picking,
            onPress: () => { void this.addAttachments(); } })
        }
        Row() { this.toolbar() }.layoutWeight(1)
        AIIconButton({ icon: this.streaming ? AIIcons.square : AIIcons.arrowUp,
          label: this.streaming ? 'Stop generating' : 'Send',
          active: this.streaming ? this.onStop !== undefined : this.text.trim().length > 0 || this.attachments.length > 0,
          solid: true, onPress: () => this.submit() })
      }.width('100%')
      if (this.pickerError) AIText({ text: this.pickerError, color: AIColors.destructive })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(8)
    .backgroundColor(AIColors.prompt)
    .border({ width: 1, color: AIColors.border, radius: 18 })
  }
}

@Component
export struct AIMessage {
  @Prop role: AIMessageRole = AIMessageRole.Assistant;
  @BuilderParam content: () => void = AIEmpty;

  build() {
    Row() {
      Column({ space: 8 }) {
        this.content()
      }
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ maxWidth: this.role === AIMessageRole.User ? '80%' : '100%' })
      .padding(this.role === AIMessageRole.User ? { left: 12, right: 12, top: 10, bottom: 10 } : 0)
      .borderRadius(this.role === AIMessageRole.User ? 22 : 0)
      .backgroundColor(this.role === AIMessageRole.User ? AIColors.muted : Color.Transparent)
    }
    .width('100%')
    .justifyContent(this.role === AIMessageRole.User ? FlexAlign.End : FlexAlign.Start)
  }
}

@Component
export struct AIMessageActions {
  @Prop text: string = '';
  onRetry?: () => void;
  onFeedback?: (feedback: string) => void;
  @State feedback: string = '';
  @State copyStatus: string = 'Copy response';

  private async copy(): Promise<void> {
    try {
      await copyAIText(this.text);
      this.copyStatus = 'Copied';
    } catch {
      this.copyStatus = 'Copy failed';
    }
  }

  private vote(value: string): void {
    this.feedback = this.feedback === value ? '' : value;
    this.onFeedback?.(this.feedback);
  }

  build() {
    Row() {
      AIIconButton({ icon: this.copyStatus === 'Copied' ? AIIcons.check : AIIcons.copy,
        label: this.copyStatus, onPress: () => { void this.copy(); } })
      if (this.onRetry) AIIconButton({ icon: AIIcons.rotateCcw, label: 'Retry', onPress: this.onRetry })
      if (this.onFeedback) {
        AIIconButton({ icon: AIIcons.thumbsUp, label: 'Good response', selected: this.feedback === 'up',
          onPress: () => this.vote('up') })
        AIIconButton({ icon: AIIcons.thumbsDown, label: 'Poor response', selected: this.feedback === 'down',
          onPress: () => this.vote('down') })
      }
    }
  }
}

@Component
export struct AIChatHeader {
  @Prop title: string = 'Chat';
  @Prop description: string = '';
  onReset?: () => void;

  build() {
    Row() {
      Column({ space: 4 }) {
        AIText({ text: this.title, variant: 'title' })
        if (this.description) AIText({ text: this.description, variant: 'muted' })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (this.onReset) AIIconButton({ icon: AIIcons.rotateCcw, label: 'Reset conversation', onPress: this.onReset })
    }.width('100%').alignItems(VerticalAlign.Top)
  }
}

@Component
export struct AIChat {
  @Prop @Watch('messagesChanged') messages: AIChatMessage[] = [];
  @Prop streaming: boolean = false;
  @Prop emptyTitle: string = 'How can I help you today?';
  @Prop emptyDescription: string = 'Start with a question or pick a suggestion.';
  @State following: boolean = true;
  private scroller: Scroller = new Scroller();
  private followTimer: number = -1;

  aboutToDisappear(): void {
    if (this.followTimer !== -1) clearTimeout(this.followTimer);
  }

  private messagesChanged(): void {
    if (this.messages.length === 0) this.following = true;
    if (!this.following || this.messages.length === 0) return;
    if (this.followTimer !== -1) clearTimeout(this.followTimer);
    this.followTimer = setTimeout(() => {
      this.followTimer = -1;
      if (this.following) this.scroller.scrollEdge(Edge.Bottom);
    }, 0);
  }

  build() {
    Column() {
      if (this.messages.length === 0) {
        Column({ space: 8 }) {
          AIIcon({ icon: AIIcons.messageCircleDashed, iconSize: 32 })
          AIText({ text: this.emptyTitle, variant: 'title' })
          AIText({ text: this.emptyDescription, variant: 'muted' })
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center).padding(12)
      } else {
        List({ scroller: this.scroller, space: 16 }) {
          Repeat(this.messages).each((message: RepeatItem<AIChatMessage>) => {
            ListItem() {
              AIMessage({ role: message.item.role }) {
                if (message.item.text) {
                  if (message.item.role === AIMessageRole.Assistant) {
                    AIMessageResponse({ text: message.item.text })
                  } else {
                    AIText({ text: message.item.text })
                  }
                }
                ForEach(message.item.attachments ?? [], (attachment: AIAttachment) => {
                  AIAttachmentView({ attachment })
                }, (attachment: AIAttachment) => attachment.uri)
              }
            }
          }).key((message: AIChatMessage) => message.id)
          if (this.streaming) ListItem() { AIText({ text: 'Generating…', variant: 'muted' }) }
        }
        .width('100%')
        .layoutWeight(1)
        .onScrollStop(() => { this.following = this.scroller.isAtEnd(); })
        .onAppear(() => this.messagesChanged())
        if (!this.following) {
          AIButton({ label: 'Jump to latest', icon: AIIcons.arrowDown, variant: 'outline', onPress: () => {
            this.following = true;
            this.scroller.scrollEdge(Edge.Bottom);
          } })
        }
      }
    }.width('100%')
  }
}
