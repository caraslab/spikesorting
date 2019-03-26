function caraslab_CAR(datadir,sel)
%caraslab_CAR(datadir,sel)
%
%This function applies common average referencing to data. See Ludwig
%(2009) for more details on the algorithm. The code that actually applies
%the CAR was taken from the https://github.com/cortex-lab/spikes repo,
%which houses code from the Harris and Carandini labs at UCL.
%
%Written by ML Caras Mar 26 2019


%Validate inputs
narginchk(1,2)
if ~exist(datadir,'dir')
    fprintf('\nCannot find data directory!\n')
    return
end

%Default to cycling through all -mat files
if nargin < 2
    sel = 0;   
end


if ~sel
    %Get a list of all files in the data directory
    folders = caraslab_lsdir(datadir);
    foldernames = extractfield(folders,'name');

elseif sel  
    %Prompt user to select file
    pname = uigetdir(datadir,'Select data directory');
    [~,name] = fileparts(pname);
    foldernames = {name};  
    
end


%For each data folder...
for i = 1:numel(foldernames)
    clear ops medianTrace outputFilename configfilename name ext
    
    %Define the path to the current data
    currpath = fullfile(datadir,foldernames{i});
    
    %Load in configuration file (contains ops struct)
    configfilename = (fullfile(currpath, 'config.mat'));
    load(configfilename);
    [~,name,ext] = fileparts(ops.fbinary);

    %Apply common average referencing
    fprintf('--------------------------------\n')
    fprintf('Processing %s\n',strcat(name,ext));
    [outputFilename,~] = applyCARtoDat(ops.fbinary, ops.NchanTOT, currpath);
    
    %Update ops structure to point to CAR datafile
    ops.fbinary = outputFilename;
    [~,name,ext] = fileparts(ops.fbinary);
    save(configfilename,'ops')
    fprintf('Updated ops.fbinary to %s\n',strcat(name,ext));

end









