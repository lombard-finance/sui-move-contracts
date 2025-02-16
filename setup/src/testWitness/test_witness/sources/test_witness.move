module test_witness::test_witness {
    public struct TestWitness has drop {}
    
    public fun create_witness(): TestWitness {
        TestWitness {}
    }
}