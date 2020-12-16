/*###############################################
#            DEVICE Test Bench MODULE           #
################################################*/

module DEVICE_tb();
/*################## REG ##################*/
reg CLK;
reg RST;
reg FRAME;
reg [3:0] CBE;
wire IRDY;
/*################## NET ##################*/
wire [31: 0] AD;

wire TRDY;
wire DEVSEL;




Device D1(); // by position

initial 
begin: GENERATE_CLK 
    clk <= 1;
    always
    begin 
        #1 // f = ??
        clk <= ~clk;
    end
end


initial 
begin
/*################ TEST WRITE OPERATION #################*/

/*################ TEST READ OPERATION #################*/

end
endmodule

