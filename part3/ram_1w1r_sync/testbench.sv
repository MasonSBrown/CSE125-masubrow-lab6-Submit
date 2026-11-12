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
   wire  genarated_reset;
   logic test_reset =  0; 
   assign reset_i = genarated_reset | test_reset;
   logic wr_valid_i = 0, rd_valid_i = 0;
   logic [8:0]  wr_addr_i = 0, rd_addr_i = 0;
   logic  [7:0] wr_data_i = 0;
   wire [7:0] rd_data_o;
   logic [7:0] memory [0:511];
   logic [7:0] expected =  0;
   bit read_initialized = 0;

   nonsynth_clock_gen
     #(.cycle_time_p(10))
   cg
     (.clk_o(clk_i));

   nonsynth_reset_gen
     #(.reset_cycles_lo_p(1)
      ,.reset_cycles_hi_p(10))
   rg
     (.clk_i(clk_i)
     ,.async_reset_o(genarated_reset));

   ram_1w1r_sync
     #(/* 
        These were the declared parameters before synthesis/obfuscation:
        parameter [31:0] width_p = 8
        parameter [31:0] depth_p = 512 */
       )
   dut
     (.clk_i(clk_i)
     ,.reset_i(reset_i)
     // Declare the other ports.
     ,.wr_valid_i(wr_valid_i)
     ,.wr_data_i(wr_data_i)
     ,.wr_addr_i(wr_addr_i)
     ,.rd_valid_i(rd_valid_i)
     ,.rd_addr_i(rd_addr_i)
     ,.rd_data_o(rd_data_o));

   task automatic check(input logic correct, input string label_text);
      error = correct !== 1'b1;

      $display("%t %s: %s", $time, label_text, error ? "FAIL" : "PASS");

      if (error) begin
         `FINISH_WITH_FAIL;
      end
   endtask

   task automatic step(input bit write_en, input logic [8:0] write_addr, input logic [7:0] write_data, input bit read_en, input logic [8:0] read_addr);
      @(negedge clk_i);
      #2;

      wr_valid_i = write_en;
      wr_addr_i = write_addr;
      wr_data_i = write_data;
      rd_valid_i = read_en;
      rd_addr_i = read_addr;

      #2;

      if (read_initialized)
         check(rd_data_o === expected, "RAM holds before positive edge");
      @(posedge clk_i);

      //update the memory first because same address read will see the new byte
      if (write_en) memory[write_addr] = write_data;
      if (read_en) begin
        expected = memory[read_addr]; read_initialized = 1;

      end
      #2;
      $display("write=%b addr=%h data=%h read=%b addr=%h expected=%h actual=%h", write_en, write_addr, write_data, read_en, read_addr, expected, rd_data_o);
      if (read_initialized)
        check(rd_data_o === expected, "RAM sync write priority read");
   endtask

   initial begin
      // Call this to set pass_o and error_o to 0.
      `START_TESTBENCH

      // Put your testbench code here. Print all of the test cases and
      // their correctness.
      
      @(negedge reset_i);
      for (int address = 0; address < 512;  address++)
        step(1, 9'(address), 8'(address  ^ (address >> 8)), 0, 0);

      for (int address = 511; address >= 0; address--)
        step(0, 0, 0,  1, 9'(address));

      for (int address = 0; address < 512; address++) begin
        step(1, 9'(address), ~8'(address ^ (address >> 8)), 1, 9'(address));
        step(0, 9'(address),  8'h5a, 0, 9'(address ^ 511));
      end

      for (int address = 0; address < 512; address++)
        step(1, 9'(address), 8'(address * 37 +  (address >> 8)), 1, 9'(address ^ 511));

      for (int address = 0; address < 512; address++)
        step(0, 9'(address), 8'ha5,  1, 9'(address));


      @(negedge clk_i);
      #2;

      test_reset = 1;
      wr_valid_i = 1;
      wr_addr_i = 9'd42;
      wr_data_i = 8'hc3;
      rd_valid_i = 0;

      repeat (2) @(posedge clk_i);
      @(negedge clk_i);
      #2;

      test_reset = 0;
      wr_valid_i = 0;
      read_initialized = 0;

      for (int address = 0; address < 512; address++)  
        step(0, 0, 0,  1, 9'(address));



      // Use FINISH_WITH_FAIL to end the testbench and cause the FAIL message, and signal fail to cocotb
      // Use FINISH_WITH_PASS to end the testbench and cause the PASS message, and signal pass to cocotb
      // Calling neither will cause the UNKNOWN message, and cause issues in Cocotb.
      `FINISH_WITH_FAIL;
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
