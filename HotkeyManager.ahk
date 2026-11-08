#Requires AutoHotkey v2.0
#SingleInstance Force
; @Ahk2Exe-SetName HotkeyManager
; @Ahk2Exe-SetVersion 0.1.0
; @Ahk2Exe-SetDescription Custom keyboard shortcuts for Windows (Ubuntu style)

; ============================================================
;  HotkeyManager - Windows 自定义快捷键（Ubuntu / GNOME 风格）
;  开发期：AutoHotkey64.exe HotkeyManager.ahk
;  交付：  HotkeyManager.exe（Ahk2Exe 编译，单文件双击即用）
;  配置：  HotkeyManager.ini（首次运行自动生成）
; ============================================================

; 鼠标坐标统一用屏幕坐标：MouseGetPos 默认返回客户区坐标，与 WinGetPos 混用会导致窗口抖动
CoordMode("Mouse", "Screen")

; 若未以管理员运行则自动提权重启（普通权限无法在管理员窗口上使用热键/调整窗口）
; 可用 --no-elevate 参数跳过（调试用）
if (!A_IsAdmin) {
    skip := false
    for arg in A_Args
        if (arg = "--no-elevate")
            skip := true
    if (!skip) {
        elevated := false
        try {
            if (A_IsCompiled)
                Run('*RunAs "' . A_ScriptFullPath . '"')
            else
                Run('*RunAs "' . A_AhkPath . '" "' . A_ScriptFullPath . '"')
            elevated := true
        }
        if (elevated)
            ExitApp()
        ; 用户取消 UAC 时降级为普通权限继续运行（仅管理员窗口受限）
    }
}

; 所有状态放在一个全局对象里，函数内只需 global S
global S := {
    title: "键盘快捷键",
    tip: "提示：亮度调节仅适用于笔记本/一体机内置屏；本方案不配置外接显示器，如需控制外接屏需显示器支持 DDC/CI 并另装工具。",
    cfg: A_ScriptDir "\HotkeyManager.ini",
    bindings: [],
    rowmap: [],
    main: "",
    lv: "",
    search: "",
    status: ""
}

; ============================================================
;  配置读写
; ============================================================
MakeDefaults() {
    ; 格式：类别|名称|动作|快捷键|no=置灰|说明
    ; 动作：run:命令 / send:按键 / vol:+5 / vol:mute / bright:+10 / lock: / win:top|size|close
    csv := "
(
辅助功能|放大镜|run:magnify.exe|||启动 Windows 放大镜
辅助功能|高对比度|send:!+{PrintScreen}|||Alt+Shift+PrtSc 切换高对比度
辅助功能|屏幕键盘|run:osk.exe|||启动屏幕键盘
辅助功能|讲述人|send:#^{Enter}|||Win+Ctrl+Enter 启动讲述人
启动器|计算器|run:calculator:|||打开计算器（UWP 协议 URI）
启动器|文件资源管理器|run:explorer.exe|||打开文件资源管理器
启动器|系统设置|run:ms-settings:|||打开 Windows 设置
启动器|搜索|send:#s|||Win+S 打开搜索
导航|上一个虚拟桌面|send:#^{Left}|||Win+Ctrl+←
导航|下一个虚拟桌面|send:#^{Right}|||Win+Ctrl+→
导航|窗口移到左显示器|send:#+{Left}|||Win+Shift+←
导航|窗口移到右显示器|send:#+{Right}|||Win+Shift+→
导航|任务视图|send:#{Tab}|||Win+Tab
导航|显示桌面|send:#d|||Win+D
截图|截图工具|send:#+s|||Win+Shift+S
截图|全屏截图|send:{PrintScreen}|||PrtSc
截图|窗口截图|send:!{PrintScreen}|||Alt+PrtSc
截图|录屏|send:#!r|||Win+Alt+R（Xbox Game Bar）
声音与媒体|音量 +5|vol:+5|^!Up||主音量 +5%（AHK 原生 SoundSetVolume）
声音与媒体|音量 -5|vol:-5|^!Down||主音量 -5%
声音与媒体|静音切换|vol:mute|^!m||切换主音量静音
声音与媒体|播放/暂停|send:{Media_Play_Pause}|||媒体键：播放/暂停
声音与媒体|上一曲|send:{Media_Prev}|||媒体键：上一曲
声音与媒体|下一曲|send:{Media_Next}|||媒体键：下一曲
声音与媒体|停止|send:{Media_Stop}|||媒体键：停止
声音与媒体|亮度 +10|bright:+10|^!PgUp||仅笔记本/一体机内置屏有效；不配置外接显示器
声音与媒体|亮度 -10|bright:-10|^!PgDn||仅笔记本/一体机内置屏有效
声音与媒体|麦克风静音|||no|Windows 无 AHK 原生麦克风静音，需 CoreAudio COM；已置灰
声音与媒体|弹出光碟|||no|Windows 已无对应硬件语义；已置灰
系统|锁屏|lock:|||调用 user32\LockWorkStation（Win+L 本身不可被重绑定）
系统|运行对话框|send:#r|||Win+R
系统|通知中心|send:#a|||Win+A
系统|任务管理器|send:^+{Escape}|||Ctrl+Shift+Esc
系统|电源菜单|send:#x|||Win+X
系统|恢复键盘快捷键|||no|GNOME 特有，Windows 无对应；已置灰
输入|切换输入法/键盘布局|send:#{Space}|||Win+Space（语义近似：Windows 为输入法/键盘布局）
窗口|关闭窗口|win:close|||关闭活动窗口
窗口|最大化|send:#{Up}|||Win+↑
窗口|最小化|send:#{Down}|||Win+↓
窗口|左半屏|send:#{Left}|||Win+←
窗口|右半屏|send:#{Right}|||Win+→
窗口|置顶切换|win:top|||切换活动窗口置顶
窗口|调整窗口大小|win:resize|||按下后窗口随鼠标改变大小，左键确认，Esc 取消
窗口|水平最大化|||no|Windows 无单独水平最大化；已置灰
窗口|垂直最大化|||no|Windows 无单独垂直最大化；已置灰
窗口|置顶所有工作区|||no|Windows 虚拟桌面无简单快捷键；已置灰
自定义快捷键|打开记事本（示例）|run:notepad.exe|^!n||自定义命令示例：任意命令或脚本
)"
    out := []
    for line in StrSplit(Trim(csv, "`n"), "`n", "`r") {
        if (Trim(line) = "")
            continue
        f := StrSplit(line, "|")
        out.Push({
            cat: f[1],
            name: f[2],
            act: f[3],
            keys: f[4],
            enabled: f[5] != "no",
            note: f.Length >= 6 ? f[6] : ""
        })
    }
    return out
}

LoadConfig() {
    global S
    if (!FileExist(S.cfg)) {
        S.bindings := MakeDefaults()
        SaveConfig()
        return
    }
    n := Integer(IniRead(S.cfg, "Meta", "Count", "0"))
    if (n = 0) {
        S.bindings := MakeDefaults()
        SaveConfig()
        return
    }
    S.bindings := []
    Loop n {
        sec := "B" A_Index
        S.bindings.Push({
            cat: IniRead(S.cfg, sec, "cat", "自定义快捷键"),
            name: IniRead(S.cfg, sec, "name", ""),
            act: IniRead(S.cfg, sec, "act", ""),
            keys: IniRead(S.cfg, sec, "keys", ""),
            enabled: IniRead(S.cfg, sec, "enabled", "1") = "1",
            note: IniRead(S.cfg, sec, "note", "")
        })
    }
    ; 迁移旧版固定尺寸动作 -> 交互式调整大小
    migrated := false
    for b in S.bindings {
        if (b.act = "win:size") {
            b.act := "win:resize"
            b.note := "按下后窗口随鼠标改变大小，左键确认，Esc 取消"
            migrated := true
        } else if (b.act = "win:resize" && InStr(b.note, "方向键")) {
            b.note := "按下后窗口随鼠标改变大小，左键确认，Esc 取消"
            migrated := true
        }
    }
    if migrated
        SaveConfig()
}

SaveConfig() {
    global S
    if FileExist(S.cfg)
        FileDelete(S.cfg)
    IniWrite(S.bindings.Length, S.cfg, "Meta", "Count")
    for i, b in S.bindings {
        sec := "B" i
        IniWrite(b.cat, S.cfg, sec, "cat")
        IniWrite(b.name, S.cfg, sec, "name")
        IniWrite(b.act, S.cfg, sec, "act")
        IniWrite(b.keys, S.cfg, sec, "keys")
        IniWrite(b.enabled ? 1 : 0, S.cfg, sec, "enabled")
        IniWrite(b.note, S.cfg, sec, "note")
    }
}

; ============================================================
;  热键注册与动作执行
; ============================================================
IsReserved(k) {
    k := StrReplace(StrLower(k), "{", "")
    k := StrReplace(k, "}", "")
    return k = "#l" || k = "^!delete" || k = "^+escape" || k = "#!delete"
}

FindConflict(keys, exclude) {
    global S
    if (keys = "")
        return 0
    for i, b in S.bindings
        if (i != exclude && b.enabled && StrLower(b.keys) = StrLower(keys))
            return i
    return 0
}

ApplyBindings() {
    global S
    for b in S.bindings {
        if (!b.enabled || Trim(b.keys) = "")
            continue
        if IsReserved(b.keys) {
            b.keys := ""
            continue
        }
        ; Reload()/重启瞬间旧实例的键盘钩子可能尚未释放，重试更久避免绑定失效
        ok := false
        Loop 8 {
            try {
                Hotkey(b.keys, RunAction.Bind(b))
                ok := true
                break
            }
            Sleep 400
        }
        if (!ok)
            b.err := true   ; 注册失败不要清空用户键位（否则下次保存会丢配置）
    }
}

RunAction(b, *) {
    ; Hotkey() 触发时会额外传入热键名，用 * 吸收多余参数
    a := b.act
    if (a = "")
        return
    p := InStr(a, ":")
    k := p ? SubStr(a, 1, p - 1) : a
    v := p ? SubStr(a, p + 1) : ""
    switch k {
        case "run":
            Run(v)
        case "send":
            Send(v)
        case "vol":
            if (v = "mute")
                SoundSetMute(-1)
            else
                SoundSetVolume(v)
        case "bright":
            BrightnessDelta(Integer(v))
        case "lock":
            DllCall("user32\LockWorkStation")
        case "win":
            if (v = "close")
                WinClose("A")
            else if (v = "top")
                WinSetAlwaysOnTop(-1, "A")
            else if (v = "resize" || v = "size")
                ResizeWindowMode()
        default:
            Run(a)
    }
}

BrightnessDelta(d) {
    ; 仅笔记本/一体机内置屏：走 Windows 自带 WMI，无需第三方工具
    ; 两个必须条件：① 用 Get-WmiObject（Get-CimInstance 的 CimInstance 没有 WmiSetBrightness 方法）
    ;              ② 需要管理员权限（普通权限调用返回「拒绝访问」）
    static warnedNoPanel := false, warnedNoAdmin := false
    if (!A_IsAdmin) {
        if (!warnedNoAdmin) {
            warnedNoAdmin := true
            r := MsgBox("调整屏幕亮度需要管理员权限。`n`n当前以普通权限运行，是否以管理员身份重启？", "键盘快捷键", "YesNo Icon!")
            if (r = "Yes")
                RestartAsAdmin()
        }
        return
    }
    sign := d > 0 ? "+" . d : "" . d
    ps := '$b=(Get-WmiObject -Namespace root/WMI -ClassName WmiMonitorBrightness -ErrorAction SilentlyContinue).CurrentBrightness;'
    ps .= 'if($null -eq $b){exit 2};'
    ps .= '$n=[byte][Math]::Max(0,[Math]::Min(100,$b' sign '));'
    ps .= '$m=Get-WmiObject -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods -ErrorAction SilentlyContinue;'
    ps .= 'if($null -eq $m){exit 3};'
    ps .= 'try{$m.WmiSetBrightness(1,$n)}catch{exit 4}'
    code := -1
    try
        code := RunWait('powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "' ps '"', , "Hide")
    catch
        code := -1
    ; 2/3 = 本机没有可通过 WMI 调亮度的内置屏（台式机 / 纯外接显示器）
    if (code = 2 || code = 3) {
        if (!warnedNoPanel) {
            warnedNoPanel := true
            TrayTip("未检测到可通过 WMI 调节亮度的内置屏。`n亮度快捷键仅适用于笔记本/一体机内置屏。", "键盘快捷键", 5)
        }
    } else if (code = 4 || code = 1) {
        TrayTip("调整亮度失败：权限不足或显示器不支持。", "键盘快捷键", 5)
    }
}

; ============================================================
;  鼠标跟随式调整窗口大小
;  按下快捷键 → 窗口随鼠标实时改变大小 → 单击左键确认 / Esc 取消
; ============================================================
RS := { active: false }

ResizeWindowMode() {
    global RS
    static tipShown := false
    hwnd := WinExist("A")
    if (!hwnd)
        return
    ; 已处于调整模式时，再按一次等于取消
    if (RS.active) {
        EndResize(false)
        return
    }
    ; 最大化/最小化的窗口先还原，否则无法改变大小
    if (WinGetMinMax("ahk_id " hwnd) != 0) {
        DllCall("ShowWindow", "Ptr", hwnd, "Int", 9)   ; SW_RESTORE
        Sleep 150
    }
    WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
    MouseGetPos(&mx, &my)
    ; 取离鼠标最近的角作为拖动角，它的对角固定不动
    cx := [wx, wx + ww, wx, wx + ww]
    cy := [wy, wy, wy + wh, wy + wh]
    ax := [wx + ww, wx, wx + ww, wx]
    ay := [wy + wh, wy + wh, wy, wy]
    best := 1, bestD := 999999999999
    Loop 4 {
        dx := mx - cx[A_Index], dy := my - cy[A_Index]
        d := dx * dx + dy * dy
        if (d < bestD) {
            bestD := d
            best := A_Index
        }
    }
    RS.hwnd := hwnd
    RS.ax := ax[best], RS.ay := ay[best]
    RS.ox := wx, RS.oy := wy, RS.ow := ww, RS.oh := wh
    RS.sx := mx, RS.sy := my
    RS.moved := false
    RS.lx := "", RS.ly := "", RS.lw := "", RS.lh := ""
    RS.active := true
    ; 拦截左键用于确认，同时避免点中窗口边框时触发系统自带的拖拽缩放
    try {
        Hotkey("$*LButton", ConfirmResize, "On")
        Hotkey("$*Escape", CancelResize, "On")
    } catch {
        EndResize(false)
        return
    }
    SetTimer(ResizeTick, 16)
    if (!tipShown) {
        tipShown := true
        TrayTip("移动鼠标调整窗口大小`n左键确认 · Esc 取消", "调整窗口大小", 2)
    }
}

ResizeTick() {
    global RS
    if (!RS.active) {
        SetTimer(ResizeTick, 0)
        return
    }
    if (!WinExist("ahk_id " RS.hwnd)) {
        EndResize(false)
        return
    }
    MouseGetPos(&mx, &my)
    ; 鼠标还没明显移动时保持原样，避免误触把窗口缩到最小
    if (!RS.moved) {
        dx := mx - RS.sx, dy := my - RS.sy
        if (dx * dx + dy * dy < 100)
            return
        RS.moved := true
    }
    left := Min(RS.ax, mx), top := Min(RS.ay, my)
    right := Max(RS.ax, mx), bottom := Max(RS.ay, my)
    ; 最小尺寸，防止缩成一条线
    if (right - left < 240) {
        if (mx < RS.ax)
            left := right - 240
        else
            right := left + 240
    }
    if (bottom - top < 160) {
        if (my < RS.ay)
            top := bottom - 160
        else
            bottom := top + 160
    }
    nw := right - left, nh := bottom - top
    ; 尺寸没变就不重设，避免每帧重复重绘造成闪烁
    if (RS.lx = left && RS.ly = top && RS.lw = nw && RS.lh = nh)
        return
    RS.lx := left, RS.ly := top, RS.lw := nw, RS.lh := nh
    DllCall("SetWindowPos", "Ptr", RS.hwnd, "Ptr", 0, "Int", left, "Int", top
        , "Int", nw, "Int", nh, "UInt", 0x0004 | 0x0010)
}

ConfirmResize(*) {
    EndResize(true)
}

CancelResize(*) {
    EndResize(false)
}

EndResize(keep) {
    global RS
    if (!RS.active)
        return
    RS.active := false
    SetTimer(ResizeTick, 0)
    ; 无论如何都解除拦截，否则左键会一直失效
    try {
        Hotkey("$*LButton", "Off")
        Hotkey("$*Escape", "Off")
    }
    if (!keep && WinExist("ahk_id " RS.hwnd))
        DllCall("SetWindowPos", "Ptr", RS.hwnd, "Ptr", 0, "Int", RS.ox, "Int", RS.oy
            , "Int", RS.ow, "Int", RS.oh, "UInt", 0x0004 | 0x0010)
}

; ============================================================
;  界面（交互结构对齐 Ubuntu「查看和自定义快捷键」）
; ============================================================
BuildGui() {
    global S
    g := Gui("+Resize +MinSize620x420", S.title)
    g.SetFont("s9", "Microsoft YaHei UI")

    S.lblSearch := g.Add("Text", "x12 y15 w44 h20", "搜索：")
    S.search := g.Add("Edit", "x56 y11 w300 h24")
    S.search.OnEvent("Change", (*) => RefreshList())

    S.lv := g.Add("ListView", "x12 y42 w720 h400 +Grid -Multi", ["名称", "快捷键"])
    S.lv.ModifyCol(1, 500)
    S.lv.ModifyCol(2, 190)
    S.lv.OnEvent("DoubleClick", OnRowDoubleClick)
    S.lv.OnEvent("Click", OnRowClick)

    S.btnAdd := g.Add("Button", "x12 y458 w150 h26", "+ 添加自定义快捷键")
    S.btnAdd.OnEvent("Click", (*) => ShowAddDialog())
    S.btnDel := g.Add("Button", "x172 y458 w90 h26", "移除")
    S.btnDel.OnEvent("Click", RemoveSelected)
    S.btnReload := g.Add("Button", "x272 y458 w90 h26", "重载")
    S.btnReload.OnEvent("Click", (*) => Reload())
    S.btnReset := g.Add("Button", "x372 y458 w100 h26", "重置默认")
    S.btnReset.OnEvent("Click", ResetDefaults)

    S.status := g.Add("Text", "x12 y492 w720 h20 c808080", S.tip)

    g.OnEvent("Size", OnGuiSize)
    g.OnEvent("Close", (*) => g.Hide())
    g.OnEvent("Escape", (*) => g.Hide())
    S.main := g
}

; 窗口尺寸变化（含最大化）时重新排布控件
OnGuiSize(g, minMax, W, H) {
    if (W < 200 || H < 200)   ; 最小化时宽高为 0
        return
    LayoutGui(W, H)
}

LayoutGui(W, H) {
    global S
    m := 12
    ; 顶部搜索行
    S.lblSearch.Move(m, 15, 44, 20)
    S.search.Move(m + 44, 11, Min(320, W - 2 * m - 44), 24)
    ; 底部两块：状态提示贴底，按钮在其上方
    statusH := 20, btnH := 26
    statusY := H - m - statusH
    btnY := statusY - 8 - btnH
    ; 列表填满中间区域
    lvY := 42
    lvH := btnY - 12 - lvY
    if (lvH < 80)
        lvH := 80
    S.lv.Move(m, lvY, W - 2 * m, lvH)
    ; 列宽随窗口伸缩：快捷键列固定，名称列吃掉剩余宽度
    col2 := 190
    S.lv.ModifyCol(2, col2)
    S.lv.ModifyCol(1, Max(160, W - 2 * m - col2 - 24))
    ; 按钮行
    S.btnAdd.Move(m, btnY, 150, btnH)
    S.btnDel.Move(m + 160, btnY, 90, btnH)
    S.btnReload.Move(m + 260, btnY, 90, btnH)
    S.btnReset.Move(m + 360, btnY, 100, btnH)
    ; 底部灰字提示
    S.status.Move(m, statusY, W - 2 * m, statusH)
}

RefreshList() {
    global S
    S.lv.Delete()
    S.rowmap := []
    last := ""
    filter := Trim(S.search.Value)
    for i, b in S.bindings {
        if (filter != "" && !InStr(b.name, filter) && !InStr(b.cat, filter))
            continue
        if (b.cat != last) {
            S.lv.Add("", "【" b.cat "】", "")
            S.rowmap.Push(0)
            last := b.cat
        }
        kd := b.enabled ? (b.keys = "" ? "禁用" : b.keys) : "—"
        if b.HasOwnProp("err")
            kd .= "（被占用）"
        S.lv.Add("", b.name, kd)
        S.rowmap.Push(i)
    }
}

RowIndex(row) {
    global S
    return (row > 0 && row <= S.rowmap.Length) ? S.rowmap[row] : 0
}

OnRowDoubleClick(lv, row) {
    global S
    idx := RowIndex(row)
    if idx
        ShowSetKeyDialog(idx)
}

OnRowClick(lv, row) {
    global S
    idx := RowIndex(row)
    if (!idx) {
        S.status.Value := S.tip
        return
    }
    b := S.bindings[idx]
    txt := b.note != "" ? b.note : b.act
    if (!b.enabled)
        txt .= "  【不可用】"
    S.status.Value := txt
}

ShowSetKeyDialog(idx) {
    global S
    b := S.bindings[idx]
    if (!b.enabled) {
        MsgBox("此条目在 Windows 上无对应能力，已置灰。`n`n原因：" b.note, S.title, "Icon!")
        return
    }
    d := Gui("+Owner" S.main.Hwnd, "设置快捷键")
    d.SetFont("s9", "Microsoft YaHei UI")
    d.Add("Text", "xm", "名称：" b.name)
    d.Add("Text", "xm", "命令：" (b.act != "" ? b.act : "—"))
    d.Add("Text", "xm y+10", "按住想要的组合键，或清空以禁用；Esc 取消")
    d.Add("Hotkey", "xm w240 vChosen", b.keys)
    d.Add("Button", "xm w80 default", "设置").OnEvent("Click", (*) => OnSet(d, idx))
    d.Add("Button", "x+10 w80", "取消").OnEvent("Click", (*) => d.Destroy())
    d.Show()
}

OnSet(d, idx) {
    global S
    form := d.Submit()
    k := form.Chosen
    if IsReserved(k) {
        MsgBox("该组合被 Windows 保留（Win+L / Ctrl+Alt+Del / Ctrl+Shift+Esc），无法使用。", S.title, "Icon!")
        d.Destroy()
        return
    }
    c := FindConflict(k, idx)
    if c {
        MsgBox("该组合已被「" S.bindings[c].name "」占用，请换一个。", S.title, "Icon!")
        d.Destroy()
        return
    }
    S.bindings[idx].keys := k
    SaveConfig()
    d.Destroy()
    Reload()
}

ShowAddDialog() {
    global S
    d := Gui("+Owner" S.main.Hwnd, "添加自定义快捷键")
    d.SetFont("s9", "Microsoft YaHei UI")
    d.Add("Text", "xm", "名称：")
    d.Add("Edit", "xm w320 vName")
    d.Add("Text", "xm", "命令（可执行文件或脚本）：")
    d.Add("Edit", "xm w320 vCmd")
    d.Add("Text", "xm", "快捷键：")
    d.Add("Hotkey", "xm w240 vChosen")
    d.Add("Button", "xm w80 default", "添加").OnEvent("Click", (*) => OnAdd(d))
    d.Add("Button", "x+10 w80", "取消").OnEvent("Click", (*) => d.Destroy())
    d.Show()
}

OnAdd(d) {
    global S
    form := d.Submit()
    nm := Trim(form.Name), cmd := Trim(form.Cmd)
    if (nm = "" || cmd = "") {
        MsgBox("名称和命令都不能为空。", S.title, "Icon!")
        d.Destroy()
        return
    }
    if IsReserved(form.Chosen) {
        MsgBox("该组合被 Windows 保留，无法使用。", S.title, "Icon!")
        d.Destroy()
        return
    }
    c := FindConflict(form.Chosen, 0)
    if c {
        MsgBox("该组合已被「" S.bindings[c].name "」占用，请换一个。", S.title, "Icon!")
        d.Destroy()
        return
    }
    S.bindings.Push({cat: "自定义快捷键", name: nm, act: "run:" cmd, keys: form.Chosen, enabled: true, note: "自定义命令"})
    SaveConfig()
    d.Destroy()
    Reload()
}

RemoveSelected(*) {
    global S
    row := S.lv.GetNext()
    if (!row) {
        MsgBox("请先选中一条。", S.title)
        return
    }
    idx := RowIndex(row)
    if (!idx || S.bindings[idx].cat != "自定义快捷键") {
        MsgBox("只能移除「自定义快捷键」分类下的条目。", S.title)
        return
    }
    S.bindings.RemoveAt(idx)
    SaveConfig()
    Reload()
}

ResetDefaults(*) {
    global S
    r := MsgBox("确定恢复全部默认快捷键吗？`n`n这会清除你自己添加和修改过的所有绑定。", S.title, "YesNo Icon! Default2")
    if (r != "Yes")
        return
    S.bindings := MakeDefaults()
    SaveConfig()
    Reload()
}

; ============================================================
;  托盘
; ============================================================
BuildTray() {
    global S
    A_IconTip := S.title
    A_TrayMenu.Delete()
    A_TrayMenu.Add("打开主窗口", (*) => S.main.Show())
    A_TrayMenu.Add("暂停全部热键", ToggleSuspend)
    A_TrayMenu.Add("开机自启", ToggleAutoStart)
    if (!A_IsAdmin)
        A_TrayMenu.Add("以管理员身份重启", RestartAsAdmin)
    A_TrayMenu.Add("退出", (*) => ExitApp())
}

ToggleSuspend(*) {
    Suspend(-1)
}

RestartAsAdmin(*) {
    try {
        if (A_IsCompiled)
            Run('*RunAs "' . A_ScriptFullPath . '"')
        else
            Run('*RunAs "' . A_AhkPath . '" "' . A_ScriptFullPath . '"')
    } catch {
        MsgBox("提权被取消或失败。", "键盘快捷键", "Icon!")
        return
    }
    ExitApp()
}

ToggleAutoStart(*) {
    lnk := A_Startup "\HotkeyManager.lnk"
    if FileExist(lnk) {
        FileDelete(lnk)
        MsgBox("已关闭开机自启。", "键盘快捷键")
        return
    }
    if (SubStr(A_ScriptFullPath, -4) = ".exe") {
        FileCreateShortcut(A_ScriptFullPath, lnk, A_ScriptDir, "", "Windows 自定义快捷键")
    } else {
        base := A_ScriptDir "\AutoHotkey_2.0.31\AutoHotkey64.exe"
        if (!FileExist(base))
            base := A_ScriptDir "\AutoHotkey64.exe"
        if (!FileExist(base)) {
            MsgBox("未找到 AutoHotkey64.exe，无法设置自启。", "键盘快捷键", "Icon!")
            return
        }
        FileCreateShortcut(base, lnk, A_ScriptDir, '"' A_ScriptFullPath '"', "Windows 自定义快捷键")
    }
    MsgBox("已设置开机自启。", "键盘快捷键")
}

; ============================================================
;  启动
; ============================================================
LoadConfig()
ApplyBindings()
BuildGui()
BuildTray()
RefreshList()
S.main.Show()
; 首次显示后按真实客户区做一次布局（Size 事件在部分情况下可能不触发）
S.main.GetClientPos(, , &cw0, &ch0)
LayoutGui(cw0, ch0)
