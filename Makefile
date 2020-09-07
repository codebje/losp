SRC_DIR:=src
BIN_DIR:=bin
SRC_FILES:=$(wildcard $(SRC_DIR)/*.asm)

all: $(BIN_DIR)/losp.bin

$(BIN_DIR)/losp.bin: $(SRC_FILES)
	@mkdir -p $(BIN_DIR)
	zasm -uwy --z180 $(SRC_DIR)/losp.asm -l $(BIN_DIR)/losp.lst -o $(BIN_DIR)/losp.bin

clean:
	rm -f $(BIN_DIR)/losp.{lst,bin}
