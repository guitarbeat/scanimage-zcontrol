# Comparison: BakingTray vs. ScanImage API for Z Control

After analyzing both BakingTray's approach and the user's ScanImage setup, I've identified key differences that explain why Z control is failing in the user's environment.

## ScanImage API Limitations

1. **Indirect Hardware Access**:
   - ScanImage attempts to abstract hardware control through its own API
   - The diagnostic logs show that none of the standard ScanImage Z control methods work with the user's Thorlabs Kinesis motors
   - Error code -50103 indicates resource conflicts with the DAQ hardware

2. **Missing Implementation**:
   - The user's diagnostic logs show that the Thorlabs KinesisMotor object lacks a `moveToPosition` method
   - ScanImage doesn't expose the necessary methods to control Thorlabs motors programmatically
   - The Z motor is recognized (as shown by `lastKnownPosition` working) but can't be controlled

3. **Resource Conflicts**:
   - ScanImage appears to be using NI-DAQmx resources that conflict with direct motor control
   - The "resource is reserved" error suggests ScanImage has locked the hardware in a way that prevents other access

## BakingTray's Superior Approach

1. **Direct Hardware Communication**:
   - BakingTray bypasses ScanImage's motor control API entirely
   - Uses Thorlabs APT ActiveX controls to communicate directly with the hardware
   - No dependency on ScanImage's implementation of motor control

2. **Independent Control Path**:
   - Creates a separate, parallel control path to the hardware
   - Doesn't rely on or interfere with ScanImage's hardware access
   - Avoids resource conflicts by using a different communication channel

3. **Custom Hardware Abstraction**:
   - Implements a complete hardware abstraction layer with custom classes
   - Each controller type has its own implementation with hardware-specific commands
   - Provides a consistent interface regardless of underlying hardware

## Key Insight

The fundamental difference is that **BakingTray doesn't try to use ScanImage for Z control at all**. Instead, it:

1. Creates its own connection to the hardware
2. Uses vendor-specific SDK calls (via ActiveX)
3. Manages position tracking and limits independently

This explains why our attempts to use ScanImage's API methods failed - those methods aren't properly implemented or connected to the actual hardware in the user's setup.

## Implications

To achieve Z control in the user's environment, we need to:

1. Abandon attempts to use ScanImage's Z control API
2. Implement direct hardware control using Thorlabs APT ActiveX (similar to BakingTray)
3. Create a simple, independent control path that doesn't interfere with ScanImage's operation
