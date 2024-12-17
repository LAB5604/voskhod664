PROJ_NAME=firmware
DEBUG=no
BENCH=no
MULDIV=yes

SRCS = 	$(wildcard src/*.c) \
		$(wildcard src/*.cpp)  \
		$(wildcard src/*.S) \
		$(wildcard ../BSP/StdPeriphLib/src/*.S) \
		$(wildcard ../BSP/StdPeriphLib/src/*.c)

OBJDIR = build

INC  = -I ../BSP/StdPeriphLib/include/ \
	   -I /opt/riscv-embed-multilib/riscv64-unknown-elf/include/c++/8.2.0 \
	   -I /opt/riscv-embed-multilib/riscv64-unknown-elf/include/newlib-nano \
	   -I /opt/riscv-embed-multilib/lib/gcc/riscv64-unknown-elf/8.2.0 \
	   -I /opt/riscv-embed-multilib/lib/gcc/riscv64-unknown-elf/8.2.0/rv32i/ilp32/ \
	   -I /opt/riscv-embed-multilib/lib/gcc/riscv64-unknown-elf/8.2.0/plugin/include/ \
	   -I /opt/riscv-embed-multilib/lib/gcc/riscv64-unknown-elf/8.2.0/plugin/ \
	   -I ./inc \
	   -I ../BSP/Debug/include 
	   #-I /opt/riscv-embed-multilib/lib/gcc/riscv64-unknown-elf/8.2.0/include 
LIBS =
LIBSINC = -L$(OBJDIR)
LDSCRIPT = ../BSP/Core/linker_app.ld

#include ../../../resources/gcc.mk
RISCV_NAME ?= riscv64-unknown-elf
RISCV_PATH ?= /opt/riscv-embed-multilib/

MABI=ilp32
MARCH := rv32i
ifeq ($(MULDIV),yes)
	MARCH := $(MARCH)m
endif
ifeq ($(COMPRESSED),yes)
	MARCH := $(MARCH)ac
endif

CFLAGS += -march=$(MARCH)  -mabi=$(MABI) -DNDEBUG
LDFLAGS += -march=$(MARCH)  -mabi=$(MABI)


ifeq ($(DEBUG),yes)
	CFLAGS += -g3 -O2
endif
#-g 
ifeq ($(DEBUG),no)
	CFLAGS += -O2
	CFLAGS += -ffunction-sections -fdata-sections
	LDFLAGS += -Wl,-gc-sections
endif

ifeq ($(BENCH),yes)
	CFLAGS += -fno-inline
endif

ifeq ($(SIFIVE_GCC_PACK),yes)
	RISCV_CLIB=$(RISCV_PATH)/$(RISCV_NAME)/lib/$(MARCH)/$(MABI)/
else
	RISCV_CLIB=$(RISCV_PATH)/$(RISCV_NAME)/lib/
endif





RISCV_OBJCOPY = $(RISCV_PATH)/bin/$(RISCV_NAME)-objcopy
RISCV_OBJDUMP = $(RISCV_PATH)/bin/$(RISCV_NAME)-objdump
RISCV_CC=$(RISCV_PATH)/bin/$(RISCV_NAME)-gcc


CFLAGS +=  -MD  -Wall#-fstrict-volatile-bitfields -fno-strict-aliasing
LDFLAGS += -lgcc -lm -mcmodel=medany -nostartfiles -ffreestanding -nostdlib -Wl,-Bstatic,-T,$(LDSCRIPT),-Map,$(OBJDIR)/$(PROJ_NAME).map,--print-memory-usage # $(INC)
#LDFLAGS += -lgcc -lc -lg  -lgcc  -msave-restore    --strip-debug, -msoft-float 

OBJS := $(SRCS)
OBJS := $(OBJS:.c=.o)
OBJS := $(OBJS:.cpp=.o)
OBJS := $(OBJS:.S=.o)
OBJS := $(OBJS:..=miaou)
OBJS := $(addprefix $(OBJDIR)/,$(OBJS))


all: $(OBJDIR)/$(PROJ_NAME).elf $(OBJDIR)/$(PROJ_NAME).hex $(OBJDIR)/$(PROJ_NAME).asm $(OBJDIR)/$(PROJ_NAME).v $(OBJDIR)/$(PROJ_NAME).bin

$(OBJDIR)/%.elf: $(OBJS) | $(OBJDIR)
	$(RISCV_CC) $(CFLAGS) -o $@ $^ $(LDFLAGS) $(LIBSINC) $(LIBS)

%.hex: %.elf
	$(RISCV_OBJCOPY) -O ihex $^ $@

%.bin: %.elf
	$(RISCV_OBJCOPY) -O binary $^ $@

%.v: %.elf
	$(RISCV_OBJCOPY) -O verilog $^ $@

%.asm: %.elf
	$(RISCV_OBJDUMP) -S -d $^ > $@

$(OBJDIR)/%.o: %.c
	mkdir -p $(dir $@)
	$(RISCV_CC) -c $(CFLAGS)  $(INC) -o $@ $^
	$(RISCV_CC) -S $(CFLAGS)  $(INC) -o $@.disasm $^

$(OBJDIR)/%.o: %.cpp
	mkdir -p $(dir $@)
	$(RISCV_CC) -c $(CFLAGS)  $(INC) -o $@ $^

$(OBJDIR)/%.o: %.S
	mkdir -p $(dir $@)
	$(RISCV_CC) -c $(CFLAGS) -o $@ $^ -D__ASSEMBLY__=1

$(OBJDIR):
	mkdir -p $@

.PHONY: clean
clean:
	rm -rf $(OBJDIR)/src
	rm -f $(OBJDIR)/$(PROJ_NAME).elf
	rm -f $(OBJDIR)/$(PROJ_NAME).hex
	rm -f $(OBJDIR)/$(PROJ_NAME).map
	rm -f $(OBJDIR)/$(PROJ_NAME).v
	rm -f $(OBJDIR)/$(PROJ_NAME).asm
	find $(OBJDIR) -type f -name '*.o' -print0 | xargs -0 -r rm
	find $(OBJDIR) -type f -name '*.d' -print0 | xargs -0 -r rm

clean-all : clean 

.SECONDARY: $(OBJS)
