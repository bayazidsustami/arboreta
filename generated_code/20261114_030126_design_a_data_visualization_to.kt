import java.awt.*
import java.awt.event.WindowAdapter
import java.awt.event.WindowEvent
import java.net.NetworkInterface
import java.util.Random
import javax.swing.JFrame
import javax.swing.JPanel
import javax.swing.Timer
import kotlin.math.*

fun main() {
    val frame = JFrame("Baroque Network Decay Monitor")
    val panel = BaroqueCanvasPanel()
    frame.add(panel)
    frame.setSize(800, 600)
    frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
    frame.isVisible = true
}

class BaroqueCanvasPanel : JPanel() {
    private val random = Random(42)
    private var packetLossRate = 0.05
    private var trafficVolume = 100.0
    private val cracks = mutableListOf<Point2D>()
    private val peelLayers = mutableListOf<Rectangle>()
    
    init {
        background = Color(20, 15, 10)
        
        Thread {
            while (true) {
                try {
                    var totalBytes = 0L
                    NetworkInterface.getNetworkInterfaces().iterator().forEach { ni ->
                        try {
                            totalBytes += ni.mtu.toLong()
                        } catch (_: Exception) {}
                    }
                    
                    val jitter = (random.nextDouble() - 0.5) * 0.02
                    packetLossRate = (packetLossRate + jitter).coerceIn(0.0, 0.45)
                    trafficVolume = 50.0 + abs(sin(System.currentTimeMillis() / 1000.0)) * 150.0

                    if (packetLossRate > 0.08 && random.nextDouble() < packetLossRate) {
                        val cx = random.nextInt(width.coerceAtLeast(100))
                        val cy = random.nextInt(height.coerceAtLeast(100))
                        cracks.add(Point2D(cx.toDouble(), cy.toDouble()))
                    }

                    repaint()
                    Thread.sleep(150)
                } catch (_: Exception) {}
            }
        }.start()
        
        Timer(30) { repaint() }.start()
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        val g2d = g as Graphics2D
        g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        val w = width
        val h = height

        val bgGradient = GradientPaint(0f, 0f, Color(40, 25, 15), w.toFloat(), h.toFloat(), Color(10, 5, 2))
        g2d.paint = bgGradient
        g2d.fillRect(0, 0, w, h)

        g2d.color = Color(120, 30, 30, 200)
        g2d.fillOval(w / 4, h / 3, w / 2, (h * 0.8).toInt())

        g2d.color = Color(210, 180, 140, 180)
        g2d.fillOval((w * 0.4).toInt(), (h * 0.25).toInt(), (w * 0.2).toInt(), (h * 0.3).toInt())

        g2d.stroke = BasicStroke(1.2f, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)
        
        for (crack in cracks) {
            g2d.color = Color(10, 5, 2, 220)
            val pathX = crack.x + (random.nextDouble() - 0.5) * packetLossRate * 100
            val pathY = crack.y + (random.nextDouble() - 0.5) * packetLossRate * 100
            g2d.drawLine(crack.x.toInt(), crack.y.toInt(), pathX.toInt(), pathY.toInt())
        }

        if (packetLossRate > 0.15 && random.nextDouble() < (packetLossRate * 0.5)) {
            val rx = random.nextInt(w)
            val ry = random.nextInt(h)
            val rw = (20 + random.nextInt(50))
            val rh = (10 + random.nextInt(30))
            peelLayers.add(Rectangle(rx, ry, rw, rh))
            if (peelLayers.size > 50) peelLayers.removeAt(0)
        }

        g2d.color = Color(5, 3, 2, 240)
        for (peel in peelLayers) {
            g2d.fillRect(peel.x, peel.y, peel.width, peel.height)
        }

        g2d.color = Color(212, 175, 55)
        g2d.font = Font("Serif", Font.ITALIC, 14)
        g2d.drawString("Packet Loss: ${String.format("%.2f", packetLossRate * 100)}% | Traffic Flow: ${String.format("%.1f", trafficVolume)} KB/s", 20, 30)
    }
}

data class Point2D(val x: Double, val y: Double)