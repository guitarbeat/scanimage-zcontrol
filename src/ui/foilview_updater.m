classdef foilview_updater < handle
    % foilview_updater - Enhanced UI state management for foilview
    %
    % This class manages all UI update operations including position display,
    % status updates, control state management, and bookmarks list updates.
    % Enhanced with error handling and performance optimizations.
    
    methods (Static)
        function success = updateAllUI(app)
            % Update all UI components with centralized error handling and throttling
            success = foilview_utils.safeExecuteWithReturn(@() doUpdateAll(), 'updateAllUI', false);
            
            function success = doUpdateAll()
                % Use persistent variable for throttling
                persistent lastUpdateTime;
                if isempty(lastUpdateTime)
                    lastUpdateTime = 0;
                end
                
                % Use throttling to prevent excessive updates
                if ~foilview_utils.shouldThrottleUpdate(lastUpdateTime)
                    success = true;  % Not an error, just throttled
                    return;
                end
                lastUpdateTime = now * 24 * 3600;  % Update timestamp
                
                % Use batch update for better performance
                updateFunctions = {
                    @() foilview_updater.updatePositionDisplay(app.UIFigure, app.PositionDisplay, app.Controller),
                    @() foilview_updater.updateStatusDisplay(app.PositionDisplay, app.StatusControls, app.Controller),
                    @() foilview_updater.updateControlStates(app.ManualControls, app.AutoControls, app.Controller),
                    @() foilview_updater.updateMetricDisplay(app.MetricDisplay, app.Controller),
                    @() foilview_updater.updatePlotExpansionState(app.MetricsPlotControls, app.PlotManager.getIsPlotExpanded()),
                    @() foilview_updater.updateWindowTitle(app)
                };
                
                success = foilview_utils.batchUIUpdate(updateFunctions);
            end
        end
        
        function success = updatePositionDisplay(uiFigure, positionDisplay, controller)
            % Enhanced position display update with validation
            success = foilview_utils.safeExecuteWithReturn(@() doUpdatePosition(), 'updatePositionDisplay', false);
            
            function success = doUpdatePosition()
                success = false;
                
                % Validate inputs using centralized utilities
                if ~foilview_utils.validateMultipleComponents(uiFigure, positionDisplay.Label) || isempty(controller)
                    return;
                end
                
                % Format position using utility
                positionStr = foilview_utils.formatPosition(controller.CurrentPosition, true);
                positionDisplay.Label.Text = positionStr;
                
                success = true;
            end
        end
        
        function success = updateStatusDisplay(positionDisplay, statusControls, controller)
            % Enhanced status display update with state management
            success = foilview_utils.safeExecuteWithReturn(@() doUpdateStatus(), 'updateStatusDisplay', false);
            
            function success = doUpdateStatus()
                success = false;
                
                % Validate inputs
                if ~foilview_utils.validateMultipleComponents(positionDisplay.Status, statusControls.Label) || isempty(controller)
                    return;
                end
                
                % Use centralized styling system
                colors = foilview_styling.getColors();
                
                % Update position status based on controller state
                if controller.IsAutoRunning
                    progressText = sprintf('Auto-stepping: %d/%d', controller.CurrentStep, controller.TotalSteps);
                    positionDisplay.Status.Text = progressText;
                    foilview_styling.styleLabel(positionDisplay.Status, 'primary');
                else
                    positionDisplay.Status.Text = 'Ready';
                    foilview_styling.styleLabel(positionDisplay.Status, 'muted');
                end
                
                % Update connection status with appropriate styling
                if controller.SimulationMode
                    statusText = sprintf('ScanImage: Simulation (%s)', controller.StatusMessage);
                    statusControls.Label.Text = statusText;
                    foilview_styling.styleLabel(statusControls.Label, 'warning');
                else
                    statusText = sprintf('ScanImage: %s', controller.StatusMessage);
                    statusControls.Label.Text = statusText;
                    foilview_styling.styleLabel(statusControls.Label, 'success');
                end
                
                success = true;
            end
        end
        
        function success = updateControlStates(manualControls, autoControls, controller)
            % Enhanced control state management using centralized utilities
            success = foilview_utils.safeExecuteWithReturn(@() doUpdateControlStates(), 'updateControlStates', false);
            
            function success = doUpdateControlStates()
                success = false;
                
                % Validate inputs
                if isempty(controller)
                    return;
                end
                
                isRunning = controller.IsAutoRunning;
                
                % Always disable manual controls when auto stepping
                foilview_updater.setControlsEnabled(manualControls, ~isRunning);
                
                % For auto controls, be more selective during auto stepping
                if isRunning
                    % Disable parameter controls that shouldn't change during auto stepping
                    foilview_utils.setControlEnabled(autoControls, false, 'StepField');
                    foilview_utils.setControlEnabled(autoControls, false, 'StepsField');
                    foilview_utils.setControlEnabled(autoControls, false, 'DelayField');
                    
                    % Keep direction button and start/stop button enabled
                    foilview_utils.setControlEnabled(autoControls, true, 'DirectionButton');
                    foilview_utils.setControlEnabled(autoControls, true, 'StartStopButton');
                    
                    % Maintain direction button styling based on current direction
                    foilview_updater.updateDirectionButtonStyling(autoControls, controller.AutoDirection);
                else
                    % Enable all auto controls when not running
                    foilview_updater.setControlsEnabled(autoControls, true);
                    
                    % Restore direction button styling when not running
                    foilview_updater.updateDirectionButtonStyling(autoControls, controller.AutoDirection);
                end
                
                % Update start/stop button appearance
                foilview_updater.updateAutoStepButton(autoControls, isRunning);
                
                success = true;
            end
        end
        
        function setControlsEnabled(controls, enabled)
            % Enhanced control enabling/disabling using centralized utilities
            foilview_utils.safeExecute(@() doSetControls(), 'setControlsEnabled');
            
            function doSetControls()
                % Get all relevant control field names
                controlFields = foilview_utils.getAllControlFields();
                
                % Enable/disable all controls efficiently
                foilview_utils.setControlsEnabled(controls, enabled, controlFields);
            end
        end
        
        function success = updateAutoStepButton(autoControls, isRunning)
            % Enhanced auto-step button update using centralized styling
            success = foilview_utils.safeExecuteWithReturn(@() doUpdateButton(), 'updateAutoStepButton', false);
            
            function success = doUpdateButton()
                success = false;
                
                % Validate input
                if ~foilview_utils.validateControlStruct(autoControls, {'StartStopButton'})
                    return;
                end
                
                if isRunning
                    foilview_styling.styleButton(autoControls.StartStopButton, 'danger', 'base');
                    autoControls.StartStopButton.Text = 'STOP';
                else
                    foilview_styling.styleButton(autoControls.StartStopButton, 'success', 'base');
                    autoControls.StartStopButton.Text = 'START';
                end
                
                success = true;
            end
        end
        
        function success = updateDirectionButtonStyling(autoControls, direction)
            % Update direction button styling based on current direction
            success = foilview_utils.safeExecuteWithReturn(@() doUpdateDirection(), 'updateDirectionButtonStyling', false);
            
            function success = doUpdateDirection()
                success = false;
                
                % Validate inputs
                if ~foilview_utils.validateControlStruct(autoControls, {'DirectionButton'})
                    return;
                end
                
                % Update toggle button appearance and text based on direction
                if direction == 1  % Up
                    foilview_styling.styleButton(autoControls.DirectionButton, 'success', 'base');
                    autoControls.DirectionButton.Text = '▲ UP';
                else  % Down
                    foilview_styling.styleButton(autoControls.DirectionButton, 'warning', 'base');
                    autoControls.DirectionButton.Text = '▼ DOWN';
                end
                
                success = true;
            end
        end
        
        function success = updateMetricDisplay(metricDisplay, controller)
            % Enhanced metric display update using centralized formatting
            success = foilview_utils.safeExecuteWithReturn(@() doUpdateMetric(), 'updateMetricDisplay', false);
            
            function success = doUpdateMetric()
                success = false;
                
                % Validate inputs
                if ~foilview_utils.validateControlStruct(metricDisplay, {'Value'}) || isempty(controller)
                    return;
                end
                
                % Get colors from the modern styling system
                colors = foilview_styling.getColors();
                
                % Use centralized metric formatting
                metricValue = controller.CurrentMetric;
                displayText = foilview_utils.formatMetricValue(metricValue);
                
                % Set text and color
                if isnan(metricValue)
                    textColor = colors.TextMuted;
                    bgColor = colors.Light;
                else
                    textColor = [0 0 0];  % Black
                    % Add visual feedback for high metric values (potential focus)
                    if metricValue > 0
                        % Calculate relative intensity for background color
                        intensity = min(1, metricValue / 100);  % Normalize to [0,1]
                        greenComponent = 0.9 + 0.1 * intensity;  % Slightly green tint for high values
                        bgColor = [0.95 greenComponent 0.95];
                    else
                        bgColor = colors.Light;
                    end
                end
                
                % Update display
                metricDisplay.Value.Text = displayText;
                metricDisplay.Value.FontColor = textColor;
                metricDisplay.Value.BackgroundColor = bgColor;
                
                success = true;
            end
        end
        
        function success = updatePlotExpansionState(plotControls, isExpanded)
            % Update plot expansion button state using centralized styling
            success = foilview_utils.safeExecuteWithReturn(@() doUpdateExpansion(), 'updatePlotExpansionState', false);
            
            function success = doUpdateExpansion()
                success = false;
                
                if ~foilview_utils.validateControlStruct(plotControls, {'ExpandButton'})
                    return;
                end
                
                if isExpanded
                    foilview_styling.styleButton(plotControls.ExpandButton, 'warning', 'base');
                    plotControls.ExpandButton.Text = '📊 Hide Plot';
                else
                    foilview_styling.styleButton(plotControls.ExpandButton, 'primary', 'base');
                    plotControls.ExpandButton.Text = '📊 Show Plot';
                end
                
                success = true;
            end
        end
        
        function success = updateWindowTitle(app)
            % Update window title with position and plot-expanded suffix
            success = foilview_utils.safeExecuteWithReturn(@() doUpdate(), 'updateWindowTitle', false);
            function success = doUpdate()
                success = false;
                if isempty(app) || ~isvalid(app.UIFigure)
                    return;
                end
                % Base title
                baseTitle = foilview_ui.TEXT.WindowTitle;
                % Add expanded suffix if needed
                if app.PlotManager.getIsPlotExpanded()
                    baseTitle = sprintf('%s - Plot Expanded', baseTitle);
                end
                % Position string
                posStr = foilview_utils.formatPosition(app.Controller.CurrentPosition, true);
                % Set name
                app.UIFigure.Name = sprintf('%s (%s)', baseTitle, posStr);
                success = true;
            end
        end
        
        function success = batchUpdate(updateFunctions)
            % Perform multiple UI updates in a batch using centralized utility
            success = foilview_utils.batchUIUpdate(updateFunctions);
        end
    end
end 