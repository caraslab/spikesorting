function caraslab_createconfig(useGPU,datadir,binarydir,chanMap,sel)
%caraslab_createconfig(useGPU,datadir,binarydir,chanMap,sel)
%
% This function extracts the streamed array from a -mat file, saves it as a
% -dat file, and sets configuration parameters for kilosort.
% 
% Input variables:
%   useGPU:     if 1, will run the code on a Nvidia GPU (much faster, but
%               requires mexGPUall first).
%
%               if 0, will run the code on built in CPU (slower)
%
%   datadir:    path where data (-mat) files are stored
%
%   binarydir:  path where binary data files (-dat) will be saved
%
%   chanMap:    name of channel map for probe (include full path and
%               extension)
%
%   sel:        if 0 or omitted, program will cycle through all files
%               in the data directory. 
%                   
%               if 1, user will be prompted to select a file
%
%Written by ML Caras Mar 26 2019

%Validate inputs
narginchk(4,5)
if ~exist(datadir,'dir')
    fprintf('\nCannot find data directory!\n')
    return
end

%Check if binary directory exists. If it doesn't, create it now.
if ~exist(binarydir,'dir')
    [success,message,messageID] = mkdir(Savedir);
    
    %Stop if directory cannot be created, and display reason why
    if ~success
        message %#ok<*NOPRT>
        messageID
        return
    end   
end

%Check that channel map exists
if ~exist(chanMap,'file')
    fprintf('\nCannot find channel map!\n')
    return
end

%Default to cycling through all -mat files
if nargin < 5
    sel = 0;   
end


if ~sel
    %Get a list of all files in the data directory
    files = caraslab_lsf(datadir,'*.mat');
    filenames = extractfield(files,'name');

elseif sel  
    %Prompt user to select file
    [fname,~,~] = uigetfile([datadir,'*.mat'],'Select file to process');
    filenames = {fname};  
end


%Loop through files
for i = 1:numel(filenames)
    clear temp ops
    
    datafile = fullfile(datadir,filenames{i});
     
    %Load -mat data file
    fprintf('Loading -mat file: %s.......\n', filenames{i})
    tic;
    temp = load(datafile);
    tEnd = toc;
    fprintf('Loaded in: %d minutes and %f seconds\n', floor(tEnd/60),rem(tEnd,60));
    
    %Get the sampling rate and number of channels
    ops.fs = temp.epData.streams.RSn1.fs;
    ops.NchanTOT = numel(temp.epData.streams.RSn1.channels); %both active and dead
    ops.Nchan = ops.NchanTOT - 1;              % number of active channels (omit if already in chanMap file)
    ops.Nfilt = 32*floor((ops.Nchan*2)/32); % number of clusters to use (2-4 times more than Nchan, should be a multiple of 32)
    
    %Format the data for binary file
    dat = int16(temp.epData.streams.RSn1.data);
    
    %Create the path for the binary file
    [~,name,~] = fileparts(datafile);
    filepath = strcat(binarydir,name);
    if ~exist(filepath,'dir')
        [success,message,messageID] = mkdir(filepath);
        
        %Stop if binary directory cannot be created
        if ~success
            message
            messageID
            return
        end
    end
    
    ops.fbinary = fullfile(filepath,strcat(name,'.dat')); 
    
    %Write the data to a binary file
    fid = fopen(ops.fbinary,'w');
    if fid == -1
        fprintf('Cannot create binary file!')
        return
    end
    
    fprintf('Writing binary file: %s.......\n', strcat(name,'.dat'))
    tic;
    fwrite(fid,dat,'int16'); %must be 16 bit integer
    fclose(fid);
    tEnd = toc;
    fprintf('Finished in: %d minutes and %f seconds\n', floor(tEnd/60),rem(tEnd,60));
    
    %Define the channel map and associated parameters
    ops.chanMap  = chanMap;
    ops.criterionNoiseChannels = 0.2; % fraction of "noise" templates allowed to span all channel groups (see caraslab_createChannelMap for more info).
    
    
    
    %Set some parameters (defaults from Kilosort repo in parentheses)
    ops.GPU                 = useGPU;   % whether to run this code on an Nvidia GPU (much faster, mexGPUall first)
    ops.parfor              = 1;        % whether to use parfor to accelerate some parts of the algorithm
    ops.verbose             = 1;        % whether to print command line progress
    ops.showfigures         = 1;        % whether to plot figures during optimization
    
    ops.datatype            = 'dat';                                    % binary ('dat', 'bin') or 'openEphys'
    ops.fproc               = fullfile(filepath,'temp_wh.dat');         % residual from RAM of preprocessed data
    ops.root               =  filepath;                                 % where kilosort output will be stored. should be same as where -dat file is stored
    
    ops.nNeighPC            = 12;            % visualization only (Phy): number of channnels to mask the PCs, leave empty to skip (12)
    ops.nNeigh              = 16;            % visualization only (Phy): number of neighboring templates to retain projections of (16)
    
    
    
    %Set options for channel whitening
    ops.whitening           = 'full';   % type of whitening (default 'full', for 'noSpikes' set options for spike detection below)
    ops.nSkipCov            = 1;        % compute whitening matrix from every N-th batch (1)
    if ops.Nchan < 32
        ops.whiteningRange = Inf;
    else
        ops.whiteningRange = 32;       % how many channels to whiten together (Inf for whole probe whitening, should be fine if Nchan<=32)
    end
    
    
    %Set other options for controlling the model and optimization
    ops.Nrank               = 3;                        % matrix rank of spike template model (3)
    ops.nfullpasses         = 6;                        % number of complete passes through data during optimization (6)
    ops.maxFR               = 20000;                    % maximum number of spikes to extract per batch (20000)
    ops.fshigh              = 300;                      % frequency for high pass filtering
    % ops.fslow             = 2000;                     % frequency for low pass filtering (optional)
    ops.ntbuff              = 64;                       % samples of symmetrical buffer for whitening and spike detection
    ops.scaleproc           = 200;                      % int16 scaling of whitened data
    ops.NT                  = 32*1024+ ops.ntbuff;      % this is the batch size (try decreasing if out of memory)
                                                        % for GPU should be multiple of 32 + ntbuff
    
    
    %The following options can improve/deteriorate results.
    %when multiple values are provided for an option, the first two are beginning and ending anneal values,
    %the third is the value used in the final pass.
    ops.Th               = [4 10 10];       % threshold for detecting spikes on template-filtered data (or try [6 12 12])
                                            % lower values here means more spikes will be detected (but also more noise)
    
    ops.lam              = [5 20 20];       % large means amplitudes are forced around the mean (or try [10 30 30])
                                            % larger values here mean there's a greater penalty for amplitudes that deviate from the mean (so
                                            % it's more likely that waveforms belong to same unit, but with the chance that you exclude some if the
                                            % amplitude varies widely)
    
    ops.nannealpasses    = 4;               % should be less than nfullpasses (4)
    ops.momentum         = 1./[20 400];     % start with high momentum and anneal (or try 1./[20 1000])
    ops.shuffle_clusters = 1;               % allow merges and splits during optimization (1)
    ops.mergeT           = .1;              % upper threshold for merging (.1)
    ops.splitT           = .1;              % lower threshold for splitting (.1)
    
    
    
    %Set options for initializing spikes from data
    %The values in this section are only applied during the initialization step
    %(if ops.initialize = 'fromData')
    ops.initialize      = 'no';    %'fromData' or 'no'
    ops.spkTh           = -6;      % spike threshold in standard deviations (-6, don't use value larger than -3)
    ops.loc_range       = [3  1];  % ranges to detect peaks; plus/minus in time and channel ([3 1])
    ops.long_range      = [30  6]; % ranges to detect isolated peaks ([30 6])
    ops.maskMaxChannels = 5;       % how many channels to mask up/down ([5])
    ops.crit            = .65;     % upper criterion for discarding spike repeates (0.65)
    ops.nFiltMax        = 10000;   % maximum "unique" spikes to consider (10000)
    
    %Load predefined principal components (visualization only (Phy): used for features)
    dd                  = load('PCspikes2.mat'); % you might want to recompute this from your own data
    ops.wPCA            = dd.Wi(:,1:7);          % PCs
    
    %Set options for posthoc merges (under construction)
    ops.fracse  = 0.1; % binning step along discriminant axis for posthoc merges (in units of sd)
    ops.epu     = Inf;
    
    ops.ForceMaxRAMforDat   = 20e9; % maximum RAM the algorithm will try to use; on Windows it will autodetect.
    
    %Save configuration file
    configfilename  = fullfile(filepath,'Config.mat');
    save(configfilename,'ops')
    fprintf('Saved configuration file: %s\n', configfilename)
end



