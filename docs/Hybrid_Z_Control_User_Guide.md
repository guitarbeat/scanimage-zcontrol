# Hybrid Z Control for ScanImage - User Guide

## Overview

This hybrid Z control solution provides a user-friendly GUI for controlling Z position in ScanImage, using both direct hardware control (via Thorlabs Kinesis ActiveX) and ScanImage API methods where available. The solution is specifically tailored for your setup with Thorlabs Kinesis motors.

## Files Included

1. **launchHybridZControlGUI.m** - The main GUI launcher script
2. **ThorlabsZControl.m** - Direct hardware control class for Thorlabs Kinesis motors
3. **SIZControl.m** - ScanImage API wrapper class for Z control

## Installation

1. Copy all three files to a directory in your MATLAB path
2. Ensure Thorlabs APT/Kinesis software is installed on your system
   - The software version (32-bit/64-bit) must match your MATLAB version
   - Default installation path: `C:\Program Files\Thorlabs\Kinesis`

## Usage

1. Start ScanImage as usual
2. Run the following command in MATLAB:
   ```matlab
   launchHybridZControlGUI
   ```
3. The GUI will appear with controls for Z movement

## GUI Features

### Manual Control
- **Move Up/Down**: Move Z position by the specified step size
- **Step Size**: Adjust the distance for each step (in µm)
- **Go to Z**: Move directly to a specific Z position
- **Update Position**: Refresh the current Z position display

### Automated Scanning
- **Number of Steps**: How many steps to take during automated scanning
- **Delay Between Steps**: Time to wait between steps (in seconds)
- **Direction**: Choose to scan upward or downward
- **Start Scan**: Begin automated Z scanning
- **Stop**: Halt the current scan
- **Return to Start**: Go back to the position where scanning began

### Configuration
- **Z Control Method**: Choose between direct hardware control and ScanImage API
  - **Direct Hardware Control**: Uses Thorlabs ActiveX to control motors directly
  - **ScanImage API**: Attempts to use ScanImage's built-in Z control methods
- **Debug Level**: Adjust the verbosity of status messages

## Troubleshooting

### Connection Issues
- If the GUI fails to connect to your Thorlabs motor:
  1. Verify the motor is powered on and connected via USB
  2. Check that Thorlabs Kinesis software can control the motor
  3. Ensure the correct serial number is detected (shown in status messages)
  4. Try restarting MATLAB and ScanImage

### Movement Issues
- If Z movement fails:
  1. Try switching between Direct Hardware Control and ScanImage API
  2. Check the status messages for specific error information
  3. Verify motor limits are set correctly in your MDF file
  4. Try smaller step sizes for more reliable movement

### ActiveX Errors
- If you see ActiveX-related errors:
  1. Ensure Thorlabs Kinesis software is installed correctly
  2. Check that the MATLAB bitness (32/64-bit) matches the Kinesis installation
  3. Try running MATLAB as administrator

## Technical Details

### Direct Hardware Control
The `ThorlabsZControl` class connects directly to your Thorlabs Kinesis motor using ActiveX controls, bypassing ScanImage's motor control system. This approach is based on the method used in BakingTray, which successfully controls Thorlabs motors independently of ScanImage.

### ScanImage API Control
The `SIZControl` class attempts to use various methods in the ScanImage API to control Z position:
1. First tries using `hSI.hMotors.moveXYZ`
2. Falls back to `hSI.hStackManager.zPosition`
3. Tries `hSI.hFastZ.positionTarget`
4. Attempts to access the Z motor directly through `hMotorXYZ{3}`

### Hybrid Approach
The GUI allows you to switch between these methods, so you can use whichever works best with your specific hardware configuration.

## Customization

You can modify the following parameters in the code:
- Default step size
- Movement velocity and acceleration (in ThorlabsZControl.m)
- Position limits (in ThorlabsZControl.m)
- Debug verbosity levels

## Support

If you encounter issues or need further customization, please provide:
1. Specific error messages from the status window
2. Your ScanImage version
3. Your Thorlabs Kinesis software version
4. Screenshots of any error dialogs
