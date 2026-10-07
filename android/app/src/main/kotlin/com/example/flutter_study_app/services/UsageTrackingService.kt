package com.example.flutter_study_app.services

import android.content.Context
import com.example.flutter_study_app.database.UsageDatabase
import com.example.flutter_study_app.database.UsageSessionData
import com.example.flutter_study_app.database.UsageStatsData
import kotlinx.coroutines.*
import org.json.JSONObject
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import java.util.*
import java.util.concurrent.ConcurrentHashMap

/**
 * Service for tracking app usage sessions and generating aggregated statistics.
 * 
 * This service handles:
 * - Recording app usage sessions
 * - Aggregating usage statistics
 * - Managing daily resets and timezone changes
 * - Battery-efficient batched processing
 * - Offline operation support
 */
class UsageTrackingService(
    private val context: Context,
    private val database: UsageDatabase
) {
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val activeSessions = ConcurrentHashMap<String, SessionTracker>()
    
    // Configuration
    private val aggregationIntervalMs = 60000L // 1 minute
    private val syncBatchSize = 50
    private val maxSessionDurationMinutes = 60 // Max single session duration
    
    // Current state
    private var lastAggregationTime = System.currentTimeMillis()
    private var currentDate = LocalDate.now()
    private var isRunning = false
    
    companion object {
        private const val TAG = "UsageTrackingService"
    }
    
    /**
     * Start the usage tracking service
     */
    fun startTracking() {
        if (isRunning) return
        
        isRunning = true
        android.util.Log.d(TAG, "Starting usage tracking service")
        
        // Start aggregation job
        serviceScope.launch {
            aggregationLoop()
        }
        
        // Start maintenance job
        serviceScope.launch {
            maintenanceLoop()
        }
    }
    
    /**
     * Stop the usage tracking service
     */
    fun stopTracking() {
        if (!isRunning) return
        
        isRunning = false
        android.util.Log.d(TAG, "Stopping usage tracking service")
        
        // End all active sessions
        endAllActiveSessions()
        
        // Final aggregation
        runBlocking {
            performAggregation()
        }
        
        serviceScope.cancel()
    }
    
    /**
     * Start tracking usage for an app
     */
    fun startAppSession(packageName: String, appName: String) {
        if (!isRunning) return
        
        val currentTime = LocalDateTime.now()
        
        // End existing session for this app if any
        endAppSession(packageName)
        
        // Start new session
        val sessionTracker = SessionTracker(
            packageName = packageName,
            appName = appName,
            startTime = currentTime,
            deviceId = getDeviceId()
        )
        
        activeSessions[packageName] = sessionTracker
        
        android.util.Log.d(TAG, "Started session for $packageName at $currentTime")
    }
    
    /**
     * End tracking usage for an app
     */
    fun endAppSession(packageName: String) {
        val sessionTracker = activeSessions.remove(packageName) ?: return
        val endTime = LocalDateTime.now()
        
        // Validate session duration
        val durationMinutes = ChronoUnit.MINUTES.between(sessionTracker.startTime, endTime)
        
        if (durationMinutes > maxSessionDurationMinutes) {
            // Split into multiple sessions to handle cases where monitoring was interrupted
            splitLongSession(sessionTracker, endTime)
        } else {
            // Record normal session
            recordSession(sessionTracker, endTime)
        }
        
        android.util.Log.d(TAG, "Ended session for $packageName, duration: ${durationMinutes}m")
    }
    
    /**
     * Get current usage stats for an app
     */
    fun getUsageStats(packageName: String): UsageStatsData? {
        return database.getStatsForPackage(packageName)
    }
    
    /**
     * Get today's usage for an app in minutes
     */
    fun getTodayUsageMinutes(packageName: String): Int {
        val stats = database.getStatsForPackage(packageName) ?: return 0
        val today = LocalDate.now().toString()
        
        return if (stats.date == today) {
            (stats.todaySeconds / 60)
        } else {
            0 // Stats are from previous day
        }
    }
    
    /**
     * Check if app has exceeded daily limit
     */
    fun hasExceededDailyLimit(packageName: String, dailyLimitMinutes: Int?): Boolean {
        if (dailyLimitMinutes == null || dailyLimitMinutes <= 0) return false
        
        val todayMinutes = getTodayUsageMinutes(packageName)
        return todayMinutes >= dailyLimitMinutes
    }
    
    /**
     * Get remaining minutes for daily limit
     */
    fun getRemainingMinutes(packageName: String, dailyLimitMinutes: Int?): Int {
        if (dailyLimitMinutes == null || dailyLimitMinutes <= 0) return Int.MAX_VALUE
        
        val todayMinutes = getTodayUsageMinutes(packageName)
        return maxOf(0, dailyLimitMinutes - todayMinutes)
    }
    
    /**
     * Handle device reboot - restore any interrupted sessions
     */
    fun handleDeviceReboot() {
        android.util.Log.d(TAG, "Handling device reboot")
        
        // End all active sessions (they would be invalid after reboot)
        activeSessions.clear()
        
        // Perform aggregation in case of missed updates
        serviceScope.launch {
            performAggregation()
        }
    }
    
    /**
     * Handle timezone change
     */
    fun handleTimezoneChange(newTimezone: ZoneId) {
        android.util.Log.d(TAG, "Handling timezone change to $newTimezone")
        
        // Force date check and aggregation
        serviceScope.launch {
            checkDateChange()
            performAggregation()
        }
    }
    
    /**
     * Handle clock change (system time adjustment)
     */
    fun handleClockChange(timeDeltaMs: Long) {
        android.util.Log.d(TAG, "Handling clock change: ${timeDeltaMs}ms")
        
        if (kotlin.math.abs(timeDeltaMs) > 60000) { // More than 1 minute change
            // Significant time change - end all active session to prevent invalid data
            endAllActiveSessions()
            
            serviceScope.launch {
                performAggregation()
            }
        }
    }
    
    // Private methods
    
    private suspend fun aggregationLoop() {
        while (isRunning) {
            try {
                delay(aggregationIntervalMs)
                
                if (System.currentTimeMillis() - lastAggregationTime >= aggregationIntervalMs) {
                    performAggregation()
                    lastAggregationTime = System.currentTimeMillis()
                }
                
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error in aggregation loop", e)
                delay(5000) // Wait before retrying
            }
        }
    }
    
    private suspend fun maintenanceLoop() {
        while (isRunning) {
            try {
                delay(300000) // 5 minutes
                
                performMaintenance()
                
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error in maintenance loop", e)
                delay(60000) // Wait before retrying
            }
        }
    }
    
    private suspend fun performAggregation() = withContext(Dispatchers.IO) {
        try {
            checkDateChange()
            aggregateUsageStats()
            generateDailySummary()
            
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error during aggregation", e)
        }
    }
    
    private suspend fun performMaintenance() = withContext(Dispatchers.IO) {
        try {
            // Cleanup old data
            val deletedSessions = database.cleanupOldSessions(30)
            val deletedSummaries = database.cleanupOldSummaries(90)
            
            if (deletedSessions > 0 || deletedSummaries > 0) {
                android.util.Log.d(TAG, "Cleaned up $deletedSessions sessions and $deletedSummaries summaries")
            }
            
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error during maintenance", e)
        }
    }
    
    private fun checkDateChange() {
        val now = LocalDate.now()
        if (now != currentDate) {
            android.util.Log.d(TAG, "Date changed from $currentDate to $now")
            
            // Reset daily stats
            database.resetDailyStats(now.toString())
            currentDate = now
            
            // End all active session (new day)
            endAllActiveSessions()
        }
    }
    
    private fun recordSession(sessionTracker: SessionTracker, endTime: LocalDateTime) {
        val sessionId = UUID.randomUUID().toString()
        
        val success = database.insertSession(
            id = sessionId,
            packageName = sessionTracker.packageName,
            appName = sessionTracker.appName,
            startTime = sessionTracker.startTime,
            endTime = endTime,
            deviceId = sessionTracker.deviceId
        )
        
        if (!success) {
            android.util.Log.w(TAG, "Failed to record session for ${sessionTracker.packageName}")
        }
    }
    
    private fun splitLongSession(sessionTracker: SessionTracker, endTime: LocalDateTime) {
        // Split long sessions into chunks to handle interruptions gracefully
        val chunkDurationMinutes = maxSessionDurationMinutes.toLong()
        var currentStart = sessionTracker.startTime
        
        while (currentStart.isBefore(endTime)) {
            val chunkEnd = currentStart.plusMinutes(chunkDurationMinutes)
            val actualEnd = if (chunkEnd.isAfter(endTime)) endTime else chunkEnd
            
            val sessionId = UUID.randomUUID().toString()
            database.insertSession(
                id = sessionId,
                packageName = sessionTracker.packageName,
                appName = sessionTracker.appName,
                startTime = currentStart,
                endTime = actualEnd,
                deviceId = sessionTracker.deviceId
            )
            
            currentStart = actualEnd
        }
    }
    
    private fun endAllActiveSessions() {
        val currentTime = LocalDateTime.now()
        
        activeSessions.values.forEach { sessionTracker ->
            recordSession(sessionTracker, currentTime)
        }
        
        activeSessions.clear()
    }
    
    private suspend fun aggregateUsageStats() = withContext(Dispatchers.IO) {
        val today = LocalDate.now()
        val yesterday = today.minusDays(1)
        val sevenDaysAgo = today.minusDays(7)
        val thirtyDaysAgo = today.minusDays(30)
        
        // Get all unique packages from recent sessions
        val recentPackages = mutableSetOf<String>()
        
        // Add packages from existing stats
        database.getAllStats().forEach { stats ->
            recentPackages.add(stats.packageName)
        }
        
        // Add packages from active session
        activeSessions.keys.forEach { packageName ->
            recentPackages.add(packageName)
        }
        
        // Aggregate stats for each package
        recentPackages.forEach { packageName ->
            try {
                aggregateStatsForPackage(packageName, today, yesterday, sevenDaysAgo, thirtyDaysAgo)
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error aggregating stats for $packageName", e)
            }
        }
    }
    
    private fun aggregateStatsForPackage(
        packageName: String,
        today: LocalDate,
        yesterday: LocalDate,
        sevenDaysAgo: LocalDate,
        thirtyDaysAgo: LocalDate
    ) {
        // Get sessions for different time periods
        val todaySessions = database.getSessionsForDateRange(packageName, today, today)
        val yesterdaySessions = database.getSessionsForDateRange(packageName, yesterday, yesterday)
        val last7DaysSessions = database.getSessionsForDateRange(packageName, sevenDaysAgo, today)
        val last30DaysSessions = database.getSessionsForDateRange(packageName, thirtyDaysAgo, today)
        
        val todaySeconds = todaySessions.sumOf { it.durationSeconds }
        val yesterdaySeconds = yesterdaySessions.sumOf { it.durationSeconds }
        val last7DaysSeconds = last7DaysSessions.sumOf { it.durationSeconds }
        val last30DaysSeconds = last30DaysSessions.sumOf { it.durationSeconds }
        
        val lastUsed = last30DaysSessions.maxByOrNull { it.endTime }?.endTime ?: LocalDateTime.now()
        val totalSessions = last30DaysSessions.size
        
        val appName = last30DaysSessions.firstOrNull()?.appName ?: packageName
        
        database.insertOrUpdateStats(
            packageName = packageName,
            appName = appName,
            todaySeconds = todaySeconds,
            yesterdaySeconds = yesterdaySeconds,
            last7DaysSeconds = last7DaysSeconds,
            last30DaysSeconds = last30DaysSeconds,
            lastUsed = lastUsed,
            totalSessions = totalSessions,
            date = today.toString()
        )
    }
    
    private suspend fun generateDailySummary() = withContext(Dispatchers.IO) {
        val today = LocalDate.now()
        val allStats = database.getAllStats()
        
        var totalScreenTimeSeconds = 0
        var totalAppsUsed = 0
        var totalSessions = 0
        val appUsageMap = mutableMapOf<String, Int>()
        
        allStats.forEach { stats ->
            if (stats.date == today.toString() && stats.todaySeconds > 0) {
                totalScreenTimeSeconds += stats.todaySeconds
                totalAppsUsed++
                appUsageMap[stats.packageName] = stats.todaySeconds
                
                // Count sessions for today only
                val todaySessions = database.getSessionsForDateRange(stats.packageName, today, today)
                totalSessions += todaySessions.size
            }
        }
        
        val appUsageJson = JSONObject(appUsageMap as Map<String, Any>).toString()
        
        database.insertOrUpdateDailySummary(
            date = today.toString(),
            totalScreenTimeSeconds = totalScreenTimeSeconds,
            totalAppsUsed = totalAppsUsed,
            totalSessions = totalSessions,
            appUsageJson = appUsageJson
        )
    }
    
    private fun getDeviceId(): String {
        // Get a consistent device identifier
        return android.provider.Settings.Secure.getString(
            context.contentResolver,
            android.provider.Settings.Secure.ANDROID_ID
        ) ?: "unknown_device"
    }
    
    /**
     * Get batched unsynced data for upload
     */
    fun getUnsyncedDataBatch(): UsageDataBatch {
        return UsageDataBatch(
            sessions = database.getUnsyncedSessions(syncBatchSize),
            stats = database.getUnsyncedStats(),
            summaries = database.getUnsyncedSummaries()
        )
    }
    
    /**
     * Mark data as synced after successful upload
     */
    fun markDataSynced(batch: UsageDataBatch) {
        if (batch.sessions.isNotEmpty()) {
            val sessionIds = batch.sessions.map { it.id }
            database.markSessionsSynced(sessionIds)
        }
        
        if (batch.stats.isNotEmpty()) {
            val packageNames = batch.stats.map { it.packageName }
            database.markStatsSynced(packageNames)
        }
        
        if (batch.summaries.isNotEmpty()) {
            val dates = batch.summaries.map { it.date }
            database.markSummariesSynced(dates)
        }
    }
}

/**
 * Tracks an active app usage session
 */
private data class SessionTracker(
    val packageName: String,
    val appName: String,
    val startTime: LocalDateTime,
    val deviceId: String
)

/**
 * Batch of unsynced usage data for upload
 */
data class UsageDataBatch(
    val sessions: List<UsageSessionData>,
    val stats: List<UsageStatsData>,
    val summaries: List<com.example.flutter_study_app.database.DailySummaryData>
) {
    val isEmpty: Boolean
        get() = sessions.isEmpty() && stats.isEmpty() && summaries.isEmpty()
}

/**
 * USAGE TRACKING LIMITATIONS AND CONSIDERATIONS:
 * 
 * 1. ANDROID SYSTEM LIMITATIONS:
 *    - Cannot force apps to close when limits are reached
 *    - UsageStatsManager has permission requirements and OEM variations
 *    - Background processing restrictions in newer Android versions
 *    - Battery optimization can affect tracking accuracy
 * 
 * 2. TRACKING ACCURACY:
 *    - Relies on foreground app detection which can have gaps
 *    - System apps and notifications can create false sessions
 *    - Rapid app switching may create incomplete sessions
 *    - Device sleep/wake cycles can affect timing
 * 
 * 3. SECURITY CONSIDERATIONS:
 *    - Client-side tracking can be tampered with by root users
 *    - Time manipulation can affect usage calculations
 *    - App usage data should not be the sole source for strict enforcement
 *    - Server-side validation and cross-referencing recommended
 * 
 * 4. BATTERY AND PERFORMANCE:
 *    - Continuous monitoring impacts battery life
 *    - Aggregation reduces database size and network usage
 *    - Batched sync minimizes network overhead
 *    - Configurable intervals balance accuracy vs efficiency
 * 
 * 5. OFFLINE OPERATION:
 *    - Local database ensures functionality without network
 *    - Usage limits enforced using cached data
 *    - Sync resumes when connectivity is restored
 *    - Data integrity maintained across service restarts
 */