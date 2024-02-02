package tb_oponent;
    typedef class Statistics;
    class Transaction;
        logic [31:0] addr, csm, data[8];
        int id;
        static int obj_count = 0;
        Statistics stats;
        
        function new(logic [31:0] a = 32'hffff_ffff);
            addr = a;
            id = ++obj_count;
            stats = new();
        endfunction

        function void display();
            $display("addr = %h, count = %d, id = %d", addr, obj_count, id);
        endfunction: display

        function void changeAddr();
           addr = 32'h1234_1234;
        endfunction: changeAddr

        function Transaction copy();
            copy = new();
            copy.addr = addr;
            copy.csm = csm;
            copy.data = data;
            copy.stats = stats.copy();
        endfunction
    endclass: Transaction

    class Statistics;
        time startT;
        static int ntrans = 0;
        static time total_time = 0;

        function void start();
            startT = $time;
        endfunction;

        function void stop();
            total_time = $time - startT;
            ntrans++;
        endfunction;

        function void display();
            $display("ntrans=%d, startT=%t", ntrans, startT);
        endfunction

        function Statistics copy();
            copy = new();
            copy.startT = startT;
            copy.total_time = total_time;
        endfunction
    endclass: Statistics

    class rdc5;
       randc [4:0] val;
    endclass //rdc8

    class RandomTest;
    bit [4:0] len[20];
  

    function void pre_randomizer();
    rdc8 data;
    data = new();
    foreach(len[i])
        len[i] = data.val;
    endfunction
    constraint c {
    };
    
        
    function void display();
        $write("sum=%4d, val=", len.sum());
        foreach(len[i]) $write("%4d, ", len[i]);
        $display;
    endfunction
    endclass: RandomTest

    class Excercise1;
        rand bit [7:0] data;
        rand bit [3:0] addr;
        constraint c {
            data inside {[3:4]};
        }
        function void display();
            $display("data: %d, addr: %d", data, addr);
        $display;
    endfunction
    endclass //Excercise1
    class StimData;
    rand int array[];
    constraint c{
        array.size() inside {[1:1000]};
    }
    endclass
endpackage


