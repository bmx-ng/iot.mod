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

Import "drivers/libgpioddriver.bmx"
Import "../common.bmx"

Rem
bbdoc: Represents a general-purpose I/O (GPIO) controller.
End Rem
Type TGpioController Implements IDisposable
Private
	Field driver:TGpioDriver
	Field openPins:Int[]
	
	Method New()
	End Method
Public

	Rem
	bbdoc: The numbering scheme used to represent pins provided by the controller.
	End Rem
	Field numberingScheme:EPinNumberingScheme
	
	Method New(numberingScheme:EPinNumberingScheme = EPinNumberingScheme.Logical)
		Self.numberingScheme = numberingScheme
		driver = New TLibGpiodDriver()
		openPins = New Int[PinCount()]
	End Method
	
	Method New(numberingScheme:EPinNumberingScheme, driver:TGpioDriver)
		Self.numberingScheme = numberingScheme
		Self.driver = driver
		openPins = New Int[PinCount()]
	End Method

	Rem
	bbdoc: Returns the number of pins provided by the controller.
	End Rem
	Method PinCount:Int()
		Return driver.PinCount()
	End Method
	
	Rem
	bbdoc: Gets the logical pin number in the controller's numbering scheme.
	End Rem
	Method GetLogicalPinNumber:Int(pinNumber:Int)
		If numberingScheme = EPinNumberingScheme.Logical Then
			Return pinNumber
		Else
			Return driver.ConvertPinNumberToLogicalNumberingScheme(pinNumber)
		End If
	End Method
	
	Rem
	bbdoc: Opens a pin in order for it to be ready to use.
	End Rem
	Method OpenPin(pinNumber:Int)
		Local logicalPinNumber:Int = GetLogicalPinNumber(pinNumber)
		If openPins[logicalPinNumber] Then
			Throw New TInvalidOperationException("The selected pin is already open.")
		End If
		
		driver.OpenPin(logicalPinNumber)
		openPins[logicalPinNumber] = True
	End Method
	
	Rem
	bbdoc: Opens a pin and sets it to a specific mode.
	End Rem
	Method OpenPin(pinNumber:Int, pinMode:EPinMode)
		OpenPin(pinNumber)
		SetPinMode(pinNumber, pinMode)
	End Method
	
	Rem
	bbdoc: Closes an open pin.
	End Rem
	Method ClosePin(pinNumber:Int)
		Local logicalPinNumber:Int = GetLogicalPinNumber(pinNumber)
		If Not openPins[logicalPinNumber] Then
			Throw New TInvalidOperationException("Cannot close a pin that is not open.")
		End If
		
		driver.ClosePin(logicalPinNumber)
		openPins[logicalPinNumber] = False
	End Method
	
	Rem
	bbdoc: Sets the mode of a pin.
	End Rem
	Method SetPinMode(pinNumber:Int, pinMode:EPinMode)
		Local logicalPinNumber:Int = GetLogicalPinNumber(pinNumber)
		If Not openPins[logicalPinNumber] Then
			Throw New TInvalidOperationException("Cannot set a mode to a pin that is not open.")
		End If
		
		If Not driver.IsPinModeSupported(logicalPinNumber, pinMode) Then
			Throw New TInvalidOperationException("The pin does not support the selected mode.")
		End If
		
		driver.SetPinMode(logicalPinNumber, pinMode)
	End Method
	
	Rem
	bbdoc: Gets the mode of a pin.
	End Rem
	Method GetPinMode:EPinMode(pinNumber:Int)
		Local logicalPinNumber:Int = GetLogicalPinNumber(pinNumber)
		If Not openPins[logicalPinNumber] Then
			Throw New TInvalidOperationException("Cannot get the mode of a pin that is not open.")
		End If
		
		Return driver.GetPinMode(logicalPinNumber)
	End Method
	
	Rem
	bbdoc: Checks if a specific pin is open.
	returns: #True if the specified pin is open, #False otherwise.
	End Rem
	Method IsPinOpen:Int(pinNumber:Int)
		Local logicalPinNumber:Int = GetLogicalPinNumber(pinNumber)
		Return openPins[logicalPinNumber]
	End Method
	
	Rem
	bbdoc: Checks if a pin supports a specific mode.
	returns: #True if the mode is supported by the specified pin, #False otherwise.
	End Rem
	Method IsPinModeSupported:Int(pinNumber:Int, pinMode:EPinMode)
		Local logicalPinNumber:Int = GetLogicalPinNumber(pinNumber)
		Return driver.IsPinModeSupported(pinNumber, pinMode)
	End Method
	
	Rem
	bbdoc: Reads the current value of a pin.
	End Rem
	Method Read:EPinValue(pinNumber:Int)
		Local logicalPinNumber:Int = GetLogicalPinNumber(pinNumber)
		If Not openPins[logicalPinNumber] Then
			Throw New TInvalidOperationException("Cannot read from a pin that is not open.")
		End If
		
		If driver.GetPinMode(logicalPinNumber) = EpinMode.Output Then
			Throw New TInvalidOperationException("Cannot read from a pin that is set to Output mode.")
		End If
		
		Return driver.Read(logicalPinNumber)
	End Method
	
	Rem
	bbdoc: Writes a value to a pin.
	End Rem
	Method Write(pinNumber:Int, value:EPinValue)
		Local logicalPinNumber:Int = GetLogicalPinNumber(pinNumber)
		If Not openPins[logicalPinNumber] Then
			Throw New TInvalidOperationException("Cannot write to a pin that is not open.")
		End If
		
		If driver.GetPinMode(logicalPinNumber) <> EPinMode.Output Then
			Throw New TInvalidOperationException("Cannot write to a pin that is not set to Output mode.")
		End If
		
		driver.Write(logicalPinNumber, value)
	End Method
	
	Rem
	bbdoc: Writes the given pins with the given values.
	End Rem
	Method Write(pinValuePairs:SPinValuePair[], count:Int = 0)
		If Not count Then
			count = pinValuePairs.length
		End If
		For Local i:Int = 0 Until count
			Write(pinValuePairs[i].pinNumber, pinValuePairs[i].pinValue)
		Next
	End Method
	
	Rem
	bbdoc: Reads the given pins with the given pin numbers.
	End Rem
	Method Read(pinValuePairs:SPinValuePair[])
		For Local i:Int = 0 Until pinValuePairs.length
			Local pin:Int = pinValuePairs[i].pinNumber
			pinValuePairs[i] = New SPinValuePair(pin, Read(pin))
		Next
	End Method
Rem
	Method WaitForEvent:SWaitForEventResult(pinNumber:Int, eventTypes:EPinEventTypes, timeoutMs:Int)
		
	End Method
	
	Method WaitForEvent:SWaitForEventResult(pinNumber:Int, eventTypes:EPinEventTypes, cancellationToken:TCancellationToken)
		Local logicalPinNumber:Int = GetLogicalPinNumber(pinNumber)
		If Not openPins[logicalPinNumber] Then
			Throw New TInvalidOperationException("Cannot wait for events from a pin that is not open.")
		End If
		
		Return driver.WaitForEvent(logicalPinNumber, eventTypes, cancellationToken)
	End Method
End Rem	

	Rem
	bbdoc: Adds a callback that will be invoked when @pinNumber has an event of type @eventType.
	End Rem
	Method RegisterCallbackForPinValueChangedEvent(pinNumber:Int, eventTypes:EPinEventTypes, context:Object, callback(context:Object, sender:Object, pinValueChangedEventArgs:SPinValueChangedEventArgs))
		Local logicalPinNumber:Int = GetLogicalPinNumber(pinNumber)
		If Not openPins[logicalPinNumber] Then
			Throw New TInvalidOperationException("Cannot add callback for a pin that is not open.")
		End If
		
		driver.AddCallbackForPinValueChangedEvent(logicalPinNumber, eventTypes, context, callback)
	End Method
	
	Rem
	bbdoc: Removes a callback that was being invoked for pin at @pinNumber.
	End Rem
	Method UnregisterCallbackForPinValueChangedEvent(pinNumber:Int, callback(context:Object, sender:Object, pinValueChangedEventArgs:SPinValueChangedEventArgs))
		Local logicalPinNumber:Int = GetLogicalPinNumber(pinNumber)
		If Not openPins[logicalPinNumber] Then
			Throw New TInvalidOperationException("Cannot remove callback for a pin that is not open.")
		End If
		
		driver.RemoveCallbackForPinValueChangedEvent(logicalPinNumber, callback)
	End Method
	
	Method Dispose()
		For Local pin:Int = EachIn openPins
			driver.ClosePin(pin)
		Next
		
		openPins = Null
		driver.Dispose()
	End Method

End Type
