# BakingTray's Approach to Thorlabs Kinesis Z Control

After reviewing the BakingTray repository, I've identified how they successfully control Thorlabs Kinesis motors for Z positioning, which differs significantly from attempting to use the ScanImage API.

## Key Findings

1. **Direct Hardware Integration**: BakingTray bypasses ScanImage's motor control API entirely and instead communicates directly with the Thorlabs hardware using:
   - Thorlabs APT ActiveX controls
   - Custom MATLAB wrapper classes for each controller type

2. **Controller Class Hierarchy**:
   - Abstract base class: `linearcontroller`
   - Specific implementation: `BSC201_APT` (for Thorlabs BSC201 controllers)
   - Other Thorlabs controllers: C663, C863, C891, etc.

3. **Connection Method**:
   - Creates an ActiveX control in a hidden MATLAB figure
   - Connects directly to the hardware via USB
   - Uses Thorlabs-specific commands rather than ScanImage API calls

4. **Z Movement Implementation**:
   - Direct hardware commands via ActiveX
   - Handles position limits, homing, and error checking
   - Completely independent of ScanImage's motor control system

## Code Structure

The key components in BakingTray's implementation:

1. **`buildMotionComponent.m`**: Factory function that creates the appropriate controller object based on hardware type

2. **`BSC201_APT.m`**: Thorlabs-specific controller class that:
   - Creates ActiveX connection to hardware
   - Implements movement methods (absoluteMove, relativeMove)
   - Handles position tracking and limits

3. **Hardware Abstraction Layer**:
   - Each controller type has its own class
   - Common interface through the `linearcontroller` base class
   - Allows for easy swapping of hardware without changing higher-level code

## ActiveX Integration

The critical part of BakingTray's approach is using ActiveX to communicate directly with Thorlabs hardware:

```matlab
% Create the ActiveX control in a figure
obj.figH = figure('Visible', 'off');
obj.hC = actxcontrol('MGMOTOR.MGMotorCtrl.1', [0,0,1,1], obj.figH);
obj.hC.StartCtrl;
set(obj.hC, 'HWSerialNum', obj.controllerID);

% Move to position using ActiveX methods
obj.hC.SetAbsMovePos(0, targetPosition);
obj.hC.MoveAbsolute(0, 0);
```

This approach completely bypasses ScanImage's motor control system, which explains why it works when ScanImage's API methods fail.

## Implications for User's Setup

The key insight is that BakingTray doesn't try to use ScanImage's Z control API at all - it creates a parallel, independent control path directly to the hardware. This explains why our attempts to use ScanImage's API methods failed, as those methods may not be properly implemented or connected to the actual hardware in the user's setup.
