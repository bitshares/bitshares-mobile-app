package com.btsplusplus.fowallet

import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.EBitsharesAccountPasswordLang
import bitshares.LLAYOUT_WARP
import com.btsplusplus.fowallet.utils.kAppBlindAccountBrainKeyCheckSumPrefix
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_new_account_password.*
import org.json.JSONObject

/**
 *  助记词使用场景定义
 */
const val kNewPasswordSceneRegAccount = 0               //  注册新账号（额外参数：账号名）
const val kNewPasswordSceneChangePassowrd = 1           //  修改密码
const val kNewPasswordSceneGenBlindAccountBrainKey = 2  //  生成隐私账号助记词

class ActivityNewAccountPassword : BtsppActivity() {

    private var _currPasswordLang = EBitsharesAccountPasswordLang.ebap_lang_zh
    private var _currPasswordWords = mutableListOf<String>()
    private var _new_account_name: String? = null
    private var _scene = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_new_account_password)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _scene = args.getInt("scene")
        _new_account_name = args.optString("args", null)
        findViewById<TextView>(R.id.title).text = args.getString("title")

        //  初始化数据
        //  REMARK：根据当前语言决定默认密码语言。
        val pass_lang_string = resources.getString(R.string.kEditPasswordDefaultPasswordLang)
        _currPasswordLang = if (pass_lang_string == "zh") {
            EBitsharesAccountPasswordLang.ebap_lang_zh
        } else {
            EBitsharesAccountPasswordLang.ebap_lang_en
        }

        //  初始化新密码
        processGeneratePassword()

        //  UI - 提示信息
        tv_tip_from_new_account_password.text = getCellTipsMessage()

        //  事件 - 切换语言
        tv_toggle_password_lang.setOnClickListener { onTogglePasswordLang() }

        //  事件 - 返回
        layout_back_from_new_account_password.setOnClickListener { finish() }

        //  事件 - 下一步
        btn_next_from_new_account_password.setOnClickListener { onNextButtonClick() }
    }

    /**
     *  (private) 处理密码生成
     */
    private fun processGeneratePassword() {
        var check_sum_prefix: String? = null
        //  REMARK：设置隐私交易中隐私账户助记词校验码前缀。
        if (_scene == kNewPasswordSceneGenBlindAccountBrainKey) {
            check_sum_prefix = kAppBlindAccountBrainKeyCheckSumPrefix
        }
        _currPasswordWords = if (_currPasswordLang == EBitsharesAccountPasswordLang.ebap_lang_zh) {
            WalletManager.randomGenerateChineseWord_N16(check_sum_prefix)
        } else {
            WalletManager.randomGenerateEnglishWord_N32(check_sum_prefix)
        }
        _draw_ui_new_password(_currPasswordWords)
    }

    private fun switchPasswordLangButtonString(): String {
        return if (_currPasswordLang == EBitsharesAccountPasswordLang.ebap_lang_zh) {
            resources.getString(R.string.kEditPasswordSwitchToEnPassword)
        } else {
            resources.getString(R.string.kEditPasswordSwitchToZhPassword)
        }
    }

    private fun getCellTipsMessage(): String {
        val n_chars = if (_currPasswordLang == EBitsharesAccountPasswordLang.ebap_lang_zh) 16 else 32
        return String.format(resources.getString(R.string.kEditPasswordUiSecTips), n_chars.toString())
    }

    private fun _draw_ui_new_password(new_words: MutableList<String>) {
        lyt_new_password_line01.let { line01 ->
            lyt_new_password_line02.let { line02 ->
                line01.removeAllViews()
                line02.removeAllViews()

                val list = if (_currPasswordLang == EBitsharesAccountPasswordLang.ebap_lang_zh) {
                    new_words.toTypedArray()
                } else {
                    val words = arrayListOf<String>()
                    for (i in 0 until 32 step 4) {
                        words.add(new_words.subList(i, i + 4).joinToString(""))
                    }
                    words.toTypedArray()
                }

                assert(list.size % 2 == 0)
                val one_line_words = list.size / 2

                list.forEachIndexed { index, word ->
                    val view = TextView(this).apply {
                        val width = if (_currPasswordLang == EBitsharesAccountPasswordLang.ebap_lang_zh) {
                            0.125f
                        } else {
                            0.25f
                        }
                        layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, width).apply {
                            gravity = Gravity.CENTER
                        }
                        gravity = Gravity.CENTER
                        text = word
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 16.0f)
                        setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    }
                    if (index < one_line_words) {
                        line01.addView(view)
                    } else {
                        line02.addView(view)
                    }
                }
            }
        }
    }

    /**
     *  (private) 事件 - 点击切换密码语言
     */
    private fun onTogglePasswordLang() {
        //  切换
        _currPasswordLang = if (_currPasswordLang == EBitsharesAccountPasswordLang.ebap_lang_zh) {
            EBitsharesAccountPasswordLang.ebap_lang_en
        } else {
            EBitsharesAccountPasswordLang.ebap_lang_zh
        }

        //  刷新切换按钮
        tv_toggle_password_lang.text = switchPasswordLangButtonString()

        //  刷新描述信息
        tv_tip_from_new_account_password.text = getCellTipsMessage()

        //  重新生成密码
        processGeneratePassword()
    }

    /**
     *  (private) 事件 - 点击下一步
     */
    private fun onNextButtonClick() {
        if (_scene == kNewPasswordSceneRegAccount || _scene == kNewPasswordSceneGenBlindAccountBrainKey) {
            val value = resources.getString(R.string.kEditPasswordNextStepAskForReg)
            UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kWarmTips), value).then {
                if (it != null && it as Boolean) {
                    goTo(ActivityNewAccountPasswordConfirm::class.java, true, args = JSONObject().apply {
                        put("current_password", _currPasswordWords.joinToString(""))
                        put("pass_lang", _currPasswordLang)
                        put("args", _new_account_name)
                        put("scene", _scene)
                    })
                }
            }
        } else {
            goTo(ActivityNewAccountPasswordConfirm::class.java, true, args = JSONObject().apply {
                put("current_password", _currPasswordWords.joinToString(""))
                put("pass_lang", _currPasswordLang)
                put("scene", _scene)
            })
        }
    }
}
