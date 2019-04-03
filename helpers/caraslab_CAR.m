function  [refsig,badchans] = caraslab_CAR(sig,nchans,badchans);
%refsig = caraslab_CAR(sig,nchans,badchans)
%
% Common average referencing is implemented using matrix multiplication
% in the format D x C = R, where:
%
% C is a single time-slice of data in the shape [n x 1]. In other
% words, it is the value from all n channels sampled at a single point
% in time.
%
% D is a n x n matrix. Each row in the matrix defines the weights of the
% individual channels.
%
% R is the referenced output in the shape [n x 1].
%
% Input variables:
%   sig:    MxN matrix of voltage signals, where 
%               M = number of samples, and  
%               N = number of channels.
%           Data should already have had artifacts removed using 
%           caraslab_artifact_reject.m, and have been bandpass filtered. 
%
%   nchans: total number of recording channels (both active and dead)
%
%   badchans: identity of channels that aren't connected because 
%             they're used for wireless transmission
%
%
%EXAMPLES:
% If you were averaging together channels 2-16 of a 16 channel probe,
% and subtracting the mean from the first channel, the first row would
% contain the weights:
%
% [1 -1/15 -1/15 ... -1/15]
%
% If you were averaging together channels 2-64  of a 64 channel probe,
% and subtracting the mean from the first channel:
%
% [1 -1/63 -1/63 ... -1/63]
%
%
% If you were averaging together channels 3-8 of a 16 channel probe 
% (because channel 2 was bad) and subtracting the mean from the first
% channel:
%
% [1 0 -1/6 ... -1/6 0 0 0 ... 0]
%
% To average channels 1-4 and subtract the mean from the first channel:
%
% [3/4 -1/4 -1/4 -1/4 0 ... 0]
%
% To repeat the same process (average channels 1-4 and subtract the
% mean) for the second channel, the second row in the matrix would be:
%
% [-1/4 3/4 -1/4 -1/4 0 ... 0]
%
%
%For more information see Ludwig et al. (2009) J Neurophys 101(3):1679-89
%
%Written by ML Caras Apr 1 2019

%--------------------------------------------------------------------------
%Identify bad channels based on RMS of signal. Limits are taken directly
%from Ludwig et al. 2009.
rmsvals = rms(sig);
minrms = 0.3*mean(rmsvals);
maxrms = 2*mean(rmsvals);
toohigh = find(rmsvals > maxrms); %RMS noise floor too high
toolow = find(rmsvals < minrms); %RMS noise floor too low

if ~isempty(toohigh)
    badchans = [badchans,toohigh];
    fprintf('\nRMS noise floor of channel(s) %d exceeds maximum allowed! Removed from analysis!',toohigh)
end

if ~isempty(toolow)
    badchans = [badchans,toolow];
    fprintf('\nRMS noise floor of channel(s) %d is below minimum allowed! Removed from analysis!',toolow)
end

%Remove redundant channels
badchans = unique(badchans); 
%--------------------------------------------------------------------------


%Calculate weight for non-identical pairs
weight = -1/(nchans - numel(badchans) - 1);

%Initialize weight matrix
weightmat = repmat(weight,nchans,nchans);

%The weights of all bad channels are 0.
weightmat(:,badchans) = 0;

%Do not perform averaging on bad channels: leave as is.
weightmat(badchans,:) = 0;

%For each channel
for ch = 1:nchans
    
    %Its own weight is 1
    weightmat(ch,ch) = 1;
    
end


%Preallocate common average referencing matrix
refsig = NaN(size(sig));

%For each time slice of data, perform common average referencing
nsamples = size(sig,1);

for samp = 1:nsamples
    timeslice = sig(samp,:)';%make a column vector
    R = weightmat*timeslice;
    refsig(samp,:) = R';
end

