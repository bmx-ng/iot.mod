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

Import pub.stdc
Import brl.event
Import "glue.c"

Rem
bbdoc: Pin modes supported by the GPIO controllers and drivers.
End Rem
Enum EPinMode
	Input
	Output
	InputPullDown
	InputPullUp
End Enum

Rem
bbdoc: Different numbering schemes supported by GPIO controllers and drivers.
End Rem
Enum EPinNumberingScheme
	Logical
	Board
End Enum

Rem
bbdoc: Event types that can be triggered by the GPIO.
End Rem
Enum EPinEventTypes Flags
	None = 0
	Rising = 1
	Falling = 2
End Enum

Rem
bbdoc: Represents a value for a pin.
End Rem
Enum EpinValue
	Low = 0
	High = 1
End Enum

Rem
bbdoc: A motion started event.
End Rem
Global MOTION_START_EVENT:Int = AllocUserEventId("Motion started")
Rem
bbdoc: A motion stopped event.
End Rem
Global MOTION_STOP_EVENT:Int = AllocUserEventId("Motion stopped")


Function defaultcomparator_compare:Int(a:EpinValue, b:EpinValue )
	Return a.Ordinal() - b.Ordinal()
End Function

Type TIntArrayList

	Field data:Int[0]
	Field size:Int
	
	Method New(initialCapacity:Int)
		data = New Int[initialCapacity]
	End Method
	
	Method Add(value:Int)
		CheckAndResize()
		data[size] = value
		size :+ 1
	End Method

	Method CheckAndResize()
		If size = data.length Then
			Local newSize:Int = size + 1 + size * (2/3.0)
			data = data[..newSize]
		End If
	End Method
	
	Method Operator[]:Int(index:Int)
		Return data[index]
	End Method
	
	Method Remove(value:Int)
		For Local i:Int = 0 Until size
			If data[i] = value Then
				data = data[..i] + data[i+1..]
				Exit
			End If
		Next
	End Method
	
End Type

Rem
bbdoc: General Iot exception.
End Rem
Type TIotException Extends TBlitzException

	Field message:String

	Method ToString:String() Override
		Return message
	End Method
	
End Type

Type TPlatformNotSupportedException Extends TIotException

	Method New()
		message = "Platform not supported"
	End Method

	Method New(message:String)
		Self.message = message
	End Method

End Type

Type TArgumentException Extends TIotException

	Method New(message:String)
		Self.message = message
	End Method

End Type

Type TUnauthorizedAccessException Extends TIotException

	Method New(message:String)
		Self.message = message
	End Method

End Type

Type TInvalidOperationException Extends TIotException

	Method New(message:String)
		Self.message = message
	End Method

End Type

Type TArgumentOutOfRangeException Extends TIotException

	Method New(message:String)
		Self.message = message
	End Method

End Type

Type TArgumentNullException Extends TIotException

	Method New(message:String)
		Self.message = message
	End Method

End Type

Type TIOException Extends TIotException

	Method New(message:String)
		Self.message = message
	End Method

End Type

Type TNotImplementedException Extends TIotException
End Type

Type TNotSupportedException Extends TIotException

	Method New(message:String)
		Self.message = message
	End Method

End Type

Enum EI2cFunctionalityFlags Flags
	NONE = 0
	I2C_FUNC_I2C = $00000001
	I2C_FUNC_SMBUS_BLOCK_DATA = $03000000
End Enum

Enum EI2cSettings:UInt
	I2C_FUNCS = $0705
	I2C_SLAVE_FORCE = $0706
	I2C_RDWR = $0707
	I2C_SMBUS = $0720
End Enum

Enum EI2cMessageFlags:Short Flags
	I2C_M_WR = $0000
	I2C_M_RD = $0001
	I2C_M_TEN = $0010
	I2C_M_RECV_LEN = $0400
	I2C_M_NO_RD_ACK = $0800
	I2C_M_IGNORE_NAK = $1000
	I2C_M_REV_DIR_ADDR = $2000
	I2C_M_NOSTART = $4000
End Enum

Enum ESpiSettings:UInt
	SPI_IOC_WR_MODE = $40016b01
	SPI_IOC_RD_MODE = $80016b01
	SPI_IOC_WR_BITS_PER_WORD = $40016b03
	SPI_IOC_RD_BITS_PER_WORD = $80016b03
	SPI_IOC_WR_MAX_SPEED_HZ = $40046b04
	SPI_IOC_RD_MAX_SPEED_HZ = $80046b04
End Enum

Enum ESpiMode Flags
	None = $00
	SPI_CPHA = $01
	SPI_CPOL = $02
	SPI_CS_HIGH = $04
	SPI_LSB_FIRST = $08
	SPI_3WIRE = $10
	SPI_LOOP = $20
	SPI_NO_CS = $40
	SPI_READY = $80
	SPI_MODE_0 = None
	SPI_MODE_1 = SPI_CPHA
	SPI_MODE_2 = SPI_CPOL
	SPI_MODE_3 = SPI_CPOL | SPI_CPHA
End Enum

Struct i2c_msg
	Field addr:Short
	Field flags:Short
	Field length:Short
	Field buf:Byte Ptr
	
	Method New(addr:Short, flags:Short, length:Short, buf:Byte Ptr)
		Self.addr = addr
		Self.flags = flags
		Self.length = length
		Self.buf = buf
	End Method
	
End Struct

Struct i2c_rdwr_ioctl_data
	Field msgs:Byte Ptr
	Field nmsgs:UInt
	
	Method New(msgs:Byte Ptr, nmsgs:UInt)
		Self.msgs = msgs
		Self.nmsgs = nmsgs
	End Method
End Struct

Const O_RDWR:Int = $0002

Struct spi_ioc_transfer
	Field tx_buf:Byte Ptr
	Field rx_buf:Byte Ptr
	Field length:UInt
	Field speed_hz:UInt
	Field delay_usecs:Short
	Field bits_per_word:Byte
	Field cs_change:Byte
	Field pad:UInt
	
	Method New(tx_buf:Byte Ptr, rx_buf:Byte Ptr, length:UInt, speed_hz:UInt, bits_per_word:Byte, delay_usecs:Short)
		Self.tx_buf = tx_buf
		Self.rx_buf = rx_buf
		Self.length = length
		Self.speed_hz = speed_hz
		Self.bits_per_word = bits_per_word
		Self.delay_usecs = delay_usecs
	End Method
End Struct

Enum EDataFlow
	MsbFirst
	LsbFirst
End Enum

Extern
	Function open_:Int(path:String, flags:Int)
	Function ioctl_:Int(fd:Int, request:UInt, data:Byte Ptr)'="void ioctl_(int, unsigned int, int *)!"
	Function ioctli_:Int(fd:Int, request:UInt, data:Int)="ioctli_"
	Function ioctl_:Int(fd:Int, request:UInt, data:i2c_rdwr_ioctl_data Var)="void ioctl_(int, unsigned int, int *)!"
	Function ioctl_:Int(fd:Int, request:UInt, data:spi_ioc_transfer Var)="void ioctl_(int, unsigned int, int *)!"
	Function ioctli2_:Int(fd:Int, request:UInt, data:EI2cFunctionalityFlags Var)="void ioctl_(int, unsigned int, int *)!"
	Function ioctlsp_:Int(fd:Int, request:UInt, data:ESpiMode Var)="void ioctl_(int, unsigned int, int *)!"
	
	Function write_:Long(fd:Int, buf:Byte Ptr, count:Size_T)
	Function read_:Long(fd:Int, buf:Byte Ptr, count:Size_T)
	Function close_(fd:Int)="close"
End Extern

Struct SPinValuePair
	Field pinNumber:Int
	Field pinValue:EPinValue
	
	Method New(pinNumber:Int, pinValue:EPinValue)
		Self.pinNumber = pinNumber
		Self.pinValue = pinValue
	End Method
	
	Method New(pinNumber:Int, pinValue:Int)
		Self.pinNumber = pinNumber
		If pinValue = 0 Then
			Self.pinValue = EPinValue.Low
		Else
			Self.pinValue = EpinValue.High
		End If
	End Method
	
End Struct


Function DelayMicroseconds(microseconds:Int, allowThreadYield:Int)
	
End Function


