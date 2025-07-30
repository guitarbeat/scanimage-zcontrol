function migrate_architecture()
    % migrate_architecture - Migrate the src directory to improved architecture
    % This script helps implement the architectural improvements outlined in
    % ARCHITECTURE_IMPROVEMENT_PLAN.md step by step
    
    fprintf('=== FoilView Architecture Migration Tool ===\n\n');
    
    % Get user input for migration phase
    fprintf('Available migration phases:\n');
    fprintf('1. Create new directory structure\n');
    fprintf('2. Extract interfaces\n');
    fprintf('3. Implement repository pattern\n');
    fprintf('4. Split large services\n');
    fprintf('5. Split large controllers\n');
    fprintf('6. Split large views\n');
    fprintf('7. Organize utilities\n');
    fprintf('8. Full migration (all phases)\n\n');
    
    phase = input('Enter phase number (1-8): ');
    
    switch phase
        case 1
            create_directory_structure();
        case 2
            extract_interfaces();
        case 3
            implement_repository_pattern();
        case 4
            split_large_services();
        case 5
            split_large_controllers();
        case 6
            split_large_views();
        case 7
            organize_utilities();
        case 8
            full_migration();
        otherwise
            fprintf('Invalid phase number. Exiting.\n');
            return;
    end
    
    fprintf('\n=== Migration completed successfully! ===\n');
end

function create_directory_structure()
    % Create new directory structure for improved architecture
    
    fprintf('Creating new directory structure...\n');
    
    % Define new directories to create
    new_dirs = {
        'interfaces',
        'repositories', 
        'strategies',
        'models',
        'commands',
        'services/core',
        'services/infrastructure',
        'services/external',
        'controllers/core',
        'controllers/ui',
        'controllers/coordination',
        'views/components',
        'views/layouts',
        'views/builders',
        'utils/core',
        'utils/file',
        'utils/ui',
        'utils/external'
    };
    
    % Create directories
    for i = 1:length(new_dirs)
        dir_path = fullfile('src', new_dirs{i});
        if ~exist(dir_path, 'dir')
            mkdir(dir_path);
            fprintf('  ✅ Created: %s\n', dir_path);
        else
            fprintf('  ⚠️  Exists: %s\n', dir_path);
        end
    end
    
    % Create README files for new directories
    create_readme_files();
    
    fprintf('Directory structure created successfully!\n');
end

function create_readme_files()
    % Create README files for new directories
    
    readme_content = {
        'interfaces', 'Abstract contracts and interfaces for the application layers';
        'repositories', 'Data access layer implementing repository pattern';
        'strategies', 'Pluggable strategy implementations for controllers';
        'models', 'Domain models representing core business entities';
        'commands', 'Command pattern implementations for operations';
        'services/core', 'Core business logic services';
        'services/infrastructure', 'Infrastructure and utility services';
        'services/external', 'External system integration services';
        'controllers/core', 'Core business logic controllers';
        'controllers/ui', 'UI-specific controllers';
        'controllers/coordination', 'High-level coordination controllers';
        'views/components', 'Reusable UI components';
        'views/layouts', 'Layout managers for UI organization';
        'views/builders', 'UI builders and factories';
        'utils/core', 'Core utility functions';
        'utils/file', 'File and path operation utilities';
        'utils/ui', 'UI-related utility functions';
        'utils/external', 'External system utility functions'
    };
    
    for i = 1:size(readme_content, 1)
        dir_name = readme_content{i, 1};
        description = readme_content{i, 2};
        
        readme_path = fullfile('src', dir_name, 'README.md');
        if ~exist(readme_path, 'file')
            fid = fopen(readme_path, 'w');
            fprintf(fid, '# %s\n\n', upper(dir_name));
            fprintf(fid, '%s\n\n', description);
            fprintf(fid, '## Purpose\n\n');
            fprintf(fid, 'This directory contains %s.\n\n', lower(description));
            fprintf(fid, '## Files\n\n');
            fprintf(fid, '- (Files will be listed here as they are created)\n');
            fclose(fid);
            fprintf('  ✅ Created README: %s\n', readme_path);
        end
    end
end

function extract_interfaces()
    % Extract interfaces for major components
    
    fprintf('Extracting interfaces...\n');
    
    % Define interfaces to create
    interfaces = {
        'IStageController', {'moveTo(x, y, z)', 'getPosition()', 'isMoving()'};
        'IScanController', {'startScan()', 'stopScan()', 'getScanStatus()'};
        'IMetadataService', {'logPosition(x, y, z)', 'logScan(scanData)', 'getSessionStats()'};
        'IErrorHandler', {'handleError(error)', 'logError(error)', 'notifyUser(message)'};
        'IFileRepository', {'write(data, path)', 'read(path)', 'exists(path)'};
        'IControllerStrategy', {'createController(zController, stepFactor)', 'isAvailable()'};
        'ICommand', {'execute()', 'undo()'};
        'IStageService', {'moveTo(x, y, z)', 'getPosition()', 'isMoving()', 'stop()'};
        'IScanService', {'startScan(params)', 'stopScan()', 'getStatus()', 'getResults()'};
        'IMetricService', {'calculateMetric(data)', 'getMetrics()', 'clearMetrics()'};
        'INotificationService', {'notify(message)', 'showDialog(title, message)', 'log(message)'};
        'IConfigurationService', {'get(key)', 'set(key, value)', 'load()', 'save()'};
        'ILoggingService', {'log(level, message)', 'error(message)', 'warning(message)', 'info(message)'};
        'IStageView', {'updatePosition(x, y, z)', 'showError(message)', 'enableControls(enable)'};
        'IBookmarkView', {'addBookmark(bookmark)', 'removeBookmark(id)', 'updateBookmarks()'};
        'IMetricView', {'updateMetrics(metrics)', 'showPlot(data)', 'clearPlot()'};
        'IComponentBuilder', {'createComponent(parent, config)', 'updateComponent(component, data)'};
        'ILayoutBuilder', {'createLayout(parent, config)', 'updateLayout(layout, config)'};
        'IStyleBuilder', {'applyStyle(component, style)', 'createStyle(config)'};
        'IValidationUtils', {'validatePosition(x, y, z)', 'validateScanParams(params)', 'validateMetadata(metadata)'};
        'IConversionUtils', {'convertUnits(value, fromUnit, toUnit)', 'formatNumber(value, precision)'};
        'IMathUtils', {'calculateDistance(pos1, pos2)', 'interpolate(points)', 'fitCurve(data)'};
        'IFileUtils', {'readFile(path)', 'writeFile(path, data)', 'deleteFile(path)'};
        'IPathUtils', {'joinPath(parts)', 'getDirectory(path)', 'getFilename(path)'};
        'IConfigUtils', {'loadConfig(path)', 'saveConfig(config, path)', 'validateConfig(config)'};
        'IStyleUtils', {'createColor(hex)', 'createFont(size, weight)', 'createBorder(style)'};
        'ILayoutUtils', {'createGrid(rows, cols)', 'createPanel(parent)', 'createButton(parent, text)'};
        'IComponentUtils', {'createLabel(parent, text)', 'createEditField(parent)', 'createButton(parent, text)'};
        'IScanImageUtils', {'connectToScanImage()', 'getScanImageData()', 'sendCommand(command)'};
        'IHardwareUtils', {'detectHardware()', 'testConnection()', 'getHardwareInfo()'}
    };
    
    % Create interface files
    for i = 1:size(interfaces, 1)
        interface_name = interfaces{i, 1};
        methods = interfaces{i, 2};
        
        interface_path = fullfile('src', 'interfaces', [interface_name '.m']);
        if ~exist(interface_path, 'file')
            create_interface_file(interface_path, interface_name, methods);
            fprintf('  ✅ Created interface: %s\n', interface_name);
        else
            fprintf('  ⚠️  Exists: %s\n', interface_name);
        end
    end
    
    fprintf('Interfaces extracted successfully!\n');
end

function create_interface_file(filepath, interface_name, methods)
    % Create an interface file with the specified methods
    
    fid = fopen(filepath, 'w');
    
    fprintf(fid, 'classdef %s < handle\n', interface_name);
    fprintf(fid, '    %% %s - Abstract interface for %s\n', interface_name, lower(interface_name(2:end)));
    fprintf(fid, '    %% This interface defines the contract for %s implementations\n\n', lower(interface_name(2:end)));
    
    fprintf(fid, '    methods (Abstract)\n');
    
    for i = 1:length(methods)
        method = methods{i};
        fprintf(fid, '        %s\n', method);
    end
    
    fprintf(fid, '    end\n');
    fprintf(fid, 'end\n');
    
    fclose(fid);
end

function implement_repository_pattern()
    % Implement repository pattern for data access
    
    fprintf('Implementing repository pattern...\n');
    
    % Define repositories to create
    repositories = {
        'MetadataRepository', 'IMetadataRepository';
        'ConfigurationRepository', 'IConfigurationRepository';
        'BookmarkRepository', 'IBookmarkRepository';
        'FileRepository', 'IFileRepository';
        'ScanRepository', 'IScanRepository';
        'LogRepository', 'ILogRepository'
    };
    
    % Create repository files
    for i = 1:size(repositories, 1)
        repo_name = repositories{i, 1};
        interface_name = repositories{i, 2};
        
        repo_path = fullfile('src', 'repositories', [repo_name '.m']);
        if ~exist(repo_path, 'file')
            create_repository_file(repo_path, repo_name, interface_name);
            fprintf('  ✅ Created repository: %s\n', repo_name);
        else
            fprintf('  ⚠️  Exists: %s\n', repo_name);
        end
    end
    
    fprintf('Repository pattern implemented successfully!\n');
end

function create_repository_file(filepath, repo_name, interface_name)
    % Create a repository file implementing the specified interface
    
    fid = fopen(filepath, 'w');
    
    fprintf(fid, 'classdef %s < %s\n', repo_name, interface_name);
    fprintf(fid, '    %% %s - Repository implementation for %s\n', repo_name, lower(repo_name(1:end-10)));
    fprintf(fid, '    %% This repository handles data access for %s\n\n', lower(repo_name(1:end-10)));
    
    fprintf(fid, '    methods\n');
    fprintf(fid, '        function obj = %s()\n', repo_name);
    fprintf(fid, '            %% Constructor\n');
    fprintf(fid, '        end\n\n');
    
    fprintf(fid, '        %% Implementation of interface methods\n');
    fprintf(fid, '        %% TODO: Implement abstract methods from %s\n', interface_name);
    fprintf(fid, '    end\n');
    fprintf(fid, 'end\n');
    
    fclose(fid);
end

function split_large_services()
    % Split large services into focused components
    
    fprintf('Splitting large services...\n');
    
    % Define service splits
    service_splits = {
        'ApplicationInitializer', {'InitializationService', 'ConfigurationService', 'UISetupService'};
        'StageControlService', {'StageMovementService', 'StagePositionService', 'StageCalibrationService'};
        'MetricCalculationService', {'MetricComputationService', 'MetricStorageService', 'MetricAnalysisService'};
        'UserNotificationService', {'DialogService', 'LoggingService', 'StatusService'};
        'ErrorHandlerService', {'ErrorLoggingService', 'ErrorReportingService', 'ErrorRecoveryService'};
        'ScanControlService', {'ScanExecutionService', 'ScanValidationService', 'ScanMonitoringService'};
        'MetricsPlotService', {'PlotCreationService', 'PlotUpdateService', 'PlotExportService'}
    };
    
    % Create split service files
    for i = 1:size(service_splits, 1)
        original_service = service_splits{i, 1};
        new_services = service_splits{i, 2};
        
        fprintf('  📋 Splitting %s into:\n', original_service);
        for j = 1:length(new_services)
            service_name = new_services{j};
            service_path = fullfile('src', 'services', 'core', [service_name '.m']);
            
            if ~exist(service_path, 'file')
                create_service_file(service_path, service_name);
                fprintf('    ✅ Created: %s\n', service_name);
            else
                fprintf('    ⚠️  Exists: %s\n', service_name);
            end
        end
    end
    
    fprintf('Large services split successfully!\n');
end

function create_service_file(filepath, service_name)
    % Create a service file
    
    fid = fopen(filepath, 'w');
    
    fprintf(fid, 'classdef %s < handle\n', service_name);
    fprintf(fid, '    %% %s - Service for %s\n', service_name, lower(service_name(1:end-7)));
    fprintf(fid, '    %% This service handles %s functionality\n\n', lower(service_name(1:end-7)));
    
    fprintf(fid, '    properties (Access = private)\n');
    fprintf(fid, '        %% TODO: Add private properties\n');
    fprintf(fid, '    end\n\n');
    
    fprintf(fid, '    methods\n');
    fprintf(fid, '        function obj = %s()\n', service_name);
    fprintf(fid, '            %% Constructor\n');
    fprintf(fid, '        end\n\n');
    
    fprintf(fid, '        %% TODO: Implement service methods\n');
    fprintf(fid, '    end\n');
    fprintf(fid, 'end\n');
    
    fclose(fid);
end

function split_large_controllers()
    % Split large controllers into focused components
    
    fprintf('Splitting large controllers...\n');
    
    % Define controller splits
    controller_splits = {
        'FoilviewController', {'StageController', 'ScanController', 'BookmarkController', 'ApplicationController'};
        'UIController', {'MainUIController', 'StageUIController', 'BookmarkUIController', 'MetricUIController'};
        'HIDController', {'JoystickController', 'KeyboardController', 'DeviceController'};
        'ScanImageZController', {'ZPositionController', 'ZCalibrationController', 'ZValidationController'}
    };
    
    % Create split controller files
    for i = 1:size(controller_splits, 1)
        original_controller = controller_splits{i, 1};
        new_controllers = controller_splits{i, 2};
        
        fprintf('  📋 Splitting %s into:\n', original_controller);
        for j = 1:length(new_controllers)
            controller_name = new_controllers{j};
            
            % Determine appropriate subdirectory
            if contains(controller_name, 'UI')
                controller_path = fullfile('src', 'controllers', 'ui', [controller_name '.m']);
            else
                controller_path = fullfile('src', 'controllers', 'core', [controller_name '.m']);
            end
            
            if ~exist(controller_path, 'file')
                create_controller_file(controller_path, controller_name);
                fprintf('    ✅ Created: %s\n', controller_name);
            else
                fprintf('    ⚠️  Exists: %s\n', controller_name);
            end
        end
    end
    
    fprintf('Large controllers split successfully!\n');
end

function create_controller_file(filepath, controller_name)
    % Create a controller file
    
    fid = fopen(filepath, 'w');
    
    fprintf(fid, 'classdef %s < handle\n', controller_name);
    fprintf(fid, '    %% %s - Controller for %s\n', controller_name, lower(controller_name(1:end-10)));
    fprintf(fid, '    %% This controller handles %s coordination\n\n', lower(controller_name(1:end-10)));
    
    fprintf(fid, '    properties (Access = private)\n');
    fprintf(fid, '        %% TODO: Add private properties\n');
    fprintf(fid, '    end\n\n');
    
    fprintf(fid, '    methods\n');
    fprintf(fid, '        function obj = %s()\n', controller_name);
    fprintf(fid, '            %% Constructor\n');
    fprintf(fid, '        end\n\n');
    
    fprintf(fid, '        %% TODO: Implement controller methods\n');
    fprintf(fid, '    end\n');
    fprintf(fid, 'end\n');
    
    fclose(fid);
end

function split_large_views()
    % Split large views into focused components
    
    fprintf('Splitting large views...\n');
    
    % Define view splits
    view_splits = {
        'StageView', {'StagePositionComponent', 'StageControlComponent', 'StageStatusComponent'};
        'UiBuilder', {'ComponentBuilder', 'LayoutBuilder', 'StyleBuilder'};
        'UiComponents', {'ButtonComponents', 'PanelComponents', 'FieldComponents'};
        'BookmarksView', {'BookmarkListComponent', 'BookmarkEditComponent', 'BookmarkSearchComponent'};
        'MJC3View', {'MJC3StatusComponent', 'MJC3ControlComponent', 'MJC3ConfigComponent'};
        'ToolsWindow', {'ToolPanelComponent', 'ToolButtonComponent', 'ToolStatusComponent'};
        'PlotManager', {'PlotDisplayComponent', 'PlotControlComponent', 'PlotExportComponent'}
    };
    
    % Create split view files
    for i = 1:size(view_splits, 1)
        original_view = view_splits{i, 1};
        new_components = view_splits{i, 2};
        
        fprintf('  📋 Splitting %s into:\n', original_view);
        for j = 1:length(new_components)
            component_name = new_components{j};
            component_path = fullfile('src', 'views', 'components', [component_name '.m']);
            
            if ~exist(component_path, 'file')
                create_component_file(component_path, component_name);
                fprintf('    ✅ Created: %s\n', component_name);
            else
                fprintf('    ⚠️  Exists: %s\n', component_name);
            end
        end
    end
    
    fprintf('Large views split successfully!\n');
end

function create_component_file(filepath, component_name)
    % Create a component file
    
    fid = fopen(filepath, 'w');
    
    fprintf(fid, 'classdef %s < handle\n', component_name);
    fprintf(fid, '    %% %s - UI Component for %s\n', component_name, lower(component_name(1:end-9)));
    fprintf(fid, '    %% This component handles %s UI functionality\n\n', lower(component_name(1:end-9)));
    
    fprintf(fid, '    properties (Access = private)\n');
    fprintf(fid, '        Panel\n');
    fprintf(fid, '        %% TODO: Add component-specific properties\n');
    fprintf(fid, '    end\n\n');
    
    fprintf(fid, '    methods\n');
    fprintf(fid, '        function obj = %s(parent)\n', component_name);
    fprintf(fid, '            %% Constructor\n');
    fprintf(fid, '            obj.createUI(parent);\n');
    fprintf(fid, '        end\n\n');
    
    fprintf(fid, '        function createUI(obj, parent)\n');
    fprintf(fid, '            %% Create the UI components\n');
    fprintf(fid, '            %% TODO: Implement UI creation\n');
    fprintf(fid, '        end\n\n');
    
    fprintf(fid, '        %% TODO: Implement component methods\n');
    fprintf(fid, '    end\n');
    fprintf(fid, 'end\n');
    
    fclose(fid);
end

function organize_utilities()
    % Organize utilities by domain
    
    fprintf('Organizing utilities...\n');
    
    % Define utility organization
    utility_org = {
        'FoilviewUtils', {'ValidationUtils', 'ConversionUtils', 'MathUtils'};
        'NumericUtils', {'MathUtils', 'ValidationUtils'};
        'FilePathUtils', {'FileUtils', 'PathUtils'};
        'ConfigUtils', {'ConfigUtils', 'ValidationUtils'};
        'MetadataWriter', {'FileUtils', 'ValidationUtils'};
        'UiBuilder', {'StyleUtils', 'LayoutUtils', 'ComponentUtils'};
        'UiComponents', {'StyleUtils', 'ComponentUtils'};
        'StageView', {'LayoutUtils', 'ComponentUtils'};
        'BookmarksView', {'LayoutUtils', 'ComponentUtils'};
        'MJC3View', {'LayoutUtils', 'ComponentUtils'};
        'ToolsWindow', {'LayoutUtils', 'ComponentUtils'};
        'PlotManager', {'LayoutUtils', 'ComponentUtils'};
        'ScanImageManager', {'ScanImageUtils', 'HardwareUtils'};
        'StageControlService', {'HardwareUtils', 'ValidationUtils'};
        'ApplicationInitializer', {'ConfigUtils', 'ValidationUtils'};
        'UserNotificationService', {'LoggingUtils', 'ValidationUtils'};
        'ErrorHandlerService', {'LoggingUtils', 'ValidationUtils'};
        'MetricCalculationService', {'MathUtils', 'ValidationUtils'};
        'ScanControlService', {'ValidationUtils', 'HardwareUtils'};
        'MetricsPlotService', {'MathUtils', 'ValidationUtils'};
        'MetadataService', {'FileUtils', 'ValidationUtils'};
        'BookmarkManager', {'FileUtils', 'ValidationUtils'};
        'HIDController', {'HardwareUtils', 'ValidationUtils'};
        'WindowsJoystickReader', {'HardwareUtils', 'ValidationUtils'};
        'ScanImageZController', {'HardwareUtils', 'ValidationUtils'};
        'UIController', {'LayoutUtils', 'ComponentUtils'};
        'FoilviewController', {'ValidationUtils', 'ConversionUtils'};
        'MJC3ControllerFactory', {'HardwareUtils', 'ValidationUtils'};
        'BaseMJC3Controller', {'HardwareUtils', 'ValidationUtils'};
        'MJC3_HID_Controller', {'HardwareUtils', 'ValidationUtils'};
        'MJC3_Native_Controller', {'HardwareUtils', 'ValidationUtils'};
        'MJC3_Windows_HID_Controller', {'HardwareUtils', 'ValidationUtils'};
        'MJC3_Keyboard_Controller', {'HardwareUtils', 'ValidationUtils'};
        'MJC3_Simulation_Controller', {'ValidationUtils', 'MathUtils'};
        'foilview', {'ConfigUtils', 'ValidationUtils', 'LayoutUtils'};
        'verify_migration', {'ValidationUtils', 'FileUtils'};
        'migrate_to_new_organization', {'FileUtils', 'ValidationUtils'};
        'test_new_organization', {'ValidationUtils', 'HardwareUtils'};
        'migrate_architecture', {'FileUtils', 'ValidationUtils'}
    };
    
    % Create organized utility files
    for i = 1:size(utility_org, 1)
        original_util = utility_org{i, 1};
        new_utils = utility_org{i, 2};
        
        fprintf('  📋 Organizing %s into:\n', original_util);
        for j = 1:length(new_utils)
            util_name = new_utils{j};
            
            % Determine appropriate subdirectory
            if contains(util_name, 'File') || contains(util_name, 'Path') || contains(util_name, 'Config')
                util_path = fullfile('src', 'utils', 'file', [util_name '.m']);
            elseif contains(util_name, 'Style') || contains(util_name, 'Layout') || contains(util_name, 'Component')
                util_path = fullfile('src', 'utils', 'ui', [util_name '.m']);
            elseif contains(util_name, 'ScanImage') || contains(util_name, 'Hardware')
                util_path = fullfile('src', 'utils', 'external', [util_name '.m']);
            else
                util_path = fullfile('src', 'utils', 'core', [util_name '.m']);
            end
            
            if ~exist(util_path, 'file')
                create_utility_file(util_path, util_name);
                fprintf('    ✅ Created: %s\n', util_name);
            else
                fprintf('    ⚠️  Exists: %s\n', util_name);
            end
        end
    end
    
    fprintf('Utilities organized successfully!\n');
end

function create_utility_file(filepath, util_name)
    % Create a utility file
    
    fid = fopen(filepath, 'w');
    
    fprintf(fid, 'classdef %s\n', util_name);
    fprintf(fid, '    %% %s - Utility functions for %s\n', util_name, lower(util_name(1:end-5)));
    fprintf(fid, '    %% This utility provides %s functionality\n\n', lower(util_name(1:end-5)));
    
    fprintf(fid, '    methods (Static)\n');
    fprintf(fid, '        %% TODO: Implement utility methods\n');
    fprintf(fid, '    end\n');
    fprintf(fid, 'end\n');
    
    fclose(fid);
end

function full_migration()
    % Execute full migration (all phases)
    
    fprintf('Executing full architecture migration...\n\n');
    
    create_directory_structure();
    fprintf('\n');
    
    extract_interfaces();
    fprintf('\n');
    
    implement_repository_pattern();
    fprintf('\n');
    
    split_large_services();
    fprintf('\n');
    
    split_large_controllers();
    fprintf('\n');
    
    split_large_views();
    fprintf('\n');
    
    organize_utilities();
    fprintf('\n');
    
    fprintf('Full migration completed successfully!\n');
    fprintf('Next steps:\n');
    fprintf('1. Review the new structure\n');
    fprintf('2. Move existing files to appropriate new locations\n');
    fprintf('3. Update import paths and dependencies\n');
    fprintf('4. Implement the abstract methods in new files\n');
    fprintf('5. Test the refactored components\n');
end 