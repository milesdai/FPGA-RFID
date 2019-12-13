module pulse(
    input clock,
    input signal,
    output pulsed_signal
    );
    
    logic old_signal;
    assign pulsed_signal = (old_signal == 0) & (signal == 1);
    
    always_ff @ (posedge clock) begin
        old_signal <= signal;
    end
    
endmodule



module debounce (input reset_in, clock_in, noisy_in,
                 output logic clean_out);

   logic [4:0] count;
   logic new_input;

   always_ff @(posedge clock_in)
     if (reset_in) begin 
        new_input <= noisy_in; 
        clean_out <= noisy_in; 
        count <= 0; end
     else if (noisy_in != new_input) begin new_input<=noisy_in; count <= 0; end
     else if (count >= 5) clean_out <= new_input;
     else count <= count+1;
     
endmodule