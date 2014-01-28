##############################################################################
#Makefile for the project test0.
#You can use in another project by modifying $(TARGET)
##############################################################################
#Makefile , written by Li Jun
#mail: lijun4running@gmail.com
##############################################################################

# General setting

MCU           = atmega32u4 
CC            = avr-gcc
OBJCOPY       = avr-objcopy

# Project setting
TARGET        = test0
FLAGS         = -mmcu=$(MCU)


# AVRDUDE setting
AVRDUDE_PROGRAMMER  = jtag1
AVRDUDE_PORT        = /dev/ttyUSB0
AVRDUDE_TARGET      = $(MCU)
# make all command
all:$(TARGET).hex

$(TARGET).hex:$(TARGET).elf
	$(OBJCOPY) -j .text -j .data -O ihex $(TARGET).elf $(TARGET).hex

$(TARGET).elf:$(TARGET).o
	$(CC) $(FLAGS) -o $(TARGET).elf $(TARGET).o

$(TARGET).o:$(TARGET).c
	$(CC) $(FLAGS) -c $(TARGET).c

# make load command
load:$(TARGET).hex
	sudo avrdude -p $(AVRDUDE_TARGET) -c $(AVRDUDE_PROGRAMMER) -P $(AVRDUDE_PORT) -e -U
flash:w:$(TARGET).hex


# make erase command
erase:
	sudo avrdude -p $(AVRDUDE_TARGET) -c $(AVRDUDE_PROGRAMMER) -P $(AVRDUDE_PORT) -e
.POHNY: clean
clean:
	rm -f *.o *.elf *.hex *.map *.out

