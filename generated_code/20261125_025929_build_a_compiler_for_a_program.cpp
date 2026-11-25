#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include#include <cmath>
#include <iomanip>
#include <stdexcept>
#include <algorithm>
#include <cctype>

// ============================================================================
// GEO-WEATHER VM & COMPILER ("TerraByte" / "GeoASM")
// Memory addresses are (latitude, longitude) pairs on Earth.
// Executing instructions flies a virtual drone between coordinate cells and
// uses deterministic/simulated regional weather telemetry to mutate values.
// ============================================================================

constexpr double EARTH_RADIUS_KM = 6371.0;
constexpr double PI = 3.14159265358979323846;

inline double deg2rad(double deg) { return deg * (PI / 180.0); }

// Great-circle Haversine distance in kilometers between two Earth coordinates
double haversine_km(double lat1, double lon1, double lat2, double lon2) {
    double dlat = deg2rad(lat2 - lat1);
    double dlon = deg2rad(lon2 - lon1);
    double a = std::sin(dlat / 2.0) * std::sin(dlat / 2.0) +
               std::cos(deg2rad(lat1)) * std::cos(deg2rad(lat2)) *
               std::sin(dlon / 2.0) * std::sin(dlon / 2.0);
    double c = 2.0 * std::atan2(std::sqrt(a), std::sqrt(std::max(0.0, 1.0 - a)));
    return EARTH_RADIUS_KM * c;
}

struct GeoCoord {
    double lat = 0.0;
    double lon = 0.0;

    bool operator<(const GeoCoord& o) const {
        if (std::abs(lat - o.lat) > 1e-6) return lat < o.lat;
        return lon < o.lon;
    }

    std::string str() const {
        std::ostringstream oss;
        oss << std::fixed << std::setprecision(4) << "(" << lat << ", " << lon << ")";
        return oss.str();
    }
};

struct WeatherTelemetry {
    double temp_c = 15.0;      // Temperature in Celsius
    double wind_mps = 5.0;     // Wind speed in m/s
    double pressure_hpa = 1013.25;
    double humidity = 0.5;     // 0.0 to 1.0
    std::string condition = "Clear";
};

// Deterministic procedural weather engine based on coordinates & flight distance
class WeatherOracle {
public:
    static WeatherTelemetry sample(const GeoCoord& c, double flight_km) {
        // Smooth harmonic field so nearby coordinates have realistic gradients
        double wave_t = std::sin(deg2rad(c.lat * 2.0)) * 18.0 +
                        std::cos(deg2rad(c.lon * 1.5)) * 6.0 + 12.0;
        double wave_w = std::abs(std::sin(deg2rad(c.lat * 3.7 + c.lon * 2.3))) * 18.0 +
                        std::min(15.0, flight_km * 0.002);
        double wave_p = 1013.25 + std::cos(deg2rad(c.lat * 1.3 - c.lon * 0.9)) * 22.0;
        double wave_h = std::clamp(0.55 + 0.35 * std::sin(deg2rad(c.lon * 4.1)), 0.05, 0.99);

        WeatherTelemetry w;
        w.temp_c = std::round(wave_t * 100.0) / 100.0;
        w.wind_mps = std::round(wave_w * 100.0) / 100.0;
        w.pressure_hpa = std::round(wave_p * 100.0) / 100.0;
        w.humidity = std::round(wave_h * 1000.0) / 1000.0;

        if (w.wind_mps > 16.0) w.condition = "Gale";
        else if (w.humidity > 0.82 && w.temp_c > 0.0) w.condition = "Rain";
        else if (w.humidity > 0.80 && w.temp_c <= 0.0) w.condition = "Snow";
        else if (w.humidity > 0.65) w.condition = "Cloudy";
        else w.condition = "Clear";

        return w;
    }
};

// ============================================================================
// INSTRUCTION SET & COMPILER
// Supported instructions:
//   BIND <var> <lat> <lon>          - Bind variable <var> to Earth memory cell
//   STORE <var> <val>               - Store numeric value at <var>'s coordinate
//   FLY <var>                       - Fly drone to <var>'s coordinate
//   WEATHER_MUTATE <var> <MODE>     - Mutate <var> using local weather telemetry
//                                     Modes: TEMP, WIND, PRESSURE, GUST, ALL
//   ADD <dst> <src>                 - dst = dst + src (flies to src, then dst)
//   MUL <dst> <src>                 - dst = dst * src
//   PRINT <var>                     - Print <var>, its coordinate, and weather
//   JUMP_IF_GT <var> <val> <label>  - Conditional branch if var > val
//   LABEL <name>                    - Jump target
// ============================================================================

enum class OpCode {
    BIND,
    STORE,
    FLY,
    WEATHER_MUTATE,
    ADD,
    MUL,
    PRINT,
    JUMP_IF_GT,
    LABEL
};

struct Instruction {
    OpCode op;
    std::string s1;
    std::string s2;
    double d1 = 0.0;
    double d2 = 0.0;
    int line_no = 0;
};

struct CompiledProgram {
    std::vector<Instruction> code;
    std::map<std::string, size_t> labels;
};

class GeoCompiler {
public:
    static CompiledProgram compile(const std::string& source) {
        CompiledProgram prog;
        std::istringstream iss(source);
        std::string line;
        int line_no = 0;

        while (std::getline(iss, line)) {
            ++line_no;
            // Strip comments starting with '#' or '//'
            auto hash_pos = line.find('#');
            if (hash_pos != std::string::npos) line = line.substr(0, hash_pos);
            auto slash_pos = line.find("//");
            if (slash_pos != std::string::npos) line = line.substr(0, slash_pos);

            std::istringstream ls(line);
            std::string mnemonic;
            if (!(ls >> mnemonic)) continue; // Blank line

            for (auto& ch : mnemonic) ch = static_cast<char>(std::toupper(static_cast<unsigned char>(ch)));

            Instruction inst;
            inst.line_no = line_no;

            if (mnemonic == "LABEL") {
                std::string name;
                if (!(ls >> name)) throw compile_error(line_no, "LABEL requires a name");
                if (prog.labels.count(name)) throw compile_error(line_no, "Duplicate label: " + name);
                inst.op = OpCode::LABEL;
                inst.s1 = name;
                prog.labels[name] = prog.code.size();
                prog.code.push_back(inst);
            } else if (mnemonic == "BIND") {
                inst.op = OpCode::BIND;
                if (!(ls >> inst.s1 >> inst.d1 >> inst.d2))
                    throw compile_error(line_no, "BIND requires <var> <lat> <lon>");
                validate_coord(line_no, inst.d1, inst.d2);
                prog.code.push_back(inst);
            } else if (mnemonic == "STORE") {
                inst.op = OpCode::STORE;
                if (!(ls >> inst.s1 >> inst.d1))
                    throw compile_error(line_no, "STORE requires <var> <value>");
                prog.code.push_back(inst);
            } else if (mnemonic == "FLY") {
                inst.op = OpCode::FLY;
                if (!(ls >> inst.s1))
                    throw compile_error(line_no, "FLY requires <var>");
                prog.code.push_back(inst);
            } else if (mnemonic == "WEATHER_MUTATE") {
                inst.op = OpCode::WEATHER_MUTATE;
                if (!(ls >> inst.s1 >> inst.s2))
                    throw compile_error(line_no, "WEATHER_MUTATE requires <var> <MODE>");
                for (auto& ch : inst.s2) ch = static_cast<char>(std::toupper(static_cast<unsigned char>(ch)));
                prog.code.push_back(inst);
            } else if (mnemonic == "ADD") {
                inst.op = OpCode::ADD;
                if (!(ls >> inst.s1 >> inst.s2))
                    throw compile_error(line_no, "ADD requires <dst_var> <src_var>");
                prog.code.push_back(inst);
            } else if (mnemonic == "MUL") {
                inst.op = OpCode::MUL;
                if (!(ls >> inst.s1 >> inst.s2))
                    throw compile_error(line_no, "MUL requires <dst_var> <src_var>");
                prog.code.push_back(inst);
            } else if (mnemonic == "PRINT") {
                inst.op = OpCode::PRINT;
                if (!(ls >> inst.s1))
                    throw compile_error(line_no, "PRINT requires <var>");
                prog.code.push_back(inst);
            } else if (mnemonic == "JUMP_IF_GT") {
                inst.op = OpCode::JUMP_IF_GT;
                if (!(ls >> inst.s1 >> inst.d1 >> inst.s2))
                    throw compile_error(line_no, "JUMP_IF_GT requires <var> <threshold> <label>");
                prog.code.push_back(inst);
            } else {
                throw compile_error(line_no, "Unknown instruction: " + mnemonic);
            }
        }

        // Verify jump targets exist
        for (const auto& inst : prog.code) {
            if (inst.op == OpCode::JUMP_IF_GT && !prog.labels.count(inst.s2)) {
                throw compile_error(inst.line_no, "Undefined jump label: " + inst.s2);
            }
        }
        return prog;
    }

private:
    static void validate_coord(int line_no, double lat, double lon) {
        if (lat < -90.0 || lat > 90.0 || lon < -180.0 || lon > 180.0) {
            throw compile_error(line_no, "Coordinate out of Earth bounds [-90..90, -180..180]");
        }
    }

    static std::runtime_error compile_error(int line_no, const std::string& msg) {
        return std::runtime_error("Compile error [line " + std::to_string(line_no) + "]: " + msg);
    }
};

// ============================================================================
// VIRTUAL DRONE & EARTH MEMORY RUNTIME
// ============================================================================

struct GeoCell {
    GeoCoord coord;
    double value = 0.0;
};

class DroneGeoVM {
public:
    explicit DroneGeoVM(GeoCoord start_pos = {0.0, 0.0}) : drone_pos_(start_pos) {}

    void execute(const CompiledProgram& prog) {
        size_t pc = 0;
        size_t steps = 0;
        constexpr size_t MAX_STEPS = 10000; // Guard against infinite loops

        while (pc < prog.code.size()) {
            if (++steps > MAX_STEPS) {
                throw std::runtime_error("Runtime error: max flight instruction budget exceeded");
            }
            const auto& inst = prog.code[pc];
            switch (inst.op) {
                case OpCode::LABEL:
                    ++pc;
                    break;
                case OpCode::BIND: {
                    GeoCell cell;
                    cell.coord = {inst.d1, inst.d2};
                    cell.value = 0.0;
                    vars_[inst.s1] = cell;
                    ++pc;
                    break;
                }
                case OpCode::STORE: {
                    auto& cell = get_var(inst.s1, inst.line_no);
                    fly_to(cell.coord);
                    cell.value = inst.d1;
                    ++pc;
                    break;
                }
                case OpCode::FLY: {
                    auto& cell = get_var(inst.s1, inst.line_no);
                    fly_to(cell.coord);
                    ++pc;
                    break;
                }
                case OpCode::WEATHER_MUTATE: {
                    auto& cell = get_var(inst.s1, inst.line_no);
                    double dist = fly_to(cell.coord);
                    WeatherTelemetry w = WeatherOracle::sample(cell.coord, dist);
                    cell.value = apply_weather(cell.value, w, inst.s2, inst.line_no);
                    ++pc;
                    break;
                }
                case OpCode::ADD: {
                    auto& dst = get_var(inst.s1, inst.line_no);
                    auto& src = get_var(inst.s2, inst.line_no);
                    fly_to(src.coord);
                    double s_val = src.value;
                    fly_to(dst.coord);
                    dst.value += s_val;
                    ++pc;
                    break;
                }
                case OpCode::MUL: {
                    auto& dst = get_var(inst.s1, inst.line_no);
                    auto& src = get_var(inst.s2, inst.line_no);
                    fly_to(src.coord);
                    double s_val = src.value;
                    fly_to(dst.coord);
                    dst.value *= s_val;
                    ++pc;
                    break;
                }
                case OpCode::PRINT: {
                    auto& cell = get_var(inst.s1, inst.line_no);
                    double dist = fly_to(cell.coord);
                    WeatherTelemetry w = WeatherOracle::sample(cell.coord, dist);
                    std::cout << std::fixed << std::setprecision(2)
                              << "[VAR " << inst.s1 << "] @ " << cell.coord.str()
                              << " | val=" << cell.value
                              << " | weather=" << w.condition
                              << " (T=" << w.temp_c << "C, wind=" << w.wind_mps
                              << "m/s, P=" << w.pressure_hpa << "hPa)\n";
                    ++pc;
                    break;
                }
                case OpCode::JUMP_IF_GT: {
                    auto& cell = get_var(inst.s1, inst.line_no);
                    fly_to(cell.coord);
                    if (cell.value > inst.d1) {
                        pc = prog.labels.at(inst.s2);
                    } else {
                        ++pc;
                    }
                    break;
                }
            }
        }

        std::cout << "\n--- Flight Summary ---\n"
                  << "Final Drone Position: " << drone_pos_.str() << "\n"
                  << "Total Distance Flown: " << std::fixed << std::setprecision(2)
                  << total_distance_km_ << " km\n";
    }

private:
    GeoCoord drone_pos_;
    double total_distance_km_ = 0.0;
    std::map<std::string, GeoCell> vars_;

    GeoCell& get_var(const std::string& name, int line_no) {
        auto it = vars_.find(name);
        if (it == vars_.end()) {
            throw std::runtime_error("Runtime error [line " + std::to_string(line_no) +
                                     "]: unbound geo-variable '" + name + "'");
        }
        return it->second;
    }

    double fly_to(const GeoCoord& target) {
        double d = haversine_km(drone_pos_.lat, drone_pos_.lon, target.lat, target.lon);
        total_distance_km_ += d;
        drone_pos_ = target;
        return d;
    }

    static double apply_weather(double val, const WeatherTelemetry& w,
                                const std::string& mode, int line_no) {
        if (mode == "TEMP") {
            return val + w.temp_c;
        } else if (mode == "WIND") {
            return val * (1.0 + w.wind_mps * 0.05);
        } else if (mode == "PRESSURE") {
            return val + (w.pressure_hpa - 1013.25) * 0.25;
        } else if (mode == "GUST") {
            return val + (w.wind_mps * w.humidity) - (w.temp_c * 0.1);
        } else if (mode == "ALL") {
            return (val + w.temp_c * 0.5) * (1.0 + w.wind_mps * 0.02) + w.humidity * 10.0;
        }
        throw std::runtime_error("Runtime error [line " + std::to_string(line_no) +
                                 "]: unknown WEATHER_MUTATE mode '" + mode + "'");
    }
};

// Sample GeoASM program flying across Earth memory cells and mutating values via weather
const char* SAMPLE_PROGRAM = R"(
# Bind variables to real Earth coordinates (lat, lon)
BIND reykjavik  64.1466  -21.9426
BIND tokyo      35.6762  139.6503
BIND nairobi    -1.2921   36.8219
BIND santiago  -33.4489  -70.6693

# Initialize values by physically flying to each memory cell
STORE reykjavik 20.0
STORE tokyo     15.0
STORE nairobi   10.0
STORE santiago   5.0

# Mutate values using local weather telemetry at each coordinate
WEATHER_MUTATE reykjavik TEMP
WEATHER_MUTATE tokyo     WIND
WEATHER_MUTATE nairobi   GUST
WEATHER_MUTATE santiago  ALL

# Combine remote memory cells (drone flies between source and destination)
ADD tokyo reykjavik
MUL nairobi santiago

LABEL loop_check
PRINT nairobi
JUMP_IF_GT nairobi 500.0 cool_down
ADD nairobi tokyo
JUMP_IF_GT nairobi 0.0 loop_check

LABEL cool_down
WEATHER_MUTATE nairobi PRESSURE
PRINT reykjavik
PRINT tokyo
PRINT nairobi
PRINT santiago
)";

int main(int argc, char* argv[]) {
    try {
        std::string source;
        if (argc > 1) {
            std::ifstream file(argv[1]);
            if (!file) {
                std::cerr << "Failed to open source file: " << argv[1] << "\n";
                return 1;
            }
            std::ostringstream buf;
            buf << file.rdbuf();
            source = buf.str();
        } else {
            std::cout << "No input file given; compiling built-in sample GeoASM flight program...\n\n";
            source = SAMPLE_PROGRAM;
        }

        CompiledProgram compiled = GeoCompiler::compile(source);
        DroneGeoVM vm({37.7749, -122.4194}); // Drone launches from San Francisco
        vm.execute(compiled);
    } catch (const std::exception& ex) {
        std::cerr << ex.what() << "\n";
        return 1;
    }
    return 0;
}