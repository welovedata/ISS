
import processing.serial.*;
import java.text.SimpleDateFormat;

Serial port;  // Create object from Serial class

long start;
long highest;
long end;

void setup() 
{
  size(200, 200);
  String portName = Serial.list()[0];
  port = new Serial(this, portName, 9600);

  background(0);
  stroke(255);
  frameRate(1);


  String[] lines = loadStrings("ISS10days.csv");
  String[] cells = split(lines[2], ',');
  
  for (int i = 0; i < cells.length; i++) {
    println(cells[i]);
  }
  SimpleDateFormat timeFormat = new SimpleDateFormat("yyyy dd MMM HH:mm:ss");
  try {
    start = timeFormat.parse("2012 " + cells[0].substring(1, cells[0].length()-1) + " " + cells[1]).getTime();
    highest = timeFormat.parse("2012 " + cells[0].substring(1, cells[0].length()-1) + " " + cells[3]).getTime();
    end = timeFormat.parse("2012 " + cells[0].substring(1, cells[0].length()-1) + " " + cells[4]).getTime();    
  } catch (ParseException e) {
    println(e);
  }
}

void draw() {
  int value;
  
  long now = System.currentTimeMillis();
  if (now < start) {
    // build up to visibility
    long secsTo = (start - now) / 1000;
    value = (int)map(secsTo, 20800, 0, 0, 127);
  } else if (now > end) {
    // moving away
    long secsSince = (now - end) / 1000;
    value = (int)map(secsSince, 0, 20800, 127, 0);
  } else {
    // visible!
    if (now < highest) {
      // on way to max
      long secsTo = (highest - now) / 1000;
      value = (int)map(secsTo, (highest-start) / 1000, 0, 128, 255);
    } else {
      // past max
      long secsSince = (end - now) / 1000;
      value = (int)map(secsSince, (end-highest) / 1000, 0, 255, 128);
    }
  }
  
  println(value);
  port.write(value);
}



