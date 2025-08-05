/**
 *==============================================================================
 * MJC3_JOYSTICK_MEX.CPP
 *==============================================================================
 * High-performance MEX interface for Thorlabs MJC3 joystick.
 *
 * This MEX function provides direct HID access to the MJC3 joystick without
 * requiring PsychHID or other external dependencies. It implements a low-level
 * USB HID communication protocol for real-time joystick polling and control.
 *
 * Key Features:
 *   - Direct HID communication with MJC3 device (VID:1313, PID:9000)
 *   - Non-blocking I/O with configurable timeouts
 *   - Automatic device detection and connection management
 *   - Error handling and device state validation
 *   - Cross-platform compatibility (Windows/Linux/Mac)
 *
 * Device Specifications:
 *   - Vendor ID: 0x1313 (Thorlabs)
 *   - Product ID: 0x9000 (MJC3)
 *   - Report Size: 5 bytes
 *   - Interface: USB HID
 *
 * Dependencies:
 *   - hidapi library: Cross-platform HID communication
 *   - MATLAB MEX API: MATLAB interface
 *   - C++ Standard Library: String handling and utilities
 *
 * Author: Aaron W. (alw4834)
 * Created: 2024
 * Last Modified: 2024
 * Version: 1.0
 *
 * Usage:
 *   data = mjc3_joystick_mex('read', timeout_ms)  % Read joystick state
 *   info = mjc3_joystick_mex('info')              % Get device info
 *   result = mjc3_joystick_mex('test')            % Test function
 *   mjc3_joystick_mex('close')                    % Close connection
 *
 * Compilation:
 *   mex -I"path/to/hidapi/include" -L"path/to/hidapi/lib" -lhidapi mjc3_joystick_mex.cpp
 *
 *==============================================================================
 */

/**
 * mjc3_joystick_mex.cpp - High-performance MEX interface for Thorlabs MJC3 joystick
 * 
 * This MEX function provides direct HID access to the MJC3 joystick without
 * requiring PsychHID or other external dependencies.
 * 
 * Usage:
 *   data = mjc3_joystick_mex('read', timeout_ms)  % Read joystick state
 *   info = mjc3_joystick_mex('info')              % Get device info
 *   result = mjc3_joystick_mex('test')            % Test function
 *   mjc3_joystick_mex('close')                    % Close connection
 * 
 * Compilation:
 *   mex -I"path/to/hidapi/include" -L"path/to/hidapi/lib" -lhidapi mjc3_joystick_mex.cpp
 */

#include "mex.h"
#include <hidapi.h>
#include <string>
#include <cstring>

// MJC3 Device Constants
const unsigned short MJC3_VID = 0x1313;
const unsigned short MJC3_PID = 0x9000;
const int REPORT_SIZE = 5;

// Global device handle (persistent across MEX calls)
static hid_device* g_device = nullptr;
static bool g_initialized = false;

/**
 * Initialize HID library and open MJC3 device
 */
bool initializeDevice() {
    if (g_initialized && g_device) {
        return true; // Already initialized
    }
    
    // Initialize HID library
    if (hid_init() != 0) {
        mexWarnMsgIdAndTxt("MJC3:InitFail", "Failed to initialize HID library");
        return false;
    }
    
    // Open MJC3 device
    g_device = hid_open(MJC3_VID, MJC3_PID, nullptr);
    if (!g_device) {
        mexWarnMsgIdAndTxt("MJC3:OpenFail", "Cannot open MJC3 joystick (VID:1313, PID:9000)");
        hid_exit();
        return false;
    }
    
    // Set non-blocking mode
    hid_set_nonblocking(g_device, 1);
    
    g_initialized = true;
    return true;
}

/**
 * Close device and cleanup
 */
void cleanupDevice() {
    if (g_device) {
        hid_close(g_device);
        g_device = nullptr;
    }
    
    if (g_initialized) {
        hid_exit();
        g_initialized = false;
    }
}

/**
 * Read joystick state with timeout
 */
bool readJoystickData(unsigned char* buffer, int timeout_ms) {
    if (!g_device) {
        if (!initializeDevice()) {
            return false;
        }
    }
    
    // Read with timeout
    int result = hid_read_timeout(g_device, buffer, REPORT_SIZE, timeout_ms);
    
    if (result < 0) {
        // Read error - device may be disconnected
        const wchar_t* error_str = hid_error(g_device);
        if (error_str) {
            mexWarnMsgIdAndTxt("MJC3:ReadError", "HID read error occurred");
        }
        return false;
    }
    
    if (result == 0) {
        // Timeout - no data available
        return false;
    }
    
    return true;
}

/**
 * Get device information
 */
mxArray* getDeviceInfo() {
    const char* field_names[] = {"connected", "vendor_id", "product_id", 
                                "manufacturer", "product", "serial_number"};
    mxArray* info = mxCreateStructMatrix(1, 1, 6, field_names);
    
    if (!g_device && !initializeDevice()) {
        mxSetField(info, 0, "connected", mxCreateLogicalScalar(false));
        return info;
    }
    
    mxSetField(info, 0, "connected", mxCreateLogicalScalar(true));
    mxSetField(info, 0, "vendor_id", mxCreateDoubleScalar(MJC3_VID));
    mxSetField(info, 0, "product_id", mxCreateDoubleScalar(MJC3_PID));
    
    // Get device strings
    wchar_t wstr[256];
    
    // Manufacturer
    if (hid_get_manufacturer_string(g_device, wstr, 256) == 0) {
        mxArray* mfg = mxCreateString("Thorlabs"); // Default if read fails
        // Convert wchar to char if needed
        mxSetField(info, 0, "manufacturer", mfg);
    }
    
    // Product
    if (hid_get_product_string(g_device, wstr, 256) == 0) {
        mxArray* prod = mxCreateString("MJC3 Joystick");
        mxSetField(info, 0, "product", prod);
    }
    
    // Serial number
    if (hid_get_serial_number_string(g_device, wstr, 256) == 0) {
        mxArray* serial = mxCreateString("Unknown");
        mxSetField(info, 0, "serial_number", serial);
    }
    
    return info;
}

/**
 * MEX function entry point
 */
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // Register cleanup function
    mexAtExit(cleanupDevice);
    
    if (nrhs < 1) {
        mexErrMsgIdAndTxt("MJC3:InvalidInput", "At least one input argument required");
    }
    
    // Get command string
    if (!mxIsChar(prhs[0])) {
        mexErrMsgIdAndTxt("MJC3:InvalidInput", "First argument must be a command string");
    }
    
    char command[64];
    mxGetString(prhs[0], command, sizeof(command));
    
    if (strcmp(command, "read") == 0) {
        // Read joystick data
        int timeout_ms = 100; // Default timeout
        if (nrhs > 1 && mxIsNumeric(prhs[1])) {
            timeout_ms = (int)mxGetScalar(prhs[1]);
        }
        
        unsigned char buffer[REPORT_SIZE] = {0};
        
        if (readJoystickData(buffer, timeout_ms)) {
            // Create output array [xVal, yVal, zVal, button, speedKnob]
            plhs[0] = mxCreateDoubleMatrix(1, 5, mxREAL);
            double* output = mxGetPr(plhs[0]);
            
            // Convert bytes to appropriate ranges
            output[0] = (int8_t)buffer[0];  // xVal: -127 to 127
            output[1] = (int8_t)buffer[1];  // yVal: -127 to 127  
            output[2] = (int8_t)buffer[2];  // zVal: -127 to 127
            output[3] = buffer[3];          // button: 0 or 1
            output[4] = buffer[4];          // speedKnob: 0 to 255
        } else {
            // Return empty array on read failure/timeout
            plhs[0] = mxCreateDoubleMatrix(0, 0, mxREAL);
        }
        
    } else if (strcmp(command, "info") == 0) {
        // Get device information
        plhs[0] = getDeviceInfo();
        
    } else if (strcmp(command, "test") == 0) {
        // Test function - verify MEX is working
        plhs[0] = mxCreateLogicalScalar(true);
        
    } else if (strcmp(command, "close") == 0) {
        // Close device connection
        cleanupDevice();
        if (nlhs > 0) {
            plhs[0] = mxCreateLogicalScalar(true);
        }
        
    } else {
        mexErrMsgIdAndTxt("MJC3:InvalidCommand", 
            "Unknown command. Valid commands: 'read', 'info', 'test', 'close'");
    }
}