`timescale 1ns / 1ps

module Averaging_filter(
    input clk, 
    input rst, // btn[0]
    input start, // btn[1]
    input stop, // btn[2]
    input average, // btn[3]
    output reg regFull=0,
    output wire led0, // led0
    output reg full_led=0,
    output reg [3:0] seg_an,
    output reg [6:0] seg_cat,
    output reg [7:0] led
    );
      
    // works no glitched, but average output missing
    reg [3:0] regd3, regd2, regd1, regd0; //the main output registers
    wire db_start, db_stop;
    reg dffstr1, dffstr2, dffstp1, dffstp2;
    reg [2:0] register_counter;
    
    reg [7:0] A, B, C, D, E, F, G, H;

always @ (posedge clk) dffstr1 <= start;
always @ (posedge clk) dffstr2 <= dffstr1;
assign db_start = ~dffstr1 & dffstr2; // activate only on rising edge
always @ (posedge clk) dffstp1 <= stop;
always @ (posedge clk) dffstp2 <= dffstp1;
assign db_stop = ~dffstp1 & dffstp2; 

//Block for LFSR random number generator/ works  
reg [28:0] random, random_next, random_done; //**29 bit register to keep track upto 10 seconds. 
reg [4:0] count_r, count_next_r; //to keep track of the shifts. 5 bit register to count up to 30
wire feedback = random[28] ^ random[26]; 
always @ (posedge clk or posedge rst) begin
 if (rst) begin
    random <= 29'hF; //An LFSR cannot have an all 0 state, thus reset to FF. 
    count_r <= 0;
   end
 else begin
    random <= random_next;
    count_r <= count_next_r;
   end
 end
always @* begin
 random_next = random; //default state stays the same
 count_next_r = count_r;
 random_next = {random[27:0], feedback}; //shift left the xor'd every posedge clock
 if (count_r == 29)begin
  count_next_r = 0;
  random_done = random; //assign the random number to output after 30 shifts
 end
 else begin
  count_next_r = count_r + 1;
  random_done = random; //keep previous value of random
 end
 end
 //random number block ends


reg [3:0] reg_d0, reg_d1, reg_d2, reg_d3; //registers that will hold the individual counts
// (* KEEP = "TRUE" *)
reg [1:0] sel, sel_next; 
localparam [1:0]
      idle = 2'b00,
      starting = 2'b01,
      time_it = 2'b10,
      done = 2'b11;
      
reg [1:0] state_reg, state_next;
reg [28:0] count_reg, count_next; 
// state machine rst logic
always @ (posedge clk or posedge rst)
begin
 if(rst)
  begin 
   state_reg <= idle;
   count_reg <= 0;
   sel <=0;
  end
 else
  begin
   state_reg <= state_next;
   count_reg <= count_next;
   sel <= sel_next;
  end
end

reg go_start;
// state machine
always @* begin
 state_next = state_reg; 
 count_next = count_reg;
 sel_next = sel;
 case(state_reg)
 idle:
      begin
       sel_next = 2'b00;
    if(db_start)
      begin
       count_next = random_done; 
       state_next = starting; 
      end
      end
  starting:
   begin
    if(count_next == 500000000) 
    begin  
     state_next = time_it; 
    end
    else
    begin
     count_next = count_reg + 1; 
    end
   end  
  time_it:
   begin
     sel_next = 2'b01; 
     state_next = done;     
   end
  done:
   begin
    if(db_stop)
     begin
      sel_next = 2'b10; 
      // register_counter = register_counter + 1'd1;
     end
   end
  endcase
 case(sel_next) // SSD control
  2'b00: 
  begin
   go_start = 0; 
   regd0 = 4'd12; 
   regd1 = 4'd11;
   regd2 = 4'd10;
   regd3 = 4'd12;
  end
  2'b01: 
  begin
   go_start = 1'b1; 
   regd0 = reg_d0;
   regd1 = reg_d1;
   regd2 = reg_d2;
   regd3 = reg_d3;
  end
  2'b10: 
  begin
   // modify here
   go_start = 1'b0;
   regd0 = reg_d0;
   regd1 = reg_d1;
   regd2 = reg_d2;
   regd3 = reg_d3;
  end
  2'b11: 
  begin
   regd0 = 4'd0; 
   regd1 = 4'd0;
   regd2 = 4'd0;
   regd3 = 4'd0;
   go_start = 1'b0;
  end
  default: begin
   regd0 = 4'd0;
   regd1 = 4'd0;
   regd2 = 4'd0;
   regd3 = 4'd0;
   go_start = 1'b0;
  end
 endcase   
end

// counter
always @(posedge db_stop) begin
    register_counter = register_counter + 1'd1;
end

// register on db_stop

//the stopwatch block/counter
reg [18:0] tic; //19 bits needed to count up to 500K bits
wire tac;
always @ (posedge clk or posedge rst)
begin
 if(rst)
  tic <= 0;
 else if(tic == 500000) 
  tic <= 0;
 else if(go_start) 
  tic <= tic + 1;
end
assign tac = ((tic == 500000)?1'b1:1'b0); //click to be assigned high every 0.01 second

// incrementor
always @ (posedge clk or posedge rst)
begin
 if (rst)
  begin
   reg_d0 <= 0;
   reg_d1 <= 0;
   reg_d2 <= 0;
   reg_d3 <= 0;
  end
 else if (tac) 
  begin
   if(reg_d0 == 9) 
   begin  
    reg_d0 <= 0;
    if (reg_d1 == 9) 
    begin  
     reg_d1 <= 0;
     if (reg_d2 == 9) 
     begin 
      reg_d2 <= 0;
      if(reg_d3 == 9) 
       reg_d3 <= 0;
      else
       reg_d3 <= reg_d3 + 1;
     end
     else 
      reg_d2 <= reg_d2 + 1;
    end
    else 
     reg_d1 <= reg_d1 + 1;
   end 
   else 
    reg_d0 <= reg_d0 + 1;
  end
   end
    assign led0 = ((count_reg == 500000000) ? ((db_stop == 1) ? 1'b0 : 1'b1) : 1'b0);
    wire [15:0] b_transfer;
    assign b_transfer =(reg_d3 * 10'd1000) + (reg_d2*7'd100) + (reg_d1*4'd10) + reg_d0;
    reg [30:0] countt;
    reg [2:0] add;
    reg [15:0] sdata;
    
    reg stop_prev;
    reg btn_re;
    always @(posedge clk)
    stop_prev <= stop;
    always @(stop, stop_prev)
    btn_re <= stop & ~stop_prev; // incrementing only at edge   
    
    // need to convert result back to bcd
    wire [3:0] one, ten, hundred, thousand;
    // Up to this point, further is ssd and to bcd converter
    // work with sdata inputs
    // sdata should go to the adder
    // input a and b, where b is the result of the previous sum
    
    // maybe use is as a 8 bit decoder
reg [7:0] registers[7:0];
integer i;
always @(posedge clk) begin // works as intended
    case (register_counter) // try with {}
      3'd0 : led = 8'd1; //
      3'd1 : led = 8'd2;
      3'd2 : led = 8'd4;
      3'd3 : led = 8'd8;
      3'd4 : led = 8'd16;
      3'd5 : led = 8'd32;
      3'd6 : led = 8'd64;
      3'd7 : led = 8'd128;
    endcase
    if (led == 8'd1)
        A <= sdata;
    if (led == 8'd128)
        regFull <= 1'd1;       
end

wire [15:0] bin_sdata; // correct here
assign bin_sdata = (reg_d3 * 10'd1000) + (reg_d2 * 7'd100) + (reg_d1 * 4'd10) + reg_d0;

always @(posedge clk) begin                                
    if (db_stop) registers[register_counter] <= bin_sdata;   //  Write new data if db_stop
end

// maybe sdata d out to be equal directly to the sum of registers without the always case
    wire [15:0] sdata_d_out;
    assign sdata_d_out = (registers[3'd0]
             + registers[3'd1] + registers[3'd2] + registers[3'd3] 
             + registers[3'd4] + registers[3'd5] + registers[3'd6] + registers[3'd7])/8'd8;

//reg [7:0] sdata_d_out;
//always @(posedge average) begin // Output mux always driven
//   if (average) begin
//   sdata_d_out <= registers[3'd0] + registers[3'd1] + registers[3'd2] + registers[3'd3] 
//            + registers[3'd4] + registers[3'd5] + registers[3'd6] + registers[3'd7];
//   end
//end
    
    // binary2BCD b2B(sdata_d_out, thousand, hundred, ten, one);
    // bin2bcd2 bb(bin_sdata[13:0], {thousand, hundred, ten, one}); sdata_d_out
    bin2bcd2 bb(sdata_d_out[13:0], {thousand, hundred, ten, one}); 
    
    wire [3:0] one_t, ten_t, hundred_t, thousand_t;
    average_filter af1(average, regd0, regd1, regd2, regd3, one, ten, hundred, thousand, one_t, ten_t, hundred_t, thousand_t);
    // average filter works
    // now to the SSD
    // SSD control module
    localparam div_value = 4999; // 10 kHz
    integer counter_value = 0; // 
    reg divided_clk;
    // making clk for 4 digit ssd display
    always @ (posedge clk)
    begin
        if (counter_value == div_value) begin
            counter_value <= 0;
            divided_clk <= ~divided_clk;
        end 
        else begin
            counter_value <= counter_value + 1;
            divided_clk <= divided_clk;
        end
    end    
    
    reg [1:0] update_counter;
    always @ (posedge divided_clk)
    update_counter <= update_counter + 1;
    
    always @ (update_counter)
    begin
        case (update_counter)
        2'b00: seg_an = 4'b1110;
        2'b01: seg_an = 4'b1101;
        2'b10: seg_an = 4'b1011; 
        2'b11: seg_an = 4'b0111;
        endcase
    end
    
    reg [3:0] Ddigit;
    always @ (update_counter)
    begin
        // we need to store one_t, ten_t, hundred_t, thousand_t in the 7 registrers
        case (update_counter)
        2'b00: Ddigit = one_t;
        2'b01: Ddigit = ten_t;
        2'b10: Ddigit = hundred_t; 
        2'b11: Ddigit = thousand_t; // change to variables
        endcase
    end
    
always @ (Ddigit)
begin
case (Ddigit)
4'b0000 : seg_cat <= 7'b1000000; // 0
4'b0001 : seg_cat <= 7'b1111001; // 1
4'b0010 : seg_cat <= 7'b0100100; // 2
4'b0011 : seg_cat <= 7'b0110000; // 3
4'b0100 : seg_cat <= 7'b0011001; // 4
4'b0101 : seg_cat <= 7'b0010010; // 5
4'b0110 : seg_cat <= 7'b0000010; // 6
4'b0111 : seg_cat <= 7'b1111000; // 7
4'b1000 : seg_cat <= 7'b0000000; // 8
4'b1001 : seg_cat <= 7'b0010000; // 9
default: seg_cat <= 7'b1000000;
endcase
end
endmodule
    
    // average_filter af1(average, regd0, regd1, regd2, regd3, one, ten, hundred, thousand, one_t, ten_t, hundred_t, thousand_t
    module average_filter(
        input average,
        input wire [3:0] reg_d0, reg_d1, reg_d2, reg_d3,
        input wire [3:0] one, ten, hundred, thousand,
        output reg [3:0] one_t, ten_t, hundred_t, thousand_t
        );
        
        // the problem is not here as well
        always @ (average) begin
        case(average)
        1'b0: begin 
          one_t <= reg_d0;
          ten_t <= reg_d1;
          hundred_t <= reg_d2;
          thousand_t <= reg_d3;
          end
        1'b1: begin
          one_t <= one;
          ten_t <= ten;
          hundred_t <= hundred;
          thousand_t <= thousand;
          end
    endcase
    end      
    endmodule
    
    module bin2bcd2(
       input [13:0] bin,
       output reg [15:0] bcd
    );
   
integer i;
	
always @(bin) begin
    bcd=0;		 	
    for (i=0;i<14;i=i+1) begin					//Iterate once for each bit in input number
        if (bcd[3:0] >= 5) bcd[3:0] = bcd[3:0] + 3;		//If any BCD digit is >= 5, add three
	if (bcd[7:4] >= 5) bcd[7:4] = bcd[7:4] + 3;
	if (bcd[11:8] >= 5) bcd[11:8] = bcd[11:8] + 3;
	if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
	bcd = {bcd[14:0],bin[13-i]};				//Shift one bit, and shift in proper bit from input 
    end
end
endmodule
    
    module binary2BCD(
    input [15:0] binary,
    output reg [3:0] thousands,
    output reg [3:0] hundreds,
    output reg [3:0] tens,
    output reg [3:0] ones 
    ); 
    reg [15:0]shifter; 
    reg [4:0] i; // fixes the issue
    always@(binary) 
      begin 
        shifter = 0; 
        for (i = 0; i < 16; i = i+1) begin 
            if (i < 15 && shifter[3:0] > 4) 
                shifter[3:0] = shifter[3:0] + 3; 
            if (i < 15 && shifter[7:4] > 4)             
                shifter[7:4] = shifter[7:4] + 3;
            if (i < 15 && shifter[11:8] > 4)             
                shifter[11:8] = shifter[11:8] + 3; 
            if (i < 15 && shifter[15:12] > 4)              
                shifter[15:12] = shifter[15:12] + 3; 
    end  
    thousands = shifter[15:12];
    hundreds = shifter[11:8];
    tens = shifter[7:4];
    ones = shifter[3:0];
end
endmodule

module regfile(
    input clk, rst, clr, wen,
    input [2:0] add,
    input [7:0] d_in,
    output reg [7:0] d_out
    );
    
reg [7:0] registers[7:0];
integer i;
  
always @(posedge(clk), posedge(rst))        // 
    begin                                   //  
        if (rst) begin                      //
        for (i=0; i<7; i=i+1)               //  For loop assigns asynch reset to all registers
            registers[i] <= 8'b0;           //
        end      
    else if (wen) registers[add] <= d_in;   //  Write new data if wen asserted

end

always @(add, registers)                    // Output mux always driven
   d_out <= registers[add];
 
endmodule
