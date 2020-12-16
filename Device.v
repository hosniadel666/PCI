/*###############################################
#               DEVICE MODULE                   #
################################################*/

module Device(
FRAME,  // Transaction Frame
CLK, // Clock
RST, // Reset(Active Low)
AD, // Address and Data line time multiplexing 
CBE, // Control command
IRDY, // Initiator ready(Active Low)
TRDY, // Target ready(Active Low)
DEVSEL // Device select ready(Active Low)
);


/*################## INPUT ###################*/
input wire CLK;
input wire FRAME;
input wire RST;
input wire [3: 0] CBE;
input wire TRDY;

/*################## OUTPUT ##################*/
output reg IRDY;

/*################## INOUT ###################*/
inout wire [31: 0] AD;
inout wire DEVSEL;

/*################# INTERNAL #################*/
reg [31: 0] DEVICE_MEM [0: 99]; // Device memory
reg [31: 0] DEVICE_BUF; // Device internal buffer
reg [7: 0] INDEX;
reg [31: 0] DEVICE_AD, // parameter [31:0]DEVICE_AD = 8'hxxxx_xxxx 



initial begin: DEVICE_MEM_INIT
    integer i;
    for(i = 0; i < 100; i = i + 1) begin
    
        DEVICE_MEM[i] = (1 << 32) - 1;

    end
end

assign INDEX = 0;

// I will initialize signals to defaults in Device_tb.v 


always @(posedge CLK)
begin: MAIN
    if(!FRAME)
    begin: START_TRANSACTION

        if (AD == DEVICE_AD)
        begin: DEVICE_DECODED
            DEVSEL <= 1'b0;
            if(CBE == 4'b0111)
            begin: START_WRITE
                TRDY <= 1'b0;
                DEVICE_BUF <= AD;
                DEVICE_MEM[INDEX] <= DEVICE_BUF;
                INDEX = INDEX + 1;
                INDEX = (INDEX => 100)?0: INDEX; // IF I REMOVE FALSE FIELD WHAT WILL HAPPEN

            end
            else if(CBE == 4'b0110)
            begin: START_READ
                TRDY <= 1'b0;
                AD = DEVICE_MEM[0]; // WHAT IS THE EXPECTED RETURN VALUE
            end
        end

    end
endmodule






        