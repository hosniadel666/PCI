/*************************************************
 *            DEVICE Test Bench MODULE           *
 *************************************************/

include "new_device.v";

module GenericTestBench();
    
    /******************* REG *******************/
    reg CLK;
    reg RST;
    reg FRAME;
    reg IRDY;
    reg [3:0] CBE;
    /******************* NET *******************/
    wire [31:0] AD;
    wire TRDY;
    wire DEVSEL;
    wire STOP;
    reg PAR;
    wire SERR;
    wire PERR;
    
    reg [31:0] AD_REG;
    reg AD_OE;

    parameter BASE_AD           = 32'hFFFF0000;
    parameter MEM_READ_C        = 4'b0110;
    parameter MEM_WRITE_C       = 4'b0111;
    parameter MEM_READ_MUL_C    = 4'b1100;
    parameter MEM_READ_LINE_C   = 4'b1110;
    parameter MEM_WRITE_INVAL_C = 4'b1111;
    
    // tri-state the AD lines
    assign AD = AD_OE? AD_REG: 32'hZZZZZZZZ;
    
    // Instantiate the Device
    Device D1(FRAME, CLK, RST, AD, CBE, IRDY, TRDY, DEVSEL, STOP, PAR, SERR, PERR);
    Device #(.BASE_AD(32'hFFFFF000)) D2(FRAME, CLK, RST, AD, CBE, IRDY, TRDY, DEVSEL, STOP, PAR);
    
    // Intialize the signals
    initial begin
        CLK    = 1;
        AD_OE  = 1;
        IRDY   = 1'b1;
        AD_REG = 32'hFFFF_FFFF;
        FRAME  = 1'b1;
        RST    = 0;
        #1 RST = 1;
    end
    
    // Generate the clk;
    always begin
        #5 CLK = ~CLK;
    end
    
    // Intialize data
    reg [31:0] data [0:5];
    integer i;
    
    task initialize_data;
        begin
            data[0] = 32'h0000_F0F0;
            data[1] = 32'h0000_F0F1;
            data[2] = 32'h0000_F0F2;
            data[3] = 32'h0000_F0F3;
            data[4] = 32'h0000_F0F4;
            data[5] = 32'h0000_F0F5;
        end
    endtask
    
    reg enable_loop = 1;
    reg clc_par;
    
    task write_data; begin
        // Intiating write operation
        #10;
        FRAME = 1'b0;
        clc_par = (^AD_REG) ^ (^CBE);
        #10
        IRDY = 1'b0;
        
        
        // put the first data on the bus
        CBE    = 4'b1111;
        AD_REG = data[0]; // Data
        PAR = clc_par;
        clc_par = (^AD_REG) ^ (^CBE);
        $display("\nTRANSACTION STARTED\n");
        enable_loop = 1;
        for(i = 1; i < 6 & enable_loop;) begin
            #5
            if (~TRDY & STOP) begin
                // ready to write
                $display("Writing %h", data[i - 1]);
                #5
                AD_REG = data[i];
                PAR = clc_par;
                clc_par = (^AD_REG) ^ (^CBE);
                i      = i + 1;
            end
            else if (TRDY & STOP) begin
                // device is busy
                // wait for TRDY
                $display("Device busy");
                #5 enable_loop = 1;
            end
                else if (~TRDY & ~STOP) begin
                // device request to end the transction
                $display("Device requesting disconnet with data");
                $display("Writing the last word %h", data[i - 1]);
                #5
                enable_loop = 0;
                // finish
                end
            else begin
                $display("Device requesting retry/disconnet without data");
                enable_loop = 0;
            end
        end
        // the last data transfer
        FRAME = 1;
        #5;
        if (i == 6)
            $display("Writing %h", data[i - 1]);
            #5 IRDY = 1;
            $display("\nTRANSACTION FINISHED\n");
            #10; // turn around cycle
        
    end
    endtask
    
    task read_data; begin
        // Intiating Read operation
        #10
        FRAME = 1'b0;
        #10
        AD_OE = 0;
        IRDY  = 1'b0;
        // Wait for turn around cycle
        #10
        
        // start reading
        $display("\nTRANSACTION STARTED\n");
        enable_loop = 1;
        for(i = 0; i < 4 & enable_loop;) begin
            #10
            if (~TRDY & STOP) begin
                // ready to read
                $display("Reading %h", AD);
                i = i + 1;
                end else if (TRDY & STOP) begin
                // device is busy
                // wait for TRDY
                $display("Device busy");
                end else if (~TRDY & ~STOP) begin
                // device request to end the transction
                $display("Device requesting disconnet with data");
                $display("Reading the last word %h", AD);
                enable_loop = 0;
                // finish
                end else begin
                $display("Device requesting retry/disconnet without data");
                enable_loop = 0;
            end
        end
        FRAME = 1;
        #10
        IRDY  = 1;
        AD_OE = 1;
        $display("\nTRANSACTION FINISHED\n");
    end
    endtask
    
    // Starting the Test
    initial begin
        /***************** TEST WRITE OPERATION *****************/
        #5
        $display("Test Write Operation");
        initialize_data;
        CBE    = MEM_WRITE_C;
        AD_REG = BASE_AD;
        write_data;
        /***************** TEST READ OPERATION ******************/
        $display("Test Read Operation");
        CBE    = MEM_READ_C;
        AD_REG = BASE_AD;
        read_data;
        /**** TEST UNSUPPORTED BURST MODE IN WRITE OPERATION ****/
        $display("Test Disconnect with data in Write Operation");
        #10
        initialize_data;
        CBE    = MEM_WRITE_C;
        AD_REG = BASE_AD + 1;
        write_data;
        /**** TEST UNSUPPORTED BURST MODE IN WRITE OPERATION ****/
        $display("Test Disconnect with data in Read Operation");
        CBE    = MEM_READ_C;
        AD_REG = BASE_AD + 1;
        read_data;
        
        /**** TEST UNSUPPORTED OPERATION ****/
        $display("Test Disconnect without data");
        #10
        initialize_data;
        CBE    = 4'b0000;
        AD_REG = BASE_AD + 1;
        write_data;
    end
endmodule
    
