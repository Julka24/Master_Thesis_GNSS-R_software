%% RUN THIS PART FIRST TO VISUALLY DETERMINE t_cut

clear
clc
close all

% LOAD DIRECT SIGNAL FILES
track_d_full=load("260416_Two_Computers\Test_4\RFA_Tracking\tracking_ch_6.mat");
tele_d = load("260416_Two_Computers\Test_4\RFA_Telemetry\telemetry_ch_6.mat");

% CONSTANTS
c= 3e8;                                                                    % Speed of light [m/s]
fc=1575.42e6;                                                               % Carrier freq [Hz]
fs=4e6;                                                                     % SDR sampling frequency [Hz]
fIF=0;                                                                      % Intermediate frequency [Hz]
dt_samp=1/fs;                                                               % SDR sampling time step [s]
chip_rate=1.023e6;                                                          % CA code freq [Hz]
chips_number=1023;                                                          % No. of chips per period [-]
chip_period =1/chip_rate;                                                   % CA code period [s]
t_epoch = chips_number/chip_rate;                                           % CA code epoch time [s]
dt_track = 1e-3;                                                            % Tracking data period [s]
dt_tele   = 20e-3;                                                          % Nav message period [s]
prn =8;                                                                     % PRN of satellite of interest

% DETERMINE WHERE THE NAV AND TRACKING DATA INTESECT BASED ON COUNTERS
track_counter = double(track_d_full.PRN_start_sample_count(:));             % Converion of track counter into a double column
tele_counter = double(tele_d.tracking_sample_counter(:));                   % Converion of tele counter into a double column

[~,idx_track, idx_tele] = intersect(track_counter, tele_counter);           % Defining intersection of track and tele counters

fprintf('====== Track and Tele alignment ======\n');
fprintf('Number of matched samples:         %d\n',length(idx_track));       % Display number of matched samples

track_start = idx_track(1);                                                 % Define counter corresponding to 1st matched value
track_end   = idx_track(end);                                               % define counter corresponding to last matched value
track_section = track_start:track_end;                                      % Define track section span for intersected counters
N_section = length(track_section);                                          % Number of samples in the track section
t_section = (0:N_section-1)*dt_track;                                       % Track section expressed in seconds

t_cut = 0.079;                                                              % Data quality boarder in seconds
N_cut = t_cut/dt_track;                                                     % Number of samples chosen to be used for signal replica; chosen "manually"
track_section_cut = track_start:track_start+N_cut-1;                        % New track section of N_cut samples
t_section_cut = (0:N_cut-1)*dt_track;                                       % New track section of N_cut samples expressed in seconds

t_track = (0:length(track_counter)-1)' * dt_track;
t_tel   = (0:length(tele_counter)-1)'  * dt_tele;

t_track_ref = t_track - t_track(idx_track(1));
t_tel_ref   = t_tel   - t_tel(idx_tele(1));

% GENERAL PROPERTIES OF DIRECT SIGNAL
track_d1=figure;

% CARRIER TO NOISE RATIO
subplot(4,1,1);
plot(t_section, track_d_full.CN0_SNV_dB_Hz(track_section),"b");
xlim([0 t_section(end)]);
yline(25,'--r','C/N0 lock threshold');
xline(t_cut,'m--', sprintf('t = %.3f s',t_cut));
xlabel('Time [s]');
ylabel('C/N0 [dB-Hz]');
title('C/N0');

% CARRIER LOCK TEST
subplot(4,1,2);
plot(t_section, track_d_full.carrier_lock_test(track_section),"g");
ylim([0 1.2]);
xlim([0 t_section(end)]);
yline(1,'--r','Positive lock test');
xline(t_cut,'m--',sprintf('t = %.3f s',t_cut));
xlabel('Time [s]');
ylabel('Carrier lock test');
title('Carrier Lock Test');

% CARRIER DOPPLER 
subplot(4,1,3);
plot(t_section, track_d_full.carrier_doppler_hz(track_section), "r");%,':'
xlim([0 t_section(end)]);
xline(t_cut,'m--',sprintf('t = %.3f s',t_cut));
xlabel('Time [s]');
ylabel('Doppler frequency [Hz]');
title('Doppler frequency');

% CA CODE FREQUENCY
subplot(4,1,4);
plot(t_section, track_d_full.code_freq_chips(track_section));
xlim([0 t_section(end)]);
xline(t_cut,'m--',sprintf('t = %.3f s',t_cut));
xlabel('Time [s]');
ylabel('Code frequency [chips/s]');
title('Code frequency');

sgtitle(sprintf('PRN %d - Direct Signal', prn));

% I AND Q PROMPT SCATTERPLOT
track_d2 = figure;

plot(track_d_full.Prompt_I(track_start:1:track_start+N_cut-1), track_d_full.Prompt_Q(track_start:1:track_start+N_cut-1),".",'MarkerSize', 8);
xlabel('I Prompt');
ylabel('Q Prompt')
axis equal;
xline(0,'--r');
yline(0,'--r');
grid on;
title(sprintf('Discrete-Time Scatter Plot PRN %d - Direct Signal', prn));

%% CA CODE GENERATOR FOR A GIVEN PRN

input_data = [ ...                                                          % chips used for CA generator
    2  6  1440;  3  7  1620;  4  8  1710;  5  9  1744;  1  9  1133; ...
    2 10  1455;  1  8  1131;  2  9  1454;  3 10  1626;  2  3  1504; ...
    3  4  1642;  5  6  1750;  6  7  1764;  7  8  1772;  8  9  1775; ...
    9 10  1776;  1  4  1156;  2  5  1467;  3  6  1633;  4  7  1715; ...
    5  8  1746;  6  9  1763;  1  3  1063;  4  6  1706;  5  7  1743; ...
    6  8  1761;  7  9  1770;  8 10  1774;  1  6  1127;  2  7  1453; ...
    3  8  1625;  4  9  1712;  5 10  1745;  4 10  1713;  1  7  1134; ...
    2  8  1456;  4 10  1713 ...
];

reg_g1 = ones(1,10);                                                        % Empty register for G1 generator
reg_g2 = ones(1,10);                                                        % Empty register for G2 generator

ca = zeros(1,chips_number);                                                 % Empty CA code array
ca_mapped=zeros(1,chips_number);                                            % Empty CA code mapped array

chip1 = input_data(prn,1);                                                  % Chip 1 for given PRN for G2
chip2 = input_data(prn,2);                                                  % Chip 2 for given PRN for G2

for i=1:chips_number                                                        % CA code shift register loop 

    % G1 generator
    g1=reg_g1(10);
    sum_g1=xor(reg_g1(3),reg_g1(10));
    reg_g1(2:10)=reg_g1(1:9);
    reg_g1(1)=sum_g1;

    % G2 generator
    g2=xor(reg_g2(chip1),reg_g2(chip2));
    sum_g2 = mod(reg_g2(2)+reg_g2(3)+...
             reg_g2(6)+reg_g2(8)+reg_g2(9)+...
             reg_g2(10),2);
    reg_g2(2:10)=reg_g2(1:9);
    reg_g2(1)=sum_g2;

    % CA generator
    ca(i)=xor(g1,g2);
end

for i=1:chips_number                                                        % CA code mapping loop 
    % Mapping CA 0->1, 1->-1
    ca_mapped(i)=1-2*ca(i);
end

% UPSAMPLE CA CODETO SAMP FREQ
samples_per_ms = round(fs*t_epoch);                                         % how many signal samples per CA code of 1ms
samples_per_chip_round = round(fs/chip_rate);                               % samples per chip rounded 
samples_per_chip_true = fs/chip_rate;                                       % samples per chip true
t_ca_code = (0:samples_per_ms-1)/fs;                                        % time array corresponding to fs
ca_upsampled = ca_mapped(floor...
              (t_ca_code*chip_rate)+1);                                     % CA code upsampled to fs
%% DIRECT SIGNAL REPLICA GENERATION

% Define components of replica
prn =double(track_d_full.PRN_start_sample_count(track_section_cut));        % PRN counter
doppler = track_d_full.carrier_doppler_hz(track_section_cut);               % Carrier Doppler
phase = track_d_full.acc_carrier_phase_rad(track_section_cut);              % Carrier phase

initial_offset_samples = mod(prn(1), samples_per_ms);                       % Determine intitial offset of prn code in samples
initial_offset_chips   = initial_offset_samples / samples_per_chip_true;    % Determine initial offset of prn code in chips

n_track_samp = length(prn);                                                 % Number of tracking samples used to generate replica
dt_ms_per_samp = 1;                                                         % Number of ms per one tracking sample
t_track_ms = n_track_samp*dt_ms_per_samp;                                   % Total replica time in ms

nav_start=idx_tele(1);                                                      % First point of nav cut segment 
nav_end = nav_start+floor(n_track_samp*(dt_track/dt_tele));                 % Length of the nav cut segment based on the track and nav sampling differences
nav_bits = double(tele_d.nav_symbol(nav_start:nav_end));                    % Nav bits cut to the chosen segment

replica = zeros(1,t_track_ms*samples_per_ms);                               % Empty array for replica

ms_counter = 0;                                                             % Milisecond counter, starting from 0

for i=1:n_track_samp                                                        % Replica building loop            

        ms_counter = ms_counter+1;                                          % Milisecond counter

        % CA code
        ca_local = ca_upsampled;

        % Nav message
        nav_idx = floor((i-1)/20) + 1;                                      % Creating nav index
        nav_bit = nav_bits(nav_idx);                                        % Reading nav bit for given index

        % Residual carrier
        fd=doppler(i);                                                      % Doppler value for a given track step                        
        phi = phase(i);                                                     % Phase value for a given track step
        dt = (0:samples_per_ms-1)/fs;                                       % Time increments
        carrier = exp(1j*(2*pi*fd*dt+phi));                                 % Residual carrier

        idx = (ms_counter-1)*samples_per_ms+1:ms_counter*samples_per_ms;    % Indexes that are increments of samples_per_ms 
        replica(idx) = nav_bit .* ca_local .* carrier;                      % Replica for a given ms, a vecotr of 1 ms equivalent values
end 

fprintf('\n====== Direct signal ======\n');
fprintf('Replica aligned to initial code phase\n');
fprintf('Initial code phase:                %.4f chips\n', initial_offset_chips);
fprintf('Replica built successfully:        %d samples\n', length(replica));       % Display length of replica

%% READING AND CUTTING REFLECTED SIGNAL TO [N_MIN:N_MAX] BOUNDARIES

bytes_per_sample = 8;                                                       % gr_complex is float32

start_refl_sample = prn(1);                                                 % Def. start of signal sample
end_refl_sample = start_refl_sample+length(replica);                        % Def. end of signal sample
num_refl_samples = end_refl_sample-start_refl_sample;                       % Def. number of signal sample

byte_offset = start_refl_sample*bytes_per_sample;                           % How many bytes into file to cut

fid = fopen('260424_PRN27_rerun\Reflected\signal_dump_ch1', 'rb');            % Open the whole big raw reflected signal file
fseek(fid, byte_offset, 'bof');                                             % Define the byte offset from beginning of file 
raw = fread(fid, 2*num_refl_samples, 'float32');                            % Read the data of given sample length in correct data format
fclose(fid);                                                                % Close the raw data file

if mod(length(raw),2) ~= 0                                                  % Rounding up if the data turns out to end on odd number of samples
    raw = raw(1:end-1);
end

I_cut = raw(1:2:end);                                                       % Write real I component
Q_cut = raw(2:2:end);                                                       % write imaginaty Q component
refl_signal_cut = complex(I_cut, Q_cut).';                                  % combine I and Q into complex signal

t_replica_total = length(refl_signal_cut)/fs;                               % total time of the replica signal
t_replica_fs = 1:length(refl_signal_cut);                                   % array of times for replica
 
% Find NaN values, determine their number and linearly interpolate them
nanIdx = isnan(real(refl_signal_cut)) | isnan(imag(refl_signal_cut));

I_clean = interp1(t_replica_fs(~nanIdx), real(refl_signal_cut(~nanIdx)), t_replica_fs, 'linear', 'extrap');
Q_clean = interp1(t_replica_fs(~nanIdx), imag(refl_signal_cut(~nanIdx)), t_replica_fs, 'linear', 'extrap');
refl_signal_cut_clean = (I_clean + 1i * Q_clean);

% Plot of firt 10000 samples of clean dataset
raw_IQ_cut = figure;
plot(real(refl_signal_cut_clean(1:10000)), "b");
hold on 
plot(imag(refl_signal_cut_clean(1:10000)), "g");
legend("Inphase signal", "Quadrature signal");
title("Clean IQ Data for the first 10000 points of reflected signal")

fprintf('\n====== Reflected signal ======\n');
fprintf('Reflected signal cut successfully: %d samples\n', ...
    length(refl_signal_cut_clean));                                         % Display length of reflected cut signal        
fprintf('Total reflected samples:           %d\n', numel(refl_signal_cut));
fprintf('NaN reflected samples:             %d (%.2f%%)\n', sum(nanIdx), 100*mean(nanIdx));
%% DELAY DOPPLER MAP

doppler_center = mean(doppler);                                             % Mean doppler value for direct signal     
doppler_range = 5000;                                                       % Doppler range of [-5000, +5000] Hz       
doppler_step = 10;                                                          % Doppler step           
doppler_bins =(-doppler_range:doppler_step:doppler_range);                  % Doppler bins
n_doppler = length(doppler_bins);                                           % Length of Doppler bins array

ms_integration = 1;                                                         % Coherent integration per segment 
samples_per_seg = round(ms_integration * 1e-3 * fs);                        % Number of samples per segment
n_segments      = floor(length(replica) / samples_per_seg);                 % Number of segments

N_fft=samples_per_seg;
delay_bins_samples = -N_fft/2:N_fft/2;
delay_bins_chips  = delay_bins_samples / samples_per_chip_true;             % Delay bin chips
delay_bins_meters = delay_bins_chips / chip_rate * c;                       % Conversion od delay chips into meters
n_delay = length(delay_bins_samples);                                       % Length of delay bins array

fprintf('\n====== DDM parameters ======\n');
fprintf('Doppler bins:                      %d (%.0f to %.0f Hz)\n', n_doppler, doppler_bins(1), doppler_bins(end));
fprintf('Delay bins:                        %d (%.1f to %.1f chips)\n', n_delay, delay_bins_chips(1), delay_bins_chips(end));
fprintf('Segments:                          %d x %d ms\n', n_segments, ms_integration);

DDM = zeros(n_doppler, n_delay);                                            % Empty matrix for DDM

t_seg = (0:samples_per_seg-1).' / fs;                                       % Time per segment, column vector
    
for d = 1:n_doppler                                                         % DDM LOOP

    f_d = doppler_bins(d);                                                  % Choosing a Doppler bin
    corr_incoherent = zeros(1, n_delay);

    for seg = 1:n_segments

        % Extract segment from reflected signal
        idx = (seg-1)*samples_per_seg + 1 : seg*samples_per_seg;            % Creates indexes for 1ms data bits 
        refl_column  = refl_signal_cut_clean(:);                            % Reshapes the cut reflected raw signal into a column vector
        refl_seg  = refl_column(idx);                                       % Extracts the reflected signal for a given segment

        % Strip Doppler from reflected segment
        doppler_wipe = exp(-1j*2*pi*f_d*t_seg);                             % Doppler wipe off component
        refl_wiped   = refl_seg .* doppler_wipe;                            % Remove Doppler component from residual carrier

        % Extract segment from replica signal
        replica_flat  = replica(:);                                         % Reshape seplica signal into a column vector
        replica_seg = replica_flat(idx);                                    % Extract the replica of direct signal for a given segment

        % FFT correlation of segment
        %N_seg = samples_per_seg;                                            % Determines the number of points for DFT
        refl_fft = fft(refl_wiped,   N_fft);                                % DFT of reflected signal segment
        direct_fft = fft(replica_seg,  N_fft);                              % DFT of direct signal replica segment
        corr  = ifft(refl_fft.*conj(direct_fft));                           % Correlation

        % Incoherently integrate over segments
        for k = 1:n_delay
            delay_samp = mod(delay_bins_samples(k), N_fft) + 1;             % Wrap the delay bins into segment length
            corr_incoherent(k) = corr_incoherent(k)+abs(corr(delay_samp))^2;% Accumulate the power from segments
        end

    end

    DDM(d, :) = corr_incoherent;                                            % Saves the correlation value for each Doppler bin 

end

fprintf('DDM built:                        %d x %d\n', size(DDM));          % Print resulting DDM size

%% DDM PLOTS AND DATA 
% NOISELESS REPLICA MAX VALUES 
[peak_doppler, peak_delay] = find(DDM == max(DDM(:)));                      % Peak Doppler bin and peak delay from DDM
peak_doppler_hz    = doppler_bins(peak_doppler);                            % Peak Doppler absolute value
peak_delay_chips   = delay_bins_chips(peak_delay);                          % Peak code delay 
peak_delay_meters  = delay_bins_meters(peak_delay);                         % Peak delay in meters

fprintf('\n====== DDM Peak ======\n');
fprintf('Peak correlation power:            %.4f \n',  DDM(peak_doppler,peak_delay));
fprintf('Doppler (absolute):                %.2f Hz\n',          peak_doppler_hz);
fprintf('Delay (chips):                     %.6f chips\n',       peak_delay_chips);
fprintf('Delay (m):                         %.2f m\n',           peak_delay_meters);

max_delay_per_doppler_bin = max(DDM, [], 2);                                % Column vecotr of maximum code delay for each Doppler bin
[~, peak_doppler_idx] = max(max_delay_per_doppler_bin);                     % The index of Doppler bin with the highest code delay 
delay_profile = (DDM(peak_doppler_idx, :));                                 % Correlation power for all code delays for bin that has the peak
[~, peak_delay_idx] = max(delay_profile);                                   % Delay index of the correlation peak

DDM_flat = figure;                                                          % Flat DDM plot 
imagesc(doppler_bins, delay_bins_chips, (DDM).');
colorbar;
colormap('jet');
ylabel('Code Delay [chips]', 'Fontsize', 20);
xlabel('Doppler Offset [Hz]', 'Fontsize', 20);
xlim([-1200 1200]);
ylim([-5 5]);
%title('Delay-Doppler Map (DDM)', 'Fontsize', 20);
clim([min(10*log10(DDM(:))), max((DDM(:)))]);  
fontsize(50,"points")

Delay_peak = figure;                                                        % Slice of DDM at the peak along Doppler
plot(delay_bins_chips, delay_profile, 'b-', 'LineWidth', 2);
xlabel('Code Delay [chips]', 'Fontsize', 20);
ylabel('Correlation Power', 'Fontsize', 20);
xline(delay_bins_chips(peak_delay_idx), 'r--', sprintf('%.4f chips', delay_bins_chips(peak_delay_idx)),'LabelOrientation','horizontal');
xlim([-1023/2 1023/2]);
fontsize(50,"points")
grid on;

half_power_line = linspace(-5000, 5000, 1001);
doppler_profile_func = DDM(:, peak_delay);
half_power = DDM(peak_doppler,peak_delay)/2;
[~, idx_half_power] = max(doppler_profile_func);
xq(1)=interp1(doppler_profile_func(1:idx_half_power), half_power_line(1:idx_half_power), half_power);
xq(2)=interp1(doppler_profile_func(idx_half_power+1:end), half_power_line(idx_half_power+1:end), half_power);

Doppler_peak = figure;                                                      % Slice of DDM at the peak along code delay
plot(doppler_bins, (DDM(:, peak_delay)), 'm-', 'LineWidth', 2);
xlabel('Doppler Offset [Hz]', 'Fontsize', 20);
ylabel('Correlation Power', 'Fontsize', 20);
xline(doppler_bins(peak_doppler_idx), 'r--', sprintf(' \\leftarrow %.2f Hz', doppler_bins(peak_doppler_idx)),'LabelOrientation','horizontal', 'LineWidth', 4);
xlim([doppler_bins(1) doppler_bins(end)])
fontsize(50,"points")
yline(half_power*2, "g:", 'Fontsize', 30, 'LineWidth',4)
yline(half_power, "b:", 'Fontsize', 30, 'LineWidth',4)
hold on
plot(xq, [1 1]*half_power, 'xr', 'MarkerSize', 20, 'LineWidth', 3)
hold off
legend({'Doppler profile', 'Peak Doppler', 'P_{corr\_max}', '0.5 \cdot P_{corr\_max}'}, 'FontSize',40);

grid on;

DDM_3D = figure;                                                            % 3D DDM plot
surf(delay_bins_chips, doppler_bins, (DDM), 'EdgeColor', 'none');
colorbar;
colormap('jet');
xlim([delay_bins_chips(1), delay_bins_chips(end)]);
ylim([doppler_bins(1), doppler_bins(end)]);
xlabel('Code Delay [chips]', 'Fontsize', 20);
ylabel('Doppler Offset [Hz]', 'Fontsize', 20);
zlabel('Correlation Power', 'Fontsize', 20);
fontsize(50,"points")

%% Other features 

delay_profile_noise = (DDM(1001, :));                                       % Correlation power for all code delays for bin that has the peak
noise_floor=mean(delay_profile_noise);
Doppler_bandwidth = xq(2)-xq(1);
Doppler_mean = (xq(1)+xq(2))/2;

fprintf('\n====== Noise and Doppler bandwidth ======\n');
fprintf('Noise floor:                       %.3f \n',  noise_floor);
fprintf('Doppler bandwidth:                 %.2f Hz\n',          Doppler_bandwidth);
fprintf('Doppler mean:                      %.2f \n',       Doppler_mean);
fprintf('Doppler min:                       %.2f Hz\n',           xq(1));
fprintf('Doppler max:                       %.2f Hz\n',           xq(2));