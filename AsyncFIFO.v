/********************************************************************/
								/*Gray code modules*/
/********************************************************************/
//Binary to Gray code converter
module BinaryToGray #(
  parameter N = 7
)(
  input [N-1:0] binary,
  output reg [N-1:0] gray
);

  genvar i;
  
  generate
    for (i = 0; i < N; i = i + 1) begin : XOR_Gates
      always @(*) begin
        if (i == 0)
          gray[i] = binary[i];
        else
          gray[i] = binary[i-1] ^ binary[i];
      end
    end
  endgenerate
  
endmodule

//Gray to Binary converter
module GrayToBinary #(
  parameter N = 7
)(
  input [N-1:0] gray,
  output reg [N-1:0] binary
);

  genvar i;
  
  generate
    for (i = 0; i < N; i = i + 1) begin : XOR_Gates
      always @(*) begin
        if (i == 0)
          binary[i] = gray[i];
        else
          binary[i] = binary[i-1] ^ gray[i];
      end
    end
  endgenerate
  
endmodule

/********************************************************************/
								/*FIFO Code*/
/********************************************************************/
/*
Problem Statement
Write frequency: 80Mhz
Read frequency:  50Mhz
Burst length: Number of data to be transferred = 120
No ideal cycles between reads and writes


Working:
Time required to write one data item: 1/80Mhz = 12.5 ns
Time required to write all ht data in burst = 120*12.5ns = 1500 ns
Time required to read one data item = 1/50Mhz = 20ns
no. of data items read in 1500ns = 1500ns/20ns = 75
Remaining no. of items to be stored in the FIFO = 120 - 75 = 45

so we will keep the FIFO depth as 64 so 6 bits are required to store the pointer addresses. 
We are over-designing the FIFO still we will take measures to make sure the two-cycle delay of the synchronizers is taken care of.

Data getting written after each 12.5ns
Data is getting read after each 20ns

Assume that writing and reading are taking place at the same time.

The clock edges are as below:(Assume timescape as 1ns)
For wclk:
0 | 12.5 | 25 | 37.5 | 50 | 62.5 | 75 | 87.5 | 100
w_ptr:
0 | 1    | 2  | 3    | 4  | 5    | 6  | 7    | 8

For rclk:
21 | 41 | 61 | 81 | 101
r_ptr:
0  | 1  | 2  | 3  | 4

FIFO Full Condition:

Let's see the comparison that takes place at the read domain at 101ns.
The read pointer is 4 and the write pointer that is present at the read domain is from 2 clock cycles earlier.
so we need to check what was the write pointer at 61ns. The w_ptr is also 4. But the actual value would be 8. 
So the actual w_ptr can be 4 ahead of what was read. So we can keep a buffer of 4 for w_ptr to check FIFO full condition.

FIFO Empty Condition:
Let's see the comparison that takes place at the read domain at 100ns.
The write pointer is 7 at the write clock domain. The value read at write domain is 2 cycles old i.e. at 75ns.
The read value will be 2. But the actual value is 3. So we need a buffer of 1 for the read pointer.





*/




module AsyncFIFO
(input [7:0]data_in,
input w_en,
input r_en,
input wclk,
input rclk,
output reg [7:0]data_out,
output full,
output empty
);




//Eight entry queue with 8bit entries
reg [7:0] FIFOreg [0:63];

//Write and read pointers
reg [5:0] w_ptr;
reg [5:0] r_ptr;

//Overflow bits for detecting if queue is empty of full
reg w_ovf;
reg r_ovf; 

//After the gray to binary conversions
wire [5:0] w_ptr_r;
wire [5:0] r_ptr_w;
wire w_ovf_r;
wire r_ovf_w;



//Gray code Handling regist ers
wire [6:0] g_w_ptr;
wire [6:0] g_r_ptr;

reg [6:0] g_w_ptr_0;
reg [6:0] g_r_ptr_0;

reg [6:0] g_w_ptr_sync;
reg [6:0] g_r_ptr_sync;


 

//empty and full registers
reg full_reg;
reg empty_reg;

//Always block for writing
always@(posedge wclk)
begin
	if(w_en)
	begin
		if(full_reg!=1'b1) //check if queue is not full
		begin
			FIFOreg[w_ptr]=data_in;
			{w_ovf,w_ptr}={w_ovf,w_ptr}+1'b1;
			
		end
	end
end

//Always block for reading
always@(posedge rclk)
begin
	if(r_en)
	begin
		if(empty_reg!=1'b1) //check if queue is not full
		begin
			data_out=FIFOreg[r_ptr];
			{r_ovf,r_ptr}={r_ovf,r_ptr}+1'b1;
			
		end
	end
end

always@(posedge wclk)
begin
	full_reg = (w_ptr_r==r_ptr) && (w_ovf_r!=r_ovf);
end

always@(posedge rclk)
begin
	empty_reg = (w_ptr==r_ptr_w) && (w_ovf==r_ovf_w);
end

//Binary to Gray conversion
BinaryToGray b2gw(.binary({w_ovf,w_ptr}),.gray(g_w_ptr));
BinaryToGray b2gr(.binary({r_ovf,r_ptr}),.gray(g_r_ptr));




//The double synchronizers
always@(posedge wclk)
begin
	g_w_ptr_0=g_w_ptr;
	g_w_ptr_sync=g_w_ptr_0;
end


always@(posedge rclk)
begin
	g_r_ptr_0=g_r_ptr;
	g_r_ptr_sync=g_r_ptr_0;
end


//Gray to Binary Conversion
GrayToBinary g2bw(.gray(g_w_ptr_sync),.binary({w_ovf_r,w_ptr_r}));
GrayToBinary g2br(.gray(g_r_ptr_sync),.binary({r_ovf_w,r_ptr_w}));



//Condition for queue empty
assign full = full_reg; 
assign empty = empty_reg; 

//Initial block
initial
begin
	{w_ovf,w_ptr}<=7'd0;
	{r_ovf,r_ptr}<=7'd0;
	full_reg<=1'b0;
	empty_reg<=1'b0;
end
endmodule
