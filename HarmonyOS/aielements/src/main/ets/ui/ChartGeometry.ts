/** Natural cubic spline with zero curvature at the endpoints, as in the Compose renderer. */
export function naturalDerivatives(values: number[]): number[] {
  const count = values.length;
  if (count < 2) return values.map(() => 0);
  const diagonal = values.map(() => 4);
  diagonal[0] = 2;
  diagonal[count - 1] = 2;
  const rhs = values.map(() => 0);
  rhs[0] = 3 * (values[1] - values[0]);
  rhs[count - 1] = 3 * (values[count - 1] - values[count - 2]);
  for (let index = 1; index < count - 1; index++) {
    rhs[index] = 3 * (values[index + 1] - values[index - 1]);
  }
  for (let index = 1; index < count; index++) {
    const factor = 1 / diagonal[index - 1];
    diagonal[index] -= factor;
    rhs[index] -= factor * rhs[index - 1];
  }
  rhs[count - 1] /= diagonal[count - 1];
  for (let index = count - 2; index >= 0; index--) {
    rhs[index] = (rhs[index] - rhs[index + 1]) / diagonal[index];
  }
  return rhs;
}

export function chartDomain(values: number[]): number[] {
  let low = 0;
  let high = 0;
  for (const value of values) {
    if (Number.isFinite(value) && Math.abs(value) <= 1e15) {
      low = Math.min(low, value);
      high = Math.max(high, value);
    }
  }
  const range = Math.max(1, high - low);
  const power = Math.pow(10, Math.floor(Math.log10(range / 4)));
  const step = Math.ceil(range / 4 / power) * power;
  const minimum = Math.floor(low / step) * step;
  return [minimum, Math.max(minimum + step, Math.ceil(high / step) * step)];
}
