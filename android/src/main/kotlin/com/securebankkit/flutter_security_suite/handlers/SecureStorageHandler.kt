package com.securebankkit.flutter_security_suite.handlers

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Encrypted key-value storage backed by EncryptedSharedPreferences.
 *
 * The [EncryptedSharedPreferences] instance is created once and cached
 * in a thread-safe singleton to avoid the cost of repeated key-store access.
 */
class SecureStorageHandler {

    companion object {
        private const val PREFS_NAME = "secure_bank_kit_prefs"

        @Volatile
        private var prefs: SharedPreferences? = null
        private val lock = Any()

        private fun getPrefs(context: Context): SharedPreferences {
            return prefs ?: synchronized(lock) {
                prefs ?: run {
                    val masterKey = MasterKey.Builder(context.applicationContext)
                        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                        .build()
                    EncryptedSharedPreferences.create(
                        context.applicationContext,
                        PREFS_NAME,
                        masterKey,
                        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
                    ).also { prefs = it }
                }
            }
        }
    }

    fun write(context: Context, key: String, value: String) {
        getPrefs(context).edit().putString(key, value).apply()
    }

    fun read(context: Context, key: String): String? {
        return getPrefs(context).getString(key, null)
    }

    fun delete(context: Context, key: String) {
        getPrefs(context).edit().remove(key).apply()
    }

    fun deleteAll(context: Context) {
        getPrefs(context).edit().clear().apply()
    }
}
