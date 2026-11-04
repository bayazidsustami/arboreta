import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import kotlin.math.*
import java.util.Random

// Holds real-time meteorological parameters fetched from open APIs
data class Weather(val windSpeed: Double, val windDir: Double, val pressure: Double)

// Fetches live atmospheric data using Java HTTP client and lightweight regex parsing
fun fetchLiveWeather(): Weather {
    try {
        val client = HttpClient.newHttpClient()
        val request = HttpRequest.newBuilder()
            .uri(URI.create("[https://api.open-meteo.com/v1/forecast?latitude=40.71&longitude=-74.01&current=surface_pressure,wind_speed_10m,wind_direction_10m](https://api.open-meteo.com/v1/forecast?latitude=40.71&longitude=-74.01&current=surface_pressure,wind_speed_10m,wind_direction_10m)"))
            .build()
        val response = client.send(request, HttpResponse.BodyHandlers.ofString())
        val body = response.body()
        
        val speed = "wind_speed_10m\":([0-9.]+)".toRegex().find(body)?.groupValues?.get(1)?.toDouble() ?: 15.0
        val dir = "wind_direction_10m\":([0-9.]+)".toRegex().find(body)?.groupValues?.get(1)?.toDouble() ?: 180.0
        val pressure = "surface_pressure\":([0-9.]+)".toRegex().find(body)?.groupValues?.get(1)?.toDouble() ?: 1013.25
        
        return Weather(speed, dir, pressure)
    } catch (e: Exception) {
        // Fallback simulation parameters if offline
        return Weather(14.2, 210.0, 1008.5)
    }
}

fun main() {
    println("Sampling atmospheric conditions...")
    val weather = fetchLiveWeather()
    println("Current Live Weather -> Wind Speed: ${weather.windSpeed} km/h | Direction: ${weather.windDir}° | Pressure: ${weather.pressure} hPa\n")

    val width = 39
    val height = 17
    
    // Seed generator with wind vector characteristics
    val seed = (weather.windSpeed * weather.windDir).toInt()
    val rng = Random(seed.toLong())

    // Atmospheric pressure dictates wall erosion: lower pressure causes walls to crumble
    val pressureDelta = weather.pressure - 1013.25
    val structuralIntegrity = (1.0 + (pressureDelta / 40.0)).coerceIn(0.2, 1.0)

    // Convert wind direction into directional flow vectors
    val angleRad = Math.toRadians(weather.windDir)
    val flowX = cos(angleRad)
    val flowY = sin(angleRad)

    // Construct the shifting text labyrinth grid
    val grid = Array(height) { y ->
        CharArray(width) { x ->
            val nx = x.toDouble() / width
            val ny = y.toDouble() / height
            val vectorInfluence = sin(nx * flowX * 6.0 + ny * flowY * 6.0)
            
            val density = 0.45 + (weather.windSpeed / 120.0) * 0.25
            val roll = rng.nextDouble()

            when {
                x == 0 || x == width - 1 || y == 0 || y == height - 1 -> '█' // Outer boundary
                roll < (density * structuralIntegrity) -> if (vectorInfluence > 0) '▓' else '▒'
                else -> ' ' // Open corridors eroded by wind
            }
        }
    }

    // Render the live-generated labyrinth
    println("=== THE BAROMETRIC LABYRINTH ===")
    for (row in grid) {
        println(String(row))
    }
    println("\nLegend: █ / ▓ / ▒ = Crystalline Walls (Density shifts with wind) | ' ' = Corridors")
    println("System Note: Structure stability continuously decays under low pressure zones.")
}

main()