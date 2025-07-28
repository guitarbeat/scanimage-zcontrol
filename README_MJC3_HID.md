## MJC3 Joystick Integration

This project includes a class `MJC3_HID_Controller` for using a Thorlabs MJC3 joystick as an input device for ScanImage Z‑control.

### Prerequisites

* Psychtoolbox installed in MATLAB (provides the PsychHID functions).
* A Z‑control object that exposes a `relativeMove(dz)` method (e.g. `SI_MotorGUI_ZControl`).

### Usage

1. Place `MJC3_HID_Controller.m` somewhere on your MATLAB path.
2. Create or access your existing Z‑control object:
   ```matlab
   zCtrl = SI_MotorGUI_ZControl(); % or whatever class you use
