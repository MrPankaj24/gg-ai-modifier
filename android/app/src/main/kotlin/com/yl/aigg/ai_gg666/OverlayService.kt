package com.yl.aigg.ai_gg666

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.widget.ImageView
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Spinner
import android.widget.ArrayAdapter
import android.widget.TextView
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class OverlayService : Service() {

    companion object {
        private const val CHANNEL_ID = "overlay_channel"
        private const val NOTIFICATION_ID = 1
        var isRunning = false
    }

    private var wm: WindowManager? = null
    private var ballView: View? = null
    private var ballParams: WindowManager.LayoutParams? = null
    private var panel: View? = null
    private var panelParams: WindowManager.LayoutParams? = null
    private val handler = Handler(Looper.getMainLooper())

    // Searchstatus
    private var searchResults: List<Map<String, Any>> = emptyList()
    private var searchDataType = "dword"
    private val selectedIndices = mutableSetOf<Int>() // Selected result indices
    // Implementation detail.
    private var savedSearchInput = ""
    private var savedFilterInput = ""
    private var savedRangeMin = ""
    private var savedRangeMax = ""
    private var savedScrollY = 0

    // Implementation detail.
    private val chatMessages = mutableListOf<Pair<String, String>>() // (sender, message)
    private var isAiResponding = false

    // Implementation detail.
    private var lastPanel = ""

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        createBall()
        // Implementation detail.
        lastPanel = getSharedPreferences("gg_overlay", Context.MODE_PRIVATE).getString("last_panel", "") ?: ""
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int) = START_STICKY

    override fun onDestroy() {
        isRunning = false
        removeBall()
        super.onDestroy()
    }

    // Implementation detail.

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL_ID, "GG-AI Overlay", NotificationManager.IMPORTANCE_LOW)
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(ch)
        }
    }

    private fun buildNotification(): Notification {
        val pi = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID).setContentTitle("GG-AI").setContentText("Overlay running")
                .setSmallIcon(android.R.drawable.ic_dialog_info).setContentIntent(pi).build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setContentTitle("GG-AI").setContentText("Overlay running")
                .setSmallIcon(android.R.drawable.ic_dialog_info).setContentIntent(pi).build()
        }
    }

    // Implementation detail.

    private fun createBall() {
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        ballView = ImageView(this).apply {
            setImageResource(R.drawable.xfc)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(Color.parseColor("#f6f2c1")) }
            setPadding(dp(10), dp(10), dp(10), dp(10))
        }

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        ballParams = WindowManager.LayoutParams(
            dp(50),
            dp(50),
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = dp(200)
        }

        var ix = 0; var iy = 0; var tx = 0f; var ty = 0f; var dragging = false
        ballView?.setOnTouchListener { _, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> { ix = ballParams?.x ?: 0; iy = ballParams?.y ?: 0; tx = e.rawX; ty = e.rawY; dragging = false; true }
                MotionEvent.ACTION_MOVE -> {
                    if (kotlin.math.abs(e.rawX - tx) > 10 || kotlin.math.abs(e.rawY - ty) > 10) dragging = true
                    ballParams?.x = ix + (e.rawX - tx).toInt(); ballParams?.y = iy + (e.rawY - ty).toInt()
                    try { wm?.updateViewLayout(ballView, ballParams) } catch (_: Exception) {}
                    true
                }
                MotionEvent.ACTION_UP -> { if (!dragging) showLastOrMainMenu(); true }
                else -> false
            }
        }
        try { wm?.addView(ballView, ballParams) } catch (_: Exception) {}
    }

    private fun removeBall() {
        closePanel()
        try { ballView?.let { wm?.removeView(it) } } catch (_: Exception) {}
        ballView = null
    }

    // Implementation detail.

    private fun saveLastPanel(name: String) {
        lastPanel = name
        getSharedPreferences("gg_overlay", Context.MODE_PRIVATE).edit().putString("last_panel", name).apply()
    }

    private fun closePanel() {
        // Implementation detail.
        try {
            fun findScrollView(v: android.view.View): android.widget.ScrollView? {
                if (v is android.widget.ScrollView) return v
                if (v is android.view.ViewGroup) {
                    for (i in 0 until v.childCount) {
                        val found = findScrollView(v.getChildAt(i))
                        if (found != null) return found
                    }
                }
                return null
            }
            panel?.let { findScrollView(it)?.let { sv -> if (sv.scrollY > 0) savedScrollY = sv.scrollY } }
        } catch (_: Exception) {}
        try { panel?.let { wm?.removeView(it) } } catch (_: Exception) {}
        panel = null; panelParams = null
    }

    private fun showPanel(view: View, w: Int = 280, h: Int = 400) {
        closePanel()
        val dm = resources.displayMetrics
        val screenW = dm.widthPixels
        val screenH = dm.heightPixels
        val panelW = dp(w).coerceAtMost(screenW - dp(20))
        val panelH = dp(h).coerceAtMost(screenH - dp(20))

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        panelParams = WindowManager.LayoutParams(
            panelW,
            panelH,
            type,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (screenW - panelW) / 2
            y = (screenH - panelH) / 2
        }
        panel = view
        try { wm?.addView(panel, panelParams) } catch (_: Exception) {}
    }

    // Implementation detail.
    private fun showFocusablePanel(view: View, w: Int = 280, h: Int = 400) {
        closePanel()
        val dm = resources.displayMetrics
        val screenW = dm.widthPixels
        val screenH = dm.heightPixels
        val panelW = dp(w).coerceAtMost(screenW - dp(20))
        val panelH = dp(h).coerceAtMost(screenH - dp(20))

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        panelParams = WindowManager.LayoutParams(
            panelW,
            panelH,
            type,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (screenW - panelW) / 2
            y = (screenH - panelH) / 2
            softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE or WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE
        }
        panel = view
        try { wm?.addView(panel, panelParams) } catch (_: Exception) {}
    }

    private fun overlayType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
    }

    // Implementation detail.

    private fun makeDraggablePanel(title: String, contentBuilder: (LinearLayout) -> Unit, w: Int = 280, h: Int = 400, onBack: (() -> Unit)? = null, titleIcon: Int? = null, bgColor: String = "#F2F3F8") {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                cornerRadius = dp(12).toFloat(); setColor(Color.parseColor(bgColor)); setStroke(1, Color.parseColor("#3D5AFE"))
            }
        }

        // Implementation detail.
        val titleBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            minimumHeight = 0
            setPadding(dp(5), dp(5), dp(5), dp(5))
            setBackgroundColor(Color.parseColor(bgColor))
        }
        if (titleIcon != null) {
            titleBar.addView(ImageView(this).apply {
                setImageResource(titleIcon)
                layoutParams = LinearLayout.LayoutParams(dp(18), dp(18)).apply { marginEnd = dp(6) }
                scaleType = ImageView.ScaleType.CENTER_INSIDE
            })
        }
        val titleText = TextView(this).apply {
            text = title; setTextColor(Color.parseColor("#F2F3F8")); textSize = 13f
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        titleBar.addView(titleText)

        // Implementation detail.
        if (title != "🎮 GG-AI Modifier") {
            titleBar.addView(TextView(this).apply {
                text = "back "; setTextColor(Color.parseColor("#FFFFFF")); textSize = 12f
                background = GradientDrawable().apply { cornerRadius = dp(4).toFloat(); setColor(Color.parseColor("#3D5AFE")) }
                setPadding(dp(5), dp(5), dp(5), dp(5))
                setOnClickListener { onBack?.invoke() ?: showMainMenu() }
            })
        }

        root.addView(titleBar)

        // Implementation detail.
        root.addView(View(this).apply {
            setBackgroundColor(Color.parseColor("#E8EAF6"))
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(1))
        })

        // Implementation detail.
        val contentArea = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f)
        }
        contentBuilder(contentArea)
        root.addView(contentArea)

        // Implementation detail.
        var pix = 0; var piy = 0; var ptx = 0f; var pty = 0f; var isDragging = false
        val dm = resources.displayMetrics

        titleBar.setOnTouchListener { _, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    pix = panelParams?.x ?: 0
                    piy = panelParams?.y ?: 0
                    ptx = e.rawX
                    pty = e.rawY
                    isDragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    isDragging = true
                    val dx = (e.rawX - ptx).toInt()
                    val dy = (e.rawY - pty).toInt()

                    // Implementation detail.
                    val screenW = dm.widthPixels
                    val screenH = dm.heightPixels
                    val panelW = panelParams?.width ?: 0
                    val panelH = panelParams?.height ?: 0

                    var newX = pix + dx
                    var newY = piy + dy

                    // Implementation detail.
                    newX = newX.coerceIn(-panelW / 2, screenW - panelW / 2)
                    newY = newY.coerceIn(0, screenH - panelH)

                    panelParams?.x = newX
                    panelParams?.y = newY
                    try { wm?.updateViewLayout(panel, panelParams) } catch (_: Exception) {}
                    true
                }
                MotionEvent.ACTION_UP -> {
                    isDragging
                }
                else -> false
            }
        }

        // Implementation detail.
        if (title == "🤖 AI Chat") {
            showFocusablePanel(root, w, h)
        } else {
            showPanel(root, w, h)
        }
    }

    // Implementation detail.

    private fun showLastOrMainMenu() {
        when (lastPanel) {
            "process" -> showProcessPanel()
            "search" -> showSearchPanel()
            "chat" -> showAIChatPanel()
            "script" -> showScriptPanel()
            else -> showMainMenu()
        }
    }

    private fun showMainMenu() {
        saveLastPanel("menu")
        makeDraggablePanel("GG-AI Modifier", { content ->
            val sv = ScrollView(this).apply {
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f)
            }
            val list = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(12), dp(8), dp(12), dp(8)) }

            list.addView(menuBtn("Attach Process", R.drawable.jingcheng) { showProcessPanel() })
            list.addView(menuBtn("Memory search", R.drawable.neichun) { showSearchPanel() })
            list.addView(menuBtn("AI Chat", R.drawable.ai) { showAIChatPanel() })
            list.addView(menuBtn("Script Library", R.drawable.jiaoben) { showScriptPanel() })

            sv.addView(list); content.addView(sv)

            // Implementation detail.
            val bar = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; setPadding(dp(12), dp(8), dp(12), dp(8)) }
            bar.addView(iconBtn(R.drawable.gb_xfc, "Overlay") { stopSelf() }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            bar.addView(iconBtn(R.drawable.ck_gb, "Menu") { closePanel() }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            content.addView(bar)
        }, 250, 380, titleIcon = R.drawable.xfc, bgColor = "#536DFE")
    }

    // Implementation detail.

    private fun showProcessPanel() {
        saveLastPanel("process")
        makeDraggablePanel("Select game process", { content ->
            val status = TextView(this).apply { text = "Scanning..."; setTextColor(Color.parseColor("#F2F3F8")); textSize = 12f; setPadding(dp(12), dp(8), dp(12), dp(4)) }
            content.addView(status)

            val sv = ScrollView(this).apply { layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f) }
            val list = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(8), dp(4), dp(8), dp(4)) }
            sv.addView(list); content.addView(sv)

            // Implementation detail.
            val bar = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; setPadding(dp(12), dp(4), dp(12), dp(8)) }
            bar.addView(iconBtn(R.drawable.shuaxing) { loadProcs(list, status) }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            bar.addView(iconBtn(R.drawable.ck_gb) { closePanel() }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            content.addView(bar)

            loadProcs(list, status)
        }, 300, 450, titleIcon = R.drawable.jingcheng, bgColor = "#213333")
    }

    private fun loadProcs(list: LinearLayout, status: TextView) {
        status.text = "Scanning..."; list.removeAllViews()
        Thread {
            val procs = ProcessManager.getProcessList(this@OverlayService).filter {
                val p = it["packageName"] as String
                p.isNotEmpty() && p.contains(".") && !p.startsWith("com.android.") && !p.startsWith("android.") &&
                        p != "system" && p != "zygote" && p != "zygote64"
            }
            handler.post {
                status.text = "Found ${procs.size} apps"
                for (proc in procs) {
                    val name = proc["processName"] as String; val pkg = proc["packageName"] as String; val pid = proc["pid"] as Int
                    val item = LinearLayout(this).apply {
                        orientation = LinearLayout.VERTICAL; setPadding(dp(12), dp(10), dp(12), dp(10))
                        background = GradientDrawable().apply { cornerRadius = dp(8).toFloat(); setColor(Color.parseColor("#304FFE")) }
                        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { bottomMargin = dp(4) }
                    }
                    item.addView(TextView(this).apply { text = name; setTextColor(Color.parseColor("#F2F3F8")); textSize = 14f })
                    item.addView(TextView(this).apply { text = "$pkg | PID: $pid"; setTextColor(Color.parseColor("#000000")); textSize = 11f })
                    item.setOnClickListener {
                        Thread {
                            val ok = MemoryEngine.attachProcess(pid)
                            handler.post {
                                status.text = if (ok) "✅ Attached: $name" else "❌ Attach failed"
                                // Implementation detail.
                                if (ok) {
                                    saveAttachedProcess(pid, pkg, name)
                                    searchResults = emptyList()
                                }
                            }
                        }.start()
                    }
                    list.addView(item)
                }
            }
        }.start()
    }

    // Implementation detail.
    private fun saveAttachedProcess(pid: Int, packageName: String, processName: String) {
        try {
            val prefs = getSharedPreferences("gg_overlay", Context.MODE_PRIVATE)
            prefs.edit().apply {
                putInt("attached_pid", pid)
                putString("attached_package", packageName)
                putString("attached_name", processName)
                putLong("attached_time", System.currentTimeMillis())
                apply()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    // Implementation detail.

    private var currentSearchMode = "exact"

    private fun showSearchPanel() {
        saveLastPanel("search")
        val dm = resources.displayMetrics
        val screenW = dm.widthPixels
        val screenH = dm.heightPixels
        val density = dm.density
        val isLandscape = screenW > screenH

        // Implementation detail.
        val panelWDp = if (isLandscape) ((screenW * 0.88f) / density).toInt().coerceIn(650, 900) else 320
        val panelHDp = if (isLandscape) ((screenH * 0.93f) / density).toInt().coerceIn(380, 550) else 520

        makeDraggablePanel("Memory search", { content ->
            val pid = MemoryEngine.getAttachedPid()

            if (isLandscape) {
                // Implementation detail.
                val mainRow = LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f)
                }

                // Implementation detail.
                val leftPanel = LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f)
                    setPadding(dp(8), dp(4), dp(4), dp(4))
                }

                // Implementation detail.
                val status = TextView(this).apply {
                    text = if (pid != null) "PID:$pid" else "⚠Not attached"
                    setTextColor(if (pid != null) Color.parseColor("#66BB6A") else Color.parseColor("#FF8F00"))
                    textSize = 11f
                }
                leftPanel.addView(status)

                // type Select
                val types = arrayOf("dword", "float", "double", "byte", "word", "qword")
                val typeSpinner = Spinner(this).apply {
                    adapter = ArrayAdapter(this@OverlayService, android.R.layout.simple_spinner_dropdown_item, types)
                    layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                }
                leftPanel.addView(typeSpinner)

                // Implementation detail.
                val modeRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; setPadding(0, dp(4), 0, dp(4)) }
                fun modeBtn(label: String, mode: String): Button {
                    return Button(this).apply {
                        text = label; textSize = 10f; setTextColor(Color.parseColor("#F2F3F8"))
                        background = GradientDrawable().apply {
                            cornerRadius = dp(4).toFloat()
                            setColor(if (currentSearchMode == mode) Color.parseColor("#3D5AFE") else Color.parseColor("#333333"))
                        }
                        setPadding(dp(4), dp(2), dp(4), dp(2))
                        layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply { marginEnd = dp(2) }
                        setOnClickListener { currentSearchMode = mode; showSearchPanel() }
                    }
                }
                modeRow.addView(modeBtn("Exact", "exact"))
                modeRow.addView(modeBtn("Fuzzy", "fuzzy"))
                modeRow.addView(modeBtn("Range", "range"))
                modeRow.addView(modeBtn("address ", "addr"))
                modeRow.addView(modeBtn("Machine code", "machine"))
                leftPanel.addView(modeRow)

                // Implementation detail.
                leftPanel.addView(View(this).apply {
                    setBackgroundColor(Color.parseColor("#E8EAF6"))
                    layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(1)).apply { topMargin = dp(4); bottomMargin = dp(4) }
                })

                // Implementation detail.
                buildSearchInputArea(leftPanel, status, typeSpinner, null, dp(4))

                // Implementation detail.
                leftPanel.addView(View(this).apply {
                    layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f)
                })

                // Implementation detail.
                val bar = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; setPadding(0, dp(4), 0, 0) }
                bar.addView(iconBtn(R.drawable.shuaxing) {
                    searchResults = emptyList(); selectedIndices.clear(); status.text = "Reset"
                    val resultList = leftPanel.tag as? LinearLayout
                    resultList?.removeAllViews()
                    resultList?.addView(TextView(this@OverlayService).apply {
                        text = "No results"; setTextColor(Color.parseColor("#3D5AFE")); textSize = 12f
                        setPadding(dp(8), dp(20), dp(8), dp(8)); gravity = Gravity.CENTER
                    })
                }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
                bar.addView(iconBtn(R.drawable.ck_gb) { closePanel() }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
                leftPanel.addView(bar)

                mainRow.addView(leftPanel)

                // Implementation detail.
                mainRow.addView(View(this).apply {
                    setBackgroundColor(Color.parseColor("#E8EAF6"))
                    layoutParams = LinearLayout.LayoutParams(dp(1), LinearLayout.LayoutParams.MATCH_PARENT)
                })

                // Implementation detail.
                val rightPanel = LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f)
                    setPadding(dp(4), dp(4), dp(8), dp(4))
                }

                val resultTitle = TextView(this).apply {
                    text = "Search results"; setTextColor(Color.parseColor("#4A6572")); textSize = 11f
                    setPadding(0, 0, 0, dp(4))
                }
                rightPanel.addView(resultTitle)

                // Implementation detail.
                val actionBarContainer = LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                }
                rightPanel.addView(actionBarContainer)

                val rsv = ScrollView(this).apply {
                    layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f)
                }
                val rl = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(0, 0, 0, 0) }
                rsv.addView(rl)

                if (searchResults.isNotEmpty()) {
                    status.text = "${searchResults.size} results"
                    updateSearchResults(rl, searchResults, actionBarContainer)
                } else {
                    rl.addView(TextView(this).apply {
                        text = "No results"; setTextColor(Color.parseColor("#3D5AFE")); textSize = 12f
                        setPadding(dp(8), dp(20), dp(8), dp(8)); gravity = Gravity.CENTER
                    })
                }

                rightPanel.addView(rsv)
                // Implementation detail.
                if (savedScrollY > 0) {
                    rsv.post { rsv.scrollY = savedScrollY; savedScrollY = 0 }
                }
                mainRow.addView(rightPanel)

                content.addView(mainRow)

                // Implementation detail.
                content.tag = rl
                leftPanel.tag = rl
            } else {
                // Implementation detail.
                val topRow = LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    setPadding(dp(8), dp(4), dp(8), dp(2))
                }
                val status = TextView(this).apply {
                    text = if (pid != null) "PID:$pid" else "⚠Not attached"
                    setTextColor(if (pid != null) Color.parseColor("#66BB6A") else Color.parseColor("#FF8F00"))
                    textSize = 11f
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                }
                topRow.addView(status)

                val types = arrayOf("dword", "float", "double", "byte", "word", "qword")
                val typeSpinner = Spinner(this).apply {
                    adapter = ArrayAdapter(this@OverlayService, android.R.layout.simple_spinner_dropdown_item, types)
                    layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                }
                topRow.addView(typeSpinner)
                content.addView(topRow)

                val modeRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; setPadding(dp(6), dp(2), dp(6), dp(2)) }
                fun modeBtn(label: String, mode: String): Button {
                    return Button(this).apply {
                        text = label; textSize = 10f; setTextColor(Color.parseColor("#F2F3F8"))
                        background = GradientDrawable().apply {
                            cornerRadius = dp(4).toFloat()
                            setColor(if (currentSearchMode == mode) Color.parseColor("#3D5AFE") else Color.parseColor("#333333"))
                        }
                        setPadding(dp(4), dp(2), dp(4), dp(2))
                        layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply { marginEnd = dp(2) }
                        setOnClickListener { currentSearchMode = mode; showSearchPanel() }
                    }
                }
                modeRow.addView(modeBtn("Exact", "exact"))
                modeRow.addView(modeBtn("Fuzzy", "fuzzy"))
                modeRow.addView(modeBtn("Range", "range"))
                modeRow.addView(modeBtn("address ", "addr"))
                modeRow.addView(modeBtn("Machine code", "machine"))
                content.addView(modeRow)

                // Implementation detail.
                buildSearchInputArea(content, status, typeSpinner, null, dp(12))

                // Implementation detail.
                val actionBarContainer = LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                }
                content.addView(actionBarContainer)

                // Implementation detail.
                val rsv = ScrollView(this).apply { layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f) }
                val rl = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(6), dp(2), dp(6), dp(2)) }
                rsv.addView(rl)
                // Implementation detail.
                content.tag = rl
                if (searchResults.isNotEmpty()) {
                    status.text = "${searchResults.size} results"
                    updateSearchResults(rl, searchResults, actionBarContainer)
                }
                content.addView(rsv)
                // Implementation detail.
                if (savedScrollY > 0) {
                    rsv.post { rsv.scrollY = savedScrollY; savedScrollY = 0 }
                }

                val bar = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; setPadding(dp(8), dp(2), dp(8), dp(4)) }
                bar.addView(iconBtn(R.drawable.shuaxing) {
                    searchResults = emptyList(); selectedIndices.clear(); status.text = "Reset"
                    rl.removeAllViews()
                }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
                bar.addView(iconBtn(R.drawable.ck_gb) { closePanel() }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
                content.addView(bar)
            }
        }, panelWDp, panelHDp, titleIcon = R.drawable.neichun, bgColor = "#213333")
    }

    // Implementation detail.
    private fun buildSearchInputArea(parent: LinearLayout, status: TextView, typeSpinner: Spinner, rl: LinearLayout?, inputPadding: Int) {
        // Implementation detail.
        fun getResultList(): LinearLayout? = rl ?: (parent.tag as? LinearLayout)

        when (currentSearchMode) {
            "exact" -> {
                val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; setPadding(inputPadding, dp(2), inputPadding, dp(2)) }
                val inp = EditText(this).apply {
                    hint = "Enter a value"; setTextColor(Color.parseColor("#FFFFFF")); setHintTextColor(Color.parseColor("#FFFFFF"))
                    background = GradientDrawable().apply { cornerRadius = dp(6).toFloat(); setColor(Color.parseColor("#304FFE")) }
                    setPadding(dp(8), dp(6), dp(8), dp(6)); textSize = 13f
                    inputType = android.text.InputType.TYPE_CLASS_NUMBER or android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL or android.text.InputType.TYPE_NUMBER_FLAG_SIGNED
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    setText(savedSearchInput)
                }
                row.addView(inp)
                row.addView(iconBtn(R.drawable.bt_shuousuo) {
                    val v = inp.text.toString()
                    if (v.isEmpty()) { status.text = "❌Enter a value"; return@iconBtn }
                    savedSearchInput = v
                    if (MemoryEngine.getAttachedPid() == null) { status.text = "❌Attach first"; return@iconBtn }
                    val dtype = typeSpinner.selectedItem.toString(); searchDataType = dtype
                    status.text = "Searching..."
                    val resultList = getResultList()
                    resultList?.removeAllViews(); searchResults = emptyList()
                    Thread {
                        val t = System.currentTimeMillis()
                        val nv: Any = if (dtype == "float" || dtype == "double") v.toDoubleOrNull() ?: 0.0 else v.toLongOrNull() ?: 0
                        val res = MemoryEngine.searchExact(nv, dtype)
                        searchResults = res
                        notifySearchComplete(res.size, t)
                    }.start()
                })
                parent.addView(row)

                val fRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; setPadding(inputPadding, dp(2), inputPadding, dp(2)) }
                val fInp = EditText(this).apply {
                    hint = "New value (filter)"; setTextColor(Color.parseColor("#FFFFFF")); setHintTextColor(Color.parseColor("#FFFFFF"))
                    background = GradientDrawable().apply { cornerRadius = dp(6).toFloat(); setColor(Color.parseColor("#304FFE")) }
                    setPadding(dp(8), dp(6), dp(8), dp(6)); textSize = 13f
                    inputType = android.text.InputType.TYPE_CLASS_NUMBER or android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL or android.text.InputType.TYPE_NUMBER_FLAG_SIGNED
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    setText(savedFilterInput)
                }
                fRow.addView(fInp)
                fRow.addView(iconBtn(R.drawable.bt_guolv) {
                    val v = fInp.text.toString()
                    if (v.isEmpty() || searchResults.isEmpty()) { status.text = "❌Search first"; return@iconBtn }
                    savedFilterInput = v
                    status.text = "Filtering..."
                    val resultList = getResultList()
                    Thread {
                        val t = System.currentTimeMillis()
                        val nv: Any = if (searchDataType == "float" || searchDataType == "double") v.toDoubleOrNull() ?: 0.0 else v.toLongOrNull() ?: 0
                        val res = MemoryEngine.filterResults(searchResults.mapNotNull { (it["addressInt"] as? Number)?.toLong() }, nv, searchDataType)
                        searchResults = res
                        notifySearchComplete(res.size, t)
                    }.start()
                })
                parent.addView(fRow)
            }
            "fuzzy" -> {
                val grid = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(inputPadding, dp(2), inputPadding, dp(2)) }
                fun fuzzyBtn(label: String, cmp: String, color: String): Button {
                    return Button(this).apply {
                        text = label; textSize = 11f; setTextColor(Color.parseColor("#F2F3F8"))
                        background = GradientDrawable().apply { cornerRadius = dp(6).toFloat(); setColor(Color.parseColor(color)) }
                        setPadding(dp(8), dp(4), dp(8), dp(4))
                        layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply { marginEnd = dp(3); bottomMargin = dp(2) }
                        setOnClickListener {
                            if (MemoryEngine.getAttachedPid() == null) { status.text = "❌Attach first"; return@setOnClickListener }
                            val dtype = typeSpinner.selectedItem.toString(); searchDataType = dtype
                            status.text = "FuzzySearch..."
                            Thread {
                                try {
                                    val t = System.currentTimeMillis()
                                    val res = MemoryEngine.searchFuzzy(cmp, dtype)
                                    searchResults = res
                                    notifySearchComplete(res.size, t)
                                } catch (_: Exception) {}
                            }.start()
                        }
                    }
                }
                val r1 = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
                r1.addView(fuzzyBtn("Increased", "increased", "#E53935"))
                r1.addView(fuzzyBtn("Decreased", "decreased", "#43A047"))
                r1.addView(fuzzyBtn("Unchanged", "unchanged", "#1E88E5"))
                r1.addView(fuzzyBtn("Changed", "changed", "#FB8C00"))
                grid.addView(r1)
                parent.addView(grid)
            }
            "range" -> {
                val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; setPadding(inputPadding, dp(2), inputPadding, dp(2)) }
                val minInp = EditText(this).apply {
                    hint = "Min"; setTextColor(Color.parseColor("#FFFFFF")); setHintTextColor(Color.parseColor("#FFFFFF"))
                    background = GradientDrawable().apply { cornerRadius = dp(6).toFloat(); setColor(Color.parseColor("#304FFE")) }
                    setPadding(dp(8), dp(6), dp(8), dp(6)); textSize = 13f
                    inputType = android.text.InputType.TYPE_CLASS_NUMBER or android.text.InputType.TYPE_NUMBER_FLAG_SIGNED
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    setText(savedRangeMin)
                }
                val maxInp = EditText(this).apply {
                    hint = "Max"; setTextColor(Color.parseColor("#FFFFFF")); setHintTextColor(Color.parseColor("#FFFFFF"))
                    background = GradientDrawable().apply { cornerRadius = dp(6).toFloat(); setColor(Color.parseColor("#304FFE")) }
                    setPadding(dp(8), dp(6), dp(8), dp(6)); textSize = 13f
                    inputType = android.text.InputType.TYPE_CLASS_NUMBER or android.text.InputType.TYPE_NUMBER_FLAG_SIGNED
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    setText(savedRangeMax)
                }
                row.addView(minInp)
                row.addView(TextView(this).apply { text = "~"; setTextColor(Color.parseColor("#F2F3F8")); setPadding(dp(4), dp(6), dp(4), dp(6)) })
                row.addView(maxInp)
                row.addView(smallBtn("Scan") {
                    val lo = minInp.text.toString().toLongOrNull()
                    val hi = maxInp.text.toString().toLongOrNull()
                    if (lo == null || hi == null) { status.text = "❌Enter a range"; return@smallBtn }
                    savedRangeMin = minInp.text.toString()
                    savedRangeMax = maxInp.text.toString()
                    if (MemoryEngine.getAttachedPid() == null) { status.text = "❌Attach first"; return@smallBtn }
                    val dtype = typeSpinner.selectedItem.toString(); searchDataType = dtype
                    status.text = "Scanning range..."
                    val resultList = getResultList()
                    resultList?.removeAllViews(); searchResults = emptyList()
                    Thread {
                        val t = System.currentTimeMillis()
                        val res = MemoryEngine.searchByRange(lo, hi, dtype)
                        searchResults = res
                        notifySearchComplete(res.size, t)
                    }.start()
                })
                parent.addView(row)
            }
            "addr" -> {
                val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; setPadding(inputPadding, dp(2), inputPadding, dp(2)) }
                val inp = EditText(this).apply {
                    hint = "0x728B3A4D"; setTextColor(Color.parseColor("#FFFFFF")); setHintTextColor(Color.parseColor("#FFFFFF"))
                    background = GradientDrawable().apply { cornerRadius = dp(6).toFloat(); setColor(Color.parseColor("#304FFE")) }
                    setPadding(dp(8), dp(6), dp(8), dp(6)); textSize = 13f
                    inputType = android.text.InputType.TYPE_CLASS_TEXT
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    setText(savedSearchInput)
                }
                row.addView(inp)
                row.addView(smallBtn("read ") {
                    val addr = inp.text.toString().trim()
                    if (addr.isEmpty()) { status.text = "❌Enter an address"; return@smallBtn }
                    savedSearchInput = addr
                    if (MemoryEngine.getAttachedPid() == null) { status.text = "❌Attach first"; return@smallBtn }
                    searchDataType = "addr"
                    status.text = "Reading..."
                    val resultList = getResultList()
                    resultList?.removeAllViews(); searchResults = emptyList()
                    Thread {
                        val t = System.currentTimeMillis()
                        val res = MemoryEngine.searchAob(addr)
                        searchResults = res
                        notifySearchComplete(res.size, t)
                    }.start()
                })
                parent.addView(row)
            }
            "machine" -> {
                val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; setPadding(inputPadding, dp(2), inputPadding, dp(2)) }
                val inp = EditText(this).apply {
                    hint = "48 89 5C 24 ?? CC"; setTextColor(Color.parseColor("#FFFFFF")); setHintTextColor(Color.parseColor("#FFFFFF"))
                    background = GradientDrawable().apply { cornerRadius = dp(6).toFloat(); setColor(Color.parseColor("#304FFE")) }
                    setPadding(dp(8), dp(6), dp(8), dp(6)); textSize = 13f
                    inputType = android.text.InputType.TYPE_CLASS_TEXT
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    setText(savedSearchInput)
                }
                row.addView(inp)
                row.addView(iconBtn(R.drawable.bt_shuousuo) {
                    val pattern = inp.text.toString().trim()
                    if (pattern.isEmpty()) { status.text = "❌enter Machine code"; return@iconBtn }
                    savedSearchInput = pattern
                    if (MemoryEngine.getAttachedPid() == null) { status.text = "❌Attach first"; return@iconBtn }
                    searchDataType = "aob"
                    status.text = "Scanning..."
                    val resultList = getResultList()
                    resultList?.removeAllViews(); searchResults = emptyList()
                    Thread {
                        val t = System.currentTimeMillis()
                        val res = MemoryEngine.searchAob(pattern)
                        searchResults = res
                        notifySearchComplete(res.size, t)
                    }.start()
                })
                parent.addView(row)
            }
        }
    }

    // Implementation detail.
    private fun notifySearchComplete(count: Int, startTime: Long) {
        val elapsed = String.format("%.2f", (System.currentTimeMillis() - startTime) / 1000.0)
        try {
            handler.post {
                try {
                    // Implementation detail.
                    refreshCurrentPanel()
                    Toast.makeText(this, "${count} results ${elapsed}s", Toast.LENGTH_SHORT).show()
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }

    // Implementation detail.
    private fun refreshCurrentPanel() {
        val content = panel as? android.view.ViewGroup ?: return
        // Implementation detail.
        fun findResultList(v: android.view.ViewGroup): LinearLayout? {
            for (i in 0 until v.childCount) {
                val child = v.getChildAt(i)
                if (child is android.widget.ScrollView) {
                    val inner = child.getChildAt(0)
                    if (inner is LinearLayout) return inner
                }
                if (child is android.view.ViewGroup) {
                    val found = findResultList(child)
                    if (found != null) return found
                }
            }
            return null
        }
        // Implementation detail.
        fun findActionBarContainer(v: android.view.ViewGroup): LinearLayout? {
            for (i in 0 until v.childCount) {
                val child = v.getChildAt(i)
                if (child is LinearLayout && child.childCount > 0) {
                    val firstChild = child.getChildAt(0)
                    if (firstChild is Button && (firstChild.text?.toString()?.contains("All") == true)) {
                        return child
                    }
                }
                if (child is android.view.ViewGroup) {
                    val found = findActionBarContainer(child)
                    if (found != null) return found
                }
            }
            return null
        }
        val rl = findResultList(content) ?: return
        val abc = findActionBarContainer(content)
        if (searchResults.isNotEmpty()) {
            updateSearchResults(rl, searchResults, abc)
        }
    }

    private fun updateSearchResults(rl: LinearLayout, results: List<Map<String, Any>>, actionBarContainer: LinearLayout? = null) {
        rl.removeAllViews()
        actionBarContainer?.removeAllViews()
        selectedIndices.clear()

        if (results.isEmpty()) {
            if (actionBarContainer != null) {
                actionBarContainer.visibility = android.view.View.GONE
            }
            rl.addView(TextView(this).apply { text = "No results found"; setTextColor(Color.parseColor("#4A6572")); textSize = 11f; setPadding(dp(8), dp(4), dp(8), dp(4)) })
            return
        }

        // Implementation detail.
        val actionBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(dp(2), dp(2), dp(2), dp(4))
            background = GradientDrawable().apply { cornerRadius = dp(4).toFloat(); setColor(Color.parseColor("#213333")) }
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { bottomMargin = dp(4) }
        }

        // Implementation detail.
        val displayCount = minOf(results.size, 300)

        // Implementation detail.
        fun actionBtn(text: String, onClick: () -> Unit): Button {
            return Button(this).apply {
                this.text = text; setTextColor(Color.parseColor("#F2F3F8")); textSize = 11f
                background = GradientDrawable().apply { cornerRadius = dp(4).toFloat(); setColor(Color.parseColor("#3D5AFE")) }
                setPadding(dp(4), dp(0), dp(4), dp(0))
                layoutParams = LinearLayout.LayoutParams(0, dp(30), 1f).apply { marginEnd = dp(2) }
                setOnClickListener { onClick() }
            }
        }

        // Select all/Deselect all
        actionBar.addView(actionBtn("☑All") {
            if (selectedIndices.size >= displayCount) {
                selectedIndices.clear()
            } else {
                selectedIndices.clear()
                for (i in 0 until displayCount) {
                    selectedIndices.add(i)
                }
            }
            updateSearchResults(rl, results, actionBarContainer)
        })

        // Implementation detail.
        actionBar.addView(actionBtn("📋Addresses") {
            if (selectedIndices.isEmpty()) { Toast.makeText(this, "Select items first", Toast.LENGTH_SHORT).show(); return@actionBtn }
            val addrs = selectedIndices.map { results[it]["address"] as String }.joinToString("\n")
            copyToClipboard(addrs)
            Toast.makeText(this, "Copied ${selectedIndices.size} addresses", Toast.LENGTH_SHORT).show()
        })

        // Implementation detail.
        actionBar.addView(actionBtn("📋Codes") {
            if (selectedIndices.isEmpty()) { Toast.makeText(this, "Select items first", Toast.LENGTH_SHORT).show(); return@actionBtn }
            val codes = selectedIndices.map { results[it]["machineCode"] as? String ?: "" }.joinToString("\n")
            copyToClipboard(codes)
            Toast.makeText(this, "Copied ${selectedIndices.size} machine-code entries", Toast.LENGTH_SHORT).show()
        })

        // Implementation detail.
        actionBar.addView(actionBtn("📋value ") {
            if (selectedIndices.isEmpty()) { Toast.makeText(this, "Select items first", Toast.LENGTH_SHORT).show(); return@actionBtn }
            val vals = selectedIndices.map { "${results[it]["value"]}" }.joinToString("\n")
            copyToClipboard(vals)
            Toast.makeText(this, "Copied ${selectedIndices.size} values", Toast.LENGTH_SHORT).show()
        })

        // Implementation detail.
        actionBar.addView(actionBtn("🤖") {
            if (selectedIndices.isEmpty()) { Toast.makeText(this, "Select items first", Toast.LENGTH_SHORT).show(); return@actionBtn }
            val selectedResults = selectedIndices.map { results[it] }
            addResultsToAIChat(selectedResults)
            Toast.makeText(this, "Added ${selectedIndices.size} items to AI", Toast.LENGTH_SHORT).show()
        })

        // Implementation detail.
        actionBar.addView(actionBtn("✏️") {
            if (selectedIndices.isEmpty()) { Toast.makeText(this, "Select items first", Toast.LENGTH_SHORT).show(); return@actionBtn }
            val selectedResults = selectedIndices.map { results[it] }
            showBatchEditDialog(selectedResults)
        })

        if (actionBarContainer != null) {
            actionBarContainer.addView(actionBar)
            actionBarContainer.visibility = android.view.View.VISIBLE
        } else {
            rl.addView(actionBar)
        }

        // Implementation detail.
        for (index in 0 until displayCount) {
            val r = results[index]
            val addr = r["address"] as String
            val v = r["value"]
            val mc = r["machineCode"] as? String ?: ""
            val displayText = if (mc.isNotEmpty()) "${index+1}. $mc=$v" else "${index+1}. $addr=$v"
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL; setPadding(dp(4), dp(3), dp(4), dp(3))
                background = GradientDrawable().apply { cornerRadius = dp(4).toFloat(); setColor(Color.parseColor("#304FFE")) }
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { bottomMargin = dp(2) }
            }

            // Implementation detail.
            val checkBox = android.widget.CheckBox(this).apply {
                isChecked = selectedIndices.contains(index)
                buttonTintList = android.content.res.ColorStateList.valueOf(Color.parseColor("#3D5AFE"))
                setPadding(0, 0, dp(4), 0)
                setOnCheckedChangeListener { _, isChecked ->
                    if (isChecked) selectedIndices.add(index) else selectedIndices.remove(index)
                }
            }
            row.addView(checkBox)

            // Implementation detail.
            row.addView(TextView(this).apply {
                text = displayText; setTextColor(Color.parseColor("#3D5AFE")); textSize = 10f
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            })

            // Implementation detail.
            row.addView(miniBtn("Edit") {
                // Implementation detail.
                val sv = rl.parent as? android.widget.ScrollView
                savedScrollY = sv?.scrollY ?: 0
                showWriteDialog(addr, v, mc)
            })
            row.addView(miniBtn("Freeze") {
                val ai = addr.removePrefix("0x").removePrefix("0X").toLongOrNull(16)?.toInt() ?: return@miniBtn
                Thread { if (v != null) MemoryFreezer.freeze(ai, v, searchDataType) }.start()
            })

            rl.addView(row)
        }
    }

    // Copy to clipboard
    private fun copyToClipboard(text: String) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
        val clip = android.content.ClipData.newPlainText("search_results", text)
        clipboard.setPrimaryClip(clip)
    }

    // Implementation detail.
    private fun addResultsToAIChat(selectedResults: List<Map<String, Any>>) {
        val message = buildString {
            appendLine("📊 Search results analysis request:")
            appendLine()
            appendLine("Data type: $searchDataType")
            appendLine("Selected ${selectedResults.size} results:")
            appendLine()
            for ((i, r) in selectedResults.withIndex()) {
                val addr = r["address"] as String
                val v = r["value"]
                val mc = r["machineCode"] as? String ?: ""
                if (mc.isNotEmpty()) {
                    appendLine("${i+1}. Address: $addr, Machine code: $mc, value : $v")
                } else {
                    appendLine("${i+1}. Address: $addr, value : $v")
                }
            }
            appendLine()
            appendLine("Analyze these memory addresses and suggest possible edit approaches.")
        }

        // Implementation detail.
        chatMessages.add(Pair("👤 Me", message))

        // Implementation detail.
        // Implementation detail.
        Toast.makeText(this, "Added to AI chat. Open the AI Chat panel to view it.", Toast.LENGTH_SHORT).show()
    }

    private fun miniBtn(text: String, onClick: () -> Unit): Button {
        return Button(this).apply {
            this.text = text; setTextColor(Color.parseColor("#F2F3F8")); textSize = 10f
            background = GradientDrawable().apply { cornerRadius = dp(4).toFloat(); setColor(Color.parseColor("#3D5AFE")) }
            setPadding(dp(6), dp(0), dp(6), dp(0))
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, dp(28))
            setOnClickListener { onClick() }
        }
    }

    private fun showWriteDialog(addr: String, curVal: Any?, machineCode: String = "") {
        makeDraggablePanel("Edit memory value", { content ->
            content.addView(TextView(this).apply { text = "Address: $addr"; setTextColor(Color.parseColor("#4A6572")); textSize = 12f; setPadding(dp(12), dp(8), dp(12), dp(2)) })
            if (machineCode.isNotEmpty()) {
                content.addView(TextView(this).apply { text = "Machine code: $machineCode"; setTextColor(Color.parseColor("#3D5AFE")); textSize = 11f; setPadding(dp(12), dp(2), dp(12), dp(2)) })
            }
            content.addView(TextView(this).apply { text = "Current value: $curVal"; setTextColor(Color.parseColor("#4A6572")); textSize = 12f; setPadding(dp(12), dp(2), dp(12), dp(8)) })

            val inp = EditText(this).apply {
                hint = "Enter a new value"; setTextColor(Color.parseColor("#FFFFFF")); setHintTextColor(Color.parseColor("#FFFFFF"))
                background = GradientDrawable().apply { cornerRadius = dp(8).toFloat(); setColor(Color.parseColor("#304FFE")) }
                setPadding(dp(12), dp(8), dp(12), dp(8))
                inputType = android.text.InputType.TYPE_CLASS_NUMBER or android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL or android.text.InputType.TYPE_NUMBER_FLAG_SIGNED
                setText(curVal.toString())
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { marginStart = dp(12); marginEnd = dp(12) }
            }
            content.addView(inp)

            val bar = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; setPadding(dp(12), dp(12), dp(12), dp(8)) }
            bar.addView(smallBtn("Cancel") { showSearchPanel() }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            bar.addView(smallBtn("Confirm edit") {
                val nv = inp.text.toString()
                if (nv.isEmpty()) return@smallBtn
                val addrLong = addr.removePrefix("0x").removePrefix("0X").toLongOrNull(16) ?: return@smallBtn
                Thread {
                    val numVal: Any = when (searchDataType) {
                        "float", "double" -> nv.toDoubleOrNull() ?: 0.0
                        else -> nv.toLongOrNull() ?: 0
                    }
                    val success = MemoryEngine.writeMemory(addrLong, numVal, searchDataType)
                    // Implementation detail.
                    if (success) {
                        searchResults = searchResults.map { r ->
                            val rAddr = (r["addressInt"] as? Number)?.toLong()
                            if (rAddr == addrLong) {
                                r.toMutableMap().apply { this["value"] = numVal }
                            } else r
                        }
                    }
                    handler.post {
                        if (success) {
                            Toast.makeText(this@OverlayService, "✅ Edit succeeded: $addr = $numVal", Toast.LENGTH_SHORT).show()
                            showSearchPanel()
                        } else {
                            Toast.makeText(this@OverlayService, "❌ Edit failed", Toast.LENGTH_SHORT).show()
                        }
                    }
                }.start()
            }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            content.addView(bar)
        }, 280, 280, onBack = { showSearchPanel() })
    }

    // Implementation detail.
    private fun showBatchEditDialog(selectedResults: List<Map<String, Any>>) {
        val count = selectedResults.size
        makeDraggablePanel("Edit $count items", { content ->
            // Implementation detail.
            val addrList = selectedResults.joinToString("\n") { r ->
                val addr = r["address"] as String
                val v = r["value"]
                val mc = r["machineCode"] as? String ?: ""
                if (mc.isNotEmpty()) "$mc = $v" else "$addr = $v"
            }
            content.addView(TextView(this).apply {
                text = addrList; setTextColor(Color.parseColor("#4A6572")); textSize = 11f
                setPadding(dp(12), dp(8), dp(12), dp(8))
                maxLines = 6
            })

            // Enter a new value
            content.addView(TextView(this).apply {
                text = "Enter a new value (applied to all $count items):"; setTextColor(Color.parseColor("#F2F3F8")); textSize = 12f
                setPadding(dp(12), dp(8), dp(12), dp(4))
            })

            val inp = EditText(this).apply {
                hint = "Enter a new value"; setTextColor(Color.parseColor("#FFFFFF")); setHintTextColor(Color.parseColor("#FFFFFF"))
                background = GradientDrawable().apply { cornerRadius = dp(8).toFloat(); setColor(Color.parseColor("#304FFE")) }
                setPadding(dp(12), dp(8), dp(12), dp(8))
                inputType = android.text.InputType.TYPE_CLASS_NUMBER or android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL or android.text.InputType.TYPE_NUMBER_FLAG_SIGNED
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { marginStart = dp(12); marginEnd = dp(12) }
            }
            content.addView(inp)

            // button
            val bar = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; setPadding(dp(12), dp(12), dp(12), dp(8)) }
            bar.addView(smallBtn("Cancel") { showSearchPanel() }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            bar.addView(smallBtn("Confirm edit") {
                val nv = inp.text.toString()
                if (nv.isEmpty()) return@smallBtn

                val numVal: Any = when (searchDataType) {
                    "float", "double" -> nv.toDoubleOrNull() ?: 0.0
                    else -> nv.toLongOrNull() ?: 0
                }

                Thread {
                    var successCount = 0
                    for (r in selectedResults) {
                        val addr = r["address"] as String
                        val addrLong = addr.removePrefix("0x").removePrefix("0X").toLongOrNull(16) ?: continue
                        val success = MemoryEngine.writeMemory(addrLong, numVal, searchDataType)
                        if (success) {
                            successCount++
                            // Implementation detail.
                            searchResults = searchResults.map { sr ->
                                val srAddr = (sr["addressInt"] as? Number)?.toLong()
                                if (srAddr == addrLong) {
                                    sr.toMutableMap().apply { this["value"] = numVal }
                                } else sr
                            }
                        }
                    }
                    handler.post {
                        if (successCount == count) {
                            Toast.makeText(this@OverlayService, "✅ Edited $successCount items to $numVal", Toast.LENGTH_SHORT).show()
                        } else {
                            Toast.makeText(this@OverlayService, "⚠️ Edit complete: $successCount/$count succeeded", Toast.LENGTH_SHORT).show()
                        }
                        selectedIndices.clear()
                        showSearchPanel()
                    }
                }.start()
            }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            content.addView(bar)
        }, 300, 350)
    }

    // Implementation detail.

    private fun jumpToPage(page: String) {
        closePanel()
        try {
            // Implementation detail.
            val prefs = getSharedPreferences("gg_overlay", Context.MODE_PRIVATE)
            prefs.edit().putString("pending_page", page).apply()

            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("page", page)
            }
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    // Implementation detail.

    private fun showAIChatPanel() {
        saveLastPanel("chat")
        makeDraggablePanel("AI Chat", { content ->
            // Implementation detail.
            content.setBackgroundColor(Color.parseColor("#213333"))

            // Implementation detail.
            val prefs = getSharedPreferences("gg_overlay", Context.MODE_PRIVATE)
            val attachedPid = prefs.getInt("attached_pid", -1)
            val attachedName = prefs.getString("attached_name", "")
            val attachedPackage = prefs.getString("attached_package", "")

            // status display
            val status = TextView(this).apply {
                text = if (attachedPid != -1 && !attachedName.isNullOrEmpty()) {
                    "✅ Attached: $attachedName"
                } else {
                    "⚠️ not Attach Process,Attach firstgame "
                }
                setTextColor(if (attachedPid != -1) Color.parseColor("#66BB6A") else Color.parseColor("#FF8F00"))
                textSize = 11f
                setPadding(dp(12), dp(8), dp(12), dp(4))
            }
            content.addView(status)

            // Implementation detail.
            content.addView(View(this).apply {
                setBackgroundColor(Color.parseColor("#304FFE"))
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(1))
            })

            // Implementation detail.
            val messageArea = ScrollView(this).apply {
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f)
                background = GradientDrawable().apply {
                    cornerRadius = dp(8).toFloat()
                    setColor(Color.parseColor("#213333"))
                }
            }
            val messageList = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(8), dp(8), dp(8), dp(8))
            }

            // Implementation detail.
            if (chatMessages.isEmpty()) {
                val welcomeMsg = if (attachedPid != -1 && !attachedName.isNullOrEmpty()) {
                    "🤖 AI assistant ready!\n\nCurrently attached: $attachedName\n\nWhat game data would you like to edit?\n\n💡 Notice:If you switch processes, clear the chat so the AI does not use stale context"
                } else {
                    "🤖 AI assistant\n\n⚠️ Attach to a game process first\ntap back  → Attach Process"
                }
                chatMessages.add(Pair("🤖 AI", welcomeMsg))
            }

            // Implementation detail.
            for ((sender, msg) in chatMessages) {
                val isUser = sender == "👤 Me"
                messageList.addView(createMessageBubble(sender, msg, isUser))
            }

            messageArea.addView(messageList)
            content.addView(messageArea)

            // Implementation detail.
            if (savedScrollY > 0) {
                val restoreY = savedScrollY
                savedScrollY = 0
                messageArea.post { messageArea.scrollY = restoreY }
                // Implementation detail.
                messageArea.postDelayed({ messageArea.scrollY = restoreY }, 500)
                messageArea.postDelayed({ messageArea.scrollY = restoreY }, 1500)
            } else {
                messageArea.post { messageArea.fullScroll(ScrollView.FOCUS_DOWN) }
                messageArea.postDelayed({ messageArea.fullScroll(ScrollView.FOCUS_DOWN) }, 500)
                messageArea.postDelayed({ messageArea.fullScroll(ScrollView.FOCUS_DOWN) }, 1500)
            }

            // Implementation detail.
            val inputArea = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(dp(5), dp(5), dp(5), dp(5))
                setBackgroundColor(Color.parseColor("#213333"))
            }

            val inputField = EditText(this).apply {
                hint = "Describe what you need..."
                setTextColor(Color.parseColor("#000000"))
                setHintTextColor(Color.parseColor("#4A6572"))
                textSize = 13f
                background = GradientDrawable().apply {
                    cornerRadius = dp(6).toFloat()
                    setColor(Color.parseColor("#304FFE"))
                    setStroke(dp(1), Color.WHITE)
                }
                setPadding(dp(5), dp(5), dp(5), dp(5))
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)

                isFocusable = true
                isFocusableInTouchMode = true

                setOnClickListener {
                    requestFocus()
                    post {
                        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
                        imm.showSoftInput(this, android.view.inputmethod.InputMethodManager.SHOW_FORCED)
                    }
                }

                setOnFocusChangeListener { _, hasFocus ->
                    if (hasFocus) {
                        post {
                            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
                            imm.showSoftInput(this, android.view.inputmethod.InputMethodManager.SHOW_FORCED)
                        }
                    }
                }

                post {
                    requestFocus()
                    val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
                    imm.showSoftInput(this, android.view.inputmethod.InputMethodManager.SHOW_FORCED)
                }
            }

            val sendBtn = TextView(this).apply {
                text = "Send"
                setTextColor(Color.parseColor("#F2F3F8"))
                textSize = 12f
                gravity = android.view.Gravity.CENTER
                background = GradientDrawable().apply {
                    cornerRadius = dp(6).toFloat()
                    setColor(Color.parseColor("#536DFE"))
                }
                setPadding(dp(5), dp(5), dp(5), dp(5))
                setOnClickListener {
                    val userInput = inputField.text.toString().trim()
                    if (userInput.isNotEmpty() && !isAiResponding) {
                        // Implementation detail.
                        chatMessages.add(Pair("👤 Me", userInput))
                        messageList.addView(createMessageBubble("👤 Me", userInput, true))
                        inputField.text.clear()

                        // Implementation detail.
                        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
                        imm.hideSoftInputFromWindow(inputField.windowToken, 0)

                        // Implementation detail.
                        isAiResponding = true
                        val streamBubble = LinearLayout(this@OverlayService).apply {
                            orientation = LinearLayout.VERTICAL
                            layoutParams = LinearLayout.LayoutParams(
                                LinearLayout.LayoutParams.MATCH_PARENT,
                                LinearLayout.LayoutParams.WRAP_CONTENT
                            ).apply { bottomMargin = dp(8) }
                        }
                        streamBubble.addView(TextView(this@OverlayService).apply {
                            text = "🤖 AI"
                            setTextColor(Color.parseColor("#3D5AFE"))
                            textSize = 11f
                            setPadding(0, 0, 0, dp(2))
                        })
                        val streamText = TextView(this@OverlayService).apply {
                            text = "Thinking..."
                            setTextColor(Color.parseColor("#F2F3F8"))
                            textSize = 12f
                            background = GradientDrawable().apply {
                                cornerRadius = dp(8).toFloat()
                                setColor(Color.parseColor("#304FFE"))
                            }
                            setPadding(dp(12), dp(8), dp(12), dp(8))
                        }
                        streamBubble.addView(streamText)
                        messageList.addView(streamBubble)
                        messageArea.post { messageArea.fullScroll(ScrollView.FOCUS_DOWN) }

                        // Implementation detail.
                        Thread {
                            try {
                                val result = callLlmApi(userInput, attachedName ?: "")
                                handler.post {
                                    chatMessages.add(Pair("🤖 AI", result))
                                    isAiResponding = false
                                    streamBubble.removeView(streamText)
                                    streamBubble.addView(createMarkdownWebView(result))
                                    messageArea.post { messageArea.fullScroll(ScrollView.FOCUS_DOWN) }
                                }
                            } catch (e: Exception) {
                                handler.post {
                                    val errorMsg = "❌ Request failed: ${e.message}\n\nCheck the API configuration in Settings"
                                    chatMessages.add(Pair("🤖 AI", errorMsg))
                                    isAiResponding = false
                                    streamBubble.removeView(streamText)
                                    streamBubble.addView(createMarkdownWebView(errorMsg))
                                    messageArea.post { messageArea.fullScroll(ScrollView.FOCUS_DOWN) }
                                }
                            }
                        }.start()
                    }
                }
            }

            inputArea.addView(inputField)
            inputArea.addView(sendBtn)
            content.addView(inputArea)

            // Implementation detail.
            val actionBar = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(dp(5), dp(5), dp(5), dp(5))
            }
            val smallBtnStyle = { text: String, onClick: () -> Unit ->
                TextView(this).apply {
                    this.text = text; setTextColor(Color.parseColor("#F2F3F8")); textSize = 10f
                    gravity = android.view.Gravity.CENTER
                    background = GradientDrawable().apply { cornerRadius = dp(6).toFloat(); setColor(Color.parseColor("#536DFE")) }
                    setPadding(dp(5), dp(5), dp(5), dp(5))
                    setOnClickListener { onClick() }
                }
            }
            actionBar.addView(smallBtnStyle("Save") { saveChatToStorage() }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            actionBar.addView(smallBtnStyle("Clear") {
                chatMessages.clear()
                messageList.removeAllViews()
                val welcomeMsg = if (attachedPid != -1 && !attachedName.isNullOrEmpty()) {
                    "🤖 AI assistant ready!\n\nCurrently attached: $attachedName\n\nWhat game data would you like to edit?\n\n💡 Notice:If you switch processes, clear the chat so the AI does not use stale context"
                } else {
                    "🤖 AI assistant\n\n⚠️ Attach to a game process first"
                }
                chatMessages.add(Pair("🤖 AI", welcomeMsg))
                messageList.addView(createMessageBubble("🤖 AI", welcomeMsg, false))
            }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            actionBar.addView(smallBtnStyle("disable ") { closePanel() }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            content.addView(actionBar)

            // Implementation detail.
            messageArea.post { messageArea.fullScroll(ScrollView.FOCUS_DOWN) }

        }, 320, 550, titleIcon = R.drawable.ai, bgColor = "#000000")
    }

    // Implementation detail.
    private fun createMessageBubble(sender: String, message: String, isUser: Boolean): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), dp(6), dp(8), dp(6))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(8) }

            // Implementation detail.
            addView(TextView(this@OverlayService).apply {
                text = sender
                setTextColor(if (isUser) Color.parseColor("#3D5AFE") else Color.parseColor("#536DFE"))
                textSize = 11f
                setPadding(0, 0, 0, dp(2))
            })

            if (isUser) {
                // Implementation detail.
                addView(TextView(this@OverlayService).apply {
                    text = message
                    setTextColor(Color.parseColor("#F2F3F8"))
                    textSize = 12f
                    background = GradientDrawable().apply {
                        cornerRadius = dp(8).toFloat()
                        setColor(Color.parseColor("#304FFE"))
                    }
                    setPadding(dp(12), dp(8), dp(12), dp(8))
                })
            } else {
                // Implementation detail.
                // Implementation detail.
                addView(createMarkdownWebView(message))
            }
        }
    }

    /**
     * Implementation detail.
     * Implementation detail.
     */
    private fun preprocessLaTeX(content: String): String {
        var result = content

        // Implementation detail.
        val codeBlocks = mutableListOf<String>()
        val codeBlockRegex = Regex("(```[\\s\\S]*?```|`[^`\\n]+`)")
        result = codeBlockRegex.replace(result) { match ->
            codeBlocks.add(match.value)
            "<<CODE_BLOCK_${codeBlocks.size - 1}>>"
        }

        // Implementation detail.
        val latexExpressions = mutableListOf<String>()
        val latexRegex = Regex("(\\$\\$[\\s\\S]*?\\$\\$|\\$[^$\\n]*?\\$|\\\\\\[[\\s\\S]*?\\\\]|\\\\\\(.*?\\\\\\))")
        result = latexRegex.replace(result) { match ->
            latexExpressions.add(match.value)
            "<<LATEX_${latexExpressions.size - 1}>>"
        }

        // Implementation detail.
        result = result.replace(Regex("\\$(?=\\d)"), "\\$")

        // Implementation detail.
        result = result.replace(Regex("<<LATEX_(\\d+)>>")) { match ->
            val index = match.groupValues[1].toInt()
            latexExpressions[index]
        }

        // Implementation detail.
        result = result.replace(Regex("<<CODE_BLOCK_(\\d+)>>")) { match ->
            val index = match.groupValues[1].toInt()
            codeBlocks[index]
        }

        // Implementation detail.
        val bracketRegex = Regex("(```[\\S\\s]*?```|`.*?`)|\\\\\\[([\\S\\s]*?[^\\\\])\\\\]|\\\\\\((.*?)\\\\\\)")
        result = bracketRegex.replace(result) { match ->
            when {
                match.groupValues[1].isNotEmpty() -> match.groupValues[1] // Code block; skip
                match.groupValues[2].isNotEmpty() -> "$$${match.groupValues[2]}$$" // \[...\] -> $$...$$
                match.groupValues[3].isNotEmpty() -> "$${match.groupValues[3]}$" // \(...\) -> $...$
                else -> match.value
            }
        }

        return result
    }

    /**
     * Implementation detail.
     */
    private fun createMarkdownWebView(markdownContent: String): WebView {
        // Implementation detail.
        // Implementation detail.
        val escapedContent = markdownContent
            .replace("\\", "\\\\")
            .replace("'", "\\'")
            .replace("\n", "\\n")
            .replace("\r", "")

        val html = """
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        font-size: 14px;
        line-height: 1.6;
        color: #213333;
        background: #F2F3F8;
        padding: 10px;
        word-wrap: break-word;
        overflow-wrap: break-word;
    }
    h1, h2, h3, h4, h5, h6 {
        color: #304FFE;
        margin: 12px 0 6px 0;
        font-weight: 600;
    }
    h1 { font-size: 20px; }
    h2 { font-size: 17px; }
    h3 { font-size: 15px; }
    p { margin: 6px 0; }
    a { color: #3D5AFE; text-decoration: none; }
    code {
        background: #E8EAF6;
        color: #304FFE;
        padding: 2px 6px;
        border-radius: 4px;
        font-family: 'Courier New', monospace;
        font-size: 13px;
    }
    pre {
        background: #213333;
        border: 1px solid #3D5AFE;
        border-radius: 8px;
        padding: 12px;
        margin: 8px 0;
        overflow-x: auto;
    }
    pre code {
        background: none;
        padding: 0;
        color: #F2F3F8;
        font-size: 13px;
    }
    blockquote {
        border-left: 4px solid #3D5AFE;
        padding-left: 12px;
        margin: 8px 0;
        color: #4A6572;
    }
    ul, ol { margin: 6px 0; padding-left: 24px; }
    li { margin: 3px 0; }
    table {
        border-collapse: collapse;
        width: 100%;
        margin: 8px 0;
    }
    th, td {
        border: 1px solid #3D5AFE;
        padding: 6px 10px;
        text-align: left;
    }
    th { background: #213333; color: #F2F3F8; }
    hr { border: none; border-top: 1px solid #3D5AFE; margin: 12px 0; }
    img { max-width: 100%; border-radius: 8px; }
    strong { color: #213333; }
    em { color: #4A6572; }
    .mermaid {
        max-width: 100%;
        max-height: 400px;
        overflow: auto;
        -webkit-overflow-scrolling: touch;
        background: #213333;
        border-radius: 8px;
        padding: 8px;
        margin: 8px 0;
    }
    .mermaid svg {
        max-width: 100%;
        height: auto;
    }
    .table-wrapper {
        overflow-x: auto;
        -webkit-overflow-scrolling: touch;
        max-width: 100%;
    }
    /* Chat bubble */
    .msg { margin-bottom: 16px; }
    .msg-header { display: flex; align-items: center; gap: 6px; margin-bottom: 4px; }
    .msg-icon { font-size: 14px; }
    .msg-sender { font-size: 12px; color: #4A6572; }
    .msg-time { font-size: 10px; color: #4A6572; }
    .msg-user .msg-header { justify-content: flex-end; }
    .bubble { padding: 10px 14px; border-radius: 12px; max-width: 85%; word-break: break-word; }
    .bubble-user { background: #3D5AFE; border: 1px solid #FFFFFF; border-radius: 12px; padding: 10px 14px; margin-left: auto; color: #FFFFFF; }
    .bubble-ai { background: #FFFFFF; border: 1px solid #3D5AFE; border-radius: 12px; padding: 10px 14px; }
    .msg-user .msg-sender { color: #3D5AFE; }
    .msg-ai .msg-sender { color: #536DFE; }
</style>
<!-- Local library. -->
<link rel="stylesheet" href="file:///android_asset/css/prism-tomorrow.min.css">
<script src="file:///android_asset/js/prism.min.js"></script>
<!-- Local library. -->
<link rel="stylesheet" href="file:///android_asset/css/katex.min.css">
<script src="file:///android_asset/js/katex.min.js"></script>
<script src="file:///android_asset/js/auto-render.min.js"></script>
<!-- Local library. -->
<script src="file:///android_asset/js/marked.min.js"></script>
<!-- Local library. -->
<script src="file:///android_asset/js/mermaid.min.js"></script>
</head>
<body>
<div id="content"></div>
<script>
(function() {
    // Implementation detail.
    mermaid.initialize({
        startOnLoad: false,
        theme: 'dark',
        themeVariables: {
            primaryColor: '#3D5AFE',
            primaryTextColor: '#E0E0E0',
            primaryBorderColor: '#E8EAF6',
            lineColor: '#3D5AFE',
            secondaryColor: '#FFFFFF',
            tertiaryColor: '#F2F3F8'
        }
    });

    // Implementation detail.
    var renderer = new marked.Renderer();
    renderer.code = function(code, lang) {
        var codeText = (typeof code === 'object') ? code.text : code;
        var langStr = (typeof code === 'object') ? code.lang : lang;
        var escaped = codeText.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
        if (langStr && Prism.languages[langStr]) {
            try {
                var highlighted = Prism.highlight(codeText, Prism.languages[langStr], langStr);
                return '<pre class="language-' + langStr + '"><code class="language-' + langStr + '">' + highlighted + '</code></pre>';
            } catch(e) {}
        }
        return '<pre class="language-' + (langStr || 'none') + '"><code class="language-' + (langStr || 'none') + '">' + escaped + '</code></pre>';
    };
    marked.setOptions({ breaks: true, gfm: true, renderer: renderer });

    var rawContent = '___CONTENT_PLACEHOLDER___';

    // Implementation detail.
    var latexStore = [];
    function protectLaTeX(text) {
        // Implementation detail.
        var codeBlocks = [];
        text = text.replace(/(```[\s\S]*?```|`[^`\n]+`)/g, function(m, c) {
            codeBlocks.push(c);
            return '\x00CODE' + (codeBlocks.length-1) + '\x00';
        });
        // Implementation detail.
        text = text.replace(/\$\$([\s\S]*?)\$\$/g, function(m, inner) {
            latexStore.push('$$' + inner + '$$');
            return '\x00LATEX' + (latexStore.length-1) + '\x00';
        });
        // Implementation detail.
        text = text.replace(/\$([^\$\n]+?)\$/g, function(m, inner) {
            latexStore.push('$' + inner + '$');
            return '\x00LATEX' + (latexStore.length-1) + '\x00';
        });
        // Implementation detail.
        text = text.replace(/\\\[([\s\S]*?)\\\]/g, function(m, inner) {
            latexStore.push('$$' + inner + '$$');
            return '\x00LATEX' + (latexStore.length-1) + '\x00';
        });
        text = text.replace(/\\\((.*?)\\\)/g, function(m, inner) {
            latexStore.push('$' + inner + '$');
            return '\x00LATEX' + (latexStore.length-1) + '\x00';
        });
        // Implementation detail.
        text = text.replace(/\x00CODE(\d+)\x00/g, function(m, i) { return codeBlocks[parseInt(i)]; });
        return text;
    }

    // Implementation detail.
    var protectedContent = protectLaTeX(rawContent);

    // Implementation detail.
    var htmlContent = marked.parse(protectedContent);

    // Implementation detail.
    htmlContent = htmlContent.replace(/\x00LATEX(\d+)\x00/g, function(m, i) {
        return '<span class="katex-placeholder" data-latex="' +
            latexStore[parseInt(i)].replace(/&/g,'&amp;').replace(/"/g,'&quot;').replace(/</g,'&lt;').replace(/>/g,'&gt;') +
            '"></span>';
    });

    // Implementation detail.
    document.getElementById('content').innerHTML = htmlContent;

    // Implementation detail.
    var mermaidBlocks = document.querySelectorAll('code.language-mermaid');
    mermaidBlocks.forEach(function(block, idx) {
        var pre = block.parentElement;
        var div = document.createElement('div');
        div.className = 'mermaid';
        div.textContent = block.textContent;
        pre.parentNode.replaceChild(div, pre);
    });

    // Implementation detail.
    document.querySelectorAll('#content table').forEach(function(table) {
        var wrapper = document.createElement('div');
        wrapper.className = 'table-wrapper';
        table.parentNode.insertBefore(wrapper, table);
        wrapper.appendChild(table);
    });

    // Implementation detail.
    document.querySelectorAll('.katex-placeholder').forEach(function(el) {
        var latex = el.getAttribute('data-latex');
        try {
            var isDisplay = latex.substring(0, 2) === '$$';
            var tex = isDisplay ? latex.substring(2, latex.length - 2) : latex.substring(1, latex.length - 1);
            katex.render(tex, el, { displayMode: isDisplay, throwOnError: false });
        } catch(e) {
            el.textContent = latex;
            el.style.color = '#FF5252';
        }
    });

    // Implementation detail.
    var notifyDone = function() {
        // Implementation detail.
        window.__renderDone = true;
    };

    if (mermaidBlocks.length > 0) {
        // Implementation detail.
        if (typeof mermaid.run === 'function') {
            mermaid.run().then(function() { notifyDone(); }).catch(function(e) {
                console.error('Mermaid error:', e);
                notifyDone();
            });
        } else if (typeof mermaid.init === 'function') {
            try { mermaid.init(undefined, document.querySelectorAll('.mermaid')); } catch(e) { console.error(e); }
            notifyDone();
        } else {
            notifyDone();
        }
    } else {
        notifyDone();
    }
})();
</script>
</body>
</html>
""".trimIndent().replace("___CONTENT_PLACEHOLDER___", escapedContent)

        return WebView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            setBackgroundColor(Color.TRANSPARENT)
            settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                allowFileAccess = true
                allowContentAccess = true
                loadWithOverviewMode = true
                useWideViewPort = true
                builtInZoomControls = false
                displayZoomControls = false
                cacheMode = WebSettings.LOAD_DEFAULT
                mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
            }
            webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    // Implementation detail.
                    view?.evaluateJavascript(
                        """
                        (function() {
                            function checkAndMeasure() {
                                if (window.__renderDone) {
                                    return document.body.scrollHeight;
                                }
                                // Implementation detail.
                                var tries = 0;
                                var timer = setInterval(function() {
                                    tries++;
                                    if (window.__renderDone || tries > 50) {
                                        clearInterval(timer);
                                        var h = document.body.scrollHeight;
                                        window.__measuredHeight = h;
                                    }
                                }, 100);
                                return -1;
                            }
                            return checkAndMeasure();
                        })();
                        """.trimIndent()
                    ) { value ->
                        try {
                            val initial = value.replace("\"", "").toFloatOrNull() ?: 0f
                            if (initial > 0) {
                                // Implementation detail.
                                val layoutParams = this@apply.layoutParams
                                layoutParams.height = (initial * resources.displayMetrics.density).toInt() + dp(20)
                                this@apply.layoutParams = layoutParams
                            } else {
                                // Implementation detail.
                                val handler = android.os.Handler(android.os.Looper.getMainLooper())
                                val checkRunnable = object : Runnable {
                                    override fun run() {
                                        view?.evaluateJavascript("window.__measuredHeight || document.body.scrollHeight") { v ->
                                            try {
                                                val h = v.replace("\"", "").toFloatOrNull() ?: 0f
                                                if (h > 0) {
                                                    val lp = this@apply.layoutParams
                                                    lp.height = (h * resources.displayMetrics.density).toInt() + dp(20)
                                                    this@apply.layoutParams = lp
                                                } else {
                                                    handler.postDelayed(this, 200)
                                                }
                                            } catch (_: Exception) {}
                                        }
                                    }
                                }
                                handler.postDelayed(checkRunnable, 200)
                            }
                        } catch (_: Exception) {}
                    }
                }
            }
            loadDataWithBaseURL("file:///android_asset/", html, "text/html", "UTF-8", null)
        }
    }

    // Implementation detail.

    private fun callLlmApi(userInput: String, attachedApp: String): String {
        // Implementation detail.
        val configPrefs = getSharedPreferences("gg_llm_config", Context.MODE_PRIVATE)
        val configJson = configPrefs.getString("config", null)

        var baseUrl = ""
        var apiKey = ""
        var model = "deepseek-chat"

        if (configJson != null) {
            try {
                val json = JSONObject(configJson)
                baseUrl = json.optString("baseUrl", "")
                apiKey = json.optString("apiKey", "")
                model = json.optString("model", "deepseek-chat")
            } catch (e: Exception) {
                // Implementation detail.
            }
        }

        // Implementation detail.
        if (baseUrl.isEmpty() || apiKey.isEmpty()) {
            return "⚠️ Configure the LLM API in Settings first\n\nOpen the main app → Settings → LLM API Configuration\n\nSupported: DeepSeek, OpenAI, Xiaomi MiMo, and more"
        }

        // Implementation detail.
        val modelInfo = getModelInfo(model)
        val systemPrompt = buildString {
            append("You are GG-AI, a game-memory assistant. The underlying model is: $modelInfo.\n")
            append("When asked which model you are, answer exactly \"$modelInfo\". GG-AI is the app name, not the model name. Do not invent another model name.\n\n")
            append("## Core behavior rules\n")
            append("When the user requests a search, read, or edit, call the tool (search_memory / read_memory / write_memory) to perform the real operation and return real results.\n")
            append("Never simulate or invent search results or addresses. Do not write gg.searchNumber or similar code instead of performing the real operation.\n")
            append("The machine code in search results is the raw bytes at that address and can help verify it.\n")
            append("After editing, the tool reads the value back for verification. If the read-back value differs from the target, the write may have failed.\n\n")
            append("## Script generation\n")
            append("Only output a Lua script when the user explicitly asks to write or generate one.\n")
            append("Lua script requirements (luaj-jse-3.0.2.jar environment):\n")
            append("- use  GG API:gg.searchNumber, gg.getResults, gg.editAll, gg.clearResults\n")
            append("- type constants:gg.TYPE_DWORD, gg.TYPE_FLOAT, gg.TYPE_DOUBLE, gg.TYPE_BYTE, gg.TYPE_WORD, gg.TYPE_QWORD\n")
            append("- UI:gg.toast, gg.alert, gg.prompt, gg.choice\n")
            append("- Wrap it in a ```lua code block\n\n")
            if (attachedApp.isNotEmpty()) {
                    append("Currently attached game process: $attachedApp\n")
            }
            append("\nRendering support: The client supports Markdown rendering and code-block highlighting, LaTeX formulas and Mermaid diagrams.")
            append("When asked for a diagram, output a Mermaid code block directly without explanation.")
            append("Wrap it in a ```mermaid code block; the client renders it automatically.\n")
            append("⚠️ Mermaid version 8.14.0; use only compatible syntax:\n")
            append("- For flowcharts, use `graph TD`  or  `graph LR` (do not use flowchart)\n")
            append("- Supported chart types:graph, sequenceDiagram, classDiagram, stateDiagram, gantt, pie\n")
            append("- Unsupported:mindmap, timeline, quadrantChart, block-beta, sankey-beta, xychart-beta and other newer types \n")
            append("- do not use  `%%{init: ...}%%` configuration directives\n")
            append("- Wrap special characters in node text in double quotes, e.g. A[\"(special) text\"]\n")
            append("Example:\n")
            append("```mermaid\ngraph TD\n    A[Search coin value ] --> B[spend coins]\n    B --> C[search again]\n    C --> D[Confirm address ]\n    D --> E[Edit value]\n```\n\n")
            append("LaTeX formulas: use ${'$'}...${'$'} for inline formulas,${'$'}${'$'}...${'$'}${'$'} for display formulas.Example:${'$'}E=mc^2${'$'},${'$'}${'$'}\\int_0^1 x dx = \\frac{1}{2}${'$'}${'$'}\n\n")
            append("Response format:\n")
            append("- Use concise, friendly English\n")
            append("- List steps numerically\n")
            append("- Mark results with ✅ or ❌\n")
            append("- Display addresses and values as code \n")
            append("- When a diagram is requested, output only a Mermaid code block\n\n")

            // read Enabled of  Skill
            try {
                val skillsPrefs = getSharedPreferences("gg_skills", Context.MODE_PRIVATE)
                val skillsJson = skillsPrefs.getString("skills", "[]") ?: "[]"
                val skillsArray = org.json.JSONArray(skillsJson)
                if (skillsArray.length() > 0) {
                    append("## Imported Skills\n")
                    append("The following skills are enabled; use their knowledge when replying:\n\n")
                    for (i in 0 until skillsArray.length()) {
                        val skill = skillsArray.getJSONObject(i)
                        val name = skill.optString("name", "Unknown")
                        val content = skill.optString("content", "")
                        append("### 📖 $name\n")
                        append("$content\n\n")
                    }
                }
            } catch (e: Exception) {
                android.util.Log.w("GG-AI", "Failed to load skills: $e")
            }
        }

        // Implementation detail.
        val messages = JSONArray()
        messages.put(JSONObject().apply {
            put("role", "system")
            put("content", systemPrompt)
        })

        val recentMessages = chatMessages.takeLast(10)
        for ((sender, msg) in recentMessages) {
            val role = if (sender == "👤 Me") "user" else "assistant"
            messages.put(JSONObject().apply {
                put("role", role)
                put("content", msg)
            })
        }

        // Implementation detail.
        messages.put(JSONObject().apply {
            put("role", "user")
            put("content", userInput)
        })

        // Implementation detail.
        val isGemini = baseUrl.contains("generativelanguage.googleapis.com")
        // Implementation detail.
        // Implementation detail.
        val effectiveBaseUrl = if (isGemini) {
            val base = baseUrl.trimEnd('/')
            if (base.endsWith("/v1beta/openai")) base else "$base/v1beta/openai"
        } else {
            baseUrl.trimEnd('/')
        }

        // Implementation detail.
        val tools = JSONArray().apply {
            put(JSONObject().apply {
                put("type", "function")
                put("function", JSONObject().apply {
                    put("name", "search_memory")
                    put("description", "Search values in game memory. Supports exact, range, and AOB searches and returns matching addresses.")
                    put("parameters", JSONObject().apply {
                        put("type", "object")
                        put("properties", JSONObject().apply {
                            put("mode", JSONObject().apply {
                                put("type", "string")
                                put("description", "Search mode:exact(Exact), range(Range), aob(AOBSignature)")
                                put("enum", JSONArray().apply { put("exact"); put("range"); put("aob") })
                            })
                            put("value", JSONObject().apply {
                                put("type", "string")
                                put("description", "Search value. For exact mode, enter a value such as'750000';for range, use 'Minimum,Maximum' such as '100,200'; for AOB, use a signature such as '48 8B 05 ?? ??'")
                            })
                            put("type", JSONObject().apply {
                                put("type", "string")
                                put("description", "Data type:dword(integer, 4 bytes), float(float), double(double), byte(1 bytes), word(2 bytes), qword(8 bytes)")
                                put("enum", JSONArray().apply { put("dword"); put("float"); put("double"); put("byte"); put("word"); put("qword") })
                            })
                        })
                        put("required", JSONArray().apply { put("mode"); put("value") })
                    })
                })
            })
            put(JSONObject().apply {
                put("type", "function")
                put("function", JSONObject().apply {
                    put("name", "read_memory")
                    put("description", "Read a value from the specified memory address.")
                    put("parameters", JSONObject().apply {
                        put("type", "object")
                        put("properties", JSONObject().apply {
                            put("address", JSONObject().apply {
                                put("type", "string")
                                put("description", "memoryaddress ,hexadecimal, e.g.'0x12345678'")
                            })
                            put("type", JSONObject().apply {
                                put("type", "string")
                                put("description", "data type ")
                                put("enum", JSONArray().apply { put("dword"); put("float"); put("double"); put("byte"); put("word"); put("qword") })
                            })
                        })
                        put("required", JSONArray().apply { put("address"); put("type") })
                    })
                })
            })
            put(JSONObject().apply {
                put("type", "function")
                put("function", JSONObject().apply {
                    put("name", "write_memory")
                    put("description", "Write a value to the specified memory address.")
                    put("parameters", JSONObject().apply {
                        put("type", "object")
                        put("properties", JSONObject().apply {
                            put("address", JSONObject().apply {
                                put("type", "string")
                                put("description", "memoryaddress ,hexadecimal, e.g.'0x12345678'")
                            })
                            put("value", JSONObject().apply {
                                put("type", "string")
                                put("description", "write  of value ")
                            })
                            put("type", JSONObject().apply {
                                put("type", "string")
                                put("description", "data type ")
                                put("enum", JSONArray().apply { put("dword"); put("float"); put("double"); put("byte"); put("word"); put("qword") })
                            })
                        })
                        put("required", JSONArray().apply { put("address"); put("value"); put("type") })
                    })
                })
            })
        }

        // Implementation detail.
        val url = URL("$effectiveBaseUrl/chat/completions")
        android.util.Log.d("GG-AI", "API URL: $url")
        android.util.Log.d("GG-AI", "Model: $model")

        val requestBody = JSONObject().apply {
            put("model", model)
            put("messages", messages)
            put("tools", tools)
            put("temperature", 0.7)
            put("max_tokens", 2048)
        }

        val responseText = doHttpPost(url, apiKey, requestBody)
        val responseJson = JSONObject(responseText)
        val choices = responseJson.getJSONArray("choices")
        if (choices.length() == 0) return "❌ No AI response received"

        val msg = choices.getJSONObject(0).getJSONObject("message")

        // Implementation detail.
        if (msg.has("tool_calls") && !msg.isNull("tool_calls")) {
            messages.put(msg)

            val toolCalls = msg.getJSONArray("tool_calls")
            for (i in 0 until toolCalls.length()) {
                val toolCall = toolCalls.getJSONObject(i)
                val callId = toolCall.getString("id")
                val func = toolCall.getJSONObject("function")
                val funcName = func.getString("name")
                val funcArgs = JSONObject(func.getString("arguments"))

                val result = executeToolCall(funcName, funcArgs)

                messages.put(JSONObject().apply {
                    put("role", "tool")
                    put("tool_call_id", callId)
                    put("content", result)
                })
            }

            val finalRequestBody = JSONObject().apply {
                put("model", model)
                put("messages", messages)
                put("temperature", 0.7)
                put("max_tokens", 2048)
            }
            val finalResponseText = doHttpPost(url, apiKey, finalRequestBody)
            val finalJson = JSONObject(finalResponseText)
            val finalChoices = finalJson.getJSONArray("choices")
            if (finalChoices.length() > 0) {
                return finalChoices.getJSONObject(0).getJSONObject("message").getString("content")
            }
            return "❌ No AI response received"
        }

        return msg.optString("content", "❌ No AI response received")
    }

    private fun doHttpPost(url: URL, apiKey: String, body: JSONObject): String {
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("Content-Type", "application/json")
        conn.setRequestProperty("Authorization", "Bearer $apiKey")
        conn.doOutput = true
        conn.connectTimeout = 30000
        conn.readTimeout = 60000
        val writer = OutputStreamWriter(conn.outputStream, Charsets.UTF_8)
        writer.write(body.toString())
        writer.flush()
        writer.close()
        val code = conn.responseCode
        android.util.Log.d("GG-AI", "HTTP Response: $code, URL: ${url}")
        if (code != 200) {
            val err = conn.errorStream?.bufferedReader()?.readText() ?: "Unknown error"
            android.util.Log.e("GG-AI", "HTTP Error: $code, Body: $err")
            throw Exception("HTTP $code: $err")
        }
        val reader = BufferedReader(InputStreamReader(conn.inputStream, Charsets.UTF_8))
        val text = reader.readText()
        reader.close()
        conn.disconnect()
        return text
    }

    private fun executeToolCall(name: String, args: JSONObject): String {
        return try {
            when (name) {
                "search_memory" -> {
                    val mode = args.optString("mode", "exact")
                    val value = args.optString("value", "")
                    val type = args.optString("type", "dword")
                    if (MemoryEngine.getAttachedPid() == null) return "❌ No game process attached,Attach first"
                    when (mode) {
                        "exact" -> {
                            val numVal: Any = if (type == "float" || type == "double") value.toDoubleOrNull() ?: 0.0 else value.toLongOrNull() ?: 0
                            val res = MemoryEngine.searchExact(numVal, type)
                            if (res.isEmpty()) return "Search complete; no results found"
                            val sb = StringBuilder("Found ${res.size}  results:\n")
                            for ((idx, r) in res.take(50).withIndex()) {
                                val addr = r["address"] ?: ""
                                val mc = r["machineCode"] ?: ""
                                val v = r["value"] ?: ""
                                sb.append("${idx + 1}. $addr [$mc] = $v\n")
                            }
                            if (res.size > 50) sb.append("... ${res.size} total results")
                            sb.append("\nAnalyze the machine code to identify the target address, then use write_memory to edit it.")
                            sb.toString()
                        }
                        "range" -> {
                            val parts = value.split(",")
                            if (parts.size != 2) return "❌ Invalid range format; expected 'Minimum,Maximum'"
                            val lo = parts[0].trim().toLongOrNull() ?: 0
                            val hi = parts[1].trim().toLongOrNull() ?: 0
                            val res = MemoryEngine.searchByRange(lo, hi, type)
                            if (res.isEmpty()) return "Search complete; no results found"
                            val sb = StringBuilder("Found ${res.size}  results:\n")
                            for ((idx, r) in res.take(50).withIndex()) {
                                sb.append("${idx + 1}. Address: ${r["address"]}, value : ${r["value"]}\n")
                            }
                            sb.toString()
                        }
                        "aob" -> {
                            val res = MemoryEngine.searchAob(value)
                            if (res.isEmpty()) return "Search complete; no results found"
                            val sb = StringBuilder("Found ${res.size}  results:\n")
                            for ((idx, r) in res.take(50).withIndex()) {
                                sb.append("${idx + 1}. Address: ${r["address"]}\n")
                            }
                            sb.toString()
                        }
                        else -> "❌ UnknownSearch mode: $mode"
                    }
                }
                "read_memory" -> {
                    val address = args.optString("address", "")
                    val type = args.optString("type", "dword")
                    if (MemoryEngine.getAttachedPid() == null) return "❌ No game process attached"
                    val addrLong = address.removePrefix("0x").toLongOrNull(16) ?: return "❌ Invalid address: $address"
                    val value = MemoryEngine.readMemory(addrLong, type)
                    "Value at address $address: $value (Type: $type)"
                }
                "write_memory" -> {
                    val address = args.optString("address", "")
                    val value = args.optString("value", "")
                    val type = args.optString("type", "dword")
                    if (MemoryEngine.getAttachedPid() == null) return "❌ No game process attached"
                    val addrLong = address.removePrefix("0x").toLongOrNull(16) ?: return "❌ Invalid address: $address"
                    val numVal: Any = if (type == "float" || type == "double") value.toDoubleOrNull() ?: 0.0 else value.toLongOrNull() ?: 0
                    val success = MemoryEngine.writeMemory(addrLong, numVal, type)
                    if (success) {
                        // Implementation detail.
                        val readBack = MemoryEngine.readMemory(addrLong, type)
                        "✅ Wrote $value to address $address; read-back: $readBack"
                    } else {
                        "❌ Write failed; the address may be read-only or permissions may be insufficient"
                    }
                }
                else -> "❌ Unknown tool: $name"
            }
        } catch (e: Exception) {
            "❌ Execution error: ${e.message}"
        }
    }

    // Implementation detail.
    private fun callLlmApiStream(userInput: String, attachedApp: String, onChunk: (String) -> Unit) {
        val configPrefs = getSharedPreferences("gg_llm_config", Context.MODE_PRIVATE)
        val configJson = configPrefs.getString("config", null)

        var baseUrl = ""
        var apiKey = ""
        var model = "deepseek-chat"

        if (configJson != null) {
            try {
                val json = JSONObject(configJson)
                baseUrl = json.optString("baseUrl", "")
                apiKey = json.optString("apiKey", "")
                model = json.optString("model", "deepseek-chat")
            } catch (_: Exception) {}
        }

        if (baseUrl.isEmpty() || apiKey.isEmpty()) {
            onChunk("⚠️ Configure the LLM API in Settings first")
            return
        }

        val modelInfo = getModelInfo(model)
        val systemPrompt = buildString {
            append("You are GG-AI, a game-memory assistant. The underlying model is: $modelInfo.\n")
            append("When asked which model you are, answer exactly \"$modelInfo\". GG-AI is the app name, not the model name.\n\n")
            append("When the user requests a search, read, or edit, call the search_memory/read_memory/write_memory tools and never simulate results.\n")
            append("Only output a Lua script when the user explicitly requests one (luaj-jse-3.0.2.jar), wrapped in ```lua.\n\n")
            if (attachedApp.isNotEmpty()) append("Currently attached game process: $attachedApp\n")
            append("\nRendering support: Markdown, LaTeX formulas (${'$'}...${'$'} / ${'$'}${'$'}...${'$'}${'$'}), and Mermaid diagrams.")
            append("When asked for a diagram, output a ```mermaid code block directly without explanation.")
            append("Mermaid version 8.14.0 supports graph, sequenceDiagram, classDiagram, stateDiagram, gantt, and pie only.\n")
            append("\nUse concise, friendly English and numbered steps.")
        }

        val messages = JSONArray()
        messages.put(JSONObject().apply { put("role", "system"); put("content", systemPrompt) })
        for ((sender, msg) in chatMessages.takeLast(10)) {
            messages.put(JSONObject().apply { put("role", if (sender == "👤 Me") "user" else "assistant"); put("content", msg) })
        }
        messages.put(JSONObject().apply { put("role", "user"); put("content", userInput) })

        val isGemini = baseUrl.contains("generativelanguage.googleapis.com")
        val effectiveBaseUrl = if (isGemini) {
            "${baseUrl.trimEnd('/')}/v1beta/openai"
        } else {
            baseUrl.trimEnd('/')
        }

        // Implementation detail.
        val url = URL("$effectiveBaseUrl/chat/completions")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("Content-Type", "application/json")
        conn.setRequestProperty("Authorization", "Bearer $apiKey")
        conn.doOutput = true
        conn.connectTimeout = 30000
        conn.readTimeout = 120000

        val requestBody = JSONObject().apply {
            put("model", model)
            put("messages", messages)
            put("temperature", 0.7)
            put("max_tokens", 2048)
            put("stream", true)
        }

        val writer = OutputStreamWriter(conn.outputStream, Charsets.UTF_8)
        writer.write(requestBody.toString())
        writer.flush()
        writer.close()

        val responseCode = conn.responseCode
        if (responseCode != 200) {
            val errorStream = conn.errorStream?.bufferedReader()?.readText() ?: "Unknown error"
            throw Exception("HTTP $responseCode: $errorStream")
        }

        val reader = BufferedReader(InputStreamReader(conn.inputStream, Charsets.UTF_8))
        var line: String?
        while (reader.readLine().also { line = it } != null) {
            val l = line!!.trim()
            if (l.isEmpty() || !l.startsWith("data: ")) continue
            val data = l.substring(6)
            if (data == "[DONE]") break
            try {
                val json = JSONObject(data)
                val delta = json.getJSONArray("choices").getJSONObject(0).getJSONObject("delta")
                if (delta.has("content") && !delta.isNull("content")) {
                    val content = delta.getString("content")
                    if (content.isNotEmpty() && content != "null") {
                        onChunk(content)
                    }
                }
            } catch (_: Exception) {}
        }
        reader.close()
        conn.disconnect()
    }

    // Implementation detail.
    private fun getModelInfo(modelName: String): String {
        val m = modelName.lowercase()
        return when {
            m.contains("deepseek-reasoner") || m.contains("deepseek-r1") -> "DeepSeek-R1 (DeepSeek,reasoningmodel)"
            m.contains("deepseek") -> "DeepSeek-V3 (DeepSeek,general-purpose chatmodel)"
            m.contains("mimo") -> "MiMo-v2.5-Pro (Xiaomi,language model)"
            m.contains("gpt-4o") -> "GPT-4o (OpenAI ,multimodalmodel)"
            m.contains("gpt-4") -> "GPT-4 (OpenAI ,language model)"
            m.contains("gpt-3.5") -> "GPT-3.5-Turbo (OpenAI ,language model)"
            m.contains("gemini") -> "Gemini (Google ,language model)"
            m.contains("claude") -> "Claude (Anthropic ,language model)"
            m.contains("qwen") || m.contains("tongyi") -> "Qwen (Alibaba,language model)"
            m.contains("glm") || m.contains("chatglm") -> "ChatGLM (Zhipu AI,language model)"
            else -> modelName
        }
    }

    // Implementation detail.

    private fun saveChatToStorage() {
        if (chatMessages.isEmpty()) {
            handler.post {
                Toast.makeText(this, "No chat history to save", Toast.LENGTH_SHORT).show()
            }
            return
        }

        try {
            val prefs = getSharedPreferences("gg_overlay_chat", Context.MODE_PRIVATE)
            val editor = prefs.edit()

            // Implementation detail.
            val jsonArray = JSONArray()
            for ((sender, msg) in chatMessages) {
                jsonArray.put(JSONObject().apply {
                    put("sender", sender)
                    put("message", msg)
                    put("timestamp", System.currentTimeMillis())
                })
            }

            // Implementation detail.
            val sessionId = "chat_${System.currentTimeMillis()}"
            editor.putString(sessionId, jsonArray.toString())
            editor.putString("latest_session_id", sessionId)
            editor.apply()

            handler.post {
                Toast.makeText(this, "✅ Chat saved; view it in the main app", Toast.LENGTH_SHORT).show()
            }
        } catch (e: Exception) {
            handler.post {
                Toast.makeText(this, "❌ Save failed: ${e.message}", Toast.LENGTH_SHORT).show()
            }
        }
    }

    // Implementation detail.

    private fun showScriptPanel() {
        saveLastPanel("script")
        makeDraggablePanel("Script Library", { content ->
            val status = TextView(this).apply {
                text = "Loading scripts..."
                setTextColor(Color.parseColor("#F2F3F8"))
                textSize = 12f
                setPadding(dp(12), dp(8), dp(12), dp(4))
            }
            content.addView(status)

            val sv = ScrollView(this).apply {
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f)
            }
            val list = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(8), dp(4), dp(8), dp(4))
            }
            sv.addView(list)
            content.addView(sv)

            // Implementation detail.
            fun loadScripts() {
                list.removeAllViews()
                status.text = "Loading scripts..."
                Thread {
                    val scripts = loadScriptsFromStorage()
                    handler.post {
                        status.text = "Found ${scripts.size} scripts"
                        for (script in scripts) {
                            val item = LinearLayout(this).apply {
                                orientation = LinearLayout.HORIZONTAL
                                setPadding(dp(12), dp(10), dp(12), dp(10))
                                background = GradientDrawable().apply {
                                    cornerRadius = dp(8).toFloat()
                                    setColor(Color.parseColor("#304FFE"))
                                }
                                layoutParams = LinearLayout.LayoutParams(
                                    LinearLayout.LayoutParams.MATCH_PARENT,
                                    LinearLayout.LayoutParams.WRAP_CONTENT
                                ).apply { bottomMargin = dp(6) }
                            }
                            val nameText = TextView(this).apply {
                                text = script["name"] ?: "Unknown script"
                                setTextColor(Color.parseColor("#F2F3F8"))
                                textSize = 14f
                                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                            }
                            item.addView(nameText)

                            val runBtn = smallBtn("▶ Run") {
                                val scriptContent = script["content"] ?: ""
                                if (scriptContent.isNotEmpty()) {
                                    status.text = "Running: ${script["name"]}..."
                                    Thread {
                                        try {
                                            LuaEngine.setContext(this@OverlayService)
                                            val output = LuaEngine.executeScript(scriptContent)
                                            // Implementation detail.
                                            saveScriptLog(script["name"] ?: "Script", output)
                                            handler.post {
                                                status.text = "✅ ${script["name"]} Execution complete"
                                                Toast.makeText(this@OverlayService, "✅ ${script["name"]} completed; log saved", Toast.LENGTH_SHORT).show()
                                            }
                                        } catch (e: Exception) {
                                            handler.post {
                                                status.text = "❌ Execution failed: ${e.message}"
                                            }
                                        }
                                    }.start()
                                }
                            }
                            item.addView(runBtn)
                            list.addView(item)
                        }

                        if (scripts.isEmpty()) {
                            list.addView(TextView(this).apply {
                                text = "No scripts\nCreate one in Script Library in the main app"
                                setTextColor(Color.parseColor("#4A6572"))
                                textSize = 13f
                                setPadding(dp(12), dp(20), dp(12), dp(8))
                                gravity = Gravity.CENTER
                            })
                        }
                    }
                }.start()
            }

            // Implementation detail.
            loadScripts()

            // Implementation detail.
            val bar = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; setPadding(dp(12), dp(4), dp(12), dp(8)) }
            bar.addView(iconBtn(R.drawable.shuaxing) { loadScripts() }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            bar.addView(iconBtn(R.drawable.ck_gb) { closePanel() }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            content.addView(bar)
        }, 300, 420, titleIcon = R.drawable.jiaoben, bgColor = "#213333")
    }

    /**
     * SaveScript Run Log
     */
    private fun saveScriptLog(scriptName: String, output: String) {
        try {
            val now = java.text.SimpleDateFormat("MMddHHmm", java.util.Locale.getDefault()).format(java.util.Date())
            val timeStr = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())

            // Implementation detail.
            val prefs = getSharedPreferences("gg_script_logs", Context.MODE_PRIVATE)
            val existing = prefs.getString("logs", "[]") ?: "[]"
            val logsArray = org.json.JSONArray(existing)

            val logEntry = org.json.JSONObject().apply {
                put("name", "${now}_$scriptName")
                put("scriptName", scriptName)
                put("time", timeStr)
                put("output", output)
            }
            logsArray.put(logEntry)

            prefs.edit().putString("logs", logsArray.toString()).apply()
        } catch (_: Exception) {}
    }

    /**
     * Implementation detail.
     */
    private fun loadScriptsFromStorage(): List<Map<String, String>> {
        val scripts = mutableListOf<Map<String, String>>()

        try {
            // Implementation detail.
            val prefs = getSharedPreferences("gg_scripts", Context.MODE_PRIVATE)
            val scriptsJson = prefs.getString("scripts", "[]") ?: "[]"
            val jsonArray = org.json.JSONArray(scriptsJson)
            for (i in 0 until jsonArray.length()) {
                val json = jsonArray.getJSONObject(i)
                scripts.add(mapOf(
                    "id" to json.optString("id", ""),
                    "name" to json.optString("name", "Unknown"),
                    "content" to json.optString("content", ""),
                    "description" to json.optString("description", "")
                ))
            }
        } catch (_: Exception) {}

        // Implementation detail.
        if (scripts.none { it["id"] == "builtin_test" }) {
            // Implementation detail.
            scripts.add(mapOf(
            "id" to "builtin_test",
            "name" to "Run Test",
            "content" to """-- game modifier Lua test script
function searchData(value, valueType)
    gg.clearResults()
    gg.searchNumber(value, valueType)
    local count = gg.getResultCount()
    gg.toast("Search complete; found " .. count .. " results")
    return count
end
function menu1_search()
    local choice = gg.choice({
        " Search integer 9999",
        " Search float 1.0",
        " Search double 3.14"
    }, nil, "【Value search】Choose a search type")
    if choice == nil then
        gg.toast("Cancelled")
        return
    end
    if choice == 1 then
        searchData(9999, gg.TYPE_DWORD)
    elseif choice == 2 then
        searchData("1.0", gg.TYPE_FLOAT)
    elseif choice == 3 then
        searchData("3.14", gg.TYPE_DOUBLE)
    end
end
function menu2_advanced()
    local choice = gg.choice({
        " Change search results to 88888",
        " Freeze current results",
        " Clear all results"
    }, nil, "【Advanced operations】Choose an operation")
    if choice == nil then
        gg.toast("Cancelled")
        return
    end
    if choice == 1 then
        local count = gg.getResultCount()
        if count > 0 then
            local results = gg.getResults(count)
            for i, v in ipairs(results) do
                results[i].value = 88888
                results[i].flags = gg.TYPE_DWORD
            end
            gg.setValues(results)
            gg.toast("Updated " .. count .. " items to 88888")
        else
            gg.toast("No search results")
        end
    elseif choice == 2 then
        local count = gg.getResultCount()
        if count > 0 then
            local results = gg.getResults(count)
            for i, v in ipairs(results) do
                results[i].freeze = true
            end
            gg.addListItems(results)
            gg.toast("Froze " .. count .. " items")
        else
            gg.toast("No search results")
        end
    elseif choice == 3 then
        gg.clearResults()
        gg.clearList()
        gg.toast("All results cleared")
    end
end
function mainMenu()
    while true do
        local main = gg.choice({
            " Value search",
            " Advanced operations",
            " Exit script"
        }, nil, "=== Lua test script v1.0 ===")
        if main == nil or main == 3 then
            gg.toast("Script exited")
            break
        elseif main == 1 then
            menu1_search()
        elseif main == 2 then
            menu2_advanced()
        end
    end
end
gg.toast("Lua test script loaded")
gg.sleep(1000)
mainMenu()""",
            "description" to "Lua menu and data search test"
        ))
        }

        return scripts
    }

    /**
     * Implementation detail.
     */

    // Implementation detail.

    private fun menuBtn(text: String, iconRes: Int? = null, onClick: () -> Unit): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(10), dp(12), dp(10))
            background = GradientDrawable().apply { cornerRadius = dp(8).toFloat(); setColor(Color.parseColor("#304FFE")) }
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { bottomMargin = dp(6) }
            setOnClickListener { onClick() }
            if (iconRes != null) {
                addView(ImageView(this@OverlayService).apply {
                    setImageResource(iconRes)
                    layoutParams = LinearLayout.LayoutParams(dp(24), dp(24)).apply { marginEnd = dp(10) }
                    scaleType = ImageView.ScaleType.CENTER_INSIDE
                })
            }
            addView(TextView(this@OverlayService).apply {
                this.text = text; setTextColor(Color.parseColor("#F2F3F8")); textSize = 14f
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            })
        }
    }

    private fun smallBtn(text: String, onClick: () -> Unit): Button {
        return Button(this).apply {
            this.text = text; setTextColor(Color.parseColor("#F2F3F8")); textSize = 11f
            background = GradientDrawable().apply { cornerRadius = dp(6).toFloat(); setColor(Color.parseColor("#3D5AFE")) }
            setPadding(dp(10), dp(4), dp(10), dp(4))
            setOnClickListener { onClick() }
        }
    }

    private fun iconBtn(iconRes: Int, label: String = "", onClick: () -> Unit): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            background = GradientDrawable().apply { cornerRadius = dp(6).toFloat(); setColor(Color.parseColor("#3D5AFE")) }
            setPadding(dp(6), dp(4), dp(6), dp(4))
            setOnClickListener { onClick() }
            addView(ImageView(this@OverlayService).apply {
                setImageResource(iconRes)
                layoutParams = LinearLayout.LayoutParams(dp(20), dp(20))
                scaleType = ImageView.ScaleType.CENTER_INSIDE
            })
            if (label.isNotEmpty()) {
                addView(TextView(this@OverlayService).apply {
                    text = label; setTextColor(Color.parseColor("#F2F3F8")); textSize = 9f
                    gravity = Gravity.CENTER
                })
            }
        }
    }

    private fun dp(v: Int): Int = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()
}
