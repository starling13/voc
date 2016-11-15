/* voc 1.95 [2016/11/15]. Bootstrapping compiler for address size 8, alignment 8. xtspaSF */

#ifndef Reals__h
#define Reals__h

#include "SYSTEM.h"




import void Reals_Convert (REAL x, INT16 n, CHAR *d, LONGINT d__len);
import void Reals_ConvertH (REAL y, CHAR *d, LONGINT d__len);
import void Reals_ConvertHL (LONGREAL x, CHAR *d, LONGINT d__len);
import void Reals_ConvertL (LONGREAL x, INT16 n, CHAR *d, LONGINT d__len);
import INT16 Reals_Expo (REAL x);
import INT16 Reals_ExpoL (LONGREAL x);
import void Reals_SetExpo (REAL *x, INT16 ex);
import REAL Reals_Ten (INT16 e);
import LONGREAL Reals_TenL (INT16 e);
import void *Reals__init(void);


#endif // Reals
