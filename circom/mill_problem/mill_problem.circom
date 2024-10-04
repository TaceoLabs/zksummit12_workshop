pragma circom 2.0.0;

include "lib/comparators.circom";

template MillionairesProblem(N) {
    signal input alice;
    signal input bob;
    signal output result;

    component is_equal = IsEqual();
    is_equal.in[0] <== alice;
    is_equal.in[1] <== bob;
    signal inv <== 1 - is_equal.out;

    component lt = LessThan(N);
    lt.in[0] <== alice;
    lt.in[1] <== bob;
    signal comparison <== lt.out + 1;

    // if result == 0 -> same money
    // if result == 1 -> alice richer
    // if result == 2 -> bob richer
    result <== comparison * inv;
}

component main = MillionairesProblem(32);

