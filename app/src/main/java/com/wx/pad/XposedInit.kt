package com.wx.pad

import android.util.Log
import com.wx.pad.PadDisguise
import de.robv.android.xposed.IXposedHookLoadPackage
import de.robv.android.xposed.callbacks.XC_LoadPackage

/**
 * XposedInit serves as the main entry point for the LSPosed/Vector module.
 * Intercepts the WeChat application lifecycle to initialize:
 * 1. PadDisguise (appearance, layout breakpoints sw600dp, portrait locking)
 * 2. PadLoginHook (first-party pad-login qualification hook via DexKit)
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
            // 1. Apply Pad disguise and portrait lock.
            // PadDisguise is gated by the system property persist.wx.pad.disguise
            // (default enabled; set to "0" to disable without recompiling).
            PadDisguise.apply(lpparam)

            // 2. Apply built-in Pad login qualification hook.
            // PadLoginHook is gated by the system property persist.wx.pad.loginhook
            // (default enabled; set to "0" to disable without recompiling).
            PadLoginHook.apply(lpparam)

            Log.i(TAG, "WX-Tablet-Mode module initialized successfully for $processName")
        } catch (e: Throwable) {
            Log.e(TAG, "Fatal error initializing WX-Tablet-Mode: ${e.message}", e)
        }
    }
}
