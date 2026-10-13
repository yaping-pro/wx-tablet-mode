package com.wx.pad

import android.util.Log
import com.wx.pad.PadDisguise
import de.robv.android.xposed.IXposedHookLoadPackage
import de.robv.android.xposed.callbacks.XC_LoadPackage

/**
 * XposedInit serves as the main entry point for the LSPosed/Vector module.
 * It intercepts the WeChat application lifecycle and initializes PadDisguise.
 *
 * NOTE: Login qualification is NOT handled here. This module only provides
 * appearance/layout spoofing (sw600dp breakpoint and portrait locking).
 */
class XposedInit : IXposedHookLoadPackage {

    companion object {
        private const val TAG = "WX-Pad-Init"
        private const val TARGET_PACKAGE = "com.tencent.mm"
    }

    override fun handleLoadPackage(lpparam: XC_LoadPackage.LoadPackageParam) {
        if (lpparam.packageName != TARGET_PACKAGE) {
            return
        }

        val processName = lpparam.processName
        Log.i(TAG, "Initializing WX-Tablet-Mode in process: $processName (package: ${lpparam.packageName})")

        try {
            // Apply Pad disguise and portrait lock.
            // PadDisguise is gated by the system property persist.wx.pad.disguise
            // (default enabled; set to "0" to disable without recompiling).
            PadDisguise.apply(lpparam)

            Log.i(TAG, "WX-Tablet-Mode disguise initialized successfully for $processName")
        } catch (e: Throwable) {
            Log.e(TAG, "Fatal error initializing WX-Tablet-Mode: ${e.message}", e)
        }
    }
}
