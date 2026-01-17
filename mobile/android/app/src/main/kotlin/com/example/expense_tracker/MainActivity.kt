package com.example.expense_tracker

import android.Manifest
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.*

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.expense_tracker/sms"
    private val SMS_PERMISSION_CODE = 100

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSmsPermission" -> {
                    val hasPermission = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.READ_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(hasPermission)
                }
                "requestSmsPermission" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) 
                        != PackageManager.PERMISSION_GRANTED) {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.READ_SMS),
                            SMS_PERMISSION_CODE
                        )
                        result.success(false)
                    } else {
                        result.success(true)
                    }
                }
                "getBankingSms" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) 
                        == PackageManager.PERMISSION_GRANTED) {
                        val messages = getBankingSmsMessages()
                        result.success(messages)
                    } else {
                        result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getBankingSmsMessages(): List<Map<String, String>> {
        val messages = mutableListOf<Map<String, String>>()
        
        // Các từ khóa ngân hàng phổ biến
        val bankKeywords = listOf(
            "VCB", "Vietcombank", "TCB", "Techcombank", "MB", "MBBank",
            "ACB", "VPBank", "BIDV", "Agribank", "TPBank", "VIB",
            "Sacombank", "HDBank", "OCB", "MSB", "SHB", "Eximbank",
            "GD:", "giao dich", "so du", "SD:", "TK:", "tai khoan"
        )

        try {
            val uri = Uri.parse("content://sms/inbox")
            val cursor: Cursor? = contentResolver.query(
                uri,
                arrayOf("_id", "address", "body", "date"),
                null,
                null,
                "date DESC"
            )

            cursor?.use {
                val bodyIndex = it.getColumnIndex("body")
                val addressIndex = it.getColumnIndex("address")
                val dateIndex = it.getColumnIndex("date")

                var count = 0
                while (it.moveToNext() && count < 100) {
                    val body = it.getString(bodyIndex) ?: ""
                    val address = it.getString(addressIndex) ?: ""
                    val dateMillis = it.getLong(dateIndex)

                    // Kiểm tra xem có phải SMS ngân hàng không
                    val isBankingSms = bankKeywords.any { keyword ->
                        body.contains(keyword, ignoreCase = true) ||
                        address.contains(keyword, ignoreCase = true)
                    }

                    if (isBankingSms) {
                        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                        val date = dateFormat.format(Date(dateMillis))

                        messages.add(mapOf(
                            "sender" to address,
                            "body" to body,
                            "date" to date
                        ))
                        count++
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return messages
    }
}
