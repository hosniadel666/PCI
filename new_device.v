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
              STOP,
              PAR);
    
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
    inout PAR;
    
    /**************** PARAMETERS *****************/
    parameter BASE_AD  = 32'hFFFF0000;
    parameter MEM_READ_C  = 4'b0110;
    parameter MEM_WRITE_C = 4'b0111;
    parameter MEM_READ_MUL_C  = 4'b1100;
    parameter MEM_READ_LINE_C  = 4'b1110;
    parameter MEM_WRITE_INVAL_C = 4'b1111;

    /************** PCI ENDPOINT ****************/
    
    reg DEVICE_READY;  // used by the device to state that it's not ready
    
    // Keep track of the transations on the bus
    // TRANSACTION should be asserted up if there is
    // any transation on the bus
    reg TRANSACTION;
    
    // TRANSACTION_START will be asserted up if any transation started
    // (the half clock cycle before the transation)
    wire TRANSACTION_START = ~TRANSACTION & ~FRAME;
    // TRANSACTION_END will be asserted if any transation end
    // (the half clock cycle after the transation)
    wire TRANSACTION_END = TRANSACTION & FRAME & IRDY;
    
    // The logic of tracking the current transation on the bus
    always @(posedge CLK or negedge REST) begin
        if (~REST)
            TRANSACTION <= 0;
        else
            case (TRANSACTION)
                1'b0: TRANSACTION <= TRANSACTION_START;
                1'b1: TRANSACTION <= ~TRANSACTION_END;
            endcase
    end
    
    // Save the address & the command in an internal buffers
    reg [31:0] ADRESS_BUFF;
    reg [3:0] COMMAND_BUFF;
    reg FIRST_DATA_PHASE;
    always @(posedge CLK)
    begin
        if (TRANSACTION_START) begin
            ADRESS_BUFF <= AD;
            // We work on 32bit aligend address so we ignore
            // the first two bits
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
            if (TRANSACTION_START & ((AD - BASE_AD) != 2'b00))
            // unsupported burst mode
            // Disconnect with data
                TARGET_ABORT <= 1;
            else
                case (TARGET_ABORT)
                    1'b0:  TARGET_ABORT <= 0;
                    1'b1: if (TRANSACTION_END | FRAME)
                    TARGET_ABORT <= 1'b0;
                endcase
        end
    end
    
    // Disconnet with data
    // dessert TRANSACTION_READY after the one data phase

    // TRANSACTION_READY is used to indcaite that will be the last data
    // to transfer from or to the device
    // once it's low it won't be up until the end of the transcation
    wire DISCONNECT = TARGET_ABORT & ~IRDY;
    reg TRANSACTION_READY;
    always @(posedge CLK or negedge REST) begin
        if (~REST) begin
            TRANSACTION_READY <= 1;
        end
        else begin
            case (TRANSACTION_READY)
                1'b1: TRANSACTION_READY <= ~DISCONNECT;
                1'b0: if (TRANSACTION_END | FRAME)
                            TRANSACTION_READY <= 1'b1;
            endcase
        end
    end
    
    // Disconnect without data in case of unsupported opeartion
    wire VAILD_COMMEND = (CBE == MEM_READ_C) |
                         (CBE == MEM_WRITE_C) |
                         (CBE == MEM_READ_MUL_C) |
                         (CBE == MEM_READ_LINE_C) |
                         (CBE == MEM_WRITE_INVAL_C);

    reg DISCONNECT_WITHOUT_DATA;
    always @(posedge CLK or negedge REST) begin
        if (~REST) begin
            DISCONNECT_WITHOUT_DATA <= 0;
        end
        else begin
            // TODO: Modify to all unsupported operations
            if (TRANSACTION_START & ~VAILD_COMMEND)
            // unsupported operation
            // Disconnect without data (retry)
                DISCONNECT_WITHOUT_DATA <= 1;
            else
                case (DISCONNECT_WITHOUT_DATA)
                    1'b0: DISCONNECT_WITHOUT_DATA <= 0;
                    1'b1: if (TRANSACTION_END| FRAME)
                    DISCONNECT_WITHOUT_DATA <= 1'b0;
                endcase
        end
    end
    
    // See if our device is the target
    // (The half clock cycle before the transation as TRANSACTION_START)
    // We support form  32'hFFFF0000 to 32'hFFFF000F
    wire TARGETED = TRANSACTION_START & ((AD - BASE_AD) >= 32'h0) & ((AD - BASE_AD) < 32'hF);
    
    // Assert the DEVICE_TRANSACTION signal up if the current
    // transation is our transation
    // NOTE THE DIFFERENCE:
    // TRANSACTION is up on every transation on the bus
    // DEVICE_TRANSACTION is up in just our transation
    reg DEVICE_TRANSACTION;
    always @(posedge CLK or negedge REST) begin
        if (~REST)
            DEVICE_TRANSACTION <= 0;
        else
            case(TRANSACTION)
                1'b0: DEVICE_TRANSACTION <= TARGETED;
                1'b1: if (TRANSACTION_END)
                DEVICE_TRANSACTION <= 1'b0;
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
            case(TRANSACTION)
                1'b0: DEVSEL_BUFF <= TARGETED; // fast
                1'b1: DEVSEL_BUFF <= DEVSEL_BUFF & ~LAST_DATA_TRANSFER & ~FRAME;
            endcase
    end

    // figure out if we read or write
    wire COMMOND_READ  = (COMMAND_BUFF == MEM_READ_C) | 
                         (COMMAND_BUFF == MEM_READ_MUL_C) |
                         (COMMAND_BUFF == MEM_READ_LINE_C) ;
    
    wire COMMOND_WRITE = (COMMAND_BUFF == MEM_WRITE_C) | 
                         (COMMAND_BUFF == MEM_WRITE_INVAL_C);
    
    // Asserting TRDY
    // the same as DEVSEL but we might need to assert it up
    // during the transation due to target abort
    wire STOPED = DISCONNECT_WITHOUT_DATA |
                 (DISCONNECT & COMMOND_WRITE) | 
                 (DISCONNECT & COMMOND_READ);
    reg TRDY_BUFF;
    always @(posedge CLK or negedge REST) begin
        if (~REST)
            TRDY_BUFF <= 0;
        else
            case(TRANSACTION)
                1'b0: TRDY_BUFF <= TARGETED; // fast
                1'b1: TRDY_BUFF <= TRDY_BUFF & ~LAST_DATA_TRANSFER & ~STOPED;
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
            TRDY_BUFF_NEG    <= TRDY_BUFF & DEVICE_READY & ~DISCONNECT_WITHOUT_DATA ;
            DEVSEL_BUFF_NEG  <= DEVSEL_BUFF;
            TARGET_ABORT_NEG <= TARGET_ABORT | DISCONNECT_WITHOUT_DATA;
        end
    end
    
    // Asserting DEVSEL & TRDY down during the transaction or tri-state it
    assign DEVSEL = DEVICE_TRANSACTION ? ~DEVSEL_BUFF_NEG : 1'bZ;
    assign TRDY   = DEVICE_TRANSACTION ? ~TRDY_BUFF_NEG : 1'bZ;
    assign STOP   = DEVICE_TRANSACTION ? ~TARGET_ABORT_NEG : 1'bZ;
    
    
    // Siganls to track the current operation
    wire DATA_WRITE = ~DEVSEL & COMMOND_WRITE & ~IRDY & TRANSACTION_READY;
    wire DATA_READ  = ~DEVSEL & COMMOND_READ & ~IRDY & ~TRDY & TRANSACTION_READY;
    
    /********* PARITY CALCULATION *********/
    wire PAR_DATA = ^AD;
    wire PAR_CBE  = ^CBE;
    wire PAR_ALL  = PAR_CBE ^ PAR_DATA;

    /********* PARITY REPORTING *********/

        
    
    /****************** INTERNAL ******************/
    reg [31:0] MEM [0:3]; // Device internal memory 4 words
    reg [31:0] INTERNAL_BUFFER [0:31]; // Device internal buffer 4 words
    reg [2:0]  INDEX_WRITE;  // used as pointer in case of write operation
    reg [2:0]  INDEX_READ;  // used as pointer in case of read operation
    reg [5:0]  INDEX_BUFFER;  // used as pointer in case of read operation
    
    /*************************************************
     *               WRITE OPERATION                 *
     *************************************************/
    // Mask to be used with write opeartion
    wire [31:0] MASK = {{8{CBE[3]}}, {8{CBE[2]}}, {8{CBE[1]}}, {8{CBE[0]}}};
    
    always @(posedge CLK or negedge REST)
    begin
        if (~REST) begin
            INDEX_WRITE  <= 0;
            INDEX_BUFFER <= 0;
            DEVICE_READY <= 1;
        end
        else begin
            if (TRANSACTION_START)
                INDEX_WRITE <= (AD - BASE_AD) >> 2;
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
                        INTERNAL_BUFFER[INDEX_BUFFER] <= MEM[0];
                        INTERNAL_BUFFER[INDEX_BUFFER + 1] <= MEM[1];
                        INTERNAL_BUFFER[INDEX_BUFFER + 2] <= MEM[2];
                        INTERNAL_BUFFER[INDEX_BUFFER + 3] <= MEM[3];
                        INDEX_WRITE  <= 0;
                        INDEX_BUFFER <= (INDEX_READ >= 30) ? 0 : INDEX_BUFFER + 4;
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
                INDEX_READ <= (ADRESS_BUFF - BASE_AD) >> 2;
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

    /*********  PARITY GENERATION *********/
    // get the parity at the postive edge 
    reg PAR_OUT;
    always@(posedge CLK or negedge REST) begin
        if(~REST)
            PAR_OUT <= 0;
        else
            PAR_OUT <= PAR_ALL;
    end

    // delay it to the negtive edge 
    // to be seen at the bus at the next cycle
    reg PAR_OUT_NEG;
    always@(negedge CLK or negedge REST) begin
        if(~REST)
            PAR_OUT <= 0;
        else
            PAR_OUT_NEG <= PAR_OUT;
    end

    assign PAR = AD_OUTPUT_EN ? PAR_OUT_NEG : 1'hZ;
    
endmodule
