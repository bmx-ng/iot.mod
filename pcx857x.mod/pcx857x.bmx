SuperStrict

Module iot.pcx857x

Import iot.core

Type TPcx857x Extends TGpioDriver

	Field device:TI2cDevice
	Field masterGpioController:TGpioController
	Field interrupt:Int
	
	Field pinModes:Short
	
	Field pinValues:Short
	
	Method New(device:TI2cDevice, interrupt:Int = -1, gpioController:TGpioController = Null)
		If Not device Then
			Throw New TArgumentNullException("device")
		End If
		
		Self.device = device
		Self.interrupt = interrupt
		
		If interrupt <> -1 Then
			If Not gpioController Then
				masterGpioController = New TGpioController
			End If
			masterGpioController.OpenPin(interrupt, EpinMode.Input)
		End If
		
		' These controllers do not have commands, setting the pins to high designates
		' them as able to recieve input. As we don't want to set high on pins intended
		' for output we'll set all of the pins to low for our initial state.
		If PinCount() = 8 Then
			WriteByte(0)
		Else
			InternalWriteUInt16(0)
		End If
		
		pinModes = $FFFF
	End Method
	
	Method ReadByte:Byte()
		Return device.ReadByte()
	End Method
	
	Method WriteByte(value:Byte)
		device.WriteByte(value)
	End Method
	
	Method InternalReadUInt16:Short()
		Local buffer:Byte Ptr = StackAlloc(2)
		device.Read(buffer, 2)
		Return buffer[0] | buffer[1] Shl 8
	End Method
	
	Method InternalWriteUInt16(value:Short)
		Local buffer:Byte Ptr = StackAlloc(2)
		buffer[0] = value
		buffer[1] = value Shr 8
		device.Write(buffer, 2)
	End Method
	
	Method ClosePin(pinNumber:Int)
		' no-op
	End Method
	
	Method Dispose()
		device.Dispose()
	End Method
	
	Method OpenPin(pinNumber:Int)
		' no-op
	End Method
	
	Method Read:EPinValue(pinNumber:Int)
		Local values:SPinValuePair[] = New SPinValuePair[1]
		values[0] = New SPinValuePair(pinNumber, EPinValue.Low)
		
		Read(values)
		Return values[0].PinValue
	End Method
	
	Method Read(pinValues:SPinValuePair[])
		Local vec:SPinVector32 = New SPinVector32(pinValues)
		
		If vec.pins Shr PinCount() > 0 Then
			ThrowInvalidPin("pinValues")
		End If
		
		If vec.pins & pinModes Then
			' One of the specified pins was set to output (1)
			Throw New TInvalidOperationException("Cannot read from output pins.")
		End If
		
		
		Local data:Short
		If PinCount() = 8 Then
			data = ReadByte()
		Else
			data = InternalReadUInt16()
		End If
		
		For Local i:Int = 0 Until pinValues.Length
			Local pin:Int = pinValues[i].pinNumber
			pinValues[i] = New SPinValuePair(pin, (data Shr pin) & 1)
		Next
		
	End Method

	Method ThrowInvalidPin(name:String)
		Throw New TArgumentOutOfRangeException("Pin numbers must be in the range of 0 to " + (PinCount() - 1))
	End Method

	Method ValidatePinNumber(pinNumber:Int)
		If pinNumber < 0 Or pinNumber >= PinCount() Then
			ThrowInvalidPin("pinNumber")
		End If
	End Method
	
	Method SetPinMode(pinNumber:Int, pinMode:EPinMode)
		ValidatePinNumber(pinNumber)
		
		If pinMode = EPinMode.Input Then
			pinModes = (pinModes & ~(1 Shl pinNumber))
		Else If pinMode = EPinMode.Output Then
			pinModes = (pinModes | (1 Shl pinNumber))
		Else
			Throw New TArgumentOutOfRangeException("Only Input and Output modes are supported.")
		End If
		
		WritePins(pinValues)
	End Method
	
	Method WritePins(value:Short)
		' We need to set all input pins to high
		pinValues = (value | ~pinModes)
		
		If PinCount() = 8 Then
			WriteByte(Byte(pinValues))
		Else
			InternalWriteUInt16(pinValues)
		End If
	End Method
	
	Method GetPinMode:EPinMode(pinNumber:Int)
		If (pinModes & (1 Shl pinNumber)) = 0 Then
			Return EPinMode.Input
		Else
			Return EPinMode.Output
		End If
	End Method
	
	Method Write(pinNumber:Int, value:EPinValue)
		Local values:SPinValuePair[] = New SPinValuePair[1]
		values[0] = New SPinValuePair(pinNumber, value)
		
		Write(values)
	End Method

	Method Write(pinValues:SPinValuePair[])
		Local vec:SPinVector32 = New SPinVector32(pinValues)
		
		If vec.pins Shr PinCount() > 0 Then
			ThrowInvalidPin("pinValues")
		End If
		
		If vec.pins & ~pinModes Then
			' One of the specified pins was set to input (0)
			Throw New TInvalidOperationException("Cannot write to input pins.")
		End If
		
		Local cpins:Short = Self.pinValues
		cpins :& ~vec.pins
		cpins :| vec.values
		WritePins(cpins)
	End Method
	
	Method ConvertPinNumberToLogicalNumberingScheme:Int(pinNumber:Int)
		Return pinNumber
	End Method
	
	Method IsPinModeSupported:Int(pinNumber:Int, pinMode:EPinMode)
		Return pinMode = EpinMode.Output Or pinMode = EpinMode.Input
	End Method
	
	Method AddCallbackForPinValueChangedEvent(pinNumber:Int, eventTypes:EPinEventTypes, context:Object, callback(context:Object, sender:Object, pinValueChangedEventArgs:SPinValueChangedEventArgs))
		Throw New TNotImplementedException
	End Method
	
	Method RemoveCallbackForPinValueChangedEvent(pinNumber:Int, callback(context:Object, sender:Object, pinValueChangedEventArgs:SPinValueChangedEventArgs))
		Throw New TNotImplementedException
	End Method
	
End Type

Rem
bbdoc: Base class for 8 bit I/O expanders.
End Rem
Type TPcx8574 Extends TPcx857x

	Method New(device:TI2cDevice, interrupt:Int = -1, gpioController:TGpioController = Null)
		Super.New(device, interrupt, gpioController)
	End Method

	Method PinCount:Int()
		Return 8
	End Method

End Type

Rem
bbdoc: Remote 8-bit I/O expander for I2C-bus with interrupt.
End Rem
Type TPcf8574 Extends TPcx8574

	Method New(device:TI2cDevice, interrupt:Int = -1, gpioController:TGpioController = Null)
		Super.New(device, interrupt, gpioController)
	End Method

End Type
