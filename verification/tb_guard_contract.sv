`timescale 1ns/1ps
module tb_guard_contract;
  reg clk=0;always #10 clk=~clk;
  reg rst=1,provision=0,frame_start=0,frame_complete=1,abort_frame=0,critical_fault=0;
  reg [63:0] session_cfg=1;reg [31:0] destination_cfg=2;
  reg [255:0] header=0;
  reg pt_valid=0,auth_valid=0,auth=0,app_ready=1;
  reg [31:0] pt_data=0;reg [2:0] pt_bytes=0;
  wire app_valid,app_last,app_commit,busy,session_active,rejected,scrub_done;
  wire [31:0] app_data;wire [2:0] app_bytes;wire [63:0] last_seq;
  sentinel_guard #(.TRANSACTION_TIMEOUT_CYCLES(64)) dut(.*);
  integer commits=0,cases=0,fd;
  always @(posedge clk)if(app_commit)commits=commits+1;
  task begin_case(input integer n);
    begin
      @(negedge clk);rst=1;provision=0;pt_valid=0;auth_valid=0;app_ready=1;
      @(negedge clk);rst=0;repeat(18)@(negedge clk);
      provision=1;@(negedge clk);provision=0;
      header=0;header[7:0]=1;header[15:8]=2;header[31:16]=16'(n);
      header[63:32]=2;header[127:64]=1;header[191:128]=1;
      frame_start=1;@(negedge clk);frame_start=0;commits=0;
    end
  endtask
  task beat(input integer n,input bit final_auth);
    begin
      pt_valid=1;pt_bytes=3'(n);pt_data=32'h12345678;
      auth_valid=final_auth;auth=final_auth;
      @(negedge clk);pt_valid=0;auth_valid=0;
    end
  endtask
  task authenticate;
    begin auth_valid=1;auth=1;@(negedge clk);auth_valid=0;end
  endtask
  task check(input integer expected,input string name);
    begin repeat(85)@(negedge clk);
      if(commits!=expected || last_seq!=64'(expected))$fatal(1,"Contract failed %s",name);
      cases=cases+1;$fwrite(fd,"%0d,%s,%0d,%0d\n",cases,name,expected,commits);
    end
  endtask
  initial begin
    fd=$fopen("guard_contract_results.csv","w");
    $fwrite(fd,"id,case,expected_commits,commits\n");
    begin_case(8);beat(4,0);beat(4,0);authenticate();check(1,"packed_words");
    begin_case(8);beat(4,0);beat(4,1);check(1,"final_word_and_auth_same_edge");
    begin_case(8);beat(1,0);beat(4,0);beat(3,0);authenticate();check(0,"partial_intermediate_word");
    begin_case(4);beat(0,0);beat(4,0);authenticate();check(0,"zero_byte_beat");
    begin_case(4);beat(4,0);beat(4,1);check(0,"extra_plaintext_word");
    begin_case(4);check(0,"collection_timeout");
    begin_case(4);beat(4,0);app_ready=0;authenticate();check(0,"release_timeout");
    app_ready=1;repeat(3)@(negedge clk);if(commits!=0)$fatal(1,"Commit after timeout");
    $display("PASS %0d guard interface contracts",cases);$fclose(fd);$finish;
  end
  initial begin #100000;$fatal(1,"Contract global timeout");end
endmodule
