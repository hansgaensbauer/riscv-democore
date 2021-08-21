`timescale 1ns / 1ps
//memory module for riscv. 32 bit plane, 4 write enable bytes
module wide_ram(
    input [13:0] address,
    input [31:0] data_in,
    input clk,
    input we,
    input [3:0] byte_we,
    output logic [31:0] data_out
    );
    
    //asynchronous data out
    logic [31:0] ram_data_out;
    
    //shifted inputs
    logic [31:0] data_in_aligned;
    logic [3:0] bwe_aligned;
    
    logic [1:0] lsbs_last, lsbs_dlast;
    
    always_ff @(posedge clk) begin
        lsbs_last <= address[1:0];
        lsbs_dlast <= lsbs_last;
    end //always_ff
    
    //multiplex to handle byte alignment
    always_comb begin
        data_in_aligned = data_in;
        data_out = ram_data_out;
        case(address[1:0])
            2'b00: data_in_aligned = data_in;
            2'b01: data_in_aligned = (data_in << 8);
            2'b10: data_in_aligned = (data_in << 16);
            2'b11: data_in_aligned = (data_in << 24);
        endcase
        case(lsbs_last)
            2'b00: data_out = ram_data_out;
            2'b01: data_out = (ram_data_out >> 8);
            2'b10: data_out = (ram_data_out >> 16);
            2'b11: data_out = (ram_data_out >> 24);
        endcase
    end //always_comb
    
    assign bwe_aligned = byte_we << address[1:0];
    
    //32 bit wide ram IP core with byte write enables
    block_ram #(.init_value_file("data.txt")) ram_core (
        .clk(clk),
        .en(1'b1),
        .we({4{we}} & bwe_aligned),
        .addr(address[11:2]),
        .di(data_in_aligned),
        .dout(ram_data_out)
    );
    
endmodule //fancy_mem