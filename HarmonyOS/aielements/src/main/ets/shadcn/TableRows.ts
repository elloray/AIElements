export interface ShadcnTableRow {
  id: string;
  index: number;
  cells: string[];
}

export function shadcnTableRows(rows: string[][], rowIDs: string[] | undefined,
  query: string, column: number, ascending: boolean, filterColumn?: number): ShadcnTableRow[] {
  const hasIDs = rowIDs !== undefined && rowIDs.length === rows.length &&
    !rowIDs.includes('') && new Set(rowIDs).size === rows.length;
  const filter = query.toLowerCase();
  const result: ShadcnTableRow[] = [];
  rows.forEach((cells: string[], index: number) => {
    const matches = !filter || (filterColumn === undefined
      ? cells.some((cell: string) => cell.toLowerCase().includes(filter))
      : (cells[filterColumn] ?? '').toLowerCase().includes(filter));
    if (matches) {
      result.push({ id: hasIDs ? rowIDs![index] : String(index), index, cells });
    }
  });
  if (column >= 0) {
    result.sort((a: ShadcnTableRow, b: ShadcnTableRow) =>
      (a.cells[column] ?? '').localeCompare(b.cells[column] ?? '') * (ascending ? 1 : -1) || a.index - b.index);
  }
  return result;
}
