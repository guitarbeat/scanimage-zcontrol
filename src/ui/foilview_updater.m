classdef foilview_updater < handle
    % foilview_updater - Enhanced UI state management for foilview
    %
    % This class manages all UI update operations including position display,
    % status updates, control state management, and bookmarks list updates.
    % Refactored for better maintainability, reduced complexity, and improved organization.
    
    properties (Constant, Access = private)
        % Update throttling constants
        DEFAULT_THROTTLE_INTERVAL = 0.05  % 50ms throttle
        
        % Update operation names for error reporting
        UPDATE_OPERATIONS = struct(...
            'All', 'updateAllUI', ...
            'Position', 'updatePositionDisplay', ...
            'Status', 'updateStatusDisplay', ...
            'Controls', 'updateControlStates', ...
            'Metrics', 'updateMetricDisplay', ...
            'Plot', 'updatePlotExpansionState', ...
            'Title', 'updateWindowTitle')
    end
    
    methods (Static)
        function success = updateAllUI(app)
            % Update all UI components with centralized coordination
            success = foilview_updater.safeExecuteUpdate(@() foilview_updater.doUpdateAll(app), ...
                foilview_updater.UPDATE_OPERATIONS.All);
        end
        
        function success = updatePositionDisplay(uiFigure, positionDisplay, controller)
            % Update position display with enhanced validation
            success = foilview_updater.safeExecuteUpdate(@() foilview_updater.doUpdatePosition(uiFigure, positionDisplay, controller), ...
                foilview_updater.UPDATE_OPERATIONS.Position);
        end
        
        function success = updateStatusDisplay(positionDisplay, statusControls, controller)
            % Update status display with state management
            success = foilview_updater.safeExecuteUpdate(@() foilview_updater.doUpdateStatus(positionDisplay, statusControls, controller), ...
                foilview_updater.UPDATE_OPERATIONS.Status);
        end
        
        function success = updateControlStates(manualControls, autoControls, controller)
            % Update control states with centralized logic
            success = foilview_updater.safeExecuteUpdate(@() foilview_updater.doUpdateControls(manualControls, autoControls, controller), ...
                foilview_updater.UPDATE_OPERATIONS.Controls);
        end
        
        function success = updateMetricDisplay(metricDisplay, controller)
            % Update metric display with enhanced formatting
            success = foilview_updater.safeExecuteUpdate(@() foilview_updater.doUpdateMetrics(metricDisplay, controller), ...
                foilview_updater.UPDATE_OPERATIONS.Metrics);
        end
        
        function success = updatePlotExpansionState(plotControls, isExpanded)
            % Update plot expansion button state
            success = foilview_updater.safeExecuteUpdate(@() foilview_updater.doUpdatePlotState(plotControls, isExpanded), ...
                foilview_updater.UPDATE_OPERATIONS.Plot);
        end
        
        function success = updateWindowTitle(app)
            % Update window title with position and status information
            success = foilview_updater.safeExecuteUpdate(@() foilview_updater.doUpdateTitle(app), ...
                foilview_updater.UPDATE_OPERATIONS.Title);
        end
    end
    
    methods (Static, Access = private)
        %% Core Update Implementation Methods
        
        function success = doUpdateAll(app)
            % Coordinate all UI updates with throttling and batch processing
            persistent lastUpdateTime;
            if isempty(lastUpdateTime)
                lastUpdateTime = 0;
            end
            
            % Apply throttling to prevent excessive updates
            if ~foilview_updater.shouldPerformUpdate(lastUpdateTime)
                success = true;
                return;
            end
            lastUpdateTime = now * 24 * 3600;
            
            % Execute batch updates for better performance
            updateOperations = foilview_updater.createUpdateOperations(app);
            success = foilview_updater.executeBatchUpdates(updateOperations);
        end
        
        function success = doUpdatePosition(uiFigure, positionDisplay, controller)
            % Core position display update implementation
            success = false;
            
            if ~foilview_updater.validatePositionInputs(uiFigure, positionDisplay, controller)
                return;
            end
            
            positionStr = foilview_utils.formatPosition(controller.CurrentPosition, true);
            positionDisplay.Label.Text = positionStr;
            
            success = true;
        end
        
        function success = doUpdateStatus(positionDisplay, statusControls, controller)
            % Core status display update implementation
            success = false;
            
            if ~foilview_updater.validateStatusInputs(positionDisplay, statusControls, controller)
                return;
            end
            
            foilview_updater.updatePositionStatus(positionDisplay, controller);
            foilview_updater.updateConnectionStatus(statusControls, controller);
            
            success = true;
        end
        
        function success = doUpdateControls(manualControls, autoControls, controller)
            % Core control state update implementation
            success = false;
            
            if ~foilview_updater.validateControlInputs(controller)
                return;
            end
            
            isRunning = controller.IsAutoRunning;
            
            foilview_updater.updateManualControlStates(manualControls, isRunning);
            foilview_updater.updateAutoControlStates(autoControls, controller, isRunning);
            
            success = true;
        end
        
        function success = doUpdateMetrics(metricDisplay, controller)
            % Core metric display update implementation
            success = false;
            
            if ~foilview_updater.validateMetricInputs(metricDisplay, controller)
                return;
            end
            
            metricValue = controller.CurrentMetric;
            foilview_updater.updateMetricValueDisplay(metricDisplay, metricValue);
            
            success = true;
        end
        
        function success = doUpdatePlotState(plotControls, isExpanded)
            % Core plot state update implementation
            success = false;
            
            if ~foilview_updater.validatePlotInputs(plotControls)
                return;
            end
            
            foilview_updater.updatePlotExpansionButton(plotControls, isExpanded);
            
            success = true;
        end
        
        function success = doUpdateTitle(app)
            % Core window title update implementation
            success = false;
            
            if ~foilview_updater.validateTitleInputs(app)
                return;
            end
            
            baseTitle = foilview_ui.TEXT.WindowTitle;
            if app.PlotManager.getIsPlotExpanded()
                baseTitle = sprintf('%s - Plot Expanded', baseTitle);
            end
            
            posStr = foilview_utils.formatPosition(app.Controller.CurrentPosition, true);
            app.UIFigure.Name = sprintf('%s (%s)', baseTitle, posStr);
            
            success = true;
        end
        
        %% Specialized Update Methods
        
        function updatePositionStatus(positionDisplay, controller)
            % Update position status based on controller state
            if controller.IsAutoRunning
                progressText = sprintf('Auto-stepping: %d/%d', controller.CurrentStep, controller.TotalSteps);
                positionDisplay.Status.Text = progressText;
                foilview_styling.styleLabel(positionDisplay.Status, 'primary');
            else
                positionDisplay.Status.Text = 'Ready';
                foilview_styling.styleLabel(positionDisplay.Status, 'muted');
            end
        end
        
        function updateConnectionStatus(statusControls, controller)
            % Update connection status with appropriate styling
            if controller.SimulationMode
                statusText = sprintf('ScanImage: Simulation (%s)', controller.StatusMessage);
                foilview_styling.styleLabel(statusControls.Label, 'warning');
            else
                statusText = sprintf('ScanImage: %s', controller.StatusMessage);
                foilview_styling.styleLabel(statusControls.Label, 'success');
            end
            statusControls.Label.Text = statusText;
        end
        
        function updateManualControlStates(manualControls, isRunning)
            % Update manual control states based on auto-stepping status
            foilview_updater.setControlGroupEnabled(manualControls, ~isRunning);
        end
        
        function updateAutoControlStates(autoControls, controller, isRunning)
            % Update auto control states with selective enabling/disabling
            if isRunning
                foilview_updater.disableAutoStepParameters(autoControls);
                foilview_updater.enableAutoStepControls(autoControls);
            else
                foilview_updater.setControlGroupEnabled(autoControls, true);
            end
            
            foilview_updater.updateDirectionButtonStyling(autoControls, controller.AutoDirection);
            foilview_updater.updateAutoStepButton(autoControls, isRunning);
        end
        
        function updateMetricValueDisplay(metricDisplay, metricValue)
            % Update metric value display with visual feedback
            colors = foilview_styling.getColors();
            
            displayText = foilview_utils.formatMetricValue(metricValue);
            
            if isnan(metricValue)
                textColor = colors.TextMuted;
                bgColor = colors.Light;
            else
                textColor = [0 0 0];
                bgColor = foilview_updater.calculateMetricBackgroundColor(metricValue, colors);
            end
            
            metricDisplay.Value.Text = displayText;
            metricDisplay.Value.FontColor = textColor;
            metricDisplay.Value.BackgroundColor = bgColor;
        end
        
        function updatePlotExpansionButton(plotControls, isExpanded)
            % Update plot expansion button appearance
            if isExpanded
                foilview_styling.styleButton(plotControls.ExpandButton, 'warning', 'base');
                plotControls.ExpandButton.Text = '📊 Hide Plot';
            else
                foilview_styling.styleButton(plotControls.ExpandButton, 'primary', 'base');
                plotControls.ExpandButton.Text = '📊 Show Plot';
            end
        end
        
        function updateAutoStepButton(autoControls, isRunning)
            % Update auto-step button appearance based on state
            if ~foilview_updater.validateControlStruct(autoControls, {'StartStopButton'})
                return;
            end
            
            if isRunning
                foilview_styling.styleButton(autoControls.StartStopButton, 'danger', 'base');
                autoControls.StartStopButton.Text = 'STOP';
            else
                foilview_styling.styleButton(autoControls.StartStopButton, 'success', 'base');
                autoControls.StartStopButton.Text = 'START';
            end
        end
        
        function updateDirectionButtonStyling(autoControls, direction)
            % Update direction button styling based on current direction
            if ~foilview_updater.validateControlStruct(autoControls, {'DirectionButton'})
                return;
            end
            
            if direction == 1  % Up
                foilview_styling.styleButton(autoControls.DirectionButton, 'success', 'base');
                autoControls.DirectionButton.Text = '▲ UP';
            else  % Down
                foilview_styling.styleButton(autoControls.DirectionButton, 'warning', 'base');
                autoControls.DirectionButton.Text = '▼ DOWN';
            end
        end
        
        %% Control State Management Methods
        
        function setControlGroupEnabled(controls, enabled)
            % Enable/disable all controls in a group
            controlFields = foilview_utils.getAllControlFields();
            foilview_utils.setControlsEnabled(controls, enabled, controlFields);
        end
        
        function disableAutoStepParameters(autoControls)
            % Disable parameter controls during auto stepping
            parameterFields = {'StepField', 'StepsField', 'DelayField'};
            for i = 1:length(parameterFields)
                foilview_utils.setControlEnabled(autoControls, false, parameterFields{i});
            end
        end
        
        function enableAutoStepControls(autoControls)
            % Enable control buttons during auto stepping
            controlFields = {'DirectionButton', 'StartStopButton'};
            for i = 1:length(controlFields)
                foilview_utils.setControlEnabled(autoControls, true, controlFields{i});
            end
        end
        
        %% Validation Methods
        
        function valid = validatePositionInputs(uiFigure, positionDisplay, controller)
            % Validate inputs for position display update
            valid = foilview_utils.validateMultipleComponents(uiFigure, positionDisplay.Label) && ...
                    ~isempty(controller);
        end
        
        function valid = validateStatusInputs(positionDisplay, statusControls, controller)
            % Validate inputs for status display update
            valid = foilview_utils.validateMultipleComponents(positionDisplay.Status, statusControls.Label) && ...
                    ~isempty(controller);
        end
        
        function valid = validateControlInputs(controller)
            % Validate inputs for control state update
            valid = ~isempty(controller);
        end
        
        function valid = validateMetricInputs(metricDisplay, controller)
            % Validate inputs for metric display update
            valid = foilview_updater.validateControlStruct(metricDisplay, {'Value'}) && ...
                    ~isempty(controller);
        end
        
        function valid = validatePlotInputs(plotControls)
            % Validate inputs for plot state update
            valid = foilview_updater.validateControlStruct(plotControls, {'ExpandButton'});
        end
        
        function valid = validateTitleInputs(app)
            % Validate inputs for title update
            valid = ~isempty(app) && isvalid(app.UIFigure);
        end
        
        function valid = validateControlStruct(controlStruct, requiredFields)
            % Validate that control structure has required fields
            if ~isstruct(controlStruct) || isempty(requiredFields)
                valid = false;
                return;
            end
            
            valid = true;
            for i = 1:length(requiredFields)
                if ~isfield(controlStruct, requiredFields{i}) || ...
                   ~foilview_utils.validateUIComponent(controlStruct.(requiredFields{i}))
                    valid = false;
                    return;
                end
            end
        end
        
        %% Utility and Helper Methods
        
        function should = shouldPerformUpdate(lastUpdateTime)
            % Check if enough time has passed since last update
            currentTime = now * 24 * 3600;
            should = (currentTime - lastUpdateTime) >= foilview_updater.DEFAULT_THROTTLE_INTERVAL;
        end
        
        function operations = createUpdateOperations(app)
            % Create list of update operations for batch execution
            operations = {
                @() foilview_updater.updatePositionDisplay(app.UIFigure, app.PositionDisplay, app.Controller),
                @() foilview_updater.updateStatusDisplay(app.PositionDisplay, app.StatusControls, app.Controller),
                @() foilview_updater.updateControlStates(app.ManualControls, app.AutoControls, app.Controller),
                @() foilview_updater.updateMetricDisplay(app.MetricDisplay, app.Controller),
                @() foilview_updater.updatePlotExpansionState(app.MetricsPlotControls, app.PlotManager.getIsPlotExpanded()),
                @() foilview_updater.updateWindowTitle(app)
            };
        end
        
        function success = executeBatchUpdates(updateOperations)
            % Execute multiple update operations as a batch
            success = foilview_utils.batchUIUpdate(updateOperations);
        end
        
        function bgColor = calculateMetricBackgroundColor(metricValue, colors)
            % Calculate background color based on metric value
            if metricValue > 0
                % Add visual feedback for high metric values (potential focus)
                intensity = min(1, metricValue / 100);  % Normalize to [0,1]
                greenComponent = 0.9 + 0.1 * intensity;  % Slightly green tint for high values
                bgColor = [0.95 greenComponent 0.95];
            else
                bgColor = colors.Light;
            end
        end
        
        function success = safeExecuteUpdate(updateOperation, operationName)
            % Centralized error handling for update operations
            try
                success = updateOperation();
            catch ME
                fprintf('Error in %s: %s\n', operationName, ME.message);
                success = false;
            end
        end
    end
    
    methods (Static)
        function success = batchUpdate(updateFunctions)
            % Public method for performing multiple UI updates in a batch
            success = foilview_utils.batchUIUpdate(updateFunctions);
        end
    end
end 