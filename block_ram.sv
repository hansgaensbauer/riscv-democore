// Block RAM, write first, byte write enables
// As outlined at https://www.xilinx.com/support/documentation/sw_manuals/xilinx2017_1/ug901-vivado-synthesis.pdf

module block_ram #(parameter init_value_file = "code.txt") (clk, en, we, addr, di, dout);
    input clk; 
    input en; 
    input [3:0] we; 
    input [9:0] addr; 
    input [31:0] di; 
    output logic [31:0] dout;
    
    logic [31:0] RAM [1023:0];
    
    initial begin //initial values in the ram
        $readmemh(init_value_file, RAM);
    end
    
    always_ff @(posedge clk) begin
        if (en)  begin
            if (we[0]) RAM[addr][7:0] <= di[7:0];
            if (we[1]) RAM[addr][15:8] <= di[15:8];
            if (we[2]) RAM[addr][23:16] <= di[23:16];
            if (we[3]) RAM[addr][31:24] <= di[31:24];
            dout <= RAM[addr];  
        end //if
    end //always_ff

endmodule //block_ram
