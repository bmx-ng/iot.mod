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

Import "link.bmx"
Import "../gpiodriver.bmx"

Private
Global _libgpiod:Byte Ptr=LoadGpiod()

Function LoadGpiod:Byte Ptr()
	Return dlopen_("libgpiod.so", 2)
End Function

Public

Rem
bbdoc: Returns #True if libgpiod is available.
End Rem
Function LibGpiodAvailable:Int()
	Return _libgpiod <> Null
End Function

Const GPIOD_LINE_BULK_MAX_LINES:Int = 64

Global gpiod_chip_open:Byte Ptr(path:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_chip_open")
Global gpiod_chip_open_by_name:Byte Ptr(name:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_chip_open_by_name")
Global gpiod_chip_open_by_number:Byte Ptr(num:UInt)=LinkSymbol(_libgpiod, "gpiod_chip_open_by_number")
Global gpiod_chip_open_by_label:Byte Ptr(label:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_chip_open_by_label")
Global gpiod_chip_open_lookup:Byte Ptr(desc:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_chip_open_lookup")
Global gpiod_chip_close(chip:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_chip_close")
Global gpiod_chip_name:Byte Ptr(chip:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_chip_name")
Global gpiod_chip_label:Byte Ptr(chip:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_chip_label")
Global gpiod_chip_num_lines:UInt(chip:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_chip_num_lines")

Global gpiod_chip_get_line:Byte Ptr(chip:Byte Ptr, offset:UInt)=LinkSymbol(_libgpiod, "gpiod_chip_get_line")
Global gpiod_chip_get_lines:Int(chip:Byte Ptr, offsets:UInt Ptr, numOffsets:UInt, bulk:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_chip_get_lines")
Global gpiod_chip_get_all_lines:Int(chip:Byte Ptr, bulk:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_chip_get_all_lines")
Global gpiod_chip_find_line:Byte Ptr(chip:Byte Ptr, name$z)=LinkSymbol(_libgpiod, "gpiod_chip_find_line")

Global gpiod_line_offset:UInt(line:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_line_offset")
Global gpiod_line_name:Byte Ptr(line:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_line_name")
Global gpiod_line_consumer:Byte Ptr(line:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_line_consumer")
Global gpiod_line_direction:Int(line:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_line_direction")
Global gpiod_line_active_state:Int(line:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_line_active_state")
Global gpiod_line_is_used:Int(line:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_line_is_used")
Global gpiod_line_is_open_drain:Int(line:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_line_is_open_drain")
Global gpiod_line_is_open_source:Int(line:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_line_is_open_source")
Global gpiod_line_update:Int(line:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_line_update")
Global gpiod_line_needs_update:Int(line:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_line_needs_update")
Global gpiod_line_release(line:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_line_release")
Global gpiod_line_get_value:Int(line:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_line_get_value")
Global gpiod_line_is_requested:Int(line:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_line_is_requested")
Global gpiod_line_set_value:Int(line:Byte Ptr, value:Int)=LinkSymbol(_libgpiod, "gpiod_line_set_value")
Global gpiod_line_request_input:Int(line:Byte Ptr, consumer$z)=LinkSymbol(_libgpiod, "gpiod_line_request_input")
Global gpiod_line_request_output:Int(line:Byte Ptr, consumer$z, defaultValue:Int)=LinkSymbol(_libgpiod, "gpiod_line_request_output")
Global gpiod_line_request_both_edges_events:Int(line:Byte Ptr, consumer$z)=LinkSymbol(_libgpiod, "gpiod_line_request_both_edges_events")
Global gpiod_line_event_wait:Int(line:Byte Ptr, timespec:STimeSpec Var)=LinkSymbol(_libgpiod, "gpiod_line_event_wait")
Global gpiod_line_event_read:Int(line:Byte Ptr, lineEvent:SGpioLineEvent Var)=LinkSymbol(_libgpiod, "gpiod_line_event_read")
Global gpiod_line_is_free:Int(line:Byte Ptr)=LinkSymbol(_libgpiod, "gpiod_line_is_free")

Enum ELineRequestType
	GPIOD_LINE_REQUEST_DIRECTION_AS_IS = 1
	GPIOD_LINE_REQUEST_DIRECTION_INPUT
	GPIOD_LINE_REQUEST_DIRECTION_OUTPUT
	GPIOD_LINE_REQUEST_EVENT_FALLING_EDGE
	GPIOD_LINE_REQUEST_EVENT_RISING_EDGE
	GPIOD_LINE_REQUEST_EVENT_BOTH_EDGES
End Enum

Enum ELineRequestFlags Flags
	GPIOD_LINE_REQUEST_FLAG_OPEN_DRAIN	= 1 Shl 0
	GPIOD_LINE_REQUEST_FLAG_OPEN_SOURCE	= 1 Shl 1
	GPIOD_LINE_REQUEST_FLAG_ACTIVE_LOW	= 1 Shl 2
End Enum

Public

Struct SGpioLineEvent
	Field timespec:STimeSpec
	Field eventType:Int
	
	Method AsPinEventType:EPinEventTypes()
		If eventType = 1 Then
			Return EPinEventTypes.Rising
		Else
			Return EPinEventTypes.Falling
		End If
	End Method
	
End Struct
