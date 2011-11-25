////////////////////////////////////////////////////////////////////
// MindWave Cat Ear Tuning Sketch
//
// Moves ears up and down according to the position of a 10K-ohm 
// potentiometer on analog pin 0
//
// Use this sketch to tune the ear position when assembling the 
// MindWave Cat Ears. See link for instructions:
// http://makeprojects.com/Project/MindWave-Cat-Ears/1627/
// 
// Adapted from example code by Neurosky Inc., and from the "Knob" 
// example distributed with the Arduino Servo library
// 
// Joshua DiMauro and Jeff Cutler, 2011
//
// https://github.com/jdimauro/MindWave-Cat-Ears
//
////////////////////////////////////////////////////////////////////

#define BAUDRATE 115200 // the wireless dongle operates at 115.2 Kbps

// Put a 10K-ohm potentiometer on analog pin 0
#define attentionPin 0 

int attention = 0;

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

// TODO: add a "range_pan" and "range_tilt" variable so that you only have to specify
// minimum value and specify max variables by adding/subtracting the range vars. 
                       
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

  r_tilt.attach(3);
  r_pan.attach(4);  
  l_tilt.attach(5); 
  l_pan.attach(6);

  WiggleEars(2);
  SweepToPosition(lp_max, lt_max, rp_max, rt_max, 100);

  Serial.begin(BAUDRATE);

}


/////////////
//MAIN LOOP//
/////////////
void loop() {
        
  int attval = analogRead(attentionPin);
  attention = map(attval, 0, 1023, 1, 100);
        
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

    // Tuning Output
    Serial.print("Attention: ");
    Serial.print(attention, DEC);
    Serial.print(", lp: ");
    Serial.print(lp, DEC);
    Serial.print(", lt: ");
    Serial.print(lt, DEC);
    Serial.print(", rp: ");
    Serial.print(rp, DEC);
    Serial.print(", rt: ");
    Serial.print(rt, DEC);
    Serial.print("\n");
  
  } else {
    
    // this used to have a set of randomized left ear, right ear, and both ear wiggles, but it got stuck in a loop.
    WiggleEars(3);
    attention = 85;
    delay(2000);

  } // end attention else


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