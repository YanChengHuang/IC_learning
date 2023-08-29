VERILOG = iverilog
TARGET = simple.vcd

$(TARGET) : simple.vvp
	vvp simple.vvp

simple.vvp: simple_tb.v simple.v
	$(VERILOG) -o simple.vvp simple_tb.v simple.v

clean:
	rm $(TARGET)