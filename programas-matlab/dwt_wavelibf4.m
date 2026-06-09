clear; clc; close all;

%% 1. Configuracion del Puerto Serie
puerto = "COM4";
baudrate = 460800;
try
    s = serialport(puerto, baudrate);
    s.ByteOrder = "little-endian";
    s.Timeout = 15;
    flush(s);
catch
    error('No se pudo abrir el puerto UART');
end

%% 2. Senal de Prueba
fs = 16000;
t = (0:fs-1) / fs;
filename = 'rec_13.wav';
t_evento_inicio = 32;
t_evento_fin    = 33;

[full_signal, fs] = audioread(filename);

idx_inicio = round(t_evento_inicio * fs) + 1;
idx_fin    = min(round(t_evento_fin * fs), length(full_signal));

%sig_test = chirp(t, 50, 0.1, 6000); 
%señal chirp. cambiar comentario con otra señal sig_test
sig_test = full_signal(idx_inicio : idx_fin);

tamano_paquete = 256;
tamano_ventana = 512;
num_paquetes   = floor(length(sig_test) / tamano_paquete);
sig_test       = sig_test(1 : num_paquetes * tamano_paquete);
sig_tx         = int16(sig_test * 32767);

%% 3. Transmision y Recepcion
disp('Iniciando envio y recepcion');
dwt_outlength      = 0;
matriz_stm32_full  = [];
magic_word         = uint8([255 170 255 170]);

for i = 1:num_paquetes
    inicio_idx = (i-1)*tamano_paquete + 1;
    fin_idx    = i*tamano_paquete;
    write(s, sig_tx(inicio_idx:fin_idx), "int16");
    pause(0.03);  
    header = read(s, 6, "uint8");
    if isempty(header) || ~isequal(header(1:4), magic_word)
        error(['Error de header en paquete ', num2str(i)]);
    end
    largo_paquete = double(typecast(uint8(header(5:6)), 'uint16'));
    if i == 1
        dwt_outlength = largo_paquete;
        fprintf('outlength reportado por STM32: %d\n', dwt_outlength);
        matriz_stm32_full = zeros(dwt_outlength, num_paquetes);
    end
    datos_float = read(s, largo_paquete, "single");
    matriz_stm32_full(1:largo_paquete, i) = datos_float;
    fprintf('Paquete %d / %d procesado.\n', i, num_paquetes);
end
disp('Procesamiento finalizado.');
clear s;

%% 4. Visualizacion y Analisis
dt_frame  = tamano_paquete / fs;
t_signal  = (0 : length(sig_test)-1) / fs;
t_frames  = ((1:num_paquetes) - 0.5) * dt_frame;  % centro de cada frame
figure('Name','DWT STM32 vs MATLAB','Position',[100 50 900 1100])

% 4.1 Senal en el tiempo
subplot(4,1,1);
plot(t_signal, sig_test, 'k');
title('Señal de Prueba en el Dominio del Tiempo');
xlabel('Tiempo (s)'); ylabel('Amplitud');
grid on; xlim([0 max(t_signal)]);
subplot(4,1,2);
[wt, f_cwt] = cwt(sig_test, fs); 
imagesc(t_signal, f_cwt, abs(wt));
set(gca, 'YDir', 'normal', 'YScale', 'log'); 
ylim([100 7500]);
colormap(jet);
title('Transformada Wavelet Continua (CWT) Real - MATLAB');
xlabel('Tiempo (s)');
ylabel('Frecuencia (Hz)');
xlim([0 max(t_signal)]);

subplot(4,1,3);
matriz_matlab_full = zeros(dwt_outlength, num_paquetes);
buffer_ventana     = zeros(1, tamano_ventana);
for i = 1:num_paquetes %CALCULO DE DWT
    inicio_idx = (i-1)*tamano_paquete + 1;
    fin_idx    = i*tamano_paquete;
    nuevos_datos   = reshape(sig_test(inicio_idx:fin_idx), 1, tamano_paquete);
    buffer_pasado  = reshape(buffer_ventana(tamano_paquete+1:end), 1, tamano_ventana - tamano_paquete);
    buffer_ventana = [buffer_pasado, nuevos_datos];
    
    [C, L_ref] = wavedec(buffer_ventana, 6, 'db4');
    min_len = min(dwt_outlength, length(C));
    matriz_matlab_full(1:min_len, i) = C(1:min_len);
end

segmentos = [0, cumsum(L_ref)]; 
energia_matlab = zeros(7, num_paquetes);
for i = 1:num_paquetes
    for b = 1:7
        rango = segmentos(b)+1 : segmentos(b+1);
        energia_matlab(b, i) = sum(matriz_matlab_full(rango, i).^2);
    end
end
energia_matlab_dB = 10*log10(energia_matlab + eps);

% Etiquetas de frecuencia para el eje Y
frecuencias_bandas = {'0 - 125', '125 - 250', '250 - 500', '500 - 1k', '1k - 2k', '2k - 4k', '4k - 8k'};

imagesc(t_frames, 1:7, energia_matlab_dB);
set(gca, 'YDir', 'normal'); 
yticks(1:7);
yticklabels(frecuencias_bandas);
colormap(jet);
title('Escalograma DWT (MATLAB)');
xlabel('Tiempo (s)'); ylabel('Frecuencia (Hz)');
xlim([0 max(t_frames)]);


subplot(4,1,4);
energia_bandas = zeros(7, num_paquetes);
for i = 1:num_paquetes
    for b = 1:7
        rango = segmentos(b)+1 : segmentos(b+1);
        energia_bandas(b, i) = sum(matriz_stm32_full(rango, i).^2);
    end
end
energia_dB = 10*log10(energia_bandas + eps);
energia_norm = zeros(size(energia_dB));
for b = 1:7
    media_banda = mean(energia_dB(b, :));
    std_banda = std(energia_dB(b, :)) + eps;
    energia_norm(b, :) = (energia_dB(b, :) - media_banda) / std_banda;
end

imagesc(t_frames, 1:7, energia_norm);
set(gca, 'YDir', 'normal'); 
yticks(1:7);
yticklabels(frecuencias_bandas);
colormap(jet);
title('Implementación DWT en STM32');
xlabel('Tiempo (s)'); ylabel('Frecuencia (Hz)');
xlim([0 max(t_frames)]);

%% 5. Analisis de un Slice

t_eval = 0.89;
idx_eval_sig = round(t_eval * fs) + 1;

t_eval2 = 0.895; 
idx_eval_sig2 = round(t_eval2 * fs) + 1;

[~, idx_frame] = min(abs(t_frames - t_eval));
[~, idx_frame2] = min(abs(t_frames - t_eval2));

figure('Name', sprintf('Corte Transversal DWT en t = %.3f s', t_eval), 'Position', [150 100 800 800])

subplot(3, 1, 1);
plot(t_signal, sig_test, 'k'); hold on;
xline(t_eval, 'r', 'LineWidth', 2, 'Label', sprintf('t = %.3f s', t_eval), 'LabelVerticalAlignment', 'bottom');
title('Señal de Prueba en el Dominio del Tiempo');
xlabel('Tiempo (s)'); ylabel('Amplitud');
grid on; xlim([0 max(t_signal)]);

subplot(3, 1, 2);
slice_stm32 = energia_dB(:, idx_frame2);
plot(1:7, slice_stm32, '-o', 'LineWidth', 1.5, 'Color', '#D95319', 'MarkerFaceColor', '#D95319');
title(sprintf('Slice DWT STM32 (Energía en dB) en t = %.3f s', t_frames(idx_frame)));
xlabel('Banda Frecuencia'); ylabel('Energía');
grid on;
xticks(1:7); 
yticklabels_auto = get(gca, 'YTick');
xticklabels(frecuencias_bandas);
xlim([1 7]);

subplot(3, 1, 3);
slice_matlab = energia_matlab_dB(:, idx_frame);
plot(1:7, slice_matlab, '-o', 'LineWidth', 1.5, 'Color', '#0072BD', 'MarkerFaceColor', '#0072BD');
title(sprintf('Slice DWT MATLAB en t = %.3f s', t_frames(idx_frame)));
xlabel('Banda de Frecuencia'); ylabel('Energía');
grid on;
xticks(1:7); 
xticklabels(frecuencias_bandas);
xlim([1 7]);
ymin = min([slice_stm32; slice_matlab]) - 5;
ymax = max([slice_stm32; slice_matlab]) + 5;
subplot(3, 1, 2); ylim([ymin ymax]);
subplot(3, 1, 3); ylim([ymin ymax]);