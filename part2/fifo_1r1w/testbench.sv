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
   logic  test_reset = 0; 
   assign reset_i = genarated_reset | test_reset;
   localparam  depth_lp = 256;
   logic  [7:0] data_i = 0;  
   logic valid_i = 0,  ready_i = 0; 
   wire [7:0]  data_o;
   wire ready_o,  valid_o;  
   logic [7:0] expected_queue[$];
   logic [7:0]  removed_data;  
   logic [31:0] random_state = 32'h12560001;

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

   fifo_1r1w
     #(/* Parameters chosen before synthesis/obfuscation  
       parameter [31:0] width_p = 32
       // Note: Not depth_p! depth_p should be 1<<depth_log2_p
      ,parameter [31:0] depth_log2_p = 3*/)
   dut
     (.clk_i(clk_i)
     ,.reset_i(reset_i)
     // Declare the other ports.
     ,.data_i(data_i) 
     ,.valid_i(valid_i)
     ,.ready_o(ready_o)
     ,.valid_o(valid_o) 
     ,.data_o(data_o)  
     ,.ready_i(ready_i));

    task automatic check(input logic correct, input string label_text);
      error = correct !== 1'b1;
      $display("%t %s: %s", $time,  label_text, error ?  "FAIL" : "PASS");
      if (error) begin
         `FINISH_WITH_FAIL;
      end
   endtask


   task automatic check_fifo;
      $display("size=%0d in=%b/%b out=%b/%b expected_data=%h actual_data=%h",
               expected_queue.size(),  valid_i, ready_o,  valid_o, ready_i,
               expected_queue.size() != 0 ?  expected_queue[0] :  8'b0, data_o);
      check(ready_o === (expected_queue.size() < depth_lp),  "FIFO ready");
      check(valid_o === (expected_queue.size() !=  0), "FIFO valid");

      if (expected_queue.size() != 0)  
         check(data_o === expected_queue[0],  "FIFO front data");
   endtask

   task automatic step(input bit send, input bit receive, input logic [7:0] data);
      bit push, pop;
      @(negedge clk_i);
      #2;
      //stalled source retains pending transaction
      if (!valid_i) begin
         valid_i = send;
         data_i = data;
      end

      ready_i = receive;
      #2;
      check_fifo();
      push = valid_i && ready_o;
      pop = valid_o && ready_i;
      @(posedge clk_i);
      if (pop) begin
         removed_data = expected_queue.pop_front();
         check(data_o === removed_data, "FIFO consumed data");
      end

      if (push) expected_queue.push_back(data_i);
      #2;
      check_fifo();
      //accepted no longer needs ot be held

      if (push) valid_i = 0;
   endtask

   task automatic reset_fifo;
      @(negedge clk_i);
      #2;
      test_reset = 1;
      valid_i = 0;
      ready_i = 0;

      @(posedge clk_i);
      expected_queue.delete();
      #2;

      check_fifo();
      @(negedge clk_i);
      #2;

      test_reset = 0;
   endtask

   initial begin
      // Call this to set pass_o and error_o to 0.
      `START_TESTBENCH

      // Put your testbench code here. Print all of the test cases and
      // their correctness.

      @(negedge reset_i);
      reset_fifo();
      repeat (3) step(0, 1,  0);

      for (int round_number = 0; round_number < 3; round_number++) begin
         for (int index = 0; index < depth_lp; index++)
            step(1, 0, 8'(index ^ (index >> 3) ^ (round_number  * 91)));
         repeat (3) step(1, 0, 8'ha5);
         repeat (depth_lp + 1) step(0, 1, 0);
      end

      repeat (32) step(1, 0, 8'h96);
      for (int index = 0; index < 600; index++)
         step(1, 1,  8'(index ^ (index >> 8)));
      for (int index =  0; index < 1500; index++) begin
         random_state = {random_state[30:0], random_state[31] ^
                         random_state[21] ^  random_state[1] ^ random_state[0]};
         step(random_state[8], random_state[16],  random_state[7:0]);
      end

      reset_fifo();
      step(1, 0, 8'h3c);
      step(0, 0, 0);
      step(0, 1, 0);
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
