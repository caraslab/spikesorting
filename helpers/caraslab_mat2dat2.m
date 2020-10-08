function caraslab_mat2dat(Savedir, sel)
%caraslab_mat2dat(binarydir)
%
% This function converts -mat files to 16 bit integer -dat files, the
% required input format for kilosort. This function should be run as the
% final processing step before storing data in kilosort (i.e. data should
% already have been filtered, had common average referencing applied, and
% had artifacts removed using caraslab_preprocess.m).
%
%   sel:        if 0 or omitted, program will cycle through all files
%               in the data directory. 
%                   
%               if 1, user will be prompted to select a file
%
%Written by ML Caras Mar 27 2019

if ~sel
    datafolders = caraslab_lsdir(Savedir);
    datafolders = {datafolders.name};

elseif sel  
    %Prompt user to select folder
    datafolders_names = uigetfile_n_dir(Savedir,'Select data directory');
    datafolders = {};
    for i=1:length(datafolders_names)
        [~, datafolders{end+1}, ~] = fileparts(datafolders_names{i});
    end
%     [~,name] = fileparts(pname);
%     datafolders = {name};  
%     
end


%For each data folder...
for i = 1:numel(datafolders)
    clear ops temp dat
    
    cur_path.name = datafolders{i};
    cur_savedir = [Savedir filesep cur_path.name];

    %Load in configuration file (contains ops struct)
    % Catch error if -mat file is not found
    try
        load(fullfile(cur_savedir, 'config.mat'));

    catch ME
        if strcmp(ME.identifier, 'MATLAB:load:couldNotReadFile')
            fprintf('\n-mat file not found\n')
            continue
        else
            fprintf(ME.identifier)
            fprintf(ME.message)
            continue
        end
    end
    
    %Find the -mat file to convert
%     matfile = ops.readyforsorting;
    matfile = ops.rawdata;
    
    %Load -mat data file
    fprintf('Loading -mat file: %s.......\n', matfile)
    tic;
    try
        temp = load(matfile);
    catch ME
        if strcmp(ME.identifier, 'MATLAB:load:couldNotReadFile')
            fprintf('\n-mat file not found\n')
            continue
        else
            fprintf(ME.identifier)
            fprintf(ME.message)
            continue
        end
    end
    
    tEnd = toc;
    fprintf('Loaded in: %d minutes and %f seconds\n', floor(tEnd/60),rem(tEnd,60));
    
    % Deline using chunkwiseDeline
    if ops.deline
        fprintf('Delining... ')
        tic
        for ch_n = 1:size(temp.rawsig, 1)
            temp_sig = temp.rawsig(ch_n, :)';  % transpose
            
            window_size = 60;  % in s
            success = 0;
            while ~success
                try
                    temp_sig = chunkwiseDeline(temp_sig, ops.fs, [60 180 300], 10, window_size);
                    success = 1;
                catch ME
                    if (strcmp(ME.identifier, 'optimlib:levenbergMarquardt:UserJacUndefAtX0') ||...
                        strcmp(ME.identifier, 'MATLAB:dimagree') )
                        % If delining fails, try a larger window.
                        window_size = window_size + 1;
                    else
                        throw(ME)
                    end
                end
            end
            temp.rawsig(ch_n, :) = temp_sig'; % transpose back
        end
        tEnd = toc;
        fprintf('Done in: %d minutes and %f seconds\n', floor(tEnd/60),rem(tEnd,60));
    end
    
    % MML edit
    % RMS detection of bad channels
    % Has to be done before amplitude range normalization
    ops.igood = caraslab_rms_badChannels(temp.rawsig);
    
    fprintf('Writing raw binary file: %s.......\n', ops.fbinary)
    t0 = tic;
    temp_raw = temp.rawsig./max(abs(temp.rawsig), [], 2); %normalizes recording such that dat ranges from - 1 to 1
    %     dat = temp.rawsig./max(abs(temp.rawsig)); %normalizes recording such that dat ranges from - 1 to 1
    temp_raw = int16(temp_raw.*(single(intmax('int16')))); %rescales to use maximum range of int16 scale
    fwrite(fid, temp_raw(:),'int16'); 
    clear temp_raw
    fclose(fid);
    tEnd = toc(t0);
    fprintf('Finished in: %d minutes and %f seconds\n', floor(tEnd/60),rem(tEnd,60));

    % Comb filter at multiples of ~60Hz for line-noisy recordings
    % Can't use GPU acceleration for comb filter yet...
    if getOr(ops, 'comb', 0)  
        fprintf('Comb filtering raw file: %s.......\n', ops.fbinary)
        t0 = tic;

        % Filter design, determined empirically
        N  = 407;    % Order
        BW = 2;    % Bandwidth
        Fs = ops.fs;  % Sampling Frequency
        h = fdesign.comb('Notch', 'N,BW', N, BW, Fs);
        comb_filter = design(h, 'butter');
        comb_b1= comb_filter.Numerator;
        comb_a1= comb_filter.Denominator;
        
        % comb filter raw signal
        dat = filter(comb_b1, comb_a1, temp.rawsig);
        tEnd = toc(t0);
        fprintf('Finished in: %d minutes and %f seconds\n', floor(tEnd/60),rem(tEnd,60));
        
        fprintf('Shuttling data to GPU.........\n')
        dat = gpuArray(dat); % move int16 data to GPU
    else
        fprintf('Shuttling data to GPU.........\n')
        dat = gpuArray(dat); % move int16 data to GPU
    end
    dat = single(dat); % convert to float32 so GPU operations are fast
    % subtract the mean from each channel
    dat = dat - mean(dat, 1); % subtract mean of each channel

    % CAR, common average referencing by median
    if getOr(ops, 'CAR', 1)
        fprintf('CAR filtering.......\n')
        t0 = tic;
        % MML edit:take median of good channels only
        dat = dat - median(dat(:, chanMap(igood)), 2); % subtract median across channels
        tEnd = toc(t0);
        fprintf('Finished in: %d minutes and %f seconds\n', floor(tEnd/60),rem(tEnd,60));
    end       
    
    fprintf('Highpass or bandpass filtering.......\n')

    dat = filter(b1, a1, dat); % causal forward filter
    dat = flipud(dat); % reverse time
    dat = filter(b1, a1, dat); % causal forward filter again
    dat = flipud(dat); % reverse time back
    tEnd = toc(t0);
    fprintf('Finished in: %d minutes and %f seconds\n', floor(tEnd/60),rem(tEnd,60));

    if getOr(ops, 'rm_artifacts', 1)
        fprintf('Removing artifacts.......\n')
        t0 = tic;
        warning off;
        [dat, ~] = caraslab_artifact_reject(dat, ops.fs);
        warning on;
        tEnd = toc(t0);
        fprintf('Finished in: %d minutes and %f seconds\n', floor(tEnd/60),rem(tEnd,60));
    end
    
    %Prepare data for conversion to int16
    fprintf('Normalizing amplitude range... ')
    tic
    dat = dat./max(abs(dat), [], 2); %normalizes recording such that dat ranges from - 1 to 1

    %     dat = temp.rawsig./max(abs(temp.rawsig)); %normalizes recording such that dat ranges from - 1 to 1
    dat = int16(dat.*(single(intmax('int16')))); %rescales to use maximum range of int16 scale
    
    tEnd = toc;
    fprintf('Done in: %d minutes and %f seconds\n', floor(tEnd/60),rem(tEnd,60));
    
    dat = dat';

    dat  = gather(int16(dat)); % convert to int16, and gather on the CPU side
    fwrite(fidC, dat, 'int16'); % write this batch to clean file

    fclose(fid);
    tEnd = toc;
    

    
    %Write the data to a binary file
    fid = fopen(ops.fbinary,'w');
    if fid == -1
        fprintf('Cannot create binary file!')
        return
    end
    
    fprintf('Writing raw binary file: %s.......\n', ops.fbinary)
    tic;
    fwrite(fid, dat(:),'int16'); 
    fclose(fid);
    tEnd = toc;
    fprintf('Finished in: %d minutes and %f seconds\n', floor(tEnd/60),rem(tEnd,60));
    
    %Save configuration file
    save(fullfile(cur_savedir, 'config.mat'),'ops')
end







