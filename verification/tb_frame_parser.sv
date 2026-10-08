`timescale 1ns/1ps
module tb_frame_parser;
  reg clk=0; always #10 clk=~clk;
  reg rst=1, token_valid=0, overflow=0, frame_ready=0;
  reg [1:0] token_type=0; reg [7:0] token_data=0;
  wire token_ready,frame_valid,rejected;
  wire [255:0] header; wire [511:0] ciphertext;
  wire [127:0] tag; wire [6:0] payload_length; wire [2:0] reject_reason;
  sentinel_frame_parser #(.TIMEOUT_CYCLES(512)) dut(.*);
  integer cases=0, accepts=0, rejects=0, i,j,l,kind,nbytes,seed=20261008;
  reg [895:0] expected, frozen;
  integer logfd;
  integer rejection_events=0, prior_rejections;
  integer last_reason=0;
  always @(negedge clk)if(rejected)begin
    rejection_events=rejection_events+1;last_reason=int'(reject_reason);
  end
  task send(input [1:0] t,input [7:0] d);
    begin
      @(negedge clk); token_valid=1;token_type=t;token_data=d;
      if(!token_ready)$fatal(1,"Unexpected parser backpressure");
      @(negedge clk);token_valid=0;
    end
  endtask
  task reset_parser;
    begin @(negedge clk);rst=1;@(negedge clk);rst=0;end
  endtask
  initial begin
    logfd=$fopen("parser_results.csv","w");
    $fwrite(logfd,"id,kind,payload_bytes,accepted,rejected\n");
    repeat(3)@(negedge clk);rst=0;
    for(i=0;i<10000;i=i+1)begin
      l=1+(i%64);kind=i%8;expected=0;
      for(j=0;j<112;j=j+1)expected[j*8+:8]=8'($random(seed));
      expected[31:16]=16'(l);
      reset_parser();prior_rejections=rejection_events;send(1,0);
      nbytes=48+l;
      if(kind==1)nbytes=nbytes-1;
      if(kind==2)nbytes=nbytes+1;
      if(kind==3)expected[31:16]=0;
      if(kind==4)expected[31:16]=65;
      for(j=0;j<nbytes;j=j+1)send(0, j<112 ? expected[j*8+:8] : 8'hff);
      if(kind==5)send(3,0);
      else if(kind==6)begin @(negedge clk);overflow=1;@(negedge clk);overflow=0;end
      else if(kind==7)repeat(520)@(negedge clk);
      else send(2,0);
      if(kind==0)begin
        if(rejection_events!=prior_rejections)$fatal(1,"Valid frame was rejected");
        if(!frame_valid || payload_length!=7'(l) || header!==expected[255:0] ||
           ciphertext !== (expected[767:256]&((512'b1<<(l*8))-1)) ||
           tag!==128'(expected>>((32+l)*8)))$fatal(1,"Parser accepted data mismatch case %0d",i);
        frozen={header,ciphertext,tag};
        repeat(5)begin
          @(negedge clk);token_valid=1;token_type=1;
          if(token_ready || !frame_valid || {header,ciphertext,tag}!==frozen)
            $fatal(1,"Frozen descriptor overwritten");
        end
        token_valid=0;frame_ready=1;@(negedge clk);frame_ready=0;
        if(frame_valid)$fatal(1,"Descriptor did not retire");
        accepts=accepts+1;
      end else begin
        if(frame_valid)$fatal(1,"Malformed frame accepted case %0d kind %0d",i,kind);
        @(negedge clk);
        if(rejection_events==prior_rejections)$fatal(1,"Missing parser rejection event");
        if((kind==5 && last_reason!=4) || (kind==6 && last_reason!=3) ||
           (kind==7 && last_reason!=5))$fatal(1,"Wrong parser rejection reason");
        rejects=rejects+1;
      end
      cases=cases+1;$fwrite(logfd,"%0d,%0d,%0d,%0d,%0d\n",i+1,kind,l,kind==0,kind!=0);
    end
    // Interruption at every byte position of a full 112-byte frame.
    for(kind=9;kind<=10;kind=kind+1)for(nbytes=0;nbytes<=112;nbytes=nbytes+1)begin
      reset_parser();expected=0;expected[31:16]=64;
      send(1,0);for(j=0;j<nbytes;j=j+1)send(0,expected[j*8+:8]);
      if(kind==9)send(3,0);else reset_parser();
      @(negedge clk);
      if(frame_valid || dut.collecting)$fatal(1,"Interrupted frame survived cleanup");
      if(kind==10 && (header!==0 || ciphertext!==0 || tag!==0))
        $fatal(1,"Reset did not discard descriptor");
      cases=cases+1;rejects=rejects+1;
      $fwrite(logfd,"%0d,%0d,64,0,1\n",cases,kind);
    end
    // Every legal length is also checked independently of the kind interleave.
    for(l=1;l<=64;l=l+1)begin
      reset_parser();expected=0;expected[31:16]=16'(l);
      send(1,0);for(j=0;j<48+l;j=j+1)send(0,expected[j*8+:8]);send(2,0);
      if(!frame_valid || payload_length!=7'(l))$fatal(1,"Boundary length failed");
      cases=cases+1;accepts=accepts+1;
      $fwrite(logfd,"%0d,8,%0d,1,0\n",cases,l);
    end
    $display("PASS %0d parser frames; %0d accepted, %0d rejected",cases,accepts,rejects);
    $fclose(logfd);$finish;
  end
  initial begin #70000000;$fatal(1,"Parser global timeout");end
endmodule
