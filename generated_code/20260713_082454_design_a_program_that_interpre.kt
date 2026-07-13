import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.Point
import org.opencv.core.Scalar
import org.opencv.core.Size
import org.opencv.imgproc.Imgproc
import org.opencv.video.BackgroundSubtractorMOG2
import org.opencv.video.Video
import org.opencv.videoio.VideoCapture
import org.opencv.videoio.VideoWriter
import java.io.File
import java.time.Instant
import javax.sound.midi.*

/**
 * Simple live webcam → MIDI + video symphony.
 *  - Moving pixels are extracted by background subtraction.
 *  - Pixel hue → MIDI pitch (C3‑C6), brightness → velocity, speed → note length.
 *  - Generated notes are stored in a MIDI file.
 *  - Original frames (with drawn notes) are saved as a video.
 */
object WebcamMusic {
    init { System.loadLibrary(Core.NATIVE_LIBRARY_NAME) }

    @JvmStatic
    fun main(args: Array<String>) {
        val cam = VideoCapture(0)
        require(cam.isOpened) { "Cannot open webcam" }

        val fps = cam.get(Videoio.CAP_PROP_FPS).let { if (it <= 0) 30.0 else it }
        val frameW = cam.get(Videoio.CAP_PROP_FRAME_WIDTH).toInt()
        val frameH = cam.get(Videoio.CAP_PROP_FRAME_HEIGHT).toInt()

        val writer = VideoWriter(
            "output.mp4",
            VideoWriter.fourcc('m', 'p', '4', 'v'),
            fps,
            Size(frameW.toDouble(), frameH.toDouble())
        )
        require(writer.isOpened) { "Cannot open video writer" }

        // MIDI setup
        val synth = MidiSystem.getSynthesizer()
        synth.open()
        val channels = synth.channels
        val instrument = 0 // piano
        channels[0].programChange(instrument)
        val seq = Sequence(Sequence.PPQ, 480)
        val track = seq.createTrack()

        // tempo 120 BPM
        track.add(MidiEvent(ShortMessage(ShortMessage.SET_TEMPO, 0x51, 0x07, 0xA1, 0x20), 0))

        val bgSub: BackgroundSubtractorMOG2 = Video.createBackgroundSubtractorMOG2()
        val prevPositions = mutableMapOf<Point, Point>() // current → previous for speed
        var tick = 0L
        val maxTicks = 480 * 120 // approx 2 minutes

        while (tick < maxTicks && cam.read(Mat())) {
            val frame = Mat()
            cam.read(frame)
            if (frame.empty()) break

            // background subtraction
            val fgMask = Mat()
            bgSub.apply(frame, fgMask)
            Imgproc.threshold(fgMask, fgMask, 200.0, 255.0, Imgproc.THRESH_BINARY)

            // find non‑zero points (moving pixels)
            val points = mutableListOf<Point>()
            Core.findNonZero(fgMask, points)

            // process a random subset to keep load low
            points.shuffle()
            val sample = points.take(50)

            for (pt in sample) {
                val hsv = Mat()
                val pixel = frame.submat(pt.y.toInt(), pt.y.toInt() + 1, pt.x.toInt(), pt.x.toInt() + 1)
                Imgproc.cvtColor(pixel, hsv, Imgproc.COLOR_BGR2HSV)
                val hue = hsv.get(0, 0)[0]          // 0‑180
                val brightness = hsv.get(0, 0)[2]   // 0‑255

                // pitch mapping: hue 0‑180 → MIDI 48‑84 (C3‑C6)
                val pitch = ((hue / 180.0) * 36 + 48).toInt()
                // volume mapping: brightness 0‑255 → 30‑127
                val velocity = (30 + (brightness / 255.0) * 97).toInt()

                // speed (simple) – distance from previous position if any
                val prev = prevPositions[pt]
                val speed = if (prev != null) {
                    Math.hypot(pt.x - prev.x, pt.y - prev.y)
                } else 0.0
                // rhythm mapping: faster → shorter note
                val durationTicks = when {
                    speed > 20 -> 120   // eighth note
                    speed > 10 -> 240   // quarter note
                    else -> 480         // half note
                }

                // MIDI note on/off
                track.add(MidiEvent(ShortMessage(ShortMessage.NOTE_ON, 0, pitch, velocity), tick))
                track.add(MidiEvent(ShortMessage(ShortMessage.NOTE_OFF, 0, pitch, 0), tick + durationTicks))

                // visual feedback
                Imgproc.circle(frame, pt, 4, Scalar(0.0, 255.0, 0.0), -1)

                // store current position for next iteration
                prevPositions[pt] = pt
            }

            writer.write(frame)
            tick += 480 // advance one beat per processed frame (adjust as needed)
        }

        // cleanup
        cam.release()
        writer.release()
        MidiSystem.write(seq, 1, File("output.mid"))
        synth.close()
        println("Processing finished – video saved as output.mp4, MIDI as output.mid")
    }
}