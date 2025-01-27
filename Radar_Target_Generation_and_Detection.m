clear all
clc;

%% Radar Specifications 
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Frequency of operation = 77GHz
% Max Range = 200m
% Range Resolution = 1 m
% Max Velocity = 100 m/s
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%speed of light = 3e8
%% User Defined Range and Velocity of target
% *%TODO* :
% define the target's initial position and velocity. Note : Velocity
% remains contant
R = 110; % Range of target
v = -20; % velocity of target (running away) [-70->+70]
c = 3e8; % speed of light


%% FMCW Waveform Generation

% *%TODO* : Done
%Design the FMCW waveform by giving the specs of each of its parameters.
% Calculate the Bandwidth (B), Chirp Time (Tchirp) and Slope (slope) of the FMCW
% chirp using the requirements above.


%Operating carrier frequency of Radar 
fc= 77e9;             %carrier freq
rangeRes = 1;         %range resolution
Rmax = 200;           %max detectable range
B = c / (2*rangeRes); %Chirp Bandwidth, Bsweep
Tchirp = 5.5 *  2 * Rmax / c;
slope = B / Tchirp;
                                                          
%The number of chirps in one sequence. Its ideal to have 2^ value for the ease of running the FFT
%for Doppler Estimation. 
Nd=128;                   % #of doppler cells OR #of sent periods % number of chirps

%The number of samples on each chirp. 
Nr=1024;                  %for length of time OR # of range cells

% Timestamp for running the displacement scenario for every sample on each
% chirp
t=linspace(0,Nd*Tchirp,Nr*Nd); %total time for samples

display(t);

%Creating the vectors for Tx, Rx and Mix based on the total samples input.
Tx=zeros(1,length(t)); %transmitted signal
Rx=zeros(1,length(t)); %received signal
Mix = zeros(1,length(t)); %beat signal

%Similar vectors for range_covered and time delay.
r_t=zeros(1,length(t));
td=zeros(1,length(t));


%% Signal generation and Moving Target simulation
% Running the radar scenario over the time.

for i=1:length(t)
    
    
    % *%TODO* :
    %For each time stamp update the Range of the Target for constant velocity. 
    r_t(i) = (R + t(i) * v);
    
    % Time delay is amount of time needed for the electromagnetic wave
    % to reach the target, reflect back and be received by the receiver
    % since speed of electromagnetic wave is speed of causality (aka light),
    % doubling the amount of time for the wave to reach the target is
    % enough
    td(i) = 2 * r_t(i) / c;
    
    % *%TODO* :
    %For each time sample we need update the transmitted and
    %received signal. 
    Tx(i) = cos(2 * pi * (fc * t(i) + slope * (t(i)^2) / 2));
    Rx(i) = cos(2 * pi * (fc * (t(i) - td(i)) + slope * ((t(i) - td(i))^2) / 2));
    
    % *%TODO* :
    %Now by mixing the Transmit and Receive generate the beat signal
    %This is done by element wise matrix multiplication of Transmit and
    %Receiver Signal
    % NOTE: No need to do it inside loop, once Tx and Rx are both
    % accomodated, we can simply do Tx .* Rx after loop ends.
end
Mix = Tx .* Rx;

%% RANGE MEASUREMENT


 % *%TODO* :
%reshape the vector into Nr*Nd array. Nr and Nd here would also define the size of
%Range and Doppler FFT respectively.
Mix = reshape(Mix, [Nr, Nd]);

 % *%TODO* :
%run the FFT on the beat signal along the range bins dimension (Nr) and
%normalize.
fft_mix = fft(Mix) / Nr;

 % *%TODO* :
% Take the absolute value of FFT output
fft_mix = abs(fft_mix);

 % *%TODO* :
% Output of FFT is double sided signal, but we are interested in only one side of the spectrum.
% Hence we throw out half of the samples.
fft_mix = fft_mix(1 : Nr/2 + 1);


%plotting the range
figure ('Name','Range from First FFT');
subplot(2,1,1);

 % *%TODO* :
 % plot FFT output
 % Sampling frequency is Nr * Nd
f = (0:(Nr/2));
axis ([0 200 0 1]);
plot(f, fft_mix);




%% RANGE DOPPLER RESPONSE
% The 2D FFT implementation is already provided here. This will run a 2DFFT
% on the mixed signal (beat signal) output and generate a range doppler
% map.You will implement CFAR on the generated RDM


% Range Doppler Map Generation.

% The output of the 2D FFT is an image that has reponse in the range and
% doppler FFT bins. So, it is important to convert the axis from bin sizes
% to range and doppler based on their Max values.

Mix=reshape(Mix,[Nr,Nd]);

% 2D FFT using the FFT size for both dimensions.
sig_fft2 = fft2(Mix,Nr,Nd);

% Taking just one side of signal from Range dimension.
sig_fft2 = sig_fft2(1:Nr/2,1:Nd);
sig_fft2 = fftshift (sig_fft2);
RDM = abs(sig_fft2);
RDM = 10*log10(RDM);

%use the surf function to plot the output of 2DFFT and to show axis in both
%dimensions
doppler_axis = linspace(-100,100,Nd);
range_axis = linspace(-200,200,Nr/2)*((Nr/2)/400);
figure,surf(doppler_axis,range_axis,RDM);

%% CFAR implementation

%Slide Window through the complete Range Doppler Map

% *%TODO* :
%Select the number of Training Cells in both the dimensions.
Tr = 12; % band in range dimension
Td = 3; % band in doppler dimension

% *%TODO* :
%Select the number of Guard Cells in both dimensions around the Cell under 
%test (CUT) for accurate estimation
Gr = 4; % band in range dimension
Gd = 1; % band in doppler dimension

% *%TODO* :
% offset the threshold by SNR value in dB
offset = 21;

% Total number of training and guard cells
%           range side of rectangle    doppler side of rect    rect covering guards and a target
numTraining = (2 * Tr + 2 * Gr + 1) * (2 * Td + 2 * Gd + 1) - (2 * Gr + 1) * (2 * Gd + 1);

% *%TODO* :
%Create a vector to store noise_level for each iteration on training cells
CFAR = zeros(size(RDM));


% *%TODO* :
%design a loop such that it slides the CUT across range doppler map by
%giving margins at the edges for Training and Guard Cells.
%For every iteration sum the signal level within all the training
%cells. To sum convert the value from logarithmic to linear using db2pow
%function. Average the summed values for all of the training
%cells used. After averaging convert it back to logarithimic using pow2db.
%Further add the offset to it to determine the threshold. Next, compare the
%signal under CUT with this threshold. If the CUT level > threshold assign
%it a value of 1, else equate it to 0.


   % Use RDM[x,y] as the matrix from the output of 2D FFT for implementing
   % CFAR

% ri -- range index
for ri = Tr+Gr+1:Nr/2-(Gr+Tr)
    % di -- doppler index
    for di = Td+Gd+1:Nd-(Gd+Td)
        % slice within [ri-Tr-Gr:ri+Tr+Gr, di-Td-Gd:di+Td+Gd] includes
        %  - Training Cells, Guarde Cells and 1 target cell
        %  - Taking this slice and 0-ing anything that is not training cell
        %    will allow us to easily sum up all training cells. Since we
        %    know how many training cells we have, finding the mean is
        %    straightforward
        trainingSlice = RDM(ri-Tr-Gr:ri+Tr+Gr, di-Td-Gd:di+Td+Gd);
        
        % anything from [ri-Gr:ri+Gr, di-Gd:di+Gd] is not training cells
        trainingSlice(ri-Gr:ri+Gr, di-Gd:di+Gd) = 0;
        
        % convert from db to power
        trainingSlice = db2pow(trainingSlice);
        
        % find mean of training cells, it's vector of sum of each column
        % elements.
        mean = sum(trainingSlice) / numTraining;
        
        % mean is in power, convert it to db
        mean = pow2db(mean);
        
        % threshold is a little above the mean, so add the offset
        threshold = mean + offset; 

        % check if CUT is above threshold
        if (RDM(ri, di) > threshold)
            CFAR(ri,di) = 1;
        end
    end
end





% *%TODO* :
% The process above will generate a thresholded block, which is smaller 
%than the Range Doppler Map as the CUT cannot be located at the edges of
%matrix. Hence,few cells will not be thresholded. To keep the map size same
% set those values to 0. 
% Note, since the CFAR was defined as a 0 vector, these values are already 0

% *%TODO* :
%display the CFAR output using the Surf function like we did for Range
%Doppler Response output.
figure,surf(doppler_axis,range_axis,CFAR);
colorbar;


 
 