# ImageSearch UDF v3.5

Advanced image search library for AutoIt with cache system and SIMD optimization.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
  - [Startup & Configuration](#startup--configuration)
  - [Core Search Functions](#core-search-functions)
  - [Screen Capture Functions](#screen-capture-functions)
  - [Mouse Functions](#mouse-functions)
  - [Wait & Click Functions](#wait--click-functions)
  - [Monitor Functions](#monitor-functions)
  - [Window Coordinate Functions](#window-coordinate-functions)
  - [Cache & Info Functions](#cache--info-functions)
- [Examples](#examples)
- [Error Codes](#error-codes)
- [Performance Tips](#performance-tips)
- [Changelog](#changelog)
- [License](#license)

## Overview

ImageSearchDLL UDF is a high-performance image search library for AutoIt that enables you to find images on screen or within other images. Built with C++14 and optimized with SIMD instructions (AVX512/AVX2/SSE2), it provides fast and accurate image matching capabilities.

## Features

- **High Performance**: SIMD optimization (AVX512/AVX2/SSE2) for fast searching
- **Multi-Monitor Support**: Full support for multi-monitor setups with negative coordinates
- **DPI Awareness**: Thread-local DPI awareness without affecting AutoIt GUI
- **Cache System**: Persistent cache for 30-50% speed boost on repeated searches
- **Image Scaling**: Search for images at different scales (0.1x to 5.0x)
- **Multiple Formats**: Support for BMP, PNG, JPG, and other image formats
- **Screen Capture**: Direct screen capture with DPI-aware coordinates
- **Mouse Automation**: Precise mouse movement and clicking with multi-monitor support

## Requirements

- **AutoIt**: Version 3.3.16.1 or higher
- **Windows**: XP SP3 to Windows 11
- **Architecture**: x86 or x64 (automatic detection)
- **DLL**: ImageSearchDLL (included)

## Installation

1. Download the UDF package
2. Place `ImageSearchDLL_UDF.au3` in your script directory
3. Ensure the appropriate DLL is in the same directory:
   - `ImageSearchDLL_x64.dll` for 64-bit AutoIt
   - `ImageSearchDLL_x86.dll` for 32-bit AutoIt
Not required in embedded version! (But need to install Visual C++ Redistributable 2015-2022)

4. Include the UDF in your script:

```autoit
#include "ImageSearchDLL_UDF.au3"
```

## Quick Start

### Basic Image Search

```autoit
#include "ImageSearchDLL_UDF.au3"

; Search for a button on screen
Local $aResult = _ImageSearch("button.png")
If $aResult[0] > 0 Then
    ConsoleWrite("Found at: " & $aResult[1][0] & ", " & $aResult[1][1] & @CRLF)
    MouseClick("left", $aResult[1][0], $aResult[1][1])
Else
    ConsoleWrite("Image not found" & @CRLF)
EndIf
```

### Wait for Image and Click

```autoit
; Wait up to 5 seconds for button to appear, then click it
If _ImageSearch_WaitClick(5000, "button.png") Then
    MsgBox(0, "Success", "Button clicked!")
Else
    MsgBox(0, "Failed", "Button not found within 5 seconds")
EndIf
```

### Screen Capture

```autoit
; Capture a region and save as PNG
_ImageSearch_ScreenCapture_SaveImage(@ScriptDir & "\screenshot.png", 100, 100, 600, 400)

; Capture full screen
_ImageSearch_ScreenCapture_SaveImage(@ScriptDir & "\fullscreen.png")
```

## API Reference

### Startup & Configuration

#### _ImageSearch_Startup()
Initializes the ImageSearch library by loading the appropriate DLL.

**Returns:**
- Success: 1 (DLL loaded successfully)
- Failure: 0 and sets @error

**Remarks:** 
- Must be called before using any search functions
- Automatically called on script start
- DLL v3.5+ uses thread-local DPI awareness and won't affect AutoIt GUI

#### _ImageSearch_Shutdown()
Closes the DLL and cleans up resources.

#### _ImageSearch_SetDllPath($sPath)
Sets a custom DLL path (must be called before _ImageSearch_Startup).

**Parameters:**
- `$sPath` - Full path to the DLL file

**Returns:**
- Success: 1
- Failure: 0 (file not found)

### Core Search Functions

#### _ImageSearch($sImagePath [, $iLeft, $iTop, $iRight, $iBottom [, $iScreen [, $iTolerance [, $iResults [, $iCenterPOS [, $fMinScale [, $fMaxScale [, $fScaleStep [, $iReturnDebug [, $iUseCache]]]]]]]])
Searches for an image within a specified screen area.

**Parameters:**
- `$sImagePath` - Image file path(s), multiple separated by "|"
- `$iLeft, $iTop, $iRight, $iBottom` - Search region (0 = entire screen)
- `$iScreen` - Monitor index (-1 = virtual screen, 0 = primary, 1+ = specific monitor)
- `$iTolerance` - Color tolerance 0-255 (default: 10)
- `$iResults` - Max results 1-1024 (default: 1)
- `$iCenterPOS` - Return center (1) or top-left (0) coordinates (default: 1)
- `$fMinScale, $fMaxScale` - Scale range 0.1-5.0 (default: 1.0)
- `$fScaleStep` - Scale step (default: 0.1)
- `$iReturnDebug` - Debug mode (default: 0)
- `$iUseCache` - Enable cache (default: 1)

**Returns:**
- Success: Array of found positions `[count][X, Y, Width, Height]`
- Failure: Empty array with @error set

**Example:**
```autoit
; Search for multiple images with scaling
Local $aResult = _ImageSearch("icon1.png|icon2.png", 0, 0, 800, 600, -1, 10, 5, 1, 0.8, 1.2, 0.1)
If $aResult[0] > 0 Then
    For $i = 1 To $aResult[0]
        ConsoleWrite("Match " & $i & " at: " & $aResult[$i][0] & ", " & $aResult[$i][1] & @CRLF)
    Next
EndIf
```

#### _ImageSearch_InImage($sSourceImage, $sTargetImage [, $iTolerance [, $iResults [, $iCenterPOS [, $fMinScale [, $fMaxScale [, $fScaleStep [, $iReturnDebug [, $iUseCache]]]]]]]])
Searches for a target image within a source image (file-to-file search).

**Parameters:**
- `$sSourceImage` - Path to source image file
- `$sTargetImage` - Path to target image file(s), multiple separated by "|"
- Other parameters same as `_ImageSearch`

**Returns:** Same as `_ImageSearch`

**Remarks:** Useful for pre-processing images or testing without screen capture

**Example:**
```autoit
$aResult = _ImageSearch_InImage("screenshot.png", "button.png", 20)
```

#### _ImageSearch_hBitmap($hBitmapSource, $hBitmapTarget [, $iTolerance [, $iLeft [, $iTop [, $iRight [, $iBottom [, $iResults [, $iCenterPOS [, $fMinScale [, $fMaxScale [, $fScaleStep [, $iReturnDebug [, $iUseCache]]]]]]]]]]]])
Searches for a target bitmap within a source bitmap (memory-to-memory search).

**Parameters:**
- `$hBitmapSource` - Handle to source bitmap (HBITMAP)
- `$hBitmapTarget` - Handle to target bitmap (HBITMAP)
- Other parameters same as `_ImageSearch`

**Returns:** Same as `_ImageSearch`

**Remarks:** 
- Fastest method for repeated searches (no disk I/O)
- Bitmaps must be created with GDI/GDI+ functions

### Screen Capture Functions

#### _ImageSearch_CaptureScreen([$iLeft, $iTop, $iRight, $iBottom [, $iScreen]])
Capture screen region and return as HBITMAP handle.

**Parameters:**
- `$iLeft, $iTop, $iRight, $iBottom` - Capture region (default: 0 = full screen)
- `$iScreen` - Monitor index (default: -1 = virtual screen)

**Returns:**
- Success: HBITMAP handle (must DeleteObject when done)
- Failure: 0 and sets @error

**Example:**
```autoit
$hBitmap = _ImageSearch_CaptureScreen(0, 0, 800, 600)
; ... use $hBitmap ...
_WinAPI_DeleteObject($hBitmap)
```

#### _ImageSearch_ScreenCapture_SaveImage($sImageFile [, $iLeft [, $iTop [, $iRight [, $iBottom [, $iScreen]]]]])
Captures a screen region and saves it directly to an image file in one call.

**Parameters:**
- `$sImageFile` - Output file path (extension determines format: .bmp, .png, .jpg/.jpeg)
- `$iLeft, $iTop, $iRight, $iBottom` - Capture region (default: 0 = full screen)
- `$iScreen` - Monitor index (default: 0 = primary screen)

**Returns:**
- Success: True (1)
- Failure: False (0) and sets @error

**Remarks:**
- Automatically detects format from file extension
- ~2x faster than separate capture + save operations
- JPEG quality is fixed at 100% (highest quality)
- Uses DPI-aware capture (accurate on all DPI scales)

**Example:**
```autoit
; Capture full primary screen to PNG
_ImageSearch_ScreenCapture_SaveImage(@ScriptDir & "\screenshot.png")

; Capture region on monitor 2 to JPEG
_ImageSearch_ScreenCapture_SaveImage(@ScriptDir & "\region.jpg", 100, 100, 600, 400, 2)
```

#### _ImageSearch_hBitmapLoad($sImageFile [, $iAlpha [, $iRed [, $iGreen [, $iBlue]]]])
Load image file and convert to HBITMAP handle.

**Parameters:**
- `$sImageFile` - Path to image file
- `$iAlpha, $iRed, $iGreen, $iBlue` - Background color components 0-255 (default: 0 = transparent)

**Returns:**
- Success: HBITMAP handle (must DeleteObject when done)
- Failure: 0 and sets @error

**Example:**
```autoit
$hBitmap = _ImageSearch_hBitmapLoad("image.png", 255, 255, 255, 255) ; White background
; ... use $hBitmap ...
_WinAPI_DeleteObject($hBitmap)
```

### Mouse Functions

#### _ImageSearch_MouseMove($iX, $iY [, $iSpeed [, $iScreen]])
Moves mouse cursor to coordinates (supports negative coordinates on multi-monitor).

**Parameters:**
- `$iX, $iY` - Target coordinates (-1 = keep current position)
- `$iSpeed` - Speed 0-100 (0=instant, default: 0)
- `$iScreen` - Monitor index (default: -1 = virtual screen)

**Returns:** 1 on success, 0 on failure

#### _ImageSearch_MouseClick([$sButton [, $iX [, $iY [, $iClicks [, $iSpeed [, $iScreen]]]]]])
Clicks mouse at coordinates (screen or current position).

**Parameters:**
- `$sButton` - Button: "left", "right", "middle" (default: "left")
- `$iX, $iY` - Coordinates (-1 = current position)
- `$iClicks` - Number of clicks (default: 1)
- `$iSpeed` - Speed 0-100 (0=instant, default: 0)
- `$iScreen` - Monitor index (default: -1 = virtual screen)

**Returns:** 1 on success, 0 on failure

#### _ImageSearch_MouseClickWin($sTitle, $sText, $iX, $iY [, $sButton [, $iClicks [, $iSpeed]]])
Clicks mouse in a window.

**Parameters:**
- `$sTitle` - Window title/class/handle
- `$sText` - Window text
- `$iX, $iY` - Relative coordinates in window
- `$sButton` - Button (default: "left")
- `$iClicks` - Number of clicks (default: 1)
- `$iSpeed` - Speed 0-100 (default: 0)

**Returns:** 1 on success, 0 on failure

### Wait & Click Functions

#### _ImageSearch_Wait($iTimeout, $sImagePath [, $iLeft [, $iTop [, $iRight [, $iBottom [, $iScreen [, $iTolerance [, $iResults [, $iCenterPOS [, $fMinScale [, $fMaxScale [, $fScaleStep [, $iReturnDebug [, $iUseCache [, $iMaxAttempts]]]]]]]]]]]]])
Waits for an image to appear on screen with timeout and optional max attempts limit.

**Parameters:**
- `$iTimeout` - Timeout in milliseconds (0 = wait forever)
- `$sImagePath` - Image file path(s), multiple separated by "|"
- `$iMaxAttempts` - Max number of search attempts (0 = unlimited, default: 0)
- Other parameters same as `_ImageSearch`

**Returns:**
- Success: 2D Array (same as `_ImageSearch`)
- Timeout: Empty array with `[0][0] = 0`

**Example:**
```autoit
; Wait 5 seconds for button (unlimited attempts)
$aResult = _ImageSearch_Wait(5000, "button.png")
If $aResult[0] > 0 Then
    MouseClick("left", $aResult[1][0], $aResult[1][1])
Else
    MsgBox(0, "Timeout", "Button not found")
EndIf
```

#### _ImageSearch_WaitClick($iTimeout, $sImagePath [, $sButton [, $iClicks [, $iLeft [, $iTop [, $iRight [, $iBottom [, $iScreen [, $iTolerance [, $iResults [, $iCenterPOS [, $fMinScale [, $fMaxScale [, $fScaleStep [, $iReturnDebug [, $iUseCache]]]]]]]]]]]]])
Waits for an image and clicks it when found.

**Parameters:**
- `$iTimeout` - Timeout in milliseconds (0 = wait forever)
- `$sImagePath` - Image file path(s)
- `$sButton` - Mouse button: "left", "right", "middle" (default: "left")
- `$iClicks` - Number of clicks (default: 1)
- Other parameters same as `_ImageSearch`

**Returns:**
- Success: 1 (image found and clicked)
- Timeout: 0 (image not found)

### Monitor Functions

#### _ImageSearch_Monitor_GetList()
Gets a list of all connected display monitors and their properties.

**Returns:**
- Success: The number of monitors found. @extended contains a detailed log.
- Failure: 0 and sets @error

**Remarks:** 
- Populates the global `$g_aMonitorList`
- Called automatically by `_ImageSearch_Startup`

#### _ImageSearch_Monitor_ToVirtual($iMonitor, $iX, $iY)
Converts local monitor coordinates to virtual screen coordinates.

**Parameters:**
- `$iMonitor` - The 1-based index of the monitor
- `$iX, $iY` - Coordinates relative to the monitor's top-left corner

**Returns:**
- Success: A 2-element array `[$vX, $vY]` containing virtual screen coordinates
- Failure: 0 and sets @error

#### _ImageSearch_Monitor_FromVirtual($iMonitor, $iX, $iY)
Converts virtual screen coordinates to local monitor coordinates.

**Parameters:**
- `$iMonitor` - The 1-based index of the monitor
- `$iX, $iY` - Virtual screen coordinates

**Returns:**
- Success: A 2-element array `[$lX, $lY]` containing local monitor coordinates
- Failure: 0 and sets @error

#### _ImageSearch_Monitor_Current()
Detects which monitor contains the current mouse cursor position.

**Returns:**
- Success: Monitor index (1-based) where the cursor is located
- Failure: 0 and sets @error

#### _ImageSearch_Monitor_GetAtPosition([$iX [, $iY]])
Returns detailed information string about the monitor at specified position.

**Parameters:**
- `$iX, $iY` - Coordinates (default: -1 = use mouse cursor position)

**Returns:**
- Success: String describing the monitor (e.g., "Monitor 2: 1920x1080 (Primary)")
- Failure: Error message string

### Window Coordinate Functions

#### _ImageSearch_Window_ToScreen($hWnd, $iX, $iY [, $bClientArea])
Converts window-relative coordinates to screen (virtual desktop) coordinates.

**Parameters:**
- `$hWnd` - Window handle or title
- `$iX, $iY` - Coordinates relative to window
- `$bClientArea` - True = relative to client area, False = relative to window (default: True)

**Returns:**
- Success: A 2-element array `[$screenX, $screenY]` containing screen coordinates
- Failure: 0 and sets @error

#### _ImageSearch_Window_FromScreen($hWnd, $iScreenX, $iScreenY [, $bClientArea])
Converts screen (virtual desktop) coordinates to window-relative coordinates.

**Parameters:**
- `$hWnd` - Window handle or title
- `$iScreenX, $iScreenY` - Screen coordinates
- `$bClientArea` - True = relative to client area, False = relative to window (default: True)

**Returns:**
- Success: A 2-element array `[$winX, $winY]` containing window-relative coordinates
- Failure: 0 and sets @error

### Cache & Info Functions

#### _ImageSearch_WarmUpCache($sImagePaths [, $bEnableCache])
Pre-loads images into cache for faster subsequent searches.

**Parameters:**
- `$sImagePaths` - Pipe-separated list of images to preload
- `$bEnableCache` - Enable persistent cache (default: True)

**Returns:**
- Success: Number of images cached
- Failure: 0

**Example:**
```autoit
_ImageSearch_WarmUpCache("btn1.png|btn2.png|icon.png")
```

#### _ImageSearch_ClearCache()
Clears the internal bitmap and location cache.

**Remarks:** 
- Useful for freeing memory or forcing re-scan after image updates
- Clears both in-memory cache and persistent disk cache

#### _ImageSearch_GetDllInfo([$bForceRefresh])
Gets comprehensive DLL information in INI format.

**Parameters:**
- `$bForceRefresh` - Force refresh of cached info (default: True)

**Returns:** Multi-line string in INI format with sections:
- `[DLL]` - DLL name, version, architecture, author
- `[OS]` - OS name, version, build, platform
- `[CPU]` - Threads, SSE2, AVX2, AVX512 support
- `[SCREEN]` - Virtual screen, scale, monitors with individual resolutions
- `[CACHE]` - Location cache, bitmap cache, pool size

#### _ImageSearch_GetInfo()
Gets formatted DLL and system information for display.

**Returns:** Formatted string with DLL info, cache status, and screen information

#### _ImageSearch_GetDllValue($sSection, $sKey)
Quick accessor to read any value from cached DLL Info.

**Parameters:**
- `$sSection` - Section name (DLL, OS, CPU, SCREEN, CACHE)
- `$sKey` - Key name

**Returns:** Value string or "" if not found

**Example:**
```autoit
$sVersion = _ImageSearch_GetDllValue("DLL", "Version")
$sOSName = _ImageSearch_GetDllValue("OS", "Name")
$iThreads = _ImageSearch_GetDllValue("CPU", "Threads")
```

#### _ImageSearch_GetLastResult()
Gets the raw DLL return string from the last search.

**Returns:** Raw result string (e.g., "{2}[100|200|32|32,150|250|32|32]<debug info>")

**Remarks:** Useful for debugging or custom parsing

#### _ImageSearch_GetScale([$iScreen])
Gets the DPI scale factor for a specific monitor as a decimal number.

**Parameters:**
- `$iScreen` - Monitor index (0 = Primary, 1+ = specific monitor number)

**Returns:** Scale factor as number (e.g., 1.0, 1.25, 1.5) or 0 if not found

**Example:**
```autoit
$fScale = _ImageSearch_GetScale(0)  ; Get primary monitor scale (e.g., 1.25)
$fScale = _ImageSearch_GetScale(2)  ; Get monitor 2 scale
```

## Examples

### Advanced Search with Multiple Images and Scaling

```autoit
#include "ImageSearchDLL_UDF.au3"

; Search for multiple UI elements with different scales
Local $sImages = "button_ok.png|button_cancel.png|icon_settings.png"
Local $aResult = _ImageSearch($sImages, 0, 0, 1920, 1080, -1, 15, 10, 1, 0.8, 1.3, 0.1, 0, 1)

If $aResult[0] > 0 Then
    ConsoleWrite("Found " & $aResult[0] & " matches:" & @CRLF)
    For $i = 1 To $aResult[0]
        ConsoleWrite("  Match " & $i & ": X=" & $aResult[$i][0] & ", Y=" & $aResult[$i][1] & 
                     ", W=" & $aResult[$i][2] & ", H=" & $aResult[$i][3] & @CRLF)
    Next
Else
    ConsoleWrite("No matches found" & @CRLF)
EndIf
```

### Multi-Monitor Screen Capture

```autoit
#include "ImageSearchDLL_UDF.au3"

; Get monitor information
_ImageSearch_Monitor_GetList()
ConsoleWrite("Detected " & $g_aMonitorList[0][0] & " monitors" & @CRLF)

; Capture each monitor separately
For $i = 1 To $g_aMonitorList[0][0]
    Local $sFile = @ScriptDir & "\monitor_" & $i & ".png"
    _ImageSearch_ScreenCapture_SaveImage($sFile, 0, 0, 0, 0, $i)
    ConsoleWrite("Captured monitor " & $i & " to: " & $sFile & @CRLF)
Next

; Capture entire virtual desktop
_ImageSearch_ScreenCapture_SaveImage(@ScriptDir & "\virtual_desktop.png", 0, 0, 0, 0, -1)
```

### Automated UI Testing

```autoit
#include "ImageSearchDLL_UDF.au3"

; Pre-load images for better performance
_ImageSearch_WarmUpCache("login_button.png|username_field.png|password_field.png")

; Wait for login screen and interact
If _ImageSearch_WaitClick(10000, "login_button.png") Then
    ConsoleWrite("Login button clicked" & @CRLF)
    
    ; Find username field and click
    Local $aUsername = _ImageSearch_Wait(5000, "username_field.png")
    If $aUsername[0] > 0 Then
        MouseClick("left", $aUsername[1][0], $aUsername[1][1])
        Send("myusername")
        
        ; Find password field and click
        Local $aPassword = _ImageSearch_Wait(5000, "password_field.png")
        If $aPassword[0] > 0 Then
            MouseClick("left", $aPassword[1][0], $aPassword[1][1])
            Send("mypassword")
            Send("{ENTER}")
        EndIf
    EndIf
Else
    MsgBox(0, "Error", "Login screen not found within 10 seconds")
EndIf
```

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| -1 | `$IMGSE_INVALID_PATH` | Invalid file path |
| -2 | `$IMGSE_FAILED_TO_LOAD_IMAGE` | Failed to load image |
| -3 | `$IMGSE_FAILED_TO_GET_SCREEN_DC` | Failed to get screen device context |
| -4 | `$IMGSE_INVALID_SEARCH_REGION` | Invalid search region |
| -5 | `$IMGSE_INVALID_PARAMETERS` | Invalid parameters |
| -6 | `$IMGSE_INVALID_SOURCE_BITMAP` | Invalid source bitmap |
| -7 | `$IMGSE_INVALID_TARGET_BITMAP` | Invalid target bitmap |
| -9 | `$IMGSE_RESULT_TOO_LARGE` | Result too large |
| -10 | `$IMGSE_INVALID_MONITOR` | Invalid monitor |

## Performance Tips

1. **Use Cache**: Enable cache for repeated searches to get 30-50% speed boost
2. **Pre-load Images**: Use `_ImageSearch_WarmUpCache()` during initialization
3. **Limit Search Area**: Specify search regions instead of full screen when possible
4. **Optimize Tolerance**: Use appropriate tolerance values (5-15 for most cases)
5. **Use Appropriate Scale Range**: Limit scale range to what you actually need
6. **Monitor Selection**: Use specific monitor index for faster searches on multi-monitor setups
7. **Image Format**: BMP files load faster than PNG/JPG but are larger
8. **Memory Management**: Always call `_WinAPI_DeleteObject()` for HBITMAP handles

## Changelog

### Version 3.5
- Added thread-local DPI awareness (no GUI resize issues)
- Enhanced multi-monitor support with individual monitor scales
- Improved cache system with persistent disk cache
- Added `_ImageSearch_ScreenCapture_SaveImage()` for direct file saving
- Performance optimizations with SIMD instructions
- Better error handling and debugging information

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

**Dao Van Trong** - [TRONG.PRO](https://trong.pro)

---

For more information, examples, and updates, visit the project repository.
