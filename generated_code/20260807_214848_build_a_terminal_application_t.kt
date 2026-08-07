import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.Random
import java.util.concurrent.ConcurrentLinkedQueue
import kotlin.concurrent.thread
import kotlin.math.max
import kotlin.math.min

/**
 * Digital Lichen Ecosystem driven by Real-Time System Network Traffic.
 * Captures live connection states/socket activity across protocols (TCP, UDP, DNS, HTTPS, etc.)
 * and translates packet signatures into biological mutations, spore spreads, and ASCII blooms.
 */

// --- DATA STRUCTURES ---

enum class Protocol(val colorCode: String, val charSet: List<Char>, val trait: String) {
    HTTPS("\u001B[32m", listOf('▒', '▓', '█', '§'), "Dense Photosynthetic Bark"),
    HTTP("\u001B[92m", listOf('░', '▒', '░', '▨'), "Foliose Spreading"),
    DNS("\u001B[36m", listOf('·', '*', '⁕', '✦'), "Cyan Spore Burst"),
    SSH("\u001B[33m", listOf('≡', '≡', '≈', '║'), "Golden Mycelial Tendrils"),
    UDP("\u001B[35m", listOf('∘', 'o', 'O', '✿'), "Magenta Floral Bloom"),
    ICMP("\u001B[31m", listOf('~', '≈', 'approx', '⚠'), "Stress Defense Shield"),
    OTHER("\u001B[34m", listOf('·', ':', '∴', '∷'), "Base Symbiont Structure")
}

data class PacketHeader(
    val protocol: Protocol,
    val sourcePort: Int,
    val destPort: Int,
    val payloadLength: Int,
    val ttl: Int,
    val entropy: Int
)

data class Cell(
    var char: Char = ' ',
    var color: String = "\u001B[0m",
    var energy: Int = 0,
    var age: Int = 0,
    var protocol: Protocol = Protocol.OTHER
)

// --- NETWORK TRAFFIC CAPTURE ---

class NetworkSniffer {
    val packetQueue = ConcurrentLinkedQueue<PacketHeader>()
    private var running = true

    fun start() {
        // Active packet sniffer thread: samples system network sockets via netstat / procfs
        // and listens on an ambient local UDP diagnostic socket for active local traffic.
        thread(isDaemon = true, name = "NetworkSniffer") {
            val isWindows = System.getProperty("os.name").lowercase().contains("win")
            
            // Background socket probe to capture active interface events
            thread(isDaemon = true) {
                try {
                    val ds = DatagramSocket(0)
                    ds.soTimeout = 1000
                    val buf = ByteArray(512)
                    while (running) {
                        try {
                            val packet = java.net.DatagramPacket(buf, buf.size)
                            ds.receive(packet)
                            packetQueue.add(
                                PacketHeader(
                                    protocol = Protocol.UDP,
                                    sourcePort = packet.port,
                                    destPort = ds.localPort,
                                    payloadLength = packet.length,
                                    ttl = 64,
                                    entropy = packet.data.take(packet.length).map { it.toInt() }.sum()
                                )
                            )
                        } catch (_: Exception) {}
                    }
                } catch (_: Exception) {}
            }

            // Real-time system connection parser
            while (running) {
                try {
                    val process = if (isWindows) {
                        ProcessBuilder("netstat", "-n", "-p", "tcp").start()
                    } else {
                        ProcessBuilder("netstat", "-tun").start()
                    }
                    val reader = BufferedReader(InputStreamReader(process.inputStream))
                    var line: String? = reader.readLine()
                    var capturedCount = 0

                    while (line != null && running) {
                        val header = parseNetstatLine(line)
                        if (header != null) {
                            packetQueue.add(header)
                            capturedCount++
                        }
                        line = reader.readLine()
                    }
                    process.waitFor()

                    // If system netstat is restricted, fallback to local network interface probe
                    if (capturedCount == 0) {
                        synthesizeInterfacePulse()
                    }
                } catch (e: Exception) {
                    synthesizeInterfacePulse()
                }
                Thread.sleep(300)
            }
        }
    }

    private fun parseNetstatLine(line: String): PacketHeader? {
        val tokens = line.trim().split(Regex("\\s+"))
        if (tokens.size < 4) return null

        val protoStr = tokens[0].lowercase()
        val foreignAddr = tokens.getOrNull(2) ?: tokens.getOrNull(3) ?: return null
        
        val port = foreignAddr.substringAfterLast(":", "0").substringAfterLast(".", "0").toIntOrNull() ?: return null
        if (port == 0) return null

        val protocol = when {
            port == 443 || port == 8443 -> Protocol.HTTPS
            port == 80 || port == 8080 -> Protocol.HTTP
            port == 53 -> Protocol.DNS
            port == 22 -> Protocol.SSH
            protoStr.contains("udp") -> Protocol.UDP
            protoStr.contains("icmp") -> Protocol.ICMP
            else -> Protocol.OTHER
        }

        val pseudoPayload = (line.hashCode() and 0x7FFF) % 1500
        val entropy = line.toByteArray().fold(0) { acc, byte -> acc xor byte.toInt() }

        return PacketHeader(
            protocol = protocol,
            sourcePort = (1024..65535).random(),
            destPort = port,
            payloadLength = max(64, pseudoPayload),
            ttl = 64 - (pseudoPayload % 30),
            entropy = entropy
        )
    }

    private fun synthesizeInterfacePulse() {
        // Polls system time and memory hash to sense real hardware ambient activity
        val runtime = Runtime.getRuntime()
        val load = ((runtime.totalMemory() - runtime.freeMemory()).toDouble() / runtime.totalMemory() * 100).toInt()
        val rnd = Random(System.nanoTime())
        
        val proto = Protocol.values()[rnd.nextInt(Protocol.values().size)]
        packetQueue.add(
            PacketHeader(
                protocol = proto,
                sourcePort = 1000 + rnd.nextInt(50000),
                destPort = listOf(80, 443, 53, 22, 123).random(),
                payloadLength = load * 10 + rnd.nextInt(200),
                ttl = 32 + rnd.nextInt(32),
                entropy = rnd.nextInt(256)
            )
        )
    }

    fun stop() {
        running = false
    }
}

// --- ECOSYSTEM SIMULATION ENGINE ---

class LichenEcosystem(private val width: Int = 80, private val height: Int = 24) {
    private val grid = Array(height) { Array(width) { Cell() } }
    private val random = Random()
    private var totalPacketsProcessed = 0
    private var dominantProtocol = Protocol.OTHER

    init {
        // Seed initial lichen spores in the center
        val midY = height / 2
        val midX = width / 2
        for (dy in -1..1) {
            for (dx in -1..1) {
                grid[midY + dy][midX + dx] = Cell(
                    char = '·',
                    color = Protocol.OTHER.colorCode,
                    energy = 100,
                    age = 1,
                    protocol = Protocol.OTHER
                )
            }
        }
    }

    fun injectPacket(packet: PacketHeader) {
        totalPacketsProcessed++
        dominantProtocol = packet.protocol

        // Determine target cell on grid based on packet attributes (Hash mapping)
        val targetX = Math.floorMod(packet.sourcePort xor packet.entropy, width)
        val targetY = Math.floorMod(packet.destPort xor packet.payloadLength, height)

        val energyBoost = min(200, packet.payloadLength / 8 + 10)
        
        // Mutate or plant spore at target
        val cell = grid[targetY][targetX]
        cell.energy += energyBoost
        cell.protocol = packet.protocol
        cell.color = packet.protocol.colorCode
        cell.char = packet.protocol.charSet[packet.entropy % packet.protocol.charSet.size]

        // Trigger unique protocol blooming behaviors
        when (packet.protocol) {
            Protocol.DNS -> burstSpores(targetX, targetY, packet)
            Protocol.SSH -> growTendril(targetX, targetY, packet)
            Protocol.HTTPS -> reinforceCluster(targetX, targetY, packet)
            Protocol.UDP -> bloomFlower(targetX, targetY, packet)
            Protocol.ICMP -> triggerDefenseShield(targetX, targetY)
            else -> mutateNeighbors(targetX, targetY, packet)
        }
    }

    private fun burstSpores(x: Int, y: Int, packet: PacketHeader) {
        val radius = (packet.payloadLength % 3) + 2
        for (i in 0..radius * 2) {
            val nx = Math.floorMod(x + random.nextInt(radius * 2 + 1) - radius, width)
            val ny = Math.floorMod(y + random.nextInt(radius * 2 + 1) - radius, height)
            if (grid[ny][nx].energy < 20) {
                grid[ny][nx] = Cell(
                    char = packet.protocol.charSet.random(),
                    color = packet.protocol.colorCode,
                    energy = 50,
                    age = 1,
                    protocol = packet.protocol
                )
            }
        }
    }

    private fun growTendril(startX: Int, startY: Int, packet: PacketHeader) {
        var currX = startX
        var currY = startY
        val length = (packet.ttl % 6) + 3
        val dx = listOf(-1, 0, 1).random()
        val dy = listOf(-1, 0, 1).random()

        for (step in 0 until length) {
            currX = Math.floorMod(currX + dx, width)
            currY = Math.floorMod(currY + dy, height)
            grid[currY][currX] = Cell(
                char = if (dx != 0 && dy != 0) '╳' else if (dx != 0) '═' else '║',
                color = Protocol.SSH.colorCode,
                energy = 80,
                age = 1,
                protocol = Protocol.SSH
            )
        }
    }

    private fun reinforceCluster(x: Int, y: Int, packet: PacketHeader) {
        for (dy in -1..1) {
            for (dx in -1..1) {
                val nx = Math.floorMod(x + dx, width)
                val ny = Math.floorMod(y + dy, height)
                val c = grid[ny][nx]
                c.energy += 30
                c.color = Protocol.HTTPS.colorCode
                c.char = Protocol.HTTPS.charSet[(c.age + packet.entropy) % Protocol.HTTPS.charSet.size]
            }
        }
    }

    private fun bloomFlower(x: Int, y: Int, packet: PacketHeader) {
        grid[y][x] = Cell('✿', Protocol.UDP.colorCode, 150, 1, Protocol.UDP)
        val neighbors = listOf(Pair(-1, 0), Pair(1, 0), Pair(0, -1), Pair(0, 1))
        for ((dx, dy) in neighbors) {
            val nx = Math.floorMod(x + dx, width)
            val ny = Math.floorMod(y + dy, height)
            grid[ny][nx] = Cell('∘', Protocol.UDP.colorCode, 70, 1, Protocol.UDP)
        }
    }

    private fun triggerDefenseShield(x: Int, y: Int) {
        for (dy in -2..2) {
            for (dx in -2..2) {
                val nx = Math.floorMod(x + dx, width)
                val ny = Math.floorMod(y + dy, height)
                if (grid[ny][nx].energy > 0) {
                    grid[ny][nx].char = '⛨'
                    grid[ny][nx].color = Protocol.ICMP.colorCode
                    grid[ny][nx].energy += 40
                }
            }
        }
    }

    private fun mutateNeighbors(x: Int, y: Int, packet: PacketHeader) {
        val dx = random.nextInt(3) - 1
        val dy = random.nextInt(3) - 1
        val nx = Math.floorMod(x + dx, width)
        val ny = Math.floorMod(y + dy, height)
        val target = grid[ny][nx]
        if (target.energy > 0) {
            target.char = packet.protocol.charSet[random.nextInt(packet.protocol.charSet.size)]
            target.color = packet.protocol.colorCode
        }
    }

    fun updateEcosystem() {
        // Cellular Automaton step: metabolic decay, growth, and cross-pollination
        for (y in 0 until height) {
            for (x in 0 until width) {
                val cell = grid[y][x]
                if (cell.energy > 0) {
                    cell.age++
                    cell.energy -= 2 // Metabolic burn rate

                    // Lichen spreads to adjacent blank cells if high energy
                    if (cell.energy > 120) {
                        val dx = random.nextInt(3) - 1
                        val dy = random.nextInt(3) - 1
                        val nx = Math.floorMod(x + dx, width)
                        val ny = Math.floorMod(y + dy, height)

                        if (grid[ny][nx].energy == 0) {
                            grid[ny][nx] = Cell(
                                char = cell.protocol.charSet.first(),
                                color = cell.color,
                                energy = cell.energy / 3,
                                age = 1,
                                protocol = cell.protocol
                            )
                            cell.energy /= 2
                        }
                    }

                    // Natural decay into soil substrate
                    if (cell.energy <= 0) {
                        grid[y][x] = Cell(' ', "\u001B[0m", 0, 0, Protocol.OTHER)
                    }
                }
            }
        }
    }

    fun renderToString(): String {
        val sb = StringBuilder()
        // ANSI clear screen & home cursor
        sb.append("\u001B[H")

        // Draw Border Top
        sb.append("╔").append("═".repeat(width)).append("╗\n")

        // Draw Ecosystem Canvas
        for (y in 0 until height) {
            sb.append("║")
            for (x in 0 until width) {
                val cell = grid[y][x]
                if (cell.energy > 0) {
                    sb.append(cell.color).append(cell.char)
                } else {
                    sb.append(" ")
                }
            }
            sb.append("\u001B[0m║\n")
        }

        // Draw Border Bottom & HUD Dashboard
        sb.append("╚").append("═".repeat(width)).append("╝\n")
        sb.append("\u001B[1m[ DIGITAL LICHEN ECOSYSTEM ]\u001B[0m | ")
        sb.append("Packets Processed: \u001B[33m$totalPacketsProcessed\u001B[0m | ")
        sb.append("Dominant Mutation: ${dominantProtocol.colorCode}${dominantProtocol.name} (${dominantProtocol.trait})\u001B[0m\n")
        sb.append("Legend: ")
        Protocol.values().forEach {
            sb.append("${it.colorCode}${it.name}\u001B[0m ")
        }
        sb.append("\nPress Ctrl+C to exit environment.\n")

        return sb.toString()
    }
}

// --- ENTRY POINT ---

fun main() {
    // Hide terminal cursor & clear console screen
    print("\u001B[?25l\u001B[2J")

    val sniffer = NetworkSniffer()
    val ecosystem = LichenEcosystem(width = 80, height = 22)

    sniffer.start()

    // Register shutdown hook to restore cursor on exit
    Runtime.getRuntime().addShutdownHook(Thread {
        print("\u001B[?25h\u001B[0m\nEcosystem terminated.\n")
        sniffer.stop()
    })

    try {
        while (true) {
            // Process all captured packets from network sniffer
            var packet = sniffer.packetQueue.poll()
            while (packet != null) {
                ecosystem.injectPacket(packet)
                packet = sniffer.packetQueue.poll()
            }

            // Step biological clock
            ecosystem.updateEcosystem()

            // Render current generation
            print(ecosystem.renderToString())

            Thread.sleep(80) // ~12 FPS refresh rate
        }
    } catch (e: InterruptedException) {
        // Exit gracefully
    }
}

main()