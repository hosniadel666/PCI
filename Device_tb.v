/*###############################################
#            DEVICE Test Bench MODULE           #
################################################*/
include "Device.v";

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

Device D1(FRAME_tb, CLK_tb, RST_tb, AD_tb, CBE_tb, IRDY_tb, TRDY_tb, DEVSEL_tb);

reg [31: 0]READ_DATA;

assign AD_tb = AD_RW_tb? AD_REG_tb: 8'hzzzz_zzzz;  

always
begin: GENERATE_CLK
    #1 
    CLK_tb = ~CLK_tb;
end

initial
begin
	CLK_tb = 1;
	AD_RW_tb = 1'b1;
    IRDY_tb = 1'b1;
    AD_REG_tb = 32'hzzzzzzzz;
    FRAME_tb = 1'bz;
    RST_tb = 1'b1;
end


initial 
begin: TEST
/*################ TEST WRITE OPERATION #################*/
	#1
	//AD_RW_tb = 1'b1;
	FRAME_tb = 1'b0;
	AD_REG_tb = 32'h00000000;
	CBE_tb = 4'b0111; // WRITE OPERATION

	#2
	AD_REG_tb = 32'hzzzzzzzz;// turning cycle
	CBE_tb = 4'b1111; // Byte enable
	IRDY_tb = 1'b0;

	#2
	AD_REG_tb = 32'hf0f0f0f0; // Data1

	#2
	CBE_tb = 4'b1001; // Byte enable
	AD_REG_tb = 32'hffffffff; // Data2

	#2
	CBE_tb = 4'b0001; // Byte enable
	AD_REG_tb = 32'hf0f0f0f0; // Data3

	#2
	AD_REG_tb = 32'hzzzzzzzz; // turning cycle
	FRAME_tb = 1'b1;
	



/*################ TEST READ OPERATION #################*/
 	#4
	//AD_RW_tb = 1'b1;
	FRAME_tb = 1'b0;
	AD_REG_tb = 32'h00000000;
	CBE_tb = 4'b0110; // WRITE OPERATION

	#2
	AD_REG_tb = 32'hzzzzzzzz;// turning cycle
	CBE_tb = 4'bzzzz; // Byte enable
	IRDY_tb = 1'b0;

	#2;
	#2;
	#2;
	#2

	FRAME_tb = 1'b1;
	#4;
end
endmodule

