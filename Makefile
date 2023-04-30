BUILD:=./build
HD_IMG_NAME:= "hd.img"

all: ${BUILD}/system.bin
	$(shell rm -rf $(BUILD)/$(HD_IMG_NAME))
	bximage -q -hd=16 -func=create -sectsize=512 -imgmode=flat $(BUILD)/$(HD_IMG_NAME)
	dd if=kernel/boot/boot.o of=$(BUILD)/$(HD_IMG_NAME) bs=512 seek=0 count=1 conv=notrunc
	dd if=kernel/boot/setup.o of=$(BUILD)/$(HD_IMG_NAME) bs=512 seek=1 count=2 conv=notrunc
	dd if=${BUILD}/system.bin of=$(BUILD)/$(HD_IMG_NAME) bs=512 seek=3 count=60 conv=notrunc

${BUILD}/system.bin: ${BUILD}/kernel.bin
	objcopy -O binary ${BUILD}/kernel.bin ${BUILD}/system.bin
	nm ${BUILD}/kernel.bin | sort > ${BUILD}/system.map

${BUILD}/kernel.bin: ${BUILD}/boot/kernel_entry.o ${BUILD}/interrupt/init.o
	ld -m elf_i386 $^ kernel/asm/io.o kernel/chr_drv/console.o kernel/chr_drv/keyboard.o kernel/lib/string.o kernel/vsprintf.o kernel/printk.o -o $@ -Ttext 0x1200

${BUILD}/interrupt/%.o: yaos/interrupt/%.asm
	$(shell mkdir -p ${BUILD}/interrupt)
	nasm -f elf32 -g $< -o $@

${BUILD}/boot/kernel_entry.o: yaos/boot/kernel_entry.asm
	$(shell mkdir -p ${BUILD}/boot)
	nasm -f elf32 -g $< -o $@

${BUILD}/boot/%.o: yaos/boot/%.asm
	$(shell mkdir -p ${BUILD}/boot)
	nasm $< -o $@

clean:
	$(shell rm -rf ${BUILD})

bochs: all
	bochs -q -f bochsrc

qemu: all
	qemu-system-x86_64 \
	-m 32M \
	-hda ./build/hd.img
