import java.io.File
import java.net.URL
import java.net.URLEncoder
import kotlin.math.sqrt
import kotlin.math.log

// ==== CONFIG ====
// Replace with your OpenWeatherMap API key or set ENV variable WEATHER_API_KEY
val apiKey = System.getenv("WEATHER_API_KEY") ?: "YOUR_API_KEY"
// Location for weather (city name)
val location = "London"
// Mandelbrot parameters (will be overwritten each run)
val maxIter = 50           //PARAM_MAX_ITER
val zoom = 0.0065          //PARAM_ZOOM
val offsetX = -0.7          //PARAM_OFFSET_X
val offsetY = 0.0           //PARAM_OFFSET_Y
// ==== END CONFIG ====

// Entry point
fun main() {
    val weather = fetchWeather()
    val haiku = generateHaiku(weather.description)
    println("Weather: ${weather.main} - ${weather.description}")
    println("Haiku:\n$haiku")
    println("\nLandscape:\n")
    renderMandelbrot(haiku)
    selfModify(haiku, weather)
}

// Simple data holder for weather
data class Weather(val main: String, val description: String)

// Fetch current weather from OpenWeatherMap (JSON parsed manually, no external libs)
fun fetchWeather(): Weather {
    val url = "https://api.openweathermap.org/data/2.5/weather?q=${URLEncoder.encode(location, "UTF-8")}&appid=$apiKey&units=metric"
    val json = URL(url).readText()
    // Very naive extraction
    val main = "\"main\":\"(.*?)\"".toRegex().find(json)!!.groupValues[1]
    val desc = "\"description\":\"(.*?)\"".toRegex().find(json)!!.groupValues[1]
    return Weather(main, desc)
}

// Turn weather description into a rough 5-7-5 haiku
fun generateHaiku(desc: String): String {
    val words = desc.split(Regex("\\s+"))
    val line1 = words.take(5).joinToString(" ")
    val line2 = words.drop(5).take(7).joinToString(" ")
    val line3 = words.drop(12).take(5).joinToString(" ")
    return listOf(line1, line2, line3).joinToString("\n")
}

// Render a Mandelbrot‑style ASCII art; colour palette hinted by haiku (ignored for simplicity)
fun renderMandelbrot(haiku: String) {
    val chars = " .:-=+*#%@"
    val width = 80
    val height = 30
    for (y in 0 until height) {
        val imag = (y - height / 2) * zoom + offsetY
        val line = StringBuilder()
        for (x in 0 until width) {
            val real = (x - width / 2) * zoom + offsetX
            var zr = 0.0
            var zi = 0.0
            var i = 0
            while (zr * zr + zi * zi < 4.0 && i < maxIter) {
                val temp = zr * zr - zi * zi + real
                zi = 2 * zr * zi + imag
                zr = temp
                i++
            }
            val c = if (i == maxIter) ' ' else chars[(i * chars.length) / maxIter]
            line.append(c)
        }
        println(line)
    }
}

// Self‑modifying: embed haiku as comment and tweak parameters for next run
fun selfModify(haiku: String, weather: Weather) {
    val source = File(object {}.javaClass.enclosingClass.protectionDomain.codeSource.location.path)
        .readText()

    // Embed haiku as hidden comment
    val haikuComment = "//HAIKU_START\n// $haiku\n//HAIKU_END"
    var newSource = source.replace(Regex("//HAIKU_START[\\s\\S]*?//HAIKU_END"), haikuComment)

    // Evolve parameters: simple rule based on temperature
    val temp = extractTemperature()
    val newMaxIter = (maxIter + (temp % 10).toInt()).coerceIn(30, 200)
    val newZoom = zoom * (1.0 + (temp - 15) / 100.0)

    // Replace param markers
    newSource = newSource.replace("//PARAM_MAX_ITER", "val maxIter = $newMaxIter //PARAM_MAX_ITER")
    newSource = newSource.replace("//PARAM_ZOOM", "val zoom = $newZoom //PARAM_ZOOM")

    // Write back
    sourceFile().writeText(newSource)
}

// Helper to locate the source file of the running script
fun sourceFile(): File {
    // Assuming the script is run from a .kts file
    val path = System.getProperty("kotlin.script.execution.source.path")
        ?: throw IllegalStateException("Cannot locate source file.")
    return File(path)
}

// Extract temperature from the latest weather call (cached call)
fun extractTemperature(): Double {
    val url = "https://api.openweathermap.org/data/2.5/weather?q=${URLEncoder.encode(location, "UTF-8")}&appid=$apiKey&units=metric"
    val json = URL(url).readText()
    val tempStr = "\"temp\":([\\-\\d.]+)".toRegex().find(json)!!.groupValues[1]
    return tempStr.toDouble()
}