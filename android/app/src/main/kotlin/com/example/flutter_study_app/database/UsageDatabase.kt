package com.example.flutter_study_app.database

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.*

/**
 * Local SQLite database for storing app usage sessions and aggregated statistics.
 * 
 * This database handles offline usage tracking and provides the data source for
 * both local rule enforcement and parent dashboard synchronization.
 */
class UsageDatabase private constructor(context: Context) : 
    SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {
    
    companion object {
        private const val DATABASE_NAME = "usage_tracking.db"
        private const val DATABASE_VERSION = 1
        
        // Tables
        private const val TABLE_SESSIONS = "usage_sessions"
        private const val TABLE_STATS = "app_usage_stats"
        private const val TABLE_DAILY_SUMMARY = "daily_summary"
        
        // Session table columns
        private const val SESSION_ID = "id"
        private const val SESSION_PACKAGE = "package_name"
        private const val SESSION_APP_NAME = "app_name"
        private const val SESSION_START = "start_time"
        private const val SESSION_END = "end_time"
        private const val SESSION_DURATION = "duration_seconds"
        private const val SESSION_DEVICE_ID = "device_id"
        private const val SESSION_SYNCED = "synced"
        private const val SESSION_CREATED = "created_at"
        
        // Stats table columns
        private const val STATS_PACKAGE = "package_name"
        private const val STATS_APP_NAME = "app_name"
        private const val STATS_TODAY = "today_seconds"
        private const val STATS_YESTERDAY = "yesterday_seconds"
        private const val STATS_LAST_7_DAYS = "last_7_days_seconds"
        private const val STATS_LAST_30_DAYS = "last_30_days_seconds"
        private const val STATS_LAST_USED = "last_used"
        private const val STATS_TOTAL_SESSIONS = "total_sessions"
        private const val STATS_DATE = "date"
        private const val STATS_UPDATED = "updated_at"
        private const val STATS_SYNCED = "synced"
        
        // Daily summary columns
        private const val SUMMARY_DATE = "date"
        private const val SUMMARY_TOTAL_SCREEN_TIME = "total_screen_time_seconds"
        private const val SUMMARY_TOTAL_APPS = "total_apps_used"
        private const val SUMMARY_TOTAL_SESSIONS = "total_sessions"
        private const val SUMMARY_APP_USAGE = "app_usage_json" // JSON string
        private const val SUMMARY_CREATED = "created_at"
        private const val SUMMARY_UPDATED = "updated_at"
        private const val SUMMARY_SYNCED = "synced"
        
        @Volatile
        private var INSTANCE: UsageDatabase? = null
        
        fun getInstance(context: Context): UsageDatabase {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: UsageDatabase(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
    
    override fun onCreate(db: SQLiteDatabase) {
        // Create usage sessions table
        db.execSQL("""
            CREATE TABLE $TABLE_SESSIONS (
                $SESSION_ID TEXT PRIMARY KEY,
                $SESSION_PACKAGE TEXT NOT NULL,
                $SESSION_APP_NAME TEXT NOT NULL,
                $SESSION_START TEXT NOT NULL,
                $SESSION_END TEXT NOT NULL,
                $SESSION_DURATION INTEGER NOT NULL,
                $SESSION_DEVICE_ID TEXT NOT NULL,
                $SESSION_SYNCED INTEGER DEFAULT 0,
                $SESSION_CREATED TEXT NOT NULL
            )
        """)
        
        // Create app usage stats table
        db.execSQL("""
            CREATE TABLE $TABLE_STATS (
                $STATS_PACKAGE TEXT PRIMARY KEY,
                $STATS_APP_NAME TEXT NOT NULL,
                $STATS_TODAY INTEGER DEFAULT 0,
                $STATS_YESTERDAY INTEGER DEFAULT 0,
                $STATS_LAST_7_DAYS INTEGER DEFAULT 0,
                $STATS_LAST_30_DAYS INTEGER DEFAULT 0,
                $STATS_LAST_USED TEXT NOT NULL,
                $STATS_TOTAL_SESSIONS INTEGER DEFAULT 0,
                $STATS_DATE TEXT NOT NULL,
                $STATS_UPDATED TEXT NOT NULL,
                $STATS_SYNCED INTEGER DEFAULT 0
            )
        """)
        
        // Create daily summary table
        db.execSQL("""
            CREATE TABLE $TABLE_DAILY_SUMMARY (
                $SUMMARY_DATE TEXT PRIMARY KEY,
                $SUMMARY_TOTAL_SCREEN_TIME INTEGER DEFAULT 0,
                $SUMMARY_TOTAL_APPS INTEGER DEFAULT 0,
                $SUMMARY_TOTAL_SESSIONS INTEGER DEFAULT 0,
                $SUMMARY_APP_USAGE TEXT DEFAULT '{}',
                $SUMMARY_CREATED TEXT NOT NULL,
                $SUMMARY_UPDATED TEXT NOT NULL,
                $SUMMARY_SYNCED INTEGER DEFAULT 0
            )
        """)
        
        // Create indices for better performance
        db.execSQL("CREATE INDEX idx_sessions_package_date ON $TABLE_SESSIONS($SESSION_PACKAGE, $SESSION_START)")
        db.execSQL("CREATE INDEX idx_sessions_synced ON $TABLE_SESSIONS($SESSION_SYNCED)")
        db.execSQL("CREATE INDEX idx_sessions_created ON $TABLE_SESSIONS($SESSION_CREATED)")
        db.execSQL("CREATE INDEX idx_stats_date ON $TABLE_STATS($STATS_DATE)")
        db.execSQL("CREATE INDEX idx_stats_synced ON $TABLE_STATS($STATS_SYNCED)")
        db.execSQL("CREATE INDEX idx_summary_synced ON $TABLE_DAILY_SUMMARY($SUMMARY_SYNCED)")
    }
    
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Handle database upgrades here
        db.execSQL("DROP TABLE IF EXISTS $TABLE_SESSIONS")
        db.execSQL("DROP TABLE IF EXISTS $TABLE_STATS")
        db.execSQL("DROP TABLE IF EXISTS $TABLE_DAILY_SUMMARY")
        onCreate(db)
    }
    
    /**
     * Usage Session Management
     */
    
    fun insertSession(
        id: String,
        packageName: String,
        appName: String,
        startTime: LocalDateTime,
        endTime: LocalDateTime,
        deviceId: String
    ): Boolean {
        val db = writableDatabase
        val durationSeconds = java.time.Duration.between(startTime, endTime).seconds.toInt()
        
        if (durationSeconds <= 0) return false // Invalid session
        
        val values = ContentValues().apply {
            put(SESSION_ID, id)
            put(SESSION_PACKAGE, packageName)
            put(SESSION_APP_NAME, appName)
            put(SESSION_START, startTime.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
            put(SESSION_END, endTime.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
            put(SESSION_DURATION, durationSeconds)
            put(SESSION_DEVICE_ID, deviceId)
            put(SESSION_SYNCED, 0)
            put(SESSION_CREATED, LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
        }
        
        val result = db.insertWithOnConflict(TABLE_SESSIONS, null, values, SQLiteDatabase.CONFLICT_REPLACE)
        return result != -1L
    }
    
    fun getUnsyncedSessions(limit: Int = 50): List<UsageSessionData> {
        val db = readableDatabase
        val sessions = mutableListOf<UsageSessionData>()
        
        val cursor = db.query(
            TABLE_SESSIONS,
            null,
            "$SESSION_SYNCED = 0",
            null,
            null,
            null,
            "$SESSION_CREATED ASC",
            limit.toString()
        )
        
        cursor.use { c ->
            while (c.moveToNext()) {
                sessions.add(parseSessionFromCursor(c))
            }
        }
        
        return sessions
    }
    
    fun markSessionsSynced(sessionIds: List<String>): Boolean {
        val db = writableDatabase
        val placeholders = sessionIds.joinToString(",") { "?" }
        
        val values = ContentValues().apply {
            put(SESSION_SYNCED, 1)
        }
        
        val result = db.update(
            TABLE_SESSIONS,
            values,
            "$SESSION_ID IN ($placeholders)",
            sessionIds.toTypedArray()
        )
        
        return result > 0
    }
    
    fun getSessionsForDateRange(
        packageName: String,
        startDate: LocalDate,
        endDate: LocalDate
    ): List<UsageSessionData> {
        val db = readableDatabase
        val sessions = mutableListOf<UsageSessionData>()
        
        val startDateStr = startDate.atStartOfDay().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
        val endDateStr = endDate.plusDays(1).atStartOfDay().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
        
        val cursor = db.query(
            TABLE_SESSIONS,
            null,
            "$SESSION_PACKAGE = ? AND $SESSION_START >= ? AND $SESSION_START < ?",
            arrayOf(packageName, startDateStr, endDateStr),
            null,
            null,
            "$SESSION_START ASC"
        )
        
        cursor.use { c ->
            while (c.moveToNext()) {
                sessions.add(parseSessionFromCursor(c))
            }
        }
        
        return sessions
    }
    
    /**
     * Usage Statistics Management
     */
    
    fun insertOrUpdateStats(
        packageName: String,
        appName: String,
        todaySeconds: Int,
        yesterdaySeconds: Int,
        last7DaysSeconds: Int,
        last30DaysSeconds: Int,
        lastUsed: LocalDateTime,
        totalSessions: Int,
        date: String
    ): Boolean {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(STATS_PACKAGE, packageName)
            put(STATS_APP_NAME, appName)
            put(STATS_TODAY, todaySeconds)
            put(STATS_YESTERDAY, yesterdaySeconds)
            put(STATS_LAST_7_DAYS, last7DaysSeconds)
            put(STATS_LAST_30_DAYS, last30DaysSeconds)
            put(STATS_LAST_USED, lastUsed.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
            put(STATS_TOTAL_SESSIONS, totalSessions)
            put(STATS_DATE, date)
            put(STATS_UPDATED, LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
            put(STATS_SYNCED, 0)
        }
        
        val result = db.insertWithOnConflict(TABLE_STATS, null, values, SQLiteDatabase.CONFLICT_REPLACE)
        return result != -1L
    }
    
    fun getStatsForPackage(packageName: String): UsageStatsData? {
        val db = readableDatabase
        val cursor = db.query(
            TABLE_STATS,
            null,
            "$STATS_PACKAGE = ?",
            arrayOf(packageName),
            null,
            null,
            null
        )
        
        return cursor.use { c ->
            if (c.moveToFirst()) {
                parseStatsFromCursor(c)
            } else {
                null
            }
        }
    }
    
    fun getAllStats(): List<UsageStatsData> {
        val db = readableDatabase
        val stats = mutableListOf<UsageStatsData>()
        
        val cursor = db.query(TABLE_STATS, null, null, null, null, null, "$STATS_LAST_USED DESC")
        
        cursor.use { c ->
            while (c.moveToNext()) {
                stats.add(parseStatsFromCursor(c))
            }
        }
        
        return stats
    }
    
    fun getUnsyncedStats(): List<UsageStatsData> {
        val db = readableDatabase
        val stats = mutableListOf<UsageStatsData>()
        
        val cursor = db.query(
            TABLE_STATS,
            null,
            "$STATS_SYNCED = 0",
            null,
            null,
            null,
            "$STATS_UPDATED ASC"
        )
        
        cursor.use { c ->
            while (c.moveToNext()) {
                stats.add(parseStatsFromCursor(c))
            }
        }
        
        return stats
    }
    
    fun markStatsSynced(packageNames: List<String>): Boolean {
        val db = writableDatabase
        val placeholders = packageNames.joinToString(",") { "?" }
        
        val values = ContentValues().apply {
            put(STATS_SYNCED, 1)
        }
        
        val result = db.update(
            TABLE_STATS,
            values,
            "$STATS_PACKAGE IN ($placeholders)",
            packageNames.toTypedArray()
        )
        
        return result > 0
    }
    
    /**
     * Daily Summary Management
     */
    
    fun insertOrUpdateDailySummary(
        date: String,
        totalScreenTimeSeconds: Int,
        totalAppsUsed: Int,
        totalSessions: Int,
        appUsageJson: String
    ): Boolean {
        val db = writableDatabase
        val now = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
        
        val values = ContentValues().apply {
            put(SUMMARY_DATE, date)
            put(SUMMARY_TOTAL_SCREEN_TIME, totalScreenTimeSeconds)
            put(SUMMARY_TOTAL_APPS, totalAppsUsed)
            put(SUMMARY_TOTAL_SESSIONS, totalSessions)
            put(SUMMARY_APP_USAGE, appUsageJson)
            put(SUMMARY_UPDATED, now)
            put(SUMMARY_SYNCED, 0)
        }
        
        // Try to update first
        val updateResult = db.update(
            TABLE_DAILY_SUMMARY,
            values,
            "$SUMMARY_DATE = ?",
            arrayOf(date)
        )
        
        if (updateResult == 0) {
            // Insert if update didn't affect any rows
            values.put(SUMMARY_CREATED, now)
            val insertResult = db.insert(TABLE_DAILY_SUMMARY, null, values)
            return insertResult != -1L
        }
        
        return true
    }
    
    fun getDailySummary(date: String): DailySummaryData? {
        val db = readableDatabase
        val cursor = db.query(
            TABLE_DAILY_SUMMARY,
            null,
            "$SUMMARY_DATE = ?",
            arrayOf(date),
            null,
            null,
            null
        )
        
        return cursor.use { c ->
            if (c.moveToFirst()) {
                parseSummaryFromCursor(c)
            } else {
                null
            }
        }
    }
    
    fun getUnsyncedSummaries(): List<DailySummaryData> {
        val db = readableDatabase
        val summaries = mutableListOf<DailySummaryData>()
        
        val cursor = db.query(
            TABLE_DAILY_SUMMARY,
            null,
            "$SUMMARY_SYNCED = 0",
            null,
            null,
            null,
            "$SUMMARY_DATE DESC"
        )
        
        cursor.use { c ->
            while (c.moveToNext()) {
                summaries.add(parseSummaryFromCursor(c))
            }
        }
        
        return summaries
    }
    
    fun markSummariesSynced(dates: List<String>): Boolean {
        val db = writableDatabase
        val placeholders = dates.joinToString(",") { "?" }
        
        val values = ContentValues().apply {
            put(SUMMARY_SYNCED, 1)
        }
        
        val result = db.update(
            TABLE_DAILY_SUMMARY,
            values,
            "$SUMMARY_DATE IN ($placeholders)",
            dates.toTypedArray()
        )
        
        return result > 0
    }
    
    /**
     * Maintenance Operations
     */
    
    fun cleanupOldSessions(olderThanDays: Int = 30): Int {
        val db = writableDatabase
        val cutoffDate = LocalDateTime.now().minusDays(olderThanDays.toLong())
        val cutoffDateStr = cutoffDate.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
        
        return db.delete(
            TABLE_SESSIONS,
            "$SESSION_CREATED < ? AND $SESSION_SYNCED = 1",
            arrayOf(cutoffDateStr)
        )
    }
    
    fun cleanupOldSummaries(olderThanDays: Int = 90): Int {
        val db = writableDatabase
        val cutoffDate = LocalDate.now().minusDays(olderThanDays.toLong())
        val cutoffDateStr = cutoffDate.toString()
        
        return db.delete(
            TABLE_DAILY_SUMMARY,
            "$SUMMARY_DATE < ? AND $SUMMARY_SYNCED = 1",
            arrayOf(cutoffDateStr)
        )
    }
    
    fun resetDailyStats(date: String): Boolean {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(STATS_TODAY, 0)
            put(STATS_DATE, date)
            put(STATS_UPDATED, LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
            put(STATS_SYNCED, 0)
        }
        
        val result = db.update(TABLE_STATS, values, null, null)
        return result > 0
    }
    
    // Helper methods for parsing cursor data
    
    private fun parseSessionFromCursor(cursor: android.database.Cursor): UsageSessionData {
        return UsageSessionData(
            id = cursor.getString(cursor.getColumnIndexOrThrow(SESSION_ID)),
            packageName = cursor.getString(cursor.getColumnIndexOrThrow(SESSION_PACKAGE)),
            appName = cursor.getString(cursor.getColumnIndexOrThrow(SESSION_APP_NAME)),
            startTime = LocalDateTime.parse(cursor.getString(cursor.getColumnIndexOrThrow(SESSION_START))),
            endTime = LocalDateTime.parse(cursor.getString(cursor.getColumnIndexOrThrow(SESSION_END))),
            durationSeconds = cursor.getInt(cursor.getColumnIndexOrThrow(SESSION_DURATION)),
            deviceId = cursor.getString(cursor.getColumnIndexOrThrow(SESSION_DEVICE_ID)),
            synced = cursor.getInt(cursor.getColumnIndexOrThrow(SESSION_SYNCED)) == 1,
            createdAt = LocalDateTime.parse(cursor.getString(cursor.getColumnIndexOrThrow(SESSION_CREATED)))
        )
    }
    
    private fun parseStatsFromCursor(cursor: android.database.Cursor): UsageStatsData {
        return UsageStatsData(
            packageName = cursor.getString(cursor.getColumnIndexOrThrow(STATS_PACKAGE)),
            appName = cursor.getString(cursor.getColumnIndexOrThrow(STATS_APP_NAME)),
            todaySeconds = cursor.getInt(cursor.getColumnIndexOrThrow(STATS_TODAY)),
            yesterdaySeconds = cursor.getInt(cursor.getColumnIndexOrThrow(STATS_YESTERDAY)),
            last7DaysSeconds = cursor.getInt(cursor.getColumnIndexOrThrow(STATS_LAST_7_DAYS)),
            last30DaysSeconds = cursor.getInt(cursor.getColumnIndexOrThrow(STATS_LAST_30_DAYS)),
            lastUsed = LocalDateTime.parse(cursor.getString(cursor.getColumnIndexOrThrow(STATS_LAST_USED))),
            totalSessions = cursor.getInt(cursor.getColumnIndexOrThrow(STATS_TOTAL_SESSIONS)),
            date = cursor.getString(cursor.getColumnIndexOrThrow(STATS_DATE)),
            updatedAt = LocalDateTime.parse(cursor.getString(cursor.getColumnIndexOrThrow(STATS_UPDATED))),
            synced = cursor.getInt(cursor.getColumnIndexOrThrow(STATS_SYNCED)) == 1
        )
    }
    
    private fun parseSummaryFromCursor(cursor: android.database.Cursor): DailySummaryData {
        return DailySummaryData(
            date = cursor.getString(cursor.getColumnIndexOrThrow(SUMMARY_DATE)),
            totalScreenTimeSeconds = cursor.getInt(cursor.getColumnIndexOrThrow(SUMMARY_TOTAL_SCREEN_TIME)),
            totalAppsUsed = cursor.getInt(cursor.getColumnIndexOrThrow(SUMMARY_TOTAL_APPS)),
            totalSessions = cursor.getInt(cursor.getColumnIndexOrThrow(SUMMARY_TOTAL_SESSIONS)),
            appUsageJson = cursor.getString(cursor.getColumnIndexOrThrow(SUMMARY_APP_USAGE)),
            createdAt = LocalDateTime.parse(cursor.getString(cursor.getColumnIndexOrThrow(SUMMARY_CREATED))),
            updatedAt = LocalDateTime.parse(cursor.getString(cursor.getColumnIndexOrThrow(SUMMARY_UPDATED))),
            synced = cursor.getInt(cursor.getColumnIndexOrThrow(SUMMARY_SYNCED)) == 1
        )
    }
}

// Data classes for usage tracking
data class UsageSessionData(
    val id: String,
    val packageName: String,
    val appName: String,
    val startTime: LocalDateTime,
    val endTime: LocalDateTime,
    val durationSeconds: Int,
    val deviceId: String,
    val synced: Boolean,
    val createdAt: LocalDateTime
)

data class UsageStatsData(
    val packageName: String,
    val appName: String,
    val todaySeconds: Int,
    val yesterdaySeconds: Int,
    val last7DaysSeconds: Int,
    val last30DaysSeconds: Int,
    val lastUsed: LocalDateTime,
    val totalSessions: Int,
    val date: String,
    val updatedAt: LocalDateTime,
    val synced: Boolean
)

data class DailySummaryData(
    val date: String,
    val totalScreenTimeSeconds: Int,
    val totalAppsUsed: Int,
    val totalSessions: Int,
    val appUsageJson: String,
    val createdAt: LocalDateTime,
    val updatedAt: LocalDateTime,
    val synced: Boolean
)