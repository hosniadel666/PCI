/************************************************
 *            DEVICE Test Bench MODULE           *
 *************************************************/

`include "new_device.v"

module Device_new_tb();
    
    /******************* REG *******************/
    reg CLK;
    reg REST;
    reg FRAME;
    reg [3:0] CBE;
    reg IRDY;
    /******************* NET *******************/
    wire [31:0] AD;
    wire TRDY;
    wire DEVSEL;
    
    Device_new D1(FRAME, CLK, REST, AD, CBE, IRDY, TRDY, DEVSEL);
    
    reg [31:0] READ_DATA;
    
    // assign AD     = 32'h0000FFFF;
    // wire AD_EN;
    // assign CBE = 4'b0101;
    initial begin
        CLK   = 1;
        REST  = 0;
        IRDY  = 1'b1;
        FRAME = 1'b1;
    end
    
    always
    begin: GENERATE_CLK
    #5  CLK = ~CLK; // T = 10;
    end
    
    initial
        begin: TEST
        #10
        REST = 1;
        #5
        CBE   = 4'b0111; 
        FRAME = 1'b0;
	// assign AD = 32'h0000FFFF;
	CBE = 4'b0111;
        #10
        IRDY  = 1'b0;
	// AD = 32'h0000FFF0;
	CBE = 4'b1111;
	#10
        IRDY  = 1'b0;
	// assign AD = 32'h0000FFF1;
	CBE = 4'b1111;
	#10
        IRDY  = 1'b1;
	// assign AD = 32'h0000FFF2;
	CBE = 4'b1111;
	#10
        IRDY  = 1'b0;
	// assign AD = 32'h0000FFF23;
	CBE = 4'b1111;
        #10
        FRAME = 1'b1;
        #10
        IRDY = 1'b1;
    end
    initial
    $monitor("time = %0d, CLK = %b, REST = %b, FRAME = %b, IRDY = %b, TRDY = %b, DEVSEL= %b", 
    $time, CLK, REST, FRAME, IRDY, TRDY, DEVSEL);

endmodule
    
