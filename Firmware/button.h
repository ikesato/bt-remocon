#ifndef _button_h_
#define _button_h_

void ButtonInit(BYTE buttonBitMask);
void ButtonProcEveryMainLoop(BYTE buttonPort);
void ButtonProcEvery1ms(void);
BYTE ButtonState(void);
BYTE ButtonUpState(void);
BYTE ButtonDownState(void);
BYTE ButtonLongDownState(void);
BYTE ButtonVeryLongDownState(void);

#endif//_button_h_
