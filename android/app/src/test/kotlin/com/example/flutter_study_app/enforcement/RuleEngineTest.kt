package com.example.flutter_study_app.enforcement

import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDateTime
import java.time.LocalTime

/**
 * Comprehensive unit tests for RuleEngine
 * 
 * Test cases cover all rule types, edge cases, and offline operation
 */
class RuleEngineTest {
    
    private val ruleEngine = RuleEngine()
    private val testTime = LocalDateTime.of(2024, 1, 15, 14, 30) // Monday 2:30 PM
    
    @Test
    fun `test allowed app rule`() {
        val rule = createRule(RuleEngine.RuleType.ALLOWED)
        
        val result = ruleEngine.evaluate("com.example.app", testTime, rule, null)
        
        assertEquals(RuleEngine.EvaluationResult.ALLOW, result)
    }
    
    @Test
    fun `test blocked app rule`() {
        val rule = createRule(RuleEngine.RuleType.BLOCKED)
        
        val result = ruleEngine.evaluate("com.example.app", testTime, rule, null)
        
        assertEquals(RuleEngine.EvaluationResult.BLOCK, result)
    }
    
    @Test
    fun `test ask parent rule`() {
        val rule = createRule(RuleEngine.RuleType.ASK_PARENT)
        
        val result = ruleEngine.evaluate("com.example.app", testTime, rule, null)
        
        assertEquals(RuleEngine.EvaluationResult.REQUEST, result)
    }
    
    @Test
    fun `test no rule defaults to allowed`() {
        val result = ruleEngine.evaluate("com.example.app", testTime, null, null)
        
        assertEquals(RuleEngine.EvaluationResult.ALLOW, result)
    }
    
    // Time Limit Tests
    
    @Test
    fun `test time limit - within limit`() {
        val rule = createRule(RuleEngine.RuleType.TIME_LIMIT, dailyLimitMinutes = 120) // 2 hours
        val usageData = createUsageData(todayMinutes = 60) // 1 hour used
        
        val result = ruleEngine.evaluate("com.example.app", testTime, rule, usageData)
        
        assertEquals(RuleEngine.EvaluationResult.ALLOW, result)
    }
    
    @Test
    fun `test time limit - at exact limit`() {
        val rule = createRule(RuleEngine.RuleType.TIME_LIMIT, dailyLimitMinutes = 120)
        val usageData = createUsageData(todayMinutes = 120) // Exactly at limit
        
        val result = ruleEngine.evaluate("com.example.app", testTime, rule, usageData)
        
        assertEquals(RuleEngine.EvaluationResult.TIME_EXPIRED, result)
    }
    
    @Test
    fun `test time limit - exceeded`() {
        val rule = createRule(RuleEngine.RuleType.TIME_LIMIT, dailyLimitMinutes = 60)
        val usageData = createUsageData(todayMinutes = 90) // Over limit
        
        val result = ruleEngine.evaluate("com.example.app", testTime, rule, usageData)
        
        assertEquals(RuleEngine.EvaluationResult.TIME_EXPIRED, result)
    }
    
    @Test
    fun `test time limit - first use (no usage data)`() {
        val rule = createRule(RuleEngine.RuleType.TIME_LIMIT, dailyLimitMinutes = 60)
        
        val result = ruleEngine.evaluate("com.example.app", testTime, rule, null)
        
        assertEquals(RuleEngine.EvaluationResult.ALLOW, result)
    }
    
    @Test
    fun `test time limit - usage from previous day should reset`() {
        val rule = createRule(RuleEngine.RuleType.TIME_LIMIT, dailyLimitMinutes = 60)
        val yesterdayUsage = createUsageData(
            todayMinutes = 120, // Over limit
            dailyResetDate = "2024-01-14" // Yesterday
        )
        
        val result = ruleEngine.evaluate("com.example.app", testTime, rule, yesterdayUsage)
        
        assertEquals(RuleEngine.EvaluationResult.ALLOW, result)
    }
    
    // Time Window Tests
    
    @Test
    fun `test time window - within allowed hours`() {
        val rule = createRule(
            RuleEngine.RuleType.TIME_WINDOW,
            allowedStartTime = LocalTime.of(9, 0),  // 9:00 AM
            allowedEndTime = LocalTime.of(17, 0)    // 5:00 PM
        )
        // Test time is 2:30 PM - should be allowed
        
        val result = ruleEngine.evaluate("com.example.app", testTime, rule, null)
        
        assertEquals(RuleEngine.EvaluationResult.ALLOW, result)
    }
    
    @Test
    fun `test time window - before allowed hours`() {
        val rule = createRule(
            RuleEngine.RuleType.TIME_WINDOW,
            allowedStartTime = LocalTime.of(16, 0),  // 4:00 PM
            allowedEndTime = LocalTime.of(18, 0)     // 6:00 PM
        )
        // Test time is 2:30 PM - should be blocked
        
        val result = ruleEngine.evaluate("com.example.app", testTime, rule, null)
        
        assertEquals(RuleEngine.EvaluationResult.OUTSIDE_ALLOWED_WINDOW, result)
    }
    
    @Test
    fun `test time window - after allowed hours`() {
        val rule = createRule(
            RuleEngine.RuleType.TIME_WINDOW,
            allowedStartTime = LocalTime.of(9, 0),   // 9:00 AM
            allowedEndTime = LocalTime.of(12, 0)     // 12:00 PM
        )
        // Test time is 2:30 PM - should be blocked
        
        val result = ruleEngine.evaluate("com.example.app", testTime, rule, null)
        
        assertEquals(RuleEngine.EvaluationResult.OUTSIDE_ALLOWED_WINDOW, result)
    }
    
    @Test
    fun `test time window - crossing midnight (evening allowed)`() {
        val rule = createRule(
            RuleEngine.RuleType.TIME_WINDOW,
            allowedStartTime = LocalTime.of(22, 0),  // 10:00 PM
            allowedEndTime = LocalTime.of(6, 0)      // 6:00 AM next day
        )
        val eveningTime = LocalDateTime.of(2024, 1, 15, 23, 0) // 11:00 PM
        
        val result = ruleEngine.evaluate("com.example.app", eveningTime, rule, null)
        
        assertEquals(RuleEngine.EvaluationResult.ALLOW, result)
    }
    
    @Test
    fun `test time window - crossing midnight (morning allowed)`() {
        val rule = createRule(
            RuleEngine.RuleType.TIME_WINDOW,
            allowedStartTime = LocalTime.of(22, 0),  // 10:00 PM
            allowedEndTime = LocalTime.of(6, 0)      // 6:00 AM next day
        )
        val morningTime = LocalDateTime.of(2024, 1, 16, 5, 0) // 5:00 AM next day
        
        val result = ruleEngine.evaluate("com.example.app", morningTime, rule, null)
        
        assertEquals(RuleEngine.EvaluationResult.ALLOW, result)
    }
    
    @Test
    fun `test time window - crossing midnight (blocked time)`() {
        val rule = createRule(
            RuleEngine.RuleType.TIME_WINDOW,
            allowedStartTime = LocalTime.of(22, 0),  // 10:00 PM
            allowedEndTime = LocalTime.of(6, 0)      // 6:00 AM next day
        )
        // Test time is 2:30 PM - should be blocked
        
        val result = ruleEngine.evaluate("com.example.app", testTime, rule, null)
        
        assertEquals(RuleEngine.EvaluationResult.OUTSIDE_ALLOWED_WINDOW, result)
    }
    
    // Temporary Approval Tests
    
    @Test
    fun `test active temporary approval overrides block rule`() {
        val rule = createRule(RuleEngine.RuleType.BLOCKED)
        val approval = RuleEngine.TemporaryApproval(
            packageName = "com.example.app",
            approvedAt = testTime.minusMinutes(10), // Approved 10 minutes ago
            durationMinutes = 30, // Valid for 30 minutes
            approvedBy = "parent123"
        )
        
        val result = ruleEngine.evaluate("com.example.app", testTime, rule, null, approval)
        
        assertEquals(RuleEngine.EvaluationResult.TEMPORARY_APPROVAL, result)
    }
    
    @Test
    fun `test expired temporary approval falls back to rule`() {
        val rule = createRule(RuleEngine.RuleType.BLOCKED)
        val approval = RuleEngine.TemporaryApproval(
            packageName = "com.example.app",
            approvedAt = testTime.minusMinutes(45), // Approved 45 minutes ago
            durationMinutes = 30, // Expired 15 minutes ago
            approvedBy = "parent123"
        )
        
        val result = ruleEngine.evaluate("com.example.app", testTime, rule, null, approval)
        
        assertEquals(RuleEngine.EvaluationResult.BLOCK, result)
    }
    
    @Test
    fun `test temporary approval for wrong package falls back to rule`() {
        val rule = createRule(RuleEngine.RuleType.BLOCKED)
        val approval = RuleEngine.TemporaryApproval(
            packageName = "com.different.app", // Different package
            approvedAt = testTime.minusMinutes(10),
            durationMinutes = 30,
            approvedBy = "parent123"
        )
        
        val result = ruleEngine.evaluate("com.example.app", testTime, rule, null, approval)
        
        assertEquals(RuleEngine.EvaluationResult.BLOCK, result)
    }
    
    // Midnight Reset Tests
    
    @Test
    fun `test usage data reset detection`() {
        val todayUsage = createUsageData(dailyResetDate = "2024-01-15")
        val yesterdayUsage = createUsageData(dailyResetDate = "2024-01-14")
        
        assertFalse(ruleEngine.shouldResetUsageData(todayUsage, testTime))
        assertTrue(ruleEngine.shouldResetUsageData(yesterdayUsage, testTime))
    }
    
    @Test
    fun `test get today date string`() {
        val dateString = ruleEngine.getTodayDateString(testTime)
        assertEquals("2024-01-15", dateString)
    }
    
    // Utility Method Tests
    
    @Test
    fun `test get remaining minutes for time limit`() {
        val rule = createRule(RuleEngine.RuleType.TIME_LIMIT, dailyLimitMinutes = 120)
        val usageData = createUsageData(todayMinutes = 60)
        
        val remaining = ruleEngine.getRemainingMinutes(rule, usageData, testTime)
        
        assertEquals(60, remaining)
    }
    
    @Test
    fun `test get remaining minutes - no usage`() {
        val rule = createRule(RuleEngine.RuleType.TIME_LIMIT, dailyLimitMinutes = 120)
        
        val remaining = ruleEngine.getRemainingMinutes(rule, null, testTime)
        
        assertEquals(120, remaining)
    }
    
    @Test
    fun `test get remaining minutes - not time limit rule`() {
        val rule = createRule(RuleEngine.RuleType.ALLOWED)
        val usageData = createUsageData(todayMinutes = 60)
        
        val remaining = ruleEngine.getRemainingMinutes(rule, usageData, testTime)
        
        assertNull(remaining)
    }
    
    @Test
    fun `test get minutes until allowed window opens`() {
        val rule = createRule(
            RuleEngine.RuleType.TIME_WINDOW,
            allowedStartTime = LocalTime.of(16, 0), // 4:00 PM
            allowedEndTime = LocalTime.of(18, 0)
        )
        // Current time is 2:30 PM, so 90 minutes until 4:00 PM
        
        val minutes = ruleEngine.getMinutesUntilAllowed(rule, testTime)
        
        assertEquals(90, minutes)
    }
    
    @Test
    fun `test get minutes until allowed - crosses midnight`() {
        val rule = createRule(
            RuleEngine.RuleType.TIME_WINDOW,
            allowedStartTime = LocalTime.of(6, 0), // 6:00 AM next day
            allowedEndTime = LocalTime.of(18, 0)
        )
        val lateEvening = LocalDateTime.of(2024, 1, 15, 23, 0) // 11:00 PM
        
        val minutes = ruleEngine.getMinutesUntilAllowed(rule, lateEvening)
        
        // 1 hour to midnight + 6 hours = 7 hours = 420 minutes
        assertEquals(420, minutes)
    }
    
    // Offline Operation Tests
    
    @Test
    fun `test offline evaluation with cached rule`() {
        // This test ensures the engine works entirely with local data
        val rule = createRule(RuleEngine.RuleType.TIME_LIMIT, dailyLimitMinutes = 60)
        val usageData = createUsageData(todayMinutes = 30)
        
        val result = ruleEngine.evaluate("com.example.app", testTime, rule, usageData)
        
        assertEquals(RuleEngine.EvaluationResult.ALLOW, result)
        // No network calls made - purely local evaluation
    }
    
    @Test
    fun `test evaluation with stale usage data from different timezone`() {
        // Test that the engine correctly handles date changes due to timezone
        val rule = createRule(RuleEngine.RuleType.TIME_LIMIT, dailyLimitMinutes = 60)
        val staleUsage = createUsageData(
            todayMinutes = 120,
            dailyResetDate = "2024-01-14" // Yesterday in any timezone
        )
        
        val result = ruleEngine.evaluate("com.example.app", testTime, rule, staleUsage)
        
        assertEquals(RuleEngine.EvaluationResult.ALLOW, result)
    }
    
    // Helper Methods
    
    private fun createRule(
        type: RuleEngine.RuleType,
        dailyLimitMinutes: Int? = null,
        allowedStartTime: LocalTime? = null,
        allowedEndTime: LocalTime? = null
    ): RuleEngine.AppRule {
        return RuleEngine.AppRule(
            packageName = "com.example.app",
            type = type,
            dailyLimitMinutes = dailyLimitMinutes,
            allowedStartTime = allowedStartTime,
            allowedEndTime = allowedEndTime,
            createdAt = testTime.minusDays(1),
            updatedAt = testTime.minusHours(1)
        )
    }
    
    private fun createUsageData(
        todayMinutes: Int = 0,
        dailyResetDate: String = "2024-01-15"
    ): RuleEngine.UsageData {
        return RuleEngine.UsageData(
            packageName = "com.example.app",
            todayMinutes = todayMinutes,
            lastUsed = testTime.minusMinutes(30),
            dailyResetDate = dailyResetDate
        )
    }
}