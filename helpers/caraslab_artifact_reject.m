function [finalsignal,rejectthresh] = caraslab_artifact_reject(rawsignal,fs)
%[finalsignal,rejectthresh] = caraslab_artifact_reject(rawsignal,fs)
%
% This function performs automatic artifact removal on raw in vivo
% extracellular physiology data. Artifact removal proceeds as follows:
% First, all peaks (both spikes and artifacts) with amplitudes greater than
% 5 median-based stdevs of the baseline noise are identified. Next, the
% median-based stdev of the amplitude of those peaks is calculated, and a
% rejection threshold is set to 2X that value. Any peaks with amplitudes
% exceeding this rejection threshold are considered to be artifacts. A
% window is set around each artifact peak, and the signal is set to zero
% within that window. This initial pass is somewhat conservative in 
% identifying artifacts. Therefore, a second pass is run, where the peak
% identifcation is performed on the initial cleaned signal, and remaining
% artifcats are identified and zeroed. 
%
% Input variables:
%   rawsignal:  MxN matrix of raw voltage values, where
%                   M = number of samples, and 
%                   N = number of channels
%
%   fs:         Sampling rate of data (in Hz)
%
% Output variables:
%   finalsignal: MxN matrix of cleaned voltage values,where 
%                   M = number of samples, and 
%                   N = number of channels. 
%                Note that cleaned signal is high-pass filtered at 100 Hz.
%
%   rejectthresh: artifact rejection threshold (V)
%
%
% Written by ML Caras Apr 1 2019
    

%Determine the number of channels
numchans = size(rawsignal,2);

%Define the number of samples before and after each artifact peak to be
%zeroed. This value was empirically determined.
win = 200; 

%Create initial highpass filter parameters
hp = 100;  %(Hz)
[b1, a1] = butter(3,(hp/fs)*2, 'high');

%Highpass filter the raw signal
fprintf('Highpass filtering signal...\n')
sigflt = filter(b1, a1, rawsignal);
sigflt = flipud(sigflt);
sigflt = filter(b1, a1, sigflt);
sigflt = flipud(sigflt);


%---------------------------------------------------------------------
%First cleaning pass
fprintf('First pass artifact rejection...\n')
cleansignal = rm_artifacts(sigflt,numchans,win);

%---------------------------------------------------------------------
%Second cleaning pass
fprintf('First pass artifact rejection...\n')
[finalsignal,rejectthresh] = rm_artifacts(cleansignal,numchans,win);




function [cleansig,varargout] = rm_artifacts(sig,numchans,win)

cleansig = sig;

%Find all the peaks (spikes and artifacts) greater than 5 std above noise
stdbkg = median((abs(sig)/0.6745));
thresh = 5*stdbkg;

for ch = 1:numchans
    fprintf('Cleaning channel %d\n',ch)
    [pks,locs] = findpeaks(abs(sig(:,ch)),'MinPeakHeight',thresh(ch));
    
    %Determine threshold for artifact rejection
    rejectthresh = 2*median(pks/0.6745);
    
    %Find violations
    idx = find(pks>rejectthresh);
   
    %Define a window of samples around each violation and set signal to 0
    for i = 1:numel(idx)
        samp = locs(idx(i));
        cleansig(samp-win:samp+win,ch) = 0;
    end
    
end

if nargout>1
    varargout{1} = rejectthresh;
end
