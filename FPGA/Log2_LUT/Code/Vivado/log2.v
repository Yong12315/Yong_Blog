`timescale 1ns/1ps
`default_nettype none

module log2 #(
    parameter                           IN_DATA_WIDTH               = 32                   ,
    parameter                           OUT_INT_WIDTH               = clog2(IN_DATA_WIDTH) ,
    parameter                           LUT_PRECISION               = 16                   ,
    parameter                           OUT_FRAC_WIDTH              = 16                   ,
    parameter                           OUT_DATA_WIDTH              = OUT_INT_WIDTH + OUT_FRAC_WIDTH
) (
    input  wire                                 Clk                        ,
    input  wire                                 Rst                        ,

    input  wire                                 Din_tvalid                 ,
    input  wire          [IN_DATA_WIDTH-1: 0]   Din                        ,

    output wire                                 Dout_tvalid                ,
    output wire          [OUT_DATA_WIDTH-1: 0]  Dout                       
);


function integer clog2;
    input integer value;
    integer temp;
    begin
        temp = value - 1;
        for (clog2 = 0; temp > 0; clog2 = clog2 + 1)
            temp = temp >> 1;
    end
endfunction


reg                                         Data_Val                   ;
reg                  [IN_DATA_WIDTH-1: 0]   Data                       ;

always @(posedge Clk) begin
    if (Rst) begin
        Data_Val <= 'b0;
    end
    else begin
        Data_Val <= Din_tvalid;
    end
end

always @(posedge Clk) begin
    if (Din_tvalid) begin
        Data <= Din;
    end
    else begin
        Data <= 'd0;
    end
end


localparam                          PRIENCR_LATENCY             = OUT_INT_WIDTH + 1    ;

wire                                        Integer_Val                ;
wire                 [OUT_INT_WIDTH-1: 0]   Integer                    ;
wire                 [IN_DATA_WIDTH-1: 0]   Data_Pipe                  ;

Priencr #(
    .WIDTH                              (IN_DATA_WIDTH                ) 
) u_Priencr (
    .Clk                                (Clk                       ),
    .Rst                                (Rst                       ),

    .Din_tvalid                         (Data_Val                  ),
    .Din                                (Data                      ),
    .Pos_tvalid                         (Integer_Val               ),
    .Pos                                (Integer                   ) 
);

shiftreg#(
    .WIDTH                              (IN_DATA_WIDTH             ),
    .LENGTH                             (PRIENCR_LATENCY           ) 
) u_shiftreg (
    .CLK                                (Clk                       ),
    .D                                  (Data                      ),
    .Q                                  (Data_Pipe                 ),
    .CE                                 (1'b1                      ) 
);


reg                                         Data_Barrel_Val            ;
reg                  [IN_DATA_WIDTH-1: 0]   Data_Barrel                ;
reg                  [OUT_INT_WIDTH-1: 0]   Integer_Out                ;

always @(posedge Clk) begin
    if (Integer_Val) begin
        Data_Barrel <= Data_Pipe << (IN_DATA_WIDTH - 1 - Integer);
        Integer_Out <= Integer;
    end
end

always @(posedge Clk) begin
    if (Rst) begin
        Data_Barrel_Val <= 'b0;
    end
    else begin
        Data_Barrel_Val <= Integer_Val;
    end
end


reg                                         Fraction_Val               ;
reg                  [OUT_INT_WIDTH-1: 0]   Integer_Out_1              ;

wire                 [OUT_FRAC_WIDTH-1: 0]  Fraction                   ;

rams_rom #(
    .DWIDTH                             (OUT_FRAC_WIDTH            ),
    .AWIDTH                             (LUT_PRECISION             ),
    .INIT_FILE                          ("Log2_Frac_Init.mem"      ) 
) log2_Frac_LUT (
    .clk                                (Clk                       ),
    .en                                 (Data_Barrel_Val           ),
    .addr                               (Data_Barrel[IN_DATA_WIDTH-2-:LUT_PRECISION]),
    .dout                               (Fraction                  ) 
);

always @(posedge Clk) begin
    if (Data_Barrel_Val) begin
        Integer_Out_1 <= Integer_Out;
    end
end

always @(posedge Clk) begin
    if (Rst) begin
        Fraction_Val <= 'b0;
    end
    else begin
        Fraction_Val <= Data_Barrel_Val;
    end
end


reg                                         Result_Val                 ;
reg                  [OUT_DATA_WIDTH-1: 0]  Result                   =0 ;

always @(posedge Clk) begin
    if (Rst) begin
        Result_Val <= 'b0;
    end
    else begin
        Result_Val <= Fraction_Val;
    end
end

always @(posedge Clk) begin
    if (Fraction_Val) begin
        Result <= {Integer_Out_1, Fraction};
    end
end


assign                              Dout_tvalid                 = Result_Val           ;
assign                              Dout                        = Result               ;


endmodule

`default_nettype wire