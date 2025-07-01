classdef foilview_callback_manager < handle
    % foilview_callback_manager - Systematic callback setup for foilview
    %
    % This class provides a systematic approach to setting up all UI callbacks
    % for the foilview application, reducing code duplication and improving
    % maintainability.
    
    methods (Static)
        function setupAllCallbacks(app)
            % Set up all UI callbacks for the application
            foilview_callback_manager.setupMainWindowCallbacks(app);
            foilview_callback_manager.setupManualControlCallbacks(app);
            foilview_callback_manager.setupAutoStepCallbacks(app);
            foilview_callback_manager.setupMetricCallbacks(app);
            foilview_callback_manager.setupStatusCallbacks(app);
            foilview_callback_manager.setupPlotControlCallbacks(app);
        end
        
        function setupMainWindowCallbacks(app)
            % Set up main window callbacks
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @app.onWindowClose, true);
        end
        
        function setupManualControlCallbacks(app)
            % Set up manual control callbacks
            callbacks = {
                {app.ManualControls.StepSizeField, 'ValueChangedFcn', @app.onManualStepSizeChanged}
                {app.ManualControls.UpButton, 'ButtonPushedFcn', @app.onUpButtonPushed}
                {app.ManualControls.DownButton, 'ButtonPushedFcn', @app.onDownButtonPushed}
                {app.ManualControls.ZeroButton, 'ButtonPushedFcn', @app.onZeroButtonPushed}
                {app.ManualControls.StepUpButton, 'ButtonPushedFcn', @app.onStepUpButtonPushed}
                {app.ManualControls.StepDownButton, 'ButtonPushedFcn', @app.onStepDownButtonPushed}
            };
            
            foilview_callback_manager.assignCallbacks(app, callbacks);
        end
        
        function setupAutoStepCallbacks(app)
            % Set up auto step control callbacks
            callbacks = {
                {app.AutoControls.StepField, 'ValueChangedFcn', @app.onAutoStepSizeChanged}
                {app.AutoControls.StepsField, 'ValueChangedFcn', @app.onAutoStepsChanged}
                {app.AutoControls.DelayField, 'ValueChangedFcn', @app.onAutoDelayChanged}
                {app.AutoControls.DirectionButton, 'ButtonPushedFcn', @app.onAutoDirectionToggled}
                {app.AutoControls.StartStopButton, 'ButtonPushedFcn', @app.onStartStopButtonPushed}
            };
            
            foilview_callback_manager.assignCallbacks(app, callbacks);
        end
        
        function setupMetricCallbacks(app)
            % Set up metric display callbacks
            callbacks = {
                {app.MetricDisplay.TypeDropdown, 'ValueChangedFcn', @app.onMetricTypeChanged}
                {app.MetricDisplay.RefreshButton, 'ButtonPushedFcn', @app.onMetricRefreshButtonPushed}
            };
            
            foilview_callback_manager.assignCallbacks(app, callbacks);
        end
        
        function setupStatusCallbacks(app)
            % Set up status control callbacks
            callbacks = {
                {app.StatusControls.RefreshButton, 'ButtonPushedFcn', @app.onRefreshButtonPushed}
                {app.StatusControls.BookmarksButton, 'ButtonPushedFcn', @app.onBookmarksButtonPushed}
                {app.StatusControls.StageViewButton, 'ButtonPushedFcn', @app.onStageViewButtonPushed}
            };
            
            foilview_callback_manager.assignCallbacks(app, callbacks);
        end
        
        function setupPlotControlCallbacks(app)
            % Set up plot control callbacks
            callbacks = {
                {app.MetricsPlotControls.ExpandButton, 'ButtonPushedFcn', @app.onExpandButtonPushed}
                {app.MetricsPlotControls.ClearButton, 'ButtonPushedFcn', @app.onClearPlotButtonPushed}
                {app.MetricsPlotControls.ExportButton, 'ButtonPushedFcn', @app.onExportPlotButtonPushed}
            };
            
            foilview_callback_manager.assignCallbacks(app, callbacks);
        end
    end
    
    methods (Static, Access = private)
        function assignCallbacks(app, callbacks)
            % Assign callbacks from a cell array definition
            % callbacks: cell array of {component, property, function_handle} triplets
            
            for i = 1:length(callbacks)
                component = callbacks{i}{1};
                property = callbacks{i}{2};
                functionHandle = callbacks{i}{3};
                
                if ~isempty(component) && isvalid(component)
                    component.(property) = createCallbackFcn(app, functionHandle, true);
                end
            end
        end
    end
end 