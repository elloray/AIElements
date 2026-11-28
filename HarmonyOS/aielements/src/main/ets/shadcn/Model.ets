import { shadcnExamples } from './CatalogData';

export interface AIShadcnItem {
  label: string;
  id?: string;
  detail?: string;
  icon?: string;
  disabled?: boolean;
}

export interface AIShadcnNode {
  kind: string;
  id?: string;
  label?: string;
  heading?: string;
  detail?: string;
  value?: string;
  placeholder?: string;
  action?: string;
  variant?: string;
  icon?: string;
  asset?: string;
  align?: string;
  width?: number;
  height?: number;
  size?: number;
  gap?: number;
  items?: AIShadcnItem[];
  children?: AIShadcnNode[];
  columns?: string[];
  rows?: string[][];
  rowIDs?: string[];
  filterColumn?: number;
}

export interface AIShadcnExample {
  id: string;
  title: string;
  summary: string;
  section?: string;
  selector?: string;
  root: AIShadcnNode;
}

export function loadAIShadcnCatalog(): AIShadcnExample[] {
  return shadcnExamples.map((entry: string): AIShadcnExample => JSON.parse(entry) as AIShadcnExample);
}

@Observed
export class AIShadcnState {
  values: Map<string, string> = new Map<string, string>();

  set(key: string, value: string): void {
    const next = new Map<string, string>(this.values);
    next.set(key, value);
    this.values = next;
  }

  remove(key: string): void {
    if (!this.values.has(key)) return;
    const next = new Map<string, string>(this.values);
    next.delete(key);
    this.values = next;
  }
}
