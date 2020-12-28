/*************************************************
 *            DEVICE Test Bench MODULE           *
 *************************************************/

include "new_device.v";

module DeviceTestBench();
    
    /******************* REG *******************/
    reg CLK;
    reg RST;
    reg FRAME;
    reg [3:0] CBE;
    reg IRDY;
    reg [31:0] AD_REG;
    reg AD_OE;
    /******************* NET *******************/
    wire [31: 0] AD;
    wire TRDY;
    wire DEVSEL;
wire STOP;
    
    // tri-state the AD lines
    assign AD = AD_OE? AD_REG: 32'hZZZZZZZZ;
    
    // Instantiate the Device
    Device D1(FRAME, CLK, RST, AD, CBE, IRDY, TRDY, DEVSEL, STOP);
    
    // Intialize the signals
    initial begin
        CLK    = 1;
        AD_OE  = 1;
        IRDY   = 1'b1;
        AD_REG = 32'hffff_0004;
        FRAME  = 1'b1;
        RST    = 0;
    end
    
    // Generate the clk;
    always begin
        #5 CLK = ~CLK;
    end
    
    // Starting the Test
    initial begin
        // Resting the device
        #5 RST = 1;
        /***************** TEST WRITE OPERATION ****************#*/
        #10
        FRAME  = 1'b0;
        CBE    = 4'b0111; // WRITE OPERATION
        AD_REG = 32'hffff_0000;
        IRDY   = 1'b1;
        #10
        IRDY   = 1'b1;
        CBE    = 4'b1111;
        AD_REG = 32'h0000_f0f0; // Data
        #10
        // FRAME = 1'b1;
        IRDY   = 1'b0;
        AD_REG = 32'h0000_f0f1; // Data
        #10
        AD_REG = 32'h0000_f0f2; // Data
        #10
        IRDY = 1'b1;
        #10
        IRDY   = 1'b0;
        AD_REG = 32'h0000_f0f3; // Data
        #10
        AD_REG = 32'h0000_f0f4; // Data
        #20
        AD_REG = 32'h0000_f0f5; // Data
        #10
        AD_REG = 32'h0000_f0f6; // Data
        FRAME  = 1'b1; // last transction
        #10
        // turn around cycle
        IRDY = 1'b1;
        /***************** TEST READ OPERATION ******************/
        #10
        FRAME  = 1'b0;
        CBE    = 4'b0110; // READ OPERATION
        AD_REG = 32'hffff_0000;
        #10
        IRDY  = 1'b1;
        AD_OE = 0;
        #10
        IRDY  = 1'b1;
                #20
        IRDY  = 1'b0;
        #20
        FRAME = 1;
        #10
        IRDY      = 1'b1;
    end
endmodule
    
