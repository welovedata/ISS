import cc.arduino.*;
import org.json.*;
import processing.serial.*;
import org.json.JSONObject;
import org.json.JSONArray;

String satelliteID = "25544";
String apiURL = "api.uhaapi.com";
String latitude = "51.76274";
String longitude = "-1.25793";

long imageUpdatePeriod = 1000 * 60; // 60 seconds

Date nextImageUpdate;

Satellite ISS;

Arduino arduino;

void setup()
{
  size(300,300);
  setupArduino();
  nextImageUpdate = new Date(0); // unix epoch
  updateStatus (false);
  loadData();
}

void setupArduino()
{
  arduino = new Arduino(this, Arduino.list()[0], 57600);
  arduino.pinMode(13, Arduino.OUTPUT); 
  arduino.pinMode(8, Arduino.OUTPUT); 
}

void loadData()
{
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

void updateStatus (Boolean isVisible)
{
  if (isVisible)
  {
    arduino.digitalWrite(8, Arduino.HIGH);
    arduino.digitalWrite(13, Arduino.LOW);
    println("It's overhead!");
  }
  else
  {
    arduino.digitalWrite(8, Arduino.LOW);
    arduino.digitalWrite(13, Arduino.HIGH);
  }
}

Boolean satelliteIsVisible ()
{
  return false;
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

void draw() 
{
  if (ISS.isOverhead())
  {
    updateStatus(true);
  }
  else
  {
    updateStatus(false);
  }
  // update with latest picture of where satellite is! 

  updateBackgroundImage ();
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
  double azimouth;
  double altitude;
  Date time;
  
  try
  {
    azimouth = data.getDouble("az");
    altitude = data.getDouble("alt");
    time = new Date(data.getLong("time") * 1000);
    return new PassPoint(time, altitude, azimouth);
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
  
  public Boolean isOverhead ()
  {
    for (int i = 0; i < this.passes.size(); i++)
    {
      Pass pass = (Pass)this.passes.get(i);
      if (pass.isNow())
      {
        return true;
      }
    }
    return false;
  }
}

class PassPoint 
{
  private double altitude;
  private double azimouth;
  private Date time;
  public PassPoint (Date date, double altitute, double azimouth)
  {
    this.time = date;
    this.altitude = altitude;
    this.azimouth = azimouth;
  }
  
  public Date getTime () 
  {
    return time;
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
    
    println("Forecasted pass time start: " + this.start.getTime());
  }
  
  public Boolean isNow ()
  {
    Date now = new Date();
    if (now.after(start.getTime()) && now.before(end.getTime()))
    {
      return true;
    }
    return false;
  }
}
