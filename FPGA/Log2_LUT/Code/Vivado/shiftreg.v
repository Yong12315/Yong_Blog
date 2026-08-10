`timescale 1ns/1ps

module shiftreg #(
    parameter                           WIDTH                       = 12                   ,
    parameter                           LENGTH                      = 46                   ,
    parameter                           MEMORY_TYPE                 = "LUT"                
) (
    input                               CLK                        ,
    input                [WIDTH-1: 0]   D                          ,
    output               [WIDTH-1: 0]   Q                          ,
    input                               CE                          
);

generate

    if (MEMORY_TYPE == "LUT") begin : GEN_LUT

        (* shreg_extract = "yes" *)
        reg [WIDTH-1:0] Data [0:LENGTH-1];

        integer j;

        initial begin
            for (j = 0; j < LENGTH; j = j + 1) begin
                Data[j] = {WIDTH{1'b0}};
            end
        end

        assign Q = Data[LENGTH-1];

        always @(posedge CLK) begin
            if (CE) begin
                Data[0] <= D;
                for (j = 0; j < LENGTH-1; j = j + 1) begin
                    Data[j+1] <= Data[j];
                end
            end
        end

    end
    else if (MEMORY_TYPE == "REG") begin : GEN_REG

        (* shreg_extract = "no" *)
        reg [WIDTH-1:0] Data [0:LENGTH-1];

        integer j;

        initial begin
            for (j = 0; j < LENGTH; j = j + 1) begin
                Data[j] = {WIDTH{1'b0}};
            end
        end

        assign Q = Data[LENGTH-1];

        always @(posedge CLK) begin
            if (CE) begin
                Data[0] <= D;
                for (j = 0; j < LENGTH-1; j = j + 1) begin
                    Data[j+1] <= Data[j];
                end
            end
        end

    end
    else begin : GEN_AUTO

        reg [WIDTH-1:0] Data [0:LENGTH-1];

        integer j;

        initial begin
            for (j = 0; j < LENGTH; j = j + 1) begin
                Data[j] = {WIDTH{1'b0}};
            end
        end

        assign Q = Data[LENGTH-1];

        always @(posedge CLK) begin
            if (CE) begin
                Data[0] <= D;
                for (j = 0; j < LENGTH-1; j = j + 1) begin
                    Data[j+1] <= Data[j];
                end
            end
        end

    end

endgenerate

endmodule