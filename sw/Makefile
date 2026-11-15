# sw/Makefile - assemble test programs into Verilog $readmemh files
PREFIX  ?= riscv64-unknown-elf-
AS      := $(PREFIX)as
LD      := $(PREFIX)ld
OBJCOPY := $(PREFIX)objcopy
OBJDUMP := $(PREFIX)objdump

BUILD := build
SRCS  := $(wildcard *.S)
HEXS  := $(patsubst %.S,$(BUILD)/%.hex,$(SRCS))

all: $(HEXS)

$(BUILD)/%.o: %.S test_macros.h | $(BUILD)
	$(AS) -march=rv32i -mabi=ilp32 -I . -o $@ $<

$(BUILD)/%.elf: $(BUILD)/%.o
	$(LD) -m elf32lriscv -Ttext=0x0 -e _start -o $@ $<

# one 32-bit word per line, little-endian host assumed (x86 / WSL)
$(BUILD)/%.hex: $(BUILD)/%.elf
	$(OBJCOPY) -O binary -j .text $< $(BUILD)/$*.bin
	od -An -tx4 -w4 -v $(BUILD)/$*.bin | tr -d ' ' > $@
	$(OBJDUMP) -d -M no-aliases $< > $(BUILD)/$*.dis

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)

.PRECIOUS: $(BUILD)/%.elf $(BUILD)/%.o
.PHONY: all clean
