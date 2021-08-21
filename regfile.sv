`timescale 1ns / 1ps

//register file for riscv
module regfile(
    input clk,
    input regfile_write_enable,
    input [4:0] read_address_a,
    input [4:0] read_address_b,
    input [4:0] write_address,
    input [31:0] write_data,
    output logic [31:0] read_data_a,
    output logic [31:0] read_data_b
    );
    
    logic [31:0] array_reg [0:31]; //the registers as a 2d array
    
    //synchronous write
    always_ff @(posedge clk) begin
        array_reg[0] <= 32'b0;
        if(regfile_write_enable && write_address != 5'b0) 
            array_reg[write_address] <= write_data;
    end //always_ff
    
    //assign read ports -- internal forwarding
    always_comb begin
        read_data_a = array_reg[read_address_a];
        read_data_b = array_reg[read_address_b];
        if(regfile_write_enable && write_address != 5'b0) begin
            if(write_address == read_address_a) read_data_a = write_data;
            else if(write_address == read_address_b) read_data_b = write_data;
            else begin
                read_data_a = array_reg[read_address_a];
                read_data_b = array_reg[read_address_b];
            end //else
        end else begin
            read_data_a = array_reg[read_address_a];
            read_data_b = array_reg[read_address_b];
        end //else
    end //always_comb
    
endmodule //regfile