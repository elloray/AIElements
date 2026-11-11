package dev.aielements.compose

import org.junit.Assert.*
import org.junit.Test

class ChartGeometryTest {
    @Test fun referenceVisitorsUseNiceAxisBounds() {
        assertEquals(0.0 to 320.0, chartDomain(listOf(186.0, 305.0, 237.0, 73.0, 209.0, 214.0)))
        assertEquals(-60.0 to 60.0, chartDomain(listOf(-50.0, 60.0)))
        val (low, high) = chartDomain(listOf(Double.NaN, Double.POSITIVE_INFINITY, 0.0))
        assertTrue(low.isFinite() && high.isFinite() && high > low)
    }
    @Test fun naturalCurveHasZeroEndCurvatureAndContinuousInteriorCurvature() {
        val values = listOf(186f, 305f, 237f, 73f, 209f, 214f)
        val slopes = naturalDerivatives(values)
        fun start(i: Int) = 6 * (values[i + 1] - slopes[i + 1] / 3 - 2 * (values[i] + slopes[i] / 3) + values[i])
        fun end(i: Int) = 6 * (values[i + 1] - 2 * (values[i + 1] - slopes[i + 1] / 3) + values[i] + slopes[i] / 3)
        assertEquals(0f, start(0), .001f)
        assertEquals(0f, end(values.size - 2), .001f)
        for (i in 0 until values.size - 2) assertEquals(end(i), start(i + 1), .001f)
    }
    @Test fun degenerateAndLinearSeriesRemainStable() {
        assertEquals(emptyList<Float>(), naturalDerivatives(emptyList()))
        assertEquals(listOf(0f), naturalDerivatives(listOf(7f)))
        naturalDerivatives(listOf(0f, 1f, 2f, 3f)).forEach { assertEquals(1f, it, .0001f) }
    }
}
