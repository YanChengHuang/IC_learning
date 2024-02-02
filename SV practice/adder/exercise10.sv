`define SV_RAND_CHECK(r) \
	do begin\
      if(!(r)) begin\
        $display("%s: %0d  Randomization failed\"%s\"", \
        `__FILE__, `__LINE__, `"r`");\
        $finish;\
      end\
    end while(0)

parameter int TESTS = 5;
parameter TIME_OUT=1000ns;


package tb_oponent;
    virtual class BaseTr;
        static int count;
        int id;

        function new();
            id = count++;
        endfunction

        pure virtual function bit compare(input BaseTr to);
        pure virtual function BaseTr copy(input BaseTr to=null);
        pure virtual function void display(input string prefix="");
    endclass: BaseTr

    class Transaction extends BaseTr;
        rand bit[31:0] src, dst, csm, data[8];

        extern function new();
        extern virtual function bit compare(input BaseTr to);
        extern virtual function BaseTr copy(input BaseTr to=null);
        extern virtual function void display(input string prefix="");
    endclass

    function Transaction::new();
        super.new();
    endfunction: new

    function bit Transaction::compare(input BaseTr to);
        Transaction tr;
        if(!$cast(tr, to))
            $finish;
        return ((this.src == tr.src) &&
                (this.dst == tr.dst) &&
                (this.csm == tr.csm) &&
                (this.data == tr.data));
    endfunction: compare

    function BaseTr Transaction::copy(input BaseTr to=null);
        Transaction cp;
        if(to == null) cp = new();
        else $cast(cp, to);
        cp.src = this.src; 
        cp.dst = this.dst; 
        cp.csm = this.csm;
        cp.data = this.data;
        return cp;
    endfunction: copy

    function void Transaction::display(input string prefix="");
        $display("%sTransaction %0d src=%h, dst=%x, csm=%x",
                 prefix, id, src, dst, csm);
    endfunction: display

    
    class Generator #(type T=BaseTr);
        T blueprint;
        mailbox #(Transaction) gen2drv;

        function new(input mailbox #(Transaction) gen2drv);
            this.gen2drv = gen2drv;
            blueprint = new();
        endfunction

        virtual task run(input int num_tr=10);
            T tr;
            repeat (num_tr) begin
                `SV_RAND_CHECK(blueprint.randomize());
                $cast(tr, blueprint.copy());
                gen2drv.put(tr); // send copy to the driver
            end
        endtask: run
    endclass: Generator

    class Driver;
        Transaction tr;
        mailbox #(Transaction) mbx, rtn;
        
        function new(input mailbox #(Transaction) mbx, rtn);
            this.mbx = mbx;
            this.rtn = rtn;
        endfunction //new()

        task run(input int count);
            repeat (count) begin
                mbx.get(tr);
                // process something...
                rtn.put(tr);
               
            end
        endtask //

    endclass //Driver
endpackage


          
module tb();
import tb_oponent::*;


initial begin
    Generator #(Transaction) gen;
    mailbox #(Transaction) gen2drv;
    gen2drv = new(1);
    gen = new(gen2drv);

    fork
        gen.run();

        repeat(5) begin
            Transaction tr;
            gen2drv.peek(tr);
            tr.display();
            gen2drv.get(tr);
        end
    join_any
end

final begin
  $display("This is the end of the test");
end

endmodule: tb