package com.securebankkit.flutter_security_suite.handlers

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys

/**
 * Encrypted key-value storage backed by EncryptedSharedPreferences.
 */
class SecureStorageHandler {

    companion object {
        private const val PREFS_NAME = "secure_bank_kit_prefs"
    }

    private fun getPrefs(context: Context): SharedPreferences {
        val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
        return EncryptedSharedPreferences.create(
            PREFS_NAME,
            masterKeyAlias,
            context,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
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
