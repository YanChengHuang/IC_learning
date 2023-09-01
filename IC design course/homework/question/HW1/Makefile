VERILOG = iverilog
TARGET = MMS_tb.vcd

$(TARGET) : MMS_tb.vvp
	vvp MMS_tb.vvp

MMS_tb.vvp: MMS_tb.v MMS_8num.v MMS_4num.v MMS_2num.v
	$(VERILOG) -o MMS_tb.vvp MMS_tb.v MMS_8num.v MMS_4num.v MMS_2num.v

clean:
	rm $(TARGET)