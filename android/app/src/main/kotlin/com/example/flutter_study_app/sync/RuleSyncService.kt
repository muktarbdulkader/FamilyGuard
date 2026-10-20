package com.example.flutter_study_app.sync

import android.content.Context
import com.example.flutter_study_app.database.LocalDatabase
import com.example.flutter_study_app.enforcement.RuleEngine
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
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
    private var requestListener: ListenerRegistration? = null
    
    /** Callback invoked whenever an app's temporary approval is added or updated */
    var onApprovalChanged: ((String) -> Unit)? = null

    /** Callback invoked whenever an app's rule is added or updated */
    var onRuleChanged: ((String, RuleEngine.RuleType) -> Unit)? = null

    // Recreated on every startSync() to avoid the cancelled-scope bug where
    // stopSync() permanently cancels the scope before new listeners are attached.
    private var syncJob = SupervisorJob()
    private var syncScope = CoroutineScope(Dispatchers.IO + syncJob)
    private val ruleSyncMutex = Mutex()
    
    companion object {
        private const val COLLECTION_FAMILIES = "families"
        private const val COLLECTION_CHILDREN = "children"
        private const val COLLECTION_APP_RULES = "apps" // Point to real apps subcollection in Firestore
        private const val COLLECTION_TEMPORARY_APPROVALS = "temporaryApprovals"
    }
    
    /**
     * Start real-time synchronization with Firestore
     */
    fun startSync(familyId: String) {
        // Stop existing Firestore listeners without cancelling the scope we're about to use
        ruleListener?.remove()
        approvalListener?.remove()
        requestListener?.remove()
        ruleListener = null
        approvalListener = null
        requestListener = null

        // Recreate scope so we always have a live scope for snapshot callbacks
        syncJob.cancel()
        syncJob = SupervisorJob()
        syncScope = CoroutineScope(Dispatchers.IO + syncJob)
        
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
                            parseApprovalFromDocument(doc.data ?: emptyMap(), doc.id)
                        } catch (e: Exception) {
                            android.util.Log.e("RuleSyncService", "Error parsing approval: ${doc.id}", e)
                            null
                        }
                    })
                }
            }
        }

        // Also listen for approved requests in families/{familyId}/requests
        val requestsRef = firestore
            .collection(COLLECTION_FAMILIES)
            .document(familyId)
            .collection("requests")
            .whereEqualTo("childId", childId)
            .whereEqualTo("status", "approved")

        requestListener = requestsRef.addSnapshotListener { snapshot, error ->
            if (error != null) {
                android.util.Log.w("RuleSyncService", "Error listening to approved requests", error)
                return@addSnapshotListener
            }

            if (snapshot != null) {
                syncScope.launch {
                    val now = LocalDateTime.now()
                    for (doc in snapshot.documents) {
                        try {
                            val pkg = doc.getString("packageName") ?: continue
                            val grantedMinutes = doc.getLong("grantedMinutes")?.toInt() ?: 30
                            val decidedBy = doc.getString("decidedBy") ?: "parent"
                            val decidedAt = parseDateTimeSafe(doc.get("decidedAt"))
                            val approval = RuleEngine.TemporaryApproval(
                                packageName = pkg,
                                approvedAt = decidedAt,
                                durationMinutes = grantedMinutes,
                                approvedBy = decidedBy
                            )
                            val expiresAtSafe = if (doc.contains("accessExpiresAt")) {
                                parseDateTimeSafe(doc.get("accessExpiresAt"))
                            } else null
                            val isExpired = if (expiresAtSafe != null) {
                                now.isAfter(expiresAtSafe)
                            } else {
                                approval.isExpired(now)
                            }
                            if (!isExpired) {
                                database.insertTemporaryApproval(approval)
                                withContext(Dispatchers.Main) {
                                    onApprovalChanged?.invoke(pkg)
                                }
                                android.util.Log.d("RuleSyncService", "Auto-approved $pkg from requests update ($grantedMinutes min)")
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("RuleSyncService", "Error parsing approved request doc", e)
                        }
                    }
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
        requestListener?.remove()
        ruleListener = null
        approvalListener = null
        requestListener = null
        syncJob.cancel()
        android.util.Log.d("RuleSyncService", "Sync stopped")
    }
    
    /**
     * Sync rules from Firestore to local database
     */
    private suspend fun syncRulesFromFirestore(firestoreRules: List<RuleEngine.AppRule>) = withContext(Dispatchers.IO) {
        ruleSyncMutex.withLock {
            try {
                val localRules = database.getAllRules().associateBy { it.packageName }

                for (firestoreRule in firestoreRules) {
                    val localRule = localRules[firestoreRule.packageName]
                    val isOlder = localRule != null &&
                        (firestoreRule.policyVersion < localRule.policyVersion ||
                            (firestoreRule.policyVersion == localRule.policyVersion &&
                                firestoreRule.updatedAt.isBefore(localRule.updatedAt)))
                    if (isOlder) {
                        android.util.Log.w(
                            "RuleSyncService",
                            "Ignored stale rule snapshot for ${firestoreRule.packageName}"
                        )
                        continue
                    }

                    database.insertOrUpdateRule(firestoreRule)
                    withContext(Dispatchers.Main) {
                        onRuleChanged?.invoke(firestoreRule.packageName, firestoreRule.type)
                    }
                    android.util.Log.d(
                        "RuleSyncService",
                        "Updated rule: ${firestoreRule.packageName} -> ${firestoreRule.type} (v${firestoreRule.policyVersion})"
                    )
                }

                if (firestoreRules.isNotEmpty()) {
                    val firestorePackages = firestoreRules.map { it.packageName }.toSet()
                    for (packageName in localRules.keys) {
                        if (!firestorePackages.contains(packageName)) {
                            database.deleteRule(packageName)
                            android.util.Log.d("RuleSyncService", "Removed stale rule: $packageName")
                        }
                    }
                }

                android.util.Log.d(
                    "RuleSyncService",
                    "Rules sync completed. Updated ${firestoreRules.size} rules"
                )
            } catch (e: Exception) {
                android.util.Log.e("RuleSyncService", "Error syncing rules", e)
            }
        }
    }
    
    /**
     * Sync temporary approvals from Firestore
     */
    private suspend fun syncApprovalsFromFirestore(firestoreApprovals: List<RuleEngine.TemporaryApproval>) = withContext(Dispatchers.IO) {
        try {
            val currentTime = LocalDateTime.now()
            database.replaceTemporaryApprovals(firestoreApprovals, currentTime)

            for (approval in firestoreApprovals) {
                if (!approval.isExpired(currentTime)) {
                    withContext(Dispatchers.Main) {
                        onApprovalChanged?.invoke(approval.packageName)
                    }
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
        val ruleRaw = (data["rule"] as? String) ?: (data["type"] as? String) ?: "ALLOWED"
        val ruleType = when (ruleRaw.lowercase().trim()) {
            "block", "blocked" -> RuleEngine.RuleType.BLOCKED
            "allow", "allowed" -> RuleEngine.RuleType.ALLOWED
            "ask", "ask_parent", "notify", "request" -> RuleEngine.RuleType.ASK_PARENT
            "timelimited", "time_limit", "timelimit" -> RuleEngine.RuleType.TIME_LIMIT
            "timerestricted", "time_window", "timewindow" -> RuleEngine.RuleType.TIME_WINDOW
            else -> try {
                RuleEngine.RuleType.valueOf(ruleRaw.uppercase().trim())
            } catch (e: Exception) {
                RuleEngine.RuleType.ALLOWED
            }
        }

        var allowedStart: LocalTime? = null
        var allowedEnd: LocalTime? = null

        val allowedFromStr = (data["allowedFrom"] as? String) ?: (data["allowedStartTime"] as? String)
        val allowedUntilStr = (data["allowedUntil"] as? String) ?: (data["allowedEndTime"] as? String)
        if (!allowedFromStr.isNullOrEmpty() && allowedFromStr.contains(":")) {
            try { allowedStart = LocalTime.parse(allowedFromStr) } catch (_: Exception) {}
        }
        if (!allowedUntilStr.isNullOrEmpty() && allowedUntilStr.contains(":")) {
            try { allowedEnd = LocalTime.parse(allowedUntilStr) } catch (_: Exception) {}
        }

        val timeWindowMap = data["allowedTimeWindow"] as? Map<*, *>
        if (timeWindowMap != null) {
            val startH = (timeWindowMap["startHour"] as? Number)?.toInt() ?: 0
            val startM = (timeWindowMap["startMinute"] as? Number)?.toInt() ?: 0
            val endH = (timeWindowMap["endHour"] as? Number)?.toInt() ?: 23
            val endM = (timeWindowMap["endMinute"] as? Number)?.toInt() ?: 59
            allowedStart = LocalTime.of(startH, startM)
            allowedEnd = LocalTime.of(endH, endM)
        }

        val limitMinutes = (data["dailyLimitMinutes"] as? Number)?.toInt()
        val bonusDate = data["dailyLimitBonusDate"] as? String
        val bonusMinutes = (data["dailyLimitBonusMinutes"] as? Number)?.toInt() ?: 0
        val effectiveLimitMinutes = if (bonusDate == java.time.LocalDate.now().toString()) {
            (limitMinutes ?: 0) + bonusMinutes
        } else {
            limitMinutes
        }
        val alertThreshold = (data["usageAlertThresholdPercent"] as? Number)
            ?.toInt()?.coerceIn(1, 99) ?: 50
        val policyVersion = (data["policyVersion"] as? Number)?.toLong() ?: 0L
        val createdAt = parseDateTimeSafe(data["createdAt"] ?: data["detectedAt"] ?: data["installedDate"], LocalDateTime.of(2020, 1, 1, 0, 0))
        val updatedAt = parseDateTimeSafe(data["updatedAt"] ?: data["lastUpdated"], createdAt)

        return RuleEngine.AppRule(
            packageName = packageName,
            type = ruleType,
            dailyLimitMinutes = effectiveLimitMinutes,
            allowedStartTime = allowedStart,
            allowedEndTime = allowedEnd,
            createdAt = createdAt,
            updatedAt = updatedAt,
            usageAlertThresholdPercent = alertThreshold,
            policyVersion = policyVersion
        )
    }
    
    /**
     * Parse temporary approval from Firestore document
     */
    private fun parseApprovalFromDocument(data: Map<String, Any>, docId: String = ""): RuleEngine.TemporaryApproval {
        val rawPkg = (data["packageName"] as? String)?.takeIf { it.isNotBlank() }
            ?: (data["package"] as? String)?.takeIf { it.isNotBlank() }
            ?: docId.replace('_', '.')

        val duration = (data["durationMinutes"] as? Number)?.toInt()
            ?: (data["grantedMinutes"] as? Number)?.toInt()
            ?: 30

        return RuleEngine.TemporaryApproval(
            packageName = rawPkg,
            approvedAt = parseDateTimeSafe(data["approvedAt"] ?: data["decidedAt"] ?: data["createdAt"]),
            durationMinutes = duration,
            approvedBy = data["approvedBy"] as? String ?: "parent"
        )
    }
    
    /**
     * Parse time of day from string (HH:MM format)
     */
    private fun parseTimeOfDay(timeString: String): LocalTime {
        return LocalTime.parse(timeString)
    }
    
    /**
     * Safely parse LocalDateTime from Timestamp, Date, String or Number
     */
    private fun parseDateTimeSafe(value: Any?, defaultVal: LocalDateTime = LocalDateTime.now()): LocalDateTime {
        if (value == null) return defaultVal
        return when (value) {
            is com.google.firebase.Timestamp -> {
                val instant = java.time.Instant.ofEpochSecond(value.seconds, value.nanoseconds.toLong())
                LocalDateTime.ofInstant(instant, java.time.ZoneId.systemDefault())
            }
            is java.util.Date -> {
                LocalDateTime.ofInstant(value.toInstant(), java.time.ZoneId.systemDefault())
            }
            is String -> {
                try {
                    LocalDateTime.parse(value, DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                } catch (e: Exception) {
                    try {
                        LocalDateTime.parse(value, DateTimeFormatter.ISO_DATE_TIME)
                    } catch (e2: Exception) {
                        defaultVal
                    }
                }
            }
            is Number -> {
                val instant = java.time.Instant.ofEpochMilli(value.toLong())
                LocalDateTime.ofInstant(instant, java.time.ZoneId.systemDefault())
            }
            else -> defaultVal
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
            val appName = getAppName(packageName)
            val requestsRef = firestore
                .collection(COLLECTION_FAMILIES)
                .document(familyId)
                .collection("requests")
            
            val requestData = hashMapOf(
                "familyId" to familyId,
                "childId" to (childId ?: ""),
                "packageName" to packageName,
                "appName" to appName,
                "status" to "pending",
                "createdAt" to com.google.firebase.Timestamp.now(),
                "expiresAt" to com.google.firebase.Timestamp(java.util.Date(System.currentTimeMillis() + 86400000L)),
                "deviceInfo" to android.os.Build.MODEL,
                "requestNonce" to java.util.UUID.randomUUID().toString()
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