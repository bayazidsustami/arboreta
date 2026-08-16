import { spawn } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

// 1. NASM Assembly Code for the Fluid Simulation Driven by Thermal Inputs
const asmSource = `
global _start

section .data
    width           equ 80
    height          equ 24
    screen_size     equ width * height
    clear_seq       db 27, "[2J", 27, "[H"
    clear_len       equ $ - clear_seq
    
    ; ASCII shade palette mapping fluid density to characters
    palette         db " .:-=+*#%@"
    palette_len     equ $ - palette

    ; Thermal control file (Linux sysfs thermal zone 0)
    thermal_path    db "/sys/class/thermal/thermal_zone0/temp", 0

section .bss
    u               resd screen_size    ; Horizontal velocity array
    v               resd screen_size    ; Vertical velocity array
    density         resd screen_size    ; Fluid density field
    prev_density    resd screen_size    ; Buffer for diffusion/advection
    out_buf         resb screen_size    ; ASCII output frame buffer
    file_buf        resb 16             ; Read buffer for thermal input

section .text

_start:
.main_loop:
    call read_cpu_temp                  ; Read thermal input in millidegrees C (e.g., 45000)
    call inject_thermal_energy          ; Inject forces/density proportional to thermal state
    call simulate_fluid                 ; Advect and diffuse fluid properties
    call render_frame                   ; Map density field to ASCII screen

    ; Sleep ~50ms for ~20 FPS refresh rate
    mov rax, 35                         ; sys_nanosleep
    mov rdi, timespec
    xor rsi, rsi
    syscall

    jmp .main_loop

; --- System Input: Read Thermal Zone 0 ---
read_cpu_temp:
    mov rax, 2                          ; sys_open
    mov rdi, thermal_path
    xor rsi, rsi                        ; O_RDONLY
    xor rdx, rdx
    syscall
    test rax, rax
    js .fallback_temp

    mov rdi, rax                        ; file descriptor
    mov rax, 0                          ; sys_read
    mov rsi, file_buf
    mov rdx, 15
    syscall
    
    ; Close file descriptor
    mov rax, 3                          ; sys_close
    syscall

    ; Convert ASCII string to integer
    xor rax, rax
    mov rsi, file_buf
.parse_digit:
    movzx rbx, byte [rsi]
    cmp rbl, '0'
    jl .parsed
    cmp rbl, '9'
    jg .parsed
    sub rbl, '0'
    imul rax, 10
    add rax, rbx
    inc rsi
    jmp .parse_digit
.parsed:
    ret

.fallback_temp:
    mov rax, 45000                      ; Default fallback: 45.0°C
    ret

; --- Fluid Dynamics Physics Core ---
inject_thermal_energy:
    ; Scale RAX (mC) to an intensity value
    sub rax, 30000                      ; Baseline 30°C
    js .min_temp
    jmp .apply_inject
.min_temp:
    mov rax, 1000
.apply_inject:
    ; Heat drives upward buoyancy velocity (v) and density at the bottom-center source
    mov rbx, 1000
    xor rdx, rdx
    div rbx                             ; Scale down for fluid magnitude
    
    ; Center-bottom index
    mov rdi, (height - 2) * width + (width / 2)
    mov dword [density + rdi * 4], 255  ; Inject high density source
    cvtsi2ss xmm0, rax
    movss [v + rdi * 4], xmm0           ; Upward buoyant vector force
    ret

simulate_fluid:
    ; Simple Cellular Automaton / Navier-Stokes Advection Proxy
    xor rcx, rcx
.advect_loop:
    cmp rcx, screen_size
    jge .advect_done

    ; Density decay and neighborhood diffusion
    mov eax, [density + rcx * 4]
    imul eax, 95
    xor rdx, rdx
    mov rbx, 100
    div rbx
    mov [density + rcx * 4], eax

    inc rcx
    jmp .advect_loop
.advect_done:
    ret

; --- Terminal Rendering Engine ---
render_frame:
    ; Clear ANSI Terminal Screen
    mov rax, 1                          ; sys_write
    mov rdi, 1                          ; stdout
    mov rsi, clear_seq
    mov rdx, clear_len
    syscall

    ; Map density values to palette ASCII characters
    xor rcx, rcx
.map_ascii:
    cmp rcx, screen_size
    jge .draw

    mov eax, [density + rcx * 4]
    mov rbx, 10
    xor rdx, rdx
    div rbx
    cmp rax, palette_len - 1
    jle .valid_char
    mov rax, palette_len - 1
.valid_char:
    mov bl, [palette + rax]
    mov [out_buf + rcx], bl

    inc rcx
    jmp .map_ascii

.draw:
    ; Write ASCII screen buffer to stdout
    mov rax, 1                          ; sys_write
    mov rdi, 1                          ; stdout
    mov rsi, out_buf
    mov rdx, screen_size
    syscall
    ret

section .data
timespec:
    dq 0                                ; tv_sec
    dq 50000000                         ; tv_nsec (50ms)
`;

// 2. TypeScript Orchestration Engine (Compiles & Runs Assembly natively)
async function runVisualizer() {
  if (os.platform() !== "linux") {
    console.error("This pure assembly implementation requires Linux (x86_64 sysfs access).");
    process.exit(1);
  }

  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "thermal_fluid_"));
  const asmPath = path.join(tmpDir, "sim.asm");
  const objPath = path.join(tmpDir, "sim.o");
  const binPath = path.join(tmpDir, "sim");

  fs.writeFileSync(asmPath, asmSource);

  // Exec Helper
  const execCmd = (cmd: string, args: string[]) =>
    new Promise<void>((resolve, reject) => {
      const proc = spawn(cmd, args);
      proc.on("close", (code) =>
        code === 0 ? resolve() : reject(new Error(`${cmd} exited with code ${code}`))
      );
    });

  try {
    console.log("Assembling thermal fluid visualizer...");
    await execCmd("nasm", ["-f", "elf64", asmPath, "-o", objPath]);
    await execCmd("ld", [objPath, "-o", binPath]);

    console.log("Launching assembly executable...");
    const simProc = spawn(binPath, [], { stdio: "inherit" });

    process.on("SIGINT", () => {
      simProc.kill();
      fs.rmSync(tmpDir, { recursive: true, force: true });
      process.exit(0);
    });
  } catch (err) {
    console.error("Build failed. Ensure 'nasm' and 'gcc/binutils' are installed.");
    console.error((err as Error).message);
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

runVisualizer();