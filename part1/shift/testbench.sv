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
   logic test_reset = 0;
   assign  reset_i = genarated_reset |  test_reset;
   logic data_i = 0, en_i = 0;
   wire [3:0]  data_o;
   logic [3:0] expected = 0;
   bit  initialized = 0;

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

   shift
     #()
   dut
     (.clk_i(clk_i)
     ,.reset_i(reset_i)
     // Declare the other ports.
     ,.data_i(data_i)
     ,.en_i(en_i)
     ,.data_o(data_o));

   task automatic check(input logic correct, input string label_text);
      error = correct !== 1'b1;
      $display("%t %s: %s", $time, label_text, error ? "FAIL" : "PASS");
      if (error) begin
         `FINISH_WITH_FAIL;
      end
   endtask

   task automatic step(input bit rst, input bit en, input bit data);
      @(negedge clk_i);
      #2;
      test_reset = rst;
      en_i = en;
      data_i = data;
      #2;
      if (initialized && !rst)
         check(data_o === expected, "shift holds before positive edge");
      @(posedge clk_i);
      if (rst) expected = 0;
      else if (en) expected = {expected[2:0], data};
      #2;
      $display("reset=%b en=%b data=%b expected=%h actual=%h",
               rst, en, data, expected, data_o);
      check(data_o === expected, "shift state");
      initialized = 1;
   endtask

   initial begin
      // Call this to set pass_o and error_o to 0.
      `START_TESTBENCH

      // Put your testbench code here. Print all of the test cases and
      // their correctness.

      @(negedge reset_i);
      step(1, 0, 1);

      for (int pattern = 0; pattern < 16; pattern++) begin
         for (int bit_index = 3; bit_index >= 0;  bit_index--)
            step(0, 1, 1'(pattern >> bit_index));
         step(0, 0, 0);
         step(0, 0, 1);
      end

      step(1, 0, 1); 
      repeat (4) step(0, 1, 1);

      step(1, 1,  1);
      step(0, 1, 0);



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
