import java.sql.DriverManager

fun main() {
    // Establish an in-memory SQLite database connection
    val connection = DriverManager.getConnection("jdbc:sqlite::memory:")
    val statement = connection.createStatement()

    // Initialize tables for historical coffee prices and the fractal fern state
    statement.execute("""
        CREATE TABLE coffee_prices (
            year INTEGER PRIMARY KEY,
            price_usd REAL
        );
    """)

    statement.execute("""
        CREATE TABLE fern_state (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            x REAL,
            y REAL,
            iteration INTEGER
        );
    """)

    // Seed the initial point of the Barnsley fern
    statement.execute("INSERT INTO fern_state (x, y, iteration) VALUES (0.0, 0.0, 0);")

    // Construct an esoteric SQL trigger that calculates fractal affine transformations
    // dynamically modulated by global coffee price volatility on each insertion.
    statement.execute("""
        CREATE TRIGGER grow_fern AFTER INSERT ON coffee_prices
        BEGIN
            -- Self-consuming mechanism: prune older iterations to maintain memory equilibrium
            DELETE FROM fern_state WHERE id <= (SELECT MAX(id) FROM fern_state) - 400;

            -- Generate the next iteration of the fern using probabilistic transformations
            INSERT INTO fern_state (x, y, iteration)
            SELECT 
                CASE 
                    WHEN (ABS(RANDOM()) % 100) < 1 THEN 0.0
                    WHEN (ABS(RANDOM()) % 100) < 86 THEN 0.85 * x + 0.04 * y
                    WHEN (ABS(RANDOM()) % 100) < 93 THEN 0.20 * x - 0.26 * y
                    ELSE -0.15 * x + 0.28 * y + (NEW.price_usd * 0.05)
                END,
                CASE 
                    WHEN (ABS(RANDOM()) % 100) < 1 THEN 0.16 * y
                    WHEN (ABS(RANDOM()) % 100) < 86 THEN -0.04 * x + 0.85 * y + 1.60
                    WHEN (ABS(RANDOM()) % 100) < 93 THEN 0.23 * x + 0.22 * y + 1.60
                    ELSE 0.26 * x + 0.24 * y + 0.44
                END,
                NEW.year
            FROM fern_state 
            WHERE iteration = (SELECT MAX(iteration) FROM fern_state);
        END;
    """)

    // Historical global coffee price benchmarks (approximate ICO composite indicators)
    val historicalPrices = listOf(
        1970 to 0.45, 1975 to 1.25, 1980 to 1.68, 1985 to 1.40,
        1990 to 0.75, 1995 to 1.10, 2000 to 0.50, 2005 to 0.85,
        2010 to 1.45, 2015 to 1.20, 2020 to 1.15, 2026 to 2.55
    )

    val pstmt = connection.prepareStatement("INSERT INTO coffee_prices (year, price_usd) VALUES (?, ?)")
    for ((year, price) in historicalPrices) {
        pstmt.setInt(1, year)
        pstmt.setDouble(2, price)
        pstmt.executeUpdate()
    }

    // Extract the final rendered fern coordinates from the database
    val rs = statement.executeQuery("SELECT x, y FROM fern_state")
    val points = mutableListOf<Pair<Double, Double>>()
    while (rs.next()) {
        points.add(Pair(rs.getDouble("x"), rs.getDouble("y")))
    }

    // Render the esoteric text-based ASCII representation to standard output
    if (points.isNotEmpty()) {
        val width = 90
        val height = 45
        val minX = points.minOf { it.first }
        val maxX = points.maxOf { it.first }
        val minY = points.minOf { it.second }
        val maxY = points.maxOf { it.second }

        val grid = Array(height) { CharArray(width) { ' ' } }

        for ((x, y) in points) {
            val col = ((x - minX) / (maxX - minX + 1e-9) * (width - 1)).toInt().coerceIn(0, width - 1)
            val row = (height - 1 - ((y - minY) / (maxY - minY + 1e-9) * (height - 1))).toInt().coerceIn(0, height - 1)
            grid[row][col] = '*'
        }

        println("=== COFFEE-DRIVEN SQL FRACTAL FERN ENGINE ===")
        for (row in grid) {
            println(String(row))
        }
    }

    connection.close()
}