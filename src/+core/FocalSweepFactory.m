classdef FocalSweepFactory
    % FocalSweepFactory - Factory class for creating and managing FocalSweep instances
    
    methods (Static)
        function obj = launch(varargin)
            % Launch FocalSweep as a singleton
            %
            % Optional parameter/value pairs:
            %   'verbosity' - Level of output messages (0=quiet, 1=normal, 2=debug)
            %   'forceNew'  - Force creation of a new instance
            
            % Parse inputs
            p = inputParser;
            p.addParameter('verbosity', 1, @isnumeric);
            p.addParameter('forceNew', false, @islogical);
            p.parse(varargin{:});
            
            verbosity = p.Results.verbosity;
            forceNew = p.Results.forceNew;
            
            persistent instance;
            
            % Check if the existing instance is valid
            isInstanceValid = false;
            if ~isempty(instance)
                try
                    % Use a more focused check to validate instance
                    isInstanceValid = isvalid(instance) && ...
                                     core.CoreUtils.isGuiValid(instance) && ...
                                     ishandle(instance.gui.hFig);
                catch
                    % If any error occurs during validation, the instance is not valid
                    isInstanceValid = false;
                end
            end
            
            % Create a new instance or reuse existing
            if ~isInstanceValid || forceNew
                if verbosity > 0
                    fprintf('Initializing FocalSweep focus control...\n');
                end
                obj = core.FocalSweep('verbosity', verbosity);
                
                % Store as singleton
                instance = obj;
                
                if verbosity > 0
                    fprintf('FocalSweep focus control ready.\n');
                end
            else
                % An instance already exists, bring it to the front
                try
                    figure(instance.gui.hFig);
                catch ME
                    % If bringing window to front fails, create a new instance
                    warning('Failed to access existing instance: %s\nCreating new instance.', ME.message);
                    obj = core.FocalSweep('verbosity', verbosity);
                    instance = obj;
                end
            end
            
            obj = instance;
        end
    end
end 