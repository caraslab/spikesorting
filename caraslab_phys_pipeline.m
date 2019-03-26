%caraslab_phys_pipeline


%% MAKE A CHANNELMAP FILE
%This function creates a channel map for a specific electrode probe array.
%You only need to run this function if the map for your specific probe
%doesn't already exist.
%  
%   probetype:  specifies the probe style used for recordings
%                   'NNBuz5x1264':  Neuronexus Buzsaki 5x12 H64LP
%                   'NN4x16Poly64': Neuronexus A4x16 Poly2 H64LP
%                   'NNA4x16Lin64': Neuronexus A4x16 Linear  H64LP
%                   'CamASSY156P':  Cambridge NeuroTech ASSY156 P Series
%                   'NN4x4H16':     Neuronexus A4x4 200-200-1250 H16 21mm

Savedir = '/Users/Melissa/Documents/Professional/NYU/SanesLab/ActiveProjects/OFCRecordings/ChannelMaps/';
Probetype = 'NNBuz5x1264'; 

caraslab_createChannelMap(Savedir,Probetype)

%% CONVERT *.SEV AND TANK DATA TO *.MAT FILE
%   Function to reformat and save ephys data from TDT.
%
%   FIRST you must manually copy the .sev files from RS4 data streamer into
%   the appropriate TDT tank block.
%
%   Input variables:
%       Tankdir:    path to tank directory
%
%       Savedir:    path to directory where -mat files will be saved
%
%       sel:        if 0 or omitted, program will cycle through all BLOCKS
%                   in the tank directory. 
%                   
%                   if 1, user will be prompted to select a BLOCK
%  
%   Uses TDTbin2mat to reformat tank data to a matlab struct, and
%   saves as a -mat file in specified folder.


Tankdir = '/Users/Melissa/Documents/Professional/NYU/SanesLab/ActiveProjects/OFCRecordings/TDTTanks/';
Savedir = '/Users/Melissa/Documents/Professional/NYU/SanesLab/ActiveProjects/OFCRecordings/MATPhysFiles/';
sel = 0;

epData = caraslab_reformat_synapse_data(Tankdir,Savedir,sel);

%% CREATE BINARY *.DAT FILE AND CREATE KILOSORT CONFIGURATION FILE
% This function extracts the streamed array from a -mat file, saves it as a
% -dat file, and sets configuration parameters for kilosort.


useGPU = 0; %or 1

datadir = '/Users/Melissa/Documents/Professional/NYU/SanesLab/ActiveProjects/OFCRecordings/MATPhysFiles/';
binarydir = '/Users/Melissa/Documents/Professional/NYU/SanesLab/ActiveProjects/OFCRecordings/BinaryFiles/';
chanMap = '/Users/Melissa/Documents/Professional/NYU/SanesLab/ActiveProjects/OFCRecordings/ChannelMaps/NNBuz5x1264.mat'; 
sel = 1; %or 0 to cycle through all files

caraslab_createconfig(useGPU,datadir,binarydir,chanMap,sel)

%% APPLY COMMON AVERAGE REFERENCING
%This function applies common average referencing to data. See Ludwig
%(2009) for more details on the algorithm. The code that actually applies
%the CAR was taken from the https://github.com/cortex-lab/spikes repo,
%which houses code from the Harris and Carandini labs at UCL.

datadir = '/Users/Melissa/Documents/Professional/NYU/SanesLab/ActiveProjects/OFCRecordings/BinaryFiles/';
sel = 0; %or 0;

caraslab_CAR(datadir,sel)

%% RUN KILOSORT 
%This function runs kilosort on the selected data.

datadir = '/Users/Melissa/Documents/Professional/NYU/SanesLab/ActiveProjects/OFCRecordings/BinaryFiles/';
sel = 0; %or 0

caraslab_kilosort(datadir,sel)