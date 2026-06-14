@file:DependsOn("org.openpnp:opencv:4.5.1-2")
@file:DependsOn("org.jfugue:jfugue:5.0.9")
@file:DependsOn("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")

import org.opencv.core.*
import org.opencv.videoio.VideoCapture
import org.opencv.imgproc.Imgproc
import org.jfugue.player.Player
import org.jfugue.pattern.Pattern
import kotlinx.coroutines.*
import java.io.File
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import javax.sound.midi.Sequence
import kotlin.math.*

// Load native OpenCV library
nu.pattern.OpenCV.loadShared()
System.loadLibrary(org.opencv.core.Core.NATIVE_LIBRARY_NAME)

// ----------- Parameters -----------
val FRAME_RATE = 30
val DURATION_SEC = 10          // total run time
val CHORDS = listOf("C", "Dm", "Em", "F", "G", "Am", "Bdim")  // simple diatonic set
val SVG_WIDTH = 800
val SVG_HEIGHT = 600
val OUTPUT_HTML = "audiovisual.html"

// ----------- Helpers -----------
fun dominantHue(mat: Mat): Double {
    // Convert to HSV and compute average hue (0‑180 in OpenCV)
    val hsv = Mat()
    Imgproc.cvtColor(mat, hsv, Imgproc.COLOR_BGR2HSV)
    val hueChannel = Mat()
    Core.extractChannel(hsv, hueChannel, 0)
    return Core.mean(hueChannel).`val`[0] * 2.0   // scale to 0‑360°
}

fun hueToChord(hue: Double): String {
    // map hue (0‑360) to one of the chords
    val idx = ((hue / 360.0) * CHORDS.size).toInt() % CHORDS.size
    return CHORDS[idx]
}

fun chordToPattern(chord: String): Pattern {
    // simple arpeggio over one measure
    return Pattern("$chord5q $chord3q $chord1q $chord5q")
}

// ----------- Main Logic -----------
fun main() = runBlocking {
    val cap = VideoCapture(0)
    if (!cap.isOpened) {
        println("Cannot open webcam.")
        return@runBlocking
    }
    cap.set(Videoio.CAP_PROP_FRAME_WIDTH, SVG_WIDTH.toDouble())
    cap.set(Videoio.CAP_PROP_FRAME_HEIGHT, SVG_HEIGHT.toDouble())

    val player = Player()
    val svgBuilder = StringBuilder()
    svgBuilder.append("""<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>Audio‑Visual Loop</title></head>
<body style="margin:0; background:#000;">
<svg id="stage" width="${SVG_WIDTH}" height="${SVG_HEIGHT}" style="background:#111;"></svg>
<audio id="audio" autoplay></audio>
<script>
let svg = document.getElementById('stage');
function addShape(color, size, opacity, speed){
    let ns = "http://www.w3.org/2000/svg";
    let circle = document.createElementNS(ns,'circle');
    circle.setAttribute('cx', Math.random()*${SVG_WIDTH});
    circle.setAttribute('cy', Math.random()*${SVG_HEIGHT});
    circle.setAttribute('r', size);
    circle.setAttribute('fill', color);
    circle.setAttribute('fill-opacity', opacity);
    svg.appendChild(circle);
    let dx = (Math.random()-0.5)*speed;
    let dy = (Math.random()-0.5)*speed;
    function move(){
        let x = parseFloat(circle.getAttribute('cx')) + dx;
        let y = parseFloat(circle.getAttribute('cy')) + dy;
        if(x<0||x>${SVG_WIDTH}) dx=-dx;
        if(y<0||y>${SVG_HEIGHT}) dy=-dy;
        circle.setAttribute('cx', x);
        circle.setAttribute('cy', y);
        requestAnimationFrame(move);
    }
    move();
}
</script>
</body></html>
""")
    // Prepare a temporary MIDI file that will be streamed to the browser
    val midiFile = File.createTempFile("temp", ".mid")
    midiFile.deleteOnExit()

    // Coroutine producing music and SVG commands
    val musicJob = launch {
        val seq = Sequence(Sequence.PPQ, 480)
        repeat((DURATION_SEC * FRAME_RATE).toInt()) {
            val frame = Mat()
            if (!cap.read(frame)) return@repeat
            val hue = dominantHue(frame)
            val chord = hueToChord(hue)
            player.play(chordToPattern(chord))
            // Store chord as MIDI (simplified)
            // In practice you'd add notes to seq here; omitted for brevity.
            // Generate SVG shape parameters based on hue & chord index
            val color = "hsl(${hue.toInt()},80%,60%)"
            val size = 10 + (hue % 30)
            val opacity = 0.5 + (hue % 50) / 100.0
            val speed = 2 + (hue % 5)
            // Append JS call to HTML (will be executed after page load)
            svgBuilder.insert(svgBuilder.lastIndexOf("</script>"),
                "addShape('$color',$size,$opacity,$speed);\n")
            delay(1000L / FRAME_RATE)
        }
        // write empty MIDI to satisfy the audio element (real implementation would fill seq)
        midiFile.writeBytes(ByteArray(0))
    }

    // Wait for both tasks
    musicJob.join()
    cap.release()

    // Insert audio source
    val finalHtml = svgBuilder.toString().replace(
        "<audio id=\"audio\" autoplay></audio>",
        "<audio id=\"audio\" autoplay controls src=\"data:audio/midi;base64,${java.util.Base64.getEncoder().encodeToString(midiFile.readBytes())}\"></audio>"
    )
    File(OUTPUT_HTML).writeText(finalHtml)
    println("Finished. Open $OUTPUT_HTML in a browser.")
}