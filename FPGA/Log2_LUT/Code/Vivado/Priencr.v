`timescale 1ns/1ps
`default_nettype none

module Priencr #(
    parameter                           WIDTH                       = 32                   ,
    parameter                           POS_WIDTH                   = clog2(WIDTH)         
) (
    input  wire                             Clk                        ,
    input  wire                             Rst                        ,

    input  wire                             Din_tvalid                 ,
    input  wire          [WIDTH-1: 0]       Din                        ,

    output wire                             Pos_tvalid                 ,
    output wire          [POS_WIDTH-1: 0]   Pos                         
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


localparam                          STAGE_NUM                      = POS_WIDTH            ;
localparam                          PAD_WIDTH                   = 1 << STAGE_NUM          ;


reg                  [PAD_WIDTH-1: 0]   Data_Pipe[0:STAGE_NUM]        ;
reg                                     Valid_Pipe[0:STAGE_NUM]       ;

always @(posedge Clk) begin
    if (Din_tvalid) begin
        Data_Pipe[0]  <= {{(PAD_WIDTH-WIDTH){1'b0}}, Din};
    end
    else begin
        Data_Pipe[0] <= {PAD_WIDTH{1'b0}};
    end
end

always @(posedge Clk) begin
    if (Rst) begin
        Valid_Pipe[0] <= 'b0; 
    end
    else begin
        Valid_Pipe[0] <= Din_tvalid;
    end
end


reg                  [POS_WIDTH-1: 0]   Pos_Pipe[0:STAGE_NUM-1]         ;

genvar stage;

generate

    for (stage = 0; stage < STAGE_NUM; stage = stage + 1) begin : gen_stage

        localparam                          CUR_WIDTH                   = PAD_WIDTH >> stage       ;
        localparam                          HALF_WIDTH                  = CUR_WIDTH >> 1       ;

        if (stage == 0) begin

            always @(posedge Clk) begin
                if (Valid_Pipe[stage]) begin
                    Pos_Pipe[stage][stage:0] <= |Data_Pipe[stage][CUR_WIDTH-1:HALF_WIDTH];
                end
            end

            always @(posedge Clk) begin
                if (Valid_Pipe[stage]) begin
                    Data_Pipe[stage+1][HALF_WIDTH-1:0] <= |Data_Pipe[stage][CUR_WIDTH-1:HALF_WIDTH] ? 
                                                            Data_Pipe[stage][CUR_WIDTH-1:HALF_WIDTH] : 
                                                            Data_Pipe[stage][HALF_WIDTH-1:0];
                end
            end

            always @(posedge Clk) begin
                if (Rst) begin
                    Valid_Pipe[stage+1] <= 'b0;
                end
                else begin
                    Valid_Pipe[stage+1] <= Valid_Pipe[stage];
                end
            end

        end
        
        else begin

            always @(posedge Clk) begin
                if (Valid_Pipe[stage]) begin
                    Pos_Pipe[stage][stage:0] <= {Pos_Pipe[stage-1][stage-1:0], |Data_Pipe[stage][CUR_WIDTH-1:HALF_WIDTH]};
                end
            end

            always @(posedge Clk) begin
                if (Valid_Pipe[stage]) begin
                    Data_Pipe[stage+1][HALF_WIDTH-1:0] <= |Data_Pipe[stage][CUR_WIDTH-1:HALF_WIDTH] ? 
                                                            Data_Pipe[stage][CUR_WIDTH-1:HALF_WIDTH] : 
                                                            Data_Pipe[stage][HALF_WIDTH-1:0];
                end
            end

            always @(posedge Clk) begin
                if (Rst) begin
                    Valid_Pipe[stage+1] <= 'b0;
                end
                else begin
                    Valid_Pipe[stage+1] <= Valid_Pipe[stage];
                end
            end

        end

    end

endgenerate


assign                              Pos_tvalid                  = Valid_Pipe[STAGE_NUM];
assign                              Pos                         = Pos_Pipe[STAGE_NUM-1];


endmodule

`default_nettype wire