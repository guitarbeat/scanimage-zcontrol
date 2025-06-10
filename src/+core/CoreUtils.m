classdef CoreUtils
    % CoreUtils - Utility functions shared across core components
    %
    % This class provides common utility functions to reduce code duplication
    % across multiple core classes.
    
    methods(Static)
        function isValid = isGuiValid(obj)
            % Checks if a GUI component is valid and accessible
            % Returns true if the GUI exists, is not empty, and is a valid object
            try
                isValid = isfield(obj, 'gui') && ...
                         ~isempty(obj.gui) && ...
                         isvalid(obj.gui);
            catch
                isValid = false;
            end
        end
        
        function handleError(controller, ME, prefix)
            % Handle and display error information
            % 
            % Parameters:
            %   controller - Object that may have a GUI to update
            %   ME - The MException object
            %   prefix - Optional prefix for the error message
            
            if nargin < 3
                prefix = 'Error';
            end
            
            % Display error in console
            errMsg = sprintf('%s: %s', prefix, ME.message);
            fprintf('%s\n', errMsg);
            disp(getReport(ME));
            
            % Update GUI status if available
            if core.CoreUtils.isGuiValid(controller) && ismethod(controller.gui, 'updateStatus')
                try
                    controller.gui.updateStatus(errMsg, 'error');
                catch
                    % Silently ignore errors when updating GUI
                end
            end
        end
        
        function updateStatus(controller, message, varargin)
            % Update status text in the GUI
            fprintf('%s\n', message);
            
            % Only update GUI if it's initialized
            if core.CoreUtils.isGuiValid(controller) && ismethod(controller.gui, 'updateStatus')
                try
                    % Forward any optional parameters to GUI's updateStatus method
                    controller.gui.updateStatus(message, varargin{:});
                catch
                    % Silently ignore errors when updating GUI
                end
            end
        end
    end
end 