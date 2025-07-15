% Simple test for bookmark metadata integration
% This script demonstrates how bookmarks are saved to the imaging metadata

fprintf('=== Simple Bookmark Metadata Test ===\n\n');

% Start the application
fprintf('Starting FoilView application...\n');
app = foilview();

% Wait a moment for initialization
pause(2);

% Test bookmark creation directly through the controller
fprintf('\nCreating test bookmarks...\n');

% Create a bookmark with a custom label
fprintf('Creating bookmark: "Test Position 1"\n');
app.Controller.markCurrentPosition('Test Position 1');

pause(1);

% Create another bookmark
fprintf('Creating bookmark: "Test Position 2"\n');
app.Controller.markCurrentPosition('Test Position 2');

pause(1);

% Create a bookmark for maximum metric value
fprintf('Creating maximum metric bookmark...\n');
app.Controller.BookmarkManager.updateMax('Std Dev', 45.2, app.Controller.CurrentXPosition, app.Controller.CurrentYPosition, app.Controller.CurrentPosition);

fprintf('\n=== Test Complete ===\n');
fprintf('Bookmarks have been created.\n');
fprintf('To see them in metadata, click the metadata button (📝) in the application.\n');
fprintf('Then check the generated CSV file for bookmark entries.\n');

% Keep the application open
fprintf('\nApplication will remain open for inspection.\n');
fprintf('Close the application window when done.\n'); 