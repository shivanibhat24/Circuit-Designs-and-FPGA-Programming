#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <float.h>
#include <limits.h>

#define MAX_NODES 1000
#define MAX_NAME_LENGTH 50

// Enum for gate types
typedef enum {
    GATE_AND,
    GATE_OR,
    GATE_NOT,
    GATE_NAND,
    GATE_NOR,
    GATE_XOR,
    INPUT,
    OUTPUT
} GateType;

// Node structure representing circuit elements
typedef struct Node {
    char name[MAX_NAME_LENGTH];
    GateType type;
    double delay;
    double arrival_time;
    double required_time;
    double slack;
    struct Node* inputs[4];  // Support up to 4 inputs
    int input_count;
    struct Node* outputs[4]; // Support up to 4 outputs
    int output_count;
} Node;

// Graph structure for the entire circuit
typedef struct {
    Node* nodes[MAX_NODES];
    int node_count;
} Circuit;

// Function prototypes
Circuit* create_circuit();
Node* create_node(Circuit* circuit, const char* name, GateType type);
void add_connection(Node* source, Node* destination);
void compute_delays(Circuit* circuit);
void compute_arrival_times(Circuit* circuit);
void compute_required_times(Circuit* circuit);
void compute_slack(Circuit* circuit);
void find_critical_paths(Circuit* circuit);
void print_circuit_timing(Circuit* circuit);

// Create a new circuit
Circuit* create_circuit() {
    Circuit* circuit = malloc(sizeof(Circuit));
    circuit->node_count = 0;
    return circuit;
}

// Create a new node and add to circuit
Node* create_node(Circuit* circuit, const char* name, GateType type) {
    if (circuit->node_count >= MAX_NODES) {
        fprintf(stderr, "Circuit node limit exceeded\n");
        return NULL;
    }

    Node* node = malloc(sizeof(Node));
    strncpy(node->name, name, MAX_NAME_LENGTH - 1);
    node->type = type;
    node->delay = 0.0;
    node->arrival_time = 0.0;
    node->required_time = DBL_MAX;
    node->slack = 0.0;
    node->input_count = 0;
    node->output_count = 0;

    // Assign gate delays based on type
    switch(type) {
        case GATE_AND:   node->delay = 0.5; break;
        case GATE_OR:    node->delay = 0.6; break;
        case GATE_NOT:   node->delay = 0.3; break;
        case GATE_NAND:  node->delay = 0.4; break;
        case GATE_NOR:   node->delay = 0.5; break;
        case GATE_XOR:   node->delay = 0.7; break;
        case INPUT:      node->delay = 0.0; break;
        case OUTPUT:     node->delay = 0.2; break;
    }

    circuit->nodes[circuit->node_count++] = node;
    return node;
}

// Add connection between nodes
void add_connection(Node* source, Node* destination) {
    if (source->output_count < 4 && destination->input_count < 4) {
        source->outputs[source->output_count++] = destination;
        destination->inputs[destination->input_count++] = source;
    }
}

// Compute arrival times for all nodes (forward traversal)
void compute_arrival_times(Circuit* circuit) {
    for (int i = 0; i < circuit->node_count; i++) {
        Node* node = circuit->nodes[i];
        
        if (node->type == INPUT) {
            node->arrival_time = 0.0;
            continue;
        }

        // Find max arrival time of inputs
        double max_input_arrival = 0.0;
        for (int j = 0; j < node->input_count; j++) {
            max_input_arrival = fmax(max_input_arrival, 
                node->inputs[j]->arrival_time + node->inputs[j]->delay);
        }

        node->arrival_time = max_input_arrival;
    }
}

// Compute required times (backward traversal)
void compute_required_times(Circuit* circuit) {
    // Find the max arrival time (critical path)
    double max_arrival_time = 0.0;
    Node* sink_node = NULL;
    for (int i = 0; i < circuit->node_count; i++) {
        if (circuit->nodes[i]->type == OUTPUT && 
            circuit->nodes[i]->arrival_time > max_arrival_time) {
            max_arrival_time = circuit->nodes[i]->arrival_time;
            sink_node = circuit->nodes[i];
        }
    }

    if (sink_node) {
        sink_node->required_time = max_arrival_time;

        // Backward traversal
        for (int i = circuit->node_count - 1; i >= 0; i--) {
            Node* node = circuit->nodes[i];
            
            if (node->type == OUTPUT) continue;

            for (int j = 0; j < node->output_count; j++) {
                node->required_time = fmin(node->required_time, 
                    node->outputs[j]->required_time - node->delay);
            }
        }
    }
}

// Compute slack for each node
void compute_slack(Circuit* circuit) {
    for (int i = 0; i < circuit->node_count; i++) {
        Node* node = circuit->nodes[i];
        node->slack = node->required_time - node->arrival_time;
    }
}

// Print circuit timing information
void print_circuit_timing(Circuit* circuit) {
    printf("Circuit Timing Analysis:\n");
    printf("---------------------\n");
    
    for (int i = 0; i < circuit->node_count; i++) {
        Node* node = circuit->nodes[i];
        printf("Node: %s\n", node->name);
        printf("  Type: %d\n", node->type);
        printf("  Delay: %.2f ns\n", node->delay);
        printf("  Arrival Time: %.2f ns\n", node->arrival_time);
        printf("  Required Time: %.2f ns\n", node->required_time);
        printf("  Slack: %.2f ns\n\n", node->slack);
    }
}

// Example usage
int main() {
    Circuit* circuit = create_circuit();

    // Create nodes
    Node* input1 = create_node(circuit, "IN1", INPUT);
    Node* input2 = create_node(circuit, "IN2", INPUT);
    Node* and_gate = create_node(circuit, "AND1", GATE_AND);
    Node* not_gate = create_node(circuit, "NOT1", GATE_NOT);
    Node* output = create_node(circuit, "OUT", OUTPUT);

    // Connect nodes
    add_connection(input1, and_gate);
    add_connection(input2, and_gate);
    add_connection(and_gate, not_gate);
    add_connection(not_gate, output);

    // Perform STA
    compute_arrival_times(circuit);
    compute_required_times(circuit);
    compute_slack(circuit);

    // Print results
    print_circuit_timing(circuit);

    return 0;
}
