% Test script for bookmark metadata integration
% This script demonstrates how bookmarks are now saved to the imaging metadata

fprintf('=== Bookmark Metadata Integration Test ===\n\n');

% Start the application
fprintf('Starting FoilView application...\n');
app = foilview();

% Wait a moment for initialization
pause(2);

% Initialize metadata logging
fprintf('\nInitializing metadata logging...\n');
% Simulate clicking the metadata button by calling the private method
app.onMetadataButtonPushed();

% Wait for metadata setup
pause(1);

% Test bookmark creation
fprintf('\nCreating test bookmarks...\n');

% Create a bookmark with a custom label
fprintf('Creating bookmark: "Test Position 1"\n');
app.Controller.markCurrentPosition('Test Position 1');

pause(1);

% Create another bookmark with auto-generated label
fprintf('Creating bookmark with auto-generated label\n');
app.Controller.markCurrentPosition('Auto Bookmark');

pause(1);

% Move to a different position and create another bookmark
fprintf('Moving to new position and creating bookmark...\n');
app.Controller.moveStageManual(10, 1); % Move up 10 μm
pause(1);
app.Controller.markCurrentPosition('High Position');

pause(1);

% Create a bookmark for maximum metric value
fprintf('Creating maximum metric bookmark...\n');
app.Controller.BookmarkManager.updateMax('Std Dev', 45.2, app.Controller.CurrentXPosition, app.Controller.CurrentYPosition, app.Controller.CurrentPosition);

fprintf('\n=== Test Complete ===\n');
fprintf('Check the metadata file for bookmark entries with the following columns:\n');
fprintf('- BookmarkLabel: The label of the bookmark\n');
fprintf('- BookmarkMetricType: Type of metric (e.g., "Std Dev")\n');
fprintf('- BookmarkMetricValue: Value of the metric\n');
fprintf('\nRegular metadata entries will have empty bookmark fields.\n');
fprintf('Bookmark entries will have populated bookmark fields.\n');

% Keep the application open for inspection
fprintf('\nApplication will remain open for inspection.\n');
fprintf('Close the application window when done.\n'); 