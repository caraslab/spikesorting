function caraslab_concatenate_sameDepth_recordings(Savedir, sel)

output_file_name = output_dir;

datafolders_names = uigetfile_n_dir(Savedir,'Select data directory');

datafolders = {};
for i=1:length(datafolders_names)
    [~, datafolders{end+1}, ~] = fileparts(datafolders_names{i});
end

% Sort according to dates then times in folder names
date_time = regexp(datafolders, '\d+', 'match');
recording_dates = [];
recording_times = [];
for i=1:length(date_time)
   recording_dates = [recording_dates str2num(date_time{i}{1})];
   recording_times = [recording_times str2num(date_time{i}{2})];
end

% now sort hierarchically first date, then time
temp_cell = horzcat(datafolders', num2cell([recording_dates' recording_times']) );
temp_cell = sortrows(temp_cell, [2 3]);
datafolders = temp_cell(:,1)';

% Print names of files to check order
fprintf('\nConcatenating files in the following order:\n')
for i = 1:length(datafolders)
    fprintf('%s\n',datafolders{i}) % print each file to make sure it's in order
    % need the sorting performed above!!!
end

full_output_dir = fullfile(Savedir, output_dir);
mkdir(full_output_dir);

fidC        = fopen(fullfile(full_output_dir, [output_file_name 'CLEAN.dat']),  'w'); % Write concatenated recording
session_names = {};
break_points = [];
tic;
for i = 1:numel(datafolders)
    cur_path.name = datafolders{i};
    cur_dir = [Savedir filesep cur_path.name];
    
    %Start timer
    
    dir_fbinary = dir(fullfile(cur_dir, '*CLEAN.dat'));  % presume file is cleaned
    fbinary = fullfile(cur_dir, dir_fbinary(1).name);
    
    fprintf('\nReading raw file: %s\n', fbinary)
    fid         = fopen(fbinary, 'r'); % open current raw data

    
    % Check if breakpoints file exists in folder; this indicates this
    % current day consists of previously concatenated recordings. If this
    % is the case, just read that file
    cur_breakpoint_file = [dir(fullfile(cur_dir, '*breakpoints.csv'))];
    if ~isempty(cur_breakpoint_file)
        cur_breakpoint_table = readtable(fullfile(cur_dir, cur_breakpoint_file(1).name), 'Delimiter', ',');
        session_names = [session_names cur_breakpoint_table.Session_file'];
        
        % concatenate break_points adding the last value
        if ~isempty(break_points)
            break_points = [break_points; break_points(end) + cur_breakpoint_table.Break_point];  
        else
            break_points = [break_points; cur_breakpoint_table.Break_point]; 
        end
    else
        session_names{end+1} = dir(ops.fbinary).name;
        if i > 1
            
            break_points = [break_points; get_file_size(ops.fbinary)/NchanTOT/2 + break_points(i-1)];
        else
            break_points = [break_points; get_file_size(ops.fbinary)/NchanTOT/2];
        end
    end
    
    while ~feof(fid)  % read until end of file
        buff = fread(fid, [NchanTOT NT], '*int16'); % read and reshape. Assumes int16 data (which should perhaps change to an option)
        fwrite(fidC, buff, 'int16'); % write this batch to concatenated file
    end
    fclose(fid); % close the files
end

% Output csv breakpoints
ret_table = cell2table(session_names(:), 'VariableNames', {'Session_file'});
ret_table.Break_point = break_points;
writetable(ret_table, fullfile(full_output_dir, [output_file_name '_breakpoints.csv']));

fclose(fidC);

tEnd = toc;
fprintf('\nDone in: %d minutes and %f seconds\n', floor(tEnd/60), rem(tEnd,60));
