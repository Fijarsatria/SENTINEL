`timescale 1ns/1ps
`include "ascon_core.sv"
module tb_sentinel;
  reg clk=0;
  always #10 clk=~clk;
  reg core_rst=1, guard_rst=1, app_rst=1;
  reg [31:0] key=0, bdi=0;
  reg key_valid=0, bdi_eot=0, bdi_eoi=0;
  reg [3:0] bdi_valid=0;
  data_t bdi_type=D_INVALID;
  mode_t mode=M_INVALID;
  wire key_ready,bdi_ready,bdo_valid,bdo_eot,auth,auth_valid;
  wire [31:0] bdo;
  data_t bdo_type;
  ascon_core core(.clk(clk),.rst(core_rst),.key(key),.key_valid(key_valid),
    .key_ready(key_ready),.bdi(bdi),.bdi_valid(bdi_valid),.bdi_ready(bdi_ready),
    .bdi_type(bdi_type),.bdi_eot(bdi_eot),.bdi_eoi(bdi_eoi),.mode(mode),
    .bdo(bdo),.bdo_valid(bdo_valid),.bdo_ready(1'b1),.bdo_type(bdo_type),
    .bdo_eot(bdo_eot),.bdo_eoo(1'b0),.auth(auth),.auth_valid(auth_valid));
  reg provision=0,frame_start=0,frame_complete=1,abort_frame=0,critical_fault=0;
  reg [255:0] header=0;
  reg app_ready=1;
  wire app_valid,app_last,app_commit,busy,session_active,rejected,scrub_done;
  wire [31:0] app_data,commit_count;
  wire [2:0] app_bytes;
  wire [63:0] last_seq;
  wire [511:0] live_payload;
  integer ml=0,al=0,g_en=0,action=0,stall=0,observed=0;
  wire [2:0] pt_nbytes = ml-observed>=4 ? 3'd4 : 3'(ml-observed);
  sentinel_guard #(.TRANSACTION_TIMEOUT_CYCLES(1024)) guard(.clk(clk),.rst(guard_rst),.provision(provision),
    .frame_start(frame_start),.session_cfg(64'h0102030405060708),
    .destination_cfg(32'h11223344),.header(header),.frame_complete(frame_complete),
    .abort_frame(abort_frame),.critical_fault(critical_fault),
    .pt_valid(bdo_valid && bdo_type==D_MSG && g_en!=0),
    .pt_data(bdo),.pt_bytes(pt_nbytes),.auth_valid(auth_valid),.auth(auth),
    .app_valid(app_valid),.app_last(app_last),.app_commit(app_commit),
    .app_data(app_data),.app_bytes(app_bytes),.app_ready(app_ready),
    .busy(busy),.session_active(session_active),.rejected(rejected),
    .scrub_done(scrub_done),.last_seq(last_seq));
  sentinel_app app(.clk(clk),.reset_app(app_rst),
    .abort_shadow(guard_rst || abort_frame || critical_fault || !session_active),
    .valid(app_valid),.ready(app_ready),.last(app_last),.commit(app_commit),
    .data(app_data),.data_bytes(app_bytes),.live_payload(live_payload),
    .commit_count(commit_count));
  reg [511:0] pt_seen=0;
  reg [31:0] unsafe_live=0;
  integer unsafe_writes=0;
  integer cycle=0,tracefd=0,caseid=0;
  reg seen_auth=0;
  integer release_beats=0,commit_cycle=-1;
  reg [511:0] sampled_live;
  reg [63:0] sampled_seq;
  reg [31:0] sampled_commits;
  reg sampled_commit,sampled_app_reset,sampled_guard_reset,sampled_provision;
  // Observe both sides of each edge, including NBA updates. A transient
  // unauthorized state change cannot hide behind end-of-transaction checks.
  always @(posedge clk) begin
    sampled_live=live_payload; sampled_seq=last_seq; sampled_commits=commit_count;
    sampled_commit=app_commit; sampled_app_reset=app_rst;
    sampled_guard_reset=guard_rst;
    sampled_provision=provision && guard.phase_q==5'b00001;
    if(app_valid && app_ready)release_beats=release_beats+1;
    if(app_commit)commit_cycle=cycle;
    #1;
    if(!sampled_app_reset && !sampled_commit && live_payload!==sampled_live)
      $fatal(1,"Live state changed without commit case %0d",caseid);
    if(!sampled_guard_reset && !sampled_provision && !sampled_commit && last_seq!==sampled_seq)
      $fatal(1,"Replay state changed without commit case %0d",caseid);
    if(!sampled_app_reset && commit_count!==sampled_commits+32'(sampled_commit))
      $fatal(1,"Commit counter edge mismatch case %0d",caseid);
  end
  reg [31:0] held_data;
  reg [2:0] held_bytes;
  reg held_last,was_stalled=0;
  always @(posedge clk) begin
    cycle=cycle+1;
    if (!core_rst && bdo_valid && bdo_type==D_MSG) begin
      pt_seen[observed*8+:32]<=bdo;
      observed<=observed+((ml-observed>=4)?4:(ml-observed));
      if(g_en!=0)begin unsafe_live<=bdo;unsafe_writes<=unsafe_writes+1;end
    end
    if (core_rst) seen_auth=0;
    else if (auth_valid && auth) seen_auth=1;
    if (app_valid && !seen_auth) $fatal(1,"Premature application output at case %0d",caseid);
    if (was_stalled && !guard_rst && !abort_frame && !critical_fault &&
        guard.watchdog_q!=1023) begin
      if (!app_valid || app_data!==held_data || app_bytes!==held_bytes || app_last!==held_last)
        $fatal(1,"Backpressure changed approved data");
    end
    was_stalled=app_valid && !app_ready;
    held_data=app_data;held_bytes=app_bytes;held_last=app_last;
    if(tracefd!=0)
      $fwrite(tracefd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",cycle,caseid,
        bdo_valid && bdo_type==D_MSG,auth_valid,auth,app_valid,app_ready,
        app_commit,last_seq,guard.phase_q);
  end

  task send_key(input [127:0] k);
    integer i,waits;
    begin
      for(i=0;i<4;i=i+1) begin
        if(i!=0)@(negedge clk);
        key=k[i*32+:32];key_valid=1;
        #1;waits=0;
        while(!key_ready)begin @(negedge clk);#1;waits=waits+1;
          if(waits>1000)$fatal(1,"Key timeout case %0d state %0d",caseid,core.fsm_q);end
        @(posedge clk);
      end
      @(negedge clk);key_valid=0;key=0;
    end
  endtask
  task send_data(input [511:0] d,input integer len,input data_t dt,input bit eoi);
    integer i,j,waits;
    begin
      for(i=0;i<len;i=i+4) begin
        @(negedge clk);bdi=d[i*8+:32];bdi_valid=0;
        for(j=0;j<4;j=j+1) if(i+j<len)bdi_valid[j]=1;
        bdi_type=dt;bdi_eot=(i+4>=len);bdi_eoi=bdi_eot && eoi;
        #1;waits=0;
        while(!bdi_ready)begin @(negedge clk);#1;waits=waits+1;
          if(waits>1000)$fatal(1,"Data timeout case %0d type %0d state %0d",caseid,dt,core.fsm_q);end
        @(posedge clk);
      end
      @(negedge clk);bdi_valid=0;bdi_type=D_INVALID;bdi_eot=0;bdi_eoi=0;bdi=0;
    end
  endtask
  task configure;
    begin
      @(negedge clk);guard_rst=1;
      repeat(2) @(negedge clk);
      guard_rst=0;
      repeat(18) @(negedge clk);
      provision=1;@(negedge clk);provision=0;
    end
  endtask
  integer fd,rv,ea,ec,reprovision,complete_flag,case_count=0,old_commits;
  integer start_cycle,auth_cycle,logfd,delay_count,timeout_count,old_unsafe;
  reg [127:0] k,n,t;
  reg [255:0] ad;
  reg [511:0] ct,expected_pt,old_live;
  reg [63:0] old_seq;
  string vecfile, logfile;
  initial begin
    if(!$value$plusargs("VECTORS=%s",vecfile))vecfile="vectors.txt";
    if(!$value$plusargs("RESULTS=%s",logfile))logfile="results.csv";
    if($test$plusargs("WAVES")) begin
      $dumpfile("sentinel.vcd");$dumpvars(0,tb_sentinel);
      tracefd=$fopen("trace.csv","w");
      $fwrite(tracefd,"cycle,case,raw_pt_valid,auth_valid,auth,app_valid,app_ready,app_commit,last_seq,phase\n");
    end
    logfd=$fopen(logfile,"w");
    $fwrite(logfd,"id,payload_bytes,ad_bytes,guard,expected_auth,expected_commit,cycles_to_auth,commits,last_seq,unsafe_writes,cycles_to_commit,release_beats\n");
    fd=$fopen(vecfile,"r");if(fd==0)$fatal(1,"No vector file");
    repeat(3) @(negedge clk);app_rst=0;core_rst=0;
    configure();
    while(!$feof(fd))begin
      rv=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d %h %h %h %h %h %h\n",
        caseid,ml,al,g_en,ea,ec,reprovision,action,stall,complete_flag,k,n,ad,ct,t,expected_pt);
      if(rv!=16)$fatal(1,"Bad vector count %0d",rv);
      if(reprovision!=0)configure();
      old_commits=commit_count;old_live=live_payload;old_seq=last_seq;old_unsafe=unsafe_writes;
      release_beats=0;commit_cycle=-1;
      @(negedge clk);core_rst=1;mode=M_INVALID;header=ad;
      abort_frame=0;critical_fault=0;app_ready=1;frame_complete=(complete_flag!=0);
      repeat(2) @(negedge clk);core_rst=0;pt_seen=0;observed=0;
      key=k[31:0];key_valid=1;
      mode=M_AEAD128_DEC;frame_start=(g_en!=0);start_cycle=cycle;
      @(negedge clk);mode=M_INVALID;frame_start=0;
      send_key(k);
      send_data({384'b0,n},16,D_NONCE,(al==0)&&(ml==0));
      if(al>0)send_data({256'b0,ad},al,D_AD,ml==0);
      if(ml>0)send_data(ct,ml,D_MSG,1);
      if(action==1)begin guard_rst=1;@(negedge clk);guard_rst=0;end
      if(action==2)begin abort_frame=1;@(negedge clk);abort_frame=0;end
      if(action==3)begin critical_fault=1;@(negedge clk);critical_fault=0;end
      if(action==6)begin
        header=~ad;frame_start=1;@(negedge clk);frame_start=0;
      end
      if(action>=10 && action<15)
        guard.phase_q=guard.phase_q^(5'b00001<<(action-10));
      if(action>=30 && action<32)
        guard.approval_q=guard.approval_q^(2'b01<<(action-30));
      send_data({384'b0,t},16,D_TAG,1);
      timeout_count=0;
      while(!auth_valid)begin
        @(negedge clk);timeout_count=timeout_count+1;
        if(timeout_count>1000)$fatal(1,"Authentication timeout");
      end
      auth_cycle=cycle;
      if(auth!==1'(ea))$fatal(1,"Auth mismatch case %0d",caseid);
      if(ea!=0 && observed!=ml)$fatal(1,"PT size mismatch case %0d",caseid);
      if(ea!=0 && ml>0 && ((pt_seen^expected_pt) & ((512'b1<<(ml*8))-1))!=0)
        $fatal(1,"PT mismatch case %0d",caseid);
      if(stall>0 && action<50)begin
        app_ready=0;
        repeat(stall) @(negedge clk);
        if(commit_count!=old_commits || last_seq!=old_seq)$fatal(1,"Commit during stall");
        app_ready=1;
      end
      if((action>=50 && action<66) || (action>=100 && action<116) ||
         (action>=200 && action<216))begin
        delay_count=action>=200 ? action-200 : action>=100 ? action-100 : action-50;
        while(release_beats<delay_count || !app_valid)@(negedge clk);
        if(action<66)begin
          app_ready=0;repeat(stall)@(negedge clk);app_ready=1;
        end else if(action<116)begin
          abort_frame=1;@(negedge clk);abort_frame=0;
        end else begin guard_rst=1;@(negedge clk);guard_rst=0;end
      end
      if(action==300)begin
        app_ready=0;repeat(1100)@(negedge clk);app_ready=1;
      end
      if(action==4)begin
        timeout_count=0;
        while(!app_valid)begin @(negedge clk);timeout_count=timeout_count+1;
          if(timeout_count>100)$fatal(1,"No release before reset");end
        @(negedge clk);guard_rst=1;@(negedge clk);guard_rst=0;
      end
      if((action>=20 && action<25) || (action>=40 && action<42))begin
        timeout_count=0;
        while(!app_valid)begin @(negedge clk);timeout_count=timeout_count+1;
          if(timeout_count>100)$fatal(1,"No release before fault injection");end
        if(action<25)guard.phase_q=guard.phase_q^(5'b00001<<(action-20));
        else guard.approval_q=guard.approval_q^(2'b01<<(action-40));
      end
      repeat(50) @(negedge clk);
      if(commit_count-old_commits!=ec)$fatal(1,"Commit mismatch case %0d",caseid);
      if(ec!=0 && live_payload!==expected_pt)$fatal(1,"Committed payload mismatch case %0d",caseid);
      if(ec==0 && live_payload!==old_live)$fatal(1,"Rejected frame changed application case %0d",caseid);
      if(ec==0 && action!=1 && action!=3 && action!=4 &&
          !(action>=200 && action<216) && last_seq!=old_seq)
        $fatal(1,"Rejected frame poisoned sequence case %0d",caseid);
      if(g_en!=0)for(delay_count=0;delay_count<16;delay_count=delay_count+1)
        if(guard.quarantine[delay_count]!==0)$fatal(1,"Quarantine was not scrubbed");
      $fwrite(logfd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",caseid,ml,al,g_en,ea,ec,
        auth_cycle-start_cycle,commit_count-old_commits,last_seq,unsafe_writes-old_unsafe,
        commit_cycle<0 ? -1 : commit_cycle-start_cycle,release_beats);
      $fflush(logfd);
      case_count=case_count+1;
    end
    $display("PASS %0d RTL transactions; no premature output or rejected-frame application effect",case_count);
    $fclose(fd);$fclose(logfd);if(tracefd!=0)$fclose(tracefd);$finish;
  end
  initial begin #200000000; $fatal(1,"Global timeout");end
endmodule
