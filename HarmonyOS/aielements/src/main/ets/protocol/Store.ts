import { AIUIDocument, AIUIEvent, AIUIStreamEvent, AIUIValue, utf8Length } from './Models';
import { AIUIPhase, AIUISession, AIUIStreamDecoder } from './Streaming';

export class AIUIStore {
  private session: AIUISession;
  private decoder = new AIUIStreamDecoder();
  private listeners = new Set<() => void>();
  private transportError?: string;
  private editError?: string;

  constructor(document?: AIUIDocument) {
    this.session = new AIUISession(document);
  }

  get document(): AIUIDocument | undefined { return this.session.document; }
  get phase(): AIUIPhase { return this.transportError ? 'failed' : this.session.phase; }
  get errorMessage(): string | undefined { return this.transportError ?? this.editError ?? this.session.errorMessage; }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => { this.listeners.delete(listener); };
  }

  reset(document?: AIUIDocument): void {
    this.session = new AIUISession(document);
    this.decoder.reset();
    this.transportError = undefined;
    this.editError = undefined;
    this.publish();
  }

  receive(bytes: Uint8Array): void {
    this.read(() => this.decoder.append(bytes, event => this.apply(event)));
  }

  /** Each call contains one already-decoded JSON frame, without a line terminator. */
  receiveLine(line: string): void {
    this.read(() => {
      if (/^[\t\r ]*$/.test(line)) return;
      if (utf8Length(line) > this.decoder.maximumLineBytes) throw new Error('UI stream line exceeds size limit.');
      this.apply(JSON.parse(line) as AIUIStreamEvent);
    });
  }

  finish(): void {
    this.read(() => this.decoder.finish(event => this.apply(event)));
    this.interrupt();
  }

  interrupt(message?: string): void {
    this.decoder.reset();
    this.session.interrupt(message);
    this.publish();
  }

  setValue(nodeID: string, value: AIUIValue): boolean {
    try {
      this.session.setValue(nodeID, value);
      this.editError = undefined;
    } catch (error) {
      this.editError = error instanceof Error ? error.message : 'Invalid input.';
      this.publish();
      return false;
    }
    this.publish();
    return true;
  }

  event(nodeID: string, event: string, value: AIUIValue = null): AIUIEvent | undefined {
    if (this.phase === 'failed' && event === 'press') return undefined;
    return this.session.event(nodeID, event, value);
  }

  private apply(event: AIUIStreamEvent): void {
    this.session.apply(event);
    this.editError = undefined;
    this.publish();
  }

  private read(operation: () => void): void {
    if (this.transportError) throw new Error(this.transportError);
    try {
      operation();
    } catch (error) {
      this.transportError = error instanceof Error ? error.message : 'Invalid UI stream.';
      this.session.interrupt(this.transportError);
      this.publish();
      throw error;
    }
  }

  private publish(): void {
    for (const listener of this.listeners) listener();
  }
}
