export interface AIInlineRun {
  text: string;
  style: string;
  url?: string;
}

export interface AIMessageBlock {
  kind: string;
  runs: AIInlineRun[];
  code: string;
  language: string;
}

export function inlineRuns(text: string): AIInlineRun[] {
  const runs: AIInlineRun[] = [];
  const tokens = /\*\*([^*\n]+)\*\*|`([^`\n]+)`|\[([^\]\n]+)\]\((https?:\/\/[^\s)]+)\)/g;
  let start = 0;
  let token: RegExpExecArray | null;
  while ((token = tokens.exec(text)) !== null) {
    if (token.index > start) runs.push({ text: text.slice(start, token.index), style: 'plain' });
    if (token[1]) runs.push({ text: token[1], style: 'strong' });
    else if (token[2]) runs.push({ text: token[2], style: 'code' });
    else runs.push({ text: token[3], style: 'link', url: token[4] });
    start = tokens.lastIndex;
  }
  if (start < text.length) runs.push({ text: text.slice(start), style: 'plain' });
  return runs;
}

export function messageBlocks(value: string): AIMessageBlock[] {
  const blocks: AIMessageBlock[] = [];
  let paragraph: string[] = [];
  let code: string[] = [];
  let language: string | undefined;
  const flushParagraph = (): void => {
    if (paragraph.length === 0) return;
    blocks.push({ kind: 'paragraph', runs: inlineRuns(paragraph.join('\n')), code: '', language: '' });
    paragraph = [];
  };
  const flushCode = (): void => {
    blocks.push({ kind: 'code', runs: [], code: code.join('\n'), language: language ?? '' });
    code = [];
    language = undefined;
  };
  for (const line of value.replace(/\r\n/g, '\n').split('\n')) {
    if (language !== undefined) {
      if (/^```\s*$/.test(line)) flushCode();
      else code.push(line);
    } else if (/^```[^\s`]*\s*$/.test(line)) {
      flushParagraph();
      language = line.slice(3).trim();
    } else if (/^#{1,6}\s/.test(line)) {
      flushParagraph();
      blocks.push({ kind: 'title', runs: inlineRuns(line.replace(/^#+\s+/, '')), code: '', language: '' });
    } else if (line.trim() === '') {
      flushParagraph();
    } else {
      paragraph.push(line.replace(/^[-*] /, '• '));
    }
  }
  flushParagraph();
  if (language !== undefined) flushCode();
  return blocks;
}
