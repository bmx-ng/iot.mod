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

Import brl.threadpool

Import "../gpiodriver.bmx"
Import "libgpiod.bmx"

Type TLibGpiodDriver Extends TGpioDriver

	Field chipPtr:Byte Ptr
	
	Field pinNumberToLines:TGpiodLine[]
	Field pinNumberToEventHandler:TLibGpiodDriverEventHandler[]
	
	Field pool:TThreadPoolExecutor

Private
	Method New()
	End Method
Public

	Method New(gpioChip:UInt = 0)

		If Not LibGpiodAvailable() Then
			Throw New TPlatformNotSupportedException()
		End If
		
		chipPtr = gpiod_chip_open_by_number(gpioChip)
		If Not chipPtr Then
			Throw New TIOException("no chip found")
		End If
		
		pool = TThreadPoolExecutor.newCachedThreadPool()
		
		Local count:Int = PinCount()
		pinNumberToLines = New TGpiodLine[count]
		pinNumberToEventHandler = New TLibGpiodDriverEventHandler[count]
	End Method

	Method PinCount:Int()
		Return gpiod_chip_num_lines(chipPtr)
	End Method
	
	Method ConvertPinNumberToLogicalNumberingScheme:Int(pinNumber:Int)
		' not supported
	End Method
	
	Method OpenPin(pinNumber:Int)
		Local pin:TGpiodLine = TGpiodLine._create(gpiod_chip_get_line(chipPtr, UInt(pinNumber)))
		If Not pin Then
			Throw New TIOException("Error opening pin")
		End If
		
		pinNumberToLines[pinNumber] = pin
	End Method
	
	Method ClosePin(pinNumber:Int)
		Local pin:TGpiodLine = pinNumberToLines[pinNumber]
		
		If pin And Not IsListeningEvent(pinNumber) Then
			pin.Dispose()
			pinNumberToLines[pinNumber] = Null
		End If
		
	End Method
	
	Method SetPinMode(pinNumber:Int, pinMode:EPinMode)
		Local requestResult:Int = -1
		
		Local pin:TGpiodLine = pinNumberToLines[pinNumber]
		If pin Then
			If pinMode = EPinMode.Input
				requestResult = pin.RequestInput(String(pinNumber))
			Else
				requestResult = pin.RequestOutput(String(pinNumber))
			End If
			pin.SetPinMode(pinMode)
		End If
		
		If requestResult = -1 Then
			Throw New TIOException("Error setting pin mode : " + pinNumber)
		End If
	End Method
	
	Method GetPinMode:EPinMode(pinNumber:Int)
		Local pin:TGpiodLine = pinNumberToLines[pinNumber]
		If Not pin Then
			Throw New TInvalidOperationException("Pin not open : " + pinNumber)
		End If
		
		Return pin.GetPinMode()
	End Method
	
	Method IsListeningEvent:Int(pinNumber:Int)
		Return pinNumberToEventHandler[pinNumber] <> Null
	End Method
	
	Method IsPinModeSupported:Int(pinNumber:Int, pinMode:EPinMode)
		' Libgpiod Api do not support pull up or pull down resistors for now.
		Return pinMode <> EPinMode.InputPullDown And pinMode <> EPinMode.InputPullUp
	End Method
	
	Method Read:EPinValue(pinNumber:Int)
		Local pin:TGpiodLine = pinNumberToLines[pinNumber]
		If pin Then
			Local pinValue:EPinValue

			Local result:Int = pin.GetValue()
			If result = -1 Or Not EPinValue.TryConvert(result, pinValue) Then
				Throw New TIOException("Read pin error : " + pinNumber)
			End If

			Return pinValue
		Else
			Throw New TInvalidOperationException("Pin not opened : " + pinNumber)
		End If
	End Method
	
	Method Write(pinNumber:Int, value:EPinValue)
		Local pin:TGpiodLine = pinNumberToLines[pinNumber]
		If Not pin Then
			Throw New TIOException("Pin not opened : " + pinNumber)
		End If
		
		If value = EPinValue.High Then
			pin.SetValue(1)
		Else
			pin.SetValue(0)
		End If
	End Method
	
	Method AddCallbackForPinValueChangedEvent(pinNumber:Int, eventTypes:EPinEventTypes, context:Object, callback(context:Object, sender:Object, pinValueChangedEventArgs:SPinValueChangedEventArgs))
		If eventTypes & EPinEventTypes.Rising Or eventTypes & EPinEventTypes.Falling Then
			Local eventHandler:TLibGpiodDriverEventHandler = pinNumberToEventHandler[pinNumber]
			If Not eventHandler Then
				eventHandler = PopulateEventHandler(pinNumber)
			End If
			
			If eventTypes & EPinEventTypes.Rising Then
				eventHandler.valueRising.AddLast(context, callback)
			End If
			
			If eventTypes & EPinEventTypes.Falling Then
				eventHandler.valueFalling.AddLast(context, callback)
			End If
		Else
			Throw New TIOException("Invalid event type")
		End If
	End Method
	
	Method PopulateEventHandler:TLibGpiodDriverEventHandler(pinNumber:Int)
		Local pin:TGpiodLine = pinNumberToLines[pinNumber]
		If pin Then
			If Not pin.IsFree() Then
				pin.Dispose()
				pin = TGpiodLine._create(gpiod_chip_get_line(chipPtr, UInt(pinNumber)))
				pinNumberToLines[pinNumber] = pin
			EndIf
		End If
		
		Return New TLibGpiodDriverEventHandler(pinNumber, pin, pool)
	End Method
	
	Method RemoveCallbackForPinValueChangedEvent(pinNumber:Int, callback(context:Object, sender:Object, pinValueChangedEventArgs:SPinValueChangedEventArgs))
		Local eventHandler:TLibGpiodDriverEventHandler = pinNumberToEventHandler[pinNumber]
		If eventHandler Then
			eventHandler.valueFalling.Remove(callback)
			eventHandler.ValueRising.Remove(callback)
			
			If eventHandler.IsCallbackListEmpty() Then
				pinNumberToEventHandler[pinNumber] = Null
				eventHandler.Dispose()
			End If
		Else
			Throw New TIOException("Not listening for event")
		End If
	End Method
	
	Method WaitForEvent()
	End Method

	Method Dispose()
		If pinNumberToEventHandler Then
			For Local i:Int = 0 Until pinNumberToEventHandler.length
				Local handler:TLibGpiodDriverEventHandler = pinNumberToEventHandler[i]
				If handler Then
					handler.Dispose()
					pinNumberToEventHandler[i] = Null
				End If
			Next
			pinNumberToEventHandler = Null
		End If
		
		If pinNumberToLines Then
			For Local i:Int = 0 Until pinNumberToLines.length
				Local pin:TGpiodLine = pinNumberToLines[i]
				If pin Then
					pin.Dispose()
					pinNumberToLines[i] = Null
				End If
			Next
			pinNumberToLines = Null
		End If
		
		If chipPtr Then
			gpiod_chip_close(chipPtr)
			chipPtr = Null
		End If
		
	End Method

End Type

Type TGpiodLine

	Field linePtr:Byte Ptr
	Field pinMode:EPinMode
	
	Function _create:TGpiodLine(linePtr:Byte Ptr)
		If linePtr Then
			Local this:TGpiodLine = New TGpiodLine
			this.linePtr = linePtr
			Return this
		End If
	End Function
	
	Method GetPinMode:EPinMode()
		Return pinMode
	End Method
	
	Method SetPinMode(value:EPinMode)
		pinMode = value
	End Method
	
	Method GetValue:Int()
		Return gpiod_line_get_value(linePtr)
	End Method
	
	Method SetValue:Int(value:Int)
		Return gpiod_line_set_value(linePtr, value)
	End Method
	
	Method RequestInput:Int(consumer:String)
		Return gpiod_line_request_input(linePtr, consumer)
	End Method
	
	Method RequestOutput:Int(consumer:String)
		Return gpiod_line_request_output(linePtr, consumer, 0)
	End Method
	
	Method RequestBothEdgesEvents:Int(consumer:String)
		Return gpiod_line_request_both_edges_events(linePtr, consumer)
	End Method

	Rem
	bbdoc: Waits for an event on the GPIO line.
	returns: 0 if wait timed out, -1 if an error occurred, 1 if an event occurred.
	End Rem
	Method EventWait:Int(timespec:STimeSpec Var)
		Return gpiod_line_event_wait(linePtr, timespec)
	End Method
	
	Rem
	bbdoc: Reads the last event from the GPIO line.
	returns: 0 if the event was read correctly, -1 on error.
	End Rem
	Method EventRead:Int(event:SGpioLineEvent Var)
		Return gpiod_line_event_read(linePtr, event)
	End Method
	
	Method IsFree:Int()
		Return gpiod_line_is_free(linePtr)
	End Method

	Method Dispose()
		If linePtr Then
			gpiod_line_release(linePtr)
			linePtr = Null
		End If
	End Method

	Method Delete()
		Dispose()
	End Method
	
End Type


Type TLibGpiodDriverEventHandler

	Field pool:TThreadPoolExecutor
	
	' PinChangeEventHandler(object sender, PinValueChangedEventArgs pinValueChangedEventArgs
	Field valueRising:TCallbackList = New TCallbackList
	Field valueFalling:TCallbackList = New TCallbackList
	
	Field pinNumber:Int
	
	Field _shutdown:Int
	
	Method New(pinNumber:Int, pin:TGpiodLine, pool:TThreadPoolExecutor)
		Self.pool = pool
		
		Self.pinNumber = pinNumber
		' CancellationTokenSource = new CancellationTokenSource ' TODO
		SubscribeForEvent(pin)
		
		InitializeEventDetectionTask(pin)
	End Method
	
	Method SubscribeForEvent(pin:TGpiodLine)
		Local eventSuccess:Int = pin.RequestBothEdgesEvents("Listen " + pinNumber + " for both edge event")
		If eventSuccess < 0 Then
			Throw New TIOException("Request event error : " + pinNumber)
		End If
	End Method
	
	Method InitializeEventDetectionTask(pin:TGpiodLine)
		
		pool.execute(New TEventDetectionTask(Self, pinNumber, pin))
		
	End Method
	
	Method OnPinValueChanged(args:SPinValueChangedEventArgs, detectionOfEventTypes:EPinEventTypes)
		If detectionOfEventTypes = EPinEventTypes.Rising And args.changeType = EPinEventTypes.Rising Then
			If valueRising.size Then
				For Local i:Int = 0 Until valueRising.size
					Local cb:TCallback = valueRising.data[i]
					cb.data(cb.context, Self, args)
				Next
			End If
		Else
			If valueFalling.size Then
				For Local i:Int = 0 Until valueFalling.size
					Local cb:TCallback = valueFalling.data[i]
					cb.data(cb.context, Self, args)
				Next
			End If
		End If
	End Method

	Method IsCallbackListEmpty:Int()
		Return Not valueRising.size And Not valueFalling.size
	End Method
	
	Method Dispose()
		_shutdown = True
	End Method
	
End Type

Type TEventDetectionTask Extends TRunnable

	Field eventHandler:TLibGpiodDriverEventHandler
	Field pinNumber:Int
	Field pin:TGpiodLine
	
	Field timespec:STimeSpec
	
	Method New(eventHandler:TLibGpiodDriverEventHandler, pinNumber:Int, pin:TGpiodLine)
		Self.eventHandler = eventHandler
		Self.pinNumber = pinNumber
		Self.pin = pin
		
		timespec = New STimeSpec(0, 1000000)
	End Method
	
	Method Run()
	
		While Not eventHandler._shutdown
		
			Local res:Int = pin.EventWait(timespec)
			
			' error
			If res = -1 Then
				Throw New TIOException("Event wait error " + pinNumber)
			End If
		
			' event
			If res = 1 Then
			
				Local event:SGpioLineEvent
				
				If pin.EventRead(event) = -1 Then
					Throw New TIOException("Event read error " + pinNumber)
				End If
				
				eventHandler.OnPinValueChanged(New SPinValueChangedEventArgs(event.AsPinEventType(), pinNumber), event.AsPinEventType())
			
			End If
		
		Wend
	
	End Method
	
End Type

Type TCallback
	Field context:Object
	Field data(context:Object, sender:Object, pinValueChangedEventArgs:SPinValueChangedEventArgs)
	
	Method New(context:Object, data(context:Object, sender:Object, pinValueChangedEventArgs:SPinValueChangedEventArgs))
		Self.context = context
		Self.data = data
	End Method
End Type

Type TCallbackList

	Field data:TCallback[16]
	Field size:Int

	Method _ensureCapacity(newSize:Int)
		If newSize >= data.length Then
			data = data[.. newSize * 3 / 2 + 1]
		End If
	End Method

	Method Clear()
		For Local i:Int = 0 Until size
			data[i] = Null
		Next
		size = 0
	End Method

	Method IsEmpty:Int()
		Return size = 0
	End Method
	
	Method AddLast(context:Object, callback(context:Object, sender:Object, pinValueChangedEventArgs:SPinValueChangedEventArgs))
		_ensureCapacity(size + 1)
		data[size] = New TCallback(context, callback)
		size :+ 1
	End Method
	
	Method Remove(callback(context:Object, sender:Object, pinValueChangedEventArgs:SPinValueChangedEventArgs))
		If size Then
			Local offset:Int = -1
			For Local i:Int = 0 Until size
				If data[i].data = callback Then
					offset = i
				End If
			Next
			
			If offset >= 0 Then
				Local length:Int = size - offset
				If length > 0 Then
					ArrayCopy(data, offset + 1, data, offset, length)
				End If
				size :- 1
				data[size] = Null
			End If
		End If
	End Method
			
	Method _removeAt(index:Int)
		data[index] = Null
	End Method
	
End Type
