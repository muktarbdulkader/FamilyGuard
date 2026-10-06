package com.example.flutter_study_app.database

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.example.flutter_study_app.enforcement.RuleEngine
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.time.LocalDateTime
import java.time.LocalTime

/**
 * Unit tests for LocalDatabase operations
 * Uses Robolectric for Android context simulation
 */
@RunWith(RobolectricTestRunner::class)
class LocalDatabaseTest {
    
    private lateinit var database: LocalDatabase
    private lateinit var context: Context
    
    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        database = LocalDatabase.getInstance(context)
        
        // Clear any existing data
        clearDatabase()
    }
    
    @After
    fun tearDown() {
        clearDatabase()
    }
    
    private fun clearDatabase() {
        // Clear all tables for clean tests
        val db = database.writableDatabase
        db.execSQL("DELETE FROM app_rules")
        db.execSQL("DELETE FROM app_usage")
        db.execSQL("DELETE FROM temporary_approvals")
    }
    
    // Rule Management Tests
    
    @Test
    fun `insertOrUpdateRule should store rule correctly`() {
        val rule = createTestRule()
        
        val success = database.insertOrUpdateRule(rule)
        
        assertTrue(success)
        
        val retrievedRule = database.getRule("com.test.app")
        assertNotNull(retrievedRule)
        assertEquals(rule.packageName, retrievedRule?.packageName)
        assertEquals(rule.type, retrievedRule?.type)
        assertEquals(rule.dailyLimitMinutes, retrievedRule?.dailyLimitMinutes)
    }
    
    @Test
    fun `getRule should return null for non-existent package`() {
        val rule = database.getRule("com.nonexistent.app")
        
        assertNull(rule)
    }
    
    @Test
    fun `updateRule should overwrite existing rule`() {
        val originalRule = createTestRule(RuleEngine.RuleType.ALLOWED)
        database.insertOrUpdateRule(originalRule)
        
        val updatedRule = createTestRule(RuleEngine.RuleType.BLOCKED)
        database.insertOrUpdateRule(updatedRule)
        
        val retrievedRule = database.getRule("com.test.app")
        assertEquals(RuleEngine.RuleType.BLOCKED, retrievedRule?.type)
    }
    
    @Test
    fun `getAllRules should return all stored rules`() {
        val rule1 = createTestRule("com.test.app1", RuleEngine.RuleType.ALLOWED)
        val rule2 = createTestRule("com.test.app2", RuleEngine.RuleType.BLOCKED)
        val rule3 = createTestRule("com.test.app3", RuleEngine.RuleType.TIME_LIMIT, dailyLimit = 60)
        
        database.insertOrUpdateRule(rule1)
        database.insertOrUpdateRule(rule2)
        database.insertOrUpdateRule(rule3)
        
        val allRules = database.getAllRules()
        
        assertEquals(3, allRules.size)
        assertTrue(allRules.any { it.packageName == "com.test.app1" })
        assertTrue(allRules.any { it.packageName == "com.test.app2" })
        assertTrue(allRules.any { it.packageName == "com.test.app3" })
    }
    
    @Test
    fun `deleteRule should remove rule from database`() {
        val rule = createTestRule()
        database.insertOrUpdateRule(rule)
        
        val deleteSuccess = database.deleteRule("com.test.app")
        
        assertTrue(deleteSuccess)
        assertNull(database.getRule("com.test.app"))
    }
    
    @Test
    fun `timeWindow rules should store start and end times correctly`() {
        val rule = createTestRule(
            type = RuleEngine.RuleType.TIME_WINDOW,
            startTime = LocalTime.of(9, 0),
            endTime = LocalTime.of(17, 30)
        )
        
        database.insertOrUpdateRule(rule)
        
        val retrievedRule = database.getRule("com.test.app")
        assertEquals(LocalTime.of(9, 0), retrievedRule?.allowedStartTime)
        assertEquals(LocalTime.of(17, 30), retrievedRule?.allowedEndTime)
    }
    
    // Usage Tracking Tests
    
    @Test
    fun `insertOrUpdateUsage should store usage data correctly`() {
        val usage = createTestUsage()
        
        val success = database.insertOrUpdateUsage(usage)
        
        assertTrue(success)
        
        val retrievedUsage = database.getUsage("com.test.app")
        assertNotNull(retrievedUsage)
        assertEquals(usage.packageName, retrievedUsage?.packageName)
        assertEquals(usage.todayMinutes, retrievedUsage?.todayMinutes)
        assertEquals(usage.dailyResetDate, retrievedUsage?.dailyResetDate)
    }
    
    @Test
    fun `incrementUsageMinutes should add to existing usage`() {
        val currentTime = LocalDateTime.now()
        val today = currentTime.toLocalDate().toString()
        
        // Create initial usage
        database.incrementUsageMinutes("com.test.app", 30, currentTime)
        
        // Increment usage
        database.incrementUsageMinutes("com.test.app", 25, currentTime)
        
        val usage = database.getUsage("com.test.app")
        assertEquals(55, usage?.todayMinutes)
        assertEquals(today, usage?.dailyResetDate)
    }
    
    @Test
    fun `incrementUsageMinutes should create new record for different date`() {
        val yesterday = LocalDateTime.now().minusDays(1)
        val today = LocalDateTime.now()
        
        // Create usage for yesterday
        database.incrementUsageMinutes("com.test.app", 120, yesterday)
        
        // Add usage for today (should reset)
        database.incrementUsageMinutes("com.test.app", 30, today)
        
        val usage = database.getUsage("com.test.app")
        assertEquals(30, usage?.todayMinutes) // Should be reset for new day
        assertEquals(today.toLocalDate().toString(), usage?.dailyResetDate)
    }
    
    @Test
    fun `resetUsageForDate should reset usage to zero`() {
        val usage = createTestUsage(todayMinutes = 120)
        database.insertOrUpdateUsage(usage)
        
        database.resetUsageForDate("com.test.app", "2024-01-15")
        
        val resetUsage = database.getUsage("com.test.app")
        assertEquals(0, resetUsage?.todayMinutes)
        assertEquals("2024-01-15", resetUsage?.dailyResetDate)
    }
    
    @Test
    fun `getAllUsageData should return usage map`() {
        val usage1 = createTestUsage("com.app1", 60)
        val usage2 = createTestUsage("com.app2", 120)
        
        database.insertOrUpdateUsage(usage1)
        database.insertOrUpdateUsage(usage2)
        
        val usageMap = database.getAllUsageData()
        
        assertEquals(2, usageMap.size)
        assertEquals(60, usageMap["com.app1"]?.todayMinutes)
        assertEquals(120, usageMap["com.app2"]?.todayMinutes)
    }
    
    // Temporary Approval Tests
    
    @Test
    fun `insertTemporaryApproval should store approval correctly`() {
        val approval = createTestApproval()
        
        val success = database.insertTemporaryApproval(approval)
        
        assertTrue(success)
        
        val retrievedApproval = database.getActiveTemporaryApproval("com.test.app")
        assertNotNull(retrievedApproval)
        assertEquals(approval.packageName, retrievedApproval?.packageName)
        assertEquals(approval.durationMinutes, retrievedApproval?.durationMinutes)
        assertEquals(approval.approvedBy, retrievedApproval?.approvedBy)
    }
    
    @Test
    fun `getActiveTemporaryApproval should return null for non-existent approval`() {
        val approval = database.getActiveTemporaryApproval("com.nonexistent.app")
        
        assertNull(approval)
    }
    
    @Test
    fun `expireTemporaryApproval should deactivate approval`() {
        val approval = createTestApproval()
        database.insertTemporaryApproval(approval)
        
        database.expireTemporaryApproval("com.test.app")
        
        val expiredApproval = database.getActiveTemporaryApproval("com.test.app")
        assertNull(expiredApproval)
    }
    
    @Test
    fun `cleanupExpiredApprovals should remove old approvals`() {
        val oldApproval = createTestApproval(
            approvedAt = LocalDateTime.now().minusHours(25) // 25 hours ago
        )
        val recentApproval = createTestApproval(
            packageName = "com.recent.app",
            approvedAt = LocalDateTime.now().minusMinutes(30) // 30 minutes ago
        )
        
        database.insertTemporaryApproval(oldApproval)
        database.insertTemporaryApproval(recentApproval)
        
        database.cleanupExpiredApprovals(LocalDateTime.now())
        
        // Old approval should be deleted
        assertNull(database.getActiveTemporaryApproval("com.test.app"))
        
        // Recent approval should still exist
        assertNotNull(database.getActiveTemporaryApproval("com.recent.app"))
    }
    
    // Helper Methods
    
    private fun createTestRule(
        packageName: String = "com.test.app",
        type: RuleEngine.RuleType = RuleEngine.RuleType.ALLOWED,
        dailyLimit: Int? = null,
        startTime: LocalTime? = null,
        endTime: LocalTime? = null
    ): RuleEngine.AppRule {
        return RuleEngine.AppRule(
            packageName = packageName,
            type = type,
            dailyLimitMinutes = dailyLimit,
            allowedStartTime = startTime,
            allowedEndTime = endTime,
            createdAt = LocalDateTime.now().minusHours(1),
            updatedAt = LocalDateTime.now()
        )
    }
    
    private fun createTestUsage(
        packageName: String = "com.test.app",
        todayMinutes: Int = 60,
        resetDate: String = "2024-01-15"
    ): RuleEngine.UsageData {
        return RuleEngine.UsageData(
            packageName = packageName,
            todayMinutes = todayMinutes,
            lastUsed = LocalDateTime.now().minusMinutes(10),
            dailyResetDate = resetDate
        )
    }
    
    private fun createTestApproval(
        packageName: String = "com.test.app",
        approvedAt: LocalDateTime = LocalDateTime.now().minusMinutes(5)
    ): RuleEngine.TemporaryApproval {
        return RuleEngine.TemporaryApproval(
            packageName = packageName,
            approvedAt = approvedAt,
            durationMinutes = 30,
            approvedBy = "parent123"
        )
    }
}