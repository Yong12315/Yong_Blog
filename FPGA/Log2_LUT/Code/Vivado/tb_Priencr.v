`timescale 1ns/1ps
`default_nettype none

module tb_Priencr;

parameter                           WIDTH                       = 16                   ;
parameter                           POS_WIDTH                   = clog2(WIDTH)         ;

function integer clog2;
    input integer value;
    integer temp;
    begin
        temp = value - 1;
        for (clog2 = 0; temp > 0; clog2 = clog2 + 1)
            temp = temp >> 1;
    end
endfunction

reg                                     Clk                        ;
reg                                     Rst                        ;
reg                                     Din_tvalid                 ;
reg                  [WIDTH-1: 0]       Din                        ;
wire                                    Pos_tvalid                 ;
wire                 [POS_WIDTH-1: 0]   Pos                        ;

Priencr #(
    .WIDTH                              (WIDTH                     ) 
) u_Priencr (
    .Clk                                (Clk                       ),
    .Rst                                (Rst                       ),
    .Din_tvalid                         (Din_tvalid                ),
    .Din                                (Din                       ),
    .Pos_tvalid                         (Pos_tvalid                ),
    .Pos                                (Pos                       ) 
);

localparam CLK_PERIOD = 10;
always #(CLK_PERIOD/2) Clk=~Clk;



initial begin
    #1 Rst<=1'bx;Clk<=1'bx;
    #(CLK_PERIOD*3) Rst<=0;
    #(CLK_PERIOD*3) Rst<=1;Clk<=0;
    repeat(5) @(posedge Clk);
    Rst<=0;
    Din_tvalid = 'b0;
    @(posedge Clk);
    repeat(2) @(posedge Clk);
    #1;
    Din_tvalid = 'b1;
end

always @(posedge Clk) begin
    if (Rst) begin
        Din <= 'd0;
    end
    else if (Din_tvalid) begin
        Din <= Din + 1;
    end
end

endmodule
`default_nettype wire