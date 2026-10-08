`timescale 1ns/1ps
module sentinel_app (
  input logic clk, reset_app, abort_shadow,
  input logic valid, ready, last, commit,
  input logic [31:0] data,
  input logic [2:0] data_bytes,
  output logic [511:0] live_payload,
  output logic [31:0] commit_count
);
  logic [31:0] shadow [0:15];
  logic [4:0] index_q;
  logic [31:0] masked_data;
  integer i;
  always @* begin
    masked_data = data;
    case (data_bytes)
      1: masked_data = data & 32'h000000ff;
      2: masked_data = data & 32'h0000ffff;
      3: masked_data = data & 32'h00ffffff;
      default: masked_data = data;
    endcase
  end
  always @(posedge clk) begin
    if (reset_app) begin
      index_q <= 0;
      commit_count <= 0;
      live_payload <= 0;
      for (i=0;i<16;i=i+1) shadow[i] <= 0;
    end else if (abort_shadow) begin
      index_q <= 0;
      for (i=0;i<16;i=i+1) shadow[i] <= 0;
    end else if (valid && ready) begin
      shadow[index_q[3:0]] <= masked_data;
      if (commit && last) begin
        for (i=0;i<16;i=i+1)
          live_payload[i*32+:32] <= (i==int'(index_q)) ? masked_data :
            (i<int'(index_q) ? shadow[i] : 32'b0);
        commit_count <= commit_count+1;
        index_q <= 0;
        for (i=0;i<16;i=i+1) shadow[i] <= 0;
      end else index_q <= index_q+1;
    end
  end
endmodule
