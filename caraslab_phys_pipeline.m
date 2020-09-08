%caraslab_phys_pipeline.m
%
%This pipeline transforms raw -sev data into -mat format, removes
%artifacts, bandpass filters the data, applies common average referencing,
%and creates16 bit binary -dat files for sorting with kilosort. Raw
%(filtered) and cleaned (artifact removed, referenced) data streams can be
%compared using a GUI to ensure that cleaned data look good before sorting. 


%% MAKE A CHANNELMAP FILE
%This function creates a channel map for a specific electrode probe array.
%You only need to run this function if the map for your specific probe
%doesn't already exist.
%  
%   probetype:  specifies the probe style used for recordings
%                   'NNBuz5x1264':  Neuronexus Buzsaki 5x12 H64LP
%                   'NN4x16Poly64': Neuronexus A4x16 Poly2 H64LP
%                   'NNA4x16Lin64': Neuronexus A4x16 Poly2 Linear H64LP
%                   'CamASSY156P':  Cambridge NeuroTech ASSY156 P Series
%                   'NN4x4H16':     Neuronexus A4x4 200-200-1250 H16 21mm
%                   'NNA2x32':     Neuronexus A2x32-5mm-25-200-177

% Tankdir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/TDT tank/SUBJ-ID-28-200615-141009';

Savedir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/Matt/Sorted/SUBJ-ID-13-200125-124647';
% Savedir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/Matt/Sorted/SUBJ-ID-14-200126-125925';
% Savedir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/Matt/Sorted/SUBJ-ID-26-200614-103221';
% Savedir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/Matt/Sorted/SUBJ-ID-27-200614-104657';
% Savedir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/Matt/Sorted/SUBJ-ID-28-200615-141009';

Behaviordir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/matlab_data_files/SUBJ-ID-13';
% Behaviordir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/matlab_data_files/SUBJ-ID-14';
% Behaviordir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/matlab_data_files/SUBJ-ID-26';
% Behaviordir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/matlab_data_files/SUBJ-ID-27';
% Behaviordir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/matlab_data_files/SUBJ-ID-28';

chanMapSavedir = '/home/caras/Documents/Matt/Spike sorting code/channelmaps';
Probetype = 'NNA4x16Lin64'; 
chanMap = [chanMapSavedir '/' Probetype '.mat']; 

sel = 0;  % Select subfolders; 0 will run all subfolders


%% Extract behavioral timestamps from _info.mat file
batch_behav_pipeline(Behaviordir,Savedir,sel)
% 
% %% Channel map creation
caraslab_createChannelMap(chanMapSavedir,Probetype);
% 
% %% CONVERT *.SEV AND TANK DATA TO *.MAT FILE
% %   Function to reformat and save ephys data from TDT.
% %
% %   FIRST you must manually copy the .sev files from RS4 data streamer into
% %   the appropriate TDT tank block.
% %
% %   Input variables:
% %       Tankdir:    path to tank directory
% %
% %       Savedir:    path to directory where -mat and -csv files will be saved
% %
% %       sel:        if 0 or omitted, program will cycle through all BLOCKS
% %                   in the tank directory. 
% %                   
% %                   if 1, user will be prompted to select a BLOCK
% %  
% %   Uses TDTbin2mat to reformat tank data to a matlab struct. 
% %   Two files are saved:    
% %       (1) A -mat file containing an MxN matrix of raw voltages, where 
% %               M = the number of samples, and 
% %               N = the number of channels
% %
% %       (2) A -info file containing supporting information, including
% %               sampling rate, epocs, and timing
% 
% 
% epData = caraslab_reformat_synapse_data(Tankdir,Savedir,sel);
% 
% %% CREATE KILOSORT CONFIGURATION FILE
% % This function sets configuration parameters for kilosort. It also
% % establishes the binary path for each future binary dataset.
% caraslab_createconfig(Savedir,chanMap,sel)
% 
% 
% %% CREATE *DAT BINARY FILE AND DELINE
% % This function detects bad channels by RMS thresholds and saves them in ops.igood
% % then it rescales and converts -mat files to 16 bit integer -dat files
% % TODO? change this to be chunkwise so it doesn't hog RAM
% caraslab_mat2dat(Savedir,sel)
% 
% %% FILTERING BEFORE KILOSORT
% % This function takes .dat files and employs in this order:
% % 1. Comb filter
% % 2. Kilosort GPU-based chunkwise filter
% % 3. Median-CAR filter
% % 4. Saves a filename_CLEAN.dat file
% caraslab_batch_gpufilter(Savedir, sel)
% 
% 
% %% RUN KILOSORT caraslab_kilosort(Savedir,sel)
% 
% %This function runs kilosort on the selected data.
% caraslab_kilosort(Savedir,sel)
% 
% %% GO HAVE FUN IN PHY!
% 
% %         _             _   _                _ 
% %        | |           | | (_)              | |
% %   _ __ | |__  _   _  | |_ _ _ __ ___   ___| |
% %  | '_ \| '_ \| | | | | __| | '_ ` _ \ / _ \ |
% %  | |_) | | | | |_| | | |_| | | | | | |  __/_|
% %  | .__/|_| |_|\__, |  \__|_|_| |_| |_|\___(_)
% %  | |           __/ |                         
% %  |_|          |___/                          
% 
% %% EXTRACT SPIKE TIMES AND WAVEFORM MEASUREMENTS 
% %This function runs kilosort on the selected data.
% get_timestamps_and_wf_measurements(Savedir,sel)