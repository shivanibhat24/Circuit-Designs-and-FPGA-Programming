ARCHITECTURE netlist OF mux IS
COMPONENT andgate
PORT(a, b, c : IN bit; c : OUT BIT);
END COMPONENT;
COMPONENT inverter
PORT(in1 : IN BIT; x : OUT BIT);
END COMPONENT;
COMPONENT orgate
PORT(a, b, c, d : IN bit; x : OUT BIT);
END COMPONENT;
SIGNAL s0_inv, s1_inv, x1, x2, x3, x4 : BIT;
BEGIN
U1 : inverter(s0, s0_inv);
U2 : inverter(s1, s1_inv);
U3 : andgate(a, s0_inv, s1_inv, x1);
U4 : andgate(b, s0, s1_inv, x2);
U5 : andgate(c, s0_inv, s1, x3);
U6 : andgate(d, s0, s1, x4);
U7 : orgate(x2 => b, x1 => a, x4 => d, x3 => c, x => x);
END netlist;
