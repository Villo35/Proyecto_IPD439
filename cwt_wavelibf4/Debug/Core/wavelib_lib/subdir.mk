################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (11.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../Core/wavelib_lib/conv.c \
../Core/wavelib_lib/cwtmath.c \
../Core/wavelib_lib/hsfft.c \
../Core/wavelib_lib/real.c \
../Core/wavelib_lib/wavefilt.c \
../Core/wavelib_lib/wavefunc.c \
../Core/wavelib_lib/wavelib.c \
../Core/wavelib_lib/wtmath.c 

OBJS += \
./Core/wavelib_lib/conv.o \
./Core/wavelib_lib/cwtmath.o \
./Core/wavelib_lib/hsfft.o \
./Core/wavelib_lib/real.o \
./Core/wavelib_lib/wavefilt.o \
./Core/wavelib_lib/wavefunc.o \
./Core/wavelib_lib/wavelib.o \
./Core/wavelib_lib/wtmath.o 

C_DEPS += \
./Core/wavelib_lib/conv.d \
./Core/wavelib_lib/cwtmath.d \
./Core/wavelib_lib/hsfft.d \
./Core/wavelib_lib/real.d \
./Core/wavelib_lib/wavefilt.d \
./Core/wavelib_lib/wavefunc.d \
./Core/wavelib_lib/wavelib.d \
./Core/wavelib_lib/wtmath.d 


# Each subdirectory must supply rules for building sources it contributes
Core/wavelib_lib/%.o Core/wavelib_lib/%.su Core/wavelib_lib/%.cyclo: ../Core/wavelib_lib/%.c Core/wavelib_lib/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m4 -std=gnu11 -g3 -DDEBUG -DARM_MATH_CM4 -D__FPU_PRESENT=1 -DUSE_HAL_DRIVER -DSTM32F439xx -c -I../Core/Inc -I../Drivers/STM32F4xx_HAL_Driver/Inc -I../Drivers/STM32F4xx_HAL_Driver/Inc/Legacy -I../Drivers/CMSIS/Device/ST/STM32F4xx/Include -I../Drivers/CMSIS/Include -I"D:/Coso/U/IPD439/Proyecto/cwt_wavelibf4/Core/wavelib_lib" -I"D:/Coso/U/IPD439/Proyecto/cwt_wavelibf4/Core/dsplib" -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv4-sp-d16 -mfloat-abi=hard -mthumb -o "$@"

clean: clean-Core-2f-wavelib_lib

clean-Core-2f-wavelib_lib:
	-$(RM) ./Core/wavelib_lib/conv.cyclo ./Core/wavelib_lib/conv.d ./Core/wavelib_lib/conv.o ./Core/wavelib_lib/conv.su ./Core/wavelib_lib/cwtmath.cyclo ./Core/wavelib_lib/cwtmath.d ./Core/wavelib_lib/cwtmath.o ./Core/wavelib_lib/cwtmath.su ./Core/wavelib_lib/hsfft.cyclo ./Core/wavelib_lib/hsfft.d ./Core/wavelib_lib/hsfft.o ./Core/wavelib_lib/hsfft.su ./Core/wavelib_lib/real.cyclo ./Core/wavelib_lib/real.d ./Core/wavelib_lib/real.o ./Core/wavelib_lib/real.su ./Core/wavelib_lib/wavefilt.cyclo ./Core/wavelib_lib/wavefilt.d ./Core/wavelib_lib/wavefilt.o ./Core/wavelib_lib/wavefilt.su ./Core/wavelib_lib/wavefunc.cyclo ./Core/wavelib_lib/wavefunc.d ./Core/wavelib_lib/wavefunc.o ./Core/wavelib_lib/wavefunc.su ./Core/wavelib_lib/wavelib.cyclo ./Core/wavelib_lib/wavelib.d ./Core/wavelib_lib/wavelib.o ./Core/wavelib_lib/wavelib.su ./Core/wavelib_lib/wtmath.cyclo ./Core/wavelib_lib/wtmath.d ./Core/wavelib_lib/wtmath.o ./Core/wavelib_lib/wtmath.su

.PHONY: clean-Core-2f-wavelib_lib

