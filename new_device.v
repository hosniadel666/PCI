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
    parameter BASE_AD           = 32'hFFFF0000;
    parameter MEM_READ_C        = 4'b0110;
    parameter MEM_WRITE_C       = 4'b0111;
    parameter MEM_READ_MUL_C    = 4'b1100;
    parameter MEM_READ_LINE_C   = 4'b1110;
    parameter MEM_WRITE_INVAL_C = 4'b1111;
    
    /************** PCI ENDPOINT ****************/
    
    reg DEVICE_READY;  // used by the device to state that it's not ready
    
    // Perserving the values of tri-state outputs
    reg TRDY_INT;
    reg DEVSEL_INT;
    reg STOP_INT;
    
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
    wire LAST_DATA_TRANSFER = FRAME & ~IRDY & ~TRDY_INT;
    
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
    wire COMMOND_READ = (COMMAND_BUFF == MEM_READ_C) |
                        (COMMAND_BUFF == MEM_READ_MUL_C) |
                        (COMMAND_BUFF == MEM_READ_LINE_C) ;
    
    wire COMMOND_WRITE = (COMMAND_BUFF == MEM_WRITE_C) |
                         (COMMAND_BUFF == MEM_WRITE_INVAL_C);
    
    // Asserting TRDY
    // the same as DEVSEL but we might need to assert it up
    // during the transation due to target abort
    wire STOPED = DISCONNECT_WITHOUT_DATA |
                 (DISCONNECT & COMMOND_WRITE) |
                 (~TRANSACTION_READY & COMMOND_READ);
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
    always @(negedge CLK or negedge REST) begin
        if (~REST) begin
            TRDY_INT   <= 1;
            DEVSEL_INT <= 1;
            STOP_INT   <= 1;
        end
        else begin
            TRDY_INT   <= ~(TRDY_BUFF & DEVICE_READY & ~DISCONNECT_WITHOUT_DATA) ;
            DEVSEL_INT <= ~(DEVSEL_BUFF);
            STOP_INT   <= ~(TARGET_ABORT | DISCONNECT_WITHOUT_DATA);
        end
    end
    
    // Asserting DEVSEL & TRDY down during the transaction or tri-state it
    assign DEVSEL = DEVICE_TRANSACTION ? DEVSEL_INT : 1'bZ;
    assign TRDY   = DEVICE_TRANSACTION ? TRDY_INT : 1'bZ;
    assign STOP   = DEVICE_TRANSACTION ? STOP_INT : 1'bZ;
    
    
    // Siganls to track the current operation
    wire DATA_WRITE = ~DEVSEL_INT & COMMOND_WRITE & ~IRDY & TRANSACTION_READY;
    
    // as we read at the negtive edge
    // we need capture DATA_READ at the postive edge
    // notoice that we used a wire with DATA_WRITE as we write
    // at the postive edge already
    reg DATA_READ;
    always @(posedge CLK) begin
        DATA_READ <= ~DEVSEL_INT & COMMOND_READ & ~FRAME & ~IRDY & ~TRDY_INT & TRANSACTION_READY;
    end
    
    /****************** INTERNAL ******************/
    reg [31:0] MEM [0:3]; // Device internal memory 4 words
    reg [31:0] INTERNAL_BUFFER [0:31]; // Device internal buffer 4 words
    reg [1:0]  INDEX_WRITE;  // used as pointer in case of write operation
    reg [1:0]  INDEX_READ;  // used as pointer in case of read operation
    reg [1:0]  INDEX_BUFFER;  // used as pointer in case of read operation
    
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
                    if (~DEVICE_READY) begin
                        INTERNAL_BUFFER[INDEX_BUFFER]     <= MEM[0];
                        INTERNAL_BUFFER[INDEX_BUFFER + 1] <= MEM[1];
                        INTERNAL_BUFFER[INDEX_BUFFER + 2] <= MEM[2];
                        INTERNAL_BUFFER[INDEX_BUFFER + 3] <= MEM[3];
                        INDEX_BUFFER                      <= INDEX_BUFFER + 4;
                        DEVICE_READY                      <= 1;
                    end
                    else begin
                        // if we reached the last byte reserve the next
                        // cycle for moveing the data to the buffer
                        if (INDEX_WRITE == 3)
                            DEVICE_READY <= 0;
                        else
                            DEVICE_READY <= 1;
                        // Store only the Bytes enableld data
                        MEM[INDEX_WRITE] <= (MEM[INDEX_WRITE] & ~MASK) | (AD & MASK);
                        // Add one to the index to point at the next word
                        INDEX_WRITE <= INDEX_WRITE + 1;
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
    
    always @(negedge CLK or negedge REST) begin
        if (~REST) begin
            OUTPUT_BUFFER <= 32'hFFFF_FFFF;
        end
        else begin
            OUTPUT_BUFFER <= MEM[INDEX_READ];
        end
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
                    INDEX_READ   <= INDEX_READ + 1;
                end
                else begin
                    AD_OUTPUT_EN <= 0;
                end
            end
        end
        
    end
    // tri-state the AD to the output location
    assign AD = AD_OUTPUT_EN ? OUTPUT_BUFFER : 32'hZZZZZZZZ;
    
    /********* PARITY CALCULATION *********/
    wire PAR_DATA = ^AD;
    wire PAR_CBE  = ^CBE;
    wire PAR_ALL  = PAR_CBE ^ PAR_DATA;
    
    /********* PARITY REPORTING *********/
    
    
    /*********  PARITY GENERATION *********/
    // get the parity at the postive edge
    reg PAR_OUT;
    always@(posedge CLK or negedge REST) begin
        if (~REST)
            PAR_OUT <= 0;
        else
            PAR_OUT <= PAR_ALL;
    end
    
    // delay it to the negtive edge
    // to be seen at the bus at the next cycle
    reg PAR_INT;
    always@(negedge CLK or negedge REST) begin
        if (~REST)
            PAR_INT <= 0;
        else
            PAR_INT <= PAR_OUT;
    end
    
    // parity is enabeled one cycle after the data
    reg PAR_OUTPUT_EN;
    always @(negedge CLK or negedge REST) begin
        if (~REST) begin
            PAR_OUTPUT_EN <= 0;
        end
        else begin
            PAR_OUTPUT_EN <= AD_OUTPUT_EN;
        end
    end
    
    assign PAR = PAR_OUTPUT_EN ? PAR_INT : 1'hZ;
    
endmodule
