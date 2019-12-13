module reader(
    input comparator_in,
    input clk_in,
    input reset_in,
    input [3:0] addr_in,
    input record_in,
    output logic [193:0] id_bits_out,
    output logic id_ready_out
);
    logic pulse;
    logic bit_ready;
    logic current_bit;
    pulse_gen comparator_cleanup(.comparator_in(comparator_in), 
                                 .clk_in(clk_in), 
                                 .reset_in(reset_in), 
                                 .pulse_out(pulse));
    parser comparator_parser(.pulse_in(pulse), 
                             .clk_in(clk_in), 
                             .reset_in(reset_in), 
                             .bit_ready_out(bit_ready), 
                             .current_bit_out(current_bit));
    read_fsm fsm(.bit_ready_in(bit_ready), 
                 .sent_bit_in(current_bit), 
                 .reset_in(reset_in), 
                 .clk_in(clk_in), 
                 .id_out(id_bits_out), 
                 .id_ready_out(id_ready_out));
    
endmodule

module record(
    input [3:0] addr,
    input record_in, // Signal to record
    input [193:0] id_bits_in, // id number to record
    input id_ready_in, // id number ready signal from the reader module
    input clk_in, 
    input reset_in,
    output logic [193:0] data_to_bram_out,
    output logic bram_write_out
);
    // Continuously stores IDs being emitted from the reader module and stores in internal register
    // This allows for instantaneous recording when the button is pressed.
    parameter S_IDLE = 0;
    parameter S_RECORD = 1;
    
    logic state = S_IDLE;
    logic [193:0] last_valid_id_num = 0;
    
    always_ff @(posedge clk_in) begin
        case(state)
            S_IDLE: begin
                bram_write_out <= 0; // ensure one cycle pulse
                if(record_in) begin
                    state <= S_RECORD;
                end
                if(id_ready_in) begin
                    last_valid_id_num <= id_bits_in;
                end
            end
            S_RECORD: begin
                data_to_bram_out <= last_valid_id_num;
                bram_write_out <= 1;
                state <= S_IDLE;
            end
            default: begin
                state <= S_IDLE;
                bram_write_out <= 0;
                last_valid_id_num <= 0;
            end
        endcase
    end
endmodule

/*
parser receives the raw pulse data from the comparator and determines if a bit has been sent
*/
module parser(
    input pulse_in, // Assumed to be a single clock cycle pulse
    input clk_in,
    input reset_in,
    output logic bit_ready_out,
    output logic current_bit_out
);
    parameter RFID_FREQ = 125000; // This needs to be tuned depending on the coil for optimal performance
    
    parameter PULSE_PER_BIT = 16;
//    parameter CYCLES_PER_PULSE = 2 * 100000000 / RFID_FREQ; //1600; // 1 / 62.5kHz * 100MHz = 1600 clock cycles per pulse
    parameter CYCLES_PER_PULSE = 1600;     
    parameter CYCLE_COUNT_ERROR = 100; // allowable tolerance on the period
    logic [4:0] pulse_count; // count the number of pulses detected
    logic [11:0] cycle_count; // longest expected duration between pulses is 2400 cycles (1.5 * period) 
        
    // Every 16 pulses, output one bit
    always_ff @(posedge clk_in) begin
        if(bit_ready_out) begin
            bit_ready_out <= 0; // ensure bit_ready_out is one pulse wide
        end
        if(pulse_in) begin
            // Check for phase shift
            if(cycle_count > CYCLES_PER_PULSE + CYCLE_COUNT_ERROR || 
                cycle_count < CYCLES_PER_PULSE - CYCLE_COUNT_ERROR) begin
                current_bit_out <= current_bit_out ^ 1'b1; // toggle current_bit_out
            end
            // Check if a bit has been sent
            if(pulse_count == PULSE_PER_BIT - 1) begin
                pulse_count <= 0;
                bit_ready_out <= 1; // tell next module that a bit is ready to be read
            end else begin
                pulse_count <= pulse_count + 1;
            end
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
        end
        
        if(reset_in) begin
            pulse_count <= 0;
            current_bit_out <= 0;
            bit_ready_out <= 0;
        end
    end

endmodule

/* Receives the output from the comparator. Needs to create a sharp transistion and an output pulse with one clock cycle width */
module pulse_gen(
    input comparator_in,
    input clk_in,
    input reset_in,
    output logic pulse_out
);
    logic prev_input;
    logic [4:0] input_buffer; 
    always_ff @(posedge clk_in) begin
        if(pulse_out) begin
            pulse_out <= 0; // Guarantee one-cycle long pulse
        end
        input_buffer <= {comparator_in, input_buffer[4:1]};
        // Wait until the entire buffer agrees before accepting the bit since the comparator is slow
        if(input_buffer == 5'b11111 || input_buffer == 0) begin
            prev_input <= input_buffer[0];
            // Check for falling edge
            if(input_buffer[0] == 0 && prev_input == 1) begin
                pulse_out <= 1;
            end
        end 
        if(reset_in) begin
            pulse_out <= 0;
            prev_input <= 0;
        end
    end
endmodule

module read_fsm(input bit_ready_in,
                input sent_bit_in,
                input clk_in,
                input reset_in,
                output logic [193:0] id_out,
                output logic id_ready_out);
    
    // Hyperparameters
    parameter CONSEC_BIT_THRESHOLD = 25; // Detect 25 consecutive bits before transitioning to triggered
    parameter NUM_CONST_1 = 22;
    parameter NUM_PERSONAL = 33;
    parameter NUM_CONST_2 = 139;
    
    // States
    parameter S_IDLE = 0;
    parameter S_TRIGGERED = 1;
    parameter S_CONSTANT_1 = 2;
    parameter S_PERSONAL = 3;
    parameter S_CONSTANT_2 = 4;
    
    logic [2:0] state = S_IDLE;
    logic parity = 0; // There's a chance all the bits are flipped. XOR inputs with this parity bit to fix this
    logic input_bit;
    assign input_bit = parity ^ sent_bit_in;
    logic prev_bit;
    logic [7:0] bit_count;
    
    always_ff @(posedge clk_in) begin
        if(reset_in) begin
            state <= S_IDLE;
            prev_bit <= 0;
            bit_count <= 0;
            parity <= 0;
            id_ready_out <= 0;
            id_out <= 0;
        end else if(bit_ready_in) begin
            case(state)
                S_IDLE: begin
                    // Look for consecutive string of same bit
                    id_ready_out <= 0; // Clear the bit if already set from a previous run
                    bit_count <= input_bit == prev_bit ? bit_count + 1 : 0;
                    prev_bit <= input_bit;
                    if(bit_count > CONSEC_BIT_THRESHOLD) begin
                        state <= S_TRIGGERED;
                        if(input_bit == 1) begin
                            // If a string of ones is detected, flip parity bit (we are backwards)
                            parity <= 1;
                        end
                    end
                end
                S_TRIGGERED: begin
                    // Wait for first one
                    if(input_bit == 1) begin
                        id_out[0] <= 1;
                        bit_count <= 1;
                        state <= S_CONSTANT_1;
                    end
                end
                S_CONSTANT_1: begin
                    if(bit_count == 11 && id_out[9:0] != 10'b0111000001) begin // invalid, reject
                        state <= S_IDLE;
                        bit_count <= 0;
                        parity <= 0;
                        prev_bit <= 0;
                    end
                    id_out[bit_count] <= input_bit;
                    bit_count <= bit_count + 1;
                    if(bit_count == NUM_CONST_1 - 1) begin
                        state <= S_PERSONAL;
                    end
                end
                S_PERSONAL: begin
                    id_out[bit_count] <= input_bit;
                    bit_count <= bit_count + 1;
                    if(bit_count == NUM_PERSONAL + NUM_CONST_1 - 1) begin
                        state <= S_CONSTANT_2;
                    end
                end
                S_CONSTANT_2: begin
                    id_out[bit_count] <= input_bit;
                    bit_count <= bit_count + 1;
                    if(bit_count == NUM_PERSONAL + NUM_CONST_1 + NUM_CONST_2 - 1) begin
                        state <= S_IDLE;
                        id_ready_out <= 1;
                        bit_count <= 0;
                        parity <= 0;
                        prev_bit <= 0;
                    end
                end
                default:
                    state <= S_IDLE;
            endcase
        end
    end
endmodule
