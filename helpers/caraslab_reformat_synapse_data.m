function epData = caraslab_reformat_synapse_data(Tankdir,Savedir,sel)
%epData = caras_lab_reformat_synapse_data(Tankdir,Savedir,sel);
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
%
%   Written by ML Caras Mar 22, 2019 


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
    BLOCKNAMES = extractfield(BLOCKS,'name');

elseif sel  
    %Prompt user to select BLOCK
    FULLPATH = uigetdir(Tankdir,'Select BLOCK to process');
    PathFolders = regexp(FULLPATH,filesep,'split');
    BLOCKNAMES = PathFolders(end);  
end


%Check that at least one block has been selected
if isempty(BLOCKNAMES)
    fprintf('\n No BLOCKS could be found!!\n')
    return
end


%For each block
for i = 1:numel(BLOCKNAMES)
    savefilename = [Savedir filesep BLOCKNAMES{i} '.mat'];
    
    %Check if datafile is already saved, and if so, ask user what to do.
    if exist(savefilename,'file')
        reply = input('\n Reformated file exists already. Do you want to overwrite?\n Y/N:','s');
        
        switch reply
            case {'n','N','no','No','NO'}
                continue
        end
    end
    
    %Convert tank data to -mat
    FULLPATH = fullfile(Tankdir,BLOCKNAMES{i});
    fprintf('\n======================================================\n')
    fprintf('Processing ephys data, %s.......\n', BLOCKNAMES{i})
 
    %Display elapsed time
    tic;
    epData = TDTbin2mat(FULLPATH,'TYPE',{'epocs','streams'});
    tEnd = toc;
    fprintf('\n~~~~~~\nFinished in: %d minutes and %f seconds\n~~~~~~\n', floor(tEnd/60),rem(tEnd,60));
    
    %Save -mat file
    try
        fprintf('\nsaving...')
        save(savefilename,'epData','-v7.3')
        fprintf('\n~~~~~~\nSuccessfully saved datafile.\n\t %s\n~~~~~~\n',savefilename)
    catch
        warning('\n ** Could not save file **.\n')
        keyboard
    end
 
end

fprintf('\n\n ##### Finished reformatting and saving data files.\n\n')


end






