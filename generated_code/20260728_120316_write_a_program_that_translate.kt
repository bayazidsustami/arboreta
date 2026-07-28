import java.io.File
import kotlin.math.*

// Vector 3D representation and basic math
data class Vec3(val x: Double, val y: Double, val z: Double) {
    operator fun plus(v: Vec3) = Vec3(x + v.x, y + v.y, z + v.z)
    operator fun minus(v: Vec3) = Vec3(x - v.x, y - v.y, z - v.z)
    operator fun times(s: Double) = Vec3(x * s, y * s, z * s)
    fun length() = sqrt(x * x + y * y + z * z)
    fun normalize(): Vec3 {
        val l = length()
        return if (l > 0) Vec3(x / l, y / l, z / l) else Vec3(0.0, 0.0, 0.0)
    }
    fun cross(v: Vec3) = Vec3(
        y * v.z - z * v.y,
        z * v.x - x * v.z,
        x * v.y - y * v.x
    )
}

data class Triangle(val v1: Vec3, val v2: Vec3, val v3: Vec3) {
    fun normal(): Vec3 {
        val edge1 = v2 - v1
        val edge2 = v3 - v1
        return edge1.cross(edge2).normalize()
    }
}

data class CommitNode(
    val hash: String,
    val parentCount: Int,
    val insertions: Int,
    val deletions: Int
)

fun main() {
    val commits = fetchGitLog()
    println("Processing ${commits.size} commits into 3D printable STL sculpture...")

    val triangles = mutableListOf<Triangle>()
    val segments = 24
    val heightStep = 2.0
    val baseRadius = 15.0

    // Main cylinder with micro-textures derived from code diffs
    var currentZ = 0.0
    val sliceVertices = mutableListOf<List<Vec3>>()

    commits.forEachIndexed { index, commit ->
        currentZ += heightStep
        val diffMagnitude = (commit.insertions + commit.deletions).toDouble()
        val textureScale = log2(diffMagnitude + 1.0) * 0.4

        val ring = (0 until segments).map { i ->
            val angle = (i.toDouble() / segments) * 2 * PI
            // Micro-texture displacement based on hash and line diffs
            val noise = sin(angle * 5 + commit.hash.hashCode()) * textureScale
            val radius = baseRadius + noise
            Vec3(radius * cos(angle), radius * sin(angle), currentZ)
        }
        sliceVertices.add(ring)

        // Generate branch support structure if commit is a merge (>1 parent)
        if (commit.parentCount > 1) {
            val supportAngle = (index * 137.5) * (PI / 180.0) // Golden ratio spread
            triangles.addAll(generateSupportStrut(Vec3(0.0, 0.0, currentZ), supportAngle, baseRadius))
        }
    }

    // Connect slices to create main outer mesh body
    for (i in 0 until sliceVertices.size - 1) {
        val ringA = sliceVertices[i]
        val ringB = sliceVertices[i + 1]
        for (j in 0 until segments) {
            val nextJ = (j + 1) % segments
            triangles.add(Triangle(ringA[j], ringB[j], ringB[nextJ]))
            triangles.add(Triangle(ringA[j], ringB[nextJ], ringA[nextJ]))
        }
    }

    // Cap bottom and top
    triangles.addAll(createCap(sliceVertices.first(), currentZ = 0.0, invert = true))
    triangles.addAll(createCap(sliceVertices.last(), currentZ = currentZ, invert = false))

    exportSTL("sculpture.stl", triangles)
    println("Sculpture successfully exported to 'sculpture.stl' with ${triangles.size} facets.")
}

// Fetch real Git log or fallback to synthetic log if outside a git repo
fun fetchGitLog(): List<CommitNode> {
    return try {
        val process = ProcessBuilder("git", "log", "--pretty=format:%h|%p", "--numstat")
            .redirectError(ProcessBuilder.Redirect.DISCARD)
            .start()

        val lines = process.inputStream.bufferedReader().readLines()
        process.waitFor()

        if (lines.isEmpty()) throw Exception("Empty git output")

        val commits = mutableListOf<CommitNode>()
        var currentHash = ""
        var parentCount = 1
        var ins = 0
        var del = 0

        for (line in lines) {
            if (line.contains("|")) {
                if (currentHash.isNotEmpty()) {
                    commits.add(CommitNode(currentHash, parentCount, ins, del))
                }
                val parts = line.split("|")
                currentHash = parts[0]
                parentCount = if (parts.size > 1 && parts[1].trim().isNotEmpty()) parts[1].trim().split(" ").size else 1
                ins = 0
                del = 0
            } else if (line.isNotBlank()) {
                val stat = line.trim().split("\\s+".toRegex())
                if (stat.size >= 2) {
                    ins += stat[0].toIntOrNull() ?: 0
                    del += stat[1].toIntOrNull() ?: 0
                }
            }
        }
        if (currentHash.isNotEmpty()) commits.add(CommitNode(currentHash, parentCount, ins, del))
        commits.ifEmpty { syntheticGitLog() }
    } catch (e: Exception) {
        syntheticGitLog()
    }
}

// Fallback synthetic commit history generator
fun syntheticGitLog(): List<CommitNode> = (1..60).map { i ->
    CommitNode(
        hash = Integer.toHexString(i * 1234567),
        parentCount = if (i % 7 == 0) 2 else 1,
        insertions = (i * 17) % 120,
        deletions = (i * 7) % 50
    )
}

// Generates angled support strut anchoring back to print bed for merge commits
fun generateSupportStrut(origin: Vec3, angle: Double, baseRadius: Double): List<Triangle> {
    val tris = mutableListOf<Triangle>()
    val dir = Vec3(cos(angle), sin(angle), -0.5).normalize()
    val start = origin + Vec3(cos(angle) * baseRadius, sin(angle) * baseRadius, 0.0)
    val end = Vec3(start.x + dir.x * origin.z, start.y + dir.y * origin.z, 0.0)

    val thickness = 1.2
    val perp = Vec3(-sin(angle), cos(angle), 0.0) * thickness

    val p1 = start - perp
    val p2 = start + perp
    val p3 = end + perp
    val p4 = end - perp

    tris.add(Triangle(p1, p2, p3))
    tris.add(Triangle(p1, p3, p4))
    return tris
}

// Generates flat cap geometry for closed solid mesh
fun createCap(ring: List<Vec3>, currentZ: Double, invert: Boolean): List<Triangle> {
    val tris = mutableListOf<Triangle>()
    val center = Vec3(0.0, 0.0, currentZ)
    for (i in ring.indices) {
        val next = (i + 1) % ring.size
        if (invert) {
            tris.add(Triangle(center, ring[next], ring[i]))
        } else {
            tris.add(Triangle(center, ring[i], ring[next]))
        }
    }
    return tris
}

// Exports mesh geometry to standard ASCII STL format for 3D printing
fun exportSTL(filename: String, triangles: List<Triangle>) {
    File(filename).printWriter().use { out ->
        out.println("solid git_sculpture")
        for (t in triangles) {
            val n = t.normal()
            out.println("  facet normal ${n.x} ${n.y} ${n.z}")
            out.println("    outer loop")
            out.println("      vertex ${t.v1.x} ${t.v1.y} ${t.v1.z}")
            out.println("      vertex ${t.v2.x} ${t.v2.y} ${t.v2.z}")
            out.println("      vertex ${t.v3.x} ${t.v3.y} ${t.v3.z}")
            out.println("    endloop")
            out.println("  endfacet")
        }
        out.println("endsolid git_sculpture")
    }
}