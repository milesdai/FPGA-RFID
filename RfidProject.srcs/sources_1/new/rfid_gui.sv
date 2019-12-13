////////////////////////////////////////////////////////////////////////////////
//
// RFID GUI
//
// sw[15] == 1 for SPOOF; 0 for READ
////////////////////////////////////////////////////////////////////////////////

module rfid_gui (
   input vclock_in,        // 65MHz clock
   input reset_in,         // 1 to initialize module
   input up_in,            // 
   input down_in,          // 
   input left_in,
   input right_in,
   input is_spoof_display,  //connected to sw[15]
   input [3:0] save_addr,         //connected to sw[3:0], location to save bits to in bram
   input [193:0] read_module_bits,
   
   input [10:0] hcount_in, // horizontal index of current pixel (0..1023)
   input [9:0]  vcount_in, // vertical index of current pixel (0..767)
   input hsync_in,         // XVGA horizontal sync signal (active low)
   input vsync_in,         // XVGA vertical sync signal (active low)
   input blank_in,         // XVGA blanking (1 means output black pixel)
        
   output phsync_out,       // pong game's horizontal sync
   output pvsync_out,       // pong game's vertical sync
   output pblank_out,       // pong game's blanking
   output logic [11:0] pixel_out,  // pong game's pixel  // r=11:8, g=7:4, b=3:0
   input [193:0] data_from_bram,
   output logic [193:0] data_to_bram,
   output logic [3:0] addr,
   output logic write_to_bram,
   output logic [193:0] bits_to_spoof_out
   );
   
   assign phsync_out = hsync_in;
   assign pvsync_out = vsync_in;
   assign pblank_out = blank_in;
   
   /////// BIT CODE THINGS /////////
   parameter MIT_BITS = 22'b0110100001100111000001;
   
   ///////
   /////// Pulse UI Buttons //////////
   logic up_pulse;
   pulse_65mhz my_up_pulse (.clock_in(vclock_in), .signal_in(up_in), .pulse_out(up_pulse));
   logic down_pulse;
   pulse_65mhz my_down_pulse (.clock_in(vclock_in), .signal_in(down_in), .pulse_out(down_pulse));
   logic left_pulse;
   pulse_65mhz my_left_pulse (.clock_in(vclock_in), .signal_in(left_in), .pulse_out(left_pulse));
   logic right_pulse;
   pulse_65mhz my_right_pulse (.clock_in(vclock_in), .signal_in(right_in), .pulse_out(right_pulse));
   /////////////////////////////////////////
   
    parameter BITS_IN_BRAM = 194;                                  
    logic [BITS_IN_BRAM-1:0] ascii_module_in;
    logic [8*BITS_IN_BRAM-1: 0] ascii_module_out;
    bits_to_ascii my_bits_to_ascii(.bits_in(ascii_module_in), .ascii_out(ascii_module_out));
    
    
   ///// SWITCHES TO NUMBER ////
   logic [15:0] save_addr_ascii; 
   
   ////// FONT MODULE ///////
   logic [64*8-1:0] char_string;
   logic [10:0] string_start_x;
   logic [9:0] string_start_y;
   logic [6:0] line_number; //can fit 32 lines on the screen but line_number will count up to the blank vsync interval
   assign line_number = vcount_in/24; //text heigh is 24 pixels so line number is module 24
   assign string_start_y = line_number * 24;
   logic coe_pixel_out;
   parameter CHARS_PER_LINE = 64; //at most 64 characters per line
   char_string_display read_spoof_display(.vclock(vclock_in), .hcount(hcount_in), .vcount(vcount_in), .pixel(coe_pixel_out), .cstring(char_string), .cx(string_start_x), .cy(string_start_y));
/////////////////////////////////////////////////////////////////

////////////////////////////
////// ASCII 
////////////////////////////////
    parameter SPOOF_ASCII = 40'b0101001101010000010011110100111101000110;
    parameter READ_ASCII = 32'b01010010010001010100000101000100;
    parameter ASCII_0 = 8'b00110000;
    parameter ASCII_1 = 8'b00110001;
    parameter ASCII_SPACE = 8'b00100000;
    parameter ASCII_COLON = 8'b00111010;
    parameter ASCII_BITS_TEXT = 48'b011000100110100101110100011100110011101000100000; // "bits: "
    parameter ASCII_ID = 32'b01001001010001000011101000100000;//"ID: "
    parameter ASCII_NOT_REC = 112'b0110111001101111011101000010000001110010011001010110001101101111011001110110111001101001011110100110010101100100; //"not recognized"
    parameter ASCII_MIT = 24'b010011010100100101010100;// "MIT"
    parameter ASCII_POUND = 16'b0010001100100000; //"# "
    parameter ASCII_EMPTY = 40'b0110010101101101011100000111010001111001; //"empty"
    parameter ASCII_SAVE_AS = 112'b0111001101100001011101100110010100100000010010010100010000100000011000010111001100100000001000110011101000100000; //"save ID as #: "
/////////////////////////////////

    //logic old_hsync_in;
    
    logic [3:0] selected_id; // 16 IDs in bram to select from using up and down arrow keys
    logic [3:0] displayed_id;
    logic verbose_mode;
    
    always_ff @ (posedge vclock_in) begin
    
    /// CLOCKED SPOOF LOGIC 
    if (is_spoof_display == 1) begin
            write_to_bram <= 0;
            ascii_module_in <= data_from_bram;
            addr <= displayed_id; //will change as hcount and vcount change
            
            if (displayed_id == selected_id) begin
                bits_to_spoof_out <= data_from_bram;
            end
            if (reset_in) begin
                string_start_x <= 0;
                selected_id <= 0;
                verbose_mode <= 0;
            
            // keep track of state of selected ID    
            end else if (up_pulse) begin
                if (selected_id > 0) selected_id <= selected_id - 1;
            end else if (down_pulse) begin
                if (selected_id < 15) selected_id <= selected_id + 1;
                
            end else if (right_pulse) begin
                verbose_mode <= 1;
            end else if (left_pulse) begin
                verbose_mode <= 0;
            end
            
            if (line_number == 0) begin
                pixel_out = 12'hFFF*coe_pixel_out;
            end else if ((2*selected_id+1) == line_number) begin
                pixel_out = ~(12'hFFF*coe_pixel_out);
            end
            else begin
                pixel_out = 12'hFFF*coe_pixel_out;
            end
                
      ///// CLOCKED READ LOGIC
        
      end else begin
           ascii_module_in <= read_module_bits;
           addr <= save_addr;
           //save_addr switches to ascii
           case(save_addr) 
                4'b0000: save_addr_ascii <= ASCII_0+8'd0;
                4'b0001: save_addr_ascii <= ASCII_0+8'd1;
                4'b0010: save_addr_ascii <= ASCII_0+8'd2;
                4'b0011: save_addr_ascii <= ASCII_0+8'd3;
                4'b0100: save_addr_ascii <= ASCII_0+8'd4;
                4'b0101: save_addr_ascii <= ASCII_0+8'd5;
                4'b0110: save_addr_ascii <= ASCII_0+8'd6;
                4'b0111: save_addr_ascii <= ASCII_0+8'd7;
                4'b1000: save_addr_ascii <= ASCII_0+8'd8;
                4'b1001: save_addr_ascii <= ASCII_0+8'd9;
                4'b1010: save_addr_ascii <= {ASCII_1,ASCII_0+8'd0};
                4'b1011: save_addr_ascii <= {ASCII_1,ASCII_0+8'd1};
                4'b1100: save_addr_ascii <= {ASCII_1,ASCII_0+8'd2};
                4'b1101: save_addr_ascii <= {ASCII_1,ASCII_0+8'd3};
                4'b1110: save_addr_ascii <= {ASCII_1,ASCII_0+8'd4};
                4'b1111: save_addr_ascii <= {ASCII_1,ASCII_0+8'd5};
            endcase
          
          if (right_pulse == 1) begin //write to bram
               write_to_bram <= 1;
          end else begin //don't write to bram, just display
               write_to_bram <= 0;
              if ((line_number == 7) & (right_in == 1)) begin     
                            pixel_out = ~(12'hFFF*coe_pixel_out);            
              end else begin
                  pixel_out = 12'hFFF*coe_pixel_out;
              end
         end
        
     end
    
    end
    
    // combinational logic determines 
    // 1) based on line number, what text should be, 
    // 2) what the color of pixel_out should be by feeding char_string through cstringdisplay.v to produce coe_pixel_out
    // 3) pixel_out based on coe_pixel_out
    // uses combinational logic on hcount_in and vcount_into determine what the element to be displayed is
    
    always_comb begin
        ////////// //SPOOF DISPLAY //////////////
        if (is_spoof_display == 1) begin
            //generate ascii for each line -- display rom text on odd lines in non verbose mode
            displayed_id = (line_number - 1) >> 1; //which ID is currently displayed
            
                 
            //ascii_module
            
            //ascii string to display
            case (line_number)
                0: char_string = SPOOF_ASCII;
                1: char_string  = {ASCII_0,ASCII_COLON,ASCII_SPACE,ascii_module_out[55*8-1:0]};
                3: char_string  = {ASCII_0+8'd1,ASCII_COLON,ASCII_SPACE,ascii_module_out[55*8-1:0]};
                5: char_string  = {ASCII_0+8'd2,ASCII_COLON,ASCII_SPACE,ascii_module_out[55*8-1:0]};
                7: char_string  = {ASCII_0+8'd3,ASCII_COLON,ASCII_SPACE,ascii_module_out[55*8-1:0]};
                9: char_string  = {ASCII_0+8'd4,ASCII_COLON,ASCII_SPACE,ascii_module_out[55*8-1:0]};
                11: char_string  = {ASCII_0+8'd5,ASCII_COLON,ASCII_SPACE,ascii_module_out[55*8-1:0]};
                13: char_string  = {ASCII_0+8'd6,ASCII_COLON,ASCII_SPACE,ascii_module_out[55*8-1:0]};
                15: char_string  = {ASCII_0+8'd7,ASCII_COLON,ASCII_SPACE,ascii_module_out[55*8-1:0]};
                17: char_string  = {ASCII_0+8'd8,ASCII_COLON,ASCII_SPACE,ascii_module_out[55*8-1:0]};
                19: char_string  = {ASCII_0+8'd9,ASCII_COLON,ASCII_SPACE,ascii_module_out[55*8-1:0]};
                21: char_string  = {ASCII_1,ASCII_0,ASCII_COLON,ASCII_SPACE,ascii_module_out[55*8-1:0]};
                23: char_string  = {ASCII_1,ASCII_0+8'd1,ASCII_COLON,ASCII_SPACE,ascii_module_out[55*8-1:0]};
                25: char_string  = {ASCII_1,ASCII_0+8'd2,ASCII_COLON,ASCII_SPACE,ascii_module_out[55*8-1:0]};
                27: char_string  = {ASCII_1,ASCII_0+8'd3,ASCII_COLON,ASCII_SPACE,ascii_module_out[55*8-1:0]};
                29: char_string  = {ASCII_1,ASCII_0+8'd4,ASCII_COLON,ASCII_SPACE,ascii_module_out[55*8-1:0]};
                31: char_string  = {ASCII_1,ASCII_0+8'd5,ASCII_COLON,ASCII_SPACE,ascii_module_out[55*8-1:0]};
                default: char_string  = 0;
            endcase
            
        end
            
            
        ////////is_spoof_display==0 for READ DISPLAY///////////    
        else begin            
           
            //ascii

            data_to_bram = read_module_bits;
        //// display 
             case (line_number)
                0: char_string = READ_ASCII;
                3: char_string = {ASCII_BITS_TEXT, ascii_module_out[55*8-1:0]}; //print out 22 MIT and 33 personal from left to right
                5: begin
                    if (read_module_bits[21:0] == MIT_BITS) begin
                        char_string = {ASCII_ID, ASCII_MIT}; //add information about whether the ID is mit, unidentified or stored in the bram
                    end else begin
                        char_string = {ASCII_ID, ASCII_NOT_REC};
                    end
                end
                7: char_string = {ASCII_SAVE_AS, save_addr_ascii};
                default: char_string = 0;
            endcase
        end
        
        
    end
    
    
    //ila_0 myila(.clk(vclock_in), .probe0(hsync_in), .probe1(vsync_in), .probe2(hcount_in), .probe3(pixel_out), .probe4(puck_center_x), .probe5(puck_center_y));
     
    endmodule
    
    module synchronize #(parameter NSYNC = 3)  // number of sync flops.  must be >= 2
                   (input clk,in,
                    output reg out);
    
    reg [NSYNC-2:0] sync;
    
    always_ff @ (posedge clk)
    begin
        {out,sync} <= {sync[NSYNC-2:0],in};
    end
endmodule

///////////////////////////////////////////////////////////////////////////////
//
// Rising Edge Pulse
//
///////////////////////////////////////////////////////////////////////////////

module pulse_65mhz (input clock_in, input signal_in, output pulse_out);

    logic old_signal_in;
    assign pulse_out = (old_signal_in == 0) & (signal_in == 1);
    always_ff @(posedge clock_in) begin
        old_signal_in <= signal_in;
    end
endmodule



///////////////////////////////////////////////////////////////////////////////
//
// Pushbutton Debounce Module (video version - 24 bits)  
//
///////////////////////////////////////////////////////////////////////////////

module debounce_65mhz (input reset_in, clock_in, noisy_in,
                 output reg clean_out);

   reg [19:0] count;
   reg new_input;

   always_ff @(posedge clock_in)
     if (reset_in) begin 
        new_input <= noisy_in; 
        clean_out <= noisy_in; 
        count <= 0; end
     else if (noisy_in != new_input) begin new_input<=noisy_in; count <= 0; end
     else if (count == 1000000) clean_out <= new_input;
     else count <= count+1;


endmodule

//////////////////////////////////////////////////////////////////////////////////
// Update: 8/8/2019 GH 
// Create Date: 10/02/2015 02:05:19 AM
// Module Name: xvga
//
// xvga: Generate VGA display signals (1024 x 768 @ 60Hz)
//
//                              ---- HORIZONTAL -----     ------VERTICAL -----
//                              Active                    Active
//                    Freq      Video   FP  Sync   BP      Video   FP  Sync  BP
//   640x480, 60Hz    25.175    640     16    96   48       480    11   2    31
//   800x600, 60Hz    40.000    800     40   128   88       600     1   4    23
//   1024x768, 60Hz   65.000    1024    24   136  160       768     3   6    29
//   1280x1024, 60Hz  108.00    1280    48   112  248       768     1   3    38
//   1280x720p 60Hz   75.25     1280    72    80  216       720     3   5    30
//   1920x1080 60Hz   148.5     1920    88    44  148      1080     4   5    36
//
// change the clock frequency, front porches, sync's, and back porches to create 
// other screen resolutions
////////////////////////////////////////////////////////////////////////////////

module xvga(input vclock_in,
            output reg [10:0] hcount_out,    // pixel number on current line
            output reg [9:0] vcount_out,     // line number
            output reg vsync_out, hsync_out,
            output reg blank_out);

   parameter DISPLAY_WIDTH  = 1024;      // display width
   parameter DISPLAY_HEIGHT = 768;       // number of lines

   parameter  H_FP = 24;                 // horizontal front porch
   parameter  H_SYNC_PULSE = 136;        // horizontal sync
   parameter  H_BP = 160;                // horizontal back porch

   parameter  V_FP = 3;                  // vertical front porch
   parameter  V_SYNC_PULSE = 6;          // vertical sync 
   parameter  V_BP = 29;                 // vertical back porch

   // horizontal: 1344 pixels total
   // display 1024 pixels per line
   reg hblank,vblank;
   wire hsyncon,hsyncoff,hreset,hblankon;
   assign hblankon = (hcount_out == (DISPLAY_WIDTH -1));    
   assign hsyncon = (hcount_out == (DISPLAY_WIDTH + H_FP - 1));  //1047
   assign hsyncoff = (hcount_out == (DISPLAY_WIDTH + H_FP + H_SYNC_PULSE - 1));  // 1183
   assign hreset = (hcount_out == (DISPLAY_WIDTH + H_FP + H_SYNC_PULSE + H_BP - 1));  //1343

   // vertical: 806 lines total
   // display 768 lines
   wire vsyncon,vsyncoff,vreset,vblankon;
   assign vblankon = hreset & (vcount_out == (DISPLAY_HEIGHT - 1));   // 767 
   assign vsyncon = hreset & (vcount_out == (DISPLAY_HEIGHT + V_FP - 1));  // 771
   assign vsyncoff = hreset & (vcount_out == (DISPLAY_HEIGHT + V_FP + V_SYNC_PULSE - 1));  // 777
   assign vreset = hreset & (vcount_out == (DISPLAY_HEIGHT + V_FP + V_SYNC_PULSE + V_BP - 1)); // 805

   // sync and blanking
   wire next_hblank,next_vblank;
   assign next_hblank = hreset ? 0 : hblankon ? 1 : hblank;
   assign next_vblank = vreset ? 0 : vblankon ? 1 : vblank;
   always_ff @(posedge vclock_in) begin
      hcount_out <= hreset ? 0 : hcount_out + 1;
      hblank <= next_hblank;
      hsync_out <= hsyncon ? 0 : hsyncoff ? 1 : hsync_out;  // active low

      vcount_out <= hreset ? (vreset ? 0 : vcount_out + 1) : vcount_out;
      vblank <= next_vblank;
      vsync_out <= vsyncon ? 0 : vsyncoff ? 1 : vsync_out;  // active low

      blank_out <= next_vblank | (next_hblank & ~hreset);
   end
endmodule