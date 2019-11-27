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

Import brl.threads

Import "../../common.bmx"

Rem
bbdoc: Represents a SPI communication channel.
End Rem
Type TSpiDevice

	Const DEFAULT_DEVICE_PATH:String = "/dev/spidev"
	Const SPI_IOC_MESSAGE_1:UInt = $40206b00

Private

	Field deviceFileDescriptor:Int = -1
	Field ReadOnly settings:TSpiConnectionSettings
	Field devicePath:String

	Field initializationLock:TMutex = TMutex.Create()
Public

	Method New(settings:TSpiConnectionSettings)
		Self.settings = settings
		devicePath = DEFAULT_DEVICE_PATH
	End Method

Private
	Method Initialize()
		If deviceFileDescriptor >= 0 Then
			Return
		End If
		
		Try
			initializationLock.Lock()
			
			If deviceFileDescriptor >= 0 Then
				Return
			End If
		
			Local deviceFileName:String = devicePath + settings.GetBusId() + "." + settings.GetChipSelectLine()
		
			deviceFileDescriptor = open_(deviceFileName, O_RDWR)
		
			If deviceFileDescriptor < 0 Then
				Throw New TIOException("Cannot open SPI device file '" + deviceFileName + " '.")
			End If
			
			Local Mode:ESpiMode = SpiSettingsToSpiMode()

			Local result:Int = ioctlsp_(deviceFileDescriptor, ESpiSettings.SPI_IOC_WR_MODE.Ordinal(), Mode)
			
			If result = -1 Then
				Throw New TIOException("Cannot set SPI mode to " + settings.Mode.ToString())
			End If
			
			Local dataLengthInBits:Byte = settings.GetDataBitLength()
			
			result = ioctl_(deviceFileDescriptor, ESpiSettings.SPI_IOC_WR_BITS_PER_WORD.Ordinal(), Varptr dataLengthInBits)
			
			If result = -1 Then
				Throw New TIOException("Cannot set SPI data bit length to " + settings.GetDataBitLength())
			End If

			Local clockFrequency:Int = settings.GetClockFrequency()

			result = ioctli_(deviceFileDescriptor, ESpiSettings.SPI_IOC_WR_MAX_SPEED_HZ.Ordinal(), clockFrequency)

			If result = -1 Then
				Throw New TIOException("Cannot set SPI clock frequency to " + settings.GetClockFrequency())
			End If
			
		Finally
			initializationLock.Unlock()
		End Try
	End Method

	Method SpiSettingsToSpiMode:ESpiMode()
		
		Local Mode:ESpiMode = settings.GetMode()
		
		If settings.GetChipSelectLineActiveState() = EPinValue.High Then
			Mode :| ESpiMode.SPI_CS_HIGH
		End If

		If settings.GetDataFlow() = EDataFlow.LsbFirst Then
			Mode :| ESpiMode.SPI_LSB_FIRST
		End If
		
		Return Mode

	End Method

	Method Transfer(writeBuffer:Byte Ptr, readBuffer:Byte Ptr, length:UInt)
	
		Local tr:spi_ioc_transfer = New spi_ioc_transfer(writeBuffer, readBuffer, length, UInt(settings.GetClockFrequency()), Byte(settings.GetDataBitLength()), 0)
		
		Local result:Int = ioctl_(deviceFileDescriptor, SPI_IOC_MESSAGE_1, tr)
		
		If result < 1 Then
			Throw New TIOException("Error performing SPI data transfer.")
		End If
	
	End Method
	
Public
	Method GetConnectionSettings:TSpiConnectionSettings()
	End Method
	
	Method ReadByte:Byte()
		Initialize()
		
		Local result:Byte
		Transfer(Null, Varptr result, 1)
		
		Return result
	End Method
	
	Method Read(buffer:Byte Ptr, length:UInt)
		Initialize()
		
		Transfer(Null, buffer, length)
	End Method
	
	Method WriteByte(value:Byte)
		Initialize()
		
		Transfer(Varptr value, Null, 1)
	End Method
	
	Method Write(buffer:Byte Ptr, length:UInt)
		Initialize()
		
		Transfer(buffer, Null, length)
	End Method
	
	Method TransferFullDuplex(writeBuffer:Byte Ptr, writeLength:UInt, readBuffer:Byte Ptr, readLength:UInt)
		Initialize()
		
		If writeLength <> readLength Then
			Throw New TArgumentException("Parameters 'writeLength' and 'readLength' must have the same length.")
		End If
		
		Transfer(writeBuffer, readBuffer, writeLength)
	End Method

	Method Dispose()
		If deviceFileDescriptor >= 0 Then
			close_(deviceFileDescriptor)
			deviceFileDescriptor = -1
		End If
	End Method
	
End Type



Type TSpiConnectionSettings

	Field busId:Int
	Field chipSelectLine:Int
	Field Mode:ESpiMode = ESpiMode.SPI_Mode_0
	Field dataBitLength:Int = 8 ' 1 byte
	Field clockFrequency:Int = 500000 ' 500 KHz
	Field dataFlow:EDataFlow = EDataFlow.MsbFirst
	Field chipSelectLineActiveState:EPinValue = EPinValue.Low
	
	Method New(busId:Int, chipSelectLine:Int)
		Self.busId = busId
		Self.chipSelectLine = chipSelectLine
	End Method
	
	Method New(other:TSpiConnectionSettings)
		busId = other.busId
		chipSelectLine = other.chipSelectLine
		Mode = other.Mode
		dataBitLength = other.dataBitLength
		clockFrequency = other.clockFrequency
		dataFlow = other.dataFlow
		chipSelectLineActiveState = other.chipSelectLineActiveState
	End Method
	
	Method GetBusId:Int()
		Return busId
	End Method
	
	Method SetBusId(value:Int)
		busId = value
	End Method
	
	Method GetChipSelectLine:Int()
		Return chipSelectLine
	End Method
	
	Method SetChipSelectLine(value:Int)
		chipSelectLine = value
	End Method
	
	Method GetMode:ESpiMode()
		Return Mode
	End Method
	
	Method SetMode(value:EspiMode)
		Mode = value
	End Method
	
	Method GetDataFlow:EDataFlow()
		Return dataFlow
	End Method
	
	Method SetDataFlow(value:EDataFlow)
		dataFlow = value
	End Method
	
	Method GetChipSelectLineActiveState:EPinValue()
		Return chipSelectLineActiveState:EPinValue
	End Method
	
	Method SetChipSelectLineActiveState(value:EPinValue)
		chipSelectLineActiveState:EPinValue = value
	End Method
	
	Method GetDataBitLength:Int()
		Return dataBitLength
	End Method
	
	Method SetDataBitLength(value:Int)
		dataBitLength = value
	End Method
	
	Method GetClockFrequency:Int()
		Return clockFrequency
	End Method
	
	Method SetClockFrequency(value:Int)
		clockFrequency = value
	End Method
	
End Type
