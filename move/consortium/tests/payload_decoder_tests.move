#[test_only]
module consortium::payload_decoder_tests;

use consortium::payload_decoder;
use sui::bcs;

#[test]
fun test_payload_decoder() {
    let payload = x"f2e73f7c0000000000000000000000000000000000000000000000000000000000aa36a70000000000000000000000000f90793a54e809bf708bd0fbcc63d311e3bb1be100000000000000000000000000000000000000000000000000000000000059d85a7c1a028fe68c29a449a6d8c329b9bdd39d8b925ba0f8abbde9fe398430fac40000000000000000000000000000000000000000000000000000000000000000";

    let (action, to_chain, recipient, amount, txid, vout) = payload_decoder::decode_mint_payload(payload);
    assert!(action == 4075241340);
    assert!(to_chain == 11155111);
    assert!(recipient.to_bytes() == x"0000000000000000000000000f90793a54e809bf708bd0fbcc63d311e3bb1be1");
    assert!(amount == 23000);
    assert!(bcs::to_bytes(&txid) == x"c4fa308439fee9bdabf8a05b928b9dd3bdb929c3d8a649a4298ce68f021a7c5a");
    assert!(vout == 0);
}

#[test]
fun test_signature_decoder() {
    let signatures = x"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000405ac3b079f374485585c941449e67e4fd33217c4a5579dc61f9d7b2704a00820c29d588f2981f7a2a429cf2df97ed1ead40f37d1c4fc45257ee37592861b4957000000000000000000000000000000000000000000000000000000000000000404588a44b8309f6602515e4aa5e6868b4b8131bea1a3d7e137049113b31c2ea384a3cea2e1ce7ecdd30cf6caabd22282dc65324de0c14e857c4850c981935a0260000000000000000000000000000000000000000000000000000000000000040b31e60fd4802a7d476dc9a75b280182c718ffd8a0ddf4630b4a91b4450a2c3ca5f9f34229c2c9da7a86881fefe7f41ffcafd96b6157da2729f59c4856e2d437a";
    let payload = x"f2e73f7c000000000000000000000000000000000000000000000000000000000000000953ac220c4c7f0e8ac4266b54779f8a5e772705390a43f4ea2a59cd7c10305e4d0000000000000000000000000000000000000000000000000000000005f5e1008d3427b7fa9f07adb76208188930d49341246cef989a20b45a4619fd2ba6810a0000000000000000000000000000000000000000000000000000000000000000";
    let hash = x"89cf3b8247cc333fcf84109cee811a81d2ed1c14af1701b7716cbb0611e51979";
    let signers = vector[x"04ba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0d67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f4", x"049d9031e97dd78ff8c15aa86939de9b1e791066a0224e331bc962a2099a7b1f0464b8bbafe1535f2301c72c2cb3535b172da30b02686ab0393d348614f157fbdb", x"0420b871f3ced029e14472ec4ebc3c0448164942b123aa6af91a3386c1c403e0ebd3b4a5752a2b6c49e574619e6aa0549eb9ccd036b9bbc507e1f7f9712a236092"];
    let weights: vector<u256> = vector[1, 1, 1];
    let weight_threshold = 2;

    let signatures = payload_decoder::decode_signatures(signatures);
    assert!(payload_decoder::validate_signatures(signers, signatures, weights, weight_threshold, payload, hash));
}

#[test]
fun test_valset_decoder() {
    let valset = x"4aab1d6f000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000034000000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000041047378e006183e9a5de1537b788aa9d107c67189cd358efc1d53a5642dc0a373113e8808ff945b2e03470bc19d0d11284ed24fee8bbf2c90908b640a91931b257200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004104ca1bf4568f0e73ed993c9cb80bb46492101e0847000288d1cdc246ff67ecda20da20c13b7ed03a97c1c9667ebfdaf1933e1c731d496b62d82d0b8cb71b33bfd500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004104ac2fec1927f210f2056d13c9ba0706666f333ed821d2032672d71acf47677eae4c474ec4b2ee94be26655a1103ddbd0b97807a39b1551a8c52eeece8cc48829900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004104b56056d0cb993765f963aeb530f7687c44d875bd34e38edc719bb117227901c5823dc3a6511d67dc5d081ac2a9d41219168f060f80c672c0391009cd267e4eb40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000064";

    let (action, epoch, validators, weights, weight_threshold, height) = payload_decoder::decode_valset(valset);
    assert!(action == 1252728175);
    assert!(epoch == 2);
    assert!(weight_threshold == 320);
    assert!(height == 6);
    assert!(validators.length() == 4);
    assert!(weights.length() == 4);

    assert!(validators[0] == x"047378e006183e9a5de1537b788aa9d107c67189cd358efc1d53a5642dc0a373113e8808ff945b2e03470bc19d0d11284ed24fee8bbf2c90908b640a91931b2572");
    assert!(validators[1] == x"04ca1bf4568f0e73ed993c9cb80bb46492101e0847000288d1cdc246ff67ecda20da20c13b7ed03a97c1c9667ebfdaf1933e1c731d496b62d82d0b8cb71b33bfd5");
    assert!(validators[2] == x"04ac2fec1927f210f2056d13c9ba0706666f333ed821d2032672d71acf47677eae4c474ec4b2ee94be26655a1103ddbd0b97807a39b1551a8c52eeece8cc488299");
    assert!(validators[3] == x"04b56056d0cb993765f963aeb530f7687c44d875bd34e38edc719bb117227901c5823dc3a6511d67dc5d081ac2a9d41219168f060f80c672c0391009cd267e4eb4");

    let mut i = 0;
    while (i < weights.length()) {
        assert!(weights[i] == 100);
        i = i + 1;
    }
}

#[test]
fun test_initial_valset_decoder() {
    let valset = x"4aab1d6f000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000002a000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000001d0000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000004104434be45682238709526d562c099570f7e7c19f670be0a41eff5fde784b0841cea3097052b8389e6424b799eb0a4b7e7a53abb4a62016cb7a7e0ffffb3b28e2700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000410420b2a4abde0bd0a5943c8740b69d244a419ece11505afc6234f62b86c4e3575075dde75b95b988853231f210b28592bc31fa749b29dda5204186aca273413431000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041041e706ef040f760e5f97504a97479d34bffa6205b35dd97a0815e9bbd1ab8add0fb73442ff761f27d2aebab49b7b0f1ace226c56bd3391c4e47af8071358a93a1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000064";

    let (action, epoch, validators, weights, weight_threshold, height) = payload_decoder::decode_valset(valset);
    assert!(action == 1252728175);
    assert!(epoch == 2);
    assert!(weight_threshold == 240);
    assert!(height == 29);
    assert!(validators.length() == 3);
    assert!(weights.length() == 3);

    assert!(validators[0] == x"04434be45682238709526d562c099570f7e7c19f670be0a41eff5fde784b0841cea3097052b8389e6424b799eb0a4b7e7a53abb4a62016cb7a7e0ffffb3b28e270");
    assert!(validators[1] == x"0420b2a4abde0bd0a5943c8740b69d244a419ece11505afc6234f62b86c4e3575075dde75b95b988853231f210b28592bc31fa749b29dda5204186aca273413431");
    assert!(validators[2] == x"041e706ef040f760e5f97504a97479d34bffa6205b35dd97a0815e9bbd1ab8add0fb73442ff761f27d2aebab49b7b0f1ace226c56bd3391c4e47af8071358a93a1");

    let mut i = 0;
    while (i < weights.length()) {
        assert!(weights[i] == 100);
        i = i + 1;
    }
}

#[test]
fun test_fee_payload_decoder() {
    let fee_payload = x"8175ca940000000000000000000000000000000000000000000000000000000005f5e0ff00000000000000000000000000000000000000000000000000000000678621c7";

    let (action, fee, expiry) = payload_decoder::decode_fee_payload(fee_payload);
    assert!(action == 2171980436);
    assert!(fee == 99999999);
    assert!(expiry == 1736843719);
}
