/*
 * LIDAR Lab-on-a-Chip Control Software
 * For soft processor (NIOS II, MicroBlaze, RISC-V, etc.)
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

// LIDAR hardware register base address
#define LIDAR_BASE_ADDR     0x10000000

// Register offsets
#define REG_CONTROL         0x00
#define REG_STATUS          0x04
#define REG_PULSE_WIDTH     0x08
#define REG_SCAN_RATE       0x0C
#define REG_CURRENT_ANGLE   0x10
#define REG_MEM_ADDR        0x14
#define REG_MEM_DATA        0x18
#define REG_VERSION         0x1C

// Control register bits
#define CTRL_START_SCAN     (1 << 0)
#define CTRL_RESET_SCAN     (1 << 1)
#define CTRL_BEAM_ENABLE    (1 << 2)
#define CTRL_AUTO_MODE      (1 << 3)

// Status register bits
#define STATUS_SCAN_COMPLETE    (1 << 1)
#define STATUS_BEAM_ACTIVE      (1 << 2)
#define STATUS_MEASUREMENT_VALID (1 << 3)
#define STATUS_ERROR_FLAG       (1 << 4)

// LIDAR configuration structure
typedef struct {
    uint16_t pulse_width;    // Laser pulse width in clock cycles
    uint16_t scan_rate;      // Scan rate in clock cycles
    bool auto_mode;          // Automatic scanning mode
    bool beam_enable;        // Beam steering enable
} lidar_config_t;

// Depth map structure
typedef struct {
    uint16_t data[64][64];   // 64x64 depth map
    bool valid;              // Data validity flag
    uint32_t timestamp;      // Scan timestamp
} depth_map_t;

// Function prototypes
void lidar_init(void);
bool lidar_configure(const lidar_config_t* config);
bool lidar_start_scan(void);
bool lidar_stop_scan(void);
uint32_t lidar_get_status(void);
bool lidar_is_scan_complete(void);
bool lidar_read_depth_map(depth_map_t* map);
void lidar_reset(void);
bool lidar_self_test(void);

// Hardware access macros
#define LIDAR_REG(offset) (*(volatile uint32_t*)(LIDAR_BASE_ADDR + (offset)))

// Global variables
static lidar_config_t current_config;
static volatile bool scan_in_progress = false;

/*
 * Initialize LIDAR system
 */
void lidar_init(void) {
    // Check version register
    uint32_t version = LIDAR_REG(REG_VERSION);
    if (version != 0x4C494441) { // "LIDA"
        // Version mismatch - handle error
        return;
    }
    
    // Reset the system
    lidar_reset();
    
    // Set default configuration
    current_config.pulse_width = 100;  // 1 microsecond
    current_config.scan_rate = 1000;   // 10 microseconds
    current_config.auto_mode = true;
    current_config.beam_enable = true;
    
    lidar_configure(&current_config);
}

/*
 * Configure LIDAR parameters
 */
bool lidar_configure(const lidar_config_t* config) {
    if (config == NULL) {
        return false;
    }
    
    // Don't configure while scanning
    if (scan_in_progress) {
        return false;
    }
    
    // Set pulse width (minimum 10 ns)
    if (config->pulse_width < 10) {
        return false;
    }
    LIDAR_REG(REG_PULSE_WIDTH) = config->pulse_width;
    
    // Set scan rate (minimum 1 us)
    if (config->scan_rate < 100) {
        return false;
    }
    LIDAR_REG(REG_SCAN_RATE) = config->scan_rate;
    
    // Update control register
    uint32_t ctrl = 0;
    if (config->auto_mode) ctrl |= CTRL_AUTO_MODE;
    if (config->beam_enable) ctrl |= CTRL_BEAM_ENABLE;
    
    LIDAR_REG(REG_CONTROL) = ctrl;
    
    // Store current configuration
    current_config = *config;
    
    return true;
}

/*
 * Start LIDAR scanning
 */
bool lidar_start_scan(void) {
    if (scan_in_progress) {
        return false;
    }
    
    // Clear any previous errors
    uint32_t ctrl = LIDAR_REG(REG_CONTROL);
    ctrl |= CTRL_RESET_SCAN;
    LIDAR_REG(REG_CONTROL) = ctrl;
    
    // Small delay for reset
    for (volatile int i = 0; i < 100; i++);
    
    // Start scanning
    ctrl = LIDAR_REG(REG_CONTROL);
    ctrl &= ~CTRL_RESET_SCAN;
    ctrl |= CTRL_START_SCAN | CTRL_BEAM_ENABLE;
    LIDAR_REG(REG_CONTROL) = ctrl;
    
    scan_in_progress = true;
    return true;
}

/*
 * Stop LIDAR scanning
 */
bool lidar_stop_scan(void) {
    uint32_t ctrl = LIDAR_REG(REG_CONTROL);
    ctrl &= ~(CTRL_START_SCAN | CTRL_BEAM_ENABLE);
    LIDAR_REG(REG_CONTROL) = ctrl;
    
    scan_in_progress = false;
    return true;
}

/*
 * Get LIDAR status
 */
uint32_t lidar_get_status(void) {
    return LIDAR_REG(REG_STATUS);
}

/*
 * Check if scan is complete
 */
bool lidar_is_scan_complete(void) {
    uint32_t status = lidar_get_status();
    bool complete = (status & STATUS_SCAN_COMPLETE) != 0;
    
    if (complete) {
        scan_in_progress = false;
    }
    
    return complete;
}

/*
 * Read depth map from hardware memory
 */
bool lidar_read_depth_map(depth_map_t* map) {
    if (map == NULL) {
        return false;
    }
    
    // Check if scan is complete
    if (!lidar_is_scan_complete()) {
        return false;
    }
    
    // Read 64x64 depth map
    for (int y = 0; y < 64; y++) {
        for (int x = 0; x < 64; x++) {
            uint32_t addr = y * 64 + x;
            LIDAR_REG(REG_MEM_ADDR) = addr;
            
            // Small delay for address setup
            for (volatile int i = 0; i < 10; i++);
            
            uint32_t data = LIDAR_REG(REG_MEM_DATA);
            map->data[y][x] = (uint16_t)(data & 0xFFF); // 12-bit depth
        }
    }
    
    map->valid = true;
    map->timestamp = 0; // Would use system timer in real implementation
    
    return true;
}

/*
 * Reset LIDAR system
 */
void lidar_reset(void) {
    LIDAR_REG(REG_CONTROL) = CTRL_RESET_SCAN;
    
    // Hold reset for a few cycles
    for (volatile int i = 0; i < 1000; i++);
    
    LIDAR_REG(REG_CONTROL) = 0;
    scan_in_progress = false;
}

/*
 * Perform self-test
 */
bool lidar_self_test(void) {
    // Save current configuration
    lidar_config_t saved_config = current_config;
    
    // Test register access
    uint32_t test_val = 0x12345678;
    LIDAR_REG(REG_PULSE_WIDTH) = test_val & 0xFFFF;
    if ((LIDAR_REG(REG_PULSE_WIDTH) & 0xFFFF) != (test_val & 0xFFFF)) {
        return false;
    }
    
    LIDAR_REG(REG_SCAN_RATE) = (test_val >> 16) & 0xFFFF;
    if ((LIDAR_REG(REG_SCAN_RATE) & 0xFFFF) != ((test_val >> 16) & 0xFFFF)) {
        return false;
    }
    
    // Test control register
    LIDAR_REG(REG_CONTROL) = CTRL_AUTO_MODE | CTRL_BEAM_ENABLE;
    uint32_t ctrl = LIDAR_REG(REG_CONTROL);
    if ((ctrl & (CTRL_AUTO_MODE | CTRL_BEAM_ENABLE)) != 
        (CTRL_AUTO_MODE | CTRL_BEAM_ENABLE)) {
        return false;
    }
    
    // Restore configuration
    lidar_configure(&saved_config);
    
    return true;
}

/*
 * Example application function
 */
void lidar_application_example(void) {
    depth_map_t depth_map;
    lidar_config_t config = {
        .pulse_width = 100,    // 1 us pulse
        .scan_rate = 2000,     // 20 us between measurements
        .auto_mode = true,
        .beam_enable = true
    };
    
    // Initialize system
    lidar_init();
    
    // Perform self-test
    if (!lidar_self_test()) {
        // Handle self-test failure
        return;
    }
    
    // Configure LIDAR
    if (!lidar_configure(&config)) {
        // Handle configuration error
        return;
    }
    
    // Start scanning
    if (!lidar_start_scan()) {
        // Handle start error
        return;
    }
    
    // Wait for scan completion
    while (!lidar_is_scan_complete()) {
        // Could do other tasks here
        
        // Check for errors
        uint32_t status = lidar_get_status();
        if (status & STATUS_ERROR_FLAG) {
            // Handle error
            lidar_stop_scan();
            lidar_reset();
            return;
        }
    }
    
    // Read depth map
    if (lidar_read_depth_map(&depth_map)) {
        // Process depth map data
        for (int y = 0; y < 64; y++) {
            for (int x = 0; x < 64; x++) {
                uint16_t distance = depth_map.data[y][x];
                // Process distance measurement
                // (distance is in centimeters)
            }
        }
    }
    
    // Stop scanning
    lidar_stop_scan();
}

/*
 * Interrupt service routine (if using interrupts)
 */
void lidar_isr(void) {
    uint32_t status = lidar_get_status();
    
    if (status & STATUS_SCAN_COMPLETE) {
        // Scan completed - could set a flag or call callback
        scan_in_progress = false;
    }
    
    if (status & STATUS_ERROR_FLAG) {
        // Error occurred - handle appropriately
        lidar_stop_scan();
        lidar_reset();
    }
}
