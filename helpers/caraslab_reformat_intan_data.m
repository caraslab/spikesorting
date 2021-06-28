function caraslab_reformat_intan_data(Tankdir,Savedir,sel)
%epData = caras_lab_reformat_synapse_data(Tankdir,Savedir,sel);
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
%       
%
%   Written by ML Caras Mar 22, 2019 
%   patched by M Macedo-Lima 9/8/20


%Default to cycling through all BLOCKS
if nargin < 3
    sel = 0;   
end

%Check that tank directory exists and abort if it doesn't
if ~exist(Tankdir,'dir')
    fprintf('\n Tank directory does not exist!!\n')
    return
end


%Check if save directory exists. If it doesn't, create it now.
if ~exist(Savedir,'dir')
    [success,message,messageID] = mkdir(Savedir);
    
    %Stop if directory cannot be created, and display reason why
    if ~success
        message %#ok<*NOPRT>
        messageID
        return
    end   
end

if ~sel
    %Get a list of all BLOCKS in the tank directory
    BLOCKS = caraslab_lsdir(Tankdir);
    BLOCKNAMES = {BLOCKS.name};
    

elseif sel  
    %Prompt user to select folder
    datafolders_names = uigetfile_n_dir(Tankdir,'Select data directory');
    BLOCKNAMES = {};
    for i=1:length(datafolders_names)
        [~, BLOCKNAMES{end+1}, ~] = fileparts(datafolders_names{i});
    end
end

%Check that at least one block has been selected
if isempty(BLOCKNAMES)
    fprintf('\n No BLOCKS could be found!!\n')
    return
end


%For each block
for i = 1:numel(BLOCKNAMES)
    t0 = tic;
    cur_path.name = BLOCKNAMES{i};
    cur_savedir = [Savedir filesep cur_path.name];
    data_filename = fullfile(cur_savedir, [cur_path.name '.dat']);
    adc_filename = fullfile(cur_savedir, [cur_path.name '_ADC.dat']);

    events_filename = fullfile(cur_savedir, [cur_path.name '.info']);
    
    cur_tank_subdir = dir(fullfile(Tankdir, cur_path.name, 'Record Node*'));  % assume 1 recording node
    fullpath = fullfile(cur_tank_subdir.folder, cur_tank_subdir.name);
    
    %Convert tank data to -mat and display elapsed time
    fprintf('\n======================================================\n')
    fprintf('Processing ephys data, %s.......\n', cur_path.name)
    
    % Try to read file. If missing, skip to the next folder
    mkdir(cur_savedir);
%     
    t0 = tic;
    chunk_size = 1800000; % Lower this number if running out of memory
    fid_data = fopen(data_filename,'w');
    fid_adc = fopen(adc_filename,'w');
    
    try
        
        % Data channels have the naming convention *CHXX.continuous
        % Read recording info to get channel order; ADC channels will also
        % be in the mix; Channels should come out in order
        session_info = get_session_info(fullpath); 
        
        % Find the index of the recording node (assume only one)
        node_idx = find(contains(session_info.processors(:,2),'Filters/Record Node'));
        
        % Something weird happens sometimes
        all_channels = session_info.processors{node_idx, 3}{1};
        if isempty(all_channels)
            all_channels = session_info.processors{node_idx, 3}{2};

        end
        data_channels = all_channels(contains(all_channels,'CH'));
        adc_channels = all_channels(contains(all_channels,'ADC'));
        
        % Weird bug in OpenEphys GUI sometimes names these differently
        if length(data_channels) == 0
            data_channels = all_channels(1:64);
            adc_channels = all_channels(65);            
        end

        
        %% Read data channels and add to .dat
        fprintf('Concatenating data channels in chunks:\n')
        eof = 0;
        chunk_counter = 1;
        t1 = 0;
        while ~eof
            disp(['Chunk counter: ' num2str(chunk_counter) '...']);
            rawsig = [];
            t2 = t1 + chunk_size;  % Update t2
            disp(['Reading data channels...']);
            for ch_idx=1:length(data_channels)
                [cur_ch_data, ~, ~, is_eof] = load_open_ephys_data_chunked(fullfile(fullpath, data_channels{ch_idx}), t1, t2, 'samples');
                rawsig = [rawsig; cur_ch_data'];
                if is_eof
                    eof = 1;
                end

            end
            disp(['Writing to file...']);
            fwrite(fid_data, rawsig, 'int16');
            t1 = t2;  % Update t1
            chunk_counter = chunk_counter + 1;
        end
        fclose(fid_data);
%         rawsig = rawsig';  % Transpose for [n_ch n_samp] size;
        
        %% Read ADC channels and add to .dat
        fprintf('Concatenating ADC channels in chunks in the following order:\n')
        eof = 0;
        chunk_counter = 1;
        t1 = 0;
        while ~eof
            disp(['Chunk number: ' num2str(chunk_counter) '...']);
            rawsig = [];
            t2 = t1 + chunk_size;  % Update t2
            disp(['Reading ADC channels...']);

            for ch_idx=1:length(adc_channels)
                [cur_ch_data, data_timestamps, ~, is_eof] = load_open_ephys_data_chunked(fullfile(fullpath, adc_channels{ch_idx}), t1, t2, 'samples');
                rawsig = [rawsig; cur_ch_data'];
                if is_eof
                    eof = 1;
                end

            end
            disp(['Writing to file...']);
            fwrite(fid_adc, rawsig, 'int16');
            t1 = t2;  % Update t1
            chunk_counter = chunk_counter + 1;
        end
        fclose(fid_adc);
        
        clear rawsig cur_ch_data;
        
        %% Read DAC channels; for now just bundle the relevant variables in a .info file and
        % unpack them in the behavior pipeline; this struct is meant to
        % look somewhat similar to the TDT epData that comes out of Synapse
        % 0: DAC1 = sound on/off
        % 1: DAC2 = spout on/off
        % 2: DAC3 = trial start/end
        fprintf('Reading Events channels:\n')
        
        % Load only a little bit of a channel file to get the zero timestamp info
        [~, data_timestamps, ~, ~] = load_open_ephys_data_chunked(fullfile(fullpath, data_channels{1}), 0, 5, 'samples');

        [event_ids, timestamps, info] = load_open_ephys_data_faster(fullfile(fullpath, 'all_channels.events'));
        epData.event_ids = event_ids;
        epData.event_states = info.eventId;
        epData.timestamps = timestamps - data_timestamps(1); % Zero TTL timestamps based on the first sampled data  time
        epData.info.blockname = cur_path.name;
        
        block_timestamp = split(cur_path.name, '_');
        block_date_timestamp = [block_timestamp{1} '_' block_timestamp{2}];
        block_date_timestamp = datevec(block_date_timestamp, 'yyyy-mm-dd_HH-MM-SS');
        epData.info.StartTime = block_date_timestamp;  % TDT-like
        
        save(events_filename, 'epData','-v7.3')

    catch ME
        if strcmp(ME.identifier, 'MATLAB:load:couldNotReadFile')
            fprintf('\nFile not found\n')
            continue
        else
            fprintf(ME.identifier)
            fprintf(ME.message)
            break
        end
    end
% 
%     %Save a -mat file with the raw streams
%     try
%         fprintf('\nSaving raw stream...')
%         mkdir([Savedir filesep cur_path.name]);
%         if ~isempty(rawsig)
%             save(datafilename, 'rawsig','-v7.3')
%             clear rawsig
%         else
%             fprintf('\nNo raw stream found in folder. Skipping...')
%             continue
%         end
%         
%         fprintf('\nSaving ADC stream...')
%         if ~isempty(adc_channels_mat)
%             save(adcfilename, 'adc_channels_mat','-v7.3')
%             clear adc_channels_mat
%         else
%             fprintf('\nNo ADC stream found in folder. Skipping...')
%             continue
%         end
%         
%         % TODO: OUTPUT DAC TTL INFORMATION
%         
% %         fprintf('\nSaving supporting information...\n')
% %         save(infofilename,'epData','-v7.3')    
%         fprintf('\nSuccessfully saved raw data to:\n\t %s',datafilename)
% %         fprintf('\nSuccessfully saved supporting info to:\n\t %s',infofilename)
%     catch
%         warning('\n ** Could not save file **.\n')
%         keyboard
%     end
    
    tEnd = toc(t0);
    fprintf('\n~~~~~~\nFinished in: %d minutes and %f seconds\n~~~~~~\n', floor(tEnd/60),rem(tEnd,60));

    %--------------------------------------------------------------------------    
    % NOT CURRENTLY IN USE, BUT COULD BE IMPLEMENTED AT A LATER DATE
    %--------------------------------------------------------------------------    
    %Option for saving raw streams to csv file. Transpose such that each column
    %is one channel, and each row is one sample. This csv file can be used
    %later to create a datastore, and a tall array.
    %     csvfilename = [Savedir filesep BLOCKNAMES{i} '.csv'];
    %     fprintf('\nSaving CSV file %s...',[BLOCKNAMES,'.csv']);
    %     dlmwrite(csvfilename,epData.streams.RSn1.data','precision',7);
    %     fprintf('done.\n');
    %     
    %     %Remove the data from the epData structure
    %     epData.streams.RSn1.data = [];
    %     
    %     %Add the path to the -csv file to the epData structure
    %     epData.info.csvfile = csvfilename;
    %     
    %     %Save the -mat file containing epoch, sampling rate, and other
    %     %important information, but not the raw streams
    %     save(matfilename,'epData');
    %     fprintf('Saved MAT file %s',matfilename);
    %--------------------------------------------------------------------------    


end


fprintf('\n\n ##### Finished reformatting and saving data files.\n\n')


end






