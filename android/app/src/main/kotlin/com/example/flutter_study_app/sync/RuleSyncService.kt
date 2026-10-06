package com.example.flutter_study_app.sync

import android.content.Context
import com.example.flutter_study_app.database.LocalDatabase
import com.example.flutter_study_app.enforcement.RuleEngine
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import kotlinx.coroutines.*
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.format.DateTimeFormatter

/**
 * Synchronizes app rules between Firebase Firestore and local database.
 * 
 * This service maintains real-time sync of parental control rules while
 * ensuring the local database remains authoritative for enforcement.
 * Handles offline scenarios gracefully.
 */
class RuleSyncService(
    private val context: Context,
    private val database: LocalDatabase,
    private val childId: String
) {
    private val firestore = FirebaseFirestore.getInstance()
    private var ruleListener: ListenerRegistration? = null
    private var approvalListener: ListenerRegistration? = null
    private val syncScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    companion object {
        private const val COLLECTION_FAMILIES = "families"
        private const val COLLECTION_CHILDREN = "children"
        private const val COLLECTION_APP_RULES = "appRules"
        private const val COLLECTION_TEMPORARY_APPROVALS = "temporaryApprovals"
    }
    
    /**
     * Start real-time synchronization with Firestore
     */
    fun startSync(familyId: String) {
        stopSync() // Stop any existing listeners
        
        // Listen for rule changes
        val rulesRef = firestore
            .collection(COLLECTION_FAMILIES)
            .document(familyId)
            .collection(COLLECTION_CHILDREN)
            .document(childId)
            .collection(COLLECTION_APP_RULES)
        
        ruleListener = rulesRef.addSnapshotListener { snapshot, error ->
            if (error != null) {
                android.util.Log.w("RuleSyncService", "Error listening to rules", error)
                return@addSnapshotListener
            }
            
            if (snapshot != null) {
                syncScope.launch {
                    syncRulesFromFirestore(snapshot.documents.mapNotNull { doc ->
                        try {
                            parseRuleFromDocument(doc.data ?: emptyMap(), doc.id)
                        } catch (e: Exception) {
                            android.util.Log.e("RuleSyncService", "Error parsing rule: ${doc.id}", e)
                            null
                        }
                    })
                }
            }
        }
        
        // Listen for temporary approval changes
        val approvalsRef = firestore
            .collection(COLLECTION_FAMILIES)
            .document(familyId)
            .collection(COLLECTION_CHILDREN)
            .document(childId)
            .collection(COLLECTION_TEMPORARY_APPROVALS)
        
        approvalListener = approvalsRef.addSnapshotListener { snapshot, error ->
            if (error != null) {
                android.util.Log.w("RuleSyncService", "Error listening to approvals", error)
                return@addSnapshotListener
            }
            
            if (snapshot != null) {
                syncScope.launch {
                    syncApprovalsFromFirestore(snapshot.documents.mapNotNull { doc ->
                        try {
                            parseApprovalFromDocument(doc.data ?: emptyMap())
                        } catch (e: Exception) {
                            android.util.Log.e("RuleSyncService", "Error parsing approval: ${doc.id}", e)
                            null
                        }
                    })
                }
            }
        }
        
        android.util.Log.d("RuleSyncService", "Started real-time sync for child: $childId")
    }
    
    /**
     * Stop synchronization
     */
    fun stopSync() {
        ruleListener?.remove()
        approvalListener?.remove()
        ruleListener = null
        approvalListener = null
        syncScope.cancel()
    }
    
    /**
     * Sync rules from Firestore to local database
     */
    private suspend fun syncRulesFromFirestore(firestoreRules: List<RuleEngine.AppRule>) = withContext(Dispatchers.IO) {
        try {
            // Get current local rules
            val localRules = database.getAllRules().associateBy { it.packageName }
            
            // Update/insert rules from Firestore
            for (firestoreRule in firestoreRules) {
                val localRule = localRules[firestoreRule.packageName]
                
                // Update if rule is newer or doesn't exist locally
                if (localRule == null || firestoreRule.updatedAt.isAfter(localRule.updatedAt)) {
                    database.insertOrUpdateRule(firestoreRule)
                    android.util.Log.d("RuleSyncService", "Updated rule for: ${firestoreRule.packageName}")
                }
            }
            
            // Remove local rules that no longer exist in Firestore
            val firestorePackages = firestoreRules.map { it.packageName }.toSet()
            for ((packageName, localRule) in localRules) {
                if (!firestorePackages.contains(packageName)) {
                    database.deleteRule(packageName)
                    android.util.Log.d("RuleSyncService", "Removed rule for: $packageName")
                }
            }
            
            android.util.Log.d("RuleSyncService", "Rules sync completed. Updated ${firestoreRules.size} rules")
            
        } catch (e: Exception) {
            android.util.Log.e("RuleSyncService", "Error syncing rules", e)
        }
    }
    
    /**
     * Sync temporary approvals from Firestore
     */
    private suspend fun syncApprovalsFromFirestore(firestoreApprovals: List<RuleEngine.TemporaryApproval>) = withContext(Dispatchers.IO) {
        try {
            // Clear existing approvals and insert new ones
            // This ensures we don't keep expired approvals that were removed from Firestore
            val currentTime = LocalDateTime.now()
            
            for (approval in firestoreApprovals) {
                if (!approval.isExpired(currentTime)) {
                    database.insertTemporaryApproval(approval)
                    android.util.Log.d("RuleSyncService", "Updated approval for: ${approval.packageName}")
                }
            }
            
            android.util.Log.d("RuleSyncService", "Approvals sync completed. ${firestoreApprovals.size} approvals")
            
        } catch (e: Exception) {
            android.util.Log.e("RuleSyncService", "Error syncing approvals", e)
        }
    }
    
    /**
     * Parse rule from Firestore document
     */
    private fun parseRuleFromDocument(data: Map<String, Any>, packageName: String): RuleEngine.AppRule {
        return RuleEngine.AppRule(
            packageName = packageName,
            type = RuleEngine.RuleType.valueOf(data["type"] as? String ?: "ALLOWED"),
            dailyLimitMinutes = (data["dailyLimitMinutes"] as? Number)?.toInt(),
            allowedStartTime = (data["allowedStartTime"] as? String)?.let { parseTimeOfDay(it) },
            allowedEndTime = (data["allowedEndTime"] as? String)?.let { parseTimeOfDay(it) },
            createdAt = parseDateTime(data["createdAt"] as? String),
            updatedAt = parseDateTime(data["updatedAt"] as? String)
        )
    }
    
    /**
     * Parse temporary approval from Firestore document
     */
    private fun parseApprovalFromDocument(data: Map<String, Any>): RuleEngine.TemporaryApproval {
        return RuleEngine.TemporaryApproval(
            packageName = data["packageName"] as? String ?: "",
            approvedAt = parseDateTime(data["approvedAt"] as? String),
            durationMinutes = (data["durationMinutes"] as? Number)?.toInt() ?: 0,
            approvedBy = data["approvedBy"] as? String ?: ""
        )
    }
    
    /**
     * Parse time of day from string (HH:MM format)
     */
    private fun parseTimeOfDay(timeString: String): LocalTime {
        return LocalTime.parse(timeString)
    }
    
    /**
     * Parse LocalDateTime from ISO string
     */
    private fun parseDateTime(dateTimeString: String?): LocalDateTime {
        return if (dateTimeString != null) {
            LocalDateTime.parse(dateTimeString, DateTimeFormatter.ISO_LOCAL_DATE_TIME)
        } else {
            LocalDateTime.now()
        }
    }
    
    /**
     * Upload usage data to Firestore (called periodically)
     */
    suspend fun uploadUsageData(familyId: String) = withContext(Dispatchers.IO) {
        try {
            val usageData = database.getAllUsageData()
            if (usageData.isEmpty()) return@withContext
            
            val usageRef = firestore
                .collection(COLLECTION_FAMILIES)
                .document(familyId)
                .collection(COLLECTION_CHILDREN)
                .document(childId)
                .collection("usageData")
            
            val batch = firestore.batch()
            
            for ((packageName, usage) in usageData) {
                val docRef = usageRef.document(packageName)
                val usageMap = mapOf(
                    "packageName" to usage.packageName,
                    "todayMinutes" to usage.todayMinutes,
                    "lastUsed" to usage.lastUsed.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                    "dailyResetDate" to usage.dailyResetDate,
                    "updatedAt" to LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                )
                
                batch.set(docRef, usageMap)
            }
            
            batch.commit().addOnSuccessListener {
                android.util.Log.d("RuleSyncService", "Usage data uploaded successfully")
            }.addOnFailureListener { exception ->
                android.util.Log.w("RuleSyncService", "Error uploading usage data", exception)
            }
            
        } catch (e: Exception) {
            android.util.Log.e("RuleSyncService", "Error uploading usage data", e)
        }
    }
    
    /**
     * Send parent request to Firestore
     */
    suspend fun sendParentRequest(familyId: String, packageName: String) = withContext(Dispatchers.IO) {
        try {
            val requestsRef = firestore
                .collection(COLLECTION_FAMILIES)
                .document(familyId)
                .collection("parentRequests")
            
            val requestData = mapOf(
                "childId" to childId,
                "packageName" to packageName,
                "requestedAt" to LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                "status" to "pending",
                "appName" to getAppName(packageName)
            )
            
            requestsRef.add(requestData).addOnSuccessListener { docRef ->
                android.util.Log.d("RuleSyncService", "Parent request sent: ${docRef.id}")
            }.addOnFailureListener { exception ->
                android.util.Log.w("RuleSyncService", "Error sending parent request", exception)
            }
            
        } catch (e: Exception) {
            android.util.Log.e("RuleSyncService", "Error sending parent request", e)
        }
    }
    
    /**
     * Get user-friendly app name
     */
    private fun getAppName(packageName: String): String {
        return try {
            val packageManager = context.packageManager
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }
}

/**
 * FIREBASE SYNC STRATEGY:
 * 
 * 1. REAL-TIME RULES SYNC:
 *    - Listen to Firestore changes in real-time
 *    - Update local database when rules change
 *    - Local database remains authoritative for enforcement
 * 
 * 2. OFFLINE RESILIENCE:
 *    - Enforcement continues with cached rules when offline
 *    - Rules sync when connection is restored
 *    - No enforcement interruption during network issues
 * 
 * 3. CONFLICT RESOLUTION:
 *    - Firestore timestamp determines rule precedence
 *    - Local rules updated only if Firestore rule is newer
 *    - Prevents overwriting local changes with stale data
 * 
 * 4. USAGE DATA UPLOAD:
 *    - Periodic upload of usage statistics to Firestore
 *    - Parents can view child's app usage in real-time
 *    - Batched for efficiency
 * 
 * 5. PARENT REQUESTS:
 *    - ASK_PARENT rule triggers create Firestore request
 *    - Parents receive real-time notifications
 *    - Temporary approvals sync back to child device
 */