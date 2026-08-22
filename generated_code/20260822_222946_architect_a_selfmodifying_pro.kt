```kotlin
import org.lwjgl.glfw.GLFW.*
import org.lwjgl.opengl.GL
import org.lwjgl.opengl.GL20.*
import org.lwjgl.opengl.GL30.*
import org.lwjgl.system.MemoryUtil.NULL
import java.nio.ByteBuffer

// Self-Modifying GLSL Cellular Automaton Engine
// Reads pixel state buffer memory to recompile its own shader program at runtime
fun main() {
    check(glfwInit()) { "Failed to initialize GLFW" }
    
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3)
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE)
    
    val width = 800
    val height = 600
    val window = glfwCreateWindow(width, height, "Self-Modifying CA Shader", NULL, NULL)
    if (window == NULL) error("Failed to create GLFW window")
    
    glfwMakeContextCurrent(window)
    glfwSwapInterval(1)
    GL.createCapabilities()

    // Full-screen Quad Setup
    val vao = glGenVertexArrays()
    glBindVertexArray(vao)

    val vertexShaderSource = """
        #version 330 core
        layout (location = 0) in vec2 aPos;
        out vec2 uv;
        void main() {
            uv = aPos * 0.5 + 0.5;
            gl_Position = vec4(aPos, 0.0, 1.0);
        }
    """.trimIndent()

    fun compileShader(type: Int, source: String): Int {
        val shader = glCreateShader(type)
        glShaderSource(shader, source)
        glCompileShader(shader)
        if (glGetShaderi(shader, GL_COMPILE_STATUS) == GL_FALSE) {
            val log = glGetShaderInfoLog(shader)
            glDeleteShader(shader)
            throw RuntimeException("Shader compilation failed: $log")
        }
        return shader
    }

    fun createProgram(vsSource: String, fsSource: String): Int {
        val vs = compileShader(GL_VERTEX_SHADER, vsSource)
        val fs = compileShader(GL_FRAGMENT_SHADER, fsSource)
        val program = glCreateProgram()
        glAttachShader(program, vs)
        glAttachShader(program, fs)
        glLinkProgram(program)
        glDeleteShader(vs)
        glDeleteShader(fs)
        return program
    }

    // Ping-Pong Framebuffer Architecture
    val fbos = IntArray(2)
    val textures = IntArray(2)
    glGenFramebuffers(2, fbos)
    glGenTextures(2, textures)

    for (i in 0..1) {
        glBindFramebuffer(GL_FRAMEBUFFER, fbos[i])
        glBindTexture(GL_TEXTURE_2D, textures[i])
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, null as ByteBuffer?)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, textures[i], 0)
    }

    // Seed Framebuffer Memory with initial pseudo-code pixel bytes
    val initBuffer = ByteBuffer.allocateDirect(width * height * 4)
    val seedCode = "float rule(int n, float c) { return (n==3 || (n==2 && c>0.5)) ? 1.0 : 0.0; }"
    for (i in 0 until width * height) {
        val charVal = if (i < seedCode.length) seedCode[i].code else (Math.random() * 255).toInt()
        initBuffer.put(charVal.toByte()) // R: Code channel
        initBuffer.put((Math.random() * 255).toInt().toByte()) // G: State
        initBuffer.put((Math.random() * 255).toInt().toByte()) // B: Color mutation
        initBuffer.put(255.toByte())
    }
    initBuffer.flip()
    glBindTexture(GL_TEXTURE_2D, textures[0])
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, initBuffer)

    var currentProgram = 0
    var activeIdx = 0
    var frameCount = 0

    // Core execution & mutation loop
    while (!glfwWindowShouldClose(window)) {
        // Step 1: Read code fragments out of pixel memory buffer
        val pixelBuffer = ByteBuffer.allocateDirect(width * height * 4)
        glBindTexture(GL_TEXTURE_2D, textures[activeIdx])
        glGetTexImage(GL_TEXTURE_2D, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixelBuffer)

        // Decode ASCII fragment from Red channel memory
        val codeChars = CharArray(128)
        for (i in 0 until 128) {
            val byteVal = pixelBuffer.get(i * 4).toInt() and 0xFF
            codeChars[i] = if (byteVal in 32..126) byteVal.toChar() else ' '
        }
        val dynamicRuleSnippet = String(codeChars).trim()

        // Fallback default rule if extracted pixel string is invalid syntax
        val fragmentShaderSource = """
            #version 330 core
            out vec4 FragColor;
            in vec2 uv;
            uniform sampler2D uTex;
            uniform vec2 uRes;
            uniform float uTime;

            $dynamicRuleSnippet

            void main() {
                vec2 st = uv;
                vec2 texel = 1.0 / uRes;
                float neighbors = 0.0;

                for (int x = -1; x <= 1; x++) {
                    for (int y = -1; y <= 1; y++) {
                        if (x == 0 && y == 0) continue;
                        neighbors += texture(uTex, st + vec2(x, y) * texel).g > 0.5 ? 1.0 : 0.0;
                    }
                }

                vec4 self = texture(uTex, st);
                float nextState = rule(int(neighbors), self.g);

                // Self-modifying code channel mutation
                float mutatedCode = mod(self.r * 255.0 + (sin(uTime + st.x * 10.0) * 2.0), 256.0) / 255.0;
                vec3 color = vec3(mutatedCode, nextState, abs(sin(uTime + self.b)));

                FragColor = vec4(color, 1.0);
            }
        """.trimIndent()

        // Recompile shader from pixel buffer memory
        try {
            val newProg = createProgram(vertexShaderSource, fragmentShaderSource)
            if (currentProgram != 0) glDeleteProgram(currentProgram)
            currentProgram = newProg
        } catch (_: Exception) {
            // Keep previous valid compilation state on syntax mutation faults
        }

        // Step 2: Render CA state step to opposite framebuffer
        val nextIdx = 1 - activeIdx
        glBindFramebuffer(GL_FRAMEBUFFER, fbos[nextIdx])
        glUseProgram(currentProgram)

        val resLoc = glGetUniformLocation(currentProgram, "uRes")
        val timeLoc = glGetUniformLocation(currentProgram, "uTime")
        glUniform2f(resLoc, width.toFloat(), height.toFloat())
        glUniform1f(timeLoc, frameCount * 0.016f)

        glBindTexture(GL_TEXTURE_2D, textures[activeIdx])
        glBindVertexArray(vao)
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4)

        // Step 3: Present buffer state to window screen
        glBindFramebuffer(GL_FRAMEBUFFER, 0)
        glViewport(0, 0, width, height)
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4)

        activeIdx = nextIdx
        frameCount++

        glfwSwapBuffers(window)
        glfwPollEvents()
    }

    glDeleteVertexArrays(vao)
    glDeleteFramebuffers(2, fbos)
    glDeleteTextures(2, textures)
    if (currentProgram != 0) glDeleteProgram(currentProgram)
    glfwDestroyWindow(window)
    glfwTerminate()
}
```