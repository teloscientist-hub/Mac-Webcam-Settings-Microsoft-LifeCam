#import "USBHostShim.h"

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>
#import <IOUSBHost/IOUSBHost.h>

WSUSBHostRequestResult WSUSBHostSendDeviceRequest(
    uint64_t registryEntryID,
    uint64_t options,
    uint8_t requestType,
    uint8_t request,
    uint16_t value,
    uint16_t index,
    void *buffer,
    uint16_t length
) {
    WSUSBHostRequestResult result = {
        .status = (int32_t)kIOReturnError,
        .bytesTransferred = 0
    };

    @autoreleasepool {
        CFMutableDictionaryRef matching = IORegistryEntryIDMatching(registryEntryID);
        if (!matching) {
            result.status = (int32_t)kIOReturnBadArgument;
            return result;
        }

        io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, matching);
        if (service == IO_OBJECT_NULL) {
            result.status = (int32_t)kIOReturnNoDevice;
            return result;
        }

        dispatch_queue_t queue = dispatch_queue_create("webcamsettings.usbhost", DISPATCH_QUEUE_SERIAL);
        NSError *error = nil;
        IOUSBHostDevice *device = [[IOUSBHostDevice alloc] initWithIOService:service
                                                                     options:(IOUSBHostObjectInitOptions)options
                                                                       queue:queue
                                                                       error:&error
                                                             interestHandler:nil];
        IOObjectRelease(service);

        if (!device) {
            result.status = (int32_t)(error ? error.code : kIOReturnError);
            return result;
        }

        IOUSBDeviceRequest deviceRequest = {0};
        deviceRequest.bmRequestType = requestType;
        deviceRequest.bRequest = request;
        deviceRequest.wValue = value;
        deviceRequest.wIndex = index;
        deviceRequest.wLength = length;

        NSMutableData *data = nil;
        if (buffer && length > 0) {
            data = [NSMutableData dataWithBytesNoCopy:buffer length:length freeWhenDone:NO];
        } else if (length > 0) {
            data = [NSMutableData dataWithLength:length];
        }

        NSUInteger bytesTransferred = 0;
        BOOL ok = [device sendDeviceRequest:deviceRequest
                                       data:data
                           bytesTransferred:&bytesTransferred
                                      error:&error];
        result.status = ok ? (int32_t)kIOReturnSuccess : (int32_t)(error ? error.code : kIOReturnError);
        result.bytesTransferred = (uint32_t)bytesTransferred;
        [device destroy];
    }

    return result;
}

static CFUUIDRef WSUSBMakeDeviceUserClientTypeID(void) {
    return CFUUIDGetConstantUUIDWithBytes(
        nil,
        0x9d, 0xc7, 0xb7, 0x80, 0x9e, 0xc0, 0x11, 0xD4,
        0xa5, 0x4f, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61
    );
}

static CFUUIDRef WSUSBMakeIOCFPlugInInterfaceID(void) {
    return CFUUIDGetConstantUUIDWithBytes(
        nil,
        0xC2, 0x44, 0xE8, 0x58, 0x10, 0x9C, 0x11, 0xD4,
        0x91, 0xD4, 0x00, 0x50, 0xE4, 0xC6, 0x42, 0x6F
    );
}

static CFUUIDRef WSUSBMakeDeviceInterfaceID942(void) {
    return CFUUIDGetConstantUUIDWithBytes(
        kCFAllocatorSystemDefault,
        0x56, 0xAD, 0x08, 0x9D, 0x87, 0x8D, 0x4B, 0xEA,
        0xA1, 0xF5, 0x2C, 0x8D, 0xC4, 0x3E, 0x8A, 0x98
    );
}

static io_service_t WSUSBFindLegacyUSBDeviceService(uint32_t vendorID, uint32_t productID) {
    CFMutableDictionaryRef matching = IOServiceMatching(kIOUSBDeviceClassName);
    if (!matching) {
        return IO_OBJECT_NULL;
    }

    CFDictionarySetValue(matching, CFSTR(kUSBVendorID), CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &vendorID));
    CFDictionarySetValue(matching, CFSTR(kUSBProductID), CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &productID));
    return IOServiceGetMatchingService(kIOMainPortDefault, matching);
}

static WSUSBHostRequestResult WSUSBPerformDeviceRequestTOOnService(
    io_service_t service,
    bool seize,
    uint8_t requestType,
    uint8_t request,
    uint16_t value,
    uint16_t index,
    void *buffer,
    uint16_t length,
    uint32_t noDataTimeout,
    uint32_t completionTimeout
) {
    WSUSBHostRequestResult result = {
        .status = (int32_t)kIOReturnError,
        .bytesTransferred = 0
    };

    IOCFPlugInInterface **plugin = NULL;
    SInt32 score = 0;
    IOReturn pluginResult = IOCreatePlugInInterfaceForService(
        service,
        WSUSBMakeDeviceUserClientTypeID(),
        WSUSBMakeIOCFPlugInInterfaceID(),
        &plugin,
        &score
    );

    if (pluginResult != kIOReturnSuccess || plugin == NULL) {
        result.status = (int32_t)pluginResult;
        return result;
    }

    IOUSBDeviceInterface942 **deviceInterface = NULL;
    HRESULT queryResult = (*plugin)->QueryInterface(
        plugin,
        CFUUIDGetUUIDBytes(WSUSBMakeDeviceInterfaceID942()),
        (LPVOID *)&deviceInterface
    );
    (*plugin)->Release(plugin);

    if (queryResult != S_OK || deviceInterface == NULL) {
        result.status = (int32_t)queryResult;
        return result;
    }

    IOReturn openResult = seize
        ? (*deviceInterface)->USBDeviceOpenSeize(deviceInterface)
        : (*deviceInterface)->USBDeviceOpen(deviceInterface);
    if (openResult != kIOReturnSuccess) {
        result.status = (int32_t)openResult;
        (*deviceInterface)->Release(deviceInterface);
        return result;
    }

    IOUSBDevRequestTO deviceRequest = {0};
    deviceRequest.bmRequestType = requestType;
    deviceRequest.bRequest = request;
    deviceRequest.wValue = value;
    deviceRequest.wIndex = index;
    deviceRequest.wLength = length;
    deviceRequest.pData = buffer;
    deviceRequest.wLenDone = 0;
    deviceRequest.noDataTimeout = noDataTimeout;
    deviceRequest.completionTimeout = completionTimeout;

    IOReturn requestResult = (*deviceInterface)->DeviceRequestTO(deviceInterface, &deviceRequest);
    if (requestResult == kIOReturnSuccess) {
        result.status = (int32_t)kIOReturnSuccess;
        result.bytesTransferred = (uint32_t)deviceRequest.wLenDone;
    } else {
        result.status = (int32_t)requestResult;
    }

    (*deviceInterface)->USBDeviceClose(deviceInterface);
    (*deviceInterface)->Release(deviceInterface);
    return result;
}

WSUSBHostRequestResult WSUSBDeviceInterfaceSendRequestTO(
    uint64_t registryEntryID,
    bool seize,
    uint8_t requestType,
    uint8_t request,
    uint16_t value,
    uint16_t index,
    void *buffer,
    uint16_t length,
    uint32_t noDataTimeout,
    uint32_t completionTimeout
) {
    CFMutableDictionaryRef matching = IORegistryEntryIDMatching(registryEntryID);
    if (!matching) {
        return (WSUSBHostRequestResult){ .status = (int32_t)kIOReturnBadArgument, .bytesTransferred = 0 };
    }

    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, matching);
    if (service == IO_OBJECT_NULL) {
        return (WSUSBHostRequestResult){ .status = (int32_t)kIOReturnNoDevice, .bytesTransferred = 0 };
    }

    WSUSBHostRequestResult result = WSUSBPerformDeviceRequestTOOnService(
        service,
        seize,
        requestType,
        request,
        value,
        index,
        buffer,
        length,
        noDataTimeout,
        completionTimeout
    );
    IOObjectRelease(service);
    return result;
}

WSUSBHostRequestResult WSUSBLegacyDeviceRequestTOForVIDPID(
    uint32_t vendorID,
    uint32_t productID,
    bool seize,
    uint8_t requestType,
    uint8_t request,
    uint16_t value,
    uint16_t index,
    void *buffer,
    uint16_t length,
    uint32_t noDataTimeout,
    uint32_t completionTimeout
) {
    io_service_t service = WSUSBFindLegacyUSBDeviceService(vendorID, productID);
    if (service == IO_OBJECT_NULL) {
        return (WSUSBHostRequestResult){ .status = (int32_t)kIOReturnNoDevice, .bytesTransferred = 0 };
    }

    WSUSBHostRequestResult result = WSUSBPerformDeviceRequestTOOnService(
        service,
        seize,
        requestType,
        request,
        value,
        index,
        buffer,
        length,
        noDataTimeout,
        completionTimeout
    );
    IOObjectRelease(service);
    return result;
}
