`timescale 1ns/1ps
// Byte/token parser in clk_sys. CDC and SPI are separate integration layers.
module sentinel_frame_parser #(
  parameter integer TIMEOUT_CYCLES = 100000
) (
  input logic clk, rst,
  input logic token_valid,
  output logic token_ready,
  input logic [1:0] token_type,
  input logic [7:0] token_data,
  input logic overflow,
  output logic frame_valid,
  input logic frame_ready,
  output logic [255:0] header,
  output logic [511:0] ciphertext,
  output logic [127:0] tag,
  output logic [6:0] payload_length,
  output logic rejected,
  output logic [2:0] reject_reason
);
  localparam [1:0] DATA=0, SOP=1, EOP=2, ABORT=3;
  // Reasons: 1 framing; 2 size; 3 overflow; 4 abort; 5 timeout.
  logic collecting, bad_frame;
  logic [7:0] count_q;
  logic [895:0] frame_q;
  logic [$clog2(TIMEOUT_CYCLES+1)-1:0] timer_q;
  localparam integer TIMER_BITS=$clog2(TIMEOUT_CYCLES+1);
  localparam [TIMER_BITS-1:0] TIMER_LIMIT=TIMER_BITS'(TIMEOUT_CYCLES-1);
  wire [15:0] declared_length = frame_q[31:16];
  assign token_ready = !frame_valid && !overflow;
  always @(posedge clk) begin
    rejected <= 0;
    if (rst) begin
      collecting<=0; bad_frame<=0; count_q<=0; timer_q<=0;
      frame_valid<=0; frame_q<=0; header<=0; ciphertext<=0; tag<=0;
      payload_length<=0; rejected<=0; reject_reason<=0;
    end else if (overflow) begin
      collecting<=0; frame_valid<=0; frame_q<=0; header<=0;
      ciphertext<=0; tag<=0; count_q<=0; timer_q<=0; payload_length<=0;
      rejected<=1; reject_reason<=3;
    end else if (frame_valid) begin
      if (frame_ready) begin
        frame_valid<=0; frame_q<=0; header<=0; ciphertext<=0; tag<=0;
        payload_length<=0; count_q<=0;
      end
    end else if (collecting && timer_q==TIMER_LIMIT) begin
      collecting<=0; frame_q<=0; count_q<=0; timer_q<=0;
      rejected<=1; reject_reason<=5;
    end else begin
      if (collecting) timer_q<=timer_q+1'b1;
      if (token_valid && token_ready) begin
        case (token_type)
          SOP: begin
            if (collecting) begin rejected<=1; reject_reason<=1; end
            collecting<=1; bad_frame<=0; count_q<=0; frame_q<=0; timer_q<=0;
          end
          DATA: begin
            if (!collecting) begin rejected<=1; reject_reason<=1; end
            else if (count_q<112) begin
              frame_q[count_q*8+:8]<=token_data; count_q<=count_q+1'b1;
            end else bad_frame<=1;
          end
          EOP: begin
            collecting<=0; timer_q<=0;
            if (!collecting) begin rejected<=1; reject_reason<=1; end
            else if (bad_frame || declared_length<1 || declared_length>64 ||
                     {8'b0,count_q} != 16'd48+declared_length) begin
              rejected<=1; reject_reason<=2; frame_q<=0; count_q<=0;
            end else begin
              header<=frame_q[255:0];
              ciphertext<=frame_q[767:256] & ((512'b1 << (declared_length*8))-1);
              tag<=128'(frame_q >> ((32+declared_length)*8));
              payload_length<=declared_length[6:0]; frame_valid<=1;
            end
          end
          ABORT: begin
            collecting<=0; frame_q<=0; count_q<=0; timer_q<=0;
            rejected<=1; reject_reason<=4;
          end
        endcase
      end
    end
  end
endmodule
