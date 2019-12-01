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
bbdoc: Character LCDs.
End Rem
Module iot.CharacterLCD

Import iot.core
Import brl.color


Rem
bbdoc: Abstraction layer for accessing the lcd IC.
End Rem
Type TLCDInterface Implements IDisposable Abstract

	Field waitMultiplier:Double = 1.0
	Field backlightOn:Int
	Field eightBitMode:Int

	Method SendData(value:Byte) Abstract
	Method SendCommand(command:Byte) Abstract
	Method SendData(buffer:Byte Ptr, size:Size_T) Abstract
	Method SendCommands(buffer:Byte Ptr, size:Size_T) Abstract

	Method GetWaitMultiplier:Double()
		Return waitMultiplier
	End Method
	
	Method SetWaitMultiplier(value:Double)
		waitMultiplier = value
	End Method
	
	Method IsBacklightOn:Int()
		Return backlightOn
	End Method
	
	Method SetBacklightOn(value:Int)
		backlightOn = value
	End Method
	
	Method GetEightBitMode:Int()
		Return eightBitMode
	End Method

	Method WaitForNotBusy(microseconds:Int)
		' TODO
	End Method
	
	
	
End Type

Rem
bbdoc: Standard direct pin access to the HD44780 controller.
End Rem
Type TLCDGpio Extends TLCDInterface

	Field ReadOnly rsPin:Int
	Field ReadOnly rwPin:Int
	Field ReadOnly enablePin:Int
	Field ReadOnly backlight:Int

	Field backlightBrightness:Int
	Field lastByte:Byte
	Field useLastByte:Int
	
	Field ReadOnly dataPins:Int[]
	Field controller:TGpioController
	Field pinBuffer:SPinValuePair[8]
	
	Method New(registerSelectPin:Int, enablePin:Int, dataPins:Int[], backlightPin:Int = -1, backlightBrightness:Float = 1.0, readWritePin:Int = -1, controller:TGpioController = Null)
		rsPin = registerSelectPin
		rwPin = readWritePin
		Self.enablePin = enablePin
		Self.dataPins = dataPins
		backlight = backlightPin
		Self.backlightBrightness = backlightBrightness
		
		If dataPins.length = 8 Then
			eightBitMode = True
		Else If dataPins.length <> 4 Then
			Throw New TArgumentException("")
		End If
		
		If controller Then
			Self.controller = controller
		Else
			Self.controller = New TGpioController
		End If
		
		Initialize()
	End Method
	
	Method Initialize()
		' prep the pin
		controller.OpenPin(rsPin, EPinMode.Output)
		
		If rwPin <> -1 Then
			controller.OpenPin(rwPin, EPinMode.Output)
		
			' Set to write. Once we enable reading have reading pull high and reset
			' after reading to give maximum performance to write (i.e. assume that
			' the pin is low when writing).
			controller.Write(rwPin, EPinValue.Low)
		End If
		
		If backlight <> -1 Then
			controller.OpenPin(backlight, EPinMode.Output)
			If backlightBrightness > 0 Then
				' Turn on the backlight
				controller.Write(backlight, EPinValue.High)
			End If
		End If
		
		controller.OpenPin(enablePin, EPinMode.Output)
		
		For Local i:Int = 0 Until dataPins.length
			controller.OpenPin(dataPins[i], EPinMode.Output)
		Next
		
		' The HD44780 self-initializes when power is turned on to the following settings:
		' 
		'  - 8 bit, 1 line, 5x7 font
		'  - Display, cursor, and blink off
		'  - Increment with no shift
		'
		' It is possible that the initialization will fail if the power is not provided
		' within specific tolerances. As such, we'll always perform the software based
		' initialization as described on pages 45/46 of the HD44780 data sheet. We give
		' a little extra time to the required waits as described.

		If dataPins.length = 8 Then
			' Init to 8 bit mode (this is the default, but other drivers may set the controller to 4 bit mode, so reset to be safe.)
			Delay(50)
			WriteBits($30, 8)
			Delay(5)
			WriteBits($30, 8)
			Delay(100)
			WriteBits($30, 8)
		Else
			' Init to 4 bit mode, setting rspin to low as we're writing 4 bits directly.
			' (Send writes the whole byte in two 4bit/nibble chunks)
			controller.Write(rsPin, EPinValue.Low)
			Delay(50)
			WriteBits($3, 4)
			Delay(5)
			WriteBits($3, 4)
			Delay(100)
			WriteBits($3, 4)
			WriteBits($2, 4)			
		End If
		
		' The busy flag can NOT be checked until this point.
	End Method
	
	Method IsBacklightOn:Int()
		Return backlight <> -1 And controller.Read(backlight) = EPinValue.High
	End Method
	
	Method SetBackLigntOn(value:Int)
		If backlight <> -1 Then
			If value Then
				controller.Write(backlight, EPinValue.High)
			Else
				controller.Write(backlight, EPinValue.Low)
			End If
		End If
	End Method
	
	Method SendData(value:Byte)
		controller.Write(rsPin, EPinValue.High)
		SendByte(value)
	End Method
	
	Method SendCommand(command:Byte)
		controller.Write(rsPin, EPinValue.Low)
		SendByte(command)
	End Method
	
	Method SendData(buffer:Byte Ptr, size:Size_T)
		controller.Write(rsPin, EPinValue.High)
		For Local i:Int = 0 Until size
			SendByte(buffer[i])
		Next
	End Method
	
	Method SendCommands(buffer:Byte Ptr, size:Size_T)
		controller.Write(rsPin, EPinValue.Low)
		For Local i:Int = 0 Until size
			SendByte(buffer[i])
		Next		
	End Method
	
	Method SendByte(value:Byte)
		If dataPins.Length = 8 Then
			WriteBits(value, 8)
		Else
			WriteBits(Byte(value Shr 4), 4)
			WriteBits(value, 4)
		End If
		
		WaitForNotBusy(37)
	End Method
	
	Method WriteBits(bits:Byte, count:Int)
		Local changedCount:Int
		For Local i:Int = 0 Until count
			Local newBit:Int = (bits Shr i) & 1
			If useLastByte Then
				' Each bit change takes ~23μs, so only change what we have to
				' This is particularly impactful when using all 8 data lines.
				Local oldBit:Int = (lastByte Shr i) & 1
				If oldBit <> newBit Then
					pinBuffer[changedCount] = New SPinValuePair(dataPins[i], newBit)
				End If
				changedCount:+ 1
			Else
				pinBuffer[changedCount] = New SPinValuePair(dataPins[i], newBit)
				changedCount:+ 1
			End If
		Next
		
		If changedCount > 0 Then
			controller.Write(pinBuffer, changedCount)
		End If
		
		useLastByte = True
		lastByte = bits
		
		' Enable pin needs to be high for at least 450ns when running on 3V
		' and 230ns on 5V. (PWeh on page 49/52 and Figure 25 on page 58)
		controller.Write(enablePin, EPinValue.High)
		UDelay(1)
		controller.Write(enablePin, EPinValue.Low)
	End Method
	
	Method Dispose()
		If controller Then
			controller.Dispose()
		End If
	End Method
	
End Type

Rem
bbdoc: 
End Rem
Type TLCDI2c Extends TLCDInterface

	Field ReadOnly device:TI2cDevice
	
	Method New(device:TI2cDevice)
		Self.device = device
	End Method

	Method GetEightBitMode:Int() Override
		Return True
	End Method
	
	Method IsBacklightOn:Int() Override
		Throw New TNotImplementedException
	End Method
	
	Method SetBacklightOn(value:Int) Override
		Throw New TNotImplementedException
	End Method
	
	Method SendCommand(command:Byte) Override
		Local buffer:Byte Ptr = StackAlloc(2)
		buffer[0] = 0
		buffer[1] = command
		device.Write(buffer, 2)
	End Method
	
	Method SendCommands(commands:Byte Ptr, size:Size_T) Override
		If size > 20 Then
			Throw New TArgumentOutOfRangeException("Too many commands in one request.")
		End If
		
		Local buffer:Byte Ptr = StackAlloc(size + 1)
		buffer[0] = 0
		MemCopy(buffer + 1, commands, size)
		device.Write(buffer, size + 1)
	End Method

	Method SendData(value:Byte) Override
		Local buffer:Byte Ptr = StackAlloc(2)
		buffer[0] = EControlByteFlags.RegisterSelect.Ordinal()
		buffer[1] = value
		device.Write(buffer, 2)
	End Method

	Method SendData(data:Byte Ptr, size:Size_T) Override
		' limit sending to 20 byte chunks
		Local buffer:Byte Ptr = StackAlloc(21)
		buffer[0] = EControlByteFlags.RegisterSelect.Ordinal()
		Local offset:Int
		
		While size > 0
			Local toCopy:Size_T = Min(size, 20)
			MemCopy(buffer + 1, data + offset, toCopy)

			device.Write(buffer, toCopy + 1)
			
			offset :+ toCopy
			size :- toCopy
		Wend
		
	End Method

	Method Dispose()
	End Method
	
End Type

Enum EControlByteFlags:Byte Flags
	ControlByteFollows = $80
	RegisterSelect = $40
End Enum

Rem
bbdoc: Supports LCD character displays compatible with the HD44780 LCD controller/driver.
about: Also supports serial interface adapters such as the MCP23008.
End Rem
Type THd44780 Implements IDisposable

	Const CLEAR_DISPLAY_COMMAND:Int = $0001
	Const RETURN_HOME_COMMAND:Int = $0002
	Const SET_CG_RAM_ADDRESS_COMMAND:Int = $0040
	Const SET_DD_RAM_ADDRESS_COMMAND:Int = $0080

	Field displayFunction:EDisplayFunction = EDisplayFunction.Command
	Field displayControl:EDisplayControl = EDisplayControl.Command
	Field displayMode:EDisplayEntryMode = EDisplayEntryMode.Command

	Field rowOffsets:Byte[]
	
	Field lcdInterface:TLCDInterface
	Field size:SSize
	
	Method GetSize:SSize()
		Return size
	End Method
	
	Method New(size:SSize, lcdInterface:TLCDInterface)
		Self.size = size
		Self.lcdInterface = lcdInterface
		
		If lcdInterface.eightBitMode Then
			displayFunction :| EDisplayFunction.EightBit
		End If
		
		Initialize(size.height)
		rowOffsets = InitializeRowOffsets(size.height)
	End Method
	
	Method Initialize(rows:Int)
		' While the chip supports 5x10 pixel characters for one line displays they
		' don't seem to be generally available. Supporting 5x10 would require extra
		' support for CreateCustomCharacter
		
		If GetTwoLineMode(rows) Then
			displayFunction :| EDisplayFunction.TwoLine
		End If

		displayControl :| EDisplayControl.DisplayOn
		displayMode :| EDisplayEntryMode.Increment
	
		Local commands:Byte Ptr = StackAlloc(4)
		commands[0] = displayFunction.Ordinal()
		commands[1] = displayControl.Ordinal()
		commands[2] = displayMode.Ordinal()
		commands[3] = CLEAR_DISPLAY_COMMAND
		
		SendCommands(commands, 4)
	End Method
	
	Method SendData(value:Byte)
		lcdInterface.SendData(value)
	End Method
	
	Method SendCommand(command:Byte)
		lcdInterface.SendCommand(command)
	End Method
	
	Method SendData(buffer:Byte Ptr, size:Size_T)
		lcdInterface.SendData(buffer, size)
	End Method
	
	Method SendCommands(buffer:Byte Ptr, size:Size_T)
		lcdInterface.SendCommands(buffer, size)
	End Method
	
	Method GetTwoLineMode:Int(rows:Int)
		Return rows > 1
	End Method
	
	Method InitializeRowOffsets:Byte[](rows:Int)
		Local rowOffsets:Byte[]
	
		Select rows
			Case 1
				rowOffsets = New Byte[1]
			Case 2
				rowOffsets = [0:Byte, 64:Byte]
			Case 4
				rowOffsets = [0:Byte, 64:Byte, 20:Byte, 84:Byte]
			Default
				Throw New TArgumentOutOfRangeException("rows")
		End Select
	
		Return rowOffsets
	End Method
	
	Method WaitForNotBusy(microseconds:Int)
		lcdInterface.WaitForNotBusy(microseconds)
	End Method
	
	Rem
	bbdoc: Clears the LCD, returning the cursor to home and unshifting if shifted.
	about: Will also set to Increment.
	End Rem
	Method Clear()
		SendCommand(CLEAR_DISPLAY_COMMAND)
		WaitForNotBusy(2000)
	End Method
	
	Rem
	bbdoc: Moves the cursor to the first line and first column, unshifting if shifted.
	End Rem
	Method Home()
		SendCommand(RETURN_HOME_COMMAND)
		WaitForNotBusy(1520)
	End Method
	
	Rem
	bbdoc: Moves the cursor to an explicit column and row position.
	End Rem
	Method SetCursorPosition(Left:Int, top:Int)
		Local rows:Int = rowOffsets.length
		
		If top < 0 Or top >= rows Then
			Throw New TArgumentOutOfRangeException("rows")
		End If
		
		Local newAddress:Int = Left + rowOffsets[top]
		If Left < 0 Or (rows = 1 And newAddress >= 80) Or (rows > 1 And newAddress >= 104) Then
			Throw New TArgumentOutOfRangeException("left")
		End If
		
		SendCommand(Byte(SET_DD_RAM_ADDRESS_COMMAND | newAddress))
	End Method
	
	Rem
	bbdoc: Determines whether the display is on or not.
	returns: #True if the display is on, #False otherwise.
	End Rem
	Method IsDisplayOn:Int()
		Return (displayControl & EDisplayControl.DisplayOn).Ordinal()
	End Method
	
	Rem
	bbdoc: Enable/disable the display.
	End Rem
	Method SetDisplayOn(value:Int)
		If value Then
			displayControl :| EDisplayControl.CursorOn
		Else
			displayControl :& ~EDisplayControl.CursorOn
		End If
		SendCommand(displayControl.Ordinal())
	End Method
	
	Rem
	bbdoc: Determines whether the underlins cursor is visible or not.
	returns: #True if the underline cursor is visible, #False otherwise.
	End Rem
	Method IsUnderlineCursorVisible:Int()
		Return (displayControl & EDisplayControl.CursorOn).Ordinal()
	End Method
	
	Rem
	bbdoc: Enables/disables the underline cursor.
	End Rem
	Method SetUnderlineCursorVisible(value:Int)
		If value Then
			displayControl :| EDisplayControl.CursorOn
		Else
			displayControl :& ~EDisplayControl.CursorOn
		End If
		SendCommand(displayControl.Ordinal())
	End Method
	
	Rem
	bbdoc: Determines whether the blinking cursor is visible or not.
	returns: #True if the blinking cursor is visible, #False otherwise.
	End Rem
	Method IsBlinkingCursorVisible:Int()
		Return (displayControl & EDisplayControl.BlinkOn).Ordinal()
	End Method
	
	Rem
	bbdoc: Enables/disables the blinking cursor.
	End Rem
	Method SetBlinkingCursorVisible(value:Int)
		If value Then
			displayControl :| EDisplayControl.BlinkOn
		Else
			displayControl :& ~EDisplayControl.BlinkOn
		End If
		SendCommand(displayControl.Ordinal())
	End Method
	
	Rem
	bbdoc: Returns whether auto shift is enabled.
	about: When enabled the display will shift rather than the cursor.
	End Rem
	Method GetAutoShift:Int()
		Return (displayMode & EDisplayEntryMode.DisplayShift).Ordinal()
	End Method
	
	Rem
	bbdoc: Enables/disabled auto shift.
	about: When enabled the display will shift rather than the cursor.
	End Rem
	Method SetAutoShift(value:Int)
		If value Then
			displayMode :| EDisplayEntryMode.DisplayShift
		Else
			displayMode :& ~EDisplayEntryMode.DisplayShift
		End If
		SendCommand(displayControl.Ordinal())
	End Method
	
	Rem
	bbdoc: Gets whether the cursor location increments or decrements.
	End Rem
	Method GetIncrement:Int()
		Return (displayMode & EDisplayEntryMode.Increment).Ordinal()
	End Method
	
	Rem
	bbdoc: Sets whether the cursor location increments (#True) or decrements (#False).
	End Rem
	Method SetIncrement(value:Int)
		If value Then
			displayMode :| EDisplayEntryMode.Increment
		Else
			displayMode :& ~EDisplayEntryMode.Increment
		End If
		SendCommand(displayControl.Ordinal())
	End Method
	
	Rem
	bbdoc: Moves the display left by one position.
	End Rem
	Method ShiftDisplayLeft()
		SendCommand((EDisplayShift.Command | EDisplayShift.Display).Ordinal())
	End Method
	
	Rem
	bbdoc: Moves the display right by one position.
	End Rem
	Method ShiftDisplayRight()
		SendCommand((EDisplayShift.Command | EDisplayShift.Display | EDisplayShift.Right).Ordinal())
	End Method

	Rem
	bbdoc: Moves the cursor left by one position.
	End Rem
	Method ShiftCursorLeft()
		SendCommand((EDisplayShift.Command | EDisplayShift.Display).Ordinal())
	End Method
	
	Rem
	bbdoc: Moves the cursor right by one position.
	End Rem
	Method ShiftCursorRight()
		SendCommand((EDisplayShift.Command | EDisplayShift.Display | EDisplayShift.Right).Ordinal())
	End Method
	
	Rem
	bbdoc: Fill one of the 8 CGRAM locations (character codes 0 - 7) with custom characters.
	about: The custom characters also occupy character codes 8 - 15.
	You can find help designing characters at https://www.quinapalus.com/hd44780udg.html
	
	The datasheet description for custom characters is very difficult to follow. Here is a rehash of the technical details that is hopefully easier:
	> Only 6 bits of addresses are available for character ram. That makes for 64 bytes of
	> available character data. 8 bytes of data are used for each character, which is where
	> the 8 total custom characters comes from (64/8).
	> 
	> Each byte corresponds to a character line. Characters are only 5 bits wide so only
	> bits 0-4 are used for display. Whatever is in bits 5-7 is just ignored. Store bits
	> there if it makes you happy, but it won't impact the display. '1' is on, '0' is off.
	> 
	> In the built-in characters the 8th byte is usually empty as this is where the underline
	> cursor will be if enabled. You can put data there if you like, which gives you the full
	> 5x8 character. The underline cursor just turns on the entire bottom row.
	> 
	> 5x10 mode is effectively useless as displays aren't available that utilize it. In 5x10
	> mode *16* bytes of data are used for each character. That leaves room for only *4*
	> custom characters. The first character is addressable from code 0, 1, 8, and 9. The
	> second is 2, 3, 10, 11 and so on...
	> 
	> In this mode *11* bytes of data are actually used for the character data, which
	> effectively gives you a 5x11 character, although typically the last line is blank to
	> leave room for the underline cursor. Why the modes are referred to as 5x8 and 5x10 as
	> opposed to 5x7 and 5x10 or 5x8 and 5x11 is a mystery. In an early pre-release data
	> book 5x7 and 5x10 is used (Advance Copy #AP4 from July 1985). Perhaps it was a
	> marketing change?
	> 
	> As only 11 bytes are used in 5x10 mode, but 16 bytes are reserved, the last 5 bytes
	> are useless. The datasheet helpfully suggests that you can store your own data there.
	> The same would be true for bits 5-7 of lines that matter for both 5x8 and 5x10.
	End Rem
	Method CreateCustomCharacter(location:Byte, characterMap:Byte[])
		If location > 7 Then
			Throw New TArgumentOutOfRangeException("location")
		End If
		
		If characterMap.Length <> 8 Then
			Throw New TArgumentException("characterMap")
		End If
		
		' The character address is set in bits 3-5 of the command byte
		SendCommand(Byte(SET_CG_RAM_ADDRESS_COMMAND | (location Shl 3)))
		SendData(characterMap, characterMap.Length)
	End Method
	
	
	Rem
	bbdoc: Writes text to the display.
	End Rem
	Method Write(value:String)
		Local buf:Byte Ptr = value.ToCString()
		SendData(buf, Size_T(value.Length))
		MemFree(buf)
	End Method
	
	Method Dispose()
		If lcdInterface Then
			lcdInterface.Dispose()
			lcdInterface = Null
		End If
	End Method
	
End Type

Rem
bbdoc: 16x2 HD44780 compatible character LCD display.
End Rem
Type TLcd1602 Extends THd44780

	Rem
	bbdoc: Constructs a new HD44780 based 16x2 LCD controller, using GPIO pins.
	End Rem
	Method New(registerSelectPin:Int, enablePin:Int, dataPins:Int[] , backlightPin:Int = -1, backlightBrightness:Float = 1.0, readWritePin:Int = -1, controller:TGpioController = Null)
		Super.New(New SSize(16, 2), New TLCDGpio(registerSelectPin, enablePin, dataPins, backlightPin, backlightBrightness, readWritePin, controller))
	End Method
	
	Rem
	bbdoc: Constructs a new HD44780 based 16x2 LCD controller with integrated I2c support.
	End Rem
	Method New(device:TI2cDevice)
		Super.New(New SSize(16, 2), New TLCDI2c(device))
	End Method

End Type

Rem
bbdoc: Supports I2c LCDs with I2c RGB backlight, such as the Grove - LCD RGB Backlight (16x2 LCD character display with RGB backlight).
End Rem
Type TLcdRgb1602 Extends TLcd1602

	Field rgbDevice:TI2cDevice
	
	Field currentColor:SColor8
	Field backlightOn:Int = True

	Method New(lcdDevice:TI2cDevice, rgbDevice:TI2cDevice)
		Super.New(lcdDevice)
		Self.rgbDevice = rgbDevice
		
		InitRgb()
	End Method

	Rem
	bbdoc: Enables or disables the backlight.
	End Rem
	Method SetBacklightOn(value:Int)
		If value Then
			ForceSetBacklightColor(currentColor)
		Else
			ForceSetBacklightColor(SCOlor8.Black)
		End If
		backlightOn = value
	End Method
	
	Rem
	bbdoc: Returns #True if the backlight is on, #False otherwise.
	End Rem
	Method IsBacklightOn:Int()
		Return backlightOn
	End Method

	Rem
	bbdoc: Sets the backlight color.
	End Rem
	Method SetBacklightColor(color:SColor8)
		If Not backlightOn Then
			Return 
		End If
		
		ForceSetBacklightColor(color)
		currentColor = color
	End Method

Private
	Method InitRgb()
		' backlight init
		SetRgbRegister(ERgbRegisters.REG_MODE1, 0)
		
		' set LEDs controllable by both PWM and GRPPWM registers
		SetRgbRegister(ERgbRegisters.REG_LEDOUT, $FF)
		
		' set MODE2 values
		SetRgbRegister(ERgbRegisters.REG_MODE2, $20)
		
		SetBacklightColor(SColor8.White)
	End Method
	
	Method SetRgbRegister(addr:ERgbRegisters, value:Byte)
		Local buffer:Byte Ptr = StackAlloc(2)
		buffer[0] = addr.Ordinal()
		buffer[1] = value
		rgbDevice.Write(buffer, 2)
	End Method

	Method ForceSetBacklightColor(color:SColor8)
		SetRgbRegister(ERgbRegisters.REG_RED, color.r)
		SetRgbRegister(ERgbRegisters.REG_GREEN, color.g)
		SetRgbRegister(ERgbRegisters.REG_BLUE, color.b)
	End Method
Public
	
	Method Dispose()
		If rgbDevice Then
			rgbDevice.Dispose()
		End If
	End Method
	
End Type


Rem
bbdoc: 20x4 HD44780 compatible character LCD display.
End Rem
Type TLcd2004 Extends THd44780

	Rem
	bbdoc: Constructs a new HD44780 based 20x4 LCD controller.
	End Rem
	Method New(registerSelectPin:Int, enablePin:Int, dataPins:Int[] , backlightPin:Int = -1, backlightBrightness:Float = 1.0, readWritePin:Int = -1, controller:TGpioController = Null)
		Super.New(New SSize(20, 4), New TLCDGpio(registerSelectPin, enablePin, dataPins, backlightPin, backlightBrightness, readWritePin, controller))
	End Method

End Type


Struct SSize
	Field width:Int
	Field height:Int
	
	Method New(width:Int, height:Int)
		Self.width = width
		Self.height = height
	End Method
	
End Struct


Enum ERgbRegisters:Byte
	REG_MODE1 = $00
	REG_MODE2 = $01
	REG_LEDOUT = $08
	REG_RED = $04
	REG_GREEN = $03
	REG_BLUE = $02
End Enum

Enum EDisplayEntryMode:Byte Flags
	DisplayShift = $1
	Increment = $2
	Command = $4
End Enum

Enum EDisplayControl:Byte Flags
	BlinkOn = $1
	CursorOn = $2
	DisplayOn = $4
	Command = $8
End Enum

Enum EDisplayShift:Byte Flags
	Right = $04
	Display = $08
	Command = $10
End Enum

Enum EDisplayFunction:Byte Flags
	ExtendedInstructionSet = $01
	Font5x10 = $04
	TwoLine = $08
	EightBit = $10
	Command = $20
End Enum
