module top_level(
    input clk_100mhz,
    output logic[15:0] led
    );
    
    logic [26:0] counter = 27'b0;
    always_ff @(posedge clk_100mhz) begin
        counter <= counter + 2;
    end
    
    assign led[0] = counter[26];
endmodule
