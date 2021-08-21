`timescale 1ns / 1ps

module top(
    input logic       clk,   //12MHz clock
    input logic      reset,  //connected to a button
    output uart_rxd_out,     //uart pins
    input uart_txd_in,
    output ck_io34,          //debug
    output ck_io35           //debug
    );
    
    import riscv_data::*;       //data package with all the parameters and structs

    //internal signals
    logic           instruction_valid;
    logic [31:0]    instruction_addr;
    logic [31:0]    instruction_read;
    logic           instruction_ready;

    logic           data_read_valid;
    logic           data_write_valid;
    logic [31:0]    data_addr;
    logic [31:0]    data_read;
    logic [31:0]    data_write;
    logic [3:0]     data_write_byte;
    logic           data_ready;

    //instantiate the core
    riscv32 core(
        .clk(clk),
        .reset(reset),
        .instruction_valid(instruction_valid),          // instruction fetch?
        .instruction_addr(instruction_addr),            // instruction fetch address?
        .instruction_read(instruction_read),            // data returned from memory
        .instruction_ready(instruction_ready),          // data returned is valid this clock cycle
        .data_read_valid(data_read_valid),              // do read?
        .data_write_valid(data_write_valid),            // do write?
        .data_addr(data_addr),                          // address
        .data_read(data_read),                          // data read back from memory
        .data_write(data_write),                        // data to be written to memory
        .data_write_byte(data_write_byte),              // which bytes of the data should be written
        .data_ready(data_ready)                         // data memory has finished R/W this cycle
        );
        
     //instruction ROM
     block_ram #(.init_value_file("code.txt")) instruction_rom (
        .clk(clk), 
        .en(instruction_valid),
        .we(4'b0),
        .addr(instruction_addr[11:2]),
        .di(32'b0), 
        .dout(instruction_read)
     );
     
     //slice out bottom addresses for the RAM
     logic data_ram_addr_match_flag;
     assign data_ram_addr_match_flag = (data_addr[31:14] == 18'b0);
     
     //data RAM
     wide_ram data_ram (
        .address(data_addr[13:0]),
        .data_in(data_write),
        .clk(clk),
        .we(data_write_valid && data_ram_addr_match_flag),
        .byte_we(data_write_byte),
        .data_out(data_read)
     );
        
     //map the uart to the uart address
     logic uart_addr_match_flag;
     assign uart_addr_match_flag = (data_addr == uart_address);
        
     //instantiate the UART
     uart serial_io(
        .tx_data(data_write[7:0]),
        .tx_data_ready(data_write_valid && uart_addr_match_flag), //essentially a write enable
        .txd(uart_rxd_out),
        .hs_clk(clk),
        .xfer_done(data_ready)
     );
     
     //pins for debugging the UART. These break the tx and rx pins out so I can see them with a DSO
     assign ck_io34 = uart_rxd_out;
     assign ck_io35 = uart_txd_in;
        
endmodule //top

/* verilator lint_off STMTDLY*/
/* verilator lint_off INFINITELOOP*/
module top_tb();
    logic clk;
    logic reset;
    logic uart_rxd_out, ck_io34, uart_txd_in, ck_io35;
    
    //instantiate the DUT
    top DUT(.*);
    
    //clock signal
    initial begin
        clk = 1'b0;
        forever begin
            #5;
            clk = ~clk;
        end //forever
    end //initial
    
    //reset pulse
    initial begin
        #10; reset = 1'b1;
        #10; reset = 1'b0;
    end //initial
    
endmodule //top_tb
/* verilator lint_on STMTDLY*/
/* verilator lint_on INFINITELOOP*/
