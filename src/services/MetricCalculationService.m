classdef MetricCalculationService < handle
    % MetricCalculationService - Pure business logic for metric calculations
    % Handles all metric computations, caching, and optimization
    % No UI dependencies - focused on core metric calculation functionality

    properties (Constant, Access = public)
        % Available metric types
        METRIC_TYPES = {'Std Dev', 'Mean', 'Max'}
        DEFAULT_METRIC = 'Std Dev'

        % Caching settings
        CACHE_ENABLED = true
        CACHE_MAX_SIZE = 100

        % Simulation parameters
        SIMULATION_NOISE_LEVEL = 0.1
        SIMULATION_PEAK_WIDTH = 50
    end

    properties (Access = private)
        ScanImageManager
        SimulationMode = true

        % Metric caching - initialized in constructor to avoid shared instances
        MetricCache
        CacheTimestamps
        CacheTimeout = 30  % seconds - configurable cache timeout

        % Current state
        CurrentMetricType = 'Std Dev'
        LastCalculatedMetrics = struct()
        LastPosition = [0, 0, 0]  % [X, Y, Z]
    end

    events
        MetricCalculated
        MetricTypeChanged
    end

    methods (Access = public)
        function obj = MetricCalculationService(scanImageManager)
            % Constructor - requires ScanImageManager dependency
            if nargin >= 1 && ~isempty(scanImageManager)
                obj.ScanImageManager = scanImageManager;
                obj.SimulationMode = scanImageManager.isSimulationMode();
            else
                error('MetricCalculationService requires a ScanImageManager instance');
            end

            % Initialize cache containers to avoid shared instances
            obj.MetricCache = containers.Map();
            obj.CacheTimestamps = containers.Map();
            
            obj.CurrentMetricType = obj.DEFAULT_METRIC;
            % Initialize metrics structure but don't store unused return value
            obj.initializeMetricsStructure();
        end

        function metrics = calculateAllMetrics(obj, position)
            % Calculate all available metrics for the current or specified position
            % position: [X, Y, Z] coordinates (optional, uses last known if not provided)

            if nargin >= 2 && ~isempty(position)
                obj.LastPosition = position;
            end

            % Check cache first
            cacheKey = obj.generateCacheKey(obj.LastPosition);
            if obj.CACHE_ENABLED && obj.isCacheValid(cacheKey)
                metrics = obj.MetricCache(cacheKey);
                obj.LastCalculatedMetrics = metrics;
                return;
            end

            % Initialize metrics structure
            metrics = obj.initializeMetricsStructure();

            try
                if obj.SimulationMode
                    % Generate simulated metrics
                    metrics = obj.calculateSimulatedMetrics(obj.LastPosition);
                else
                    % Get real image data and calculate metrics
                    pixelData = obj.ScanImageManager.getImageData();
                    if ~isempty(pixelData)
                        metrics = obj.calculateRealMetrics(pixelData);
                    else
                        % No data available - return NaN values
                        metrics = obj.setAllMetricsToNaN();
                    end
                end

                % Cache the results
                if obj.CACHE_ENABLED
                    obj.cacheMetrics(cacheKey, metrics);
                end

                obj.LastCalculatedMetrics = metrics;
                obj.notifyMetricCalculated(metrics);

            catch ME
                FoilviewUtils.logException('MetricCalculationService.calculateAllMetrics', ME);
                metrics = obj.setAllMetricsToNaN();
            end
        end

        function value = getCurrentMetric(obj, position)
            % Get the current selected metric value
            % position: [X, Y, Z] coordinates (optional)

            if nargin >= 2
                obj.calculateAllMetrics(position);
            elseif isempty(fieldnames(obj.LastCalculatedMetrics))
                obj.calculateAllMetrics();
            end

            fieldName = obj.metricTypeToFieldName(obj.CurrentMetricType);
            if isfield(obj.LastCalculatedMetrics, fieldName)
                value = obj.LastCalculatedMetrics.(fieldName);
            else
                value = NaN;
            end
        end

        function success = setMetricType(obj, metricType)
            % Set the current metric type
            success = false;

            if ~obj.isValidMetricType(metricType)
                FoilviewUtils.error('MetricCalculationService', 'Invalid metric type: %s', metricType);
                return;
            end

            oldType = obj.CurrentMetricType;
            obj.CurrentMetricType = metricType;

            if ~strcmp(oldType, metricType)
                obj.notifyMetricTypeChanged(oldType, metricType);
            end

            success = true;
        end

        function metricType = getMetricType(obj)
            % Get the current metric type
            metricType = obj.CurrentMetricType;
        end

        function types = getAvailableMetricTypes(obj)
            % Get all available metric types
            types = obj.METRIC_TYPES;
        end

        function metrics = getLastCalculatedMetrics(obj)
            % Get the last calculated metrics structure
            metrics = obj.LastCalculatedMetrics;
        end

        function clearCache(obj)
            % Clear the metric cache
            obj.MetricCache = containers.Map();
            obj.CacheTimestamps = containers.Map();
            FoilviewUtils.info('MetricCalculationService', 'Metric cache cleared');
        end

        function stats = getCacheStats(obj)
            % Get cache statistics
            stats = struct();
            stats.size = obj.MetricCache.Count;
            stats.maxSize = obj.CACHE_MAX_SIZE;
            stats.enabled = obj.CACHE_ENABLED;
            stats.hitRate = obj.calculateCacheHitRate();
        end

        function optimizeForAutoStepping(obj, enable)
            % Optimize metric calculation for auto-stepping mode
            if enable
                % Reduce cache timeout for more frequent updates
                obj.CacheTimeout = 5;
                FoilviewUtils.info('MetricCalculationService', 'Optimized for auto-stepping');
            else
                % Restore normal cache timeout
                obj.CacheTimeout = 30;
                FoilviewUtils.info('MetricCalculationService', 'Restored normal optimization');
            end
        end

        function value = calculateSpecificMetric(obj, pixelData, metricType)
            % Calculate a specific metric from pixel data
            % This is a utility method for external use

            if isempty(pixelData)
                value = NaN;
                return;
            end

            if ~obj.isValidMetricType(metricType)
                value = NaN;
                return;
            end

            try
                % Convert to double for calculations
                pixelData = double(pixelData);

                % Calculate the requested metric
                switch metricType
                    case 'Std Dev'
                        value = std(pixelData(:));
                    case 'Mean'
                        value = mean(pixelData(:));
                    case 'Max'
                        value = max(pixelData(:));
                    otherwise
                        value = std(pixelData(:));  % Default to Std Dev
                end

            catch ME
                FoilviewUtils.logException('MetricCalculationService.calculateSpecificMetric', ME);
                value = NaN;
            end
        end
    end

    methods (Access = private)
        function metrics = initializeMetricsStructure(obj)
            % Initialize the metrics structure with NaN values
            metrics = struct();
            for i = 1:length(obj.METRIC_TYPES)
                fieldName = obj.metricTypeToFieldName(obj.METRIC_TYPES{i});
                metrics.(fieldName) = NaN;
            end
        end

        function metrics = setAllMetricsToNaN(obj)
            % Set all metrics to NaN (error/no data state)
            metrics = obj.initializeMetricsStructure();
        end

        function metrics = calculateSimulatedMetrics(obj, position)
            % Generate simulated metrics based on position
            metrics = obj.initializeMetricsStructure();

            x = position(1);
            y = position(2);
            z = position(3);

            % Generate different simulated patterns for each metric
            for i = 1:length(obj.METRIC_TYPES)
                metricType = obj.METRIC_TYPES{i};
                fieldName = obj.metricTypeToFieldName(metricType);

                switch metricType
                    case 'Std Dev'
                        % Simulate focus-like behavior: peak at certain Z positions
                        baseValue = 50 - abs(mod(z, 100) - 50);
                        % Add XY influence
                        xyInfluence = 10 * exp(-((x^2 + y^2) / 10000));
                        metrics.(fieldName) = baseValue + xyInfluence + ...
                            obj.SIMULATION_NOISE_LEVEL * randn();

                    case 'Mean'
                        % Different pattern - decreases with distance from origin
                        distance = sqrt(x^2 + y^2 + z^2);
                        metrics.(fieldName) = 100 - mod(distance, 100) + ...
                            obj.SIMULATION_NOISE_LEVEL * randn();

                    case 'Max'
                        % Another pattern - periodic in Z with XY modulation
                        metrics.(fieldName) = 200 - mod(abs(z), 150) + ...
                            5 * sin(x/20) * cos(y/20) + ...
                            obj.SIMULATION_NOISE_LEVEL * randn();
                end

                % Ensure positive values
                metrics.(fieldName) = max(0, metrics.(fieldName));
            end
        end

        function metrics = calculateRealMetrics(obj, pixelData)
            % Calculate metrics from real pixel data
            metrics = obj.initializeMetricsStructure();

            if isempty(pixelData)
                return;
            end

            % Convert to double for calculations
            pixelData = double(pixelData);

            % Calculate all metrics
            for i = 1:length(obj.METRIC_TYPES)
                metricType = obj.METRIC_TYPES{i};
                fieldName = obj.metricTypeToFieldName(metricType);
                metrics.(fieldName) = obj.calculateSpecificMetric(pixelData, metricType);
            end
        end

        function fieldName = metricTypeToFieldName(~, metricType)
            % Convert metric type string to valid field name
            fieldName = strrep(metricType, ' ', '_');
        end

        function valid = isValidMetricType(obj, metricType)
            % Check if metric type is valid
            valid = ischar(metricType) && ismember(metricType, obj.METRIC_TYPES);
        end

        function cacheKey = generateCacheKey(~, position)
            % Generate cache key from position
            cacheKey = sprintf('%.2f_%.2f_%.2f', position(1), position(2), position(3));
        end

        function valid = isCacheValid(obj, cacheKey)
            % Check if cache entry is valid (exists and not expired)
            valid = false;

            if ~obj.MetricCache.isKey(cacheKey)
                return;
            end

            if ~obj.CacheTimestamps.isKey(cacheKey)
                return;
            end

            timestamp = obj.CacheTimestamps(cacheKey);
            currentTime = posixtime(datetime('now'));

            valid = (currentTime - timestamp) < obj.CacheTimeout;
        end

        function cacheMetrics(obj, cacheKey, metrics)
            % Cache metrics with timestamp
            try
                % Check cache size limit
                if obj.MetricCache.Count >= obj.CACHE_MAX_SIZE
                    obj.evictOldestCacheEntry();
                end

                obj.MetricCache(cacheKey) = metrics;
                obj.CacheTimestamps(cacheKey) = posixtime(datetime('now'));

            catch ME
                FoilviewUtils.logException('MetricCalculationService.cacheMetrics', ME);
            end
        end

        function evictOldestCacheEntry(obj)
            % Remove the oldest cache entry
            try
                if obj.CacheTimestamps.Count == 0
                    return;
                end

                keys = obj.CacheTimestamps.keys;
                timestamps = cell2mat(obj.CacheTimestamps.values);

                [~, oldestIdx] = min(timestamps);
                oldestKey = keys{oldestIdx};

                obj.MetricCache.remove(oldestKey);
                obj.CacheTimestamps.remove(oldestKey);

            catch ME
                FoilviewUtils.logException('MetricCalculationService.evictOldestCacheEntry', ME);
            end
        end

        function hitRate = calculateCacheHitRate(obj)
            % Calculate cache hit rate (placeholder - would need hit/miss counters)
            if obj.MetricCache.Count == 0
                hitRate = 0;
            else
                % Simplified calculation - in real implementation would track hits/misses
                hitRate = min(0.8, obj.MetricCache.Count / obj.CACHE_MAX_SIZE);
            end
        end

        function notifyMetricCalculated(obj, metrics)
            % Notify listeners that metrics have been calculated
            try
                eventData = struct();
                eventData.metrics = metrics;
                eventData.position = obj.LastPosition;
                eventData.timestamp = datetime('now');
                eventData.metricType = obj.CurrentMetricType;

                notify(obj, 'MetricCalculated', eventData);
            catch ME
                FoilviewUtils.logException('MetricCalculationService.notifyMetricCalculated', ME);
            end
        end

        function notifyMetricTypeChanged(obj, oldType, newType)
            % Notify listeners that metric type has changed
            try
                eventData = struct();
                eventData.oldType = oldType;
                eventData.newType = newType;
                eventData.timestamp = datetime('now');

                notify(obj, 'MetricTypeChanged', eventData);
            catch ME
                FoilviewUtils.logException('MetricCalculationService.notifyMetricTypeChanged', ME);
            end
        end
    end

    methods (Static)
        function [valid, errorMsg] = validateMetricType(metricType)
            % Static validation method for metric types
            valid = true;
            errorMsg = '';

            if ~ischar(metricType) && ~isstring(metricType)
                valid = false;
                errorMsg = 'Metric type must be a string';
                return;
            end

            if ~ismember(metricType, MetricCalculationService.METRIC_TYPES)
                valid = false;
                errorMsg = sprintf('Invalid metric type. Must be one of: %s', ...
                    strjoin(MetricCalculationService.METRIC_TYPES, ', '));
                return;
            end
        end

        function types = getStaticMetricTypes()
            % Get available metric types (static method)
            types = MetricCalculationService.METRIC_TYPES;
        end

        function defaultType = getStaticDefaultMetric()
            % Get default metric type (static method)
            defaultType = MetricCalculationService.DEFAULT_METRIC;
        end
    end
end