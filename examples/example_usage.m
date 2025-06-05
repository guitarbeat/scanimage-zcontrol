% Example usage of ScanImage Z Control
%
% This script demonstrates how to use the ScanImage Z Control tools
% both programmatically and through the GUI.

%% Basic Usage - GUI
% The simplest way to use ScanImage Z Control is through the GUI:
%
% launchHybridZControlGUI;
%
% This will open the graphical interface for controlling Z position.

%% Programmatic Usage - Direct Hardware Control
% For programmatic control using direct hardware access:

% Create a ThorlabsZControl object
z = ThorlabsZControl();

% Check if connected successfully
if z.isConnected
    % Get current position
    currentPos = z.getCurrentPosition();
    fprintf('Current Z position: %.2f\n', currentPos);
    
    % Move to an absolute position
    z.moveAbsolute(currentPos + 10);  % Move 10 µm up
    
    % Move by a relative distance
    z.moveRelative(-5);  % Move 5 µm down
    
    % Clean up when done
    delete(z);
else
    fprintf('Failed to connect to Thorlabs Z motor\n');
end

%% Programmatic Usage - ScanImage API
% For programmatic control using ScanImage API:

% Create a SIZControl object with a status callback
z = SIZControl(@(msg) fprintf('%s\n', msg));

% Get current position
currentPos = z.getCurrentZPosition();
fprintf('Current Z position: %.2f\n', currentPos);

% Move up by one step
z.moveUp();

% Move down by one step
z.moveDown();

% Move to an absolute position
z.absoluteMove(currentPos + 10);

% Start automated Z movement
z.numSteps = 10;
z.delayBetweenSteps = 0.5;
z.direction = 1;  % 1=up, -1=down
z.startZMovement();

% Wait for movement to complete
pause(z.numSteps * z.delayBetweenSteps + 1);

% Return to starting position
z.returnToStart();

% Clean up when done
delete(z);
