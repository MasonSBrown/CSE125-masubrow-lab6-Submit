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
   wire genarated_reset; 
   logic test_reset = 0;
   assign reset_i = genarated_reset  | test_reset;

   logic d_i = 0, en_i = 0;
   wire q_o;  

   logic expected = 0;
   bit initialized = 0;

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

   dff
     #()
   dut
     (.clk_i(clk_i)
     ,.reset_i(reset_i)
     // Declare the other ports.
     ,.d_i(d_i)
     ,.en_i(en_i)
     ,.q_o(q_o));

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
      d_i = data;
      #2;

      if (initialized && !rst)
         check(q_o === expected, "DFF holds before positive edge");
      @(posedge clk_i);
      if (rst) expected = 0;
      else if (en) expected = data;
      #2;
      
      $display("reset=%b en=%b d=%b expected=%b actual=%b",
               rst, en, data, expected, q_o);
      check(q_o === expected, "DFF state");
      initialized = 1;

   endtask

   initial begin
      // Call this to set pass_o and error_o to 0.
      `START_TESTBENCH

      // Put your testbench code here. Print all of the test cases and
      // their correctness.

      @(negedge reset_i);

      step(1, 1, 1);

      for (int state_value = 0;  state_value < 2; state_value++)
         for (int inputs = 0; inputs < 8; inputs++) begin 
            step(0, 1,  1'(state_value));
            step(1'(inputs >> 2),  1'(inputs >> 1), 1'(inputs));
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
