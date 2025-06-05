# ScanImage Z Control

A robust solution for Z position control in ScanImage using both direct hardware access and ScanImage API methods.

[![MATLAB](https://img.shields.io/badge/MATLAB-Compatible-blue.svg)](https://www.mathworks.com/products/matlab.html)
[![ScanImage](https://img.shields.io/badge/ScanImage-Compatible-green.svg)](https://docs.scanimage.org/)
[![Thorlabs](https://img.shields.io/badge/Thorlabs-Kinesis-orange.svg)](https://www.thorlabs.com/software_pages/viewsoftwarepage.cfm?code=Motion_Control)

## Overview

ScanImage Z Control provides a user-friendly GUI and robust backend for controlling Z position in ScanImage microscopy setups. It addresses common issues with Z control in ScanImage by implementing a hybrid approach:

1. **Direct Hardware Control**: Connects directly to Thorlabs Kinesis motors using ActiveX controls
2. **ScanImage API Integration**: Uses multiple fallback methods to work with ScanImage's native API
3. **User-Friendly GUI**: Provides intuitive controls for both manual and automated Z movement

This solution is particularly useful for microscopy setups where ScanImage's built-in Z control methods are unreliable or limited.


## Repository Structure

```
scanimage-zcontrol/
├── docs/                      # Documentation
│   ├── Hybrid_Z_Control_User_Guide.md         # User guide with installation and usage instructions
│   ├── BakingTray_Z_Control_Approach.md       # Technical analysis of BakingTray's approach
│   └── BakingTray_vs_ScanImage_Comparison.md  # Comparison of control methods
│
├── examples/                  # Example scripts and configurations
│   └── example_usage.m        # Example script demonstrating basic usage
│
├── src/                       # Source code
│   ├── launchHybridZControlGUI.m  # Main GUI launcher
│   ├── ThorlabsZControl.m         # Direct hardware control class
│   └── SIZControl.m               # ScanImage API wrapper class
│
├── tests/                     # Test scripts
│   └── test_zcontrol.m        # Basic test script
│
└── README.md                  # This file
```

## Features

- **Hybrid Control Methods**: Switch between direct hardware control and ScanImage API
- **Manual Z Movement**: Precise control with configurable step size
- **Automated Z Scanning**: Multi-step scanning with configurable parameters
- **Real-time Status Updates**: Detailed feedback on operations and errors
- **Position Tracking**: Monitors current Z position and allows return to start
- **Robust Error Handling**: Multiple fallback methods for Z control

## Requirements

- MATLAB (tested with R2019b and newer)
- ScanImage (tested with 2023.1.0)
- Thorlabs Kinesis software (matching your MATLAB's bitness - 32 or 64 bit)
- Thorlabs Kinesis-compatible Z motor (e.g., MLJ150, KDC101)

## Quick Start

1. **Installation**:
   - Clone or download this repository
   - Add the `src` directory to your MATLAB path

2. **Usage**:
   ```matlab
   % Start ScanImage
   scanimage;
   
   % Launch the Z control GUI
   launchHybridZControlGUI;
   ```

3. **Control Methods**:
   - Use the GUI to switch between direct hardware control and ScanImage API
   - Try both methods to determine which works best with your setup

## Documentation

For detailed information, please refer to the following documents:

- [User Guide](docs/Hybrid_Z_Control_User_Guide.md) - Complete installation and usage instructions
- [BakingTray Approach](docs/BakingTray_Z_Control_Approach.md) - Technical analysis of the direct hardware control method
- [ScanImage Comparison](docs/BakingTray_vs_ScanImage_Comparison.md) - Comparison of control methods and limitations

## Technical Background

This solution was developed after analyzing how the [BakingTray](https://github.com/SWC-Advanced-Microscopy/BakingTray) project successfully controls Thorlabs motors. The key insight was that BakingTray bypasses ScanImage's motor control API entirely and communicates directly with the hardware using Thorlabs APT ActiveX controls.

Our hybrid approach combines this direct hardware access with attempts to use ScanImage's API where possible, giving you the best of both worlds.

## Troubleshooting

Common issues and solutions:

1. **Connection Failures**:
   - Ensure Thorlabs Kinesis software is installed and matches your MATLAB bitness
   - Verify the motor is connected and powered on
   - Check that the motor can be controlled through Thorlabs Kinesis software

2. **Movement Errors**:
   - Try switching between direct hardware and ScanImage API control
   - Check status messages for specific error information
   - Verify motor limits are set correctly in your MDF file

3. **ActiveX Errors**:
   - Run MATLAB as administrator
   - Reinstall Thorlabs Kinesis software
   - Ensure MATLAB and Kinesis software bitness match (both 32-bit or both 64-bit)

For more detailed troubleshooting, see the [User Guide](docs/Hybrid_Z_Control_User_Guide.md).

## Customization

The solution can be customized by modifying:

- Default step size and movement parameters
- Position limits and safety checks
- GUI layout and controls
- Debug verbosity levels

See code comments for specific customization points.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [BakingTray](https://github.com/SWC-Advanced-Microscopy/BakingTray) project for inspiration on direct hardware control
- [ScanImage](https://docs.scanimage.org/) documentation and examples
- [Thorlabs](https://www.thorlabs.com/) for motor control libraries and documentation

## Support

For issues, questions, or contributions, please contact the repository maintainer.
