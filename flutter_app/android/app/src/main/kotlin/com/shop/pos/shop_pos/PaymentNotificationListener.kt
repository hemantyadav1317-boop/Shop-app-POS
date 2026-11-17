package com.shop.pos.shop_pos

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.util.regex.Pattern

class PaymentNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "BillZoPaymentListener"
        var isConnected: Boolean = false
        var onPaymentDetected: ((Map<String, Any>) -> Unit)? = null

        // Supported package names for Indian UPI & Merchant applications
        private val PAYMENT_PACKAGES = setOf(
            "com.phonepe.app",
            "com.phonepe.merchant",
            "net.one97.paytm",
            "net.one97.paytm.merchant",
            "com.google.android.apps.nbu.paisa.user",
            "com.google.android.apps.nbu.paisa.merchant",
            "in.amazon.mShop.android.shopping",
            "com.bharatpe.app",
            "com.freecharge.android",
            "com.mobikwik_new",
            "com.sbi.upi",
            "com.fss.pnbpsp",
            // SMS messaging apps for bank credit alerts
            "com.google.android.apps.messaging",
            "com.samsung.android.messaging",
            "com.android.mms"
        )

        // Regex for Amount: ₹350, Rs. 350.00, INR 500, etc.
        private val AMOUNT_PATTERN = Pattern.compile(
            """(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)|([\d,]+(?:\.\d{1,2})?)\s*(?:rs\.?|inr|₹|credited|received|प्राप्त|जमा)""",
            Pattern.CASE_INSENSITIVE
        )

        // Regex for UTR / Transaction Reference
        private val UTR_PATTERN = Pattern.compile(
            """(?:utr|ref|rrn|txn\s*(?:id|no)?)\s*[:#\-]?\s*([a-zA-Z0-9]{8,22})""",
            Pattern.CASE_INSENSITIVE
        )
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        isConnected = true
        Log.d(TAG, "✓ BillZo PaymentNotificationListener connected successfully")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        isConnected = false
        Log.d(TAG, "✕ BillZo PaymentNotificationListener disconnected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val pkg = sbn.packageName ?: return
        val isPaymentApp = PAYMENT_PACKAGES.contains(pkg) || pkg.contains("messaging") || pkg.contains("sms")
        if (!isPaymentApp) return

        val extras = sbn.notification?.extras ?: return
        val title = extras.getString(Notification.EXTRA_TITLE, "") ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
        val fullContent = "$title $text $bigText"

        val lower = fullContent.lowercase()

        // Filter: Must indicate money arrived (received / credited / प्राप्त / जमा)
        val isReceived = lower.contains("received") ||
                lower.contains("credited") ||
                lower.contains("प्राप्त") ||
                lower.contains("जमा") ||
                lower.contains("paid you") ||
                lower.contains("sent you") ||
                lower.contains("has paid")

        if (!isReceived) return

        // Extract amount
        val amountMatcher = AMOUNT_PATTERN.matcher(fullContent)
        var amount: Double? = null
        if (amountMatcher.find()) {
            val raw1 = amountMatcher.group(1)
            val raw2 = amountMatcher.group(2)
            val raw = raw1 ?: raw2
            if (raw != null) {
                amount = raw.replace(",", "").toDoubleOrNull()
            }
        }

        if (amount == null || amount <= 0.0) return

        // Extract UTR if present
        var utr = ""
        val utrMatcher = UTR_PATTERN.matcher(fullContent)
        if (utrMatcher.find()) {
            utr = utrMatcher.group(1) ?: ""
        }

        val appName = when {
            pkg.contains("phonepe") -> "PhonePe"
            pkg.contains("paytm") -> "Paytm"
            pkg.contains("paisa") || pkg.contains("google") -> "Google Pay"
            pkg.contains("bharatpe") -> "BharatPe"
            else -> "Bank SMS"
        }

        val payload = mapOf(
            "amount" to amount,
            "appName" to appName,
            "packageName" to pkg,
            "title" to title,
            "text" to text,
            "utr" to utr,
            "timestamp" to System.currentTimeMillis()
        )

        Log.d(TAG, "⚡ Payment Verified from $appName: ₹$amount (UTR: $utr)")
        onPaymentDetected?.invoke(payload)
    }
}
