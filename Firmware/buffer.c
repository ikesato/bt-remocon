#include "GenericTypeDefs.h"
#include "buffer.h"

#define BUFF_BW_BYTE 0xFFFE
#define BUFF_BW_WORD 0xFFFD

struct BUFFER {
    BYTE *addr;
    WORD size;
} buffer[5];
BYTE buffNum;
WORD totalSize;


BYTE ReadBYTEBuffer(WORD i);
BYTE WriteBYTEBuffer(WORD i, BYTE v);

void InitBuffer(void)
{
    buffNum = 0;
    totalSize = 0;
}

void AddBuffer(BYTE *addr, WORD size)
{
    buffer[buffNum].addr = addr;
    buffer[buffNum].size = size;
    buffNum++;
    totalSize += size;
}

WORD ReadBuffer(WORD *pos, WORD *byteOrWord)
{
	BYTE lo = ReadBYTEBuffer(*pos);
	BYTE hi = ReadBYTEBuffer((*pos)+1);
	WORD hilo = ((WORD)hi<<8)|lo;
    if ((*pos)+2 > totalSize)
		return BUFF_EOF;
	switch (hilo) {
		case BUFF_BW_BYTE:
			(*pos)+=2;
			lo = ReadBYTEBuffer(*pos);
			(*pos)++;
			*byteOrWord = BUFF_BW_BYTE;
            if ((*pos) > totalSize)
                return BUFF_EOF;
			return lo;
		case BUFF_BW_WORD:
			(*pos)+=2;
			lo = ReadBYTEBuffer(*pos);
			(*pos)++;
			hi = ReadBYTEBuffer(*pos);
			(*pos)++;
			*byteOrWord = BUFF_BW_WORD;
            if ((*pos) > totalSize)
                return BUFF_EOF;
			return ((WORD)hi<<8)|lo;
		case BUFF_EOF:
			return BUFF_EOF;
	}
	if (*byteOrWord == BUFF_BW_BYTE) {
		(*pos)++;
		return lo;
	} else {
		(*pos)+=2;
		return hilo;
	}
}

BYTE WriteBuffer(WORD v, WORD *pos, WORD *byteOrWord)
{
	WORD lastBW = *byteOrWord;
	BYTE hi,lo;

	if (v <= 0xFF)
		*byteOrWord = BUFF_BW_BYTE;
	else
		*byteOrWord = BUFF_BW_WORD;
	if (lastBW != *byteOrWord) {
		hi = (*byteOrWord)>>8;
		lo = (*byteOrWord)&0xFF;
		if (WriteBYTEBuffer(*pos, lo))
			return 1;
		(*pos)++;
		if (WriteBYTEBuffer(*pos, hi))
			return 1;
		(*pos)++;
	}
	if (v <= 0xFF) {
		if (WriteBYTEBuffer(*pos, (BYTE)v))
            return 1;
        (*pos)++;
	} else {
		hi = v>>8;
		lo = v&0xFF;
		if (WriteBYTEBuffer(*pos, lo))
            return 1;
		(*pos)++;
		if (WriteBYTEBuffer(*pos, hi))
            return 1;
		(*pos)++;
	}
	return 0;
}

void WriteEOF(WORD pos)
{
    if (pos+2 > (totalSize))
        return;
    WriteBYTEBuffer(pos, BUFF_EOF&0xff);
    WriteBYTEBuffer(pos+1, BUFF_EOF>>8);
}


BYTE ReadBYTEBuffer(WORD pos)
{
	BYTE *p=NULL;
    BYTE i;
    for (i=0; i<buffNum; i++) {
        if (pos < buffer[i].size) {
            p = buffer[i].addr;
            break;
        }
        pos -= buffer[i].size;
    }
    if (p==NULL)
        return 0xff;
    return p[pos];
}

BYTE WriteBYTEBuffer(WORD pos, BYTE v)
{
	BYTE *p=NULL;
    BYTE i;
    for (i=0; i<buffNum; i++) {
        if (pos < buffer[i].size) {
            p = buffer[i].addr;
            break;
        }
        pos -= buffer[i].size;
    }
    if (p==NULL)
        return 1;
    p[pos] = v;
    return 0;
}

//	WORD ReadWORDBuffer(WORD i)
//	{
//		WORD *p;
//		if (i<BUFF_U1_WSIZE) {
//			p = buff_user1.wBuff;
//		} else if (i<(BUFF_U1_WSIZE+BUFF_U2_WSIZE)) {
//			p = buff_user2.wBuff;
//			i -= BUFF_U1_WSIZE;
//	//	} else if (i<(BUFF_U1_WSIZE+BUFF_U2_WSIZE+BUFF_U3_WSIZE)) {
//	//		p = buff_user3.wBuff;
//	//		i -= BUFF_U1_WSIZE+BUFF_U2_WSIZE;
//		} else {
//			return 0xffff;
//		}
//		return p[i];
//	}
//	
//	BYTE WriteWORDBuffer(WORD i, WORD v)
//	{
//		WORD *p;
//		if (i<BUFF_U1_WSIZE) {
//			p = buff_user1.wBuff;
//		} else if (i<BUFF_U1_WSIZE+BUFF_U2_WSIZE) {
//			p = buff_user2.wBuff;
//			i -= BUFF_U1_WSIZE;
//	//	} else if (i<(BUFF_U1_WSIZE+BUFF_U2_WSIZE+BUFF_U3_WSIZE)) {
//	//		p = buff_user3.wBuff;
//	//		i -= BUFF_U1_WSIZE+BUFF_U2_WSIZE;
//		} else {
//			return 1;
//		}
//		p[i] = v;
//	    return 0;
//	}
