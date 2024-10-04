use dep::std::hash::poseidon;

fn main(x: Field, y: Field) -> pub Field {
    poseidon::bn254::hash_2([x, y])
}

