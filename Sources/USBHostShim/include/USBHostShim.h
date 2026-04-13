#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct WSUSBHostRequestResult {
    int32_t status;
    uint32_t bytesTransferred;
} WSUSBHostRequestResult;

WSUSBHostRequestResult WSUSBHostSendDeviceRequest(
    uint64_t registryEntryID,
    uint64_t options,
    uint8_t requestType,
    uint8_t request,
    uint16_t value,
    uint16_t index,
    void *buffer,
    uint16_t length
);

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
);

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
);

#ifdef __cplusplus
}
#endif
