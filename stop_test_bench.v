/*************************************************
 *            DEVICE Test Bench MODULE           *
 *************************************************/

include "new_device.v";

module StopTestBench();
    
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

    wire PAR;
    
    // tri-state the AD lines
    assign AD = AD_OE? AD_REG: 32'hZZZZZZZZ;
    
    // Instantiate the Device
    Device D1(FRAME, CLK, RST, AD, CBE, IRDY, TRDY, DEVSEL, STOP, PAR);
    
    // Intialize the signals
    initial begin
        CLK    = 1;
        AD_OE  = 1;
        IRDY   = 1'b1;
        AD_REG = 32'hFFFF_FFFF;
        FRAME  = 1'b1;
        RST    = 0;
        // DEVSEL = 1;
        // TRDY   = 1;
    end
    
    // Generate the clk;
    always begin
        #5 CLK = ~CLK;
    end
    
    reg [31:0] data [0:5];
    integer i;

    initial begin
        data[0] = 32'h0000_F0F0;
        data[1] = 32'h0000_F0F1;
        data[2] = 32'h0000_F0F2;
        data[3] = 32'h0000_F0F3;
        data[4] = 32'h0000_F0F4;
        data[5] = 32'h0000_F0F5;
    end

    reg enable_loop = 1;

    parameter BASE_AD  = 32'hFFFF0000;
    parameter MEM_READ_C  = 4'b0110;
    parameter MEM_WRITE_C = 4'b0111;
    parameter MEM_READ_MUL_C  = 4'b1100;
    parameter MEM_READ_LINE_C  = 4'b1110;
    parameter MEM_WRITE_INVAL_C = 4'b1111;

    // Starting the Test
    initial begin
        // Resting the device
        #5 RST = 1;
        /***************** TEST WRITE OPERATION *****************/
        // Intiating write operation
        #10
        FRAME  = 1'b0;
        CBE    = MEM_WRITE_C;
        AD_REG = BASE_AD;
        IRDY   = 1'b0;

        // put the first data on the bus 
        #10
        CBE    = 4'b1111;
        AD_REG = data[0]; // Data

        $display("\nTRANSACTION STARTED\n");
        enable_loop = 1;
        for(i = 1; i < 6 & enable_loop; ) begin
            #5
            if(~TRDY & STOP) begin
                // ready to write
                $display("Writing %h", data[i - 1]);
                #5
                AD_REG = data[i];
                i = i + 1;
            end else if (TRDY & STOP) begin
                // device is busy 
                // wait for TRDY
                $display("Device busy");
                #5 enable_loop = 1;
            end else if (~TRDY & ~STOP) begin
                // device request to end the transction
                $display("Device requesting disconnet with data");
                $display("Writing the last word %h", data[i - 1]);
                #5
                enable_loop = 0;
                // finish 
            end else begin
                $display("Device requesting retry/disconnet without data");
                enable_loop = 0;
            end
        end
        // the last data transfer 
        FRAME = 1;
        #5;
        while(TRDY) begin
            $display("Device busy");
            #5;
        end
        $display("Writing %h", data[i - 1]);
        #5 IRDY = 1;
        $display("\nTRANSACTION FINISHED\n");
        #10 // turn around cycle

         /***************** TEST READ OPERATION ******************/
        // Intiating Read operation
        FRAME  = 1'b0;
        CBE    = MEM_READ_C;
        AD_REG = BASE_AD;

        #10
        IRDY   = 1'b0;
        AD_OE = 0;

        // Wait for turn around cycle
        #10
        
        // start reading
        $display("\nTRANSACTION STARTED\n");
        enable_loop = 1;
        for(i = 1; i < 5 & enable_loop; ) begin
            #5
            if(~TRDY & STOP) begin
                // ready to read
                $display("Reading %h", AD);
                i = i + 1;
                #5  enable_loop = 1;
            end else if (TRDY & STOP) begin
                // device is busy 
                // wait for TRDY
                $display("Device busy");
                #5  enable_loop = 1;
            end else if (~TRDY & ~STOP) begin
                // device request to end the transction
                $display("Device requesting disconnet with data");
                $display("Reading the last word %h", AD);
                #5
                enable_loop = 0;
                // finish 
            end else begin
                $display("Device requesting retry/disconnet without data");
                enable_loop = 0;
            end
        end
        FRAME = 1;
        #10 IRDY = 1;
        $display("\nTRANSACTION FINISHED\n");
    end
endmodule
    
