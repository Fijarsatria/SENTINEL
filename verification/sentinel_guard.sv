`timescale 1ns/1ps
module sentinel_guard #(
  parameter integer TRANSACTION_TIMEOUT_CYCLES = 100000
) (
  input logic clk, rst, provision, frame_start,
  input logic [63:0] session_cfg,
  input logic [31:0] destination_cfg,
  input logic [255:0] header,
  input logic frame_complete, abort_frame, critical_fault,
  input logic pt_valid,
  input logic [31:0] pt_data,
  input logic [2:0] pt_bytes,
  input logic auth_valid, auth,
  output logic app_valid, app_last, app_commit,
  output logic [31:0] app_data,
  output logic [2:0] app_bytes,
  input logic app_ready,
  output logic busy, session_active, rejected, scrub_done,
  output logic [63:0] last_seq
);
  localparam [4:0] LOCKED=5'b00001, IDLE=5'b00010,
    COLLECT=5'b00100, RELEASE=5'b01000, SCRUB=5'b10000;
  logic [4:0] phase_q;
  logic [31:0] quarantine [0:15];
  logic [63:0] session_q, pending_seq;
  logic [31:0] destination_q;
  logic [6:0] length_q, received_bytes;
  logic [4:0] wr_q, rd_q, scrub_q;
  logic candidate_ok;
  logic [1:0] approval_q;
  logic [$clog2(TRANSACTION_TIMEOUT_CYCLES+1)-1:0] watchdog_q;
  localparam integer WATCHDOG_BITS=$clog2(TRANSACTION_TIMEOUT_CYCLES+1);
  localparam [WATCHDOG_BITS-1:0] WATCHDOG_LIMIT=WATCHDOG_BITS'(TRANSACTION_TIMEOUT_CYCLES-1);
  wire state_legal = phase_q==LOCKED || phase_q==IDLE ||
    phase_q==COLLECT || phase_q==RELEASE || phase_q==SCRUB;
  wire approval_legal = approval_q==2'b01 || approval_q==2'b10;
  wire [6:0] rd_bytes = {rd_q,2'b00};
  wire beat_ok = wr_q<16 && pt_bytes>=1 && pt_bytes<=4 &&
    received_bytes+{4'b0,pt_bytes}<=length_q &&
    (pt_bytes==4 || received_bytes+{4'b0,pt_bytes}==length_q);
  wire [6:0] collected_after_beat = received_bytes +
    ((pt_valid && beat_ok) ? {4'b0,pt_bytes} : 7'b0);
  assign busy = phase_q!=IDLE;
  assign app_valid = (phase_q==RELEASE) && session_active &&
    !rst && !abort_frame && !critical_fault && state_legal && approval_q==2'b10 &&
    watchdog_q!=WATCHDOG_LIMIT;
  assign app_data = app_valid ? quarantine[rd_q[3:0]] : 32'b0;
  assign app_last = app_valid && (rd_bytes+7'd4 >= length_q);
  assign app_bytes = !app_valid ? 3'd0 : app_last ?
    3'(length_q - rd_bytes) : 3'd4;
  assign app_commit = app_valid && app_ready && app_last;

  always @(posedge clk) begin
    rejected <= 1'b0;
    scrub_done <= 1'b0;
    if (rst) begin
      phase_q <= SCRUB;
      session_active <= 1'b0;
      session_q <= 0;
      destination_q <= 0;
      last_seq <= 0;
      pending_seq <= 0;
      length_q <= 0;
      received_bytes <= 0;
      wr_q <= 0;
      rd_q <= 0;
      scrub_q <= 0;
      candidate_ok <= 0;
      approval_q <= 2'b01;
      watchdog_q <= 0;
    end else if (critical_fault || !state_legal || !approval_legal) begin
      phase_q <= SCRUB;
      scrub_q <= 0;
      session_active <= 0;
      candidate_ok <= 0;
      approval_q <= 2'b01;
      rejected <= 1;
    end else if ((abort_frame || watchdog_q==WATCHDOG_LIMIT) &&
                 (phase_q==COLLECT || phase_q==RELEASE)) begin
      phase_q <= SCRUB;
      scrub_q <= 0;
      candidate_ok <= 0;
      approval_q <= 2'b01;
      rejected <= 1;
    end else begin
      if (phase_q==COLLECT || phase_q==RELEASE) watchdog_q<=watchdog_q+1'b1;
      else watchdog_q<=0;
      case (phase_q)
        LOCKED: if (provision) begin
          session_q <= session_cfg;
          destination_q <= destination_cfg;
          session_active <= 1;
          last_seq <= 0;
          phase_q <= IDLE;
        end
        IDLE: if (frame_start) begin
          pending_seq <= header[191:128];
          length_q <= header[22:16];
          received_bytes <= 0;
          wr_q <= 0;
          rd_q <= 0;
          approval_q <= 2'b01;
          candidate_ok <= frame_complete && session_active &&
            header[7:0]==8'd1 &&
            ((header[15:8]==8'd1 && header[31:16]==4) || header[15:8]==8'd2) &&
            header[31:16]>=1 && header[31:16]<=64 &&
            header[63:32]==destination_q &&
            header[127:64]==session_q &&
            header[191:128]>last_seq && header[255:192]==0;
          phase_q <= COLLECT;
        end
        COLLECT: begin
          if (pt_valid) begin
            if (beat_ok) begin
              quarantine[wr_q[3:0]] <= pt_data;
              wr_q <= wr_q+1;
              received_bytes <= received_bytes+{4'b0,pt_bytes};
            end else candidate_ok <= 0;
          end
          if (auth_valid) begin
            if (auth && candidate_ok && collected_after_beat==length_q &&
                (!pt_valid || beat_ok) && length_q!=0) begin
              phase_q <= RELEASE;
              approval_q <= 2'b10;
            end else begin
              phase_q <= SCRUB;
              scrub_q <= 0;
              rejected <= 1;
            end
          end
        end
        RELEASE: if (app_valid && app_ready) begin
          if (app_commit) begin
            last_seq <= pending_seq;
            phase_q <= SCRUB;
            scrub_q <= 0;
          end else rd_q <= rd_q+1;
        end
        SCRUB: begin
          quarantine[scrub_q[3:0]] <= 0;
          if (scrub_q==15) begin
            phase_q <= session_active ? IDLE : LOCKED;
            scrub_q <= 0;
            pending_seq <= 0;
            length_q <= 0;
            received_bytes <= 0;
            wr_q <= 0;
            rd_q <= 0;
            candidate_ok <= 0;
            approval_q <= 2'b01;
            scrub_done <= 1;
          end else scrub_q <= scrub_q+1;
        end
        default: begin phase_q <= SCRUB; scrub_q <= 0; session_active <= 0; end
      endcase
    end
  end
endmodule
