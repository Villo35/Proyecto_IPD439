clear; clc; close all;

puerto = "COM3"; 
baudrate = 115200; 

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

% Ajustar la longitud de la senal para que sea multiplo exacto de 256
tamano_paquete = 256; 
num_paquetes = floor(length(sig_test) / tamano_paquete);
sig_test = sig_test(1 : num_paquetes * tamano_paquete);

sig_tx = int16(sig_test * 16000); 

%% Transmision y Recepcion
disp('Iniciando envio y recepcion');

j_tot = 16;
% 16 escalas * 256 muestras * 4 bytes (tamaño de un float32)
bytes_esperados = j_tot * tamano_paquete * 4; 

matriz_stm32_full = zeros(j_tot, length(sig_test)); 
magic_word = uint8([255 170 255 170]);

for i = 1:num_paquetes
    inicio_idx = (i-1)*tamano_paquete + 1;
    fin_idx = i*tamano_paquete;
    
    % Enviar frame de 256 muestras
    write(s, sig_tx(inicio_idx:fin_idx), "int16");
    
    % Leer header
    header = read(s, 4, "uint8");
    if isempty(header) || ~isequal(header, magic_word)
        error(['Error de sincronizacion', num2str(i)]);
    end
    
    datos_raw = read(s, bytes_esperados, "uint8");
    if length(datos_raw) < bytes_esperados
        error(['Datos incompletos ', num2str(i)]);
    end
    
    % pasar a uint8
    datos_raw = uint8(datos_raw); 
    
    % 4. Reconstruir la matriz
    datos_float = typecast(datos_raw, 'single');
    matriz_frame = reshape(datos_float, tamano_paquete, [])';
    
    if size(matriz_frame, 1) ~= j_tot
        warning('Se recibieron %d escalas en vez de %d en el paquete %d', size(matriz_frame, 1), j_tot, i);
    end
    
    matriz_stm32_full(:, inicio_idx:fin_idx) = matriz_frame;
    
    fprintf('Paquete %d / %d procesado.\n', i, num_paquetes);
end

disp('Procesamiento finalizado');

%% Visualizacion y Comparacion
figure('Name','Comparacion STM32 vs MATLAB','Position',[100 50 800 1000])

% señal en el tiempo
subplot(4,1,1);
t_signal = (0:length(sig_test)-1) / fs; 
plot(t_signal, sig_test, 'k'); 
title('Senal de Prueba en el Dominio del Tiempo');
xlabel('Tiempo (s)');
ylabel('Amplitud');
grid on;
xlim([0 max(t_signal)]); 

% señal de stm32
subplot(4,1,2);
imagesc(t_signal, 1:j_tot, matriz_stm32_full);
set(gca, 'YDir', 'reverse'); 
colormap(jet);
title('CWT calculada en STM32 (Analisis por Escalas)');
xlabel('Tiempo (s)');
ylabel('Escala');
xlim([0 max(t_signal)]);

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
ylabel('Frecuencia (Hz) [Log]');
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

clear s;