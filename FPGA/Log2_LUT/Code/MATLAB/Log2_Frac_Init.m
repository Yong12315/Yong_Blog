clc;
clear;

ADDR_WIDTH = 16;
DATA_WIDTH = 16;

DEPTH = 2^ADDR_WIDTH;
SCALE = 2^DATA_WIDTH;

fid = fopen('Log2_Frac_Init.mem', 'w');

for addr = 0 : DEPTH-1
    frac_in = addr / DEPTH;
    log2_frac = log2(1 + frac_in);
    lut_data = round(log2_frac * SCALE);

    if lut_data >= SCALE
        lut_data = SCALE - 1;
    end

    fprintf(fid, '%04X\n', lut_data);
end

fclose(fid);

disp('Log2_Frac_Init.txt generated.');