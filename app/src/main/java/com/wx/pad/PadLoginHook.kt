/*
 * Copyright (C) 2026 yaping-pro / wx-tablet-mode contributors.
 *
 * This file is part of wx-tablet-mode.
 *
 * wx-tablet-mode is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * wx-tablet-mode is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with wx-tablet-mode. If not, see <https://www.gnu.org/licenses/>.
 *
 * ATTRIBUTION / CREDITS:
 * Matcher concepts and hook design derive from Houvven/I-Am-Pad (GPL-3.0)
 * (https://github.com/Houvven/I-Am-Pad) by Houvven, licensed under GPL-3.0.
 * Dynamic bytecode search is powered by LuckyPray/DexKit (LGPL-3.0)
 * (https://github.com/LuckyPray/DexKit) by LuckyPray.
 */

package com.wx.pad

import android.app.Application
import android.content.Context
import android.util.Log
import de.robv.android.xposed.XC_MethodHook
import de.robv.android.xposed.XposedBridge
import de.robv.android.xposed.XposedHelpers
import de.robv.android.xposed.callbacks.XC_LoadPackage
import org.luckypray.dexkit.DexKitBridge
import java.lang.reflect.Modifier
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.Continuation

/**
 * PadLoginHook provides first-party pad-login qualification for WeChat on Android.
 *
 * HOW IT WORKS:
 * WeChat server and client determine tablet secondary-device QR login eligibility
 * via two internal checkpoints:
 * 1. A static boolean method matched by string "inTabletEnv" -> forces return true.
 * 2. A coroutine method whose signature is (String, String, Continuation) -> Object
 *    matched by string "/cgi-bin/micromsg-bin/checkloginaspad" -> forces return true.
 *
 * Both methods are located dynamically at runtime using LuckyPray/DexKit so that no
 * obfuscated class or method names are hardcoded.
 *
 * RUNTIME TOGGLE:
 * Gated by system property "persist.wx.pad.loginhook" (default: enabled).
 * To disable at runtime (e.g. to use an external hook):
 *   su -c 'setprop persist.wx.pad.loginhook 0'
 */
object PadLoginHook {
    private const val TAG = "TabletHook"
    private const val PROP_PAD_LOGINHOOK_ENABLED = "persist.wx.pad.loginhook"
    private val installed = AtomicBoolean(false)

    /**
     * @return true if PadLoginHook should run. Reads system property
     * [PROP_PAD_LOGINHOOK_ENABLED]; any value other than exactly "0" is treated as enabled.
     */
    fun isEnabled(): Boolean {
        return try {
            val cls = Class.forName("android.os.SystemProperties")
            val get = cls.getDeclaredMethod("get", String::class.java, String::class.java)
            val v = get.invoke(null, PROP_PAD_LOGINHOOK_ENABLED, "1") as? String ?: "1"
            v != "0"
        } catch (e: Throwable) {
            true
        }
    }

    /**
     * Entry point called from XposedInit during handleLoadPackage.
     * Hooks Application lifecycle to run DexKit search after the classloader is fully attached.
     */
    fun apply(lpparam: XC_LoadPackage.LoadPackageParam) {
        if (!isEnabled()) {
            Log.i(TAG, "com.wx.pad: PadLoginHook DISABLED via system property $PROP_PAD_LOGINHOOK_ENABLED=0; skipping.")
            return
        }

        // Only the primary WeChat process handles login logic and CGI requests
        if (lpparam.processName != "com.tencent.mm") {
            return
        }

        hookApplicationLifecycle(lpparam)
    }

    private fun hookApplicationLifecycle(lpparam: XC_LoadPackage.LoadPackageParam) {
        val classLoader = lpparam.classLoader

        // Strategy A: WeChat uses TinkerApplication as its base Application class.
        // Hook onBaseContextAttached(Context) which fires right after base context attachment.
        val tinkerClass = XposedHelpers.findClassIfExists(
            "com.tencent.tinker.loader.app.TinkerApplication",
            classLoader
        )

        if (tinkerClass != null) {
            try {
                XposedBridge.hookAllMethods(
                    tinkerClass,
                    "onBaseContextAttached",
                    object : XC_MethodHook() {
                        override fun afterHookedMethod(param: MethodHookParam) {
                            val context = param.args.firstOrNull() as? Context
                            onContextReady(lpparam, context)
                        }
                    }
                )
                Log.d(TAG, "com.wx.pad: Hooked TinkerApplication.onBaseContextAttached")
            } catch (e: Throwable) {
                Log.w(TAG, "com.wx.pad: Failed to hook TinkerApplication.onBaseContextAttached: ${e.message}")
            }
        }

        // Strategy B: android.app.Application.onCreate() as guaranteed fallback
        try {
            XposedHelpers.findAndHookMethod(
                Application::class.java,
                "onCreate",
                object : XC_MethodHook() {
                    override fun afterHookedMethod(param: MethodHookParam) {
                        val app = param.thisObject as? Application
                        onContextReady(lpparam, app)
                    }
                }
            )
            Log.d(TAG, "com.wx.pad: Hooked Application.onCreate fallback")
        } catch (e: Throwable) {
            Log.w(TAG, "com.wx.pad: Failed to hook Application.onCreate: ${e.message}")
        }
    }

    private fun onContextReady(lpparam: XC_LoadPackage.LoadPackageParam, context: Context?) {
        if (!installed.compareAndSet(false, true)) {
            return
        }
        val targetClassLoader = context?.classLoader ?: lpparam.classLoader
        install(lpparam, targetClassLoader)
    }

    private fun install(lpparam: XC_LoadPackage.LoadPackageParam, classLoader: ClassLoader) {
        try {
            System.loadLibrary("dexkit")
        } catch (e: Throwable) {
            Log.e(TAG, "com.wx.pad: Failed to load libdexkit.so native library: ${e.message}", e)
            return
        }

        var bridge: DexKitBridge? = null
        try {
            // First attempt: memory dex via class loader (fast, works on loaded runtime)
            bridge = try {
                DexKitBridge.create(classLoader, true)
            } catch (e: Throwable) {
                Log.w(TAG, "com.wx.pad: DexKitBridge.create(classLoader, true) failed: ${e.message}; trying apkPath fallback")
                val sourceDir = lpparam.appInfo?.sourceDir
                if (!sourceDir.isNullOrBlank()) {
                    DexKitBridge.create(sourceDir)
                } else {
                    null
                }
            }

            if (bridge == null) {
                Log.e(TAG, "com.wx.pad: Could not initialize DexKitBridge; pad login hooks skipped")
                return
            }

            val envHooked = installTabletEnvHook(bridge, classLoader)
            val loginHooked = installCheckLoginAsPadHook(bridge, classLoader)

            if (envHooked > 0 || loginHooked > 0) {
                Log.i(TAG, "com.wx.pad: 微信平板登录模式已启用")
            } else {
                Log.w(TAG, "com.wx.pad: 目标方法未命中，微信平板登录模式未完全生效")
            }
        } catch (e: Throwable) {
            Log.e(TAG, "com.wx.pad: Unexpected error during DexKit search & hook: ${e.message}", e)
        } finally {
            try {
                bridge?.close()
            } catch (e: Throwable) {
                Log.w(TAG, "com.wx.pad: Error closing DexKitBridge: ${e.message}")
            }
        }
    }

    /**
     * Intercepts WeChat's tablet environment check:
     * Matched by static boolean method using string "inTabletEnv", forced to return true.
     */
    private fun installTabletEnvHook(bridge: DexKitBridge, classLoader: ClassLoader): Int {
        var hookedCount = 0
        try {
            // Primary matcher: static boolean method containing string "inTabletEnv"
            var candidates = bridge.findMethod {
                matcher {
                    modifiers(Modifier.STATIC)
                    returnType(Boolean::class.javaPrimitiveType!!)
                    usingStrings("inTabletEnv")
                }
            }

            // Fallback 1: exact string match
            if (candidates.isEmpty()) {
                candidates = bridge.findMethod {
                    matcher {
                        modifiers(Modifier.PUBLIC or Modifier.STATIC)
                        returnType(Boolean::class.javaPrimitiveType!!)
                        usingEqStrings("inTabletEnv")
                    }
                }
            }

            // Fallback 2: foldable screen check (Houvven/I-Am-Pad style)
            if (candidates.isEmpty()) {
                Log.d(TAG, "com.wx.pad: inTabletEnv not found; trying foldable device check fallback")
                candidates = bridge.findMethod {
                    searchPackages("com.tencent.mm.ui")
                    matcher {
                        modifiers(Modifier.PUBLIC or Modifier.STATIC)
                        returnType(Boolean::class.javaPrimitiveType!!)
                        usingStrings("royole", "ro.os_foldable_screen_support")
                    }
                }
            }

            for (methodData in candidates) {
                try {
                    val method = methodData.getMethodInstance(classLoader)
                    XposedBridge.hookMethod(method, object : XC_MethodHook() {
                        override fun beforeHookedMethod(param: MethodHookParam) {
                            param.result = true
                        }
                    })
                    hookedCount++
                    Log.d(TAG, "com.wx.pad: Hooked tablet env check: $method")
                } catch (e: Throwable) {
                    Log.w(TAG, "com.wx.pad: Failed to hook method ${methodData.name}: ${e.message}")
                }
            }
        } catch (e: Throwable) {
            Log.e(TAG, "com.wx.pad: Error searching tablet env check: ${e.message}", e)
        }

        Log.i(TAG, "com.wx.pad: DexKit 微信平板判定候选：关键词=${if (hookedCount > 0) 2 else 0}，签名=$hookedCount")
        return hookedCount
    }

    /**
     * Intercepts WeChat's checkloginaspad eligibility coroutine:
     * Matched by (String, String, Continuation) -> Object using "/cgi-bin/micromsg-bin/checkloginaspad",
     * forced to return true (granting secondary tablet scan-login eligibility).
     */
    private fun installCheckLoginAsPadHook(bridge: DexKitBridge, classLoader: ClassLoader): Int {
        var hookedCount = 0
        try {
            // Primary matcher: (String, String, Continuation) -> Object with CGI path
            var candidates = bridge.findMethod {
                matcher {
                    paramCount(3)
                    paramTypes(
                        String::class.java,
                        String::class.java,
                        Continuation::class.java
                    )
                    usingEqStrings("/cgi-bin/micromsg-bin/checkloginaspad")
                }
            }

            // Fallback 1: include class hint "MicroMsg.CgiCheckLoginAsPad" (Houvven/I-Am-Pad style)
            if (candidates.isEmpty()) {
                candidates = bridge.findMethod {
                    matcher {
                        paramCount(3)
                        paramTypes(
                            String::class.java,
                            String::class.java,
                            Continuation::class.java
                        )
                        usingStrings(
                            "MicroMsg.CgiCheckLoginAsPad",
                            "/cgi-bin/micromsg-bin/checkloginaspad"
                        )
                    }
                }
            }

            // Fallback 2: relaxed string match on CGI path
            if (candidates.isEmpty()) {
                candidates = bridge.findMethod {
                    matcher {
                        paramTypes(
                            String::class.java,
                            String::class.java,
                            Continuation::class.java
                        )
                        usingStrings("/cgi-bin/micromsg-bin/checkloginaspad")
                    }
                }
            }

            for (methodData in candidates) {
                try {
                    val method = methodData.getMethodInstance(classLoader)
                    // The coroutine suspend method is non-static
                    if (Modifier.isStatic(method.modifiers)) {
                        continue
                    }
                    XposedBridge.hookMethod(method, object : XC_MethodHook() {
                        override fun beforeHookedMethod(param: MethodHookParam) {
                            param.result = true
                        }
                    })
                    hookedCount++
                    Log.d(TAG, "com.wx.pad: Hooked checkloginaspad method: $method")
                } catch (e: Throwable) {
                    Log.w(TAG, "com.wx.pad: Failed to hook cgi method ${methodData.name}: ${e.message}")
                }
            }
        } catch (e: Throwable) {
            Log.e(TAG, "com.wx.pad: Error searching checkloginaspad method: ${e.message}", e)
        }

        Log.i(TAG, "com.wx.pad: DexKit 微信副设备登录资格候选：关键词=${if (hookedCount > 0) 1 else 0}，签名=$hookedCount")
        return hookedCount
    }
}
