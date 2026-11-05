package com.yl.aigg.ai_gg666

import android.content.Context
import android.util.Log
import kotlinx.coroutines.runBlocking
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Implementation detail.
 *
 * Implementation detail.
 * Implementation detail.
 * Implementation detail.
 * Implementation detail.
 */
object MemoryEngine {

    private const val TAG = "MemoryEngine"
    private const val MAX_RESULTS = 500

    private var attachedPid: Int? = null
    private var activeRegions: List<MemRegion> = emptyList()
    private var lastSnapshot: Map<Long, ByteArray> = emptyMap()
    private val aobDatabase = mutableMapOf<Long, AobSignature>()
    private var appContext: Context? = null

    init {
        try {
            System.loadLibrary("aigg_scanner")
            Log.i(TAG, "✅ Native library loaded")
        } catch (e: UnsatisfiedLinkError) {
            Log.w(TAG, "Native library not loaded (using Root Scanner instead)")
        }
    }

    fun isNativeAvailable(): Boolean = true

    /**
     * Implementation detail.
     */
    fun setContext(context: Context) {
        appContext = context
    }

    // Implementation detail.

    fun attachProcess(pid: Int): Boolean {
        return try {
            // Implementation detail.
            if (!RootManager.checkRootAccess()) {
                Log.e(TAG, "❌ No root access")
                return false
            }

            // Implementation detail.
            val ctx = appContext
            if (ctx != null) {
                runBlocking {
                    RootScanner.initialize(ctx)
                }
            }

            // Implementation detail.
            activeRegions = getRegions(pid)
            if (activeRegions.isEmpty()) {
                Log.e(TAG, "Process $pid has no accessible regions")
                return false
            }

            attachedPid = pid
            lastSnapshot = emptyMap()
            aobDatabase.clear()

            val totalMB = activeRegions.sumOf { it.endAddr - it.startAddr } / 1024 / 1024
            Log.i(TAG, "✅ Attached to process $pid (${activeRegions.size} regions, ${totalMB}MB)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to attach: ${e.message}", e)
            false
        }
    }

    fun detachProcess() {
        attachedPid = null
        activeRegions = emptyList()
        lastSnapshot = emptyMap()
        aobDatabase.clear()
        RootScanner.shutdown()
    }

    fun getAttachedPid(): Int? = attachedPid

    // Implementation detail.

    data class MemRegion(val startAddr: Long, val endAddr: Long, val priority: Int)

    private fun getRegions(pid: Int): List<MemRegion> {
        val mapsResult = RootManager.executeRootCommand("cat /proc/$pid/maps 2>/dev/null") ?: return emptyList()

        val regions = mutableListOf<MemRegion>()
        for (line in mapsResult.lines()) {
            if (line.isBlank()) continue
            val parts = line.split("\\s+".toRegex())
            if (parts.size < 2) continue
            val addrRange = parts[0].split("-")
            if (addrRange.size != 2) continue

            val startAddr = addrRange[0].toLongOrNull(16) ?: continue
            val endAddr = addrRange[1].toLongOrNull(16) ?: continue
            val permissions = parts[1]
            val name = if (parts.size > 5) parts.subList(5, parts.size).joinToString(" ") else ""
            val regionSize = endAddr - startAddr

            if (regionSize <= 0) continue
            if (!permissions.contains('r') || !permissions.contains('w')) continue
            if (name.contains("/dev/ashmem") || name.contains("[anon:vulkan]")) continue
            if (regionSize > 100 * 1024 * 1024) continue

            var priority = 0
            if (permissions.contains('r')) priority += 10
            if (permissions.contains('w')) priority += 20
            when {
                name.contains("[heap]") -> priority += 70
                name.contains("[anon:") -> priority += 50
                name.isEmpty() -> priority += 40
            }

            regions.add(MemRegion(startAddr, endAddr, priority))
        }

        return regions.sortedByDescending { it.priority }
    }

    fun getMemoryRegions(): List<Map<String, Any>> {
        return activeRegions.map { r ->
            mapOf("startAddress" to r.startAddr, "endAddress" to r.endAddr,
                "size" to (r.endAddr - r.startAddr), "priority" to r.priority)
        }
    }

    // Implementation detail.

    // ==================== Search ====================

    fun searchExact(value: Any, type: String): List<Map<String, Any>> {
        val pid = attachedPid ?: return emptyList()
        if (activeRegions.isEmpty()) return emptyList()

        return try {
            val targetBytes = valueToBytes(value, type) ?: return emptyList()
            val typeSize = getTypeSize(type)

            val targetHex = targetBytes.joinToString(" ") { String.format("%02X", it) }
            val totalMB = activeRegions.sumOf { it.endAddr - it.startAddr } / 1024 / 1024
            Log.d(TAG, "🎯 Searchvalue : $value, Type: $type, Hex: [$targetHex]")
            Log.d(TAG, "📊 segments : ${activeRegions.size}, total size: ${totalMB}MB")

            val startTime = System.currentTimeMillis()

            // Implementation detail.
            val addresses = runBlocking {
                RootScanner.searchExact(pid, activeRegions, typeSize, targetBytes)
            }

            val elapsed = (System.currentTimeMillis() - startTime) / 1000.0
            Log.d(TAG, "⚡ searchExact: ${addresses.size} results in ${String.format("%.2f", elapsed)}s")

            val results = addresses.map { addr -> createResultMap(addr, value, type) }
            enrichWithMachineCode(pid, results)
            saveSnapshot(results, type)
            results
        } catch (e: Exception) {
            Log.e(TAG, "searchExact failed: ${e.message}", e)
            emptyList()
        }
    }

    fun searchByRange(minValue: Long, maxValue: Long, type: String): List<Map<String, Any>> {
        val pid = attachedPid ?: return emptyList()
        if (activeRegions.isEmpty()) return emptyList()

        return try {
            val typeSize = getTypeSize(type)

            val addresses = runBlocking {
                RootScanner.searchRange(pid, activeRegions, typeSize, minValue, maxValue)
            }

            val placeholder: Any = if (type == "float") minValue.toFloat() else minValue
            val results = addresses.map { addr -> createResultMap(addr, placeholder, type) }
            enrichWithMachineCode(pid, results)
            saveSnapshot(results, type)
            results
        } catch (e: Exception) { emptyList() }
    }

    fun filterResults(previousAddresses: List<Long>, value: Any, type: String): List<Map<String, Any>> {
        val pid = attachedPid ?: return emptyList()

        return try {
            val typeSize = getTypeSize(type)
            val targetBytes = valueToBytes(value, type) ?: return emptyList()

            // Implementation detail.
            val results = mutableListOf<MutableMap<String, Any>>()
            for (addr in previousAddresses) {
                val bytes = runBlocking {
                    RootScanner.readMemory(pid, addr, typeSize)
                }
                if (bytes != null && bytes.contentEquals(targetBytes)) {
                    results.add(createResultMap(addr, value, type))
                }
            }

            if (results.isNotEmpty()) {
                enrichWithMachineCode(pid, results)
                saveSnapshot(results, type)
            }
            results
        } catch (e: Exception) { emptyList() }
    }

    fun searchFuzzy(comparison: String, type: String): List<Map<String, Any>> {
        val pid = attachedPid ?: return emptyList()

        if (lastSnapshot.isEmpty()) {
            val initialResults = searchAllValues(type)
            saveSnapshot(initialResults, type)
            return initialResults
        }

        return try {
            val typeSize = getTypeSize(type)
            val addresses = lastSnapshot.keys.toList()
            val oldValues = ByteArray(addresses.size * typeSize)

            // Implementation detail.
            addresses.forEachIndexed { index, addr ->
                val bytes = lastSnapshot[addr] ?: return@forEachIndexed
                System.arraycopy(bytes, 0, oldValues, index * typeSize, typeSize)
            }

            val mode = when (comparison) {
                "changed" -> 0
                "unchanged" -> 1
                "increased" -> 2
                "decreased" -> 3
                else -> 0
            }

            val resultAddrs = runBlocking {
                RootScanner.searchFuzzy(pid, addresses, oldValues, mode, typeSize)
            }

            val results = resultAddrs.map { addr ->
                val bytes = runBlocking {
                    RootScanner.readMemory(pid, addr, typeSize)
                }
                val value = if (bytes != null) bytesToValue(bytes, type) else 0
                createResultMap(addr, value ?: 0, type)
            }
            enrichWithMachineCode(pid, results)
            saveSnapshot(results, type)
            results
        } catch (e: Exception) { emptyList() }
    }

    fun searchAob(pattern: String, mask: String? = null): List<Map<String, Any>> {
        val pid = attachedPid ?: return emptyList()
        if (activeRegions.isEmpty()) return emptyList()

        // Implementation detail.
        val addrLong = parseAddress(pattern)
        if (addrLong != null) {
            return readAddressValues(pid, addrLong)
        }

        return try {
            val (patternBytes, maskBytes) = parseAobPattern(pattern)
            if (patternBytes.isEmpty()) return emptyList()

            // Implementation detail.
            val finalMask = if (mask != null) {
                ByteArray(patternBytes.size) { i ->
                    if (i < mask.length && mask[i] == '?') 0.toByte() else maskBytes[i]
                }
            } else maskBytes

            val addresses = runBlocking {
                RootScanner.searchAob(pid, activeRegions, patternBytes, finalMask)
            }

            addresses.map { addr ->
                val ctx = runBlocking {
                    RootScanner.readMemory(pid, addr - 16, patternBytes.size + 32)
                }
                if (ctx != null) aobDatabase[addr] = AobSignature(addr, pattern, ctx, 16)
                val mc = runBlocking { RootScanner.readMemory(pid, addr, 8) }
                val mcStr = mc?.joinToString(" ") { String.format("%02X", it) } ?: ""
                // Implementation detail.
                val valBytes = runBlocking { RootScanner.readMemory(pid, addr, 4) }
                val actualValue: Any = if (valBytes != null) bytesToValue(valBytes, "dword") ?: 0 else 0
                mapOf("address" to "0x${addr.toString(16).uppercase()}", "addressInt" to addr,
                    "value" to actualValue, "type" to "aob", "isFavorite" to false, "isFrozen" to false,
                    "machineCode" to mcStr)
            }
        } catch (e: Exception) { emptyList() }
    }

    // Implementation detail.
    private fun parseAddress(input: String): Long? {
        val s = input.trim()
        return when {
            s.startsWith("0x", ignoreCase = true) -> s.substring(2).toLongOrNull(16)
            // Implementation detail.
            s.length >= 6 && s.all { it.isDigit() || it in "abcdefABCDEF" } -> s.toLongOrNull(16)
            else -> null
        }
    }

    // Implementation detail.
    private fun readAddressValues(pid: Int, address: Long): List<Map<String, Any>> {
        val results = mutableListOf<Map<String, Any>>()
        // read Machine code
        val mc = runBlocking { RootScanner.readMemory(pid, address, 8) }
        val mcStr = mc?.joinToString(" ") { String.format("%02X", it) } ?: ""
        // Implementation detail.
        val types = listOf("dword" to 4, "float" to 4, "double" to 8, "word" to 2, "byte" to 1)
        for ((type, size) in types) {
            try {
                val bytes = runBlocking { RootScanner.readMemory(pid, address, size) }
                if (bytes != null && bytes.size == size) {
                    val value = bytesToValue(bytes, type)
                    if (value != null) {
                        results.add(mapOf(
                            "address" to "0x${address.toString(16).uppercase()}",
                            "addressInt" to address,
                            "value" to value,
                            "type" to type,
                            "isFavorite" to false,
                            "isFrozen" to false,
                            "machineCode" to mcStr
                        ))
                    }
                }
            } catch (_: Exception) {}
        }
        return results
    }

    fun relocateAobSignatures(): List<Map<String, Any>> {
        val pid = attachedPid ?: return emptyList()
        if (aobDatabase.isEmpty() || activeRegions.isEmpty()) return emptyList()

        return try {
            val results = mutableListOf<Map<String, Any>>()

            for ((address, sig) in aobDatabase) {
                val mask = ByteArray(sig.contextBytes.size) { 1.toByte() }
                val found = runBlocking {
                    RootScanner.searchAob(pid, activeRegions, sig.contextBytes, mask)
                }
                if (found.isNotEmpty()) {
                    val newAddr = found[0] + sig.contextOffset
                    val mc = runBlocking { RootScanner.readMemory(pid, newAddr, 8) }
                    val mcStr = mc?.joinToString(" ") { String.format("%02X", it) } ?: ""
                    val valBytes = runBlocking { RootScanner.readMemory(pid, newAddr, 4) }
                    val actualValue: Any = if (valBytes != null) bytesToValue(valBytes, "dword") ?: 0 else 0
                    results.add(mapOf("address" to "0x${newAddr.toString(16).uppercase()}", "addressInt" to newAddr,
                        "value" to actualValue, "type" to "aob", "isFavorite" to false, "isFrozen" to false,
                        "relocated" to true, "oldAddress" to "0x${address.toString(16).uppercase()}",
                        "machineCode" to mcStr))
                }
            }
            results
        } catch (e: Exception) { emptyList() }
    }

    // Implementation detail.

    fun readMemory(address: Long, type: String): Any? {
        val pid = attachedPid ?: return null
        return try {
            val typeSize = getTypeSize(type)
            val bytes = runBlocking {
                RootScanner.readMemory(pid, address, typeSize)
            } ?: return null
            bytesToValue(bytes, type)
        } catch (e: Exception) {
            Log.e(TAG, "readMemory failed: ${e.message}")
            null
        }
    }

    // Implementation detail.
    fun readMemory(address: Int, type: String): Any? = readMemory(address.toLong(), type)

    fun writeMemory(address: Long, value: Any, type: String): Boolean {
        val pid = attachedPid ?: return false
        return try {
            val bytes = valueToBytes(value, type) ?: return false
            runBlocking {
                RootScanner.writeMemory(pid, address, bytes)
            }
        } catch (e: Exception) {
            Log.e(TAG, "writeMemory failed: ${e.message}")
            false
        }
    }

    // Implementation detail.
    fun writeMemory(address: Int, value: Any, type: String): Boolean = writeMemory(address.toLong(), value, type)

    fun writeBatch(requests: List<Map<String, Any>>): Boolean {
        var ok = true
        for (req in requests) {
            val addr = (req["address"] as? Number)?.toLong() ?: continue
            val v = req["value"] ?: continue
            val t = req["type"] as? String ?: "dword"
            if (!writeMemory(addr, v, t)) ok = false
        }
        return ok
    }

    fun analyzeMemoryRegion(address: Long, range: Int): Map<String, Any> {
        val pid = attachedPid ?: return emptyMap()
        return try {
            val data = runBlocking {
                RootScanner.readMemory(pid, (address - range).coerceAtLeast(0), range * 2)
            } ?: return emptyMap()
            mapOf("address" to address, "range" to range, "data" to data.joinToString("") { "%02x".format(it) }, "size" to data.size)
        } catch (e: Exception) { emptyMap() }
    }

    // Implementation detail.
    fun analyzeMemoryRegion(address: Int, range: Int): Map<String, Any> = analyzeMemoryRegion(address.toLong(), range)

    private fun searchAllValues(type: String): List<Map<String, Any>> {
        val pid = attachedPid ?: return emptyList()
        if (activeRegions.isEmpty()) return emptyList()

        return try {
            val typeSize = getTypeSize(type)

            val addresses = runBlocking {
                RootScanner.searchRange(pid, activeRegions, typeSize, Long.MIN_VALUE, Long.MAX_VALUE)
            }

            val placeholder: Any = if (type == "float") 0.0f else if (type == "double") 0.0 else 0
            addresses.map { addr -> createResultMap(addr, placeholder, type) }
        } catch (e: Exception) { emptyList() }
    }

    // Implementation detail.

    private fun saveSnapshot(results: List<Map<String, Any>>, type: String) {
        val pid = attachedPid ?: return
        val typeSize = getTypeSize(type)
        val addresses = results.mapNotNull { (it["addressInt"] as? Number)?.toLong() }
        if (addresses.isEmpty()) return

        val snapshot = mutableMapOf<Long, ByteArray>()
        for (addr in addresses) {
            val b = runBlocking {
                RootScanner.readMemory(pid, addr, typeSize)
            }
            if (b != null) snapshot[addr] = b
        }
        lastSnapshot = snapshot
    }

    // Implementation detail.

    // Implementation detail.
    private fun parseAobPattern(input: String): Pair<ByteArray, ByteArray> {
        var raw = input.trim()
        // Implementation detail.
        if (raw.startsWith("0x", ignoreCase = true)) raw = raw.substring(2)

        // Implementation detail.
        val tokens: List<String> = if (raw.contains(" ")) {
            raw.split("\\s+".toRegex()).filter { it.isNotEmpty() }
        } else {
            // Implementation detail.
            val result = mutableListOf<String>()
            var j = 0
            while (j < raw.length) {
                if (j + 1 < raw.length && raw[j] == '?' && raw[j + 1] == '?') {
                    result.add("??")
                    j += 2
                } else if (j + 1 < raw.length) {
                    result.add(raw.substring(j, j + 2))
                    j += 2
                } else {
                    j++ // Skip the final odd digit
                }
            }
            result
        }

        val patternBytes = mutableListOf<Byte>()
        val maskBytes = mutableListOf<Byte>()
        for (token in tokens) {
            if (token == "??") {
                patternBytes.add(0)
                maskBytes.add(0) // Wildcard
            } else {
                patternBytes.add(token.toInt(16).toByte())
                maskBytes.add(1) // Exact match
            }
        }
        return Pair(patternBytes.toByteArray(), maskBytes.toByteArray())
    }

    fun getTypeSize(type: String): Int = when (type) {
        "byte" -> 1; "word" -> 2; "dword" -> 4; "qword" -> 8; "float" -> 4; "double" -> 8; else -> 4
    }

    private fun valueToBytes(value: Any, type: String): ByteArray? {
        return try {
            val num = value as? Number ?: return null
            when (type) {
                "byte" -> byteArrayOf(num.toInt().toByte())
                "word" -> ByteBuffer.allocate(2).order(ByteOrder.LITTLE_ENDIAN).putShort(num.toShort()).array()
                "dword" -> ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(num.toInt()).array()
                "qword" -> ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN).putLong(num.toLong()).array()
                "float" -> ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putFloat(num.toFloat()).array()
                "double" -> ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN).putDouble(num.toDouble()).array()
                else -> null
            }
        } catch (e: Exception) { null }
    }

    private fun bytesToValue(bytes: ByteArray, type: String): Any? {
        return try {
            val buf = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
            when (type) {
                "byte" -> bytes[0].toInt() and 0xFF
                "word" -> buf.short.toInt() and 0xFFFF
                "dword" -> buf.int; "qword" -> buf.long
                "float" -> buf.float; "double" -> buf.double
                else -> null
            }
        } catch (e: Exception) { null }
    }

    private fun valuesEqual(a: Any, b: Any, type: String): Boolean = try {
        when (type) {
            "float" -> Math.abs((a as Number).toFloat() - (b as Number).toFloat()) < 0.001
            "double" -> Math.abs((a as Number).toDouble() - (b as Number).toDouble()) < 0.0001
            else -> (a as? Number)?.toLong() == (b as? Number)?.toLong()
        }
    } catch (e: Exception) { false }

    private fun compareValues(a: Any, b: Any, type: String): Int = try {
        when (type) {
            "float" -> (a as Number).toFloat().compareTo((b as Number).toFloat())
            "double" -> (a as Number).toDouble().compareTo((b as Number).toDouble())
            else -> (a as Number).toLong().compareTo((b as Number).toLong())
        }
    } catch (e: Exception) { 0 }

    private fun createResultMap(address: Long, value: Any, type: String): MutableMap<String, Any> = mutableMapOf(
        "address" to "0x${address.toString(16).uppercase()}", "addressInt" to address,
        "value" to value, "type" to type, "isFavorite" to false, "isFrozen" to false
    )

    // Implementation detail.
    private fun enrichWithMachineCode(pid: Int, results: List<MutableMap<String, Any>>) {
        for (r in results) {
            val addr = r["addressInt"] as? Long ?: continue
            try {
                val bytes = runBlocking { RootScanner.readMemory(pid, addr, 8) }
                if (bytes != null) {
                    r["machineCode"] = bytes.joinToString(" ") { String.format("%02X", it) }
                }
            } catch (_: Exception) {}
        }
    }

    data class AobSignature(val address: Long, val pattern: String, val contextBytes: ByteArray, val contextOffset: Int)
}
