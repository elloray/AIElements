import { AIAttachment, AIButton, AICheckpoint, AIChainOfThought, AIChat, AIChatHeader, AIChatMessage,
  AICitedText, AIConfirmation, AIConfirmationDecision, AIContext, AIFileNode, AIFileTree,
  AIMessage, AIMessageActions, AIMessageResponse, AIMessageRole, AIModel, AIModelSelector, AIPlan,
  AIPromptInput, AIPromptSubmission, AIQueue, AIReasoning, AISource, AISources, AIStackTrace, AIStatus,
  AIStep, AISubagent, AISuggestions, AITask, AITerminal, AITestResults, AIText, AITool } from '@aielements/arkui';

const models: AIModel[] = [
  { id: 'haiku', name: 'Claude Haiku', provider: 'Anthropic' },
  { id: 'sonnet', name: 'Claude Sonnet', provider: 'Anthropic' },
  { id: 'gemini', name: 'Gemini Flash', provider: 'Google' }
];

const steps: AIStep[] = [
  { id: 'structure', title: 'Inspect the existing components', status: AIStatus.Completed,
    detail: 'Reviewed the SwiftUI and Compose interfaces.' },
  { id: 'native', title: 'Implement the ArkUI library', status: AIStatus.Running,
    detail: 'Port shared tokens, forms and streaming charts.' },
  { id: 'build', title: 'Run the gallery and protocol checks', status: AIStatus.Pending }
];

const sources: AISource[] = [
  { title: 'ArkUI', url: 'https://developer.huawei.com/consumer/en/arkui/',
    summary: 'Declarative native interface framework for HarmonyOS.' },
  { title: 'AI Elements', url: 'https://ui.shadcn.com/docs/ai-elements',
    summary: 'Original reference patterns for AI interfaces.' }
];

const files: AIFileNode[] = [
  { id: 'gallery', name: 'gallery', children: [
    { id: 'index', name: 'Index.ets' }, { id: 'demos', name: 'PatternDemo.ets' }
  ] },
  { id: 'aielements', name: 'aielements', children: [
    { id: 'themes', name: 'Theme.ets' }, { id: 'library', name: 'Index.ets' }
  ] }
];

@Component
struct Composer {
  @Prop streaming: boolean = false;
  @Prop suggestions: boolean = false;
  onSubmit: (submission: AIPromptSubmission) => void = () => {};
  onStop?: () => void;
  @State draft: string = '';
  @State model: string = 'haiku';
  @State effort: string = 'Medium';
  @State attachments: AIAttachment[] = [];

  build() {
    Column({ space: 8 }) {
      if (this.suggestions) {
        AISuggestions({ suggestions: ['Explain streaming UI', 'Add a chart', 'Review this component'],
          onSelect: value => { this.draft = value; } })
      }
      AIPromptInput({ text: this.draft, streaming: this.streaming, attachments: this.attachments,
        onTextChange: value => { this.draft = value; },
        onAttachmentsChange: files => { this.attachments = files; },
        onSubmit: submission => {
          this.onSubmit(submission);
          this.draft = '';
          this.attachments = [];
        },
        onStop: this.onStop }) {
        AIModelSelector({ models, selectedID: this.model, effort: this.effort,
          onSelect: id => { this.model = id; }, onEffortChange: value => { this.effort = value; } })
      }
    }.width('100%')
  }
}

@Component
export struct ChatDemo {
  @Prop showHeader: boolean = true;
  @State messages: AIChatMessage[] = [];
  @State streaming: boolean = false;
  @State composerKey: number[] = [0];
  private timer: number = -1;
  private sequence: number = 0;

  aboutToDisappear(): void {
    this.stop();
  }

  private stop(): void {
    if (this.timer !== -1) clearTimeout(this.timer);
    this.timer = -1;
    this.streaming = false;
  }

  private reset(): void {
    this.stop();
    this.messages = [];
    this.composerKey = [this.composerKey[0] + 1];
  }

  private submit(submission: AIPromptSubmission): void {
    if (this.streaming) return;
    const answer = 'This is a **local demo reply**. The host app can connect this composer to its own model and stream the response into the conversation.';
    const id = 'assistant-' + ++this.sequence;
    const message: AIChatMessage = { id: 'user-' + this.sequence, role: AIMessageRole.User, text: submission.text,
      attachments: submission.attachments };
    this.messages = this.messages.concat(message);
    this.streaming = true;
    let end = 0;
    const update = (): void => {
      end = Math.min(answer.length, end + 14);
      const reply: AIChatMessage = { id, role: AIMessageRole.Assistant, text: answer.slice(0, end) };
      this.messages = this.messages.filter((item: AIChatMessage) => item.id !== id).concat(reply);
      if (end < answer.length) this.timer = setTimeout(update, 90);
      else this.stop();
    };
    this.timer = setTimeout(update, 280);
  }

  build() {
    Column({ space: 12 }) {
      if (this.showHeader) {
        AIChatHeader({ title: 'Conversation', description: 'Local chat demo', onReset: () => this.reset() })
      }
      AIChat({ messages: this.messages, streaming: this.streaming }).layoutWeight(1)
      ForEach(this.composerKey, () => {
        Composer({ streaming: this.streaming, suggestions: this.messages.length === 0,
          onSubmit: submission => this.submit(submission), onStop: () => this.stop() })
      }, (key: number) => String(key))
    }.width('100%').height('100%').padding({ bottom: 12 })
  }
}

@Component
export struct PatternDemo {
  @Prop name: string = '';
  @State notice: string = '';
  @State decision: AIConfirmationDecision = AIConfirmationDecision.Pending;
  @State restored: boolean = false;
  @State reasoning: boolean = true;
  @State file: string = '';
  @State selectedModel: string = 'haiku';
  @State selectedEffort: string = 'Medium';

  build() {
    Column({ space: 16 }) {
      if (this.name === 'chain-of-thought') {
        AIMessage({ role: AIMessageRole.User }) { AIText({ text: 'How should we build the HarmonyOS version?' }) }
        AIChainOfThought({ steps })
      } else if (this.name === 'checkpoint') {
        AIMessage() { AIText({ text: 'Renamed Button to Action in the demo.' }) }
        AICheckpoint({ title: this.restored ? 'Checkpoint restored' : 'Restore checkpoint', active: !this.restored,
          onRestore: () => { this.restored = true; this.notice = 'Local checkpoint restored.'; } })
        if (!this.restored) AIText({ text: 'Updated the documentation to match.' })
      } else if (this.name === 'confirmation') {
        AIConfirmation({ title: 'Clean up the build folder?',
          description: 'This local demo records your choice.',
          decision: this.decision, executionStatus: AIStatus.Completed,
          output: 'Demo completed. No files were removed.',
          onDecision: async decision => { this.decision = decision; } })
        AIButton({ label: 'Reset', variant: 'outline', active: this.decision !== AIConfirmationDecision.Pending,
          onPress: () => { this.decision = AIConfirmationDecision.Pending; } })
      } else if (this.name === 'context') {
        AIContext({ input: 8420, output: 1260, reasoning: 980, limit: 128000 })
      } else if (this.name === 'file-tree') {
        AIFileTree({ nodes: files, selection: this.file, onSelect: node => {
          this.file = node.id;
          this.notice = 'Selected ' + node.name;
        } })
      } else if (this.name === 'inline-citation') {
        AICitedText({ parts: [
          { text: 'Build native HarmonyOS interfaces with ' },
          { text: 'ArkUI', sources },
          { text: '. The gallery uses the same JSONL examples as the Swift and Compose ports.' }
        ] })
      } else if (this.name === 'message') {
        AIMessage({ role: AIMessageRole.User }) { AIText({ text: 'How do I add a settings dialog?' }) }
        AIMessage() {
          AIMessageResponse({ text: 'Use a **native dialog** for a short choice.\n\n```arkts\n@State showSettings: boolean = false;\n```\nFor more, see [ArkUI](https://developer.huawei.com/consumer/en/arkui/).' })
          AIMessageActions({ text: 'Use a native dialog for a short choice.',
            onRetry: () => { this.notice = 'Retry requested locally.'; },
            onFeedback: feedback => { this.notice = 'Feedback: ' + (feedback || 'cleared'); } })
        }
      } else if (this.name === 'model-selector') {
        AIModelSelector({ models, selectedID: this.selectedModel, effort: this.selectedEffort,
          onSelect: id => { this.selectedModel = id; }, onEffortChange: effort => { this.selectedEffort = effort; } })
      } else if (this.name === 'prompt-input' || this.name === 'suggestion') {
        Composer({ suggestions: this.name === 'suggestion', onSubmit: submission => {
          this.notice = 'Submitted locally' + (submission.text ? ': ' + submission.text : '') +
            (submission.attachments.length ? ' · ' + submission.attachments.length + ' attachments' : '');
        } })
      } else if (this.name === 'plan') {
        AIPlan({ title: 'HarmonyOS port', steps })
      } else if (this.name === 'queue') {
        AIQueue({ items: steps, onSelect: step => { this.notice = 'Selected: ' + step.title; } })
      } else if (this.name === 'reasoning') {
        AIReasoning({ text: 'Inspecting the theme and component boundaries before adapting the controls.',
          streaming: this.reasoning, durationSeconds: 4 })
        AIButton({ label: this.reasoning ? 'Finish thinking' : 'Replay', variant: 'outline',
          onPress: () => { this.reasoning = !this.reasoning; } })
      } else if (this.name === 'sources') {
        AISources({ sources })
      } else if (this.name === 'stack-trace') {
        AIStackTrace({ error: 'Error: missing state binding', frames: [
          { id: '1', name: 'renderInput', file: 'GenerativeUI.ets', line: 42 },
          { id: '2', name: 'refresh', file: 'GenerativeUI.ets', line: 116 },
          { id: '3', name: 'dispatch', file: 'ArkUI', line: 1, framework: true }
        ], onOpenSource: frame => { this.notice = 'Open ' + frame.file + ':' + frame.line; } })
      } else if (this.name === 'subagent') {
        AISubagent({ title: 'Inspect components', status: AIStatus.Completed }) {
          AIText({ text: 'Reviewed native controls and checked the component catalog.' })
          AIPlan({ title: 'Review', steps: [{ id: 'review', title: 'Review the exported API', status: AIStatus.Completed }] })
        }
      } else if (this.name === 'task') {
        AITask({ title: 'Prepare the HarmonyOS gallery', steps })
      } else if (this.name === 'terminal') {
        AITerminal({ command: 'hvigorw assembleHap', output: 'Demo output\n> hvigor Finished :gallery:assembleHap\nBUILD SUCCESSFUL' })
      } else if (this.name === 'test-results') {
        AITestResults({ title: 'Protocol tests', tests: [
          { id: 'split', name: 'Handle split UTF-8', status: AIStatus.Completed, suite: 'Stream decoder' },
          { id: 'order', name: 'Reject stale revisions', status: AIStatus.Completed, suite: 'Surface reducer' },
          { id: 'fail', name: 'Example failing assertion', status: AIStatus.Failed, suite: 'Surface reducer',
            detail: 'Demo failure: expected revision 3, received 2.' },
          { id: 'network', name: 'Network integration', status: AIStatus.Skipped, suite: 'Host' }
        ] })
      } else if (this.name === 'tool') {
        AITool({ name: 'Read Theme.ets', status: AIStatus.Completed,
          input: '{"path":"Theme.ets"}', output: 'Found light and dark palettes.' })
        AITool({ name: 'Build the demo', status: AIStatus.Running })
        AITool({ name: 'Example failed task', status: AIStatus.Failed, output: 'Demo error: missing input.' })
      }
      if (this.notice) AIText({ text: this.notice, variant: 'muted' })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
