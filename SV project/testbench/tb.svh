`timescale 1ns/10ps
`define CYCLE   20.0   
`define END_CYCLE 1_000_000
`define IMG_WIDTH 8 
`define WORD_LENGTH 8
`define PIXEL_NUM `IMG_WIDTH*`IMG_WIDTH
`define CMD_LENGTH 4
`include "interface.sv"
`include "test.sv"
`include "LCD_CTRL.v"
