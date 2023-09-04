VERILOG = iverilog
TARGET = tb.vcd

$(TARGET) : tb.vvp
	vvp tb.vvp

tb.vvp: tb.v rails_state.v
	$(VERILOG) -o tb.vvp tb.v rails_state.v

clean:
	rm $(TARGET)
