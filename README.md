# Master_Thesis_GNSS-R_software
This repository contains software used for my master's thesis at UIO: configuration files for GNSS-SDR that were used to collect direct and reflected GPS signals as well as MATLAB script for creating Reflectometry Delay Doppler Maps

== DDM Matlab script ==

The two first inputs are the tracking and telemetry files for the direct signal, denoted as "track_d\full" and "tele\d". Two of the parameters have to be written in the code manually: PRN and t_cut. The PRN is apriori known, but the t_cut is chosen based on the inspection of selected signal properties available in the tracking file:

	* C/N0 of at least 25 dB-Hz is required for GPS lock, values above 35 dB-Hz are considered very good;
	* Carrier lock test - this parameter is set to 1 if carrier lock is achieved. Any data with values less than 1 means unstable tracking;
	* Doppler frequency - this parameter can vary during the measurement time, but it is expected to be stable with little noise and located somewhere between -5 kHz and +5 kHz;
	* Code frequency - this value is expected to be stable with little noise around 1.023 MHz.

Firstly, only the first section of code is executed and t_cut is determined. After that, the file path to the raw reflected signal has to be specified. 

== GNSS-SDR config files ==

* "One_Antenna_Test.conf" is used to test individual antennas prior to saving the data to see if they detect GPS satellites;
* "Two_Antennas_Recording.conf" is used for recording and saving the raw IQ data from tow channels in USRP B210 used simultaneously;
* "Post_Processing.cong" is used to extract necessary GNSS DSP files used later for reflectometry DDMs, such as acquisition, tracking and telemetry files as well as PVT solution. This file requires inputting path to the file with raw file.
