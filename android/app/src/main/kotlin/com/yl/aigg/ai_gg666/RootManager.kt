package com.yl.aigg.ai_gg666

import java.io.BufferedReader
import java.io.DataOutputStream
import java.io.InputStreamReader

/**
 * Implementation detail.
 * Implementation detail.
 */
object RootManager {

    private var hasRootAccess: Boolean? = null
    private var suProcess: Process? = null
    private var suOutputStream: DataOutputStream? = null
    private var suReader: BufferedReader? = null

    /**
     * Implementation detail.
     * Implementation detail.
     */
    fun checkRootAccess(): Boolean {
        if (hasRootAccess == true) return true
        return initSuShell()
    }

    /**
     * Implementation detail.
     */
    private fun initSuShell(): Boolean {
        if (hasRootAccess == true) return true

        try {
            suProcess = Runtime.getRuntime().exec("su")
            suOutputStream = DataOutputStream(suProcess!!.outputStream)
            suReader = BufferedReader(InputStreamReader(suProcess!!.inputStream))

            // Test root permission
            val result = executeCommandInternal("id")
            hasRootAccess = result?.contains("uid=0") == true

            if (!hasRootAccess!!) {
                closeSuShell()
            }

            return hasRootAccess!!
        } catch (e: Exception) {
            hasRootAccess = false
            closeSuShell()
            return false
        }
    }

    /**
     * Implementation detail.
     */
    fun requestRootAccess(): Boolean {
        return checkRootAccess()
    }

    /**
     * Implementation detail.
     */
    fun executeRootCommand(command: String): String? {
        if (hasRootAccess != true) {
            if (!initSuShell()) return null
        }
        return executeCommandInternal(command)
    }

    /**
     * Implementation detail.
     */
    private fun executeCommandInternal(command: String): String? {
        try {
            val os = suOutputStream ?: return null
            val reader = suReader ?: return null

            // Implementation detail.
            val marker = "CMD_DONE_${System.nanoTime()}"

            os.writeBytes("$command\n")
            os.writeBytes("echo $marker\n")
            os.flush()

            val output = StringBuilder()
            while (true) {
                val line = reader.readLine() ?: break
                if (line.contains(marker)) break
                output.appendLine(line)
            }

            return output.toString().trim()
        } catch (e: Exception) {
            // Implementation detail.
            closeSuShell()
            return null
        }
    }

    /**
     * disable  su shell
     */
    private fun closeSuShell() {
        try {
            suOutputStream?.writeBytes("exit\n")
            suOutputStream?.flush()
            suOutputStream?.close()
            suReader?.close()
            suProcess?.destroy()
        } catch (_: Exception) {}
        suProcess = null
        suOutputStream = null
        suReader = null
    }

    /**
     * Implementation detail.
     */
    fun getRootStatus(): String {
        return when (hasRootAccess) {
            true -> "Root access granted"
            false -> "Root access not granted"
            null -> "Not checked"
        }
    }

    /**
     * Implementation detail.
     */
    fun resetRootStatus() {
        closeSuShell()
        hasRootAccess = null
    }

    /**
     * Implementation detail.
     * Implementation detail.
     */
    fun batchReadMemoryViaRoot(pid: Int, requests: List<Pair<Long, Int>>): List<ByteArray?> {
        if (requests.isEmpty()) return emptyList()

        try {
            // Implementation detail.
            val commands = requests.mapIndexed { index, (address, size) ->
                "dd if=/proc/$pid/mem bs=1 skip=$address count=$size 2>/dev/null | xxd -p > /data/local/tmp/mem_$index.hex"
            }

            // Implementation detail.
            val batchCmd = commands.joinToString(" && ")
            executeRootCommand(batchCmd)

            // Implementation detail.
            return requests.indices.map { index ->
                val hexResult = executeRootCommand("cat /data/local/tmp/mem_$index.hex 2>/dev/null")
                if (hexResult.isNullOrEmpty()) {
                    null
                } else {
                    val hexClean = hexResult.replace("\\s".toRegex(), "")
                    val bytes = ByteArray(hexClean.length / 2)
                    for (i in bytes.indices) {
                        val hex = hexClean.substring(i * 2, i * 2 + 2)
                        bytes[i] = hex.toInt(16).toByte()
                    }
                    bytes
                }
            }.also {
                // Implementation detail.
                executeRootCommand("rm -f /data/local/tmp/mem_*.hex 2>/dev/null")
            }
        } catch (e: Exception) {
            android.util.Log.e("RootManager", "batchReadMemoryViaRoot failed: ${e.message}")
            return List(requests.size) { null }
        }
    }

    /**
     * Implementation detail.
     * Implementation detail.
     */
    fun readMemoryViaRoot(pid: Int, address: Long, size: Int): ByteArray? {
        try {
            // Implementation detail.
            val cmd = "dd if=/proc/$pid/mem bs=1 skip=$address count=$size 2>/dev/null | xxd -p"
            val hexResult = executeRootCommand(cmd) ?: return null

            if (hexResult.isEmpty()) return null

            // Implementation detail.
            val hexClean = hexResult.replace("\\s".toRegex(), "")

            if (hexClean.isEmpty()) return null

            // Implementation detail.
            val bytes = ByteArray(hexClean.length / 2)
            for (i in bytes.indices) {
                val hex = hexClean.substring(i * 2, i * 2 + 2)
                bytes[i] = hex.toInt(16).toByte()
            }

            return bytes
        } catch (e: Exception) {
            android.util.Log.e("RootManager", "readMemoryViaRoot failed: ${e.message}")
            return null
        }
    }

    /**
     * Implementation detail.
     */
    fun writeMemoryViaRoot(pid: Int, address: Long, data: ByteArray): Boolean {
        try {
            // Implementation detail.
            val hexString = data.joinToString("") { "%02x".format(it) }

            // Implementation detail.
            val cmd = "echo '$hexString' | xxd -r -p | dd of=/proc/$pid/mem bs=1 seek=$address count=${data.size} 2>/dev/null"
            val result = executeRootCommand(cmd)

            return result != null
        } catch (e: Exception) {
            android.util.Log.e("RootManager", "writeMemoryViaRoot failed: ${e.message}")
            return false
        }
    }
}
