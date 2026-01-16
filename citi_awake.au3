; ============================================
; Citi 远程办公助手（简单版 - 能工作的版本）
; ============================================

#include <AutoItConstants.au3>
#include <MsgBoxConstants.au3>
#include <FileConstants.au3>
#include "ImageSearchDLL_UDF\ImageSearchDLL_UDF.au3"

; ============================================
; 配置
; ============================================
Global $g_sLogFile = @ScriptDir & "\citi_awake.log"
Global $g_sConfigFile = @ScriptDir & "\config.ini"
Global $g_sPassword = IniRead($g_sConfigFile, "Credentials", "Password", "")
Global $g_iAwakeInterval = Int(IniRead($g_sConfigFile, "Settings", "AwakeInterval", "300"))
Global $g_iLoginCheckInterval = Int(IniRead($g_sConfigFile, "Settings", "LoginCheckInterval", "500"))

; 直接使用 images 目录下的 password_box.png
Global $g_sTriggerImage = @ScriptDir & "\images\password_box.png"

Global $g_iLastAwakeTime = 0

; ============================================
; 热键
; ============================================
HotKeySet("^!p", "TypePassword")
HotKeySet("^!q", "ExitScript")

; ============================================
; 初始化
; ============================================
WriteLog("INFO", "========== 程序启动 ==========")

If $g_sPassword = "" Then
    MsgBox(16, "错误", "请在 config.ini 中配置密码")
    Exit
EndIf

If Not FileExists($g_sTriggerImage) Then
    MsgBox(16, "错误", "找不到: " & $g_sTriggerImage)
    Exit
EndIf

_ImageSearch_Startup()
If @error Then
    MsgBox(16, "错误", "ImageSearch 初始化失败")
    Exit
EndIf

WriteLog("INFO", "初始化完成")
TrayTip("Citi 助手已启动", "Ctrl+Alt+Q 退出", 5)

; ============================================
; 主循环
; ============================================
While True
    If TimerDiff($g_iLastAwakeTime) > ($g_iAwakeInterval * 1000) Then
        KeepAwake()
        $g_iLastAwakeTime = TimerInit()
    EndIf

    CheckAndAutoLogin()
    Sleep($g_iLoginCheckInterval)
WEnd

; ============================================
; 函数
; ============================================
Func CheckAndAutoLogin()
    Local $aResult = _ImageSearch($g_sTriggerImage, 0, 0, 0, 0, -1, 15)

    If @error Then Return
    If Not IsArray($aResult) Then Return
    If UBound($aResult, 0) <> 2 Then Return

    If $aResult[0][0] > 0 Then
        WriteLog("INFO", "检测到登录界面!")
        Send($g_sPassword)
        Sleep(100)
        Send("{ENTER}")
        WriteLog("INFO", "登录完成")
        Sleep(1500)
    EndIf
EndFunc

Func KeepAwake()
    Local $aPos = MouseGetPos()
    MouseMove(10, 10, 0)
    Sleep(50)
    MouseMove($aPos[0], $aPos[1], 0)
EndFunc

Func TypePassword()
    Send($g_sPassword)
EndFunc

Func ExitScript()
    WriteLog("INFO", "程序退出")
    _ImageSearch_Shutdown()
    Exit
EndFunc

Func WriteLog($sLevel, $sMessage)
    Local $sTime = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
    Local $hFile = FileOpen($g_sLogFile, $FO_APPEND)
    If $hFile <> -1 Then
        FileWrite($hFile, "[" & $sTime & "] [" & $sLevel & "] " & $sMessage & @CRLF)
        FileClose($hFile)
    EndIf
EndFunc
