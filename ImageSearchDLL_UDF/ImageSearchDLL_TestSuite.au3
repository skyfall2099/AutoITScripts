#RequireAdmin
;~ #Region ;**** Directives created by AutoIt3Wrapper_GUI ****
;~ #AutoIt3Wrapper_UseX64=y
;~ #EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
;~ #pragma compile(x64, true) ; false
#cs ----------------------------------------------------------------------------
	;
	;    Title .........: ImageSearch Test Suite v3.5
	;    AutoIt Version : 3.3.16.1+
	;    Author ........: Dao Van Trong (TRONG.PRO)
	;    UDF Version ...: 3.5
	;    Build Date ....: 2025-11-11
	;
	;    Note ..........: This script is a graphical user interface (GUI) front-end for the
	;                     ImageSearchDLL_UDF.au3 and its underlying ImageSearch.dll.
	;                     It allows for visual configuration of image search tasks on the screen
	;                     or within another image file, and now includes a file browser for
	;                     selecting existing images.
	;
	; -------------------------------------------------------------------------------------------------------------------------------
	; #SECTION# SCRIPT OVERVIEW
	; -------------------------------------------------------------------------------------------------------------------------------
	;
	; This enhanced script provides a powerful and user-friendly interface for performing complex image search and automation tasks.
	; It acts as a control panel for the high-performance ImageSearch UDF, allowing you to visually configure, execute,
	; and log search operations without writing complex code. It supports searching images on the screen or within another image.
	; NEW: Added "Browse" buttons to select existing image files instead of only capturing from screen.
	;
	; -------------------------------------------------------------------------------------------------------------------------------
	; #SECTION# FIRST-TIME SETUP
	; -------------------------------------------------------------------------------------------------------------------------------
	;
	; Before you can start a search, you need to provide the images you want to find.
	;
	; 1. RUN THE SCRIPT: The main window will appear. On the right side, you will see 12 empty "Image Target" slots.
	;
	; 2. CREATE OR SELECT AN IMAGE:
	;    - Click the "Create" button next to slot #1 to capture a region from the screen.
	;    - OR click the "Browse" button next to slot #1 to select an existing image file.
	;
	; 3. FOR CREATE: The script window will hide. Your mouse cursor will turn into a crosshair.
	;    Click and drag a rectangle around the object on the screen you want to find. When you release the mouse button,
	;    a bitmap image named "Search_1.bmp" will be saved in the same directory as the script.
	;
	; 4. FOR BROWSE: A file dialog will open allowing you to select BMP, JPG, PNG, or other image files.
	;    The selected image will be copied to the script directory as "Search_X.bmp".
	;
	; 5. PREVIEW UPDATES: The image you just captured/selected will now appear in the preview panel for that slot.
	;
	; 6. REPEAT: Repeat this process for any other images you need to find (up to 12).
	;
	; 7. IMAGE-IN-IMAGE SEARCH: To search within an image, select "Search in Image" mode, then specify a source image file
	;    using the "Browse Source Image" button.
	;
#ce ----------------------------------------------------------------------------

; === INCLUDES ===
#include <Array.au3>
#include <GDIPlus.au3>
#include <ScreenCapture.au3>
#include <WinAPI.au3>
#include <WindowsConstants.au3>
#include <GUIConstantsEx.au3>
#include <EditConstants.au3>
#include <StaticConstants.au3>
#include <ButtonConstants.au3>
#include <Date.au3>
#include <Misc.au3>
#include <Math.au3>
#include <GuiEdit.au3>
#include <GuiStatusBar.au3>
#include <GuiComboBox.au3>
#include <ComboConstants.au3>
#include <WinAPIConstants.au3>
#include <File.au3>
;~ #include "ImageSearchDLL_UDF.au3" ; Core image search functionality v3.5

; === GLOBAL CONSTANTS ===
Global Const $AppSuite_Ver = "3.5"
Global Const $MAX_IMAGES = 12 ; Maximum number of image targets the GUI supports.
Global Const $g_sImgEmptySlots = @TempDir & "\" & 'Default_UIF.jpg' ; Default image to show in empty slots.
Global Const $g_sPlaceholderPath = _Deploy_ImgEmptySlots() ? $g_sImgEmptySlots : @WindowsDir & "\Web\Wallpaper\Windows\img0.jpg"
#include-once
; #INDEX# =======================================================================================================================
; Title ............: ImageSearch_UDF (DLL Embedded) [Need to install Visual C++ Redistributable 2015-2022]
; AutoIt Version ...: 3.3.16.1+
; Language .........: English
; Description ......: Advanced image search library with cache system and SIMD optimization
; Author ...........: Dao Van Trong - TRONG.PRO
; Version ..........: 3.5
; DLL Architecture .: C++14 (Windows XP SP3 - Windows 11)
; DLL Toolset ......: v141_xp
; ===============================================================================================================================
;
#include <Array.au3>
#include <WinAPI.au3>

;~ #RequireAdmin
;~ #AutoIt3Wrapper_UseX64=n
;~ #AutoIt3Wrapper_UseX64=y
;~ #pragma compile(x64, false)
;~ #pragma compile(x64, true)

; #CONSTANTS# ===================================================================================================================
Global Const $IMGS_UDF_VERSION = '3.5'
Global Const $IMGS_RESULTS_MAX = 64
Global Const $iSleepTime = 100
Global Const $g_IMGS_Debug = @Compiled ? False : True

; Cache System Constants
Global Const $IMGS_ENABLED_CACHE = 1   ;

; DLL Error Codes (matching C++ ErrorCode enum)
Global Const $IMGSE_INVALID_PATH = -1
Global Const $IMGSE_FAILED_TO_LOAD_IMAGE = -2
Global Const $IMGSE_FAILED_TO_GET_SCREEN_DC = -3
Global Const $IMGSE_INVALID_SEARCH_REGION = -4
Global Const $IMGSE_INVALID_PARAMETERS = -5
Global Const $IMGSE_INVALID_SOURCE_BITMAP = -6
Global Const $IMGSE_INVALID_TARGET_BITMAP = -7
Global Const $IMGSE_RESULT_TOO_LARGE = -9
Global Const $IMGSE_INVALID_MONITOR = -10

; ===============================================================================================================================

; #GLOBAL VARIABLES# ============================================================================================================
Global $g_bImageSearch_Debug = $g_IMGS_Debug

Global $g_sImgSearchDLL_Path = ""
Global $g_hImageSearchDLL = -1
Global $g_bImageSearch_Initialized = False
Global $g_sLastDllReturn = ""
Global $g_sImgSearchDLL_Dir = @ScriptDir
Global $g_sImgSearchDLL_CustomPath = ""
Global $g_bImageSearch_UseEmbeddedDLL = False
Global $g_sImgSearch_TempDLLPath = ""
Global $g_aMonitorList[1][9]

; DLL Info Cache (parsed from Get_DllInfo)
Global $g_sDllInfoCache = ""           ; Raw INI string
Global $g_mDllInfoParsed = Null         ; Parsed Map/Dictionary
; ===============================================================================================================================

; #TABLE OF CONTENTS (PUBLIC API)# =============================================================================================
;
; 📌 Startup & Configuration:
;   _ImageSearch_Startup              ; Initialize ImageSearch library by loading the DLL
;   _ImageSearch_Shutdown             ; Cleanup and unload the DLL
;   _ImageSearch_SetDllPath           ; Set custom DLL path before initialization
;
; 🔍 Core Search Functions:
;   _ImageSearch                      ; Search for image(s) on screen within specified region
;   _ImageSearch_InImage              ; Search for image(s) within another image file (offline)
;   _ImageSearch_hBitmap              ; Search for HBITMAP within another HBITMAP (advanced, uses hBitmap_Search)
;
; 📸 Screen Capture Functions:
;   _ImageSearch_CaptureScreen        ; Capture screen region to HBITMAP (DPI-aware, multi-monitor)
;   _ImageSearch_ScreenCapture_SaveImage ; Capture screen and save directly to file (BMP/PNG/JPG, 2x faster)
;   _ImageSearch_hBitmapLoad          ; Load image file to HBITMAP with background color support
;
; 🖱️ Mouse Functions:
;   _ImageSearch_MouseMove            ; Move mouse cursor with smooth movement and multi-monitor support
;   _ImageSearch_MouseClick           ; Click mouse at coordinates with configurable speed and clicks
;   _ImageSearch_MouseClickWin        ; Click at window-relative coordinates with window search
;
; ⏱️ Wait & Click Functions:
;   _ImageSearch_Wait                 ; Wait for image to appear with timeout (non-blocking)
;   _ImageSearch_WaitClick            ; Wait for image and click when found (combines Wait + Click)
;
; 🖥️ Monitor Functions:
;   _ImageSearch_Monitor_GetList      ; Get array of all monitors with position, size, DPI info
;   _ImageSearch_Monitor_ToVirtual    ; Convert monitor-relative coords to virtual desktop coords
;   _ImageSearch_Monitor_FromVirtual  ; Convert virtual desktop coords to monitor-relative coords
;   _ImageSearch_Monitor_Current      ; Auto-detect which monitor contains cursor (cursor-aware)
;   _ImageSearch_Monitor_GetAtPosition ; Get monitor info at position with auto cursor detection
;
; 🪟 Window Coordinate Functions:
;   _ImageSearch_Window_ToScreen      ; Convert window-relative coords to screen coords (client/full)
;   _ImageSearch_Window_FromScreen    ; Convert screen coords to window-relative coords (client/full)
;
; 🛠️ Cache & Info Functions:
;   _ImageSearch_ClearCache           ; Clear all cached image locations and bitmaps
;   _ImageSearch_WarmUpCache          ; Pre-load images into cache for faster searches
;   _ImageSearch_GetDllInfo           ; Get comprehensive DLL info (DLL, OS, CPU, Screen, Cache) in INI format ⭐ RECOMMENDED
;   _ImageSearch_GetLastResult        ; Get raw DLL return string from last search (debug)
;   _ImageSearch_PrimaryScale         ; Get primary monitor DPI scale (uses cached GetDllInfo)
;   _ImageSearch_GetDllValue          ; Generic accessor for any DLL info value
;
; ===============================================================================================================================


; Multi-monitor constants are now provided by WinAPIConstants.au3:
; $SM_XVIRTUALSCREEN, $SM_YVIRTUALSCREEN, $SM_CXVIRTUALSCREEN, $SM_CYVIRTUALSCREEN

; === GLOBAL VARIABLES ===
Global $g_asImagePaths[$MAX_IMAGES] ; Array to store the file paths for the 12 target images.
Global $g_nMsg ; Stores the message code from GUIGetMsg() for the main event loop.
Global $g_hMainGUI ; Handle for the main GUI window.
Global $g_hLog ; Handle for the activity log Edit control.
Global $g_hStatusBar ; Handle for the status bar at the bottom of the GUI.
Global $g_iCurrentMonitor = 0 ; Monitor where TestSuite is currently displayed

; --- GUI Control IDs ---
Global $g_idBtnStart, $g_idBtnSelectAll, $g_idBtnDeselectAll, $g_idBtnSelectArea, $g_idSystemInfo
Global $g_idInputDelay, $g_idChkMoveMouse
Global $g_idRadNoClick, $g_idRadSingleClick, $g_idRadDoubleClick
Global $g_idChkWait, $g_idInputWaitTime
Global $g_idChkUseArea, $g_idInputLeft, $g_idInputTop, $g_idInputRight, $g_idInputBottom
Global $g_idChkMultiSearch, $g_idChkFindAll, $g_idChkUseTolerance, $g_idInputTolerance, $g_idChkEnableDebug, $g_idChkUseCache
Global $g_aidPic[$MAX_IMAGES], $g_aidChkSearch[$MAX_IMAGES], $g_aidBtnCreate[$MAX_IMAGES], $g_aidBtnBrowse[$MAX_IMAGES]
Global $g_idRadSearchOnScreen, $g_idRadSearchInImage, $g_idInputSourceImage, $g_idBtnBrowseSource
; Monitor selection controls
Global $g_idChkUseSpecificMonitor, $g_idComboMonitor
Global $g_iMonitorCount = 0

_Main()

; #FUNCTION# ====================================================================================================================
; Name...........: _Main
; Description....: Main program entry point. Initializes all necessary components and enters the GUI message loop to handle user interactions.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _Main()
	; Explicitly initialize the ImageSearch library. This is a critical first step.
	If Not _ImageSearch_Startup() Then
		MsgBox(16, "Fatal Error", "Failed to initialize the ImageSearch DLL. @error: " & @error & @CRLF & "The script will now exit.")
		Exit
	EndIf

	; Start GDI+ for image processing and create the GUI
	_GDIPlus_Startup()
	_InitializeImagePaths()
	_EnumerateMonitors() ; NEW: Get monitor list using UDF
	_DetectCurrentMonitor() ; Detect which monitor TestSuite is on
	_CreateGUI()
	_UpdateAllImagePreviews()
	_RefreshImageTooltips()

	; Main event loop to handle GUI events. The script will wait here for user input.
	While 1
		$g_nMsg = GUIGetMsg()
		Switch $g_nMsg
			Case $GUI_EVENT_CLOSE
				Exit ; Exit the loop and terminate the script.

			Case $g_idRadSearchInImage, $g_idRadSearchOnScreen
				_UpdateSearchModeControls()

			Case $g_idChkUseSpecificMonitor
				_UpdateMonitorControls()

			Case $g_idBtnStart
				_ExecuteSearch() ; Begin the image search process.

			Case $g_idBtnSelectAll
				_SelectAll(True) ; Check all image target checkboxes.

			Case $g_idBtnDeselectAll
				_SelectAll(False) ; Uncheck all image target checkboxes.

			Case $g_idBtnSelectArea
				_SelectAreaOnScreen() ; Allow user to define a search area on the screen.

			Case $g_idBtnBrowseSource
				_BrowseSourceImage() ; Open file dialog to select the source image for image-in-image search.

				; Event handlers for the "Create" and "Browse" buttons for each image slot.
			Case $g_aidBtnCreate[0] To $g_aidBtnCreate[$MAX_IMAGES - 1]
				_HandleImageCreation($g_nMsg)

			Case $g_aidBtnBrowse[0] To $g_aidBtnBrowse[$MAX_IMAGES - 1]
				_HandleImageBrowse($g_nMsg)
		EndSwitch
	WEnd

	_Exit()
EndFunc   ;==>_Main

; #FUNCTION# ====================================================================================================================
; Name...........: _InitializeImagePaths
; Description....: Populates the global array '$g_asImagePaths' with default file paths for the search images (e.g., Search_1.bmp, Search_2.bmp).
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _InitializeImagePaths()
	For $i = 0 To $MAX_IMAGES - 1
		$g_asImagePaths[$i] = @ScriptDir & "\Search_" & $i + 1 & ".bmp"
	Next
EndFunc   ;==>_InitializeImagePaths

; #FUNCTION# ====================================================================================================================
; Name...........: _EnumerateMonitors
; Description....: Enumerates all monitors using UDF function and stores count
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _EnumerateMonitors()
	; Use UDF's built-in monitor enumeration
	_ImageSearch_Monitor_GetList()
	$g_iMonitorCount = $g_aMonitorList[0][0]

	If $g_bImageSearch_Debug Then
		ConsoleWrite("Detected " & $g_iMonitorCount & " monitor(s)" & @CRLF)
		For $i = 1 To $g_iMonitorCount
			Local $sInfo = "Monitor " & $i & ": " & $g_aMonitorList[$i][5] & "x" & $g_aMonitorList[$i][6]
			If $g_aMonitorList[$i][7] Then $sInfo &= " (Primary)"
			ConsoleWrite("  " & $sInfo & @CRLF)
		Next
	EndIf
EndFunc   ;==>_EnumerateMonitors

; #FUNCTION# ====================================================================================================================
; Name...........: _DetectCurrentMonitor
; Description....: Detects which monitor the TestSuite GUI is currently displayed on using primary monitor
; Remarks........: This is a simplified version. For cursor-based detection, use _ImageSearch_Monitor_Current() from UDF
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _DetectCurrentMonitor()
	$g_iCurrentMonitor = 0

	; Assume primary monitor for TestSuite
	For $i = 1 To $g_iMonitorCount
		If $g_aMonitorList[$i][7] Then ; Primary monitor
			$g_iCurrentMonitor = $i
			Return
		EndIf
	Next

	; Fallback to monitor 1
	If $g_iMonitorCount > 0 Then $g_iCurrentMonitor = 1
EndFunc   ;==>_DetectCurrentMonitor

; #FUNCTION# ====================================================================================================================
; Name...........: _PopulateMonitorCombo
; Description....: Populates the monitor selection combobox with detected monitors
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _PopulateMonitorCombo()
	; Always populate, even with 1 monitor
	Local $sMonitorList = ""

	; If no monitors detected, add default entry
	If $g_iMonitorCount = 0 Then
		$sMonitorList = "Monitor 1 (Primary) - " & @DesktopWidth & "x" & @DesktopHeight
	Else
		; Build monitor list from detected monitors
		For $i = 1 To $g_iMonitorCount
			Local $sLabel = "Monitor " & $i
			If $g_aMonitorList[$i][7] Then $sLabel &= " (Primary)"
			$sLabel &= " - " & $g_aMonitorList[$i][5] & "x" & $g_aMonitorList[$i][6]
			$sMonitorList &= ($i > 1 ? "|" : "") & $sLabel
		Next
	EndIf

	; Set data and select primary monitor by default
	GUICtrlSetData($g_idComboMonitor, $sMonitorList)

	; Find and select primary monitor
	For $i = 1 To $g_iMonitorCount
		If $g_aMonitorList[$i][7] Then
			_GUICtrlComboBox_SetCurSel($g_idComboMonitor, $i - 1)
			Return
		EndIf
	Next
	_GUICtrlComboBox_SetCurSel($g_idComboMonitor, 0)
EndFunc   ;==>_PopulateMonitorCombo

Func _CreateSlot(ByRef $aChk, ByRef $aPic, ByRef $aBtnCreate, ByRef $aBtnBrowse, $idx, $col, $row, _
		$baseLeft, $baseTop, $colSpacing, $rowSpacing, $slotGroupW, $slotGroupH, $slotChkW, $slotChkH, $slotPicW, $slotPicH, $slotBtnW, $slotBtnH)
	Local $leftGroup = $baseLeft + ($col * $colSpacing)
	Local $topGroup = $baseTop + ($row * $rowSpacing)
	GUICtrlCreateGroup("Slot " & ($idx + 1), $leftGroup, $topGroup, $slotGroupW, $slotGroupH)
	Local $ox_chk = 5, $oy_chk = 13
	Local $ox_pic = 10, $oy_pic = 36
	Local $ox_btnCreate = 5, $oy_btnCreate = 142
	Local $ox_btnBrowse = $ox_btnCreate + $slotBtnW + 6
	$aChk[$idx] = GUICtrlCreateCheckbox("Search", $leftGroup + $ox_chk, $topGroup + $oy_chk, $slotChkW, $slotChkH)
	$aPic[$idx] = GUICtrlCreatePic("", $leftGroup + $ox_pic, $topGroup + $oy_pic, $slotPicW, $slotPicH)
	GUICtrlSetState(-1, $GUI_DISABLE)
	$aBtnCreate[$idx] = GUICtrlCreateButton("Create", $leftGroup + $ox_btnCreate, $topGroup + $oy_btnCreate, $slotBtnW, $slotBtnH)
	GUICtrlSetTip(-1, "Capture an image from the screen for slot " & ($idx + 1) & ".")
	$aBtnBrowse[$idx] = GUICtrlCreateButton("Browse", $leftGroup + $ox_btnBrowse, $topGroup + $oy_btnCreate, $slotBtnW, $slotBtnH)
	GUICtrlSetTip(-1, "Select an existing image file for slot " & ($idx + 1) & ".")
	GUICtrlCreateGroup("", -99, -99, 1, 1)
EndFunc   ;==>_CreateSlot

Func _CreateGUI()


	$g_hMainGUI = GUICreate("ImageSearch Automation v" & $AppSuite_Ver & " by Dao Van Trong - TRONG.PRO", 1036, 786)
	GUISetFont(9, 400, 0, "Segoe UI")
	GUISetBkColor(0xF3F3F3)
	GUICtrlCreateGroup("Configuration", 10, 2, 460, 326)
	GUICtrlCreateGroup("Search Mode", 20, 22, 210, 222)
	$g_idRadSearchOnScreen = GUICtrlCreateRadio("Search on All Screens", 30, 42, 180, 20)
	GUICtrlSetState(-1, $GUI_CHECKED)
	GUICtrlSetTip(-1, "Search across all")
	$g_idChkUseSpecificMonitor = GUICtrlCreateCheckbox("Use Specific Monitor", 40, 67, 160, 20)
	GUICtrlSetTip(-1, "Search on a specific monitor")
	$g_idComboMonitor = GUICtrlCreateCombo("", 40, 92, 180, 25, BitOR($GUI_SS_DEFAULT_COMBO, $CBS_SIMPLE))
	GUICtrlSetTip(-1, "Select which monitor to search on")
	GUICtrlSetState($g_idComboMonitor, $GUI_DISABLE)
	_PopulateMonitorCombo()
	$g_idRadSearchInImage = GUICtrlCreateRadio("Search in Image", 30, 127, 132, 20)
	GUICtrlSetTip(-1, "Search for images within a specified source image file.")
	$g_idInputSourceImage = GUICtrlCreateInput("", 30, 157, 196, 23, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY))
	$g_idBtnBrowseSource = GUICtrlCreateButton("Browse", 167, 133, 55, 23)
	GUICtrlSetTip(-1, "Select the source image file to search within.")
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	GUICtrlCreateGroup("Parameters", 240, 22, 220, 120)
	GUICtrlCreateLabel("Timeout (ms):", 250, 44, 90, 20, $SS_RIGHT)
	$g_idInputWaitTime = GUICtrlCreateInput("5000", 355, 42, 80, 23)
	GUICtrlCreateLabel("Tolerance:", 250, 74, 90, 20, $SS_RIGHT)
	$g_idInputTolerance = GUICtrlCreateInput("10", 355, 72, 80, 23)
	GUICtrlCreateLabel("Delay (ms):", 250, 104, 90, 20, $SS_RIGHT)
	$g_idInputDelay = GUICtrlCreateInput("500", 355, 102, 80, 23)
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	GUICtrlCreateGroup("Actions on Found", 240, 144, 220, 100)
	$g_idChkMoveMouse = GUICtrlCreateCheckbox("Move Mouse", 250, 164, 104, 20)
	GUICtrlSetState(-1, $GUI_CHECKED)
	GUICtrlCreateLabel("Click:", 250, 189, 40, 20)
	$g_idRadNoClick = GUICtrlCreateRadio("None", 305, 189, 60, 20)
	GUICtrlSetState(-1, $GUI_CHECKED)
	$g_idRadSingleClick = GUICtrlCreateRadio("Single", 250, 214, 60, 20)
	$g_idRadDoubleClick = GUICtrlCreateRadio("Double", 310, 214, 60, 20)
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	$g_idChkUseCache = GUICtrlCreateCheckbox("Enable Cache", 248, 253, 210, 20)
	GUICtrlSetTip(-1, "Enable persistent cache for 30-50% speed boost on repeated searches")
	$g_idChkEnableDebug = GUICtrlCreateCheckbox("Enable DLL Debug", 248, 280, 210, 20)
	GUICtrlSetState(-1, $GUI_CHECKED)
	$g_idChkUseTolerance = GUICtrlCreateCheckbox("Use Tolerance", 248, 303, 210, 20)
	GUICtrlSetState(-1, $GUI_CHECKED)

	$g_idChkWait = GUICtrlCreateCheckbox("Wait for Image Found", 22, 302, 200, 20)
	$g_idChkFindAll = GUICtrlCreateCheckbox("Find All Occurrences", 22, 277, 200, 20)
	GUICtrlSetState(-1, $GUI_CHECKED)
	$g_idChkMultiSearch = GUICtrlCreateCheckbox("Multi Search (All at once)", 22, 252, 200, 20)
	GUICtrlSetTip(-1, "Finds the FIRST occurrence of ANY of the selected images.")
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	GUICtrlCreateGroup("Search Area", 10, 332, 460, 80)
	$g_idChkUseArea = GUICtrlCreateCheckbox("Use Custom Area", 23, 349, 150, 20)
	GUICtrlCreateLabel("Left:", 23, 382, 45, 20)
	$g_idInputLeft = GUICtrlCreateInput("0", 78, 380, 50, 23)
	GUICtrlCreateLabel("Top:", 139, 382, 45, 20)
	$g_idInputTop = GUICtrlCreateInput("0", 195, 380, 50, 23)
	GUICtrlCreateLabel("Right:", 256, 382, 45, 20)
	$g_idInputRight = GUICtrlCreateInput(@DesktopWidth, 301, 380, 50, 23)
	GUICtrlCreateLabel("Bottom:", 362, 382, 45, 20)
	$g_idInputBottom = GUICtrlCreateInput(@DesktopHeight, 408, 380, 50, 23)
	$g_idBtnSelectArea = GUICtrlCreateButton("Select Area on Screen", 191, 349, 268, 25)
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	GUICtrlCreateGroup("Activity Log", 10, 604, 1016, 158)
	$g_hLog = GUICtrlCreateEdit("", 15, 627, 1008, 128, BitOR($GUI_SS_DEFAULT_EDIT, $ES_READONLY))
	GUICtrlSetData(-1, "")
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	GUICtrlCreateGroup("System Information", 10, 416, 460, 184)
	GUICtrlCreateLabel("OS: " & @OSVersion & " (" & @OSArch & ")   |   AutoIt: " & @AutoItVersion & (@AutoItX64 ? "x64" : "x86") & "   |   UDF Version:" & $IMGS_UDF_VERSION, 20, 433, 440, 20)
	GUICtrlCreateLabel("DLL Path: " & $g_sImgSearchDLL_Path, 20, 457, 440, 36)
	GUICtrlCreateLabel("Screen: " & @DesktopWidth & "x" & @DesktopHeight & "   |   Monitors: " & $g_iMonitorCount, 20, 498, 440, 20)
	$g_idSystemInfo = GUICtrlCreateLabel(_ImageSearch_GetInfo(), 20, 522, 440, 72)
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	$g_idBtnSelectAll = GUICtrlCreateButton("Select All", 581, 560, 100, 38)
	$g_idBtnStart = GUICtrlCreateButton("Start Search", 692, 560, 340, 38, $BS_DEFPUSHBUTTON)
	GUICtrlSetFont(-1, 12, 800, 0, "Segoe UI")
	$g_idBtnDeselectAll = GUICtrlCreateButton("Deselect All", 472, 560, 100, 38)
	GUICtrlCreateGroup("Image Targets", 474, 10, 556, 546)
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	Dim $g_aidChkSearch[12], $g_aidPic[12], $g_aidBtnCreate[12], $g_aidBtnBrowse[12]
	Local $idx = 0
	For $r = 0 To 2
		For $c = 0 To 3
			_CreateSlot($g_aidChkSearch, $g_aidPic, $g_aidBtnCreate, $g_aidBtnBrowse, $idx, $c, $r, _
					479, 27, 135, 172, _
					127, 172, 100, 20, 100, 100, 55, 22)
			$idx += 1
		Next
	Next

	; Status bar
	$g_hStatusBar = _GUICtrlStatusBar_Create($g_hMainGUI)
	_UpdateStatus("Ready - ImageSearch Test Suite v" & $AppSuite_Ver)

	GUISetState(@SW_SHOW)
	_UpdateSearchModeControls()

	; Log initial info
	_LogWrite("═══════════════════════════════════════════════════════════")
	_LogWrite("ImageSearch Test Suite v" & $AppSuite_Ver & " - Initialized Successfully")
	_LogWrite("UDF Version: " & $IMGS_UDF_VERSION & "  |  DLL: " & _ImageSearch_GetDllValue("DLL", "Version"))
	_LogWrite("Detected " & $g_iMonitorCount & " monitor(s)")
	If $g_iMonitorCount > 0 Then
		For $i = 1 To $g_iMonitorCount
			Local $sMonInfo = "  Monitor " & $i & ": " & $g_aMonitorList[$i][5] & "x" & $g_aMonitorList[$i][6]
			If $g_aMonitorList[$i][7] Then $sMonInfo &= " (Primary)"
			If $i = $g_iCurrentMonitor Then $sMonInfo &= " ★ " ;"TestSuite by Dao Van Trong - TRONG.PRO"
			_LogWrite($sMonInfo)
		Next
	EndIf
	_LogWrite("═══════════════════════════════════════════════════════════")
	_LogWrite("Ready to search. Select images and click 'Start Search'")
EndFunc   ;==>_CreateGUI

Func _UpdateGUI_SystemInfo()
	GUICtrlSetData($g_idSystemInfo, "System Info: " & _ImageSearch_GetInfo())
EndFunc   ;==>_UpdateGUI_SystemInfo

; #FUNCTION# ====================================================================================================================
; Name...........: _GetControlPos
; Description....: Calculates the X and Y coordinates for a control within a grid layout based on its index.
; Parameters.....: $iIndex     - The zero-based index of the control in the grid.
;                  $iX_Start   - The starting X coordinate of the grid.
;                  $iY_Start   - The starting Y coordinate of the grid.
;                  $iColWidth  - The width of each column.
;                  $iRowHeight - The height of each row.
;                  $iX         - [ByRef] Returns the calculated X coordinate.
;                  $iY         - [ByRef] Returns the calculated Y coordinate.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _GetControlPos($iIndex, $iX_Start, $iY_Start, $iColWidth, $iRowHeight, ByRef $iX, ByRef $iY)
	$iX = $iX_Start + ($iColWidth * Mod($iIndex, 4)) ; 4 controls per row
	$iY = $iY_Start + ($iRowHeight * Int($iIndex / 4))
EndFunc   ;==>_GetControlPos

; #FUNCTION# ====================================================================================================================
; Name...........: _CreateCheckboxGrid
; Description....: Creates a grid of checkboxes for selecting which image slots to search.
; Parameters.....: $aidArray   - Array to store control IDs.
;                  $iCount     - Number of checkboxes to create.
;                  $iX_Start   - Starting X coordinate.
;                  $iY_Start   - Starting Y coordinate.
;                  $iColWidth  - Width of each column.
;                  $iRowHeight - Height of each row.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _CreateCheckboxGrid(ByRef $aidArray, $iCount, $iX_Start, $iY_Start, $iColWidth, $iRowHeight)
	For $i = 0 To $iCount - 1
		Local $iX, $iY
		_GetControlPos($i, $iX_Start, $iY_Start, $iColWidth, $iRowHeight, $iX, $iY)
		$aidArray[$i] = GUICtrlCreateCheckbox("Search " & ($i + 1), $iX, $iY, 100, 20)
	Next
EndFunc   ;==>_CreateCheckboxGrid

; #FUNCTION# ====================================================================================================================
; Name...........: _CreateBtnCreateGrid
; Description....: Creates a grid of "Create" buttons for capturing images from the screen.
; Parameters.....: $aidArray   - Array to store control IDs.
;                  $iCount     - Number of buttons to create.
;                  $iX_Start   - Starting X coordinate.
;                  $iY_Start   - Starting Y coordinate.
;                  $iColWidth  - Width of each column.
;                  $iRowHeight - Height of each row.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _CreateBtnCreateGrid(ByRef $aidArray, $iCount, $iX_Start, $iY_Start, $iColWidth, $iRowHeight)
	For $i = 0 To $iCount - 1
		Local $iX, $iY
		_GetControlPos($i, $iX_Start, $iY_Start, $iColWidth, $iRowHeight, $iX, $iY)
		$aidArray[$i] = GUICtrlCreateButton("Create", $iX, $iY + 125, 45, 20)
		GUICtrlSetTip(-1, "Capture an image from the screen for slot " & ($i + 1) & ".")
	Next
EndFunc   ;==>_CreateBtnCreateGrid

; #FUNCTION# ====================================================================================================================
; Name...........: _CreateBtnBrowseGrid
; Description....: Creates a grid of "Browse" buttons for selecting existing image files.
; Parameters.....: $aidArray   - Array to store control IDs.
;                  $iCount     - Number of buttons to create.
;                  $iX_Start   - Starting X coordinate.
;                  $iY_Start   - Starting Y coordinate.
;                  $iColWidth  - Width of each column.
;                  $iRowHeight - Height of each row.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _CreateBtnBrowseGrid(ByRef $aidArray, $iCount, $iX_Start, $iY_Start, $iColWidth, $iRowHeight)
	For $i = 0 To $iCount - 1
		Local $iX, $iY
		_GetControlPos($i, $iX_Start, $iY_Start, $iColWidth, $iRowHeight, $iX, $iY)
		$aidArray[$i] = GUICtrlCreateButton("Browse", $iX + 50, $iY + 125, 45, 20)
		GUICtrlSetTip(-1, "Select an existing image file for slot " & ($i + 1) & ".")
	Next
EndFunc   ;==>_CreateBtnBrowseGrid

; #FUNCTION# ====================================================================================================================
; Name...........: _CreatePicGrid
; Description....: Creates a grid of image preview controls to display the target images.
; Parameters.....: $aidArray   - Array to store control IDs.
;                  $iCount     - Number of controls to create.
;                  $iX_Start   - Starting X coordinate.
;                  $iY_Start   - Starting Y coordinate.
;                  $iColWidth  - Width of each column.
;                  $iRowHeight - Height of each row.
;                  $iPicWidth  - Width of each image preview.
;                  $iPicHeight - Height of each image preview.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _CreatePicGrid(ByRef $aidArray, $iCount, $iX_Start, $iY_Start, $iColWidth, $iRowHeight, $iPicWidth, $iPicHeight)
	For $i = 0 To $iCount - 1
		Local $iX, $iY
		_GetControlPos($i, $iX_Start, $iY_Start, $iColWidth, $iRowHeight, $iX, $iY)
		$aidArray[$i] = GUICtrlCreatePic("", $iX, $iY, $iPicWidth, $iPicHeight)
		GUICtrlSetState(-1, $GUI_DISABLE)
	Next
EndFunc   ;==>_CreatePicGrid

; #FUNCTION# ====================================================================================================================
; Name...........: _UpdateSearchModeControls
; Description....: Updates the state (enabled/disabled) of GUI controls based on the selected search mode (screen or image).
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _UpdateSearchModeControls()
	Local $bIsScreenSearch = __IsChecked($g_idRadSearchOnScreen)
	GUICtrlSetState($g_idInputSourceImage, ($bIsScreenSearch ? $GUI_DISABLE : $GUI_ENABLE))
	GUICtrlSetState($g_idBtnBrowseSource, ($bIsScreenSearch ? $GUI_DISABLE : $GUI_ENABLE))
	GUICtrlSetState($g_idChkMoveMouse, ($bIsScreenSearch ? $GUI_ENABLE : $GUI_DISABLE))
	GUICtrlSetState($g_idRadNoClick, ($bIsScreenSearch ? $GUI_ENABLE : $GUI_DISABLE))
	GUICtrlSetState($g_idRadSingleClick, ($bIsScreenSearch ? $GUI_ENABLE : $GUI_DISABLE))
	GUICtrlSetState($g_idRadDoubleClick, ($bIsScreenSearch ? $GUI_ENABLE : $GUI_DISABLE))
	GUICtrlSetState($g_idChkUseArea, ($bIsScreenSearch ? $GUI_ENABLE : $GUI_DISABLE))
	GUICtrlSetState($g_idInputLeft, ($bIsScreenSearch ? $GUI_ENABLE : $GUI_DISABLE))
	GUICtrlSetState($g_idInputTop, ($bIsScreenSearch ? $GUI_ENABLE : $GUI_DISABLE))
	GUICtrlSetState($g_idInputRight, ($bIsScreenSearch ? $GUI_ENABLE : $GUI_DISABLE))
	GUICtrlSetState($g_idInputBottom, ($bIsScreenSearch ? $GUI_ENABLE : $GUI_DISABLE))
	GUICtrlSetState($g_idBtnSelectArea, ($bIsScreenSearch ? $GUI_ENABLE : $GUI_DISABLE))
	GUICtrlSetState($g_idChkWait, ($bIsScreenSearch ? $GUI_ENABLE : $GUI_DISABLE))
	GUICtrlSetState($g_idInputWaitTime, ($bIsScreenSearch ? $GUI_ENABLE : $GUI_DISABLE))

	; Monitor selection controls
	GUICtrlSetState($g_idChkUseSpecificMonitor, ($bIsScreenSearch ? $GUI_ENABLE : $GUI_DISABLE))
	If Not $bIsScreenSearch Then
		GUICtrlSetState($g_idComboMonitor, $GUI_DISABLE)
	Else
		_UpdateMonitorControls()
	EndIf
EndFunc   ;==>_UpdateSearchModeControls

; #FUNCTION# ====================================================================================================================
; Name...........: _UpdateMonitorControls
; Description....: Updates monitor selection controls based on checkbox state
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _UpdateMonitorControls()
	Local $bScreenSearch = __IsChecked($g_idRadSearchOnScreen)
	Local $bUseSpecific = __IsChecked($g_idChkUseSpecificMonitor)

	If $bScreenSearch And $bUseSpecific Then
		GUICtrlSetState($g_idComboMonitor, $GUI_ENABLE)
		; Refresh monitor list to ensure it's always populated
		_PopulateMonitorCombo()
	Else
		GUICtrlSetState($g_idComboMonitor, $GUI_DISABLE)
	EndIf
EndFunc   ;==>_UpdateMonitorControls

; #REGION# === EVENT HANDLERS ===

; #FUNCTION# ====================================================================================================================
; Name...........: _HandleImageCreation
; Description....: Handles the "Create" button click for an image slot by capturing a screen region and saving it to a file.
; Parameters.....: $iControlID - The control ID of the clicked "Create" button.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _HandleImageCreation($iControlID)
	For $i = 0 To $MAX_IMAGES - 1
		If $g_aidBtnCreate[$i] = $iControlID Then
			GUISetState(@SW_HIDE, $g_hMainGUI)
			_UpdateStatus("Capturing image for slot " & ($i + 1) & "...")
			Local $iResult = _CaptureRegion_free($g_asImagePaths[$i])
			GUISetState(@SW_SHOW, $g_hMainGUI)
			If $iResult = 0 Then
				_LogWrite("Captured image for slot " & ($i + 1) & ": " & $g_asImagePaths[$i])
				_UpdateSingleImagePreview($i)
				_RefreshImageTooltips()
				_UpdateStatus("Image captured for slot " & ($i + 1))
			ElseIf $iResult = -2 Then
				_LogWrite("Image capture cancelled for slot " & ($i + 1))
				_UpdateStatus("Capture cancelled")
			Else
				_LogWrite("ERROR: Failed to capture image for slot " & ($i + 1))
				_UpdateStatus("Capture failed")
			EndIf
			ExitLoop
		EndIf
	Next
EndFunc   ;==>_HandleImageCreation

; #FUNCTION# ====================================================================================================================
; Name...........: _HandleImageBrowse
; Description....: Handles the "Browse" button click for an image slot by opening a file dialog and copying the selected image.
; Parameters.....: $iControlID - The control ID of the clicked "Browse" button.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _HandleImageBrowse($iControlID)
	For $i = 0 To $MAX_IMAGES - 1
		If $g_aidBtnBrowse[$i] = $iControlID Then
			Local $sFile = FileOpenDialog("Select Image for Slot " & ($i + 1), @ScriptDir, "Images (*.bmp;*.jpg;*.jpeg;*.png;*.gif)", 1)
			If @error Or Not _ValidateImageFile($sFile) Then
				_LogWrite("ERROR: Invalid or no image selected for slot " & ($i + 1))
				_UpdateStatus("Invalid image selected")
				Return
			EndIf
			If FileExists($g_asImagePaths[$i]) Then FileDelete($g_asImagePaths[$i])
			If FileCopy($sFile, $g_asImagePaths[$i], 1) Then
				_LogWrite("Selected image for slot " & ($i + 1) & ": " & $g_asImagePaths[$i])
				_UpdateSingleImagePreview($i)
				_RefreshImageTooltips()
				_UpdateStatus("Image selected for slot " & ($i + 1))
			Else
				_LogWrite("ERROR: Failed to copy image for slot " & ($i + 1))
				_UpdateStatus("Failed to copy image")
			EndIf
			ExitLoop
		EndIf
	Next
EndFunc   ;==>_HandleImageBrowse

; #FUNCTION# ====================================================================================================================
; Name...........: _BrowseSourceImage
; Description....: Opens a file dialog to select the source image for image-in-image search and updates the GUI.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _BrowseSourceImage()
	Local $sFile = FileOpenDialog("Select Source Image", @ScriptDir, "Images (*.bmp;*.jpg;*.jpeg;*.png;*.gif)", 1)
	If @error Or Not _ValidateImageFile($sFile) Then
		_LogWrite("ERROR: Invalid or no source image selected.")
		_UpdateStatus("Invalid source image")
		Return
	EndIf
	GUICtrlSetData($g_idInputSourceImage, $sFile)
	_LogWrite("Selected source image: " & $sFile)
	_UpdateStatus("Source image selected")
EndFunc   ;==>_BrowseSourceImage

; #FUNCTION# ====================================================================================================================
; Name...........: _ExecuteSearch
; Description....: Executes the image search based on user-specified parameters from the GUI and processes the results.
; Parameters.....: None (uses global GUI control states)
; Return values..: True if search executed successfully, False otherwise.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _ExecuteSearch()
	_UpdateGUI_SystemInfo()
	; Get search parameters from GUI controls
	Local $bMultiSearch = __IsChecked($g_idChkMultiSearch)
	Local $bFindAll = __IsChecked($g_idChkFindAll)
	Local $bWait = __IsChecked($g_idChkWait)
	Local $bUseTolerance = __IsChecked($g_idChkUseTolerance)
	Local $bEnableDebug = __IsChecked($g_idChkEnableDebug)
	Local $bUseCache = __IsChecked($g_idChkUseCache)
	Local $bUseArea = __IsChecked($g_idChkUseArea)
	Local $bMoveMouse = __IsChecked($g_idChkMoveMouse)
	Local $bSearchInImage = __IsChecked($g_idRadSearchInImage)
	Local $iTimeout = Number(GUICtrlRead($g_idInputWaitTime))
	Local $iTolerance = ($bUseTolerance ? Number(GUICtrlRead($g_idInputTolerance)) : 0)
	Local $iDelay = Number(GUICtrlRead($g_idInputDelay))
	Local $iLeft = ($bUseArea ? Number(GUICtrlRead($g_idInputLeft)) : 0)
	Local $iTop = ($bUseArea ? Number(GUICtrlRead($g_idInputTop)) : 0)
	Local $iRight = ($bUseArea ? Number(GUICtrlRead($g_idInputRight)) : 0)
	Local $iBottom = ($bUseArea ? Number(GUICtrlRead($g_idInputBottom)) : 0)

	; Monitor selection
	Local $iScreen = -1  ; Default: all monitors (virtual desktop)
	Local $bUseSpecificMonitor = __IsChecked($g_idChkUseSpecificMonitor)
	If $bUseSpecificMonitor And Not $bSearchInImage Then
		; Parse monitor number from combobox selection
		Local $sMonitorText = GUICtrlRead($g_idComboMonitor)
		Local $aMatch = StringRegExp($sMonitorText, "Monitor (\d+)", 1)
		If Not @error And IsArray($aMatch) Then
			$iScreen = Number($aMatch[0])
			_LogWrite("Using specific monitor: " & $iScreen & " (faster search)")
		EndIf
	EndIf

	; Cache parameter (v3.3 uses $IMGS_ENABLED_CACHE constant from UDF)
	Local $iUseCache = $bUseCache ? $IMGS_ENABLED_CACHE : 0
	If $bUseCache Then _LogWrite("Cache enabled for performance boost")

	Local $iCenterPos = 1 ; Return center coordinates
	Local $fMinScale = 1.0, $fMaxScale = 1.0, $fScaleStep = 0.1
	Local $iReturnDebug = ($bEnableDebug ? 1 : 0)
	Local $sClickType = (__IsChecked($g_idRadSingleClick) ? "single" : (__IsChecked($g_idRadDoubleClick) ? "double" : "none"))
	Local $iClicks = ($sClickType = "single" ? 1 : ($sClickType = "double" ? 2 : 0))

	; Build list of images to search with detailed logging
	Local $sImagePath = ""
	Local $sValidImages = ""
	Local $sInvalidImages = ""
	_LogWrite("Building list of images to search...")
	For $i = 0 To $MAX_IMAGES - 1
		If __IsChecked($g_aidChkSearch[$i]) Then
			If FileExists($g_asImagePaths[$i]) Then
				$sImagePath &= ($sImagePath = "" ? "" : "|") & $g_asImagePaths[$i]
				$sValidImages &= ($sValidImages = "" ? "" : ", ") & "Slot " & ($i + 1)
			Else
				GUICtrlSetState($g_aidChkSearch[$i], $GUI_UNCHECKED) ; Uncheck if image does not exist
				$sInvalidImages &= ($sInvalidImages = "" ? "" : ", ") & "Slot " & ($i + 1)
			EndIf
		EndIf
	Next
	If $sValidImages <> "" Then
		_LogWrite("Valid images selected: " & $sValidImages)
	Else
		_LogWrite("No valid images found.")
	EndIf
	If $sInvalidImages <> "" Then
		_LogWrite("Invalid or missing images (unchecked): " & $sInvalidImages)
	EndIf

	If $sImagePath = "" Then
		_LogWrite("ERROR: No valid images selected for search.")
		_UpdateStatus("Error: No images selected")
		Return False
	EndIf

	; Initialize result array
	Local $aResult
	Local $bSuccess = False

	If $bSearchInImage Then
		; Search within a source image
		Local $sSourceImage = GUICtrlRead($g_idInputSourceImage)
		If Not FileExists($sSourceImage) Then
			_LogWrite("ERROR: Source image file does not exist: " & $sSourceImage)
			_UpdateStatus("Error: Invalid source image")
			Return False
		EndIf

		_LogWrite("Starting image-in-image search for: " & $sImagePath)
		_UpdateStatus("Searching in image...")

		; Execute search
		$aResult = _ImageSearch_InImage($sSourceImage, $sImagePath, $iTolerance, ($bFindAll ? $MAX_IMAGES : 1), $iCenterPos, $fMinScale, $fMaxScale, $fScaleStep, $iReturnDebug, $iUseCache)
		If $bEnableDebug Then
			_LogWrite("DLL Raw Return: " & _ImageSearch_GetLastResult())
		EndIf
		If @error Then
			_LogSearchError(@error)
			_UpdateStatus("Search failed")
			Return False
		EndIf

		; Process results (v3.3: array format is [row][col] where col: 0=X, 1=Y, 2=W, 3=H)
		If $aResult[0][0] > 0 Then
			For $i = 1 To $aResult[0][0]
				_LogWrite("Found match " & $i & ": X=" & $aResult[$i][0] & ", Y=" & $aResult[$i][1] & ", Width=" & $aResult[$i][2] & ", Height=" & $aResult[$i][3])
				$bSuccess = True
			Next
			_UpdateStatus("Found " & $aResult[0][0] & " match(es)")
		Else
			_LogWrite("No matches found.")
			_UpdateStatus("No matches found")
		EndIf
	Else
		; Screen search
		_LogWrite("Starting screen search for: " & $sImagePath)
		_UpdateStatus("Searching on screen...")

		; All searches now use _ImageSearch with proper parameters
		If $bWait Then
			; Wait for image to appear (same params for area or full screen)
			$aResult = _ImageSearch_Wait($iTimeout, $sImagePath, $iLeft, $iTop, $iRight, $iBottom, $iScreen, $iTolerance, ($bFindAll ? $MAX_IMAGES : 1), $iCenterPos, $fMinScale, $fMaxScale, $fScaleStep, $iReturnDebug, $iUseCache)
		Else
			; Immediate search (replaced _ImageSearch_Area with _ImageSearch)
			$aResult = _ImageSearch($sImagePath, $iLeft, $iTop, $iRight, $iBottom, $iScreen, $iTolerance, ($bFindAll ? $MAX_IMAGES : 1), $iCenterPos, $fMinScale, $fMaxScale, $fScaleStep, $iReturnDebug, $iUseCache)
		EndIf

		If $bEnableDebug Then
			_LogWrite("DLL Raw Return: " & _ImageSearch_GetLastResult())
		EndIf
		If @error Then
			_LogSearchError(@error)
			_UpdateStatus("Search failed")
			Return False
		EndIf

		; Process results (v3.3: array format is [row][col] where col: 0=X, 1=Y, 2=W, 3=H)
		If $aResult[0][0] > 0 Then
			For $i = 1 To $aResult[0][0]
				_LogWrite("Found match " & $i & ": X=" & $aResult[$i][0] & ", Y=" & $aResult[$i][1] & ", Width=" & $aResult[$i][2] & ", Height=" & $aResult[$i][3])
				If $bMoveMouse Then
					_UpdateStatus("MouseMove X:" & $aResult[$i][0] & " Y:" & $aResult[$i][1])
					; Use DLL MouseMove to support negative coordinates
					_ImageSearch_MouseMove($aResult[$i][0], $aResult[$i][1], 0, $iScreen)
					_HighlightFoundArea($aResult[$i][0], $aResult[$i][1], $aResult[$i][2], $aResult[$i][3])
				EndIf
				If $iClicks > 0 Then
					_UpdateStatus("MouseClick 'left' X:" & $aResult[$i][0] & " Y:" & $aResult[$i][1])
					; Use DLL MouseClick with fallback support for negative coordinates
					_ImageSearch_MouseClick("left", $aResult[$i][0], $aResult[$i][1], $iClicks, 0, $iScreen)
				EndIf
				Sleep($iDelay)
				$bSuccess = True
			Next
			_UpdateStatus("Found " & $aResult[0][0] & " match(es)")
		Else
			_LogWrite("No matches found.")
			_UpdateStatus("No matches found")
		EndIf
	EndIf

	Return $bSuccess
EndFunc   ;==>_ExecuteSearch


; #FUNCTION# ====================================================================================================================
; Name...........: _SelectAreaOnScreen
; Description....: Allows the user to select a rectangular area on the screen by dragging the mouse and updates the GUI inputs.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _SelectAreaOnScreen()
	GUISetState(@SW_HIDE, $g_hMainGUI)
	_UpdateStatus("Selecting search area...")
	Local $aArea = _CaptureRegion_free()
	GUISetState(@SW_SHOW, $g_hMainGUI)
	If IsArray($aArea) Then
		GUICtrlSetData($g_idInputLeft, $aArea[0])
		GUICtrlSetData($g_idInputTop, $aArea[1])
		GUICtrlSetData($g_idInputRight, $aArea[2])
		GUICtrlSetData($g_idInputBottom, $aArea[3])
		GUICtrlSetState($g_idChkUseArea, $GUI_CHECKED)
		_LogWrite("Search area selected: Left=" & $aArea[0] & ", Top=" & $aArea[1] & ", Right=" & $aArea[2] & ", Bottom=" & $aArea[3])
		_UpdateStatus("Search area selected")
	ElseIf $aArea = -2 Then
		_LogWrite("Area selection cancelled.")
		_UpdateStatus("Area selection cancelled")
	Else
		_LogWrite("ERROR: Failed to select search area.")
		_UpdateStatus("Area selection failed")
	EndIf
EndFunc   ;==>_SelectAreaOnScreen

; #REGION# === SCREEN CAPTURE & AREA SELECTION ===

; #FUNCTION# ====================================================================================================================
; Name...........: _CaptureRegion_free
; Description....: Captures a user-defined rectangular region of the screen or returns the coordinates of the selected area.
;                  Automatically detects and applies screen DPI scaling for accurate capture on high-DPI displays.
; Parameters.....: $sFilePath - [optional] The file path to save the captured image. If empty, returns coordinates.
; Return values..: If $sFilePath is provided:
;                  | 0 = Success (image saved with correct scaling)
;                  | -1 = Capture failed
;                  | -2 = User cancelled
;                  If $sFilePath is empty:
;                  | Array [Left, Top, Right, Bottom] = Success (LOGICAL coordinates)
;                  | -1 = Capture failed
;                  | -2 = User cancelled
; Author.........: Dao Van Trong (TRONG.PRO)
; Remarks........: COORDINATE SCALING BEHAVIOR:
;                  - GetCursorPos returns LOGICAL coordinates (unscaled)
;                  - On 125% scaled display: logical 100 = physical 125
;                  - For capture: Coordinates are automatically scaled using _ImageSearch_GetScale()
;                  - Return value: Always returns LOGICAL coordinates for GUI display
;                  - DLL's ImageSearch_CaptureScreen receives PHYSICAL (scaled) coordinates
; ===============================================================================================================================
Func _CaptureRegion_free($sFilePath = "")
	Local $sTitle = "Select Region (" & ($sFilePath = "" ? "Area" : "Image") & ")"
	Local $hUserDLL = DllOpen("user32.dll")
	If $hUserDLL = -1 Then Return -1

	; Hide main GUI to avoid interference
	GUISetState(@SW_HIDE, $g_hMainGUI)

	; Create fullscreen semi-transparent overlay to block mouse clicks from passing through
	; Get virtual screen dimensions to cover all monitors
	Local $iVirtualX = _WinAPI_GetSystemMetrics(76) ; SM_XVIRTUALSCREEN
	Local $iVirtualY = _WinAPI_GetSystemMetrics(77) ; SM_YVIRTUALSCREEN
	Local $iVirtualW = _WinAPI_GetSystemMetrics(78) ; SM_CXVIRTUALSCREEN
	Local $iVirtualH = _WinAPI_GetSystemMetrics(79) ; SM_CYVIRTUALSCREEN

	; Create overlay without $WS_EX_TRANSPARENT and WITHOUT $WS_EX_LAYERED to capture mouse events
	; Use WinSetTrans() instead of _WinAPI_SetLayeredWindowAttributes() - this is the key!
	Local $hOverlay = GUICreate("", $iVirtualW, $iVirtualH, $iVirtualX, $iVirtualY, $WS_POPUP, $WS_EX_TOPMOST)
	GUISetBkColor(0x000001) ; Almost black (color unlikely to be on screen)
	WinSetTrans($hOverlay, "", 5) ; Very transparent (5 out of 255) but still captures mouse!
	GUISetState(@SW_SHOW, $hOverlay) ; Show and activate to capture mouse events
	GUISetCursor(3, 1, $hOverlay) ; Cross cursor for selection

	_UpdateStatus("Drag the mouse to select an area. Press ESC to cancel.")
	; Show instruction on current mouse position (using UDF function with auto-detect)
	Local $aMousePos = MouseGetPos()
	Local $sMonitorInfo = _ImageSearch_Monitor_GetAtPosition() ; Auto-detect cursor position
	ToolTip("Drag to select area. ESC to cancel." & @CRLF & $sMonitorInfo, $aMousePos[0] + 20, $aMousePos[1] + 20)

	; Wait for the user to press the left mouse button.
	While Not _IsPressed("01", $hUserDLL)
		If _IsPressed("1B", $hUserDLL) Then ; Check for ESC key press to cancel.
			ToolTip("")
			GUIDelete($hOverlay) ; Clean up overlay
			DllClose($hUserDLL)
			GUISetState(@SW_SHOW, $g_hMainGUI)
			Return -2
		EndIf
		; Update tooltip position
		$aMousePos = MouseGetPos()
		$sMonitorInfo = _ImageSearch_Monitor_GetAtPosition()
		ToolTip("Drag to select area. ESC to cancel." & @CRLF & $sMonitorInfo, $aMousePos[0] + 20, $aMousePos[1] + 20)
		Sleep(100)
	WEnd
	ToolTip("")

	; Use WinAPI GetCursorPos for accurate physical coordinates
	Local $tPoint = DllStructCreate("long X;long Y")
	DllCall("user32.dll", "bool", "GetCursorPos", "struct*", $tPoint)
	Local $iX1 = DllStructGetData($tPoint, "X")
	Local $iY1 = DllStructGetData($tPoint, "Y")
	ConsoleWrite("Start position (GetCursorPos): " & $iX1 & ", " & $iY1 & @CRLF)
	Local $iX2 = $iX1, $iY2 = $iY1  ; Initialize with start position
	Local $hRectGUI

	; While the mouse button is held down, draw a feedback rectangle.
	While _IsPressed("01", $hUserDLL)
		; Use WinAPI GetCursorPos for accurate coordinates
		DllCall("user32.dll", "bool", "GetCursorPos", "struct*", $tPoint)
		$iX2 = DllStructGetData($tPoint, "X")  ; Update continuously
		$iY2 = DllStructGetData($tPoint, "Y")

		If IsHWnd($hRectGUI) Then GUIDelete($hRectGUI)

		Local $iLeft = ($iX1 < $iX2 ? $iX1 : $iX2)
		Local $iTop = ($iY1 < $iY2 ? $iY1 : $iY2)
		Local $iWidth = Abs($iX1 - $iX2)
		Local $iHeight = Abs($iY1 - $iY2)

		; Show real-time monitor info and selection size (using UDF function)
		Local $sCurrentMonitor = _ImageSearch_Monitor_GetAtPosition($iX2, $iY2)
		ToolTip("Selection: " & $iWidth & "x" & $iHeight & @CRLF & $sCurrentMonitor, $iX2 + 20, $iY2 + 20)

		$hRectGUI = GUICreate("", $iWidth, $iHeight, $iLeft, $iTop, $WS_POPUP, BitOR($WS_EX_LAYERED, $WS_EX_TOPMOST))
		GUISetBkColor(0xFF0000) ; Red feedback rectangle.
		_WinAPI_SetLayeredWindowAttributes($hRectGUI, 0, 100) ; Set transparency.
		GUISetState(@SW_SHOWNOACTIVATE, $hRectGUI)
		Sleep(50)
	WEnd
	; At this point, $iX2 and $iY2 contain the last position BEFORE mouse was released
	ConsoleWrite("End position (GetCursorPos): " & $iX2 & ", " & $iY2 & @CRLF)

	ToolTip("") ; Clear tooltip

	; Clean up selection rectangle GUI and overlay
	If IsHWnd($hRectGUI) Then GUIDelete($hRectGUI)
	GUIDelete($hOverlay) ; Clean up overlay
	DllClose($hUserDLL)

	; Final coordinate calculation.
	Local $iLeft = ($iX1 < $iX2 ? $iX1 : $iX2)
	Local $iTop = ($iY1 < $iY2 ? $iY1 : $iY2)
	Local $iRight = ($iX1 > $iX2 ? $iX1 : $iX2)
	Local $iBottom = ($iY1 > $iY2 ? $iY1 : $iY2)

	GUISetState(@SW_SHOW, $g_hMainGUI)

	; If no area was selected (no drag), treat as a cancel.
	If $iLeft = $iRight Or $iTop = $iBottom Then Return -2

	; === SCREEN SCALE DETECTION ===
	; Detect current monitor and get its scale factor
	Local $fScale = _ImageSearch_GetScale(0)  ; Get primary monitor scale (e.g., 1.0, 1.25, 1.5)
	If @error Or $fScale = 0 Then $fScale = 1.0  ; Fallback to no scaling

	; Log selection details including monitor info (using UDF function)
	Local $sSelMonitor = _ImageSearch_Monitor_GetAtPosition(Int(($iLeft + $iRight) / 2), Int(($iTop + $iBottom) / 2))
	_LogWrite("Selected region: " & ($iRight - $iLeft) & "x" & ($iBottom - $iTop) & " on " & $sSelMonitor)
	_LogWrite("  Logical coordinates (from GetCursorPos): L=" & $iLeft & ", T=" & $iTop & ", R=" & $iRight & ", B=" & $iBottom)
	_LogWrite("  Screen Scale detected: " & ($fScale * 100) & "% (factor: " & $fScale & ")")

	; If a file path was provided, capture the screen area to that file.
	If $sFilePath <> "" Then
		Local $aMousePos = MouseGetPos()

		; === COORDINATE SCALING FIX ===
		; GetCursorPos returns LOGICAL coordinates (not scaled)
		; For scaled displays (125%, 150%, etc.), we need to multiply by scale factor
		; to get PHYSICAL coordinates for accurate capture

		; Apply scale factor to coordinates
		Local $iScaledLeft = Int($iLeft * $fScale)
		Local $iScaledTop = Int($iTop * $fScale)
		Local $iScaledRight = Int($iRight * $fScale)
		Local $iScaledBottom = Int($iBottom * $fScale)

		; Get DPI info for logging purposes
		Local $hDC = _WinAPI_GetDC(0)
		Local $iDpiX = _WinAPI_GetDeviceCaps($hDC, 88) ; LOGPIXELSX = 88
		_WinAPI_ReleaseDC(0, $hDC)

		_LogWrite("  DPI from DC: " & Round(($iDpiX / 96.0) * 100, 1) & "% (DPI=" & $iDpiX & ")")
		If $fScale <> 1.0 Then
			_LogWrite("  Scaled coordinates (for capture): L=" & $iScaledLeft & ", T=" & $iScaledTop & ", R=" & $iScaledRight & ", B=" & $iScaledBottom)
		EndIf
		_LogWrite("  Attempting capture with DLL...")

		; Move mouse out of the way briefly
		MouseMove(-9999, -9999, 0)
		Sleep(100)

		; v3.5: Use DLL's ImageSearch_CaptureScreen for DPI-aware capture
		; Use SCALED coordinates for accurate capture on high-DPI displays
		Local $hBitmap = _ImageSearch_CaptureScreen($iScaledLeft, $iScaledTop, $iScaledRight, $iScaledBottom, -1)

		; Restore mouse position
		MouseMove($aMousePos[0], $aMousePos[1], 0)

		If @error Or $hBitmap = 0 Then
			_LogWrite("  ❌ Capture failed! @error=" & @error)
			Return -1 ; Return error if capture failed.
		EndIf

		; Debug: Check bitmap dimensions
		Local $hImage = _GDIPlus_BitmapCreateFromHBITMAP($hBitmap)
		If $hImage Then
			Local $iCapturedW = _GDIPlus_ImageGetWidth($hImage)
			Local $iCapturedH = _GDIPlus_ImageGetHeight($hImage)
			Local $iExpectedW = $iRight - $iLeft
			Local $iExpectedH = $iBottom - $iTop
			_LogWrite("  ✅ Captured bitmap: " & $iCapturedW & "x" & $iCapturedH & " pixels (expected: " & $iExpectedW & "x" & $iExpectedH & ")")

			; Save bitmap to file using GDI+ with error checking
			Local $bSaveResult = _GDIPlus_ImageSaveToFile($hImage, $sFilePath)
			_GDIPlus_BitmapDispose($hImage)
			_WinAPI_DeleteObject($hBitmap)

			; Verify file was saved
			If $bSaveResult And FileExists($sFilePath) Then
				Local $iFileSize = FileGetSize($sFilePath)
				_LogWrite("  ✅ Saved to file: " & $sFilePath & " (" & Round($iFileSize / 1024, 1) & " KB)")
			Else
				_LogWrite("  ❌ File not created! Save result: " & $bSaveResult & ", File exists: " & FileExists($sFilePath))
				Return -1
			EndIf
		Else
			_LogWrite("  ❌ Failed to create GDI+ bitmap from HBITMAP")
			_WinAPI_DeleteObject($hBitmap)
			Return -1
		EndIf

		Return 0 ; Success.
	Else
		; If no file path, return the coordinates array.
		; NOTE: Returns LOGICAL coordinates (unscaled) for display in GUI
		; These will be scaled automatically when used for capture later
		Local $aReturn[4] = [$iLeft, $iTop, $iRight, $iBottom]
		Return $aReturn
	EndIf
EndFunc   ;==>_CaptureRegion_free

; === END SCREEN CAPTURE & AREA SELECTION ===

; #REGION# === UTILITY & HELPER FUNCTIONS ===

; #FUNCTION# ====================================================================================================================
; Name...........: _HighlightFoundArea
; Description....: Creates a temporary, semi-transparent GUI to visually highlight a found image location on the screen.
; Parameters.....: $iX, $iY    - The TOP-LEFT coordinates of the found area (NOT center).
;                  $iWidth     - The width of the highlight rectangle.
;                  $iHeight    - The height of the highlight rectangle.
;                  $iColor     - [optional] The color of the highlight rectangle in 0xRRGGBB format. Default is green.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _HighlightFoundArea($iX, $iY, $iWidth, $iHeight, $iColor = 0xFF00FF00)
	; FIX: $iX/$iY are already top-left coordinates, not center
	Local $hGUI = GUICreate("", $iWidth, $iHeight, $iX, $iY, $WS_POPUP, BitOR($WS_EX_LAYERED, $WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
	GUISetBkColor($iColor)
	_WinAPI_SetLayeredWindowAttributes($hGUI, 0, 128) ; 50% transparency.
	GUISetState(@SW_SHOWNOACTIVATE)
	Sleep(500) ; Display the highlight for half a second.
	GUIDelete($hGUI)
EndFunc   ;==>_HighlightFoundArea

; #FUNCTION# ====================================================================================================================
; Name...........: _LogWrite
; Description....: Writes a timestamped message to the activity log Edit control and ensures it scrolls to the latest entry.
; Parameters.....: $sMessage - The string message to log.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _LogWrite($sMessage)
	GUICtrlSetData($g_hLog, "[" & _NowTime(5) & "] " & $sMessage & @CRLF, 1) ; The '1' appends the text.
	_GUICtrlEdit_SetSel(GUICtrlGetHandle($g_hLog), 0x7FFFFFFF, 0x7FFFFFFF) ; Scroll to the end.
	ConsoleWrite($sMessage & @CRLF)
EndFunc   ;==>_LogWrite

; #FUNCTION# ====================================================================================================================
; Name...........: _LogSearchError
; Description....: Translates a numerical error code from the ImageSearch UDF into a human-readable message and logs it.
; Parameters.....: $iErrorCode - The status code returned by an _ImageSearch* function.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _LogSearchError($iErrorCode)
	Switch $iErrorCode
		Case 0
			_LogWrite("No matches found.")
		Case $IMGSE_FAILED_TO_GET_SCREEN_DC
			_LogWrite("ERROR: Failed to capture screen.")
		Case $IMGSE_INVALID_PARAMETERS
			_LogWrite("ERROR: Invalid parameters.")
		Case $IMGSE_INVALID_SEARCH_REGION
			_LogWrite("ERROR: Invalid search region.")
		Case $IMGSE_INVALID_Source_BITMAP
			_LogWrite("ERROR: Invalid Source bitmap.")
		Case $IMGSE_RESULT_TOO_LARGE
			_LogWrite("ERROR: Too many results.")
		Case Else
			_LogWrite("ERROR: Error code " & $iErrorCode)
	EndSwitch
EndFunc   ;==>_LogSearchError

; #FUNCTION# ====================================================================================================================
; Name...........: _UpdateAllImagePreviews
; Description....: Iterates through all image slots and calls the function to update their preview images.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _UpdateAllImagePreviews()
	For $i = 0 To $MAX_IMAGES - 1
		_UpdateSingleImagePreview($i)
	Next
EndFunc   ;==>_UpdateAllImagePreviews

; #FUNCTION# ====================================================================================================================
; Name...........: _UpdateSingleImagePreview
; Description....: Updates a single image preview slot. If the target image file exists, it's displayed. Otherwise, a placeholder is shown.
; Parameters.....: $iIndex - The index (0-11) of the image slot to update.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _UpdateSingleImagePreview($iIndex)
	If FileExists($g_asImagePaths[$iIndex]) Then
		GUICtrlSetImage($g_aidPic[$iIndex], $g_asImagePaths[$iIndex])
	Else
		; Use a default Windows wallpaper as a placeholder if available.
		If FileExists($g_sPlaceholderPath) Then
			GUICtrlSetImage($g_aidPic[$iIndex], $g_sPlaceholderPath)
		Else
			; Fallback to a generic icon from shell32.dll if the wallpaper is also missing.
			GUICtrlSetImage($g_aidPic[$iIndex], "shell32.dll", 22)
		EndIf
	EndIf
EndFunc   ;==>_UpdateSingleImagePreview

; #FUNCTION# ====================================================================================================================
; Name...........: _SelectAll
; Description....: Checks or unchecks all image target checkboxes simultaneously.
; Parameters.....: $bState - True to check all, False to uncheck all.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _SelectAll($bState)
	Local $iCheckState = ($bState ? $GUI_CHECKED : $GUI_UNCHECKED)

	For $i = 0 To $MAX_IMAGES - 1
		GUICtrlSetState($g_aidChkSearch[$i], $iCheckState)
	Next
EndFunc   ;==>_SelectAll

; #FUNCTION# ====================================================================================================================
; Name...........: _UpdateStatus
; Description....: Sets the text of the status bar at the bottom of the GUI.
; Parameters.....: $sMessage - The message to display.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _UpdateStatus($sMessage)
	_GUICtrlStatusBar_SetText($g_hStatusBar, $sMessage)
EndFunc   ;==>_UpdateStatus

; #FUNCTION# ====================================================================================================================
; Name...........: __IsChecked
; Description....: A helper function to check the state of a checkbox or radio button in a more readable way.
; Parameters.....: $iControlID - The control ID of the checkbox or radio button.
; Return values..: True if the control is checked, False otherwise.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func __IsChecked($iControlID)
	Return BitAND(GUICtrlRead($iControlID), $GUI_CHECKED) = $GUI_CHECKED
EndFunc   ;==>__IsChecked

; #FUNCTION# ====================================================================================================================
; Name...........: _GetImageDimensions
; Description....: Gets the width and height of an image file using GDI+.
; Parameters.....: $sImagePath - Path to the image file.
; Return values..: On success, a 2-element array [Width, Height]. On failure, returns False.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _GetImageDimensions($sImagePath)
	If Not FileExists($sImagePath) Then Return False

	Local $hImage = _GDIPlus_ImageLoadFromFile($sImagePath)
	If Not $hImage Then Return False

	Local $iWidth = _GDIPlus_ImageGetWidth($hImage)
	Local $iHeight = _GDIPlus_ImageGetHeight($hImage)
	_GDIPlus_ImageDispose($hImage)

	Local $aDimensions[2] = [$iWidth, $iHeight]
	Return $aDimensions
EndFunc   ;==>_GetImageDimensions

; #FUNCTION# ====================================================================================================================
; Name...........: _ValidateImageFile
; Description....: Validates if a file is a valid image that can be processed by GDI+. Checks for existence, size, and basic integrity.
; Parameters.....: $sImagePath - Path to the image file.
; Return values..: True if the image is valid, False otherwise.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _ValidateImageFile($sImagePath)
	If Not FileExists($sImagePath) Then Return False

	; Check file size (must be > 0 and < 50MB for reasonable processing)
	Local $iFileSize = FileGetSize($sImagePath)
	If $iFileSize <= 0 Or $iFileSize > 50 * 1024 * 1024 Then Return False

	; Try to load with GDI+ to validate it's a real, uncorrupted image.
	Local $hImage = _GDIPlus_ImageLoadFromFile($sImagePath)
	If Not $hImage Then Return False

	; Check minimum dimensions (at least 1x1 pixel).
	Local $iWidth = _GDIPlus_ImageGetWidth($hImage)
	Local $iHeight = _GDIPlus_ImageGetHeight($hImage)
	_GDIPlus_ImageDispose($hImage)

	Return ($iWidth > 0 And $iHeight > 0)
EndFunc   ;==>_ValidateImageFile

; #FUNCTION# ====================================================================================================================
; Name...........: _CreateImageInfoTooltip
; Description....: Creates a detailed tooltip string for an image slot, showing file name, dimensions, file size, and full path.
; Parameters.....: $iIndex - The index (0-11) of the image slot.
; Return values..: A formatted string containing the image's information for use in a tooltip.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _CreateImageInfoTooltip($iIndex)
	Local $sImagePath = $g_asImagePaths[$iIndex]
	Local $sTooltip = "Slot " & ($iIndex + 1) & ":" & @CRLF

	If FileExists($sImagePath) Then
		Local $aDims = _GetImageDimensions($sImagePath)
		Local $iFileSize = FileGetSize($sImagePath)
		Local $sFileSize = ""

		If $iFileSize < 1024 Then
			$sFileSize = $iFileSize & " B"
		ElseIf $iFileSize < 1024 * 1024 Then
			$sFileSize = Round($iFileSize / 1024, 1) & " KB"
		Else
			$sFileSize = Round($iFileSize / (1024 * 1024), 2) & " MB"
		EndIf

		$sTooltip &= "File: " & StringRegExpReplace($sImagePath, ".*\\", "") & @CRLF
		If IsArray($aDims) Then
			$sTooltip &= "Size: " & $aDims[0] & " x " & $aDims[1] & " px" & @CRLF
		EndIf
		$sTooltip &= "File Size: " & $sFileSize & @CRLF
		$sTooltip &= "Path: " & $sImagePath
	Else
		$sTooltip &= "No image file." & @CRLF
		$sTooltip &= "Click 'Create' or 'Browse'."
	EndIf

	Return $sTooltip
EndFunc   ;==>_CreateImageInfoTooltip

; #FUNCTION# ====================================================================================================================
; Name...........: _RefreshImageTooltips
; Description....: Updates the tooltips for all image preview controls with the latest file information.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _RefreshImageTooltips()
	For $i = 0 To $MAX_IMAGES - 1
		GUICtrlSetTip($g_aidPic[$i], _CreateImageInfoTooltip($i))
	Next
EndFunc   ;==>_RefreshImageTooltips

; #FUNCTION# ====================================================================================================================
; Name...........: _Exit
; Description....: Performs cleanup operations (like shutting down GDI+) and exits the script cleanly.
; Author.........: Dao Van Trong (TRONG.PRO)
; ===============================================================================================================================
Func _Exit()
	_GDIPlus_Shutdown()
	_ImageSearch_Shutdown()
	Exit
EndFunc   ;==>_Exit


Func _ImgEmptySlots()
	; This function holds the hex data for default_img.jpg
	; File size: 8.2 KB
	; Architecture: Not PE
	; Generated by AutoIt Embedded File Generator
	Local $sHexData = '0xFFD8FFE000104A46494600010101006000600000FFE1005A4578696600004D4D002A00000008000503010005000000010000004A03030001000000010000000051100001000000010100000051110004000000010000000051120004000000010000000000000000000186A00000B18FFFDB0043000201010201010202020202020202030503030303030604040305070607070706070708090B0908080A0807070A0D0A0A0B0C0C0C0C07090E0F0D0C0E0B0C0C0CFFDB004301020202030303060303060C0807080C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0CFFC00011080156015603012200021101031101FFC4001F0000010501010101010100000000000000000102030405060708090A0BFFC400B5100002010303020403050504040000017D01020300041105122131410613516107227114328191A1082342B1C11552D1F02433627282090A161718191A25262728292A3435363738393A434445464748494A535455565758595A636465666768696A737475767778797A838485868788898A92939495969798999AA2A3A4A5A6A7A8A9AAB2B3B4B5B6B7B8B9BAC2C3C4C5C6C7C8C9CAD2D3D4D5D6D7D8D9DAE1E2E3E4E5E6E7E8E9EAF1F2F3F4F5F6F7F8F9FAFFC4001F01000301010101010101'
	$sHexData &= '01010000000000000102030405060708090A0BFFC400B51100020102040403040705040400010277000102031104052131061241510761711322328108144291A1B1C109233352F0156272D10A162434E125F11718191A262728292A35363738393A434445464748494A535455565758595A636465666768696A737475767778797A82838485868788898A92939495969798999AA2A3A4A5A6A7A8A9AAB2B3B4B5B6B7B8B9BAC2C3C4C5C6C7C8C9CAD2D3D4D5D6D7D8D9DAE2E3E4E5E6E7E8E9EAF2F3F4F5F6F7F8F9FAFFDA000C03010002110311003F00F90E8A28AFED03F2F0A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A28'
	$sHexData &= '00A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A28'
	$sHexData &= '00A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A2A4B3B39B50BB8ADEDE29279E7711C71C6A59E462701401C924F000AFB3A3FD927E0F7EC23E14D3752FDA16E355F167C44D4A25BA83E1DE8178B10D3E221597FB42E14E632C0FDD4607FBBBC648F3730CD68E1396124E5397C318ABC9DB7B2D124BAB6D25D5EA7450C34AADDAD12DDBD97F5D96A7C5B457D8337FC14DBE1DD84A61D27F655F82D069AC70D1DFDA9BEB9DBD809CA2907DF6D68E85E2EFD96FF6D8BB1A2EAFE1597F676F195E46D1D8EB7A7DFF00DA7C38F2F3B05D4726DF254F4CA851DDA415E74B3BC5525ED313849C61D5A709B5E6E31937FF0080A91B2C25397BB4EAA6FE6BF16ADF7D8F8B68AF40FDA67F665F167EC95F15EEFC1FE31B38EDF508116E2DEE2DDCCB69A95B3E7CBB9B793037C4D8383804156560ACACA3CFEBDEA15E9D7A71AD464A5192BA6B668E39C250938C959A0A2BF487FE0DE3F857E1AF88FAF7C5F7F10681A46B6D6BA6585BC3F6EB44B8114731BAF355438380DB1338EBB457E7BFC45D3E1D23E20EBB696D1AC56F6BA8DC45120E888B230007D0015E4E0F3B862331C465CA2D3A2A177D1F3ABFE074D5C238508576FE3BFE0CC6A2B574CF02EB7AD786EF759B3D1B55BBD234C60B797D0DA4925B5A93D049201B509ED922B7FC21FB36FC45F883E1FF00ED6D03C03E35D734AC13F6'
	$sHexData &= 'DD3F43B9B9B7C0EBFBC442BFAD7AB53134609B9C92B69AB5BF639E34E4F448E2E8A92EED25B0BA9609E29219E1731C91C8A55E360705483C820F635D4F82BE01F8EBE24E95F6FF000E782BC5BAFD88629F68D3748B8BA8B70E08DD1A119FC6AAA56A74E3CF52492EEDD8518CA4ED157392A2AEF88BC35A97843579B4FD5B4FBDD2EFEDCE25B6BB81A09A33E8C8C011F88AAD676736A37715BDBC524F3CEE238E38D4B3C8C4E028039249E00154A49AE64F4134EF623A2B7D7E1478A5FC69FF0008D8F0D6BE7C459C7F658D3E6FB6E719FF0053B77F4E7A74AB9E3DF80FE38F855671DC78A3C19E2BF0DDBCA42A4BAA69171668E4F2003222826B3FACD1E651E7577B2BAD7D0AF672B376D8E528A29F6D6D25E5C470C31BCB2CAC111114B33B1380001D4935B10328AEDF55FD997E24685A23EA77DF0FBC6F67A7449E63DD4FA15D47022E33B8B940A063BE6B88ACA957A7515E9C93B76772A50947E2560A28A2B52428ADAF047C36F117C4CD45ECFC37A06B5E20BB8977BC1A6D8CB77222FA958D4902A5F1D7C2AF147C2FB88A1F13786F5FF0ECB38CC49A9E9F35A3483D5448A33F8565EDE9F3FB3E65CDDAFAFDC5724ADCD6D0C0A28AD7D4FC01AF689A3E9BA8DEE89ABDA69FAC8CD85CCD672470DF76FDD39187FF0080935729C5349BDC4937B1914576FAF7ECCFF11FC2DE156D7753F87FE3'
	$sHexData &= '7D3B4444F31B50BAD0AEA1B555FEF19590263DF35C4A234AE154166638000C926A2957A751374E49A5D9DC7284A3A49584A2BB997F661F897068A7527F879E394D3847E69BA6D06E84213FBDBFCBDB8F7CD70D452AF4EA5FD9C93B7677094251F895828A28AD490A28A2800A28A2800A28A2800A28A2800A28A2800A28A2803EB2FF008269693A77C1FF0008FC50F8FDAD58DADF2FC2BD2E383C3B0DCA878E4D72EDFCBB57DBC93E572C78E37060415C8F1EF8437FE13F8E5FB405CEA5F1ABC69E20D234CD69A7BCD4B5BB5B437D772DCB7CC32A01203313C8538C0180391ECDF0BA54D43FE08C3F142DACC6DBCD3BE2169B77A8375DF6D24091C4BED89431FC6BE48AF99C050FACE23195652719F37B34D5AF18C6316AD74D6F272DBAAD343D0AD3F670A514AEADCD6E8DB6F7F9248FD07F0E7FC13DBF653F167C0AF117C49B1F8CDF1065F07F856F21B0D4AF0E89B5A09A66458D44660DED92E9CAA9033EC6BE56FDADBC0DF06FC11AC68B1FC1FF001BF88BC6B67710CADA949AAE98D646D5C32F961372216DC0B67E5E303939C0F71FD9FBFE509DF1EFFEC6CD23FF00475A57C615C9C3F87C4CB135E55B13526A9547049F2D9AE48BD6D14EF793D9AE9A77D31B3A6A9C1469A5CD1BDD5FBB5A6BE47D75E09F88563FB5CFFC13B3C4BE0CF13DF69CFE3BF827147AC783EEEEE454BBBAD1F245'
	$sHexData &= 'DD8AB9399162501D530480100E178F916BB9F0E7C0CB8F11FC05F1178F93C43E16B6B7F0E5FDB5849A45C5FECD56F0CDD24860C7CE8BDCE470AFD769AE1ABDCCB30D4A84EB4684AF1736F97F95B49C92F26FDEF59339311525350735ADB7EEBA7F97C8FDC2FF008236FF00C140752FDAF3C19AF7872FBC29A178757E1DE97A7C11CBA6B32C779BC4C99F2C8C4607920E013F78D7C2BFF0515FF82B56B3FB5BF80752F87377E05F0E68D6D63ABEE6D42399E7B83E43B01E5E4011962393F37048F7AF65FF00836BA743E23F8C506E1E74B63A632A77601AEC13F9B0FCEBF39BE31D9CBA77C5DF155BCF1BC53C1AC5DC72230C323099C1047A835F9E645C3996C789F1A9525FBAF67286AF46E376F7D6EFBDD1EDE331D5DE5F4BDEF8B993DB5B3D0FD6CFF823A6A3E18F0D7FC1287C61A9F8BAC6DEFBC31677BAA5D6AF6F244245BAB78E2467565FE20557183C76E95F37F8BFFE0E1EF8ADFF000934A3C29E16F01E87E1BB76D96361716535C491C23855775990138FEE2A81D2BD7FF603FF0094107C61FF00AF1D7FFF00496BF282AB21E1ECBF30CCF31AD8EA6AA38D56927B2D35696D77A6BE418DC756A187A11A32B5E3D0FD18FF008262FECEF65FF050FF00DA1FE207C77F8BB67A55DE89A35CFDA6E2C522F2EC2E6F0C61CEF424E628E35525493B8B0CE79CDCF8EDFF00070CF8B34BF1D5C6'
	$sHexData &= '9BF0A3C29E12D37C1DA631B7B27D52D25967BA8D7857091C91AC4840E1304818C9EC3B2FF821B88FE26FEC19F1BBC03A6DD44BE23BCB9B892388B7CC12E6C52189B1E85E2719F6AFCB7F12F86AFF00C1BE21BED2755B49EC352D3677B6BAB69976C904884AB2B0EC4106B6C065183CCF3AC5D2CC23CD1C3F2469D37F0C62E3BA5E7DFF00E0115B13570F84A52A0ECE77727D5BBED73F5EFE067C60F017FC174BE03F883C27E39F0CE99A07C4FF000DDA79B6F7F6684987770B716EED9758F7801E16661823939047C11FF04F9F01DE7C3DFF00829E780FC37AC408BA8687E287B1BA8C8CA8962F314E33DB72E41FA1AFA07FE0DD3F84FABEA5FB46F8AFC70239A1F0F689A249A64D3B29114B3CD244E10374255622C476DCA78C8CF9F7C17F1BD87C48FF0082E3D9EB7A590DA7DFF8EEE5A0704112283228718E30DB723D88AE7C3D28E07119A657846FD846973257BA84A51778AF5DEC5CE4EB430F88ABF1B95AFDD26B5FD0FB8BFE0A9DFF000536B3FD81FE20C1A5782FC2DA0EA9F123C47611DCDFEA5A844C63B5B45664855F615790921F6AEF0ABC9E49C1F29FD85BFE0B55A97ED5BF16AD3E17FC62F09784EF34AF1A16D3EDEE6CAD5D60F3187CB15C432BC8AE8FCAE4118257839247847FC1C27FF27EB6BFF62B58FF00E8DB9AF97BF63BFF0093B8F859FF00637E93FF00A5B0D6592F06'
	$sHexData &= 'E575F86E188A94EF5654F9B9EEF993B5D59DF44B4B2DB42F179AE2218F708CBDD52B5BA5BFE09EA7FF000564FD90F4EFD8EBF6B7D4345D062687C33AE5B26AFA5C24922D5246657841272423AB633FC256BED6F813E05F00FF00C11CFF00616D27E2CF8A3C3B6FE21F8A9E2E8633671CBB44D14B3279896B1B907CA4441BA47504920F5F9457947FC1C81FF2723E04FF00B179FF00F4A1ABD47FE0B6BE19BDF8E3FB05FC25F1F786637D53C3DA5AC3757925BFEF160867B65093363F84300A4E382E3A735854C756CCB2ECA70B8C9BF675DB551DEDCDCABDD8B7FDE7BF765468C70F5F135292F7A1F0F95F77F23C7FC31FF0719FC59B5F1AC373ACF84FC0B7DA019B33D8DAC1736F71E57A24CD3380C3D59083CF033C75DFF055CFD973C03FB40FECABA37ED35F0B74E8F4C5BF58A5D6ED6DE111ADCC72BEC32BC6BC2CD14A76B91D4124E76835F9915FB09E06F845ACFC1EFF00837DBC43A6F886DA4B4BFBDD16F35516D3290F6F1CF71E6C40AB0055B6156231C1635E8E7F95E0722C4E0F199645529CAA460E29E9384B7BAEB6D35F3F430C1622B6329D5A5887CC945B4DF46B63F1EEBD77F618FD962EBF6C9FDA67C3BE0586792CECEF9DAE351BA400B5B5A46374ACA0F1B88C28EBF338C822BC8ABEEEFF0083786357FDBBB54240253C237A57D8FDA6D07F226BEDB89B1F5705956231547E'
	$sHexData &= '28C5B5E4FA3F91E4E5F46357130A73D9B47BEFED97FF000536F0FF00FC13235083E0BFC09F06786E3BAF0F451FF6A5E5E46CF6F04ACA0EC2B1B2BCD395219E477E09030C738A7FB197FC15DB4EFDBB7C5A9F087E3C7833C29776BE2E736D61756B6CE2D5E6C656396395DCAB920EC951810DB4601F9ABE35FF0082B87C25D73E15FEDEBE3D6D62DAE23B7F105F1D574EB975C25DC12804329E876B650F7056B8FF00F827DFC20D6FE36FED91F0F748D0ADE596E2DB5AB5D4AE6545256D2DEDE6496495880768017009E37328EF5F134384B27A9912C6CFF88E1CEEADDF3735B9B9AF7E8FA7EA7AD3CCF14B19EC97C37B72DB4B5ED6B1B3FF00052AFD8EC7EC4DFB526ABE15B379A7F0F5E44BA968B2CA4B39B690902366C72C8CACA7D40527AD7EAF7ED17FB4BF85BF635FF827DFC30F1C6ADE18D3FC49AD69961A7C1E19B4B8402386FA4B223CC0D83B36C42424A8DD8C818CE6BE29FF00838AFC77A77883F6ADF0BE8B6AD1C97BA06823ED857AA34D2B32213EA14671FED8F5AF59FF0082CFFF00CA2DBE06FF00D7F699FF00A6B9EBCAC6B9E6D86C9BEBF76EA37CDAD9B56F2FE64B5F2674D2B61A78BF63F652B796BFA1E01E2EFF0082FE7C6FF18F87F57D32E34DF87D15A6AF6D25AB08F4A9CB408EA54942D3919C1FE20C3DABDFBF628F841F0FFF00E0995FB07DBFED05E3DD0E2D73C6FE'
	$sHexData &= '21823B8D2A095434B6EB367ECF043B87EEDD97E777C6E032390307F286BF597FE0A49E1EBBFDA4BFE08E5F0A3C5BE178A5BDD3FC311586A3A8451AEF78225B57B790B05E9E5BB7CC7A0009E8335EC71365183C1BC2E5D8582A347115146A38E9CC92D22DFF007B6397018AAB57DA57A8F9A508DE37D6DDDFC8F20B4FF838CFE2EC7E321753F84FC052E87E7EE6D3D20B9498C59FBA27F38E1F1FC5B08CF3B7B57A37FC1457F67FF87DFB747EC470FED2DF0D3488344D76CE3FB56BB6F1C4B1BDDC6ADB2E1660B853344DCF99D5957BE463F2CEBF59BF66DF0D5D7ECF3FF0411F88379E2C0FA68F1769FA8CBA7C17276B1176A20B7C03FF003D1B0C0752181A9E21C9B0592D4C2E372A8FB2A8EA46168B7EFC65BA6AFAFAFF00C01E071557171A94B12F9A3CADEBD1AD99F933451457EA47CE8514514005145140051451400514514005145140051451401F477FC13AFE367867C29E24F177C37F883A8369BF0F3E2EE95FD89A8DE900A69376AE1ECEF98120011499C93C00D93C035E75FB56FECADE2CFD8F7E316A5E0EF1659490CD6AE5ECAF56322D756B627E4B8818F0C8C3AE0E55B72B619481E6D5F4BFC06FF82893786BE14DB7C37F8AFE0CD33E2F7C3DB371FD9F6DA95C3C3A9682BB7611677432D1A85C613B6D001519AF9FC561B1585C4CB1B838F3A9DB9E1749B6B4528B765CD6D1A6'
	$sHexData &= 'D2692D535AF6D3A94EA5354AABB35B3FD1F975BAD8C7F861FB57681E09FF00827A7C4CF8497563AC4BE21F1A6B963A959DD451C66CA18A07859C48C5C3863E51C0542391922BC02BEAEB87FD8A35B9DAEF6FED21A2283B9EC21FEC99D587F76376248FAB9A7EB7FB687C19F825E0AD4745F82FF07619F52D56DDEDE6F147C405B7D5EFE247C0222B5DAD6E8703AF20E7953DF9B0B8C74E73FAA616A73549734B9AD149D92BB6DED64B48A93F234A94B992F6B52368AB2B6AFABDBE7D6C7837C6BD2FE1EE989E17FF00840754F126A6D3E876F2EBFF00DAF6F1C42DB5339F3A28367588718CE4FF00B47B70F4B2399246638058E4E0003F21C0A4AFA4A34DD3828393979BDFF438272E677B58F67FD857F6D3D7FF00617F8E1078BB46B74D4AD2784DA6A9A649298E3BFB7241DBB803B5C100AB60E0F6C122BEA1FDB87FE0A39FB347ED43F067C4E349F839AA58FC4CD7A3468F5B9F4AB1B7682E015CC8D7314C65930063053E6E01C57E7BD15E2637867038AC6C3309A71AB1B6B1938DD2774A56DD7FC31D74B1F5A9D274159C5F46AF6F43ED1FD98FFE0A55E13F82BFF04DCF885F06B53D0FC4373E22F1443A84161776AB0B5928BA8447BA566915D4A9C9C2A36401C8CF1F175145776072AC3E0EA56AB4159D59734B5EBB7C8C6B626756318CF68AB2F43D4BF643FDAEFC5DFB16FC5FB5F177'
	$sHexData &= '84AE23F3157C8BEB19F26DB52809C98A40083EE1872A4023B83F76F89BFE0A61FB1FFED4F343AEFC57F831AC41E2C48D64B99EDAD63945C3AF44F3E19A29251C71E6A018E2BF3028AF3F35E17C163EB2C54F9A1552B73C24E32B766D6FF337C36635A8C3D9AB38F66AE8FD05FDAA3FE0B4DA45E7C1293E1AFC02F04C9F0DFC33770B5BDC5E491436D7491BE43A43140CC91B367994BB31C9C60FCD5F217EC81F1B2CBF671FDA6BC17E38D46D2EAFEC3C37A925DDC416DB7CE923C156D9B8805B04900900E3A8EB5E6F456B80E1CC060F0B530942168D4BF336DB94AEACDB93D6FF0097426B63EB55A91AB37AC76ECADE47D19FF0544FDB13C3FF00B707ED383C67E19D3B59D33498B48B7D3523D51234B8768DA46662B1BBA8199303E63D3DF15E39F03BC7B07C2BF8D5E0FF00145D412DD5B786F5BB2D525862203CA904E92B2AE78C90A40CFAD72D45776132CA186C1C703497B918F2AD75B6DB98D5C44EA5575A5BB773EA8FF82B07EDDDE1AFDBCFE32E81AEF85749D734BD3345D2BEC27FB55228E7964323393B637750A32003BB279E057ACFEC19FF00050FF1F7EC4FF00EC34CF89FF0E3C47E29F823E206923D2EFA6B12042AF92F144D2810CF1372446CCBFC5B588040FCFEAFBE7F619FF82BAF87BC1BF03E1F83FF001CBC283C63E00861169677515BA4F2DAC00FCB14B0B101D13F85'
	$sHexData &= 'D4875006031C11F299F6454E86514F0186C37B6A506AF1E66A696BEF41FF00326FBEAB43D2C1E3253C54AB54A9C927D6DA5FB35D8ED2F3F6FBFD897E1B6A7FF097783FE04EA7A878B997CFB6B5BAB08A0B3B4997E64CAB4F245110C7EF4313118F615EF5FB42FC7BF11F8BFF00E08BBE30F1AFC48862D275AF1FC323595844ACAB6D0DCDC2A5A42AADF371105639EB96638CD78CE93E37FF0082717C36D563F1369DA76A9ACDFD91F3EDF4992D757B840E3240F2EE310BFD2472BD2BE66FF82957FC14EB58FDBCB5EB1D32C34E7F0D78074272FA7E965C34D71263689A72BF2EE0BC2A2F0A09E589CD7C8E1B21FED0C650F6187AD08D39294AA576F9AD1D54209B7A37BB5D91E9CF19EC294F9E706E49A5186DAF567ADFFC1353F6E2FD9F7F67DFD917C5FE18F889E1A173E27D45EE1A6FF8938BC6D7A164C47089082136F230E55467703926A8FF00C1BDD34571FB7D6B92410FD9E07F0A5F34716F2FE529BAB4C2E4F27038CF7AF82ABEB7FF00822E7ED21E0DFD983F6C0B9D7BC73ACA683A35F787AEB4E4BB9219248D26696091436C56201113738C671EB5F5BC43C3F1A396E61570BCF3A95D5DABB96ABA457FC3FDC79982C6B957A11A964A0F7DBEF67D4FFB447FC150BE17DFFC6FF1CFC2EFDA07E180F1AE8BE16D76E2DF48D56C608A5BA8232E70ACACF1B215040DF1C80B01CA923270'
	$sHexData &= '9BFE0B09F003F649F026A3A6FECF7F09AEAD35ABD8C47F6ED42D92DA1638F95A593CD92E26DA4FDC62A09CFCC339AF83BF6D5F899A47C64FDAC7E2078A3409DEEB45D6F599EEACA678DA333445BE56DAC0119C670403CF205797D6581E03CB6A61692ACA6935172A7CF25072B2BDE37DEFBAD0BAD9CD78D4972357BBB4ACAF6F537FE28FC4DD6FE337C43D5FC53E23BE9352D735CB96BABBB87EAEE7B01D9400000380001DABEB2FDBD3FE0A55E13FDAC7F630F865F0EB47D0FC43A76B9E119AD67D467BC5845A3186CE4B72B0B248CEE097CE591381D2BE2EA2BEAF1393616BD4A15671B3A2EF0B689696DBB58F329E2AA42338A7F1EE15F5B7FC139FFE0AB7AFFEC436573E17D634A1E30F879A948D24DA6492ED9AC99F87680B6570C325A361B58F3952493F24D15AE6795E1730C3BC2E321CD07D3F54D6A9F9A270F88A9426AA527667E9C41FB767EC23A66B4BE2EB6F81DAD7FC241BF72D8FF635BF931B02486F24DD7D940CF390B9E9C71C7CDDFF000517FF0082A4F89BF6EFBCB4D1EDEC07857C07A4CBE6DA69114BE63DCC8321659DC001881F7500DAB93F78F35F2C515E365FC1F80C2E2238A6E75271F85CE4E5CBFE1BE8BF33AEBE695AA41D3D229EF6495FD428A28AFA93CE0A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A'
	$sHexData &= '28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A'
	$sHexData &= '28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2800A28A2803FFFD9'

	Return $sHexData
EndFunc   ;==>_ImgEmptySlots

; =================================================================
; Helper function to deploy the file from hex data.
; =================================================================
Func _Deploy_ImgEmptySlots()
	Local $sHexData = _ImgEmptySlots()
	Local $Deploy_Dir = @TempDir
	If $sHexData = "" Then Return SetError(1, 0, False)
	Local $hFile = FileOpen($g_sImgEmptySlots, 2 + 8 + 16)
	If $hFile = -1 Then Return SetError(2, 0, False)
	FileWrite($hFile, Binary($sHexData))
	FileClose($hFile)
	If Not FileExists($g_sImgEmptySlots) Then Return SetError(3, 0, False)
	Return True
EndFunc   ;==>_Deploy_ImgEmptySlots


; === END UTILITY & HELPER FUNCTIONS ===


; #PUBLIC FUNCTIONS - STARTUP & CONFIG# ========================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Startup
; Description ...: Initializes the ImageSearch library by loading the appropriate DLL
; Syntax ........: _ImageSearch_Startup()
; Parameters ....: None
; Return values .: Success - 1 (DLL loaded successfully)
;                  Failure - 0 (DLL not found or load failed)
;                  Failure - 0 and sets @error:
;                  |1 - No DLL found
;                  |2 - DllOpen failed
;                  |3 - Architecture mismatch
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: Must be called before using any search functions
;                  Automatically called on script start
;
;                  IMPORTANT: DLL v5+ uses thread-local DPI awareness.
;                  Loading this DLL will NOT affect your AutoIt GUI, even on high-DPI displays.
;                  Safe to load before or after GUICreate() without GUI resize issues.
; ===============================================================================================================================
Func _ImageSearch_Startup()
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Startup()" & @CRLF)
	If $g_bImageSearch_Initialized Then Return 1
	If $g_bImageSearch_Debug Then ConsoleWrite(">> ImageSearch UDF Version: " & $IMGS_UDF_VERSION & @CRLF)
	; Priority 1: Custom path
	If ($g_sImgSearchDLL_CustomPath <> "") And FileExists($g_sImgSearchDLL_CustomPath) Then
		$g_sImgSearchDLL_Path = $g_sImgSearchDLL_CustomPath
		If $g_bImageSearch_Debug Then ConsoleWrite(">> Using custom DLL: " & $g_sImgSearchDLL_Path & @CRLF)
	EndIf

	; Priority 2: Auto-search
	If ($g_sImgSearchDLL_Path = "") Or (Not FileExists($g_sImgSearchDLL_Path)) Then
		Local $aDllNames[3], $sSuffix = "ImageSearchDLL"
		$aDllNames[0] = $sSuffix & "_" & (@AutoItX64 ? "x64" : "x86") & ".dll"
		$aDllNames[1] = $sSuffix & ".dll"
		$aDllNames[2] = $sSuffix & "_XP_" & (@AutoItX64 ? "x64" : "x86") & ".dll"

		Local $sPath
		For $i = 0 To UBound($aDllNames) - 1
			$sPath = $g_sImgSearchDLL_Dir & "\" & $aDllNames[$i]
			If $g_bImageSearch_Debug Then ConsoleWrite('>> Find and Check DLL Path: ' & $sPath & @CRLF)
			If FileExists($sPath) Then
				$g_sImgSearchDLL_Path = $sPath
				ExitLoop
			EndIf
		Next
	EndIf
	Local $sArch = __ImgSearch_GetFileArch($g_sImgSearchDLL_Path, True)
	If ((($sArch = "x86") And @AutoItX64) Or (($sArch = "x64") And Not @AutoItX64)) Then
		If $g_bImageSearch_Debug Then ConsoleWrite('! Wrong Dll Arch [' & $sArch & ']: ' & $g_sImgSearchDLL_Path & @CRLF)
	EndIf
	If ((($sArch = "x86") And @AutoItX64) Or (($sArch = "x64") And (Not @AutoItX64))) Or ($g_sImgSearchDLL_Path = "") Or (Not FileExists($g_sImgSearchDLL_Path)) Then
		If $g_bImageSearch_Debug Then ConsoleWrite("!> No external DLL found, trying embedded DLL..." & @CRLF)

		$g_sImgSearchDLL_Path = __ImgSearch_ExtractEmbeddedDLL()
		If $g_sImgSearchDLL_Path <> "" Then
			$g_bImageSearch_UseEmbeddedDLL = True
			$g_sImgSearch_TempDLLPath = $g_sImgSearchDLL_Path
			If $g_bImageSearch_Debug Then ConsoleWrite(">> Using embedded DLL" & @CRLF)
			$sArch = __ImgSearch_GetFileArch($g_sImgSearchDLL_Path, True)
			If $g_bImageSearch_Debug Then ConsoleWrite('>> DLL Architecture:  ' & $sArch & @CRLF)
			IsVcRedist_Installed()
		EndIf
		If $g_sImgSearchDLL_Path = "" Then
			If $g_bImageSearch_Debug Then ConsoleWrite("!> ERROR: No DLL found (external or embedded)" & @CRLF)
			Return SetError(1, 0, 0)
		EndIf
	Else
		If $g_bImageSearch_Debug Then ConsoleWrite('>> DLL Architecture: ' & $sArch & @CRLF)
	EndIf
	$g_hImageSearchDLL = DllOpen($g_sImgSearchDLL_Path)
	If $g_hImageSearchDLL = -1 Then
		If $g_bImageSearch_Debug Then ConsoleWrite("!> ERROR: DllOpen failed: " & $g_sImgSearchDLL_Path & @CRLF)
		Return SetError(2, 0, 0)
	EndIf
	OnAutoItExitRegister("_ImageSearch_Shutdown")
	$g_bImageSearch_Initialized = True
	If $g_bImageSearch_Debug Then
		Local $sDllInfoAll = _ImageSearch_GetInfo()
		Local $sDllType = ($g_bImageSearch_UseEmbeddedDLL ? "[Embedded]" : "[External]")
		ConsoleWrite(">> ImageSearch DLL loaded successfully " & $sDllType & @CRLF)
		ConsoleWrite(">> Dll Path: " & $g_sImgSearchDLL_Path & @CRLF)
		ConsoleWrite($sDllInfoAll & @CRLF)
		ConsoleWrite(">> Screen Scale: " & _ImageSearch_GetScale() & @CRLF)
	EndIf
	Local $l_MonitorInfo = _ImageSearch_Monitor_GetList()
	If $g_bImageSearch_Debug Then ConsoleWrite($l_MonitorInfo)
	Return 1
EndFunc   ;==>_ImageSearch_Startup

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Shutdown
; Description ...: Closes the DLL and cleans up resources
; Syntax ........: _ImageSearch_Shutdown()
; Author.........: Dao Van Trong - TRONG.PRO
; ===============================================================================================================================
Func _ImageSearch_Shutdown()
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Shutdown()" & @CRLF)
	If Not $g_bImageSearch_Initialized Then Return
	If $g_hImageSearchDLL <> -1 Then
		DllClose($g_hImageSearchDLL)
		$g_hImageSearchDLL = -1
	EndIf
	; Clean up embedded DLL if used
	If $g_bImageSearch_UseEmbeddedDLL And $g_sImgSearch_TempDLLPath <> "" Then
		If FileExists($g_sImgSearch_TempDLLPath) Then
			; Retry mechanism because file might be locked
			Local $iRetries = 3
			While $iRetries > 0
				FileDelete($g_sImgSearch_TempDLLPath)
				If Not FileExists($g_sImgSearch_TempDLLPath) Then
					If $g_bImageSearch_Debug Then ConsoleWrite(">> Cleaned up embedded DLL: " & $g_sImgSearch_TempDLLPath & @CRLF)
					ExitLoop
				EndIf
				Sleep(100)
				$iRetries -= 1
			WEnd
			If FileExists($g_sImgSearch_TempDLLPath) Then
				If $g_bImageSearch_Debug Then ConsoleWrite("!> Warning: Could not delete temp DLL: " & $g_sImgSearch_TempDLLPath & @CRLF)
			EndIf
		EndIf
	EndIf
	$g_bImageSearch_Initialized = False
	If $g_bImageSearch_Debug Then ConsoleWrite(">> ImageSearch DLL closed" & @CRLF)
EndFunc   ;==>_ImageSearch_Shutdown

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_SetDllPath
; Description ...: Sets a custom DLL path (must be called before _ImageSearch_Startup)
; Syntax ........: _ImageSearch_SetDllPath($sPath)
; Parameters ....: $sPath - Full path to the DLL file
; Return values .: Success - 1
;                  Failure - 0 (file not found)
; ===============================================================================================================================
Func _ImageSearch_SetDllPath($sPath)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_SetDllPath($sPath=" & $sPath & ")" & @CRLF)
	If Not FileExists($sPath) Then Return 0
	$g_sImgSearchDLL_CustomPath = $sPath
	Return 1
EndFunc   ;==>_ImageSearch_SetDllPath

; #PUBLIC FUNCTIONS - CORE SEARCH# ============================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch
; Description ...: Searches for an image within a specified screen area
; Syntax ........: _ImageSearch($sImagePath, $iLeft=0, $iTop=0, $iRight=0, $iBottom=0[, $iScreen = -1[, $iTolerance = 10[, $iResults = 1[, $iCenterPOS = 1[, $fMinScale = 1.0[, $fMaxScale = 1.0[, $fScaleStep = 0.1[, $iReturnDebug = $g_bImageSearch_Debug]]]]]]]])
; Parameters ....: $sImagePath     - Image file path(s), multiple separated by "|"
;                  $iLeft          - [optional] Left boundary (0 = entire screen)
;                  $iTop           - [optional] Top boundary (0 = entire screen)
;                  $iRight         - [optional] Right boundary (0 = entire screen)
;                  $iBottom        - [optional] Bottom boundary (0 = entire screen)
;                  $iScreen        - [optional] Monitor index:
;                                    iScreen < 0: Virtual screen (all monitors combined)
;                                    iScreen = 0: Use provided region params only (primary screen if region=0)
;                                    iScreen > 0: Specific monitor (1=first, 2=second, 3=third...)
;                  $iTolerance     - [optional] Color tolerance 0-255 (default: 10)
;                  $iResults       - [optional] Max results 1-1024 (default: 1)
;                  $iCenterPOS     - [optional] Return center (1) or top-left (0) (default: 1)
;                  $fMinScale      - [optional] Min scale 0.1-5.0 (default: 1.0)
;                  $fMaxScale      - [optional] Max scale (default: 1.0)
;                  $fScaleStep     - [optional] Scale step (default: 0.1)
;                  $iReturnDebug   - [optional] Debug mode (default: 0)
;                  $iUseCache      - [optional] Enable cache (0=off, 1=on, default: 0)
; Return values .: Success - Array of found positions:
;                    [0] = Match count (0 if not found)
;                    [1][0] = X coordinate of first match
;                    [1][1] = Y coordinate of first match
;                    [1][2] = Width of matched image
;                    [1][3] = Height of matched image
;                    [n][0..3] = Additional matches if $iResults > 1
;                  Failure - Empty array, @error set to error code
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: - Set bounds to 0 to search entire screen
;                  - Supports multiple images: "img1.png|img2.png|img3.png"
;                  - Uses SIMD (AVX512/AVX2/SSE2) for fast searching
;                  - Cache system significantly speeds up repeated searches
; Example .......: ; Search for a button image on screen
;                  Local $aResult = _ImageSearch("button.png")
;                  If $aResult[0] > 0 Then
;                      ConsoleWrite("Found at: " & $aResult[1][0] & ", " & $aResult[1][1] & @CRLF)
;                      MouseClick("left", $aResult[1][0], $aResult[1][1])
;                  EndIf
;
;                  ; Search for multiple images with scaling
;                  Local $aResult = _ImageSearch("icon1.png|icon2.png", 0, 0, 800, 600, -1, 10, 5, 1, 0.8, 1.2, 0.1)
;                  If $aResult[0] > 0 Then
;                      For $i = 1 To $aResult[0]
;                          ConsoleWrite("Match " & $i & " at: " & $aResult[$i][0] & ", " & $aResult[$i][1] & @CRLF)
;                      Next
;                  EndIf
; ===============================================================================================================================
Func _ImageSearch($sImagePath, $iLeft = 0, $iTop = 0, $iRight = 0, $iBottom = 0, $iScreen = -1, $iTolerance = 10, $iResults = 1, $iCenterPOS = 1, $fMinScale = 1.0, $fMaxScale = 1.0, $fScaleStep = 0.1, $iReturnDebug = $g_bImageSearch_Debug, $iUseCache = $IMGS_ENABLED_CACHE)
	If Not $g_bImageSearch_Initialized Then _ImageSearch_Startup()
	If Not $g_bImageSearch_Initialized Then Return __ImgSearch_MakeEmptyResult()
	If $g_bImageSearch_Debug Then $iReturnDebug = $g_bImageSearch_Debug
	; Validate and normalize parameters
	$sImagePath = __ImgSearch_NormalizePaths($sImagePath)
	If $sImagePath = "" Then Return __ImgSearch_MakeEmptyResult()
	$iTolerance = __ImgSearch_Clamp($iTolerance, 0, 255)
	$iResults = __ImgSearch_Clamp($iResults, 1, $IMGS_RESULTS_MAX)
	$iCenterPOS = ($iCenterPOS = 0 ? 0 : 1)
	$fMinScale = __ImgSearch_Clamp($fMinScale, 0.1, 5.0)
	$fMaxScale = __ImgSearch_Clamp($fMaxScale, $fMinScale, 5.0)
	$fScaleStep = __ImgSearch_Clamp($fScaleStep, 0.01, 1.0)
	$iReturnDebug = ($iReturnDebug) ? 1 : 0
	$iUseCache = ($iUseCache) ? 1 : 0
	If $g_bImageSearch_Debug Then ConsoleWrite("+ _ImageSearch_Area($sImagePath=" & $sImagePath & ", $iLeft =" & $iLeft & ", $iTop=" & $iTop & ", $iRight=" & $iRight & ", $iBottom=" & $iBottom & ", $iScreen=" & $iScreen & ", $iTolerance=" & $iTolerance & ", $iResults=" & $iResults & ", $iCenterPOS=" & $iCenterPOS & ", $fMinScale=" & $fMinScale & ", $fMaxScale=" & $fMaxScale & ", $fScaleStep=" & $fScaleStep & ", $iReturnDebug=" & $iReturnDebug & ", $iUseCache = " & $iUseCache & ')' & @CRLF)

	; Call DLL - NEW SIMPLIFIED SIGNATURE
	Local $aDLL = DllCall($g_hImageSearchDLL, "wstr", "ImageSearch", _
			"wstr", $sImagePath, _
			"int", $iLeft, _
			"int", $iTop, _
			"int", $iRight, _
			"int", $iBottom, _
			"int", $iScreen, _
			"int", $iTolerance, _
			"int", $iResults, _
			"int", $iCenterPOS, _
			"float", $fMinScale, _
			"float", $fMaxScale, _
			"float", $fScaleStep, _
			"int", $iReturnDebug, _
			"int", $iUseCache)
	If @error Then
		If $g_bImageSearch_Debug Then ConsoleWrite("!> DllCall error: " & @error & @CRLF)
		Return SetError(1, @error, __ImgSearch_MakeEmptyResult())
	EndIf
	; Parse result
	Local $sResult = $aDLL[0]
	$g_sLastDllReturn = $sResult
	If $g_bImageSearch_Debug Then ConsoleWrite(">> DLL returned: " & $sResult & @CRLF)
	Local $aResult = __ImgSearch_ParseResult($sResult)
	; Check if parser set error (from DLL error code)
	If @error Then
		Return SetError(@error, 0, $aResult)
	EndIf
	Return $aResult
EndFunc   ;==>_ImageSearch

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_InImage
; Description ...: Searches for a target image within a source image (file-to-file search)
; Syntax ........: _ImageSearch_InImage($sSourceImage, $sTargetImage[, $iTolerance = 10[, $iResults = 1[, $iCenterPOS = 1[, $fMinScale = 1.0[, $fMaxScale = 1.0[, $fScaleStep = 0.1[, $iReturnDebug = $g_bImageSearch_Debug]]]]]]])
; Parameters ....: $sSourceImage   - Path to source (Source) image file
;                  $sTargetImage   - Path to target (Target) image file(s), multiple separated by "|"
;                  $iTolerance     - [optional] Color tolerance (default: 10)
;                  $iResults       - [optional] Max results (default: 1)
;                  $iCenterPOS     - [optional] Return center (1) or top-left (0) (default: 1)
;                  $fMinScale      - [optional] Min scale (default: 1.0)
;                  $fMaxScale      - [optional] Max scale (default: 1.0)
;                  $fScaleStep     - [optional] Scale step (default: 0.1)
;                  $iReturnDebug   - [optional] Debug mode (default: 0)
;                  $iUseCache      - [optional] User cache  (default: 0)
; Return values .: Same as _ImageSearch
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: Useful for pre-processing images or testing without screen capture
; Example .......: $aResult = _ImageSearch_InImage("screenshot.png", "button.png", 20)
; ===============================================================================================================================
Func _ImageSearch_InImage($sSourceImage, $sTargetImage, $iTolerance = 10, $iResults = 1, $iCenterPOS = 1, $fMinScale = 1.0, $fMaxScale = 1.0, $fScaleStep = 0.1, $iReturnDebug = $g_bImageSearch_Debug, $iUseCache = $IMGS_ENABLED_CACHE)
	If $g_IMGS_Debug Then ConsoleWrite("+ _ImageSearch_InImage($sSourceImage=" & $sSourceImage & ", $sTargetImage=" & $sTargetImage & ", $iTolerance=" & $iTolerance & ", $iResults=" & $iResults & ", $iCenterPOS=" & $iCenterPOS & ", $fMinScale=" & $fMinScale & ", $fMaxScale=" & $fMaxScale & ", $fScaleStep=" & $fScaleStep & ", $iReturnDebug=" & $iReturnDebug & ", $iUseCache: " & $iUseCache & ')' & @CRLF)
	If Not $g_bImageSearch_Initialized Then _ImageSearch_Startup()
	If Not $g_bImageSearch_Initialized Then Return __ImgSearch_MakeEmptyResult()
	If $g_bImageSearch_Debug Then $iReturnDebug = $g_bImageSearch_Debug
	; Validate
	If Not FileExists($sSourceImage) Then Return __ImgSearch_MakeEmptyResult()
	$sTargetImage = __ImgSearch_NormalizePaths($sTargetImage)
	If $sTargetImage = "" Then Return __ImgSearch_MakeEmptyResult()
	$iTolerance = __ImgSearch_Clamp($iTolerance, 0, 255)
	$iResults = __ImgSearch_Clamp($iResults, 1, $IMGS_RESULTS_MAX)
	$iCenterPOS = ($iCenterPOS = 0 ? 0 : 1)
	$fMinScale = __ImgSearch_Clamp($fMinScale, 0.1, 5.0)
	$fMaxScale = __ImgSearch_Clamp($fMaxScale, $fMinScale, 5.0)
	$fScaleStep = __ImgSearch_Clamp($fScaleStep, 0.01, 1.0)
	$iReturnDebug = ($iReturnDebug) ? 1 : 0
	$iUseCache = ($iUseCache) ? 1 : 0
	; Call DLL
	Local $aDLL = DllCall($g_hImageSearchDLL, "wstr", "Search_In_Image", _
			"wstr", $sSourceImage, _
			"wstr", $sTargetImage, _
			"int", $iTolerance, _
			"int", $iResults, _
			"int", $iCenterPOS, _
			"float", $fMinScale, _
			"float", $fMaxScale, _
			"float", $fScaleStep, _
			"int", $iReturnDebug, _
			"int", $iUseCache)
	If @error Then
		If $g_bImageSearch_Debug Then ConsoleWrite("!> DllCall error: " & @error & @CRLF)
		Return SetError(1, @error, __ImgSearch_MakeEmptyResult())
	EndIf
	Local $sResult = $aDLL[0]
	$g_sLastDllReturn = $sResult
	If $g_bImageSearch_Debug Then ConsoleWrite(">> DLL returned: " & $sResult & @CRLF)
	Local $aResult = __ImgSearch_ParseResult($sResult)
	If @error Then
		Return SetError(@error, 0, $aResult)
	EndIf
	Return $aResult
EndFunc   ;==>_ImageSearch_InImage

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_hBitmap
; Description ...: Searches for a target bitmap within a Source bitmap (memory-to-memory search)
; Syntax ........: _ImageSearch_hBitmap($hBitmapSource, $hBitmapTarget[, $iTolerance = 10[, $iLeft = 0[, $iTop = 0[, $iRight = 0[, $iBottom = 0[, $iResults = 1[, $iCenterPOS = 1[, $fMinScale = 1.0[, $fMaxScale = 1.0[, $fScaleStep = 0.1[, $iReturnDebug = $g_bImageSearch_Debug]]]]]]]]]]])
; Parameters ....: $hBitmapSource - Handle to Source bitmap (HBITMAP)
;                  $hBitmapTarget   - Handle to Target bitmap (HBITMAP)
;                  $iTolerance      - [optional] Color tolerance (default: 10)
;                  $iLeft/$iTop/$iRight/$iBottom - [optional] Search region in Source (0 = entire bitmap)
;                  $iResults        - [optional] Max results (default: 1)
;                  $iCenterPOS         - [optional] Return center (1) or top-left (0) (default: 1)
;                  $fMinScale       - [optional] Min scale (default: 1.0)
;                  $fMaxScale       - [optional] Max scale (default: 1.0)
;                  $fScaleStep      - [optional] Scale step (default: 0.1)
;                  $iReturnDebug    - [optional] Debug mode (default: 0)
;                  $iUseCache       - [optional] User cache  (default: 0)
; Return values .: Same as _ImageSearch
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: Fastest method for repeated searches (no disk I/O)
;                  Bitmaps must be created with GDI/GDI+ functions
; Example .......:
;   $hScreen = _ScreenCapture_Capture("", 0, 0, 800, 600)
;   $hIcon = _GDIPlus_BitmapCreateHBITMAPFromBitmap($pBitmap)
;   $aResult = _ImageSearch_hBitmap($hScreen, $hIcon, 10)
;   _WinAPI_DeleteObject($hScreen)
;   _WinAPI_DeleteObject($hIcon)
; ===============================================================================================================================
Func _ImageSearch_hBitmap($hBitmapSource, $hBitmapTarget, $iTolerance = 10, $iLeft = 0, $iTop = 0, $iRight = 0, $iBottom = 0, $iResults = 1, $iCenterPOS = 1, $fMinScale = 1.0, $fMaxScale = 1.0, $fScaleStep = 0.1, $iReturnDebug = $g_bImageSearch_Debug, $iUseCache = $IMGS_ENABLED_CACHE)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_hBitmap($hBitmapSource, $hBitmapTarget, $iTolerance = " & $iTolerance & ", $iLeft =" & $iLeft & ", $iTop=" & $iTop & ", $iRight=" & $iRight & ", $iBottom=" & $iBottom & ", $iResults=" & $iResults & ", $iCenterPOS=" & $iCenterPOS & ", $fMinScale=" & $fMinScale & ", $fMaxScale=" & $fMaxScale & ", $fScaleStep=" & $fScaleStep & ", $iReturnDebug=" & $iReturnDebug & ", $iUseCache=" & $iUseCache & ')' & @CRLF)
	If Not $g_bImageSearch_Initialized Then _ImageSearch_Startup()
	If Not $g_bImageSearch_Initialized Then Return __ImgSearch_MakeEmptyResult()
	If $g_bImageSearch_Debug Then $iReturnDebug = $g_bImageSearch_Debug
	; Validate
	$iTolerance = __ImgSearch_Clamp($iTolerance, 0, 255)
	$iResults = __ImgSearch_Clamp($iResults, 1, $IMGS_RESULTS_MAX)
	$iCenterPOS = ($iCenterPOS = 0 ? 0 : 1)
	$fMinScale = __ImgSearch_Clamp($fMinScale, 0.1, 5.0)
	$fMaxScale = __ImgSearch_Clamp($fMaxScale, $fMinScale, 5.0)
	$fScaleStep = __ImgSearch_Clamp($fScaleStep, 0.01, 1.0)
	$iReturnDebug = ($iReturnDebug) ? 1 : 0
	$iUseCache = ($iUseCache) ? 1 : 0 ; Call DLL
	Local $aDLL = DllCall($g_hImageSearchDLL, "wstr", "hBitmap_Search", _
			"handle", $hBitmapSource, _
			"handle", $hBitmapTarget, _
			"int", $iTolerance, _
			"int", $iLeft, _
			"int", $iTop, _
			"int", $iRight, _
			"int", $iBottom, _
			"int", $iResults, _
			"int", $iCenterPOS, _
			"float", $fMinScale, _
			"float", $fMaxScale, _
			"float", $fScaleStep, _
			"int", $iReturnDebug, _
			"int", $iUseCache)
	If @error Then
		If $g_bImageSearch_Debug Then ConsoleWrite("!> DllCall error: " & @error & @CRLF)
		Return SetError(1, @error, __ImgSearch_MakeEmptyResult())
	EndIf
	Local $sResult = $aDLL[0]
	$g_sLastDllReturn = $sResult
	If $g_bImageSearch_Debug Then ConsoleWrite(">> DLL returned: " & $sResult & @CRLF)
	Local $aResult = __ImgSearch_ParseResult($sResult)
	If @error Then
		Return SetError(@error, 0, $aResult)
	EndIf
	Return $aResult
EndFunc   ;==>_ImageSearch_hBitmap


; #PUBLIC FUNCTIONS - UTILITIES# ==============================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_hBitmapLoad
; Description ...: Load image file and convert to HBITMAP handle
; Syntax ........: _ImageSearch_hBitmapLoad($sImageFile[, $iAlpha = 0[, $iRed = 0[, $iGreen = 0[, $iBlue = 0]]]])
; Parameters ....: $sImageFile - Path to image file
;                  $iAlpha     - Alpha channel (0-255, default=0 transparent)
;                  $iRed       - Red component (0-255, default=0)
;                  $iGreen     - Green component (0-255, default=0)
;                  $iBlue      - Blue component (0-255, default=0)
; Return values .: Success - HBITMAP handle (must DeleteObject when done)
;                  Failure - 0 and sets @error:
;                  |1 - DLL not initialized
;                  |2 - DLL call failed
;                  |3 - Invalid file path
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: Remember to DeleteObject() the returned HBITMAP when finished
; Example .......: $hBitmap = _ImageSearch_hBitmapLoad("image.png", 255, 255, 255, 255) ; White background
;                  ; ... use $hBitmap ...
;                  _WinAPI_DeleteObject($hBitmap) ;#include <WinAPIHObj.au3>
; ===============================================================================================================================
Func _ImageSearch_hBitmapLoad($sImageFile, $iAlpha = 0, $iRed = 0, $iGreen = 0, $iBlue = 0)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_hBitmapLoad($sImageFile=" & $sImageFile & ", $iAlpha=" & $iAlpha & ", $iRed=" & $iRed & ", $iGreen=" & $iGreen & ", $iBlue=" & $iBlue & ")" & @CRLF)
	If Not $g_bImageSearch_Initialized Then
		If Not _ImageSearch_Startup() Then Return SetError(1, 0, 0)
	EndIf
	If Not FileExists($sImageFile) Then Return SetError(3, 0, 0)
	Local $aResult = DllCall($g_hImageSearchDLL, "handle", "hBitmap_Load", _
			"wstr", $sImageFile, _
			"int", $iAlpha, _
			"int", $iRed, _
			"int", $iGreen, _
			"int", $iBlue)
	If @error Or Not IsArray($aResult) Or $aResult[0] = 0 Then
		Return SetError(2, @error, 0)
	EndIf
	Return $aResult[0]
EndFunc   ;==>_ImageSearch_hBitmapLoad

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_CaptureScreen
; Description ...: Capture screen region and return as HBITMAP handle
; Syntax ........: _ImageSearch_CaptureScreen([$iLeft = 0[, $iTop = 0[, $iRight = 0[, $iBottom = 0[, $iScreen = -1]]]]])
; Parameters ....: $iLeft   - Left coordinate (default=0)
;                  $iTop    - Top coordinate (default=0)
;                  $iRight  - Right coordinate (default=0, full width)
;                  $iBottom - Bottom coordinate (default=0, full height)
;                  $iScreen - Monitor index:
;                             iScreen < 0: Virtual screen (all monitors combined)
;                             iScreen = 0: User absolute coordinates (primary screen or multi-monitor)
;                                          Supports negative coords for secondary monitors (e.g., -1920, 0)
;                                          Use (0,0,0,0) for full primary screen
;                             iScreen > 0: Specific monitor (1=first, 2=second, 3=third...)
;                                          Coords relative to monitor origin, (0,0,0,0) = full monitor
; Return values .: Success - HBITMAP handle (must DeleteObject when done)
;                  Failure - 0 and sets @error:
;                  |1 - DLL not initialized
;                  |2 - DLL call failed
;                  |3 - Invalid screen region
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: Remember to DeleteObject() the returned HBITMAP when finished
; Example .......: $hBitmap = _ImageSearch_CaptureScreen(0, 0, 800, 600)
;                  ; ... use $hBitmap ...
;                  _WinAPI_DeleteObject($hBitmap) ; #include <WinAPIHObj.au3>
; ===============================================================================================================================
Func _ImageSearch_CaptureScreen($iLeft = 0, $iTop = 0, $iRight = 0, $iBottom = 0, $iScreen = -1)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_CaptureScreen($iLeft=" & $iLeft & ", $iTop=" & $iTop & ", $iRight=" & $iRight & ", $iBottom=" & $iBottom & ", $iScreen=" & $iScreen & ")" & @CRLF)
	If Not $g_bImageSearch_Initialized Then
		If Not _ImageSearch_Startup() Then Return SetError(1, 0, 0)
	EndIf
	Local $aResult = DllCall($g_hImageSearchDLL, "handle", "Capture_Screen", _
			"int", $iLeft, _
			"int", $iTop, _
			"int", $iRight, _
			"int", $iBottom, _
			"int", $iScreen)
	If @error Or Not IsArray($aResult) Or $aResult[0] = 0 Then
		Return SetError(2, @error, 0)
	EndIf
	Return $aResult[0]
EndFunc   ;==>_ImageSearch_CaptureScreen

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_ScreenCapture_SaveImage
; Description ...: Captures a screen region and saves it directly to an image file in one call.
;                  Automatically detects format from file extension (BMP, PNG, JPG).
;                  Combines capture + save for maximum performance (2x faster than AutoIt GDI+).
; Syntax ........: _ImageSearch_ScreenCapture_SaveImage($sImageFile[, $iLeft = 0[, $iTop = 0[, $iRight = 0[, $iBottom = 0[, $iScreen = 0]]]]])
; Parameters ....: $sImageFile - Output file path (extension determines format: .bmp, .png, .jpg/.jpeg)
;                                Default to BMP if extension not recognized
;                  $iLeft      - [optional] Left coordinate (default: 0)
;                  $iTop       - [optional] Top coordinate (default: 0)
;                  $iRight     - [optional] Right coordinate (default: 0, full width)
;                  $iBottom    - [optional] Bottom coordinate (default: 0, full height)
;                  $iScreen    - [optional] Monitor index (default: 0):
;                                iScreen < 0: Virtual screen (all monitors combined)
;                                iScreen = 0: User absolute coordinates (primary screen or multi-monitor)
;                                             Supports negative coords for secondary monitors (e.g., -1920, 0)
;                                             Use (0,0,0,0) for full primary screen
;                                iScreen > 0: Specific monitor (1=first, 2=second, 3=third...)
;                                             Coords relative to monitor origin, (0,0,0,0) = full monitor
; Return values .: Success - True (1)
;                  Failure - False (0) and sets @error:
;                  |1 - DLL not initialized
;                  |2 - DLL call failed (capture or save failed)
;                  |3 - Invalid file path
; Remarks .......: * No need to manage HBITMAP - DLL handles all memory management internally
;                  * JPEG quality is fixed at 100% (highest quality)
;                  * Uses DPI-aware capture (accurate on all DPI scales)
;                  * ~2x faster than _ImageSearch_CaptureScreen + _ImageSearch_HBitmapSaveToFile
;                  * Supported formats: BMP (uncompressed), PNG (lossless), JPEG (quality 100%)
;                  * Thread-safe with proper GDI+ initialization
; Author ........: Dao Van Trong - TRONG.PRO
; Example .......: ; Capture full primary screen to PNG
;                  _ImageSearch_ScreenCapture_SaveImage(@ScriptDir & "\screenshot.png")
;
;                  ; Capture region (100, 100, 600, 400) on monitor 2 to JPEG
;                  _ImageSearch_ScreenCapture_SaveImage(@ScriptDir & "\region.jpg", 100, 100, 600, 400, 2)
;
;                  ; Capture entire virtual desktop to BMP
;                  _ImageSearch_ScreenCapture_SaveImage(@ScriptDir & "\desktop.bmp", 0, 0, 0, 0, -1)
; ===============================================================================================================================
Func _ImageSearch_ScreenCapture_SaveImage($sImageFile, $iLeft = 0, $iTop = 0, $iRight = 0, $iBottom = 0, $iScreen = 0)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_ScreenCapture_SaveImage($sImageFile=" & $sImageFile & ", $iLeft=" & $iLeft & ", $iTop=" & $iTop & ", $iRight=" & $iRight & ", $iBottom=" & $iBottom & ", $iScreen=" & $iScreen & ")" & @CRLF)

	; Validate input
	If Not $sImageFile Or $sImageFile = "" Then Return SetError(3, 0, False)

	; Initialize DLL if needed
	If Not $g_bImageSearch_Initialized Then
		If Not _ImageSearch_Startup() Then Return SetError(1, 0, False)
	EndIf

	; Call DLL function (capture + save in one optimized call)
	Local $aResult = DllCall($g_hImageSearchDLL, "int", "Capture_Screen_Save", _
			"wstr", $sImageFile, _
			"int", $iLeft, _
			"int", $iTop, _
			"int", $iRight, _
			"int", $iBottom, _
			"int", $iScreen)

	If @error Or Not IsArray($aResult) Then
		If $g_IMGS_Debug Then ConsoleWrite("!> DLL call failed, @error=" & @error & @CRLF)
		Return SetError(2, @error, False)
	EndIf

	; Check result (1 = success, 0 = failure)
	If $aResult[0] = 1 Then
		If $g_IMGS_Debug Then ConsoleWrite(">> Successfully saved screenshot to: " & $sImageFile & @CRLF)
		Return SetError(0, 0, True)
	Else
		If $g_IMGS_Debug Then ConsoleWrite("!> Failed to save screenshot" & @CRLF)
		Return SetError(2, 0, False)
	EndIf
EndFunc   ;==>_ImageSearch_ScreenCapture_SaveImage


; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Wait
; Description ...: Waits for an image to appear on screen with timeout and optional max attempts limit
; Syntax ........: _ImageSearch_Wait($iTimeout, $sImagePath[, $iSleepTime = 100[, $iScreen = -1[, $iTolerance = 10[, $iResults = 1[, $iCenterPOS = 1[, $fMinScale = 1.0[, $fMaxScale = 1.0[, $fScaleStep = 0.1[, $iReturnDebug = $g_bImageSearch_Debug[, $iUseCache = $IMGS_ENABLED_CACHE[, $iMaxAttempts = 0]]]]]]]]]]]
; Parameters ....: $iTimeout       - Timeout in milliseconds (0 = wait forever)
;                  $sImagePath     - Image file path(s), multiple separated by "|"
;                  $iSleepTime     - [optional] Sleep between checks in ms (default: 100)
;                  $iScreen        - [optional] Monitor index:
;                                    iScreen < 0: Virtual screen (all monitors combined)
;                                    iScreen = 0: Use provided region params only (primary screen if region=0)
;                                    iScreen > 0: Specific monitor (1=first, 2=second, 3=third...)
;                  $iTolerance     - [optional] Color tolerance 0-255 (default: 10)
;                  $iResults       - [optional] Max results 1-1024 (default: 1)
;                  $iCenterPOS     - [optional] Return center (1) or top-left (0) (default: 1)
;                  $fMinScale      - [optional] Min scale 0.1-5.0 (default: 1.0)
;                  $fMaxScale      - [optional] Max scale (default: 1.0)
;                  $fScaleStep     - [optional] Scale step (default: 0.1)
;                  $iReturnDebug   - [optional] Debug mode (default: 0)
;                  $iUseCache      - [optional] User cache  (default: 0)
;                  $iMaxAttempts   - [optional] Max number of search attempts (0 = unlimited, default: 0)
; Return values .: Success - 2D Array (same as _ImageSearch)
;                  Timeout - Empty array with [0][0] = 0
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: $iMaxAttempts provides additional control to limit search attempts
;                  Useful for preventing excessive CPU usage in tight loops
; Example .......:   ; Wait 5 seconds for button (unlimited attempts)
;                  $aResult = _ImageSearch_Wait(5000, "button.png")
;                  If $aResult[0][0] > 0 Then
;                      MouseClick("left", $aResult[1][0], $aResult[1][1])
;                  Else
;                      MsgBox(0, "Timeout", "Button not found")
;                  EndIf
;
;                  ; Wait with max 50 attempts (exits early if 50 attempts reached)
;                  $aResult = _ImageSearch_Wait(10000, "button.png", 100, -1, 10, 1, 1, 1.0, 1.0, 0.1, 0, 1, 50)
; ===============================================================================================================================
Func _ImageSearch_Wait($iTimeout, $sImagePath, $iLeft = 0, $iTop = 0, $iRight = 0, $iBottom = 0, $iScreen = -1, $iTolerance = 10, $iResults = 1, $iCenterPOS = 1, $fMinScale = 1.0, $fMaxScale = 1.0, $fScaleStep = 0.1, $iReturnDebug = $g_bImageSearch_Debug, $iUseCache = $IMGS_ENABLED_CACHE, $iMaxAttempts = 0)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Wait($iTimeout=" & $iTimeout & ", $sImagePath=" & $sImagePath & ", $iLeft=" & $iLeft & ", $iTop=" & $iTop & ", $iRight=" & $iRight & ", $iBottom=" & $iBottom & ", $iScreen=" & $iScreen & ", $iTolerance=" & $iTolerance & ", $iResults=" & $iResults & ", $iCenterPOS=" & $iCenterPOS & ", $fMinScale=" & $fMinScale & ", $fMaxScale=" & $fMaxScale & ", $fScaleStep=" & $fScaleStep & ", $iReturnDebug=" & $iReturnDebug & ", $iUseCache=" & $iUseCache & ", $iMaxAttempts=" & $iMaxAttempts & ")" & @CRLF)
	Local $hTimer = TimerInit()
	Local $iAttempts = 0

	While True
		$iAttempts += 1
		Local $aResult = _ImageSearch($sImagePath, $iLeft, $iTop, $iRight, $iBottom, $iScreen, $iTolerance, $iResults, $iCenterPOS, $fMinScale, $fMaxScale, $fScaleStep, $iReturnDebug, $iUseCache)
		If $aResult[0][0] > 0 Then Return $aResult

		; OPTIMIZED: Check max attempts limit to prevent excessive DLL calls
		If $iMaxAttempts > 0 And $iAttempts >= $iMaxAttempts Then
			If $g_IMGS_Debug Then ConsoleWrite(">> Max attempts (" & $iMaxAttempts & ") reached" & @CRLF)
			Return __ImgSearch_MakeEmptyResult()
		EndIf

		If $iTimeout > 0 And TimerDiff($hTimer) > $iTimeout Then
			If $g_IMGS_Debug Then ConsoleWrite(">> Timeout (" & $iTimeout & "ms) after " & $iAttempts & " attempts" & @CRLF)
			Return __ImgSearch_MakeEmptyResult()
		EndIf

		Sleep($iSleepTime)
	WEnd
EndFunc   ;==>_ImageSearch_Wait

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_WaitClick
; Description ...: Waits for an image and clicks it when found
; Syntax ........: _ImageSearch_WaitClick($iTimeout, $sImagePath[, $sButton = "left"[, $iClicks = 1[, $iScreen = -1[, $iTolerance = 10[, $iResults = 1[, $iCenterPOS = 1[, $fMinScale = 1.0[, $fMaxScale = 1.0[, $fScaleStep = 0.1[, $iReturnDebug = $g_bImageSearch_Debug[, $iUseCache = $IMGS_ENABLED_CACHE]]]]]]]]])
; Parameters ....: $iTimeout       - Timeout in milliseconds (0 = wait forever)
;                  $sImagePath     - Image file path(s)
;                  $sButton        - [optional] Mouse button: "left", "right", "middle" (default: "left")
;                  $iClicks        - [optional] Number of clicks (default: 1)
;                  $iScreen        - [optional] Monitor index:
;                                    iScreen < 0: Virtual screen (all monitors combined)
;                                    iScreen = 0: Use provided region params only (primary screen if region=0)
;                                    iScreen > 0: Specific monitor (1=first, 2=second, 3=third...)
;                  $iTolerance     - [optional] Color tolerance 0-255 (default: 10)
;                  $iResults       - [optional] Max results 1-1024 (default: 1)
;                  $iCenterPOS     - [optional] Return center (1) or top-left (0) (default: 1)
;                  $fMinScale      - [optional] Min scale 0.1-5.0 (default: 1.0)
;                  $fMaxScale      - [optional] Max scale (default: 1.0)
;                  $fScaleStep     - [optional] Scale step (default: 0.1)
;                  $iReturnDebug   - [optional] Debug mode (default: 0)
;                  $iUseCache      - [optional] User cache  (default: 0)
; Return values .: Success - 1 (image found and clicked)
;                  Timeout - 0 (image not found)
; Author.........: Dao Van Trong - TRONG.PRO
; Example .......:
;   ; Wait and click button
;   If _ImageSearch_WaitClick(5000, "button.png") Then
;       MsgBox(0, "Success", "Button clicked!")
;   Else
;       MsgBox(0, "Failed", "Button not found")
;   EndIf
; ===============================================================================================================================
Func _ImageSearch_WaitClick($iTimeout, $sImagePath, $sButton = "left", $iClicks = 1, $iLeft = 0, $iTop = 0, $iRight = 0, $iBottom = 0, $iScreen = -1, $iTolerance = 10, $iResults = 1, $iCenterPOS = 1, $fMinScale = 1.0, $fMaxScale = 1.0, $fScaleStep = 0.1, $iReturnDebug = $g_bImageSearch_Debug, $iUseCache = $IMGS_ENABLED_CACHE)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_WaitClick($iTimeout=" & $iTimeout & ", $sImagePath=" & $sImagePath & ", $sButton=" & $sButton & ", $iClicks=" & $iClicks & ", $iLeft=" & $iLeft & ", $iTop=" & $iTop & ", $iRight=" & $iRight & ", $iBottom=" & $iBottom & ", $iScreen=" & $iScreen & ", $iTolerance=" & $iTolerance & ", $iResults=" & $iResults & ", $iCenterPOS=" & $iCenterPOS & ", $fMinScale=" & $fMinScale & ", $fMaxScale=" & $fMaxScale & ", $fScaleStep=" & $fScaleStep & ", $iReturnDebug=" & $iReturnDebug & ", $iUseCache=" & $iUseCache & ")" & @CRLF)
	Local $aResult = _ImageSearch_Wait($iTimeout, $sImagePath, $iLeft, $iTop, $iRight, $iBottom, $iScreen, $iTolerance, $iResults, $iCenterPOS, $fMinScale, $fMaxScale, $fScaleStep, $iReturnDebug, $iUseCache)
	If $aResult[0][0] > 0 Then
		; Use DLL MouseClick with proper $iScreen parameter (supports negative coords)
		Return _ImageSearch_MouseClick($sButton, $aResult[1][0], $aResult[1][1], $iClicks, 10, $iScreen)
	EndIf
	Return 0
EndFunc   ;==>_ImageSearch_WaitClick

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_MouseClick
; Description ...: Clicks mouse at coordinates (screen or current position)
; Syntax ........: _ImageSearch_MouseClick($sButton[, $iX=-1[, $iY=-1[, $iClicks=1[, $iSpeed=0[, $iScreen=-1]]]]])
; Parameters ....: $sButton - Button: "left", "right", "middle" (default: "left")
;                  $iX, $iY - Coordinates (-1 = current position)
;                  $iClicks - Number of clicks (default: 1)
;                  $iSpeed - Speed 0-100 (0=instant, default: 0)
;                  $iScreen - Monitor index (default: -1 = all monitors/virtual screen)
; Return values .: 1 on success, 0 on failure
; ===============================================================================================================================
Func _ImageSearch_MouseClick($sButton = "left", $iX = -1, $iY = -1, $iClicks = 1, $iSpeed = 0, $iScreen = -1)
	If $g_bImageSearch_Debug Then ConsoleWrite("+  _ImageSearch_MouseClick($sButton=" & $sButton & ", $iX=" & $iX & ", $iY=" & $iY & ", $iClicks=" & $iClicks & ", $iSpeed=" & $iSpeed & ", $iScreen=" & $iScreen & ")" & @CRLF)

	; Initialize DLL if needed
	If Not $g_bImageSearch_Initialized Then
		If Not _ImageSearch_Startup() Then Return SetError(1, 0, 0)
	EndIf

	; Call DLL (handles move + click with proper timing, DPI-aware, SendInput)
	Local $aDLL = DllCall($g_hImageSearchDLL, "int", "Mouse_Click", _
			"wstr", $sButton, _
			"int", $iX, _
			"int", $iY, _
			"int", $iClicks, _
			"int", $iSpeed, _
			"int", $iScreen)

	If @error Or Not IsArray($aDLL) Then
		If $g_bImageSearch_Debug Then ConsoleWrite("!> DLL call failed, @error=" & @error & @CRLF)
		Return SetError(2, @error, 0)
	EndIf

	If $aDLL[0] = 1 Then
		If $g_bImageSearch_Debug Then ConsoleWrite(">> Click performed at X=" & $iX & ", Y=" & $iY & " (via DLL)" & @CRLF)
		Return 1
	Else
		If $g_bImageSearch_Debug Then ConsoleWrite("!> DLL Mouse_Click returned 0" & @CRLF)
		Return SetError(3, 0, 0)
	EndIf
EndFunc   ;==>_ImageSearch_MouseClick

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_MouseMove
; Description ...: Moves mouse cursor to coordinates (supports negative coordinates on multi-monitor)
; Syntax ........: _ImageSearch_MouseMove($iX, $iY[, $iSpeed=0[, $iScreen=-1]])
; Parameters ....: $iX, $iY - Target coordinates (-1 = keep current position)
;                  $iSpeed - Speed 0-100 (0=instant, default: 0)
;                  $iScreen - Monitor index:
;                             iScreen < 0: Virtual screen (coords are absolute virtual desktop coords)
;                             iScreen = 0: Absolute screen coordinates (supports negative for multi-monitor)
;                             iScreen > 0: Coordinates relative to specific monitor origin
; Return values .: 1 on success, 0 on failure
; Remarks .......: When iScreen > 0, coordinates are converted to absolute virtual desktop coords
; ===============================================================================================================================
Func _ImageSearch_MouseMove($iX, $iY, $iSpeed = 0, $iScreen = -1)
	If $g_bImageSearch_Debug Then ConsoleWrite("+  _ImageSearch_MouseMove($iX=" & $iX & ", $iY=" & $iY & ", $iSpeed=" & $iSpeed & ", $iScreen=" & $iScreen & ")" & @CRLF)

	; Initialize DLL if needed
	If Not $g_bImageSearch_Initialized Then
		If Not _ImageSearch_Startup() Then Return SetError(1, 0, 0)
	EndIf

	; Call DLL (handles all cases: multi-monitor, DPI-aware, smooth movement)
	Local $aDLL = DllCall($g_hImageSearchDLL, "int", "Mouse_Move", _
			"int", $iX, _
			"int", $iY, _
			"int", $iSpeed, _
			"int", $iScreen)

	If @error Or Not IsArray($aDLL) Then
		If $g_bImageSearch_Debug Then ConsoleWrite("!> DLL call failed, @error=" & @error & @CRLF)
		Return SetError(2, @error, 0)
	EndIf

	If $aDLL[0] = 1 Then
		If $g_bImageSearch_Debug Then ConsoleWrite(">> Mouse moved to X=" & $iX & ", Y=" & $iY & " (via DLL)" & @CRLF)
		Return 1
	Else
		If $g_bImageSearch_Debug Then ConsoleWrite("!> DLL Mouse_Move returned 0" & @CRLF)
		Return SetError(3, 0, 0)
	EndIf
EndFunc   ;==>_ImageSearch_MouseMove

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_MouseClickWin
; Description ...: Clicks mouse in a window
; Syntax ........: _ImageSearch_MouseClickWin($sTitle, $sText, $iX, $iY[, $sButton="left"[, $iClicks=1[, $iSpeed=0]]])
; Parameters ....: $sTitle - Window title/class/handle
;                  $sText - Window text
;                  $iX, $iY - Relative coordinates in window
;                  $sButton - Button (default: "left")
;                  $iClicks - Number of clicks (default: 1)
;                  $iSpeed - Speed 0-100 (default: 0)
; Return values .: 1 on success, 0 on failure
; ===============================================================================================================================
Func _ImageSearch_MouseClickWin($sTitle, $sText, $iX, $iY, $sButton = "left", $iClicks = 1, $iSpeed = 0)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_MouseClickWin($sTitle=" & $sTitle & ", $sText=" & $sText & ", $iX=" & $iX & ", $iY=" & $iY & ", $sButton=" & $sButton & ", $iClicks=" & $iClicks & ", $iSpeed=" & $iSpeed & ")" & @CRLF)
	If Not _ImageSearch_Startup() Then Return SetError(-1, 0, 0)
	Local $aRet = DllCall($g_hImageSearchDLL, "int:cdecl", "Mouse_ClickWin", "wstr", $sTitle, "wstr", $sText, "int", $iX, "int", $iY, "wstr", $sButton, "int", $iClicks, "int", $iSpeed)
	If @error Then Return SetError(1, 0, 0)
	Return $aRet[0]
EndFunc   ;==>_ImageSearch_MouseClickWin


; #PUBLIC FUNCTIONS - CACHE & INFO# ==========================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_WarmUpCache
; Description ...: Pre-loads images into cache for faster subsequent searches
; Syntax ........: _ImageSearch_WarmupCache($sImagePaths[, $bEnableCache = True])
; Parameters ....: $sImagePaths - Pipe-separated list of images to preload
;                  $bEnableCache - [optional] Enable persistent cache (default: True)
; Return values .: Success - Number of images cached
;                  Failure - 0
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: Call this during app initialization for better performance
;                  v3.5: Now uses $iUseCache=1 for persistent caching
; Example .......:
;   _ImageSearch_WarmUpCache("btn1.png|btn2.png|icon.png")
; ===============================================================================================================================
Func _ImageSearch_WarmUpCache($sImagePaths, $bEnableCache = True)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_WarmUpCache($sImagePaths=" & $sImagePaths & ", $bEnableCache=" & $bEnableCache & ")" & @CRLF)
	If Not $g_bImageSearch_Initialized Then _ImageSearch_Startup()
	Local $aFiles = StringSplit($sImagePaths, "|", 2)
	Local $iCached = 0
	Local $iUseCache = ($bEnableCache ? 1 : 0)
	For $sFile In $aFiles
		If FileExists($sFile) Then
			; FIXED: Use full screen (0,0,0,0) to properly load bitmap into cache
			; Previous bug: 1x1 region was too small and didn't load full bitmap
			; _ImageSearch($sImagePath, $iLeft, $iTop, $iRight, $iBottom, $iScreen, $iTolerance, $iResults, $iCenterPOS, $fMinScale, $fMaxScale, $fScaleStep, $iReturnDebug, $iUseCache)
			_ImageSearch($sFile, 0, 0, 0, 0, -1, 0, 1, 1, 1.0, 1.0, 0.1, 0, $iUseCache)
			$iCached += 1
		EndIf
	Next
	If $g_bImageSearch_Debug Then ConsoleWrite(">> Warmed up cache for " & $iCached & " images" & @CRLF)
	Return $iCached
EndFunc   ;==>_ImageSearch_WarmUpCache

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_ClearCache
; Description ...: Clears the internal bitmap and location cache
; Syntax ........: _ImageSearch_ClearCache()
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: Useful for freeing memory or forcing re-scan after image updates
;                  v3.5: Clears both in-memory cache and persistent disk cache
; Example .......: _ImageSearch_ClearCache()  ; Clear all cached data
; ===============================================================================================================================
Func _ImageSearch_ClearCache()
	If $g_bImageSearch_Debug Then ConsoleWrite("+  _ImageSearch_ClearCache()" & @CRLF)
	If Not $g_bImageSearch_Initialized Then Return
	DllCall($g_hImageSearchDLL, "none", "Clear_Cache")
	If $g_bImageSearch_Debug Then ConsoleWrite(">> Cache cleared (memory + disk)" & @CRLF)
EndFunc   ;==>_ImageSearch_ClearCache

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_GetDllInfo
; Description ...: Gets comprehensive DLL information in INI format
; Syntax ........: _ImageSearch_GetDllInfo()
; Return values .: Multi-line string in INI format with sections:
;                  [DLL]     - DLL name, version, architecture, author
;                  [OS]      - OS name, version, build, platform
;                  [CPU]     - Threads, SSE2, AVX2, AVX512 support
;                  [SCREEN]  - Virtual screen, scale, monitors with individual resolutions
;                  [CACHE]   - Location cache, bitmap cache, pool size
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: This is the recommended function for getting detailed system information.
; Example .......: ConsoleWrite(_ImageSearch_GetDllInfo() & @CRLF)
; ===============================================================================================================================
Func _ImageSearch_GetDllInfo($bForceRefresh = True)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_GetDllInfo($bForceRefresh=" & $bForceRefresh & ")" & @CRLF)
	If Not $g_bImageSearch_Initialized Then _ImageSearch_Startup()
	If Not $g_bImageSearch_Initialized Then Return ""
	; Return cached version if available
	If (Not $bForceRefresh) And ($g_sDllInfoCache <> "") Then Return $g_sDllInfoCache
	; Call DLL and cache result
	Local $aDLL = DllCall($g_hImageSearchDLL, "wstr", "Get_DllInfo")
	If @error Then Return ""
	$g_sDllInfoCache = $aDLL[0]
	; Parse and cache as Map for fast access
	$g_mDllInfoParsed = __ImgSearch_ParseIniToMap($g_sDllInfoCache)
	Return $g_sDllInfoCache
EndFunc   ;==>_ImageSearch_GetDllInfo

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_GetInfo()
; ===============================================================================================================================
Func _ImageSearch_GetInfo()
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_GetInfo()" & @CRLF)
	If Not $g_bImageSearch_Initialized Then _ImageSearch_Startup()
	If Not $g_bImageSearch_Initialized Then Return ""
	; Ensure cache is populated
	Local $sDllInfoRaw = _ImageSearch_GetDllInfo()
	;If $g_IMGS_Debug Then ConsoleWrite(">> DLL Info Raw (" & StringLen($sDllInfoRaw) & " chars):" & @CRLF & $sDllInfoRaw & @CRLF)
	If Not IsObj($g_mDllInfoParsed) Then
		If $g_IMGS_Debug Then ConsoleWrite("!> ERROR: Parsed map is not an object" & @CRLF)
		Return ""
	EndIf
	; Read from cached Map (FAST)
	Local $sName = __ImgSearch_IniRead($g_mDllInfoParsed, "DLL", "Name")
	Local $sVersion = __ImgSearch_IniRead($g_mDllInfoParsed, "DLL", "Version")
	Local $sArch = __ImgSearch_IniRead($g_mDllInfoParsed, "DLL", "Arch")
	Local $sOSName = __ImgSearch_IniRead($g_mDllInfoParsed, "OS", "Name")
	Local $sOSShort = StringReplace($sOSName, "Windows ", "Win")
	Local $sSSE2 = __ImgSearch_IniRead($g_mDllInfoParsed, "CPU", "SSE2")
	Local $sVirtualScreen = __ImgSearch_IniRead($g_mDllInfoParsed, "SCREEN", "VirtualScreen")
	Local $sPrimaryScale = __ImgSearch_IniRead($g_mDllInfoParsed, "SCREEN", "PrimaryScale")
	Local $sMonitors = __ImgSearch_IniRead($g_mDllInfoParsed, "SCREEN", "Monitors")
	Local $sLocationCache = __ImgSearch_IniRead($g_mDllInfoParsed, "CACHE", "LocationCache")
	Local $sBitmapCache = __ImgSearch_IniRead($g_mDllInfoParsed, "CACHE", "BitmapCache")
	Local $sPoolSize = __ImgSearch_IniRead($g_mDllInfoParsed, "CACHE", "PoolSize")
	; Build monitor list with scales (only if more than 1 monitor)
	; OPTIMIZED: Use array + _ArrayToString instead of loop concatenation
	Local $sMonitorInfo = ""
	Local $iMonitorCount = Int($sMonitors)
	If $iMonitorCount > 1 Then
		Local $aMonitorParts[$iMonitorCount]
		Local $iValidCount = 0
		For $i = 1 To $iMonitorCount
			Local $sMonRes = __ImgSearch_IniRead($g_mDllInfoParsed, "SCREEN", "Monitor_" & $i)
			Local $sMonScale = __ImgSearch_IniRead($g_mDllInfoParsed, "SCREEN", "Monitor_" & $i & "_Scale")
			If $sMonRes <> "" Then
				$aMonitorParts[$iValidCount] = "Monitor_" & $i & ":" & $sMonRes & " Scale_" & $i & ":" & $sMonScale
				$iValidCount += 1
			EndIf
		Next
		If $iValidCount > 0 Then
			ReDim $aMonitorParts[$iValidCount]
			$sMonitorInfo = _ArrayToString($aMonitorParts, ", ")
		EndIf
	EndIf
	; Build format with Scale info
	Local $sResult = ">> DLL Info: " & $sName & " v" & $sVersion & " [" & $sArch & "] " & $sOSShort & " | CPU: SSE2=" & $sSSE2 & @CRLF
	$sResult &= ">> Cache: LocationCache=" & $sLocationCache & " | BitmapCache=" & $sBitmapCache & " | PoolSize=" & $sPoolSize & @CRLF
	; Screen info: only show detailed monitor list if more than 1 monitor
	If $iMonitorCount > 1 Then
		$sResult &= ">> Screen: " & $sVirtualScreen & " PrimaryScale=" & $sPrimaryScale & " | Monitors: " & $sMonitors & " | " & $sMonitorInfo
	Else
		$sResult &= ">> Screen: " & $sVirtualScreen & " Scale=" & $sPrimaryScale & " | Monitors: " & $sMonitors
	EndIf
	Return $sResult
EndFunc   ;==>_ImageSearch_GetInfo

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_GetDllValue
; Description ...: Quick accessor to read any value from cached DLL Info
; Syntax ........: _ImageSearch_GetDllValue($sSection, $sKey)
; Parameters ....: $sSection - Section name (DLL, OS, CPU, SCREEN, CACHE)
;                  $sKey - Key name
; Return values .: Value string or "" if not found
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: Uses cached Map for maximum performance. Call _ImageSearch_GetDllInfo() first to populate cache.
; Example .......: $sVersion = _ImageSearch_GetDllValue("DLL", "Version")
;                  $sOSName = _ImageSearch_GetDllValue("OS", "Name")
;                  $iThreads = _ImageSearch_GetDllValue("CPU", "Threads")
; ===============================================================================================================================
Func _ImageSearch_GetDllValue($sSection, $sKey)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_GetDllValue($sSection=" & $sSection & ", $sKey=" & $sKey & ")" & @CRLF)
	; Ensure cache is populated
	If Not IsObj($g_mDllInfoParsed) Then
		_ImageSearch_GetDllInfo()
		If Not IsObj($g_mDllInfoParsed) Then Return ""
	EndIf
	Return __ImgSearch_IniRead($g_mDllInfoParsed, $sSection, $sKey)
EndFunc   ;==>_ImageSearch_GetDllValue

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_GetLastResult
; Description ...: Gets the raw DLL return string from the last search
; Syntax ........: _ImageSearch_GetLastResult()
; Return values .: Raw result string (e.g., "{2}[100|200|32|32,150|250|32|32]<debug info>")
; Remarks .......: Useful for debugging or custom parsing
; ===============================================================================================================================
Func _ImageSearch_GetLastResult()
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_GetLastResult()" & @CRLF)
	Return $g_sLastDllReturn
EndFunc   ;==>_ImageSearch_GetLastResult

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_GetScale
; Description ...: Gets the DPI scale factor for a specific monitor as a decimal number
; Syntax ........: _ImageSearch_GetScale($iScreen = 0)
; Parameters ....: $iScreen - Monitor index (0 = Primary, 1+ = specific monitor number)
; Return values .: Scale factor as number (e.g., 1.0, 1.25, 1.5) or 0 if not found
; Author ........: Dao Van Trong - TRONG.PRO
; Remarks .......: Uses cached DLL info for fast access. Returns PrimaryScale for $iScreen=0.
;                  Converts percentage to decimal: 100% = 1.0, 125% = 1.25, 150% = 1.5
; Example .......: $fScale = _ImageSearch_GetScale(0)  ; Get primary monitor scale (e.g., 1.25)
;                  $fScale = _ImageSearch_GetScale(2)  ; Get monitor 2 scale
; ===============================================================================================================================
Func _ImageSearch_GetScale($iScreen = 0)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_GetScale($iScreen=" & $iScreen & ")" & @CRLF)
	; Ensure cache is populated
	If Not IsObj($g_mDllInfoParsed) Then
		_ImageSearch_GetDllInfo()
		If Not IsObj($g_mDllInfoParsed) Then Return 0
	EndIf
	Local $sScaleStr = ""
	; Primary monitor (0 or negative)
	If $iScreen < 1 Then
		$sScaleStr = __ImgSearch_IniRead($g_mDllInfoParsed, "SCREEN", "PrimaryScale")
	Else
		; Specific monitor (1, 2, 3...)
		Local $sMonitorCount = __ImgSearch_IniRead($g_mDllInfoParsed, "SCREEN", "Monitors")
		Local $iMonitorCount = Int($sMonitorCount)
		If $iScreen > 0 And $iScreen <= $iMonitorCount Then
			$sScaleStr = __ImgSearch_IniRead($g_mDllInfoParsed, "SCREEN", "Monitor_" & $iScreen & "_Scale")
		EndIf
	EndIf
	; Convert "125%" to 1.25 or "125% (Primary)" to 1.25
	If $sScaleStr <> "" Then
		; Extract numeric part only (remove % and any text after it)
		Local $sNumeric = StringRegExpReplace($sScaleStr, "(\d+)%.*", "$1")
		Local $fScale = Number($sNumeric) / 100.0
		;If $g_IMGS_Debug Then ConsoleWrite("   Scale: " & $sScaleStr & " -> " & $fScale & @CRLF)
		Return $fScale
	EndIf
	; Not found
	Return SetError(1, 0, 0)
EndFunc   ;==>_ImageSearch_GetScale

; #PUBLIC FUNCTIONS - MONITOR INFO# ==========================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Monitor_GetList
; Description ...: Gets a list of all connected display monitors and their properties.
; Syntax ........: _ImageSearch_Monitor_GetList()
; Return values .: Success - The number of monitors found. @extended contains a detailed log.
;                  Failure - 0 and sets @error (1 = _WinAPI_EnumDisplayMonitors failed)
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: This function populates the global $g_aMonitorList.
;                  It is called automatically by _ImageSearch_Startup, but can be called manually to refresh the list.
; ===============================================================================================================================
Func _ImageSearch_Monitor_GetList()
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Monitor_GetList()" & @CRLF)
	; --- Virtual Desktop info ---
	Local $l_vLeft = DllCall("user32.dll", "int", "GetSystemMetrics", "int", 76)[0]   ; SM_XVIRTUALSCREEN
	Local $l_vTop = DllCall("user32.dll", "int", "GetSystemMetrics", "int", 77)[0]    ; SM_YVIRTUALSCREEN
	Local $l_vWidth = DllCall("user32.dll", "int", "GetSystemMetrics", "int", 78)[0]  ; SM_CXVIRTUALSCREEN
	Local $l_vHeight = DllCall("user32.dll", "int", "GetSystemMetrics", "int", 79)[0] ; SM_CYVIRTUALSCREEN
	Local $l_vRight = $l_vLeft + $l_vWidth
	Local $l_vBottom = $l_vTop + $l_vHeight
	Local $l_aMonitors = _WinAPI_EnumDisplayMonitors()
	If @error Then Return SetError(1, 0, 0)
	Local $l_iCount = $l_aMonitors[0][0]
	ReDim $g_aMonitorList[$l_iCount + 1][9]
	; --- Virtual Desktop entry ---
	$g_aMonitorList[0][0] = $l_iCount
	$g_aMonitorList[0][1] = $l_vLeft
	$g_aMonitorList[0][2] = $l_vTop
	$g_aMonitorList[0][3] = $l_vRight
	$g_aMonitorList[0][4] = $l_vBottom
	$g_aMonitorList[0][5] = $l_vWidth
	$g_aMonitorList[0][6] = $l_vHeight
	$g_aMonitorList[0][7] = 1
	$g_aMonitorList[0][8] = "Virtual"
	Local $l_sLog = StringFormat(">> Number of screens: [%d] - Virtual Desktop: Left=%d, Top=%d, Right=%d, Bottom=%d, Width=%d, Height=%d", $l_iCount, $l_vLeft, $l_vTop, $l_vRight, $l_vBottom, $l_vWidth, $l_vHeight) & @CRLF
	; --- Individual monitors ---
	For $l_i = 1 To $l_iCount
		Local $l_hMonitor = $l_aMonitors[$l_i][0]
		Local $l_tRect = $l_aMonitors[$l_i][1]
		Local $l_aInfo = _WinAPI_GetMonitorInfo($l_hMonitor)
		Local $l_mLeft = DllStructGetData($l_tRect, "Left")
		Local $l_mTop = DllStructGetData($l_tRect, "Top")
		Local $l_mRight = DllStructGetData($l_tRect, "Right")
		Local $l_mBottom = DllStructGetData($l_tRect, "Bottom")
		Local $l_mWidth = $l_mRight - $l_mLeft
		Local $l_mHeight = $l_mBottom - $l_mTop
		Local $l_bPrimary = ($l_aInfo[2] <> 0)
		Local $l_sDevice = $l_aInfo[3]
		$g_aMonitorList[$l_i][0] = $l_hMonitor
		$g_aMonitorList[$l_i][1] = $l_mLeft
		$g_aMonitorList[$l_i][2] = $l_mTop
		$g_aMonitorList[$l_i][3] = $l_mRight
		$g_aMonitorList[$l_i][4] = $l_mBottom
		$g_aMonitorList[$l_i][5] = $l_mWidth
		$g_aMonitorList[$l_i][6] = $l_mHeight
		$g_aMonitorList[$l_i][7] = $l_bPrimary
		$g_aMonitorList[$l_i][8] = $l_sDevice
		$l_sLog &= StringFormat(">> Monitor [%d]: Handle=%s, L=%d, T=%d, R=%d, B=%d, W=%d, H=%d, IsPrimary=%d, Device=%s", $l_i, Ptr($l_hMonitor), $l_mLeft, $l_mTop, $l_mRight, $l_mBottom, $l_mWidth, $l_mHeight, $l_bPrimary, $l_sDevice) & @CRLF
	Next
	Return SetError(0, $l_iCount, $l_sLog)
EndFunc   ;==>_ImageSearch_Monitor_GetList

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Monitor_ToVirtual
; Description ...: Converts local monitor coordinates to virtual screen coordinates.
; Syntax ........: _ImageSearch_Monitor_ToVirtual($iMonitor, $iX, $iY)
; Parameters ....: $iMonitor - The 1-based index of the monitor (from $g_aMonitorList).
;                  $iX       - The X coordinate relative to the monitor's top-left corner.
;                  $iY       - The Y coordinate relative to the monitor's top-left corner.
; Return values .: Success - A 2-element array [$vX, $vY] containing virtual screen coordinates.
;                  Failure - 0 and sets @error:
;                  |1 - Invalid monitor index
; Author.........: Dao Van Trong - TRONG.PRO
; ===============================================================================================================================
Func _ImageSearch_Monitor_ToVirtual($iMonitor, $iX, $iY)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Monitor_ToVirtual($iMonitor=" & $iMonitor & ", $iX=" & $iX & ", $iY=" & $iY & ")" & @CRLF)
	If $g_aMonitorList[0][0] = 0 Then _ImageSearch_Monitor_GetList()
	If $iMonitor < 1 Or $iMonitor > $g_aMonitorList[0][0] Then Return SetError(1, 0, 0)
	Local $l_Left = $g_aMonitorList[$iMonitor][1]
	Local $l_Top = $g_aMonitorList[$iMonitor][2]
	Local $aRet[2] = [$l_Left + $iX, $l_Top + $iY]
	Return $aRet
EndFunc   ;==>_ImageSearch_Monitor_ToVirtual

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Monitor_FromVirtual
; Description ...: Converts virtual screen coordinates to local monitor coordinates.
; Syntax ........: _ImageSearch_Monitor_FromVirtual($iMonitor, $iX, $iY)
; Parameters ....: $iMonitor - The 1-based index of the monitor (from $g_aMonitorList).
;                  $iX       - The virtual screen X coordinate.
;                  $iY       - The virtual screen Y coordinate.
; Return values .: Success - A 2-element array [$lX, $lY] containing local monitor coordinates.
;                  Failure - 0 and sets @error:
;                  |1 - Invalid monitor index
;                  |2 - Coordinates are not located on the specified monitor
; Author.........: Dao Van Trong - TRONG.PRO
; ===============================================================================================================================
Func _ImageSearch_Monitor_FromVirtual($iMonitor, $iX, $iY)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Monitor_FromVirtual($iMonitor=" & $iMonitor & ", $iX=" & $iX & ", $iY=" & $iY & ")" & @CRLF)
	If $g_aMonitorList[0][0] = 0 Then _ImageSearch_Monitor_GetList()
	If $iMonitor < 1 Or $iMonitor > $g_aMonitorList[0][0] Then Return SetError(1, 0, 0)
	Local $l_Left = $g_aMonitorList[$iMonitor][1]
	Local $l_Top = $g_aMonitorList[$iMonitor][2]
	Local $l_Right = $g_aMonitorList[$iMonitor][3]
	Local $l_Bottom = $g_aMonitorList[$iMonitor][4]
	; FIXED: Consistent bounds check [Left,Top) to [Right,Bottom) - excludes right/bottom edge
	If $iX < $l_Left Or $iX >= $l_Right Or $iY < $l_Top Or $iY >= $l_Bottom Then
		Return SetError(2, 0, 0)
	EndIf
	Local $aRet[2] = [$iX - $l_Left, $iY - $l_Top]
	Return $aRet
EndFunc   ;==>_ImageSearch_Monitor_FromVirtual

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Monitor_Current
; Description ...: Detects which monitor contains the current mouse cursor position.
; Syntax ........: _ImageSearch_Monitor_Current()
; Parameters ....: None (automatically uses current mouse cursor position)
; Return values .: Success - Monitor index (1-based) where the cursor is located
;                  Failure - 0 and sets @error:
;                  |1 - No monitors detected
;                  |2 - Cursor position is not on any detected monitor
; Remarks .......: * This function uses MouseGetPos() to automatically get the current cursor coordinates
;                  * The returned index corresponds to $g_aMonitorList array
;                  * If cursor is between monitors (in the gap), returns 0 with @error = 2
;                  * Call _ImageSearch_Monitor_GetList() first to populate monitor list
; Author.........: Dao Van Trong - TRONG.PRO
; ===============================================================================================================================
Func _ImageSearch_Monitor_Current()
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Monitor_Current() - Auto-detect using mouse cursor position" & @CRLF)

	; Auto-populate monitor list if not done yet
	If $g_aMonitorList[0][0] = 0 Then _ImageSearch_Monitor_GetList()
	If $g_aMonitorList[0][0] = 0 Then Return SetError(1, 0, 0) ; No monitors

	; Get current mouse cursor position (virtual screen coordinates)
	Local $aMousePos = MouseGetPos()
	If @error Then Return SetError(1, 0, 0)
	Local $iMouseX = $aMousePos[0]
	Local $iMouseY = $aMousePos[1]

	If $g_IMGS_Debug Then ConsoleWrite("   Mouse Position: X=" & $iMouseX & ", Y=" & $iMouseY & @CRLF)

	; Check which monitor contains the cursor
	For $i = 1 To $g_aMonitorList[0][0]
		Local $iLeft = $g_aMonitorList[$i][1]
		Local $iTop = $g_aMonitorList[$i][2]
		Local $iRight = $g_aMonitorList[$i][3]
		Local $iBottom = $g_aMonitorList[$i][4]

		; FIXED: Use < instead of <= for Right/Bottom to avoid overlap between monitors
		; Monitor bounds: [Left, Top) to [Right, Bottom) - excludes right/bottom edge
		If $iMouseX >= $iLeft And $iMouseX < $iRight And $iMouseY >= $iTop And $iMouseY < $iBottom Then
			If $g_IMGS_Debug Then ConsoleWrite("   Found on Monitor " & $i & ": " & $g_aMonitorList[$i][5] & "x" & $g_aMonitorList[$i][6] & @CRLF)
			Return $i
		EndIf
	Next

	; Cursor not on any monitor (between monitors)
	If $g_IMGS_Debug Then ConsoleWrite("!  Cursor not on any detected monitor (in gap)" & @CRLF)
	Return SetError(2, 0, 0)
EndFunc   ;==>_ImageSearch_Monitor_Current

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Monitor_GetAtPosition
; Description ...: Returns detailed information string about the monitor at specified position.
; Syntax ........: _ImageSearch_Monitor_GetAtPosition([$iX = -1[, $iY = -1]])
; Parameters ....: $iX - [optional] The X coordinate (virtual screen). Default = -1 (use mouse cursor position)
;                  $iY - [optional] The Y coordinate (virtual screen). Default = -1 (use mouse cursor position)
; Return values .: Success - String describing the monitor (e.g., "Monitor 2: 1920x1080 (Primary)")
;                  Failure - Error message string
; Remarks .......: * If $iX or $iY is -1, automatically uses current mouse cursor position (via MouseGetPos)
;                  * If both parameters omitted, uses mouse cursor position for both X and Y
;                  * Returns "Virtual Desktop" info if position is between monitors
;                  * This function is useful for tooltips and user feedback
;                  * Example outputs:
;                    - "Monitor 1: 1920x1080 (Primary)"
;                    - "Monitor 2: 2560x1440"
;                    - "Position: 2000, 500 (Virtual Desktop)" (if in gap)
;                    - "No monitors detected" (if monitor list empty)
; Author.........: Dao Van Trong - TRONG.PRO
; ===============================================================================================================================
Func _ImageSearch_Monitor_GetAtPosition($iX = -1, $iY = -1)
	; Auto-detect coordinates using mouse cursor if not provided
	If $iX = -1 Or $iY = -1 Then
		Local $aMousePos = MouseGetPos()
		If @error Then Return "Unable to get mouse position"
		$iX = $aMousePos[0]
		$iY = $aMousePos[1]
		If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Monitor_GetAtPosition() - Auto-detect using cursor: X=" & $iX & ", Y=" & $iY & @CRLF)
	Else
		If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Monitor_GetAtPosition($iX=" & $iX & ", $iY=" & $iY & ")" & @CRLF)
	EndIf
	; Auto-populate monitor list if not done yet
	If $g_aMonitorList[0][0] = 0 Then _ImageSearch_Monitor_GetList()
	If $g_aMonitorList[0][0] = 0 Then Return "No monitors detected"
	; Check which monitor contains this point
	For $i = 1 To $g_aMonitorList[0][0]
		Local $iLeft = $g_aMonitorList[$i][1]
		Local $iTop = $g_aMonitorList[$i][2]
		Local $iRight = $g_aMonitorList[$i][3]
		Local $iBottom = $g_aMonitorList[$i][4]
		; FIXED: Use < instead of <= for Right/Bottom to avoid overlap between monitors
		If $iX >= $iLeft And $iX < $iRight And $iY >= $iTop And $iY < $iBottom Then
			Local $sInfo = "Monitor " & $i & ": " & $g_aMonitorList[$i][5] & "x" & $g_aMonitorList[$i][6]
			If $g_aMonitorList[$i][7] Then $sInfo &= " (Primary)"
			If $g_IMGS_Debug Then ConsoleWrite("   " & $sInfo & @CRLF)
			Return $sInfo
		EndIf
	Next
	; Not on any monitor (between monitors in virtual desktop)
	Local $sVirtualInfo = "Position: " & $iX & ", " & $iY & " (Virtual Desktop)"
	If $g_IMGS_Debug Then ConsoleWrite("   " & $sVirtualInfo & @CRLF)
	Return $sVirtualInfo
EndFunc   ;==>_ImageSearch_Monitor_GetAtPosition

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Window_ToScreen
; Description ...: Converts window-relative coordinates to screen (virtual desktop) coordinates.
; Syntax ........: _ImageSearch_Window_ToScreen($hWnd, $iX, $iY[, $bClientArea = True])
; Parameters ....: $hWnd        - Window handle or title
;                  $iX          - X coordinate relative to window
;                  $iY          - Y coordinate relative to window
;                  $bClientArea - [optional] True = relative to client area, False = relative to window (default: True)
; Return values .: Success - A 2-element array [$screenX, $screenY] containing screen coordinates
;                  Failure - 0 and sets @error:
;                  |1 - Invalid window handle
;                  |2 - Unable to get window position
;                  |3 - Unable to get client area position (when $bClientArea = True)
; Remarks .......: * Screen coordinates are in virtual desktop space (can be negative on multi-monitor)
;                  * $bClientArea = True: Coordinates relative to window's client area (excludes title bar, borders)
;                  * $bClientArea = False: Coordinates relative to entire window (includes title bar, borders)
;                  * Useful for converting click positions in a window to screen positions for automation
;                  * Example: Window at (100, 100), click at (50, 30) in window → screen (150, 130)
; Author.........: Dao Van Trong - TRONG.PRO
; ===============================================================================================================================
Func _ImageSearch_Window_ToScreen($hWnd, $iX, $iY, $bClientArea = True)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Window_ToScreen($hWnd=" & $hWnd & ", $iX=" & $iX & ", $iY=" & $iY & ", $bClientArea=" & $bClientArea & ")" & @CRLF)

	; Validate window handle
	If Not IsHWnd($hWnd) Then
		$hWnd = WinGetHandle($hWnd)
		If @error Or Not IsHWnd($hWnd) Then
			If $g_IMGS_Debug Then ConsoleWrite("!> Error: Invalid window handle" & @CRLF)
			Return SetError(1, 0, 0)
		EndIf
	EndIf

	Local $iWinX, $iWinY

	If $bClientArea Then
		; Get client area position (excludes title bar and borders)
		Local $aClientPos = WinGetPos($hWnd)
		If @error Then
			If $g_IMGS_Debug Then ConsoleWrite("!> Error: Unable to get window position" & @CRLF)
			Return SetError(2, 0, 0)
		EndIf

		; Get client area offset using ControlGetPos
		Local $aCtrlPos = ControlGetPos($hWnd, "", "")
		If @error Then
			; Fallback: Use ClientToScreen API
			Local $tPoint = DllStructCreate("long X;long Y")
			DllStructSetData($tPoint, "X", 0)
			DllStructSetData($tPoint, "Y", 0)
			Local $aResult = DllCall("user32.dll", "bool", "ClientToScreen", "hwnd", $hWnd, "struct*", $tPoint)
			If @error Or Not $aResult[0] Then
				If $g_IMGS_Debug Then ConsoleWrite("!> Error: Unable to get client area position" & @CRLF)
				Return SetError(3, 0, 0)
			EndIf
			$iWinX = DllStructGetData($tPoint, "X")
			$iWinY = DllStructGetData($tPoint, "Y")
		Else
			; Use window position (client area starts at window top-left for most windows)
			$iWinX = $aClientPos[0]
			$iWinY = $aClientPos[1]

			; Adjust for title bar and borders
			Local $tPoint = DllStructCreate("long X;long Y")
			DllStructSetData($tPoint, "X", 0)
			DllStructSetData($tPoint, "Y", 0)
			Local $aResult = DllCall("user32.dll", "bool", "ClientToScreen", "hwnd", $hWnd, "struct*", $tPoint)
			If Not @error And $aResult[0] Then
				$iWinX = DllStructGetData($tPoint, "X")
				$iWinY = DllStructGetData($tPoint, "Y")
			EndIf
		EndIf
	Else
		; Get window position (includes title bar and borders)
		Local $aWinPos = WinGetPos($hWnd)
		If @error Then
			If $g_IMGS_Debug Then ConsoleWrite("!> Error: Unable to get window position" & @CRLF)
			Return SetError(2, 0, 0)
		EndIf
		$iWinX = $aWinPos[0]
		$iWinY = $aWinPos[1]
	EndIf

	; Calculate screen coordinates
	Local $iScreenX = $iWinX + $iX
	Local $iScreenY = $iWinY + $iY

	If $g_IMGS_Debug Then ConsoleWrite("   Window offset: (" & $iWinX & ", " & $iWinY & ") → Screen: (" & $iScreenX & ", " & $iScreenY & ")" & @CRLF)

	Local $aResult[2] = [$iScreenX, $iScreenY]
	Return $aResult
EndFunc   ;==>_ImageSearch_Window_ToScreen

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Window_FromScreen
; Description ...: Converts screen (virtual desktop) coordinates to window-relative coordinates.
; Syntax ........: _ImageSearch_Window_FromScreen($hWnd, $iScreenX, $iScreenY[, $bClientArea = True])
; Parameters ....: $hWnd        - Window handle or title
;                  $iScreenX    - X coordinate on screen (virtual desktop)
;                  $iScreenY    - Y coordinate on screen (virtual desktop)
;                  $bClientArea - [optional] True = relative to client area, False = relative to window (default: True)
; Return values .: Success - A 2-element array [$winX, $winY] containing window-relative coordinates
;                  Failure - 0 and sets @error:
;                  |1 - Invalid window handle
;                  |2 - Unable to get window position
;                  |3 - Unable to get client area position (when $bClientArea = True)
; Remarks .......: * Inverse of _ImageSearch_Window_ToScreen()
;                  * $bClientArea = True: Returns coordinates relative to window's client area
;                  * $bClientArea = False: Returns coordinates relative to entire window
;                  * Useful for determining where on a window a screen position maps to
;                  * Example: Screen (150, 130), window at (100, 100) → window (50, 30)
; Author.........: Dao Van Trong - TRONG.PRO
; ===============================================================================================================================
Func _ImageSearch_Window_FromScreen($hWnd, $iScreenX, $iScreenY, $bClientArea = True)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Window_FromScreen($hWnd=" & $hWnd & ", $iScreenX=" & $iScreenX & ", $iScreenY=" & $iScreenY & ", $bClientArea=" & $bClientArea & ")" & @CRLF)

	; Validate window handle
	If Not IsHWnd($hWnd) Then
		$hWnd = WinGetHandle($hWnd)
		If @error Or Not IsHWnd($hWnd) Then
			If $g_IMGS_Debug Then ConsoleWrite("!> Error: Invalid window handle" & @CRLF)
			Return SetError(1, 0, 0)
		EndIf
	EndIf

	Local $iWinX, $iWinY

	If $bClientArea Then
		; Get client area position using ClientToScreen
		Local $tPoint = DllStructCreate("long X;long Y")
		DllStructSetData($tPoint, "X", 0)
		DllStructSetData($tPoint, "Y", 0)
		Local $aResult = DllCall("user32.dll", "bool", "ClientToScreen", "hwnd", $hWnd, "struct*", $tPoint)
		If @error Or Not $aResult[0] Then
			If $g_IMGS_Debug Then ConsoleWrite("!> Error: Unable to get client area position" & @CRLF)
			Return SetError(3, 0, 0)
		EndIf
		$iWinX = DllStructGetData($tPoint, "X")
		$iWinY = DllStructGetData($tPoint, "Y")
	Else
		; Get window position
		Local $aWinPos = WinGetPos($hWnd)
		If @error Then
			If $g_IMGS_Debug Then ConsoleWrite("!> Error: Unable to get window position" & @CRLF)
			Return SetError(2, 0, 0)
		EndIf
		$iWinX = $aWinPos[0]
		$iWinY = $aWinPos[1]
	EndIf

	; Calculate window-relative coordinates
	Local $iWinRelX = $iScreenX - $iWinX
	Local $iWinRelY = $iScreenY - $iWinY

	If $g_IMGS_Debug Then ConsoleWrite("   Screen: (" & $iScreenX & ", " & $iScreenY & ") - Window offset: (" & $iWinX & ", " & $iWinY & ") → Relative: (" & $iWinRelX & ", " & $iWinRelY & ")" & @CRLF)

	Local $aResult[2] = [$iWinRelX, $iWinRelY]
	Return $aResult
EndFunc   ;==>_ImageSearch_Window_FromScreen

; #INTERNAL (PRIVATE) FUNCTIONS# ==============================================================================================
; ===============================================================================================================================

; Parse DLL result string
; Format: {count}[x|y|w|h,x|y|w|h,...](debug_info)          - Success
;         {error_code}[]<Error Name>(debug_info)            - Error
Func __ImgSearch_ParseResult($sResult)
	;If $g_IMGS_Debug Then ConsoleWrite("+  __ImgSearch_ParseResult($sResult=" & $sResult & ")" & @CRLF)
	; Extract count or error code between { }
	Local $sCountStr = __ImgSearch_ExtractBetween($sResult, "{", "}")
	Local $iCount = Number($sCountStr)
	; Check if error (negative count or has error message)
	Local $sErrorMsg = __ImgSearch_ExtractBetween($sResult, "<", ">")
	If $iCount < 0 Or $sErrorMsg <> "" Then
		; Error occurred
		If $g_bImageSearch_Debug Then
			ConsoleWrite("!> DLL Error [" & $iCount & "]: " & $sErrorMsg & @CRLF)
			; Extract debug info if exists
			Local $sDebugInfo = __ImgSearch_ExtractBetween($sResult, "(", ")")
			If $sDebugInfo <> "" Then ConsoleWrite("   Debug: " & $sDebugInfo & @CRLF)
		EndIf
		Return SetError($iCount, 0, __ImgSearch_MakeEmptyResult())
	EndIf
	; Extract matches between [ ]
	Local $sMatches = __ImgSearch_ExtractBetween($sResult, "[", "]")
	; Create result array: [row][col] where col 0=X, 1=Y, 2=W, 3=H
	Local $aResult[$iCount + 1][4]
	$aResult[0][0] = $iCount
	If $iCount = 0 Or $sMatches = "" Then Return $aResult

	; OPTIMIZED: Use single StringRegExp instead of double loop with StringSplit
	; Pattern matches: number|number|number|number (X|Y|W|H format)
	Local $aMatches = StringRegExp($sMatches, "(-?\d+)\|(-?\d+)\|(-?\d+)\|(-?\d+)", 3)

	If IsArray($aMatches) And UBound($aMatches) > 0 Then
		Local $iMatches = Int(UBound($aMatches) / 4)
		Local $iValid = ($iMatches < $iCount) ? $iMatches : $iCount

		For $i = 0 To $iValid - 1
			$aResult[$i + 1][0] = Number($aMatches[$i * 4])     ; X coordinate
			$aResult[$i + 1][1] = Number($aMatches[$i * 4 + 1]) ; Y coordinate
			$aResult[$i + 1][2] = Number($aMatches[$i * 4 + 2]) ; Width
			$aResult[$i + 1][3] = Number($aMatches[$i * 4 + 3]) ; Height
		Next

		$aResult[0][0] = $iValid
		ReDim $aResult[$iValid + 1][4]
	Else
		; Fallback to old method if regex fails
		Local $aRecords = StringSplit($sMatches, ",", 3)
		Local $iValid = 0
		For $i = 0 To UBound($aRecords) - 1
			Local $aParts = StringSplit($aRecords[$i], "|", 3)
			If UBound($aParts) >= 4 Then
				$iValid += 1
				$aResult[$iValid][0] = Number($aParts[0])
				$aResult[$iValid][1] = Number($aParts[1])
				$aResult[$iValid][2] = Number($aParts[2])
				$aResult[$iValid][3] = Number($aParts[3])
				If $iValid >= $iCount Then ExitLoop
			EndIf
		Next
		$aResult[0][0] = $iValid
		ReDim $aResult[$iValid + 1][4]
	EndIf
	; Debug output if enabled
	If $g_bImageSearch_Debug Then
		Local $sDebugInfo = __ImgSearch_ExtractBetween($sResult, "(", ")")
		If $sDebugInfo <> "" Then ConsoleWrite(">> Debug: " & $sDebugInfo & @CRLF)
	EndIf
	Return $aResult
EndFunc   ;==>__ImgSearch_ParseResult

; Extract string between delimiters
Func __ImgSearch_ExtractBetween($sString, $sStart, $sEnd)
	;If $g_IMGS_Debug Then ConsoleWrite("+  __ImgSearch_ExtractBetween($sString=" & $sString & ", $sStart=" & $sStart & ", $sEnd=" & $sEnd & ")" & @CRLF)
	If $sString = "" Or $sStart = "" Or $sEnd = "" Then Return ""
	Local $aRet = StringRegExp($sString, "(?si)\Q" & $sStart & "\E(.*?)" & "(?=\Q" & $sEnd & "\E)", 3)
	If @error Then
		Local $iStart = StringInStr($sString, $sStart)
		If $iStart = 0 Then Return ""
		Local $iEnd = StringInStr($sString, $sEnd, 0, 1, $iStart + StringLen($sStart))
		If $iEnd = 0 Or $iEnd <= $iStart Then Return ""
		Return StringMid($sString, $iStart + StringLen($sStart), $iEnd - $iStart - StringLen($sStart))
	EndIf
	If IsArray($aRet) And UBound($aRet) > 0 Then Return $aRet[0]
	Return ""
EndFunc   ;==>__ImgSearch_ExtractBetween

; Normalize file paths
Func __ImgSearch_NormalizePaths($sInput)
	;If $g_IMGS_Debug Then ConsoleWrite("+  __ImgSearch_NormalizePaths($sInput=" & $sInput & ")" & @CRLF)
	If $sInput = "" Then Return ""
	; Remove duplicate delimiters
	While StringInStr($sInput, "||")
		$sInput = StringReplace($sInput, "||", "|")
	WEnd
	; Trim delimiters
	$sInput = StringStripWS($sInput, 3)
	$sInput = StringRegExpReplace($sInput, "^\|+|\|+$", "")
	; Validate files exist
	If Not StringInStr($sInput, "|") Then
		Return (FileExists($sInput) ? $sInput : "")
	EndIf
	Local $aPaths = StringSplit($sInput, "|", 3)
	Local $sValid = ""
	For $i = 0 To UBound($aPaths) - 1
		If FileExists($aPaths[$i]) Then
			$sValid &= ($sValid = "" ? "" : "|") & $aPaths[$i]
		EndIf
	Next
	Return $sValid
EndFunc   ;==>__ImgSearch_NormalizePaths

; Clamp value between min and max
Func __ImgSearch_Clamp($vValue, $vMin, $vMax)
	;If $g_IMGS_Debug Then ConsoleWrite("+  __ImgSearch_Clamp($vValue=" & $vValue & ", $vMin=" & $vMin & ", $vMax=" & $vMax & ")" & @CRLF)
	If $vValue < $vMin Then Return $vMin
	If $vValue > $vMax Then Return $vMax
	Return $vValue
EndFunc   ;==>__ImgSearch_Clamp

; Create empty result array
Func __ImgSearch_MakeEmptyResult()
	If $g_IMGS_Debug Then ConsoleWrite("+  __ImgSearch_MakeEmptyResult()" & @CRLF)
	Local $aResult[1][4] = [[0, 0, 0, 0]]
	Return $aResult
EndFunc   ;==>__ImgSearch_MakeEmptyResult


; #FUNCTION# ====================================================================================================================
; Name............: __ImgSearch_GetFileArch
; Description....: Determine the architecture (x86, x64, ARM, etc.) of the executable file or library (EXE, DLL, SYS, OCX...).
; Syntax.........: __ImgSearch_GetFileArch($sFilePath [, $bAsText = True])
; Parameters.....: $sFilePath - File path to check
;                  $bAsText - True => Returns the description string (default)
;                             False => Returns the architecture code (e.g., 32, 64, 65,...)
; Return values..: Success: + When $bAsText = True → Returns the description string (e.g., "SCS_64BIT_BINARY", "ARM64", ...)
;                           + When $bAsText = False → Returns the code (eg: 64, 65, ...)
;                  Failed → SetError(code, ext, message)
; Author.........: Dao Van Trong - TRONG.PRO
; =========================================================================================================================
Func __ImgSearch_GetFileArch($sFilePath, $bAsText = True)
	If $g_IMGS_Debug Then ConsoleWrite("+  __ImgSearch_GetFileArch($sFilePath=" & $sFilePath & ", $bAsText=" & $bAsText & ")" & @CRLF)
	If Not FileExists($sFilePath) Then Return SetError(-1, 0, '')
	Local $tType = DllStructCreate("dword lpBinaryType")
	Local $aRetAPI = DllCall("kernel32.dll", "bool", "GetBinaryTypeW", "wstr", $sFilePath, "ptr", DllStructGetPtr($tType))
	If @error = 0 And $aRetAPI[0] Then
		Local $BinaryType = DllStructGetData($tType, "lpBinaryType")
		Switch $BinaryType
			Case 0
				Return SetError(0, 0, ($bAsText ? "x86" : 32)) ; (I386) SCS_32BIT_BINARY
			Case 6
				Return SetError(0, 6, ($bAsText ? "x64" : 64)) ; (AMD64)SCS_64BIT_BINARY
				;Case Else
				;   Return SetError(1, $BinaryType, "Unknown (API Code: " & $BinaryType & ")")
		EndSwitch
	EndIf
	Local $hFile = _WinAPI_CreateFile($sFilePath, 2, 2)
	If $hFile = 0 Then Return SetError(2, 0, "Error: Cannot open file")
	Local $tDosHeader = DllStructCreate("char Magic[2];byte[58];dword Lfanew")
	Local $aRead = _WinAPI_ReadFile($hFile, DllStructGetPtr($tDosHeader), 64, 0)
	If Not $aRead Or DllStructGetData($tDosHeader, "Lfanew") < 64 Then
		_WinAPI_CloseHandle($hFile)
		Return SetError(3, 0, "Error: Cannot read DOS header")
	EndIf
	If DllStructGetData($tDosHeader, "Magic") <> "MZ" Then
		_WinAPI_CloseHandle($hFile)
		Return SetError(4, 0, "Error: Not a valid PE file")
	EndIf
	_WinAPI_SetFilePointer($hFile, DllStructGetData($tDosHeader, "Lfanew"))
	Local $tNtHeaders = DllStructCreate("dword Signature;word Machine;word NumberOfSections;byte[18]")
	$aRead = _WinAPI_ReadFile($hFile, DllStructGetPtr($tNtHeaders), 24, 0)
	If Not $aRead Then
		_WinAPI_CloseHandle($hFile)
		Return SetError(5, 0, "Error: Cannot read NT headers")
	EndIf
	If DllStructGetData($tNtHeaders, "Signature") <> 0x4550 Then
		_WinAPI_CloseHandle($hFile)
		Return SetError(6, 0, "Error: Invalid PE signature")
	EndIf
	Local $Machine = DllStructGetData($tNtHeaders, "Machine")
	_WinAPI_CloseHandle($hFile)
	Switch $Machine
		Case 0x014C
			Return SetError(0, 32, ($bAsText ? "x86" : 32)) ; (I386) SCS_32BIT_BINARY
		Case 0x8664
			Return SetError(0, 64, ($bAsText ? "x64" : 64)) ; (AMD64) SCS_64BIT_BINARY
;~ 		Case 0xAA64
;~ 			Return SetError(0, 65, ($bAsText ? "ARM64" : 65))
		Case Else
;~ 			Return SetError(7, $Machine, "Unknown (Machine: 0x" & Hex($Machine, 4) & ")")
			Return SetError(7, $Machine, "Unknown")
	EndSwitch
EndFunc   ;==>__ImgSearch_GetFileArch

; ============================================================================
; Parse INI format string with multiple fallback methods (ROBUST VERSION)
; ============================================================================
; Parse toàn bộ INI content một lần và cache vào Map structure
; Returns Map["Section.Key"] = Value
; ============================================================================
Func __ImgSearch_ParseIniToMap($sIniContent)
	If $g_IMGS_Debug Then ConsoleWrite("+  __ImgSearch_ParseIniToMap()" & @CRLF)
	If $sIniContent = "" Then Return Null

	Local $mResult = ObjCreate("Scripting.Dictionary")
	If Not IsObj($mResult) Then Return Null

	; Normalize line endings: convert CRLF to LF, then split by LF
	$sIniContent = StringRegExpReplace($sIniContent, "\r\n", @LF)
	$sIniContent = StringRegExpReplace($sIniContent, "\r", @LF)

	; METHOD 1: Primary parsing with StringSplit
	Local $aLines = StringSplit($sIniContent, @LF, 1 + 2) ; No count, entire delimiter
	Local $sCurrentSection = ""

	;If $g_IMGS_Debug Then ConsoleWrite(">> Parsing " & UBound($aLines) & " lines" & @CRLF)

	For $i = 0 To UBound($aLines) - 1
		Local $sLine = StringStripWS($aLines[$i], 3) ; Trim both ends

		; Skip empty lines and comments
		If $sLine = "" Or StringLeft($sLine, 1) = ";" Or StringLeft($sLine, 1) = "#" Then
			ContinueLoop
		EndIf

		; Check for section header: [Section]
		If StringLeft($sLine, 1) = "[" And StringRight($sLine, 1) = "]" Then
			$sCurrentSection = StringMid($sLine, 2, StringLen($sLine) - 2)
			$sCurrentSection = StringStripWS($sCurrentSection, 3)
			ContinueLoop
		EndIf

		; Parse key=value (multiple methods with fallback)
		Local $sKey = "", $sValue = ""

		; Method 1: Simple StringInStr
		Local $iEqualPos = StringInStr($sLine, "=")
		If $iEqualPos > 0 Then
			$sKey = StringStripWS(StringLeft($sLine, $iEqualPos - 1), 3)
			$sValue = StringStripWS(StringMid($sLine, $iEqualPos + 1), 3)
		EndIf

		; Method 2: Fallback with regex if Method 1 failed
		If $sKey = "" Then
			Local $aMatch = StringRegExp($sLine, "^\s*([^=]+?)\s*=\s*(.*)$", 1)
			If IsArray($aMatch) And UBound($aMatch) >= 2 Then
				$sKey = $aMatch[0]
				$sValue = $aMatch[1]
			EndIf
		EndIf

		; Method 3: Fallback with StringSplit if regex failed
		If $sKey = "" And StringInStr($sLine, "=") Then
			Local $aParts = StringSplit($sLine, "=", 2) ; No count
			If UBound($aParts) >= 2 Then
				$sKey = StringStripWS($aParts[0], 3)
				$sValue = StringStripWS($aParts[1], 3)
			ElseIf UBound($aParts) = 1 Then
				$sKey = StringStripWS($aParts[0], 3)
				$sValue = ""
			EndIf
		EndIf

		; Store in map if valid key found
		If $sKey <> "" And $sCurrentSection <> "" Then
			Local $sMapKey = $sCurrentSection & "." & $sKey
			$mResult($sMapKey) = $sValue
			;If $g_IMGS_Debug Then ConsoleWrite(">> Parsed: [" & $sCurrentSection & "] " & $sKey & " = " & $sValue & @CRLF)
		EndIf
	Next

	Return $mResult
EndFunc   ;==>__ImgSearch_ParseIniToMap

; ============================================================================
; Read INI value from parsed Map or raw string
; ============================================================================
; Parameters:
;   $vInput - String (raw INI) hoặc Object (parsed Map)
;   $sSection - Section name
;   $sKey - Key name
; Returns: Value string or "" if not found
; ============================================================================
Func __ImgSearch_IniRead($vInput, $sSection, $sKey)
	;If $g_IMGS_Debug Then ConsoleWrite("+  __ImgSearch_IniRead($sSection=" & $sSection & ", $sKey=" & $sKey & ")" & @CRLF)
	If $sSection = "" Or $sKey = "" Then Return ""

	; If input is already a parsed Map object, use it directly
	If IsObj($vInput) Then
		Local $sMapKey = $sSection & "." & $sKey
		If $vInput.Exists($sMapKey) Then
			Return $vInput($sMapKey)
		EndIf
		Return "" ; Not found
	EndIf

	; If input is a string, parse it
	If Not IsString($vInput) Or $vInput = "" Then Return ""

	; Fast path: Direct regex search (Method 1)
	Local $sPattern = "(?si)\[" & $sSection & "\][^\[]*?^\s*" & $sKey & "\s*=\s*(.+?)\s*$"
	Local $aMatch = StringRegExp($vInput, $sPattern, 1)
	If IsArray($aMatch) And UBound($aMatch) > 0 Then
		Return StringStripWS($aMatch[0], 3)
	EndIf

	; Fallback: Line-by-line parsing (Method 2)
	Local $aLines = StringSplit($vInput, @CRLF, 1 + 2)
	Local $bInSection = False

	For $i = 0 To UBound($aLines) - 1
		Local $sLine = StringStripWS($aLines[$i], 3)
		If $sLine = "" Then ContinueLoop

		; Section header
		If StringLeft($sLine, 1) = "[" And StringRight($sLine, 1) = "]" Then
			Local $sCurrentSection = StringStripWS(StringMid($sLine, 2, StringLen($sLine) - 2), 3)
			$bInSection = ($sCurrentSection = $sSection)
			ContinueLoop
		EndIf

		; If in target section, look for key
		If $bInSection Then
			; End of section check
			If StringLeft($sLine, 1) = "[" Then Return ""

			; Key=value parsing with multiple attempts
			Local $iEqualPos = StringInStr($sLine, "=")
			If $iEqualPos > 0 Then
				Local $sCurrentKey = StringStripWS(StringLeft($sLine, $iEqualPos - 1), 3)
				If $sCurrentKey = $sKey Then
					Return StringStripWS(StringMid($sLine, $iEqualPos + 1), 3)
				EndIf
			EndIf
		EndIf
	Next

	Return "" ; Not found
EndFunc   ;==>__ImgSearch_IniRead



; ===============================================================================================================================
; EMBEDDED DLL SUPPORT
; ===============================================================================================================================
; Function to check and warn about Visual C++ Redistributable vc17
Func IsVcRedist_Installed()
	Local $downloadLink = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
	Local $sFileArch = "(x86)"
	If @AutoItX64 Then
		$downloadLink = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
		$sFileArch = "(x64)"
	EndIf
	Local $bNeedVC = True
	If (_CheckDll_FileExists('msvcp140.dll') And _CheckDll_FileExists('vcruntime140.dll')) Then $bNeedVC = False
	If $bNeedVC Then
		Local $sReturn = "Visual C++ Redistributable 2015-2022 " & $sFileArch & " is required!" & @CRLF & "! Please download and install from:" & @CRLF & "!> " & $downloadLink
		If $g_bImageSearch_Debug Then ConsoleWrite("! Error: " & $sReturn & @CRLF)
		If @Compiled Or $g_bImageSearch_Debug Then MsgBox(16 + 262144, "Error", $sReturn, 30)
		Return False
	EndIf
	If $g_bImageSearch_Debug Then ConsoleWrite(">> [Confirmed] Visual C++ Redistributable is installed" & @CRLF)
	; If we reach here, VC++ is installed
	Return True
EndFunc   ;==>IsVcRedist_Installed

Func _CheckDll_FileExists($dllName)
	Local $dllExists = False
	Local $LocalDllPath = @ScriptDir & "\" & $dllName
	Local $dllPath = @SystemDir & "\" & $dllName
	; Determine which version of AutoIt is running
	If @AutoItX64 Then
		; ===== AutoIt x64 (64-bit) is running - requires VC++ x64 =====
		; If AutoIt x64 can run, the OS must be x64
		; Check for x64 DLL in System32
		If FileExists($dllPath) Then
			$dllExists = True
		Else
			If FileExists($LocalDllPath) And (__ImgSearch_GetFileArch($LocalDllPath) == 'x64') Then $dllExists = True
		EndIf
	Else
		; ===== AutoIt x86 (32-bit) is running - requires VC++ x86 =====
		; Check operating system architecture
		If @OSArch = "X86" Then
			; x86 operating system - check for x86 DLL in System32
			If FileExists($dllPath) Or FileExists($LocalDllPath) Then
				$dllExists = True
			Else
				If FileExists($LocalDllPath) And (__ImgSearch_GetFileArch($LocalDllPath) == 'x86') Then $dllExists = True
			EndIf
		Else
			; x64 operating system - check for x86 DLL in SysWOW64
			$dllPath = @WindowsDir & "\SysWOW64\" & $dllName
			If FileExists($dllPath) Then $dllExists = True
		EndIf
	EndIf
	Return $dllExists
EndFunc   ;==>_CheckDll_FileExists

; #FUNCTION# ====================================================================================================================
; Name ..........: __ImgSearch_ExtractEmbeddedDLL
; Description ...: Extracts embedded DLL to temp directory
; Syntax ........: __ImgSearch_ExtractEmbeddedDLL()
; Return values .: Success - Path to extracted DLL
;                  Failure - Empty string
; Author.........: Dao Van Trong - TRONG.PRO
; ===============================================================================================================================
Func __ImgSearch_ExtractEmbeddedDLL()
	If $g_IMGS_Debug Then ConsoleWrite("+  __ImgSearch_ExtractEmbeddedDLL()" & @CRLF)
	Local $sHexData, $sDllName
	If @AutoItX64 Then
		$sHexData = __ImgSearch_GetEmbeddedDLL_x64()
		$sDllName = "_ImageSearchDLL_x64.dll"
	Else
		$sHexData = __ImgSearch_GetEmbeddedDLL_x86()
		$sDllName = "_ImageSearchDLL_x86.dll"
	EndIf
	If ($sHexData == "") Then Return "" ; No embedded DLL
	Local $sTempPath = @TempDir & "\" & $sDllName
	__ImgSearch_WriteBinaryFile($sTempPath, $sHexData)
	If Not FileExists($sTempPath) Then Return ""
	If $g_bImageSearch_Debug Then ConsoleWrite(">> Extracted embedded DLL to: " & $sTempPath & @CRLF)
	Return $sTempPath
EndFunc   ;==>__ImgSearch_ExtractEmbeddedDLL

Func __ImgSearch_WriteBinaryFile($sFilePath, $sHexData)
	If ($sHexData == "") Then Return False
	If FileExists($sFilePath) Then
		FileSetAttrib($sFilePath, "-RASH", 1)
		DirRemove($sFilePath, 1)
		FileDelete($sFilePath)
	EndIf
	Local $hFile = FileOpen($sFilePath, 2 + 8 + 16) ; Binary + overwrite
	If $hFile = -1 Then Return False
	FileWrite($hFile, Binary($sHexData))
	FileClose($hFile)
	If FileExists($sFilePath) Then Return True
	Return False
EndFunc   ;==>__ImgSearch_WriteBinaryFile


; #FUNCTION# ====================================================================================================================
; Name ..........: __ImgSearch_GetEmbeddedDLL_x64()
; Description ...: Returns hex string of embedded x64 DLL
; Syntax ........: __ImgSearch_GetEmbeddedDLL_x64()
; Return values .: Hex string of DLL binary (empty = not embedded)
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: PLACEHOLDER - Add hex string here to enable embedded DLL
;                  To generate hex: FileRead(DLL_PATH, 16) then convert to string
; ===============================================================================================================================
Func __ImgSearch_GetEmbeddedDLL_x64()
	; This function holds the hex data for ImageSearchDLL_MD_x64.dll
	; File size: 132 KB
	; Architecture: x64
	Local $sHexData = '0x4D5A90000300000004000000FFFF0000B800000000000000400000000000000000000000000000000000000000000000000000000000000000000000000100000E1FBA0E00B409CD21B8014CCD21546869732070726F6772616D2063616E6E6F742062652072756E20696E20444F53206D6F64652E0D0D0A2400000000000000594659561D2737051D2737051D2737054F4F3304152737054F4F34041F273705145FBF051C2737054F4F3204072737054F4F360419273705145FA405042737051D2736050A263705B34E3E041C273705B34E37041C273705B34EC8051C2737051D27A0051C273705B34E35041C273705526963681D27370500000000000000005045000064860300670614690000000000000000F00022200B020E10001002000010000000100500D01B0700002005000000008001000000001000000002000005000200000000000500020000000000004007000004000000000000020060010000100000000000001000000000000000001000000000000010000000000000000000001000000098380700480100009434070004040000003007009404000000700600484E00000000000000000000E039070020000000000000000000000000000000000000000000000000000000C01E070028000000C02007000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000555058300000000000100500001000000000000000040000000000008C57CE7500000000800000E0555058310000000000100200002005000002020000040000000000004C67D37500000000400000E02E727372630000000010000000300700000A000000060200000000004C77D55700000000400000C00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000332E35300055505'
	$sHexData &= '8210D24080A64DB7F224E490AB73EFA0600D0FB010000A40600490900A4F7FF6FFE4883EC28B91000E80904509848890593580600488D0D8C0CDB6F77FB0F57C00F11188B057F2789082CBD9A041283C4B6FFBBDB28E95A55B4CC007E3848C7442420FEFF0033C0462EDBF980FA590C0B5A0C0DB67D47460E0F5AB9F3BA05CC5B176CCF6CCD0DCE458A33D21A034B7C7FEE5C792EB5C705BA0168660F7F05A713BC9DB7781005A3FF1A8987C1DB1DDCBA083E427B167A01E57C905C7B82C9C83E385F28BA02559282FB33E0FF15F2A146B22330765E160132192BBCE4E5D15FCB57C457B7570C2C24834DFF10C30219B97253BF466697471A572B0D2C2D790C47462E2F57BFEC56CB0B7979ED56EE56D55623471EC8DA56D75643FEA7485E7292569B56AE992118727040576230D53FF8CCCAED5687A06C3D2F4D7C244017F9E005491F570B1C5714EE39049319594A1C00280D26B30B4305630A59965CF09091FDD28BCF500226CC62311CA915305FBDCAD131D9BFB9993F565BB25BC9D29F6F399C9FB0A7991FFF2559A31F8BC2C33F07BFA0207EC9485AC80F540D225E662BB9DA6B14C13D3F02E0FF807CBF814D85C0740F663911740DB759C3BF38C1024983E80175F166C3EC6F3FFEFB0F7F24482BCA0F1F8453440FB70C11081266453BCA757DBB33F268C2E725B80148B9FFB53F15F7000F42849E53204D03C0A2D92DF8D01EE469770EC30C205B2D367B04EF32E92C7D3FB8FF017F411BFC5B4580C92425232284E49CF2CB1922490BBEE0DCBAB3C706264000410FB61E49FF662BF8FFC14833C1490FAFC24D3BC872ECE3FF4076383E9FA6632B33C40CB2304CF1AED81AA8C60C28010851084C20209D9AE05C3E0503A9463E014B02835BF16B224C2C89420880B9A1332472F0A0B5223082CC8A4B4C84401D073BDF72C9A86C64A24182057656B51AAE09FFBE56CD5CB1E65653A7995F0B4CDE6B0FB0890A044A2448CA531593D93537CCBF693E0899C792177A23A13FD4BF287EE546D585D2480F45C2DF895C24089FCA064EA7C71FA8F98BDAADF869729DA2D5F6C301FABA180ADA8D16E320A8683018C7550B96545F9F3F0365D560B02C109C776CA96BC930FF547D9FC92B76A5E2C39FD09B08E4155BFF189FD3AC16F2159C5F2C26B0F508B1BF1D01044108105230523027CB44ED20AFDAB15BC39FD79A592A58C99D7F6AC16957140428420006BC3FC7C0B158DB748730C0803C2475F777E9164CEBFFF90078ED73ADF97FB602880189C200DC6B047B311F0C1454B06B351FA35E016A6DB5F7431B3F1FA454DA9506DC0E0E000656D425F6C9BF4D397E13574A0B05213F3ED29D3DED9D02916401751866152E96DA205FE1E96CBFDB268A3F280602278F8B50F848'
	$sHexData &= '2BC25CA07D6B1AC00C83F81F7708C611E2C3AF565B76BE6E9E9FA2899F4CDAD525B90F282C6100AB371E4489490863609C060BAD2C0C7F3EA0010684A43D653E103E6C7BFF668206D241C1E208440BD01CC11512085CBBEDA2176ACC11718C66DB2F31BF5EC1E0080ACA0B6E167FDDF29DC811C954AAB9BB0414C0211535BDFA101CBA1E226A12FF8FBB1A04F606C78BFA0EAC305DFB3D147C40F6847480CB100475142807303360789EE15C05C476E1003B6A61FC2F1468B08E5FF9C3DF3C6090CD30732528FDA6870207E0A803176F69D680486C541ADA223089E4020ADC4308BA32D2287AD116D52336093AFE9DF6E84CEB5FBFBA07AD09A0E0C91D9D010A099FD939C8C4DE460F5F02619DE72899085130091F9B06CD0452087068780E46D88A74181B20609601D946E892CF9C30AC8D160101861B6C84C950BF083FB9B95524F9BC8B498B9C1F2E0324E4E323A7139A0986624913281D0310A0D5059E0D2FA339D15D2CAD7E4CD050D24807108A57E17E698B5310168A0089501071600854AC97BF926138D11FDD9BB71048C841909F13C11DF22A9DE19B8B3A13A1E4B1049FC3224BC840C8F99A73876C5530C1C7012F01C812C2748BAAA92B4D658887DEB704C3E7448A85583BEE61F5FF95E449A6214C8BC2821F04D92C60B74B498BC8D896B81A9CAC40DD13F2DC56C14B0851BF4083E877DE4D3898AC09A6458BD8FF7A57E2FA8DEC448BD2FD0D41B90ADA4F4ADC20263EA82E418BCA04D3DB6689D3EC3DD1F7ED8E82508938EFBF032007E440CA80B66464BBF24C8D44C933D2D45A9920D88055B47F7E1057DD3420AFA79F20F949013934EAF491D84F385C2E00F6DECADFA6DB1010DCB20DA7FAABCF48EDE098B73DA8018BE9EC4DC048C339351ADBC37F498B7E8BE448530250D0C498D8F45A0C3FE6C9006B136CF115958DA81D55AB033F0DEDB22D79507E981EC99722C2AAC43F3F9C921772EFB4BD97D897920D18813E99B45A4548F26B977F4EBF212F9FB31E987A18106870056A0F3672030E026F4B51A00319449973409505E6FF940090B10364DA5A888701FF33C8063DB7DFC74EDB9B5D710E0614B8AF8520D02899F3163F899017727F9B3594495EB2415E399BF393C151E87C3FC153417328589DB80EAE04BB3FA9904372DF9A9593A1840CC8999A530FAFE4D45F699A2393C3B1E069C8B4AF0FAE08016A9CD29EBF120CFC5F2A7DB22B8B5E9E1A66BFF1BF15FF8D5001F00FB1DC740A3375EF32C0C3B04EDB743A27F0FF751F0CC3E1400F185FBFFFDF7F6EDF9A0CA0C16883F80175181C01FF107B0C83FF4C0FD4340903FA5008659D97061B011D810CACE0332A07CCFF60035388426FDEDFE5A607DCFD85C9741BEF501090440F7E3B2438C300BA45C'
	$sHexData &= '8411819CDAB5815DFC63382513B1FD080F65A18730F12426204CC7522332BFE83EB6EC740387A24741712518D4682FB344D5808403CD838A3608B4021FFDE0A70236C4419FF37126C78B4397C0F94D1A4AAC602345A4C7F5F8356C7593A349FA016341CE8DA4448C80008F0511058C55297D9BF14835F333FA0490640084D4EA8C14745013C39500366326381A3D1AB4444926CC334C4FDC01F01498BD84430B5507607D17D304B84AEDF4939518C263F60FE0E8B0B390875082D3291F6DBCCDF4839493C443902D580972B527F887424108BFA5AED5F5E6435F844068D159EDE02007AC6E678E0B336AC448E8B9CAC12DC9EF0CCA4907873197C38893B47D76055857F56B160C706D900A5405408195098F0AB0DAC22F2494C88BFF5AE1F1A48498378D6741541B82D156BEEEA814D7DCB52020CAC4EE273A349C30112062011C410DC0A417C04440F431660374DDB1604613C8B38FA10723BF588A63512C239F281FA46D57A8000A0721C2027ECE7C1499110C176BCED8FFF2DF8003733F628771006180F10030F1160B6D7B6070A4B100C4F22732AC743B0CBB77D48408833865318CB2C0BC154F005CA182241F8492BC85241C09E128FD32F64B989935CE0E0C603CAC7EE50601F9402C55F5E8A1E5D9F55016CB73741564157966C24C9C8ECA00FF7436D7F45FFDD9C24E81EC4A5B6D6DA93174527D6F8FEFA04F1184DD7D894F6F454C79F0ECF385810F0072B78DE186E03144CFB107311DAA7BB40C2C81145B7450FEB7C9EF3A16ADCDA32CE0FD57AF0C0838EADD447068D46DC3DCD3460D35C6BC82762C23D3AC846CAE14B822B61D0D33BEEC6A6B627E0E0F6F8EB147C8D8EA502EE29320842B5A2397BBAE44C8D43E0D72569777537F8CC56045DC7B6343CD741332945072FF0386E6EDB74163D2E95B04DB71FBFE51D3F4D0F4A8D55073FD69AC7760EF47D1F3B124C32175B78B9AC38906A551F344D070882BCEA35D28D1CC3667B102E52DF0E4DC74DEFB9ADC92E02A33C7A8D3E660ABEEE6FF27EC1660F73D90813C890104C16C1E12F42111ABE28498906498D5608095C2E7C3B309876F2996FB0720F014ADA6C8C50FDA8950CC8C15EF7DF87E51B72228E05A993C478153706114618E8C68C2793BCD2916383B0C4415F415EE4051576FE5DC3BFFF924320272FB58B28B913F22A80925F738BC4B5ADD65D7F40901B3A50581804DE70D260DA20AA6F0539E53F86C03F107F40D8C640C880261793B5D53F2A488C020B1C90712944F5BD90F2308DB1CF9A183CAB8603F93B4830A5F83078C9CF8B8AAA7D72C7D5F0EA747B806DC35F532187E4CF91858A89BC905789915F438AA9A22154C2AC080349AB891BE7DE015F414CBE760B04241C1E867543103560057800'
	$sHexData &= '533D0DB4FD2F7E49FFC042803C1C75F6B5CB4AA4090FC3351F58E0161CF6C2AA0ABA93A56BD0884D7BBFB5D5857A3E74753E06B71ED89E7C7640C8F82F3E1185278A90429C764A4F1E28D6583E2C585C902287D6383C32F604725DAC6C0DDF0F89F0A5830B81E33CCCBE5AE0015BC5AB8BA9B047180FBF2EAF9043FC8FAF8890B658D84D98B7AB01BE18869F816118FFF3EA1E814918000290438E763FEF203B92430EF908832A0393024704235F6F9582C0A8110780A683F14AACC07B184AF872861B41B80AB49B1E60A2CB0093CB4C0FC5D970AB3B9020750E240DA9462997EF678383833F2225AE78A650212673FF6021AE06791058D5FAE83F680E300E523085D2794741F7D8BFEA76FF1F83E902B8CD701EE0C1EACEB7C266C1E002E2AA55FF8D0C106603C966446C66416E3066456CF0B69D427C6C75D05EC1FEB82D7A3069118ADD26EB31907FC8971BF6E92007B5434892A86FB277FF524C3BC874164C13498BD14D6A36CB49D1F8AA30853E069C9758A79217C1D30BDFF30F6060305274E5D4C176B0FDE549BACD5D5FC6C2495A11B84141485D855FAEF8A011DFCAA24687044BFF3010789A3BC1750832AECE1897B7CA0F149F6E555FD24E0E0F95C0673F68806C058A0944AB86AB1A6D71C51F1F3F9BA5B6F98ACD80B710A4819948F7DCEF6A86FB109669CACA9A3B4969C80D55A94EF52BC103C12D13A7FD9160BFC4C974069CD6A7658900713FBE14DAB30A61CE800AFAAE4F1CC8B537015F1C7E92017994DC804E23E4408EC41E80C5AE036251387FD296869959D9805475EFAE58F25E199F1624D60D2CEEB3304F46AD7F6C6562C890CC3F2E8D4BC821B67FFFD47F3F4B15C22F35E17EE3B6BC2010CED17FAD7F225DE5C12A0908187F64411B845EA812646B7F1385262FDA7E9FC272F00F785C4803C64008000028109D775A2C761E5F4821CD5ABE7E3BF4A21B5F4863060D2EE002DE8B9DBE04816688DDE9453BDA1F863F0FB64220051B601F9E7BE86EFF137E0E83FA027E05080575043E9A4D68891018FD1F012C2EE4874539684F0AED5AF89405345B9F211F04621F3E127E0DE16D42DD033EE44BFF7FAAB64E411F8B02F0440FB1A8024BE1017506918002806305EDC03F1EBFA8004F7E8DDEC9DA4D638C8278D16FFF1B1C329CF9057728478B8C8A9836664D03CA41DF5B64D8FFE18F0F1D74F1A10FEBC9C0EE1F0078520787B8051C47763027C67CA59FE3901F42FE1D7E13092C7B28F03084C09E480F21FEA1926C7FC705DE0806003217C7FD0271D7148189E9D63ED815C2298B05B21F3FA2A29A900B92118311D16345FA8701029F7C0C22BA1E5F9F950B79559FD4C72D70F17019923814852309902943A9EC25DC443019D862075C9F535BA8203FC'
	$sHexData &= '78848C8D18A183285E753A31FBC404828B40B403C220F044FC0D73A6156F05489470869B3EE154D8B071ACC5A0806E0055EC02DBE808BC61800120095431CFBDC1AE47F1E730C83FE01750A9083D63A31D64014A1F1091679FE101F83791000901315F09D9F6306410E210F0B840885E040C8CAB57CE69BAF8347212F265F657C69BA90D7A1833F237C1900AB808645019D150B361C7F29FF7F3058B221105A05F1D7C282D77E8B49C8531817813291CC01777FCBD9E15185103FC57608EE2051253E79303FD82C0590E8DE51182F5C85384E20FF403FF4C87A6841763F06E18708DABD8B1F21002C3C4B1211BE4EC0C0DA3701A6210466DC9BB30C1E0D1F40B9AD820E134B21D89FF011D18376A168D6CE12065CCAFECD166CB6AF46687610065E187E2018B4755C541A5D102B50585840849C0ACE6C23AFBFA8207A613FC39F0622543C80750135F30233305F06188A7822C420FF8B0DCA2BDD2AA0D8655A255888697561FB3F18C88B0C02390DDB2E347E38E6D227F1DBDE10B84F623DC614FF752336F7BBA33E2EBA6DFD05822F3F55B45698ACD291A64EE8486A2F52F95885DFDA78387B080F79EC0260C624618887D3AB44874446407733268ADE74AD2B5013ECD27B50206F12506C17C9B796F8ACF02DDA74B125792B1C990F9D78BE2E4E60979EB79778C3491E7584D77310AFB2F37454D88D9B3C3C861B004100075C7F8A2A873C79849B2D922D862739F2922D7A6C422E662D6A6FE2242A2E95332E72802114D77FAC01CB8BE4549073D7C7471EC8CAB02C9A73EB76A32DC9435E21DE73B373044BA5064491B1B13360849D01FFC07C62E0A8FFBBAB590883EB80406F46167E11FF5208C11830C7407C0B44BAD0F565FF5DDF21640B690DE508DF50ACC90ACEFB8F939D1A722C5FCB2A5E2D83B02DBF76073654601620181E1B72327EA719E84B60E51CE4A2C683B0B665FF007383B80001C7BF91A625390B8E6083165CDE79A2D1E64A0337608514151F1481E078E80E75603A7A9A804F785F107568FA8BCF5EB9F6FF090C55202C4F100F45D883FB02754BBAF834E8BC4FE2219408BD7164D6A0498A876701393CA4794F6509A0902C182DF30241B9893F470860746AD809ED08132F20A7067F078EEC7D949D7576A6D3CB71D7448E89A3E41367C048816DF968C14812003C390030B94BBB77BF10845368380A178BD0B8B7A5FD2789187C404C3F007512FCC32C7B86ADE038DB141D89814FC107D2895708094C8BC945F0066EF49809713A6690F33F02ADC3BC0C30C17975ECC2AC58DFC34D0A05495E0408D2C8800A1364DA7A4D88880E81F22BE961B802A18E4F0891DC131FC4A708233C898BFA4697F8CED9874210F0FF308A13D680D1EF40B60183757B7B47EE73'
	$sHexData &= '9215A81870B46F8B434577AD04FE374032F68D4810EFED38C52A380D397B686C060C68B547C487EB1A43702F4B0E8BD75726F9ABFA6F5E4084F60F844C2A17B26833C1586E7217529093BC42746F106FF29093BC8F6FF36E806FAEB0484EDC6EA90121308A635E331C3CAC40C850F0C8C7589C5C810F7268203A0EFC054880D70C3FE1F14566F8593E5CBF4CC11997BB6E37578B4E68BD0B881E16AB43613439394F255C1372D15975EFEBF141AD8F2869DAB8466814E09BDC48488942145670758A0F14FC8BC5874710A920EB0341E2794EC5070F6B6E1DCF6D4529960F1F3564B901E833C02874B85F9127EEFF83F9020F861740BF2011FEFF3BD8747B876F1083FD03747307A7E2A5B2D05F6038D26D436E6D851DF03B420180BF0F752AAEAD6A1BBF54D3BF5D3F937CF0765374DE5BBD6D21E193232834484C8D5C0C34DB0FD25B30066B38E399FB7063AA3F010FB6809521C20A1D18D5E7F4C1485DFFCD04A2C4DACA4610513F43295C35B7163308B1B4812670BE0386146F05892CB9D966C8B40BD80F44B8FF8D1535618B4C068B1FC6546362ACA111B25A581D9F98898C10C1C84B1E79C39FA0D082AF08407B009A7030A737CB83E0CC81BC9A609F238C568712C8087FC98E2E03F2FA48069F6BE0FDA5393B6B83027D0AC78711C849565DDDBEB76B136B721FAFBD7C982DFC6A49BBE2406EAB85FF40584CB4E4465A55F805A13082EF01DA7948AE28EB013B6882DFBB9DBCC6420183BB4528B13B9AA1A080F1D761FE5914FCDECE704F7CDF95EE6A53963402CB526A385C3129379DDFDA467E612BCFAB69DE4F487407EF5EE99A0E8F981C0CA027C9A648D14308A9A42C8798B4F38CBC14A010A864B0630054BA5B4B76B746A6BF28DA18FF7522DA403A7A02B902D0CAFB4783B614891F4C7C8D1555FD76550A4B89F54122E62AC0419184BB9E56B7F0741ED57FB94A0E2AFFF6692E194A2E68686828B9E4486868A79253C15FA5F55168928BE424ED674C9CE450F4C0675F3E68A267C9A11A85BFBF674E720A395B67D76733670839C943B8671C671828CD426890DCE483B9596BA06A6FF497222BE1848F18FA39B458389C48AAA40261029981250E3C7E5CA3F0DA3FDC248C517DA0976630B7C5EAEF6065914133A888CB48E9F24CA10DE905661548706765F30C78704CBA251FE0ED13CE0F66E23CDB815C69525DAEFECF0D1420062859088E549A03B7721866FE4C5CF8C2A7C950C7EC029137F2E91EFF10EB1848C18128A55C5E9D4D28B181B9BFC71C4873807BFFE921CD85162A3BC9FE48656321CFC8654838863641821F8F2EFF1D55AC82419001DB010E06683F42C9E3765758CB243510966CC26E171EB180A50E1215C15A48779858B279299C4BAE565EC9AB1'
	$sHexData &= 'FD96F9368C48756A9C1405E59B0C54217C33F38126B89D3E1FFD836225E973F332BD12CE2F8614484882920C9151163B6291C43E179BAC54343434B4E298F0802DB689F6F46AC85F93F454753C3799E4C4C4CD142EF79DA82187D4C424242953CC185465F08E7C74138712E7002254A38D60C5D5003A1084D3817720385587F4987ED98503641EA62E1B44BD2DA572E143BCB0F95C22A20EE4374508AF0BA4001E84653EC387FC3DF19938A0DC8B030B11590B3B3586D41979FB1958A858615097F6D756B10148D9FEA02B6117D3F98F4273108D9B940BB15633DE0F84F2EF240162B2F274B0D4CD041F5C48523E247384486D7B1E8E868801B7C9F284BBD104EA728428ED58E780C01314B601089E44404A45F2D605DA56E2C3F692F8522A530021FBF4B2BA149951FD7B0F28FE34C8BDC498953704986A8EDBE258C3020D89D498D43B04986E9D7AD2832FE424A150EF1C061D3360153B020DE8353A1130954CD825F6429220645B16F5486C4A870FD7F82D644EA876FF9F965D286C0554A5F91CE013DD165508D01033AD44AAC34D49F5CFD24581DABCD9F40B2E0D9BA960F9EB25ECC7E625E452C863220AC433089B758781AC1F89214C5FD014EAE98D52890AD078D38EF200628144B661E62D92E9462E518F9630A2AE381DE0308B2728425B0DE60ECF874205A030316DF02151129B837C2E1E7949C42619FF15D285AC9B53FD11F838F17729D5DC601F8020D6A87E080E014223BCA43377D7C9A4284122A03166CB72E20311F31671D1DF84088E59F0A28037398AB0B75A9E8472C0A10D79FE2629C1C99809CB01044023633C802EB782A4BB882F61D2561C2D006D849D0D0C4067966C4E25C45586870E4B3B2796829B10216EC5C8ED82CF145E85124396045E3709AE705F11648C93A08E6042781FDF8113778D4E133B87B18C0C27FDE7BD7174D9C244006480E503840887B125303CD306658AB78F0A65CAEFB9880FFD15C4A460E1319A65C58E9D204C23F18C137B188A5029F4D7B57880B509F015724EB827BB335100E10771F9AA390931020101882A73C6920CB605C3041B01AB4B61FBFD4827203DF66BF58B2E80B31CAEA8B5AC9A2A1D83F09E4625A9C8C77609E41544155228F628C0247EC6C406835B003B8704D6C8BEA74FFE543CD6A7F33ED448969086608C5FF3A4D90061080C120418D5502EEF151DBCC5B226B7006AB758B7EB635B7F26CFF470819A03E0466109C9EB475C0B38881CE64425AD04E8DF3F84E0B83AE210C9FD494E72B80041EBEFBBE749AE73348A6A844B05A4EEA9C9F532AA95C6B36F2491E10270C700A9E020783904848100C50E1764746584001C99B600C5C3483B0E08368A36B6083FD022EE90E1A134595D9281C0DA47941D477FE'
	$sHexData &= '9E703A1CE7B58BDA7014FA87714E415D415CBF41D3050C28DFD981354E56ACF27D78AF0A62D61A4DF913BA25676B64F08B8B9D595416835801B98202E37554BCA5BD83950C5099688B7658FDA4E8579C90D7A63659DC780A75A61829E3E06CCB404886BA5D4D541019DF187910433E0BB0067318EA7B200CE601FE898C68893880790C007476EF7FBCB3E0D838B1D062D0ABAC58F32B8F4A494858500183BF380129055FC0275ED69E8FDFDBB9A456A81C4D7CDB939A2F6456663B09FE57604B97F854B64843ED735DFBEE0B1C88286D2BA9C72EB51DC06C3E448840603F36100C41151E111F673B804F65E393EBD97874166DE592070D1377EB052E7CEE009A0F087F0D7C538B9CE4870B0F3809A7574357F4260EB940320C726008151F1F98574E72484E0C578A57EE568C5FE22177103C75318B4FC04A1429983C042CFFC01E8A251F9268B450A907B0D90673207B289BC326E80B7C309C91439CBF251D758426113A10C2417AE2A8EC7C8FDE01047C853FEE41B1684FE9B4013654DE06D1BC8047F6BA3F9E9E4314392685C854E6C3EA6BA98B81CD74A81FD104A391D96AB0DFB9028150B848646D5E29CD5414010C0C28ED72A0C0A1708C5EC063850F60B48FC24E4B6C30A42E7655A74B760A87154AEEB3B8E8B295A2CD7130590746B86718924C195CDC41A00DDAC1B00198D02CCE9E10F04FC7A56707B3D7CE5301892E35FAB338C17C5D971C39744E551A47794F275A43AED04E40FAC63EB004367C0109BF400BF2B05EB8B8066B28D092975E5EE242E9408C10D538C04368738F5A59E20C199C324C13811EE86DAEB9D09B302F3942F633D241B828975C172B0B84D6609371C74733FC2104792022698D4F31F0E4D9E6534FAF54A1CBD90B6097B8736078C1B95400B8C0C83C0C0483C80E243E386A7D991542B7419F89BD80D1075C7CF44D7882327C903D16AA803B97180C82F3582E3AE24E911160790B1881157DF34AB5A6431F501935201FC452F0E5E0D90D03A0816F7F9795132F421846F4782FF119FA16908D48FE4A08E24FDA81C1B77E2B75EBFBDF4560DDB4A919FFF9C9218D6565C703C934168CA27723711FFBCD85B00AC7D068509C000B3C0BA33CAC250E7E05E92A6B7E331632501F0CFF1E50174791474D3080D2562A504933DC2E8B1370139C278337DB0EBD892F8B47DF1F930BB990020304C82135115FB1231D6015BF2B687A2580182C2F8C2C044A0D2D5961C48840EF81C15565D7140B17DFE3DAD9409E5EC0691E305D400110D43560306000CC930124E50F351DE0F2B96C3087CAA904FA0FE21E9099EBF8EBF69F7C2DFA0A8F69615206D9017A31DEA01A3CBF566257D8E02EE1A7BE544464CBD28B47D8B25FF1AF858A52A9807B200013F2571'
	$sHexData &= '0C0FDE203A890693A0074AE48071CF831403702E554245EA7B201E789033D0C02BC25014A3C5AC62DBBD1C3D1708F02F25F0C83FB7053A97C604F987015A288C2FBF0369A8E4F23068442109A61FA5F8B7B24382EBFC0C807FBC689188C9273503C780B8717A524883CCF55EABDD83840CA947A878C4DC50901BE74AD11BA4472D336B4C3C0CC3B4B123CC2546DE794E362F1EB1058432445C357D05AC7513C095C852E6ED495C3D0262E40B9B09F201CF2C34D3B221FDC80E4308C86C699BF4D63E495BC54A3457240345C413C91677893AC90A47228305C4CC35B348D458740426021970FD18B4A4BAEB0DFAC1987CF100183701E09E0CA433E260BDB0001F133FFB106A662242051099D2D63C0E9D8515F0F9D10584D439F4C467085D400CEA83922FC24DB0A3CC3330AD6DB741DA7C1030BABDF1679F08FBB470793AE565D76FE29A5931E8738A1F81721941DFB2F16278B4D24B71258681A69A07F309DB1087AA93F84E857B6E237D519995A74694B734C58B00E90BC08449A33CD2E946D2BF7FE6BB868044535A03BC823B3599536BC4BF5802D0E925C48E735F88012980AEF28778D0A17B7B01B6DA121C6858885D3E3C0035D0BFFEE41DDC42D872FBEE9A35F1B216084934B7235612354404D18A3286C049E27DFD3CB07D6DF7E575170544550AA80E270E81F171DD113CD90C82BBC75490F4640CA75ECF1DFD338885FD94E48DC58253F18817001BEDA8AC87F04991B3A342912EE2E51105291B0F111012F363FD04A87CF5560A2CC2D32250E4BDF1456B5943F04D092E3970CB55C8C014B9F03E91C31034FFCFF10370216809F4B08532360AD25DA910712C8CB1059137A598B80C9285D72BA049E7503A88CF1F75740926B21289FA71298907028F9ED48A466E22032C0BD0456450C1F406881A29F7FB8008B5CBF27C72353F1B4EAFA35185A2E488692AE904F9193290421CF47564A0E81C32698A51B58C4FFD84C0DB4D08C8728025426AAEEBA78BF4850F0C47DE2EC528CF2F5501F855B89074C255F8D2816AA7047EB380A4DA7CC8B3F1F3F04F082B509DD0049DC249C0200643D641A52C53F1F281E817B84B34033F6EC4A2513D46A50091C156A2D380F87825D6F11CF7A5E01CC40064850E1BA8397C0E544A91885C42D1706DC1364A56115522A08D9958086B3DA1F4A9FE4C857139F58FE05AE9A0079B2F964FD053E4454493457BA3F83E901742A091D1083F903B3423C01FE3E51820F927232B2F250CAB20472799D3F696701A97409E4DD50F76B5D4A0BAE524F413278E743A0535A716D65A7F23EDBE01560EB1910371028963E950E07F54F21C168E736B902B37E790888A51F95FC0579B2B9F2EE98A7FB058142974711A5B17C6FFC053F89E450F20CD0'
	$sHexData &= '05F0411A0C7382A70D50F86E414AE3BC551E794B45312039C82145421A421AA61A5B019658D0C00CB27052CF406F9CFD180F4E1A1212B64E720567FA0500C0B4D30D680A6A00CA7659229C3F5D4A15A8EEA1B45AEF3F034533D2FDA5CC7AE22441B8DE29A6C3D74AA0411422FFD3C48C2F00A87542F4142C89197EDDDD0D00BF15FEF9CBFC0AEB0C8B662A24B0FB0E8B0DE60AB02DC0B66C58B455B978B53EC19C5C2A2F9FF99D9B8F0828D1B985EE3CEE745F00687239C7057D1E8FC6057AF2DC46E012CC05720F1E6D34247986AE409AC461FC4EABC33C479206751041DA93566E0C9035EBBC362C06051F800E340966141C096D8686B49B6A1342750B73B269EEDC016F3686F8F811DB81A75903A420E8019E61DA38E073F748DC0A0F821F813DC1F0559AF26DEE61154E730998B6F85AB1D13444E00F77CC3FE95BDAA92618083C09412BA5A528E48150EB25739F500ACDB506F6912E78FF63CF8F9CBBA98F5A2A644F067D4C3E81A32301A4664878FD42C1F107C864294CA0DD53AF88D941A243282355677E24400816584C688A7A3A44D762EC0A5A114568E6FC40EA3AAC55531DC07DC140B7CBEB96139343701D7245335FAC50B371341A6918207B1B906CB6073F0A363D8B0D12143C3DB714ABFD645480B001FF3F0A6125473BA82A712EA87AC6D958CAB8A537F1BE414E778AAE5EE04B2CFF4A99200B49033E20580F45D0E006975F1F61FF18576A50021C80DA5C92CB23D129B1BA9BBDFAD6E70A84EAE2AB2D3BBA042D2E3CDD580C02EA321D81CF3E8DD724F803F18CD70FF5122EE2ABFA4440023159792070025002580FA1A53F55642978133B85A8F86C56E0BC343642055D70181C7905FC5FCA85D02CCE04E0D26103FF44A1DEF6A1684C8939047908061045510B1C5C602985603E21AAF438081B78491CF11F51FF5B7041BC5C0844396448FE742E4EA2113BF2731C78010BF615B6DD645BCEB4EB0D458BCCB159F104F802B44C9CD11E73492C8DB2DB2D3C41EB78AA81C06B445580DE3A0C8012106EFE421F98819DCD68275F0FB74DAC6773DC6F0645AE663B0D299AB4100522754FE57D55082A171A10111109C021EF56B0440549542BC5C74CFCBA4516665AFC0D3A353888083BC7742548492C1829027F171247101DDD07F511D95E7B105CE0EC5D3867F16692F6261D6E345C7431371F4F45E5181C9EC704488B3D3838173AAC5CAC576690F6B0E05D3E6642833CE275F51CAC4B2FF5FFC35A8B4580C1E804F6D0240188828B5E4BAF3740EC5E10741C93387F28BC17840FB63688E8460828EB117ABD67BD4CF92CCE8699D0250372B9CA50333816A95EC9157764BD3E200B600636D83739F2B5C2EF668C218E38888478904B06E441602353DAD9060E7E2'
	$sHexData &= 'E3F0C27D5A2D42722468DD0C52598A672E00240482926006F8D5C5F5DC3DF9C6893561D4120667DB03A8C58DF5118CA1446F07A7931EE7F2135B9E2E11F6715E61446E7575A571DAA35D79F56579D687C3E2497FE700F2970C890C62A243F83500F28F1B70B573D38F887505D139C8A8F7F01BD2C90418D57027D3CE7B1BC6A0DA4026DB4FFFFC53A44014E3AA9C66305DADBA2483003CB125708FF17CCCE75B05230A003F0527E10A2D7D352B6464C3E6904607F02FFAF4DD8F6C102F645A84C82FFDABB207017168806100CD04C3BC04CCA9EDBDB0F42062BC2EB284E04752FA006537AD6791967804FB84C638E94D49D3C4D4C03C1A04F5275E99ECC90CF03DE147E5F072A21621885294734BDF06B5941BEFC8EC6646C4E1C824DF90D219A0C151CC0DFEBEB64445F0166413BC6734D2260B8514EC644059035C47A750C4475E6C636A1359C56C00342C0A89B3F6C0C435F150FB7C0807C00740BDE207A5B4874556CE902EBE26C4AD1F9EB4E201C60C17750BA0CB806CD2B9852449862E97E73D4840CD602EA0174BEEBEE9D06436C9776D384C1FF7C3BF9D438A460C56C2EBE4E10EAC6065F66837DEC3C48230444D9211162ED2E751974C963A86C6515F063510428185B1450298FF7007E448D8268DE284C65E1547D4F68C31370BA1123ABA5E3A6E86E57130068743001990221B4B48C8EE08E6383359A5E6CF9823AFCBF0A5E091B9E999855802C5018F40056815A7D1A134670CF2C6E0D323752F082D33264334B881C78DE32FFE9CBBB48FF25B9373F0B345092F87E6C55C39FC38C21854000B233F8532E294420C1E81ED4DB95B874803E64731E08327F1EB98F02B916384825B964909ABB6031B8632DB4FBC57AFF84D085D27F06B8FF4684FF4D9D54B4DE7908E0A60ED0704F193F402708BE33DB90DC79D361B3E05DCACF6BD0647CAB32A97F4C5AE2FF307414FFC383FB037CDD9EF3AD92112F15C20D20FD302AB52ABFEA0506BA51481FC0C64108D396C98C803E51D45FDF871C72B9CE3B0BEB5672AABB02C2D188BEF82BA1230235808C740F82BB985343074A0B7EC7430B40B50CB4E451F288DF9CC1803390CFCA89C78A78EA8A330779851CDB36D533AA3387815A25FFE3C0118611408398653DACB1BBD4BC285479E0F0F7D12E40E902DB47E8EECD8B0D33187645CB3C0D2637281470181FDA0AA915FD1833C90F01D072E2A00BA45B1ACEF41424EB060A0F845EE8900E0DC31FDFF0966050124655280FA28827F176158BF83C2474EDE03BD5102C847D19C605F008000CEA36D2252857657076F93674309338BEC5FD25DCCE3E964A3432DB92C1E91BF883E3CF419C3C4084CE125C6F8C24067162A8ADECDB3C0844F88405BF18D88032C9E64083FF077C'
	$sHexData &= '3B2DBE7BE08AC3B8D29E1E8BC312DBEDAA3605B0140181E32823C0F083B7F76A81FB13BA4C0F94C1398805415530C17D50880D3C0A51CCFF10848C0CE8E8800F90CBE8E883C10AD617805FAA09775E4863C1F67E36EB07EF5E8C823082B203CAFFE1ECF33D9E9CCC5E2B3E0F6BE31B3F4E4E4E464B83BBE3CF7B3F4F0B4066901EB41606260E9EA7F93C06FE81F6EEE61815C679DE5F1DFEE1CA375E5FEC803DDFF974888370B67BBE0DD3A697ED6A598C002E9A533215D1745AE1A54EA446D32DF3DCAC34ADA555CF24F0C085F668C2390979FFD0DCFD19F0EC8EC303FFD640715E76E8A5D6B4B315398C9207063F2073297845047438642C2FDE6984CE200E2DF21C087B700E2C254D2C2B340205558C0B24905F3C0370223A56B9AB8443296945174B8DB90098E0954D19497FD8C24D27581F1C9041C16215B26AE814C900F08CB60BF5030345070F581145F70C48104A7C03D80E4D073A70A4EFACF897408930448D4604DA15CDA2F7C9C8CD1BD577E7D7D374BCD8E77383C3B2FB670093974FC3D47B6C869FCA6B3628993B4F10D0460F3C95A7F23C3D8634BD2BCFF3A93CEC22233D195ACE53792A108107A883766883511F5F19908233427ED7C7480B3919B7C7042CEF862BC9AC76B7969C7D1B797707754F109006FA716E55CFD139C9A946D97E55463260AE278010FC1AE448DE7651A475B7A6EFD7460EC8ABF231CC8AE74A8EE479D70FF79E9303B99E7807F7AE9223793F274AC5C20B435A32E0B3CB89246E7680849EE7795E7706896E655C530A9CE7794A4138BF1178322E187020E1B56EC151DEE904FA0CD8BD9DF56EF28D45FF3CED777D22C11B687E7B59404C08480F2920EDFE1B7728359589506EC00F5BC040225E07C5DAB6F01B1459C67E30F24472B04AE20F2CF01EC7331C7D0EA49D302EC3040F2817E0B3C4BAD542C045027904320E891FFCD2EB0A443BF10AD60F4FD1AA48B3699AFF2C054032FFEB0940FEF94881133FD740345ADBEB083886E3594BED4FD90ACB7D46C59E8581238A58331ACFAC0496F6110ECAAFF4430323DFD1181F8BF150377D0140F9C1EE18C194C1EF084E9FEB1345788D4080A81394587E680F1D7D402518F60D2AF63E18FCE006A25E357488CEE32A2FF9DE395CE815684131111B1E481BF82EC3F92E15FEE01B4CD217D085EDB8C9EB0B413BC3D314EC8DCD41E8C86CFF17F0C5B9360E30F8BF301EF885D2E67A5AFB17132AD028DAD80E1E06066A7650861EC930C387D060681F5D48294082C15A5F6BC199F8A81893964D199ED063F0065C2C0AF0C5F58D484EC0FADED0B4C10A6EB94F8C1AD80ECFD5FD3DB3DB41C74614018027C8990F4ED882FB29B449262007C91CBC013819AD69304758470540B89341EF8C4833F'
	$sHexData &= 'E32C67E32F91D180978280CBEEA414FE87012E9448BEDB4E1BB2DEC7E218B511C227E1AED4443F3B608081CAF08F902360B10A9F8C2064DE2A9D1139FB448B44B6DC6F620891132602611F632D014AC4404E00C044F9DA80C4069C5860756D3FF43648774840EA0FC6001477E0426B0C3F0B545505829E088449A6D0371C4036C16512B0814AA2449DE07042A01182DC01C0C17A050051456C20291B9BF607BD5BEC849BD254992240542F2D0E02362F7E91AC1FB045AB25B0BA0680403D8A02238F053281C679EC815402A15BCF39C0F3E12352EE7F2B4ECA5D4372BCE9F98FAC291A1ED34D0197BCE4CEFE062FE02F2FD4D85E47414BEDA3782428B0C2E27E14DD4067CB2085C2E0C41729E09FEB71514442E08992BC2D1F803C83811F88BD1260759F06F188B299137C9B123E31C587133777248336D9A546C545A82FF6903D3323A49FFC44983C538A58F82309C48B859B34C3B50F4FAA5E2B47AF2EB2826A5140339AC0B08CAE492CA4949412421A9DB1C99154C3B0F4208859A4C44C749439E1C0879764A6F28B52784FA29C01227503D0D230F0C01B571E8D103ABD7C4BF537274F6E8C1BDACD6C6C2B09D6CD67968FEF216B3A0114EEC009BF14DEC66157C90F5024533E43064FFE1E816BD4DA0B310B1F2207AF0CAB1354BB0379C27C9FB410E8A35396610742960906328F568624610A73605DC124F4CB3FA0CF33C180E9B184F5C13A669EFA4F21DDEF0255848D84B79602E9554284C245E360659F009418B571026E8262E724873ED3E3714CC029087341318B0CE350939A4391C949A9990439A207866649A0939A45C324840D21CC843F6344C2421CD841CBA500833F230C8864DBA494D57BC2F49494849345D0B43B5C5888110AB824F7C838AC9015B4EC93390050F92271724752545357072A3339005A7749538EE275FC820BA46BF0CFD664D28B16090AB644A4895EF5B06396F58805590AFE42A19903B783D274D0730C66747274B86EB90C728FBF870009591D82020C321B94C32F0D008BC4B15AECFFB52F9F945A9D6B5BD15A027F75CD382773D5AB8F54DC06EF523818C6328ED38123B908DAFC9D71AE3E8B0E5AFAF42625B5DBF054FD7BC191919690C50515253405A1DC47F46E2BC89ED28063081CCD2262C7A81BCBF25374313189F2845D2805C3218199AC0198D2DE4AC4F69A5F1A4BA385B0B81269D22AE655FC2131448EED8C081FB47BE4B63E9D70533DB48391D52D61C750B56687675BF320539208FD4E09A501A0C1469CE0B9E8911C403AC024D8D0C7B002F3E33F70DD41E0CADABA04800EB02521CD63B206CFFCA4923FE75E4FD86EE14D0E277830C206CFFA316FFC3483B1DDDD5227293520904387F405006B2435848F7ACFAD2EF103F833D'
	$sHexData &= '1CAD080E21EC88BBAE0312BDEB7F5DFA43E809B953F41D36C8843B78DF3D02187746311ED79EF97C793D439018CA0062EC15BD23EBD5C0B9EB36E5D2C5803C2AA7203FB24B18293C4303FE052CC2EA102EA8D94D585B1FC95E1BB8095989CE8002C0204D582639DC0870113B1E0A8F208C837A8875276090A7EA4533F694714131F0E802F3107C2B0BC73685269A0427612AA98D170F71E460E71C2F388023C6DDC95EE1FE7B48BAA2E193F0705466609D0B5008BBA506D3F58D7C1F3008EFB71250084D0F43F895EED2F6004CF2790441225C115D9BE8D8B6628BE02CE3BBC4D6F192D1EC02D86047E6EC1D286AC4A97AFB0FB70BC04A1A0467FC8E8DD25B024AC6493BF475E6AE2F19E0A538317E3261F48406AC20BC9799902BA070C024B04595E480025FD40CCC3E0AFEDE22D61FCE0B7121865F55639323239768982864AA43523C19E0453E37846FC0855D3EF490CE40A55A8410DF499D522183DC9009454EA68380808BF072E38E480EB68D1CC816AFAC08C5D92F667AA602E622286C67083C97494ED8B80000D28C348331D025B00A582CE4E88D6BF40A78E07CEACA3BFB50506EAFB0872A10C30F842934ECB1202BDF225DA1D6C20E03875BEB66540873E371EA6808F8F05A8C5692B01DA11C7D6363402A847B7F58F84546C23C42874B26D427F180433BDFDB58001FED689C1C09EF85BFFA453834593995302029203B8DC2A3E3327016F0C245A3B1683490A7213E20847005881D723B4F918B9A38DE2C51DFA67361DA8E1F8F387A61212A4835E1504E55E148387F7D1F8770204CE1CF102B78F27F1AA52A0DF24A3CD0E8E0801C47862A72482B4A3AD4365C6AC26FE95B1CBB956E351C4491024459CE8D5436129E2E63511C6EA39046972E3312402BE4922F235F180CB497DC309AABDEEAB0953D0D80278D916589540C7CA8FC49179698A0FF15A91B18A6E4C5696EEF1B705838E454B3B5EF1DC61A7420852280980DEB4A2BC427DF901F38F2AD709001054840407E5D20BC05A6564981A7FD5033F622EC42100A0A0F05A51248BB9BA0F087C35240742049B9A0D06EA3A104B6041190D841C1D0A4967CFF8676040A509CED0792DB2967E5474224C893221A1E34B97C1FD812CA3E2F4076C7378C7C75E982FC80A5B400B35D5A78F8E4F8B958FBC21B90899535685961735FD4951141B90FBB04798D6A9A90024675192A063C42283D2860EE3A61966F4C11F06670B5D341F08CB9431428010D67A2C1F0921B417409BFD11BF28A0F1B9268411A4BE9A0705BF2A5ED72A492802F3A8027831C9AD68BFB2B187197925C8D1793808CA02F99CBC0907D746215BE5F1D33274E5CD0406BD5A243829E4E13C16120B4F1F6027F233971108295F5A03D28CB05DFDF76F'
	$sHexData &= '614FF1F33C9848B189C4D89BB100C45322C38A1F7E44588A3211E0B0127C2201DFFAA8451095F58492A4175A67C025F1A015CE40C824CB4E2D868960CA4F9C870571D5A45447505E9E14B170EF8C88D8C248C268902A37B13FE2B300F4642C53B9C4524BCB3A00DDB03A023EE17320B706EBF11306BE0AA991593F0053DC7BF176A6D2EE8C94B40BB0CD89442DE157D627B0FA18B8C2DE52E78AC0C2535F17E3E609950940C2C852FB3DD85B5F5D800A540BE14DAB73C3830DE332BC60CBCE01C6C770FB2015BA87BDF8314D6B4F9CC0569B4B52CEDF57040A87CCBB66B702060AFA73DDCDA253571B3403D3A1703C8846481E3418D3CBC7A14877B1815AFC6C0DF23476DD9E92C97F57060A8ED3AC1BE8DB4D7F3B20A076FA113AE13FDDB66F7ABB8549702FC3C4C567F8C619512DA0F713823747701D04C2ECF4DFAF0E3681DA8C104F8DF66833F7C7F53B86D2D90965AC7024834EC49C7C0ACAD81C6264CFE1E0C9C0C52D96994F040F8E8188805B8C7D4CF4964BDC16C130CFDEDC94643F403165FEA077735032B1CBC4BB49304B8D1427D8C1C76FD20ADEB1D3C85492B48D1FF5C13AB0B01EBEEC4B572B2C34612FFC76DBE6FC84AC26072B8BDD824BA3E00309622DAC70D6619F0DAFA46359BA1C8A3CCB000A3DDE6A7C10C7843B84983FE214C9E2A1752D0AF4B4236B80950420225381B463E3DA2AE16338AE80000CC81904D231E0A7E3A798688806732448BE80E7D640950DF750D3C0D984D88FBCA32D5100ED93E8858D709BCAE15B843C8204FD000B808C9E5402EF09C761DDD2E3A93FC8C8510273C3D60EA228717B190E622FA865EE1133D5D1071DD44BE9F447014DEE4DE84E7EE9A25B6955E4CD60F9D5EADD0C023702DD13B3490D9F525940A91BE808DBE064F07D597E0354CC838F1D888446D4C642B03341007DE7FC777D0BA40B7014088BC3FF0F09968A0E74847103BABC2A5FC11A0F214BC0A3407355611663F87F1886699EC5D6614DF051F93153D88C55464760FA885AC908D5A791C7977F10200C7A114989CE7C6BE1AAFB2505F4F547368F43EC51F0DCA0D44A8C6F70361F4017915F97AC6EB8F40841EF290DA901649D6270F8B0E9D66C47B2E60A1981E6BC0A1DDE518945E3933F6B0BE68107CA554D488412D2B3E7C34047194FF893DD5854C497B915B552F391E13F86B8BC704C800B20001E8961A10E4BA120FA4864CC09636956F70201105D199702A4EF701BB5C19480C384803F3988DD20EDB20055758323E054551F19053CC11EB116F0B5FD8851A740EBE098CC529DB87570A586563D25C1EFE50384085F49278A6E7907F95AB2456FFB08B97731287600005FE26509891432E50504C1DD012373D8B940E0EDC3A70120BB30DE33E898508'
	$sHexData &= '791F42086B249FDD206C65610133550BE904C819EF2C0C47104087B126FF7F1FC64A1E17107B9CC6110369300B1AA3A04E5998AFE2203F7B0DDA4C5424283979917D6E7BFB9B8F5C35AAC085F61FDCCED023DBA34088101C27FE407C39418BFFDFCF2436B0862D1B086217E4E33FC783FF7B84C0D24CA87BC6AC4D70893F4053AB31D370438BD0A531F21B6010686024C23950A83439710F42C11CC13D6B4C63B888E0439D7B661D268807771C3780D7C4C6DA3C12742BBC5B051B933C50EB06118EE100BC59B9C808E6DA204790007CBF48566F79741C4A902C4F2F5864989738BA0A5118EF2BC5B791A97D3E39F2B6650A900035592DB40C79798CED2535B7588C004778506F95EB537979598CB0E50905299800EEB43352140A5BCF09D373F918059C18B120C20C7D94313A2D00B13BD7879C88B16BB190009020143C9000A109B7339EE0A8A9831700742D939B8133C349784E71186C578521042C16C85C0A0D38188591A99D8AC137A0C9EB5A797D09118E6446E368504111BDE4547D0C576571E4F350605A85B73B0DB94A067021D46AE565D7120B090FE40BFCDBBD0433A001B0010910692A30384F7248AE01FFA8CE2A462ACAE55858585492037248A2083308C844251908BF008BD3B207C384A618F254AE93A7F9A44ED461BD9E30C3C03B5ACF8E1EBE4A60B8B74B06927AE521E705680133DB100EC0CA79EE75F975AAB2CA94BDE66444203B058BDCAAA8DDAF9DAA0C30200DEABBFB6C84F283D0D5BB15B60C218D38E28BC3BECE1274F2CEE01408E3EC2C100AD59ED23D1A58D482012DED522F96064942C256C8616D4DA52A020318844A01A55D49D329C17C133E0326661E540BCD2F4C96F0DCB7C84B20859A0237A5C0FBEB4572627022E0800C7E47E6581F30DA84ECBCB23C8F1EB2128A6105C504CFD722C08D01FB12C7A8C81C5D1C9E026B4A95469C6B0907B36025AF8A3BA0002A92D6695F9F40AA03C45F42AB8D51157FA59938317F68A1AAF033406BC2976BE11F11850B8891A11F04B860834A48CF0345DF8625D1BBC9A282DFF465D77CCC0CC403F413D9396003440A9E7DCF4DD1431E6D0955CF0610BB45CF04F78A76E408BBA309BA708A3B3567B9203CB21B9B82A03E2AEABA8D5708E63FD9202AD3BA8BDF48393D3CB9795676E37166902829B90AB9C78041B808C7230A9A177265BACBB89199C37F137243BA3B1E751FC64618001FCEA300F0EC025B5002BC2C580ECE236277B858B8B9487E804B8D1430489DC28FFCC94823CA0CC80F10718E909E48CEA1018B67024DAF4D7979F021C3A2E01CE8B7C9B7DA5327001CC82F4DE7A16EE21CBD4320EA0753B61DDAB84B30B64D17D41576F09FEEAE4B57CF9100CB034E8DA3EB56C104321152E595AED'
	$sHexData &= 'F6645017338498D50AD91B5A4D260FF0760855486EB558F9FC9010FBE4EC84455B79D58CAB6F35ED93EFFC0120DB03BC8770C34EABBBB68E50D9F8D79DC233D9C15893D950DF5715ABB0F44F960CF30416C1C1D57DA03ED9268833C035E1CF77B1CD6B9380F0D5077040B44061C3C9C45920300E7D41A0CE60D9345079A88101F3CD3609C11D02C2B052D141809700CE51EFFB9AAD090E7FF047DBE76348801BC36CE45AF46109B8F491FA31A00197EFF031A404939E4EF887E1837FEFF0362E415433BD94D1F59F000B48AA13F410F2873F0631C4F420A3FAD87FA78416195208D345007060B324FBDB9001720BF56B7D01EE03919C71018AE478CE301BE4137CBF1A7F7B895361716FDB60575EFFDF0FE033EF27C04A78CFE03F7E74C8BC6F94CF279E73CB6E734B67D7A741EA6AC48D48BB4B96C510E68D10CA519D2E4AB2AE5014CD54923C80F97866714030E4210044A5E3EA73293A7CB1EB4FFB31922394049FFCBE790011F2FACB3562507C88DB34C5B4E5A8906910F072692E7BAAA8EBF3997713801549DF9F6974C06A74C8D4DAF3E84CF1772908307B3EDB2DC15F2F290B2D9B2D2B279C809E4A5B28DB282B264904B0EFF1F2F2897BC1C69B26AB217E4AA142714AC8DFF0A37C8ABF300E97B804486E292D6037F107BBDD51A34C7E56ADD39D57A118400C3A6B127E4C90197B11EB305B3A17985219C6DB172B2B20A061E9E59B13AB1F3424E0195B2FBB0E714E0ABCF40FB7BA4FA4606E4007437D028253E027830095D5F2323EF5E05F7960CF8F9FA8A82E822CFC3FF1C9013F282B069B0BAB040564ED279A1B082B076101509B01006F3AF6149F34241B08F84CB54687FE0AFD880979B3F20E586C3DC3005F46845EF943D4DB11A76D607BE7DB7AD90F9EF060C88732CF96EF8360D700178BAEF5EAFE72F9B43EF56AFAC74488B58010ABCCA95AF760C4126928F90A3BD1A498BC6B70093355AC1C103865B18A6367EE85B3AC3FF534D073BBE1C3C1064152F0C0E05EFAE3735E061A20B1AD807BC0B155552AABF12B1DA9D910F07265B2533E80AB5281700422269C028248F663303446C27D7E04CD93CE4C95BAE41AEDE4C30AE79E5E7E6591D2DAE1D26AED948FFCBF995477EC3488D3415F9AD1600751FB930BCBB6F0C90DE35890C064AD38D18EBE1D01638DC32AF347C6D047208D7E9F1F0C14007E302DB4A1DF060F2E85506A2AD5DA3C80BF9740C7A44AD2BADE9778121888A39357B1E767C66D7E12EAF7F61AD420CCEBF8F982E116083B1ACA6E03924FFAC8DC8374156799E7755D24219C92FE809E1079ED587117FFA00AD1C9031AFF603D513F678C9B73D1D893D90F4F517A785075FC70B2098AD259501E01FAC9A0C8CCB5608091CCB1E11545A6BB6'
	$sHexData &= '3F3F03F58358345128CF0F6044208E1C908B4A02F35D883814BEC74328C95850655D945BE392D7500BDFCAE3C401AB60BF40403A21E4F78498766267E2F23950A0D641ACE754AC7C70A884F4A720F479D9CCA24C42B8AA0C15991DB2C7BD5EF14D0354ED4D3BCBF1AFA24D9A39E4590090C57402C9B0A13226CB510BDA0D88D68025281A043B8BC330FA8252143B531075292138B7B4A968C13F3F3904B5B4108220D647078526A075B0EB5238498C0078F07D4BF021A8CD828DA45D76EAFC4D3816490E340AAA2093906E42D0954AD3A5F5C04D4D594B3D8C009120C2E4ECB1D4B5132E103EF4E42F74855ED24C3A93C0009E1A2A5538351DC015D5A520ADD6B8ABC00530AF4E8B8504029A4E06A78054529DC3D3CBE4843CD90657A93DA92CA9C491AC1C29A922A93C933C95E72F0DF5A80F30DDC1597995A80F14D28B0C1F42785CEB0121E25D0823E81060280C70B03CB8B7104920DAB45A42B5A81A4BFFBA9EABC3F86476533E6753E95B7EFFA4441582D76CE5002E48056DC9D0A9E0EFFDDE1E756BE801806A351D5BA8EBA3B7F78DDDC650A577B21531F26E032FA7BD95F15E089F056CC4287148D1B43A7BDFC007885DFFA70661A6426590E085492E366C7E05E8F802CC2E74D048F49AA753B00306188714F1C9B0DD4DA495F08D8570762500FCA0E502F72CBB70AEA77A13A85077A2F0E5390CD1C6025BB2EB8B30028C00436F2E844FE5BD64E28210F038F89DF7193ACC71E806F009809280206A8F04B6A77EE8451047F83D36194A9A028566A2E0E07B9E777777324608D6D563176028F36096FC8E4574C3ABB803E838823330580A9E6B903D703065DF3FF04E29C0F3A3EF290AAAA6B9E4FB81778FDC9055147897CC60408B5090EB40261089F323B942097F40B864218460E8B07CDA2260E569D64202B482EC2CF844DCD9A53C73CE1053EF34089693EFEEB690036A60A2B8059530CE145C150478F4EE848C0820BEDF48CC743D49BAABAA012A355B08F082FF8A5120514917F442ACC248F7EA72025CF59A34032E097875F863052AF2E9B11D5A4C16735D4F3089A53F05426BA47650501074B780B7B533FE3A047A080610BB99C2C0934243CB43027AAD91BD3B047B247BA0B37093020E18EB0C79C9933C50163A028CD69FEE03615442383D53A751A7868B1A40C0031854FFBE2FE28A827F60A93EDC03895B08F446A4DD9C2646209D361EED4CDD47123D3D10AF0D3B18EF65D31294D5ED1D7D617E139B70AC636D1F3D6E406CE2CC0D6F538933BBDD5620B55B456402DEE5B14AF04A2CD19E3A36F1EC47C06B01750EEE60214E5A30465F1AFDA399034EE5C1B66C32A1A313FA03F6385D7C18EEA9B6496A1CDDC75F745102BF4C3A6037B82BD2713A2F585FF61'
	$sHexData &= '0E9902F12129C5248C1E203AE965F79498B484C2BC1498D4072C1E4DDEB366505019A0C02E0830965035B4012A4001A165F68D0908990FF101800F9056B3D488B575B3CEF1189555F18062028E63E0E289FF200132A406FC8CE40081CF1D184F7E11AA41A24480C2181C208DF563BD975ECBA9A7A4D008D25BD861A0AFFA25B1F80792100741250D7C0072F016CD1971BA0A7CAB30BFF10FC0664A0131F1C03708C8510C70B7503500A18FB9F0C3821BC06104F507BB901B106102218BC7FD31C860A1C1C0FB642208841200C2101BB24D121D4881283D747B31F11B8E8B83A0385F5FA084D2BC249DAB83412A22611A0C8A0DF5FC62F70F7F1073BC226D03352137188C9C01C5C95764BFFD63F8D42038038FF720E2A4903BA45B430E1F0E522631DD2DF0F2F17198745A80DE07E775E0B8525B336C3C4468788B0BD34DC7D345EEB6E5C91882F4521375022883EC0FB031122BDA537305C34275D46686C40283486A4536B624EA088B3459E4A5CEE03B46D98AE03F06445A06D88F9F806D6E760219855304AF8A8FC4558A93A26F854D2BA8B6BF18D78E26049FA3EC645810144EBB227697CD278108C442AD68AD5C27C9252206E5580218115D7070474250F99DD5322E303141C463E628F5F5BD75B8B769DC646284E9BBFE976BF89060F68460849894E104518457410DD371C458856204A96150388D60212F19132237E28C72B41745D00333D0878430B5F2F5CC3936AC048C2989330F76AF89237939B0F8631A386CE22E00AED17216E661239E42A4E818B8B8FE6308808910E0F4A874E0AF6D0C8702AD6008A24399105434BB83FFE1EC076A4B8F5107578A06FB62FB694BB828D4E024A6BE641887628740E0104ED13EC10C446050244B0C26CEE1F51BC3CB98F34C0E53312B8E444280699CECEA12A307359EB3FFB5F167F0CEC4C63F8150D3C8BD845FE736AF385FF0F8EC1FFA40F4181FF007DE8226DF7A48F1981FB177850F1D469189E0E2BBE9BC4BF628280500FBAE012720C3DA2FB53C2D20C0075050D0122D0BEE1DE68507D70895D74724561EC30F1D0111FCE9177819C68FCEB9DBDF38A60B883A48D12EACCAFB9803508981866966E0E0A5601CC20248BC30F076FE80EC7BAE04D8BC4BAB8C2B104C0BC897C1558D86BE8759A2BBE5EF4EC28378209409616C80EF85A7B9E101018A22F046FB06F10A8F15439D2B84044C84720A70AB0E569E985DFC0BC7E180080493BC49323171FCABF0594D828EA8A3F080DEF5500B71C9003E83A270290E858D4AA00DE383FD8A258E31DF42775BFA6486345E0FB4C8B65E846C55878381018F7EB571AF7496690336CF67E4A458BFDB3DFB647BF1004BC06C841C1E918410C0A7824FD4D10D0C1EA084D63D75A4A8D44C6'
	$sHexData &= 'FF20F602769C890341FFC788BB27B51B7AFE7CCC5EFE69A54C031AF88EF4E14503EFB726759E390D223845F6BFC8E8D0B64F0F807C38745E4645100655BE820AAB837CA93BC0C18105158DEC8537965C8E246E7A54D841965FC1F69FECC6401B27301E2BCEF86E87E4DA7638E9FCE44989076D0DC7DA925F10C38C2B046B08F4308FEE06101CAE4320190657F050A4B858CE60722036B22684690A2462D288482C4E8327B7D87410AD48FE61817023D3C643216829002F61182625F08AF24558A11595518308133E5C1C269230CEAE1C0F4EB8132C9E0C9A0AD902D3F30E1810E7242041797F709E0C240F418846200E29213A8FEE21E68907473B7F858141631F498B074929A2D1A4720C0A44EB9C8AA2A12DE19FE5F04AC0E2AA1AC02460C4A01837B3E4A9426830D902E50352418D6449F6E055608CE4903F963018A5BF02E229BAC71041C33F0A6900ACDE23A96C8C0FA8A8FD631803880693CDFF0F2970A80F297898CC6C2EE0A8EDAFFAF144894D680CE04449C4C5B886C6F98190AB92FAD43D308B5218CE22180125B532451CEC9443491D7640492B70D8A04AD6240448AC22042B021F02490944887F0C48D306F8D1ED4585E42610E9C992749BF04181FC9719F985FEBAD8A8DF4D184D29D149DCDB976EFFB815AE47E17A140849F7E21C2B04D1E8EFF58754CC080641BB37493BC34C8FD12D34D8284D4FC425F44AE89B48BFDD48BECD644C807F41BEB979379EDF437EBB1AAA7E8100CFA6AFCE16448101C9801CD218C80203DAB42DA9C3E0060CD3EA02373B09D5D84AAA0C3CD94D036F692DC0C34D3E72AA55448B75686AE27142778DE08BD09CD0361783F1D3099D675226F0898377903FA15968DDDF0309E017E472EDBC62BB5518B264906D452A551856B5DF7B90439AB7361C99670772483BD4347E44D6370EF0346390E0305638940A4B38C24E043C21F3C1EC8D6876A131D161BC8586E89AB8397D221CBD84DEEE57CC45984C3B8560390F420F012CEFF99631394C30E8BCC8EB4F2A6A1012486A00874EA94D2015691AC81C30026B1018726490A6201010C7C7A053814CCFC6472F44284F694889071D4FBD7681B110EFC470C647E04FBEF001BB84885720642481C6300E70C05BC1DC781800CF9054362018C7016E55D55E79FD9221E9D0343820178A21A741E0DCCD03E32214E718E0A7629FAF893A60FF030DE0334AF41C52A1940DDCF1739A1832FFB18DFDC25FE6F7684FDDE3781992DC3D25D1C2492F8D85CA1E0D56BEBEC8FD45780C2445C8D633CE13482867E653643464A3E24D03E11DF00CDB8BF0773E589DF2ED64A185416CBDDB8DB001A9C6D90B95B402F0C616729502954F2178E06E2B16AF07C903B44739231142407145E0095F82E2C7594'
	$sHexData &= 'D37545C16588219301092DE5505043F05594508461AEC07FC4845397D1CC6CA9A412286B8D5D01FDDA6F8894D08103D4237043F1568522332A2E294181BD4E806D25F625EAC03C77A83755966492AA414888BF26BA5B5D23E8BDA428BFA899E3C4A47CA20CA27BC565373691EF6F72AC2D85A0C8CC994D4699D838543337AB65CD9552D622FEAD8BAD832433B0B94D663EB3445424FD11B4A6B4B2B153BF91AD25A5899C10F18526935ED2532D9C924D9CFDD837FD28BCEC1E1083E0BC80E7511C38BF176FC0E41890C24A04983C40415D47051B0443B2A8CEA4E6AC092BC9AB10936C04347C1C17514FC9A1045AA9E029F43BF7F4F3CDF6424409C688F05E8FD8BB58955F0E8752C7F95D5DDE0892F749E39F2CBA0E2FA1A906807C873D0C0C0D604CC6966DBA9DA1C75D2509C989AE6CD06D081B8E6B8CEC91C994A7A8B8C24F8C817E02DE0A56B25C3BEA0DE1DD8BA02257B28670A324894B9D3F0B08EBC28AFE937C2E09BCC305505DDA4B3258755CC4A8F50DD709ACBF6D112EEDCCBE408F2880AC35FDB4F9B001E6BC60620E99A62D7EF830F91B8D7A5C00DB5C453819BAA34D0579553AF3C9243F04EDCFDCD4151DC20BF9683EFDB7AE5DBC829E444CC3BCC36A54ACB16308EDAABF40F477B401B50C645617A6558166E386D06755CEA34884560A4F9ABA4988EC44C63F04D8BC6A0C0D2FC66D840483BC37430407967CA8EAA16FC0E4834C8A1E71050029FC84995EEEB031E9EA0B0A599E45199D95040F9F0ACCFC6CEE8AFEA59DA2C575A85298C40DAD9205F3DB2DA50134DC814457288AA7001C0D8084AF41C6D6D3BA35DA9924AC4404D63E49868EAA24A3F8FCF7FC8D8746864874BE9D8E095EE3CFA4EEAB35233F66A7E46458BF5074FC955BFB74963FEA6405205F84AB704BBDEC6FFD8107FA37CCF8E994C03F94403EAC301BE4AB94875A209D1C33AD7C43ED82A89B7EBE16AC889111DC0903CE9D8F050704EFAA60E462C7BF1799985AF47BEF6BF0610517969D2F647300A7D6684491BB45D7070940A13D923995CE66088481FF8A40FD349F748B6CF5B18E4F9F74761503448305CA966B7004AD3A4F4502056CE2423F1FD404848485601435E50483475504F5A2E0D114646F748F2E9A461F561300B9430B94A5D1EA2350BE9293B4F6864733426B809D8C02A4D1EB252A6D79BD7174D3215AD490B9063924714411FD675D709A7752133433E3AC90992F52DD370D203F5D0072AC6EB079213F95341E0E0DF0F28B4240003925D94F9BC24F0A21803E8EA02B07FD92B8191625000509B3C596498502CB05D1748220EF0A4B198B75016E31F38088851286ED5BBE09DB88A8CF7BA203986CD84A8FA771FD5B74C6375FB2CFF90457AF6AD561E85FF0F4181FEDD'
	$sHexData &= '9AA7D2B61881FF175B165C2163769F5F45D6919F9E014F40B8847A2285687AF8523CE7E8EF1CF334DA24454497451C0181CA663D574BE0AFD51847FB34A83C846E0341360131A677D1C18395BF9ECFD25078F3CC45DFAAD7DB4D8BFE57E91738FD86E74D0FAFE6495CE1F505752E47DE7635B497FCD4034A981C2D0C66BFE801BC3571CB0201C00323FA751E800266DFE25A058F440194BFC00EDBDB3F70DE4E080EC774CF4D892E046E0873E08A7A061023678F0093472165D300A7503E5FBF25D4D68B57F334569F40A770D5052FCA0C7CE3001E30253F459EFF1880FF726141478B04B45FFFC4C887BF4A8D3C07BCFFC64C3BC75305C2F67C66FE328C4602FF80A7E24403E8E0695874BB01DD759EAD48D0C780866DC898D3745DC78EC32084421A56BF017EC950E762C9884DDFDBA4015A85DE16045ECBCF5C0AF0B135CAD7DB149706F8884EC3E0E0ED0BFAF843EB20B101EBA72FEBC39BD89E37042F11170C90CB353F5000F833CB181E750F1101C641140A687C5B539F03C269057017700118E4E05970FCFBB884953A5108BF492B112047CB9C42D9C8B08797D0AD2796C6A800D525B86F2AE8288F0C8821F4E5CE2147062E2B3C91CF0BB86CBD792303FD34488B535310741AA5E14E692102F2114AEA14AE88F043AA0D4447E100A17F876079E98A4D875D360CD22F6D9FF2AA0D4C58FB0C59853796087C70DCDFC4B8A1BF05F8560FE836762E33C92ECEAC0D77CCC6E6C78205A1CB9D3D163122360AFADE8316AD24B7817705D2172A9E93E7E42ECE30C230BECB3B794E38B238C066EEA995917809DCCA7CB5129C8546155B61A214C6F09AFDA9FE836A149EAB4D8B40F8492BC013A773408FCF1014261906594058300B138C3F20BF0D24F9307096C05785A1268E38630EC5BCC10A1843A3A6FD41089E83ACCDBE89C10CAC8FC0F3D9B960346822D2C9CCCC80B6C0A3BF3BDADC4C4D2B2F5CA3928411302E8108CA9CE4E524A4C9458239824E7292933582298225825939C9491982CD80DFC90E76E1264316D40C5B77D060199E2C448CF8B3C1A4C5057CDB5754892D7945C549EACD5B481426EA4F410D61B97770FFEF61E2219CD97BF285C97E157C09A754FF56D82C844C31DF37C0E09C2085A6242BC1890E1E2C8914F127E2172BCAE7608908F890C06255B28906896F44C03C34DFCB49EB427516DD87B47F2D024189002EC72AB94C0C2ACD4EA522B54D7018A84E53A5D254079B4F039C8990BC4B8E4CEA0159C001933F6C0A69B6B029FB5534560727C087E938AC8F4C6841F5456C3C30448596933A4D14E1BCC92165F18CB816A03C812AE03C28A14B01371CEC4F1AD29B1DF508722BFE6006FE3C4470B3D1FF2BC3EB48751133F633DBA7D0CA8D4E019566934'
	$sHexData &= '7E9C0CAF818B34EA652692AD8A64FF8C78EAD9D999CC0F5303E42AAAD02FE5403ABDC66F675276F845884081210751D85EDDBA7A3D375193F20EA548931045D0059C65D68061250DD584185682F860E82468D1C3B9EFF9245D6BEFFED0F47FE1A1426448D042B458D343738770334C11E22B6DFFE4AFF443BD67D0516CEEB07453BD1504ECADA4F53745144DC3849DB7C0A2ED9ADA06B78CB8AD9C98BA0C02CF05DB09937443BF241BC043E07020D0C7F4AF439C07D075E1353A5C1D96946C1177561872CE6589E4A27221E6283CBD31458689001453A83C133783B9B3F6A966BFE37704B9C1845892145897D00CD5F9E4AA50BC1130E090E777781FB2EDBB785E7F2849142FF0F41FB4AC146E98EE6E0440F4FE0AEF4F34AC10623068930F0FBC880349BF84FF8DF09C12702D5D686EF3BE87D0436C3D7417BEB053BE938CD73B190810E7B333C4239017D0A08067DB5220B29AF0FE0204613DDFFA60A6946E11488A870E4087E604C5227120D5AD1B8E104F8C6DE7726F0516168DB381D72C98907B67D487456AEDA734CA0B2BA98C2F87641B9BCEF7269D403702FF02476CF4F6702A65DC51914CC0426D2FFD00768D5176865E0FFD64F5CE567AB527912543850A65A029B9630A34201304170D33A1A1FAC96CC228BCD40DABC84955D0BD841DF933454089666E9D30A902BF5CC5C2BD693BC9C1AEFDF93DF93DF0C7672939317F57DC771F3C1263012A5AF28C1D84427001A48382760F7FFD54FEDC669E643954D3B114CCDF1C0F8733BAD7300531320F85FBDA77569EDEB6A34D72AD2F02884C1C0F12000CC2CD4E778EB094634DC0828EED3CE9328BECE219862C8FBCEF780E8D61B921199BD3AEAE84C5E6C0CA191F88616EC2E78DD36803DB57B5CE553A176782DA9D2DB6BB89D7C2E721BAFD2B6290631A2529F34D02EC717A5EBC4636E1D5B19692C283F3F306407887034F14FB78643C34C1B56F9148C24B082230B2FD844DBEC1F1C1808EC96988BD361E2ECA041FDDD9C3E4A00FF4E884628EB7B0B00D22C5D42B085C5ABBF64E260724F68C03EAC59DB472E0C175C566ABF38E3A8975E80942F3DCC78D37ECA4D33DE4B0FB24E0E598CC613190DB3CCC119CF41152A00A5C3248538ECA468700205F81F060185C9781B85D27817428E01697CDEA33B4C7F0D120A307F648A038B31DF20DAE643B1E8EA88E28710C946B7FF478B59184C635218891C2443AA023BC35041F6B7E12A4C6A1C1E293B411C218614E00F349E70927840846604A35F0157F6EB1CBF79DB7E12401A0AADEE2BC3792907A04FC2F8039F2639381AEDE283D0035033A670F339E42A05150B58AFF1F4F244544CFB02C46F4503F04963C4CE8D1C8212FF565550C670819A7370492BD815111043'
	$sHexData &= '3EE003146D2FC4E896C1C1E818C07C497410020856006AD2048C01EE05ED9933C208416E7F630FB73E94DA6B0A350CD23A314A411E10B371B4856C6530B838BDD07F4983C0044C3BCE7C99520844D12F78011F2C4403345A3AE2453BFDC6037E0100E1DC2B3718AF14F3000D202A09AC0129BFEA40639855FF4B964F561C242016E5E0E4D245760317ED10FA51187272550040F8CE1FFA06413BC2315AA37972B16C5D04240BE4D2B4601A2C4BDB80D8040F22256892EEEB202E52912E338416B22BC779DF160AFB2B0A984A3694F8C4C1796EE2B7FFFFC7C5F970C000C4E37D18C001C5FE7F45201EEFC0400FBEC7B172FBDB48146EC8C4E27100C83C7518C94D40383F5B7CCEC5F877A1E4CE458BEAB19211BA9AE90492F5849E7490E87F2AF1E20FE0B09648984CABC5B644203A8681B6E09D062E667E76900EC5D9EFE4370B1EBC0A7E6F14836A7419006F4DFD72D2770278FB18C5F566E0F47D1725079E7238C56E3E35F5EDDB1DBD4E400482DB15B0F7B7EDEF19EDD8CBC5E5D8C21EEBC95ED85540C5DDDFDA690984C3034385353342F885DAAE088D4107902A5DC7FFF67C8B4D0E7D704E8D0C824C2BDA43A00BEF0A429A8F1FA141A24611A35B1D5B287F5DA12F45DB747CAB9F312C9CC0C104D66CB335F07C9B445C067CFFC40C26ECF11D3DEA443B650495E3ACC1F309C7D6E9C773236172497B5D5E419D8E812036186D10EB16A87E9D56ADBA8BD04CCD93771C7CD9A7E880E8806278E689A0181606698808E14628F88614E645223CAAEC5F261E9A093B431C1FCEF53D2A957C7CFF9FF6EB2241BE8E17F071D3A01748A3565B4F65F6C6C67E33D2DAF31410F6E28E6E46C48037F01446B83DCC002BE034885B401E986E059AE654CA2041033B4806763B16262C8828FC0F6FE6D49ABF238C9F3E0FB7CA62F17E4886C3ECFFB4322862D27D487CCE220A46C7A3F64462F30C1F2AF893A0B83FA1C080FB0EC894E6B762F777DFBFD166448500BAFF2E62F2688C6D48DBD974F7D4B1690AD165486C339AC22DDF760E65D8CB86BB7AC7AC75483EC8060588B5FBC4E1FB93D9E935660487C04A0B6EB7D171708C56DF3E859FC0D0740BBA0F951783B8F8D3E24C0BC2E2D1F4407CE658B4A20998F71085C30F393A0D6B9A4136C2C354A14DD714120FC42F8CE5EC5FF80261102C0509730500B5E0AE3AC3E7AB6C4D07E48D1D85321D857F495F804AC3E92C04162C312F9A4EBF301205BF192030CA30C1E0A707AAAB1872C0B1FD66E19B367DBEE7B9194F5E0D6FC4A1F20429747A7A9B74DBDA72D195A4F3DFE9F59CD909418ED0C4E26900D082CAD37B6D18D20144CAC8C1C0B91724780608086BB7E61B3415026C2000DC89E842BB7E834DE0149D674D03D5492BF53F7'
	$sHexData &= 'F2A68F0468B04167F0B66C0FFC67C51F82D04350AE406C02BC15235D1143FC723410CC0AC9ED634C9E8083B7F6B4109D3548DD6341073144FC398E8C34FC2DC7C8FDB8B400E5458D80502FFC25A1C2E2C050B8DB46C69F54FA15486388D6B183B103FE5A403A8C0AE10BB03466826C8233EB6F1AF5F043B420475042A0F9CC0614C78B572DC45894BEF8FE4526DB670382F47059C85205A205AA999647CE2C54C17205CB82DC079EB85F342F8E80188011CCA348AF07743A3A90E4D24A6B3786D87170BD8413940187DEF72181C5710883C1C2C76CB032BEBAE201EA424281397961940B471C4D084A37372331FC84062FB3C97CE5870AE923CEB192692F779CB43223A7507C8111FC4CDC28AAC24D8F284D7ED7AA3EDD3ED674181BC1CF49F8E1DC259B7017EB85CC4B70AA79699BDDB84C56C47E84113C40B16707A2B461CFF638B8BF0FCF7F57683F83247ED592300AEA1FAFDDA86136007C49286891C101C8B34FB6F88FE02E0EB7B458D65FF48A8FCF0B61167B86E8B40ABEB041C24840E383B9502941D165AEF43B132B7930F23D41328A81FB827272727B0C0B8E069556E27C0A938C8411CA5E58791D810636DFD256D9CF8827C00D0819139D374B736DE6D7232483BD082929E60F48A02BC30C6420836C110EB0E0D40BCEC831001858CD7D80D62102333C10B6B091CF68134D86107419F0D8BD106843712A186F194FFC7418F1F42C303DF4AFDA2EA44C5A4B42E08417B704D1C2102D2408D1DFE86893BDFB9EC59D820E1B9A97D807BEC09800C745888830A6E9C34AC71017612485021F42E77B758942FD76CF6BAF570EC728C410E61230F9B00BB4AF8FF00F3A5C1BC90E34801F14C2F377CD1B6E9C28DBA049FE8005D84C93CD6DC48F2F9B52E7B7A9000777FB4997180229F1BDBCB8BE72334E09C9149F7E8DA6063F34C8BC2494C039A0D0E6E60C110C035EADB9A58DA037C72847C996AA45D1385160810E22D04AC4B9C2F1BAC18D959100165F3C7BE5C7801AD7519204353F06D72AA10F56ABAE31ED6F0B27FE2209175A37A202670FEEF9E3B5D67EAA94C69FEE53B4660883B794A389F722832AF2ECF181830E4516C04BC9A12BE04C3188E659CCB163F8B08D3072F6DB97B4C0888C49C30DE2F9C26853AE4FCEB44880BB66816763B8C89797FC2F77774077CE2ACEB050CE12C75EF1D45E709BA8D8B588B3C96C0F180EBDE03D75AB811CB94984C0CC4231E7C5090543E163084AE35C4572B9266E9383506003B0D2A27084DF6F60A4FF38AA078040C500854E9BC02360CF3E258F3283D720E9342184A28BA3C8727F473472D38EB1728BCA273809AA3940C8BE4489E1E7860A678039458A67426FFC3412B8055076C3BD8A78D942457F4DE773BF8254F07D9'
	$sHexData &= 'B172C94747EB128C23B82A7A5BC1E6310471080610774B00134793C75091401EC860017001C3BCB0023FFA0E6A742CFD106E7E2D4C408BAAF0281728F62894014D286106DE4A7CBC04ACFF828B096B993DAC405B73D1694B1276D661457A4C047F70F75A0BBD2870CA40181E6B3EDEF2EF6CD044885C2420740A7F7326605520EFE921B4D34435911C9D52C120C3BF8094802EB9D84C15D2DB5AFB50E033ED1C98102A046A08061047BC27C41073313B71041CFA8653F0F2648BDD2E57D28B4818394AA97CDA7E9DF253825718A4FE68CE326C2A1C234988065210251550E7D03C0217201C0A73DB7933833366C9204A10316A98468639675F010A6106470707F23B043078001505E60D6EE0501C441E162804033ABDB0BDC612201003C3D0713CC1A74755407C4469488A01B5C8A76750CC5691CBD39BA25610744956383C3964909140444850C9AD4B06606CE07D284D26AC4E1274CE944CC9314568509106D332273AE84FDCBFD2F449182B4844D9F0DCFFC63B7704E9126538D028D8314E2F9247699680808B02707C700004CE4104733C95F785AB101838202A4FE5A94028483050487F0070C74908C303580B745F1F06D2C950BF30322790AB6A00C120B200C619304A28668C02004F35B4035F45E6C065BDB8FAFA105D469095064520C4B8EEF3D936A844084098488890783A201F41F80E98688D4F3CC4C6F8C004C8EAAD4DE85F25C0893B7C8BF68975807FB616120EAE038F1FAF032E712427F8F8D49DF03D80057A6D4038353A67A1CF40076E5AAEBE0338DB202B1660AC432815312E6DD901BF38AC243ECEE0C9C06925DA1B7834960F6E16451E099E037341FFD44000705C8FCA38306DCF60024CC0E4216002C630262EF8947905A03CEB0DB313843B51BB89453C1221E066E245544610158F46DDCE4EEA1105960E2FD0778AEAD97DDF28D0245DD04D58297606C25D492B9D682DC04D5C324EB6E6EDBC791D4D4CC1770841C3325DC15B6C5CF93A3D480F59C73EB203B68056C6EF28C8565ECFC60D002B0BDF274832437F3458C1094FDAB5565840047B9E7749EC700664687424CC020D5AC004C4A06AC4FF137837161D0102522420388142A1E23772C8E1EACBD1FD2A8B75C8858BCE4864D56CDE17F4D0442BD644166845D4C2BD4DB8EF8D74EB6575194D95646E067E00A849B0FB305F80E24637227E54B98C0177BE4D21265D21C22BA0D262174F4B68D719030D8EB021BB8BF3FAB618B8E42616460602458B5D20024AC1C56C7564413C10E0E7F737E02541397514751F0A1875191C751382BFDC991ADF8BD0CD20F7274190C0F4309414AA92EFA0404B181AD19F241C8CDBC121C1AD6545F36BDAB5A01BBE45150A18750F021F15B4BE0926D1D668EB5B266'
	$sHexData &= 'D455A6CD609DC413BCAE4FDAEC14FF027452876143BC230D0E0298D6ED0F745C8E3CCB6DB62FA7E0508D17E079332ACBC3B9AF6F132C245C87E08442E74CDADE3D6C192C22BC6E0C00EC02BC2C48BB41F689EF2F2F84610D0523099CD041C52C845087813AF09090B88BD043C921A99F373485C649FC713A1A8457047E262F30EFA44558516145089CCC4C8B058BD4E6B9539E148582E602CC059F34ED31064C49C68C8130A76029A69C9221065DCA07CCE4810BAEE0C1BBF6C5A57CE380174DC80BD62F494D7C374368D598C69A9BCDDFF8955446215D3BC03C0B26BFB1A02C4E97410A43EE0A9A41580DB10B7AA035FFEFF19808D24D82BD748B8DB3457C929FCB6D782DE1B43622A49C1FCBA3704C41249C015E0BAFC50A053702C05736C80407A1F52A5F07839CAD0786860F93A70D395DE904630FF8D3C7FFDE45435B58FAE41837D600507052772BA7EE47405219F37381F1CB22468E8012EDF83C3F831AAC8454C702F27151474F0058DBB944E9A9003850243C9D1304BE5510CCC4CE28D988548F2E1682A6308B605F271BA0E39F9DC5B8E3CCCE8D821049049E85B4C3D9C2828F09B4BC60584E14914F4762949605197A0C4E249E2721D020C169E6097680BBEF09608175D78EB19140C6608AD1ED8861CE485780168014AA931E1292B700D5B1EACBA30404607B287B95FE4A5F49A9345B089A0585B086DB07B7617D8C192B4993C9323169819E4488B47177C8DD41626F8108BCF8716FF087610303F774DA08173490E19281829FFE04C02421212C8C0DCF27EAFB85D9108E24A0E79F800084C6492839C311001080148A3784B26F81731490C02093FE49029D82BAF9888924F2B99989A1001829C00B9F841AB3D83E5132C1B04A5B8B5400E20ED89C03018011939200FE0AABA032848AA09378932B87220576DA0B5855F0EAE89D11034A06A8099001940682A78939303047889ED6925058AF0C3C18E1C9057C9A9A302E80019402E47D800A088930399006842236978939889EE08E1815CB5F0B50DE70139925799EF00F0A8E0C82703F22AB8A892D872259F1699C80002E8C80139015DA83701A022BCC9F8892564E4C0F0FCA7D7D600B8468003DD894C14A9B209AF89C51548507CCCA1C0C05055F51D725560721F6C900132803C0EA08880083F36229341BEF8034C93020A55627F3E47227371883F380B48807CF81C197FB8A802755098023BA32C3CF650D53723B9A217C019769D4319E03B43BF67E885E002550F2BC779C8C316EEEB43A7047545DFA2EE420E1933C5CD1F840E9C698248B26649C9832097CF781AD857158E5841CF144C371E90A6EEFE0387BDACC4DEF880BDC374134D97911B4B22ED58B6B71C64600211C52533C8CAEB32595C027802CBC1'
	$sHexData &= 'F970806100D2F827E7149E4390F739592D72E4219FB05F9E33B03A9E526327021622D682DFD08607A407734E55287B850553E2010333BEB29ECAAE85059DF6662DC4AE24F799F5FD0397659F242CD56F9527A718471FCDB85CAF6D7D70013E6C054E0D3B3C4570D71C0439547CA485E48F9162E1D8A6FF15F39E58C84072CA9F01E8A63E0066C1FE80C6AF5AFC9307F0BAFB3E81736C1721432039ABA7E0508CA3C705A7B645E224E2E2150FB185824B2824D91968FC6251ACA3E2E0A52145420D86D83C8AB0E40D310C71C95121F560205045A804CE20318275BCE4CFA2A9FB977742AE6CC058F800488BD63062C9A13FA297D0E451C841F5A1F331E057E2E44D8967534589273C021CC80F47AB119E9B90878C2E8F9DEF1F038E7C804D48EB3A4121238F1D4495BE9D3201035EC8A4AC9D4125276AC0903FF4A0316091E4CEF9B441C9099207F0BFDF9D9F270F39229D18540CAB3E994672E42112AB19999B5D4F032E3885980D66A69A4A0E92277D9B0824072099FA5E9F1D7602780B9A04F6AC513D23217BB8BF0D0636209291952EA8D613F8E8783F6464D8D84D3965385EFE143AC8CFF6E3F70365A04DDECABA6BF70FDEDBC216A0EB2AF18844245A83EEDBFA538859560116553B81089B648278632AC023EF4D9EA86AAC90B72939202FF39DCDF6079BA8425D92C16C203385265DA5C5831DD19B37B511F6A338508112D9DC9C32727915E5B6F5E8D8973C82E4A84C9CC03C00999200A8029CE4053294131E980079202F9C97FC970FE4859CCB97B197B997BCE40121019BDBF327485E91FDB9EC979E3CE4242F97254E19A5C991877C4B931FA5269362A40218E9773801418E099E9C4AA5099616100A826CC167561091F319FBDE22669F797C84C0278B97544B621222EE080E100F65E48BF1D6EF05B5F7F10F4FF118443A542C3C450DB5B7F48B7D14451010F943AAD1D8303BF906F9F600C1370120043BD07E0248C62EE2AF1A413BCF7E05047E03BB37028CEEDEC68D5A1101FC22200D4C894D5885B79BDEBC012BD6897C412BCF1C640FB6851D88F88F108845680FAFCA4C38953C53287995ED482D018C4CD24848500613803F9B455837424A6101A9AA8A1832C08E47858409983CA2985C1443AB8C6EDE63D092484AE004A6DC362C0A36200E89481F8448A48EC40FA903C6B0659DD0BB3BDE888C637AA11FBC05DC2FA08D0C8849B7170591FCD5FFC38E15F080FF3BD87CBEB101888DD08BA8CDB6344F954C4C144D588DBA815501A90C58D100D6945516E012AE802F97ABB0AF806FF65D6844889DAF5D691220C3B40AAF2144BE7BF62C44EF0C4D78718BD7AD04C89547D4B80D0407B980C13B5C372816E199B0585C9B8370BC0354400D6E867A08840D39C722C'
	$sHexData &= '1C779F001505001C1469CEA348BF90A592EFC80C09E262701D83C1746D448B9B84244FFB20BA89404E8CC04A594BCA20733F6F521F608AD04BE268BD67A00459889461CE6BE08865EBA77413A041630E301266CEF2C700B811FC0B5B84E02871E29DF752BEA8EA423ABE89BEE638B62716CFC9035E911F62A499C48A5210A9EC4403007223E6270B64199DE291F898B9D8B40A5AD5862DB111A4A38AD18C63FA63C3002EFA00CEECCCB4C2BCE7F98D85623417983BD05CF000FC9DB3B25B18857346EC63BBBFAFD61A7E17301ADAA2CED3BF3728DEB0DCDBDB4813390BB4D970CB5333C8295B03BDE8318025D7CDC27EA261E4F2810B1FB864AEA006233493945406112F908FC00D4366C4778D39E26E2186271D08F69AAAAF5809C0A1298C664C36C063E7805F20176491BE4F66A28D74C2A7F72C1B2E2A5330ECEAC7D1E221E3C83C3206875B9D86227822BA3441173DC9139F97290CC4800F2DC488C1DF751F62E58109C654C45C5C21B84020F9DC3D0605490108EBC680494BA80034C90B2B443E844C2845CC35A5A20A56F4C1549215C59BA1C0F54CA76F305E4DDDC9CF2EC03D8762156C069157E9B47D136DA760541B701DA32FF501E60BB727C246DFA7588BC2002E38C7A78F15E045F1C4D3A82D145BFB77CA6E7D8C3F995E83D6B0C9068DE92E7C910021BF2E827D28067054E080238A0B0D3FDC5838F433BF07325C007163B325CAC979964DE92CF9B74CE02EB14739B2A04DFAEE32147D0DBEC5AF6C6047412EE42B16C3AE6FB8D2F02741400561479FD8F48B84431CA451F0D1A131F209598EFFF91184FBFD88D3F912D4839952D2DAC12FE6A41395564746454115C01D6826070CA72F8E5B554634D3C6088C5829309DEFB857C61D89C43FA433A35FED89EBC807818761B1FABE20C55008D0CE06C003E6DF0AD565C15522517134A6400DC4E60CB157F4985D5EC082C3608410200BE2D123A313B680F8C1E16FE8B9D1C8F802F575C2464F98B8D5C8D0416B80BA03134680F8F258CBD0423C8D3AC17281F74B82BFB2E64CB442B4D4406388827184077685D10C9A46933239759431E0F548E319C3E8B453C7C4F937E406CC0D7C77479486C58411B75BEB388043D24EB4447B11A6618C6DF7956F26026CA05238BA4603043BAC36101FF451A4E6AE019CFD07A610D7406D1F2DA1B8ED4429045A854CBE785ECDAEB4C58944059115E20E940938561442B9064A7A4FF768574D078C7BD75827C1E217E41549C3CEB0C11A39CD8E42009D06BDA807C3C3B5EBD78740AD78CEC182E686F1BAB82E18DF81A9982F748403238C3601B6E6330810C209A32C399CF408795AD59698061E832F6688570C0407A54D8912119A5B75E7B1C2E9065FD88F0E7F8E36FACA9746DD3'
	$sHexData &= '17BC74638B03713ADE0DE58B43040C7CC196BCE0D4C2353078A221D23391EB989ED130218307231C60A2D9342DF0908618552F28C402058E1D97126DFB3A4DDF2D3F2CE98490E79A8B7C6058FC1FBC955C800750EAF245C6C27238FC2C34479F1AC68DBB8EEDE0E26BAE5EC7F3F098C8988DA0BAB93D689CF36A58F144C673CFD2C5C135D110BD6393473D70240E1A0E3695020557E13E0F86276FEC17B1F2C3C86878C6493BDF1983982C18A5FF0410034E610CADB3939C1110F4549E383C304432A5302527AA432BE8AF042BBF8159262C98341D301CF8F074CDE6086F7D6F7C76F0D4FC04398E8B062185E8FC17B54AC5271EDE7467FF0F5B85F1351089A93723A45CD43186804CC7C11D3573103441B18A738C7210438B53F09F39D5BC9D8049AB80C37B1B84FF3E406E85E55CD656B30F5BC5FF8CD03A205DF03104E68C79BD17F45BC8C8865CF5A4FDEDFA113BB5ED16443B8D5419D7AF5D471ECF67C346C2F6E020240753278B55D52D5F20319EF513321990B944AA7A215139DE33E9B0AA43B033B122CB68C90B184825630C169380496EBC0BF6E115CB741BB61A1C47F24ED10002FBCDECFC8810974332905002C8C49277ED73FD62B488C07370A3C519BDD5B0D20E38E308252A24B82050E1FC3D10C28D316C227813BC2D129180C371138F147EC4297CEF4797788527EA41AA30479B4192029525B28C6E49A1374963454C061E360A8AB4C82FCC06761631B704672100351CEEAAF10291CCF250921F678903A52C8CBB68FC604825C66F8660DB97F7028520522EA0006C9C1782037C11FD8AC9CBC49B49C4DDE024C888ED992D5325F8CAFBE7ADB0956FBA05E70D803C055641DEC326DC9AC01E6FEC80EFE523E79DFB053A69982B8C761D89660CA6F70A4C0F160268DA45F10A48F9DA3B9518194956B003CA3C2F754AAE87FB460F3420BBED391D0099954D72F6E0671F3BCA988BD841360B8994B6867C963BAC1D721954987677C00E690E6834A53BAD1CC821ED55903462009466401ED247C5973C88B1E4902C92282EF9DA15837433498BD75607BBE440D4249BD76B037B0D5BF29667D6330B16C492B8CE3A8E85D21CEC20949337647221CD841C7868561CD24CC85C743A40E421ED8055C0341FE5942A0E6906C404FAF91964ABD4A020A2E8841649AB34051593A83499C658E7880FAE203FE3BC1C3D600309B248D7B4773C6670038D0A546E5D0D10E85BEB5613B7A990A58D039B6BD5DFCB8033480E5EA025E9CF8C852E59390133D0BCC00138F1E67A41CFEB6C19B0823081D5731A5C14E01786F200791823AE442155BFC848D55FA57E7CBC95952F28A6EBFA056120064E90A73815942A1B02663C5D8D803B4C2A7DD3F5412A563B7CCCEB670586D0704A1'
	$sHexData &= '0C94751C101301EA3D76CD440C8FD4E7A708D853C08967BA80014C52A79A800A969BC1471497904925099B88B0650CF67F3B363087BE04543D04BC053E3351B9FB05BA0A75E5D69DAD5099FDA0411CB5AC605B05240A9AB5A50827F1FD2A1706E7FD1994A12AB4BBF754B6C828DFF1285DF39C540613F0001C9620823C2030C292DB20E559F7B6D6C20F0B88B2C65CFFE275662F6EC40181901FF15F2829B914B5B32471C07D88271CB81131B25DF107F67E8A7603B708818443B481C05612D6D1354A0A29ED87B1028627BDA9B644D1F45847084B035CB4FC0761F20B0B8DBC4DB659DE76E4F308A28AC44239C3A624F5245D7E7C4996C4547383F1007BC133B1BD740C63C010FB60122CA9EA8023AE245C47B636B09228E10E4A7323E11F02DEBBF9E3E5A1F87E5F150371B0058237ABFD0D68B7F5359B7352704670806402065E2006F75C77B631E220FD101F18103175DD6D3DEAF8933D0737BC566E183223C5074260EB44DD091F71F002C89235463E10A06F26385C31732D608DB1000636D2C90013E9393936B20283038564093934048E9B2B0AA361F0DE42B62DFA78003AED9C6ABFF5556834095415E4EC0DD0888F29F000E2A7928045801EA6A41F7293CBAF7644173CEC0E9F884D833ED66F83F5C5496147A6F6B6061AA45B72B55124772663820FF0D4E9F5C7F396E60CE166478E0127F7CE13516F2521C0C068F2884A78C04DDBA9E02078CD93834684003AF484E282E7F410FE555A508D87660344C1A2A92EEE0130D132C3948842B84714D4B1005881F2C677B3CCC7D105E844C3BA77E822F0BA949E59F1A72D5A668915EB8415C00FBAD5BD0729900007502198BFF859206B0501AA35B5EF0BE9A93C0E6CD107BE8A41CE0A0B73584F5D1127BD826B805265E8388A848C04E660F5FD259D6C3123083A04F08CC46577A5AFA925FF00AA77D103F085C05A9736F000B16F412D84E4179765286047B229EFF73FA81493BFA72C9488B4CC0CF43CF6FD3684983FBAB28DB1A11604D7A92FA043A02F150542AAF9E8C840AE99884D29C90C3870C33BF6941C706997A20999A0C0726F7507257D448B4A9AB182A0D77512C6F4AE85D49DF805505DF2F67C649B7CE865B83DB30EEE67C834370E0834B2F752626931CC19063250FE91D887207725071431CD279BF70D14C3BD6752A6E3B08206DDD105F760AE7A12DCDEEEDE905753CE4C35A920E7F1F1D4177460E08109D5E876A837C533D9CCF8B669F33815C2E098F42EFC545480106F750A6536D698F21DE9F3F0F197986A7E820408BC9A60E705BC178C3A2946762BF10183E0233B51CC79870B0912512A6CFEA85119BB615F72D5220E8F1413B48340BFD16DC744FDF889BDDFE2BE9442BF28BC51CCE0FAF0A06CE'
	$sHexData &= '03C817C24A403A22E6C03E83FF4F7700760D67D3140F2FC8774F8D043F992ACB1CD4F7FB8AAAE6015A6BDB4CFC12DC7CA4FD1AE380F6340890083A36F0082E549D7C10280398FE6C6F67CF7803DCCF100F7303F603FDBAEF0B1A52ECF6D0EB0B8BD62F8F40B092E798A65860D1D00F8ADE57B1408BFA01470BCBC5F04468F377E33BA20970A0296C418BDF85FFFD1C845E898E8B8B388D77FF4C238027EB0E306E70BFB08C050CC9F1F4E0C8F2FBAA1B06B90A1D12BB15BD6872033F38FFF97EB32AFA773BDE7D0BB9324943FFC33BDF7CB51C9C0A56678ED07DC48AD11C72405FC3BB01AC907F216B006F99F1CAFE2638AD9301F7764E04A85A58BABAE0B2080D2A0B166477EDE734B29C2C4FE17FA4FF41672E0F34E78B4577458D7D01272A043122A26C36ED09C888965D78CC4C84EEB0304528C473406F40025ECC6D4D87B240202A7156EC24459732F576600E824EEBB2D8CB1CFEB35940056CF72D1C577134168AA95626781AF0A8631E947C5230022C3CB000E0905A6EB5EF09219A1E362C8CE0DD58526768094288AD3D887FEF3441B8282B6DAB78FEBD572EA70EB306BF0ED3418D48D9DB15097F03CB6DA7CCBB143C9BE716C7CF75E3EF2453B3B523E14C6A5A091AC570696EF132A39ACFC089482E6445BB3819500922314C9C70F2E24F40142F3DEB38AF6C7F27970322761E6B602BFB8D57EF740AECFFEB040CDF41BF6944386D7FC177C74E9530C2553D5A4863BC73E09E503C3212A8BDC6CDB3A0406E6D878FEB7503989EA70961DD7503C766CC0C9D605EA44AE0152DA6440F4E6AC05C97138C7691A5604D24CF650D6FE82254B7F387DF046324599949F7F98F59B1B00E648388A69E45A7C5B2A1F24597C71025759EC769168B443F242AD20AAD310CF0DD5691805102812C634D863FC4E3A6F13EC33F3008497A27B7C1FCFE042023431843180B32CE2DBD04D20008371404DADBE03AE31DFF8B174D1A57051D025002C630A656988A20EB05CBF2407ED32220085008468E60B230081F406C851472494935642CA251E6743F036482D7A1745E55305EE5015698287274D34DD40B84D21AAC1A3C329153D901E69DAF4162EC26286111DF32BC48D92D3272210588306040468849D4FFE382D808334D7D1E39C344335AB7C1E679BEC8848D9F2A9B897B28015ADD36D79D4E6935DF7F700848D28A04E9A1730C8FC72AFD8360AD45841147E27208F64950C0EE6EAB34420C075486D2675D716B3D254C608F395BB69E9E5B6451AE737C0070E9E332F32803C1C863CE20CD40B89C1D389C07FC4E7CF1D520ED5DE028508028C72FAD24FC606B2BF88FB72F1A5F89106C382BD17508C8B38B4E1B88EDF80D453B6E1ACEF5E80F95C30A8F61D2C4141A243B0381F2D'
	$sHexData &= '2C590EB93B97CD3D8B743287030288C07A2067A2B489353C9D117305273525A7244CB6018A510F2EA7008FF990AB9642008209057A8191808E3B57292DED49F8B42283941289213D25C8C3F60A8EE0C8D02D4FA04E960DA502F61851337ABFD6E5059E4413313710A841A38FE04DA5E26FE0124448D4010EB13F58D6B11BFD725744E6786513AA3975271BB3594F0F6228981704B1A4B98FD3D9C191B81CED10B306D318CA029FE498B7734F2EEAD9EE452E95EEC32708FF82939CB65F66A1C99548F0FCF79B1176C8A75BC07F66F77FD6F1D3A402E188081913388D540C23BD92564102E20874F53483F9D52A6A09C49A8900A01DF7E0AF8F06FEC484D3BD37B39A45E0A503A328BC6B5C580FC3F033E3E34D3EDB54EAA04CA3A0B34DF771CCB0D027674914036CA49C769167EC80374588BF75F83F70EB6D5460C327979738CB759664BC484C63098AAC2B4608FDC94C0EEA0EC6AA68D045B1A1E3CC24D7A08FE200D35BF2702BCBC49A5C081791C44C8255709582F046461404EF76FC75D724868E09C5860342AD0409FBF0003B17555BB68FFE4914F9840FFF70450458BE9418B60501498F096E1B0D21735E7049527234EB80D1B7A67E2002B4D68FB003370239B391E7A252E20B7B4B93C242BCD12682444FCCBF3FF74110C8D4FFD41FFD7A9FF21CE71392B19453BEF450F4DFD5D5F961A74D095E4B8BCB491BA6412D64FF845806B1BF1BE6D4E83FE9A0909C5C29619A9B875094005B0DE0DC440B5984032ED162E8E8A04A46BDC17114F8C6F96AB094403BA0634BE8612C040886660CEEB0D911E4F96A80020FEB88470C6484D6442E7260E7E5A2E3C37092022E4219F27147946671A798DA20272216797902A011C6821A4586B22BF0EB0B2086B2D32A855F6D1BE4D0CA01F04E89EBCE26D580E33ED8BDD577B216F783683BCA07CA166397278567C274779667F25CE56666659CF8454E44DD4D18C5454EC4120EDE8E8A212A79065946B30FF0700B6F800443BF7993B1CA43C6183120FE7EEED430F421F3670742BAB8BFF8A8E92A2F76E677499F9FD6F46AA344103FEEB1F8BFAEB1B598BF0A0B373E30F8046284B4101540818E4B25486373E3ED8D61D231B975AE60B782970E397B513DD44664580C010CB926CDB7C0DFE896A931E8BD7E3E41CEB129C3A586782F3C6E80EF28A6BE490E12F202377E4C9495655652977306515A1270C1D65BA80C953000100CB797240153F385FF4023C6503044B7C92B0C765F914292B9FE775017A1F536E76A064CA93CF213E717678642595279FF07E766564F6F1933E34D62BF33D04AD68A4A25D4B39DD32A3F52C4775F606335C35C07AE0292D5EE3497C54BBED037B6534FCBF49FD9969ED2CD403AD7D994A22BF05FC0123'
	$sHexData &= '6B8A418D0C04A817FF1DD1438D14283BC87C563BE27F503BD0AB1BE67C4B3B527F45836ECAF5124039554476A26FF295E780E0F0A19F5F6B8CC5566C94C0B63ABA5278F5D0B70AFD64E520AFB5451E39756B63AD429E9C3F7546635F9A03265FF9C880F204112A4B23EF79FD00BD60B0B415BA1A0568B9C0012B06C457D7F041BDA0FA4A8B07F6FFDB1CD05419A801752583C8014E89642B10891C7A83FC333A9A5F4A762BB94689242B301E361D3657EA456FCFD006720FB29FBF62E09B4C6B26A988DE109F0A7FE19A769BB285873810CB8F7F34DF37046C6485972BCFAF5CBA07E26ED32BA7DF4572DFD7B711E3304DD73BF6652E8C0DBCA706BFEC1CA84945FA7D8789758FF69316972C243CFE48F36C4903DD20DACD043C61723F0743C6A7AA74038E4F4B108015018B7D0B5A95243CFB8DE4448CDC8353A868C60762C7D58E270C4987AE4AFFC38EEF46021732C8337C18DC10CC480AAB6A2F51C8690640046491765A59A54C0C505520A5F9540000803F58F45C550A6812903DDFCE055C60FDEB67F08BC30C05DBB0397520E1CA9D18FFB9980175785B9B1841BC093B07B93C397C23E55D233C2376389122EA73431E1F5F26A7453E39ADD42289932DAD011E240AE128F92E002CC323381CC346DE5CA0483F9C6914EB05897F4CC248D68844F7601378603A078C3082D871283A4C3C4259DC88B9E37C478C00AFA47BDC480664287F3F0A5825AF6A66D7E43A323783C01523E4A06AFFEE96D292911630078792575C01825C8597AF16AE201BF2930B44B590CB979BF12CEE6A5E87449F01AFAD108C201ED158D1D5EB75600011C70902A99247A364031B292EFF4916040E00DAF80CC4C230B2B71EA109093C568BCD976CE04D5D071DE94C4E0B2122FF378F25AB10FA61EC091032722422F145F5A587B2321893BCF5B019102C0E16FDBD4E6027956D0F437C0E666389AA61CF8A94C37C901334D9366384DB0F8529293C181523B710216888081FD84D21DEC5461878082910100CEFEB33090E81031324039900D6696057F14027121CD046FE7CC3FD2874B5939D0CEC0E345F82210513EF7610786732420F7318D848EB173D157DF0C20F6C748BEFEB0549351238436A28F72A4DFB0432F04420F0FFFFD32EF154F8F8AD6AC91CC830CFCFC8D2C6D8D806187EAA10C5413923191742440BC04717B611D4EE38C71E0AC1C43B0F9E05A04E630305ACEB0A810B11673258E8DF9634E495DE0E4C2EE428F4B4FF5028DCE8246137019E89D43A95A91AEA04C45A1E4983320B3798D985245C07FE24B35CD6D262589C4BBBB4A7F747FFC446B6821123678D861606422D9E5EB3D471DA6DC46357549EC08B887815C695827B4415E4743C66B8116D0CDF28D7E8496BC22AD65F5'
	$sHexData &= 'A2018404C2BC0C24284CD24C5C400EC3DFF5A05E9813472CFF53C1D3C8379E8708B3451913218716CBB5C60B603C17804181183FA001400EBC17F0BAF59483F8BECF28454363C8000A0E4E80401BD1031F0FBA83A34D4CE07497E5AC301A1801A8A6EBFD7FD10613E0BE0A8D27D412FEA4775FCE0D039055C40B355BC04C219D8075DE8EA36BBDF2E32E245E04D7D204D8D48B74C3BF1F640D0CB490F42C0392E74190D283B873F3BCA4D905AD6EEE23175EDDA67DD94408846FF33493B2E9F85B7C945FFC15C89B8C0F041680D13B0AEC1EC49C83A11B4B4D618C81AB5E0123AD017EA0C4178BB8026B09EFB07771A9A606C706A8003DB1D70EAC5D6BE1DB0EB09FA6FB05D9907607DB080607D65DCB58CC84D7A7C2DC3AE4BE4495DB0D00EAA65472428FB6E2D23319F559F5F03EC28D84AC68F4DC00801D9E0B3AFB79AE4916ABEE801499DD00C72AA420B7C5E7D980E1C2188FB37AD5036134085668501E482BDD17253C9B730D0509AA217AFAA85201F2466033AF02606C84B8000617463D44BDF9CBC3473DBE9D012E6F766109A24E877A80CB47024C27D7F70B88740E41C78F2E1B34DB4C04207461EBB3A6D880958A5E0761250CD09C6C20333317634724DFE4598A0444C949806E268F3489F46FCF0B7CE6C4A6DB69F0E4D9F2D0FAA145DAFEBD0E1D93D3C49A68C3914E1255CE1BB0306BC9E220B1023221572A303FCD6DB75B0F16C50D37C906312063E5F16E71EE0DEB2D546824BA0A7E3BF92D0398B812C034D2BC73990694F9F7F13C58B0504F6EB7779F8752F24341106A64EF4C6B4CA10DBBF7F8537F9D8C17330267A83487DFFF87A24990A424A8F9A810F7A6A937775FE3300150435828428B035D1F275B573061F6CB6803D5F8B621C6656875C7029E00B1A5593416CD2F09B9A281FCF826BC19F377F2A1E4CC10FB71104012BD0C1025B819FCA85C06FFA72CF0BB6C16B2D045EB0E15383BD69C585908BBBE74DAFF08D2E1C709F5B37AAB3C99DBA630F86312C005B6953608225CB89BFE7524A08F785FF7888EEC56E1E5FEF974C3AE6B7B162050F5F80A7C30E23F6B497AFB6613675AE0806535A31BE8543CA2EEB1CE70C40DD19679764E4CA1018C35F62F9037529492BCF3F327E28343207C0397512499858A00E216CB875E9D1E19CBBB8CFEB30AFE5A91ECC4EA1ED067E2BCE5E0680BD849DD23175C8C6021FED8B2D657D5903875587FE9C823380BF66CC319ADB565056F947103E418BDE07C39BC215E19CB7470BBAF085523CDB0894C67A4C2F981EA843E5C410C62A1108E3AA9608ABC02DBE238540E099C88008AA114F1930D41806D9A102A420CA01E2A8D291B8A049FCF96C80B070B2B40CAE54F845E20E4A16DA0C907242168B6C0D0CF40B'
	$sHexData &= '54462E6F7877A9090D5AC6B5EE324D6D3C439A6B832D31581A6CF351B5C0DF18EFA5A0CD945BE116EE0AC765B4B53E77995F624269702D7B653BFEEB305BF089D47F209D37A4AE49186AE90FCE56584042190FB478488190CDD47BF522681EA76062C8025DDB6811D07204E311DC683E80BFFA022E1C7E78B011726649804210ED8D5AF0061C44C3410068BADFCBD6FA73F5571E74476683387E74ACC0E901EBEE9F46DC59BB41B8112A49C84DB169201CEE9E0A0C11A0434DCBDC35EC4963576489CA740D75EBAE05F13156CDED50EF33B71A6CAF821284F64AFCA93067DA751D81A320D4D141526CD032C1AABAD12724D257D021A8D05644A148046385331CE0850D18F2E820CA1C12062BFC41E7641C20EB05E12EA0C3388805671B38DE0D0B18CD4BA83004752E0A46DE027F9CBEC5C290E3205F185078AF09560C7185EC760077DAF6C60120E6FE9172380406D2414E552A2F696E6149C1C656C9F3A23837E57414ED764FC889AA08F5635696F4AA2B1E282A4ED13B01E5F91E506B0CC2DCB684F03C60504B6766407E41C80101044872026492E9556A257BC363A0006D6E022EB19A9D97CB495656BE8408CE506A5054462EDDDD3C3D65E7094BAE105FF790DC573BB0C917C85C202C7B304D8B63C8C428C44147132299B1BFF6CA449E9022B6D06BDD04B340874330E0CC1C41643902527F56DC8B0DA10505D1BE2F34787B1CC81E333905B664EC539C13903A077EA9D99D20E24E069574308C8CBC6B8DAA1E0CBBBCBD21C28D8CBEBF955921E27BF17C1433FFF47B089C350F597C0849DC632F6C0810713844036908142C2BBFF5F5AC0339082A2FB4B01DBE0219BCC5624B3C1DB44F181FACF9075F4EE89EF2E07B704AA3E8287E3B9ADF07B9287C1ED3077526E917E49DA2CEC4239A04989B8A5F90B041EA4EC78616F849EB8DD83448BE59F85059D333CE48BF42551656D962CF32C9AD3582E128C815E2E3C924934CE4E5E6180D7E32E748230D6720430A49882C206E07ED77CB78045C1C094F8B14D930157B80D4B81F24FF507505247B0B687ACAEB084BA2D9ED3BC10B0F49FC742E4C39401085DE147DF00FBC1E8B5818B9454E434BBE1EE7A94D4FDA352A8CF80A958EBBF2803D5070EDD2CCA24A1048092242D8BA342B74675E4293CDE5B3FE0D63474B2013636643777128EE3B5654F98E0A700A9A176E2B1F1C24E1CE73071B7787C055B8F8E876E0FFD0325D937CD0A1E836D841514DED148B519C4C331E0B242F7915E105BC0590098677992490FF1085AB469C757ED2E044E863E8469DB577B61465F5A703A81636F88C48B91AE9BC67B30007B6454E2A1F564166730EBE75660FDCC7B00EEACCEE891524403D07AF2CFB063A0E4DFDC283AAF44DF07DBE0'
	$sHexData &= '405504959017603BD4CB5CE497E83474CAB4B95642235AAF85BD08FB050EF015E576CB3CA8B029F8704880D89232323238A8B8C8D705B38238EBFF0BD5818DF0D4B4433DB88141F3E6A4D1E4D0417BC68D6A303ADDF4FB25B8A0915BE1DFF037ADE5282F3D30F4E0DA388D31D7419D3226EC8BDBC14C81DC90DA81C286CA1209F8B19EDB74A97F79B76A4CB1875E431360E40A3C6010080B06E5997E91014A81FB75C70B2028AA5D750F4ECFF043062524FBA41A0BD3FB6DF3CC8B93410422A3902EC97229A263A1042891E5006A92C9C53463A3AF0BF770B855FEC08D6EC443825840270434C69828E06EFBCCFE612103D9AEB6C306A232A833C95A05A57A648F254067944AC363119E4A90CB2241EB8F88D975712E40B3DC8EC0F4496145648947E4993362D9381D8E126DD8A4C44DADC16BFD516C68157C426BC527C63506212F401FF8BF0832DB9495008895F03644886A42088A7B686644886C5F8EB33B46448EA4D03197653B73C55CFD00794459AEF00BE4A202D32C4CF553AD50BB976C8686A999A5C72C8B0AA5D393B8BBE21B3813F675D0CD086824B00CD6321E48114DA62A1AEAD49030399F6BF5E994F1A69E54A5896FE043D5503DF09E75D157A4312544C5D72313410DEA3D36505794BB7B3914EC4247282E26C2E132D5E07BB084E215E9BF42141267AA7E18D4D4D9030124E3E168149E79D244CE596ED6E729043AE4874583364DA439AD794AE5DFDC6F290E62588D6699F5E5038261E0DBBB0BFC658F7107B2B0DA220D8A0F33467428362DA95AD6148A72A027765933CA4B436285D609315917870A28DE114C67F68265E7B4D8BF4A4F37E1AD54CE71F438B7C0608F0346BF607B71674060C19432B3C06061A04FB841C8607B8473B025ED25CF2D876333C57D65C7A700A1E765C63A6FD4E03CEF014B411B60301C1DFEBDE4E761A0C0341041C642324F5143802FDEAA8BFB8CEB00C6DBE8FC1A8BA457D157D5D6950D80979C80F755DCD46331A1E9C645705171C418010145B425E01CE11A85020BB5BCF678725E3EEFCFFC3DC11A1067012CEF6702AA0F083C618DF43FFE7C023B9601C5D0C06BA79425EC86E5BF95C1D20FA30BC0ADE2FB73346A1647338C9D5C8BA3D38EE45C8C8B01B08CA9F38C9A6649007E345859EBD6C93C739B85A9CF1D09A5C053976756F6D61877B049C05EA5802A12048C295207FA0502DE87513AC05BDB5041E880D6E8074820ADB306DA490492481036AB871BBC3F2207428E0C8DFCC1B82838D1B284D6D6C100EDAD2EB4520D5C0BA3FDC283508935347479D43892DA83B0573C2C12D686D640DEB16E4A8BD1750BE6E410D684403DD822A070E43C30D28790D61C06001C0D2195094BE0496FCF922CF047B619F2F6C0009D0'
	$sHexData &= '7761D9892FCDB721964040663F7C3A799E033648B8F53B07968C6C79CDDBD150022ECB3BC124ED06C6C420E81AEB057D3C42FF27890DD1CE04E6920033EE8D3D6D73C83F6311F7040AE77532F51838B521CCD94721AB39F4F6A3DD3589BBEB3A4D467AE124F9D98C2DC548B63EC705CBC97BF2DC0114C8EB0B18BB0B50888803A090758B611CBFE2A22695BF3E554D624C9C310C6A6B721B6312654E610F2D45E3188CE9BF95FF01DD414CEA8210DF202B8B6B635C8CF987077FC7470B28C67BB41D7824624CC4D80566907F0777AE182750103C815F025ADB5AB4875CA4105FEC1048B8D025B7067D2040013CD11702975C72C90304050656BCC925070D7A73F8F6A0B37D23CA121551EF04DA41C18CC9068E14CA61D0E90CEE3725E5DDA04E11824BE3159441558616BE48E969CD6AA466011CC30C11751EAD427FD0E1F73C48AD10533E959E6515180AFCBAA558C1CB0860EF3648C149BEF8C8CA174B2EB9E402030437B9E4920506070D6087CE0224155EE26FF7F0E99EA3F30C14452B0F1F21831C72F8CA4A13261C7F28E38B1AF60F297096EB0872DD6A1F6A36A67B08C7DFA6DFE9503A740EEDDF43F796CF05589F3D20A4543D3A32AEECAD0C618107E5D0E40EF692F604E113ADD1E1E166707BA78997829048C31F7599381730EB9C3203EF3D40C7489726935CDD301E8A2D2A4D6603A7A3114D1658006E4EAB131CA7965CF9EC9F9A03E3F504A6A8471386108141A141B5DFA1236040AAED22DC2243213831605A0B3385A0E0244F484D34042AE7A411CBD6203FAB03C2B76E51A3DFA11F436BDBA239FF1D178C77AD9F117908C9C65E4DC5FE792E7D8D4FC786C512763BB3CB7859F8462889472828B771083D8F63751B17FB92FB2BE954B5451AE07FDFE4FD76CF59FACD8BF1CB8D4BD203D05B6D58CC659D5C14580D295F694C681C2D74110B71718155518B59450556A119B5D5406239523FDFEBD47180371F2B0156B1AD2B6AC31F3C0C108A1F71E48BB5D4541A510E381E6A1FCE8542886AB07D3C3F89918596128B1A800833B18E2DCCDF2CAF68B8FC293D3E9E7658351FF90311011A2D9D183F04C3DF96D04010D922E372E548C20A4982494D89087A701BD8820F38C309087F17C4365B259F18C03BCB3604249D528A6E4CCF341814269CEE49A641E81852DAC6408D7D8AF3E4887F4ABD5C1798BC2299F0B13CA5A5B4AA1F3E951844BD02FDE1406E10F4E3C404C1BA10E469279C4B68E9B75AC28BCD0ED08BDD27C4834922A8860D7823891AD8324872F039017841056C4380B9B796B00238D018094B4B47E0B2DC670A4D10946E281BF13C4DC15C482E6E6E079D7776067B47080E1099427BFE062F48896F08102218C276A6F02C471C2B472084C0DBD901B'
	$sHexData &= '447210A00807F2807F5C0DA9C2822196A50AEA43B43E9A9024A2C8BF28378F269620AEB0F9E461883F72AC648181A974B8050761272C31AC5E181D4E15D3FD935EE9047098B5F7C349864A43925F80E90E928304A7F0375E004F25F0505C3DFB411886BBF4B388421228186CBD350C49D6ED96E089F9B068940066AF4DA40159A9B2045EC01F4C381589FEE01C3607F065EBCA7B5F606187E027C008A4A4822425376D22D6E42028BBF888CE0568BA7E69A07BE408CC8BD5A43E03DC864496BD01732950AF606835C7F06AA42B3FF6DFFCC64A0E440E03817D8D10A5F2C1B1A19AD59C28078EF1FA23100180F84E3AC09273920E7321555050670FF1F1448143B858C9FBF1E013240BED136CCA20E4257B9A0B170C8C873FFBFCD0FC855C3FAE833F68BCEE009F924CD8BDEE0E0488930435E60C771EA61C271EAD6799A82C836377777F24CEADA074447704A5820B43153C951814DE0C7E7922F102C4870E1000594784D3230E4020AAC7D5FE01B4F580822C6815C71A38CD07F02C874C30A1EE893703BE300406B0D6A1CEE91273ABC0D34A4285DF2348796568E2A104F3079293248E945D00257204BF24DF23B9F0B2C4E2E1887CC5F5EC020157F69F204D3A4D2484A483FB15CC3D35D2741D145D3AA905B65FAAA69799E335F0FB64A877C18A5CA61440FB6024CB650C466781E4201B2C1491477DBEBB8490CEEC16003150C9FD01AC5A1FF34DB1A3165FF3801605BFC41283F04652D25957D44237EA676807926092143E1366184145AECCACE101CEF66F6E4726984AAF24B0343DC37AD438667062E974A47F343434343008311DF044F21384F28EFB08AC52DB5FF52AC60602138275370F010087FD428868872B90A4EBE52570242CC096A7242674A1919B914564242424225924B734A4ACA11918CD601C6FC0127C0A1885BBE250A7950041F9D30002C84758B108FC8A572513F1001412E1941FE09483BD1741FF700CC25E30FF5EDB605C07935302FBBE2EC56A33F1F8B080EAE76EA96C3BF0F00B9A4965CB5A560560260E5D43CDA439269539D4C59021503492699640405062DB7ADAD072C1D0D9D3A6C9CC6C84C002CA7106A9F7A5601F08B3C14C84D8D1CC885984CC8B58A0974CB0BC4C1029305A0695E8B73C6FAB5B8FAEEE3B95455010505C64E95CFAB8B3F44D929C0D659EBE113855382168B91472D958A5077C02CB15BC6E4742468C71899A2A09F58F99955D80AE133F6448D5919A6DA3A3C0A48CFFBB16AF7D47718062028B58C97D0C707CE8D56CEE480C649CFC7BE58F8C0170BDF83E83D75EA554D5F895CD5D21C6AA3694BE8D043F8810BD2552D4FF610F5BCE806F0F8FE469E0C61741E9B85B45F8AB12E7C422D9F05C639C0E5354C224C733D8B3A0B'
	$sHexData &= 'F9520EE684078D7DBA04883D26B84807998C6C9F8CB563ACA74B42CB0D60AD9F498940A259D9DA58CF8DFF05155672BF4C976010B35ED22BFF700BB0909E8CE31E36D4142A9CD2B073200894C90AF049C8036D55039289120452836954E24D5CDE01AEAD008B9D4DBFFF317003D6ED9FD1CCC8C2C2C614A73B47B66C05229C22C3A02056738D2D1F0BB8B871DD3C9F50D50B4F861E00DA554CC068E760C0340304503AF8B67657AE42578D9134032800C847728513C9488954858D6B802D8D2209512B0435C3971696BE465F05DDDBD9DB3328BADE0DFF726E26C11914D8389523AC80C8FD2CAA9B1FB9212DA744E344EB1601BA2886B5DC8C94DB04DFF266149527DACE6903F9C2C6DA4FDB049C5AD8B83E20A8B8C9CF5D801038DB0431DB0461A317A00934F3853C5FD908DB040EF0DA0401C483CD0EE5DA8D0E25D368C379CB43DA9297CA03438D53FAB3552CEAEE83FF05B40C0B73E0BA84847934CCD86964324E882A314D51450BA54DF028D101D0264B3FE1CB7170AC3F95CAC19E65458A4E491F5619DA4800CADD320D030D23B0158E5AC99A8A5F8DFD8D7701438005DED95907631DA1511F6B8C4AD43DC2B05AC370115909D29BD9C186F256171FC69A3C282E3E560D80D9B1A36CD9E72A1B83D88466D90400BAB4E55FD9046644CB21AF8A1593A31ED9A69E54E413D902B95CB49E5111045188074725DCA71D89170C575120061B5FD9D85E4710AF4F20A4D8C62BAD579A47C43D78715710BCD5D831C60C22B401EB8F5FFCD3D67D941D9138E4890597D885ADF3BB7F6B05907065EFE03C128E6716625D047C4694E0FF5318D6EAC61A3FBF010B805A9F02AD22EB1F7F9F8FD803A9D61F80797AB7C8DA1800E6C6281312EEC1460B931EE501DFAF8A19973EBF3D25D24A0821FF94941482101F4B849226070B053F1519010DDA8DFFEF4095A57FC108990EA01984903DCB2FAD19CF34D1DFA726F9205F5C502C16C21964EAAC40B4E2D2009CAF9FB8311678CD17D238950C31C4D6B0D0E30D4C8CB53928202A471EB177FBAC918861C04E1392045AB1173AF91C6639001FCB99CB24538C57B14BC30BE4520F9030FC409E01B918BF5068709C904B4630404B7C499C3C9001E57C681D4EB58A173F7A1806C07942122C99B00CF974493B03C974244535BF64BF411064B824C0BC3FC101C8420C7FAB4A7661DEEA0C2E2C5AC9ECBCFFE2B3CDC8CF03D31504D3D0E7D21923965B522AD238B949C089DE910B4306190039C95988F39A4B0BAC8B668BD2928FF10E78251B4421CDF32AC2BF52D2F238C9421C90D2EABC6224D2052D59791ED217D27900790A6DEED104D6D10414F4713ECBD104DAD64FC2C8236B46204EB3A1F7434175FF05B6594428D46DB13DA216FD01408'
	$sHexData &= 'E3C3E71D180D107795DB8418CDF29D106D1219B1320EA0CD8D078722A39C3D0C2D0A8D0F2BA70AA1F94D0DF8ED017EBC2B287D0D11F2E1C92CB5ED00646D0DF5788FCF9053BD0040633C9D0484BA91403B0074F2A2E5D38B8A2180F6047E1D9007C4020844F303042405676C40AD0FBCFE5E5C9E9BFC9CFCFCFB7CF491EF264C8CFC6CF9ACFCDC217C88DCF6BC238178DB40A807F38CD422A2C593F6D6301C804450814490880919F451429C9706E6B6C2CC21B032DA679E66DBD71F2F061013653D006D8EBC73BA543CD8AB50433ED74EB84165E896C7F1A520EEA01D896257935B18084E14EC60839D15AA0E410FCC7405CE32D80C78BE448BEA0382080BD5AA25F6BFF83C39E2D89F608C7FB16EE5D8A171E1347DED389C20A9A4B1EA82A607010182330642145C06D346E1C24B94E21513F9F543C23884D084004E00C08583DCDD3080C0C1044884DD342C128304018692E8423ECC42828BE6491A628303AFC3816D41E7894C0DF0EC15EA69A2CE2A7795ABB8BC448040C08080CCC7C779A0C10CC9989B8B0B3D5E9C2F43EC210D436CB04380118CD16CB68025E137FF14CFF4CC00D906048BB70EE0C06C32E2920EA0046110BF7900E60B1A0FD20564D5A379F0C8109B8F3AF5A23148AF88A2B026D95680F2E978DCD40929714ED7ADA3B2487E054FA38E2FF051070BA31481EC06760692ECFC886253EB869364883E1E076F8EB17EE14F4814F1A85FF76CF158905E1EB27EC050590E00C07350034C3993E221611963C91C3E0D4B798AF36343C3F8A5D0D845E0490C31FB444415C6C7F1FE48E15609F1E0296FC8C261B211C85480161F09566D2D5656A02F704D5D64433819FD962C9899303141CC81C2A0ADF4D18085172A0DFF4EC96099402FE097A204CA096DA090CF404F12EF54CC45BAD8A4B23AE9D3E215A00DFC240FFDC561D1F818B5EC39F8955A3F0251FA49EAE2A1F2421C450C68E1146205AB51720950A28997CBFD2CED5005940F1B2FA2E096F604FAA28171C404A9FC200C6259DDC8F281990EB9F0492A5EA889C8215FF28EB5C75DF4CA59037FFE5498D88484989804001F51A49BF68A1A9AB0D450E45D7D592C49DD0349DE117A1756DC8EDDA4C54B07583010349CC0B706BF1197B2E7E014F326F7445CFA517B7A0558D4DEF6EFA8C64ED20605EF1F85CCBF8D40BB15DF78A2A7EE04710234983FF025C94B359567B0E0C66A73046BD9FDAD2EB08184CF8897DA7FCAFACF708DFF40E4DB71E4D07060FD6820FB53F0F2875A7D07507A0F5AE82A3F066E73BB979AAA1C22B0306C7465121ADB05E0E10034E185E0E03E45F41CB13A1DE0E0300C6865AB79C1D8EB8738F32201302CE0B5F8EA68356A590DEF3F35DD03A2810DA456686915F7E5EB19E4989'
	$sHexData &= 'B7D6498B4FB38C3574651759BC54C13AC80F4DAF1387AC6DC90C825E08A3C12423114BD0B293C4F8FE0F28612DA48BAEB04A58291A1F7FE28415A8FF8050002C1F82440A1A7F514B9783FFA090FF2DF913D268846B99043ADB684E1EB6B6AC4EB67689C5482A6947C83A310F0CFF9860B4990B41BE9FE480D61F6CE901977698D001DDC81190AEF089D6A57D18572860A4A5AE332C08498CF50CB9E2F2421AAD3757A0F67431BB2A5A93A6C346195AE75A566E5E1E600C2A41C46AD986298082047EA075DBD5EB7A6E037415ED740DB35B65E20E5475D84E0871FA9CE4819A790BDD0A32C0D34A3142F3E0FB129005059C33DB3D881DD230F2DE44E0DBD91E68618ED509BF2400E592197D860F1A2C96742C74C09926AECAB758C2BFB03F1A8B8F878C235935FAB279DD43E986AAACD994960A0DB64EE5083217B497E7DA07F8B7135088AD0AE7E5B563CA09858B33EF09B982D676837F70F98AA42A0392E722397C30287A5500B051433805AD734A922E91D0816001FCE72D80AB9B3F20C757C5294BA870643F6E42C7189FDF56A502896CB20169A4B591F5EE32028CB40690F1D7486B0359F38D91AC3780BB6EDB88645D721590DD04E051D4C75555B25E3F48DCDFF24033ADBF859504AD938201DAC81CD34CEB33C515C3018E7054C99B3C8BC53F0E38F8FF9B5946569ACDE8C549005F372440D68B638CD98BFA096059B1E3B2C023D04B1EA82D8406034D07BC9A009E782B898B6009732A21FE2A84C285D5BB098BFFFA539ADDB637EB83C02D1443C33800160CC3B0C95BD04A09F305BDA1DE269030160E28CEBECB413EFBAAB14808740C2B75ED289C80B138ACCB3A96F2F6415D81AD41705F3F8AA88155FFAA5040903FBF828056A83F148280563543212FA89F166CF849A653247D08B012088780FF20566766C19AE4D5FF565208CA2AADA0132414FF9CE91A7ADA8B132C5BDA2F9472B25619F1F425A9BC95154048894E483113AB06DFDF5D02F0525F9F704F02131C7B8801032500D706EFA86AB5D5779F5F538A66043F7F9D0D600087051997C0CB06BBFEBAB542691831BF6A92B0069817F3F5000F230EC5001F2B01D52A16D31DC75A2DBF06121A9801E5DAD46087DFFF920179D099170B0C6FE4031758FF8307A700AAAA189943C622013D631418C07F01748BA19F55E14833ED8FD2F8A7686E6AFA66892A49548B8DEF01F851106C727A7C2A027182B46CC2878C71C883EAB0492844419A18E87744123A2A9167A9F7D6D3D267984537C2B4D2B175BA81889E83BEB48D2C33935B2BB9A93953481ECFAC77C656CFB33C297C1A5811E75E10C00D59A901CC8C239DBA48D6307119B810089C6B13AA40F0C0C29F63A43EBE2F4C3DCC720455C30D480C9DAD6B450F430'
	$sHexData &= 'C441E140A61424F5608CB6EB646C64404B221AC1172A2E7A1B054460E042069E3A3F600FBFCEB5F7B1443446C02608495C3C4C90B57DA0B00349F154975F080D334B71B6578C2EB1EACD37406EAB02EB7D5CA8B2D07A7D96960C18BD140200118C9CA03480130018700546E61D111270C8283703240552E001E04A62E1042740FE8EDB634F45283E80226382E75F152B86D288DF8C35DC3C8A970CA7F42432A8B1702D44ADA6114037809BE9EC34D658AD35A75F93969D2562ECF104C50DBA60910EDE3255331418945145EEE8475C1B83CF2741ACB45A6A4192A87E64D47D53814C35F0A8975692C745E2D31AC6F2B67144780D678143F57C643A868F13A1595907F5A2115174AD768D594D731E9988A7F1244CF72813C43954C5060302A8E5A567F262CEE109E731A4A52D88A255F60F21E83387C74124F0C5AF1157EF3779F1398A94F8D3D77115845494EE7D2D4FFC2FE57B7C06528954C4CC64365E047D3A7470EA712D0406AC0ECA001100956418AC704C0541043FF1577C9070F5F1E7E74188B5C35F0C105295F2BED4D24C31150DCD7A68EC43C860C15002717BEBB02F06F316C9CEB95502101C78BCC9FE425ACC8945F20C6063D75711049F289A80ED4B6D109E4B77F73CC2BD6818DA5D858A1F58F50543720CDFAC7895C45FD3ACD244075D7D3A350D409C34718C1158A32C48B4BFFC1241C20C923FF15925ADBDFE18EFF0B040695905FAED21AD093CA484EF64DE9EB205024019F3A1E0B545204ECC45FF1180B36585E5A90864891DF6CFBCF7757F089127B0333C966890C507FF0EC187872082D1E0851944A8FD0DF49C10108361A3B0E0C407B1F403726E10AAD305E08ABB55DDF187221722105F6FF900574F0D69919C8E828126E28463A291F4CF0067D369B1ED94C184D2A496C41F00902471EC2EF07132D03A242891440084C40024F5957A18B88CA6BAC010785A10A8114033F043CBCA5541EBE7AC2F0C20AE11D0CD0313F99310A56805FDFC0930AB0197B83A0A8258C1B3F890E417907FD027F046C1781244390924E615C4766470860156907C7970FD23ABF95014986D163C9104832563F17EB94B5CBB36E74D06A4401D7002152C5B21FE1F3703C9063FA062506A01371C318F36A2F3A0E9A2A0F83DCFD10CCBEC07769E09DD2A6AC3E48B8FEB680175BEB8BF5503A966C0C07493CC18EC5660B1B2E4258882E138805F0EB09C21FB6A13B2A2C4A2790490F46C93CCF47440B7AFB02D2CAA479F99AE26D890BD7AF8F9C42DAB7731875C022034B50E961C9572AFF1E109118C30459F7003825478BE20CACFF9E10E5A1682C4D1F10722C15E4A068FFC215212A6CADB09789D4710E51197AFA5F5AC18E6E69885D1FDE913201C7F549A5C3D6AB71C60145'
	$sHexData &= '99963A6C3F73C108A3E30564C37FF2E3165D9AFA190C7F103F70CA4710730D8B76EB7848B98F460C8EFF7998F15600810D9BF156016124CDA579744AC0CAC840903B0E52F94F08E31A09CD6E01D5D7667400DAA24712B9E6B9F42A3E079F815873CBF3634B910518030A01C03C92810A5494882D8D949F02062FB68DCCF54A4690A1191FC0EAA19D43D148C828B8FFCA6A5D40E132406F16963F407DBCA800349FF40200BEF5B5815F08C76729ED18413C50F06DF30F501F491703343923223D01A8995439FCB9CA6A9D6DCB62EEF39E0E130238DFF6C6437C0006720037EAB33DE0AF838B0538AC0472742A4368436205A8C7C1FA7605A8BD18DD4803CFACDF5080A3CFCD8B0FC7B01D9CF2223A158B4470705BC03AFC6D50C845E882A15E9032322107500D50919C4C3250504C83BC223914F4670FB01332212FEFF21098920B9990F20C50724A8E3C3EF25E113AF20019924388AA010432849C1FF250ADD534617FD940753A2A8BD6A3CCF81E676942083AE613316117697B18E77B682326603CF90298F1BF83B9807438947A0A47967E3A53F86ECB22A85018663BF8C91078CA612E2F8CB0D96C9EF502790B59408A5304E300D0E08D9FF94D4789EB4BD0DDBB64620B40358C471206A804690EE3819AC05EAE344E9B1178754451CF669FB571F32B1A477C01884772ACF002D8EBF00281CE55893B22057FD673894F74F047550DCA0EE7A4FF86BCC1C05671E17C0023F182CA9E18A5A1172BDA1B2218243CFCCA7472CA11361C8977297A8FE13CA3355E16587FF4534C494700AF8C26E656AA744909BF5745C828548889979091856E395904D16425AC6FA166188B4FD131030998589F0B04806F6868E1B6872F6C7CEB15EE03B72D44020F245F58338DD17FBD4B9E071F9FC13800017D0A06AC42415138113018187CD4B92884C60A5A11414612C14F95049C6883EE02FB0661080E7462EB5946F09493C6750584B636589278FF44090066F36A36315C382D782B22A93C053FEF10FCCA4F541310AE40264B383AF1284CED6CA9EFAB780A4B5E1E919F10B9CC29939007B25370223592EA7A00B0877047EB41388F3F6164F5FE504D630E93540181C1444927F490F1981D41E27A49AC46DD574AB048FA1A7E1250A8F6B7BD52BF784E365E750AB527C78A1EE1150524F71323C7C56304FF13363C0DDF0ADC8910F27F238364AA7BBA4653BB9D66205069EF50A4BADCD8BA632F23D5FC373F27006D5B2A19ABEC96B6D26EB42B09580B9FD44BD6C3540430B3E59934208A0E74DC1C048EB640104488048B013705F876EB0D7E2CAB50BCC84F02B77CB960EED348557D3F4B1206E194749D065D4CA0D039396910A417211F6C94D13A0F45BB4F689E0B567622C6EE78713C010F8'
	$sHexData &= 'F96F648B8FB593984AC3CB751D58604F6DFC3550F4C2BD00C502CCCE09D784D0F42D0273F1223065D129C4C88ECC760AD0B4C11F90DE5070FDF90F0AAB60C93FF10818707DC0F828D10F88634B3272DB50A9E7635AB6BA044903727094E439C5D26F2DE64ACD403D84C7E1F680FBE0C0B5D77460A0497A231064FEB2EA1C58AE17A5D1F7D103EB5B18707D30BFBA3761850AF19E33D7D58C36A477A06B94A11907B5D815182C8DF8A3CBC791E660819504C63023C41400AC05AEF09AC97B1DD024F99BBFF50382CF8B8BB666ACDD3C70C341ED73A3055C0024D20C7DF9F96B606289FF160362530C3FABED308694348CD04CCFA39087335667A7E51361167EFFE752A2650440AC000FEB7CB4493F63B2E44F8D7176187A0255793B78D32092597B95252F7747D477B4101BD0E5CCF9CE96E004EDF4675C34C9A0906E8A7DA5310745B86460D846E563A74ECAB771A841C3688EC48A9053A70003A0C488B1BB6EE01C4D97AEA5667FD88C172621656B5F656813A231F2EC625CC82D6819FA3383C9C3C8E76047821309834F8703C0A7511E3D617A50ABCE2BAE71640ABF0608A3721165863407873118B30F659C673EA89385927B5C391A089F133BADC1E38C8D3DA41419190E1C06032C9898843B770F864EAC24B9275218E5AB66CD8CD9CD0EDA5E0F710AC2554DCE109D5551FA050CD5396BA1094150D035235AD7103178F2EABAEDE0848EFDECEEA52D6CD1E7D7E0CF07548AC6250EB8C2FFCCC537B712BE8741F4C9D839B95A91B16C5BA011F064C14CE48165528E14CE4AF10A03994E1E2C3B614750309050909F9163C7831D8E8AD1B01F421F6C0560A07DACDEBD4A33019683FA55F61598C143E27070706153773312F0AB47673494343807B7C6C4B80BB0A4E188D173AFB18670176111043EC782FDD8131A1E722E243038B91C52EF09F89C8C0641352633E49E8A626E4089E53DA2446597C29C0716937E84018C9DF9171F6C202B5FC03015241584C8B084D7C051360F7AC5683E9802D02FE780A143B094CA04D8BA49DA94D39C26850B2B2DAD438413041686C9D8C0C4DCBC340A6401B8D1F6872C8E572F509686868A1AD2B3364B2801F15EB050A13E2E7295CC617A05589563CBD178BF91E50EFCAB100813CF55B124706031D20A091CB4A985EE65018CBC190531BBAE6723BC52447A0041B6858B1D5B83CF3B0E5CA690399C410A0B40C70C9E071D04A7F4156ED041848D89E04718A0B1BB73806D24903B04012EE104D81062B0A1A2E7304497874A03D3A5243A0534A1A8229BA18C210C68116A6FE5C760949C702337E9FC27F2007F6C101740564E7FB699D7914028DDCE47C8D3C5E3D27045AE5140FA83E1CAC57F944A350A49C5B322D26D41BBC05AA63100C40'
	$sHexData &= '0E0C204286C1EAE651C8740258DC8028F3CC4B4443837647CEB4961AC318859609EA80CE49532C211C68BD428AC2D42C018CA85F1DC3D3F0269A0879D903ECE040A84147238B2FFA5B4A3015608B73683878D900D00EBE36C6C413F1302E0455860AFF350157FC4252EBFE83E0033C037413B8128034DC158E344C94802C525269471A8AC5EB263202C90CC349330BC10CB97DD820F820128D1CE8E277EB70E6C175D1149BB8ED7B1E86397CCDD2C3CB74283F320A1C0A28F7C130FE10A0E1D4A64EC1652DA0C0B714C4442BBCC4D54D9434AC6118C35FC78E598447E0E13C138059801042534E504B6AB018B8D00A73054146C34909A0B8E1C8B138F2EACC74186014B851401A2E2806B6D1CAD27621D2511C37407B0B0C0BEA5E4D8658E0BC7038461190C4EA75EAA941AAB72330CC61488ED600763F37031DC06644560DAE50FE745E3805B806CC1C2CA780D4F89441410AA36B423B417EE258D1E4D0C2608EE960C2C354C15F6CD0796D828DBF9B4412CF80AE574D9858C0F752C326A0C275AC3C0C84B80EECE92288D57160E1F0BE41E6AA4F7E75C1B5AE23D4FA731E77BCE202379AB0B6745E4754EF31792A7272C7CE928BA1CE21B4F612287BC232EEBDD294E12BF51812FE207278BC10F772A0F73F73065636EB0EB9AD0DFE010BF10F831B48BAAD05AC58D9C0240928041A1D6AA976053B08005D999159273BC84954ABED522BDDC31F3078D6E7200D55D4471E1E4CB56CA8DF80FEEB1441BC408EA4C10E7E1BC0A10352D5A16B753439CFE9D0AD0E1184A6E29C028E27433FC24C039A20BC8FA1F09AFC391240A2CBC1188E869C43060AE256FE100FF205FF4C893038EBBF85E1E10FA6364A472BCD070EDB11FC53A424CD668923691F9C008BA82E060E4D0E2F38FD4DECB0BC69C6E9488D45BE18CE19D682F19164C22E9C04DE22891051D822B22827E119EB0B02C473A01EE40418C00A590EA4993AE5818F0FACFF3E01FA78D4D202D74A61137A3A3E822B0D1D4AEB12C15BB432271E0D2651C98A8057E18BDF03D29558C14D06496BBA44BA875D5D7B1920A8F0A63CDE080A836370FEE72E65E0E72055E0023EE314F06804FF8B0951D25A708B9269326DA0BFC35F30595AC56C1FB62A69A33F9E385FD06000ABDF646BE23450F00D2B0020989782AA4828E0AD1D1F0EBA6A255FC61A130840380321827F71C548984E9CC8FD933877218436F9021BA209C0F06EDC101441A42D4D18FE3E76202B58C94AC7D000170504AB18FF114E26B9E4ADF82875ED25B183D83FB51FB511C8410C1FA16611081F4EC05413DFB9AACBE6CA00ECCF9BBC92830D92087F502A0432F2963C1048CEDE2DDDBB5C7198008C051334FF331683D8913E634094C65D92FFAAFE020049898'
	$sHexData &= '40833458D88A722247F9445898C086E9D7FD803496FDB107D11BA900A581B04EBF45ACB5A29FD83B1A782052701BFC34C1958252378C9C028461F26566D759F1F28C38B223FDDDD8C840AAC9A9F7F028F9A08BF3B0F06CE4226B95E10B85D9C3FCB3C1F75EB12A1B42E953FE0C807E0BA68B56504249343D444E30191269047C8DF90B3902500CDD44A5224ED8AC074CF18032D81331C4A5F4C1C65F044278D3D36215608741A527AEE905372903D0D269023900ABC1C9095900F900C909834207280BCDC8F3055D13A293D7F244607811FDA2A5C5CBF8DF51F426F45D35F1FB0A05A757F3FD5A36A201F42DA35A3956A69BFDF6A0810C35F3F0C4091B4FFD949C02A18E8DFF02A00899FFE500884D2E4927F12A2E80901CE7A10143090AF95D302490EE4EA9F3B2C1906C69211A3D660CC16D1EB20D781C0AA2A3F880EAF8A1FA1D7A63F46AA048CDF473C104F57E209819E44988C42716055452D67189F8603D0297F71D65F182145891FD41AC4237C3E81D9D845849D8C0FD8771249E5417AE8031B6E001B80D436E7B68F052579D1BEC7812151455719A7920E2C21DE0D8582C8D002FF1C85B50841BF30219BA081C8205E0BC01BAA1028BB46D037F983C138838818DABE88024EC8BD64D002407F125AA82280BBE354F54F3D19BA0257E9CF30500A5E4D285E6EFE882C6011A8532859D0BA9F163622CCC68391019EDA4029AD8321151EDAFE099865BBAAAD83BBD4A05440F83B323F18CC30B7A58B47465339C1DB9DBAFC6374D90DE7CF9A8D6E0A9B3780940034FC29E23C9308D0E355D023C16C990AF108ACC81AB556F20421DFB55C04936C9E1BCF283060CFFC21430C97CE30252879C8C0302F1F2836CF93832527AACED030C0A98CB4284C1F0983101831823DF8FBF9807F5FED0280B9D9BB1483B9C1D90C262B0BC1A4B0CD27737B391EC2CE2D305F1528EA40546434D1DF20D0812F6B5F2F3A7041035F65CDC6276B21D7126D28F2C6D48CB8C9101C58B59FE057D081555FBE08E4112071D121144C3810DF80550DAB3F9F784D41B51F0EF2A8129060BFD201D2A0310BFF75B6AD0488083541010649028611D402059F8D6602A93FCE921E4913526201EB82457F87A049AB1FCDCE552960259F587235295F30920E550ADF3B11524026A5D75F8B504FBADFD354F0910A70A1495FB39828B056BD3F580070363106FF05AC6C5D3D3E7A4B210A017B58B5EA50423F804015605EBF851E4593BF72CC9F729380409F940E3686949EEB089AB8ADC12D00007209D8B7FFC18F042C02461E1D49C083989F0151C5190482BFE5A2272AA1D3205706630C5DD8400E7D9009F952891EF97CE1B9900BB9C9B1994002960B89B200408ADFB4657C35169213507C5F72DBE4193442'
	$sHexData &= '4E1AC9B9736DFDEE1A1E1E260E0D267CC07C9347EF0A7CCEFD7B70A11DEE24F60C08B900088C6C02CAE97BC2169F17A83F32DF33FF9FE112F0BC5496C9901BB30339C9B37B9E7BA61EFBEE8129A597AB94153617CAE60F44CF0D81C0B41D6D2E6F25FE17DB7431FFB251CB388091F09ED8577F66EF5B7A4FDADE6A37BD284B35A9F679422E30DD0158351A4740A7993721F17A0CE28089D4773D56C9025F6720F1DAE6C34CB86548BAD051B5B25501724526C804ED24C62C8E720611DF037A987314A2F23BC80860B53EB4E0464EEBDA8752028C69B78BE84D7C4401E92BEB718DB60C7BA86BBE43200CA19D1FB5C126871C1BD6D02E697E2210B7E03F488D70E643E373B046F85E13EB1B8E0B950F931472FD79F0D270B646DEF61A05E7761CFE9AC4200E7B4E8D34FDAEDA9F942D3C36061494CFC20DBD927A03D8E0F06F772EDB15AD7303FB344C3BFD772548403C976A338624B785223E3EFA82277421BAC1E00391A729EF5EA5CEEB33D2ED8D0566C2FE873B362C034C2BF24C03F091D91243F78A364E15520D3CC8C22AE14C5B945C9CD739357E2EF8C55DB81F722B012DF978E91A4C41E9EDC094AA35E0210A980F4823444FC728447C80C02A7CDF18818847C1AD4F670267AB3C2ABE78F212159432F0FD218F1DA1156BF814C1B00DFEF063E840B4A72DB260100641CC1C6B18C590BA4CCBA00B7B0B0A271F1E86560B0DD907782BF4044AFF4C012C361F7683E1E480D62144BE0C026EEF25ED5B0A2F284D0A2EEB04B66D161E00041CE0DE5C698F6A382EFFFFEB033F0F284C119D34E82D7CEA5D28E15FE61ABA720B34493BDC744E5A88D4CE2BC276483F7445AA4E6A05CCCD498849DAFDDB576E0C5508484F084C23C520CC4923C44A8B14C275D12A5C56C15C9D2C32EB75CCB531A55C341D9D7747E2E95FF7A0307F0D7936806AF774359577C9CB73832D6B2AE3BD8F800178DFEB0A8E55494730DC66D01D4B137EBD173234B8E9A72F4848C853A934484848487F6918C9441030304D3BC57488607DAF5338422BE01F394327F44D10342301C948431EB401CB04C0FACA4ACE831B04528EDD75CBC8A4765E726501BE9576F6745579762587014703CB7F5E76CD038EB47A6657767EE90DDEC987CA5476DF124176B3721C2A171B5DCF95604C7C68700FEB3B9278A8DBAC23121221ACE3A6AA80178D03DA3E02DAB55D1F147E2C8A786BA79B9017090F06300E045FC4972CC6C6E050260222211DCC059CD6022DE9A7CCC21A3F0E92594A838C1FCCD2A3F10336D10D2A1B984C1B3335564DAC2FBF23C529607F19E604545F1DC37894E482FF3878E4AC8D010E031F566A74B64E3133EDC1183511D29B3606693B19746E9968C0C0AB60083BA9019077B74B1042B00E1'
	$sHexData &= 'E87CF6B202389A087555FAE669C88E5DBE939ECD03E759C488BD93C61A5BB3C5E37C2AC22090BDF198C4144154B142AA952A61C342E27E2E2035CC1F89AF9E08DB70815D4B8E51C77DED704508AD3CF024AB44719190C98C899D4AF7633C34F332BEC49498D46F0AA9125C08B47B0773814DF2852547C264C497CDF6A6093881D93A0AD0A72EB49FC701806D037012C6C4615425514ACD918CAFE52103E6F19F2041B504DBEA4D6BA2648BF9F667403C04240090E1EA45E034DD7BFB1C87210D6727B0823CE4518A2C8E864950B4642C90712CC6405C4A7142CC286C28840BA011ADCEF49C7EB08F880373A1EBC22C86CE7650BD68188141BCE0C37F17F71CAE2218A8813A4040430202F13CF20E667C012718A4F941A4CDA9E46AF04E1FABC1408754F0C0564AF92B78D517139EE168C44C110787ECF5B81E67230D2DF7E0204ABCCBFA412374883EBFC0FEBAF472B01FC76E6ACD8CB4145741F0320FB442C6EE02EC75B5185562B8144FF68552D204105810655FFBF7914050A9FD16F1772B103C11FA9912117722179619047057A516F9F2D6F2379919C186F166F2779C8CBE66EEE6ED26EC56E494E212BBE6EB16EB2BE5741BF3DAA2A0074166837C4F79B1D75F104826EF21B435D2EDEFE696E59792113384F6E406E709BBA021ED973E07C370C760CFD6D87D9961C6E98BCDFEB6DD58D150219DF941C0039ECB6936D5772420EECAF3B6D257941F2926D0F6DD56C172007008E6C644E85BC926C566C216C97137242086CDFBA32901C35A56C1F18D297ECC660FE2D431DCE6B5D44E0B640AE25CD6B09A3139E54C112B0E3D31B57113846A2448BEF4D5760C2F2F2E8F33130E8831B0D0FF5CEEADEA4D860FD46F0D8EEF4733217ADDDB33510376EED027C34E74520D21B8340DD40A7480D33C20CC1DEE0E7CDF6F8DE48DE643BDA8DEE48E15A701D2948AB3F4E28653D0B7CD63C38A019E0CF2A6323079A516D5E34F04DE2A89B834045E34C22334B6D2382742C24CE8706B64A010741B206164E10D72D01ED0E084829893E1178B63E2E4620465DF2A6F870EB453088FB75859E7E6A3320033F5229F53FEFF6B2F281565F7F516A426A145248602AC844E3287146237B03B241D3633B08FE69E82300CF9369DE69EDA34C916070EE5CE937FEB88B09142A75BE25B1438340EF15C1C3A1546F314D3BC4FD8B81D5E1DF19485811CA1248892AFC2E9E0C1E9BCEF576162610FEC5C5819B3B2E483BF3742A488B2F9643032D4B102B8D692582EB78305798411E2F4BBC90CFB72D4D3BF4758FE76874125EDE870B8F1475F540C60DA75AA8A6F50D8BD43E23F1E880B0330E82D46C72A0B808261A89A544208168B925CDC8B19C6040480B4B1E68DF38803880759FDF70519DC0'
	$sHexData &= '7F652260AE127F0C0B2A01E9317FAD5334E86BD238ADC6B505BFA5551F5BD99101811B603B7B48B96540C0431FD17772B56E6925576734110E08B82949F96C080504164C4367030B69A4148E15105869192F390121819F5D3D3942020B994B040EA13CF3853F04C803849FC6BC0293A7421EF2DCD8B302004811023F284C6015636BA0AD00C0615F4A1485309F625515AA3F5F93198022FFB2DFA7E1C4447F7B3FDFE99C814076E73C954E851CA2E7D5B135DC630554041F030F848ABF1E03815475DFFFE8061E4102B0DFDC4AD4307F9FBA0C6151FF40A859C03F8A40AA5935350B5815B13705540158FF82543580BFFF8C63013F889170017F7B1444B52EA973F0A816EFF5A7003175271E3A6E81022B2309D2A8EAC9DFA9324278035B404601CB25A4C9C98099F6EEA8CB8A14F04516A0380111001EC8B5A955028B5EE0A808052CD33344F72860D5981EFF0B298A55FF43A9308027FF032B411CC8900020945735821135204D3B80A65DE8008010B04D968866523F3471B9C801751B87E4794C8BE05875CAAEB5001898B48D7C345EDE8D48065F180606B8C684B6135C904679B77D0B2F98EB4804500464B80840DF60021E309019F93EF800CD49FB474CDAEFC96E1CDD560704B7B0FEB39A6F018F44C6BD45934CE0294F22302B5051640AD530483F160BC003C63541604C04150C4CCFC07F13124713722863A9522A8060259513E80090E85A5529FFFFD04002095FD7D56C6B1707DD16B522B948894F2214B0223FE50C8E8430111F54452014FF8021A058BFD93AA80195D541B5ED121033FD8746B0A73E1ED81F059C48509F02394532F8FDA72B9201991FD505E251C885A7392CAB0A3140BF035FC54215123F9F80A1A90B992E07DA0240B891EBA9A002AD28461C85FBBF8837803736C20E3D6A15BC405F7F100218117F9F4FAB10C00567DFAB12C0F218080F935F2A74D4681FDE9F864A562271C380B0DB02BFAC8C071DFF889FED084AC505500B6CCAC18403D5FB02809263025794625D9744412D0A87B5B40F4F68DCDB128C42ECAE70A918092BC1634A9796E96F12837C19F29C4C98019D80190F0E684A66C8E2140E4ACD560838016844182961159403BD3D488B41D23F015F1005C9855C10104E00A1623F3F80851C28E7A25C024623DFBF03780307C12A4691AD75911F8380D70067F9970E02C4C28485E4200601A71E791A4C2638815F26043C08232301188C187F2BE0810DBB8D408D400437CFC30D870933C041444102954E6F0077E9BF04A8A500E26AA52301925CFABDD03202B65A4D683608DB7503203B988C3B020E3724021F37CA35E7CD2B01254841833C51CFCD02043AF2D07745300C85CA21F831862E310B38F0F3CFD802B38004F7DDBAAD374091B'
	$sHexData &= '5DC1F3653EA31BFF91E77424560C8C0D5F1A336D4603ABC74CFADA606069A66DB0D8E2D461FA1CF7C016BD4D2A7771DDCD6A20A1FBF74465FDB204FC8720B5D1A78097A2806731A5DBD71C858EC45F3017C4B6070B6505309E0BA1FEEBF83063004C2CD0749E8512028EF1EE8488D4567402580C92DD5C3988CFC18FF15679F0AE6100A18100B8907B0384A00E56F64B0602860408863C420E02E7E1062EF0F02A176C33F5F6A0E53F53833EDED69613629E920D0420F4A54C809D82CE0C855EA203022734C4E8683809010553002140879285707812131385538148180253FEC06705EDA9D5F94B0BA015903EB5A151FBF2507D7AA7FFF1CD275FFCB104288140142C64401E8F8B6425C6FA1B78AFF5B57B68EBF584DED67AE6F94F9FDB688041F8A1F5240E232F743420AB95F10B1AD8315BF5778651CBC0AEAC06D45199C1AB9C2EA9E903508B858369FE32904ACAA7F395A495D9DE93FEB504FA2C15018F81E8B48399F0E772BF07B5C5D1A16FE39431CC35EEDA27EC6043E004959BFADD1C6A8354287B80C086A6C8F68BE42C90F2E3010D8E3F6D687D1EA2677A2B543BE770E28BC2DACDC448BF837DA526D058E6C010D2CC26B493E5181480F46CAC4613056A6A94668BEE545A9EAEA28A90D65E87AED1B28D44B608973F6D760C1C591C248CD2B7A2E0002D494EBB3360A40AA0A1F3B730583038E905E52F7C0CB2A61622D9BEC3CB26C8A52BFDA8CEAB8E0B4AAF2073B21398CD85495F7782A5C4BF0462E47C0BAD2C311F8723FE70A08304154A9D3AA4A464A10BB07A6BB2385FCC4BF7D3542AAD2330081D6D68E543D7ABAD6BA2C3B8C658D8A9FDFEB277514F455CF0A2C79C1949B1F00FF2EE448AE10100F059EE448FF83CD0FDD8006485819A78009F98099024C9614705581BDCC3929C0604B3A424209000919020416F24C5F402895248490BB15072A014FE5B602131595205C32205ECE77A4A3D51E949706BFB77BAB04640F302313922F2B953138649484B30203E4851C6094AE4C0434ED92D717DC0E49B510602AB2CEB146D02A01E0CBE5E4510CCFDF1F7DB090097919B00594102EE4819CAE935FAD502939F248549374B264480EC950939E4B018410F200369357C081011AFCFE4D8D515D860AC07049504681BE2D0700314A632781B7E50DAAE2737CD0BA300BF26A2D54003A2F49592610D02562755F89FBBF49CC996700F3017525B3260EEBBCF98F494C2BC248BB4C0246E64180BF09D84B53FA530F9440A70331AF0892DE6437A08B1F60FC6F1E02771090E2C6C02153FCAE123E807906133269038149F100781366B7BE0F000E21AD0657ABD3F04E5E2438D45BE9026E8B09D2740D0802743F3C95A2129E3DA78104C021E84AF6CD1CF9C0D7384C8B'
	$sHexData &= 'C7DC95CA75BD048DF4CA807B728426245CF2217A587869996107E33F1874927B2918C641CD926EC26C8FFA417C9E0C91CAFCA8049C653940488947B2B186843FBD420163D511750613808B014CF7EB230F83A0149611454E4197B18BF310F77431448BD632A9F70891978046200E90436106A3B9E34804C6434B0BA915EE70BB8359DD35926301FE80A0A8AC95DECBE7448A64405FAA932018993ACB54004231C79D02363543018BEEF6C22B0FD990A94140412041687315803308792E402ECD4838221850905F3690DF302DBB1607D98E30F292AFA1B44C2FD09A3C053AD62A7BBFEB1962AB2B0A12CBD18F10920330FD1126128025837E409CEBAC23390C4926F1523361637DFF8CEB9259A0C24B35486DA817033B770F069781A7348B8FC61A7F0A567213F3375186542E27D591D2CA82AFC01D563D3F4981F837D239901F4AF84983C012C0DD4170203D7BB27E6906B001CF3F01C046B9BA258C3BC2C9584C8054210C600DD21EFFD31202ED9E3F2351E3A2BF483F0D16C64DFF5F610C943603C7BE843094D6D12010186A0C9F18AA80B4A3FF113DC7C3BA92117FABE4F28AFFD41CE802272945BF53D9C46AAB2DDF1F550BAB037F1FB0AA02581F1A81C915BE103F7D1377ACFF4A09C55E433147F6049F4224AFA4BF958EB6E822DF1FCA028162B27FA3B03456BF83B58D8E29ACD9E90341DCC6F220FE417FF202791050DC403C99583A004F7C5F02960E122B57154926996402030430996492050607B0B1F4102EEB23C0B550E8A4BF8204E37F19E0A84A3904C27507BBB388CF594A8B44C29616224AE96F6C09C35F518B0CC009C4C63A313F69A3F1CA4A607840A94951A7AE710C4C001E0245AB8A891F3F05922BAA9F10AC0320555FD6E9C814309E00CC7F1059438440BF40252FA23A2E7F368B841C15205F10C844801302C31F854D8DE455668A2E53C855FFF1A0EC97439E4985ECA0853200C82484124C72C9115084843281FC81E809021E31832EE490E6408440842B39B954E8F2F2935C8690ECA084834236983CEC0DE7831C493515FE8384200725938310C824974C50838220577232F2F2EC7926B91CA08382EC209964008382931C8C56B5230C248CA920ECC04D25B87D7F073919798FA1F1EC50FF97E3A6E51570810F82AD30D5AE1CC71F82C3F4807B387A0EE133AD378A79C66AEA1B62269DFF4C25F921E8090220F1000A304567C35F22C0A1403FBD5C5F460534E404520489B906A887B784DB173210059FCC057940322005E7847CB21C23865D0EA203E15ED0C68117AE0936240A90CE81681F41C854349FE0AC310A8E5F3E552003745FBEAA422AE487833F900142841F02C989900303A682034583429FA6A015279481DFB0520CDA5F1F88412B623F1FD'
	$sHexData &= '08200F24A1C3F17C8A1601F548C46FAC601900C533C5F0531E043F7FFD1F408AE5FBF4CDF35359257367FFE7A854C483030FF415C0DA24B3F1F27695B48291F3924CCD1ADDF1FE455DD72DDE70A7EC54555ABFF7D1F84D29257092F3F612527E4F52EE02E7C9E1A491FBB2E04B42EC06E1A459BA7278908B8D5420C7F5CFDDA0C4148163C0F781F75EABE38EF9066AF0D6C1272F0BC460F632E10524EFDB6DB025805421EF39F3D382CD302C0410316BB4C640B353F6D48C96611F8F12D111D0805FF3F1720ED611F2786D07618A0523C20D0770EDF205C50F72010B3BE0537AADF89DFB48754056CE86C8BF0A6E934301AD0FD34578288F621BD2AEA86802DD283012126B2BED7092A84FD50872E246D01E9924C8B55D1E81256C2C02C17AEEBEBA54261EB602C823BEB42EB4B86922BDFD561A3310611253E81B1455A6CDCEE582CEDBD913CE4E4FD4DCD48CAD34878A67AB3EDCD6C9F216CD5B203CD124F10863004A1285D82309CDF06C341292CA8B6F8BC201CDD104E99CBB39F25DCEEDD76364FC07C0E32B5AF15FA2BDD74183FBB7FB4A53DB1758D1CD972D3305F31002B9269BF142AE450967996745AC41FBF38923AC594DF522881939888872AA1470978912898CBE6E60D87C68D501D158B785572A00BFF4B7C79323189BF52C94985216926D2BB0400013026FEA4703101089CFACA72EC000C8001B6AE1D2456459FDF406115625F8247EAAD18C2C0AA00B962F144E1CAB80A20D427F026D650107523FE1B8507428E9DFE084341A22356D25B41C09520BF035985751FFE312887A22ABC211FDF1A76A7E45121B675B126C80979249D2688269C64E50463265C264F2616F279910D8A1F70B2B20A9BFFE21B260C2607744B77121273305D087118B170C287ECA29E2514B6B1257DABB62E9874789D27E14A01D90B7F902592431736897F4925ACEC3691FE31254A25352091AC3B251FDEA8BA809F1F98AC9C2A9F55884F6ECD244EDDFFC20C3F2D8640C810BF62694DE2DF067979559510DF8E7213219F08496BD0382A44A3BE74C6DFBF2D2BA7083FB586AF6C01EEC4A05F973FFF47803C573F95710224132185A2A835BAC13F921C62D2FFC2DCB949E1928DFF04712AE42880B66F0095952ABF84846B100B6FC768C24EE834335A38004F6C22DF411F394938F6460985F75F21BF545B0DABFFDF2B0FA8699F65835F6950200A2D7F2F8A0BA157BFBA6D06E05121566D9F0825AAAD1F8AB760D03F7801FE219F48252B27AD816767177470105F11AB7088A3148F9FACB3817B0BD9565298F4822A54107506BA2A82DDA7FF4C1E57845B966210AC805805109F90E334563F7FFEB3B1C91840F7DB25CF7305452820CEAD021A6D5F73D76C3C19F5DDF80AA3187A279FF4'
	$sHexData &= '32C6687F314B243E20D3C172438081451687D234012E3034E671FBF11B3B52503022065E4F07EEC9322215DB6E93C2F932385BBC43105A714973C38CDD32F00DE1FFB2768202F53C09868660F0A0AD000FC211D104F1DDD84A04C0CB68EE376F8086C6ED882D7C871E890C309C3F57850F60A5AA0C46C1226104A7DF3FC730568F68458679E10517139985903EC141B86693790DA9D116736430DC4643BD3B993007A9F201566518C80AE341EAA81DE19EB6485F88EE909CC1F8CD4DEBF8B3F166EF9978D23B0AEB0EC95EFEB2319622D6854E9670FAAF100BC2AA24EBB4C30EE3DB4D0819B06A9284DFE4236393067B64B19B83470AEC8E7736A6C0830DC762C234951C4B8963AA212824FC1F8A181281DEB19A61E1815F0AC253179F02205C558441F2D100DFE440DC5A9F50DC01F2A2E44F418E941C88E441E241E2C981425E5666C54C562CE405C54C69AA91C02AFF5F48A4AAD6BFDED4A9C17FFF18C00877668F800F300F5118490E8954AC3FFE18D145AC76DFFF842A24B6184A060709199809B10705205311FF9428A49A85C15732C944FFF2F2E8360E852572688506D4286977328500B0AAD9AD0730864C0AA94C6183CD0FB6C7071188435CD530B8191FE02E220884BFE0C040A14A7EE4C903AA9F548C533CE40172A2475E47B25E941C8847B2866005C98142C62C15582CE4C62C681F466015485FFFE30D4080FF4A1823084C2CDD6EB803E7B480A34318A705BC06E34B2897D0C032442B292D2075FD2FA6F32A81CB35F05E7F98EC40825E291005AC2E597F5FEA1056FF1F7EE90F40B5BC251ED95FA92C1256FE1573590354492DFF5D08A84721497C5FA700D395DF4C0A49A129F40264D1E90D090A1F2D2854E27303A69A78C0A8F81BBF49052C5D301E898D5A17AE16F0597F02A1935ADFB85A380E3F57F969059CA15A8C342D2B296338C0B7E6F18D7D526808003743200F80342ED1024BF1C012933415AD22461514D2B2FE24D75483D14240F1CC07606B80008A5E4E1C0F47542103F1EB1E1F5EC31274411BE58D522C49ECE6C915127AEA79F6310C18BAA956994837D63CB9CC486C9EF92EFB800EFD4651506EEF101278248B5C24674B0BEC1E0F3BB5922C4D20389D5B2E409C301F182230E806DFD3AA122BFFFF7F455C34569FC4AA0221DF10F2AEDDB9FF410BFCB54260DFFF010B6B81E484F10A7FAB02560D7FDF0590A0105FDFD502B4555FFFB501AB6B1FFF083F84A8DFDFC249A09E75408109815014685FBF0821F97C5F7D6D37538328703A37E9FFC85025956D53572E10C9514F3E00071E82961F1CAA905752018D5520558195BF393462549FFF4909420BAA923FE74B848A3F7F55690A7951C94F4FC553EA44943C533C55B15AC9A38A5FDD5109E'
	$sHexData &= '7040D3F0903A5E2D0AABF9F29B5882D9F29975E1202FCA6B202E409C0FA6C3106F1C3E43049893B2EA937FA41C01EF74F4A83A416B4C1840696AC2AB150AB700562F215D90396D04D51AB32A449D207D8EA3BF822818BD0C4D10F6A60032F224A8B040A92AA29FCA2784DBBCA75EDDB85B08AB03FBFB04A1E14DA4FAB0A24289FBF561903621FDE31004B84B6425F7F559402A23F1F849C9253214E85D6F2883842FF5A4D4B186D553FB4551815DFFB140236C9249303040506C531E8C24906459F21A7E455D14B35D4362079140A4B1FB45D112CDB172CCA90C10A1B9CF4DB041160DD8ADA2AC09FDF8460A15A9F3C848DB0FD7A4CCAAF1F3902382461279F9F373F3F8FFD033E97004FFD0331440258C8CB23474902FD03481E26593FC3D1030BA757AA1F2A05F2D1245FC3D003601532561F292D58553FBFA696BCD89FD0DACF210D96F074711C85BF004DC041B50D0C0CDC2B48D759487595971FC20C96E5FACF50AD82F376E01F6F204579F96829BD3D19429A21EE41200A4F691449E12CC41301418B00330DBC3022172CB4246FC37FF88890C43F4180B8272D38D0C50D2DE2C00AEC167DC7286D2FDA41B74E1680BB685191F85374DFF994708B66BF402C984754FF4002B0523B0DC7285FD5090A0F23BFC9C021A14F1840A1E32B7CF9DBC06901E64C71E2152D3C7F5D02DD7E600742035B68C5303805CE244D18082A1F26518328488B0656050C6C49783F4D8A511321A1A9305585A10307DFB8A884853F4FC04F00BFC2052F5C02BB0245E176832106187ADEA98B47100E1018A4B0D916D3267F385A100022009C1F927C921B5E51630248894938158C43026B910A68AC3050F8F9420A29E1CA15095C7451DD5C420EB51A3B3E01CACA0A84BE65F8BE94C9CB93CF77F7513E67433FF84F4C400B760CAB85C9742A3B01931E9F1408C29257D74A7F9ACB464E2187803D3C94F341F240568F3DE04008813CE4D93DAE3D81A5B5411FBC0461416326628525220E430C7DD1431346DF448B096A09A89054446E0A130D1B4EB80E5E4EC13F7A4E218792CA603CAC93E481BC5C5D6F3CC03F0879C883B93C8E3CC2780690FF12208272F99A43D68379044A6310420CE3CDD501DCF2183B0322161A068147A5BFDB0925300CCBD24912D229DFC9F748A49FB0C9D83CCCDDA789051F48D41B3861E74062B8BA01A4002B0EE285A88FA26ADB8915048E00213B495041F8BF26023E85771E1C7275F6E863BA20F1008C7C307E7E43F83741F4FE7E05492BFEEB02AE39041C04EEF954660ADF320918200F3CA7C201537C264C6F2D9D00464B41837C316AC56E01A61E4D763150C00C14D00114A85E99A170C5DA54F33B02094AB116651B2F8B44505E10F849E99C36BB0400B0FADD1B'
	$sHexData &= '026896301825C0613558E27B5B83F840742E1E3322D3DAE3CF7F780FB75431E4C648AC4CE17611899CF8744918CFEBD94310103808EAC1795E53FCE8D4443001A6835C4977C67527872E0805DA361C2C19675B91EA493CEE31280711ED8242D6AB8B3B3028453CC217804B1C113B2D0898CD0CAA39B811B89D413FED3A26905F1827CE084A8B4C29700440305C1D4238041231C440656E20112D7F421850E88754FA0CCCBF080BBD001F33F6AC14360B6E1032FFC50350A37D4AD1ED80F1500DEA2934ECEE78C3E394D080D93F0C3B1204870867DE3E803807857704AB3BF575E7943C36E578EB034C894683C660B59E0199C3E3004C51DF025C05C1DB2C6B3F5F4A18914C2E0162950A7F68BA16420AE746170964698BBF99820E28BCC6204D0422E074E6503EBA9CFCC9006622498B42161FC6F661DD321A4DCCCAB423E30701EB15495126122244D2D5D26CCBF803B50ED507DAB20A28AB52C28F38E63735202C4CAE58E0C7388871CEFC3C439EB8683F498BD890E9A281033D109190AAA57FC5CB58402045799130317F51E45110752091D028E0189490DFE2125632009F8C459B301F5F2F0522C4FFF07AC373913A9003F25DD9D044B056FE393F186D10702C0B4EB08358425A23DB7587B6AE58530E326A233CA8BB202A4C293C1B7144C3A6D003D1400E0E528B5C08AD02405FF71F540A9F170DF94F02F88ECC709908D2B37E11E3BD19B7894ADE0A230883E0A24E66C7425C101B3B2E1649138361F24A8B3F7F4205611A45DF601E50C0AA75C96B4A40E4A5D44AC2541F0252F5492C53C6068E85354A67BA0B11204C235039E97E93B04E1143C847C030140A4E573823D0EC0127A0834B6720C41E2290E4380141608D4FC6D34C98665651A9746336251350709DEEC3946FB180782D01CF33CB599F529EC6984A4D5E0D6B071F73380F2F6C6E5BBE335EB6724F36B7288CCB97A8F30C3084E0431C0BC044EC0D9BD79BD60322A9DCD58F5BB181123E3C5B7C626EFF92D680AEBF6DC5DED42B99C5C687AF1F424168E436233BF0740B9AF7BEC7F0FFE13EC646080006019A6FFDCF931692558F0B4CD7AB14B51356EB0EBB5905E808379A5801681AC90360015FA007543DF24DEE4906D1C1C20CBD98B3EE05BCA0D77C1EBCFC01129EB0D3B64C8BC349AD25A0DD4903D85CC2E5481340B0E86BCB38EB1CDEB04D0612510EFDDF442B614DD20E66780896804BD2DCD1CC0968C0A099AAE9BCA4186B80BA689CBF90533186B58531C4B85B31EC1B00D416C3A4F259395A9633E98D311EBC185372DE3468C1D83112099083AD313704BC06B6090602206F0870B210A9225DD281519F492BA1E22A09203B2A9B429246321280158536395F08B1A4A5FF607CB261B720A97C5DBE0'
	$sHexData &= 'B86501D50D3D472517D215DB9405530850E8EA440D2F087762D6A798086BD4D0D5076FA1B40CD734E420660155D9C0015DB469A230F05E44FF9F89A2C2440251140ACC437490E0A53483FC843431E4CF462BD5488C222594909475AA70446FDCA502A65290307EC30C039012358C61691AC1E809500D3A4F0314568BACCA296F421B1178D5304FF10C617EE2E40880FF0D715E365F41B5507228BD9EB0FDD52CF2265531F884F86803C653B21E1802A4A23C711422E4CDA7089401EC09F0DBCA14A0EC9154A234C0072A2097F0ABB72289047264F30DC913C08393248B5BC569780009F831857A65FF3185C9BC049100C2709A9B2D02C0CC2DF21CDB318FE0410C2E932223F213F96BD58C8276C5B3F03208F9A21BC1F6AB8212F404EC930BF4D2D46A0E413315F20260A605F207EC8430EC1F5EE2BEA1D72C87CFFC5FAF525CBA1331EE4567270C80ADFEAC66E020B17B36C0880A13F400A2157006A58C5743F1F1472687BE2038CE20300D40D2148360C856480BF2DC13D015AF68903AD9C78947193845D40A41580BA283AF332B71707B5F88CD40DE5E1FC0840B57DB8F9C14883F8887A44BC084358A22872EF16C2C5260DB75A2EA00D0D207D40C910B00250A78A97F588A8155C13C3191F0D8D48A35F623C043DEC6A805B7A01AE8D4CEC4B8F061EED43CB56150D67CB1F3A1761B537B350F224CB422D1640A005D9B40949FC49BBC4C33064980D5903CBBAB690384EC93A211031544B49657E1062181E687CF162816C2B8A7201624F10E8704DC4A848491ED4DEB24603D4685B5068C0AC114826C65D82CC22034004E455C4CDAC048C2CC2760CB7DB49B5811E103629C3506A032D2969F3815913488D58E3E0B3E2816006CCE6EB2096CE2B76C897859612D83B667B486B022130F03C76DD95B59BE78D341F166E1E66480928A5291A400506054E00FC2E8547758B40288946288493F4484D2A0A7604A8031B0FC6170E99F2C08FD6282D7CE907DC37738647CE27904872A13D99B85F28FB7007310A48E077652CB16232FB10B96EE36D7E773BA88646248E4BC0768968D21141AA47D6A64FE0561C29C003C73E3430A9E06011A42A0DA8125ED40CDF2B122C0D45FF9BA027105D6329400311B911E4EE264A74502BAEFDBC7BB22514300860A56324FC3EA6C17ECB840B037BCF2BCAC36860BD96D88D70DE1D57ADA7987CD166C18A9AC862699E34480A48480B0F84A7A860855DD74A8664622349273D0E1CDDF9C495EB147D0DC6028F2573DA04243708DE80F1178904ABB6BC4D3BF0E09280007CD81D9CA3740E140E5B3170126F82D0014D2BC6C6851DE721A2312C071948468AF457FC3C3E0C2C26B3B20FB4607029A718DDC6C0BBF821BB48A85691174F2075B2CA28'
	$sHexData &= '8944D5C4D64C9F96D608219F926661724D61492521ACA0955F091EC054239CE7DB155E80025E700110FA4C219B8ECD2BF8710836F0FE04E3842DDA0FCCF12980ED06A2E3F1F129C81E04160D211DAB5AA4E8AAE50400D566E2951C2A740E053A26BB061B848B27075AD766E7F8A048F04D683FBE060E81D7A421F55245E5A4F11070B214967836497EA935968E50BD0B44E26EFB7545D8D4142E9C7446103587266E691ECC3EAE3D461A582465A7EA74AC43893BE6E6E5699A9BF773084A2F430391E42A438BF1F630487C2AED43A826FEE6D84CD49646409FC5FC5AC711C35F61307CBC3C7E23F21D2A224CAB01937F290549B862EA86C7B2F259F0832A3C220EC4C3026F3ED8AD10C7BA5D49816621B3D0F1DAF82A5F15CF0468D72A4D54C0D1C8013940C983233A8C911C1542DDB7A0033B4EE6E03C4D341E1009B7412607218E3C041E12DA7B02103A144C3514497811049C4AA32C2436BF031F73AAEA7416488BD52F2C6BD2FEE12774204C03C324CD75A589F39F3DC30F821C24D3B7E03FEEF2F204B5A1971F0A1F6A3E8E05F377F8311C109679C6815E953AD7E1796B24BDDA6C7F26ACA602DF88409EAB105F504824CDA56B3836F9EAE8037972C80507852493448C9205578054BA30E0DE05C1BB2E92175E23286CE5E006102B9A4E2B887E20790B46D443E049F9F3050FC9C765B04CB5509E4B384C49DEF1DEBD0E084DA246692690E4886BD5097D342E2C4691EDE265C5036906C5507122F34E441C589F873D15C80B4A3B214CC803792FEC2FECBEAC9753905820DC5C3542233ABF1F2DAD0AA05FA5B436BAE53D7F64D0C7237A770AA8A407992810BD6B18C844E2F16CEEB30319F48E2496B837AA3A889A8A0AF6FAFF2CE8A14ABA8649F854BF200A2B1DB0D08A3B750CE26E4C4082A62808A91D749D4463FB1874D0463631CEEB0A945DA9414DCACE2ECE38701C59061D04493609D6208E21551A5120E18945C2EB08D39281DA388A34A5140D87E111F062BA84A539D55A7F7ED23C388269783A3FF2944D3A3F587A14B1E4540691D8A9B4AE75350CB589A8541B87551FFCCA18BD2C29570441E8F28E02FE9E28C2F85A75E2EB5C6A07C818A91E5F21C39E99C3DDD6213C12F1D6CF4603CF170BC2ADDB440B18A94C5434D8A40B08C31821E43E0651DAF06DF04CF30C0C1AA2FB43833E1AF063E96D8D0CC7183CC2169F84B9282A6E3A4FD3B0124606035DD2CB0788F82C5A1DDE8CC78A50A23F9EEEC74A468BAD78DEE6F418978C014D406408D2419B0C15D022B809641819072E19114E30C4960E2F0AD255A60EC9111C74092D3DAAF549081A6DFF04F9438E66D74C8B77084D4B229D4142D01B75C0626FD8F98B5C00EB8B3102D225170255F60C5CABD31649F6C'
	$sHexData &= 'E8E2D02B1A54E6331408F10125911AC48C500D4D25E5B7F0A0355F20884BF524282033A6D1BDF282DA5DA7903806B222CCC04480788239C34565EB5D214A04BEEFCBA31F95E0AD0124F013CC22BD0955C215FC849B9C206F7D2CAD18E9EDA40C57780F3003230484F623214E0197A2047C1CD302713484882CE010201264D3F05701082E046C9C58C13208E978B1B2020CFC0C8414C8BDC667C90C34D892C1F621F080933D0520D9E0C0A0C40E5D943469A4428101010D08C55C2C3994ADDE4E5313C4718244161943A27BF4C335B7244D778BD4714789E2F07D5C04830C3DAD54A8FDB9F78BFD2192825F6633815335EB6A5F718E11CDF0CC65BC0E9043F2B541A0829857058782CE748D1E882056585969A529606495B7068258C971F53689B561FB1074EE04F212F4A28977A663E53361048202A3A20E23D2D1D5A2855016628C501ED5F807033145540580AC8DDE63CA003037210165B2590092C5D8D5B4FA50EB0E97045A95E344F2E40D6A576FBAC578010588A639D849557A5B82C5212A54205B018085E9FA64E0F2A5023CF0BC32CB80B78C0EB0797DF382570714877406D141028C0BF207710FA1E18FF0B1083E40487162604333AC5CF18516108E97F858F1170297F67EDD3124F2020F73030C39F0F79D018DFE626790900BD50FAD710E13228D5293CA001C8C9B4BAA3500F587D93184903165178882CC1E9C0B2EECB09540D3ABEA61E856F3BFAF29332490480E196E149C04DC0AB4087248113C034FF8D6399F7C83411483BF7F78E24D473DD6BC638B424C2D8461E70840F312703DE480D93D28B0698DD48D2D11499695322850FA86BD6F19E544960D3D30828906000B8A6518233F09D2F0189BCB7EDA687CE38D30F323C901ECE1DFAA275543D29C42AC2A12074E4BC312498D594762611D62230D897EC59B802D75DC30A6BDF3869AB449CE450C1465F531B452C11E0A214A0FF65E26509835E131E4261FB22CAE62C35308E4B7A540FC243501A41A61C56703C342E470763C84720C50490BF0AAB774795ED498B4E15804752DC8D6A3503C954A1604704FD48159E1EAD3CFD48FD405EE1A2E66BC73833F91460AAE32A9F1C908113B0AAB0391C00B17EA8506BF63889AA95A7BBC17CEC441E041108080CF7E0A93C0C10108C1E2809961A2B07FB32B67996417031C81A28741096E72830902287E9530A560E4CC2761AA8A2E096D72708384DD1D2548224CF3ECFC5308E8E3A3629258965F00AFD743E2E36E17BC720D6284D222657415C5E7FEA9081551F1818221CB099174058F0546FF1F033F0280532F5EE164D9F424AD8FC7A08DF47F889033431AE6808FC16048B070814047B0C17D00CC0188D5706221288C24BABD5C608CF8B6CDC8D9A45DCA04FA0'
	$sHexData &= 'CE75C18B120D3230450525A3BE47E659FAA8A3E579BAEF69E80796C08E6FFD0236E850009BA3728698584716C07BD23F1E8724A10F218F3A082EBEC06725CCC9C3C3B034852880371A578BD60DD422D2239851C9DE88D168BB3CCAAF4C2BC53985D624C302C5F0581A418497C200323225370E56522C4D322D9F2D25FCD0813C50435C5AA71F7533353D0F869C40681DF22DDA12FA454CBA49BA9DBD07733BAD8B7174B81DC522B6E536902D699694AEA23FE9D46D019C221F3F85459458FF33297CC55FB64320AB2A12BE3020499F8A040710289B91B053406B9B5B72845C0404752B399170069B9BBC254A0592046975A9BB587E4E8906690C504174CB689F36078A8495A3FC0CD000792AC0C8A03505A916B6AC1C167E7324AC6CE8AA7C226115255F9B7032E5523432B90308919DE1EADE20CFE6D532FC28CD275AF2221293C2DC480855D2AD838664A0933CB6428E84D7B0143540A5E5913C1295C4D90B40B7A2E8E75CDF5E8D50A0067F3E09B5B0A690274CC7C9590CE1454D3EE1C4E4B824870B8133F20C7EC64949ED8A6037610DC33FE81A900C089F3456C0F0166C9F346146A03FEC9A484CAE52498BF9B742A444304567090A50F0A79FD3082911DF2F12EB185AC8920356C790FEF561B94B9ED6BD4D2032C55BC55512703E9660261110E43014F4949901BDA9BC4A741C66904A21A4BB0536C57348F2E1EBF9724983C04C3BC14E26C79F96984D9F5C010F836788216DD89F0D837B405B62953FDF6DE60443F7F704D978E60C13DA1066391056A6E12A48A1F1C6F874114F80FB76694020CD24CC8430973155010C4C6ACF60E8982135DEA263C1602E8971DF66000E433EA44966D652CD20C7905CCAD0C21CC8F3344141C1C1B1D02A963F6613B890533B7490BC8A140F2BE8D8F1514200F28A95FFA09B55A09BA040B7893C7E701100C033AC1FBF5337A48B3C45B94E0DE93625905F0AAF1679DEBB756268671443F918D208E424FF741491A318D223D348C801F2D6482BD3CBA492B8A29120D228EBB0C03A4C301B4AF2064E487780741266FFEA5C4DE748C15F7C1CAC65C0BBD27D42DA01407749C20DD09E6E618A3B8BC3BED2C36B9D0BF63DCD165C1C51BF27A422230802E12E86643414BFFE7E741C13D25A4891366339E4E6E9221F5B329C90F71B6E80EFE3B5C8C3899BBCEB85AD7D099BFFB98C7146BB4C374E10375A36B8B32C91EEF902A3255B089FF1E61C69182F4E8DB52E36D23C32CFC907BE773C47DF255CD564A5E8770E982A27B8171EEDCDD837C8B0B01A7AF0012B102710A109FEBA81034ED123733052C5B879A91C4E1005224ECB5E18D43E417AC2387245101E2A442C86F1406DB626194A0DEB781DA59D1E9604DDD68368F024C6ACCEAE2FE'
	$sHexData &= '15B387EDB0982997AA547EA1FB69844A47F5F9AD144A87F60A38914C27B77B9AE437A218CB1F1449A8A001D56E05EFE90909984F926CEB72FBB09FBFD0D9E26C050018B46A6D26411867848F81287C61CF9A6680E807824F35D534B7C520E5E450D7718954A40F84559754E010B873BC603D300955E97E2A81638553B610B87F1C52547C46535BDC8167E1DD6B6031993FDA88C05D4C4B7E1C08B4D8DB912AC0F985D811E477D2818DC4C6015421F009552513FD601DF8623A115053A021A7EB63F8D55B5553F6B4815915F7F0F3256051F773BC3C2E442B2035E1ABAD9838C7A100F0D1FC3412CA8127F0D5E4B8A7E20DAD4BCC4AA2865C548D0B1E5B1FFDD8EADA34ADF1CC782D184273DF990B111DAFFBFB064A34EC8DE408876562A077AC8FDA00CED44E310D828AE60629C8C138D108AFAD42E2C68D0A4394918B9A031D6DE4874052230D1052887303EF9D220F5EEAE0929143F3BE07444DBB2160EEE588D7941631B66EEFFCEFDC8C697A8274D23C65D43188188FF629600F006867D97C20B7C846428AC2490D310AD232A8CF93518681C07090EEDA8E700B65A3C4EC758F2053D3E0640AC14B10B9F0B118FA50928729A42D86C59CC1B94CE58C3BFB92B2CB118D07F3EAE505C9253419F86B00EA1E2F9A041488B2AE0391515471A104171A17CFE493BC474434860483FB628CE51394C33321B641480C3D3E67A4206398A3F58492BE400994949711076515FC05018E9A65DB040F8855DBF6C47C0442B68551F75F99542DE40D5374883C1ACCB5787EF92FC01098B2AB03AE9BF2307E45CFF5AAD30AD284851C891AD30AD0BB0221B2D02BE83581BCA2150DE006E4E505B4DAC207BE241BC4CEE185E068E8A4CC06B88B5E50E32A5458BE80621271927A07651745269E4F39F44E475054D8BE0242464466092D1195453DD24C39A1D5DC8304FC4072AAD846CA8D13A923A1310901A62E185B85FD6342A0B5E08484D6C642C15324848CDB7029E9FB027CD3C524101B7C8A8FB74298B1A05050C849170D254C918434303E91B58373D33A436CAB898F6758F497C62C195318B3FE37BC3693A40AC6F698906049D34C6404626CBD686705E8B4FA8A6E4C206DA50C3E2184501DF1F62E40870AE81E150F9EA636DEA0B7019F1F1600D28F12A19C7B382DC11E964101832954C4957E1748681AC4CC1AF97C3E41849471E6C1913C8957C12CDCEC9280372204B0B64E878490CFFC51FEEB43A16242525D274FCA20F781E0E4E18687C506BC1383DD0C468C0B7A890B188FF5FEB50419EAD7F037129A4EF402806D84D6821E3754277B135E640803C505F16FF01983C15F202B08C28F601055615C89F7F00182547955101308A9F1F2A440670C487995A520DBAA892CD86D6965D'
	$sHexData &= 'EA48C801145A07D2C963158C5339C5124D5BAE0AC65B195B48180F424CCA24F35292012A63404E158C9EBF40594212732A8858D6F9FF18E71A94F4BE650D992A61203155C1D8A55D771506B032D05B560D2B463FFF8955C5325FD1A555959FDF829E0A6D7FFED68762651F03450FB7E1C73A183004FA720CB537565B9ED4581068174D8D7E8490A3900160091AEB252C1CB1621D8233B59525AC3F43B1DDF8FD4D03F69681186B2C1C4855424A2E2350AA248258AF843EB43E02396B6DC83F1AFF15F9F10189ACC536164F832C27687258581FD848AC585D1FDFB8C012A3171618F18B4782021678B7300D131C064A30CCF1A43CACEAD62013FAE4984A4E84B729FC90825170ED360C31455835CE71D17458DF51443B1708254D07300E6DB8156A83270312070390860A70561C1623A82665F08456C4DBB701CCD3544CEB215F556001797AA08B695CFFA4202EF9B6E1482BC5B8BC62F2A72D157118534C8D7D4232D24D88CBC37093B828575889C655211C233979169C464DAD0B9BC40530102FDF24D6D4694A0B7844A62032FC88242FC6442F74FF1851A42D79EE85478129EAA5E360F15C14143AA333EC3C5F0BA499A63F28FF826992CABA21600F35075198B82067BA8C5EA9861AE5E0EB131F369C00EB4541D1CB470FE4F210722D5501EB204DC9412320E13CA28BB528E174EDC0072CACA99E550583ACB4BF38BFFFC72CE9F3179002BDC9BBAA397948C9307ECFC707221323E75C24C1706198707589C422904EBB63B7442A185D3B7CA4314FC35FC0C6BF3C339A7ECB45969A0F87543EC5B0E100B544C420CF64206AE8B343D6279B4F91E690E6F947F9CFBCD4269B222BECA199AC07E3540A1E23983CC0156D017C5024964AEE84BB7114A5AEFFDFBAE08069223709DCC7D16A5C49DFF14D4029E1400C49E3A241C6E064EB8C7FC52C2212BF58C42C621F89676C21A2E1BD43077D41EA816FFA5B8D590E0B4D6CF81A136D5DD02A19E84D37FEC6767322C7031173E80EF6023905E66A3BC775A99AF974867BD3CDB2524AEA871046C1FF1E695A8E4E003540A70D7CD03E0BA30416C904F89A20FD5A85DF75BCEF377850DDDF7D89217430103A2C0FD91E38A468A67B1C55DE14D90333FC20AD39C39A4185153FE9403254C1FFE0164235689F450862D5BF1FE3207958FE770B7901F249EC3C2C495CA40214D309CB29A934F218B3C5E75C0B5855FF56CD2E10A9EB079F51584422C9C18E08A13FC39FB03461184866102CBE00702BD94CCCB60A0E160BEEEB034A4D3CD91E6F9780526E26FB02724B0CCC12CE045E560A4A0CC12A8C2EEAE143EBC87336B0893C248CFE132514527FA8C699B813C2F7A7496A48645827A0D8EA6642E2AB4C03145C7ECB7418F82CC056DF0'
	$sHexData &= '49E024DD0E1330B9C2E75EE94985CC171BC5F3814878AD03FE7E5BB52155B585F80FC80D01F9FC293D24C04323038D00BA2E504FAE49F1AB04A9E3F8D1FCC09E40A282FE41AB1AA86FFBF05F20899FEC53941A100C9077F537A1032C9C4F12FA5C6A859CEC14F8AFC11052236FA4D8D24181846A908F400FAA0440B3550438D591194424665C7CC1911947898C54189061BF1569BFC23FF159DE2AB9B800FAD2A1D1181A441449F9FA1826051BF261922097F0810C92B844E08C54B189022CE101F304A75A03D3CE0E5FB5549381B3EDF05238473EABF80019734C35F2C3508C3250F5DFF1858B5515FCC8F15555FF7D23030793EF0C2EAE3E36C2E9DC80149B2C0128299C0403E6C110881C9FF9F4E0308157F534D110B9F09053C4FC9E401C3DC01F405A575C1E60F7FAA1681453FC82A5129FEDD01E86258570281F90AA3CB9A1FC25FAA02D06645DF08C300391E8F83DAC469C05A9FAAB09192AD1F34D3BA37362006AA420D6DA78C4A36AEC7421CD470FE23448942FF2217A72085AB84DB05412A46515F7EF83910CE20BE4A4930C35CB272839FD496699AD67E040A08080CDEF3DD4BCEAAB728307618ACF39275CB7229BC4697C9EA9A8D15239FB34AAB68C705BFAB5AA02E7F7FC43900157FC4D94D583159FF1E5346C8502022515C670A35297F83622339C7D8DF61140D9357DF45601E75FFBCD7FF8522F146C9DF1819980C0C82B4351409DF41A58445F21F58FF205FC0773452CD663BD0730CA032B1D136803C68131A54860D04F084FB642441B94B1E6814D1B81F3613036CDF6FA1C202C60408014675E76B6A0458015616714DA90318204B49308141915F0B85B6A81F5F709F642E13E73AD165752B4E30496A1C1073AFD04FC9191E8EC6108FE904A04C6DBA04498A1178140C9F8911AB185E4617FE005F3C485A05DFC7BC4A5E11DFBFCF9ACF0A915C81E03471342A5F56E9B6A0A4F0B8BF7FA9107202430C01C10BA53F2BDF296AAD828D1F2E8535019FDE010E250C429F65D51806A8BE7FCE84548389BF44E93C21E14D8BF05A8A01D2EE5C54017042226EE28AD20A55F38938A40AC0EC3BC7DA3E7507FD1C7B27188C1054525384648180F8A0A6D242098F69BFCAD02CA42005493AE88552B8292901725D02787709B9F80DA61E84A2913F497641764D24962D7CE8A6B06A3FFF929B89C51E265248B9BEAA11C2DF9AD1011770A4427F45CD109695E63FCC5FC810C841FCAF1C70804CB7A191B95CC512DF3F029E59540A55D55803A111404C4616F54C0824D9A2842E290E20C3FF021A4584FF325048C5FECFE488650AE4CAF9420E293D18EC3D97A3B4AE369D2BF57CEC086C0CE7046D03FD33C7392177237B8FCE1F5A2123570F04B444F2A2DF2E9C3F7AAD'
	$sHexData &= '226DD7DFF0105085DA91DD634500E4ABCDDF3ED05504DF1DE3750B8A5804E31EE3051CCE8DE91D773FE4A864E525E21FC8CC4606420EE0050532819C4A6FCC0722390532052F2C13C810722F2C07079203803C058BCB954774AD1F35E02F0092A192C6BE480E01F27FCA2FEC0D20949C2FEC0E14D7BA1F3F8BC93F71204005DEFEFFC315A54324504C6F6280E4034C2BD14939249D7871E78D0CE04B4EC84FB821DB4B38C8C9049C50DF02EAC4626BE7DFD4129A341E48E91E8116E44050BECA5FCD1100859EC8114AE149072F1110C61846E302BA542DD19F2A3AF766A9FF7F017D6F84E2A7041C286A83E149112305A183757F15E2286C2F60037F0AAB9057DAC64EC1A055BF1F75DB420E957C6FC1BF4C9D035134379CC5448000111FFFEA7889E4313C3F7F8400C9099AC4BA10101A7F0A4115E0B0013F67A6ADAD1DA03E1B5F9797FC051FB275887580F55A92977588753C691D0B0BA0B0BF3C0282155F9F7A743972E48050744874507445A8B503311D3F5A505A0F496BC09C34048776E79F58D634A0360DFD8541D4860D87FAC2C7B56BC53893103B43B7DC43F36BC638249A12D78BF924C285FF187101C0C528A65181A9FF197A8B64323F55A515307FBFC8A39253C1C0F5484EC081047F35D51A0A957C2FBB408828110F8126B908E97E92B6B68291BC485CBF293BAC55147FFD16C951447FFCD1C4B4D03FD5C3D3B008B9DF0878040BE04058B98FDF940D6AD42ABEDF318A036B265F1F108B18B0DF0BC4220E1F5A34E1A83F019F85168888FF1F9F929537DF15D2BFB783CA074922009B88B9A91204A6B98977D67849A9E89A8A1C0F98D08ADBC05DADB87F22A824AC1F2BA45AD61E1801A103000F7F24E2E55FC16643833C48F08CBDABA6C01FE648D8C0314056DEB09FDFA5D04FB6448AA4190FFFE2614D053F1AC87000CA40FF9812F243C2F54883EAA4809030FF139A7C29BF430C21010775BF225096C0514902BF1017902EAD1FB1EA02B6BF9F8FB0AA12BFB9E9B40619383F952614AEA012C50A8B6106D646BF9F808355A8C37F5F06B0011A1F077F012A58B35F7F3628D0527E7F7F4AD12685BE284C1FB46A03553FC39F8C4B251A9F192756BB14AB1F1F268C8E503FBF5D2155B01F3F135841051F014DD611F38B2AF1225A1BC49039555E41BFDE245BC824F15F52FAB292256C090F7F433335F50B89457EFAB822F000C575DC485B151613B0761DA44E72F8773859C28614AEF77796C369BD5A6EFE492BFF4E9190D6031EFE4C9B048A093724604E12EA06A6391CE2D7C606DE71A377DA37EFDF261AADC7B04761006EB589335FF6090C0ED61C1732C85BD23B5D5DC3731916464B35CD4D0814D25636349C3D4D37D7A09FFB44B9FA54E889CE3087CF3C27A'
	$sHexData &= 'D774C39FD11E313181CD524A5E5A6C93852A3E94F984805819FA60681749E7B3370225ECAE42F2B4CA41A8113082E0A1305CC5F36AAE48AE01F58B555D59F7F25AD2AC1FF04C6A0989F5F7C82C3586404504C20F1B705B542FF69BC61A513F65E0675691E3E3D4AE6E3B61600C081B6CED69014F24D68ABF56BC376D223C8CDDA5A6DAF6BC8D9D016EB9E4D48D343C9B2CA8000C0B9B83C3B366995E64910D6CED3B9431C26117FC3CD570818DFB9C9014276CC0B2302A341449C884129087F03C400119F44725204E22245A2454428A6B576CEDD3FCFA63E10D20B35050C6A5A85442016215F3B04E26469BE430C0A563F1D6E759248051F1F6BC4221A5F159A08B249F07C39E50BE4428EC26103D364039F8A7CF2CA6403BE6403FC81843471BB65943EAAA3018F71CF833C9E64036265036B0C4440AE7445B628C436A0811F1F135A14D0BF7940291AD7F16AC14158597A3CECC778C535A43349014031496C964EAA01FB014C7C1D48C1A2B74C0C4857C61797D482147F653C1851029F0ABEC6234C1CB1686D000E324710E35D035808E3E52F205F829F9811CE5910AB26535F9F52B4065B6FBE39CDEA08202301DFF21552B8481F0C370311F141203D004C72A9F760AC90A9DA3848051618ED279E7F8A4062441FF0C6653D7A36492C28052D126013E3113B40621CBBFCDCDC49D0D75E0399AE01CA5E0390B8A287BD5EAB406105030A153F800A446CFF6CA10A82DED0EA546CC1DC0588D7042097E6F876F8FE39E451F207A901FB8FBE4A165B387446746C6EC1FB7964A801F0754A7F9F5BDE07B99227364583CB04572D4CC516953F67254D9E628FD37CEED2329F30CFA71EA0D65C6CA1F250BE94F188E4E729A97C18A801B1A6014789386DCF94F4BA2164620BEF39B0460D9080FF3231E8B4BFD6B1E238555F57D48B8B26C9702038024355E6F87528153650F0622E24A444E0A381A5883DE1D8B84F5F72C16A8D210890B254CE055D3D05EE89883C84E0052DECBDFD99B7C75144A849AFB82B36146C18674D87625086C555B8C841BDFF08E02A8D85C0E97507D3247E1FFF3018CF751C123A139B7D20813E38E34B5D664F88720BBBB6D1DA443571EBD857185F30C134374713FA1144890C3BB3A8DB4866504802EBE1B44CC1B490E004BDA5431F0CD0FD10DF8BB28E2164C8061E597328E2D1D1B12C7503C802190BA60F52A9F8F10C24F2512211FF526997282CB5558055610F3FCA231C2121121ABF20118960EA39191642524830617540D9993000BFC72431355FC442E0094D60201724AE91C28BDA5DF068A4B0922763780EA0E5CEBEC506CA723C406D46EDD132E1053AFB2258576EAB3C3068589EE8EB6C08D2CBC273A9EC7BCB38EF80F65E0CBF9F04BEF00C30'
	$sHexData &= 'C765E1294A78C5D68D21873C288E501CB670D1B7054C4DEAC686D7C6D2612D0F44E000741835A140955F9F918181926380AD41CE8158A129307850E8051870A7F2D5616026013813C0AAA0881761EDF081350FF45CC9495018799ACAF9C1C830248027A3F7BF2CE105CA770875063AEB0ECF0C008BC6CC890301F79B5BCD648866066FA6EA2BCDC6AD6E023D262EF6FF13AF0302174D2BE949F7ED3FBB7E0721B47D3E2B58D80F875A83226D035FF41A07506AC1638442E0880DD6E78861DCD1E86819F97F836A9A3CF9F95F6BC7A39222032EFB095723E439A601CA4426F06FC02572C24C6BE8805150A8B4EB278329FC82CDC399EEAF3D30C88BD649A5963C750F1F918140670F807CC075154B0DA4139C8257064606CEC5A0189AC0459BCF1B6829BD095FCFEB20B09A1FC39A0603501BC4CDCE1661312A4740AC0F83AF690B2E46D456FB384CDDDFE9F59D0CBCCBE10C1DD3C2DB644D5B5EA4143717BA43001508902108EE04D0C2E5700C743D41CF6E2601D4F008460489040C08514FF334080C0C100295D627A48D56D04E26DCF76AFFC638814910947C5AD8562AB9EE5AB3B6F434A2C3C6633110C160C1276A0920089C855F136B3060F490E9E3E3786863181FE5FD9488090E1A1FE1562DA912CC9880682CC422564F45077E358A68082A8BCF3F5184468D4F83FA200F8E99800A13C2A05F1B40FB560E1FD492CCD393451C91357AB6818145EC74CDD1FB70D6B42184D91575BF52CEAD088F885376F3C03140D827F9C020EA7409F9B67A2BD7EFEABA614C1D39FE3C7D4B32EB6DE1E218D0C1DD8ECEF090CE1FF7CE88FABD2382758F4CEC12027C0E2903677706749569ECBB854C524407987B7EC63862036BBBBBC64CC1D52683F0A0FE1C3B9801080C9C2505C7AD28A5814950C903C0401A81DF1F4DD31ABE725BC88B43D0FACF0AD4D3D87660D334D7DCDBF3CEE0F3CDFB9930E943E80EE74B4BC5069AF84DC6530127EB11D953E8A131B8F582107E23E48805E2AE0CBD360D90920919DD063D0F2EA0DA377D8F1C1C0CC160F4325FC01F55B6B422F849C7C7D0BA2B871DADEEFFBB08AA3ABF4906AACBA5C1477ED08B01AB4646E46490934646464E96D291E7560656E82E0A210DD3F49B80870423B290CBEB255381604CE332324401603B3CE038009B14EE38E65F641B6E11BEAC03DE816E9BF8F405EC1EA0541C3A4D080CAD3F1A18E9A120EA0AEDD06A9B09EFAB03C4DA9F1F466A75409F1743B38501DAD7509E85582046F0B507114734A0619740F73584E70EB7021352384A628DD4C9AAB8C73FD1090333FFD0155299A4C1180D50F0601C5C0EA450CE900E68C02316B806C621B4B5A67518A8B8D002A69B9E334839B6708CD928241C531448C40FDF827085E'
	$sHexData &= '59E010063250C4A34C6257C88C8C8E56427BB4048680372D94C48B35C4050C8245721F2D019088A7320FFB3851CC9299CB4B680643563FF470E007274BA30DC8CB3A8925320B5BCA670AE429EA929FE9C1A07155F40199C24B9C25B97F90A98D9E1082D5CCB49BC63C409F5485E99030C693E885597F8119E4DACC603F0008121E4E53E01F3578DFF4803F90F1D48B833D4A38CE013CE823AE00BC83506AC6C9FA9C3420845D042F54B5CE11EC23BD1CC90D6BBB7C201886ADD901E0806D796CD34F6D2806DA3C92A8C900BB22272600A6F957D3C5078076B851593C5BD8B6A469E82EA48FDC5E8F5500110D8CACE8D0F6F820A2E0D88CD564693DC76D783C7FBC2B60E125F8E8D7F95A24F5DC647CD487007500536B0344F186F6B572D03D92F50204E6D9401C070DFB2D8C54E83780C13B83CC98A0A2B993785738881F20E8B68CE0C956FB642FD810C7DD849C7C6F8F3DE1C81CABF28FB3F470E5DE4820F157E76018B061EE419E44E6E462E8B4614F529586AD39CAC581552B17C555FC20A5421CBE6C30A077483433AEA7841B565203C332A2CB8C590AEE76026C0ACFC0DACFF150399FC98FF0B0A10A9FF0588115111EB42560E14854C964C4732813C524C2310C2038824BDA402C40BA2DB0A10C55A3E043AEB723109ACDEEF4B037C72F30415AD01AF9201B44B0311061EF7BD0C28240A108FD3A44BE5DA58BA25FE508541B73EC15B7F16144E05FF8BF1FB0585755139EB7124070524110A0F145621F90A8B0B23AD230E560785239B0F90A910047746612C5B1C83AB231D919A40DC057B40FA492C7150580F24C08233EDEC2EC3E2154A988010BF57DBA3907335211E0F85F812B01A044E093DE778E8509C124794AA29A13BD9012E908955D3C4C160C445CCDD182A348B5930E153D6A927EBDFBF270345209F68E048B8D2901C0B24CFCF119F4C483BCA79821EC910688B123AAC154CBD1F1019248C3FA08B21C09DD3EA68AF288C2A5C2BF2C4C7065CDA902B8BDE12169EC60A52725A2F83B160CC02B546449C9114F20F5D84819B38154A170EC0AC488346114C4E878D4B00312C952519A8B2B32D62F4F04EDB01F53A1E2E13926A0477D56304A1BBB3E81EEB4A04A3922866A490D487002CEA8582A780B7E82B9AB6DDC384B8FA7A567B1FEB0CA2243C5C216D9FFD40C2100B4960D102758C51FF5F468D1042BF5672A8109F19AD91E782389F03039E1C72920317421F179A27480640D5FF9CE4481E215390C5C921E42ADF392C513781443F61D56D60FF504851009F041E75149F015D882D885BFFFF6135A4B65F3FA861550DFFFFDA28C66430DF9F37AAC2C05F1F81403581DF4E3C63155FAA10BA22858D89F14510110067492806D8C1AD5DA9A0E0D8CF664908'
	$sHexData &= 'C72E50F75293119CBC728D8B58D0F1A73E45126868C8A770D8C0110301DF4C0C899E060CA64DC84E035B673F0D4DD023C73FFA65C0A649B0FF70D6277C58A9DE0F2800CD44B32B12605C16609048589EBDDF418060B1479F9013188881ECAB9F4052B9542AD8D9C7CE401008B9493BFE99DCD568609FC7B058D24C149F17C7111A98C9BF41A7A14EE3CCC1AADD0520A2A2BB9000DFB4D45414BF563C844C3272BE50E9C840689ECACEC4B8E60DCCF1F17A1DDF271FC0B66687937526E04CC80E78D83402476F78B89049BF685E03CF0920F11048CD78981A0E9FC320822477188727C2C9C001092B53F8EA32301397F4759387292F53ADDB99D243823E9E0FE9B87970AA6C6C247855D42108B19EB353602261AA215FF2290C57553F5FE9A5C3845CC8C53FCCC833B272493BEC1EFF70707C38185239C533CE30190894B7875C311CEC3F7474ACA835255DDF25278A0CDFBD10425E241F0320122690450696A34CB99853211F031F7C4B87815523003F466250915FBF1297920140AC0C4B3934B987A43057414A80CF58183890B0FEB412620A8B70478253061E4EB0EA1CF0101047DF1D3B2495471487A243867BD201DF611590111F1102C0667F3F113181053FD4167563BF9F1F504120DF03233300E450255A846855C9214F833808ACAA7F3F88C01C2AA581DF9580271490FF510156105F08BC424E4B7C27E32072A81A9FAA7FC151C0403F0F345044AB86FF1FC028620A7F1410AA585FD0AA0DEA9F5F2605AA8ADF3FAA53C0A23F01C19A145F1F44358055FF812F145BDFBF3005CE203BB88302202EA0EC4860654C1A74AA43D5A0C02CD27F40E0748F71868840143E4F89E12588EE5401C809D0BAB843B53DDF2E0A01B81448C84C344D893617888B98C740D0BB50366FB309FB8B48D8438932E448E0C875580258A1AED75529A4A368DF20AAD3D241467DC6501DC0FF026C185041DF505A0126012787282E36A9F6111E705E4C890B22D902B683352B441A0941E091841056C6C30F69E021EDE3DCBD5C23182127281F389213C504C35FD3004F0706795813B21B116DC3145F4ED600F8080C89C3450B7DE87220F09C6E191BA40341B8D8E4E20C53440EB64CE079480BC57A33C4BDCCE01CC1083F0521CDC4451F070504C8A9219F0A0004281572BEB21A4C5EFFFF0201283EC8C0E9FF0141794979B597E5E1FF4810F61848030240E7E15B482113455F02D5617950FFD7AA560785FF7F929121F9C3FE025510ABADD5C39E135DF80814019661F5719EF01828F0B557DDDBAE744B8401E018E811E882D81ED2EA7906E0E85FBEBF4CC24A8E48025330A043FFFFFD033272247F3041341F3C05E6D038E5D0419CF274EFF938439C18A011A0A4D20095A7A4A8A8CDC02E954BA'
	$sHexData &= '5C8B0B0C0C0AA3C797AC07EC850B094416A18C58B537F00D5941C03599FF39C5C352897D0D0287BB130C8D8C03E48E042886E79C88B41E0E487BAC2DC88A9C5227E7D0461462B7FE4285245A1DB7FDF117211A11828075B3301497FF51725AC14A10D495560722101EBFF0397845756579FBFC094B6266FC74A9EAFD1230336286856C5162660ADC9474D30C30335EE9A781646D07868C05A324E7D104603ED12B2D411120A5C36F0801891D0C05DB13E59620B83A568A8EBA40A0DACF94C33BB24B0A07199D618860686E75C12C6609FA7206E4D0E5F5EDF32110146DF485533A455DF2214322CDF38B94D8E41BE281F382DB9900B40500C8CA8445F0079141C7E3FC801106A23969F1FB1B482A3B2237FF60E8D04FE4C615F84B4108A03BADAB7A4415F840ECA7099D8ABD6A210B41F4D4692DD9E29121479A34004968A19073548663F5935F6B0685E0FB689DDD51BE8A4EC5A04F640280E1436869A971DCC03845B042351AB5B04366767058302593F366D002CD72E01EB7C41A560DC6E9F4801D725649C349F34E3E8148C410B90D4E5C1AC205C909B3856A2DFF6DCA44FC3FB5B46EC9135034C4CCC1E8656115FC01C4A8618DF2801D1E405C991281D8323922319283014F200C9E80001D41CB5642A39482CDAD09022961FCCF2804814FC255908733B60812BB60E8FA5AA15A5AC909F5F8F0826AF49031F8BDA1E2496574C52883C40970B12030838643D46454940BB809E21E3D7F17A6AC98C6F487255D7A4C92E989F269207F239FE02518931618221D03FDF6C9C25430249E88C54488108BE18815C9E8A12ED20CE2A461CD46C031FA6A096BCA90CFF804D923108A52119A3828C91C276509F281FC23781042612F27881C336B820639797ACAA40A49F806AE104EFA044B1A10554BF9F48A14E5B7F4A1C3F1191F1021A8BC95BED7011C8D04D361F430058DA491430F85C08009351EF1C93D01324FEC200D703C0A6EF075A80064F08E7741A49B54126FA34803F090B49FF200F6315320603171B31D14503BF2B21750AABC11F5D41B1221F3F4B37A5553BE0BF1F502017421AC35025AC201FFF26F000681DD3340614CD121EC09887304344F4282CACBDF74684B1C2C21377F7A9445D94C100A364281F40451877117FB638E2A03455FF11B9246B0DD489920E24DD0A446101774AD08CC57BBFA071A69BABE9E7C0018CDF6CC98BEA4109F910CD8681D2020AF15C4323D51B24C059CBACC5010903B208945001C7B8C2552549C3313C161522BFA8B90071012309AF403904C318BF5F767A28C44906284453550603530BCB5F212F001938E800F68A0D16069F790899552401A13F5661D0893F2F8C555DB4296AAB6A26DF7F8155BBC4DF810039A8203F1856C8462C9E'
	$sHexData &= 'B97C6F5AA90AFFA7E4AB9689DF07E9021C694AF28000DC38750640CE8A60BE5B16C547800E385A227B76BB11A978325B7088184AE7AB489D8CA7285B01C28F489978D118BA03760F9900CF60B25AAE8883272CBC10B12344D48729ACC9705528236DE4904E7870C66009869AEE747BC43D580B219C48E5071260305305E990121CCB18D57F2A70B20158F24080C2E7933C370C6883382010E599E4905A206038CB49364F58604A5AE6599CE4429E60D9487059781E00AD7B10E820343E25E20467F14C982006CE5346281030C6048D5A6B0D3999E418EB5860584AE24DB2EA594E169041838B205ECC90C1565244197C88643756811FBEF17C4AD18C89759F0ED1781C7FB9207567C3540C28DB3408C07B49E0647880E45A804B7F301F894AC0FFFF8C202B8110E293E5EB8456D1FD596D60ACE7498B49491441BEF98A9B498B1C0CC8483BDAB8246092490A3D786B011803C62AC3B1A6891821107D24D3909A1FBF3835D8DA129F9F875C2861FF70226CEA2510931CCC1B574C0C99937F56C57087CB89105ADF97168C0FA270575D1CD1CD2612A72964BC1B2C18E56A93CA9F0240DF5A6464924F7573560F0106F202E424A89E4BC923084F709E01908AD2D23FD2D5A2AA7F8BD568E143BF7F05E18A8C3FC0C42A708A7B25E239D019009614667030D5197DE8E8F203CE007AFDCB54B900451E67542D3C60598020F2F4537089860217C1B3192F402D4CBD43D856CC5CA30167A576543057CD3931E06EB3223AE57754E6B1F50EDBF1F4F956D092A101E3908FA602D59F1415F00839C8E102488BBD53020196D31B59530CE9C3C849A628E3521066A9C844859B389C820797EB9253C9F652A1D065EAE3925714ABC1BF45E039C9490E38EB528752855CC8231452D9903C1939F85128505539C9233942559752FB519242250719559001793142C830DFF2E4242F3938D8517451E6720A39D9FE507B382E7440502BDB06E7482B41A546461045C7B973E72E29201904E19CE48551E950D02C05AA9D1F359992AF3E3030D6AAA8823F4A3EAC0A1F1F38E3E1B164387A98391E1E4A307A7A753DB07844780413031698234A4E801C24DE97B6AA19D41F7F4D9F52A85FA39AE44269EEE8DB02F0018F36DA158680B9AA27738A13D94DD440B85D59A3913607F687004B337D2F00322C62292D6249CA75C436313F30D743D9809349AEE3206710D6A501D6F1B48F119895124628CCDF0A99425EF8DAD921643372E94C2846504F0652C93C507F9E0CBC05E9E17187F18E08EF6FF3A730A91CE07126F7CE595A9D847B6EB96130854FD5881A0DE9028B638ADA52E8DF9F21A9B6345F5B2529009F5F1101A555BF540D9252DF4A54402A9F4A6B50919BBFB5C524AE094B3FE49B49635F5AFF0'
	$sHexData &= '27CF2E50B6B020362020356020329E0CA874A410112030324EE90C3CF3602FA1602D2F2593E03031442C1A09F9F4661ED629FB05D7FC9304BC6011079452960BFDE64A950B720FE9F324529E00054DCFF6C2523B5149F58C9231D1F40DD47013A46740A7F1FAD281E849660AC3F701346A87F5FDC7C01F2B3D40210FD02D24C0116C987FC03FD02F6FC02F1128D069F1FA48661C5BF5F495843DEF024E968464248A906DFF5908A4962707B9EC3699D6E534A68074F4E4E4628384858486A968CC98D9FCF5B8F424057106580113716C341A4626BB19FE738B00C053F512AE470089DA56700E41072F800BD603035258421E3004FE1D03F09E98E180AC10D9FB00A2155EB559B89D4309FA0B2D1D258892568E9488C4DA35BEF035F02F1605AF88548AC226377021840C6EEE8112430D06696EF383E0278448E7718E64704D1344DD30AD808DC0CE025194D086A986B47ABF248CE410106414C50B343FF069A7B339FA0B13D45893E9AEB384B67771289CD9ED208E6263E8610D96085740D03AB09ED1B8F243CBF79E95270446B82CADF0D15F420DF80E160AD02A78384243E204B2BF1E630134E801D3E0303C1369E4C6EE896AB96834E1A0D48EB2ED49E789AA7790CD8DCDCE0E0052F692EA4EE7428CD4500A70EC625CF4D63266C30B8550AAEC7D070CF7596A4F22DFD148128BE3068E342D22BE006B0C8ABF2DF1A3915308300D045818590C99CB855B71D027EB01A4D8D68FEE1140D3660FC68B9F349616D2078588F661E4AC10ACD0B491E2630A86957AA01EC6E766BF2384103F2B5E068C41D287EFA168BA2E2A6F580A1CA56D86BF870B491A06A641341043A561B08F824E37C101633D7DEE9D4F856582914F5EA5A03305B34BBD6F1AEBDFC324D8BC5EB0612FA3C2503016E31B9315E021EEE68E25ED03BFE7338FE708D860D1F84C8450D0444A4B8BA15A866D61B5FCE1908F72E28028AB4723C6DF83BDD734833F2B9C857CB16D38CD2677109214672DD92A35100C05E1AF67E179F04B422FD4A624AFE187D94D61E1EBDD4623AB5D2F1ADF92147C6DF6232CD7D03689DD7C010E30E0E954A03010304080CD53E6B00473446101EDBAC82302EDA46D1B006F07E7E4DE742F74780774F53A0D2174A824D37EB8B4415A03055C3193DA7B4995ACA66D66B301A0908DA011335D834C382616CE212D794D140B7CC4463AFA0C38A468477C85F49DF6325586DD79449213C86C6C898E80CDE37E63A8B063EF3A148C8E5D2E0F228E746464680309783E4184839388B7452462838E44D4800C125FAE572705030B4E4EFECEEE4C7A6C1C0BD625CEB042DF0E9857071AFC364A41B8468AB289342040F73AAFA52AB9284C10A9FBD81814D81B0A14418CDA903402E428ECB60B1'
	$sHexData &= '900631D7B721E0585439C9C3EAC71CC1E9B855494EB7C307E58764660DE9FEBF383D44BA656141C86C10A6149C1C2E98924F2CC0253883478D0C8F3F1A6249CF91200C6C2E1846564A473077CDCE0D0D2140A8C8CF23E0B8C9D3B807783538C041BE9744155CA4E126284DE975B0E1F9E1D82547CF9173190ECB8F0A1D474707C820CF7747774972413024323B1520C78E577739150DBCA84AE3B0454430CC0999380503884442164AD8B840268D34C0DF4A990B69EA80C8FC14E239C8F9C8704DE9E9C0D16023F5FEF81AC019DE2B681CC45E7810843903D8C0A03420A4DF694E8C539FBE0CD4E0699EE63CD840DC44C0CED829A72543E80AB19C12B14BF8B38927416D4416E8ED808B00E1EC2DCD658864256AAE0C3236F4A780A9676CA13564E8C7C84B40C0B261D24E3FF26135A4FFC5B49EC7C219C64AA7F8382EDC4B7DC949BFB7C70960144A9F8A059CCE4D69BB92B6C640465C5EF1BFF9E2E1238E5D3F5195308B01022E19A2CB636384E427C5CED61E498BC7A4E2144F0A0B33D202CE36C672A24AE866DC7C4C0D931F1B8DD2CC1456B145E54D56A48BDB32B43DA2B0BA05BFE2C574C5E1B80BF3C5E8448B7719F84D53F21EA0E0CCD852AF4DB00D6C15D48256A3E4617265A8422A4981C3217968327F5B3B00BAFC6A8AC00C47D4344FF334C4D8C8DCCCAEB7000B67D5D0136F010BBCE810D87CD857E04281E846D40745E8D4F605105790FFD58003869B7C4C013FE08A9AD40D5E4C6DB3E2A424C0E9566BC4779862D6041EDB247B225FC850D7821B55B807ABD00D95B5C618524E646A4CF2BACF07134F2E5C5885F82861D80C8ED7DF75973E32225DB0CACA2778208BFEE845C445C8223B8FCE45CC0845D0F1752C8C4CA47C2F643B1B81F720F0EE4DE83CBAF86075BC73680028F02E75D88461E6DE75A0EB080B0624D4F190063B324DD8D5508AC432446CC4E74DB88BC6384C3BE66A5CACA87E80B3F8F5D664AB07D3FD4F3B15B19E6ADFFF6108FF0AE455A81FD835018B4BC43F7AB30067674DB5509D716E5E65120DC352C4DF59684DC50AB23E7553504D1B2B52380F5F3A9889FF569EA0CB5BBE25DBF1CC4EC16289B806BE2D04BB4D694B96F04AE1D25A5E7A8CE578569886404D044EC9C8864838B1CC58915C056130B49266131AA08008C2BB3F46ECFFA9E384B4DF48160682DC178039F21C0E027D294F07D449CA109FD0AE0E02EB03813B1B272F429E38902084DC6C62805101746AC0445F756122D0A9BA88232A8255C9564EA1141148F2CD37FE54813C57901352808E752AEB9F1CE445559FE54C9B4D0F003980A54F7E4C72484E21224DA852AC2A7910B46C401E5501BF6A520AE4C80930DC304F9103801CC55130DC0AE414C8DD4AB5BC280C6E8D3'
	$sHexData &= 'F4E76ABA52B7834E5BBE899134F5CA80E30E048E05B6F3816B83DA8374775C04D8D75D032F5961846FE703840989FBB33C08D3452DC7AEBAC2B48423BD078EB1C5A2CB445422BC31CB03C405AE34A1EDCFAE70545F36C1C428659283A76F302DEB71E3FCC4D2F3971EB829AFA3BF36C318A74BEA8488D7E303EDE7F8354766B3EC3D0CBD341A8DB25F362FB72DA3220DFFA86F6FF3ECFF2AD7BC9D7C7304E3EDF2595FF5CDD76564C8D7708D343D96FED7646F9215348E0EAEB628CE7763E48D3382CB80DDE3286DA3F04001F96B06E0B8C45339AD18CE0B2C0A8D05874EB99669CACB81716D891532083C07A67351852CDC730301C9A34472EBF16758CA87742D021276E3D3F1F77216FBDA5397738D03A48213548D0283208C7C4916A9D60ACB664EA2015DC80E0088B46C5D2C59AA6B556F7A83030C1432A47766CA87878FB595F71AF84683F284B77E248D46785C0C783CD1881C1A4A9C01820817B082E8A818847CF8158C9C10208D3C0B12AB0791159B35A395651A675757C48F379D0493BDD79B5D0791D496A1D3CA42867AD74D2546B186E182008805C30389075CEC9340C464E77D7D6228AA307874D50F0A04F757C25E99C7C189075B4AE43CBCD20CFD34B73437343AD901C20492272017226C036782AD59A8D7C26B078E8A8B50A5BB321B0AAB59C272D1F79B96ABDC219B86CB5B403490668D74138A092ABDE0B1F411886D17B94F420612D5F2AB552EB074403F8211FE43A0C1CCB1F382E97FC6440504C897F3F602A2F13B3EFD3B83C58918BE448402F3214139FDB7AFCFFB859E6312BE9D92B17ADD1B0DF85CE10926156B4D968910CB3C281D9032C19F9E67D13D849C7C6F8288039B3367FDF7CED72F2B0C81F8A034B2D0FF20C6343238B434206E467AF9CAC03665DD1B0C347AFF14806E430037C3CCC0ADD2063A9269A650E5F2A9FC0400A7242A3B248F367FD34895DB04CA74C8BE1B8D161CDFF7FE14C8D69304C896DEA21795068B30C403568F5CF76909FCCAC53D0E049897F9C1A026D4116E8E44626FC432231C8FFD3B682F5667D947EBB26104D3BEC219A556462E6181CB80B3EB4512B5F5E760CEF305C09789A20430614268A01114071A483491990733336BDBA58822BEACC75B34C402C33C43070E2C0829D25C6DE47A2A0C4B42C02359D2D59904820D54D6A1FDC97E07DE0B9A526E86618D0FD5A48C5AE4160D47F8811078379BF218EB0CC3278C1CACB7472A9EEC49300B3E6BF59C00D87FF8476084C68014336C0284906A46079E74B986B2BC3070454463516DD4B6C83A6C997AAC2D3F8ACC5CA46F3C80239826365B92C5820F8D02245BD3AB576072F8AA7DD83F97F918B64E44DD01F4BD8848FC5639E304D017C78AB8610E83C7DA384A0'
	$sHexData &= '5653FE2749975029D4449F5FAFDA00024905520E978DD0DB02A2DA4C38909C7685066B4C403907F9080D6B492BC85F3C222A0B047884F921FF789B9A78D6FE32900507A543F2141A6BEEDA0248A9605543E33F96409A820136D944E606E81482BA2F20D04AE5045E4537C33B5D74676813913AD94C5AD5501B260606F75A04A5C1BF0A00880889351091DFAC6E5921BF1BDE841B8A973ECB0D5C197822D6351C92B00A13D97020374FF93A019320015690903F3413D74C8B4B8CA0ADE4A726FE50CF13313C6DB6BFFA07C30A961C2BBF63432890953AFD1F9FAA2461557901C80E27A9399F431F607904C8C3FBAC597910AD2B5F1339AD1EBA0C840AFFACAA01ACBF90A72A0D1F50AB02C4B5342A9FBDB6024D9F1FC36C03BA085F2291C313299A00DF69327431FF401387444D01A91B102A30849F05F2E8325FE93CF260F2611F03BFD1544C20507F881AC0527F08FD09179FC2442BC133D2A81490B8BF1F180DACB1FE97A48106E16A22F110B8D8BAADA6EB746A0E89456F6B499A3458CD80CC80B2FDE82022815FCB8A486008BE615112B6D1B06423C31A8A48E0E163CA01351602350E0CB166200D500C0B0D34C2A498078133CEC61956BE3D6143B9C1414D8B60F544028F31E984671869F033178B2A51587C094A453441393F62145C105FC32F25E81E699EC3A62E3836EE9E847F3B587170245EC541A03D5171020CE13A5F6D7002429F25C2811B2D537A1EB413CAE16A7029FF8A3824287AA622D511AF6C6913B8D0C10E944546487E7EC35D488B4AC9CD04568E8F2C2802412D64166593383CFCF7758E4C958C3D46A2F09F4930014105370C0DAB5FAFC3DF0313435A4172140C96D48810E43EF160424A1BD78B3B39E1681A0DD2D1383055282958632A11033A9FB9741378167E5F4D09924BA5C6CD45941A0CB4C504C6BFC3A78DA75AC10561904AA528307838D293852F35C1C811C101BD5F4005E2835A9E08330A918DFF7501523627E43581E234243348815872C889734B37708A6A11A51B4FD128C26D2247083867BF452C22143F405C318DFF200F0172159F4BE51A0181810E003F0A01604423B913454DE37E7F2790AB08941A7FE0514403217F06898160BF30E421402EDF4B4519019217C5B09FD718A6B6843790088383D90805DB1208C31F245D0A18BEC19D42D229514910314120B37129C023C7DF3A05B4452AD0A5118AADB65FDF812A050C9E5F75C1A21A1F7FD893C467B890BC5C480414027E1D20C2B180175F5F7A8D493F1A56216030F806F92D096ABC9441D09D069EEDB81049E0482851C02A08A8E05E7C908BC0B652EFFC51D08B51B450D87E51F8442CE01BCEB3350B5823803FA0124371FF02FFC1708825FF04C3BF048C5B4A3F25408589132B6'
	$sHexData &= 'E152805DC7F031F2016A0B626BB6195B5E4DEDB1271BC8A5F05C31F424D1B0D4D3435442A4DA480014925102F65EAC320282A0747D9015E20CEC9221856F2BDCCBF149020B9BE0A452CAA1F9F16B036315EA0E08D605F7D5F381C748C5F51A9940E2B38F47FFE354631CE5E32083AEB50EDEC9C52240CE065EE74FC875AC38D41F04CA6D854C9CD02CE360638C275C10407AB6B63DF3F34D8C2147AF63040630103B08836412CE01F7F41FEF3BCF7B6D42A49381EA016A00EA4A4015780CFA8A84DB8C006B1808B637B22417907C402DE12497798EA0480253FC5AA53C03F3F2C1E2E518204493C2457D70C5F4CBE4C29B085734C81067E946E34B65120128853204BA6E017EDC875C6A3DC1A5405161E5F24171103FF10DB92851ADEF92B4149083510BFB1DE010AE74E2D958492573380074A38027915843F812E55F287B45FAE26B56904A07DC3DF41402BE4E92ADDB43145FFF15F223E0863EB1E1C8AACE23B2C0651322724FC09C743BF4E23461157C729B205920F1E712D3EB125604D100281AE864DD6ECFD17C3085A15823FDA160B555F1F5F40218852BF0160D0089F76005840EDE105D20010EF2800B08A8061201B8BE0DFD59180C57F1E18231B27B2B17118ACB26441AD22B3050B0D6181395103692497064E1461412509237C00F2A89F000102205C0056258340BE801085DF9F699A5636F3182008A4699AA6081818182069B6A043AA6A2820C54C423F0D9FFA254B8D7001336BC506E93BEF97034248A6184A054D69CC24D4725B2430A210A21B5D6B343C1F5625458004BE05671D0293B8ABED5B014CC2018F0CFF59721B5711489349614CE8681CE40E88B82A1B908F3235AC89C6256C09E220293EA490831ADF235AE7543A6229420914D85811DF69DA583352E102E500349F74089F44A0E480E0215311981F231ACE2948A3A2077F8504EE0834DA7F1342B5151F3F888936569F42A700ADDF11AB53125948C5B4B1493FD4025B5DA977DFC01023819FDC093C8891FFBF4C22F6A028BFBE5C5F50721172BDCC5C80959C90BCBC0078111A5FE700AAA48123E55F6D5193C23F7F99C382521F9563B74E7C48FF49E51E75F1184169DFEE1AB00CCE86187B10CC24301CBF30846A587F3F0B2DB550DF1FDF00605572948DAAAD8ABFFF0B58C460FFC81BAC75FF5F2AB2F9E4CB433BB50232B50226B5023CC8950F1AF400E2B50206B50258C9CF83CAB502D3B5025DA09A3A1F5F3E08E4554D1F23899C64E57380B1420173B166B1C48B61945FFFE19115A8DADFBF5545BC51393F1BAB0E6B9F0A2DD4689F5FA10AEBC2F79F2EADE491380DFA001F1A04728A2B1C6A8036DA3F5F395083B51F3A1BC0040D024B24D341691FD80CB200C020CC118650A66082921AC467'
	$sHexData &= 'C13057FE33C9318550DA7F8FB695B0F043B8D830011040384C602B00FE400643C0F5C53270160B01166C90B9C908B7B731CFC41C86B1E10C535C4001AB184EC76B143735798800DF9E03373528C1AB634028E4794E4850208681A53943C52A621571F29BBFE8B685D1DADFAC3403C17FEACAAC3216404A9E593018820569025F9D956C371508AFB22868AC0A9DD55B2F84C60958E284B90A238973495337D550DBF011656A052538E3D8534B4B6F0E8AB329FF7F184C8D340B498BD64C8D040F16CC4E5541565023D3A2D4BD44CC4D43EE3BEB51445341CA10D53771C1ED25337C61EB4A1A42F75DF15039C5722CD53D749BA3415CE96DCC05F9AAB0BFE3820268300D7B99DAF38041B62869DE2B5B57040C240810BCA5E6280CB334C7D43BE618202C4E414129172C8B2A49D2034FD4D839FEB9B085C57D025093A7400E38C5F9006EAC0E5B09DF201201D0F11913131C5F10EB2B34BC4193BBAA234917B345EEC5DFB4DA70FF16F6E1D1FEB5804567E2C063E9F8A23E1AAF123BD690AF06AC65C122FF961C5DA50AE187F003CDD4C86F5F1BAF3B03126BD33830CF388B04CEAC6B9B2A7D183EFA44D9442A4FF39E82880C08080C2437EB340CDB26A236D2ACD77B1E1B4DC134FBDE60AE6C1C45BC8CB1F02D1D00F10D8E2E751EF01A69162C050AC00455C8D0C0817FC52BFE4C3BE77D7AD214B88D6E6CD7C486F370F604F7F5F2855F8B066F7E18070F1E7C6F8B46654663466186E296C146109943FB1A62AAC8F22C86CC4C9DE115BC18C72F79183877CE6CC74104CB0CCD0C928B81782F0FC0217193C6A76C1A276F130E038CD4D09F5657B864901D3086CD7F700699C0C4314848E0DCC64A6FB148B9BCA23E768B034F04089C0C72720C10182879B2A0A561AE434C0BB13090328D2E2AEA3B2BDFF3EB577403349649CF48459EA25552F600B061C8D057B89D5785D2BA9FBF051418C9930C130E0AC201F092E24B47901CAADF217EE8704B09927C7F79889253E90A5EF400D846B7346B0153903CAA1F917CEB17450B92AC3F6538547290091B0A817B11C929681FEE4CC80B98A51F5A0F43516310BF31919C82867A9FF0FC14029D187F09B94EECF37F03293D31906D76E4C189C5638FF36C485E20A7F36CF36C71E084056C7FA37874A291521B1BDA38080C0CA50355ACE20B4B73F241416241217D7C7CB248797180B89D487B51188A708A2A559CEF6B24B800E0505B8E13A34E5F5553419A072757284890D20719B0E67E16D1FCF1D1808E3605E93E31343E675460D4874E9C7FB9444533ED5F8D0CE8C457488AE1044903CF66D0B7F4229C65B25B498ACC9269363E3C7FE78C39FE5BD3066F03CC03EF4B8B043E4A8904541C37D0082A271B064C42F90D174E1C41D3C55'
	$sHexData &= '543303E7942C6A72716B23F2869DCB89C03C692790288C1BE8CC14E5D9CF0262E1D52277A22DC400C31187D0E20E157D0526E38F1685C65FE6E78940846851EDFFE6EFFF0B872F028D1FE94764D03F7AA65519571C3EA068E1C7FE1F90203ABA4EB498D7E083B03612002C141C3ACB05E41FEAB3B28D27C8261DA1B1A8CAAC77D19DF16EC72DF1C900342BB64A0AF7737C045261E1ADB5628929E0814797E207FE2A8B7A879907513A10AC968F335F448867903BB6E359E4E58EB03AB3C08409327E5691850A8434E38619A4B4B6E4B5E21971C9CAC03B83C53C9915458402C15B8E492EC68A8A59A070186607E5638502F976C7274F0747BD23F8DE6B450D8198D78083781B4F83C3090DF43E6A29006D2EE306E7F01B790264B79894F20C3229E065428B3D06E5A9703CE47621AA1010181AD6AA0B15F4F23D40D9F80D0E34B81DA30F15E40085DD55347F36884E5E71900B3E500721D85D042FBF340C09998497728251CB29B96E47249835482313BDB0D40283604AB380DA4D88FBEC9ED8E0D772A170225975C72030405F16D72C90607FA46304C23C2241CF020B28C6362813E5E56F80CC27AEE67028352B8941B66901D8CA1818443784ACBD48109C8EE12CF26B0418E17AB3E016BD734FFA6BA20B09E4A09A949891EC2D332560AA23491282C96BF571907F3B4D991BC2D6B010C48196523404F4B3940237982E6DE1C4117D64D374A8B0499B600DBA2750F7A3CC22246EC1E60BDA4C008EB2F100627EB24856BBB09031A4C0EB62F6B040012732B482D8C43B493862A387048C3883780E9100DB341D495B69D68B01858C130D2D2ADFE766920D2D1065EC20F2F0676644702E30D2036730A57EB1200D44665DDDCD06077022C8203D2DF19BCCED6128AE8262E2E6C3A38A4137FE1B0089F84E13296CBD1213D2B6763E84941692802B8E06E3EA4967C32625748501181D5DDDF8314A0293FD37C9E98423FF9FC0093E20A421E94C46F244026E44D3EC4F40341EB480C35200F0AE4C268983E905720035A26CCC92326652421C02C1420A200FFB988429333FFF91A230172DFC87A29446A01A898BB6C1869E36211D06D43A7CDD000581034781084370E184983FC7141380641654FD4D85607854D9FBB510641D84161A9B51961E3D3A3EC6A4EF8FC5C1EB8CA49C1498B4E34C171F04B938103C4567AC168BC7C642DBEDE74758D4B1C8C4E03647B2A0AC275278810037E5B2075E21344852CD3FA1734E41A4183C1691E72C02D492E9C1F81924FA547C7C5878C1CE4C8C949CA49CA49C8464E2E97CACACA49E4E95B46CA2D492C493A0D252F813B412F6193570E404901E57C49E6323611F870085F492CA5979A3D5DF0ADD37452343D3F473685E4A59D484D6202561601'
	$sHexData &= 'DF1C90142186E3A00423A4D9C2D3B007A212219940A80007695028AD2B1FC8502026DF5655199F43480101C35F0CA630943EDF8E2E2910BFD56D14C10A5F3F5FE63485414724A2B1AA0241BAA104DC67FF20BFA19B60D2EC9138F9815CF9FF66897CBDE7003B48897B8C408F022EDFFB2CE91B1A20D9AAC958551F5F103188D83F2DDCA2205F7E210B66E8A41E421686E94918870FC8C258B289DE4B7655188B41502250D7993C72A01F108B8A011F555BD4209FFF04BA00621F6151A12D1FDCA2A864BFBBB761E4E17C7C49417F79201697242BC4CEF102DA4188408728C303B4AAD91F7F16813C110EF800744058D41F3F1227A551BF5C89AA363FDFA28A8D50FF6A8B68C0BFBF605591315F522D0571DFBF260178261E08B7601459D0FFAD1721431306F315CADA3D73FEEB009030237298D100664D4B5989298074089571000BB33A40CBB0BC1A00CA58CA3A5BCB066EBC851DD6D9BE81DD78B817C2F0F0F1E015E10D21A81074FBDBC9F3BBEBC20F57C9CACA4C5EC115801B9B0F7676E9959018884943F5116BAC87825C5F34D04F2067CE0E9DC61A48EE145F482DBCCC61EB5C5EC30D4CA771FF1C49CD03DDFF4DA1DB1C20D9493904DA75134B8914CA2CDCBEC30A1254C80456C34F30CA750A5CA6D0B71F4B254BCA42AF09E1A844DA0858B19DD94CDA733F6B5318F2D8855DE95B1CCCA80E70E2B820DC07805900120C3FFF4926A826F469EF1B115AD5C63F709AE462FC1FEF00C64CB0D03E922D17CF1A902670234DCA50E71E17C2379CEF0218C6839C2111CC24033CA8A49DE6FDB40CF08883F21848F860448035B15FF3BE01F9092AEE333479100618230B1CA4571C88CE38A440241A02185A2809DF65887534408807DF0FEEFB89BBD415BBD80027DA174CABC8C2BBE0C73F5721AD4059DE9C2A64A7E83F78CEF02B2B92538126CC480E04C8C02C655ADA09F344D70A2FABC900702F3B293216716C011F903D5ED58BCEE61F68CC1F0572AAE02901E57C10205724C3959C007955582E9C7C7799083530EADF57235906934D37C48167B7430419498420F0517C0B93434B08490A1F082020110DBB1C8B92D0DF1F9090166FB8F15538A71E8B889F9683C91E3B02D3C57D27C776C70B3838CDC829CDC36AA030C39F7F542A39159F566858AA9E34960875C3EA26943F7F1C0A3945C02C3D26819043915F5527A001C82E9C990AB9A8617FC3A116803CFD2450C1D0B90D4BC2C31648D7A27F59370A1DEE7512587067C3798BAD0A9F7FFE10B6C850225FFF451610A2FFA08104B4FF506105A05F3FB4182D20BFA2B6AA241F7F685B14BB8D3F1FD06AAB221F5F961068471F9F12218FFCBF387DC300082DEA02FF1C3984EC7FEA78FB7BF27BF2729283E67BDABAA27CC9C'
	$sHexData &= 'A431EC67B8A7C937C46E8115A5F3F9F4320AF0350607822C8ADE4249F00537846784358D5081F75CAC2AA3FFF1AF5045DCA61234C74CAC69FA0B84E08B81F034D40DB2609C9184D27B075ED2D5B65B7722104610813C81CB6C1E7E7B48A8834EFCC7818112D94200B207D68B8911612D7BE1428A2445F169C985E8FB892C16042DDAC90511959E0E9B0A03541807EE8D92A65C029B24638FF57B051244040B5C3C64F422CBE0117BCBF37018D55607DD7EB1B1A5F55C71DB4908949B5D732BFFA0A0CE840C75849AE898870650BCE512BAC25D7B21A0D3B854DFC9802744C625C984DE282D2C74B48B54DDCEAC1FF031AFDD64EE00414C5338B2CE3BD3D49960741DAA2A0A017C59FF78320A7C4C486C6400C000D4E6441CF0D0FD133D2C80184D94AD6BE93D2A32B69D52FAC31DFA9E80A74905E600710804F7802DD72047C60277844DA0A265A1B2205DD0B5279D0448214C295BF9429A4F21898A00038C9C02603DF931D048ED76852794C50D93E1225F10AD14DCBA82209135E02454F09431BAA44E00626CFE453D62A546EAE9058B88B43BC8B43C8321BED6C661CC09876CC860ACE534418699A2209E2C4D0E0CC042639B8E86BD8380532D0E59E7082C13173CF5853E5AA7548303257AD65904B835347474720833CCF477F477F7017805CCBD69465AA185653A739C823288C57F0C144A659784DF08168C8A1107AA85F334A104A5E1515C1431A17A1DF573982861305F121C1433A283970864E2B3F4C4FA07DDEC3A7F24C3BC2E76A266441CD7A245D70BC5E7840E8547AD66C03FF69A2571A5B745E4424CE47612EE8CFE34791D710944A47474D025A7441E3FE6D6A707FF63BEB7C8792720BEAFD60B0E33202829671D8C8193A2F6BE2C7A55BD02AA1EC415EB094CB41415181403571F6A5B4A406218BEF5D1888254C645F2420768DC15441FA04AD606FDEE315D4AEE5EBF0CF77CE0A4C3C063D33D27D370813148CFF03B9C94AAE61D70062C24A01F5DF0781BCA2A4BD543925AF92BD66B709D85895BC0273D203996640BF20011AB219040045C31A128E5B288DCE05BD636A712ACA7D47381620CD3233DFE3A2D986CD378660C12C33803103C260690B2A26B3217EEEBB5F6401C80974BA2B3900F224BA36B400E440C811D38BD140722A309F39D02782E854D4B73F84B7BC92032096B121D209400E8423D34072AA4ADF30DC3C08E41124B5D4B4C8297995E6AEF1CD3C00E415CBCC535558726EE8298E3CA0AF34D415E9D7FFD58CF423A9AA2DF431482F10469710DFD06FC80295E13E7509B9B8A16BCE7904959637BBF56024610C254219A4607912F56C3647CF9A419EA74F774777478D00B942CB6A08042B9E376F5ED420ADDB2EB222AF1442805D5B04C8E990'
	$sHexData &= '5F733AAAB44A0E6CB15FA52B69B4DEADB286A4710A508A073C1B855C4D32E8A72359A752E14DF70FB99F280309AABDFFC4B934481E7FF42E0D92C91A225D5BA41F245B922576085902792ACA232AEE39027021C7466E208D09A12EF652C206E92C162328D23C64FD243BEF7C83A3C207D26F1B98164EB47F08D503DC95A641BA80503325FF457CC90148892F41152F69958932D3944350691F9CACB94A61901D1F03B6847728B83CBF3CC70D6D5587773037D49C9C3840907F9AE63245434743C5224A375826C623AD1502C4619023B00A7F3FC627EA02F9FD099E29E0082689C21820AC88061D54030B0A3FBE0AD24A00965F18997864620B50729808100D774C2C013894345C72ED38971217131471C925971516172CC02032072823D22D407D549CE2D6CA0A80D2B520182575EEB3B0707516990145154994EDB417620A08EB152A4048EB0BBC909006ADF001DDD324244810189CC24B614A2549200CAD0002FF8A9DC6B82D791FB378C9814A1C33C92306282E9E67481820282D1F13048C200856142B885D1522B3B42A1FDF2105A42EC7DA3CDBC4644B7C4518C0036CDA480463041C954614088AD5095FE2E2EEB25228084DE2221080C217F479D9BA097AB08175290421010A8F10B70F1F8750C3C41FD374CABC4BE4699E8630FE4BCAE1C952794686434B4309C30331154B3DFF6A248050DF09A08A46DA1887010C1AE78C2A42C36118E9EFDF085A4C507F084100AD3FFF3C4D4B02E9182008D234CDD30818181820012BD36077287E0358C501DF0BC08A029F4289265822429F0B08A114BFB7C4A67618477F25A488152F8D6613A1FB9FE41510A31F3FBF3011883A109D1AB65003CD015F8100941C8F2F308C1A56DD553F020624796F2EBD540DB8E42240BF42C1A260E18C59240D7E83A7C07854F0DB439206160CC34B3954D31C28F81482A34062054B8904C343089BA1074AD108CF2502775A4B12C348409789EF3C46D3C33F082354B4DF0662D5D6DF1FBF403C10A19F442239C47F3D9E2589500D5FBF895AF240042F6C202E58101F0701EA9E9A11E9D24E1C530B227F4E488B0998C09C68B30DAD4B9FB0098F20FEBD00AB4411079465BE73DB45E145352D3C64FCBCD6308E5A3219601891A80B45CBE4A949C25F29BA00E45404ABBFE09BE451C80B7FBCE4B6901745827F301CE405F20A009BD7B97944F2284CB811B75E202F08209AA7BA04208F42A4BB207805C8DC4099BF4A1E85BC47B81CB7C1EA32B19F4BAB51229E880ADF204B7511FF7FC10E46D01D0A5900C37F190AC208BF496C4357487B20561580D69D7F071BABF62B1F1F3C90034948693EA9B3DE180037B5C222B6E7BD31001CB41E28BF64749E2838EF7F043D82C1C60D6CFFB92A18659C89DFC'
	$sHexData &= '13FF9E8B88DBF7CDF0FB6FA131118785120CD3567D11821B32D6A37748D50287D40E0C0C0EF497C9FF846C5398942BF3090B4522D12DF8ED1EDA940C6342B8B53304C05DF9C9F791C0099902BC9ACCC9C9047703F492FD1B919885C85CC8CF354113FA29A00B803E802FF35D8FD02D4A87F5F04143CC3307EBE1F4C8D4100035C420658D7E3D0357C5FAC82C02B99FC152C37BA05A91FDF420688881599D0F07C3F575060D4BF9F704321279093C7B3AC1A11AC92B3DF268C2174DEA821AB30AA617EA9B0400E2248FF92959C0AB90F74ADBA09E30C8DE151B12A311FDF85BC400E809157B08221401ECCAE12E52A395484DF61ADF20279B0FF9007B13528791404B29207C943BF0123DC30DCE405C12B908FDF97AEB480E8286CBF624500BDEC5EC741B28D6C54453F0A0409B9EA11FF11EB948458A562F2B582BF3EAA62C91E2DCBC895DA47646418288D7F6A8630B9F1FF7CCC82B4DF63AC005A880B870851DF3C5881BCD9ABBE11B2C7E358819FB94811B426C2F902AABC3BCB7EC2F961EE36319C5731AC53F852219FE6DDA95A4AF75DD4C1EDCA65DC18207C629016203CFF9130A4ADF028FE4937B8B0FBF400FBEC84BCDA32FCFFB5AA0521B9E4322C6CDF14F59017323C324CB18887A2DFC4415699DA9A414D50F106780D7131B6A4F94AD12A02F1C029AC1E215850CBD07A033EB4849570169F850D5E3074323EF5D01148D0CD6558F1213304DD5418B7AADED074305AF0A35F08E6C33A0E4A502F748D9E8264CE15380E893885B7348C39967C85D4C2F045493999D804D1CE46190C6C4326759B99861E90F95CF1302158C41D97C515861EC534B4C7CDEBCE4F5794367FF1D60D7A70DA2049A7C98A2F5E53800E19A79C25B8A84BEA066B59A3C3F2E6A1A8EFBCFF72514018B6C70891F7AE4A2D42377E61E258010E7C733F02E4C98318BF16AD8FE4841C5489148A298989925325F5880F4A4EC96DA9A988CAA9CA415E2429AA18DC8AE444C8E9A8E9A921409E1C1ADF8EA9F2484EC83487F48709879C283955D5869DA5F2A0E4948986AAA7AC1CE445D1A31AFC19A5A1484E8491A31C02E4C91CFF4EA21485258FE484D485E98492899253B58445481E94BC69848AA5909583BC699F1D1CC1A43914C989299F1F1F9043803CFE9EF482AAE4919CB483C982293951729582DDA28BE441C949826AA3085939C881A21F3C59A26160909C41A2F81996BABF266B2E8CAA02F4C5F103D05CDE87269962C7F95F7C2C5500B16CE086DF82242306A81CA5AD20017FF2076B3B00E08593C9A9AD9020FF18DC240FE4112FA218DCC82392031AFC779D2407481E1AFC1D1C903C9047AF9A1D1C1C51210AA8FF674DABE4841F3C7EC94D4D81909D3F386BC00658FB234B90C60448EB'
	$sHexData &= '99C0A1483FC0000B034B1E5928AFE203BA893A4196929C401BBB28EDEE1320DDF938EB54107DC00990E687F8806BC0EBD5DC8730BC4AA8EC41B07D4F99707E0026DF830FB6E845859481930FBD4C410106B4295B4056D5CA13833CE08956C06B813C8C42279EF972A8E4041AA0607C813C9213207D357C794020579A629DE4841C2A107BD07BE454208FE57A719B43250F08F296C0E4919C9079807A957901819C0AD9991372A8E4729470783016813C9279457817865627DF6F97290CBE20E10C068F9500BD7CA878000275DF46BE95AD0AE20801B701571809891A18547C511464028675599FE9537210F202965D202F979C9077E077F0F57695340320D64D959C8860BFFA99A664420E4076001550C9294AB297792427E4607520763575874AA628918074C9233921407555741C2A7944A28FA073208FE484607475732C1A81451F1472330DFEC98E0022B948B63ED98F94ACE44472219629910D61D121FFC1D1101CBD95C5090C46C97FD90D198470B89E9627682748C14008C33C6F45E04818E41E2830D45649E061FFB60A857312D75F24988421D94B12B0AA281FC40412175A28E721ACCBC54010C00342314BD04808D7B954B0BA8C217F308C2A6177DF9217C9030123DCE68C1CC210215CFFC953C957488B02488B12901F84055F258C70030F999C354CDFE442CE569F058EEC849C0AB97CCD93119BBAE4323CAC7F06BA24690759212F03015140F76E00C82339B76FCC6E0A4633AC5B1F29B990036727137220923CD76D9757903C926EAC6D4724537221071C2427E440B76C776D03B020798C6C1F20F9435E361C6CFF150072249B49DA5E0C3CD07126CD435E35FCCFFCA0798ADB06BF8D6C00A006000BFF84B728C2DF5F20C24B413F5F3F5270E0A55F7F2B05070E7F7F04F254249F398600C889906E5F87298C7222E444618D598876612B101F3F548131025FAD9003F2D9F901A987BE6A81A43E89DF290B02E444F240118CF18B921372A2A917398A274A5EB2198A190672223921A9848984C9093951C90E0983484EB413E9823FA9852239919C618AD98881E4A260993F4928C0AA1ADFDF02849A11FF9F46A8008B7FA271D6625F960A99E2FA213F814E212FD89F46EC398211C889400987D0900A3921887F4A225030F9DF3FB10721A7C98271875FC8899013D98589806C81E444297F3EE98172223991A1861985212FDA44D9FF897ED8606C5A7F57462866D0DFD05855839FD7D80A6E5F5F8DB1A2B812DF27D8E0A6FF3F46ECD8BA4421FE0A8A0411BF1F06311C845F1F7083621B9F3FFE42B511C57F1F55DB101AFF5F1F6985A8867FA28C323AB4FCC0FA25A76DA2C80C17C74C8CFF25AA72694A184E0A94862F97CBE5786A5C4EC05B72B95C2A424446482E9'
	$sHexData &= '7CBE54A4C4E50525B79B95C545628619260EFB95C2EDF0B96989A9C97CBE5729EA0A2A4A672B95C2EA8AAACAE9597CBE5B0B2B4765A68E4BB5C2E5A4C3E2F30F9461ABCC45FDFF65FBF5B5C2E976F0BAEB0B2B4CBE572B9B6B8BABCB95C2E97BEC0C2C4C697CBE572C8CACCCED072B95C2ED2D4D6D82E97CBE5DADCDEE0E2A5C7B95CE4E60649122934A9860EA0D19F4C406928B590CA626262608B4168EAD930A0B48D00A938450E9DC6875787EB44E6D0DE148305410EA24D676F924B10697CA3121083CEB6340232F6610CE95E1784911D0080C407806380B0CF2B58514A176F897057C8AA618D39082B6446DD10DD25470C4F1038AB0EA92F023715640A2A108E2BF7253F05561B3F5EE5F27D978A8C0B8E1790922A2F97CB9C9EA07A5DA4CBE5F25DA60BA8AAACB95C2E97AEB0B2B4B697CBE572B8BABCBEC072B95C2EC2C4C6C82E97CBE5CACCCED0D2E572B95CD4D6D8DA5C2E97CBDCDEE0E2E4CBE572B9E6E8EAECB95C2E97EEF0F2F4F697CBE572F8FAFCFE00B95C2E955B0204060897CBE5720A0C0E101272B95C2E1416181A2E97CBE51C1E202224E572B95C26282A2C5C2E97CB2E30323436CBE572B9383A3C3EF24DD180402F740B7697CBA5F2585EB2A4968872B95C2E7A6C5E502E97CBE5423426187272B9545EFC5DEEE0D22E97CBE5C4B6A89A8C9090BC5E7E5D7F40E19EEA3636E78D1DB39C51B8B364A96E169B38791D3C140150DA2C40AE8E1C25EEEBDB7F533FA589926724908E81F963847641E2736DE04F01567DBA0D7F3B0DB9E47CF275DA4DF5BB60C1C11066F7C1EE1602F2C31AC9F8CC95863A045B900E5F08405F1148B7BAA00FD9A5544FB5B77206D9556D289FDF1A216100DB54492EEFB7AD1A2A53C5D2BE6EDB0F84BC4CCA321559615F389867649037F0266584F8017C6C90717089F6747E83051D3EFC79297448255D10416D9D06214E8008C1954A0E5C15CDE3D66B9338B0C63F09F50B9B2436D3CF1633C77C366DF7C83159D3CB18D3152C33C9EFC2143E9A5368224098150C879071A6E1B8D7C222309BDDB02D05F6418D510110306FA2D705B02FBF1DC07A0DEBB4B907005F189015C1638148B72D3EE00D4B882CDE01E45BB04AE13F1CC8C32F150B003A9B4CFDE2D449C2FD83D0A183E23F2BCA38F7059299C43FDD308BCA95C8CAAB8AB7DB04FD532B2764E5455FFF52775FE95279F279204E727D5FBC52F290270F895FA852955FA95426799452605B568E3C39F281047204195BF1E1C94DC548B0FA3D58049CA838DBDA181D537BB152F892418E1904CF8D4807C0634AA161AE95C0CF0E038F87CCB90393C056779552DC183E45B9515E8890030FE7588C62E4FD5CB68323001E7C5106F6B869774FC05F5C5B09E95C86DEE00165'
	$sHexData &= '15BC05A749EA4F0930C05AE384A132F02889034941697F5AEBAF4C1AD05EC843890401BE5686B4F208FC022652A9F09B0D043B000BFFEB34B964350BC62AEC20EBEA2A04EFBBBED808F62298301F14C8C6F8CE6B9E64411094B1C9487CE79D05A0E550269D1CC651099C99E15F8B266EA3D36CCC167C35B905B42801167989C1928F409B76F9B0CE5900B82E517F2F142210C48DBCBE3D76DCEFE7DF742756C2008BD97533D3DF015015DE97009D149CC3D6407FAF6040236BC758A9E80102D8D6B97CE622500BB849BE9BA5982262C901EDF11F1FE2319FEB0FEF67847C139C1B3D6E178A97E7CB83FBD9AAFB359C062A62D4CC0BF4C731DF2A50750219DF874309E3031F6490EB674A1788FA964C63413CCE440814754C190E1A4618B7E667A06E210648802804C94D21B46610481EA2495A1BC60B08D1720B419055A41EC30C72063E28C0733480EB4DBD2EDCC8BCF6679C9727B84D6EF0F696C66639E8C44864813850459AC2CEDC3A750EB93148180ACE8F10535530470961ECE198002131650762E358841014D44B616DDF1E0FB10DC8008A75EE2F8EC13B2576EBF7CC77F16314EB19DFB525D161A9962C62EB05DCB3C1344E667567772C158634845597EFC2BA37682A756912197B686CEBEC18DB7B6B7F2309296300090A97EF5B2F7856F05CE94D7516F8248D4FA21141C68E27CB86C7627656180230DD608B28C1094201DB6790D7158B9D0291C8FFF0A9081A3CDFAEBA687805D3C0CF8C44B69D68744D10078D8AAB8222837866BB7478B87F320F44C38805731E7F0364AA9A1D9B19098F70D08A71BA4F4C5740803D38748C978D4F14A8542D6ABA31046F0F87103553288224777036321EC167A248101E5B817792227473D678444EDC26B4618123894FA4D1483006C694E002B769161310133076B16028DBB205BFFE6CC7CE366041360DB351AE2EDE4F7B1928B6C605800A017D5881D506A6B90585F545E64826189B05A99BDFD72D5A187579A205DC1044990D0CA019F9E8108139B95FB8415408A81F0930B7411436F6E91A4862D014A14C06963120A4CADE811594E406E04A0CDA4EEF807C720A8B42A412C07233FC68BA00C2A4DF1885D2E9838FDE51F77A24007D130AC8060E02E718600F8F503F8AD9BB66F04B41F8760B84208715AAFDCE8A34EA08472E9FFDDBC5ADC9540084B00E8ACB810D1F04A464B0FF8B15D35F7715CEDA01E033156F70C3E002146C1883FAF60A43B41C232F1A6FD3744FFDA82AEDD5C986C7CBFC9F21DFE1BC92897C933DD5E82021885BBA93F23C15CC8E1FE9F722D3F61F552C48F7D81BC006FFC8ABF908F876B70E64A4FFB9574AA78D407722A768245724F718D042582E0ED7C1858D55F3872C65134D4303408567C229825'
	$sHexData &= '056028BBD20C22F82703FE43C2EB1C812FEC0468B1FA2782266B4CDD610F3ECC60234F75606CDACA0EF73B552EE084279E9C1E0F0CA32C3CF4D276D4524841C848BFB96932984AABABBC91B2C654B5CCAE987F6564D01D78F1CED87C28A23C5E72100C347AB12140677B8F008153E3D2E8BF1158DC26FE3BE613CF41CFE5B60833E490ABB0103DFEB2B833B1E752D332F861428E18ACED35EBD48D84E053CEB1B6A04B6C1392946F0D0146303D2E033FEE6C310FF030D30CF38CD96C5A440D7623945F74D48C0280916087F8FB80B6CB8C811C05260EB050002D9700DDA8817E09199628957F011BC7D202E95C11D590CCFBD0020322027F10A0EF002CD1C82181BA2F43719484051B08AD8307887717490833D59FA0E0606F70D9758FDC70549182D1574DF578D20CE4F10662C0865DC1308B86515217E4A510CDEEB9E06BDD229A7EC5C203E02D36C23479B50CCA8F4F902585F898C861D54DC708CEE530EE316A924AC835CF75CB01210C83D40926DA08C0320C629EF2D190ABACEA04137DE87FBFFD1FF05F19C77E98218653F423A06071D408AF1824F2841AE6033DB4E179A5AC37F122779C8F0D01EEE8905A03E2B5AF82C38541E6CD02645637535F852D8EC1C3467AF68891D2E535308CF919E4D68022212CEB25500C3A64A049BFCEB9E210F204F02461656E727ACA48108D94CEF570F10B0160F39151CB27F80072E1108A65AC107122420E2DC45706304133EC0062711DF9C0AFEE909FA41094A374FFEC6020FFCE2A55AB76DBE451D5AA8CE57A031147988350160DC285A9815DE38A834293719CCA9E55D86F451FC314D78992DF0BE4E34980327070FD87540E77429681709DB0403E38D58013A665784C129CECE7B59EB06283B2F71D280686F82D5B4009696524D3DE046B22E6E2F6D145B84D8CFB4F80B276701F3B0C28250DB236530E2C715D5142A69CF809C676321B1CFB6070DDD2F016AA34D6915E6493BAD0066A0CA8F1227EDA6D007127F451B7E100A688BB1393A64BA00C0F178810DB84C2787B917DAE812E71568325AB99DCD295882567E36D7F7015E94A074A7B845BEDAFC16DE3D9C77F41E4E0AA70C1A18D9749EEE5C53401CA2F2F6D222AB9CEB60ECF612F6AB0F0568A96BC00906082D5CEE26DA0061576E6B2FB00DD6D34C0420292357419E01B9BA5D5B490A1B805CE7054778E96F085C7857CDA3091CC82808815319F9A0C8CFEFF62428F2F264E4D6F72866F7BFF7430E69F030F6B7161018C4B9921A1292075D38C6D20162AB508401894136A539920B5EB64938404E9E01394A3831382B472E4FC1F61A8BF571F53660E4206BF583C20076D96AC1A9C20E1275085C1CFBEEF5BE2D0E760AB448D40A13C08EB91C084E4B9D43F540BBEB2A'
	$sHexData &= '4F7820EB6F205A0A6F6CBFCAAF391A73228B4C2EC18BC970150A960E2CE351212FDEC4E47A04CAEBCA809C4F53DA05220F256D7462B7D54275BBF88149AC7171066AA14D5585AE42E7325264285C8B8400512723C3A1B35AADADED99E13A296019D8AD9C765A95282C8574F916D86FDB67B3AFBBBB260FCEE4821B4965925B45DF3968607426A432C670069BD647349A027CB1029B29B4A937C683259150AFD77E6A47557169A81E6A40FBAE0A05437570AC6E13049C80A429B00AB903651050354D345BF0060483ED1613891CDEA6418172411B679DE88804834CF083618441813C8DDEB3E0BDE03B4989C330E8BD3A77708DA71120A73B5C73E07EB585C839D05085CD74BAE40C1129A8980B0EB47115442D4B69296D630CCA1E02CF8415BA0E54BDB7E3CC0137A4808232068D9B6821F0DA6C67F40801E9B640DB4014B378331A70D00CAA088D48034A034B7A0B2F055049C60E655DC30FC367328D93448D42683D1ADBD36E1A883EF6B65C01640CEE4C21660F452C51F862914F2F61106CB85046D7476ED43F34FF938E3AB987087530486348C8003E646ECD211683B98D1ED6B4388C0D108700A352ED2261D59E0AA4DDF30D0000DEAACFB6808017C08138E8751C4DD07F6B0A048E8B48208D81E0FA6CE6A476F04CB8E10F81F966990174E88F1B109C07536E549D00603E588C4CB73DA840206F0D55045620F03D0B82BC0E810A6F29BE7C4DC7D609EB9DAF44E421B2A54CE9294C004C242F36BFF54B154B4E32840CF14BB7A234791EA1E28C9AD248BAB8278DE95BF2353F6F4B00FBB8E460A32A7B872B3190D2822F035B72F30461A47B87013F62D9C2429E04BBAC802A70CFAE52E9CCD26986630DA016D9950919F615A2443C1AB7DBB7FFCB4181F06E74656C0CF147656E7520D28BF0508D47010E84DEEC450BC8482AF2696E6508030FB4D71CCAB2043ED9B0046EB3B1C00C752C0D949EE5F6DBEFE03FFF0F3DC0061474283D6006020C213D705CD34A7C1A05B0F9FCA42077FCB9F1C2FE083493A3C1731490429170AB2EF4547A9E78DEF74489059614EB07268DB89081A0888260260E02DE1FE63EF48BFBF3ED0FBAE309730B6E02C8829F7B5E8522147370CEFDCBBBBBF3B412F706351B73550D1C73C02080A44E3DDAFFC0C3BCA224063C067532F2C76BE769ED66A80878B603BAB412D3B40B848620741330209D05499CCB059B74982B01CB28E6103853AB4B670F398E4442A0108E98EFF4068806BD90F680760CA2EF5582ECA702A40F4D6518F1C83B386D919A00457845101AC26BCBAE41CA3117763C4A201F18895037B63745EBA9A6DB14B0E033450710C1F2A16F95FF9223C14E5D6F5621EC20DFB2C8CABB32A2DF058522EE2D992B4E3A740BE42507724'
	$sHexData &= '23CF03B692F402630B933D5184C251805450440797F52EBF7D01C2E292B1FE059B689F201B23A1B8C56E71E7959E2D67DF2B6576B330F4F65F8100804FC1EF07C6600024946494600B399AFEA371D6FC50C3D68B03C66E0EB1287D8428A446CA62072E9F75CC848B777433C9CC2666081D3A7542A15DE3F3F3F235C2E97CBDADCDEE0E2525979B9E42E405041EA5C2ABFEF2C17160BF84022AC2FDFE5BB2E2FC0420BE4C63FB9545E2AB8CA400CAEEFBB4C7BA0402F8C76537047B95C2E97621C4EB88A824BE5777C0B1E4008FA7F97CBE5BBD60BC8BAA496EE355C2E587A3FA63917B97C97CAB03892440B36287C97EF721A0C53FEF00BE2CBE572B9D4C6B8AABB5C2E979C8E80721C8F8A38DFE556480B3AC44D08ED2F07CF4D1A203A0029CA7B6284FAEF689CAF0F458B04B632A5180BE3F809B8DA5F3EF600040CD192B89A249EEE4D82F7D84CB6FE46C1DE63C84C23D14963011F000EE2D610D382FE33140C08F64401030F045EB3DFB00E83E0F0524C33CCC9682362BD5C4B4CC74459297C183A20F2DFF85AD08135088D4304F883AF3A4146042466F6D84F451BC0414004B42F064403C044853A744A0749AC05C0B18614B10E66AC7D4C10CECACAF73CF93CB33D1717F4E89FFFE01F8ADCFE34A02893061C1F486B619BBE01ACBC9C8A20175F491BC9B5403F702630D8C9916E1F28A02C40DFB9BDA5361FFFA16C1F2072EDE4051638ECDF40DA7B09399FFC477F3F7082A12D1F581F3FDCE5C83B581737F660A08C6F058F861F9E0C1F7F945EE0038FA9EA802F9C93F14D50BD30D892F69978585F7E20742870C401BC836520FE1D2C72F370400041ACFF88102CE49DDF402C9C903FDD76F088A18FE516E560DAB737163D0C4F18763529DB2E8A1FEC7717400321189657E4D016FC06DFFBFF3735FDDE6FA14C2463388B940650A47DA87F3CE1E610923C28071C90C1F6AB4C2D004C2C902B6D0B84A2B44F1009348ED591A271313F19998A8F003E5C174868172D86097051919C7DECADA6DC5F2C5CED00582CB1A617ACDF159D7C1F23E4D0F0FF6786E4797908C96DE464285D20610C48A77BCF58A085CE480680E899344B97DF492E155E3555DEF96D5886932F0E38BC06AE1E1046287C0220BC2007497E901650428EA270B78F38B660585309FF87AC6442AE28308498821C1EF0376ADA367D493791233C1F06C3C5773840195E64F3385D3314228D181240D05538B57FB0E2C8E638CE3672E73DBA5425F97D381FE2E45CCFA93759FC807F9A2CF61654839F17975EA606AC7F28AA2C931B26BA9F306601918CD11404696A60A168F093899D8E076C3C97044BB47793FB7297E34B1C41EA083F7F90B9E4DA151360174020870C102C3F2424D8B195BCFBF238FFA07FC8'
	$sHexData &= 'B54B5EAE784817285A6D8A210770C7BEEB0B83AFE901AD01828C47F235F21E291826814905AC0AEC12FCFF87FB46AB0F48496955E1382B1A98483F75048FA4B1018A7D50BCF06446D270333948F404015D1FD86CF0553430907E06D16E4B58A5EE863BD80E09B0808DF126D48C3A92862C2D88BA9246012C4E1EAE07003C2BB7E78E41EF2C904040100E185B90B00F27E04B4D4891070B12486A2B1326246E08F99F0C75CCB08F80978DB9E46250570A38382BB9630210C7EFC5024160E717FF5F685A32289B9F8877249F236E2C080185DF9CAD7B22F11B83A519FE508D30EC0EB340AB2F3118C15D831E2F331CA46F2E4D3BEF5CB8D81A113F10250FDFF6CCBB5C1FFC963C389855B8E4DAE817B8D87D878E13229D971CED60200C39B42135FF2146D52513FF40700F87E7391AB70218FD0AF29297CB9000A829309000BB91CBE7107130380B1A3F7A03364C080B199BBC2106726881FB266625A61748608429D70BF22171FF61A03FB520975C78881727E455BD57FFB9E3A9E36FBB82253F6CDFF6808C5D6292DCAD4E202FDD961C0E5F80DC679046904BAE975050965C26699E28308E1E9C0BC63F7F69767B3CC0890F795D0023FCB72CDB3AF101772C877E769C72B0F716777F177F38A463241738C688ACE076B4F917F8BF758C4C3D8752F755D831D5340910F634FE96B06787BC32B4757C7899748C1A7ABD5591814901C15239E45A9F3030902F15C0463CB9680489EB6C27FB448D20BF8295BC8220A3100151239754DE161190C80A14E49283EC8040688AB009569FCD98ABDF34BB60A7737C1F686773A7E00D0BBFEF8C4C63705CD3E43B5DD1720C464801E7E5118F1C301C74FC723018B380CB48F28F24A5656ADF0DD6D681B7749F2F75C502D70A9FE25F2461F1DCE46003632F6039C14EF2EAC002A80117E80276C92427C800F08877B54B2EB9D868A05F4B2E99E41802F888B431C18148A7254665071E9CAA1381FF756C70DA2E2D9DD56E15BC7939D8C10D200772807F88A36005AB91FBE303900B82F821A811F20A06E4E3FFF7A8586DA2F148A9C5AA6039C3D56E7C393870ACDA2F55180376DA49FE6D6A7C6C5C5F268C2F9DA6832D4703B58004431744A3BF74CD028313960E3D83C041BC1D290A5FCBBD5A70285A5E2B81BC4DDA6DC97BAF5E6847682F0DB9E4D5EBF0D80A26F6B48FDB8F30C5EA9203C77F6004046AD170B06BF5FD7C9003A3FF5F0BC00037563B9A2B639762AB1A1368FF5F3C3875E428347CFF67BC4248AE8D5087309A425B229F570EF760F222C44FADD476616527DF2DDE4EB8B63DDE5079DB41628C371E180CA50A4BAA96381F355AEDA5671F67202994C50A9FC3FF104BAE0A67284B210EA93F06FF1FF9C31462FF485F03387C6B308'
	$sHexData &= 'CE42017D118923A0A0AB13A0303B4AF9086642A35495830378042A56E2D9FBF083990233028A14AABD4DF9F1993A3491B15638532871120257746DE763311682E9F1A0230CB505B3311BFB007F24CC9C0241800A20530199024109E7354634960B70DAE20C4A4C73F50B93C95435040982091839101402022B8C04A2EA2505F50443146149F4710F228B13F3F4008F591601FFFF323241F8E4836961C7208E4835F023B2CF022E335E804382371D2223B811CA25F9022D022BF0D018E0372225F0754913A123F7F751D0A60CD148CFF39B566BEFEF2217F7F07325400C75068D60A8125DF2DB485BC4740BF1FD2B4505C287F170294D5522B2D65707831406D11BAB001BA0430F9B77ED18F209D50E5FD282197537F380120DB3E02BC01D41C270347EC2F16FEC6C5E4445C98283B5D7CFB88E04102D29C9F02D1AC1F0BC83B7230CA2C36585F43AA08565F8F91DB840287F3BC07A4081BDC183830458171E01C1C213F799F77B17F406420224C98302B428A3D226C7F9F279FE76A9F2838345C20DA91423E352C47E405C1F39F9FBF375C9D69A0BD379C9F481FC21C12032FC20CA302D34B388155017F3F07131730DB452E1807797101D32F1CF41CC043B621309E1FA31F54D3E45FD51973FE5F45617A7B5F1DA775FE5F5F8676DA83BE41FC17369C9F28983E19400FCB76FEFF91010C85FFA54E729213000108010001384AC84900011F702C19A8DF347F0730E46280601937DA87623D6B5D28706E8D844F0AEDF64903D91C7528380EF11B019A0A5FD68EE5EC2FF042471B4FD8BF106F42F8D2775F1CED83D6DE515D62D3FBB41FE76DD7560365A1D8F3AC2DED830C4E7D48E4D71C031505A21FB8A8AA890B79B1BAB42AE901C8431EC0FFAF19741AE4C8430E1E1D231D9E7E1999020C5F5060987C8009602F0220DB0ED30C118B8946AC471623C8C5E4432CD040936E848A7FFE48AA11576017BFFFB4AD18AB5F1F66D03AF09F1F877079116000973F70BCC88AE778700C0F1814D4D31FB08A9F34034DCCE1860A1DB2ADBDCC7F20F34CB14958DF58604E9A91CD589F1758645811B2F279384FACACBEC19E60897F1FDF104FD88D974F0AA9DA885F7F34616A831F1F80854DB882C9887FF0C5C79B4C32F8F0179FB5C0AC14931F4B8A067240FCC0C1F4B090C01F85D362087258FFE5AA602D549B3FAD0A41C39F2756D592AB1F485FC25595A8473F4871310244A3DF40014B250B9EBBFC9FA0176A189FBF4C2A85159216208E501B71FF5FBFA8855A2A9F3FB1625541BFDF3A0CB08A1F56C51B1869401520004E30F890AFD86AE57F0352BC211F849CFA8C022FEC56452B39FC3C3FF2B061C41F675E90F016366BC7DFD5C28852B74800DA824BCB3E5CFB4A28406D054B5DDF'
	$sHexData &= '202457343027285115ABA2FFDF79345123EF589652EC46260224C7284880539542BF5A3C3488815357472CAF2102082DF5486562938B8190F07083FF7701B1408E648B3C739017970E5C0FB72B206E4092BE8D2E25F9CC0712AEDC822F920344B0FF9084C905C82984840DE4C840320E11FC834E919C82B085A48592492E400C0D14244706101C8501728AE4D086C48632904C720B0C0F24A720393C86F087920B9053E4870AC89181640B0E5C870B72C90020303FD5811104DFDADA10C840409F3FE831E1A040A7018BBC31EB27684B2490652D22A080169A81380E826BD64D82C18BC1958AE0296D287D55E9422DDB90344371363830CBE891944E16D19E6CDC246E0D48BD3E4553AA80846A6869523C2545C47890623035CAFF4E101A98BF1DBD89941106F258B3358A4F4390A766CB5FA8BD019544483E93BD01FEBFBA8DA0642AED1FA93E643375F69207150D95DCF761E1267A35AEE894184CAE3A2C8126E8A6AE6D3CF23A33DC5F031271B87E668905A10C41E3741D133AEE642838BABF507F3BA0BC1CAC5EBEE20607212D799ED9BCBF3574833C9DBD014116AE8390CE3B5CC61CC883DCFCBF049CA914BD0100BD01DD14201FFFBC01A19A93C770E40CA2A3BC1BE00A408383057F1465C602C18347706C0A69BE2DC092230A1F262D941FC2CB0CBE0147F43A2C3982BD1D51BFA93064837576720530C6445D28F8BA0157C704F10AF90397BE08264B29C2090039906343FF7858C14AAE0842FE03850CC8B9A0086564A325FF19BD032AB8A20DBF3F2B420E645838AAEC1496222EC9B246DF47D4C636018E0B060F7E27272727685C4E3E91073327A87F3609272727B74C0F5C6C74842727272792A0B0C266274F6E8FDA8C2F310F524F46DE4E3C1F2A090CFA304E4E4E660FE6CAB6A24E4E4E4E8468543A234F4E4E2616FE2FF091272727E4CC1A09DBC9C8930AFA08E6D61FDBC9C893C42631B0A48FB79113C3742FAF3C0C760FBE93939127060D4C98C9C9C893DC1C0E60A6E464E4C9EC260F5EBA93DBF6E4EE10108F0F4093939393547A92C6C9C89393E0FC3C1170C9C9C9C992ACD2F4E4E464E41612345C9632F2E4E4B8D60413386D7B7272587CE40B6F1FC9C893DBC40FF216142AC9C9C9C94A566C7AE4C9C9C98CA4E82C1532F2E46476B40216461979727288CC3617749C8C3C39BA021844967272DB9E0619CF0FB6FC3C3919793E1AACE8201B9E9C9C8C66ACF2381C234F4E467CC40A1D52912727279AE0241EC89393936CB4FA6A1F64E4C9C9A2E022206632F2E4E4AEF03C2188C96D7B72D81A22AF0FA6E464E4C9E2402384C8727232F20C245094D8393919791C25609EC09C8C3C39E0002620409E9C9C9C6082D01E274F4E4E4676CCF816283939B96D8'
	$sHexData &= 'F0F6890B6C891733DBC0B4F020C9413C389BD4DF04F04292F0E0A6FC9C9C96D0F2A3646C9C9C9C95A687684C9C9C9C996A2B6CC64E4C9C9E0F4060B0EE944F0E41EFC093F82317232F2B6AF0F642B7A9272727272ACC4D0DA137B7272ECF60C2CCF14EC7621B32D2F54CA1FBA5F79BB9D5C90840F3E4F662E9B90B7097C2F96316E4F93DBED76E23F5C1F462FA49127B79338200F04E82DB793939336C6AC7A4F9AED1636B12DEF86DF2F2A0FC9C9C8DB221F9C2C0AF6939393DBEC0F72D8B05D0C27B7686F005E5F7A91173BB92F48903F462B912727B7300F1806EE2A93939393E2CCAE9A939391B7824F22294C2EB79393931408F2D40FB6272727279A84705425E48A273829DF2AECC48EFC0F045B3869A0310338539C1CB95D400FF001203036799B9C708F02509FF60094181079044B7C2FEAC4D9094AE40F56183FB618DA2F2205931927019FF6054E37B989764F052F4C2117C8C04F5870B7FF177278A93C6BB92807D3119D7B1EF81EF3C8855CC82EAAABAC5CC8855CADAEAF855CC885B0B1FF855CC8B2B56DBDED6AB53F8AFFFFFFFF4183A67F45229DC8727B6F2384D33B8F428DAB4EA1439CA31586DC627480617EFFFFFFFF4C8E3FEE7333A7A483BE6C83E5EF5E1D4FACDEAE4C43B608CECDFD4A1C7761CFE8FFFFFF43ABC75F51AF39EE859D739DE0D4CCEE448EBA3FBF8BE4FC585570FFFF5F004AAD7C4C9A1838A2310B833761264E3A0931564E8536F1FFFFFF42C156E7DCFA768CD1244A81A441BF531C219CCCF7973AC5426D9A22FFFF2F8046B75C99E2B9A8B8B5E45B1D4AFA2D459CDD5DB351FFFFFFFF05E7EBD1B20E8D8EA5A84EAA14108074B7B6F9CE3BB3ED6602774AB9042721606FFAFFFF99E717DC55E4F2B30916438260676ADA32481CFC66F240ACBF47FFFFFFFF8CFCA85B89A655DEA0627AAE2CEED8499D071BA8A927596E135E87631D1FAB45FFFFFFFF9195A29B6066A650C9BB19A29D0A0540A3EE3A421B8BB06C23185D027D6C7B44882344FFBBDBA3CBC3DFA2FC4FBF13F28263F06F18F72002EC9890F761B200695841F8BDF7006D00730A77166E0E63006FFDDAF935F865227300791E68166C00318EBDABEE0A32062C2E00641E6CB76B1FDABDF75A7252652633463F496E697477BBDDFF69616C697A65436F6E64160A56617222626C653F5BF668DB530E65703543537B005761F9AA56FB6B65416C6C799F0502C09D7D801C55EC0652F00F53904076BB9D5F061071A00F800DBBFDB02F3F0462502F6261642061FE6F6361FB0339699B9F4EB894C2F582FF72726179206E6577203E6E6774682F73D3D29318AC4FBCFF4F146F0FE8F91F556E6B6E6F776E20657863D0E6D60C1ED5AFF673745718DA73F76067B265022E696E7667'
	$sHexData &= 'BFCD0EAA36326F69F067756D304940F07D301F206F750666202CF8667F831C634661696C20466E63686564752FF0E6264E166865206F726521BF684DF00CFE69732066756E6307F26E2A8462F97FED704408602026612064656661756C742878B6991ADC7275543074466BCE5A33B76162726F48700C6D90E6416007DB947475B68408920B85B999380A6069657635518DFD706C4173CE73666941B7B0B381FCC42692972F00ED13C78E74D3E352746C47C656C7F10C0D4673875C002F0D2AF39E7079062E2ED79249F7F4B4D3761A8E69202A61B2CFEF75BA681213202A6D2267006566BD51A17B271F746F1A696BE7B5E57A652E6F0A6C2A647B76D97B47722E6D1363008FD5EA75836F740E730E2AEABDF7BC1A6E640E765663AB4BF0DEC163161678576B73DEBD8360B35336753A6F6A6857AFFB786BBA000FBBEE7CEF7336615B68FB6732D60383F3BE37701E639362700A160C8FDE615E87F76B1247732B077647ED8E82D56F4B286A1F2F3CBC372922624E74AB34DE82656AEF54FF7E74BD37C0D61F7F523273C26CF175C0F35F53721767976F0F531B7B0F4C87DF6D27B65CEC70A75F1A64010E0FCF6F553A6B006E7777130DB89BBD72570175FA2677EFA4120D5388142544706941C98057AA77A0EC73730A6E1749B71278743F473EBF7D7DDF8D04D85D003C177B07309D77A5B7273737067C5E74D8D1276D1F73697B3D83DB04D8475B29AF2CF38F1A4DDE643E3A4B61835FBD6D6B7116E770375F3A786A876DDA364F3A2F662FF6DE49D1B265723A70DA739F98B68A037283432C6D84A3BB239A0B92AF6D46EF86E35FDBBB2FE7636D30CBCF626FBC1E83759B6D2F4F677E74AD69AD9B4370FF07EBE2F6E0B63D17665B00D763F0FB818F7E004300410648004536F6DE91A2CA4DC21A4526522B260D75A08F56425F77EE701CF7DA362E4F0F2ADF5FDBFBBE770F4F0B53AF4C4A441FE177D10CCB610341AE5800350497AD55C2321F17006B2FB0865B7E4B0F757050AD0ADF5F5F614DDB0AFF7F7755BD55854F63626843B5C1B58E7F2F4B0CDAE16142426A964D823660B02B7874ABE36D62C03A3FAF3D2F6088DE7763AB74DFFF596F200F0BC6622F9BBEB7BD6B6F70663D433BDF2D34D8444BC33D6FA628B154533F535FD51E479F5B7383A63F156CD9C3682F377FFB83AD21B1AFA75FAF6D1FBE629F6B2F643326758E66D0F1DE551B73A27A6B4F31AD2EB60133AE5F693A77CB702B7200797B08D7F16D5FDB758F65C28F6D9BB764674F77644CC7A2617F30F3D32FD802DB1D566DDEEF963FDB7BD6B6274F1A670FB6B5D0B6652B9F37B7C611ACAA5F8F682EB00A6CABBF7E5333B67F23A665466163746F7246044D6F5267AC0E340C006F0EEF09EF03B31F923'
	$sHexData &= '1022BA90D31602FAA2FABDD80BD38FA312F002F9D3E2E903756FFBAFA0CD1823FEE755BDC23F0FBDE4C025D000A3F622E1CC30F9B49B353C7F8005E965B57BF07EF0B5F67E76A337E3525DFB66B3F416F3278003600349EB7C4B03F758E7A724458E174F0CE6F7BC2B2A8782355CA6F2D1F6A4FBCEFDE3B4647CA50179E075B165341B082118B8F4F26A7336CFF42EB7FC0BD6EC14B0F381200CAEBB69DB80674A74BDF4336E747C1D855E332687761F57E0C547F53DB322259C0833779B30A1B4F6F5D1478AB9F73DF3D15347FE0DF425200454ECF0F70408BCF7206635354B7A10153255350AF238E021C53C34D3FDB917C03732F3D5FA72D91D80866878648D38689C7294FFFD15D6B2C6BD34C9E7F7470C1065C234337234248105A3A6F379F2E020C96E6E2C34750F4A035AB62335C87D88AB6765FAF1658EF63FF5F00A9FF3A414D3A616D3A504D3A7585FECA706D657175653C543E866F206C35AF9BD06667AF658F31E9DB71284F72146720706F731BDD83398DAE7A4D0A9A16B6859DCB5070015F9922AD66368622ED813B3BF27717280F0422601BF02F11C00FD2A935F902D3206D36D0CC5E8E7CEF140CA844BC9F27767BDB9E3A800FAF3BF01F500FECECECE430406F22B8BFCEA0DFE4E4E4EC1F400F1DD0C0B0B793D9DB6F20F8CF0A0AAF110D4E6EB7D01F200F0010FF9872E4D921260F0343803AC03639F9728001D1C0B0EF4E4E70F60C58712BA00F0B60C0B741464EA010900F70B3B71B267F1D1F3A100F3926B793B3F01F3C40E00FC0CE6ECFCE9F05042F033E500F101F59C0574CCE4E000F3D60AF09919393670F001CE08090D9D9C9C9162070306F05881F8E17AC963162DF66C88F8C1C3972084821E019D02621272783604060F9B0763B0548AFA0BF3E11083B993D190C0BF0CF0E0B0F327B9B0CC0EF19A03F20BBDDAE7815906FF84FB00F704FDC8E62320F8FD01F50C9EC41A659CF88DF3827B7DBDB38CF3D301F900F7080AC64E444BF26E89B3811DD7EDF700F30BF16A89F75426EAFA01F180F1220173C90E01B48EFA07BCE393701A5BD254D272F56EB964C041F022F5CED62C377048F0407057FBA6285DF08BF02173089A69323D340D0EFDB07C8B3096F039A50033BE00FB8BE23B1A06FCF023F80BF3BF28E89132F22A01E102F5A2C39390440E05FE0F901474E2017B0CF06D8C8DF0319201D980F01C7D03472E4E4BB4020B970B8CC9ECD5E2F49681FB77F01B5001FB47BBB4D9EB4E02FB38FB2900FAA913F60EF01B1E0709FC81D177236F008BF40DDE6044E10A01DF00FD0669B2673FF862F0E4F841C391BB09F09301AC06501B9E10A885F60292333E0ED3F2F39A03F8090964D6E23700F505F7FC8EC14380CAF42500F396738513110EF'
	$sHexData &= '05C0EFC8B0C8296E275C0F622FC120DB49B7E4C0C01F506E0FF6648A93747A4FBEBDF02F5DDBC9ED800F868CFF5F3C9B88E9CDF03F260F033CE08E9C9C9D801F5A90703BF0DD70064CCF19187F30A46D19B00FDF8F1E008DBCE86438387F08C8C5E4F6569C5F0196AF9D0E02D07080255FE050EF37709E8CFC71B93F0F48100C20322147CE2F11800A201A5361E2782A109F072F5F41116E6FCF5EA00FB0BFCE6E73E01298CF800F501F0DF0709BDC4E400F206F0E700557996F9F0F1E20B3919BFF40201F5AC3DBE4C8103CF07D1D30BF269C1C3944B013B8D02F8693B307019A705F12C0A45F0241A6C23F574BD317188E2698F4052D1EB07402CFB820CF4F79815CC83858D8F32113C809F8F3785CC80572981838972D81941F64F274C909E47B0E039EA0F2E0F1953C2321D34E2899405EC87090F100212F900B2090F02E640239B0F020404CF2E14A02CEDCEF0289E002F9F0EFEF8FC8C516C898EF4F20819C901788EEA8EE5E201732103098EDEC527242B8ED0FC8EC6492CF740F03D0EC05F3DEC8E70A68EBB80E0E4E10E484BCDA509F28EB30EB72E4C809C8E918EA70EA2027E40488E990E99023474E28E878E8D0E802392127E8E7F0E7811C397288E6D8E630E713C8093948E650E6F0A6E4C891E440E590E5027B9E77F24E5C6C0E0398204FE4C89157F0E100E228E2DEE2D8A5FF7CE0AF1E88DBAD05088F4F1F50E09F3B27E404CCDFF8DF4F567221573C68829D909DDFF4DE08DFEF2790137270DE98DE44DD9C404E04DF70DD10DDF24ADE84184E2034DB4226901340DB104EC80BE41890DA98DA920B99406068900BB9E405384017C8C52E0CEF18E46468AB9DD9014FCCCFBBE4028C021E9840B76B80005FD8BF0E91577B9E03E0284FF4D74F2E909314405474D779159C23A0D73FD0D67615BD09D81E304F244FBC92E7B9033840ECD5BC923731CF009E20B0D5B109E484C0D55C4F5CEB5672702F149F02425EC9F33048D8D421AF8673E8D42F98D444700239A0D474D38F17D709E488D33CD3BFD34EF121250FD26FD8D26483D546004F3F70D2B113442778D2EF48D2EF76B10976D29F184F209F819CD80BF0D14FF8D105F25C32C002C8C805BBD87C9F884F581772815C601C2864425E20F8D00091235BAC1F78D090D0EC6213C8B8D04C9F584FC0B6251704014F899D0079E4CF98CFEF72B105C7A0CF5F4F789E77C90538021E40405DC80001AFCDCD901372829FECCCF8CC25CFC526B04FB8306E251772788043AA9E67DAECCB4F0418202F09E484BCB4CBC8CBDDD516D56CCBCF4F06EFCA2B799E699F052058577BDEB5A44F021EC048EF5C18929C90CA78CA2F353C171B149F2038CF13C80979D8C9E0C99C39819C90C9A8C98CC89013C809B8C858C8623'
	$sHexData &= '8819C68C8BCC77FB9900976D8C74F5870C5D15B2BA7C70F9BE473B54F0768C6091E13F26ACFA0389F20C63039212790C680C5C0C539C54D2C0F60C5ADE48A254F48D3EE32DCEF30C405BF0EEF90C4DFC881DD04082E9F10C487CB8D1340C3AF0E2F42AE0EBC0E287FC3427E8D64C31FC2CF2513ECC24FC801D0C8855C20A8B0057221178890B96017C1603F689F34855CB00B404F0C421A5DC91802EFC14EC80976D0C19F8CC198C1C70B99403C50C1AFC50B360118EFF0C06F6C820017C00FC84F1772815CD08C98B6B84EB0C0EF5CC06F9FD8425EAC1FC09FC14E0C2FE0BF2FE8BF4F5D201732748028600879AE9F0130BE6213C8898F80BE3C4F4EC80BE44890BC98BC900B994024303D90220C1EBBB0BBBC4B9EA94F0254031E683921AFF6409FC0B9C8B9F94C720214B90428B94EC88B29091E78B8C0B843364713FF0BBCB7596B249B0618B83FE079DEC34E1F0E0558304A4EC8AB3FC0B6D0B6DEFB896E0C8FB53F900E0A4E1013F22A78588F94B4E00F7840A5B4DFC8B3EFE49BDACBF0B320B4EF064EF4B2AB9DAB6524CEB34F41B0BB9324540E1F80B2DFB0E4A23AE4B1CFB10403AE881FB1EF64824DC8AFAF4F680BB9402E703C4E442F9048E8ACEFF0AC20179B40804F88D258495E8CAA2FAAE2B9D801384F4840C80339157FF4A710A870B98C07D8A60F0E06B89E01FF6E506FA672829D286F48A69F74A568551D3984A5B0A57F53C1843C8EA5A5DF03516F423E08A4201E200246C9A95FE0A33DCF8B74DFA30E04A048404EC8ABEFC0A2D8A2474E809C98A2C8A1D8A1F2EA7A23006E50BFC4A0AEA6E74D075E2048DF5403E4A5D64F4E88A0AFF616C7F09F0F4E509F8C9F64023921C09F2C5E054FB71F50308F709EE1047242C89E209DAB3DCF9B2F500E088020EFAE764EC8AC9CD09C4F4C25ACE44270A073226ADF9C9F209C104DC8559F9B9B4F5C6D424E849BA04F04A6A75BF20C1F3030DF023921AF889890988001277648989F58989F9009423DB0976F954276239996EFB895B836C170C8952F444F082E36813CDE609514EF2009F9A9D59FDE449442262881943F937221136C934F24489C902D561F64917091F062094E4F4F4091C60939C1CFDC90E89099600F607F88909F2CBC00792E0238E08F2764AF946F808FA08F5EEC80028F284F308F362127182FF48E00EFA2043EAC5F8EDF4C57255E1E40AF8D3F019C404E288D1C8BB554D3446F8B3F0104D3A3867FA08A8F4E2027E4788A808A388AE4047242488ABC895C632527E0896E894E04C18489DF58893CD726088F0CEF0220096989950F88C9C50E9088444F50F25CF25C020403180127E4054C876087BC844C104F871E3007C8A9069F00878091F02686862F881E40DF6A2F2157851E284F4A2D13'
	$sHexData &= 'F2FC8420EFB00390A983404F79C08C1728837F00839007C8030883A0821332813CA88282820BD804043F684FB0920B904828351109BD1F81DF810FB436412FB84F9EC0816A174B209F904F12865CE2075E803000C7B31F1E480F8034210F387F30808095690F28CFA07FEF087F5D1E3009CF7C7E8C309216C00E6F7E0079202FDE307E407E101311F0B07D9F7D17703C80CF787D0F7D8960825B9F7C3FE7DA04C1F87C8F8C4F02211DB192A0BF7B26E401327CB47B7B804338C19F887B4F7225573B704F2058E4457001108F187B404EC809CC7AE07A404E809CA07A887A2170D526704F020E1E200F64FC79107AF87876A99D88EF20794F2FFC77AA0EBA89EF3C5E0F782F4D482BA4EF777713C7034A4FD475FF00C50EB880766F884F5CC8D5DE981E404F3448097989955EF874037940A8756FAC740ED91CC9B87404D07206B776806CF072784F1FC9E7624F9060EF5AE06BA682E7336CB06E01DF6C35EBE9D64F1F80706FCFF3A638606A6FA80E0DD0D022065E15BF78691F84BC1A5E1E60CFFC682FE44ADE104E20B4C868DEC44E205068EF601E50873C13B3BF0D6619DF512D746F673F0C4E90651D78DE24181EF0A87FF1801B57655F086507549AA81F653FB820983885641F64DF70EA849C746488643F57F25C4B4F072007586F423E7863B01E80809A90ABCF636306266482AF63634BC8E6A84F0684621E315C1DC4583F622F5E6C02395062184F2862DE2427B86F78610A1EA044F0AA78501FD4603F77702ED8004F284F0EBBD43A081F604FCF185F3A8E9C00FF685F905F0FCF4BA69B129F5D8F0E14EA01B2192E105EA05CF00079708FC05CE45B034EE244DF205CFFC8CB57C0445B2F545B805BCFF366135A4FD00E03F8281EC8A9524F905A985A4A2E96404F58BD44A1DD43AC59CF1E68BD850C701F591E303521A76AFFEC575809E45552CE80C85757D59BD8A056EFC01E382FE0B5970889558F1E284F56BB5872681F4F3531A1111F540F55B790CFD46F0464541E7C5A72B5389F0CAF542736410D9F534FE8535EC8953428ACB853AE1732C19F7880536F25CFB5090C4F04404C4843600F525213324124DF5252C3844C205252CF92E7DA04584F03782C218DB52F52EF0B76211708104F8C949CD8E0519FE85177F90A0DDF509FE050104E1AB80A8988DF4FB5098A899F501F404F51484DDD0CBF4FDF4AEC2ED23F4E0E1FB84E5F6AE2C603E84DAF4D47606D827F904F9F90E404414D3FFC4CE05488770F4E60CFA84B202F5E6AEF0E0C6E404C6862244E644B2F4B13117082EF244B9F4B913C80422FF84A9A900DC6069E784A4AA45B9BA07F484F9F50DA427EAD6F494F989085B8022EC44949EF62075CDF7C9F984F6E62AA116F49BF4498900949496F955C040'
	$sHexData &= '7003F10043B21BB9FD848E048EFE402B9D8B84FC0980BB9402EA078211314C08048BF4817324130488F20287171BD604FDC471F47CFBB36C1AF4C4F091E8030E5B9E46A9F0C0318229AAA819F46EFB9900976D8464F80909E6B472B7F4F0258BB902B79282830EF0A27E405E045F045F25C4B502F4F03B074212F56BF454520264E40EF5845EF1227023CF8445F1045C0C5F5800F98441F445B1C139C2F44AF4FB7900F57042ECC431E251772B5384F6C905D427A635F431E989001465F4343609A80123F428FD526269DA842EF42EF5A423E88DE424FB19201B6EF3840AD0BF9FF4141FF7A895878CC400F1E68BC845C15CF401E4020105E153F28402FA68999983EDF3E3FC48FB509884FCF3E302113545F3E3E052C01138F4F05C805C828102F6402E4F83DE06F12ACA10CFD833A0AD7233CBEC27C811796E3F03F6C556FF31C20417F432E5F6701C246461E0F00FF7F0FB941BBD0F726074548865AA0070100F215B1A101B7063010A2E0F60104A9280F301F1C79880D0F052BD02D946482931F3F065864D03D501400D60370404A12DA41C375FAC006BD133F8AB16D6D10178717FF1D31DCD77FAE2D901B2964F3EE6013381329F9AE19E73F905E181E53C8AB759701FF6013B88415F23CE0B88D08BEE6473F181405070AB90A86A7020FE053B260F330552031AE4014803B2127905B6828C0414F2527E404F017605EE614D2603F30E049872826CDE821E09F10463D916C3658290815E8220548DAF380CF2858317E48A73981BC00236061384E11BC9288B02BBF104187D8A4D96E8025C04F5060E7226936E82FE828069792CD0029101687FFE39BD8ADAE578876C02D34BB14B2D6381B9F204503DAB1E4957034C72986C72A2FEE2FC34AB6CD4056101CFED8169EC716C1C3E066806FDF173A815C5C3F41B018B2D99CA23FF854C81E58176382E244601D1F90C79960AF4FD846FF30CF3716C310F08727360F880E3205FFE840683660070D78188FA87F0BA4D9BCD0478027487302F9BC03FE0AC01DB048202F9266701588201748361B4E804FDE5823C818736A7A9A28973F305AB613C966F02C0819685C4E602064C72B6930582FAEF82958451E29278FA0B808F04ECF58DF82EA849C0030584F1FD3708AE82D2F70484EA09B0EA6E4F019680E98A72790431CAF28283035369B130CAFC05FD031601A49B39D48004E4E801788E9E81E5C30EE183236A6206F2350B15FC70790AA775A1F4F78377633163090130C2F385CDF88290A39819CE840683644B26173504AA827AE601B2F1A90E4802C77D060097925055E044022281E13C8304DB08EBF8A01498E1C47E02184C487CFB6B33915FFE04CF0249FD83D87183FB06121CE4F1A4C0E2EB0E604BFA87282E2D54F4050'
	$sHexData &= '2F40327DE18514E6BEF8945BC0AB9FB849AF90025C3AA79EB6350E4E03A650DF202A9E1D2728AE18774C2F08241FAE4D21409708E60826D389A90A46202F582C4F57582D0501F71CC8A9125F0029107C24398180250790424E502FF024AFA22BBC26FE90F7A82EB009530CFF705F0939C10EC7EFA023075617DAF0524E09FF87882E0056C727DF077E3527F858280E481F2F27924D53228EB02BC02A1A0A8A24B75887188C78BE380E7FF05B07F280120F402C5014F2B492532E1DA0672CC0A0EF47734535C1CF314F430E4DA761982B1EA08FC05F30859C40D031B03C68AE76A7CF518856082169B689224F624E981730E004C32BA04E3FD0270F30408ABF764F8020785088216F48266FE8C0D79CB8543036C021BF250F0F9922C8249E190B640239606138418181752B68374B0FC98607321C1834CE8028816C9B136059D8174E9822D66A72359886045FC04FED0411AE587F9836FFD7F02258AFC8295F19B4DA800A1727E75D1B9117EF787EE0C6AA26D850375FD8F7560364A85F2D16498B869FEFB8238F4E747C92663EE0233FC82595A0C04950436F01F68C450766024F4A110D5D6F37FF920A830EB68E4E246AC2D39CC833C070EF4FAB60D1F74F1F48F282521F181A2E82138C3FA81D7F496CB036C14F48971F105DC71472811570CFE32457C77F2A6033AD2EA4E4762EC7C8098223F7AF101C9D2B694E104F08D8C78C21427F22AF28171C0F922EB0423F1803422C21874F2445D85CE0881F862647A42871E0CFD63B5EED11AEE06F5830BED01C578C9A34087F803925BB9A44289E2827C820563B40225F6F2D86F494471996C4961C513FB0D727580F23771FCFA8241BDF585D8F4704015EED1FA7182CEF157282E97050EF482A12C823D4309F6852A9FDB8087718D67820FF530C17C82844332F00825A171CBF481FA2E28341C69F1829AF38C909766035AFB81E401E92810695FFCFF0E994607F865FA098E4C0550F083637C80B8A2BE06F881F951284588F3E1E32C485BF36482457884127DF7F88754A9E9A5F1A7E2AD83510A352726E32C716C104C762AF986F70B50AAC97BFBF5430F9BA876826058FA1175860F6CE482B79516BC49F7F4835855E510A97405F2FD715D704320F1A5FC803225C4F7F58232999401E885F1A4E157619A7D77054908BE0378F10CF98020322BCF02E9F35EAE38217209E107F426D31284701D4EB7000DFCF1047017038608F182EEF1A6EF24266043E262DB8A0444AC701B45F485C976E702D4FDA33CE48966E984F57C701B006029F600501A6902030CFD41AE28806DF2ECF4CC809E4B061A821A014D3090A9F40296F577182E09832FF70243F46D50B9960AF58B0164E5C682567B814B7C4850B02EF1B6F3D000760B68E183CA'
	$sHexData &= '0C2ABA70825DFD0473A9009066F2790E96213DCDF684FF003644A16EED82A4318A2C6494EBF3038159A60DFC07F6814915CD52AAFAF0079153C6A06022F28361348720A90262479C0A25F2EB00F9A810FC7DF1037172A4D20578E8EF8D478D0A430EFD02E3F41A02113284703116070C09E47D05A04171C2F78072087285676CF50279460004E0834BF525A710A3720577F47C806AD379EE827981D5060922C14AF0155D56811F7CF70FF55B8B880F7B06F49B379B58F80468030B88E04275ED055BF775580BBB4C7016FD48D29E4D817D08F200FF9A1AE5031504A80C162488F867A110D188F27E81BABAD58955F5FCF4850BD90E8C02FAF09225DCCB7E0CFD7E03A097E1FCFB0AA7117388E575635BEBA5F6016058F0006D5D83F8F088187744F35D053BF38F140263408338F91DC200CAF086B47153A3025BF40E790A9124F07FF082249830904871A0269AD15F77F34314D7060572F258F06C00048663F1170D080360F08EF7DEAA904562E405ED1D78A7F4FA74028130427189FB0487F70BD78A4901506DFC09ACD21B6FF4FC045D82BE805F8C24A776FAE2B9D13805BFE37DF714C20A75044900FE401D560065FD82B13FFFF9F525344536871485260131343807EB897C92BA86DF7FFFF1B373A5C496D616765536561726368444C4C5F5544465C5F11A16D37370A53524352656C3673654D486CC3FE7836342E706462BF2307789A7F618FC84743544C0010502EB7073F40E0246469A71326406604456C81276D6E777904413E7F6CDE2724303000B0E030290EB2B57846AA1EF4047964B19ADDFF6C262809696461746124359728B910569E7653866366671E38084352B1871580C4434137274CF23C344CB74E5055B0A309A9985AAF9FE44BEC7244A8274FB095895D0E49B82743C039902F2177C84C84542676D02743D8C89790CA44E09FE8F912BB1C50F0274FF893B497035400BA26205AA13C7C2A207058EE72C1D983717E123F1F2454AFCDCA21DF26DC24729C370CFC3AEC90047A007E67EEA83B053BD8E58F727463244941B0275AEFE48D0CECB84F54C02610D33D6C364FD027746C731FE0CB4E63E4B40124BE943D075F0A7B1F64AF26C8BCA6784641B62368FA1EA802005359A5F98E10FD48654784E37860F61801FF32A772C86B87FF26003388AFA470454F3467EE280B488063273681987CF79CE677BD961ED021CB83857A84400E380AAE6273146ECF66401E484E7061C0D0A4FAA0061773488831DA60C877AF26F00346015714C983800001E6FD4A1AFE0632023019150E72EDF65AD5807818302F010A1E0A34060632143E9BF70670190F4652B076100514FD81C40FBF190DE80416F6740AF237082D2F677BAEA4BDE00F2E52B8828FF33C7957902EAD'
	$sHexData &= '010442F7BA33306F6837D416EB4EB9B5AB7501F5BF404F01B5D947D80F3B172F45176F11EF1DDC03DB185FDE0F5F7218429090171F3F5BF261391587280F6821F6564F5F2F20B3035A1F723F3881691A0C19670952576340F15657FF1658688B471F57175E45800D97CFF00E08569B6CA9246F27A3F9D9ED0F2E0F640706860F320B20914FDBFED6B20470036036FC788EC8520073F936C5C079D7CC0F3A270052C31D4FDE011E7128285F321EA9F06E7F24341D00140114A6F006E0ABF8C9C9C9D3AFA092E0ECDBC8D9DBEA7F4429BF72298E1F07B753C1992AAF11141614341077B6D99D06FF7847007A6E2B5FA2114376892B7F1F075645600B17CF6DB5912967B2581FB7B545C11BC70F0F8EC5420B973F1789EA5C07500EAF7A33EFAB879BA0112A1964096E08AFF93DC94A70280E4139006F5739223B501437191E37B0C3C9D3B7003210FE9F018E9CE2CA3A9FD13AED3A3F1E45B653D80D760D3B4772066C9E410B0A720B676139EC06B05EBF523CDA157C8C2727B788573C38B3DD01C7AA0FDD0F1CB1C14DF4E23F6056245F63D26C80D7207A019BBDBC4ECF423D863D5F9F1EB0153CCF02AB011FBF5E2057323830823EC9912347C63EDF3EEB3EC80C8B8E570F0940B31772108740AFD2E55B5D37E9416F1707E4216F8E6F0BA60AE80C6767AF6240DFCE428FE242AD244393DBEC045F34432F7F1FADF85F7DC5192A561B541100178E0B9207E0057004605B3B697657C00C4A50BF1FE4C8D9A75C2B44CF9744B3444D9DE16DE32F1F455F5245F98E22CC2F459F98C60C4605D7C6106F3F70BF8E4184CF70CA466FCF464E0C87480CBF47476F46DD93EE0E1F8D19236F0BC725274F8370CF203A800926D4DBE55F12489F488FC901AAC83F488FF80BAE20EC36E76FFD5FAFD0404EF0DD4F90DE33493F7C493220939CA80BA049097672724A4A4A8F8CBCE49280B0954AC268989C9CE0EFCF91B31372580B274B7F4F4BA51700B76D1F19C61A3414006F262B20960072FF3076825C5DC81DA7C0CC0E026E23BB85CFD87ABDBFD8CEEC044F0D4C4F554C1F8CBC93DB03E2A82FDAE41E03B908BAF3EFBF199F08A9C0D90B444DCF5B4D6F233CAA0668BF13021EA279D9011FE00AF07A4F785B27520F2F3F007B72A6B729E7904F9E4F3FBB4F16D96D53906F5F09503FB9924B06685440B9E44A2E9418E467384034AFF00947107B80137C232D0E23515F4C516E03C3C01F502FC86F407560C97B974E00FF030CDEDEA04EBD9F11182E16869393EF0CD208F778707C875EE433B0065E520E005F78E77989028F674EBE9B7C8F506E9F90D8B589E1DD6FF68F3F286792739CE028533F88533F9353201871E0621FCF4D047A6D009F4D546F2642F3F2575E173413000BF204D80'
	$sHexData &= '87AE946722257A07B2FAC047C96D4C70E305527CF9B4D4F5537AD1E05D6F162807C84558FFC55FF93CD812FB0084057260C0026640E002153E17FFB540D001C34160E520AF008E006D004C0CF08232778203C580F5458A913134E6E1FBF193F6047CEF5627F1F59AFB659CD59D7E8A2202E1D741346AE7A3ADC70153411A4D205E05F386B062021EFB7D07B9F23DFD4F5DC7BC7051E697C759918C2B47C6F024F06DBC2973A4C3F305B1CD99D97FF9638271849037C70BA5588A5271E9CEA043F143A5A37665AEF845A6767BB9B0ED7EF5ACF0B5BEF3F5B799EF7665F760E072E9408BADCE0BA3B48AEEB630E87190A02D14E872F4E5097381FDED5A6E90C04A6320750372754E0DB88770F111A066616498B2F54B6F20F2F10EB5274E4907C9C7C070FB92F090EC576C90F7F665CDF8E9CE0C8715CAC5CCFCD5CF75C70E114471E5D07345D0F212F0831502FE8070DC592DBE0F7EC7FF1E1C891EF9E01EEA65EC85EE25EBD76F9353F0D000692C0AF007D676790A68F88F3AE5F9FC65F4384A6054F6FAEF43A7191729697107D36DABA440FAF030F2FB27D791D5F4927EF7C4E4523AFA309C71C7D09173B72EA78377DEF527D68619FCEB5503894613F67797D3CCFF346840E0392059C6A83C5F1069F9E1F083B8F6D0B6A0B429BA6272AD8F682F6341A2E0116B6E717B9486F702EA2977D0E8A17385067EFF57D7F2AE01BA51E17430B4F6EA9706E62BF2FBE0263DE6DE40C5F2F633C1F5D0E04728EDD796D019763CFAD6307A421164F1648078E9CE021107E671C7E397ECD840707FF0B640F647B6ECF9BCF760E02831FA103EEBCAB2EE4B16430AA1E6426F6258C7C873C5E2220F6030150E911B69D5C0FE78F0321CFF32E824E058E0376DD767208090F1FF14E2F77FCDADECF8FCF0CFFF45E7B07C750059F9A66381F2D6579DE862B3F65DF0E027B9E37B2D1871A66360E055846BEE77907800D7E9666B5F33C43E8AEC70E09D2B12E3CCF0BDC0C5FD47C3BD7FF202F70210505A49E011B5E2067C6069060D29AE9DE211F673CE4AAC66F06DF677634692E1F674FD04F3975E2BC58689FA806DC8CB703C44FDB689F02C5C95F43B64F80067F0FE224E7380C7FC7187F2769E9795E2E3F0E0269036ED38835DFDF589F300402607BE26FD7974CED1537246A3F0864F742B427111C161C2E10D20C70C779136764E0054055949253BD0F587F97647F9A09233F3EC26A6A9F6B6138F1A63F1A0E05EF0AEA0E397027B805DD4E4E0D4B3E9EF36BFF90054D4E7142646C9F7B6C72F692ABCF68056D5F636DDB855C6CBF40B45F538B5A93CBB7C92BD482872F18059430401E707F8BF1666FD366705F780E027E8470F7CCA6231902CE012BAE4020E97BA2DB21081E08342A7E3ECB'
	$sHexData &= '06A854A7C6B1963F1F979FC131E1A592F0041F8016849CE2EC5F731785730FDD73B653C3840F1F96344E0655EFC1B5017A06BE0F02B63BAA2AF8AAEDAE643826346416015CC6F009E007C0F9260054AA37C8DED202BE1BEE189087B607C20EE67539C109CEEF3F76CFE976EFCE77110C6E1C8478BF1F8118F8DB3AEE296826002534569E2E3CC36E0C6B700560EFA0527C4E469E0280D0DCB4799123478EC379FE79767A6030E8C80E7C327C0F1F408AA30F13DFC6601040792564079F6017DFE9C07D56065C565F1F4CC92BD6A7780480CB37EE91927E080E7E4DC0F3BCE81E02F401D7472E5A4C09AF220676947FE683B76C56A67F0F67340D6C36CD9392640C7F0C801057CF015B9B1F5F8081E3589B34401F9F9ACDB7DB211F6E1F64065E7407006082858270C18E36587A27001F81C34080B7504E42701B790E5D83207620341C360DF004185747BF28549A93930480800180EEEE769B2F9D8FB30E4FEF830020F2055EAF844FEB846BC191078E54520BF75B6F45AA9EA086063841DEF7732E27E4091FD12648D04E79DF68021FD6265C9E1F9CADBDB5671FAFF7640A66DB4CF20954B087CEE4876D7BDD92B41FE906C48F1FF9B6030B6701158615740664073EC774B334063211E0DF3734366DF82B9ED62C96F00AE008D006C0BFAD74503EDF0050A7802367F8220E598A9FA78AE44162C4918B5A8C6F9673D8D3F51A01367F600330B7D8037272C549A2B07FBCC8E2B47772D4E00F01328D23478E9C9F438DA58DB88DCB3EC2D9918D6B8F1FD2907F2A91171790083F471132A3AE499F038F8144A5B3EF200E97107FD5101F08AF28B48F97880305232F8F5F6792D992244A093D339801F652276043D442E092745F5F3C909758DEE45A30818BCB00BC3D938F0E57B15B25B61F1FC7193357A83D5D2E2134589E50FEF05EC0037057C933C1026007387368ECED99905B50581744946F6776E4EC96941F25953595576AE93BE1527FEFE0097008607E538310D73F360E1C0133000DF0E635D2F136D073DE10036E979191018282280F4E98F64E4E5A664F01D9E41C4F2E1FF488966FB796EB2E13708F97EF0E73DC1FC7D98778B098FF26996FBC999F17608816EF355E243438493618F20013013277E8023EB79393909CA80FCE789ACE5EA6061F9AD49AFF329B9CE9C8094FAD9BF29BEFF49CD080ED85360BFE64526651C9395675064AB7CFC002919DD630E037F7EC826E3FB4BBF80EC72F83F7410F4F799EE779025F076B08637B9EE77709830A9FEBB45D7E368F839B0F0F0B0F83756DDA4F005F0FFEED36C049105D7E1F1127E4E593CEF49E2860A783339CF68EC22701ED9D7F3979DEC8919E619EB40E04E2E75D36E8050E189F470E0282971B9CB5B7B7A00045A14'
	$sHexData &= '7C97B1F74C3A2F7E80E0D1EF33D239FE669A30ED6A3F70FC30637F26E07A41B0EE704A6F7C56AD03B26A6AF6F47569110DA1FA735FE10C2279620643DFE7C0806583CE6E69F424E3E53DF98A301833772E4E483830484350E62674F9E054755843F65847F07C5276F0816097C5F050F711C39C391844EA8FFC8A8D3A89123478E1FA944A994A9363BF2BDE00E074E20AA62AACF851FB98645F49EABDF4F9854B16E2F192D8A1B64182E1773EB0D29CE144693FF90DD2A359284FF07034F26E405BF5C609C9BAC6767676767A8AD2FBDAD5FCCAD7F3FAE1DCDA3020F7002387A2A19FF15C0680E5627002234260016011EE84ABDA1D7484EDA278413011E505FCC84BF22AFE7BD91AF7D0E011EEB007F9DE0EC48B02CB11F0DB2B7A1B228108E9C3F04B327B3BF92FF2FF8193009466420001E341F0012011A0007E08B5CAD6720C2CF840FC4DB5570F867F6BFF6B41C39C1C4C7B54F64B6CDB6B323478ED7B64BB7BBB71FDE9008B43BABECB7AF2223A7A89FF801850AD944F80EF7112F12FF97C224AF6FD001B86F0D4973C9DDB8241CA8E776BBE16ED21730D73C0F488A354C9E0254277F4B85230F56B904BADF0ECFEC0CBB5F71BB0F7FBB1FA504C8F7463E1FBC6F0E057E95BC7597D7A5DF800160F7BD90171590CFAF5801EB767B3BA64FBDBD9F1E561E542186E1E8300E0E0E0760BF2FD28965304E850E01C19B9C3C8894B7F739C1911762BECCBFCFE8BF73CD281C85C00FC03F14315DC091C12AC1BF345E0BA958780CB20B26080136C9D943A085DFAC85D27F6F7676F6F7C1EFA3C2CFDFC2FFF51E009950473E0AC31CC31F2872900AE10C560AE000E609AC1DC0C7EF6F433872F61FC4CF70C486C4996146ADCF7F007FD0F4EE3839DCEC57FC0EA4955AA75E4FDE12AF1F3C1969CD0D0C9E929010869B23478E1C862C863C864EC51391902382C5FF232F87E407680044C73C1B4274E00B002BDE1BCE8223C4AB7F4000DF800F79BAEDE4505C1F0F0368350193E70474EF76F90BBB1FA986CFB586C10F6377B3DD3FB3C8C7C50EB7FFC807DE4C53FFC93FBE0E05AE6713E3652ECA45CA2FCB1F3CCB91272723DFF626CD9CEDCEC83DCDB0E7A8CE2FBFCEF80A478E10CF81D0BF31D1D94B1156DE6ED199D15F201CF9BCB01E0042D259D251A3FEC4CF3E0E002D782F0630AEE9F0FF7F0163000FF00DE00BD009C00770066005300450A7187B7232F2E202D0F905870F72E4C3332E03963A874687795E7713521EFF5E0E086A6A799EE709760A8274E40CA757BAD4BFCED46ED5EAC819CE2F01D6DF1BD674D6DDCD8E9C4FFFD61AD73FCB0E93A2C8D991B3D82FBDD8E1DB1FFCDB673872E4E0DCFBDC78DD9F80DE728623672F9BDEF3DECFFDDFF2BD8F38ACE0DFDB0E095E'
	$sHexData &= '25E103C89F3A3CE1DFFEE1500348F348FF2A20F02F3235B6FF06F2005F870E838E9CCDA5E29FE3BF86E5C9E5A9ED01111F1918DE09F2594FBD755F2427A2C7364C4E9EC842B0EF0067478A4EE7A6E7CF1AE84937AA810F0EDF8FA0C8911772C0DEE83FE9D2FC52E4C2E9E70908062A84B6011C9E1C561CECFABFA9961C1C9218F016E014D012C0100E2C0AD641A122DE112750E20AE1FDFF78F6729F870D52B0358F0F57DE3872A6B3ED1741EE4F9AEFD5EF1F2E8E2EEF175ED2439768E6792638670D0B0ADB4DC190329E281F7418066417E8186B363416F23706230CF0FF2FE623121FF01DE01BD019C01770166015309E577D5300EE36350017012EAEF00EE0213E53FC0CD00AC0087057506301CF2ABC293287E7F887A748588330E7DD79A6BD6F04881F002B2F060772A440B607BC6A103F00CF784648F6F99F37FADD4C2F23FA29FBAF690E91CF1BD9D7B9FBE71E060DFCA7F9BCD940FC3FD61E006DFE08CB14E3C8E3FEADFF3F52C2E31006D6D71E08BAA143A8EE17DF28466F3984CEFF888F0F9B0155013C9701FC01CFC015A0DA5B964A2042A85CFE464B2F46985D00358830785F002C6860E06F55DAA634CCF6C2CEF00CE00AD008C05C6EB60AFFD8E6A2050080E779379C8CAF980E02A4BC1B4E9E03B0BCCFC80E06F33CCFF3D407E008ECA4163ACF09F83789E779DE7B3F100E0C1E1C0D28E4D64D9E0E340F0C1F0BE4E4E4E40A090807E7E4E4E4060503191DD4C093404C89CF7D3C27EFB92F891E1E959520E4E476F2A1AD0FDEEAF3349FE7F625028A260EDDE479DE271E1A28260F26794E4E6E1F25032D32E7E4763B3E0F6F1F7B87C9F34E9E32939F0E34AB773B79DEB71E36C3CF0FDB1EE4794E9E39E7E73BF37B463EEFFF0E3D0B8B173F1EF3BCDBC9232F0F3B1E4247CFF33CCF4353445F458ECFF33C278E479A48A627CFF33C49B24ABECA3CCFF36E3FD60E4DE24EEE9EA7BD9DFA2F068C0E5112439E93E7791E532A3655799EE77942564E575A0B9D9EE7586615CE5FA51D3953046FA8049A051E03AA473E4D0804C6082D0901AF9EE7795E0E0650075E087C9EE779A409EC0A7E0A693ECFD30BBC0C3C0B0DF9349FE7850E140C10CB0FD37C9EA719E91AAF101B7B349FE64111024E121CE7120173E4F32EB21E232D139213F3B4274F1DB038140E1E8637F279DE201EFE211C15D90E912347BE22BE61166F17D917CF1BF9BCF71E248718AE0E25C49EA7F93C260C19275C289EE6D37CEB1A2D091B2ECC3972E47B2FBE541C621D6E1DEDC8A71D6F1E1E30882005210E34BC93F73C1C351E2D610E36D3DEDCF3A237AF1F55220E3DCF3B79CF653E1E87952E3FA59F77F23C40DEEE0E41D9239EA7F934433A24445A4575CFD37C0A25497B4AEF26BDEDC8A'
	$sHexData &= '71E4B712606273F0E4C349F37F21E2528910E4D5B294E7B4EDEF36B4F1EB6E6504E799E76E48F2A0F2B0E513F52DEC883E7BE482E902CC30E53B427CFF31EDD54ED212D0E55E779DEF332561E4557553BF2799E58BC59F82F29304F66383B3B6E306F84308F3731AF47F39E93F70E381E768A393EAD78F23CCF3BBD3CE32332BC93F7A64F330E311E546B2E323827CFF37B33A1E7C66AAB023F0FA9D4031D3F19340B46294E1C92A62820D8FE4F171929C22E8C8C0E05273AD59834AF26350F0D362FC52AC46EBF2E0776184612933770005FB0AE8ACFD39D93B0BC1FBC02C847CECE3E5C379FED37CF2B3898384FB3B7554F1F4B394F19DE07681F1D08BF3F21043A04C053658D86703E563973AE5D329C8E1614F47A84F3BEED0AE40B36740C2F8F36303BE57D0FEF0E1FC626448E1F6BE70D125E7E007770C85B7B4FCF4E0600AC61B1500757F40C0EF8FFE6FB4620540E340B321CF01AE018D016C014700109DB85C04DEE7205F092302116A616E4B6AF1868060EE60556803DA6AE3D65073669F41F1927F61D4217D07C1BD737C093FF4938470A010D010601E79067D820082F0C083026A881596731D415A06D605415BA34F00E028C7C5A6C5FB7886208E0E3C8299E77438F8F430744613A118B4FCF13C9D323DB4E0BB29B4F605AE88AB3CFF0B8467FB947DF29B0A8516156C27397AAF14C0F3852177FB68F706429482F491F6A499FA03BF502BE06130116BB9237C06F10A6A2D57F9C2A387B204B9F5B4B3FE8FD125270E387DB4F78736FAF0A4D6F454DCF260E9017D719B05505C0ABBF2409C618CF808DB6201F4F9F712C54BC01146E148E54FB19F4019714529E761864130674F6CD6654123411B214F012E02E775096A6592416191E6454F43D6D8097F786E055B6D8B259A63156C4761F467673349000CE33256419361D52805FCE15F283C7C0BE91373C7287008D0C0E7B57393BC7196F4C589F44591FCC591542831E1925094E1ABF7C2C2C08FF9FD419D8B2D91456596D5A68771F552F92B64600193AE62834E06AC7C41DE6741CFE1B561A99E352207616D04F98D54DACE3AB0FA7E32E3FEA208D0F2C8D380E032B74A17F4E2F074EE027677805B7448D1CD961202F385E5C5E799EE78D750E018402B7E5CA9FC0DE255F013D6001E7E4BDD9626F370E071E4970C06071134FBF544FC703DE1E645E1A0EFF2727CF8B7F705A606CC4D01238278D176FDD04DF8C1E49634F810EB7383BC15963EFD9644FFB641F9C658B0067275FC8662FDE661F6036DBC5320D2634066433343299C624978EC35F220362C95001DFE65CC4924E3F803F6C766C1812907216B972B07930960EB61F014605AC52A19E19D6048223CD6D4C6772AFFD1F9C60E4E5A08DB08D756FD5'
	$sHexData &= '755AA820522FEF1F05242E841F079686D7AF20FDBF2FF8FC2523CF250C22D0A34438862F255EDE341B1D690A92DB9FA8FC4A407CC185C09F867B019113446E9F147C01BF597CDA2EB982190F80995F08DCAA11777FCF0532811C58FC303C0558C908E6060F0A2EDF047E0E00089204FBCF478E3C99D06881BB81D981939C92230082B8FB494437B490822F9BCD21A20F30875987387C1ADB832D1F012B762B6477017B3CBFFF1119370B391979441F90FBE0F0044C8E3C4A896A89393928D2DF179242CD8603ED1DBE1D864F9789F07668BF008EEF8D602B006E828EFF6E0E1F68244244AF6FC131D95DAE7F14914FF60502683F66F4925F98E63D42770FCE0E929531C34ECF470E973B19F96087F0FA10200EDA74EAEC2A948F4A947F92FF870A42C18FBF2B08F3EC1800AEF6541110E47BDC48D2C8F67CFF309E37C3E73C2F9A7F4C0E01CF2A4283701F1F2F9A85BBA09E6FA07E7BC883039F508E7A9DCFE09D7437BB0E1FD16A460168902E711FD63FD10131343760B716D96CFE740600E09F06A0107F1FD1211AB03F1933F62A74087625680A9E46153E707051127F786692C203391147708E7C8E291EC90F37888E24A31F209CDBC855A36D1FC3F3BC47E81FA44F9B0E01B76024E4D105FEE8A41B39ED556F50FACF9DA5B30EBBBBBA899F28563F54A6D33C0827301E1A1973C9834914D700A0A015048E1FB7CEF3223F278E0E05D5BEC2DBC001D7DF4FA75F67A752E8C809FFA5A7B9A7FF6E2347DE2F05A832A8661F9ABAE7794EC804F5065FA9634DCACE1F26A94F2F1CDFBB2A6F403E5A064881671C3A84B51F97D8F975CB4725DFC1A9010E029114F9AFAA4FA236B2D75F54AA4FEF936907F988F904F08E5FEA032B39D510AB5F28AB02D9E2A657608ECF88AC9309E46D383F14AD109C8253C1B4AD8FE8F82F34AEDEAE4A880FC03F008F354135697D7709D96CD8565FF660AFF69BAFC08225031B6C1FFF98914341E44AB07F70F8E2BB86C9C4B03748368DB1E0732D51CF3F2013B24CDA31712F076A0782F2036530AECE213F460F76F0BD804ECD067083671F1938B4E9306E46386428FE292600EB826698B70153F653E42A401374E6BE2C361260A23B9D26EA3F01020E5E2FDAD26C5B0690B6CED1B6E026008CC10E40001FF606292FAF09C770B75EBBC596CDB8B734841FA647B0E09416D7412F04BAE78F0AC6455B6B52328250673F130213F4111706DF9679DE65E4F8F78F3E0E01504CA7783B5E2F33BF7F52BF6FB2596FE484BFA00E027ED0BF32C156F2F2BFF7D0E7767272709EB00FBE72E4C8D9E3C0EF02C134C150C186851C3980C1A2C16F59F122AC8F30C24646C20830D8B2DC851F7F2D9F5791B69056C80886757A03831FB752B4D14A11674E0962771'
	$sHexData &= '0DBAAFF2FAE1F74165A506BF4001B34153E66E022E8B0F70617D0E0820BF0DE45C6DFC79F39102E0642D666AFB27D506BF7AE1AFE0BF2A3ED264D787F54CE70C94650AD2D7806B46F1FF70645767780FEDFCACB37E433F257EF58F7E0BDCCC36843C5AF1D361D4D06E991FF9F30907C0D9CBD0F74CDBF90CDCFC2CD6C3FA584566404063403C1D75CD5E04F74F04E63CE8E8D78B06580871F01189674E834DB1B3E761854187FB3DD7E9601162E16540C06340B3212F010E00EC0ADC238F40C700B60A7A7500BD3254FF70F2327386C0F48D55F7DD59B137BC080D53FE0F67F076BEB92B6D64F4F47D54623B6903FE71754A0C588770F93CDA6616ED916DAC088F078D06B1F1912E76632F2C53AD77F90F650551C797260A2DBDCDB6F37C954A1FF196896A950E2C0E9DE2FDF355C4DBA403E3F184F8585C2F2A4E1017FE2E09057B7F0F5704F59E523263F1EE201490EDCBCA4F31F54AF1FD7B7F49C9CE2FE02AE1CF200721DE301C8F5049023676F87865FACE3AFE7E3063CE45185E4EFA0F576E4B239C0B08F78F539E5892ADD14503E3F66C731428FE92E46E9CCA1B5C8D88A1F5F0B3999E38028F51F90A025758E3CCBE9EBE91F5BEE6005F621CF1E1B03342015965E50EE6A77360B2699EE648B5FE405B153DAEFF60A2739EF2E6CC61F42F23C2D86000000AE840EEC561F191B26F205E0A63D39047650341266F06CBB2ACD7CF0DC2C5E2CF40621D49A296C77BE12C40E5E740F0615F778EFDB4E5414478706ECB72A361C186C62270097DFDAB2D95EA0F356AFF34C8C1F06B902DB57B754609B349BCF770700B0F4DDF4801F3616D2124600DB4AD3BC77090807198E1E8E64FA42076D560E22BBC02B9C5C15ABFFEF00B02627839CC0F7F755B162A667D79790CDE6C0FA09FB508D278AB5535EA92E58AE1FD70EECAD8D87571F192BF2A6B916B6151412001CB26934AD18FF575B6BC010BF010E0206F4AFBCE052601F1FD8F49CD70D87D047DC1F6E8CABEC488703029F0E369B436CFEF750057A05708E812AAD451F67B0EDDD617FF007BE06B07F1F70AC66282766742E1C0C4FB86E0FCF92AB79E10F6788E46D76F692094FB0096FE51F110AE9072172450A0E22341D30402D54B6123F609A7872F27E82FCF0909EB6BBA3EFE19E27990B0E02B3719EE77901DD03F3BF6BC00A3FCF38C6540C02B339342C6F700C7F0C0E69B065E88F1F978EBC18AE106F270D3E0D65B339C1BF800D8F0D4890367068B01F07F39FA32BC171340E4FA76860DB7B76CA06A0AF1F19CB13C17577F35F291102DBDE1B1DFF2E5F06F09F1FEC2AB602A798AF45BD095EE0126FFE0E00E4C8DB543F705F309145132FAD447068131F3707300E5D207057B065B3596620164716A0911FF23C03'
	$sHexData &= '6C5FA0B2D06D070B6C1FD7410E4154251369067F6057625B369BDF059FB018F8181C921FDB4085067F0C1E0C32512B7618FF07B4A5D936EE201B9EAA1B6C26000D36D891001FB7B33DE4221752B01C76D31C8382B549C01FDF46207018374F9E7772C57F406E0E0180E4C82B4E8EAFBD1EDC1EF3464E750E1F6F2A1F5A0E03005B85CE7B5FE7DBC9C9C920A0CEE00F47CEDE9EEECD8FEC1FDF1E203A204AC891236A208B20CBB4A3D3FF0F16B2937CC64EBFFF08085337B5340747F804387282F25700927A241F565B8D483F0F17B0253A6F47E7229B154329CE5629AC945217D2D61F9F2F51BD2236F7D0F2BFC8216A3CA42D020FA8F2B2192B793092FE2E0293DBF2F22E022E021FD764679C93E2FEFF2F022779C80180F240922F02242F2F2F2F022F02300262EB0E3958F2B63ECF1100A3B60FCFDAB259713606663630961F512C11C5070F210DE9D209DE42340B1AF4D7363B1E273CB816D2129B1F4600228610B10F1F6822D85A5F0F19A6267CAE3730544B4F52777E7105DF04260500304C0610636DD3C0972F1F3F7B2ED4C40E462605D05EA4C026CFECF01FE0A3B59A27770D5774C7115F089F501F176DE4C8914E634E934EB72F67F63AA07FE0F17F60C5E8D2B7F73F134F024FF765B3E04540508E7750B49880C56EB11F9E47DADAB854BE04B717CFB66C3687105647561C991FD4B1962DCF274734DB4588A7599ECA59748C86039B1F0112F612C3526FAA5E1212320EE09F699E23B6579F5F5FC46289B6361F9F8F6BCB66F360638A630C9A1FA6B5B0608F77092D46DD7C0E3407321070E7E085888DD7570F0F6AD4088F2788A88F4BB2B8FE5A4FE7FB00B9925270020F910077DD752FA40E23B00E5F6D38B00857C7211E21B3265DD6640CC60BFF6F07F2B290F180929D1FDF712E646767CF1A72BF3872DF7F87BCA8B15768F1F7074064775E8F0D736F27C26D900A4057B07FBC9230397B206E73EF89735CC9C4709F7F18D02327788192741FD174E4AD51E7791E02F09F814CC981BFF0F0E0478E1C79B275F17504761076382222217F0A0A46A25A261146B6466C34D6728B2623BBB3CFEEE7F092FCB4601D041F27870669150F0F649D03793010270893097637C192774FBF0E0116785FEF79DEC88778B00E04C4055EDD4424BC91782B8E03CF24CF55835E2F0A09A32661B52707324C446A17CF34BC24C20687873248855005D631C62CAA125A0CA08701D771174CC38F40A75D0EF3BC9BB5571F750E0681708A5EC507E7949357257EAFBB19CE2F9E7E4FC70E57EC1E089BF1463E247F660E0A2E877FA04430210FB73A52093DEFC217FF1C3981BCA0938D80D38051CB298EE5809FF18043A3ABA69E06105E0FBF7037F152C8A7505200A3E0447581B7933FD'
	$sHexData &= '08100C88E9CEF598277821F8F907831EF28F06FC093AEDD32491797CCA7CFF237CEDE7FDA82EB4B839FA6832057C1F6C483BF8F00A7782157E020847FA9841CE8D8261FA7D8EF1C793295F00D9419943821478E25943194449447CE71222F6585AFDE850786E4C891232C866486A6868E981272C7866718CF823926A60B2F1B08C7C41832A787740D0A75900EB66F305F5837B10DE210B28BA859984B1FEF97042F13F2ECA194A78B5F9F859BE2038C3B570E8E7B9467EB6E24CF010B053ED92F3D510F2E38068E8BD4A92276153E058E408DB102E06B5E860630A27F60133BB3824637001F89784DC41F88EF297816A64F214611EE52145E51033FEF8F6C30E0578FEF8F2A90024243652FF1901F07526081F666FA8F21371E37F6016936DF7FD405007091B691F018EC62CFD4050F37001F57C994BC3792388862379990A3900117944A468E9C3F6F94B094BB017230DCD68F1039720A79E8EE3F967A969FF1811C4197F006D03B2166F3FC86448E44740E000AE4C4D097779E93CD449838A4E4C4469B1E6C6237001F01259A25E487A3B01176740F4E8AE47BA40A67F76207F005E0B3409BED4C4E4C3416D496C405A5D90A00AE9CEEE39CACD8E226CD08D436863FA91307BB001F11A609919797730FC0EED094169FF590FEB41C8E0D0D7209E0D663356187AF8F1F96C2A426062B1F999053C998EE98A5E0C891232FA9A2F2A21AA30FC1A5E40B95D7BF370F775642E7C00260664D4D340AD528362256058610C196CD86A42687A4E0A51F87BC1AA47F70EE209980A98595BFA61F6A89B18EA63FD6DED707190B23770AE02DB66CB6D64DA758A61FAB062CDA86471FDCD4AB8648C7FCA62F9133BC4C9579AABFD9AA825BC9C821AB5BCE1FB35D69243617642A06542992540B6634285610B651A326B716542B06AD5DE2CC342A46234FD6861DD5A774BE1857023C00A352E25E4556B3695AF9457405000E540C8EB1F9B1DFC4DA64A0A71F7F6244E00A3F8EDEC9C9D36F205A707E0F6FE404D701B4FF1AB4850E013F3139792EA2D0470942857524184EC2564C03B446671A4E1AF495464127FEC4660B86045DD6D736C0B78EDF0650A84F68A7B4DF0B1F45B826646E1F804D115867F6CE0AC27269AE3D92CF16160B0AD26C1E60B980B9B868DBEB14061FE606CCAF1F112CD05A67DFDF55D2584816D6041A750CC2F002CF154ED4B6422CDCCE10C40D260640BCBE0C049CCD61BC40A916BEEFC5060610642E34152FE00654A968818DF6F71F77D769B6EF190D05A650BED671BEAC75CB4F531D1D1354102FED602DB4ED06C0B71F7771C8216AEFF8ED9047CEF1DD779C0EAFC05FCCC04FC11547238102AF203620888A541B8E1C30A203B017EFEDEF613B7B798EC24AC3AF62'
	$sHexData &= 'C39FE600A771FF229E4AB778F9FC4A740C0013F4D40D50C47E0674606DC1B0AAAF1F87F9F402B27F06A615C45089064116C59EC63A3011AAA6AA6FC47E7482C18E6637001FCEDAA9019A05420A57B37D8CBC570BE4E6C776AFC7E482B56548AB1F2742B39D6ABB3C663C74C700C96E27C98E76064B8417062F00855682C11FC756D0ECBA7938464E4EC40576340E9AAD839816CA7E5ECAD45100AC4D1FB795F4AB81360E320A70210D9EDB27C02D5EF6C0CC7ECECCD3165B3624AC1F4E00F21958C8003708B5EB550CA8E7ACCDAFD75229AD0F085F86D036D825B6BDDF0690D71F6E47604086B6CF80CEC0AB2566EFDF50CFB7D8FBDC060600ADDF1FDF46E186B5275F02BFB6349B6D745E80D0C2D0441F40C32625EFB7894D9AED10D27E1ED2801F80612D0DB72F6F129B3CEFE08EEFC81F0938D60E8F276F585B36DB90D3A6BED30CAE1F2DCD766A0F50D55692D54C9ACDABAD1F5730D672D678EA24125B1F47D4C6A0B647C71160C904195F92ABED78E9E1AF57305E72B0F7D9E24F3F08ADE38D40A2041F77EF6A00563F13BFAD26E00BA78FC288D8A27F4700665CD54F17EE415BB5559767E7410CAB861FBF37163780174F29C2094EE0EC6790FDDF83E4D05DEEF004E0B6B65DB2ABE6740C0BAE0A46F2BA09D6367D0650B1771F674260799E0807063F533004210F1CA7287835183897B8EC7BE40AE9B766B0AA07030FBE3500E7C82FA7827543EFA3BF90763B7F51451D2BEF87721180B00FFF059FB40772B2C0954648110903B5BBEE7C0F24BFE33623EE95F2A531859795DF0796068B5AC03F47ECC40A01BF0F72007901A71068EC7A14F2F220962C9638B3E5431E143F38967E0A0397BBF359AB0E1FFE77520B036BE77927B30B1FA2B60E04D11815C006BF5B96AFBAF446346719773412CFE4E4E4C1A740707C420E052B9704B48E6CB064889F980CA10C76E40447D30C7F2E0D5C0D1FC987E76484B6040ECF0D277EAE829F40111C07BEA5DBAA421F4E1EDE1CAFA8753A37189FC0962F2F2F2FE096EC96F896049797BF80210E940E030F9ED7DD0CBF2A0E3F4F1E0886631B6A4D5F2F2A17F21A022BA5676E07EB1493A490C6A75B1676DE02F6511FFB0F934B9E6B4F07C509144F457A0F4FCCB5055F5C74E7760627E08F088E0B0270429EF4B520977A21EFA8D75D2658D197DDC80EA9175F4111970EEAA678D21FE87712CFB40E1E374343B7137F630EE7348FDEC84B97BF0E048E1898096B03E785F0EB26D86C3180428B3E2FA42F54128F272F03C400BE6613B7C826530D703E4C9798912327F80E06147F68158015333B66E86C16030F82EFA00C0F5580B744B7059F0067471E40982617FF639825478E9C9F6E987C988798A7C9B8602701C7111B9E9A2B002E1'
	$sHexData &= 'E1C4E1A350183437876CF333DB95DA0DFBDC9984FD569B9786E2FE1085EEDC89123A76F13184B187118CED37CDEEF0E0914190A4B836095002F7727921754C750EB0099E4C8912320992C993899C8A94E724499141ABF841A0B3972E4AA1ACF1A061B1C4C515937282E7A33FC381707606F991FCD1C99E9911B281D034F1D1D1E2AA060267FF332F36E05806991E41E078EE61B9D8D246F72DBA1CC116F38F746E0216BA9B16D8E3222066CB9571F7270750BF70056428E9CE0738084232FB52301100DB73EB3365E1032FF50DA2AD48027AF1751576A1537725794511F18D7160C540DBE6CD92C28C62A6E4B2A24BA1F9ACF401B6FE01B2B5CB046AD4D1FE7D68D30451F92FF60211C50CD05858EF4AE14E409749366F3B74E540FBE0E00F02C2F2DB48EE45A601F7F506436693647102E4F2EF41F248718B537D8EA9DCBB7C8990F9F2F03BC4A8CE4473E2C30037F0399C0B8725FEA8A43DBD967318F7D317F8F2DB25970B03286BE32C8BB1FA4B575688F2F95BED8D17788FF9C33034FD8FBDE10C036CF0638BCDF1F86B690B64600D7600E55E94B9C34034F703597D8A4D9DE7F35A81FDFDBD4A1B527E7365E72363424B634EC1FAFD8B2D90E60376E6E3720BD1F18D6D2B0AF2F5F9366330C088E0F3868C1DA41621F7F277FDAD27C53C05E0239AC1FC9D3BCDA577039B2D8569184B51FAF4B254C876709F7375CD4D328CF382A8F60A1294F0A3F03876F1626AF64105A408B365AA29F8F1F814008045747FC5A4EAD6017340CFEA0440DB66C3616D044D4BE1FA7E8550D8FE8E92FC44626A508A4030FBFDAD5640C8FC0977437B2C1FFA249CB0E1FE296BA9E9CFB1E4A4FD79CBD640898124BAF3B4BA93DB98D521F6B8E4BCF0379351A7F70E92E6E08D9254C7F2F48724C46DE4FB099C61E3221ED8A2E0BAE542062728217A44D2FBB4D5E0D304FDF3647F8E88CC8D94348516F5E51B7E6ED0A57D04FC099DD3FE6D937506C5FDFA84E24523F3042CF045F0A096F2FF0003980E88D52CFB66C4F6E9752CD1FE62753DF2EB63821FF9F6017C810DB4FFF30BDB32723B753DF53FD1654FF57EC4226905408904F63999017E0E7DD377B6D82FFB8573C554F530EAE854E081F4F94E492814D3F68D404C14BAE4015566F15BC5DC818644F7B561F45605B3BF0E6DF4FBAF106F9FF12C846836F30D2C140BF9999991B47B737048F05811C692603068CC391232FDEE886387E28573A57B95DBED065570FA657C53FE2FB8C96C28F9A470E0E240A3DCF051D040F5E32101877DFA0145844FB2D447F1146D2E4851CFCDF78DE6B409A093915724C9A7CC43972E4C8589A6A587C58A75823478E1C1C593B594E5973732527277E8D7807868888A7148E016A094B129F0E90A9A8D297'
	$sHexData &= 'D2509E29D9E3B68F545D289438F1CAD82F8F1257D291386F006E6AF79A09D8AD218F0FC89A3CA2861617C71B5E377286331F2E5E4F5A5E6A1EE7DD4E9E047F883FA70E050C043B9CB16FC05E3F0EF6904368B7D8E5E09AEF91539C9D295F5F4F5F4F745F99E404C1935FCFB0E5F053C80B39FC089BFB72E4046FCF0E60BF3A604A60478E1C395F60686087609160D0419323A060870F2579C941C788209B23474EF0DF61CF34618161A0A950276C2FEFE2A620D378BAA592A76042C8D923B9279B59649F646464159EDB771F7E020E8D64C9D09EB137C7389CED567240014965CF54659323478E67656E657D6532706DB43FC63FC654081101639FEF6E23311A971FCBF8A9181BE61B0AD206F05D10D91F10E5375C0EB06C00101A480F3E610AA8A68E21205E1CB327B319C7E467707C9B1F88EC857C3C024694536D9FBD8D9CE3796D1F9E6DD51F19167827C640CF472118350A762CCE18F40E13E4060E974F7CADAA0C7E6E4E7506D8C817095D3AB01F01088662019E3F30DA4621260A00261B6E6CFE6C367E6406540D0B00206F376FD81A6CD91CC91FB7CC00F2E71170D605818DD4201E0FF2274FAE7807C0CE72BFB0D37721A0F0147F287803BFA41BCCD612F2EB77987072F6B9C055796FC77934D99A856F8EE616F26FEF434F4E9E707AD0B37AAF4809F9DFCC7B6F1805A6B87450F614309F484B2E4E4EE0EC7E016605DCC8A07DC50ECF1FF3243EF01117EE10A78F1B39F2A420009C0C9C181F676527788A7E3FB27E8F5F323B20CD1F1EF8E38F306FA420723C4E9C541E03EC16E13C6077BF5D7FD7EE468E837FEF0E331480CF6DA8213B4B801F1FD0FFC889E1C9808C9C1F708186A66DE49581CC1FB7A834BD9DDC8FA0AC0F9082BF333DB94D806FC0CC9CBFD8474EC8919CE49C33835983C4C991237E83B58322034228AAD6E2B3E4BF088C0FDF17000CD273B1030F58E31FA69DD99C9C684B8BAFA08B270FD2A2CFB529306F10AD8CAF9BE454721F8D08E32076057C71BA6FE40F8F0303A10DA8BF1F923FAF794FC6154615155211E0C0AB5A0197E0E25FE805E9673F1495FF459515B45C20091F89F5B51310965E2B06C0CD6FD0AA5A6B1FD740B848D557076D4369D397D4C40B6FC097CEDFC4832D9B9718CE1F010D5D0B178D463282D04B369B67F377F40D74546098809810043669541F179334341E12066E8B37000A7C60211386D60A540C9366DB020770999E9F99A48F2368601F01CE722259F0B4756F23F623F49ED44616749366F3F754077E0F00609A859AE05C9556601F0FB8A7F8B4585E5740919B3FAE9B9DD0804B2FB7AB6D0F7990E2F99C5F4F4B09F69268B99DAFB435E88AFF1137975AC9B5B4D73F1822925685B7CF93973FF4F0E12F509DCAA7C'
	$sHexData &= '476140927C857C6C48618579D1F01E5811CE94E02A4D06C9DF4BA9BE1A1A8EFDD0E4F8B2E02AB48B708CFCE2F07C8E3D0A0E15F87AA784AEB7D6B4701AB4FDFBC648085BF50D7AB931732812850AC033875090F191CF524CE91DED61716B95ED28DAA87008EAD5FED54A0C9A5AD57D8E05F975C6D3B9EAEDF4FB06EA6510BA2AFAFAF889D8A6CDE5FA09D32B177E404AF5D60AF18B45F2FB42F7462C7AFC72F9990131C8F38E0B02713F20AECD2BCB15BC9C891B8EDB8DBCF815E2886C7F7A626B2B7489D0FC0B98F1702867CFF113EDF72E4EC21109E6F1C9E4CBA14990A3864BABFBAF318CBA506427F04673EA806060EAE344E6D2D05BED606A0D30F1F779B349B4380BB96BBDC1F9E6A255A0F4E1432AC5B77121FC021128E74776B91CDE640BC88BC18D41FD08E620B671E861E5C80FF1B7E1E321AF018E016D014C01246601050F836E06D87DEF23E1C32C5F7DF303601C11846F2130F54C1C717864B069840B70E11393BC33CC2BF54C29F6DC23780BB38DF707E37B7DB65A49E9E781FCA7FF2E42AF8384F0748BC7C3BB9909C9FCCC303E4C3B5099013AFFDC320A791B3CFC9B0BCDCC49FF4C40487A2C80DC55FF8DEAF14D1DBC9D0DC0FA0C55FF67632EDD0DEE7F0FC0F2CC6EFC011397244C65DC66FCDE649730E0E80C6C8C6509938D696D61F6F50D2FFFF561A661A4216F014E012D010C00E700D600C500B30E378E994173415C66F09B6E9C4A8DE3F9F1627CB2F40EEA1C87ACB1F620360C602965636F6F72C0817963F56B1062A11D882E8371F8F30A4801A249692D528E06907804BFF202F6A210788D7E11C0F79209F14CFCF50CFC18DE4679F4E9FEE3F794172005828D839F29209602FD261D207902B198E582D0848A8145E26B69205498331AB4730099E5CC8CCA047D53F845BC9C880D5CEE766AC662CD747CF2D9B1DAFB0D656CAD628D9583543831F97AE00C2115E07089BE0C8AB3FE09F08D85F250EA00585803FE010F02AD7E0DDB725065B3BB82F777F02DE6E13904FF0FF0ADDC55E3BA2AF68A727DE4F51175E3240D7DE8F2590CDDB185F00A0E2DF4AB1B46227EE60B37985401E26090050E1C7E14F60B065B8DA1F7F198B93B0060F2E8F12AF17F0DC6FFBE21196077242C8DC8AE36C36070A2F70E4E7E450DB2D45B0B61F2F9F9B349B0380E6F7E6A01F3788105B9FA7BCDA98320AC7B790E8D8DAA4D9A2E8FC1F872D9BCD23D0E9E2E940DCD99C82AD1F8710EB22EB44D4DAA4841F173669B64330EF664AEFBC1F1C0B4E04BFFF279B570CA0FF10A0F1F026699A63029E1D1B14139E7401677820A02FCF1B8E2D0F3F382E035ECFFB8427A4F16FC40E02DFFBA88E3ADFF2BFF40E01F2A3845E53F303CA0155C61EEEC267B48AA535E7C75A2B63'
	$sHexData &= '07779A6997B5141E08EE0D6406E86B5F0FB0F6C6B906DCDD37B453DE77C40C1FE526E8861F2154602D67A7E4E464A85750909C337C4E2EA8CE14F94F3472E4C891F94FF9A3F964FA66EA0239C3FA28AF6BF223B57728DC3B7B8B749EA10F31FBDF8FFB9F1964A822EF00A16F930B39A1A12F44FC3972E4049F64FC7FFCD3FC90408E1C94FDF3FD391939541FD8DB909CC893930BA8CEE4FE1B3972E404FF1FFF73FF340B604070DA0E931F426BE4546FB0DBA25E9E0C156C6F5F8810A21B3921471CA228A24E2FF3BCD77894010FB40E02CF39F272835F230204E402430376137802191A060F9DD889B19EC7E72006F91D0B4E3207F0212034C5FA56D46EC406BE0BA1CF060610E1670C1F8C6BA19DF226207E1F671A09184D5F77546599C75817084D9ACD7067588EF5077CCBC444AC1F3F082E06E26A2719BFDB463C6A862F14E28FEE662F0F80A2C80B77E10E019B1BCDD09AA21FBFFFAA40885BAFFF820221D827EF6DB2D9F06014E67A14B4E21F9423466BBF07829A1AD03FE7755301D847DFAD0AD6566F575A10A4825F77571D81DBF7D78031309990E4A05F958C9CA324DFEA24BF85A340B8C647213A7447255E740A1D6420461FC82835AB76011CE01FE19D742B27A7D0DC0F5B618C0EFFCF1F289C42A1069FB8A34420BA41AF0B09AF27E40FE454E5E8A204004824A37B1B0C7A27A727BD25F772E40438E725EF23263D267B99183856264F267D264F5E6084338B6F3752A33CCFF3467B0E07860699320CCFF308A3099F52D518B533101FCF2085204EE8DA3F50919DBD0F1827FF2F271F2F90930B39C0DAA3A321A7908BA4ECE66F255772A3A4271C39C56901DD273F072843289123478E5D2876288028E4E4E4C89D28AB28A4A4E4E4E4E4A4A4A4A48A543BA44E1F3FE4C84BAE98112938290CC954724F2970A4855C849CA4A5B9920B398CE8A4A58E9C902BA5FD29272AC8912347632A7D2A962A393972E4A02ABD2ACB2AA539393939A5A5A5A5A89D2939A5701FE42557C53F48312B642A3972582B6F2B202E424E86A5A5A6C9859C422CEAA54EC8955CA6A61D2CC8912347472C832C9D2C1C3972E4B62CC02CDD2CEB2C9C9C9C9CA6A6A6A6CE949C9CA6A620C9AB62D41F3FF8D94A8E1C39512D782D8F2DC8C9859CD0D9A6A69053C845A7CCEBB9922BB9A6A7A772E4C8093D2E672EA32E478E1C39BD2ED62EE02EFD2E939393230B2FA7A792939393A7A7A7A72A52ED904E1F3F91232FB9A8712F982F029502B6AF1F3FF89002D1173FAA81A6524E091DAE1C20C54235461B561862642AE080D957A7A7E4148F0AC7DA334FFA338E1C39720A341A3424344234723200CB4FEF58F0C8915772FC2A354A351C3972E45A356A3574359235479E4C813010A81CA88E1'
	$sHexData &= 'C39257A369A36AA36C8912347BA36C436E236C9C9C91408303C9123475ECA37EA37FA370572E4C80A38143832382B391939E0D8505C3972E4C81A393A394A395A3901B08D1C6439824F4FAA847017B8C6DF0705EFEDDA5F063A9F4F9079252727707C6A3A23478E1C8A3A9A3AAA3AB432D0B6913AD24FDF6891577272909C4A3B3972E4C86A3B7A3B8A3B943B7232951CB23B40B0C8915772BC2A3C4A3C1C3972E45A3C6A3C743C923C7272329518D0DCE4C891570A3D2A3D3A3D951C39724A3D543D723D2B391939F0D7F0FC72E4C893EA0A3E1A3E2A3E49881C39343E523ED2090855FF5F0AC8A30E1DD70F88F2CBCB431E10A93C405F40D0841BC92FA9C70781178AC70F07930E5F5AD76FA00CA7E4C840A94CA9B3425F1C3972E4C342D342DD42FB42C9C9008BBF786023475EC96C434353436329E4C891436D438B43B992939350808CD33C393939E3F3FD1B447272328528A0ACE4C89157634473448344C91532728D44AB009E5CC9C9C0CCF30345C891234713451D453B45000BC5A89F0F03B181459FBA08880C4FD656AF9FA9EC81BC48BA80570F12B76BD72770471A3F0978AF12F1BF301FEE5A365B0AE0AE089EA9DE0E8FA0551311071301A7981780BC2F5E0A5EB11D2F57A8BC4F8842C072355C87DA8B4B449F4B640ED6F1D9C0FB06F3A90FFF500EEA5CC0DF720F0BBA04AC87AD88446CB7AFA520328E0F195646F9FE795E19F61919193215E01177092BAC0603D702EE406864BBE133060BAA47691E0C69276217B057679E372C48087F545E72228858F24E921E9DB5267171F7098F0F305C4CA00672B2701360E7E7CB36DFD566BD6A3EAA0F6F52D02E2E037F085A08D492FF149611010011623B9522569EF77206564AC2A8A4571D17B5BC27010777055558536986BAB83EC722D420619799605B69070F5F06383099E60512F738BE3C90474D8FD0F974AA01785887B56E6120998B7FBEAED360B806DE0D260EDE09A26DD1A047E7B763C1B16430872E084341C7729777C04463FA6FA02E918389D0E8FC271023F90D04EF1886687104E47725B73CBFE803C608FB05C9D5A6AD01B8CFC818EDD45E885F4FE04D4D75A91DA9162C78FBDFABA05D0A59F02EC0FC2640FCDF20A7E49B9045284E602D902260130C670FA8FCBF68CF6E2513BC30234FE8BF920B86C9603A6FE84FC9A9BD50234F584FB0D9025C4A1E054F30FB2E9D1A1E314F685C3FC02D624FC9A9FF286020150001E4D13E2AEE090627CA2EAE646AA74E2F4F880C955CED4A2C77ECE494BCDAA89FB20B582B293925A7E228162954B6BE92322C2C060F801D011100014125A9A020AA641401FBCF2980FFCD5D20D266D40E1B0C2CA68B77D28091D22F200FE4EDA28029073F7598FFFFC9AF04ADA0'
	$sHexData &= '002E3F4156747970655F696E666F4040620918205618B1ED955F40737464474F5B9A6309565F5F655BFB475B5F72756E74696DF465666F72E0ED047B51FF3F24B27369635FB6FDBF0D77627566405F5755286368D8022EBBB75F2461697473207F56147C9759ABA2283240676DED072CBF5F41737368696A6564CE12D0DDCA0C914F5FCFD9F66F9C4055506978656C42EE6665A801A5402038689F46B45EC0DBD0B0B6706C146F772D9CBD734BEA23636F7079082ECFB6B704E43E6461D4B4567FFFD6B63C1E6D62185FD03335663766343332023639363358D0BEFD346636653064266338653764223E07150B3E284B24245651FFFFFFC342ED39616532356137306533613664653939640176FEFF6662363663326630366133306239657F4C410117145F1D54406CC1574E6B48616E64A84058AD204070F4555F5406537CB4868A3DDB4E6F1C797E4058745A47DB54B86C436F187546650A7920B1AF0DAEDA74CA40452D872014C5BE1F3F30353458F082322A313963634235333D37B8C2BE104C02393732224663313E8D682B699845DFA1E1B7ADBC33E23962B63734373363621231E499D99B3A2064313839D82C0CDE58A715A9ADCFEE735F321E4FA1A2651FBFDC15A3D63AC6670E79AF9F8B0C8B42103662600E66611009DAFF3130376334323838373820628C32D8A8282E923832309F982196BA1684656D6D5F15B7144CF132306635E2328ACDA2A634DA3260316165662A36A6A2F6383539351A355434F1DFF035B0A1446E3C9A610408C565F3A73FDFDAC30476B9924D1E636852657335C044017401C1606FB435C50B7F3476D11450146B6167DBEC15C15D1C4136413281585AA774D3574BAF476469207573420556D3666517A1FF5074E0116F66026552C72A5815FDAD1F04707D55666364365C5E241AC00C7AB2D2376632337634898AC837CA02313436372A45D33A1F9F395C0EC7FADCE2FEE473B582AD1A36A86134DC39EC3436161E15936834351C9F5F47D4F59202F95F5105061460DFFF48408054DF050F3630AF3AD20E64BD022C28583F9F8B0404AB3FCF8882477C6F736240484F1F0D860A47C6E6335C503070B017B433FA36063831623508584A8A6056403414321E58910A06AC2D3455AB0A1FDF6642042A51B865DBBF2E567D22373133658C6262DE30C070230A7835A0396335C2861059818ABE62063CBEB08E89BA5F34743402143CEEEA70374A66333482F664B85AB34A9439140237D8655FBAAEEB2350504C5745850470D88F35643864F8662AAA500C3E7661BA42303897C85521AA3C34B4A085EB7A6F55832A504463FFAE043B6C7933408FDFB8B0802344D19BC3022EC95365728BB081A245BF52A2CEE1BBB1369E5F6F626A405DB362C0064'
	$sHexData &= '7E38CAFA98E11509FAD008A41545FD97858340C1FBBAC8A1087B71F5222E42BFF696F185A402A3FE6033812CD5F7B5537565DDFB1464548B47F31E2056AC07FEAC7A2A235C3BFDFC028A255BFA16AC42ABF459AB0AA00BFDFC2AA13ABED5A102468DF4FA00D2A1E86856F556A114105BF8A4AAD1AC7C5C31353C15F436ADC7D5B4083515492434D6910E88662C8E9B23332055445AC644A620C4AB441A442E4FE6138BC751D9AAE723702E435E815E00144583F5F4508ED2B401D486F6CA872AA54D7AA43DF5103060DABFFBD47AA6011CF1F8F4587123FAA08750102105F5FF8745322743537627266310B446D2A38378A3466CA3234D029EBFA37366635328E3022FFA8261C42CA51550D5853A5BF0D5855A9A5BFA27021151F57A48202AB3F346C72353A3038CE66336A63B80CFA0A1C39623465642A4E56013474C2627C663F5581212AD9327F9AE1D429DB43D975AD55AB2D6F4B05C3A8EA7C2F3158C5015BCF427E6DA0AA14C54271FFB14A10C50AFF80285615CDFFA8B1EA56DF2795EAC082FFC0A0A50A717F2688524D319F4926EC849D057275A15F65B52AD6AAC25B9F945A75ACED3F2AF98445FF69AAEB3830CF457FA3AD26E053914F120DAB026FAF10ACD2C57F73C1C2584DE1B0511A40773A8155459FE50CA81BAB5F1A12C10D319FB0AA11AB852BD3A0BA3F9D80C55270838F502826B6C75F260615D76ADE73FD7F0348156999550A3080DFD3CF402A4A609F5609ACE841E500B9AA047F69C0563024917FA06074681BBA679AB50E3CF8616D1F177409A17F55820B8C53FB952110344A03FF03146C1507107700F5343C284E164FF3799EEB38F016117030CFD37C9A116CF061709600E6D37C9A62A04B12085012D96C369FF5A864101336138868BE775FB320143A06A03D5E0EFD06A83DF39466F32E155615B816E39ED23ECFC0F0121646CC0E39693ECFF316E84062003E70E7799EE79218A0B930CDE7799EC0CB48D0051750B9E7693E20175578600F36DF7BEE06A8770EB706D05E00192B193CCD5669D81A167E1AE090D36CDDF3E7EC471B162C1BFC3CEF3ECF305C043FA6168C0C6C3ECFF390D614201CB31CF33CCFD31CC0E82CF0D26C3EED3D1D7634401D8D1D440D2ACDA61DD51D541E06EDF33CEF06641680F574001FEE603CCF539A1F8416DF94E0DC7B4AFB112076A80E5806B047693ECFF31688B8C01E21C0F83C4FF35021C1CCD03B229F7B4F291EDC0E8306ECA70E2323D97C4F695EF80E901604401024F33C4FB351240C90C618DE7B9ACFD0232530A00EC3063C794AB3F95E30266F264416E6F3699FE74CF03C28765C40286C369F66B52AA8C02A032B0841CDE779EF0EEA1614F0332C409FE7693E902CDE4CE0012D79DE3B0F6E410E56165C'
	$sHexData &= '60A57D9EE7BB64C0112E7670699FD23E0E192F5E7C0E07301690F79E7BEF100EB706A05F0EEF06B0EFF39ED23E0E0A3146B80E2D16C0CFF33CCF509BC8A0BAD43EA5D9747731E231DC0E12323CF79ED2D6E40E4206EC771672CF3DCFF3F490ADFC770EE09E4DF07E060442050FE0EE0C4233E7799E77161430481C9EE7799E60862490B340D97CB7E977386A394E8EA0390B3A79EE3DA5780E5306882F16F8EF1D1CE794002606D01650693EF73C92E84716243CF079DE7DEF400E70060043D616FB207C9E66F3103DCE3D58D0423E3DCDE6D3B0503E0E3FB8303CCFBBEF0E53061044A616CB18D0E769BEFB2F408E1630406728794F699F7023412E300E8716686C3ECDE7B00C42748042D54329CDE6D380E0438A45D89EF7CEF60E1D467648450E631660B0349FE779E168F01B47887C9EA7F920479890A04F48F77DDFD3C8500E10490646050F881634DF7D9E40A04F4A8E16504AFFDE8188F3B0707806F8EF9DEDF316800E4D7630470E6616C8EACEF33CC0E0F80F207B0B07D8BF8E0EBE169E77B6CF08204FEE614F1670CDEFDDE77930E02D50EE16300E66E7799E7B06884716B7A8C04AB3F9BCF646C800516D51E83C4FF37916A72849B0C950E67367FB2052A6A2522F160A53CFF3349FB01053A0E8A0C99DE7693E184AD0F5209EE7BD33E026062816203830E779EE7940591F16B0E1E6D37C9E58F01B56607056A7D97C9ECED810572E57E0CDE7799E304CE850DF5800A6D23C9B4BE058595059CEF63DCDE45B88F00E0F5C8ED44CDE7D9EF70E2F16DC308F5D4E1690CF7B67FB0E045F46704D0EF416D0309AEF6CB660A67B60104E160C61183ECFD37C4061BA20C0CE63B3E03B0BF6244F0ED7641ED84F0A529FCD64BB66500527E779DEB70F591698595F9FE7799EAC6094BCA01A689EA7F934C8306861F8909A4FF379E61852F07669483CCFD37C8069A190B0F1D36CAAF398C05E366AB8AE539AE7406A6AD82F6BA67B67C1E7170E066CF660530E2B16CFF33CCF90308698907ACFD37C9A6DC8806DD6F8E016DFD93E366EEE28540E6B6FC7E7B9F716760E9106402F16E6A8D37C9E48F0A770509DB65BB50F0F6E7116B8DE331DD80FC272EE540EEE06DCDF53DAE7770E6874BEE40E8E1618557CCFF33490DC20E02E7A7529CDE6D3288075A67840BEFB9EF60E427916B0500E387CD616407CBB4FF3699F3856B03B7D5E1614759EE6707DBD50BAD376EBFF0F217E16680F2F7C9ACFF3167C60177F8C207FF33CCFD385E090B4F0AF5BA7A8270F5C161CA2CEF33C5CB3304AD36E9D0F0E46814C4A51E77916B360CFE7795EB70FEB1678EBF9E6D37C9E90F90283A410834EF3799E66B4709486D0286A8DA25F6E8DA2D697CF0FE779DDDD4787D6160F5E16845E9DE'
	$sHexData &= '7799E759475AEA451D41A4557EB4EDBAD8F0F528816D80F6A16CFF33CCFEC6AC3FCD079F3BC77B6898E0C590EEC1620F069369FE6CD8C28D08C419188DE188BEFC00E3492162E0EF3DE31A8F3168018DF06A8FB1EEFF316E053958E5B1E0ED59916DFE17D4FC0E00E0C9D5E5C3E0E2DA6DF7DEF6C8E005D0EA506D85EBE1614A79EA7F934E020A782EC90F33EA57DBCAB46F40E25AC7660CDE6D3BE0E59AE1608C0AE57B3A84FF3693E60B3954861A0095DDF7B9AB854400EF70638625600EE7DEF9EB9BC8C16C00E11BD8E63EED36C95F70ECF1628BE2E42C1586C3ECDE680C135C3E840C3A3C4F7B4EFF0643E0E9BC516F0A00E9FF62DDE59C6BE65EE0E13C7164020C7CDE6F3349E4C60C8CAD268DF59F53E10D3CEE2F6B8660EE9E5A7D9AE711E3EE616E2E690B3F9349FF024E8A030E8D7E9DFE07D4FE0E00EB1EA5E697E0E95ED7D9ACD77EE16A0EDF9EF5410F0349B4FB346FAF0D830F1AAF2ECC6B3E1F9B0F2F40E086AF57BF7BDEB76F8C616B00ECFFF8E16D00E7D83DDD059B2486BF60E8402799ACDA716500003640398706C369FF625332EA0303351333072CFF33CEF168D3890A7403ECFF33CB0D048E02E369BCF7BEEA6470EF216A810376339D648E934B077496995940775A7ED564F0F0C3A16600F32E7799EE71674327B847B4EF3799EB39CB36B3CAC693ECFEB0F8516C8907E3DD8DBAD91D2BF0F2A3E067C9EF735A8050F33161C40E8403CCDE6D32C00418C414C903CCDA7F95142646042A27C6C3EEDF3C0794476888044E444F39DADD2D045EED3478EF0474AFBCE668A4910750E8B4B1660B6EF3C7C0E654D26750E304F2E18766D77DA770E705116400F35531668E673EF3D400E8606904716D855DD9A289DA49F0FBA799EE77916DCBAD7F0D7349BCDE7E500770057D25914ED5644E99F0F5D5C9FE775A716880F99169C99AE5DCFBDEE34AC0FD806C077167707EF7B9A62D0800E016736786667BBEF6C362E6860790EDA70BE166C3ECDE6E070FA719810726C725B03A5D3A88F0F75AF3BAFDD16B80FEF06CC7773DD7B4FB3164A75DC500EE406EC777666B3D96C16F776207A007767779FE7799E3070B740C047783CCD5669465079165C7958A0693ECFF3E560F0357A78F33C4FF3407A739080E875A7BDCFA8107B567C16B00FAE3ECD66F316007BE07D167E20207EF39EE7695628607D2E30B3F93CCF80E838107F527F9FE7794A4016C548D01580539A4D77C68F80538078164AFB3CCFC890F007828E98D96CDD7B0E5E06E88F8316FB83087C349F66B3E08479851080859E549ACFF31CA025862486DD92CED3FC307FCFF3BC6E0F781640788754BDA7F93CB0078964100E83CDA77DEE0674D70E578A5EB0408BC74AB3559A8BBC8C2E348DC4A7'
	$sHexData &= 'F9DC7B0E9906CCEF168C8ED4F9349BCD508F7A8F107D806D909FE7BDA718700EC71628E03691BC779E1576307D9206501690F33CCFF3B058B0C760D37C9ACFD00093681093EDF4693ECF80F06394982095A7D974EF6E06D077955596D8D97C9ACD60962497E0C097EA979FD23EA5F00ED098BEF80E2799F9B4EF6C46087E0EF19A1610609C693E4FB3AB9C58F0EA9D64EF29CDF6709E5EA19EE80EE306F4F79EE67347164C9FFC500E9B06FB562CE9047F05DF0F30167B9EEBCE1C0F3E1F1690ED46F3693ECF40F04DA15050A1A7F994668DA1601617A270D37C9ACDB0A213A57820A53BF3799EE6108040C61820A6D37C9E6676A6488031A968AF5BA3A4970F7916503ECFF33C797F649026AA3C4FF3697430AA66A8709BCDA7F95DABC860AB03AC08823ECFD33CAC9114E036AD3E4FF3693080ADD65010AE3CCFD36C46AE70508C90F93CCFF390B3B0C01CAFB72E49A7B8EF0FF95E775EBB16CC0FC906E08E30B0E87B4AB369B0F00EE60610839EE7BDB33E70B1063016A0CA489A4FF379F01FB25020B252AD4BD279685FCFEB4EDB0F11B3167C0F2C16943066F3693E72B4A4D0B43FB6DDAA249DC0B70F0EF3BCEEB4B716E80F4516FC45E7799ACF4B10844B54246DB72A49A70F12B81640F33CAF3B0F1D16541D24F3349BCF6410B941B97850EF0D3ECFA28000BAD6068816303CCFF33C9290A0E798F6B977F820BB0606A4EF0E5ABCA64F69369FACC0BC1FBDBC0E8B3ECDE77916C4B07EBECC90BE699FE769ECDCF024C0D6E4F9CE66F340C09CC0588516D4C1749ACDA760E0C130C2D0E7756B924F0F5F16E449D2799E5F83F8EB4EDBAD3F0F0CC316100F141682F33CCF2420F53440DFD9BA779E064817C5EEE2C716F0C766F3693653C89860C869C9DD8A249DA48F0FEB3E77BBBBCADE160F03CB965F0E17CCA7F99ED2D6EC0ECC160887D0E7693ECD26CD3030CDEF385EB70E49A70FC61690DDE75E770FE406A4470E48D0EEEE7BF7F11620D11ED3AE16500E12D44ED97467FB1610D5EECBD5D7D557D6B9F8DEE0881E0EC40658882ED73CCFF3DE06781690CB84D0E769BEFB04D8EE1610D8A29CDEA27B9EB0E4AC8FD9B606B8EB5621E9169F0F3A16FBDCEBCEC80F4006DCD70E57DB767BDD7B4AEC0EEB06FCD7DC2EDD8ECDA77D6730890E4CDE163860DEA49FE6F33C40B005DF4890DFCDE6F334F86010E03CE068CDA7F93CC028E17840E1B029EDF33C80D03EE32EA0BC679AF00E1EE4FE8A0E8B16686C3ECFF390D48800E555E57B9ACFD390C028E6A8400EEBDEF9DE6C06B07610E706C02FE816E7799E665EE8C870CCD05EB70249970F6516E0DEE75E770F6B06F4EF0E04EA068B3695F68DCE0E27EB1640ECC5EC3ECDE76948D022ED5040ED37A4D36C43EE58A7B'
	$sHexData &= 'A15485A170FEB779ACFF31688EB43F0A00F9DE7795E4A16B04A50CC1BD2BA2157BE4DD8AD8F0F1BF3468C050F47E93CCFF3162847733CCFEBD60D770FE51654E5F7EEF33CEB6820F4BE0678166DB76E48370F4BF51690F33CAF3B0F5B16A45B62F3693ECFB4800DF6C810F669369F668EF7DC90F704F8FC3CCD66F370F995F9388DA0F2E9DEE2F34010FA3E064816D590560D27975E77DA6E0F5BFC16740FB3168CE6F95E770FBA069C8EBAFCFC403AFF94B81664000200C8A4D34C0B0EDC16EC3CAF5B35370F7616FC76349FE6F382108E90C10320904EB3F9F0044C0568F3BC6ECDB70FEA1678EAD36C3ECFF68C000631069C433ACDE610079707A8DD69BB35AF0F350816B80F3B549EE77916CC60E2DC0969DF79161E840A8F0E220C1658423A4FF3300C66D0CFF3BA75E70FB516F0B5BB4EF3693E0490D0510D14BC6E9D90870FC516506C3ECFF3C5CB64100E460EE0F3DCD374500F1690400FD609E9DEA606981667EE75A7ED0F3A1016A80F4606BC8F13D269B611164411CC799ED7AD270F9516F8959BF93C4FF30C91E0F51CC012799A4FB308132410138E506C9F66F35014B214800015767315E9349FD288161D1694CFEB5609970F8C16A88C25A4F33C96C07FB63BAF5B0FF416D80F0417EE3ECDF794F00E40160092806E18AD12D2690C57CFEB4EDB0F3C1916280F57164060CDA6F23CBF501A991A5890CEF33CC0FD6477DA6E951F0F651C167C0F9EE7795E6C16906C72A4804A48E779AAB41FAF3B6DB70F121D16CC0F3016E0E673AF3B0F7806F077164D1EEFECF894FC0E8E1FAE0C930E9E7367FBB420168040215E88212F0EEFBEF7EE5C225E16600EA9061094EE162FCFD37C9A231C4023EF2CF04FF3693E8924349024BB607B4AFB3CC031255E680E7F169FE73DCF7080DC2E78E01E26F8BCA734800E9A16883027CFF3BC774E06901670879C6008E9349B28A328A4EBCEEB565F0F7A16B40F80063ECFF3DCC8A716A8D8C04D2A9E66F369E0202C632CF4F0BEA7147C332D4EFC0EB01604959B4FF369D03E2F28402F1E309FA7F934A06030D7E8A031EFECF85666060896AE70320610CDA7D97C16D033123418B034F3E9DEA93C2035062816CFEB5605D70F851638853DCFF33C8B4C90B85C3BCF82CFA70E5D377E649638064F6936DF78BE3039A5398016F3B9F7FA3C88103ACE0690D7E7799EE71671988092A09AAD7B9EA0EBA8773B16E73BB076AB8274C70F423DCFF3BAD316C80F9616DC969C9DEDF33CECC0033EA60097F3349FF60E0E3F1608103F38109EE7DEEA2041F606184716E3209EA7D97C00422542283061799EE7793070823890349B4FF32943404044524448EF29EDF3B0214576500E6F16583CDDF33CE0F260EF464653799ED26816E37047'
	$sHexData &= '796FD0BD06787749C60680168069369FE7F588004A434A90CF736F514BA606985F165DA005E9F33C608CB897CFF3BAC1770FAB16C8ABC5D605E93CE03FF375A7ED0F2F4D16F80F48161098E6F33C4F50B820E0D24EF3693695344E3A4F78804FD36C3E4FB4A000503750ACB65B15A4470F925116799ED79DC40FE616D8E6EC7C9ACDE7E8F0535E54FCD0549ACDB3D93E5508995507561476AB82741F0F6257BAF3BAD3162C0FB616400FBCF0BD57F706505F586E0664168059AB82746F06066C1637F7BAD3760F3A5A167C0F460690EFEF3C2B3E0EFC5B2EA0995F06B4413ACF738F1692BC2A4DBB55270E8E60CC60767C9E7716E0E00C6266F09915A4DF796306049A050FF93CEF5B0FFA1614FA0664A1D2BEA728900EBC655E38662AEDF3DE4E064C16F045672E6067EEA2D26CD5677068266906F379DEF92E8069168CE0556ACF7B8F4F9C406B1606A416D025DF3BCFAA6C7EB89A6C06C85E006E9A4F6936366ED016276FD8B3F9DE530EE706E85E2070D370EF6CB64AF871EE5371509B169F29CDF73C60B02E5C7268F3349FF60E207316C04073A2F0FBCE82CFE0167496309C0E137516E7799A4F382075469080E7693ECD337698407699F066F3699FA0067776F81077FB78CFD36CCF009D79169779D0D047CFD37C9A7AE4507AA5F8B0CF7BF73E3D7B5E9EA60E7B160880799EE73DB42E14C0F420693ECD567C161D7D2C207D7FF3699FE744A0A47F8E4CB07F69EFAC671C809FB686811618369566F390818F827082DA83CF66F369D8E083DF8438A08459F06936E486A09087362D889FE7BDB360A10EBD1678C0408AF3BCF73490700EA416A0B02A0D9DE6FB8CAC1FF3BABBDD0FC88E66160FCF165CBDFB3CCFCFD578108FFE06888C86DEE71640F790A6A287EFFBB01B0F279356A3050F2E161CAB3CAF3B0F342E386095163ECF7B4A480E8816D09047971B5C863E66A39F0FF3BCEEEE9A5E160F3F16643FA7F93CCF458050B49B9032749ACDD09B2C9CA4BAD376ABDF0F9B9E16BC0FA23EF7BAF316DC0FA806FC770E219F7CDAB3D95E0CA5C09FA01630B0A03CCDA7D912A14820A158500C9DE6F3D08BA35CEEB4DD9A8F0FF1A516F00F6F3506BEF70610A6267E0620762B327416CF0F48A8CFF3BAD316680F55167C555C3ECFF33C8C5CABA050A99ACFD36C7DA9B080C6ABBC4FB3D97C60AD8DAD40A7E01CCFD37C9AAF4C20AF3F6C8066F3693ECEB07410B1CBB1DD3A0C9D949F0F29CFBDEEB4B316AC0F2F06C84716ECEE1B7D9AB4D840B74E0638A8A61586CEF316AE446FEB566168A70F8916CFF33CCF8489BE98BEEB5661E83CA817DD6E15864F0F29BAF6CFD37CDD160F5E1600A95E8C104DA5F93CC01ABB20BBF0BD87E13C2830DE06340CADC1D016BFEEB4DD1'
	$sHexData &= 'AF70F88BD16700F3ACFF3BCAD168CADDF9C83A135185F97D79DB65B0F9BBF16DC0FBD16F7D4D79DF80FEF0608AAEE769FA7F9B4C11618C0C1EE6060C2C0D0693686C36CAFBBDBAD6F0FD8C5BE160FDE16E0BB15183A070F2DC7CFF3BE0F0EAB050F34161C343AD64DE83C38EFE775A7ED0FD0C816580FD616746DB76E42970F1ECA1694F33CAF3B0F2516AC252B6EDD84CEC4770F7B5F77DAAECB16E40FB40604ACA6CC16E7799E6635CC1490B81C6DB76E423F0F47CD162CF33CAF3B0F481644484FA1F33CCF5460CF6C9DB65B35E70F52CE169CBAD79DD70F5316B00F5A06C077CEBA77BE7706D4BE20CF06F816F3BA5513970FCC160CCFF33CCFCCCD20CDD430BA55133A9F0FF57C9ACFF3164CF517D16050D1F33CCFD3B270C0E878AF5B35A1670F9716883CCFF33C9798A0989F5B35A1F3B03F0F9ED79DB662D316D40F6316E8636A42E7796AF81FAF3B6DB70F3DD5161C0F43163CBA55133A0F0FC5E83CCFF31654C5E768CFEBD64CFF0FA51680A59ACFF33CC794D05DD7A4DDBB10718EF006AC77DACFF3BC77BE06B416A0D7BCE0CDE6D33E3FDB76C840DB57DBD07B4AF3291615DCD80EDA064F6936DFE07670DDD5DDEC0E704AB3A9B4DE2EF4DED2DEFCBC77167C0E42DFAE04AF0EDD160C6C9FE6F3E042E01420E14637E1E7799ED21C16AF24B0DE3B7C9EFE2C40E2E6065016A09ACDE779EE5890E3B5E3789EA7D97C10E422E49830F3539AAD7BA05FE5BE15E6B40EBAE779DE6216BC70F8C45FE7DDEBEE3D2E06D8160F8D06E877E79AA7D23CE8F4E8E8FC5CEBE0530E0AE9AEB07602D26C9ECD2E18B0EA82EA20B3F9349F162AEB28B0EB24ECE7799A4F3C60EC72448094F654DA1AED464CEDEE766073F4B9F70EA206682F0E61EF56B0F39ED2BE0E0EF08E840ED51694F33CCDE620F132F19C40FD566936DFA476A0F215F3B8F416EF0D3ECD75F5C050F6D606D4A6109EA7349BF740F7E81672F86CCFF679803DF84600B1F91685F93ECDE6D314D0FAE2FA1C40FCBD73F1ADAE0624B18EFD062C26749EE716709834BAD3766B8F0F6301165C0F82B6EE3DF70678470EEE0688A70216C1027CCDE7699CF07103A88EC0059ACDA7D9F305B480061C07BC5BA5D97C6007E107CC0876AB083DCD773608B21642091080A7793EEF0EF316C4100A0BD466B33DDB400CBEEC0DB3D6700EA50FF8CEFBCE78B40E691376B50EEC16A7D9963A1EB66E163A17F036DF7D9E70EF94B7D62E6A19A0B7F9CEE679191950B816251B9BEFBEA75C500E9D1E762EC01E332074DA773648B90EBC211658E775EB16AF0F9F168066F3799E9FC0941023CA23F769369FA420245425D870262636DBA7B4278EEC0E10281600BA60293CCFD36C90290CB0DE18EBD62DE8170FBD16A0F33CCF30'
	$sHexData &= 'BDCE4C3CAF5BB5EF0F8D16688DF33CCFF39E84A0DE94CFF3DEE0502C5E069C1690BEA8BA550B3ABF0FE3E83CCFF316C0E3F5E40BEA562D870F033ECFFB5E26BB050F151624304E303C4FF3693470309E80C0EEDDA7F990318C8032E606C016DA6ECD82770F373316D0E7795E770F3816E8383F0BFA799EF850BF10BC05DD69BF35170F423416440F43799EE7791658434A6850BA779FE7BF7C40352606A016F3BA150BC70FEC16B4CFF33CCFECEDC8EDF4D8BA150B3ACF0FA5DDFBBAF316F40FC70608BD4637FE6EC582EE0618168F0F3CCFF3BCE71628E7E840E8C582CEF3EF5067CFF3BC6E0F82167482838882CEF33C838A98F3BC6EC56F0F3516B435150B3ACF57C85F9ACFF3BA0FE516E0E5073AF43EED3B7C203DFE0604BE1680233E3C4FF3690C603E901CA03CCDA7F9153F28303FBD50EF29EDF3F0654076600ED316885BA5793E4041419842BEFD424AB3F934A800439743B89D82EE9D4406C816975C77DA6E0F2C4616E40F3206CFF3BC53805E168110A0CD3ECFF33C18D0F1387047CDE6D36C91474010494D4948F9DCF33C506F544716244AF33CCDA75C304A62A880CFF33CCFBDB4C0DFC0E0F99ED23E944BEEC80ED21610C0693ECDA7F0544C1C804CDAD3BDD3E748604D8E067016609ACD7736BEE14F16C0507151B066EBDE7BB00EF806E04752162D52F3692ACD08C15053203053A7F93C4F7E78805D54A0CFF33CCD6054AEF8B0F7203C4FB3BDC28E551666554870A6E73DCFF378B0E69846F0D26C3ECD2756B830568656D8E63B9BA7565608C316F057F0BDFB94280E2658D616300E615969B6B7F0E6C4D616175AE8F83C4FF3205A57F470655BE779EF2C6600C50EB71610E0E7693ECD4B5C1C505CF3243CCF2D04A8D607163066F33CCFF33470A650D059F029EDD35E8E680EAB5F6608C69ACD77DF0EB3604616C060BD61E866B3D97C0063856338C71064CEF33CCD9A6440A0F5987DDE3B09488E06A416902766F3BDD5B32E00C869C6061416906AE7799E66B16A1CD0EB2477A834DB506B5EB56B2C6C4E063ECFF3BC3C1640D444E0F46DAD19D0697037F4EB4EDB0F066F16EC0F1D060CC905E77D2B06FF0FE31628CDE7799EE3EE4CF0E1765C369FF6290E4B782E7C5078E579F7B44F69B80E4A7C16F0900E4FF369BEB81630CAD0237D3830DAF7349B7D117E44500E1C7F1690BDA7D97C207F6A80D0A00EF3D3F7CEF60648CBEE008106541620823EF6DDE7BD06A016C0D4835E161084BE4EFB16CF728ACCEE0EC08B16586936DFED0F3A8DBE16408D0F90C87C9A4FF35090E908CDF062913ECDE6D318B0914B922850929ACDE769C23C00939B934C9B4AF379A0129460945A959EA7F934709095BDA8D015A0D37C0096B497AF3BAF5B0F4916C80F4F0'
	$sHexData &= '6DC7B54DE73EF0EE05EEC975E064FF379DEF816508004CE809F5605E83C106FE775A7ED0F499816280F5F16445EB72A403F0FE71664B7F85C770FFF371600993E0680CEF3BC9016304F9C77DA6E55170F3C9A16B40F6B02745E5616D0DFF9BAD3760F3F9B16EC0F501610CFEF3DCDA7500E9C20100E2F0650FB3CCF732F16B458C00D9D463CCF7B4A600E72168080CD7C9ACFF388F0549EA8609E7BA7CFD3C2B0709F8E06B81677E8DEE930A05E06C08FA1860636DFF3BCC81690E6D4A640A296A2AAB44F69EC0E46A38EF4A4A5D9DE37E6060CD076A516ACA514E7799A4DA67EA61CC0F0E769369F2400A735A73080A7D9549EDE38A8F6A860F4799ACD50AAC3AAE0D01EABCFF3DE598608D10E951630A013F3BCA7B4AC2E400E6E1668B0CF7BE7E223AD2ED10EEE16A4F04FF3693E57AED860AEB7E07B67FB3CC025AF5E00D20E8716B3F33CCF0890F728A8EE67B3756765B017B17641B138D266AB349BB342B458B616A2B6CDA77D9E88E045B7A69060B8813EED539AB8A00E06B9BEA850B9DD7DF76CDAB9D35E0E95BA8E16B4DD0A009F0F67BB16AC00E8BCEE0F7116CC75A7ED566F0F36BC16E80F40BE1500FA0608D4053F0FE97B9ACFF3162CE914BD44200E4AB3F9DEEC06542E10BE1DC0643CCDA77D0E6CC1167C80C1C9B0F89EE6F3D085C2BC900E52C3E6BBEF2CC600D50E15C4F61620C44FF3799E69887025C59430C1E7799AC5BAD8C075C64EFDD66CE3D6051F0F31C79FE775A716640F5C167C6015C89466F3692E8C40C85FCA9CC5364EFB0E8FCB16B4775F77DA6E0F2CCC16FC0F431618D7CDA7F934A00CCD2810CD74694F749ACF38EE5ED02EC83C9566F330D085D2D8D2D3EF69DFD968D80EADD51678C00E019EF7CE82D6DE08D90E50161070461BE779A01C3FE7795EB70FE91630E9EF75F70E9F4410D7660654160F709FE779EE06608F16C96CD07BD87C9A4D77EE17D9E7D9A880DA83F79C5B2607D70EE306BC1EEF549ACD30DB63DBD4DC06EC3C9FF67916C01EDD46F8F0DDDE7CDA77362620DA0E13DF164830DFF33CCFD3477090A77877FA3CCFB0F18040E08E067C9EE7B9A07716B7A8E016E16F85361A27050F0F795E77DA0AE216C00F1016D810E7799EE77CE880CEF079EF6C9FD04AE38E00DB0EDB1620B2716FF400E4CE064816BAD376EB9F0F2AE516580F30F33CCFF31670309C80A0D36C3ECFE38810E646E698B65B978D8F0F3AE716799ED79DA80F4016C040ACF7799EE7D0B0F3D820E8B65B978D7B06E816670FE7799AAFDA1604DCDAE01CB2719ACD60E9BBE92CBAD376EB3F0F1AEA16480F20E33CCFF31660A0FB70CFEBD665170F5A168C5ACDE6F33C60A4F0EE11EFB4BA75D9380F0F69F33CCFF316C4696FD870D36C3ECFE2E800F065'
	$sHexData &= 'F0F0DA77B6CFD003F1EE00DD0E72F31620CDA7D97C80F3C7F5B0D0F59C6BB2719AF6CC3F69B7261B770F6EF75E77DEF746DE050FB7161C0FE62E2C9B4FF379F04DF83C80F8E2FA7BDAA7344C0EABFB16D8B00E30BCB3E312FE1E18DF0EB2B266F3BDA74616C00EF31638E00001D36C3ECD62035870038805E88D6F40DF900E45066E0515D858812F67E77577BF0F13078E160F3B164C9EE7799E3B725C80DD6C762BB0712F0F6C083DCFEBEEDE160F7A16A490B4F9349BCF07460009060ABC200AD37C4AB34B0AC816910BD00B8EFADEB00EFC06DCE17E66110DF9BC773650E20E90165CA00E349B4FB3DB0E68400F6210709B4FB3F970108D118490117E124EB3F9349830145114ACBC6EDD343F0F9916BCF33CCFF3999FD0B0CBE6D33ECFE0E07815D6E8C0159AEF29CD5816F40E8B1600E3A0CDE6D37C38170880171818149EE7693E30184B2060F82ACDE6F32E289019B219341A799EA7D9166A1A3CC0CA44693ECDE7D0501B4C701BA1E67B9EE758B0BA60EE101C73EF29CD1A1C680E8A0670BF0E4AB3F9DEF706788E001D641D80CFF3DC7B0E7E06885F169990A0F33CF73CAE98BF16C9A0EDF33CCFD0DEA8F00B1EEEB0F73CEF290E2B16B830C82EA7D27C9EC0E0021FCC1F3ECF539A1FD416FEE000203DCFD36C1B20E820B8F0E6A93CCFD72EF1FC21213ECFF3CE04E416EB10F00B229F7BEF6918100EA806202F1612239FA7F9342CA023CA344024799EF7466E063C1680A644D97C9EE7B0F14C00252625E7799EA7C03062C890B3D97CDABF2676D0C026492730E678DFD3BE0EDF281668E00E692946E7B33DDB374E0EFF2AA608E82B16892BF7349F6670E9F01F2DA8200EB6B104B8A906861E163F2F9E4FF36948402FC9B0EC303CCFD36C6130E87091F0FB3CCFF3A0D4F8E01E31A63CCF7B6704ED0E541610609E7936CFFB1CED5E313128ED31D23C95E63234323240F3549AA732324C32329ED27C4A58461E33640E85F9B4CFF316709068345E78B034D37C4AB3D534E816B835F0F0D4B3E800363E2536EED6CFD37CF71E376616503775D8804FF3693E5838E0A038C55036DF7D9AEFD0A8393616B0391C3A4976EF69C8200EF806C0DDE7BD1B5686067016E0B83C8E69DFBDEF16C00E983D8EF1A60E783E16C09EA77DF7503F560630F21670B238369FE779D0EE4000401740799EE7694820735090E7799EE7ADC8C0E0D0F39ED2760F2241A6D80E9216E0EFD13DCFB0D6E8A742AE06F07C9EE779165076F8800F43F3BC77760600F30E9F1660A0DDF79EE62F44C0300EBF0620F4EE799A4FF3164F4580504571E0E7799EE780A1E8B0D1DDE7799EF0E0FFF84046B6E7799EF60600F516708E08A09FE7799EB710D0ED180047BC775E77E607F5764B06281660F73'
	$sHexData &= 'CCFF37E308097388F3DCFF33C16BD40C0E048E779EFD08F4F9E0650162040CF73EFB958A70E5D0660A71681683CCFF33C90A770B0D0F33CCFF378D0EE80F0F3349FE607508810502D90791A3CCF305098675151A9344FA5A05151A8513CCFF3DE06B046A0BDB8C0DDBBCAF3E0C0526E06C847523C4F6936BE52D016D7D88706CFF3E0FDE0C7534E3DF79E7B06E8470EE006F0470EFED3BED3E106F80F540600F61620E0F33CCF3D08406010F6F779EF1C1656062016F45B57363ECFD37C165C57C638C80058E7D9F16918E45A1E265BF6F63ECF7B0E7116A87CD95C4EF72EDE7B9ACD585D8A5ED4940EBC16F8DB9DE779BCECB40F4C5F36F93CAFBB160FB316ACC41460F33CCDA7CC24609BC49CDED97CCFD828BE1061246116B4EE2AEF79ED682EF0628E16F33CCFEB0F3916A43C64C4CFF33CCF6479CC7CDC9075A7F93CDC0C63B40F20E7799EE716BC2069786C3CAF3BCD4464880FDD1640E0E775A7F90465700F2F16809EE7799E307F38B8CF30DF7BF779EC1766F616180EBC1608F87C9EF734CCE72EF8F00B6775F7DED3000C0EA406E42E0FF4CDA7EDCE1F2E0F0D69162010699E9EE6F33C64A0D36AACF8F369BEFB0E356BD616606B9424F9D37C9A4F94656C04686C7BF7349FE6FCF87C176DEC180E9A4FF3DD266EDE16286E950CF9989ACDA77D096F8E181C6F66703CF379DE530EA2162CB00271F3DC7B4F34180E50064C4716A7F3693ECF54C80772685072CFF33C4F925C94D670D869BBF33CF87C0F1873A684369F66537393748CA874C574369B4F699C1633750CFA34759ACDE769E0000C76277614799EE779306C1C6CA8799ACDE72880789D7844A0A5F9BCE7FB3C2EFC7B794CBEF3F53D0EA20638FA0E7B062049FA3CCFD316406648E8037C799EF7BD9E4C050F1E16B01E69D97C9EE7C09CB9684D1C7D7C9E66B3377DF04E3752004FF33CCFD352B210D8F54F7BB6CFD01C7ED6397E50165C829FE7693E78519AF180907FE0D36C36B67FA855DC0280E7795EF6C656050F16307CA2480D3ECD8059E0068196EED37CEFE60E4B16105B5006828E3CCDA7F91628824E705C668CF33CCFF378A8CEF8F8799ACDE62F83B05EA783C2B81B7D9EE7C2DDC804842606CFF33CEDE85F16718CF09CB7DAB3D93E98608E8086A9866616D0CD66F379F9186805872E8720A7D96C3E10882B88386B40B3D97C9E66904C897D89107267FB3C4FADDE183E8A766F8A59A7D97C165F8B8E8B280D0EBE4F565F06C878DE8EBE417C9EF606D87E16B8D54081F3349BEDDE163E8F5085709E9DF73ECFC8E006908E87469037789FE71678FC2291468F360E9DE769BE6E167893A0CEE81D8C7712E0BE0658D6F7BBCDE7169DB89B0893E606C09D050F675B42DF5D06009F665E0D949E'
	$sHexData &= 'E67B83A14E0E811620A290C1B3D95C7CC0A38E941195D0A59B4FF3BD0E611630A7C01D96B0B24FF3693638967098B388C03EEF213C682E16E008B54FB3D96C2097519760B65DC59FE6F33C70D11E988840989FA7F9349D80B7A0BD48B8BC3758001E2E06E816E8DF73E0F9319AC32E0EA106D8C4FB06864EEE7E06D0D016EFF53E4FBCE118D3EE9F3606B8F3EEF3B4D716609458D8BE16D469369BCFF838A05EA0A0DD5EE9799EE784A8A8CEC8F3BCAF13560FF406D0DE5EA1A19EF79D6798DFA106A0DF5EA1A18EBEF36C28E0A10630E0CEA2CFF3BC7706D8164E74E0809FA7F93CA040E2A0C5B0E4F104E834E8AE00799ED7A9260F60161060B8CE7B9FE720E824A47EE746A4F33CCFF316B060B8C0E877DE79EF24A5BEE946A516500FCFE6795DB81FE946A5A6E0EAA69BE7D93CA6F0EAA6A600EB9D67F33CA6A780ECA7C6799EE7169060B8A0F3B4EF98CE3506B8F216D8F3076E67C2A0CE0F0BAA66D69EA7F93A0F22165CF8223E9C799EE7793E74D4748F693E4FF3F0F990E82843F07B67E9F01AAB9E860EAB16F8F83CCF78B0DAF8614EACAA4FFB0C0606E86416C048ADAE9574369F8060ADD7AD9679E7D9BE0E57AE2E6076AE168837805FF300AF77069079051B1516404559200944548A8DAB0A1AB4409824AC1646015710C14215285C53C15412BE026C654F626A2E2801FBB844E54578571C4502E722AD4D75CF58144CA01AC547D3D612B64C28744588444425D8CFB63A46690A5E436C6F5AF0FEDF1E99184C6F61644C696272617279576B210A7F94D24164647212B6DF4EC01E5462616C4D656D88795396F0B345827573E24B4D6FC20B5EB674896E4C00766543720D06AD5354635C534836D8518B822A1B53C46F09AF151648486479C167B04AC454C8417327130A46123E31438F81D9CD21D549583AC05D14B405DB145175E479500666146D0929AC2450C5352B38786F34723670DE3857DDA0BDE0EC73DC6275676738508A9EC1DAC0C025ADA47846B4B376EC4D9C35544C6DCA261C0B045B654311255314161EDC556E68DB6449A4D8C120740133C360A7283C56693206C186673646776923E26F6B56C0BAA704145545CA8982C19FAC2F43617031603B2836AB4C08124576C1D980E30E5711DC6E8AB8D80EDE74474913DD141F59AA1FA34FD76E86ED82F66D7050246857D34EEEBA2B7F3B473846756C6C4E616D23534D64D93AA15D06065F765BA486677ADF444C3A1E4F099ABE23856D43C139419C5370A6A9A6C52CDA4C45B34328CCB79FCD1C02E0A65F7763F06F75693634D12E4FFB156C383EF86CFE6B1BB3F30249169A1B44EFCE9E4F6310A76DA82C3CBA6C9CB4621128682463660F2ACF1356528238721E6466B0F2346F2C73717274A1505F69C'
	$sHexData &= '1DDEE608E446D140A726E6F9713B4CD9978260F525F6104713CF06D2C1CB32774C53D574E7021B00CB61A5FBA2153C283A25F8A626B726C3B86DDEE682F6657F1020AA33D81692D10B885E97014607B2CF6B05B8B7A0C9EB07B26B8102C1C9077026A0D7660B6690E6E6D771254675DC13666563D0A6776DD5F45CEA1C3D1E068A1C3E86C56A03C0D2AC3C84A67D03350388777AF0ECD5F9D83060ACE661670F562B3D362947680656B77666CE47067CD0C5CF5924CDF5F76EF420E766C3123667075B166FBFAB28F772665311F6337F3826E0ADF856642682445868F9FE340A8043B74C600C1AA091404985477271AF041B0B27764C6FC0004C800D0EC74744FF0500C690AF64DE19AE32E9D5AA6236DD94B4443D8ECF436D1130051572BF3795F586F9A426CDC0E60A8162081859369B00588CB1F7C3F48655498125B366874271A2E64A730C03D772B1CF02FBBA309B21F5955D1164B5FC77774419D15441E775F52981D6C071C498997754607C3F6AFD06D484249544D41506144EA12E05560C7F6536D6C0853E0E516FAF22B1178FD14E649546F0B6917684021B94656742C735B60E5D1E7FBC15A9AC76F614F660BC54E65052B3808CD4CC98B4E0437480B49434D114772F00087C0386E0EAF8BEC74C1B553243377C134B1B1695B57BC6282A59804F53353164650243430CB1F140C0627BAC9783E1D06CF2E2798A13FEE405359023472D26F62730A2C3CD04A76A0696610EE07594158585A6F577888ADEC5F0ED859485045604E78508AB9CEDBF0EC4D065B3132388BB8675720763052616B4936CB0F6440CE031E14EBAD3C814D3013A4B951B21605ED28B48BC387050307BC653DFC1D90A8B9446583039AFBA233717DE2502C143D815F4E2E2A2E9131C1BB580AF19148B58901C2C242B988141CC0E1419909C4264B47709BCC10A3B65F714F6D6C33B95451646B7D29988605744298C22618D06B372CA6F0AD582DA93F02DCA788306FA2A853C1BDAB751D19BC1B40C1058329FA72A0C2C3155639C874DB30E8C0A7CB5F4D6272CC636F4391EB69B15074722347586B9F13B64097AB085F730C756991378A536F70AD6C4209CDD819095F700A5F660B67B07871754575ECF2244B90261051D97E5EAB48D84176D5DC76C073381E1D3F315F96F229790B664F51C930309D1662A2480D455B1880B9D3B5BDA64121F882FBEB2BA667BA5036CF583108DBBCD1806C317B88679BBA6F33D30863800D8F4355566924A6E0F1BC65582D98F0427E61751A39145B2A77EB863D0D1281895807DC640A1BB1311B21FB615B373F954440476ACA8B4C5C5F6F665F3FF34438DEB98955C92C861916E943DF8D4061375946684C617F26845D3722AA1AC25F5748480A563154B57475'
	$sHexData &= 'D387624C949025EC2A8389C10A7D388F155A05DBF779FFD11189606FCC885716D64C63CDFDBBDBD0A053B069FE5F4ACC08597EDAC3AC693C30716376FE574455160C2C8CCA952A563C14E9325630956C41137228E4F5BADF0045038330BF31E2CB28C5001F546F4254A59A9AD98FC94D74785FE07286793D4D008543DB1C7A0877B6541960061445631268B421FEBF2731DAAAC625095751AD605B1545174F5C8AEB2A75093B91AEEA094215596359AEED406FA12B5968DB4B844A02FE1F852F1805F34C4970667840C32A11B71D70A6A66E5C80D9735474465D28460B03894782568D1C69026E81E38E234792E3A17705258893A22C578DF758209CF0793040C141CA720D42094634B4AE4FA590A8C16570D8298836AA611EAB818AA1C85D248578659B41216214FEB914C10E4C322F4D6861387049A970D8C12A6661815928428036026F871B2AD5E7988930E7048D41A8764158810E25C45F82150A483030311304175751B54089092E568115A24EDD6FB300AB42784F734A1956B1E5DB85C100CDA17D4160318DF0D891726651C10B0E160448897264DA0043A0A6CD65031AB52059B46C3F758B6A14476E55674C413B65963BA236C450673A8780E0AAE470651182AA07066734C7250738C4CD5867D53001065B65259A12CD58F46E7E8B809C900141696EA040A103617666A700E452313C4A70D2902A197026505A951C00500D8A02ABF7AF7205570E7DD3558BAD606F6DD7794751C1482F7355A81D802148858AA2419F73686F774879E7026CC5B94D5758FC44822616836F78998A1A4FF21D4D413506194178B1279C42324DA448C1150E68935059311ACE20026845417B970948695C6581D16E382A6557DF55449B46B9E75088A3D86F7536F184714B4D300E12AD5567E919221D327F40B745ED88502A85A392A3DA488349AA86A3924A4B9551C9546D4A854BA38842D14DC955D2381E81773440DB33C506A9F9C24142ACAB5D8D45667D48BEF502ED4E3D3BF473AB7DAED5B713676F6F6439DF50E35B87B435D90110627B6E63400BB58B660B539E4BBACB06245E72902EEDDFD58D7F25348D756E73686966990B6CF146FB3433B805EDE7EE4431260F976F758FA4BB4C81649110AB33162C6807696EA93909B559C00E89A7475A22E10D107761797310E304C5B66A7640BB1D3F42F6AE63834E77894B379A61E4B016196D8690105EDA48701ABC83F847688376D74F64E44B97306A6FBB444B93475D8A586DA0456A43BA7532A33276FA4CE302AE90117C69676E8F6661A8CB3F134070C058700362F2EB6A1794FB4ABD448157007C93E70034C25230BBD8C0A5B2A5140C9789D2C3D316C1EE251C86C8735758405C28B0CAD853CC086E52D42CAC14D18E504EC26EC16'
	$sHexData &= '0F501FAFEBDB553314DFC6B746F7057C86F770BC58029606D8465B2BFCC1D41F331EE456E756D19420259C87137B8852DD49B8373C25B08ED4D1072387374DB1A465A38796929430B611BDBCC6C64A7371A2BC18E6D97AB567A9642964A78B98D3186C2C14E58735082793000D74154A4464BEF0D4FE178EE846D6370790FAD380A05D47650F47878BE1F888372B64D7233275FD60097095CB408CA682D46053C5C2B62F712A9ED0005318042712F0E2A10EEB03314861EBF545180413A85CF0A61080CCE6630064F1534C6C63159BDEF623880E36CEC0001B1FF87FCF42CA9081008281808F0A002F02001082B9207EDCD18F0000F0801100801BB60AB8998B5880528484D67FFFF1A1EF0F03A5A8812F1C82D202830286050B040A070757BFB9B68A030705070583806A04068381E70B050DB0CB85DCCE050601C704828DA3AE0A8386EDF1A71608060583826E040C838304A40D0807BED3503DE423044E0284870806E084000605050046201F48FEC0600670614690549180BBF4422200B020E10CACC2312102E9D6A9EF90312E180011715766CEB34A10FED9B6CB64EE00622600169812CB5B10D1F15850DACB0B5A4830D6CDD2CC1C08E9004C5C2E61D1B01D02E03201106525B525401967CEEC914280F3E000146ECD0065501F2C0D006ADCE849FDF94D060F704454D3630F22C57CEF560E5B51681F79E8101A7CFA4BDE73940B5F7D27540042E6D0BEEEA4DC82C21C0C96FD2EC244E87D477C0790F76D875C7704E501B18FBE44AB7D49B9FCFFB700F7C1627C04E069AB530C92707D56B65846F2717874616D0A04F17D5F8F7BD93734237007FF60F33F806004992244900000050FF48894C240848895424104C8944241880FA010F859B02000053565755488D350D04FEFF488DBE00F0FAFF488D8764580600FF30C7004A049BFC505731DB31C94883CDFFE85000000001DB7402F3C38B1E4883EEFC11DB8A16F3C3488D042F83F9058A1076214883FDFC771B83E9048B104883C00483E9048917488D7F0473EF83C1048A10741048FFC0881783E9018A10488D7F0175F0F3C3FC415BEB0848FFC6881748FFC78A1601DB750A8B1E4883EEFC11DB8A1672E68D4101EB07FFC841FFD311C041FFD311C001DB750A8B1E4883EEFC11DB8A1673E483E8037219C1E0080FB6D209D048FFC683F0FF7458D1F84863E87238EB0E01DB75088B1E4883EEFC11DB7228FFC101DB75088B1E4883EEFC11DB721841FFD311C901DB75088B1E4883EEFC11DB73ED83C102EB0541FFD311C94881FD00FBFFFF83D102E81AFFFFFFE960FFFFFF5E5F5889074889F7564889F748C7C600A00400B2095357488D4C37FD5E565BEB2F4839CE7332565EAC3C80720A3C8F7706807EFE0F74062C'
	$sHexData &= 'E83C0177E44839CE731656AD28D075DF5F0FC829F801D8AB4839CE7303ACEBDF5B5E4883EC28488DBE00D006008B0709C0744F8B5F04488D8C30942407004801F34883C708FF15B818000048958A0748FFC708C074D74889F94889FAFFC8F2AE4889E9FF15A21800004809C074094889034883C308EBD64883C4285D5F5E5B31C0C34883C4284883C704488D5EFC31C08A0748FFC709C074233CEF77114801C3488B03480FC84801F0488903EBE0240FC1E010668B074883C702EBE1488B2D50180000488DBE00F0FFFFBB00100000504989E141B8040000004889DA4889F94883EC20FFD5488D872F02000080207F8060287F4C8D4C24204D8B014889DA4889F9FFD54883C428C6053C000000FC488D8E00F0FFFF6A015A4D31C050E829000000585D5F5E5B488D4424806A004839C475F94883EC804C8B442418488B542410488B4C2408E9614CFDFFC356488D35309BFDFF48AD4885C07414515241504883EC28FFD04883C42841585A59EBE55EC3000000E81E078001000000AC200780010000006468068001000000B0200780010000000000000000005000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000971E0780010000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001040068001000000000000000000000000000000000000002'
	$sHexData &= '8B904800100000030B90480010000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020010000000200000801800000060000080000000000000000021B003A9000001000100000038000080000000000000000021B003A9000001000904000050000000A4300700580300000000000000000000000000000000000021B003A9000001000200000078000080000000000000000021B003A900000100090400009000000000340700910000000000000000000000A0C00600580334000000560053005F00560045005200530049004F004E005F0049004E0046004F0000000000BD04EFFE000001000B00E90701000B0005000300000000003F000000000000000400040002000000000000000000000000000000B8020000010053007400720069006E006700460069006C00650049006E0066006F0000009402000001003000340030003900300034004200300000005E001B000100460069006C0065004400650073006300720069007000740069006F006E00000000005B007800360034005D00200049006D00610067006500200053006500610072006300680020004C0069006200720061007200790000000000460013000100500072006F0064007500630074004E0061006D0065000000000049006D0061006700650053006500610072006300680044004C004C002000780036003400000000004E001700010049006E007400650072006E0061006C004E0061006D006500000049006D0061006700650053006500610072006300680044004C004C005F007800360034002E0064006C006C00000000005600170001004F0072006900670069006E0061006C00460069006C0065006E0061006D006500000049006D0061006700650053006500610072006300680044004C004C005F007800360034002E0064006C006C000000000034000A00010043006F006D00700061006E0079004E0061006D00650000000000540052004F004E0047002E00500052004F000000340008000100500072006F006400750063007400560065007200730069006F006E00000033002E0035002E0030002E00300000003A000D000100460069006C006500560065007200730069006F006E0000000000'
	$sHexData &= '32003000320035002E00310031002E00310031002E003100000000008800320001004C006500670061006C0043006F0070007900720069006700680074000000A9002000440061006F002000560061006E002000540072006F006E00670020002D002000540052004F004E0047002E00500052004F002E00200041006C006C0020007200690067006800740073002000720065007300650072007600650064002E000000440000000100560061007200460069006C00650049006E0066006F00000000002400040000005400720061006E0073006C006100740069006F006E00000000000904B004F8C306003C3F786D6C2076657273696F6E3D27312E302720656E636F64696E673D275554462D3827207374616E64616C6F6E653D27796573273F3E0D0A3C617373656D626C7920786D6C6E733D2775726E3A736368656D61732D6D6963726F736F66742D636F6D3A61736D2E763127206D616E696665737456657273696F6E3D27312E30273E0D0A3C2F617373656D626C793E0D0A000000000000000000000000000000B0360700C0350700000000000000000000000000D2360700D0350700000000000000000000000000F7360700E035070000000000000000000000000016370700F03507000000000000000000000000003537070000360700000000000000000000000000573707001036070000000000000000000000000077370700203607000000000000000000000000009837070030360700000000000000000000000000A237070040360700000000000000000000000000AE37070050360700000000000000000000000000BB37070070360700000000000000000000000000C837070080360700000000000000000000000000D437070090360700000000000000000000000000DF370700A03607000000000000000000000000000000000000000000F0370700000000000000000000000000F8370700000000000000000000000000043807000000000000000000000000000A3807000000000000000000000000001038070000000000000000000000000018380700000000000000000000000000203807000000000000000000000000002A380700000000000000000000000000323807000000000000000000000000004C380700000000003C380700000000005A3807000000000000000000000000006A38070000000000000000000000000074380700000000000000000000000000863807000000000000000000000000008E3807000000000000000000000000006170692D6D732D77696E2D6372742D636F6E766572742D6C312D312D302E646C6C006170692D6D732D77696E2D6372742D66696C6573797374656D2D6C312D312D302E646C6C006'
	$sHexData &= '170692D6D732D77696E2D6372742D686561702D6C312D312D302E646C6C006170692D6D732D77696E2D6372742D6D6174682D6C312D312D302E646C6C006170692D6D732D77696E2D6372742D72756E74696D652D6C312D312D302E646C6C006170692D6D732D77696E2D6372742D737464696F2D6C312D312D302E646C6C006170692D6D732D77696E2D6372742D737472696E672D6C312D312D302E646C6C0047444933322E646C6C00676469706C75732E646C6C004B45524E454C33322E444C4C004D535643503134302E646C6C0053484C574150492E646C6C005553455233322E646C6C00564352554E54494D453134302E646C6C000000776373746F6C00005F6C6F636B5F66696C6500006672656500007371727400005F6572726E6F000066726561640000007763736E636D70000000426974426C7400004764697046726565000047657450726F634164647265737300004C6F61644C6962726172794100005669727475616C50726F7465637400005F4D6272746F776300005061746846696C654578697374735700000047657444430000006D656D637079000000000000FFFFFFFF000000002E390700010000000B0000000B000000C0380700EC3807001839070040530100E0590100E05D010040680100704D0100F0470100904B010090490100904F0100905301007051010045390700543907006839070074390700803907008C39070098390700A7390700B2390700C2390700CF39070000000100020003000400050006000700080009000A00496D616765536561726368444C4C5F7836342E646C6C00436170747572655F53637265656E00436170747572655F53637265656E5F5361766500436C6561725F4361636865004765745F446C6C496E666F00496D616765536561726368004D6F7573655F436C69636B004D6F7573655F436C69636B57696E004D6F7573655F4D6F7665005365617263685F496E5F496D61676500684269746D61705F4C6F616400684269746D61705F5365617263680000000010070010000000C0AEC8AED0AED8AE0020070010000000B0A018A130A138A1'

	Return $sHexData
EndFunc   ;==>__ImgSearch_GetEmbeddedDLL_x64

; #FUNCTION# ====================================================================================================================
; Name ..........: __ImgSearch_GetEmbeddedDLL_x86()
; Description ...: Returns hex string of embedded x86 DLL
; Syntax ........: __ImgSearch_GetEmbeddedDLL_x86()
; Return values .: Hex string of DLL binary (empty = not embedded)
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: PLACEHOLDER - Add hex string here to enable embedded DLL
; ===============================================================================================================================
Func __ImgSearch_GetEmbeddedDLL_x86()
	; This function holds the hex data for ImageSearchDLL_MD_x86.dll
	; File size: 103 KB
	; Architecture: x86
	Local $sHexData = '0x4D5A90000300000004000000FFFF0000B800000000000000400000000000000000000000000000000000000000000000000000000000000000000000000100000E1FBA0E00B409CD21B8014CCD21546869732070726F6772616D2063616E6E6F742062652072756E20696E20444F53206D6F64652E0D0D0A24000000000000002314AA6B6775C4386775C4386775C438351DC0396D75C438351DC7396275C4386E0D40386675C438351DC1397F75C438351DC5396375C4386E0D57387E75C4386775C5387474C438C91CCD396675C438C91CC4396675C438C91C3B386675C438677553386675C438C91CC6396675C438526963686775C4380000000000000000504500004C010300500614690000000000000000E00002210B010E10009001000010000000C004003059060000D00400006006000000001000100000000200000500010000000000050001000000000000700600000400000000000002004001000010000010000000001000001000000000000010000000246806004801000094640600900300000060060094040000000000000000000000000000000000006C6906001C000000000000000000000000000000000000000000000000000000645B0600180000008C5C0600A000000000000000000000000000000000000000000000000000000000000000000000000000000000000000555058300000000000C00400001000000000000000040000000000008C57CE7500000000800000E055505831000000000090010000D00400008E010000040000000000004C17D37500000000400000E02E727372630000000010000000600600000A000000920100000000004CA7D4E300000000400000C0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000332E35300055505'
	$sHexData &= '8210D09080A08E79C4B150F53BBAE3706002689010000CC05004605000577E5FFFF6A08E805042F69A3000591C06800049070C700C740040DD8FFEE5CA12D220A4C337983C408C3CC01BEEE663BB936927C01648C7B904B59EBB6DFD7476A026842CCFF153AA18045A091C1922E720C6BB01F9723F95CD49110D4D41E325B20DF9C91301CE441425E91A09140DEFDFD91558BEC6AFF34593A64A1E35083EC08F79FFBFFEA700C33C5508D45F464A329C991FCC745FC1B5ADB0E32D714C61E016A38002EEC90CFB90F062CC7050B431330F2B937E534F20317CCA32F3B38EE538E1D3C1340A803B9419FF276D86A10A1803F78022FECA13589AFC167ED45F08D0450422E21DCB150E5FC6139C84407480813048B4D480CEF168E890DB9598BE55D819019967C2A92009F4C907C18F29280809467C40EC5EE525155A354338BC2BF84F66EFFF30F5AC00F540544BB20F214C31FD0FEDD3EFE5151281104248F8CD95DFC1A10BFC5C0C0066D563F8B450885C074B6FFBFF913660F1F44663911740C83C10283E80175F333C0428BC1FF7D3608A35F56578BF966162BFA0FB70CB7F6FBB7170632663BCE750E83C26DEC5F6E5E681BC083107CB4F7E0FE5F4012CC7F03C050B072C4EE3CF045C0403FC63071B443B8FF007FBF51FFFFFF7F1A7D0833C9BEC59D1C8185FF74110FB604114133C669F0930100013BCF7249D1ADF8EF5F8BC65E335E020CF17FF48ACEFC8B55080C568BF18955F48D4E04C30D55DF3AF801510F57460658A78C5026ED41F161D6016F4CC664088E33084CEFC1CD5E2E2C2C9CC2845F07FB295D630160410489046AD9DF658EC244DFB83E8D460450ABECCBEC7B46006683C020B7B15E9F816996D98D769337489785FDEF17FF4904B83CD485C90F45C1C3BFBF5D6CD9B8B76BBAF6C201740B6A0C5654BDB51EA38EC5013FDAA83A7945E0563BBC56C38AECECABA11088D9A7D1262FD89F46009DC7164CDF5199706F7F2033C157041FFF750825186B2B184908C99F5320AF9240A0C4605B201305BF683B56C854307C3F805D037E3C7C68065641106F157CD71BFF001B7871E3926B0B66750187DFA06D81B725D5ED0EE71CC3A0BD1400E13FC85CB43D848D4D08B93200061C98FE7F717F8D51018A014184C075F92BCA88165C8B033F3A59FB950CEC003FC68A02880125ED108A025F301F2A3101069463C32A6FC238808BC1C741C31FC32DCBB5603F3F2B276BF335E08B00740A0B048901AB6A59DA56EB5F2C39780E4DD8ADA600DF5E4735B45355C18B013675028B6B07A185717F7301F66DE485515D782D83022384D7FF05F88B50FC2BC25EFC83F81F77038911C3FF25C8C75EB4DAC87FBFA458296AB40F04BF102134C35F108941080A1429180CD60C'
	$sHexData &= '7C357E102D200D0B9E010C08EDCF2A230CC20A9E0FB6550806456C19E4FD0CC1E2080BD0101014760969B00962AF5F019DC87E7F7FC1C1E082CA0BC10838160542C7F2110C9F380643C3E0B6C0EAFF07A68155381CFD6009BC0F775E3FFF7670194062A82990E157BE1DA804750E565F391A72050C5A5C01436C798454BD140F117D7F085DE19F2594BE33C9894DF8888DEADB6F850C027004A9648B18894604890EF7B688D04FFC7101FF3157E0FB0BC16C9F986A07FF3629482733B7FCAD46045E0B3F024486955C24545F5665FF5D4A36058B4004EB02328018049CE7768914D2507338081418DE3D0414740DDFAFE46258D3FF04FF7142C3240DF201C37F7680020C121AF82F0C51F37C8B504EFF2C03087B61D1C50B1C271312560872C367C6AC64A48948B850085ED6D00DC3B7C31BC0D9032B52015FE47510130C1BE0E60C70E17CE10820888C3C0C0C5FC0EC4D2670F88B2CFB022113B07F20B846C8C0714CBFACE22A532A67C37F4851E95A560A0CC13B05176B8F5B3F97FF7C6AD006E4081351B1B4441B35B87413C6ED4E04E5B74B6D5BBD9F86A15085C5E81DFE680A20260C36B31BBBE629B578ABC6B0CA0BB5C934B50CBFA4855C7B0364C851AD3C164DED20639F57268BF9A315FC892B8BF085F6743B81441D425B64BC480657C32D5F41314074CE575F6B17193DAA3FFF30433D5040F4CE24080D9F9B881ECC1475A95C6BED66B74C100C5F08BEB5683232C930040497A8F014FFA468C3DF2B035608C12860BFDF01A16B555F7F891BABFF7FDE837A1410C46BB8F172028B12820F51F1C6B921DCA27AA2746317BA8F49BAC49BB43D4A6DBFDFF45AA840B60A740B3BB241B151DD78A1015FD56051A03F34A6AEADE0200B624EE85B302804EDB95CC3FFDF416A1B124FC56A13CFDD85E10811BDFD0E558A7FBE608B0E85C97419F84D8C277F7E76F00FB1163BC16717FD94783075ED32A8C3B00106C180746BE6F0FF871F0805EDEBAABE83CFFF52C786C18275B3BFFDFB158B06FF10147E084F7509168BCE5F5EFF60040865A6F7761F83C8FF3C8675058B0132C38220578506A01FF0F00E1C5AA27C117C50A8ED329C8EEEBEC86A1812CA706F157B9F60C43A7105BE063B710C730CBC8B04B0C422BB37FE15908079140074183F303B703C330295720B8B40B55F1138611789988515FE0D88BFE43B48040F94B71E5817061F9DAAC4B649ED01DFC1B7ADE18BFD7F24FF31E6DA766F002B10FF52089CCBBF82F670AB1E5872704080C3FE85109C86013B027503B06AB9D0AEA02AC3BF55BA109CE0C067A1BB3F018D55F8084430281E6E5248E63AEC3B3ADC548B56042B4A460F8B003B06B262B30F3CC46DB21130E05B865F41603B42026BDB2DE88A3B9675075'
	$sHexData &= 'C59E9EEB6581EFF3E93680802C4B013412F445D82FA1AA32C1DF8D385BAD0068798893EA2C7E02BE804A4595EE3538BDC17FDB6FA5483E4F8A4F66B04896C240405475391B59323534220CE11F967D187EE897DEC043B2E4B207FD559FF458B53248BC22BC16E96F483F80272218342F6F6F6FA108D730441020F430C03F189439A2A76EBBFFDC6460200EB11C6608D4B98756E68ABD5F002848E9C960C86D4FF737E231D197ECDA01E837DE8FFDB668BD64DE48A148B43CA73202BC6894DEC51523B35EDB7FDC87725837B24C2040EB68D4310CE43F0A7343B9BC98BB6CF040610C8B13D38BB51D6CD55E836722EA8D442E0150BDE5481FA00108C72164CFC83C22348337C9084817681C80F6E1FC065D10F10BAC74710E7C760AFC26910148807F30F7EF85B5C950D7632135FB58BE34C3200C35BC3DF5068D260180EA3ECF2E56857D00ADCE804DCF8080A34E095B65D69F2D0837814E670101AD472BC827F5DB2003683FE10731554002A0F58EB3FF8BF0F4B45C0EB6A8BFE29F1E0FF026E0F3BF80F47F88D4F0181F9F3278E1DFA5F442383CAFF3BC10F46C250AF8471D3F6EB0F8419088D4836E1E0A6FCEB132F553874CC0DEF1092546A58F0C98D460124C050B8E0F30DA28523324AF2D489113B5AC175D01EDC3CE051050E4587084AC77645ACB002BB7E0283FF529E8D767A45C0349BA1E345BC4DC0BCC74ECD829E18DCD7A4524566AD690E4DA4B875F0C688181D0BBEE28B7DB4C2D02BC25751D077223A3A1EDBD30E26C58D3410C73DC91D67973EDCC7DC573DB841B341C8A4848A8C0A20C2E747E82245D0459CBEAA10615B32A010167EC8C716E28415050AC883BE3A5170914FD6E40EC0361179179EC1866616E86155A0562017042D8CFB2C369CA42A894E2187D016934E0C2251D4ECAAC21947654EFF17302A3914DFAC620DB247881CC55B706A7488F0DC90164DD818D2B058865C1A19BB6AEC3B2E56834AD83A01E90CC5F035DF6870D826CE504E166C5881DCD078EC67D82247B736E7B738C10888DDAA183F39B83C6B1FC079BC040398F84781161874FF57D6E564D00EF0FD6CD08BCAFCC746410C1457EB05EF3F8D7901C63E0F1F400059CF9C8007C351523C65D81818046E3F73A68B0A29397808DF83038903FBF33038E19E25B8439F8985C0494A20248D47ADC42952E60708E169BBBAD12640ED468C470C0A10165C5C9158C72C1C5F1315624BD59F937F1920F87F481481E1FFF3FFFF81C9B4EC5C8676841CA03FEF20AEE47284F9088342EAD06B04235F7481DABF7DA3AC837E148EF84A366A0AE1BB003E6607FD3964BF009EFEC23B75F8750B22A8C13C833F0E5D668222A0232440790E99060D1F3453F7FFF71B7AD98BF2895DCC04578D7DFA85'
	$sHexData &= 'F6792FF7DEB8CD569BF9FFFF83EF02F7E6C1EA038D049203C02BF083C6306689374275E043ED36F883C7FEB82D1C2007EB205933FFF69EE8C0C74319431407694A45FA3BF8740F8BC8EA51C1450ED1F951E4CB12E3DC2928101C28C386665B690D0613045F575A5802B4A7DA0AF9895310F1374D7123BF521FA47AB7C0B937FEC914A08AB8663BC175044CA8816FB4A20653FF22E073BBF455080F95270C90EF968A01525045F81251B666B91F450006C387DF0A02FE3DFC8526CB1C8BD88B10FC198C535753FC03FEC0BC8844AC8BF35B60CA9A3B5651EFEB08376EF88BDAD68C54FC41F659B3DB43FC3B532238F0843D0310D409FCED45F4139C78045F89305E5B5F4FA00AAF307E0AC33E1B04CA48FFD83374DC16F2CEA436520C3F904965768452418808AF10724B7F94E780D98360A0C85F6A024780805962488F9F9D6C1C740BC2ED7D9CB6C86C490B29A13F90B6622B467FFF3F8225338C97143FAF18588E989F47B026131C2494430A09102212EB1F40429AD9FF306B8808A209DB62435FB810F09987825237C65F84F946F225DEC208009D08298A0D2B5F1FA24A8B535FBFDB2085FA8B04957EE0889C0591B1DDD5B6981D1FB81D86105F7F08B61DA01D1F83FA057713FF0FBDEC82240800226C370B7CE0E4E4BD90265C06626862A05502817F5ACC1F7D0E2C64879FE800740EBA0ABBB90803740902750648BE890683455B45DF1F7FCDC0DD4B0D23283604A20F7672F2DE1F001E1C061F221FD4506D100AC31FF8514F859F578B3AA4B1313B6A30D4554A7507B80AA606053B1266735FA2AB60065E8AF28BF9166F9A86958583F8A4308524A08B16FDE70004DCAA920F3BC275185FFC6046E191E42F74E889065CEC7D29276690686F0787835847A47F05E9D1E9A8C7C605DD00AD689F472F2D46BF1D251C334CB4F6C084C0F815520FE3E4F6BEF7FC4E0707120774E59A8BFF8AA27DF54A7B39581FE423258CB587DB12B3F91BD715C7B09393F7256206707E70DFB8E66B219A701832B8112970874A7F89152DDF033734BDA11D5FA32B5F1442B6D8A18B3FC9FA4E53629FD0A41F8728D4B4A81FBFE465AAE3DF5F3526D88EC33F261D5D85C05F66696FCC618EE36637789F8402E56207BC9F15EB2C143F3F87011FF47B6BE1550C638B378BC6D6113BC6EC0E8DD51E5F1C42890732E2901301F0137F47D0594EC086C1A0FE83086AE0811E2F15008B59A160C3B01176A01F8379607B10C840151F5C0397A2E4B6E8BEC59B8434D3D328B01F21D98A583F47F88A3534110A56CD4858A0AFD6897537FF7610F4FFD08874E4582201A0F039A44BEBD21310F09247DCC25F482031E08205B8E34BF820D8BFB5894908222417C0B2601036C41B919F4BA0D4AD7505A4953'
	$sHexData &= '0167BFC0851913E537C8A002A6CACD810103C0CEC311E443E44C842707F93B104A6BED45F5A1A3E4C8CD6D200563AFC839B6406F44F06219835EAC8467608508932E55C4BA5670807F3E1F060B1C980F0012E20D291D30FBF482B69B1424D00C00D0A880CD701D7B68663FFB210EDCA2CA5087F6F400DEC608B0C88D893AC3B81F7E1735FC07E416819B42E5DAA833D1BE4672371FF752B7C9000939C007B38367993A00067132CB8498A805887437F8224477448885F20E902A23390F3DF7E798C0DED1345E828E8010F1026006E917134B60ACF2E6D9ADFE4E050F2C5C02470C8EC24743283027006D1226AEF3025CD79664FE262D2E168C6DFE96BD452062158CA428BCCCB03F1539A053C10FC866F500CBF3730C94124D7B09FB848351A2BDFA03FF0F719304B620440295683CE7433F0338071044E8211FF527011B0186736068B01D6760D331EA59FB14693737F935FDFA402F71A04528408DCEB632B518D460C5CA776A1B3FD1F64501A0803993AD50898E0346A02F9808764DE8A74F5B868BB039F6677A0ED5685F7B2139864AAF83C05D95EFFE0AF0025F0515335750A172CC0CCD88D5F8AD633C04DC01FA06E13887D8B078BCF5AB93BDE0A06539B0B3BC60F6E83FE3A3495FE0275618D773456791D8248895B145C0616D37D476401C7071B089F903D8D470CA39018C877503B94B0E08190F3F7477675077C69E0480F7D5FDD26246018BE25DFAC122B646C9FC2175B442347833900231118054CC33F08F10183068261543CB00323945889163D53E07FA5643F00750D89378977045F058B80C1D6B64740700421FF371E040B3033D2E01C399415C0BB81163930740E4EC1FCDBDD1722F15E5F6185D2757E0FEB03894A0483780B41C1D6751057040850B749114B5A23DF025D4823CC1F8A013F71C031E4490843F10B2AF18506C08D4FD68D7CF0FF14AB449B00688B844C0B01FDC5CBE1BEAC858552F7B4AD0EEC85E474956A902F7798C10A5C887669C8634DEC89B45F70E439C7417E3CA405894E3CEB0658401D2FC44BEC4E401375F09DA2FB8E5F807D0B00690F84A54C9D20CFA53957CE0A7AC9218F2E34A30A5B81E4802897021D358C920376049C012BB058119B665FB11832C84940143276A1C09A31142A8D382A2556136EE7007C1DC761B0238B52FB483C279BEE38C0F05FCC903939288BD11CC27B094775F3EB34961FD9773CB4D85DE089433C8FC842A4E3F73479068A895040CE5199AA8F179327570D2BB96C38EB6E45E7019E62921769E7AE2333F6B9FEA743E15B6374079AF8037707FF24B55169A7D82A3428AD3BF05E7E478508FF539202870883F903746F8480282A61848358E891C127B80745EC01E2690C807F64A6B92D106B1E5693513545'
	$sHexData &= '0269F04274E27D037BB05811169B8E380A05765A0A07BF8A35113AA4B2BFFF0B5B8DC27F3FEEA240D8A7E840044FBF617562F2497041853345638310474119C7503C984289C39B1854E1BEC9D10E70F00F4427DFA12948042F8BBF7B0B058B01E5DF1ECDD842F204BAB81B1F3AD0083949989208CEC2E021DDCE8B0632B42A8C8215C8D99F15D201B7D34404C084C9B1FFC09D1C31A16810283783820EAE77BA027D07C7AAAF5751AD9856D7757744220870753F1A427E6D46D80E7F0CF1E4825F76635E2853895DE8613DB8409A0ED76F35CE2D263B761B8E694B35A86982E07CE55369D763059213C3BF4A100FF2880BBB6C288B7D0C94E61A61C6C658430C5C09E0E8365A07EE2A1E19B6C236AA36367E5CFC9397D610604E6445FC2183CBFF8BC3618053412A4785612AF0052E5F084B5C17102A353C72EB8F4C2187AA1F4A38834A8A1E151AFF48752B4CF076E23DB48D8B4960561E35803934609FEE168B45C0C28B02A19AF0E4E4F629DC4304074409C35F683004712C5FC35A54C8517F98A1E122E09FC3BF036EE190F82CD7D32B01D18BFAAED034897DE85C2A7AB80D03023BBC2EE874C4293C203FAC7BC37DE82A3DFBCFD008C2E09DB990220401023452700BADF2D80ACF48C83E20926E050F84935548270D943370EEBBAF37F00F71183646158B092787A7EA894DD018D40685D0344D2BCF3F2006EB0FB0E8E84D2920862C07C8292909D712B2369BAD24ACEE0F85191E87A706DBD5A42207B8E9783B3724840C4891CE04025CCC4AC9E09F4B60C3EA985DF9C1002998C7213FAE3711E30658AE1A0D0368716103BEF12A9C905542049F8B0206C0672372420442080937E4A90ABF04B7E4134EAD50AD5F1B27CC444D0C7988DF4339400EB6E80074130C6EB3A1C33F08AC02689B310FC121D20CA9F646FF6826E2BF418B4E0C2BC883E1FC19121F06E8068883C1238F238BC2510E76E8421F0D4A46F52DBCCCAB465EC37FD67090AA1F89FF300C081CCF33F964F6017A420CE3425142D3898765422F5F4B0822AC904830C30D83F2364624D67724CC44344F2A0856F63812C756B7BBBF78E2A29B803F4EA4FB442E1AA47B8831017462113BCEC12E62915C0FB658521023516294786A2845A113A44A201F1FA0E43D4D21314C2EEC000053558A3FC0B1554B515FD7C148941C0BBFE00874002B97493851C8219F4C004C370D3061547F05DAE2F92581CC665DF87DD6FB263675A247C7DB394AF0640744572C538B22FCCAA1D7C5BC3AECD3C883512B1F4C793A62826943ECD8C08D01D79DE7261533348C5FF87F257D0BE44CA077FC2B3668C1E75F47ADEA6A5D3FF002D30F2D99625F959F215693F1093B08DB1F1C40461E4CD0516A0048D750342E28EDF4571B3AB'
	$sHexData &= '8BE054D2C4BCFC72C1586A9008543115011211D37A2083BC85713911C027CC228005F4CFB013990620D4ABFBA2260AE7B185D0C8D56067EB85BE3895E0189028915C466B2844A04A081CCE4268C2865DF4D74AA03292406BA0DFF147D5F73F4CC0DD01010488B46182BCF49B8EDC1C1F8DA14855593128B797C0F082ACF0859468BCF52510B2E838C101418B184266905ABBF2AAD0E3C5D9F5F854BBCC141088D5001223C007A2BF9CA46045F081F02E0E784AC06BB3618360C8D42524D3D941EDC68BF582D04C540A2AD133FBF5A85981C4D9B074FB4622DFFC6010156410BDE8506538932C1085DE95E7FECA9C25585CCBF10CD07A941686E009FFDC8054B04F796B72583BC419F4D7B1C1881966B4504D8B18029460AAA91865A478CB9488A2053B03BA841158B008089D8856398F4ADED8501B82AA8102007DE23567D012D2C20CF85EDE931D20C281CFDC666162C55028902837783E33656DF0C6CAE0D159604743B105117015FD1AD70764C358B6C630A601C48CC3407460A08790B90CB955F081042C86590080C100B1868AB8018C31FC375EA6888BF6607BFC6A3D620654D440EE3DC42EE4022A77F4D5B490F1C8B0983D87F6351055CC0DF2646572399604E147F662506A31E2FDC2B1FF5E146F9105F44F94C6093702010848D5E0E75492F2A2A536E4B0D99527B4374AC292797434304688930A5B4B6C90A967B5C10603A64953A4A2958751F6F630266CB161D08CF212DBB188086BC000112C01F7C72C8C4B889B6C8D586CC07721A671D4648DCD79C7A8355519AE41E55550386515A1FA2C113C94D8B4F48C7071A802BD80783F9040FE0D5A0E164F08B8FA10A3487A93C75C08DC9168B71CEDD014F7D0F87B7D1D187DE1886C881D187299B261D5E878BB7ACCBF687664B878A161D088D55EC0C1C35F34778A2D6715A66A00A50FF1E14D2D2DC60BB7D77F6E1007922235E084B5B92172A10B31F4E20771C28B5DF8965DCD9895D40A991F0D0807B08BCE0B72E702E6D73501AE47832C5A92324E40BE871AA53032276901332C4804D8BD449E4EFD25D4BEA302852004D628D7B41635DA850914715DC0872C126D4CC96DCE00017357AC03B07D63801C6901B08BE96D73B74505711E84D20313E3AEBE0904CA6C3E770D987AC22E8970AEB2D358A4B0A3623F2D474164ACC19366C61D3756809005D1A1C064D7ACC668059D495891178D4B3D6D8633DC8A8012F43244D720C0577886690C850D35BD6149C91A77FE7080FD157411F837B0CD40C75658B4B68383E2153C01248403F561538B5953EE8C08117618C0CE802208D4DC8EFBEC6F8E09C500B06164E2C2616051FA1043E04FCC822DC8B4781C0764D44AC175F114B52494D800CAE06216ED26EC804FFD07F'
	$sHexData &= 'EDC4FBED2B016A038B403B79501D32105F7A30E3FCBA020A748B81B8BF088400723FC48D81BC59767CD06674F16AD701D82518205A9E8A60913027FE9F4308014303D2657A86618C899E1916D4E3663CB8090C7F8D37B33605A0BA890170E2C883C10C5C9112B1BBE88F1708CC6CB4E0168D55E852533B9C8202E68BB18AD86F8B7510D2DCA9ECADCF4E256482FE55D885D27432EEBEB4E46342CAF1168B52083C79038B51528AC310AE2144BB9FB01A6C386A3FD969BAA6D68119A6C1E90833A85AE11E0CFA89E9A4C1F630447464B9148BF8EA16389669578944046A025C2EAF1478470CC74707471DC22597471C5C00BCD39E6C5A6800B654186C2670BADD72A00404F830897770E2F0632BB248DC7B4CE830CCAA18E036CE6746DEBF8F501A3476035A0D021F380FD8791954A45C31B1081FC36202BEDCF22E5F7D7C100A07F94C7433C9AD1C1C3F7333F66055421D7FAE50B8BA8D700414908D4A36C221DC7412A20E6D8B16E1225CD678EDFEEA93E1294D07560F818452A4220036913727D8064EEB8BAE770427EB92240710005F08D313C7A93F51474C20B4C778238B4E484A325C104CA140B050B944BBA7E078129E2C21855CC85B1E0203042A4DC8040C41AFA1013852FF912FA04FC16B81C12320514A9CB85A2C89166F393DE86B5D1F991F0E011E9475251F4F209CB0924314784361480C4DC497758801A7862AD6E4515B2D06568D5D5E89B0563BC4C01E65188B4FB6923F0669E4C745E445F8917D30905314C30BB0837ED8A0D115BB4A3AAFD95D8E09A9100328211F109C9D7843055060055336267D1D0695BB3F311DF2613F673C3F18384C1AA2FE0892C38192C60F2BE12B4EF8F90CD07543807E10164E1FA16C3D208D570C301D850FAC8E01525744148633303501A389B00B2963605523A085874DBA248D8FC8070008864BFF5334887E1483FFFF740C54BE5A81BB16BF093EB87AB8ECCC1160172A58BCAC6A28B54AB5098833E404E05D56F6253F038B4DDC578BD661B9D4C87B5D4204255CB87CFFAE2DCEDC89EB0BFF76148BCF566452BC0E42231C72058BECA7CCC217F2CEFF8BC677084E05C5EA1006231F0824871CAF3421D770784F8453873830D21CC0C0C41434332426C959ECE8C994349302E400E9305B8145491E5FC02A180C0151F3623C28305F5019DF15400A194414D8A59BDE4AC955E48B0E3DE42769971E29D1AEA2240F80E057D83032B86E6D2A3B412AC342D560F0068FE1BD84DB7457A6920C42B10EFF36C77112A328206287AAF44C8B5B244AD09A097142C1551620AEB436A009ADC0D6B2B0D4B0DE14F2D6471406BC287A08EF21F921DFE0D8068B4DD4A363E994053D070C464F01B9382024B0C2574D9EE6AE008DDCDC0A0FB3E39'
	$sHexData &= 'A1B098708210B12507A20CF5D89DC0C570481784854E16831B56EE983BA6FC31F065609283CA52CCF4068AFA4045CDDC22A875F57E6CFD92B4C44C704837C13568B7031E45283CF435376A4E25B5C7AEF5E5FC3BF3A4A3C0B2F6947230E68A0BC481811E33F50408F77289059775C25061A54E8CBFFC17E4249BC2453574DE2304685E93F51896EBD50605F446BA21EED0F7F174D3DDA4BC3BF6A745A66584280F3624C3508A7DF5080DF08B8715B95DFB85FD41244C0E31AC487E0B5A1AB5A9112EB4A24767A2C3D0BCCC4521A3E4AD5A655ED5DB6C452059C6E6A037EFC541E0321B0E4A4E8C481790D1852AC5F25AB604405D07F88B8810730FC8EBF0B1431F051101FBE567151483070BF0C3960A257F0812F44582EDADB5C7F555C141BC7CF47C11657B0C803247DBB4A603692189DCE266B2A6D9205314A08C2D2B260502450560C5F48C8D5001F55846320CDE945741D1489439F90BFDBFE0108203BF174468B905104B9416C4D0789A67EB45604D05C184091E9C6F00F3CE2C18B095666DFFFFFE4300A3B344B7CDF51B0CD401682DFFFAD3F1D03F1F4204C8B4628E6A43240F179CF9580C97402C320045EC0AAE12EDA605760D5719D4E0CC1C4A0168DC71F0CF91141A57202761EF3318C2660A1DF672A01C9F01F1C259BCD90C820918C90DB77139749F4771FFF248DBA6038CBA5BB19ECA89CC30BACC83CEF1DA4E4243C1D062329545E05F52F5FB7000140A5848CA8E24DD34C854A94FFD25A8561E5CADDCA1CBAEB130DACEB0CC8EB055D015F46E462CA37540A6A418CA1823AB2149A7FAB0EEA889F5125F71A4AB1907FFE608706A0837A9E8E959C3FE0A056B11B3FC8A1009A90BF52185CB27941C870919C2D2A08A090B586060FC1BF81EC1834B08006294596D3D5FDC04331F6A91C0F111F08F5EB0E757190642B30E3A044F89ABAB78D5268102885ECFE21540004B20EC30170EF7DC785E8201435136777F783F6D2258B8D4F8B95F00B85F4EF07E906B2C05A930CA30810BAF07D1DEA8B198B315E28610D562CFBC551C7C32928DF940A69CA74D605753483FA338CEEE001722FFFA8B213664144BD7D23191F1B00975FB16EBF2914007E067510440C7D15F7BB7C2BEBC637150EB6750966FF66B7C8F716EBA56B163202750BC91760CDE5DB6EEB9037171103A47FD9664A0F1E0C639417380A0F8263086EB01BEC813D97F055004D264870FB0173091501556D01457DE8243F83791408566D7C55A6093BA2D47786489888FF481F204C939E40837E101ABD1FF2F5A255C6AC0650850601DA607D6E31CE0EFF285610D01DD8C1E5A940700277BC2A0D01D4EC0454BB99EA9A37D30EB3DD6A876CA6DA7664509A853C838F3558A27DAA68D8BF754CA9A31B01'
	$sHexData &= '9700648CF24094D3CD9DBD0872348D14558F50FB11CCC932C0EB607F5047CA20C74B007A2885DF45B875343DB74644C2C7CA9EB001D730803C281FA03851C297E0005A8257C07CF884E854125207D017650F33A1BAA44816C54CBD10BF0F45D033C06688C28D7802FCB490F8DE668BB002669CF52BC702BCA837AED1F85052E50EE4AFC5C51F100257387BFA116689B5F0FD8CC70F837F1EF85E3C4D073C8DF41E5168BCB6059F99F7A84C331B3F73C1070B1D128D5102060183C121E554CFC0CA6A3FF8625AE02C7713BBB20BC06F57338C5CDC8BC6C1648A063FA27AB0AA80499C65039C765E90D9899D600A58D3C084026E855C10570369AE1184D627030B180433FB8E6D27F94DBC5767011D4381832FB7BC6ED05A51A33E8B75FACC3CC6B664BAFF5F795C837C48FE5C743E3BCA73228D41014995863B35E037346C5432B7C1FFF6144833D20A544802EB186A5CC685682BFFB50D59A73F5D51E642895C6A015D4C1D7BA761D3194C08D008BC6C8706E0D33B455101B0897B99DF3A0855F8328BF0663884EBB96385D3F08050E6985EDB9A80FF1E10663B11751E66DA151850021A04C4C40A40750FF84160C5A7782875DE92EB05CAEFB55A16C80127739CB884548D8D790E69DA66907E11105150FC5C4953C1C03333C9BAEAC58079172E268955E8663CFE213BF2046C3BC7741CB3D4827B38CAB7FF7710D2D450331865CF234E2EB053530C87837860A3E43232C07046A36060C328C132D48D263FDEE4220A37985FFBFF0E1FE48B85DD8B7304C1E804F6D024018845ECDA8EB78BFE5039730874134B8A248846188376CB41DFD51CEB4ACB6C709CA519BA946BB808A710238DD60977594D1E30D7F7038DED50A1A49A34A40033119A1D2058D097F128E4BC8BC3899C4AA8447F856235AA889FCE746AD502E3C370C32DF8C12C3F4E1483F93E2D8B60160C56F60C4D3D43DB65309921317BBC56B330AE733F843C64AAFFFDD40175584860908D3C728851EDE00B8368B0B1AE17DA597640FF32308C2E73CC85C838FED3045641ACBAF785C69D1C6A5A203CF367A65D0D3B5C4A0C16C0DF020B81F0321C303364FF760C8B974068B0F808D807CCC494055540508CD01210851E46022D07CFBFA2805397E0E9C7CB9C2C837B14FB11CDBE8C8E27283BF41030BC8174842533E340E6576EABC15CBA35BF0FB701E03E52E9C2734926AEC684055DF8FC7F00C004A95E75E283C9FF8D4642C87FDF1EA8364F3E5F1380BC530074097B6435FD3BCF745183E986E544EB4965ECD76D13905E31BAD6295C8060FE9504FE30741183C00283EABEABBC6F5869148605D12280EB0394C216FF08413BF10F8267894BD65BAD0E0CD7BE03626E1FFD95DB4A3CD32E7514490F178B9D2A545'
	$sHexData &= '169ACC71E16E806B212D8588B83D2707F95908D4A98898C153C18A858551F4E3BA35C1460D984AAA8BD4A347D11300D8417BCD50042085F626834D1EFEE8D4EB0E7443098E1469894DA42949F9DDD443294C94EB8C38BCE5EFF25E0D647885FE305570042D19F18EC26B36DA24C83C4A42448E2082037374171063CC7485C8B74EED2FF8624725424140FACD61EC1EA1EECCA0FA47BC3FF2BC8C1E00203F013D185D2772372EAFE64731C087BC2907A327F1CBE48B64CA237608F6033CCB9BE642D1CE8076BDD4CB8635E293E84C97503FD906073DCB87F06C4A0B9FFAA3E567DE18A78E8284FF73D980BC0BF1D5C245692E1F121E8F63E20A053F88E83D3E06BC064C4D3E182DF0FA43D8022740C464C037CDF1F29B3BDFA32C05BC30AB0015F91245D28DC94537A2807C647895DE05E32DB744356945F9F5D46DE87533724A61A13DBECF00AA2A288D0C75E5F5BDCB0D80DBDFC185E8BC7CC80F0740D708637A4AA16B52CC33492AB06DF8AF382903D1F5338CB80126D44C9E8401850B6678CF9FEECF6EC01484B643431902D0CF4D941AFD4F8A5A4248A4025DE4550324045CA891993729C0006DFF054498F5BE442FA7D8AF63F148EC972530FA28BF30F29D05BE6EAF6174A8A894F0889570C8338017D108418406E9F8F60CBED5DFB54E0708D7DE0699BFA5544AEC1E81A24015FC1450CC023F9CC1FA5FE530183C10A83F909773DE3B9741FB0724CAC60C30B9CE065E57259AA60A0D8AB185E5997CB5888B4BE723FF33CCFF3063945332D2785F13CCF211B150F9F0B005617535BBFDE8DF48F3C618C803DE5743D68AED0152BD597091C10A6357E4DDD4B002DE8F6D60EAC0853D6D9BA3D68148B75FC18349EE1C726FFD06AFD0224C7C504BC621F53601F960C413B833EF82C0B231848A8F7BE14FB15603501F6BEFF36E23B24395420DF53A043C0D5002BF21ECE0CC0C3960A301C11426FD06C01E538518BC81F93D010EDC06C16B475C94EE040408F1B10D0A4119BD90CFA40103AC7400EC23DF26340086A048F7090E609ABA455D188CC480E9964D0BCCC0E01CEF883C60A86E07AEE566E9A46B57668BAEB3D0D9CEB36E5AE7957E0EB2F28AA280DA0EB212B2BAB75D8EB1ADEAB18AB58AB888142FF388C8BCA8D7163050BD48CCE1E52054CE432C187202274BBD7D49ACA941CE40128D44C9E1C7903471047148C911CD6078747108E428EF195E2D455F4C10293226D697577B90AB90D029FBCB893763052CCD0439EBC2395AB90A4A0B4B853212727A48CC77EAD2A01FD367485F33CCFF3067E8C77706902F03CCF625B544D810EE0A7BF8ADA8AD18A4E840C1CFA0A78D59280F9B6E7060337318EB404BAF8085B25F08A51586EC00F5BFCC22A5EC803DB626C1BB6'
	$sHexData &= '4DFC0859C138F6966E8942C3D95DF44159596B0FE6103945083AF8222C08B812DC824536A680BE3BA5D35EF6560806C97901BE19F80432D2EB0858B6D10F4FD63ECF3D703F1EDBEB15393CDB3D5953B7F67E6E38DE85C0C9EB102938C824CEEB03031F0604C00F9EEE9E0B98C9CB140FCA5E880187D5105BFFFBDF650DC288D9C1E8188BD1C1EA08C1AC34A8085889E27A5AC069D8F03448CE3C5948C006834353C8C95EB97C012C18965E514648C309FA6656F049AE181E90EC4BF037952F9FF45DF4C9EB0AC1C68AC84AF33C7F2C55EC85D2D2D6C2773BB487D07C07FCF8833BDECE296160665FD820EB062452842EC7484EA651CACB7FC0614B6B616A4E28694A95C3D0CC040C08191919190C101418FE117E40BEA31415FFD6996A4FD5F040270A55BC52990BDE629370C289ED7F0D7C045A7507F76FC5D7BB0189B47F1220F6750CBE01CBFC42074B4572BA9CF7EA515334133901E1AE896CFBC11512B92BCEF7E9562F288421179C680E10018000FE8958739F7E1A8B51815F44ADCC7E139A0FAF510C2B01B00A029B443BC22D049110989F001840ED13661856E21C55E097756DF214C046047AB172689846460C764610961D40C7D38BF62639C821BF53CBC800EC0612E940DA7AF88EB45DB55C2C0E0A34FFCBAD435B87503C215D94089322A83C8702DD001EE604A0151DC097B6FCAC3C3E4C02414CF47CE5B70DFF0A2BC8B8E9A28B2E5AC1FA4EC2C1E81F03C2B216B076385051530D77CFBA0E01703948182DAE79293083FF8B3333FF2BCE89BD15919FC0FDA248F683898D38329FB6D63508E0188750BD7EF1DF25BD8B431E018B3C318B5C31047553FD6F582444318C4C310C992BC2D1F803F820116D81DB3DD8EB042B8B856147A4309834F8E00853573F6C514154F030413B6F2F8BEF24F83D48BDB183E32C47CD81402018F46AE6DA730B08A420E7E482181701697022C7587FBAF8D28A563D1A8B81B9649047D53C3C3823931C52545CA4C6E35831105FDFF00879C8542C10018995E387296FC98BC189850AF77D8FEC6303FB5D10ED27F8D1C0461CED9EF764C30D6BD8FB05B57CE3D6ED1AA45C7B4A742823745307031DB5514B8243E58BA61BD8D339CC1C9D2382574F202E024B40CE23DB11CD006BF8CA2A00FF3C72D23C23F00218381FE2CB31D873E2AD8860FF7034699AA66904302C48181424989AA6100C0803906E257F93AD7C2F6C02B9402E584427900BE42C14ACF8BA945C20DC2DC4902ED070D147AC843495677E4E36D69ACA33C8907F4F3FD7B0FB3E4E8B9952FF32578051CD623241177C5D642C888B8F3836378B734FF30EC53D33C08E0114C7239C9DD38528AF0012AFF7962099F68518C500B05A65B3931088D8D6FCFE14C35C859C6400E'
	$sHexData &= '8FE8BA06B260BABA75659D01CC2AD005791D661C03D4911158340B6E594DF0441102BCBC508ED8880EC7F0C8549AE9014380C48CB6538C1101406A5813FD8C2FC6A247C359016071069491821AFDF5460FEDC0A5D8680A3A34292902B05DD17A8F00A88D21A10730C6A104B8825E1556E3C02266C801D426EE357F1094C33F6C9F80CD24AF99498393582A3A3766B765367C046748D88470E91CC3D090A28213C5CB40103D62C10DB847FF13DEB02524808B04923CAFF348848BF7FA5DD63EC8930463BA572AD79CCC088FB5F5480143571061CE569DF27F089B5D89A3D442C0018DCB830C4FB740F681A1C57A2839C6EA04A28E00A503A367F2DBD5C483D027764AEE004567804C39EEF6D6468BFE0B99DE3DC13C52D840DF99FEB0CB8D8830DBFF71AC38BF3EF8BCEB1010B186EE0EB20D950053C03965B405048975245CF68A78D3F1046E85554B0A5080D03D26858E4672034D3415F9C0A983E2B4DE05B3A1EA4BDA075258745300A635FA86B10AEC4860621C7DB45F69A92D84EC5D0FD0C1CF2EB45BED4FDC06C32345CC740FFD8681DB686E747F9DE571BB983F70478BBBD8F088D8774933B0E5C9BFD0F43C28DBD11CAC2A43B05230217DD1CFA33D2F28D0441A89D6D61E041D1E9A8428DA08740701FAE3329BD571F0FB79D003F00EDA4183C318D3E7CC1E17F0246F4684439FE3BB559DC70E9A0D2B09C1007193D339181CF00F178FF602E54346F8B5DECFF755C5E26298EA8BC8DA8A8F04DF0ABBD1785B889C6CB005C76E06C7E781382575D3877C1CA63BC98FD445C53853750FE0A056850C08BAC8B8D8A81F718D0318B33D980474B0E12C08601CA70365851787EBFF0D6908981E46456F228209FA418642761D53F7F55035662841CFC00D2FCFE62C3127A0CFD3EE81BE8B4C016089A118AAF8CF016A09D041088AD84837C629199400110A74F6232701510F305AD68F8D08B43105432DA8D34E912C7FE8E0F44F150479C7B7E60FFBF165F103BDE77788B47143BC67471737221002BF37B47C3297611090279AC894C8A2B0C7FEB5383FE08734EE630498B37A82F0357C45D02EB2D81F01A387E640C452DF2952B0356F28D46438BF25156291C5C0D475B51061A5ED1477DD47455A5C01C55B2D0B60CBA20C578E9880704837AD074DE301C0BA780E9DA10DB13FC55FE86ECF088A779D8E8D887804005F7837A37D00884AFE2E06A01A3B378203CE3F8A1B5A90A0D5A410BD35119430FC26A47682F3BC2CA9FFF770C8BF0FF77088B06C6508B074514C4E3240F34CE8BB5F493412629CA101010432AFFCF851048048D419889840D0C2886415A9030167830603A0AB95B03C0C6EAC0AACA11BF921D883C554EBCF00034630464ECCF0A1C21FC16861C8B7AD24414'
	$sHexData &= '3C7F890328A2E06E680F1F805D97B928745517201F20DEE85A04D170095085A122C3AAB465757B88BCD2620FDEADA88052DD516900825CAD8D820238664B725E8BA539288575893418597828857DC70448C9CA97C270751CFF1CFF3AE4EB6BBF3420C8D3058416854530082E5680C04CE41486274E181C1C766B3C63723207B0D10646548D37522EF9C6AA3108E0FF0145C0AAED8FE2708B808990A05E6323E09F9D8C46EB2048E59241201C3881954C724088502356D2F6EC5F62859CE4560F98018C4207355AA429B4E7109ABF889702063DF30EC2F70218F505AB518D4DBCBED9C0C1BCD66FBF807DC00ABEA0F342D3BBAC748FABFC07F789DC68B8B8B03B80DE8A09372931AEDFA0FCC07D88088DB5745523D401CF701903F078117C8CB47EC803DEB853975688ADD9B2049DA578167DA501B9B780993B0DB02721906F9D236D3B445C04ACFECD0CE5F8BBB405B6C8C875BA78C66F3CAD28A50C0619CCA49C39BA27D515A8A300B29FB42B291E00516A0156A3B0123F9435021A1CEC1A50EF012748218F6A02E8C8B547D00282E47BE683216036BCBDEBE6F9035E7D1A91CBD4D848080393B497C583D00AA86C701A4274AE953AAE921E30CE7C988D7DC4D2C429A420BCB5C57ED7A7B942BE638BF74E3E7C740D83C65889DE143FF2C8927369F6EF590A46382BF7D1FE838C183949981DE156788CB08EC80541E45F0C0E82863427C92AA4A9383670C8A5EEA00BCC2EBE758C8BF88D9DE4164E5056C5067200DFB11B70AB84403BB53FB0836C11BDE6749558C925CFB8A4A411434CB9E48D9FCCD115C25F5A75E08D8610483D60EAE2CEB56BE187CFCA8121BEB4C927311A5F88128C158F268790FC1EACD8ACB157F92EA85C89B589554DD4CBC269B02F8B9DD6F03EB489B95CDC549CAAE0600877723AFFC61C66E14B980B0C71EFD470B32EAD0F1185700C9C742BAF1A98FE858059850D10EADD674C684C6D8B956CFEE136D255C858A1D032872E20F0640F868BDBCCBFEF3A76D28DC848D24A47C423D18BC80544C434900199D9FB1656DE06EFDDF050D86D66FFA31B0F44D3CC77387C781C778198815C725D7CEB1703BC0208F95DEC1237E006EE91E2C310663F3B9946002AF87D1EAA51AC31778100934C0AD9B46888A14574FF859733BCEB0C3F930245BCB06A50AA1F110511A222DF5FC407B8BC708D4EA090A74690956F9A165F908C9B6C8D4EA85CAC417224B84A0203487EB05D2090A6D90D08FD8FA291F81B1F56A9814AAD429FBF139AB0428C8B7D1AFCF7737292039C028F02E407D91CC8E4E86D024DCCE73ACF09F1160266AF5E827D74837DE072DC0F432001322E54C6ADE0E746847665B4CBB4C71CB4646258EACEF557006B929E05EE21AE9CAAAC50D480E'
	$sHexData &= '8CC0C68694DE555C1126304FF04000BA14B9EFFFCD82D6C978F78996500502757C8DC6E856F9D62F8825BDA2506B6040B9021B9BC634C42440E5219E450483C1256CF4BAEF0A3620700FF0018401092FF7B8FB2BF571883BDEB7422538FDF74B2CCAE4227570E2941E4A4002F02974C52C8B4C948E52AE0C4C85DA390DBB49FCC2AE46A556B25A3908192F866971BC35F9C245A2DE450FFA0655A85B45F60DF15D3A7F48E391E7FD960D9F4D6F9149E9301949C602015EF4F515377640C3FE401572C8074118FEF00EDB735DF982FF2C3FC8B163BF096947DB680B8CB50203B153F80AB8D3D83A9FDC6C98B87D2019C1D9E08924020C1267A04134C424260B60EEF4E43F9EB00547AE4D4411985DB33146AEA03EDDB6A105A5829CFC4DAB7F2430172894268D44BC901563BA921565A08F1046C70C2CACC751946E2B93A8DD6D70D125D4B57C8C802DC6B8E0A159AC8D2C82F38231572C7CAC3C8341978A2A7997DC37F02697120FF3F244A0B0111E0D20A04953F47C821A7572080550FCA8E88A84C9C0472EC48C4710AC9C1743C1D7FD4FF75A8CB9A9550CD0001F539440270207E32BB8BB9EF56836C78738CC223C365A8752FC69A6D15072BB921C39E17350A0C2A0D291AD1C4291A816C9D0EBB418031BEE38B048850A00F1040183A159E2362A62E28903B371A36C6DB4D9084949C3E03B5C14E30DB34B056F24437332946E628E04676D506D6B458C911B7AA365CD3C98BAC03C210A80D9F87403185F6068BD68B4006AA14D20B4613509327A089727E11A60575B166EC993AA00CA39093C4B00CBE222E1EEDEE01A34590C7CB1775FE039AE42975810C95ED04C73C53210821DF14451F2140F956F8FC19E0202B6C841C471847288A93D860331F48301D72576850D930A2C093248FA2402890E58BE039343D9DF5BDA50178AEA24462B4231FD7F0543048E806015A34D652EC40C2F685FF5472902CCC5502D788E811320103FAC106444FB4698D7701BBF245D18D6866B5A4897AA0E8F0450F8243D6BD6E387C147EA0B8571A190645BA65181710E0F0029142352D95E545A4831C900F1FDF03B9B87131C116519186C20F87C8E70C54386D8A7979035A958484E9729710AA8F9FE4BCBA041CD45F5790093950257F91A49B1C90CF91B491AC91AC5E3945253C1D7F91B834C2833C91BCE476573DD4A15B848CE0EBA0FAAA8491AC4287E472A987F5A282BF57D07FC8582756DF0D4B11B75F0405212A024E040DCB265852805630EC2C18B3720194EC31EC91A480F7BA422AEF015EEC8BD0007CE7335707148B02C899C23FD84DD08D4203414EA7476F360FF5F001186F0D60C9959003F93DE0D68C088C68B9CC9591F8B0181AEA8951755D58F8E270066C17DC40723FFB36'
	$sHexData &= 'FE0C512ABE0C218D71FF2335D97303AF58C88911A635E06FA4FFD84E23C68D1C85EB3C0B00751A6A2067EFC66963A5D8890C03538B0C6068398C0B74583005828321D214F442F1182A38EA0118049103941D3D582AC108EFFF97E943118D742D2227EC8A1C9234EC952115C24780633AC797CAC88307FF47C9414F26FD6A05FA4D0A0714A59CBBCA650D76EB145BED707512381D49C7A5805133915F545422795808A2A4C04AA52BFA413013573152061CFA146D27E520357A4E63B1443184A5FFA5461CD4307FC4520E01CF1C2E349BB4E4A0C75C5A461803842D2B461C7C45D422EA44760FFB0351A0505F584820C788737F40B9001BB1521B49C0E50A31427FA476021B4DD13DB703C7943BF844BF26BBAAD2008F009FB1B42131CF151488154CA5A8F8837A1C1872289E08BFFAFFB22C52183B51100F853B028B1C2BF09DF613103F0C06663B082E2311E24D0C8FEBB75942EBC855B4BFCCF8B701260B42B3145753470BC84A4DC8567003BC4ECA07AF039A932B0AF53C0F19E0B1954D3936040FAA04B310F310F222CC730022A5999AC82B5C2E24F6181C5DE61A4AA79DC8D4DCF50023603EEA0918E9D4B59B12E0CCDEF47D25215FD3E466647641A136270DE129ADDCD80C90F054BFD75133D24B83E9921F011FDB5BA8C2A3218077C491AB9520C4CE07F3116215D3730CAD659D10EB624E473012A7134080A62D9FB8400EB9DF5824759044D3024E60DC15EE01DDD9897DDC3412A38748FA108D87FF03BD250013FA861094E02C56E1EFD1E1E0CD587C8BD08955D46E390A01A9709A8AEFE7AF01123C8BAC4FAA98D34E0F783992F4EE0AF83D7B594DE8FC38224DD04A7899240DE1EB7A80BC9B5AE24FF4924F8B47FC2202AD3241C888D855901862616666EB999D85A528E4B947B6D0741947837EF481A1B62032C06361D0B5F56D6CA4067E0E04A6A3A7EC77AB5406704E4D7DEB1662FC2DE529B5715C6BE02AC243B333C6A358C00C059F0C3A0D7CAC4D2E5F3703D86450073B068400018892546CF5A2E87168436B043DDB98082BC2E2E1933C7A9230A405CB514BFFE2BD148B0E3BCE7428DFEFFA8B8D52B8ABAAAA2A2B512209F7EAD10ADBB98CFAEF03D84E75E23E5C780FDB3BD8735FC23715BD47382B254A08743E91D2549EACDE0807476C50C1A84793C524072FFE2B3F0CEB0957518BCA38638CB908ABA41B3201154B230A791F5E104B48BF5989AB08D5067F13E2C08C14328B044CF048772039A3C513F406E02671F8D5E86E122B4ACBB9492C38B895D517216E12C5EB0E98A24F42AF2CF76CC916B87A40747277153EBE97C0F4565E934C33F8A38EB1F13CFF49ACAF134CC43F8D0C40C1E102952C03898625CFF9C30810B97FAF2C308C00243F1C3290FC7'
	$sHexData &= 'F4F5C474783039AE7A68B78D2EE449E0D89400426083BC8771B1C01E831FF23AC47CE3BF0A1C42200E86A186F7981B4825F579F59B0E24B7A0A807E15E8061AA04B0DA4C2563FBC3290FCC01886408B4E0830E006164C0685E762C3E2D06B870D6C1A54DF97DD0AB198D7510C9BF669E047050A10100F02F6E6FDB642148841140C15158BC1C60EE14F842EDB3E19B8E8C3375A4B329A2BF3C1FE02782E94F00680570F47C804C6F7F119D1F696773BC21ED0BC62475C69BE8D3C9589430316E07F227F8038FF720E03CA03C75C72F33501EB94375F8790431E5A30D08BFAD28010520600A3F0D2DE2C0A543CFF4262E21FE458FF6F9C8BD78D8D24A1C96585F46A07F0ADE401A19066828467025F84C5419C90AD0D2B07D1B0A0B6BB487E1A89E5B924674C452E349BA1F839883BCD8D5590C4A74DD8849FC4004092A21C9D7000C0BA00C917C0738D1A706B43E7D50985B580010BCC2128364D420A10D08ACAF5EC2B5DF2C08845966F3C8D6E4A00C80CF7355F56EC32550304EC0CE0AFBC677DDCF4304A2A4027EF429EAD5524A411EF0490F7C4705A2ECD130F86B9260A9C8C0C1B3D623F6F222104D8E18BF820383805F640062B5E8D2E2C10235CE88284088D210766844C098DE9DE3E3B9561E814EB9A406C0AF040C0DF7C79754C6A4FAC0E5230304ECDC20830826B58924124CB0281A982442BD3F0005710696CB2E5C60276995CADC8ADCAB0C0B35CB801BF103C202C786AEB9C7507AB2231775564751145AE128AE82D5C48464DBE57F9B43C4720E2790847DC8E6D9E2CFFBD0F7F9A2E205C81FE007DAE8F50163D7273C4991545A3CF4C25B8010B26828284DD2B3A0EC6855F845E89EF469A501A0701B5458C8D8564A6C0412C16E2628021961096804A0962693DB8897588360EEC26E04320B8DFCFDB03079F8AFAF0E70B50B3A62E60B82CB1FD7B0B58C1B80FAFC68AB450EF0694273B73A9EC504BBC130EE10170CC96C2378B45D48BE39896851471EB104CC687C7B8ABAF21A7F0B02B45A8AC86C173F84040823B95C30F1C8E12C1255DD25BCD8B3C182CCA8C6D0D8E1D861806041DE8D9AF0F607A09C56CDE8D74B780975EC58555E4B4A95029007E7E3250770B415CF67E5EEE954CF93C818B7D4895C0C703B6CFA4D743BAD13AEE5AC1E910C640A4AFB657F2768C7C721C778227DC7546694083C612B49770F91F893BB77CB3B805F4D2C048E403D78D04B5F46862753B039286AD2701C3912B1A16487449F7019AE28B1380BDE9741027B0D77D501DF4BC98040EE1079D21982CA1D0E84705141D01C60E2ED06DDA22A97C92460C0AB8108A14F872B850884614377B5AD7D03E1A8215D4D05ABD36CC2B8CC6856C619C8CBCA68AE9EBC01EDF58BE50BD2B01'
	$sHexData &= 'A783E90FD21B760BE5D71EAD4104261F62B042400F5A05B8ABA1471061701F0BF001121372320B3890071D917EFB85582E8A3675EB31C30A05C482C37BBEEC45265620BE009AC21A21356658CDB8C2360001C33FE421034D7FD0B801295EC429BD94AC7269C16FEA0B6A8B53AC430C2C7B110A8CD144FEC2150D084AC0504B7AC4262F293AD30AC2100893D47551C8154F9C23D17E831C372BCEC1F9027C54524A5B6AD1C836A60A44469223CF0678758F840AFA7893F6EF900A6D14B81F85EB51F09C346956D4F7E12B205CD09985DF90053BD00F47C2FE99C9A0993A20DB6E33C68F41E7344C7F0FB60635BD9D8C4FA469C8801A460133C8C2DC9FFB0A0269C91F170303B56723FCB772AB7469D1137B02C1E10605B979379EEF7BF04282C133F88B0303EB891706860D544AC972998659C8A98C878B9343A0FE38AC474EA0FEFFB558F7900E76DA2EB024AE46C3683D4AAE086CA4325C5B197E0EB5AB2AE341B295A359ADA6328EAE92373281CC0DADF4F81CAD454B5F3C81C4E811779C2C7E42AC5EA67A026DCC96600147182D198E0D51E144F31EF33FB4E5B95C2EB8BCC90406E5974AC0C4B48845C88A9EE2419C60A0045C008598E8BE8D3E13014B924E0D3005580627190FEA8DA5EC151E42555D175BCBBE95F1BBF176106D9CFCE72A3CF12CC3C6D3F494430B28128789AFB45E0FBC387EBA0F118BC70B08371D26C7B567702F6B42F2D9F98B571060C86E2A9EFE4F0C508BF669077A2DD9C70B451678138DD034E87C3B801A26180A0151F7567B79F85642603D40840707F250C252E0FECA8327B190FE54C8956A22C3BB8B14F739F28A25800F42E2F48D6C4FE91200A674C046483F1EA4C6FF6E33F62C8E9AB8A9195AA304AFC00703CED3EED002AAE0108BCA9698C34AD0BE18E9181E087E15238FA8036F5612011992431EA801FCC1C21605F535E10396D605F595089D5C605763A0D571515029F6E4985D984BD9C9D832D80140A0226A22CA376B1166EA4E96C581F9059F0F4FD13B01BE0B7A983A09C68FEB174437F71E48C1C18833A593082D1BED838BFDEB28553160983CBCB6753D10A5EEC62130C9E08787025008268BF50BC86220DD97EB27C01B9858692DDE79890CB24636868C694C91E206A755C840AB7B3B8912195DB68C0D25075A57261CD0630544175040879649ACE8551D0F7A8D19DD48DAA003CF8C8489444F1CE039C9A8E3196D85697E43108836702337279851BEB40960B413949DF054986ACC09BD946AE94808C97764B9B52762F025545E82A54D442058012C6A4FDF9F0E3BD975988B5D56631798429E383A6C23B0EC9351747AFFD6850EE054E25C2DBCADA0FEC22378E2A36DDF895C751ECE8C8A7C8D0130B9E4D264646808122479175'
	$sHexData &= 'CA3217CB90A0656170B8D4D9C32962A6B093A50E88B85AFE98A4714E8AFFA8845B06AECAA72125EA85AAC5725007219199CC0C8AFF10379CEFAA42B459C1EC773A0C1E38251E9A171C6D0164804979FCE99A391298204CBAF0D3E7A6A6CB450574B83BD58FF8EBD2112AE354F841830B9549809474C208C4C459DE849CDCB33FF9B029C56FE61224816B88B758F4C6A989C5CC4EBC2AB710067EC0F2252708AD035B2EF1A6D5D47BF80B7C908E004314E9F37CFA8ECFD3BFA7CB18BCDE51D03C6033E4183B3CFEF83AD6101150F8575FFA74343385B4D4D8CBFF8044EA7AA026E8CFF57C3D8FD497DC48BCF8B45A88947B0343737AC8947B088479C361AAE519AC84E47948BC09A21AC92B1003B859BB1D3C1C6D48938F25C0DA7CE71FE9C4F03A14841E901D90AC20FC7C7F0AD623190C7AE93010F5C346510F4A41A8B6E27A0E815CCA164D447F865AA11E440C3A4DEFEA1213A6B180FC640088801D4B85F8D174118C8AD32C81BA4FF5B1084C210C014F272183CE1B6455DEC04F209A613C0155F6F92506A187DC223F12908A2EFB67DB06EA1DA0B187D8494905C8EDB269097E6337AD301FFC701417CA56EBC65CE5A4C8BF0A570DDA85FCF8F355603E17CB9D386857D263530D11CC6C490919492A7B62F05247DCC3D908185BFE911C6431803B8A5F9B512B6C63FD46ED6A5D20972ACA0C768ECBE4081E09C10E1F50576249662E2F1DC91057B6130728061CCA98B2E2D21B891E3F7D4952901C11A5AA4358BC1D7C748C43B5EFF758C41B8D9146090907E719C33D240010628388032DA8CAB4834ECD633DB987EA4908B558789C50C98D4B4D1F8AB954A82FA44DEDB6B0DE6AABA378D76F2436A88B05EDDDAFB3BDF7CD29C8B7E03908D1CBDB1D3C07603E1968AA83475A9ACE0A2D3FC8BBDFD9A81261DAFF088DACB940D9F0C3BBBE932C5130077189E020E2BEB0423C4A15035A79FD429CAA14B6A14AA11D8145845DF219F10C05FF083EC6810FE4BC464817D140F1042AD17306659C62C24D0B66BFFBE2B0FF7E90F2918300910C7064428EECB057CF2FA027D7C208D2AAF809C24AFB00A8AFF3308681E68D2828B470439470874D25D4AE7190F28F55E35DAB796F1833418EB0D8D4CA851EC2DD4CC0E10025F186CF15F41C2420087642A16B04DBF5B804300391051393408DF8733C7B2DC2998157E9D68C6072F3CA0B04C8F18681108210DF04C21CC9AF5AA92FCD2A30FE8699AFB2D5A269300A30920ECE8DE0884720496A1F16A269C775D75E44BE0E1F52A46E6F73EF42F810DC3418BC6C1E103C4422EC71F76C64322B94A13087F1019871C7818310C2E1CC8F0DC6E8B1B8C9253C8F8B1FF7EE1FF4A9A79E83BF87F5F3B75E8745A0D3B5DA2D7BA83540C838645'
	$sHexData &= 'DB178D047F38E3018644C6F46068A7C745DCDABA2000B37141B0298A9AFD0181D34ABF3BFC006B040E5D8D55EC53AC841921B8ACC0A64EB4005F811C52F0888917C68930A7878CB506BAFEAD6FC104321209B452E11A856A9160D6ED7A800C60890111100C536F0760777527B45D6A4C1C6A4D8907C9ECD27229B4014D4F2E982DB348105F28D33497D0C420780A14F89868366D18530CFC1C56F484824030969EC8C1399E26F05E90E60AE0035EE016EC18CA0C4EBB0D3B438C42B803CAA8C477415403C3837D1080C2D2125818397832016EBFEE23397D08751E080C751908BCDFD4ACD1DC170EB055AA1E890F89022660BF0172CD0603F303FAC80D6137349876740B3B5D42786C03F2D203B62A104E33490CF3F0F9FE9768CC713C073BFE0F4EF78BD6B3E4BB669EB68D502AF3F226DAD91E8B7037EF83172E423BDA2AD9CB8BD1FA05085E70040E02F0413BD12CB7580B8E96C10F0C4EC2201C1C166F1D7566869C922B7440E6C09AC9021F71281C58A985CA31EC60B890DA31F00A6D6E46B3DB0930F8893A082A32EA0583F9CEB3EED07A0350ED0F7A20F8A7D22CED5ACF12CA5D28D5029AAD2478205225755D766824F8AC6CDA13993A6609EF90E567EB7283FB5EC3D35D7450D8D983FA15D2D027E67FB8BD7DE07D0552E0EB05324FFE8B75F8893EC14C85BFDC8A3BF77C0A020C2C6178539E6030FCC236463BDE35E10E1FB8F1C59A378B09342AE34B46F71DC8EB0A250E615C0836077D0FEA7DA4B68430420F0A01EF0D0E111FC088953C5BA879008B9F80E733F6CC804B0662AD3EF8959E003A442DA55744B2266300A9FCD81BCDE8608000A50BC2F0023301DF6AFD92FFD3B4C4DE16428067B2D2E07124E3179E70931055486874A77BDC7884811B5C807836C85DDC2B660F090B5E5DD84416A4F8DE12DB7E56B47E520B7F4B81FB0F43C088AA05EFCEF8367A709AE03032270076081B53A3599958C6230AECCF7E62E04E68BE1F045775A2F433011C8384DB1D2B0939909B8522130D74E18D038089500586ED87D118682000CCD475D84018D45960A030F026612CFB01BD4114535AF8535B0DDA5108DA0438E03F060E04ECB03B3DFA2F0C36CE4C780F4ECC246304115F13654AD2A430B81E38056C405312D856DE2CB56E55767B54D404DC959692F850431462E0CD6074F43292FC085A8450544160EB06D6BD04AF2132C6EC561D308A25CE8B13023668198D238CD7A0BAB05C80F6860859D5584860242BBD36AD325A3F26781C5C7818B0FA07362EC13B45107F0EC806D102885EFA7F04A49837600344964B3F1CC054060F68088D80FE0AAC71875C320F8842975EFF7181A0D214374A3ADC8D0419F1DAED10B88F262142100A586626E10C521426FD0D30C0F13'
	$sHexData &= '2C6750433D2EB1FBAEAEE1F2F30CE162BD079210E81FA828BBA7C40B8D09AE04AC0C070B9AC4FC0349EC957C6A605D1E4F7DE8C03F3593DD512922B8D1CB0A39D12D0706258F47E827FA3DF7D8B30F32BC334ED0C3074098217EBBF19263BC27C478B1E0FB6D3262BC29919EDFDE033C22BF3750FB73A080AD3C308E09A642F5D7A100A4733825F456A37B018380447CA8B48280F0406F83BF97C9661600E035DC1418355063C8D594024035E30E3CD342A896EEC0F8C5E9A0242D74B62712C254CCCDF285CBF2998059696742446099B860CE6C061021D1D57545A14567A6AC78B76987C182DB2C32428ED42026A10875F87C56CB6F12C2A8A5510EE0E6788F184D2750AC271BAB756E56BA07F1BFF292F894C2414D79AF6182BC879490F691CEE447BEF303808F883D820F6ED0F28B79477153ABB00985614C4F3B8F8B4066170F85CAE0534B7C28C451C404E711481B12DB82C2828AFF12E037514B366345CB0AA787492C72892D77E06B450861E4483FF0388BA66F18A2C982B9403261804B78F331E87F6DD0F101A51B2C1B96CE8541CEAE6C1BBD672D118F4D80E66D9D7C33DF6DAD67EF0745B4E091ADBE644D40CCE14CC667BCD60D5C10CC51CF9D068E5EF6CDEFB1468CD1CC224E1EED01CC47DCD7B3665D7E00EE76380DFDA07237DC8B3D2D7F62483A7E23F5C100083C1103BD7B2610E0CEC0ED22E06ACCEA0C390C28D8C5314B1B4E24FC9A71F0C380E740BB8683A4815787CB417CE1814DD09E9C0D2778B2A1CD299BB96E835375BF72404131B1D2AD0366F3F051B0865FC1C4683C704661B7C8AA87D068F8B44271A14030E2C161C389C2A10F70420727AFE131D8D609825220F8589C3C23F75A3219499CA9EAAA4D03A98783B060F9C86484E72A23F5BFEB800A339A11F897DA48BD15404A07B40412474804B281672090650986DE3891412DE6C9C894DACDFD211C2A879A373748B160C46A4470CEAF9041710D6834FD310ED6A0620AE1830976E879B8A8D4318500A35271395DEC8E3FEBC6E97125040D2486A045335480FEC28EB0765807B1C4AD48030C03F94817F10F401210114B4C01C2DC85408B809AEACB3064794E22B41103F266E059E409CACF7F69C9483FA32EA5F180DC49A7CFE010F869102D006912240F6D04ED4623D73147F0E04D0FA6B6060AC333839F542B0A070C14842A03BF87A540563D74040B540EB8C164A6EDD9553282C5C9A95D63DBC1054430C5810D22EEDD25C2058609C2264C0898E82F589529FA95F01475089B5449747FC57129EDCD0F5D0394DD4741E5A81F823E33BCA740A2B0233F0FF953704018345D008EB0A52516512CF19B8025DAC0B9DC6DF2DA1E8219B75178B9180B191B0C731077EFEEB043EECF822FDAA944772'
	$sHexData &= '03F230F80D0A2EA0E13B7DAC0F82124F3E1D366C108B7D6E7DA08286849F81DF33E0DF360EAE57807E3F097F133E0680797400754BB345B041CA270D98B88BCE502E74941EFE523C1F4D0E1EB8D0B49804B4B01850D1FC55107E823FCEDCE1109D75C1C68C94BA04AF34967E123FA15FCC0F205D5370FE09D7072EACA05A053354B06F6E9842CF004CD534D654B2D30085436FDA2BF1F7EE4ABA80431A33A502F4009A058A02D5A89BD837B1C80DB28F4460109DCADCE0AB965B9FEDDC5676D051924C5C53F6A94E8FCC78F8B2E314B0807D13B57550660DD42AAE4423C34BCED9E46A6A26F5023F3CB8E40F88887655A4B45635117F4262FF320C2C5F01277BFA66905B3A5432160B30983EFF3007C5D3B816B6EEC07410CCD2F7D16CEB050CCFFC9264FDB47B7014994308E6034B10B15286C88C1A128B50145D0C977C0A9C03C70C6C29BBBDB58785680B95700363604CE252D1DB657815B78EDC28CECAC07BE074678B556FA8886341F44736B102F020BD60B9E36BBEB7CA387C290874110C3B0F852F4C241D284C335FC6F21466894C8C3EE7E8FB22BADC2CEB138DCD50C6D805F0ADA26A30553E008055004EAD9A6387C75E4B0E6BFE91742A94381C94A2FCA4BCB8A20AB7D3668EA34E7A46E31EA79D0B3BF0228164F6F78A55C7645FA5EB34623560351259751051A26D698EA9F07107161E538A1D0938440A4B6E8A4200C2371C3FB609568A04B3F1E3A3597A0E11025E5B8DDB8E911A1F1BCCA38D1511DF95DEA0B302389F5C510197854140816DA90EB0F29BB479DAB5006B1B269AD8C06AA2723D21194ACCEE650763E8481A888D1EFA8D62654708404FE4D1420926A2400CFF3B388FECBC4F1028F84108C064383CF2F052180C071BBD3571E6711CFF772056124CA7A380B0780F6F920EEC4718C66CC4E84714034DC200B584F0F4A22301CC323EC8AEF1F6BB14AEE13E4E04394E0874D6D2C1426432F79079BCF441B5E8C0E5E68BC4238D6C44D940D3DC463A08139804EAA256CE4F03938BCBE03A0E432E92CC4A6C3E64681E688B426B7C3BD06F68508A92C7BA40C38C9E24AD5B701FCF09AB9B58FB3FC471DA6AFF0C0C471D4DD3B40A18101C148220344DD33418241C28200507F0A824DE7F3C41436D3F5698288174908C14229733412707242899140A887518A9FF2BE4218F5F7D280469F751C06CFC095C0E0A984E139C0F8D8D48041A9C205FF294E5FCDC954E4B325350A004009234543E0550DDD9F984A2AF742D39B51774C07D52A8131E0FDCFF95293C81474C1D4A3C373921E716A798FD98FD1AA9D611922C8E79B6C819500EF47C004610BF6FF45AA7892BF8EEBAE00E4F380FFE7D7ADE2FD11E05F00895443E770F0F28D0DDA70BDB185DD121513'
	$sHexData &= 'C760A2354EDE4F33EEB0C3EC18554408BEA66B7DBDC4EC1770C19E44B5917F4213B7003FB9DA06F2D5CDAE04F82485EC6F26C9DCE56AD58DE04525A870C08F487CBE5FBD012C495C00B94905A5C2E978C88A07CB5078663A18107091A1888DC65A4BD7824500C7CA4955B0D2C38004335806EDACF16779578CB8DBF0365BFF24E1268CE9503D0837F1800FF84EC015B9ACC4A5DB92DC08350397875200810751BC27E06A1146A6733C99F32207BED6BEB4304154EECF036DD000D7408D9E064549EF60EA90B3E147974EE044F002C670D8BB53F87D2FEE32BF089CB8BF22BF1127CA2632CC0433B2B609E012ABD77C5690E96D61852FF658CC81C1C2D479D50AF62E2613857946CC16622ABB8A9F9E9E1FA7DA5523938EB86B2201B16BDF5AD61118B4356E067B409742BFB277D0837C0C6C7311408085290A13962B7B5B6597C72088D4256F036F0894364FF9DB52C10109A327E043BF17E06B7BF074A3B041088FB39170F8EB03C2FCFF6FE958FEA8BA9D5026E11738BD0AF3C4C46CB3202FF0C8A8DD9D1F06BBA884DD484A62C104CFFED659E5A4DBC4537301379ADE1FDA95232C9882D2D28B8B1E4420BAEA0F4D4CF87563C807DD4CBBC447F3C5AB5738B5B6A0683577BF0A06A4052F3BB9060CDBFF6F50D8B152BFF5C64681B854C1270E82B006840420F4457009C1ED3955FB1255E0A83BAAF838273FA1700A589F4B20065874F4800510DA8FD3454E727CD03CC45AB90237D30F844050FB742B6A00566E3DC80D1262703B3F16B2EB7A9DAEEDC710535A090A5BD8C5CB8068BF82C940E89CBC8A00750CE34BFAD07002364E34008FA90115AF0ADF78C6C9ED63009A8FCDC57292E2747DA0A5A88452C6C0B2090F6B0E05B985D60E96E0C4746650E647319580D24FC0E34067269307C2039A4E92A10FCFC17E40DB8FC0538FC9B554903017011BC1403815DC4120C914CD27C6878CDC824877C68139C7941F290FE88FE98FE5CB8CD059BC59B16140C914CD2BCA8B81CB82487BC9B8A150C914CD2786474E6B92487789BC41664886492B4A0B069462639B4A017CC43864826B8C892666492CCB818F039648864DCECF009A34626DC194A00A190A9C580E41AC0A5826CC03490119D09588C01500FB89670842F94E18B6980D9846C7C7CD21A2201E60A193F2AB0C08A58533F31C6A38BBDBA635792E6591895AE020854621572F4FE5B891DC40F3845B4740C2957028C71C68B85E3F99CE4C998FD98FD94FDB0FD6BE42107B8FD00FE307AC19502041B010A4D30010F85BAC04AE0015057520F848127B41EDDCA9C021F50D85D03678D21D1F9DCDF051E3B5287CE8BEC8D9515150E151E26229FB12C99B06D491CBD4D74123900C525719F753D385120587263515238D105'
	$sHexData &= '5D47A0ABBAFBA068925E417C1C6DFDC2A2640335484D54612F391CB982502B1C5E7822C85144E0AB4A8515CD5C1D0BAB441528B98C1F7BC2555783708173506442AAA6C5D7847C20868890811F21323F55417224851B04E448AE28C5FA2347B79B2ACD68122800BE9E78C40E4047D15C44C1637811F8C9B9B02E9811CA856CBB242C2400B84E4CD3E65752F0561FA8D6554E319625CBAE842663BA623C75C527756900C8C8452C29428AE1B45B83A02AE4A890A32B2C18EBC2A843AE5C8BB1B39FCDBF1C5D23C6DBCF2D160432902C185928BAC7F7A9D7A7594D2CDC72EC4B7DC950855493350BBDD4032AB085CC0713B7619E43520E09A43BCD4E42022AC61208EB18E10338799CEEF8564180AE0AB49573481C32BE2047CFD24F996BA7A41E740C49D2A92975D67932C0B666EDA11AAAD484F7705ACA7E624DDD43BDE6A87E09A823637435C84BBD552AACAC23957035453ACD4C7F980E7793FDF71E8CBA857F552BC22B8D845E776933572EDE70B879AFC903BD8CD324B40A4336188F200551B353EEC1D8A5B88D312A8D67A3883CEDBD3968D5B141214BE3DEE0AD00F5D6213203EFA0557E5833F61FA16D100E6B9603CE524DAFB3DDDDB659038DCC7F3C8890858B34CA2660B4F18D0C888DD6B172ABBCB8575146D20C3BB57CB910DED31122BDF963101C8C5D9B926CF091E2B88650150FE1D68D4A57FD847DDD537A4E614D23AEC88DFC71241CBB87470A1545A7710DB8A85A1B6CD1049885506EA07A4803B1BA62E175CF1EEF1604EB0232C07FDE140F09A43B1C32F5C996735978282883F9681276041C59202DA47DF42642307804FA95138E880FE002E0AEE0C2550B6ED712F83366027579235DC45B8C184530348039ECCE006C7E7442842F89701041113993819128FF01EE662216521889B52142B613A11B92F5E16F7DD9E69934E059FC1F358521C4A83C182DC823C38CD54CBF97012B98E15BA4B5CF685B1A07AC8D35184E0296D2EE28C17B908333BA2B012A5AE50C8B2CBC7C72B5A47317CC344EA407811DEE740E61491F041CD26A4444C7EE06ECF28BC638BA458050D1858443C59F3C36837D90EC30382750E1D04451415AC8176F13B1830BEB1778BB2BCB81E35EF0D1FEEBB4E55B8C58C03F3C3830B87422465D117B0CA101181D6F32628245F6542F74DA2DED43A19414994B608E2CA393488D84858813556338438BF05E21845C7537D533221EE2E0640B0D85161C185FB3B1C0F7E96F23C31737A44E7AC1EA1F03AF171E408A1D9CCFD87E38F0B22F2CC957283A12A11A4ACD34D7977A61111E48567FE93B867BF70813439C386194294B303A907D1C8C57C2E1E46A5A3891DC0AE30E3B0176F60B8C14C2A02F9447F58A13F7828D8B0C65610007B9940'
	$sHexData &= '482EC9914FF1D163781C80C09AA08A4A4C3F0028A9E3820C106CCB21434FBA616C0373D285E8E21A9F0B531FAFF1B381B79426A8003A81C8D869842EA6674AD00941C89787C8AD0938924B8B956C00EE8E4F058B508C325647A00DE12F8A7F0DC5D0C102A1FC8447529FC6AD34C1D8B218B91904F06EED57F8D858B29760CD9B11D234A74E6EF91457E615FF6CB4502FBF46714F9B9842D28529357140B46265334487EF7C701846BE93E5693E73DE229F725E4466FC1798C60A54C03324759787A070B1048570AB192A11590CA3C2AE9254CB1302FE85AF241E9B41875854993FC1186FFBB03D8FED06D6C9095FED0FED4134B9F0156A4B630BA46959DB154CB015596FC43AC418EEA405C7160C567E0214CFE1F4407094F333053821DF2814D426B2FBB025CC3B715A4A971D8B5C1660DE970A77B2FD076226D5445288224C81E4C4377072B4621BA8E7E7333C92B971C0331B052BCC0CAD8096D11A878E3DF473CC84C782A9021944B54B72336E1B46446BF71031C883733248A69B2F7C9324288CD7C7C8BCF2B103BA504830EF205166877382D5C50C13E19A647C6CEA2FC356549D4F43D0AA904AE89486B1C4873C900200450848C0C810049C45274C8DF5170002789970974AC2BAEA5ED08AEAEFDAD38AA487841D8F4B5AD61A793600A83EC402718498F2064AF23C622E1FEA64056A804741783E0FB581143FB77C0CA15A802741434FDA17859712D3B5142E8FEDCCC160330E9F2E8792F6A59E113AE82FCAE837E8609AB8C5983BDA159DF0AB07465B4480A5F51C704244C052F1C848D89E19585476807D216C88550618A748A9286FB6CFEF7CE164F56264AB84899FC807818007583ECA10415008CACDAA59D394185528321B001F0FB4162E712A6793A5A807DD03653D5C1C070E5B898942EDF3989A81D4DBC3B8D905283F082528DC6112E4DE53B8F3E275CC1882ACEEE2D7E2B8DC047D62B95C42788169348FB26760E87695A92AD62A880FD0020ACEC2978C3C3052951525A4CC15CB1709CAF80EFDE63987750958D106B980A589062A72B75BC56B1CC508518A4F870D25B7A6B5CC7F1F85A2C3C996AB8FFD3D6A5EB007302831101C09B3ADD8F3B44035C93C897408A3A6C6EDB3B4F4D40315C4D803873D908CE021E8494B128760DA140A2447C0D33A5E3B1FF97ACEB0E8D55801F9D6C6683018A040F455ABDF7931FA7A102D607EEB4FC5728385F82FEE3AF64684FC083AA9C61F438DF3079C00BC491D4C3A99A42D0245C8AA982AE697CEBB8925236A3C773B59BCAF4FB7EC7A32FDF0249AC59729B74698B3EBB0752D736207D76D293AC526019389CEE89BD26DAA6F00C49369628FC9E5D1A627C329330A9891EC3078681FF565719943C5830C0812F32F594'
	$sHexData &= 'E1C483404D581FE26117BC03DF34C4290E3C77676708C2F61D8995C80BBD51F8C0CC0FEF8D543C0AEF1B0528C20F2FCA8A5DFE785881C827CE82845F85E58051CB9862A3F08E890BD13D78D759D7F15060332048EC1D900FCE59C0045885582FC88AE5C1DF4E3573948B638BEB8213773A473BC22BC6CAAC9173F429370BACFEEC1B58DE2D24180AB0EBB41913035E5C849B91BD9DED78E180FFF00663B36E81870C354D1DC80DC041242D23C4E2E15EDB2A754D43010D5C9B5D5676E4F8FB4F3CACF35F3CC8F8BCEC505C3B1C5EB4EC70A014BC2A3BF77582C2B061D2806F10B2F63BFE745A9494CDC46E6854CF5059B1E454C260A65B6D21BACA90DC1A5150253FB6B790E085DB3C83C7951D1BB608B275A64B42B5BCCACB58C50E259001BF05D4A5E24F20FF0E24515D481E50CC78FC4D5CAF188A3B44FB59A12CBD1876487B1F571A472CC4F2437A67AEEE008073804FF63B7DC8DD8600567AB9D425A1BC28FCD4A1326CD5610679364AC48CA700BC97C211E4E11E6870B7A370B0B81F2360A5E1202E1562E670D035C9C87423E40DB85A70A2437C28152F32E573214CE45DB82CD6126BD1520D97DD134F57654AF547B7619BADCB2597828C04E8ECD45B1092CB64FCD02DB5CB8756299F984CF1884BBC53D94D671BB1122F554157867330C076E1109778FABC9FE2036C1A01A5854832D3B903CD2378314B3E21259217683084D585911D747C5399A3C004C9989DD08AAC3F1BFB6D6C638B7730E818DB6DFCCB5B2A699C3BC676665056B4BB159CFD686CFF7734DC35FB007A0CD68201E9A17D64C0731FE9B8F080FDEF65A10C032B62821F8FD0016DCEA139246C1BD7660ACE1AC0FA5158436B2C667836445A0177A767398F74C0E458C661683F712E0A75BA05FB6980C8407C1E24EC3A8E7A2F805590AF247BBF14202972E24F190F44F9DA3A88B9A2CB778C0B9094774014139B71740DDCAC9D25AC0C5096140E4BDB3375A84498C434F9468C5716AFDCF5E005E1FCE36BDF08E43584AFC85FB42ED8E5682F70985F78E05272C12F5C2DDD82E1A647D6492944D70C88204F3140834CC8217828D7AAA6F06D11E708BFC410A08D2F971A145238AEF4B34834AA29AB303552EA265DCF61174E240CC8198B3A3F50FF59504EEF3637504321390EB1CB599A90FDA211188D46ADC95B8DE37BA4EBA5A18A7C578AB7E8044A1B2BB1AF2C63A4515F43B06C7F8745AC5F2F9AEEF142B72531884C981C294C24172BBF2F03688881977E7739508314033375804B9042680C98E35B3011B83AA5C6987E6B8A2DD0AEFD31E9E15B9D4A10EB039BB90E8841583B323181B886EF75FD26DEC4A1C8DFD06060410DF110C818C1D77F47E0A1A08C5228AD40681124FB390A77457FD15E3D8'
	$sHexData &= 'D1666A1595F514E08DE1A2D28174DB1DA6AD7DF1283DFA20679A19F5FC85429A1B160B9A7348EA5633317E4E912E0348F010B9C61E506303D1AF1C2FAA2400CDB074BE9CC885F34D95DAC44084310861E67293D45AC70824E45ADC28E09330101D047346FAC4F083B59F5884110D3883FFE438B57C0B050538301D42095E6807DC8AFB09F21340BF877E1601DF1283DA0076D8551FE77E61851A80825504B301AAAE63895B6D124FF3008100CB230A21134A07D168DABDB59736CDC28F1212A20086E99532F5C4ABACE191C08639B344DC837B01AEB293915034E7F110D2501910FD0B5E4111AAB2E81BFC7024223BB96C2AA42E320009FA88D8A12FFFF728AD040DF60084AA8EB5089553EF9246A7387596CEC82A301BAF72A50D530AB7354F0E02A0814FA89FC01E1EC105A28232F418F464690938E148380CCB8255653A3F8837ECC1048B0D31D5F571007C25091F83DAFF459D442A036DD2D02DF944E23DF2CC8B8020C0315A4BAD691783AB033BD8BD649038BC8D342071E4C4608DA18C4A13A5120CCFAB46D8D424EA0451458D1F59FEAE9908AFA28F85853A20CA20A2ED86C00A6904BAA825741A670D2E59AAEF4E00B1D44E0A9D456A5AAD6D00EF55D0AFF0A0F959A66353F837DF4F03BF3426AE08D75E0060EB7047A6FB1E5A60596047E546A475B3A95F43BFB72D4DE4EF19B9282B67852F783FB047571B9ADAB9AACB044D32BF13F92C0E06FF4040E663B017555009AC32AE856EF5EC7004110D87E6B776904F48182970A0C45D4A365FA37C7E728787B7F937708F8EFC7B36401A4F21D647559FD2A1C29C8B5419EFF0DA5F2C45612113D6F0775222890CA03305F05751F380C0507190AEB5E292221531BA944005F2E1D26A93C09753750317F1FE00C7220081060A813D2434F060F75B68D62694B64BF9F3E0C72B99D74A7EB2040409AA283515745F8944A6915DD3FE9270807C48B10E952B2268C105E581CB5876476F084AB1D8BD954EDF61100F72B5C3C2BC2890A2408FB007092EA60C308166A2062C30320E4E6C0EB8F80EAC8703FBAE86677175A104248043FB98799F7FEFEA5F458084CC1A03BF17C598BFBB6A3ED941A188B9A14DF9659834A7A4603DE80C71388F691891407F8FF5020025BF0ED9330035C037C00836C74FA5F5189A8CD69B35051EF06B1655B297F568B880E2384DAF3F889FE9559C406E655FCB71D54C3D9B0011052F6443F9779F4DD8B3DC58D43FF8B1D420089FDD3FE0F94E5FCFFD36A0AFFD721F811B7F6373B75F47D046A322A4612F07CD303F52D4A07FF7C7960D65B1AF22869C02429E8925A843DD87E5D8C5FF026CE8C03B3F088003288938BCB5E2B130E37866B354EEC88AF1F0C2A3CC6459B001A600BCB443998122328'
	$sHexData &= 'F082F00078CC23301C4B7A308A1D8B40466041A138BC42620C3BA887D6FE742294574F26C605BF92016A058C807D9B7E9EF641780F868CE813E416121E4290739BA09C505D29621D0CD44048502260B2BC84C25FF64243EBA35045D045EC72B6CE4430FCCE294277864257D425E0340424F6B91582C7C03C38573591F43DEC2EEAA11D5A759C0AEE1C08E0009E76B02D168D47D809D824FDF7D346B08C7166BFA6E2802F3990C7004D172092B5572BFE8D5744040C7CD7146458CDABFA1449CF180C9406A2A0EBA5E0909A830CA000C1B488CAA964B001E1D1DC21209FC6C32320EF363F0408AD54F8280E85FCF01C9512CE608C383B4EC00B2F339CC40840CDFEDDE8FF372950155591E846D6189801A84CB8287AD7CA3A81345E1E82D548E96BFD1F99780D64142C881BF45AAE198A77F78D4E073F72B1600683C6F1D1FE74744DE42038050CF859F88160163953255757C39482FB75368885F4288AF05CA4DECFBDF2905389BD194B1C8A3DB41A92744BFCCD038D130EBF98C81CE348AA6017DB9C101A4C9185B18D8C364FEFADD40C631F117290BD7F603B2C087648D7D445EE5386780406B31B0FDDE0E2849E3F5D4886E4F0F0616D8048C3B00157564F0188D39D3C203D4E23DB9D269D1EE18DD41E2AE4F75C9017098DE8F735E46CD20EDD3EEC5EC134E1AE02099D990720DCE877457F1892656383294ECD7368A28E0EAEC9484E90421323C62EC9F9E7121110EDEB1833C08A04181C398D991840E077D1C8331439770874268B92D2D1E2A977061AD4C596E23B474989540C2020C05348B84BE8A0518601954C952AE485C4D2FBD4F7AAC8C053210590910FD25F1804929193811418042BEC90949F1E5A2BA6B63B0A0F9C794474C8741F601C1901C00828E42702F1F3B0DED68D4A3F0283C038ED91C2D1D1FA3AC0E5258C7B4DB074565AA414D2FA89FF046A10EB130FB7067510F71960FC7D416A0AEDA3608BF850BFF75D589A571F103C2215A2E093DE403F178BD34F171C33C964CFEE806245CF18A21CD3567E7D2699E49904762A1F145E95604372DEC771934C72DBEF7123180D2366EB2575C7174C1A5C6A9C04CF5A69AF96066BDCF918301B8D700BCEBD6EE424141D9432564D9437BED2BB14053C1A6202DC4C641381FBDEC4433433F638FEDD8160D1332C0C390C09427F3FDAC13C14494446F8C720483BF072DDFC03F5645A6A461090DC8B4DEC0919E4A9E4E01E63A0FE970EC1E6058B340EEBC021C00B820070C42AD2AA08237FC821D3B1BFA02CAB2C0142D2D85DD8241732203F2E5B67466A601D8B7D88119370DE8BC35B44014CD7D0863DE1D20BE21E435C69391D0A00F64D140F4D066694854162A93749C8B8646C88B624D0A6C8422EE0681542F08'
	$sHexData &= '51E381025F1A2F1900956F1955A482186007596DC7A742702AA0F00A8475E6DAD324D1CDE128D55C8740676C144FD035DC8037DCCA838CBEB174C448722EC0C8EC20765DAE004E4C21454D68E8F72BF016FE9E940D754C7C7180020874C747FD0605C45A1181E19C428222483C4BAE10D411462E4C1B9640B0087505745C0C4C383D20DE57BCEDA255737A5DCCF9634592E6B7E020A4EAFEE1836B2B08BB728429045B077BA66EB03C7EB50E46636F2BABBFFDD83F92F7DB403F9EB338BFAEB2F3654365973DAE860C77212FA108CFB0EB60CEB142FF92DF97C904007AA0451D447264A5C85BA6851DE63C827AE9441D8C2C887DCE8965E741AA857BFC562D8EAEB0D5818CFC32E7D204191212546002B41144ADE6CBF610019AD93E21EBEE8D26480A667B645F1D42B152919D47EB4FB8D258EDC854F0A0783C7F9D1F0A8BDF4419AADDCB83B55D80F039381BB4A125C1A100E6981BC257A6F82E60546FE2DE46068DBBE6A7A6814C0E0E003D73B0E7C4D0849D5A67FE87F483BD77C443BCE7F3FD42023AD5CCF1C1C00CFF8F8EA95E033BC0F94DE085751758041D541CB17FEFFD3A403441F1C003F70403A6600FF6CFC33A475075334888B86A00BF10FBAA8017533E2C786DCD34C6F211F2D8822E0A33D9188119290662ECC1EFC7C04F334904C2420A423BC7BAFA5277EEE452C2408D6799AA7D028F60C2C1430A7799AA718341C382080837A9A4C245046695ED71CD210587F30225438FD0DA0725C34733CC79F490726F233803B606CE1837030CEDD6C916E6DD0B8B62D3BF7C8CEC82B108207788747A48A7CC6478B477C607049B850CF64FCDA28224F7A20D70E5C007E2B64B18E748BC64DC00CDCA938C8481B411F0C1418C8C8C8C81C202428C4C8E5E52C0A300134385A3BD20E100C3C40CDEC3D6044381AE546480D7F749C1F90E93F70538B5D0C56C88074784D46E8FC3C0F7972E800019300ECCEC8C98428101CA538233D395458A17A0CF2D13920245C640124D4C8A7796C2C2801441CF2FCA88C48096870EC24830C902410A3322503287C5B876250AC0B64DF04011C79C825AC0401B00035813C93709C143043545327100B3C914946AE172428304865649238343C02047225CF4C509C5216AB12231F4EB9413901467811D5D46A0A14060A106568DA0D6A315F1D9998E424207B8874A02FBEFC54CF0D1EDEB1B184E2335E1CF10E2E838B6EDF800CA4B4E090BF008C74B1E468146F19F70916D2BA5A0F4308ECC04362B15620D694C3FC51C830610C84DB0F8544304078183A0D3FBC2371D0F0F2E2E228414D6959CDA350B719D42AFD253C835A80431AF9879D5BC0CD00530C4C0C1097DF023A118CC0B500AD430DF29000A100960B3113B4D2BFC40F08822A'
	$sHexData &= 'BE34094FC740109EE7B76169D71ED78B5D1485DBDBDF3D13A868DF741820C753C29812BC41A428024A1366CF897E3EE5E0637D0BC892241FC37DDA7966D43AC0348D515019E68A4123058201E88090D0EBB8381781AAA8F67A168BCE1D221CC15BEEA712F2876354D22C33C0C80DC03A819F14016C096A8FEC50BA75017CAA4DF050A3858C0F13F0A468B21A11340E4E29F07B5329B5D29E758DE0439C009A843BFD5738F4577F41B7B0772866397DF876438D5EE6F0943256C08B0B9E1F416BFF15742C4783C34C3B84721ECFFD59AC57B70956FD3DBC768BC701AFEA036BC74CBA04D2EC4183844718D1DF21C30CE861407F4447C6690F895DB404BCC0DADAEA807192D932C03590D95AA50E8008C6E5D407C035146EE0E9C09F059916301AC4D4ECAE127A389D14D14FDA4A680589BF3042C266833C412ED4741755DA1B2FDE86402EE867199BBEA683382E75EFB0D1F893DC43356F18013AC21020FF40AEEE802C04CB85013CAD44342B7C84CD0E4498D8DC5843CA420CE0117643FA5E37E9D544294DBCCE2A297D24BE80A2B8D2B8BF4033304D1F461A3B487CEDBFD07F023B75BC75E646B4C48BCB15D5223EDDC34E1A3E8785882C6992ECD8AF42E6866B78EB4297914A12004343CBDA2F122303A7A0430B8808846938E40E02DF7874E1D2855FE24D08D21814029F703E010825041DC047E3820CC6980342F1C4016C30DF51017CE0B4407763F0DE23B80C548BCF12140624A7B9713B69A08A544C03361578421884242ABC506506BC6E388D50A55A350033F05A345C64AFB051A02E7C9275368BD150203C0368907F53B6B7C9155B98E9A02EC58B18E9CE9D98AF98892EAC1632AC19EE907F128C3CC0AAC87E79047531B46053ECC8DF7F3EF92117329B277FD81077351A707CDC1C975018C32DC09024ED3E8957015E90ECCF7111E09D81569E0628D38A21DE843E76518D465A30D110188B4CCAC8440006117F8E04F8BAF67647384C873BA072B6E3020F946ED6C1D54330707EF56754E40EE1E1F5086FC2202795E73152C21D471CD0805456565C0486F8B044C185FF789BE443EB48CFBB248CDDE37CC461A6403CD45C01B0C482A5867805489D6F17CEF4203E34034A7404F5F139F20E70013C64752823721CC2118600690F8CB9ED6FC05C50EB3DA7BDA52290DC75222475B4BA046149C02C6E2D134E2F7C297704897C88460823637708D4D3C52E5CC38DC0C694C05DD5BAF5E8F09C2F822BC6F34CD204BA74187C4E506BB029FF61881123884174DF70430B8E6A27897DAC7815E2221F70C7ECE4575499E3A48D45A410ABCAC4D110108942A5EE4D2412512957B03488F803837DC0E6D80B49AC2D5532145ECF0BEAA700EB6772B53F78AC04525DE002895DA03BD'
	$sHexData &= '8622926CE7B28327B18761764378DD657C34003507090871C45D845DC8BCA4C4D789A98C8909DC880C4E1633DCF028C6826B4CD4B548B7D1EFFA61075FF1F0246CE90459883FE11722D8D4ED90BF0A6F05648894D9CBF2BC88834F37F211C387E744083C00283E96EA8093DADEE87C85B23446BD7F4DEFE04A8B26080FC9690F0412395354C8B363D78789EEB4068C476B0E078BE11E68B36E8B7FA5F0C175E0A751883C2C28F099EEE2B10BFD1F8EB9F60F0E30C52EEFC32CC640A3E32F1766A0474044850B280DA8605474DACA67580EA9408668042CEB401CD7D902BADA86E53EB16BEC8B301220CEB0668453904DC0EA832DB960B84A6BA4A3F6A80AC8B297C9330E4319CC213D6E199D931E4D5085D5157E27E515CA6A074167BA038EB03C81048079BEBDCB3C6D32B460216A48283C30F9247871C1931D1AF3FE4CF9172964C9324499203D1C1FA946218A404B3C5A38805C983BE022B9266031834E20263C4124464792D7C58B84FB07F42CC14AE61258A210DFBFABD3C530757BEB841AC0B01353A62605D3421DF4CA256F261D857619103481602416465A0A4F4FE39C35134643A1078343B8608F9E08D01B9A45834342CC0853AD2C64B557B09AF6D2D709C15F9DC13208621371374BD8B423378F19CA369EC90CF2F3B7C8013A2E05A184B3DB941E1B947FEF193702C8CA1793527A5576C2D1C9C885CF2646593F088078C0834839D94563597E106D2E048987E3AD99803585D028624D7DD8E1D64933893E09B988D1020C44CE843C5C142C22B22B6C2815C2141615087C60A092F246C45EA61B30641DE16EB2B7C19230E112A830D9BF08C93C18180092C15F580779BBD33102F7C3914B9DF75C8CAEB0F2F78B571764CB904258B09AC1C39700844843A5BC1CC725AACA0D43E7087F9A92015920E6BB0042C696C18553568BEF7005D1700751211180987E6BB03815823203736A07BC0D7B1044D461A1D1C80BB450E93DB1CC60551E996812D5E13A11B05605C12582000EC5160D01A2E7804AC75EC3BD8B5303642413BDCC6201AD6B7B1938C19AED6E83948B7C9EAB0CD914670874A028D9619E8FA0BF448045150510BE8F7A8ECE4DCD26CBD78B94E24D140DD2BCA4E9A73579BA57CEEB5A820DC42C68941581A7A4DCC8876D4A8D408C370D7C850F0BD80031A609C944CAE7AF11210970647381281B12A7F193F56D406011C3A2CB56A1008FFAB0B10505AA39F2987623C48BD7CF8537D958800C284DB909D21D10F0308891190AE67A62A0F9F019769A6341A063B53B877313BA843E85E223035C86A10C3BF55D0781487290856A4F25C1A89384C4C544BD2C0D4513A2DFD4A30E2A080A8837DF801788F841EA72952A21028363771DB81A02745C51B05A6853B'
	$sHexData &= '4108FCAD101F81ECA1C077E860E58424D875F343E2028D32048889442F805F5288AEF6C1A8C90101B4DFE4C780C42F33C922C80424F947A99400668988B4AC0FDF2B61618C08C76C391AB3DFEF2FCEB1647407BE0C74EB5F2919001F8CC9E593CBEB4F18A4EB3F1772F9E4F2BCEB2F16D0EB1F15F5C3BA7CE4EB0F14FAB2003513018798C7F8CA61BD00B5FFBEA25E0B7BD7A2FCD320FC1E02762F35ACA18BD88D44243413F408982938BB47D093AEBA9A2E4013399003791A2854700339900388CC07343990D0DC6D12D05BDA6517FF3505F47EDDB423E81508515E4C236D483E1378A950789302ADAB1C10FC87485792896888A34EA138D12170382678DA2CA547D70446EA2C980587C16F456FAD2800E31E1816CFF7B314BE080CBA1C68070F7934A485B3305751027215741F40A17054DE8CA045B9EA5C545CA2A1A964F1FB4B3B853C28B1B384B39C99031B40480D6A4E2668A26EBA4F0C0A504DB02460822E77CB2B7930100F53CBD89E204C764DB3D0DF594138A2551D1AEE56445D51F45051536B2BAF85878B3D2BCF8BF54BA05B7645B0DB8D7301502D1E035F443B8BB4245D6BBFA23B082B0C3B2B1E04D056D550319C432896B40BD05F1056C503CB1868BCD1D4410803013849F87B33B6120C03410414D1FFD1F836702C9C1FDC8B7D702078F590D150163F0FD80172204C24F1B42015137727A1EF807C03800EA361C1D12F340977C362EA86467883C3180C46FF85C20AA0B9CAC1E9CA3C82C93DE4D1A19681B44C6A648E08765B5D91D02B64516F6052B9251A618BE484E7006244C14F18576C47A07B578D9018C67B964834CF6206FE30948DB0B4BF05824EAE28147D9D49BC10FA30670480710DA130074C1CBDA004FF894C142C95F8239C0B1A4CF58C24C2D4C0697E19308BE4299EBB444DC33F0C4CF045B8B03471D96DFC681C440DF44AB8941957A8AF031D50149194161239E084B52244502B4110CE948C494A85D9D95F08751AA15D7411513CD819A4B7B19490657082D2D41F8BF1C3ABA6B615561CD083E2FC6F7C24967C128B4876C1520105AA2D1507A3A4553B3F9546346A25FCC05D18B800C4BF172900717310FE1789522A043E129B510F0E1B565E8B30FC236C23CD28F4C63BF175EBC5348EC29F5F1F4FBC0C1C53BC718A290C84B0C5E51A87AD1769C1828B9D84E17F23C88B04CA03C98B1C8A30D28ACD1AFF1A91894DFC3BDA770609AC10D11A611B1E3B0ED10BC3408EB4EBE2406B87D1D0C7F78917193AA1770D3F0D953B83043B117F798F0A34886008577D010416FCC1793C8A8D1C7396341EBCFFFA770560CD37220D790FD8E45B05102A8C51688DD4328D5D84549E305756C6C58DD1C7C142048EDCF099BF44FC34260737AFF85817A1E'
	$sHexData &= '624220C5919E415827F6216082D814C2B6CB6082EDD01D5DA0D435DFA528F1B014B931F25F08D45F008E2088E11B81B8CDA2D69400D7F9918118A5F70EC0458E78759C33FE2D292E0C1E084D5F46043298EFC0553CB6F80018B013B419876246AFF99FF7B01725B1D1FBB5F04EAC2D0F8395F087425B7F406148642493456B905C8C2F8461C8943B3617411CE806B9A53105B4166B11D5B9FBAC7244E8BD9A37B8F07CDC114A0CC954743B3A5773288777735A136754E5C81F105E2394E0806B0E054805087139B15030222BF7F08609D621F02C39F982A452DBF51F96BA8695651112F028D4204EDE173832F5255FC2B5F5460B44055DF06A186105F3FD481E883093C8D04C19F03C3A490894A3F62B7811F331F3146C702773253F9A6D6068902C70642AAA7617152A55F57DC69A34A4A3FFE6016482E2A80F543D3D828BF5F918C0A19905CF890415E649F62A818BD242D64ECCDE0B9042B18059AEC2EC2625275E4460B8B3110D30B2E97A4A9176C816F5DC28182BE8D7578025239284DC4A60C24FCF88A47188843AF0303091EE7A8EC4A7A020C92CF093C0EAD8D225521231A2508B8988E80854AA3A18007EB2926E09857C365C217100ED8D94DDC7414AC02D3FFD0DABA6836DF09B40619A4B630261668250E642BB7FF5D18EDFE29BF8D14408B018D047FE83192D0980711F7402A46A1EA735F672A02ECBFBF3C1CF253C6C742FD4202452C639B3433D201962BC0D1107A18B55921C242D1BF4613C06CEC6475B502B49C00EC63AA5DF5AD4A2CB3B5027FD0147C2DBD8B466A461040B76D04CF1C185E5D50276ACF11B3155F4E043D13556251DF6457003F745EE1DCED3E0290902F98CF57AE28ED95A257FA8D47A5510323FA6D811DB88A615F2784634CC41FC1C208200D7223FA1580780925378D3EBF889DF8AEC0AA681F9FF053C921425DAC63E8C045B510FF309F7840C903924C6358C081A9401FEC9D9E2B90CA7D7D967E711CB88B1A0F858C129FC8C1C4EA2007459866A7CC07280A08B93AB03AE9C980588554022F7907461DC7BF6380AC2A190A802C31BE241F28E05EEBC92224028FA3094D4164A2441ED622B2D34D894A1B7E0E6C92E92104815FB03860AE1B4340CC90381D927FA542EC6C6E84751F4DC0831698375A544B6610525273D613C80F12DF0323154D9A26AC074510055681433F65401A35556402420E1232494242B58BD45591DF09B69A60AD63FF1F853422B43F18AA5BAF8DE5F16832B097A88456A809A546141D202397EA46CE5F0D902824439E1E5BB08B895EDFB917570B6B48C0B59F40118966620127B55E5B1837C3DF4F925200D78C0C45ADC3FF1650DE5A0F49310FF5F05E6A18C32A5440FF9A41A3D1D20813B4300C2A5F2CAB895B'
	$sHexData &= '0DAB295E560C9C07C824958141474747417CC85F4E188B76048D148AA4699AE51FBEDECE4A37AB1D990FC675FC36BA515051BA596A1876BFD3A82E10CAF00CD8B9A9F859471203E240828F1589C376CA893C5EC67F86598F1F58B3F496FC8B4522B4B492F45F8A8C447263B658F07C56B3DE04EC8D7B04CA03EA897D358915C1F1B191D99BF58907AB430C0D10E722DEAC14998D4B98862CC56A129B7693782EE3763E31D5B6925E9143098BC3101C84B8409D70AB89D5815F9883E80CC3BF75601B85D93DBFA8343A60BF77B6F4AE907792FE448B4EFC2D23C764435E0BF8FCA90AE629948DE45FD488478A1FB638395E5855CFDEDE4DA5732380549E0242426F4C0756AE0C5ED76307628055B1BF5E6055634C9AE35672A91C5E064646321068F2B0411F6306132179934CB990AA400B1D547DAD8ADF7F4848189AAD02833F01C234C0501E3730022788B7C10803550C6D16B20CB0B452B68EA20EDB22A2B3891F19FF123F8CCF2606D15C750EDBD67605874A0C048803B39098FC1F7FBDAF4201AC3C5F8833D23C61380069871D24CC08390A142612258C47858F3226D538025C79F06069212761C46D527409124D1456BA2046B08053AC7900631CB17B0DC07877A6E41BDC48230F9F0D60348E8885832D01B9AECAC073B35DD8A30F92BE4080C31FB6FF6E153012543FE3182E0203410445058C0BE7E114358068C61EA08631AA2DCE0162180BDBE58201831A65FFC1881B461F082DAF1509D3012818D68A6114E60059060BED9B2F23BF1CCDA41E551F0D16CD5E5A4D0389481DD44F444B6D132D5F530F6165A21FE86A0877A26C0D44D4CB1A540C54AC5F7B567D4903511C577F5F08C809664933C0433151C18510A0590563058C7E421891C7304C4C254231A940613EC17FC8B78257516AE113D828871C72DCE0E430189700CB9270175C02C7B80929352345F99FB49A2677BF647D2CADA894B1C04806AAFF0435464762BF5FBF330E6D111F8079CA2B84354604AA9FA574D0199EC10162187CB4A31023FFD3242C021F94143458255E6C9482AEC936C79F32368018E1541AA9866D08371824AF113F64304D009E19CACF222B00F59CC6470C070A6A104E19D7BEA1266C2E04145F25CC120FC747690C65AC548D141F843306373FEC4204003B2A57505132608E09934EA41C12BE66EC5E545336F8428B3958F5372F045F045357D4DC8BD0B9C671448B460F1903CC3FCE92736286B557E6133E3F998C86B50D2C6E26205F206F46EACB3F6466E450C80118266C25422087094C5F1E600634574913669041805200D7FB21561562BF3E2999A264C7ECCA4A232395CCD0C8C4171002182C373A00865821B288B72156BCD1D001E53321744DC7CC4D1FD09F97412AC8C9C853D'
	$sHexData &= '82336E167BB1D75891D91D94B23C35615C784B70F73833CEC75186A301FC4C661F32D3B8B8BCFD63A69AC906515217334C29FD06CBFC845882B053FC0017215C8CCD03C48EEC2CCDFC0C7EC0DCB808CC0C0BFA94C1712DFCCCC4B0D2339C4BF1775207221DE9A6A5F48110601BF012274021EFDF94C2A95A714404140415C17AE12110B9FC032C82083C4C8CC5CC9800CD0C0C0CC90E4A9C0C0FF6B7820A7D02CBBFE91215562E5F087C29217C07F0318E1059DFF51515C2B551C10E659BF01A9E402DF6409D829237BA07D0C1A2A601085AE84B5903A420751C05327858BDE7E7408B8E42ADCCC5F3D929CA03DB7CC14B53AB4CE4B14AB8DD302AB5B5EC44064E131D5E09FE01A0D5C48AB2CC20560C1563283EF82F34D6805BE82CE2B55256395BC0BADB804ACB31F951CF82B78397108745C306104CAB71698469EC60A2C1D3481B0669E7F36140F1146142438C70E54A591CF372814B82C869585BB6B56B9D1AA5A6243FF8434AA35ACEF060846D3344DAB46F442464246F2CCD24E42B5F54642662930A5463835F54678111B49BFCEDC0CF782083F29E83B402A4F979E0646460219AB102B7FB41A750A8BC1FB240F910A5FBFD0DA1E0A1A4B75F85D08E80394BAFFFB4B042B0BBFFF576CA174763D5D74D1050F87923A6BF82C1B25FDD381FF012B8D4723003BC74BE3A4F10F46C150DF74040047E0E2E03555A23BD0FCEB179B5A2857F070B4EE47429256CE900EABEE550603C7A1644BF7E2C5E67304FF33E06C9C38300303420164D0D49978DFC6210A88CFFD5C113C5F5410A19D811FFE081003B6851F3F1EE15E80FD6D6C813F3670078C3FF957D710B4A3790CCA379CA30181465A3F44750318841ED8385B157AC58B94080A1126859836462E842E1326AE165388647CA3063B2BD72BCF28C0093860DCA4C46E4824DCD88681A8782030EC8C3F70D1A009EF7619D1B819D1EA2BC27C0A19F6429606A242C684E4885A03C01F378BD8C3BA5627D2DC1B0C6D7D6C33E8A545C6318A822389433EC34D6B20E14FEF3BF2763A8D349F565CEC2711CB57C67DF4030EC930372AD82B428718267AB61D5065C30CB789323654E8C3663E3BD812BCFF2527AA11DFD27CA51989509F56062E5625C9493049C77F413BC1E60256F6573ED5B4E8E1C88D035FA01456699F3F02D349AC7F1D2C888FD151CB738A46669607D2496E1C709CE92446C07FDFC090D2B4CF7547A77245409AFE577F6C439ABC7296932449920144C0808991028482233FFFF52F02ABFF0189820CF9741403418D8A88C4034A7F6529C0BD40863F644DECB02B141A082FD8311E20ECD44510BDE40CE82E21A2C6BCC009B024861A90ABB8D6C04272B4376E23A1DEFA9F1F5DD052838254B489B7D2C40B82B6'
	$sHexData &= '8C839FAB263152C00234CC9F83C125A2900697A810616153E89CE02881D16CA0897151A2DEDB4A0F8848BC749C80C7830C6752C99526D3038461369289D803EF370DFB0F92205DD07C04B6455825968D736475D4B8180C22DF2A31DE5BD38CBA94A8C43AAC895904A005304206792219EB7E63611E177DE0020F84F112873347098908B6D9A99DA25AA0ACA42F53416A03D5C9087A22B50A5788E075985C83DA53F63691BA20D443AFE384B5F81F6430815F0529BB147040DB08C643E452B934430343434AF9FF0F4DDC894B6C8973705389594C8B4948F2565241D4092E0A4F13A800D60B75AD1A89901015AF10D42ED5DF76C628419D90FE65501FE20435009FB098042CFF22E40507FF657054016816BFA0FFA614FA75F95433F6F2C42C8D0E48462B2DEA703D807D0CDB746B6484C2FAB0747DCA6CE3402900BC0718002D61F501584F4C787DA2D5C6E09A5710DFC90AD2406A202526517373EC2B01736B0F20C608B863C747DFF77B0561EB72D4037412E10C0A0275BD0B90B9DA4B0A8775E8A2E3542D3D32C0F556BDEA42B4B98FF8604F044D0129A19CB7E86E5223E4B20425A183E0FDEE017423080FB48B8F8F08D7C82F89BB1BDCB00155B4BE02D079208D77789B99BA825E83BF6402A934C91244664050119C23A405061DA4161A487A74423AEAF90DEDB788897DBA96F604908087B1414C03A904A6DD9B8E1684E4116B51A5A8EB14BF39BF6A316311DF7522E90D9F65464CC048AAA7A9800B93A8134E8DBE040F891A72724FCF357D6C1D1F054A3C55E4C1246ADF65F04CEA3C28661857047251DF704F0A2626F56C8B7770E191BF908AC3D6C531386C297CCBF20A507BF954186C23702D0533070834228CA30096321F5362044E6C89D95715385293A002F63768DEC704905B78722DBF56DEC2CD7F17B784D8186F187E96698B03C11A3BDDF04325A242C8703F6637A904D4D13F0B0221417F110C10C86660C33FA14A00C880BF867551C866A0C8E216B5E83FD91305A1A6CC5FDC90BC0090CC160C4A109746DFB501585DDDFE2B0646971E9A3A50D9EE1C35FCA2034C76D1F1565123161129C83E5FA711EA26BF3F502CEB0466F09F465C00701927F01215B6DF2105C950A57F670C585123DF5F230FA450F49C009C52D62A2AA025023484BC3F673031B038B06243E5003D0C10DF508906B42624B86DA303095283BFB708B9820BDF3F5041D0015463194BC16A20083FC60047F505BC1138017D85A586551FCF0192B5020F43A53A9610F8BF80853A203C035EFCEFAD04F03F41103BC772252BC79E42D0D44D9B44E5CA7952511C6CAD4809FF9A45ADB2D75F67C205E4087F8C48E54A503C398B71EB12D40572F866219041AE3F5BF8C0106490F87F3CB3BBD164A'
	$sHexData &= '1828E89141D4A5037B732B9616690A7B62E415E2031F32BC6A93D89D7D4833BD76500AD1388EAC4C330E2024C1A3F1E3C7608501961398BD1085E1C1E3411E8E6274817E3A61940F24A4A740DA59B0114D410DFF364BDBB356A7A9E8700A1A8AB3F577F416F29D8CA56B0BC0AE134745FE85210500CB3E04681895FFD9F1B0F5957254972040AC34AEA172B343E0A930B00181E527C740F6670E0060A876EF52F9F070AB80951A1C8C819156AD83F83F811726F80F664437400A0C28BC3860714930E0052DF13144062E90C94C2FB120CA400BAF0DFF0930700BF155F2BC35E48DBD250125BF194EB9E8B9446402416D6BDF401ECB0FF276139405CEAD8777A9E99602B5D6E73731C2A98F2E1A3240BDD5B5F29ECB632E5C2735003344AFA124B56691C9A1036255EB9F1412CEDC5BF10C2457070BA5B75CAC4FDA0067835086159038AC5D07102B0BF48883DFBC581DF51104A89066DA837C80884F8890C50C35CD7F1B3260451C31F4505B0512DE80441DFC5B646A360EC42757FA251292C437FD737846D3970721BB6D1D9B402B77011A4043496C18295AE03E7C9415FD1EE5F56564E4ED173278D4218F42D9A3618C6186E0666B4106A1B1885914C5020C69858588CF79F9A604D127EAB896F160670349FC2AE58DDA29EA4901F02201A435832134318DCDF9F1058B52D3341B39FFBC1600FA19FC23BF07415A9066C86B08BC84DF59A202D425D5F75C440083F2878600123C53C11B170209F33D2F5C3068322EE7FDE52A30867E04F1B460C0B6AA351C7204A511FBFB9B4D586BBDF0D22082C2C27D0A0875E0B4B2C011C12841F1DBABB895F1A09895E147E4162389BD82C7F83CB07426D68816C47D8DE7025EABB3A003DFF247605C40807C814108929748AA380800B81192F235540408D4A10BB7680890E39AD592178DD26361D85022C0A7FFF030E967C5E10FF16370480E15714B89A5E82A88000DC31C44B03184C0283FA60A38D5F42075648340802023C201B650F5181ED84DB3835169E403BD3CFE8555B0E08093BFFDD9102182ED610EE840E6D1FDB8B5814771422575650013154262AC41AFF4E33D965FE53FA1CF3041E4B3B3370F15351E60831255466A8E5915F72C1D47C10722741531F6914A6569108A204834F7FBB758DC85E8304BB3FFD68458FE49801D98A084084847CA414B2F9AFE90CD2BA81B6F3C0644AE16834A39F283D3C4A4C7F9F7BE04B6D74A8149E4D1B229F03BFE9688DCC89C2A14E367E7FAB100214360B68D1554581408250538DA472B9754D4E7E2CAD41175F5021A942489F3F987FC8D643486F606D2A91BCDF67AD3B6CD9E1006E0ACFA8606651B11BF2683443EA203B9C991AD08DC077DF56CFC00CE9A8F08B010710DBC1063D0407'
	$sHexData &= '3B164804A47860508A6C3E39FCAEDE6A61865BB8CE0E90DACD904A464800063E02E80ECC3F46400FA89921B596FF1C441238279D3443B2536E1E03108DBC19D2C40A480403CF0F5997D7213849FE0F0F0513AD174F3AFC4B694A0686DF5C909921D5215FDF5C2B532407680D70B8FCC904322010D40420934C8090C9C941C8018090779DB456FF57BC270885D67BACCACF3DC4D58266B4845F07FF26688205CC7E38635F5F41800507837E647429BAA3FBC16C442C500CB90F66F1D5AB17A615FF764C13D8437905B80C259A2C5ED63FD4903E94331204E526F08C6128AAEA0BF054400B45107505A4048DD96ADD6B8D0412CEFF779BEC40F60DC194088B1EA05BD42EA047487E3E60AA93942FDDA4D260F6DB264F4015A88944169247021E18C00F5FB809AC8A1BBF333E38E41410060355140C0A25AC7013451836B40CA71EBC153E3614D9733CC210BC4FEE6A8D5C50CDFC6DF1ED403BA4451C8B5E0CA210207F35F017908D463C39031456548B4E502BD155C4DDD4890B4AD1FA89C02C0181AD0BF0564A76440C32034FEB890F3E446A6050830FAC0257C2058A14EB234007C19E1A78FE640D4B998005859F82C803B91A1C8BC72000DF50B00B2BFF161C8061F06F5702751A837D140175D66EBF247C0A360CA0C3FEC373B8FB83D0FFEB0614200B720C13031AB75BF84EC30BC1C094C6038405561394C130C51B33A40465455D18F6C4C8F030CFEE5C13345270A81400FF4EF7285C0DD74C3D0C135872C13F48216490379F68383454700FEA8B431C6F238B53043254AAB4508A71EC17FC7C51AB24D0533202BA02890A668BDDE07A6826987AFCA4750AB8D860E839771F1C8D43C895E6E97006534B0E8B430878D3CE435E3824FF734CB7C2AF2EFB0F85C20148934D5CA580D596EE6D35D07CD48F79A3DC6846A64E10B83FC7105E02667B409193D24DE98845D0121D2AFAB69BD2C41906881408C6440093A58DECEB136637A536921E0CC013024B09388C2C0ED86DF703284B388D755A068D550C06621BE73D34EE06EC1C01E8B06496B8520817341ECBB0BCF8DBD9BB7F490F8FD6104C3984DB85872FB85DD19DA48A48CCFB2BF87A863AB7925C42F82FB52BB0846D5FF440B0043AA44F32189C2BB710A4BD3B3C3810FFC75E04B85F4A40F0C10F8291C400064A09C97952B74C142D69DD8BE006E3C091902BF103BEF4DE096E7E248B3D36E89FAF8780FFEE0FBE440EFF4EF3083C054E6D817D52EBE8D8A0EB8A9403AC718BB6E1888D66BEDB97D4BEA563305EEF97DAF966E8845591913F1CEBCDD4D0D9118230128D145036EC84151E05786E8B06BC501C0BEA17D8F4F8B825C7740B7C8E1B9D6E285210663DC3FFBB2626FAE5430946673107F86FEFFE3908732A6AD'
	$sHexData &= 'F7406663979FE751F60338DB3F6B3C94C428300FE2EFBB08689D64A38906304D557D7A76A616575D4AEDFE015C5F8993BC3753E8B5EC00A6CBC9B56137440B866A000861AF7A7D4894650B20A4B70AD5AB04818543646E44EF46A6EC13ED1F9CEDA09D9C17650E20865D75D1A0B2851A224C3677F2038484830FDC69AB580E100FAFE5F697830C17320E72C823082476D5451EA22CE35244EE201A1BD38F36906530A28F04057DAC907E8D0834E385C33F05786510D01FB888E0F24442C965B5FFA9100DC68C93AF9F13CAF9377FC06DCD0DA3C103DB0A346E449AC801E9F36F0787B767E36C37107EC00FBC275D8D5755ACD8B9C96DEDF5DD4B62BD874147453D96EB11CC2A466427522D401C36D215A0139F274165B175004BD87C1285B6512B501B45C013F73B07F3D4908C1A37059C31F6CAC901B04DF68A8F8082FE595744E7E3820977CF9070F807E402B74837C476F1389C022FCD5CC03C70A4AD8AA241B29E850A17034BF68993680892A3FF944E922AE01F0B73605BC4797E74F544602F042110D8902BA47388B18FF6EAFA682143B5F5016280F420C102BDAD1FB50B0E6F65352EB224204752434226574C9AC761B10168244126A011A96C09003C2528D288895A7035493A903BF9FE507F98CDF84E905023E8E8520C18CDDD78C2F7502A1B7BC8C04A8F01C409EF1CFCA18A22CC30C3382ACD1587B240229AB29B5F832642B44445D0C1E40A8B0855B6C201CC5149F108EA1C4BF16035D1456EC259C14860684DE6AD7343AC447910A479806FBE75108394F3873038908D80C31029E5826342260D3B73B541099390818721877047676122AA03484205346C09EFE9F110B8055244EB27415F6C2017407837CDCB6ACC8AE34D716EEE9F606F0B4CECD0458372F827D9B182898742A038100E76CCC3C8426BD4CB57BDB1CF82CE676143A7BC8AE8731F82801D3A39D3024F201207DF72937049410761E2BCA06A73BC081B84E4ACB482128851E0A1303F8368EBE89131FCE725EDF414FA40AC2941F6929833CC34631108B464E6067B88008885D8C3014C6C34E7C4F2BFA32D1FF4024ED1BC0C260E2670801DD8D05CF740E753AC799F4C2EB65A1FD3B4DD2E0033C037436F6C336176CE32DC117B614D8CCE01AE1494036CE15354D80CF2F0D9C3326E2201F1E3600E340A0798BB1814F3D1C85CC0C8A37F818037D0CC61C23287451C0535F0677C30ABF6E46AE101035C310ABF6C3DE5E0646A2F3047A702829CC18E93F27206E35CE4DAEB82B302B46657F7372D19E28242A30204646CA0BC5BB184228221B4628729C8A45204CA4B85F94F624B415403D0E0C3C62B4B4BB5B9F8BD12EA1A950100C5A3B9A24FC33F04C8B4A2C6E4F3BF97307EF855FA926B2C38B4220'
	$sHexData &= '3B30F6423C28E2260B608B72386ECB14DFE242F03BF776E41654DADFB3810BCE5FF0422C8930081CC025982DD8CA0418ED68B65AAB5B7FD1E2BF2D29E07335588B305B42B7CD09F80C3B30763E17F4740C084EFE74BA7005B806E06029AC644280015C5B360869AEA0296C2844AC22CF80073CB4C644C29DB187FB5A4D3FA2BADDE3AB9284EAF6A23CB12ADC7EDA1CDA5DD3750B6A33C05B913151693838C03047164A588587101D913B72A1154E5FF018663E5E632C28201D0C7E0AFFFF2D6C5C728BD92BD8D1FB83FB20726781FBDDBF2B5E687305DE1BEB11197F0F8339EE621900632DB690A6803500BDA1D6BC6847F8007836E7407B7491B2FCEB1F7A10336C17B1DC1A3AB44044095702A38D1FF803DB5370C240E594C0F453C755F83AC77B9C0E32A47608205D037B54A0FCB6C7EA10F141E2600228264608992ACDC2460C1CE6B0569BF6DD1E2CEB2565562E853B9813D266484AD442BC15AE535B4A61D494BA82A8BE97890D5D194BD98D43EDF40B3AE5D952534E4AC801C223C303063CCD0B70029750325EC1C1A8B45E225CC25B3FB8BEC0C15C016F744E8F549ABE620A8941EB0D682C1C008F949D0C0E24FE27964C3095569341860D81FB1C112C1F19649010203083663CFE048DB050F5CD3483843D0681FF31BDC55685081F1FC49096B45E181FBD288854DF6A24C42A96A89F5F1502C99E9F691071D0804E22AD95EA24C6A2A72A2027B07F00014A5A8922A5BF2E6200E46970B3040704A4D7520D047074C5B022E4081F50BA8814B5E5DFA1364A06081F6ED14001FFFE8B09F827C5578D7E8DBE1197A5070B0F308489B83B03B0D033C0B9B60E6BBF90B82D5D1C6D07CB8D92838DBFB831D9BAE27DEB589960462A18DFAD60440C6B074BE482B788DF7D1F441FD416833E1F8BC1C3551058257F0556C900947F1CA0B4169F3B07814B29089A9F19BF61059FA13B3775ED7C09A139FFFFD320309A0C9F999089A2B7F81249287826F8EBB41781316874770105042643BF869B7B1F244D0895F0E670B20405045CA30D8F2025423E088D4508F44280441F452F554060547FBF13FA1E8DBFAD8DAD687A895F1F3F884014D21EDFE216B008E3BF4372488B7E900A82E54095FF0CA26B55DF9F47858015DFFF1A055C0CE88A50047A0980B9041C942E83568A43C003B609215758C01F6904300A08910B5855C5CC3FAC8A54517F3F86182133BFD0DC82189580850DB6B83AA50171E47FD52860551F428E1802BFF0F086211458947D017432EE70069D10A7C64095785052102A0BD8084C50F93A071B2A4DC7443F488416B0D86B3992C086006901487255BF326094BC4E7F6A18ED863A25AC1C95BC4160093E1CA140170467045C091D3A4F1A07E4D7AF0E7414BA020'
	$sHexData &= 'FE08D5EB064A7AC14000153B2F6FAB6AA11AFCC5322A07D96EF3750867E146C26918474B05E88E851D7AB7104387EE810837E78DC025805582390AEE85384F7AD22233E74E3D0539750AABDCED1A31172091676C2CE906870A3FBA518089063485585BF48D83002E40CB7289960702B23200616C941CE01EF963468C77F6A706F080C247D1DB9FC7413C31483072F0DD2F90893B4D076D307982D6B144B179501BF0C4851E823E5CEDC7D20B01C441F17215245382119BFEBBC97710F666C785E84C40C495F6A90AC4A8E4080909C80221F924CE70290076AB0080784880ABF7EA780410DBF1F45684844DFBECA20C3A0A7D0D00D7A2A95D2D0CA5EA9492005C3C35FA9ACD3D47F4DF70C328080036E2D875DFF201CC0A455A53F3F41A18055DF01C8D0A47F1869A380C9161F024D9A3C74F27F00D228C0E41D0081E41D3F6AE63F30E503DA8B450802A403897D081B002E01170722750958A40B17AA441C5AFF9F01A168C01F56B5A022BF7F811C45029F94A52A005C42DB668B48807E9FDF0188042C02BFBF007C66A17F89450C2E6D02D68B7B516DB940C0DFB81F17722107E0DCD8A6157221D4BFA5080484F565891AD43ABF58A801A406C3FB095855239F709F2632C913192F045C83A64465907D0B2A01094FBA443984CCC3512A902E4E0EB4E4E048C321E1E2DE8876D02A8C49E05B5F894E6793982C00F620506A04BDAC88E45B43D29063C06E7E81FEB9C63108181B56732F05C21A30D8B91F247E81F2B801001D570F45C6AC04F0C51FC82BCEDE72055ED278696013B94E2BC840FDAD96EC82776403C0EBDF6520E09E554DA4C0C932A980C6AB0239906F943F2D9A025AF326015836E30D1C9DA068FC07EB19EE13138654F68123E53FB81F3478DBFF8D14BDCB048D3C1A05D28868E40274A14806CBAD3C96FD3B9972B2B7F43BCF77358D348DFA6CF7217395D8504DC72B45FC928A50502672A46E841C8485561423696FA1EB4168BDC77D0649DB55C00C06772BF903F8B8B0F675F0533B56EE1F91FEC71337097324C04B721040C0C11213D1DB58C1CE5BE602E01E013D616BD83D40E006F1CA07EC589388143F6356D3A0C1421447E020AF89D1D134A2E04DF45DD22641F455F88C2B8B05F0D3C2033D8BF27CF44F0CA20C72073945F0C3F5D5EB0F83AF03DBFE030F8943628BB9515B5745901D0BF0BA44974D1AF67483552CD74C07D1E163BB7F4C31F6E1A8170137155FDF0D050C018CC7A2F5323488A5D3078543E89D5942890D66CB5743041B2AC19917D4158534787018F1E082075070F2602D4202B1EFE50477F8926F806C744DAD32D0F504178D4AFF0DB9530A26E415D17F8AA54E5059063B0F030854B8F4F003C2F1D7263050130F32474AC48B389684E9'
	$sHexData &= '06AC755F20D3F001A42313D20F42CAE92369388756D925574C609922DB17013BB1AAAD7FA04EAC2E3F1F03192A119F241DA5B51F34C2FC5F590314030BEA8B30895A7643C297F84BC133746457BF4E1C066010E56EB735204A104000081C44CDBB56BCA160F1C3D3F73B3B75A3448B29AD4A005F80DD224EA103F6962B437D2DFD9738573BF0761107773104B90474CA4B4778018FC4EA14E89656D40D05236F57894B1CFCDAF51A1C43186B5E251C1E222C84F865D3780C01B6F357C30005DA66AA108C700140804E7833C822A10C9C9C717F094B6846DE314133C26905274893D0E4F2233A253581C28EB289435BDFF51A0CC4C08B3C824096E49461D404822E961DB0539500EB9402748410ADD3C2BE007B006E958B285A797444FE0898538D688298791C18AB24C077083B55F4756D50141A2B200E1188F89F14383F9014C70052085F837DE46C3C01144E3692127D74435BE38AF4D8E0753FAE3E2BDA698174B362041A027530C3744886C5A410E0CBE34DE12076091E6206D30FB00F0F1C0A55E41703362E085F33CD89305E54F26A0CBF6B262139147218266C152310C8094C7F5C4531165FD0722103CD1FCCC856722117C4C00CC844315FC0C01070C991D0C009628CE0BB5FE01EF192C8D056CA8E7A010B692931CCAA8AD44A2FA5158334C6A40FA222658CE5AB010D0672E8011A67AB250C3BB1C8782319E418EAC4305C448C0451EBC8EAC0AA04A3852BE42AC6FFC8442053F255555505CCC9800CC9C8C8C4C855C815C4C44C321072C4C4C8858C5C84C8C408C815E10F7C9F38125FA0C6F4B6DACF8A8B0372C8A9402BD8458C8B1399DC29D0576F3EC04027E4D88A5DD4E22E43D436E0C8220F8385A2A5A9C41A06FF07B8420CE57D1B3F26020CB964299AAA1238E0E65D52BBE718C00180DEDCEA7935DD2619B84849D6BA4A2E40CF6956C28B90C6A116703A4D1C88D95DD29DA42D8BCB1B8B444672F2252003439CEDB6DB4A4718BC4843184B288BF45146829D904E7590C1D3413184E4687CBB5BE440542DD4CEB3DB018D54652477FD7EE6690DD0F6ED46890D83EB0623A9AF2A84F7C0C7A9BB0C092CFCD003D601F310883BAC0A389109CC330B1B8953025A31C48C85C0C07291CF120B87172A5ACFE4190A001AFC541C13E1283F3B55E04F920E25330ADA00070E53B10C138BC5006E26EE302AC5900E199A2D0CA945878CA1082C9A95D3D242A8C8F13B28C78BEB7593B9124E43AB235A1A0DF8916CF94E03CEE38964A853EB47B0805460E35F36632A1AD4F02F8206CC5861DD7801F56A301FAA6A8D4E1F9F2B5055C07F018627731F6195BCD2643A8447A5DF032910DC7A6BC82C1B5F01966EFF6774070AF8868132CF52C0075271C6570419428E733D1D3'
	$sHexData &= '7520A50E43DBCC680150CFC2FA4767E9F001D576B89064DA58000736E794DC88983C01F6B60000781051B4FC073C94DA7DE7F8C0A0E021FAB0318941FDCAA13C25508CFA38A1948C55F9FA86A552D3F5F4A1527303F2940B583FB0124D3AA06045F03E475514DEF9D7FC1E702FB1211105885FF3F40A03852BF584525F01E9FAA05550ADF7FCD5A41A8FFBF93CFA9553F8A00880120F90501DF6B33000362F975D209B4412527F05F045C81056A35DB8F441DA1C1435E038B849E2B95CB73038BCBC72812B060B3BF2208200CBF75901CC31FB08A1138E91B227714568887CE8186290211040E338054AA22ED8D0845E0A1758108984A6603411904B414FA78DF640A0A01A702040492230334081818E511E3A70A29203F6BF1C0300E535FA524E02422B016901A1F0DE04FE0076CF043010D45F0B70025D5F1587E455730CEE54000825DD25BC08AE8EF51089E03F9A510D08B7DD4FF4780E8346FD0FF75EC7944F816F05B4F034D88270BB86DBB0093053C6CB5A4C43630E879700ECC9512F09A03482A4D165A030CC0D02D04FF6C02585148DF0AB8567171BFCE40F2579F6C30F101A3DA023B59089067524E0114AC06011B72C3CD024614DFFF08398A457F5006106E245FC0F242A29D37E44EEAD23F24C39F2444282AB45F06B0AAA0DFC22A00F1D89F5441ACEADFDF4F62155B9F9F012852486C0655072BA8A115DF019C81419E06F30C0862A4081F55AD50A3FF3F806D09609A447204E1B40603911FD52603F214080F93081FD042C5A85F1F58D50AADBF33008B2E03FFD10B2BA4DE90F13400E3FD949E8B0E1757422DDB191CE28C4C083806B4841EC4BF0801A8A16383DFB81F6F6964ADB8BEA0F2AAA837DC42BC3007280CFB2C5116F7C2CB68FBABE6837C310C00751442313CC7FB785000560841E048403ABA3480CD300F945B4B1DAB19D13F1B72212F12DF1010B8402117101AE8B6B1AABF1FA40E00231F2DC129749F056C04D070DE51300C43AA1E0138DB49DF01743615E1104A2E423E2845162DD5A2564DDFE980450920FF187C81319F523B511473237111801D013C44C00D0CEEF6666E616D4451024700A1112D298C0005803FC04F123A5A0CF13400E519DC944BC09CA3A23E188596E03E02549D33561102FF8E580B0EEF450C6A5399EC5FB4342442C8DE3BC1772B8BC0E02580DFD31F167600B803265652530F9D26112F1F1E5F3DFEEEF7F8294887F5BFF083CE0781FE2116E0B6EE7607BE0DEB52D1B811BD050CFB0F2B081C4D00602D2036A8C029D624FE010F92C1F7D90B1468ADF0CC29BBCAFA03233C5090CA8D42C29B7FAB84C30C1DEB13FC0D52A7192A006DD8DB310C87C177147A9F583CB8800385F09F3934E11A846E822D01B9203A07E11987'
	$sHexData &= '1358C1891FF3CFBA5CDB094A293F0057F8105697D6302C7F372BBD2266001F51537DC8DA69C3FC5EF4A0F51B393683FB087319410780111904CAF71B58792397C3B9C8076004F0B1F847C11E4099750A01A98D890F0ED6084066931E8952B5AA61D91F005B5400E3989A456806552D5F41305B2302423300030B05695CE512EED6CA72261B564A1B702BCA5442F9F19502564B3850575B00ABC26A36FB18B020461F9B08AB10C01B5601D62DBF7F578054111FBF1F372A057037BF44880411D00001ECC64411E6B78C80AB690D4B1F101D60026CBF5650B98AB7B00298A69C3E3EB1314826129F104541156059104E4CC82242568351C1CC411621C0159B8A22415130105152679A56610397DF942A01BC0190FF70030297895F0832507000312E1D3BC054E2F059F9772CDEFCCD0016B2621E575053897E10EC7A52871F965BFFD3806FB350DFDF83CB0F81FBFFE424272BBBFFFFBBFFAB86341FD80F42D8C311AE863092258577D510BE43111C0B5179061718601EDA505694A9040276095D070503032469C8D500D12BC6480154255031247F5F891E8BC6BBFF3560038113190DF0B481C315010F626D5FDE0A04040645422D0C029CA0D4433008780C53FA46052111084910F0E8E0B01653350C03C18B344D0C311F102CD88E3C0C03FE2418563C1457ABE8D29C1837149F9041AE01BF1010269509390FFF0F1C00061CC6A54301E00189069D1F8C29D420634912C93B019F6D1D650F312242624B6810A8010C95AB036F19400E9973CB030298A4520303199E9053758F12578B0B504E00236F490403CBC35F10C80DAB1F7D64404EC870B8FC1026999209D48090009009400105A20E5618108D2ABE53D6723C76C6741389427042A1F639A6604204481E54CB00C0570ACA1C2BCEA3690984AF4830405E890D787925D763AB417C188B92AAA6FE4D7A5C172BF28B411CD1FE1241020E90C22466510358CD3F51071C82129FFCC002C0531858E0BC7F91D5807E3E128700C0540D9D280200DE968CEB1357D6DDD6FBA8981C269EBA3D1B0802744B822AB018D4AB2968D80F48E5DBC6F857F875CC15A00E75F35FD45E6588591056FD6B1BF8C19F7D0C01C7C8C4F14F94884748C64705476AC93780184703C291C0C5FF3647D081DD56213BC6FE6FCB49C8AE384DDBFA10B01CAB45F9196E008B5BE34E4193E1185FD14E250D8055FF1F4C15580BACFFF3022B21534FEFC22A52A2791A24A7C25F6DB92D2C4EBAE31E3000E8A0D02DC13CE6278714AC0120388B4710E4391992381C0C2C109840203F03B9DB5A61C66A2C4E031FFB32C485032DE90D422A820B8D5D214E1C11B33F15F140081614ED82898A781456EF11DCE3C228855E27D9228211005F4182688997BFFE0B3556C'
	$sHexData &= '1E410351F2C3C306AE90FB709D3F2B41AF2BE9D178035B31CCE5E3D7ED94611B02AC31F6808AB6D133FD14D23551F57B589C1A9631BDB8E0CBC8B510C138B9F204A109A0528140E6015EAA55FFA117A30CE4514D4108B08061A9314057419C20376BF086D11A1E14D4A1A0E861F719F0485D2836DE01F9DB941607184D2695164C3B670440306F38D1348B0547F1FC951098C7F3F081A85B5401B7F026BA2B03F543548513F5E3F06543D85DA472A99A0903F95BB5121313F1EFF0429B056C70790AAC15A3F80014B1CDEDAE6E06F6A9DE75D8906ACA9C1602FB18FA036D67FBF2C8CF00239241C9C2B2C5C52E816FF8D58CDC411331C185A46A15D4BB823F19FB81684577A4505847B0B693904F2BE67130F6144F202D2601FA949FF9E4904EAB82349AEE93C3F5C58DB764D0C331F09D208ED3D59FD5F9A806DC7DCA59D9FAA5A1DABBF3F8A6DAD6408DF30B016270C514E7978540D1EF2623F05C38A085F1CFFC1E105051432D5B5BF0852ABE01A7F680C245B3F6E0081EE45497D9E01743545818812DE0AB9A44A5C4B5A90BCA4515C809C88925F6E284C0C910C2C1D19A2A4AE0D6524E13EBC00BE8E9B869B0D21A5B06E4D860F6B43CA2F53BE885B5B10525B27A85C905B47202AA93B74E0F08500E495547F6E58214380642C45C10367A037289F459554A83FA1196498ACCF180882282115531F585141C29F081A4A29C08D09342C72C9231659EA2C5C3C24830C2C24807E207A508F10B4F7832025156816259FA5145AA7122CB8A20E5825A5BEC03A10E8E13F8102AB623FDFA90117C8915C035F1105AB92C5BFDD244232DCDE08F02B0824DF40C1E203A98E1B45DD7E187E446C2ABC1BBC7EFF609029143CCD7F7456C9C0141F80B146A8389FBEAB4A1ED19F924CD0B1AA0B7F5F1AB40A523FFF418B918A9F42861AB49F5F1868D54C2D1F82854C355FCC3F24A762D05F2FEC26F0023921DC2E9C550312041F9F92433460BF934CB49A4904DFA951C8C45F022A712C1AFF1B54D25A4EFF297FF4D96051BF41082B41B0455276351FBB9F6EAD1AA4E9654805D5AA5F6D554C6DDFBF3FA4AD8AA997A3DE67AC454CC1541FC65460A2BF11CB773151C70BE5E0823B10BDFF1567833D4BE2A1B019051F07201052A3BF0A332B8590C4B3EA814853D71000FF20C17DA4A8025FBFCBD7E7C224282A3BD0CCFA813A4BDB0D89225DE9C403F509ACA5FF85E4B47ED4ED8B0F70E1447837BC2BD12BC1C088A449FE488CF20F86FB382477801DD7D1E856B8231130E0A912D40542395268904A0EC2A31280D5D13A202BACE938E4289DF8F8CFD32A047176DBB6EFD0D6EC623DF3BE11B43DC2945B10032C83C01E407ED50D59C0740B5033FB046307FA07037A0EF84CD4152D023CAC'
	$sHexData &= 'E1812A021C04D2F418464100E449530F0E4915642BC47294C47E01D95C8B309675F8740C5FEDC1783F8D34B18BD659B877314401B021F5BF0AA18812BFE4D602997F241F35040701613026230521A9199209A890DF18227148AC73109A4874A1D9A5C21F8D94798B43185F234001B0C9DD5F17368B58DF7F5048DA429F3F41A1A58999F2E83B28CC8932823B50107522021A58172A172BF1DE09212154F3E1834A0809FD0AA242A8DF1FAA8ADAB0BF7F5515B5C21E57CB7350851FC8C4C9149CD2CC56392F9AA69612615E14A35B2193E0B507AA18A82447859FD064082A8CC29FC0245E5109F1035418245FCAD0FFA20A58C9309F2CBA08ACBF876A4C5A7F507F95BC504562259F1789A734B80E3FE404D812962C81703184C712C577DF0C2C4B17099A011F18D1B0AA7FFF923C46E25B1F3FA74215011FDF88745804BE1F69309223968EA392FE2B1B2B31F7EE03D611924458C15EC3FFEAF8C743AA310872B7D68D421006C96F09D65E51524E541B239F8217DEF845C2891676AC470484220F4A61A5D86AE3229F249F12D0027C10C5394924D708D12E8D9F20DF8269557BBFFF9F35AD41213FBF68142D001F55E289421F8301FEBF21AACB8B5F64407F0AE96403BF6E06025550472735028CBFA2106A0B43BE026D10F3850B44C31F1E315EC6A3AB3435B98041D1DF1E42184083A165BFA7F11B8F55105FF91E343E8BFACE72212BB042D1808ED2EF19528D04708485555B78D36D50606207DFB014740461B2A82538D12A636D30BC578952D09E9BC2FE92843E1E0999ACF6B4780C57FD9EA0B76136661A47C9C203198E2D5114E84BD3CB0C0C96DC5E1F91614C611DC01C4023E303FFC4F9D23C4D64C0C236141FCCEE40E9C06D1803C6C6BA55D0C8F8CA435BDC5F5148F848BFDF88240C796EC86521840785337C92E6FA214440518F4CC446484F31692C11189FC001892841602C308D7E1212F62C80899861B02212F84BACE1E26DA2A2890951EB0B7883916E2FBD4DF008032E4A55AB1D8E06AB0C122992C308087F6EF9B490102EF05F40616C205B6B11646662A3C628904233A1FF4A4A341D33C05F82C211129EE4590642103F104846BE7F01FDFC94A8598B3AFF9FCC5A01712C8C859F57200314989858C52125F47FB1563510DFBFAD2A22447F3453AB4A1F34C56C74105B4503C17F38516A0C80017FAC822B623F1F11AB2A691F080532147F944FC2A252EB7EB96B121E0B5D0D848115437D4D828B8A818497D45701885F378B0E32118088E145CC247AE28A70558805107C89FC89BF0E0A42C9805F80C06A09481F05C209687F2FECA50E5030607F991C6124A740991C01AB26E1F5FF062C0254BF910938F1808565C248E06508C9147E0CAD800C44CB32B802109'
	$sHexData &= 'B97AF5F55012A01C6C38190A068DFBFACBA41611FBB81D501BFBF4DAB2E025FDFA2D6A4551FCD4088E2BF3D34D547201F08A9116C863620CFD1E9E2D0774B8BA8262011AC7303805BA9351DFF26A1F485D46811AC8B0E8962540D9D261EEA9F4021F5A51F9F96C28989E29E8808A390128CF4A50F066089FC4DF0E4E996F06BF0EC3F96B06402AB1C285D5439F818DD01C9290E5E0B8BD70398407CAA292480BF56C8C0C16DFAC88BAA47C6BF42C01FF81E8BD8BF018D520480624BF8468942FC8D58F3B0702010D8420B704C1575755304D15FB5E42A1057288344C387723B9E87A63801C0E8421212235291880819BF6AC44B15BF5F31629334F37F65849A427F3503AB9A1F7F89DB12026F0281925EFFC0569502361FFFD715B01A1FBFFFBAB029059FBF521500217F842218D47FBF2D622D0A3FDF5529C54BDF2B1EE5564C9BA51F1F818017B35F6A08FF1E401D581F2B2C0A1923485F03200E2C3FBB40A802BF9F3F15699156BF9F625583563F22795534FF2E9C2C2AD0089F8A42A322BFDF917C0090652C38E161322805430A060E48988123898FEFEB1108631FB4260213515BB511A51668DC1CDB6245C53BC72BF783C656EE547D0C0C620DA350F38449D2A75F340C078D400442563BD65A130585B69EF30656143821FFA2018BE83F7FB545DCD09F1F121627423F2CC4A2D31FFF023A5675BF9FB540C0317F3F625585845F04C5A88ABFDF38C10682C8C72BF0BB573304CF81001EC0F713EAD6C1070DC708C54C07C745ED6B45BF3FDF0784516D9F3EB90342E44CCA5E023B015583282C1F82A841211F1406F2B4FE2A602CAA1A3F0A022C0A5F1FD88D5717DFC158BF45F26E437F6F28A6810DD2F2B5DD86902A3D5F69C049608221ACE48A372E851A10B597FF291D2921B311220085633EC39F0D330CB85190BA82439613B76A9F945651282E561143F83DA4578F88FF3153FFD76763050E85C45774E2AC86700191DF1484D12C1F2A10F0227F6008BF53874C115F6A10C26E0C10C3F2206A28128450183F61078DA1737B9DAB6898296AC9F97F61084D7DE805024414000056D216C4E40137570C125CB456E65C020CA110519E403788CFDF002058021AA38197DF158554C19F9F086187117DC700334D7B1DED48C20C0A081010D81D616D4024E1199E61DAC0B8F3B6CC483EDF19424138C0DF08100AC22899501026CD0801187420A45202C2283E0D08AB0E9F1C011AD1FFD01290CD6F013F33D285FF74110A422F56C365D7C3FFF8DFAE04611054FF3851550951FF56FFC080150848F108D860F4715D02FFD0AB0BE14567026A9E770B720655B8543A327A1A058D455AA0FFD67C0AC45E2F3C2FC04EC17E01289037209F701818AA6473CB8091E851899C8060469B'
	$sHexData &= 'C60016B7DBFA171AE726D5C06C7DC9010616080F5D43C2A87B575E2A00A9DF9BE0584E5DC54054CAE46658B5907CE0194CDFB82A5611B77F500D4C34125F65886FAB179DDC8EECE000758EBCD8BFB071B2F48B1324023CFCA140C803C389AE78607C9578D570202C7C177F0E7611120D7F023BFE77FEF176072BF183DF00EB0E25F84C01475A2E403858268020C0FEC28C058D27F80FAE619744B7BA38501330B3011CDB67B7C270EE3680043A0CEC75271684CD2BCD421A3C74198B7D573C014DC201A6D320CAAFD3544683EA8B94440042518F1A8C1C5A4FD402A75EB96F8185C228184344EE441407E6E0DF25C03683F840743D68377C31EF7F0300FB0FB75418408B4C183852ADEF2949D8B866AA9BC175078FCAE4D4FFEB6583C6FF83D7FFEBC586D6D1CF4D4005DC6765A43BBE92D02C627530542C1A2097271EBA342E3819B6DAD9B50AC87B12F5A7EA5FC744182D0E4240680163EBDA43138215A0016ACC210960D34ACAE4B898433B302200BD674DB333A548572E5145CBD93A0B585C341639CEA2810154DCDB0624304967E730C34A67E0EA6B517142D27125AC50EF59E54B84AF14BFD133DBB454FE167A400FCF418955F8D1E9CBD4231A420C63448320AC0ADF3617813AC17F8E9C203B5DFC141E925C2C26458EB680ED103222BD4C1F5D48FF022B0186820A56153F3F8754335CDE65C2E36EC435E2FA02FF721050ADAB5C0BFE5A9F4214A05A107C00BE9C26B3CC8B79958CA215CA761B3C14C804388170C372124112539E02AB64FCEBEB11EB6B886B0846DD5F3A0B988ADF5141F26CA20806DC07E02318D863E18BD64B538F242FCE9462583B1C9C65DFDE0E0EAD14074618F56C1789CEC8F9288D5F14428750EFF059C08148C630F33B481E487010AA8A2BD65AFEAF104832663B06750C83C60283E9B442988AA2067F2BA0B03ADF5F54A6021DDF5902D6A40E6A10F2030AB1DA4FA83E4C00E38405A905385C6A84AE3E435858B54304995A2D9847DE893E010A6335CD406850A87DFD2C5E2733E3E162DF245D78D6B0F20A830C244004480CB6DA2932F1B76CFC01057CD07025050BB85193AD580A2DC2C1CA380EDB3FC528022B5F2BC6283970A08CD804D3773405E20A68B85FBCF6C20E45B00CF440205ED01AC0F05DA721C3D44D6A02082134F957706B58166803037FDCA7A8569215C8DF6462D2DC0112B416E06D49B651D21816164A18BD97DAC9A980CCC6348D5F03454B7558DCFF742A2EC04128890172A35D4878DF89498BA1BE8EE85367CD1152D882AE4C24DCF2CB8642771B9BDCD018CD2508CA8A20FB34050B43D6D862013232C82118D8C00805886ACE0780AA9417840A8A896E48B8C137C62A06970307A4DF6856044AEB11364BC04DBA12EB0'
	$sHexData &= '8A332424DB21B19B9A0DFDF0C875280015FF457F7EA809FA25C902A9CDEFA0076196F0810C1EF1F1203FAF846C0D91FCA6BCF2C5F031635801DC2890BC9A110B69A7FBDE843B101D8D1B8DB0C80704D2C16C34A0639C43F70D8187C2EA2D2F9D791EC06843D0D977170800C092A391F069EEF266209F30F10020B708DF6D1B700065D8B5F2CAC325F14042B3089315424D0881B22C1302FA2759747565F7204FA29EB000632C906560324BB7A5644DF19E485A29F710818D9126A0AE0361A33D079E31536ED53DB3242CC77576B92CB20CF877072D169680B0778E4C7032CCF4DE5D8473BC643436D040503D925A096431E7C8F90575193A8D419AB430E3982BF6830FB033892ECDC184DC4501241C2ED81F968C83013AF3715ADDC31E8008E4CD7DEE3C4899C6A9684CE0DDC57E51332D7E3048A5C8BF8AE837BB95FDDC77451C64FD73997DB853D8BBE95D00B81AF0E786FC0253D335C4BB1EA1C61473363B85E0A23C906B25EE16132C82017D3E5B252002DA146590DC46200D80981622A64C4E0C733A44B9A463309310B1A254D48FD90ABE8081F9F985845F2A8A9042392534CBF71F02E90269CB4B2C4008BE46540B48C8C13803C90028D5C03452053200458A955C906DF25AC0F0A207E9F4C8D1503F74AD1FE7D39471AEF6390CE751FC016609E9B461A5E0402750DE984318E71965F98CB9814D29F4FE184C50061813A910A887F7F4C8C12D23F132D85AA9CDB66983E90A1D00C85F4276690870A99857F4C79E78B75585AC945F43F0A0D9616C1815C74583B231E54258C40110E4B61023C9DF3DE45BE06E95E0453C9788BD0B80CE40E96EDC183F8F6ADC2331A3FAE89135574DC616901A451465157587AB0641FE9892A8975F79FB20135A5FA37C08C9207C41F72200C023D244BD0D35062D11CD6C614674218FD4AC6C1FA056C754409BD052D078CFF45CB8A638D58012BCE046CD1AD1FC1F90540D1EE58527827C69CCA5DD8EB0BF7CBA9378C3BC30F42B442C1E182C04121BCD07D9D2C366A82911B0EEC8D7026CC10D034E60C96A1109C9A9B13C0627DE03A2CF06EEB05838A1F0A14E8C1E205E832460041206B34E4A62E12CE405B05EED43A1994C6C8EE8C5389D60A7D2445E44C401C003E0EECDA5790D60F1213E589DBD12FFA0C24A731B4943DCC21D6544E2E240A3E8B574F07130430B0DF452AC72D21CED0C1E3102EE1D858FD3703DE895F044636EC08043825DF63185B8800AFF95CD23511EA04BE158C93B014A2E3A6AC7F3D81512539DF025F9BF80D85F926172BDA166FE316F1C2C1FB38E568684E9A3F2D70CADAF45C8682835E311AA5850406899E07B102D008F38FC25C810CF0C4D4C441A4E58FF0A5E6D282E4F2B49DE0C1EA3135F8B28A0431'
	$sHexData &= '8F02F0C55676D87512D25618970303C4C6EB83076B420C27A4C350CE005A0155B0438C839E147635652CB48A2B02490F2C8912162826F47ED486892B2ECCC297948B6E03C3152F060331A84C3FA427A0043F727307A5234D57D1AA92264D01016D8E8AC2589F7F14AA461412A554167E74592DFAF91A460703FC22D6B6A4211F66A5A9740C454E787DE8CDC82595031FC7C7C7C0D2524BE37AE417B180D3B39588D560600DECD06BB9A1C2DDB35A1C387C98122A92D1D91F03452CB18836D6B891AB9F2C8B0E57B814DC22F60837E00402A65023A824B16A0EBBA71EC95115BB5DE889D159A892ACC77FE4805499270982BCE001A1802FCAAA0C5FD594DC1A881318CD06021B961B81931FA8017912DFAB2950D1492CEA2AF7A4CF9F10A302231443F7D2D53CB0E927F83DAA0A3C1A41B9DBA54BCF4DB833F35CC7189145FE3C9E45344DFEFE7F7AFFEC0AC1E1573F4582EE5A703F51FC83BFEE25E85CB84EC74431FD185C69B80E3B723D90BA0D5C3A5FD7884017D653DE7EB8BB970F7619FB6CB0C8308CF7B5EA06180E8F2D3D01B5A704E0CBE7020A175480AB3203E4D900521407ABEC7FB0514678BACA319F2E9041AE5E8018D99A583C2852D97AB992A1E28AD763E8E0809902392907C00A15DC66A26990832A9CA26F1C781635E410A0F05827105795DE2AFC5D8278DF0440C1E0039C8A87416BE430B418A853378B490BC5483B132FA6E4E467C404FF75E8E0DCDAE20113DDE85097002C4DE81AC9B9EC156CDD5754E062819FA000C84420C085BC9007FC0CFC0C00BC2AE4924CADBC80D4AB38FF8B0278A88882A07C325E45811014DFBF121438881FDE80B8BAB9A975D6572B1350819F8655EA9FA439B96B3594780B75B921050C3BEB808B634540E5F495E4045CC6811E01028302A19F7CAF0FF27F3939108BCF21033BF275218165FB7D3266408D49184641E881B7474058C4F83475E5EB49678658B18A1E41C690539C39648C4AE42AE852549ACA73068D404046C640B993C4D3F2332C408B4B4C26401ECEF7E930D3E3796857F840D143890F8CCEF49C8152BAC6C5A5AFE920A871357FD184464A2A9DEA287F55307E2A4A188B520C09273D10CE34A875F49085882188558C9605E381285FD608F20C521ECE230FC059577DB6115F628BC35ED606F8B06FB736518D387A5106293DDC0606F469B5F21FCB7DF48BC8B857080C630C2131A112B5060533B458E8A5ED0BA9DA4E125283A05253B5529023CF6140A941A73F9E30B18A4DD58DAAA66823CC3F5123BA2809095652C01FA21187028E2B5D3C7EC39768A5D3AC374F34CEDDFC46D5D1FA9324DAC1EBDA81FB2ED4540C4A15B2846B4170AB8B3F438E2F458EAA1370528DC30F7C492B66634CE40414725F7F110'
	$sHexData &= '1B1891CA3A43AB9689B122B2C04312B040F8D095B2CEF3098C0E074DA2E0C0847A3E454E2710F263FFCEC2ADDF266570C8B4DF82C7DC84F126750274F1C218FD21F5ACB53E470CAA8DA33DA513BF421735DF0105B1785075491EC73B1BC34923FC15FCAE90500A59C1810C378C606FE5FC940D5E2BFE2F00CC87370D902424A3D30BAB0A1DEA2D316119FC333C0899117942642B54228D9799A41424138237BC628F5C73EDF5565618C7CE5A800B1A45F3A4B000C92E807530CC4922A9EF9674FE8D7A18E56519019EA51510C0A090EF85676BD5CC7926BD0E44F718D2570DFF4894BE96249234775563E056D2C6FEB06A36B25DF30DAC68A1BD088FF9F24B56F2D1F0CCFD06E25B8E127690148EA9F6D07F924B5424228E56C010AABBF5F73108B47209438E0A6A4A91E09D70F461608028C84C1E222DB37C0555830DAE41D1FEC46D46E09E086DB9D75C04710AB250E849CA4BB34C8D1E9FF84CD0B74E0ACDE8975EC1C11007FEB32E042185DEC6BCB2C81FB148A1827CEB7339A0F08A7E88BF8FFB248AC9B0E68E46BD12C20188C2F902AB703D752244968815E686A0C52515718E8F4650F56FDE4703EC0AD772E1AB43F3BF3762603BCBF019A982BF35652870920FE7B355374164E6BF62C51033788017B84958977571D248625F5D81711413FC8A04C1095120C4AD46C85175F922D26E49F170AC901D24317414135225ACB416758A116DD8F14BF9F921C85FA539F03508BCB10B1D99AF4C79E6184363B4D070A751F71569F6BCF02422D1D80FF9995380D3F6B55FC2C640C10041EEC6187326D44326F0C71C11CECC10C730C750A31D81AEE370E79187B2A546AB83E7DD790834C72FDEC2CFDEC103B969CB4EC830B42A82E1F861BC4A31F7338FF1000521942100800BFC9816EED3BFB74414A48404CA25FDF903608F44E1440FC6F480B3D07C856C0200A950C1050E606F147BB8D7F2C381C4154DBB8F89AD4C8241029B8315C31A4D4DFE5C710F0514DCCC2D82B4F83A19740C1F9CAFCF813B0E4242101DF1514D211F86F801146C991D211ED2D426226D48F014C186A910BA48E1370B788BB038A0C249D00874B256921DD969CB7893B3BF85D4D452E0814202BF0022418241FAD0C62491B0620B21294A6F0711F105CB836230A68F005B40D5676F05E497A4164C7767F204724571FCB35C8448656BB08682C1172388392864064B746B76A2BA09ACC3F3F42A43A101F7F212E2425F7670CF202617F73602870203C90F02B377B05B136102BF7EE5C6D0402DE8603D62B0F373AEC41BB412C7590BDE5BF6B499224090F84B8436A320709776A2F2659B9405805FFDFDC562060E40ADCD518003710EC7D4BE0C26402E8A2BD6100AA36E44BCDE30990A3595748CC465313'
	$sHexData &= '0DF0A8481CEDC869E4C286370ABC51568A40B84118BD490E05E5FE7CEC210611E606675DEF869267644F1FCB1632CF5A8379C02A5F2D330D81D4F3372BC30006B9418DD0CCF98638A053EC3B141CFF75DC45AF0278145C53B71C9FBA69BC405F9FE47540297FB788806B5A01BDC05E86AA7A77AD8B4E1AC9780244DAB903D2987E9F161975B9520E5E32C007B49C82EA48EEA2C8362058F0253F253F018B90030454C981829FDCCC8263056278DF331A022C8A4F0C5D166E052FF6994AA91A0AFF22755881537FE932948ADFFE0C12AB5B01D8F2321E407E19EE08018B5D105D47415079F430818580FB45145D27CA29662F432990DFBE1E84867E477344273BCA217784861FBA81796828A129217AE609000670D27F97A1434328E1F928B88E0766904EB8EBFC32D41AF4127232FF1F9418888541D06AEB32FD3D1A1AEDD0EF2DC345211D294B563D42A916F18BF169812A2A3081AC2E4F43E7009CD237805BA12148511E045174697DAD16FF0C0E46029EBB37F3C3824B1EDDB05F0C0131AD57162F475D1BA1D330C561DB4EE0142DC8A760D83C146DED4005682E3E4EFE598C4D0F587B18A2FC9D30E91A5865E6A6D2140C8621AD47A2A89F541E821C117020DB02D6C134B18C17B8D536A427A733C8151B3ABBCFD30C475F1A32C0FA07807C04E2D152F17CF820E8098FB4F6E2BC2214195B2F2E6CFDD6BFA2152BD00C0E469E9686010DEAC349E81C9E34F7D564DE49905DDF10D6D93BDA773156011208F60E27B40C923A18D38207AD834603105FFF171A0D4D12EBB37E703474F28BF3EB82158BF872072D01BAA11448CF0C1A9AF85F3934E0134E88EBAAFF5508B0C2DA8289B6C157500B0796EEC62C44135AFC84820BA904F614430A100F3CF84C6087A1806E04FCEB1808956005A642042A407C053B0703C23940A41BAB8B02FFC62A398B837DFC02F1591BC94310B67314BC0AC4AF91724D8B339945FC815F329419893B8BC30C76D944C553958E39A2A22E40679F24461023DF0083620BB27F3D4A5E28DF7391D96A7928C021E227281A0AC217549188EB60529C4300EBA2B84C74248815A03B783AA56269933234B92C5CBB4F25F8F0807822B67D303D0A8B730B7A9E40B83D460C2DBE0DC636C6535089A428E8A40B0800744A8BDF56C97C2A524728838B0610B8F7083B3235FD27DAA05AD024FF4CD8C7E7D316BEFC5C8BE2B00A6889BEFF0109A8203F4D06A60EDF18116C5D0A86407F35E8091BE5E17F9656D5563F1B35ACEA7F7FFFAA1084503FE16D0ED6E745BFE3500A26DFDF179418F12BF95751B7FE47694DD6025D1F2542FD096F8BF919A80280AD5EC3BF9FEE7014B4F48E146B022832C614C01DACB38957182E36E169AB365D678196A0F689D2EB1F286'
	$sHexData &= 'A02F8265E39A605C251D074342A704BCBC03708704923CB4FFFF0BF60A112423C4823C78B0C81F77927212C20583B75D79A02A365765E9C80359EC370C3B4C618E41B0100EFB42E0E897E086B59F3D0D5C38BC62C352DC7841E0A3F728C09046A4A16631CEAD5507A297915FF2B86505B31255F3F3F1F96090831C0008B4D345C7B9A1C10141220443EC986809C9C113B3DB9E110433B43473F4D46621004DA432C18AE49830E1109CB8471BF248A063AC11C410726A61687A6014D2A440419420A854A2E212D27C30802380C7A3F5A8D92905F851581747FC040675AB57F7775143D1D427919FE40F636E305F018D646B84DEC9DC04705018B552864399554640A2C793818D364091F7B4ADA02F87838444FC01ECA954C1530DFEC88106660B7A014802960D7E0A5C95EAD7A75959BDCCAFC0308C633C84320C31B2218A7BA1AAC08C61BA37578404C0F8BE333FF950E8161BFB908D8184CA70DB3F545862227AF34BE2045DC85C93983062B1E8E3B107476D8BE03C01026FBB542E79962B843B6BF4DD817D51A0C5CC37D0B9416460C933F85C005E43000141F4785D001D07FFA7048591109BF60E25706D502856D6980F1C140ADE82161806189A65B1F938CFC92D8C8C745DCC8C824234321DCC811C8845C46E4CDC2BAA0115D1A36085AFFFFA3425D299FFF45306A117F07C9AB897F74008B4E268C84DABD485DD24D263BE04954623271103BD4B4F0913C8B70C900ECA16D148B10104AA70A33F128404AC47829C040037107841CC0FA54F0E84E263E424250084993898319DA384E0A138AC981A079D852C5F9C07428D8C3812C8CBC8A4204751AC6B288140D4858F0C4E091893B10D7C7890FF935AC8A113FFF750CEA585FDF155A0D1AFF3F344084149F0C400560AB595AF6536D3A7D405E55D4A68233B9F9CF2B5A4201F88945F483CFF83BF9CD07B9A4F9BFF80F42F8C78D950C2527AB52429ECE9363886C7D08E3C0D22B0D68C25C7B147A68E0AF6E8D3C0972668B3B6257568B489C57615564108D990AC2FC0C126689043150024705B02A8B891919A495268B330C24869A1D5753C166F2316BDE0F850C37B437C35C59B04158A5AB9F248A166110918057EA20EA472F0F87F947144111898F044DF859AD028D5A1F97730E8B800FAD3419A3C2452404425F3E4C0E92DF5B031968C3483E933B454740B40ADF9F08F5D44A2AFFFB8B4C72D14AC67A01940F8975C6AC64E4B9F1FFC6884521667975C014998571D27B1611886ECC3D2E81A1683420907A741654B05AC6D2125272663B143A2A437B4D8A6688143D08DC8660F4415DEDA38B165B8A59880F3EC6666122B2479E4FBB5FC748D1209FF8D96BE4D11776573DFF9BE4563252D454AC4D0FA0FFFF56C8800CFF'
	$sHexData &= 'FF984026100B237747E0A2C21B082633B5460FAE5790810844A1A10790C6745EB920FA88FB03417318310C452371BB1F84A3957210B7F0EB69FE587DE9E0EE573BC6293E01F042DC0432EB0F897DF427CD8F41C7F9F9BEC719EA580D29F997C3EAD83037F93DD1670260D7143417D03C4545270C20F408455BA6A04200E75404FC63009AF0F803188B4DF441C6039B0C8510B1563066766BADA458605D5034BAD6C33F1FC2A95CA4DA8D04097F04E48211BF0EAAC2D74AF99F7F2388B1076A1052A9DF00916E155E56A81212BA6C592E18920928145E0EEFECD7D6420E2D8FA9E2768D06157A83C6202CE8B462DC04E0AE5E5FD7D8C205B1FF740D0D5C31DFFA5B4081945808FE01612001A3D1C3D2768F5BFF007E75C450BA5982FFE2C152C605C4845E192AB0F7A282F5C618E4B1CE941C042BF9DF40DD48905C80BF83908E44DE1828C7B092CCDF504572D565F92BD5489E86DA0CB33FD4692C778D47233F28B0B1E23F1FAA9258C1DF5F89B8B046985F29002B0B5E0E1B2F78E62BCBE603C1E9025A8D9F52C13BDA4EC8674F7F115554FC572404A2028D7BFC8D3C8F1DEE806438B4FA73245EF8430B505EEAF175F98D1495BECF3EC78BFB8C8203DA68F3ABD4ED16F0B638740D705B6643FC53507CE352F3E3DF24002A8C255F958891C21F0E020CAA3FBF284A9A81402CD83813F6786BC12CE4A84F10D7AA78D6DFDF9AA0955C1C9F20DC6C8C9F10D82028F565466B4130E34169FEB9D039E46A4FF80EF0104A0E0AABE30B2EB892B099604E131F960C1251C6F89A101DA41208BC1631DBE846B26A10F854726385018418C165835CA892E6FC0952A107920B0CA845F00E621C503F10E157B33BBBC4BDB8C2BC5C666151555D6847FF605195A1BFC20384AA7F1F048C0CF202D7080C04B7960C84246B48C53456899C342034FEF4B83C41F8049F061D09243C09FDB6AA50C3D6BF1F1F32C823AC7FCD1F42B1106DFF5F2C2D2A10BF9FAE5018DF56FA2BFBD0C70322A2C71D3EC1EF0245F9A226B012D00F2BF80346084E07B06982F3A009416C23105F9F88159108BF252722A67FB95C60D10529BFB028882CFF5A205592FF189654809227EC38916115A55F2B362C9201279DBC90C40A2B3FA59CACB18CCDDFDE0B581085352A8C6071DBBFEB0589640226C3B0165B4AFF81AC1515F53D04A30CF3285DBF9B4A15ADC74126B93C2C41414112D29092412F1C19AB533FC3212D9A762B1FAB608B889F7F112E54149FBEC560940C01292D545C89073FBF147561003FB7152A82BFFF1DC9CAD6EB3FAE94705320A6106A00E38DC91855325F4FC293583091706F6383800F14803C5C6C3C48C4B001E3B2A4B00A5FD9B7E636DAF61BBF6F640274C7731642E91F181EC202C604080'
	$sHexData &= '1EA429813C2EA5F935F08053276955FD8BE3A0327C13610C7402075889F098BADBADF5F6920712830080A33A848B403241C08BB5BA7BAE4F8C69C7C0400A16A77C10A92D71F7460BB550303B3C64150C90138AC869F9B0C1D0DBFCE41201F30615543AACB1990A3908B1F80808B425180FFF80CE96C0B27126E424EB1D5BF5F43EC86AE14151FC318484E8C3F74A00DA85A05610BAB1F4967E954C5361F100671DA788B013F425A5D101FB2022173453A008440A2A7780E0DDC4ACBC1890EFFC26834F0190300798E0A7F0705ADABB0309010C04220CF3C97DC3E0C4C5C4D229F4D6104033D397D29C58BE200238BC13F456C60551F458C10069F525CB1817F55F56CB0E00498415635F40D397D2D04A8363F00C5A29A3F7F841C435AE43A90ABC20C289BC17230AD64C1BF1F8BE428A403DCE4AA9892DC1F3FC5412422191F93702A115FB6E042C410071C832D1C1A734701AF828AECDBF523C127BF26CA93C2293B33C8276A563C91DC37922388A9B32FC598BAE25EEB0FBAF048156FCB4717085FF7EE2212ABFFC556F0B519F2A6F9EDD1CE056060D37707900E8E5D1A28C230AB1F5BB525AFFB6C3FD9B00C56C71FE95483E238A91D5F2B023940924C249213C9FC0CFC0CAA5A01017F7F8610D2824540AA00554B6361826A1589FB5FA4B12A0C1F5CA148B2352C2126C8C82BCB097ED701AAAC9535015890E75D1C6B30837F4D00DAC3C08974F61A7E01CA7AE853716E0554EFCF7781CA75E669DF8124CF183E184B9E4C519F4F934C60D52C097F21931C559D818164D9E8183FF0EA0AC161073D5F78ABB664EC3FDBE2C89AA0BF02BB56C325A2BF3C3FBB168883A68302D0DBEC5E509316281B65260B170D1FC3BFA2424023DF1010ACE8241F7F57108A8D1F7FC008C1A1253FF5CA148B7F5503118910999812A7393F4D19F92034244F373235ADE4CE3B2974A44C076B344CAE6972C83C6A346B2C1093DB949A2F1FD91F0AE149DDD0B3BFD606C90BFDEC3FA15595821FD18050509FBFAC818A4C5835B168A0767F353018C8D0953B84030AC6BE841771F48ADD15AB632D23B93F885AB58825D5712DC2772FC36DC9A963BFFE7C3F708BF856DFC33FB788503204391478A2025D2BE8A26841FFC31503D620BF7F8A5611605FDF60D12DAD5FAAA0F16CC0047D49A100D65F681032143F01745AC405DF7F98AE1587849E9807566AB10B380B982A7114687EB095158BCEF3F0770F310387596A005E1A549D12D8163D3B417F250127524B3E51AE24F054132BFA4B10C30A704BA398656E34005ADF9DA400C200E08631221D906C25A4FEF2D816A4F2B2160FB1AFD394034222D20350A09F1F0CE13384041FCEFA14E1018323EF407E001F0C5141E43962783DDF0FFFB1E42039'
	$sHexData &= 'FFFF058C80D5DFC68D30617846B70006FE010903422EEA8A042D1F9F43EC1F8A49C02374C0FF45C0185644932D758158DFDF922B0A607F10421142ED3F7F69BA2D62D2860C5F96A2C8C6460EE2EC50A5814608007B0617B042CB9F225893D6337F9F76D04206DC5E7F2A58F20AFB6C9FA454C8ABFC0C2D88B45C291E2353307CE3ABDF3FFC6B92B892EC0C7E62ABB692083FBF61D5B164FDDF9357105C7F7FFE7C7507111BBFD1FCD9FA61C0289E7A143A010FB10272101E0F872A5C693C40FE42DCDA83FF51685C03C31ADC02894D68F710EBC3761716733A10BA403A11C8280A8BFB50ED40EAA6D138F930755F12F87AAF8B52C353C18D34948D89C43F5625E4CC40A25196C7165424BE278448AA41121E50B082C4238B245BEF81404061C064AAD10AFB1A8261FFDC37930850C09FA08B286B099B1C2E58612FB5181FDF2F7091B6E23EDCA61800884011507F432003A57F43855867B385C090890614F128E255439009606B37FF8055D3DAA21FBFD124526DBF524471A95F1EBF10402A30DF4A4DE1C1E9A645B48571E56EB48B55088D14531E64920FD6CF1FFF131AAC451FD35FD1FACAC25B06D35A674C5DCF7920D77B36117F10C88642CC3E10F59AC1BACCE54BB5CF6ECA0BE7BC133F3F164B5BBED37410D1BF291605129F3F04341748CC04B83C03052716A3C3325B8EE433E5E9319E124EC50657DF33D27011105795611602B58D8B440D2BC10509C4A006C568A6308A739F885845345F0C214867FF74A80489D5FB4B45410209DB145223800FADAA16DD9F7F07923D083F751B8D77F905111D46479B4712B15C0607F0258500CDAF25456D124708BF8B6E6B6D3DBFE254620A3C966450991A291F080CB7F52016F98949AF9D5F06989F45B6CC8B0088442BB64FFFF50D066C3085BD1492E735DFB700016A5808455F7F4032C929754030108B2DE0430C290640C8416152721084434A6D058C832099294460331BDA601D04B153891C04F169E79127835CC8CCC8C80F1604B1C58593278DCCCD280C2095D0D47A23091F3C38278B30F54412DEB37A188D0B210C19397610210278586A9970E8C5230A4324E105DD1489C2E62200C9BCC333C0621D04B1CACA63A90EE48A0873CCC855B09041C8A5198A0822734B085FA1E44629C423D065FD94844C1111A1AF08F24C328E130E111141742B4EA72F945CF202CA4E49732C820B971B5EDF56B223047F75703F03448AEB2EDCC7451181C092DCD11033407C02CBCB2FB90A3CA5C831ECE0A2010BDFB04E20C30CFF2089552CE0C6149BE48B0B3F523B75E4E0EE03D3E67220394AB0A4F07A247C112B805608387EBA042BD0A3A43FC142388BD1D85598C2E0DAF2122A1753F886410B304DE847415BC20F28527DECB3EB485'
	$sHexData &= 'CACBF032C1A4C1E0332E5483C741C948829FC33F41F3BCB740A5532C9A579D08B4819D8BF421C7239CDE019387E8592620A4E2F660A7F9089E6EB234EEBCDB827A43185424B080875081FC09A322EA50583CF53784D09149AD2B5E6950C1137E4CDD772844CF2E48B7DE057D4145662415F6313039D1F021AC821571DBFE01CDC8B2416450732DBC11719089CF7885DEF52198614B41ED85838F4F4AA2015D2CF659C888E6540E973FC58F458C07861D5C62CA001AD94E3D4263E778F8507A29D75B4718040E17ACF976F0A0AFB58CFD9309C8E02D30EB61B60B3010F6BB000A849DC2A463A5AFF167FC97207B802616F8B5E143BD3731C40EB1C06C7FB0856A3ACD3BFEB10DEE4BBDAA481ACE4BFA0BBCC01A4A21BF8E8CFD460C1E11A3A8A624CEB1F4C384D861A83C849612C0B1C424238D65115A9389A186608E8010058C91F11FF52088BC70A5E18159F47FC00CCC43CEE33011E8D0F29CF410C5A1CED8AC00429660E20AC1AB119439FAF05AD6E3F7F768E12269228F29985406511013A12322171579A56A6EE86146B8DB7B02AC2AAA1D6B5C8719AF2899069578D4DE87434E8A064A48602442B31437AB650F51113FD64EC8997B41704252255441DD441118B55D9A05A2461967E015F50F20A84BF7650506D6A81B8BA10D767E281795562F7EAB6E0B01E0454FA4C03C2EFA2E603FA8BD12BD05FF289803EB5EAD883FF41C14E1A963B4B6C0694500DAC7BEF01EB0C0AF938BA14F17A650465C8D6FD1D98C142753BF8350F8623C05504FE502B33F7EEBE13C6DD8B80C4A58AF80F87DD3C484174C17E3BDCC28B209CF62ED48F8BD09EF23B35F5CF9BC6F9894DE0023BF90F420C0A5815816FA38044504DF1AE247083486BC02CEBC6651B2431A08C8BCB12EF48E18A581006A36C9C807D8647100C22A47511CA78DDE15A77C49E1AB2D53209B2996EF444A019FAD4F7E1E1AA207F8B80DCEBC070497051877360AF1178C32A046BFF2C504ECE99C6FBBD6B8CE0C05E43B8032CDCDB0827A141900F279F6460113BD9CB004B81089C53EF892204F66BC72C94D0A76C5BC1A077BB9F694F821E6DEBAE30E89AF23C0D363970A8FEFEFF379FB5ED2C3385CC4D1D114CDEDC97023A495107B7482E620239E0D1357C7D6B5DE4585C6B602CC47A01BAB7610C03C65150B5EA2F68F072A3F3F1F8D40E03CB52CDA1E0C18B17FA2D7C10DCD7F51AC504BEEF37E32CAC18F844D4C939E414159F7678482051C50256BC1C9C049A429E2434B8D93081A7227383F820C2596A3AB744085E40233D8AC4D07BB8CAA07DD360B00EBC7BD0E24D01CE8EC62B4DB480EEB5ED955CD1FE03F09530B01360C0DA66EDAAC2898EEAC1EEB4F2CD163A7EA62CBE567D12F0B07FC8C45E6BD53C78'
	$sHexData &= '45BCEB01C8CC4614B0AC250B826B4BFE1AC8C653378113848F872416027C0F8085BB0645D69B033DDCBDC117AA157A7EC688AD6E36A82829E0EAACD1F9F0032898C46D6BF19404AE24122803F77FADEDB4FE46AC8D76D4F37AE8494CC01CDCAE21A1690AC4E004D0C36899F62AEC1CC8DE5A55CF0C7224D4F2B48141287DB8FCE1180CA52760EA64B481F74B8AD18D92CF905B7A700C78852CE50483413C14A7704D34702721B4E170A741783651C0A0118955F8293C0C8CD6631F0A24EAC67F7E750B6490A0108E065C08A7ED9E6708AB0A3B1D286B914E0C6F23DF8AF424E4631B0278916E453A571C5130118043D865A8C9C1C22A08DFA248C4A89FDF20B91AC43F769382A9C2FCC0AD9040AEC1F0E1A4AAAB1CE28D8F9898061CF1C7447C5230B2D55E881525211F77089021194AC8C85172E4A7899C8DB7C0B5DC8090A9E48A5CC415AB10F7878EAE255F54490839773075E22AE4A904787F22392403008C8C47200F64028D5C0354200720046CE098C2B89EC372C80128DF77B038A3F084051A4B1E4561012DE04DC808227CC0F02E72364538C2E6EE955152ECC0E646D889CD95CCC1F802D1FEF255C475E10B997EC083E230C88406DC82802E9E83C2CA11A6C0DC4CBD6F601B0CC2EB10FCC4237076CEDC36E7D4E38EE37F9100D9088F800B5179543C48A15B1ACD40CFC34050E01170B81C5FE103BAC01D408D570496D00DC2211D5F7A118AB0419C46EA20244E481859C0C13302C4B3D0429105A550180E14F002756CA28D33E122C0606151B1909291810837E4D04A014B2E19A06511048E7E9A041ADD6C5D49088748A00F8C067A44EBEEB2B8BF8D72E402C4B85611E8164A13B87FE12580FB4FD210CA46FCD9C00937CFD0C8B24630550146A19C226C84E76A94851B048ECC2CE54466B6B51C33C92114846C05414B9186767815D0471C33D2287A18121F8A275ADFFA18050A930986502D320339D0212DFEFEEE10E2FEB883EE208D0430AAE8220F8D0E6020D1E1A64F233F80082CACBF159C20B0A920B070C90357B92A92F0B55F5FCA270019FCF48B75FC45018992F40A98A4D224F8F8D09080872F1F6A4094C0432AE5D6405010001716FA175A958A246C31518A212C1A7FDF8449428ABF082B8A21DF2F64820ADF0877E8D3D241F2050383FEDA812E0898E345FF384475000C42A0A28070455FDF6D5C04A9FF12554C052ADD3F531401847F0C4C2143250C0C451BD4B1BF5F58541A083F58F288427FB78855F280E25FDCCC080C4A4E160C34188B08DF7F6D554B5BB35F1F98F496569F106C51B160225FDFB661B4505F5F9FB6560DABFF4120F2683F891104424BD0FF1F1603580CBF1F401586963436188252C088363442213A8275FC9E1CB04A91E8A42A744'
	$sHexData &= 'E7020AF541264CE43088B4BA1DE452D583B6675D98B6E79826C5001015E19C5C32E7629E1DF186234CD770965DF0CE8EC53033A83F299CE54DA3660DB4E4647DEECE8042181914F15098262FFDF16E77200181CD6B0948E3428FE06F0E09478FE18134D82FECEC3746E904BC1DC44A0E6480623C34A70887A412A3486AF89B8081CF0CF5A341D91EC6C5D958D393138AD2F8B510459315230C47F207E140C46E05AF871E4E5D0103181033289E8DDC28B684C713EDA71470483058D8A85EC01270220749A0B0615A58FE8E463601177FC0A11035F3268C33F46DDA05E7820FF75624D04DF1DA8D54460DF954C5537FF4616311158DF565521985F3F12C95EA0FF785011838AD8A45F102589884003638CA93C3D539F08500807EAC423BE8808A3098D5E8E14C8605C039A986ECB0A508B08A5EF14E056A4E56A94CB6AAC03208AF3018DA442C4F113B52A12021F2EACEAA0DF1F0866DCA0BE3F6200A1169F9742824A4011804AC0A0371F1E44C92B7870789051D180403F9580950CCC7F1C2A58459F32C0310888011F802517545F1809085491FFC7211410DF7E5F0A0802051F852A10109FADA040C01E3F6AD0AA2A5FFF81BA01247F4004C1423E1F581507809F19483400BFC48BD43E93DA1E57B05D8BFE8DED13BD19C048182BF85F41E88D525C0678842B0B4AF0B5200F0B2B0230D736B359A1D242E041FC3EC74173B3E503AB013C7A0483C14F800B50423AAAB2D8A0BC40BD90DC37D6D146AA1F6219420CA81FFFB0FCBB6E0AF9A2C274282BFE908D0C37956E100FF6FAF1068807042C5A15AA864ED8CCD2DB2B147C8DE4915CDB7F28A6463203364037023858B80FFF604C20E0C744089501414A2C3F0B41B04C192E4A4339868920C37082C47B91528C90AE3E129D53CAC510808D0449D85A83701EDB4739BC0AE4685FD0924CF0300A905E5A2052D4D4937F9FB42154F067FFFF89057761B86AC774592E8D5025424441B61F81BD803EF98D520C4411F411EC2971BA45224298D9B3A2B710F489308D90C72E4D3243D185970D596CB739930AD241924C3FC91C45A07D3F020061150F923FE52858D57FFF661650D04C2878D8E62CA9542A9F36B0B4B8BCA7053C2C1ED43966C47332C0D02462EC61B044B3D0FBD45144421B12A11E86A18D1901A95C151F57140DE04D61F6211CF2E4DA72A6F765F6D04742E0EEE091C04F46E4D08A42E87251097338FA8E1C1AB9F589840C96DE3280C015113DCCD2856A913926562B0A282E4E3E2B1FF12B1BFFF13B550C751FC9132BF088C25C0027751186B7B42BA7408002D83E08FF722181465F14FFF0C8078513F8576A38B02AA90CFCF4C2392224FFA09040A2015321180DFCF91803C0962B19829592F25C72024202865AF003'
	$sHexData &= 'C04ADB7E725F8B33CE106C808786E939283C81508AB52F7240F2F483C418149108835DD85653A59E49B1EAC222195F25275F227F28921708181F78F0AD2A09858D41A49289FF2491BC41311F3EB812C94572C0C841601D04DF08A56055DFBF0F5A218B9410019F5A220E029F3F0E9011A1022046A819269FECAD7440E3C87FA30A1A11CA516ED5B680F4B559C37F3E36D19A02330BB2B1228DEB2DC25FD62ABF1E8444C34CAD0C4D3F0049044320105BE33FF858C027A38E2D4E14E8FC20CE784A7EF6FB6C7843F07D45263D4CBF895340E40E0BA62238FD11485E45FF791089E5F6354B8B8FED794998218623C431710037CFB7AA90EAA089A34625B12555FDFC8B0D45140EB75F51EDB3C32107191CD00C13AC1D428988C07C47E1D0500E7945951C40AE9FB0B1BC9283E4C9B0D23630848C348FB7C8B050728710C8B44D03100C900B86153F151C050F8F797E399F50F0153501DF8D7E089B52DD14F7711A3041C23056D3D96935DA9F7F7858582147C11F780B867BA07C20897D05C62158D0A1F80147492C0058A51156088932DBE140B14783C14D6CDC24017288AAFF7CC8C7AAADE4B6CC3FBF09C44072A0D9AF488154660033105356811A204F68E81001BF7CC34FC989D4BF70249AF8200261C25B61B562F9F3344A080A6110084D0C0C0D5B2CD116C59F9B74CC6EB10499B0D6B58108AD6D999F56095C4015FEC35FA96241ABDFABB488619FCCBFEC011195080C95895D9CC4C3497F8B561885E309EA1123D0E29A6DE117C00CD003D28B1CFA904DE07624889A3975F803EB603A64C6F04683C207AC180607944493F0BAEBE3E80B9B377036305F404F82D80412FFDBD153507E133F7503CF8D4036419F9BBC8A61DF18CCDF0E078050F9510454102024231F48DE0C2A3F79C0EAA6551132553DA0748140B5F0E98509A9104F14CE524A48E5858706861400868BE2A94130B04238BFB54AC9585F7C1862301F79E8AE9E861517411F000CAC064845C689A4C3BF6A01394604405A311BC1D00A90577F7A10A416E05978D0602BC2B50B289C5F21DF8241B5A9FF8D3CE251C6AD9B0A56B82BA68B0E159B3ACA38683012C013700F8DBE9809B1483E4F02A8849029415DC82A2C2E5CEDF11F703048267A1FB116A4AA2525A3023986119F701A460A11AC8E6597B94308E4B44B03100CC7B00839B83F9048804C248864886E007301DE880D8BCFBF7AB081428C4A910A800C159FD035C152181A0F0304C612DF8B62278A9F7B10BF52B48F90308D7108C1550013C7BF509F716855320CBF191A7620879F70C5042508BFB78C8B317BA551E08F8D98A979FD8EBC00303A113FD8751280AF618D55BCCA77C3C459082CC69350205645139FB5C0ABC14FE001785C19F8004F0E03A'
	$sHexData &= 'B259D0CD3B006816A19050CBC8034048CB49053078A1FD04283D847E21D8D45149BC2E4BC8BCF160C9C6A369BB41A8B06DC4E4D1B422D4314E444E01A2E0B3051C22FEB837C09854CEB428B5D1659466FF1F4377A8D32F18606BF0556664AE940A35A21049CA9BF23B11B2CB800031528D6A655332C859F13270A99D07C00AE62D5495FD7ACC9C8845CD4D81C4250CD73E4E4E8F362818B2BE8DBB6EBE7408ED5C85ED83BD8902D704CA96E1AAD48380CCA86E5E0AC0259680A0857096A425EC7E4E8240B2B69F7E448115A58C70573402EA0E1D41D5C5AB588F416C1C37FC906AD5A1DBFFFDF7175E0AA08DF1017831586774E7E0DB3800640EED0B5C86DACDD5EDA0C175F181695A144FF9354E880FFFCA043C8076E03CD720C1564829E430148583C5732C9434304CEC1F8B30D008E8D348EFE209C866832DE3955F492A64A0640CA4E551840650BE3BD2948051ADFFE240404B6087F003195AAFF22C6B270B1E5273D9EA005D72150E75C5E7490DE06D30114BCEB094061A85B00197C22AAA10A743D92E4E06568079DBF2E07BAC80032DB07EB26CD740144A5A4457F425E242BDF7C3009426621BF505A81AD4D79BF5621378ABF042BB9CA309F7C2072E0C4EC56E9462C01AB6235B5AFF09C04D9B07E558EDCA40923002DB6030443402ED4166CCB6BC93C1251506B07280007A51CA79DD152BAA86D35AC4A03BE04F3CC06354845931AAD260D862C153167E5B089C46593994A252F9F7CB82498443D7E43E5C7246A353BE1BBD7814C0C17E0737E0F1AE842F7C87E1D5710D140CE198B992318A503F600CB10E7AA44131AF11AC5658FC2815C25C75FF81CAB6315023B59D7B40090149F7D9095A98E285FF1461C42AE10AB53E012A2D956F62B4D95A7C30452034343E4A463254606CEE2243402BF514B0A907E188BD4AA267F2A52038A1FDF6A250D0B3E24ABD45600FFBF0298F06E41AA74118079D7941234E1099D42B555DDBF7F344876A27F7D585C1CD8E4771B93EC4DC8D79010380100A05F0B2739C43310F4A81515017312904E412CFF965C1430256BF455A00A0C3C7182A981A500033A815CC33ABF3F8832C4F04A5A3914416918043F60C5706720EE3935085611512627064AA12BBF7F8081D2A23F2D4E438BDFA808D2AA5FFF82A8090D3F1A05AC5A1FBFD0A840A5D1D33206D4BF640C2AAEBF0C3F585A44273F6B2B08705F9F3B1AAE857C5FB0586CA2C804A2C2081154028EC15FA88CD06C12DFF6016BD82808566C7F22788B2A9F8F7FD884951037550948119FFFC4888A5BBADF1F4554D0BF032974C7A61420FF7FD724205003F83CFA168C6A3D3A2AA9E572274C1FECF0AD2413C9F4F8E8BA51259F1E7F9A308C30FF020D83AEC51160D25805A90B9FC0'
	$sHexData &= '8905AD3FF9BA186A6B358A5B9FBB6E90BC7DC69FECAEA50DBC13C60BBEB00B5A17C287232E6B2133AB01C18AFC0164F80F8B7F048996095A35DB75A218B8149C031ED9C4C01AD0A4E1830EC4138B09E9BA1FBC8A89003F2BD1031A3A01D7C3400F5B319F8EA8B70D45C24EFE67B08D722246D88300B0CAC2EF2C6E5F14D3344DF07A6C0AE008E4F12F5A4D0CE8AC46EC3BD8001B4A19F9FE1C052DAF143F46FC8E0EE9D07DEE2CDC3BF8150D80C175A0B8800A5FC2606834591FE0BC5C0A26FCC87128BF0202C11C2621C62C83C71CBC340726D8FCC75F136220AD60BF8C3129A84DAA5F140F1680EBBD6EB7EF1F907CCB89BDB82CF7E992D4899D037077B8A414E9CF2B8D15C500BE57D1B5A018D1F8DE03EF531780D847287E7BFF4545E12B8D40CA6BF02C6BF83849DAB9DC7F8D0C6E392C6352733603D92BEBA594BA5C5DB4F7050A50DA502BCE8BD32966B8E4D977FF83C0D48BC82643563A7EB44E22DC6CC84BBD1DB0806DB0FCAFEB06AE8B0F3EC531DA7BF44B39A17370A8070DA6FBBA53577608D9C36E1430155753150A8BDF4969F669D972DDB19AB83BF9685FEC30CB941A31210FEC44ACFBF6CE64F82BF48BF78995BC12811F688F3FF140A6D84714B01DC61187CE95A07B1C673088E2362404E7EFC12571016CFE0F8450B11CD592E88D56741610305C9AE3C086316610B0081800C4D2AC28CD6C7810938226A82691F03865950394B37145E4A3974BA3A315060704080C4462002D340D73589BED80EE414188AA403217168529B0280561650E4ED43287028B5B81D3580A3010FA69E6D2C4C60010AC08B2814997A80CF880F06C2CD8BE6C218BCAD57B0BD842600B1DC6EB3A4A5E5A0F9AE7E4838B211FCD09000058837B852C2CACFA9844170E3BBF826981655525DAE282060F86F0674AD86183E2E046E853508989534C149D9D8F702D52ABA46902F7517583C3D47A4C75F0731268038D539810809B8AA5A9AC9810A89169B1541C430C7AB0A19C7F462EDE5C149278B84324C74390B5C90CD543428BCA33271EEA660164889C0A0233A54C08709CD802438E9317A190C88BD448708AC9375133D267E1263B1B034314DA9040382C97C5870476DDDB55B8B7AC38D9A29C9541FC01B78313AC1008DB0EFC96B4D5B38141C42672E121F838B878AB8D3D9F456161E6C0B138801CAA38C1EC07A7F88A83839B83E92CA183EA672345AA2C259D20B81745AF295F0CEB85E2D49962AAEF2B8478070D486F4B649041069CC0A815A90E19ACB0116D516941358C01D1B2B2C52A8E6B47104714B6A903039C7A2D31320868517C3833C94B56B9E950C58D9CFDB00F1ED25CDA570D4F0410A808AC799A67D3FC4D8C47C1C819B95C067847904779547172A08C3B4E06C36'
	$sHexData &= 'A0C038F10952C616141AF72792E189B0646461190CBE5464646730DDE00C1A146C8C95148460E4E8B260E324E4E0C4A48E5E12DA646361AEE032F3DC32C6548C5B6114FD0D54A2F7C4E92E3868574A960121B0CAFDF04DDCF25CAD4C2AD62D41DD5011EE014ECFB503BD34A3248E54A63028D4A42427020830C4242B432150F39ED3D51344DD3FC140389028B43424342344DD3344342434243B0C9C88144303893BF6CA5091D4324011C89011FCA45A0F262708D0863B4039317C01649F44B430803E4E90400EE0443A4A219904343403248311D0099344503111D18840CD417078C68216D1D4308AE05B1C2BCAEC948182BB147243C27338C47B9474F9C196E4AB0011D07E53639C30B98CB4708F6024CC375E4BF3017C894BA8E41D70BC2600B935C4F3E743B5295A2F61D08F7459B869C48C901254926B2C8C408C19900AFC17C8C4E254605904106464623E4153D89DFDCFE624461032D0A430DA41A4204C155E1E23F26353BC97708706D28394D9093A3E4460A4AE5F219644A4ADCFE42155EAB42383B5D47AC58545859459AA4B32D93F8458262A0C1273A1D430DB45DE49F3E1158BF060D565E89185B22C248300FFFD4A450F27DF8A2BC211D6A3BD62BD630C0A92C04CC2C6DF9AC40A0172CF5BBE916B07208C7F090FFCA65A4F24F8945C4C8D4CC036E0195D0D8F904C93E97E8C0D78D8C6BE816705CBCF7EC908B640EA3D8167C3062C1607E0E4A6A3B3CA0531232335590430EC35F7E28408E441C2EC24EEAB8D4F04CC388ECF740BC8780252FE1EE3C6C50E00843B8B9932BCFD7EC9A356ED8521828841812B445549A0CCA022ACE100C0F271F3A93069104018F7DA2D392088F46EF02786B10C69152FC950DF05CAEFC06BB46044651A70698089A14B05AA309745C29F5328C2660C8F7200C091E43FF2A5E811F14BC96D250C18D0C314FA70D13AE9933D25083C014155948439A4B815170C78FAD8AA3138DDBE77BC8A16815F1FF7E5810CD057248F2ACC462714948B09E2E750D56D034843272FE2CA1C54ABB52BC3BC61A247A54E2324B4CE0D6C62CB90C7239E44747474791E6A825ACC0EA4747340EDD920759FCB61D3BA84B26D137747552B027022E011E4AC3EC98C0CE502D3C34949517E60E109E45C845CCB3647AC8C233D85001CF96F0143BF06D0CB8162E9134B8D9F94B529CB8106545E8A4147E6BA43EFB06444155F1343F58C78CB666828DF555B40D7AB8A2D490954B7D2CF49801104141C458522A4106A52A30EA30EC9E182C1947120B0808F58645A9C946FC1F88B485531EA5F0E0ED040466DA75DE752ED9E11C82E0742FD13FE46888BE44D4EC45F82C39488639452EF1B67172080218024C5BC34C3A1C8939098C4E806A6C11254C7EC23E'
	$sHexData &= '321D093A80553F2275601AF8E0110590E83F3F031E043E56518BF173696F007E6C969885A48B0E02410B1FE31C0AC68952092EC2485B9F685315C07E965F51CD8D2B00B7C995C047154098BD95880342A6929CC408A1034833DF086901849F1386174DC05F899CED90174D405F7ED60ED07021A4C98A5C15438040BF0072A268DFA904919C28797F16A9045120485E8B8CDD86C94E20368C8CE9027927901F7F56420E901C8C8C8D5C9086C0AA9F3CFE18DE3889E54AD9562BDA89A1DF89261FC1FB068D41E0188B28A51ADE8D10612302FF30F203DAC1FE0525BD00FD90893F44FE287E7DFF46769242813094FED6C1E7086CAFB4AC168D04176604FF42E01D7951FCCC2C57519759160ECC493521700A815CE04F10786EB20CFF49E1175178EF4E852FB9A6CA57509E7F086C8D524B20898D18FFFCAC0EC0782E441F10E8021AFCE03CD7BCE5279F595653FFD7DE399DFC6BF6B52C1C112E3F535149B7039918284D6B8B7BDB3EB3CE244B751B83C1D96072CFEB0C8583413502E49D3F4A9D0D104E08F28393AF82012FD9708D790450EA451601D800FF31B6F61070865A53503124C0F9B7B9556FB397C80F841D76503C4804114C1533D2AC71690044E0E04992C017353F178B511E80E75E4695148D6728F00A045444B801723690AD7449DE4C55A1139DB05D4618248183B73E37823442E0B600E4318465C30E2D9DBA6544DB080B7BF7FFA2E855F4843211604A149C69E08B6CC850E0C53F6CC58B03113283C7395A814506D316C67938F071710E587F358DD4E74F2164FCC80F866B71E4DFB92884E80F222A505370D77A202E01E8E03053D6D4213AFEE72D0A25965A30FA1437C09E20D424C0AF431C8931566189A58A2D9461672874033BCE0706B4100490431343149AFCA4087B87A0084EFC998A845C142B09C001936600D40C03194A1E37C05B0C6E020F9D22A34F4AC8F583E92009449D18BE80A85BE1853DE14BC5D3BCC338BD84ED0543361C29B89A040160700893535CA121C16160A023E319188EA1069FB0D187ED02751CCA05049DAB668E8AC9413B469E814C804539B0E688C1CC04432AA5A0A6C9209581A714B41C119047C9A007057868A3C5A398E4896328F9786D13A0BA80A190816307B9904087BD86470D078DDAB7C80D03C880940F47C850053080DDFFEA01A71A9DC320C576542DC2C0EA4836D6E0C71D2FAB3E7F2678023BCB8424E5E3062D64018D51840C8DC0034E73131AC887038E2597417C921C02CFF4FE03F2E81E264D036AD6CA39309948BBA1B310C5A91C1A6B431C0CB66492870301A22EC80EB9E1053FA9E80696813804B5CBA28E571002C7A402C53B6C30ADCCC7A4A9ED0EE4C3528D1840B97104307C5831F1090159DE92A73250033'
	$sHexData &= '1AF1E44A63AED41C3015E42461A4E4034999D0BE41A5B405409B8C31685AE8BFAA10EB8B30A5CF86BE7A3915BC96C0193193C2BCFE7A6D847078D57F4FE718D04C314722020477F1992CA0130070499400E3947474703B9402E20041F4B2E902034DB15019386316A20515793A95A89C7839B023E6114F5468A08D837700451431E35C33F7F88EC042E9030C03A2BD141B58E4930FA2AD19A0184236055C466AA146275A0F2C78D71F040E0A2C05200E18D76E0084F0042A8DA61030A0883030C47C0AA6EFF3E1102C6A6607272AA94B42C4451F1533CEA80B0DF7FB8639278944DC8CF042482859D03A0BC695D048D72E4BA1EC2D79D0E761C13BC3FD08631A000DB110B43C7813E41AA28A0A2F7DECEA8D112040AC78269006141DDC445C5F200D9C00750CB56343F71FEB88007F084B2A7D516252ACEA20B7B121E041AFF38F5C18D8E9047FF40B069532BA10A1A92B8BA844B78467E00E241203D793A80460AB0C4E0EC0EA06D58E570C8AB0D83EBA6894A6AEB51291CE31561FFD2AFB56818ACE74EF2E0A000C539A02E84C892CAA864104A2856CB9F38B292F4C6E383EF203477300875E32C4F746B00115470941018547E514621F8AEDE72041CE0C124DAD03C3B5CD6CE861C949EB96D1A699902105E71E0E9A3A42729F2421C5682B4F7385677428B1B6A1F30B81C0164B868941A46C0608E4A6288046CC88169B480C820270855E13A81817DC8E6C11C0E0BEEC975A1E42B4D83C8A37E06F8742F8BCF0C06763099A49D493362C98397475C086091130390666DD15264295F5A4D6EA021880015C4C0412E40FA561893CD2F4714C4C08B55B854A42834165D97DF124D46BB89A6C17FC4454E1015AA518B30545AC203584B0887340694070C40B926A756DEC660BBD1DF5910DA2310408B06DA380CBCB7DA25DED0D797AA0DC16625C69E800FC2895752135BC501AB98163FC525C129ACC76E0BA1861F1FC3E90462F950F20809C21784A380DB10AE674747E8C12A61CFFE8956F313D0E0C168D796FCEF5B206D4470F1DFBD52100C82DFBF118C011207BFA4AD9243998CBD118441519F3F54B78045BF84A531A85F80024215155FA3C358941FDFD3440F01ADC3D0C0B6A01F2891C316B5B182BFBF464170C1508481AA03420ABF8255C1C73FDF7F8AD24080DF4158A82D5F38A513C01509C518091C08FEDF5766032BF842390656B4F0550C7439BE970598DABE20891D265B1F551C4A82A218061E0D6C2A1C507A4975DF21D5D4C2147075C93EB3A9B600620C1C693D824AACC3BF2E1C6365927DC83B5AEA7CDC5C9A01E373ABC63ED37E930C604246890E896A75CADC6BC2E84DC7EC0F5FBCB1A841343FD727554381CC4D3E75DC102968B087492689202C466C76E0F0'
	$sHexData &= '69E0C188453FA2B285D36B3C8873368A200DA9E5AFDC4170758F8CB7C3890B4B045B5DC81F5C157F1C450C3B4D14220816C108352F0567DA6F0CE04142890E89E4450BD02A7889533F98050CF95F8048E58052520CB66A0334E4D85CEC08012CCC097DDC076203CD021C744E5D9200C2021E0A5198D3A3DC7BA0C1FA2847042C5F29201447BFB02DB928BF089F23511CB4DF7291EC201F80700AC54D6355DFA39009569F9042150192807F0345AC2ABFFFAB620814DF5058090AFF41C44E0325043F1C492781FE0C08242727970C080C026FB52D615FBFAC06AD4EFFFF9043C82F7F0532C08354452CC853BA880934618D567EFC676124F064DC42E0DB8FE48DC042CC4942DC4118D746630265E44CC724B991C075B3E9906208294E7FFFC609B688DF03C3074C84A29F9FE592C014751E28FF10338159C10883C6083BCA610746C875DE59A82430887FBF1358C0913F02AB3A38FC7FAFC8E50266FD01C529A2B8481D1F50722890D0924C5413580B1FBF022B08021F5CC5B166BF3F4ABA56233E6466908724F8B0004E9120419A184432F1B00C1517259565ED7E4CE9AEC44DA0BB1765571060B09E9F66744DC0FC8D562883C12859A615A089E014DC34B00AE0A3A6699AB4E4B8E8BC9E32106A0217846490A937C0D0724DC0145C2C5AA026B01A567F5C41B56A7F1F460C1518803F8A8F8F92F11C02C61C4C0D291986BFD796DF800251811F50A545CD5F5F0D240E88F13F65AC904380F84A2DA0A3DD7EB926841B9953F0C7479EA4B1E09FF2A042D402CB9058102A5F5FC3345215FF116A788B13AF3F9148EE061F816E493006BFE30C0837E8F88F7702F770EA7EA2940A7592460FE9F8336A10B1E44B24614BBA1DC0E2BA301E50434A3688902C5F081BA3863FA897184217558915825615DFDF4DC5056A5FB8DA080A38FDBF5E24EFB49548FF0310E10692910CB0E953371C80D17F843A578D7A72C3805B52488BC082019559048634CC2A511AC2A2C769205397807F81A7A48140F5C000051C0B25FF70D040080A7F4125C2909F5C65592D28A1FE364104956046904338DA45E4A5010D1804C08A3C8517A58237A04D9FA90255C2451E8D5F04FEDE43715340FD0634354690A01226F70184C582497F602592538190436B55D83C5604BB5C38259C8077A86B2DE049C2010D205E3AC51FAB66E0886F908D47B2D09086C2902B7908B42A8E6418C7B93204A1D21FC527142A4C5869C52616A38DE3C20AB9535F8134308850E974DB58DD191F806482159FD02BD488648045C9C840143F2428836258C9145F62AB4203BF3FC98842A05EE2808D5781F85F40041B21BF90A80D2193C542D486877F848D5521D1A2D2C02A413F4CB15572964C7F9357D469E0BF9245ED45057F91D'
	$sHexData &= 'C7FAC9289DA5CFF90B2958A641F03ABB2B5DEC31285D4217F40AB1668BF9F1A9247405F95C0FF48B70202DF1F41AD8FC04B9E50784A2379B108DCAA0490C31F82205430AC2A9F8DB60A865FFFAB9263A11FDF9441222A5B9F1F04004201DF808581507EAD5B51011FFE20272A9A3F7C94B08C8F151F74682328FFDFFFE1008CAAB67FCCB486BA3F0CBF05202507043A4823551FDF7B0230DA3F797FA0168D14BF2B82532F82483FAC42280D7FFF58D6AB62DF828020B140865F28284345753BFC1408BA409A60015025A1054AA9581C93125AA809164C5726DE87AB10C647746278A92B60E3C3477C1E477E188000C62B602DE5B788FC82F565C1F4B664B7CC43A7649E7508B8ECA578080163110410EC350B466A9DBF928D430E82B314681A97600704030C83D3C9430401D1068CC247038134E247B0FE19DD2C89432866C611596DE1432401FA7FEC86899FA657E80C612CE21BB326A0841A8C731A308EDA376AD6B7DCC80CFE5E3819A31B551A4A4731001F5196AA2C4397BA72280600471307B20CB7B5DE580316A117D41B0086542E1FC2C8A0605404FF1F003C0AC05FD069120FF156C6F160A72515D88E7DFC2C8941008F6238EC0D0089F8586BF0B254C4323A4C9A50A2C035FCB6F355A6CA4060EADE55DE041650251A5E27535F20C6532BDF89CDCB2B9D6D6DE8D0F1F88BBE43D70C69018053330C1180D1779F5C9A28B092CC1060DA02432AD20AC84812A65D788D591412C47018666B0FBC3C0356D202ACAD378C1EA4DA70A67578523E4C3101C66211D7419C6F6A2C4165D79685CDDBDAA85A43AA5E2A591078414403104AA0ACBC9C45C845C4243419CA6BEE45E4322994998C87A45F13B461088D925DC854C8041039E412AB99D6FC91446345481F4B5AAF451F7ABDE04140A35AF24318BF24967DF83C786D90DEF7D10CF0248D96834F40610C9E4F6BCE2CAF8C1DDB03CB50D4506A55105D0104E83BBE4E286BD7727B1403D3034A2F188BF81989FCD33CCD3B2E0C08080C0C30F0A6CC100E82741AD77AC772C88DC92BC3209B47AA22353A73F4FEADA5B189308C72A50814759BF8A4851B5C1601109B1004EC321A09368403C334456E708C166CA8EC39927D7B1042E0A62E8BF46B6803D8536130B88F63608B03625F8814CBE5F24C434343F81231013DF541CFB89F21083CEB7C880ECB129C90B4C6204145E8ADC67294018D79142FD3202A62519B83BC910A1F82D838A64E5820282BB934F12236C007D87D1B1AFF5546D4D90379584EED4F80C8801C537A080C4CAD4048958B0814567B61404E1A537B0C1086650A6BC9D747B986E5A6860FA8893775607E75A6463135347C6F0688CEA69D0C454585A8BFDB262A15627FDF4E54E1025E9F831304C9214089'
	$sHexData &= '04A4B10279C13C4920C90D1F83F1D0A61823510CD4B72713158B439C5621DE129E8C4B7F19F11600B53DA32045F2C7117C0889462403150342A37F8382E411208AC4266A959CC45CDFC851D12ADFB3A72079048BF4C6FCA80406249F97D5B21194B9FC0115681518B751B4984C32464622E619690E5646464646B517689086063710488E86202F1A0362FF2F5B1F9A9040C048148E225A700267FF244780BC84038DC422E415C9ACCC38E3901FA49A9DA81526DC2BF1CE5C13F544BC54B150658619667E8A827268C6139D85CC2C33EE9657CC2C5CCA9058CD78069C2B834769C8CD7F4C85136AC88DF034059375255EDA7E8CD2836A47B8E2A2D6D0EAA0E91F1C045C4264035D2903E3A0D1510A25D77B4D8C45959553D20362D0411DD20425B8A725DB41BDCFA1F655C9331E2908E0E70F508CFF8BF2895DFC5738C82F9575FEF00F8D833C7D6708093D37CF6402EC2DEE92E04F2CF632F336848A06A6BC7E59D10142F5AEAAF22E32A56188CD0396F42C02794B0669FD734D453C8C925D240AF7CFC7788D8B067C85D8F8751C1714987A77C6D2FC03B8331306127B9B706CAEF031ECB0EA7D71A270E47EFFD1E093E4903442D853BF178CA0B0084F4C0383C3047E0375FC2A4832043B2B3538B8A090001C35B194B5CDBC7C91DC0C992E1C72C96C7B04A3C707475DC5E898FDF85F9EB80D6315BFBF46C821A7842828861972922170DC40C301810C0F8CCFE5A03663C516EE20B3AAA05624EF2F918824C132EF09406D8DA2A861D626D68BC59AAE90A136C7141CA6185F572BF750725664908825E290E4D0478083C0887F24C5EB79538B5D546A7EA8F221B95468EB03699056102BD44E73B761584F18A854F875B6552B50B5C6C337BF0218716B3F8724908A9FBD13431B43C15E04D21E0019B8219D4709AD48582A6EDA5881F4FD3F850CF2429F8450203B0E0468934D5C49C100D79753961C26920253951494FAA343C10B0CF30C8955E4FE428B74D09A8597145E361238CA073B8712DAAA6AF2DA106A50B4620077A8CE1710EAFC05EBE3FF4B082D5B8930AB80270870EC961F15B826755A740732242D34B77754624808318B4E39CE3C67CE7619142F1057F004C285307004D13B56D482060B0C3CD1197C04EB258445AFDBAA051EEB8844D1BDBBBA032A0ADC0E5A21898D329CDA23DB744AC4357A1C72C046C357E848F20F5804C59CBB2911ED94101A305A0DEFC6C2AD33285A5E222F6EC053E10B764AB08E73A803EB0A56FACF90A5730203C9511DE11BECC2F77C8439009AE845E434D8E120FEB4344C56F2650B020638D4574A82F83B75E4FE8038C5480B0F1601D9690D2460364A7BF3AEA650BAF84DDCFF308AE401A32285D2EFB48A4271BF9F940E29545FDB179'
	$sHexData &= '54C505F803D201AC821335B9047743E0223AC5598C681E4928846575164E40204AC204D9607E40392FC03208CD41CB402A2251F26284A973B1FB08886924328F723009CAA18D8CC14544636F051827DE4C320BC8081E8C137A10A3A057103C0A4F80D362A006F5AE2180B5A8717D223C2D8FA459554D114C138D4340632C1EE6E4A3878EB04904C1BC6A31BECD4746946837EC932EC14C04E08749978F7027205873F3B5618D44506F0481AFE3A2BF9229A3C95220F31A9A01ED23C0BECD89BA021B9A20566EB8FB321E851429A48565055E006E48382B301C39CE095666542D0998CE0D8343F4720E0020D2CCC642C59A9E8D59C070723D1FF7DA6002306490B2D34D172FA7E148D927281C52C1F44A2D1583F3A8D33926701013F85408DD21F140CE2149F5FD8AAAD201FFF3F38D1892BF912280FC025190B63DFAE6761DF1FD23F0E34C42D413FF2E49012873154030A558737624A6680B3C33F85C6AAAD1F3F8355C1563F9E0C020A12DF4420B72CBF95B10E630683C74A20831C4646154497DB00682059D94220AA9FC28090373F8510825470DA9F5FB690226430A08515045F010B8BE03F219216515F1F4E586E120AE76868EA20309658754C9E0CAC1CDF041D82C33F85585C8206D47F1F20062815BF0DA055575FFF8560408892801F6AA90181DF9F11B297117F85A855B06818FFFF755E2006D799C3AB01A101DF98B78C675B41DF0354AA0056FF45FB41608D0C920B1015779F4BE508080C4D0830B253676977F4845F3F500463C5A036C93F61D405518957950C2814F07B04393FB67F5AC22303A389F8F775E73582188904FFFC47A431100B8D0CD08B04D034C1B34DE814E54E068381BEB65E12A3D4DE776C41F00A355E21DB6D050CF6222C08740F7F8D86DE864129411F7EE9C408156A10080656C7DA5905A00E6E5DFF4FE786702541EB5855122436DDBF48AE1A1F85BA348D466249029124A8E421272E4F462C465C9C010B9C8684ABAD8CB4A5FD9BC666188C368E90DC406A9A5D5F0DAC0A3985F0EA060ED659555DC094A242B97F289AC65A8C7F809C48BE0204AC96FC16D3D315567D7B932580B506AF7569AC2A06BF9E282A2E1FBF01C39C51819C48998C08D22AE40BEC6A1C098B1FEF0E243075172802D43C05BE27A2FE803212894E109E22CC48040CB86A423024D7790CC512B0BF0FE4D4544C5FD9A9424458482678041F45C46812235C018EC409033F271C4F8F034155C8C9398633488F290CC903000C81DD509D5FAC4FA1215BF10C2D0E10AFE5FC2FA918AE0C9F3F424E01C996FC0BEC5EC5F0BAC7F83F998CAB5E094A1F11C5ADA64D3784128911191FD45B834E3F291050D37007B6308B504E56498D020B1FB3FF1221078B7F1E0808089E869E'
	$sHexData &= '1F16507011DF1F504B55265F1F83620AB89EBF6DD528015F7FB72876458D3F1E480E34401F8BC1801B843C8BC15E3442819ABFBF221AA1459F845625A7B5E4354209687F5FB0E810169FABE4DD20BF8618DAA950186DA36C75EA0917955092171D049F868232120440CBF624DACB280AC0C9B82904820CB0D8711636D34AA7625B8BD3411F89296CADD5793351D0132406E77D0C5846E8E4B902592AD06B92D80244C14B730E0A7A56D35014D140C2C7AD362AEC05B4247AD72915C4F48322BA665075815178CF146746036100064BA53C78896DFCEAC8EB37FA328053C4D220FB96844442D84B745846422571D88B29222005AA6398E73913A746038B5B44814CA049664413F764E0FD604F9A4B45441349924021148A40A92889D78A3440A6C89A39D03441114DE506CD8CA0D012C6B40E0A0904241051F278DC29620CE1A1D05D80537826FE280498E462C9BA50804606B6B1B2B5774E524A08B6F430426BE690B61A0CA8520D3011A302518692D2AB85113F644D040081C3AFB8C045D0234EF25736B4FFD028C19C823719016CFC82C2DB0445CC3A3982C297A64601620ACF08A5169C7B5A301B298F9A8DE50898AC9CCBC84049388695142A825232249720482134321A0ACA03C83FF845AC58F22062376702D80DA1022CB851FD21856B545B36FC5E148D5114DD058D048611C0E105293BDB45C41C60204DF361B802CC40C2554D490618944AE5D204080C618902A31941D3CECA9D8145A8371A934351B91A2669C0B8722041791A45C4AC085E0172836946320198064740BE652872E9F8F8BBB5AEBCC081340D07CC4C03C8C4B11AA149AF1A8CD0239AB259CF458C504FBCCC0C21933CC0C89C8442909CAC51C800E2FF1870901AFFBF8396D02AF8395D087D7AEBF9E712BA03844073FE2C03F957110018065D7C84302C2C213B068FA7A2841E83C741DE3996D0B9F475087C88F8BA3148052574C4374B8074D23FA0F2F4645C374214DA432598CBE54343431E0C061E0D9555FC6815B1484E2BD38A0CCD4C250C80CBA0C668841F2C7250D85A279F1CC8152346BFE223A2E441C18922E405C8B744B858B04AF6C67F8710698612DA01FB080118360E191C089DB431A8279744C88BA63F8772C829A2E4C4A9B8744028E410B7ECE440C8A17FA90487D21151F220C749226408E4B6A880BC06E0C4E0C1C806DE6B2D19041E180E14AD00161632BF41C88B4A9F8832C823A2E4C9F9B830E428E405A81C54419ACA87D98945D053CC4FE83E89E737E66BA8938C50D85CB9B0202D904E78E006D4E5D2B2D4C006E2208D6086374E9A4BD3AA46D8F8CFB04E9A674007C047D40E25975A3AE0F201DA8D7C42D0FF55CCE636A2D078304C104C848D51C163D251D4F7E473C9CF42D88'
	$sHexData &= 'B06022CE892431ADCA2FD4242081A98B9468C9506FD720AE4A3D88946F3001753F05808F9E9EB9242C18B07E84B04EB2FA4C56A97E3D8F974EED03D822E6F430490894172456A5877EDD4024B103CC87424EB98ED84CC241D431497D82AE09212DF30E0B2B43F56369E00C4B41F2A6997EE7D7435DFC1E30525DD20CD03D9F854B40D7049433BF175FC1F3255253FF8087C8F95F44A72A745F14337350805BE796B088A1BBAE054A380250568C6039221947041FD4116F409358CC62BFB92FE90700A38C1FF05B248A11C327C90ED8680ABB2DF66848148BACD60A800226913BF7546935539FCC3A7D242EAB61F065C3436E948049686D48830529A820222FD84B08A10035C2884289F5F10D67EDAECA4FFDE0FB6502CF90AE17430F1480981F2DBD207F9B2F72033D1280A1D170B69CAEBFFF07F45571823D18D34D55B570C03D68B0A39AA96D44C221DF81111EFEE0BF00A280F4C1604EB1AB7105A3A9CEB08380D08772DB80A1E263621E48362378235C37AF3BF9D18C955C35FCC860D83D8AB7B7F223484827B42461A0E00F5C66A18C5DF7FD00AD9905F8850A0E518CC94CB18D378A1B61B2C31910BC42A57DF6DE9AA965B14B06423E465EC20CC024358D5FF1F06FC5456F68283781C381100BDDE8D701CF88CED4D6B68D5F857BFB3C9C1FF3395FF0FB60C324233CF69F9D0544B188B530C23CF5498978A5F0ECD0C320B85409ACA4B534B2D01430D5DF4D5043048A5A2DFB2548005FA1421D72764BEB36A74428B387F9F119422581FD62304914B424240B7424460394114DF11830C06477A551030C2B87E3F60328005DF281D4009F7C51694AA1FDFA638444C14B35011D6A234C51F0490A0BFAF248C4E581D37565B815F1F9F128E123208B99B68940E9E68083E9B38303747091E470A427EC958DA470BA2B9BC6B4BDCC88D14CD4BCA5CC069B4D63979D1C78C9ACAA6E840D043440A47417D762355C71636E4248B37DD92C82D48B03F13030318F26055135F3D893041CEAA03829F4F7637574061E8947FF80A212508651F92BE0B05DFAE837F50E882A4FABC5A54D8C00E3B2DD9255DC8DBCBBE5DF881792918C69AC5041197111C60550F97C66A5B089F40FBF6183D7A840CF73944F7E6279832763AB6163104F76BC2DDDAB6105FEAF1045E6B208725DC7B445F194CCE854622B34A1D1F6A190BA0BFFFC5458CDA1FFFEA22BE88DFBF6A4017B19F913C45005F0410EC15E20284DF73D02C1C701DC8251F55F94DFCC701417D410C9C47213C04EA65B4A971F4BA51F015427830822FFFC91415A4BF1C202782607FB7440C899057B858FF20870879117CB874C8039257B7ECA904AF203845B6A87FB88043510724B813C9203F805E401004813C08829FB83021B142'
	$sHexData &= '5EA81CFF51F2B252D181B151D0424B1FD258B5157F08C5B635DB9B9F991A7F484ACEFF30E9186D894AE95EBF839910D0AA1FFF248B95BC0071E8FF7B9E628C62040E1414BF0474F9D05E08E429250F68DF73286DC008E85F9FDF86223430EC7F358103BB4838F8761C55102292037FED5441E88A48DFD1836E52894E6C43DDB924AC148AA40BA1FDE1C790F03FC303E50C720299A07F7CB71C810CEC50E51CDF28220F380E88483FB5C0C1A46949FE2424DF2A4E03573CFF559C34915F11BF707855084AA2025C19176D07C1EB0C3F2C83D6050A1F234C5F70103892BCDCFF49FDA558BF4B00DA7CC6A010AB979F012AC4E89F83AEA555607C9F5F10AB1A300158C1C18ABFA39F88204085A39F13C98B658D3EB12C118242AC927CC3407051313F12A3AB621562FF3F1AACA210E39E464C3E687F010B4C1F2B58450A57BF8205A811037C0D1C74C41F0CA2B0544809ED3B3F34DA481B0C080C5B10A70CB55F0C0489B54BAD65AD5F06071BC19F4C83D709AB662C9F714BA90ADFBFEA9652851FD7ABB66AD07FDF402DE41D3FB5C04B3016EBAD247FEA87D2905F22020C12DCCAA37D2DFB03FD3FA9042A246290ECECBF4DE054F28870B91C315A287AF381B0D001193BFB81D1CE24BBFC50926F023FD404130C501CD01D56301F22533C495E235C1FFEEB56CA280D607260B7134C72042B183FBFA82E35841C3CF9847D09437714ED701456D530344597E8E602901C80C275468E002E10726A00C3151A0C24A30DA030204AF7F3928406D50290C43B8C024DB88BD40AEDC3F222B8E4445C3C4A289967E17BE1770481C6C876CEB10B847E39DC832142E326C542DFB3D39A084836054BD80BE4D205CE0618FCE82341DD0453F2D6CCEB1E42C103440248BD8AC0458016EDA5C3700548832E0151E0A11FB154FB8BEBC3EBB820CDE70031E08D45E00910BA21CDE008860384EE27670A519618318DEF37470BA5E4180425311F88D880AB838BD38A8D890C83A0237BE4490843180A80A1272030A1DF88F004AB0A413F2D403020067827349512467F3007524D203D8205EA034B0C7D28683A44DF8928FF202708E4ACF1253C0AE400F16BF125C90190978950B6A8BC0239048970B6A82B905785B6A8411142C9B880FF39209043B638F4A3400600F4E400E492F489741908B9808974A740AE0A74B7EC50904C248A400E08E4B908F8E4289001F8F8901C00B98AB744905720178AB744720572AAB744580E05C9448ABA5C00E48040FB1A8C0219FB30C901906BFFD0BA5079057204F0BA505720AF0ABA50B6AD2AB592F43FAEACD44E1FBE100C03A5EC0EED4284E53F0FFC39B9404EDCECAC40F2262DBF8B101A7A02083014191A42910C918AE420483F300D1A089910503F94A221007F4'
	$sHexData &= '5C3002A7F7F43008A3190BF7F53513045B03F10A0100321D03F055334047FF03F70053215108C14C98108FFBA50998AA4203E3010500CC02A1FE2629288FF491C506111B9FF8C5848012C5F1397181003F4C81806548014FB417C90EB4401F0018B4DEC2D3DF1908845F00302FC84DB09A75309C8CB26CE81ECF08412B681B8B413C50A34909D9F900962587F901C8A908BACB87413210785C0B6851C8A9038B74490132107F0B90803851C8ABA508D41C8899020BA5C484B131A7F8D4BD7B246FF88D44DE8E12F6B0BB2B4F1525D3A318509CDB3015708645D5B638AFB5BC215841F703F9040869F30E5C40C0C0321ECE5E8135AC995EC8EE12B2641040BEFE5EC5501434B77A9908360DFB000728092AC0CDF4A1E854CF0B6387900C8010DCF8E3003943C0AB9080E28640290BF704A0E50F2BA5C0FAF0B3A090D3F6A4B3E527EBA5C3F89E44472B908B638222517C9B8ACE42D29A52E5F59CA67624448BEE786ECEBC0C68B566A283A8C1B8C5D654D06629B951F4B46104E205EC3BF33F1089D8B12BD050481826DC31F19A3D3C2E4B12CFF48CA47C98EA0F96A1CB886A11039A3541086898B57D60BA39B80A70523994ED11CBF684805071267DF341A4BBE010B4C3F91921E8D0388C28AAD6D3FB9626875B1BF45CB06A51143F15807E0A2A2DF5101C403882D02A924023B11570BA7041615057061511FF6443C2E96D4EB9788A483E2BCFFD03FC48850D2818210B8A0192C1B421B5AD7B14F1F811029C15D40E06118B73F402E0AE48F00302E0AE4A2609018D588401F81E5A410A617BC50E4E40A9F168C753548C51F37E03FB8150742BF5E20E4401C5F8BC172200ADCBE5F8BC1C4656B109FF2960079BA5C5FB9089C083911B638B8AC60955C84E4ABDA9A041F3F900374407F87105BB52507B8E43FFFC9047244A4ACE4052017AC82889013C903B638B638E401F2027248B9087901C889B90888A8B644F200BA5C3F2E2AAE3A3F087F082E0A2E1ABF08FF086AC02D0A3F3E9F66AC1AB07FBF40A001AB3FE810B1681F9F187004E804215FE48A9D81089F133911C8ABB908B63853202702B8AC156D250320E45F2DE036521F117222A45EACB638969C0839B908BA5C5815AC0ABF9F2054B02A7F5F8206D2AA3F783580C6AA397FAB0AD0583F6E51011ADFFE14D76A86B9BFB4C58016DF3FD616850C13FF8A5545123F1F621804225E1F5B14D2253F13FEAA8D28867F1F4ABAD010FF1F13FB14D5B07F2B49FCE9B03EE9E46CA83C0FA74CAC06A0B8CBE572F90BB0ACA8A4B95C2E97A05C50202497CBE572282C30343872B95C2E3C40444897CB65E54CA2E8ECF0F4B9AC5C2EF8FCA3000497CBE572080C101418CBF75D2E1C2077E01724CBE5FBBEE40BDCEF0C0B0804B95C'
	$sHexData &= '2E9700181014C497CBE572C8CCD0D4D872B95C2EDCE0E4E82E97CBE5ECF0F4F8FC72B95C56A10004080C2E97CBE51014181C20E572B95C24282C305C2E97CB34383C4044AC6A4BBA48F553C8AB255D8FAB799C13006E58078B7005A4841E80502DB0D6CF0E60B0F6128B0F6A9A312FAFB6138CBFC9C356EB18108C058D4D3474A3F0B932FF25C2D594FB59598B35299EDE5EC3AD55BE80090427DB0A4D4F32F12D3FED82CE280211FC59586AD75B6F0D818908F6C05E07904DC0CDE82E97CBF7DB4C0B5054585CE572B95C64686C705C2E97CB74787C8084CBE572B9888C9094B95C2E97989CA0A4A897CBE572ACB0B4B8BC72B95C2EC0C4C8CC2E97CBE5D0D4D8DCE0E572B95CE4E8ECF02E2B97CBF4F8FCA20004E572B95C080C10145C2E97CB181C202428CBE572B92C303438B95C2E973C4044484C97CBE5725054585C6072B95C2E64686C702E97CBE574787C8084E572B95C888C90945C2E97CB989CA0A4A8CBE572B9ACB0B4B8455E2D97BCC0C3A2CB65E59B23D00BD4A47C78B95C2E9774706C686497CBE572605C58545072B95C2E4C4844402E97CBE53C3834302C017AB95C2820246A61E1D34F4C3BF010387CFB1141A8EE4A65FC00BE3405B7D1C6C04E81FE11ABD55513943E3A0A1E2F0053B5A078C63E5A90B810D8FEC5F08EF3E93225C9C20C004CFCEC248130C42BF88B65E8579A7809F6B8CC9633C081129DF1FC7D0863736DE0C39914AFBFC201396E2C30685DDD6ECB3A5F6476E03B0D1FF237F01DFC7502F2C3F2E94AFF083BE6DC0DE09EC0D8A5318F59969DA4542C0E362DD7F897F2DDC4C36A07E03BEBFB8BC83315BB3789F0E11FD3C8E627CD44A6FE83E01F6A20593A322C338756AAB9052539BD85EC296C8D578FC62F84D73D68A00F08B255943EBD207C5EA6D8314C751500A4C930ADFB7EE6B7698C28A71C562B441769A615A038BED81B54F834ECE21762DB74385A3472A1646CCDBA25CE8E0814778757BC0E047BD3577B9156A326C286BBBB0C15AE59591710EB1674505003BA73C891A0802708306038A881B7C9BBF1A02447641ACC6EA76092A190A16F078F3C81095C0B1BBE3F7F9C8B5F129F9C8320F9985E5DA0EF6B31DA2EBB47ED0052418913F35109E1568908D3700089D4A43BB59357BF95577E93A4159C3E002E0EFFEB296A64B106FB05E60959EBEC2648F1A78140304B7998E0B7FF6878C19CC3B97525E2358BCE333584871E0E7791CECB3A57865F7BFFD65EC303C04508173B5CFB17889B9833833D453BDF29EC56752CA110A70C59D3353CDAB1EB2455980C47375C3B62C584855E21DB111EDCEB0D3AE64318C80F19D97161951EE6407EFFC0610F378AE983763ED837963093C4EE40A950A32A5915EF6E03FF483C03C80FB'
	$sHexData &= '7414E1803D010066D1459F86BF02803F232193D028C1F264A0C72CA03421858C0B614C872AAC228D6B2086B0321F483ECEDDEF9E99430914226B94D5AF1DF0FA6E408751CAB81395045009700DD7D94B80B012D411875C1E085A0089226C356A41FB2D723AD742021508E188B2A127090981E106F9378C20AF6DB214A1780F0EB610582370AA93F12EB18A525D2E0EC2C034E442870DA37EADAE1DE59E62BE11675FBECDDDB43178943E4EBED5825E40959781BDC18A2CF75191B1AC047BC7513A11450D6802B161EAB550E1C04E208AA76FF4324225D310CA1A96FD7FB202D4259ABED9ACAFDC1E00C12DA2143EA59E90BE0E05BB01D06C605601C019F6C98C3D331DE0447190A6F098043D3E70AE97D461C6EF4E580111D0074A2CE32F46C0B6760080ACCBA547D11268AC3111C3A2219363A12B1E9B0741D2C5946EB4BFF701FFF5B8D75F45762BF5B6D83C8FF301580207804ACB32F5A4CA500412C215A7C30BB64275F811D013ACB221CF9D8056A08503C30059FA30844B83305FFFFF0E45D46FE70BFA10C3C81B819434CB98803EEA3E322483E9AB93734D8EA2D8AFFD7595B2712E1B76CC67C218F06FB46D8DAEB1F7333C981380578C6B08920D094C1B87841AD221141B6D5AB0C823A34B080F509BCCD870C3DE187ABA51C0608BBA969380C12F7E70F0DD2F42008FBE7ED201190E14EEC40567F0CFF18A89D48EB0BE93C59F7D859768E26F81BC0F7D023A2752C6F46BAEB71065D234E8E732C59BD7676F661F9330D8FD848293BE6495F6B97457940B904A774C39AE15621BF21960CA5E0684A51AA03D0836270414668730F49B908DCD0B31084846319C7FE77D02A283EDC78258D5F028D1C9E8B0361123C2CE8800B881178BF4E0140044279E48B6C7EEEBB27980C07E3435A5989BB895B900BDB8BF72475BAD97B3D90666BC119BF0C85F07B6CFF36398326D2B7D86B351A8321482B672341BC026556576043AF2DC1B75FB68DB791EBBA4D39E07E3E1E7530688016833E466F569EF0ED594A05BE7E87F83D97E56950AE89818B0E62010A341B4434C0711AC603983FDA2A95DB330801742011053E40EB2612BA37BF30E5EB050DC658A450D5095E4EBF354F5C1077247812178D244BA70F8B36A6046A10355035039C0045565917A0E91704F0EE4634975B8845E3ACE782D1034E75E5145C4930C5C6C5708EEE6B44A74FB8964D1041E8099FBA8B95A1C5682ACC09C47443664AF7742B7529598D203BB8EE3333958860A10232DBE0B08C069B795B47326438BB52671941E27AC05989C7EA1F5686323444B8A63EFE0C6A025436D586A64377FF9B3834F78A082176CDB454E379C8592314B8CAC69B3C70A171547F06F733413C5248A31B130D76A7E1E4090275FF'
	$sHexData &= '312623AD7038E213E814643882CE09576DD4C1D3E5BAF0EA0C1A999530400ABA501F8D4922E42D0462399097757A708ADD0F39F3387F3D37E119FFD9E7DF4446080274058B5D10EB315357E77C420DC337F14E100C9E490E39CC2D34FC87B08FBEE50142DC9C7522281E53502FD36D61AA0C7113B2B0037BB4DB0554037548AB7435FFEB357E268024500151FF3635428D220C005D4801F7016630F24633F670EB88949C518BC65E35C2D1A07C7C2AD1FFCE975118918F5F99FF27279C6014105317C9240E6C4156E936EBD5DA9B9177FB005D1392246CDDB89ACEF90E384CF8C65B359701C60D404023C8F457E3D3FEE310896C068D2BE05931254135048A5E89A68405B6045016A902C1D7784045F085F2C3C186353E22DF51F2FD15E0173C1778ABA07C680908C06C433FF115A01974755A2C4C05243E6A1767AEDCEEF3174874056A0259CD298F40AC0A3C8915FDFCFCFC38891D34893530893D2C668C5A679ED631580C0D4C412828057E9AA7792425202D1C9C8FD65510527200AD440E8B50E59504488D45085433AF948450AAFB900233F83E5DA1284B4C27406F13ED2BC3F544014B506A04586BC01E80150E433E5402E8B040CAC8F74C05F81EC1E0081DF5D1E83C80FDD70DE73A9227E48604091C8B4D0844046728E4F54560F0A93C88FBB3E4A892829A20E03FF00AA340760A8C7504B608775DF20C1F0E760722488906008BA07B0C407350D3B66782D745EB48FC92060C3B4E73155C754CE00E6E558C0C8A8911187E02B04E58EBDC27A1E1880E045AD7533358201BDF6A031E3DD1EACC0250403E5110DCFC1E29150856FD3E88ACACACEC0B95849D80B57CBD78E5E5B7E12C95A40D8D989D74F3E7E5E58570A56CAD689C8F859C9ECA6B8762AE94108DA0C7B8B4EFF4EF018B40FC6A503A90A876A2702113626620D34C4915460084AC59ABA78480956C48BC6E930DECF7DB5C3B0BB93EFC931ADB44FEC30BDD845C03940D640C84DB8C032E7028E95926D9ADA0FDEA446A4448BCED1A65014974E168F6452806CCA17ED88C080A589F3D8DB8833468AEC74C3E342A2B7EC8251D12837974C00C8312C982B9B9EF149306DC042F4C3D9447C3A27990F52FF5813832752583781003F7260AEF3C40143D2020741B3D210D182CAA341A220D6840993270A9030AC9B192D9839F68915C00A7612806891C04E0E67FA50B92EB8D9855F32E275C8324A4062F83697D302567546D29A05C20579B6BC365B4BC180528BDB4C3DF00A5D43635465921C631DEE2A32DC659418BD82AB7599B3B80929031043E113CAC90CAB5253944E43321EC908764005C1752FCFA33DB43090A7010EEDEAEA83A193A580EF0B6E016031E830D35867EAFD538565798668D7DDC366483C20F3'
	$sHexData &= '4D40C00161378E07D01F51BB481F747656E75E835696E6549A6C2F91F528B45E4356E74656C1475AEBA61608D9003A40BFECFDFDE3C0BC789738A4B0889530C754325F03FFF0F3DC0067DE5F60B0074233D6006020C1C3D70153D500603C4769AA7280E03070C7511DBEF1B40AF6883CF018911EB0621C404FFEE7DF407F0E67C326A075844EFAEB08CB1E5E0F7C300116DD2CEBAAE8602425D12B4D60C0EA928102C66FFBF110C2A2005F7042E0008740600B6BB4E0D107447B20F01B820D801001E0AB3BBFFA54CE00683F806752EA16D83C80871031969DF3DA323F6C32074122C2005EFB0320432463C06391378E1486A149203869257B98FE1086880EDBD80BF59EB08B86440FB765728242B071452094CB5DDF400780CF800F758EDF7A4238226FC1DB431114960D6CE6050EC496499B9081CB6361E042FD615AC0AC19807F64EE640BBAF36D0ACBE2AFF940485CE754982DD18BB098BC81CA2F0F7150A4F38EB0E2A0A0D1147D6EFEF47F4100BC88973F7D15F11085ED329AB3C4691705417757605D5FD5EB816780B80C3A9B95CB97407628308C81BBF023B00C3DF4404A6D0C33890DC6CA50EE0BBBB093BF37319578F92CAEDB02E72E916577474E56B0D8401440B485D2E97CB4C5054584095CBE5F2533C38347CA4B95C2E971864D8E0F42EDFE5728CF81023DC98E572B95C00706C08BB5C2EDFAC0BF0ECE8FC5F5CBECBE560D40423C8E497CB77B914780B84C0BC72B95C2EB8B4B0A82E97CBE5A4A09C80CC72B9AC5CC4A09C98942E97CBE5908C888480E572B95C7C7874705C2E97CB6C686460B4AC3970B95854C4058017A70CC157568CD72251BCFFB60BC00F24E11010A8F7C8BB67FAD8F7DA83D86A26891C361CC0F64C32181C182E75181ABF7BD3687F33D2F7F18BD877A6BBDF840ED3EB4116335427D1EBD1CE64BFFFD9D1EAD1D80BDB75F43EF0F764820232A0DFBFDFA4E603D1720E3B4E770872073B5676014EA634B5B65820D88395C66FE083DA005B5E5FAB5E45F0059B5533ED63154745651460804C283AC3C102F71C2818C60F28EB4785DBFB72400F094E2B301B241C33EA10FCBCDB1210144D79A18BCA7205D7010AD978C95DDFEF752F9E08EA0A0A0C75091E04F7B3EF81BDE132530A5708EE140313E1B87C3FEE03D35B34B32C0B3090938107A9BF7A088DD41E90C2544A4C2999D8D75F14DD88E97E403FFCB9E44A2EACF8D09213ED22F4BFDE18928BA40D3E3C68AC995842861824FCCFC0D626079C014F1322AC609FB2DA46C169DA5E8E3CB4D44D2E39F60F65D0F4984CC8AD48C059A488B450F02073DF28236ED880E0DA84DC5B5C7F2DB9A898DF9FDFD8E4D8A7DEEC827C4FF0638A176C99D89FE00C3F922B69833E30F40A9681E25C7F'
	$sHexData &= 'E8FF055B2636E3885F4EC35130D47FEC1FE120E4D86740F083DC4FE8585A6AB854FF5EEC491B243F0F01847C829845F488611FE1DC9FC701868A3E5CAFE2001F60EDDA15F04F2C9FCB0186A14FE45FE260416818629F945F3F5B0D975CF4C05FFF04C13201EC5FD0712079E320E354BF9FAAA5E33FAC6EE04ED082FC495BC921C8BE88320D971CF4F01F8B01E400F27F2CE41CC8018A83081FBFE44841D3C0564F7CFF447291B43EA8D419629CE4E5006A28AE420AC668AFDCEC14AC636DE46DED7FA819A8C645E0013E000314FF3A5FFE8100423CC371E5E050019660DFE58C6AAB7851FF401C0FAD07528362B05FE5B55CBBAE85F455EC070D38515FE620DFE64D8155804CBFCE0E3C44D7A79D7CFE0C348C75AB1DB0E5E678BFE0FF4BAEE4B4E83FE704ECD2964F9338DFE40EDCD3C47072D4C849C44F7FA1E200E770617F003DFC6118901E6FD0CCED396DDA54C37DB3C09FE820B203BA29085B6CDF0059BB94B4417E74DB7E9CBA0E90636FE8B8FF210E1C60E4BFCF295A9B74CBECBF0EB84403D260EFE4E02DA568804DB8FDE9A1900139A48EC0ECE8A3E90099C0E87F97542D053EE40ED8D8A469F580FE1F0E80B099908AE5D8F0DCAC80697200EA30DF573BD174EAE83FEB143FF4B56BC92540E13976E453CEC45B7C7B4C6FC82A300A2E6CFD3F3C800107EBB0DFEBDC52047890EC081FD726640A6FECC47F3468B8E46ABFF0885F252E92367EB4E01FF222E441ED1CED48C8B113237F8B0C5FD8210D1706838B5DE59131951512A51DFEFD4E29432C0C9072ACC38F60AEA5A2BC936A638A54AD0B037644B9ED6CDF070DC1706D9CD438FEF6DDE58138FE300CC3C3B5D575813C1CFEFC9F21C8AB863FEE30294872557FEEDA8C6258C13BA40FFBAFF260726D887FA0DF3C6CC921189B28FFEF6D2D150DE4DF7F14E8E4902D0C331400FF1839813C16C1E0FEEF10C98126047FEF54920B640BA6D4FD804B06E4DA5F94F01AACD092D83F8D108B68D108CF6575025D201D0AF4F09FA16192968E20D459E40572140500F07482B45F2CDF006F6C88742997418A6EB413B4D95E13A7402857C318D0FE4D5C833A5C57193A52717D84C89B6CDC01CE6757E907B0A45D2175D7E754584E208FE1DCBD54FEF0B0D296074B7FE4A6CCC8845C70B489FCFC694E0EC86808FF60F84B86262F04FF45098AF333E94BBBE41B2979F1A09EE06D39C00EBC77F2385FEC353C612D2170FFED6CB52513F27F8F1B07C84BFEA0EC7A28F28ADFF330FFC8ECC0F946CC0E613CBEA59C034483BC613CB493F3F64213965C3F6FEFD55613A6B83F4FB86062D4E47F0835C01D5B4E2E55C4C485B0B4840C7087F488D03294F89CE4706CFFCC2A0D9057F464BFA8C9019BE46FA8E876F0023F235BEC1'
	$sHexData &= '3FCBE1BE37CB6218C7901580C150C1A0E307C576C13F4DCBF4966DB9BEC9B719DE872CC3892E8F01DF586BC28C43FF564A40041BA8E24CE900F025AB11FC35639306158FF2F58FF3C712CED487B568CC3887C55FC68A8209F765C0F4F1F20F2014B5EF5885EA0FE55EF881675B4B5C854ED737B230FCA840F940AACFA9C40162C27C47444FEE30AF2F244FE38FE4D52AB2E9038F6D51E5B1EAC9FCFD47F6CFF2EE4924BFCE8E4C8836E540CBFF71CC90132B55FDC50801C7233EC0072ECD0CF3B2871841F6C0ECC5144DA2B0EB8AD534C34B00EF2020B08DCDD0C34FF95923C40F7B89F12AF99E4E8E8B4A913A300AF6CB8A5018EA5C1A45CF89FDC2E857671C898FD9C7724F4ED3645C7FF308B8025DC3B49269936B815A064E40871C8A8FC88A968D800B2A5EA24FCC025B529A4853480C0D3D182455B8777EBDCDA92EFE0864F5CB386A6235310550C4B6C820A5D90CA9CFC101DEFBBF2F9AA14FCF94CECD4FB02A3FCA55F08D21E0DDC4260F9704DC31D954CBB4C7F150CC8B0C702FDFDCD800CC1C30B20DF00AE20C925C8FDE8E6330DD3F56875B8622CB343BE9110DD50B4FCC467499BFCB4B46C14AC2FF8FBA8EDA428489414BC70CF16C290367C3BD3EA58F436F215D0FC8D2F438C50B165F9C85D4B0E90FBF8DF6DC4D26053B0EF9203C8713F9CFBF8B1BC7563B8BF0EA01F220F0A3FFC341CD0F72087012F1A3C55C4F77014441EFC787F481107ECB8DFD473A4041CB0A11FC44FD0684030C4BF908F1C3420549FAFFDEAC654095FC0792939405E7EAC54D261A493B0E0DD14C8658209137CAFFDEFAF268D4D2DEF59C3B916745FE9D37D7A440C137C437C1F83DC10411E24FE1079250FB9B744437CFE6C24871A155FFEA08B16490B3ECC5BAD82AF1D5F219F5E1103AF63FF245FFF602E9216483E8CB87228B848E45F534CF215F24105001005004C6B079D58F7E86B4DD5584DDBBFF0BC5535AE63ACBF4ED8A420D0019F5EFC07C821AF631C620100DF9092207F03043CA65B55A3AFFF86BF81E2808DD3883F6800AE800C0F1FE01E805DDF77BC1F40C1D4013C31F18C11CDDAAC01C5FF400B244F0502683E940A4D5E1C9F83DC9F162A64817243FFB441D10103287F3E546D0413B05F6280838203457F03B4DFA2E022693ED8FC5F4405B0630473BF14BC55F205044C4E781F975C491B3EA4FCC806965C24ECA33A4D661F10496823A5C8A82F19082310D2519B1E1DA31C6CC85728899405BFE432205370185C039942261054C031340A29BC3FD052843A05989F3AC433DCC0C51F023FFDE8AACA0945910594806130F79F9103EC91E3849F06140D92174D7F06480CA28BA43E7CA85FA32D3926DFF06BAF23D084D4DFFF070816491B243E2CAE2A6187DB5FDC1608'
	$sHexData &= '794A05077C5E14A49880C01F3EF4C3453B9108203F44BF0DC913565EF0EC840413AE6B685F3081DC467F7F629CAAC0A38A7F08D07F53EC42B8099F3F304946AE08BF08E45C726CF9E4FE8B4DE081CC7424DDAA983FFFB8D14E145DDCFF0A083FA2C045722C58DF551C20780217DC0F0A8423E4503020DF0AB00E901628BEF40C2ADA8043083F25ABADBA750B385F4C64391472A21F0B900BBC39909C080C000C34AC5463220C9F700C30FC3F128C1D0C1F57C70A0B5E0D810C12510393B8DFA34A08D270E46F5335740ADDE0730DEA410526BF0D6C367508A1BF9FEC5F968842B8989F62E411EC03D75F0E20FA03B89AD01F3FE01C03981CE0BD0E6C0B48C30E5F44D4F899B7248009D481C1B074019FF6FE5F5CAEE0A50C594215420BB2E83F69000E38FF0FBF0132EDA9E4C85FD88BC233C99CC49CCF80147CDF8EDCDC0E6B0929B8EC0E8EC0BF8414AC82C08F1EF8A360584E10709F4ED511D110CC1FCC3F1128B99236483E80DC72ED4A2EACD8BFE8C989E4441240126CE3DA55A4FFF84FA8925C6D753F9FD402AC6A15BF9BBFB87624AF132CC83B58E89A1A047FE7698166FD7102A60C3174B0CBC87561DFE0C81511071DCF13BD68D02386FF14201F2A2E92163E4C787F928BA40D3EA4D0449A482EFC15DFD0A1C456534358BBBA883FF06130098B43C961A0865BC9BC638D53324CC49FE005900F58C9164CBFD4B5925C3BD06BA0FFDFE838BB030D9C0F019C9D5E171806E4AE247FF0F0AB104B4EF055E4DA15D317887FD04FE0A6E8819009DD4FA81DDD1840185FE0E041B1AE3BEC1F1964B99C40AEBFC80EECC0B515722019B0DF252780E11A049F1A500C617F238F1A3C0F6F58D25672B8829CA0E515045F1AD0B84A0E457F1AFC1B48DAA0CB1F3E5C8BE422B988B4B9DA89AEE05F1C0C3FF044BB482E386CFF43C815EB1C985F081CE8ADAA8CC4BF4EF0958870A2FF1D1CFF3A8D03EC1EDF1D48BF72A2E0AD4E74FF1D983991B4417ED41E00BB48DA203E3468BF2EB9DA45943FF8C07022B948EC1F18C9453B513F1F447F7015C4022103375A9B3A81BFF0732507D8A8DFBF201C5218BB843FEFB016A830BF7248BF80130507C8BF20EC4D84BD98FF04FCFFE5A011D8DD5F21530E41A41F2178DF39113245B02218C2DAC42610BFEC4B912E5AA8BB5F887F95CC81009BEC27A4E4DAE07BC4FE1A203890C4B89F230132B595635FB41C2047C834AC60482E2F989F0EECC052B0951C238C7F989C2869D0241408202FA81F245879508D55AF6F249CE4ADBA300F5EC8580E9023B0F438E4105C5F2520DC07AE1D5C4FDC4B4CBF27BA7100255F25A445D2065DBF3ED0E236D68D5F4F6C00D914DE2628E85FEA82964CE43F83E42A443F26466822693EE027DFE02269833E3'
	$sHexData &= '864B8F000665F2790FF470DCA0327BC3F27112F288DE81FB3FC12AF2EDD0F03154CBF2848055E20719F845E5C75520E30EB3D9128840E1403EBFF3F28B86A720553BFE44E18093ABA628E06FD88A70EBF134CCF015B05AF2918FFDF81146C3929545F5B3141F155FF295FFF57D73210E87FC80DC9AB425F2A1CD0DAEAC2804F9F5F00394206B0C8400142722B183FE00A0DC42BBBBF0039919C2BAC2BD8AA13709D2C045F2C305F4E4070022C5C7F2C88C4009D482CB4DF4AAE82AB2F7FE0A107B6D29F5DEC6E8EC5490CA83FC834877C97C4C33102FDD44C320498E3C02D821C119BBF586D424EAA8E08ECF05B0C14C172A4DFD845B113852E24BFD4524CD270DF3ABC0B8114315FBE2F145F48CF25B8DC6F487CC225C7266FB47044950E205F307F02E404ED3064FF309882E444723160318C2239017231C032880039417232B432E82039919C33B033DC484E809C341034D88BE4A29D35043F38B9482E926CA0D4C945722236083C915C241770A401395171D87F370C25C79693C8F05FC845C845C8408422E444C8C8380C40DAA0E1501F9E941A80E564C4EC9F57B1240F38C87F398B928B920C5044898B9294D8DF19905331E45F3A1C0811726D02F05F7411721172B8FC4BB408393B40FF35D426971CF4C86BE55585E53C0C213D54C96B90007F4860016B40473532D248D420856C488B2E7F29559664456964502B206F26D1C9DA27AB304CB494F07E4D1C52420E0A3D29899B340B4C708C4402AE378FA38DA146D358C79FE5C192061F9C5E91A0802216A4BF64E3D9E256AB92FC6188D0142E999911C651B007924430C831350004070216D222BF4C3E968815F1F281C6CC464465EA12657211C9D4DFEC9C967C1814BE9338A0E01280FF1FF5142064B42C8D1150B11F84283A00019EE7793F6458050058064A3A8AA4EFB5DD797A0126560E3206480E583CCFF33C6870808E9CF93CCFF3ACBED616307DE76936DF060656EA7CD0BE9EE7799EAA8E7A5C40303CCDE779180AFE7BE6BE799ACFF3A68EF255E2CE27F89EE7BEAC00B698553FCE749ACFD336B85806DEFC3659703CCDE779B6FC405A8CCE7C9EA7F90E5B5298DE185CEF3ECFD350ACE0025D4606303CCFF33C446880B2CC799EE6F3E6225E567892D37C9EE7B6D6F8165F3CE6F33CCF7696B4E216609EE7799E365A7296A2CE3C4FF379F20661263248F93CCFF3566880C20462D37C9EA74C8AD81A635CE7799ACFA00864468AD0A7F93CCD126560CE3C667CCFF3349FC002676EAAE226CDE7799A686AAEF234697A9EA7F93CBE046A4A90D2BBCFD37C186B5EA4126C3606E7693ECF88CA0E6D5496E6F3349FE02A6E78B8066F4FF3799E427ED81A705C9E9EA7F93CE0227164A6E23CCFD37C04722444628079'
	$sHexData &= '9ACFF39EBE087350A0F33CCDE7EE1A74365E8438B2EDCEAA010875161C751A58EF9DEFECB6F0570EF856161606263CCFF33C3242566472F33CCFF380929EB2C8DFC74DCFDC021746EE500626789EE6F3341006EC777C92679FE779ACC4D0DA77672E793B698E6C166E78E478D49E2EBE9183CF58807A7679961E5A7DF3BCE7CD17BE36766006523A79CF7BDEFC261E0266E0C606B4EFCD3EEF941E50887A773C167856B6CFF39E7B06828F1E1A0610068C7CCF7B9A78A02416CA4476F2788393E78DAA1E9462488E9ACFF3BC5E06301E06FA76E4799EE779C6B29A7E64F3799EE7462C200AEC75CFF33C4FCEB29C886C50DE0426174E3A30E77923CF11023B004006608075677B9E90D0F04601100720EDB4872E8B042C46172B8F06339BFF6FB4D3471EA93C6BB92807D3119D7BF81EE5422EE4F32EAAABAC422E6492ADAEE4422EE4AFB0B12FE4422EB2B56DBDFFFFFFFFED6AB53F8A4183A67F45229DC8727B6F2384D33B8F428DAB4EA1439CA31586DCFF6F7AD762744E7E4C8E3F2A33A7A483BE6C83E5EF5E1D4FFFFFFFFFACDEAE4C43B608CECDFD4A1C7761CF43ABC75F51AF39EE859D739DE0D4CCEE44FFFFFFFF8EBA3FBF8BE4FC585570086666AD7C4C9A1838A2310B833761264E3A0931564EFFFF2BFE853642C156E7DCD48CD1244A81A441BF531C219CCCF7973AC542FFFFFFFF6D9A2225488BB75C99E2B9A8B8B5E45B1D4AFA2D459CDD5DB35105E7EBD1B20EFFFFFFFF8D8EA5A84EAA14108074B7B6F9CE3BB3ED6602774AB90427216099E717DC55E4FFFFFFFFF2B30916438260676ADA32481CFC66222940ACBF478CFCA85B89A655DEA0627AFFFFFFFFAE2CEED8499D071BA8A927596E135E87631D1FAB459195A29B6066A650C9BB19F8FFFFFFA29D0A0540A3EE3A421B8BB06C23185D027D6C7B44BBDBA3CBC3DFA2FCBDF7FFBBF7006100700069002D006D00730A77166EDAF9ADFA0E63006FD20065227300791E688954EFFD166C00310A3206305E8ABBFFDFD91E0201496E697469616C697A65436F6E64160A47DBDA7656617222626C82530665702D438D52FBBB536F57616B65416C6C693F049BC090CDBC5833B0F3DEDB9E2406901EC5603870066046A03E77FB6E3E82176261642061966F6361937FECBDFD1FF236AF72726179206E657720BE6E6774686E13FCDFA5556E6B6E6F776E20657863466D5782F6D46D8673743F3A7A675A652A6FB3C105FE696E76C236326F69986760DBFFD9756D304904C0CC0003FED006EC3037FEC0ECFB206F75066620ECDCA24661696C20CD4DF0CD3E7E636865647506166865206FC133F8FF72652100546869732066756E6307FA6E2AFFB5C13574623CA0582026612064656661E0D966E6756C741ACC72755'
	$sHexData &= '430746BCDFCB04E6B009062726F48700C6D90811D6C3BD6947475AE1C089A73E66602E80A606965765749ECFD706C39735E73666939EC4C919D0DBC1E82010097B6B7D920CFCC74E24006200EE7D08E8FB37910E1E03E741B34B44FC72B52746C47EE567673E51DD733AF5C002FB72A062E367A1EDF2E1F30878A761A8646D7AE9D69C47016AA68121374EFF9BD202A6D2267006566271F74B5E5BD0FDF12697265266F7B476BE70A6C2A6473722E6D13752376D96300876774F7BCD3E80E73FE1A1A6E640EDEC0E9BD765663A353FE167883604BF0575B73A37B9FDEBD5336753A6FEB78126CBAE77B57C100FF7336615B689CF7DD75FB6732D637701E63B06018188B627FE0EEC153D661653B726A2AA360B5F7FF76476F4B0FEF4DBB286A1F2922624E74A305CBD55604EF54FF6F80ADBD7E741F7F5232737B80E77BC26C5F5372076797A636F6E26F0F4C87DF6DB9D8E11E27A74F1A641E9EDF6ABE326B006E776F80EF7D1D0B724F00E2731F334A3410609E9753685EA9BE931C35447069417798FC737324DDA601422A78743F47FBBEFF5D3E067D005B005D003C9F7B07302774E77D6F372F2C067C276DB6171D76075B69633D47BC06EF157D2917D364363AE21E359A2B61635F16B4EB30D6C77037BF782E47A2D50EDB3A2F3E2F8A1CEDBD9365723A70D2739772710FB355533B2CEB8ADDB03DF0D34A9FBB5F0DA6CDE8CB832F93C6BAF3B1BF226F936D27B45D7B3D07676E74CF70175EDBF756B79E3DFF6653A706BF3FAE642F7E004300410648004516EF7D283A724D7AC24526522B76EFBB682656FA5F575C0644362EF796D7BD4F0F2B78F65F470BE0617BDF53A74C42441F9310BCEFE3237FC33217331CEF563053F3000A75E756808169C75F5F3519ACE86ED7F7BBD58A35BD52689BF77F8783D50643EA421230D83B688E4D8A501E74A34580151B2BBFF743F4BEDB3D27639B74CF57598DE11D7B064E3F70363D17451F6BDF96072DA7FBCF1D69A96393378BB6F878345F8373BBF63F0AD20EAE68DF37A31C5B435A9F478762BDB63DB86BCF645726757E66A4627B372B73927A63B703569C0F766DAFC24BD1BD8B830E791E934ECD812BBEBB75E76577644F782F8E576DCF64B72FDDC174BC780F232F266DC6862D76C0CE4637276A1BED81ED120F6E872FC1AA695B9F5767580376E2683367DBBF100F26535665466163746F7246044D6FF8D09913220C376B7B6EFC3F240DD66C4973576F77363450726F63138B0206885F3BC2BB803E9B1F7A31026A2F0CD82B2F822FA636606F38DA312F2737DAE9E34A56D742E7FB7D5DBE5800505B0E4C025D000A1F8EE105EE4E5A8349E35385DB4B15975B575676F0AE702FAF62335E3537B71DB4ED415F2A785E362B'
	$sHexData &= '2FF09E7744752E627244AE6F4D38E174536A627A6F3BA878232D1F7A4F2647B21CBCEFDE50178E075B16536BD3AD82156727E74277704CA78A2F781E340F84035E833300B26CE718C3FBAE2F3DBF432E552FC6F5FC2812686F617367DF1AF0AD2EFF6F773B41F0B67B071258173A8727AF052EF642312F5B2B5276453AC08B772AE3777247B7DB1AF0D2FBF72577500E021C545F53334DA92D5817B76B2F22B107B65F9F3E7FA605131BFEBF295FD7BBCED8903F3B4C9E7F6204B8A174FB43AF185A2AB00F9737505A01068E57D24BD183CEB83713622B5C278DE2DA415FA75FB7FB2B908A63D6414D3A616D3A500ABA40FF6E706D1F64657175653C543EFE6F206C8979EDE536F37665572943DF8E41C772146720706F73DEE81ECC2D9E5A4D0A4A16508D6DEE5C7001578992408B997E22D576CFE6B6D1CC03E40E03E3D0E560C06C9BED790690B036C9140E100605201D6A9EDF04F00001FB6050FAB6C5F7FCFBB41C0EA82A0F06150001A180101669CFABB41B2EA02106272D2E9FB379DEBB019DE0163306393FC82C3DEF7D671AC0561DD00E90066080EFA6B2E6B6CCA5364E2E017BB01E4C9E67DB6CFEA3E0B32006B1C0B0A0DFB4677B0056C6B400367804D09C0002A52AB5DDA2B006360302DE12F6CD83068B06CFC1AEFF70EF6CDFD33ECAAC360F0BF6CC98160A103DDBDB8ECAD43E08D006B00E2780A0A40707E7067036D11E2830DFBBAFFDB7C35406034EFA30FE2661066060BDE7D93C70143090504E0479CF87A78EE3E3AEE6305006206C8E6CEF40D6389E1A40CD8C01F0796FFB1436F6BE5C0625DB26780ED30B3E14ABCB66584E4256BECCD836E5F334A5A501F04EC928E6194E7BE37EBF0006B0F1790E9E5B04760404C1F806C5B3597EA430FCE0708F3ECDF6183FC428660F6006064005CF9818C7C9D2E04EC24FB36D9EE850F3305ECB0C0807BD70F779EE2707E0061F96CF5CCFE1DEA71E09099036100E974E09F7B4078B704636FE3086ECC7F438313CDB1B10061AB0C077D0683E7A8D6C260290C50B901FEFC8821F0FCFD80E00B0BFDC16109EE7E114AFC46C3EE0D070DBEE4947C4ECA377CE34061A409CCDB33D200E1E201019E0BBEF1D788F3EE16EE1AEE8A00E07DE7BB6A770904ECB48C006A06E705E7E9CEF0E261960BF70BF84CF7BCFD3B61B1B1DEE1BB61A1B4D973E3CC81EE3103EE000547CE735D00650A6C480366FCEF41A92F6300600C7BF60CFBB2D3B46112001010602039269CB73E526052F046CD86ADD1F022F77048FAC90AB5D0407057641B51D76D8F0F4902FC8B8CC5EC7D86E80372E50062037CF2940E41A287C1FE7E1C8B3B6CAC030BDA0A6C01FCE7B9EA030900660BEBEAC7DCFD36C76A8109B9B99F698E0CDFBB473FF98A'
	$sHexData &= '0369695F006D0943EED793E93E060204E92C1D491554F3A9E35C6701610A042FF4BC3C6DCE6196F12833A0AD7233C62206A04569A0CE9D59B03F00EA06E2041D860D60DDC23FF00070122C2469EF041FF7F0F2B928B287BA03C6E50138E14D2807EC072102C21683F013E054800D6DCDD806482F7228AC6D40F40B5C15E8506BC6CF51E7CC6CE6DEC06843F01FF831BE4DDD6674F6026B40247D8B01F37C40616C9C4470197DADE4226B4FEBD19F262EF65971E1006209F7C0291CDE65677EEC2A8D0D0C8B013C876C4C788C704E78213C1D07FC574668B8C03E0843C9210C3E47AC831E1C0B336BE883C9E507B7A2F827FCB98066C3E94764EECD4DE284E6447C73CFFCAE800B9E0C43FD1B0967F7004760259F0CDACCE72C8C418AFBBB70827BE703F97A67FBD6740C1DEF0A625F6649007DBE46E9477EF947827E49D7D68268482C08ED4133B81AC3E7568CBA8A7CD169D40B6BC5678D8CCC8068AA83B119D40D1346FC1E81FB840B613CECC767E2844095970226787DC2EBEDC033C13C5C980C78BC5C727D8D92B76BF08277588BFD02C726A7857BE60CEE087C0C09F89BD13771026F0D77BC254C9105D04BF6C1F003C40EE5836795001C15C276402F9A4023CCFEC063B816C8E7A20BF7457C1866CAA1E3CC840372486F7C4C2DE06BFCF9C904573DFB0D6CEF0D0EC6707EF84CA0C26F8AEC8678908C9A6130427CEACB6C88041E0B05837AE8FC882133224CBD486C720D7898D0C01C41FC514E6FC705DCBA46F5037D08CE0458085A785908F1CEBC03665774FAC64C3C1C12D56C65460250B7A5F68968D78268213D24728CFF80FC117D3640316BE30EF081BDE6A70BFAFE72EC89C57D18221EFCF8CF062816C8687481ECBB81890601B3F476605787810DF8CB876C066D202CF892D377B2874AC2DDB8367C59CB67C882FC44E04373738DFC40C9F09E4B3E98048A6CC88400104C33BB1447FD18CA6CC9798AE8BE3C82077FC4781229892A7F6BE08B097A3C0C575C7D0FF581FC80942D1C36847A7C2486B429E4E8668967CD0ED4283A1FFA4EEAE1016BF0A1C4233011ECE64D39790445ED250A67CA44B70B80B3447476EC00BC9066EC8E401361D2AB03E1770DC7EC174D4DE674278C0E0963487284678D079368C168F0727222C3F77A85ECCC57B4E040F76F01406706F1C97606F4F9F76EEDB20C087A6C0FFFE000333114C2018977ED93451E1BDE4D7F48E80E0C2647302BE4CC6143721AF3626C7C6A48D6690EDC481CA7FCE0C7E7F4C787A312C4779AC5E4CD1704C1CFFF0A70A3FBD982636983FC6BF87F8808313B226CDD073889E0467EBC2C40F6827278338121C060F6EF48FA7A3953408B61672BFC8E97ACF04ACF620FF87DC7B382117DC813C4E24BE2622AC'
	$sHexData &= 'C01C2F4FC4114E200B2675F0CD4CB60A4448B037DE2E14A5085725FF030E099C64C5835EC4B0DEC2647544EA5009427FBEF0028B77827F8C58DE4887E78B4EC809C44C89A89EBDF4139C38257818D73C608202173EF8E7B00913D458862FC0820A0789EF57AF52F12240AF82FC1ECFE9892706663E718205775704673F882C872F241817F6D4C6C18145810C3777A18D00DFC34EC078670E3C5C38E8B1D7F780169CE7760D645B1EBD84AF402E2E287F143ED00E0E0C90960F8CB087252BDECC041F77E2EB6258477DFF184D71510F038FE0DFD7665C30FF24EEE809579013D50494EFD06075B64E9C72A4AF2784B8FC850BD93ECBE04847CC3C701ADE06E7EE90E7CD5C071CB02ADF4E26268211140737C8B462BC831EE6583F8A2F815C66750803A6C798FFD1B06C27C8B81ED1FCA74C7018E1C8707FF77480139418DE17D1D4F4C6AFC4FFFEC64436847023C1975E7E3C4492C037A689A8E6C26A80CE466F668C0B096FE7BD5670C6BEBF775CC2932921CEA727764125A6E7E47FCFC822BC8B00572426B82F9374ACE4042658CF015ED888240F260734C3D805E0BDEF2802F990A8173E82C0D39A24526E3706D9F1B6A2DFA9743006C9FC013F6E2BDFD15EC74C7A0F18B48F3FBFC046048478634DCF467FF1804313A08FCF50852EE4C487BE7C50F6F6D0C48C07CCB6CFA1824309DE3E16483B418FBE046E8B9E26029326B79866B47208926CCF70C783384213C505F447CE30C4428477EFC681C73A74468C2F7F27140CE404CFB81E7C8D34B181B720B705A29A60C071101714570C38F5C34E86D008A70A0F274AAFCD1476ECF6262EACA7DFB09E243F54D1220C378E4C04C101EB9F863F682AF080AF1F58234513CC4757C967861062551FB68EC1A2BA985F5C878F6605171216EF0150F5E0B0976FFE4855E2E0B89F884F97ACD02A319C579FC3093915CFC238CDC8D726766217A03FC3C01FCACE42371C9F8737C40434C18087BE677454895371C6302FBE1497F50859A8E6CE7476C42CB006BDDEE7C6028F096A17442F1732871E09569F002638D056CE84F784D81A13B7D7F43EC7B6E16B24670D3C24E05506CFF33CCD005620406080A09EE6F33CC8F02357508877DEE779B0D0F857665806DDE7799E6088B8E008592EF3799EE7067098C0E8105ACFF33C4F386898C0F8209EE7799A5B4878A0C0E03CCFD37C005C3779A0D0CFF3EEF3FB205DBE067BA0C09EA7F93CE0205E7AB0E8BBCFD37C205F67AF19606606E6F33CCF6080B8E810619EE7799E307090B0D0F03ECFD37C186248A2FD3863BCFB3CEF7E06A0CB2C641E0680349FE6F3B003654E0F66A9799EE6F3E820676890D09FE779F70868DE0673B0E83A69FBEEF33489B0306A4E06106BF69BCFF3BC0678A8F'
	$sHexData &= 'E516C7D6F9EA7F934C808703B78A03C4FF379D000714088D8CFF3BCFB16721E066080A8D0F3BCFB3CF01073D60658803CEFBCCFB6E8732E740666A0799EE6F3D029755070A09E779FE7D0F01876BE06608077DEE779A0C8F0768E7706CFD37C9E50AD0D78386099F3BCF33EE9784679065086A7F93CCFB0D0F0187A48DDE7799E7090B0E6267B86DE799FE70690B0F17B8E7C0650349FE7797090B81D7D7D799ACFF3B9E0007E2858AD7B9EE780A0C8F92F7F066ABBCFF33C90C0E81880A606E7693ECFA0D808816898CFF3349FF02082406080A09EE6F33CC0E810833860E7DDE77991D00084660640BEE7799E6080A0C0E0361B85F3799E770670B0E02886E6F33C4F5078A0C00887DDE7799E3078B0E820884EE7799EE7067090B0D0F0799EE7DD10895E065078A0C09EE79DF7E889368A0650709077DEE779B0D0F08A3E8B06DDE7799E5070A0D0008C2EF3799EE7065088B8F8288DCEF33E4F5888C68D268D8E799ACFF30696D6168F5688F3349FE7B8E818904870EEF33CCF90B0D0F82891CEF33CCFF3067090B0D0F83ECFF3EE20926E0680B3D81393EEF33CEF260683B3D003948EF93CCFF3065080B0E81095E7799EA7305880A8D0E6F3349FF0189682E2109779DE7D9E72D232988E0670A8E7799FE7D0F028992E99999EE7799E9999999A9A9AEFBCE7799A9A9AF69B06503CEFF33C7090B09B3E9B9BCFF3BCF39C066090C0F09EE7693E209D4070B0F0CFF35C7C309E3E9E9E9E9FF33CCF3B066090ABC6C6FFFFCFE152534453E9A677B12AC1174587D0AB636C4D67F7FFFFF797443A5C496D616765536561726368444C4C5F5544465C5F11A16D37370A53524352656C3673654DDD7613FE7838362E706462D7230717223C037F0B5E43544CC050850F8C2A882EA8246469284F6EBDBF12269043046D6E4D40D8231E204A4F24A0F60A836C1E7104790FB026D9ACFC95846964617461243584B40400F70FD2FE30306366671E884352542458434147925799588C274C904E28AB4C486555B85ABC9FBEC42E0744C0274FC499D8E54049C8274303F91252CC77D0486562974CD42743D87C09A94C44DC9FE02FB1CB8150E4274F25763990E854EC2736E5E1F34FF05017EE721E40CC1A00836C18002417586C560EF92628167280E2F80564B3BD8773787D2E78E8F003C9830E3B7A0086671E68EC83835DFE7274632449416C275A1F061B19D8704F5474274F77E5CD4F782608746C731F8000D96995910124ED3F245A67647470BE882618615911093A2774144E466F6581634495D0E84F3E010FCA21DB0B41512614003343CA159D145F34EE2EC73E86DC27773680BE771F26DF0D3F481E981D94E09D8232FD6C1ED0056273730FE9AE7AE096D7731024303127A083'
	$sHexData &= '3618F2F0032601895855C9800010C8405B9647051142AE5C0104DE602523DDADE704426257028C0099D80B2167C005813D640146C0CF6F9448DE56AFDF18E4DABBB0AB0E1B674C2395938B4048018006315C2480DFB68644D29ED077F6A1182E92FCF0775B00E414E7E054578CCC1605FF5705AC43802C940F3290AB4D865F0197F85E06920BB002E14419992540670478571B6D22497787BCE2845C24304938E1A29DA09FE224CF90DD0221A717E2506784C9A9E3A2BFE06FE2B84E24D74257E44A30B08B760A17E3105760BF2517C92D674490990DC470784F0867B044346D0800D7E07F6D0B19E44AE8023F819C6A50C77FE414D29D484EE4404B40570257C145326C7017A0AE605720CC57F85A25A740E5240BB8482EFFE54C5DB46BED770E2FBF846760C90443505F0307D44E452717C0C82FE610390D27404CF097E64468959C02E670572095BCDFE6A04F4DDF8B2D90604F68063F4D011EC485701FE728AF112A3815E75CD79122DD0AAF6F09DF2B8CD09E0E94D7E7B1ABB2068703477F4EA772EDBD2D572E080F2F05FE10E436186F10E70573F4542767474CA01F8168BBD1C9A5014E4DA1FF06E893704F174E270ED785266FC5472E670F22792B82B7A6985B0DCBEDA077A8FF86030716C9DCAF073660B32BE910010F486701932764C3CE4F10426203556C61671F4F182F7F67E4ECC1F0E95C09B753731F73F45CC189E179D7537F3FB091EF4D14A74F750E4801172EA0C85002699F2717ED40EA0CB790989B0D4527A77F0E8F683F0C0C423BEA548FFF8FC1C9EDE6D147D8B7E0E84F6761080B6FAF0F500130B9D8910509034F088BE05BF4979F4E1108EF4E014E0CB757D48FEB0C0AA48D405638E415ABE46407EB90ED5DDB8950A00F4750B0DFA7E0A25DD487E08FEC00AD925320EC2C5B26927727EC58510E806AE4C9586002689F41A81A5BFFFF570B0C805CD8034F9CDA0264ED04CFED4090736395E7ED6CD856C8035210EFBB8213C5FF5240BFE457C8768545270E92015C242FDD9A7702EE20DB02E4149CD0CFEE5455854072533037A189647604DFC45361E4C8F6C70E88019002984EBB68A79FEF0887C0DFEF34478E9C485400540B541650E992235421784F3660B747EFA467B4570F89E816DA3767C8411572E4DA8314AFFCF00C4EC30939F02085443FF054993DB948E0E8010FF38964A43BFB87039848E5ECC85530553B77554310479C38C1D8BFF1586F559CBD854BEF7F88020F9303234F468EB604C2CE02D969E4C89107E408EC09F4E4E5EC225F0B2FFC0C56043EE45D1B003F0DF60EF180015011A7DD1F0F2790097F555E723891D9DE92F90A3740719B57D867C45708AE424EF09009F228FF56408E1C397B5648020F500358047B05E43D4C468'
	$sHexData &= '73F7E9E9DE4C4110F9745F25C449AA0B8E77C8756571AA1EB18DF021FE93AB15B8790CF9999DF840113C9F2C4579FDA23E447075718F31097BAB4DD2E5087580F1F1B0079D5B7F35407DFDBC9453280B0B80FC1AAD2C8C002C89F0F20482417DC847B04F2A8B7F408F434AF46BE8745470E5B0163D5604D4D77EF3AB948BAA788A0A845D2420CDF86CC31919CDAE0EFF500596DE4C8F71F0E1A0124022F87C9C945724460682E20C2C9737ECF11D24695CACFFFD6F3E45D6172D03F0E03679B3172E304EB7F1F5A159B0DB1200F074F201F82C58E0C0C280C4F5F6D39959CF6605AAE0E60E4ECC891016B027303BF7B02766490B71E83068E082F27181664960F095F9E023A163B21A60C4F7F8EA94472F70C8FDD22B9F60E0867403E955CB4A3CF746770DB3716C9A82F6734B4D99109F0010FDC6705179C452A160647F838C7D061380726A75BE04FEC6D814A77873EEB1FF020C22D6FF36FD6FE7250855387F86CA75C63A453DA0E496F6AA8674FDAA88F767078010F8302C89391238B0396A1051C3972E4A906B407BF08CA099123478ED50AE00BEB0C7272E4CBF60D5D010E0C0D0C727272720B0A09087272727207060503DD42317219179F2F2A8C3C99BD0F321D5F3A3A1F45C8DBC9851F4D1F5524193972E460256B2676277E9C9C9C3C7E2524032C9E9C9D8C89910F5F656D3099BD0846750F9C330FA48E3C993DAF351FBAC233CA3827234F46D5D53ADDE5B72BA8913CF0CF3E0F3F6FD8AD100FEE0F3D1F231FECE45E123D3C0F5E1D462872723BB1462F7649BF4A4B397272724C4C499849393B720233523E531F4954479E8C1C5455A3A357AE58C9C89123B959C45ACCC8C8D9DBD73FE25D0FED5EF88E1C39F25F035D0E611653216391234F462C34653F665163E4C84A6752685D078E6C81E4FC1C76B000B801918C5446C0045898EA7672F0F81FF85F603648BA8527879C56928BE49230C870B04770E9F48FFD2057230320574C0278EE3D4D24619D0E38677500B79108C0CFAC2F20D42C720547FE772367DF3657AE70030F780480788059613F4F01359FB92878C467FE3477B06E252738BC1761C64F4824A786D02FFE90C8A978D7850E0B47FEC44E81B41156F0FF1CA14606400348E75A577B0062A0CF8453103C8207FFB0D7FF08E42390DC050008AB9D00F90500346350CF682198817097289CB52307DD276363ABBF20162EDAD067E0C734E8042B4F01441F24D78E1C64645B6778B3979C5C9098AC010FBCAA168A525F66D09F112F0F266E170C0208973FF1A8BF64F02F64F8651F48B792110F00651907A968B12321073F07032856C9028C2F84A9648209AFE06589B60AAE372F0F11C847D565988F05034CA85330B556780F03A482087250BF664016AC'
	$sHexData &= 'A2C7EE04446B1705A7047097C0AF4114AC929CDF70913CC004FF0567DAC9C877C70E8D0199A28793938BE478D0ED9291CA91F9680201BCED44142768308F060C9F918C74178057023897B42F61C766DD6C99565011BFA70AE414C806A006CC7A32517106F88769697B51A5A9605F07FF41F2142B3F0507A0D91003CE6AAF02879D1A2E92E440970818A6D94034F702E78C27E4DA93896A6ADB67C0B9E4C8896B106B1BF40AE1E4225058878085401E05092856A82256C5FFB7938B8236869847D822A2C584D0EF17DC4240710A00CF9F5005720B80577CE94E146BFF6CB05704FBC22219D42F0E39EDE465FD016D0912870B18393972226D406D5D694532523972015C9D82E1DAA05788170BB4279253707F0BE06E2063D14E250C248721E03855CF0C58AF2517C90507A8C088848B76DC67F067853C0079050D086F2072A26176039754E76F50809C8A136F5FB70D90DB45720BCFBCB0BF00B920B0B877DFF8C85920B9E0970E449181E4047010064F4EB0D990010FC09770404801B04D70111F04B713D5423787A6D4A156E6C6074321005F080F107B53104A0F702F0E2D46606482028A5F01726AB84F985F0F7492D94072D00797C04660150C8F4FE8E0982DA771BF0AC11E253B7F10207130392846CEB61E38020F4A03521F05B75B580F4F607F60A7B50B404E109490B73D4C546AFF719F920B36F20ED201DAB7E8212FA7D23F114C115C5D27A247117037559827309C023911A411D0772948B7061F7F722AE4C8120C121C1230057292135D071264E41620391290CFCC8E5CC18972E0D7F813083821A742131C6A139213C929071350733072157272137C8CA08598861372B18713FF37D0941373800E89CFE422D916761410C00220A7E2C8BF1444815C81DC57709C5A08465CC87F56F48010A74015208F9628C82E069FFF0F82592BB0E7CF00074EC56715C49FE0452B7875100FFF1628B74010AA0FCFA73C640A4E4437C958FF16C1ED3608A7C4EFF4FF71E1E40475A0A8672A3C90471708CDBD8FC905BB3D173C4764EFD0C3D542C8D8DF787755729213CFBA17AC797959883676007612761A5DB9010B6F0A184003E25A4D980F04B7EFCF6943701890670527A006060B15933C09B09F0F86B6F642E70F3F077662485B0F2FD4B01FA6EA422ECE738718A7E944A1FF76702F1910712A902319401954429CE4C497D8161988E7404EC7A24F19D4484E4E2EE0F2FA01404E413F1A28C841836E97743F77C8007BC37797776A9702E96E17C9C0A00FA8670171EA2219F4E0BFDA9183E41B20787818BF5C0B556A1BFF57805C815C81ACD8AE404E811C0430808E6000C71C40AE8520FFBF90B802B90557BCE820A79D28C77970AF1D14740A86531D40771D6C20E44115CF79E'
	$sHexData &= '0941A15589EFFB7A8A42B5817F82F5A28E421051E24665811C8A928F71E8C815C81B456B8E440AE404E1F103C40AE40AE689406DD460607C067F85FA5F6A8837BAF0E989289F0D697156F05037290660306200C03A7404EC114E9572040206C4E2E0A6E67A457F0F87042AE42B816DD475D01214F082F768CA36421387CCF0E04F9D685782F1E80032039D400EF219CB982C0F47CB0FF3FD82EE4E42AE0E8F04E24A740223C7D2016C9C8C0670370E46A61003777AC4606908B8004E86E1CB948B07DB8CF7691FCAE0187232CF0575C7222B9587E208464A472915004B00072828B808F7E889C5C24B787F4C0C87222398524387F008BE40A397F087C69238A9340482786C04572ED228057ECE42239C9B02518E05C7222B944801070845A729140FF5C81B41156C8F4AE404E8126204C76AA2E0AB7F0972678677C1D74E09017818702B74548D777A4125AC183D76D601715C8DBAAFF57270415C815C8305C9229A881FF27AC926B2781F0AFE013C9915727280C2824822921A79040283804C4D096FFBFFF2EE28CC082B78278173272903C28A88282D32E926E67DCD0BF29BAF7269208831F0E0B67033DB948463C303801E4A25D9B0F40DF787770C94572ED7B67ACA0B64A4ED5AB7F29E0BFD0C945F22A0CF0FB74279223FF2A842057045011B08D6C67DFA385BAA01F86A0E4E4DA89CF9641CFD4F4921372AA2B0898E8C855ED762B3C475CCF7045721A4E9BC2C72BA400D4D4DAE057FF925320B757FC2C28A8A925278550FFE4226923AE80A0692308B5FF56D839919C022D0486108B45325205308D860E26BD0E48F7864572497BAF96697C9D5CC8C9A0A8B0C9BD89E454772DC8871F938B76ED0E08FFFC673092916DB038FF96400359C8C945722E48909824979C5CA0B994E4849C5CF0F888005E1E33708819C72EE02EF04E548F422F0427D54AAE62B7D3AF2F384748AF5C463A7742EBA90DB70CA83740454DFF066C5069FC940B473008CF22EAA4212690983FA684A60D4F07CF081115764088A02F57306EC90303ED8A1E3C4E75EBAF1FEDC7305CAE401E8130880C9C6AB8CD67D0CFBC4F3130841C399189108918849C404E8920F10AE42427E4F150F16D31843B15720A31B031F8CF2239D570E44F3258E422E4E49098A0424EC809F48AF4D0A7404E72F4ED32AC32D8C99153213320330C2327925333808A108A13C88990188A20F8E4849C900AF850F86D424E819C33D43400A79223A73448343434A8849C5C2490980939815CA0FB8AC8494EC8FBD0FBED34FC5B20E414352867AB90AB905C90A990AB90C4F855C855C8362C6055C855C894C820E454C8FC3730830260640464E74204C0918C8C587FC8C945D286A880889C5C2457ECB0B8E42239853830E02792'
	$sHexData &= '2BE4E8748D10450690238D1802072C514CFFEFEC119C5C246068777272D14E393087A0A82717C91574E0E839915C21B88E204572851C8E28FC66ACE4861F8E0F7914F2F23A403A503A64C949162CBE11E93A981B212717C0C88621271749DCF0F88E9C484E3B208F208F287251B542FF8F17C915728F3B8F8AC13A278F976F3B69314FFED40F1F39B66AEF042BE306F3877FD8C9C0DE03329D06B0BFD0D9889D60573648FF3FCEDE2982D83F37B506D44F3E60126E23FF0F053CBC02C8063D7810B5B4A25D3F1757F6F2E4F63DFA6F71F4033D0477D1291919007C3E2D77D3A9A21340F5DF3D206F6A55DC4E3D302740176EDFDA067FE7C91077EC760ACE0C37173E6C4F756867CE085C06141B3F1A80B56764536ED80434AC7F72764ABAE7C43D707F10E0C1477276A05787DC029C400FE4822B397D00705F1892B3573C00115F3E50FF79AC2E4C8E9C118028703748AA6A0127E4913C01EA5605E47AAE646AA7687B4FA226AB5DED4A4627069FC9A9BD92C2AE5827707756724A4EFA742E756214F1D59F467805270B00041201421201150412AA00012066557A036941C7B119BF44B0D81899508F17BBA0B669071F757702599398162F2E3F413406F2FF56747970655F696E666F4040B1DA2B85965F4073746437DBD234A4975F5F4DFBEDF6604F3F2452736963BC6F73405F57551C5AE6B66D63686C5F747069742165BF4340E3BF5F526566436F759E9B691B41B265745C6C1E6E63370A6EB375E6D663795A8FB8E1167CFB5F50504C54DE6B48616E6426404525FFAFE5A42B2D58563C6C616D6264615FDFFEFFFF666138633465373938663134373738363439643933333516313234613586F1C3ED38333ECE555F543C53656C4D10D8F7514E6F417379FE2540B84BCCAEDA74CAEC2D822A386C7BC9BAFF793340E3C1B022B5875F4661BF414C44D26F5F636F70790881624C63283E0084081E814370419F37338A3FB8FD37DE33313937303462393400623361BC323064370B1B30FC35616634643ED77B6037BCFD37AA31383438306562326666313636320E653036581537C33332160C35393E471676713122485FC865B347FD0B1A0E42F86D4840476469706C75733E2C40903DBF88466D8862C7C046C8E749140D691F58242456FD7F1B346CB0AC7864320E36DC42E1B71F6C633906A0393038106464636564332D1A5E827FBE4412657C8D69F438263D5F7D40EBF8907130BD044D1E661A0D22F05C7374D4BE69B8402F45351A3004A61F9FD19BC63B9C74D2754F5F521CE1A66391561D839A3F23D83500983FC783B80466604270CFB463A21DF781458D8BC3ED50CF537928656D5FEE602A56C1683F7F17051B6CA4FF466902284416A1C690BF215515AB59353C438'
	$sHexData &= '8F7F5627566FB8C32064B7FD78B1D59D55F2E655A93DD0C2F456B57DB933FBF4BF550346332909436613762623875D50DDB61650038652E393935CE666330BA52C0D0AE323FFF1589A89850BE6BFC64EABA3B7633CE41364132419A627A27585A0F1F660007866021001FFFFFFFFF65623837646664373366383537663434653161333531656134326365326233046618923443E43270052F1B2F8F54166A670D6B7A5629212D5F17032C5281974FB41B0C17F73022506978CC42ADC00C70D6E6828B3A7C205427A3188C8AB0AA270F4B4458757F0FB7E26A265C724AAE658741F2145397696E6716E00D8E432832B7110481089F78C6F56F4257324261B23433363164626631177699CB4A7E1076663558AD69D484AF4073A4698640141740644FEF0D064722E2BACE354677181CF4F4E636396608604D801B4E366364D61033B6C26A03A8FFBF868B8FE02D366435E8393A0D6830B463E436386E36D433EC82D9F0306630638E30312D042B1814FB45FF6B8FED443034DE3339ECF033EC5A0991636438EC98CC64645615A22D1C32331C65FFC660A108D1BFB43638A1B6013744576B77DFE2CC670E79DF122C2AFA376333332063163130324884AE7FD06265343937FC617E1586AE933AE6DF732DAE5525522F973455C7227F62594185C098827C38A836CC24302F32B27835616132AE07C689D6DA30F036AD212AD1714432BF372262AC4F37CE22BCA10303439A62F86406A419C77804070ACC58783632AAF8319CA2A2065165B02E31A661D42B0E1C14E8185540C5AA09AFC181D6D684699741C20A6434428D59D280E46AAF6F716200201900AF82540346FF2F2C1A30202F4485A9423D451F013E023A5F47A15F413A83B510575F42A488E130B3D23F0AB5EA3B8F6F736240480F3F1A1A5CA34AA062EC397130383926599EF041BD56C93EA66337953415040980FF5B6FB403A69F66C26572031A88533F44B041371C11A1539D15506044639F5160D5A8CD9FD9C7A841F36F626A821A1621C622DFBC072E2CAAB1D7C9EAC46AA96F890558D5B40F05C1AA9A560FAF5A55915625D60AA5AABF1F86488B22B76F6FA9260C4A918AB18203CF2D14230AA5EFD3149A8015BFB58AB412FEB713A36055DB0F165B0827FBB3D76A480531910745AD55D58B3700A11874587F55A15450EDBFEDAF22583F66356462390232B3068109B41AEC33265602C7F626F8363232310A3733AC3F5804C1AA110A4190A28F4551BB428C2F378F9A908A358F5F45820BBF5BC5486F6C649B418040C1477501A4E01AFF15AC2B55AFFFC7AB406218E70F552556051FCD156351A81FE9D0D18D551F460A71C35BC11D2B9A10289F1119556D0D51019928A80000B608A00215FF092A28A202000020A004'
	$sHexData &= '006E01CDFF0146696E64436C6F736557C0E0B72259DA5322676C654F626A44B44C2C1C28EB9D0A947D4578571C0B4D7591969940261AC602B6CF1B474C287445E6BC33B3D344443AAE0A5EB5FEDFAE0535184C6F61644C6962726172795759FF24F06B9841646472B0FD66275C1E5462616C4D656D887953819FED24387573E24B4D6F52F0BD852489A57202747694B42E1A5953B419C26B050648366469196C82F0D754564173174CD0B6CF1331542A7050806803430E0EAC05931108490305ADFD76517565FE5006660C6D5E2E092B567B5BE8CC0A0E2C722E70E638F5737367662FD462756767387C788A259336D6066D78464AB86535EE69DBC0609EB27243A05338083CB8556E68AD6461418ABD4156DB33FF8701C53B4576AA57696D29B6F75E52EA7447CF13355745E0608064385356C1D0D670AE87354102AD2D1E6C5370B2057CEE76790DA3394C453B2BB58CA0E618D34E9277E5173B331446756C6C4E616D23392C5B47538D5D06F238A2B5AD5FA3617D9CDDB05615444AEC6A57BEFD6C16AEA40160A35F7763746F756936346079DA67156C38C66CF332D040A06B5F16E5696382B61B44EB78B18421817A266616DD5968141242DA66721A43A5D9966D520A028C723ADA8245EE6466A9B46D5FD265320871C6B4063B4C5F702A7F70E1A8BC2952987405BDC176CE6012640F52225F715266DB60030627190C8C28EA0C47D65FAA215F02629D69773B6B94726E6F0EC867B0789B69853FEF3469C15A68A3AD79331CC06CB707DC779C6E76690E6E6D858D1AEC01121C677A3D720E05B70A67762E9A684FDD42D6602B346C91AB5FABE016F64207705AA049C9EE2D41421C0C9295A761ED166E612A4BD466751378169B0C66A268775E1DEC0E6756D96373621C99690E092B5FD84899E071E7AA7086A4D659F0597647D67638793C32667090769BC266EC43103273A33FBE5B215F22656B3F66777C6C389F8265246B10A4A277645C860F13FE26759E605898352C760A6C04EAE8F6FA380D7400FB3E3CF4367D680C69B04443C3132D0B9B6A5E1D572B1D6F9F1D4B48B72E0E426CA7606B575F2663792896E00E069420E8A81408606103CC3C68054861E0112F43852AB147308C644D7B0E05DC2B10062F1FBADDD12CE955F7164B4183AFE23BB7154488775F520C6CCD0EB649897375468361FB1BF2484249544D4150616AC050FD2AB0C7A0536D6F6FC08434050638882BAE2098A7F958BF4F022BD83373B5DB027B4046FE74EFDBF1C56F0B83659F614F66C738085A9A9B4E65D74CF74A052BD395CB49434DABC04E041147723878639A60D84C21BF53D8D845768C33CD695B52CC609A57300EF558442BC1330C6E30E47E062CCBF691546F5FE0DFCA530CAFC03F5'
	$sHexData &= 'FC6637674405FFC9380D3C2DF1151424508CD8E247E43307063111870435E53310E2504D350A4988A0C78BFB76E345941585004425840465FBAF5A665AB846861081AC02D26E013D97E3861F1A80740708854B36E35136BB54AF15258B10866EA48DC6F6246727622432C45AB6F58CBD61510215F048343CCB7594850D22578F6E6B0CCAC593132368938B9B06D2E6757206B4920EB181A10584970F7C15438272F3C86B79ED6163C5141451389DDB0C04BD08563A39A1B5430F6196381B9670883C76FC44211A07B317FE213295E5F4E258F1F83E4A2AD58A52C24A411837DC1014C06F34193CA96681808704A6EA8ED86B0C5CF6F6E147344BF6B4F2F609B00F6697B51425570183008AF52DD8184379ECBEE13C21B9F3F30B9A0E09E03BA0275AD19BA84C194A31740F668E110BB20F27B04742AC217E2D1074D6272E4637025C0E86945695CCF0ADB4095AF085FA24E03A9199C671AC6CE085DCDCD5F70C5AE5D68CE5F007175C3DDA4C98099EC248B7649F812D17A41420DF01C0E03EE0C0B3F315F162C802DB0ECEBBFC41C47D22E3048F545A66B1B6DA1FCB78041EB5700731FF09C67B450364707BC07F6A6583106C93173CE9B9966A067490863780D5259E07D8743525603245478A1344558666175508A2D8D14C1E16E89C1C21C235839808DD806CC319BEDB0AD00013F834440E515009045245F6F665F231C6E353DB56DC30C8B199DC5D543CBA0B01B164B46683832C2AC465D1120C45631C8AF8A50425F574848745D624C940ACB702585C10A87D40E67344A05DB85D1F3734E89601DA169EAD3C0DA33AFCB771B2AF415535A69F45F4ACA082778987559693C30593BE0056174574455AAEDB1E26134793256308990C321576241F56CC7341884A902BF2EDE520CF051AB546F422899A9997D88AB4D74785FDC6E8279B6A6EC881B443F856F268CB6441259DD11DADA58256B55A24A325B19AF4235BA14D5555BED3B7793262A87A4436307AEED416FA161594CDB0B824AA8C21F99C25F05FB497066784018461582B95FAA3015E802B97378743EF14271524586470C68DDC869186E7F39EE307290DD9D779E52105A382213DC780F0574EA77E82556111C68078A972518D156479D6EC686C1A0061F1A9F770B5AA87F2283E1228622646591500E5CC1043732073B7014C147497FA9980584702B7FD808600653245783549D0BAB5A8530C5DA046DA93689587FDE0E048B080D0848303031988A2A17CB8B40AB4020B670FD784ED9805121176F0CA9D859464F73E1C9E02A66A8737B414678EC825A5356322F7889982BFE488172640C299A06D2A559A8D4820053FE6C2DAA500C091D9D7104D56C116534DA0B13551167F68382A39283706509A85A60AA67EE9772'
	$sHexData &= '8043247F20670D1360452365178A29F1545F476E268754C903B941696E0F2830E86176E29B5F4A92AB921729707057250DA11A5050C0AA5225C595422BA26BF36D9B5CC19D556BD5E0A1D55677A34090A3A81955A01FD40EDC8373686F7720A7A258CE7963494D41039A08B0569281663CF112FD787E9F3148652A4D4178949009AA2F4D30401BE182F88F504BC20AAC0327EF7240C3003548695A651A430D687FBAD1A651B4CDBF95C7622836156F7336D85103148B30620EEA592A2D85201A323644A2D65340AFBE81C945EDA0487F49C345C9454A4B81745132544A4D60288E501BA97798348E43F44035B7E31CB1C1343F421B6B6A3733667948043BB56BBD15399873B1D66A9F2A55676F6F64E9B06B9CB12E9C1B77A7CC1158E33EBB5019F44553414988AE372A5B832A28BB22D4FEADAB34C7407368696691B6C0146EF1182FAE44318AB9F5CE220A8D1085F2CE19B082870C9A333B08D04E696E991F0A904AEF009697D311E0105EE477617973041CC703866D7640ABE73F420EEC1DC506499149339431D0611DE16D804C73CBB1BBD646E8474B64DA4768CB415B8F448BCC6660174300BCF2D0A2C1A13014764D64E07B090587251C457800CAD35668735758C8DCF81AC82989AC506F6902E0F7535957786F77569A08D959092FF0230A625D3BE41D54FE2898B0393F18496E66169A53D819CA94735BEB21AC29EB53314D1D59EBD6DA6BEC7091546D4FA11130EA651DCBFE32837731BA456E756D19710BB1B0205FD783423B6661B74D1072A685F006CC73F8DAB815DDB679692943B66CC173E1C1DA6001976800D3E0DD9E2E142C6DAA6370790F88872BA15076FA5FF65F3ADC0AB7B1BB6C690046C0DFE17878895178BD300D7526007F02DF40275F3B7234C00D851386A6046B80B0D985085C483533CD5A6ADB8857CD3188704E8008E82B70DAA085B0F3123F5451DEFFDF28C1010C0512061C0A1806051317121E9AFD6EFF0E0A1B0F130D140A0A0E060D080E220E2DFFFFFFDF1E050E18231015F00B01220B2724111507181707340D152E0C13210D182BFFFFB77604101E6C230E320D270B210CF0D5011C11CE3906123421FFDFFEFF2C1520203A52060C1C0F164C231C24021547241D062D2806321F062B11FF2F68FF200645362526162152220C1C190C1F0F140B0C2A0733075FF0FF6B22180A231109ED0C63F0BE010505140C291230CAFDFDB7FD6410E5C62F33141B353C1A101861102C10160F1977DFDE16BC44060D052068172506A00F1D0DE4061FB07F2E26086AF623470D6F4E0011D0ED2FF8ED0E161B06120E271E1D135C0E280E301F2B402A0FFDB7DBB6110610177A09040198100DF023010C3565FBBEE113260A16050B1417174C0E1B08FE5EF'
	$sHexData &= '0120917A00A8E0C3D1B6A0C7571B7FFDF7E28120F333EBA2A2D263E0F24330D1C49080D0E08840E0D281FFBF6ED0F2C1FC818052A1125250E0413271F502A16FC05822936AE070A0914101437741E47F7FFF6FF14F02101122E155A243A1C460F2B06484C40062C29242FE2B6B5E2ED620EBE4C0D492A0F74281BBDEDFF5D840626213B0F150C900E4924351B0B37FCDBBB3F6FCC1C1E1450112B0E9E2E1FACB6770EFFFF77FF520D265D0D630D5307127E10321E0C12820F453C0E2B470E1A07601AAFD876FF7D201A0C198B0F3573053970D06E3C14201214FFFF7FC52735BCF200101AAC104D0D0F3F062A2636062714110A1436242E58F007FFDE125715A1310F5D9014960FF0F17858261BDEA1687C25CA8A0F8A28CF1E28A57E85E0FF0F4F1886393B0E2108D90FC08E640E6210931D15B6D00E145302114A0F6CF6E2B791200F716A160E5FE319F600080470F136DF0E0F220507403F1639D310B56FD875722C0F090706044B42FF82DF6DA6311C0B100A080815109A08120A110C100B0BFF827FD10D21A42D1F4142401B0A32FC46367612D8212043FF7FC3FFF07C010F32BE17127210A6462651862A093E1B09361AAF3E2F3F98F9F6B027B729171BD4563759372201DF5B1BE40426D40CDC390D1908FE3F12B1E6DBE02548514601576F502555ADD8F0FF282D1D23D217201DC9F006286428E24457A645B613E4034531EEAE5D1AF8B7FFD7DE723623030524242C130543636230462B0B948A0EFE45701111060F0A051D0ABE357C12ABFEA29BDA1C330A922850144C35C8F0C0073BFC3BD3FF201E12F050013F5D1808748329262A0C32541378AF68BF157A1D6405F0010159329449545E1D251B47FB45156814AC4B1455882313AA234CF0B70D7F869D0F0F0C0954DC09190636503C4A141251FEC7DED020AB40375644175D2D05103D5018211A1BFE37DC32320F2EEE0622150F0B084A570D30B27F13FFDF4CBF2C2023161202F411140866085606DA370D851022DB57D0652C7815764F20D26CCA09090F82779D585A0E2D0B16A71224BDDEECDF0F21841E1548084D824C0921093CF0EF1D2DD2411AD40678720E9A7BA9AFF8DF55C2125C9E511D0C47180B0A0C10070908FE00DB66523E0F201806245A1506410F251CC0D5FE5417430C5CE0644EA80BFE040F02BD140988580D0D0B4045FFAFDA200CAC507DF0F900134D79F00E011326785A363CAEFA302444F00352F0A20192880F08F186FF2939F0FD006906511FC91AC6F0050145FFFFFFDF861413132B1F0C612407A62B07F0F500CE0CDC123CF02F01F04701516B0F1798E3C7440A8013085C023E50330FDFFE45E64A0A2B1C68762AF0B9020F28A60B07050976BFBD87E11012102C992F210D07D8414E'
	$sHexData &= 'F09302F0DB6FFEFF1E02147D19110922F0DB0108337D5F0270117AF05FB0F1004DA637ED281350720F12781046585AF0EFF8DBFF74028CAE75172E336A63015D9846584C06C5D21C14FF76D3DF489415B71D0562175C5A36A14654F0CD01E4923735ABFAF05702BFDAA6FBBC081826ABF04ADA4CEAFF040C1CF0D7012CF02B030BAA0C1A3E117D2027151919164BF06C01AB2FB8C0D0AE113486E00F604EF300F055BFE0FFFF014A109228487E3C427228691638302D3049BEE4243F094B1D28FE8AFFFF064A9F172C244F39360F4B530E190D4045EA311623F0320189A0D8700170430715040B24147F68B843FED609167B7025350A4E7DB9FBEC0E2D47101E1D34BC102021420F2EFBA72B1F3D1F0F7738123610D8123AE143060BF0FF0B447781391F2406D86227201C9C203101FF77FF552624223EAD0C22231D2001111E6C422F493B331F5F0FFFFFA38E1C0C1715140A090D770EBC6A6822387655230D0945BB6E2A0D2E161E0811840B000EC783290E14A070E8470EC54C92B8A813270D1F3A3685C1140DD80A0818EC479DFD7FFC2F3A14BA0522065207250A25107E46056FED7EB80B0950E4093818290F3F48079A45FEB40801060913072B0EFE9A1541EBAC1DCC0C1506B919F6074C5D93557D05160C0E10240CD6360C4C7A37C135E6144826460B1116082BE6702AFB0110B22F3840267A5DD30B22D805930F0B124C150E41C38321D0390EF47819D50CFF07BA749E3C164B203E114010000A1D0FE954C01D4D0DF0C5E8227BC7BF5D840D7302A82B0FDF125ECF0262331F5750B508F022B6320B9C9A5ED41C74544A766D0106465245EA406BDE169301F061088E0B1411D9D5FFAC640B0644062A08551706CA28CA0AEEF5A6260C1E0C650614EA4205EE75DDDF28F06901A910815387B97B57061051C8D7EE4DD60B2608177873500612FF45FF3FA80F56C3F038021284F0F801B93C02AD0F7C4FF02D01102F6AC26FF414C80FD10E5234AD40462E1B24FE45F8A698147A0D530FD362179D0C840E920E822F687FCD1CEE106C19010D2014AEEC150C140EFCEF82E92A0E3A0C62BA372762F09501E7F07902FCC717B89801951EDDA6681C0A122F6813B32AC31317C6B834BA1D47A6FFBFEB1C314EE80B303FB169158920150F7F3D825A4DBCB4B7DBFF1B01764754511A3C61104C183E1352192312B87211E87FC503FE1C1662F01604F0670119229A06ED5F17FE880F1E930D341A350BB61A083E046E1476C537F01401AA10604D0D1A664D07F8821F5D01E25B9EF039011B0C00256D5FFBFF0C342C0E460F2D06380E1C2C21B83D144029961812FD8A4ABB641160314E1941402A01D910F0AA3DD89FA10E015001230E13429A182EC70E850AA0A00809B076E2ADF'
	$sHexData &= 'DFF310A0C153450120E3D350B2E0C312C17381664151B7A8217A0EA1162280917371255686D802F58F01F01C6844CA47B9F03B96CFE0F080859060E091FA57880F61D1007CA7A58FEF003E66AF156D11851B6098653018A4EA97FE21F28EE4AF0C3019E480F2106213A1EF656B4BF8658124C539F0D93241160F07A3E100EF1155F81215A0D140C430FEC4B01B6F03347F1ED5B581C0186F0A4105C016F12273D2E5FB1FD6B17A61C1D4A3C5D103A1A5CD01A10B6066CED0CF764623F5C6A53F0577C250428013CBCC914B228E43A2F0E4DA83BDDFDA7D939243A4E2C640D1B15555101EF80E00A1CDCCF42F03F02869A5C82EF9E6215130E16F67A38073D408C0BEC0B1239A65027420CACA10A5E3CE93D529CB48E7FD30C39F409CA069F5E7D0673DE0548706F78C537148362C5061F50340211286C0A171818025BC1F754101A0F62F00BA88842B803801568BA0E3C50100C7FAAF07EFFFB6B4DD4EEA06A3A1CDD015EB02B4EB50FB5B7D5113BE2FB0FA5F02C010877019114C037FD5FF5EE2B196A182B116E07592D123E156B1A311C110961C3BE9A3F43379B111F7CC5BFAC12CE57332B46051E9486A0F03C0144142006B723DAFF6C7C106EF0AC01230F284E077C62540C71F83BF8FD0F64F0F6008712841068222650BA3C14517ED7F607880B0D8212B06002421212A6F02002D88B06FFDDAAF0F000193903E90697D64CF004E254F45DE206A9C712C244026AE0F0C8A8CCDC43F612E487F509ED7FF248012F1476EAF0A81250280F1F7BADE1FF1C24212B092BF002029EA5B001866712E6FF5B73A2F0603F8256C1F0FA00123A5DF08C02F04AACFA4F9B6554015892EF1E0ED111F64F01BFA1B51F86C98DF0760EE8043CDC09C696E2F0D0153BEEF801845460841C42011E5ACC1EFEF0025CF082F4528F0671D0385F3FC530B67FD3FE6DD6970689E9580EE67B53D4680688EA7CE40CA4F8B0E3F406D61490069D6CF09270E1F6AD22F06A060F01800107C5C6BF61B8E1641B6D701A8150506114F83735D9260D1E005354291112110811063069A532C4AD2C0D085DDFE22F86043C4212A954312245177A12483B36F105FE8660F82C6A71124BD31208EE0128B59B00DF0E1A02431255F8CC76113DCE26B0D8DEAD36C30FCE3898485A01200D051F2CE7520654A4A0CCAD0F3B1A364601AAA4AC8002647AB899E1053652F00902457FB5017D0B6E0EAC20050E1E06FC04869AEF02DBDF0CF817206E0F14CC08AD0E6D150E1E7F201E0F6AFCBFEA7C1A500402104DA30E39290C640F1BB6BEB0C6EBF41B860E41A5271661F29AFE0B1AE4647C661130260E285E0E2D143306DD7E05263126062F5748162423BC0CB6FD7FED0E2B2E044E5493100F320E1924122219A20F30'
	$sHexData &= '26054FA56B5E2C21213C28D08D187EFF47229F11351223436211320AF0C702C78DA36EFC75703181615DD55AC17FEE603822122CF013D62304CA380F7AFBE6768C2808A801195B028C3B08E81226081979D80037F44C561F010116685871D1E4F0A30A5AD848C052ACEAF0E6640872026919C30D3E8B067F3BC035C07B0664A3B28E03112377D01503147DC70CADACEF5EF0D702E0838E16A3FDFFD6031F2E0F1A5930401E12365A204801E8F012685FFBCF0ADA0D0DB40F0DB6540F1A5203869395A98229B927B32DF0ECF1FFED1D011DAE9811172D0C0A38601187F03602571402BFF6ED474451082A2255112E563E0C66170D14EF69D57E4E2B134114E63EAA100C3E4F77B7071406246040011A9C133B0281697B2E85624A1D7AAC9E57B0395AA3DCD32620F7005EF206DDD7B4B71C44891ACC51A81C4DB576216B8EE0DD770960CE1B47BE05F07B035FAD17145D994A1D7A1063E67135D8F002CA26152A38B4032DA7C836AC0D733827373C40173B2B6683A73D3A4067FC0234C18F04A6BDF6FF9103D0D0F03202A6152D3747067E0D065739F1FD5FC81759178F1A215F0C9158DAFFA6BDB6265539068E0D0649B5403A363032201C50F46FF812626C12241E4D252611154C1A2C3E248AF65F51A40FCC35290F1E0C32272D213949AA7DBF5220200F12363109576C013E335E111F1216620D605CB0D7DA0F18D20EC824166D0BA1ADE0FF67E255871230F056014C1C0F274044097A15305C596C483000A9DEC55BEB7E4905013C50003082AD345321C532011025FF071E0E1C181F15411108068BBAFEFF071409105E051026191414130A13DC16E4060B5DA4ED42CE09021408EC0F052D2A7E25BE240B0A070D10F20F080C110728CA09D3473ADF800B080A080BC60807086485E9DF3618073B86A8A4203136260F1352085F809B6C15156468680D27521A08183B11BFE9FF4D2A7CBD2F0D210519050D46082FDA12185012BA3DCD2CC1FF1A4E08161D44090B07202101080CC556E20404B898093133FFBFDADD0B311305252D2A0F2807E9200A332140064BFEFF57FB1B18180615040AF6311D130E1B0B9409083C1407300956577D271A110E10232BD60D163ADE80A17DB57C23080513140413A7F6612A04960863066DF6CDFF282833372E2820321E20301E2842262016283ABFFDBFAD14420A302840374227302B2520451B144A5040382E51DADFBDE6486A1D3836403A685D5B381E2E616FBFFD9B9E30534B440D0C644806393C3B451E4AAC4D3D380D5E8845FF0A314F278DA04035465946944840363ADF7B01DEB030404B0AD62D342A20F3083632A29B6D6FA036442663B63A262728FB26C1D6F0B794212906351E392D162720362A51DE1EDCDE10405A20411F872'
	$sHexData &= 'E4B3C27F082EDFF37281B1639382630142E5A4E60305826017E765BD3AC13283F19202A31322D30DEDBDE5E48262008484238382FEFF5567030D8011E22426230A2EC8C40C13E3C7234A80C1AD8FFCBE047455E2838332F31353B301D0CB6FDCE1DBA2E858F6A602E626060C4382805BE53A50D01793A40002630E4B8C3541B12194C0EAE33698743824A8A070FAE18DBDE472929170A430A113A6010026F6FADF80F061B609E1C102E01140C9A6156A104D4A010271460099A39D23CE0F0A401DA88DA6A6F8B9B0D5FD086989FF008016C5873DB6D7E1018041018100A0D0F17CEDDC3D9141EA9081B1ECD8575F73D1A4F18256D6F7BDFF7B235313F107F143F3D73DF299F4B1070E714914D6459F6DEEB0A086B4585EFBDDB1E4510F3203DC913DB821564CB7B97996CDBBE0543E1107145EF822CDBBE631477931989368E0DDB6B33DD4534DBB659E71093C94D14DEBDDB56575D085308A5C6B025D8C7D3C9F935D8821BFD083562B56F41DABB224DFB57150A874376382F02FBB111BC3424DF7DF77BEF1F82E1F0CC0B200C200804300B04DE76EE330E190C0D000B39EBF6DEDB1B43054905246CB6A51DB32B03A70861EEA9B66D4FDFC81E1002D67D2CFB0110DBD70C0820331437DBF7DEB6396F6D7510D92C0B4B7B6F15190F1F6F5BB0201709270DB7E06DEF08341007FDFE1C33E3C0DAEDDC14D1F0271816181AB6C130B62FF50B33ED62161A8184010C23DC1DAC4D2005D9F8F0B98AAD396759112015DC6A2301CEA7559C0BB60313101BF0B6B5B143571708541A067B5883AA24BD0991E4875B63786578202F6DB3C5D1942FAD37E8D89663633023176D2B0A5111B1173DD96210D1A402FC2C2DF262DA1A2B3847101D843DC78601610C28140F3A6DDB728D0BEF033030AD35A321B528B34430EB73381CEF0F0C28E11460D357ADEA321BEE35102F4B45688BC3E1174DAEDD9D16BACAAE15548E6D1D2B2BCFCB256CB115ADB933CD6D03665A8A25B336F615A4BD9D08441007A989A502AC350BBBDEAE5593BD07C3500B147BBF2D05478A85D8080937945CC31FB13940043C04209C04141E8A730E000B0C7494A5BB37D61804250F062708FFFFFF7FF0B431181C283834D86038242460606C3CD83C2420343494402C2098704038DB9B2CEB48443406604860A0361C247FB761FD382048C06870E898985C2C2820D89BFF76FB383C3CC04C08D8D868525C381C341C603828A04058DD5912FE4C3C5C3460942CF34C01050D12B0BD0E0614690001BE21C07649C00B012C960418F7DE9908492948161010B00E99298577121712723FF72E256D0FE9453D806DCB5E4028106F0F1331002C0645351A29B5AE2C75B00E90F956F26DBBC02EAC3F3C30CB040070C9BB1A00B5'
	$sHexData &= 'A03E40621B0460F501071602104DAE712ABF9D9394965F2C57CEF520DD00E0963A85BF3CB8E074CDF7CE069A044CF7D26BE67BEF2D042E4D44234E8005C0C9239F1E6805C7D339C0BCC11903DD16D69E051EF2E4D3068605D35772657937F09671F66A4E40CE3EF9E48C07D45F4200F0276515499284EF9100DB35060000009524FF00000000000000000000807C2408010F850302000060BE00D004108DBE0040FBFF8D8760910500FF30C7009092412F505783CDFFEB0E909090908A064688074701DB75078B1E83EEFC11DB72EDB80100000001DB75078B1E83EEFC11DB11C001DB730B75288B1E83EEFC11DB721F4801DB75078B1E83EEFC11DB11C0EBD401DB75078B1E83EEFC11DB11C9EB5231C983E8037211C1E0088A064683F0FF7475D1F889C5EB0B01DB75078B1E83EEFC11DB72CC4101DB75078B1E83EEFC11DB72BE01DB75078B1E83EEFC11DB11C901DB73EF75098B1E83EEFC11DB73E483C10281FD00FBFFFF83D1028D142F83FDFC760E8A02428807474975F7E942FFFFFF8B0283C204890783C70483E90477F101CFE92CFFFFFF5E5F58890789F7B900960400EB238A07472CE83C01771A83F904721A8B072C05750F86C4C1C01086C429F801F083E904AB83E90173D88DBE00F005008B0709C0743C8B5F048D84309454060001F35083C708FF9608560600958A074708C074DC89F95748F2AE55FF960C56060009C07407890383C304EBE16131C0C20C0083C7048D5EFC31C08A074709C074223CEF771101C38B0386C4C1C01086C401F08903EBE2240FC1E010668B0783C702EBE28BAE105606008DBE00F0FFFFBB0010000050546A045357FFD58D871F02000080207F8060287F585054505357FFD5588D9E00F0FFFF8DBB445B06005731C0AA5949506A0153FFD1618D4424806A0039C475FA83EC80E9E6ECFDFFEB1A56BED4B40410FCAD85C0740D6A0359FF742410E2FAFFD0EBEE5EC20C0000007C5B0610845C061060A10510845C06100000000000004000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000435B061'
	$sHexData &= '000000000A000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000C80051080E204107E01000084B4041000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020010000000200000801800000060000080000000000000000021B003A9000001000100000038000080000000000000000021B003A9000001000904000050000000A4600600580300000000000000000000000000000000000021B003A9000001000200000078000080000000000000000021B003A900000100090400009000000000640600910000000000000000000000A0B00500580334000000560053005F00560045005200530049004F004E005F0049004E0046004F0000000000BD04EFFE000001000B00E90701000B0005000300000000003F000000000000000400040002000000000000000000000000000000B8020000010053007400720069006E006700460069006C00650049006E0066006F0000009402000001003000340030003900300034004200300000005E001B000100460069006C0065004400650073006300720069007000740069006F006E00000000005B007800380036005D00200049006D00610067006500200053006500610072006300680020004C0069006200720061007200790000000000460013000100500072006F0064007500630074004E0061006D0065000000000049006D0061006700650053006500610072006300680044004C004C002000780038003600000000004E001700010049006E007400650072006E0061006C004E0061006D006500000049006D0061006700650053006500610072006300680044004C004C005F007800380036002E0064006C006C00000000005600170001004F0072006900670069006E0061006C00460069006C0065006E0061006D006500000049006D006100670065005300650061'
	$sHexData &= '0072006300680044004C004C005F007800380036002E0064006C006C000000000034000A00010043006F006D00700061006E0079004E0061006D00650000000000540052004F004E0047002E00500052004F000000340008000100500072006F006400750063007400560065007200730069006F006E00000033002E0035002E0030002E00300000003A000D000100460069006C006500560065007200730069006F006E000000000032003000320035002E00310031002E00310031002E003100000000008800320001004C006500670061006C0043006F0070007900720069006700680074000000A9002000440061006F002000560061006E002000540072006F006E00670020002D002000540052004F004E0047002E00500052004F002E00200041006C006C0020007200690067006800740073002000720065007300650072007600650064002E000000440000000100560061007200460069006C00650049006E0066006F00000000002400040000005400720061006E0073006C006100740069006F006E00000000000904B004F8B305003C3F786D6C2076657273696F6E3D27312E302720656E636F64696E673D275554462D3827207374616E64616C6F6E653D27796573273F3E0D0A3C617373656D626C7920786D6C6E733D2775726E3A736368656D61732D6D6963726F736F66742D636F6D3A61736D2E763127206D616E696665737456657273696F6E3D27312E30273E0D0A3C2F617373656D626C793E0D0A00000000000000000000000000000038660600C06506000000000000000000000000005A660600C86506000000000000000000000000007F660600D06506000000000000000000000000009E660600D8650600000000000000000000000000BD660600E0650600000000000000000000000000DF660600E8650600000000000000000000000000FF660600F065060000000000000000000000000020670600F86506000000000000000000000000002A670600006606000000000000000000000000003667060008660600000000000000000000000000436706001866060000000000000000000000000050670600206606000000000000000000000000005C6706002866060000000000000000000000000067670600306606000000000000000000000000000000000000000000786706000000000080670600000000008C6706000000000092670600000000009A67060000000000A267060000000000AA67060000000000B467060000000000BC67060000000000D6670600C6670600E467060000000000F467060000000000FE67060000000000106806000000000018680600000000006170692D6D732D77696E2D6372742D636F6E766572742'
	$sHexData &= 'D6C312D312D302E646C6C006170692D6D732D77696E2D6372742D66696C6573797374656D2D6C312D312D302E646C6C006170692D6D732D77696E2D6372742D686561702D6C312D312D302E646C6C006170692D6D732D77696E2D6372742D6D6174682D6C312D312D302E646C6C006170692D6D732D77696E2D6372742D72756E74696D652D6C312D312D302E646C6C006170692D6D732D77696E2D6372742D737464696F2D6C312D312D302E646C6C006170692D6D732D77696E2D6372742D737472696E672D6C312D312D302E646C6C0047444933322E646C6C00676469706C75732E646C6C004B45524E454C33322E444C4C004D535643503134302E646C6C0053484C574150492E646C6C005553455233322E646C6C00564352554E54494D453134302E646C6C000000776373746F6C00005F6C6F636B5F66696C650000667265650000726F756E646600005F6365786974000066726561640000007763736E636D70000000426974426C7400004764697046726565000047657450726F634164647265737300004C6F61644C6962726172794100005669727475616C50726F7465637400005F4D6272746F776300005061746846696C654578697374735700000047657444430000006D656D6370790000000000000000FFFFFFFF00000000BA680600010000000B0000000B0000004C68060078680600A46806003032010050340100C03501008037010050370100203D0100202D0100A02E01009030010020410100904B0100D1680600E0680600F4680600006906000C6906001869060024690600336906003E6906004E6906005B6906000400050009000A000000060008000700010003000200496D616765536561726368444C4C5F7838362E646C6C00436170747572655F53637265656E00436170747572655F53637265656E5F5361766500436C6561725F4361636865004765745F446C6C496E666F00496D616765536561726368004D6F7573655F436C69636B004D6F7573655F436C69636B57696E004D6F7573655F4D6F7665005365617263685F496E5F496D61676500684269746D61705F4C6F616400684269746D61705F536561726368000000005006001C0000003D39473B643B683B6C3B703B843CC83CCC3CD43C000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'

	Return $sHexData
EndFunc   ;==>__ImgSearch_GetEmbeddedDLL_x86


; ===============================================================================================================================
; AUTO-INITIALIZATION
; ===============================================================================================================================
