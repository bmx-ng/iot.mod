' Copyright (c) .NET Foundation and Contributors
' Copyright (c) 2019 Bruce A Henderson
' 
' All rights reserved.
' 
' Permission is hereby granted, free of charge, to any person obtaining a copy
' of this software and associated documentation files (the "Software"), to deal
' in the Software without restriction, including without limitation the rights
' to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
' copies of the Software, and to permit persons to whom the Software is
' furnished to do so, subject to the following conditions:
' 
' The above copyright notice and this permission notice shall be included in all
' copies or substantial portions of the Software.
' 
' THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
' IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
' FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
' AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
' LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
' OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
' SOFTWARE.
' 
SuperStrict

Import brl.filesystem
Import brl.textstream
Import "../gpiodriver.bmx"

Rem
bbdoc: A SysFs GPIO driver.
End Rem
Type TSysFsGpioDriver Implements IDisposable

	Const GPIO_BASE_PATH:String = "/sys/class/gpio"
Private
	Field exportedPins:TIntArrayList = New TIntArrayList
Public
	Rem
	bbdoc: Opens a pin in order for it to be ready to use.
	End Rem
	Method OpenPin(pinNumber:Int)
		Local pinPath:String = GPIO_BASE_PATH + "/gpio" + pinNumber
		
		If Not FileType(pinPath) Then
			SaveText(pinNumber, GPIO_BASE_PATH + "/export")
			exportedPins.Add(pinNumber)
		End If
	End Method

	Method ClosePin(pinNumber:Int)
		Local pinPath:String = GPIO_BASE_PATH + "/gpio" + pinNumber
		If FileType(pinPath) = FILETYPE_DIR Then
			SetPinEventsToDetect(pinNumber, EPinEventTypes.None)
			SaveText(pinNumber, GPIO_BASE_PATH + "/unexport")
			exportedPins.Remove(pinNumber)
		End If
	End Method

	Method SetPinMode(pinNumber:Int, pinMode:EPinMode)
		If pinMode = EpinMode.InputPullDown Or pinMode = EpinMode.InputPullUp Then
			Throw "This driver is generic so it does not support Input Pull Down or Input Pull Up modes."
		End If
		
		Local directionPath:String = GPIO_BASE_PATH + "/gpio" + pinNumber + "/direction"
		Local sysfsMode:String = ConvertPinModeToSysFsMode(pinMode)
		
		If FileType(directionPath) = FILETYPE_DIR Then
			Try
				SaveText(sysfsMode, directionPath)
			Catch e:TStreamWriteException
				Throw "Setting a mode to a pin requires root permissions."
			End Try
		Else
			Throw "There was an attempt to set a mode to a pin that is not open."
		End If
	End Method
	
	Method ConvertPinModeToSysFsMode:String(pinMode:EPinMode)
		Select pinMode
			Case EPinMode.Input
				Return "in"
			Case EPinMode.Output
				Return "out"
		End Select
		
		Throw New TPlatformNotSupportedException(pinMode + " is not supported by this driver.")
	End Method


	Method SetPinEventsToDetect(pinNumber:Int, eventType:EPinEventTypes)
		Local edgePath:String = GPIO_BASE_PATH
	End Method
	
	Method ConvertSysFsModeToPinMode:EPinMode(sysfsMode:String)
		sysfsMode = sysfsMode.Trim()
		Select sysfsMode
			Case "in"
				Return EPinMode.Input
			Case "out"
				Return EPinMode.Output
		End Select
		
		Throw New TArgumentException("Unable to parse " + sysfsMode + " as a pinMode.")
	End Method
	
	Method Read:Int(pinNumber:Int)
		Local result:Int
		
		Local valuePath:String = GPIO_BASE_PATH + "/gpio" + pinNumber + "/value"
		If FileType(valuePath) = FILETYPE_DIR Then
			Try
				Local valueContents:String = LoadText(valuePath)
				result = ConvertSysFsValueToPinValue(valueContents)
			Catch e:TStreamReadException
				Throw New TUnauthorizedAccessException("Reading a pin value requires root permissions.")
			End Try
		Else
			Throw New TInvalidOperationException("There was an attempt to read from a pin that is not open.")
		End If
		
		Return result
	End Method
	
	Method ConvertSysFsValueToPinValue:Int(value:String)
	End Method
	
	Method Write(pinNumber:Int, value:Int)
	End Method
	
	Method ConvertPinValueToSysFs:String(value:Int)
	End Method
	
	Method IsPinModeSupported:Int(pinNumber:Int, pinMode:EPinMode)
	End Method
	
	Method GetPinEventsToDetect:Int(pinNumber:Int)
	End Method
	
	Method StringValueToPinEventType:EPinEventTypes(value:String)
	End Method
	
	Method PinEventTypeToStringValue:String(kind:EPinEventTypes)
	End Method
	
	Method GetPinMode:EPinMode(pinNumber:Int)
		Local directionPath:String = GPIO_BASE_PATH + "/gpio" + pinNumber + "/direction"
		If FileType(directionPath) = FILETYPE_DIR Then
			Try
				Local sysfsMode:String = LoadText(directionPath)
				Return ConvertSysFsModeToPinMode(sysfsMode)
			Catch e:TStreamReadException
				Throw New TUnauthorizedAccessException("Getting a mode to a pin requires root permissions.")
			End Try
		Else
			Throw New TInvalidOperationException("There was an attempt to get a mode to a pin that is not open.")
		End If
	End Method
	
End Type
