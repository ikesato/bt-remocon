/** INCLUDES *******************************************************/
#include <timers.h>
#include <delays.h>
#include <usart.h>

#include "HardwareProfile.h"

/** CONFIGURATION **************************************************/
// Configuration bits for PICDEM FS USB Demo Board (based on PIC18F4550)
#pragma config PLLDIV   = 5         // (20 MHz crystal on PICDEM FS USB board)
#if (USB_SPEED_OPTION == USB_FULL_SPEED)
    #pragma config CPUDIV   = OSC1_PLL2  
#else
    #pragma config CPUDIV   = OSC3_PLL4   
#endif
#pragma config USBDIV   = 2         // Clock source from 96MHz PLL/2
#pragma config FOSC     = HSPLL_HS
#pragma config FCMEN    = OFF
#pragma config IESO     = OFF
#pragma config PWRT     = OFF
#pragma config BOR      = ON
#pragma config BORV     = 3
#pragma config VREGEN   = ON      //USB Voltage Regulator
#pragma config WDT      = OFF
#pragma config WDTPS    = 32768
#pragma config MCLRE    = ON
#pragma config LPT1OSC  = OFF
#pragma config PBADEN   = OFF
//#pragma config CCP2MX   = ON
#pragma config STVREN   = ON
#pragma config LVP      = OFF
//#pragma config ICPRT    = OFF       // Dedicated In-Circuit Debug/Programming
#pragma config XINST    = OFF       // Extended Instruction Set
#pragma config CP0      = OFF
#pragma config CP1      = OFF
//#pragma config CP2      = OFF
//#pragma config CP3      = OFF
#pragma config CPB      = OFF
//#pragma config CPD      = OFF
#pragma config WRT0     = OFF
#pragma config WRT1     = OFF
//#pragma config WRT2     = OFF
//#pragma config WRT3     = OFF
#pragma config WRTB     = OFF       // Boot Block Write Protection
#pragma config WRTC     = OFF
//#pragma config WRTD     = OFF
#pragma config EBTR0    = OFF
#pragma config EBTR1    = OFF
//#pragma config EBTR2    = OFF
//#pragma config EBTR3    = OFF
#pragma config EBTRB    = OFF

/** I N C L U D E S **********************************************************/

#include "GenericTypeDefs.h"
#include "Compiler.h"
#include "buffer.h"
#include "button.h"

#include "HardwareProfile.h"

#define LED1_TRIS   TRISAbits.TRISA4
#define LED2_TRIS   TRISAbits.TRISA5
#define IR_TRIS     TRISBbits.TRISB3
#define SW_TRIS     TRISBbits.TRISB4
#define IRLED_TRIS  TRISAbits.TRISA0

#define LED1_PORT   PORTAbits.RA4
#define LED2_PORT   PORTAbits.RA5
#define IR_PORT     PORTBbits.RB3
#define SW_PORT     PORTBbits.RB4
#define IRLED_PORT  PORTAbits.RA0

#define SW_BIT      (1<<4)

#define MAX_WAIT_CYCLE 60000

/** V A R I A B L E S ********************************************************/
// 順番重要:先にアドレス順で後の udata から定義するとバンク内にきちんと収まる
//          これを udata の後に書くと収まらなくなる
// http://tylercsf.blog123.fc2.com/blog-entry-189.html

#pragma udata USER_RAM3=0x300
BYTE signalBuffer[0x400];

#pragma udata USER_RAM2=0x120
BYTE uartInBuffer[0x1d0];

#if defined(__18CXX)
    #pragma udata
#endif

char uartOutBuffer[128];
BYTE enableReadIR;
BYTE buff_pos=0;


/** P R I V A T E  P R O T O T Y P E S ***************************************/
static void InitializeSystem(void);
void ProcessIO(void);
void YourHighPriorityISRCode();
void YourLowPriorityISRCode();
void ButtonProc(void);
void ReadIR(void);
void SendIR(void);
void SendIRImpl(void);
void DelayIRFreqHi(void);
void DelayIRFreqLo(void);
int WaitToReadySerial(void);
void SerialProc(void);
void PutsString(const rom char *str);
void PutsStringCPtr(char *str);
void PrintIRBuffer(const rom char *title);
WORD ReadSerial(BYTE *buffer, WORD length);
void WriteSerial(char *str);

/** VECTOR REMAPPING ***********************************************/
#if defined(__18CXX)
    //On PIC18 devices, addresses 0x00, 0x08, and 0x18 are used for
    //the reset, high priority interrupt, and low priority interrupt
    //vectors.  However, the current Microchip USB bootloader 
    //examples are intended to occupy addresses 0x00-0x7FF or
    //0x00-0xFFF depending on which bootloader is used.  Therefore,
    //the bootloader code remaps these vectors to new locations
    //as indicated below.  This remapping is only necessary if you
    //wish to program the hex file generated from this project with
    //the USB bootloader.  If no bootloader is used, edit the
    //usb_config.h file and comment out the following defines:
    //#define PROGRAMMABLE_WITH_USB_HID_BOOTLOADER
    //#define PROGRAMMABLE_WITH_USB_LEGACY_CUSTOM_CLASS_BOOTLOADER
    
    #if defined(PROGRAMMABLE_WITH_USB_HID_BOOTLOADER)
        #define REMAPPED_RESET_VECTOR_ADDRESS           0x1000
        #define REMAPPED_HIGH_INTERRUPT_VECTOR_ADDRESS  0x1008
        #define REMAPPED_LOW_INTERRUPT_VECTOR_ADDRESS   0x1018
    #elif defined(PROGRAMMABLE_WITH_USB_MCHPUSB_BOOTLOADER) 
        #define REMAPPED_RESET_VECTOR_ADDRESS           0x800
        #define REMAPPED_HIGH_INTERRUPT_VECTOR_ADDRESS  0x808
        #define REMAPPED_LOW_INTERRUPT_VECTOR_ADDRESS   0x818
    #else   
        #define REMAPPED_RESET_VECTOR_ADDRESS           0x00
        #define REMAPPED_HIGH_INTERRUPT_VECTOR_ADDRESS  0x08
        #define REMAPPED_LOW_INTERRUPT_VECTOR_ADDRESS   0x18
    #endif
    
    #if defined(PROGRAMMABLE_WITH_USB_HID_BOOTLOADER)||defined(PROGRAMMABLE_WITH_USB_MCHPUSB_BOOTLOADER)
    extern void _startup (void);        // See c018i.c in your C18 compiler dir
    #pragma code REMAPPED_RESET_VECTOR = REMAPPED_RESET_VECTOR_ADDRESS
    void _reset (void)
    {
        _asm goto _startup _endasm
    }
    #endif
    #pragma code REMAPPED_HIGH_INTERRUPT_VECTOR = REMAPPED_HIGH_INTERRUPT_VECTOR_ADDRESS
    void Remapped_High_ISR (void)
    {
         _asm goto YourHighPriorityISRCode _endasm
    }
    #pragma code REMAPPED_LOW_INTERRUPT_VECTOR = REMAPPED_LOW_INTERRUPT_VECTOR_ADDRESS
    void Remapped_Low_ISR (void)
    {
         _asm goto YourLowPriorityISRCode _endasm
    }
    
    #if defined(PROGRAMMABLE_WITH_USB_HID_BOOTLOADER)||defined(PROGRAMMABLE_WITH_USB_MCHPUSB_BOOTLOADER)
    //Note: If this project is built while one of the bootloaders has
    //been defined, but then the output hex file is not programmed with
    //the bootloader, addresses 0x08 and 0x18 would end up programmed with 0xFFFF.
    //As a result, if an actual interrupt was enabled and occured, the PC would jump
    //to 0x08 (or 0x18) and would begin executing "0xFFFF" (unprogrammed space).  This
    //executes as nop instructions, but the PC would eventually reach the REMAPPED_RESET_VECTOR_ADDRESS
    //(0x1000 or 0x800, depending upon bootloader), and would execute the "goto _startup".  This
    //would effective reset the application.

    //To fix this situation, we should always deliberately place a
    //"goto REMAPPED_HIGH_INTERRUPT_VECTOR_ADDRESS" at address 0x08, and a
    //"goto REMAPPED_LOW_INTERRUPT_VECTOR_ADDRESS" at address 0x18.  When the output
    //hex file of this project is programmed with the bootloader, these sections do not
    //get bootloaded (as they overlap the bootloader space).  If the output hex file is not
    //programmed using the bootloader, then the below goto instructions do get programmed,
    //and the hex file still works like normal.  The below section is only required to fix this
    //scenario.
    #pragma code HIGH_INTERRUPT_VECTOR = 0x08
    void High_ISR (void)
    {
         _asm goto REMAPPED_HIGH_INTERRUPT_VECTOR_ADDRESS _endasm
    }
    #pragma code LOW_INTERRUPT_VECTOR = 0x18
    void Low_ISR (void)
    {
         _asm goto REMAPPED_LOW_INTERRUPT_VECTOR_ADDRESS _endasm
    }
    #endif  //end of "#if defined(PROGRAMMABLE_WITH_USB_HID_BOOTLOADER)||defined(PROGRAMMABLE_WITH_USB_LEGACY_CUSTOM_CLASS_BOOTLOADER)"

    #pragma code

    //These are your actual interrupt handling routines.
    #pragma interrupt YourHighPriorityISRCode
    void YourHighPriorityISRCode()
    {
        INTCONbits.GIEH = 0;
        SerialProc();
        INTCONbits.GIEH = 1;
    }
    #pragma interruptlow YourLowPriorityISRCode
    void YourLowPriorityISRCode()
    {
        //Check which interrupt flag caused the interrupt.
        //Service the interrupt
        //Clear the interrupt flag
        //Etc.
        LED1_PORT = 1;
        PutsString("low interrupt!\r\n");
    }   //This return will be a "retfie", since this is in a #pragma interruptlow section 


/** DECLARATIONS ***************************************************/
#if defined(__18CXX)
    #pragma code
#endif

/******************************************************************************
 * Function:        void main(void)
 * Overview:        Main program entry point.
 *****************************************************************************/
#if defined(__18CXX)
void main(void)
#else
int main(void)
#endif
{   
    InitializeSystem();

    while(1) {
        ProcessIO();        
    }
}


/********************************************************************
 * Function:        static void InitializeSystem(void)
 * Overview:        InitializeSystem is a centralize initialization
 *                  routine. All required USB initialization routines
 *                  are called from here.
 *
 *                  User application initialization routine should
 *                  also be called from here.                  
 *******************************************************************/
static void InitializeSystem(void)
{
    ADCON1 |= 0x0F;                 // Default all pins to digital

    // initialize
    LED1_TRIS = 0; // LED1 output
    LED2_TRIS = 0; // LED2 output
    IR_TRIS   = 1; // IR input
    SW_TRIS   = 1; // SW input
    IRLED_TRIS= 0; // IRLED input
    LED1_PORT = 0;
    LED2_PORT = 0;
    IRLED_PORT= 0;

    // timer list
    // 48MHz/4=12MHz => 0.08333[us/cycle]
    // 0.08333[us/cycle] *  2 =  0.16666us -> max: *65536 = 10.923ms
    // 0.08333[us/cycle] *  4 =  0.33333us -> max: *65536 = 21.845ms
    // 0.08333[us/cycle] *  8 =  0.66666us -> max: *65536 = 43.69ms
    // 0.08333[us/cycle] * 16 =  1.33333us -> max: *65536 = 87.381ms
    // 0.08333[us/cycle] * 32 =  2.66666us -> max: *65536 = 174.76ms
    // 0.08333[us/cycle] * 64 =  5.33333us -> max: *65536 = 349.5ms
    // 0.08333[us/cycle] *128 = 10.66666us -> max: *65536 = 699ms
    // 0.08333[us/cycle] *256 = 21.33333us -> max: *65536 = 1398ms

    // timer0 max=349.5[ms]
    T0CON = TIMER_INT_ON &
            T0_16BIT &
            T0_SOURCE_INT &
            T0_EDGE_RISE & // なんでもいい
            T0_PS_1_64;

    // timer1 max=43.69[ms]
    T1CON = TIMER_INT_ON &
            T1_16BIT_RW &
            T1_SOURCE_INT &
            T1_PS_1_8;

    // timer2 max=5.33333[us]*256=1.365[ms] 約1ms
    T2CON = T2_POST_1_4 &
            T2_PS_1_16;

    // configure USART
    // For a device with FOSC of 16 MHz, desired baud rate of 9600, Asynchronous mode, 8-bit BRG:
    // Desired Baud Rate = FOSC/(64 ([SPBRGH:SPBRG] + 1))
    // Solving for SPBRGH:SPBRG:
    // X = ((FOSC/Desired Baud Rate)/64) – 1
    //   = ((16000000/9600)/64) – 1
    //   = [25.042] = 25
    // Calculated Baud Rate = 16000000/(64 (25 + 1))
    //   = 9615
    // Error = (Calculated Baud Rate – Desired Baud Rate)/Desired Baud Rate
    //   = (9615 - 9600)/9600 = 0.16%

    // FOSC == 48 [MHz]
    //   X = ((48 * 1,000,000 / 9600)/64 -1
    //     = 77.125
    //   Calculated Baud Rate = 48 * 1,000,000 / (64 * (77+1)) = 9615.38
    //   Error = (9615 - 9600) / 9600 = 0.16%
    OpenUSART(USART_TX_INT_OFF &    // 送信割込みの禁止
              USART_RX_INT_ON &     // 受信割込みの許可
              USART_ASYNCH_MODE &   // 非同期（調歩）モード
              USART_EIGHT_BIT &     // ８ビットモード
              USART_CONT_RX &       // 連続受信モード
              USART_BRGH_LOW,       // 低速ボーレート
              77);                  // 9600 bps

    RCONbits.IPEN = 0;      //割込み優先順位制御：OFF (RCON レジスタのIPENビット = 0)
    INTCONbits.GIE = 1;     // 全割込み許可
    INTCONbits.PEIE = 1;    // 周辺機能の割込み有効

    // initilize other variables
    InitBuffer();
    AddBuffer(signalBuffer, sizeof(signalBuffer));
    ButtonInit(SW_BIT);
    enableReadIR = 1;
}

/********************************************************************
 * Function:        void ProcessIO(void)
 * Overview:        This function is a place holder for other user
 *                  routines. It is a mixture of both USB and
 *                  non-USB tasks.
 *******************************************************************/
void ProcessIO(void)
{   
    LED1_PORT = 0;
    IRLED_PORT = 0;

    ButtonProc();
    ReadIR();
    SendIR();
}

void SerialProc(void)
{
    WORD numBytesRead;
    BYTE i;
    char buff[10];
    char *buffPtr;
    BYTE *readPtr;
    char state; // 0:readed ',' 1:readed number
    BYTE exit;
    WORD byteOrWord; // 0:未設定
    WORD pos;
    WORD v;
    WORD bpos;

    // check whether data is recieved from uart
    if (!DataRdyUSART())
        return;

    bpos = 0;
    // read data from uart
    numBytesRead = ReadSerial(uartInBuffer, sizeof(uartInBuffer));
    if (numBytesRead == 0 || numBytesRead == 0xFFFF)
        return;

    state = 0;
    buffPtr = buff;
    readPtr = uartInBuffer;
    pos = 0;
    byteOrWord = 0;
    exit = 0;
loop:
    for(i=0;i<numBytesRead;i++) {
        if (readPtr[i]=='\r' || readPtr[i]=='\n'){
            if (pos>0) {
                if (buffPtr==buff) {
                    sprintf(uartOutBuffer,
                            (far rom char*)"parse error. need number. [%d,%c]\r\n",
                            bpos+i,readPtr[i]);
                    PutsStringCPtr(uartOutBuffer);
                    return;
                }
                *buffPtr++ = '\0';
                v = atoi(buff);
                exit += WriteBuffer(v,&pos,&byteOrWord);
                buffPtr = buff;

                WriteEOF(pos);
                SendIRImpl();
                PrintIRBuffer("echo,");
            }
            return;
        } else if (state==0) {
            if(readPtr[i] != 'H' && readPtr[i] != 'L') {
                sprintf(uartOutBuffer,
                        (far rom char*)"parse error. need 'H' or 'L'. [%d,%c]\r\n",
                        bpos+i,readPtr[i]);
                PutsStringCPtr(uartOutBuffer);

                WriteEOF(pos);
                PrintIRBuffer("echo,");
                return;
            }
            state = 1;
        } else if (state==1) {
            if (readPtr[i] == ',') {
                state = 0;
                if (buffPtr==buff) {
                    sprintf(uartOutBuffer,
                            (far rom char*)"parse error. need number. [%d,%c]\r\n",
                            bpos+i,readPtr[i]);
                    PutsStringCPtr(uartOutBuffer);
                    WriteEOF(pos);
                    PrintIRBuffer("echo,");
                    return;
                }
                *buffPtr++ = '\0';
                v = atoi(buff);
                exit += WriteBuffer(v,&pos,&byteOrWord);
                buffPtr = buff;
            } else if ('0' <= readPtr[i] && readPtr[i] <= '9') {
                *buffPtr++ = readPtr[i];
            } else {
                sprintf(uartOutBuffer,
                        (far rom char*)"parse error. need ',' or number. [%d,%c]\r\n",
                        bpos+i,readPtr[i]);
                PutsStringCPtr(uartOutBuffer);
                WriteEOF(pos);
                PrintIRBuffer("echo,");
                return;
            }
        }
    }
    bpos += numBytesRead;
    numBytesRead = ReadSerial(uartInBuffer, sizeof(uartInBuffer));
    if (numBytesRead == 0xFFFF)
        return;
    goto loop;
}


void ButtonProc(void)
{
    ButtonProcEveryMainLoop(PORTB);
    if (ButtonLongDownState() & SW_BIT)
        enableReadIR = !enableReadIR ;
    LED2_PORT = enableReadIR;

    if(PIR1bits.TMR2IF) {
        PIR1bits.TMR2IF = 0;
        ButtonProcEvery1ms();
    }
}

void ReadIR(void)
{
    WORD t;
    BYTE hilo;
    BYTE exit;
    WORD byteOrWord; // 0:未設定
    WORD pos;

    if (enableReadIR==0)
        return;

    if (IR_PORT == 1)
        return;

    // なにか信号があった

    WriteTimer0(0);
    INTCONbits.TMR0IF = 0;
    hilo = 0;

    pos = 0;
    byteOrWord = 0;
    exit = 0;
    while (exit==0) {
        LED1_PORT = !hilo;
        do {
            t = ReadTimer0();
            if (INTCONbits.TMR0IF || (t > MAX_WAIT_CYCLE)) {
                t = MAX_WAIT_CYCLE;
                INTCONbits.TMR0IF = 0;
                exit=1;
                break;
            }
        } while (IR_PORT == hilo);
        WriteTimer0(0);
        exit += WriteBuffer(t,&pos,&byteOrWord);
        hilo = !hilo;
    }
    LED1_PORT = 0;
    WriteEOF(pos);

    if (!WaitToReadySerial())
        return;
    PrintIRBuffer("received,");
}

void PrintIRBuffer(const rom char *title)
{
    WORD t;
    BYTE hilo;
    WORD byteOrWord; // 0:未設定
    WORD pos;
    char separator[2] = {'\0','\0'};

    PutsString("");  // なぜかこの出力がないと１発目が化ける

    PutsString(title);

    hilo = 1;
    pos = 0;
    byteOrWord = 0;
    while (1) {
        if (!WaitToReadySerial()) return;
        t = ReadBuffer(&pos,&byteOrWord);
        if (t==BUFF_EOF)
            break;
        sprintf(uartOutBuffer, (far rom char*)"%s%c%u",
                separator,
                hilo ? 'H' : 'L',
                t);
        WriteSerial(uartOutBuffer);
        hilo=!hilo;
        separator[0] = ',';
    }
    if (!WaitToReadySerial()) return;
    sprintf(uartOutBuffer, (far rom char*)"\r\n");
    WriteSerial(uartOutBuffer);
    if (!WaitToReadySerial()) return;
}

void SendIR(void)
{
    if ((ButtonUpState() & SW_BIT)==0)
        return;
    SendIRImpl();
}

void SendIRImpl(void)
{
    WORD t,wait;
    BYTE hilo;
    WORD pos;
    WORD byteOrWord; // 0:未設定

    WriteTimer0(0);
    INTCONbits.TMR0IF = 0;

    hilo = 1;
    pos = 0;
    byteOrWord = 0;
    while (1) {
        wait = ReadBuffer(&pos,&byteOrWord);
        if (wait==BUFF_EOF)
            break;
        if (wait==MAX_WAIT_CYCLE)
            break;
        do {
            LED1_PORT = hilo;
            IRLED_PORT = hilo;
            DelayIRFreqHi();
            t = ReadTimer0();
            if (t >= wait)
                break;
            LED1_PORT = 0;
            IRLED_PORT = 0;
            DelayIRFreqLo();
            t = ReadTimer0();
        } while(t < wait);

        WriteTimer0(0);
        hilo = !hilo;
        LED1_PORT = hilo;
        IRLED_PORT = hilo;
    }

    // wait 10msec [1cycle==0.083333333us]
    Delay10KTCYx(120);
    LED1_PORT = 0;
    IRLED_PORT = 0;

    PutsString("OK\r\n");

    LED1_PORT = 0;
    IRLED_PORT = 0;
}

void PutsString(const rom char *str)
{
    if (!WaitToReadySerial()) return;
    strcpypgm2ram(uartOutBuffer, (const far rom char*)str);
    WriteSerial(uartOutBuffer);
    if (!WaitToReadySerial()) return;
}

void PutsStringCPtr(char *str)
{
    if (!WaitToReadySerial()) return;
    WriteSerial(str);
    if (!WaitToReadySerial()) return;
}


// 38KHz のデューティー比 33% の HI で待つ
// HI:105.263157894737[cycle] == 8.77192982456142[us]
// 38KHz のデューティー比 50% の 場合
// HI:157.894736842105[cycle] == 13.1578947368421[us]
void DelayIRFreqHi(void)
{
    // duty 1/3
    Delay10TCYx(10);
    Delay1TCY();
    Delay1TCY();
    Delay1TCY();
    Delay1TCY();
    Delay1TCY();
}

// 38KHz のデューティー比 33% の LO で待つ
// LO:210.526315789474[cycle] == 17.5438596491228[us]
// 38KHz のデューティー比 50% の 場合
// LO:157.894736842105[cycle] == 13.1578947368421[us]
void DelayIRFreqLo(void)
{
    // duty 1/3
    Delay10TCYx(21);
    Delay1TCY();
}

/**
 * シリアル・ポートの Ready を待つ
 * 出力ポートの busy 状態を見る
 * timer1 を使ってオーバフローならば 0 を返す
 * Ready になれば 1 を返す
 */
int WaitToReadySerial(void)
{
    WriteTimer1(0);
    PIR1bits.TMR1IF = 0;
    while(PIR1bits.TMR1IF==0) {
        // wait to ready uart
        if (!BusyUSART())
            return 1;
    }
    return 0;
}


/**
 * シリアルからデータリード
 * @param buffer 入力バッファ
 * @param length サイズ
 */
WORD ReadSerial(BYTE *buffer, WORD length)
{
    BYTE i;
    for (i=0; i<length; i++) {
        if (!DataRdyUSART())
            break;
        buffer[i] = ReadUSART();
    }
    if (RCSTAbits.OERR==1) {
        sprintf(uartOutBuffer,
                (far rom char*)"error: overrun! RCSTA:0x%02x PIR1:0x%02x i:%d\r\n",
                RCSTA, PIR1, i);
        PutsStringCPtr(uartOutBuffer);

        RCSTAbits.CREN = 0; // clear the OVR flag 
        RCSTAbits.CREN = 1; 
        sprintf(uartOutBuffer,
                (far rom char*)"recovery: overrun! RCSTA:0x%02x PIR1:0x%02x i:%d\r\n",
                RCSTA, PIR1, i);
        PutsStringCPtr(uartOutBuffer);
        return 0xFFFF;
    }
    return i;
}

/**
 * シリアルバッファへ書き込み
 * @param str 出力バッファ
 */
void WriteSerial(char *str)
{
    putsUSART(str);
}
