function files = caraslab_lsf(directoryname,filetype)
%files = caraslab_lsf(directoryname,filetype)
%
%Creates a list of files for a directory.  The file extension is indicated
%by filetype.
%
%%Written by ML Caras Mar 25 2019

%Obtain a list of files (not directories) in the directory
files = dir(fullfile(directoryname, filetype));
ind=find(~[files.isdir]); 

%Make sure they're real files
files = files(ind); %#ok<*FNDSB>
ind_real = cell2mat(arrayfun(@(x)(~strcmp(x.name(1),'.')),files,'UniformOutput',false));
fileIndex = find(ind_real == 1);
files = files(fileIndex);

end