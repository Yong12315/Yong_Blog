`timescale 1ns/1ps

module rams_rom #(
    parameter                           DWIDTH                      = 32                   ,
    parameter                           AWIDTH                      = 16                   ,
    parameter                           INIT_FILE                   = "Data.mem"           
) (
    input                               clk                        ,
    input                               en                         ,
    input                [AWIDTH-1: 0]  addr                       ,

    output reg           [DWIDTH-1: 0]  dout                        
);

localparam                          MEM_SIZE                    = 1 << AWIDTH          ;

(*rom_style = "block" *)
reg                [DWIDTH-1: 0]        ram[0:MEM_SIZE-1]           ;


initial begin
    $readmemh(INIT_FILE, ram);
end


always @(posedge clk) begin
    if (en) begin
        dout <= ram[addr];
    end
end


endmodule
