export type AIUIPrimitive = null | boolean | number | string;
export type AIUIValue = AIUIPrimitive | AIUIValue[] | AIUIObject;
export interface AIUIObject { [key: string]: AIUIValue }
export interface AIUIAction {
  name: string;
  payload?: AIUIObject;
  stateKeys?: string[];
}
export interface AIUINode {
  type: string;
  props?: AIUIObject;
  children?: string[];
  bindings?: Record<string, string>;
  events?: Record<string, AIUIAction>;
}
export interface AIUIDocument {
  version?: string;
  id: string;
  revision?: number;
  root: string;
  nodes: Record<string, AIUINode>;
  state?: AIUIObject;
}
export interface AIUIStreamEvent {
  version?: string;
  kind: string;
  surfaceID: string;
  revision: number;
  baseRevision?: number;
  root?: string;
  nodes?: Record<string, AIUINode>;
  removeNodes?: string[];
  state?: AIUIObject;
  message?: string;
}
export interface AIUIEvent {
  version: string;
  id: string;
  surfaceID: string;
  revision: number;
  nodeID: string;
  event: string;
  name: string;
  value: AIUIValue;
  payload: AIUIObject;
  state: AIUIObject;
}

export const AIUIComponentCatalog: Readonly<Record<string, readonly string[]>> = {
  Stack: ['gap'], Row: ['gap'],
  Card: ['style', 'title', 'description', 'footer', 'footerIcon', 'footnote'],
  Text: ['text', 'variant'], Button: ['label', 'variant', 'disabled'],
  Badge: ['text', 'variant'], Input: ['label', 'placeholder', 'value', 'disabled'],
  Select: ['placeholder', 'label', 'value', 'options', 'disabled'], Switch: ['label', 'value', 'disabled'],
  Progress: ['label', 'value', 'max'], Separator: [], Table: ['columns', 'rows', 'caption', 'footer'],
  BarChart: ['data', 'series', 'height', 'label', 'legend'],
  LineChart: ['data', 'series', 'height', 'label', 'legend'],
  AreaChart: ['data', 'series', 'height', 'label', 'legend']
};

export function own<T>(object: Record<string, T>, key: string): T | undefined {
  return Object.prototype.hasOwnProperty.call(object, key) ? object[key] : undefined;
}

export function dictionary<T>(): Record<string, T> {
  return Object.create(null) as Record<string, T>;
}

export function resolvedProps(node: AIUINode, state: AIUIObject): AIUIObject {
  const result: AIUIObject = Object.assign(dictionary<AIUIValue>(), node.props);
  for (const [property, key] of Object.entries(node.bindings ?? {})) {
    const value = own(state, key);
    if (value === undefined) {
      delete result[property];
    } else {
      result[property] = value;
    }
  }
  return result;
}

export function utf8Length(text: string): number {
  let bytes = 0;
  for (const character of text) {
    const code = character.codePointAt(0)!;
    bytes += code < 0x80 ? 1 : code < 0x800 ? 2 : code < 0x10000 ? 3 : 4;
  }
  return bytes;
}
