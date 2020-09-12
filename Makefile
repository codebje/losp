SRC_DIR:=src
BIN_DIR:=bin
SRC_FILES:=$(wildcard $(SRC_DIR)/*.asm)
DEP_FILES=$(patsubst $(SRC_DIR)/%.asm,$(BIN_DIR)/%.d,$(SRC_FILES))

TARGET=losp

all: $(BIN_DIR)/$(TARGET).com $(DEP_FILES)

$(BIN_DIR): ; @mkdir -p $@

$(BIN_DIR)/$(TARGET).com: $(SRC_DIR)/$(TARGET).asm | $(BIN_DIR)
	zasm -uwy --z180 $< -l $(BIN_DIR)/$(TARGET).lst -o $@

# this is a terrible hack - file names must be really super clean and everything must match perfectly
$(BIN_DIR)/%.d: $(SRC_DIR)/%.asm | $(BIN_DIR)
	@printf "$(BIN_DIR)/$*.com $(BIN_DIR)/$*.d : $^ " > $@
	@sed -Ene 's/^#include[[:space:]]*"(.*)"$$/$(SRC_DIR)\/\1/p' $^ | tr '\n' ' ' >> $@
	@echo >> $@

clean:
	rm -f $(BIN_DIR)/losp.{lst,com} $(BIN_DIR)/*.d

-include $(wildcard $(DEP_FILES))
