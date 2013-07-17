#ifndef _buffer_h_
#define _buffer_h_

#define BUFF_EOF 0xFFFF


void InitBuffer(void);
void AddBuffer(BYTE *addr, WORD size);
WORD ReadBuffer(WORD *pos, WORD *byteOrWord);
BYTE WriteBuffer(WORD v, WORD *pos, WORD *byteOrWord);
void WriteEOF(WORD pos);

#endif//_buffer_h_
