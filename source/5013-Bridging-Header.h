#ifndef _013_Bridging_Header_h
#define _013_Bridging_Header_h

#include "exploit/offsets.h"
#include "exploit/exploit.h"
#include "exploit/krw.h"
#include "exploit/physical.h"

#include "mcm/mcm_bridge.h"
#include "worse_query/worse_query.h"
#include "app/app_info.h"

// sandbox_escape.c
extern int sandbox_escape(void);

#endif
