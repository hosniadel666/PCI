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
reg [7: 0] DEVICE_MEM [0: 99]; // Internal device memory 25-word
reg [31: 0] DEVICE_BUF; // Device internal buffer
reg [7: 0] INDEX ; // Index of internal memory of the device 
reg [31: 0] DEVICE_AD; // Device Address
reg [31: 0] AD_REG; // Address register to read or assign data from/to the address line
reg AD_RW; // Address read/write signal (Active Low)
reg TRANSACTION; //Transaction state (Active Low)
reg R; // Read State signal (Active Low)
reg W; // Write State signal (Active Low)
reg [3:0]BE;
reg [7: 0] INDEX_2 ; // Index of internal memory for read operation



/*################ INOUT CONTROL ###############*/
assign AD = AD_RW? AD_REG: 8'hzzzz_zzzz;  



integer i;
initial begin
	TRANSACTION = 1'b1;
    DEVSEL = 1'b1;
    DEVICE_AD = 8'h0000_0000;
    INDEX = 0;
	INDEX_2 = 0;
    DEVICE_BUF = 0; 
	AD_RW = 1;
	AD_REG = 8'h0000_0000;
	TRDY = 1'b1; 
	R = 1'b1;
	W = 1'b1; 

    for(i = 0; i < 100; i = i + 1) 
	begin
		if(i % 2 == 0)
         	DEVICE_MEM[i] = (1 << 8) - 1;
		else
			DEVICE_MEM[i] = 0;
    end
end


always @(negedge CLK)
begin
	if(!FRAME && !IRDY && !TRANSACTION)
	begin
		TRDY <= 1'b0;
		DEVSEL <= 1'b0;
	end
	else if(FRAME)
	begin
		AD_RW <= 1'b0;
		TRDY <= 1'b1;
		DEVSEL <= 1'b1;
		TRANSACTION <= 1'b1;
		R <= 1'b1;
		W <= 1'b1;
	end
end

always @(posedge CLK)
begin: MAIN
    if(!FRAME | !TRANSACTION)
    begin: START_TRANSACTION
	
		$display("hey iam in frame");
        if (TRANSACTION && AD == DEVICE_AD)
		begin
			$display("hey iam in decoding");
			TRANSACTION <= 1'b0;
		end

		begin
			if(CBE == 4'b0111 && W)
			begin
				W <= 1'b0; 
			end
			else if(!W)
			begin
				if(!IRDY && !TRDY)
				begin
					//BE <= CBE;
					AD_RW <= 1'b1;
                    INDEX = (INDEX > 99)?0: INDEX;
					// Store word in mem
     				DEVICE_MEM[INDEX] = (CBE[0])? AD[7:0]: DEVICE_MEM[INDEX];
                    INDEX = INDEX + 1; 
					DEVICE_MEM[INDEX] = (CBE[1])? AD[15:8]: DEVICE_MEM[INDEX];
                    INDEX = INDEX + 1; 
					DEVICE_MEM[INDEX] = (CBE[2])? AD[23:16]: DEVICE_MEM[INDEX];
                    INDEX = INDEX + 1; 
     				DEVICE_MEM[INDEX] = (CBE[3])? AD[31:24]: DEVICE_MEM[INDEX];
                    INDEX = INDEX + 1;

				end
			end
			else if(CBE == 4'b0110 && R)
			begin
				R <= 1'b0;
				INDEX_2 = 0;
			end
			else if(!R)
			begin
				if(!IRDY && !TRDY)
				begin
					AD_RW <= 1'b1;
                    AD_REG <= {DEVICE_MEM[INDEX_2], DEVICE_MEM[INDEX_2 + 1], DEVICE_MEM[INDEX_2 + 2], DEVICE_MEM[INDEX_2 + 3]}; 
					INDEX_2 = INDEX_2 + 4;
				end
			end
		end
    end

end
endmodule






        