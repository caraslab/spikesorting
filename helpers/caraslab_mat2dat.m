function caraslab_mat2dat(binarydir,sel)
%caraslab_mat2dat(binarydir)
%
% This function converts -mat files to 16 bit integer -dat files, the
% required input format for kilosort. This function should be run as the
% final processing step before storing data in kilosort (i.e. data should
% already have been filtered, had common average referencing applied, and
% had artifacts removed using caraslab_preprocess.m).
%
%
%   binarydir:  Path where binary data folders are stored.
%               Binary folders should already have been created by
%               caraslab_createconfig.m, and each should contain a 
%               Config.m file with the kilosort ops structure.
%
%   sel:        if 0 or omitted, program will cycle through all files
%               in the data directory. 
%                   
%               if 1, user will be prompted to select a file
%
%Written by ML Caras Mar 27 2019


%Validate inputs
narginchk(1,2)

%Check if binary directory exists. 
if ~exist(binarydir,'dir')
     fprintf('\nCannot find binary directory!\n')
    return
end


%Default to cycling through all  files
if nargin < 2
    sel = 0;   
end


if ~sel
    %Get a list of all folders in the data directory
    folders = caraslab_lsdir(datadir);
    foldernames = extractfield(folders,'name');

elseif sel  
    %Prompt user to select folder
    pname = uigetdir(datadir,'Select data directory');
    [~,name] = fileparts(pname);
    foldernames = {name};  
    
end


%For each data folder...
for i = 1:numel(foldernames)
    clear ops temp dat
    
    %Define the path to the current data
    currpath = fullfile(datadir,foldernames{i});
    
    %Load in configuration file (contains ops struct)
    load(fullfile(currpath, 'Config.mat'));
    
    %Find the -mat file to convert
    matfile = ops.readyforsorting;
    
    %Load -mat data file
    fprintf('Loading -mat file: %s.......\n', matfile)
    tic;
    temp = load(matfile);
    tEnd = toc;
    fprintf('Loaded in: %d minutes and %f seconds\n', floor(tEnd/60),rem(tEnd,60));
    
    %Prepare data for conversion to int16
    dat = temp.epData.streams.RSn1.data;
    dat = dat./max(abs(dat)); %normalizes recording such that dat ranges from - 1 to 1
    dat = int16(dat.*single(intmax('int16'))); %rescales to use maximum range of int16 scale
    
    
    %Write the data to a binary file
    fid = fopen(ops.fbinary,'w');
    if fid == -1
        fprintf('Cannot create binary file!')
        return
    end
    
    fprintf('Writing binary file: %s.......\n', strcat(name,'.dat'))
    tic;
    fwrite(fid,dat,'int16'); 
    fclose(fid);
    tEnd = toc;
    fprintf('Finished in: %d minutes and %f seconds\n', floor(tEnd/60),rem(tEnd,60));
    
end







