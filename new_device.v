/*************************************************
 *               DEVICE MODULE                   *
 *************************************************/

// Two problems for now
// 1. fast device select
// 2. I was depending that the output would be slow
//    around the negtive edge but the ouput appears
//    immediately at the pos edge
//    may be we should increases the clk 
// 3. I didn't do the acutal reading & writing yet

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
    parameter DEVICE_AD = 32'h0000FFFF; // reg [31:0] DEVICE_AD;
    
    
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
            ADRESS_BUFF  <= AD;
            COMMAND_BUFF <= CBE;
        end
    end
    
    // See if our device is the target
    // (The half clock cycle before the transation as TRANSATION_START)
    // TODO: Shoud be modified to support a range of addreces
    wire TARGETED = TRANSATION_START & (AD == DEVICE_AD);
    
    // Assert the DEVSEL_TRANSATION signal up if the current
    // transation is our transation
    // NOTE THE DIFFERENCE:
    // TRANSATION is up on every transation on the bus
    // DEVSEL_TRANSATION is up in just our transation
    reg DEVSEL_TRANSATION;
    always @(posedge CLK or negedge REST) begin
        if (~REST)
            DEVSEL_TRANSATION <= 0;
        else
            case(TRANSATION)
                1'b0: DEVSEL_TRANSATION <= TARGETED;
                1'b1: if (TRANSATION_END)
                DEVSEL_TRANSATION <= 1'b0;
            endcase
    end
    
    // TODO:
    // the next section needs to be checked for
    // the turnaround cycle & tri-state or zero
    // for now I think it's fast device select
    // and I done't konw how to delay it 
    
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
    
    // Asserting DEVSEL down during the transaction or tri-state it
    assign DEVSEL = DEVSEL_TRANSATION ? ~DEVSEL_BUFF : 1'bZ;
    
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
    assign TRDY = DEVSEL_TRANSATION ? ~TRDY_BUFF : 1'bZ;
    
    /****************** INTERNAL ******************/
    reg [31:0] MEM [0:31]; // Device memory 32 word
    reg [31:0] BUF; // Device internal buffer
    reg [7:0]  INDEX ;
    reg [31:0] AD_REG;
    reg AD_RW;
    
    reg R;
    reg W;

    /**************** DEVICE INTERFACE ************/
    
    // reg [31:0] DATA_BUFF;
    // wire [31:0] MASK = {{8{CBE[3]}}, {8{CBE[2]}}, {8{CBE[1]}}, {8{CBE[0]}}};
    // always @(posedge CLK or negedge REST) begin
    //     if (~REST)
    //     else
    //         MEM[INDEX] <= (MEM[INDEX] & ~MASK) | (AD & MASK);
    
    // end
    
    
    
endmodule
