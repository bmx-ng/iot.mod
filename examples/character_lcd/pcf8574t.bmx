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

Framework brl.standardio
Import iot.characterlcd
Import iot.pcx857x
Import brl.stringbuilder
Import brl.timer

Print "Starting..."

' for PCF8574T i2c addresses can be between $27 and $20 depending on bridged solder jumpers
' for PCF8574AT i2c addresses can be between $3f and $38 depending on bridged solder jumpers
Local connectionSettings:TI2cConnectionSettings = New TI2cConnectionSettings(1, $27)
Local i2cDevice:TI2cDevice = New TI2cDevice(connectionSettings)
Local driver:TGpioDriver = New TPcf8574.Create(i2cDevice)
Local lcd:TLcd1602 = New TLcd1602(0, 2, [ 4, 5, 6, 7 ], 3, , 1, New TGpioController(EPinNumberingScheme.Logical, driver))

Const TWENTY:String = "123456789~$08~123456789~$09~"
Const THIRTY:String = TWENTY+ "123456789~$0a~"
Const FORTY:String = THIRTY + "123456789~$0b~";
Const EIGHTY:String = FORTY + "123456789~$0c~123456789~$0d~123456789~$0e~123456789~$0f~"

Enum EShift
	DisplayLeft
	DisplayRight
	CursorLeft
	CursorRight
End Enum

Print "Initialized"
Input

TestPrompt("SetCursor", lcd, SetCursorTest)
TestPrompt("Underline", lcd, Underline)
lcd.SetUnderlineCursorVisible(False)
TestPrompt("Walker", lcd, WalkerTest)
CreateTensCharacters(lcd)
TestPrompt("CharacterSet", lcd, CharacterSet)

' Shifting
TestPrompt("Autoshift", lcd, AutoShift)
TestPrompt("DisplayLeft", lcd, ShiftDisplayTestLeft)
TestPrompt("DisplayRight", lcd, ShiftDisplayTestRight)
TestPrompt("CursorLeft", lcd, ShiftCursorTestLeft)
TestPrompt("CursorRight", lcd, ShiftCursorTestRight)

' Long string
TestPrompt("Twenty", lcd, WriteTwenty)
TestPrompt("Forty", lcd, WriteForty)
TestPrompt("Eighty", lcd, WriteEighty)

TestPrompt("Twenty-", lcd, WriteFromEndTwenty)
TestPrompt("Forty-", lcd, WriteFromEndForty)
TestPrompt("Eighty-", lcd, WriteFromEndEighty)

TestPrompt("Wrap", lcd, WriteWrap)
TestPrompt("Perf", lcd, PerfTests)


Function TestPrompt(test:String, lcd:THd44780, action(lcd:THd44780))
	Local prompt:String = "Test " + test + ":"
	lcd.Clear()
	lcd.Write(prompt)
	lcd.SetBlinkingCursorVisible(True)
	Input prompt
	lcd.SetBlinkingCursorVisible(False)
	lcd.Clear()
	action(lcd)
	Input "Test Complete:"
	lcd.Clear()
End Function

Function SetCursorTest(lcd:THd44780)
	Local size:SSize = lcd.GetSize()
	Local num:Int
	For Local i:Int = 0 Until size.height
		lcd.SetCursorPosition(0, i)
		lcd.Write(num)
		num :+ 1
		lcd.SetCursorPosition(size.Width - 1, i)
		lcd.Write(num)
		num :+ 1
	Next
End Function

Function Underline(lcd:THd44780)
	lcd.SetUnderlineCursorVisible(True)
End Function

Function AutoShift(lcd:THd44780)
	lcd.SetAutoShift(True)
	Local size:SSize = lcd.GetSize()
	lcd.Write(EIGHTY[0 .. size.Width + size.Width / 2])
	lcd.SetAutoShift(False)
End Function

Function CreateWalkCharacters(lcd:THd44780)
	' Walk 1
	lcd.CreateCustomCharacter(0, [$6:Byte, $6:Byte, $C:Byte, $17:Byte, $4:Byte, $E:Byte, $A:Byte, $11:Byte])
	' Walk 2
	lcd.CreateCustomCharacter(1, [$6:Byte, $6:Byte, $C:Byte, $C:Byte, $6:Byte, $6:Byte, $A:Byte, $A:Byte])
End Function

Function WalkerTest(lcd:THd44780)
	CreateWalkCharacters(lcd)
	
	Local walkOne:String = "~$8~~$8~~$8~~$8~~$8~~$8~~$8~~$8~~$8~~$8~~$8~~$8~~$8~~$8~~$8~~$8~"[..lcd.GetSize().Width]
	Local walkTwo:String = "~$9~~$9~~$9~~$9~~$9~~$9~~$9~~$9~~$9~~$9~~$9~~$9~~$9~~$9~~$9~~$9~"[..lcd.GetSize().Width]

	For Local i:Int = 0 Until 5
		lcd.SetCursorPosition(0, 0)
		lcd.Write(walkOne)
		Delay(500)
		lcd.SetCursorPosition(0, 0)
		lcd.Write(walkTwo)
		Delay(500)
	Next
	
End Function

Function CreateTensCharacters(lcd:THd44780)
	lcd.CreateCustomCharacter(0, [$10:Byte, $10:Byte, $10:Byte, $10:Byte, $17:Byte, $05:Byte, $05:Byte, $07:Byte]) ' 10
	lcd.CreateCustomCharacter(1, [$1C:Byte, $04:Byte, $1C:Byte, $10:Byte, $1F:Byte, $05:Byte, $05:Byte, $07:Byte]) ' 20
	lcd.CreateCustomCharacter(2, [$1C:Byte, $04:Byte, $1C:Byte, $04:Byte, $1F:Byte, $05:Byte, $05:Byte, $07:Byte]) ' 30
	lcd.CreateCustomCharacter(3, [$14:Byte, $14:Byte, $1C:Byte, $04:Byte, $07:Byte, $05:Byte, $05:Byte, $07:Byte]) ' 40
	lcd.CreateCustomCharacter(4, [$1C:Byte, $10:Byte, $1C:Byte, $04:Byte, $1F:Byte, $05:Byte, $05:Byte, $07:Byte]) ' 50
	lcd.CreateCustomCharacter(5, [$1C:Byte, $10:Byte, $1C:Byte, $14:Byte, $1F:Byte, $05:Byte, $05:Byte, $07:Byte]) ' 60
	lcd.CreateCustomCharacter(6, [$1C:Byte, $04:Byte, $08:Byte, $08:Byte, $0F:Byte, $05:Byte, $05:Byte, $07:Byte]) ' 70
	lcd.CreateCustomCharacter(7, [$1C:Byte, $14:Byte, $1C:Byte, $14:Byte, $1F:Byte, $05:Byte, $05:Byte, $07:Byte]) ' 80
End Function

Function CharacterSet(lcd:THd44780)
	Local sb:TStringBuilder = New TStringBuilder(256)
	For Local i:Int = 0 Until 256
		sb.AppendChar(i)
	Next
	
	Local char:Int
	Local line:Int
	Local size:SSize = lcd.GetSize()
	
	While char < 256
		lcd.SetCursorPosition(0, line)
		lcd.Write(sb.Substring(char, Min(size.width, 256 - char)))
		
		line:+ 1
		char :+ size.width
		If line >= size.height Then
			line = 0
			Delay(1000)
		End If
	Wend
	
End Function

Function ShiftTest(lcd:THd44780, shift:EShift)
	Local size:SSize = lcd.GetSize()
	For Local i:Int = 0 Until size.width
		Select shift
			Case EShift.DisplayLeft
				lcd.ShiftDisplayLeft()
			Case EShift.DisplayRight
				lcd.ShiftDisplayRight()
			Case EShift.CursorLeft
				lcd.ShiftCursorLeft()
			Case EShift.CursorRight
				lcd.ShiftCursorRight()
		End Select
		Delay(250)
	Next
End Function

Function ShiftDisplayTest(lcd:THd44780, shift:EShift)
	Local size:SSize = lcd.GetSize()
	lcd.Write(Eighty[0 .. size.height * size.width])
	ShiftTest(lcd, shift)
End Function

Function ShiftDisplayTestLeft(lcd:THd44780)
	ShiftDisplayTest(lcd, EShift.DisplayLeft)
End Function

Function ShiftDisplayTestRight(lcd:THd44780)
	ShiftDisplayTest(lcd, EShift.DisplayRight)
End Function

Function ShiftCursorTest(lcd:THd44780, shift:EShift)
	lcd.SetBlinkingCursorVisible(True)
	ShiftTest(lcd, shift)
	lcd.SetBlinkingCursorVisible(False)
End Function

Function ShiftCursorTestLeft(lcd:THd44780)
	ShiftCursorTest(lcd, EShift.CursorLeft)
End Function

Function ShiftCursorTestRight(lcd:THd44780)
	ShiftCursorTest(lcd, EShift.CursorRight)
End Function

Function WriteTwenty(lcd:THd44780)
	lcd.Write(TWENTY)
End Function

Function WriteForty(lcd:THd44780)
	lcd.Write(FORTY)
End Function

Function WriteEighty(lcd:THd44780)
	lcd.Write(EIGHTY)
End Function

Function WriteFromEnd(lcd:THd44780, value:String)
	Local size:SSize = lcd.GetSize()

	lcd.SetIncrement(False)
	lcd.SetCursorPosition(size.width - 1, size.height - 1)
	lcd.Write(value)
	lcd.SetIncrement(True)
End Function

Function WriteFromEndTwenty(lcd:THd44780)
	WriteFromEnd(lcd, TWENTY)
End Function

Function WriteFromEndForty(lcd:THd44780)
	WriteFromEnd(lcd, FORTY)
End Function

Function WriteFromEndEIGHTY(lcd:THd44780)
	WriteFromEnd(lcd, EIGHTY)
End Function

Function WriteWrap(lcd:THd44780)
	lcd.Write("********************************************************************************>>>>>")
End Function

Function PerfTests(lcd:THd44780)
	Local stars:String = "********************************************************************************"
	Local timer:TChrono = TChrono.Create()
	
	lcd.Clear()
	For Local i:Int = 0 Until 25
		lcd.Write(EIGHTY)
		lcd.Write(stars)
	Next
	lcd.Clear()
	
	timer.Stop()
	Local result:String = "Elapsed ms: " + timer.GetElapsedMilliseconds()
	lcd.Write(result)
	Print result
	
End Function
