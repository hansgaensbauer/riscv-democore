`timescale 1ns / 1ps

//Arithmetic logic unit
import riscv_data::alu_ctrl_word;

module alu(
    input logic signed [31:0] a,
    input logic signed [31:0] b,
    output logic [31:0] out,
    output logic alu_zero,
    input alu_ctrl_word control
    );
    
    import riscv_data::*;   //import the rest of the package
    
    //assign the zero output
    assign alu_zero = (out == 32'b0);
    
    //This is necessary to satisfy prof. Oskins single adder requirement
    logic [31:0] inv_b;
    logic subtract;
    assign inv_b = (b ^ {32{subtract}});
    
    logic [31:0] adder_out;
    assign adder_out = (a + inv_b + {31'b0,subtract});
    
    //every instruction
    always_comb begin
        subtract = 0;
        case (control)
            and_op: out = (a & b);
            or_op: out = (a | b);
            add_op: out = adder_out;
            sub_op: begin
                out = adder_out;
                subtract = 1;
            end
            sll_op: out = (a << b[4:0]);
            slt_op: out = {31'b0, (a < b)};
            sltu_op: out = {31'b0, (a[31:0] < b[31:0])}; //forces unsigned comparison
            xor_op: out = (a ^ b);
            srl_op: out = (a >> b[4:0]);
            sra_op: out = (a >>> b[4:0]);
            default: out = 32'b0;
        endcase
    end //always_comb
    
endmodule //alu