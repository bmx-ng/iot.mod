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

Import "../common.bmx"


Type TGpioDriver Implements IDisposable Abstract

	Method PinCount:Int() Abstract
	
	Method ConvertPinNumberToLogicalNumberingScheme:Int(pinNumber:Int) Abstract
	
	Method OpenPin(pinNumber:Int) Abstract
	
	Method ClosePin(pinNumber:Int) Abstract
	
	Method SetPinMode(pinNumber:Int, pinMode:EPinMode) Abstract
	
	Method GetPinMode:EPinMode(pinNumber:Int) Abstract
	
	Method IsPinModeSupported:Int(pinNumber:Int, pinMode:EPinMode) Abstract
	
	Method Read:EPinValue(pinNumber:Int) Abstract
	
	Method Write(pinNumber:Int, value:EPinValue) Abstract
	
	'Method WaitForEvent:SWaitForEventResult() Abstract
	
	Method AddCallbackForPinValueChangedEvent(pinNumber:Int, eventTypes:EPinEventTypes, context:Object, callback(context:Object, sender:Object, pinValueChangedEventArgs:SPinValueChangedEventArgs)) Abstract
	
	Method RemoveCallbackForPinValueChangedEvent(pinNumber:Int, callback(context:Object, sender:Object, pinValueChangedEventArgs:SPinValueChangedEventArgs)) Abstract
	
End Type

Struct SWaitForEventResult
	Field eventTypes:EPinEventTypes
	Field timedOut:Int
	
	Method New(eventTypes:EPinEventTypes, timedOut:Int)
		Self.eventTypes = eventTypes
		Self.timedOut = timedOut
	End Method
End Struct

Struct SPinValueChangedEventArgs
	Field changeType:EPinEventTypes
	Field pinNumber:Int
	
	Method New(changeType:EPinEventTypes, pinNumber:Int)
		Self.changeType = changeType
		Self.pinNumber = pinNumber
	End Method
	
End Struct

Function defaultcomparator_compare:Int(a:EPinEventTypes, b:EPinEventTypes )
	Return a.Ordinal() - b.Ordinal()
End Function
