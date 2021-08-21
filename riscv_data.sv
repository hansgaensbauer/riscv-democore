`timescale 1ns / 1ps

package riscv_data;

  // general parameters
  localparam error_handler_loc = 32'h0;
  localparam program_counter_increment = 32'd4;
  localparam uart_address = 32'h00020000; //4096
  localparam zero = 32'd0;  //personally, I think this is *more* confusing
  
  //output from controller, input to alu_controller
  typedef enum {alu_add, alu_sub, alu_slt, alu_sltu, alu_var, alu_var_i} alu_command;
  
  //output from alu controller, input to ALU. 
  typedef enum logic [3:0] {
    and_op = 4'b0000,
    or_op = 4'b0001,
    add_op = 4'b0010,
    sub_op = 4'b0110,
    sll_op = 4'b0011,
    slt_op = 4'b0100,
    sltu_op = 4'b0101,
    xor_op = 4'b0111,
    srl_op = 4'b1000,
    sra_op = 4'b1001
    } alu_ctrl_word;
    
    //combination of function 7 and function 3 fields that specify ALU behavior
    typedef enum logic [3:0] {
    add_ins = 4'b0000,
    sub_ins = 4'b1000,
    sll_ins = 4'b0001,
    slt_ins = 4'b0010,
    sltu_ins = 4'b0011,
    xor_ins = 4'b0100,
    srl_ins = 4'b0101,
    sra_ins = 4'b1101,
    or_ins = 4'b0110,
    and_ins = 4'b0111
    } op_type;
    
    //decoding type of instruction from instruction bits 6 to 0
    typedef enum logic [6:0] {
    r_type = 7'b0110011,
    i_type = 7'b0010011,
    l_i_type = 7'b0000011,
    j_i_type = 7'b1100111,
    s_type = 7'b0100011,
    b_type = 7'b1100011,
    u_type = 7'b0Z10111,
    j_type = 7'b1101111
    } instruction_format;
    
    //program counter mux options
    localparam pc_mux_sel_alu_out = 2'b00;
    localparam pc_mux_sel_alu_out_reg = 2'b01;
    localparam pc_mux_sel_jump_target = 2'b10;
    
    //alu input b mux controls
    localparam alu_mux_ctrl_b_b_temp = 2'b00;
    localparam alu_mux_ctrl_b_pc_inc = 2'b01;
    localparam alu_mux_ctrl_b_immediate = 2'b10;
    localparam alu_mux_ctrl_b_pc = 2'b11;
    
    //alu input a mux controls
    localparam alu_mux_ctrl_a_a_temp = 2'b01;
    localparam alu_mux_ctrl_a_pc = 2'b00;
    localparam alu_mux_ctrl_a_zero = 2'b10;
    localparam alu_mux_ctrl_a_pc_prev = 2'b11;
    
    //write enable parameter
    localparam write_enable = 1'b1;
    localparam write_disable = 1'b0;
    
    //regfile data input mux controls
    localparam regfile_write_data_mem = 1'b1;
    localparam regfile_write_data_alu = 1'b0;
    
    //memory address mux controls
    localparam mem_address_mux_ctrl_alu = 1'b1;
    localparam mem_address_mux_ctrl_pc = 1'b0;
    
    //valid invalid parameter
    localparam valid = 1'b1;
    localparam invalid = 1'b0;
    
    //nop
    localparam nop = 32'b00000000000000000000000000110011; //add x0, x0, x0
    
    //memory write data mask
    localparam mask_byte = 4'b0001;
    localparam mask_half = 4'b0011;
    localparam mask_word = 4'b1111;
    
    //load data sizes
    localparam load_word = 2'b10;
    localparam load_byte = 2'b00;
    localparam load_half = 2'b01;
    
    //branch operation selects
    localparam branch_op_sub = 2'b00;
    localparam branch_op_slt = 2'b10; //01
    localparam branch_op_sltu = 2'b11; //10
    
    
    function logic is_branch_store (input logic [31:0] instruction); 
        return (instruction[6:0] == s_type || instruction[6:0] == b_type);
    endfunction
    
    function logic takes_a (input logic [31:0] instruction); 
        return !(instruction[6:0] == j_type || instruction[6:0] == u_type || instruction[6:0] == j_i_type);
    endfunction
    
    function logic takes_b (input logic [31:0] instruction); 
        return (instruction[6:0] == r_type);
    endfunction
    
endpackage //riscv_data
