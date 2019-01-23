package com.btsplusplus.fowallet

import android.os.Bundle
import kotlinx.android.synthetic.main.activity_vesting_balance.*

//  TODO: pending

class ActivityVestingBalance : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_vesting_balance)

        setFullScreen()

        layout_back_from_page_of_unfreeze_amount.setOnClickListener {
            finish()
        }
    }
}
