#import <CoreFoundation/CoreFoundation.h>
#import <HBLog.h>

#import <dlfcn.h>
#import <mach/port.h>
#import <mach/kern_return.h>

int HVer = 0;

#define MAX_HVER 15

typedef struct HXISPCaptureStream *HXISPCaptureStreamRef;
typedef struct HXISPCaptureDevice *HXISPCaptureDeviceRef;
typedef struct HXISPCaptureGroup *HXISPCaptureGroupRef;

int (*SetTorchLevel)(CFNumberRef, HXISPCaptureStreamRef, HXISPCaptureDeviceRef) = NULL;
int (*SetTorchLevelWithGroup)(CFNumberRef, HXISPCaptureStreamRef, HXISPCaptureGroupRef, HXISPCaptureDeviceRef) = NULL;

%group SetTorchLevelHook

%hookf(int, SetTorchLevel, CFNumberRef level, HXISPCaptureStreamRef stream, HXISPCaptureDeviceRef device) {
    bool *highCurrentEnabled = (bool *)((uintptr_t)stream + 0x90C);
    bool original = *highCurrentEnabled;
    *highCurrentEnabled = YES;
    int result = %orig(level, stream, device);
    *highCurrentEnabled = original;
    return result;
}

%end

%group SetTorchLevelWithGroupHook

%hookf(int, SetTorchLevelWithGroup, CFNumberRef level, HXISPCaptureStreamRef stream, HXISPCaptureGroupRef group, HXISPCaptureDeviceRef device) {
    bool *highCurrentEnabled = HVer > 9 ? (bool *)((uintptr_t)stream + 0xB70) : (bool *)((uintptr_t)stream + 0xA6C);
    bool original = *highCurrentEnabled;
    *highCurrentEnabled = YES;
    int result = %orig(level, stream, group, device);
    *highCurrentEnabled = original;
    return result;
}

%end

%ctor {
    void *IOKit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
    if (IOKit) {
        mach_port_t *kIOMasterPortDefault = (mach_port_t *)dlsym(IOKit, "kIOMasterPortDefault");
        CFMutableDictionaryRef (*IOServiceMatching)(const char *name) = (CFMutableDictionaryRef (*)(const char *))dlsym(IOKit, "IOServiceMatching");
        mach_port_t (*IOServiceGetMatchingService)(mach_port_t masterPort, CFDictionaryRef matching) = (mach_port_t (*)(mach_port_t, CFDictionaryRef))dlsym(IOKit, "IOServiceGetMatchingService");
        kern_return_t (*IOObjectRelease)(mach_port_t object) = (kern_return_t (*)(mach_port_t))dlsym(IOKit, "IOObjectRelease");
        if (kIOMasterPortDefault && IOServiceGetMatchingService && IOObjectRelease) {
            char AppleHXCamIn[14];
            for (HVer = MAX_HVER; HVer > 9; --HVer) {
                snprintf(AppleHXCamIn, 14, "AppleH%dCamIn", HVer);
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
    snprintf(imagePath, 49, "/System/Library/MediaCapture/H%dISP.mediacapture", HVer);
    dlopen(imagePath, RTLD_LAZY);
    MSImageRef hxRef = MSGetImageByName(imagePath);
    switch (HVer) {
        case 9: {
            SetTorchLevel = (int (*)(CFNumberRef, HXISPCaptureStreamRef, HXISPCaptureDeviceRef))MSFindSymbol(hxRef, "__ZL13SetTorchLevelPKvP18H9ISPCaptureStreamP18H9ISPCaptureDevice");
            if (SetTorchLevel == NULL)
                SetTorchLevelWithGroup = (int (*)(CFNumberRef, HXISPCaptureStreamRef, HXISPCaptureGroupRef, HXISPCaptureDeviceRef))MSFindSymbol(hxRef, "__ZL13SetTorchLevelPKvP18H9ISPCaptureStreamP17H9ISPCaptureGroupP18H9ISPCaptureDevice");
            break;
        }
        default: {
            char SetTorchLevelWithGroupSymbol[88];
            snprintf(SetTorchLevelWithGroupSymbol, 88, "__ZL13SetTorchLevelPKvP19H%dISPCaptureStreamP18H%dISPCaptureGroupP19H%dISPCaptureDevice", HVer, HVer, HVer);
            SetTorchLevelWithGroup = (int (*)(CFNumberRef, HXISPCaptureStreamRef, HXISPCaptureGroupRef, HXISPCaptureDeviceRef))MSFindSymbol(hxRef, SetTorchLevelWithGroupSymbol);
            if (SetTorchLevelWithGroup == NULL) {
                char SetTorchLevelSymbol[67];
                snprintf(SetTorchLevelSymbol, 67, "__ZL13SetTorchLevelPKvP19H%dISPCaptureStreamP19H%dISPCaptureDevice", HVer, HVer);
                SetTorchLevel = (int (*)(CFNumberRef, HXISPCaptureStreamRef, HXISPCaptureDeviceRef))MSFindSymbol(hxRef, SetTorchLevelSymbol);
            }
            break;
        }
    }
    HBLogDebug(@"SetTorchLevel found: %d", SetTorchLevel != NULL);
    HBLogDebug(@"SetTorchLevelWithGroup found: %d", SetTorchLevelWithGroup != NULL);
    if (SetTorchLevelWithGroup) {
        %init(SetTorchLevelWithGroupHook);
    } else {
        %init(SetTorchLevelHook);
    }
}