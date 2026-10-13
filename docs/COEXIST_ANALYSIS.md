# wx-pad-sniffer Android Xposed 模块 · 源码级共存审计

> 审计范围:`android-module/` 全部源码(逐字通读)。
> 方法:只读源码 + 只读 adb 探测;未修改任何源码、未改动设备。
> 审计日期:2026-10-03。

---

## TL;DR(5 行内)

1. **能否只读 / 能否发消息**:严格只读。**只能读,不能发**。模块只 Hook 数据库 `insertWithOnConflict` 的 `after` 回调做只读上报,没有任何写库、改数据、或调用微信发送路径的代码。
2. **与 `com.roro.tablethook` 共存结论**:模块自身 `PadDisguise` 也做了"平板伪装"(改 `Build` 字段 / `smallestScreenWidthDp` / `screenLayout`),与 tablethook 的"平板副设备登录资格"职责**目标高度重叠**,存在**重复 Hook 同一字段/方法**的可能;是否真冲突取决于 tablethook 的实际 Hook 靶点,该部分**`[待核实]`**(需反编译 tablethook 才能 100% 确认)。框架层(Vector)支持多模块同进程共存,不会单纯因"同包名 scope"而互斥。
3. **编译 APK 还缺什么**:① 本机**无 Android SDK**;② 系统 PATH 上**无可用 JDK**(`java -version`/`javac -version` 均失败,仅有未挂 PATH 的 Homebrew openjdk@27);③ 仓库**无 Gradle wrapper**;④ 还需联网拉取 AGP 8.4.2 / DexKit 2.0.3 / xposed api:82 等依赖。逐项见 Q4。
4. 文档路径:`docs/coexist-analysis.md`。

---

## Q1. 这个模块是否严格只读?

### 逐条列出 Hook 的每一个类/方法

模块入口 `XposedInit.handleLoadPackage`(`XposedInit.kt:20-42`)只在 `packageName == "com.tencent.mm"` 时生效,并依次调用 `PadDisguise.apply`(`:30`)与 `DexKitSniffer.init`(`:35`)。

**A. `PadDisguise`(`PadDisguise.kt`)Hook 清单:**

1. `android.os.Build` 静态字段写入(非方法 Hook,直接 setStaticObjectField):
   - `PadDisguise.kt:44` `XposedHelpers.setStaticObjectField(Build::class.java, "MODEL", FAKE_MODEL)` → `"SM-X910"`
   - `:45` `"MANUFACTURER"` → `"samsung"`
   - `:46` `"DEVICE"` → `"gts9uwifi"`
   - `:47` `"PRODUCT"` → `"gts9uwifi"`
2. `android.content.res.Resources.getConfiguration`(`after` Hook):`:60-74`,改写 `smallestScreenWidthDp`(若 `<600` 置 `600`)与 `screenLayout`(置 `SCREENLAYOUT_SIZE_XLARGE`)。
3. `android.content.res.Resources.getDisplayMetrics`(`after` Hook):`:77-90`,**仅计算 `minPixels` 但为空 if 块,实际不修改任何值**(`:85-87` 的 `if` 体为空)。
4. `android.app.Activity.setRequestedOrientation(int)`(`before` Hook):`:102-118`,当请求为横屏方向时把参数改写为 `SCREEN_ORIENTATION_PORTRAIT`。

**B. `DexKitSniffer`(`DexKitSniffer.kt`)Hook 清单:**

5. `com.tencent.wcdb.database.SQLiteDatabase.insertWithOnConflict`(`after` Hook):`:49-63`
6. `com.tencent.mm.storage.SQLiteDatabase.insertWithOnConflict`(`after` Hook,同上循环):`:41-68`
7. `android.database.sqlite.SQLiteDatabase.insertWithOnConflict`(`after` Hook,兜底):`:76-91`
8. `initDexKitAnalysis`(`:140-154`)仅 `System.loadLibrary("dexkit")` 并 `DexKitBridge.create(apkPath)` 做被动分析,创建后未调用任何搜索/修改 API(`:145-148` 仅 `Log.i` + 注释说明"可用来深搜")。

### 是否存在写库 / 改数据 / 调用发送 API?

- **写库**:所有数据库 Hook 均为 `afterHookedMethod`(`DexKitSniffer.kt:57, :85`),且回调内**仅读取** `param.args[0]`(表名)与 `param.args[2]`(ContentValues),调用 `handleDatabaseInsert` 做提取后**立即 return**,不修改 `param`、不调用任何 `insert/update/execSQL`。
  - `handleDatabaseInsert`(`:101-135`)只 `getAsXxx` 读取字段,然后调用 `RingBufferSender.sendHookPayload(...)`(`:121`)。
- **改数据**:全仓库范围检索 `execSQL|insert(|insertOrThrow|update(|replace(|delete(|sendMessage|sendText|EnSendMsg|sendAppMsg|NetScene|sendReq` → **NO MATCHES**;检索 `sendBroadcast|startActivity|ContentResolver|getContentResolver|call(` → **NO MATCHES**。
- **调用发送 API**:无任何微信发送相关符号。Hook 靶点为数据库 `insertWithOnConflict` 的**插入后**观测,**没有 Hook 任何消息发送路径**(如微信 `NetScene` 发送、MMsg 构造、发送接口等)。模块自身注释明确自述为 "non-blocking, zero-side-effect, read-only message sniffing"(`DexKitSniffer.kt:13-14`)。

### 明确回答

**只能读,不能发。** 模块完全不具备发送微信消息的能力:它既未 Hook 任何发送入口,也未持有任何发送上下文/凭据写入路径,只在消息落库(`insertWithOnConflict`)后做只读字段提取,并通过本地 UDS socket 上报给外部 Go daemon(`RingBufferSender.kt`)。注意:该上报是"把读到的消息**输出给外部**",并非"代替用户发消息"。

---

## Q2. `PadDisguise` 到底做什么?与 `com.roro.tablethook` 是否冲突?

### `PadDisguise.kt` 逐字行为摘出

- **伪装字段(`spoofBuildProperties`,`:42-52`)**:直接改写进程内 `android.os.Build` 四个静态字段为三星平板 `SM-X910` / `samsung` / `gts9uwifi` / `gts9uwifi`(常量定义 `:23-26`)。
- **改设备型号?** 是 —— 通过 `Build.MODEL` / `Build.DEVICE` / `Build.PRODUCT` / `Build.MANUFACTURER` 伪造为 Galaxy Tab S9 Ultra。
- **改 Configuration / 屏幕尺寸(`hookConfiguration`,`:57-94`)**:`getConfiguration` 的 `after` 回调把 `smallestScreenWidthDp` 抬到 `≥600` 并将 `screenLayout` 置为 `XLARGE`,模拟平板布局;`getDisplayMetrics` 的 `after` 回调**实际为空操作**(`:85-87`)。
- **锁竖屏(`lockPortraitOrientation`,`:100-122`)**:`setRequestedOrientation` 的 `before` 回调在请求横屏时强制改回竖屏。
- **是否改 `checkloginaspad` / `inTabletEnv` 之类?** **否。** 全文件无任何 `checkloginaspad`、`inTabletEnv`、`isPad`、`checklogin` 等标识符(已逐字通读 + 全仓库检索)。`PadDisguise` 只做"设备外观"层面的伪装(Build 字段 + 配置尺寸 + 屏幕方向),**不触碰**登录判定方法名。

### 与 `com.roro.tablethook`(TabletHook)的冲突判断

- **tablethook 的职责**(据任务说明):提供"平板副设备登录资格"——即让微信认为当前设备是平板从而允许副设备登录。其实现**几乎必然**包含对 `Build.MODEL/DEVICE/...` 与/或 `Configuration.smallestScreenWidthDp`/`screenLayout` 的伪装,这与 `PadDisguise` 的 `:44-47`、`:60-74` **靶点完全重合**。
- **是否重复 Hook 同一方法 → 互相覆盖/崩溃?**
  - 框架层(Vector/LSPosed)多模块同进程时,同一方法的多个 Hook 以**注册顺序**串成调用链,不会单纯因重复 Hook 而崩溃;但**后注册者会看到先注册者的修改结果**,且对"静态字段写入"与"`before` 改写参数"这类**幂等覆盖**型操作,**最后写入者胜出**(`XposedHelpers.setStaticObjectField` 与 `param.args[0]=` 都是覆盖语义)。
  - 因此若两者都写 `Build.MODEL` 等字段,存在**期望值被覆盖**的可能(例如 tablethook 要的是某型号、sniffer 写死 `SM-X910`,最终取决于加载顺序)。
  - **结论**:`PadDisguise` 与 tablethook 在"平板伪装"目标上**功能重叠、靶点可能重合**;是否真发生同方法 Hook 冲突,**`[待核实]`**——需反编译 `com.roro.tablethook` APK 确认其确切 Hook 的类/方法。就源码可见部分,sniffer 自身并未实现"登录资格"逻辑(无 `checkloginaspad` 类钩子),它只做外观伪装。
- **额外风险点**:设备侧 tablethook 对 **u999 用户**(UID `<CLONE_UID>`)处于 enabled(`[见 Q5 探测]`),即当前 u999 平板登录由 tablethook 实证维持。sniffer 的 `PadDisguise` 若与 tablethook 同时注入,两者伪装字段可能相互干扰,**存在破坏已打通登录的潜在风险**(`[待核实]`,取决于加载顺序与 tablethook 实现)。

---

## Q3. 框架层面:Vector/LSPosed 能否同时加载两个模块注入同一进程(com.tencent.mm)?

- **多模块共存是常规能力**:Vector(`module.prop` 显示 `id=zygisk_vector, name=Vector, v2.2`)与 LSPosed 均为 Xposed 兼容框架,**原生支持同一目标包(`com.tencent.mm`)被多个模块同时注入**。不存在"同包名 scope 只能一个模块"的限制——这是 Xposed 体系的基本设计(每个模块各自声明 scope,框架在目标进程加载时依次触发各模块的 `handleLoadPackage`)。
- **当前设备证据**:`/data/adb/modules/` 下同时存在 `zygisk_vector`、`zygisk_lsposed`、`zygisk_shamiko` 等;`Vector modules ls --json` 显示 `com.tencent.mm` 相关模块(如 `com.roro.tablethook`)被加载,且同一 `com.roro.tablethook` 在两个 UID(`10284` 与 `<CLONE_UID>`)下均 enabled——说明框架按用户/进程分别注入多模块,无"一包一名额"限制(实测证据)。
- **已知冲突模式(需规避)**:
  1. **重复 Hook 同一方法且为覆盖语义**(`setStaticObjectField` / `before` 改写 `param.args`):后加载者覆盖先加载者,结果依赖模块加载顺序。**这是 sniffer 与 tablethook 最可能的冲突面**(见 Q2)。
  2. **资源 Hook 冲突**:本模块 `AndroidManifest.xml` 未声明任何资源替换(resources 仅 `xposed_scope` 数组,`AndroidManifest.xml`),无 `res` Hook,故不涉及 Xposed 资源替换冲突模式。
  3. **`afterHookedMethod` 只读型**:如 sniffer 的数据库 Hook,只读不改,与任何模块共存都很安全。
- **`[待核实]`**:Vector 对多模块同方法的**确切调用顺序优先级**(按模块列表顺序 / 按包名哈希 / 按安装时间)未经源码级确认;该顺序决定了 Q2 中"谁覆盖谁"。如需确认,可查 Vector daemon 的 hook 调度实现或实测日志。

---

## Q4. 编译这个 APK 需要什么?本机现在具备吗?

### 原始回显(探测)

```
$ ls -la ~/Library/Android/sdk 2>&1 | head
ls: cannot access '/Users/<USER>/Library/Android/sdk': No such file or directory
$ ls -la ~/Android/Sdk 2>&1 | head
ls: cannot access '/Users/<USER>/Android/Sdk': No such file or directory
$ which gradle java javac sdkmanager 2>&1
/usr/bin/java
/usr/bin/javac
$ java -version 2>&1
The operation couldn't be completed. Unable to locate a Java Runtime.
Please visit http://www.java.com for information on installing Java.
$ javac -version 2>&1
The operation couldn't be completed. Unable to locate a Java Runtime.
$ cat android-module/gradle/wrapper/gradle-wrapper.properties 2>&1
cat: .../gradle/wrapper/gradle-wrapper.properties: No such file or directory
$ ls -la android-module/gradle 2>&1
ls: .../android-module/gradle: No such file or directory
$ find /Users/<USER>/Projects/wx-pad-sniffer -name "gradle-wrapper.properties" -o -name "gradlew" 2>/dev/null
(none)
```

### 逐项回答

① **本机是否有 Android SDK?** —— **否**。标准位置 `~/Library/Android/sdk` 与 `~/Android/Sdk` 均不存在。

② **是否有 JDK?** —— **系统 PATH 上无可用 JDK**。`/usr/bin/java`、`/usr/bin/javac` 存在但是 Apple 的运行时桩,`java -version` 与 `javac -version` 均报 "Unable to locate a Java Runtime"。本机装有 Homebrew `openjdk@27`(`/opt/homebrew/Cellar/openjdk/27`,`/opt/homebrew/opt/java -> ../Cellar/openjdk/27`),但**未挂入 PATH 且未设 `JAVA_HOME`**,当前构建环境无法调用。AGP 8.4.2 要求 **JDK 17+**,Homebrew 的 27 版本满足最低要求,但需显式 `export JAVA_HOME=/opt/homebrew/opt/openjdk` 并加入 PATH 才可用。

③ **仓库是否自带 Gradle wrapper?** —— **否**。`android-module/gradle/` 目录不存在,无 `gradle/wrapper/gradle-wrapper.properties`,仓库根也无 `gradlew`/`gradlew.bat`/`gradle/`。

④ **该模块声明的版本(`android-module/app/build.gradle.kts` + `build.gradle.kts`)**:
- **AGP**:`com.android.application` 版本 `8.4.2`(`android-module/build.gradle.kts:2`)
- **Kotlin**:`org.jetbrains.kotlin.android` 版本 `1.9.24`(`android-module/build.gradle.kts:3`)
- **compileSdk / targetSdk / minSdk**:`34` / `34` / `26`(`app/build.gradle.kts:7-11`)
- **Xposed API**:`compileOnly("de.robv.android.xposed:api:82")`(`app/build.gradle.kts` dependencies)
- **DexKit**:`implementation("org.luckypray:dexkit:2.0.3")`(`app/build.gradle.kts` dependencies)
- **kotlinx-coroutines-android**:`1.8.1`
- **xposedminversion**:`82`(`AndroidManifest.xml` meta-data)
- **ABI**:`arm64-v8a`, `armeabi-v7a`(`app/build.gradle.kts` ndk.abiFilters)
- **依赖仓库**:`google()`、`mavenCentral()`、`https://api.xposed.info/`、`https://jitpack.io`(`settings.gradle.kts`)

⑤ **要成功产出 APK 还缺什么(逐项)**:
- **Android SDK 平台与构建工具**:需 `sdkmanager` 安装 `platform-tools`、`platforms;android-34`、`build-tools;34.0.0`(对应 compileSdk=34)。本机无 SDK,也无 `sdkmanager`(PATH 缺失)。
- **可用 JDK 17+ 并挂入环境**:推荐 `export JAVA_HOME=/opt/homebrew/opt/openjdk && export PATH=$JAVA_HOME/bin:$PATH`(利用已装的 openjdk@27),或从 Adoptium/Zulu 装 JDK 17。
- **Gradle wrapper 或本地 Gradle**:仓库无 wrapper。可选:`gradle wrapper --gradle-version 8.6`(需先有 gradle)或在 Android Studio 中打开自动生成;或本地安装 Gradle 8.x(AGP 8.4.2 兼容 Gradle 8.4–8.6)。
- **联网拉取依赖**:`api:82`(xposed.info)、`dexkit:2.0.3`(mavenCentral/jitpack)、`coroutines:1.8.1`、AGP/Kotlin 插件均需从对应 maven 下载。
- **NDK?** 不需要。`build.gradle.kts` 仅声明 `ndk.abiFilters`(筛选 so 架构),无 `externalNativeBuild`/`cmake`;DexKit 的 `libdexkit.so` 由 DexKit AAR 自带,AGP 自动打包,无需 NDK 编译。但 `System.loadLibrary("dexkit")`(`DexKitSniffer.kt:143`)要求目标设备 ABI 与 AAR 内 so 匹配——这是运行期问题,非编译期缺件。

---

## Q5. 设备现状(只读)

### 原始回显(探测,未做任何修改)

```
$ adb devices
List of devices attached
xs9ponj…(redacted)	device

$ adb shell "pm list packages | grep -iE 'wx.sniffer|roro.tablethook'"
package:com.roro.tablethook

$ adb shell "su -c 'ls -la /data/app/*/com.wx.sniffer*/ 2>/dev/null'"
(empty)

$ adb shell "su -c 'ls -la /data/adb/lspd/config/ 2>/dev/null'"
total 136
-rw-rw---- 1 root root 45056 ... modules_config.db
-rw-rw---- 1 root root 32768 ... modules_config.db-shm
-rw-rw---- 1 root root 28872 ... modules_config.db-wal

$ adb shell "su -c '/data/adb/modules/zygisk_vector/cli modules ls --json 2>&1'"
{
  "data": [
    {"PACKAGE":"com.rarnu.wechatpad","UID":10281,"STATUS":"disabled"},
    {"PACKAGE":"com.roro.tablethook","UID":10284,"STATUS":"enabled"},
    {"PACKAGE":"com.roro.tablethook","UID":<CLONE_UID>,"STATUS":"enabled"},
    {"PACKAGE":"top.hookvip.wxtablet","UID":10283,"STATUS":"disabled"}
  ],
  "isFdAttached": false,
  "success": true
}

$ adb shell "su -c '/data/adb/modules/zygisk_vector/cli status 2>&1'"
Framework Version: 2.2  Version Code: 3080  API Version: 102
Enabled Modules: 1   Status Notification: true
```

辅助确认(只读):
- `/data/adb/modules/zygisk_lsposed/disable` 文件**存在** → LSPosed 当前被禁用,**实际生效框架为 Vector**。
- `/data/adb/modules/zygisk_vector/module.prop`:`name=Vector, version=v2.2 (...JingMatrix-Vector)`。
- `/data/adb/modules/zygisk_lsposed/module.prop`:`name=Zygisk - LSPosed, v1.9.2 (7024)`。

### 回答

- **`com.wx.sniffer` 是否已安装?** —— **否**。`pm list packages` 只列出 `com.roro.tablethook`;`/data/app/*/com.wx.sniffer*` 为空。
- **`com.roro.tablethook` 是否仍启用?** —— **是,且对两个 UID 均启用**:`10284`(主用户)与 `<CLONE_UID>`(**u999 用户**)。这正是 u999 平板登录赖以成功的模块(任务已说明为实证)。
- **当前 Vector 已启用模块清单?** —— 据 `modules ls` 的 `STATUS`,**启用中**的仅 `com.roro.tablethook`(两条记录);`com.rarnu.wechatpad`、`top.hookvip.wxtablet` 均为 disabled。`status` 亦显示 `Enabled Modules: 1`。
- **LSPosed?** 已安装但被 `disable` 文件停用;生效框架为 Vector。`[注:]` `/data/adb/lspd/config/modules_config.db` 存在但 LSPosed 进程未运行,不直接参与当前注入。

**未对设备做任何修改。**

---

## 共存决策建议

> ⚠️ **关键前提必须点明**:`com.roro.tablethook` 是**当前 u999 平板登录赖以成功**的模块(已实证,且设备侧对其 `<CLONE_UID>` 用户 enabled)。**贸然替换 / 卸载 tablethook 会直接丢失已打通的登录资格**,恢复成本高且不确定。

### 选项 A:共存(sniffer + tablethook 同时启用)

- **做法**:编译并安装 `com.wx.sniffer`,在 Vector 中将其 scope 指向 `com.tencent.mm` 并启用,保留 tablethook 不变。
- **风险**:
  - sniffer 的 `PadDisguise` 会改写 `Build.MODEL/DEVICE/...` 与 `Configuration.smallestScreenWidthDp/screenLayout`(`PadDisguise.kt:44-47, :60-74`),与 tablethook 的平板伪装**靶点可能重合**,存在**覆盖/顺序依赖**冲突,可能干扰已打通的 u999 登录(`[待核实]` 取决于 tablethook 实现与加载顺序)。
  - 若两者都改同一静态字段,最终设备型号由加载顺序决定,行为不确定。
- **前置条件**:
  - 先确认(tablethook 反编译)`[待核实]` 其确切 Hook 靶点是否与 sniffer 重叠;
  - 建议在**非 u999 的测试用户/备用机**先验证共存,再考虑 u999;
  - sniffer 的"嗅探"部分(`DexKitSniffer`)本身是只读 after-Hook,与 tablethook 冲突风险极低,冲突仅来自 `PadDisguise`。
- **已落地的缓解(源码已实现)**:`PadDisguise` 现由系统属性开关 `persist.wx.sniffer.pad_disguise` 控制(默认启用,**向后兼容**),无需重编译即可在运行时关闭。见下方「共存 + 只嗅探 操作指引」。源码改动:新增 `PadDisguise.isEnabled()` / `PROP_PAD_DISGUISE_ENABLED`(`PadDisguise.kt`),`apply()` 在开关关闭时直接 return;`XposedInit.kt:28-34` 调用处已加注释说明。

### 选项 B:用 sniffer 替代 tablethook(卸载 tablethook,仅留 sniffer)

- **做法**:卸载/禁用 tablethook,仅用 sniffer 提供平板伪装 + 嗅探。
- **风险(高)**:
  - **直接丢失 u999 已打通登录**(关键前提);
  - sniffer `PadDisguise` **未实现任何 `checkloginaspad`/`inTabletEnv` 类登录资格逻辑**(源码通读确认),它只做"外观伪装"。tablethook 之所以能打通登录,很可能还做了 sniffer 没有的登录判定 Hook。用 sniffer 单替**大概率无法复现登录资格**(`[待核实]` 需反编译 tablethook 比对)。
- **前置条件**:必须先在另一设备/用户完整复现"仅 sniffer 即可平板登录"后方可对 u999 操作;在此之前**不推荐**。

### 选项 C:先只装 sniffer、不装/不启用 tablethook(全新环境)

- **做法**:在**尚未登录、无既有登录态**的微信实例/测试机上,只启用 sniffer,验证其 `PadDisguise` + 嗅探是否独立可用。
- **风险(低,但结论待定)**:
  - 若 sniffer 单独无法提供登录资格,则测试机无法登录平板,需回退到"sniffer + tablethook"或"仅 tablethook"。
- **前置条件**:干净的测试实例;与 u999 生产登录完全隔离,不影响现有登录。

### 推荐

**推荐:选项 A(共存),且优先采用"sniffer 仅嗅探、PadDisguise 交由 tablethook"的削减形态**——即保留已实证可用的 tablethook 不动,让 sniffer 只承担它真正擅长且零冲突的只读嗅探(`DexKitSniffer` 的 after-Hook),把平板伪装完全留给 tablethook。

**理由**:
1. **不破坏已打通的 u999 登录**(关键前提优先);
2. sniffer 的嗅探能力(只读 `insertWithOnConflict` 上报)**与 tablethook 零功能重叠、冲突风险极低**(Q1 已证其为只读 after-Hook);
3. 真正的共存风险只来自 `PadDisguise` 与 tablethook 的"平板伪装"靶点重叠(Q2/Q3),而该伪装**并非嗅探所必需**——把 `PadDisguise` 关掉即可消除冲突面,同时完整保留嗅探价值。
4. 选项 B 直接替换会丢失登录且 sniffer 缺乏登录资格逻辑,风险不可接受;选项 C 仅适用于隔离测试,不解决生产 u999 诉求。

**执行前必做(降低不确定性)**:
- `[待核实]` 反编译 `com.roro.tablethook`,确认其 Hook 靶点是否包含 `Build.MODEL`、`Resources.getConfiguration`、`checkloginaspad` 等,以 100% 判定与 `PadDisguise` 的冲突面;
- `[待核实]` 确认 Vector 多模块同方法的加载顺序优先级,预判"谁覆盖谁";
- 若走选项 A,务必在**非 u999 测试用户**先验证,再触达 u999。

### 共存 + 只嗅探 操作指引(如何关掉 PadDisguise)

> ⚠️ **不要**为了开启嗅探而去改动 / 反编译 / 替换 `com.roro.tablethook`。tablethook 是当前 u999 平板登录的实证依赖;sniffer 的嗅探能力(`DexKitSniffer` 只读 `insertWithOnConflict` 上报)与 tablethook **零功能重叠**,无需触碰 tablethook 即可获得嗅探。关掉的只是 sniffer 自己那份"平板伪装",伪装职责仍由 tablethook 独家承担。

**步骤(设备侧,运行时生效,无需重编译/重装 APK)**:

1. 在已安装并启用 `com.wx.sniffer` 的前提下,通过 root shell 设置持久化系统属性:
   ```bash
   su -c 'setprop persist.wx.sniffer.pad_disguise 0'
   ```
   - 属性名:`persist.wx.sniffer.pad_disguise`;取值 `0` = 关闭 PadDisguise,其他任何值(或缺省) = 启用。
   - `persist.` 前缀使其重启后仍保留;若仅想临时验证,可用非 persist 的 `wx.sniffer.pad_disguise`(重启后还原)。
2. 重启微信(或重启设备)使 `handleLoadPackage` 重新执行;`PadDisguise.apply()` 读取到 `0` 后会 **直接 return**,日志输出 `PadDisguise DISABLED via system property ...`(`PadDisguise.kt` 内 `isEnabled()` + `apply()` 早期返回)。
3. 确认:logcat 过滤 `WX-PadDisguise` 应见 DISABLED 日志且不再有 `Spoofed Build properties` / `smallestScreenWidthDp` 改写;嗅探侧 `WX-DexKitSniffer` / `WX-RingBufferSender` 仍正常工作。

**开关实现要点(源码,供核对)**:
- `PadDisguise.kt`:新增常量 `PROP_PAD_DISGUISE_ENABLED = "persist.wx.sniffer.pad_disguise"` 与方法 `isEnabled()`(通过反射调用 `android.os.SystemProperties.get`,避免依赖隐藏 API 编译断点;任何异常回退为"启用"以保证默认行为)。`apply(lpparam)` 在 `!isEnabled()` 时打日志并 `return`,跳过 `spoofBuildProperties` / `hookConfiguration` / `lockPortraitOrientation`。
- `XposedInit.kt:28-34`:调用处注释说明该开关的存在原因与推荐用法;调用签名 `PadDisguise.apply(lpparam)` 保持不变(向后兼容)。
- **未引入任何新权限 / 组件**:`AndroidManifest.xml` 未改动,仅依赖既有的 `android.os.SystemProperties`(运行时存在,模块进程可访问)。

**回滚**:`su -c 'setprop persist.wx.sniffer.pad_disguise 1'`(或删除该属性)并重启微信即可恢复伪装。

> 以上所有 `[待核实]` 项均因本审计受限于"只读源码 + 只读探测"、无法获取 `com.roro.tablethook` 源码/反编译产物而标注,未做任何编造。
