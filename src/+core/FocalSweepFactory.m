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
            p.addParameter('verbosity', 0, @isnumeric);
            p.addParameter('forceNew', false, @islogical);
            p.parse(varargin{:});
            
            verbosity = p.Results.verbosity;
            forceNew = p.Results.forceNew;
            
            persistent instance;
            
            % Check if the existing instance is valid using a simplified check
            isInstanceValid = false;
            try
                isInstanceValid = ~isempty(instance) && isvalid(instance) && ...
                                 isfield(instance, 'gui') && ~isempty(instance.gui) && ...
                                 isvalid(instance.gui) && isfield(instance.gui, 'hFig') && ...
                                 ishandle(instance.gui.hFig);
            catch
                isInstanceValid = false;
            end
            
            % Create a new instance or reuse existing
            if ~isInstanceValid || forceNew
                if verbosity > 0
                    fprintf('Initializing FocalSweep...\n');
                end
                
                obj = core.FocalSweep('verbosity', verbosity);
                
                % Store as singleton
                instance = obj;
                
                if verbosity > 0
                    fprintf('FocalSweep ready.\n');
                end
            else
                % An instance already exists, bring it to the front
                try
                    figure(instance.gui.hFig);
                catch
                    % If bringing window to front fails, create a new instance
                    if verbosity > 0
                        fprintf('Creating new FocalSweep instance.\n');
                    end
                    obj = core.FocalSweep('verbosity', verbosity);
                    instance = obj;
                end
            end
            
            obj = instance;
        end
    end
end 