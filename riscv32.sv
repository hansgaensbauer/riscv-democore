`timescale 1ns / 1ps

module riscv32 #(parameter reset_pc = 32'h00000000) (
    input logic       clk,
    input logic      reset,
    
    output logic           instruction_valid,
    output logic [31:0]    instruction_addr,
    input logic [31:0]    instruction_read,
    input logic           instruction_ready,

    output logic           data_read_valid,
    output logic           data_write_valid,
    output logic [31:0]    data_addr,
    input logic [31:0]    data_read,
    output logic [31:0]    data_write,
    output logic [3:0]     data_write_byte,
    input logic           data_ready
    );
    
    import riscv_data::*;       //data package with all the parameters and structs
    
    logic stall;    //signal to trigger a stall
    assign instruction_valid = !stall;
    
    //////////////////////////////////////////////////////////
    ///                Instruction Fetch Stage
    //////////////////////////////////////////////////////////
    
    //program counter
    logic [31:0] program_counter;
    logic [31:0] pc_next;
    logic [31:0] pc_prev;           //for auipc
    logic [31:0] branch_target;
    
    logic branch, branch_stall;
    
    logic [31:0] pc_inc;    //compute the next program counter
    
    //updating the program counter
    always_comb begin
        branch_stall = 1'b0;
        pc_inc = 32'd4 + program_counter;
        if(program_counter > 32'd4) begin
            if(branch) begin
                pc_inc = branch_target;
                branch_stall = 1'b1;
            end
        end
    end //always_comb
    
    //update the registers
    always_ff @(posedge clk) begin
        if(reset) program_counter <= reset_pc;
        else if(stall) program_counter <= program_counter;
        else program_counter <= pc_inc;
    end //always_ff
    
    assign instruction_addr = pc_inc - 32'd4; 
    
    //////////////////////////////////////////////////////////
    ///       Instruction Decode/Regfile Read Stage
    //////////////////////////////////////////////////////////
    
    //calculate immediate (possible input to ALU)
    logic [31:0] immediate;
    logic [31:0] regfile_write_data_last;
    
    logic [31:0] immediate_reg;
    logic [31:0] instruction_read_2;
    logic [31:0] regfile_out_a_reg, regfile_out_b_reg;    
    logic [31:0] branch_forward_a, branch_forward_b;
    logic [31:0] jump_reg_branch_sum;
    
    assign jump_reg_branch_sum = immediate_reg + branch_forward_a + 32'd4;
    
    //calculate the branch address
    always_comb begin
        branch_target = immediate_reg + pc_prev;
        if(instruction_read_2[6:0] == j_i_type) branch_target = {jump_reg_branch_sum[31:1], 1'b0};
        else if(instruction_read_2[6:0] == j_type) branch_target = immediate_reg + pc_prev;
    end //always_comb
    
    //evaluate the branch condition
    logic branch_cond;
    always_comb begin
        case(instruction_read_2[14:13])
            2'b00: branch_cond = (branch_forward_a == branch_forward_b);
            2'b10: branch_cond = !(|(branch_forward_a < branch_forward_b));
            2'b11: branch_cond = !(|(branch_forward_a[31:0] < branch_forward_b[31:0]));
            default: branch_cond = 1'b0;
        endcase
        branch = ((branch_cond ^ instruction_read_2[12]^ instruction_read_2[14]) && (instruction_read_2[6:0] == b_type) ||
                        instruction_read_2[6:0] == j_type || instruction_read_2[6:0] == j_i_type);
    end //always_comb
    
    always_comb begin
        casez(instruction_read[6:0])
            u_type: immediate = {instruction_read[31:12], 12'b0};
            j_type: immediate = {{11{instruction_read[20]}}, instruction_read[31], instruction_read[19:12], instruction_read[20], instruction_read[30:21],1'b0};
            b_type: immediate = {{20{instruction_read[31]}},instruction_read[7], instruction_read[30:25],instruction_read[11:8], 1'b0};
            i_type: immediate = {{20{instruction_read[31]}},instruction_read[31:20]};
            l_i_type: immediate = {{20{instruction_read[31]}},instruction_read[31:20]};
            j_i_type: immediate = {{20{instruction_read[31]}},instruction_read[31:20]};
            s_type: immediate = {{20{instruction_read[31]}},instruction_read[31:25], instruction_read[11:7]};
            default: immediate = 32'b0;	//nothing
        endcase
    end //always_comb
    
    //regfile wires
    logic [31:0] regfile_write_data, regfile_out_a, regfile_out_b;
    logic [4:0] regfile_write_address;
    logic regfile_write_enable;
    
    //instantiate the regfile
    regfile riscv_regfile(
        .clk(clk),
        .regfile_write_enable(regfile_write_enable),
        .read_address_a(instruction_read[19:15]),
        .read_address_b(instruction_read[24:20]),
        .write_address(regfile_write_address),
        .write_data(regfile_write_data),
        .read_data_a(regfile_out_a),
        .read_data_b(regfile_out_b)
        );
        
    //update the registers
    always_ff @(posedge clk) begin
        regfile_out_a_reg <= (branch_stall || stall) ? 32'b0 : regfile_out_a;
        regfile_out_b_reg <= (branch_stall || stall) ? 32'b0 : regfile_out_b;
        instruction_read_2 <= stall ? nop : branch_stall ? nop : instruction_read;
        immediate_reg <= immediate;
        pc_prev <= program_counter;
        regfile_write_data_last <= regfile_write_data;
    end //always_ff
    
    //////////////////////////////////////////////////////////
    ///        Execute/Address Calculation Stage
    //////////////////////////////////////////////////////////
    
    logic [31:0] alu_out, alu_out_reg;
    logic [31:0] alu_in_a, alu_in_b, alu_in_a_norm, alu_in_b_norm;
    logic [31:0] instruction_read_3;
    logic [31:0] immediate_reg_2;
    logic [31:0] regfile_out_b_reg_reg;   
    logic alu_zero;
    alu_ctrl_word alu_ctrl;
    
    //alu input mux (includes forwarding)
    always_comb begin
        alu_in_a_norm = regfile_out_a_reg;
        casez(instruction_read_2[6:0])
            r_type: alu_in_b_norm = regfile_out_b_reg;
            i_type: alu_in_b_norm = immediate_reg;
            s_type: alu_in_b_norm = immediate_reg;
            l_i_type: alu_in_b_norm = immediate_reg;
            u_type: begin
                alu_in_b_norm = immediate_reg;
                alu_in_a_norm = instruction_read_2[5] ? 32'b0 : pc_prev;
            end
            j_type: begin
                alu_in_b_norm = pc_prev;
                alu_in_a_norm = 32'b0;
            end
            j_i_type: begin
                alu_in_b_norm = pc_prev;
                alu_in_a_norm = 32'b0;
            end
            default: alu_in_b_norm = immediate_reg;
        endcase
    end //always_comb
    
    //instantiate the ALU
   alu risvc_alu(
        .a(alu_in_a),
        .b(alu_in_b),
        .out(alu_out),
        .alu_zero(alu_zero),
        .control(alu_ctrl)
    );
    
    //alu controller
    always_comb begin
        casez(instruction_read_2[6:0])
            r_type: begin
                case({(instruction_read_2[5] & instruction_read_2[30]),instruction_read_2[14:12]})
                    add_ins: alu_ctrl = add_op;
                    sub_ins: alu_ctrl = sub_op;
                    sll_ins: alu_ctrl = sll_op;
                    slt_ins: alu_ctrl = slt_op;
                    sltu_ins: alu_ctrl = sltu_op;
                    xor_ins: alu_ctrl = xor_op;
                    srl_ins: alu_ctrl = srl_op;
                    sra_ins: alu_ctrl = sra_op;
                    or_ins: alu_ctrl = or_op;
                    and_ins: alu_ctrl = and_op;
                    default: alu_ctrl = and_op;
                endcase
            end
            i_type: begin
                case({(instruction_read_2[5] & instruction_read_2[30]),instruction_read_2[14:12]})
                    add_ins: alu_ctrl = add_op;
                    sub_ins: alu_ctrl = sub_op;
                    sll_ins: alu_ctrl = sll_op;
                    slt_ins: alu_ctrl = slt_op;
                    sltu_ins: alu_ctrl = sltu_op;
                    xor_ins: alu_ctrl = xor_op;
                    srl_ins: alu_ctrl = srl_op;
                    sra_ins: alu_ctrl = sra_op;
                    or_ins: alu_ctrl = or_op;
                    and_ins: alu_ctrl = and_op;
                    default: alu_ctrl = and_op;
                endcase
            end
            s_type: alu_ctrl = add_op;
            u_type: alu_ctrl = add_op;
            default alu_ctrl = add_op;
        endcase
    end //always_comb    
    
        //update the registers
    always_ff @(posedge clk) begin
        alu_out_reg <= alu_out;
        instruction_read_3 <= instruction_read_2;
        regfile_out_b_reg_reg <= regfile_out_b_reg;
    end //always_ff
    
    //////////////////////////////////////////////////////////
    ///               Memory Access Stage
    //////////////////////////////////////////////////////////
    
    logic [31:0] instruction_read_4, regfile_write_alu;
    
    assign data_addr = alu_out_reg;
    assign data_write_valid = instruction_read_3[6:0] == s_type;
    
    //data read mask
    logic sign;
    assign sign = ~instruction_read_3[5];
    always_comb begin
        case(instruction_read_3[13:12])
            load_byte: data_write_byte = mask_byte;
            load_half: data_write_byte = mask_half;
            load_word: data_write_byte = mask_word;
            default: data_write_byte = mask_byte;
        endcase
    end //always_comb
    
    //update pipeline registers
    always_ff @(posedge clk) begin
        regfile_write_alu <= alu_out_reg;
        instruction_read_4 <= instruction_read_3;
    end //always_ff
    
    //////////////////////////////////////////////////////////
    ///                 Write Back Stage
    //////////////////////////////////////////////////////////
    logic [31:0] instruction_read_5;
    logic [31:0] data_read_masked;
    
    //data write_mask
    always_comb begin
        case(instruction_read_4[13:12])
            load_byte: data_read_masked = {{24{sign & data_read[7]}}, data_read[7:0]};
            load_half: data_read_masked = {{16{sign & data_read[15]}}, data_read[15:0]};
            load_word: data_read_masked = data_read;
            default: data_read_masked = data_read;
        endcase
    end //always_comb
    
    assign regfile_write_address = instruction_read_4[11:7];
    assign regfile_write_enable = !is_branch_store(instruction_read_4);
    
    //multiplex the regfile write data port
    assign regfile_write_data = (instruction_read_4[6:0] == l_i_type) ? data_read_masked : regfile_write_alu;

    //update pipeline registers
    always_ff @(posedge clk) begin
        instruction_read_5 <= instruction_read_4;
    end //always_ff
    
    //////////////////////////////////////////////////////////     
    ///                 Forwarding
    //in case the regfile hasn't been written to yet
    
    always_comb begin
        alu_in_b = alu_in_b_norm;
        alu_in_a = alu_in_a_norm;
        //forwarding alu_in_b
        if(takes_b(instruction_read_2)) begin
            if(instruction_read_4[11:7] == instruction_read_2[24:20] && 
                instruction_read_4[6:0] == l_i_type && instruction_read_2[24:20] != 5'b0) begin
                
                alu_in_b = data_read; 
            end
            else if(instruction_read_3[11:7] == instruction_read_2[24:20] && instruction_read_2[24:20] != 5'b0) begin
                if(!is_branch_store(instruction_read_3)) alu_in_b = alu_out_reg; //previous target is b
            end 
            else if(instruction_read_4[11:7] == instruction_read_2[24:20] && instruction_read_2[24:20] != 5'b0) begin
                 if(!is_branch_store(instruction_read_4)) alu_in_b = regfile_write_alu; //previous previous target is b
            end else alu_in_b = alu_in_b_norm;
        end
        else alu_in_b = alu_in_b_norm;
        
        //forwarding alu_in_a
        if(takes_a(instruction_read_2)) begin
            if(instruction_read_4[11:7] == instruction_read_2[19:15] && 
                instruction_read_4[6:0] == l_i_type && instruction_read_2[19:15] != 5'b0) begin
                
                alu_in_a = data_read;         //using a recently stored piece of data
            end
            else if (instruction_read_3[11:7] == instruction_read_2[19:15] && instruction_read_2[19:15] != 5'b0) begin
                if(!is_branch_store(instruction_read_3)) alu_in_a = alu_out_reg; //previoustarget is a
            end
            else if(instruction_read_4[11:7] == instruction_read_2[19:15] && instruction_read_2[19:15] != 5'b0) begin
                if(!is_branch_store(instruction_read_4)) alu_in_a = regfile_write_alu; //previous previous target is a
            end
            else alu_in_a = alu_in_a_norm;
        end 
        else alu_in_a = alu_in_a_norm;
        
        //forwarding the data write port
        data_write = regfile_out_b_reg_reg;
        if(instruction_read_3[6:0] == s_type && instruction_read_4[11:7] == instruction_read_3[24:20]) begin
            if(!is_branch_store(instruction_read_4)) data_write = regfile_write_data; 
        end else if(instruction_read_3[6:0] == s_type && instruction_read_5[11:7] == instruction_read_3[24:20]) begin
            if(!is_branch_store(instruction_read_5)) data_write = regfile_write_data_last; 
        end
        
        //forwarding the branch condition eval values
        branch_forward_a = regfile_out_a;
        branch_forward_b = regfile_out_b;
        
        if(instruction_read_2[6:0] == b_type || instruction_read_2[6:0] == j_i_type || 
            instruction_read_2[6:0] == j_type) begin
        
            if (instruction_read_3[11:7] == instruction_read_2[19:15]) begin
                if(!is_branch_store(instruction_read_3)) branch_forward_a = alu_out_reg; //previous target is a
            end
            else if(instruction_read_4[11:7] == instruction_read_2[19:15]) begin
                if(!is_branch_store(instruction_read_4)) begin
                    if(instruction_read_4[6:0] == l_i_type) branch_forward_a = data_read_masked;
                    else branch_forward_a = regfile_write_data; //previous previous target is a
                end else branch_forward_a = regfile_out_a_reg;
            end
            else branch_forward_a = regfile_out_a_reg;
            
            
            if (instruction_read_3[11:7] == instruction_read_2[24:20]) begin
                if(!is_branch_store(instruction_read_3)) branch_forward_b = alu_out_reg; //previous target is b
            end
            else if(instruction_read_4[11:7] == instruction_read_2[24:20]) begin
                if(!is_branch_store(instruction_read_4)) begin 
                    if(instruction_read_4[6:0] == l_i_type) branch_forward_b = data_read_masked;
                    else branch_forward_b = regfile_write_data; //previous previous target is a
                end else branch_forward_b = regfile_out_b_reg;
            end
            else branch_forward_b = regfile_out_b_reg;
        end
        
    end //always_comb
    
    //////////////////////////////////////////////////////////     
    ///                 Stalling
    //in case the regfile hasn't been written to yet
    always_comb begin
        stall = !data_ready;
        if(instruction_read_2[6:0] == l_i_type) begin
            if (!(instruction_read[6:0] == j_type)) begin
                if(instruction_read_2[11:7] == instruction_read[19:15] ||
                   instruction_read_2[11:7] == instruction_read[24:20]) begin
                    stall = 1'b1;
                end
            end
        end
    end
    
endmodule //riscv32
