package tb_oponent;
    class Binary;
        rand bit[3:0] val1, val2;

        function new(input bit[3:0] val1,val2);
            this.val1 = val1;
            this.val2 = val2;
        endfunction: new

        virtual function void print_int(input int val);
            $display("val=0d%0d", val);
        endfunction: print_int
    extern virtual function Binary copy();
    endclass: Binary
          
    function Binary Binary::copy();
    copy = new(15,8);
    copy.val1 = val1;
    copy.val2 = val2;
    endfunction

    class ExtBinary extends Binary;
        
        function new(input bit[3:0] val1,val2);
            super.new(val1, val2);
        endfunction: new

        function int mul();
            mul = val1*val2;
        endfunction: mul

        // function void print_int(input int val);
        //     $display("val=0d%0d", val);
        // endfunction: print_int
    endclass: ExtBinary

    class Exercise3 extends ExtBinary;
        
        function new(input bit[3:0] val1,val2);
            super.new(val1, val2);
        endfunction: new

        constraint c {
            val1 < 10;
            val2 < 10;
        }
    endclass //Exercise3 extends superClass
endpackage

module tb();
import tb_oponent::*;

initial begin
    Exercise3 excer1;
    excer1 = new(15,8);
    excer1.randomize();
    excer1.print_int(excer1.val1);
    excer1.print_int(excer1.val2);
    excer1.print_int(excer1.mul());

end

final begin
  $display("This is the end of the test");
end

endmodule: tb