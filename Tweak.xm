#import "../PSHeader/Misc.h"
#import <HBLog.h>
#import "Header.h"

#import <dlfcn.h>
#import <mach/port.h>
#import <mach/kern_return.h>

typedef struct HXISPCaptureStream *HXISPCaptureStreamRef;
typedef struct HXISPCaptureDevice *HXISPCaptureDeviceRef;
typedef struct HXISPCaptureGroup *HXISPCaptureGroupRef;

int (*SetTorchLevel)(CFNumberRef, HXISPCaptureStreamRef, HXISPCaptureDeviceRef) = NULL;
int (*SetTorchLevelWithGroup)(CFNumberRef, HXISPCaptureStreamRef, HXISPCaptureGroupRef, HXISPCaptureDeviceRef) = NULL;
SInt32 (*GetCFPreferenceNumber)(CFStringRef const, CFStringRef const, SInt32) = NULL;

%group SetTorchLevelHook

%hookf(int, SetTorchLevel, CFNumberRef level, HXISPCaptureStreamRef stream, HXISPCaptureDeviceRef device) {
    BOOL enabled = GetCFPreferenceNumber(key, kDomain, 0);
    bool *highCurrentEnabled = (bool *)((uintptr_t)stream + 0x90C);
    bool original = *highCurrentEnabled;
    if (enabled)
        *highCurrentEnabled = YES;
    int result = %orig(level, stream, device);
    *highCurrentEnabled = original;
    return result;
}

%end

%group SetTorchLevelWithGroupHook

%hookf(int, SetTorchLevelWithGroup, CFNumberRef level, HXISPCaptureStreamRef stream, HXISPCaptureGroupRef group, HXISPCaptureDeviceRef device) {
    BOOL enabled = GetCFPreferenceNumber(key, kDomain, 0);
    bool *highCurrentEnabled = (bool *)((uintptr_t)stream + 0xA6C);
    bool original = *highCurrentEnabled;
    if (enabled)
        *highCurrentEnabled = YES;
    int result = %orig(level, stream, group, device);
    *highCurrentEnabled = original;
    return result;
}

%end

%ctor {
    int HVer = 0;
    void *IOKit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
    if (IOKit) {
        mach_port_t *kIOMasterPortDefault = (mach_port_t *)dlsym(IOKit, "kIOMasterPortDefault");
        CFMutableDictionaryRef (*IOServiceMatching)(const char *name) = (CFMutableDictionaryRef (*)(const char *))dlsym(IOKit, "IOServiceMatching");
        mach_port_t (*IOServiceGetMatchingService)(mach_port_t masterPort, CFDictionaryRef matching) = (mach_port_t (*)(mach_port_t, CFDictionaryRef))dlsym(IOKit, "IOServiceGetMatchingService");
        kern_return_t (*IOObjectRelease)(mach_port_t object) = (kern_return_t (*)(mach_port_t))dlsym(IOKit, "IOObjectRelease");
        if (kIOMasterPortDefault && IOServiceGetMatchingService && IOObjectRelease) {
            char AppleHXCamIn[14];
            for (HVer = 13; HVer > 9; --HVer) {
                sprintf(AppleHXCamIn, "AppleH%dCamIn", HVer);
                mach_port_t hx = IOServiceGetMatchingService(*kIOMasterPortDefault, IOServiceMatching(AppleHXCamIn));
                if (hx) {
                    IOObjectRelease(hx);
                    break;
                }
            }
            if (HVer == 9) {
                mach_port_t h9 = IOServiceGetMatchingService(*kIOMasterPortDefault, IOServiceMatching("AppleH9CamIn"));
                if (h9)
                    IOObjectRelease(h9);
                else
                    HVer = 0;
            }
        }
        dlclose(IOKit);
        HBLogDebug(@"Detected ISP version: %d", HVer);
    }
    if (HVer == 0) return;
    char imagePath[49];
    sprintf(imagePath, "/System/Library/MediaCapture/H%dISP.mediacapture", HVer);
    dlopen(imagePath, RTLD_LAZY);
    MSImageRef hxRef = MSGetImageByName(imagePath);
    switch (HVer) {
        case 9: {
            SetTorchLevel = (int (*)(CFNumberRef, HXISPCaptureStreamRef, HXISPCaptureDeviceRef))_PSFindSymbolCallable(hxRef, "__ZL13SetTorchLevelPKvP18H9ISPCaptureStreamP18H9ISPCaptureDevice");
            if (SetTorchLevel == NULL)
                SetTorchLevelWithGroup = (int (*)(CFNumberRef, HXISPCaptureStreamRef, HXISPCaptureGroupRef, HXISPCaptureDeviceRef))_PSFindSymbolCallable(hxRef, "__ZL13SetTorchLevelPKvP18H9ISPCaptureStreamP17H9ISPCaptureGroupP18H9ISPCaptureDevice");
            GetCFPreferenceNumber = (SInt32 (*)(CFStringRef const, CFStringRef const, SInt32))_PSFindSymbolCallable(hxRef, "__ZN5H9ISP26H9ISPGetCFPreferenceNumberEPK10__CFStringS2_i");
            break;
        }
        default: {
            char SetTorchLevelWithGroupSymbol[88];
            sprintf(SetTorchLevelWithGroupSymbol, "__ZL13SetTorchLevelPKvP19H%dISPCaptureStreamP18H%dISPCaptureGroupP19H%dISPCaptureDevice", HVer, HVer, HVer);
            SetTorchLevelWithGroup = (int (*)(CFNumberRef, HXISPCaptureStreamRef, HXISPCaptureGroupRef, HXISPCaptureDeviceRef))_PSFindSymbolCallable(hxRef, SetTorchLevelWithGroupSymbol);
            if (SetTorchLevelWithGroup == NULL) {
                char SetTorchLevelSymbol[67];
                sprintf(SetTorchLevelSymbol, "__ZL13SetTorchLevelPKvP19H%dISPCaptureStreamP19H%dISPCaptureDevice", HVer, HVer);
                SetTorchLevel = (int (*)(CFNumberRef, HXISPCaptureStreamRef, HXISPCaptureDeviceRef))_PSFindSymbolCallable(hxRef, SetTorchLevelSymbol);
            }
            char GetCFPreferenceNumberSymbol[60];
            sprintf(GetCFPreferenceNumberSymbol, "__ZN6H10ISP27H%dISPGetCFPreferenceNumberEPK10__CFStringS2_i", HVer);
            GetCFPreferenceNumber = (SInt32 (*)(CFStringRef const, CFStringRef const, SInt32))_PSFindSymbolCallable(hxRef, GetCFPreferenceNumberSymbol);
            break;
        }
    }
    HBLogDebug(@"SetTorchLevel found: %d", SetTorchLevel != NULL);
    HBLogDebug(@"SetTorchLevelWithGroup found: %d", SetTorchLevelWithGroup != NULL);
    HBLogDebug(@"GetCFPreferenceNumber found: %d", GetCFPreferenceNumber != NULL);
    if (SetTorchLevelWithGroup) {
        %init(SetTorchLevelWithGroupHook);
    } else {
        %init(SetTorchLevelHook);
    }
    %init;
}