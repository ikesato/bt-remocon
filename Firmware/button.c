#include <p18cxxx.h>
#include "GenericTypeDefs.h"
#include "HardwareProfile.h"
#include "button.h"

#define LONG_PRESSED_INTERVAL_MS		2000
#define VERY_LONG_PRESSED_INTERVAL_MS	5000

BYTE buttonState;				// 整形したボタン状態 0:not pressed 1:pressed
BYTE buttonMask;				// ボタンで使用するビット
BYTE buttonUpState;				// ボタンが押して離されたどうか 1:upped 0:other (1フレームだけ有効)
BYTE buttonDownState;			// ボタンが押したかどうか 1:downed 0:other (1フレームだけ有効)
BYTE buttonLongDownState;		// 長押し(2秒)したかどうかの状態 1:downed 0:other (1フレームだけ有効)
BYTE buttonLongDownPushed;		// 長押し(2秒)を立てたかどうかワーク
BYTE buttonVeryLongDownState;	// 長押し(5秒)したかどうかの状態 1:downed 0:other (1フレームだけ有効)
BYTE buttonVeryLongDownPushed;	// 長押し(5秒)を立てたかどうかワーク
WORD buttonTimer;				// タイマー

void ButtonInit(BYTE buttonBitMask)
{
	buttonMask = buttonBitMask;

	buttonState = 0;
	buttonUpState = 0;
	buttonDownState = 0;
	buttonLongDownState = 0;
	buttonLongDownPushed = 0;
	buttonVeryLongDownState = 0;
	buttonVeryLongDownPushed = 0;
	buttonTimer = 0;
	//buttonSameStateCount = 0;
}

void ButtonProcEveryMainLoop(BYTE buttonPort)
{
	BYTE lastState = buttonState;
	BYTE xorState;
	BYTE changed;

	buttonState = (~buttonPort)&buttonMask;
	xorState = buttonState ^ lastState;
	buttonDownState = xorState & buttonState;
	buttonUpState = xorState & (~buttonState);

	if (buttonState == 0) {
		buttonTimer = 0;
		buttonLongDownState = 0;
		buttonLongDownPushed = 0;
		buttonVeryLongDownState = 0;
		buttonVeryLongDownPushed = 0;
	} else if (buttonTimer>=VERY_LONG_PRESSED_INTERVAL_MS) {
		if (buttonVeryLongDownPushed==0) {
			buttonVeryLongDownPushed = 1;
			buttonVeryLongDownState = buttonState;
		} else {
			buttonVeryLongDownState = 0;
		}
	} else if (buttonTimer>=LONG_PRESSED_INTERVAL_MS) {
		if (buttonLongDownPushed==0) {
			buttonLongDownPushed = 1;
			buttonLongDownState = buttonState;
		} else {
			buttonLongDownState = 0;
		}
	} else {
		buttonLongDownState = 0;
		buttonLongDownPushed = 0;
		buttonVeryLongDownState = 0;
		buttonVeryLongDownPushed = 0;
	}
}

void ButtonProcEvery1ms(void)
{
	if (buttonTimer < 0xFFFF)
		buttonTimer++;
}


BYTE ButtonState(void)
{
	return buttonState;
}

BYTE ButtonUpState(void)
{
	return buttonUpState;
}

BYTE ButtonDownState(void)
{
	return buttonDownState;
}

BYTE ButtonLongDownState(void)
{
	return buttonLongDownState;
}

BYTE ButtonVeryLongDownState(void)
{
	return buttonVeryLongDownState;
}



//	{
//		extern WORD buttonTimer;
//		BYTE p = PORTB;
//		if (!WaitToReadySerial()) return;
//		sprintf(USB_In_Buffer, (far rom char*)"s:%02x up:%02x d:%02x ld:%02x vd:%02x timer:%u\r\n",
//				ButtonState(), ButtonUpState(), ButtonDownState(),
//				ButtonLongDownState(), ButtonVeryLongDownState(), buttonTimer);
//		putsUSBUSART(USB_In_Buffer);
//		if (!WaitToReadySerial()) return;
//	}
