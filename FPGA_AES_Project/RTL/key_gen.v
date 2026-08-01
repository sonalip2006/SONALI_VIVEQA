module key_gen #(parameter KEY_SIZE = 128, ROUNDS = 10) (
  input wire  [KEY_SIZE-1:0] key,
  output wire [(ROUNDS+1)*128-1:0] w
);

localparam WORDS_PER_ROW = KEY_SIZE/32; // number of words in each row 4, 6, 8
localparam N_WORDS = (ROUNDS+1)*4; // number of total words actually needed: 44, 52, 60
localparam K_ROUNDS = (KEY_SIZE == 128) ? 10 : (KEY_SIZE == 192) ? 8 : 7; // number of rows in key generation 10, 8, 7

// FIX: the generate loop below always produces a full row of WORDS_PER_ROW
// words per round, but N_WORDS (the count AES actually needs) is not always
// an exact multiple of WORDS_PER_ROW -- for AES-192 it generates 2 words more
// than needed, and for AES-256 it generates 4 words more than needed. The
// original code sized w_arr to N_WORDS, so those extra words were written
// out of bounds, causing a fatal simulation error for KEY_SIZE=192/256
// (KEY_SIZE=128 happened to divide evenly, which is why only that case
// worked). W_ARR_SIZE fits every word the loop actually writes; only the
// first N_WORDS of them are wired to the output below, exactly as before.
localparam W_ARR_SIZE = (K_ROUNDS+1)*WORDS_PER_ROW;

wire [31:0] w_arr [0:W_ARR_SIZE-1];
wire [31:0] gout_arr [0:ROUNDS-1];


genvar i;
generate
  for (i=0; i<N_WORDS; i=i+1) begin // connect the w_arr array of wires to the output wire w
    mybuf #(.WIDTH(32)) buf0(.in(w_arr[N_WORDS-1-i]), .out(w[i*32+31 : i*32]));
  end
endgenerate

genvar j;
generate
  for (j=0; j<KEY_SIZE/32; j=j+1) begin // assign each 4 bytes from the key in the corresponding w_arr
    mybuf #(.WIDTH(32)) bufw0 (w_arr[j] , {key[KEY_SIZE-1 -32*j: KEY_SIZE-8 -32*j], key[KEY_SIZE-9 -32*j : KEY_SIZE-16 -32*j], key[KEY_SIZE-17 -32*j : KEY_SIZE-24 -32*j], key[KEY_SIZE-25 -32*j : KEY_SIZE-32 -32*j]});
  end
endgenerate


genvar r, x, z;
generate
  for (r=0; r<K_ROUNDS; r=r+1 ) begin // Each round will generate its words, xors and g_block 
      g #(.ROUND(r+1)) g_0 (
        .win( w_arr[r*WORDS_PER_ROW + WORDS_PER_ROW-1] ), // always takes input from last word in the row
        .wout( gout_arr[r] )  // connect the output with gout array
      );
    for (x=0; x<WORDS_PER_ROW ; x=x+1 ) begin //Each xor has its own connections
      if(x == 0) begin // special treatment for the first in the row
        add_rk #(.WIDTH(32)) xor_0 (
          .in1(w_arr[r*WORDS_PER_ROW]), // first input from the above word
          .in2(gout_arr[r]),    // second input from the gout calculated above
          .out(w_arr[WORDS_PER_ROW + r*WORDS_PER_ROW]) // output is assigned for the first word in next row
        );
      end
      else if (ROUNDS == 14 && x == 4) begin // middle word in AES-256 has special treatment 
        wire [31:0] w_temp, w_temp2; // substituting the bytes from previous word using sbox blocks
        mybuf #(.WIDTH(32)) buf_tmp(.in(w_arr[x+WORDS_PER_ROW-1 + r*WORDS_PER_ROW]), .out(w_temp));
        for (z=0; z<4; z=z+1) begin
          sbox s4 (.in(w_temp[z*8+7 : z*8]), .out(w_temp2[z*8+7 : z*8]));
        end
        add_rk #(.WIDTH(32)) xor_4 (
          .in1(w_arr[x + r*WORDS_PER_ROW]), // first input from the above word 
          .in2(w_temp2), // second is from the previous substituted word
          .out(w_arr[x+WORDS_PER_ROW + r*WORDS_PER_ROW])  // output is assigned for the below word
        );
      end
      else begin
        add_rk #(.WIDTH(32)) xor_123 (
          .in1(w_arr[x + r*WORDS_PER_ROW]),  // first input from the above word
          .in2(w_arr[x+WORDS_PER_ROW-1 + r*WORDS_PER_ROW]), // second input from left the below word 
          .out(w_arr[x+WORDS_PER_ROW + r*WORDS_PER_ROW])  // output is assigned for the below word
        );
      end
    end
  end
endgenerate


endmodule
