package com.btsplusplus.fowallet

import android.os.Bundle
import android.support.design.widget.TabLayout
import android.support.v4.app.Fragment
import android.support.v4.view.ViewPager
import android.view.View
import android.view.animation.OvershootInterpolator
import android.widget.Button
import bitshares.Promise
import kotlinx.android.synthetic.main.activity_login.*
import org.json.JSONObject
import java.lang.reflect.Field

class ActivityLogin : BtsppActivity() {

    private val fragmens: ArrayList<Fragment> = ArrayList()
    private var tablayout: TabLayout? = null
    private var view_pager: ViewPager? = null
    private var _checkActivePermission = true
    private var _result_promise: Promise? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_login)

        //  读取参数
        val args = _btspp_params as? JSONObject
        if (args != null) {
            _checkActivePermission = args.getBoolean("checkActivePermission")
            _result_promise = args.get("result_promise") as Promise
        }

        setFullScreen()

        //  事件 - 返回按钮
        layout_back_from_login.setOnClickListener { onBackClicked(false) }

        //  初始化界面（部分界面在某些模式下不可见）
        if (_checkActivePermission) {
            //  test network didnt show 'register'
            button_register.setOnClickListener {
                goTo(ActivityRegister::class.java, true)
            }
        } else {
            //  导入到已有钱包时：钱包模式移除，注册按钮隐藏。
            findViewById<android.support.design.widget.TabLayout>(R.id.tablayout_of_login).removeTabAt(2)
            findViewById<Button>(R.id.button_register).visibility = View.INVISIBLE
        }

        // 设置 tablelayout 和 view_pager
        tablayout = tablayout_of_login
        view_pager = view_pager_of_login

        // 添加 fargments
        setFragments()

        // 设置 viewPager 并配置滚动速度
        setViewPager()

        // 监听 tab 并设置选中 item
        setTabListener()
    }

    /**
     * 事件 - 返回按钮或系统返回键点击。
     */
    override fun onBackClicked(result: Any?) {
        _result_promise?.resolve(result)
        finish()
    }

    private fun setViewPager() {
        view_pager!!.adapter = ViewPagerAdapter(super.getSupportFragmentManager(), fragmens)
        val f: Field = ViewPager::class.java.getDeclaredField("mScroller")
        f.isAccessible = true
        val vpc: ViewPagerScroller = ViewPagerScroller(view_pager!!.context, OvershootInterpolator(0.6f))
        f.set(view_pager, vpc)
        vpc.duration = 700


        view_pager!!.setOnPageChangeListener(object : ViewPager.OnPageChangeListener {
            override fun onPageScrollStateChanged(state: Int) {
            }

            override fun onPageScrolled(position: Int, positionOffset: Float, positionOffsetPixels: Int) {
            }

            override fun onPageSelected(position: Int) {
                println(position)
                tablayout!!.getTabAt(position)!!.select()
            }

        })

    }

    private fun setFragments() {
        fragmens.add(FragmentLoginAccountMode().initWithCheckActivePermission(_checkActivePermission, _result_promise))
        fragmens.add(FragmentLoginBrainKeyMode().initWithCheckActivePermission(_checkActivePermission, _result_promise))
        fragmens.add(FragmentLoginPrivateKeyMode().initWithCheckActivePermission(_checkActivePermission, _result_promise))
        //  正常登录模式
        if (_checkActivePermission) {
            fragmens.add(FragmentLoginWalletMode().init())
        }
    }

    private fun setTabListener() {
        tablayout!!.setOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab) {
                view_pager!!.setCurrentItem(tab.position, true)
            }

            override fun onTabUnselected(tab: TabLayout.Tab) {
                //tab未被选择的时候回调
            }

            override fun onTabReselected(tab: TabLayout.Tab) {
                //tab重新选择的时候回调
            }
        })
    }

}
