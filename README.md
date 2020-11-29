# spikesorting
Contains pipeline for spike sorting multi-channel data acquired with TDT hardware.This is the current somewhat-stable version of the pipeline. 

Preprocessing steps convert data from TDT native format to -mat files. Files are then converted to binary (-dat), common average referencing and high-pass filtering are applied, and data is run through kilosort for sorting. This version runs with the modified Kilosort2 code also present in this repository. First, install Kilosort2 according to the developers' instructions, then replace all files in Kilosort2 folder with the files in this repository.
