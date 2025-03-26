#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <float.h>

#define MAX_NODES 1000
#define MAX_NAME_LENGTH 50
#define MAX_CHILDREN 10

// Enum for clock tree node types
typedef enum {
    CLOCK_SOURCE,
    CLOCK_BUFFER,
    CLOCK_LEAF,
    CLOCK_ENDPOINT
} ClockNodeType;

// Clock tree node structure
typedef struct ClockNode {
    char name[MAX_NAME_LENGTH];
    ClockNodeType type;
    
    // Timing parameters
    double arrival_time;
    double insertion_delay;
    double wire_length;
    double capacitance;
    
    // Tree structure
    struct ClockNode* parent;
    struct ClockNode* children[MAX_CHILDREN];
    int child_count;
    
    // Skew-related information
    double skew_to_siblings;
    double skew_to_endpoints;
} ClockNode;

// Clock tree structure
typedef struct {
    ClockNode* root;
    ClockNode* nodes[MAX_NODES];
    int node_count;
} ClockTree;

// Function prototypes
ClockTree* create_clock_tree();
ClockNode* create_clock_node(ClockTree* tree, const char* name, ClockNodeType type);
void add_clock_node(ClockTree* tree, ClockNode* parent, ClockNode* child);
void compute_insertion_delays(ClockTree* tree);
void compute_clock_skew(ClockTree* tree);
void print_clock_tree_analysis(ClockTree* tree);

// Create a new clock tree
ClockTree* create_clock_tree() {
    ClockTree* tree = malloc(sizeof(ClockTree));
    tree->root = NULL;
    tree->node_count = 0;
    return tree;
}

// Create a new clock node
ClockNode* create_clock_node(ClockTree* tree, const char* name, ClockNodeType type) {
    if (tree->node_count >= MAX_NODES) {
        fprintf(stderr, "Clock tree node limit exceeded\n");
        return NULL;
    }

    ClockNode* node = malloc(sizeof(ClockNode));
    strncpy(node->name, name, MAX_NAME_LENGTH - 1);
    node->type = type;
    
    // Initialize timing parameters
    node->arrival_time = 0.0;
    node->insertion_delay = 0.0;
    node->wire_length = 0.0;
    node->capacitance = 0.0;
    
    // Initialize tree structure
    node->parent = NULL;
    node->child_count = 0;
    
    // Initialize skew parameters
    node->skew_to_siblings = 0.0;
    node->skew_to_endpoints = 0.0;

    // Set as root if it's the first node
    if (tree->node_count == 0) {
        tree->root = node;
    }

    // Add to tree's node list
    tree->nodes[tree->node_count++] = node;
    
    return node;
}

// Add a child node to the clock tree
void add_clock_node(ClockTree* tree, ClockNode* parent, ClockNode* child) {
    if (parent->child_count >= MAX_CHILDREN) {
        fprintf(stderr, "Maximum children limit reached for node %s\n", parent->name);
        return;
    }

    // Add child to parent's children
    parent->children[parent->child_count++] = child;
    
    // Set parent reference
    child->parent = parent;
}

// Compute insertion delays through the clock tree
void compute_insertion_delays(ClockTree* tree) {
    // Recursive depth-first traversal
    void traverse_and_compute(ClockNode* node, double parent_delay) {
        if (!node) return;

        // Compute insertion delay based on wire length and capacitance
        // Simple model: delay = wire_length * capacitance
        node->insertion_delay = parent_delay + (node->wire_length * node->capacitance);
        
        // Compute arrival time
        if (node->parent) {
            node->arrival_time = node->parent->arrival_time + node->insertion_delay;
        }

        // Recursively compute for children
        for (int i = 0; i < node->child_count; i++) {
            traverse_and_compute(node->children[i], node->insertion_delay);
        }
    }

    // Start traversal from root
    if (tree->root) {
        traverse_and_compute(tree->root, 0.0);
    }
}

// Compute clock skew between nodes
void compute_clock_skew(ClockTree* tree) {
    // Compute skew between sibling nodes
    void compute_sibling_skew(ClockNode* node) {
        if (!node || node->child_count <= 1) return;

        // Compare arrival times of sibling nodes
        for (int i = 0; i < node->child_count; i++) {
            for (int j = i + 1; j < node->child_count; j++) {
                node->children[i]->skew_to_siblings = 
                    fabs(node->children[i]->arrival_time - 
                         node->children[j]->arrival_time);
            }
        }

        // Recursively compute for children
        for (int i = 0; i < node->child_count; i++) {
            compute_sibling_skew(node->children[i]);
        }
    }

    // Compute skew to endpoints
    void compute_endpoint_skew(ClockNode* node, double reference_time) {
        if (!node) return;

        // If it's a leaf or endpoint, compute skew from reference
        if (node->type == CLOCK_LEAF || node->type == CLOCK_ENDPOINT) {
            node->skew_to_endpoints = fabs(node->arrival_time - reference_time);
        }

        // Recursively compute for children
        for (int i = 0; i < node->child_count; i++) {
            compute_endpoint_skew(node->children[i], reference_time);
        }
    }

    // Perform skew computations
    if (tree->root) {
        compute_sibling_skew(tree->root);
        compute_endpoint_skew(tree->root, tree->root->arrival_time);
    }
}

// Print clock tree analysis results
void print_clock_tree_analysis(ClockTree* tree) {
    printf("Clock Tree Analysis Results:\n");
    printf("---------------------------\n");

    // Recursive printing function
    void print_node(ClockNode* node, int depth) {
        if (!node) return;

        // Indent based on depth
        for (int i = 0; i < depth; i++) printf("  ");

        printf("Node: %s\n", node->name);
        
        // Indent and print details
        for (int i = 0; i < depth + 1; i++) printf("  ");
        printf("Type: %d\n", node->type);
        
        for (int i = 0; i < depth + 1; i++) printf("  ");
        printf("Arrival Time: %.3f ns\n", node->arrival_time);
        
        for (int i = 0; i < depth + 1; i++) printf("  ");
        printf("Insertion Delay: %.3f ns\n", node->insertion_delay);
        
        for (int i = 0; i < depth + 1; i++) printf("  ");
        printf("Sibling Skew: %.3f ns\n", node->skew_to_siblings);
        
        for (int i = 0; i < depth + 1; i++) printf("  ");
        printf("Endpoint Skew: %.3f ns\n", node->skew_to_endpoints);

        // Recursively print children
        for (int i = 0; i < node->child_count; i++) {
            print_node(node->children[i], depth + 1);
        }
    }

    // Start printing from root
    if (tree->root) {
        print_node(tree->root, 0);
    }
}

// Example usage
int main() {
    // Create clock tree
    ClockTree* clock_tree = create_clock_tree();

    // Create clock tree nodes
    ClockNode* clock_source = create_clock_node(clock_tree, "CLK_SRC", CLOCK_SOURCE);
    clock_source->arrival_time = 0.0;
    
    // Level 1 buffers
    ClockNode* buffer1 = create_clock_node(clock_tree, "CLK_BUF1", CLOCK_BUFFER);
    buffer1->wire_length = 10.0;
    buffer1->capacitance = 0.5;
    
    ClockNode* buffer2 = create_clock_node(clock_tree, "CLK_BUF2", CLOCK_BUFFER);
    buffer2->wire_length = 12.0;
    buffer2->capacitance = 0.6;

    // Add nodes to tree
    add_clock_node(clock_tree, clock_source, buffer1);
    add_clock_node(clock_tree, clock_source, buffer2);

    // Level 2 endpoints
    ClockNode* endpoint1 = create_clock_node(clock_tree, "CLK_EP1", CLOCK_ENDPOINT);
    endpoint1->wire_length = 5.0;
    endpoint1->capacitance = 0.3;
    
    ClockNode* endpoint2 = create_clock_node(clock_tree, "CLK_EP2", CLOCK_ENDPOINT);
    endpoint2->wire_length = 7.0;
    endpoint2->capacitance = 0.4;

    // Add endpoints to buffers
    add_clock_node(clock_tree, buffer1, endpoint1);
    add_clock_node(clock_tree, buffer2, endpoint2);

    // Perform clock tree analysis
    compute_insertion_delays(clock_tree);
    compute_clock_skew(clock_tree);

    // Print analysis results
    print_clock_tree_analysis(clock_tree);

    return 0;
}
