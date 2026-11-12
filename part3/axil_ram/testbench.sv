`timescale 1ns/1ps

`define START_TESTBENCH error_o = 0; pass_o = 0; #10;
`define FINISH_WITH_FAIL error_o = 1; pass_o = 0; #10; $finish();
`define FINISH_WITH_PASS pass_o = 1; error_o = 0; #10; $finish();
module testbench
  // You don't usually have ports in a testbench, but we need these to
  // signal to cocotb/gradescope that the testbench has passed, or failed.
  (output logic error_o = 1'bx
  ,output logic pass_o = 1'bx);

   // You can use this 
   logic [0:0] error;
   
   wire        clk_i;
   wire        reset_i;
   logic [7:0]  awaddr = 0, araddr = 0;
   logic awvalid = 0, wvalid = 0, bready = 0,  arvalid = 0, rready = 0;
   logic  [31:0] wdata = 0; 
   logic [3:0] wstrb = 0;
   wire awready, wready, bvalid, arready, rvalid;

   wire [31:0] rdata; 
   wire [1:0] bresp, rresp;
   logic  [31:0] message_words  [0:63];
   logic [31:0] word_data;
   bit message_done = 0;  
   int word_count = 0;

   nonsynth_clock_gen
     #(.cycle_time_p(10))
   cg
     (.clk_o(clk_i));

   nonsynth_reset_gen
     #(.reset_cycles_lo_p(1)
      ,.reset_cycles_hi_p(10))
   rg
     (.clk_i(clk_i)
     ,.async_reset_o(reset_i));

   axil_ram
     #(
       // Parameters before Synthesis:
       /*
       .DATA_WIDTH(32)
      ,.ADDR_WIDTH(8)
      ,.PIPELINE_OUTPUT(1)
        */)
   dut
     (.clk(clk_i)
     ,.rst(reset_i)
     // Declare the other ports.
     ,.s_axil_awaddr(awaddr)
     ,.s_axil_awprot(3'b0)
     ,.s_axil_awvalid(awvalid)
     ,.s_axil_awready(awready)
     ,.s_axil_wdata(wdata)
     ,.s_axil_wstrb(wstrb)
     ,.s_axil_wvalid(wvalid)
     ,.s_axil_wready(wready)
     ,.s_axil_bresp(bresp)
     ,.s_axil_bvalid(bvalid)
     ,.s_axil_bready(bready)
     ,.s_axil_araddr(araddr)
     ,.s_axil_arprot(3'b0)
     ,.s_axil_arvalid(arvalid)
     ,.s_axil_arready(arready)
     ,.s_axil_rdata(rdata)
     ,.s_axil_rresp(rresp)
     ,.s_axil_rvalid(rvalid)
     ,.s_axil_rready(rready) );

   task automatic check(input logic correct, input string label_text);
      error = correct !== 1'b1;
      $display("%t %s: %s", $time, label_text, error ? "FAIL" : "PASS");
      if (error) begin
         `FINISH_WITH_FAIL;
      end

   endtask

   initial begin
      #1000000;
      $display("FAIL: testbench timed out");
      `FINISH_WITH_FAIL;
   end

   task automatic read_word(input logic [7:0] address, output logic [31:0] data);
      @(negedge clk_i);
      araddr =  address;
      arvalid = 1;

      do @(posedge clk_i); while (arready !==  1'b1);
      @(negedge clk_i);
      arvalid = 0; 

      do @(posedge clk_i);  while (rvalid !== 1'b1);
      data = rdata;

      check(rresp === 2'b00 && (^data !==  1'bx), "AXI read response");
      $display("read  address=%h data=%h", address, data);
      @(negedge clk_i);
      rready = 1;
      @(posedge clk_i); 
      @(negedge clk_i);
      rready = 0;
   endtask


   task automatic write_word(input logic [7:0] address, input logic [31:0] data, input logic [3:0] strobes);
      bit address_done, data_done;
      address_done = 0;

      data_done = 0;
      @(negedge clk_i);
      awaddr = address;
      wdata = data;
      wstrb =  strobes;
      awvalid = 1;
      wvalid = 1;

      while (!(address_done && data_done)) begin
         @(posedge clk_i);

         if (awvalid && awready) address_done = 1;
         if (wvalid && wready) data_done = 1;

         @(negedge clk_i);
         if (address_done) awvalid = 0;
         if (data_done) wvalid = 0;
      end


      do @(posedge clk_i); while (bvalid !== 1'b1);
      check(bresp === 2'b00,  "AXI write response");
      //actual response helper
      $display("write address=%h data=%h strobes=%b", address, data, strobes);
      @(negedge clk_i);

      bready = 1;
      @(posedge  clk_i);
      @(negedge clk_i);

      bready = 0;

   endtask

   task automatic print_message;
      $write("Message: ");
      for (int index = 0; index < word_count; index++)

         for (int lane = 3; lane >= 0; lane--)
            if (message_words[index][8*lane +: 8] != 0)
               $write("%c", message_words[index][8*lane +: 8]);

      $write("\n");
   endtask

   initial begin
      // Call this to set pass_o and error_o to 0.
      `START_TESTBENCH

      // Put your testbench code here. Print all of the test cases and
      // their correctness.

      @(negedge reset_i);
      for (int index = 0; index < 64 && !message_done; index++) begin
         read_word(8'(index * 4), message_words[index]);
         word_count++;
         for (int lane = 3; lane >= 0; lane--)
            if (message_words[index][8*lane +: 8] == 0) message_done = 1;
      end
      check(message_done, "AXI message terminates within RAM");
      print_message();
      if (message_words[0] == 0) begin
         $display("RAM starts empty, checking fullword and bytestrobe writes.");
         write_word(0, 32'h12345678, 4'b1111);
         write_word(0, 32'h0000ab00, 4'b0010);
         read_word(0, word_data);
         check(word_data === 32'h1234ab78, "AXI writereadback  preserves other bytes");
         write_word(0, 0, 4'b1111);
      end else begin
         //yello slug with space as w
         check(message_words[3] === 32'h6c6c6f20, "misspelled word");
         write_word(8'h0c, 32'h00000077, 4'b0001);
         message_words[3][7:0] = 8'h77;
         for (int index = 0; index < word_count; index++) begin
            read_word(8'(index * 4), word_data);
            check(word_data === message_words[index], "corrected message");
         end
         print_message();
      end




      // Use FINISH_WITH_FAIL to end the testbench and cause the FAIL message, and signal fail to cocotb
      // Use FINISH_WITH_PASS to end the testbench and cause the PASS message, and signal pass to cocotb
      // Calling neither will cause the UNKNOWN message, and cause issues in Cocotb.
      `FINISH_WITH_PASS;
   end

   // This block executes after $finish() has been called.
   final begin
      $display("Simulation time is %t", $time);
      if(error_o === 1) begin
	 $display("\033[0;31m    ______                    \033[0m");
	 $display("\033[0;31m   / ____/_____________  _____\033[0m");
	 $display("\033[0;31m  / __/ / ___/ ___/ __ \\/ ___/\033[0m");
	 $display("\033[0;31m / /___/ /  / /  / /_/ / /    \033[0m");
	 $display("\033[0;31m/_____/_/  /_/   \\____/_/     \033[0m");
	 $display("Simulation Failed");
     end else if (pass_o === 1) begin
	 $display("\033[0;32m    ____  ___   __________\033[0m");
	 $display("\033[0;32m   / __ \\/   | / ___/ ___/\033[0m");
	 $display("\033[0;32m  / /_/ / /| | \\__ \\\__ \ \033[0m");
	 $display("\033[0;32m / ____/ ___ |___/ /__/ / \033[0m");
	 $display("\033[0;32m/_/   /_/  |_/____/____/  \033[0m");
	 $display();
	 $display("Simulation Succeeded!");
     end else begin
        $display("   __  ___   ____ __ _   ______ _       ___   __");
        $display("  / / / / | / / //_// | / / __ \\ |     / / | / /");
        $display(" / / / /  |/ / ,<  /  |/ / / / / | /| / /  |/ / ");
        $display("/ /_/ / /|  / /| |/ /|  / /_/ /| |/ |/ / /|  /  ");
        $display("\\____/_/ |_/_/ |_/_/ |_/\\____/ |__/|__/_/ |_/   ");
	$display("Please set error_o or pass_o!");
     end
   end

endmodule

