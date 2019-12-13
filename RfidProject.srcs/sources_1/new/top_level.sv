module top_level(
    input clk_100mhz,
    input [1:0] ja,
    output logic[0:0] jb,
    input [15:0] sw,    
    logic btnc, // reset
    logic btnd, // record
    logic btnu, btnl, btnr, // unassigned
    output[3:0] vga_r,
    output[3:0] vga_b,
    output[3:0] vga_g,
    output vga_hs,
    output vga_vs,
    output logic[15:0] led
    );
    
    logic record_btn;
    assign record_btn = btnd;
    
    // Declare BRAM
    logic [3:0] addr;
    logic [193:0] data_to_bram;
    logic [193:0] data_from_bram;
    logic bram_write;
    blk_mem_gen_0 bit_bram(.addra(addr), .clka(clk_100mhz), 
              .dina(data_to_bram), 
              .douta(data_from_bram), 
              .ena(1), .wea(bram_write));
    
    // Reader
    logic id_ready;
    logic [193:0] id_bits;
    reader card_reader(.comparator_in(ja[0]), 
                       .clk_in(clk_100mhz), 
                       .reset_in(sw[15]), // activate reader when sw[15] is low
                       .id_bits_out(id_bits), 
                       .id_ready_out(id_ready));

//    record id_recorder(.addr(addr),
//                       .record_in(record_btn),
//                       .id_bits_in(id_bits),
//                       .id_ready_in(id_ready),
//                       .clk_in(clk_100mhz),
//                       .reset_in(sw[15]),
//                       .data_to_bram_out(data_to_bram),
//                       .bram_write_out(bram_write));
    // Spoofer
    logic [193:0] bits_to_spoof;
    spoofer id_spoofer( .card_reader_in(ja[1]),
                        .card_bits_in(bits_to_spoof),
                        .clk_in(clk_100mhz),
                        .reset_in(!sw[15]), // activate spoofer when sw[15] is high
                        .mosfet_control_out(jb[0]));
    /////////////////////////////////////////////////////////                    
    // GUI
    // create 65mhz system clock, happens to match 1024 x 768 XVGA timing
    wire clk_65mhz;
    clk_wiz_0 clkdivider(.clk_in1(clk_100mhz), .clk_out1(clk_65mhz), .reset(0));
    
    wire [10:0] hcount;    // pixel on current line
    wire [9:0] vcount;     // line number
    wire hsync, vsync;
    wire [11:0] pixel;
    reg [11:0] rgb;    
    wire blank;
    xvga xvga1(.vclock_in(clk_65mhz),.hcount_out(hcount),.vcount_out(vcount),
          .hsync_out(hsync),.vsync_out(vsync),.blank_out(blank));
    
    
    // btnc button is user reset
    logic reset;
    debounce_65mhz db1(.reset_in(0),.clock_in(clk_65mhz),.noisy_in(btnc),.clean_out(reset));
   
    // UP and DOWN and LEFT and RIGHT for menu interface
    wire up,down,left,right;
    debounce_65mhz db2(.reset_in(reset),.clock_in(clk_65mhz),.noisy_in(btnu),.clean_out(up));
    debounce_65mhz db3(.reset_in(reset),.clock_in(clk_65mhz),.noisy_in(btnd),.clean_out(down));
    debounce_65mhz db4(.reset_in(reset),.clock_in(clk_65mhz),.noisy_in(btnl),.clean_out(left));
    debounce_65mhz db5(.reset_in(reset),.clock_in(clk_65mhz),.noisy_in(btnr),.clean_out(right));
    
    wire spoof_switch;
    debounce_65mhz db6(.reset_in(reset),.clock_in(clk_65mhz),.noisy_in(sw[15]),.clean_out(spoof_switch));
    
    wire phsync,pvsync,pblank;
    rfid_gui gui(.vclock_in(clk_65mhz),.reset_in(reset),
                .up_in(up),.down_in(down),.left_in(left), .right_in(right), .is_spoof_display(spoof_switch),
                .hcount_in(hcount),.vcount_in(vcount),
                .hsync_in(hsync),.vsync_in(vsync),.blank_in(blank),
                .phsync_out(phsync),.pvsync_out(pvsync),.pblank_out(pblank),.pixel_out(pixel),
                .save_addr(sw[3:0]),
                .read_module_bits(id_bits),
                .data_to_bram(data_to_bram),
                .data_from_bram(data_from_bram),
                .addr(addr),
                .write_to_bram(bram_write),
                .bits_to_spoof_out(bits_to_spoof));
                
    reg b,hs,vs;
    always_ff @(posedge clk_65mhz) begin
         hs <= phsync;
         vs <= pvsync;
         b <= pblank;
         rgb <= pixel;
    end

    // the following lines are required for the Nexys4 VGA circuit - do not change
    assign vga_r = ~b ? rgb[11:8]: 0;
    assign vga_g = ~b ? rgb[7:4] : 0;
    assign vga_b = ~b ? rgb[3:0] : 0;

    assign vga_hs = ~hs;
    assign vga_vs = ~vs; 
                
    // Debug
    assign led[15:0] = sw[14] ? data_from_bram[38:23] : bits_to_spoof[45:30];
    
endmodule
