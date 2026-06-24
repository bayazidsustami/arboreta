import kotlinx.browser.document
import kotlinx.browser.window
import org.w3c.dom.*
import org.w3c.dom.events.Event
import org.w3c.dom.html.HTMLCanvasElement
import org.w3c.dom.media.MediaStreamTrack
import org.w3c.dom.url.URL
import org.w3c.dom.url.createObjectURL
import kotlin.math.*
import kotlin.random.Random

/*** Helper extensions ***/
fun HTMLCanvasElement.ctx2d(): CanvasRenderingContext2D = getContext("2d") as CanvasRenderingContext2D
fun HTMLVideoElement.playAsync(): Promise<Unit> = Promise { resolve, _ ->
    addEventListener("playing", { resolve(Unit) })
    play()
}

/*** Main entry ***/
fun main() {
    // create video element (webcam)
    val video = document.createElement("video") as HTMLVideoElement
    video.autoplay = true
    video.playsInline = true
    document.body!!.appendChild(video)

    // canvas for processing frames & drawing mandala
    val canvas = document.createElement("canvas") as HTMLCanvasElement
    canvas.width = 640
    canvas.height = 480
    document.body!!.appendChild(canvas)
    val ctx = canvas.ctx2d()

    // audio context
    val audioCtx = AudioContext()
    val masterGain = audioCtx.createGain()
    masterGain.gain.value = 0.2
    masterGain.connect(audioCtx.destination)

    // mapping from hue (0..360) to 12‑tone scale frequencies (A4 = 440Hz)
    val baseFreq = 440.0
    val scale = DoubleArray(12) { i -> baseFreq * 2.0.pow(i / 12.0) }

    // simple motion estimator (frame differencing)
    var prevPixels: Uint8ClampedArray? = null

    // start webcam
    window.navigator.mediaDevices?.getUserMedia(js("{ video: true }"))?.then { stream ->
        video.srcObject = stream
        video.playAsync()
    }?.catch { console.error("Webcam error:", it) }

    // render loop
    fun render(timestamp: Double) {
        // draw current video frame onto canvas (hidden copy)
        ctx.drawImage(video, 0.0, 0.0, canvas.width.toDouble(), canvas.height.toDouble())
        val imageData = ctx.getImageData(0.0, 0.0, canvas.width.toDouble(), canvas.height.toDouble())
        val data = imageData.data

        // --- dominant color (average hue) ---
        var sumX = 0.0; var sumY = 0.0; var cnt = 0
        for (i in 0 until data.length step 4) {
            val r = data[i]; val g = data[i + 1]; val b = data[i + 2]
            val max = max(r, max(g, b)).toDouble()
            val min = min(r, min(g, b)).toDouble()
            val delta = max - min
            var hue = 0.0
            when {
                delta == 0.0 -> hue = 0.0
                max == r.toDouble() -> hue = ((g - b) / delta) % 6
                max == g.toDouble() -> hue = (b - r) / delta + 2
                else -> hue = (r - g) / delta + 4
            }
            hue = (hue * 60 + 360) % 360
            sumX += cos(Math.toRadians(hue))
            sumY += sin(Math.toRadians(hue))
            cnt++
        }
        val avgHue = Math.toDegrees(atan2(sumY, sumX)).let { if (it < 0) it + 360 else it }
        val scaleIdx = ((avgHue / 30).roundToInt()) % 12
        val freq = scale[scaleIdx]

        // --- play tone (one per frame, short envelope) ---
        val osc = audioCtx.createOscillator()
        osc.frequency.value = freq
        val env = audioCtx.createGain()
        env.gain.setValueAtTime(0.0, audioCtx.currentTime)
        env.gain.linearRampToValueAtTime(0.2, audioCtx.currentTime + 0.01)
        env.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.2)
        osc.connect(env).connect(masterGain)
        osc.start()
        osc.stop(audioCtx.currentTime + 0.25)

        // --- motion magnitude (simple frame diff) ---
        var motion = 0.0
        if (prevPixels != null) {
            for (i in 0 until data.length step 4) {
                val diff = abs(data[i] - prevPixels!![i]) + abs(data[i + 1] - prevPixels!![i + 1]) + abs(data[i + 2] - prevPixels!![i + 2])
                motion += diff
            }
            motion = motion / (data.length / 4) // average per pixel
        }
        prevPixels = Uint8ClampedArray(data.length).apply { set(data) }

        // --- draw kaleidoscopic mandala ---
        ctx.clearRect(0.0, 0.0, canvas.width.toDouble(), canvas.height.toDouble())
        val cx = canvas.width / 2.0
        val cy = canvas.height / 2.0
        val petals = 8
        val radius = 150 + 50 * sin(timestamp / 500)
        for (p in 0 until petals) {
            val angle = p * (2 * Math.PI / petals) + (timestamp % 1000) / 1000
            val x = cx + radius * cos(angle)
            val y = cy + radius * sin(angle)

            // color driven by hue & motion
            ctx.fillStyle = "hsl(${(avgHue + p * 30) % 360},80%,${50 + 30 * sin(motion / 5000) }%)"
            ctx.beginPath()
            ctx.moveTo(cx, cy)
            ctx.lineTo(x, y)
            ctx.arc(cx, cy, radius, angle, angle + Math.PI / petals, false)
            ctx.closePath()
            ctx.fill()
        }

        // schedule next frame
        window.requestAnimationFrame(::render)
    }

    // start loop after video ready
    video.addEventListener("playing", { window.requestAnimationFrame(::render) })

    // export button (creates a self‑contained HTML page)
    val exportBtn = document.createElement("button") as HTMLButtonElement
    exportBtn.textContent = "Export Loop"
    document.body!!.appendChild(exportBtn)
    exportBtn.onclick = {
        val html = """
            <!DOCTYPE html>
            <html><head><meta charset="UTF-8"><title>Kaleido Poem</title></head>
            <body style="margin:0;background:#000;">
            <canvas id="c" width="${canvas.width}" height="${canvas.height}"></canvas>
            <script>
            ${window.asDynamic().Kotlin?.modules?.main?.toString() ?: ""}
            </script>
            </body></html>
        """.trimIndent()
        val blob = Blob(arrayOf(html), BlobPropertyBag("type" to "text/html"))
        val url = URL.createObjectURL(blob)
        val a = document.createElement("a") as HTMLAnchorElement
        a.href = url
        a.download = "kaleido_poem.html"
        a.click()
        URL.revokeObjectURL(url)
    }
}