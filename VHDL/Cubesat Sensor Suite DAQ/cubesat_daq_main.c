/*
 * cubesat_daq_main.c
 * Main SDK module for CubeSat DAQ system
 * Provides high-level API for sensor data acquisition
 */
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <stdlib.h>
#include "cubesat_daq_hal.h"
#include "cubesat_telemetry.h"
#include "cubesat_sensor_control.h"

// System configuration
#define MAX_SAMPLES_PER_SESSION 10000
#define DEFAULT_SAMPLE_RATE_HZ  10
#define TELEMETRY_BUFFER_SIZE   1024
#define STATUS_UPDATE_INTERVAL  1000  // ms

// Global variables
static cubesat_daq_t g_daq_system;
static telemetry_buffer_t g_telemetry_buffer;
static sensor_data_t g_sensor_samples[MAX_SAMPLES_PER_SESSION];
static volatile bool g_system_running = false;
static volatile uint32_t g_sample_count = 0;

// Function prototypes
static int initialize_system(void);
static int start_data_acquisition(uint16_t sample_rate_hz);
static int stop_data_acquisition(void);
static void process_sensor_data(void);
static void update_system_status(void);
static int handle_telemetry_commands(void);
static void print_system_status(void);
static void cleanup_system(void);

/*
 * Main application entry point
 */
int main(int argc, char *argv[]) {
    int ret = 0;
    uint16_t sample_rate = DEFAULT_SAMPLE_RATE_HZ;
    bool auto_start = false;
    
    printf("CubeSat DAQ System v1.0\n");
    printf("Initializing sensors and communication...\n");
    
    // Parse command line arguments
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-r") == 0 && i + 1 < argc) {
            sample_rate = (uint16_t)atoi(argv[i + 1]);
            i++;
        } else if (strcmp(argv[i], "-a") == 0) {
            auto_start = true;
        } else if (strcmp(argv[i], "-h") == 0) {
            printf("Usage: %s [-r sample_rate] [-a] [-h]\n", argv[0]);
            printf("  -r: Set sample rate in Hz (default: %d)\n", DEFAULT_SAMPLE_RATE_HZ);
            printf("  -a: Auto-start data acquisition\n");
            printf("  -h: Show this help\n");
            return 0;
        }
    }
    
    // Initialize the DAQ system
    ret = initialize_system();
    if (ret != 0) {
        printf("ERROR: System initialization failed (code: %d)\n", ret);
        return ret;
    }
    
    printf("System initialized successfully\n");
    printf("Sample rate: %d Hz\n", sample_rate);
    
    // Auto-start if requested
    if (auto_start) {
        printf("Starting automatic data acquisition...\n");
        ret = start_data_acquisition(sample_rate);
        if (ret != 0) {
            printf("ERROR: Failed to start data acquisition (code: %d)\n", ret);
            cleanup_system();
            return ret;
        }
    }
    
    // Main control loop
    printf("Entering main control loop. Press 'q' to quit.\n");
    printf("Commands: s=start, t=stop, r=rate, status=show status\n");
    
    char command[256];
    static uint32_t last_status_update = 0;
    
    while (true) {
        // Handle telemetry commands from ground station
        handle_telemetry_commands();
        
        // Process any pending sensor data
        if (g_system_running) {
            process_sensor_data();
        }
        
        // Update system status periodically
        uint32_t current_time = (uint32_t)(time(NULL) * 1000);
        if (current_time - last_status_update >= STATUS_UPDATE_INTERVAL) {
            update_system_status();
            last_status_update = current_time;
        }
        
        // Check for user input (non-blocking)
        if (fgets(command, sizeof(command), stdin) != NULL) {
            // Remove newline character
            command[strcspn(command, "\n")] = 0;
            
            if (strcmp(command, "q") == 0 || strcmp(command, "quit") == 0) {
                printf("Shutting down system...\n");
                break;
            } else if (strcmp(command, "s") == 0 || strcmp(command, "start") == 0) {
                if (!g_system_running) {
                    ret = start_data_acquisition(sample_rate);
                    if (ret == 0) {
                        printf("Data acquisition started\n");
                    } else {
                        printf("Failed to start data acquisition (code: %d)\n", ret);
                    }
                } else {
                    printf("System is already running\n");
                }
            } else if (strcmp(command, "t") == 0 || strcmp(command, "stop") == 0) {
                if (g_system_running) {
                    ret = stop_data_acquisition();
                    if (ret == 0) {
                        printf("Data acquisition stopped\n");
                    } else {
                        printf("Failed to stop data acquisition (code: %d)\n", ret);
                    }
                } else {
                    printf("System is not running\n");
                }
            } else if (strncmp(command, "r ", 2) == 0) {
                uint16_t new_rate = (uint16_t)atoi(command + 2);
                if (new_rate > 0 && new_rate <= 1000) {
                    sample_rate = new_rate;
                    printf("Sample rate set to %d Hz\n", sample_rate);
                    if (g_system_running) {
                        printf("Restart acquisition for new rate to take effect\n");
                    }
                } else {
                    printf("Invalid sample rate. Use 1-1000 Hz\n");
                }
            } else if (strcmp(command, "status") == 0) {
                print_system_status();
            } else if (strlen(command) > 0) {
                printf("Unknown command: %s\n", command);
                printf("Commands: s=start, t=stop, r=rate, status=show status, q=quit\n");
            }
        }
        
        // Small delay to prevent excessive CPU usage
        usleep(10000); // 10ms
    }
    
    // Cleanup before exit
    if (g_system_running) {
        stop_data_acquisition();
    }
    cleanup_system();
    
    printf("System shutdown complete\n");
    return 0;
}

/*
 * Initialize the DAQ system and all subsystems
 */
static int initialize_system(void) {
    int ret = 0;
    
    // Initialize HAL layer
    ret = cubesat_hal_init(&g_daq_system);
    if (ret != 0) {
        printf("HAL initialization failed\n");
        return ret;
    }
    
    // Initialize telemetry subsystem
    ret = telemetry_init(&g_telemetry_buffer, TELEMETRY_BUFFER_SIZE);
    if (ret != 0) {
        printf("Telemetry initialization failed\n");
        return ret;
    }
    
    // Initialize sensor control subsystem
    ret = sensor_control_init();
    if (ret != 0) {
        printf("Sensor control initialization failed\n");
        return ret;
    }
    
    // Reset sample counter
    g_sample_count = 0;
    
    printf("All subsystems initialized successfully\n");
    return 0;
}

/*
 * Start data acquisition at specified sample rate
 */
static int start_data_acquisition(uint16_t sample_rate_hz) {
    if (g_system_running) {
        printf("System is already running\n");
        return -1;
    }
    
    // Configure sensor sampling rate
    int ret = sensor_control_set_sample_rate(sample_rate_hz);
    if (ret != 0) {
        printf("Failed to set sensor sample rate\n");
        return ret;
    }
    
    // Start sensor data collection
    ret = sensor_control_start();
    if (ret != 0) {
        printf("Failed to start sensor control\n");
        return ret;
    }
    
    // Start telemetry transmission
    ret = telemetry_start();
    if (ret != 0) {
        printf("Failed to start telemetry\n");
        sensor_control_stop();
        return ret;
    }
    
    g_system_running = true;
    g_sample_count = 0;
    
    printf("Data acquisition started at %d Hz\n", sample_rate_hz);
    return 0;
}

/*
 * Stop data acquisition
 */
static int stop_data_acquisition(void) {
    if (!g_system_running) {
        printf("System is not running\n");
        return -1;
    }
    
    // Stop sensor data collection
    int ret = sensor_control_stop();
    if (ret != 0) {
        printf("Warning: Failed to stop sensor control cleanly\n");
    }
    
    // Stop telemetry transmission
    ret = telemetry_stop();
    if (ret != 0) {
        printf("Warning: Failed to stop telemetry cleanly\n");
    }
    
    g_system_running = false;
    
    printf("Data acquisition stopped. Total samples: %u\n", g_sample_count);
    return 0;
}

/*
 * Process incoming sensor data
 */
static void process_sensor_data(void) {
    sensor_data_t sensor_data;
    
    // Check if new sensor data is available
    while (sensor_control_get_data(&sensor_data) == 0) {
        // Store sample if we have space
        if (g_sample_count < MAX_SAMPLES_PER_SESSION) {
            memcpy(&g_sensor_samples[g_sample_count], &sensor_data, sizeof(sensor_data_t));
            g_sample_count++;
        } else {
            printf("Warning: Sample buffer full, dropping data\n");
        }
        
        // Send data via telemetry
        telemetry_send_sensor_data(&sensor_data);
        
        // Log critical sensor readings
        if (sensor_data.temperature > 70.0f || sensor_data.temperature < -40.0f) {
            printf("WARNING: Temperature out of range: %.2f°C\n", sensor_data.temperature);
        }
        
        if (sensor_data.voltage < 3.0f) {
            printf("WARNING: Low voltage detected: %.2fV\n", sensor_data.voltage);
        }
    }
}

/*
 * Update system status and health monitoring
 */
static void update_system_status(void) {
    system_status_t status;
    
    // Get current system status
    int ret = cubesat_hal_get_status(&g_daq_system, &status);
    if (ret != 0) {
        printf("Failed to get system status\n");
        return;
    }
    
    // Check for system health issues
    if (status.cpu_usage > 90) {
        printf("WARNING: High CPU usage: %d%%\n", status.cpu_usage);
    }
    
    if (status.memory_usage > 85) {
        printf("WARNING: High memory usage: %d%%\n", status.memory_usage);
    }
    
    if (status.temperature > 60.0f) {
        printf("WARNING: High system temperature: %.1f°C\n", status.temperature);
    }
    
    // Send status via telemetry
    telemetry_send_status(&status);
}

/*
 * Handle incoming telemetry commands from ground station
 */
static int handle_telemetry_commands(void) {
    telemetry_command_t command;
    
    // Check for incoming commands
    while (telemetry_receive_command(&command) == 0) {
        printf("Received telemetry command: %d\n", command.command_id);
        
        switch (command.command_id) {
            case TELEMETRY_CMD_START_DAQ:
                if (!g_system_running) {
                    uint16_t rate = command.param1 > 0 ? command.param1 : DEFAULT_SAMPLE_RATE_HZ;
                    start_data_acquisition(rate);
                    telemetry_send_ack(command.command_id, 0);
                } else {
                    telemetry_send_ack(command.command_id, -1);
                }
                break;
                
            case TELEMETRY_CMD_STOP_DAQ:
                if (g_system_running) {
                    stop_data_acquisition();
                    telemetry_send_ack(command.command_id, 0);
                } else {
                    telemetry_send_ack(command.command_id, -1);
                }
                break;
                
            case TELEMETRY_CMD_SET_SAMPLE_RATE:
                if (command.param1 > 0 && command.param1 <= 1000) {
                    sensor_control_set_sample_rate(command.param1);
                    telemetry_send_ack(command.command_id, 0);
                } else {
                    telemetry_send_ack(command.command_id, -1);
                }
                break;
                
            case TELEMETRY_CMD_GET_STATUS:
                print_system_status();
                telemetry_send_ack(command.command_id, 0);
                break;
                
            default:
                printf("Unknown telemetry command: %d\n", command.command_id);
                telemetry_send_ack(command.command_id, -1);
                break;
        }
    }
    
    return 0;
}

/*
 * Print current system status
 */
static void print_system_status(void) {
    system_status_t status;
    
    printf("\n=== CubeSat DAQ System Status ===\n");
    printf("System Running: %s\n", g_system_running ? "YES" : "NO");
    printf("Samples Collected: %u\n", g_sample_count);
    
    if (cubesat_hal_get_status(&g_daq_system, &status) == 0) {
        printf("CPU Usage: %d%%\n", status.cpu_usage);
        printf("Memory Usage: %d%%\n", status.memory_usage);
        printf("System Temperature: %.1f°C\n", status.temperature);
        printf("Uptime: %u seconds\n", status.uptime_seconds);
    }
    
    // Get sensor status
    sensor_status_t sensor_status;
    if (sensor_control_get_status(&sensor_status) == 0) {
        printf("Active Sensors: %d\n", sensor_status.active_sensors);
        printf("Sensor Errors: %d\n", sensor_status.error_count);
        printf("Last Sample Rate: %d Hz\n", sensor_status.current_sample_rate);
    }
    
    // Get telemetry status
    telemetry_status_t telem_status;
    if (telemetry_get_status(&telem_status) == 0) {
        printf("Telemetry Link: %s\n", telem_status.link_active ? "ACTIVE" : "INACTIVE");
        printf("Messages Sent: %u\n", telem_status.messages_sent);
        printf("Commands Received: %u\n", telem_status.commands_received);
    }
    
    printf("================================\n\n");
}

/*
 * Cleanup system resources before shutdown
 */
static void cleanup_system(void) {
    printf("Cleaning up system resources...\n");
    
    // Stop telemetry
    telemetry_cleanup();
    
    // Stop sensor control
    sensor_control_cleanup();
    
    // Cleanup HAL
    cubesat_hal_cleanup(&g_daq_system);
    
    printf("Cleanup complete\n");
}
