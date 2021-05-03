/*###############################################
#               DEVICE MODULE                   #
################################################*/

module Device(
FRAME,  // Transaction Frame
CLK, // Clock
RST, // Asyncronous Reset(Active Low)
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
input wire IRDY;

/*################## OUTPUT ##################*/
output reg TRDY;
output reg DEVSEL;

/*################## INOUT ###################*/
inout [31: 0] AD;
//If you must use any port as inout, Here are few things to remember:
// You can't read and write inout port simultaneously, hence kept highZ for reading.
// inout port can NEVER be of type reg.
// There should be a condition at which it should be written. (data in mem should be written when Write = 1 and should be able to read when Write = 0).

/*################# INTERNAL #################*/
reg [31: 0] DEVICE_MEM [0: 99]; // Device memory
reg [31: 0] DEVICE_BUF; // Device internal buffer
reg [7: 0] INDEX ;
reg [31: 0] DEVICE_AD; // parameter [31:0]DEVICE_AD = 8'hxxxx_xxxx 
reg [31: 0] AD_REG;
reg AD_RW;

/*################ INOUT CONTROL ###############*/
assign AD = AD_RW? AD_REG: 32'hzzzz_zzzz;  



integer i;
initial begin: DEVICE_MEM_INIT
    DEVSEL = 1'b1;
    DEVICE_AD = 8'h0000_0000;
    INDEX = 0;
    DEVICE_BUF = 0; 
	AD_RW = 1;
	AD_REG = 8'h0000_0000;
	TRDY = 1'b1;
	

    for(i = 0; i < 100; i = i + 1) 
	begin
        // DEVICE_MEM[i] = (1 << 32) - 1;
		DEVICE_MEM[i] = 0;
    end
end

// I will initialize signals to defaults in Device_tb.v 


always @(posedge CLK)
begin: MAIN
    if(!FRAME && !IRDY)
    begin: START_TRANSACTION
		TRDY <= 1'b1;
		DEVSEL <= 1'b1;
		$display("hey iam in frame");
        if (AD == DEVICE_AD)
		
        begin: DEVICE_DECODED
			$display("hey iam in decoding");
            DEVSEL <= 1'b0;
            case(CBE)
                4'b0111: begin: START_WRITE
                    AD_RW = 1'b1;
                    $display("hey iam in write");
                    TRDY <= 1'b0;
                    //DEVICE_BUF <= AD; // Taking the bus's data
                    DEVICE_MEM[INDEX] <= AD;
                    INDEX = INDEX + 1; // why <= doesnot work,21w solved with =
                    INDEX = (INDEX > 99)?0: INDEX; // IF I REMOVE FALSE FIELD WHAT WILL HAPPEN
     
                end
                4'b0110: begin: START_READ
                    $display("hey iam in read");
                    TRDY <= 1'b0;
                    AD_RW = 1'b1;
                    AD_REG <= DEVICE_MEM[1]; // I need to put data on the bus	
                    
                end
                default: $display("ERROR IN CBE");
            endcase
        end

    end
	else begin
		TRDY <= 1'b1;
		DEVSEL <= 1'b1;
	end
end
endmodule






        