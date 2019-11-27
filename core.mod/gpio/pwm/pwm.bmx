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

Import "../../common.bmx"
Import brl.filesystem
Import brl.textstream

Rem
bbdoc: Represents a single PWM channel.
End Rem
Type TPwmChannel Implements IDisposable

	Private
	
	Field ReadOnly chip:Int
	Field ReadOnly channel:Int
	
	Field ReadOnly chipPath:String
	Field ReadOnly channelPath:String
	
	Field dutyCycleStream:TStream
	Field frequencyStream:TStream
	
	Field frequency:Int
	Field dutyCycle:Double
	
	Public
	
	Method New(chip:Int, channel:Int, frequency:Int = 400, dutyCycle:Double = 0.5)
		Self.chip = chip
		Self.channel = channel
		Self.chipPath = "/sys/class/pwm/pwmchip" + chip
		Self.channelPath = chipPath + "/pwm" + channel
		
		Validate()
		Open()
		
		' avoid opening the file for operations changing relatively frequently
		dutyCycleStream = OpenStream("utf8::" + channelPath + "/duty_cycle", True)
		frequencyStream = OpenStream("utf8::" + channelPath + "/period", True)

		SetFrequency(frequency)
		SetDutyCycle(dutyCycle)
	End Method

Private
	Method Validate()
		If Not FileType(chipPath) Then
			Throw New TArgumentException("The chip number " + chip + " is invalid or is not enabled.")
		End If
		
		Local npwmPath:String = chipPath + "/npwm"
		
		Try
			Local s:String = LoadText(npwmPath)
			Local numberOfSupportedChannels:Int = s.ToInt()
			
			If channel < 0 Or channel >= numberOfSupportedChannels Then
				Throw New TArgumentException("The PWM chip " + chip + " does not support the channel " + channel + ".")
			End If
			
		Catch e:Object
			Throw New TArgumentException("Unable to parse the number of supported channels at " + npwmPath)
		End Try
	End Method

	Method Close()
		If FileType(channelPath) = FILETYPE_DIR Then
			SaveText(channel, chipPath + "/unexport", ETextStreamFormat.UTF8, False)
		End If
	End Method

	Method Open()
		If Not FileType(channelPath) Then
			SaveText(channel, chipPath + "/export", ETextStreamFormat.UTF8, False)
		End If
	End Method
Public
	Rem
	bbdoc: Returns the frequency in hertz.
	End Rem
	Method GetFrequency:Int()
		Return frequency
	End Method
	
	Rem
	bbdoc: Gets the frequency period, in nanoseconds.
	End Rem
	Function GetPeriodInNanoseconds:Int(frequency:Int)
		Return ((1.0:Double / frequency) * 1000000000)
	End Function
	
	Rem
	bbdoc: Sets the frequency in hertz.
	End Rem
	Method SetFrequency(value:Int)
		If value < 0 Then
			Throw New TArgumentOutOfRangeException("Value must not be negative.")
		End If
		
		Local periodInNanoseconds:Int = GetPeriodInNanoseconds(value)
		frequencyStream.SetSize(0)
		frequencyStream.WriteString(periodInNanoseconds)
		frequencyStream.Flush()
		frequency = value
	End Method
	
	Rem
	bbdoc: Returns the duty cycle represented as a value between 0.0 and 1.0.
	End Rem
	Method GetDutyCycle:Double()
		Return dutyCycle
	End Method
	
	Rem
	bbdoc: Sets the duty cycle represented as a value between 0.0 and 1.0.
	End Rem
	Method SetDutyCycle(value:Double)
		If value < 0 Or value > 1 Then
			Throw New TArgumentOutOfRangeException("Value must be between 0.0 and 1.0.")
		End If
		
		' In Linux, the period needs to be a whole number and can't have decimal point.
		Local dutyCycleInNanoseconds:Int = GetPeriodInNanoseconds(frequency) * value
		dutyCycleStream.SetSize(0)
		dutyCycleStream.WriteString(dutyCycleInNanoseconds)
		dutyCycleStream.Flush()
		dutyCycle = value
	End Method
	
	Rem
	bbdoc: Starts the PWM channel.
	End Rem
	Method Start()
		SaveText("1", channelPath + "/enable", ETextStreamFormat.UTF8, False)
	End Method
	
	Rem
	bbdoc: Stops the PWM channel.
	End Rem
	Method Stop()
		SaveText("0", channelPath + "/enable", ETextStreamFormat.UTF8, False)
	End Method

	Method Dispose() Override
		dutyCycleStream.Close()
		frequencyStream.Close()
		Close()
	End Method
	
End Type
