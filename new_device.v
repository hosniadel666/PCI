/*************************************************
 *               DEVICE MODULE                   *
 *************************************************/


module Device_new(FRAME,
                  CLK,     // Clock
                  REST,    // Asyncronous Reset(Active Low)
                  AD,      // Address and Data line time multiplexing
                  CBE,     // Control command
                  IRDY,    // Initiator ready(Active Low)
                  TRDY,    // Target ready(Active Low)
                  DEVSEL); // Device select ready(Active Low)
    
    /******************* INPUT ********************/
    input wire CLK;
    input wire FRAME;
    input wire REST;
    input wire [3:0] CBE;
    input wire IRDY;
    
    /******************* OUTPUT *******************/
    output wire TRDY;
    output wire DEVSEL;
    
    /******************* INOUT ********************/
    inout [31:0] AD;
    
    /**************** PARAMETERS ***************/
    parameter BASE_AD = 32'hFFFF0000;
    
    /****************** INTERNAL ******************/
    reg [31:0] MEM [0:3]; // Device internal memory 4 words
    reg [31:0] TEMP_BUFFER [0:3]; // Device internal buffer 4 words
    reg [2:0]  INDEX ;  // used as a pointer
    reg DEVICE_READY;
    
    
    // Keep track of the transations on the bus
    // TRANSATION should be asserted up if there is
    // any transation on the bus
    reg TRANSATION;
    
    // TRANSATION_START will be asserted up if any transation started
    // (the half clock cycle before the transation)
    wire TRANSATION_START = ~TRANSATION & ~FRAME;
    // TRANSATION_END will be asserted if any transation end
    // (the half clock cycle after the transation)
    wire TRANSATION_END = TRANSATION & FRAME & IRDY;
    
    // The logic of tracking the current transation on the bus
    always @(posedge CLK or negedge REST) begin
        if (~REST)
            TRANSATION <= 0;
        else
            case (TRANSATION)
                1'b0: TRANSATION <= TRANSATION_START;
                1'b1: TRANSATION <= ~TRANSATION_END;
            endcase
    end
    
    // Save the address & the command in an internal buffers
    // TODO: Shoud be modified to map to the internal memery addres
    reg [31:0] ADRESS_BUFF;
    reg [3:0] COMMAND_BUFF;
    always @(posedge CLK) begin
        if (TRANSATION_START) begin
            ADRESS_BUFF <= AD;
            // We work on 32bit aligend address so we ignore
            // the first two bits
            INDEX        <= AD[3:2];
            COMMAND_BUFF <= CBE;
        end
    end
    
    // See if our device is the target
    // (The half clock cycle before the transation as TRANSATION_START)
    // We support form  32'hFFFF0000 to 32'hFFFF000F
    wire TARGETED = TRANSATION_START & ((AD - BASE_AD) >= 32'h0) & ((AD - BASE_AD) < 32'hF);
    
    // Assert the DEVICE_TRANSATION signal up if the current
    // transation is our transation
    // NOTE THE DIFFERENCE:
    // TRANSATION is up on every transation on the bus
    // DEVICE_TRANSATION is up in just our transation
    reg DEVICE_TRANSATION;
    always @(posedge CLK or negedge REST) begin
        if (~REST)
            DEVICE_TRANSATION <= 0;
        else
            case(TRANSATION)
                1'b0: DEVICE_TRANSATION <= TARGETED;
                1'b1: if (TRANSATION_END)
                DEVICE_TRANSATION <= 1'b0;
            endcase
    end
    
    // Keep track of the last byte to transfer
    // when the frame asserted up
    wire LAST_DATA_TRANSFER = FRAME & ~IRDY & ~TRDY;
    
    // Asserting DEVSEL
    // Storing it's state in and internal register will help us
    // to tri-state it after the transation ends to be used
    // by other slaves on the bus
    reg DEVSEL_BUFF;
    always @(posedge CLK or negedge REST) begin
        if (~REST)
            DEVSEL_BUFF <= 0;
        else
            case(TRANSATION)
                1'b0: DEVSEL_BUFF <= TARGETED; // fast
                1'b1: DEVSEL_BUFF <= DEVSEL_BUFF & ~LAST_DATA_TRANSFER;
            endcase
    end
    
    // Asserting TRDY
    // the same as DEVSEL but we might need to assert it up
    // during the transation
    reg TRDY_BUFF;
    always @(posedge CLK or negedge REST) begin
        if (~REST)
            TRDY_BUFF <= 0;
        else
            case(TRANSATION)
                1'b0: TRDY_BUFF <= TARGETED; // fast
                1'b1: TRDY_BUFF <= TRDY_BUFF & ~LAST_DATA_TRANSFER;
            endcase
    end
    
    // Asserting on negtive edge
    reg TRDY_BUFF_NEG;
    reg DEVSEL_BUFF_NEG;
    
    always @(negedge CLK or negedge REST) begin
        if (~REST) begin
            TRDY_BUFF_NEG   <= 0;
            DEVSEL_BUFF_NEG <= 0;
        end
        else begin
            TRDY_BUFF_NEG   <= TRDY_BUFF & DEVICE_READY;
            DEVSEL_BUFF_NEG <= DEVSEL_BUFF;
        end
    end
    
    // Asserting DEVSEL & TRDY down during the transaction or tri-state it
    assign DEVSEL = DEVICE_TRANSATION ? ~DEVSEL_BUFF_NEG : 1'bZ;
    assign TRDY   = DEVICE_TRANSATION ? ~TRDY_BUFF_NEG : 1'bZ;
    
    /**************** DEVICE INTERFACE ************/
    parameter READ_OP  = 4'b0110;
    parameter WRITE_OP = 4'b0111;
    
    // Mask to be used with write opeartion
    wire [31:0] MASK = {{8{CBE[3]}}, {8{CBE[2]}}, {8{CBE[1]}}, {8{CBE[0]}}};
    
    // Siganls to track the current operation
    wire DATA_WRITE = ~DEVSEL & (WRITE_OP == COMMAND_BUFF) & ~IRDY;
    wire DATA_READ  = ~DEVSEL & (READ_OP == COMMAND_BUFF) & ~IRDY & ~TRDY;
    
    // Write opeartion
    always @(posedge CLK or negedge REST) begin
        if (~REST) begin
            INDEX        <= 0;
            DEVICE_READY <= 1;
        end
        
        if (DATA_WRITE) begin
            if (INDEX < 4) begin
                DEVICE_READY <= 1;
                // Store only the Bytes enableld data
                MEM[INDEX] <= (MEM[INDEX] & ~MASK) | (AD & MASK);
                // Add one to the index to point at the next word
                INDEX <= INDEX + 1;
            end
            else begin
                // Move the data to temp buffer to be processed by the Device
                // Assert TRDY up during the operation for only one cycle
                // then wrap the INDEX to zero
                DEVICE_READY   <= 0;
                TEMP_BUFFER[0] <= MEM[0];
                TEMP_BUFFER[1] <= MEM[1];
                TEMP_BUFFER[2] <= MEM[2];
                TEMP_BUFFER[3] <= MEM[3];
                INDEX          <= 0;
            end
        end
        
    end
    
    
    // Read Operation
    reg [31:0] OUTPUT_BUFFER;
    reg AD_OUTPUT_EN;
    always @(negedge CLK or negedge REST) begin
        if (~REST)
            AD_OUTPUT_EN <= 0;
        else
            OUTPUT_BUFFER <= MEM[INDEX];
        
        if (DATA_READ) begin
            // the read opeation doeesn't have side effects
            // so we only wrap the index to zero
            INDEX        <= (INDEX > 3) ? 0 : INDEX;
            INDEX        <= INDEX + 1;
            AD_OUTPUT_EN <= 1;
        end
        else begin
            AD_OUTPUT_EN <= 0;
        end
    end
    
    // tri-state the AD to the output location
    assign AD = AD_OUTPUT_EN ? OUTPUT_BUFFER : 32'hZZZZZZZZ;
    
endmodule
