/*
 * Esoteric Cellular Automaton: Atmospheric ASCII Textile Weaver
 * Translates real-time (or simulated fallback) weather data into an evolving,
 * multi-threaded woven ASCII textile pattern.
 *
 * Thread Types (Atmospheric Variables):
 *   Warp   (|) : Temperature (determines thread density/tension)
 *   Weft   (-) : Humidity (determines moisture weave structure)
 *   Wind   (/,\) : Wind Speed & Direction (determines bias/shear in cell state)
 *   Pressure (*,+) : Atmospheric Pressure (determines knotting & state transitions)
 */

(async function () {
  // Configurable location or fallback coordinates (London as default)
  const LAT = 51.5074;
  const LON = -0.1278;

  // Visual Textile Canvas Dimensions
  const WIDTH = 64;
  const HEIGHT = 32;

  // Glyph sets for atmospheric thread weaving
  const THREADS = {
    warp: ['|', '!', '¦', '║', '┆'],        // Temperature / Vertical tension
    weft: ['-', '=', '~', '≡', '┄'],        // Humidity / Horizontal fill
    shearR: ['/', '⎍', '╱'],                // Wind right
    shearL: ['\\', '⎎', '╲'],               // Wind left
    knot: ['*', '+', '#', '×', '¤', '•'],   // Pressure / Intersection knots
    air: [' ', '·']                         // Void
  };

  // Fetch real-time weather from Open-Meteo free API (no key required)
  async function fetchAtmosphericData() {
    try {
      const url = `[https://api.open-meteo.com/v1/forecast?latitude=$](https://api.open-meteo.com/v1/forecast?latitude=$){LAT}&longitude=${LON}&current_weather=true&hourly=relativehumidity_2m,surface_pressure`;
      const res = await fetch(url);
      if (!res.ok) throw new Error('Network response failed');
      const data = await res.json();

      const temp = data.current_weather.temperature; // Celsius
      const windSpeed = data.current_weather.windspeed; // km/h
      const windDir = data.current_weather.winddirection; // degrees
      const humidity = data.hourly ? data.hourly.relativehumidity_2m[0] : 65; // %
      const pressure = data.hourly ? data.hourly.surface_pressure[0] : 1013; // hPa

      return parseWeatherToParameters(temp, humidity, windSpeed, windDir, pressure);
    } catch (e) {
      // Fallback synthetic weather parameters if offline/rate-limited
      return parseWeatherToParameters(18, 72, 14, 135, 1015);
    }
  }

  // Normalize weather metrics into Cellular Automaton transition parameters
  function parseWeatherToParameters(temp, humidity, windSpeed, windDir, pressure) {
    return {
      // Temperature (0-1): Higher temp = tighter vertical warp weave
      tempFactor: Math.min(Math.max((temp + 10) / 50, 0.1), 0.95),
      // Humidity (0-1): Higher humidity = dense weft/moisture saturation
      humidityFactor: Math.min(Math.max(humidity / 100, 0.1), 0.95),
      // Wind Speed (0-1): Drives transition rate and shear strength
      windStrength: Math.min(Math.max(windSpeed / 50, 0.05), 1.0),
      // Wind Direction (-1 to 1): Determines left vs right slant bias
      windBias: Math.cos((windDir * Math.PI) / 180),
      // Pressure (0-1): High pressure stabilizes pattern, low pressure creates knots
      pressureChaos: Math.min(Math.max((1035 - pressure) / 50, 0.05), 0.9)
    };
  }

  // Initialize Cellular Automaton Matrix
  let grid = Array.from({ length: HEIGHT }, () =>
    Array.from({ length: WIDTH }, () => Math.floor(Math.random() * 4))
  );

  // Core Cellular Automaton rule engine translating atmosphere into textile state
  function stepTextileCA(grid, env) {
    const next = Array.from({ length: HEIGHT }, () => new Array(WIDTH));

    for (let y = 0; y < HEIGHT; y++) {
      for (let x = 0; x < WIDTH; x++) {
        // Neighborhood analysis (Moore neighborhood with wrap-around topology)
        let neighbors = 0;
        let skewSum = 0;

        for (let dy = -1; dy <= 1; dy++) {
          for (let dx = -1; dx <= 1; dx++) {
            if (dx === 0 && dy === 0) continue;
            const ny = (y + dy + HEIGHT) % HEIGHT;
            const nx = (x + dx + WIDTH) % WIDTH;
            const state = grid[ny][nx];

            if (state > 0) neighbors++;
            skewSum += (dx * env.windBias);
          }
        }

        const currentState = grid[y][x];
        let newState = currentState;

        // Custom Weaver Rules:
        // Rule 1: Warp thread creation governed by Temperature factor
        if (currentState === 0 && Math.random() < env.tempFactor * 0.3) {
          newState = 1; // Vertical Warp
        }
        // Rule 2: Weft thread crossing governed by Humidity saturation
        else if (currentState === 1 && Math.random() < env.humidityFactor * 0.4) {
          newState = 2; // Horizontal Weft
        }
        // Rule 3: Wind shear skews threads diagonally
        else if (neighbors >= 3 && Math.random() < env.windStrength) {
          newState = skewSum >= 0 ? 3 : 4; // Diagonal Shear
        }
        // Rule 4: Low pressure/chaos causes threads to knot together
        else if (neighbors >= 5 && Math.random() < env.pressureChaos) {
          newState = 5; // Pressure Knot
        }
        // Rule 5: Over-tension or decay clears thread (Loom re-threading)
        else if (neighbors > 6 || (neighbors < 2 && Math.random() > 0.7)) {
          newState = 0; // Void / Air gap
        }

        next[y][x] = newState;
      }
    }
    return next;
  }

  // Render numerical state matrix into atmospheric woven ASCII textile
  function renderTextile(grid, env) {
    let output = `═══ Atmospheric Textile Loom ═══ [T:${(env.tempFactor*100).toFixed(0)}% | H:${(env.humidityFactor*100).toFixed(0)}% | W:${(env.windStrength*100).toFixed(0)}%] ═══\n`;

    for (let y = 0; y < HEIGHT; y++) {
      let row = '║ ';
      for (let x = 0; x < WIDTH; x++) {
        const state = grid[y][x];
        let symbol;

        switch (state) {
          case 1: // Temperature Warp
            symbol = THREADS.warp[(x + y) % THREADS.warp.length];
            break;
          case 2: // Humidity Weft
            symbol = THREADS.weft[(x * y) % THREADS.weft.length];
            break;
          case 3: // Wind Shear Right
            symbol = THREADS.shearR[(x + y) % THREADS.shearR.length];
            break;
          case 4: // Wind Shear Left
            symbol = THREADS.shearL[(x + y) % THREADS.shearL.length];
            break;
          case 5: // Pressure Knot
            symbol = THREADS.knot[(x ^ y) % THREADS.knot.length];
            break;
          default: // Air / Void
            symbol = THREADS.air[(x + y) % THREADS.air.length];
        }
        row += symbol;
      }
      row += ' ║\n';
      output += row;
    }

    output += '╚' + '═'.repeat(WIDTH + 2) + '╝';
    return output;
  }

  // Initialize and run life cycle
  const env = await fetchAtmosphericData();

  function animate() {
    grid = stepTextileCA(grid, env);
    const frame = renderTextile(grid, env);

    if (typeof console.clear === 'function') console.clear();
    console.log(frame);
  }

  // Start continuous weaving loom animation (200ms per shuttle pass)
  setInterval(animate, 200);
})();