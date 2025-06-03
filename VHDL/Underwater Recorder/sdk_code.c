/*
 * Underwater Recorder SoC - C Implementation
 * Provides high-level control interface for FPGA-based audio recorder
 * Includes SD card management, audio processing, and system control
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

// Hardware register addresses (adjust for your memory map)
#define FPGA_BASE_ADDR          0x40000000
#define CONTROL_REG             (FPGA_BASE_ADDR + 0x00)
#define STATUS_REG              (FPGA_BASE_ADDR + 0x04)
#define ADC_CONFIG_REG          (FPGA_BASE_ADDR + 0x08)
#define COMPRESSION_REG         (FPGA_BASE_ADDR + 0x0C)
#define SD_CONTROL_REG          (FPGA_BASE_ADDR + 0x10)
#define SD_STATUS_REG           (FPGA_BASE_ADDR + 0x14)
#define AUDIO_BUFFER_REG        (FPGA_BASE_ADDR + 0x18)
#define FILE_ADDR_REG           (FPGA_BASE_ADDR + 0x1C)
#define RECORDING_TIME_REG      (FPGA_BASE_ADDR + 0x20)
#define PLAYBACK_TIME_REG       (FPGA_BASE_ADDR + 0x24)

// Control register bit definitions
#define CTRL_RECORD_EN          (1 << 0)
#define CTRL_PLAYBACK_EN        (1 << 1)
#define CTRL_RESET              (1 << 2)
#define CTRL_SD_INIT            (1 << 3)
#define CTRL_AUDIO_MUTE         (1 << 4)

// Status register bit definitions
#define STATUS_RECORDING        (1 << 0)
#define STATUS_PLAYING          (1 << 1)
#define STATUS_SD_READY         (1 << 2)
#define STATUS_SD_ERROR         (1 << 3)
#define STATUS_FIFO_FULL        (1 << 4)
#define STATUS_FIFO_EMPTY       (1 << 5)
#define STATUS_PLL_LOCKED       (1 << 6)
#define STATUS_ERROR            (1 << 7)

// Audio configuration constants
#define SAMPLE_RATE_48KHZ       0
#define SAMPLE_RATE_44KHZ       1
#define SAMPLE_RATE_32KHZ       2
#define SAMPLE_RATE_16KHZ       3

#define COMPRESSION_NONE        0
#define COMPRESSION_2TO1        1
#define COMPRESSION_4TO1        2
#define COMPRESSION_8TO1        3

#define MAX_FILENAME_LEN        256
#define SECTOR_SIZE             512
#define MAX_FILES               100

// File system structures
typedef struct {
    char filename[MAX_FILENAME_LEN];
    uint32_t start_sector;
    uint32_t size_sectors;
    uint32_t duration_ms;
    uint8_t sample_rate;
    uint8_t compression;
    uint32_t timestamp;
} audio_file_t;

typedef struct {
    uint32_t total_files;
    uint32_t free_sectors;
    uint32_t total_sectors;
    audio_file_t files[MAX_FILES];
} file_system_t;

// System state structure
typedef struct {
    bool recording;
    bool playing;
    bool sd_ready;
    uint8_t sample_rate;
    uint8_t compression;
    uint32_t current_file_sector;
    uint32_t recording_time_ms;
    uint32_t playback_time_ms;
    file_system_t filesystem;
    char current_filename[MAX_FILENAME_LEN];
} recorder_state_t;

// Global state
static recorder_state_t g_recorder_state = {0};

// Function prototypes
int recorder_init(void);
int load_filesystem(void);
int save_filesystem(void);
int start_recording(const char* filename);
int stop_recording(void);
int start_playback(const char* filename);
int stop_playback(void);
int set_sample_rate(uint8_t sample_rate);
int set_compression(uint8_t compression);
void update_status(void);
void print_status(void);
void list_files(void);
uint32_t get_timestamp(void);
int delete_file(const char* filename);
int format_sd_card(void);
int defragment_storage(void);
void print_help(void);
int command_interface(void);

// Hardware access functions
static inline void write_reg(uint32_t addr, uint32_t value) {
    *(volatile uint32_t*)addr = value;
}

static inline uint32_t read_reg(uint32_t addr) {
    return *(volatile uint32_t*)addr;
}

// System initialization
int recorder_init(void) {
    printf("Initializing Underwater Recorder SoC...\n");
    
    // Reset the system
    write_reg(CONTROL_REG, CTRL_RESET);
    for (volatile int i = 0; i < 10000; i++); // Delay
    write_reg(CONTROL_REG, 0);
    
    // Wait for PLL lock
    int timeout = 1000000;
    while (!(read_reg(STATUS_REG) & STATUS_PLL_LOCKED) && timeout--) {
        // Wait for PLL to stabilize
    }
    
    if (timeout <= 0) {
        printf("ERROR: PLL failed to lock\n");
        return -1;
    }
    
    // Initialize SD card
    printf("Initializing SD card...\n");
    write_reg(CONTROL_REG, CTRL_SD_INIT);
    
    timeout = 1000000;
    while (!(read_reg(STATUS_REG) & STATUS_SD_READY) && timeout--) {
        if (read_reg(STATUS_REG) & STATUS_SD_ERROR) {
            printf("ERROR: SD card initialization failed\n");
            return -2;
        }
    }
    
    if (timeout <= 0) {
        printf("ERROR: SD card initialization timeout\n");
        return -2;
    }
    
    // Set default audio configuration
    g_recorder_state.sample_rate = SAMPLE_RATE_48KHZ;
    g_recorder_state.compression = COMPRESSION_4TO1;
    g_recorder_state.sd_ready = true;
    
    write_reg(ADC_CONFIG_REG, (g_recorder_state.sample_rate << 0));
    write_reg(COMPRESSION_REG, g_recorder_state.compression);
    
    // Load file system
    load_filesystem();
    
    printf("Underwater Recorder initialized successfully\n");
    return 0;
}

// File system management
int load_filesystem(void) {
    printf("Loading file system...\n");
    
    // Read file system from first sector of SD card
    write_reg(FILE_ADDR_REG, 0); // Sector 0
    
    // In a real implementation, you would read the actual file system
    // For now, initialize with empty file system
    memset(&g_recorder_state.filesystem, 0, sizeof(file_system_t));
    g_recorder_state.filesystem.total_sectors = 1024 * 1024; // 512MB assuming 512B sectors
    g_recorder_state.filesystem.free_sectors = g_recorder_state.filesystem.total_sectors - 1;
    
    printf("File system loaded: %d files, %d free sectors\n", 
           g_recorder_state.filesystem.total_files,
           g_recorder_state.filesystem.free_sectors);
    
    return 0;
}

int save_filesystem(void) {
    printf("Saving file system...\n");
    
    // Write file system to first sector of SD card
    write_reg(FILE_ADDR_REG, 0); // Sector 0
    
    // In a real implementation, you would write the file system structure
    // to the SD card's reserved area
    
    return 0;
}

// Audio recording functions
int start_recording(const char* filename) {
    if (g_recorder_state.recording) {
        printf("ERROR: Already recording\n");
        return -1;
    }
    
    if (!g_recorder_state.sd_ready) {
        printf("ERROR: SD card not ready\n");
        return -2;
    }
    
    if (g_recorder_state.filesystem.total_files >= MAX_FILES) {
        printf("ERROR: Maximum files reached\n");
        return -3;
    }
    
    printf("Starting recording: %s\n", filename);
    
    // Find free sector for new file
    uint32_t start_sector = 1; // Skip file system sector
    for (int i = 0; i < g_recorder_state.filesystem.total_files; i++) {
        uint32_t file_end = g_recorder_state.filesystem.files[i].start_sector + 
                           g_recorder_state.filesystem.files[i].size_sectors;
        if (file_end > start_sector) {
            start_sector = file_end;
        }
    }
    
    // Set up new file entry
    audio_file_t* new_file = &g_recorder_state.filesystem.files[g_recorder_state.filesystem.total_files];
    strncpy(new_file->filename, filename, MAX_FILENAME_LEN - 1);
    new_file->start_sector = start_sector;
    new_file->size_sectors = 0;
    new_file->duration_ms = 0;
    new_file->sample_rate = g_recorder_state.sample_rate;
    new_file->compression = g_recorder_state.compression;
    new_file->timestamp = get_timestamp();
    
    g_recorder_state.current_file_sector = start_sector;
    strncpy(g_recorder_state.current_filename, filename, MAX_FILENAME_LEN - 1);
    
    // Configure hardware for recording
    write_reg(FILE_ADDR_REG, start_sector);
    write_reg(RECORDING_TIME_REG, 0);
    
    // Start recording
    uint32_t control = read_reg(CONTROL_REG);
    control |= CTRL_RECORD_EN;
    write_reg(CONTROL_REG, control);
    
    g_recorder_state.recording = true;
    g_recorder_state.recording_time_ms = 0;
    
    printf("Recording started\n");
    return 0;
}

int stop_recording(void) {
    if (!g_recorder_state.recording) {
        printf("ERROR: Not recording\n");
        return -1;
    }
    
    printf("Stopping recording: %s\n", g_recorder_state.current_filename);
    
    // Stop recording
    uint32_t control = read_reg(CONTROL_REG);
    control &= ~CTRL_RECORD_EN;
    write_reg(CONTROL_REG, control);
    
    // Wait for recording to stop
    int timeout = 100000;
    while ((read_reg(STATUS_REG) & STATUS_RECORDING) && timeout--);
    
    // Update file entry
    g_recorder_state.recording_time_ms = read_reg(RECORDING_TIME_REG);
    audio_file_t* current_file = &g_recorder_state.filesystem.files[g_recorder_state.filesystem.total_files];
    current_file->duration_ms = g_recorder_state.recording_time_ms;
    
    // Calculate file size in sectors (simplified)
    uint32_t bytes_per_second = 48000 * 2; // 48kHz, 16-bit
    if (g_recorder_state.compression == COMPRESSION_4TO1) {
        bytes_per_second /= 4;
    } else if (g_recorder_state.compression == COMPRESSION_8TO1) {
        bytes_per_second /= 8;
    }
    
    uint32_t total_bytes = (bytes_per_second * g_recorder_state.recording_time_ms) / 1000;
    current_file->size_sectors = (total_bytes + SECTOR_SIZE - 1) / SECTOR_SIZE;
    
    g_recorder_state.filesystem.total_files++;
    g_recorder_state.filesystem.free_sectors -= current_file->size_sectors;
    
    g_recorder_state.recording = false;
    
    // Save updated file system
    save_filesystem();
    
    printf("Recording stopped. Duration: %d ms, Size: %d sectors\n", 
           current_file->duration_ms, current_file->size_sectors);
    
    return 0;
}

// Audio playback functions
int start_playback(const char* filename) {
    if (g_recorder_state.playing) {
        printf("ERROR: Already playing\n");
        return -1;
    }
    
    if (!g_recorder_state.sd_ready) {
        printf("ERROR: SD card not ready\n");
        return -2;
    }
    
    // Find file
    audio_file_t* file = NULL;
    for (int i = 0; i < g_recorder_state.filesystem.total_files; i++) {
        if (strcmp(g_recorder_state.filesystem.files[i].filename, filename) == 0) {
            file = &g_recorder_state.filesystem.files[i];
            break;
        }
    }
    
    if (!file) {
        printf("ERROR: File not found: %s\n", filename);
        return -3;
    }
    
    printf("Starting playback: %s\n", filename);
    
    // Configure hardware for playback
    write_reg(FILE_ADDR_REG, file->start_sector);
    write_reg(PLAYBACK_TIME_REG, 0);
    
    // Set audio configuration to match file
    write_reg(ADC_CONFIG_REG, file->sample_rate);
    write_reg(COMPRESSION_REG, file->compression);
    
    // Start playback
    uint32_t control = read_reg(CONTROL_REG);
    control |= CTRL_PLAYBACK_EN;
    write_reg(CONTROL_REG, control);
    
    g_recorder_state.playing = true;
    g_recorder_state.playback_time_ms = 0;
    strncpy(g_recorder_state.current_filename, filename, MAX_FILENAME_LEN - 1);
    
    printf("Playback started\n");
    return 0;
}

int stop_playback(void) {
    if (!g_recorder_state.playing) {
        printf("ERROR: Not playing\n");
        return -1;
    }
    
    printf("Stopping playback: %s\n", g_recorder_state.current_filename);
    
    // Stop playback
    uint32_t control = read_reg(CONTROL_REG);
    control &= ~CTRL_PLAYBACK_EN;
    write_reg(CONTROL_REG, control);
    
    // Wait for playback to stop
    int timeout = 100000;
    while ((read_reg(STATUS_REG) & STATUS_PLAYING) && timeout--);
    
    g_recorder_state.playing = false;
    
    printf("Playback stopped\n");
    return 0;
}

// Configuration functions
int set_sample_rate(uint8_t sample_rate) {
    if (sample_rate > SAMPLE_RATE_16KHZ) {
        printf("ERROR: Invalid sample rate\n");
        return -1;
    }
    
    if (g_recorder_state.recording || g_recorder_state.playing) {
        printf("ERROR: Cannot change sample rate during recording/playback\n");
        return -2;
    }
    
    g_recorder_state.sample_rate = sample_rate;
    write_reg(ADC_CONFIG_REG, sample_rate);
    
    const char* rate_str[] = {"48kHz", "44.1kHz", "32kHz", "16kHz"};
    printf("Sample rate set to %s\n", rate_str[sample_rate]);
    
    return 0;
}

int set_compression(uint8_t compression) {
    if (compression > COMPRESSION_8TO1) {
        printf("ERROR: Invalid compression setting\n");
        return -1;
    }
    
    if (g_recorder_state.recording) {
        printf("ERROR: Cannot change compression during recording\n");
        return -2;
    }
    
    g_recorder_state.compression = compression;
    write_reg(COMPRESSION_REG, compression);
    
    const char* comp_str[] = {"None", "2:1", "4:1", "8:1"};
    printf("Compression set to %s\n", comp_str[compression]);
    
    return 0;
}

// Status and monitoring functions
void update_status(void) {
    uint32_t status = read_reg(STATUS_REG);
    
    g_recorder_state.recording = (status & STATUS_RECORDING) != 0;
    g_recorder_state.playing = (status & STATUS_PLAYING) != 0;
    g_recorder_state.sd_ready = (status & STATUS_SD_READY) != 0;
    
    if (g_recorder_state.recording) {
        g_recorder_state.recording_time_ms = read_reg(RECORDING_TIME_REG);
    }
    
    if (g_recorder_state.playing) {
        g_recorder_state.playback_time_ms = read_reg(PLAYBACK_TIME_REG);
    }
}

void print_status(void) {
    update_status();
    
    printf("\n=== Underwater Recorder Status ===\n");
    printf("Recording: %s", g_recorder_state.recording ? "YES" : "NO");
    if (g_recorder_state.recording) {
        printf(" (%s, %d ms)", g_recorder_state.current_filename, g_recorder_state.recording_time_ms);
    }
    printf("\n");
    
    printf("Playing: %s", g_recorder_state.playing ? "YES" : "NO");
    if (g_recorder_state.playing) {
        printf(" (%s, %d ms)", g_recorder_state.current_filename, g_recorder_state.playback_time_ms);
    }
    printf("\n");
    
    printf("SD Card: %s\n", g_recorder_state.sd_ready ? "READY" : "NOT READY");
    
    const char* rate_str[] = {"48kHz", "44.1kHz", "32kHz", "16kHz"};
    const char* comp_str[] = {"None", "2:1", "4:1", "8:1"};
    printf("Sample Rate: %s\n", rate_str[g_recorder_state.sample_rate]);
    printf("Compression: %s\n", comp_str[g_recorder_state.compression]);
    
    printf("Files: %d/%d\n", g_recorder_state.filesystem.total_files, MAX_FILES);
    printf("Free Space: %d sectors (%.1f MB)\n", 
           g_recorder_state.filesystem.free_sectors,
           (float)g_recorder_state.filesystem.free_sectors * SECTOR_SIZE / (1024 * 1024));
    printf("================================\n\n");
}

void list_files(void) {
    printf("\n=== Recorded Files ===\n");
    printf("%-20s %-10s %-10s %-12s %-10s\n", "Filename", "Duration", "Size(MB)", "Sample Rate", "Compression");
    printf("--------------------------------------------------------------------------------\n");
    
    for (int i = 0; i < g_recorder_state.filesystem.total_files; i++) {
        audio_file_t* file = &g_recorder_state.filesystem.files[i];
        const char* rate_str[] = {"48kHz", "44.1kHz", "32kHz", "16kHz"};
        const char* comp_str[] = {"None", "2:1", "4:1", "8:1"};
        
        printf("%-20s %-10d %-10.2f %-12s %-10s\n",
               file->filename,
               file->duration_ms,
               (float)file->size_sectors * SECTOR_SIZE / (1024 * 1024),
               rate_str[file->sample_rate],
               comp_str[file->compression]);
    }
    printf("======================\n\n");
}

// Utility functions
uint32_t get_timestamp(void) {
    // In a real implementation, this would return current timestamp
    // For now, return a dummy value
    static uint32_t counter = 1000000000;
    return counter++;
}

int delete_file(const char* filename) {
    // Find file
    int file_index = -1;
    for (int i = 0; i < g_recorder_state.filesystem.total_files; i++) {
        if (strcmp(g_recorder_state.filesystem.files[i].filename, filename) == 0) {
            file_index = i;
            break;
        }
    }
    
    if (file_index == -1) {
        printf("ERROR: File not found: %s\n", filename);
        return -1;
    }
    
    printf("Deleting file: %s\n", filename);
    
    // Add freed sectors back to available space
    g_recorder_state.filesystem.free_sectors += g_recorder_state.filesystem.files[file_index].size_sectors;
    
    // Shift remaining files down to fill the gap
    for (int i = file_index; i < g_recorder_state.filesystem.total_files - 1; i++) {
        g_recorder_state.filesystem.files[i] = g_recorder_state.filesystem.files[i + 1];
    }
    
    // Clear the last file entry
    memset(&g_recorder_state.filesystem.files[g_recorder_state.filesystem.total_files - 1], 
           0, sizeof(audio_file_t));
    
    g_recorder_state.filesystem.total_files--;
    
    // Save updated file system
    save_filesystem();
    
    printf("File deleted successfully\n");
    return 0;
}

int format_sd_card(void) {
    printf("WARNING: This will erase all recorded files!\n");
    printf("Are you sure you want to format the SD card? (y/N): ");
    
    char response;
    scanf(" %c", &response);
    
    if (response != 'y' && response != 'Y') {
        printf("Format cancelled\n");
        return 0;
    }
    
    printf("Formatting SD card...\n");
    
    // Stop any ongoing operations
    if (g_recorder_state.recording) {
        stop_recording();
    }
    if (g_recorder_state.playing) {
        stop_playback();
    }
    
    // Clear file system
    memset(&g_recorder_state.filesystem, 0, sizeof(file_system_t));
    g_recorder_state.filesystem.total_sectors = 1024 * 1024; // 512MB
    g_recorder_state.filesystem.free_sectors = g_recorder_state.filesystem.total_sectors - 1;
    
    // Save empty file system
    save_filesystem();
    
    printf("SD card formatted successfully\n");
    return 0;
}

int defragment_storage(void) {
    printf("Defragmenting storage...\n");
    
    if (g_recorder_state.recording || g_recorder_state.playing) {
        printf("ERROR: Cannot defragment during recording/playback\n");
        return -1;
    }
    
    // Sort files by start sector to identify fragmentation
    for (int i = 0; i < g_recorder_state.filesystem.total_files - 1; i++) {
        for (int j = i + 1; j < g_recorder_state.filesystem.total_files; j++) {
            if (g_recorder_state.filesystem.files[i].start_sector > 
                g_recorder_state.filesystem.files[j].start_sector) {
                audio_file_t temp = g_recorder_state.filesystem.files[i];
                g_recorder_state.filesystem.files[i] = g_recorder_state.filesystem.files[j];
                g_recorder_state.filesystem.files[j] = temp;
            }
        }
    }
    
    // Compact files to eliminate gaps
    uint32_t next_sector = 1; // Skip file system sector
    for (int i = 0; i < g_recorder_state.filesystem.total_files; i++) {
        if (g_recorder_state.filesystem.files[i].start_sector != next_sector) {
            printf("Moving file %s from sector %d to %d\n", 
                   g_recorder_state.filesystem.files[i].filename,
                   g_recorder_state.filesystem.files[i].start_sector,
                   next_sector);
            
            // In a real implementation, you would move the actual file data
            g_recorder_state.filesystem.files[i].start_sector = next_sector;
        }
        next_sector += g_recorder_state.filesystem.files[i].size_sectors;
    }
    
    // Update free sectors count
    g_recorder_state.filesystem.free_sectors = g_recorder_state.filesystem.total_sectors - next_sector;
    
    save_filesystem();
    
    printf("Defragmentation complete\n");
    return 0;
}

void print_help(void) {
    printf("\n=== Underwater Recorder Commands ===\n");
    printf("record <filename>    - Start recording to file\n");
    printf("stop                 - Stop current recording\n");
    printf("play <filename>      - Play recorded file\n");
    printf("pause                - Stop current playback\n");
    printf("list                 - List all recorded files\n");
    printf("delete <filename>    - Delete a file\n");
    printf("status               - Show system status\n");
    printf("rate <0-3>          - Set sample rate (0=48kHz, 1=44.1kHz, 2=32kHz, 3=16kHz)\n");
    printf("compress <0-3>      - Set compression (0=None, 1=2:1, 2=4:1, 3=8:1)\n");
    printf("format              - Format SD card (CAUTION: Erases all files!)\n");
    printf("defrag              - Defragment storage\n");
    printf("help                - Show this help\n");
    printf("quit                - Exit program\n");
    printf("=====================================\n\n");
}

int command_interface(void) {
    char command[256];
    char filename[MAX_FILENAME_LEN];
    int value;
    
    printf("Underwater Recorder Command Interface\n");
    printf("Type 'help' for available commands\n\n");
    
    while (1) {
        printf("recorder> ");
        if (!fgets(command, sizeof(command), stdin)) {
            break;
        }
        
        // Remove newline
        command[strcspn(command, "\n")] = 0;
        
        // Parse command
        if (sscanf(command, "record %255s", filename) == 1) {
            start_recording(filename);
        }
        else if (strcmp(command, "stop") == 0) {
            if (g_recorder_state.recording) {
                stop_recording();
            } else {
                printf("Not currently recording\n");
            }
        }
        else if (sscanf(command, "play %255s", filename) == 1) {
            start_playback(filename);
        }
        else if (strcmp(command, "pause") == 0) {
            if (g_recorder_state.playing) {
                stop_playback();
            } else {
                printf("Not currently playing\n");
            }
        }
        else if (strcmp(command, "list") == 0) {
            list_files();
        }
        else if (sscanf(command, "delete %255s", filename) == 1) {
            delete_file(filename);
        }
        else if (strcmp(command, "status") == 0) {
            print_status();
        }
        else if (sscanf(command, "rate %d", &value) == 1) {
            set_sample_rate((uint8_t)value);
        }
        else if (sscanf(command, "compress %d", &value) == 1) {
            set_compression((uint8_t)value);
        }
        else if (strcmp(command, "format") == 0) {
            format_sd_card();
        }
        else if (strcmp(command, "defrag") == 0) {
            defragment_storage();
        }
        else if (strcmp(command, "help") == 0) {
            print_help();
        }
        else if (strcmp(command, "quit") == 0 || strcmp(command, "exit") == 0) {
            break;
        }
        else if (strlen(command) > 0) {
            printf("Unknown command: %s\n", command);
            printf("Type 'help' for available commands\n");
        }
    }
    
    return 0;
}

// Main function for testing
int main(void) {
    printf("Underwater Recorder SoC Control Software\n");
    printf("========================================\n\n");
    
    // Initialize the recorder
    if (recorder_init() != 0) {
        printf("Failed to initialize recorder\n");
        return -1;
    }
    
    // Show initial status
    print_status();
    
    // Enter command interface
    command_interface();
    
    // Cleanup
    if (g_recorder_state.recording) {
        stop_recording();
    }
    if (g_recorder_state.playing) {
        stop_playback();
    }
    
    printf("Underwater Recorder shutdown complete\n");
    return 0;
}
