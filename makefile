YSYX_DIR=../oscpu-framework
PROJECT_NAME=voskhod664
TEST_BINARY=addi-riscv64-mycpu.bin
RECUR_AXI_PARAM= -e $(PROJECT_NAME) -v '-Wno-TIMESCALEMOD' -b -r "non-output/cpu-tests non-output/riscv-tests" -m "WITH_DRAMSIM3=1" 
SIM_PARAM      = -e $(PROJECT_NAME) -d -b -s -a "-i $(TEST_BINARY).bin --dump-wave -b 0" -m "EMU_TRACE=1 WITH_DRAMSIM3=1" -w

help:
	

sim_elaborate:	#elaborate simulation source 
	@echo "source file elaborate begin."
	-rm -f $(YSYX_DIR)/projects/$(PROJECT_NAME)/vsrc/*
	-find ./src/core -name "*.v" -type f -exec cp {} $(YSYX_DIR)/projects/$(PROJECT_NAME)/vsrc \;
	-find ./src/core -name "*.sv" -type f -exec cp {} $(YSYX_DIR)/projects/$(PROJECT_NAME)/vsrc \;
	-find ./src/core -name "*.svh" -type f -exec cp {} $(YSYX_DIR)/projects/$(PROJECT_NAME)/vsrc \;

	-find ./src/misc -name "*.v" -type f -exec cp {} $(YSYX_DIR)/projects/$(PROJECT_NAME)/vsrc \;
	-find ./src/misc -name "*.sv" -type f -exec cp {} $(YSYX_DIR)/projects/$(PROJECT_NAME)/vsrc \;
	-find ./src/misc -name "*.svh" -type f -exec cp {} $(YSYX_DIR)/projects/$(PROJECT_NAME)/vsrc \;

	-find ./src/soc -name "*.v" -type f -exec cp {} $(YSYX_DIR)/projects/$(PROJECT_NAME)/vsrc \;
	-find ./src/soc -name "*.sv" -type f -exec cp {} $(YSYX_DIR)/projects/$(PROJECT_NAME)/vsrc \;
	-find ./src/soc -name "*.vh" -type f -exec cp {} $(YSYX_DIR)/projects/$(PROJECT_NAME)/vsrc \;
	-find ./src/soc -name "*.svh" -type f -exec cp {} $(YSYX_DIR)/projects/$(PROJECT_NAME)/vsrc \;

	-cp -f ./src/sim/ysyx_difftest/SimTop.v  $(YSYX_DIR)/projects/$(PROJECT_NAME)/vsrc
	-cp -f ./src/sim/ysyx_difftest/*.svh  $(YSYX_DIR)/projects/$(PROJECT_NAME)/vsrc
	@echo "source file elaborate finish."
soc_sim:	#simulation full soc

single_sim:
	$(MAKE) sim_elaborate
	-rm -rf $(YSYX_DIR)/projects/$(PROJECT_NAME)/build
	cp -f ./makefile_ysyxproj $(YSYX_DIR)/projects/$(PROJECT_NAME)/makefile
	cd $(YSYX_DIR) && bash ./build.sh $(SIM_PARAM)

recursive:	#CPU指令回环测试
	$(MAKE) sim_elaborate
	-rm -rf $(YSYX_DIR)/projects/$(PROJECT_NAME)/build
	cp -f ./makefile_ysyxproj $(YSYX_DIR)/projects/$(PROJECT_NAME)/makefile
	cd $(YSYX_DIR) && bash ./build.sh $(RECUR_AXI_PARAM)
