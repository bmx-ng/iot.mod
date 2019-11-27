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

Rem
bbdoc: Software PWM channel.
End Rem
Module iot.SoftPwm

Import iot.core
Import brl.timer

Rem
bbdoc: Software PWM channel implementation
End Rem
Type TSoftwarePwmChannel Extends TPwmChannel

	Field currentPulseWidth:Double
	Field pulseFrequency:Double
	Field frequency:Int
	
	Field percentage:Double
	Field usePrecisionTimer:Int
	
	Field isRunning:Int
	Field isStopped:Int = True

	Field servoPin:Int = -1
	
	Field runningThread:TThread
	Field controller:TGpioController
	Field runThread:Int = True
	Field shouldDispose:Int
	
	Field chrono:TChrono = TChrono.Create()
	
	Method New(pinNumber:Int, frequency:Int = 400, dutyCycle:Double = 0.5, usePrecisionTimer:Int = False, controller:TGpioController = Null, shouldDispose:Int = True)
		If Not controller Then
			Self.controller = New TGpioController()
			Self.shouldDispose = True
		Else
			Self.controller = controller
			Self.shouldDispose = shouldDispose
		End If
		
		If Not controller Then
			Print "GPIO does not exist on the current system."
			Return
		End If
		
		servoPin = pinNumber
		controller.OpenPin(servoPin, EPinMode.Output)
		Self.usePrecisionTimer = usePrecisionTimer
		isRunning = False
		
		runningThread = TThread.Create(_RunSoftPWM, Self)
		
		Self.frequency = frequency
		If frequency > 0 Then
			pulseFrequency = 1.0 / frequency * 1000.0
		End If
		
		SetDutyCycle(dutyCycle)
	End Method
	
	Rem
	bbdoc: Gets the frequency in hertz.
	End Rem
	Method GetFrequency:Int()
		Return frequency
	End Method
	
	Rem
	bbdoc: Sets the frequency in hertz.
	End Rem
	Method SetFrequency(value:Int)
		If value < 0 Then
			Throw New TArgumentOutOfRangeException("Value must note be negative.")
		End If
		
		frequency = value
		If frequency > 0 Then
			pulseFrequency = 1 / frequency * 1000.0
		Else
			pulseFrequency = 0.0
		End If
		
		UpdateRange()
	End Method

	Rem
	bbdoc: Gets the duty cycle percentage represented as a value between 0.0 and 1.0.
	End Rem
	Method GetDutyCycle:Double()
		Return percentage
	End Method
	
	Rem
	bbdoc: Sets the duty cycle percentage represented as a value between 0.0 and 1.0.
	End Rem
	Method SetDutyCycle(value:Double)
		If value < 0.0 Or value > 1.0 Then
			Throw New TArgumentOutOfRangeException("Value must be between 0.0 and 1.0.")
		End If
		percentage = value
		UpdateRange()
	End Method

Private
	Method UpdateRange()
		currentPulseWidth = percentage * pulseFrequency
	End Method
	
	Function _RunSoftPWM:Object(data:Object)
		TSoftwarePwmChannel(data).RunSoftPWM()
	End Function
	
	Method RunSoftPWM()
		
		While runThread
			' Write the pin high for the appropriate length of time
			If isRunning Then
				If currentPulseWidth <> 0 Then
					controller.Write(servoPin, EPinValue.High)
					isStopped = False
				End If
				
				' Use the wait helper method to wait for the length of the pulse
				Wait(currentPulseWidth)
				
				' The pulse if over and so set the pin to low and then wait until it's time for the next pulse
				controller.Write(servoPin, EPinValue.Low)
				
				Wait(pulseFrequency - currentPulseWidth)
				
			Else
				If Not isStopped Then
					controller.Write(servoPin, EPinValue.Low)
					isStopped = True
				End If
			End If
		
		Wend
	End Method
	
	Method Wait(milliseconds:Double)
		Local initialTick:ULong = chrono.GetElapsedTicks()
		Local initialElapsed:ULong = chrono.GetElapsedMilliseconds()
		Local desiredTicks:Double = milliseconds / 1000.0 * TChrono.frequency
		Local finalTick:Double = initialTick + desiredTicks
		While chrono.GetElapsedTicks() < finalTick
		Wend
	End Method
Public
	Rem
	bbdoc: Starts the PWM channel.
	End Rem
	Method Start()
		isRunning = True
	End Method
	
	Rem
	bbdoc: Stops the PWM channel.
	End Rem
	Method Stop()
		isRunning = False
	End Method
	
	Method Dispose()
		isRunning = False
		runThread = False
		If runningThread Then
			runningThread.Wait()
		End If
		
		If shouldDispose Then
			If controller Then
				controller.Dispose()
				controller = Null
			End If
		End If
	End Method
	
End Type
