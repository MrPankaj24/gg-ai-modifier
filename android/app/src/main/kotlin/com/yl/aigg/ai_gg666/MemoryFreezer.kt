package com.yl.aigg.ai_gg666

/**
 * Implementation detail.
 * Implementation detail.
 */
object MemoryFreezer {

    private val frozenAddresses = mutableMapOf<Int, Map<String, Any>>()
    private var freezeThread: Thread? = null
    private var isRunning = false

    /**
     * Freezememoryaddress
     */
    fun freeze(address: Int, value: Any, type: String): Boolean {
        frozenAddresses[address] = mapOf(
            "address" to address,
            "value" to value,
            "type" to type
        )
        startFreezingIfNeeded()
        return true
    }

    /**
     * Implementation detail.
     */
    fun unfreeze(address: Int): Boolean {
        frozenAddresses.remove(address)
        if (frozenAddresses.isEmpty()) {
            stopFreezing()
        }
        return true
    }

    /**
     * Implementation detail.
     */
    fun getFrozenAddresses(): List<Map<String, Any>> {
        return frozenAddresses.values.toList()
    }

    /**
     * Implementation detail.
     */
    private fun startFreezingIfNeeded() {
        if (isRunning) return

        isRunning = true
        freezeThread = Thread {
            while (isRunning && frozenAddresses.isNotEmpty()) {
                for ((address, info) in frozenAddresses) {
                    val value = info["value"] ?: continue
                    val type = info["type"] as? String ?: "dword"
                    try {
                        MemoryEngine.writeMemory(address, value, type)
                    } catch (e: Exception) {
                        // Implementation detail.
                    }
                }
                try {
                    Thread.sleep(100) // Write every 100 ms
                } catch (e: InterruptedException) {
                    break
                }
            }
            isRunning = false
        }
        freezeThread?.isDaemon = true
        freezeThread?.start()
    }

    /**
     * Implementation detail.
     */
    private fun stopFreezing() {
        isRunning = false
        freezeThread?.interrupt()
        freezeThread = null
    }
}
