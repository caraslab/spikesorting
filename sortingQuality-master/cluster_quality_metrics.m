function cluster_quality_metrics(Savedir, sel, show_plots, bp_filter)
% This function runs 3 quality control metrics on the curated clusters:
% 1. ISI violation false positive rate: how many false positive spikes in a
%   cluster.
% 2. Fraction of spikes missing: based on the probability distribution of 
%   spikes detected for a unit, how many are estimated to be missing? 
% 3. Presence ratio: for how much of the recording is a unit present? The
%   recording time is divided in 100 bins and the fraction of bins with at
%   least one spike present is calculated.
% Adapted from the Allen Brain Institute github

% By default, the AllenSDK applies filters so only units above a set of thresholds are returned.
% 
% The default filter values are as follows:
% 
% isi_fprate < 0.5
% amplitude_cutoff < 0.1
% presence_ratio > 0.9

% Inspired by the AllenInstitude github code. 
% Parts of this code are adapted from Cortexlab repository
% Implemented by M Macedo-Lima, December 2020

    % Select folders to run
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
    end

    %For each data folder...
    for i = 1:numel(datafolders)
        clear ops rez
        close all
        
        cur_path.name = datafolders{i};
        cur_savedir = [Savedir filesep cur_path.name];

        %Load in configuration file (contains ops struct)
        % Catch error if -mat file is not found and skip folder
        try
            load(fullfile(cur_savedir, 'config.mat'));
        catch ME
            if strcmp(ME.identifier, 'MATLAB:load:couldNotReadFile')
                fprintf('\nFile not found\n')
                continue
            else
                fprintf(ME.identifier)  % file not found has no identifier?? C'mon MatLab...
                fprintf(ME.message)
                continue  % Continue here instead of break because I don't know how to catch 'file not found' exception; maybe using ME.message?
            end
        end

        %Start timer
        t0 = tic;
        
        fprintf('Calculating quality control metrics for: %s\n', cur_savedir)
        
        %% Define I/O and waveform parameters
        gwfparams.dataDir = cur_savedir;    % KiloSort/Phy output folder 
        gwfparams.ops = ops;
        
        % Define output name for cluster; this is specific for my
        % file-naming convention and should be tweaked
        split_dir = split(cur_savedir, '/'); 
        subj_id = split(split_dir{end-1}, '-');
        subj_id = join(subj_id(1:3), '-'); 
        subj_id = subj_id{1}; 
        recording_id = split_dir{end};
        prename = [subj_id '_' recording_id];  % this is what goes into the .txt file name

        gwfparams.rawDir = cur_savedir;
        gwfparams.sr = ops.fs;
        gwfparams.nCh = ops.NchanTOT; % Number of channels that were streamed to disk in .dat file
        gwfparams.fileName = dir(ops.fclean).name; % .dat file containing the raw used for sorting
        gwfparams.dataType = 'int16'; % Data type of .dat file (this should be BP filtered)

        gwfparams.wfWin = [round(-(0.001*gwfparams.sr)) round(0.003*gwfparams.sr)]; % Number of samples before and after spiketime to include in waveform
        gwfparams.nWf = 2000; % Max number of waveforms per unit to pull out for averaging
        gwfparams.spikeTimes = readNPY(fullfile(gwfparams.dataDir, 'spike_times.npy')); % Vector of cluster spike times (in samples) same length as .spikeClusters
        gwfparams.spikeClusters = readNPY(fullfile(gwfparams.dataDir, 'spike_clusters.npy')); % Vector of cluster IDs (Phy nomenclature)   same length as .spikeTimes
        gwfparams.channelShanks = readNPY(fullfile(gwfparams.dataDir, 'channel_shanks.npy')); % Vector of cluster shanks

        gwfparams.chanMap = readNPY(fullfile(gwfparams.dataDir, 'channel_map.npy')); % this is important in esp if you got rid of files. 
        try
            gwfparams.cluster_quality = tdfread(fullfile(gwfparams.dataDir, 'cluster_info.tsv'));
        catch ME
            if strcmp(ME.identifier, 'MATLAB:load:couldNotReadFile')
                fprintf('\nFile not found\n')
                continue
            else
                fprintf(ME.identifier)  % file not found has no identifier?? C'mon MatLab...
                fprintf([ME.message '\n'])
                continue  % Continue here instead of break because I don't know how to catch 'file not found' exception; maybe using ME.message?
            end
        end

        % Get good and mua for measuring
        gwfparams.good_clusters = gwfparams.cluster_quality.cluster_id(gwfparams.cluster_quality.group(:,1)=='g' | gwfparams.cluster_quality.group(:,1)=='m');

        %% Get waveforms from .dat
        wf = getWaveForms(gwfparams, bp_filter);  

        good_cluster_idx = wf.unitIDs; % store their Phy IDs

        % Create a folder called CSV files within saved directory, because
        % older versions of Phy crash if random .csv files are present
        % Contains other file types too, but oh well...
        if (exist(fullfile(gwfparams.dataDir, 'CSV files')) == 0)
            mkdir(fullfile(gwfparams.dataDir, 'CSV files')); 
        end

        %% OUTPUT from getWaveforms looks like this:
        % wf.unitIDs                               % [nClu,1]            List of cluster IDs; defines order used in all wf.* variables
        % wf.spikeTimeKeeps                        % [nClu,nWf]          Which spike times were used for the waveforms
        % wf.waveForms                             % [nClu,nWf,nCh,nSWf] Individual waveforms
        % wf.waveFormsMean                         % [nClu,nCh,nSWf]     Average of all waveforms (per channel)
        %                                          % nClu: number of different clusters in .spikeClusters
        %                                          % nSWf: number of samples per waveform

        %% Measure waveform averages
        % Prealocate some variables
        best_channels_csv = zeros(length(gwfparams.good_clusters), 1);
        shanks = zeros(length(gwfparams.good_clusters), 1);
        cluster_quality = zeros(length(gwfparams.good_clusters), 1);  % zeros will be MU, ones will be SU
        fpRate_list = zeros(length(gwfparams.good_clusters), 1);
        fraction_missing_list = zeros(length(gwfparams.good_clusters), 1);
        presence_ratio_list = zeros(length(gwfparams.good_clusters), 1);
        if show_plots
            figure('Name', prename);
        else
            figure('Name', prename, 'visible', 'off');
        end
        for wf_idx=1:length(good_cluster_idx)
            cluster_phy_id = good_cluster_idx(wf_idx);

            % Grab channel with highest amplitude for this unit
            best_channel = gwfparams.cluster_quality.ch(gwfparams.cluster_quality.cluster_id == cluster_phy_id);
            
            % Store channel and shank info
            best_channels_csv(wf_idx) = best_channel + 1;
            shanks(wf_idx) = gwfparams.cluster_quality.sh(gwfparams.cluster_quality.cluster_id == cluster_phy_id);  
            
            % Grab best channel index
            best_channel_idx = find(gwfparams.chanMap == best_channel);
            
            % Store cluster quality
            cluster_quality_char = gwfparams.cluster_quality.group(gwfparams.cluster_quality.cluster_id == cluster_phy_id);
            if (cluster_quality_char == 'g')
            	cluster_quality(wf_idx) = 1;
            end
            
            % Squeeze out and store raw waveforms and averages
            cur_wfs = wf.waveForms(wf_idx, :, best_channel_idx,:);
            cur_wfs = squeeze(cur_wfs);
            
            %% ISI violations
%             """Calculate ISI violations for a spike train.
% 
%             Based on metric described in Hill et al. (2011) J Neurosci 31: 8699-8705
            
            % Declare some parameters first
            all_spike_times = double(wf.allSpikeTimePoints{wf_idx}) / gwfparams.sr;
            min_time = ops.trange(1);
            
            filenamestruct = dir(ops.fclean);
            dataTypeNBytes = numel(typecast(cast(0, gwfparams.dataType), 'uint8')); % determine number of bytes per sample
            nSamp = filenamestruct.bytes/(gwfparams.nCh*dataTypeNBytes);  % Number of samples per channel
            max_time = nSamp / gwfparams.sr;
            
            % Modify these if you'd like
            %     isi_threshold : threshold for isi violation (i.e. refractory period)
            %     min_isi : threshold for duplicate spikes (if run after the postprocessing step, it shouldn't detect anything)
            isi_threshold = 0.0015;
            min_isi = 0.00015;
            
            % Then run
            [fpRate, ~] = isi_violations(all_spike_times, min_time, max_time, isi_threshold, min_isi, ops);
            fpRate_list(wf_idx) = fpRate;
            % TODO: Reconstruct autocorrelograms
            
            %% Amplitude cutoff
%             """ Calculate approximate fraction of spikes missing from a distribution of amplitudes
%             Assumes the amplitude histogram is symmetric (not valid in the presence of drift)
%             Inspired by metric described in Hill et al. (2011) J Neurosci 31: 8699-8705
             [fraction_missing, h, b, G] = amplitude_cutoff(cur_wfs);
             % Store relevant variable
             fraction_missing_list(wf_idx) = fraction_missing;
             % Plots
             subplot(ceil(length(good_cluster_idx) / 4), 4, wf_idx);
             plot(b(1:end-1), h)
             hold on
             plot([b(G(1)) b(G(1))], [0, max(h)], '--')
%              fraction_txt = ['Fraction missing = ' num2str(fraction_missing, 3)];
%              text(b(G(1)), 0, fraction_txt, 'fontsize',10);
             title(['Cluster' num2str(cluster_phy_id)]);
            
             %% Presence ratio
%              Presence ratio is not a standard metric in the field, 
%              but it's straightforward to calculate and is an easy way to 
%              identify incomplete units. It measures the fraction of time 
%              during a session in which a unit is spiking, and ranges from 
%              0 to 0.99 (an off-by-one error in the calculation ensures that it will never reach 1.0).
             pr = presence_ratio(all_spike_times, min_time, max_time, 100, ops);
             presence_ratio_list(wf_idx) = pr;
             % TODO: Plot histograms

             
        end

        screen_size = get(0, 'ScreenSize');

        origSize = get(gcf, 'Position'); % grab original on screen size
        set(gcf, 'Position', [0 0 screen_size(3) screen_size(4)] ); %set to scren size
        set(gcf,'PaperPositionMode','auto') %set paper pos for printing
        print([gwfparams.dataDir '\CSV files\' prename 'fraction_missing'], '-dpdf', '-bestfit', '-painters');
        
        %% write csv
        TT = array2table([gwfparams.good_clusters best_channels_csv shanks ...
            cluster_quality fpRate_list fraction_missing_list presence_ratio_list],...
            'VariableNames',{'Cluster' 'Best_channel' 'Shank' ...
            'Cluster_quality' 'ISI_FPRate' 'Fraction_missing', 'Presence_ratio'});
        % Change code into words
        TT.Cluster_quality = num2cell(TT.Cluster_quality);
        
        for i=1:length(TT.Cluster_quality)
            if TT.Cluster_quality{i} == 1
                TT.Cluster_quality(i) = {'good'};
            else
                TT.Cluster_quality(i) = {'mua'};
            end
        end
        writetable(TT, fullfile(gwfparams.dataDir, 'CSV files', [prename '_quality_metrics.csv']));
        
        tEnd = toc(t0);
        fprintf('Done in: %d minutes and %f seconds\n', floor(tEnd/60), rem(tEnd,60));
    end
end