#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_NAME_LENGTH 100
#define MAX_MODULES 1000
#define MAX_INSTANCES 1000
#define MAX_PORTS 100
#define MAX_CONNECTIONS 1000

// Structures to represent netlist components
typedef struct {
    char name[MAX_NAME_LENGTH];
    char type[MAX_NAME_LENGTH];
} Port;

typedef struct {
    char name[MAX_NAME_LENGTH];
    char type[MAX_NAME_LENGTH];
    Port ports[MAX_PORTS];
    int port_count;
} Module;

typedef struct {
    char name[MAX_NAME_LENGTH];
    char module_name[MAX_NAME_LENGTH];
    Port port_connections[MAX_PORTS];
    int connection_count;
} ModuleInstance;

// Global data structures
Module modules[MAX_MODULES];
int module_count = 0;

ModuleInstance instances[MAX_INSTANCES];
int instance_count = 0;

// Function prototypes
void add_module(const char* name, const char* type);
void add_module_port(const char* module_name, const char* port_name, const char* port_type);
void add_module_instance(const char* instance_name, const char* module_name);
void connect_port(const char* instance_name, const char* port_name, const char* connection);
void flatten_netlist(const char* top_module_name);
void print_flattened_netlist();

// Add a new module to the netlist
void add_module(const char* name, const char* type) {
    if (module_count >= MAX_MODULES) {
        fprintf(stderr, "Error: Maximum module limit reached\n");
        return;
    }

    Module* module = &modules[module_count];
    strncpy(module->name, name, MAX_NAME_LENGTH - 1);
    strncpy(module->type, type, MAX_NAME_LENGTH - 1);
    module->port_count = 0;
    module_count++;
}

// Add a port to a specific module
void add_module_port(const char* module_name, const char* port_name, const char* port_type) {
    for (int i = 0; i < module_count; i++) {
        if (strcmp(modules[i].name, module_name) == 0) {
            if (modules[i].port_count >= MAX_PORTS) {
                fprintf(stderr, "Error: Maximum port limit reached for module %s\n", module_name);
                return;
            }

            Port* port = &modules[i].ports[modules[i].port_count];
            strncpy(port->name, port_name, MAX_NAME_LENGTH - 1);
            strncpy(port->type, port_type, MAX_NAME_LENGTH - 1);
            modules[i].port_count++;
            return;
        }
    }
    fprintf(stderr, "Error: Module %s not found\n", module_name);
}

// Add a module instance to the netlist
void add_module_instance(const char* instance_name, const char* module_name) {
    if (instance_count >= MAX_INSTANCES) {
        fprintf(stderr, "Error: Maximum instance limit reached\n");
        return;
    }

    ModuleInstance* instance = &instances[instance_count];
    strncpy(instance->name, instance_name, MAX_NAME_LENGTH - 1);
    strncpy(instance->module_name, module_name, MAX_NAME_LENGTH - 1);
    instance->connection_count = 0;
    instance_count++;
}

// Connect a port of an instance to a signal
void connect_port(const char* instance_name, const char* port_name, const char* connection) {
    for (int i = 0; i < instance_count; i++) {
        if (strcmp(instances[i].name, instance_name) == 0) {
            if (instances[i].connection_count >= MAX_PORTS) {
                fprintf(stderr, "Error: Maximum port connections reached for instance %s\n", instance_name);
                return;
            }

            Port* port_connection = &instances[i].port_connections[instances[i].connection_count];
            strncpy(port_connection->name, port_name, MAX_NAME_LENGTH - 1);
            strncpy(port_connection->type, connection, MAX_NAME_LENGTH - 1);
            instances[i].connection_count++;
            return;
        }
    }
    fprintf(stderr, "Error: Instance %s not found\n", instance_name);
}

// Flatten the netlist starting from the top module
void flatten_netlist(const char* top_module_name) {
    printf("Flattening Netlist from Top Module: %s\n", top_module_name);
    printf("-----------------------------------\n");
}

// Print the flattened netlist
void print_flattened_netlist() {
    printf("\nFlattened Netlist:\n");
    printf("------------------\n");
    
    for (int i = 0; i < instance_count; i++) {
        printf("Instance: %s (Module: %s)\n", instances[i].name, instances[i].module_name);
        
        // Find the corresponding module
        for (int j = 0; j < module_count; j++) {
            if (strcmp(modules[j].name, instances[i].module_name) == 0) {
                printf("  Ports:\n");
                for (int k = 0; k < modules[j].port_count; k++) {
                    printf("    - %s (%s)\n", 
                           modules[j].ports[k].name, 
                           modules[j].ports[k].type);
                }
                break;
            }
        }

        printf("  Port Connections:\n");
        for (int k = 0; k < instances[i].connection_count; k++) {
            printf("    - %s -> %s\n", 
                   instances[i].port_connections[k].name,
                   instances[i].port_connections[k].type);
        }
        printf("\n");
    }
}

int main() {
    // Example usage of Netlist Flattener
    
    // Define modules
    add_module("and_gate", "primitive");
    add_module_port("and_gate", "a", "input");
    add_module_port("and_gate", "b", "input");
    add_module_port("and_gate", "y", "output");

    add_module("or_gate", "primitive");
    add_module_port("or_gate", "a", "input");
    add_module_port("or_gate", "b", "input");
    add_module_port("or_gate", "y", "output");

    add_module("complex_module", "hierarchical");
    add_module_port("complex_module", "x", "input");
    add_module_port("complex_module", "y", "input");
    add_module_port("complex_module", "z", "output");

    // Create module instances
    add_module_instance("and1", "and_gate");
    add_module_instance("or1", "or_gate");
    add_module_instance("complex1", "complex_module");

    // Connect ports
    connect_port("and1", "a", "signal_a");
    connect_port("and1", "b", "signal_b");
    connect_port("and1", "y", "and_output");

    connect_port("or1", "a", "signal_c");
    connect_port("or1", "b", "signal_d");
    connect_port("or1", "y", "or_output");

    connect_port("complex1", "x", "input_x");
    connect_port("complex1", "y", "input_y");
    connect_port("complex1", "z", "output_z");

    // Flatten netlist
    flatten_netlist("complex_module");

    // Print flattened netlist
    print_flattened_netlist();

    return 0;
}
