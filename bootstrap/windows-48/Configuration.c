/* voc 1.95 [2016/11/15]. Bootstrapping compiler for address size 8, alignment 8. xtspaSF */

#define SHORTINT INT8
#define INTEGER  INT16
#define LONGINT  INT32
#define SET      UINT32

#include "SYSTEM.h"


export CHAR Configuration_versionLong[75];





export void *Configuration__init(void)
{
	__DEFMOD;
	__REGMOD("Configuration", 0);
/* BEGIN */
	__MOVE("1.95 [2016/11/15]. Bootstrapping compiler for address size 8, alignment 8.", Configuration_versionLong, 75);
	__ENDMOD;
}
