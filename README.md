# ZK Summit 12 Workshop

This README is complementary material for the workshop during ZK-12.

## Installation
The preferred way to participate in the workshop is by running the docker image provided in this repository.

### Docker
Simply run in the root folder of the repository:
```bash
docker build -t co-snarks . && docker run -it co-snarks
```

### Install everything by hand
Follow the instructions from our [GitHub](https://github.com/TaceoLabs/collaborative-circom). Additionally, you have to install [Noir](https://noir-lang.org/docs/getting_started/installation/).

At the end you should have an installation of the following tools:
* co-circom
* circom
* snarkJS
* Noir

## The Millionaires Problem
For this example we will work in the `/circom/mill_problem` folder. For convenience we provided a `justfile` that executes all commands. As we need to run certain commands on all "MPC-nodes" we need to start those process at the same time. This can be bothersome in the Docker, so we added the `justfile` and the container already has `just` installed.

### Compiling the Circuit

First step is to compile the circuit to the R1CS format. For that type:

```bash
circom --r1cs mill_problem.circom -l libs
```

You call the circom compiler with the `--r1cs` flag to compile the circuit to
the R1CS format. The `-l` flag is used to specify the directory where the
libraries are located.

After that you will have another file: `mill_problem.r1cs`. Additionally, you get
some output from the compiler, like the amount of constraints, public and
private inputs, etc.

### Secret Sharing the Input

The next step is to prepare the input for the circuit. As we simulate two
parties, we have two input files: `input.alice.json` and `input.bob.json`.

You can show the input files with the following command:

```bash
cat input.alice.json
```

Now split the input (secret-share):

```bash
#split input Alice
co-circom split-input --circuit mill_problem.circom --input input.alice.json --protocol REP3 --out-dir out/secret_shared_inputs/ --curve BN254

#split input Bob
co-circom split-input --circuit mill_problem.circom --input input.bob.json --protocol REP3 --out-dir out/secret_shared_inputs/ --curve BN254
```
or  use the `justfile`

```bash
just split-input
```

You will find 6 files now in the `out/secret_shared_inputs` directory. The file
`input.alice.json.0.shared` contains the secret-shared from Alice for party 0. The
file `input.bob.json.1.shared` contains the secret-shared input from Bob for party 1
and so on.

Recall that usually this is done on two different machines!

### Merging the Input

After we have secret-shared the input, we need to merge the secret-shared input
on the MPC-nodes. In a real scenario, Alice and Bob would send their
secret-shared inputs to the MPC-nodes. For this example, we will simulate this by
merging the secret-shared inputs on the same machine. This means we have to do
that three times (one for every node).

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

All the MPC-nodes now have the secret-shared merged input. The next step is to
generate the extended witness. This is done by running the following command on each MPC-node. This is a dedicated process, so you either need three terminal sessions or use the provided `justfile`.

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

This may take a few seconds (but should not take so long). After that, you will
have the secret-shared witness in the `out/witness` folder.

### Generating the Proof

The last step is to generate the proof. This is done by running the following
commands on each MPC-node:

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

Congratulations! You have generated the proof. You can find three proofs in the
`out/proofs` directory. The public input is also stored in the `out/proofs`
directory. The proofs and the public inputs are in JSON format and are
equivalent to one another.

### Verifying the Proof with co-circom

Of course, you can also verify the proof with the `co-circom` tool. You can do
that with the following command:

```bash
co-circom verify --proof out/proofs/proof.0.json --vk verification_key.json --public-input out/proofs/public_input.0.json groth16 --curve BN254
```

You can also do that with snarkJS! For that just type:

```bash
snarkjs groth16 verify verification_key.json out/proofs/public_input.0.json out/proofs/proof.0.json
```

## Poseidon with co-noir
In this example, we show how to compute a Poseidon hash from two different source. Start a new Noir project by typing:

```bash
nargo new poseidon
```

`Nargo` will create a new Noir project with a `main.nr` file. Copy the following code snippet in the `main.nr`:

```rust
use dep::std::hash::poseidon;

fn main(x: Field, y: Field) -> pub Field {
    poseidon::bn254::hash_2([x, y])
}

```

Here we use the standard library to compute a Poseidon hash from two secret inputs. The output is a public Field element, e.g., the computed hash.

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
just run-generate-witness
```

### Generating the Proof
```bash
# start party 0
co-noir generate-proof --witness out/witness/witness.wtns.0.shared --crs bn254_g1.dat --protocol REP3 --config ../../configs/party0.toml --out out/proofs/proof.0.json --public-input out/proofs/public_input.0.json --circuit target/poseidon.json 

# start party 1
co-noir generate-proof --witness out/witness/witness.wtns.1.shared --crs bn254_g1.dat --protocol REP3 --config ../../configs/party1.toml --out out/proofs/proof.1.json --public-input out/proofs/public_input.1.json --circuit target/poseidon.json

# start party 2
co-noir generate-proof --witness out/witness/witness.wtns.2.shared --crs bn254_g1.dat --protocol REP3 --config ../../configs/party2.toml --out out/proofs/proof.2.json --public-input out/proofs/public_input.2.json --circuit target/poseidon.json

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

### as
Finally verify the proof:
```bash
# verify proof
co-noir verify --proof out/proofs/proof.0.proof --vk verification_key.dat --crs bn254_g2.dat

```
