////////////////////////////////////////////////////////////////////
// MindWave Cat Ears
// 
// An arduino sketch to use a Neurosky MindWave headset in order to
// move a pair of ears using servos mounted on the headset
// 
// Adapted from example code by Neurosky Inc., and from the "Knob" 
// example distributed with the Arduino Servo library
// 
// Joshua DiMauro and Jeff Cutler, 2011
// 
// TODO LIST:
// 
// 1. make it easier to swap in a potentiometer to tune ear movement without a headset
// 2. re-work the servo positioning code to make it easier to tune
// 3. re-write the movement code to make movement less jerky 
// 4. re-write the movement function so it doesn't block the main loop
// 5. move to using the ITP "Brain" library
// 6. use randomized ear wiggle events at high attention (this was removed due to crashing)
////////////////////////////////////////////////////////////////////


#define LED 13          // status LED for Mindwave signal quality
#define BAUDRATE 115200 // the wireless dongle operates at 115.2 Kbps
#define DEBUGOUTPUT 0   // set to 1 if you want to debug

// checksum variables
byte generatedChecksum = 0;
byte checksum = 0;
int payloadLength = 0;
byte payloadData[64] = {
  0};
byte poorQuality = 0;
int attention = 0;
int meditation = 0;

// system variables
unsigned long lastReceivedPacket = 0;
boolean bigPacket = false;

// Cat ear servos 

#include <Servo.h>

Servo l_pan;
Servo l_tilt;
Servo r_pan;
Servo r_tilt;

int lp_pos = 1300;
int lt_pos = 2250;
int rp_pos = 1200;
int rt_pos = 650; 

// minimums            expected position
int lp_min = 1800;  // pointed all the way to the side
int lt_min = 1650;  // about ten degrees above horizontal
int rp_min = 700;   // 
int rt_min = 850;   // 
                       
// maximums            expected position
int lp_max = 1100;  // pointed forwards and just a tiny bit "in"
int lt_max = 1950;  // standing straight up, a bit "back"
int rp_max = 1400;  // 
int rt_max = 550;   // 


int att_high = 67;  // make ears stay up when "high enough"
int att_lo = 5;     // if high and lo are closer together, range of movement is reduced
int att_sup = 87;   // reduce this to make the ears easier to wiggle
int old_att = 0;

//////////////////////////
// Microprocessor Setup //
//////////////////////////
void setup() {
  // make random() function return non-repeatable random value
  randomSeed(analogRead(1));

  r_tilt.attach(3);
  r_pan.attach(4);  
  l_tilt.attach(5); 
  l_pan.attach(6);

  WiggleEars(2);
  SweepToPosition(lp_max, lt_max, rp_max, rt_max, 100);

  pinMode(LED, OUTPUT);
  Serial.begin(BAUDRATE);           // USB

  delay(3000) ;
  Serial.print(194,BYTE) ;

}

////////////////////////////////
// Read data from Serial UART //
////////////////////////////////
byte ReadOneByte() {
  int ByteRead;

  while(!Serial.available());
  ByteRead = Serial.read();

#if DEBUGOUTPUT
  Serial.print((char)ByteRead);   // echo the same byte out the USB serial (for debug purposes)
#endif

  return ByteRead;
}

/////////////
//MAIN LOOP//
/////////////
void loop() {


  // Look for sync bytes
   if(ReadOneByte() == 170) {
     if(ReadOneByte() == 170) {

      payloadLength = ReadOneByte();
      if(payloadLength > 169)                      //Payload length can not be greater than 169
          return;

      generatedChecksum = 0;
      for(int i = 0; i < payloadLength; i++) {
        payloadData[i] = ReadOneByte();            //Read payload into memory
        generatedChecksum += payloadData[i];
      }

      checksum = ReadOneByte();                      //Read checksum byte from stream
      generatedChecksum = 255 - generatedChecksum;   //Take one's compliment of generated checksum

        if(checksum == generatedChecksum) {

          poorQuality = 200;
          attention = 0;
          meditation = 0;

          for(int i = 0; i < payloadLength; i++) {    // Parse the payload
            switch (payloadData[i]) {
            case 2:
              i++;
              poorQuality = payloadData[i];
              bigPacket = true;
              break;
            case 4:
              i++;
              // comment out the following line if using a potentiometer on pin 0 to 
              // fake attention
              attention = payloadData[i];
              break;
            case 5:
              i++;
              meditation = payloadData[i];
              break;
            case 0x80:
              i = i + 3;
              break;
            case 0x83:
              i = i + 25;
              break;
            default:
              break;
            } // switch
          } // for loop

#if !DEBUGOUTPUT

        // Uncomment the following lines to fake attention with a potentiometer on pin 0
        
        // int attval = analogRead(attentionPin);
        // attention = map(attval, 0, 1023, 1, 100);
        // Serial.println(attention);

        // **** Move ears according to attention value ****
        
        if (attention > 0) {    // stops oscillation
          if (attention <= att_sup) {
            int lp = map(attention, att_lo, att_high, lp_min, lp_max);
            int lt = map(attention, att_lo, att_high, lt_min, lt_max);
            int rp = map(attention, att_lo, att_high, rp_min, rp_max);
            int rt = map(attention, att_lo, att_high, rt_min, rt_max);

            lp = constrain(lp, lp_max, lp_min);
            lt = constrain(lt, lt_min, lt_max);
            rp = constrain(rp, rp_min, rp_max);
            rt = constrain(rt, rt_max, rt_min);
            
            SweepToPosition(lp, lt, rp, rt, attention);
            
          }

          // if attention is higher than the att_sup threshold:
          else {
            WiggleEars(3);
            attention = 85;
            delay(2000);
          } // end attention else
        } // end if attention > 0

        if(bigPacket) {
          if(poorQuality == 0)
            digitalWrite(LED, HIGH);
          else
            digitalWrite(LED, LOW);
           Serial.print("PoorQuality: ");
           Serial.print(poorQuality, DEC);

           // The following is a hack to get around an intermittent crash that occurs
           // when using the MindWave wireless card on an unreliable power supply
           // …or possibly when The Stars Are Right. I have no idea.
           if (millis() - lastReceivedPacket > 99999999) {
            // Serial.println(" CRASH!");
            void (*softReset) (void) = 0; //declare reset function @ address 0
            softReset();
           }
           Serial.print(" Attention: ");
           Serial.print(attention, DEC);

           Serial.print(" Time since last packet: ");
           Serial.print(millis() - lastReceivedPacket, DEC);
           Serial.print(" ");
           lastReceivedPacket = millis();
           Serial.print("\n");

        }

#endif
        bigPacket = false;
      }
      else {
        // Checksum Error
      }  // end if else for checksum
    } // end if read 0xAA byte
  } // end if read 0xAA byte
}


void SweepToPosition(int lp, int lt, int rp, int rt, int att) {

  int init_lp = lp_pos;
  int init_lt = lt_pos;
  int init_rp = rp_pos;
  int init_rt = rt_pos;

  int d_lp = directionOfMovement(lp_pos, lp);
  int d_lt = directionOfMovement(lt_pos, lt);
  int d_rp = directionOfMovement(rp_pos, rp);
  int d_rt = directionOfMovement(rt_pos, rt);

  while (lp_pos!=lp || lt_pos!=lt || rp_pos!=rp || rt_pos!=rt) {
    lp_pos = lp_pos + d_lp;
    lt_pos = lt_pos + d_lt;
    rp_pos = rp_pos + d_rp;
    rt_pos = rt_pos + d_rt;
    lp_pos = constrain(lp_pos, min(init_lp, lp), max(init_lp, lp));
    lt_pos = constrain(lt_pos, min(init_lt, lt), max(init_lt, lt));
    rp_pos = constrain(rp_pos, min(init_rp, rp), max(init_rp, rp));
    rt_pos = constrain(rt_pos, min(init_rt, rt), max(init_rt, rt));
    l_pan.writeMicroseconds(lp_pos);
    l_tilt.writeMicroseconds(lt_pos);
    r_pan.writeMicroseconds(rp_pos);
    r_tilt.writeMicroseconds(rt_pos);

    // slow down movement when the change in attention values is small
     int att_diff = att - old_att;
     if (att == 200) {
       delay(1);
     } else if (abs(att_diff) < 4) {
       delay(7);
     } else if(abs(att_diff) < 12) {
       delay(4);
     } else if(abs(att_diff) < 25) {
       delay(3);
     } else {
       delay(2);
     } // end if att == 200
  } // end while
  old_att = att;
}

void WiggleEars(int count) {
  for (int i = 0; i < count; i++) {
    // maximums     1100, 1950, 1400, 550
    // minimums     1800, 1650, 700,  850
    SweepToPosition(1200, 1950, 1300, 550, 200);
    SweepToPosition(1100, 1850, 1400, 650, 200);
  }
  SweepToPosition(lp_max, lt_max, rp_max, rt_max, 100);
}

void WiggleInwards(int count) {
  // SweepToPosition(1300, 1950, 1600, 550, 100);
  for (int i = 0; i < count; i++) {
    // maximums     1100, 1950, 1400, 550
    // minimums     1800, 1650, 700,  850
    SweepToPosition(1350, 1950, 1600, 550, 200);
    SweepToPosition(1250, 1850, 1700, 650, 200);
  }
  SweepToPosition(lp_max, lt_max, rp_max, rt_max, 100);
}

void RightEarTwitch() {
  for (int i = 0; i < 2; i++) {
    // maximums     1100, 1950, 1400, 550
    // minimums     1800, 1650, 700,  850
    SweepToPosition(lp_max, lt_max, rp_max, rt_max, 200);
    SweepToPosition(lp_max, lt_max, 1300, 650, 200);
    SweepToPosition(lp_max, lt_max, rp_max, rt_max, 200);
    
  }
}

void LeftEarTwitch() {
  for (int i = 0; i < 2; i++) {
    // maximums     1100, 1950, 1400, 550
    // minimums     1800, 1650, 700,  850
    SweepToPosition(lp_max, lt_max, rp_max, rt_max, 200);
    SweepToPosition(1200, 1850, rp_max, rt_max, 200);
    SweepToPosition(lp_max, lt_max, rp_max, rt_max, 200);
    
  }
}

int directionOfMovement(int startPos, int endPos) {
  if (startPos < endPos) {
    return 1;
  }
  if (startPos == endPos) {
    return 0;
  }
  return -1;
}