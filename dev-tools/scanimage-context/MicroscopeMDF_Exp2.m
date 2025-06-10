% Most Software Machine Data File

%% scanimage.SI (ScanImage)

% Global microscope properties
objectiveResolution = 29.7467;     % Resolution of the objective in microns/degree of scan angle

% Data file location

% Custom Scripts
startUpScript = 'setupFeedbackRecording';     % Name of script that is executed in workspace 'base' after scanimage initializes
shutDownScript = 'cleanupFeedbackRecording';     % Name of script that is executed in workspace 'base' after scanimage exits

fieldCurvatureZs = [];     % Field curvature for mesoscope
fieldCurvatureRxs = [];     % Field curvature for mesoscope
fieldCurvatureRys = [];     % Field curvature for mesoscope
fieldCurvatureTip = 0;     % Field tip for mesoscope
fieldCurvatureTilt = 0;     % Field tilt for mesoscope
useJsonHeaderFormat = false;     % Use JSON format for TIFF file header

minimizeOnStart = false;
widgetVisibility = true;

%% scanimage.components.CoordinateSystems (SI CoordinateSystems)
% SI Coordinate System Component.
classDataFileName = 'C:\Program Files\Vidrio\MicroscopeMDF_2023_1_0.ConfigData\2023\CoordinateSystems\25x Objective.mat';     % File containing the previously generated alignment data corresponding to the currently installed objective, SLM, scanners, etc.

%% scanimage.components.Motors (SI Motors)
% SI Stage/Motor Component.
motorXYZ = {'X Motor' 'Y Motor' 'LabJack'};     % Defines the motor for ScanImage axes X Y Z.
motorAxisXYZ = [1 1 1];     % Defines the motor axis used for Scanimage axes X Y Z.
scaleXYZ = [1 1 1];     % Defines scaling factors for axes.
backlashCompensation = [0 0 0];     % Backlash compensation in um (positive or negative)
moveTimeout_s = 10;     % Move timeout in seconds

%% scanimage.components.Photostim (SI Photostim)
photostimScannerName = '';     % Name of scanner (from first MDF section) to use for photostimulation. Must be a linear scanner
stimTriggerTerm = 1;     % Specifies the channel that should be used to trigger a stimulation. This a triggering port name such as D2.1 for vDAQ or PFI1 for the auxiliary IO board of an NI LinScan system.

% Monitoring DAQ AI channels
BeamAiId = [];     % AI channel to be used for monitoring the Pockels cell output

loggingStartTrigger = '';     % PFI line to which start trigger for logging is wired to photostim board. Leave empty for automatic routing via PXI bus

stimActiveOutputChannel = '';     % Digital terminal on stim board to output stim active signal. (e.g. on vDAQ: 'D1.6' on NI-DAQ hardware: '/port0/line0'
beamActiveOutputChannel = '1.6';     % Digital terminal on stim board to output beam active signal. (e.g. on vDAQ: 'D1.7' on NI-DAQ hardware: '/port0/line1'
slmTriggerOutputChannel = '1.7';     % Digital terminal on stim board to trigger SLM frame flip. (e.g. on vDAQ: 'D1.5' on NI-DAQ hardware: '/port0/line2'
pairStimActiveOutputChannel = false;     % Whether stimActiveOutputChannel should share its terminal with all the RggScan's auxiliary trigger 3 input
pairBeamActiveOutputChannel = true;     % Whether beamActiveOutputChannel should share its terminal with all the RggScan's auxiliary trigger 4 input

%% scanimage.components.scan2d.ResScan (ResScan)
% DAQ settings
rioDeviceID = 'RIO0';     % FlexRIO Device ID as specified in MAX. If empty, defaults to 'RIO0'
digitalIODeviceName = 'PXI1Slot5';     % String: Device name of the DAQ board or FlexRIO FPGA that is used for digital inputs/outputs (triggers/clocks etc). If it is a DAQ device, it must be installed in the same PXI chassis as the FlexRIO Digitizer

channelsInvert = [true false false false];     % Logical: Specifies if the input signal is inverted (i.e., more negative for increased light signal)

externalSampleClock = false;     % Logical: use external sample clock connected to the CLK IN terminal of the FlexRIO digitizer module
externalSampleClockRate = 8e+07;     % [Hz]: nominal frequency of the external sample clock connected to the CLK IN terminal (e.g. 80e6); actual rate is measured on FPGA

enableRefClkOutput = false;     % Enables/disables the 10MHz reference clock output on PFI14 of the digitalIODevice

% Scanner settings
resonantScanner = 'ResonantX';     % Name of the resonant scanner
xGalvo = 'GalvoX';     % Name of the x galvo scanner
yGalvo = 'GalvoY';     % Name of the y galvo scanner
beams = {'Pockels'};     % beam device names
fastZs = {};     % fastZ device names
shutters = {'Shutter'};     % shutter device names

extendedRggFov = false;     % If true and x galvo is present, addressable FOV is combination of resonant FOV and x galvo FOV.
keepResonantScannerOn = false;     % Always keep resonant scanner on to avoid drift and settling time issues

% Advanced/Optional
PeriodClockDebounceTime = 1e-07;     % [s] time the period clock has to be stable before a change is registered
TriggerDebounceTime = 5e-07;     % [s] time acquisition, stop and next trigger to be stable before a change is registered
reverseLineRead = 1;     % flips the image in the resonant scan axis

% Aux Trigger Recording, Photon Counting, and I2C are mutually exclusive

% Aux Trigger Recording
auxTriggersEnable = false;
auxTriggersTimeDebounce = 1e-06;     % [s] time an aux trigger needs to be high for registering an edge (seconds)
auxTriggerLinesInvert = [false;false;false;false];     % [logical] 1x4 vector specifying polarity of aux trigger inputs

% Photon Counting
photonCountingEnable = false;
photonCountingDisableAveraging = [];     % disable averaging of samples into pixels; instead accumulate samples
photonCountingScaleByPowerOfTwo = 8;     % for use with photonCountingDisableAveraging == false; scale count by 2^n before averaging to avoid loss of precision by integer division
photonCountingDebounce = 2.5e-08;     % [s] time the TTL input needs to be stable high before a pulse is registered

% I2C
I2CEnable = false;
I2CAddress = 0;     % [byte] I2C address of the FPGA
I2CDebounce = 5e-07;     % [s] time the I2C signal has to be stable high before a change is registered
I2CStoreAsChar = false;     % if false, the I2C packet bytes are stored as a uint8 array. if true, the I2C packet bytes are stored as a string. Note: a Null byte in the packet terminates the string
I2CDisableAckOutput = false;     % the FPGA confirms each packet with an ACK bit by actively pulling down the SDA line. I2C_DISABLE_ACK_OUTPUT = true disables the FPGA output

% Laser Trigger
LaserTriggerPort = '';     % Port on FlexRIO AM digital breakout (DIO0.[0:3]) where laser trigger is connected.
LaserTriggerFilterTicks = 0;
LaserTriggerSampleMaskEnable = false;
LaserTriggerSampleWindow = [0 1];

% Calibration data
scannerToRefTransform = [1 0 0;0 1 0;0 0 1];

%% scanimage.components.scan2d.LinScan (LinScan)
deviceNameAcq = 'RIO0';     % string identifying NI DAQ board for PMT channels input
deviceNameAux = 'PXI1Slot6';     % string identifying NI DAQ board for outputting clocks. leave empty if unused. Must be a X-series board

externalSampleClock = false;     % Logical: use external sample clock connected to the CLK IN terminal of the FlexRIO digitizer module
externalSampleClockRate = 8e+07;     % [Hz]: nominal frequency of the external sample clock connected to the CLK IN terminal (e.g. 80e6); actual rate is measured on FPGA

% Optional
channelsInvert = [true false false false];     % scalar or vector identifiying channels to invert. if scalar, the value is applied to all channels

xGalvo = 'GalvoX';     % x Galvo device name
yGalvo = 'GalvoY';     % y Galvo device name
fastZs = {};     % fastZ device names
beams = {'Pockels' 'MHWP'};     % fastZ device names
shutters = {'Shutter'};     % shutter device names

referenceClockIn = '';     % one of {'',PFI14} to which 10MHz reference clock is connected on Aux board. Leave empty for automatic routing via PXI bus
enableRefClkOutput = false;     % Enables/disables the export of the 10MHz reference clock on PFI14

% Acquisition
channelIDs = [0 1 2 3];     % Array of numeric channel IDs for PMT inputs. Leave empty for default channels (AI0...AIN-1)

% Advanced/Optional:
stripingEnable = true;     % enables/disables striping display
stripingMaxRate = 10;     % [Hz] determines the maximum display update rate for striping
maxDisplayRate = 30;     % [Hz] limits the maximum display rate (affects frame batching)
internalRefClockSrc = '';     % Reference clock to use internally
internalRefClockRate = [];     % Rate of reference clock to use internally
secondaryFpgaFifo = false;     % specifies if the secondary fpga fifo should be used

LaserTriggerPort = '';     % Port on FlexRIO AM digital breakout (DIO0.[0:3]) or digital IO DAQ (PFI[0:23]) where laser trigger is connected.
LaserTriggerFilterTicks = 0;
LaserTriggerSampleMaskEnable = false;
LaserTriggerSampleWindow = [0 1];

% Calibration data
scannerToRefTransform = [1 0 0;0 1 0;0 0 1];
% Output Clocks
startTriggerTermOut = '';     % Port on digital IO DAQ (PX.X) to output pulse at start of acquisition.
lineClockTermOut = '';     % Port on digital IO DAQ (PX.X) to output start of line.
pixelClockTermOut = '';     % Port on digital IO DAQ (PFI) to output start of pixel.

%% dabs.generic.ResonantScannerAnalog (ResonantX)
AOZoom = '/PXI1Slot5/AO1';     % zoom control terminal  e.g. '/vDAQ0/AO0'
DOEnable = '';     % digital enable terminal e.g. '/vDAQ0/D0.1'
DISync = '/PXI1Slot5/PFI0';     % digital sync terminal e.g. '/vDAQ0/D0.0'

nominalFrequency = 7910;     % nominal resonant frequency in Hz
angularRange = 26;     % total angular range in optical degrees (e.g. for a resonant scanner with -13..+13 optical degrees, enter 26)
voltsPerOpticalDegrees = 0.1923;     % volts per optical degrees for the control signal
settleTime = 0.5;     % settle time in seconds to allow the resonant scanner to turn on

% Calibration Settings
amplitudeToLinePhaseMap = [3.75 -1.225e-06;12.5 -1.29167e-06;15 1.63333e-06];     % translates an amplitude (degrees) to a line phase (seconds)
amplitudeToFrequencyMap = [3.75 7934.72;7.5 7932.41;8.333 7932.1;9.375 7931.99;10.714 7931.72;12.5 7931.19;13.636 7930.6;15 7931.84];     % translates an amplitude (degrees) to a resonant frequency (Hz)
amplitudeLUT = [8.33333 8.875];     % translates a nominal amplitude (degrees) to an output amplitude (degrees)

minimizeOnStart = false;

%% dabs.generic.GalvoPureAnalog (GalvoX)
AOControl = '/PXI1Slot6/AO1';     % control terminal  e.g. '/vDAQ0/AO0'
AOOffset = '';     % control terminal  e.g. '/vDAQ0/AO0'
AIFeedback = '/PXI1Slot6/AI3';     % feedback terminal e.g. '/vDAQ0/AI0'

angularRange = 15;     % total angular range in optical degrees (e.g. for a galvo with -20..+20 optical degrees, enter 40)
voltsPerOpticalDegrees = 0.25;     % volts per optical degrees for the control signal
voltsOffset = 0;     % voltage to be added to the output
parkPosition = 0;     % park position in optical degrees
slewRateLimit = Inf;     % Slew rate limit of the analog output in Volts per second

% Calibration settings
feedbackVoltLUT = [0.0249164 1.875;0.0549265 1.45833;0.0635915 1.04167;0.0820265 0.625;0.115463 0.208333;0.139367 -0.208333;0.147614 -0.625;0.153204 -1.04167;0.15916 -1.45833;0.19939 -1.875];     % [Nx2] lut translating feedback volts into position volts
offsetVoltScaling = 1;     % scalar factor for offset volts

minimizeOnStart = false;

%% dabs.generic.GalvoPureAnalog (GalvoY)
AOControl = '/PXI1Slot6/AO0';     % control terminal  e.g. '/vDAQ0/AO0'
AOOffset = '';     % control terminal  e.g. '/vDAQ0/AO0'
AIFeedback = '/PXI1Slot6/AI5';     % feedback terminal e.g. '/vDAQ0/AI0'

angularRange = 15;     % total angular range in optical degrees (e.g. for a galvo with -20..+20 optical degrees, enter 40)
voltsPerOpticalDegrees = 0.25;     % volts per optical degrees for the control signal
voltsOffset = 0;     % voltage to be added to the output
parkPosition = 0;     % park position in optical degrees
slewRateLimit = Inf;     % Slew rate limit of the analog output in Volts per second

% Calibration settings
feedbackVoltLUT = [1.54511 1.875;1.77781 1.45833;2.02413 1.04167;2.33046 0.625;2.72063 0.208333;3.18581 -0.208333;3.76167 -0.625;4.44657 -1.04167;5.29313 -1.45833;6.36394 -1.875];     % [Nx2] lut translating feedback volts into position volts
offsetVoltScaling = 1;     % scalar factor for offset volts

minimizeOnStart = false;

%% dabs.generic.BeamModulatorFastAnalog (Pockels)
AOControl = '/PXI1Slot5/AO0';     % control terminal  e.g. '/vDAQ0/AO0'
AIFeedback = '/PXI1Slot5/AI6';     % feedback terminal e.g. '/vDAQ0/AI0'

outputRange_V = [0 2];     % Control output range in Volts
feedbackUsesRejectedLight = false;     % Indicates if photodiode is in rejected path of beams modulator.
calibrationOpenShutters = {'Shutter'};     % List of shutters to open during the calibration. (e.g. {'Shutter1' 'Shutter2'}

powerFractionLimit = 1;     % Maximum allowed power fraction (between 0 and 1)

% Calibration data
powerFraction2ModulationVoltLut = zeros(0,2);
powerFraction2PowerWattLut = [0 0;1 0.003];
powerFraction2FeedbackVoltLut = zeros(0,2);
feedbackOffset_V = 0;

% Calibration settings
calibrationNumPoints = 20;     % number of equidistant points to measure within the analog output range
calibrationAverageSamples = 50;     % per analog output voltage, average N analog input samples. This helps to reduce noise
calibrationNumRepeats = 5;     % number of times to repeat the calibration routine. the end result is the average of all calibration runs
calibrationSettlingTime_s = 0.1;     % pause between measurement points. this allows the beam modulation to settle
calibrationFlybackTime_s = 0.1;     % pause between calibration runs

% Advanced Settings. Note: these settings are unused for vDAQ based systems
modifiedLineClockIn = '';     % Terminal to which external beam trigger is connected. Leave empty for automatic routing via PXI/RTSI bus
frameClockIn = '';     % Terminal to which external frame clock is connected. Leave empty for automatic routing via PXI/RTSI bus
referenceClockIn = '';     % Terminal to which external reference clock is connected. Leave empty for automatic routing via PXI/RTSI bus
referenceClockRate = 1e+07;     % if referenceClockIn is used, referenceClockRate defines the rate of the reference clock in Hz. Default: 10e6Hz

widgetVisibility = 1;

%% dabs.thorlabs.KinesisMotor (LabJack)
serial = '49902840';     % Serial of the thorlabs stage e.g. '45155204'
kinesisInstallDir = 'C:\Program Files\Thorlabs\Kinesis';     % Path to Thorlabs Kinesis installation
homingTimeout_s = 1000;     % Timeout for homing move in seconds
units = 'um';     % Units for the device. One of {'um' 'deg'}
startupSettingsMode = 'UseDeviceSettings';     % Settings the device should use. One of {"Reset RealToDeviceUnit","Use Device Settings","Use File Settings","Use Configured Settings"}
minimizeOnStart = false;

%% dabs.thorlabs.KinesisMotor (X Motor)
serial = '27003557';     % Serial of the thorlabs stage e.g. '45155204'
kinesisInstallDir = 'C:\Program Files\Thorlabs\Kinesis';     % Path to Thorlabs Kinesis installation
homingTimeout_s = 100;     % Timeout for homing move in seconds
units = 'um';     % Units for the device. One of {'um' 'deg'}
startupSettingsMode = 'UseDeviceSettings';     % Settings the device should use. One of {"Reset RealToDeviceUnit","Use Device Settings","Use File Settings","Use Configured Settings"}

%% dabs.thorlabs.KinesisMotor (Y Motor)
serial = '27504762';     % Serial of the thorlabs stage e.g. '45155204'
kinesisInstallDir = 'C:\Program Files\Thorlabs\Kinesis';     % Path to Thorlabs Kinesis installation
homingTimeout_s = 100;     % Timeout for homing move in seconds
units = 'um';     % Units for the device. One of {'um' 'deg'}
startupSettingsMode = 'UseDeviceSettings';     % Settings the device should use. One of {"Reset RealToDeviceUnit","Use Device Settings","Use File Settings","Use Configured Settings"}

%% dabs.generic.DigitalShutter (Shutter)
DOControl = '/PXI1Slot5/PFI12';     % control terminal  e.g. '/vDAQ0/DIO0'
invertOutput = false;     % invert output drive signal to shutter
openTime_s = 0.5;     % settling time for shutter in seconds
shutterTarget = 'Excitation';     % one of {', 'Excitation', 'Detection'}


%% scanimage.components.UserFunctions (User Functions)
% Event Name | User Function | Arguments | Enable
userFunctionsCfg = {
'acqModeStart'    'setupFeedbackRecording'    {} true  
'frameAcquired'   'saveImageMetadata'         {} true
'acqDone'         'cleanupFeedbackRecording'  {} true
};



