export interface GalleryExample {
  id: string;
  title: string;
}

export const patterns: GalleryExample[] = [
  { id: 'chain-of-thought', title: 'Chain of Thought' },
  { id: 'chat', title: 'Chat' },
  { id: 'checkpoint', title: 'Checkpoint' },
  { id: 'confirmation', title: 'Confirmation' },
  { id: 'context', title: 'Context' },
  { id: 'file-tree', title: 'File Tree' },
  { id: 'inline-citation', title: 'Inline Citation' },
  { id: 'message', title: 'Message' },
  { id: 'model-selector', title: 'Model Selector' },
  { id: 'plan', title: 'Plan' },
  { id: 'prompt-input', title: 'Prompt Input' },
  { id: 'queue', title: 'Queue' },
  { id: 'reasoning', title: 'Reasoning' },
  { id: 'sources', title: 'Sources' },
  { id: 'stack-trace', title: 'Stack Trace' },
  { id: 'subagent', title: 'Subagent' },
  { id: 'suggestion', title: 'Suggestion' },
  { id: 'task', title: 'Task' },
  { id: 'terminal', title: 'Terminal' },
  { id: 'test-results', title: 'Test Results' },
  { id: 'tool', title: 'Tool' }
];

export const foundations: GalleryExample[] = [
  { id: 'stack', title: 'Stack' }, { id: 'row', title: 'Row' }, { id: 'card', title: 'Card' },
  { id: 'text', title: 'Text' }, { id: 'button', title: 'Button' }, { id: 'badge', title: 'Badge' },
  { id: 'input', title: 'Input' }, { id: 'select', title: 'Select' }, { id: 'switch', title: 'Switch' },
  { id: 'progress', title: 'Progress' }, { id: 'separator', title: 'Separator' }, { id: 'table', title: 'Table' },
  { id: 'bar-chart', title: 'Bar Chart' }, { id: 'line-chart', title: 'Line Chart' }, { id: 'area-chart', title: 'Area Chart' }
];

export const streaming: GalleryExample[] = [{ id: 'generative-ui', title: 'Generative UI' }];
