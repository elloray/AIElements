import {
  AIUIComponentCatalog, AIUIDocument, AIUIObject, AIUIStreamEvent, own, resolvedProps, utf8Length
} from './Models';

export function requireValid(condition: unknown, message: string): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

function object(value: unknown): value is AIUIObject {
  if (value === null || typeof value !== 'object') return false;
  const prototype = Object.getPrototypeOf(value);
  return prototype === null || prototype === Object.prototype;
}

function identifier(value: unknown): value is string {
  return typeof value === 'string' && value.length > 0 && value.length <= 128;
}

function revision(value: unknown): value is number {
  return typeof value === 'number' && Number.isSafeInteger(value) && value >= 0;
}

function inRange(value: unknown, min: number, max: number): boolean {
  return typeof value === 'number' && value >= min && value <= max;
}

function validateValue(value: unknown, depth = 0): void {
  requireValid(depth <= 16, 'Value nesting exceeds 16 levels.');
  if (typeof value === 'string') {
    requireValid(utf8Length(value) <= 32768, 'Text exceeds 32 KiB.');
  } else if (typeof value === 'number') {
    requireValid(Number.isFinite(value) && Math.abs(value) <= 1e15, 'Invalid number.');
  } else if (Array.isArray(value)) {
    requireValid(value.length <= 1000, 'Array exceeds 1000 entries.');
    for (const item of value) validateValue(item, depth + 1);
  } else if (object(value)) {
    const entries = Object.entries(value);
    requireValid(entries.length <= 256, 'Object exceeds 256 keys.');
    for (const [key, item] of entries) {
      requireValid(key.length <= 128, 'Object key exceeds 128 characters.');
      validateValue(item, depth + 1);
    }
  } else {
    requireValid(value === null || typeof value === 'boolean', 'Invalid JSON value.');
  }
}

const textProps = new Set(['title', 'description', 'footer', 'footerIcon', 'footnote', 'text', 'variant', 'label',
  'placeholder', 'caption']);
const booleanProps = new Set(['disabled', 'legend']);
const numericProps = new Set(['height', 'gap', 'max']);

function keyedItems(value: unknown, name: string, min: number, max: number, key: string): AIUIObject[] {
  requireValid(Array.isArray(value) && value.length >= min && value.length <= max,
    `${name} must have ${min}–${max} entries.`);
  const keys = new Set<string>();
  for (const item of value) {
    requireValid(object(item) && typeof item.label === 'string', `${name} require text labels.`);
    const id = item[key];
    requireValid(typeof id === 'string' && !keys.has(id), `${name} require unique keys.`);
    keys.add(id);
  }
  return value as AIUIObject[];
}

function validateProps(props: AIUIObject, type: string, incomplete: boolean): void {
  for (const [key, value] of Object.entries(props)) {
    if (textProps.has(key) && !(type === 'Table' && key === 'footer')) {
      requireValid(typeof value === 'string', `${key} must be text.`);
    }
    if (booleanProps.has(key)) requireValid(typeof value === 'boolean', `${key} must be boolean.`);
    if (numericProps.has(key)) requireValid(typeof value === 'number', `${key} must be numeric.`);
  }
  const { value, variant, footerIcon, style, height, gap } = props;
  if (footerIcon !== undefined) requireValid(footerIcon === 'trending-up', 'Unknown footer icon.');
  if (style !== undefined) requireValid(style === 'standard' || style === 'chart', 'Unknown card style.');
  if (height !== undefined) requireValid(inRange(height, 120, 600), 'Height must be 120–600.');
  if (gap !== undefined) requireValid(inRange(gap, 0, 48), 'Gap must be 0–48.');
  if (typeof variant === 'string') {
    const variants = type === 'Text' ? ['body', 'title', 'caption', 'muted', 'label'] :
      ['primary', 'secondary', 'outline', 'ghost', 'destructive'];
    requireValid(variants.includes(variant), 'Unknown variant.');
  }
  if (value !== undefined) {
    const kind = type === 'Switch' ? 'boolean' : type === 'Progress' ? 'number' : 'string';
    requireValid(typeof value === kind, 'Invalid value type.');
  }
  if (type === 'Progress') {
    const max = typeof props.max === 'number' ? props.max : 100;
    requireValid(max > 0 && inRange(value ?? 0, 0, max), 'Progress must be between zero and its positive maximum.');
  }
  if (type === 'Select' && props.options !== undefined) {
    const options = keyedItems(props.options, 'Options', 0, 100, 'value');
    requireValid(value === undefined || value === '' || options.some(option => option.value === value),
      'Selected value is absent from options.');
  }
  if (type.endsWith('Chart')) validateChart(props, incomplete);
  if (type === 'Table') validateTable(props);
}

function validateChart(props: AIUIObject, incomplete: boolean): void {
  requireValid(incomplete || (props.series !== undefined && props.data !== undefined), 'Chart requires series and data.');
  const series = props.series === undefined ? [] : keyedItems(props.series, 'Series', 1, 5, 'key');
  requireValid(series.every(item => item.key !== 'label'), 'Series key cannot be label.');
  if (props.data === undefined) return;
  for (const row of keyedItems(props.data, 'Chart rows', 0, 200, 'label')) {
    for (const item of series) {
      requireValid(typeof own(row, item.key as string) === 'number', 'Chart row is missing a numeric series value.');
    }
  }
}

function validateTable(props: AIUIObject): void {
  if (props.footer !== undefined) requireValid(object(props.footer), 'Table footer must be an object.');
  if (props.rows !== undefined) {
    requireValid(Array.isArray(props.rows) && props.rows.every(object), 'Table rows must be objects.');
  }
  if (props.columns === undefined) return;
  for (const column of keyedItems(props.columns, 'Columns', 1, 12, 'key')) {
    requireValid(column.width === undefined || inRange(column.width, 24, 600), 'Column width must be 24–600.');
    requireValid(column.alignment === undefined || column.alignment === 'leading' || column.alignment === 'trailing',
      'Unknown column alignment.');
    requireValid(column.emphasized === undefined || typeof column.emphasized === 'boolean',
      'Column emphasis must be boolean.');
  }
}

const containers = new Set(['Stack', 'Row', 'Card']);
const controls = new Set(['Input', 'Select', 'Switch']);

export function validateDocument(doc: AIUIDocument, incomplete = false): void {
  requireValid(object(doc) && (doc.version === undefined || doc.version === '1.0'), 'Unsupported UI version.');
  requireValid(identifier(doc.id) && identifier(doc.root) && revision(doc.revision === undefined ? 0 : doc.revision),
    'Invalid surface identity/revision.');
  const state = doc.state === undefined ? {} : doc.state;
  requireValid(object(doc.nodes) && Object.keys(doc.nodes).length <= 256 && object(state) &&
    Object.keys(state).length <= 256, 'Invalid nodes/state or more than 256 entries.');
  for (const value of Object.values(state)) validateValue(value);
  for (const [id, node] of Object.entries(doc.nodes)) {
    requireValid(identifier(id) && object(node) && typeof node.type === 'string', 'Invalid node.');
    const allowed = own(AIUIComponentCatalog, node.type);
    requireValid(allowed, `Unsupported component: ${node.type}`);
    const props = node.props === undefined ? {} : node.props;
    const bindings = node.bindings === undefined ? {} : node.bindings;
    const children = node.children === undefined ? [] : node.children;
    const events = node.events === undefined ? {} : node.events;
    requireValid(object(props) && object(bindings) && object(events), `Invalid properties, bindings or events on ${id}.`);
    requireValid([...Object.keys(props), ...Object.keys(bindings)].every(key => allowed.includes(key)),
      `Unknown property on ${id}.`);
    for (const value of Object.values(props)) validateValue(value);
    for (const key of Object.values(bindings)) {
      requireValid(identifier(key) && (incomplete || own(state, key) !== undefined), `Invalid or missing binding on ${id}.`);
    }
    requireValid(Array.isArray(children) && children.length <= 256 && children.every(identifier) &&
      new Set(children).size === children.length && (children.length === 0 || containers.has(node.type)),
      `Invalid children on ${id}.`);
    for (const [event, action] of Object.entries(events)) {
      const supported = node.type === 'Button' ? 'press' : controls.has(node.type) ? 'change' :
        node.type.endsWith('Chart') ? 'select' : '';
      requireValid(supported !== '' && event === supported && object(action) && identifier(action.name),
        `Invalid action on ${id}.`);
      requireValid(action.stateKeys === undefined || (Array.isArray(action.stateKeys) &&
        action.stateKeys.length <= 256 && action.stateKeys.every(identifier)), `Invalid action state keys on ${id}.`);
      if (action.payload !== undefined) {
        requireValid(object(action.payload), `Invalid action payload on ${id}.`);
        validateValue(action.payload);
      }
    }
    validateProps(resolvedProps(node, state), node.type, incomplete);
  }

  const visiting = new Set<string>();
  const visited = new Set<string>();
  const parents = new Map<string, string>();
  function walk(id: string, depth: number): void {
    requireValid(depth <= 32 && !visiting.has(id), `Cycle or excessive depth at ${id}.`);
    const node = own(doc.nodes, id);
    if (!node) {
      requireValid(incomplete, `Missing node: ${id}`);
      return;
    }
    visiting.add(id);
    for (const child of node.children ?? []) {
      requireValid(!parents.has(child) || parents.get(child) === id, `Multiple parents for ${child}.`);
      parents.set(child, id);
      walk(child, depth + 1);
    }
    visiting.delete(id);
    visited.add(id);
  }
  walk(doc.root, 0);
  for (const id of Object.keys(doc.nodes)) {
    if (!visited.has(id)) walk(id, 0);
  }
}

export function validateEvent(event: AIUIStreamEvent): void {
  requireValid(object(event) && (event.version === undefined || event.version === '1.0') &&
    identifier(event.surfaceID) && revision(event.revision), 'Invalid event identity or version.');
  requireValid(['surface.begin', 'surface.update', 'surface.complete', 'surface.error', 'surface.remove'].includes(event.kind),
    'Unknown event kind.');
  requireValid(event.baseRevision === undefined || revision(event.baseRevision), 'Invalid base revision.');
  requireValid(event.root === undefined || identifier(event.root), 'Invalid event root.');
  requireValid(event.nodes === undefined || (object(event.nodes) && Object.keys(event.nodes).length <= 256), 'Invalid event nodes.');
  requireValid(event.state === undefined || (object(event.state) && Object.keys(event.state).length <= 256), 'Invalid event state.');
  requireValid(event.removeNodes === undefined || (Array.isArray(event.removeNodes) &&
    event.removeNodes.length <= 256 && event.removeNodes.every(identifier)), 'Invalid node removals.');
  requireValid(event.message === undefined || (typeof event.message === 'string' && utf8Length(event.message) <= 32768),
    'Invalid event message.');
}
