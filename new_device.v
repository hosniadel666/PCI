//`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:    19:41:34 12/25/2020
// Design Name:
// Module Name:    Device
// Project Name:
// Target Devices:
// Tool versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
/*************************************************
 *               DEVICE MODULE                   *
 *************************************************/


module Device(FRAME,
              CLK,    // Clock
              REST,   // Asyncronous Reset(Active Low)
              AD,     // Address and Data line time multiplexing
              CBE,    // Control command
              IRDY,   // Initiator ready(Active Low)
              TRDY,   // Target ready(Active Low)
              DEVSEL,
              STOP);
    
    /******************* INPUT ********************/
    input wire CLK;
    input wire FRAME;
    input wire REST;
    input wire [3:0] CBE;
    input wire IRDY;
    
    /******************* OUTPUT *******************/
    output wire TRDY;
    output wire DEVSEL;
    output wire STOP;
    
    /******************* INOUT ********************/
    inout [31:0] AD;
    
    /**************** PARAMETERS ***************/
    parameter BASE_AD  = 32'hFFFF0000;
    parameter READ_OP  = 4'b0110;
    parameter WRITE_OP = 4'b0111;
    
    /****************** INTERNAL ******************/
    reg [31:0] MEM [0:3]; // Device internal memory 4 words
    reg [31:0] TEMP_BUFFER [0:3]; // Device internal buffer 4 words
    reg [2:0]  INDEX_WRITE;  // used as pointer in case of write operation 
    reg [2:0]  INDEX_READ;  // used as pointer in case of read operation
    reg DEVICE_READY;  // used by the device to state that it's not ready
    
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
    reg [31:0] ADRESS_BUFF;
    reg [3:0] COMMAND_BUFF;
    reg FIRST_DATA_PHASE;
    always @(posedge CLK)
    begin
        if (TRANSATION_START) begin
            ADRESS_BUFF <= AD;
            // We work on 32bit aligend address so we ignore
            // the first two bits
            // INDEX_WRITE         <= AD[3:2];
            COMMAND_BUFF     <= CBE;
            FIRST_DATA_PHASE <= 1;
        end
        else begin
            FIRST_DATA_PHASE <= 0;
        end
    end
    
    
    // check of supported brust modes
    reg TARGET_ABORT;
    always @(posedge CLK or negedge REST) begin
        if (~REST) begin
            TARGET_ABORT <= 0;
        end
        else begin
            if (TRANSATION_START & (AD[1:0] != 2'b00))
            // unsupported burst mode
            // Disconnect with data
                TARGET_ABORT <= 1;
            else 
                case (TARGET_ABORT)
                    1'b0:  TARGET_ABORT <= 0;
                    1'b1: if (TRANSATION_END)
                    TARGET_ABORT <= 1'b0;
                endcase  
        end
    end

    // Disconnet with data 
    // in case of write operation delay one cycle to write the first data
    // in case of read operation delay one cycle to write the first data
    // it's delayed another cycle becasue of the turnaround cycle
    reg WRITE_ONE;
    reg READ_ONE;
    always @(posedge CLK or negedge REST) begin
         if (~REST) begin
             WRITE_ONE <= 1;
        READ_ONE <= 1;
        end
        else begin
        WRITE_ONE <= ~TARGET_ABORT;
        READ_ONE <= WRITE_ONE;
        end
    end


    // Disconnect without data in case of unsupported opeartion
    reg DISCONNECT_WITHOUT_DATA;
    always @(posedge CLK or negedge REST) begin
        if (~REST) begin
            DISCONNECT_WITHOUT_DATA <= 0;
        end
        else begin
            // TODO: Modify to all unsupported operations
            if (TRANSATION_START & (CBE[1:0] == 2'b0000))
            // unsupported operation
            // Disconnect with data
                DISCONNECT_WITHOUT_DATA <= 1;
            else
                case (DISCONNECT_WITHOUT_DATA)
                    1'b0: DISCONNECT_WITHOUT_DATA <= 0;
                    1'b1: if (TRANSATION_END)
                    DISCONNECT_WITHOUT_DATA <= 1'b0;
                endcase
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
    
    wire COMMOND_READ  = (COMMAND_BUFF == READ_OP);
    wire COMMOND_WRITE = (COMMAND_BUFF == WRITE_OP);
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
                1'b1: DEVSEL_BUFF <= DEVSEL_BUFF & ~LAST_DATA_TRANSFER & ~FRAME;
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
    reg TARGET_ABORT_NEG;
    always @(negedge CLK or negedge REST) begin
        if (~REST) begin
            TRDY_BUFF_NEG    <= 0;
            DEVSEL_BUFF_NEG  <= 0;
            TARGET_ABORT_NEG <= 0;
        end
        else begin
            TRDY_BUFF_NEG    <= TRDY_BUFF & DEVICE_READY & ~DISCONNECT_WITHOUT_DATA;
            DEVSEL_BUFF_NEG  <= DEVSEL_BUFF;
            TARGET_ABORT_NEG <= TARGET_ABORT & DISCONNECT_WITHOUT_DATA;
        end
    end
    
    // Asserting DEVSEL & TRDY down during the transaction or tri-state it
    assign DEVSEL = DEVICE_TRANSATION ? ~DEVSEL_BUFF_NEG : 1'bZ;
    assign TRDY   = DEVICE_TRANSATION ? ~TRDY_BUFF_NEG : 1'bZ;
    assign STOP   = DEVICE_TRANSATION ? ~TARGET_ABORT_NEG : 1'bZ;
    
    
    // Mask to be used with write opeartion
    wire [31:0] MASK = {{8{CBE[3]}}, {8{CBE[2]}}, {8{CBE[1]}}, {8{CBE[0]}}};
    
    
    // Siganls to track the current operation
    wire DATA_WRITE = ~DEVSEL & (WRITE_OP == COMMAND_BUFF) & ~IRDY & WRITE_ONE;
    wire DATA_READ  = ~DEVSEL & (READ_OP == COMMAND_BUFF) & ~IRDY & ~TRDY & READ_ONE;
    
    
    /*************************************************
     *               WRITE OPERATION                 *
     *************************************************/
    
    always @(posedge CLK or negedge REST)
    begin
        if (~REST) begin
            INDEX_WRITE        <= 0;
            DEVICE_READY <= 1;
        end
        else begin
            if (TRANSATION_START)
                INDEX_WRITE <= AD[3:2];
            else begin
                if (DATA_WRITE)
                begin
                    if (INDEX_WRITE < 4)
                    begin
                        DEVICE_READY <= 1;
                        // Store only the Bytes enableld data
                        MEM[INDEX_WRITE] <= (MEM[INDEX_WRITE] & ~MASK) | (AD & MASK);
                        // Add one to the index to point at the next word
                        INDEX_WRITE <= INDEX_WRITE + 1;
                    end
                    else begin
                        // Move the data to temp buffer to be processed by the Device
                        // Assert TRDY up during the operation for only one cycle
                        // then wrap the INDEX_WRITE to zero
                        DEVICE_READY   <= 0;
                        TEMP_BUFFER[0] <= MEM[0];
                        TEMP_BUFFER[1] <= MEM[1];
                        TEMP_BUFFER[2] <= MEM[2];
                        TEMP_BUFFER[3] <= MEM[3];
                        INDEX_WRITE          <= 0;
                    end
                end
            end
        end
    end
    
    /*************************************************
     *               READ OPERATION                  *
     *************************************************/
    reg [31:0] OUTPUT_BUFFER;
    reg AD_OUTPUT_EN;
    always @(negedge CLK) begin
        OUTPUT_BUFFER <= MEM[INDEX_READ];
    end
    
    always @(negedge CLK or negedge REST)
    begin
        if (~REST) begin
            AD_OUTPUT_EN <= 0;
            INDEX_READ   <= 0;
        end
        else begin
            if (FIRST_DATA_PHASE) begin
                INDEX_READ <= ADRESS_BUFF[3:2];
            end
            else begin
                if (DATA_READ) begin
                    // the read opeation doeesn't have side effects
                    // so we only wrap the index to zero
                    AD_OUTPUT_EN <= 1;
                    INDEX_READ   <= (INDEX_READ >= 3) ? 0 : INDEX_READ + 1;
                    
                end
                else begin
                    AD_OUTPUT_EN <= 0;
                end
            end
        end
        
    end
    // tri-state the AD to the output location
    assign AD = AD_OUTPUT_EN ? OUTPUT_BUFFER : 32'hZZZZZZZZ;
    
endmodule
