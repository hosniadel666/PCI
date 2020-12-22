/*###############################################
#            DEVICE Test Bench MODULE           #
################################################*/

include "Device.v";
include "new_device.v";



module DEVICE_tb();

/*################## REG ##################*/
reg CLK_tb;
reg RST_tb;
reg FRAME_tb;
reg [3:0] CBE_tb;
reg IRDY_tb;
reg [31: 0]AD_REG_tb;
reg AD_RW_tb;
/*################## NET ##################*/
wire [31: 0] AD_tb;
wire TRDY_tb;
wire DEVSEL_tb;

Device_new D1(FRAME_tb, CLK_tb, RST_tb, AD_tb, CBE_tb, IRDY_tb, TRDY_tb, DEVSEL_tb);

reg [31: 0]READ_DATA;

assign AD_tb = AD_RW_tb? AD_REG_tb: 32'hzzzz_zzzz;  


//Device D1(); // by position

initial 
begin 
    CLK_tb = 1;
	AD_RW_tb = 1;
end

always
begin: GENERATE_CLK
    #5 // f = ??
    CLK_tb = ~CLK_tb;
end

initial
begin
    IRDY_tb = 1'b1;
    AD_REG_tb = 32'h0000FFFF;
    FRAME_tb = 1'b1;
    RST_tb = 1'b1;
end


initial 
begin: TEST
/*################ TEST WRITE OPERATION #################*/
    #2
    CBE_tb = 4'b0111; // WRITE OPERATION
    AD_REG_tb = 32'h0000_0000;
    IRDY_tb = 1'b0;
    #1
    AD_REG_tb = 32'h0000_f0f0; // Data 
    IRDY_tb = 1'b1;

/*################ TEST READ OPERATION #################*/
    #2
    CBE_tb = 4'b0110; // READ OPERATION
    AD_REG_tb <= 32'h0000_0000;
    IRDY_tb = 1'b0;
    #1
    READ_DATA = AD_tb;  
    IRDY_tb = 1'b1;

end
endmodule

