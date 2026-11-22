import {
  AIUIDocument, AIUIEvent, AIUINode, AIUIObject, AIUIStreamEvent, AIUIValue, dictionary, own, utf8Length
} from './Models';
import { requireValid, validateDocument, validateEvent } from './Validation';

const maximumDocumentBytes = 1024 * 1024;
const hex = '0123456789abcdef';

function decodeUtf8(bytes: Uint8Array): string {
  // URI decoding enforces strict UTF-8 and is available in both ArkTS and host JS.
  const blocks: string[] = [];
  let block = '';
  for (const byte of bytes) {
    block += '%' + hex[byte >> 4] + hex[byte & 15];
    if (block.length >= 12288) {
      blocks.push(block);
      block = '';
    }
  }
  blocks.push(block);
  try {
    return decodeURIComponent(blocks.join(''));
  } catch {
    throw new Error('Invalid UTF-8 in UI stream.');
  }
}

export function decodeDocument(data: string | Uint8Array): AIUIDocument {
  const length = typeof data === 'string' ? utf8Length(data) : data.length;
  requireValid(length <= maximumDocumentBytes, 'UI document exceeds 1 MiB.');
  const doc = JSON.parse(typeof data === 'string' ? data : decodeUtf8(data)) as AIUIDocument;
  validateDocument(doc);
  return doc;
}

export class AIUIStreamDecoder {
  private buffer: Uint8Array;
  private length = 0;

  constructor(readonly maximumLineBytes: number = maximumDocumentBytes) {
    requireValid(Number.isSafeInteger(maximumLineBytes) && maximumLineBytes > 0, 'Invalid line size limit.');
    this.buffer = new Uint8Array(Math.min(1024, maximumLineBytes));
  }

  append(bytes: Uint8Array, onEvent: (event: AIUIStreamEvent) => void): void {
    for (const byte of bytes) {
      if (byte === 10) {
        this.finish(onEvent);
      } else {
        requireValid(this.length < this.maximumLineBytes, 'UI stream line exceeds size limit.');
        if (this.length === this.buffer.length) {
          const buffer = new Uint8Array(Math.min(this.buffer.length * 2, this.maximumLineBytes));
          buffer.set(this.buffer);
          this.buffer = buffer;
        }
        this.buffer[this.length++] = byte;
      }
    }
  }

  finish(onEvent: (event: AIUIStreamEvent) => void): void {
    const line = this.buffer.subarray(0, this.length);
    this.length = 0;
    if (line.some(byte => byte !== 9 && byte !== 13 && byte !== 32)) {
      const event = JSON.parse(decodeUtf8(line)) as AIUIStreamEvent;
      validateEvent(event);
      onEvent(event);
    }
  }

  reset(): void {
    this.length = 0;
  }
}

export type AIUIPhase = 'idle' | 'streaming' | 'complete' | 'failed' | 'removed';

export class AIUISession {
  private current?: AIUIDocument;
  private status: AIUIPhase = 'idle';
  private failure?: string;
  private eventSequence = 0;

  constructor(document?: AIUIDocument) {
    if (document) {
      validateDocument(document);
      this.current = document;
      this.status = 'complete';
    }
  }

  get document(): AIUIDocument | undefined { return this.current; }
  get phase(): AIUIPhase { return this.status; }
  get errorMessage(): string | undefined { return this.failure; }

  apply(event: AIUIStreamEvent): void {
    validateEvent(event);
    if (event.kind === 'surface.begin') {
      requireValid(this.status === 'idle' || this.status === 'removed', 'Surface already exists.');
      requireValid(event.root !== undefined, 'A begin event requires a root.');
      const next: AIUIDocument = {
        version: '1.0', id: event.surfaceID, revision: event.revision, root: event.root,
        nodes: event.nodes ?? {}, state: event.state ?? {}
      };
      validateDocument(next, true);
      this.commit(next, 'streaming');
      return;
    }
    const current = this.current;
    requireValid(current, 'No surface.');
    const revision = current.revision ?? 0;
    requireValid(event.surfaceID === current.id && event.baseRevision === revision && event.revision === revision + 1,
      'Out-of-order UI event. Request a fresh snapshot.');
    requireValid(this.status !== 'failed' || event.kind === 'surface.remove', 'Failed surface is frozen.');
    if (event.kind === 'surface.remove') {
      this.commit(undefined, 'removed');
      return;
    }
    if (event.kind === 'surface.error') {
      this.commit({ ...current, revision: event.revision }, 'failed', event.message ?? 'Generation interrupted.');
      return;
    }
    const nodes = Object.assign(dictionary<AIUINode>(), current.nodes);
    for (const id of event.removeNodes ?? []) delete nodes[id];
    Object.assign(nodes, event.nodes);
    const next: AIUIDocument = {
      ...current, root: event.root ?? current.root, revision: event.revision, nodes,
      state: Object.assign(dictionary<AIUIValue>(), current.state, event.state)
    };
    const complete = event.kind === 'surface.complete';
    validateDocument(next, !complete);
    this.commit(next, complete ? 'complete' : 'streaming');
  }

  interrupt(message = 'Generation interrupted. Replay to start again.'): void {
    if (this.status === 'streaming') this.commit(this.current, 'failed', message);
  }

  setValue(nodeID: string, value: AIUIValue): void {
    const current = this.current;
    requireValid(current, 'No surface.');
    const key = own(current.nodes, nodeID)?.bindings?.value;
    requireValid(key !== undefined, 'Control has no state binding.');
    const state = Object.assign(dictionary<AIUIValue>(), current.state);
    state[key] = value;
    const next = { ...current, state };
    validateDocument(next, this.status === 'streaming' || this.status === 'failed');
    this.current = next;
  }

  event(nodeID: string, event: string, value: AIUIValue = null): AIUIEvent | undefined {
    const doc = this.current;
    if (!doc) return undefined;
    const action = own(own(doc.nodes, nodeID)?.events ?? {}, event);
    if (!action) return undefined;
    const state: AIUIObject = dictionary();
    for (const key of action.stateKeys ?? []) {
      const item = own(doc.state ?? {}, key);
      if (item !== undefined) state[key] = item;
    }
    this.eventSequence++;
    return {
      version: '1.0', id: `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}-${this.eventSequence}`,
      surfaceID: doc.id, revision: doc.revision ?? 0, nodeID, event, name: action.name,
      value, payload: action.payload ?? {}, state
    };
  }

  private commit(document: AIUIDocument | undefined, phase: AIUIPhase, errorMessage?: string): void {
    this.current = document;
    this.status = phase;
    this.failure = errorMessage;
  }
}
