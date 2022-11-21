module.exports = {
    burnRates: [
        0n,
        1_000n,
        50_000n,
        100_000n,
        200_000n,
        500_000n,
        1_000_000n,
    ],
    rareLimits: [
        0,      // starts from 10_001
        0,      // starts from 10_001
        10_000, // starts from 6_001
        6_000,  // starts from 3_001
        3_000,  // starts from 1_001
        1_000,  // starts from 3
        2,      // starts from 1
    ],
    Series: {
        COLLECTOR:  0,
        LIMITED:    1,
        RARE:       2,
        EPIC:       3,
        LEGENDARY:  4,
        EXOTIC:     5,
        XUNICORN:   6,
    }
}

