import cc.arduino.*;
import org.json.*;
import processing.serial.*;
import org.json.JSONObject;
import org.json.JSONArray;

String satelliteID = "25544";
String apiURL = "api.uhaapi.com";
String latitude = "51.76274";
String longitude = "-3.25793";

long imageUpdatePeriod = 1000 * 60; // 60 seconds
long dataUpdatePeriod = 1000 * 60 * 60; // 1 hour

int altitudeIndicator = 1;
int altitudeOKPin = 1;
int altitudeOverflowPin = 1;

int azimouthIndicator = 10;
int azimouthOKPin = 1;
int azimouthOverflowPin = 1;



Date nextImageUpdate;
Date nextDataUpdate;

Satellite ISS;

Arduino arduino;

void setup()
{
  size(300,300);
  setupArduino();
  nextImageUpdate = new Date(0); // unix epoch
  nextDataUpdate = new Date(0);
  updateStatus (0, 0);
  loadData();
}

void setupArduino()
{
  arduino = new Arduino(this, Arduino.list()[0], 57600);
  arduino.pinMode(azimouthIndicator, Arduino.OUTPUT); 
  arduino.pinMode(azimouthOKPin, Arduino.OUTPUT); 
  arduino.pinMode(azimouthOverflowPin, Arduino.OUTPUT); 
  arduino.pinMode(altitudeIndicator, Arduino.OUTPUT); 
  arduino.pinMode(altitudeOKPin, Arduino.OUTPUT); 
  arduino.pinMode(altitudeOverflowPin, Arduino.OUTPUT); 
}
// this is wrong. altituddee takes a value between -90 - 90
void driveServo (double value, int servoPin, int okPin, int overflowPin)
{
  Boolean flipped = false;
  if (value >= 180)
  {
    flipped = true;
    value %= 180;
  }

  arduino.analogWrite(servoPin, (int)value);
  if (flipped)
  {
    arduino.digitalWrite(okPin, Arduino.LOW);
    arduino.digitalWrite(overflowPin, Arduino.HIGH);
  }
  else
  {
    arduino.digitalWrite(okPin, Arduino.HIGH);
    arduino.digitalWrite(overflowPin, Arduino.LOW);
  }
}

void updateStatus (double altitude, double azimouth)
{ 
  driveServo (altitude, altitudeIndicator, altitudeOKPin, altitudeOverflowPin);
  driveServo (azimouth, azimouthIndicator, azimouthOKPin, azimouthOverflowPin);
}

void updateBackgroundImage ()
{
  Date now = new Date();
  if (now.after(nextImageUpdate))
  {
    println ("Updating orbital position image");
    long nextUpdate = now.getTime() + imageUpdatePeriod;
    nextImageUpdate = new Date(nextUpdate);
    PImage img = loadImage("http://www.heavens-above.com/orbitdisplay.aspx?icon=iss&width=300&height=300&satid=25544", "png");
    image(img, 0, 0);
  }
}

void loadData()
{
  println ("Updating orbital data");
  Date now = new Date();
  long nextUpdate = now.getTime() + dataUpdatePeriod;
  nextDataUpdate = new Date(nextUpdate);
  String[] response;
  String data;
  JSONObject json;
  String url = "http://" + apiURL + "/satellites/" + satelliteID + "/passes?lat=" + latitude + "&lng=" + longitude;
  
  println(url);
  
  response = loadStrings(url);
  data = join(response, "");

  
  try
  {
    json = new JSONObject(data);
  }
  catch (Exception e)
  {
    println("could not load JSON feed");
    json = new JSONObject();
  }
  ISS = new Satellite(json);
}

void draw() 
{
  Date now = new Date();
  updateStatus(ISS.getAltitudeAt(now), ISS.getAzimouthAt(now));
  
  if (now.after(nextDataUpdate))
  {
    loadData();
  }
  if (now.after(nextImageUpdate))
  {
    updateBackgroundImage ();
  }

  delay (2000);
}

Pass generatePass (JSONObject data) throws Exception
{
  Pass pass;
  try
  {
    PassPoint start = generatePassPoint (data.getJSONObject("start"));
    PassPoint middle = generatePassPoint (data.getJSONObject("max"));
    PassPoint end = generatePassPoint (data.getJSONObject("end"));
    return new Pass(start, middle, end);
  }
  catch (Exception e)
  {
    throw e;
  }
}

PassPoint generatePassPoint(JSONObject data) throws Exception
{
  PassPoint passPoint;
  SkyPosition position;
  Date time;
  
  try
  {
    position = new SkyPosition(data.getDouble("alt"), data.getDouble("az"));
    time = new Date(data.getLong("time") * 1000);
    return new PassPoint(time, position);
  }
  catch (Exception e)
  {
    throw e;
  }
}

class Satellite 
{
  private JSONObject data;
  private ArrayList passes;
  
  public Satellite (JSONObject data)
  {
    this.passes = new ArrayList ();
    this.data = data;
    this.setPassTimes (data);
  }
  
  private void setPassTimes (JSONObject data)
  {
    JSONArray passes = data.getJSONArray("results");
    for (int i = 0; i < passes.length(); i++)
    {
      try
      {
        this.passes.add(generatePass(passes.getJSONObject(i)));
      }
      catch (Exception e)
      {
        println("failed to load pass data in Satellite.setPassTimes - trying next pass");
      }
    }
  }
  
  public double getAltitudeAt (Date time)
  {
    return this.getPositionAt(time).getAltitude();
  }
  
  public double getAzimouthAt (Date time)
  {
    return this.getPositionAt(time).getAzimouth();
  }
  
  public SkyPosition getPositionAt (Date time)
  {
    try
    {
      SkyPosition position;
      Pass pass = this.getOverheadPassAt (time);
      
      position = pass.getPositionAt (time);
      return position;
    }
    catch (Exception e)
    {
      return new SkyPosition(0.0, 0.0);
    }
  }
  
  public Pass getOverheadPassAt (Date time) throws Exception // no pass overhead at that time
  {
    for (int i = 0; i < this.passes.size(); i++)
    {
      Pass pass = (Pass)this.passes.get(i);
      if (pass.isOverheadAt(time))
      {
        return pass;
      }
    }
    throw new Exception();
  }
  
  public Boolean isOverhead (Date time)
  {
    try
    {
      this.getOverheadPassAt (time);
      return true;
    }
    catch (Exception e)
    {
      return false;
    }
  }

}

class PassPoint 
{
  private SkyPosition position;
  private Date time;
  public PassPoint (Date date, SkyPosition position)
  {
    this.time = date;
    this.position = position;
  }
  
  public Date getTime () 
  {
    return time;
  }
  
  public double getAzimouth ()
  {
    return position.getAzimouth();
  }
  
  public double getAltitude ()
  {
    return position.getAltitude();
  }
}

class Pass
{
  private String data;
  private PassPoint start;
  private PassPoint middle;
  private PassPoint end;
  public Pass (PassPoint start, PassPoint middle, PassPoint end) 
  {
    this.start = start;
    this.middle = middle;
    this.end = end;
    
    println("Forecasted pass time start: " + start.getTime());
    println("Forecasted start az: " + start.getAzimouth());
    println("Forecasted end az: " + end.getAzimouth());
  }
  
  public Boolean isOverheadAt (Date time)
  {
    return (time.after(start.getTime()) && time.before(end.getTime()));
  }
  
  public SkyPosition getPositionAt (Date time)
  {
    long passLength = end.getTime().getTime() - start.getTime().getTime();
    long passCovered = time.getTime() - start.getTime().getTime();
    double ratio = (double)passCovered / (double)passLength;
    
    double startAzimouth = start.getAzimouth();
    double endAzimouth = end.getAzimouth ();
    double currentAzimouth = startAzimouth + (endAzimouth - startAzimouth) * ratio;
    
    double startAltitude = start.getAltitude();
    double endAltitude = end.getAltitude ();
    double currentAltitude = startAltitude + (endAltitude - startAltitude) * ratio;
    
    return new SkyPosition(currentAltitude, currentAzimouth);
  }
}

class SkyPosition
{
  private double azimouth;
  private double altitude;
  
  public SkyPosition (double altitude, double azimouth)
  {
    this.azimouth = azimouth;
    this.altitude = altitude;
  }
  
  public double getAzimouth () 
  {
    return this.azimouth;
  }
  
  public double getAltitude ()
  {
    return this.altitude;
  }
}
