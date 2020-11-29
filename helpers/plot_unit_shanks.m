function plot_unit_shanks(Savedir, sel, show_plots, bp_filter)
    % This function reads the probe geometry in channel map and outputs the
    % spike means and SEM organized in space. If filter_300hz==0, it will
    % search for the 300hz bandpass filtered file. Otherwise, it will filter
    % again
    % Adapted from Cortexlab repository
    % Patched by M Macedo-Lima, November 2020

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
            readNPY(fullfile(cur_savedir, 'spike_times.npy'));
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
        gwfparams.channelPositions = readNPY(fullfile(gwfparams.dataDir, 'channel_positions.npy')); % Vector of cluster shanks
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
        gwfparams.good_clusters = gwfparams.cluster_quality.cluster_id(gwfparams.cluster_quality.group(:,1)=='g');

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

        %% Plot

        for wf_idx=1:length(good_cluster_idx)
            if show_plots
                figure('Name', prename);
            else
                figure('Name', prename, 'visible', 'off');
            end
            cluster_phy_id = good_cluster_idx(wf_idx);

            cur_shank = gwfparams.cluster_quality.sh(gwfparams.cluster_quality.cluster_id == cluster_phy_id);
            shank_channels_0ind = gwfparams.chanMap(gwfparams.channelShanks == cur_shank);
            [~, shank_channels_idx] = intersect(gwfparams.chanMap, shank_channels_0ind);
            
            % Rescale x and y to 0-1
            scaled_channel_positions = gwfparams.channelPositions;
            scaled_channel_positions(:,1) = rescale(scaled_channel_positions(:,1));
            scaled_channel_positions(:,2) = rescale(scaled_channel_positions(:,2));
         
            % Normalize all channels by the best channel
            best_channel_0ind = gwfparams.cluster_quality.ch(gwfparams.cluster_quality.cluster_id == cluster_phy_id);
            best_chanMap_idx = find(gwfparams.chanMap == best_channel_0ind);
            best_wf_mean = squeeze(wf.waveFormsMean(wf_idx, best_chanMap_idx,:));
            abs_best_wf_mean = abs(best_wf_mean);
            cur_wf_mean_peak_idx = abs_best_wf_mean == max(abs_best_wf_mean);
            norm_peak_value = abs(best_wf_mean(cur_wf_mean_peak_idx)) / 100;

            % If more than 14 channels plot 13 closest channels to best channel
            % Use an euclidean distances matrix to figure this out
            if length(shank_channels_idx) > 14
                euclidean_distances = zeros(length(scaled_channel_positions), length(scaled_channel_positions));

                for ch_i=1:length(shank_channels_idx)
                    for ch_j=1:length(shank_channels_idx)
                        euclidean_distances(shank_channels_idx(ch_i), shank_channels_idx(ch_j)) = ...
                            sqrt( (scaled_channel_positions(shank_channels_idx(ch_i),1)-scaled_channel_positions(shank_channels_idx(ch_j),1))^2 +...
                            (scaled_channel_positions(shank_channels_idx(ch_i),2)-scaled_channel_positions(shank_channels_idx(ch_j),2))^2 );
                    end
                end

                closest_distances = nonzeros(sort(euclidean_distances(:,best_chanMap_idx)));
                closest_distances = closest_distances(1:min(14, length(closest_distances)));  % grab 5 non-zero firsts
                [~, closest_channels_idx] = intersect(euclidean_distances(:,best_chanMap_idx), closest_distances);

                closest_channels_idx = [closest_channels_idx; best_chanMap_idx];
                % Exclude channels not part of the current shank
                [shank_channels_idx, ~] = intersect(shank_channels_idx, closest_channels_idx);
            end
            
            
            for shank_channel_idx=1:numel(shank_channels_idx)
                cur_chanMap_idx = shank_channels_idx(shank_channel_idx);
                
                % Grab x and y positions; rescale them to look closer
                % together; might need to be tweaked for each probe type
                x_offset = scaled_channel_positions(cur_chanMap_idx, 1)*120;
                y_offset = scaled_channel_positions(cur_chanMap_idx, 2)*5000;
                
                % Squeeze out and store raw waveforms and averages
                snip_points = 20;  % snip some points at the end of template
                cur_wfs = wf.waveForms(wf_idx, :, cur_chanMap_idx,1:end-snip_points);
                cur_wfs = squeeze(cur_wfs);
                cur_wfs = rmmissing(cur_wfs, 1);
                
                cur_wf_std = std(cur_wfs./norm_peak_value, 0, 1);

                cur_wf_mean = wf.waveFormsMean(wf_idx, cur_chanMap_idx,1:end-snip_points);
                cur_wf_mean = squeeze(cur_wf_mean);

                % 10x upsample mean waveform with spline interpolation
                samplingRateIncrease = 10;
                newXSamplePoints = linspace(1, length(cur_wf_mean), length(cur_wf_mean) * samplingRateIncrease);
                cur_wf_mean_upsample = spline(1:length(cur_wf_mean), cur_wf_mean, newXSamplePoints);
                cur_wf_std_upsample = spline(1:length(cur_wf_std), cur_wf_std, newXSamplePoints);
                
                x_time = linspace(0, length(cur_wf_mean) / gwfparams.sr, length(cur_wf_mean));
                x_time = x_time * 1000; % in ms

                upsampled_x_time = linspace(0, length(cur_wf_mean_upsample) / gwfparams.sr / samplingRateIncrease, length(cur_wf_mean_upsample));
                upsampled_x_time = upsampled_x_time*1000;
                
                % Normalize amplitude so that peak is at -1 or 1
                cur_wf_mean_upsample = cur_wf_mean_upsample ./ norm_peak_value;
                
                title(['Cluster' num2str(cluster_phy_id)]);

                hold on
%               If you want to output individual spikes around the mean instead of SEM
%                 for spike_idx=1:min(size(cur_wfs, 1), 100)  % plot a max of 50 spikes
%                     cur_wf = cur_wfs(spike_idx,:);
%                     if isnan(mean(cur_wfs(spike_idx, 1:5)))
%                         continue  % sometimes waveforms are NaN which is weird...
%                     end
%                     % Normalize amplitude of individual spike using the average
%                     cur_wf = cur_wf ./ norm_peak_value;
% 
%                     cax = plot(x_time + x_offset, cur_wf + y_offset, 'black'); % Plot 0-centered traces
%                     cax.Color(4)=0.1;
%                 end
                
                std_patch_top = (cur_wf_mean_upsample + cur_wf_std_upsample) + y_offset;
                std_patch_bottom = (cur_wf_mean_upsample - cur_wf_std_upsample) + y_offset ;
                patch_cax = patch([upsampled_x_time + x_offset fliplr(upsampled_x_time + x_offset)],...
                    [std_patch_bottom fliplr(std_patch_top)], 'black', 'EdgeColor','none');
                patch_cax.FaceAlpha=0.3;
                plot(upsampled_x_time + x_offset, cur_wf_mean_upsample + y_offset, 'black', 'linewidth', 0.5);
            end

            axis off;
           print([gwfparams.dataDir '\' prename '_shankWaveforms' '_cluster' num2str(cluster_phy_id)], '-dpdf', '-bestfit', '-painters');
        end
    end
end