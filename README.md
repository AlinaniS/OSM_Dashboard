# open_dashboard

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


# Summary
This project illustrates a GPS tracker strapped to a Tablet for visualization of an object.
We have an EE harrier Tab, coupled with (2) ESP32 dev modules and (2) GPS modules namely: NEO M8N AND NE0 7M GPS Module respectively.
The whole purpose of the device is to illustrate that tracking and displaying an object can be done using simple items and can easily be scaled upwards with more complexity and performance and visual appeal are needed by the customer, and this is illustrated by having a good sense of the basics so that they can be built on for further systems.
The android tablet has been debloated of all custom applications and bloatware that's typically found in it to maximize on space and RAM usage so that it is dedicated to the tablet's tracking capabilities.
Key attributes of the tablet include: (i) The capability to host a server to receive information from the GPS devices (ii) Co-ordinate GPS data amongst the two GPS devices and it's own internal GPS navigation system and use the appropriate co-ordinates amongst the devices to give the user the most accurate data/positioning that they can have at any particular point. (iii) Host a series of driver linked attributes like searchability, backtracking, and alternative stops as part of the android flutter UI. (iv) The ability to save GPS co-ordinates or main pin points along which an object has moved through onto the local storage of the tablet in an sqflite database as well as being able to sync to an online database to view location history remotely. (v) Implement voice search to reduce driving accidents on the road, link some APIs to some well know apps and acts as a full infortainment system. (iv) Add a feature to connect to another phone where android or iphone or some weird OS if available and use GPS data with in in colaboration to produce a higher quality infortainment Tracking system.
Hopefully this can workout before Friday!!!.
