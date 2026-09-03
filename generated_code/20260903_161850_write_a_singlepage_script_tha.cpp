#include <iostream>
#include <vector>
#include <string>
#include <cmath>
#include <algorithm>
#include <random>
#include <memory>
#include <chrono>
#include <thread>
#include <iomanip>
#include <sstream>

#if defined(_WIN32)
#include <windows.h>
#include <tlhelp32.h>
#include <psapi.h>
#else
#include <unistd.h>
#include <dirent.h>
#include <fstream>
#include <sys/ioctl.h>
#include <termios.h>
#endif

// Represents a process as a celestial body in our ASCII universe
struct Star {
    unsigned long pid;
    std::string name;
    size_t memory_bytes;
    float x, y;          // Screen coordinates
    float target_x, target_y; // Smooth motion targets
    char symbol;
    std::string color;
};

// Process Information Fetching (Cross-platform support)
struct ProcessInfo {
    unsigned long pid;
    std::string name;
    size_t memory_bytes;
};

std::vector<ProcessInfo> get_system_processes() {
    std::vector<ProcessInfo> processes;

#if defined(_WIN32)
    HANDLE hSnap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnap == INVALID_HANDLE_VALUE) return processes;

    PROCESSENTRY32W pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32W);

    if (Process32FirstW(hSnap, &pe32)) {
        do {
            HANDLE hProc = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, pe32.th32ProcessID);
            size_t mem = 0;
            if (hProc) {
                PROCESS_MEMORY_COUNTERS pmc;
                if (GetProcessMemoryInfo(hProc, &pmc, sizeof(pmc))) {
                    mem = pmc.WorkingSetSize;
                }
                CloseHandle(hProc);
            }
            
            // Convert wide string to standard string
            std::wstring wName(pe32.szExeFile);
            std::string name(wName.begin(), wName.end());
            
            if (mem > 0) {
                processes.push_back({pe32.th32ProcessID, name, mem});
            }
        } while (Process32NextW(hSnap, &pe32));
    }
    CloseHandle(hSnap);
#else
    DIR* proc_dir = opendir("/proc");
    if (!proc_dir) return processes;

    struct dirent* entry;
    while ((entry = readdir(proc_dir)) != nullptr) {
        if (entry->d_type == DT_DIR) {
            std::string pid_str = entry->d_name;
            if (std::all_of(pid_str.begin(), pid_str.end(), ::isdigit)) {
                unsigned long pid = std::stoul(pid_str);
                std::ifstream status_file("/proc/" + pid_str + "/status");
                std::string line, name = "unknown";
                size_t mem = 0;

                while (std::getline(status_file, line)) {
                    if (line.rfind("Name:", 0) == 0) {
                        name = line.substr(6);
                        name.erase(0, name.find_first_not_of(" \t"));
                    } else if (line.rfind("VmRSS:", 0) == 0) {
                        std::stringstream ss(line.substr(6));
                        size_t kb;
                        ss >> kb;
                        mem = kb * 1024; // Convert KB to Bytes
                    }
                }
                if (mem > 0) {
                    processes.push_back({pid, name, mem});
                }
            }
        }
    }
    closedir(proc_dir);
#endif

    // Sort descending by memory usage to highlight significant processes
    std::sort(processes.begin(), processes.end(), [](const ProcessInfo& a, const ProcessInfo& b) {
        return a.memory_bytes > b.memory_bytes;
    });

    return processes;
}

// Get current terminal dimensions
void get_terminal_size(int& width, int& height) {
#if defined(_WIN32)
    CONSOLE_SCREEN_BUFFER_INFO csbi;
    GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &csbi);
    width = csbi.srWindow.Right - csbi.srWindow.Left + 1;
    height = csbi.srWindow.Bottom - csbi.srWindow.Top + 1;
#else
    struct winsize w;
    ioctl(STDOUT_FILENO, TIOCGWINSZ, &w);
    width = w.ws_col;
    height = w.ws_row;
#endif
    width = std::max(width, 40);
    height = std::max(height, 20);
}

// Map process memory magnitude to dynamic star symbols and ANSI intensity colors
std::pair<char, std::string> get_star_appearance(size_t mem, size_t max_mem) {
    float ratio = static_cast<float>(mem) / std::max<size_t>(max_mem, 1);
    
    // Symbols ordered by visual density/brightness
    static const char symbols[] = { '.', '·', '*', 'o', 'O', '@', '█' };
    static const std::string colors[] = {
        "\033[34m", // Dim Blue
        "\033[36m", // Cyan
        "\033[32m", // Green
        "\033[33m", // Yellow
        "\033[35m", // Magenta
        "\033[31m", // Bright Red
        "\033[97m"  // Supernova White
    };

    int idx = static_cast<int>(ratio * 6.99f);
    idx = std::clamp(idx, 0, 6);
    return {symbols[idx], colors[idx]};
}

// Distance helper for drawing constellation lines
float distance(float x1, float y1, float x2, float y2) {
    return std::sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
}

int main() {
    // Hide cursor and clear terminal space
    std::cout << "\033[?25l\033[2J";

    std::mt19937 rng(1337); // Deterministic pseudo-positions per PID
    std::vector<Star> stars;

    while (true) {
        int width, height;
        get_terminal_size(width, height);
        int map_height = height - 4; // Reserve header and footer telemetry space

        auto procs = get_system_processes();
        size_t max_mem = procs.empty() ? 1 : procs[0].memory_bytes;

        // Limit star capacity to canvas fit
        size_t max_stars = std::min(procs.size(), static_cast<size_t>(width * map_height / 12));
        procs.resize(max_stars);

        // Update celestial positions deterministically from PID
        std::vector<Star> next_stars;
        for (const auto& p : procs) {
            std::mt19937 pid_rng(p.pid);
            std::uniform_real_distribution<float> dist_x(2.0f, static_cast<float>(width - 3));
            std::uniform_real_distribution<float> dist_y(2.0f, static_cast<float>(map_height - 1));

            auto [sym, col] = get_star_appearance(p.memory_bytes, max_mem);

            Star star;
            star.pid = p.pid;
            star.name = p.name;
            star.memory_bytes = p.memory_bytes;
            star.target_x = dist_x(pid_rng);
            star.target_y = dist_y(pid_rng);
            star.symbol = sym;
            star.color = col;

            // Retain smoothly animated spatial states
            auto existing = std::find_if(stars.begin(), stars.end(), [&](const Star& s) { return s.pid == p.pid; });
            if (existing != stars.end()) {
                star.x = existing->x + (star.target_x - existing->x) * 0.3f;
                star.y = existing->y + (star.target_y - existing->y) * 0.3f;
            } else {
                star.x = star.target_x;
                star.y = star.target_y;
            }
            next_stars.push_back(star);
        }
        stars = next_stars;

        // Initialize display frame buffers (Character + Color state buffers)
        std::vector<std::string> buffer(map_height, std::string(width, ' '));
        std::vector<std::vector<std::string>> color_buffer(map_height, std::vector<std::string>(width, "\033[0m"));

        // Render Constellation Links between adjacent star nodes
        for (size_t i = 0; i < stars.size(); ++i) {
            for (size_t j = i + 1; j < stars.size(); ++j) {
                float d = distance(stars[i].x, stars[i].y, stars[j].x, stars[j].y);
                // Connect stars close in physical distance or with high relative memory weights
                if (d < 12.0f) {
                    int x0 = static_cast<int>(stars[i].x), y0 = static_cast<int>(stars[i].y);
                    int x1 = static_cast<int>(stars[j].x), y1 = static_cast<int>(stars[j].y);
#include <iostream>
#include <vector>
#include <string>
#include <algorithm>
#include <cmath>
#include <chrono>
#include <thread>
#include <iomanip>
#include <sstream>
#include <filesystem>
#include <fstream>

#if defined(_WIN32)
#include <windows.h>
#include <psapi.h>
#elif defined(__APPLE__)
#include <mach/mach.h>
#include <sys/sysctl.h>
#else
#include <dirent.h>
#include <unistd.h>
#include <sys/ioctl.h>
#endif

// Represents a real-time process translated into an astronomical star
struct Star {
    std::string name;
    size_t pid;
    size_t memory_bytes;
    float x, y;         // Normalized orbital coordinates [-1.0, 1.0]
    float screen_x, screen_y;
    char symbol;
    int brightness;     // ANSI color level
};

// Retrieve system process info and current memory consumption
std::vector<Star> get_process_stars() {
    std::vector<Star> stars;
    
#if defined(_WIN32)
    DWORD aProcesses[1024], cbNeeded, cProcesses;
    if (EnumProcesses(aProcesses, sizeof(aProcesses), &cbNeeded)) {
        cProcesses = cbNeeded / sizeof(DWORD);
        for (unsigned int i = 0; i < cProcesses; i++) {
            if (aProcesses[i] != 0) {
                HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, aProcesses[i]);
                if (hProcess) {
                    PROCESS_MEMORY_COUNTERS pmc;
                    if (GetProcessMemoryInfo(hProcess, &pmc, sizeof(pmc))) {
                        TCHAR szProcessName[MAX_PATH] = TEXT("<unknown>");
                        HMODULE hMod;
                        DWORD cbNeededMod;
                        if (EnumProcessModules(hProcess, &hMod, sizeof(hMod), &cbNeededMod)) {
                            GetModuleBaseName(hProcess, hMod, szProcessName, sizeof(szProcessName)/sizeof(TCHAR));
                        }
                        Star star;
                        star.pid = aProcesses[i];
                        star.name = szProcessName;
                        star.memory_bytes = pmc.WorkingSetSize;
                        stars.push_back(star);
                    }
                    CloseHandle(hProcess);
                }
            }
        }
    }
#elif defined(__APPLE__)
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size;
    if (sysctl(mib, 4, NULL, &size, NULL, 0) == 0) {
        struct kinfo_proc* procs = (struct kinfo_proc*)malloc(size);
        if (sysctl(mib, 4, procs, &size, NULL, 0) == 0) {
            int count = size / sizeof(struct kinfo_proc);
            for (int i = 0; i < count; ++i) {
                mach_port_t task;
                if (task_for_pid(mach_task_self(), procs[i].kp_proc.p_pid, &task) == KERN_SUCCESS) {
                    mach_task_basic_info_data_t info;
                    mach_msg_type_number_t count_info = MACH_TASK_BASIC_INFO_COUNT;
                    if (task_info(task, MACH_TASK_BASIC_INFO, (task_info_t)&info, &count_info) == KERN_SUCCESS) {
                        Star star;
                        star.pid = procs[i].kp_proc.p_pid;
                        star.name = procs[i].kp_proc.p_comm;
                        star.memory_bytes = info.resident_size;
                        stars.push_back(star);
                    }
                }
            }
        }
        free(procs);
    }
#else // Linux / POSIX fallback
    DIR* proc_dir = opendir("/proc");
    if (proc_dir) {
        struct dirent* entry;
        while ((entry = readdir(proc_dir)) != nullptr) {
            if (entry->d_type == DT_DIR) {
                std::string pid_str = entry->d_name;
                if (std::all_of(pid_str.begin(), pid_str.end(), ::isdigit)) {
                    size_t pid = std::stoull(pid_str);
                    std::ifstream statm_file("/proc/" + pid_str + "/statm");
                    std::ifstream comm_file("/proc/" + pid_str + "/comm");
                    
                    if (statm_file.is_open() && comm_file.is_open()) {
                        size_t pages;
                        statm_file >> pages;
                        std::string name;
                        std::getline(comm_file, name);
                        
                        Star star;
                        star.pid = pid;
                        star.name = name.empty() ? "unknown" : name;
                        star.memory_bytes = pages * sysconf(_SC_PAGESIZE);
                        stars.push_back(star);
                    }
                }
            }
        }
        closedir(proc_dir);
    }
#endif

    // Fallback pseudo-processes if native access is restricted
    if (stars.empty()) {
        for (int i = 1; i <= 30; ++i) {
            Star star;
            star.pid = i * 100;
            star.name = "proc_" + std::to_string(i);
            star.memory_bytes = (i * 1234567) % 500000000;
            stars.push_back(star);
        }
    }

    return stars;
}

// Get interactive terminal dimensions
void get_terminal_size(int& width, int& height) {
    width = 80;
    height = 24;
#if defined(_WIN32)
    CONSOLE_SCREEN_BUFFER_INFO csbi;
    GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &csbi);
    width = csbi.srWindow.Right - csbi.srWindow.Left + 1;
    height = csbi.srWindow.Bottom - csbi.srWindow.Top + 1;
#else
    struct winsize w;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0) {
        width = w.ws_col;
        height = w.ws_row;
    }
#endif
}

// Map process memory to visual ASCII spectral magnitudes
void compute_magnitude(Star& star, size_t max_mem) {
    double ratio = static_cast<double>(star.memory_bytes) / (max_mem > 0 ? max_mem : 1);
    
    if (ratio > 0.6) {
        star.symbol = '#';         // Supergiant
        star.brightness = 93;      // Bright Yellow
    } else if (ratio > 0.3) {
        star.symbol = '*';         // Giant
        star.brightness = 96;      // Cyan
    } else if (ratio > 0.1) {
        star.symbol = '+';         // Main sequence
        star.brightness = 92;      // Green
    } else if (ratio > 0.02) {
        star.symbol = '.';         // White Dwarf
        star.brightness = 90;      // Dark Gray
    } else {
        star.symbol = '`';         // Micro star
        star.brightness = 37;      // Dim Gray
    }
}

int main() {
    // Enable ANSI escape sequences on Windows terminals
#if defined(_WIN32)
    HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
    DWORD dwMode = 0;
    GetConsoleMode(hOut, &dwMode);
    SetConsoleMode(hOut, dwMode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
#endif

    std::cout << "\x1b[?25l"; // Hide cursor

    float angle = 0.0f;

    while (true) {
        int width, height;
        get_terminal_size(width, height);
        
        // Dynamic viewport safety buffer for dashboard telemetry
        int canvas_h = std::max(10, height - 4);
        int canvas_w = std::max(20, width);

        auto stars = get_process_stars();

        // Sort stars to prioritize rendering largest processes
        std::sort(stars.begin(), stars.end(), [](const Star& a, const Star& b) {
            return a.memory_bytes > b.memory_bytes;
        });

        // Limit density to fit terminal dimensions safely
        size_t max_visible = std::min(stars.size(), static_cast<size_t>(canvas_w * canvas_h * 0.15));
        stars.resize(max_visible);

        size_t max_mem = stars.empty() ? 1 : stars.front().memory_bytes;

        // Position stars deterministically in celestial orbits based on PID & dynamic cosmic drift
        for (size_t i = 0; i < stars.size(); ++i) {
            compute_magnitude(stars[i], max_mem);

            // Seed golden-ratio spiral distribution
            float radius = std::sqrt(static_cast<float>(i + 1) / stars.size()) * 0.85f;
            float theta = i * 2.39996f + angle; // Fibonacci angle + rotation

            stars[i].x = radius * std::cos(theta);
            stars[i].y = radius * std::sin(theta);

            // Convert normalized celestial coordinates [-1, 1] to screen layout (correcting font aspect ratio)
            stars[i].screen_x = std::round((stars[i].x + 1.0f) * 0.5f * (canvas_w - 1));
            stars[i].screen_y = std::round((stars[i].y + 1.0f) * 0.5f * (canvas_h - 1));
        }

        // Initialize frame buffer with spatial grid coordinates
        std::vector<std::string> buffer(canvas_h, std::string(canvas_w, ' '));
        std::vector<std::vector<int>> color_buffer(canvas_h, std::vector<int>(canvas_w, 0));

        // Draw faint celestial coordinate grid lines
        for (int y = 0; y < canvas_h; ++y) {
            for (int x = 0; x < canvas_w; ++x) {
                if (x == canvas_w / 2 && y % 2 == 0) buffer[y][x] = '|';
                if (y == canvas_h / 2 && x % 4 == 0) buffer[y][x] = '-';
                if (x == canvas_w / 2 && y == canvas_h / 2) buffer[y][x] = '+';
            }
        }

        // Render Constellation Connections between top system processes
        for (size_t i = 0; i < std::min(stars.size(), static_cast<size_t>(8)); ++i) {
            size_t next = (i + 1) % std::min(stars.size(), static_cast<size_t>(8));
            int x0 = stars[i].screen_x, y0 = stars[i].screen_y;
            int x1 = stars[next].screen_x, y1 = stars[next].screen_y;

            // Bresenham's line algorithm for constellation links
            int dx = std::abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
            int dy = -std::abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
            int err = dx + dy, e2;

            while (true) {
                if (x0 >= 0 && x0 < canvas_w && y0 >= 0 && y0 < canvas_h) {
                    if (buffer[y0][x0] == ' ') {
                        buffer[y0][x0] = '.';
                        color_buffer[y0][x0] = 30; // Dark shadow grey lines
                    }
                }
                if (x0 == x1 && y0 == y1) break;
                e2 = 2 * err;
                if (e2 >= dy) { err += dy; x0 += sx; }
                if (e2 <= dx) { err += dx; y0 += sy; }
            }
        }

        // Place stars on top of canvas grid
        for (const auto& star : stars) {
            int sx = star.screen_x;
            int sy = star.screen_y;
            if (sx >= 0 && sx < canvas_w && sy >= 0 && sy < canvas_h) {
                buffer[sy][sx] = star.symbol;
                color_buffer[sy][sx] = star.brightness;
            }
        }

        // Assemble output string frame
        std::ostringstream frame;
        frame << "\x1b[H"; // Clear/Reset screen cursor pos

        // Render header dashboard
        frame << "\x1b[1;37m=== REAL-TIME PROCESS CONSTELLATION MAP ===\x1b[0m\n";
        
        for (int y = 0; y < canvas_h; ++y) {
            for (int x = 0; x < canvas_w; ++x) {
                if (color_buffer[y][x] != 0) {
                    frame << "\x1b[" << color_buffer[y][x] << "m" << buffer[y][x] << "\x1b[0m";
                } else {
                    frame << "\x1b[90m" << buffer[y][x] << "\x1b[0m";
                }
            }
            frame << "\n";
        }

        // Display legend for brightest star (Alpha Process)
        if (!stars.empty()) {
            const auto& alpha = stars.front();
            frame << "\x1b[1;33mAlpha Star (Max RAM):\x1b[0m " << alpha.name 
                  << " (PID: " << alpha.pid << ") - " 
                  << (alpha.memory_bytes / (1024 * 1024)) << " MB | "
                  << "Total Stars Tracked: " << stars.size();
        }

        std::cout << frame.str() << std::flush;

        angle += 0.05f; // Rotate celestial sphere drift
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
    }

    std::cout << "\x1b[?25h"; // Restore cursor visibility
    return 0;
}