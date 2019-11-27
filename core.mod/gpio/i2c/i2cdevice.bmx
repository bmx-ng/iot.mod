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
bbdoc: The communications channel to a device on an I2C bus.
End Rem
Type TI2cDevice Implements IDisposable

	Const DEFAULT_DEVICE_PATH:String = "/dev/i2c"

	Field ReadOnly settings:TI2cConnectionSettings
	Field deviceFileDescriptor:Int = -1
	Field functionalities:EI2cFunctionalityFlags
	Field devicePath:String
	
	Field initializationLock:TMutex = TMutex.Create()
	
	Method New(settings:TI2cConnectionSettings)
		Self.settings = settings
		devicePath = DEFAULT_DEVICE_PATH
	End Method

Private
	Method Initialize()
		If deviceFileDescriptor >= 0 Then
			Return
		End If
		
		Local deviceFileName:String = devicePath + "-" + settings.GetBusId()
		
		Try
			initializationLock.Lock()
		
			deviceFileDescriptor = open_(deviceFileName, O_RDWR)

			If deviceFileDescriptor < 0 Then
				Throw New TIOException("Cannot open I2C device file '" + deviceFileName + "'.")
			End If

			Local tempFlags:EI2cFunctionalityFlags
			Local result:Int = ioctli2_(deviceFileDescriptor, EI2cSettings.I2C_FUNCS.Ordinal(), tempFlags)
			
			If result < 0 Then
				functionalities = EI2cFunctionalityFlags.None
			Else
				functionalities = tempFlags
			End If
		Finally
			initializationLock.Unlock()
		End Try
	End Method
	
	Method Transfer(writeBuffer:Byte Ptr, writeLength:Size_T, readBuffer:Byte Ptr, readLength:Size_T)
		If functionalities & EI2cFunctionalityFlags.I2C_FUNC_I2C Then
			ReadWriteInterfaceTransfer(writeBuffer, writeLength, readBuffer, readLength)
		Else
			FileInterfaceTransfer(writeBuffer, writeLength, readBuffer, readLength)
		End If
	End Method
	
	Method ReadWriteInterfaceTransfer(writeBuffer:Byte Ptr, writeLength:Size_T, readBuffer:Byte Ptr, readLength:Size_T)
		Local messages:i2c_msg[2]
		Local messageCount:UInt
		
		If writeBuffer Then
			messages[messageCount] = New i2c_msg(Short(settings.GetDeviceAddress()), Short(EI2cMessageFlags.I2C_M_WR), Short(writeLength), writeBuffer)
			messageCount :+ 1
		End If
		
		If readBuffer Then
			messages[messageCount] = New i2c_msg(Short(settings.GetDeviceAddress()), Short(EI2cMessageFlags.I2C_M_RD), Short(readLength), readBuffer)
			messageCount :+ 1			
		End If
		
		Local msgset:i2c_rdwr_ioctl_data = New i2c_rdwr_ioctl_data(messages, messageCount)
		
		Local result:Int = ioctl_(deviceFileDescriptor, EI2cSettings.I2C_RDWR.Ordinal(), msgset)
		
		If result < 0 Then
			Throw New TIOException("Error performing I2C data transfer.")
		End If
	End Method
	
	Method FileInterfaceTransfer(writeBuffer:Byte Ptr, writeLength:Size_T, readBuffer:Byte Ptr, readLength:Size_T)
		Local result:Int = ioctli_(deviceFileDescriptor, EI2cSettings.I2C_SLAVE_FORCE.Ordinal(), settings.DeviceAddress)
		
		If result < 0 Then
			Throw New TIOException("Error performing I2C data transfer.")
		End If
		
		If writeBuffer Then
			result = write_(deviceFileDescriptor, writeBuffer, writeLength)
			
			If result < 0 Then
				Throw New TIOException("Error performing I2C data transfer.")
			End If
		End If
		
		If readBuffer Then
			result = read_(deviceFileDescriptor, readBuffer, readLength)
			
			If result < 0 Then
				Throw New TIOException("Error performing I2C data transfer.")
			End If
		End If
	End Method
	
Public
	Rem
	bbdoc: Reads a byte from the I2C device.
	End Rem
	Method ReadByte:Byte()
		Initialize()
		
		Local result:Byte
		Transfer(Null, 0, Varptr result, 1)
		Return result
	End Method
	
	Rem
	bbdoc: Reads data from the I2C device.
	End Rem
	Method Read(buffer:Byte Ptr, length:Size_T)
		Initialize()
		
		Transfer(Null, 0, buffer, length)
	End Method
	
	Rem
	bbdoc: Writes a byte to the I2C device.
	End Rem
	Method WriteByte(value:Byte)
		Initialize()
		
		Transfer(Varptr value, 1, Null, 0)
	End Method
	
	Rem
	bbdoc: Writes data to the I2C device.
	End Rem
	Method Write(buffer:Byte Ptr, length:Size_T)
		Initialize()
		
		Transfer(buffer, length, Null, 0)
	End Method
	
	Rem
	bbdoc: Performs an atomic operation to write data to and then read data from the I2C bus on which the device is connected, and sends a restart condition between the write and read operations.
	End Rem
	Method WriteRead(writeBuffer:Byte Ptr, writeLength:Size_T, readBuffer:Byte Ptr, readLength:Size_T)
		Initialize()
	
		Transfer(writeBuffer, writeLength, readBuffer, readLength)
	End Method
	
	Rem
	bbdoc: Returns the path to I2C resources located on the system.
	End Rem
	Method GetDevicePath:String()
		Return devicePath
	End Method
	
	Rem
	bbdoc: Sets the path to I2C resources located on the system.
	End Rem
	Method SetDevicePath(devicePath:String)
		Self.devicePath = devicePath
	End Method

	Rem
	bbdoc: Returns the connection settings of a device on an I2C bus. 
	End Rem
	Method GetConnectionSettings:TI2cConnectionSettings()
		Return settings
	End Method
	
	Method Dispose() Override
		If deviceFileDescriptor >= 0 Then
			close_(deviceFileDescriptor)
			deviceFileDescriptor = -1
		End If
	End Method
End Type

Rem
bbdoc: The connection settings of a device on an I2C bus.
End Rem
Type TI2cConnectionSettings

	Field ReadOnly busId:Int
	Field ReadOnly deviceAddress:Int
	
	Rem
	bbdoc: Creates a new instance of #TI2cConnectionSettings.
	End Rem
	Method New(busId:Int, deviceAddress:Int)
		Self.busId = busId
		Self.deviceAddress = deviceAddress
	End Method
	
	Rem
	bbdoc: Creates a copy of a #TI2cConnectionSettings.
	End Rem
	Method New(other:TI2cConnectionSettings)
		busId = other.busId
		deviceAddress = other.deviceAddress
	End Method

	Rem
	bbdoc: Returns the bus id that the I2C device is connected to.
	End Rem
	Method GetBusId:Int()
		Return busId
	End Method
	
	Rem
	bbdoc: Returns the bus address of the I2C device.
	End Rem
	Method GetDeviceAddress:Int()
		Return deviceAddress
	End Method
	
End Type
