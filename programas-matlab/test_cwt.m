clear; clc; close all;

puerto = "COM4"; 
baudrate = 460800; 

try
    s = serialport(puerto, baudrate);
    configureTerminator(s, "CR/LF");
    flush(s);
catch
    error('No se pudo abir el puerto UART');
end

%% Señal de Prueba (cambiable entre chirp y señal real)
fs = 16000;
t = (0:fs-1) / fs;

%sig_test = chirp(t, 50, 0.1, 6000);

filename = 'rec_13.wav'; %tc 26, banda baja

t_evento_inicio = 32;
t_evento_fin    = 33;
[full_signal, fs] = audioread(filename);
full_signal = full_signal(:, 1); 


idx_inicio = round(max(0, t_evento_inicio) * fs) + 1;
idx_fin    = round(min((length(full_signal)-1)/fs, t_evento_fin) * fs);

sig_test = full_signal(idx_inicio : idx_fin);

sig_tx = int16(sig_test * 16000); 

%% Transmitir señal
disp('Inicio transmisión de señal');
tamano_paquete = 1000; % Muestras por paquete
num_paquetes = floor(length(sig_tx) / tamano_paquete);

for i = 1:num_paquetes
    inicio = (i-1)*tamano_paquete + 1;
    fin = i*tamano_paquete;
    write(s, sig_tx(inicio:fin), "int16");
    pause(0.005); 
end

if fin < length(sig_tx)
    write(s, sig_tx(fin+1:end), "int16");
end
disp('Transmisión finalizada');

%% Recibir Datos
disp('Esperando respuesta');
pause(4);

bytes_disponibles = s.NumBytesAvailable;
if bytes_disponibles == 0
    error('No se recibieron datos');
end
datos_raw = read(s, bytes_disponibles, "uint8");


%disp(['Bytes recibidos en total: ', num2str(length(datos_raw))]);

magic_word = uint8([255 170 255 170]); % 0xFF 0xAA 0xFF 0xAA
idx = strfind(datos_raw, magic_word);

if isempty(idx)
error('No se encontró el Magic Word');
end

inicio_matriz = idx(end) + length(magic_word);

num_bandas = 24;
num_frames = 124;

bytes_esperados = num_bandas * num_frames * 4; % float32 = 4 bytes

% Verificar que haya suficiente información después del header
bytes_disponibles_despues = length(datos_raw) - inicio_matriz + 1;

if bytes_disponibles_despues < bytes_esperados
error(['Datos incompletos']);
end

% Extraer bytes necesarios
bytes_matriz = datos_raw(inicio_matriz : inicio_matriz + bytes_esperados - 1);

%{
if mod(length(bytes_matriz), 4) ~= 0
error('El tamaño de bytes no es múltiplo de 4');
end
%}
disp(['Floats recibidos: ', num2str(length(bytes_matriz)/4)]);

% Convertir a float32 (single)
bandEnergy_1d = typecast(uint8(bytes_matriz), 'single');

matriz_stm32 = reshape(bandEnergy_1d, num_frames, num_bandas)';

disp('¡Matriz recibida y reconstruida correctamente!');

frames_reales = size(matriz_stm32, 2);
disp(['Frames reales reconstruidos: ', num2str(frames_reales)]);
disp('¡Matriz recibida, alineada a 32 bits y reconstruida con éxito!');

%% Visualización y Comparación
figure('Name','Comparación STM32 vs MATLAB','Position',[100 50 800 1000])
%señal en el tiempo
subplot(4,1,1);
t_signal = (0:length(sig_test)-1) / fs; 
plot(t_signal, sig_test, 'k'); 
title('Señal de Prueba en el Dominio del Tiempo');
xlabel('Tiempo (s)');
ylabel('Amplitud');
grid on;
xlim([0 max(t_signal)]); 
% Señal de STM32
subplot(4,1,2);
t_frames = linspace(0, max(t_signal), frames_reales);

band_freq_hz = [
     31,   62,   93,  125,  156, ...  % Bandas 1-5
    202,  265,  327,  406,  499, ...  % Bandas 6-10
    609,  734,  890, 1093, 1327, ...  % Bandas 11-15
   1609, 1953, 2359, 2843, 3421, ...  % Bandas 16-20
   4109, 4921, 5890, 6968 ...         % Bandas 21-24
];

imagesc(t_frames, band_freq_hz, 10*log10(matriz_stm32 + 1));
shading flat;
set(gca, 'YDir', 'normal', 'YScale', 'log');
colormap(jet);
title('Componentes frecuenciales calculadas en STM32 (24 Bandas)');
xlabel('Tiempo (s)');
ylabel('Frecuencia (Hz)');
xlim([0 max(t_signal)]);
ylim([31 7500]); 

% STFT en maltab
subplot(4,1,3);
win_size = 256;
hop_size = 128;
noverlap = win_size - hop_size;
nfft = 2048; 
[S, F_stft, T_stft] = spectrogram(sig_test, hamming(win_size), noverlap, nfft, fs);
S_dB = 10*log10(abs(S).^2 + eps);
clim_max = max(S_dB(:));
clim_min = clim_max - 65; 
pcolor(T_stft, F_stft, S_dB);
shading flat; 
caxis([clim_min clim_max]);
set(gca, 'YDir', 'normal', 'YScale', 'log');
colormap(jet);
title('STFT en MATLAB');
xlabel('Tiempo (s)');
ylabel('Frecuencia (Hz)');
xlim([0 max(t_signal)]);
ylim([500 8000]);

% CWT MATLAB
subplot(4,1,4);
[wt, f_cwt] = cwt(sig_test, fs); 
imagesc(t_signal, f_cwt, abs(wt));
set(gca, 'YDir', 'normal', 'YScale', 'log'); 
ylim([100 7500]);
colormap(jet);
title('Transformada Wavelet Continua (CWT) Real - MATLAB');
xlabel('Tiempo (s)');
ylabel('Frecuencia (Hz)');
xlim([0 max(t_signal)]);

%% slices

t_eval = 0.89;
idx_eval_sig = round(t_eval * fs) + 1;

t_eval2 = 0.93; 
idx_eval_sig2 = round(t_eval2 * fs) + 1;

[~, idx_stm32] = min(abs(t_frames - t_eval2));
[~, idx_stft] = min(abs(T_stft - t_eval));


figure('Name', sprintf('Corte Transversal STFT en t = %.3f s', t_eval), 'Position', [150 100 800 800])

subplot(3, 1, 1);
plot(t_signal, sig_test, 'k'); hold on;
xline(t_eval, 'r', 'LineWidth', 2, 'Label', sprintf('t = %.3f s', t_eval), 'LabelVerticalAlignment', 'bottom');
title('Señal de Prueba en el Dominio del Tiempo');
xlabel('Tiempo (s)');
ylabel('Amplitud');
grid on;
xlim([0 max(t_signal)]);

subplot(3, 1, 2);
slice_stm32 = matriz_stm32(:, idx_stm32);
plot(band_freq_hz, slice_stm32, '-o', 'LineWidth', 1.5, 'Color', '#D95319', 'MarkerFaceColor', '#D95319');
title(sprintf('Slice STM32 (24 Bandas) en t = %.3f s', t_frames(idx_stm32)));
xlabel('Frecuencia (Hz)');
ylabel('Magnitud');
grid on;
set(gca, 'XScale', 'log'); 
xlim([min(band_freq_hz) max(band_freq_hz)]);

subplot(3, 1, 3);
slice_matlab = abs(S(:, idx_stft));
plot(F_stft, slice_matlab, '-', 'LineWidth', 1.5, 'Color', '#0072BD');
title(sprintf('Slice STFT MATLAB en t = %.3f s', T_stft(idx_stft)));
xlabel('Frecuencia (Hz)');
ylabel('Magnitud');
grid on;
