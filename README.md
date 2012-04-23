# ISS tracker 

![Photo of the tracker in action](https://p.twimg.com/ArMjPLTCIAAmHgB.jpg)

## Changelog

## v0.2.0 
**Processing code**
* Total rewrite
* Use Firmata to allow Arduiono programming via Processing
* Pull live data from unnoficial heavens above API - http://uhaapi.com/
* Add live(ish) tracking map - updated every 60 seconds from http://www.heavens-above.com/

**Hardware setup**
* Green LED connected to PIN 8 to indicate the ISS is currently overhead
* Red LED connected to PIN 13 to indicate that the ISS is not currently visible
