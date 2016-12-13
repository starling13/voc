/* voc 2.00 [2016/12/13]. Bootstrapping compiler for address size 8, alignment 8. xtspaSF */

#ifndef Out__h
#define Out__h

#include "SYSTEM.h"


import BOOLEAN Out_IsConsole;


import void Out_Char (CHAR ch);
import void Out_DumpHeap (void);
import void Out_DumpTag (INT64 addr);
import void Out_DumpType (SYSTEM_BYTE *o, ADDRESS o__len);
import void Out_Flush (void);
import void Out_Hex (INT64 x, INT64 n);
import void Out_HexDump (SYSTEM_BYTE *m, ADDRESS m__len);
import void Out_HexDumpAdr (INT64 adr, INT64 offset, INT32 length);
import void Out_Int (INT64 x, INT64 n);
import void Out_Ln (void);
import void Out_LongReal (LONGREAL x, INT16 n);
import void Out_Open (void);
import void Out_Real (REAL x, INT16 n);
import void Out_String (CHAR *str, ADDRESS str__len);
import LONGREAL Out_Ten (INT16 e);
import void *Out__init(void);


#endif // Out
