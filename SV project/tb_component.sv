`define SV_RAND_CHECK(r) \
	do begin\
      if(!(r)) begin\
        $display("%s: %0d  Randomization failed\"%s\"", \
        `__FILE__, `__LINE__, `"r`");\
        $finish;\
      end\
    end while(0)


package tb_component;
	typedef virtual LCD_if.TEST LCDifTest;
	typedef class Driver_cb;
	typedef class Monitor_cb;
	typedef bit [7:0] img_data;
	typedef img_data Img [0:63];

	import "DPI-C" function Img LCD_CTRL_CPP(input Img generated_img, input bit [3:0] cmd[]);


	virtual class BaseTr;
		static int count;
		int id;
		
		function new();
		id = count++;
		endfunction: new
		
		pure virtual function BaseTr copy(input BaseTr to=null);
		pure virtual function void display(input string prefix="");
	endclass: BaseTr
      
 	class Transaction extends BaseTr;
		rand Img image; // 8 bits 8*8 image with no constraint
		rand bit [3:0] cmd []; // cmd array
		
		constraint c_cmd{
          cmd.size() inside {[0:62]}; // The size of the cmd array should be larger than 0 and its size should not exceed 63.
			foreach(cmd[i])
              	cmd[i] inside {[1:11]}; // Element in the cmd array should inside[1:11] 
		}
		
		function void post_randomize;
          cmd = new[cmd.size()+1](cmd); // The last element of cmd array should be 0 (write)
		endfunction

		function new();
			super.new();
		endfunction: new
		
		virtual function BaseTr copy(input BaseTr to=null);
			Transaction cp;
			if(to==null) cp = new();
			else $cast(cp, to);
			cp.image = this.image;
			cp.cmd = this.cmd;
			return cp;
		endfunction: copy

		virtual function void display(input string prefix="");
			$display("%s Transaction %0d:", prefix, id);
         	$display("image: ");
			for(int i=0;i<8;i++) begin
        		for(int j=0;j<8;j++) $write("%3d ", image[i*8+j]);
					$display();
			end	
			$display("sub cmd in cmd array ");
          foreach(cmd[i]) $write("%2h ", cmd[i]);
          $display("\n size of cmd array %0d", cmd.size());
		endfunction: display
    endclass: Transaction

	class Generator;
		Transaction blueprint;
		mailbox gen2drv;
		event drv2gen;
		int nImages; // How many images for this generator to create
		
		function new(input mailbox gen2drv, 
					 input event drv2gen,
					 input int nImages);
			this.gen2drv = gen2drv;
			this.drv2gen = drv2gen;
			this.nImages = nImages;
			this.blueprint = new();
		endfunction: new

		task run();
			Transaction cp;
			repeat(nImages) begin
				`SV_RAND_CHECK(blueprint.randomize());
				$cast(cp, blueprint.copy());
				cp.display($sformatf("time: %t ",$time));
				gen2drv.put(cp);
				@drv2gen; // Wait for driver to with finish it
			end
		endtask: run
	endclass: Generator
	
	class Driver;
		mailbox gen2drv;
		event drv2gen;
		LCDifTest LCDif;
		bit [5:0] cmd_length;
		Driver_cb cb;

		function new(input mailbox gen2drv,
							input event drv2gen,
							input LCDifTest LCDif);
			this.gen2drv = gen2drv;
			this.drv2gen = drv2gen;
			this.LCDif = LCDif;
		endfunction: new

		// Get transaction from generator and keep interating with DUT
		task run();
			Transaction tr;
			//Initialize the ports
			LCDif.cb.cmd_valid <= 0;
			fork
				forever begin: DUT_interation
					gen2drv.peek(tr);
					@(LCDif.cb);
					send_image(tr);
					send_cmd(tr);
				end
				forever begin: done
					@(posedge LCDif.cb.done);
					cb.post_transmit(this, tr.image, tr.cmd);
					gen2drv.get(tr);
					cmd_length = 0;
					->drv2gen;
				end
			join
			
		endtask: run

		// Store generator generate image and send to DUT if it is needed
		task send_image(input Transaction tr);
			if(LCDif.cb.IROM_rd) LCDif.cb.IROM_Q <= tr.image[LCDif.cb.IROM_A];
		endtask: send_image

		task send_cmd(input Transaction tr);
			if(cmd_length < tr.cmd.size()) begin
				if(!LCDif.cb.busy && !LCDif.cb.done) begin
					LCDif.cb.cmd <= tr.cmd[cmd_length];
					LCDif.cb.cmd_valid <= 1;
					cmd_length++;
				end
				else LCDif.cb.cmd_valid <= 0;
			end
			else LCDif.cb.cmd_valid <= 0;
		endtask: send_cmd
	endclass: Driver

	class Monitor;
		LCDifTest LCDif;
		Img img;
		Monitor_cb cb;

		function new(LCDifTest LCDif);
			this.LCDif = LCDif;
		endfunction: new
		
		task run();
			fork
				begin
					forever begin
					recieve();
					end			
				end
				forever begin
					@(posedge LCDif.cb.done);
					cb.post_recieve(this, this.img);
				end
			join
			
		endtask: run
		
		task recieve();
				@(LCDif.cb);
				if(LCDif.cb.IRAM_valid) begin 
					img[LCDif.cb.IRAM_A] <= LCDif.cb.IRAM_D;
				end
		endtask: recieve
	endclass: Monitor

	class Scoreboard;
		int nErrors, nExpects;
		Img expected_img;
		bit same;
		bit diff_map[0:63];
		Img recieved_img;
		function new();
			same = 1;
		endfunction: new

		function void save_expected(input Img generated_img, input bit [3:0] cmd[]);
			// here to use referenced model implement by C++
			LCD_CTRL_CPP(generated_img, cmd);
			expected_img = generated_img;
			nExpects++;
		endfunction: save_expected

		function void check_actual(input Img DUT_img);
			recieved_img = DUT_img;
			foreach(DUT_img[i]) begin
				same &= (DUT_img[i] == expected_img[i]);
				diff_map[i] = !((DUT_img[i] == expected_img[i]));
			end
			if(!same) nErrors++;
		endfunction: check_actual

		function void display();
			if(same) $display("pass");
			else begin
				$display("Different pixel:");
				$write("position: ");
				foreach(diff_map[i]) begin
					if(diff_map[i]) $write("(%0d, %0d) ", i>>3,i[2:0]);
				end
				$display();
				$display("Transaction result %0d (Expected/ Recieved):", nExpects);
				$display("image: ");
				for(int i=0;i<8;i++) begin
					for(int j=0;j<8;j++) $write("(%3d / %3d) ", expected_img[i*8+j], recieved_img[i*8+j]);
						$display();
			end	
			end
		endfunction
	endclass: Scoreboard;

	class Driver_cb;
		virtual task pre_transmit(input Driver drv, input Img img, input bit[3:0] cmd[]);
		endtask: pre_transmit
		
		virtual task post_transmit(input Driver drv, input Img img, input bit[3:0] cmd[]);
		endtask: post_transmit
	endclass: Driver_cb

	class Monitor_cb;		
		virtual task post_recieve(input Monitor mon, input Img img);
		endtask: post_recieve
	endclass: Monitor_cb;

	class Scb_Driver_cb extends Driver_cb;
		Scoreboard scb;
		
		function new(input Scoreboard scb);
			this.scb = scb;
		endfunction: new

		virtual task post_transmit(input Driver drv, input Img img, input bit[3:0] cmd[]);
			scb.save_expected(img, cmd);
		endtask: post_transmit
	endclass: Scb_Driver_cb

	class Scb_Monitor_cb extends Monitor_cb;
		Scoreboard scb;
		
		function new(input Scoreboard scb);
			this.scb = scb;
		endfunction: new

		virtual task post_recieve(input Monitor mon, input Img img);
			scb.check_actual(img);
			scb.display();
		endtask: post_recieve
	endclass

	class Environment;
		Generator gen;
		mailbox gen2drv;
		event drv2gen;
		Driver drv;
		Monitor mon;
		Scoreboard scb;
		LCDifTest LCDif;
		int nImages;
      	Scb_Driver_cb sdc;
      	Scb_Monitor_cb smc;

		function new(input LCDifTest LCDif, input int nImages);
			this.LCDif = LCDif;
			this.nImages = nImages;

			if($test$plusargs("ntb_random_seed")) begin
				int seed;
				$value$plusargs("ntb_random_seed=%d", seed);
				$display("Simulation run with random seed = %0d", seed);
			end
			else  $display("Simulation run with default random seed");
		endfunction: new

		virtual function void build();
			gen2drv = new(1);
			gen = new(gen2drv, drv2gen, nImages);
			drv = new(gen2drv, drv2gen, LCDif);
			mon = new(LCDif);
			scb = new();

            sdc = new(scb);
			smc = new(scb);

			drv.cb = sdc;
			mon.cb = smc;
		endfunction: build

		virtual task run();
			fork
				gen.run();
				drv.run();
				mon.run();
        	join_none

			fork: timeout_block
				wait (scb.nExpects == nImages);
				begin: exceeded_time
					repeat(1_000_000) @LCDif.cb;
					$display("@%0t: %m ERROR: Generator timeout", $time);
				end
			join_any

			disable timeout_block;
		endtask: run

		virtual function void wrap_up();
			$display("Simulation end");
		endfunction: wrap_up
	endclass: Environment
	
endpackage