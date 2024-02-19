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
	typedef bit [`WORD_LENGTH-1:0] img_data;
    typedef img_data img_t [0:`PIXEL_NUM-1];
	typedef bit[`CMD_LENGTH-1:0] cmd_t;

    import "DPI-C" function void LCD_CTRL_C (input img_t generated_img, input cmd_t cmd[], output img_t expected_img);


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
		rand img_t image; // 8 bits 8*8 image with no constraint
		rand cmd_t cmd []; // cmd array
		
		constraint cmd_base_c{
          	cmd.size() inside {[0:62]}; // The size of the cmd array should be larger than 0 and its size should not exceed 63.
			foreach(cmd[i])
              	cmd[i] inside {[1:11]}; // Element in the cmd array should inside[1:11] 
		}

		int consecutive_num;
		rand bit[5:0] consecutive_head_idx;
		rand bit[3:0] shift_cmd; 
		// Create 7 shift command(cmd: 1~4) in a row, which guarantee DUT to trigger the image edge.
		constraint cmd_edge_trigger{
			cmd.size() >= (consecutive_num) + 1; 
			consecutive_head_idx <= cmd.size() - consecutive_num - 1;
			shift_cmd inside {[1:4]};
			foreach(cmd[i])
				if( i >= consecutive_head_idx)
					if(i < consecutive_head_idx + consecutive_num) cmd[i] == shift_cmd; // gererate consecutive vertical cmd
					else cmd[i] inside {[5:11]};
		}

		rand bit[3:0] vertical_shift_cmd;
		rand bit[3:0] horizontal_shift_cmd;
		// Create 7 vertical shift command(cmd: 1~2) and 7 horizontal shift command(cmd: 3~4) in a row, which guarantee DUT to trigger the image corner.
		constraint cmd_corner_trigger{
			cmd.size() >= (consecutive_num)*2 + 1;
			consecutive_head_idx <= cmd.size() - ((consecutive_num)*2) - 1;
			vertical_shift_cmd inside {[1:2]};
			horizontal_shift_cmd inside {[3:4]};
			foreach(cmd[i])
              	if( i >= consecutive_head_idx)
					if(i < consecutive_head_idx + consecutive_num) cmd[i] == vertical_shift_cmd; // gererate consecutive vertical cmd
					else if(i < consecutive_head_idx + 2*consecutive_num) cmd[i] == horizontal_shift_cmd; // gererate consecutive horizontal cmd
					else cmd[i] inside {[5:11]};
		}

		function void post_randomize;
          cmd = new[cmd.size()+1](cmd); // The last element of cmd array should be 0 (write)
		endfunction

		function new();
			super.new();
			consecutive_num = `IMG_WIDTH-1;
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
			$display("%s, Transaction %0d:", prefix, id);
         	$display("image: ");
			for(int i=0;i<`IMG_WIDTH;i++) begin
        		for(int j=0;j<`IMG_WIDTH;j++) $write("%3d ", image[i*(`IMG_WIDTH)+j]);
					$display();
			end	
			$display("cmd in cmd array ");
          foreach(cmd[i]) $write("%2h ", cmd[i]);
          $display("\nSize of cmd array %0d", cmd.size());
		endfunction: display
    endclass: Transaction

	class Generator;
		Transaction blueprint;
		mailbox #(Transaction) gen2drv;
		event drv2gen;
		int nImages; // How many images for this generator to create
		
		function new(input mailbox #(Transaction) gen2drv, 
					 input event drv2gen,
					 input int nImages);
			this.gen2drv = gen2drv;
			this.drv2gen = drv2gen;
			this.nImages = nImages;
			this.blueprint = new();
		endfunction: new

		task run();
			Transaction cp;
			// The testbench has three types of contraint to apply
			int constraint_num=3;
			
			min_repeat_time: assert(nImages >= 3)
			else $fatal("Generated Image must at least 3 Images.");

			for(int repeat_time=0;repeat_time<nImages;repeat_time++) begin
				if(repeat_time < (nImages/constraint_num))begin
					blueprint.constraint_mode(0);
					blueprint.cmd_base_c.constraint_mode(1);
					if(repeat_time == 0) $display("--- Regular constraint test start ---");
				end	 
				else if(repeat_time < 2*(nImages/constraint_num)) begin 
					blueprint.cmd_edge_trigger.constraint_mode(1);
					if(repeat_time == (nImages/constraint_num)) $display("--- Edge-detected constraint test start ---");
				end
				else begin
					blueprint.cmd_edge_trigger.constraint_mode(0);
					blueprint.cmd_corner_trigger.constraint_mode(1);
					if(repeat_time == 2*(nImages/constraint_num)) $display("--- Corner-detected constraint test start ---");
				end
				`SV_RAND_CHECK(blueprint.randomize());
				$cast(cp, blueprint.copy());
				cp.display($sformatf("Time: %0t",$time));
				gen2drv.put(cp);
				@drv2gen; // Wait for driver to finish it
			end
		endtask: run
	endclass: Generator
	
	class Driver;
		mailbox #(Transaction) gen2drv;
		event drv2gen;
		LCDifTest LCDif;
		int cmd_idx;
		Driver_cb cb;

		function new(input mailbox #(Transaction) gen2drv,
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
					cmd_idx = 0;
					->drv2gen;
				end
			join
			
		endtask: run

		// Store generator generate image and send to DUT if it is needed
		task send_image(input Transaction tr);
			if(LCDif.cb.IROM_rd) LCDif.cb.IROM_Q <= tr.image[LCDif.cb.IROM_A];
		endtask: send_image

		task send_cmd(input Transaction tr);
			if(cmd_idx < tr.cmd.size()) begin
				if(!LCDif.cb.busy && !LCDif.cb.done) begin
					LCDif.cb.cmd <= tr.cmd[cmd_idx];
					LCDif.cb.cmd_valid <= 1;
					cmd_idx++;
				end
				else LCDif.cb.cmd_valid <= 0;
			end
			else LCDif.cb.cmd_valid <= 0;
		endtask: send_cmd
	endclass: Driver

	class Monitor;
		LCDifTest LCDif;
		img_t img;
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
		bit same;
		bit[$clog2(`PIXEL_NUM)-1:0] diff_map[0:`PIXEL_NUM-1];
		img_t expected_img;
		img_t recieved_img;

		function void save_expected(input img_t generated_img, input cmd_t cmd[]);
			// here to use referenced model implemented by C
          	LCD_CTRL_C(generated_img, cmd, expected_img);
			nExpects++;
		endfunction: save_expected

		function void check_actual(input img_t DUT_img);
			recieved_img = DUT_img;
			same = (DUT_img == expected_img);
			foreach(DUT_img[i])	diff_map[i] = !((DUT_img[i] == expected_img[i]));
			if(!same) nErrors++;
		endfunction: check_actual

		function void display();
			if(same) $display("Pass, identical to the referenced model.");
			else begin
				$display("Different pixel, %2d different pixel:", diff_map.sum());
				$write("position: ");
				foreach(diff_map[i]) begin
					if(diff_map[i]) $write("(%0d, %0d) ", i>>$clog2(`IMG_WIDTH),i[$clog2(`IMG_WIDTH)-1:0]);
				end
				$display();
				$display("Transaction result %0d (Expected/ Recieved):", nExpects);
				$display("image: ");
				for(int i=0;i<`IMG_WIDTH;i++) begin
					for(int j=0;j<`IMG_WIDTH;j++) $write("(%3d / %3d) ", expected_img[i*`IMG_WIDTH+j], recieved_img[i*`IMG_WIDTH+j]);
					$display();
			end	
			end
		endfunction
	endclass: Scoreboard;

	class Driver_cb;
		virtual task pre_transmit(input Driver drv, input img_t img, input cmd_t cmd[]);
		endtask: pre_transmit
		
		virtual task post_transmit(input Driver drv, input img_t img, input cmd_t cmd[]);
		endtask: post_transmit
	endclass: Driver_cb

	class Monitor_cb;		
		virtual task post_recieve(input Monitor mon, input img_t img);
		endtask: post_recieve
	endclass: Monitor_cb;

	class Scb_Driver_cb extends Driver_cb;
		Scoreboard scb;
		
		function new(input Scoreboard scb);
			this.scb = scb;
		endfunction: new

		virtual task post_transmit(input Driver drv, input img_t img, input cmd_t cmd[]);
			scb.save_expected(img, cmd);
		endtask: post_transmit
	endclass: Scb_Driver_cb

	class Scb_Monitor_cb extends Monitor_cb;
		Scoreboard scb;
		
		function new(input Scoreboard scb);
			this.scb = scb;
		endfunction: new

		virtual task post_recieve(input Monitor mon, input img_t img);
			scb.check_actual(img);
			scb.display();
		endtask: post_recieve
	endclass

	class Environment;
		Generator gen;
		mailbox #(Transaction) gen2drv;
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
					repeat(`END_CYCLE) @LCDif.cb;
					$display("@%0t: %m ERROR: Generator timeout", $time);
				end
			join_any

			disable timeout_block;
		endtask: run

		virtual function void wrap_up();
			$display("@%0t: Simulation end, %0d Trans generated, %0d Errors", $time, gen.nImages, scb.nErrors);
			if(!scb.nErrors) $display("All pass!");
		endfunction: wrap_up
	endclass: Environment
	
endpackage