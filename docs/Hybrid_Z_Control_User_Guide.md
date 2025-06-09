# ScanImage Z Control - User Guide

## Overview

This solution provides robust, programmatic control of the Z position in ScanImage by directly interfacing with the ScanImage Motor Controls GUI. It is compatible with any ScanImage setup, including those using Thorlabs Kinesis motors, and avoids hardware conflicts by using the same GUI controls as the user.

## Files Included

- **SI_MotorGUI_ZControl.m** — Main class for controlling Z via the ScanImage Motor Controls GUI

## Installation

1. Copy `SI_MotorGUI_ZControl.m` to a directory in your MATLAB path (e.g., `src/`)
2. Start ScanImage as usual and ensure the Motor Controls GUI is open

## Usage

1. In MATLAB, create the controller:
   ```matlab
   z = SI_MotorGUI_ZControl();
   ```
2. Read the current Z position:
   ```matlab
   z.getZ()
   ```
3. Set the step size (e.g., 5 µm):
   ```matlab
   z.setStepSize(5);
   ```
4. Move up or down by one step:
   ```matlab
   z.moveUp();
   z.moveDown();
   ```
5. Move by a relative distance (e.g., +20 µm or -10 µm):
   ```matlab
   z.relativeMove(20);   % Up 20 µm
   z.relativeMove(-10);  % Down 10 µm
   ```
6. Move to an absolute Z position (e.g., 12000 µm):
   ```matlab
   z.absoluteMove(12000);
   ```

## Features

- **No hardware conflicts**: Uses ScanImage's own GUI controls
- **Robust**: Works with any ScanImage-supported motor
- **Scriptable**: Automate Z movement, focus routines, or integrate into your own GUIs

## Troubleshooting

- Ensure the Motor Controls GUI is open in ScanImage
- If you get errors about missing controls, close and reopen the Motor Controls GUI
- If Z does not move, check that ScanImage is not busy/acquiring

## Advanced: Automated Z Scanning (Next Step)

You can use the `relativeMove` and `absoluteMove` methods in a loop to perform automated Z scanning, e.g.:

```matlab
z = SI_MotorGUI_ZControl();
startZ = z.getZ();
step = 2; % µm
nSteps = 20;
for i = 1:nSteps
    z.relativeMove(step);
    pause(0.2); % adjust as needed
    % Insert your image acquisition or focus metric code here
end
z.absoluteMove(startZ); % Return to start
```

## Customization
- Change the default step size in your scripts
- Integrate with image acquisition or autofocus routines

## Support
If you encounter issues or need further customization, please provide:
1. Specific error messages
2. Your ScanImage version
3. Screenshots of the Motor Controls GUI
