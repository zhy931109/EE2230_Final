`timescale 1ns / 1ps
`define LCD_SET_DSL      10'b0_0_11000000
`define LCD_ERASE        10'b1_0_00000000
`define LCD_DISPLAY_IDLE 10'b0_0_00111111
`define INIT_LCD     3'b000
`define ERASE_LCD    3'b001
`define LCD_IDLE         3'b010
`define REQUEST_DATA 3'b011
`define READ_DATA    3'b100
`define LAST 3'b101
`define ENABLED  1'b1
`define DISABLED 1'b0
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    12:51:56 06/19/2016 
// Design Name: 
// Module Name:    LCDctl 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module LCDctl(
	clk, // LCD controller clock
	rst_n, // active low reset
	data_ack, // data re-arrangement buffer ready indicator
	data, // byte data transfer from buffer
	lcd_di, // LCD data/instruction 
	lcd_rw, // LCD Read/Write
	lcd_en, // LCD enable
	lcd_rst, // LCD reset
	lcd_cs, // LCD frame select
	lcd_data, // LCD data
	addr, // Address for each picture
	data_request, // request for the memory data
	speed
);
	input [1:0]speed;
	input clk; // LCD controller clock
	input rst_n; // active low reset
	input data_ack; // data re-arrangement buffer ready indicator
	input [7:0] data; // byte data transfer from buffer
	output lcd_di; // LCD data/instruction 	
	output lcd_rw; // LCD Read/Write
	output lcd_en; // LCD enable
	output lcd_rst; // LCD reset
	output [1:0] lcd_cs; // LCD frame select
	output [7:0] lcd_data; // LCD data
	output [5:0] addr; // Address for each picture
	output data_request; // request for the memory data
	
	reg lcd_di; // LCD data/instruction 
	reg lcd_rw; // LCD Read/Write
	reg [7:0] lcd_data; // LCD data
	reg lcd_di_next; // LCD data/instruction 
	reg lcd_rw_next; // LCD Read/Write
	reg [7:0] lcd_data_next; // LCD data
	reg data_request; // request for the memory data
	reg data_request_next; // request for the memory data
	reg lcd_en; // LCD enable
	wire lcd_en_next; // LCD enable

	reg [2:0] state; // FSM state definition
	reg [2:0] state_next; // FSM state definition

	reg [6:0] counter_y; // y counter
	reg [6:0] counter_y_next; // y counter
	reg [3:0] counter_page; // page counter
	reg [3:0] counter_page_next; // page counter

	//reg [3:0] image; // image counter
	//reg [3:0] image_next; // image counter
	reg [1:0] speed_image;
	reg left_right_image, left_right_image_next;
	
	reg [6:0] idle_counter; // idle time counter
	reg [6:0] idle_counter_next; // idle time counter

	assign addr = {speed_image, left_right_image, counter_page[2:0]};
	assign lcd_rst = rst_n;
	assign lcd_cs = (left_right_image == 0) ? 2'b10 : 2'b01;
	assign lcd_en_next = ~lcd_en;
	
	always@(*)
		case(speed)
			2'b00: //HIGH
				speed_image = 2'b00;
			2'b01: //MEDIUM
				speed_image = 2'b10;
			2'b10: //LOW
				speed_image = 2'b01;
			2'b11: //OFF
				speed_image = 2'b11;
		endcase

	always@(*) begin
		{lcd_di_next, lcd_rw_next, lcd_data_next} = `LCD_DISPLAY_IDLE;
		state_next = state;
		counter_page_next = counter_page;
		counter_y_next = counter_y;
		//image_next = image;
		left_right_image_next = left_right_image;
		idle_counter_next = idle_counter;
		data_request_next = data_request;
		if (~lcd_en) begin
			case(state)
				`INIT_LCD: begin
					{lcd_di_next, lcd_rw_next, lcd_data_next} = `LCD_SET_DSL;
					state_next = `ERASE_LCD;
					counter_y_next = 7'd0;
					counter_page_next = 4'd0;
				end
				`ERASE_LCD: begin
					if(counter_page <= 4'd7 && counter_y < 7'd63) begin
						{lcd_di_next, lcd_rw_next, lcd_data_next} = `LCD_ERASE;
						counter_y_next = counter_y + 1'b1;
					end
					else if(counter_page <= 4'd7 && counter_y == 7'd63) begin
						{lcd_di_next, lcd_rw_next, lcd_data_next} = `LCD_ERASE;
						counter_y_next = counter_y + 1'b1;
						counter_page_next = counter_page + 1'b1;
					end
					else if(counter_page <= 4'd7 && counter_y == 7'd64) begin
						{lcd_di_next, lcd_rw_next, lcd_data_next} = `LCD_ERASE;
						counter_y_next = 7'b0;
					end
					else if(counter_page == 4'd8 && counter_y == 7'd64) begin
						{lcd_di_next, lcd_rw_next, lcd_data_next} = {4'b0_0_01, 6'b0};
						counter_y_next = counter_y + 1'b1;
					end
					else if(counter_page == 4'd8 && counter_y == 7'd65) begin
						{lcd_di_next, lcd_rw_next, lcd_data_next} = {7'b0_0_10111, 3'd0};
						counter_y_next = 7'd0;
						counter_page_next = 4'b0;
						state_next = `LCD_IDLE;
					end
				end
				`LCD_IDLE: begin
					{lcd_di_next, lcd_rw_next, lcd_data_next} = `LCD_DISPLAY_IDLE;
					if(idle_counter >= 7'd100) begin
						state_next = `REQUEST_DATA;
						idle_counter_next = 7'd0;
						counter_y_next = 7'd0;
						counter_page_next = 4'd0;
					end
					else begin
						state_next = `LCD_IDLE;
						idle_counter_next = idle_counter + 1'b1;
					end
				end
				`REQUEST_DATA: begin
					data_request_next = `ENABLED;
					if (data_ack == `ENABLED) begin
						state_next = `READ_DATA;
						data_request_next = `DISABLED;
						counter_y_next = 7'd0;
						{lcd_di_next, lcd_rw_next, lcd_data_next} = {7'b0_0_10111, counter_page[2:0]};
					end
				end
				`READ_DATA: begin
					if(counter_y < 7'd63) begin
						{lcd_di_next, lcd_rw_next, lcd_data_next} = {2'b1_0, data};
						counter_y_next = counter_y + 1'b1;
					end
					else if(counter_y == 7'd63) begin
						{lcd_di_next, lcd_rw_next, lcd_data_next} = {2'b1_0, data};
						counter_y_next = counter_y + 1'b1;
						counter_page_next = counter_page + 1'b1;

					end
					else if(counter_y == 7'd64) begin
						counter_y_next = 7'd0;
						if (counter_page == 4'd8) begin
							state_next = `REQUEST_DATA;
							left_right_image_next = left_right_image + 1'b1;
						end
						else state_next = `REQUEST_DATA;
					end
				end
			endcase
		end
	end
	
	always @(posedge clk or negedge rst_n)
		if(~rst_n) begin
			state <= 3'd0;
			counter_y <= 7'd0;
			counter_page <= 4'd0;
			idle_counter <= 14'd0;
			data_request <= 1'b0;
			lcd_di <= 1'b0;
			lcd_rw <= 1'b0;
			lcd_data <= 8'd0;
			lcd_en <= 1'b0;
			left_right_image <= 1'b0;
		end
		else begin
			state <= state_next;
			counter_y <= counter_y_next;
			counter_page <= counter_page_next;
			idle_counter <= idle_counter_next;
			data_request <= data_request_next;
			lcd_di <= lcd_di_next;
			lcd_rw <= lcd_rw_next;
			lcd_data <= lcd_data_next;
			lcd_en <= lcd_en_next;
			left_right_image <= left_right_image_next;
		end
				
endmodule
