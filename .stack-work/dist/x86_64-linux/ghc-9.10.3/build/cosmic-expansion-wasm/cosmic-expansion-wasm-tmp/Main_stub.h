#include <HsFFI.h>
#if defined(__cplusplus)
extern "C" {
#endif
extern HsStablePtr initState(HsInt32 a1);
extern void stepState(HsStablePtr a1, HsDouble a2);
extern void applyBlastState(HsStablePtr a1, HsDouble a2, HsDouble a3, HsDouble a4);
extern void warpState(HsStablePtr a1, HsInt32 a2, HsDouble a3, HsDouble a4, HsDouble a5);
extern void writePositions(HsStablePtr a1);
extern HsPtr positionsPtr(HsStablePtr a1);
extern HsInt32 stateCount(HsStablePtr a1);
extern void freeState(HsStablePtr a1);
#if defined(__cplusplus)
}
#endif

