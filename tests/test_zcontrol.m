function test_zcontrol
% Basic test script for ScanImage Z Control
%
% This script tests the basic functionality of both Z control methods
% (direct hardware and ScanImage API) to verify proper operation.

%% Test Direct Hardware Control
fprintf('Testing ThorlabsZControl (Direct Hardware Control)...\n');

try
    % Create control object
    z = ThorlabsZControl();
    
    % Check connection
    if z.isConnected
        fprintf('✓ Successfully connected to Thorlabs Z motor\n');
        
        % Get current position
        pos = z.getCurrentPosition();
        fprintf('✓ Current Z position: %.2f\n', pos);
        
        % Test relative movement
        fprintf('Testing relative movement...\n');
        success = z.moveRelative(1.0);  % Move 1 µm up
        if success
            fprintf('✓ Relative movement successful\n');
        else
            fprintf('✗ Relative movement failed\n');
        end
        
        % Test absolute movement
        fprintf('Testing absolute movement...\n');
        success = z.moveAbsolute(pos);  % Move back to original position
        if success
            fprintf('✓ Absolute movement successful\n');
        else
            fprintf('✗ Absolute movement failed\n');
        end
    else
        fprintf('✗ Failed to connect to Thorlabs Z motor\n');
    end
    
    % Clean up
    delete(z);
    fprintf('✓ ThorlabsZControl test complete\n\n');
catch ME
    fprintf('✗ Error in ThorlabsZControl test: %s\n', ME.message);
end

%% Test ScanImage API Control
fprintf('Testing SIZControl (ScanImage API)...\n');

try
    % Check if ScanImage is running
    try
        hSI = evalin('base', 'hSI');
        if isempty(hSI)
            fprintf('✗ ScanImage is not running or hSI is empty\n');
            return;
        end
    catch
        fprintf('✗ ScanImage is not running\n');
        return;
    end
    
    % Create control object
    z = SIZControl(@(msg) fprintf('%s\n', msg));
    fprintf('✓ SIZControl object created\n');
    
    % Get current position
    pos = z.getCurrentZPosition();
    fprintf('✓ Current Z position: %.2f\n', pos);
    
    % Test relative movement
    fprintf('Testing moveUp...\n');
    success = z.moveUp();
    if success
        fprintf('✓ moveUp successful\n');
    else
        fprintf('✗ moveUp failed\n');
    end
    
    % Test relative movement
    fprintf('Testing moveDown...\n');
    success = z.moveDown();
    if success
        fprintf('✓ moveDown successful\n');
    else
        fprintf('✗ moveDown failed\n');
    end
    
    % Clean up
    delete(z);
    fprintf('✓ SIZControl test complete\n');
catch ME
    fprintf('✗ Error in SIZControl test: %s\n', ME.message);
end

fprintf('\nTest complete. Check results above for any failures.\n');
