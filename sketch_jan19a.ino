#include <ESP8266WiFi.h>
#include <Firebase_ESP_Client.h>
#include <Servo.h>

// Ultrasonic Sensor Library
#define TRIG_FOOD 5   // GPIO5 (D1) for Food Level Sensor
#define ECHO_FOOD 4   // GPIO4 (D2) for Food Level Sensor
#define TRIG_WATER 13  // GPIO13 (D7) for Water Level Sensor
#define ECHO_WATER 12  // GPIO12 (D6) for Water Level Sensor

// Wi-Fi Credentials
#define WIFI_SSID "Mobitel_4G_B6CD8"
#define WIFI_PASSWORD "9T9G9RDELFH"

// Firebase Configuration
FirebaseConfig firebaseConfig;
FirebaseAuth firebaseAuth;
FirebaseData firebaseData;

// Servo & Motor Configurations
Servo servo;
#define SERVO_PIN 14        // GPIO14 (D5) for Servo Motor
#define WATER_PUMP_PIN 17   // GPIO15 (D8) for Water Pump

// Threshold Values
#define FOOD_THRESHOLD 13  // cm (Below this level triggers alert)
#define WATER_THRESHOLD 15 // m (Below this level triggers alert)

// Servo Positions
int feedPosition = 90;   // Position for feeding
int startPosition = 0;   // Starting position

void setup() {
    Serial.begin(115200);

    // Connect to Wi-Fi
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    Serial.print("Connecting to Wi-Fi");
    while (WiFi.status() != WL_CONNECTED) {
        delay(1000);
        Serial.print(".");
    }
    Serial.println("\nWi-Fi connected");

    // Configure Firebase
    firebaseConfig.host = "petfeed-7b214-default-rtdb.asia-southeast1.firebasedatabase.app/";
    firebaseConfig.signer.tokens.legacy_token = "WjS7w8HmOnGCtMRwT8VGGH6nlrFYClfvbCS84FRD";
    Firebase.begin(&firebaseConfig, &firebaseAuth);

    // Servo Setup
    servo.attach(SERVO_PIN);
    servo.write(startPosition); // Initial position
    Serial.println("Servo motor initialized");

    // Water Pump Setup
    pinMode(WATER_PUMP_PIN, OUTPUT);
    digitalWrite(WATER_PUMP_PIN, LOW); // Start with pump OFF
    Serial.println("Water Pump initialized");

    // Ultrasonic Sensor Pins
    pinMode(TRIG_FOOD, OUTPUT);
    pinMode(ECHO_FOOD, INPUT);
    pinMode(TRIG_WATER, OUTPUT);
    pinMode(ECHO_WATER, INPUT);
}

void loop() {
    // Handle Feeding Mechanism
    if (Firebase.RTDB.getString(&firebaseData, "/feedCommand")) {
        if (firebaseData.dataType() == "string") {
            String feedCommand = firebaseData.stringData();
            if (feedCommand == "true" && servo.read() != feedPosition) {
                servo.write(feedPosition);
                Serial.println("Feeding: Servo moved to 90° position");
                Firebase.RTDB.setString(&firebaseData, "/feedLogs/" + String(millis()), "Feed pressed");
            } else if (feedCommand == "false" && servo.read() != startPosition) {
                servo.write(startPosition);
                Serial.println("Feeding: Servo returned to start position");
                Firebase.RTDB.setString(&firebaseData, "/feedLogs/" + String(millis()), "Feed released");
            }
        }
    }

    // Handle Water Pump
    if (Firebase.RTDB.getString(&firebaseData, "/waterCommand")) {
        if (firebaseData.dataType() == "string") {
            String waterCommand = firebaseData.stringData();
            if (waterCommand == "true") {
                digitalWrite(WATER_PUMP_PIN, HIGH);
                Serial.println("Water Pump: ON");
                Firebase.RTDB.setString(&firebaseData, "/waterLogs/" + String(millis()), "Water Pump ON");
            } else if (waterCommand == "false") {
                digitalWrite(WATER_PUMP_PIN, LOW);
                Serial.println("Water Pump: OFF");
                Firebase.RTDB.setString(&firebaseData, "/waterLogs/" + String(millis()), "Water Pump OFF");
            }
        }
    }

    // Measure Food & Water Levels
    int foodLevel = measureDistance(TRIG_FOOD, ECHO_FOOD);
    int waterLevel = measureDistance(TRIG_WATER, ECHO_WATER);

    Serial.print("Food Level: "); Serial.print(foodLevel); Serial.println(" mm");
    Serial.print("Water Level: "); Serial.print(waterLevel); Serial.println(" mm");

    // Check if food is below threshold
    if (foodLevel > FOOD_THRESHOLD) {
        Firebase.RTDB.setString(&firebaseData, "/foodStatus", "Low Food Alert");
        Serial.println("Alert: Food level low!");
    } else {
        Firebase.RTDB.setString(&firebaseData, "/foodStatus", "Sufficient Food");
    }

    // Check if water is below threshold
    if (waterLevel > WATER_THRESHOLD) {
        Firebase.RTDB.setString(&firebaseData, "/waterStatus", "Low Water Alert");
        Serial.println("Alert: Water level low!");
    } else {
        Firebase.RTDB.setString(&firebaseData, "/waterStatus", "Sufficient Water");
    }

    delay(100); // Delay for stability
}

// Function to measure distance using ultrasonic sensor
int measureDistance(int trigPin, int echoPin) {
    digitalWrite(trigPin, LOW);
    delayMicroseconds(2);
    digitalWrite(trigPin, HIGH);
    delayMicroseconds(10);
    digitalWrite(trigPin, LOW);

    long duration = pulseIn(echoPin, HIGH);
    int distance = duration * 0.034 / 2; // Convert time to distance in mm
    return distance;
}
