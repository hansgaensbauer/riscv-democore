`timescale 1ns / 1ps

//a uart transmitter for serial io
module uart(
    input [7:0] tx_data,
    input tx_data_ready,
    output txd,
    input hs_clk,
    output xfer_done
    );
    
    localparam baud_period = 1250; //input clock speed divided by baud rate (12e6/9600 = 1250)
    localparam packet_length = 13; //1 start bit, 8 data bits, 2 padding bits, 2 delay bits
    
    enum {ready, busy, done} ps, ns; //states
    
    //data shift register
    logic [packet_length:0] packet;
    
    //shift counter
    logic [3:0] shift_counter;
    
    //clock divider
    logic [10:0] clock_divider;
    logic bit_clock;                //bit clock pulses to trigger a shift
    
    //next state
    always_comb begin
        ns = ready;
        case(ps)
            ready: ns = tx_data_ready ? busy : ready;
            busy: ns = (shift_counter == 4'b0) ? done : busy;
            done: ns = (tx_data_ready) ? done : ready;
        endcase
    end //always_comb
    
    //shifting out
    always_ff @(posedge hs_clk) begin
        if(ps == ready) begin
            packet <= {4'b1111, tx_data, 2'b01}; //assemble the UART packet
            shift_counter <= packet_length;      //NOTE: the 1's on either side guarantee that txd starts and ends high even if you're slow with tx_data_ready
            clock_divider <= baud_period;
        end else if(ps != done) begin
            if(clock_divider == 11'b0)
                clock_divider <= baud_period;
            else
                clock_divider <= clock_divider - 1'b1;
        end
        
        if(bit_clock && (ps == busy)) begin
            packet <= packet >> 1'b1;
            shift_counter <= shift_counter - 1'b1;
        end
        ps <= ns;
    end //always_ff
    
    assign bit_clock = (clock_divider == 11'b0);
    
    assign txd = packet[0]; //tx pin
    assign xfer_done = (ps == ready || ps == done);
    
endmodule //uart