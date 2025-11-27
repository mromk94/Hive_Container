package com.omk.container.access

import android.graphics.Bitmap
import android.util.Log

/**
 * Screenshot + OCR pipeline skeleton.
 *
 * Real implementation will use Google ML Kit or Tesseract to extract text
 * blocks and confidence scores from a Bitmap. This skeleton defines the
 * interface and logging path.
 */
object ScreenshotOcr {

    data class OcrBlock(
        val text: String,
        val confidence: Float,
    )

    fun analyze(bitmap: Bitmap): List<OcrBlock> {
        Log.d("OmkOcr", "Received screenshot ${bitmap.width}x${bitmap.height}")
        // TODO: integrate ML Kit / Tesseract and map TextBlocks -> OcrBlock
        return emptyList()
    }
}
