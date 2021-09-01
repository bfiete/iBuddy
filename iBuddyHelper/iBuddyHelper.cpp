#include "BeefySysLib/Common.h"

#include "vjoy/SDK/inc/public.h"
#include "vjoy/SDK/inc/vjoyinterface.h"

#pragma comment(lib, "c:/proj/iBuddy/iBuddyHelper/vjoy/SDK/lib/amd64/vJoyInterface.lib")

int rID = 1;
static bool gDidInit = false;

BF_EXPORT __declspec(dllexport) void BF_CALLTYPE VJoy_Set(int x, int y, int z, int btn)
{
	if (!gDidInit)
	{		
		AcquireVJD(1);
		ResetVJD(1);
		gDidInit = true;
	}

	//GetvJoyVersion();
	SetAxis(x, rID, HID_USAGE_X);
	SetAxis(y, rID, HID_USAGE_Y);
	SetAxis(z, rID, HID_USAGE_Z);
	SetBtn((btn >> 0) & 1, rID, 1);
	SetBtn((btn >> 1) & 1, rID, 2);
	SetBtn((btn >> 2) & 1, rID, 3);
	SetBtn((btn >> 3) & 1, rID, 4);
	SetBtn((btn >> 4) & 1, rID, 5);
	SetBtn((btn >> 5) & 1, rID, 6);
	SetBtn((btn >> 6) & 1, rID, 7);
	SetBtn((btn >> 7) & 1, rID, 8);
}