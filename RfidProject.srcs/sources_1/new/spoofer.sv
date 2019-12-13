module spoofer(
        input clk_in,
        input reset_in, //center button for reset
        input card_reader_in, // ready-signal from incoming 125kHz wave
        input [193:0] card_bits_in, // data bits to spoof ([193:0])
        output logic mosfet_control_out // mosfet state
    );
    
    //mosfet output signal
    logic spoof_out; // mosfet state
    assign mosfet_control_out = spoof_out;
    
    parameter NUM_BITS = 224;
    logic[NUM_BITS-1: 0] data_in; 
    assign data_in = {30'b0, card_bits_in}; // prepend 30 zeros to the front of the data bits
    logic[NUM_BITS-1:0] cyclic_data_in;
    
    logic [4:0] cycles_per_bit_count; //5 bits so 32 cycles per bit
    
    logic [3:0] card_reader_buffer; //incoming data
    logic card_reader_noisy; //buffered
    logic card_reader_clean; //buffered and debounced
    debounce card_reader_noisy_debounce (.reset_in(reset_in), .clock_in(clk_in), .noisy_in(card_reader_noisy) ,
                 .clean_out(card_reader_clean));
    logic card_reader_pulse; //true on rising edge
    pulse my_card_reader_pulse (.clock(clk_in), .signal(card_reader_clean), .pulsed_signal(card_reader_pulse)); //pulse the clean debounced signal

    logic [7:0] current_bit_loc;
    parameter MAX_LOC = 223;
    logic currentBit; //MSB of cyclic_data_in
    logic previousBit; //previous MSB of cyclic_data_in
    assign currentBit = data_in[current_bit_loc];
    
    always_ff @(posedge clk_in) begin
        if (reset_in) begin //reset and initialize
            spoof_out <= 0;
            cycles_per_bit_count <= 1;
            previousBit <= currentBit;
            card_reader_buffer <= 4'b0;
            card_reader_noisy <= 0;
            current_bit_loc <= 0;
        end
        
        else begin
            if (card_reader_pulse) begin //determine spoof_out
                if (cycles_per_bit_count == 0) begin //move to next bit
               
                    //if bit flip from previous to current, phase shift implies spoof_out remains the same
                    spoof_out <= (previousBit != currentBit) ? spoof_out : !spoof_out;
                
                    //get the next bit and bit shift cyclic_data_in
                    previousBit <= currentBit;
                    current_bit_loc <= (current_bit_loc == MAX_LOC) ? 0: current_bit_loc + 1; //bit shifting cyclic_data_in will pop the MSB
                end
                 
                else begin
                    spoof_out <= !spoof_out;
                end
                
                cycles_per_bit_count <= cycles_per_bit_count + 1;
            end
           
            card_reader_noisy <= (card_reader_buffer >> 3);
            card_reader_buffer <= (card_reader_buffer << 1) + card_reader_in;
        end
    end
        
endmodule


//module spoof_module(
//        input clk_100mhz,
//        input logic btnc, //center button for reset
//        input logic [0:0] ja, //card_reader_in:  ready-signal from incoming 125kHz wave
//        output logic [0:0] jb //spoof_out:  mosfet state
//    );

    
//    //mosfet output signal
//    logic spoof_out; // mosfet state
//    assign jb = spoof_out;
    
//    logic[29:0] consecutive_bits;
//    assign consecutive_bits = 30'b0;
   
//    logic[21:0] constant_bits;
//    assign constant_bits = 22'b1000001110011000010110;
    
//    logic[32:0] personal_bits;
//    assign personal_bits = 33'b100000100001000010100010001001111; //hannah
////    // 33'b101010110101000010111000011110100 //miles
    
//    logic[138:0] trash_bits;
//    assign trash_bits = 139'b0101100010101101010000011001011100010110111001100011010101011101011110010010001000100111011110110010111001110110010001010011001111100011111; 
    
//    parameter NUM_BITS = 224;
//    logic[NUM_BITS-1: 0] data_in; 
//    assign data_in = {consecutive_bits, constant_bits, personal_bits, trash_bits};
//    logic[NUM_BITS-1:0] cyclic_data_in;
    
//    logic [2:0] cycles_per_bit_count; //5 bits so 32 cycles per bit
    
//    logic [3:0] card_reader_buffer; //incoming data
//    logic card_reader_noisy; //buffered
//    logic card_reader_clean; //buffered and debounced
//    debounce card_reader_noisy_debounce (.reset_in(btnc), .clock_in(clk_100mhz), .noisy_in(card_reader_noisy) ,
//                 .clean_out(card_reader_clean));
//    logic card_reader_pulse; //true on rising edge
//    pulse my_card_reader_pulse (.clock(clk_100mhz), .signal(card_reader_clean), .pulsed_signal(card_reader_pulse)); //pulse the clean debounced signal

//    logic currentBit; //MSB of cyclic_data_in
//    logic previousBit; //previous MSB of cyclic_data_in
//    assign currentBit = btnc ? (data_in >> (NUM_BITS - 1)) : (cyclic_data_in >> (NUM_BITS - 1));
    
//    always_ff @(posedge clk_100mhz) begin
//        if (btnc) begin //reset and initialize
//            cyclic_data_in <= data_in;
//            spoof_out <= 0;
//            cycles_per_bit_count <= 1;
//            previousBit <= currentBit;
//            card_reader_buffer <= 4'b0;
//            card_reader_noisy <= 0;
//        end
        
//        else begin
//            if (card_reader_pulse) begin //determine spoof_out
//                if (cycles_per_bit_count == 0) begin //move to next bit
               
//                    //if bit flip from previous to current, phase shift implies spoof_out remains the same
//                    spoof_out <= (previousBit != currentBit) ? spoof_out : !spoof_out;
                
//                    //get the next bit and bit shift cyclic_data_in
//                    previousBit <= currentBit;
//                    cyclic_data_in <= (cyclic_data_in << 1) + currentBit; //bit shifting cyclic_data_in will pop the MSB
//                end
                 
//                else begin
//                    spoof_out <= !spoof_out;
//                end
                
//                cycles_per_bit_count <= cycles_per_bit_count + 1;
//            end
           
//            card_reader_noisy <= (card_reader_buffer >> 3);
//            card_reader_buffer <= (card_reader_buffer << 1) + ja;
//        end
//    end
        
//endmodule