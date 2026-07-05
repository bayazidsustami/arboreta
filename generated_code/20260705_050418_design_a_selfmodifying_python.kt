import java.awt.Color
import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.Base64
import kotlin.system.exitProcess

// Helper to write the evolving Python script
fun writePythonScript(content: String) {
    File("evolve.py").writeText(content)
}

// Generate initial Python source that reads webcam, extracts dominant color,
// and rewrites itself with variable names reflecting that color.
fun generateInitialPython(): String {
    val template = """
        import cv2, numpy as np, sys, os, re, base64
        # Capture from default webcam
        cap = cv2.VideoCapture(0)
        if not cap.isOpened():
            sys.exit(1)
        # Main loop
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            # Resize for speed
            small = cv2.resize(frame, (80, 60))
            # Dominant color via k‑means (k=1)
            data = small.reshape((-1,3)).astype(np.float32)
            _, labels, centers = cv2.kmeans(data, 1, None,
                                           (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 10, 1.0),
                                           1, cv2.KMEANS_RANDOM_CENTERS)
            dominant = centers[0].astype(int)
            # Encode dominant color into variable name (hex)
            hexcol = '%02x%02x%02x' % tuple(dominant)
            var_name = 'c_' + hexcol
            # Build ASCII art based on luminance
            gray = cv2.cvtColor(small, cv2.COLOR_BGR2GRAY)
            chars = "@%#*+=-:. "[::-1]
            ascii_img = ""
            for row in gray:
                for pixel in row:
                    ascii_img += chars[pixel * len(chars) // 256]
                ascii_img += '\\n'
            # Display
            os.system('cls' if os.name == 'nt' else 'clear')
            print(f'\\n{ascii_img}')
            # Self‑modify: replace the placeholder variable name
            with open(__file__, 'r') as f:
                src = f.read()
            new_src = re.sub(r'c_[0-9a-f]{6}', var_name, src)
            # Write back
            with open(__file__+'.tmp', 'w') as f:
                f.write(new_src)
            os.replace(__file__+'.tmp', __file__)
            # Small pause
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
        cap.release()
    """.trimIndent()
    return template
}

// Main entry: write script and launch it.
fun main() {
    val pythonCode = generateInitialPython()
    writePythonScript(pythonCode)

    // Ensure python is available
    val process = ProcessBuilder("python", "evolve.py")
        .inheritIO()
        .start()
    process.waitFor()
    exitProcess(process.exitValue())
}