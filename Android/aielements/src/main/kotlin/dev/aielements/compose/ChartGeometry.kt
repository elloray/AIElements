package dev.aielements.compose

import kotlin.math.*

/** Natural cubic spline, matching the reference renderer (zero curvature at both ends). */
internal fun naturalDerivatives(values: List<Float>): List<Float> {
    val n = values.size
    if (n < 2) return List(n) { 0f }
    val diagonal = FloatArray(n) { 4f }; diagonal[0] = 2f; diagonal[n - 1] = 2f
    val rhs = FloatArray(n)
    rhs[0] = 3 * (values[1] - values[0]); rhs[n - 1] = 3 * (values[n - 1] - values[n - 2])
    for (i in 1 until n - 1) rhs[i] = 3 * (values[i + 1] - values[i - 1])
    for (i in 1 until n) { val factor = 1f / diagonal[i - 1]; diagonal[i] -= factor; rhs[i] -= factor * rhs[i - 1] }
    rhs[n - 1] /= diagonal[n - 1]
    for (i in n - 2 downTo 0) rhs[i] = (rhs[i] - rhs[i + 1]) / diagonal[i]
    return rhs.toList()
}
internal fun chartDomain(values: List<Double>): Pair<Double, Double> {
    val finite = values.filter { it.isFinite() && abs(it) <= 1e15 }
    val low = min(0.0, finite.minOrNull() ?: 0.0); val high = max(0.0, finite.maxOrNull() ?: 1.0)
    val range = max(1.0, high - low); val power = 10.0.pow(floor(log10(range / 4)))
    val step = ceil(range / 4 / power) * power
    val minimum = floor(low / step) * step
    return minimum to max(minimum + step, ceil(high / step) * step)
}
