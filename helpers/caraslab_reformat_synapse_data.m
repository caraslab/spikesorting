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
%               M = the number of samples, and 
%               N = the number of channels
%
%       (2) A -info file containing supporting information, including
%               sampling rate, epocs, and timing
%       
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
    datafilename = [Savedir filesep BLOCKNAMES{i} '.mat'];
    infofilename = [Savedir filesep BLOCKNAMES{i} '.info'];
    
    %Check if datafile is already saved, and if so, ask user what to do.
    if exist(datafilename,'file')
        reply = input('\n Reformated file exists already. Do you want to overwrite?\n Y/N:','s');
        
        switch reply
            case {'n','N','no','No','NO'}
                continue
        end
    end
    
    %Convert tank data to -mat and display elapsed time
    FULLPATH = fullfile(Tankdir,BLOCKNAMES{i});
    fprintf('\n======================================================\n')
    fprintf('Processing ephys data, %s.......\n', BLOCKNAMES{i})
 
    tic;
    epData = TDTbin2mat(FULLPATH,'TYPE',{'epocs','streams'});
    tEnd = toc;
    fprintf('\n~~~~~~\nFinished in: %d minutes and %f seconds\n~~~~~~\n', floor(tEnd/60),rem(tEnd,60));
    
    %Save a -mat file with the raw streams
    try
        fprintf('\nSaving raw stream...')
        rawsig = epData.streams.RSn1.data'; %rows = samples, cols = chs
        save(datafilename,'rawsig','-v7.3')
        
        %Remove the data from the epData structure
        epData.streams.RSn1.data = [];
        fprintf('\nSaving supporting information...')
        save(infofilename,'epData','-v7.3')
            
        fprintf('\nSuccessfully saved raw data to:\n\t %s',datafilename)
        fprintf('\nSuccessfully saved supporting info to:\n\t %s',infofilename)
        
        
    catch
        warning('\n ** Could not save file **.\n')
        keyboard
    end
    
    
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






