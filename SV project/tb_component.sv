`define SV_RAND_CHECK(r) \
	do begin\
      if(!(r)) begin\
        $display("%s: %0d  Randomization failed\"%s\"", \
        `__FILE__, `__LINE__, `"r`");\
        $finish;\
      end\
    end while(0)
// `include "interface.sv"

package tb_component;
	
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
		rand bit [7:0] image[0:63]; // 8 bits 8*8 image with no constraint
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
				cp.display($sformatf("@%0t: ", $time));
				gen2drv.put(cp);
              $display("success");
				@drv2gen; // Wait for driver to with finish it
			end
		endtask: run
	endclass: Generator
	
	typedef virtual LCD_if.TEST LCDifTest;

	class Driver;
		mailbox gen2drv;
		event drv2gen;
		LCDifTest LCDif;
		bit [5:0] cmd_length;

		extern function new(input mailbox gen2drv,
							input event drv2gen,
							input LCDifTest LCDif);
		extern task run();
		extern task send_image(input Transaction tr);
		extern task send_cmd(input Transaction tr);

	endclass: Driver

	function Driver::new(input mailbox gen2drv,
						 input event drv2gen,
						 input LCDifTest LCDif);
			this.gen2drv = gen2drv;
			this.drv2gen = drv2gen;
			this.LCDif = LCDif;
	endfunction: new

	// Get transaction from generator and keep interating with DUT
	task Driver::run();
		Transaction tr;

		//Initialize the ports
		LCDif.cb.cmd_valid <= 0;
		
		fork
			forever begin
				gen2drv.peek(tr);
				@(LCDif.cb);
				send_image(tr);
				send_cmd(tr);
              if(LCDif.cb.done) begin
					gen2drv.get(tr);
					->drv2gen;
                    $display("event trigger seccess");
				end
			end
		join
		

	endtask: run

	// Store generator generate image and send to DUT if it is needed
	task Driver::send_image(input Transaction tr);
      	if(LCDif.cb.IROM_rd) LCDif.cb.IROM_Q <= tr.image[LCDif.cb.IROM_A];
      $display("%t: LCDif.cb.IROM_A: %2d,  tr.image[LCDif.cb.IROM_A]: %3d",$time,  LCDif.cb.IROM_A, tr.image[LCDif.cb.IROM_A]);
	endtask: send_image

	task Driver::send_cmd(input Transaction tr);
		if(cmd_length < tr.cmd.size()) begin
			if(!LCDif.cb.busy) begin
				LCDif.cb.cmd <= tr.cmd[cmd_length];
				LCDif.cb.cmd_valid <= 1;
				cmd_length++;
			end
			else LCDif.cb.cmd_valid <= 0;
		end
		else LCDif.cb.cmd_valid <= 0;
	endtask: send_cmd
endpackage