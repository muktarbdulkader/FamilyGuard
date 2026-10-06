package com.example.flutter_study_app.database

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.example.flutter_study_app.enforcement.RuleEngine
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.format.DateTimeFormatter

/**
 * Local SQLite database for storing app rules and usage data.
 * 
 * This database operates completely offline and serves as the authoritative
 * source for rule enforcement when Firebase is unavailable.
 */
class LocalDatabase private constructor(context: Context) : 
    SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {
    
    companion object {
        private const val DATABASE_NAME = "parental_control.db"
        private const val DATABASE_VERSION = 1
        
        // Tables
        private const val TABLE_RULES = "app_rules"
        private const val TABLE_USAGE = "app_usage"
        private const val TABLE_TEMPORARY_APPROVALS = "temporary_approvals"
        
        // Rule table columns
        private const val RULE_PACKAGE_NAME = "package_name"
        private const val RULE_TYPE = "type"
        private const val RULE_DAILY_LIMIT = "daily_limit_minutes"
        private const val RULE_START_TIME = "allowed_start_time"
        private const val RULE_END_TIME = "allowed_end_time"
        private const val RULE_CREATED_AT = "created_at"
        private const val RULE_UPDATED_AT = "updated_at"
        private const val RULE_SYNC_STATUS = "sync_status" // For Firebase sync tracking
        
        // Usage table columns
        private const val USAGE_PACKAGE_NAME = "package_name"
        private const val USAGE_TODAY_MINUTES = "today_minutes"
        private const val USAGE_LAST_USED = "last_used"
        private const val USAGE_RESET_DATE = "daily_reset_date"
        private const val USAGE_TOTAL_OPENS = "total_opens"
        
        // Temporary approval columns
        private const val APPROVAL_PACKAGE_NAME = "package_name"
        private const val APPROVAL_APPROVED_AT = "approved_at"
        private const val APPROVAL_DURATION = "duration_minutes"
        private const val APPROVAL_APPROVED_BY = "approved_by"
        private const val APPROVAL_IS_ACTIVE = "is_active"
        
        @Volatile
        private var INSTANCE: LocalDatabase? = null
        
        fun getInstance(context: Context): LocalDatabase {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: LocalDatabase(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
    
    override fun onCreate(db: SQLiteDatabase) {
        // Create app rules table
        db.execSQL("""
            CREATE TABLE $TABLE_RULES (
                $RULE_PACKAGE_NAME TEXT PRIMARY KEY,
                $RULE_TYPE TEXT NOT NULL,
                $RULE_DAILY_LIMIT INTEGER,
                $RULE_START_TIME TEXT,
                $RULE_END_TIME TEXT,
                $RULE_CREATED_AT TEXT NOT NULL,
                $RULE_UPDATED_AT TEXT NOT NULL,
                $RULE_SYNC_STATUS INTEGER DEFAULT 1
            )
        """)
        
        // Create app usage table
        db.execSQL("""
            CREATE TABLE $TABLE_USAGE (
                $USAGE_PACKAGE_NAME TEXT PRIMARY KEY,
                $USAGE_TODAY_MINUTES INTEGER DEFAULT 0,
                $USAGE_LAST_USED TEXT,
                $USAGE_RESET_DATE TEXT NOT NULL,
                $USAGE_TOTAL_OPENS INTEGER DEFAULT 0
            )
        """)
        
        // Create temporary approvals table
        db.execSQL("""
            CREATE TABLE $TABLE_TEMPORARY_APPROVALS (
                $APPROVAL_PACKAGE_NAME TEXT PRIMARY KEY,
                $APPROVAL_APPROVED_AT TEXT NOT NULL,
                $APPROVAL_DURATION INTEGER NOT NULL,
                $APPROVAL_APPROVED_BY TEXT NOT NULL,
                $APPROVAL_IS_ACTIVE INTEGER DEFAULT 1
            )
        """)
        
        // Create indices for better performance
        db.execSQL("CREATE INDEX idx_rules_type ON $TABLE_RULES($RULE_TYPE)")
        db.execSQL("CREATE INDEX idx_usage_date ON $TABLE_USAGE($USAGE_RESET_DATE)")
        db.execSQL("CREATE INDEX idx_approvals_active ON $TABLE_TEMPORARY_APPROVALS($APPROVAL_IS_ACTIVE)")
    }
    
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Handle database upgrades here
        db.execSQL("DROP TABLE IF EXISTS $TABLE_RULES")
        db.execSQL("DROP TABLE IF EXISTS $TABLE_USAGE")
        db.execSQL("DROP TABLE IF EXISTS $TABLE_TEMPORARY_APPROVALS")
        onCreate(db)
    }
    
    /**
     * Rule Management
     */
    
    fun insertOrUpdateRule(rule: RuleEngine.AppRule): Boolean {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(RULE_PACKAGE_NAME, rule.packageName)
            put(RULE_TYPE, rule.type.name)
            put(RULE_DAILY_LIMIT, rule.dailyLimitMinutes)
            put(RULE_START_TIME, rule.allowedStartTime?.toString())
            put(RULE_END_TIME, rule.allowedEndTime?.toString())
            put(RULE_CREATED_AT, rule.createdAt.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
            put(RULE_UPDATED_AT, rule.updatedAt.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
            put(RULE_SYNC_STATUS, 1) // Mark as synced
        }
        
        val result = db.insertWithOnConflict(TABLE_RULES, null, values, SQLiteDatabase.CONFLICT_REPLACE)
        return result != -1L
    }
    
    fun getRule(packageName: String): RuleEngine.AppRule? {
        val db = readableDatabase
        val cursor = db.query(
            TABLE_RULES,
            null,
            "$RULE_PACKAGE_NAME = ?",
            arrayOf(packageName),
            null,
            null,
            null
        )
        
        return cursor.use { c ->
            if (c.moveToFirst()) {
                RuleEngine.AppRule(
                    packageName = c.getString(c.getColumnIndexOrThrow(RULE_PACKAGE_NAME)),
                    type = RuleEngine.RuleType.valueOf(c.getString(c.getColumnIndexOrThrow(RULE_TYPE))),
                    dailyLimitMinutes = c.getInt(c.getColumnIndexOrThrow(RULE_DAILY_LIMIT)).takeIf { !c.isNull(c.getColumnIndexOrThrow(RULE_DAILY_LIMIT)) },
                    allowedStartTime = c.getString(c.getColumnIndexOrThrow(RULE_START_TIME))?.let { LocalTime.parse(it) },
                    allowedEndTime = c.getString(c.getColumnIndexOrThrow(RULE_END_TIME))?.let { LocalTime.parse(it) },
                    createdAt = LocalDateTime.parse(c.getString(c.getColumnIndexOrThrow(RULE_CREATED_AT))),
                    updatedAt = LocalDateTime.parse(c.getString(c.getColumnIndexOrThrow(RULE_UPDATED_AT)))
                )
            } else {
                null
            }
        }
    }
    
    fun getAllRules(): List<RuleEngine.AppRule> {
        val db = readableDatabase
        val cursor = db.query(TABLE_RULES, null, null, null, null, null, null)
        val rules = mutableListOf<RuleEngine.AppRule>()
        
        cursor.use { c ->
            while (c.moveToNext()) {
                val rule = RuleEngine.AppRule(
                    packageName = c.getString(c.getColumnIndexOrThrow(RULE_PACKAGE_NAME)),
                    type = RuleEngine.RuleType.valueOf(c.getString(c.getColumnIndexOrThrow(RULE_TYPE))),
                    dailyLimitMinutes = c.getInt(c.getColumnIndexOrThrow(RULE_DAILY_LIMIT)).takeIf { !c.isNull(c.getColumnIndexOrThrow(RULE_DAILY_LIMIT)) },
                    allowedStartTime = c.getString(c.getColumnIndexOrThrow(RULE_START_TIME))?.let { LocalTime.parse(it) },
                    allowedEndTime = c.getString(c.getColumnIndexOrThrow(RULE_END_TIME))?.let { LocalTime.parse(it) },
                    createdAt = LocalDateTime.parse(c.getString(c.getColumnIndexOrThrow(RULE_CREATED_AT))),
                    updatedAt = LocalDateTime.parse(c.getString(c.getColumnIndexOrThrow(RULE_UPDATED_AT)))
                )
                rules.add(rule)
            }
        }
        
        return rules
    }
    
    fun deleteRule(packageName: String): Boolean {
        val db = writableDatabase
        val result = db.delete(TABLE_RULES, "$RULE_PACKAGE_NAME = ?", arrayOf(packageName))
        return result > 0
    }
    
    /**
     * Usage Tracking
     */
    
    fun insertOrUpdateUsage(usage: RuleEngine.UsageData): Boolean {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(USAGE_PACKAGE_NAME, usage.packageName)
            put(USAGE_TODAY_MINUTES, usage.todayMinutes)
            put(USAGE_LAST_USED, usage.lastUsed.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
            put(USAGE_RESET_DATE, usage.dailyResetDate)
            put(USAGE_TOTAL_OPENS, 0) // This would be incremented separately
        }
        
        val result = db.insertWithOnConflict(TABLE_USAGE, null, values, SQLiteDatabase.CONFLICT_REPLACE)
        return result != -1L
    }
    
    fun getUsage(packageName: String): RuleEngine.UsageData? {
        val db = readableDatabase
        val cursor = db.query(
            TABLE_USAGE,
            null,
            "$USAGE_PACKAGE_NAME = ?",
            arrayOf(packageName),
            null,
            null,
            null
        )
        
        return cursor.use { c ->
            if (c.moveToFirst()) {
                RuleEngine.UsageData(
                    packageName = c.getString(c.getColumnIndexOrThrow(USAGE_PACKAGE_NAME)),
                    todayMinutes = c.getInt(c.getColumnIndexOrThrow(USAGE_TODAY_MINUTES)),
                    lastUsed = LocalDateTime.parse(c.getString(c.getColumnIndexOrThrow(USAGE_LAST_USED))),
                    dailyResetDate = c.getString(c.getColumnIndexOrThrow(USAGE_RESET_DATE))
                )
            } else {
                null
            }
        }
    }
    
    fun incrementUsageMinutes(packageName: String, minutes: Int, currentTime: LocalDateTime) {
        val db = writableDatabase
        val today = currentTime.toLocalDate().toString()
        
        db.beginTransaction()
        try {
            // Get current usage
            var currentUsage = getUsage(packageName)
            
            if (currentUsage == null || currentUsage.dailyResetDate != today) {
                // Create new usage record for today
                currentUsage = RuleEngine.UsageData(
                    packageName = packageName,
                    todayMinutes = minutes,
                    lastUsed = currentTime,
                    dailyResetDate = today
                )
            } else {
                // Update existing usage
                currentUsage = RuleEngine.UsageData(
                    packageName = packageName,
                    todayMinutes = currentUsage.todayMinutes + minutes,
                    lastUsed = currentTime,
                    dailyResetDate = today
                )
            }
            
            insertOrUpdateUsage(currentUsage)
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }
    
    fun resetUsageForDate(packageName: String, date: String) {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(USAGE_TODAY_MINUTES, 0)
            put(USAGE_RESET_DATE, date)
        }
        
        db.update(TABLE_USAGE, values, "$USAGE_PACKAGE_NAME = ?", arrayOf(packageName))
    }
    
    fun getAllUsageData(): Map<String, RuleEngine.UsageData> {
        val db = readableDatabase
        val cursor = db.query(TABLE_USAGE, null, null, null, null, null, null)
        val usageMap = mutableMapOf<String, RuleEngine.UsageData>()
        
        cursor.use { c ->
            while (c.moveToNext()) {
                val usage = RuleEngine.UsageData(
                    packageName = c.getString(c.getColumnIndexOrThrow(USAGE_PACKAGE_NAME)),
                    todayMinutes = c.getInt(c.getColumnIndexOrThrow(USAGE_TODAY_MINUTES)),
                    lastUsed = LocalDateTime.parse(c.getString(c.getColumnIndexOrThrow(USAGE_LAST_USED))),
                    dailyResetDate = c.getString(c.getColumnIndexOrThrow(USAGE_RESET_DATE))
                )
                usageMap[usage.packageName] = usage
            }
        }
        
        return usageMap
    }
    
    /**
     * Temporary Approvals
     */
    
    fun insertTemporaryApproval(approval: RuleEngine.TemporaryApproval): Boolean {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(APPROVAL_PACKAGE_NAME, approval.packageName)
            put(APPROVAL_APPROVED_AT, approval.approvedAt.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
            put(APPROVAL_DURATION, approval.durationMinutes)
            put(APPROVAL_APPROVED_BY, approval.approvedBy)
            put(APPROVAL_IS_ACTIVE, 1)
        }
        
        val result = db.insertWithOnConflict(TABLE_TEMPORARY_APPROVALS, null, values, SQLiteDatabase.CONFLICT_REPLACE)
        return result != -1L
    }
    
    fun getActiveTemporaryApproval(packageName: String): RuleEngine.TemporaryApproval? {
        val db = readableDatabase
        val cursor = db.query(
            TABLE_TEMPORARY_APPROVALS,
            null,
            "$APPROVAL_PACKAGE_NAME = ? AND $APPROVAL_IS_ACTIVE = 1",
            arrayOf(packageName),
            null,
            null,
            null
        )
        
        return cursor.use { c ->
            if (c.moveToFirst()) {
                RuleEngine.TemporaryApproval(
                    packageName = c.getString(c.getColumnIndexOrThrow(APPROVAL_PACKAGE_NAME)),
                    approvedAt = LocalDateTime.parse(c.getString(c.getColumnIndexOrThrow(APPROVAL_APPROVED_AT))),
                    durationMinutes = c.getInt(c.getColumnIndexOrThrow(APPROVAL_DURATION)),
                    approvedBy = c.getString(c.getColumnIndexOrThrow(APPROVAL_APPROVED_BY))
                )
            } else {
                null
            }
        }
    }
    
    fun expireTemporaryApproval(packageName: String) {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(APPROVAL_IS_ACTIVE, 0)
        }
        
        db.update(TABLE_TEMPORARY_APPROVALS, values, "$APPROVAL_PACKAGE_NAME = ?", arrayOf(packageName))
    }
    
    fun cleanupExpiredApprovals(currentTime: LocalDateTime) {
        val db = writableDatabase
        val expiredTime = currentTime.minusHours(24).format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
        
        // Delete approvals older than 24 hours
        db.delete(TABLE_TEMPORARY_APPROVALS, "$APPROVAL_APPROVED_AT < ?", arrayOf(expiredTime))
    }
}