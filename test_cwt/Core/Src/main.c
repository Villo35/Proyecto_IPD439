/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2026 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include "arm_math.h"
#include <string.h>
#include <stdbool.h>
#include <math.h>
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */
typedef struct {
    uint16_t binStart;
    uint16_t binEnd;
} band_def_t;
/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */
#define FS_HZ               16000 //frecuencia fija del dataset
#define TOTAL_SAMPLES       16000 //muestras totales (para 1 segundo)
#define FFT_LEN             256 //tamañno de la ventana a procesar
#define HOP_LEN             128 //tamaño del overlap
#define N_FRAMES            (((TOTAL_SAMPLES - FFT_LEN) / HOP_LEN) + 1)

#define UART_DMA_RX_BYTES   2
#define NBANDS              24 //numero de bandas a guardar
/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
UART_HandleTypeDef huart2;
DMA_HandleTypeDef hdma_usart2_rx;

/* USER CODE BEGIN PV */

static const band_def_t bands[NBANDS] = {
    { 1, 1 },     // Banda 1: ~31 Hz
    { 2, 2 },     // Banda 2: ~62 Hz
    { 3, 3 },     // Banda 3: ~93 Hz
    { 4, 4 },     // Banda 4: ~125 Hz
    { 5, 5 },     // Banda 5: ~156 Hz
    { 6, 7 },     // Banda 6: ~187-218 Hz
    { 8, 9 },     // Banda 7: ~250-281 Hz
    { 10, 11 },   // Banda 8: ~312-343 Hz
    { 12, 14 },   // Banda 9: ~375-437 Hz
    { 15, 17 },   // Banda 10: ~468-531 Hz
    { 18, 21 },   // Banda 11: ~562-656 Hz
    { 22, 25 },   // Banda 12: ~687-781 Hz
    { 26, 31 },   // Banda 13: ~812-968 Hz
    { 32, 38 },   // Banda 14: ~1000-1187 Hz
    { 39, 46 },   // Banda 15: ~1218-1437 Hz
    { 47, 56 },   // Banda 16: ~1468-1750 Hz
    { 57, 68 },   // Banda 17: ~1781-2125 Hz
    { 69, 82 },   // Banda 18: ~2156-2562 Hz
    { 83, 99 },   // Banda 19: ~2593-3093 Hz
    { 100, 119 }, // Banda 20: ~3125-3718 Hz
    { 120, 143 }, // Banda 21: ~3750-4468 Hz
    { 144, 171 }, // Banda 22: ~4500-5343 Hz
    { 172, 205 }, // Banda 23: ~5375-6406 Hz
    { 206, 240 }  // Banda 24: ~6437-7500 Hz
};
static int16_t pcm16_1s[TOTAL_SAMPLES]; //entrada por uart
static volatile uint32_t pcmWriteIndex = 0;
static volatile bool oneSecondReady = false; //flag para indicar operación lista

//Variables de fft:
static float32_t fftIn[FFT_LEN];
static float32_t fftOut[FFT_LEN];
static float32_t magOut[FFT_LEN / 2];
static float32_t hanningWindow[FFT_LEN]; //ventana hanning

static float32_t bandEnergy[NBANDS][N_FRAMES]; //matriz final que será enviada
static arm_rfft_fast_instance_f32 rfft_f32; //variable de cmsis-dsp
/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_DMA_Init(void);
static void MX_USART2_UART_Init(void);
/* USER CODE BEGIN PFP */
void AudioDSP_Init(void);
void AudioDSP_Task(void);
static void StartUartDmaReception(void);
static void Process1sPseudoCWT_F32(void);
static void SendBandMatrix(void);
static void InitHanningWindow(void);
/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */

/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{
  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* Configure the system clock */
  SystemClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_DMA_Init();
  MX_USART2_UART_Init();
  /* USER CODE BEGIN 2 */
  AudioDSP_Init();
  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
	  AudioDSP_Task();
  }
  /* USER CODE END 3 */
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /** Configure the main internal regulator output voltage
  */
  if (HAL_PWREx_ControlVoltageScaling(PWR_REGULATOR_VOLTAGE_SCALE1) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI;
  RCC_OscInitStruct.HSIState = RCC_HSI_ON;
  RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSI;
  RCC_OscInitStruct.PLL.PLLM = 1;
  RCC_OscInitStruct.PLL.PLLN = 10;
  RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV7;
  RCC_OscInitStruct.PLL.PLLQ = RCC_PLLQ_DIV2;
  RCC_OscInitStruct.PLL.PLLR = RCC_PLLR_DIV2;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV1;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_4) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief USART2 Initialization Function
  * @param None
  * @retval None
  */
static void MX_USART2_UART_Init(void)
{

  /* USER CODE BEGIN USART2_Init 0 */

  /* USER CODE END USART2_Init 0 */

  /* USER CODE BEGIN USART2_Init 1 */

  /* USER CODE END USART2_Init 1 */
  huart2.Instance = USART2;
  huart2.Init.BaudRate = 115200;
  huart2.Init.WordLength = UART_WORDLENGTH_8B;
  huart2.Init.StopBits = UART_STOPBITS_1;
  huart2.Init.Parity = UART_PARITY_NONE;
  huart2.Init.Mode = UART_MODE_TX_RX;
  huart2.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart2.Init.OverSampling = UART_OVERSAMPLING_16;
  huart2.Init.OneBitSampling = UART_ONE_BIT_SAMPLE_DISABLE;
  huart2.AdvancedInit.AdvFeatureInit = UART_ADVFEATURE_NO_INIT;
  if (HAL_UART_Init(&huart2) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN USART2_Init 2 */

  /* USER CODE END USART2_Init 2 */

}

/**
  * Enable DMA controller clock
  */
static void MX_DMA_Init(void)
{

  /* DMA controller clock enable */
  __HAL_RCC_DMA1_CLK_ENABLE();

  /* DMA interrupt init */
  /* DMA1_Channel6_IRQn interrupt configuration */
  HAL_NVIC_SetPriority(DMA1_Channel6_IRQn, 0, 0);
  HAL_NVIC_EnableIRQ(DMA1_Channel6_IRQn);

}

/**
  * @brief GPIO Initialization Function
  * @param None
  * @retval None
  */
static void MX_GPIO_Init(void)
{
  GPIO_InitTypeDef GPIO_InitStruct = {0};
/* USER CODE BEGIN MX_GPIO_Init_1 */
/* USER CODE END MX_GPIO_Init_1 */

  /* GPIO Ports Clock Enable */
  __HAL_RCC_GPIOC_CLK_ENABLE();
  __HAL_RCC_GPIOH_CLK_ENABLE();
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(LD2_GPIO_Port, LD2_Pin, GPIO_PIN_RESET);

  /*Configure GPIO pin : B1_Pin */
  GPIO_InitStruct.Pin = B1_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_IT_FALLING;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(B1_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : LD2_Pin */
  GPIO_InitStruct.Pin = LD2_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(LD2_GPIO_Port, &GPIO_InitStruct);

/* USER CODE BEGIN MX_GPIO_Init_2 */
/* USER CODE END MX_GPIO_Init_2 */
}

/* USER CODE BEGIN 4 */
void AudioDSP_Init(void)
{
    // Inicializar FFT en modo flotante rápido
    arm_rfft_fast_init_f32(&rfft_f32, FFT_LEN);
    memset((void*)pcm16_1s, 0, sizeof(pcm16_1s));
    memset((void*)bandEnergy, 0, sizeof(bandEnergy));

    InitHanningWindow();
    StartUartDmaReception();
}

static void InitHanningWindow(void) //ventana hanning
{
    for (uint16_t i = 0; i < FFT_LEN; i++)
    {
        hanningWindow[i] = 0.5f * (1.0f - cosf(2.0f * 3.14159265358979f * i / (FFT_LEN - 1)));
    }
}
static void StartUartDmaReception(void)
{
	HAL_UART_Receive_DMA(&huart2, (uint8_t*)pcm16_1s, TOTAL_SAMPLES * 2);
}
void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart)
{
    if (huart->Instance == USART2)
    {

        oneSecondReady = true; //está listo el segundo a procesar
    }
}

void AudioDSP_Task(void)
{
    if (oneSecondReady)
    {
        oneSecondReady = false;
        Process1sPseudoCWT_F32();
        SendBandMatrix();
       // pcmWriteIndex = 0;
        StartUartDmaReception();
    }
}

static void Process1sPseudoCWT_F32(void)
{
    uint32_t frameIdx = 0;
    memset((void*)bandEnergy, 0, sizeof(bandEnergy));

    for (uint32_t start = 0; start + FFT_LEN <= TOTAL_SAMPLES; start += HOP_LEN)
    {
        for (uint32_t n = 0; n < FFT_LEN; n++)
            fftIn[n] = (float32_t)pcm16_1s[start + n];

        arm_mult_f32(fftIn, hanningWindow, fftIn, FFT_LEN);
        arm_rfft_fast_f32(&rfft_f32, fftIn, fftOut, 0);

        magOut[0] = fabsf(fftOut[0]);  // DC
        for (uint32_t k = 1; k < FFT_LEN / 2; k++)
        {
            float32_t re = fftOut[2*k];
            float32_t im = fftOut[2*k + 1];
            magOut[k] = sqrtf(re*re + im*im);
        }

        for (uint32_t b = 0; b < NBANDS; b++)
        {
            float32_t acc = 0.0f;
            for (uint32_t k = bands[b].binStart; k <= bands[b].binEnd; k++)
                acc += magOut[k];
            bandEnergy[b][frameIdx] = acc;
        }

        frameIdx++;
        if (frameIdx >= N_FRAMES) break;
    }
}
static void SendBandMatrix(void)
{
    const uint8_t syncHeader[4] = {255, 170, 255, 170}; //header para debuggeo

    HAL_UART_Transmit(&huart2, (uint8_t*)syncHeader, sizeof(syncHeader), HAL_MAX_DELAY);
    HAL_UART_Transmit(&huart2, (uint8_t*)bandEnergy, sizeof(bandEnergy), HAL_MAX_DELAY);
}

void HAL_UART_ErrorCallback(UART_HandleTypeDef *huart)
{
    if (huart->Instance == USART2)
    {

        volatile uint32_t errorCode = huart->ErrorCode;
        __HAL_UART_CLEAR_OREFLAG(huart);
        StartUartDmaReception();
    }
}
/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}

#ifdef  USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
