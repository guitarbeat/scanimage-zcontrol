classdef ComponentFactory < handle
    %COMPONENTFACTORY Creates UI components from JSON configuration
    %   Replaces repetitive UI construction code in UiBuilder
    
    properties (Constant, Access = private)
        CONFIG_FILE = 'src/config/ui_components.json'
    end
    
    properties (Access = private)
        Config
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
            try
                obj.loadConfig();
            catch ME
                fprintf('ComponentFactory initialization failed: %s\n', ME.message);
                obj.Config = [];
            end
        end
        
        function component = buildComponent(obj, componentName, parent)
            %BUILDCOMPONENT Build a component from config
            try
                if isempty(obj.Config) || ~isfield(obj.Config, 'components')
                    error('Component %s not found in config', componentName);
                end
                
                components = obj.Config.components;
                if ~isfield(components, componentName)
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
                else
                    error('Config file not found: %s', obj.CONFIG_FILE);
                end
            catch ME
                error('Failed to load config: %s', ME.message);
            end
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
        
        function uiElement = createElement(obj, elementConfig, parent)
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