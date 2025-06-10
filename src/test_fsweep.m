%% Test FocalSweep with different verbosity settings
% This script tests the FocalSweep tool with different verbosity levels
% to verify the warning suppression is working correctly.

fprintf('===== Testing FocalSweep with normal verbosity =====\n');
fprintf('You should see warnings if ScanImage is not properly initialized\n\n');

% Launch with normal verbosity
fs1 = fsweep();
pause(1);
close(fs1.hFig);
clear fs1;

fprintf('\n\n===== Testing FocalSweep with quiet mode =====\n');
fprintf('You should NOT see any warnings\n\n');

% Launch in quiet mode
fs2 = fsweep('quiet');
pause(1);
close(fs2.hFig);
clear fs2;

fprintf('\n\nTest completed.\n'); 