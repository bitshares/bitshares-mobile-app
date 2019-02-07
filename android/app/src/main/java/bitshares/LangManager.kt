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
    }

    private fun getCurrentLanguageCode(ctx: Context):String {
        if (this.currLangCode.isEmpty()){
            var currentLanguage = PreferenceManager.getDefaultSharedPreferences(ctx).getString(kCurrentLanguageKey, null)
            if (currentLanguage == null){
                //  default lang is english
                currentLanguage = "en"
                val localeLang = Locale.getDefault().language
                if (localeLang != null && localeLang.toLowerCase().indexOf("zh") == 0){
                    currentLanguage = "zh-Hans"
                }
                PreferenceManager.getDefaultSharedPreferences(ctx).edit().putString(kCurrentLanguageKey, currentLanguage).apply()
            }
            this.currLangCode = currentLanguage as String
        }
        return this.currLangCode
    }

    fun saveLangCode(ctx: Context, langCode: String) {
        this.currLangCode = langCode
        PreferenceManager.getDefaultSharedPreferences(ctx).edit().putString(kCurrentLanguageKey, langCode).apply()
    }

    fun getCurrentLanguageName(ctx: Context): String {
        for (langInfo in data_array.forin<JSONObject>()){
            if (langInfo!!.getString("langCode") == this.currLangCode){
                return langInfo.getInt("langNameKey").xmlstring(ctx)
            }
        }
        return ""
    }

    private fun getLocalByLangCode(langCode: String):Locale{
        for (langInfo in data_array.forin<JSONObject>()){
            if (langInfo!!.getString("langCode") == langCode){
                return langInfo.get("langLocale") as Locale
            }
        }
        return Locale.ENGLISH
    }

    @SuppressWarnings("deprecation")
    fun changeLocalLanguage(ctx: Context, nullableLangCode: String? = null){
        val langCode = nullableLangCode ?: getCurrentLanguageCode(ctx)
        val resources = ctx.resources
        val configuration = resources.configuration

        //  app locale
        val locale = getLocalByLangCode(langCode)
        configuration.setLocale(locale)

        //  updateConfiguration
        val dm = resources.displayMetrics
        resources.updateConfiguration(configuration, dm)
    }

    fun getAttachBaseContext(ctx: Context, nullableLangCode: String? = null):Context{
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N){
            return updateResources(ctx, nullableLangCode ?: getCurrentLanguageCode(ctx))
        }else{
            return ctx
        }
    }

    /**
     * only for android 7.0+
     */
    @TargetApi(Build.VERSION_CODES.N)
    private fun updateResources(ctx: Context, langCode: String):Context{
        val resources = ctx.resources
        val locale = getLocalByLangCode(langCode)

        val configuration = resources.configuration
        configuration.setLocale(locale)
        configuration.locales =  LocaleList(locale)
        return ctx.createConfigurationContext(configuration)
    }
}