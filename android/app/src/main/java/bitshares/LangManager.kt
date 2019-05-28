package bitshares

import android.annotation.TargetApi
import android.content.Context
import android.os.Build
import android.os.LocaleList
import android.preference.PreferenceManager
import com.btsplusplus.fowallet.R
import org.json.JSONArray
import org.json.JSONObject
import java.util.*

const val kCurrentLanguageKey = "kCurrentLanguageKey"

class LangManager {

    companion object {

        private var _spInstanceLangManager = LangManager()

        fun sharedLangManager(): LangManager {
            return _spInstanceLangManager
        }
    }

    var data_array = JSONArray()
    var currLangCode: String = ""

    constructor() {
        data_array.put(JSONObject().apply {
            put("langNameKey", R.string.kLangKeyZhSimple)
            put("langCode", "zh-Hans")
            put("langLocale", Locale.SIMPLIFIED_CHINESE)
        })
        data_array.put(JSONObject().apply {
            put("langNameKey", R.string.kLangKeyEn)
            put("langCode", "en")
            put("langLocale", Locale.ENGLISH)
        })
        data_array.put(JSONObject().apply {
            put("langNameKey", R.string.kLangKeyJa)
            put("langCode", "ja")
            put("langLocale", Locale.JAPANESE)
        })
    }

    fun onAttach(ctx: Context): Context {
        return _onAttach(ctx, _getCurrentLanguageCode(ctx))
    }

    /**
     * change language
     */
    fun setLocale(ctx: Context, langCode: String, save: Boolean): Context {
        if (save) {
            _saveLangCode(ctx, langCode)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            return _updateResources(ctx, langCode)
        }

        return _updateResourcesLegacy(ctx, langCode)
    }

    /**
     * get current language display name
     */
    fun getCurrentLanguageName(ctx: Context): String {
        for (langInfo in data_array.forin<JSONObject>()) {
            if (langInfo!!.getString("langCode") == this.currLangCode) {
                return langInfo.getInt("langNameKey").xmlstring(ctx)
            }
        }
        return ""
    }

    private fun _getCurrentLanguageCode(ctx: Context): String {
        if (this.currLangCode.isEmpty()) {
            var currentLanguage = PreferenceManager.getDefaultSharedPreferences(ctx).getString(kCurrentLanguageKey, null)
            if (currentLanguage == null) {
                //  default lang is english
                currentLanguage = "en"
                val localeLang = Locale.getDefault().language
                if (localeLang != null) {
                    if (localeLang.toLowerCase().indexOf("zh") == 0) {
                        currentLanguage = "zh-Hans"
                    } else if (localeLang.toLowerCase().indexOf("ja") == 0) {
                        currentLanguage = "ja"
                    }
                }
                PreferenceManager.getDefaultSharedPreferences(ctx).edit().putString(kCurrentLanguageKey, currentLanguage).apply()
            }
            this.currLangCode = currentLanguage as String
        }
        return this.currLangCode
    }

    private fun _saveLangCode(ctx: Context, langCode: String) {
        this.currLangCode = langCode
        PreferenceManager.getDefaultSharedPreferences(ctx).edit().putString(kCurrentLanguageKey, langCode).apply()
    }

    private fun _getLocalByLangCode(langCode: String): Locale {
        for (langInfo in data_array.forin<JSONObject>()) {
            if (langInfo!!.getString("langCode") == langCode) {
                return langInfo.get("langLocale") as Locale
            }
        }
        return Locale.ENGLISH
    }

    private fun _onAttach(ctx: Context, langCode: String): Context {
        return setLocale(ctx, langCode, false)
    }

    /**
     * only for android 7.0+
     */
    @TargetApi(Build.VERSION_CODES.N)
    private fun _updateResources(ctx: Context, langCode: String): Context {
        val locale = _getLocalByLangCode(langCode)
        Locale.setDefault(locale)

        val configuration = ctx.resources.configuration
        configuration.setLocale(locale)
        configuration.locales = LocaleList(locale)
        configuration.setLayoutDirection(locale)

        return ctx.createConfigurationContext(configuration)
    }

    @SuppressWarnings("deprecation")
    private fun _updateResourcesLegacy(ctx: Context, langCode: String): Context {
        val locale = _getLocalByLangCode(langCode)
        Locale.setDefault(locale)

        val resources = ctx.resources

        val configuration = resources.configuration
        configuration.setLocale(locale)
        configuration.setLayoutDirection(locale)

        resources.updateConfiguration(configuration, resources.displayMetrics)

        return ctx
    }
}