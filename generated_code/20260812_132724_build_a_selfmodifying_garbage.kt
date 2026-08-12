import javax.sound.midi.MidiSystem
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.random.Random

/**
 * Self-Modifying Memory-to-MIDI Garbage Collector
 *
 * Translates heap allocation and deallocation into multi-track MIDI synthesis:
 * - Track 0 (Allocations): Rapid melodic arpeggios on high-frequency channels.
 * - Track 1 (Deallocations): Percussive staccato notes clearing pitch buffers.
 * - Track 2 (Memory Leaks/Drone): Unresolved leaks gradually evolve into sustained, dissonant drone chords.
 *
 * Self-Modification: As memory pressure and leak count change, GC dynamically adjusts its threshold
 * and adapts synthesis parameters (timbre, dissonant harmonic intervals, note velocity).
 */

class HeapObject(val id: Int, val pitch: Int, val creationTime: Long)

class MusicalGarbageCollector {
    private val synth = MidiSystem.getSynthesizer().apply { open() }
    private val channels = synth.channels
    private val scheduler = Executors.newScheduledThreadPool(2)

    private val heap = ConcurrentHashMap<Int, HeapObject>()
    private val rootSet = ConcurrentHashMap.newKeySet<Int>()
    
    // Dynamic GC adaptation state
    private var gcThreshold = 25
    private var leakCount = 0
    private var totalAllocations = 0

    init {
        // Channel setup: 0=Lead/Allocations, 1=Percussive/Deallocations, 2=Dissonant Drone
        channels[0].programChange(80) // Lead 1 (Square)
        channels[1].programChange(12) // Marimba / Percussive
        channels[2].programChange(89) // Warm / Dissonant Pad
    }

    fun allocate(isLeaking: Boolean = false): Int {
        val id = ++totalAllocations
        // Map allocation to a pitch in pentatonic/modal scale
        val pitch = 50 + (id * 7 % 36)
        val obj = HeapObject(id, pitch, System.currentTimeMillis())
        heap[id] = obj

        if (!isLeaking) {
            rootSet.add(id)
        }

        // Trigger Allocation Sound (Track 0)
        channels[0].noteOn(pitch, 85)
        scheduler.schedule({
            channels[0].noteOff(pitch)
        }, 120, TimeUnit.MILLISECONDS)

        // Self-modifying trigger check: Invoke GC when heap exceeds adaptive threshold
        if (heap.size >= gcThreshold) {
            collectGarbage()
        }

        return id
    }

    fun release(id: Int) {
        rootSet.remove(id)
    }

    private fun collectGarbage() {
        val currentTime = System.currentTimeMillis()
        val unreachable = heap.keys.filter { !rootSet.contains(it) }

        // Deallocate unreachable objects (Track 1)
        unreachable.forEach { id ->
            heap.remove(id)?.let { obj ->
                channels[1].noteOn(obj.pitch - 12, 70)
                scheduler.schedule({
                    channels[1].noteOff(obj.pitch - 12)
                }, 80, TimeUnit.MILLISECONDS)
            }
        }

        // Detect sustained memory leaks (objects lingering beyond threshold)
        val leakingObjects = heap.values.filter { (currentTime - it.creationTime) > 800 }
        leakCount = leakingObjects.size

        // Evolve dissonant drone chords based on uncollected leaks (Track 2)
        evolveDissonantDrone(leakingObjects.map { it.pitch })

        // Self-Modifying Heuristic: Adapt GC threshold based on memory pressure & leak rate
        if (leakCount > 5) {
            gcThreshold = (gcThreshold * 0.85).toInt().coerceAtLeast(8) // More aggressive GC sweep
        } else {
            gcThreshold = (gcThreshold * 1.15).toInt().coerceAtMost(60) // Relaxed collection
        }
    }

    private fun evolveDissonantDrone(leakPitches: List<Int>) {
        channels[2].allNotesOff()

        if (leakPitches.isEmpty()) return

        // Transform leak pitches into dissonant intervals (minor 2nds, tritones, major 7ths)
        val droneNotes = leakPitches.take(8).mapIndexed { idx, pitch ->
            val dissonanceOffset = when (idx % 3) {
                0 -> 1  // Minor second
                1 -> 6  // Tritone
                else -> 11 // Major seventh
            }
            (pitch % 24 + 36 + dissonanceOffset).coerceIn(24, 72)
        }.distinct()

        // Volume and velocity scale with severity of unresolved leaks
        val velocity = (50 + leakCount * 6).coerceAtMost(127)
        droneNotes.forEach { note ->
            channels[2].noteOn(note, velocity)
        }
    }

    fun shutdown() {
        channels.forEach { it.allNotesOff() }
        scheduler.shutdownNow()
        synth.close()
    }
}

fun main() {
    val gc = MusicalGarbageCollector()
    val random = Random(1337)

    try {
        // Run real-time simulation: transition from healthy allocation cycles to severe leaks
        repeat(150) { step ->
            val memoryPressure = step / 150.0
            val isLeak = random.nextDouble() < (memoryPressure * 0.85)
            val id = gc.allocate(isLeaking = isLeak)

            if (!isLeak && random.nextDouble() > 0.3) {
                gc.release(id)
            }

            Thread.sleep(100)
        }
        Thread.sleep(3000) // Allow sustained dissonant drone to resonate
    } finally {
        gc.shutdown()
    }
}