import { AIButton, AICodeBlock, AIColors, AIRow, AIText, AIUIEvent, AIUIRenderer, AIUIStore,
  decodeDocument } from '@aielements/arkui';

@Component
export struct StreamDemo {
  @Prop example: string = 'generative-ui';
  @State running: boolean = false;
  @State callback: string = '';
  @State failure: string = '';
  private store: AIUIStore = new AIUIStore();
  private timer: number = -1;

  aboutToAppear(): void {
    if (this.example === 'generative-ui') this.replay();
    else this.load();
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) clearTimeout(this.timer);
  }

  private read(name: string): Uint8Array {
    const context = this.getUIContext().getHostContext();
    if (!context) throw new Error('Gallery resources are unavailable.');
    return context.resourceManager.getRawFileContentSync(name);
  }

  private load(): void {
    try {
      this.store.reset(decodeDocument(this.read(this.example + '.json')));
    } catch {
      this.failure = 'This example could not be loaded.';
    }
  }

  private replay(): void {
    this.store.reset();
    this.callback = '';
    this.failure = '';
    try {
      const bytes = this.read('dashboard.jsonl');
      this.running = true;
      this.next(bytes, 0);
    } catch {
      this.running = false;
      this.failure = 'The dashboard example could not be loaded.';
    }
  }

  private next(bytes: Uint8Array, offset: number): void {
    this.timer = -1;
    try {
      const separator = bytes.indexOf(10, offset);
      const end = separator < 0 ? bytes.length : separator + 1;
      this.store.receive(bytes.subarray(offset, end));
      if (end === bytes.length) {
        this.store.finish();
        this.running = false;
      } else {
        this.timer = setTimeout(() => this.next(bytes, end), 220);
      }
    } catch {
      this.running = false;
    }
  }

  private stop(): void {
    if (this.timer !== -1) clearTimeout(this.timer);
    this.timer = -1;
    this.running = false;
    this.store.interrupt('Generation stopped. Replay to start again.');
  }

  build() {
    Column({ space: 16 }) {
      if (this.example === 'generative-ui') {
        AIRow() {
          AIButton({ label: 'Replay', active: !this.running, onPress: () => this.replay() })
          AIButton({ label: 'Stop', variant: 'outline', active: this.running, onPress: () => this.stop() })
        }
      }
      if (this.failure) AIText({ text: this.failure, color: AIColors.destructive })
      AIUIRenderer({ store: this.store, onEvent: (event: AIUIEvent) => {
        this.callback = JSON.stringify(event, null, 2);
      } })
      if (this.callback) AICodeBlock({ code: this.callback, language: 'Host callback' })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
