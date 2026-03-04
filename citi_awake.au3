; ============================================
; 通用图像触发器 - 自动检测屏幕并发送按键
; ============================================

#include <AutoItConstants.au3>
#include <MsgBoxConstants.au3>
#include <FileConstants.au3>
#include <Array.au3>
#include "ImageSearchDLL_UDF\ImageSearchDLL_UDF.au3"
#include <GDIPlus.au3>

; ============================================
; 全局配置
; ============================================
Global $g_sLogFile = @ScriptDir & "\citi_awake.log"
Global $g_sConfigFile = @ScriptDir & "\config.ini"
Global $g_iAwakeInterval = Int(IniRead($g_sConfigFile, "Settings", "AwakeInterval", "300"))
Global $g_iCheckInterval = Int(IniRead($g_sConfigFile, "Settings", "CheckInterval", "500"))
Global $g_iTolerance = Int(IniRead($g_sConfigFile, "Settings", "Tolerance", "30"))
Global $g_iLastAwakeTime = 0
Global $g_iDllRestartInterval = Int(IniRead($g_sConfigFile, "Settings", "DllRestartInterval", "1800")) ; 默认30分钟重启一次DLL
Global $g_iLastDllRestartTime = 0
Global $g_sPassword = IniRead($g_sConfigFile, "Credentials", "Password", "")
Global $g_sScreenshotDir = @ScriptDir & "\" & IniRead($g_sConfigFile, "Settings", "ScreenshotDir", "screenshots")

; 规则数组：[n][0]=名称, [n][1]=图片路径, [n][2]=按键, [n][3]=延迟, [n][4]=OffsetX%, [n][5]=OffsetY%, [n][6]=图片宽度, [n][7]=图片高度, [n][8]=ScrLeft, [n][9]=ScrTop, [n][10]=ScrRight, [n][11]=ScrBottom
Global $g_aRules[0][12]

; ============================================
; 热键
; ============================================
HotKeySet("^!p", "TypePassword")
HotKeySet("^!q", "ExitScript")

; ============================================
; 初始化
; ============================================
WriteLog("INFO", "========== 程序启动 ==========")
_GDIPlus_Startup()

; 创建截图目录
If Not FileExists($g_sScreenshotDir) Then DirCreate($g_sScreenshotDir)

; 加载规则
LoadRules()
If UBound($g_aRules) = 0 Then
    MsgBox(16, "错误", "没有找到任何规则，请检查 config.ini")
    Exit
EndIf

; 初始化图像搜索
_ImageSearch_Startup()
If @error Then
    MsgBox(16, "错误", "ImageSearch 初始化失败")
    Exit
EndIf

WriteLog("INFO", "初始化完成，已加载 " & UBound($g_aRules) & " 条规则")
TrayTip("图像触发器已启动", "Ctrl+Alt+P 输入密码 | Ctrl+Alt+Q 退出", 5)

; ============================================
; 主循环
; ============================================
While True
    ; 防休眠
    If TimerDiff($g_iLastAwakeTime) > ($g_iAwakeInterval * 1000) Then
        KeepAwake()
        $g_iLastAwakeTime = TimerInit()
    EndIf

    ; 定期重启 ImageSearch DLL 防止内存泄漏
    If TimerDiff($g_iLastDllRestartTime) > ($g_iDllRestartInterval * 1000) Then
        RestartImageSearchDll()
        $g_iLastDllRestartTime = TimerInit()
    EndIf

    ; 检查所有规则
    CheckAllRules()
    Sleep(500)
WEnd

; ============================================
; 函数：加载规则
; ============================================
Func LoadRules()
    Local $aSections = IniReadSectionNames($g_sConfigFile)
    If @error Then
        WriteLog("ERROR", "无法读取配置文件")
        Return
    EndIf

    For $i = 1 To $aSections[0]
        Local $sSection = $aSections[$i]
        ; 只处理以 Rule_ 开头的 section
        If StringLeft($sSection, 5) = "Rule_" Then
            Local $sImage = IniRead($g_sConfigFile, $sSection, "Image", "")
            Local $sKeys = IniRead($g_sConfigFile, $sSection, "Keys", "")
            Local $iDelay = Int(IniRead($g_sConfigFile, $sSection, "Delay", "1500"))
            Local $iOffsetX_Percent = Int(IniRead($g_sConfigFile, $sSection, "ClickOffsetX_Percent", "50"))
            Local $iOffsetY_Percent = Int(IniRead($g_sConfigFile, $sSection, "ClickOffsetY_Percent", "50"))

            ; 读取截图区域（仅用于 {SCREENSHOT} 规则）
            Local $sScreenshotRegion = IniRead($g_sConfigFile, $sSection, "ScreenshotRegion", "")
            Local $iScrLeft = 0, $iScrTop = 0, $iScrRight = 0, $iScrBottom = 0
            If $sScreenshotRegion <> "" Then
                Local $aRegion = StringSplit($sScreenshotRegion, ",", 2)
                If UBound($aRegion) = 4 Then
                    $iScrLeft = Int(StringStripWS($aRegion[0], 3))
                    $iScrTop = Int(StringStripWS($aRegion[1], 3))
                    $iScrRight = Int(StringStripWS($aRegion[2], 3))
                    $iScrBottom = Int(StringStripWS($aRegion[3], 3))
                Else
                    WriteLog("WARN", "规则 [" & $sSection & "] ScreenshotRegion 格式错误，应为 Left,Top,Right,Bottom")
                EndIf
            EndIf

            ; Clamp offset percentages to valid range 0-100
            If $iOffsetX_Percent < 0 Or $iOffsetX_Percent > 100 Then
                WriteLog("WARN", "规则 [" & $sSection & "] ClickOffsetX_Percent 超出范围，使用默认值 50")
                $iOffsetX_Percent = 50
            EndIf
            If $iOffsetY_Percent < 0 Or $iOffsetY_Percent > 100 Then
                WriteLog("WARN", "规则 [" & $sSection & "] ClickOffsetY_Percent 超出范围，使用默认值 50")
                $iOffsetY_Percent = 50
            EndIf

            If $sImage = "" Or $sKeys = "" Then
                WriteLog("WARN", "规则 [" & $sSection & "] 缺少 Image 或 Keys，跳过")
                ContinueLoop
            EndIf

            ; 转换为完整路径
            Local $sFullPath = @ScriptDir & "\" & $sImage
            If Not FileExists($sFullPath) Then
                WriteLog("WARN", "规则 [" & $sSection & "] 图片不存在: " & $sFullPath)
                ContinueLoop
            EndIf

            ; 获取图片尺寸
            Local $hImage = _GDIPlus_ImageLoadFromFile($sFullPath)
            If @error Then
                WriteLog("WARN", "规则 [" & $sSection & "] GDI+ 无法加载图片: " & $sFullPath)
                ContinueLoop
            EndIf
            Local $iImgWidth = _GDIPlus_ImageGetWidth($hImage)
            Local $iImgHeight = _GDIPlus_ImageGetHeight($hImage)
            _GDIPlus_ImageDispose($hImage)

            ; 添加规则
            Local $iCount = UBound($g_aRules)
            ReDim $g_aRules[$iCount + 1][12]
            $g_aRules[$iCount][0] = $sSection
            $g_aRules[$iCount][1] = $sFullPath
            $g_aRules[$iCount][2] = $sKeys
            $g_aRules[$iCount][3] = $iDelay
            $g_aRules[$iCount][4] = $iOffsetX_Percent
            $g_aRules[$iCount][5] = $iOffsetY_Percent
            $g_aRules[$iCount][6] = $iImgWidth
            $g_aRules[$iCount][7] = $iImgHeight
            $g_aRules[$iCount][8] = $iScrLeft
            $g_aRules[$iCount][9] = $iScrTop
            $g_aRules[$iCount][10] = $iScrRight
            $g_aRules[$iCount][11] = $iScrBottom


            WriteLog("INFO", "加载规则: [" & $sSection & "] -> " & $sImage)
        EndIf
    Next
EndFunc

; ============================================
; 函数：检查所有规则
; ============================================
Func CheckAllRules()
    Local Static $iCheckCount = 0
    Local Static $iLastLogTime = 0

    $iCheckCount += 1

    For $i = 0 To UBound($g_aRules) - 1
        Local $sRuleName = $g_aRules[$i][0]
        Local $sImagePath = $g_aRules[$i][1]
        Local $sKeys = $g_aRules[$i][2]
        Local $iDelay = $g_aRules[$i][3]
        Local $iOffsetX_Percent = $g_aRules[$i][4]
        Local $iOffsetY_Percent = $g_aRules[$i][5]
        Local $iImgWidth = $g_aRules[$i][6]
        Local $iImgHeight = $g_aRules[$i][7]

        Local $aResult = _ImageSearch($sImagePath, 0, 0, 0, 0, -1, $g_iTolerance)
        Sleep(50) ; 给热键处理留出响应窗口

        If @error Then ContinueLoop
        If Not IsArray($aResult) Then ContinueLoop
        If UBound($aResult, 0) <> 2 Then ContinueLoop

        If $aResult[0][0] > 0 Then
            Local $iFoundX = $aResult[1][0]
            Local $iFoundY = $aResult[1][1]
            WriteLog("INFO", "[" & $sRuleName & "] 匹配成功! 左上角坐标: (" & $iFoundX & ", " & $iFoundY & ")")

            Switch $sKeys
                Case "{LCLICK}", "{RCLICK}", "{DCLICK}"
                    Local $iClickX = $iFoundX + Round($iImgWidth * ($iOffsetX_Percent / 100))
                    Local $iClickY = $iFoundY + Round($iImgHeight * ($iOffsetY_Percent / 100))
                    Local $sClickType = "left"
                    Local $iClickCount = 1
                    Local $sLogMsg = "左键单击"

                    If $sKeys = "{RCLICK}" Then
                        $sClickType = "right"
                        $sLogMsg = "右键单击"
                    ElseIf $sKeys = "{DCLICK}" Then
                        $iClickCount = 2
                        $sLogMsg = "左键双击"
                    EndIf

                    MouseClick($sClickType, $iClickX, $iClickY, $iClickCount, 0)
                    WriteLog("INFO", "[" & $sRuleName & "] 已发送 " & $sLogMsg & " 到坐标 (" & $iClickX & ", " & $iClickY & ")")
                Case "{SCREENSHOT}"
                    ; 截取屏幕区域并保存到文件
                    Local $iScrLeft = $g_aRules[$i][8]
                    Local $iScrTop = $g_aRules[$i][9]
                    Local $iScrRight = $g_aRules[$i][10]
                    Local $iScrBottom = $g_aRules[$i][11]
                    Local $sTimestamp = @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC & "_" & @MSEC
                    Local $sSafeRuleName = StringRegExpReplace($sRuleName, '[\\/:*?"<>|]', "_")
                    Local $sScreenshotFile = $g_sScreenshotDir & "\" & $sSafeRuleName & "_" & $sTimestamp & ".png"
                    Local $bResult = _ImageSearch_ScreenCapture_SaveImage($sScreenshotFile, $iScrLeft, $iScrTop, $iScrRight, $iScrBottom)
                    If $bResult Then
                        WriteLog("INFO", "[" & $sRuleName & "] 截图已保存: " & $sScreenshotFile)
                    Else
                        WriteLog("ERROR", "[" & $sRuleName & "] 截图保存失败: " & $sScreenshotFile)
                    EndIf
                Case Else
                    Send($sKeys)
                    WriteLog("INFO", "[" & $sRuleName & "] 已发送按键: " & $sKeys)
            EndSwitch

            Sleep($iDelay)
            Return ; 匹配到一个就返回，避免重复触发
        EndIf
    Next

    ; 定期打印状态
    If TimerDiff($iLastLogTime) > 30000 Then
        WriteLog("DEBUG", "已检查 " & $iCheckCount & " 次，未匹配到任何规则")
        $iLastLogTime = TimerInit()
    EndIf
EndFunc

; ============================================
; 函数：防休眠
; ============================================
Func KeepAwake()
    Local $aPos = MouseGetPos()
    MouseMove(10, 10, 0)
    Sleep(10)
    MouseMove($aPos[0], $aPos[1], 0)
EndFunc

; ============================================
; 函数：手动输入密码
; ============================================
Func TypePassword()
    If $g_sPassword = "" Then
        TrayTip("错误", "未配置密码，请在 config.ini [Credentials] 中设置 Password", 5)
        Return
    EndIf
    Send($g_sPassword)
    WriteLog("INFO", "手动输入密码 (Ctrl+Alt+P)")
EndFunc

; ============================================
; 函数：定期重启 ImageSearch DLL
; ============================================
Func RestartImageSearchDll()
    _ImageSearch_Shutdown()
    Sleep(100)
    _ImageSearch_Startup()
    If @error Then
        WriteLog("ERROR", "ImageSearch DLL 重启失败")
    Else
        WriteLog("INFO", "ImageSearch DLL 已重启（防止内存泄漏）")
    EndIf
EndFunc

; ============================================
; 函数：退出
; ============================================
Func ExitScript()
    WriteLog("INFO", "程序退出")
    _ImageSearch_Shutdown()
    _GDIPlus_Shutdown()
    Exit
EndFunc

; ============================================
; 函数：写日志
; ============================================
Func WriteLog($sLevel, $sMessage)
    Local $sTime = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
    Local $hFile = FileOpen($g_sLogFile, $FO_APPEND)
    If $hFile <> -1 Then
        FileWrite($hFile, "[" & $sTime & "] [" & $sLevel & "] " & $sMessage & @CRLF)
        FileClose($hFile)
    EndIf
EndFunc
