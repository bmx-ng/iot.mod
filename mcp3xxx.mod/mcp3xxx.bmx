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
bbdoc: MCP3xxx family of Analog to Digital Converters
End Rem
Module iot.mcp3xxx

Import iot.core

Type TMcp3Base Implements IDisposable

	Field spiDevice:TSpiDevice
	
	Method New(spiDevice:TSpiDevice)
		Self.spiDevice = spiDevice
	End Method
	
	Method ReadInternal:Int(adcRequest:Int, adcResolutionBits:Int, delayBits:Int)
		Local result:Int
		Local bufferSize:UInt
		
		' shift the request left to make space in the response for the number of bits in the
		' response plus the conversion delay and plus 1 for a null bit.
		adcRequest :Shl (adcResolutionBits + delayBits + 1)
		
		' calculate the buffer size... If there is a start bit in the range b16 -> b23 then the size of the buffer is 3 bytes otherwise 2 bytes
		If adcRequest & $00FF0000 Then
			bufferSize = 3
		Else
			bufferSize = 2
		End If
		
		Local requestBuffer:Byte Ptr = StackAlloc(bufferSize)
		Local responseBuffer:Byte Ptr = StackAlloc(bufferSize)
		
		' take the resuest and put it in a byte array
		For Local i:Int = 0 Until bufferSize
			requestBuffer[i] = adcRequest Shr (bufferSize - i - 1) * 8
		Next
		
		spiDevice.TransferFullDuplex(requestBuffer, bufferSize, responseBuffer, bufferSize)
		
		' transfer the response from the ADC into the return value
		For Local i:Int = 0 Until bufferSize
			result :Shl 8
			result :+ responseBuffer[i]
		Next
		
		' test the response from the ADC to check that the null bit is actually 0
		If result & (1 Shl adcResolutionBits) Then
			Throw New TInvalidOperationException("Invalid data was read from the sensor")
		End If
		
		' return the ADC response with any possible higer bits masked out
		Return result & Int((1:Long Shl adcResolutionBits) - 1)
	End Method
	
	Method Dispose()
		If spiDevice Then
			spiDevice.Dispose()
			spiDevice = Null
		End If
	End Method

End Type

Rem
bbdoc: MCP family of ADC devices
End Rem
Type TMcp3xxx Extends TMcp3Base Abstract
	
	' the number of single ended input channel on the ADC
	Field channelCount:Byte
	Field adcResolutionBits:Byte
	
	Method New(spiDevice:TSpiDevice, channelCount:Byte, adcResolutionBits:Byte)
		Super.New(spiDevice)
		Self.channelCount = channelCount
		Self.adcResolutionBits = adcResolutionBits
	End Method
	
	Method CheckChannelRange(channel:Int, channelCount:Int)
		If channel < 0 Or channel > channelCount - 1 Then
			Throw New TArgumentOutOfRangeException("ADC channel must be within the range 0-" + (channelCount - 1))
		End If
	End Method
	
	Method CheckChannelPairing(valueChannel:Int, referenceChannel:Int)
		CheckChannelRange(valueChannel, channelCount);
		CheckChannelRange(referenceChannel, channelCount)
		
		' Check that the channels are in the differential pairing.
		' When using differential inputs then then the single ended inputs are grouped into channel pairs
		' such that for an 8 input device then the pairs would be CH0 and CH1, CH2 and CH3, CH4 and CH5,
		' CH6 and CH7 and thus to work out which channel pairing a channel is in then the channel number can be divided by 2.
		If valueChannel / 2 <> referenceChannel / 2 Or valueChannel = referenceChannel Then
			Throw New TArgumentException("ADC differential channels must be different and part of the same channel pairing.")
		End If
	End Method
	
	Rem
	bbdoc: Reads a value from the device using pseudo-differential inputs
	End Rem
	Method ReadPseudoDifferential:Int(valueChannel:Int, referenceChannel:Int)
		' ensure that the channels are part of the same pairing
		CheckChannelPairing(valueChannel, referenceChannel)
		
		' read and return the value. the value passsed to the channel represents the channel pair.
		If valueChannel > referenceChannel Then
			Return ReadInternal(valueChannel / 2, EInputType.InvertedDifferential, adcResolutionBits)
		Else
			Return ReadInternal(valueChannel / 2, EInputType.Differential, adcResolutionBits)
		End If
	End Method
	
	Rem
	bbdoc: Reads a value from the device using differential inputs
	End Rem
	Method ReadDifferential:Int(valueChannel:Int, referenceChannel:Int)
		CheckChannelRange(valueChannel, channelCount)
		CheckChannelRange(referenceChannel, channelCount)
		
		If valueChannel = referenceChannel Then
			Throw New TArgumentException("ADC differential channels must be different.")
		End If

		Return ReadInternal(valueChannel, EInputType.SingleEnded, adcResolutionBits) - ReadInternal(referenceChannel, EInputType.SingleEnded, adcResolutionBits)
	End Method
	
	Method Read:Int(channel:Int)
		Return ReadInternal(channel, EInputType.SingleEnded, adcResolutionBits)
	End Method
	
	Method ReadInternal:Int(channel:Int, inputType:EInputType, adcResolutionBits:Int)
		Local channelValue:Int
		Local requestValue:Int
		
		If inputType = EInputType.SingleEnded Then
			CheckChannelRange(channel, channelCount)
		Else
			CheckChannelRange(channel, channelCount / 2)
		End If
		
		' create a value that represents the channel value. For differental inputs
		' then incorporate the lower bit which indicates if the channel is inverted or not.
		
		Select inputType
			Case EInputType.Differential
				channelValue = channel * 2
				
			Case EInputType.InvertedDifferential
				channelValue = channel * 2
				
			Default
				channelValue = channel
		End Select
		
		' create a value to represent the request to the ADC
		Select channelCount
			Case 4, 8
				If inputType = EInputType.SingleEnded Then
					requestValue = $18 | channelValue
				Else
					requestValue = $10 | channelValue
				End If
			Case 2
				If inputType = EInputType.SingleEnded Then
					requestValue = $D | channelValue
				Else
					requestValue = $9 | (channelValue Shl 1)
				End If
			Case 1
				requestValue = 0
			Default
				Throw New TArgumentOutOfRangeException("Unsupported Channel Count")
		End Select
		
		' read the data from the device...
		' the delayBits is set to account for the extra sampling delay on the 3004, 3008, 3204, 3208, 3302 and 3304
		If ChannelCount > 2 Then
			Return ReadInternal(requestValue, adcResolutionBits, 1)
		Else
			Return ReadInternal(requestValue, adcResolutionBits, 0)
		End If
	End Method
	
End Type

Rem
bbdoc: MCP3001 Analog to Digital Converter (ADC)
End Rem
Type TMcp3001 Extends TMcp3Base

	Method New(spiDevice:TSpiDevice)
		Super.New(spiDevice)
	End Method
	
	Rem
	bbdoc: Reads a 10-bit (0..1023) value from the device
	End Rem
	Method Read:Int()
		' Read the data from the device. As the 10 bits of data start at bit 3 then read 13 bits and shift right by 3.
		Return ReadInternal(0, 10 + 3, 0) Shr 3
	End Method
	
End Type

Rem
bbdoc: MCP3002 Analog to Digital Converter (ADC)
End Rem
Type TMcp3002 Extends TMcp3xxx

	Method New(spiDevice:TSpiDevice)
		Super.New(spiDevice, 2, 10)
	End Method

End Type

Rem
bbdoc: MCP3004 Analog to Digital Converter (ADC)
End Rem
Type TMcp3004 Extends TMcp3xxx

	Method New(spiDevice:TSpiDevice)
		Super.New(spiDevice, 4, 10)
	End Method

End Type

Rem
bbdoc: MCP3008 Analog to Digital Converter (ADC)
End Rem
Type TMcp3008 Extends TMcp3xxx

	Method New(spiDevice:TSpiDevice)
		Super.New(spiDevice, 8, 10)
	End Method

End Type

Rem
bbdoc: MCP3201 Analog to Digital Converter (ADC)
End Rem
Type TMcp3201 Extends TMcp3Base

	Method New(spiDevice:TSpiDevice)
		Super.New(spiDevice)
	End Method
	
	Rem
	bbdoc: Reads a 12-bit (0..4095) value from the device
	End Rem
	Method Read:Int()
		' Read the data from the device. As the 12 bits of data start at bit 1 then read 13 bits and shift right by 1.
		Return ReadInternal(0, 12 + 1, 0) Shr 1
	End Method
	
End Type

Rem
bbdoc: MCP3202 Analog to Digital Converter (ADC)
End Rem
Type TMcp3202 Extends TMcp3xxx

	Method New(spiDevice:TSpiDevice)
		Super.New(spiDevice, 2, 12)
	End Method

End Type

Rem
bbdoc: MCP3204 Analog to Digital Converter (ADC)
End Rem
Type TMcp3204 Extends TMcp3xxx

	Method New(spiDevice:TSpiDevice)
		Super.New(spiDevice, 4, 10)
	End Method

End Type

Rem
bbdoc: MCP3208 Analog to Digital Converter (ADC)
End Rem
Type TMcp3208 Extends TMcp3xxx

	Method New(spiDevice:TSpiDevice)
		Super.New(spiDevice, 8, 12)
	End Method

End Type

Rem
bbdoc: MCP3301 Analog to Digital Converter (ADC)
End Rem
Type TMcp3301 Extends TMcp3Base

	Method New(spiDevice:TSpiDevice)
		Super.New(spiDevice)
	End Method
	
	Rem
	bbdoc: Reads a 13 bit signed value from the device using differential inputs
	End Rem
	Method ReadDifferential:Int()
		Local signedResult:Int = ReadInternal(0, 13, 0)
		
		' convert 13 bit signed to 32 bit signed
		Return TMcp33xx.SignExtend(signedResult, 12)
	End Method
	
End Type

Rem
bbdoc: MCP33XX family of Analog to Digital Converters
End Rem
Type TMcp33xx Extends TMcp3xxx Abstract

	Method ReadPseudoDifferential:Int(valueChannel:Int, referenceChannel:Int)
		Throw New TNotSupportedException("TMcp33xx device does not support ReadPseudoDifferential.")
	End Method
	
	Method ReadDifferential:Int(valueChannel:Int, referenceChannel:Int)
		Local result:Int
		
		CheckChannelRange(valueChannel, channelCount)
		CheckChannelRange(referenceChannel, channelCount)
		
		If valueChannel = referenceChannel Then
			Throw New TArgumentException("ADC differential channels must be different.")
		End If
		
		' check if it is possible to use hardware differential because both input channels are in the same differential channel pairing
		If valueChannel / 2 = referenceChannel / 2 Then
			' read a value from the ADC where the channel is the channel pairing
			If valueChannel > referenceChannel Then
				result = ReadInternal(valueChannel / 2, EInputType.InvertedDifferential, 13)
			Else
				result = ReadInternal(valueChannel / 2, EInputType.Differential, 13)
			End If
			
			' convert 13 bit signed to 32 bit signed
			result = SignExtend(result, 12)
		Else
		
			result = ReadInternal(valueChannel, EInputType.SingleEnded, 12) - ReadInternal(referenceChannel, EInputType.SingleEnded, 12)
		
		End If
		
		Return result
	End Method
	
	Function SignExtend:Int(signedValue:Int, signingBit:Int)
		' if the sign bit is set then extend the signing bit to create a signed integer
		If signedValue Shr signingBit Then
			Return signedValue - (2 Shl signingBit)
		Else
			Return signedValue
		End If
	End Function

End Type

Rem
bbdoc: MCP3302 Analog to Digital Converter (ADC)
End Rem
Type TMcp3302 Extends TMcp33xx

	Method New(spiDevice:TSpiDevice)
		Super.New(spiDevice, 4, 13)
	End Method

End Type

Rem
bbdoc: MCP3304 Analog to Digital Converter (ADC)
End Rem
Type TMcp3304 Extends TMcp33xx

	Method New(spiDevice:TSpiDevice)
		Super.New(spiDevice, 8, 13)
	End Method

End Type

Enum EInputType
	SingleEnded = 0
	Differential = 1
	InvertedDifferential = 2
End Enum
