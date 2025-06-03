/**
 * Autonomous Boat Controller - Soft-Core Processor Implementation
 * Handles GPS pathfinding, joystick control, and motor control
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <stdbool.h>

// Hardware register addresses
#define SONAR_BASE_ADDR     0x00
#define SONAR_DIST0         (SONAR_BASE_ADDR + 0x00)
#define SONAR_DIST1         (SONAR_BASE_ADDR + 0x04)
#define SONAR_DIST2         (SONAR_BASE_ADDR + 0x08)
#define SONAR_DIST3         (SONAR_BASE_ADDR + 0x0C)
#define SONAR_CONTROL       (SONAR_BASE_ADDR + 0x10)
#define SONAR_STATUS        (SONAR_BASE_ADDR + 0x14)

// Motor control
#define MOTOR_BASE_ADDR     0x20
#define MOTOR_LEFT_PWM      (MOTOR_BASE_ADDR + 0x00)
#define MOTOR_RIGHT_PWM     (MOTOR_BASE_ADDR + 0x04)
#define MOTOR_DIRECTION     (MOTOR_BASE_ADDR + 0x08)

// GPS and navigation
#define GPS_BASE_ADDR       0x40
#define GPS_LATITUDE        (GPS_BASE_ADDR + 0x00)
#define GPS_LONGITUDE       (GPS_BASE_ADDR + 0x04)
#define GPS_STATUS          (GPS_BASE_ADDR + 0x08)

// Joystick/tether control
#define JOYSTICK_BASE_ADDR  0x60
#define JOYSTICK_X          (JOYSTICK_BASE_ADDR + 0x00)
#define JOYSTICK_Y          (JOYSTICK_BASE_ADDR + 0x04)
#define JOYSTICK_BUTTONS    (JOYSTICK_BASE_ADDR + 0x08)

// Constants
#define MAX_PWM_VALUE       255
#define MIN_SAFE_DISTANCE   1000  // Minimum safe distance in sensor units
#define EARTH_RADIUS        6371000.0  // Earth radius in meters
#define PI                  3.14159265359

// Control modes
typedef enum {
    MODE_MANUAL,
    MODE_AUTONOMOUS,
    MODE_EMERGENCY_STOP
} control_mode_t;

// GPS coordinate structure
typedef struct {
    double latitude;
    double longitude;
    bool valid;
} gps_coord_t;

// Navigation waypoint
typedef struct {
    gps_coord_t position;
    float tolerance;  // Acceptance radius in meters
} waypoint_t;

// Sonar data structure
typedef struct {
    uint32_t distances[4];  // Front-left, front-right, left, right
    uint8_t obstacle_flags;
    bool emergency_stop;
} sonar_data_t;

// Motor control structure
typedef struct {
    uint8_t left_pwm;
    uint8_t right_pwm;
    bool left_forward;
    bool right_forward;
} motor_control_t;

// Global variables
static control_mode_t current_mode = MODE_MANUAL;
static gps_coord_t current_position;
static waypoint_t target_waypoint;
static sonar_data_t sonar_data;
static motor_control_t motor_cmd;

// Hardware access functions
static inline uint32_t read_reg(uint32_t addr) {
    return *((volatile uint32_t*)addr);
}

static inline void write_reg(uint32_t addr, uint32_t value) {
    *((volatile uint32_t*)addr) = value;
}

// GPS functions
bool gps_read_position(gps_coord_t* pos) {
    uint32_t lat_raw = read_reg(GPS_LATITUDE);
    uint32_t lon_raw = read_reg(GPS_LONGITUDE);
    uint32_t status = read_reg(GPS_STATUS);
    
    if (status & 0x01) {  // GPS fix available
        // Convert from integer representation to double
        pos->latitude = ((int32_t)lat_raw) / 1000000.0;
        pos->longitude = ((int32_t)lon_raw) / 1000000.0;
        pos->valid = true;
        return true;
    }
    
    pos->valid = false;
    return false;
}

// Calculate distance between two GPS coordinates (Haversine formula)
double gps_distance(const gps_coord_t* pos1, const gps_coord_t* pos2) {
    double lat1_rad = pos1->latitude * PI / 180.0;
    double lat2_rad = pos2->latitude * PI / 180.0;
    double dlat_rad = (pos2->latitude - pos1->latitude) * PI / 180.0;
    double dlon_rad = (pos2->longitude - pos1->longitude) * PI / 180.0;
    
    double a = sin(dlat_rad/2) * sin(dlat_rad/2) +
               cos(lat1_rad) * cos(lat2_rad) *
               sin(dlon_rad/2) * sin(dlon_rad/2);
    double c = 2 * atan2(sqrt(a), sqrt(1-a));
    
    return EARTH_RADIUS * c;
}

// Calculate bearing to target waypoint
double gps_bearing(const gps_coord_t* from, const gps_coord_t* to) {
    double lat1_rad = from->latitude * PI / 180.0;
    double lat2_rad = to->latitude * PI / 180.0;
    double dlon_rad = (to->longitude - from->longitude) * PI / 180.0;
    
    double y = sin(dlon_rad) * cos(lat2_rad);
    double x = cos(lat1_rad) * sin(lat2_rad) -
               sin(lat1_rad) * cos(lat2_rad) * cos(dlon_rad);
    
    double bearing = atan2(y, x) * 180.0 / PI;
    return fmod(bearing + 360.0, 360.0);  // Normalize to 0-360
}

// Sonar data reading
void sonar_read_data(sonar_data_t* data) {
    data->distances[0] = read_reg(SONAR_DIST0);
    data->distances[1] = read_reg(SONAR_DIST1);
    data->distances[2] = read_reg(SONAR_DIST2);
    data->distances[3] = read_reg(SONAR_DIST3);
    
    uint32_t status = read_reg(SONAR_STATUS);
    data->obstacle_flags = status & 0x0F;
    data->emergency_stop = (status & 0x10) != 0;
}

// Joystick input reading
void joystick_read(int16_t* x, int16_t* y, uint8_t* buttons) {
    uint32_t x_raw = read_reg(JOYSTICK_X);
    uint32_t y_raw = read_reg(JOYSTICK_Y);
    uint32_t btn_raw = read_reg(JOYSTICK_BUTTONS);
    
    *x = (int16_t)(x_raw & 0xFFFF);
    *y = (int16_t)(y_raw & 0xFFFF);
    *buttons = btn_raw & 0xFF;
}

// Motor control functions
void motor_set_speed(uint8_t left_pwm, uint8_t right_pwm, bool left_fwd, bool right_fwd) {
    write_reg(MOTOR_LEFT_PWM, left_pwm);
    write_reg(MOTOR_RIGHT_PWM, right_pwm);
    
    uint32_t direction = 0;
    if (left_fwd) direction |= 0x01;
    if (right_fwd) direction |= 0x02;
    write_reg(MOTOR_DIRECTION, direction);
}

void motor_stop(void) {
    motor_set_speed(0, 0, true, true);
}

// Navigation controller - simple proportional control
void navigate_to_waypoint(const gps_coord_t* current, const waypoint_t* target, motor_control_t* cmd) {
    double distance = gps_distance(current, &target->position);
    double bearing = gps_bearing(current, &target->position);
    
    if (distance < target->tolerance) {
        // Reached waypoint
        cmd->left_pwm = 0;
        cmd->right_pwm = 0;
        return;
    }
    
    // Simple proportional control based on bearing
    // Assuming boat's forward direction is 0 degrees
    double error = bearing;
    if (error > 180) error -= 360;  // Normalize to -180 to +180
    
    // Base speed
    uint8_t base_speed = 128;  // 50% PWM
    
    // Steering adjustment
    int16_t steer = (int16_t)(error * 2.0);  // Proportional gain
    
    // Limit steering
    if (steer > 100) steer = 100;
    if (steer < -100) steer = -100;
    
    // Apply differential steering
    int16_t left_speed = base_speed - steer;
    int16_t right_speed = base_speed + steer;
    
    // Limit speeds
    if (left_speed < 0) {
        cmd->left_pwm = -left_speed;
        cmd->left_forward = false;
    } else {
        cmd->left_pwm = left_speed;
        cmd->left_forward = true;
    }
    
    if (right_speed < 0) {
        cmd->right_pwm = -right_speed;
        cmd->right_forward = false;
    } else {
        cmd->right_pwm = right_speed;
        cmd->right_forward = true;
    }
    
    // Limit PWM values
    if (cmd->left_pwm > MAX_PWM_VALUE) cmd->left_pwm = MAX_PWM_VALUE;
    if (cmd->right_pwm > MAX_PWM_VALUE) cmd->right_pwm = MAX_PWM_VALUE;
}

// Obstacle avoidance behavior
bool obstacle_avoidance(const sonar_data_t* sonar, motor_control_t* cmd) {
    // Emergency stop check
    if (sonar->emergency_stop) {
        motor_stop();
        return true;  // Emergency override
    }
    
    // Check for obstacles in front
    bool front_left_blocked = (sonar->distances[0] < MIN_SAFE_DISTANCE);
    bool front_right_blocked = (sonar->distances[1] < MIN_SAFE_DISTANCE);
    
    if (front_left_blocked || front_right_blocked) {
        if (front_left_blocked && !front_right_blocked) {
            // Turn right
            cmd->left_pwm = 100;
            cmd->right_pwm = 50;
            cmd->left_forward = true;
            cmd->right_forward = true;
        } else if (front_right_blocked && !front_left_blocked) {
            // Turn left
            cmd->left_pwm = 50;
            cmd->right_pwm = 100;
            cmd->left_forward = true;
            cmd->right_forward = true;
        } else {
            // Both blocked - back up and turn
            cmd->left_pwm = 80;
            cmd->right_pwm = 80;
            cmd->left_forward = false;
            cmd->right_forward = false;
        }
        return true;  // Avoidance active
    }
    
    return false;  // No obstacles
}

// Manual control mode
void manual_control_mode(void) {
    int16_t joy_x, joy_y;
    uint8_t buttons;
    
    joystick_read(&joy_x, &joy_y, &buttons);
    
    // Check mode switch button
    if (buttons & 0x01) {  // Button 1 pressed
        current_mode = MODE_AUTONOMOUS;
        printf("Switched to autonomous mode\n");
        return;
    }
    
    // Convert joystick to motor commands
    // joy_y: forward/backward, joy_x: left/right steering
    int16_t forward = joy_y / 128;  // Scale to -255 to +255
    int16_t turn = joy_x / 128;
    
    int16_t left_speed = forward - turn;
    int16_t right_speed = forward + turn;
    
    // Set motor directions and speeds
    motor_cmd.left_forward = (left_speed >= 0);
    motor_cmd.right_forward = (right_speed >= 0);
    motor_cmd.left_pwm = abs(left_speed);
    motor_cmd.right_pwm = abs(right_speed);
    
    // Limit PWM values
    if (motor_cmd.left_pwm > MAX_PWM_VALUE) motor_cmd.left_pwm = MAX_PWM_VALUE;
    if (motor_cmd.right_pwm > MAX_PWM_VALUE) motor_cmd.right_pwm = MAX_PWM_VALUE;
}

// Autonomous control mode
void autonomous_control_mode(void) {
    uint8_t buttons;
    int16_t dummy_x, dummy_y;
    
    joystick_read(&dummy_x, &dummy_y, &buttons);
    
    // Check mode switch button
    if (buttons & 0x01) {  // Button 1 pressed
        current_mode = MODE_MANUAL;
        printf("Switched to manual mode\n");
        return;
    }
    
    // Read current GPS position
    if (!gps_read_position(&current_position)) {
        printf("GPS signal lost - stopping\n");
        motor_stop();
        return;
    }
    
    // Check for obstacles first
    if (obstacle_avoidance(&sonar_data, &motor_cmd)) {
        printf("Obstacle avoidance active\n");
        // Obstacle avoidance has priority
    } else {
        // Navigate to waypoint
        navigate_to_waypoint(&current_position, &target_waypoint, &motor_cmd);
        
        double distance = gps_distance(&current_position, &target_waypoint.position);
        printf("Distance to waypoint: %.2f m\n", distance);
    }
}

// Main control loop
void control_loop(void) {
    // Read sonar data
    sonar_read_data(&sonar_data);
    
    // Execute control based on current mode
    switch (current_mode) {
        case MODE_MANUAL:
            manual_control_mode();
            break;
            
        case MODE_AUTONOMOUS:
            autonomous_control_mode();
            break;
            
        case MODE_EMERGENCY_STOP:
            motor_stop();
            break;
    }
    
    // Apply motor commands (unless emergency stop is active)
    if (!sonar_data.emergency_stop) {
        motor_set_speed(motor_cmd.left_pwm, motor_cmd.right_pwm,
                       motor_cmd.left_forward, motor_cmd.right_forward);
    }
}

// Initialize system
void system_init(void) {
    printf("Boat Controller Starting...\n");
    
    // Initialize default waypoint
    target_waypoint.position.latitude = 37.7749;   // San Francisco Bay example
    target_waypoint.position.longitude = -122.4194;
    target_waypoint.position.valid = true;
    target_waypoint.tolerance = 5.0;  // 5 meter acceptance radius
    
    // Initialize motor control
    motor_stop();
    
    // Set sonar control - enable scanning
    write_reg(SONAR_CONTROL, 0x00010001);  // Enable scanning, 1ms threshold
    
    printf("System initialized\n");
}

// Main function
int main(void) {
    system_init();
    
    printf("Autonomous Boat Controller Ready\n");
    printf("Mode: Manual (Button 1 to switch)\n");
    
    // Main control loop
    while (1) {
        control_loop();
        
        // Add delay to prevent overwhelming the system
        // In a real implementation, this would be timer-based
        for (volatile int i = 0; i < 10000; i++);
    }
    
    return 0;
}
