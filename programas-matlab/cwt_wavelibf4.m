clear; clc; close all;

%% 1. Configuracion del Puerto Serie
puerto = "COM4"; 
baudrate = 460800; 
try
    s = serialport(puerto, baudrate);
    configureTerminator(s, "CR/LF");
    s.Timeout = 15;
    flush(s);
catch
    error('No se pudo abir el puerto UART');
end

%% 2. Senal de Prueba
fs = 16000;
t = (0:fs-1) / fs;
%sig_test = chirp(t, 50, 0.1, 6000); 
%señal chirp. cambiar comentario con otra señal sig_test

filename = 'rec_13.wav'; %tc 26, banda baja
t_evento_inicio = 32;
t_evento_fin    = 33;
[full_signal, fs] = audioread(filename);
full_signal = full_signal(:, 1); 

idx_inicio = round(max(0, t_evento_inicio) * fs) + 1;
idx_fin    = round(min((length(full_signal)-1)/fs, t_evento_fin) * fs);
sig_test = full_signal(idx_inicio : idx_fin);

tamano_paquete = 256; 
tamano_ventana = 512; 
num_paquetes = floor(length(sig_test) / tamano_paquete);
sig_test = sig_test(1 : num_paquetes * tamano_paquete);
sig_tx = int16(sig_test * 16000); 

%% 3. Transmision y Recepcion
j_tot = 18;
bytes_esperados = j_tot * tamano_ventana * 4; 
matriz_stm32_full = zeros(j_tot, length(sig_test)); 
magic_word = uint8([255 170 255 170]); %Header del paquete

for i = 1:num_paquetes
    inicio_idx = (i-1)*tamano_paquete + 1;
    fin_idx = i*tamano_paquete;
    
    write(s, sig_tx(inicio_idx:fin_idx), "int16"); %Enviar ventana de 256

    header = read(s, 4, "uint8");
    if isempty(header) || ~isequal(header, magic_word) %revisa header
        error(['Header no encontrado en envío: ', num2str(i)]);
    end
    
    datos_raw = read(s, bytes_esperados, "uint8");
    if length(datos_raw) < bytes_esperados
        error(['Datos incompletos en el paquete ', num2str(i)]);
    end

    datos_raw = uint8(datos_raw); 

    datos_float = typecast(datos_raw, 'single'); %construcción Matriz
    matriz_frame = reshape(datos_float, tamano_ventana, [])';
    
    if size(matriz_frame, 1) ~= j_tot
        warning('Escala incorrecta');
    end

    matriz_stm32_full(:, inicio_idx:fin_idx) = matriz_frame(:, (tamano_paquete + 1):end);
    
    fprintf('Paquete %d / %d procesado.\n', i, num_paquetes);
end
disp('Procesamiento finalizado.');

%% 4. Visualizacion y Comparacion
figure('Name','Comparacion STM32 vs MATLAB','Position',[100 50 800 1000])

% Senal en el tiempo
subplot(4,1,1);
t_signal = (0:length(sig_test)-1) / fs; 
plot(t_signal, sig_test, 'k'); 
title('Senal de Prueba en el Dominio del Tiempo');
xlabel('Tiempo (s)');
ylabel('Amplitud');
grid on;
xlim([0 max(t_signal)]); 

% Senal de STM32
subplot(4,1,2);
matriz_stm32_dB = 10*log10(matriz_stm32_full + eps);

clim_max_stm = max(matriz_stm32_dB(:));
clim_min_stm = clim_max_stm - 65;
imagesc(t_signal, 1:j_tot, matriz_stm32_full);
set(gca, 'YDir', 'reverse'); 
colormap(jet);
title('CWT calculada en STM32');
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

%% Analisis de un Slice

t_eval = 0.89; 
idx_eval = round(t_eval * fs) + 1;

t_eval2 = 0.89; 
idx_eval2 = round(t_eval2 * fs) + 1;

figure('Name', sprintf('Corte Transversal CWT en t = %.3f s', t_eval), 'Position', [150 100 800 800])

subplot(3, 1, 1);
plot(t_signal, sig_test, 'k'); hold on;
xline(t_eval, 'r', 'LineWidth', 2, 'Label', sprintf('t = %.3f s', t_eval), 'LabelVerticalAlignment', 'bottom');
title('Senal de Prueba en el Dominio del Tiempo');
xlabel('Tiempo (s)');
ylabel('Amplitud');
grid on;
xlim([0 max(t_signal)]);

subplot(3, 1, 2);
slice_stm32 = matriz_stm32_full(:, idx_eval2);
escalas_stm32 = 1:j_tot;
plot(escalas_stm32, slice_stm32, '-o', 'LineWidth', 1.5, 'Color', '#D95319', 'MarkerFaceColor', '#D95319');
title(sprintf('Slice CWT STM32 en t = %.3f s', t_eval));
xlabel('Escalas'); 
ylabel('Magnitud');
grid on;
xlim([1 j_tot]);
set(gca, 'XDir', 'reverse'); 

subplot(3, 1, 3);
slice_matlab = abs(wt(:, idx_eval));
plot(f_cwt, slice_matlab, '-o', 'LineWidth', 1.5, 'Color', '#0072BD', 'MarkerFaceColor', '#0072BD');
title(sprintf('Slice CWT MATLAB en t = %.3f s', t_eval));
xlabel('Frecuencia (Hz)');
ylabel('Magnitud');
grid on;
set(gca, 'XScale', 'log'); 
xlim([175 max(f_cwt)]);