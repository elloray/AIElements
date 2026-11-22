import { AIUIDocument, AIUINode, AIUIObject, AIUIValue, dictionary, own, resolvedProps } from '../protocol/Models';

interface DisplayOption { label: string; value: string }
interface DisplayColumn { key: string; label: string; width?: number; trailing: boolean; emphasized: boolean }
interface DisplayRow { id: string; cells: string[] }
interface DisplaySeries { key: string; label: string }
interface DisplayChartRow { label: string; values: number[] }

function objects(value: AIUIValue | undefined): AIUIObject[] {
  return Array.isArray(value) ? value as AIUIObject[] : [];
}

function string(value: AIUIValue | undefined, fallback = ''): string {
  return typeof value === 'string' ? value : fallback;
}

function display(value: AIUIValue | undefined): string {
  if (value === null || value === undefined) return '—';
  if (typeof value === 'boolean') return value ? 'Yes' : 'No';
  if (typeof value === 'number' || typeof value === 'string') return String(value);
  return '';
}

export class AIUIDisplayNode {
  readonly type: string;
  readonly bound: boolean;
  readonly hasPress: boolean;
  readonly children: AIUIDisplayNode[] = [];
  readonly props: AIUIObject;

  constructor(readonly id: string, node?: AIUINode, state: AIUIObject = {}) {
    this.type = node?.type ?? '';
    this.props = node ? resolvedProps(node, state) : {};
    this.bound = typeof node?.bindings?.value === 'string';
    this.hasPress = node?.events?.press !== undefined;
  }

  text(key: string, fallback = ''): string { return string(own(this.props, key), fallback); }
  number(key: string, fallback: number): number {
    const value = own(this.props, key);
    return typeof value === 'number' ? value : fallback;
  }
  flag(key: string): boolean { return own(this.props, key) === true; }

  options(): DisplayOption[] {
    return objects(this.props.options).map(option => ({ label: string(option.label), value: string(option.value) }));
  }

  columns(): DisplayColumn[] {
    return objects(this.props.columns).map(column => ({
      key: string(column.key), label: string(column.label), width: typeof column.width === 'number' ? column.width : undefined,
      trailing: column.alignment === 'trailing', emphasized: column.emphasized === true
    }));
  }

  tableRows(): DisplayRow[] {
    const columns = this.columns();
    return objects(this.props.rows).map((row, index) => ({
      id: String(index), cells: columns.map(column => display(own(row, column.key)))
    }));
  }

  tableFooter(): string[] {
    const footer = this.props.footer;
    if (!footer || typeof footer !== 'object' || Array.isArray(footer)) return [];
    return this.columns().map(column => display(own(footer, column.key)));
  }

  series(): DisplaySeries[] {
    return objects(this.props.series).map(series => ({ key: string(series.key), label: string(series.label) }));
  }

  chartRows(): DisplayChartRow[] {
    const series = this.series();
    return objects(this.props.data).map(row => ({
      label: string(row.label), values: series.map(item => Number(own(row, item.key) ?? 0))
    }));
  }

  chartSelection(row: DisplayChartRow): AIUIObject {
    const value: AIUIObject = dictionary();
    value.label = row.label;
    this.series().forEach((series, index) => { value[series.key] = row.values[index] ?? 0; });
    return value;
  }
}

export function displaySurface(document?: AIUIDocument): AIUIDisplayNode | undefined {
  if (!document) return undefined;
  function load(id: string, doc: AIUIDocument): AIUIDisplayNode {
    const node = own(doc.nodes, id);
    const view = new AIUIDisplayNode(id, node, doc.state);
    for (const child of node?.children ?? []) view.children.push(load(child, doc));
    return view;
  }
  return load(document.root, document);
}
