//converts entire 194 bits into ascii. later on, can index in
module bits_to_ascii(
    input  logic [193:0] bits_in,
    output logic [8*194-1:0] ascii_out
    );
    
    parameter ASCII_0 = 8'b00110000;
    parameter ASCII_1 = 8'b00110001;
    parameter MAX_BITS = 194; //at most 64 characters per line
 
    always @ (*) begin
        for (int n=0 ; n< MAX_BITS ; n++) begin
            ascii_out[8*n +: 8] <= (bits_in[n] == 1) ? ASCII_1 : ASCII_0; 
         end
    end
    
endmodule