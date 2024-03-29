%caraslab_EPhysIntan_pipeline.m
%
%This pipeline transforms raw -openEphys data into -dat format, 
% highpass filters the data and applies common average referencing before
% sorting with kilosort 2.

%% 
%% IMPORTANT: THIS PIPELINE HAS NOT BEEN THOROUGHLY TESTED/OPTIMIZED
%%

% Note that this pipeline was designed to be modular, i.e. you run one bit
% at a time and you can add/remove/replace modules 

% Wrtten by M Macedo-Lima; April 2021

%% Set your paths

% Tankdir: Where your Raw files are; This path should be a
%   subject's folder with subfolder representing different recording sessions

% Savedir: Where you wish to save the processed files

% Behaviordir: Where the ePsych behavior files are; -mat files will be
%   combined into a single file. Before running this, group similar sessions
%   into folders named: 
%   shock_training, psych_testing, pre_passive, post_passive

% chanMapSavedir: where your channel maps are

% Probetype: what kind of channel map you are using
%   Only the following have been set up:
%               'NNBuz5x1264':  Neuronexus Buzsaki 5x12 H64LP
%               'NN4x16Poly64': Neuronexus A4x16 Poly2 H64LP
%               'NNA4x16Lin64': Neuronexus A4x16 Poly2 Linear H64LP
%               'NNA2x32':     Neuronexus A2x32-5mm-25-200-177

% sel: whether you want to run all or a subset of the folders. If 1, you
%   will be prompted to select folders. Multiple folders can be selected
%   using Ctrl or Shift

% rootH: path for temp Kilosort file. Should be a fast SSD


Behaviordir = '/mnt/CL_4TB_1/matlab_data_files';

Tankdir = '/mnt/CL_4TB_2/temp_tanks/SUBJ-ID-153';
Savedir =  '/mnt/CL_4TB_2/Matt/OFCmuscimol_ACxrecording/Sorting/SUBJ-ID-153'; 
Probetype = 'NNBuz5x1264';
badchannels = [];

chanMapSavedir = '/home/matheus/Documents/Spike sorting code/channelmaps';
chanMap = [chanMapSavedir '/' Probetype '_intan.mat']; 

% path to temporary binary file for Kilosort (same size as data, should be on fast SSD)
rootH = '/home/matheus/Documents'; 

sel = 1;  % Select subfolders; 0 will run all subfolders

%% 1. MAKE A CHANNELMAP FILE
% This function creates a channel map for a specific electrode probe array.
%   You only need to run this function if the map for your specific probe
%   doesn't already exist.
caraslab_createChannelMap(chanMapSavedir,Probetype, 'intan');

%% 2. CONVERT *.SEV AND TANK DATA TO *.MAT FILE
%   Function to reformat and save ephys data from TDT.
%
%   FIRST you must manually copy the .sev files from RS4 data streamer into
%   the appropriate TDT tank block.
%
%   Input variables:
%       Tankdir:    path to tank directory
%
%       Savedir:    path to directory where -mat and -csv files will be saved
%
%       sel:        if 0 or omitted, program will cycle through all BLOCKS
%                   in the tank directory. 
%                   
%                   if 1, user will be prompted to select a BLOCK
%  
%   Uses TDTbin2mat to reformat tank data to a matlab struct. 
%   Two files are saved:    
%       (1) A -mat file containing an MxN matrix of raw voltages, where 
%               M = the number of channels
%               N = the number of samples
%
%       (2) A -info file containing supporting information, including
%               sampling rate, epocs, and timing
caraslab_reformat_intan_data(Tankdir, Savedir, sel);


%% 3. Output timestamps info
% This pipeline takes ePsych .mat behavioral files, combines and analyzes them and
% outputs files ready for further behavioral analyses and for aligning
% timestamps with neural recordings
% This pipeline also incorporates ephys recordings
% in the processing to extract timestamps related to spout and stimulus
% delivery

% IMPORTANT: if behavior is relevant, run this now so that createconfig can
% extract information about how much of the beginning of the recording to 
% skip due to noise

% IMPORTANT 2: organize your behavior files into subfolders to be analyzed together , e.g.
% shockTraining_pre, shockTraining_active, psychTesting_active, psychTesting_muscimol etc
% select those folders when prompted (you can select multiple folders)
caraslab_behav_pipeline(Savedir, Behaviordir, sel, 'intan');


%% 4. CREATE KILOSORT CONFIGURATION FILE
% This function sets configuration parameters for kilosort. It also
%   establishes the binary path for each future binary dataset.

%   IMPORTANT: this function is a  'living' function, i.e. you should edit it
%   appropriately for every subject if necessary
% e.g. whether to CAR/comb filter; template size and more...
caraslab_createconfig(Savedir,chanMap,sel, badchannels, 0, 'intan')

% 
% %% 5. CREATE *DAT BINARY FILE
% % This function detects bad channels by RMS thresholds and saves them in ops.igood
% %   Bad channels detected this way are currently not used for anything, but it
% %   could be helpful to signal unknown bad channels
% % Then, this function rescales and converts -mat files to 16 bit integer -dat files
% % TODO: change this to be chunkwise so it doesn't hog RAM
% caraslab_intan_mat2dat(Savedir,sel)


%% 6. REMOVE ARTIFACTS AND FILTER
% This function takes .dat files and employs in this order:
% 1. Comb filter (if ops.comb==1)
% 2. Median-CAR filter (if ops.CAR==1)
% 3. Kilosort-inspired GPU-based chunkwise filter
% 4. Saves a filename_CLEAN.dat file
caraslab_preprocessdat(Savedir, sel)


%% 7. CONCATENATE SAME DAY RECORDINGS
% This function searches the recording folders and concatenates *CLEAN.dat files
% within folders that have the same date in order of session number. A new file and directory will be
% created with Date_concat name (e.g. 201125_concat).
% This function also creates a config.mat within each concat folder with
% some useful parameters about the concatenation; plus it outputs a csv
% file with the continuous breakpoints where one file ends and another
% starts
caraslab_concatenate_sameDay_recordings(Savedir,sel, chanMap, 'intan')


%% 8. CONCATENATE SAME DEPTH RECORDINGS ACROSS DAYS
% % not currently in use
% NchanTOT = 64;
% NT = 32832;  % A reasonable batch size. Reduce if out of memory
% caraslab_concatenate_sameDepth_recordings(Savedir, sel, NchanTOT, NT)

%% 9. RUN KILOSORT
%   This function runs kilosort on the selected data.
% rootH is the path to the kilosort temp file; Better if a fast SSD
caraslab_kilosort(Savedir, sel, rootH)


%% 10. ELIMINATE NOISE

% NEED TO TWEAK PARAMETERS INSIDE THIS FUNCTION. DEFAULT (ALLEN INSTITUDE)
% PARAMETERS ARE GETTING RID OF GOOD CLUSTERS WITH THE NOISE

% This function eliminates noise by running an AllenInstitute python script
% I didn't translate it to MatLab, but instead adapted it to run from
% within MatLab by shuffling variables back and forth from a python
% evironment; The Python-from-MatLab pipeline is a little clunky...
% py_code_folder = '/home/matheus/Documents/Spike sorting code/sortingQuality-master/helpers';
% id_noise_templates_wrapper(Savedir, sel, 1, py_code_folder)

%% 11. REMOVE DOUBLE-COUNTED SPIKES
% This function removes potential double-counted spikes detected by
% kilosort within one cluster and among clusters of the same shank (spikes within 0.15 ms are deleted)
% Can be run either right after kilosort or after manual curation.
% Adapted from the Allen Brain Institute github
remove_double_counted_spikes(Savedir, sel, 1)


%% 12. GO HAVE FUN IN PHY!  
%         _             _   _                _ 
%        | |           | | (_)              | |
%   _ __ | |__  _   _  | |_ _ _ __ ___   ___| |
%  | '_ \| '_ \| | | | | __| | '_ ` _ \ / _ \ |
%  | |_) | | | | |_| | | |_| | | | | | |  __/_|
%  | .__/|_| |_|\__, |  \__|_|_| |_| |_|\___(_)
%  | |           __/ |                         
%  |_|          |___/                          


%% 13. EXTRACT SPIKE TIMES AND WAVEFORM MEASUREMENTS 
% This function retrieves timestamps and waveforms from phy files
% Outputs are .txt files with timestamps, .csv and .pdf files with waveform
% measurements and plots
% Because Kilosort2 likes 150Hz high-pass filtered data, this function will
% also refilter the data with a 300-6000Hz bandpass filter and save a new
% ~~CLEAN300Hz.dat
show_plots = 1;
filter_300hz = 1;
get_timestamps_and_wf_measurements(Savedir, sel, show_plots, filter_300hz)


%% 14. EXTRACT WAVEFORMS PLOTS WITH PROBE GEOMETRY
% This function reads the probe geometry in chann el map and outputs the
% spike means and SEM organized in space in a pdf. If filter_300hz==0, it will
% search for the 300hz bandpass filtered file. Otherwise, it will filter
% again
show_plots = 1;
filter_300hz = 0;
plot_unit_shanks(Savedir, sel, show_plots, filter_300hz)

%% 15. QUALITY METRICS
% This function runs 3 quality control metrics on the curated clusters:
% 1. ISI violation false positive rate: how many false positive spikes in a
%   cluster. Good units < 0.5
% 2. Fraction of spikes missing: based on the probability distribution of 
%   spikes detected for a unit, how many are estimated to be missing? Good
%   units < 0.1
% 3. Presence ratio: for how much of the recording is a unit present? The
%   recording time is divided in 100 bins and the fraction of bins with at
%   least one spike present is calculated. Good units > 0.9
% Adapted from the Allen Brain Institute github
show_plots = 1;
filter_300hz = 0;
cluster_quality_metrics(Savedir, sel, show_plots, filter_300hz)

%% 16. PCA COMPARISONS BETWEEN DAYS
% This function loops through recording folders and compares waveforms between
% consecutive days if they occured on the same shank. The output is a plot 
% showing the compared waveforms and the correlations between the PC scores 
% up to the 3rd PC. It also outputs a csv file per comparison with the PC scores.
show_plots = 1;
filter_300hz = 0;
pca_compare_waveforms(Savedir, sel, show_plots, filter_300hz)

%% 17. EXTRACT AND COMPILE FILES FOR ANALYSIS
% This function walks through all selected folders and copies the relevant files
% to a structured folder system in the parent directory to Savedir
compile_data_for_analyses(Savedir, sel)