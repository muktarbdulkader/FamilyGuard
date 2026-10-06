package com.example.flutter_study_app.enforcement

import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.util.*

/**
 * Core rule evaluation engine for parental control enforcement.
 * 
 * This engine evaluates app access based on configured rules and usage data.
 * It operates entirely offline using cached rules and local usage tracking.
 */
class RuleEngine {
    
    /**
     * Rule evaluation result
     */
    enum class EvaluationResult {
        ALLOW,              // App is allowed to run
        BLOCK,              // App is blocked
        REQUEST,            // Must request parent permission
        TIME_EXPIRED,       // Daily time limit exceeded
        OUTSIDE_ALLOWED_WINDOW, // Current time is outside allowed window
        TEMPORARY_APPROVAL  // Temporary approval is active
    }
    
    /**
     * Rule types matching the parent dashboard
     */
    enum class RuleType {
        ALLOWED,
        BLOCKED,
        ASK_PARENT,
        TIME_LIMIT,
        TIME_WINDOW
    }
    
    /**
     * App rule definition
     */
    data class AppRule(
        val packageName: String,
        val type: RuleType,
        val dailyLimitMinutes: Int? = null,
        val allowedStartTime: LocalTime? = null,
        val allowedEndTime: LocalTime? = null,
        val createdAt: LocalDateTime,
        val updatedAt: LocalDateTime
    )
    
    /**
     * Usage tracking data
     */
    data class UsageData(
        val packageName: String,
        val todayMinutes: Int,
        val lastUsed: LocalDateTime,
        val dailyResetDate: String // Format: yyyy-MM-dd
    )
    
    /**
     * Temporary approval data
     */
    data class TemporaryApproval(
        val packageName: String,
        val approvedAt: LocalDateTime,
        val durationMinutes: Int,
        val approvedBy: String // Parent ID
    ) {
        fun isExpired(currentTime: LocalDateTime): Boolean {
            return currentTime.isAfter(approvedAt.plusMinutes(durationMinutes.toLong()))
        }
    }
    
    /**
     * Evaluate whether an app should be allowed to run
     * 
     * @param packageName The package name of the app to evaluate
     * @param currentTime Current system time
     * @param rule The app rule (null if no rule exists - defaults to ALLOWED)
     * @param usageData Current usage data for the app
     * @param temporaryApproval Active temporary approval (null if none)
     * @return EvaluationResult indicating what action to take
     */
    fun evaluate(
        packageName: String,
        currentTime: LocalDateTime,
        rule: AppRule?,
        usageData: UsageData?,
        temporaryApproval: TemporaryApproval? = null
    ): EvaluationResult {
        
        // Check for active temporary approval first
        temporaryApproval?.let { approval ->
            if (!approval.isExpired(currentTime) && approval.packageName == packageName) {
                return EvaluationResult.TEMPORARY_APPROVAL
            }
        }
        
        // If no rule exists, default to allowed
        if (rule == null) {
            return EvaluationResult.ALLOW
        }
        
        // Evaluate based on rule type
        return when (rule.type) {
            RuleType.ALLOWED -> EvaluationResult.ALLOW
            
            RuleType.BLOCKED -> EvaluationResult.BLOCK
            
            RuleType.ASK_PARENT -> EvaluationResult.REQUEST
            
            RuleType.TIME_LIMIT -> evaluateTimeLimit(rule, usageData, currentTime)
            
            RuleType.TIME_WINDOW -> evaluateTimeWindow(rule, currentTime)
        }
    }
    
    /**
     * Evaluate time limit rule
     */
    private fun evaluateTimeLimit(
        rule: AppRule,
        usageData: UsageData?,
        currentTime: LocalDateTime
    ): EvaluationResult {
        val dailyLimitMinutes = rule.dailyLimitMinutes ?: return EvaluationResult.ALLOW
        
        // If no usage data, allow (first time use)
        if (usageData == null) {
            return EvaluationResult.ALLOW
        }
        
        // Check if usage data is from today
        val today = getTodayDateString(currentTime)
        if (usageData.dailyResetDate != today) {
            // Usage data is from previous day, reset
            return EvaluationResult.ALLOW
        }
        
        // Check if daily limit exceeded
        return if (usageData.todayMinutes >= dailyLimitMinutes) {
            EvaluationResult.TIME_EXPIRED
        } else {
            EvaluationResult.ALLOW
        }
    }
    
    /**
     * Evaluate time window rule
     */
    private fun evaluateTimeWindow(
        rule: AppRule,
        currentTime: LocalDateTime
    ): EvaluationResult {
        val startTime = rule.allowedStartTime ?: return EvaluationResult.ALLOW
        val endTime = rule.allowedEndTime ?: return EvaluationResult.ALLOW
        
        val currentTimeOfDay = currentTime.toLocalTime()
        
        return if (isTimeWithinWindow(currentTimeOfDay, startTime, endTime)) {
            EvaluationResult.ALLOW
        } else {
            EvaluationResult.OUTSIDE_ALLOWED_WINDOW
        }
    }
    
    /**
     * Check if current time is within allowed window
     * Handles cases where window crosses midnight (e.g., 22:00 to 06:00)
     */
    private fun isTimeWithinWindow(
        currentTime: LocalTime,
        startTime: LocalTime,
        endTime: LocalTime
    ): Boolean {
        return if (startTime.isBefore(endTime)) {
            // Normal window (e.g., 09:00 to 17:00)
            currentTime.isAfter(startTime) && currentTime.isBefore(endTime)
        } else {
            // Window crosses midnight (e.g., 22:00 to 06:00)
            currentTime.isAfter(startTime) || currentTime.isBefore(endTime)
        }
    }
    
    /**
     * Get today's date string in format yyyy-MM-dd
     */
    fun getTodayDateString(currentTime: LocalDateTime): String {
        return currentTime.toLocalDate().toString()
    }
    
    /**
     * Check if usage data needs reset (new day)
     */
    fun shouldResetUsageData(usageData: UsageData, currentTime: LocalDateTime): Boolean {
        val today = getTodayDateString(currentTime)
        return usageData.dailyResetDate != today
    }
    
    /**
     * Calculate remaining time for time-limited apps
     */
    fun getRemainingMinutes(rule: AppRule?, usageData: UsageData?, currentTime: LocalDateTime): Int? {
        if (rule?.type != RuleType.TIME_LIMIT || rule.dailyLimitMinutes == null) {
            return null
        }
        
        val usage = usageData?.let { data ->
            if (shouldResetUsageData(data, currentTime)) 0 else data.todayMinutes
        } ?: 0
        
        return maxOf(0, rule.dailyLimitMinutes - usage)
    }
    
    /**
     * Get time until allowed window opens
     */
    fun getMinutesUntilAllowed(rule: AppRule?, currentTime: LocalDateTime): Int? {
        if (rule?.type != RuleType.TIME_WINDOW || rule.allowedStartTime == null) {
            return null
        }
        
        val currentTimeOfDay = currentTime.toLocalTime()
        val startTime = rule.allowedStartTime
        
        return if (currentTimeOfDay.isBefore(startTime)) {
            // Same day
            java.time.Duration.between(currentTimeOfDay, startTime).toMinutes().toInt()
        } else {
            // Next day
            val minutesToMidnight = java.time.Duration.between(currentTimeOfDay, LocalTime.MIDNIGHT).toMinutes()
            val minutesFromMidnight = java.time.Duration.between(LocalTime.MIDNIGHT, startTime).toMinutes()
            (minutesToMidnight + minutesFromMidnight).toInt()
        }
    }
}