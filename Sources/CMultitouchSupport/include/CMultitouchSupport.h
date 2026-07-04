#ifndef CMULTITOUCH_SUPPORT_H
#define CMULTITOUCH_SUPPORT_H

// C-layout mirror of the private MultitouchSupport contact structures.
// Field layout follows the community-documented header (asmagill/hs._asm.undocumented.
// touchdevice, Karabiner-Elements MultitouchExtension); validated live at gate 3.1.
// Defined in C (not Swift) because Swift struct layout is not guaranteed C-compatible.

#include <stdint.h>

typedef struct {
    float x;
    float y;
} TLMTPoint;

typedef struct {
    TLMTPoint position;
    TLMTPoint velocity;
} TLMTVector;

typedef struct {
    int32_t frame;
    double timestamp;
    int32_t identifier;
    int32_t state;        // 0..7, matches TilerCore.ContactState
    int32_t fingerID;
    int32_t handID;
    TLMTVector normalized; // position in 0..1, origin bottom-left
    float zTotal;          // contact "size"
    int32_t field9;
    float angle;
    float majorAxis;
    float minorAxis;
    TLMTVector absolute;   // millimeters
    int32_t field14;
    int32_t field15;
    float zDensity;
} TLMTTouch;

typedef void *TLMTDeviceRef;

typedef int (*TLMTContactCallback)(TLMTDeviceRef device, TLMTTouch *touches,
                                   int32_t numTouches, double timestamp, int32_t frame);

#endif
