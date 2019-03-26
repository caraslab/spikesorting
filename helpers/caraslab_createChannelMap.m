function caraslab_createChannelMap(savedir,probetype)
%caraslab_createChannelMap(savedir,probetype)
%
%Create a channel map file for a specific probe type
%
% Input variables:
%   savedir:    directtory to save channelmap file (-mat)
%  
%   probetype:  specifies the probe style used for recordings
%                   'NNBuz5x1264':  Neuronexus Buzsaki 5x12 H64LP
%                   'NN4x16Poly64': Neuronexus A4x16 Poly2 H64LP
%                   'NNA4x16Lin64': Neuronexus A4x16 Linear  H64LP
%                   'CamASSY156P':  Cambridge NeuroTech ASSY156 P Series
%                   'NN4x4H16':     Neuronexus A4x4 200-200-1250 H16 21mm
%
% Notes: kcoords is used to forcefully restrict templates to channels in the same
% channel group. An option can be set in the master_file to allow a fraction 
% of all templates to span more channel groups, so that they can capture shared 
% noise across all channels. This option is ops.criterionNoiseChannels = 0.2; 
% If this number is less than 1, it will be treated as a fraction of the total number of clusters
% If this number is larger than 1, it will be treated as the "effective
% number" of channel groups at which to set the threshold. So if a template
% occupies more than this many channel groups, it will not be restricted to
% a single channel group.



%How many channels are on your probe?
switch probetype
    case {'NNBuz5x1264','NN4x16Poly64','NNA4x16Lin64','CamASSY156P'}
        Nchannels = 64;
        deadchan = 64;
        
    case 'NN4x4H16'
        Nchannels = 16;
        deadchan = 16;
end
        

switch probetype
    case 'NNBuz5x1264'
        %Define the channel groups:
        shank1L = [61,60,63,62,58,59]; %left side of shank 1
        shank1R = [54,55,52,53,57,56]; %right side of shank 1
        
        shank2L = [49,48,51,50,18,17]; %left side of shank 2
        shank2R = [21,24,26,25,22,20]; %right side of shank 2
        
        shank3L = [32,29,30,28,31,27]; %left side of shank 3
        shank3R = [2,3,4,6,1,5];       %right side of shank 3
        
        shank4L = [11,10,8,7,12,14];   %left side of shank 4
        shank4R = [47,46,45,44,16,15]; %right side of shank 4
        
        shank5L = [40,41,42,43,39,38]; %left side of shank 5
        shank5R = [35,34,64,33,36,37]; %right side of shank 5
        
        extrasites = [23,9,19,13];     %extra sites on shank 3
        
        %Create the channel map (and a version that's indexed starting at zero)
        chanMap = [shank1L,shank1R,shank2L,shank2R,shank3L,shank3R,shank4L,shank4R,shank5L,shank5R,extrasites];
        chanMap0ind = chanMap - 1;
        
        %-----------------------------------------------------------------------
        %Define the x coordinates for each channel group (in relative microns)
        %-----------------------------------------------------------------------
        %On each shank, sites are spaced in two columns, set 20 um apart
        xL = zeros(1,6);
        xR = zeros(1,6)+20;
        
        %Shank 1 will be defined as starting at position 0
        Xshank1L = xL;
        Xshank1R = xR;
        
        %Shank 2 is 200 um away from shank 1
        Xshank2L = 200+xL;
        Xshank2R = 200+xR;
        
        %Shank 3 is 400 um away from shank 1
        Xshank3L = 400+xL;
        Xshank3R = 400+xR;
        
        %Shank 4 is 600 um away from shank 1
        Xshank4L = 600+xL;
        Xshank4R = 600+xR;
        
        %Shank 5 is 800 um away from shank 1
        Xshank5L = 800+xL;
        Xshank5R = 800+xR;
        
        %The extra sites are centered on shank 3 (i.e. 10 um offset from the columns)
        Xextra = 10 + Xshank3L(1:4);
        
        %Concatenate to define the x coordinates
        xcoords = [Xshank1L,Xshank1R,Xshank2L,Xshank2R,Xshank3L,Xshank3R,Xshank4L,Xshank4R,Xshank5L,Xshank5R,Xextra];
        
        
        %-----------------------------------------------------------------------
        %Define the y coordinates for each channel group (in relative microns)
        %-----------------------------------------------------------------------
        %Left column starts 55 um above the tip,
        %and extends upwards in 20 um spacing
        yL = 55:20:(55+20*5);
        
        %Right column starts 35 um above the tip,
        %and extends upward in 20 um spacing
        yR = 35:20:(35+20*5);
        
        %Extra sites start 200 um above the top most site on the left,
        %and extend upwards in 200 um spacing
        Yextra = [yL(end)+200, yL(end)+400, yL(end)+600, yL(end)+800];
        
        %Shank 1
        Yshank1L = yL;
        Yshank1R = yR;
        
        %Shank 2
        Yshank2L = yL;
        Yshank2R = yR;
        
        %Shank 3
        Yshank3L = yL;
        Yshank3R = yR;
        
        %Shank 4
        Yshank4L = yL;
        Yshank4R = yR;
        
        %Shank 5
        Yshank5L = yL;
        Yshank5R = yR;
        
        %Concatenate to define the y coordinates
        ycoords = [Yshank1L,Yshank1R,Yshank2L,Yshank2R,Yshank3L,Yshank3R,Yshank4L,Yshank4R,Yshank5L,Yshank5R,Yextra];
        
        
        %-----------------------------------------------------------------------
        %Define the k coordinates for each channel group
        %-----------------------------------------------------------------------
        %The k coordinates indicate the group that each channel belongs to. Nearby
        %sites on a single shank might pickup activity from the same neuron, for
        %instance, and thus belong to the same group, but sites that are spaced far
        %apart, or on different shanks, could not possibly pick up the same unit,
        %and thus should be identified as being members of different groups.
        %Specifying the groups will help Kilosort's algorithm discard noisy
        %templates that are shared across groups.
        
        Kshank1 = ones(1,12);
        Kshank2 = Kshank1+1;
        Kshank3 = Kshank1+2;
        Kshank4 = Kshank1+3;
        Kshank5 = Kshank1+4;
        Kextra = [6:9];
        
        kcoords = [Kshank1,Kshank2,Kshank3,Kshank4,Kshank5,Kextra];
        
    otherwise
        fprintf('\nProbe dimensions not specified!\nEdit caraslab_CreateChannelMapFile.m to add dimensions before map can be generated.\n')
        return
end


%-----------------------------------------------------------------------
%Identify dead (or disconnected) channels
%-----------------------------------------------------------------------
deadind = find(chanMap == deadchan);
connected = true(Nchannels, 1); % a 'connected' channel is one that is active (not dead)
connected(deadind) = false;     %#ok<*NASGU>

xcoords(deadind) = NaN;
ycoords(deadind) = NaN;
kcoords(deadind) = NaN;

fs = 25000; % sampling frequency

filename = fullfile(savedir,[probetype,'.mat']);
save(filename,'chanMap','connected', 'xcoords', 'ycoords', 'kcoords', 'chanMap0ind', 'fs')
fprintf('Saved channel map file: %s \n',filename);

 