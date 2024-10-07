# ZK Summit 12 Workshop

This README provides complementary material for the ZK-12 workshop.

## Installation
To participate in the workshop, the recommended approach is to run the provided Docker image.

### Docker
Run the following command in the root directory of the repository:
```bash
docker build -t co-snarks . && docker run -it co-snarks
```

### Manual Installation
If you'd prefer to install everything manually, follow the instructions from our [GitHub](https://github.com/TaceoLabs/collaborative-circom). Additionally, you will need to install [Noir](https://noir-lang.org/docs/getting_started/installation/).

By the end of this setup, you should have the following tools installed:
* `co-circom`
* `circom`
* `snarkJS`
* `Noir` (`nargo`)

## The Millionaires Problem
 For this example, we'll work in the `/circom/mill_problem` folder. . To make things easier, we’ve provided a `justfile` that automates all the necessary commands. Since you’ll need to run specific commands on all "MPC-nodes" simultaneously, it can be a bit cumbersome to manage this in Docker. That's why we’ve included the `justfile` — and don't worry, the container already comes with `just` pre-installed to streamline the process.

### Compiling the Circuit

The first step is to compile the circuit into R1CS format. To do that, run:

```bash
circom --r1cs mill_problem.circom -l libs
```
In this command:
* The `--r1cs` flag tells the Circom compiler to output the circuit in R1CS format.
* The `-l` flag specifies the directory where your libraries are located.

After running this, you’ll generate a file called `mill_problem.r1cs`. The compiler will also provide some useful output, such as the number of constraints, as well as details about the public and private inputs.

### Secret Sharing the Input

Now, let’s prepare the inputs for the circuit. Since we are simulating two parties, we have two input files: `input.alice.json` and `input.bob.json`.

To view the input files, use the following command:

```bash
bat input.alice.json
```

Now split the input (secret-share):

```bash
#split input Alice
co-circom split-input --circuit mill_problem.circom --input input.alice.json --protocol REP3 --out-dir out/secret_shared_inputs/ --curve BN254

#split input Bob
co-circom split-input --circuit mill_problem.circom --input input.bob.json --protocol REP3 --out-dir out/secret_shared_inputs/ --curve BN254
```
or use the `justfile`

```bash
just split-input
```

You’ll now find 6 files in the `out/secret_shared_inputs` directory. Each file contains the secret-shared inputs for the respective parties. For example,
`input.alice.json.0.shared` holds Alice's secret-shared input for party 0, and `input.bob.json.1.shared` contains Bob’s secret-shared input for party 1, and so on.

Keep in mind, this process is typically done on two separate machines in a real-world setting!

### Merging the Input

Once the input is secret-shared, the next step is to merge the secret-shared inputs on each of the MPC nodes. In a real-world scenario, Alice and Bob would send their secret-shared inputs to the MPC nodes. However, for this example, we’ll simulate this process by merging the inputs on a single machine. We’ll need to do this three times—once for each node.

```bash
#merge input for party 0
co-circom merge-input-shares --inputs out/secret_shared_inputs/input.alice.json.0.shared --inputs out/secret_shared_inputs/input.bob.json.0.shared --protocol REP3 --out out/merged_inputs/input.json.0.shared --curve BN254

#merge input for party 1
co-circom merge-input-shares --inputs out/secret_shared_inputs/input.alice.json.1.shared --inputs out/secret_shared_inputs/input.bob.json.1.shared --protocol REP3 --out out/merged_inputs/input.json.1.shared --curve BN254

#merge input for party 2
co-circom merge-input-shares --inputs out/secret_shared_inputs/input.alice.json.2.shared --inputs out/secret_shared_inputs/input.bob.json.2.shared --protocol REP3 --out out/merged_inputs/input.json.2.shared --curve BN254
```
or 

```bash
just merge-input
```

We now have three files in the `out/merged_inputs` directory.

### Generating the Extended Witness

Now that all the MPC nodes have the secret-shared, merged input, the next step is to generate the extended witness. This step involves running a specific command on each MPC node. Since this is a dedicated process, you’ll either need to open three terminal sessions or simply use the provided `justfile` to streamline the process.

```bash
# start party 0
co-circom generate-witness --input out/merged_inputs/input.json.0.shared --circuit mill_problem.circom --protocol REP3 --config ../../configs/party0.toml --out out/witness/witness.wtns.0.shared --curve BN254

# start party 1
co-circom generate-witness --input out/merged_inputs/input.json.1.shared --circuit mill_problem.circom --protocol REP3 --config ../../configs/party1.toml --out out/witness/witness.wtns.1.shared --curve BN254

# start party 2
co-circom generate-witness --input out/merged_inputs/input.json.2.shared --circuit mill_problem.circom --protocol REP3 --config ../../configs/party2.toml --out out/witness/witness.wtns.2.shared --curve BN254
```
or

```bash
just run-witness-generation
```

This step might take a few seconds (but shouldn’t be too long). Once it’s complete, you’ll find the secret-shared witness in the `out/witness` folder.

### Generating the Proof

Now for the final step — generating the proof! You can do this by running the following commands on each MPC-node:

```bash
# start party 0
co-circom generate-proof --witness out/witness/witness.wtns.0.shared --zkey mill_problem.zkey --protocol REP3 --config ../../configs/party0.toml --out out/proofs/proof.0.json --public-input out/proofs/public_input.0.json groth16 --curve BN254

# start party 1
co-circom generate-proof --witness out/witness/witness.wtns.1.shared --zkey mill_problem.zkey --protocol REP3 --config ../../configs/party1.toml --out out/proofs/proof.1.json --public-input out/proofs/public_input.1.json groth16 --curve BN254

# start party 2
co-circom generate-proof --witness out/witness/witness.wtns.2.shared --zkey mill_problem.zkey --protocol REP3 --config ../../configs/party2.toml --out out/proofs/proof.2.json --public-input out/proofs/public_input.2.json groth16 --curve BN254
```
or use the `justfile`

```bash
just run-proof-groth16
```

Congratulations! 🎉 You’ve successfully generated the proof! You can find three proof files in the 
`out/proofs` directory. The public input is also stored in the same location. Both the proofs and public inputs are in JSON format and correspond to each other.


### Verifying the Proof with co-circom

You can easily verify the proof using the `co-circom` tool. Simply run the following command:

```bash
co-circom verify --proof out/proofs/proof.0.json --vk verification_key.json --public-input out/proofs/public_input.0.json groth16 --curve BN254
```

Alternatively, you can verify the proof using snarkJS. Just execute:


```bash
snarkjs groth16 verify verification_key.json out/proofs/public_input.0.json out/proofs/proof.0.json
```

## Poseidon with co-noir
In this example, we’ll demonstrate how to compute a Poseidon hash from two different sources. Therefore we work in the `noir/poseidon folder`. The following code snippet describes the circuit we want to prove:

```rust
use dep::std::hash::poseidon;

fn main(x: Field, y: Field) -> pub Field {
    poseidon::bn254::hash_2([x, y])
}

```

In this code, we utilize the standard library to compute a Poseidon hash from two secret inputs. The result is a public Field element, which represents the computed hash.

### Compiling the Circuit
Now that we already experts we will run through this example. We use `nargo`to compile the project by typing:

```bash
nargo compile
```

You'll find a file called `poseidon.json` under the `target` folder. This is our compiled circuit.

### Secret Sharing the Input
Secret share the inputs (now Toml files instead of JSON).

```bash
co-noir split-input --input Alice.toml --circuit target/poseidon.json --protocol REP3 --out-dir out/secret_shared_inputs/
co-noir split-input --input Bob.toml --circuit target/poseidon.json --protocol REP3 --out-dir out/secret_shared_inputs/
```
or 

```bash
just split-input
```
### Merging the Input
Merge the inputs:
```bash
#merge input for party 0
co-noir merge-input-shares --inputs out/secret_shared_inputs/Alice.toml.0.shared --inputs out/secret_shared_inputs/Bob.toml.0.shared --protocol REP3 --out out/merged_inputs/input.toml.0.shared 
co-noir merge-input-shares --inputs out/secret_shared_inputs/Alice.toml.1.shared --inputs out/secret_shared_inputs/Bob.toml.1.shared --protocol REP3 --out out/merged_inputs/input.toml.1.shared 
co-noir merge-input-shares --inputs out/secret_shared_inputs/Alice.toml.2.shared --inputs out/secret_shared_inputs/Bob.toml.2.shared --protocol REP3 --out out/merged_inputs/input.toml.2.shared 
```
or 

```bash
just merge-input
```
### Generating the Extended Witness
Compute the extended witness:
```bash
# start party 0
co-noir generate-witness --input out/merged_inputs/input.toml.0.shared --circuit target/poseidon.json --protocol REP3 --config ../../configs/party0.toml --out out/witness/witness.wtns.0.shared 

# start party 1
co-noir generate-witness --input out/merged_inputs/input.toml.1.shared --circuit target/poseidon.json --protocol REP3 --config ../../configs/party1.toml --out out/witness/witness.wtns.1.shared 

# start party 2
co-noir generate-witness --input out/merged_inputs/input.toml.2.shared --circuit target/poseidon.json --protocol REP3 --config ../../configs/party2.toml --out out/witness/witness.wtns.2.shared 
```
or 

```bash
just run-witness-generation
```

### Generating the Proof
```bash
# start party 0
co-noir generate-proof --witness out/witness/witness.wtns.0.shared --crs bn254_g1.dat --protocol REP3 --config ../../configs/party0.toml --out out/proofs/proof.0.dat --public-input out/proofs/public_input.0.json --circuit target/poseidon.json 

# start party 1
co-noir generate-proof --witness out/witness/witness.wtns.1.shared --crs bn254_g1.dat --protocol REP3 --config ../../configs/party1.toml --out out/proofs/proof.1.dat --public-input out/proofs/public_input.1.json --circuit target/poseidon.json

# start party 2
co-noir generate-proof --witness out/witness/witness.wtns.2.shared --crs bn254_g1.dat --protocol REP3 --config ../../configs/party2.toml --out out/proofs/proof.2.dat --public-input out/proofs/public_input.2.json --circuit target/poseidon.json

```
or use the `justfile`

```bash
just run-proof-honk
```

### Extract the Verification Key
In contrast to `circom` where we can extract the verification key from the `zkey` with snarkJS, we need another step with `co-noir`. Generate the verification key with this command:

```bash
# Create verification key
co-noir create-vk --circuit target/poseidon.json --crs bn254_g1.dat --vk verification_key.dat
```

### Verifying the Proof with co-circom
Finally verify the proof:
```bash
# verify proof
co-noir verify --proof out/proofs/proof.0.dat --vk verification_key.dat --crs bn254_g2.dat

```
