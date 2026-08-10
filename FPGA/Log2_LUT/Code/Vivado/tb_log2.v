`timescale 1ns/1ps
`default_nettype none

module tb_log2;

parameter                           IN_DATA_WIDTH               = 29                   ;
parameter                           OUT_INT_WIDTH               = clog2(IN_DATA_WIDTH) ;
parameter                           LUT_PRECISION               = 16                   ;
parameter                           OUT_FRAC_WIDTH              = 16                   ;
parameter                           OUT_DATA_WIDTH              = OUT_INT_WIDTH + OUT_FRAC_WIDTH;

function integer clog2;
    input integer value;
    integer temp;
    begin
        temp = value - 1;
        for (clog2 = 0; temp > 0; clog2 = clog2 + 1)
            temp = temp >> 1;
    end
endfunction

reg                                         Clk                        ;
reg                                         Rst                        ;
reg                                         Din_tvalid                 ;
reg                  [IN_DATA_WIDTH-1: 0]   Din                        ;
wire                                        Dout_tvalid                ;
wire                 [OUT_DATA_WIDTH-1: 0]  Dout                       ;

log2 #(
    .IN_DATA_WIDTH                      (IN_DATA_WIDTH             ),
    .LUT_PRECISION                      (LUT_PRECISION             ),
    .OUT_FRAC_WIDTH                     (OUT_FRAC_WIDTH            ) 
) u_log2 (
    .Clk                                (Clk                       ),
    .Rst                                (Rst                       ),
    .Din_tvalid                         (Din_tvalid                ),
    .Din                                (Din                       ),
    .Dout_tvalid                        (Dout_tvalid               ),
    .Dout                               (Dout                      ) 
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
    repeat(200) @(posedge Clk);
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