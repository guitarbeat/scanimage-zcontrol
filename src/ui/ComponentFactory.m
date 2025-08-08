classdef ComponentFactory < handle
    %COMPONENTFACTORY Creates UI components from JSON configuration
    %   Replaces repetitive UI construction code in UiBuilder
    
    properties (Constant, Access = private)
        CONFIG_FILE = 'src/config/ui_components.json'
    end
    
    properties (Access = private)
        Config
        Logger  % LoggingService instance
    end
    
    methods (Static)
        function success = test()
            %TEST Quick test of ComponentFactory functionality
            try
                factory = ComponentFactory();
                fprintf('✅ ComponentFactory created\n');
                
                % Test config loading
                if ~isempty(factory.Config)
                    fprintf('✅ Config loaded with %d components\n', ...
                        length(fieldnames(factory.Config.components)));
                else
                    fprintf('❌ Config is empty\n');
                    success = false;
                    return;
                end
                
                % Test component creation (dry run)
                components = fieldnames(factory.Config.components);
                fprintf('✅ Available components: %s\n', strjoin(components, ', '));
                
                success = true;
                fprintf('✅ ComponentFactory test passed\n');
                
            catch ME
                fprintf('❌ ComponentFactory test failed: %s\n', ME.message);
                success = false;
            end
        end
        
        function component = createComponent(componentName, parent)
            %CREATECOMPONENT Create a single component by name
            factory = ComponentFactory();
            component = factory.buildComponent(componentName, parent);
        end
        
        function layout = createLayout(layoutName, parent)
            %CREATELAYOUT Create a complete layout by name
            factory = ComponentFactory();
            layout = factory.buildLayout(layoutName, parent);
        end
    end
    
    methods
        function obj = ComponentFactory()
            %COMPONENTFACTORY Constructor
            % Initialize logger
            obj.Logger = LoggingService('ComponentFactory', 'SuppressInitMessage', true);
            
            try
                obj.loadConfig();
            catch ME
                obj.Logger.error('ComponentFactory initialization failed: %s', ME.message);
                obj.Config = [];
            end
        end
        
        function component = buildComponent(obj, componentName, parent)
            %BUILDCOMPONENT Build a component from config
            try
                if isempty(obj.Config) || ~isfield(obj.Config, 'components')
                    obj.Logger.error('Component %s not found in config', componentName);
                    error('Component %s not found in config', componentName);
                end
                
                components = obj.Config.components;
                if ~isfield(components, componentName)
                    obj.Logger.error('Component %s not found in config', componentName);
                    error('Component %s not found in config', componentName);
                end
                
                config = components.(componentName);
                component = obj.createFromConfig(config, parent);
                
            catch ME
                fprintf('Failed to build component %s: %s\n', componentName, ME.message);
                component = [];
            end
        end
        
        function layout = buildLayout(obj, layoutName, parent)
            %BUILDLAYOUT Build a complete layout from config
            try
                if isempty(obj.Config) || ~isfield(obj.Config.layouts, layoutName)
                    obj.Logger.error('Layout %s not found in config', layoutName);
                    error('Layout %s not found in config', layoutName);
                end
                
                layoutConfig = obj.Config.layouts.(layoutName);
                layout = obj.createLayoutFromConfig(layoutConfig, parent);
                
            catch ME
                fprintf('Failed to build layout %s: %s\n', layoutName, ME.message);
                layout = [];
            end
        end
    end
    
    methods (Access = private)
        function loadConfig(obj)
            %LOADCONFIG Load configuration from JSON file
            try
                if exist(obj.CONFIG_FILE, 'file')
                    obj.Config = jsondecode(fileread(obj.CONFIG_FILE));
                    % * Validate configuration schema to catch errors early
                    obj.validateConfigSchema(obj.Config);
                else
                    obj.Logger.error('Config file not found: %s', obj.CONFIG_FILE);
                    error('Config file not found: %s', obj.CONFIG_FILE);
                end
            catch ME
                obj.Logger.error('Failed to load config: %s', ME.message);
                error('Failed to load config: %s', ME.message);
            end
        end

        function validateConfigSchema(obj, config)
            %VALIDATECONFIGSCHEMA Basic schema validation for UI config
            % * Ensures required top-level sections and minimal field checks
            if ~isstruct(config)
                error('UI config must be a struct');
            end
            requiredTop = { 'components', 'layouts' };
            for i = 1:numel(requiredTop)
                if ~isfield(config, requiredTop{i})
                    error('UI config missing required section: %s', requiredTop{i});
                end
            end

            % Validate components
            components = config.components;
            if ~isstruct(components)
                error('UI config "components" must be a struct');
            end
            compNames = fieldnames(components);
            for i = 1:numel(compNames)
                c = components.(compNames{i});
                if ~isfield(c, 'type')
                    error('Component "%s" missing required field: type', compNames{i});
                end
                switch c.type
                    case 'grid_panel'
                        if ~isfield(c, 'rows') || ~isfield(c, 'columns')
                            error('grid_panel "%s" must specify rows and columns', compNames{i});
                        end
                        if (~isscalar(c.rows) || c.rows < 1) || (~isscalar(c.columns) || c.columns < 1)
                            error('grid_panel "%s" rows/columns must be positive scalars', compNames{i});
                        end
                    case {'horizontal_panel','vertical_panel'}
                        % No extra required fields
                    otherwise
                        error('Unknown component type in "%s": %s', compNames{i}, c.type);
                end
                if isfield(c, 'elements')
                    elems = c.elements;
                    if ~(iscell(elems) || isstruct(elems))
                        error('Component "%s" elements must be a cell array or struct array', compNames{i});
                    end
                end
            end

            % Validate layouts
            layouts = config.layouts;
            if ~isstruct(layouts)
                error('UI config "layouts" must be a struct');
            end
            layoutNames = fieldnames(layouts);
            for i = 1:numel(layoutNames)
                l = layouts.(layoutNames{i});
                if ~isfield(l, 'rows') || ~isfield(l, 'columns')
                    error('Layout "%s" must specify rows and columns', layoutNames{i});
                end
                if (~isscalar(l.rows) || l.rows < 1) || (~isscalar(l.columns) || l.columns < 1)
                    error('Layout "%s" rows/columns must be positive scalars', layoutNames{i});
                end
                if isfield(l, 'components') && ~(isstruct(l.components) || isvector(l.components))
                    error('Layout "%s" components should be an array-like struct', layoutNames{i});
                end
            end
            obj.Logger.debug('UI configuration schema validated: %d components, %d layouts', numel(compNames), numel(layoutNames));
        end
        
        function component = createFromConfig(obj, config, parent)
            %CREATEFROMCONFIG Create UI component from config structure
            
            switch config.type
                case 'grid_panel'
                    component = obj.createGridPanel(config, parent);
                case 'horizontal_panel'
                    component = obj.createHorizontalPanel(config, parent);
                case 'vertical_panel'
                    component = obj.createVerticalPanel(config, parent);
                otherwise
                    obj.Logger.error('Unknown component type: %s', config.type);
                    error('Unknown component type: %s', config.type);
            end
        end
        
        function panel = createGridPanel(obj, config, parent)
            %CREATEGRIDPANEL Create a grid-based panel
            
            % Create main panel
            panel = uipanel(parent);
            if isfield(config, 'title')
                panel.Title = config.title;
            end
            
            % Create grid layout
            grid = uigridlayout(panel);
            grid.RowHeight = repmat({'1x'}, 1, config.rows);
            grid.ColumnWidth = repmat({'1x'}, 1, config.columns);
            
            % Add elements
            if isfield(config, 'elements')
                for i = 1:length(config.elements)
                    % Handle cell array from JSON
                    if iscell(config.elements)
                        element = config.elements{i};  % Use curly braces for cell array
                    else
                        element = config.elements(i);  % Use parentheses for struct array
                    end
                    obj.createElement(element, grid);
                end
            end
        end
        
        function panel = createHorizontalPanel(obj, config, parent)
            %CREATEHORIZONTALPANEL Create a horizontal panel
            
            panel = uipanel(parent);
            if isfield(config, 'title')
                panel.Title = config.title;
            end
            
            % Create horizontal grid
            grid = uigridlayout(panel);
            grid.RowHeight = {'1x'};
            grid.ColumnWidth = repmat({'1x'}, 1, length(config.elements));
            
            % Add elements
            for i = 1:length(config.elements)
                % Handle cell array from JSON
                if iscell(config.elements)
                    element = config.elements{i};  % Use curly braces for cell array
                else
                    element = config.elements(i);  % Use parentheses for struct array
                end
                % Add position info
                element.row = 1;
                element.col = i;
                obj.createElement(element, grid);
            end
        end
        
        function panel = createVerticalPanel(obj, config, parent)
            %CREATEVERTICALPANEL Create a vertical panel
            
            panel = uipanel(parent);
            if isfield(config, 'title')
                panel.Title = config.title;
            end
            
            % Create vertical grid
            grid = uigridlayout(panel);
            grid.RowHeight = repmat({'1x'}, 1, length(config.elements));
            grid.ColumnWidth = {'1x'};
            
            % Add elements
            for i = 1:length(config.elements)
                % Handle cell array from JSON
                if iscell(config.elements)
                    element = config.elements{i};  % Use curly braces for cell array
                else
                    element = config.elements(i);  % Use parentheses for struct array
                end
                % Add position info
                element.row = i;
                element.col = 1;
                obj.createElement(element, grid);
            end
        end
        
        function uiElement = createElement(~, elementConfig, parent)
            %CREATEELEMENT Create individual UI element
            
            switch elementConfig.type
                case 'label'
                    uiElement = uilabel(parent);
                    uiElement.Text = elementConfig.text;
                    
                case 'button'
                    uiElement = uibutton(parent);
                    uiElement.Text = elementConfig.text;
                    if isfield(elementConfig, 'tooltip')
                        uiElement.Tooltip = elementConfig.tooltip;
                    end
                    
                case 'numeric_field'
                    uiElement = uieditfield(parent, 'numeric');
                    if isfield(elementConfig, 'value')
                        uiElement.Value = elementConfig.value;
                    end
                    if isfield(elementConfig, 'editable')
                        uiElement.Editable = elementConfig.editable;
                    end
                    
                case 'dropdown'
                    uiElement = uidropdown(parent);
                    if isfield(elementConfig, 'items')
                        uiElement.Items = elementConfig.items;
                    end
                    
                otherwise
                    error('Unknown element type: %s', elementConfig.type);
            end
            
            % Set grid position
            if isfield(elementConfig, 'row')
                uiElement.Layout.Row = elementConfig.row;
            end
            if isfield(elementConfig, 'col')
                uiElement.Layout.Column = elementConfig.col;
            end
            if isfield(elementConfig, 'span')
                uiElement.Layout.Column = [elementConfig.col, elementConfig.col + elementConfig.span - 1];
            end
        end
        
        function layout = createLayoutFromConfig(obj, layoutConfig, parent)
            %CREATELAYOUTFROMCONFIG Create layout from config
            
            % Create main grid
            layout = uigridlayout(parent);
            layout.RowHeight = repmat({'1x'}, 1, layoutConfig.rows);
            layout.ColumnWidth = repmat({'1x'}, 1, layoutConfig.columns);
            
            % Add components to layout
            for i = 1:length(layoutConfig.components)
                compConfig = layoutConfig.components(i);
                component = obj.buildComponent(compConfig.component, layout);
                
                if ~isempty(component)
                    component.Layout.Row = compConfig.row;
                    component.Layout.Column = compConfig.col;
                end
            end
        end
    end
end